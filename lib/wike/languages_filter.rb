# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's LanguagesFilter in src/langlinks.py.
  #
  # One entry of the language-links panel's filter dropdown: a display name
  # and the level it selects — 0 for the user's own languages, 1 for all of
  # them, which is the value stored in the `filter-langlinks` setting.
  #
  # Upstream makes this a GObject with `name` and `level` properties so a
  # Gtk::SignalListItemFactory can bind the name straight onto a label.
  # Registering GObject properties from Ruby buys nothing here — the panel
  # feeds the dropdown a Gtk::StringList of names and keeps these objects
  # alongside it — so this is a plain value object with the same two readers.
  class LanguagesFilter
    attr_reader :name, :level

    def initialize(name, level)
      @name = name
      @level = level
    end
  end
end
