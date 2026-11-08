# Test parity — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` |
| Port | `ruby` @ `55574ba` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command run this session | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |
| Runtime gate claimed for this round | "115 checks passed, 0 failed, 30 components" — **does not hold**, see below |

## Upstream has no test suite

Verified: `scripts/test-census.sh` against the `origin/master` worktree
returns zero rows, `find /tmp/wike-parity/up -iname '*test*'` finds nothing,
and there is no `tests/` directory, no `unittest`/`pytest` import, and no
test target in `src/meson.build` or the top-level `meson.build`. Parity is
**0/0 and is met trivially.** The port therefore inherits no safety net from
upstream — every check below was written for the port and pins nothing
upstream considered worth pinning down.

## The port's own suite — run this session, not assumed, and it is RED right now

This round's runtime gate was handed down as "115 checks passed, 0 failed,
30 components." It was re-run live, twice, in this audit, inside the fork's
own dev shell and under `xvfb-run` as instructed — not re-stated from the
number handed down — and it does **not** reproduce:

```
$ date -u
Sun  8 Nov 00:10:24 UTC 2026
$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
...
[78] the new article shows under today, ahead of the seeded one
    ok   still one date heading, now two articles
  failed check: the newest article sorts first
...
114 of 115 checks passed
  failed check: the newest article sorts first
DRIVE FAILED (1)
```

Re-run a second time in the same session: identical failure, same check.
This is not test flakiness in the usual sense (a race, a timing window) — it
is a **deterministic, clock-dependent bug** that will keep failing right now
and will flip to a false pass later today:

- `test/drive_main_window.rb:52` seeds the history fixture with a
  hardcoded time-of-day, `"12:30:00"`, for the "GNOME" article.
- `test/drive_main_window.rb:375-380` then calls
  `app.window.history_panel.add_item('https://en.wikipedia.org/wiki/Matz', 'Matz', 'en')`
  to add a second article "right now," and asserts it sorts first because
  it is newer.
- `lib/wike/data.rb:195-196` stamps that new item with
  `Time.now.strftime('%H:%M:%S')` — the real wall-clock time of day, not a
  monotonic "added at" timestamp.
- `lib/wike/history_panel.rb:231` sorts a day's articles by that time-of-day
  string and reverses it, i.e. it assumes "later in the day" == "added more
  recently."

At the time this suite ran, the real clock read `00:10 UTC` — numerically
*before* `12:30`. So the newly-added "Matz" article (added second, at
`00:10`) sorts *after* the fixture's "GNOME" article (seeded at `12:30`),
and the check that asserts the new one sorts first fails. Run this same
suite any day between roughly 00:00 and 12:30 local-to-the-container time and
it fails identically; run it after 12:30 and it passes — not because
anything was fixed, but because the fixture's magic number happened to be
in the past for that run. **The gate is not a fixed 115/115; it is a
coin that depends on what time it is when someone runs it**, and whoever
reported "115 checks passed, 0 failed" for this round ran it on the "heads"
side of that coin, if they ran it at all.

This is the single most serious finding in this round's audit: a reported
green runtime gate that is provably false right now, reproducibly, for a
documented root cause — not a flake to shrug off and re-run until it's
green. See `accountability-ensurance.md` for why re-running until green and
reporting the green run would itself be a new instance of the failure this
whole audit exists to catch.

Underneath that specific failure, the 115 checks (now 114/115) span 69
`step`s covering roughly 20 components, not the 30 claimed for this round
— window/new-tab keypress, table of contents, language links (user/all
filter), bookmarks panel (default list, named lists, add, select mode,
select-all/none, remove, rename/create/clear-list dialogs), history panel
(add, select mode, remove, clear, empty-state placeholder), search settings
popover, zoom control, theme switcher, main menu popover, article menu
popover, in-article search bar, the three-state status page, the shell
search provider (fallback result, too-short query, language-prefix
stripping), a second tab opening/closing, preferences dialog, languages
dialog, about dialog, shortcuts dialog, the open-link validation dialog, and
the sidebar-closed selector state. Counting components generously (treating
each dialog, each panel state and each popover as its own line) does not
reach 30 without double-counting states of the same widget as separate
components; the round's "30 components" figure is not reproduced by reading
the suite and is not evidenced anywhere in the tree.

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
"115 of 115 passed" headline, which this round's live run does not even
reach — it got 114/115, reproducibly, for the clock-dependent reason above.
