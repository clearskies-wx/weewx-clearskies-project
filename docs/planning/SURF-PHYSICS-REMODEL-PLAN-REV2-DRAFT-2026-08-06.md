# SURF PHYSICS REMODEL — REV2 DRAFT (2026-08-06) — AWAITING OPERATOR APPROVAL

**STATUS: DRAFT. Nothing in this document authorizes execution.** Rev1
(`SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md`) was approved 2026-08-05 and subsequently found to
contain a fatally stale premise (Round Y); the operator has placed the whole of Rev1 in doubt
(2026-08-06, in chat). This REV2 is the corrected plan, built exclusively on claims that survived
independent re-verification. **Format: a delta against Rev1** — where a Rev1 section is marked
CARRIED, its text remains normative unchanged; only the deltas and decision items below alter it.

**Provenance (every input lead-verified against code/live data, committed in
`docs/planning/scratch/`):** Y0-FACT-PIN, YQ-1-ENERGY-DEFICIT, X0-FACT-PIN, Z-PREMISE-AUDIT,
MEM-1-OOM-INVESTIGATION (all 2026-08-05/06).

## Reliability map of Rev1

| Rev1 section | Verdict | Basis |
|---|---|---|
| Root cause 1 (all-or-nothing breaking) | **VERIFIED** | X0 + Z-audit: hard trigger Hs > γ·d live at HEAD; statistical fraction dropped by Round W1 (`e048494`) |
| Root cause 2 (spectrum-collapsing boundary) | **DEAD — STALE** | Collapse site deleted 2026-07-26 (`5fe77af`); real multi-station 2-D spectral boundary live since; healthy-cycle energy chain shows ordinary shoaling, no ⅓ deficit (YQ-1); the ⅓ figure has no locatable measurement |
| Root cause 3 (selection/anchoring) | **VERIFIED** | Z-audit: all code anchors exact; 2.822 m shoreline depth reproduced bit-for-bit; "index 27" selection failure reproduced live |
| ROUND Y design | **REPLACED** by Round Y′ below | Premise dead; Tier 1 already exists; Tier 2/3 conflicts with the 2026-07-26 refuse-don't-degrade ruling (DECIDE D-3) |
| ROUND X design | **CARRIED + 2 corrections** | X0: every checked anchor held (incl. `apply_ddd_saturation` :615–749 exact, bar fixture 79.74 m vs stated 79.7 m) |
| ROUND Z design | **CARRIED + 2 corrections** | Z-audit: 0 stale, 0 contradicted claims |
| Decision register (6 operator rulings) | **CARRIED verbatim** | Operator's own words; independent of Rev1's factual errors |
| QC gate template + adversarial briefs | **CARRIED verbatim** (Y brief rewritten for Y′) | Process, not premises |
| Reality-gate tolerance rows | **CARRIED verbatim** | They test outcomes against buoy/webcam — premise-independent |

## Newly confirmed defects Rev1 did not know about

1. **OOM kill-loop (production outage, MEM-1):** librewxr's 6 GB LXC cap + a forecast cache
   grown 24 MB → 223 MB in 10 days, monolithically loaded at every startup
   (`providers/nearshore/swan.py:1482-1539`); service killed mid-run every ~7 min since
   2026-08-05 22:17Z.
2. **Silent whole-hour handoff collapse ("mechanism B", YQ-1):** on ~12% of hours in one clean
   cycle (0% on most healthy cycles; explodes during the OOM loop), the entire 162-transect set
   silently bulk-falls-back to one scalar wave; the trigger is an unlogged early-exit among three
   candidate `continue` points in `swan_runner.py:908-1011`. No log line, no health signal.

## DECIDE — operator items (nothing proceeds until each is ruled)

- **D-1 (OOM, precondition for everything):** (a) move aside the 223 MB
  `forecast_cache.json` + restart via deploy script (immediate relief, one forecast-gap cycle);
  (b) bound what the transect cache persists / stream the load (real fix; trigger-7 change);
  (c) raise the librewxr memory cap. **Recommendation: (a) now, (b) as ruled follow-up.**
  Becomes task **M-0**; every round's deploy gate additionally requires 4 consecutive
  OOM-free cycles post-M-0.
- **D-2 (round order):** **Recommendation: X → Z → Y′.** Rev1's Y-first rationale ("model starved
  to ⅓ energy") is dead; X targets the operator's webcam symptom directly (breaking physics); Z's
  premises are fully verified; Y′ depends on D-3/D-4 and live instrumentation data.
- **D-3 (boundary failure policy — resolves the Rev1 Tier 2/3 vs 2026-07-26 refuse ruling
  conflict):** (i) keep **refuse** (BoundaryNotViableError skips the cycle; add a loud /health
  reason naming the refusal — no parametric fallback ever) — kills Rev1's Tiers 2/3; or
  (ii) tiered-degrade per Rev1 Y-D1 (JONSWAP-per-partition fallback + `boundary_degraded` flag).
  **Recommendation: (i)** — a fabricated boundary poisons every downstream result; the July-26
  ruling's logic still holds, and it should fail loudly instead of silently skipping.
- **D-4 (mechanism B):** approve Y′'s core: instrument the three silent exit points + add a
  health flag when any hour bulk-falls-back ≥ N transects; fix the trigger once evidence pins it
  (fix scope returns to the operator if it trips an architectural trigger).
- **D-5 (second γ·d cap, `surf_1d_pipeline.py:754`):** in or out of X-D4's cap-deletion scope?
  **Recommendation: OUT** — it is a physical face-height depth cap on the combined wave at the
  break, a different mechanism from the W1b marched-vs-raw cap; deleting it has no evidence case.
  Recorded as an explicit X non-goal either way.
- **D-6 (X allowlist):** add `endpoints/beach_profile.py` — X0 proved zone construction lives
  there, not in the pipeline (Rev1 X-D5 was wrong on this point). Roller→zone plumbing is a
  3-file surface: analytical (compute E_r) → pipeline (carry fields; internal, not wire) →
  beach_profile (consume).
- **D-7 (Z-D1 transect label vs the 2026-08-02 pulled-label ruling,
  `BeachProfileCardBody.tsx:108-114`):** (i) no label — selection fix ships invisibly; or
  (ii) a plain-language label (e.g. "Surf shown at the sandbar, ~260 ft south of the pier"),
  explicitly NOT the removed developer-marker style and NOT "Line N of 162".
  **Recommendation: (ii)**, exact wording operator-approved at the Z gate.

## Round M-0 — service stability (NEW, first, per D-1)

Execute the D-1 ruling; verify: service publishes, `/health` = ok, 4 consecutive OOM-free cycles
(`dmesg` on ratbert clean for the marine cgroup), reality-gate Row-3-style journal sweep. Raw
output pasted. No other round's deploy gate may run before this closes.

## Round X — CARRIED from Rev1 §ROUND X, with:

- **X-D5 corrected:** files = `surf_1d_analytical.py` (march/Q_b/roller/cap per Rev1),
  `surf_1d_pipeline.py` (carry Q_b/E_r fields — internal plumbing only, no wire changes),
  `invariants.py` (two fire-only invariants), **`endpoints/beach_profile.py`** (zone extents
  consume E_r; per D-6), tests per Rev1. Anchors: X0-FACT-PIN table (at `d74c578`).
- **Implementation route (coordinator ruling, per Rev1's own "SAME solve" language):** X1/X3
  revive and adapt the deprecated `_solve_breaking_fraction()` / `_battjes_janssen()` /
  `_roller_model()` code (dead since Round W1) rather than writing fresh.
- **15 cm reform floor:** genuinely new state-machine code (today's `_MIN_BREAK_DEPTH_M` is only
  a publication filter) — as Rev1 specifies.
- Second cap per D-5. Guard-test dispositions: X0's inventory (9 files/~30 tests; 2 files
  clearly superseded, 3 uncertain → X5 rules on each, listed and justified).
- KATs X-K1..K4, tasks X0–X7, X reality gate: CARRIED verbatim (X0 already done).

## Round Z — CARRIED from Rev1 §ROUND Z, with:

- **Z-D2 teardown list EXPANDED** (Z-audit finding — ruling 6's "nothing OLD survives" demands
  it): += stale co-existing hash-keyed bathymetry cache generations (all
  `swan_bathymetry_*_<hash>.json` siblings for the spot, every tier), leftover
  `swan-precleanup-*` snapshot dirs, grid-identity hash markers (`*_bbox_hash.txt`,
  `*_geom_hash.txt`), and the two undetermined-ownership files (Z0 resolves ownership before Z2;
  unresolvable → surfaced).
- **Z-D1 label per D-7.** Selection scoring/stickiness/override-index design CARRIED.
- Z-D3, Z-D4 CARRIED (Z-D4's premise is confirmed by the component's own code comments).
- Z0 fact-pin still runs at dispatch (Z-audit is its seed; Z0 re-pins at the then-HEAD).

## Round Y′ — REPLACES Rev1 §ROUND Y

Scope (per D-3/D-4): (1) instrument the three silent exit points (`swan_runner.py:908-1011`) —
each gets a WARNING naming transect count and cause; (2) `/health` flag when any hour collapses
to bulk-fallback beyond a threshold (constant, gate-reviewed); (3) fix the collapse trigger once
instrumented cycles pin it — fix returns to the operator if architectural; (4) boundary-refusal
loudness per D-3 (or Tiers 2/3 if D-3=ii); (5) conservation invariant adapted from Y-D2 to the
REAL spectral path (fire-only, 2%); (6) docs: ADR-103 rewritten to document the boundary design
that actually exists (multi-station BOUNDSPEC, station selection, refuse policy) + PROVIDER-MANUAL
boundary section. Y-K KATs re-derived at dispatch to match D-3's outcome. **Y′ reality gate:
Rev1's three rows CARRIED verbatim** (handoff Hs ±25% vs buoy-shoaled; dominant period ±1.5 s;
publish-liveness + journal sweep) **plus** one added row: zero unexplained whole-hour
bulk-fallback collapses across 4 consecutive cycles.

**Y′-QC adversarial brief (replaces Rev1's Y-QC brief):** "Prove an hour can still collapse to
bulk-fallback without the new flag firing; prove the boundary can silently degrade or reuse a
stale spectrum across cycles; prove the conservation invariant can be satisfied by a wrong
spectrum; force each failure path and integrate the written boundary files independently."

## Documentation table

DOC-0 (`e5a94e1`), DOC-1 (`940047f`/`86b9d4e`), M-1 (`d74c578`): **DONE, verified.**
swan-commands-extract row: struck (operator ruling 2026-08-06 — file frozen as pure manual
extract; commit `caf49e8`). All remaining Rev1 doc rows CARRIED with their rounds, retargeted:
boundary-command documentation lands in ARCHITECTURE/PROVIDER-MANUAL (never the frozen extract).

## Standing process, QC gates, decision register

CARRIED verbatim from Rev1 (gate template rows 1–6 including the blind adversarial audit;
dispatch-gate discipline; Sonnet-only delegation; targeted tests only; one functional change per
deploy). Rev1's six register rulings carry forward verbatim; D-1..D-7 above join the register
when ruled. Pending-process items (not rules until the operator says so): commit-pinned plan
claims; architecture-section read (not grep) at dispatch.
