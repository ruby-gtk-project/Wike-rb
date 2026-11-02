# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's HistoryRow in src/history.py and
  # data/gtk/history-row.ui.
  #
  # One visited article: title over the time it was read and the language it
  # was read in, with a check button that the panel's selection mode reveals.
  # The stored time carries seconds; the row shows hours and minutes only.
  class HistoryRow < Gtk::ListBoxRow
    attr_reader :uri, :title, :lang, :date, :time

    def initialize(uri, title, lang, date, time)
      super()
      @uri = uri
      @title = title
      @lang = lang
      @date = date
      @time = time.to_s.rpartition(':').first.then { |hhmm| hhmm.empty? ? time.to_s : hhmm }
    end

    def build
      tap do |row|
        row.child = row_box

        row_box.tap do |box|
          box.append(select_check)
          box.append(labels_box)

          labels_box.tap do |labels|
            labels.append(title_label)
            labels.append(meta_box)

            meta_box.tap do |meta|
              meta.append(time_label)
              meta.append(lang_label)
            end
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

    def meta_box = @meta_box ||= Gtk::Box.new(:horizontal, 6)

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

    def time_label
      @time_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.label = @time
        label.add_css_class('caption')
        label.add_css_class('dim-label')
      end
    end

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
