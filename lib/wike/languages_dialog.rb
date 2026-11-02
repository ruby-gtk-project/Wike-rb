# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'languages_row'

module Wike
  # Ported from upstream's LanguagesDialog in src/languages.py and
  # data/gtk/languages.ui.
  #
  # The "Pick your Languages" dialog: every language Wikipedia publishes in,
  # each with a check button, filtered by a search bar, with select-all and
  # select-none buttons and a running count of the picks.
  #
  # The picks are written back on close, not as they are made — upstream
  # rebuilds the whole user language list from the check buttons in the
  # dialog's `closed` handler, and only if something actually changed. The
  # host is told through the on_changed callback so it can repopulate the
  # places the language list shows up.
  class LanguagesDialog < Adwaita::Dialog
    def initialize(on_changed:)
      super()
      @on_changed = on_changed
      @languages_changed = false
      @languages_selected = 0
    end

    def build
      tap do |dialog|
        dialog.title = 'Pick your Languages'
        dialog.content_height = 500
        dialog.content_width = 380
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.add_top_bar(search_bar)
          view.add_bottom_bar(action_bar)
          view.content = scroller

          header_bar.tap do |bar|
            bar.pack_start(search_button)
          end

          search_bar.tap do |bar|
            bar.child = languages_entry
            bar.set_key_capture_widget(dialog)
            # The layout binds the toggle and the search bar in both
            # directions, so the button reflects an Escape that closed the bar.
            search_button.bind_property(

              'active',

              bar,

              'search-mode-enabled',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::BIDIRECTIONAL,

            )
          end

          action_bar.tap do |bar|
            bar.pack_start(select_all_button)
            bar.pack_start(select_none_button)
            bar.pack_end(selected_label)
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = languages_list

              languages_list.tap do |list|
                list.set_filter_func { |row| matches_filter?(row) }
                list.signal_connect('row-activated') do |_list, row|
                  row.lang_check.active = !row.lang_check.active?
                end
              end
            end
          end
        end

        languages_entry.signal_connect('search-changed') { languages_list.invalidate_filter }
        select_all_button.signal_connect('clicked') { set_all(true) }
        select_none_button.signal_connect('clicked') { set_all(false) }
        dialog.signal_connect('closed') { commit }

        populate
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def search_bar = @search_bar ||= Gtk::SearchBar.new
    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)
    def action_bar = @action_bar ||= Gtk::ActionBar.new

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'system-search-symbolic'
        button.tooltip_text = 'Search Languages'
      end
    end

    def languages_entry
      @languages_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = 'Search languages'
        entry.max_width_chars = 20
      end
    end

    def languages_list
      @languages_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def select_all_button
      @select_all_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'edit-select-all-symbolic'
        button.tooltip_text = 'Select All'
      end
    end

    def select_none_button
      @select_none_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'edit-select-none-symbolic'
        button.tooltip_text = 'Select None'
      end
    end

    def selected_label
      @selected_label ||= Gtk::Label.new.tap do |label|
        label.margin_end = 9
      end
    end

    private

      def populate
        Data.languages.then do |languages|
          languages.wikilangs.keys.sort.each do |lang_id|
            Data.capitalize(languages.wikilangs[lang_id]).then do |lang_name|
              languages.items.key?(lang_id).then do |checked|
                if checked
                  @languages_selected += 1
                end
                LanguagesRow.new(lang_name, lang_id, checked).build.tap do |row|
                  languages_list.append(row)
                  row.lang_check.signal_connect('toggled') { |check| count(check) }
                end
              end
            end
          end
        end

        set_selected_label
      end

      def count(check_button)
        if check_button.active?
          @languages_selected += 1
        else
          @languages_selected -= 1
        end
        set_selected_label
        @languages_changed = true
      end

      def set_selected_label
        if @languages_selected == 1
          selected_label.label = '1 language selected'
        else
          selected_label.label = "#{@languages_selected} languages selected"
        end
      end

      def matches_filter?(row)
        languages_entry.text.then do |text|
          text.empty? ||
            row.lang_name.downcase.start_with?(text.downcase) ||
            row.lang_id.downcase.start_with?(text.downcase)
        end
      end

      def each_row(&block) = rows.each(&block)

      def rows
        [].tap do |collected|
          index = 0
          while (row = languages_list.get_row_at_index(index))
            collected << row
            index += 1
          end
        end
      end

      def set_all(state) = each_row { |row| row.lang_check.active = state }

      # Upstream rebuilds the user language list from the check buttons, and
      # falls back to English if the user unchecked everything — the app has
      # to search somewhere.
      def commit
        if @languages_changed
          Data.languages.then do |languages|
            languages.clear
            each_row do |row|
              if row.lang_check.active?
                languages.items[row.lang_id] = row.lang_name
              end
            end
            if languages.items.empty?
              languages.items['en'] = 'English'
            end
            languages.save
          end

          @languages_changed = false
          @on_changed.call
        end
      end
  end
end
