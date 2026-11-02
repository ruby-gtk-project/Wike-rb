# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's HistoryFilter in src/history.py.
  #
  # One entry of the history panel's filter dropdown: a display name and the
  # number of days back it shows. Upstream's four entries are Today (1), Last
  # 7 days (7), Last 30 days (30) and Show full history (365), and the chosen
  # index is stored in the `filter-history` setting.
  #
  # A plain value object for the same reason as LanguagesFilter: the panel
  # drives the dropdown with a Gtk::StringList and resolves the selected index
  # back to one of these.
  class HistoryFilter
    attr_reader :name, :days

    def initialize(name, days)
      @name = name
      @days = days
    end
  end
end
