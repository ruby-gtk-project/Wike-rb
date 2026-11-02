# frozen_string_literal: true

require 'adwaita'
require_relative 'rb/version'

module Wike
  # Ported from upstream's data/gtk/about.ui and the _about_cb in
  # src/application.py.
  #
  # Upstream splits the about dialog in two: the properties live in the
  # GtkBuilder file and the links, developers and credit sections are added in
  # code, because AdwAboutDialog's add_link / add_credit_section /
  # add_legal_section have no XML form. Both halves are here.
  #
  # The version is the port's own — this is the Ruby port, not upstream 3.2.1 —
  # and the legal sections are kept verbatim: the Wikipedia content notice and
  # the flag icons' MIT notice are obligations, not decoration.
  class AboutDialog < Adwaita::AboutDialog
    WEBSITE = 'https://hugolabe.github.io/Wike/'
    SOURCE_CODE = 'https://github.com/ruby-gtk-project/Wike-rb'
    ISSUES = 'https://github.com/ruby-gtk-project/Wike-rb/issues'
    TRANSLATIONS = 'https://poeditor.com/join/project?hash=kNgJu4MAum'
    CONTRIBUTORS = 'https://github.com/hugolabe/Wike/graphs/contributors'

    WIKIPEDIA_NOTICE = <<~TEXT.chomp
      All content from Wikipedia.org and available under CC BY-SA 4.0 unless otherwise noted.

      Wike is an independent development not endorsed by or affiliated with the Wikimedia Foundation.
    TEXT

    def build
      tap do |dialog|
        dialog.application_icon = 'com.github.hugolabe.Wike'
        dialog.application_name = 'Wike'
        dialog.developer_name = 'Hugo Olabera'
        dialog.version = Wike::Rb::Version::VERSION
        dialog.comments = 'Search and read Wikipedia articles'
        dialog.website = WEBSITE
        dialog.translator_credits = 'translator-credits'
        dialog.copyright = 'Copyright © 2021-25 Hugo Olabera'
        dialog.license_type = Gtk::License::GPL_3_0

        dialog.add_link('Source Code', SOURCE_CODE)
        dialog.add_link('Report an Issue', ISSUES)
        dialog.add_link('Help Translating', TRANSLATIONS)
        dialog.developers = ['Hugo Olabera <hugolabe@proton.me>', "Contributors #{CONTRIBUTORS}"]
        dialog.add_credit_section('Flag Icons', ['HatScripts https://github.com/HatScripts/'])
        dialog.add_legal_section(
          'Wikipedia',
          WIKIPEDIA_NOTICE,
          Gtk::License::UNKNOWN,
          nil,
        )
        dialog.add_legal_section(
          'Circle Flags',
          'Copyright © 2022 HatScripts',
          Gtk::License::MIT_X11,
          nil,
        )
      end
    end
  end
end
