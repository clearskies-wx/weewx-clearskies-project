# SURF-ZONE BREAK DETECTION & REPORTING — DESIGN SPEC (APPROVED 2026-08-01)

**Date:** 2026-08-01 · **Status:** **APPROVED** — operator signed off in chat same day and ruled
every open parameter (see §6, now RULINGS). Round 1 (BD-1/BD-2/BD-4) is GO. Round 2 =
BD-7 + BD-9; BD-8 is RESCINDED as an exclusion (flag retired to metadata-only, see §6.3).

**Implementation status (updated 2026-08-01):** **Round 1 (BD-1/BD-2/BD-4) — CLOSED, PASSED.** Marine
`03b33e1`/`ea62e85`/`b60ef92`; adversarial audit PASS; live SWAN run completed and passed (L4 accuracy 99.6%,
valid_fraction 100.0%, 143 transects × 67/67 timesteps, published); doc-sync committed+pushed. **Round 2
(BD-7/BD-8/BD-9) — IMPLEMENTED, being pushed/deployed.** Marine `9719db1`/`732e87d`; adversarial audit PASS
WITH FINDINGS (F1 remediated + re-audited PASS, F2 operator-approved as a real case not a defect, F3 docstring
fix); this doc-sync pass records the code as it stands at `732e87d` — live verification of the deployed Round-2
run is pending as of this line (see PROVIDER-MANUAL.md §14.15 and the plan decision log for the fuller
narrative). See `docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` decision log for both rounds' full entries.

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

## 6. Parameters — RULED by the operator, 2026-08-01 chat

1. **Deviation band (BD-7): the UPPER TAIL — transects whose bigger-break face height is ABOVE
   the zone mean + 0.75 σ contribute to the headline average.** (Corrected ruling, same day —
   NOT a symmetric ±band.) Rationale (operator): SWAN conveys hourly-averaged swell statistics,
   not individual waves — every per-transect face height is already a smoothed average, so the
   upper tail of transects is what corresponds to the set waves surfers actually judge by;
   averaging around the mean would double-smooth and understate. Single-transect anomalies are
   guarded by ruling 2's ≥5-transect zone window, not by trimming the top. **Fallback (operator
   ruling, same day): if fewer than 5 transects clear mean+0.75σ, lower the deviation threshold
   for that run until at least 5 qualify.** Deterministic implementation: effective threshold =
   `min(mean + 0.75σ, 5th-highest bigger-break face in the zone)` — identical to 0.75σ whenever
   it already yields ≥5, otherwise admits exactly the top 5.
2. **Main-break-zone window: minimum ~5 consecutive transects (~50 m at 10 m spacing)** — a zone
   is a real stretch of beach, never one anomalous line.
3. **BD-8 RESCINDED — no exclusion at all.** Operator reasoning: with the zone-based headline, a
   structure-degraded transect simply fails to qualify for the main break zone; a structure-
   improved one legitimately qualifies. Verified fact behind the ruling: `is_structure_affected`
   is a geometric-SHADOW classification (beach_facing ±30° test, `swan_formats.py` TransectInfo
   docstring) — NOT an "uncomputable transect" marker; every flagged transect is fully computed.
   Disposition: the flag and `shadowing_structures` labels are RETAINED as map/UI metadata
   (heatmap semantics) and lose all aggregation roles. `open_transect_count` semantics update
   accordingly at implementation time.
4. **Break-zone merge threshold: DEFERRED with default.** (Meaning, for the record: on a noisy
   profile the H/d ≥ γ condition can flicker over a few metres, splitting one physical break
   into several detected entries; a merge threshold would coalesce them.) Ruling: rely on the
   existing engine's guards; tune ONLY if the HB double-break reality gate (§4.1) shows zone
   fragmenting. No speculative parameter now. (Operator note reinforcing deferral: the model
   conveys hourly-AVERAGED swells, not individual waves — Hs profiles are spatially smooth, so
   γ-condition flicker is unlikely in practice.)
5. **Band widening cost (BD-1): measure first** — coordinator measures the actual TABLE_PT cost
   from the 2026-08-01 run artifacts and presents the number; full-length bands adopted if the
   cost is unremarkable.

## 7a. Doc-sync task — REQUIRED, per round (operator-ordered 2026-08-01)

Each implementation round closes ONLY with its doc-sync pass (CLAUDE.md doc-code sync rule —
same commit/PR discipline, meta repo):

**Round 1 (BD-1/BD-2/BD-4, bands):**
- `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — new amendment: per-hour handoff
  criterion is now "nearest target depth AMONG stations seaward of the outermost suspected
  break zone" (supersedes plain first-crossing/nearest-target; Amendment 2 §2's target-depth
  formula itself unchanged).
- `docs/manuals/PROVIDER-MANUAL.md` — T4B.1 band description (full-crossing stations,
  parse-and-delete), handoff selection §, BD-4 primary-break semantics.
- `docs/ARCHITECTURE.md` — handoff/1D boundary description wherever it names the selection rule.
- `docs/manuals/API-MANUAL.md` — per-transect payload semantics if the primary-break index or
  band fields change shape.
- `docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` decision log — round entry.
**Round 2 (BD-7/BD-9):**
- `docs/manuals/API-MANUAL.md` — headline-metric contract (main-break-zone average, upper-tail
  threshold + ≥5 fallback), representative-transect cross-section field semantics,
  `open_transect_count`/exclusion-retirement semantics.
- `docs/manuals/DASHBOARD-MANUAL.md` — cross-section = representative transect (not averaged),
  heatmap break-zone presentation.
- `docs/ARCHITECTURE.md` + `docs/manuals/PROVIDER-MANUAL.md` — headline metric + BD-8
  retirement.
- SURF-ZONE-MODEL-BRIEF — dated addendum pointing to this spec.
- Plan decision log — round entry.
Session logs/concerns files/archive stay untouched (records, not governing docs). The
coordinator gates each round's close on this pass, same as Phase R.

## 7. BD-9 — Representative-transect cross-section (operator ruling, 2026-08-01)

The cross-sectional depth/wave graphic shows ONE transect. Do NOT build an averaged "best
curve." Instead, pick the transect that best represents the identified main-break-zone window
and render its actual cross-section. Selection: the in-zone transect whose bigger-break face
height is closest to the zone's band-filtered mean (deterministic tiebreak: nearest the zone's
alongshore center). Spatial variation across the beach is the heatmap's job (BD-6), not the
cross-section's. This replaces any averaging ambition in BD-5's presentation layer; BD-5's
anatomy requirements (both breaks, foam/reform zones on the rendered transect) stand.
