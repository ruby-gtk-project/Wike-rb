# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's TocBoxRow in src/toc.py and data/gtk/toc-row.ui.
  #
  # One section of the article's table of contents. The section's depth drives
  # both the indent — 3px plus 15px per level below the first — and the
  # `caption` style class that makes everything under a top-level heading
  # smaller.
  class TocBoxRow < Gtk::ListBoxRow
    attr_reader :anchor

    def initialize(section, anchor, level)
      super()
      @section = section
      @anchor = anchor
      @level = level
    end

    def build
      tap do |row|
        row.child = section_label
      end
    end

    def section_label
      @section_label ||= Gtk::Label.new.tap do |label|
        label.margin_start = 3 + ((@level - 1) * 15)
        label.margin_end = 3
        label.halign = :start
        label.ellipsize = :end
        label.use_markup = true
        label.label = @section.to_s
        if @level > 1
          label.add_css_class('caption')
        end
      end
    end
  end
end
