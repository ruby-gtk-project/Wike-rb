# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's ThemeSwitcher in src/menu.py and
  # data/gtk/theme-switcher.ui.
  #
  # The row of four colour swatches at the top of the view menu: system,
  # light, sepia and dark. Each is a check button in one radio group, styled
  # into a circle by the app stylesheet's `.theme-button` rules, with a
  # checkmark image that fades in on the chosen one.
  #
  # Toggling a swatch activates the matching app action, which is what
  # actually applies the colour scheme and records the choice; the switcher
  # only reflects and requests.
  class ThemeSwitcher < Gtk::Box
    # [swatch, theme value in settings, app action]
    THEMES = [
      [:system, 3, 'theme-system'],
      [:light, 0, 'theme-light'],
      [:sepia, 2, 'theme-sepia'],
      [:dark, 1, 'theme-dark'],
    ].freeze

    def initialize
      super(:horizontal, 0)
    end

    def build
      tap do |switcher|
        switcher.margin_start = 6
        switcher.halign = :center

        THEMES.each do |name, theme, action|
          buttons[name].tap do |button|
            switcher.append(button)
            button.active = Data.settings.get_int('theme') == theme
            button.signal_connect('toggled') do
              if button.active?
                activate_action("app.#{action}", nil)
              end
            end
          end
        end
      end
    end

    # Memoized widget methods

    # All four swatches share the first one's radio group, so checking one
    # unchecks the rest.
    def buttons
      @buttons ||= THEMES.each_with_object({}) do |(name, _theme, _action), collected|
        collected[name] = Gtk::CheckButton.new.tap do |button|
          button.add_css_class('theme-button')
          button.add_css_class("theme-button-#{name}")
          button.child = Gtk::Image.new.tap do |image|
            image.icon_name = 'checkmark-symbolic'
            image.halign = :center
            image.valign = :center
          end
          unless collected.empty?
            button.group = collected.values.first
          end
        end
      end
    end
  end
end
