# frozen_string_literal: true

require 'adwaita'
require_relative 'booklist'
require_relative 'bookmarks_menu_popover'
require_relative 'bookmarks_row'
require_relative 'data'
require_relative 'dialogs'

module Wike
  # Ported from upstream's BookmarksPanel in src/bookmarks.py and
  # data/gtk/bookmarks.ui.
  #
  # The bookmarks page of the sidebar: a dropdown of bookmark lists, the
  # bookmarks of the selected one sorted by title then language, an add
  # button driven by the window's add-bookmark action, a selection mode for
  # removing several at once, and an overflow menu for creating, renaming and
  # clearing lists.
  #
  # Position 0 of the dropdown is always the default reading list, which has
  # no entry in the bookmarks store — it is represented by a nil list name,
  # cannot be renamed, and cannot be deleted. The other positions are the
  # user's own lists, sorted alphabetically after it.
  #
  # Upstream reaches the article view and the window's action through
  # `self._window`; the port takes what it does with them as callbacks:
  #
  #   on_load_uri    — called with the article URI to load
  #   on_dismiss     — called after an activation, so a collapsed sidebar closes
  #   current_article — returns the current article's URI, or nil if there is none
  #   on_can_add     — called with whether the current article can be bookmarked
  #
  class BookmarksPanel < Adwaita::Bin
    DEFAULT_BOOKLIST = 'Reading list'

    def initialize(on_load_uri:, on_dismiss:, current_article:, on_can_add:)
      super()
      @on_load_uri = on_load_uri
      @on_dismiss = on_dismiss
      @current_article = current_article
      @on_can_add = on_can_add
      @booklist = nil
      @booklists = [Booklist.new(DEFAULT_BOOKLIST)]
    end

    def build
      tap do |panel|
        panel.child = toolbar_view
        panel.insert_action_group('bookmarks', actions)

        toolbar_view.tap do |view|
          view.add_top_bar(header_box)
          view.add_bottom_bar(action_bar)
          view.content = scroller

          header_box.tap do |box|
            box.append(booklists_dropdown)
            box.append(add_button)
            box.append(selection_button)
            box.append(menu_button)

            menu_button.tap do |button|
              button.popover = menu_popover
            end
          end

          action_bar.tap do |bar|
            bar.pack_start(select_all_button)
            bar.pack_start(select_none_button)
            bar.pack_end(remove_button)
            selection_button.bind_property(
              'active',
              bar,
              'revealed',
              :sync_create,
            )
          end

          scroller.tap do |scrolled|
            scrolled.child = viewport

            viewport.tap do |port|
              port.child = bookmarks_list

              bookmarks_list.tap do |list|
                list.set_placeholder(placeholder)
                list.set_sort_func { |row1, row2| compare_rows(row1, row2) }
                list.signal_connect('row-activated') { |_list, row| activate(row) }
              end
            end
          end
        end

        booklists_dropdown.signal_connect('notify::selected') { select_booklist }
        select_all_button.signal_connect('clicked') { mark_all(true) }
        select_none_button.signal_connect('clicked') { mark_all(false) }
        remove_button.signal_connect('clicked') { remove_marked }

        menu_popover.build
        refresh_booklists
        populate
      end
    end

    # Add a bookmark to the current list. Returns whether it was added, which
    # is false for an article the list already holds, so the caller knows
    # whether to show the "Bookmark added" notification.
    def add_bookmark(uri, title, lang)
      Data.bookmarks.add(
        uri,
        title,
        lang,
        @booklist,
      ).tap do |added|
        if added
          selection_button.active = false
          append_row(uri, title, lang)
          Data.bookmarks.save
          refresh_buttons
        end
      end
    end

    # Remove a bookmark from the current list by URI.
    def remove_bookmark(uri)
      Data.bookmarks.remove(uri, @booklist).tap do |removed|
        if removed
          rows.find { |row| row.uri == uri }.then do |row|
            if row
              bookmarks_list.remove(row)
            end
          end
          Data.bookmarks.save
          refresh_buttons
        end
      end
    end

    # Tell the host whether the current article can be bookmarked: not if
    # there is no article, and not if the current list already holds it.
    def refresh_buttons
      @current_article.call.then do |uri|
        @on_can_add.call(!uri.nil? && !bucket.key?(uri))
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def viewport = @viewport ||= Gtk::Viewport.new(nil, nil)
    def action_bar = @action_bar ||= Gtk::ActionBar.new
    def booklists_model = @booklists_model ||= Gtk::StringList.new([])

    def header_box
      @header_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.add_css_class('toolbar')
      end
    end

    def booklists_dropdown
      @booklists_dropdown ||= Gtk::DropDown.new.tap do |dropdown|
        dropdown.hexpand = true
        dropdown.model = booklists_model
        dropdown.factory = booklists_factory
      end
    end

    def booklists_factory
      @booklists_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
        factory.signal_connect('setup') do |_factory, list_item|
          list_item.child = Gtk::Label.new.tap do |label|
            label.xalign = 0
            label.ellipsize = :end
          end
        end
        factory.signal_connect('bind') do |_factory, list_item|
          list_item.child.label = list_item.item.string
        end
      end
    end

    def add_button
      @add_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'bookmark-new-symbolic'
        button.tooltip_text = 'Add Bookmark'
        button.action_name = 'win.add-bookmark'
      end
    end

    def selection_button
      @selection_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'selection-mode-symbolic'
        button.tooltip_text = 'Select'
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = 'view-more-symbolic'
      end
    end

    def menu_popover
      @menu_popover ||= BookmarksMenuPopover.new(
        actions:    actions,
        renameable: -> { booklists_dropdown.selected.positive? },
      )
    end

    def select_all_button
      @select_all_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'edit-select-all-symbolic'
        button.tooltip_text = 'Select All'
      end
    end

    def select_none_button
      @select_none_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'edit-select-none-symbolic'
        button.tooltip_text = 'Select None'
      end
    end

    def remove_button
      @remove_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'app-remove-symbolic'
        button.tooltip_text = 'Remove Selected'
        button.add_css_class('destructive-action')
      end
    end

    def bookmarks_list
      @bookmarks_list ||= Gtk::ListBox.new.tap do |list|
        list.vexpand = true
        list.selection_mode = :none
        list.add_css_class('navigation-sidebar')
      end
    end

    def placeholder
      @placeholder ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Bookmarks'
        page.description = 'Use the Add Bookmark button or press Ctrl+D to add the ' \
                           'current article to the list'
        page.icon_name = 'user-bookmarks-symbolic'
        page.margin_start = 50
        page.margin_end = 50
        page.add_css_class('compact')
      end
    end

    # The panel's own action group, which the overflow menu's items target.
    def actions
      @actions ||= Gio::SimpleActionGroup.new.tap do |group|
        {
          'create-list' => -> { create_booklist },
          'rename-list' => -> { rename_booklist },
          'clear-list'  => -> { clear_booklist },
        }.each do |name, callback|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { callback.call }
            group.add_action(action)
          end
        end
      end
    end

    private

      # The bookmarks of the selected list: the default reading list for a nil
      # list name, one of the named lists otherwise.
      def bucket
        if @booklist
          Data.bookmarks.lists.fetch(@booklist, {})
        else
          Data.bookmarks.items
        end
      end

      def populate
        clear_list
        bucket.then do |items|
          items.each { |uri, (title, lang)| append_row(uri, title, lang) }
        end
      end

      def append_row(uri, title, lang)
        BookmarksRow.new(uri, title, lang).build.tap do |row|
          bookmarks_list.append(row)
          selection_button.bind_property(
            'active',
            row.select_check,
            'visible',
            :sync_create,
          )
        end
      end

      def clear_list
        selection_button.active = false
        bookmarks_list.remove_all
        # GtkListBox#remove_all does not re-trigger the placeholder the way
        # removing rows one at a time does, so it is set again here to make
        # the empty state actually appear rather than leaving a blank list.
        bookmarks_list.set_placeholder(placeholder)
      end

      # Title first, language as the tie-breaker, as upstream's sort does.
      def compare_rows(row1, row2)
        (row1.title.to_s <=> row2.title.to_s).then do |by_title|
          if by_title.zero?
            row1.lang.to_s <=> row2.lang.to_s
          else
            by_title
          end
        end
      end

      def rows
        [].tap do |collected|
          index = 0
          while (row = bookmarks_list.get_row_at_index(index))
            collected << row
            index += 1
          end
        end
      end

      def mark_all(state) = rows.each { |row| row.select_check.active = state }

      def remove_marked
        rows.select { |row| row.select_check.active? }.each do |row|
          if Data.bookmarks.remove(row.uri, @booklist)
            bookmarks_list.remove(row)
          end
        end
        Data.bookmarks.save
        refresh_buttons
      end

      # The default reading list first, then the user's lists alphabetically.
      def refresh_booklists
        @booklists = [Booklist.new(DEFAULT_BOOKLIST)] +
                     Data.bookmarks.lists.keys.sort.map { |name| Booklist.new(name) }
        reload_booklists_model
      end

      # Gtk::StringList has no "replace everything" call, so the model is
      # spliced in one step, which leaves the dropdown's selection intact.
      def reload_booklists_model
        booklists_model.splice(0, booklists_model.n_items, @booklists.map(&:name))
      end

      def select_booklist
        booklists_dropdown.selected.then do |position|
          if position.zero?
            @booklist = nil
          else
            @booklist = @booklists[position]&.name
          end
        end

        populate
        refresh_buttons
      end

      # Selecting a position rather than letting the dropdown keep the old one
      # is what makes a newly created or renamed list the one on show.
      def select_position(position)
        booklists_dropdown.selected = position
        select_booklist
      end

      def create_booklist
        Dialogs::NewBooklistDialog.new.build.tap do |dialog|
          dialog.name_entry.signal_connect('changed') do |entry|
            dialog.valid_name = name_state(entry.text, nil)
          end
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::CREATE
              add_booklist(dialog.name_entry.text)
            end
          end
          dialog.present(root)
        end
      end

      def add_booklist(list_name)
        if Data.bookmarks.new_list(list_name)
          Data.bookmarks.save
          refresh_booklists
          select_position(@booklists.index { |booklist| booklist.name == list_name } || 0)
        end
      end

      def rename_booklist
        Dialogs::RenameBooklistDialog.new.build.tap do |dialog|
          dialog.name_entry.text = @booklist.to_s
          dialog.name_entry.signal_connect('changed') do |entry|
            dialog.valid_name = name_state(entry.text, @booklist)
          end
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::RENAME
              apply_rename(dialog.name_entry.text)
            end
          end
          dialog.present(root)
        end
      end

      def apply_rename(new_name)
        if Data.bookmarks.rename_list(@booklist, new_name)
          Data.bookmarks.save
          refresh_booklists
          select_position(@booklists.index { |booklist| booklist.name == new_name } || 0)
        end
      end

      # Upstream's entry validation: empty is simply not ready, the current
      # name is not ready either, and a name that collides with the default
      # list or an existing one is marked as an error.
      def name_state(text, current)
        if text.empty?
          :empty
        elsif !current.nil? && text == current
          :empty
        elsif text == DEFAULT_BOOKLIST || Data.bookmarks.lists.key?(text)
          :taken
        else
          :ok
        end
      end

      def clear_booklist
        Dialogs::ClearBooklistDialog.new(deletable: booklists_dropdown.selected.positive?)
                                   .build.tap do |dialog|
          dialog.signal_connect('response') do |_dialog, response|
            if response == Dialogs::CLEAR
              apply_clear(dialog.delete_booklist_check.active?)
            end
          end
          dialog.present(root)
        end
      end

      def apply_clear(delete_list)
        if delete_list && Data.bookmarks.remove_list(@booklist)
          refresh_booklists
          select_position(0)
        else
          Data.bookmarks.clear_list(@booklist)
          clear_list
          refresh_buttons
        end
        Data.bookmarks.save
      end

      def activate(row)
        if selection_button.active?
          row.select_check.active = !row.select_check.active?
        else
          @on_dismiss.call
          @on_load_uri.call(row.uri)
        end
      end
  end
end
