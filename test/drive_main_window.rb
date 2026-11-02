# frozen_string_literal: true

# Drives the app shell: the five sidebar pages, the three header-bar menus,
# the preferences, languages, about and shortcuts dialogs, and the data
# stores behind the bookmarks and history panels.
#
# Run with: nix develop --command xvfb-run -a ruby test/drive_main_window.rb

require 'tmpdir'
require 'fileutils'

scratch = Dir.mktmpdir('wike-drive')
ENV['XDG_CONFIG_HOME'] = File.join(scratch, 'config')
ENV['XDG_DATA_HOME'] = File.join(scratch, 'data')

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'wike'
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
File.write(
  File.join(
    scratch,
    'data',
    'wike-rb',
    'historic.json',
  ),
  "{\"#{Time.now.strftime('%Y-%m-%d')}\":" \
  '{"https://en.wikipedia.org/wiki/GNOME":["12:30:00","GNOME","en"]}}',
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

  d.step('the window and the sidebar build') do
    d.check('window has a title') { app.window.title == 'Wike' }
    d.check('five sidebar pages') { app.panel_stack.pages.n_items == 5 }
    d.check('content is the status page') { app.content_toolbar.content == app.page_status }
    d.check('status page says Search Wikipedia') do
      app.page_status.status_page.title == 'Search Wikipedia'
    end
    d.shot('01-start')
  end

  d.step('the table of contents fills from section data') do
    app.toc_panel.populate('Ruby (programming language)', SECTIONS)
  end

  d.step('the toc shows one row per section, indented by depth') do
    rows_of(app.toc_panel.toc_list).then do |rows|
      d.check('three section rows') { rows.length == 3 }
      d.check('top level sits at 3px') { rows[0].section_label.margin_start == 3 }
      d.check('second level sits at 18px') { rows[1].section_label.margin_start == 18 }
      d.check('second level is captioned') do
        rows[1].section_label.has_css_class?('caption')
      end
    end
    d.check('title label is set') do
      app.toc_panel.title_label.label == 'Ruby (programming language)'
    end
    app.panel_buttons['toc'].active = true
    d.shot('02-toc')
  end

  d.step('the language links fill, user languages first') do
    app.langlinks_panel.populate(LANGLINKS)
  end

  d.step('only the user languages show while the filter is on Your languages') do
    rows_of(app.langlinks_panel.langlinks_list).then do |rows|
      # The user list is just `en`, and none of the three links is English,
      # so the user-languages filter leaves the list empty.
      d.check('no rows under the user-languages filter') { rows.empty? }
    end
    app.panel_buttons['langlinks'].active = true
    d.shot('03-langlinks-user')
  end

  d.step('switching the filter to All languages reveals the rest') do
    app.langlinks_panel.filter_dropdown.selected = 1
  end

  d.step('all three languages show under a heading') do
    rows_of(app.langlinks_panel.langlinks_list).then do |rows|
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
    rows_of(app.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('two bookmarks') { rows.length == 2 }
      d.check('sorted by title: Madrid before Ruby') do
        rows.map(&:title) == ['Madrid', 'Ruby']
      end
      d.check('language name resolved from the bundled list') do
        rows.first.lang_label.label == 'Español'
      end
    end
    d.check('two lists in the dropdown') do
      app.bookmarks_panel.booklists_model.n_items == 2
    end
    app.panel_buttons['bookmarks'].active = true
    d.shot('05-bookmarks')
  end

  d.step('selecting the named list swaps the bookmarks over') do
    app.bookmarks_panel.booklists_dropdown.selected = 1
  end

  d.step('the named list shows its own bookmark') do
    rows_of(app.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('one bookmark in Programming') { rows.length == 1 }
      d.check('it is GTK') { rows.first.title == 'GTK' }
    end
    d.shot('06-booklist')
  end

  d.step('selection mode reveals the check buttons') do
    app.bookmarks_panel.selection_button.active = true
  end

  d.step('the action bar is revealed with the checks') do
    d.check('action bar revealed') { app.bookmarks_panel.action_bar.revealed? }
    rows_of(app.bookmarks_panel.bookmarks_list).then do |rows|
      d.check('check button visible') { rows.first.select_check.visible? }
    end
    d.shot('07-selection-mode')
  end

  d.step('the history panel loaded today’s article') do
    rows_of(app.history_panel.history_list).then do |rows|
      d.check('a date heading and an article row') { rows.length == 2 }
      d.check('date heading is not activatable') { !rows[0].activatable? }
      d.check('article row shows hours and minutes only') { rows[1].time == '12:30' }
      d.check('article title') { rows[1].title == 'GNOME' }
    end
    app.panel_buttons['history'].active = true
    d.shot('08-history')
  end

  d.step('the search page takes focus when selected') do
    app.panel_buttons['search'].active = true
  end

  d.step('the search settings popover knows the language') do
    d.check('search page is showing') { app.panel_stack.visible_child_name == 'search' }
    d.check('language button is labelled en') { app.search_panel.settings_button.label == 'en' }
    d.check('tooltip names the language') do
      app.search_panel.settings_button.tooltip_text == 'English'
    end
    rows_of(app.search_panel.settings_popover.languages_list).then do |rows|
      d.check('one user language row') { rows.length == 1 }
      d.check('it carries the checkmark') do
        rows.first.check_image.icon_name == 'checkmark-symbolic'
      end
    end
    d.shot('09-search')
  end

  d.step('the zoom control reflects and changes the setting') do
    app.view_menu_popover.zoom_level.zoom_in_button.signal_emit('clicked')
  end

  d.step('zooming in moved the setting and the label') do
    d.check('setting is 110') { Wike::Data.settings.get_int('zoom-level') == 110 }
    d.check('label is 110%') do
      app.view_menu_popover.zoom_level.zoom_value_button.label == '110%'
    end
    d.check('reset button became sensitive') do
      app.view_menu_popover.zoom_level.zoom_value_button.sensitive?
    end
  end

  d.step('the theme switcher activates the app action') do
    app.view_menu_popover.theme_switcher.buttons[:dark].active = true
  end

  d.step('picking dark recorded the theme') do
    d.check('theme setting is 1') { Wike::Data.settings.get_int('theme') == 1 }
    d.shot('10-dark')
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
    app.search_panel.settings_popover.languages_button.signal_emit('clicked')
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
    app.send(:show_open_link)
  end

  d.step('a bad link is rejected, a good one parses') do
    app.window.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('a non-wikipedia host is rejected') do
        app.send(:wiki_uri, 'https://example.com/wiki/Ruby').empty?
      end
      d.check('an article URL is accepted') do
        app.send(:wiki_uri, 'https://en.wikipedia.org/wiki/Ruby?x=1#frag') ==
          'https://en.wikipedia.org/wiki/Ruby'
      end
      d.check('a bare host is accepted as the main page') do
        app.send(:wiki_uri, 'https://en.wikipedia.org') == 'https://en.wikipedia.org/'
      end
      d.shot('15-open-link')
      dialog.close
    end
  end

  d.step('closing the sidebar unpresses every selector button') do
    app.split_view.show_sidebar = false
  end

  d.step('no selector button is pressed with the sidebar closed') do
    d.check('all unpressed') { app.panel_buttons.each_value.none?(&:active?) }
    d.shot('16-sidebar-closed')
  end
end
