# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's BookmarksMenuPopover in src/bookmarks.py and
  # data/gtk/bookmarks-menu.ui.
  #
  # The bookmarks panel's overflow menu: create a list, rename the current
  # one, clear it. Upstream loads the menu model from the GtkBuilder file; the
  # port builds the same two sections with Gio::Menu, since that is all the
  # file held.
  #
  # The one piece of behaviour is in the `show` handler: the default reading
  # list cannot be renamed, so the rename action is disabled whenever it is
  # the selected list. The panel owns the action group; the popover is handed
  # it along with a predicate for "a renameable list is selected".
  class BookmarksMenuPopover < Gtk::PopoverMenu
    SECTIONS = [
      [['Create New List…', 'bookmarks.create-list']],
      [
        ['Rename List…', 'bookmarks.rename-list'],
        ['Clear List…', 'bookmarks.clear-list'],
      ],
    ].freeze

    # The menu model has to exist before the popover does, so it is built
    # here rather than in a memoized method.
    def self.menu_model
      Gio::Menu.new.tap do |menu|
        SECTIONS.each do |items|
          Gio::Menu.new.tap do |section|
            items.each { |label, action| section.append(label, action) }
            menu.append_section(nil, section)
          end
        end
      end
    end

    def initialize(actions:, renameable:)
      super(self.class.menu_model)
      @actions = actions
      @renameable = renameable
    end

    def build
      tap do |popover|
        popover.signal_connect('show') do
          @actions.lookup_action('rename-list').enabled = @renameable.call
        end
      end
    end
  end
end
