# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's Booklist in src/bookmarks.py.
  #
  # One entry of the bookmarks panel's list dropdown. Position 0 is always the
  # default reading list, which has no entry in the bookmarks store — the
  # panel represents it with a nil list name — and every other entry names one
  # of the user's own lists.
  class Booklist
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end
end
