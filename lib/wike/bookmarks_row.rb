# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's BookmarksRow in src/bookmarks.py and
  # data/gtk/bookmarks-row.ui.
  #
  # One bookmarked article: title over the language's display name, with a
  # check button that the panel's selection mode reveals.
  class BookmarksRow < Gtk::ListBoxRow
    attr_reader :uri, :title, :lang

    def initialize(uri, title, lang)
      super()
      @uri = uri
      @title = title
      @lang = lang
    end

    def build
      tap do |row|
        row.child = row_box

        row_box.tap do |box|
          box.append(select_check)
          box.append(labels_box)

          labels_box.tap do |labels|
            labels.append(title_label)
            labels.append(lang_label)
          end
        end
      end
    end

    def row_box
      @row_box ||= Gtk::Box.new(:horizontal, 9).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 3
        box.margin_end = 3
      end
    end

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 3).tap do |box|
        box.hexpand = true
        box.valign = :center
      end
    end

    def select_check
      @select_check ||= Gtk::CheckButton.new.tap do |check|
        check.valign = :center
        check.visible = false
        check.add_css_class('selection-mode')
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.ellipsize = :end
        label.label = @title.to_s
      end
    end

    # Upstream names the language with the bundled list's display name, and
    # falls back to the bare code for a language the list does not cover.
    def lang_label
      @lang_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.ellipsize = :end
        label.label = Data.languages.name_for(@lang)
        label.add_css_class('caption')
        label.add_css_class('dim-label')
      end
    end
  end
end
