---
status: Accepted
date: 2026-08-13
deciders: shane
supersedes: ADR-104 (D2 cap value for L1 only, and its S/W island-aware siting rationale — see below)
superseded-by:
---

# ADR-108: Big-L1 true-non-stationary domain — island containment, time-marching compute, hourly L2+ seam

## Context

The served southerly swell runs 30–45% below reality. The deficit was traced with hand-decoded
numbers to WHERE the L1 boundary samples the WW3 grid: the boundary line (33.1667°N) is seaward of
Catalina Island by design, but **San Clemente Island still stands between it and open water** for
SSW swell, and WW3's coarse grid attenuates energy crossing the islands harder than reality does
(buoy 46253 holds 0.5 m of the 16 s train inside the bight where WW3's own cell says 0.21 m).

Ledger for the 16 s SSW train, 2026-08-13 00Z f006: open Pacific seaward of San Clemente
**0.43–0.45 m** (matches surf-forecast's WW3 read) → our boundary cells **0.22–0.38 m** → our
boundary spectra files 0.24–0.34 m (faithful write) → served **0.23 m**. The 12 s S train passes
healthily (0.47 → 0.41 m). Boundary reconstruction is faithful — the problem is that WW3's own
island-attenuation zone sits between our boundary and open water, and we inherit WW3's
over-attenuation instead of doing the shadowing ourselves.

The only way to beat WW3's island bias — not just relocate it — is a domain large enough to
**contain** both islands (Catalina and San Clemente) and do the shadowing ourselves with our own
real bathymetry. Extending L1 to contain San Clemente (~32.80°N southern tip, ~119.15°W western
shore) pushes the boundary into WW3's verified-accurate open-Pacific zone (the 0.43–0.45 m
readings), eliminates the islands as WW3-inherited bias, and lets SWAN model the real shadow
geometry at 1 km resolution.

The current quasi-stationary compute mode (one stationary equilibrium solve per forecast hour — a
`COMPUTE STAT` march) is physically indefensible at this domain size: a 16 s swell crosses a 170 km
domain in 3–4 h (group speed ~12.5 m/s), so equilibrating the whole domain instantly each hour makes
swell arrive hours early. True non-stationary time-marching (SWAN's own `COMPUTE NONSTAT`) fixes
arrival timing as a genuine physics gain.

The full evidence base, fact base, and design are recorded in
`docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` §PLAN AMENDMENT A1 ("A1 DESIGN v1"), which is
the operator-ordered architectural permission for this change (PA7).

## Options considered

| Question | Options | Chosen |
|---|---|---|
| Island handling | (a) Keep boundary dodging islands (ADR-104's approach); (b) Extend L1 to contain both islands, do shadowing ourselves | **(b)** — operator ordered 2026-08-13 |
| Compute mode (big L1) | (a) Keep quasi-stationary march; (b) True `COMPUTE NONSTAT` time-marching | **(b)** — physically required at >100 km extent |
| Hourly cycle handling | (a) Recompute L1 every hour (stationary, as today); (b) Skip L1 hourly, feed L2 from archived full-run nest output | **(b)** — eliminates L1's hourly cost entirely |
| Cartesian vs spherical | (a) Switch L1 to spherical coordinates; (b) Keep Cartesian UTM (quantified error: ~0.5–0.9° skew, within 5° directional bins) | **(b)** — error bounded, native nesting preserved |
| L1 cap | (a) Keep 100 km cap (G9); (b) Raise to 175 km for L1 only | **(b)** — G9's rationale (stationary validity) no longer applies once L1 is non-stationary |

## Decision

Adopted in full, as operator-ordered 2026-08-13 (fixit plan PA7). This ADR records D1–D9 of the
A1 DESIGN v1 as a decision.

**D1 — Domain extension.** L1's S and W edges extend to contain San Clemente Island; N and E edges
unchanged. Geographic targets: **SW corner (32.60°N, 119.25°W)** — south of San Clemente's
southern tip (~32.80°N) with open-Pacific WW3 cells seaward; NE corner stays (~34.07°N, ~117.77°W).
Result: **~138 km E-W × ~163 km N-S**, UTM 11N Cartesian as today (meridian-convergence skew ~0.5°,
scale error ~0.05% at 170 km — both below the 5° directional bin width; validation must spot-check
shadow-edge sensitivity). Cell size stays ~1.0 km → **~138 × 163 meshes (~22.5k cells, 2.47×
today's 9.1k)**. Spectral resolution unchanged (`CIRCLE 72 0.03 1.0 34`). Code:
`services/swan_domain.py` sizing gains an ISLAND-CONTAINMENT union — L1 box = union(spot-derived
box as today, fixed containment corners); `services/geography.py` cap `L1_MAX_EXTENT_KM` raised
**100 → 175** FOR L1 ONLY. Both constants operator-ordered under this amendment.

> **AS-BUILT AMENDMENT (2026-08-14): deck truth.** The emitted L1 `CGRID REG` for cycle
> 2026-08-14T00Z: `... 145069.95 167074.31 142 169` — **142×169 meshes at 1021.6 m × 988.6 m
> (≈145.07 × 167.07 km E-W × N-S)**, UTM 11N; the SW containment corner falls inside the box.
> Mesh count 142×169 = **23,998** (design estimated ~138×163 km / ~22.5k cells — the final box is
> slightly larger because sizing is a union of the containment corners with the existing G9
> clamp-floor/fetch-fan geometry, not a direct re-derivation of the design's hand corners; see the
> deploy-time fixes `084ecfb`/`425f168` recorded in the fixit plan's CURRENT STATE). This mesh
> count is distinct from the sizing cache's own cost-estimator figure — see the named-constants
> note below. Wind-store gatherer bbox rebuilt at the wider box, `leftlon = -119.60`.

**Named constants:**
- `L1_CONTAINMENT_SW = (32.60, -119.25)` — the containment SW corner (lat, lon).
- `L1_MAX_EXTENT_KM = 175` — supersedes ADR-104 D2's 100 km cap FOR L1 ONLY. G9's rationale
  (stationary validity at <100 km) no longer applies because L1 stops being stationary. The cap
  for non-L1 levels and the Great Lakes regime exemption are unaffected.
- **Cell-count estimator note (as-built, GATE-A1.5 finding F1):** the sizing cache's cost
  estimator (`GridDomain.cell_count`) reports **24,795** — ni×nj HAVERSINE GRID POINTS
  (145×171, `round(dist/res)+1` per axis) — a DIFFERENT metric from the deck's CGRID MESH count
  (142×169 = 23,998) cited above; the OLD grid's cached "9.1k" used the same points-based
  mechanism. The deck's mesh count is the as-built truth cited throughout this ADR; the cache
  figure is a pre-existing, unrelated cost estimator, not a doc-code drift.

**D2 — Compute mode (full run, L1 ONLY; L2–L4 unchanged).** Keep `MODE NONSTATIONARY`; replace the
57–73-solve `COMPUTE STAT` march with the SWAN manual's own canonical pattern (lines 5708–5713):

```
COMPUTE STAT <C+0>                      ! spin-up: stationary equilibrium = initial state
COMPUTE NONSTAT <C+0> 10 MIN <C+72h>    ! true time-marching, dt = 10 min
```

NUMERIC: the manual's grammar makes `STAT [mxitst] [alfa]` and `NONSTAT [mxitns]` ALTERNATIVES
inside one NUMERIC command (manual 4176–4182); `[alfa]` is "NOT MEANINGFUL FOR NONSTATIONARY"
(4231); settings may change between COMPUTE commands (5708–5716). The deck carries **TWO NUMERIC
commands**: today's STOPC…STAT line before the spin-up solve, then `NUMERIC STOPC dabs=0.005
drel=0.01 curvat=0.005 npnts=99.5 NONSTAT mxitns=1` before the march (`mxitns` default is already
1 per 4235 — stated explicitly; manual 5730–5731: ≤10-min dt → 1 iteration/step). **dt = 10 MIN**
(manual 5721: at most 10 minutes advised).

> **AS-BUILT AMENDMENT (2026-08-14, operator-ordered after two production failures): the deck
> carries `PROP BSBT`, and dt stays 10 MIN. The original Courant analysis below is WRONG — do not
> resurrect the dt-shrinking ladder.**
>
> The original design computed Courant numbers against the fastest *physically-present* wave
> (25 s forerunners, cg≈19.5 m/s → C≈11.7 at dt=10; ladder rung dt=6 → C≈7.0). In production,
> **SWAN's internal CFL<10 advisory for the default higher-order S&L nonstationary scheme is
> evaluated against the lowest *discrete spectral bin*** — here 0.03 Hz (T=33.3 s, deep-water
> cg=26.0 m/s) — and behaves as an axis-combined metric (per-axis C≈9.2/9.5 at dt=6, combined
> ≈13). Result: dt=6 MIN **still tripped** `** Error … CFL greater than 10` (2026-08-14 00:43Z
> and 02:34Z), which the convergence gate rightly classifies as print-fatal → no-publish → the
> service retry-looped ~100-minute failing cycles. No practical dt passes at 1 km cells with the
> 0.03 Hz spectral floor (dt would need to be ≤4 MIN, ~148-min march, breaching the 2 h timeout).
>
> The manual resolves this directly: SWAN is **implicit and unconditionally stable** — "not
> limited by the Courant stability criterion" (manual ~756); the CFL advisory concerns S&L
> *accuracy* only. For exactly this case the manual prescribes the first-order upwind scheme:
> "Otherwise, a first order upwind scheme is recommended in that case; see command PROP BSBT"
> (5725–5728). BSBT is valid for both stationary and nonstationary computations (4139). On its
> diffusion penalty: the manual's only quantified scale statement for first-order upwind
> diffusion is its unstructured-mesh note (4164–4169: "may only be significant … in the order
> of thousands of kilometers") — that passage describes the automatic lowest-order scheme on
> unstructured meshes, NOT `PROP BSBT` on a regular grid; we carry the characterization over as
> an ANALOGICAL INFERENCE (same first-order upwind scheme class), per Gate DOC-A1-FINAL finding
> F2, not as a direct manual statement about BSBT. L1 spans ~150 km either way, and
> its job is basin-scale energy delivery to L2's boundary; fine directional structure is rebuilt
> by the unchanged higher-order (SORDUP) stationary solves in L2–L4, which stay BSBT-free.
> Emitted order: `PROP BSBT` precedes both COMPUTE commands. dt returns to the manual-advised
> 10 MIN maximum (forcing varies hourly; 432 steps). KATs pin `PROP BSBT` presence and order and
> pin L2–L4 decks BSBT-free (`tests/services/test_all_stationary_sequence.py`). Commit `7097369`.

All L1 inputs (WIND/BOUND/WLEV/CUR) are already time-tagged files —
non-stationary interpolates them natively, zero input-side changes. `NESTOUT … 1 HR` unchanged
(same L2 contract, and the 48–72 h tail gains hourly nest records vs today's 3-hourly solves).
L1 hourly hotstart files **retired** (nothing consumes them once the fast cycle drops L1);
full-run initial state = the spin-up solve, no hotfile dependency.

**D3 — Boundary.** Per-wet-cell WW3 reconstruction (ADR-106 R1) mechanism UNCHANGED; the perimeter
moves with the box: S side at ~32.60°N (~7–8 gfswave 0p16 wet cells), W side at ~119.25°W (~9
cells). Same source, same time axis, same coverage-window rule (Z3.9a).

**D4 — Bathymetry (datum policy).** Existing chain unchanged in mechanism: NCEI regional DEM → CRM
fallback (`bathymetry_resolver.py`). ADR-098 discipline applies to the big box in full: BOTTOM and
WLEVEL on the SAME vertical datum; SWAN does not detect mismatches — a mismatch silently corrupts
depth-dependent physics. **Hard requirements:** (i) the big-L1 BOTTOM source must have a KNOWN
datum — the existing UNKNOWN-datum rejection guard in `download_bathymetry_for_level()` stays
binding; (ii) CRM has NO guaranteed datum (PROVIDER-MANUAL: mixed-datum mosaic, unnormalized) — CRM
answering the big box is NOT automatically acceptable; it is a STOP-and-surface for the operator's
datum ruling (accept with existing degraded-quality flagging, or bring a known-datum deep source
such as GEBCO/MSL); (iii) WLEVEL (STOFS ≈ LMSL) must be reconciled to the chosen BOTTOM datum via
the existing ADR-098 match-at-source mechanism, verified for the NEW box; (iv) datum consistency
across nest levels — the big L1's datum vs the child DEMs' datums — is part of A1.2's acceptance,
since a level-to-level offset shifts every handoff depth.

**D5 — Hourly (fast) cycle rewire.** Fast cycle runs L2→L3→L4 + SwellTrack/1-D exactly as today;
**L1 is SKIPPED**. L2's `nest_in.dat` := the ARCHIVED `nest_out.dat` of the most recent COMPLETED
full run (per-run retained copy `level1/nest_out_<cycle>.dat`, kept ≥24 h; the live workdir file is
not depended on). L2's deck is byte-unchanged — `BOUNDNEST1 NEST CLOSED` + `COMPUTE STAT <t>`
already reads the time-tagged record stream mid-file (production behavior today; A1.1 runs the
disambiguation: a SINGLE mid-file `COMPUTE STAT` against a multi-record nest file). Fresh wind
still forces L2–L4 every hour — the accepted loss is confined to L1's belt outside L2 (~6–8 h
worst-case latency on new offshore wind). **New health surface:** `l1NestAge` reports the age (in
hours) of the archived nest being used. Hourly-run refusal when the archived nest exceeds
`L1_NEST_MAX_AGE_H = 9` (one missed full run + margin) — refuse-loudly per standing no-publish
posture.

**D6 — Wind store impact.** Gatherer bbox derives from the L1 box (existing derivation) → grows
~2.5×; HRRR CONUS + GFS both cover 32.6°N offshore; disk/transfer growth bounded and trivial vs
the existing store. No schedule/cadence change, no store schema change.

**D7 — NOT changing (scope fence for every A1 agent):** L2/L3/L4 grids and decks, spectral
resolution at every level, GEN3 ST6 physics line, SwellTrack/1-D/SurfBeat, the per-wet-cell
reconstruction algorithm, provider modules other than bbox inputs, API/served contracts, the 5°
directional-resolution question (separate parked experiment).

**D8 — Failure/rollback.** Full-run failure → hourly keeps serving off the last archived nest
until the D5 age gate refuses (existing refuse-loudly UX). Rollback = git revert of the domain
constants + runner switch; no data migration; stale hotstart/nest artifacts are inert files.

**D9 — Predicted cost.** Iteration-sweep units on today's grid=1: march today ≈ 57–73 solves ×
I_stat iterations × 1.0; big-L1 non-stat ≈ (I_stat spin-up + 432 steps × 1 iter) × 2.47. At
I_stat≈15 → ≈ parity with today's L1 wall-clock share; worst plausible (well-warmed I_stat≈8) ≈ 2×
L1's share. The hourly cycle gets strictly FASTER (drops its L1 solve entirely). A1.1 confirms.

### Named constants (fixed by this decision, not re-derivable by implementers)

- `L1_CONTAINMENT_SW = (32.60, -119.25)` — containment corner.
- `L1_MAX_EXTENT_KM = 175` — L1-only cap (supersedes ADR-104 D2's 100 km for L1).
- `L1_NEST_MAX_AGE_H = 9` — hourly cycle refuses when the archived L1 nest exceeds this age.
- `COMPUTE NONSTAT` dt = **10 MIN**, with **`PROP BSBT`** in the L1 deck (as-built 2026-08-14;
  the dt=6 ladder rung is superseded — see the D2 as-built amendment. Do NOT shrink dt to chase
  SWAN's CFL advisory: it checks the 0.03 Hz bin and no practical dt passes at 1 km cells).
- `mxitns = 1` (explicit, per SWAN manual 4235 + 5730–5731).
- Spectral resolution: `CIRCLE 72 0.03 1.0 34` — **UNCHANGED**.
- L1 cell size: **~1.0 km** — unchanged.

### Supersedes and amends

- **ADR-104 D2** — the 100 km cap. The cap itself is retained for non-L1 levels; only L1's cap
  is raised to 175 km. D2's stationary-validity rationale no longer applies to L1 because L1
  stops being stationary under this decision. The Great Lakes exemption is unaffected.
- **ADR-104's island-aware S/W siting rationale** — ADR-104's boundary design avoids the islands
  (dodges them, then mitigates the residual shadow with D11's near-lee clamp). This decision
  supersedes that approach FOR L1: the boundary swallows the islands instead of dodging them,
  eliminating the inherited WW3 island-attenuation bias that was the root cause of the 30–45%
  SSW deficit. D11's near-lee clamp machinery remains in the code but does not fire for islands
  that are now contained.

## Consequences

- **Domain constants:** `L1_CONTAINMENT_SW` and `L1_MAX_EXTENT_KM = 175` in
  `services/geography.py`; union sizing in `services/swan_domain.py`.
- **Deck emission:** `services/swan_formats.py` emits `PROP BSBT` + the two-NUMERIC + spin-up +
  `COMPUTE NONSTAT` pattern for L1 full runs. L2–L4 decks byte-unchanged (BSBT-free, SORDUP).
- **Runner orchestration:** `services/swan_runner.py` full-run path unchanged except the deck
  it writes; fast-cycle path skips L1, reads the archived nest, and checks the age gate.
- **Nest archive:** per-run `nest_out_<cycle>.dat` in `level1/`, ≥24 h retention.
- **Health surface:** `l1NestAge` in the `/health` response; `l1NestAge` > 9 → hourly refuse. A
  forced full run (the existing geometry-changing config-push trigger, `force_full_run_signal`)
  always rebuilds L1 and therefore resets `l1NestAge` to zero on success; the age only grows
  between full runs or when one fails/delays (fold-in from Gate DOC-A1's A1.0 LOW finding).
- **State:** `state.py` + `endpoints/health.py` carry the new `l1NestAge` key.
- **Hotstart retirement:** L1 hourly hotstart files no longer produced or consumed.
- **Wind store:** gatherer bbox grows with L1 (existing derivation, no code change).
- **Boundary perimeter:** moves with the box (per-wet-cell mechanism unchanged).
- **Bathymetry:** the big box may require a datum ruling if CRM answers (D4).

## Acceptance criteria

`(landed 2026-08-14, Plan Amendment A1 tasks A1.1–A1.5 of MARINE-PAGE-FIXIT-PLAN; as-built)`

- [x] D1: L1 domain contains San Clemente at ~1 km resolution; both islands render as dry cells.
  **Evidence:** live INPUT deck `CGRID REG` confirms the SW containment corner (32.60°N,
  119.25°W) falls inside the 142×169-mesh box (1021.6 m × 988.6 m cells); A1.1(f)
  (`A11-MEASUREMENTS.md`) — ETOPO 2022 15s renders San Clemente as ~90–150 dry cells at 1 km L1
  resolution (~2× coarser than ETOPO's native ~460 m); boundary reconstruction log confirms 9 wet
  WW3 cells on both the S and W sides outside the containment corners (journal
  2026-08-14T04:02:38Z).
- [x] D2: Full-run L1 deck emits `PROP BSBT` + spin-up `COMPUTE STAT` + `COMPUTE NONSTAT <C>
  10 MIN <C+72h>` with two NUMERIC commands (STAT before spin-up, NONSTAT before march); L2–L4
  decks BSBT-free. **Evidence:** live deck verified post-deploy `7097369` 04:06:26Z — `PROP BSBT`
  line + `COMPUTE NONSTAT 20260814.000000 10 MIN 20260817.000000`; KATs
  `tests/services/test_all_stationary_sequence.py` pin `PROP BSBT` presence/order and L2–L4
  BSBT-free.
- [x] D2: All SWAN commands in the emitted deck verified against the local SWAN manual with line
  cites. **Evidence:** this ADR's D2 as-built amendment (manual ~756 implicit/unconditionally
  stable; 5725–5728 CFL-advisory-is-accuracy-only + `PROP BSBT` prescription; 4139 BSBT valid
  stat/nonstat; 4164–4169 unstructured-mesh first-order-upwind diffusion-scale note, applied to
  BSBT as an analogical inference — see the D2 as-built amendment's labeling) plus D2's original
  canonical-pattern cites (5708–5731, 4176–4235).
- [x] D3: Boundary perimeter covers the new S/W edges with ≥2 wet WW3 cells per side.
  **Evidence:** journal 2026-08-14T04:02:38Z: "reconstructed ocean boundary (ocean cycle
  2026-08-14T00:00:00+00:00): side S = 9 wet cell(s), side W = 9 wet cell(s), 25 timestep(s)
  each"; 22 boundary files on disk (11 `B_S_*` + 11 `B_W_*`) vs the old grid's 15.
- [x] D4: BOTTOM datum KNOWN for the whole big box; WLEVEL reconciled; cross-level consistency
  stated. **Evidence:** A1.1(f) (`A11-MEASUREMENTS.md`) — ETOPO 2022 15s covers the big-box SW
  corner at datum LMSL (same source/datum as today); no CRM fallback triggered, D4's STOP clause
  does not fire; L2/L3/L4 regional DEMs also normalized to LMSL via VDatum — no cross-level
  offset; WLEVEL (STOFS≈LMSL) already matches, no reconciliation change needed.
- [x] D5: Hourly cycle runs L2→L3→L4 without L1; archived nest age checked; refusal when >9 h.
  **Evidence:** GATE-A1.4 PASS (marine `ffe0f0c` after F1/F2 remediation); live nest archive
  `nest_out_20260814.000000.dat` saved 04:57:43Z (journal); `L1_NEST_MAX_AGE_H = 9` KATs incl. the
  exact-9.0h boundary (frozen-clock fix, marine `7bffaf7`).
- [x] D5: `l1NestAge` visible in `/health` response. **Evidence:** GATE-A1.5 record
  (`A15-REALITY-GATE.md`): `l1NestAge` = 5.58 h (non-null) after the first archived nest;
  independently re-derived from `/health` by the auditor's clean dispatch.
- [x] D7: `CIRCLE 72 0.03 1.0 34` byte-identical at every level; L2/L3/L4 sizing untouched.
  **Evidence:** GATE-A1.3 deck KAT (frozen-core untouched outside the named files); GATE-A1.4
  hourly deck byte-identical except nest source; no L2/L3/L4 file appears in the A1.3/A1.4 diffs.
- [x] D9: A1.1 measurement confirms D9's predicted cost within 3× of today's L1 share.
  **Evidence:** full run 5280 s (cycle 2026-08-14T00Z, journal completion line
  2026-08-14T05:34:26Z) vs prior baseline 3064 s (00Z cycle, 06:21:39Z) = **1.72×**, inside the
  3× bound; A1.1(a)/(b) analytical prediction (I_stat mean 7.0) forecast ~2.12× L1 share,
  consistent with the measured range.
- [x] A1.5 reality gate: served 16 s-train no longer 30–45% low vs buoy 46253 at matched hours.
  **Evidence:** GATE-A1.5 PASS-WITH-FINDINGS (`A15-REALITY-GATE.md`): served southerly
  long-period train 0.53 m vs buoy 46253 0.5–0.6 m (ratio 0.89–1.06) across matched hours, vs the
  pre-fix baseline's 0.23 m (30–45% low). Today's ocean state carries the same southerly train at
  12–13 s rather than 2026-08-13's 16 s (buoy SwP oscillated 11.1–18.2 s over the period) —
  matched like-for-like, not a goalpost move; see the gate record for the full disposition.

## Implementation guidance

- **Task breakdown is in the fixit plan** — A1.0 (docs first) → A1.1 (validate) → A1.2
  (bathymetry) → A1.3 (big-L1 non-stationary full run) → A1.4 (hourly cycle rewire) → A1.5
  (validate against reality) → A1.6 (docs final). Strict order.
- **Frozen-core opening** — A1 tasks open ONLY: `services/geography.py` (the cap),
  `services/swan_domain.py` (sizing union), `services/swan_formats.py` (deck emission),
  `services/swan_runner.py` (full/fast orchestration + nest archive), `state.py` +
  `endpoints/health.py` (`l1NestAge`). Hotstart mechanics open ONLY for L1-hourly-hotstart
  retirement. `CIRCLE 72 0.03 1.0 34`, `omp_num_threads = 6`, and L2/L3/L4 sizing stay FROZEN.
- **SWAN manual is LOCAL** — `docs/reference/swan-user-manual.txt` +
  `docs/reference/swan-commands-extract.md`. Web-searching SWAN is forbidden.
- **Out of scope:** L2/L3/L4 grids and decks, spectral resolution, GEN3 ST6 physics,
  SwellTrack/1-D/SurfBeat, the per-wet-cell reconstruction algorithm, API/served contracts, the
  5° directional-resolution question.

## Amendment (2026-08-17): scope note — remains the live serving path, NOT superseded — ADR-109

**Status: Accepted.** Recorded by the DOC-W.5 full-index ADR impact sweep
(`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, Phase DOC-W, task DOC-W.5), following
acceptance of **ADR-109** ("WW3 deep-water leg — always-on deep-ocean wave model, handoff to SWAN at
L2"). Pointer + scope note only — no ruling above (D1–D9) is re-opened.

**This ADR remains the LIVE serving path.** Per ADR-109 D15: this ADR's domain (the big-L1
island-containment box), compute mode (`COMPUTE NONSTAT` time-marching), hourly-cycle rewire (L2+
seam via archived nest output), and refuse-gate mechanics (`l1NestAge` + `L1_NEST_MAX_AGE_H = 9`)
are **unchanged** by ADR-109 and continue to serve production traffic until a Phase V4 verdict-1
(cutover) ruling, if one is ever given. Under a verdict-2 (hold shadow, open Phase L) or verdict-3
(extend) ruling, this ADR's path keeps serving indefinitely.

**This ADR is NOT superseded by ADR-109, and gets NO SUPERSEDED-AT-V5 tag** — the plan's DOC-W.5
provisional table is explicit on this point: any supersession of this ADR belongs exclusively to a
future Phase V5 disposition ruling, never before, and never as a byproduct of this sweep. The WW3
deep-water leg (ADR-109) runs in shadow mode alongside this ADR's live path (ADR-109 D1, D12's
per-site shadow-mode key) — it computes and stores its own artifacts without affecting this ADR's
serving behavior in any way.

## References

- Plan: `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` §PLAN AMENDMENT A1 — A1 DESIGN v1
  (the operator-ordered design this ADR records), PA7 pre-approval register entry, QC gates.
- ADR-109: WW3 deep-water leg — scope note above (D15); this ADR's own path is unaffected and remains
  live-serving until at least Phase V4.
- ADR-104: island-aware L1 sizing — D2 cap superseded for L1; S/W siting rationale superseded
  by containment.
- ADR-106: marine page fixit rulings — R1 per-WW3-cell boundary (mechanism unchanged, perimeter
  moves with the box).
- ADR-098: bathymetry datum discipline — binding on the big box in full (D4).
- SWAN manual: `docs/reference/swan-user-manual.txt` — lines 4176–4235 (NUMERIC alternatives),
  5708–5731 (COMPUTE NONSTAT canonical pattern, dt advice, iteration count).
