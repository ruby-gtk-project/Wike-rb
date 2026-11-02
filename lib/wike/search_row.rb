# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's SearchRow in src/search.py and
  # data/gtk/search-row.ui.
  #
  # One Wikipedia search suggestion: the article title, with the article URI
  # carried alongside so the panel can load it when the row is activated.
  class SearchRow < Gtk::ListBoxRow
    attr_reader :title, :uri

    def initialize(title, uri)
      super()
      @title = title
      @uri = uri
    end

    def build
      tap do |row|
        row.child = suggestion_label
      end
    end

    def suggestion_label
      @suggestion_label ||= Gtk::Label.new.tap do |label|
        label.margin_start = 3
        label.margin_end = 3
        label.halign = :start
        label.ellipsize = :end
        label.label = @title.to_s
      end
    end
  end
end
