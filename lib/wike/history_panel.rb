# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'dialogs'
require_relative 'history_filter'
require_relative 'history_row'

module Wike
  # Ported from upstream's HistoryPanel in src/history.py and
  # data/gtk/history.ui.
  #
  # The history page of the sidebar: visited articles grouped under date
  # headings, newest first, cut off by the chosen filter — today, the last 7
  # days, the last 30, or everything. A selection mode reveals a check button
  # on every article row and an action bar for removing the marked ones, and
  # the clear button empties the history after a confirmation.
  #
  # Upstream reaches the article view through `self._window.page.wikiview`;
  # the port takes the two things it does with it as callbacks:
  #
  #   on_load_uri — called with the article URI to load
  #   on_dismiss  — called after an activation, so a collapsed sidebar closes
  #
  class HistoryPanel < Adwaita::Bin
    FILTERS = [
      ['Today', 1],
      ['Last 7 days', 7],
      ['Last 30 days', 30],
      ['Show full history', 365],
    ].freeze

    def initialize(on_load_uri:, on_dismiss:)
      super()
      @on_load_uri = on_load_uri
      @on_dismiss = on_dismiss
    end

    def build
      tap do |panel|
        panel.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_box)
          view.add_bottom_bar(action_bar)
          view.content = scroller

          header_box.tap do |box|
            box.append(filter_dropdown)
            box.append(selection_button)
            box.append(clear_button)
          end

          action_bar.tap do |bar|
            bar.pack_start(select_all_button)
            bar.pack_start(select_none_button)
            bar.pack_end(remove_button)
            selection_button.bind_property(
              'active',
              bar,
              'revealed',
              :sync_create,
            )
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = history_list

              history_list.tap do |list|
                list.set_placeholder(placeholder)
                list.signal_connect('row-activated') { |_list, row| activate(row) }
              end
            end
          end
        end

        clear_button.signal_connect('clicked') { confirm_clear }
        select_all_button.signal_connect('clicked') { mark_all(true) }
        select_none_button.signal_connect('clicked') { mark_all(false) }
        remove_button.signal_connect('clicked') { remove_marked }

        Data.settings.bind('filter-history', filter_dropdown, 'selected')
        Data.settings.connect_changed('filter-history') { populate }
        Data.settings.connect_changed('keep-history') { keep_history_changed }

        populate
      end
    end

    # Add an article to the history and rebuild the list, as upstream does
    # every time an article finishes loading.
    def add_item(uri, title, lang)
      Data.history.add(uri, title, lang)
      populate
    end

    # Clear the history of recent articles. Called both by the panel's own
    # clear button and by the preferences dialog.
    def clear_history
      Data.history.clear
      Data.history.save
      clear_list
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)
    def action_bar = @action_bar ||= Gtk::ActionBar.new

    def header_box
      @header_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('toolbar')
      end
    end

    def filters = @filters ||= FILTERS.map { |name, days| HistoryFilter.new(name, days) }

    def filter_dropdown
      @filter_dropdown ||= Gtk::DropDown.new.tap do |dropdown|
        dropdown.hexpand = true
        dropdown.model = Gtk::StringList.new(filters.map(&:name))
        dropdown.factory = filter_factory
      end
    end

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

    def selection_button
      @selection_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'selection-mode-symbolic'
        button.tooltip_text = 'Select'
      end
    end

    def clear_button
      @clear_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'list-remove-all-symbolic'
        button.tooltip_text = 'Clear History'
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

    def remove_button
      @remove_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'app-remove-symbolic'
        button.tooltip_text = 'Remove Selected'
        button.add_css_class('destructive-action')
      end
    end

    def history_list
      @history_list ||= Gtk::ListBox.new.tap do |list|
        list.vexpand = true
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def placeholder
      @placeholder ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'Empty History'
        page.description = 'There are no recent articles in the history'
        page.icon_name = 'document-open-recent-symbolic'
        page.margin_start = 50
        page.margin_end = 50
        page.add_css_class('compact')
      end
    end

    private

      # Walk the dates newest first and stop at the first one older than the
      # filter allows, which is what upstream's `break` does.
      def populate
        clear_list

        selected_filter.days.then do |filter_days|
          Data.history.items.keys.sort.reverse.each do |date|
            if days_ago(date) >= filter_days
              break
            end

            history_list.append(date_row(date))
            append_articles(date)
          end
        end
      end

      def selected_filter = filters[filter_dropdown.selected] || filters.last

      def days_ago(date)
        ((Time.now - Time.new(*date.split('-').map(&:to_i))) / 86_400).floor
      rescue ArgumentError, TypeError
        Float::INFINITY
      end

      # Within a date, upstream sorts by the stored value — time first — and
      # reverses it, so the most recent article of the day comes first.
      def append_articles(date)
        Data.history.items[date].then do |items|
          items.keys.sort_by { |uri| items[uri] }.reverse.each do |uri|
            items[uri].then do |time, title, lang|
              HistoryRow.new(
                uri,
                title,
                lang,
                date,
                time,
              ).build.tap do |row|
                history_list.append(row)
                selection_button.bind_property(

                  'active',
                  row.select_check,
                  'visible',
                  :sync_create,

                )
              end
            end
          end
        end
      end

      def date_row(date)
        Gtk::ListBoxRow.new.tap do |row|
          row.activatable = false
          row.selectable = false
          row.child = Gtk::Label.new.tap do |label|
            label.label = date
            label.xalign = 0
            label.margin_start = 3
            label.margin_end = 3
            label.add_css_class('heading')
          end
        end
      end

      def clear_list
        selection_button.active = false
        history_list.remove_all
        # GtkListBox#remove_all does not re-trigger the placeholder the way
        # removing rows one at a time does, so it is set again here to make
        # the empty state actually appear rather than leaving a blank list.
        history_list.set_placeholder(placeholder)
      end

      def keep_history_changed
        if Data.settings.get_boolean('keep-history')
          populate
        else
          clear_list
        end
      end

      def confirm_clear
        Dialogs::ClearHistoryDialog.new.build.tap do |dialog|
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::CLEAR
              clear_history
            end
          end
          dialog.present(root)
        end
      end

      # The date headings are not activatable, so only article rows are
      # touched by the select and remove buttons.
      def article_rows
        [].tap do |collected|
          index = 0
          while (row = history_list.get_row_at_index(index))
            if row.activatable?
              collected << row
            end
            index += 1
          end
        end
      end

      def mark_all(state) = article_rows.each { |row| row.select_check.active = state }

      def remove_marked
        article_rows.select { |row| row.select_check.active? }.each { |row| remove_row(row) }
        Data.history.save
      end

      # Removing the last article of a date takes its heading row with it,
      # which sits one position above the article in the list.
      def remove_row(row)
        Data.history.remove(row.date, row.uri).then do |item_deleted, date_deleted|
          row.index.then do |row_index|
            if item_deleted
              history_list.remove(row)
            end
            if date_deleted
              history_list.remove(history_list.get_row_at_index(row_index - 1))
            end
          end
        end
      end

      # In selection mode a click toggles the row's check button instead of
      # loading the article.
      def activate(row)
        if selection_button.active?
          row.select_check.active = !row.select_check.active?
        else
          @on_dismiss.call
          @on_load_uri.call(row.uri)
        end
      end
  end
end
