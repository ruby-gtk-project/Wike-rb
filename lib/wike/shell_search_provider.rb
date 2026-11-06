# frozen_string_literal: true

require 'gtk4'
require_relative 'data'
require_relative 'wikipedia'

module Wike
  # Ported from upstream's src/wike-sp.in: the standalone D-Bus service that
  # lets GNOME Shell's search bar query Wikipedia without the app's window
  # ever opening.
  #
  # Upstream is a GApplication that overrides `do_dbus_register` to add its
  # own object alongside the one GApplication registers for itself. The Ruby
  # GNOME bindings expose no vfunc override hooks at all (confirmed: neither
  # `Gio::Application#dbus_register` nor a `dbus-register` signal exists), so
  # this registers the object by hand from the `startup` signal instead,
  # against the connection `app.dbus_connection` already holds once GLib has
  # finished `g_application_register`. The object upstream's shell exposes —
  # method names, argument shapes, lifetime — is identical either way.
  #
  # The five org.gnome.Shell.SearchProvider2 methods, ported one for one:
  #
  #   GetInitialResultSet   — upstream's a search; `-lang text` picks a
  #                           language the way upstream's leading `-xx` does
  #   GetSubsearchResultSet — upstream just calls the method above again
  #   GetResultMetas        — the id/name pairs the shell shows for a result
  #   ActivateResult        — opens the chosen result in the app
  #   LaunchSearch          — opens the app with nothing chosen
  #
  # GVariant construction is the other binding gap: the binding converts a
  # Ruby Hash into a GVariant dict for nothing more complex than `{sv}`
  # members (`GLib::Variant.new(hash)` raises `NotImplementedError` for it),
  # so `GetResultMetas`'s `aa{sv}` reply is built from GVariant text format
  # through `GLib::Variant.parse`, with every string value escaped first.
  class ShellSearchProvider
    APP_ID = 'org.rubygtkproject.Wike.SearchProvider'
    OBJECT_PATH = '/org/rubygtkproject/Wike/SearchProvider'

    # A service with nothing to do for this long lets go of the bus name,
    # which is upstream's `inactivity_timeout`.
    INACTIVITY_TIMEOUT = 10_000

    # Upstream counts "no match" below this length, after the `-lang` prefix
    # (if any) is stripped.
    MIN_SEARCH_LENGTH = 2

    INTERFACE_XML = <<~XML
      <node>
        <interface name="org.gnome.Shell.SearchProvider2">
          <method name="GetInitialResultSet">
            <arg type="as" name="terms" direction="in" />
            <arg type="as" name="results" direction="out" />
          </method>
          <method name="GetSubsearchResultSet">
            <arg type="as" name="previous_results" direction="in" />
            <arg type="as" name="terms" direction="in" />
            <arg type="as" name="results" direction="out" />
          </method>
          <method name="GetResultMetas">
            <arg type="as" name="identifiers" direction="in" />
            <arg type="aa{sv}" name="metas" direction="out" />
          </method>
          <method name="ActivateResult">
            <arg type="s" name="identifier" direction="in" />
            <arg type="as" name="terms" direction="in" />
            <arg type="u" name="timestamp" direction="in" />
          </method>
          <method name="LaunchSearch">
            <arg type="as" name="terms" direction="in" />
            <arg type="u" name="timestamp" direction="in" />
          </method>
        </interface>
      </node>
    XML

    def initialize
      @results = {}
      @lang = Data.settings.get_string('search-language')
      Data.settings.connect_changed('search-language') do
        @lang = Data.settings.get_string('search-language')
      end
    end

    def build
      app.tap do |application|
        application.signal_connect('startup') do
          register_object(application)
          # Upstream holds the service in use for its whole lifetime — a
          # provider with no window to keep the process open needs
          # something to, or GApplication exits the moment startup returns.
          application.hold
        end
      end
    end

    def run = app.run([])

    def app
      @app ||= Gio::Application.new(APP_ID, :is_service).tap do |application|
        application.inactivity_timeout = INACTIVITY_TIMEOUT
      end
    end

    # --- The five SearchProvider2 methods, each matching upstream's ------

    # Upstream's GetInitialResultSet: a leading `-lang` (a Wikipedia language
    # code) picks the search language for this query and is stripped from
    # the text; too short a remainder clears the results. With desktop search
    # on, the results are real matches from the API; with it off, upstream
    # shows one row that opens a plain Wikipedia search instead.
    def get_initial_result_set(terms)
      text = terms.join(' ')
      lang = @lang
      @results = {}

      prefix = terms.first.to_s
      if prefix.start_with?('-') && Data.languages.wikilangs.key?(prefix.delete_prefix('-'))
        lang = prefix.delete_prefix('-')
        text = terms[1..].to_a.join(' ')
      end

      if text.length > MIN_SEARCH_LENGTH
        if Data.settings.get_boolean('search-desktop')
          fill_results(text, lang)
        else
          @results["search:#{lang}:#{text}"] = "Search \u201C#{text}\u201D on Wikipedia"
        end
      end

      @results.keys
    end

    def get_subsearch_result_set(_previous_results, new_terms)
      get_initial_result_set(new_terms)
    end

    # The id/name pairs the shell renders for each result GetInitialResultSet
    # (or GetSubsearchResultSet) returned.
    def get_result_metas(identifiers)
      identifiers.filter_map do |identifier|
        @results[identifier].then do |name|
          if name
            [identifier, name]
          end
        end
      end
    end

    # Opens the chosen result — or, for a plain-search row, runs the search
    # for real and opens whatever its first match turns out to be.
    def activate_result(identifier, _terms, _timestamp)
      if identifier.start_with?('search:')
        @results = {}
        _tag, lang, text = identifier.split(':', 3)
        fill_results(text, lang)
        launch_app(@results.empty? ? 'notfound' : @results.keys.first)
      else
        launch_app(identifier)
      end
    end

    # Opens the app on its current page, with nothing chosen.
    def launch_search(_terms, _timestamp) = launch_app(nil)

    private

      # Upstream's _get_results: a blocking search, since the D-Bus call this
      # answers is itself synchronous.
      def fill_results(text, lang)
        titles, urls = Wikipedia.search(text.downcase, lang, 5)
        if titles
          titles.zip(urls).each { |title, url| @results[url] = title }
        end
      end

      # Upstream spawns the launcher with `--url`, or with nothing at all for
      # LaunchSearch. `Process.spawn` plus `Process.detach` is upstream's
      # `GLib.spawn_async_with_pipes` with `SEARCH_PATH`: the GLib spawn
      # functions carry no GObject-Introspection annotations, so the binding
      # exposes none of them, and this is the plain Ruby equivalent.
      def launch_app(uri)
        Process.detach(
          uri ? Process.spawn('wike', '--url', uri) : Process.spawn('wike'),
        )
      end

      def register_object(application)
        info = Gio::DBusNodeInfo.new(INTERFACE_XML)
        interface = info.lookup_interface('org.gnome.Shell.SearchProvider2')
        application.dbus_connection.register_object(OBJECT_PATH, interface) do |_connection, _sender, _path, _iface, method, params, invocation|
          safe_dispatch(method, params.to_a, invocation)
        end
      end

      # An exception escaping a GObject-Introspection method-call closure
      # propagates all the way out of `Gio::Application#run` and takes the
      # whole service down — confirmed by letting `ActivateResult` spawn a
      # launcher that was not on PATH, which killed the process rather than
      # just failing that one call. Upstream's Python binding logs an
      # unhandled callback exception and carries on instead, so one bad
      # request here is answered with a D-Bus error and the service keeps
      # running, matching that.
      def safe_dispatch(method, arguments, invocation)
        dispatch(method, arguments, invocation)
      rescue StandardError => e
        warn "#{method} failed: #{e.class}: #{e.message}"
        invocation.return_dbus_error('org.gnome.Shell.SearchProvider2.Error', e.message)
      end

      # One call site, dispatching by method name the way upstream's single
      # `on_dbus_method_call` does with `getattr`. Each branch returns the
      # GVariant `return_value` wants, built as plainly as the method's
      # signature allows — the `aa{sv}` reply is the one shape the binding
      # cannot build directly (see the class comment), so it alone goes
      # through GVariant text format.
      def dispatch(method, arguments, invocation)
        case method
        when 'GetInitialResultSet'
          invocation.return_value(string_array_variant(get_initial_result_set(arguments[0])))
        when 'GetSubsearchResultSet'
          invocation.return_value(
            string_array_variant(get_subsearch_result_set(arguments[0], arguments[1])),
          )
        when 'GetResultMetas'
          invocation.return_value(result_metas_variant(get_result_metas(arguments[0])))
        when 'ActivateResult'
          activate_result(arguments[0], arguments[1], arguments[2])
          invocation.return_value(nil)
        when 'LaunchSearch'
          launch_search(arguments[0], arguments[1])
          invocation.return_value(nil)
        end
      end

      # `GLib::Variant.new(array)` builds a bare `as`, and
      # `g_dbus_method_invocation_return_value` demands a tuple — the
      # assertion the Ruby process otherwise dies on is
      # `g_variant_is_of_type (parameters, G_VARIANT_TYPE_TUPLE)` — so the
      # single result array is wrapped as the one-member tuple `(as)` the
      # method's `out` signature declares.
      def string_array_variant(strings)
        strings.map { |s| quoted(s) }.join(', ').then do |entries|
          GLib::Variant.parse("([#{entries}],)", '(as)')
        end
      end

      def result_metas_variant(metas)
        metas.map { |id, name| "{\"id\": <#{quoted(id)}>, \"name\": <#{quoted(name)}>}" }
          .then { |entries| "([#{entries.join(', ')}],)" }
          .then { |text| GLib::Variant.parse(text, '(aa{sv})') }
      end

      # GVariant text format's double-quoted string literal, with the two
      # characters that would otherwise end it or start an escape escaped
      # first.
      def quoted(text)
        "\"#{text.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}\""
      end
  end
end
