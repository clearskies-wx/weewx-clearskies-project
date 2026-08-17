---
status: Accepted
date: 2026-08-11
deciders: shane
supersedes:
superseded-by:
---

# ADR-107: Wind provider decoupling + assembly (wind gatherer, single assembled timeline)

**Status: Accepted 2026-08-15 (operator, in chat: "yes adr107 is approved"). Drafted 2026-08-11 by
the Z3.5 implementer per the fixit plan's Z3 re-scope note ("lifting the design into
ADR/PROVIDER-MANUAL as the doc-sync this ruling never got"); it sat Proposed and untracked until the
2026-08-15 ADR impact sweep prep surfaced it (Marine Model Evolution Plan, carry-over C20). Records
the design the operator approved verbatim 2026-08-03, as built and running live.**

## Context

The design this ADR records was fully approved by the operator in chat on 2026-08-03 (decision item
9 of `docs/planning/briefs/AUDIT-OPUS-WINDOW-2026-08-03.md`) and written up in full in
`docs/planning/briefs/WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md` ("the design brief") — but the
approval never became an ADR at the time, so `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md`'s
Z1 diagnosis and its PA6 pre-approval register both treated the underlying question ("how should the
marine service gather wind?") as still open, three days after it had already been ruled on twice. The
plan's Z3 re-scope note (2026-08-10) names this gap explicitly and assigns its closure — lifting the
design into an ADR — to this round (Z3, migration step 5). This ADR is that lift: it restates the
approved design as a decision record, with no new ruling of its own. Evidence, full narrative, and
the five-step migration order are in the design brief; this ADR summarizes the shape and cites it as
the source of record.

**Operator ruling, verbatim (2026-08-03):** *"You need to decouple the HRRR gathering from the
runs… This is an external API provider just like any other and needs treated as such. It should have
its own independent timings, not be tied into the surf system, especially if that information may be
used by other portions of the marine service. Second, if we have to assemble our information, then
we need a mechanism to do that. Third… We need to cut back our hourly runs to 12 hours."* Read-back
confirmed: per-hour freshest-available assembly; 12h fast cycle ("half a day"); full runs trigger on
extended-cycle-assembled-complete.

**The defect this design closes:** before this design, `_marine_runner_loop()` (service.py) fetched
HRRR/GFS inline, at run-trigger time, and ran SWAN on whatever hours the fetch happened to return —
NOAA posts an extended cycle's forecast-hour files over roughly 60-90 minutes, not atomically, and
nothing checked completeness before accepting a fetch as done. A live journal survey (2026-08-03)
found every extended-cycle first fetch partial (7-31 of 49 grids). The mid-forecast hole this produced
is `docs/planning/briefs/V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md`'s subject.

## Decision

**1. The wind gatherer** — one new background component inside the existing marine service process:
an independent `asyncio` task with its own scheduler, started at service startup, never invoked by
(and never invoking) the SWAN run path. Detects new HRRR cycles (hourly f00-f18 every hour; extended
f00-f48 at 00/06/12/18Z) and GFS far-window cycles (f048-f084, 3-hourly; Z3.6 2026-08-12); fetches incrementally
("top-up" — only forecast hours not yet held for a cycle), respecting NOMADS pacing; tracks per-cycle
completeness; maintains the assembled store and emits `hourly_cycle_assembled` /
`extended_cycle_assembled` events. Considered and rejected: a separate systemd service — it maximizes
"treated like an external provider" but adds a deployment unit and a second failure domain for a
gatherer whose consumers all live in the marine process anyway.

**2. The store — ONE assembled wind timeline, updated in place.** *(Revised 2026-08-03 per operator
review: "we need to be keeping one fully assembled set, why are we keeping individual fragments?" —
the original per-cycle-fragment design was dropped before build.)* File-backed under the marine
service's run directory: `wind_timeline.json(.gz)` — one record per forecast hour over the working
window (now → +72h), each carrying grid data + per-hour provenance; a fresher cycle's hour replaces
the existing one in place, no fragment retention. `incoming.json` — completeness tracker for the
cycle currently being assembled only. Read API: `get_wind_series(t0, t1)` (uniform-hourly, refuses
with a named reason on any gap) and the regime-aware `get_wind_records(t0, t1)` (native-cadence per
regime, for the run triggers below); `get_status()` for `/health`.

**3. Consumers — all read-only against the store, all switched over across migration steps 2-5:**

| Consumer | Before | After |
|---|---|---|
| Full 48h SWAN run | fetched inline at trigger time; ran on partial fetches | triggered BY `extended_cycle_assembled`; reads a complete assembled 0-72h series |
| Hourly fast cycle | 24h scope; trigger unreachable in production | REAL hourly trigger on `hourly_cycle_assembled`; **12 forecast hours** ("half a day") |
| Surf-card display wind | request-time fetch + publish-time warming thread | store PRIMARY per hour via `get_present_hours()` (tolerant, never refuses); run-forced `wind_for_display` PERMANENT fallback for hours the store cannot cover — Q3 amendment below |
| GFS far window | separate fetch, same partial-success defect class | gatherer-owned on the same manifest pattern |

**4. Deletions (migration step 5, no dead code left behind):** `hrrr.py`'s/`gfs.py`'s request-time
fetch orchestration from consumer paths (the fetch machinery itself is reused by the gatherer, and
`run_all_spots()`'s/`run_quick_update()`'s own inline-fetch fallbacks stay live for the manual
trigger and tests); the run loop's inline HRRR/GFS fetch, cycle-cadence classification, and
cycle-change bookkeeping in their entirety; the H5 publish-time warming thread (removed earlier,
2026-08-02, confirmed pre-satisfied at this step). The pipeline-persisted `wind_for_display` field
was originally scoped for deletion here too — **reversed, see "Amendment (Q3 ruling, 2026-08-11)"
below.**

**5. Migration order** (each step separately deployed + reality-gated): (1) gatherer + store land
dormant; (2) display wind switches to the store; (3) full run switches to the
`extended_cycle_assembled` trigger + store reads + a gap-refusal invariant; (4) fast cycle (12h)
switches on — the first time this path ever ran in production; (5) deletions + this doc-sync.

## Amendment (Q3 ruling, 2026-08-11)

The original step-5 design (Decision §4 above) deleted `wind_for_display` — the pipeline-persisted,
run-forced spot-pin wind field — treating the Z3.2-shipped fallback as a temporary transition rung
between the old request-time fetch and a store read expected to eventually cover the whole served
timeline on its own.

**Production evidence surfaced the mechanism was built wrong, not merely incomplete.** Post-restart
production monitoring (2026-08-11, `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` "Z3.5
STATUS") found the store-primary display-wind read failing on EVERY served request — 16/16 requests
logged a fallback. Mechanism: the store is self-bounding by design (§2 above) — `age_out()` deletes
every hour behind wall-clock now, and it holds the +48-72h window only at GFS-native 3-hourly
cadence — while the surf endpoint's served forecast timeline starts at the run's own cycle start
(already in the past by the time of any request) and extends past +48h. A whole-timeline,
refuse-on-gap read against a store that cannot, by construction, hold that whole range can
essentially never fully succeed. Deleting the fallback as originally scoped would have blanked the
forecast wind display.

**Operator ruling (2026-08-11, verbatim):** *"Q3 that is fine, I do not understand why that is even a
question? It is apparent you built the mechanism wrong, and need to fix it."* Classified as a DEFECT
FIX, not a new design choice (`docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md`, "Q3 — ✅
ANSWERED").

**Corrected, permanent design:** the store is PRIMARY for every hour it actually holds, read via
`wind_timeline_store.get_present_hours()` — a tolerant sibling of `get_wind_series()` that returns
whatever hours are present instead of refusing on a gap. `wind_for_display` — unchanged from its
pre-round build and cache-key handling — permanently serves every hour the store does not cover:
aged-out past hours, 3-hourly far-window off-slot hours, and any store-absent/cold hour. Both
sources absent for an hour → null, never a fabricated value. The single WARNING that used to fire per
request on any partial store coverage is replaced by one WARNING that fires only when the store
returns zero hours in range while the gatherer is enabled (store dead/cold — genuinely anomalous);
partial coverage is now the designed steady state, not an anomaly.

**Scope of the amendment:** ONLY `wind_for_display`'s deletion (Decision §4) and the "After" cell for
surf-card display wind (Decision §3 table) are reversed. Every other migration-step-5 deletion — the
run loop's inline HRRR/GFS fetch, cycle-cadence classification, and cycle-change bookkeeping; the H5
warming thread; the full-run and fast-cycle event-driven-only triggers — proceeds exactly as
originally decided and is unaffected by this amendment. This ADR remains status **Proposed**; this
amendment does not itself constitute operator acceptance of the ADR as a whole.

## Consequences

- Wind is gathered on its own schedule, independent of SWAN run cadence, satisfying the "own
  independent timings" ruling.
- A SWAN run can no longer read a partial fetch — the store's refuse-on-gap contract makes a
  structurally short forecast unreachable, closing the defect class Z1 diagnosed.
- The wind gatherer is the sole ROUTINE NOMADS caller for wind as of migration step 5;
  `hrrr.py`'s/`gfs.py`'s own inline-fetch fallbacks remain reachable only via the manual trigger and
  tests.
- `GET /health`'s `inputs.wind` freshness signal moved from the (now-deleted) run-loop inline fetch
  to the store-driven run functions themselves, recorded immediately after their own store read.
- The 12h fast-cycle scope is an operator-ruled reduction from the prior 24h inline-fetch scope,
  authorized by the same 2026-08-03 chat ruling ("cut back our hourly runs to 12 hours").

## Trigger classification (for the record, design brief §6)

Trigger 2 (new component + responsibilities move), 5 (fetch lifecycle moves), 6 (new schedules; run
triggers change), 7 (new persisted store files). All authorized by the 2026-08-03 operator ruling.

## References

- `docs/planning/briefs/WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md` — full design, source of
  record for every detail summarized above.
- `docs/planning/briefs/AUDIT-OPUS-WINDOW-2026-08-03.md` — decision item 9, the original operator
  ruling.
- `docs/planning/briefs/V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md` — the defect this design closes.
- `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` — Z3 re-scope note, migration steps 2-5 as
  tracked tasks.
- `docs/manuals/PROVIDER-MANUAL.md` §14.14/§14.15 and ARCHITECTURE.md's "Wind gatherer" section —
  target-state documentation, updated in the same commit as this draft.

## Amendment (Z3.6 runnability fixes, 2026-08-12)

The first production trigger of the event-driven full run (00Z cycle, fired 01:50:43Z) refused and
exposed three build errors that made the designed trigger structurally unsatisfiable; the operator
ruled them defects ("fix it") and Z3.6 (marine `acdfa0c` + hotfix `ed1f26d`) corrected them:

1. **Store retention floor.** `age_out()` deleted every hour behind wall-clock now — including the
   assembling extended cycle's own first hours, destroyed 47 minutes before assembly even
   completed. The floor is now `min(now, the hrrr_extended track's own cycle_time)`; the
   "self-bounding, no retention policy" wording in §2 is amended accordingly (bound ≈ +8 h worst
   case, the extended cycle replaces every 6 h).
2. **GFS fetch depth.** f048–f072 measured from GFS's *own* cycle can never reach the HRRR
   cycle + 72 h far edge, because GFS structurally lags the HRRR extended cycle by ≥ one 6 h step.
   The gatherer now fetches f048–f084 (13 grids); `gfs.py` defaults and the inline manual-trigger
   path are unchanged.
3. **Trigger retry.** The pending `extended_cycle_assembled` signal was consumed before the run
   executed, so a refusal swallowed it until the next cycle (≥6 h). It is now peeked, cleared only
   on success (equality-guarded so a newer mid-run arrival is never lost), retried every runner
   tick otherwise, and cleared-without-dispatch when its run marker shows the cycle already
   completed (forced-path race). A pending cycle superseded before running logs one INFO.

Rider (same date): the fast-cycle merge persist carried the last full run's `saved_at` stamp
forward, so the disk cache's >12 h staleness check refused a file whose newest content was minutes
old — a service restart during a long full-run outage came up cold (6-minute empty-forecast
outage, 04:58–05:04Z). The merge persist now stamps `saved_at = now` (`ed1f26d`).

## Amendment (Z3.7 far-window geometry homogenization — option 2, operator ruling 2026-08-12)

Z3.6 made the trigger fire; the run then crashed at the wind stitch on every cycle
(`IndexError`, `swan_runner.py` `_stitch_wind()`, first hit 10:49:48Z). Root cause: this ADR's
store keeps ONE record per hour ("best source wins"), and the HRRR-extended and GFS batches for
the same forecast cycle carry the same `cycle_time` label with HRRR assembling first — so the
boundary hour (cycle+48 h) is always HRRR-sourced (65×60 grid) and GFS's own f048 copy is always
discarded. `get_wind_records()`'s original docstring promised the boundary hour "in both regimes"
reproducing the legacy fetch shape; the one-record-per-hour design cannot honor that promise.
`_stitch_wind()` interpolates the far-window pair (48 h→51 h) elementwise assuming one geometry,
and crashed on the 65×60-vs-6×7 mix.

**Operator ruling (in chat, 2026-08-12): option 2** — at store-read time, in the run adapter
(`run_full_swan_cycle_from_store()` only), any far-window grid whose geometry differs from the
GFS target geometry is resampled onto the GFS grid using the existing canonical sampler
(`swan_formats._bilinear_interp()`), with nearest-edge clamping for the GFS box's ≤0.061°
overhang past the HRRR box. In production this means the h49–50 interpolation anchors on
HRRR's own hour-48 state (resampled to 6×7) instead of legacy GFS f048 — a deliberate,
approved change of those two hours' interpolation inputs (smoother handoff: the model is
HRRR-forced through hour 48). The resampled anchor remains pure scaffolding — never emitted as
a forced hour. Rejected alternatives: option 1 (store keeps both sources at overlap hours —
schema change, bit-identical legacy reproduction) and option 3 (GFS wins ≥48 h in the merge —
moves the same crash into the near window). Store schema, gatherer merge rule, and
`_stitch_wind()` itself are unchanged.

## Amendment (2026-08-17): WW3 leg becomes a second consumer of the assembled wind store — ADR-109

**Status: Accepted.** Recorded by the DOC-W.5 full-index ADR impact sweep
(`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, Phase DOC-W, task DOC-W.5), following
acceptance of **ADR-109** ("WW3 deep-water leg"). Pointer + amendment only — no prior ruling above
(D1–D5, the Q3/Z3.6/Z3.7 amendments) is re-opened.

**What changes.** This ADR's assembled wind timeline store (§2, "the store — ONE assembled wind
timeline, updated in place") gains a second consumer beyond the existing SWAN full-run/fast-cycle/
display-wind readers already listed in the Decision §3 table: **ADR-109's WW3 deep-water leg**
(wind-only forcing, D9; the `ww3_prep` preprocessor path, D7). Per ADR-109 D9/D12, the WW3 leg reads
the store on the same full-run (6-hourly) cadence the live SWAN-L1 path already reads it on —
**current cycles only**; the WW3 leg does not read archived/past cycles from this store (that
archived-cycle need, if any, belongs to F0/F2's own Phase-F scratch tooling, not this store's
production contract, per the plan's DOC-W.5 provisional table).

**What does not change.** This is a read-only addition: the store's file format, retention, schema,
gatherer merge rule, `get_wind_series()`/`get_wind_records()`/`get_present_hours()` read APIs, and
every existing consumer's behavior (full-run trigger, fast-cycle trigger, display wind's PRIMARY/
fallback split per the Q3 amendment) are unchanged by this amendment. The WW3 leg's own wind
regrid/re-emit step onto its own grid (ADR-109 D9, F5-CATALOG Gap G7 — "production wind-store→WW3-
grid regrid/re-emit step is unbuilt") is separately-built Phase W work (W4/W5), not a change to this
store.
