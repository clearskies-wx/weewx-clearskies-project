# Study-Area Geometry & Geographic Awareness — Research Brief

**Date:** 2026-07-30 · **Status:** DRAFT for operator review — **Fable-reviewed 2026-07-30, 15 findings incorporated** (coordinator-verified against live code before edit) · **Author:** coordinator (research pass, grounded 2026-07-30)
**Scope:** How the marine pipeline decides *where* and *which way* to model a surf spot — beach facing, grid
orientation, transect orientation, swell/fetch exposure, and the shoreline data underneath it.
**This brief proposes nothing to build.** It documents the current mechanism (verified in code *and* against the
governing ADRs/manuals/briefs), separates what is a genuine defect from what is an approved design choice, and
frames the geometry change so it does **not** disturb the fixed grid-sizing / handoff / nesting requirements.
Every downstream change is architectural and requires explicit operator approval.

---

## 0. Correction to an earlier claim (read first)

An earlier pass asserted the **L4 grid's rotation to the pier axis was "unauthorized."** That is **wrong**, and
this brief corrects it. Rotating the L4 structure grid to the structure's own principal axis is an **explicitly
approved decision** with a sound rationale — [SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md §3.1 lines 520-529], carried
into ADR-093 Amendment 3, `ARCHITECTURE.md:105`, `PROVIDER-MANUAL §14.15:1901`. The reasoning (verbatim): L4 is a
*nested* grid that "receives parent boundary spectra around its entire perimeter … so swell obliquity relative to
the box orientation is immaterial … Rotation here is purely an area optimization around a fixed physical object
(the structure)" — it roughly halves the cell count (illustrative 12.5 m-era worked example 16,128 → 5,120; the
**deployed 10 m L4 runs 5,292 cells**, T1.2). **Rotating L1–L3 to the beach bearing was, by
contrast, explicitly rejected** (SWAN-GRID-STRATEGY-RESEARCH-BRIEF §5 error 1, `:227-231`). So the design is: **L1/L2/L3 axis-aligned; L4 rotated to the
structure axis; neither oriented to beach facing — on purpose.**

Consequence for the "L4 and the transects must share one orientation" premise: **per the approved design they need
not, and should not, match.** Transects read the SWAN spectrum at their handoff cells regardless of L4's box
angle; L4's rectangle need not be parallel to the lines, and — because a partial-coverage transect already uses
its own L4 column as far as that column reaches (interior-clamp, T1.2b/TA-C23, see §3.3.6) — **L4's box need not
even fully cover every transect.** The edge-transect issue was never an orientation error; and its coverage
aspect is already handled by the shipped partial-coverage clamp, not something this brief reopens.

---

## 1. What is genuinely broken vs. what is by design

> **⛔ SUPERSEDED 2026-08-02 (H3, MARINE-FORWARD-PLAN.md).** Defect 1 below (and its "isobath-normal"/"local
> isobaths"/"smoothed bathymetric gradients" framing) describes the facing derivation this brief judged
> "documented but NOT implemented" — that design was never built. It was superseded 2026-07-31 by **AD-1R**
> (`docs/decisions/ADR-093-swan-trushore-nearshore-model.md` Amendment 5), which uses a **smoothed 0 m shoreline
> normal** (DSAS/CliffMetrics), not an isobath/depth-contour gradient, computed at spot-definition time and
> operator-overridable. AD-1R is IMPLEMENTED (marine `73df829` and later). The text below is left unchanged as
> the historical record of this brief's own diagnosis — do not read it as describing current behavior.

**By design (approved — do NOT "fix"):**
- L4 rotated to the structure principal axis; L1–L3 axis-aligned. (§0)
- Grid geometry frozen at setup; the per-hour handoff *cell* moves, the grid does not.
- L4 orientation independent of swell/beach — it's a nested grid.

**Genuinely defective (verified in code + docs):**
1. **Transect / beach-facing derivation.** The design of record is **transects perpendicular to local isobaths**,
   from smoothed bathymetric gradients (`ARCHITECTURE.md:125`, `OPERATIONS-MANUAL.md:961`, SURF-ZONE §2.6). It is
   **documented but NOT implemented**: code sets `transect_bearing = beach_facing_degrees` for *every* transect,
   with no per-transect variation (T4.4-SHADOW-DIAGNOSIS `:25-27`, `swan_formats.py:752-753`), and
   `beach_facing_degrees` is itself computed as the **perpendicular to the operator's drawn shoreline segment**
   (`marine_config.py:505-510`, `:569-576`). This segment-perpendicular value is the **documented v1 placeholder
   for the isobath-normal design** — ADR-093 Amdt 1 §3/§6 deliberately replaced the old `beach_facing_degrees`
   config key with the segment endpoints and made the perpendicular the v1 bearing source, with `swan_formats.py:750`
   marking per-transect isobath-normal as `v2 future`. It is not an accident; it is a placeholder never advanced to
   v2. At HB this lands at **238.02°** (segment bearing 148.02° + 90°, T4.4-SHADOW-DIAGNOSIS `:23-24`), ~13° off the
   true shore-normal.
2. **`beach_facing_degrees` is consumed consistently now — the residual is a stale-config risk, not the sizing
   inconsistency an earlier draft claimed.** An earlier version of this brief cited "other code sizes L2/L3 by
   *ignoring* it and extending equally in all directions (BATHYMETRY-RESOLUTION-BRIEF `:175`)." **That is stale:**
   `:175` is the root-cause line of a bug the same brief records as **FIXED in commit `b44e3c3`** ("All three
   levels now use `beach_facing_degrees`"), and the current code confirms it — `_compute_level2()`
   (`swan_domain.py:1010-1049`) and `_compute_level1()` (`swan_domain.py:980-988`) both project offshore *along*
   the bearing. So the value **is** now the single offshore-direction source across L1/L2. The real defect is
   **defect 1** (the bearing's *derivation* is segment-perpendicular, not isobath-normal), not its consumption.
   One genuine residual to verify at fixture time: the `API-MANUAL.md:2477` "`beach_facing_degrees + 180°`"
   CURVE-direction note and any lingering deployed-config `beach_facing` value (see §1 measured note) — confirm
   these agree with the derived property before relying on either.
3. **Multi-obstacle structure axis is fragile.** `compute_structure_grid_domain()` takes the two most-distant
   points across **all** eligible obstacles combined (`swan_domain.py:1904-1911`); with >1 separate structure the
   "axis" becomes the line between two *different* structures — not a physical orientation. The principled
   replacement is the **minimum-area enclosing rectangle of the combined obstacle-plus-shadow footprint** (§6 Q6),
   which reduces to the pier axis for a single structure; a two-point axis is a degenerate special case.
4. **Shoreline is derived from the bathymetry DEM's 0 m (MSL) crossing** (`find_shoreline_from_grid`,
   `bathymetry.py:1364-1406`), which is datum-dependent and requires the DEM to already exist — while the operator
   *traces* the study area on the OSM basemap. Two different shorelines; see §4.

**Measured at Huntington (2026-07-30, coordinator-reproduced diagnosis `T4.4-SHADOW-DIAGNOSIS-2026-07-30.md:19-32`):**
survey lines **238.02°** (segment bearing 148.02° + 90°, segment-perpendicular, uniform across all 32 transects);
pier's **configured** `bearing_degrees` **221.0°** (the L4 grid rotates to the pier axis, **approved** — the exact
computed `alpc` rotation is recorded separately as ≈229° in PHASE-E-SESSION-LOG `:376`; reconcile the two before
quoting a single L4 angle). HB faces SW into open Pacific, so the ~13°-off lines still point at real water — which
is why nothing surfaced until an edge line walked off L4's coverage. *(A "configured `beach_facing` 225°" figure
from an earlier draft is **unverified** — `beach_facing_degrees` is a derived property (238.02°), not a config
key, so any deployed 225° value needs a source in `marine.conf` before it is cited as the shore-normal comparator.)*

---

## 2. Why it does not generalize (the deferred decision this reopens)

The single-cross-shore-facing model assumes a **straight beach facing open ocean**. That assumption is
load-bearing in: one facing per spot; a single (currently uniform) transect bearing; "offshore = away from land,
forever"; and an operator-typed 8-sector exposure window. It fails at:

- **Point break / curved shore (Malibu, Rincon):** the shore-normal *rotates* along the break; a uniform bearing
  and a per-spot exposure window can't represent the wrap-around or the narrow directional sensitivity.
- **Bay / semi-enclosed:** the local beach-normal points into the bay, not the open-ocean swell corridor.
- **Enclosed basin (Great Lakes):** no distant swell — **wind-sea, fetch-limited** to the opposite shore, a
  different physics regime (ADR-098 already routes Great Lakes to a different DEM/datum). **`classify_region`
  already exists and already routes several region-dependent behaviours** — the WW3 product (GLWU vs ocean,
  `ww3_station_selection.py`), the vertical-datum branch (`vertical_datum.py`), the bathymetry source order
  (`bathymetry.py`), fishing species (`fishing_species.py`), and tide (`surf_pipeline_timestep.py`). So the
  regime split this brief needs is a **change to what an existing, multiply-consumed shared function drives**
  (architectural trigger 2 — a responsibility change), **not** a greenfield classifier. That existing machinery
  is an asset here, not an obstacle (see §4, §6).
- **Archipelago / intricate coast (Aegean, fjords):** islands + slanting fetch + combined refraction–diffraction;
  first-order sheltering that cannot be smoothed.

**This is the exact decision ADR-093 Amendment 2 §3 deliberately deferred.** It ruled contour-orientation
derivation OUT of scope — "contour curvature, orientation variation along the segment, headland detection,
automatic break-type classification" — and substituted **operator classification** (`topographic_feature` =
point/headland/bay), which also became the L3 trigger. Reason given: point breaks are defined by *alongshore*
geometry a single cross-shore profile can't see, and auto-detection "is specified nowhere and built nowhere."
**Anything in this brief that auto-derives facing from contour shape moves work from that OUT list to IN — i.e. it
consciously reopens a closed decision.** That is allowed (operator-driven), but the brief must say so, and the
reopening must not disturb the fixed sizing set (§3).

---

## 3. Integration: what is FIXED, where the seam is, what changes, what's preserved

### 3.1 FIXED — must not move (an orientation change may not perturb these)

| Requirement | Value / rule | Source |
| --- | --- | --- |
| Handoff depth (per forecast hour) | `1.3 × Hs(hour) / γ`, γ = **0.73** | ADR-093 Amdt 2 §2; `ARCHITECTURE.md:100`, `PROVIDER-MANUAL.md:2066` |
| Grid shoreward reach (setup) | smallest handoff ever, at `_MIN_DESIGN_HS_M = 1.0` → **1.78 m** contour | `ARCHITECTURE.md:105`, `PROVIDER-MANUAL.md:2074` |
| Offshore edges | L2 = **30 m** contour, L3(role-b) = **15 m** contour, deep-water reference always L2 @ 15 m | ADR-093 Amdt 2 §2; `PROVIDER-MANUAL.md:2078`, `:2159` |
| Tier resolutions | L1 **1 km**, L2 **100 m**, L3 **40 m** (`_L3_RESOLUTION_M`), L4 **10 m** fixed | ADR-093 Amdt 3; `PROVIDER-MANUAL §14.15` |
| Nesting ratio | **Spectral** resolution between nests ≤ ~2–3×; **spatial** refinement 5–10× per step is acceptable (deployed: L1→L2 10×, L2→L3 2.5×, L3→L4 4×) | SWAN-NESTING-RESEARCH `:69` |
| L1 offshore *distance* | GSFM shelf/slope boundary **+ 10 km offshore past the shelf edge** (`swan_domain.py:965`; the "15 km" in `ARCHITECTURE.md:105` is doc-code drift — fix at doc-sync), ~5 km lateral default — **open-ocean baseline only.** The offshore *aim* and island/lake enclosure are **NOT** fixed: operator direction 2026-07-30 moves L1's aim + WW3 sides to the geography-aware open-water fan (§3.3 item 4), islands enlarge L1 to enclose them (§6.4), and lakes need fetch bounding (no shelf, §6). | `swan_domain.py:965`; `ARCHITECTURE.md:105` (drift); ADR-098 |
| L3/L4 alongshore extent | structure length + 2× downstream (shadow) + 100 m pad; L4 across-axis = shadow-union + 2 λ each side | ADR-093 Amdt 1 §2 / Amdt 3; FINDINGS §3.2 |
| Handoff control flow | first-match L4 → L3 → **L2 @ fixed 15 m** (`L2_REFERENCE_DEPTH_M`) | FINDINGS D3 |
| 1-D landward boundary | Highest Astronomical Tide, computed once at setup | ADR-093 Amdt 4 |
| Setup-time freeze | all geometry in `compute_domains()` before any SWAN run; **no runtime override**; NESTOUT must cover every child grid | `rules/clearskies-process.md:298`; `PROVIDER-MANUAL.md:1952` |
| Coordinate frame | Cartesian/UTM, one **locked zone per deployment** (spherical forbids rotated grids → would kill L4) | MARINE-MODEL-RESTORATION-PLAN "Projection fix" (operator Option A, 2026-07-28, DONE) |
| Memory / runtime | ≤ 300 MB budget (ADR-093:73); measured first real 4-level run ~**41 min**, peak tmpfs ~1.36 GB (cadence lever → ~24–27 min). The old "~7 min / 12,600-cell" figure predates the real run and is struck. | ADR-093:73; plan T1.2 |
| Transect spacing | 10 m default (value unchanged); node-alignment now holds against **L4's 10 m** grid — L3 is 40 m since Amdt 3, so the original "matched to L3 res" rationale is stale, the spacing is not | SURF-ZONE §2.2.4; ADR-093 Amdt 1 §3 / Amdt 3 |
| Structure-affected transects | tagged, excluded from headline metrics; >50 % → warn | SURF-ZONE §2.2.3 |

### 3.2 The seam — where the change actually goes

The change is **one thing: how the shore-normal bearing is derived, and letting it vary along the shore.** It
enters at exactly two producers and flows into existing, unchanged consumers:

- **Producer A — `beach_facing_degrees` derivation** (`marine_config.py:505-510`): replace "perpendicular to the
  drawn shoreline segment" with a **bathymetry-isobath shore-normal** (the design already documented in
  SURF-ZONE §2.6), allowed to be **per-transect** on a curved shore.
- **Producer B — `compute_spot_transects` / `swan_formats.py:752`**: emit the per-transect isobath-normal bearing
  instead of one shared `beach_facing` (advance the existing `v2 future` comment at `swan_formats.py:750`).

Every sizing/handoff consumer already takes a *bearing* as a parameter (`find_shoreline_from_grid`,
`find_depth_contour_distance`, `compute_transect_shadows`). **We change what bearing is passed, not the math
that consumes it.**

**A framing correction (operator, 2026-07-30): L2 size is coverage-driven, not bearing-driven.** L2 is a
**functional stepping-down of L1**, and its size is governed by the requirement to **enclose the L3/L4 grids and
every 1-D transect, across all surf locations** — multiple spots *and* the child grids drive L2's extent (the
"NESTOUT covers every child" rule in §3.1 is the hard constraint). The facing bearing's role in L2 is narrow: it
only sets the *direction along which the 30 m contour distance is measured* (`_compute_level2()` currently
averages `beach_facing_degrees`; `find_depth_contour_distance` runs once per spot). So the per-transect change is
small — measure the offshore contour per-transect and let L2 **enclose the union** (the same covering envelope L2
already computes over all spots and children), rather than pick one representative bearing. The only genuinely
new sub-detail is whether the per-transect contour rays feed that envelope directly or via a per-spot summary —
surface it, but it does **not** reopen L2's coverage-driven sizing.

### 3.3 What CHANGES

1. `beach_facing_degrees` source → isobath shore-normal, not segment-perpendicular; single value for a straight
   beach, **per-transect** where the shore curves (this is the reopened Amdt 2 §3 item).
2. Transect bearings → per-transect isobath-normal (implements the already-documented SURF-ZONE §2.6 design).
3. Water-body classification runs **first** and selects the physics regime (open-ocean swell vs. fetch-limited
   basin) and the parameter values. *(This re-purposes the existing multiply-consumed `classify_region` — a
   responsibility change, trigger 2, not a greenfield classifier; see §2.)*
4. **The fetch/openness fan (a ray-cast fan over the coastline layer) replaces the typed 8-sector
   `directional_exposure` AND becomes the source of "where open water actually is."** From one geography-aware
   fan come both: (a) per-direction **exposure/sheltering** — structures, headlands, opposite shores fall out of
   the geometry; and (b) the **actual open-water direction**, which now **aims L1's offshore reach and selects
   the WW3 boundary sides** in place of the beach-facing bearing (**operator direction, 2026-07-30**). This is
   the fix for the case the beach-normal gets wrong: at a bay, a curved shore, or an island-sheltered spot,
   "offshore = the beach normal" aims L1 (and the incoming wave spectrum) at the wrong water — or at land. Open
   water is a geographic fact, not the beach's perpendicular. *(Architectural: changes an L4 sizing input +
   surf-scoring (trigger 4/7, §3.5 coupling 4) AND how L1's extent/aim and the WW3 boundary sides are determined
   (trigger 3 — a model extent/boundary input, §3.5 coupling 3). Operator approval required; record in the plan
   ledger when this brief feeds the plan.)*
5. Shoreline for study-area definition → the OSM coastline the operator already traces on (§4), not the DEM 0 m
   crossing.
6. **L4-coverage decoupling — ALREADY IMPLEMENTED; this brief proposes NO handoff-flow change.** An earlier
   draft here specified a new "seaward-most valid intersection with L4" handoff-selection rule and attributed
   `degraded_bulk` (TA-C22) to a transect "selecting an out-of-grid exception cell (Hsig = −9)." **Both are
   wrong against the verified record and are struck** — this is exactly the kind of relitigation of working code
   this brief must avoid:
   - The per-transect L4-coverage handoff **already works** (plan **T1.2b, commit `d803d9c`, ✅ FIXED+VERIFIED
     2026-07-30**): a partial-coverage transect (e.g. #31) "correctly uses its own L4 column as far as it
     reaches"; 32/32 transects resolve their own L4 handoff, 0 % clamp.
   - The handoff **cannot** select an exception cell: it **excludes the grid-boundary station and clamps to an
     interior L4 cell** (**TA-C23** `CONCERNS:50`), and the TABLE parser drops Hsig ≤ −9 rows at parse time
     (`PROVIDER-MANUAL:1907/:1923`).
   - TA-C22's own code-traced root cause is **not** a handoff-selection defect. It is (a) `_run_pipeline_per_transect`
     setting `_degraded = bool(bulk_fallback_transects)` so any *one* transect flags the whole hour, and (b)
     transect 31 lacking its own PT* swell partitions at its handoff from ~hour 32 (`CONCERNS:54-59`). The
     operator-tracked fixes are **(a) grade `modelStatus` by fraction degraded** (a data-contract change to
     `modelStatus` values — trigger 4, needs approval) and **(b) root-cause the PT* gap** (non-architectural if
     a bug). Neither is a handoff-flow redesign, and neither belongs in a *geometry* brief.

   The decoupling this brief actually needs from §1 defect 3 is already true: because a partial-coverage transect
   uses its own L4 column as far as it reaches, **L4's box need not cover every transect**, so L4's orientation
   can stay a pure area-optimization. That is a *consequence of already-shipped behaviour*, not a change to
   propose here. **If** the operator does want the handoff selection itself changed, that is a governed STOP
   boundary (FINDINGS D3, PHASE-D-GATE-D `:100-104`) that must be recorded in the plan's Operator-decisions
   ledger and go through the ADR-093 Amendment 5 path **before** any brief specs it — it is not carried by this
   brief and no such direction is in the ledger today.

**Two independent items, do not conflate:** (1–2) the transect **orientation** is genuinely wrong — segment-
perpendicular (238.02° at HB), ~13° off the true shore-normal, because it inherited the shoreline-segment
perpendicular (the v1 placeholder) instead of the isobath-normal (§1 defect 1) — **this is what the brief fixes.**
The transect **handoff / L4 coverage** is a *separate, already-working* concern (T1.2b), with only the tracked
TA-C22 truthfulness-signal residual open. The orientation fix neither depends on nor changes the handoff.

### 3.4 What is PRESERVED (explicitly not touched)

- **L4 rotation stays on the structure principal axis** (approved). Multi-obstacle case: fix the *degenerate axis*
  (§1 defect 3) — one wedge per cluster on the cluster's principal axis (FINDINGS `:584`) — without changing that
  L4 rotates to the structure.
- All of §3.1 (every sizing/handoff/nesting/freeze number).
- The setup-time freeze and cold-start-on-geometry-change guard.
- The 2D→1D handoff surface and control flow.
- L1/L2/L3 stay axis-aligned.

### 3.5 The couplings to watch (more than one)

The orientation/exposure change touches **four** existing sizing inputs. None of the sizing *formulas* changes —
but each takes the derived bearing or exposure as input, so re-running sizing with the new values is mandatory:

1. **Facing → L3/L4 alongshore.** Beach facing feeds the **shadow-envelope direction that sizes L3/L4 alongshore**
   ("predominant wave direction", FINDINGS §3.2; ADR-093 Amdt 1 §2).
2. **Facing → L2/L3 offshore extent.** It sets the ray along which `find_depth_contour_distance` measures the
   30 m/15 m/1.78 m contours (so it perturbs L2/L3 *extent*).
3. **Facing → L1/L2 offshore placement & WW3 boundary sides — NOT rotation.** L1 and L2 are **axis-aligned
   lat/lon boxes**; the facing bearing does **not** rotate them (only L4 rotates). It sets the *direction of the
   offshore-extension point* that is then folded into the box's min/max (`_compute_level1()` `swan_domain.py:980-996`,
   `_compute_level2()` `:1072-1106`) — so it only nudges **extent/placement**, which an oversized L1 largely
   forgives. The load-bearing coupling is different: **the same `mean_offshore_bearing_deg` drives WW3 boundary
   side-selection** — `ww3_station_selection.py`'s choice of which sides of L1 the incoming spectrum enters
   through (verified: `swan_domain.py:31-41` docstring — "silently decides which sides of the domain the incoming
   wave spectrum enters through"; C-94). **Operator direction, 2026-07-30: L1 can no longer take this from the
   beach-facing bearing at all.** L1's offshore reach and its WW3 boundary sides must come from the
   **geography-aware open-water direction** — the §3.3.4 fetch/openness fan (where open water actually is, past
   bays, headlands and islands) — not the beach normal. So this stops being a "preserve and re-run" coupling and
   becomes part of **what CHANGES** (§3.3 item 4): the current `mean_offshore_bearing_deg` L1 aim is itself one
   of the inadequate parameters this brief replaces. Until it lands, at minimum re-run WW3 boundary
   viability/side-selection against any re-aimed L1.
4. **Exposure → L4 across-axis (the coupling an earlier draft missed).** `directional_exposure` is not only a
   scoring input — it is a **sizing input to L4**: `compute_structure_grid_domain(directional_exposure=...)`
   (`swan_domain.py:1803`, `:1998-2003`) uses the active sectors as the swell-climate window for the shadow-union
   envelope that sizes L4's across-axis and decides which sides are illuminated (§3.1 row "L4 across-axis =
   shadow-union + 2λ each side"). So the §3.3.4 fetch-fan exposure change (replacing `directional_exposure`)
   **perturbs a FIXED L4 sizing input** and also gates surf-scoring (`enrichment/surf_scorer.py`). It is a
   wizard field / config key (`OPERATIONS-MANUAL.md:961`) → trigger 4/7 + wizard help-content doc-sync.

**Most of these are grid-geometry changes** that trip the F1 cold-start guard and forced full run — **but the
guard today compares L1/L2 bbox+resolution and the L3 clusters, NOT L4** (`ARCHITECTURE.md:105`). Extending it to
L4-only changes is Phase-5 **D6b** (approved but **open**). So an **L4-only** across-axis change — the exposure
coupling (#4), with L1/L2/L3 unchanged — does **not** trip the guard until D6b lands, and would warm-start on a
hotstart sized for the old L4. **Sequence D6b before any L4 resize.** Otherwise expect a cold-start after adopting
these. **Instruction stands: change the derivation, re-run the *existing* sizing with the new bearing/exposure,
re-assert the existing viability test and NESTOUT-coverage guard — do not change the sizing formulas.**

---

## 4. Data source & the two-stage model (operator decisions, 2026-07-30)

**Single global coastline = OSM.** It is the basemap the operator already traces on, and OSM `natural=coastline`
is a single, regularly-rebuilt global land/water-polygon layer — "global, one source, not 20." Crowd-sourced
accuracy varies (accepted; it's the same coastline the operator sees). This also closes the current
**trace-on-OSM / size-from-DEM** inconsistency (§1 defect 4).

**Two-stage: OSM bootstrap → bathymetry refine** — which maps cleanly onto the *existing* L1-coarse/L2-fine data
split (ADR-098: L1 = ETOPO global, L2/L3 = regional DEM):
- **Stage 1 — OSM (global, coarse):** coastline, **water-body classification**, the **fetch/exposure fan**, and
  the bathymetry download footprint. **L1 is the super-sized, axis-aligned margin grid** — oversizing *is* the
  margin, so its box *placement* is forgiving and it is never *rotated*. But its **offshore aim and WW3 boundary
  sides are NOT free** — they come from the fan's open-water direction (operator direction 2026-07-30, §3.3 item
  4 / §3.5 coupling 3), because at a bay, curved shore, or island-sheltered spot the beach normal points at the
  wrong water. Frozen after this stage. *(This corrects the earlier "L1 orientation/placement is immaterial"
  claim: placement is forgiving; open-water aim is not.)*
- **Stage 2 — local bathymetry:** the **precise facing** and the **inner nests (L3/L4) + transects** — where the
  orientation problem actually lives. Facing from the **shallow isobath *heading*** (2 m/5 m contour trend), not
  the 0 m line: isobaths steer refraction, and a contour's heading is **datum-robust** (a datum shift slides a
  contour, barely rotates it) — sidestepping the datum sensitivity of §1 defect 4.

**Self-checking:** stage-1 OSM coastline heading vs stage-2 isobath heading is its own validity test — agreement
⇒ trust both; sharp divergence ⇒ auto-flag (bad OSM coastline *or* anomalous bathymetry). No separate flagger.

**Two clarifications (operator):** (1) the stage-1 download-margin worry is largely covered because **L1 is
already super-sized**; (2) **bathymetry availability gates region expansion** (US-only today for that reason) —
securing a source is part of opening a region, so stage 2 always has bathymetry where coverage exists; the
"no fine bathymetry" case is an error/transient, and **OSM remains the only layer that must be truly global**.

---

## 5. Relationship to the existing briefs/ADRs (do not re-litigate)

> **⛔ SUPERSEDED 2026-08-02 (H3, MARINE-FORWARD-PLAN.md).** The second and third bullets below describe this
> brief's transect-facing proposal as implementing "SURF-ZONE §2.6's documented-but-unbuilt isobath design" and
> reopening ADR-093 Amendment 2 §3's deferral of *contour-orientation* derivation. Both bullets are superseded:
> the facing question was closed 2026-07-31 by **AD-1R** (ADR-093 Amendment 5) with a **smoothed 0 m shoreline
> normal**, not isobath/contour-orientation derivation — a different method than either this brief or SURF-ZONE
> §2.6 proposed. Text below is left unchanged as the historical record — do not read it as describing current
> behavior.

- **Do not reopen L4 rotation as an efficiency question.** SWAN-GRID-STRATEGY-RESEARCH-BRIEF `:227-231` rejected
  rotating outer grids to the beach; FINDINGS D6 approved rotating **only L4** to the structure axis. Settled.
- **This brief's transect-facing change *implements* SURF-ZONE §2.6's documented-but-unbuilt isobath design** —
  it is not a new invention; it closes a known gap.
- **It *reopens* ADR-093 Amendment 2 §3's deferral** of contour-orientation derivation. State that explicitly and
  keep the reopening inside the fixed sizing set (§3.1).
- **A "study-area extent" sizing mechanism already exists** (PHASE-E-DEPLOY-RESUME-28b `:70-72`: per-cluster
  study-area = transect corridor ∪ L3 grid ∪ structure polygon ± margin). Build the geometry change on top of it,
  don't reinvent domain sizing.
- **Handoff geometry is a governed STOP boundary** (P4B agent tripwires; PHASE-D-GATE-D `:102-103`): moving the
  handoff point / changing what feeds the 1-D model is architectural — this brief does **not** propose to.

---

## 6. Resolved by research / best-practice (not operator preferences) + the remaining choice

> **What "not operator preferences" means here — and what it does NOT mean.** The *method* for each item below
> is settled by research/best-practice, so there is no knob for the operator to tune. But **adopting** any of
> them is still an **architectural change requiring explicit operator approval** — several trip the trigger list
> (a criterion/formula, a component responsibility, a wizard field / config key, the L3-enable trigger). "The
> method is decided" is not "the change is authorized." Each item is tagged with its trigger below.

**Scope — DECIDED (operator 2026-07-30): US + Great Lakes, now.** Every US setting must be supported: open-ocean
straight beaches, point breaks / curved shores, island-sheltered coasts (SoCal Channel Islands, Hawaii
inter-island), and the Great Lakes. Non-US intricate coasts (Aegean archipelago, fjords) are out of near-term
scope but the architecture must not preclude them.

1. **Operator break-type classification — DROP it, derive it.** *(Architectural: trigger 1/2/7 — changes the
   **L3-enable criterion**, moves a **responsibility** from operator to derived computation, and removes a
   **wizard field / config key** (`topographic_feature`, `OPERATIONS-MANUAL.md:961`). It **amends ADR-093
   Amendment 2 §3**, which deliberately chose operator classification precisely because contour-shape derivation
   "is specified nowhere and built nowhere." Operator approval required; wizard help-content doc-sync required.)*
   `topographic_feature` (point/headland/bay) exists only because contour-shape derivation was never built (the
   explicit ADR-093 Amdt 2 §3 rationale). The orientation fix builds exactly that; a point break/headland *is*
   measured curvature in the shoreline/isobaths, so both the facing and the L3-refraction trigger become
   derivable. Note the L3 trigger **currently reads `topographic_feature`** (ARCHITECTURE.md:105: "L3 turns on
   when a manmade structure is discovered OR the operator classifies…"), so re-sourcing it is not a no-op. Stop
   asking the operator to classify — they only draw the surf area. Keep classification only as an optional
   override for a feature bathymetry can't see at grid resolution (e.g. a submerged reef).
2. **`D_open` — regime-dependent, set by research:**
   - **Ocean (swell):** a direction is "open" if the fetch ray reaches deep water past the shelf where the WW3
     boundary is valid (SWAN-manual deep-water-boundary rule) — the shelf-edge scale (tens of km) L1 already
     reaches. Not a tuned knob.
   - **Fetch-limited (Great Lakes):** no "open ocean"; the **fetch value itself** drives wind-sea growth. Surfable
     is measured — 15–20 mph (winter)/20–25+ (summer) winds for 4+ h; >2 ft works, 3–6 ft routine; surfable
     fetches run tens–hundreds of km (Lake Superior 300 mi → 13 ft @ 10 s). Minimum surfable fetch ≈ order tens of
     km. The fetch fan yields it directly.
3. **`L_shore` — best-practice method, not a knob.** Facing = perpendicular to the **local depth contours** (waves
   refract toward the shore-normal, Snell), computed **per-transect** from a **smoothed** shoreline. Smoothing
   scale ≈ surf-zone width to a few hundred metres (kills cusps/water-level noise, keeps real curvature); the
   ~300 m study segment is the natural alongshore extent.
4. **Islands are MODELLED, not flagged.** A significant island in the swell window is **included in the domain**
   (size **L1 to enclose it and the deep water beyond**) so SWAN computes its sheltering/refraction/diffraction —
   "draw L1 large enough to go around the island." Mandatory for US (SoCal Channel Islands; Hawaii inter-island
   wrap). A **domain-sizing rule**, physics-driven — not an operator flag.
5. **"Boxed-in" spots are a natural limit, not a special case.** If the fetch/exposure fan shows insufficient open
   water/fetch in every direction (large islands close together, a tight cove), the spot has no surfable waves and
   the exposure computation says so directly. No special handling.

**Remaining genuine operator choice:**

6. **Multi-obstacle L4 handling — proximity clustering, not an either/or** (operator, 2026-07-30). Each obstacle
   gets a box of at least a **minimum size** (to resolve it + its shadow at 10 m). Boxes that are **close merge**
   into one; **far-apart** ones stay **separate** — the same rule as the existing <500 m spot-clustering
   threshold, applied to obstacles. Each box wraps its obstacle(s): a single obstacle keeps the structure axis
   (approved); a merged box takes the enclosing orientation of the merged footprint. The transect-31 handoff fix
   (§3.3.6) already means a box need not cover every transect. So this is a **sizing/clustering rule**, not an
   orientation *choice*. (Open sub-detail: the exact merge distance and minimum box size — a best-practice number
   to set, analogous to the <500 m spot threshold.)

**Verify, don't decide — Great Lakes boundary routing (correction 2026-07-30).** Earlier text here wrongly said
"WW3 is ocean-only." **WW3 covers the Great Lakes:** NOAA runs **GLWU** (Great Lakes Wave Unstructured, a
WAVEWATCH III implementation, ~50 m coastal → 400 m offshore, NDFD-wind-forced), operational to 11 Great Lakes
WFOs. So the regime branch is **selecting the GLWU WW3 product vs the ocean WW3 grid** by water body — *not*
abandoning WW3; the fetch-limited/short-period character comes through in GLWU's own boundary spectra. The
Great-Lakes-specific piece that *does* remain: **L1 cannot be sized by the continental-shelf edge** (no shelf) —
it needs lake-geometry/fetch bounding. **Code check — DONE (this review):**
- **GLWU routing already exists.** `product_for_extent()` (`ww3_station_selection.py:1300-1316`) classifies the L1
  extent centre and routes a Great-Lakes region to the `glwu.grlc_2p5km` product, refusing loudly
  (`BoundaryNotViableError`) on a mis-route. So the WW3-product half of the regime branch is built.
- **L1 shelf sizing has NO Great Lakes branch and would silently misbehave.** `_compute_level1()`
  (`swan_domain.py:956-965`) sizes L1's offshore extent from `find_shelf_distance(center)`, which
  (`shelf_boundary.py:60-67`) returns the haversine distance to the nearest point of the **global ocean** GSFM
  polyline. For a lake centre that is the distance to the nearest *ocean* shelf (not `None`), so L1's offshore
  edge would be pushed ~10 km past a shelf that is nowhere near the lake — an absurd L1. **This is the real
  Great-Lakes gap:** L1 offshore sizing needs a lake-geometry/fetch bound where there is no shelf. The routing is
  done; the L1-sizing branch is not.

---

## 7. How this brief reshapes `MARINE-WORKING-MODEL-PLAN.md` (supersede / reshape / retain)

This geometry model does **not** supersede the whole plan. It leaves **Track A** intact, **reshapes Track B**,
and **resolves two Phase 5 items**. This section is the task-level map so the re-plan is explicit and Track B is
not executed as-written against a premise this brief has changed. *(Coordinator + Fable had not mapped this
interaction in the first review pass; this section closes that gap and has since been **Fable-adversarially-checked
(2026-07-30), its 9 findings verified against code/plan and incorporated**.)*

### 7.1 Track A (get a working model) — RETAINED in content, with a required downstream re-validation
Phase 0 (instrumentation/deploy) is done; Phase 1 **M1's computation criterion is met** — but its closure items
remain **open** and carry forward: the **66 h vs 72 h** window (TA-C16), a **formal blind audit** of the full
served forecast, and **revalidation at larger/multi-swell seas** (validated at ~1 m swell only). Phases 2–3
(spectrum, handoff, reality gate) are the working-model spine, **independent of orientation in their content**.
The brief builds **on** the now-working model, and per §3.3 item 6 the orientation fix neither depends on nor
changes the handoff. **One caveat, do not miss it:** the per-transect bearing flows into `compute_transect_shadows`,
so it changes which transects are structure-affected — and thus the **headline-aggregate composition** the Phase-3
reality gate validated. So *after* the bearing change lands, **re-validate the served headline vs the
contemporaneous cam** against the Phase-3 pinned tolerance. Track A's task *content* is unchanged; its reality
gate is simply re-run downstream of the new geometry. TA-C22 stays a tracked truthfulness-signal residual (fix
(a) modelStatus grading / (b) PT* gap), not a geometry item.

### 7.2 Track B (obstacle representation overhaul) — RESHAPED (the interaction that had been missed)
Track B's *mechanics* (T4.0–T4.6) largely stand, but the brief adds the geometry/orientation **layer** Track B
lacked, and it **unifies a primitive Track B was about to build separately**:

| Plan task | Interaction | What the re-plan must do |
| --- | --- | --- |
| **T4.0** structure-geometry normalizer — computes an **oriented minimum bounding box (OMBB)** for centerline+width | **Same primitive** as §1 defect 3 / §6.6's **min-area enclosing rectangle** for the L4 axis (verified: no OMBB helper exists anywhere in the marine repo; `compute_structure_grid_domain` uses the separate `_most_distant_pair` two-point axis, `swan_domain.py:1904-1911`) | **Build the OMBB helper once** in `structure_geometry.py` (shapely `minimum_rotated_rectangle`, already a dep); have **both** the L4-axis sizing and the obstacle router consume it. **Two caveats:** (a) the **inputs differ** — T4.0's OMBB is of the *structure polygon alone*; §1 defect 3 / §6.6's is of the *obstacle-plus-shadow* (or merged-cluster) footprint — **same helper, different call geometry**, not one call site; (b) `_most_distant_pair` also drives **base/tip identification + the tip-depth + 1-wavelength along-axis margin** (`swan_domain.py:1904-1939`, tip = farther-from-anchor), so re-deriving the axis from the OMBB must **re-anchor tip/base selection**. Extend T4.0's Accept to the multi-obstacle cluster case. |
| **T4.0 / T4.1** normalize + route one structure | §6.6 adds **multi-obstacle proximity clustering** (merge-when-close/separate-when-far, the <500 m spot rule applied to obstacles) + a min box size | **New Track-B task**: after per-structure normalize, cluster the boxes, then size L4 per cluster. Sequence: normalize → cluster → size. |
| **T4.2** burn structure footprints into the **L4** BOTTOM grid | §3.3.4 exposure→L4 sizing **re-sizes the same L4 grid**; both mutate L4 | Sequence: L4 sized with the **new exposure-derived** across-axis **then** footprints injected on the sized grid. **The F1 cold-start guard does NOT cover L4-only changes until Phase-5 D6b lands (§3.5, §7.3) — sequence D6b first, or an L4 resize warm-starts on a stale hotstart.** |
| **T4.4** shadow diagnosis (**done**, verdict (ii): 0/32 geometrically correct **for the current uniform 238.02° bearing only**) | The shadow test runs at `beach_facing ± 30°` per transect, so **per-transect isobath-normal bearings change the tested angles/spans** — re-opening the 0/32 result, the structure-affected exclusions, and the **OPEN TA-C21** invariant-3 rescope (CONCERNS; criterion change, trigger 1). Plus §6.1's curvature-derived break-type (L3-enable trigger) | **Re-run shadow classification after the bearing change** — verdict (ii) holds for current geometry *only*; **fold TA-C21's invariant-3 rescope into the geometry plan**; reconcile the derived classification with the shadow geometry. |
| **T4.5** structure-coord round-trip guard (C-E02) | **Independent of the geometry model** — a data-loss guard test on a bug that may already be fixed | **Proceed as-written, now.** Do not defer it into the geometry pipeline. |
| **T4.6** draw-tool polygon mode | §4 makes **OSM** the coastline/study-area basis the operator traces on — same operator-drawn-geometry UX | Merge T4.6 with the §4 OSM tracing UX design. |

Track B's **operator sign-off gate** (bathymetry-injection fork T4.2, coefficients T4.3, draw-tool T4.6) is
**unchanged and still required** — the brief adds architectural items to that same gate (the geometry model
itself, §3.3/§6), it does not relax it.

### 7.3 Phase 5 (Track C) — one item folded-in-as-a-gate, one prerequisite, the rest STAND
- **D6c (enlarged-L1 Bolsa → 0 qualifying WW3 stations → every cycle refuses) — EXPECTED to be addressed by the
  L1-aim change, but NOT pre-resolved.** The facing→L1-aim→WW3-side coupling is real and shared (§3.3 item 4,
  §3.5 coupling 3), so folding D6c into the geometry work is legitimate — **but D6c's root cause was never
  diagnosed.** The 0-stations result could be the two-spot **lateral-union** enlargement moving the boundary past
  the ~18.5 km station-distance criterion, or catalogue density near the new boundary, *as well as* the
  mean-of-two-facings aim; the open-water fan changes the **aim**, which may only **partially** address it.
  **Carry D6c into the new plan as a validation gate:** root-cause it first, then validate with the real 2-spot
  Bolsa station-selection run before closing. Do not pre-mark it resolved.
- **D6b (extend the geometry guard to L4-only changes) — reinforced, and a PREREQUISITE.** The brief's L4-only
  across-axis change (exposure) will **not** trip the cold-start guard until D6b lands (§3.5, §7.2 T4.2) —
  sequence D6b **before** any L4 resize.
- **D6a (`grid_sizing_chain.py:1270` StructureConfig-vs-dict type bug) — carry it; it lives in the exact chain
  the geometry work edits, so fix it before/with that work** (§7.4 lists it in the carry-forward).
- **C-E10/11, C-E01/C-E03, C-E04, C-E08, C-E12, D7, doc drift, and the deferred T4.3 dynamic coefficients —
  STAND**, untouched by geometry.

### 7.4 Structure recommendation — a NEW plan that supersedes `MARINE-WORKING-MODEL-PLAN`, not brief-as-plan
The brief is a **design** document (every change architectural, pending approval); a plan is **task-level
execution**. Keeping the two separate is project rule (plan-stays-an-index; briefs-feed-plans). So:
1. **This brief carries the map above** — its correct role — and stays the design authority the new plan cites.
2. **After operator approval, create a NEW plan** (e.g. `MARINE-GEOMETRY-MODEL-PLAN`) that **supersedes**
   `MARINE-WORKING-MODEL-PLAN`. **Do a full task-by-task carry-forward audit of the source plan — do NOT trust
   its execution-status summary, which conflicts with its own task detail** (it lists T2.3 as remaining work while
   T2.3 is actually DONE + Gate-2 audited, `plan:1165-1186`). Concretely:
   - **(a) Carry forward Track A's genuinely open items:** T1.3, T2.2 PART B (residual half-applied fix),
     **T2.3's residuals only** (operator push/deploy + the deferred first-multi-swell-day reality validation +
     the auditor CLAIM-2 divergence check — **NOT** re-implement it), T3.1, the Phase-F conditional (T3.2, gated
     on re-recording the pre-approval); plus the **M1 closure items** (TA-C16 66 h window; formal blind audit;
     larger-sea revalidation), the approved gate-cleared **cadence/performance lever**, **TA-C21** (invariant-3
     rescope, now geometry-coupled per §7.2 T4.4), and **TA-C22 fixes (a)/(b)**.
   - **(b) Replace Track B** with a geometry-integrated structure-and-study-area track folding this brief's model
     into Track B's still-valid T4.0–T4.6 mechanics (OMBB unified per §7.2), **sequencing D6b before any L4 resize.**
   - **(c) Carry Phase 5's open items:** **D6a** (`grid_sizing_chain.py:1270` type bug — in the chain the geometry
     work edits; fix before/with it), **D6b** (prerequisite), the deferred T4.3 dynamic-coefficient design task,
     C-E10/11/01/03/04/08, C-E12, D7, doc drift — and **D6c as a validation gate** (§7.3), not struck.
3. **Do not amend `MARINE-WORKING-MODEL-PLAN` in place.** Its Track B tasks are now partly stale against this
   brief, and a top-down reader would execute them as-written — the exact failure the restoration plan's
   "document order is execution order" warning exists to prevent. A clean superseding plan avoids that.

This is a recommendation, not a decision — the supersede-vs-amend call and the new plan's name/shape are the
operator's. Nothing here is built until that call and the architectural sign-offs land.

---

## 9. Directional sector optimization for L2/L3/L4 (added 2026-08-07)

**Problem.** SWAN allocates spectral arrays proportional to `grid_cells × directions × frequencies`.
All four grid levels currently use `CIRCLE 72` (full 360° at 5° resolution). On a memory-constrained
host (5.7 GB LXC container), L2's spectral arrays alone consume ~740 MB. When a radar container
(~3.2 GB resident) is also running, the SWAN cycle OOM-kills during L2 execution.

**Observation.** Nearshore grids (L2/L3/L4) do not need the full 360°. Swell arrives from the open
ocean — a limited directional sector. Directions facing into the coast carry near-zero energy
(no significant reflectors besides structures, and reflection is handled by OBSTACLE). The SWAN User
Manual §2.6.3 (line 807–808) explicitly names this: "This may be convenient (less computer time
and/or memory space), for example, when waves travel towards a coast within a limited sector of 180°."

**Measured test case (2026-08-07, Huntington Beach).** Using the actual `geography.py`
`cast_fetch_fan()` ray-tracing against real OSM coastline data (81 LineStrings), firing from each
grid's perimeter points (4 corners + 4 edge midpoints for bbox grids; 4 corners for rotated L4):

| Grid | Perimeter union | Blocked | Memory reduction | Bins 72 → |
|------|----------------|---------|-----------------|-----------|
| L2 (6,150 cells) | 220° | 140° | **39%** (~290 MB) | 72 → 44 |
| L3 (2,445 cells) | 215° | 145° | **40%** (~48 MB) | 72 → 43 |
| L4 (8,619 cells) | 205° | 155° | **43%** (~130 MB) | 72 → 41 |
| Beach centroid (existing fan, for comparison) | 185° | 175° | — | — |

Combined savings: **~468 MB** — sufficient for coexistence with the radar container.

**Key finding: the perimeter-union is wider than the beach's own view.** L2's 220° sector is 35°
wider than the 185° seen from the beach, because L2's offshore corners can see around headlands
that block the beach's view. This validates the operator's direction (2026-08-07) that the ray fan
must fire from the grid's boundary perimeter, not from the beach centroid — using the beach fan
would clip diagonal waves entering through the corners.

### 9.1 Design

**SWAN command change:** replace `CIRCLE 72 0.03 1.0 34` with
`SECTOR <dir1> <dir2> 72 0.03 1.0 34` on L2/L3/L4, where `<dir1>` and `<dir2>` define the open-
water sector boundaries. L1 stays `CIRCLE` (shelf-scale, swell from any direction). The `72` in
SECTOR is the number of directional bins within the sector — SWAN distributes them evenly, so fewer
degrees = coarser resolution per bin unless the bin count is also reduced. To preserve the 5°
resolution, set the bin count to `sector_span / 5`.

**Computation (setup-time, once per spot/grid — not runtime):**

1. At config-push time, after `compute_domains()` produces the L2/L3/L4 bounding boxes, compute 8
   perimeter points per grid (4 corners + 4 edge midpoints; for rotated L4, use the 4 actual corners
   + 4 edge midpoints of the rotated rectangle).
2. For each perimeter point, call `cast_fetch_fan()` with the same coastline geometry and land-size
   thresholds the existing L1-aiming fan uses — `directly_open` and `wrap_candidate` rays are
   "open," `truly_blocked` are "blocked."
3. Take the **union** of open-water bearings across all perimeter points. This is the minimum
   sector that carries energy into the grid from any boundary point.
4. **Pad by 15°** on each end for refraction spread and wind-sea from oblique wind directions.
5. Store the sector boundaries in the grid-sizing cache alongside the bbox/resolution.
6. `build_swan_input()` emits `SECTOR` when the computed sector is < 330° (a threshold below which
   the savings are material); otherwise stays on `CIRCLE` (near-360° sectors save nothing and add
   code complexity).

**Multi-spot grids (L1 and L2).** L1 and L2 are shared across all spots in a deployment. L1 stays
`CIRCLE` regardless. For L2, the sector computation fires from **L2's own perimeter** (which
already encloses all spots and all child grids). The open-water union from L2's 8 perimeter points
is the correct sector for L2 — it does not depend on how many spots are inside it, because it
measures what directions can deliver energy across L2's boundary, not what any individual spot sees.
L3/L4 are per-cluster and already cluster-scoped. **No change to grid sizing, nesting, or the
NESTOUT/BOUNDNEST1 chain.** The sector is a spectral-resolution parameter on the CGRID command
only; everything else (grid geometry, nesting I/O, handoff selection) is unchanged.

**L4 and diffraction.** L4 runs DIFFRACTION for pier/structure effects. Diffraction can redirect
energy into directions outside the incoming sector. However, the SECTOR command only limits which
directions SWAN propagates — diffracted energy that wraps around a structure into a "blocked"
direction would be lost. For L4, pad the sector by an additional 30° (total 45° per side) to
accommodate diffraction spreading, or keep L4 on CIRCLE if the padded sector exceeds 330°. The
test case shows L4's unpadded sector is 205°; with 45° padding on each side = 295° — still a 18%
reduction (72 → 59 bins). Decision: operator.

**Performance.** The ray-tracing from 8 perimeter points takes ~2 minutes in the current pure-Python
implementation. Optimization paths (not blocking this task, but noted for follow-up): Shapely
`STRtree` spatial index for coastline geometry lookups (10-100× speedup); NumPy-vectorized ray-step
generation; GPU acceleration via RAPIDS cuSpatial or Numba CUDA for large-scale multi-spot
deployments. For a setup-time computation that runs once per config push, 2 minutes is acceptable
as-is.

### 9.2 What this does NOT change

- L1: stays `CIRCLE 72` (full 360°) — shelf-scale, swell from any direction
- Grid geometry (bbox, resolution, nesting): unchanged
- NESTOUT/BOUNDNEST1 spectral boundary handoff: unchanged (SWAN interpolates spectra between
  different directional grids at nesting boundaries — SWAN User Manual §2.4)
- Handoff selection (first-match L4→L3→L2): unchanged
- SwellTrack/SurfBeat: unchanged (they consume the handoff spectrum, not the directional grid)
- Spectral frequency resolution: unchanged (34 bins, 0.03–1.0 Hz)

---

## 10. Sources (renumbered from §8)

**Internal — ADRs/rules:** ADR-093 (+Amdt 1–4) `docs/decisions/ADR-093-swan-trushore-nearshore-model.md`;
ADR-095, ADR-097, ADR-098; `rules/clearskies-process.md:272,284,288,290-300`. SWAN User Manual (in-project
`docs/reference/swan-user-manual.txt`) §2.4 nesting lines 424-435, 539-543.

**Internal — manuals:** `docs/ARCHITECTURE.md:99-127`; `PROVIDER-MANUAL.md §14.15:1845-2196`;
`OPERATIONS-MANUAL.md:801-964`; `API-MANUAL.md §17`.

**Internal — briefs:** SWAN-GRID-STRATEGY-RESEARCH-BRIEF + -FINDINGS (§3.1 L520-529, D6 L203-211);
SWAN-NESTING-RESEARCH-BRIEF; L3-1D-BOUNDARY-DECISIONS-BRIEF; SURF-ZONE-MODEL-BRIEF §2.6; T4.4-SHADOW-DIAGNOSIS
`:25-27`; PHASE-E-SESSION-LOG `:374-391`; PHASE-E-DEPLOY-RESUME-28b `:70-72`; BATHYMETRY-RESOLUTION-BRIEF `:175`.

**Internal — code:** `config/marine_config.py:505-510,569-576`; `services/swan_domain.py:1904-1911`;
`enrichment/bathymetry.py:1364-1406`; `services/swan_formats.py:752`.

**External best practices:** WW3 15° directional-increment error near islands & nested SWAN offshore forcing —
[ScienceDirect S0029801821009409](https://www.sciencedirect.com/science/article/abs/pii/S0029801821009409),
[NCSU CCHT SWAN](https://ccht.ccee.ncsu.edu/category/models/swan/). Enclosed/fetch-limited basins —
[MDPI Water 14/7/1087](https://www.mdpi.com/2073-4441/14/7/1087),
[USGS 70251488](https://pubs.usgs.gov/publication/70251488),
[ScienceDirect S0380133024002119](https://www.sciencedirect.com/science/article/abs/pii/S0380133024002119).
Islands/archipelagos — [Copernicus OS 15/1469/2019](https://os.copernicus.org/articles/15/1469/2019/),
[ScienceDirect S0029801813003569](https://www.sciencedirect.com/science/article/abs/pii/S0029801813003569).
Coastline datasets — [GSHHG](https://www.soest.hawaii.edu/pwessel/gshhg/),
[30 m Global Shoreline Vector](https://www.tandfonline.com/doi/full/10.1080/1755876X.2018.1529714).
Great Lakes fetch-limited surf (wind/fetch/period thresholds) —
[Surfer Today: surfing the Great Lakes](https://www.surfertoday.com/surfing/the-ultimate-guide-to-surfing-the-great-lakes),
[Wikipedia: Lake surfing](https://en.wikipedia.org/wiki/Lake_surfing). WW3 covers the Great Lakes via GLWU —
[GMD: Great Lakes wave forecast system on unstructured meshes](https://gmd.copernicus.org/articles/17/1023/2024/),
[BAMS: NOAA's Great Lakes Wave Prediction System](https://journals.ametsoc.org/view/journals/bams/104/4/BAMS-D-22-0094.1.xml),
[GLERL WW3 waves](https://www.glerl.noaa.gov/emf/waves/WW3/). Shoreline orientation & refraction toward
the shore-normal (per-transect facing on non-straight coasts) —
[ScienceDirect S1463500315001778](https://www.sciencedirect.com/science/article/abs/pii/S1463500315001778),
[Longshore wave variability along non-straight coastlines](https://www.researchgate.net/publication/326515489_Longshore_wave_variability_along_non-straight_coastlines).
