# frozen_string_literal: true

require 'adwaita'
require_relative 'data'

module Wike
  # Ported from upstream's SettingsLangsRow in src/search.py and
  # data/gtk/search-settings-row.ui.
  #
  # One of the user's languages in the search settings popover: flag, name, a
  # checkmark on the language searches currently go to, and the language code.
  class SettingsLangsRow < Gtk::ListBoxRow
    attr_reader :lang_name, :lang_id

    def initialize(lang_name, lang_id, check_mark)
      super()
      @lang_name = lang_name
      @lang_id = lang_id
      @check_mark = check_mark
    end

    def build
      tap do |row|
        row.child = row_box

        row_box.tap do |box|
          box.append(flag_image)
          box.append(name_label)
          box.append(check_image)
          box.append(id_label)
        end
      end
    end

    def row_box = @row_box ||= Gtk::Box.new(:horizontal, 0)

    def flag_image
      @flag_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'noflag'
        image.pixel_size = 16
        image.valign = :center
        if Data.settings.get_boolean('show-flags')
          Data.flag_icon_name(@lang_id).then do |icon_name|
            if icon_name
              image.icon_name = icon_name
            end
          end
        else
          image.visible = false
        end
      end
    end

    def name_label
      @name_label ||= Gtk::Label.new.tap do |label|
        label.halign = :start
        label.label = @lang_name.to_s
      end
    end

    # Upstream leaves the image empty for every language but the current one,
    # which is what makes the checkmark column read as a single mark.
    def check_image
      @check_image ||= Gtk::Image.new.tap do |image|
        image.hexpand = true
        image.halign = :start
        if @check_mark
          image.icon_name = 'checkmark-symbolic'
        end
      end
    end

    def id_label
      @id_label ||= Gtk::Label.new.tap do |label|
        label.halign = :end
        label.label = @lang_id.to_s
        label.add_css_class('dim-label')
      end
    end
  end
end
