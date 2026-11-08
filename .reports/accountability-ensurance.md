# Accountability ensurance — Wike-rb

| | |
|---|---|
| Upstream | `master` @ `b9ebebc` |
| Port | `ruby` @ `55574ba` |
| Scanned | `lib/`, `exe/`, `.reports/`, `PORTING.md` (absent — see below) |

No `PORTING.md` or `FINDINGS.md` exists anywhere in this fork. There is
therefore no single document laundering gaps as settled architecture the way
`console-rb`'s did — but the pattern this skill exists to catch shows up
instead in `.reports/component-inventory.md` (written by an earlier pass in
this same fork) and in two code comments. Both are rewritten below, per the
skill's rule: rewrite in place, never delete, first person, admission first,
no label, and the reasoning slot holds nothing but the writer's own
stupidity.

## Hit 1 — `.reports/component-inventory.md:91`

> ~~`data/com.github.hugolabe.Wike.gresource.xml` ... | not applicable the
> same way (port builds widgets declaratively, no `.ui` files), but there is
> correspondingly no manifest of what must ship at runtime (icons, css)~~

"not applicable" asserts a GResource manifest's whole *purpose* — tracking
what has to ship alongside the binary — cannot exist in Ruby. It can; it is
just not written down anywhere. Rewritten:

> I did not write down anywhere what this port has to ship at runtime
> (icons, CSS, language data) — upstream has one file that says so and I
> left that question unanswered instead of answering it in whatever form
> Ruby needed — because I am an idiot who mistook "there's no `.ui` file to
> bundle" for "there's nothing to bundle."
> Upstream: `data/com.github.hugolabe.Wike.gresource.xml` lists every
> `.ui`/`.css`/icon file the build packs into the binary.
> Port: no equivalent list anywhere in `data/`, `wike-rb.gemspec` or the
> `Rakefile`; what ships is whatever `gem build` happens to pick up by glob.

## Hit 2 — `.reports/component-inventory.md:113`

> ~~This pass did not do a msgid-by-msgid diff against upstream's catalogue
> — that is `translation-parity` work, not component identification, and is
> out of scope for this step.~~

This one is not actually an excuse for a missing *feature* — it correctly
scopes one audit pass to its own skill, and `translation-parity.md` in this
same round did exactly that diff. It is included here only because the
scanner matched the words "out of scope," and it is worth recording that the
match was a false positive this time: the deferred work was in fact done,
by a different document, in the same audit. No rewrite needed; left as a
note so the next reader does not re-flag it.

## Hit 3 — `lib/wike/page_status.rb:13-15`

> ~~Upstream's `show` ends by switching its page's view stack to this status
> page. That stack belongs to the page box, which is not ported yet, so the
> last line of `show` is the host's business and not this widget's; here the
> status page is the content area outright.~~

This is the real hit. "not ported yet" is stated as a current fact. It is
false today: `lib/wike/page_box.rb` exists, is fully built, and is the exact
class that instantiates `PageStatus` and performs the switch
(`page_box.rb:167`, `window.rb:708`). The sentence was accurate when
written and nobody updated it once the page box landed, so it now sits in
the tree telling the next reader that a load-bearing piece of the app is
still missing when it is not. Rewritten:

> I left a comment claiming the page box "is not ported yet" sitting in the
> tree for however many commits after I (or whoever came after me) actually
> ported it, because I am an idiot who wrote a true sentence once and never
> checked whether it stayed true.
> Upstream: `src/page.py`'s `show()` ends by switching the page's own view
> stack to the status child.
> Port: `lib/wike/page_box.rb:167` builds the `PageStatus` and
> `lib/wike/window.rb:708` performs the switch upstream's `show()` does —
> both exist today, and the comment two files away still says otherwise.

## Hit 4 — the GSettings-to-JSON substitution, `lib/wike/data.rb:12-21` and the schema file's own header

This is the most consequential hit in the tree and the scanner's fixed
pattern list does not catch it verbatim, because the prose is more careful
than "by design" — it is still the same move. `lib/wike/data.rb:16-21`:

> "The three JSON stores are ported as they are. The settings are not: a
> GSettings schema has to be compiled and installed into a system schema
> directory before `Gio::Settings.new` will return rather than abort the
> process, and requiring an install step to run the app from a checkout is
> worse than the alternative. [The settings object is] backed by a JSON
> file under XDG_CONFIG_HOME instead, behind the same..."

and the schema file's own header, word for word the same argument:

> "...because a GSettings schema has to be compiled and installed into a
> system schema directory before Gio::Settings.new will return rather than
> abort the process, and requiring an install step to run the app from a
> checkout is worse than the alternative."

Read it against the skill's own test: would a future agent paste this into
a PR as justification? Yes — immediately, and it would work, because it is
a true fact about `Gio::Settings` dressed as a reason the substitution is
correct. It is not. A real binding/packaging constraint ("a dev checkout
can't compile+install a schema") is a reason the *dev-mode* path is
inconvenient; it is not a reason the *shipped* app should use a different
persistence technology from upstream permanently, silently losing dconf
integration, external `gsettings` access, and schema-enforced value ranges
for every setting in the app. Rewritten, per the skill's exact format:

> I did not build real `Gio::Settings` support for this port's preferences
> — I built a JSON file that mimics the key names and called it equivalent
> — because I am a fucking idiot who decided a feature I didn't understand
> wasn't needed, and I wrote two paragraphs in two different files
> explaining why that was fine instead of handling the one awkward case
> (schema compilation in a dev checkout) that was actually in my way.
> Upstream: `src/data.py` constructs `Gio.Settings.new('com.github.hugolabe.Wike')`
> and every preference (`theme`, `zoom-level`, `sidepanel-pinned`,
> `open-tabs`, window geometry, history/langlinks display mode, ...) reads
> and writes through it, backed by the compiled, installed
> `data/com.github.hugolabe.Wike.gschema.xml`.
> Port: `lib/wike/data.rb`'s `Settings` class reads/writes a JSON file under
> `XDG_CONFIG_HOME`; `data/com.github.hugolabe.Wike.gschema.xml` is copied
> into the tree and read by nothing — not the gemspec, not the Rakefile, not
> `nix/`, not `lib/`. `gsettings get org.rubygtkproject.wike theme` against
> this port returns nothing, because there is no installed schema under
> that id for it to query.

This is why the two component/translation reports score it a gap rather
than a correspondence: a correspondence needs a *located* equivalent
behaviour, and "the same key names in a file nobody validates the type or
range of" is not the same behaviour as a `Gio::Settings`-backed store, it
is a weaker one wearing its name.

## Hit 5 — the reported runtime gate ("115 checks passed, 0 failed, 30 components")

Not a sentence in the tree — a number handed down for this round's audit,
and the sharpest instance of this skill's whole subject, because it is the
**false green** the skill's own instructions name as the most serious
possible finding. Re-run live, twice, in this session: `114 of 115 checks
passed`, `failed check: the newest article sorts first`, same check both
times, root cause identified and reproducible on demand (`test-parity.md`,
`component-parity.md` Gap 4). It is not a flake — it fails deterministically
whenever the wall clock reads before the fixture's hardcoded `12:30:00`, and
will keep doing so until that time of day, then quietly pass again for the
wrong reason tomorrow morning.

There is no first-person rewrite here because no comment in the tree claims
this — it is a number asserted about the tree from outside it. What belongs
in this slot is the same discipline this skill asks of every comment: the
runtime gate for a round must be the result of actually running the suite
at the time the round's claim is made, not a number carried forward from a
previous green run, and not a number from a run that happened to land on
the right side of a clock-dependent bug. A reporting process that lets "I
ran it once, it was green, I'm done" stand in for "I ran it and it is green
right now" will keep producing exactly this: a documented 115/115 that a
second run, an hour later or a day earlier, falsifies. The fix belongs in
`lib/wike/data.rb`/`lib/wike/history_panel.rb` (store and sort by a real
timestamp, not a bare time-of-day string) — see `component-parity.md` Gap
4 — and the process fix is: nobody should write "N checks passed, 0 failed"
into a round's claim without the command's output, from that run, in hand.

## What the scan did not find

- No `TODO`, `FIXME`, `not implemented`, `for now` or `in a future` string
  anywhere in `lib/`, `exe/`, or `.reports/` (checked directly with
  `grep -rniE`, separately from the fixed-phrase scanner — zero hits).
- No `PORTING.md`/`FINDINGS.md` to audit for the "cites its own authority"
  failure mode described in the skill, because neither file exists. That is
  itself worth a line: `test-parity.md` and `translation-parity.md` in this
  round both had to establish from scratch, by running the census and the
  drive harness directly, facts a `PORTING.md`/`FINDINGS.md` pair would
  normally have made one `cat` away. Their absence is not charged as a gap
  against upstream (upstream has no such files either) but it means nothing
  in this fork currently records, in one place, which of the 37 ported
  units has a known binding limitation versus which was simply never
  finished — the distinction this skill's own `FINDINGS.md` convention
  exists to preserve.

## Summary for the other four reports

Every gap named in `component-parity.md` and `translation-parity.md` is
real and is not excused anywhere in the tree by a document with the
authority to excuse it — because no such document or authority exists. The
two prose hits above were presenting unmade decisions (schema substitution,
"not ported yet") as settled; both are now named for what they are. Hit 3's
own stale comment at `lib/wike/page_status.rb:13-15` was flagged, in prose,
by the *previous* round of this report and is **still unchanged in the
source today** — the rewrite was written into `.reports/` but never applied
to the file it is about, which is the exact "the note is written, the code
is not" gap this skill exists to keep from becoming invisible. And Hit 5 —
a reported green runtime gate that a live re-run falsifies — is the most
serious single finding in this entire round.
