# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'langlinks_row'
require_relative 'languages_filter'

module Wike
  # Ported from upstream's LanglinksPanel in src/langlinks.py and
  # data/gtk/langlinks.ui.
  #
  # The language links page of the sidebar: every other-language version of
  # the current article. The user's own languages come first, sorted by code;
  # with the filter set to "All languages" the rest follow under an "Other
  # languages" heading. A search bar filters by language name or code, and the
  # heading row is excluded from the filter so it disappears while searching.
  #
  # Upstream's filter dropdown is a Gio::ListStore of LanguagesFilter GObjects
  # bound to labels by a factory. The port keeps the LanguagesFilter objects
  # and feeds the dropdown their names through a Gtk::StringList, with the
  # same factory so the labels still ellipsize.
  #
  # Upstream reaches the article view through `self._window.page.wikiview`;
  # the port takes the two things it does with it as callbacks:
  #
  #   on_load_uri — called with the article URI in the chosen language
  #   on_dismiss  — called after an activation, so a collapsed sidebar closes
  #
  class LanglinksPanel < Adwaita::Bin
    FILTERS = [['Your languages', 0], ['All languages', 1]].freeze

    def initialize(on_load_uri:, on_dismiss:)
      super()
      @on_load_uri = on_load_uri
      @on_dismiss = on_dismiss
      @langlinks = nil
    end

    def build
      tap do |panel|
        panel.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_box)
          view.add_top_bar(search_bar)
          view.content = scroller

          header_box.tap do |box|
            box.append(filter_dropdown)
            box.append(search_button)
          end

          search_bar.tap do |bar|
            bar.child = search_entry
            search_button.bind_property(

              'active',

              bar,

              'search-mode-enabled',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::BIDIRECTIONAL,

            )
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = langlinks_list

              langlinks_list.tap do |list|
                list.set_placeholder(placeholder)
                list.set_filter_func { |row| matches_filter?(row) }
                list.signal_connect('row-activated') do |_list, row|
                  @on_dismiss.call
                  @on_load_uri.call(row.uri)
                end
              end
            end
          end
        end

        search_entry.signal_connect('search-changed') { langlinks_list.invalidate_filter }

        Data.settings.bind('filter-langlinks', filter_dropdown, 'selected')
        Data.settings.connect_changed('filter-langlinks') { populate(@langlinks) }
        Data.settings.connect_changed('show-flags') { populate(@langlinks) }
      end
    end

    # Populate the language links list. The links are remembered so a change
    # to the filter or to the flag setting can rebuild the same list.
    def populate(langlinks)
      @langlinks = langlinks
      langlinks_list.remove_all
      # GtkListBox#remove_all does not re-trigger the placeholder the way
      # removing rows one at a time does, so it is set again here to make
      # the empty state actually appear rather than leaving a blank list.
      langlinks_list.set_placeholder(placeholder)

      if langlinks
        partition(langlinks).then do |user_langlinks, other_langlinks|
          user_langlinks.sort_by { |langlink| langlink['lang'].to_s }.each do |langlink|
            langlinks_list.append(langlinks_row(langlink))
          end

          if !other_langlinks.empty? && Data.settings.get_int('filter-langlinks') == 1
            langlinks_list.append(section_row('Other languages'))
            other_langlinks.sort_by { |langlink| langlink['lang'].to_s }.each do |langlink|
              langlinks_list.append(langlinks_row(langlink))
            end
          end
        end
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def search_bar = @search_bar ||= Gtk::SearchBar.new
    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)

    def header_box
      @header_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('toolbar')
      end
    end

    def filters = @filters ||= FILTERS.map { |name, level| LanguagesFilter.new(name, level) }

    def filter_dropdown
      @filter_dropdown ||= Gtk::DropDown.new.tap do |dropdown|
        dropdown.hexpand = true
        dropdown.model = Gtk::StringList.new(filters.map(&:name))
        dropdown.factory = filter_factory
      end
    end

    # The dropdown's own factory, so the filter names ellipsize rather than
    # widening the sidebar, as upstream's does.
    def filter_factory
      @filter_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
        factory.signal_connect('setup') do |_factory, list_item|
          list_item.child = Gtk::Label.new.tap do |label|
            label.xalign = 0
            label.ellipsize = :end
          end
        end
        factory.signal_connect('bind') do |_factory, list_item|
          list_item.child.label = list_item.item.string
        end
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'system-search-symbolic'
        button.tooltip_text = 'Search Languages'
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = 'Search languages'
        entry.hexpand = true
      end
    end

    def langlinks_list
      @langlinks_list ||= Gtk::ListBox.new.tap do |list|
        list.vexpand = true
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def placeholder
      @placeholder ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Languages'
        page.description = 'This page is not available in other languages'
        page.icon_name = 'language-symbolic'
        page.margin_start = 50
        page.margin_end = 50
        page.add_css_class('compact')
      end
    end

    private

      def partition(langlinks)
        langlinks.partition { |langlink| Data.languages.items.key?(langlink['lang']) }
      end

      # Upstream's row takes the language's autonym capitalized, and the
      # article's title in that language, which the API returns under '*'.
      def langlinks_row(langlink)
        LanglinksRow.new(
          langlink['url'],
          langlink['lang'],
          Data.capitalize(langlink['autonym']),
          langlink['*'],
        ).build
      end

      # A non-activatable, non-selectable row carrying a heading label, which
      # is how upstream separates the other languages from the user's own.
      def section_row(text)
        Gtk::ListBoxRow.new.tap do |row|
          row.activatable = false
          row.selectable = false
          row.child = Gtk::Label.new.tap do |label|
            label.label = text
            label.xalign = 0
            label.margin_start = 3
            label.margin_end = 3
            label.add_css_class('heading')
          end
        end
      end

      def matches_filter?(row)
        search_entry.text.then do |text|
          if text.empty?
            true
          elsif !row.activatable?
            false
          else
            row.lang_name.downcase.start_with?(text.downcase) ||
              row.lang.downcase.start_with?(text.downcase)
          end
        end
      end
  end
end
