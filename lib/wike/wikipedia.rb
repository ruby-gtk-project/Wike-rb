# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'soup3'
require 'uri'

module Wike
  # Ported from upstream's src/wikipedia.py: the three Wikipedia Action API
  # calls the app makes, plus the shared request plumbing.
  #
  # Upstream talks to the API through libsoup 3 and its
  # send_and_read_async/send_and_read_finish pair, which the soup3 gem binds
  # directly: one Soup::Session shared across every call, each request a
  # Soup::Message, and the response bytes read back on the block
  # send_and_read_async hands its result to — already on the GLib main loop,
  # so the block may touch widgets exactly as upstream's callback does.
  module Wikipedia
    USER_AGENT = 'Wike/3.2.1 (https://github.com/hugolabe)'

    # The API refuses to answer without one, and a slow network should not
    # wedge the main loop forever.
    TIMEOUT = 10

    class << self
      # Get a Wikipedia random page. The block receives the article URI — or
      # nil when the response carried no page — and whether the request itself
      # failed, which is upstream's "the libsoup callback raised" path.
      def get_random(lang, &callback)
        request(
          endpoint(lang),
          'action'       => 'query',
          'generator'    => 'random',
          'grnlimit'     => 1,
          'grnnamespace' => 0,
          'prop'         => 'info',
          'inprop'       => 'url',
          'format'       => 'json',
        ) { |data| callback.call(random_result(data), data.nil?) }
      end

      # Search Wikipedia with a limit of responses. With a block the search
      # runs asynchronously and the block receives [titles, uris] (nil for no
      # matches) and whether the request failed; with no block — the shell
      # search provider's own call, which answers a synchronous D-Bus method
      # the way upstream's blocking call does — it runs on the spot and
      # returns the pair directly.
      def search(text, lang, limit, &callback)
        params = {
          'action'    => 'opensearch',
          'search'    => text,
          'limit'     => limit,
          'namespace' => 0,
          'redirects' => 'resolve',
          'format'    => 'json',
        }
        if callback
          request(endpoint(lang), params) { |data| callback.call(search_result(data), data.nil?) }
        else
          search_result(fetch(endpoint(lang), params))
        end
      end

      # Get the section list and language links for a Wikipedia page. The
      # block receives the `parse` object — nil when the page has none — and
      # whether the request failed.
      def get_properties(page, lang, &callback)
        request(
          endpoint(lang),
          'action'    => 'parse',
          'prop'      => 'sections|langlinks',
          'redirects' => 1,
          'page'      => page,
          'format'    => 'json',
        ) { |data| callback.call(properties_result(data), data.nil?) }
      end

      # --- Response decoding, each the counterpart of an upstream *_result --

      def random_result(data)
        parse(data).then do |result|
          result&.dig('query', 'pages').then do |pages|
            if pages.is_a?(Hash) && !pages.empty?
              pages.values.first['fullurl']
            end
          end
        end
      end

      def search_result(data)
        parse(data).then do |result|
          if result.is_a?(Array) && result[1].is_a?(Array) && !result[1].empty?
            [result[1], result[3]]
          end
        end
      end

      def properties_result(data) = parse(data)&.fetch('parse', nil)

      private

        def endpoint(lang) = "https://#{lang}.wikipedia.org/w/api.php"

        def session
          @session ||= Soup::Session.new.tap do |s|
            s.user_agent = USER_AGENT
            s.timeout = TIMEOUT
          end
        end

        # Upstream's _request: a GET of the endpoint with the given query
        # parameters, answered asynchronously on the main loop. The callback
        # receives the response body for a 200, nil otherwise — including for
        # a request that never got that far, which is upstream's "the
        # callback raised" path.
        def request(endpoint, params, &callback)
          message_for(endpoint, params).then do |message|
            session.send_and_read_async(message, GLib::PRIORITY_DEFAULT, nil) do |soup_session, result|
              callback.call(read_response(soup_session, message, result))
            end
          end
        end

        # The blocking counterpart `search` uses when called without a
        # block: the same request, answered on the spot.
        def fetch(endpoint, params)
          message_for(endpoint, params).then do |message|
            bytes = session.send_and_read(message, nil)
            if message.status_code == Soup::Status::OK
              bytes.to_s
            end
          end
        rescue GLib::Error => e
          warn "Wikipedia request failed: #{e.message}"
          nil
        end

        def message_for(endpoint, params)
          URI.parse(endpoint).then do |uri|
            uri.query = URI.encode_www_form(params)
            Soup::Message.new('GET', uri.to_s)
          end
        end

        def read_response(soup_session, message, result)
          bytes = soup_session.send_and_read_finish(result)
          if message.status_code == Soup::Status::OK
            bytes.to_s
          end
        rescue GLib::Error => e
          warn "Wikipedia request failed: #{e.message}"
          nil
        end

        def parse(data)
          data && JSON.parse(data)
        rescue JSON::ParserError => e
          warn "Wikipedia response was not JSON: #{e.message}"
          nil
        end
    end
  end
end
