# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'dialogs'

module Wike
  # Ported from upstream's PrefsDialog in src/prefs.py and data/gtk/prefs.ui.
  #
  # Two groups. Behavior: which page opens on start, and whether the tab bar
  # is always hidden. Privacy: the desktop live-search switch with its warning
  # expanded underneath, the recent-articles history with a Clear button, and
  # clearing cookies and cache on close with a Clear button of its own.
  #
  # Every switch and the combo are bound straight to their settings key, so
  # the dialog holds no state. The two Clear buttons confirm first.
  #
  # Upstream reaches the history panel through its window to clear it, and the
  # WebKit website data manager to clear cookies and cache; the port takes
  # both as callbacks:
  #
  #   on_clear_history — called to empty the article history
  #   on_clear_data    — called to delete cookies and cache
  #
  class PrefsDialog < Adwaita::PreferencesDialog
    START_PAGES = [
      'Wikipedia main page',
      'Random article',
      'Last article',
      'Restore open articles',
    ].freeze

    def initialize(on_clear_history:, on_clear_data:)
      super()
      @on_clear_history = on_clear_history
      @on_clear_data = on_clear_data
    end

    def build
      tap do |dialog|
        dialog.content_height = 480
        dialog.content_width = 580
        dialog.add(preferences_page)

        preferences_page.tap do |page|
          page.add(behavior_group)
          page.add(privacy_group)

          behavior_group.tap do |group|
            group.add(start_combo)
            group.add(tabs_switch)
          end

          privacy_group.tap do |group|
            group.add(desktop_row)
            group.add(history_row)
            group.add(data_row)

            desktop_row.tap do |row|
              row.add_prefix(desktop_switch)
              row.add_row(desktop_hint_row)
            end

            history_row.tap do |row|
              row.add_prefix(history_switch)
              row.add_suffix(clear_history_button)
              row.activatable_widget = history_switch
            end

            data_row.tap do |row|
              row.add_prefix(data_switch)
              row.add_suffix(clear_data_button)
              row.activatable_widget = data_switch
            end
          end
        end

        clear_history_button.signal_connect('clicked') { confirm_clear_history }
        clear_data_button.signal_connect('clicked') { confirm_clear_data }

        Data.settings.bind('on-start-load', start_combo, 'selected')
        Data.settings.bind('hide-tabs', tabs_switch, 'active')
        Data.settings.bind('search-desktop', desktop_switch, 'active')
        Data.settings.bind('keep-history', history_switch, 'active')
        Data.settings.bind('clear-data', data_switch, 'active')
      end
    end

    # Memoized widget methods

    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

    def behavior_group
      @behavior_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Behavior'
      end
    end

    def privacy_group
      @privacy_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = 'Privacy'
      end
    end

    def start_combo
      @start_combo ||= Adwaita::ComboRow.new.tap do |row|
        row.title = 'Home Page'
        row.subtitle = 'The page that will be displayed when Wike starts'
        row.model = Gtk::StringList.new(START_PAGES)
      end
    end

    def tabs_switch
      @tabs_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = 'Always Hide Tabs'
        row.subtitle = 'The tab bar will also be hidden in desktop mode'
      end
    end

    def desktop_row
      @desktop_row ||= Adwaita::ExpanderRow.new.tap do |row|
        row.title = 'Allow Live Search on Desktop'
        row.subtitle = 'Warning: all desktop searches will be sent to Wikipedia'
      end
    end

    def desktop_hint_row
      @desktop_hint_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = 'Desktop searches are performed in the default language'
        row.subtitle = 'You can search in other languages ​​using a prefix. ' \
                       'Eg. -es to search in Spanish'
      end
    end

    def history_row
      @history_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = 'Keep a List of Recent Articles'
        row.subtitle = 'Wike will remember the history of visited articles'
      end
    end

    def data_row
      @data_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = 'Clear Personal Data on Close'
        row.subtitle = 'Cookies and cache data will be deleted'
      end
    end

    def desktop_switch = @desktop_switch ||= switch
    def history_switch = @history_switch ||= switch
    def data_switch = @data_switch ||= switch

    def clear_history_button = @clear_history_button ||= clear_button
    def clear_data_button = @clear_data_button ||= clear_button

    private

      def switch
        Gtk::Switch.new.tap do |toggle|
          toggle.valign = :center
        end
      end

      def clear_button
        Gtk::Button.new.tap do |button|
          button.label = 'Clear'
          button.valign = :center
        end
      end

      def confirm_clear_history
        Dialogs::ClearHistoryDialog.new.build.tap do |dialog|
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::CLEAR
              @on_clear_history.call
            end
          end
          dialog.present(self)
        end
      end

      def confirm_clear_data
        Dialogs::ClearDataDialog.new.build.tap do |dialog|
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::CLEAR
              @on_clear_data.call
            end
          end
          dialog.present(self)
        end
      end
  end
end
