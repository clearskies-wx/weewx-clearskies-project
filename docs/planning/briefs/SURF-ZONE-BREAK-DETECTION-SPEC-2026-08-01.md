# SURF-ZONE BREAK DETECTION & REPORTING — DESIGN SPEC (DRAFT — awaiting operator sign-off)

**Date:** 2026-08-01 · **Status:** DRAFT — operator rulings captured from chat, same day; NOT yet
approved for implementation. No code changes are authorized by this document until the operator
signs off in chat and the open parameters (§6) are ruled.

**Context:** written the same day the L4 shadow-envelope rewrite (marine `4e79d21`) passed its
full-run reality gate (L4 valid_fraction 100%, 143/143×35/35 per-transect handoff, published).
This spec covers the NEXT defect class, in the 1D/handoff layer: break detection.

---

## 1. Defect statement (measured, 2026-08-01 19:06 UTC run)

The 1D system's break handling contradicts its own design intent (SURF-ZONE-MODEL-BRIEF):

1. **Handoff picks the FIRST depth crossing and stops.** `select_hourly_handoff()` takes the
   first shore-outward crossing of `1.3·Hs/0.73` (`transect_handoff.py`), assuming a monotonic
   profile. On a barred (double-break) profile the first crossing lands in the TROUGH shoreward
   of the bar — the outer break's post-break foam zone. Measured this run: handoff at 1.05 m
   depth, single break reported per transect at 9–17 m from shore in 0.76 m water (the shore
   break only).
2. **The 1D break search domain is only handoff→shore.** Everything seaward is inside SWAN's
   domain, where breaking exists physically (dissipation, QB) but is never *reported* — no break
   location, no zones. A mid-pier outer break is structurally invisible in every published
   product, on every day.
3. **The SWAN-side scan never looks at the whole line.** The T4B.1 band brackets only the
   expected handoff depth (`_TRANSECT_BAND_PAD_FRACTION = 0.5`); SWAN's QB along the REST of the
   cross-shore line is computed and discarded.
4. **Structure exclusion is blanket.** `is_structure_affected` = crosses-an-obstacle → excluded
   from headline metrics regardless of whether the structure improves or degrades the wave.
5. **Headline metric is mean+max over open transects.** No main-break-zone concept; a single
   anomalous transect can own `best_peak_face_height_m`.

## 2. Operator rulings (2026-08-01, chat — the design authority for this spec)

- "Our handoff is not properly looking at the entire SWAN transect (not 1D transect) to find the
  point where each break is suspected — it finds the first one and just stops."
- "The handoff always needs to be calculated to take place seaward of the break — and
  considering there is a double break on this beach, it needs to detect that too."
- 1D transects that do NOT intersect L4: "they need to be looking for both breaks, and need to
  be reporting from the bigger of the two — the shoreward break is going to be smaller and not
  the one surfers will be looking for in most cases — but WE DO map both."
- "We also map a 2D cross-section seaward to shore showing the profile of the waves coming in
  and where the breaks, break zones and foam zones are. This needs to map both breaks. This is
  why we are using such fine detail on the 1D transects."
- "We also create a horizontal heatmap that maps a birdseye view of the beach … so surfers know
  where the best breaks are occurring."
- Headline metric: "take the average of the max breaks for the MAIN BREAK ZONE, where the waves
  are maximized within the entire study area — smooths single anomalies in a single transect but
  represents the best surf within the study area." (Deviation-band filtering around the mean.)
- Structure exclusion: only exclude structure-affected transects from headlines "if it is
  reducing the wave quality."
- (Earlier, standing:) the ENTIRE point of the 1D transects is to locate the peak, the break
  zone, the foam zones, AND double breaks.

## 3. Design requirements

**BD-1 — Full-line break-suspect scan (SWAN side).** For every transect, scan the ENTIRE
cross-shore line through the SWAN domain that covers it (L4 band through the whole grid crossing
for L4 transects; L3/L2 stations otherwise), using SWAN's own Hs, depth, and QB at each station,
plus depth-limited criterion `H ≥ γ·d` between stations, to identify EVERY suspected break zone
(entry point, extent, exit into foam/trough), ordered seaward→shore. Requires widening the
T4B.1 band to span the full grid crossing (station count cap revisited; cost measured before
adoption).

**BD-2 — Handoff seaward of the OUTERMOST break.** The per-hour handoff must land seaward of
break zone #1 (the outermost suspected break) with the existing 1.3× margin — never inside or
shoreward of it. The QB guard extends from "nudge within bracket" to "must clear the outermost
zone." First-crossing-of-target-depth is retired.

**BD-3 — 1D model maps BOTH breaks.** From the (now correctly seaward) handoff, the 1D model
walks its full fine profile and detects every break zone (outer/bar break, inner/shore break),
each with: break-point distance & depth, face height, breaker type, Iribarren, foam-zone extent
shoreward of it. Both are always published per transect.

**BD-4 — Report from the BIGGER break.** Per-transect headline face height = the larger break's
face height (usually the outer). The smaller break remains in the mapped output.

**BD-5 — Cross-section product carries the full anatomy.** The beach_profile `transect`
(hs_envelope) payload maps, at fine resolution seaward→shore: incoming Hs profile, every break
zone, and every foam zone — both breaks visible on a double-break day.

**BD-6 — Heatmap truth.** The quasi-2D heatmap (per-transect × cross-shore) must show break
zones spatially so the best-break locations are visible along the beach. Structure-affected
transects stay IN the heatmap (already true) and their break anatomy must be as complete as open
transects'.

**BD-7 — Main-break-zone headline metric.** Identify the MAIN BREAK ZONE: the alongshore region
of the study area where per-transect (bigger-break) face heights are maximized. Headline =
average of per-transect max face heights within that zone, filtered to transects within a
deviation band of the zone mean (band width: operator parameter, §6). Replaces bare mean+max as
the headline pair; `best_peak`/`spot_average` may remain as secondary fields for continuity.

**BD-8 — Quality-conditional structure exclusion.** A structure-affected transect is excluded
from headline aggregation only when the structure DEGRADES it (criterion: operator parameter,
§6 — e.g., face height and/or peel quality below the adjacent open-transect band). Never
excluded from maps.

## 4. Acceptance (reality-gate cases; numbers pasted, not asserted)

1. **HB double-break day:** cross-section and heatmap show TWO break zones on mid-beach
   transects — an outer break (operator's observed reference: roughly mid-pier distance) and a
   shore break; per-transect headline comes from the bigger; handoff is seaward of the outer
   zone on every transect (log evidence).
2. **Small-swell single-break day:** exactly one break zone; no phantom second zone; handoff
   seaward of it (regression vs today's run: currently 9–17 m shore break, 0.76 m depth).
3. **Headline behavior:** an artificial single-transect spike does NOT move the main-break-zone
   headline (known-answer test).
4. **Structure day-dependence:** a synthetic case where lee transects beat open ones keeps them
   in the headline; the mirrored degraded case excludes them.
5. Convergence/publish/valid_fraction remain at the 2026-08-01 verified levels.

## 5. Current-state facts an implementer must know

**REVISION (same day, operator prompted "I can swear we already wrote some of this"): the
multi-break engine and zone classifier ALREADY EXIST — verified in code.** This shrinks the
package: BD-3 and most of BD-5 are already implemented and are merely STARVED by the handoff
domain. The core defect is BD-1/BD-2 alone.

- `surf_1d_analytical.py::_find_break_points()` (~line 484): walks the whole given profile,
  edge-detects EVERY entry into breaking (H/d ≥ γ transitions), returns ALL break points,
  outermost first (guards: depth > 0.3 m, Hs > 0.15 m). Multi-break by design.
- `surf_1d_analytical.py::_classify_zones()` (~line 514): builds the full anatomy — impact zone
  (outer break → 50% energy decay), foam/bore zone, and an explicit **reform zone when
  `len(break_points) > 1`** (the double-break case, already coded).
- **Why none of this shows in the product:** the profile fed to the engine starts at the
  handoff (1.05 m depth in the 2026-08-01 run) — shoreward of any outer bar — so only the shore
  break is ever visible to it. Fix the handoff domain (BD-1/BD-2) and the existing engine
  produces both breaks + reform zone through the existing data contracts.
- `PartitionBreakResult.break_points` is already `list[BreakPoint]` ("primary = index 0,
  outermost") end-to-end through the cache codec (`swelltrack_cache.py`) and API — no payload
  shape change needed for multi-break.
- BD-4 is a one-comparison change: primary/reported break is currently the OUTERMOST
  (`break_points[0]` everywhere: face height, invariants, peel); the ruling changes the
  criterion to the BIGGER (usually the same wave; not always).
- Per-transect fine profiles (`hs_total_profile`, distances, depths) span the transect at fine
  resolution — the detection data exists.
- The cross-section product = `endpoints/beach_profile.py` `"transect": hs_envelope`.
- The heatmap contract = `per_transect` in `surf_1d_pipeline.PipelineResult` (structure-affected
  included by design).
- Handoff selection = `transect_handoff.select_hourly_handoff()` (three-way L4→L3→L2, QB
  refinement) — BD-2 changes its criterion, an architectural (trigger-1) change: THIS SPEC +
  operator sign-off is the authorization trail.
- The spot-level pin-anchored CURVE pick is deleted (marine `1c98507`) — do not resurrect it;
  all selection is per-transect.

## 6. Open parameters — operator must rule before implementation

1. **Deviation band width** for BD-7 (e.g., ±1σ, ±20% of zone mean?).
2. **Main-break-zone identification window** (alongshore smoothing length / minimum zone width
   in transects?).
3. **Degradation criterion** for BD-8 (face height alone, or face height + peel?).
4. **Break-zone merge threshold** — when do two adjacent breaking regions count as ONE zone
   (bar-trough-bar spacing floor)?
5. **Band widening cost** (BD-1): accept larger TABLE_PT files / station counts, or cap and
   interpolate? (Cost will be measured and presented before ruling if preferred.)
