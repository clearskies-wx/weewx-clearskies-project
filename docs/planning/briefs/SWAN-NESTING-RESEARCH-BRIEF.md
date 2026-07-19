# Research Brief: SWAN Nesting Architecture Redesign

**Date:** 2026-07-18
**Status:** COMPLETE — all design decisions settled and implemented (session 3)
**Origin:** Production testing revealed the inner grid bathymetry was 3km-interpolated (not native CUDEM resolution), making the surf zone invisible to the model. Investigation revealed broader architectural issues with domain sizing, nesting levels, and resolution.
**Implementation:** Phases 13-16 of SWAN-FIXES-PLAN committed 2026-07-18 (session 3). GSFM shelf boundary verified at 10.3 km for HB Pier (San Pedro shelf is narrower than initial 20-25 km estimate).

---

## §1 — Problems Identified

### 1.1 Inner grid bathymetry at wrong resolution
The 2D CUDEM grid (`swan_bathymetry.json`) is downloaded at **outer grid resolution (3km)** and bilinear-interpolated to the inner grid (200m). The inner grid has no more bathymetric detail than the outer grid. Every sandbar, reef, channel, and coastal feature < 3km is invisible. The surf zone (0-3m depth within 100m of shore) is completely unresolved.

**Root cause:** `_load_or_download_cudem_grid()` is called once with `outer_resolution_km * 1000.0` spacing. Both outer and inner grids reuse this same coarse cache. The inner grid was never given its own high-resolution CUDEM download.

### 1.2 Outer grid domain oversized
Current outer grid: ~195km × 230km. For HB Pier, the shelf break (~100-200m depth) is ~20-30km offshore. The outer grid extends ~200km offshore — 170km of deep open ocean that WW3 already handles. This wastes compute on redundant deep-water propagation.

### 1.3 No surf zone resolution
At 200m inner grid resolution, the entire surf zone (0-3m depth, ~100m from shore) fits in a single grid cell. SWAN cannot model breaking, sandbars, or pier shadow zones at this resolution. QB=0 everywhere despite correct transect placement.

### 1.4 Domain sizing is not physics-based
The outer grid bbox is computed as `all_spot_coordinates ± 1.0°` — a fixed margin regardless of shelf geometry. This produces wildly different coverage depending on spot placement, not on oceanographic requirements (where WW3 fails, shelf break location, island effects).

### 1.5 IQR smoothing destroyed CUDEM data
`_smooth_outliers_iqr()` treated the 0m shoreline depth as a statistical outlier and replaced it with 4.26m. **Removed in commit 66e5cae.** CUDEM data is QC'd by NOAA (Carignan et al. 2023) and should be used as-is.

---

## §2 — Physics: Where WW3 Fails and SWAN Begins

Waves "feel" the bottom when depth < wavelength/2. Below this depth, WW3's deep-water assumptions break down and SWAN's nearshore physics (refraction, shoaling, breaking) become necessary.

| Swell period | Wavelength (L = 1.56 × T²) | WW3 valid (depth > L/2) | SWAN essential (depth < L/20) |
|---|---|---|---|
| 10s | ~156m | > 78m | < 8m |
| 12s | ~225m | > 112m | < 11m |
| 14s | ~350m | > 175m | < 18m |
| 16s | ~500m | > 250m | < 25m |
| 20s | ~624m | > 312m | < 31m |

The WW3→SWAN handoff depth is **location-specific** — it depends on the maximum swell period that reaches the coast, which varies globally.

**Continental shelf width varies enormously:**
- Hawaii: ~1-2km to shelf break
- SoCal: ~15-30km
- East Coast US: ~100-150km
- Gulf of Mexico: up to ~200km
- UK North Sea: ~200km+

A fixed domain size cannot work for a global product.

---

## §3 — Resolution Requirements by Feature

| Feature | Typical size | Grid resolution needed | Source |
|---|---|---|---|
| Continental shelf refraction | 10-100km | 1-3km | Standard practice |
| Nearshore refraction/shoaling | 1-10km | 100-200m | NWPS operational |
| Sandbars / rip channels | ~100m alongshore | 10-25m | Kumar 2015, MIT sandbar study |
| Surf zone breaking | 100-200m wide | 25-50m (3-4 cells across) | Multiple sources |
| Pier shadow zone | ~50-100m wide | 10-25m | Diffraction resolution |
| Breakwater effects | ~100-500m | 25-50m | OBSTACLE + grid resolution |

**Key finding:** 10m grid resolution is used in the innermost surf zone for sandbar modeling (Kumar 2015, MIT). 50m is the minimum for break detection. 200m cannot resolve the surf zone.

**SWAN nesting ratio guidance (from SWAN user manual):** Spectral resolution between nests should not differ by more than 2-3×. If finer resolution is needed, add another nesting level. Spatial refinement ratios of 5-10× are acceptable.

---

## §4 — Domain Sizing: Deepwater Boundary Dataset (DECIDED)

### The problem

We need to know where the WW3→SWAN handoff occurs BEFORE downloading high-resolution bathymetry, to size the SWAN coarse grid correctly. This is a chicken-and-egg problem: you need the domain to download bathymetry, but you need bathymetry to know the domain.

### Why a raw depth contour doesn't work

A depth contour (isobath) at any fixed depth (140m, 200m, etc.) traces EVERY bathymetric feature that crosses that depth — submarine canyons cutting into the shelf, isolated holes, trenches. These irregularities do NOT represent the deepwater boundary. A canyon at 200m depth 5km from shore does not mean "deep water starts 5km out" — the shelf continues on both sides of the canyon.

What we actually need: **a line that represents where the flat continental shelf transitions to the steep continental slope** — regardless of the exact depth (which varies by location). This is the physical boundary where WW3's deep-water assumptions start failing and SWAN must take over.

### Decision: GSFM shelf/slope boundary (Harris et al. 2014)

**Dataset:** Global Seafloor Geomorphic Features Map (GSFM)
**Authors:** Harris, P.T. & Macmillan-Lawler, M. (2014)
**Publication:** "Geomorphology of the oceans," Marine Geology, 352, pp. 4-24
**Download:** [bluehabitats.org](https://bluehabitats.org/?page_id=58) — full archive 389 MB (ESRI shapefiles)
**Also available via:** [researchdata.edu.au](https://researchdata.edu.au/digital-seafloor-geomorphic-global-ocean/3962960)

**What it is:** The entire global ocean floor classified into 29 geomorphic feature categories — shelf, slope, rise, abyss, canyons, seamounts, ridges, trenches, etc. — based on the SRTM30_PLUS 30-arc-second bathymetry database. 131,192 polygons total.

**Why it solves our problem:**
1. The classification is by **gradient analysis** (change in seafloor slope), not by a fixed depth
2. **Canyons are their own category** — they don't contaminate the shelf/slope boundary
3. The boundary between "shelf" polygons and "slope" polygons IS the deepwater dividing line, defined by where the bottom gradient steepens
4. It's geomorphologically meaningful — represents the actual physical transition, regardless of local depth variations
5. Global coverage, free, static (ocean floor doesn't change)

**What we rejected:**
- **COMARGE (IFREMER, 2009):** Continental margin polygon with upper boundary at fixed 140m depth (the average shelf break depth globally). Problem: it's derived from a fixed-depth isobath from S2004 at 1 arc-minute. "Manually edited in particular cases" but fundamentally depth-based, not gradient-based. Would still trace canyon walls at 140m depth.
- **GEBCO-derived 200m isobath:** Same problem — raw depth contour includes every irregularity.
- **Natural Earth bathymetry contours:** Generalized at cartographic scales, but still depth contours (same category of problem).
- **Marine Regions Extended Continental Shelves v2:** Legal/political boundary (UNCLOS submissions), not a physical boundary.

### How we use it

**Pre-processing (one-time, ships with the API package):**
1. Download full GSFM archive
2. Extract only the "shelf" layer polygons
3. Dissolve into a single global multipolygon
4. Extract the OUTER boundary as a polyline (the inner boundary is the coastline — we don't need it)
5. Simplify slightly for file size
6. Ship as a static file (~10-20 MB estimated) in the API package

**Query at wizard time (instant, offline):**
1. Operator places spot pin(s)
2. For each spot: find nearest point on the GSFM shelf boundary polyline
3. Maximum distance across all spots = required offshore extent of the SWAN coarse grid
4. Bbox = all spots lateral extent + margins + offshore extent
5. No API calls, no bathymetry download needed, works offline

**For verification/refinement (optional, at SWAN run time):**
- The GEBCO API (`https://api.gebco.net/`) can do individual point depth queries at ~450m resolution globally to verify the boundary depth at the chosen domain edge
- This is a sanity check, not required for domain sizing

---

## §5 — Nesting Architecture Design

### Design constraints

- **Target hardware:** Small server, 6 cores, ≤300 MB memory, ≤15 min total runtime
- **Spot model:** Operator defines multiple spot locations ("local" — within ~30 km of coastline). All spots share one SWAN computational domain. Each spot is an output location within the solved wave field.
- **Operator constraint:** This is for LOCAL surf forecasting, not a global surf database. Spots must fit within a maximum bounding box (soft limit — warn, don't prevent).

### Deepwater boundary: GSFM shelf/slope polyline

**Data source:** Harris et al. (2014) Global Seafloor Geomorphic Features Map (GSFM), available at [bluehabitats.org](https://bluehabitats.org/?page_id=58).

**Why GSFM, not a depth contour:** A raw isobath (e.g., 140m or 200m contour) traces every submarine canyon, trench, and hole — it doesn't represent a meaningful "where deep water begins" boundary. The GSFM classifies the ocean floor into geomorphic units (shelf, slope, rise, abyss, canyon, etc.) using **gradient analysis**. Canyons are their own category, so the shelf/slope boundary IS the clean deepwater dividing line without irregularities.

**What it represents for SWAN:** The boundary between "shelf" and "slope" polygons marks where the flat continental shelf transitions to the steep continental slope. This IS where WW3's deep-water assumptions start failing — the physical transition from deep water (WW3's domain) to depth-dependent wave physics (SWAN's domain).

**Query at wizard time:** Extract the outer boundary of GSFM "shelf" polygons as a polyline. Given a spot coordinate, find the nearest point on that polyline → distance = offshore extent needed for the SWAN coarse grid.

**Ships with API:** Pre-processed shelf boundary polyline, ~10-20 MB. Static file, no API queries needed, works offline, instant computation.

### Level 1: Coarse grid (SETTLED)

| Property | Value |
|---|---|
| **Purpose** | Propagate waves from WW3 boundary across continental shelf to nearshore |
| **Resolution** | 1 km |
| **Domain sizing** | Lateral: all spots extent + 5 km margin each side. Offshore: spot to GSFM shelf boundary + 10 km margin into deep water. |
| **Cell count** | Varies by shelf width — see table below |
| **Runtime (6 cores)** | Under 3 min everywhere |
| **Bathymetry source** | GEBCO at 450m (global) or CUDEM at 1km (US) |

**Calibration point:** The current (oversized) outer grid is 195 km × 230 km at 3 km = ~5,000 cells and takes 2-3 minutes on 6 cores.

**Cell count estimates by shelf width:**

| Location type | Shelf width | Grid dimensions | Cells | Est. runtime (6 cores) |
|---|---|---|---|---|
| Narrow shelf (Hawaii) | 1-2 km | 30 × 12 km | ~360 | seconds |
| SoCal (this operator) | 15-30 km | 30 × 30 km | ~900 | ~30 sec |
| Average global shelf | ~70 km | 30 × 80 km | ~2,400 | ~1.2 min |
| Wide shelf (East Coast US) | 100-150 km | 30 × 160 km | ~4,800 | ~2.5 min |

**Conclusion:** The coarse grid is computationally trivial for all realistic scenarios. Even the worst case (wide shelf) is under 5,000 cells and 3 minutes. No operator will realistically hit a compute limit at this level. A soft warning at ~8,000 cells is generous — operators would need extreme spot spread AND a wide shelf to approach it.

**SoCal worked example (Sunset Beach to The Wedge):**
- Spots span ~20 km of coast (33.72°N/118.08°W to 33.59°N/117.88°W)
- Shelf break ~20 km offshore (San Pedro shelf edge)
- Grid: 30 km × 30 km at 1 km = 900 cells
- Compare to current: 5,000 cells covering 195 × 230 km of mostly irrelevant deep ocean

### Level 2: Nearshore grid (TO BE DESIGNED)

| Property | Preliminary |
|---|---|
| **Purpose** | Resolve bathymetric refraction, shoaling, nearshore features (canyons, reefs) |
| **Resolution** | 100 m (TBD) |
| **Domain sizing** | TBD — covers all spots, extends from coast to ??? km offshore |
| **Bathymetry source** | CUDEM at 100m (US) or GEBCO at 450m (international) |

### Level 3: Surf zone grid (SETTLED)

| Property | Value |
|---|---|
| **Purpose** | Resolve breaking, sandbars, pier shadow, wave setup, beach profile transect |
| **Resolution** | 10 m |
| **Domain sizing** | Per spot: 500m alongshore (250m each side of pin) × ~1 km cross-shore (shore to 15m depth) |
| **Cell count** | 50 × 100 = ~5,000 cells per isolated spot |
| **Runtime (6 cores)** | ~4 min per grid (at 0.05 sec/cell empirical rate) |
| **Bathymetry source** | CUDEM at native 3.4m resolution, averaged to 10m grid (US). GEBCO 450m interpolated (international — reduced accuracy). |
| **Grid assignment** | Adjacent spots merge into shared grids (see de-duplication below). Grids run sequentially. |

**Why 10m resolution (not 25m):**

| Feature | Size | At 25m | At 10m |
|---|---|---|---|
| Sandbar width | 20-50m | 1-2 cells (unresolved) | 2-5 cells ✓ |
| Breaking detection | need 3-4 cells across surf zone | 4-8 cells ✓ | 10-20 cells ✓✓ |
| Pier/structure shadow | 50-100m | 2-4 cells (marginal) | 5-10 cells ✓ |

25m cannot resolve individual sandbars. Since sandbar resolution is the primary motivation for the fine grid (it's what the 3km-interpolated inner grid was missing), 10m is required.

**Why 15m depth for the offshore boundary (DECIDED):**

Three independent lines of evidence converge on 8-10m as the depth where fine-scale features (sandbars, active morphology) exist. The 15m boundary provides a buffer above this.

| Source | Finding |
|---|---|
| Hallermeier (1981) depth of closure, SoCal wave climate | h_in = 8.9 × H̄_s ≈ **8-9m** |
| Ludka et al. (2019) — 16 years of San Diego beach surveys | Active morphological zone: shore to **8m depth** |
| Coastal Wiki — Egmond outer bar decay | Outer bar decays at **8m depth** |
| Standard SWAN practice for surf zone boundary | **10-30m** water depth |
| XBeach default tutorial (Holland coast) | Offshore boundary at **20m depth** |

We use 15m: safely beyond the depth of closure (8-9m), provides full beach profile context, and aligns with the mid-range of published practice (10-30m).

**Why 250m each side alongshore (DECIDED):**

The surf zone wave transformation is fundamentally a **cross-shore process** — waves approach from offshore, shoal, and break. Alongshore effects (diffraction, lateral spreading) are secondary.

Key evidence:
- **XBeach** (standard surf zone model) uses **1D mode (zero alongshore extent) as its default** for the Holland coast tutorial. If the primary surf zone model produces useful results with no alongshore dimension, it demonstrates that cross-shore physics dominates.
- **No published paper or the SWAN user manual specifies a minimum alongshore extent** for a nested fine grid with spectral boundary conditions from a coarser level.
- In a **nested setup**, Level 2 provides physically correct spectral boundary conditions at Level 3's lateral edges — these are not artificial walls. Waves from all angles are correctly specified at the boundary.
- Level 3 only ADDS fine-scale bathymetric detail (sandbars, 10m-scale features) that Level 2 at 100m cannot see. These features are **inherently local** — a sandbar affects breaking directly above it, not 500m down the beach.
- Sandbar features (crescentic bars, bar gaps, rip channels) have typical **alongshore scales of 100-400m**. 500m total (250m each side) captures one complete bar system plus transitions.

The grid is sized **proportionally**: ~1 km cross-shore (to 15m depth where features exist) and ~500m alongshore (to capture the local feature scale). The cross-shore dimension is larger because depth increases with distance — the grid must reach 15m. The alongshore dimension only needs to contain the local bar system.

**Compute validation:**
- Empirical calibration: current system runs ~10,000-13,000 cells (both grids) in ~9 minutes on 6 cores
- Per-cell cost: 540 sec / ~10,000 cells = **~0.05 sec/cell** for a full 72h nonstationary run
- Level 3 at 5,000 cells: 5,000 × 0.05 = 250 sec ≈ **4 minutes per spot** ✓
- For 7 spots (sequential): 7 × 4 = 28 minutes. Exceeds 15-min budget — see scheduling note below.

**Level 3 grid de-duplication (DECIDED):**

SWAN has no knowledge of other grids at the same nesting level. Two overlapping Level 3 grids would compute overlapping cells twice independently. To avoid this, adjacent spots MERGE into a single shared Level 3 grid.

**Merge rule:** If two adjacent spots (sorted along the coast) are within 500m of each other (pin-to-pin), they share one Level 3 grid. The merged grid extends from 250m before the first pin to 250m after the last pin in the cluster.

**Why this works physically:** Waves propagating between closely-spaced spots (e.g., pier break and a bar break 300m down the beach) are correctly modeled within one continuous domain. Separate grids would split this interaction across two independent solutions.

**Algorithm at SWAN run time:**
1. Sort all spot pins by position along the coast
2. Walk the sorted list — group consecutive spots where pin-to-pin distance < 500m
3. Each cluster becomes one Level 3 grid: 250m before first pin → 250m after last pin × 1 km cross-shore
4. Isolated spots (>500m from any neighbor) get their own 500m × 1km grid

**Example — operator with 7 spots, some clustered:**

| Cluster | Spots | Grid width | Cells | Runtime |
|---|---|---|---|---|
| A | HB Pier + Pier South (200m apart) | 700m | 7,000 | ~6 min |
| B | Bolsa Chica (isolated) | 500m | 5,000 | ~4 min |
| C | 56th St + River Jetties + Wedge (each ~400m apart) | 1,300m | 13,000 | ~11 min |

Total Level 3: 3 SWAN runs, 25,000 cells, ~21 min (vs. 7 separate runs × 5,000 = 35,000 cells, ~28 min). Merging saves ~7 min and eliminates 4 SWAN process invocations.

**Scheduling consideration:** Even with merging, many-spot operators may exceed 15 minutes for Level 3. Options:
1. Run fewer spots per cycle (rotate clusters across cycles)
2. Accept longer total runtime for operators with many spots (relax 15-min budget)
3. Run Level 3 stationary (cheaper — each hour solved independently, not time-stepped)
4. Reduce forecast horizon for Level 3 (e.g., 24h instead of 72h — surfers mostly care about today/tomorrow)

This is a scheduling/product decision, not a physics constraint. The per-grid compute is within budget.

### Level 2: Nearshore grid (SETTLED)

| Property | Value |
|---|---|
| **Purpose** | Bridge 1km coarse grid to 10m fine grid. Resolve bathymetric refraction at 100m scale (rocky reefs, outcrops, shelf features in the 15-30m depth zone). |
| **Resolution** | 100 m |
| **Domain sizing** | Lateral: all spots extent + 1-2 km margin each side. Offshore: shore to 30m depth. One shared grid for all spots. |
| **Cell count** | Varies — SoCal example: 22 km × 4 km at 100m = 220 × 40 = ~8,800 cells |
| **Runtime (6 cores)** | ~7.5 min (SoCal example) |
| **Bathymetry source** | CUDEM at 100m (US) or GEBCO at 450m (international — meets resolution) |

**Why 30m depth for the offshore boundary (DECIDED):**

The question: at what depth do 100m-scale seafloor features stop existing (and therefore stop affecting waves)? Independent evidence from marine ecology and wave modeling converge on 30m:

| Source | Finding |
|---|---|
| SCCWRP Bight '13 — SoCal rocky reef monitoring | "Shallow" rocky reef habitat defined as **0-30m**. 119 reefs, ~49,055 hectares. Sampling strata: inner <5m, middle ~10m, outer ~15m, deep ~25m. |
| California Sea Grant — reef classification | "Mid-depth" reef starts at **30m (100 ft)**. Described as separate ecosystem from nearshore — larger-scale, sparser features. |
| USGS California wave model | Defines "nearshore" as the **20m depth contour**. High-res grids operate landward of this. |
| SWAN modeling practice | Offshore boundary at **20-30m** common for nearshore grids with 30-100m resolution. |

Below 30m: features transition to "mid-depth" scale (200m-1km+), which Level 1 at 1km resolution handles adequately. The 30m boundary is not arbitrary — it's where the physical character of the seafloor changes from complex nearshore structure to smoother mid-shelf sediment.

**SoCal worked example:**
- 30m depth is approximately 3-4 km offshore at Huntington Beach
- Level 2 grid: 22 km lateral (all spots + margins) × 4 km cross-shore = 8,800 cells
- Level 2 is the computational bottleneck (~7.5 min), but within budget

### Wizard/admin compute calculator (DECIDED)

Instead of imposing hard limits on spot count or bbox size, the wizard/admin shows a **before/after compute estimate** as the operator adds, moves, or removes spots. The operator sees the cost of each action and makes their own informed tradeoff.

**Display:** A table showing estimated runtime before and after the pending change:

| | Before | After | Delta |
|---|---|---|---|
| Level 1 (coarse) | 30 sec | 30 sec | — |
| Level 2 (nearshore) | 7.5 min | 7.5 min | — |
| Level 3 (surf zone) | 10 min (2 grids) | 11.5 min (2 grids) | +1.5 min |
| **Total full run** | **18 min** | **19.5 min** | **+1.5 min** |

**Key insight for the operator:** Spots don't have equal cost.
- Adding a spot that merges into an existing cluster: CHEAP (extends the grid marginally, no new SWAN invocation). e.g., "+2,000 cells, +1.5 min"
- Adding an isolated spot: EXPENSIVE (creates a new 5,000-cell grid + new SWAN process). e.g., "+5,000 cells, +4 min"

This naturally guides operators toward efficient configurations (clustered spots) without imposing arbitrary rules.

**Calculator inputs (all available at wizard time):**
- Spot positions → clustering algorithm determines grid count and sizes
- GSFM shelf distance → Level 1 offshore extent
- Shore-to-30m distance (from GEBCO point query or shelf slope estimate) → Level 2 cross-shore extent
- Operator's configured core count → scales the per-cell cost (0.05 sec/cell at 6 cores, linear scaling)

**Scaling formula:** `estimated_runtime = total_cells × (0.05 / (cores / 6))` seconds for the full 72h run.

### Scheduling model (DECIDED)

Full runs happen 2-4× per day (operator choice). Quick updates run hourly. The compute calculator shows per-run cost; operator picks frequency.

| Run type | Frequency | What runs | Cost (7 spots, SoCal) |
|---|---|---|---|
| Full run | 2-4× daily (operator choice) | All 3 levels, 72h nonstationary | ~29 min |
| Quick update | Hourly | Level 3 only, stationary (latest wind from most recent full run) | ~1-2 min |

- **4× daily** (every 6h, aligned with HRRR extended cycles 00/06/12/18Z) — best accuracy, matches wind data availability
- **2× daily** (every 12h) — half the compute, minimum recommended for accuracy
- Quick updates are always hourly and cheap — no operator configuration needed

No rotation, reduced-horizon, or other complexity. The operator sees the cost and picks their frequency.

### Resolved questions (no longer open)

1. ~~Level 3 scheduling~~ — **Resolved:** Operator chooses 2-4 full runs/day via the compute calculator. Quick updates always hourly (cheap, stationary Level 3 only).
2. ~~International bathymetry~~ — **Deferred:** Product is US-only (CUDEM-covered) for v1. Other international data sources need work regardless of bathymetry (providers, tide data, etc.). GEBCO question revisited when international scope opens.
3. ~~Nesting ratio validation~~ — **Deferred to implementation:** Must build and run to test. Verify that spectral transfer at 10× ratios produces clean results. Not a design decision — a verification step.

---

## §6 — Fixes Already Completed (Session 1)

| Fix | Commit | What |
|---|---|---|
| HOTFILE bootstrap | fa74965 | HOTFILE always written — hotstart chain bootstraps on first run |
| Quick update crash | 492c3ed | grid_info referenced before assignment (UTM regression) |
| Bidirectional transect | 77c7bdc | CUDEM profile from coastline to deep water, not just offshore from pin |
| Scoring: biggest break | 0cfb9db | Reference point = offshore of highest QB×waveHeight peak |
| Dead code removal | fd0a0f6 | Wizard bathymetry endpoint, BathymetryPoint moved to bathymetry.py |
| IQR smoothing removed | 66e5cae | CUDEM data used as-is per NOAA QA/QC |
| Hotstart crash retry | 66e5cae | If SWAN crashes with hotstart, delete and retry cold |
| Coastline detection | 5646869 | depth <= 0 instead of depth == 0 |
| CURVE uses runtime profile | 9da62d4 | build_swan_input() was using old bathymetric_profile key |
| Max points uncapped | eaf34c2 | max_points raised from 20 to 200 |
| Tide label clipping | fe3b5ed | TideChart margin.top 12→36 |
| Beach profile card | 95621d9+ | 3-tier X-axis scale, Y-axis labels, break markers, tidal shoreline, unit-neutral |
| Marine map bounds | 5adfd08 | Pixel padding instead of degree inflation |
| Marine card spacing | 00b02aa | Map wrapper bottom margin |
| api.conf [trushore]→[swan] | config fix | omp_num_threads=6→16 now visible |

### Known remaining issues:
- **Inner grid bathymetry at 3km** — the primary unresolved issue, requires nesting redesign
- **Beach profile API unit conversion** — distance/depth hardcoded in meters, should use operator's configured units (Phase 9 in plan)
- **Marine summary waterTemp null for Huntington Harbor** — OFS resolver wired in detail endpoint but may not cache for non-surf locations
- **NDBC station prjc1 inactive** — wizard configured an inactive station; wizard should filter to active-only
- **Hotstart files not portable across OMP thread count changes** — detected during testing, mitigated by crash-retry logic

---

## §7 — Sources

- Harris, P.T. & Macmillan-Lawler, M. (2014), *Geomorphology of the oceans*, Marine Geology, 352, pp. 4-24 — the GSFM dataset paper. Download: https://bluehabitats.org/?page_id=58 (389 MB shapefile archive). Also: https://researchdata.edu.au/digital-seafloor-geomorphic-global-ocean/3962960
- Hallermeier, R.J. (1981), *A profile zonation for seasonal sand beaches from wave climate*, Coastal Engineering, 4, pp. 253-277 — depth of closure formula. Simplified by Houston (1995): h_in = 8.9 × H̄_s. SoCal (H̄_s ≈ 1.0m) → closure depth ~8-9m. See: https://www.coastalwiki.org/wiki/Closure_depth
- Ludka, B.C. et al. (2019), *Sixteen years of bathymetry and waves at San Diego beaches*, Scientific Data, 6, 161 — 16 years of quarterly surveys to 8m depth at 3 SoCal beaches. Confirms active morphological zone ends at ~8m. https://pmc.ncbi.nlm.nih.gov/articles/PMC6715754/
- XBeach development team, *XBeach Holland Default tutorial* — standard surf zone model uses 1D (cross-shore only) as default mode. Offshore boundary at 20m depth. Demonstrates surf zone physics is fundamentally cross-shore. https://xbeach.readthedocs.io/en/stable/tutorials/holland_default.html
- Zijlema (2021), *Parallel Computing Efficiency of SWAN 40.91*, Geoscientific Model Development — https://gmd.copernicus.org/articles/14/4241/2021/
- Rogers et al. (2007), *Forecasting and hindcasting waves with the SWAN model in the Southern California Bight*, Coastal Engineering
- Kumar et al. (2015), *Midshelf to Surfzone Coupled ROMS–SWAN*, J. Physical Oceanography
- Carignan et al. (2023), *Continuously Updated Digital Elevation Models (CUDEMs)*, Remote Sensing — https://www.mdpi.com/2072-4292/15/6/1702
- SWAN User Manual v41.51 — https://swanmodel.sourceforge.io/download/zip/swanuse.pdf
- COMARGE Continental Margins (IFREMER, 2009) — http://geonode.iwlearn.org/layers/Marine_Regions_web_services:comarge (REJECTED — fixed 140m isobath, traces canyons; see §4 for rationale)
- GEBCO API — https://www.sciencedirect.com/science/article/pii/S2665963826000291
- GEBCO Web Services — https://www.gebco.net/data-products/gebco-web-services
- Marine Regions Downloads — https://marineregions.org/downloads.php
