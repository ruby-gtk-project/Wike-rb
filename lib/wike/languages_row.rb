# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's LanguagesRow in src/languages.py and
  # data/gtk/languages-row.ui.
  #
  # One Wikipedia language in the "Pick your Languages" dialog: a check button
  # whose state is whether the user has picked the language, the language's
  # name, and its code underneath.
  class LanguagesRow < Gtk::ListBoxRow
    attr_reader :lang_name, :lang_id

    def initialize(lang_name, lang_id, checked)
      super()
      @lang_name = lang_name
      @lang_id = lang_id
      @checked = checked
    end

    def build
      tap do |row|
        row.child = row_box

        row_box.tap do |box|
          box.append(lang_check)
          box.append(labels_box)

          labels_box.tap do |labels|
            labels.append(name_label)
            labels.append(id_label)
          end
        end
      end
    end

    def row_box
      @row_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 3
      end
    end

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
        box.valign = :center
      end
    end

    def lang_check
      @lang_check ||= Gtk::CheckButton.new.tap do |check|
        check.valign = :center
        check.active = @checked
        check.add_css_class('selection-mode')
      end
    end

    def name_label
      @name_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.label = @lang_name.to_s
      end
    end

    def id_label
      @id_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.label = @lang_id.to_s
        label.add_css_class('dim-label')
      end
    end
  end
end
