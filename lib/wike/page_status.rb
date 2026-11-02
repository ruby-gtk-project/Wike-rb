# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's PageStatus in src/page.py and
  # data/gtk/page-status.ui.
  #
  # The status page shown in place of an article: the blank start page, "no
  # article found" after an empty search, and "can't access Wikipedia" after a
  # failed load. Each of the three sets a title, a description, an icon, which
  # of the three buttons are visible, and which one takes focus.
  #
  # Upstream's `show` ends by switching its page's view stack to this status
  # page. That stack belongs to the page box, which is not ported yet, so the
  # last line of `show` is the host's business and not this widget's; here the
  # status page is the content area outright.
  #
  # The one callback is on_try_again, for the button that reloads whichever
  # article failed — the failed URI is the host's, as upstream's fail_uri is
  # the view's.
  #
  class PageStatus < Adwaita::Bin
    BLANK = 'blank'
    NOT_FOUND = 'notfound'
    ERROR = 'error'

    def initialize(on_try_again:)
      super()
      @on_try_again = on_try_again
    end

    def build
      tap do |page|
        page.child = status_page

        status_page.tap do |status|
          status.child = buttons_box

          buttons_box.tap do |box|
            box.append(main_page_button)
            box.append(random_article_button)
            box.append(try_again_button)
          end
        end

        try_again_button.signal_connect('clicked') { @on_try_again.call }
      end
    end

    # Show the status for a message type. Upstream dispatches on the
    # `about:` URI the view is sitting on; the port is handed the bare
    # message type, since that is the only part it reads.
    def show(message_type)
      case message_type
      when NOT_FOUND
        set_status(
          'Article not Found',
          'Can’t find any results for requested query',
          'find-location-symbolic',
        )
        set_buttons(main: true, random: false, try_again: false)
        main_page_button.grab_focus
      when ERROR
        set_status(
          'Can’t Access Wikipedia',
          'Check your Internet connection and try again',
          'network-error-symbolic',
        )
        set_buttons(main: false, random: false, try_again: true)
        try_again_button.grab_focus
      else
        set_status(
          'Search Wikipedia',
          'Start typing to search Wikipedia articles',
          'com.github.hugolabe.Wike',
        )
        set_buttons(main: true, random: true, try_again: false)
        main_page_button.grab_focus
      end
    end

    # Memoized widget methods

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |status|
        status.add_css_class('wikiview-status')
      end
    end

    def buttons_box
      @buttons_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.halign = :center
        box.homogeneous = true
      end
    end

    def main_page_button
      @main_page_button ||= Gtk::Button.new.tap do |button|
        button.label = 'Main Page'
        button.action_name = 'win.main-page'
        button.add_css_class('pill')
        button.add_css_class('suggested-action')
      end
    end

    def random_article_button
      @random_article_button ||= Gtk::Button.new.tap do |button|
        button.label = 'Random Article'
        button.action_name = 'win.random-article'
        button.add_css_class('pill')
      end
    end

    def try_again_button
      @try_again_button ||= Gtk::Button.new.tap do |button|
        button.label = 'Try Again'
        button.visible = false
        button.add_css_class('pill')
        button.add_css_class('suggested-action')
      end
    end

    private

      def set_status(title, description, icon_name)
        status_page.tap do |status|
          status.title = title
          status.description = description
          status.icon_name = icon_name
        end
      end

      def set_buttons(main:, random:, try_again:)
        main_page_button.visible = main
        random_article_button.visible = random
        try_again_button.visible = try_again
      end
  end
end
