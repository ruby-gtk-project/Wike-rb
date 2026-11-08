# Translation parity — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` |
| Port | `ruby` @ `55574ba` |
| Domain | `wike` (matches; `domain_matches: true`) |
| Upstream messages | 178 |
| Ported | 28 |
| Gaps | 150 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 216 across 178 messages (29 reused) |
| Port occurrences | 30 |
| Upstream languages | 39 `.po` files, 5,298 translated, 490 untranslated, 37 fuzzy |
| Languages shipped by the port | 39 (file set matches, `languages_missing: []`) |
| Generated artifacts | `/tmp/wike-parity/up.yaml`, `/tmp/wike-parity/port.yaml`, `/tmp/wike-parity/compare.yaml` (not committed — regenerate with `.claude/skills/translation-parity/scripts/catalogue.rb`) |

`summary.parity: false` (`ported: 28, gaps: 150, extra: 0, kind_mismatch: 0,
uses_mismatch: 1, languages_missing: [], domain_matches: true`).

**178/178 messages, port has 28 — 150 gaps, 84% of upstream's catalogue
missing.**

## The headline finding: every one of the 28 "ported" messages is dead

Reading `port.yaml`'s `messages:` list (not just its count) shows all 28
come from exactly three files: `data/com.github.hugolabe.Wike.gschema.xml`,
`data/com.github.hugolabe.Wike.desktop.in` and
`data/com.github.hugolabe.Wike.metainfo.xml.in`. **Zero** come from any
`lib/wike/*.rb` file.

That matters because of what `component-parity.md` (Gap 1) already
established: the gschema file those 28 messages live in is not compiled,
not installed, and not read by anything in this tree — `lib/wike/data.rb`
backs the same settings with a hand-rolled JSON store instead. So the 28
messages the catalogue counts as "ported" are translatable strings sitting
in a file nothing loads at runtime. They cannot reach a user in any
language, including English-as-shown, because the file they are in is
inert.

```
$ grep -rn "require ['\"]gettext" lib/     # → nothing
$ grep -c "_(\|N_(\|n_(" lib/wike/*.rb     # → every file: 0
```

**No file under `lib/` requires `gettext`, and no file under `lib/`
contains a single `_()`, `N_()` or `n_()` call.** Every user-visible string
in every dialog, menu, button, label, tooltip and status message across all
37 ported widget files is a hardcoded English literal. `po/*.po` (39
languages, copied byte-for-byte from upstream, correctly) is a complete,
accurate set of translations for an application that does not call into it
anywhere.

So the real number, measuring what a user actually sees, is **0 of the
~150 UI-facing messages translated, in 0 of 39 shipped languages** — not
28/178. The 28 that the mechanical census counts are real upstream msgids
that happen to sit in a copied-but-unused XML file.

## Numbers, reported as pairs

```
28/178 messages (catalogue count, inflated by 28 dead-file messages — see above)
 0/178 messages reachable at runtime, by the same evidence
30/216 occurrences
39/39 languages shipped (file set)
5,298 translated strings exist upstream, reachable by 0 of them
de (or any other) verified on screen: NOT RUN — no gettext call exists in
  lib/ to bind a locale to, so there is nothing for a locale-switch smoke
  test to exercise. This is not a check that was skipped for convenience;
  it is a check with no target.
```

## Per-group detail (upstream source → port)

| Upstream source | Messages | In port? |
|---|---:|---|
| `src/*.py` (all application/dialog/widget code) | ~150 | **0** — no `_()`/`N_()`/`n_()` anywhere in `lib/wike/*.rb` |
| `data/*.gschema.xml` | 17 | present, in the copied-but-inert schema file |
| `data/*.desktop.in` | 3 | present, in the port's `.desktop.in` |
| `data/*.metainfo.xml.in` | ~8 | present, in the port's `metainfo.xml.in` |

The 150-message row is where every gap lives. A representative sample
(msgid, upstream file) that has no counterpart anywhere in `lib/`:

- `Open Random Article` (`src/menu.py` / `data/gtk/menu-main.ui`)
- `Search Wikipedia` (`src/page.py` — also the exact string the port's own
  `page_status.rb` hardcodes as `'Search Wikipedia'`, see below)
- `Can't Access Wikipedia` (`src/page.py`)
- `_Remove`, `_Rename List…`, `_New List…`, `Clear List` (`src/bookmarks.py`)
- `Clear History`, `Select All`, `Select None` (`src/history.py`)
- the four shortcuts-window section titles and every shortcut label
  (`data/gtk/shortcuts-dialog.ui`)
- the About dialog's translator-credits marker and description
  (`src/window.py`)

## The unmarked-literal pattern, confirmed directly

`test-parity.md`'s drive run asserts against hardcoded English, which is
itself proof the port's strings are unmarked rather than just unmarked in
the census:

```ruby
# test/drive_main_window.rb:541
d.check('blank state invites a search') { status.status_page.title == 'Search Wikipedia' }
# test/drive_main_window.rb:554
d.check(...) { status.status_page.title == 'Can't Access Wikipedia' }
```

`lib/wike/page_status.rb` builds these as plain Ruby string literals, not
through any translation marker — matching upstream's wording exactly (good
for a future fix: the msgids are already byte-identical, they are just not
behind `_()`), but with zero connection to the catalogue upstream ships for
either string today.

## What is not a gap

- The domain matches (`wike`), so when/if gettext is wired in, the existing
  `po/*.mo` build would resolve under the name the port already uses.
- The language *set* was copied completely and correctly: 39/39 `.po` files,
  `LINGUAS` matches the file list, no missing or extra language.
- No kind mismatches (plural/singular) and no msgid was found reworded —
  the few strings that do coincide (6 in `component-inventory.md`'s earlier
  spot-check: `Home`, `Mobile`, `Work`, etc., plus the two `page_status.rb`
  strings above) are byte-identical to upstream's, they are simply not
  marked.

## Required fix, in order (per the skill's own discipline)

1. Add the `gettext` gem, `require 'gettext'`/`include GetText` (or the
   equivalent the house style elsewhere in this org uses), and
   `bindtextdomain('wike', ...)` at startup.
2. Wrap every user-visible literal across all 37 `lib/wike/*.rb` files in
   `_()`/`n_()`/`N_()`, using upstream's exact English as the msgid — most
   of it, per the spot-check above, needs no rewording, only marking.
3. Decide what to do about the dead `data/*.gschema.xml`: either wire it in
   for real (compile + install + have `data.rb` actually use
   `Gio::Settings`, which also closes `component-parity.md` Gap 1) or stop
   shipping it, because right now it inflates this exact report's "ported"
   count with messages nobody will ever see translated.
4. Re-run `catalogue.rb --compare` and expect `ported` to climb from 28
   toward 178 only once real `_()` call sites exist in `lib/`.

None of this was done in the current tree. 150/178 is a gap count, not a
to-do list that has started.
