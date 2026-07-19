# SWAN Model Fixes — Mini-Plan

## Context

Post-deployment testing of the SWAN corrections (SWAN-CORRECTIONS-PLAN.md, all phases complete) revealed three critical issues and several related problems:

1. **Wave heights too low** — SWAN cold-starts every run because the HOTFILE command is never written to the INPUT file (chicken-and-egg bug). First 3-6 hours of each 72-hour run show near-zero wave heights.
2. **Hourly quick updates not firing** — last model run was 3+ hours ago despite the cache warmer having a 1-hour quick update timer.
3. **Beach profile useless** — the cross-shore transect extends from 6m depth to 18m depth (entirely offshore of the surf zone). No breaking detected, no break points shown, no useful visualization. Root cause: the transect is computed from the operator's pin coordinate outward, but the pin is at the pier (already 4-6m depth) and the bathymetric profile has no shoreward data.

The operator's pin placement is "people surf here" — NOT a precise surveyed coordinate. The system has CUDEM bathymetry and must use it to find the actual coastline and build the transect from shore to deep water, regardless of where the pin lands.

---

## Phase 1: Hotstart Bootstrap Fix ✓ COMPLETE

**Completed:** 2026-07-18. Commit: fa74965.

**Problem:** `HOTFILE 'hotstart.dat'` and `INIT HOTSTART 'hotstart.dat'` are both gated on `if hotstart_file:` in `build_swan_input()`. On the first run, `hotstart_file` is None → neither command emitted → SWAN writes no hotstart → next run also cold-starts. Permanent failure.

**Fix:** `swan_formats.py` line 945 — unconditionally emit `HOTFILE 'hotstart.dat'`. `INIT HOTSTART` (line 719) stays conditional (only read when a previous hotstart exists). 3 unit tests added.

**Files:**
- Modify: `weewx_clearskies_api/services/swan_formats.py` (line 945-946)
- Test: add assertion to `tests/services/test_swan_runner.py` that `build_swan_input(hotstart_file=None)` output contains `HOTFILE 'hotstart.dat'`

**Verify:**
1. Deploy, delete existing `*_hotstart.dat` from `/var/run/weewx-clearskies/swan/`
2. After next full SWAN run, confirm `outer_hotstart.dat` and `inner_hotstart.dat` exist
3. After second run, confirm logs show "using hotstart from previous run"
4. Compare t=0 wave heights between run 1 (cold) and run 2 (warm)

---

## Phase 2: Quick Update Fix ✓ COMPLETE

**Completed:** 2026-07-18. Commit: 492c3ed.

**Root cause:** The UTM conversion commit (0610b3d) introduced a reference to `grid_info` at line 1245 of `swan_runner.py` before it was assigned at line 1259. The stationary inner nest path (`run_stationary_inner()`) hit this code when no CURVE transects were configured. Every hourly quick update crashed with `UnboundLocalError: cannot access local variable 'grid_info'`.

**Fix:** Moved `grid_info = {**bottom_dims, **wind_dims}` assembly before the OUTPUT_POINTS.txt block. Computed UTM zone directly from `bottom_dims` instead of from the not-yet-built `grid_info`.

---

## Phase 3: Transect Reaches Shore (CUDEM-driven) ✓ COMPLETE

**Problem:** The transect is computed from the operator's pin OFFSHORE using a wizard-downloaded 1D profile that starts at the pin (4.26m depth at HB Pier). It never extends shoreward. The surf zone (0-3m depth) is missing entirely.

**Design:**

### 3a. Bidirectional CUDEM profile download

New function in `enrichment/bathymetry.py`:
- From the pin, sample CUDEM SHOREWARD (bearing + 180°) at ~10m spacing until depth ≤ 0 → coastline found
- From the coastline, sample CUDEM OFFSHORE (bearing) at ~10m spacing until depth ≥ 15m
- Return a unified profile with `distance_m` measured from the coastline (0 = shore)
- Edge cases: pin on beach (depth ≤ 0 at pin, just go offshore), pin in deep water (search shoreward to find coast)
- Use existing `download_bathymetric_profile()` NCEI query pattern (3.4m CUDEM resolution)

### 3b. Profile caching

- Cache per-spot at `/etc/weewx-clearskies/spot_profiles/{spot_id}.json`
- 180-day TTL (CUDEM data changes infrequently)
- Downloaded at SWAN run time, not wizard setup time
- `swan.py` `run_all_spots()` checks cache, downloads if missing/stale

### 3c. Transect computation from full profile

Modify `compute_spot_transect()` in `swan_formats.py`:
- Input: the bidirectional profile (shore-to-deep)
- Build CURVE from ~0m depth (shore) to ~15m depth
- 20 points covering the full surf zone
- The pin is somewhere along this transect, NOT an endpoint

### 3d. Wizard help text update

Update the surf spot wizard step help text: "Place the pin at the surf spot — where people actually surf. The system will determine the coastline and bottom profile automatically."

**Files:**
- Modify: `weewx_clearskies_api/enrichment/bathymetry.py` (new bidirectional download)
- Modify: `weewx_clearskies_api/services/swan_formats.py` (transect computation, line 450+)
- Modify: `weewx_clearskies_api/providers/nearshore/swan.py` (runtime profile cache)
- Modify: `weewx_clearskies_api/services/swan_runner.py` (pass cached profile instead of config profile)

**Verify:**
- After SWAN run, TABLE output shows depth decreasing to ~0m at the nearshore end
- QB > 0 at transect points in the surf zone
- Beach profile API returns break points with `breakingFraction >= 0.25`
- For HB Pier: outer break visible at ~280m from shore, inner break closer to shore

---

## Phase 4: Scoring Uses Biggest Break ✓ COMPLETE

**Problem:** The scoring reference point is the transect point closest to 10m depth (selected BEFORE break detection in surf.py line 489-497). It should be just offshore of the most energetic break.

**Fix in `endpoints/surf.py`:**
1. Move break point detection (lines 499-529) ABOVE reference point selection (line 489)
2. If breaks exist: biggest break = `max(break_points, key=lambda bp: (bp["waveHeight"] or 0) * (bp.get("breakingFraction") or 0))`
3. Reference point = first transect point just offshore (deeper) of the biggest break
4. Fall back to closest-to-10m if no breaks detected (flat conditions)

**Verify:**
- In 3-5 ft swell at HB Pier, the outer break is the primary break
- Scoring wave height reflects the outer break, not a random 10m-depth point
- Flat conditions (<1 ft) fall back to 10m depth gracefully

---

## Phase 5: Beach Profile Card Redesign ✓ COMPLETE

**Problem:** No axis labels, no tick marks, wave envelope invisible relative to depth scale, no break point markers.

**Redesign in `BeachProfileChart.tsx`:**
- Proper X-axis: distance from shore (meters) with tick marks at regular intervals
- Proper Y-axis: depth (meters) with tick marks (0m, -5m, -10m, -15m)
- Break point markers: dashed vertical lines with distance-from-shore labels ("280m from shore")
- Multi-break support (outer + inner)
- Increase SVG viewBox height or adjust to 2x4 card footprint (TBD based on visual review once data is correct)
- Keep: bathymetry fill, water surface line, wave height envelope, sr-only data table

**Files:**
- Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx`
- Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx` (card footprint if changing to 2x4)

**Verify:** Visual inspection at https://weather-test.shaneburkhardt.com — card shows proper axes, break markers with distances, readable wave envelope.

---

## Phase 6: Tide Card Label Clipping ✓ COMPLETE

**Problem:** High/low tide labels clip at the top of the chart area (e.g., "High 1.67 ft" is cut off).

**Fix in `TideChart.tsx`:**
- Increase SVG top padding to accommodate labels above the highest data point
- Ensure high-tide labels render fully within the viewBox when they appear at the chart ceiling

**Files:**
- Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/shared/TideChart.tsx`

**Verify:** Visual inspection — all high/low labels fully visible, no clipping at chart edges.

---

## Phase 7: Dead Code Removal ✓ COMPLETE

Remove the wizard bathymetry download system (replaced by Phase 3's runtime CUDEM profiles):

- `POST /setup/marine/bathymetry` endpoint (`endpoints/setup.py` lines 2542-2576)
- `MarineBathymetryRequest/Response` models (`setup.py` lines 2521-2539)
- `_resolve_marine_bathymetry()` (`setup.py` lines 1006-1051)
- `BathymetryPoint` class (`config/marine_config.py` line 251)
- `bathymetric_profile` from `SurfSpotConfig` (`marine_config.py`)
- `download_bathymetric_profiles_unified()` from `enrichment/bathymetry.py`
- Admin bathymetry re-download route if it exists

**Keep:** `download_bathymetric_profile()` — reused by the new bidirectional download.

---

## Phase 8: CUDEM Cache Age Check ✓ COMPLETE

**Completed:** 2026-07-18. Commit: fd0a0f6.

Add 180-day mtime check to `_load_or_download_cudem_grid()` in `swan.py` (lines 102-138). If the cached file is older than 180 days, re-download. Same pattern for per-spot transect profile cache (Phase 3).

---

## Phase 9: Marine API Unit Conversion + Dashboard Unit Neutrality

**Problem:** The beach profile endpoint returns `distance` and `depth` hardcoded in meters regardless of the operator's configured unit system. Per ADR-042, the API is the single conversion authority — the dashboard has zero unit knowledge. This violates the architecture and forces dashboard-side conversion hacks that shouldn't exist.

### 9a. API: Marine endpoint unit conversion audit

Audit ALL marine endpoints to verify every numeric field is converted to the operator's configured display units before responding. Known gaps:

- **Beach profile endpoint** (`endpoints/beach_profile.py`): `distanceFromShore` and `depth` returned in meters — should use `group_distance` and `group_depth` (or a marine-appropriate depth group). `waveHeight` and `swellHeight` already converted.
- **Surf endpoint** (`endpoints/surf.py`): Verify `swellHeight`, `breakingFaceHeight`, `waveHeightAtBreak`, `directionalSpread`, `setup` are all converted.
- **Marine summary** (`endpoints/marine.py`): Verify `waveHeight`, `waterTemp`, `windSpeed` are converted. Investigate why Huntington Harbor `waterTemp` is null when OFS resolver IS wired in.
- **Beach profile `units` block**: Currently hardcodes `{"distance": "m", "depth": "m"}` — should reflect the actual converted units.

**Files:**
- Audit + fix: `endpoints/beach_profile.py`, `endpoints/surf.py`, `endpoints/marine.py`
- Reference: `services/units.py` (UnitTransformer), `docs/manuals/API-MANUAL.md` §16 unit groups

### 9b. Dashboard: Marine card unit neutrality audit

Verify ALL marine tab components display values as-is from the API with no dashboard-side conversion. The dashboard should only use the `units` block from the API response for label text. Known items:

- **BeachProfileChart.tsx**: Already cleaned up — displays raw API values. Confirm no residual conversion.
- **SurfingTab.tsx**: Verify wave heights, periods, distances displayed without conversion.
- **BoatingTab.tsx**, **FishingTab.tsx**, **BeachSafetyTab.tsx**: Spot-check for any hardcoded unit assumptions.
- **LocationCard.tsx**: Verify it uses `units` block labels, not hardcoded "ft"/"m".

**Verify:** For a US-unit operator, all marine values display in feet/knots/°F. For a metric operator, all display in meters/km-h/°C. No mixed units, no hardcoded unit strings.

---

## Phase 10: ~~Documentation & Manual Updates~~ → SUPERSEDED by Phase 17

Original scope absorbed into Phase 17 (expanded to cover nesting redesign docs).

---

## Phase 11: ~~Adversarial Audit~~ → SUPERSEDED by Phase 18

Original scope absorbed into Phase 18 (expanded to cover nesting redesign verification).

---

## Phase 12: Sundry Fixes

Quick independent fixes — no dependencies on nesting redesign.

### 12a. Remove debug logging
Commits 36aefe7 and 60a27da added diagnostic logging to `swan_runner.py` and `swan_formats.py` during session 1 debugging. Remove:
- `swan_runner.py` line ~1249: 10-line INFO log of transect profile data
- `swan_formats.py` line ~525: `import logging` + 11-line INFO log inside `compute_spot_transect()`

### 12b. Wizard: filter inactive NDBC/CO-OPS stations
The wizard's `discover-stations` endpoint returns ALL stations within radius, including decommissioned/inactive ones (e.g., NDBC prjc1 at Huntington Harbor). Filter to active-only:
- NDBC: check station metadata for active status before returning in discovery results
- CO-OPS: same — filter stations with no recent data (>30 days stale)
- This is why marine summary waterTemp is null for some locations — the wizard paired them with dead stations

### 12c. Remove commit 5275993 debug logging
`cache_warmer.py` has an INFO log from quick-update HRRR debugging. Remove.

---

## Phase 13: GSFM Shelf Boundary Data Integration

Prerequisite for the nesting redesign. Ships a static shelf boundary dataset with the API for domain sizing.

**What:**
1. Download the GSFM (Harris et al. 2014) shapefile archive from bluehabitats.org
2. Extract the "shelf" polygon layer
3. Dissolve into a single global multipolygon
4. Extract the outer boundary as a polyline (shelf/slope transition)
5. Simplify to reduce file size (~10-20 MB target)
6. Ship as a static data file in the API package (e.g., `data/gsfm_shelf_boundary.geojson`)
7. Implement `find_shelf_distance(lat, lon)` — nearest-point-on-polyline query, returns distance in km

**Verify:** `find_shelf_distance(33.66, -118.00)` returns ~20-25 km (HB to San Pedro shelf edge).

**Files:**
- New: `weewx_clearskies_api/data/gsfm_shelf_boundary.geojson` (static asset)
- New: `weewx_clearskies_api/services/shelf_boundary.py` (query function)
- Modify: `pyproject.toml` (include data file in package)

---

## Phase 14: 3-Level Nesting Implementation

The core architectural change. Replaces the current 2-level system (3km outer + 200m inner) with the designed 3-level system (1km + 100m + 10m). Full design in `docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md` §5.

### ⚠️ SWAN REGRESSION PREVENTION — HARD RULES

**Context:** The SWAN-CORRECTIONS-PLAN delivered working SWAN input generation. Then a subsequent plan's agents rewrote parts of that code and broke it — the same issues (wrong INPUT commands, bad coordinate formats, missing HOTFILE, wrong CURVE syntax) had to be debugged ALL OVER AGAIN. SWAN is not ordinary code. Its INPUT file is a domain-specific language with exact syntax requirements. A missing space, a wrong keyword order, or a removed line can produce silent failures (SWAN runs but gives garbage output) or crashes with cryptic Fortran error messages.

**RULE 1 — Preserve proven INPUT patterns.** The following SWAN INPUT file patterns were debugged and verified working in Phases 1-8. They must NOT be modified unless the agent can cite the specific SWAN User Manual section that justifies the change:
- `HOTFILE` unconditional write (Phase 1 fix)
- `INIT HOTSTART` conditional on file existence
- `CURVE` coordinate format and point specification
- `TABLE` output variable list (HSIGN, HSWELL, DIR, TM01, DEPTH, QB, DISSURF, SETUP, DSPR)
- `OBSTACLE` transmission coefficient format
- `WLEVEL` / `CURRENT` input specification
- `TRIAD` / `SETUP` physics activation
- `NESTOUT` boundary file commands
- UTM coordinate transformation (commit 0610b3d — required for SETUP command)

**RULE 2 — Additive, not rewrite.** The Phase 14 implementation ADDS a third grid level. It does NOT rewrite the inner grid logic. The existing inner nest code becomes Level 3 (with resolution and domain changes). The existing outer grid code becomes Level 1 (with resolution and domain changes). Level 2 is NEW code inserted between them. The orchestration changes; the per-grid INPUT generation preserves the proven patterns.

**RULE 3 — Regression test before every deploy.** After any change to `swan_runner.py` or `swan_formats.py`, run the existing SWAN setup on production data (current HB Pier config) and verify:
- SWAN exits 0 (no crash)
- TABLE output has non-exception values (Hs > 0, not -9.0)
- QB > 0 at at least one transect point (breaking detected)
- Hotstart files written
If ANY of these fail, the change has regressed and must be reverted before proceeding.

**RULE 4 — No blind refactoring.** Agents must NOT "clean up," "refactor," or "simplify" the SWAN input generation code while implementing the nesting changes. Every line in `build_swan_input()` exists because SWAN requires it in that exact form. If something looks redundant or oddly formatted, it's probably a SWAN syntax requirement that was debugged into place. Leave it alone unless the change is explicitly in the Phase 14 scope.

**RULE 5 — Read the SWAN commands extract.** Before writing ANY code that modifies SWAN INPUT generation, the agent MUST read `docs/reference/swan-commands-extract.md` (the extracted SWAN command reference). Every command, keyword, and parameter format in the INPUT file must comply with this document. Agent prompts must include this file in the reading list.

### 14a. Domain sizing algorithm
Replace the current `all_spots ± 1.0°` bbox computation with physics-based sizing:

**Level 1 (coarse, 1km):**
- Lateral: all spots extent + 5 km margin each side
- Offshore: spot to GSFM shelf boundary distance + 10 km margin
- Bathymetry: GEBCO at 450m or CUDEM at 1km

**Level 2 (nearshore, 100m):**
- Lateral: all spots extent + 1-2 km margin each side
- Offshore: shore to 30m depth (estimated from shelf slope or GEBCO point query)
- One shared grid for all spots
- Bathymetry: CUDEM at 100m

**Level 3 (surf zone, 10m):**
- Per spot (or merged cluster): 250m each side of pin × shore to 15m depth
- Spot clustering: adjacent spots <500m apart share one grid
- Bathymetry: CUDEM at native 3.4m, averaged to 10m

**Files:**
- New: `weewx_clearskies_api/services/swan_domain.py` (domain sizing, clustering, bbox computation)
- Modify: `weewx_clearskies_api/providers/nearshore/swan.py` (use new domain sizing)

### 14b. Per-level bathymetry downloads
Replace the single `_load_or_download_cudem_grid()` (which downloads at outer resolution for everything) with per-level downloads:
- Level 1: download CUDEM/GEBCO at 1km spacing for Level 1 bbox
- Level 2: download CUDEM at 100m spacing for Level 2 bbox
- Level 3: download CUDEM at native 3.4m for each Level 3 grid bbox, then average to 10m

Each level's bathymetry cached independently. 180-day TTL (existing).

**Files:**
- Modify: `weewx_clearskies_api/providers/nearshore/swan.py` (per-level CUDEM downloads)
- Modify: `weewx_clearskies_api/services/swan_formats.py` (write BOTTOM.txt per level at correct resolution)

### 14c. 3-level SWAN execution
Modify `SWANRunner` to execute 3 sequential SWAN runs per full cycle:
1. Level 1 → writes NESTOUT for Level 2 boundary
2. Level 2 → reads Level 1 NESTOUT, writes NESTOUT for Level 3 boundaries
3. Level 3 (per cluster grid) → reads Level 2 NESTOUT, writes TABLE + CURVE output

Quick updates: Level 3 only (stationary, latest wind from most recent Level 2).

**Files:**
- Modify: `weewx_clearskies_api/services/swan_runner.py` (3-level orchestration)
- Modify: `weewx_clearskies_api/services/swan_formats.py` (INPUT file generation for 3 levels)

### 14d. Spot clustering algorithm
At SWAN run time, sort spots along coast and merge those <500m apart into shared Level 3 grids. Each cluster's grid extends from 250m before the first pin to 250m after the last.

**Files:**
- Part of `weewx_clearskies_api/services/swan_domain.py` (from 14a)

**Verify (full Phase 14):**
- SWAN produces output at all 3 levels without crashing
- Level 3 TABLE shows depth decreasing to 0-1m (reaches shore)
- QB > 0 at surf zone points (breaking detected)
- Beach profile API returns break points with realistic depths/distances
- HB Pier spot: outer break visible in profile
- Runtime for 1 spot: ≤15 min total on 6 cores

---

## Phase 15: Data Source Bbox Alignment

Ensure all data source queries use the computed grid bboxes as the single source of truth — no independent radius calculations.

**Alignment requirements:**
- Overpass API structure discovery: query must cover each Level 3 grid bbox (not just a radius around the pin)
- CUDEM bathymetry downloads: per-level bboxes (from Phase 14b)
- OFS current/temp extraction: verify WCOFS coverage includes full Level 2 domain
- WW3 boundary point selection: use Level 1 offshore boundary coordinates

**Modify wizard's discover-structures endpoint:** Accept a bbox parameter (computed from the spot clustering algorithm) instead of a fixed radius_m. The wizard computes the Level 3 grid extent for the spot configuration, then uses that bbox for structure discovery.

**Files:**
- Modify: `weewx_clearskies_api/endpoints/setup.py` (`discover-structures` endpoint — accept bbox)
- Modify: `weewx_clearskies_api/services/swan_domain.py` (expose bbox computation for wizard use)

---

## Phase 16: Wizard/Admin Compute Calculator

Before/after compute estimate displayed when operator adds, moves, or removes spots.

**Display:** Table showing estimated runtime before and after the pending change. Marginal cost visible — clustered spots cheap, isolated spots expensive.

**Formula:** `estimated_runtime_sec = total_cells × (0.05 / (cores / 6))`

**Inputs (all available at wizard time):**
- Spot positions → clustering algorithm → grid count and sizes
- GSFM shelf distance → Level 1 offshore extent
- Shore-to-30m distance (GEBCO query or shelf slope estimate) → Level 2 cross-shore
- Operator's configured core count

**Also expose:** Choice of 2-4 full runs per day (frequency selector). The calculator shows per-run time; operator picks frequency knowing the cost.

**Files:**
- Modify: stack repo wizard marine step (add compute estimate display)
- Modify: stack repo admin marine section (same)
- New: `weewx_clearskies_api/services/swan_domain.py` already has the sizing math — expose via `/setup/marine/compute-estimate` endpoint

---

## Phase 9: Marine API Unit Conversion + Dashboard Unit Neutrality

(Unchanged from original plan — still pending.)

---

## Phase 17: Documentation & Manual Updates

Update governing documents to reflect all changes (expanded from original Phase 10):

- **ARCHITECTURE.md**: Update SWAN note — 3-level nesting (1km/100m/10m), GSFM-based domain sizing, spot clustering, per-level bathymetry, scheduling model (2-4 runs/day + hourly quick updates). Remove `/setup/marine/bathymetry` endpoint. Update cell counts and runtime estimates.
- **API-MANUAL.md §17-18**: Update scoring, transect, beach profile, and SWAN architecture sections.
- **PROVIDER-MANUAL.md §14.15**: Rewrite SWAN runner section — 3-level execution, domain sizing, bathymetry per level, clustering.
- **OPERATIONS-MANUAL.md**: New operator guidance on spot placement, compute cost, frequency selection.
- **DASHBOARD-MANUAL.md**: Beach profile card updates, compute calculator in admin.
- **Research brief**: Mark as COMPLETE (all design decisions settled).

---

## Phase 18: Adversarial Audit (QC Gate)

(Expanded from original Phase 11 — covers all new phases.)

`clearskies-auditor` reviews the full diff against:
1. This plan — every phase's acceptance criteria met
2. The nesting research brief — architecture matches design
3. ARCHITECTURE.md — reflects actual behavior
4. Code quality — no dead references to old 2-level system, no stale bathymetry logic
5. Production verification — 3-level SWAN run produces valid output at HB Pier

---

## Execution Order

```
Phases 1-8          ← COMPLETE (session 1)
Phase 12 (Sundry)   ← independent, ship immediately
Phase 9 (Units)     ← independent, can run in parallel with 13-14
Phase 13 (GSFM)    ← prerequisite for Phase 14
Phase 14 (Nesting) ← the big one, depends on 13
Phase 15 (Alignment) ← depends on 14 (needs domain sizing to exist)
Phase 16 (Calculator) ← depends on 14 (needs sizing math)
Phase 17 (Docs)     ← after all code phases complete
Phase 18 (Audit)    ← final gate
```

Phase 12 and Phase 9 are independent — ship anytime.
Phase 13 enables Phase 14 (must have shelf data before domain sizing works).
Phases 15-16 depend on Phase 14's domain sizing algorithm.
Phases 17-18 are the closeout gate.
