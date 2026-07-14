---
status: Archived — consolidated into PROVIDER-MANUAL.md, API-MANUAL.md
date: 2026-07-13
accepted: 2026-07-13
archived: 2026-07-13
deciders: shane
---

# ADR-091: Marine card data sources, OFS ocean data, and composite water level

## Context

The marine feature shipped with correct data sourcing in the surf detail endpoint (`GET /surf/{id}`) — NWPS → wave_transform → surf_scorer per ADR-084. But the marine list endpoint (`GET /marine`) and marine detail endpoint (`GET /marine/{id}`) never wired into this chain. The result: all 7 location cards show identical offshore buoy data (NDBC 46253, 12 miles offshore in 66m deep water), weather fields are null (buoy doesn't report wind/pressure/air temp), water temperature is raw Celsius with no unit conversion, and tide height is identical across all locations sharing the same CO-OPS station.

Separately, research (documented in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md`) found that NDBC buoy 46253 is wrong for nearshore water temperature — deep ocean water does not heat like the coastal shelf, with beach surface water 5–9°F warmer than offshore. Fishing needs water column profiles (thermocline, bottom temps), not just surface readings.

Research into tide accuracy (documented in `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md`) found that CO-OPS harmonic predictions are excellent for astronomical tides (2–5 cm accuracy) but miss all meteorological effects (storm surge, wind setup, atmospheric pressure). OFS total water level captures these effects. The optimal approach combines both: CO-OPS as tidal base + OFS non-tidal residual as meteorological signal.

This ADR makes four related decisions that establish data source contracts for all marine endpoints.

## Options considered

### Water temperature source

| Option | Pros | Cons |
|---|---|---|
| Keep NDBC buoy as sole source | Simple, already implemented | Wrong location (12mi offshore), surface only, no forecast, identical for all locations |
| OFS regional model (primary) with tiered fallback | Accurate nearshore temp, water column profiles, forecasts, per-location differentiation | New dependency (xarray + netCDF4), OFS coverage gaps |
| Satellite SST only (MUR/OISST) | Simple HTTP, global | Surface only, 1-day latency, no depth profiles, no forecast |

### Card weather data (wind, air temp, weatherCode)

| Option | Pros | Cons |
|---|---|---|
| NDBC buoy (current) | Already wired | Buoy 46253 reports null for wind/pressure/air temp |
| Station hardware + forecast provider fallback | Uses existing `is_station_served()` and provider dispatch patterns | Requires wiring the existing but uncalled `marine_weather_cache` |

### Tide on location cards

| Option | Pros | Cons |
|---|---|---|
| Keep currentTide on cards | Consistent with current design | Identical for all 7 locations (same CO-OPS station) — visual noise |
| Remove from cards, keep in detail tabs | Cards differentiate on fields that actually differ per location | Tide info less discoverable on landing page |

### Water level enhancement

| Option | Pros | Cons |
|---|---|---|
| CO-OPS predictions only (current) | Accurate tidal component | Misses storm surge, wind setup, atmospheric pressure effects |
| OFS total water level only | Captures meteorological effects | Less accurate for pure tidal component (15 cm RMSE vs 2–5 cm) |
| CO-OPS prediction + OFS non-tidal residual (composite) | Best of both: excellent tidal accuracy + meteorological signal | Requires compositor service, bias correction logic |

## Decision

### Decision 1 — Marine card data source contract

The `_location_summary()` function in `endpoints/marine.py` populates `currentConditions` and related card fields from these sources, in this precedence order:

| Card field | Primary source | Fallback | Unit conversion |
|---|---|---|---|
| waveHeight | NWPS → `wave_transform.apply_supplements()` (for locations with surf activity + `nwps_wfo`) | WaveWatch III first forecast point (no supplements per ADR-084), then NDBC buoy Hs | meter → operator `group_wave_height` via `convert()` |
| windSpeed | Station hardware via weewx archive (when `is_station_served(location.id)` returns True) | Configured forecast provider `fetch_current_conditions(lat, lon)` (returns in operator target unit) | Provider handles conversion |
| windDirection | Same as windSpeed | Same as windSpeed | degrees (no conversion) |
| airTemp | Same as windSpeed | Same as windSpeed | Provider handles conversion |
| waterTemp | Ocean data resolver `resolve(needs="surface")` — tiered: on-premises sensor → OFS model surface → MUR SST → RTOFS surface | See Decision 2 for full fallback chain | Celsius → operator `group_temperature` via `convert()` |
| ~~currentTide~~ | **Removed from card.** All locations sharing a CO-OPS station show identical tide data — visual noise on the landing page. Tide information lives in the activity detail tabs. | — | — |
| weatherCode | Configured forecast provider `fetch_current_conditions(lat, lon)` | None | WMO code (no conversion) |
| isDay | Configured forecast provider `fetch_current_conditions(lat, lon)` | None | boolean |

The `is_station_served()` function (in `services/marine_location_resolver.py`) determines whether a marine location is close enough to the weather station to use live hardware observations. Locations within `dedup_radius_km` (default 2.5 km) get station data; all others get forecast provider data.

### Decision 2 — NOAA OFS as primary ocean data source, with tiered fallback

**Full research:** `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` — documents why NDBC buoy 46253 is wrong (deep-water station, 5–9°F discrepancy vs coastal shelf), the complete OFS model inventory (15 models, coverage maps, resolution, depth levels), THREDDS/OPeNDAP data extraction patterns (verified regulargrid variable structure, grid coordinate caching, cycle selection), the ERDDAP fallback sources (MUR SST, RTOFS, PacIOOS, CARICOOS), the resolver architecture (two query modes, coverage tiers, canonical data models), species depth targeting for fishing, and the setup wizard Data Coverage panel spec. **Implementation agents must read the brief for technical details — this ADR is a decision summary, not a build spec.**

NDBC buoy 46253 is demoted from primary water temperature source to labeled offshore reference data. The ocean data resolver (`services/ocean_data_resolver.py`) provides a provider-agnostic interface for all ocean model data. The dashboard and endpoint code never see provider names. The resolver implements this fallback chain:

| Tier | Source | Coverage | Data available | Access |
|---|---|---|---|---|
| 1 | On-premises sensor | At-location only | Surface temp only | Operator station or CO-OPS gauge within threshold |
| 2 | NOAA OFS (15 models) | Major US coasts | Full: temp column, currents, salinity, water levels, forecast | THREDDS/OPeNDAP via `xarray` |
| 3a (surface) | NASA MUR SST | Global, 1km | Surface temp only | ERDDAP griddap |
| 3b (column+forecast) | NOAA RTOFS | Global, 8km, 41 depth levels | Temp column, currents, salinity, 8-day forecast | ERDDAP griddap |
| 4 | Unavailable | — | null | — |

OFS model assignment is computed at location configuration time (setup wizard) by checking which OFS domain bounding box contains the location's lat/lon. Persisted in `api.conf` as `ofs_model`. Locations outside all OFS domains skip to tier 3.

The resolver supports two query modes: `mode="modeled"` (default — runs the tier chain) and `mode="observed"` (returns only a real sensor reading, null if no sensor nearby — does NOT fall back to models).

### Decision 3 — OFS data beyond temperature

**Full research:** `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"OFS Data Beyond Temperature" — documents verified OPeNDAP variable structure for all fields (temp, salt, u_eastward, v_northward, zeta, zetatomllw, h), 2D surface file variables (ROMS only), the modeled-vs-observed distinction, OFS bathymetry vs CUDEM, and how currents/salinity/water levels integrate with each activity tab.

From the same OFS files opened for temperature, the system extracts and reports additional oceanographic data where available. All fields are null when OFS/RTOFS coverage doesn't include them — dashboard handles null with "—" display.

| OFS variable | Canonical field | Used by | Unit conversion |
|---|---|---|---|
| `temp` (full column) | `waterColumnProfile` | Fishing species scorer (depth-specific), thermocline detection | Celsius → operator `group_temperature` |
| `salt` (full column) | `salinity` | Fishing species scorer (habitat preference), river plume detection | PSU — no conversion |
| `u_eastward` + `v_northward` | `currentSpeed`, `currentDirection` | Boating navigation, fishing drift, beach safety | m/s → operator speed unit |
| `zeta` / `zetatomllw` | `waterLevelMsl`, `waterLevelMllw` | Supplementary to CO-OPS tides (includes storm surge) | meter → operator `group_water_level` |
| `h` | `seafloorDepth` | Fishing bottom temp reference (NOT replacing CUDEM — model-grid resolution only) | meter |

Current reporting is simple: speed + direction as stat tile and forecast time series. No vector field maps.

### Decision 4 — Composite water level (CO-OPS prediction + OFS non-tidal residual)

**Full research:** `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md` — answers five research questions: Q1 (OFS vs CO-OPS comparison — they measure different things, the difference IS the valuable data), Q2 (per-location tide differentiation — not physically meaningful at 1.9 km on open coast; justifies removing `currentTide` from cards), Q3 (OFS deviation during storm/king tide events — the deviation is the storm surge signal, not model error), Q4 (OFS as tide proxy — no, supplement only; CO-OPS primary), Q5 (display design — total water level overlay + residual stat tile + storm surge indicator). Also documents: the composite algorithm with bias correction, persistence fallback formula, CO-OPS station coverage for Huntington Beach locations, STOFS-2D-Global comparison (not needed separately — OFS provides equivalent data from same files), cache warmer integration, and TideChart enhancement design. **Implementation agents must read the brief for the full algorithm, validation data, and architectural rationale.**

CO-OPS harmonic predictions are accurate to 2–5 cm for astronomical tides but miss all meteorological effects. OFS total water level captures surge/wind/pressure but is less accurate (RMSE ≤ 0.15m) for the pure tidal component. A water level compositor service (`services/water_level_compositor.py`) combines both:

- **Base:** CO-OPS harmonic prediction (excellent tidal accuracy)
- **Meteorological signal:** OFS non-tidal residual (= OFS total water level − CO-OPS prediction)
- **Bias correction:** Anchor OFS forecast residual to observed residual (= CO-OPS observed − CO-OPS predicted) at current time
- **Persistence fallback:** When OFS unavailable, decay current observed residual exponentially (tau = 12 hours)

Storm surge classification thresholds (configurable per location):
- < 0.15 ft: null (normal)
- 0.15–0.5 ft: `"elevated"` or `"depressed"`
- 0.5–1.0 ft: `"significant"`
- \> 1.0 ft: `"storm_surge"`

`currentTide` is removed from `GET /marine` card summary (identical across all locations sharing a CO-OPS station). Composite water level data surfaces in the activity detail tabs via `GET /tides/{locationId}`.

## Consequences

- New domain `ocean` with two provider modules: `providers/ocean/ofs.py` (THREDDS) and `providers/ocean/erddap_ocean.py` (ERDDAP, config-driven for MUR SST + RTOFS + regional models)
- New service `services/ocean_data_resolver.py` — orchestrates fallback, normalizes output
- New service `services/water_level_compositor.py` — combines CO-OPS predictions with OFS non-tidal residual
- New canonical models: `OceanDataResult`, `WaterColumnProfile`, `WaterColumnLayer`, `OceanCurrentSnapshot`, `OceanForecastPoint`, `CompositeWaterLevel`
- New dependency: `xarray` + `netCDF4` in `[marine]` pip extra
- New setup endpoint: `GET /setup/marine/coverage` for wizard/admin Data Coverage panel
- New response fields on `GET /tides/{id}`: `totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel`
- NDBC buoy demoted to labeled offshore reference data, not a primary source
- `currentTide` removed from `GET /marine` card summary
- TideChart enhanced with total water level overlay, observed trace, and residual fill
- Admin marine section gains per-location edit, species management, coverage panel, unit groups

## Acceptance criteria

- [ ] `_location_summary()` populates wind/air temp from station hardware (via `is_station_served()`) or forecast provider — not NDBC buoy
- [ ] `waterTemp` on cards comes from the ocean data resolver, unit-converted to operator's `group_temperature`
- [ ] `currentTide` is null or absent from `GET /marine` card summary
- [ ] Ocean data resolver implements full tier chain: on-premises → OFS → MUR SST/RTOFS → unavailable
- [ ] `mode="observed"` returns null when no sensor — never silently falls back to modeled
- [ ] OFS provider extracts temp, salt, u_eastward, v_northward, zeta, zetatomllw, h from regulargrid files
- [ ] Water level compositor computes observed residual, bias-corrected OFS forecast residual, and total water level forecast
- [ ] Persistence fallback decays exponentially with tau = 12h when OFS unavailable
- [ ] `GET /tides/{id}` includes `totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel` when data available
- [ ] `GET /tides/{id}` returns unchanged response when OFS unavailable (no regression)
- [ ] Setup wizard Data Coverage panel shows OFS model assignment, coverage tier, nearest stations
- [ ] `xarray` and `netCDF4` in `[marine]` pip extra, not in base install

## Implementation guidance

- **Phase 1 (MARINE-CARD-DATA-SOURCE-PLAN):** Wire forecast provider into `marine_weather_cache`, fix `_location_summary()` data sources, fix waterTemp unit conversion, remove `currentTide` from cards, fix SRF zone forecast, consolidate dashboard stats panels, fix all four activity tab data issues
- **Phase 2:** Wire NWPS → wave_transform for card + detail wave height
- **Phase 3:** Build OFS provider, ERDDAP ocean provider, ocean data resolver, setup coverage panel, wire resolver into endpoints + cache warmer
- **Phase 4:** Build water level compositor, wire into tides endpoint + cache warmer, enhance TideChart with overlays, add residual stat tiles
- **Phase 5:** Admin marine section parity with wizard
- **Phase 6:** Final doc-code sync, ADR archive

See `docs/planning/MARINE-CARD-DATA-SOURCE-PLAN.md` for full task breakdown and acceptance criteria per phase.

## References

- Related ADRs: ADR-083 (marine provider domains), ADR-084 (NWPS primary with supplements), ADR-090 (activity capability matrix)
- Research: `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` (OFS model inventory, THREDDS technical details, fallback architecture)
- Research: `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md` (CO-OPS vs OFS accuracy, composite water level architecture, bias correction)
