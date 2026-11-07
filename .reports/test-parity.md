# Test parity — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` |
| Port | `ruby` @ `79db2b8` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command run this session | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |

## Upstream has no test suite

Verified: `scripts/test-census.sh` against the `origin/master` worktree
returns zero rows, `find /tmp/wike-parity/up -iname '*test*'` finds nothing,
and there is no `tests/` directory, no `unittest`/`pytest` import, and no
test target in `src/meson.build` or the top-level `meson.build`. Parity is
**0/0 and is met trivially.** The port therefore inherits no safety net from
upstream — every check below was written for the port and pins nothing
upstream considered worth pinning down.

## The port's own suite — run this session, not assumed

```
$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
...
115 of 115 checks passed
DRIVE OK
```

This is a real execution, performed in this audit, inside the fork's own dev
shell and under `xvfb-run` as instructed, not a re-statement of the gate
number handed down. The 115 checks span 69 `step`s covering roughly 20
components: window/new-tab keypress, table of contents, language links
(user/all filter), bookmarks panel (default list, named lists, add, select
mode, select-all/none, remove, rename/create/clear-list dialogs), history
panel (add, select mode, remove, clear, empty-state placeholder), search
settings popover, zoom control, theme switcher, main menu popover, article
menu popover, in-article search bar, the three-state status page, the shell
search provider (fallback result, too-short query, language-prefix
stripping), a second tab opening/closing, preferences dialog, languages
dialog, about dialog, shortcuts dialog, the open-link validation dialog, and
the sidebar-closed selector state. All 115 passed; nothing was skipped,
caught-and-ignored, or asserted-true-unconditionally in what ran.

One non-fatal issue surfaced in this run that the pass/fail count does not
show: step `[60]`'s screenshot failed —
`shot 12-languages failed: RuntimeError: widget produced no render node (not realised yet?)`
— a `Gtk::Snapshot` timing issue around the languages dialog, caught by the
harness and logged rather than counted as a failure. It does not change
`115 of 115`, but a screenshot that cannot be taken of a dialog is itself a
small gap in what the harness can actually show a reviewer, flagged here
rather than silently absorbed into a green count.

`spec/` exists (`spec/spec_helper.rb`, `spec/README.md`) but **contains no
`*_spec.rb` file at all** — it is unused `kettle-jem` gem-template
scaffolding, not an app test suite, and running `rake coverage` or any
RSpec task against it would execute zero examples. It is not counted as a
gap against upstream (upstream has nothing to map to it either) but it is
worth naming plainly: the project's two conventional entry points for
"tests" (`spec/`, a would-be unit-test target) are empty, and the only suite
that exercises the app at all is the one hand-rolled driver script.

## Extra

- `test/drive_main_window.rb` (684 lines) + `test/gtk_driver.rb` (204 lines)
  — 115 checks across ~20 widget-tree components, driving the real GTK
  window under Xvfb with real keypresses (`xdotool`), real signal emission,
  and screenshot capture. This is the port's entire safety net; see
  `component-parity.md` for exactly which 20 units it reaches and which
  components (notably `lib/wike/wikipedia.rb`, the Wikipedia API client) it
  does not touch at all.

## What this ledger does not claim

0/0 upstream parity is not evidence the port is behaviourally sound — it
only means there is nothing from upstream to have dropped. The one
component this session found with **zero** executed checks anywhere in the
tree is `lib/wike/wikipedia.rb` (see `component-parity.md`, Gap 3): no test,
no drive step, no stub, calls `get_random`, `search` or `get_properties`.
Per the runtime-gate framing for this audit, an unexercised component is
unverified, not done, and it is reported as such rather than folded into the
"115 of 115 passed" headline.
