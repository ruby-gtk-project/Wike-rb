# frozen_string_literal: true

# Drives the real window: the icon bar, the five sidebar panels, the tab
# view, the three header-bar menus, the preferences, languages, about and
# shortcuts dialogs, and the data stores behind the bookmarks and history
# panels.
#
# Run with: nix develop --command xvfb-run -a ruby test/drive_main_window.rb

require 'tmpdir'
require 'fileutils'

scratch = Dir.mktmpdir('wike-drive')
ENV['XDG_CONFIG_HOME'] = File.join(scratch, 'config')
ENV['XDG_DATA_HOME'] = File.join(scratch, 'data')

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'wike'
require 'wike/shell_search_provider'
require_relative 'gtk_driver'

# Seed the stores so the panels have something to show.
FileUtils.mkdir_p(File.join(scratch, 'data', 'wike-rb'))
File.write(
  File.join(
    scratch,
    'data',
    'wike-rb',
    'bookmarks.json',
  ),
  '{"https://en.wikipedia.org/wiki/Ruby":["Ruby","en"],' \
  '"https://es.wikipedia.org/wiki/Madrid":["Madrid","es"]}',
)
File.write(
  File.join(
    scratch,
    'data',
    'wike-rb',
    'booklists.json',
  ),
  '{"Programming":{"https://en.wikipedia.org/wiki/GTK":["GTK","en"]}}',
)
# Seeded at the script's own start time rather than a fixed clock value, so
# the 'newest article sorts first' check below (which adds a second item
# later, at whatever the real current time is by then) is guaranteed to see
# the seeded item as older — real time only moves forward from here — and
# is not at the mercy of what time of day the suite happens to run.
seeded_at = Time.now
File.write(
  File.join(
    scratch,
    'data',
    'wike-rb',
    'historic.json',
  ),
  "{\"#{seeded_at.strftime('%Y-%m-%d')}\":" \
  "{\"https://en.wikipedia.org/wiki/GNOME\":[\"#{seeded_at.strftime('%H:%M:%S')}\"," \
  '"GNOME","en",' \
  "\"#{seeded_at.strftime('%Y-%m-%d %H:%M:%S')}\"]}}",
)

SECTIONS = [
  { 'line' => 'History', 'anchor' => 'History', 'toclevel' => 1 },
  { 'line' => 'Early years', 'anchor' => 'Early_years', 'toclevel' => 2 },
  { 'line' => 'Syntax', 'anchor' => 'Syntax', 'toclevel' => 1 },
].freeze

LANGLINKS = [
  {
    'lang'    => 'es',
    'autonym' => 'español',
    'url'     => 'https://es.wikipedia.org/wiki/Rub%C3%AD',
    '*'       => 'Rubí',
  },
  {
    'lang'    => 'ja',
    'autonym' => '日本語',
    'url'     => 'https://ja.wikipedia.org/wiki/Ruby',
    '*'       => 'Ruby',
  },
  {
    'lang'    => 'fy',
    'autonym' => 'Frysk',
    'url'     => 'https://fy.wikipedia.org/wiki/Ruby',
    '*'       => 'Ruby',
  },
].freeze

# Runs xdotool against the display the driver is already on, quietly.
def xdotool(*args)
  system('xdotool', *args, out: File::NULL, err: File::NULL)
end

def rows_of(list_box)
  [].tap do |collected|
    index = 0
    while (row = list_box.get_row_at_index(index))
      collected << row
      index += 1
    end
  end
end

GtkDriver.drive(Wike::Application.new, shots: 'tmp/shots') do |d, app|
  d.window { app.window }

  d.step('the window opens with one blank tab') do
    d.check('window has a title') { app.window.title == 'Wike' }
    d.check('one tab is open') { app.window.tabview.n_pages == 1 }
    d.check('five sidebar pages') { app.window.panel_stack.pages.n_items == 5 }
    d.shot('01-start')
  end

  # GTK4 has no public way to forge a Gdk key event
  # (gtk_event_controller_key_forward asserts on a NULL current event), so
  # the one keyboard shortcut this drive fires as a real keystroke, rather
  # than by activating its action directly, goes through xdotool against the
  # Xvfb display this run is already on. `^Wike$` is unambiguous because the
  # window's title is still the bare app name at this point in the run.
  d.step('Ctrl+T is pressed as a real key combo, not an action activation') do
    d.check('xdotool is on PATH to drive the keyboard with') { xdotool('--version') }
    xdotool('search', '--name', '^Wike$', 'windowfocus', '--sync')
    xdotool('key', '--clearmodifiers', 'ctrl+t')
  end

  d.step('the real keypress reached win.new-tab, not just its action') do
    d.check('a second tab opened from the keyboard') { app.window.tabview.n_pages == 2 }
    app.window.lookup_action('close-tab').activate(nil)
  end

  d.step('closing it again leaves a single tab, as before the keypress') do
    d.check('back to one tab') { app.window.tabview.n_pages == 1 }
  end

  d.step('the table of contents fills from section data') do
    app.window.toc_panel.populate('Ruby (programming language)', SECTIONS)
  end

  d.step('the toc shows one row per section, indented by depth') do
    rows_of(app.window.toc_panel.toc_list).then do |rows|
      d.check('three section rows') { rows.length == 3 }
      d.check('top level sits at 3px') { rows[0].section_label.margin_start == 3 }
      d.check('second level sits at 18px') { rows[1].section_label.margin_start == 18 }
      d.check('second level is captioned') do
        rows[1].section_label.has_css_class?('caption')
      end
    end
    d.check('title label is set') do
      app.window.toc_panel.title_label.label == 'Ruby (programming language)'
    end
    app.window.panel_buttons['toc'].active = true
    d.shot('02-toc')
  end

  d.step('the language links fill, user languages first') do
    app.window.langlinks_panel.populate(LANGLINKS)
  end

  d.step('only the user languages show while the filter is on Your languages') do
    rows_of(app.window.langlinks_panel.langlinks_list).then do |rows|
      # The user list is just `en`, and none of the three links is English,
      # so the user-languages filter leaves the list empty.
      d.check('no rows under the user-languages filter') { rows.empty? }
    end
    app.window.panel_buttons['langlinks'].active = true
    d.shot('03-langlinks-user')
  end

  d.step('switching the filter to All languages reveals the rest') do
    app.window.langlinks_panel.filter_dropdown.selected = 1
  end

  d.step('all three languages show under a heading') do
    rows_of(app.window.langlinks_panel.langlinks_list).then do |rows|
      d.check('three links plus a heading row') { rows.length == 4 }
      d.check('the heading row is not activatable') do
        rows.any? { |row| !row.activatable? }
      end
      d.check('spanish autonym is capitalised') do
        rows.any? { |row| row.respond_to?(:lang_name) && row.lang_name == 'Español' }
      end
      d.check('spanish flag emblem resolved') do
        rows.any? { |row| row.respond_to?(:flag_image) && row.flag_image.icon_name == 'es' }
      end
    end
    d.shot('04-langlinks-all')
  end

  d.step('the bookmarks panel loaded the default reading list') do
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('two bookmarks') { rows.length == 2 }
      d.check('sorted by title: Madrid before Ruby') do
        rows.map(&:title) == ['Madrid', 'Ruby']
      end
      d.check('language name resolved from the bundled list') do
        rows.first.lang_label.label == 'Español'
      end
    end
    d.check('two lists in the dropdown') do
      app.window.bookmarks_panel.booklists_model.n_items == 2
    end
    app.window.panel_buttons['bookmarks'].active = true
    d.shot('05-bookmarks')
  end

  d.step('selecting the named list swaps the bookmarks over') do
    app.window.bookmarks_panel.booklists_dropdown.selected = 1
  end

  d.step('the named list shows its own bookmark') do
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('one bookmark in Programming') { rows.length == 1 }
      d.check('it is GTK') { rows.first.title == 'GTK' }
    end
    d.shot('06-booklist')
  end

  d.step('adding a bookmark directly appends a row and leaves select mode') do
    app.window.bookmarks_panel.selection_button.active = true
    d.check('added returns true') do
      app.window.bookmarks_panel.add_bookmark(
        'https://en.wikipedia.org/wiki/Rake_(software)',
        'Rake',
        'en',
      )
    end
  end

  d.step('the new bookmark is in the list and select mode dropped') do
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('two bookmarks in Programming now') { rows.length == 2 }
      d.check('Rake is one of them') { rows.map(&:title).include?('Rake') }
    end
    d.check('selection mode turned off by the add') do
      !app.window.bookmarks_panel.selection_button.active?
    end
  end

  d.step('turning on selection mode reveals the action bar') do
    app.window.bookmarks_panel.selection_button.active = true
  end

  d.step('select all marks every row, select none clears them') do
    app.window.bookmarks_panel.select_all_button.signal_emit('clicked')
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('select all checked every row') { rows.all? { |row| row.select_check.active? } }
    end
    app.window.bookmarks_panel.select_none_button.signal_emit('clicked')
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('select none cleared every row') { rows.none? { |row| row.select_check.active? } }
    end
    rows_of(app.window.bookmarks_panel.bookmarks_list).first.select_check.active = true
    d.shot('06a-bookmarks-select-mode')
  end

  d.step('removing the marked bookmark deletes it and saves') do
    app.window.bookmarks_panel.remove_button.signal_emit('clicked')
  end

  d.step('one bookmark remains in Programming, selection mode off') do
    rows_of(app.window.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('back to one bookmark') { rows.length == 1 }
    end
  end

  d.step('the overflow menu opens and rename is disabled on the default list') do
    app.window.bookmarks_panel.booklists_dropdown.selected = 0
    app.window.bookmarks_panel.menu_button.popup
  end

  d.step('rename-list is disabled while the default reading list is selected') do
    d.check('menu popover is visible') { app.window.bookmarks_panel.menu_popover.visible? }
    d.check('rename-list disabled on the default list') do
      !app.window.bookmarks_panel.actions.lookup_action('rename-list').enabled?
    end
    app.window.bookmarks_panel.menu_popover.popdown
    app.window.bookmarks_panel.booklists_dropdown.selected = 1
  end

  d.step('create-list opens the new-list dialog') do
    app.window.bookmarks_panel.actions.lookup_action('create-list').activate(nil)
  end

  d.step('an empty name leaves Create disabled, a fresh name enables it') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the new-booklist dialog') { dialog.is_a?(Wike::Dialogs::NewBooklistDialog) }
      d.check('Create starts disabled on an empty name') do
        !dialog.get_response_enabled(Wike::Dialogs::CREATE)
      end
      dialog.name_entry.text = 'Programming'
      dialog.name_entry.signal_emit('changed')
      d.check('a name already taken keeps Create disabled') do
        !dialog.get_response_enabled(Wike::Dialogs::CREATE)
      end
      d.check('a taken name marks the entry as an error') do
        dialog.name_entry.has_css_class?('error')
      end
      dialog.name_entry.text = 'Gems'
      dialog.name_entry.signal_emit('changed')
      d.check('a fresh name enables Create') { dialog.get_response_enabled(Wike::Dialogs::CREATE) }
      d.shot('06b-new-booklist')
      dialog.signal_emit('response', Wike::Dialogs::CREATE)
      dialog.close
    end
  end

  d.step('the new list exists and is selected') do
    d.check('three lists in the dropdown now') do
      app.window.bookmarks_panel.booklists_model.n_items == 3
    end
    d.check('Gems is the selected list') do
      app.window.bookmarks_panel.booklists_dropdown.selected_item.string == 'Gems'
    end
    d.check('the new list starts empty') { rows_of(app.window.bookmarks_panel.bookmarks_list).empty? }
  end

  d.step('rename-list opens the rename dialog pre-filled with the current name') do
    # Reopen the overflow menu first: it is what flips rename-list back to
    # enabled now that a renameable list is selected, exactly as it did (to
    # disabled) in the earlier default-list check.
    panel = app.window.bookmarks_panel
    panel.menu_button.popup
    panel.menu_popover.popdown
    panel.actions.lookup_action('rename-list').activate(nil)
  end

  d.step('renaming to Ruby Gems swaps the dropdown entry over') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the rename dialog') { dialog.is_a?(Wike::Dialogs::RenameBooklistDialog) }
      d.check('pre-filled with the current name') { dialog.name_entry.text == 'Gems' }
      dialog.name_entry.text = 'Ruby Gems'
      dialog.name_entry.signal_emit('changed')
      dialog.signal_emit('response', Wike::Dialogs::RENAME)
      dialog.close
    end
    d.check('the dropdown now shows the new name') do
      app.window.bookmarks_panel.booklists_dropdown.selected_item.string == 'Ruby Gems'
    end
  end

  d.step('clear-list opens the clear-booklist dialog with delete enabled') do
    app.window.bookmarks_panel.actions.lookup_action('clear-list').activate(nil)
  end

  d.step('confirming clear with delete checked removes the list entirely') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('delete checkbox is enabled for a non-default list') do
        dialog.delete_booklist_check.sensitive?
      end
      dialog.delete_booklist_check.active = true
      d.shot('06c-clear-booklist')
      dialog.signal_emit('response', Wike::Dialogs::CLEAR)
      dialog.close
    end
    d.check('back to the original two lists') do
      app.window.bookmarks_panel.booklists_model.n_items == 2
    end
    d.check('selection fell back to the default reading list') do
      app.window.bookmarks_panel.booklists_dropdown.selected.zero?
    end
  end

  d.step('the history panel loaded today’s article') do
    rows_of(app.window.history_panel.history_list).then do |rows|
      d.check('a date heading and an article row') { rows.length == 2 }
      d.check('date heading is not activatable') { !rows[0].activatable? }
      d.check('article row shows hours and minutes only') do
        rows[1].time == seeded_at.strftime('%H:%M')
      end
      d.check('article title') { rows[1].title == 'GNOME' }
    end
    app.window.panel_buttons['history'].active = true
    d.shot('07-history')
  end

  d.step('adding a history item directly appends it, newest heading first') do
    app.window.history_panel.add_item(
      'https://en.wikipedia.org/wiki/Matz',
      'Matz',
      'en',
    )
  end

  d.step('the new article shows under today, ahead of the seeded one') do
    rows_of(app.window.history_panel.history_list).then do |rows|
      d.check('still one date heading, now two articles') { rows.length == 3 }
      d.check('the newest article sorts first') { rows[1].title == 'Matz' }
    end
  end

  d.step('turning on selection mode reveals the history action bar') do
    app.window.history_panel.selection_button.active = true
  end

  d.step('select all marks every article row, select none clears them') do
    app.window.history_panel.select_all_button.signal_emit('clicked')
    rows_of(app.window.history_panel.history_list).then do |rows|
      article_rows = rows.select(&:activatable?)
      d.check('select all checked every article row') do
        article_rows.all? { |row| row.select_check.active? }
      end
    end
    app.window.history_panel.select_none_button.signal_emit('clicked')
    rows_of(app.window.history_panel.history_list).then do |rows|
      article_rows = rows.select(&:activatable?)
      d.check('select none cleared every article row') do
        article_rows.none? { |row| row.select_check.active? }
      end
      article_rows.find { |row| row.title == 'Matz' }.select_check.active = true
    end
    d.shot('07a-history-select-mode')
  end

  d.step('removing the marked article leaves the seeded one behind') do
    app.window.history_panel.remove_button.signal_emit('clicked')
  end

  d.step('back to the single seeded article, selection mode off') do
    rows_of(app.window.history_panel.history_list).then do |rows|
      d.check('a date heading and the one remaining article') { rows.length == 2 }
      d.check('it is the seeded GNOME article') { rows[1].title == 'GNOME' }
    end
  end

  d.step('the clear-history button opens the confirmation dialog') do
    app.window.history_panel.clear_button.signal_emit('clicked')
  end

  d.step('confirming clear empties the history entirely') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the clear-history dialog') { dialog.is_a?(Wike::Dialogs::ClearHistoryDialog) }
      d.shot('07b-clear-history')
      dialog.signal_emit('response', Wike::Dialogs::CLEAR)
      dialog.close
    end
  end

  d.step('the history list is empty') do
    d.check('no rows left') { rows_of(app.window.history_panel.history_list).empty? }
  end

  d.step('the empty-history placeholder is on screen, one tick later') do
    d.check('placeholder widget is set') { !app.window.history_panel.placeholder.nil? }
    d.check('placeholder is visible') { app.window.history_panel.placeholder.visible? }
    d.check('placeholder names the empty state') do
      app.window.history_panel.placeholder.title == 'Empty History'
    end
    d.check('placeholder is actually mapped on screen') do
      app.window.history_panel.placeholder.mapped?
    end
    d.shot('07c-history-empty')
  end

  d.step('the search page takes focus when selected') do
    app.window.panel_buttons['search'].active = true
  end

  d.step('the search settings popover knows the language') do
    d.check('search page is showing') { app.window.panel_stack.visible_child_name == 'search' }
    d.check('language button is labelled en') { app.window.search_panel.settings_button.label == 'en' }
    d.check('tooltip names the language') do
      app.window.search_panel.settings_button.tooltip_text == 'English'
    end
    rows_of(app.window.search_panel.settings_popover.languages_list).then do |rows|
      d.check('one user language row') { rows.length == 1 }
      d.check('it carries the checkmark') do
        rows.first.check_image.icon_name == 'checkmark-symbolic'
      end
    end
    d.shot('08-search')
  end

  d.step('the zoom control reflects and changes the setting') do
    app.window.view_menu_popover.zoom_level.zoom_in_button.signal_emit('clicked')
  end

  d.step('zooming in moved the setting and the label') do
    d.check('setting is 110') { Wike::Data.settings.get_int('zoom-level') == 110 }
    d.check('label is 110%') do
      app.window.view_menu_popover.zoom_level.zoom_value_button.label == '110%'
    end
    d.check('reset button became sensitive') do
      app.window.view_menu_popover.zoom_level.zoom_value_button.sensitive?
    end
  end

  d.step('the theme switcher activates the app action') do
    app.window.view_menu_popover.theme_switcher.buttons[:dark].active = true
  end

  d.step('picking dark recorded the theme') do
    d.check('theme setting is 1') { Wike::Data.settings.get_int('theme') == 1 }
    d.shot('09-dark')
  end

  d.step('the main menu popover opens from the hamburger button') do
    app.window.main_button.popup
  end

  d.step('it is showing, wired to the app actions it lists') do
    d.check('popover is visible') { app.window.main_menu_popover.visible? }
    d.check('three items declared') { Wike::MainMenuPopover::ITEMS.length == 3 }
    d.check('app.prefs exists') { !app.app.lookup_action('prefs').nil? }
    d.check('app.shortcuts exists') { !app.app.lookup_action('shortcuts').nil? }
    d.check('app.about exists') { !app.app.lookup_action('about').nil? }
    app.window.main_menu_popover.popdown
  end

  d.step('the article menu popover opens from the article button') do
    app.window.article_button.popup
  end

  d.step('it is showing, wired to the window actions it lists') do
    d.check('popover is visible') { app.window.article_menu_popover.visible? }
    d.check('two button items, two sections') do
      Wike::ArticleMenuPopover::BUTTONS.length == 2 &&
        Wike::ArticleMenuPopover::SECTIONS.length == 2
    end
    %w[print-page search-text main-page random-article open-link open-browser
       copy-link].each do |action|
      d.check("win.#{action} exists") { !app.window.lookup_action(action).nil? }
    end
    app.window.article_menu_popover.popdown
  end

  # win.search-text is one of ARTICLE_ACTIONS, which refresh_menu_actions
  # disables while the current tab is a status page rather than a live
  # article — exactly the state a network-free drive run is in — so this
  # calls the page box's own method instead of going through the
  # (possibly disabled) action, the same way `d.step` elsewhere calls
  # `show_prefs`/`show_about` directly rather than their menu actions.
  d.step('the in-article search bar opens on the current page') do
    app.window.page.show_text_search
  end

  d.step('it is showing, ready to type into') do
    d.check('search bar is in search mode') { app.window.page.search_bar.search_mode? }
    app.window.page.search_bar.search_mode = false
  end

  d.step('the status page runs through its three message states') do
    status = Wike::PageStatus.new(on_try_again: -> {})
    status.build

    status.show(Wike::PageStatus::BLANK)
    d.check('blank state invites a search') { status.status_page.title == 'Search Wikipedia' }
    d.check('blank state offers the main page and a random article') do
      status.main_page_button.visible? && status.random_article_button.visible?
    end

    status.show(Wike::PageStatus::NOT_FOUND)
    d.check('not-found state names the failed query') do
      status.status_page.title == 'Article not Found'
    end
    d.check('not-found state has no try-again button') { !status.try_again_button.visible? }

    status.show(Wike::PageStatus::ERROR)
    d.check('error state names the connection problem') do
      status.status_page.title == 'Can’t Access Wikipedia'
    end
    d.check('error state offers try-again and nothing else') do
      status.try_again_button.visible? && !status.main_page_button.visible?
    end
  end

  d.step('the shell search provider answers a query without the window') do
    Wike::Data.settings.set_boolean('search-desktop', false)
    provider = Wike::ShellSearchProvider.new

    results = provider.get_initial_result_set(%w[ruby programming])
    d.check('a fallback web-search result for the typed terms') do
      results == ["search:en:ruby programming"]
    end

    metas = provider.get_result_metas(results)
    d.check('the result meta carries the quoted search text') do
      metas.length == 1 && metas.first[1].include?('ruby programming')
    end

    d.check('too-short a query clears the results') do
      provider.get_initial_result_set(['a']).empty?
    end

    d.check('a language prefix is recognised and stripped') do
      provider.get_initial_result_set(%w[-es madrid]).first.start_with?('search:es:')
    end
  end

  d.step('a second tab opens') do
    app.window.lookup_action('new-tab').activate(nil)
  end

  d.step('the tab view now has two pages') do
    d.check('two tabs open') { app.window.tabview.n_pages == 2 }
    d.shot('10-new-tab')
  end

  d.step('closing the tab returns to one') do
    app.window.lookup_action('close-tab').activate(nil)
  end

  d.step('one tab remains') do
    d.check('one tab open') { app.window.tabview.n_pages == 1 }
  end

  d.step('the preferences dialog opens') do
    app.send(:show_prefs)
  end

  d.step('preferences show the bound settings') do
    d.check('a dialog is up') { !app.window.visible_dialog.nil? }
    d.shot('11-prefs')
    app.window.visible_dialog.close
  end

  d.step('the languages dialog opens from the search settings') do
    app.window.search_panel.settings_popover.languages_button.signal_emit('clicked')
  end

  d.step('the languages dialog lists every Wikipedia language') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the language picker') { dialog.is_a?(Wike::LanguagesDialog) }
      d.check('selected label counts the picks') do
        dialog.selected_label.label == '1 language selected'
      end
      d.check('over 300 languages listed') do
        rows_of(dialog.languages_list).length > 300
      end
      d.shot('12-languages')
      dialog.close
    end
  end

  d.step('the about dialog opens') do
    app.send(:show_about)
  end

  d.step('about names the app and the port version') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('application name') { dialog.application_name == 'Wike' }
      d.shot('13-about')
      dialog.close
    end
  end

  d.step('the shortcuts dialog opens') do
    app.send(:show_shortcuts)
  end

  d.step('shortcuts lists four sections') do
    d.check('a dialog is up') { !app.window.visible_dialog.nil? }
    d.check('four sections built') { Wike::ShortcutsDialog.new.sections.length == 4 }
    d.shot('14-shortcuts')
    app.window.visible_dialog.close
  end

  d.step('the open-link dialog validates Wikipedia URLs') do
    app.window.lookup_action('open-link').activate(nil)
  end

  d.step('a bad link is rejected, a good one parses') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('a non-wikipedia host is rejected') do
        Wike::WikiView.wiki_uri('https://example.com/wiki/Ruby').empty?
      end
      d.check('an article URL is accepted') do
        Wike::WikiView.wiki_uri('https://en.wikipedia.org/wiki/Ruby?x=1#frag') ==
          'https://en.wikipedia.org/wiki/Ruby'
      end
      d.check('a bare host is accepted as the main page') do
        Wike::WikiView.wiki_uri('https://en.wikipedia.org') == 'https://en.wikipedia.org/'
      end
      d.shot('15-open-link')
      dialog.close
    end
  end

  d.step('closing the sidebar unpresses every selector button') do
    app.window.panel_split.show_sidebar = false
  end

  d.step('no selector button is pressed with the sidebar closed') do
    d.check('all unpressed') { app.window.panel_buttons.each_value.none?(&:active?) }
    d.shot('16-sidebar-closed')
  end
end
