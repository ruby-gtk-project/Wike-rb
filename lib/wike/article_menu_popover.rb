# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's ArticleMenuPopover in src/menu.py and
  # data/gtk/menu-article.ui.
  #
  # The article menu: a row of two icon buttons for print and text search,
  # then a section for jumping somewhere else in Wikipedia, then a section for
  # taking the article out of the app. Every item is a window action, so the
  # popover carries no behaviour of its own.
  #
  # The first section is the one with structure: `display-hint` of
  # `horizontal-buttons` is what turns it into the button row, and each item's
  # `verb-icon` is the icon shown on its button. Neither attribute has a
  # setter on Gio::Menu, so that section is appended as a Gio::MenuItem
  # carrying the hint, with the icons set the same way.
  class ArticleMenuPopover < Gtk::PopoverMenu
    BUTTONS = [
      ['Print', 'win.print-page', 'printer-symbolic'],
      ['Search Text', 'win.search-text', 'system-search-symbolic'],
    ].freeze

    SECTIONS = [
      [
        ['Main Page', 'win.main-page'],
        ['Random Article', 'win.random-article'],
        ['Open Wikipedia Link', 'win.open-link'],
      ],
      [
        ['Open in Browser', 'win.open-browser'],
        ['Copy Link to Clipboard', 'win.copy-link'],
      ],
    ].freeze

    def self.menu_model
      Gio::Menu.new.tap do |menu|
        menu.append_item(buttons_section)

        SECTIONS.each do |items|
          Gio::Menu.new.tap do |section|
            items.each { |label, action| section.append(label, action) }
            menu.append_section(nil, section)
          end
        end
      end
    end

    def self.buttons_section
      Gio::Menu.new.tap do |section|
        BUTTONS.each do |label, action, icon|
          Gio::MenuItem.new(label, action).tap do |item|
            item.set_attribute_value('verb-icon', GLib::Variant.new(icon))
            section.append_item(item)
          end
        end
      end.then do |section|
        Gio::MenuItem.new(nil, nil).tap do |item|
          item.section = section
          item.set_attribute_value('display-hint', GLib::Variant.new('horizontal-buttons'))
        end
      end
    end

    def initialize
      super(self.class.menu_model)
    end

    def build = self
  end
end
