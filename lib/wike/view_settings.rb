# frozen_string_literal: true

require 'fileutils'

require 'adwaita'
require 'webkit-gtk'
require_relative 'data'

module Wike
  # Ported from upstream's ViewSettings in src/view.py, together with the
  # module-level network session that file configures beside it.
  #
  # One object holds everything every article view shares: the WebKit settings
  # (user agent, article font size, back/forward gestures), the cookie jar, and
  # the stylesheets injected into each page — the base article stylesheet, the
  # user's font family, the sepia sheet, and the rule that hides Wikipedia's
  # hover previews. It watches the four settings keys upstream watches and the
  # system colour scheme, and rebuilds the injected stylesheets when any of
  # them moves.
  #
  # Two deviations from upstream, both forced by the bindings and neither of
  # them provisional:
  #
  #   * WebKit's user-content-manager is construct-only and the Ruby binding
  #     has no constructor that takes it, so a view cannot be handed a shared
  #     manager. Each view keeps its own, this object keeps the list of live
  #     views, and `set_style` injects into all of them — which is what sharing
  #     one manager bought upstream.
  #   * upstream's `set-skin` GObject signal is a plain call into each
  #     registered view, since the views are exactly the signal's subscribers.
  #
  # The stylesheets themselves are the upstream assets, read from data/styles
  # rather than from a GResource bundle, because this port ships its data as
  # files.
  class ViewSettings
    # Wikipedia serves its mobile skin to this user agent, which is the layout
    # the article stylesheet is written against.
    USER_AGENT = 'Mozilla/5.0 (Linux; Android; Mobile) AppleWebKit/537.36 (KHTML, like Gecko)'

    # Wikipedia's hover previews, hidden when the user turns them off.
    HIDE_PREVIEWS_CSS = '.mwe-popups{display:none!important}'

    THEME_DARK = 1
    THEME_SEPIA = 2
    THEME_SYSTEM = 3

    class << self
      # Upstream builds one `view_settings` when src/view.py is imported and
      # every view takes its settings from it.
      def instance = @instance ||= new
    end

    def initialize
      @views = []
      @dark = false
      configure_cookies
      set_style
      watch_settings
    end

    # Register an article view: give it the shared settings, inject the
    # stylesheets into its own content manager and put it on the skin's
    # mailing list. Returns the view.
    def register(view)
      view.tap do |registered|
        @views << registered
        registered.settings = web_settings
        inject(registered)
        registered.set_wikipedia_skin(@dark)
      end
    end

    # Drop a view that has been closed, so a destroyed view is not styled
    # again on the next change.
    def unregister(view) = @views.delete(view)

    # Whether articles are currently rendered with Wikipedia's night skin.
    def dark? = @dark

    # Inject the stylesheets that customise the article view, as upstream's
    # set_style does: the article sheet, the font sheet, the sepia sheet for
    # the sepia theme, and the previews sheet when previews are off. The
    # memory cache is cleared first so that a page already rendered picks the
    # new sheets up.
    def set_style
      clear_memory_cache
      @dark = dark_skin?
      @views.each do |view|
        inject(view)
        view.set_wikipedia_skin(@dark)
      end
    end

    # The settings object every view shares.
    def web_settings
      @web_settings ||= WebKitGtk::Settings.new.tap do |settings|
        settings.user_agent = USER_AGENT
        settings.default_font_size = Data.settings.get_int('font-size')
        settings.enable_back_forward_navigation_gestures = true
      end
    end

    def network_session = @network_session ||= WebKitGtk::NetworkSession.default
    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    private

      # Upstream's four `changed::` connections. The font size is a WebKit
      # setting rather than a stylesheet, so it is the one key that does not
      # rebuild the sheets.
      def watch_settings
        Data.settings.connect_changed('font-family') { set_style }
        Data.settings.connect_changed('preview-popups') { set_style }
        Data.settings.connect_changed('theme') { set_style }
        Data.settings.connect_changed('font-size') do
          web_settings.default_font_size = Data.settings.get_int('font-size')
        end
        style_manager.signal_connect('notify::dark') { on_system_theme_changed }
      end

      # The system scheme only matters while the theme follows the system.
      def on_system_theme_changed
        if Data.settings.get_int('theme') == THEME_SYSTEM
          set_style
        end
      end

      # Cookies persist as text in the user data directory, exactly where
      # upstream keeps them.
      def configure_cookies
        FileUtils.mkdir_p(Data.data_dir)
        network_session.cookie_manager.tap do |manager|
          manager.accept_policy = :always
          manager.set_persistent_storage(File.join(Data.data_dir, 'cookies'), :text)
        end
      end

      def clear_memory_cache
        network_session.website_data_manager.clear(:memory_cache, 0) { |_manager, _result| }
      end

      def inject(view)
        view.user_content_manager.tap do |manager|
          manager.remove_all_style_sheets
          manager.add_style_sheet(stylesheet(view_css))
          manager.add_style_sheet(stylesheet(font_css))
          if Data.settings.get_int('theme') == THEME_SEPIA
            manager.add_style_sheet(stylesheet(sepia_css))
          end
          unless Data.settings.get_boolean('preview-popups')
            manager.add_style_sheet(stylesheet(HIDE_PREVIEWS_CSS))
          end
        end
      end

      # Dark is either the dark theme outright or the system theme while the
      # system is dark; sepia and light are both light.
      def dark_skin?
        Data.settings.get_int('theme').then do |theme|
          if theme == THEME_SYSTEM
            style_manager.dark?
          else
            theme == THEME_DARK
          end
        end
      end

      def font_css
        "body,h1,h2{font-family:\"#{Data.settings.get_string('font-family')}\"!important}"
      end

      def view_css = @view_css ||= read_asset('view.css')
      def sepia_css = @sepia_css ||= read_asset('sepia.css')

      # All frames, USER level: the rules have to beat Wikipedia's own
      # stylesheet.
      def stylesheet(source)
        WebKitGtk::UserStyleSheet.new(
          source,
          :all_frames,
          :user,
          nil,
          nil,
        )
      end

      # A stylesheet that is not where it should be leaves the article with
      # Wikipedia's own styling, which is upstream's fallback too.
      def read_asset(name)
        File.read(Data.asset_path('styles', name))
      rescue SystemCallError
        ''
      end
  end
end
