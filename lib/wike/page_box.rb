# frozen_string_literal: true

require 'adwaita'
require 'webkit-gtk'
require_relative 'data'
require_relative 'page_status'
require_relative 'view_settings'
require_relative 'wiki_view'

module Wike
  # Ported from upstream's PageBox in src/page.py and data/gtk/page.ui.
  #
  # One tab's content: the in-article text search bar above a stack that shows
  # either the article view or the status page. It owns the view, drives the
  # find controller behind the search bar, and turns the view's load events
  # into the things the window has to do — the tab's title and spinner, the
  # window title, the sidebar panels, the history entry and the navigation
  # actions.
  #
  # Like upstream it is handed the window rather than a bag of callbacks: it
  # talks to the tab view, five panels and four window actions, and the window
  # is the thing that has them. `tab_page` is set by the window as soon as the
  # box is in the tab view, where upstream looks it up through the window on
  # every event.
  #
  # A tab restored from the last session starts empty: `lazy_load` holds its
  # [uri, title] until the tab is first selected and `load_now` loads it.
  class PageBox < Gtk::Box
    # The keys WebKit is allowed to keep for itself; everything else is
    # forwarded to the window so the app's accelerators still fire while the
    # article has the focus. Tab, Return and the navigation keys, by keyval.
    WEBKIT_ALLOW_KEYS = [
      0xff09,
      0xff0d,
      0xff50,
      0xff51,
      0xff52,
      0xff53,
      0xff54,
      0xff55,
      0xff56,
      0xff57,
    ].freeze

    # Upstream counts at most this many matches of the search text.
    MAX_MATCHES = 9999

    # Upstream searches once the text is longer than two characters.
    MIN_SEARCH_LENGTH = 2

    attr_reader :lazy_load
    attr_accessor :tab_page

    def initialize(window:, lazy_load: nil)
      super(:vertical, 0)
      @window = window
      @lazy_load = lazy_load
    end

    def build
      tap do |page|
        page.append(search_bar)
        page.append(view_stack)

        search_bar.tap do |bar|
          bar.child = search_box
          bar.connect_entry(search_entry)

          search_box.tap do |box|
            box.append(search_entry)
            box.append(search_prev_button)
            box.append(search_next_button)
            box.append(search_matches_label)
          end
        end

        view_stack.tap do |stack|
          stack.add_named(wikiview.build, 'wikiview')
          stack.add_named(status.build, 'status')
          stack.visible_child_name = 'wikiview'
        end

        connect_search
        connect_view
      end
    end

    # Put the focus where the eye is, as upstream does when the sidebar
    # closes: on the status page's first button, or in the article.
    def set_focus
      if view_stack.visible_child_name == 'status'
        status.main_page_button.grab_focus
      else
        wikiview.grab_focus
      end
    end

    # Load a tab that was restored but never loaded, which is what happens
    # the first time the user selects it.
    def load_now
      @lazy_load.then do |uri, _title|
        @lazy_load = nil
        wikiview.load_wiki(uri)
      end
    end

    # Reveal the text search bar, or focus it when it is already up, which is
    # upstream's Ctrl+F.
    def show_text_search
      if search_bar.search_mode?
        search_entry.grab_focus
      else
        search_bar.search_mode = true
      end
    end

    # Memoized widget methods

    def view_stack = @view_stack ||= Gtk::Stack.new

    def search_bar
      @search_bar ||= Gtk::SearchBar.new.tap do |bar|
        bar.show_close_button = true
      end
    end

    def search_box = @search_box ||= Gtk::Box.new(:horizontal, 6)

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.max_width_chars = 30
        entry.placeholder_text = 'Search text'
      end
    end

    def search_prev_button
      @search_prev_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-up-symbolic'
        button.tooltip_text = 'Previous Result'
        button.sensitive = false
      end
    end

    def search_next_button
      @search_next_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-down-symbolic'
        button.tooltip_text = 'Next Result'
        button.sensitive = false
      end
    end

    def search_matches_label
      @search_matches_label ||= Gtk::Label.new.tap do |label|
        label.width_chars = 4
        label.margin_start = 9
        label.xalign = 0
      end
    end

    def wikiview
      @wikiview ||= WikiView.new(
        on_load_props: -> { on_load_props },
        on_new_page:   ->(uri) { @window.new_page(uri, tab_page, false) },
      )
    end

    def status = @status ||= PageStatus.new(on_try_again: -> { retry_failed })

    def find_controller = @find_controller ||= wikiview.find_controller

    private

      def connect_search
        search_entry.signal_connect('search-changed') { on_search_changed }
        search_entry.signal_connect('activate') { on_search_activate }
        search_prev_button.signal_connect('clicked') { find_controller.search_previous }
        search_next_button.signal_connect('clicked') { find_controller.search_next }
        find_controller.signal_connect('found-text') { on_found_text }
        find_controller.signal_connect('failed-to-find-text') { on_not_found_text }
        find_controller.signal_connect('counted-matches') { |_controller, count| on_counted(count) }
      end

      def connect_view
        wikiview.add_controller(key_controller)
        key_controller.signal_connect('key-pressed') do |controller, keyval, _code, state|
          on_key_pressed(controller, keyval, state)
        end
        wikiview.signal_connect('load-changed') { |_view, event| on_load_changed(event) }
        wikiview.back_forward_list.signal_connect('changed') { on_nav_list_changed }
      end

      def key_controller = @key_controller ||= Gtk::EventControllerKey.new

      # WebKit keeps the keys it needs to move around a page; everything else
      # is handed to the window, where the accelerators live. True means the
      # key has been dealt with here.
      def on_key_pressed(controller, keyval, state)
        if WEBKIT_ALLOW_KEYS.include?(keyval) || state == Gdk::ModifierType::CONTROL_MASK
          false
        else
          controller.forward(@window)
          true
        end
      end

      # Upstream's _wikiview_load_changed_cb: the tab's title and spinner, the
      # stack page, the window title and Wikipedia's skin, by load phase.
      def on_load_changed(event)
        case event
        when WebKitGtk::LoadEvent::STARTED then on_load_started
        when WebKitGtk::LoadEvent::COMMITTED then on_load_committed
        when WebKitGtk::LoadEvent::FINISHED then on_load_finished
        end
      end

      def on_load_started
        @is_main = wikiview.uri.to_s.end_with?('.wikipedia.org/')
        search_bar.search_mode = false
        view_stack.visible_child_name = 'wikiview'
        tab_page&.tap do |page|
          page.title = 'Loading…'
          page.loading = true
          if page.selected?
            @window.title = 'Loading…'
            wikiview.grab_focus
          end
        end
      end

      # The skin has to be re-applied on every commit: the page that has just
      # been committed is Wikipedia's own markup, with Wikipedia's own day
      # class on it.
      def on_load_committed
        wikiview.set_wikipedia_skin(ViewSettings.instance.dark?)
      end

      def on_load_finished
        tab_page&.loading = false
        if wikiview.local?
          show_status(wikiview.uri.to_s)
        end
      end

      # Upstream's status page dispatches on the `about:` URI the view sits
      # on; PageStatus takes the message type, which is all of that URI it
      # reads.
      def show_status(uri)
        status.show(uri.to_s.sub(/\Aabout:/, ''))
        view_stack.visible_child_name = 'status'
      end

      # Upstream's _wikiview_load_props_cb: the properties are in, so the tab
      # and — for the tab on screen — the window and its panels catch up.
      def on_load_props
        tab_page&.title = wikiview.article_title
        if tab_page.nil? || tab_page.selected?
          @window.show_article(wikiview)
        end
        record_history
      end

      def record_history
        if Data.settings.get_boolean('keep-history') && !@is_main && !wikiview.local?
          @window.history_panel.add_item(
            wikiview.base_uri,
            wikiview.article_title,
            wikiview.lang,
          )
        end
      end

      def on_nav_list_changed
        if tab_page.nil? || tab_page.selected?
          @window.refresh_nav_actions(wikiview)
        end
      end

      def retry_failed
        wikiview.fail_uri.then do |uri|
          if uri
            wikiview.load_wiki(uri)
          end
        end
      end

      # Upstream searches and counts in one go, and resets the bar below the
      # minimum length.
      def on_search_changed
        search_entry.text.then do |text|
          if text.length > MIN_SEARCH_LENGTH
            find_controller.count_matches(text, find_options, MAX_MATCHES)
            find_controller.search(text, find_options, MAX_MATCHES)
          else
            reset_search
          end
        end
      end

      def on_search_activate
        if search_entry.text.length > MIN_SEARCH_LENGTH
          find_controller.search_next
        end
      end

      def find_options
        @find_options ||= WebKitGtk::FindOptions::WRAP_AROUND |
                          WebKitGtk::FindOptions::CASE_INSENSITIVE
      end

      def on_found_text
        search_prev_button.sensitive = true
        search_next_button.sensitive = true
      end

      def on_not_found_text
        search_matches_label.label = ''
        search_entry.add_css_class('error')
        search_prev_button.sensitive = false
        search_next_button.sensitive = false
        find_controller.search_finish
      end

      def on_counted(count)
        if count.positive?
          search_matches_label.label = count.to_s
          search_entry.remove_css_class('error')
        end
      end

      def reset_search
        search_matches_label.label = ''
        search_entry.remove_css_class('error')
        search_prev_button.sensitive = false
        search_next_button.sensitive = false
        find_controller.search_finish
      end
  end
end
