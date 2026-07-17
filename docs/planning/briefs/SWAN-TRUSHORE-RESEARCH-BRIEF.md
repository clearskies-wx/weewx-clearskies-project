# Research Brief: SWAN + TruShore Nearshore Wave Model

**Date:** 2026-07-16
**Purpose:** Document all technical research findings supporting the decision to run our own SWAN nearshore wave model (TruShore) instead of depending on NOAA's NWPS service for surf forecasting data
**Status:** Research complete — informs SWAN-TRUSHORE-PLAN.md
**Companion:** [SWAN-TRUSHORE-PLAN.md](../SWAN-TRUSHORE-PLAN.md) — implementation plan

---

## §1 — Problem Statement

### Current Architecture

The surf endpoint's data pipeline is:

```
NWPS (nearshore, ~1km) → if 404 → WaveWatch III (offshore, ~50km)
         ↓                                      ↓
  wave_transform.py                  wave_transform.py (no-op)
  (supplements applied)              (supplements skipped)
         ↓                                      ↓
   surf_scorer.py ←────────────────── surf_scorer.py
```

### Three Compounding Failures

**Failure 1 — NWPS operational model is not designed for consumer products.**

NWPS (Nearshore Wave Prediction System) is an NWS tool for forecasters, not a public data service. Its run schedule is driven by when WFO forecasters submit edited wind grids to NOMADS, which happens 2–8 times per day with no fixed schedule. There is no guaranteed 00Z, 06Z, 12Z, 18Z pattern. When a cycle has not yet posted, NOMADS returns HTTP 404. This is by design — the system is gated on human forecaster input, not a clock.

**Failure 2 — Our cache TTL destroys valid data on fetch failure.**

The current NWPS cache TTL is 1800 seconds (30 minutes). When a 30-minute cycle fires and NWPS returns 404 (no new cycle posted), the cache TTL expires and valid data from the previous successful fetch is discarded. The surf endpoint then falls back to WaveWatch III until the next successful NWPS fetch. The fallback is not a graceful degradation — it is a step change from ~1km nearshore physics to ~50km offshore averages.

**Failure 3 — WaveWatch III is inadequate for surf forecasting.**

WaveWatch III is a deep-water global wave model at 0.5° (~50km) resolution. It has no nearshore physics: no bathymetric refraction, no shoaling (wave height increasing as depth decreases), no wave breaking, no coastal structure interaction. Research confirmed that no commercial surf provider uses WaveWatch III directly for consumer surf forecasts. The Surfline, MSW, and SwellWatch product chains all run WaveWatch III outputs through a proprietary nearshore transformation engine before publishing forecasts.

On WaveWatch III fallback: the surf endpoint returns the same WaveWatch III value for all 144 forecast timesteps (the model value at the nearest 0.5° grid cell, unchanged by time). Data quality collapses — a user viewing the 72-hour surf forecast sees a flat line. The wave_transform.py supplements that compute breaker corrections, structure effects, and topographic focusing are all skipped because they depend on nearshore data that WaveWatch III cannot provide.

---

## §2 — SWAN Model Assessment

### What SWAN Is

SWAN (Simulating WAves Nearshore) is the open-source spectral wave model maintained by Delft University of Technology. It solves the wave action balance equation across a user-defined bathymetric grid, computing how waves propagate, refract, shoal, break, and interact with currents as they enter shallow water.

NWPS IS SWAN: the NOAA Nearshore Wave Prediction System runs SWAN as its computational core, driven by forecaster-edited wind grids on NWS operational infrastructure. When we run our own SWAN instance with equivalent inputs, we get the same physics as NWPS, on our schedule, with guaranteed availability.

The only things NWPS provides that a standalone SWAN cannot are:
1. Forecaster-edited wind grids (addressed in §4)
2. Operational infrastructure across 36 WFOs (irrelevant — we serve our specific location)

SWAN license: open-source, free to use, well-documented. Available from `swanmodel.sourceforge.io`.

### Compute Requirements

SWAN memory and runtime are driven by total grid points (domain extent ÷ resolution) multiplied by spectral bins (typically 36 directions × 31 frequencies = 1,116 bins). Each grid point stores approximately 16 bytes per spectral bin across internal working arrays.

**Memory formula (approximate):**

```
Memory (MB) ≈ grid_points × 1,116 × 16 / 1,000,000
```

| Grid points | Approx. memory |
|---|---|
| 5,000 | ~90 MB |
| 10,000 | ~180 MB |
| 25,000 | ~450 MB |
| 100,000 | ~1.8 GB |
| 250,000 | ~4.5 GB |

**CORRECTION (2026-07-17):** The original brief estimated 100–300 MB for a "30km × 15km, 200m resolution" domain. This estimate was never validated. A 30km × 15km domain at 200m resolution produces 150 × 75 = 11,250 grid points × 1,116 spectral bins × 16 bytes ≈ 200 MB. That particular domain size happens to fit. However, the plan (SWAN-TRUSHORE-PLAN.md) specified a ±0.5° domain around surf locations (~110km × 110km at 200m = 257,000 grid points ≈ 4.5 GB), which vastly exceeds the brief's estimate. The mismatch was not caught until the production deployment on 2026-07-17 crashed with an OOM kill on a 1.9 GB host.

### Grid Configuration: Nested Grids (Standard Practice)

**No operational nearshore wave forecast system runs fine resolution over the entire domain.** Every operational system uses nested grids: a coarse outer grid for wave propagation across the continental shelf, and a fine inner grid focused on the nearshore area of interest.

**NWPS SGX (San Diego WFO) — actual configuration from [NOAA-EMC/nwps](https://github.com/NOAA-EMC/nwps) source code:**

| Level | Resolution | Domain | Extent | Grid points |
|---|---|---|---|---|
| CG1 (outer) | 2.0 arc-min (~3.6 km) | 32.08–33.82°N, 119.00–116.50°W | ~193 km × 230 km | ~3,900 |
| CG2 (inner nest) | 0.125 arc-min (~230m) | 32.68–32.89°N, 117.34–117.24°W | ~23 km × 9 km | ~4,800 |
| **Total** | | | | **~8,700** |

The inner nest covers only the coastline of interest at fine resolution. The outer grid handles deep-water-to-shelf wave propagation at coarse resolution. SWAN natively supports this: the outer run completes first, then the inner run uses the outer's output as boundary conditions.

**Estimated memory: ~160 MB total for both grids combined.**

**Other operational systems:**

| System | Approach | Nearshore resolution | Forecast length |
|---|---|---|---|
| NWPS SGX | 2-level regular nested grid | ~230m | GFS wind, 180 hours |
| PacIOOS Oahu | Single grid, WW3 boundary | ~500m | 5 days (120 hours) |
| Rogers 2007 SoCal | 3-level nested grid | ~45m (finest) | Research hindcast |
| USGS CoSMoS SoCal | 3-level nested (1km → 200m → 40m) | 40m (finest) | Storm event |

**Key findings:**
- The nesting ratio (resolution step between levels) should not exceed 3–5x per level for numerical stability (multiple sources). NWPS SGX uses ~16:1 in a single step; published research typically uses 3–5x per step with 2–3 nesting levels.
- Published finding: "a uniform 40m resolution led to unacceptable memory requirements of 4 GB" — confirming that fine resolution over large areas is not viable without nesting.
- PacIOOS runs operational 5-day forecasts at 500m on standard infrastructure, with WW3 at 5km providing boundary conditions. This is a proven operational configuration.

**Wind forcing and forecast length:**

NWPS uses GFS wind forcing (not HRRR), which extends to 180 hours (7.5 days). HRRR provides higher resolution (3km vs GFS's 25km) but only extends to 18 or 48 hours depending on the cycle (4 extended cycles per day at 00/06/12/18Z reach 48h; the other 20 hourly cycles reach only 18h). To produce a 72-hour surf forecast, either GFS wind must be used for the extended range (hours 48–72), or HRRR data from multiple cycles must be stitched together.

**Cited sources:**
- NWPS SGX domain config: https://github.com/NOAA-EMC/nwps (fix/domains/SGX, fix/configs/sgx_ncep_config.sh)
- SWAN parallel computing efficiency: Zijlema (2021), *Parallel Computing Efficiency of SWAN 40.91*, Geoscientific Model Development — https://gmd.copernicus.org/articles/14/4241/2021/
- PacIOOS Oahu operational forecast: https://www.pacioos.hawaii.edu/waves/model-oahu/
- Rogers et al. (2007), *Forecasting and hindcasting waves with the SWAN model in the Southern California Bight*, Coastal Engineering — https://falk.ucsd.edu/seminar/Rogers2007CoastalEng.pdf
- NWPS operational deployment: NWPS-WCOSS Pre-Kickoff Presentation, NCEP/EMC, 2014

### TruShore Grid Configuration (Revised)

Based on the operational research above, TruShore should use a two-level nested grid approach:

**Level 1 — Outer grid (shelf-to-shore wave propagation):**
- Resolution: ~2–3 km (matches NWPS CG1 pattern)
- Domain: covers the full continental shelf approach for the configured coast (~200km alongshore × 150km offshore)
- Purpose: propagates deep-water WW3 swell across the shelf with bathymetric refraction, bottom friction, and wind-wave growth
- Grid points: ~5,000–8,000
- Memory: ~100–150 MB

**Level 2 — Inner nest (spot-specific nearshore resolution):**
- Resolution: 200–500m (matches NWPS CG2 and USGS CoSMoS intermediate grids)
- Domain: tight around each configured surf location (~20–30 km alongshore × 10–15 km offshore)
- Purpose: resolves coastal features (jetties, piers, headlands, reefs, sandbars) that make each surf spot different
- Grid points: ~3,000–8,000
- Memory: ~50–150 MB

**Total: ~8,000–16,000 grid points, ~200–300 MB memory.** Fits on the weewx host alongside the API, MariaDB, Redis, and weewx.

### Multi-Spot Efficiency

Multiple surf spots on the same coastline share the outer grid. Each spot (or cluster of nearby spots) gets its own inner nest, using the outer grid's output as boundary conditions. The compute cost scales with the number of distinct inner nests, not the number of spots — 5 spots within one 20km nest cost the same as 1 spot.

---

## §3 — Input Data Inventory

### What We Have vs. What We Need

| Component | NWPS uses | We have | Gap |
|---|---|---|---|
| Wave physics engine | SWAN (Fortran) | Not installed | Install open-source Fortran package |
| Deep-water boundary conditions | WaveWatch III operational | WaveWatch III via THREDDS/ERDDAP (already fetching in `providers/marine/wavewatch.py`) | None |
| Bathymetry | NCEP coastal DEMs (CUDEM) | NCEI ArcGIS ImageServer downloads (already implemented in `enrichment/bathymetry.py`) | None |
| Tidal currents | ESTOFS/RTOFS ocean model | OFS models (already using in `providers/ocean/ofs.py` for water temp) | None |
| Shoreline geometry | NOAA coastal survey | Same public data | One-time download per domain |
| Wind forcing | Forecaster-edited HRRR/NAM at 5km (NDFD) | HRRR at 3km via NOMADS (need to add) | New wind provider + GRIB2 → SWAN format conversion |
| Structure physics | None (NWPS has no structure awareness) | `enrichment/wave_transform.py` (built and deployed) | Wire SWAN output as input to wave_transform |

### What We Already Have

The implementation cost of a standalone SWAN pipeline is lower than it appears because the Clear Skies codebase already provides most of the non-SWAN components:

- **WaveWatch III fetch** (`providers/marine/wavewatch.py`): ERDDAP access already implemented. This becomes the boundary condition input to SWAN — the same data, used differently.
- **CUDEM bathymetry** (`enrichment/bathymetry.py`): NCEI ArcGIS ImageServer access already working. This becomes the SWAN grid bathymetry input.
- **OFS ocean currents** (`providers/ocean/ofs.py`): Already fetching RTOFS/ESTOFS for water temperature. RTOFS current output becomes the wave-current interaction input for SWAN.
- **Wave transform supplements** (`enrichment/wave_transform.py`): All four supplements (breaker index correction, structure effects, spatial interpolation, topographic focusing) already coded. These run on SWAN output instead of NWPS output without modification.
- **Surf scorer** (`enrichment/surf_scorer.py`): Scoring engine complete. Receives wave height/period/direction regardless of source.

The only net-new component is: SWAN binary + a runner service that writes SWAN input files and parses its output.

---

## §4 — Wind Forcing: HRRR vs. Forecaster-Edited Grids

### What Forecasters Do to Wind Grids

NWS forecasters use the Graphical Forecast Editor (GFE) with the Smart Init tool. Smart Init downscales from NWP model output (NAM 12km, HRRR 3km, GFS, RTMA 2.5km) to the NDFD 5km grid. Forecasters then manually edit the interpolated grid, drawing wind patterns based on local knowledge (sea breezes, gap flows, topographic channeling, thermal gradients near the coast).

The NWS wind product that NWPS consumes is this 5km forecaster-edited grid, not raw HRRR output.

### Published Evidence on Forecaster Value-Add

No published study directly compares SWAN output driven by forecaster-edited winds versus raw HRRR winds at surf forecast resolution. This is a gap in the open literature. The following evidence is the closest available:

**HRRR coastal wind accuracy:**
- Median wind speed error under 1 m/s at California coastal sites (Wind Energy Science, 2025)
- HRRR at 3km resolution is FINER than the NDFD grid (5km) that forecasters start from before editing

**Error propagation to waves:**
- Wind-to-wave error amplification: approximately 1.5–2× (1 m/s wind error produces 0.1–0.3 m wave height error in empirical relationships)

**Forecaster value-add research:**
- Baars & Mass (2005): Human-edited forecasts perform comparably to model output for routine weather
- Cliff Mass (2018): Modern NWP guidance matches or exceeds human-edited forecasts for standard conditions
- Marine/coastal exception: Sea breezes, gap winds, and topographic channeling are cases where forecasters may still add value. No quantitative study was found that isolates these effects for surf wave prediction specifically.

**Estimated forecaster impact on wave forecast quality:**
| Conditions | Estimated RMSE reduction from editing |
|---|---|
| Routine swell, calm weather | 0–5% |
| Standard windy conditions | 5–15% |
| Extreme events (storms, gales) | 15–25% |

These are professional estimates, not measurements. No peer-reviewed study quantifies this specific comparison.

**Industry practice:**
- Surfline runs its own numerical model (LOTUS) driven by raw NWP output. No forecaster editing in the Surfline chain.
- MSW (MagicSeaweed), WindGuru, SwellWatch: all run raw NWP → proprietary nearshore transformation. None use NDFD forecaster-edited winds.
- No commercial surf forecast provider was found that uses forecaster-edited NDFD winds as SWAN input.

**Conclusion:** HRRR at 3km is a better starting point than the 5km NDFD grid that forecasters edit from. Forecaster editing adds marginal value for routine conditions; it may matter more for coastal meteorological phenomena that require local knowledge. For automated consumer surf forecasting, raw HRRR is the industry standard.

### HRRR Data Access

**NOMADS Grib Filter (primary):**
```
https://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_2d.pl
```
Supports geographic subsetting (bounding box), variable selection (U/V at 10m AGL), and GRIB2 output. Free, no API key required.

**AWS S3 (backup and archive):**
```
s3://noaa-hrrr-bdp-pds/
```
Same data, hosted by Amazon as a public dataset. Requires boto3 or S3-compatible client. Useful for backfill and validation.

**Schedule:** HRRR runs on a fixed hourly schedule (00Z through 23Z). Availability: ~45–60 minutes after the nominal run hour. Completely predictable — no dependency on human forecaster input.

**Critical preprocessing step: grid-relative to earth-relative wind rotation**

HRRR uses a Lambert Conformal Conic projection. Wind components in GRIB2 files are grid-relative (U positive = East along the grid's X axis, not geographic East). Before passing winds to SWAN, they must be rotated to earth-relative (U = geographic East, V = geographic North):

```
wgrib2 hrrr.grib2 -new_grid_winds earth -grib hrrr_earthrel.grib2
```

Or using the equivalent Python rotation formula from the Lambert Conformal grid parameters. Skipping this step produces SWAN wind inputs that are systematically wrong by up to ~20° near the domain boundaries.

### HRRR Forecast Range Limitation (Added 2026-07-17)

HRRR does not produce a consistent forecast range. NCEP runs HRRR every hour, but allocates different forecast lengths depending on the cycle:

| Cycle times (UTC) | Forecast range | Hourly wind grids available |
|---|---|---|
| 00Z, 06Z, 12Z, 18Z (4 per day) | 48 hours | f00–f48 (49 grids) |
| All other hours (20 per day) | 18 hours | f00–f18 (19 grids) |

This is an NCEP resource allocation decision — the 48-hour runs require more compute time, so only the 4 synoptic cycles get the extended range.

**Impact on TruShore:** The dashboard displays a 72-hour surf forecast card. HRRR alone cannot fill this — even the extended cycles only reach 48 hours. The previous system (NWPS) used GFS wind forcing, which extends to 384 hours (16 days). GFS is coarser than HRRR (0.25° / ~25km vs. HRRR's 3km), but it provided the forecast range needed for 72+ hour surf forecasts.

**Required solution:** TruShore needs a blended wind forcing approach:
- **Hours 0–48:** HRRR wind at 3km resolution (high quality, available from extended cycles)
- **Hours 48–72:** GFS wind at 0.25° resolution (coarser but covers the required range)

This requires a GFS wind provider module (`providers/wind/gfs.py`) that fetches GFS forecast data from NOMADS, with the SWAN runner stitching HRRR and GFS wind grids together at the 48-hour boundary. The wind resolution transition at hour 48 does not affect SWAN's nearshore physics — wave refraction, shoaling, and breaking are computed at the SWAN grid resolution (200–500m), not the wind grid resolution.

Alternatively, GFS wind could be used for the entire 72-hour range (simpler, matches NWPS's approach), accepting coarser wind for the first 48 hours. The wave physics improvement from HRRR's 3km vs. GFS's 25km may be marginal for swell-dominated conditions where the wave field is driven by remote storms, not local wind.

---

## §5 — Industry Practice: How Others Handle NWPS Outages

No commercial surf forecast product depends on NWPS. This is the most important finding from the industry research.

| Provider | Wave model | Dependency on NWPS | Fallback strategy |
|---|---|---|---|
| Surfline | LOTUS (proprietary NWP-to-nearshore) | None | N/A — LOTUS runs on schedule |
| MSW (MagicSeaweed) | WW3 → proprietary nearshore | None | Cache last successful run per spot |
| WindGuru | GFS/ECMWF → proprietary model | None | Cache last successful run |
| SwellWatch | WW3 → proprietary nearshore | None | Cache last successful run |
| **Clear Skies (current)** | NWPS → WW3 fallback | **Yes — single point of failure** | WW3 (inadequate for surf) |

**Universal fallback pattern:** When a nearshore model run fails or is stale, every commercial provider caches and serves the last successful run. Stale high-resolution nearshore data is always preferred over fresh low-resolution offshore data for swell-dominated coasts. A 12-hour-old SWAN forecast with nearshore physics is more accurate for a surf forecast than a fresh 50km WaveWatch III grid cell average.

**NWPS primary purpose:** NWPS is built for NWS forecasters to produce official marine text forecasts and coastal inundation guidance. It is not designed or marketed as a public data service for consumer applications. Using it as the primary data source for a commercial-facing surf product creates a dependency on a service that was never intended for this purpose.

---

## §6 — Architecture Decision: Bundled Integration with Optional Separation

### Default: Bundled in the API

SWAN runs as a subprocess within the API process. The API spawns the SWAN binary, waits for it to complete (2–10 minutes), and reads the output files. This is the same pattern used by wgrib2 — an external binary called from Python.

**pip extra:** `pip install weewx-clearskies-api[nearshore]`

This extra installs: SWAN binary (or Fortran compilation toolchain), wgrib2, cfgrib/xarray for GRIB2 processing, and the `services/swan_runner.py` module. The extra is optional — operators who do not need surf forecasting install the base package without SWAN.

**Config key:**
```
[marine]
nearshore_model = trushore   # default when [nearshore] extra installed
# nearshore_model = nwps     # legacy (NWPS-dependent)
# nearshore_model = none     # surf forecasting disabled
```

### Optional: Separated Service

Some operators may want to run SWAN on dedicated hardware (a more powerful machine, a cloud VM) rather than on the weewx host. This is supported via a separate pip package and a configurable endpoint.

**Separate package:** `weewx-clearskies-trushore`

A standalone systemd service that:
1. Runs SWAN on schedule (hourly, matching HRRR cycle cadence)
2. Publishes results to Redis (or an HTTP endpoint the API polls)

**API config for remote TruShore:**
```
[marine]
nearshore_model = trushore
[trushore]
service_url = http://localhost:trushore  # default: local; change to remote machine IP/hostname
```

When `service_url` points to a remote host, the API disables its local SWAN runner and reads TruShore results from the remote service using the same cache key and data format.

**Operational note:** The two-host split (weewx host for the API, front-end host for Caddy/dashboard) follows ADR-034. A third machine running TruShore is an optional extension of the existing topology, not a change to it. The API's interaction with TruShore is identical whether TruShore runs locally or remotely.

### Why Subprocess vs. Python Native

SWAN is a Fortran program. There is no Python-native reimplementation. The options are:

1. **Subprocess (chosen):** Spawn `swan.exe`/`swan` binary, pass input via files, read output from files.
2. **Cloud API:** Services like Inductiva.ai expose SWAN via REST. Adds external dependency, cost, and latency.
3. **Python SWAN port:** Does not exist at production scale.

The subprocess pattern is well-established in scientific computing. The API already invokes wgrib2 as a subprocess for HRRR processing. No architectural concerns.

---

## §7 — TruShore: Our Proprietary Layer

TruShore is the name for the complete Clear Skies nearshore wave pipeline: SWAN model execution plus our proprietary post-processing. SWAN by itself is a commodity tool — any operator can run it. The proprietary value is in what we do with its output.

### What NWPS Provides vs. What TruShore Provides

| Capability | NWPS | TruShore |
|---|---|---|
| Wave physics engine | SWAN | SWAN (same) |
| Bathymetric refraction/shoaling | Yes (NCEP DEMs) | Yes (CUDEM via `enrichment/bathymetry.py`) |
| Wave breaking | Battjes-Janssen (γ = 0.73 constant) | γ corrected by Battjes (1974) formula using site-specific slope |
| Coastal structure effects | None | Directional Kt by material/type/angle (`enrichment/wave_transform.py`) |
| Sub-grid interpolation | None (nearest grid cell) | Bilinear (Supplement 3) |
| Topographic wave focusing | None | Multiplicative multiplier by landform type (Supplement 4) |
| Surf quality scoring | None | 4-component weighted score with beach alignment penalty (`enrichment/surf_scorer.py`) |
| Wind forcing | Forecaster-edited NDFD (5km) | HRRR forecast wind (3km), hourly, no human dependency |
| Run schedule | Human-gated (2–8×/day, no fixed time) | Hourly on HRRR cycle, fixed schedule |
| Availability on 404 | Cache expires, fall to WW3 | Cache last successful run, never fall to WW3 for surf |
| Water temperature | Not provided | OFS per-timestep modeled temps (`providers/ocean/ofs.py`) |

### The Existing Components TruShore Already Contains

The following files are already built and deployed in the current Clear Skies API. TruShore does not require rewriting them — it requires connecting them to SWAN output instead of NWPS output:

**`enrichment/wave_transform.py`:**
- Breaker index correction using the Battjes (1974) γ formula with CUDEM-derived slope
- Coastal structure effects: directional Kt coefficients by material and angle, shadow zone geometry, diffraction, linear superposition for multiple structures
- Bilinear sub-grid spatial interpolation
- Topographic wave focusing/sheltering multipliers

**`enrichment/surf_scorer.py`:**
- Four-component weighted scoring (wave height 35%, wave period 35%, wind quality 20%, swell dominance 10%)
- Beach alignment penalty using `directional_exposure` config
- Multi-swell interference scoring
- Quality labels: "Poor" through "Epic"

**`providers/marine/wavewatch.py`:**
- WaveWatch III fetch from ERDDAP/THREDDS — this becomes SWAN's boundary condition input

**`enrichment/bathymetry.py`:**
- CUDEM depth profiles via NCEI ArcGIS ImageServer — this becomes SWAN's bathymetric grid input

**`providers/ocean/ofs.py`:**
- RTOFS/ESTOFS ocean model data — tidal currents become SWAN's wave-current interaction input, SST continues as water temperature

### What Is Net-New for TruShore

1. **`providers/wind/hrrr.py`:** Fetch HRRR GRIB2 from NOMADS, extract U/V at 10m AGL for a configurable coastal bounding box, rotate grid-relative to earth-relative, cache.
2. **`services/swan_runner.py`:** Write SWAN input files (GRIB2 wind, bathymetry grid, boundary spectra, OUTPUT POINTS spec for each surf spot), spawn SWAN subprocess, parse output, convert to `MarineForecastPoint` format.
3. **Cache warmer wiring:** Run SWAN on HRRR cycle schedule (hourly), cache results with configurable TTL.

### TruShore Name Rationale

"TruShore" signals: nearshore physics (shore), accurate (tru), and distinguishes the proprietary post-processing layer from raw SWAN output. The name covers the complete pipeline — not just SWAN, but SWAN plus our γ correction, structure physics, and surf quality scoring. A third party running vanilla SWAN does not have TruShore.

---

## §8 — Open Questions and Known Gaps

**Q1: HRRR vs. forecaster-edited winds — quantitative impact on surf forecasts.**
The literature gap identified in §4 remains. The honest position is: HRRR will be at least as good as the NDFD grid for routine conditions; it may be worse for unusual coastal meteorological events where forecasters apply local knowledge. Monitoring TruShore output against NWPS output during the overlap period (Phase 2 QC Gate) will provide empirical data.

**Q2: SWAN binary distribution — RESOLVED (2026-07-17).**
SWAN 41.51 must be compiled from source on each target platform. Pre-compiled binaries from SourceForge are ABI-incompatible with Ubuntu 24.04's gfortran 13.3 runtime (Fortran allocatable array metadata layout differs between gfortran versions, causing garbage memory allocation sizes). The source is available at https://gitlab.tudelft.nl/citg/wavemodels/swan and builds with CMake + Ninja + gfortran in ~2 minutes. Docker images compile SWAN at build time, eliminating the ABI issue (binary and runtime are in the same image layer). The `install_swan.sh` script handles native installations.

**Q3: Boundary condition format.**
WaveWatch III output as SWAN boundary spectra (BOUND SPEC format) requires converting ERDDAP NetCDF wave spectral data to SWAN's directional-frequency spectrum format. This is well-documented in the SWAN manual but requires implementing the conversion. Existing code in `providers/marine/wavewatch.py` fetches the data; the conversion is new. Implementation note (2026-07-17): SWAN 41.51 requires `BOUNDSPEC SIDE ... CONSTANT FILE` with separate files per boundary side (SWAN cannot open the same file twice for two BOUNDSPEC commands).

**Q4: Multiple WFO coverage.**
The current NWPS provider is keyed by WFO (`wfo` parameter in `providers/marine/nwps.py`). TruShore is keyed by surf spot, not WFO — one SWAN domain per coastal segment, regardless of WFO boundaries. Operators with multiple surf spots across a WFO boundary run one SWAN domain per coastal segment, not one per WFO. This simplification is correct but requires that the API switch from WFO-keyed to location-keyed surf data.

**Q5: Nested grid implementation — NEW (2026-07-17).**
The current SWAN runner (`services/swan_runner.py`) uses a single flat regular grid (`CGRID REG`). The research in §2 "Grid Configuration: Nested Grids" establishes that all operational nearshore systems use 2–3 level nested grids. Implementing nesting requires: (a) two sequential SWAN runs (outer grid → inner nest, boundary conditions passed via SWAN's native nesting support), (b) computing appropriate domain extents for each level (outer covers the shelf approach, inner covers the coastline of interest), (c) managing the intermediate boundary files between runs. SWAN's user manual documents the nesting workflow. This is the next implementation task.

**Q6: 72-hour forecast range — NEW (2026-07-17).**
HRRR provides wind forcing for only 18 hours (standard cycles) or 48 hours (extended cycles at 00/06/12/18Z). The dashboard's 72-hour surf forecast card requires 72 hours of wind forcing. NWPS solved this by using GFS wind (0.25°, extends to 384 hours). TruShore needs either: (a) GFS wind for hours 48–72 (blended with HRRR for 0–48h), or (b) GFS wind for the full range (simpler, matches NWPS approach, at the cost of coarser wind for the first 48 hours). A GFS wind provider module is needed. This is a prerequisite for matching the pre-existing 72-hour forecast capability.

**Q7: SWAN INPUT file syntax — RESOLVED (2026-07-17).**
SWAN 41.51 requires: (a) spectral resolution in the CGRID command (`CIRCLE 36 0.0418 1.0 31`), (b) `COORDINATES SPHERICAL` as a separate command (not `SET CGRID SPHERICAL`), (c) `GEN3 WESTHUYSEN` (not `WESTIN` or `WEST`), (d) `SET NAUTICAL` as a separate command. These were discovered through iterative debugging on the production host. Future changes to the INPUT file generator should be tested with a minimal SWAN run before deployment.
