# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'net/http'
require 'uri'

module Wike
  # Ported from upstream's src/wikipedia.py: the three Wikipedia Action API
  # calls the app makes, plus the shared request plumbing.
  #
  # Upstream talks to the API through libsoup 3 and its
  # send_and_read_async/send_and_read_finish pair. There is no libsoup binding
  # in the Ruby GNOME stack, so the transport here is Net::HTTP. The
  # asynchronous shape is kept: the request runs on its own thread and the
  # result is handed back to the caller from a GLib::Idle callback, so the
  # block always runs on the main loop and may touch widgets, exactly as the
  # libsoup callbacks upstream do.
  module Wikipedia
    USER_AGENT = 'Wike/3.2.1 (https://github.com/hugolabe)'

    # The API refuses to answer without one, and a slow network should not
    # wedge the thread forever.
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 20

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
      # matches) and whether the request failed; with no block it blocks and
      # returns the pair.
      def search(text, lang, limit, &callback)
        {
          'action'    => 'opensearch',
          'search'    => text,
          'limit'     => limit,
          'namespace' => 0,
          'redirects' => 'resolve',
          'format'    => 'json',
        }.then do |params|
          if callback
            request(endpoint(lang), params) { |data| callback.call(search_result(data), data.nil?) }
          else
            search_result(fetch(endpoint(lang), params))
          end
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

        # Upstream's _request. The callback form runs the query on its own
        # thread and returns immediately; the result is delivered on the main
        # loop so the block may touch widgets.
        def request(endpoint, params, &callback)
          Thread.new do
            fetch(endpoint, params).then do |data|
              GLib::Idle.add do
                callback.call(data)
                GLib::Source::REMOVE
              end
            end
          end
        end

        # The blocking query. Returns the response body for a 200, nil
        # otherwise — including for a connection that never got that far,
        # which is upstream's "the callback raised" path.
        def fetch(endpoint, params)
          URI.parse(endpoint).then do |uri|
            uri.query = URI.encode_www_form(params)
            Net::HTTP.start(
              uri.host,
              uri.port,
              use_ssl:      true,
              open_timeout: OPEN_TIMEOUT,
              read_timeout: READ_TIMEOUT,
            ) do |http|
              http.request(Net::HTTP::Get.new(uri, 'User-Agent' => USER_AGENT)).then do |response|
                if response.is_a?(Net::HTTPOK)
                  response.body
                end
              end
            end
          end
        rescue StandardError, Timeout::Error => e
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
