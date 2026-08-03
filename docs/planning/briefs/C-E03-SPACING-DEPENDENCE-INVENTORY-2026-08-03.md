# C-E03 — Transect-spacing dependence inventory (read-only investigation)

**Date:** 2026-08-03. **Agent:** Explore (read-only), dispatched per ruled decision item 3
(AUDIT-OPUS-WINDOW-2026-08-03.md — "investigation-first: inventory transect-count vs metres
criteria before any change is considered"). **Coordinator spot-check:** cites at
surf_1d_pipeline.py:1295/:1331, marine_config.py:544, surf.py:475 verified verbatim against HEAD
(marine `f38a8f3`). **Status: FINDINGS ONLY — no code change proposed or authorized. Awaits
operator review; any follow-on change to the count criteria is trigger 1 (criterion inside a
detection formula) and needs explicit operator approval per criterion.**

**Operator's question this answers:** "right now we have a hardcoded 5 transects needed to agree
in order to find high surf... less transects means less checks and balances... Changing this
requires us to rethink the validation process as well as the smoothing process for heat map."

**Headline findings (coordinator reading of the inventory below):**
1. The main-break-zone algorithm (the thing that picks the published headline height) carries
   FIVE spacing-blind count criteria (C1-C6) in one function; at 25 m spacing their physical
   meaning drifts 2.5×; none of them can even see `transect_spacing_m` (it is not a parameter
   of the function).
2. The fraction-based criteria (C11 25% bulk-degrade, C12 50% structure warning) are scale-free
   and safe under spacing changes.
3. The cross-shore band criteria (C13-C15) count stations against a DIFFERENT hardcoded 10 m
   (`_TRANSECT_BAND_SPACING_M`) — unaffected by `transect_spacing_m`, but a second, unrelated
   "10" a reader can confuse with transect spacing.
4. `transect_spacing_m` has no upper bound and no sanity check against segment length, and is
   undocumented in CONFIG.md/README/INSTALL.
5. **There is NO alongshore heatmap smoothing anywhere in the package** — the "rethink the
   smoothing" concern has no current code object; per-transect output is emitted verbatim.
6. Changing spacing silently invalidates persisted `transect_bearings` (length-match check
   discards with WARNING → falls back to isobath normals).
7. Tests pin the count constants hard (test_main_break_zone_headline.py pins 5 repeatedly and
   the 0.75σ coefficient; test_model_status_grading.py pins 25% exactly) — any ruled change is
   a code+tests same-commit change.

---

## Agent report (verbatim)

## Summary conversion table

| # | Criterion | File:line | As written | Physical extent @ 10 m spacing | Spacing-aware? | >2x drift at 25 m? |
|---|---|---|---|---|---|---|
| C1 | Main-break-zone candidate run must be `>= 5` transects long | `services/surf_1d_pipeline.py:1295` | transect count (5) | ~50 m of beach (4 gaps = 40 m span) | **No** | **YES** — 50 m -> 125 m |
| C2 | Fallback A: `n >= 5` successful transects required | `services/surf_1d_pipeline.py:1299` | transect count (5) | ~50 m | **No** | **YES** |
| C3 | Fallback A: contiguous block must be `>= 5` to host a window | `services/surf_1d_pipeline.py:1308` | transect count (5) | ~50 m | **No** | **YES** |
| C4 | Fallback A: sliding window is exactly 5 wide (`span = (s, s+4)`) | `services/surf_1d_pipeline.py:1309-1310` | transect count (5) | ~50 m (40 m span) | **No** | **YES** |
| C5 | Qualifying floor = "fifth-highest in-zone face" when zone `>= 5` | `services/surf_1d_pipeline.py:1331` | transect count (5, order statistic) | ~50 m worth of members | **No** | **YES** (degeneracy point moves) |
| C6 | Zone contiguity = consecutive `transect_index` (`indices[pos] == indices[pos-1] + 1`) | `services/surf_1d_pipeline.py:1287`, `1306` | transect count (gap of 1) | one gap tolerated = 0 m; a single failed transect breaks a run | **No** | **YES** (a break costs 25 m not 10 m) |
| C7 | Peel angle needs `>= 2` transect results and `>= 2` break points | `services/surf_1d_pipeline.py:804`, `831` | transect count (2) | ~10 m baseline minimum | **No** (but see C8) | **YES** |
| C8 | Peel Δy = actual measured origin-to-origin distance, `< 0.1 m` skipped | `services/surf_1d_pipeline.py:842-844` | metres | n/a — measured | **Yes (implicitly)** — reads real geometry | No |
| C9 | Invariant 4 gated on `n_transects > 1` | `services/surf_1d_pipeline.py:2292`, `2301` | transect count (1) | ~10 m | **No** | No (degenerate guard) |
| C10 | Invariant 5 gated on `n_transects > 1` | `services/surf_1d_pipeline.py:2322` | transect count (1) | ~10 m | **No** | No (degenerate guard) |
| C11 | `modelStatus=degraded_bulk` at `bulk_fraction >= 0.25` | `endpoints/surf.py:475` | fraction of transects | 25% of segment length (scale-free) | **No** (but scale-free) | No |
| C12 | ">50% of transects structure-affected" operator warning | `services/swan_formats.py:879` | fraction of transects | 50% of segment (scale-free) | **No** (scale-free) | No |
| C13 | `_TRANSECT_BAND_MIN_POINTS = 3` band stations | `services/swan_runner.py:1538`, used `4939`, `4990` | station count (3) | 30 m **cross-shore** (band spacing 10 m) | **No** — reads `_TRANSECT_BAND_SPACING_M`, not `transect_spacing_m` | n/a (different axis) |
| C14 | `_TRANSECT_BAND_MAX_POINTS = 150` | `services/swan_runner.py:1548` | station count (150) | 1500 m cross-shore | **No** | n/a |
| C15 | BD-2 eligibility `_l4_eligible_n >= 3` / `_l3_eligible_n < 3` | `services/transect_handoff.py:809`, `958` | station count (3) | 30 m cross-shore | **No** | n/a |
| C16 | SWAN `sname` 8-char cap -> abandons per-transect POINTS | `services/swan_runner.py:5015` | transect index digits | caps usable transect count per spot | **No** | Inverse: coarser spacing *relieves* it |
| C17 | `transect_count = int(segment_length_m / spacing) + 1` | `config/marine_config.py:544`; `services/swan_formats.py:751` | derived count | n/a | **Yes** — the definition | n/a |

---

## Per-criterion detail

### C1–C6: the main-break-zone algorithm (`_compute_main_break_zone`)
`weewx_clearskies_marine/services/surf_1d_pipeline.py:1179-1365`. This one function contains five of the six spacing-blind alongshore criteria. Verbatim:

```python
1295:    long_runs = [span for span in candidate_runs if (span[1] - span[0] + 1) >= 5]
1297:    if long_runs:
1298:        zone_span = max(long_runs, key=_run_mean)
1299:    elif n >= 5:
...
1308:                if block_end - block_start + 1 >= 5:
1309:                    for s in range(block_start, block_end - 5 + 2):
1310:                        span = (s, s + 4)
...
1331:    fifth_highest_or_floor = sorted_desc[4] if len(sorted_desc) >= 5 else sorted_desc[-1]
1332:    eff_threshold = min(zone_mean + 0.75 * zone_sigma, fifth_highest_or_floor)
```
and the contiguity test at `1287` / `1306`:
```python
1287:        while pos < n and candidate[pos] and indices[pos] == indices[pos - 1] + 1:
1306:            if scan_pos == n or indices[scan_pos] != indices[scan_pos - 1] + 1:
```

**What it decides.** Where along the beach "the main break" is, and hence *the published headline wave height*. Step 2 marks every transect whose `best_face_height_m >= spot_mean` as a candidate; step 4 (C1) keeps only maximal contiguous candidate runs of at least 5 transects and picks the highest-mean one. If no such run exists but 5+ transects succeeded (C2), Fallback A (C3/C4) slides a fixed 5-wide window over each index-contiguous block and takes the highest mean. Otherwise every successful transect becomes the zone (Fallback B). C5 then sets the qualifying threshold `min(zone_mean + 0.75*sigma, fifth-highest-face)`; the qualifying members' mean is `main_zone_face_height_m` — consumed at `endpoints/surf.py:1243-1248` as `_swelltrack_face_m`, the number fed to `score_surf()`. C6 (contiguity) makes a single FAILED transect (absent from the input list) terminate a run exactly as a non-candidate does.

**Units as written:** pure transect count. **Physical extent @ 10 m:** 5 transects = 4 spacings = 40 m of span, ~50 m of beach occupied. **Spacing-aware:** no — `_compute_main_break_zone()` takes only `list[tuple[int, TransectResult]]`; `transect_spacing_m` is not a parameter, is not imported, and no distance is available inside the function. **Downstream fields set:** `main_zone_face_height_m`, `main_zone_start_index`, `main_zone_end_index`, `main_zone_transect_count`, `main_zone_qualifying_count`, `main_zone_threshold_m`, `representative_transect_index`, `qualifying_indices` (`1354-1365`). The representative index also selects the transect whose break points are published (`endpoints/beach_profile.py:350-371` `_select_best_transect`, BD-9).

**>2x flag:** YES for C1–C6. At 25 m spacing the 5-transect window covers 100 m of span / ~125 m of beach — 2.5x the physical extent. C6 is the sharpest: at 25 m one failed transect creates a 25 m discontinuity that hard-splits the zone.

**Test pin:** `tests/test_main_break_zone_headline.py` pins 5 explicitly and repeatedly — e.g. line 139 `"a run of 4 never beats a run of 5"`, line 146-148 build a 4-run vs a 5-run, lines 111/132/133/155/237/270/304 assert `main_zone_transect_count == 5` / `main_zone_qualifying_count == 5`. Also pins the 0.75 sigma coefficient (line 233). The zone-size-5 degeneracy of C5 is pinned at lines 31-34.

### C7/C8: peel angle from adjacent transect pairs
`services/surf_1d_pipeline.py:777-930`.
```python
804:    if len(open_transect_results) < 2:
805:        return None, None, None
...
831:    if len(break_pts) < 2:
832:        return None, None, None
...
842:        delta_y = _along_shore_distance_m(t1, t2)
843:        if delta_y < 0.1:
844:            continue  # degenerate — skip
```
**Decides:** whether `peel_angle_deg`, `peel_classification`, `peel_direction` are computed at all (else all three publish as `None`). The break-line angle is `atan2(|Δx|, Δy)` over each adjacent pair.

**Units:** C7 is a transect count (2); C8 is metres. **Extent @ 10 m:** the minimum baseline is one spacing = 10 m. **Spacing-aware:** C7 no; C8 yes-by-measurement — `_along_shore_distance_m()` (`538-548`) computes the real great-circle distance between transect origins, so the *angle arithmetic* self-corrects for spacing. Only the "need 2" gate and the `0.1 m` degeneracy floor are fixed. The regression-slope guard `den > 1.0` ("require at least 1 m of positional spread", line 897) and the `|slope| < 0.05` a_frame band (line 899) are in metres/dimensionless and also self-correct.

**>2x flag:** the C7 count gate technically doubles-plus (10 m -> 25 m minimum baseline), but the criterion is a "have any data at all" guard, not a physical-agreement window. C8 is unaffected.

### C9/C10: invariants gated on transect counts
`services/surf_1d_pipeline.py:2290-2332`.
```python
2290:    _n_clamped = sum(clamped_for_transect)
2291:    _all_clamped = n_transects > 0 and all(clamped_for_transect)
2292:    if not _handoff_is_l2_broadcast and n_transects > 1 and not _all_clamped:
2293:        invariants.check(
2294:            invariants.INVARIANT_4,
2295:            _distinct_handoff_count > 1,
...
2322:    if len(_profile_ids) >= 1 and n_transects > 1:
...
2328:            len(_profile_ids) > 1 or _n_profiled <= 1,
```
**Decides:** whether invariant 4 (`4:distinct_handoff_depths_across_transects`) and invariant 5 (`5:transect_bathymetry_objects_distinct`) are evaluated. Firing logs one ERROR and records into the bounded registry (`services/invariants.py:124-166`); it never alters published output (module docstring, `invariants.py:1-10`). **Units:** transect count (`> 1`) plus, for inv-4, an "all transects clamped" *fraction* expressed as `all(...)` — i.e. 100% of transects, scale-free. **Spacing-aware:** no. **>2x:** no — these are degenerate-population guards, not physical-extent criteria.

Note there is **no** invariant that counts transects or requires a fraction of transects as its *predicate*; `services/invariants.py` itself is entirely free of transect arithmetic (it contains only the registry, `ray_box_exit_distance_m`, and `rotated_rect_clearance_to_bbox_m`, both pure metres geometry). Invariant 10 (`invariants.py:94-101`) is *gated* on `main_zone_transect_count > 0` at `surf_1d_pipeline.py:1792` and `2795`, inheriting C1–C6's spacing sensitivity indirectly.

### C11: model-status grading by fraction of transects
`endpoints/surf.py:441-491`.
```python
470:    n_success = len(pipeline_result.per_transect)
471:    n_bulk = pipeline_result.bulk_fallback_transect_count
472:    if n_bulk > 0:
473:        bulk_fraction = n_bulk / n_success
474:        qualifying_hit = pipeline_result.qualifying_zone_bulk_fallback
475:        if bulk_fraction >= 0.25 or qualifying_hit:
```
**Decides:** the published `modelStatus` string: `degraded_bulk` / `partial` / `ok` / `no_breaking` / `unavailable`. `unavailable` additionally triggers `_report_forecast_gap()` (`surf.py:1235`). **Units:** fraction of successful transects. **Extent @ 10 m:** 25% of the segment, whatever its length — scale-free by construction (docstring line 463: "Percentage base is successful transects only"). **Spacing-aware:** no, and does not need to be. **>2x:** no. The `or qualifying_hit` disjunct, however, is spacing-sensitive *transitively*, because "qualifying" is defined by C1–C6.

**Test pin:** `tests/test_model_status_grading.py:129-146` pins the boundary at *exactly* 25%.

### C12: >50% structure-affected operator warning
`services/swan_formats.py:876-888`.
```python
878:    n_affected = sum(1 for t in result if t.is_structure_affected)
879:    if n_affected > 0 and n_affected > len(result) / 2:
880:        logger.warning(
881:            "compute_spot_transects: %d/%d transects (%d%%) are "
882:            "structure-affected (>50%% threshold). "
```
**Decides:** nothing computational — a WARNING only ("A WARNING is logged but no exception raised", docstring line 699). **Units:** fraction of transects. **Spacing-aware:** no; scale-free. **>2x:** no.

### C13/C14/C15: cross-shore band station counts (BD-1/BD-2)
These are the criteria the brief flagged as "swan_runner transect/POINTS band logic". Critically, they count **cross-shore stations along one transect**, not transects — their pitch is `_TRANSECT_BAND_SPACING_M = 10.0` (`swan_runner.py:1537`), a *different* 10 m from `transect_spacing_m`.

```python
1537: _TRANSECT_BAND_SPACING_M = 10.0
1538: _TRANSECT_BAND_MIN_POINTS = 3   # select_hourly_handoff() needs >=3 for an interior station
1548: _TRANSECT_BAND_MAX_POINTS = 150
```
consumed at `swan_runner.py:4938-4940` and:
```python
4990:                        if len(_pruned_band_points) < _TRANSECT_BAND_MIN_POINTS:
```
**Decides (C13):** whether a transect gets L4 POINTS emitted at all. Below 3 surviving in-rotated-footprint wet points, no L4 POINTS are written and that transect routes to the fixed L2 15 m reference via `resolve_handoff_by_transect()`'s missing-index fallback (`surf_pipeline_timestep.py:287-309`). **Decides (C15):** the same interior-station rule inside `select_hourly_handoff()`:
```python
transect_handoff.py:809:        if _l4_eligible_n >= 3:
transect_handoff.py:958:    if _l3_eligible_n < 3:
```
which routes L4 -> L3 -> L2. **Units:** station count. **Extent @ 10 m band spacing:** 3 stations = 30 m cross-shore, 150 stations = 1500 m. **Spacing-aware:** blind to `transect_spacing_m` (correctly — wrong axis), and blind to `_TRANSECT_BAND_SPACING_M` too (hardcoded counts against a hardcoded pitch). **>2x under a `transect_spacing_m` change:** not applicable.

BD-1 itself (`transect_handoff.py:619-677`, `find_outermost_break_index`) has **no** count criterion — it is a first-match scan on `Hs >= gamma*depth` or `QB >= qb_threshold`, both physical thresholds. Its result is consumed as `max_seaward_break_index` at `swan_runner.py:925-947`.

### C16: SWAN 8-char `sname` cap
`services/swan_runner.py:5004-5026`. `_pt_name = f"PT{n}_{_t.index}"`; if `len(_pt_name) > 8` the whole spot abandons per-transect POINTS and falls back to CURVE-only. **Units:** digits in the transect index — an implicit ceiling on transect count (comment at `5008` names "200 transects at 10 m spacing on a 2 km segment" as the overflow case). **Spacing-aware:** no. Coarser spacing makes this *less* likely to trip.

### C17: the definition itself
```python
config/marine_config.py:544:  self._transect_count = int(self._segment_length_m / self.transect_spacing_m) + 1
config/marine_config.py:549:  self._primary_transect_index = self._transect_count // 2
swan_formats.py:751:          n_transects = int(seg_length_m / transect_spacing_m) + 1
swan_formats.py:758:              d = float(i) * transect_spacing_m
```
Plus the override length-match check at `swan_formats.py:791` (a persisted `transect_bearings` list of the wrong length is discarded with a WARNING and the call falls back to per-origin isobath normals / the scalar facing — i.e. changing spacing silently invalidates cached bearings).

---

## `transect_spacing_m` — config entry and every consumer

**Key:** `[marine.locations.<id>.surf] transect_spacing_m`
**Default:** `10.0` — hardcoded twice: the shipped config template `config/marine_config.py:57`, and the parse fallback `config/marine_config.py:509-513` (`raw_spacing is None or blank -> 10.0`).
**Validation bounds:** only `> 0`. `config/marine_config.py:750-754` raises `ValueError` on `<= 0`. No upper bound, no sanity check against `segment_length_m`. Secondary guards: `swan_formats.py:704-708` raises `ValueError` in `compute_spot_transects`; `swan_runner.py:4850-4860` and `swan_runner.py:3352` treat non-positive as a geometry issue and degrade to CURVE-only / single-point with a WARNING. Not documented in `CONFIG.md`, `README.md`, or `INSTALL.md` (grep returns nothing) — the only prose is the code comment at `marine_config.py:47-52` and the class docstring at `432`/`443`.

**Consumers (all pass it into `compute_spot_transects`, except where noted):**
- `config/marine_config.py:544` — derives `transect_count`; `:549` derives `primary_transect_index`
- `services/swan_formats.py:602/704/751/758/797` — the geometry generator itself; `:895` logs it; `:1206` passes a dummy `1.0` for the degenerate single-point path
- `services/grid_sizing_chain.py:1405` (strip bearings), `:1507` (30 m contour), `:1663` (15 m contour), `:1905` (study-area bbox), `:2136` (per-transect profiles cache)
- `services/swan_runner.py:3352` (L3-disabled fallback geometry check), `:3392`, `:4841`/`4851`/`4906` (per-transect POINTS emission)
- `providers/nearshore/swan.py:2088` (served surf-card shadow geometry), `:2931` and `:3770` (written into the SWAN runtime `cfg_dict`)
- `endpoints/surf.py:902`
- `endpoints/beach_profile.py:1028`

No consumer feeds it into any detection/agreement/validation threshold — every count-based criterion above sits downstream of the transect list with no access to the spacing that produced it.

---

## Already purely in metres — no count dependence (completeness check)

- `services/surf_1d_analytical.py:604` `_JACKING_EXTREMUM_HALF_WINDOW_M = 10.0` and `:616` `_JACKING_APPROACH_WINDOW_M = 50.0` — cross-shore bar-crest detection windows, explicitly converted from a former sample-count algorithm to metres for resolution independence (docstring `:641-651`). Note the comment at `:582` describes 10.0 m as "one L4 SWAN grid cell / transect spacing" and `:609` describes 50.0 m as "five L4 grid cells" — the *rationale* references spacing, but the constants are metres and are applied cross-shore, so `transect_spacing_m` does not affect them.
- `services/surf_1d_pipeline.py:843` `delta_y < 0.1` and `:897` `den > 1.0` — metres.
- `services/transect_handoff.py:594-611` `breaking_margin_depth_m()`, `_GAMMA_BREAKING`, `_DEFAULT_QB_THRESHOLD`, `L2_REFERENCE_DEPTH_M` — depths/dimensionless physics.
- `services/swan_domain.py:2288-2313` L4 sizing: `u_max = u_seaward_most + l_tip_m`, lateral `+/- resolution_m` — metres; `:1255` `+0.5 km` margin; `:1265` `landward_km = 0.5`; `:649` `level3_lateral_m` default 250 m; `:1335` cluster `max_distance_m` (500 m).
- `services/invariants.py:228-336` — `ray_box_exit_distance_m` / `rotated_rect_clearance_to_bbox_m`, pure metres geometry.
- `enrichment/bathymetry.py:1614-1861` — shoreline smoothing: window given in metres `w_m`, converted per-call `k = max(1, round(w_m / (2.0 * delta_s)))` with `delta_s = median(|p_{i+1}-p_i|)`. Spacing-aware by construction, and operates on 0 m-shoreline vertices, not transects.
- `enrichment/bathymetry.py:2223` `_DEEP_WATER_NEIGHBOR_MIN_M = 20.0` — a depth, not a distance along the beach.

## Not found

There is **no alongshore heatmap smoothing anywhere in the package.** "Heat map" appears only as a description of the un-smoothed per-transect output list: `surf_1d_pipeline.py:161` ("it is map/UI/quasi-2D-heat-map"), `:307` ("Includes both open and structure-affected transects for the heat map"), `swan_formats.py:563`, `transect_handoff.py:15`. `PipelineResult.per_transect` is emitted verbatim; no convolution, moving average, neighbour blend, or kernel is applied across the transect axis. The only neighbour-averaging in the codebase is the shoreline smoothing above (different axis, metres-parameterised) and `services/vertical_datum.py:283-309` (8-neighbour raster gap fill, grid cells).
