# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's MainMenuPopover in src/menu.py and
  # data/gtk/menu-main.ui.
  #
  # The hamburger menu: preferences, keyboard shortcuts, about. All three are
  # app actions, so the popover carries no behaviour of its own — upstream
  # only loads the menu model from its GtkBuilder file.
  class MainMenuPopover < Gtk::PopoverMenu
    ITEMS = [
      ['Preferences', 'app.prefs'],
      ['Keyboard Shortcuts', 'app.shortcuts'],
      ['About Wike', 'app.about'],
    ].freeze

    def self.menu_model
      Gio::Menu.new.tap do |menu|
        Gio::Menu.new.tap do |section|
          ITEMS.each { |label, action| section.append(label, action) }
          menu.append_section(nil, section)
        end
      end
    end

    def initialize
      super(self.class.menu_model)
    end

    def build = self
  end
end
