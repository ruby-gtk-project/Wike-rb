# frozen_string_literal: true

require 'uri'
require 'webkit-gtk'
require_relative 'data'
require_relative 'page_status'
require_relative 'view_settings'
require_relative 'wikipedia'

module Wike
  # Ported from upstream's WikiView in src/view.py.
  #
  # The article view: a WebKit view that only ever navigates Wikipedia. It
  # loads articles, the main page, a random article and the three local status
  # pages; it answers the questions the rest of the app asks about whatever is
  # on screen (its base URI, its language, whether it is a status page); and it
  # keeps the title, the section list and the language links of the current
  # article, which it fetches from the API on every committed load.
  #
  # Upstream's three GObject signals are callbacks here, which is how the rest
  # of this port passes things up to its host:
  #
  #   on_load_props   — the article's title, sections and language links are in
  #   on_new_page     — a link wants a new tab (middle click)
  #
  # Two things differ from upstream and both are the bindings:
  #
  #   * upstream stores the article title in `self.title`, shadowing
  #     WebKit.WebView's own `title` property. That property is read-only in
  #     the Ruby binding, so the article title is `article_title` here.
  #   * WebKitContextMenuItem has no constructor in the binding, so the four
  #     items upstream adds to the context menu cannot be built, and upstream's
  #     third signal, add-bookmark, has nothing to emit it. The menu is still
  #     pruned to the actions upstream allows, and every one of those four
  #     items has a window action with the same accelerator behind it — Ctrl+D,
  #     Ctrl+U, the article menu's "Open in Browser", and a middle click for a
  #     new tab.
  class WikiView < WebKitGtk::WebView
    # WebKit reports a middle click on a navigation action as button 2.
    MIDDLE_BUTTON = 2

    # The load error upstream lets through without showing its error page: a
    # redirect is not a failure.
    REDIRECT_ERROR = 302

    # The stock context-menu actions upstream keeps; everything else is
    # removed before WebKit shows the menu.
    ALLOWED_CONTEXT_MENU_ACTIONS = %i[
      no_action
      custom
      go_back
      go_forward
      reload
      copy
      copy_image_to_clipboard
      copy_image_url_to_clipboard
    ].freeze

    DARK_SKIN_SCRIPT = <<~JS
      document.documentElement.classList.remove("skin-theme-clientpref-day");
      document.documentElement.classList.add("skin-theme-clientpref-night");
    JS

    LIGHT_SKIN_SCRIPT = <<~JS
      document.documentElement.classList.remove("skin-theme-clientpref-night");
      document.documentElement.classList.add("skin-theme-clientpref-day");
    JS

    class << self
      # Upstream's is_wiki_uri: the article's base URI for a Wikipedia article
      # link, and an empty string for anything else. A class method because
      # the open-link dialog validates a URI before any view has seen it.
      def wiki_uri(text)
        URI.parse(text.to_s).then do |uri|
          if uri.host.to_s.end_with?('.wikipedia.org')
            article_uri(uri)
          else
            ''
          end
        end
      rescue URI::InvalidURIError
        ''
      end

      # The language a Wikipedia host publishes in: the first label of
      # `en.wikipedia.org`.
      def lang_of(uri) = URI.parse(uri.to_s).host.to_s.split('.', 2).first

      # The page name in an article URI, which is what the API takes.
      def page_of(uri) = URI.parse(uri.to_s).path.to_s.sub(%r{\A/wiki/}, '')

      # Upstream's fallback title, used until the API returns the real one.
      def title_of(uri)
        URI::DEFAULT_PARSER.unescape(page_of(uri)).tr('_', ' ')
      end

      private

        def article_uri(uri)
          (uri.path.to_s.empty? ? '/' : uri.path).then do |path|
            if path.start_with?('/wiki/') || path == '/'
              "#{uri.scheme || 'https'}://#{uri.host}#{path}"
            else
              ''
            end
          end
        end
    end

    attr_reader :article_title, :sections, :langlinks, :fail_uri

    def initialize(on_load_props:, on_new_page:)
      super()
      @on_load_props = on_load_props
      @on_new_page = on_new_page
      @article_title = 'Wike'
    end

    def build
      tap do |view|
        view.vexpand = true
        view.set_background_color(Gdk::RGBA.new(1, 1, 1, 0))
        view.zoom_level = Data.settings.get_int('zoom-level') / 100.0

        view_settings.register(view)
        Data.settings.connect_changed('zoom-level') do
          view.zoom_level = Data.settings.get_int('zoom-level') / 100.0
        end

        view.signal_connect('load-changed') { |_view, event| on_load_changed(event) }
        view.signal_connect('load-failed') do |_view, _event, failed_uri, error|
          on_load_failed(failed_uri, error)
        end
        view.signal_connect('decide-policy') do |_view, decision, decision_type|
          on_decide_policy(decision, decision_type)
        end
        view.signal_connect('context-menu') { |_view, menu, hit_test| on_context_menu(menu, hit_test) }
      end
    end

    # Switch the article between Wikipedia's day and night skins.
    def set_wikipedia_skin(dark)
      evaluate_javascript(
        dark ? DARK_SKIN_SCRIPT : LIGHT_SKIN_SCRIPT,
        -1,
        nil,
        nil,
        nil,
      )
    end

    # Load a Wikipedia article by URI.
    def load_wiki(target)
      stop_loading
      load_uri(target.to_s)
    end

    # Go to a section of the article on screen, which is the same URI with the
    # section's anchor as its fragment. A section already in the fragment is
    # left alone, as upstream does, so the jump is not reloaded.
    def load_section(anchor)
      URI::DEFAULT_PARSER.escape(anchor.to_s).then do |section|
        URI.parse(uri.to_s).then do |current|
          unless current.fragment == section
            current.fragment = section
            load_uri(current.to_s)
          end
        end
      end
    end

    # Load the main page of the search language's Wikipedia.
    def load_main
      load_wiki("https://#{Data.settings.get_string('search-language')}.wikipedia.org")
    end

    # Load a random article, which takes an API call to find.
    def load_random
      Wikipedia.get_random(Data.settings.get_string('search-language')) do |random_uri, failed|
        if failed
          load_message(PageStatus::ERROR)
        elsif random_uri
          load_wiki(random_uri)
        else
          load_message(PageStatus::NOT_FOUND)
        end
      end
    end

    # Load the void page a status page is drawn over. The `about:` URI is what
    # the page box reads to pick which status to show.
    def load_message(message_type)
      load_alternate_html('', "about:#{message_type}", nil)
    end

    # The article's URI without the query or the fragment, which is the form
    # bookmarks and history keep.
    def base_uri
      URI.parse(uri.to_s).then do |current|
        if current.fragment
          "#{current.scheme}://#{current.host}#{current.path}"
        else
          uri.to_s
        end
      end
    rescue URI::InvalidURIError
      uri.to_s
    end

    # The language of the article on screen, and nil on a status page.
    def lang
      if local?
        nil
      else
        self.class.lang_of(uri)
      end
    end

    # Whether the page on screen is one of the local status pages.
    def local? = URI.parse(uri.to_s).scheme == 'about'

    private

      def view_settings = ViewSettings.instance

      # Upstream's do_load_changed. A committed load drops the properties of
      # the page that was on screen and asks the API for the new one's, except
      # on a status page, whose title is all there is to tell.
      def on_load_changed(event)
        if event == WebKitGtk::LoadEvent::COMMITTED
          @article_title = 'Wike'
          @sections = nil
          @langlinks = nil
          URI.parse(uri.to_s).then do |current|
            if current.scheme == 'about'
              @article_title = status_title(current.path)
              @on_load_props.call
            else
              request_properties(self.class.page_of(uri), self.class.lang_of(uri))
            end
          end
        end
      end

      def status_title(message_type)
        case message_type
        when PageStatus::NOT_FOUND then 'Article not found'
        when PageStatus::ERROR then 'Can’t access Wikipedia'
        else 'Wike'
        end
      end

      def request_properties(page, page_lang)
        Wikipedia.get_properties(page, page_lang) do |props, _failed|
          if props
            @article_title = props['title']
            @sections = props['sections']
            @langlinks = props['langlinks']
          else
            @article_title = self.class.title_of(uri)
          end
          @on_load_props.call
        end
      end

      # Upstream's do_load_failed: remember the URI so "Try Again" has
      # something to retry, and show the error page. True either way, so
      # WebKit does not show its own.
      def on_load_failed(failed_uri, error)
        unless error.code == REDIRECT_ERROR
          @fail_uri = failed_uri
          load_message(PageStatus::ERROR)
        end
        true
      end

      # Upstream's do_decide_policy. Wikipedia article links load here (or in
      # a new tab on a middle click), everything else opens in the browser,
      # and a reload or a history step on a status page is refused because
      # there is nothing to reload.
      def on_decide_policy(decision, decision_type)
        if %i[navigation_action new_window_action].any? { |type| decision_type == type }
          decide_navigation(decision, decision.navigation_action)
        end
        true
      end

      def decide_navigation(decision, action)
        URI.parse(action.request.uri.to_s).then do |target|
          case action.navigation_type
          when WebKitGtk::NavigationType::LINK_CLICKED
            decide_link(decision, action, target)
          when WebKitGtk::NavigationType::RELOAD, WebKitGtk::NavigationType::BACK_FORWARD
            if target.scheme == 'about'
              decision.ignore
            end
          when WebKitGtk::NavigationType::OTHER
            if target.host.to_s.start_with?('upload.')
              decision.ignore
            end
          end
        end
      rescue URI::InvalidURIError
        decision.ignore
      end

      def decide_link(decision, action, target)
        self.class.wiki_uri(target.to_s).then do |article|
          if article.empty?
            decision.ignore
            launch_browser(target.to_s)
          elsif action.mouse_button == MIDDLE_BUTTON
            decision.ignore
            @on_new_page.call(article)
          elsif article != base_uri
            decision.ignore
            load_wiki(target.to_s)
          end
        end
      end

      def launch_browser(target)
        Gtk::UriLauncher.new(target).launch(root, nil) { |_launcher, _result| }
      end

      # Upstream's do_context_menu. An editable, media or scrollbar context
      # has no menu at all; otherwise the stock items it does not allow are
      # removed and WebKit shows what is left.
      def on_context_menu(menu, hit_test)
        if unwanted_context?(hit_test)
          true
        else
          prune_context_menu(menu)
          false
        end
      end

      def unwanted_context?(hit_test)
        hit_test.context_is_editable? ||
          hit_test.context_is_media? ||
          hit_test.context_is_scrollbar?
      end

      # `any?` with the enum on the left, not Array#include?: GLib::Enum#==
      # resolves a Symbol to an enum value, but include? asks the Symbol
      # first, and Symbol#== against an enum is always false.
      def prune_context_menu(menu)
        menu.items.each do |item|
          unless ALLOWED_CONTEXT_MENU_ACTIONS.any? { |action| item.stock_action == action }
            menu.remove(item)
          end
        end
      end
  end
end
