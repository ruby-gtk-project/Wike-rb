# frozen_string_literal: true

require 'adwaita'
require_relative 'toc_box_row'

module Wike
  # Ported from upstream's TocPanel in src/toc.py and data/gtk/toc.ui.
  #
  # The table-of-contents page of the sidebar: the article's title above a
  # list of its sections, each indented by its depth. Activating a section
  # asks the host to jump to it.
  #
  # Upstream reaches the article view through `self._window.page.wikiview`;
  # the port takes the two things it actually does with it as callbacks:
  #
  #   on_section  — called with a section anchor to jump to it
  #   on_dismiss  — called after an activation, so a collapsed sidebar closes
  #
  class TocPanel < Adwaita::Bin
    def initialize(on_section:, on_dismiss:)
      super()
      @on_section = on_section
      @on_dismiss = on_dismiss
    end

    def build
      tap do |panel|
        panel.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(title_label)
          view.content = scroller

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = toc_list

              toc_list.tap do |list|
                list.set_placeholder(placeholder)
                list.signal_connect('row-activated') do |_list, row|
                  @on_dismiss.call
                  @on_section.call(row.anchor)
                end
              end
            end
          end
        end
      end
    end

    # Populate the toc list. A page with no sections clears the title too, so
    # the placeholder is all that shows.
    def populate(title, sections)
      toc_list.remove_all
      # GtkListBox#remove_all does not re-trigger the placeholder the way
      # removing rows one at a time does, so it is set again here to make
      # the empty state actually appear rather than leaving a blank list.
      toc_list.set_placeholder(placeholder)

      if sections && !sections.empty?
        title_label.label = title.to_s
        sections.each do |section|
          toc_list.append(
            TocBoxRow.new(section['line'], section['anchor'], section['toclevel'].to_i).build,
          )
        end
      else
        title_label.label = ''
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.margin_start = 15
        label.margin_end = 15
        label.height_request = 46
        label.xalign = 0
        label.width_chars = 30
        label.max_width_chars = 30
        label.ellipsize = :end
        label.add_css_class('heading')
      end
    end

    def scroller = @scroller ||= Gtk::ScrolledWindow.new

    def toc_list
      @toc_list ||= Gtk::ListBox.new.tap do |list|
        list.vexpand = true
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def placeholder
      @placeholder ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Contents'
        page.description = 'There is no table of contents for this page'
        page.icon_name = 'view-list-symbolic'
        page.margin_start = 50
        page.margin_end = 50
        page.add_css_class('compact')
      end
    end
  end
end
