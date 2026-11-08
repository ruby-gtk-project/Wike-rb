# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'fileutils'
require 'time'

module Wike
  # Ported from upstream's src/data.py and
  # data/com.github.hugolabe.Wike.gschema.xml.
  #
  # Upstream keeps four pieces of state: a GSettings object for the
  # preferences, and three JSON files under the user data directory for the
  # chosen Wikipedia languages, the article history and the bookmarks.
  #
  # The three JSON stores are ported as they are. The settings are not: a
  # GSettings schema has to be compiled and installed into a system schema
  # directory before `Gio::Settings.new` will return rather than abort the
  # process, and requiring an install step to run the app from a checkout is
  # worse than the alternative. The same key names, types and defaults are
  # backed by a JSON file under XDG_CONFIG_HOME instead, behind the same
  # get_boolean/get_int/get_string/bind/changed surface the upstream callers
  # use, so the call sites read the way upstream's do.
  module Data
    # The upstream schema, key for key, with the same types and defaults.
    class Settings
      DEFAULTS = {
        'search-language'    => 'en',
        'search-suggestions' => true,
        'search-desktop'     => false,
        'keep-history'       => true,
        'clear-data'         => false,
        'on-start-load'      => 0,
        'last-uri'           => '',
        'last-tabs'          => {},
        'hide-tabs'          => false,
        'theme'              => 3,
        'zoom-level'         => 100,
        'show-flags'         => true,
        'preview-popups'     => false,
        'custom-font'        => false,
        'font-family'        => 'Sans',
        'font-size'          => 16,
        'panel-pinned'       => false,
        'panel-page'         => 'toc',
        'filter-langlinks'   => 0,
        'filter-history'     => 0,
        'window-width'       => 900,
        'window-height'      => 700,
        'window-max'         => false,
      }.freeze

      def initialize(path: nil)
        @path = path || default_path
        @values = DEFAULTS.merge(read)
        @handlers = {}
      end

      def location = @path

      def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

      def []=(key, value)
        key = key.to_s
        @values[key] = value
        write
        notify(key)
        value
      end

      # The upstream typed accessors. Each one coerces, so a hand-edited file
      # with a string where an integer belongs still yields a usable value.
      def get_boolean(key) = self[key] ? true : false
      def get_int(key) = self[key].to_i
      def get_string(key) = self[key].to_s
      def get_value(key) = self[key]

      def set_boolean(key, value) = self[key] = (value ? true : false)
      def set_int(key, value) = self[key] = value.to_i
      def set_string(key, value) = self[key] = value.to_s
      def set_value(key, value) = self[key] = value

      # Upstream calls settings.sync() before quitting; writes here are
      # already synchronous, so this only has to flush the current values.
      def sync = write

      # Upstream's `settings.connect('changed::key', cb)`. The block is called
      # with the settings object and the key, matching the GSettings callback
      # signature the ported call sites expect.
      def connect_changed(key, &block)
        (@handlers[key.to_s] ||= []) << block
        block
      end

      # Upstream's `settings.bind(key, widget, property, DEFAULT)`: a two-way
      # binding between a key and a widget property.
      def bind(key, widget, property)
        key = key.to_s
        widget.set_property(property.to_s.tr('-', '_'), self[key])
        widget.signal_connect("notify::#{property}") do
          widget.get_property(property.to_s.tr('-', '_')).then do |value|
            unless value == self[key]
              self[key] = value
            end
          end
        end
        connect_changed(key) do
          unless widget.get_property(property.to_s.tr('-', '_')) == self[key]
            widget.set_property(property.to_s.tr('-', '_'), self[key])
          end
        end
      end

      private

        def notify(key)
          @handlers.fetch(key, []).each { |handler| handler.call(self, key) }
        end

        def default_path
          File.join(Data.config_dir, 'settings.json')
        end

        def read
          File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
        rescue JSON::ParserError => e
          warn "Error parsing #{@path}: #{e.message}"
          {}
        end

        def write
          FileUtils.mkdir_p(File.dirname(@path))
          File.write(@path, JSON.generate(@values))
        end
    end

    # Wikipedia languages. `wikilangs` is every language Wikipedia publishes
    # in, read from the bundled asset; `items` is the subset the user picked,
    # persisted to languages.json in the user data directory.
    class Languages
      attr_reader :wikilangs
      attr_accessor :items

      def initialize(path: nil)
        @path = path || File.join(Data.data_dir, 'languages.json')
        @wikilangs = load_wikilangs
        @items = load_items
      end

      def clear = @items.clear

      def save
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(@items))
      end

      # The display name for a language code, falling back to the code itself
      # for a language the bundled list does not name.
      def name_for(lang)
        @wikilangs.key?(lang) ? Data.capitalize(@wikilangs[lang]) : lang
      end

      private

        def load_wikilangs
          JSON.parse(File.read(Data.asset_path('languages.json')))
        rescue SystemCallError, JSON::ParserError => e
          warn "Can't load languages file from assets: #{e.message}"
          {}
        end

        def load_items
          JSON.parse(File.read(@path))
        rescue SystemCallError, JSON::ParserError
          { 'en' => 'English' }
        end
    end

    # History of recent articles, keyed by date then by article URI:
    # { '2026-11-02' => { uri => [time, title, lang] } }.
    class History
      attr_accessor :items

      def initialize(path: nil, keep: true)
        @path = path || File.join(Data.data_dir, 'historic.json')
        if keep
          @items = load
        else
          @items = {}
        end
      end

      # The stored tuple carries a fourth element, a full date+time
      # timestamp, alongside the bare time-of-day string upstream keeps for
      # display. A history row's actual chronological position can't be
      # recovered from the time-of-day alone (today's 00:10 entry is not
      # "later" than yesterday's 23:50 one, even though "00:10" < "23:50"
      # lexically and nothing about the bare string says which day it
      # belongs to beyond the outer date key) — the panel's "newest first"
      # sort within a day needs the real timestamp, not the clock face.
      def add(uri, title, lang)
        Time.now.then do |now|
          date = now.strftime('%Y-%m-%d')
          time = now.strftime('%H:%M:%S')
          timestamp = now.strftime('%Y-%m-%d %H:%M:%S')
          (@items[date] ||= {})[uri] = [time, title, lang, timestamp]
        end
      end

      # Returns [item_deleted, date_deleted] the way upstream does, so the
      # panel knows whether the date heading row has to go too.
      def remove(date, uri)
        item_deleted = false
        date_deleted = false

        if @items.key?(date)
          if @items[date].key?(uri)
            @items[date].delete(uri)
            item_deleted = true
          end
          if @items[date].empty?
            @items.delete(date)
            date_deleted = true
          end
        end

        [item_deleted, date_deleted]
      end

      def clear = @items.clear

      def save
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(@items))
      end

      private

        def load
          JSON.parse(File.read(@path))
        rescue SystemCallError, JSON::ParserError
          {}
        end
    end

    # Bookmarks. `items` is the default reading list, { uri => [title, lang] };
    # `lists` holds the named lists, { list_name => items }.
    class Bookmarks
      attr_accessor :items, :lists

      def initialize(path: nil, lists_path: nil)
        @path = path || File.join(Data.data_dir, 'bookmarks.json')
        @lists_path = lists_path || File.join(Data.data_dir, 'booklists.json')
        @items = load(@path)
        @lists = load(@lists_path)
      end

      def add(uri, title, lang, list_name)
        bucket(list_name).then do |bookmarks_items|
          if bookmarks_items.key?(uri)
            false
          else
            bookmarks_items[uri] = [title, lang]
            true
          end
        end
      end

      def remove(uri, list_name)
        bucket(list_name).then do |bookmarks_items|
          if bookmarks_items.key?(uri)
            bookmarks_items.delete(uri)
            true
          else
            false
          end
        end
      end

      def new_list(list_name)
        if @lists.key?(list_name)
          false
        else
          @lists[list_name] = {}
          true
        end
      end

      def remove_list(list_name)
        if @lists.key?(list_name)
          @lists.delete(list_name)
          true
        else
          false
        end
      end

      def rename_list(list_name, new_name)
        if @lists.key?(list_name)
          @lists[new_name] = @lists.delete(list_name)
          true
        else
          false
        end
      end

      def clear_list(list_name) = bucket(list_name).clear

      def save
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(@items))
        FileUtils.mkdir_p(File.dirname(@lists_path))
        File.write(@lists_path, JSON.generate(@lists))
      end

      private

        # A nil list name means the default reading list, as upstream.
        def bucket(list_name) = list_name ? (@lists[list_name] ||= {}) : @items

        def load(path)
          JSON.parse(File.read(path))
        rescue SystemCallError, JSON::ParserError
          {}
        end
    end

    class << self
      def settings = @settings ||= Settings.new
      def languages = @languages ||= Languages.new
      def history = @history ||= History.new(keep: settings.get_boolean('keep-history'))
      def bookmarks = @bookmarks ||= Bookmarks.new

      # Where the bundled data/ assets live: next to lib/, both in a checkout
      # and in the tree the flake installs.
      def asset_dir = @asset_dir ||= File.expand_path('../../data', __dir__)
      def asset_path(*parts) = File.join(asset_dir, *parts)

      # The bundled flag emblems are registered as a hicolor icon theme, so a
      # language code doubles as an icon name. Upstream asks the resource
      # bundle whether the SVG is there before setting it; the port asks the
      # asset directory, and returns nil for a language with no flag so the
      # row keeps the `noflag` placeholder from the layout.
      def flag_icon_name(lang)
        if File.exist?(
          asset_path(
            'icons',
            'hicolor',
            'scalable',
            'emblems',
            "#{lang}.svg",
          ),
        )
          lang
        end
      end

      # Puts the bundled actions, emblems and app icons on the icon theme's
      # search path, so every `icon_name` in the ported layouts resolves.
      def install_icons(display = Gdk::Display.default)
        Gtk::IconTheme.get_for_display(display).add_search_path(asset_path('icons'))
      end

      def data_dir
        @data_dir ||= File.join(
          ENV.fetch('XDG_DATA_HOME', File.expand_path('~/.local/share')),
          'wike-rb',
        )
      end

      def config_dir
        @config_dir ||= File.join(
          ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
          'wike-rb',
        )
      end

      # Python's str.capitalize() uppercases the first character and leaves
      # the rest alone for the scripts where case does not apply; Ruby's
      # String#capitalize downcases the tail, which would mangle names like
      # 'Bahasa Indonesia'. This is the Python behaviour upstream relies on.
      def capitalize(text)
        text.to_s.then do |value|
          value.empty? ? value : value[0].upcase + value[1..]
        end
      end
    end
  end
end
