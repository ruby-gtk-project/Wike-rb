# frozen_string_literal: true

require 'adwaita'
require_relative 'data'
require_relative 'theme_switcher'
require_relative 'zoom_level'

module Wike
  # Ported from upstream's ViewMenuPopover in src/menu.py and
  # data/gtk/menu-view.ui.
  #
  # The view menu: the theme switcher, the zoom row, two toggles for the
  # language flags and the article link previews, and a section naming the
  # current article font that opens the font picker.
  #
  # The theme switcher and the zoom row are custom widgets slotted into the
  # menu by the `custom` attribute of their items; the font section is
  # appended in code because its label is the current font and changes.
  #
  # The two toggles are stateful actions in the popover's own `view` group,
  # the way upstream's are, so the menu items render as checkboxes.
  class ViewMenuPopover < Gtk::PopoverMenu
    # The index of the font section in the menu model — after the theme
    # switcher, the zoom row and the show section — which is the one upstream
    # removes and re-appends when the font changes.
    FONT_SECTION_INDEX = 3

    SHOW_ITEMS = [
      ['Language Flags', 'view.show-flags'],
      ['Link Previews', 'view.preview-popups'],
    ].freeze

    # The menu model is built before the popover, and kept so the font
    # section can be swapped out later.
    def self.menu_model
      Gio::Menu.new.tap do |menu|
        menu.append_item(custom_item('theme_switcher'))
        menu.append_item(custom_item('zoom_level'))

        Gio::Menu.new.tap do |section|
          SHOW_ITEMS.each { |label, action| section.append(label, action) }
          menu.append_section('Show', section)
        end
      end
    end

    # A menu item that stands in for a widget added with add_child under the
    # same name.
    def self.custom_item(name)
      Gio::Menu.new.tap do |section|
        Gio::MenuItem.new(nil, nil).tap do |item|
          item.set_attribute_value('custom', GLib::Variant.new(name))
          section.append_item(item)
        end
      end.then do |section|
        Gio::MenuItem.new(nil, nil).tap { |item| item.section = section }
      end
    end

    def initialize
      @view_menu = self.class.menu_model
      super(@view_menu)
    end

    def build
      tap do |popover|
        popover.add_child(theme_switcher.build, 'theme_switcher')
        popover.add_child(zoom_level.build, 'zoom_level')
        popover.insert_action_group('view', actions)

        # Until the user picks a font, the article font follows the UI font,
        # so the setting is seeded from the popover's own Pango context.
        unless Data.settings.get_boolean('custom-font')
          Data.settings.set_string(
            'font-family', popover.pango_context.font_description.family,
          )
        end

        add_font_section
      end
    end

    # Memoized widget methods

    def theme_switcher = @theme_switcher ||= ThemeSwitcher.new
    def zoom_level = @zoom_level ||= ZoomLevel.new

    def actions
      @actions ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(toggle_action('show-flags'))
        group.add_action(toggle_action('preview-popups'))

        Gio::SimpleAction.new('set-font').tap do |action|
          action.signal_connect('activate') { open_font_dialog }
          group.add_action(action)
        end
      end
    end

    private

      # A stateful boolean action backed by a settings key: the menu item
      # renders as a checkbox and the key follows it.
      def toggle_action(key)
        Gio::SimpleAction.new(key, nil, GLib::Variant.new(Data.settings.get_boolean(key)))
          .tap do |action|
            action.signal_connect('change-state') do |changed, state|
              changed.state = state
              Data.settings.set_boolean(key, state.get_boolean)
            end
          end
      end

      def font_label
        "#{Data.settings.get_string('font-family')} #{Data.settings.get_int('font-size')}"
      end

      def add_font_section
        Gio::Menu.new.tap do |section|
          section.append(font_label, 'view.set-font')
          @view_menu.append_section('Font', section)
        end
      end

      # Upstream drops the font section and appends a fresh one so its label
      # shows the font that was just chosen.
      def refresh_font_section
        @view_menu.remove(FONT_SECTION_INDEX)
        add_font_section
      end

      # Upstream uses GtkFontChooserDialog, which GTK 4 has deprecated in
      # favour of GtkFontDialog; the port uses the replacement, with the same
      # title and the same initial font description.
      def open_font_dialog
        Gtk::FontDialog.new.tap do |dialog|
          dialog.title = 'Pick a Font'
          dialog.modal = true
          dialog.choose_font(root, current_font_description) do |chooser, result|
            apply_font(chooser, result)
          end
        end
      end

      def current_font_description
        Pango::FontDescription.new.tap do |description|
          description.family = Data.settings.get_string('font-family')
          description.absolute_size = Data.settings.get_int('font-size') * Pango::SCALE
        end
      end

      # A dismissed dialog makes choose_font_finish raise, which is the
      # cancel path — the font is simply left alone.
      def apply_font(chooser, result)
        chooser.choose_font_finish(result).then do |description|
          Data.settings.set_boolean('custom-font', true)
          Data.settings.set_string('font-family', description.family)
          Data.settings.set_int('font-size', description.size / Pango::SCALE)
          refresh_font_section
        end
      rescue StandardError
        nil
      end
  end
end
