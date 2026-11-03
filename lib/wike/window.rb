# frozen_string_literal: true

require 'adwaita'
require 'webkit-gtk'
require_relative 'article_menu_popover'
require_relative 'bookmarks_panel'
require_relative 'data'
require_relative 'dialogs'
require_relative 'history_panel'
require_relative 'langlinks_panel'
require_relative 'main_menu_popover'
require_relative 'page_box'
require_relative 'search_panel'
require_relative 'toc_panel'
require_relative 'view_menu_popover'
require_relative 'view_menu_popover'
require_relative 'wiki_view'

module Wike
  # Ported from upstream's Window in src/window.py and data/gtk/window.ui.
  #
  # The whole window: the icon bar of panel selectors down the left, the
  # sidebar that holds the five panels, the header bar, the tab bar and the
  # tabs themselves, plus the mobile action bars the breakpoints reveal.
  #
  # It owns the window actions — navigation, tabs, the panels, the article
  # actions and printing — and the tab bookkeeping upstream keeps here: a new
  # tab, a lazily restored tab, closing the last tab back to a blank page, and
  # the article properties a newly selected tab pushes into the panels.
  #
  # Two layout notes:
  #
  #   * window.ui declares its breakpoint `<setter>` entries in the template.
  #     Here each breakpoint's apply and unapply handlers set those same
  #     properties, next to the behaviour window.py already attaches to them,
  #     so a breakpoint's whole effect reads in one place.
  #   * window.ui keeps the desktop, mobile and header copies of a selector
  #     button in step with `bind-source` bindings. Here `sync_buttons` does
  #     it, which is also where upstream's `_bar_selector_button_toggled_cb`
  #     acts on the selection.
  class Window < Adwaita::ApplicationWindow
    # The sidebar pages, in the order their buttons sit on the icon bar, with
    # the icon and tooltip upstream gives each.
    PANELS = [
      ['search', 'system-search-symbolic', 'Search Wikipedia'],
      ['toc', 'view-list-symbolic', 'Contents'],
      ['langlinks', 'language-symbolic', 'Languages'],
      ['bookmarks', 'user-bookmarks-symbolic', 'Bookmarks'],
      ['history', 'document-open-recent-symbolic', 'History'],
    ].freeze

    # [action, accelerators] — upstream's `_set_actions` table, whose callback
    # column is `activate_action` below.
    ACTIONS = [
      ['prev-page', ['<Alt>Left']],
      ['next-page', ['<Alt>Right']],
      ['new-tab', ['<Ctrl>T']],
      ['close-tab', ['<Ctrl>W']],
      ['next-tab', ['<Ctrl>Tab']],
      ['prev-tab', ['<Shift><Ctrl>Tab']],
      ['toggle-overview', ['F4', '<Alt>T']],
      ['add-bookmark', ['<Ctrl>D']],
      ['show-search', ['F2', '<Ctrl>K']],
      ['show-toc', ['<Ctrl>I']],
      ['show-langlinks', ['<Ctrl>L']],
      ['show-bookmarks', ['<Ctrl>B']],
      ['show-history', ['<Ctrl>H']],
      ['main-page', ['<Alt>Home']],
      ['random-article', ['<Alt>R']],
      ['open-link', ['<Alt>L']],
      ['reload-page', ['F5', '<Ctrl>R']],
      ['search-text', ['<Ctrl>F']],
      ['print-page', ['<Ctrl>P']],
      ['open-browser', nil],
      ['copy-link', ['<Ctrl>U']],
    ].freeze

    # The actions that only mean anything on a real article, as upstream's
    # refresh_menu_actions lists them.
    ARTICLE_ACTIONS = %w[search-text print-page open-browser copy-link].freeze

    # The mouse buttons a mouse with side buttons sends for back and forward.
    BACK_BUTTON = 8
    FORWARD_BUTTON = 9

    # The `on-start-load` setting: main page, random article, last article,
    # last session's tabs.
    START_MAIN = 0
    START_RANDOM = 1
    START_LAST = 2
    START_TABS = 3

    attr_reader :page

    def initialize(app, launch_uri = '')
      super(app)
      @app = app
      @launch_uri = launch_uri
      @print_settings = Gtk::PrintSettings.new
      @syncing = false
    end

    def build
      tap do |win|
        win.title = 'Wike'
        win.icon_name = 'com.github.hugolabe.Wike'
        win.set_size_request(360, 480)
        win.content = taboverview
        win.add_breakpoint(medium_breakpoint)
        win.add_breakpoint(small_breakpoint)
        win.add_controller(click_gesture)

        taboverview.tap do |overview|
          overview.child = toast_overlay
          overview.signal_connect('create-tab') { new_page('blank', nil, true) }

          toast_overlay.tap do |overlay|
            overlay.child = bar_split

            bar_split.tap do |split|
              split.sidebar = build_icon_bar
              split.content = panel_split
            end
          end
        end

        panel_split.tap do |split|
          split.sidebar = build_panel
          split.content = content_bin
          split.signal_connect('notify::show-sidebar') { reflect_sidebar }
        end

        content_bin.tap do |bin|
          bin.add_breakpoint(content_breakpoint)
          bin.child = build_content
        end

        add_actions
        connect_settings
        open_start_pages
        reflect_sidebar
        if Data.settings.get_boolean('hide-tabs')
          hide_tabs(true)
        end
      end
    end

    # Show a notification with the provided message, as upstream's window does
    # for the bookmark, clipboard and print messages.
    def send_notification(message)
      Adwaita::Toast.new(message).tap do |toast|
        toast.timeout = 3
        toast_overlay.add_toast(toast)
      end
    end

    # The window-side half of upstream's `_wikiview_load_props_cb`: the title
    # and the panels follow the article the selected tab is on.
    def show_article(wikiview)
      self.title = wikiview.article_title
      toc_panel.populate(wikiview.article_title, wikiview.sections)
      langlinks_panel.populate(wikiview.langlinks)
      bookmarks_panel.refresh_buttons
      refresh_menu_actions(wikiview.local?)
    end

    # Upstream's refresh_nav_actions: back and forward are only live when the
    # view has somewhere to go.
    def refresh_nav_actions(wikiview)
      lookup_action('prev-page')&.enabled = wikiview.can_go_back?
      lookup_action('next-page')&.enabled = wikiview.can_go_forward?
    end

    # Upstream's refresh_menu_actions: the article actions go dead on a status
    # page, where there is no article to search, print, open or copy.
    def refresh_menu_actions(is_local)
      ARTICLE_ACTIONS.each do |name|
        lookup_action(name)&.enabled = !is_local
      end
    end

    # Open a URI in a new tab. `uri` is either an article URI or one of the
    # four words upstream accepts: main, random, blank and notfound.
    def new_page(uri, parent, select)
      page_box(nil).then do |box|
        tabview.add_page(box, parent).tap do |tabpage|
          tabpage.live_thumbnail = true
          box.tab_page = tabpage
          load_into(box, uri)
          if select
            tabview.selected_page = tabpage
          end
        end
      end
    end

    # A tab restored from the last session: it carries its title but loads
    # nothing until it is selected.
    def new_lazy_page(uri, title, parent)
      page_box([uri, title]).then do |box|
        tabview.add_page(box, parent).tap do |tabpage|
          tabpage.live_thumbnail = true
          tabpage.title = title
          box.tab_page = tabpage
        end
      end
    end

    # Upstream's application quit handler asks the window for its geometry and
    # the tabs it has open before the settings are flushed.
    def save_state
      maximized?.then do |maximized|
        Data.settings.set_boolean('window-max', maximized)
        unless maximized
          Data.settings.set_int('window-width', default_width)
          Data.settings.set_int('window-height', default_height)
        end
      end
      Data.settings.set_string('last-uri', last_uri)
      Data.settings.set_value('last-tabs', open_tabs)
    end

    # Memoized widget methods

    def taboverview
      @taboverview ||= Adwaita::TabOverview.new.tap do |overview|
        overview.view = tabview
        overview.enable_new_tab = true
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    # The icon bar is 46px of toggle buttons and nothing else, so its sidebar
    # width is pinned.
    def bar_split
      @bar_split ||= Adwaita::OverlaySplitView.new.tap do |split|
        split.min_sidebar_width = 46
        split.max_sidebar_width = 46
      end
    end

    def panel_split
      @panel_split ||= Adwaita::OverlaySplitView.new.tap do |split|
        split.min_sidebar_width = 280
        split.max_sidebar_width = 320
        split.collapsed = true
      end
    end

    def icon_bar_toolbar = @icon_bar_toolbar ||= Adwaita::ToolbarView.new
    def panel_toolbar = @panel_toolbar ||= Adwaita::ToolbarView.new

    def content_bin
      @content_bin ||= Adwaita::BreakpointBin.new.tap do |bin|
        bin.set_size_request(360, 480)
      end
    end

    def content_toolbar
      @content_toolbar ||= Adwaita::ToolbarView.new.tap do |bar|
        bar.top_bar_style = :raised
        bar.bottom_bar_style = :raised
      end
    end

    def headerbar = @headerbar ||= Gtk::HeaderBar.new
    def tabview = @tabview ||= Adwaita::TabView.new

    def tabbar
      @tabbar ||= Adwaita::TabBar.new.tap do |bar|
        bar.view = tabview
      end
    end

    def panel_stack = @panel_stack ||= Gtk::Stack.new

    def selector_box
      @selector_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.vexpand = true
        box.margin_top = 38
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    def selector_box_mob = @selector_box_mob ||= Gtk::Box.new(:horizontal, 6)

    # The five desktop selector buttons, grouped so that at most one is
    # pressed, keyed by the panel they show.
    def panel_buttons
      @panel_buttons ||= PANELS.each_with_object({}) do |(name, icon, tooltip), collected|
        collected[name] = selector_button(icon, tooltip).tap do |button|
          button.add_css_class('flat')
        end
      end
    end

    # The same five buttons again for the mobile action bar.
    def panel_buttons_mob
      @panel_buttons_mob ||= PANELS.each_with_object({}) do |(name, icon, tooltip), collected|
        collected[name] = selector_button(icon, tooltip)
      end
    end

    # A sixth copy of the search button, which the narrow header bar shows in
    # place of the icon bar.
    def search_button_header
      @search_button_header ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'system-search-symbolic'
        button.tooltip_text = 'Search Wikipedia'
        button.visible = false
      end
    end

    def panel_button
      @panel_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'sidebar-show-symbolic'
        button.tooltip_text = 'Sidebar'
        button.action_name = 'win.pin-panel'
        button.margin_top = 6
        button.margin_bottom = 6
        button.margin_start = 6
        button.margin_end = 6
        button.add_css_class('flat')
      end
    end

    def panel_button_mob
      @panel_button_mob ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'sidebar-show-symbolic'
        button.visible = false
      end
    end

    def panel_actionbar
      @panel_actionbar ||= Gtk::ActionBar.new.tap do |bar|
        bar.revealed = false
      end
    end

    def content_actionbar
      @content_actionbar ||= Gtk::ActionBar.new.tap do |bar|
        bar.revealed = false
      end
    end

    def close_panel_button_mob
      @close_panel_button_mob ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-previous-symbolic'
        button.tooltip_text = 'Close'
      end
    end

    def prev_button = @prev_button ||= nav_button('go-previous-symbolic', 'Back', 'win.prev-page')
    def next_button = @next_button ||= nav_button('go-next-symbolic', 'Forward', 'win.next-page')
    def prev_button_mob = @prev_button_mob ||= nav_button('go-previous-symbolic', 'Back', 'win.prev-page')
    def next_button_mob = @next_button_mob ||= nav_button('go-next-symbolic', 'Forward', 'win.next-page')

    def newtab_button
      @newtab_button ||= nav_button('tab-new-symbolic', 'New Tab', 'win.new-tab')
    end

    def tabs_button
      @tabs_button ||= Adwaita::TabButton.new.tap do |button|
        button.view = tabview
        button.action_name = 'win.toggle-overview'
        button.visible = false
      end
    end

    def main_button
      @main_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
        button.primary = true
        button.margin_top = 6
        button.margin_bottom = 6
        button.margin_start = 6
        button.margin_end = 6
        button.add_css_class('flat')
      end
    end

    def main_button_mob
      @main_button_mob ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
      end
    end

    def article_button
      @article_button ||= menu_button('view-more-symbolic', 'Article Menu')
    end

    def article_button_mob
      @article_button_mob ||= menu_button('view-more-symbolic', 'Article Menu')
    end

    def view_button = @view_button ||= menu_button('view-reveal-symbolic', 'View')
    def view_button_mob = @view_button_mob ||= menu_button('view-reveal-symbolic', 'View')

    def main_menu_popover = @main_menu_popover ||= MainMenuPopover.new
    def article_menu_popover = @article_menu_popover ||= ArticleMenuPopover.new
    def view_menu_popover = @view_menu_popover ||= ViewMenuPopover.new

    # A window narrower than this has no room for the sidebar beside the
    # article, so the pin button goes away.
    def medium_breakpoint
      @medium_breakpoint ||= breakpoint('max-width: 750px') do |applied|
        panel_button.visible = !applied
        lookup_action('pin-panel')&.enabled = !applied
        if applied
          panel_split.collapsed = true
        else
          panel_split.collapsed = !panel_button.active?
        end
      end
    end

    # Narrower still: the icon bar and the sidebar both become overlays, the
    # selectors move to the sidebar's action bar, and the header bar grows a
    # search button of its own.
    def small_breakpoint
      @small_breakpoint ||= breakpoint('max-width: 450px') do |applied|
        bar_split.collapsed = applied
        panel_actionbar.revealed = applied
        panel_button_mob.visible = applied
        search_button_header.visible = applied
        if applied
          panel_split.collapsed = true
          panel_split.max_sidebar_width = 450
        else
          panel_split.max_sidebar_width = 320
        end
      end
    end

    # The content breakpoint is on the article side alone, so a wide window
    # with a pinned sidebar still gets the mobile action bar.
    def content_breakpoint
      @content_breakpoint ||= breakpoint('max-width: 550px') do |applied|
        prev_button.visible = !applied
        next_button.visible = !applied
        article_button.visible = !applied
        view_button.visible = !applied
        content_actionbar.revealed = applied
        move_menus(applied)
        hide_tabs(applied || Data.settings.get_boolean('hide-tabs'))
      end
    end

    # Panels

    def toc_panel
      @toc_panel ||= TocPanel.new(
        on_section: ->(anchor) { page.wikiview.load_section(anchor) },
        on_dismiss: -> { dismiss_sidebar },
      )
    end

    def search_panel
      @search_panel ||= SearchPanel.new(
        on_load_uri:     ->(uri) { page.wikiview.load_wiki(uri) },
        on_load_message: ->(message_type) { page.wikiview.load_message(message_type) },
        on_dismiss:      -> { dismiss_sidebar },
        on_show_search:  -> { show_panel('search') },
      )
    end

    def langlinks_panel
      @langlinks_panel ||= LanglinksPanel.new(
        on_load_uri: ->(uri) { page.wikiview.load_wiki(uri) },
        on_dismiss:  -> { dismiss_sidebar },
      )
    end

    def bookmarks_panel
      @bookmarks_panel ||= BookmarksPanel.new(
        on_load_uri:     ->(uri) { page.wikiview.load_wiki(uri) },
        on_dismiss:      -> { dismiss_sidebar },
        current_article: -> { current_article },
        on_can_add:      ->(can_add) { lookup_action('add-bookmark')&.enabled = can_add },
      )
    end

    def history_panel
      @history_panel ||= HistoryPanel.new(
        on_load_uri: ->(uri) { page.wikiview.load_wiki(uri) },
        on_dismiss:  -> { dismiss_sidebar },
      )
    end

    def click_gesture
      @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 0
        gesture.propagation_phase = :capture
      end
    end

    private

      # --- Assembly ---------------------------------------------------------

      def build_icon_bar
        icon_bar_toolbar.tap do |bar|
          bar.add_top_bar(main_button)
          bar.content = selector_box
          bar.add_bottom_bar(panel_button)

          selector_box.tap do |box|
            panel_buttons.each_value { |button| box.append(button) }
            group_buttons(panel_buttons.values)
          end

          main_button.popover = main_menu_popover.build
          connect_selectors
        end
      end

      def build_panel
        panel_toolbar.tap do |bar|
          bar.content = panel_stack
          bar.add_bottom_bar(panel_actionbar)

          panel_stack.tap do |stack|
            stack.add_named(search_panel.build, 'search')
            stack.add_named(toc_panel.build, 'toc')
            stack.add_named(langlinks_panel.build, 'langlinks')
            stack.add_named(bookmarks_panel.build, 'bookmarks')
            stack.add_named(history_panel.build, 'history')
          end

          panel_actionbar.tap do |actionbar|
            actionbar.pack_start(close_panel_button_mob)
            actionbar.set_center_widget(selector_box_mob)
            actionbar.pack_end(main_button_mob)

            selector_box_mob.tap do |box|
              panel_buttons_mob.each_value { |button| box.append(button) }
              group_buttons(panel_buttons_mob.values)
            end

            close_panel_button_mob.signal_connect('clicked') do
              panel_split.show_sidebar = false
            end
          end
        end
      end

      def build_content
        content_toolbar.tap do |bar|
          bar.add_top_bar(headerbar)
          bar.add_top_bar(tabbar)
          bar.content = tabview
          bar.add_bottom_bar(content_actionbar)

          headerbar.tap do |header|
            header.pack_start(prev_button)
            header.pack_start(next_button)
            header.pack_start(newtab_button)
            header.pack_start(tabs_button)
            header.pack_end(article_button)
            header.pack_end(view_button)
            header.pack_end(search_button_header)
          end

          content_actionbar.tap do |actionbar|
            actionbar.pack_start(prev_button_mob)
            actionbar.pack_start(next_button_mob)
            actionbar.pack_start(panel_button_mob)
            actionbar.pack_end(article_button_mob)
            actionbar.pack_end(view_button_mob)
          end

          article_button.popover = article_menu_popover.build
          view_button.popover = view_menu_popover.build
          connect_tabs
        end
      end

      def selector_button(icon, tooltip)
        Gtk::ToggleButton.new.tap do |button|
          button.icon_name = icon
          button.tooltip_text = tooltip
        end
      end

      def nav_button(icon, tooltip, action)
        Gtk::Button.new.tap do |button|
          button.icon_name = icon
          button.tooltip_text = tooltip
          button.action_name = action
        end
      end

      def menu_button(icon, tooltip)
        Gtk::MenuButton.new.tap do |button|
          button.icon_name = icon
          button.tooltip_text = tooltip
        end
      end

      # The five buttons of a selector set behave as one radio group, which is
      # the `group` property window.ui gives them.
      def group_buttons(buttons)
        buttons.drop(1).each { |button| button.group = buttons.first }
      end

      def breakpoint(condition)
        Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(condition)).tap do |point|
          point.signal_connect('apply') { yield(true) }
          point.signal_connect('unapply') { yield(false) }
        end
      end

      # --- Selector buttons -------------------------------------------------

      def connect_selectors
        PANELS.each do |name, _icon, _tooltip|
          panel_buttons[name].signal_connect('toggled') do |button|
            sync_buttons(name, button.active?)
          end
          panel_buttons_mob[name].signal_connect('toggled') do |button|
            sync_buttons(name, button.active?)
          end
        end
        search_button_header.signal_connect('toggled') do |button|
          sync_buttons('search', button.active?)
        end
        panel_button_mob.signal_connect('toggled') do |button|
          panel_split.show_sidebar = button.active?
        end
      end

      # Keep every copy of a selector button in step and, when one of them
      # goes down, show its panel — upstream's
      # `_bar_selector_button_toggled_cb`.
      def sync_buttons(name, active)
        unless @syncing
          @syncing = true
          panel_buttons[name].active = active
          panel_buttons_mob[name].active = active
          if name == 'search'
            search_button_header.active = active
          end
          if active
            select_panel(name)
          end
          @syncing = false
        end
      end

      def select_panel(name)
        panel_stack.visible_child_name = name
        unless panel_split.show_sidebar?
          panel_split.show_sidebar = true
        end
        if name == 'search'
          search_panel.grab_focus
        end
      end

      # Upstream's show-* actions press the button rather than touching the
      # stack, so the icon bar follows.
      def show_panel(name)
        panel_buttons[name].active = true
        sync_buttons(name, true)
      end

      # Upstream's `_panel_split_show_cb`: the visible page's button is
      # pressed while the sidebar is open, none of them once it is closed, and
      # the focus goes back to the article.
      def reflect_sidebar
        panel_button_mob.active = panel_split.show_sidebar?
        if panel_split.show_sidebar?
          sync_buttons(panel_stack.visible_child_name, true)
        else
          panel_buttons.each_value { |button| button.active = false }
          panel_buttons_mob.each_value { |button| button.active = false }
          search_button_header.active = false
          page&.set_focus
        end
      end

      # An activation in a collapsed sidebar closes it, as upstream does.
      def dismiss_sidebar
        if panel_split.collapsed?
          panel_split.show_sidebar = false
        end
      end

      # --- Tabs -------------------------------------------------------------

      def connect_tabs
        tabview.signal_connect('notify::selected-page') { on_selected_page }
        tabview.signal_connect('close-page') { |_view, tabpage| on_close_page(tabpage) }
      end

      def page_box(lazy_load)
        PageBox.new(window: self, lazy_load: lazy_load).build
      end

      def load_into(box, uri)
        case uri
        when 'main' then box.wikiview.load_main
        when 'random' then box.wikiview.load_random
        when 'blank', PageStatus::NOT_FOUND then box.wikiview.load_message(uri)
        else box.wikiview.load_wiki(uri)
        end
      end

      # Upstream's `_tabview_selected_page_cb`: a lazily restored tab loads
      # now, and any other tab pushes what it already knows into the window.
      def on_selected_page
        tabview.selected_page.then do |tabpage|
          if tabpage
            @page = tabpage.child
            if @page.lazy_load
              @page.load_now
            else
              refresh_nav_actions(@page.wikiview)
              show_article(@page.wikiview)
            end
          end
        end
      end

      # Upstream's `_tabview_close_page_cb`: the last tab is not closed but
      # emptied, so the window always has a page. True either way, because the
      # close is finished here.
      def on_close_page(tabpage)
        tabpage.child.then do |box|
          if tabview.n_pages > 1
            box.view_stack.remove(box.wikiview)
            ViewSettings.instance.unregister(box.wikiview)
            tabview.close_page_finish(tabpage, true)
          else
            if taboverview.open?
              taboverview.open = false
            end
            box.wikiview.load_message('blank')
            tabview.close_page_finish(tabpage, false)
          end
        end
        true
      end

      # Upstream's `_hide_tabs`: without the tab bar the header bar shows the
      # overview button instead of the new-tab button.
      def hide_tabs(hide)
        tabbar.visible = !hide
        newtab_button.visible = !hide
        tabs_button.visible = hide
      end

      # The three menus are shared between the header bar and the mobile
      # action bar, and a popover can only belong to one button at a time.
      def move_menus(mobile)
        if mobile
          article_button.popover = nil
          view_button.popover = nil
          article_button_mob.popover = article_menu_popover
          view_button_mob.popover = view_menu_popover
        else
          article_button_mob.popover = nil
          view_button_mob.popover = nil
          article_button.popover = article_menu_popover
          view_button.popover = view_menu_popover
        end
      end

      # --- Start-up ---------------------------------------------------------

      def connect_settings
        Data.settings.bind('panel-pinned', panel_button, 'active')
        Data.settings.bind('panel-page', panel_stack, 'visible-child-name')
        Data.settings.connect_changed('hide-tabs') { on_hide_tabs_changed }
        search_panel.capture_keys_from(self)
        search_panel.on_languages_changed = -> { langlinks_panel.populate(page.wikiview.langlinks) }
        restore_geometry
      end

      def on_hide_tabs_changed
        if Data.settings.get_boolean('hide-tabs')
          hide_tabs(true)
        elsif main_button.visible?
          hide_tabs(false)
        end
      end

      def restore_geometry
        set_default_size(
          Data.settings.get_int('window-width'),
          Data.settings.get_int('window-height'),
        )
        if Data.settings.get_boolean('window-max')
          maximize
        end
      end

      # Upstream's start-up table: a URI handed to the app on the command line
      # wins, then the `on-start-load` setting decides between the main page,
      # a random article, the last article and last session's tabs.
      def open_start_pages
        if @launch_uri.to_s.empty?
          open_start_setting
        else
          new_page(@launch_uri, nil, true)
        end
      end

      def open_start_setting
        case Data.settings.get_int('on-start-load')
        when START_MAIN then new_page('main', nil, true)
        when START_RANDOM then new_page('random', nil, true)
        when START_LAST then open_last_article
        when START_TABS then open_last_tabs
        end
      end

      def open_last_article
        Data.settings.get_string('last-uri').then do |uri|
          if uri.empty?
            new_page('blank', nil, true)
          else
            new_page(uri, nil, true)
          end
        end
      end

      # Every tab of the last session comes back, but only the one that was on
      # screen loads; the rest wait to be selected.
      def open_last_tabs
        Data.settings.get_value('last-tabs').then do |tabs|
          if tabs.nil? || tabs.empty?
            new_page('blank', nil, true)
          else
            restore_tabs(tabs, Data.settings.get_string('last-uri'))
          end
        end
      end

      def restore_tabs(tabs, last_uri)
        tabs.each do |uri, title|
          if uri == last_uri
            new_page(uri, nil, true)
          else
            new_lazy_page(uri, title, nil)
          end
        end
        unless tabs.key?(last_uri)
          tabview.selected_page = tabview.get_nth_page(0)
          @page.load_now
        end
      end

      # The tabs to restore next time: every tab's URI and title, in order,
      # leaving out the status pages, which have nothing to restore.
      def open_tabs
        (0...tabview.n_pages).each_with_object({}) do |index, collected|
          tabview.get_nth_page(index).child.then do |box|
            if box.lazy_load
              collected[box.lazy_load.first] = box.lazy_load.last
            elsif !box.wikiview.local?
              collected[box.wikiview.base_uri] = box.wikiview.article_title
            end
          end
        end
      end

      def last_uri
        if page.nil? || page.wikiview.local?
          ''
        else
          page.wikiview.base_uri
        end
      end

      # --- Actions ----------------------------------------------------------

      def add_actions
        ACTIONS.each do |name, accels|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { run_action(name) }
            add_action(action)
            if accels
              @app.set_accels_for_action("win.#{name}", accels)
            end
          end
        end
        add_pin_panel_action
        refresh_menu_actions(true)
      end

      def add_pin_panel_action
        Gio::SimpleAction.new('pin-panel', nil, GLib::Variant.new(false)).tap do |action|
          action.signal_connect('change-state') do |changed, state|
            changed.state = state
            panel_split.collapsed = !state.get_boolean
          end
          add_action(action)
          @app.set_accels_for_action('win.pin-panel', ['F9'])
          if Data.settings.get_boolean('panel-pinned')
            action.change_state(GLib::Variant.new(true))
          end
        end
      end

      # Upstream's one callback per action, gathered into the table its
      # `_set_actions` reads.
      def run_action(name)
        case name
        when 'prev-page' then go_prev_page
        when 'next-page' then go_next_page
        when 'new-tab' then new_page('blank', nil, true)
        when 'close-tab' then close_current_tab
        when 'next-tab' then select_next_tab
        when 'prev-tab' then select_prev_tab
        when 'toggle-overview' then taboverview.open = !taboverview.open?
        when 'add-bookmark' then add_current_bookmark
        when 'main-page' then page.wikiview.load_main
        when 'random-article' then page.wikiview.load_random
        when 'open-link' then show_open_link
        when 'reload-page' then page.wikiview.reload
        when 'search-text' then page.show_text_search
        when 'print-page' then print_page
        when 'open-browser' then open_in_browser
        when 'copy-link' then copy_link
        else show_panel(name.delete_prefix('show-'))
        end
      end

      def go_prev_page
        if page.wikiview.can_go_back?
          page.wikiview.go_back
        end
      end

      def go_next_page
        if page.wikiview.can_go_forward?
          page.wikiview.go_forward
        end
      end

      def close_current_tab
        tabview.selected_page.then do |tabpage|
          if tabpage
            tabview.close_page(tabpage)
          end
        end
      end

      def select_next_tab
        if tabview.n_pages > 1
          if tabview.get_page_position(tabview.selected_page) < tabview.n_pages - 1
            tabview.select_next_page
          else
            tabview.selected_page = tabview.get_nth_page(0)
          end
        end
      end

      def select_prev_tab
        if tabview.n_pages > 1
          if tabview.get_page_position(tabview.selected_page).positive?
            tabview.select_previous_page
          else
            tabview.selected_page = tabview.get_nth_page(tabview.n_pages - 1)
          end
        end
      end

      # The article on screen, or nil on a status page, which is what the
      # bookmarks panel asks for to decide whether it can bookmark it.
      def current_article
        if page.nil? || page.wikiview.local?
          nil
        else
          page.wikiview.base_uri
        end
      end

      def add_current_bookmark
        current_article.then do |uri|
          if uri && add_bookmark(uri)
            send_notification("Bookmark added: #{page.wikiview.article_title}")
          end
        end
      end

      def add_bookmark(uri)
        bookmarks_panel.add_bookmark(
          uri,
          page.wikiview.article_title,
          page.wikiview.lang,
        )
      end

      def open_in_browser
        current_article.then do |uri|
          if uri
            Gtk::UriLauncher.new(uri).launch(self, nil) { |_launcher, _result| }
          end
        end
      end

      def copy_link
        current_article.then do |uri|
          if uri
            Gdk::Display.default.clipboard.set(uri)
            send_notification('Link copied to clipboard')
          end
        end
      end

      # The entry accepts a link only once it parses as a Wikipedia article
      # URL; anything else marks the entry and leaves the dialog open.
      def show_open_link
        Dialogs::OpenLinkDialog.new.build.tap do |dialog|
          dialog.link_entry.signal_connect('changed') { dialog.clear_error }
          dialog.link_entry.signal_connect('apply') do |entry|
            WikiView.wiki_uri(entry.text).then do |link|
              if link.empty?
                dialog.reject_link
              else
                dialog.close
                page.wikiview.load_wiki(link)
              end
            end
          end
          dialog.present(self)
        end
      end

      # --- Printing ---------------------------------------------------------

      # Upstream prints through WebKit's own print operation, and remembers
      # the output directory the last print used.
      def print_page
        WebKitGtk::PrintOperation.new(page.wikiview).tap do |operation|
          operation.print_settings = print_settings_for(page.wikiview.article_title)
          operation.signal_connect('finished') { on_print_finished(operation) }
          operation.signal_connect('failed') { send_notification('Print operation failed') }
          operation.run_dialog(self)
        end
      end

      def print_settings_for(title)
        @print_settings.tap do |settings|
          settings.set('output-uri', File.join(output_dir, "#{title.tr('/', '-')}.pdf"))
        end
      end

      def output_dir
        @print_settings.get('output-uri').then do |uri|
          if uri.to_s.empty?
            "file://#{Dir.home}"
          else
            File.dirname(uri)
          end
        end
      end

      def on_print_finished(operation)
        @print_settings = operation.print_settings
        send_notification('Print operation completed')
      end

      # --- Mouse side buttons -----------------------------------------------

      # A mouse with side buttons navigates the article with them, which is
      # upstream's capture-phase click gesture.
      def on_click(gesture)
        case gesture.current_button
        when BACK_BUTTON
          gesture.state = :claimed
          lookup_action('prev-page')&.activate(nil)
        when FORWARD_BUTTON
          gesture.state = :claimed
          lookup_action('next-page')&.activate(nil)
        end
      end
  end
end
