# frozen_string_literal: true

require 'gtk4'
require 'adwaita'
require_relative 'about_dialog'
require_relative 'data'
require_relative 'prefs_dialog'
require_relative 'sepia_style'
require_relative 'shortcuts_dialog'
require_relative 'style'
require_relative 'view_settings'
require_relative 'window'

module Wike
  # Ported from upstream's src/application.py.
  #
  # The application is the thin half of the pair upstream splits itself into:
  # it owns startup (the app stylesheet, the icon theme, the saved colour
  # scheme), the app actions that are not specific to any window (the four
  # themes, preferences, about, shortcuts and quit), and the quit handler that
  # writes the window's geometry and tabs and the data stores back before
  # letting the app go. Everything that is specific to one open window — the
  # sidebar, the tabs, the article view — is Window's, built in full there.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = 'org.rubygtkproject.Wike'

    # [action name, theme value in settings, colour scheme, sepia stylesheet?]
    THEMES = [
      ['theme-light', 0, :force_light, false],
      ['theme-dark', 1, :force_dark, false],
      ['theme-sepia', 2, :force_light, true],
      ['theme-system', 3, :prefer_light, false],
    ].freeze

    def initialize(launch_uri = '')
      @launch_uri = launch_uri
    end

    def build
      app.tap do
        app.signal_connect('startup') do
          Style.install
          Data.install_icons
          apply_theme(Data.settings.get_int('theme'))
          add_app_actions
        end

        app.signal_connect('activate') { activate }
      end
    end

    def run = app.run([])

    # Memoized widget methods

    # Adwaita::Application is unreliable in the Ruby bindings; the
    # application object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)
    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def window
      @window ||= Window.new(app, @launch_uri.to_s).tap do |win|
        win.build
        win.signal_connect('close-request') { on_close_request }
      end
    end

    private

      def activate
        window.present
      end

      # Upstream's do_close_request: closing the window is the same as
      # choosing Quit.
      def on_close_request
        quit
        true
      end

      # --- App actions --------------------------------------------------

      def add_app_actions
        add_action(app, 'prefs', '<Ctrl>comma') { show_prefs }
        add_action(app, 'about', nil) { show_about }
        add_action(app, 'shortcuts', '<Ctrl>question') { show_shortcuts }
        add_action(app, 'quit', '<Ctrl>Q') { quit }

        THEMES.each do |name, theme, _scheme, _sepia|
          add_action(app, name, nil) { set_theme(theme) }
        end
      end

      def add_action(scope, name, accel, &callback)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { callback.call }
          scope.add_action(action)
          if accel
            app.set_accels_for_action("app.#{name}", [accel])
          end
        end
      end

      # --- Themes ---------------------------------------------------------

      def set_theme(theme)
        apply_theme(theme)
        Data.settings.set_int('theme', theme)
      end

      # Sepia is the light scheme plus the sepia stylesheet; every other
      # theme takes that stylesheet off again.
      def apply_theme(theme)
        (THEMES.find { |_name, value, _scheme, _sepia| value == theme } || THEMES.last)
          .then do |_name, _value, scheme, sepia|
            style_manager.color_scheme = scheme
            if sepia
              SepiaStyle.install
            else
              SepiaStyle.remove
            end
          end
      end

      # --- Dialogs ----------------------------------------------------------

      def show_prefs
        PrefsDialog.new(
          on_clear_history: -> { window.history_panel.clear_history },
          on_clear_data:    -> { clear_website_data },
        ).build.present(window)
      end

      def clear_website_data
        ViewSettings.instance.network_session.website_data_manager.clear(:all, 0) { |_manager, _result| }
      end

      def show_about = AboutDialog.new.build.present(window)
      def show_shortcuts = ShortcutsDialog.new.build.present(window)

      # --- Shutdown -----------------------------------------------------

      # Upstream's _quit_cb: the window records its own geometry and tabs,
      # the history is dropped unless the user asked to keep it, the settings
      # and the data stores are flushed, and the website data is cleared if
      # the user asked for that too, before the app goes.
      def quit
        window.save_state
        unless Data.settings.get_boolean('keep-history')
          Data.history.clear
        end
        if Data.settings.get_boolean('clear-data')
          clear_website_data
        end
        Data.settings.sync
        Data.languages.save
        Data.history.save
        Data.bookmarks.save
        app.quit
      end
  end
end
