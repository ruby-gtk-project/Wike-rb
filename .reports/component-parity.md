# Component parity — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` |
| Port | `ruby` @ `79db2b8` |
| Units with full (4-axis) parity | not computed exhaustively; see per-unit findings below — this pass is adversarial and targeted at the units with a suspected gap, not a full 37-unit sweep |

This fork's house widget mapping (type/CSS/signal/action, per
`component-identification.md`) checks out file-by-file for the 37 ported
units — no missing `lib/wike/*.rb` file was found, and the runtime drive
(see `test-parity.md`) exercises 20 of them live with observed, asserted
behaviour, which is real evidence for those 20 on the count/behaviour axes.
That is good news and is reported as such. It is not the same claim as "all
four axes hold for all 37 units," and the gaps below are real, not
nitpicks.

## Gap 1 — settings backing technology (data/settings subsystem)

| | Upstream | Port |
|---|---|---|
| Mechanism | `Gio.Settings` bound to `com.github.hugolabe.Wike` schema | hand-rolled JSON file, `lib/wike/data.rb` |
| Schema compiled/installed | yes (packaging step) | no — `data/com.github.hugolabe.Wike.gschema.xml` exists but is read/compiled by nothing in the tree (`gemspec`, `Rakefile`, `nix/*` all checked — no `glib-compile-schemas` step, no install path) |
| `gsettings get/set org.rubygtkproject.wike ...` from a terminal | works | does nothing — there is no schema under that id to query |
| dconf-editor integration | works | none |
| Type/range enforcement upstream gets from the schema (e.g. the `(0-Light, 1-Dark, 2-Sepia, 3-System)` enum range on `theme`) | enforced by `Gio.Settings` | enforced only by whatever the Ruby code happens to check, if anything |

This is a **gap**, not a correspondence. The port does not reach the same
behaviour by a different mechanism — it reaches a *subset* of the behaviour
(the app's own preferences persist and round-trip) while losing the parts
that depend on the setting actually being a `GSettings` key: external
tooling, dconf, and any other app or script that expects to read/write
`org.rubygtkproject.wike` (or `com.github.hugolabe.wike`) via the standard
GSettings API gets nothing. `prefs_dialog.rb`, `theme_switcher.rb`,
`zoom_level.rb`, `bookmarks_panel.rb` and `history_panel.rb` all bind to
these keys in the port; all five therefore inherit this same gap, because
none of them is actually talking to `Gio::Settings` underneath.

Verdict: **gap**. Named here against the component; the comments explaining
it are addressed in `accountability-ensurance.md` because they read as a
justification rather than as a located debt.

## Gap 2 — D-Bus activation for the main application

Upstream: `data/com.github.hugolabe.Wike.service.in` +
`DBusActivatable=true` in the `.desktop.in`. Port: neither file nor flag
exists for the main app (only the search-provider side was ported — see
`shell_search_provider.rb` and `data/org.rubygtkproject.Wike.SearchProvider.service.in`,
which **is** present and correct).

Verdict: **gap**. The search provider finding a non-running Wike and
activating it over D-Bus (one of the two things a shell search provider is
for) has no activation file to be started from on the port.

## Gap 3 — `wikipedia.rb` has no driven behaviour anywhere in the tree

`component-identification.md` #3. `get_random`, `search`, `get_properties`
and the private HTTP/parsing chain underneath them are not called by
`test/drive_main_window.rb`, by any spec, or by any other script in the
repository. Component count/style axes aside (there is nothing to look at —
this is a network client, not a widget), the **behaviour** axis is entirely
unverified: no test or drive step asserts that a real or stubbed MediaWiki
response is parsed into the shape `page_box.rb`/`toc_panel.rb`/
`langlinks_panel.rb` expect. Everything downstream of this file in the
pipeline (table of contents, language links, search results, the article
view itself) is tested only with hand-seeded local fixtures (see
`test-parity.md`); the one file that actually talks to Wikipedia has zero
assertions of its own.

Verdict: **gap**, behavioural. Fixing it does not require live network
access — a stubbed `Soup::Session` response is standard — but one does not
exist.

## Text axis

Deferred to `translation-parity.md` in full, because it is not a per-unit
finding here — it is systemic: **no widget in any of the 37 files marks any
of its user-visible strings for translation.** Every unit's text column is
therefore `✗` across the board. `translation-parity.md` has the census and
the numbers; it is cited here because component-parity's own rule is that a
text gap is recorded in both ledgers.

## What is not a gap

- Icons, search-provider `.ini`/`.service.in`, `languages.json`, and both
  in-article stylesheets (`view.css`, `sepia.css`) are present and match
  upstream's equivalents (file renamed per the port's own app id, same
  content) — `component-inventory.md`'s earlier table confirms this and it
  was spot-checked again here.
- The 20 units exercised by `test/drive_main_window.rb` (window, toc, bookmarks
  + its dialogs, history, search settings, zoom, theme switcher, main/article
  menu popovers, in-article search, status page, shell search provider, tab
  view, preferences, languages dialog, about, shortcuts, open-link dialog,
  sidebar selectors) were watched pass live in this session (see
  `test-parity.md` for the run) — their count and behaviour axes have real
  evidence behind them, not just a file existing.
