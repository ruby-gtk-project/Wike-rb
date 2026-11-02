# frozen_string_literal: true

require 'adwaita'

module Wike
  # Ported from upstream's data/gtk/dialogs.ui.
  #
  # Upstream keeps all six of its small dialogs in one GtkBuilder file and
  # pulls them out by id wherever one is needed; this is the same six in one
  # Ruby file. Five are Adw.AlertDialogs built from a heading, a body, a set
  # of responses and sometimes an extra child; the sixth, the open-link
  # dialog, is a full Adw.Dialog with its own header bar.
  #
  # Each dialog exposes the widgets its caller has to reach — the entry whose
  # text becomes a list name, the check button that says whether to delete the
  # list as well — the way upstream reaches them through builder ids.
  module Dialogs
    # The response ids upstream uses, so callers name them rather than
    # repeating string literals.
    CANCEL = 'cancel'
    CREATE = 'create'
    RENAME = 'rename'
    CLEAR = 'clear'

    # Shared shape for the dialogs that ask for a bookmarks list name: an
    # entry row inside a preferences group, a Cancel response and a suggested
    # confirm response that stays disabled until the name is usable.
    class BooklistNameDialog < Adwaita::AlertDialog
      attr_reader :confirm_response

      def initialize(heading, confirm_response, confirm_label)
        super()
        @heading_text = heading
        @confirm_response = confirm_response
        @confirm_label = confirm_label
      end

      def build
        tap do |dialog|
          dialog.heading = @heading_text
          dialog.default_response = @confirm_response
          dialog.close_response = CANCEL
          dialog.width_request = 340
          dialog.extra_child = entry_group
          dialog.add_response(CANCEL, 'Cancel')
          dialog.add_response(@confirm_response, @confirm_label)
          dialog.set_response_appearance(@confirm_response, Adwaita::ResponseAppearance::SUGGESTED)
          dialog.set_response_enabled(@confirm_response, false)

          entry_group.tap do |group|
            group.add(name_entry)
          end
        end
      end

      # Upstream enables the confirm response only for a name that is neither
      # empty nor already taken, and marks the entry with the `error` class
      # for a name that collides.
      def valid_name=(state)
        case state
        when :empty
          set_response_enabled(@confirm_response, false)
          name_entry.remove_css_class('error')
        when :taken
          set_response_enabled(@confirm_response, false)
          name_entry.add_css_class('error')
        else
          set_response_enabled(@confirm_response, true)
          name_entry.remove_css_class('error')
        end
      end

      def entry_group = @entry_group ||= Adwaita::PreferencesGroup.new

      def name_entry
        @name_entry ||= Adwaita::EntryRow.new.tap do |row|
          row.title = 'List Name'
          row.activates_default = true
        end
      end
    end

    # New bookmarks list dialog.
    class NewBooklistDialog < BooklistNameDialog
      def initialize
        super('New Bookmarks List', CREATE, 'Create List')
      end
    end

    # Rename bookmarks list dialog.
    class RenameBooklistDialog < BooklistNameDialog
      def initialize
        super('Rename Bookmarks List', RENAME, 'Rename List')
      end
    end

    # Shared shape for the three dialogs that confirm a destructive clear.
    class ConfirmClearDialog < Adwaita::AlertDialog
      def initialize(heading, body, confirm_label)
        super()
        @heading_text = heading
        @body_text = body
        @confirm_label = confirm_label
      end

      def build
        tap do |dialog|
          dialog.heading = @heading_text
          dialog.body = @body_text
          dialog.default_response = CLEAR
          dialog.close_response = CANCEL
          dialog.add_response(CANCEL, 'Cancel')
          dialog.add_response(CLEAR, @confirm_label)
          dialog.set_response_appearance(CLEAR, Adwaita::ResponseAppearance::DESTRUCTIVE)
        end
      end
    end

    # Clear bookmarks list dialog. The extra check button offers to delete the
    # list itself rather than just empty it; upstream makes it insensitive for
    # the default reading list, which cannot be deleted.
    class ClearBooklistDialog < ConfirmClearDialog
      def initialize(deletable: true)
        super(
          'Clear Bookmarks List?',
              'All bookmarks in the list will be removed permanently.',
              'Clear List')
        @deletable = deletable
      end

      def build
        super.tap do |dialog|
          dialog.extra_child = delete_booklist_check
        end
      end

      def delete_booklist_check
        @delete_booklist_check ||= Gtk::CheckButton.new.tap do |check|
          check.label = 'Also delete the list'
          check.sensitive = @deletable
        end
      end
    end

    # Clear history dialog.
    class ClearHistoryDialog < ConfirmClearDialog
      def initialize
        super(
          'Clear History?',
              'The history of visited articles will be deleted permanently.',
              'Clear History')
      end
    end

    # Clear personal data dialog.
    class ClearDataDialog < ConfirmClearDialog
      def initialize
        super(
          'Clear Personal Data?',
              'Cookies and cache data will be deleted permanently.',
              'Clear Data')
      end
    end

    # Open Wikipedia link dialog: an entry row with an apply button, and a
    # dimmed monospace hint showing the URL shape that is accepted.
    class OpenLinkDialog < Adwaita::Dialog
      def build
        tap do |dialog|
          dialog.title = 'Open Wikipedia Link'
          dialog.child = toolbar_view

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = content_box

            content_box.tap do |box|
              box.append(entry_group)
              box.append(hint_label)

              entry_group.tap do |group|
                group.add(link_entry)
              end
            end
          end
        end
      end

      # Upstream clears and re-sets the apply button to make it drop back out
      # of its applied state, then marks the entry as being in error.
      def reject_link
        link_entry.tap do |entry|
          entry.show_apply_button = false
          entry.show_apply_button = true
          entry.add_css_class('error')
        end
      end

      # Called as the text changes: an emptied entry gets its apply button
      # reset, and any previous error mark is cleared.
      def clear_error
        link_entry.tap do |entry|
          if entry.text.empty?
            entry.show_apply_button = false
            entry.show_apply_button = true
          end
          if entry.has_css_class?('error')
            entry.remove_css_class('error')
          end
        end
      end

      def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
      def header_bar = @header_bar ||= Adwaita::HeaderBar.new
      def entry_group = @entry_group ||= Adwaita::PreferencesGroup.new

      def content_box
        @content_box ||= Gtk::Box.new(:vertical, 16).tap do |box|
          box.margin_top = 8
          box.margin_bottom = 24
          box.margin_start = 24
          box.margin_end = 24
        end
      end

      def link_entry
        @link_entry ||= Adwaita::EntryRow.new.tap do |row|
          row.title = 'Wikipedia Link'
          row.show_apply_button = true
        end
      end

      def hint_label
        @hint_label ||= Gtk::Label.new.tap do |label|
          label.label = 'https://<i>lang</i>.wikipedia.org/wiki/<i>Article</i>'
          label.margin_start = 24
          label.margin_end = 24
          label.use_markup = true
          label.ellipsize = :end
          label.add_css_class('monospace')
          label.add_css_class('dimmed')
        end
      end
    end
  end
end
