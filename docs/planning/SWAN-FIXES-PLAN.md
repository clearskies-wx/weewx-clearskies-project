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

## Phase 17: Documentation Sync (PRE-GATE for Phases 19-24)

Governing documents must accurately describe the current system state BEFORE agents begin Phases 19-24. Agents read these manuals to understand what exists — stale docs cause agents to build on wrong assumptions. This is a HARD prerequisite: no Phase 19+ work starts until Phase 17 is complete and the auditor confirms docs match code.

**Why this is urgent:** The current PROVIDER-MANUAL §14.15 still describes a 2-level nesting system (outer + inner). The ARCHITECTURE.md SWAN section does not mention the nesting file convention (nest_in.dat / nest_out.dat), the profile-based grid sizing, or the VDatum datum correction. An agent reading these docs before implementing the OPeNDAP fetcher would make the same assumptions that caused the Bug 1-3 failures.

### T17.1 — PROVIDER-MANUAL §14.15 rewrite

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `docs/manuals/PROVIDER-MANUAL.md`

**Do:** Rewrite §14.15 (SWAN runner) to describe the actual 3-level system:

1. **Nesting architecture:** Level 1 (1km) -> Level 2 (100m) -> Level 3 (10m per cluster). Document the NESTOUT file flow: Level 1 writes `nest_out.dat`, runner copies to Level 2 as `nest_in.dat`, Level 2 writes `nest_out.dat`, runner copies to Level 3 as `nest_in.dat`. Reference SWAN-FIXES-PLAN Bug 1 (2026-07-19) for why separate filenames are required.
2. **Domain sizing:** `swan_domain.py` computes all three levels from spot locations + GSFM shelf distance + beach-facing bearing. Level 3 offshore extent from cached bidirectional profile (shore to 15m depth), NOT hardcoded.
3. **Bathymetry per level:** `download_bathymetry_for_level()` with resolver priority chain (operator > NCEI regional > Great Lakes > CRM). Currently only CRM is implemented; Phases 19-21 add the higher-priority sources. Document the `DEM_all` staircase issue for areas without CUDEM coverage.
4. **Quick update:** `run_stationary_level3()` — stationary Level 3 per cluster using latest Level 2 NESTOUT, NOT the old `run_stationary_inner()` which uses the 2-level `outer/` path.
5. **Working directories:** `level1/`, `level2/`, `level3_{idx}/` — NOT `outer/` and `inner/`.
6. **Hotstart:** Per-level hotstart files (`level1_hotstart.dat`, `level2_hotstart.dat`, `level3_{idx}_hotstart.dat`).

**Accept:** An agent reading §14.15 can correctly implement the OPeNDAP fetcher (Phase 20) without hitting any of the pitfalls from Bug 1-3. No references to the old 2-level system remain in the section.

### T17.2 — ARCHITECTURE.md SWAN section update

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `docs/ARCHITECTURE.md`

**Do:** Update the SWAN/nearshore section to reflect:
- 3-level nesting (1km/100m/10m) with nesting file convention
- Domain sizing from `swan_domain.py` (bearing-aware, profile-based Level 3)
- Bathymetry resolver priority chain (currently CRM-only; Phases 19-24 add sources)
- Spot clustering for Level 3
- Quick update via `run_stationary_level3()`
- Removed: `/setup/marine/bathymetry` endpoint (deleted in Phase 7)

**Accept:** ARCHITECTURE.md SWAN section matches the deployed code. No stale references to 2-level system, `nest_boundary.dat`, or wizard bathymetry downloads.

### T17.3 — API-MANUAL §17-18 update

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `docs/manuals/API-MANUAL.md`

**Do:** Update scoring (§17) and beach profile (§18) sections:
- Scoring reference point: just offshore of biggest break (Phase 4), not closest-to-10m
- Transect: bidirectional from coastline (Phase 3), uses runtime CUDEM profile
- Beach profile response: unit conversion per ADR-042 (Phase 9 status)
- SWAN architecture reference: point to PROVIDER-MANUAL §14.15 (not duplicate)

**Accept:** API-MANUAL scoring and profile sections match the deployed endpoints.

### T17.4 — Other document updates

- Owner: Coordinator (Opus)
- Files: `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/DASHBOARD-MANUAL.md`, research briefs

**Do:**
- OPERATIONS-MANUAL: Spot placement guidance ("place pin where people surf"), compute cost visibility (Phase 16), SWAN working directory paths.
- DASHBOARD-MANUAL: Beach profile card (Phase 5 redesign), break point markers.
- SWAN-NESTING-RESEARCH-BRIEF: Update status line — implementation landed but with Bug 1-3 fixes needed. Note that CUDEM 1/9" does NOT cover SoCal (§2 finding from BATHYMETRY-RESOLUTION-BRIEF).
- BATHYMETRY-RESOLUTION-BRIEF: Mark status as "RESEARCH COMPLETE — Phases 19-24 implement findings."

**Accept:** All governing documents match the deployed code. No doc references the old 2-level system, the old `nest_boundary.dat` filename, or the old `outer/inner/` directory structure.

### QC Gate 17

- `clearskies-auditor` verifies:
  - `grep -ri "nest_boundary\.dat" docs/` returns zero hits (only the SWAN-FIXES-PLAN Bug 1 history section is exempt).
  - `grep -ri "outer/.*inner/" docs/manuals/` returns zero hits (old directory references removed).
  - PROVIDER-MANUAL §14.15 describes the 3-level system with correct file conventions.
  - ARCHITECTURE.md SWAN section matches the deployed code state.
  - An agent reading only the manuals (not the plan or briefs) could correctly describe the nesting file flow, quick update path, and domain sizing algorithm.
  - All test baselines hold.

---

## Phase 18: Pre-Implementation Audit (REDO)

Phase 18 was originally marked COMPLETE in session 3, but its acceptance criterion "production verification — 3-level SWAN run produces valid output at HB Pier" was signed off without being verified. The output was zeros. This phase is a REDO with actual verification.

### T18.1 — Deploy Bug 1-3 fixes and verify

- Owner: Coordinator (Opus)
- Depends on: Bug 1-3 code changes (already committed locally this session)

**Do:**
1. Deploy the API via `scripts/deploy-api.sh`.
2. Delete stale bathymetry and boundary caches on the server:
   - `/var/run/weewx-clearskies/swan/level2/nest_boundary.dat` (old filename — will not be recreated)
   - `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json` (will re-download with source tag)
   - Level 1/2/3 bathymetry cache JSONs (will re-download)
3. Wait for next SWAN full run (triggered by cache warmer on HRRR cycle).
4. Run the Phase 23c regression gate against production output:
   a. SWAN exits 0 (check logs)
   b. TABLE output has Hs > 0 at scoring depth (check `level3_0/TABLE_1.txt`)
   c. QB > 0 at at least one transect point
   d. Surf forecast card shows non-zero swell height
   e. Beach profile card shows cross-section with depth decreasing toward shore
5. Verify the nesting file convention:
   - `level2/` directory contains BOTH `nest_in.dat` (from Level 1) AND `nest_out.dat` (Level 2's output) — different files, different sizes.
   - `level3_0/` directory contains `nest_in.dat` (from Level 2).
   - No file named `nest_boundary.dat` exists in any level directory.
6. Verify quick update fires:
   - Wait for the next hourly cycle.
   - Check logs for `"SWAN stationary L3"` (not `"SWAN stationary inner"` — that's the old path).
   - Confirm the forecast card updates with a new "Last model run" timestamp.

**Accept:** All 6 verification items pass with evidence (log excerpts, file sizes, screenshot). This is not a checkbox exercise — the evidence is included in the completion report.

### QC Gate 18

- `clearskies-auditor` verifies:
  - All T18.1 acceptance criteria met with evidence.
  - No `nest_boundary.dat` files exist in the SWAN working directory.
  - Quick update uses the 3-level path (log evidence).
  - Surf forecast card shows non-zero swell.

---

---

## Phase 19: NCEI Regional DEM Index ✓ COMPLETE

**Completed:** 2026-07-19. Commits: e9aacfb (index + build script), c4e0049 (resolver), 05e8632 (docs).

Build a static JSON index of all ~262 NCEI regional coastal DEMs so the bathymetry resolver can find the highest-resolution data source for any US coastal bbox.

### T19.1 — Scrape THREDDS catalog and build DEM index

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `scripts/build_ncei_dem_index.py` (one-time build script, not shipped)
  - New: `weewx_clearskies_api/data/ncei_regional_dem_index.json` (static asset, shipped)
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §3 Tier 1, §6

**Background:** NCEI hosts 262 regional coastal DEMs at `https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.xml`. Each is a NetCDF file built for tsunami inundation modeling, integrating the best available survey data (NOS hydrographic, CSMP multibeam, JALBTCX lidar) for each coastal region. Resolutions range from 1/3 arc-second (~10m) to 3 arc-second (~90m) depending on the region.

**Catalog structure (verified):** The THREDDS catalog XML is flat — no nested `catalogRef` elements. Each `<dataset>` entry has a `name` attribute with the filename and a `urlPath` attribute. Namespace: `{http://www.unidata.ucar.edu/namespaces/thredds/InvCatalog/v1.0}`.

**Metadata access (verified):** Each file's OPeNDAP `.das` endpoint (plain HTTP text, no xarray needed) contains pre-computed global attributes:
- `geospatial_lat_min`, `geospatial_lat_max`, `geospatial_lon_min`, `geospatial_lon_max` — bounding box
- `geospatial_lat_resolution`, `geospatial_lon_resolution` — cell size in degrees
- `geospatial_bounds_vertical_crs` — vertical datum string (e.g., "NAVD88 height", "Mean High Water height")

The vertical datum is also encoded in the filename convention:
| Pattern | Datum |
|---------|-------|
| `_navd88_` | NAVD88 |
| `_mhw_` | Mean High Water |
| `_mhhw_` | Mean Higher High Water |
| `_mllw_` | Mean Lower Low Water |

**Elevation variable naming (verified, inconsistent across files):**
- Older DEMs (pre-~2015): variable named `Band1`
- Newer DEMs (post-~2018): variable named `z`
- Coordinates are always `lat` and `lon` (Float64)

The index must record the elevation variable name per file so the OPeNDAP fetcher (Phase 20) knows which variable to query.

**Do:**
1. Write `scripts/build_ncei_dem_index.py`:
   a. Fetch `https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.xml`
   b. Parse with `xml.etree.ElementTree`. Extract all `name` attributes where `urlPath` is present.
   c. For each filename, fetch `https://www.ngdc.noaa.gov/thredds/dodsC/regional/{filename}.das` (plain HTTP GET, text response).
   d. Use concurrent requests (`asyncio` + `aiohttp`, 20 concurrent connections — ~30 seconds total for 262 files).
   e. Regex-extract from each `.das` response: `geospatial_lat_min`, `geospatial_lat_max`, `geospatial_lon_min`, `geospatial_lon_max`, `geospatial_lat_resolution`, `geospatial_bounds_vertical_crs`.
   f. Detect the elevation variable name: check if `.das` contains `z {` or `Band1 {`.
   g. Parse resolution from filename convention (`_13_` = 1/3", `_1_` = 1", `_815_` = 8/15", etc.) as a cross-check against the `geospatial_lat_resolution` attribute.
   h. Write the index to `weewx_clearskies_api/data/ncei_regional_dem_index.json`.
2. Run the script and commit the resulting JSON file.
3. Add `data/ncei_regional_dem_index.json` to `pyproject.toml` `[tool.setuptools.package-data]` so it ships with the API package.

**Index JSON schema:**
```json
{
  "generated": "2026-07-20T00:00:00Z",
  "source": "https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.xml",
  "dems": [
    {
      "filename": "orange_county_13_navd88_2015.nc",
      "lat_min": 32.62,
      "lat_max": 33.85,
      "lon_min": -118.90,
      "lon_max": -117.45,
      "resolution_arcsec": 0.333,
      "resolution_m_approx": 10.0,
      "vertical_datum": "NAVD88",
      "elevation_var": "Band1"
    }
  ]
}
```

**Accept:**
- Index JSON contains entries for all 262 DEMs with valid bounding boxes and resolutions.
- `orange_county_13_navd88_2015.nc` entry covers HB Pier (33.65N, 118.00W) — `lat_min < 33.65 < lat_max` and `lon_min < -118.00 < lon_max`.
- Every entry has a non-null `vertical_datum` and `elevation_var`.
- Index is committed and included in the package build.

### T19.2 — Implement `find_best_dem(bbox)` resolver

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `weewx_clearskies_api/services/bathymetry_resolver.py`
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §6

**Do:**
1. Create `bathymetry_resolver.py` with function `find_best_dem(bbox: tuple[float, float, float, float]) -> dict | None`.
2. Load the index JSON at module import time (single read, cached in module global).
3. For the given bbox `(lon_min, lat_min, lon_max, lat_max)`, find all index entries whose bounding box **fully contains** the query bbox.
4. From the matching entries, return the one with the smallest (finest) `resolution_arcsec`. This ensures the highest-resolution DEM is used when multiple overlap (common for coastal areas with both regional and national DEMs).
5. Return `None` when no DEM fully covers the bbox (caller falls back to `DEM_all`).
6. Return dict: `{"filename": str, "resolution_m": float, "vertical_datum": str, "elevation_var": str}`.

**Accept:**
- `find_best_dem((-118.06, 33.60, -117.98, 33.67))` returns `orange_county_13_navd88_2015.nc` (Level 2 bbox at HB Pier).
- `find_best_dem((-118.01, 33.64, -118.00, 33.66))` returns the same file (Level 3 bbox — fully contained within the OC DEM).
- `find_best_dem((-90.0, 25.0, -89.0, 26.0))` returns a Gulf Coast DEM if one covers it, or `None` if no regional DEM covers this area.
- Bbox partially outside all DEMs returns `None` (no partial matches — caller handles fallback).
- Index loads in <10ms (JSON parse + list scan — 262 entries is trivial).

### T19.3 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/PROVIDER-MANUAL.md` §14.7, `docs/ARCHITECTURE.md`

**Do:**
- PROVIDER-MANUAL §14.7: Add the NCEI regional DEM index as a data source. Document the index JSON schema, the `find_best_dem()` priority logic, and the fallback chain (regional DEM > Great Lakes > CRM).
- ARCHITECTURE.md: Add `bathymetry_resolver.py` to the services layer. Note that the DEM index is a static asset built offline, not a runtime dependency.

**Accept:** Manual describes the index structure, resolution priority logic, and fallback chain.

### QC Gate 19

- `clearskies-auditor` verifies:
  - Index JSON has 262 entries with valid bbox values.
  - `find_best_dem()` returns correct DEM for at least 5 test bboxes (HB Pier, San Diego, Wrightsville Beach NC, a Great Lakes point, an uncovered international point).
  - Index JSON is listed in `pyproject.toml` package data.
  - `bathymetry_resolver.py` has no circular imports with `swan.py` or `swan_formats.py`.
  - PROVIDER-MANUAL §14.7 matches implementation.
  - All test baselines hold.

---

## Phase 20: OPeNDAP Bathymetry Fetcher ✓ COMPLETE

**Completed:** 2026-07-19. Commits: c4e0049 (fetch_opendap_grid + VDatum), 3d6c675 (wiring), cf9518f (bidirectional profile), 05e8632 (docs).

Replace the `DEM_all/ImageServer/getSamples` query with OPeNDAP subset queries against the NCEI regional DEMs. This is the critical path — without it, the 3-level system runs on ~90m CRM data.

### T20.1 — OPeNDAP NetCDF subset query function

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/bathymetry_resolver.py` (add OPeNDAP fetch)
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §3 Tier 1

**Background:** `xarray` can open remote NetCDF files via OPeNDAP natively — it fetches only the requested subset, not the full file. The URL pattern is `https://www.ngdc.noaa.gov/thredds/dodsC/regional/{filename}`. `xarray` is already a dependency via the `[marine]` extra.

**Elevation variable naming inconsistency:** Older DEMs use `Band1`, newer ones use `z`. The index (Phase 19) records which variable name each file uses.

**Sign convention:** Regional DEMs use CUDEM convention (negative = ocean, positive = land). This matches what `cudem_to_swan_bottom()` expects — no sign flip needed at the resolver level.

**Do:**
1. Add function `fetch_opendap_grid(filename: str, bbox: tuple, resolution_m: float, elevation_var: str) -> dict[str, Any]` to `bathymetry_resolver.py`.
2. Open the OPeNDAP URL: `xr.open_dataset(f"https://www.ngdc.noaa.gov/thredds/dodsC/regional/{filename}")`.
3. Subset coordinates: `ds.sel(lat=slice(lat_min, lat_max), lon=slice(lon_min, lon_max))`. Handle the case where `lon` might be stored as 0-360 instead of -180 to 180 (add 360 to negative query longitudes if needed).
4. Read the elevation variable: `ds[elevation_var].values` — this triggers the actual download of only the subset.
5. If the requested `resolution_m` is coarser than the DEM's native resolution, resample using `xarray.DataArray.coarsen()` or `scipy.ndimage.zoom` to avoid downloading an unnecessarily large grid. For example, Level 2 (100m) should not download the full 10m grid — coarsen by a factor of 10 first.
6. Convert the xarray output to the dict format `cudem_to_swan_bottom()` expects:
   ```python
   {
       "lat_first": float(subset.lat.min()),
       "lon_first": float(subset.lon.min()),
       "lat_last": float(subset.lat.max()),
       "lon_last": float(subset.lon.max()),
       "ni": int(subset.sizes["lon"]),
       "nj": int(subset.sizes["lat"]),
       "depths": subset_values.tolist(),  # [nj][ni], CUDEM convention
   }
   ```
7. Close the dataset after reading (`ds.close()`).
8. Add a 30-second timeout on the OPeNDAP connection.
9. On any `xarray`/OPeNDAP failure, raise `ProviderError` with a clear message including the URL and the underlying exception.

**Accept:**
- `fetch_opendap_grid("orange_county_13_navd88_2015.nc", (-118.06, 33.60, -117.98, 33.67), 100.0, "Band1")` returns a grid dict with `depths` containing negative values (ocean) and the correct bbox.
- At 100m resolution (Level 2), the download takes <10 seconds and returns a ~75x75 grid (not the full DEM).
- At 10m resolution (Level 3), the download returns a ~220x220 grid with smooth depth gradients (no staircase pattern).
- The grid has MORE than 3 unique depth values per 100m (proving it's not CRM data).
- Connection timeout after 30 seconds produces a `ProviderError`, not a hang.

### T20.2 — Vertical datum normalization via VDatum REST API

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/bathymetry_resolver.py`
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §3 (datum conventions per DEM)

**Background:** SWAN expects depth relative to MSL (Mean Sea Level). The NCEI regional DEMs use different datums. The offsets between datums are **NOT constant** — they vary dramatically by location:

| Location | NAVD88 relative to MSL | MHW relative to MSL | MLLW relative to MSL |
|----------|----------------------|---------------------|---------------------|
| San Diego (9410170) | **-0.764m** | +0.623m | -0.896m |
| Sandy Hook NJ (8531680) | **+0.073m** | +0.707m | -0.785m |

A 0.764m error in 2m of water is a 38% depth error. SWAN's breaking criterion (Hs/d ~ 0.73) would shift the breakpoint by tens of meters. **Constant regional offsets are wrong. VDatum queries are required.**

**NOAA VDatum REST API (verified, free, no API key):**
```
GET https://vdatum.noaa.gov/vdatumweb/api/convert
    ?s_x={lon}&s_y={lat}&s_z=0
    &s_v_frame={source_datum}&t_v_frame=LMSL
    &region=contiguous
```

Returns JSON with `t_z` (converted height) and `uncertainty`. Supported frames: `NAVD88`, `NGVD29`, `LMSL`, `MLLW`, `MLW`, `MHW`, `MHHW`, `MTL`, `DTL`. Great Lakes use `region=gl` with IGLD85.

**pyproj CANNOT do tidal datum transforms** — it handles ellipsoidal/geoid heights (NAVD88 to NAD83) but not the tidal offsets between NAVD88 and MSL/MLLW/MHW. The VDatum REST API is the only programmatic path.

**Do:**
1. Add function `_query_vdatum_offset(lat: float, lon: float, source_datum: str) -> float`:
   a. Map our datum names to VDatum frame names: `NAVD88` = `NAVD88`, `MHW` = `MHW`, `MLLW` = `MLLW`, `MHHW` = `MHHW`.
   b. Target frame: `LMSL` (Local Mean Sea Level).
   c. Region: `contiguous` for CONUS, `gl` for Great Lakes (detect from lat/lon), `westcoast_ak` for Alaska, `hi` for Hawaii, `prvi` for PR/USVI.
   d. Query the VDatum REST endpoint. Parse `t_z` from the JSON response.
   e. Cache the offset per (lat_rounded, lon_rounded, datum) — the offset varies slowly over space (~10km scale). One query per SWAN run is sufficient (use the grid center point).
   f. On VDatum API failure: log a warning and use a fallback offset of 0.0m with a warning: `"VDatum API unavailable — no datum correction applied. Bathymetry may have up to ~1m vertical bias."`.
   g. Rate limit: 1 request per second (VDatum is a government service with no published limits — be conservative).
2. Add function `_normalize_to_msl(depths, datum, center_lat, center_lon)`:
   a. If `datum == "MSL"` or `datum == "LMSL"`: return depths unchanged.
   b. Otherwise: query VDatum for the offset at (center_lat, center_lon).
   c. Apply the offset uniformly to all depth values (the offset varies slowly enough that a single-point query covers the typical Level 2/3 grid extent of ~5km).
   d. Log: `"Applied {datum} to MSL offset: {offset:.3f}m via VDatum at ({lat:.2f}, {lon:.2f})"`.
3. Handle Great Lakes: use `region=gl` with `s_v_frame=IGLD85` if the DEM uses IGLD85.

**Accept:**
- At HB Pier (NAVD88 DEM): VDatum returns offset ~-0.764m. Depths are shifted accordingly.
- At Sandy Hook NJ (NAVD88 DEM): offset ~+0.073m (opposite sign — confirms spatially-varying).
- VDatum API failure produces a warning and 0.0m fallback, not a crash.
- The offset is cached — second SWAN run doesn't re-query VDatum.
- Log line shows the datum, offset, and query location for every download.

### T20.3 — Wire OPeNDAP into per-level bathymetry download

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/providers/nearshore/swan.py` (`download_bathymetry_for_level`)
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §6

**Do:**
1. Import `find_best_dem` and `fetch_opendap_grid` from `bathymetry_resolver.py`.
2. In `download_bathymetry_for_level()`, before the existing `download_swan_depth_grid()` call:
   a. Call `find_best_dem(bbox)` with the level's bbox.
   b. If a regional DEM is found:
      - Call `fetch_opendap_grid(dem["filename"], bbox, domain.resolution_m, dem["elevation_var"])`.
      - Call `_normalize_to_msl(grid["depths"], dem["vertical_datum"], center_lat, center_lon)`.
      - Cache the result at the existing cache path (same JSON format, same 180-day TTL).
      - Log: `"CUDEM L{level}: using NCEI {filename} ({resolution_m}m, {datum}) via OPeNDAP"`.
      - Return the grid.
   c. If `find_best_dem` returns `None`, fall through to the existing `download_swan_depth_grid()` call (CRM fallback).
   d. If the OPeNDAP fetch fails (timeout, network error), log a warning and fall through to CRM.
3. Add the data source name to the returned grid dict: `grid["source"] = "ncei_regional"` or `grid["source"] = "crm_fallback"`. This is consumed by the coverage endpoint (Phase 22).

**Accept:**
- For HB Pier: Level 2 and Level 3 bathymetry comes from `orange_county_13_navd88_2015.nc` (not `DEM_all`).
- For HB Pier: Level 1 bathymetry comes from `DEM_all` (the regional DEM doesn't cover the full Level 1 bbox — expected fallback).
- Cache file is written after successful OPeNDAP download.
- Subsequent runs hit the cache (no OPeNDAP query) until 180-day TTL expires.
- OPeNDAP failure falls back to CRM without crashing the SWAN run.
- Grid dict includes `"source"` key.

### T20.4 — Update the bidirectional profile download

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/enrichment/bathymetry.py` (`download_bidirectional_profile`)

**Background:** The bidirectional profile (used for Level 3 grid sizing and transect computation) currently uses the same `DEM_all/ImageServer/identify` single-point queries that produce staircase data. It should use the same OPeNDAP source when available.

**Do:**
1. Before the existing single-point query loop, check if a regional DEM covers the spot location: `find_best_dem(small_bbox_around_spot)`.
2. If found, download a small strip of OPeNDAP data (2D subset along the bearing) and extract the 1D profile from it. This replaces the ~48 individual `identify` queries with one OPeNDAP subset.
3. If not found, fall through to the existing single-point query path (unchanged).
4. Store the data source in the cached profile JSON: `"source": "ncei_regional"` or `"source": "crm_point_query"`.

**Accept:**
- For HB Pier, the bidirectional profile now has smooth depth progression (not staircase).
- The profile has >10 unique depth values across 48 sample points (vs the current 5-6 unique values from CRM).
- Level 3 grid sizing uses the improved profile, producing a grid that extends to the actual 15m depth contour.
- The profile source is recorded in the cached JSON.

### T20.5 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/PROVIDER-MANUAL.md` §14.7, `docs/reference/swan-commands-extract.md`

**Do:**
- PROVIDER-MANUAL §14.7: Document OPeNDAP as the primary bathymetry access method, CRM as fallback. Document the datum normalization approach and its limitations.
- Add OPeNDAP endpoint pattern and xarray usage to the technical reference.

**Accept:** Manual matches the implemented resolver chain.

### QC Gate 20

- `clearskies-auditor` verifies:
  - SWAN TABLE output at HB Pier shows >10 unique depth values across Level 3 transect points (no staircase).
  - Bidirectional profile for HB Pier has smooth depth progression (compare old vs new).
  - Level 3 grid sizing uses the improved profile to reach the actual 15m contour.
  - OPeNDAP failure gracefully falls back to CRM (test by temporarily using a bad URL).
  - Cache files are written and respected (second run does not query OPeNDAP).
  - Datum normalization offset is logged for every download.
  - PROVIDER-MANUAL §14.7 matches the implementation.
  - SWAN regression gate passes (Phase 23c criteria).
  - All test baselines hold.

---

## Phase 21: USGS Great Lakes DEM Integration ✓ COMPLETE

**Completed:** 2026-07-19. Commits: c4e0049 (Great Lakes functions), 3d6c675 (wiring), 05e8632 (docs).

Integrate the USGS Great Lakes seamless topobathymetric DEMs (Rohweder 2025) for operators with spots on the Great Lakes.

### T21.1 — Great Lakes DEM download and cache

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/bathymetry_resolver.py`
  - Modify: `pyproject.toml` (add `rasterio` to `[nearshore]` extra)
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §3 Tier 2

**Background:** The USGS provides per-lake seamless topobathymetric DEMs as GeoTIFF files (Rohweder 2025, DOI: 10.5066/P1DA6L6U). Files range from 154 MB (Ontario) to 1.4 GB (Michigan) compressed. CRS: NAD83 geographic (EPSG:4269), effectively identical to WGS84. Source data: 2006-2016 lidar + USACE dredge surveys. Resolution: ~3-5m.

GeoTIFF windowed reads (via `rasterio`) are efficient when the file is internally tiled (USGS DEMs are). Only the tiles intersecting the requested bbox are read from disk — no need to load the full file.

**ScienceBase download:** Each lake's GeoTIFF is downloadable from ScienceBase. The ScienceBase API returns download links: `https://www.sciencebase.gov/catalog/item/{id}?format=json` then `files[].url`.

| Lake | ScienceBase ID | Compressed size |
|------|---------------|----------------|
| Michigan | `669041b8d34e341cbf15576c` | 1.4 GB |
| Erie | `66903b2dd34e7f6636ec211b` | 521 MB |
| Huron | `66904150d34e341cbf15576a` | 546 MB |
| Ontario | `669041edd34e341cbf15576e` | 154 MB |
| Superior | `6690427ad34e341cbf155772` | 903 MB |
| St. Clair | `66904251d34e341cbf155770` | 168 MB |

**Do:**
1. Add `rasterio` to the `[nearshore]` extra in `pyproject.toml`. Import conditionally (same pattern as eccodes — `try: import rasterio` with graceful fallback).
2. Add lake bounding boxes as a constant dict in `bathymetry_resolver.py`.
3. Add function `is_great_lake(lat, lon) -> str | None` — returns the lake name if the point falls within a lake bbox, else `None`.
4. Add function `_ensure_great_lake_dem(lake) -> Path | None` — downloads from ScienceBase if not cached, 365-day TTL.
5. Add function `fetch_great_lake_grid(dem_path, bbox, resolution_m) -> dict` — rasterio windowed read, row-flip (rasterio = north-to-south, SWAN = south-to-north), nodata handling, output in standard grid dict format.

**Accept:**
- `is_great_lake(41.85, -87.62)` returns `"michigan"` (Chicago lakefront).
- `is_great_lake(33.66, -118.00)` returns `None` (HB Pier — not a Great Lake).
- `fetch_great_lake_grid()` returns a grid with smooth depth progression for a Lake Michigan nearshore bbox.
- The windowed read loads <50 MB of data from a 1.4 GB GeoTIFF (efficient tiled access).
- `rasterio` import failure is handled gracefully — Great Lakes path disabled, logged once.

### T21.2 — Wire into bathymetry resolver priority chain

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/providers/nearshore/swan.py` (`download_bathymetry_for_level`)

**Do:**
1. In `download_bathymetry_for_level()`, after the NCEI regional DEM check and before the CRM fallback:
   a. Call `is_great_lake(center_lat, center_lon)`.
   b. If on a Great Lake: call `_ensure_great_lake_dem(lake)` then `fetch_great_lake_grid(path, bbox, resolution_m)`.
   c. Cache the result at the existing cache path.
   d. The full priority chain is now: NCEI regional DEM > USGS Great Lakes > CRM fallback.

**Accept:**
- A spot at Chicago lakefront uses the Michigan Great Lakes DEM for Level 2/3.
- CRM fallback is not triggered for Great Lakes spots.
- Level 1 falls back to CRM (the Great Lakes DEM only covers the lake, not the surrounding region).

### T21.3 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
- PROVIDER-MANUAL §14.7: Add Great Lakes DEM as a data source in the resolver chain.
- OPERATIONS-MANUAL: Document the ~1.4 GB download for Great Lakes operators. Document cache location and TTL.

**Accept:** Manuals describe the Great Lakes data source, download behavior, and cache management.

### QC Gate 21

- `clearskies-auditor` verifies:
  - `is_great_lake()` returns correct results for 6 test points (one per lake + one non-lake).
  - Windowed read produces a grid with smooth depths (no staircase).
  - `rasterio` import failure disables Great Lakes path without crashing the API.
  - PROVIDER-MANUAL and OPERATIONS-MANUAL match implementation.
  - All test baselines hold.

---

## Phase 22: Bathymetry Coverage Indicator ✓ COMPLETE (API endpoint; admin UI deferred to stack repo work)

**Completed:** 2026-07-19. Commits: d467b4b (coverage endpoint + 13 locale files). Admin UI (T22.2) deferred — requires stack repo work.

Show the operator the bathymetry data quality for their spot locations in the admin marine section.

### T22.1 — API coverage endpoint: bathymetry section

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/endpoints/setup.py` (coverage endpoint)
  - Modify: `weewx_clearskies_api/locales/*.json` (13 locale files — i18n keys for quality labels and warnings)
- Reference: BATHYMETRY-RESOLUTION-BRIEF.md §6 "Coverage gate"

**Do:**
1. Extend the existing `GET /setup/marine/coverage` response to include a `bathymetry` object per SWAN grid level with source, resolution, quality tier, and warning text when degraded.
2. Quality tiers: `"high"` (regional DEM or Great Lakes, resolution <= 30m), `"degraded"` (CRM or DEM_all, resolution > 30m).
3. `"overall_quality"` is the minimum quality across Level 2 and Level 3.
4. **i18n:** All user-facing strings in the response (quality labels, source names, warning text) MUST use locale keys, not hardcoded English. Add keys to all 13 locale JSON files:
   - `marine.bathymetry.quality.high` / `marine.bathymetry.quality.degraded`
   - `marine.bathymetry.source.ncei_regional` / `marine.bathymetry.source.usgs_great_lakes` / `marine.bathymetry.source.crm` / `marine.bathymetry.source.operator`
   - `marine.bathymetry.warning.degraded` — the resolution warning
   English authoritative; other 12 locales get placeholder English.

**Accept:**
- For HB Pier: Level 2 and 3 report `"ncei_regional"` with `"high"` quality.
- For an uncovered location: `"degraded"` quality with warning text from locale key.
- For a Great Lakes spot: `"usgs_great_lakes"` with `"high"` quality.
- All text in the response comes from locale keys (no hardcoded English strings in Python code).

### T22.2 — Admin marine section: bathymetry display

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
  - Modify: all 13 locale translation files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/`

**Do:** Add a "Bathymetry Data" card to the admin marine section. HTMX-loaded from `/setup/marine/coverage`. Per-level quality indicator (green = high, amber = degraded). Help text link.

**i18n:** Add keys to all 13 stack translation files:
- `admin.marine.bathymetry.title` — card heading
- `admin.marine.bathymetry.level1` / `level2` / `level3` — level labels
- `admin.marine.bathymetry.resolution` — resolution display format
- `admin.marine.bathymetry.quality_high` / `quality_degraded` — quality indicator labels
- `admin.marine.bathymetry.help_link` — help text link label
All card labels, quality tier labels, and help text must come from translation keys — no hardcoded English in templates.

**Accept:** Admin page shows quality per level. Degraded shows warning. All visible text rendered from translation keys. Graceful fallback when endpoint unavailable.

### T22.3 — Update governing documents

- Owner: Coordinator (Opus)

**Do:** OPERATIONS-MANUAL and DASHBOARD-MANUAL — document the coverage indicator, quality tiers, and operator guidance.

**Accept:** Manuals match implementation.

### QC Gate 22

- `clearskies-auditor` verifies:
  - Coverage endpoint returns correct data for HB Pier, a degraded location, and a Great Lakes location.
  - Admin page displays correctly.
  - **i18n:** All 13 API locale files contain `marine.bathymetry.*` keys. All 13 stack translation files contain `admin.marine.bathymetry.*` keys. No hardcoded English in templates or Python response builders.
  - Manuals match.
  - All test baselines hold.

---

## Phase 23: SWAN INPUT Research & Cross-Section Fix ✓ COMPLETE (code; regression verification requires deploy)

**Completed:** 2026-07-19. Commits: 273e4b8 (meta, nesting reference), 486197f (API, transect + logging). T23.4 regression verification requires production deploy.

Before any further SWAN INPUT file modifications, complete the research that should have been done before Phase 14. This phase is a HARD prerequisite for any code touching `build_swan_input()` or `compute_spot_transect()`.

### T23.1 — SWAN manual deep read

- Owner: Coordinator (Opus)
- Output: `docs/reference/swan-nesting-reference.md`
- Reference: SWAN User Manual v41.51

**Do:** Read the full SWAN User Manual sections and extract findings:

1. **BOUNDNEST1 syntax and constraints (§4.5.5):** What happens when the nested grid extends outside the parent's NESTOUT coverage? CLOSED vs OPEN?
2. **NGRID + NESTOUT interaction (§3.5, §4.7):** Must NGRID match the child CGRID exactly? Resolution mismatch effects?
3. **Wet/dry cell determination:** What BOTTOM value makes a cell dry? What does SWAN output at dry CURVE points?
4. **CURVE output at dry points:** Confirm exception value behavior.
5. **Nesting ratio guidance:** Our 100m to 10m (10:1) exceeds the recommended 2-3x. Consequences?

**Accept:** Reference document answers all 5 questions with manual section citations and implications for our code.

### T23.2 — Fix cross-section transect placement

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/swan_formats.py` (`compute_spot_transect`)
- Depends on: T23.1

**Do:**
1. Determine wet/dry threshold from T23.1. Adjust `target_shallow_m` if needed.
2. Verify transect endpoints fall within the Level 3 grid bbox. Clip deep end if outside.
3. Log warnings for transect points with depth <= 0.

**Accept:**
- SWAN TABLE output has >80% valid (non-exception) points.
- Transect fits within the Level 3 grid.
- Warning log appears for dry points.

### T23.3 — API exception value handling

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/swan_runner.py` (`_parse_output`)
  - Modify: `weewx_clearskies_api/endpoints/surf.py` or `beach_profile.py`

**Do:**
1. Check TABLE values against -9.0 exception value. Exclude invalid points.
2. Filter null entries before scoring.
3. Log valid/total counts per transect.

**Accept:**
- API does not return 0.0 wave height from exception-value points.
- Log shows valid-point percentage per transect.

### T23.4 — Regression verification

After all T23 changes, the following MUST pass on production data before deploy:
1. SWAN exits 0
2. TABLE output has Hs > 0 at scoring depth
3. QB > 0 at at least one transect point
4. Surf forecast card shows non-zero swell matching buoy within 50%
5. Beach profile card shows depth decreasing toward shore

**This is a HARD GATE. Do not deploy without all 5 passing.**

### QC Gate 23

- `clearskies-auditor` verifies:
  - `swan-nesting-reference.md` exists and answers all 5 questions.
  - Transect points within grid. Exception values filtered. Valid-point logging.
  - All 5 regression checks pass.
  - All test baselines hold.

---

## Phase 24: Operator-Supplied Bathymetry Import

Let operators upload their own bathymetry file for higher-resolution nearshore data. Admin-only — not in the first-run wizard. This is an advanced feature for operators who know what bathymetry data is and where to get it.

### T24.1 — File import and validation

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `weewx_clearskies_api/services/bathymetry_resolver.py` (import logic)
  - Modify: `weewx_clearskies_api/endpoints/setup.py` (upload endpoint)

**Accepted formats:** GeoTIFF (`rasterio`), NetCDF (`xarray`), ASCII XYZ (`numpy`). Not v1: BAG, LAS/LAZ, proprietary formats — operators convert to GeoTIFF via QGIS/GDAL.

**Vertical datum:** Operator selects from dropdown (MSL, MLLW, NAVD88, MHW, LAT, EGM2008, Other with manual offset). System transforms to MSL via VDatum REST API (same as T20.2).

**Do:** Add `POST /setup/marine/bathymetry/upload` endpoint. Validate format, extract bbox/resolution, apply datum transform, compute per-level coverage, cache as GeoTIFF. Site-wide, not per-spot.

**i18n:** Validation response messages (coverage status, resolution notes, datum transform descriptions, format rejection reasons) MUST use API locale keys. Add keys to all 13 locale JSON files:
- `marine.bathymetry.upload.accepted` / `marine.bathymetry.upload.rejected`
- `marine.bathymetry.upload.format_unsupported`
- `marine.bathymetry.upload.coverage.full` / `coverage.partial` / `coverage.none` (per level)
- `marine.bathymetry.upload.resolution_note.exceeds` / `resolution_note.adequate` / `resolution_note.insufficient`
- `marine.bathymetry.upload.datum_applied`

**Accept:** Accepts GeoTIFF/NetCDF/ASCII XYZ. Rejects unsupported with locale-keyed message. Datum transform applied. Coverage validated per level. All response text from locale keys.

### T24.2 — Wire into resolver priority chain

- Owner: `clearskies-api-dev` (Sonnet)

**Do:** Add `get_operator_grid()` to resolver. Insert at top of priority chain: operator > NCEI > Great Lakes > CRM. Log source per level.

**Accept:** Operator file wins when present. Removing reverts to automated sources.

### T24.3 — Admin UI for bathymetry upload

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py`
  - Modify: all 13 locale translation files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/`

**Do:** Add "Bathymetry" card in admin marine section with upload field, datum dropdown, validation results, replace/remove buttons, help text link.

**i18n:** Add keys to all 13 stack translation files:
- `admin.marine.bathymetry.upload.title` — upload section heading
- `admin.marine.bathymetry.upload.label` — file input label
- `admin.marine.bathymetry.upload.help` — accepted formats help text
- `admin.marine.bathymetry.datum.label` — datum dropdown label
- `admin.marine.bathymetry.datum.msl` / `mllw` / `navd88` / `mhw` / `lat` / `egm2008` / `other` — datum option labels
- `admin.marine.bathymetry.datum.offset_label` — manual offset field label
- `admin.marine.bathymetry.datum.offset_help` — manual offset help text
- `admin.marine.bathymetry.actions.replace` / `actions.remove` — button labels
- `admin.marine.bathymetry.validation.*` — validation result labels (coverage, resolution, datum applied)
All visible text in the card — labels, dropdowns, buttons, help text, validation results — must render from translation keys. No hardcoded English in templates.

**Accept:** HTMX upload, inline validation, replace/remove works. All visible text comes from translation keys. Switching locale changes all card text.

### T24.4 — Update governing documents

- Owner: Coordinator (Opus)

**Do:** OPERATIONS-MANUAL: accepted formats, datums, where to find data, how to verify, how to remove. PROVIDER-MANUAL §14.7: operator file as highest priority in resolver chain.

**Accept:** Manuals match implementation.

### QC Gate 24

- `clearskies-auditor` verifies:
  - Accepts GeoTIFF/NetCDF/ASCII XYZ. Rejects unsupported.
  - Datum transform correct (test NAVD88 and MLLW).
  - Coverage validation correct per level.
  - Operator file takes priority. Removing reverts.
  - Admin UI end-to-end.
  - **i18n:** All 13 API locale files contain `marine.bathymetry.upload.*` keys. All 13 stack translation files contain `admin.marine.bathymetry.upload.*` and `admin.marine.bathymetry.datum.*` keys. Datum dropdown labels, button text, validation messages, help text — all from translation keys. `grep -rn "GeoTIFF\|NetCDF\|ASCII XYZ" repos/weewx-clearskies-stack/templates/` returns zero hits (format names come from translation keys, not hardcoded in templates).
  - Manuals match.
  - All test baselines hold.

---

## Phase 25: Final Adversarial Audit

Full-scope audit after all phases complete. This exists because Phase 18 (session 3) signed off on acceptance criteria that were not actually verified, and three critical bugs shipped to production as a result. This phase prevents that from happening again.

### T25.1 — QC gate verification audit

- Owner: `clearskies-auditor` (independent — NOT the agent that implemented any phase)

**Do:** For EVERY QC gate in Phases 19-24, verify that each checklist item was actually satisfied — not just checked off. Specifically:

1. **Re-run acceptance tests**, not trust the implementing agent's report. For each Accept criterion that references a testable output (API response, log line, file on disk, UI rendering), run the test independently and record the result.
2. **Check for silent deferrals.** Search the codebase for:
   - `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER` — any of these added during Phases 19-24 are silent deferrals that should have been reported.
   - Functions that return hardcoded values or empty dicts where real computation was specified.
   - `pass` statements in functions that should have implementations.
   - `NotImplementedError` raises that weren't in the plan.
3. **Check for stale code paths.** After Phases 19-24, the old `download_swan_depth_grid()` (CRM-only) path should only be reachable as a fallback, never as the primary path for locations with regional DEM coverage. Verify the resolver chain is actually consulted.
4. **Log evidence, not assertions.** Every finding includes the command run and the output observed. "Tests pass" is not evidence. The pytest output, the API response body, the file listing — those are evidence.

**Accept:** Audit report with pass/fail per QC gate item, evidence for each, and a list of any silent deferrals found.

### T25.2 — Doc-code consistency audit

- Owner: `clearskies-auditor`

**Do:**
1. For each governing document updated in Phase 17 and the per-phase T*.x doc tasks:
   - Read the document section.
   - Read the corresponding code.
   - Flag any claim in the doc that does not match the code.
2. Specific checks:
   - PROVIDER-MANUAL §14.15 describes the resolver priority chain — verify the code implements the same order.
   - PROVIDER-MANUAL §14.7 documents the VDatum REST API — verify the code actually calls it (not a constant offset).
   - ARCHITECTURE.md SWAN section — verify every component mentioned exists in the codebase.
   - OPERATIONS-MANUAL — verify every operator-facing config key and cache path mentioned actually exists.
3. Check the SWAN-FIXES-PLAN execution order — does it match what actually happened?
4. **i18n sweep:** For every user-visible string added or modified in Phases 19-24:
   - API responses: verify the string comes from a locale key in `locales/*.json`, not hardcoded in Python.
   - Stack templates (wizard/admin): verify the string comes from a translation key in the 13 locale files, not hardcoded in HTML/Jinja.
   - Dashboard components: verify labels, tooltips, and status text come from the API's `units` block or i18n keys, not hardcoded in TSX.
   - Run: `grep -rn "hardcoded-pattern" repos/` for any quality labels, datum names, format names, or warning text that appears as a literal string outside of locale/translation files and this plan.

**Accept:** Zero doc-code mismatches, or all mismatches reported with specific file:line references. Zero i18n violations (all user-facing strings from locale keys).

### T25.3 — Production regression gate

- Owner: Coordinator (Opus)

**Do:** After all phases deployed, run the full Phase 23c regression gate on production:
1. SWAN exits 0
2. TABLE output has Hs > 0 at scoring depth (not -9, not 0)
3. QB > 0 at at least one transect point
4. Surf forecast card shows non-zero swell matching buoy within 50%
5. Beach profile card shows depth decreasing toward shore

Additionally:
6. Bathymetry source is `ncei_regional` for Level 2/3 at HB Pier (not CRM)
7. Depth profile has >10 unique values (no staircase)
8. VDatum datum offset is logged
9. Quick update fires and produces non-zero output

**This is a HARD GATE. If any item fails, the responsible phase is reopened.**

**Accept:** All 9 items pass with log/screenshot evidence.

### T25.4 — Lessons capture

- Owner: Coordinator (Opus)

**Do:** After the audit, triage lessons into the correct files per CLAUDE.md "Capture lessons in the right place":
- Rule-shaped lessons → `rules/clearskies-process.md` or agent definitions
- Fact-shaped lessons → `reference/` files
- Decision-shaped lessons → this plan's decision log section

Specific lessons from this session to capture:
- "CUDEM 1/9" coverage claims must be verified per-location before coding against them"
- "SWAN nesting files must use different names for BOUNDNEST1 read and NESTOUT write"
- "Vertical datum offsets are spatially varying — constant regional offsets are wrong"
- "Phase audit gates must include production verification with evidence, not sign-off"
- "Grid sizing must come from actual data (depth profiles), not illustrative estimates in briefs"

**Accept:** Each lesson is routed to the correct file. No lessons left only in this plan's narrative.

### QC Gate 25

This is the final gate. All of the following must be true:

- Every QC gate item from Phases 19-24 independently verified with evidence.
- Zero silent deferrals (or all deferrals explicitly documented and scheduled).
- Zero doc-code mismatches (or all reported and fixed).
- Production regression gate passes with evidence.
- Lessons captured in the correct rule/reference files.
- All test baselines hold.

**Sign-off:** The coordinator presents the T25.1 audit report to the user. The user decides whether the plan is complete.

---

## Critical Bug Fixes (2026-07-19, session 4)

Post-deployment audit found two bugs that zeroed the entire surf forecast:

### Bug 1: Level 2 nesting file collision (FIXED)

**Root cause:** Level 2 used the same filename (`nest_boundary.dat`) for both
`BOUNDNEST1` (reading Level 1's boundary data) and `NESTOUT` (writing Level 2's
output for Level 3). SWAN reads boundary data progressively during the multi-hour
simulation; NESTOUT simultaneously overwrites that file. Result: Level 1's 83 MB
boundary file became a 3.5 MB corrupted file. Level 3 read garbage and produced
0.005 m wave heights (effectively zero).

**Fix:** Separated the filenames. `NESTOUT` writes to `nest_out.dat`;
`BOUNDNEST1` reads from `nest_in.dat`. The runner copies
`parent_dir/nest_out.dat` → `child_dir/nest_in.dat` between levels. The two
files never share a name within a single SWAN working directory.

**Files:** `swan_runner.py` (copy steps + constants), `swan_formats.py` (docstring
+ default parameter), `swan-commands-extract.md` (added NGRID/NESTOUT/BOUNDNEST1
documentation with the file collision warning).

### Bug 2: Quick update pointed at old 2-level paths (FIXED)

**Root cause:** `run_quick_update()` in `swan.py` checked for
`outer/nest_boundary.dat` — the old 2-level path. The 3-level system uses
`level1/`, `level2/`, `level3_*/` directories. The quick update either found a
stale pre-Phase-14 file or nothing at all.

**Fix:** Rewrote `run_quick_update()` to use the 3-level domain system:
compute domains via `compute_domains()`, load cached per-cluster Level 3
bathymetry, run stationary Level 3 per cluster using Level 2's NESTOUT output.
Added `run_stationary_level3()` method to `SWANRunner`.

**Files:** `swan.py` (rewritten `run_quick_update()`), `swan_runner.py` (new
`run_stationary_level3()` method).

### Bug 3: Level 3 grid hardcoded to 1 km offshore (FIXED)

**Root cause:** `_compute_level3_grid()` in `swan_domain.py` hardcoded
`offshore_km = 1.0`. The research brief (§5, Level 3) specifies "shore to 15m
depth" — not a fixed distance. At HB Pier, the 15m depth contour is 2,350m from
shore. Result: the Level 3 grid was only 1.1 km wide, but the transect (which
correctly used the profile data to reach 15m depth) extended 2.4 km. 42% of
transect CURVE points fell outside the computational grid and returned SWAN's
-9 exception value.

**Fix:** `compute_domains()` now accepts `offshore_distance_m` per spot (the
distance to the 15m depth contour from the cached bidirectional profile).
`_compute_level3_grid()` uses this distance + 100m margin to size the grid.
Both `run_all_spots()` and `run_quick_update()` extract the 15m-depth distance
from the profile before calling `compute_domains()`. Fallback: 2.5 km when no
profile data is available.

**Impact on compute:** For HB Pier, Level 3 grows from ~13,000 to ~47,000 cells
(~4 min → ~15 min at 16 cores). This is within the research brief's 15-min
budget. The old 4-min grid was producing 42% garbage data.

**Files:** `swan_domain.py` (`_compute_level3_grid` + `compute_domains`),
`swan.py` (`run_all_spots` + `run_quick_update` extract profile distance).

### Phase 18 audit note

Phase 18's "production verification — 3-level SWAN run produces valid output at
HB Pier" cannot have actually passed — the output has been zeros since the
3-level redesign landed. The audit's acceptance criteria were signed off without
being verified against production SWAN output.

---

## Execution Order

```
Phases 1-8          ← COMPLETE (sessions 1-2)
Phases 9, 12        ← COMPLETE (session 3)
Phases 13-16        ← COMPLETE (session 3) — code landed, domain sizing bug fixed
Bug 1-3 (Nesting)   ← FIXED (session 4) — nesting file collision + quick update + grid sizing

Phase 17 (Docs)      ← HARD PREREQUISITE — not yet started
Phase 18 (Audit)     ← REDO — deploy Bug 1-3 fixes + verify production output

Phase 19 (DEM Index)      ← COMPLETE (session 5) — 199 DEMs indexed, resolver built
Phase 20 (OPeNDAP)        ← COMPLETE (session 5) — fetch + VDatum + wiring + bidirectional profile
Phase 21 (Great Lakes)    ← COMPLETE (session 5) — Great Lakes functions + wiring
Phase 22 (Coverage UI)    ← API COMPLETE (session 5) — admin UI (T22.2) deferred to stack repo
Phase 23 (Cross-section)  ← CODE COMPLETE (session 5) — T23.4 regression needs deploy
Phase 24 (Operator bathy) ← IN PROGRESS (session 5) — resolver wired, upload endpoint in progress
Phase 25 (Final audit)    ← AFTER all phases — adversarial verification of every QC gate
```

**Sequence constraints:**

1. **Phase 17 blocks everything.** Agents read manuals before coding. Stale manuals caused Bug 1-3.
2. **Phase 18 blocks Phases 19+.** The Bug 1-3 fixes must be deployed and verified on production before building the bathymetry resolver on top of them.
3. **Phase 19 blocks Phase 20.** The DEM index must exist before the OPeNDAP fetcher can look up which file to query.
4. **Phase 20 is the critical path.** Everything else (21, 22, 23, 24) improves the system but is not required for basic operation. Phase 20 replaces garbage CRM data with real ~10m bathymetry.
5. **Phase 21 can parallelize with 20.** Different data source, different geography — no shared code.
6. **Phase 23 should follow Phase 20.** Cross-section fix needs real bathymetry to test against. Testing against CRM staircases would produce misleading results.
7. **Phase 24 is independent.** Operator upload slots into the resolver chain above all automated sources. Can be done any time. Also the immediate workaround for operators in areas with poor automated coverage.
8. **Phase 25 is last.** Adversarial audit of the entire implementation. User sign-off.
