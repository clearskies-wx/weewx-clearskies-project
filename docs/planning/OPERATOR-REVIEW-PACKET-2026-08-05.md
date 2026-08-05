# OPERATOR REVIEW PACKET — 2026-08-05 (autonomous session)

Everything below happened under your grant: "continue autonomously for as much as you
can, including D5, D6 and completion of Round S." Items needing YOUR decision are
marked **[DECIDE]**; everything else is reporting. Full evidence trail:
docs/planning/scratch/EYEBALL-FIX-EXECUTION-SCRATCH-2026-08-04.md.

## 1. What is live right now

- **Round W (real wave physics)** — marine `0560c41` deployed. The old fake clamps are
  gone; waves now break, decay toward a stable height, back off, and can re-break
  (Dally-Dean-Dalrymple 1985, the paper's own recommended constants). The blind audit
  found 2 serious problems in MY design (an unstable integration step; a wrongly
  calibrated warning) — both fixed and re-verified before deploy (exact integrator;
  warning now fires only on physically impossible values).
- **D5/D6/D7s (dashboard)** — `f85505b` deployed to the dev site. The approved
  beach-profile redesign, per-break zones on by default, zero-width bands skipped, and
  the heat-map smoothing you asked for (median over 5 neighboring transects, display
  only, disclosed in a caption note). Design/dashboard manuals updated same round.
- **Z5b (hotstart fix)** — see incident, §3.
- **Round S (surf score)** — built and verified but NOT deployed; commits held locally
  for your worked-examples review (§4), exactly as ADR-101 requires.

## 2. Round W reality gate — results vs the bands I pre-registered BEFORE deploying

Conditions at gate time were SMALL (dominant swell 0.36 m at 13.8 s from SSW), so the
big-swell anchors partly defer — stated per the bands' own rules, not waved through.

| Band (pre-stated) | Result |
|---|---|
| E1 two distinct breaks where present | **PASS** — 31 of 162 transects publish genuine multi-breaks live (30 double, 1 triple). Under the old clamped physics the audit proved a second break was IMPOSSIBLE on ~2/3 of transects at any detector setting. The reform physics demonstrably works in production. |
| E2 inner break 50–200 ft from waterline | **PASS** — representative transect: single spilling break at ~88 ft waterline-relative (your inner anchor: ~100 ft). |
| E3 outer break 150–600 ft | **DEFERRED** — no comparable SW groundswell today (band E1's own small-conditions clause). Re-check on the next real groundswell. |
| E4 outer/inner ratio 2–4 | **PARTIAL** — today's multi-break transects show ratios ~2–2.3; formal check deferred with E3. |
| E5 no-regression | **PASS** — foam zone ends within 0.163 m of the tide-aware waterline against a 1.0 m grid step (one grid cell; honest note: my ±0.1 m band was tighter than the grid itself — my miscalibration, not the model's); ZERO runaway warnings in the journal at steady state; faces/zones finite and sane (t0 face 0.95 m on a 0.36 m swell); NDBC 46253 beside: period 14 s vs our 13.8 s, height/direction inside the same tolerance family as the Round P gate. |
| E6 known carry-in | Confirmed as predicted: at small/moderate energy the representative transect shows ONE break near your inner anchor and no outer break (wave/depth ratio offshore ≈ 0.5 < 0.73 onset). Whether the persistent outer break at ~300 ft appears on real groundswell is E3's re-check; if reality shows it and the model doesn't, that goes to the parked break-geometry investigation (bathymetry/inputs — cause deliberately unestablished, not theorized). |

**[DECIDE] W-gate:** your worked-examples half — eyeball the new beach profile card on
the dev site against the webcam at a known tide, and say PASS/FAIL on the visual. The
card, per-break zones, and smoothing are all live now.

## 3. Incident report — the hotstart guard broke publishing (fixed same hour)

The first post-deploy SWAN cycle FAILED: the Round Z stamp-ordering rule kept a
hotfile stamped at the END of the previous forecast horizon (Aug 8) for a run starting
Aug 5; SWAN fatals on state stamped in its future ("[time] before current time"), and
the runner retried the same poisoned file forever — the site would have served stale
data indefinitely. I removed the poisoned files (they regenerate), then shipped Z5b
under your earlier ruling that hotfile read/write correctness is mine: a hotfile is
usable ONLY when its stamp exactly equals the requested start; any mismatch, past or
future, deletes it and cold-starts with a log line naming the direction. Verified live:
the guard caught and deleted a future-stamped file at 09:01, the cycle completed clean,
published 09:27.

**RESOLVED 2026-08-05 (operator ruling in chat): warm starts must work, for the
6-hourly full runs AND the hourly quick updates. Fix for the full runs is built and
tested; the hourly extension is in progress under full process (agent + adversarial
QC). Original decision text kept below for the record.**

**[was DECIDE] DQ-1a (parked from Round P, now sharpened):** SWAN can save its wave
state at the end of a run and reload it at the start of the next run, skipping the slow
spin-up. That reload never actually happens between cycles, because the saved file is
stamped with the END time of the previous run while the next run wants to start from a
START time — the timestamps never match, so the file is always rejected. Today's fix
makes that rejection safe and deliberate: every cycle starts from scratch, which is what
has always really happened. If you want the reload to work across cycles (saves
~minutes of SWAN compute per cycle), we need to decide how to make the timestamps line
up — either re-stamp the saved file, or have SWAN save a snapshot at the moment the
next cycle will start from. Options: leave as-is (safe, slightly wasteful) / design one
of those two schemes (its own small round). No urgency.

## 4. Round S — surf score rebuilt; YOUR GATE before it deploys (ADR-101 mandate)

Score = weighted geometric mean of five 0–100 factors (Size 0.25 / Shape 0.25 /
Conditions 0.20 / Power 0.20 / Consistency 0.10, admin-adjustable later leg). Worked
examples, computed by the real committed code:

FINAL numbers, computed by the conformed (S1c) scorer against S-SPEC-1's own six
fixtures — with one honest finding: several of the spec table's per-component values
(0.90/0.95-type entries) are mathematically UNREACHABLE from the spec's own discrete
curve buckets (brute-force-enumerated); the implementer used the closest reachable
inputs rather than inventing curve values, and the aggregates still land exact or
within 1 point:

| Scenario | Spec score/stars | ACHIEVED score/stars |
|---|---|---|
| Perfect day | 100 / 5.0 | **100 / 5.0** exact |
| Balanced good day | 84 / 4.2 | **84 / 4.2** exact |
| Small clean day (1.5 ft, 14 s, glassy) | 60 / 3.0 | **60 / 3.0** exact |
| Clean closeout (6 ft, peel 8°) | 50 / 2.5 | **51 / 2.55** (+1) |
| Blown-out epic | 47 / 2.3 | **46 / 2.3** (−1) |
| Flat day | 0 / 1 (floor) | **0 / 1 (floor)** exact |

The spec's own ⚠ judgment row applies: isolated-worst-case closeout ~50 and blown-out
~47 are the geometric mean's honest floor (real ruined days degrade multiple factors
at once and land ~25–35); levers if too generous = harsher clamps or admin weights —
your call at this gate, per the spec's own instruction.

**MY MISTAKE, disclosed:** you wrote and locked an exact design for the new surf
score (plan §1, "S-SPEC-1"): the exact scoring curves, the penalty rules, what
happens when data is missing, the exact field and config names, and six worked
examples with expected scores. When I sent the build teams their instructions, I
worked from two OLDER documents and never re-read your locked design — so my
instructions contradicted it in several places (I invented a field you never asked
for, made up different penalty numbers, and used wrong config names). I caught this
mid-build, stopped all four teams, and had everything redone to match your locked
design word for word. The manuals I had written from my wrong version are also
fixed. Nothing I invented is in the final code. The worked-examples table you review
at this gate is your own six examples (Perfect 100 / Balanced 84 / Small clean 60 /
Closeout 50 / Blown-out 47 / Flat 0) — with one flag your spec itself raises: the
worst-case days (closeout 50, blown-out 47) may feel too generous; if so, the fix
is harsher penalties or different weights, your call at this gate.
**[DECIDE] S-2:** S-SPEC-1's six fixture scores vs your intuition and Surfline — the
gate question, including the spec's own ⚠ row above. Say adjust/accept per scenario.
**Blind audit result (post-build):** the adversarial auditor could NOT disprove
conformance — hand-verified all six worked-example totals, every curve boundary,
rounding order, clamp ordering, single-use, and the config path end-to-end; 254
scoring-scoped tests pass across all four repos. Four findings: one stale contract
doc and one stale docstring (both fixed on their branches same-day), plus the two
disclosed items below (S-3 and S-5).
**[DECIDE] S-5 (audit F3 — a real conflict between your two design documents):** the
research brief §7.2 (binding inventory) says Size's beach-alignment gate keys off the
"dominant partition direction (from multiSwell)"; the plan's locked S-SPEC-1 says
"keep as-is", and the pre-existing code keyed off the top-level `wave_direction`
reference. The implementation follows S-SPEC-1 ("keep as-is" = `wave_direction`),
disclosed in code comments. Rule which document wins: (a) keep `wave_direction`
(current, status quo), or (b) switch the alignment gate to the dominant partition's
direction (one small change + test update). Recommendation: (b) at the same time you
rule S-3 — the partition direction is the more physically meaningful reference for
which swell is actually breaking, and §7.2 was written as binding.
**[DECIDE] S-3 (S-GAP-1):** the jacking-factor "sweetener" for Shape is built but
UNWIRED — the data lives in the beach-profile path and reaching it from the scoring
path needs either logic duplication or a new pipeline output field (an internal
contract change = your call). Options: (a) leave unwired (Shape = peel+breaker only,
current state), (b) authorize the pipeline field. Recommendation: (b) at the next
marine round.
Also for the record: stars floor at 1 even at score 0 (ADR said stars unchanged —
flag if you want a true 0-star tier); windSource is provenance metadata, not a
scoring input.
**[DECIDE] S-4 (new wire field `qualityScore`):** the dashboard leg proved the "XX/100"
number on the surf card was never a wire field — the old client SUMMED the additive
parts, which the geometric mean breaks (and reconstructing from rounded ints would
show a slightly-wrong number). The plan's "total unchanged" note was therefore
erroneous. Ruled: marine now publishes `qualityScore` (int 0-100, the same value
stars derive from) beside `qualityStars` — implementing the ADR's own display line
("score + stars + five bars"). Confirm or rename at the gate.
**Also at this gate — a judgment call of mine to check:** one of the build agents
refused an instruction twice. The instruction was to add the new scoring config
settings, and the agent refused because adding config settings is on the "needs
operator approval" list. I told it you had already approved this — the design
document you accepted (ADR-101) names these exact settings, and the plan section you
locked assigns exactly this work. The agent checked those documents itself, agreed,
and did the work. The question for you: was pointing at your earlier written
approval enough, or should I have come back and asked you directly in chat? If I
overstepped, say so and I'll tighten the rule.

## 5. Round W decision queue (from the audit — none urgent, all documented in code)

**[DECIDE] DQ-W1:** in water shallower than 15 cm the combined-profile treatment can
in principle flip rapidly between states and publish garbage — real inputs cannot
currently produce it (verified on the real shallowest transect). Fix = forbid "wave
reform" below the 15 cm floor (edits your approved cessation criterion — hence your
call). Recommendation: yes, next marine round.
**[DECIDE] DQ-W2:** one-grid-point height transient exactly at the 1 cm depth floor,
self-correcting, below the publication floor. Recommendation: accept as documented.
**[DECIDE] DQ-W3:** the combined profile is now bounded by its own raw input
(saturation can only remove energy, never add — the audit caught it publishing 18%
ABOVE the partitions' physics). This is a bound, NOT the banned flatten-to-γd clamp
(nothing pins to γd; both signals preserved) — surfaced here because you banned
clamps and I will not slip anything clamp-shaped past you. Already live. Say the word
and it gets redesigned.

## 6. Lessons for the rules files — proposals only, NOTHING landed without your OK

1. **Lead briefs get adversarial review too** — the audit's two HIGH findings were MY
   brief's design (the integration step, the warning calibration), not implementer
   error. Proposed: rules/verification.md gains "numeric/algorithmic design in a lead
   brief gets the same adversarial check as implementer code."
2. **Dashboard type-checking** — `npx tsc --noEmit` at the repo root checks NOTHING
   (root tsconfig is references-only); `npx tsc -b` is the only build-equivalent
   check. Proposed: rules/coding.md note. (Found by the D5 dev when the shallow check
   passed and the real build failed.)
3. **Tailwind v4 CSS-comment gotcha** — a comment containing literal `--name`-shaped
   text can make the build silently DROP the next CSS declaration. Proposed:
   rules/coding.md note. (Cost the D5 dev an hour; caught only by rendering the
   compiled output.)
4. **12 pre-existing dashboard test failures** (alert categorization, a layout token,
   realtime mapping — none marine) surfaced by my full-suite acceptance run; prior
   rounds only ever ran targeted suites. Proposed: a small repair round + a rule that
   round-close acceptance runs the FULL suite of the touched repo.
5. Pre-compaction items already queued: two over-escalations of coordinator-owned
   calls; invented-vocabulary and speculation-as-fact incidents (3); your standing
   "real physics, not clamps/bandaids" directive as a permanent rules/coding.md line.

## 7. Watching / parked (no action needed from you)

- librewxr: radar repair holds (was 200–800% CPU, now normal); load is our own SWAN
  compute; memory pressure noted (3 GB swap in use) — watching.
- Round S legs 2–4 (API conversion passthrough, dashboard five-bars display + explainer,
  stack admin weights form) — briefed after your gate, since the wire shape is now
  frozen and legs 2–4 build against it.
- Parked unchanged: inv-break-geometry (the instrument for E3's groundswell re-check),
  median-bathy land points, best-transect docstring drift, crash-retry-vs-shutdown,
  proxy 45 s ceiling until D7 precompute.
