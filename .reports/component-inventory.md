# Wike-rb component inventory

Survey of upstream `hugolabe/Wike` (Python/GTK4/Libadwaita, read from
`origin/master` — upstream has no `main` ref, `master` is its default branch)
against the Ruby port on `ruby`. No app code was written for this step.

## Method

- Upstream tree: `git ls-tree -r --name-only origin/master`.
- Each `src/*.py` file read in full; every `class`, `Gtk.Template`,
  `Gio.Settings` binding and `add_action`/`install_action` call noted.
- Each `lib/wike/*.rb` file checked for its `# Ported from upstream's ...`
  header and cross-referenced against the class/file it names.

## Widgets, dialogs, panels, rows, menus

| Upstream file | Upstream class | `lib/*.rb` path | Kind | Exists? |
|---|---|---|---|---|
| src/application.py | `Application` | lib/wike/application.rb | app/actions | yes |
| src/window.py + data/gtk/window.ui | `Window` | lib/wike/window.rb | window | yes |
| src/page.py + data/gtk/page.ui | `PageBox` | lib/wike/page_box.rb | page/tab content | yes |
| src/page.py + data/gtk/page-status.ui | `PageStatus` | lib/wike/page_status.rb | empty/error state | yes |
| src/view.py | `ViewSettings` | lib/wike/view_settings.rb | settings object | yes |
| src/view.py | `WikiView` (WebKit.WebView subclass) | lib/wike/wiki_view.rb | webview widget | yes |
| src/wikipedia.py | Wikipedia Action API client | lib/wike/wikipedia.rb | network client (now via `soup3`) | yes |
| src/data.py | `Languages`, `History`, `Bookmarks` + `settings` (`Gio.Settings`) | lib/wike/data.rb | data/settings singletons | yes |
| src/search.py + data/gtk/search.ui | `SearchPanel` | lib/wike/search_panel.rb | panel | yes |
| src/search.py + data/gtk/search-row.ui | `SearchRow` | lib/wike/search_row.rb | list row | yes |
| src/search.py + data/gtk/search-settings.ui | `SettingsPopover` | lib/wike/settings_popover.rb | popover | yes |
| src/search.py + data/gtk/search-settings-row.ui | `SettingsLangsRow` | lib/wike/settings_langs_row.rb | list row | yes |
| src/toc.py + data/gtk/toc.ui | `TocPanel` | lib/wike/toc_panel.rb | panel | yes |
| src/toc.py + data/gtk/toc-row.ui | `TocBoxRow` | lib/wike/toc_box_row.rb | list row | yes |
| src/langlinks.py + data/gtk/langlinks.ui | `LanglinksPanel` | lib/wike/langlinks_panel.rb | panel | yes |
| src/langlinks.py + data/gtk/langlinks-row.ui | `LanglinksRow` | lib/wike/langlinks_row.rb | list row | yes |
| src/langlinks.py | `LanguagesFilter` | lib/wike/languages_filter.rb | filter model | yes |
| src/languages.py + data/gtk/languages.ui | `LanguagesDialog` | lib/wike/languages_dialog.rb | dialog | yes |
| src/languages.py + data/gtk/languages-row.ui | `LanguagesRow` | lib/wike/languages_row.rb | list row | yes |
| src/bookmarks.py + data/gtk/bookmarks.ui | `BookmarksPanel` | lib/wike/bookmarks_panel.rb | panel | yes |
| src/bookmarks.py | `Booklist` | lib/wike/booklist.rb | list model object | yes |
| src/bookmarks.py + data/gtk/bookmarks-row.ui | `BookmarksRow` | lib/wike/bookmarks_row.rb | list row | yes |
| src/bookmarks.py + data/gtk/bookmarks-menu.ui | `BookmarksMenuPopover` | lib/wike/bookmarks_menu_popover.rb | menu popover | yes |
| src/history.py + data/gtk/history.ui | `HistoryPanel` | lib/wike/history_panel.rb | panel | yes |
| src/history.py | `HistoryFilter` | lib/wike/history_filter.rb | filter model | yes |
| src/history.py + data/gtk/history-row.ui | `HistoryRow` | lib/wike/history_row.rb | list row | yes |
| src/menu.py + data/gtk/menu-main.ui | `MainMenuPopover` | lib/wike/main_menu_popover.rb | menu popover | yes |
| src/menu.py + data/gtk/menu-article.ui | `ArticleMenuPopover` | lib/wike/article_menu_popover.rb | menu popover | yes |
| src/menu.py + data/gtk/menu-view.ui | `ViewMenuPopover` | lib/wike/view_menu_popover.rb | menu popover | yes |
| src/menu.py + data/gtk/theme-switcher.ui | `ThemeSwitcher` | lib/wike/theme_switcher.rb | toolbar widget | yes |
| src/menu.py + data/gtk/zoom-level.ui | `ZoomLevel` | lib/wike/zoom_level.rb | toolbar widget | yes |
| src/prefs.py + data/gtk/prefs.ui | `PrefsDialog` | lib/wike/prefs_dialog.rb | preferences dialog | yes |
| data/gtk/about.ui + `_about_cb` (window.py) | about window | lib/wike/about_dialog.rb | dialog | yes |
| data/gtk/dialogs.ui | confirmation/alert dialogs | lib/wike/dialogs.rb | dialogs | yes |
| data/gtk/shortcuts-dialog.ui | keyboard shortcuts window | lib/wike/shortcuts_dialog.rb | dialog | yes |
| data/gtk/style.css | base view stylesheet | lib/wike/style.rb | CSS provider | yes |
| data/gtk/style-sepia.css | sepia view stylesheet | lib/wike/sepia_style.rb | CSS provider | yes |
| src/wike-sp.in | standalone D-Bus search-provider service | lib/wike/shell_search_provider.rb | D-Bus service | yes |
| (no upstream equivalent file; port-only entry point) | — | lib/wike.rb, exe/wike, exe/wike-search-provider | entry points | yes |

Every upstream Python class/UI pair identified above already has a matching
`lib/wike/*.rb` file carrying a `# Ported from upstream's ...` header that
names it. No missing widget, dialog, row, panel, or menu was found in this
survey — the gaps are in the non-code assets described below, not in
`lib/`.

## Actions / keyboard shortcuts

- `src/application.py` registers 7 `Gio::SimpleAction`s on the app
  (`about`, `preferences`, `shortcuts`, `quit`, and the window/new-window
  family) — present in `lib/wike/application.rb`.
- `src/window.py` installs a further set of per-window actions (tab/page
  actions, `pin-panel`, panel navigation) around line 195-201 of
  `window.py` — present in `lib/wike/window.rb`.
- `src/bookmarks.py` and `src/menu.py` (`ViewMenuPopover`) each add an
  `actions_group`/`actions` set (select-all/select-none/remove, zoom
  in/out/reset) — present in `lib/wike/bookmarks_panel.rb` and
  `lib/wike/view_menu_popover.rb` respectively.
- The shortcuts window itself (`data/gtk/shortcuts-dialog.ui`) is ported to
  `lib/wike/shortcuts_dialog.rb`.

## GSettings / packaging assets — gaps

These are **not** `lib/*.rb` components but are required for the app's
settings and desktop integration to function, and upstream ships them as
real files that the Ruby port does not have an equivalent for:

| Upstream file | Purpose | Port equivalent | Exists? |
|---|---|---|---|
| `data/com.github.hugolabe.Wike.gschema.xml` | GSettings schema (every key `Gio::Settings` in `lib/wike/data.rb`, `window.rb`, `view_settings.rb`, `prefs_dialog.rb` binds to) | none found anywhere in the tree — only mentioned in a code comment | **no** |
| `data/com.github.hugolabe.Wike.desktop.in` | `.desktop` launcher entry | none found | **no** |
| `data/com.github.hugolabe.Wike.metainfo.xml.in` | AppStream metainfo (used by software centers, also the About dialog's version/description source upstream) | none found | **no** |
| `data/com.github.hugolabe.Wike.gresource.xml` | GResource manifest bundling the `.ui`/css/icon files | not applicable the same way (port builds widgets declaratively, no `.ui` files), but there is correspondingly no manifest of what must ship at runtime (icons, css) | **no** (by construction, not reviewed further here) |
| `data/com.github.hugolabe.Wike.service.in` | D-Bus service activation file for the main app | none found | **no** |
| `data/com.github.hugolabe.Wike.SearchProvider.service.in` | D-Bus service activation file for the search provider | `data/org.rubygtkproject.Wike.SearchProvider.service.in` exists (renamed app ID) | yes |
| `data/com.github.hugolabe.Wike.SearchProvider.ini` | Shell search-provider registration | `data/org.rubygtkproject.Wike.SearchProvider.ini` exists | yes |
| `data/languages/languages.json` (+ `.min.json`) | Wikipedia language list | `data/languages.json` exists | yes |
| `data/styles/view.css`, `data/styles/sepia.css` (+ `.min.css`) | in-article CSS injected into the WebView | `data/styles/view.css`, `data/styles/sepia.css` exist | yes |
| `data/icons/**` (app icon, symbolic icon, per-language flag emblems) | icon assets | not checked file-by-file in this pass — needs its own audit | unknown |

**`Gio::Settings.new("org.rubygtkproject.Wike")` (or whatever schema id
`lib/wike/data.rb` uses) cannot resolve without a compiled
`.gschema.xml` on the schema search path.** This is a functional gap, not
a cosmetic one: every settings-bound widget (`PrefsDialog`, `ThemeSwitcher`,
`ZoomLevel`, `BookmarksPanel`'s selection toggle, `HistoryPanel`'s filter
dropdown, `window.rb`'s panel-pinned/panel-page bindings) depends on it.

## po / translation catalogue

- `po/LINGUAS` lists 39 languages; `po/wike.pot` and per-language `.po`
  files are present (`ru.po`, `ka.po`, `ar.po`, `hr.po`, `ja.po`, `it.po`,
  `id.po`, `gl.po`, and others per `LINGUAS`).
- This pass did not do a msgid-by-msgid diff against upstream's catalogue —
  that is `translation-parity` work, not component identification, and is
  out of scope for this step.

## Binding-gem status (checked incidentally, per this task's mandatory step)

- `soup3` (provides `Soup`) is already wired in correctly: declared in the
  gemspec (`spec.add_dependency("soup3", "~> 1.0")`), declared in the
  runtime `nix/Gemfile`, present and in sync in `nix/gemset.nix`, used
  directly in `lib/wike/wikipedia.rb` (`Soup::Session`, `Soup::Message`,
  `Soup::Status`), and proven to load:
  `nix develop --command ruby -e 'require "soup3"; puts Soup.constants.size'`
  → `74`.
- No hand-rolled HTTP client (`Net::HTTP`, `open-uri`) was found anywhere
  under `lib/`; the gem is in use, not reimplemented.
- `gtk4`, `adwaita`, and `webkit-gtk` are also present in the gemspec,
  `nix/Gemfile`, and `nix/gemset.nix`.

## Bottom line

`lib/` already has a 1:1 (or finer-grained) file for every upstream
window, dialog, panel, row, and menu class identified in this survey —
component coverage in `lib/` looks complete. The real gaps found are
packaging/settings assets that no `lib/*.rb` file can substitute for:
missing `.gschema.xml`, `.desktop.in`, and `.metainfo.xml.in` equivalents,
and an icon-asset audit that this pass did not have time to do file-by-file.
