# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'search_row'
require_relative 'settings_popover'
require_relative 'wikipedia'

module Wike
  # Ported from upstream's SearchPanel in src/search.py and data/gtk/search.ui.
  #
  # The search page of the sidebar: a search entry, the language button that
  # opens the settings popover, and the live suggestions list.
  #
  # The search language can be overridden per query with a `-code ` prefix, so
  # "-es madrid" searches the Spanish Wikipedia whatever the default is. Live
  # suggestions start at three characters and ask for twenty results;
  # activating the entry asks for one and loads it directly.
  #
  # Upstream reaches the article view and the sidebar through `self.window`;
  # the port takes the four things it does with them as callbacks:
  #
  #   on_load_uri     — called with an article URI to load
  #   on_load_message — called with 'error' or 'notfound' for a failed search
  #   on_dismiss      — called after an activation, so a collapsed sidebar closes
  #   on_show_search  — called when typing should bring this page to the front
  #
  class SearchPanel < Adwaita::Bin
    SUGGESTION_LIMIT = 20
    MIN_SUGGESTION_LENGTH = 3

    def initialize(on_load_uri:, on_load_message:, on_dismiss:, on_show_search:)
      super()
      @on_load_uri = on_load_uri
      @on_load_message = on_load_message
      @on_dismiss = on_dismiss
      @on_show_search = on_show_search
    end

    def build
      tap do |panel|
        panel.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_box)
          view.content = scroller

          header_box.tap do |box|
            box.append(search_entry)
            box.append(settings_button)

            settings_button.tap do |button|
              button.popover = settings_popover
            end
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = suggestions_list

              suggestions_list.tap do |list|
                list.set_placeholder(placeholder)
                list.signal_connect('row-activated') do |_list, row|
                  @on_dismiss.call
                  @on_load_uri.call(row.uri)
                end
              end
            end
          end
        end

        search_entry.tap do |entry|
          entry.delegate.signal_connect('notify::has-focus') do |delegate|
            unless delegate.has_focus?
              entry.select_region(0, -1)
            end
          end
          entry.signal_connect('changed') { run_suggestions }
          entry.signal_connect('stop-search') { stop_search }
          entry.signal_connect('activate') { run_search }
        end

        settings_popover.build
      end
    end

    # Upstream captures keystrokes anywhere in the window into this entry, so
    # typing starts a search without the entry having focus first. The window
    # does not exist when the panel is built, so the host hands it over.
    def capture_keys_from(widget) = search_entry.set_key_capture_widget(widget)

    def grab_focus = search_entry.grab_focus

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)

    def header_box
      @header_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('toolbar')
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = 'Search Wikipedia'
        entry.hexpand = true
      end
    end

    def settings_button
      @settings_button ||= Gtk::MenuButton.new.tap do |button|
        button.label = 'en'
        button.tooltip_text = 'English'
        button.width_request = 60
      end
    end

    def settings_popover
      @settings_popover ||= SettingsPopover.new(
        on_language_label:    ->(lang_id, lang_name) { label_settings_button(lang_id, lang_name) },
        on_search_again:      -> { run_suggestions },
        on_languages_changed: -> { @on_languages_changed&.call },
      )
    end

    def suggestions_list
      @suggestions_list ||= Gtk::ListBox.new.tap do |list|
        list.vexpand = true
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def placeholder
      @placeholder ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Results'
        page.description = 'Enter at least three characters to get search suggestions'
        page.icon_name = 'find-location-symbolic'
        page.margin_start = 50
        page.margin_end = 50
        page.add_css_class('compact')
      end
    end

    # The host sets this so a change to the user's languages also refreshes
    # the language links panel, as upstream's languages dialog does.
    def on_languages_changed=(callback)
      @on_languages_changed = callback
    end

    private

      def label_settings_button(lang_id, lang_name)
        settings_button.tap do |button|
          button.label = lang_id
          button.tooltip_text = lang_name
        end
      end

      def populate(suggestions)
        suggestions_list.remove_all

        if suggestions
          suggestions[0].zip(suggestions[1]).each do |title, uri|
            suggestions_list.append(SearchRow.new(title, uri).build)
          end
        end
      end

      # Typing anywhere brings the search page to the front and moves focus
      # into the entry, so the captured keystrokes land where they are shown.
      def run_suggestions
        @on_show_search.call
        unless search_entry.delegate.has_focus?
          search_entry.grab_focus
        end

        if Data.settings.get_boolean('search-suggestions')
          search_terms(search_entry.text).then do |text, lang|
            if text.length >= MIN_SUGGESTION_LENGTH
              Wikipedia.search(text, lang, SUGGESTION_LIMIT) { |results, _failed| populate(results) }
            else
              populate(nil)
            end
          end
        else
          populate(nil)
        end
      end

      # Escape clears a non-empty entry; on an already empty one it closes a
      # collapsed sidebar and hands focus back to the article.
      def stop_search
        if search_entry.text.empty?
          @on_dismiss.call
        else
          search_entry.text = ''
        end
      end

      def run_search
        @on_dismiss.call

        search_terms(search_entry.text).then do |text, lang|
          unless text.empty?
            Wikipedia.search(text, lang, 1) do |results, failed|
              if failed
                @on_load_message.call('error')
              elsif results
                @on_load_uri.call(results[1][0])
              else
                @on_load_message.call('notfound')
              end
            end
          end
        end
      end

      # Split the search terms to get a language prefix: a leading "-code "
      # picks that Wikipedia for this query only, and an unrecognised code is
      # dropped rather than searched for.
      def search_terms(raw)
        raw.to_s.downcase.then do |text|
          lang = Data.settings.get_string('search-language')

          if text.start_with?('-')
            text.split(' ', 2).then do |terms|
              terms[0].delete_prefix('-').then do |prefix|
                if Data.languages.wikilangs.key?(prefix)
                  lang = prefix
                end
              end
              if terms.length > 1
                text = terms[1]
              else
                text = ''
              end
            end
          end

          [text, lang]
        end
      end
  end
end
