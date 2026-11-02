# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's data/gtk/shortcuts-dialog.ui.
  #
  # The keyboard shortcuts dialog: four sections of shortcuts, almost all of
  # which name a window or app action rather than an accelerator, so the
  # dialog shows whatever accelerator that action is currently bound to.
  #
  # Upstream builds this from the GtkBuilder file; here the same sections and
  # items are a table, because that is all the layout was.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    # [section title, [[item title, accelerator or action name, kind], ...]]
    SECTIONS = [
      [
        'General',
        [
          ['Main menu', 'F10', :accelerator],
          ['Sidebar', 'win.pin-panel', :action],
          ['Table of contents', 'win.show-toc', :action],
          ['Languages', 'win.show-langlinks', :action],
          ['Search text', 'win.search-text', :action],
          ['Print', 'win.print-page', :action],
          ['Copy link to clipboard', 'win.copy-link', :action],
          ['Preferences', 'app.prefs', :action],
          ['Keyboard shortcuts', 'app.shortcuts', :action],
          ['Quit', 'app.quit', :action],
        ],
      ],
      [
        'Bookmarks',
        [
          ['Bookmarks', 'win.show-bookmarks', :action],
          ['Add bookmark', 'win.add-bookmark', :action],
        ],
      ],
      [
        'Tabs',
        [
          ['New tab', 'win.new-tab', :action],
          ['Close current tab', 'win.close-tab', :action],
          ['Next tab', 'win.next-tab', :action],
          ['Previous tab', 'win.prev-tab', :action],
          ['View open tabs', 'win.toggle-overview', :action],
        ],
      ],
      [
        'Navigation',
        [
          ['Search articles', 'win.show-search', :action],
          ['Main page', 'win.main-page', :action],
          ['Random article', 'win.random-article', :action],
          ['Open Wikipedia link', 'win.open-link', :action],
          ['History of recent articles', 'win.show-history', :action],
          ['Previous page', 'win.prev-page', :action],
          ['Next page', 'win.next-page', :action],
          ['Reload current page', 'win.reload-page', :action],
        ],
      ],
    ].freeze

    def build
      tap do |dialog|
        sections.each { |section| dialog.add(section) }
      end
    end

    def sections
      @sections ||= SECTIONS.map do |title, items|
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = title
          items.each do |item_title, target, kind|
            section.add(shortcut_item(item_title, target, kind))
          end
        end
      end
    end

    private

      # Adwaita::ShortcutsItem has two constructors in C, one taking an
      # accelerator and one an action name. They have the same signature, so
      # the Ruby binding only exposes the accelerator one and rejects keyword
      # arguments; an action-name item is built with an empty accelerator and
      # then given its action, which is what the other constructor does.
      def shortcut_item(title, target, kind)
        if kind == :accelerator
          Adwaita::ShortcutsItem.new(title, target)
        else
          Adwaita::ShortcutsItem.new(title, '').tap { |item| item.action_name = target }
        end
      end
  end
end
