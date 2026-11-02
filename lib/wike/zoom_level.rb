# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's ZoomLevel in src/menu.py and
  # data/gtk/zoom-level.ui.
  #
  # The zoom row of the view menu: minus, the current percentage, plus. The
  # percentage button resets to 100% and is insensitive while already there;
  # the steps are 10% and the range is 50% to 200%, with each end button going
  # insensitive at its limit.
  class ZoomLevel < Gtk::Box
    STEP = 10
    MINIMUM = 50
    MAXIMUM = 200
    DEFAULT = 100

    def initialize
      super(:horizontal, 6)
    end

    def build
      tap do |widget|
        widget.halign = :center
        widget.append(zoom_out_button)
        widget.append(zoom_value_button)
        widget.append(zoom_in_button)

        zoom_value_button.signal_connect('clicked') { set_zoom(DEFAULT) }
        zoom_in_button.signal_connect('clicked') { step(STEP) }
        zoom_out_button.signal_connect('clicked') { step(-STEP) }
        Data.settings.connect_changed('zoom-level') { refresh_buttons }

        refresh_buttons
      end
    end

    # Memoized widget methods

    def zoom_out_button
      @zoom_out_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'zoom-out-symbolic'
        button.add_css_class('flat')
        button.add_css_class('circular')
      end
    end

    def zoom_value_button
      @zoom_value_button ||= Gtk::Button.new.tap do |button|
        button.width_request = 100
        button.add_css_class('flat')
      end
    end

    def zoom_in_button
      @zoom_in_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'zoom-in-symbolic'
        button.add_css_class('flat')
        button.add_css_class('circular')
      end
    end

    private

      def set_zoom(value) = Data.settings.set_int('zoom-level', value)

      # A step that would leave the range is simply not taken, which is also
      # why the button at that end is insensitive.
      def step(delta)
        Data.settings.get_int('zoom-level').then do |zoom_level|
          if (zoom_level + delta).between?(MINIMUM, MAXIMUM)
            set_zoom(zoom_level + delta)
          end
        end
      end

      def refresh_buttons
        Data.settings.get_int('zoom-level').then do |zoom_value|
          zoom_value_button.label = "#{zoom_value}%"
          zoom_value_button.sensitive = zoom_value != DEFAULT
          zoom_in_button.sensitive = zoom_value < MAXIMUM
          zoom_out_button.sensitive = zoom_value > MINIMUM
        end
      end
  end
end
