{
  description = "Wike — a Ruby GTK4 port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          # WebKitGTK 6.0 — the webkit-gtk gem's typelib and shared library.
          webkitgtk_6_0
          # libsoup 3 — the soup3 gem's typelib, used by the Wikipedia client.
          libsoup_3
          harfbuzz
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        # Un-prefixed names: the `xorg.*` package set is deprecated.
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = _attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          webkit-gtk = rubyGnomeGem;
          rsvg2 = rubyGnomeGem;
          soup3 = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        # libsoup (the soup3 gem's transport) has no TLS backend of its own —
        # without this GIO module on GIO_EXTRA_MODULES every HTTPS request
        # fails with "TLS support is not available".
        gioModulePath = "${pkgs.glib-networking}/lib/gio/modules";

        # nix/ and not the repo root: the root Gemfile is kettle-jem's
        # development bundle — rubocop, rspec, yard, the kettle-dev stack — and
        # must not end up in a packaged app's runtime closure. nix/Gemfile holds
        # the gemspec's runtime dependencies only.
        gems = pkgs.bundlerEnv {
          name = "Wike-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
        };

        # Every executable the gemspec installs into exe/ — the app itself
        # and, now, the standalone shell search provider service. Reading
        # the directory keeps this flake generic: no name to keep in step by
        # hand. `mainProgram` still has to name one, and "wike" is always the
        # app a person runs by hand.
        launchers = builtins.attrNames (builtins.readDir ./exe);
        mainLauncher = "wike";

        # Optional directories: a port that has not grown translations or data
        # assets yet simply has none.
        optionalDirs = builtins.filter (d: builtins.pathExists (./. + "/${d}")) [
          "data"
          "po"
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "Wike";
          version = "0.1.0";
          src = ./.;

          # Deliberately no wrapGAppsHook4: glib's setup hook relocates
          # share/glib-2.0/schemas during fixup, after wrapGAppsHook4 has
          # computed its wrapper arguments, so a schema would end up somewhere
          # the wrapper never looks. The wrapper below is built by hand and
          # points at both the pre- and post-move paths.
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ gems pkgs.glib-networking ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/Wike
            cp -r lib $out/share/Wike/
            for d in ${pkgs.lib.escapeShellArgs optionalDirs}; do
              cp -r "$d" $out/share/Wike/
            done

            # Compile any GSettings schema the port ships.
            if [ -d data/schemas ]; then
              mkdir -p $out/share/glib-2.0/schemas
              cp data/schemas/*.gschema.xml $out/share/glib-2.0/schemas/
              ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas
            fi

            # The shell search provider's D-Bus activation and registration
            # files — upstream's data/com.github.hugolabe.Wike.SearchProvider.ini
            # and .service.in, carried over under this port's own app id. The
            # .ini is what tells GNOME Shell this bus name answers
            # SearchProvider2 at all; the .service is what lets the bus
            # start wike-search-provider itself the first time the shell
            # asks for it, rather than requiring it already be running.
            # @bindir@ is the one substitution meson's configure_file does
            # for the .service.in that still applies once installed here.
            if [ -f data/org.rubygtkproject.Wike.SearchProvider.ini ]; then
              mkdir -p $out/share/gnome-shell/search-providers \
                $out/share/dbus-1/services

              install -Dm644 data/org.rubygtkproject.Wike.SearchProvider.ini \
                $out/share/gnome-shell/search-providers/org.rubygtkproject.Wike.SearchProvider.ini

              sed "s|@bindir@|$out/bin|g" \
                data/org.rubygtkproject.Wike.SearchProvider.service.in \
                > $out/share/dbus-1/services/org.rubygtkproject.Wike.SearchProvider.service
            fi

            ${pkgs.lib.concatMapStringsSep "\n" (launcher: ''
              # exe/ sits next to lib/ so ${launcher}'s `require "wike/..."`
              # resolves against the copied tree.
              install -Dm755 exe/${launcher} $out/share/Wike/exe/${launcher}

              # -rbundler/setup puts the bundled gems on the load path, and
              # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
              # types the cairo gem's C extension has already registered.
              makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/${launcher} \
                --add-flags "-rbundler/setup" \
                --add-flags "-I$out/share/Wike/lib" \
                --add-flags "$out/share/Wike/exe/${launcher}" \
                --set GI_TYPELIB_PATH "${typelibPath}" \
                --set GIO_EXTRA_MODULES "${gioModulePath}" \
                --prefix XDG_DATA_DIRS : "$out/share" \
                --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/Wike-0.1.0" \
                --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"
            '') launchers}

            runHook postInstall
          '';

          meta = {
            description = "A Ruby GTK4 / Libadwaita port of Wike";
            mainProgram = mainLauncher;
            platforms = pkgs.lib.platforms.linux;
          };
        };

        apps.default = utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "Wike-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.gettext
            # rxgettext, the extractor `rake pot` drives. GNU xgettext claims
            # to support Ruby but only shells out to this, so without it
            # `xgettext --language=Ruby` fails.
            pkgs.rubyPackages_3_4.gettext
            # The spec runner. The suite is plain RSpec, so this is enough.
            pkgs.rubyPackages_3_4.rspec
            # This machine may have no display server at all, so the shell
            # carries one it can start itself: `xvfb-run ruby exe/<app>` both
            # launches the app and is how test/drive_*.rb is run.
            pkgs.xvfb-run
            pkgs.gsettings-desktop-schemas
            pkgs.adwaita-icon-theme
            pkgs.glib-networking
            # test/drive_main_window.rb fires one accelerator (Ctrl+T) as a
            # real X key event rather than an action activation: GTK4 has no
            # public way to forge a Gdk key event, so the keystroke has to
            # come from the X server, and xdotool is what puts it there.
            pkgs.xdotool
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export GIO_EXTRA_MODULES="${gioModulePath}''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            [ -d data/schemas ] && export GSETTINGS_SCHEMA_DIR="$PWD/data/schemas"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN
            echo "Wike devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:   xvfb-run ruby exe/wike"
            echo "drive the app: xvfb-run ruby test/drive_*.rb"
            echo "run the specs: ruby -e 'require \"rspec/core\"; exit RSpec::Core::Runner.run([\"--format\", \"progress\", \"--require\", \"spec_helper\", \"spec\"])'"
          '';
        };
      });
}
