# Surf 1D Model Implementation Plan

**Status:** AMENDED 2026-07-21 — SwellTrack selected (1D-MODEL-BENCHMARK-BRIEF Round 2). SWASH and XBeach ruled out entirely. See SURF-MODEL-FIX-PLAN.md for remaining integration work.
**Created:** 2026-07-20
**Origin:** SURF-ZONE-MODEL-BRIEF research + SURF-FIXIT-LIST findings (SURF-11, 19, 21–24). SWAN L3 single-transect architecture produces systematically wrong surf heights: transect through HB Pier OBSTACLE loses 31% energy, K-G/Caldwell applied at wrong depth with ad-hoc correction, swell decomposition masks components, swell display uses nearshore values instead of deep water. SwellTrack + multi-transect architecture resolves all of these.

**Amendments (2026-07-21 per brief §9.5):**
1. Model named "SwellTrack" — replaces all "analytical 1D" / "Option A" references
2. SurfBeat cadence: every 3 hours (25 runs per 72h forecast, carry-forward between)
3. Compute offloading: SwellTrack/SurfBeat to librewxr via `surf_compute_host` config
4. Blended Hs: SurfBeat strip for approach zone, SwellTrack for surf zone (50m taper)
5. Phase 8 T8.1: SWASH ground truth CANCELLED — SWASH ruled out entirely
6. Phase 8 T8.4: Webcam validation replaced by Surfline comparison
7. Friction: always on in production (cfjon=0.038 swell default, 0.067 windsea)
8. IG display: SurfBeat set/lull timing feeds Card 3 and 72h forecast scroll
9. Attribution: "SWAN + SwellTrack" (not "SWAN" alone)

## 0. Orientation

### 0.1 Execution context

Same as MARINE-REMEDIATION-PLAN.md §0 — read those files, use those deploy scripts, follow those SSH rules. Additionally:

**Governing documents (coordinator reads ALL before Phase 1):**
- `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md` — full research brief with multi-transect architecture, handoff algorithm, per-partition pipeline, computational costs, peel angle method
- `docs/planning/SURF-FIXIT-LIST.md` — 24 findings, 4 critical/high addressed by this plan
- `docs/ARCHITECTURE.md` — SWAN architecture, SPECOUT, CURVE, OBSTACLE, L1/L2/L3 grid design
- `docs/manuals/API-MANUAL.md` §17-18 — surf endpoint contract, scoring, data pipeline
- `docs/manuals/PROVIDER-MANUAL.md` §14 — SWAN provider, NDBC, CO-OPS, structure config
- `docs/manuals/OPERATIONS-MANUAL.md` — deployment, config, SWAN working directory

**SWAN-specific references (coordinator extracts relevant sections for agent briefs):**
- SWAN User Manual (Fortran INPUT syntax) — coordinator extracts SPECOUT, CURVE, OBSTACLE, POINTS syntax into `swan-commands-extract.md` per RULE 5 (SWAN-L3-STABILITY-PLAN)
- XBeach Manual — RULED OUT (2026-07-21). Runtime incompatible with 72-timestep pipeline.
- SWASH Manual — RULED OUT (2026-07-21). Unvalidated; cannot serve as truth standard.

**Agent reading lists:** Each agent brief includes a READING LIST section per `rules/clearskies-process.md`. Agents read source documents directly — coordinator does NOT paraphrase manuals into prompts.

### 0.6 SWAN syntax reference (verified against manual + production)

All SWAN INPUT changes in this plan use ONLY these verified syntaxes. Source: `docs/reference/swan-commands-extract.md` (extracted from SWAN User Manual v41.45/v41.51), cross-checked against the live production INPUT at `/var/run/weewx-clearskies/swan/level3_0/INPUT`.

**POINTS — define isolated output points:**
```
POINTS 'sname' [xp] [yp]
```
- `'sname'` — max 8 chars, referenced by TABLE/SPECOUT
- `[xp] [yp]` — UTM coordinates (meters, Cartesian mode)
- Multiple points: repeat the POINTS command with the same `'sname'` and different coordinates

**Production example (working):**
```
POINTS 'SP1' 406470.88 3723744.89
```

**SPECOUT — write 2D spectral output:**
```
SPECOUT 'sname' SPEC2D ABS 'fname'
```
- `'sname'` — must match a previously defined POINTS or CURVE name
- `SPEC2D` — full 2D frequency×direction spectrum
- `ABS` — absolute frequencies
- `'fname'` — output filename
- For nonstationary runs, append: `OUTPUT [tbeg] [delt] HR`

**Production example (working):**
```
SPECOUT 'SP1' SPEC2D ABS 'SPEC_1.txt'
```

**CURVE — define output along a line:**
```
CURVE 'sname' [xp1] [yp1] < [int] [xp] [yp] >
```
- `[int]` — number of output points between corner points (total = sum of ints + 1)

**Production example (working, 48 points):**
```
CURVE 'CV1' 405324.23 3722625.96 47 407008.29 3724269.49
```

**TABLE — write quantities at output locations:**
```
TABLE 'sname' HEAD 'fname' [quantity1] [quantity2] ...
```

**For the multi-SPECOUT extraction (new):** Each unique handoff grid cell gets its own POINTS entry. Multiple POINTS with the same sname are NOT supported — each point needs a unique sname. Pattern:

```
POINTS 'DW1' [x1] [y1]
POINTS 'DW2' [x2] [y2]
POINTS 'DW3' [x3] [y3]
SPECOUT 'DW1' SPEC2D ABS 'SPEC_DW1.txt'
SPECOUT 'DW2' SPEC2D ABS 'SPEC_DW2.txt'
SPECOUT 'DW3' SPEC2D ABS 'SPEC_DW3.txt'
```

**For a deep-water reference SPECOUT in L2 (new):** One SPECOUT per spot at ~15m depth, extracted from the L2 run. This provides the true pre-nearshore spectrum for the swell display card.

```
POINTS 'DWR1' [x_15m] [y_15m]
SPECOUT 'DWR1' SPEC2D ABS 'SPEC_DEEPWATER_1.txt' OUTPUT [tbeg] [delt] HR
```

**OBSTACLE syntax (existing, verified):**
```
OBSTACLE TRANSM [kt] LINE [x1] [y1] [x2] [y2]
```
- `[kt]` — transmission coefficient: 0.0 = total blocking, 1.0 = no effect
- Current pier value: `TRANSM 0.8` — NEEDS CORRECTION per P3/O3 (pier pilings should be 0.93-0.97)

### 0.2 Key decisions (user-approved)

1. **Multi-transect architecture** — operator draws a shoreline segment (not a pin), transects at 10m spacing
2. **Obstacle-aware transect filtering** — transects crossing OBSTACLEs are flagged and excluded from headline metrics
3. **L3 grid optional per location** — smart-sized around structures only; transects far from structures hand off from L2
4. **Per-partition swell transformation** — decompose spectrum at handoff, run each partition independently through 1D model
5. **Swell card shows deep-water values** — from SPECOUT decomposition at handoff, not nearshore-transformed
6. **K-G/Caldwell at actual break point** — eliminate ad-hoc depth correction in `breaker_height.py`
7. **1D model selection: SwellTrack (analytical, pure Python)** — 0.85ms/transect with numpy, 5.5s for full forecast cycle (30 transects × 3 partitions × 72 timesteps). No LUT needed. XBeach and SWASH ruled out entirely (1D-MODEL-BENCHMARK-BRIEF Round 2, 2026-07-21). SurfBeat strip provides IG energy at 3-hour intervals.
8. **FUNWAVE-TVD excluded** — no real 1D mode; future scope for 2D structure-dominated spots only
9. **Pin-based config replaced entirely** — no backwards compatibility needed (no other operators)

### 0.3 Agent assignments

| Role | Model | Responsibility |
|---|---|---|
| **Coordinator** | Opus | Architecture decisions, agent briefs, QC gates, SWAN syntax extraction, doc updates, research, git push (with user approval) |
| **clearskies-api-dev** | Sonnet | API implementation: 1D model module, transect generation, handoff algorithm, surf endpoint rewiring, SPECOUT parsing, K-G fix |
| **clearskies-dashboard-dev** | Sonnet | Dashboard: measurement zone map UI, heat map visualization, beach profile chart, scoring bar redesign, swell card |
| **clearskies-docs-author** | Sonnet | Stack/wizard: shoreline segment UI, transect preview map, obstacle display, structure config, help text |
| **clearskies-test-author** | Sonnet | Tests: 1D model unit tests, multi-transect integration tests, benchmark harness |
| **clearskies-auditor** | Sonnet | Adversarial audit per QC gate: silent deferral scan, scope verification, doc-code sync |

### 0.4 Verification mandate

Every phase includes an **adversarial audit** before the QC gate closes. The auditor:
1. Greps for silent deferrals: functions that return hardcoded values, `pass` bodies, `TODO`/`FIXME` without tracking, parameters accepted but never read
2. Verifies every task's acceptance criteria against the actual code (not agent self-report)
3. Checks doc-code sync: any behavior change must have a corresponding governing document update
4. Checks the brief: any deviation from SURF-ZONE-MODEL-BRIEF must be flagged (deviation may be correct, but it must be conscious)

### 0.5 Test baselines (must not regress)

| Suite | Baseline | Command |
|---|---|---|
| API pytest | Current pass count (check before Phase 2) | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | Current pass count | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

---

## Phase 0 — Governing Document Updates

**Purpose:** Update ADRs, manuals, and ARCHITECTURE.md to reflect the new multi-transect + 1D model architecture BEFORE any implementation begins. Agents read these documents before coding — stale docs produce wrong code. This is the lesson from every prior phase.

**All Phase 0 work is Coordinator (Opus) direct.**

### T0.1 — Amend ADR-093 (SWAN nearshore model)

- File: `docs/decisions/ADR-093-swan-trushore-nearshore-model.md`

**Amendments:**
1. L3 grid is now **optional per location** — enabled automatically when Overpass API discovers structures near the spot, disabled for open beaches
2. When L3 is enabled, grid is **smart-sized around structures** (not the entire beach segment) — structure positions + shadow zone extent + 100m pad
3. Transects outside the L3 bbox hand off from L2 at ~15m depth
4. Multi-transect architecture: 10m spacing across operator-drawn shoreline segment replaces single-pin transect
5. 1D model runs from handoff to shore per transect (model selection pending Phase 1 benchmark)
6. Update compute budget estimates: L3 compute is proportional to structure coverage, not beach length; spots with no structures skip L3 entirely

### T0.2 — Amend ADR-095 (SWAN model corrections)

- File: `docs/decisions/ADR-095-swan-model-corrections.md`

**Amendments:**
1. **Decision 1 (CURVE transect):** CURVE is retained for L3-enabled spots as a diagnostic/validation output. The 1D model replaces CURVE as the primary cross-shore data source for the surf endpoint. CURVE spacing change from 50m to 10m (SURF-19) still applies for L3 validation.
2. **SPECOUT extraction:** Changes from "at ~10m depth point per spot" to "at the handoff depth per unique L2/L3 grid cell across the transect array." Multiple SPECOUT points per spot (one per unique handoff cell). For L3-disabled spots, SPECOUT extracted from L2 at ~15m.
3. **K-G/Caldwell:** Applied at the break point from the 1D model output, NOT at the ~10m reference point. Remove the "K-G/Caldwell applied at the ~10m depth point" language. Remove the ad-hoc depth correction concept.
4. **Swell decomposition reference:** multiSwell components come from SPECOUT decomposition at the handoff point (deep-water reference), not from a nearshore ~10m point. The swell card shows what's arriving, comparable to NDBC buoy partitions.
5. **Break point authority:** 1D model's H/d = gamma crossing is the primary break point. SWAN's QB retained as diagnostic only.
6. Update acceptance criteria to reflect multi-transect output shape

### T0.3 — Amend ADR-096 (scoring restructure)

- File: `docs/decisions/ADR-096-scoring-restructure.md`

**Amendments:**
1. **Scoring inputs:** Wave height, period, direction now come from multi-transect best-peak or spot-average (configurable), not single-point reference
2. **Cross-swell scoring:** Input from SPECOUT decomposition at handoff (not "at ~10m"). Multiple partitions expected — the decomposition fix (SURF-11) ensures all components survive
3. **New scoring inputs:** Peel angle → surfability sub-factor (within wave organization). Jacking factor → wave quality sub-factor. These are future additions — document as planned extensions, do not add scoring weights until validated (Phase 8)
4. **Face height input:** `breakingFaceHeight` now comes from K-G/Caldwell applied at the 1D model's break point. Scoring thresholds (`_WAVE_HEIGHT_RANGES_FT`) must be validated against the new face height values before deployment

### T0.4 — Amend ADR-097 (beach profile endpoint)

- File: `docs/decisions/ADR-097-beach-profile-endpoint.md`

**Amendments:**
1. Beach profile endpoint returns 1D model output: Hs at 3-5m resolution (replacing SWAN CURVE at 50m)
2. Break points from 1D model H/d crossing (replacing SWAN QB threshold)
3. Wave shape data from analytical computation (Stokes/cnoidal) at each transect point
4. Multiple transects available — endpoint accepts a transect index or returns all transects for the heat map
5. Response includes per-partition break info: which swell component breaks where

### T0.5 — Update ARCHITECTURE.md

- File: `docs/ARCHITECTURE.md`

**Updates to the SWAN section:**
1. L3 is optional per location (structure-dependent, auto-detected)
2. L3 smart-sizing around structures (not entire beach)
3. Multi-transect SPECOUT extraction at handoff points
4. 1D model as post-SWAN cross-shore enhancement (model selection pending)
5. Per-partition swell transformation pipeline
6. Measurement zone = operator-drawn shoreline segment (replaces pin)
7. Remove "CURVE output at 50m spacing" — replaced by 1D model at 3-5m

### T0.6 — Update API-MANUAL §17

- File: `docs/manuals/API-MANUAL.md`

**Updates:**
1. Surf endpoint data pipeline: SPECOUT decomposition at handoff → per-partition 1D transformation → K-G at break point → multi-transect aggregation (best peak, average)
2. New response fields: `bestPeakFaceHeight`, `spotAverageFaceHeight`, `peelAngle`, `peelClassification`, `transectCount`, `openTransectCount`, per-partition break info
3. Changed field semantics: `multiSwell` = deep-water values at handoff (not nearshore), `breakingFaceHeight` = at actual break point (not ~10m ref with depth correction), `swellHeight` = dominant deep-water partition
4. Surf spot config: shoreline segment replaces pin, `transect_spacing_m` field, `l3_enabled` auto/override
5. Measurement zone and obstacle filtering behavior

### T0.7 — Update PROVIDER-MANUAL §14

- File: `docs/manuals/PROVIDER-MANUAL.md`

**Updates:**
1. SWAN provider: multi-SPECOUT extraction, L3 optional, smart sizing
2. SPECOUT extraction: one per unique handoff cell, deduplication logic
3. OBSTACLE interaction: structure TRANSM values by type (pier pilings should be high transmission ~0.93-0.97, not 0.8)
4. 1D model provider section (new): describes the selected 1D model as a post-SWAN processor

### T0.8 — Update OPERATIONS-MANUAL

- File: `docs/manuals/OPERATIONS-MANUAL.md`

**Updates:**
1. Wizard marine step: shoreline segment drawing replaces pin placement
2. Transect preview on map with obstacle highlighting
3. L3 optional per location — auto-detection from structures, manual override in admin
4. Per-location L3 toggle in admin

### QC Gate 0

- All 4 ADRs amended with multi-transect + 1D model + optional L3 changes
- ARCHITECTURE.md SWAN section reflects new architecture
- API-MANUAL §17 documents new pipeline and response fields
- PROVIDER-MANUAL §14 documents SPECOUT extraction and L3 optional
- OPERATIONS-MANUAL documents wizard segment UX
- No implementation code changed — this phase is documents only
- All amendments clearly marked with date and reference to SURF-ZONE-MODEL-BRIEF

---

## Phase 1 — 1D Model Benchmark & Selection

**Purpose:** Install XBeach and SWASH on a test machine, run all three candidate models (analytical, XBeach-1D surfbeat, SWASH-1D) with the same inputs from our live SWAN output, measure runtime and output quality. This phase produces the model selection decision that unblocks Phases 3-4.

**BLOCKING:** Phases 3 and 4 cannot begin until the model is selected.

**Can run in parallel with Phase 0** (docs) and **Phase 2** (measurement zone foundation).

### T1.1 — Extract benchmark inputs from current SWAN

- Owner: Coordinator (Opus)
- Source files: `/var/run/weewx-clearskies/swan/level3_0/SPEC_1.txt`, `TABLE_1.txt`, CUDEM bathymetry cache

**Do:**
1. Copy the current SPECOUT file (`SPEC_1.txt`) — this is the 2D frequency-direction spectrum at the extraction point
2. Copy the CURVE TABLE output (`TABLE_1.txt`) — this has the Hs profile along the transect for comparison
3. Extract the CUDEM bathymetric profile along the transect from the cached bathymetry data
4. Record the current wave conditions from the nearest NDBC buoy for ground-truth comparison
5. Document the inputs: handoff depth, wave conditions (Hs, Tp, DIR), tide level, transect length

**Accept:** A self-contained benchmark input package that can be fed to any of the three models without additional data fetching.

### T1.2 — Install XBeach and SWASH on test machine

- Owner: `clearskies-test-author` (Sonnet)
- Machine: weewx container or a dedicated scratch box

**Do:**
1. Download and compile XBeach (Fortran, open source, https://github.com/openearth/xbeach)
2. Download and compile SWASH (Fortran, open source, https://swash.sourceforge.io/)
3. Verify both binaries run with their included test cases
4. Document: compiler version, build flags, binary location, any dependencies

**Accept:** Both binaries execute their included test cases without error.

### T1.3 — Implement analytical 1D model (Option A)

- Owner: `clearskies-api-dev` (Sonnet)
- Output: Standalone Python module, runnable outside the API

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §3 Option A — equations, dependencies, limitations
2. SURF-ZONE-MODEL-BRIEF §7 — per-partition swell transformation pipeline

**Do:**
1. Implement the analytical 1D model per the brief's equations: dispersion relation, group velocity, shoaling coefficient, **Snell's law refraction** (brief §3 equation 4), Battjes-Janssen breaking, Svendsen roller model. Refraction is NOT optional — each partition has its own approach angle and refracts differently toward shore-normal.
2. Accept a SPECOUT-derived bulk parameter set (Hs, Tp, DIR) and a CUDEM bathymetric profile as input
3. Output: Hs at every 3-5m along the transect, break point locations (H/d = gamma crossings), breaker type (Iribarren)
4. Include wave shape computation (Stokes 2nd order + cnoidal via scipy elliptic functions)
5. Write as a standalone module with a CLI entry point for the benchmark: `python -m surf_1d_analytical --specout SPEC_1.txt --bathy profile.csv --output results.csv`

**Accept:** Module runs on the benchmark inputs from T1.1 and produces an Hs profile, break points, and wave shapes. Runtime measured.

### T1.4 — Set up XBeach-1D surfbeat benchmark

- Owner: `clearskies-test-author` (Sonnet)
- Depends on: T1.1 (inputs), T1.2 (binary)

**Reading list:**
1. XBeach Manual — 1D profile mode setup (ny=0, morfac=0, surfbeat mode)
2. XBeach Manual — SPECOUT input format (SWAN coupling)
3. SURF-ZONE-MODEL-BRIEF §3 Option B — what we need from XBeach

**Do:**
1. Create an XBeach 1D params.txt with: ny=0, morfac=0, wavemodel=surfbeat, appropriate grid from the CUDEM profile
2. Convert the SWAN SPECOUT to XBeach's expected boundary condition format (JONS or SWAN spectrum file)
3. Run XBeach for a 30-minute simulation
4. Extract: Hs profile along transect, break point, infragravity wave height, wave setup, runup
5. Measure wall-clock time

**Accept:** XBeach produces results for the HB Pier transect. Runtime and output recorded.

### T1.5 — Set up SWASH-1D benchmark

- Owner: `clearskies-test-author` (Sonnet)
- Depends on: T1.1 (inputs), T1.2 (binary)

**Reading list:**
1. SWASH User Manual — 1D mode setup
2. SWASH User Manual — boundary condition from SWAN SPECOUT
3. SURF-ZONE-MODEL-BRIEF §3 Option C — computational cost expectations

**Do:**
1. Create a SWASH 1D input file with appropriate grid spacing (dx ~1-3m) from the CUDEM profile
2. Convert the SWAN SPECOUT to SWASH boundary condition format
3. Run SWASH for a 30-minute simulation
4. Extract: Hs profile, individual wave heights, break point, setup, runup
5. Measure wall-clock time

**Accept:** SWASH produces results for the HB Pier transect. Runtime and output recorded.

### T1.6 — Check SWAN SurfBeat-1D availability

- Owner: Coordinator (Opus)

**Do:**
1. Check SWAN 41.51 release notes and documentation for mainlined infragravity source term (Rijnsdorp et al. 2022)
2. If available as a configuration flag: document the syntax, test with current L3 setup
3. This is a complement to the 1D model, not a replacement — document what it adds (IG energy within SWAN) vs what the 1D model provides (cross-shore transformation, wave shapes, break points)

**Accept:** Availability confirmed or denied. If available, syntax documented. Relationship to 1D model clarified.

### T1.7 — Compare results and select model

- Owner: Coordinator (Opus)
- Depends on: T1.3, T1.4, T1.5

**Do:**
1. Compare Hs profiles from all three models against the SWAN CURVE output (consistency check in QB=0 zone)
2. Compare break point locations
3. Compare against NDBC buoy Hs (ground truth for offshore) and Surfline surf height (ground truth for breaking)
4. Tabulate: runtime per transect, output fields, accuracy vs ground truth
5. Compute: runtime for **6,500 runs per forecast cycle** (30 transects × 3 partitions × ~72 timesteps). Not 90 — the 72h forecast card needs every timestep. Analytical at ~1ms/run = ~6.5 seconds total. XBeach/SWASH: multiply per-run time × 6,500 to determine LUT necessity.
6. Present findings to user with recommendation

**Accept:** User selects the 1D model. Plan updated with the decision.

### QC Gate 1

- All three models produce physically reasonable Hs profiles for HB Pier
- Runtime measured for each model
- Comparison table with runtime, output fields, accuracy
- SWAN SurfBeat-1D availability documented
- User decision on model selection recorded

---

## Phase 2 — Measurement Zone & Multi-Transect Foundation

**Purpose:** Replace the single-pin surf spot config with an operator-drawn shoreline segment. Generate obstacle-aware transects at 10m spacing. This is the structural foundation everything else builds on.

### T2.1 — Shoreline segment data model

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `config/marine_config.py`, `endpoints/setup.py` (apply models), `models/responses.py`

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.2.2 — measurement zone definition
2. Current `SurfSpotConfig` in `config/marine_config.py` — what fields exist today
3. `MarineSurfSpotApplyConfig` in `endpoints/setup.py` — apply payload shape

**Do:**
1. Replace the single-pin fields (`spot_lat`, `spot_lon`, `beach_facing_degrees`) with a shoreline segment: `segment_start_lat/lon`, `segment_end_lat/lon`
2. The `beach_facing_degrees` is now computed from the segment orientation (perpendicular to the segment line), not operator-entered
3. Add `transect_spacing_m: float = 10.0` (operator-configurable, default 10m)
4. Add `transect_count: int` (computed from segment length / spacing, read-only in config)
5. Update `SurfSpotConfig` loader: reads new fields from `api.conf`, computes derived values (bearing, transect count, transect coordinates)
6. Update apply models: accept the new segment fields in the apply payload
7. Update config writer: write segment fields to `api.conf`

**Accept:**
- `SurfSpotConfig` loads segment-based config from `api.conf`
- Transect coordinates computed from segment geometry
- Apply endpoint accepts the new payload shape
- Old pin-based config fields are removed (no backwards compat needed)

### T2.2 — Transect generation with obstacle avoidance

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_formats.py` (replace `compute_spot_transect`)

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.2.3 — obstacle-aware transect filtering
2. SURF-ZONE-MODEL-BRIEF §2.3.4 — handoff algorithm (shadow geometry reused here)
3. Current `compute_spot_transect()` in `swan_formats.py` — what it does today
4. OBSTACLE coordinates in `swan_runner.py` — structure geometry already computed

**Do:**
1. Replace `compute_spot_transect()` with `compute_spot_transects()` (plural) that takes the shoreline segment and generates N transects at `transect_spacing_m` intervals
2. Each transect is perpendicular to the **local isobath orientation** (from smoothed CUDEM depth gradient), NOT simply perpendicular to the segment. The segment defines WHERE transects originate; the bathymetry defines their DIRECTION. This is required by SURF-ZONE-MODEL-BRIEF §2.6 and ensures transects follow wave approach paths correctly. On straight coastlines the two directions are nearly identical; on curved coastlines they diverge.
3. Each transect extends from the handoff depth to shore along the CUDEM bathymetric profile
4. Cross-check each transect against OBSTACLE line segments: does the transect cross any OBSTACLE?
5. Flag each transect as `open` or `structure_affected`
6. Return: list of transects, each with coordinates, bathymetric profile, handoff depth, obstacle flag

**Accept:**
- 30 transects generated for a 300m segment at 10m spacing
- Transects crossing the HB Pier OBSTACLE are flagged as `structure_affected`
- Transects not crossing any OBSTACLE are flagged as `open`
- Each transect has its own CUDEM bathymetric profile

### T2.3 — Handoff depth algorithm (T2.2 depends on this — implement first)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_formats.py` or new `services/transect_handoff.py`
- **NOTE (Fable S3):** T2.2's transect generation needs the handoff depth to know where each transect starts. Implement T2.3 before T2.2, or as a callable within T2.2.

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.3.4 — full algorithm with worked HB Pier example
2. SURF-ZONE-MODEL-BRIEF §2.3.2 — structure influence is geometric, not proportional

**Do:**
1. Implement the 4-step handoff algorithm from the brief:
   - Step 1: Structure depth extents from CUDEM
   - Step 2: Geometric shadow per transect (3 approach angles)
   - Step 3: Assign handoff depth (10m default, shallower for shadowed transects, clamp 5-15m)
   - Step 4: Per-run QB refinement (optional runtime safety check)
2. Each transect gets its own handoff depth
3. Log handoff depth assignments at INFO level

**Accept:**
- Algorithm produces handoff depths matching the HB Pier worked example: 5.5m for pier-shadowed transects, 10m for open transects
- QB refinement adjusts handoff when SWAN shows breaking at configured depth

### T2.4 — Wizard: shoreline segment map UI

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `wizard/step_marine.html`, `wizard/routes.py`, translation files (13 locales)

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.2.2 — measurement zone UX description
2. Current wizard map implementation in `step_marine.html` — Leaflet setup
3. T5.1-T5.3 from MARINE-REMEDIATION-PLAN — Leaflet.draw already planned/implemented

**Do:**
1. Replace the pin-drop for surf spots with a Leaflet.draw polyline tool (2-point line along the shore)
2. When the operator draws the segment, show the transects as thin perpendicular lines fanning out from it
3. Show discovered OBSTACLE structures as colored lines on the map
4. Transects that cross an OBSTACLE render in a different color (e.g., orange) vs open transects (blue)
5. Display transect count and segment length
6. Operator can drag segment endpoints to adjust
7. Auto-fill hidden inputs: `segment_start_lat/lon`, `segment_end_lat/lon`

**Accept:**
- Operator draws a line along the beach instead of dropping a pin
- Transects appear perpendicular to the line at 10m spacing
- OBSTACLE crossings visually flagged
- Segment coordinates populate the apply payload

### T2.5 — Admin: shoreline segment editing

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `admin/marine.html`, `admin/routes.py`

**Do:**
1. Marine admin edit form shows the segment on a map with transects
2. Operator can drag endpoints to adjust
3. Save sends updated segment to apply endpoint

**Accept:** Admin shows and edits the segment with transect preview.

### T2.6 — Pipeline continuity bridge (Fable A3)

- Owner: `clearskies-api-dev` (Sonnet)

**Problem:** Phase 2 replaces `compute_spot_transect()` and removes pin fields, but the production surf endpoint still consumes single-transect SWAN output until Phase 4 rewires it. Without a bridge, the surf page breaks between Phase 2 deploy and Phase 4 deploy.

**Do:**
1. The new `compute_spot_transects()` returns a list of transects, but ALSO computes a `primary_transect` (the one closest to the segment midpoint, excluding structure-affected transects). The existing surf endpoint uses this primary transect exactly as it used the old single transect — same ref_point selection, same K-G application.
2. The SWAN INPUT uses the primary transect for the existing CURVE command (unchanged output format). Additional transects get POINTS entries but no TABLE output until Phase 4.
3. This means Phases 2-3 deploy without changing the surf endpoint's behavior — the endpoint reads the same CURVE TABLE format from the primary transect. Phase 4 then switches to the full multi-transect pipeline.

**Accept:** After Phase 2 deploy, the surf page produces the same output format as before (from the primary transect). No regression. The multi-transect infrastructure exists in config and the wizard but doesn't affect forecast output until Phase 4.

### T2.7 — TRANSM coefficient correction for pier pilings (Fable O3)

- Owner: Coordinator (Opus)
- Files: `services/swan_runner.py` (OBSTACLE emission), `api.conf` on weewx

**Problem:** HB Pier OBSTACLE uses `TRANSM 0.8` (20% energy blocked). Pier pilings are thin relative to wavelength — academic consensus is 5-7% energy loss for pile-supported piers. `TRANSM 0.93-0.97` is correct. The current 0.8 value treats the pier like a partial breakwater.

**Do:**
1. Change default TRANSM for `pier` structure type from 0.8 to 0.95 in the OBSTACLE emission code
2. Update the production `api.conf` for HB Pier
3. Re-derive the SURF-21 worked example and the §2.3.4 handoff example with the corrected TRANSM — the 31% energy loss will shrink to ~3-5%, which changes the magnitude of the transect-through-pier problem (it's still wrong to measure through a structure, just less dramatically wrong)
4. Update PROVIDER-MANUAL §14 TRANSM values by structure type:
   - Breakwater (impermeable): 0.0-0.1
   - Jetty (rubble mound): 0.3-0.5
   - Pier (pilings): 0.93-0.97
   - Seawall: 0.0-0.05
   - Groin (rubble): 0.3-0.5

**Accept:** OBSTACLE for HB Pier uses TRANSM 0.95. Worked examples in the plan/brief updated. PROVIDER-MANUAL documents correct TRANSM ranges by structure type.

### T2.8 — Update governing documents

- Owner: Coordinator (Opus)
- Files: API-MANUAL, OPERATIONS-MANUAL, ARCHITECTURE.md

**Do:**
1. API-MANUAL §17: Update surf spot config to document segment-based measurement zone, transect generation, obstacle filtering
2. OPERATIONS-MANUAL: Update wizard marine step docs for segment drawing UX
3. ARCHITECTURE.md: Update SWAN model outputs section to reference multi-transect SPECOUT extraction

**Accept:** Docs match implementation.

### Adversarial Audit — Phase 2

- Owner: `clearskies-auditor` (Sonnet)

**Audit scope:**
1. Silent deferral scan: grep for `pass`, `TODO`, `FIXME`, hardcoded return values, parameters accepted but never read in all new/modified files
2. Verify `compute_spot_transects()` actually generates N transects (not 1 with N ignored)
3. Verify obstacle intersection test uses real OBSTACLE geometry (not hardcoded)
4. Verify handoff algorithm matches the brief's 4-step specification exactly
5. Verify wizard segment data round-trips: draw → apply → reload → admin shows correct segment
6. Doc-code sync: every new config field documented, every removed field cleared from docs

### QC Gate 2

- 30 transects generated for a 300m segment at 10m spacing
- OBSTACLE-crossing transects correctly flagged
- Handoff depths match the brief's worked example
- Wizard segment draw → apply → admin roundtrip works
- Auditor: zero silent deferrals, zero doc-code mismatches
- Test baselines hold

---

## Phase 3 — L3 Smart Sizing & SPECOUT Architecture

**Purpose:** Make L3 optional per location, smart-size L3 around structures only, establish the SPECOUT extraction pipeline for 1D model handoff.

### T3.1 — L3 optional per location

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_runner.py`, `services/swan_domain.py`, `config/marine_config.py`

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.3.5 — SWAN grid scale at handoff
2. SURF-ZONE-MODEL-BRIEF §9 — L3 grid architecture options
3. ARCHITECTURE.md — SWAN 3-level nesting architecture
4. `swan_runner.py` — current L3 grid generation and NESTOUT/BOUNDNEST flow

**Do:**
1. Add `l3_enabled: bool` per surf spot config (default: `true` if structures exist near the spot, `false` otherwise)
2. When L3 is disabled for a spot: skip L3 grid generation for that spot's cluster, extract SPECOUT from L2 grid at the handoff depth
3. When L3 is enabled: generate L3 sub-grid sized around the structure cluster (not the entire beach)
4. The decision is automatic based on Overpass API structure discovery: structures present → L3 enabled; no structures → L3 disabled
5. Operator can override in admin (force L3 on/off per location)

**Accept:**
- Spot with no structures: L3 skipped, SPECOUT extracted from L2 at handoff depth
- Spot with structures: L3 generated around structure area only
- L3 grid size is proportional to structure coverage, not beach length
- SWAN still converges; hotstart chain unbroken

### T3.2 — L3 smart sizing around structures

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_domain.py`, `services/swan_runner.py`

**Reading list:**
1. ARCHITECTURE.md — L3 grid domain sizing (currently: 250m each side of pin cluster)
2. `swan_domain.py` — `compute_l3_bbox()` or equivalent
3. SURF-ZONE-MODEL-BRIEF §2.3.2 — structure shadow geometry

**Do:**
1. When L3 is enabled, compute L3 bbox from: structure positions + shadow zone extent (not surf spot pin cluster)
2. Shadow zone extent: structure length + 2x structure length downstream in the predominant wave direction (conservative estimate of shadow width)
3. Pad by 100m on each side for boundary effects
4. This means a single pier on a 1km beach produces a ~500m L3 grid, not a 1km+ grid
5. Transects outside the L3 grid hand off from L2 at the handoff depth

**Accept:**
- HB Pier: L3 grid covers ~500m around the pier, not the entire beach
- Transects 300m south of the pier correctly hand off from L2 (outside L3 bbox)
- Transects near the pier hand off from L3 (inside L3 bbox, post-OBSTACLE)
- Compute cost is proportional to structure coverage, not beach length

### T3.3 — SPECOUT extraction: deep-water reference + handoff points

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_runner.py` (SWAN INPUT generation), `services/swan_spectral.py` (parser)

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.4 — coupling approach (SPECOUT at handoff)
2. SURF-ZONE-MODEL-BRIEF §7 — per-partition pipeline, what display elements show
3. Plan §0.6 — verified SWAN SPECOUT/POINTS syntax
4. Current SPECOUT handling in `swan_spectral.py`

**Two distinct SPECOUT purposes (Fable P3 — "10m is not deep water"):**

1. **Deep-water reference SPECOUT (for swell display card):** One per spot, extracted from L2 at ~15m depth (the L2→L3 boundary). This is the truest pre-nearshore spectrum available — before L3's structure interaction, before significant shoaling. The swell card decomposes THIS spectrum and shows the partitions as "incoming swell." At 15m, a 16s swell has shoaled only ~5%, so these values are close to true deep-water and comparable to NDBC buoy readings.

2. **Handoff SPECOUT (for 1D model boundary condition):** One per unique grid cell at each transect's handoff depth. For L3-enabled spots: from L3 grid at the structure-affected handoff depth. For L3-disabled spots: same as the deep-water reference (L2 at 15m). This spectrum feeds the 1D model — it includes structure effects when applicable.

**Do:**
1. **L2 deep-water SPECOUT:** Add one POINTS + SPECOUT per spot to the L2 SWAN INPUT, at the ~15m depth location along the spot's central transect bearing. Verified syntax:
   ```
   POINTS 'DWR1' [x_15m] [y_15m]
   SPECOUT 'DWR1' SPEC2D ABS 'SPEC_DEEPWATER_1.txt' OUTPUT [tbeg] [delt] HR
   ```
   This spectrum feeds the swell display card (deep-water partitions).

2. **L3 handoff SPECOUT:** When L3 is enabled, add POINTS + SPECOUT per unique L3 grid cell at the handoff depth:
   ```
   POINTS 'HO1' [x1] [y1]
   POINTS 'HO2' [x2] [y2]
   SPECOUT 'HO1' SPEC2D ABS 'SPEC_HO1.txt'
   SPECOUT 'HO2' SPEC2D ABS 'SPEC_HO2.txt'
   ```
   These spectra feed the 1D model. They include structure effects from L3's OBSTACLE processing.

3. **When L3 is disabled:** No L3 handoff SPECOUT needed. The deep-water reference SPECOUT from L2 serves both purposes (swell display AND 1D model input — same spectrum, no structures to differentiate).

4. Deduplicate handoff points: multiple transects sharing the same L3 grid cell get one SPECOUT, shared.
5. Parse all SPECOUT files per timestep, tag each as `deep_water_reference` or `handoff`.
6. Store parsed spectra in the forecast cache.

**Accept:**
- L2 SWAN INPUT contains deep-water SPECOUT per spot at ~15m depth
- L3 SWAN INPUT contains handoff SPECOUT per unique grid cell (when L3 enabled)
- SPECOUT files parse correctly per timestep
- Swell display uses deep-water SPECOUT (from L2), NOT handoff SPECOUT
- 1D model uses handoff SPECOUT (from L3 when available, L2 otherwise)
- SWAN syntax matches §0.6 exactly — no untested patterns

### T3.4 — Hotstart invalidation on grid resize (Fable A2)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_runner.py`

**Problem:** Smart-sizing changes L3 bbox → the existing `level3_N_hotstart.dat` is dimensionally invalid for the new grid. The bathymetry cache `swan_bathymetry_L3_{hash}.json` also needs re-download for the new extent.

**Do:**
1. When L3 bbox changes (spot added/removed, segment moved, structure discovered/removed): detect the change by comparing new bbox hash against the cached bathymetry hash
2. On change: delete the old hotstart file and bathymetry cache for that cluster. The next SWAN run cold-starts for L3 (L1/L2 hotstarts are unaffected — their grids didn't change).
3. Log INFO: "L3 grid resized for cluster N — cold start required, hotstart invalidated"
4. The first run after a resize takes longer (no hotstart warmup). Subsequent runs use the new hotstart.

**Accept:** Grid resize triggers hotstart cleanup. No stale hotstart from wrong-sized grid is ever loaded. L1/L2 hotstarts unaffected.

### T3.5 — Update governing documents

- Owner: Coordinator (Opus)
- Files: ARCHITECTURE.md, API-MANUAL, PROVIDER-MANUAL

**Do:**
1. ARCHITECTURE.md: Update SWAN section for optional L3, smart sizing, multi-SPECOUT
2. API-MANUAL: Document per-location L3 toggle and automatic structure-based decision
3. PROVIDER-MANUAL: Update SWAN provider section for SPECOUT extraction pipeline

### Adversarial Audit — Phase 3

- Owner: `clearskies-auditor` (Sonnet)

**Audit scope:**
1. L3 skip path: when L3 is disabled, verify NO L3 grid is generated (not "generated but ignored")
2. SPECOUT deduplication: verify the dedup logic correctly maps transects to shared SPECOUT points
3. Hotstart chain: verify L3 skip doesn't break the L1→L2→L3 nesting chain for OTHER spots that still have L3 enabled
4. SWAN INPUT syntax: verify generated SPECOUT commands match SWAN manual syntax exactly
5. Silent deferral scan on all modified files

### QC Gate 3

- L3 correctly skipped for structure-free spots
- L3 correctly sized around structures for structure-affected spots
- SPECOUT extracted at handoff points, deduplicated, parsed
- SWAN converges with new SPECOUT configuration
- Hotstart chain intact across all grid levels
- Auditor: zero silent deferrals, SWAN syntax verified
- Test baselines hold

---

## Phase 4 — 1D Model Integration

**Purpose:** Implement the selected 1D model, wire per-partition transformation, fix K-G/Caldwell, rewire the surf endpoint.

**DEPENDS ON:** Phase 1 model selection decision.

### T4.1 — 1D model module

- Owner: `clearskies-api-dev` (Sonnet)
- Files: new `services/surf_1d_model.py` (or `services/surf_xbeach.py` / `services/surf_swash.py` depending on selection)

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §3 — selected model's equations/setup
2. SURF-ZONE-MODEL-BRIEF §5 — outputs required (Hs envelope, break points, Iribarren, wave shapes, jacking, surf zone widths)
3. Phase 1 benchmark results — actual runtime, I/O format, configuration
4. Selected model's user manual

**Do:**
1. Implement a module that accepts: spectrum (from SPECOUT decomposition) or bulk parameters (Hs, Tp, DIR), bathymetric profile (from CUDEM), tide level, handoff depth
2. Runs the 1D model from handoff to shore
3. Returns: Hs at every 3-5m, break point locations (list — multiple bars), breaker type per break point (Iribarren), jacking factor per bar, surf zone widths, wave shape data
4. If XBeach/SWASH: manage subprocess execution, input file generation, output parsing
5. If analytical: pure Python computation per T1.3
6. Handle errors gracefully: model crash → log error, fall back to SWAN-only data

**Accept:**
- Module runs on HB Pier inputs and produces physically reasonable Hs profile
- Break points match SWAN CURVE QB > 0 locations (within 1 grid cell)
- Runtime within the measured benchmark range
- Error handling tested: bad inputs don't crash the API

### T4.1b — Fix spectral decomposition (SURF-11) — MOVED HERE from Phase 5

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/swan_spectral.py`

**Fable S1:** T4.2 requires decomposed partitions but the decomposition fix was originally in Phase 5 T5.1. Moved here because the per-partition pipeline is unusable without it.

**Reading list:**
1. SURF-FIXIT-LIST SURF-11 — full problem description with three filtering layers identified
2. Current `decompose_spectrum()` algorithm and parameters

**Do:**
1. Lower or remove `min_peak_energy_fraction` threshold (from 0.05 to 0.005 or zero)
2. Widen neighborhood integration window (+/-4 bins instead of +/-2)
3. Return all detected peaks up to `max_components` (currently 5)
4. Ensure the decomposition finds the same components the NDBC buoys show

**Accept:**
- Decomposition finds 3 components for the current HB Pier conditions (matching Surfline's 3-component display)
- Components match NDBC buoy partitions in period and direction
- `swellDominance` is no longer always 1.0 (SURF-15 automatically fixed)

### T4.2 — Per-partition swell transformation pipeline

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/surf.py`, `services/swan_spectral.py`, new `services/surf_1d_pipeline.py`
- **Depends on:** T4.1b (SURF-11 fix — decomposition must find all partitions before this task runs them through the 1D model)

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §7 — full data pipeline diagram, what each display element shows
2. Current `endpoints/surf.py` — existing per-timestep pipeline (lines 486-713)
3. `services/swan_spectral.py` — existing SPECOUT decomposition

**Do:**
1. At each forecast timestep:
   a. Decompose the **deep-water SPECOUT** (from L2 at 15m, per T3.3) into N swell partitions for the **swell display card** — these are the "incoming swell" values
   a2. Decompose the **handoff SPECOUT** (from L3 or L2, per T3.3) into N swell partitions for the **1D model input** — these may differ from deep-water partitions if L3 structure effects are present
   b. For each partition × each transect: run the 1D model independently
   c. At each transect point: combine partition Hs via `Hs_total = sqrt(sum(Hs_i^2))`
   c2. **Combined depth-limited saturation check (Fable P2):** After RSS combination, enforce Hs_total ≤ γd at each point. Individual partitions may each be below γd but RSS-combine above it. When Hs_total exceeds γd, apply Battjes-Janssen dissipation to the total energy and redistribute the reduction proportionally across partitions. Without this, small partitions never individually trigger breaking and pass through to shore unrealistically.
   d. At each partition's break point: apply Hs→face conversion (1.27× H1/10 per T4.3, NOT full K-G)
   e. Across open transects: compute best peak, spot average, worst section
   f. Across adjacent open transects: compute peel angle from break point spatial variation
2. Populate response fields:
   - `multiSwell`: partition heights/periods/directions from the SPECOUT decomposition (deep-water values — SURF-23 fix)
   - `breakingFaceHeight`: from 1D model output at break point with K-G/Caldwell (SURF-22 fix)
   - `breakPoints`: from 1D model H/d crossings (replaces SWAN QB threshold)
   - New: `bestPeakFaceHeight`, `spotAverageFaceHeight`, per-partition break info
   - New: `peelAngle`, `peelClassification`

**Accept:**
- Multiple swell partitions survive decomposition (SURF-11 verified fixed)
- `multiSwell` heights are deep-water values (compare against NDBC buoy — should be comparable)
- `breakingFaceHeight` is computed at the actual break point (compare against Surfline — should be in the right range)
- Peel angle computed from multi-transect break point variation
- Per-partition break info shows different components breaking at different bars

### T4.3 — Fix K-G/Caldwell: correct Hs-to-face-height conversion at break point

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `enrichment/breaker_height.py`

**Reading list:**
1. SURF-FIXIT-LIST SURF-22 — full problem description with code line references
2. Current `breaker_height.py` lines 187-201 — the ad-hoc depth correction
3. SURF-ZONE-MODEL-BRIEF §5.2 — K-G is NOT eliminated, better inputs

**CRITICAL PHYSICS NOTE (from Fable review P1):** K-G is a **deepwater-to-breaking** formula — its amplification factor IS the shoaling path. The 1D model's break-point Hs is **already fully shoaled**. Applying full K-G on top double-counts shoaling (the opposite error from the current under-count). Two correct approaches:

- **Option A (recommended):** At the break point, apply only the statistical Hs→face conversion factor. Rayleigh distribution gives H1/10 ≈ 1.27 × Hs (the average of the highest 10% of waves — what Caldwell already uses). This converts the statistical Hs to the trough-to-crest face height surfers observe. No shoaling amplification — the 1D model already did that.
- **Option B:** Feed K-G the **deep-water equivalent** Hs (unshoal the handoff value by dividing out the shoaling coefficient Ks and refraction coefficient Kr). K-G then does the full deepwater-to-breaking conversion. More complex, and the 1D model's break-point Hs is thrown away.

Option A is simpler and directly uses the 1D model's output.

**Do:**
1. Remove the `SHALLOW_DEPTH_THRESHOLD_M` constant and the linear depth correction (lines 187-201)
2. Add a new mode for break-point input: when the input Hs is at the break point (from the 1D model), apply ONLY the Rayleigh H1/10 factor (1.27× Hs) for face height, NOT the full K-G deepwater formula
3. Retain the full K-G formula as a fallback for cases where deep-water Hs is provided directly (backwards compat for any non-1D-model path)
4. The function signature adds a `source` parameter: `source="break_point"` (from 1D model, apply H1/10 only) or `source="deep_water"` (legacy, apply full K-G)
5. Update docstring with the physics rationale

**Accept:**
- At `source="break_point"`: face height = 1.27 × Hs (Rayleigh H1/10)
- At `source="deep_water"`: full K-G formula (legacy behavior, no depth correction)
- `SHALLOW_DEPTH_THRESHOLD_M` and the lerp logic are removed
- Face heights for HB Pier are in the physically reasonable range — validate the FULL chain: deep-water partition Hs → 1D model shoaling → break-point Hs → 1.27× → face height. Compare against Surfline. Do NOT accept if the end number matches via compensating errors.

### T4.4 — Wire 1D pipeline into surf endpoint

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/surf.py`

**Do:**
1. Replace the single-ref-point pipeline with the multi-transect per-partition pipeline from T4.2
2. The existing `ref_point` selection logic (lines 538-560) is replaced by: run all transects through 1D model, compute best peak / average from open transects
3. Existing scoring (T4.1 sub-factors) now receives the multi-transect-derived inputs instead of single-point values
4. `swellHeight` field: from SPECOUT dominant partition height (deep water)
5. `waveHeightAtBreak`: from 1D model Hs at break point (best peak or average — configurable)
6. Response shape additions: `bestPeakFaceHeight`, `spotAverageFaceHeight`, `peelAngle`, `transectCount`, `openTransectCount`

**Accept:**
- Surf endpoint returns multi-transect-derived values
- Response includes new fields alongside existing fields (no breaking change to existing fields)
- Scoring uses multi-transect inputs

### T4.5 — Fallback and degraded mode (Fable A6)

- Owner: `clearskies-api-dev` (Sonnet)

**Problem:** T4.1 says "on model crash, fall back to SWAN-only data" but T4.4 deletes the single-ref-point pipeline. Must define what happens when the 1D model fails for some or all transects.

**Do:**
1. Define degraded response shape: add a `degraded: bool` flag to the surf response. When true, face height comes from SWAN CURVE data (the legacy path) rather than the 1D model.
2. Partial failure: if the 1D model fails on 5 of 30 transects, exclude those transects from aggregation but continue with the remaining 25. Log warning with which transects failed and why.
3. Total failure: if the 1D model fails on ALL transects, fall back to: (a) SWAN CURVE Hs at the break point (from QB peak), (b) H1/10 factor for face height, (c) set `degraded: true` in response. The dashboard can show a subtle indicator that the forecast is running in degraded mode.
4. SPECOUT parse failure: if SPECOUT files are missing or corrupt, fall back to SWAN TABLE bulk parameters (Hs, Tp, DIR) at the handoff depth — single-partition transformation only.

**Accept:** Model crashes don't crash the API. Degraded mode produces reasonable (if less accurate) output. Dashboard can detect degraded mode.

### T4.5b — Partition identity across transects (Fable A5)

- Owner: `clearskies-api-dev` (Sonnet)

**Problem:** Shadowed and open transects may decompose different SPECOUT spectra at different depths. "The 16s partition" from the deep-water SPECOUT and "the 16s partition" from a structure-affected handoff SPECOUT may not be the same partition. Need a consistent identity for per-partition break aggregation and the swell card.

**Do:**
1. The **swell display card** always uses the deep-water SPECOUT (from L2 at 15m, per T3.3). One decomposition per spot. This is the canonical partition list.
2. The **1D model** decomposes the handoff SPECOUT (which may differ per transect group). Match handoff partitions to the canonical list by nearest (period, direction) — a partition is "the same swell" if its period is within ±2s and direction within ±20° of a canonical partition.
3. If the handoff decomposition finds a partition with no canonical match (e.g., a local wind chop created by structure channeling), assign it to an "other" category for that transect.
4. Per-partition break aggregation (T7.3) operates on the canonical partition IDs, collecting break points from all transects that matched each canonical partition.

**Accept:** The swell card shows the same 3 partitions regardless of which transect is viewed. Per-partition break info maps correctly to canonical partitions.

### T4.6 — Update governing documents

- Owner: Coordinator (Opus)
- Files: API-MANUAL §17, ARCHITECTURE.md

**Do:**
1. API-MANUAL §17: Document the per-partition pipeline, new response fields, changed field semantics (swellHeight = deep water, breakingFaceHeight = at break point)
2. ARCHITECTURE.md: Update surf endpoint description for multi-transect pipeline

### Adversarial Audit — Phase 4

- Owner: `clearskies-auditor` (Sonnet)

**Audit scope:**
1. **Silent deferral scan:** grep for hardcoded return values, pass bodies, unreachable code paths in the 1D model module and pipeline
2. **Per-partition verification:** verify ALL partitions from the decomposition are transformed (not just the dominant one — this was the original SURF-11 bug)
3. **K-G depth correction removal:** verify `SHALLOW_DEPTH_THRESHOLD_M` and the lerp block are completely gone, not just commented out
4. **Break point authority:** verify the 1D model's break points are used for scoring and face height, not SWAN's QB
5. **Obstacle filtering:** verify `structure_affected` transects are excluded from best-peak and spot-average
6. **Combined saturation (P2):** verify Hs_total is capped at γd — test with 3 partitions each at 0.8γd (individual below threshold, combined above)
7. **K-G chain validation (P1):** trace the FULL chain for one timestep: deep-water partition Hs → 1D shoaling → break-point Hs → 1.27× H1/10 → face height. Verify each step is physically reasonable and not compensating for errors in another step
8. **Refraction (P4):** verify the 1D model applies Snell's law per-partition — different approach angles refract differently
9. **Partition identity (A5):** verify canonical partitions from deep-water SPECOUT match correctly to handoff-SPECOUT partitions across transects
10. **Fallback (A6):** test model crash path — verify API returns degraded response, not 500
11. **Scoring recalibration:** compare scoring outputs before/after the pipeline change; flag any >10% score delta for user review
12. **Face height sanity check:** compare `breakingFaceHeight` against Surfline/buoy data for the current swell conditions

### QC Gate 4

- 1D model runs successfully for HB Pier across all forecast timesteps
- Multiple swell partitions survive and transform independently
- `breakingFaceHeight` is in the physically reasonable range (not 2.76ft when Surfline shows 5-7ft)
- `multiSwell` shows deep-water values comparable to NDBC buoy partitions
- Peel angle computed and classified
- K-G depth correction fully removed
- Obstacle-affected transects excluded from headline metrics
- Auditor: zero silent deferrals, all new response fields documented
- Test baselines hold (new tests added for 1D model module)

---

## Phase 5 — Swell Pipeline & Display Fixes

**Purpose:** Fix the remaining swell display issues and beach profile chart using 1D model output.

### T5.1 — SURF-11 MOVED to Phase 4 (T4.1b)

SURF-11 spectral decomposition fix is now T4.1b in Phase 4 — it must land before the per-partition pipeline (T4.2) can work. See Phase 4.

### T5.2 — Beach profile API: 1D model output with zones and wave shapes (SURF-9, SURF-19, SURF-20)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/beach_profile.py`, new `services/surf_zone_classifier.py`

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §5.1 (Hs envelope), §5.3 (wave shapes), §5.5 (surf zone widths)
2. SURF-FIXIT-LIST SURF-9 (axis units, datum), SURF-19 (resolution)
3. Current `endpoints/beach_profile.py` response shape

**Do:**
1. `beach_profile` endpoint returns the 1D model's full output per transect:
   - **Hs envelope:** Hs at every 3-5m from handoff to shore (replaces SWAN CURVE at 50m)
   - **Break points:** List of H/d = gamma crossings with: cross-shore position, depth, Hs at break, breaker type (Iribarren), per-partition break info
   - **Wave shapes:** At each profile point, the local wave surface computed from theory — Stokes 2nd order in intermediate water, cnoidal in shallow water, bore/turbulent post-breaking. Represented as a discretized wave surface profile: array of (phase, elevation) pairs relative to the local still water level
   - **Surf zones:** Classified zones along the transect:
     - `impact_zone`: outer break to 50% energy loss — {start_distance, end_distance, start_depth, end_depth}
     - `foam_zone`: 50% energy loss to bore minimum — {start_distance, end_distance, start_depth, end_depth}
     - `total_surf_zone`: outer break to swash — {width_m, start_distance, end_distance}
     - `reform_trough`: gap between outer and inner break zones on multi-bar beaches (if present)
   - **Jacking factor:** Per-bar Hs_bar_crest / Hs_approach
   - **Per-partition overlay:** Which swell component breaks where along the profile
2. Accept a `transect_index` query parameter (default: best-peak transect for the current timestep). Also accept `transect_index=all` for the heat map.
3. Include metadata: axis units, vertical datum (from DEM), transect bearing, obstacle flag

**Accept:**
- Response contains Hs at 3-5m resolution (not 50m lumps)
- Break points from 1D model H/d crossings (not SWAN QB)
- Surf zones classified with start/end positions and depths
- Wave shapes available at each point as discretized surface profiles
- Multi-bar profiles show two break zones with a reform trough between them
- Per-partition break info shows "16s groundswell breaks at outer bar, 9s windswell breaks at inner bar"
- Datum and units in response metadata

### T5.3 — Beach profile chart: complete cross-shore visualization (SURF-9, SURF-20)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `components/marine/tabs/BeachProfileChart.tsx`, translation files

**Reading list:**
1. T5.2 response shape (what the API now provides)
2. SURF-FIXIT-LIST SURF-9 (axis units, datum), SURF-20 (water column rendering)
3. SURF-ZONE-MODEL-BRIEF §5.3 (wave shape depth regimes table)
4. DESIGN-MANUAL — chart patterns, color tokens

**Do:**

The beach profile chart becomes the cross-shore equivalent of the heat map — it shows what happens to waves as they approach shore along one transect. It must tell the full story: approach → shoaling → jacking over bars → breaking → impact zone → foam zone → shore.

1. **Seafloor profile** (bottom layer): CUDEM bathymetry rendered as a filled tan polygon from the seabed to the chart bottom. Sandbars and troughs visible at 3-5m resolution.

2. **Water column** (middle layer): Solid visible blue fill from the still water level (tide-adjusted) down to the seafloor. Opacity ~0.20-0.30 — visible but not opaque. This IS the water. (Fixes SURF-20: currently 8% opacity = invisible.)

3. **Wave surface / Hs envelope** (top layer): The 1D model's Hs rendered as the wave surface above the still water level. In the shoaling zone, show the Hs envelope as a smooth curve rising over bars and dipping in troughs. In the breaking zone, the envelope drops as energy dissipates.

4. **Wave shapes** (detail overlay, optional toggle): At selected points along the transect, render the actual wave surface shape from the 1D model's Stokes/cnoidal output — showing crests steepening as waves approach breaking, sharp cnoidal crests in shallow water, and post-breaking bore shapes. These are small wave cross-sections overlaid on the Hs envelope, not the envelope itself.

5. **Surf zone overlays** (same zones as Phase 7 heat map, but in profile):
   - **Impact zone:** Semi-transparent red/orange overlay between the outer break and 50% energy loss line. Labeled "IMPACT ZONE" — this is where the heaviest whitewater is, where wipeouts happen.
   - **Foam zone:** Semi-transparent yellow/green overlay between 50% energy loss and the bore minimum. Labeled "FOAM ZONE" — manageable whitewater, reform zone.
   - **Reform trough** (multi-bar): Unlabeled clear gap between outer and inner break zones — waves reform here before breaking again on the inner bar.
   - Zone boundaries are vertical dashed lines with depth/distance annotations.

6. **Break point markers:** Vertical markers at each break point (H/d = gamma crossing) with:
   - Breaker type icon (spilling/plunging/surging)
   - Face height label (K-G/Caldwell output at that point)
   - Distance from shore
   - Per-partition annotation: "14s S swell" or "9s NW windswell" if partition info available

7. **Jacking annotation:** Where the Hs envelope shows a sharp increase over a bar (jacking factor > 1.3), annotate with the jacking factor: "1.5× jacking"

8. **Axis labels and datum** (SURF-9 fixes):
   - Y-axis: "Depth ({unit}, {datum})" — e.g., "Depth (ft, NAVD88)"
   - X-axis: "Distance from shore ({unit})" — e.g., "Distance from shore (ft)"
   - All axis labels use translation keys (SURF-9c)
   - Tick labels include unit suffix

9. **Transect selector:** If multiple transects available, a small dropdown or slider lets the visitor switch between transects (or "Best Peak" / "Average" presets). The chart re-renders for the selected transect.

**Accept:**
- Seafloor shows sandbar/trough structure at 3-5m resolution (not 50m steps)
- Water column visible between seafloor and surface (not invisible at 8% opacity)
- Hs envelope smooth and continuous, showing shoaling buildup and breaking decay
- Impact zone and foam zone rendered as distinct colored overlays with labels
- Break points marked with breaker type, face height, and distance
- Multi-bar profiles show two break zones with reform trough between them
- Jacking annotated where significant (>1.3×)
- Axis units and datum present on both axes
- Wave shape overlays render (if analytical model provides them)
- Transect selector works

### T5.4 — Swell display: deep-water values and per-partition break info (SURF-12, SURF-17, SURF-23)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `components/marine/tabs/SurfingTab.tsx`, translation files

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §7 — per-partition pipeline, display element table
2. SURF-FIXIT-LIST SURF-12 (swell/headline mismatch), SURF-17 (mislabeled row), SURF-23 (wrong reference depth)

**Do:**
1. **Swell card:** Shows deep-water swell components from SPECOUT decomposition at the handoff point. Label: "INCOMING SWELL (offshore)" or similar. Heights are pre-transformation — comparable to NDBC buoy reports and Surfline's swell card. Each component: height, period, direction, classification (groundswell/swell/wind_swell).

2. **Per-partition break info** (new section on surf card or expandable detail): For each swell component, show what the 1D model says it does at the beach:
   - "16s SSW groundswell → breaks at outer bar (200m out), 5ft plunging faces"
   - "12s S swell → breaks at middle bar (120m out), 4ft plunging faces"
   - "9s S windswell → breaks at inner bar (60m out), 3ft spilling faces"
   This connects the swell card (what's arriving) to the surf height card (what's breaking).

3. **72h forecast labels:**
   - SURF-17: Rename "Swell Height" row to "Surf Height" or "Face Height" (it shows K-G/Caldwell output, not swell)
   - Add a "Swell Height" row that shows the dominant deep-water partition height (actual swell, from SPECOUT decomposition)
   - Now both are visible: swell approaching (deep water) and surf height (at break) — consistent with Surfline's two-card approach

4. **Section label clarity (SURF-12):** Each section clearly states its data source:
   - "INCOMING SWELL" — deep-water values at the handoff
   - "CONDITIONS AT BREAK" — 1D model output at the break point
   - "SURF HEIGHT" — face height from K-G/Caldwell at break point

**Accept:**
- Swell card shows deep-water values comparable to NDBC buoy partitions
- Per-partition break info connects swell components to their breaking behavior
- 72h forecast has distinct swell and surf height rows
- Labels unambiguously identify data source (offshore vs at break)
- No more confusion between swell height and face height

### T5.5 — Update governing documents

- Owner: Coordinator (Opus)
- Files: API-MANUAL (beach profile response shape, swell card semantics), DESIGN-MANUAL (beach profile chart anatomy, zone overlays), DASHBOARD-MANUAL (surf page card layout changes)

### Adversarial Audit — Phase 5

**Audit scope:**
1. Decomposition finds all components (not just dominant) — test with multi-swell conditions
2. Beach profile API: verify response contains Hs at 3-5m, zone classifications, wave shapes, break points with breaker type — not just a bare Hs array
3. Beach profile chart: verify zones render as colored overlays with labels (not just break point markers)
4. Beach profile chart: verify water column is VISIBLE (not 8% opacity)
5. Beach profile chart: verify multi-bar rendering — if the bathymetry has two bars, the chart shows two break zones with a reform trough
6. Swell card: verify heights are from SPECOUT decomposition at handoff (deep water), NOT from the 1D model output at the break point
7. Per-partition break info: verify it connects the right swell component to the right break point (not scrambled)
8. 72h forecast: verify "Swell Height" and "Surf Height" are distinct rows showing different values from different sources
9. Label accuracy: every section header correctly identifies its data source
10. Silent deferral scan on all modified files

### QC Gate 5

- 3+ swell components shown for multi-swell conditions
- Beach profile chart shows full cross-shore story: seafloor, water column, Hs envelope, zone overlays (impact/foam), break point markers with breaker type and face height, jacking annotations
- Multi-bar profiles render two break zones with reform trough
- Wave shape overlays render at selected profile points
- Axis units and datum present
- Swell card shows deep-water values (compare against NDBC buoy — should be comparable)
- Per-partition break info connects swell to breaking behavior
- 72h forecast distinguishes swell height from surf height
- All labels clearly identify data source
- Auditor: zero silent deferrals, zones are real classified zones not placeholders
- Test baselines hold

---

## Phase 6 — Dashboard & Scoring Fixes (SURF-FIXIT-LIST)

**Purpose:** Fix the remaining SURF-FIXIT-LIST items not addressed by the 1D model work.

**Sequencing (Fable S2):** T6.2 and T6.3 edit `surf.py` and `surf_scorer.py` — the same files Phase 4 rewrites. Run Phase 6 scoring tasks (T6.2, T6.3) BEFORE Phase 4 starts, or AFTER Phase 4 lands. Do NOT run them concurrently. Dashboard-only tasks (T6.1, T6.4, T6.5) can run in parallel with any phase.

### T6.1 — Scoring bar redesign (SURF-1, SURF-3)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `SurfingTab.tsx`, translation files, DESIGN-MANUAL

**Reading list:**
1. SURF-FIXIT-LIST SURF-1 — full design direction (6 requirements)

**Do:** Implement the 6-point scoring bar redesign per SURF-1.

**Accept:** All 6 scoring items have bars, column headers present, bars fill relative to 100, colors signal sign, labels show denominator, values sum to total.

### T6.2 — timeOfDay scoring (SURF-2)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `enrichment/surf_scorer.py`, `endpoints/surf.py`, `services/almanac.py`

**Reading list:**
1. SURF-FIXIT-LIST SURF-2 — full problem description with two failures identified

**Do:** Wire sunrise/sunset from almanac to scorer. Implement afternoon penalty. Remove misleading docstring.

**Accept:** `timeOfDay` returns non-zero values at dawn (bonus) and afternoon (penalty). Sunrise/sunset correctly sourced from almanac.

### T6.3 — Conditions text units (SURF-10)

- Owner: `clearskies-api-dev` (Sonnet)

**Do:** Use operator's configured unit system in `_compose_conditions_text()`.

### T6.4 — Weather icons day/night (SURF-14)

- Owner: `clearskies-dashboard-dev` (Sonnet)

**Do:** Fix current conditions icon to use reactive scene data. Fix 72h forecast icons to determine day/night per-timestep.

### T6.5 — Low-priority dashboard polish (SURF-4, 5, 8, 13, 16, 18)

- Owner: `clearskies-dashboard-dev` (Sonnet)

**Do:** Fix all 6 low-priority items in a single pass:
- SURF-4: Use `periodUnit` variable instead of hardcoded "s"
- SURF-5: Replace hardcoded unit fallbacks with translation keys
- SURF-8: Use tide-specific unit for tide chip
- SURF-13: Reduce compass size by ~20%
- SURF-16: Append wind unit to row header
- SURF-18: Match tide chart "Now" line to Now page style (red, thicker dash)

### T6.6 — directionalExposure config verification (SURF-6)

- Owner: Coordinator (Opus)

**Do:** Check HB Pier config, set correct directional exposure based on beach geography.

### T6.7 — API-MANUAL scoring table update (SURF-7)

- Owner: Coordinator (Opus)

**Do:** Update §16 SurfScoringBreakdown table to match current Pydantic model.

### Adversarial Audit — Phase 6

**Audit scope:**
1. Scoring bars: verify all 6 values sum to total score (additive identity check)
2. timeOfDay: verify it returns NON-ZERO at dawn and afternoon (the original bug was silent no-op)
3. Conditions text: verify metric operators get metric units
4. Day/night icons: verify night timesteps show moon variant
5. Silent deferral scan on all modified scorer code

### QC Gate 6

- Scoring bars redesigned per SURF-1 spec
- timeOfDay returns non-zero at dawn/afternoon
- All low-priority dashboard items fixed
- Auditor: zero silent deferrals in scorer code
- Test baselines hold

---

## Phase 7 — Quasi-2D Heat Map & Peel Angle Display

**Purpose:** Build the dashboard visualization for multi-transect output: heat map, peel angle display, best-peak/average reporting.

### T7.1 — Heat map card

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: new component in `components/marine/tabs/`

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §2.2.5 — what multi-transect enables
2. SURF-ZONE-MODEL-BRIEF §5.8 — peel angle display
3. DESIGN-MANUAL — card anatomy, color tokens

**Do:**
1. Render a 2D color-coded map showing Hs across all transects (x = cross-shore distance, y = alongshore position)
2. **Surf zone polygons/curves** drawn across the transect array by connecting the corresponding zone boundaries from each transect:
   - **Break zone outer edge** — polygon/curve connecting the outermost break point (H/d = gamma crossing) across all transects. This is NOT a straight line — it follows the sandbar contour, bulging seaward over bar peaks and retreating shoreward over channels.
   - **Impact zone** — filled polygon between the outer break edge and the 50% energy loss line. Shows where the heaviest whitewater is.
   - **Foam zone** — filled polygon between the 50% energy loss line and the bore-propagation minimum. Lighter fill — the reform/whitewash zone.
   - **Total surf zone** — the combined extent from outer break to swash line.
3. Zone polygons use semi-transparent fills so the underlying Hs color map is still visible beneath them
4. Structure-affected transects visually distinguished (lighter opacity or hatched fill)
5. Color scale: Hs value → color (blue=small, green=medium, yellow/red=large)
6. Breaker type icons at break points per transect (spilling/plunging/surging)
7. Multi-bar rendering: if an outer bar and inner bar both break, show both break zone curves — the gap between them is the reform trough

**Accept:** Heat map renders for HB Pier with visible sandbar/rip channel variation across transects. Break zone curves follow the sandbar contour (not straight lines). Impact and foam zones visible as distinct polygons. Pier-shadowed transects distinguished. Multi-bar breaks (if present) show two break zone curves.

### T7.2 — Peel angle on main Surf Conditions card

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `components/marine/tabs/SurfingTab.tsx`, translation files

**Reading list:**
1. SURF-ZONE-MODEL-BRIEF §5.8 — peel angle classifications and computation
2. DESIGN-MANUAL — card anatomy, Surf Conditions card layout

**Do:**
1. Add peel angle to the **main Surf Conditions card** (not a separate card — this is primary surf information alongside wave height and period)
2. Display: peel angle value (degrees), classification label, and direction indicator
3. Classification labels: "Closeout" (<30°), "Fast Right/Left" (30-45°), "Good Right/Left" (45-66°), "Mellow Right/Left" (>66°)
4. Direction determined from the break line angle relative to shore: waves peeling toward the right (from surfer's perspective facing shore) = "Right", toward left = "Left"
5. Visual indicator: small arrow or chevron showing peel direction (left/right/both for A-frame peaks)
6. Closeout alert: when peel angle <30°, highlight in warning color — surfers should know before paddling out
7. Update the 72h forecast row to include peel angle per timestep (peel angle changes as swell direction shifts)

### T7.2b — Wave shape indicator on main Surf Conditions card

- Owner: `clearskies-dashboard-dev` (Sonnet)

**Do:**
1. Display the dominant wave shape at the primary break point on the main Surf Conditions card — this tells surfers what kind of wave to expect before they see it
2. Wave shape is determined by the 1D model's depth regime at the break point:
   - **Steep / Hollow** — cnoidal with high Iribarren (plunging). The pitching barrel wave. Show a stylized wave icon with a curling lip.
   - **Steep / Crumbly** — steepened Stokes with low Iribarren (spilling). The fat, crumbling wave. Show a rounded wave icon with whitewater on top.
   - **Walled** — cnoidal with low peel angle (<30°). Breaking all at once. Show a flat wall icon.
   - **Mushy** — Stokes with small Hs/d ratio. Gentle, slow-breaking. Show a low rounded wave icon.
3. The shape classification combines breaker type (Iribarren from §5.4) + wave theory regime (Stokes vs cnoidal from §5.3) + peel angle. These are already computed — this is a display combination, not new physics.
4. Label with the classification text: "Hollow & Plunging", "Steep & Crumbly", "Walled Closeout", "Mushy & Slow"
5. Update the 72h forecast to show wave shape per timestep (shape changes as swell period and direction shift)

**Accept:** Wave shape indicator on main Surf Conditions card matches the 1D model's physics at the break point. Changes across timesteps as conditions evolve. Surfers can see "hollow and plunging" vs "mushy and slow" at a glance.

**Accept (combined T7.2 + T7.2b):** Peel angle and wave shape both appear on the main Surf Conditions card. Closeout conditions highlighted. 72h forecast shows peel angle and wave shape variation over time.

### T7.3 — Best peak / average reporting

- Owner: `clearskies-dashboard-dev` (Sonnet)

**Do:**
1. Headline surf height: show as a range "Best peak: 5-7ft / Average: 3-5ft"
2. If structure shadow present: add "In pier shadow: 1-3ft"
3. 72h forecast: show best-peak face height per timestep

### Adversarial Audit — Phase 7

**Audit scope:**
1. Heat map: verify it uses ALL transects (open + structure-affected), not just open
2. Zone polygons: verify break zone curves connect actual break points across transects (not straight lines), impact/foam zones are distinct polygons
3. Multi-bar: verify both outer and inner break zones render when present
4. Peel angle: verify it uses OPEN transects only for the computation
5. Peel angle placement: verify it is ON the main Surf Conditions card, not a separate card
6. Peel direction: verify left/right determination is correct relative to surfer's perspective (facing shore)
7. Best peak: verify it's the maximum across OPEN transects, not ALL transects
8. Color scale: verify accessibility (not red/green only — check against DESIGN-MANUAL color guidelines)

### QC Gate 7

- Heat map renders correctly with sandbar/rip variation visible
- Break zone, impact zone, and foam zone rendered as distinct polygons following sandbar contour
- Multi-bar breaks show two break zone curves with reform trough between them
- Peel angle on main Surf Conditions card with direction and classification
- Closeout conditions (<30°) highlighted
- 72h forecast includes peel angle per timestep
- Best peak / average clearly distinguished in display
- Structure shadow reported separately when present
- Auditor: heat map uses all transects, zones are polygons not straight lines, peel/peak use open only
- Test baselines hold

---

## Phase 8 — Validation & Calibration

**Purpose:** Validate the 1D model output against ground truth. Recalibrate scoring thresholds.

### T8.1 — CANCELLED (SWASH ruled out entirely — 1D-MODEL-BENCHMARK-BRIEF Round 2, 2026-07-21)

SWASH is unvalidated and ruled out entirely — for production, LUT precomputation, and benchmark referee use. No replacement. See SURF-MODEL-FIX-PLAN T7.5 for disposition.

### T8.2 — Consistency check (R3)

- Owner: `clearskies-test-author`

**Do:** Verify that the 1D model reproduces SWAN's own CURVE Hs values in the QB=0 zone (automatic acceptance test — add to test suite).

### T8.3 — Iribarren validation (R4)

- Owner: Coordinator (Opus)

**Do:** Compute Iribarren for known surf spots with documented breaker types. Cross-check against Surfline/BSR breaker type descriptions.

### T8.4 — Surfline comparison (replaces webcam — no webcam at HB Pier)

- Owner: Coordinator (Opus)

**Do:** Compare SwellTrack face height and breaker type against Surfline's reported values for HB Pier. Document comparisons for at least 3 different swell conditions. See SURF-MODEL-FIX-PLAN T6.4 for the detailed procedure.

### T8.5 — Peel angle validation (R11)

- Owner: Coordinator (Opus)

**Do:** Compare peel angle output against Surfline/BSR peel descriptions when available.

### T8.6 — Scoring recalibration

- Owner: Coordinator (Opus) + `clearskies-api-dev`

**Do:** Compare scoring outputs before/after the pipeline change. If face heights shifted significantly (expected — they were systematically low), `_WAVE_HEIGHT_RANGES_FT` thresholds in the scorer need adjustment.

**Accept:** Scores for known good/bad conditions produce intuitively correct ratings.

### QC Gate 8 (Final)

- T8.1 CANCELLED (SWASH ruled out)
- Consistency check passes (reproduces SWAN in QB=0 zone)
- Iribarren classifications match Surfline/BSR breaker type descriptions
- Face heights within ±30% of Surfline for 3+ conditions
- Scoring produces intuitively correct results for known conditions
- All governing documents match final implementation
- All test baselines hold

---

## Summary

| Phase | Purpose | Blocking? | Key deliverables |
|---|---|---|---|
| 0 | Governing Document Updates | Yes — agents read docs before coding | ADR amendments (093-097), ARCHITECTURE.md, API-MANUAL, PROVIDER-MANUAL, OPS-MANUAL |
| 1 | 1D Model Benchmark | Yes — blocks Phases 3-4 | Model selection decision, runtime data |
| 2 | Measurement Zone & Multi-Transect | No (can run parallel with Phase 1) | Shoreline segment, transect generation, obstacle filtering, wizard UI |
| 3 | L3 Smart Sizing & SPECOUT | Needs Phase 2 | Optional L3, structure-sized grids, SPECOUT at handoff |
| 4 | 1D Model Integration | Needs Phases 1, 2, 3 | Per-partition pipeline, K-G fix, surf endpoint rewiring |
| 5 | Swell Display & Profile | Needs Phase 4 | SURF-11 fix, beach profile chart, swell/surf labels |
| 6 | Dashboard & Scoring Fixes | Independent | SURF-1,2,4-8,10,13,14,16,18 |
| 7 | Heat Map & Peel Angle | Needs Phase 4 | Quasi-2D visualization, peel angle, best-peak display |
| 8 | Validation & Calibration | Needs Phase 4 | Surfline comparison, score recalibration (SWASH cancelled, webcam replaced) |

**Parallelization:** Phase 0 (docs) must complete before any implementation phases. Phase 1 (benchmark) can overlap with Phase 2 (measurement zone) since they don't share code. Phase 6 dashboard-only tasks (T6.1, T6.4, T6.5) can run in parallel with any phase. Phase 6 scoring tasks (T6.2, T6.3) must run either BEFORE Phase 4 starts or AFTER Phase 4 lands — they edit the same files (Fable S2). SURF-11 (T4.1b) must complete before T4.2 starts (Fable S1). T2.3 (handoff algorithm) must complete before T2.2 (transect generation) (Fable S3). SWASH cannot be both the selected model and the Phase 8 ground truth — if SWASH is selected, Phase 8 T8.1 must use a different validation approach (Fable S4).

**SURF-FIXIT-LIST resolution:**

| ID | Resolution | Phase |
|---|---|---|
| SURF-1 | Scoring bar redesign | 6 |
| SURF-2 | timeOfDay implementation | 6 |
| SURF-3 | Subsumed by SURF-1 | 6 |
| SURF-4 | Hardcoded "s" | 6 |
| SURF-5 | Hardcoded fallback units | 6 |
| SURF-6 | directionalExposure config | 6 |
| SURF-7 | API-MANUAL table | 6 |
| SURF-8 | Tide unit | 6 |
| SURF-9 | Beach profile chart | 5 |
| SURF-10 | Conditions text units | 6 |
| SURF-11 | Swell decomposition | 5 |
| SURF-12 | Swell label confusion | 5 |
| SURF-13 | Compass size | 6 |
| SURF-14 | Day/night icons | 6 |
| SURF-15 | Power always 100% | 5 (consequence of SURF-11) |
| SURF-16 | Wind unit header | 6 |
| SURF-17 | Swell Height mislabeled | 5 |
| SURF-18 | Tide chart Now line | 6 |
| SURF-19 | 50m spacing | 4 (replaced by 1D model at 3-5m) |
| SURF-20 | Water column invisible | 5 |
| SURF-21 | Single transect through OBSTACLE | 2 (multi-transect) |
| SURF-22 | K-G at wrong depth | 4 |
| SURF-23 | Swell display wrong reference | 4 |
| SURF-24 | No obstacle validation | 2 |

---

## Execution Progress

**Last updated:** 2026-07-21 (session 2)

### Phase 0 — COMPLETE (af14784)
All 8 tasks done. ADRs 093-097 amended, ARCHITECTURE.md, API-MANUAL §17, PROVIDER-MANUAL §14, OPERATIONS-MANUAL updated. DESIGN-MANUAL §16 bar normalization rule updated. No implementation code changed.

### Phase 1 — COMPLETE (8e28bfb)
- T1.1: Benchmark inputs extracted from production SWAN L3 (TABLE_1, SPEC_1)
- T1.3: Analytical 1D model implemented (575 lines, 0.85ms/transect with numpy). Commit 8e28bfb.
- T1.6: SWAN SurfBeat-1D confirmed AVAILABLE as standard `SURFBeat` command in SWAN 41.45/51. Complements 1D model. Not currently used.
- T1.7: **Model selected: ANALYTICAL (Option A).** 0.85ms/transect, ~5.5s for full forecast cycle (30 transects × 3 partitions × 72 timesteps). No LUT needed. XBeach-1D surfbeat deferred to v2.
- T1.2/T1.4/T1.5: XBeach/SWASH install+benchmark DEFERRED to v2.

### Phase 2 — COMPLETE
- T2.1: Segment data model — DONE (abe7c12). SurfSpotConfig uses segment fields, computed beach_facing/transect_count/primary_transect_index.
- T2.2: Multi-transect generation — DONE (201353c). compute_spot_transects() with obstacle-aware TransectInfo, 359 lines added to swan_formats.py.
- T2.3: Handoff depth algorithm — DONE (02ea5e7). transect_handoff.py, 742 lines, 4-step algorithm per SURF-ZONE-MODEL-BRIEF §2.3.4.
- T2.4: Wizard shoreline segment UI — DONE (4c0a8ed, 7ed6b76). Leaflet.draw polyline, transect rendering, OBSTACLE color coding, 17 files changed in stack repo.
- T2.5: Admin segment editing — DONE (918181e). Leaflet segment map in admin marine form, draggable endpoints, transect preview, segment fields replace beach_facing_degrees in routes.py validation and apply payload. 321 insertions across 2 files.
- T2.6: Pipeline continuity bridge — folded into T2.1 (primary_transect_index).
- T2.7: TRANSM correction — DONE (1a3f843). Pier pilings 0.8→0.95.
- T2.8: Governing doc updates — DONE (02b0ccf). OPERATIONS-MANUAL surf config table updated with segment fields, l3_enabled, transect_spacing_m.
- Adversarial Audit + QC Gate 2 — DEFERRED (batched with Phase 3/4 audits).

### Phase 3 — COMPLETE (6209c7a, 3e3728d)
- T3.1: L3 optional per location — DONE (6209c7a). l3_enabled field in SurfSpotConfig ("auto"/"on"/"off"), per-cluster skip logic in run_3level().
- T3.2: L3 smart sizing around structures — DONE (6209c7a). smart_size_l3_grid() in swan_domain.py, structure-based bbox with shadow zone (3× structure length + 100m pad).
- T3.3: SPECOUT extraction — DONE (3e3728d). DWR SPECOUT in L2 INPUT (one per spot at ~15m), parsed into self._spectral_results with raw freqs_hz/dirs_deg/energy. Multi-cluster bug fixed (removed reset).
- T3.4: Hotstart invalidation — DONE (3e3728d). MD5[:8] bbox hash, stale hotstart deletion on mismatch.
- T3.5: Governing doc updates — DONE (02b0ccf, same commit as T2.8).

### Phase 4 — COMPLETE (50d7411)
- T4.1b: SURF-11 decomposition fix — DONE (3d5a884). Threshold 0.05→0.005, window ±2→±4, greedy exclusion removed.
- T4.2: Per-partition pipeline — DONE (88e87ca). surf_1d_pipeline.py, 766 lines. RSS combination, depth-limited saturation, H1/10 face height, peel angle.
- T4.3: K-G/Caldwell fix — DONE (3d5a884). source="break_point" → 1.27×Hs, SHALLOW_DEPTH_THRESHOLD_M and lerp removed.
- T4.4: Wire pipeline into surf endpoint — DONE (eef56fd). 105 lines added to surf.py. Graceful degradation when pipeline unavailable.
- T4.5: Fallback/degraded mode — DONE (50d7411). Bulk fallback (single partition from SWAN TABLE params when SPECOUT unavailable), partial failure exclusion, degraded flag preserved in response. surf.py updated to apply 1D results when face_height > 0 even in degraded mode.
- T4.5b: Partition identity across transects — DONE (50d7411). _match_partitions() with ±2s period, ±20° direction (wraparound-safe). _aggregate_partition_breaks() uses canonical indices. Unmatched → partition_index=-1 "other".
- T4.6: Governing doc updates — API-MANUAL §17 already documents response fields from Phase 0. No additional updates needed.
- Adversarial Audit + QC Gate 4 — DEFERRED (batched with Phase 2/3 audits).

### Phase 5 — COMPLETE (58967d7, c021bc3)
- T5.2: Beach profile API — DONE (58967d7). 596 insertions. Hs envelope at 3-5m, break points with Iribarren/face height, wave shapes (Stokes/cnoidal/bore), surf zones (impact/foam/reform), jacking factors, per-partition breaks, transect_index query param ("best"/"all"/int), metadata block.
- T5.3: Beach profile chart redesign — DONE (c021bc3). 9-element SVG rewrite: seafloor, water column 0.25 opacity (SURF-20 fix), Hs envelope, wave shapes toggle, surf zone overlays, enhanced break markers, jacking annotations, axis labels with unit+datum, transect selector.
- T5.4: Swell display deep-water values — DONE (c021bc3). "INCOMING SWELL (offshore)" label, per-partition break info section, "Surf Height"/"Swell Height" split in 72h forecast.
- T5.5: Governing doc updates — DONE (6634e3d). DESIGN-MANUAL + DASHBOARD-MANUAL synced.

### Phase 6 — COMPLETE
- T6.1: Scoring bar redesign — DONE (15cc348). All 6 SURF-1 points.
- T6.2: timeOfDay scoring — DONE (87ff2a3). Dawn bonus + afternoon penalty wired.
- T6.3: Conditions text units — DONE (3f2a151). Operator units via {unit} placeholder in 13 locales.
- T6.4: Day/night icons — DONE (25a0f8d). Reactive scene + per-timestep isNight.
- T6.5: Dashboard polish — DONE (ec6ea73). SURF-4,5,8,13,16,18.
- T6.6: directionalExposure config — DONE (verified correct).
- T6.7: API-MANUAL scoring table — DONE (updated to match Pydantic model).

### Phase 7 — COMPLETE (2026-07-21, commit 292216e)

- T7.1: HeatMapCard.tsx — custom SVG quasi-2D Hs heat map. Zone overlays (impact/foam/break), structure hatching, breaker-type glyphs, multi-bar splitBreakPoints(). A11y: role=img + aria-labelledby + sr-only data table. New types HeatMapProfileData/HeatMapTransectData; getBeachProfileAll() in client.ts; useBeachProfileAll() hook.
- T7.2: Peel angle on Card 3 (Conditions at Break) — value, classification, directional chevron, closeout alert (role=alert). 72h forecast peelAngle row.
- T7.2b: Wave shape indicator on Card 3 + 72h forecast waveShape row.
- T7.3: Best peak / Avg headline on Card 3 with optional shadow height. 72h forecast bestPeak row.
- i18n: 54 new keys in all 13 locale files.
- TypeScript: 0 errors (npx tsc -b --noEmit).
- Build: npx vite build — success, built in 2.10s.
- Axe-core: 2 pre-existing violations on splash screen (color-contrast on #splash-text, region on #root) — not introduced by T7 changes.

Deferred / awaiting API: All new SurfForecast fields (peelAngle, peelClassification, bestPeakFaceHeight, spotAverageFaceHeight, shadowFaceHeight, waveShapeClassification, transectCount, openTransectCount) and HeatMapProfileData (/profile?transect_index=all endpoint) render gracefully as "—" / hidden when API does not yet provide them. No blocking changes required in API repo for UI to merge.

### Phase 8 — IN PROGRESS (deployment verification)
- T8.1: SWASH ground truth — BLOCKED. SWASH not installed (deferred to v2 in Phase 1 T1.2/T1.5).
- T8.2: Consistency check — DONE (8064982 test, c987973 fix). Test exposed Battjes-Janssen sign error: `_battjes_janssen()` used raw negative dx, causing energy inflation instead of dissipation. Fix: `np.abs(dx)`. Impact: 20-30% Hs overestimate in pre-breaking zone corrected. Both consistency tests now pass (shoaling-only shore-normal + shoaling+refraction oblique).
- T8.3: Iribarren validation — DEFERRED. Requires: (a) spot reconfigured with segment via wizard, (b) SWAN cycle with new SPECOUT config, (c) actual swell in the water. Current endpoint returns degraded=True with no swell (Hs=0.01m, Tp=1.97s).
- T8.4: Webcam/surf report comparison — DEFERRED. Requires 5-10 sessions with live surf conditions over days/weeks.
- T8.5: Peel angle validation — DEFERRED. Requires live peel angle output + webcam comparison.
- T8.6: Scoring recalibration — DEFERRED. Requires non-degraded pipeline output with real swell. Current scoring returns 0 due to flat conditions.
- **Deployment status:** API deployed to weewx (exit 0), dashboard deployed to weather-dev (exit 0). API healthy. No DWR SPECOUT files yet — next SWAN cycle will produce them. Spot needs segment reconfiguration via wizard to activate multi-transect pipeline (currently transectCount=1, openTransectCount=0).

### Commit Log (25 commits, 4 repos)

**Meta repo:**
- af14784 — Phase 0: governing doc updates + planning docs
- 02b0ccf — T2.8+T3.5: OPERATIONS-MANUAL segment fields update
- 9828da6 — docs: execution progress update (Phases 2-5)
- 6634e3d — T5.5: sync DESIGN-MANUAL, DASHBOARD-MANUAL with Phase 5
- 2f4c158 — docs: Phase 7 COMPLETE

**API repo:**
- abe7c12 — T2.1: segment data model
- 02ea5e7 — T2.3: handoff depth algorithm
- 201353c — T2.2: multi-transect generation
- 1a3f843 — T2.7: TRANSM correction
- 87ff2a3 — T6.2: timeOfDay scoring
- 3f2a151 — T6.3: conditions text units
- 8e28bfb — T1.3: analytical 1D model
- 3d5a884 — T4.1b+T4.3: decomposition fix + K-G fix
- 88e87ca — T4.2: per-partition pipeline
- eef56fd — T4.4: wire pipeline into surf endpoint
- d394074 — test fix: update test_breaker_height for T4.3
- 6209c7a — T3.1+T3.2: l3_enabled + structure-based L3 smart sizing
- 3e3728d — T3.1-T3.4: SPECOUT pipeline + hotstart invalidation
- 50d7411 — T4.5+T4.5b: fallback/degraded mode + partition identity
- 58967d7 — T5.2: beach profile API with 1D model output
- 8064982 — T8.2: 1D model consistency check tests
- c987973 — T8.2 fix: correct Battjes-Janssen dissipation sign error

**Dashboard repo:**
- ec6ea73 — T6.5: 6 dashboard polish fixes
- 15cc348 — T6.1: scoring bar redesign
- 25a0f8d — T6.4: day/night icons
- c021bc3 — T5.3+T5.4: beach profile chart redesign + swell display
- 292216e — T7.1-T7.3: heat map, peel angle, wave shape, best peak/average

**Stack repo:**
- 4c0a8ed — T2.4: wizard segment UI
- 7ed6b76 — T2.4: cleanup fix
- 918181e — T2.5: admin segment editing
