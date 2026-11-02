# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'languages_dialog'
require_relative 'settings_langs_row'

module Wike
  # Ported from upstream's SettingsPopover in src/search.py and
  # data/gtk/search-settings.ui.
  #
  # The popover behind the search entry's language button: a button that opens
  # the language picker, the user's languages with the search language marked,
  # and a switch for the search suggestions.
  #
  # Upstream reaches back into the search panel to relabel its button and to
  # re-run the search; the port takes those as callbacks:
  #
  #   on_language_label — called with the code and name for the button
  #   on_search_again   — called when the search has to be re-run
  #   on_languages_changed — called after the picker changed the language list
  #
  class SettingsPopover < Gtk::Popover
    def initialize(on_language_label:, on_search_again:, on_languages_changed:)
      super()
      @on_language_label = on_language_label
      @on_search_again = on_search_again
      @on_languages_changed = on_languages_changed
    end

    def build
      tap do |popover|
        popover.width_request = 240
        popover.add_css_class('menu')
        popover.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(languages_button)
          view.add_bottom_bar(suggestions_box)
          view.content = scroller

          suggestions_box.tap do |box|
            box.append(suggestions_label)
            box.append(suggestions_switch)
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = languages_list

              languages_list.tap do |list|
                list.signal_connect('row-activated') do |_list, row|
                  Data.settings.set_string('search-language', row.lang_id)
                  popover.popdown
                  populate_list
                  @on_search_again.call
                end
              end
            end
          end
        end

        languages_button.signal_connect('clicked') { open_languages_dialog(popover) }
        popover.signal_connect('show') { languages_list.unselect_all }

        Data.settings.bind('search-suggestions', suggestions_switch, 'active')
        Data.settings.connect_changed('search-suggestions') { @on_search_again.call }
        Data.settings.connect_changed('show-flags') { populate_list }

        populate_list
      end
    end

    # Rebuild the language list and tell the search panel what to put on its
    # button. Called on every change that can affect either.
    def populate_list
      Data.settings.get_string('search-language').then do |search_language|
        @on_language_label.call(search_language, Data.languages.name_for(search_language))

        languages_list.remove_all
        Data.languages.items.keys.sort.each do |lang_id|
          languages_list.append(
            SettingsLangsRow.new(
              Data.capitalize(Data.languages.items[lang_id]),
              lang_id,
              lang_id == search_language,
            ).build,
          )
        end
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)
    def languages_list = @languages_list ||= Gtk::ListBox.new
    def suggestions_switch = @suggestions_switch ||= Gtk::Switch.new

    def languages_button
      @languages_button ||= Gtk::Button.new.tap do |button|
        button.label = 'Pick your Languages'
        button.hexpand = true
        button.margin_top = 6
        button.margin_bottom = 6
        button.margin_start = 6
        button.margin_end = 6
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.max_content_height = 320
        scrolled.propagate_natural_height = true
        scrolled.propagate_natural_width = true
      end
    end

    def suggestions_box
      @suggestions_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.margin_top = 9
        box.margin_bottom = 9
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def suggestions_label
      @suggestions_label ||= Gtk::Label.new.tap do |label|
        label.label = 'Search Suggestions'
        label.hexpand = true
        label.halign = :start
      end
    end

    private

      # The picker is a one-shot dialog: it writes the language list back on
      # close and then reports the change, exactly as upstream's does.
      def open_languages_dialog(popover)
        popover.popdown
        LanguagesDialog.new(
          on_changed: lambda {
            populate_list
            @on_languages_changed.call
          },
        ).build.present(popover.root)
      end
  end
end
