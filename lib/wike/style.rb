# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's data/gtk/style.css.
  #
  # Upstream ships the stylesheet as a GResource and loads it through the
  # automatic `/com/github/hugolabe/Wike/gtk/style.css` that GtkApplication
  # picks up from the resource base path. The port carries the same rules as a
  # Ruby string and installs them on the default display, so there is no
  # resource bundle to build before the app can be run from a checkout.
  module Style
    CSS = <<~CSS
      /* Theme switcher */

      .theme-button radio {
        -gtk-icon-source: none;
        margin: 1px;
        padding: 6px;
        min-height: 26px;
        min-width: 26px;
        border: solid 1px @light_4;
        border-radius: 100%;
        transition: all 200ms ease-out;
      }

      .theme-button:checked radio {
        margin: 0;
        border-width: 2px;
        border-color: @accent_bg_color;
      }

      .theme-button image {
        margin: 26px 0 0 -26px;
        padding: 2px;
        min-width: 24px;
        min-height: 24px;
        color: @accent_fg_color;
        background-color: @accent_bg_color;
        border-radius: 100%;
        opacity: 0;
        transform: scale(0.75) translate(-1px, -1px);
        transition: all 200ms ease-out;
      }

      .theme-button:checked image {
        opacity: 1;
      }

      .theme-button-system radio {
        background: linear-gradient(135deg, @light_1 0%, @light_1 49%, @dark_3 51%, @dark_3 100%);
      }

      .theme-button-light radio {
        background-color: @light_1;
      }

      .theme-button-sepia radio {
        background-color: #f4ecd8;
      }

      .theme-button-dark radio {
        background-color: @dark_3;
      }

      /* Sidebar */

      .navigation-sidebar > row {
        min-height: 28px;
      }

      /* Dark theme */

      @media (prefers-color-scheme: dark) {

        :root {
          --headerbar-bg-color: #101418;
        }

        .wikiview-status {
          background-color: #101418;
        }

      }
    CSS

    class << self
      def provider
        @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
      end

      # Installed once, for the lifetime of the process: these rules are the
      # app's own look and no theme switch takes them away.
      def install(display = Gdk::Display.default)
        Gtk::StyleContext.add_provider_for_display(
          display, provider, Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end
  end
end
