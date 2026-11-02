# Wike — upstream component inventory

Upstream ref: `origin/master` (Wike 3.2.1, PyGObject + GTK4 + Libadwaita +
WebKitGTK 6 + libsoup 3). Port branch: `ruby`.

Upstream is a **GtkBuilder app**: 24 `.ui` files carry the widget trees, CSS
classes and property bindings; 13 `.py` files carry the callbacks and the
runtime-built widgets. Every component is therefore a *pair* of files, and the
inventory unions both halves before stating a gap.

Totals: **36 components** across 13 Python modules, 24 `.ui` files, 1 GSettings
schema (23 keys), 1 GResource manifest, 2 app stylesheets, 2 webview
stylesheets, 128 icons (17 action + 111 emblem), 39 translations / 157 msgids.

Current `lib/` on `ruby`: **31 of 36 components exist**, in 33 files totalling
~4,900 lines. The data layer, the Wikipedia client, all four sidebar panels and
their rows, every menu and popover, all dialogs, the preferences and the two
stylesheets are ported. All non-code assets — the icon theme, the webview
stylesheets, `languages.json` and all 39 `po/` catalogues — are in the tree.

**The five that remain are one cluster: the article view.** The Ruby GNOME
stack ships no WebKitGTK 6 binding, so `WikiView`, `ViewSettings`, `PageBox`
and the tab view have no port yet, and `lib/wike/application.rb` stands in for
them by opening an article through `Gtk::UriLauncher`. The sidebar still drives
off the live Wikipedia API for the open article, so the gap is the embedded
view and the tab strip around it, not the article behaviour. `window.rb` is the
fifth: upstream's window is currently inlined into `application.rb` (split
view, header bar, panel selector, panel stack) and wants splitting out when the
tab view lands and the file has a second owner.

Naming follows the port's existing namespace: `lib/wike/<thing>.rb`.

---

## Map

`Exists` is read against `lib/` on `ruby` at this commit.

| # | Upstream file(s) | `lib/*.rb` | Kind | Exists |
|--:|---|---|---|---|
| 1 | `src/application.py` | `lib/wike/application.rb` | application | yes |
| 2 | `src/window.py` + `data/gtk/window.ui` | `lib/wike/window.rb` | window | partial — inlined in `application.rb`; no tab view, no `AdwTabBar`, no breakpoint popover re-parenting |
| 3 | `src/page.py` (`PageBox`) + `data/gtk/page.ui` | `lib/wike/page_box.rb` | page | no — blocked on WebKit |
| 4 | `src/page.py` (`PageStatus`) + `data/gtk/page-status.ui` | `lib/wike/page_status.rb` | empty/error state | yes |
| 5 | `src/view.py` (`WikiView`) | `lib/wike/wiki_view.rb` | widget (WebView) | no — blocked on WebKit |
| 6 | `src/view.py` (`ViewSettings`) | `lib/wike/view_settings.rb` | support | no — blocked on WebKit |
| 7 | `src/search.py` (`SearchPanel`) + `data/gtk/search.ui` | `lib/wike/search_panel.rb` | sidebar page | yes |
| 8 | `src/search.py` (`SearchRow`) + `data/gtk/search-row.ui` | `lib/wike/search_row.rb` | row | yes |
| 9 | `src/search.py` (`SettingsPopover`) + `data/gtk/search-settings.ui` | `lib/wike/settings_popover.rb` | popover | yes |
| 10 | `src/search.py` (`SettingsLangsRow`) + `data/gtk/search-settings-row.ui` | `lib/wike/settings_langs_row.rb` | row | yes |
| 11 | `src/toc.py` (`TocPanel`) + `data/gtk/toc.ui` | `lib/wike/toc_panel.rb` | sidebar page | yes |
| 12 | `src/toc.py` (`TocBoxRow`) + `data/gtk/toc-row.ui` | `lib/wike/toc_box_row.rb` | row | yes |
| 13 | `src/langlinks.py` (`LanglinksPanel`) + `data/gtk/langlinks.ui` | `lib/wike/langlinks_panel.rb` | sidebar page | yes |
| 14 | `src/langlinks.py` (`LanglinksRow`) + `data/gtk/langlinks-row.ui` | `lib/wike/langlinks_row.rb` | row | yes |
| 15 | `src/langlinks.py` (`LanguagesFilter`) | `lib/wike/languages_filter.rb` | model object | yes |
| 16 | `src/bookmarks.py` (`BookmarksPanel`) + `data/gtk/bookmarks.ui` | `lib/wike/bookmarks_panel.rb` | sidebar page | yes |
| 17 | `src/bookmarks.py` (`BookmarksRow`) + `data/gtk/bookmarks-row.ui` | `lib/wike/bookmarks_row.rb` | row | yes |
| 18 | `src/bookmarks.py` (`BookmarksMenuPopover`) + `data/gtk/bookmarks-menu.ui` | `lib/wike/bookmarks_menu_popover.rb` | menu | yes |
| 19 | `src/bookmarks.py` (`Booklist`) | `lib/wike/booklist.rb` | model object | yes |
| 20 | `src/history.py` (`HistoryPanel`) + `data/gtk/history.ui` | `lib/wike/history_panel.rb` | sidebar page | yes |
| 21 | `src/history.py` (`HistoryRow`) + `data/gtk/history-row.ui` | `lib/wike/history_row.rb` | row | yes |
| 22 | `src/history.py` (`HistoryFilter`) | `lib/wike/history_filter.rb` | model object | yes |
| 23 | `src/languages.py` (`LanguagesDialog`) + `data/gtk/languages.ui` | `lib/wike/languages_dialog.rb` | dialog | yes |
| 24 | `src/languages.py` (`LanguagesRow`) + `data/gtk/languages-row.ui` | `lib/wike/languages_row.rb` | row | yes |
| 25 | `src/prefs.py` + `data/gtk/prefs.ui` | `lib/wike/prefs_dialog.rb` | preferences | yes |
| 26 | `src/menu.py` (`MainMenuPopover`) + `data/gtk/menu-main.ui` | `lib/wike/main_menu_popover.rb` | menu | yes |
| 27 | `src/menu.py` (`ArticleMenuPopover`) + `data/gtk/menu-article.ui` | `lib/wike/article_menu_popover.rb` | menu | yes |
| 28 | `src/menu.py` (`ViewMenuPopover`) + `data/gtk/menu-view.ui` | `lib/wike/view_menu_popover.rb` | menu | yes |
| 29 | `src/menu.py` (`ThemeSwitcher`) + `data/gtk/theme-switcher.ui` | `lib/wike/theme_switcher.rb` | widget | yes |
| 30 | `src/menu.py` (`ZoomLevel`) + `data/gtk/zoom-level.ui` | `lib/wike/zoom_level.rb` | widget | yes |
| 31 | `data/gtk/dialogs.ui` (6 dialogs) | `lib/wike/dialogs.rb` | dialogs | yes |
| 32 | `data/gtk/about.ui` + `_about_cb` in `src/application.py` | `lib/wike/about_dialog.rb` | dialog | yes |
| 33 | `data/gtk/shortcuts-dialog.ui` | `lib/wike/shortcuts_dialog.rb` | keyboard shortcuts | yes |
| 34 | `src/data.py` + `data/com.github.hugolabe.Wike.gschema.xml` | `lib/wike/data.rb` | support (settings + stores) | yes |
| 35 | `src/wikipedia.py` | `lib/wike/wikipedia.rb` | support (API client) | yes |
| 36 | `src/wike-sp.in` + `data/*.SearchProvider.*` | `lib/wike/shell_search_provider.rb` | D-Bus search provider | no |

Non-code assets that must travel with the port:

| Upstream | Port | Kind | Exists |
|---|---|---|---|
| `data/gtk/style.css` | `lib/wike/style.rb` (CSS string → `Gtk::CssProvider`) | app stylesheet | yes |
| `data/gtk/style-sepia.css` | `lib/wike/sepia_style.rb` | app stylesheet (sepia theme) | yes |
| `data/styles/view.css`, `data/styles/sepia.css` | `data/styles/` + loader in `view_settings.rb` | WebKit user stylesheets | files yes, loader no |
| `data/languages/languages.min.json` | `data/languages.json` | 300+ Wikipedia language names | yes |
| `data/icons/scalable/actions/*.svg` (17) | `data/icons/hicolor/scalable/actions/` | custom action icons | yes (17) |
| `data/icons/scalable/emblems/*.svg` (111) | `data/icons/hicolor/scalable/emblems/` | language flag icons | yes (111) |
| `po/` (39 languages, 157 msgids) | `po/` | translation catalogue | yes (39) |

---

## 1. `src/application.py` — the application: theme, global actions, shutdown

`Gtk::Application` (`Adwaita::Application` is broken in the bindings — the
existing stub already notes this), id `com.github.hugolabe.Wike`, flags
`HANDLES_COMMAND_LINE`, one `--url`/`-u` string option.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Application` | 1 | — | `startup`, `activate`, `command_line` | single `Window`, created lazily |
| `Adw.StyleManager` (default) | — | — | — | color scheme set from `theme` setting |
| `Gtk.CssProvider` | 1 | — | — | holds `style-sepia.css`, added/removed per theme |

Actions (`app.`), all `Gio::SimpleAction`, non-stateful:

| Action | Accel | Does |
|---|---|---|
| `app.prefs` | `<Ctrl>comma` | presents `PrefsDialog` |
| `app.theme-system` | — | `PREFER_LIGHT`, drop sepia provider, `theme=3` |
| `app.theme-light` | — | `FORCE_LIGHT`, drop sepia provider, `theme=0` |
| `app.theme-sepia` | — | `FORCE_LIGHT` + sepia provider, `theme=2` |
| `app.theme-dark` | — | `FORCE_DARK`, drop sepia provider, `theme=1` |
| `app.about` | — | presents the About dialog |
| `app.quit` | `<Ctrl>Q` | saves window geometry, `last-uri`, `last-tabs`, clears history if `keep-history` is off, clears WebKit data if `clear-data` is on, saves all stores |
| `app.shortcuts` | (F1/`<Ctrl>?` from Adw) | **installed by Libadwaita, not by this code** — the dialog is published at the resource root as `shortcuts-dialog.ui`, which `AdwApplication` auto-loads |

Theme at startup: `0→FORCE_LIGHT`, `1→FORCE_DARK`, `2→FORCE_LIGHT`+sepia
provider, `3→PREFER_LIGHT`.

`do_command_line` stores the `--url` value; if a window already exists it opens
it in a new tab immediately, otherwise `Window` consumes it as `launch_uri`
(the sentinel `notfound` loads the not-found status page).

On `close-request` the app disconnects the tabview's `notify::selected-page`
handler and activates `app.quit` — the port must keep that handler id.

Repeaters: none. Conditional: the sepia provider.

## 2. `src/window.py` + `data/gtk/window.ui` — the main window

`Adw.ApplicationWindow`, title `Wike`, `width-request` 360, `height-request`
480, default size from `window-width`/`window-height`, maximized per
`window-max`.

| Widget | × | CSS | Signals / bindings | Notes |
|---|---:|---|---|---|
| `Adw.TabOverview` `taboverview` | 1 | — | `create-tab` → new blank page | `view=tabview`, `enable-new-tab` |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | `send_notification` adds a 3 s `Adw.Toast` |
| `Adw.OverlaySplitView` `bar_split` | 1 | — | — | 46 px fixed-width icon rail |
| `Adw.OverlaySplitView` `panel_split` | 1 | — | `notify::show-sidebar` | 280–320 px, collapsed by default |
| `Adw.ToolbarView` | 3 | — | — | rail, panel, content |
| `Adw.BreakpointBin` | 1 | — | — | wraps the content area |
| `Adw.Breakpoint` | 3 | — | `apply`, `unapply` (all three) | `max-width: 750px`, `450px`, `550px` |
| `Gtk.MenuButton` `main_button` | 1 | `flat` | — | `primary`, "Main Menu", `open-menu-symbolic` |
| `Gtk.MenuButton` `main_button_mob` | 1 | — | — | same popover, moved on the 450px breakpoint |
| `Gtk.ToggleButton` rail selectors | 5 | `flat` | `toggled` → `panel_stack` page | search / toc / langlinks / bookmarks / history; radio group on `search_button` |
| `Gtk.ToggleButton` actionbar selectors | 5 | — | — | `*_mob` twins, two-way bound `active` to the rail ones |
| `Gtk.ToggleButton` `search_button_header` | 1 | — | — | hidden until the 450px breakpoint; bound to `search_button` |
| `Gtk.ToggleButton` `panel_button` | 1 | `flat` | `win.pin-panel` | hidden on the 750px breakpoint |
| `Gtk.ToggleButton` `panel_button_mob` | 1 | — | — | bound to `panel_split.show-sidebar` |
| `Gtk.Stack` `panel_stack` | 1 | — | — | 5 named pages; `visible-child-name` ↔ `panel-page` setting |
| `Gtk.ActionBar` `panel_actionbar` | 1 | — | — | `revealed` on the 450px breakpoint |
| `Gtk.ActionBar` `content_actionbar` | 1 | — | — | `revealed` on the 550px breakpoint |
| `Gtk.Button` `close_panel_button_mob` | 1 | — | `clicked` | `go-previous-symbolic`, "Close" |
| `Gtk.HeaderBar` `headerbar` | 1 | — | — | `top-bar-style`/`bottom-bar-style` `raised` |
| `Gtk.Button` `prev_button`, `next_button` | 2 | — | `win.prev-page`, `win.next-page` | hidden on the 550px breakpoint |
| `Gtk.Button` `newtab_button` | 1 | — | `win.new-tab` | hidden when tabs are hidden |
| `Adw.TabButton` `tabs_button` | 1 | — | `win.toggle-overview` | shown only when tabs are hidden |
| `Gtk.MenuButton` `article_button` / `_mob` | 2 | — | — | `view-more-symbolic`, "Article Menu" |
| `Gtk.MenuButton` `view_button` / `_mob` | 2 | — | — | `view-reveal-symbolic`, "View" |
| `Adw.TabBar` `tabbar` | 1 | — | — | hidden per `hide-tabs` or the 550px breakpoint |
| `Adw.TabView` `tabview` | 1 | — | `notify::selected-page` (handler kept), `close-page` | holds every `PageBox` |
| `Gtk.Button` (actionbar prev/next) | 2 | — | `win.prev-page`, `win.next-page` | unnamed duplicates for mobile |
| `Gtk.GestureClick` | 1 | — | `pressed` | controller: button 8 → back, button 9 → forward |
| `Gtk.PrintSettings` | 1 | — | — | not a widget; remembers the output URI |

Actions (`win.`), installed in a loop over a 21-entry table — names are not
literals at the call site:

| Action | Accel |
|---|---|
| `prev-page` | `<Alt>Left` |
| `next-page` | `<Alt>Right` |
| `new-tab` | `<Ctrl>T` |
| `close-tab` | `<Ctrl>W` |
| `next-tab` | `<Ctrl>Tab` |
| `prev-tab` | `<Shift><Ctrl>Tab` |
| `toggle-overview` | `F4`, `<Alt>T` |
| `add-bookmark` | `<Ctrl>D` |
| `show-search` | `F2`, `<Ctrl>K` |
| `show-toc` | `<Ctrl>I` |
| `show-langlinks` | `<Ctrl>L` |
| `show-bookmarks` | `<Ctrl>B` |
| `show-history` | `<Ctrl>H` |
| `main-page` | `<Alt>Home` |
| `random-article` | `<Alt>R` |
| `open-link` | `<Alt>L` |
| `reload-page` | `F5`, `<Ctrl>R` |
| `search-text` | `<Ctrl>F` |
| `print-page` | `<Ctrl>P` |
| `open-browser` | — |
| `copy-link` | `<Ctrl>U` |
| `pin-panel` (stateful boolean) | `F9` |

Enablement rules the port must reproduce: `pin-panel` is disabled while either
window breakpoint applies; `prev-page`/`next-page` follow the webview's
back/forward list; `search-text`, `print-page`, `open-browser` and `copy-link`
are disabled on a local (`about:`) page; `add-bookmark` is disabled when the
page is local or already bookmarked.

Toasts: "Bookmark added: <title>", "Print operation completed", "Print
operation failed", "Link copied to clipboard".

Repeaters: one `PageBox` per tab, restored from `last-tabs` (lazy-loaded, title
only, body fetched on first selection). Conditional: `on-start-load` chooses
main page / random / last URI / restore tabs.

## 3. `src/page.py` (`PageBox`) + `data/gtk/page.ui` — one tab's content

`Gtk.Box` vertical.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.SearchBar` `search_bar` | 1 | — | — | `show-close-button`, entry connected |
| `Gtk.SearchEntry` `search_entry` | 1 | `error` (dynamic, on no match) | `search-changed`, `activate` | placeholder "Search text", 30 chars |
| `Gtk.Button` `search_prev_button` | 1 | — | `clicked` | `go-up-symbolic`, "Previous Result", insensitive until a hit |
| `Gtk.Button` `search_next_button` | 1 | — | `clicked` | `go-down-symbolic`, "Next Result" |
| `Gtk.Label` `search_matches_label` | 1 | — | — | 4 chars, shows the match count |
| `Gtk.Stack` `view_stack` | 1 | — | — | named pages `wikiview` and `status` |
| `Gtk.EventControllerKey` | 1 | — | `key-pressed` | controller on the webview: forwards all keys to the window except Tab/Return/Home/arrows/Page/End and Ctrl combos |

Non-widget wiring: WebKit find controller (`found-text`,
`failed-to-find-text`, `counted-matches`; search starts at 3 characters,
`WRAP_AROUND|CASE_INSENSITIVE`, limit 9999) and the back/forward list's
`changed`. `WikiView` signals consumed: `load-changed`, `load-props`,
`new-page`, `add-bookmark`.

Tab-title states: "Loading…" on `STARTED`, article title on `load-props`.
`lazy_load` holds `[uri, title]` until the tab is first selected.

## 4. `src/page.py` (`PageStatus`) + `data/gtk/page-status.ui` — the three empty/error states

`Adw.Bin` → `Adw.StatusPage` with class `wikiview-status`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.StatusPage` `status_page` | 1 | `wikiview-status` | — | title/description/icon set per state |
| `Gtk.Button` `main_page_button` | 1 | `pill`, `suggested-action` | `win.main-page` | "Main Page" |
| `Gtk.Button` `random_article_button` | 1 | `pill` | `win.random-article` | "Random Article" |
| `Gtk.Button` `try_again_button` | 1 | `pill`, `suggested-action` | `clicked` | "Try Again", reloads `fail_uri` |

| URI | Title | Description | Icon | Buttons |
|---|---|---|---|---|
| `about:blank` (default) | Search Wikipedia | Start typing to search Wikipedia articles | `com.github.hugolabe.Wike` | main page + random |
| `about:notfound` | Article not Found | Can't find any results for requested query | `find-location-symbolic` | main page |
| `about:error` | Can't Access Wikipedia | Check your Internet connection and try again | `network-error-symbolic` | try again |

Focus is grabbed by the first visible button in each state.

## 5. `src/view.py` (`WikiView`) — the article webview

`WebKit.WebView` subclass; transparent background, zoom from `zoom-level`/100.
Custom signals `load-props`, `new-page(str)`, `add-bookmark(str,str,str)`;
overrides `do_load_changed`, `do_load_failed`, `do_decide_policy`,
`do_context_menu`.

Loaders: `load_wiki(uri)`, `load_section(anchor)`, `load_main` (language main
page), `load_random` (API), `load_message(type)` → `about:<type>` alternate
HTML. Helpers: `get_base_uri`, `get_lang`, `is_local`, `is_wiki_uri`.

Policy: in-app navigation only for `*.wikipedia.org/wiki/*`; middle-click emits
`new-page`; non-Wikipedia links open externally; `upload.*` is blocked; dark/
light Wikipedia skin toggled by injected JavaScript.

Context menu — a `WebKit.ContextMenu` rebuilt by hand, four `Gio::SimpleAction`s
with a string parameter:

| Item | Action | Shown when |
|---|---|---|
| Add Bookmark | `new-tab`-group `add-bookmark` | document context |
| Open Link in New Tab | `new-tab` | link, not image |
| Open Link in Browser | `open-browser` | link, not image |
| Add Link to Bookmarks | `add-bookmark` | link, not image |
| Copy Link to Clipboard | `copy-link` | link, not image |

Everything but back / forward / reload / copy / copy-image / copy-image-URL is
stripped from the stock menu; the menu is suppressed entirely over editable,
media and scrollbar contexts.

## 6. `src/view.py` (`ViewSettings`) — shared WebKit settings and injected CSS

Not a widget. One process-wide object: `WebKit.Settings` (mobile user agent,
default font size from settings, back/forward gestures), a
`WebKit.UserContentManager` holding `view.min.css`, a generated font rule, the
sepia sheet when `theme=2` and a `.mwe-popups{display:none}` rule when
`preview-popups` is off; custom signal `set-skin(bool)`. Reacts to
`changed::font-family`, `changed::font-size`, `changed::preview-popups`,
`changed::theme` and `AdwStyleManager::notify::dark`. The network session sets
a persistent text cookie jar at `$XDG_DATA_HOME/cookies`, policy `ALWAYS`.

## 7. `src/search.py` (`SearchPanel`) + `data/gtk/search.ui` — the search sidebar page

`Adw.Bin` → `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (header) | 1 | `toolbar` | — | |
| `Gtk.SearchEntry` `search_entry` | 1 | — | `changed`, `stop-search`, `activate`; delegate `notify::has-focus` | placeholder "Search Wikipedia", `set_key_capture_widget(window)` |
| `Gtk.MenuButton` `settings_button` | 1 | — | — | label = language id, tooltip = language name, 60 px |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `suggestions_list` | 1 | `navigation-sidebar` | `row-activated` | selection none |
| `Adw.StatusPage` (placeholder) | 1 | `compact` | — | "No Results" / "Enter at least three characters to get search suggestions" / `find-location-symbolic` |

Behaviour: suggestions only when `search-suggestions` is on and the query is
longer than two characters; `-xx ` prefix overrides the language; Enter
searches for one result and loads it, or shows the not-found / error status
page; Escape clears the entry, then closes the collapsed sidebar.

Repeater: one `SearchRow` per suggestion (limit 20).

## 8. `src/search.py` (`SearchRow`) + `data/gtk/search-row.ui` — one suggestion

`Gtk.ListBoxRow` holding a single `Gtk.Label` `suggestion_label` (start-aligned,
ellipsized). Carries `title` and `uri`.

## 9. `src/search.py` (`SettingsPopover`) + `data/gtk/search-settings.ui` — search settings

`Gtk.Popover`, width 240, class `menu`, wrapping an `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` `languages_button` | 1 | — | `clicked` | "Pick your Languages" → `LanguagesDialog` |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | max height 320, natural size |
| `Gtk.ListBox` `languages_list` | 1 | — | `row-activated` | sets `search-language` |
| `Gtk.Label` | 1 | — | — | "Search Suggestions" |
| `Gtk.Switch` `suggestions_switch` | 1 | — | bound to `search-suggestions` | |

Reacts to `changed::search-suggestions` and `changed::show-flags`; unselects all
on `show`. Repeater: one `SettingsLangsRow` per user language, sorted.

## 10. `src/search.py` (`SettingsLangsRow`) + `data/gtk/search-settings-row.ui` — one search language

`Gtk.ListBoxRow` → `Gtk.Box`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Image` `flag_image` | 1 | — | — | 16 px, `noflag` default, flag icon when `show-flags` and the emblem exists; hidden otherwise |
| `Gtk.Label` `name_label` | 1 | — | — | language name |
| `Gtk.Image` `check_image` | 1 | — | — | `checkmark-symbolic` on the current language |
| `Gtk.Label` `id_label` | 1 | `dim-label` | — | language code |

## 11. `src/toc.py` (`TocPanel`) + `data/gtk/toc.ui` — the contents sidebar page

`Adw.Bin` → `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Label` `title_label` | 1 | `heading` | — | article title, 46 px tall, 30 chars, ellipsized |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `toc_list` | 1 | `navigation-sidebar` | `row-activated` → `load_section` | selection none |
| `Adw.StatusPage` (placeholder) | 1 | `compact` | — | "No Contents" / "There is no table of contents for this page" / `view-list-symbolic` |

Activating a row closes a collapsed sidebar first. Repeater: one `TocBoxRow`
per API section.

## 12. `src/toc.py` (`TocBoxRow`) + `data/gtk/toc-row.ui` — one section

`Gtk.ListBoxRow` → `Gtk.Label` `section_label` (markup, ellipsized). CSS class
`caption` added dynamically when `toclevel > 1`; `margin-start` is
`3 + (level - 1) * 15`. Carries `anchor`.

## 13. `src/langlinks.py` (`LanglinksPanel`) + `data/gtk/langlinks.ui` — the languages sidebar page

`Adw.Bin` → `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (header) | 1 | `toolbar` | — | |
| `Gtk.DropDown` `filter_dropdown` | 1 | — | bound to `filter-langlinks` | model of 2 `LanguagesFilter`s, `Gtk.SignalListItemFactory` (`setup`, `bind`) |
| `Gtk.ToggleButton` `search_button` | 1 | — | — | `system-search-symbolic`, "Search Languages", bound to the search bar |
| `Gtk.SearchBar` `search_bar` | 1 | — | — | two-way bound `search-mode-enabled` |
| `Gtk.SearchEntry` `search_entry` | 1 | — | `search-changed` → `invalidate_filter` | placeholder "Search languages" |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `langlinks_list` | 1 | `navigation-sidebar` | `row-activated` | selection none, filter func |
| `Adw.StatusPage` (placeholder) | 1 | `compact` | — | "No Languages" / "This page is not available in other languages" / `language-symbolic` |
| `Gtk.Label` (section header, runtime) | 0–1 | `heading` | — | "Other languages", inside a non-activatable `Gtk.ListBoxRow` |

Dropdown items: "Your languages", "All languages". Repeaters: one
`LanglinksRow` per user-language link, plus, when the filter is "All", a
section header row and one row per remaining language.

## 14. `src/langlinks.py` (`LanglinksRow`) + `data/gtk/langlinks-row.ui` — one language link

`Gtk.ListBoxRow` → `Gtk.Box`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Image` `flag_image` | 1 | — | — | 28 px, `noflag`, hidden when `show-flags` is off |
| `Gtk.Label` `lang_label` | 1 | — | — | autonym, ellipsized |
| `Gtk.Label` `title_label` | 1 | `caption`, `dim-label` | — | translated article title |

## 15. `src/langlinks.py` (`LanguagesFilter`) — dropdown item object

`GObject` with `name` (string) and `level` (int) properties. Two instances.

## 16. `src/bookmarks.py` (`BookmarksPanel`) + `data/gtk/bookmarks.ui` — the bookmarks sidebar page

`Adw.Bin` → `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (header) | 1 | `toolbar` | — | |
| `Gtk.DropDown` `booklists_dropdown` | 1 | — | `notify::selected`; model `items-changed` | `Booklist` model + signal factory; "Reading list" is index 0 |
| `Gtk.Button` `add_button` | 1 | — | `win.add-bookmark` | `bookmark-new-symbolic`, "Add Bookmark" |
| `Gtk.ToggleButton` `selection_button` | 1 | — | — | `selection-mode-symbolic`, "Select"; reveals the action bar and each row's check |
| `Gtk.MenuButton` `menu_button` | 1 | — | — | `view-more-symbolic` → `BookmarksMenuPopover` |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `bookmarks_list` | 1 | `navigation-sidebar` | `row-activated` | selection none, sort by title then language |
| `Adw.StatusPage` (placeholder) | 1 | `compact` | — | "No Bookmarks" / "Use the Add Bookmark button or press Ctrl+D to add the current article to the list" / `user-bookmarks-symbolic` |
| `Gtk.ActionBar` | 1 | — | `revealed` bound to `selection_button` | |
| `Gtk.Button` `select_all_button` | 1 | — | `clicked` | `edit-select-all-symbolic`, "Select All" |
| `Gtk.Button` `select_none_button` | 1 | — | `clicked` | `edit-select-none-symbolic`, "Select None" |
| `Gtk.Button` `remove_button` | 1 | `destructive-action` | `clicked` | `app-remove-symbolic`, "Remove Selected" |

Action group `bookmarks` (`Gio::SimpleActionGroup`, names from a loop):
`bookmarks.create-list`, `bookmarks.rename-list` (disabled on the default
list), `bookmarks.clear-list`. Repeater: one `BookmarksRow` per bookmark in the
selected list.

## 17. `src/bookmarks.py` (`BookmarksRow`) + `data/gtk/bookmarks-row.ui` — one bookmark

`Gtk.ListBoxRow` → `Gtk.Box`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CheckButton` `select_check` | 1 | `selection-mode` | — | hidden; `visible` bound to the panel's selection toggle |
| `Gtk.Label` `title_label` | 1 | — | — | article title, ellipsized |
| `Gtk.Label` `lang_label` | 1 | `caption`, `dim-label` | — | language name |

## 18. `src/bookmarks.py` (`BookmarksMenuPopover`) + `data/gtk/bookmarks-menu.ui` — bookmarks list menu

`Gtk.PopoverMenu` over a 2-section, 3-item `Gio.Menu`: "Create New List…"
(`bookmarks.create-list`), "Rename List…" (`bookmarks.rename-list`), "Clear
List…" (`bookmarks.clear-list`). Connects `show` to enable/disable rename.

## 19. `src/bookmarks.py` (`Booklist`) — dropdown item object

`GObject` with a `name` string property; one per bookmark list plus the
default.

## 20. `src/history.py` (`HistoryPanel`) + `data/gtk/history.ui` — the history sidebar page

`Adw.Bin` → `Adw.ToolbarView`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (header) | 1 | `toolbar` | — | |
| `Gtk.DropDown` `filter_dropdown` | 1 | — | bound to `filter-history` | 4 `HistoryFilter`s + signal factory |
| `Gtk.ToggleButton` `selection_button` | 1 | — | — | `selection-mode-symbolic`, "Select" |
| `Gtk.Button` `clear_button` | 1 | — | `clicked` | `list-remove-all-symbolic`, "Clear History" → confirm dialog |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `history_list` | 1 | `navigation-sidebar` | `row-activated` | selection none |
| `Adw.StatusPage` (placeholder) | 1 | `compact` | — | "Empty History" / "There are no recent articles in the history" / `document-open-recent-symbolic` |
| `Gtk.ActionBar` | 1 | — | `revealed` bound to `selection_button` | |
| `Gtk.Button` `select_all_button` / `select_none_button` | 2 | — | `clicked` | as in bookmarks |
| `Gtk.Button` `remove_button` | 1 | `destructive-action` | `clicked` | "Remove Selected" |
| `Gtk.Label` (date header, runtime) | 0..n | `heading` | — | one per day, in a non-activatable `Gtk.ListBoxRow` |

Dropdown items: "Today" (1), "Last 7 days" (7), "Last 30 days" (30), "Show full
history" (365). Reacts to `changed::keep-history` and `changed::filter-history`.
Repeaters: a date header row per day plus one `HistoryRow` per article;
removing the last article of a day removes its header too.

## 21. `src/history.py` (`HistoryRow`) + `data/gtk/history-row.ui` — one visited article

`Gtk.ListBoxRow` → `Gtk.Box`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CheckButton` `select_check` | 1 | `selection-mode` | — | hidden; bound to the selection toggle |
| `Gtk.Label` `title_label` | 1 | — | — | article title, ellipsized |
| `Gtk.Label` `time_label` | 1 | `caption`, `dim-label` | — | `HH:MM` |
| `Gtk.Label` `lang_label` | 1 | `caption`, `dim-label` | — | language name |

## 22. `src/history.py` (`HistoryFilter`) — dropdown item object

`GObject` with `name` (string) and `days` (int). Four instances.

## 23. `src/languages.py` (`LanguagesDialog`) + `data/gtk/languages.ui` — pick your languages

`Adw.Dialog`, title "Pick your Languages", 380 × 500.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | |
| `Gtk.ToggleButton` `search_button` | 1 | — | — | `system-search-symbolic`, "Search Languages", bound to the search bar |
| `Gtk.SearchBar` `search_bar` | 1 | — | — | `set_key_capture_widget(self)` |
| `Gtk.SearchEntry` `languages_entry` | 1 | — | `search-changed` → `invalidate_filter` | placeholder "Search languages", 20 chars |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 | — | — | |
| `Gtk.ListBox` `languages_list` | 1 | `navigation-sidebar` | `row-activated` toggles the row's check | selection none, filter by name or code prefix |
| `Gtk.ActionBar` | 1 | — | — | |
| `Gtk.Button` `select_all_button` | 1 | — | `clicked` | `edit-select-all-symbolic`, "Select All" |
| `Gtk.Button` `select_none_button` | 1 | — | `clicked` | `edit-select-none-symbolic`, "Select None" |
| `Gtk.Label` `selected_label` | 1 | — | — | "1 language selected" / "%s languages selected" |

`closed` rewrites the user language list (falling back to `en` when empty) and
repopulates the search settings popover and the langlinks panel. Repeater: one
`LanguagesRow` per Wikipedia language (300+ from `languages.min.json`), each
row's check connected in the loop.

## 24. `src/languages.py` (`LanguagesRow`) + `data/gtk/languages-row.ui` — one selectable language

`Gtk.ListBoxRow` → `Gtk.Box`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CheckButton` `lang_check` | 1 | `selection-mode` | `toggled` (connected by the dialog) | |
| `Gtk.Label` `name_label` | 1 | — | — | language name |
| `Gtk.Label` `id_label` | 1 | `dim-label` | — | language code |

## 25. `src/prefs.py` + `data/gtk/prefs.ui` — preferences

`Adw.PreferencesDialog`, 580 × 480, one `Adw.PreferencesPage`, two groups.

| Widget | × | CSS | Signals / bindings | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesGroup` | 2 | — | — | "Behavior", "Privacy" |
| `Adw.ComboRow` `start_combo` | 1 | — | bound to `on-start-load` | "Home Page"; `Gtk.StringList` of "Wikipedia main page", "Random article", "Last article", "Restore open articles" |
| `Adw.SwitchRow` `tabs_switch` | 1 | — | bound to `hide-tabs` | "Always Hide Tabs" |
| `Adw.ExpanderRow` | 1 | — | — | "Allow Live Search on Desktop" + warning subtitle |
| `Gtk.Switch` `desktop_switch` | 1 | — | bound to `search-desktop` | prefix of the expander |
| `Adw.ActionRow` | 3 | — | — | the expander's explanatory row, "Keep a List of Recent Articles", "Clear Personal Data on Close" |
| `Gtk.Switch` `history_switch` | 1 | — | bound to `keep-history` | activatable widget of its row |
| `Gtk.Switch` `data_switch` | 1 | — | bound to `clear-data` | activatable widget of its row |
| `Gtk.Button` `clear_history_button` | 1 | — | `clicked` | "Clear" → clear-history dialog |
| `Gtk.Button` `clear_data_button` | 1 | — | `clicked` | "Clear" → clear-data dialog |

## 26. `src/menu.py` (`MainMenuPopover`) + `data/gtk/menu-main.ui` — main menu

`Gtk.PopoverMenu` over a 1-section, 3-item `Gio.Menu`: "Preferences"
(`app.prefs`), "Keyboard Shortcuts" (`app.shortcuts`), "About Wike"
(`app.about`). Moves between `main_button` and `main_button_mob` on the 450px
breakpoint.

## 27. `src/menu.py` (`ArticleMenuPopover`) + `data/gtk/menu-article.ui` — article menu

`Gtk.PopoverMenu` over a 3-section, 7-item `Gio.Menu`. First section is
`display-hint horizontal-buttons`: "Print" (`printer-symbolic`,
`win.print-page`) and "Search Text" (`system-search-symbolic`,
`win.search-text`). Then "Main Page" (`win.main-page`), "Random Article"
(`win.random-article`), "Open Wikipedia Link" (`win.open-link`); then "Open in
Browser" (`win.open-browser`), "Copy Link to Clipboard" (`win.copy-link`).

## 28. `src/menu.py` (`ViewMenuPopover`) + `data/gtk/menu-view.ui` — view menu

`Gtk.PopoverMenu`. Menu model: a `custom:theme_switcher` slot, a
`custom:zoom_level` slot, a "Show" section with "Language Flags"
(`view.show-flags`) and "Link Previews" (`view.preview-popups`), and a "Font"
section appended at runtime whose single item is the current
`<family> <size>` label pointing at `view.set-font`.

Action group `view`: stateful `show-flags`, stateful `preview-popups`, plain
`set-font`.

`set-font` opens `Gtk.FontChooserDialog` "Pick a Font", level `SIZE`, modal; on
OK it writes `custom-font`, `font-family`, `font-size` and rebuilds the Font
section (`view_menu.remove(3)` then re-append). On first run without
`custom-font` the popover's own Pango context supplies the default family.

## 29. `src/menu.py` (`ThemeSwitcher`) + `data/gtk/theme-switcher.ui` — the four theme swatches

`Gtk.Box`, `halign center`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CheckButton` `system_button` | 1 | `theme-button`, `theme-button-system` | `toggled` → `app.theme-system` | group leader |
| `Gtk.CheckButton` `light_button` | 1 | `theme-button`, `theme-button-light` | `toggled` → `app.theme-light` | |
| `Gtk.CheckButton` `sepia_button` | 1 | `theme-button`, `theme-button-sepia` | `toggled` → `app.theme-sepia` | |
| `Gtk.CheckButton` `dark_button` | 1 | `theme-button`, `theme-button-dark` | `toggled` → `app.theme-dark` | |
| `Gtk.Image` | 4 | — | — | one `checkmark-symbolic` per swatch, revealed by the `:checked` CSS |

The swatch look is entirely `data/gtk/style.css`: `.theme-button radio`
(26 px circle, 1 px `@light_4` border), `.theme-button:checked radio` (2 px
accent border), `.theme-button image` (overlaid accent check, opacity 0 → 1),
and four gradient/colour rules — system (`@light_1`/`@dark_3` diagonal), light
(`@light_1`), sepia (`#f4ecd8`), dark (`@dark_3`). Dropping that stylesheet
produces four plain radio buttons.

## 30. `src/menu.py` (`ZoomLevel`) + `data/gtk/zoom-level.ui` — the zoom stepper

`Gtk.Box`, `halign center`, spacing 6.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` `zoom_out_button` | 1 | `flat`, `circular` | `clicked` | `zoom-out-symbolic`, −10 %, floor 50 % |
| `Gtk.Button` `zoom_value_button` | 1 | `flat` | `clicked` | 100 px wide, shows "N%", resets to 100 %, insensitive at 100 % |
| `Gtk.Button` `zoom_in_button` | 1 | `flat`, `circular` | `clicked` | `zoom-in-symbolic`, +10 %, ceiling 200 % |

Reacts to `changed::zoom-level`; the two steppers go insensitive at their
limits.

## 31. `data/gtk/dialogs.ui` — six confirm/entry dialogs

No backing source file of its own; built on demand by `window.py`,
`prefs.py` and `bookmarks.py`.

| Object | Type | Heading | Responses | Extra child |
|---|---|---|---|---|
| `new_booklist_dialog` | `Adw.AlertDialog` (340 px) | New Bookmarks List | Cancel, **Create List** (`suggested`, disabled until valid) | `Adw.PreferencesGroup` → `Adw.EntryRow` `name_entry` "List Name" |
| `rename_booklist_dialog` | `Adw.AlertDialog` (340 px) | Rename Bookmarks List | Cancel, **Rename List** (`suggested`, disabled until valid) | `Adw.EntryRow` `rename_entry` |
| `clear_booklist_dialog` | `Adw.AlertDialog` | Clear Bookmarks List? | Cancel, **Clear List** (`destructive`) | `Gtk.CheckButton` `delete_booklist_check` "Also delete the list" (insensitive on the default list) |
| `clear_history_dialog` | `Adw.AlertDialog` | Clear History? | Cancel, **Clear History** (`destructive`) | — |
| `clear_data_dialog` | `Adw.AlertDialog` | Clear Personal Data? | Cancel, **Clear Data** (`destructive`) | — |
| `open_link_dialog` | `Adw.Dialog` | Open Wikipedia Link | — (apply button on the entry) | `Adw.ToolbarView` + `Adw.HeaderBar`, `Adw.EntryRow` `link_entry` with `show-apply-button`, and a `Gtk.Label` hint `https://<i>lang</i>.wikipedia.org/wiki/<i>Article</i>` with classes `monospace`, `dimmed` |

Dynamic CSS: `error` is added to `name_entry`, `rename_entry` and `link_entry`
on invalid input and removed on change. Name validation rejects the empty
string, the default list name and any existing list name.

## 32. `data/gtk/about.ui` + `_about_cb` — About Wike

`Adw.AboutDialog`: icon and name Wike, developer Hugo Olabera, version 3.2.1,
comments "Search and read Wikipedia articles", website
`hugolabe.github.io/Wike`, copyright "© 2021-25 Hugo Olabera", GPL-3.0,
translator credits. Built up in code with three links ("Source Code", "Report
an Issue", "Help Translating"), a developer list, a "Flag Icons" credit
section, and two legal sections — "Wikipedia" (CC BY-SA 4.0 notice plus the
"independent development" disclaimer) and "Circle Flags" (MIT).

## 33. `data/gtk/shortcuts-dialog.ui` — keyboard shortcuts

`Adw.ShortcutsDialog`, auto-loaded by Libadwaita from the resource root, with
no backing source file. Four `Adw.ShortcutsSection`s, 25 `Adw.ShortcutsItem`s —
all but "Main menu" declare an `action-name` and take their accelerator from
the app's bindings:

- **General** (10): Main menu (`F10`), Sidebar, Table of contents, Languages, Search text, Print, Copy link to clipboard, Preferences, Keyboard shortcuts, Quit
- **Bookmarks** (2): Bookmarks, Add bookmark
- **Tabs** (5): New tab, Close current tab, Next tab, Previous tab, View open tabs
- **Navigation** (8): Search articles, Main page, Random article, Open Wikipedia link, History of recent articles, Previous page, Next page, Reload current page

All titles carry the `shortcut window` message context — the port's catalogue
must keep it.

## 34. `src/data.py` + the GSettings schema — settings and the three stores

Not widgets. `Gio::Settings` for `com.github.hugolabe.Wike` plus three JSON
stores under `$XDG_DATA_HOME`: `languages.json` (user languages, default
`{en: English}`), `historic.json` (date → uri → `[time, title, lang]`),
`bookmarks.json` + `booklists.json`. The full language table is read from the
`languages.min.json` resource.

Schema keys (26): `search-language` `en`, `search-suggestions` true,
`search-desktop` false, `keep-history` true, `clear-data` false,
`on-start-load` 0, `last-uri` "", `last-tabs` `a{ss}` {}, `hide-tabs` false,
`theme` 3, `zoom-level` 100, `show-flags` true, `preview-popups` false,
`custom-font` false, `font-family` "Sans", `font-size` 16, `panel-pinned`
false, `panel-page` "toc", `filter-langlinks` 0, `filter-history` 0,
`window-width` 900, `window-height` 700, `window-max` false.

## 35. `src/wikipedia.py` — the Wikipedia API client

Not a widget. A libsoup session (user agent `Wike/3.2.1 …`) and four calls
against `https://<lang>.wikipedia.org/w/api.php`: `get_random` (random
generator with `inprop=url`), `search` (`opensearch`, configurable limit,
`redirects=resolve`, async or sync), `get_properties`
(`action=parse&prop=sections|langlinks&redirects=1`), and the three
`*_result` finishers.

## 36. `src/wike-sp.in` + `data/*.SearchProvider.*` — GNOME Shell search provider

A second `Gio::Application`
(`com.github.hugolabe.Wike.SearchProvider`, `IS_SERVICE`, 10 s inactivity)
exporting `org.gnome.Shell.SearchProvider2` on
`/com/github/hugolabe/Wike/SearchProvider`: `GetInitialResultSet`,
`GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch`.
With `search-desktop` off it returns the single pseudo-result
"Search “%s” on Wikipedia"; with it on it queries the API for 5 titles.
Activating spawns `wike --url <uri>`. Ships a `.ini` provider file and two
D-Bus `.service` files.

---

## Notes and upstream oddities worth carrying forward

- **`app.shortcuts` has no handler in `src/`.** The action and its dialog come
  from Libadwaita, which auto-loads `shortcuts-dialog.ui` from the resource
  root — note the `<file alias="shortcuts-dialog.ui">` line in the GResource
  manifest. The Ruby port has no GResource, so it must install the action
  itself.
- **`po/POTFILES` is stale**: it lists `data/gtk/help-overlay.ui`, which no
  longer exists (it became `shortcuts-dialog.ui`), and omits
  `data/gtk/langlinks-row.ui`'s replacement — any port-side POTFILES should be
  regenerated, not copied.
- **Widget pairs bound two ways.** The rail toggles, their mobile twins and the
  header search toggle are joined by `bind-source`/`bind-property` with
  `sync-create` in the `.ui`, not by code. Reproducing them as one-way
  assignments produces toggles that desync.
- **Popovers move between buttons.** The main, article and view popovers are
  re-parented on breakpoint apply/unapply (`set_popover(None)` on one button,
  `set_popover(p)` on the other). A port that builds two popovers instead of
  moving one will show stale state.
- **Three `row-activated` handlers close a collapsed sidebar before acting.**
- **`style.css` is load-bearing**, not decoration: the whole theme switcher is
  drawn by it, and it also sets `--headerbar-bg-color` and the
  `.wikiview-status` background in dark mode and `.navigation-sidebar > row`
  min-height.
- **Bindings quirks to expect** (see `.claude/skills/ruby-gtk`):
  `Adwaita::Application` is unusable, `Gtk::VERSION` does not exist (the
  constant is `Gtk::Version`), and `Adwaita::ShortcutsItem.new` takes
  positional, not keyword, arguments.
- **WebKitGTK 6 and libsoup 3 via GObject introspection** are the biggest
  unknown on the Ruby side: `WikiView` subclasses `WebKit.WebView` and
  overrides four virtual methods (`do_load_changed`, `do_load_failed`,
  `do_decide_policy`, `do_context_menu`). Whether the Ruby bindings allow
  overriding those vfuncs needs a spike before the port commits to the
  subclass shape.
