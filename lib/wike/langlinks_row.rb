# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's LanglinksRow in src/langlinks.py and
  # data/gtk/langlinks-row.ui.
  #
  # One other-language version of the current article: the language's own name
  # for itself above the article's title in that language, with the flag
  # emblem beside them and the article URI carried for activation.
  class LanglinksRow < Gtk::ListBoxRow
    attr_reader :uri, :lang, :lang_name

    def initialize(uri, lang, lang_name, title)
      super()
      @uri = uri
      @lang = lang
      @lang_name = lang_name
      @title = title
    end

    def build
      tap do |row|
        row.child = row_box

        row_box.tap do |box|
          box.append(flag_image)
          box.append(labels_box)

          labels_box.tap do |labels|
            labels.append(lang_label)
            labels.append(title_label)
          end
        end
      end
    end

    def row_box
      @row_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 3
        box.margin_end = 3
      end
    end

    def labels_box = @labels_box ||= Gtk::Box.new(:vertical, 3)

    def flag_image
      @flag_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'noflag'
        image.pixel_size = 28
        image.valign = :center
        if Data.settings.get_boolean('show-flags')
          Data.flag_icon_name(@lang).then do |icon_name|
            if icon_name
              image.icon_name = icon_name
            end
          end
        else
          image.visible = false
        end
      end
    end

    def lang_label
      @lang_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.ellipsize = :end
        label.label = @lang_name.to_s
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.ellipsize = :end
        label.label = @title.to_s
        label.add_css_class('caption')
        label.add_css_class('dim-label')
      end
    end
  end
end
