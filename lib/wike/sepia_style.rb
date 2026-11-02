# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's data/gtk/style-sepia.css.
  #
  # The sepia theme is the one stylesheet that gets added and removed at
  # runtime: upstream's application adds this provider to the default display
  # when theme 2 is chosen and removes it again for every other theme. The
  # provider is memoized so that add and remove see the same object, which is
  # what makes the removal work.
  module SepiaStyle
    CSS = <<~CSS
      /* Sepia theme */

      :root {
        --window-bg-color: #fdf8e8;
        --headerbar-bg-color: #fdf6e3;
        --headerbar-backdrop-color: #e9e3d1;
        --sidebar-bg-color: #e9e3d1;
        --sidebar-backdrop-color: #e9e3d1;
        --secondary-sidebar-bg-color: #f1ead8;
        --secondary-sidebar-backdrop-color: #f1ead8;
        --overview-bg-color: #e9e3d1;
        --view-bg-color: #fefdf6;
        --card-bg-color: #fefdf6;
        --dialog-bg-color: #fdf8e8;
        --popover-bg-color: #fdf8e8;
        --accent-bg-color: var(--orange-4);
        --accent-color: var(--orange-5);
      }
    CSS

    class << self
      def provider
        @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
      end

      def install(display = Gdk::Display.default)
        Gtk::StyleContext.add_provider_for_display(
          display, provider, Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end

      def remove(display = Gdk::Display.default)
        Gtk::StyleContext.remove_provider_for_display(display, provider)
      end
    end
  end
end
