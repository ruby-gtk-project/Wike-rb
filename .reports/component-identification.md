# Component identification — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` (hugolabe/Wike, Python/GTK4/Libadwaita; the fork has no `main` ref) |
| Port | `ruby` @ `55574ba` |

This supersedes/extends `.reports/component-inventory.md` (written earlier in
this fork's history, before commit `4137a32` added `data/*.gschema.xml`,
`*.desktop.in`, `*.metainfo.xml.in`). That file's widget/file mapping is
still accurate and is reused here rather than redone; this document adds what
it did not cover — the `data/` assets as they actually stand today, and
whether the things in `lib/` are wired to real system services or to
look-alikes.

## Widget/dialog/panel/row/menu inventory

Confirmed by re-reading every `lib/wike/*.rb` header against
`git ls-tree -r --name-only origin/master`: every upstream `src/*.py` class
(plus its `.ui` pair) maps to exactly one `lib/wike/*.rb` file carrying a
`# Ported from upstream's ...` header naming it. 37 files on the port side,
one upstream class/UI pair each. No missing widget class was found by this
pass. See `.reports/component-inventory.md` for the full file-by-file table.

## Non-widget components this pass adds

### 1. The settings store is not `Gio::Settings`

Upstream's `src/data.py` backs every preference (`zoom-level`, `theme`,
`last-uri`, `open-tabs`, window geometry, `sidepanel-pinned`, ...) with a real
`Gio.Settings` bound to the compiled `com.github.hugolabe.Wike` schema. The
port's `lib/wike/data.rb` backs the *same key names* with a hand-rolled JSON
file under `XDG_CONFIG_HOME`, and ships
`data/com.github.hugolabe.Wike.gschema.xml` as an inert copy that nothing in
the tree loads, installs or compiles. The file's own header and
`lib/wike/data.rb:12-21` both say so explicitly. This is a real component —
the app's whole settings subsystem — built with a different backing
technology than upstream, not a renamed file. See `component-parity.md` for
why this is a gap and `accountability-ensurance.md` for the comments that
present it as a justified substitution rather than one.

### 2. D-Bus activation for the main app

Upstream ships `data/com.github.hugolabe.Wike.service.in` (D-Bus service
activation for the main app, alongside `DBusActivatable=true` in its
`.desktop.in`). The port has neither: `data/com.github.hugolabe.Wike.desktop.in`
drops the `DBusActivatable=true` line, and there is no
`data/com.github.hugolabe.Wike.service.in` anywhere in the port's `data/`
directory (only the search-provider's `.service.in` was ported). This is the
mechanism the desktop activates the app through when it is not already
running and something addresses it by bus name (GNOME Shell search,
`gdbus call`, a session restore). Component-level gap, named here so
`component-parity.md` can score it.

### 3. The core Wikipedia API client has no exercised component boundary

`lib/wike/wikipedia.rb` (163 lines, `# Ported from upstream's src/wikipedia.py`)
is a real component: `get_random`, `search`, `get_properties`, plus the
private `endpoint`/`session`/`request`/`fetch`/`message_for`/`read_response`/
`parse` machinery that talks to the MediaWiki Action API over `Soup::Session`.
Nothing in `test/drive_main_window.rb` or anywhere else in the tree calls any
of its public methods, mocked or live. It is identified here as a component
with zero behavioural coverage; `test-parity.md` and the runtime-gate note in
`accountability-ensurance.md` carry the consequence.

### 4. A stale internal note

`lib/wike/page_status.rb:13-15` says: "That stack belongs to the page box,
which is not ported yet, so the last line of `show` is the host's business
and not this widget's." `lib/wike/page_box.rb` exists, is 250+ lines, and is
the thing that instantiates `PageStatus` (`page_box.rb:167`) and switches to
it. The comment is inaccurate today — the page box has been ported since
this comment was written — and left in place it reads as a current statement
of missing work. Flagged for `accountability-ensurance.md`.

## Scan artifacts

No `gir-symbols.sh`/`component-scan.sh` run against this app's GIR set was
needed beyond what `component-inventory.md` already established by direct
reading (one file ≈ one component, no `.ui`/`.blp` templates on either side
to scan — upstream is Python+`.ui`, not blueprint, and the port never has
`.ui` files by house style). The widget-type/CSS/signal axis comparison is in
`component-parity.md`.
