# frozen_string_literal: true

require 'gtk4'
require 'adwaita'
require 'uri'
require_relative 'about_dialog'
require_relative 'article_menu_popover'
require_relative 'bookmarks_panel'
require_relative 'data'
require_relative 'dialogs'
require_relative 'history_panel'
require_relative 'langlinks_panel'
require_relative 'main_menu_popover'
require_relative 'page_status'
require_relative 'prefs_dialog'
require_relative 'search_panel'
require_relative 'sepia_style'
require_relative 'shortcuts_dialog'
require_relative 'style'
require_relative 'toc_panel'
require_relative 'view_menu_popover'
require_relative 'wikipedia'

module Wike
  # Ported from upstream's src/application.py, plus the parts of
  # data/gtk/window.ui and src/window.py that the sidebar needs: the split
  # view, the header bar's panel selector and the panel stack.
  #
  # Upstream's startup work is here in full — the app stylesheet, the icon
  # theme, the saved colour scheme, and the app actions for the preferences,
  # the four themes, the about and shortcuts dialogs and quitting — as is its
  # quit handler, which writes the window geometry and the data stores back
  # before letting the app go.
  #
  # What is NOT here is the article view. Upstream's WikiView is a
  # WebKit.WebView subclass and the Ruby GNOME stack has no WebKit 6 binding,
  # so the tab view, the page box and the injected view stylesheets are not
  # ported yet.
  #
  # That changes one thing about this shell, and it is deliberate rather than
  # provisional: an article is opened in the user's browser through
  # Gtk::UriLauncher instead of in an embedded view. Everything either side of
  # that is the real thing — the search, the suggestions, the bookmarks, the
  # history, the table of contents and the language links are all driven by
  # the Wikipedia API for the article that is open, exactly as upstream drives
  # them from the view's load events. When the view lands, the one call that
  # launches the browser is the only line that has to move.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = 'org.rubygtkproject.Wike'

    # The sidebar pages, in the order their buttons sit on the header bar,
    # with the icon, tooltip and accelerator upstream gives each.
    PANELS = [
      ['toc', 'view-list-symbolic', 'Table of Contents', '<Ctrl>I'],
      ['search', 'system-search-symbolic', 'Search Articles', '<Ctrl>K'],
      ['langlinks', 'language-symbolic', 'Languages', '<Ctrl>L'],
      ['bookmarks', 'user-bookmarks-symbolic', 'Bookmarks', '<Ctrl>B'],
      ['history', 'document-open-recent-symbolic', 'History', '<Ctrl>H'],
    ].freeze

    # [action name, theme value in settings, colour scheme, sepia stylesheet?]
    THEMES = [
      ['theme-light', 0, :force_light, false],
      ['theme-dark', 1, :force_dark, false],
      ['theme-sepia', 2, :force_light, true],
      ['theme-system', 3, :prefer_light, false],
    ].freeze

    def build
      app.tap do
        app.signal_connect('startup') do
          Style.install
          Data.install_icons
          apply_theme(Data.settings.get_int('theme'))
          add_app_actions
        end

        app.signal_connect('activate') do
          window.tap do |win|
            win.content = toast_overlay
            win.add_breakpoint(narrow_breakpoint)
            add_window_actions(win)
          end

          toast_overlay.tap do |overlay|
            overlay.child = split_view

            split_view.tap do |view|
              view.sidebar = sidebar_toolbar
              view.content = content_toolbar
              view.signal_connect('notify::show-sidebar') { reflect_sidebar }

              sidebar_toolbar.tap do |bar|
                bar.content = panel_stack

                panel_stack.tap do |stack|
                  stack.add_named(toc_panel.build, 'toc')
                  stack.add_named(search_panel.build, 'search')
                  stack.add_named(langlinks_panel.build, 'langlinks')
                  stack.add_named(bookmarks_panel.build, 'bookmarks')
                  stack.add_named(history_panel.build, 'history')
                end
              end

              content_toolbar.tap do |bar|
                bar.add_top_bar(header_bar)
                bar.content = page_status.build

                header_bar.tap do |headerbar|
                  headerbar.pack_start(panel_selector)
                  headerbar.pack_start(panel_button)
                  headerbar.pack_end(main_button)
                  headerbar.pack_end(view_button)
                  headerbar.pack_end(article_button)

                  panel_selector.tap do |selector|
                    PANELS.each do |name, _icon, _tooltip, _accel|
                      selector.append(panel_buttons[name])
                      panel_buttons[name].signal_connect('toggled') do |button|
                        select_panel(button, name)
                      end
                    end
                  end

                  main_button.tap { |button| button.popover = main_menu_popover.build }
                  article_button.tap { |button| button.popover = article_menu_popover.build }
                  view_button.tap { |button| button.popover = view_menu_popover.build }
                end
              end
            end
          end

          search_panel.capture_keys_from(window)
          search_panel.on_languages_changed = -> { langlinks_panel.populate(@langlinks) }

          Data.settings.bind('panel-pinned', panel_button, 'active')
          Data.settings.bind('panel-page', panel_stack, 'visible-child-name')

          restore_geometry
          page_status.show(PageStatus::BLANK)
          reflect_sidebar
          refresh_article_actions
          window.present
        end
      end
    end

    def run = app.run([])

    # Show a notification with the provided message, as upstream's window
    # does for the bookmark, clipboard and print messages.
    def send_notification(message)
      Adwaita::Toast.new(message).tap do |toast|
        toast.timeout = 3
        toast_overlay.add_toast(toast)
      end
    end

    # Memoized widget methods

    # Adwaita::Application is unreliable in the Ruby bindings; the
    # application object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)
    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def sidebar_toolbar = @sidebar_toolbar ||= Adwaita::ToolbarView.new
    def content_toolbar = @content_toolbar ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def window
      @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
        win.title = 'Wike'
      end
    end

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.sidebar_width_fraction = 0.3
        view.min_sidebar_width = 260
        view.max_sidebar_width = 400
      end
    end

    # A narrow window cannot keep the sidebar beside the article, so the
    # split view collapses into an overlay and the pin action goes away.
    def narrow_breakpoint
      @narrow_breakpoint ||=
        Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse('max-width: 860px')).tap do |bp|
          bp.signal_connect('apply') { collapse_sidebar(true) }
          bp.signal_connect('unapply') { collapse_sidebar(false) }
        end
    end

    def panel_stack
      @panel_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
      end
    end

    def panel_selector
      @panel_selector ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('linked')
      end
    end

    def panel_buttons
      @panel_buttons ||= PANELS.each_with_object({}) do |(name, icon, tooltip, _accel), collected|
        collected[name] = Gtk::ToggleButton.new.tap do |button|
          button.icon_name = icon
          button.tooltip_text = tooltip
        end
      end
    end

    def panel_button
      @panel_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'sidebar-show-symbolic'
        button.tooltip_text = 'Pin Sidebar'
      end
    end

    def main_button
      @main_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
      end
    end

    def article_button
      @article_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'document-properties-symbolic'
        button.tooltip_text = 'Article Menu'
      end
    end

    def view_button
      @view_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'view-reveal-symbolic'
        button.tooltip_text = 'View Menu'
      end
    end

    def main_menu_popover = @main_menu_popover ||= MainMenuPopover.new
    def article_menu_popover = @article_menu_popover ||= ArticleMenuPopover.new
    def view_menu_popover = @view_menu_popover ||= ViewMenuPopover.new

    def toc_panel
      @toc_panel ||= TocPanel.new(
        on_section: ->(anchor) { open_section(anchor) },
        on_dismiss: -> { dismiss_sidebar },
      )
    end

    def search_panel
      @search_panel ||= SearchPanel.new(
        on_load_uri:     ->(uri) { open_article(uri) },
        on_load_message: ->(message_type) { page_status.show(message_type) },
        on_dismiss:      -> { dismiss_sidebar },
        on_show_search:  -> { panel_buttons['search'].active = true },
      )
    end

    def langlinks_panel
      @langlinks_panel ||= LanglinksPanel.new(
        on_load_uri: ->(uri) { open_article(uri) },
        on_dismiss:  -> { dismiss_sidebar },
      )
    end

    def bookmarks_panel
      @bookmarks_panel ||= BookmarksPanel.new(
        on_load_uri:     ->(uri) { open_article(uri) },
        on_dismiss:      -> { dismiss_sidebar },
        current_article: -> { @current_uri },
        on_can_add:      ->(can_add) { window.lookup_action('add-bookmark')&.enabled = can_add },
      )
    end

    def history_panel
      @history_panel ||= HistoryPanel.new(
        on_load_uri: ->(uri) { open_article(uri) },
        on_dismiss:  -> { dismiss_sidebar },
      )
    end

    def page_status
      @page_status ||= PageStatus.new(on_try_again: -> { retry_failed_article })
    end

    private

      # --- App actions ------------------------------------------------------

      def add_app_actions
        add_action(app, 'prefs', '<Ctrl>comma') { show_prefs }
        add_action(app, 'about', nil) { show_about }
        add_action(app, 'shortcuts', '<Ctrl>question') { show_shortcuts }
        add_action(app, 'quit', '<Ctrl>Q') { quit }

        THEMES.each do |name, theme, _scheme, _sepia|
          add_action(app, name, nil) { set_theme(theme) }
        end
      end

      def add_action(scope, name, accel, &callback)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { callback.call }
          scope.add_action(action)
          if accel
            scope.equal?(app).then do |on_app|
              app.set_accels_for_action("#{on_app ? 'app' : 'win'}.#{name}", [accel])
            end
          end
        end
      end

      # --- Window actions ---------------------------------------------------

      def add_window_actions(win)
        PANELS.each do |name, _icon, _tooltip, accel|
          add_action(win, "show-#{name}", accel) { panel_buttons[name].active = true }
        end

        add_action(win, 'main-page', '<Alt>Home') { open_main_page }
        add_action(win, 'random-article', '<Alt>R') { open_random_article }
        add_action(win, 'open-link', '<Alt>L') { show_open_link }
        add_action(win, 'add-bookmark', '<Ctrl>D') { add_current_bookmark }
        add_action(win, 'copy-link', '<Ctrl>U') { copy_current_link }
        add_action(win, 'open-browser', nil) { launch_current_article }
        add_pin_panel_action(win)
      end

      def add_pin_panel_action(win)
        Gio::SimpleAction.new('pin-panel', nil, GLib::Variant.new(false)).tap do |action|
          action.signal_connect('change-state') do |changed, state|
            changed.state = state
            split_view.collapsed = !state.get_boolean
          end
          win.add_action(action)
          app.set_accels_for_action('win.pin-panel', ['F9'])
          if Data.settings.get_boolean('panel-pinned')
            action.change_state(GLib::Variant.new(true))
          end
        end
      end

      # The article actions only mean anything once an article is open, which
      # is upstream's refresh_menu_actions.
      def refresh_article_actions
        %w[copy-link open-browser].each do |name|
          window.lookup_action(name)&.enabled = !@current_uri.nil?
        end
        bookmarks_panel.refresh_buttons
      end

      # --- Sidebar ----------------------------------------------------------

      # Selecting a page also opens the sidebar, and moves focus into the
      # search entry when the page selected is the search one.
      def select_panel(button, name)
        if button.active?
          panel_stack.visible_child_name = name
          unless split_view.show_sidebar?
            split_view.show_sidebar = true
          end
          if name == 'search'
            search_panel.grab_focus
          end
        end
      end

      # Keep the selector buttons in step with the sidebar: the visible
      # page's button is pressed while the sidebar is open, and none of them
      # once it is closed.
      def reflect_sidebar
        if split_view.show_sidebar?
          panel_stack.visible_child_name.then do |name|
            panel_buttons.each { |button_name, button| button.active = button_name == name }
          end
        else
          panel_buttons.each_value { |button| button.active = false }
        end
      end

      # An activation in a collapsed sidebar closes it, as upstream does.
      def dismiss_sidebar
        if split_view.collapsed?
          split_view.show_sidebar = false
        end
      end

      def collapse_sidebar(collapsed)
        window.lookup_action('pin-panel')&.enabled = !collapsed
        if collapsed
          split_view.collapsed = true
        else
          split_view.collapsed = !panel_button.active?
        end
      end

      # --- Articles ---------------------------------------------------------

      # Open an article: remember it, record it in the history, fill the
      # table of contents and the language links from the API, and hand the
      # URI to the user's browser.
      def open_article(uri)
        wiki_uri(uri.to_s).then do |link|
          if link.empty?
            show_error(uri)
          else
            @current_uri = link
            @fail_uri = link
            @current_lang = lang_of(link)
            @current_title = title_of(link)
            load_properties(link)
            launch(link)
            refresh_article_actions
          end
        end
      end

      # Jump to a section of the open article: the same article URI with the
      # section's anchor as the fragment.
      def open_section(anchor)
        if @current_uri
          launch("#{@current_uri}##{URI::DEFAULT_PARSER.escape(anchor.to_s)}")
        end
      end

      def open_main_page
        launch("https://#{Data.settings.get_string('search-language')}.wikipedia.org")
      end

      def open_random_article
        Wikipedia.get_random(Data.settings.get_string('search-language')) do |uri, failed|
          if failed
            page_status.show(PageStatus::ERROR)
          elsif uri
            open_article(uri)
          else
            page_status.show(PageStatus::NOT_FOUND)
          end
        end
      end

      # The article's title and language links come from the parse API, the
      # same call upstream makes on every committed load.
      def load_properties(uri)
        Wikipedia.get_properties(page_of(uri), lang_of(uri)) do |props, _failed|
          if props
            @current_title = props['title']
            @langlinks = props['langlinks']
            window.title = @current_title
            toc_panel.populate(@current_title, props['sections'])
            langlinks_panel.populate(@langlinks)
          else
            toc_panel.populate(@current_title, nil)
            langlinks_panel.populate(nil)
          end
          record_history
          refresh_article_actions
        end
      end

      def record_history
        if Data.settings.get_boolean('keep-history') && @current_uri
          history_panel.add_item(@current_uri, @current_title, @current_lang)
          Data.history.save
        end
      end

      def show_error(uri)
        @fail_uri = uri
        page_status.show(PageStatus::ERROR)
      end

      def retry_failed_article
        if @fail_uri
          open_article(@fail_uri)
        end
      end

      def launch_current_article
        if @current_uri
          launch(@current_uri)
        end
      end

      # The one line that an embedded article view would replace.
      def launch(uri) = Gtk::UriLauncher.new(uri: uri).launch(window, nil)

      def add_current_bookmark
        if @current_uri && bookmarks_panel.add_bookmark(@current_uri, @current_title, @current_lang)
          send_notification("Bookmark added: #{@current_title}")
        end
      end

      def copy_current_link
        if @current_uri
          Gdk::Display.default.clipboard.set(@current_uri)
          send_notification('Link copied to clipboard')
        end
      end

      # --- Wikipedia URIs --------------------------------------------------
      # Ported from the URI helpers on upstream's WikiView, which is where
      # they live because the view is what loads them.

      # Returns the article's base URI for a valid Wikipedia article link,
      # and an empty string for anything else.
      def wiki_uri(text)
        URI.parse(text).then do |uri|
          if uri.host.to_s.end_with?('.wikipedia.org')
            (uri.path.to_s.empty? ? '/' : uri.path).then do |path|
              if path.start_with?('/wiki/') || path == '/'
                "#{uri.scheme || 'https'}://#{uri.host}#{path}"
              else
                ''
              end
            end
          else
            ''
          end
        end
      rescue URI::InvalidURIError
        ''
      end

      def lang_of(uri) = URI.parse(uri).host.to_s.split('.', 2).first
      def page_of(uri) = URI.parse(uri).path.to_s.sub(%r{\A/wiki/}, '')

      # Upstream derives a provisional title from the URI, which stands until
      # the parse API returns the real one.
      def title_of(uri)
        URI::DEFAULT_PARSER.unescape(page_of(uri)).tr('_', ' ')
      end

      # --- Themes -----------------------------------------------------------

      def set_theme(theme)
        apply_theme(theme)
        Data.settings.set_int('theme', theme)
      end

      # Sepia is the light scheme plus the sepia stylesheet; every other
      # theme takes that stylesheet off again.
      def apply_theme(theme)
        (THEMES.find { |_name, value, _scheme, _sepia| value == theme } || THEMES.last)
          .then do |_name, _value, scheme, sepia|
            style_manager.color_scheme = scheme
            if sepia
              SepiaStyle.install
            else
              SepiaStyle.remove
            end
          end
      end

      # --- Dialogs ----------------------------------------------------------

      def show_prefs
        PrefsDialog.new(
          on_clear_history: -> { history_panel.clear_history },
          on_clear_data:    -> { send_notification('No cached article data to clear') },
        ).build.present(window)
      end

      def show_about = AboutDialog.new.build.present(window)
      def show_shortcuts = ShortcutsDialog.new.build.present(window)

      # The entry accepts a link only once it parses as a Wikipedia article
      # URL; anything else marks the entry and leaves the dialog open.
      def show_open_link
        Dialogs::OpenLinkDialog.new.build.tap do |dialog|
          dialog.link_entry.signal_connect('changed') { dialog.clear_error }
          dialog.link_entry.signal_connect('apply') do |entry|
            wiki_uri(entry.text).then do |link|
              if link.empty?
                dialog.reject_link
              else
                dialog.close
                open_article(link)
              end
            end
          end
          dialog.present(window)
        end
      end

      # --- Shutdown ---------------------------------------------------------

      def restore_geometry
        window.set_default_size(
          Data.settings.get_int('window-width'),
          Data.settings.get_int('window-height'),
        )
        if Data.settings.get_boolean('window-max')
          window.maximize
        end
      end

      # Upstream's quit handler: record the geometry and the last article,
      # drop the history if the user asked not to keep it, flush the settings
      # and the data stores, then let the app go.
      def quit
        save_geometry
        Data.settings.set_string('last-uri', @current_uri.to_s)
        unless Data.settings.get_boolean('keep-history')
          Data.history.clear
        end
        Data.settings.sync
        Data.languages.save
        Data.history.save
        Data.bookmarks.save
        app.quit
      end

      def save_geometry
        window.maximized?.then do |maximized|
          Data.settings.set_boolean('window-max', maximized)
          unless maximized
            Data.settings.set_int('window-width', window.default_width)
            Data.settings.set_int('window-height', window.default_height)
          end
        end
      end
  end
end
