# Brief: Marine, Surf & Fishing Data Audit

**Date:** 2026-07-08  
**Scope:** Code audit of two pre-Clear-Skies weewx extensions, marine data provider landscape survey, global coverage gap analysis, and architectural assessment for Clear Skies integration  
**Repos audited:** [inguy24/weewx-noaa_marine_API](https://github.com/inguy24/weewx-noaa_marine_API), [inguy24/weewx-fish_and_surf_forecasts](https://github.com/inguy24/weewx-fish_and_surf_forecasts)  
**Deliverable:** Research brief only — no code changes, planning documents, or ADRs created

---

## Executive Summary

Two weewx extensions were built before the Clear Skies project began. **Phase I** (`weewx-noaa_marine_API`) fetches NOAA CO-OPS tide/water-level data and NDBC buoy observations. **Phase II** (`weewx-fish_and_surf_forecasts`) depends on Phase I and adds GFS Wave GRIB processing for surf forecasts plus rule-based fishing forecasts.

Both extensions are more complete than expected but neither would work correctly out of the box. Phase I has structural bugs in data insertion and table creation. Phase II has a copy-paste error that calls the wrong forecast generator and bypasses its own wave transformation physics.

**Key discovery:** The Clear Skies API already contains dormant marine infrastructure: a GFE text engine with wave height phrases, chop categories, and marine wind descriptors — fully translated into 12 languages. The provider dispatch pattern supports adding a `"marine"` domain with no architectural changes. Xweather has `/maritime` and `/tides` endpoints; Open-Meteo has a dedicated Marine Weather API. Neither has a module built yet.

**Bottom line:** The extensions' core value — fetching external marine data and computing derived forecasts — maps directly to Clear Skies' provider + enrichment architecture. None of this needs to remain a weewx extension. The data should flow through the API's provider modules, and the surf/fishing scoring logic should become API enrichment processors, producing three new dashboard pages: Marine Forecast, Surf Conditions, and Fishing Forecast.

---

## 1. Extension Audit: NOAA Marine API (Phase I)

**Repo:** inguy24/weewx-noaa_marine_API  
**Version:** 1.0.1-beta (released 2025-08-14)  
**License:** GPL v3  
**Size:** ~3,200 lines across 2 Python files + YAML config

### Architecture

Registers as a `StdService` in weewx's `data_services`. Spawns three daemon threads:
- CO-OPS collection (every 10 min)
- NDBC collection (hourly)
- Health monitor (every 5 min, restarts stuck threads)

Data goes into three dedicated database tables (`coops_realtime`, `tide_table`, `ndbc_data`) — *not* the weewx archive. A `TideTableSearchList` provides Cheetah template variables (`$next_high_tide`, `$next_low_tide`, `$today_tides`, `$week_tides`, `$tide_range_today`).

### NOAA APIs Used

| Source | Product | Data | Interval |
|--------|---------|------|----------|
| CO-OPS | `water_level` | Real-time water level, sigma, quality flags | 10 min |
| CO-OPS | `water_temperature` | Coastal water temperature | 10 min |
| CO-OPS | `predictions` (hi/lo) | 7-day tide predictions with heights | 6 hr |
| NDBC | Realtime2 `.txt` | Waves, wind, temp, pressure, visibility, dewpoint | 1 hr |

CO-OPS base URL: `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter`  
NDBC base URL: `https://www.ndbc.noaa.gov/data/realtime2/`

Metadata APIs (install-time only): CO-OPS station discovery via `mdapi/prod/webapi/stations.json`, NDBC station discovery via `activestations.xml`.

### Data Model

Three dedicated tables in the weewx database (via `wx_binding`):

**`coops_realtime`** — water level + temperature observations:
- `dateTime`, `station_id`, `marine_current_water_level`, `marine_water_level_sigma`, `marine_water_level_flags`, `marine_coastal_water_temp`, `marine_water_temp_flags`

**`tide_table`** — 7-day rolling tide predictions:
- `dateTime`, `station_id`, `tide_time`, `tide_type` (H/L), `predicted_height`, `datum`, `days_ahead`, plus computed next-tide fields

**`ndbc_data`** — buoy observations:
- `dateTime`, `station_id`, `marine_wave_height`, `marine_wave_period`, `marine_wave_direction`, `marine_wind_speed`, `marine_wind_direction`, `marine_wind_gust`, `marine_air_temp`, `marine_sea_surface_temp`, `marine_barometric_pressure`, `marine_visibility`, `marine_dewpoint`

### What Works

- CO-OPS API client with retry and exponential backoff
- NDBC text file parser handling `MM` missing-data markers correctly
- Background thread architecture with configurable intervals
- Thread health monitor with automatic restart of dead/stuck threads
- Interactive curses-based installer with station discovery (bounding-box for CO-OPS, XML metadata for NDBC)
- YAML-driven field definitions (good separation of config from code)
- CLI test harness (`--test-install`, `--test-api`, `--test-db`, `--test-all`)
- Tide prediction cleanup (deletes predictions older than 24 hours)
- Build/packaging script

### Bugs & Issues

1. **CO-OPS data insertion structurally wrong.** The `_insert_coops_data` method expects `data` to contain keys like `'water_level'`, but the CO-OPS API returns `{'data': [{'v': '1.234', 's': '0.003', ...}]}`. The `get_water_level()` method returns raw API JSON. `data.get('water_level')` never matches — every field inserts as `None`.

2. **SQLite table creation fails.** Uses MySQL-specific `INDEX idx_name (col)` syntax and `station_id(20)` prefix-length keys inside `CREATE TABLE`. SQLite does not support inline INDEX definitions or prefix lengths. On a SQLite database (weewx default), table creation would error.

3. **No `commit()` after CO-OPS realtime inserts.** Tide predictions commit correctly; water level/temperature inserts do not. Data may never persist.

4. **TideTableSearchList never registered.** The installer only registers the service in `data_services`, not the SearchList in `[CheetahGenerator] [[search_list_extensions]]`. Template variables would be unavailable.

5. **Unit conversion ignores weewx target_unit.** NDBC data hardcodes US unit conversions (meters→feet, m/s→mph, °C→°F) regardless of the configured unit system.

6. **Database type detection on every insert.** Runs `SELECT VERSION()` to detect MySQL vs SQLite on every single row — 2+ extra queries per insert.

### Dependencies

- **PyYAML** — only real external dependency
- `requests` is imported but never used (all HTTP uses `urllib`) — dead import

---

## 2. Extension Audit: Fish & Surf Forecasts (Phase II)

**Repo:** inguy24/weewx-fish_and_surf_forecasts  
**Label:** Phase II (depends on Phase I)  
**License:** GPL v3  
**Size:** ~7,900 lines in a single Python file (`surf_fishing.py`) + ~1,560 line installer

### Architecture

A `StdService` that spawns a background thread running every 6 hours (configurable). For each configured surf spot: optionally runs bathymetry calculation (GEBCO API), downloads GFS Wave GRIB files (NOAA NOMADS), processes GRIB data to extract wave parameters, generates surf quality ratings (1–5 stars), stores in `marine_forecast_surf_data` table. For each fishing spot: queries Phase I marine data, scores fishing periods based on pressure/tide/time/species factors, stores in `marine_forecast_fishing_data` table. Two `SearchList` classes provide template variables.

### Data Sources

| Source | Data | Method |
|--------|------|--------|
| NOAA GFS Wave (WaveWatch III) | Wave height, period, direction, wind, swell components | GRIB2 file download from NOMADS |
| GEBCO via OpenTopoData | Ocean floor bathymetry | REST API (install-time + first-run) |
| Phase I tables | NDBC buoy obs, CO-OPS water levels, tide predictions | Direct SQL queries |

GFS Wave URL pattern: `https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.{yyyymmdd}/{hh}/wave/gridded/gfswave.t{hh}z.{grid_name}.f{fff}.grib2`

6 regional grids: US East Coast (`atlocn.0p16`), US West Coast (`wcoast.0p16`), Hawaii/Pacific (`epacif.0p16`), Alaska/Arctic (`arctic.9km`), Global primary (`global.0p16`), Global fallback (`global.0p25`).

### Key Classes

| Class | Lines | Role |
|-------|-------|------|
| `GRIBProcessor` | 42+ | GRIB file reading with eccodes or pygrib backends |
| `MarineStationIntegrationManager` | 287+ | Phase I station metadata and quality scoring |
| `DataFusionProcessor` | 488+ | Multi-source atmospheric data fusion |
| `WaveWatchDataCollector` | 669+ | GFS Wave GRIB download and caching |
| `BathymetryProcessor` | 1370+ | GEBCO bathymetry with adaptive refinement |
| `SurfForecastGenerator` | 3213+ | Surf forecast generation and quality scoring |
| `FishingForecastGenerator` | 5833+ | Fishing forecast generation and scoring |
| `SurfFishingService` | 6919+ | Main StdService orchestrator |

### Surf Forecast Features

- Up to 5 configurable surf spots with lat/lon, bottom type (sand/rock/coral_reef/mud/mixed), beach facing
- 6 regional GRIB grids with geographic priority and fallback
- Research-based physics coefficients (Dean & Dalrymple, Scripps citations)
- Bathymetric profile calculation with adaptive refinement (GEBCO API)
- Surf quality scoring: wave height + period + wind + swell dominance → 1–5 stars
- GRIB file caching with cleanup of old cycles
- Wave transformation physics code exists (shoaling, refraction, breaking) but is not wired into the main loop

### Fishing Forecast Features

- Up to 5 fishing spots, 4 target categories (freshwater sport, saltwater inshore, saltwater offshore, bottom fish)
- 3-day, period-based forecasts (dawn, morning, midday, afternoon, dusk, night)
- Scoring: pressure trend + tide movement + time-of-day + species activity modifiers
- Species-specific scoring adjustments per target category
- No solunar computation — scoring is based entirely on weather/tide conditions

### Bugs & Issues

1. **Copy-paste error in main forecast loop.** `_generate_surf_forecast_for_spot` (line 7316) calls `generate_fishing_forecast` instead of the surf forecast generator. Surf forecasts would not actually generate.

2. **`eval()` for unit conversion.** `_apply_conversion_formula` (line 7065) executes arbitrary code from weewx.conf values. Security risk — anyone who can write to weewx.conf can execute arbitrary Python.

3. **Wave transformation physics bypassed.** The `_apply_multi_point_wave_transformation` method exists and `_transform_to_local_conditions` is coded, but neither is called from the main `_forecast_loop`. Raw GFS data goes directly to the quality scorer without shoaling, refraction, or breaking adjustments.

4. **`FishingForecastSearchList` doesn't extend `SearchList`.** Extends `object` implicitly (line 6812), so it may not register properly as a weewx SearchList extension.

5. **`AttributeError` in `new_loop_packet`.** References `self.station_integration` (line 7109) which is set on `FishingForecastGenerator`, not on `SurfFishingService`. Would raise `AttributeError` at runtime.

6. **Duplicate method definitions.** `apply_breaking_limit` defined twice (lines 4160 and 4581); the simpler second definition silently overwrites the enhanced first. `_determine_tide_stage` copy-pasted between both generators.

### Dependencies

- **Required:** PyYAML, Phase I extension
- **Optional:** eccodes or pygrib (GRIB processing), numpy (required by pygrib path)
- Without a GRIB library, wave forecasts are disabled (graceful degradation)

---

## 3. Marine Data Provider Landscape

### Provider Comparison by Data Type

| Provider | Waves | Tides | SST | Currents | Marine Text | Coverage | Free Tier |
|----------|-------|-------|-----|----------|-------------|----------|-----------|
| **Open-Meteo** | Full | Model-derived | Full | Full | None | Global | 10K/day |
| **Xweather** | Full | US only | Full | Full | None | Global | 15K/mo |
| **NOAA NWS** | None | None | None | None | Full | US only | Free |
| **NOAA CO-OPS** | None | Full | Full | Full | None | US only | Free |
| **NOAA NDBC** | Obs only | None | Obs only | Some | None | US + open ocean | Free |
| **OpenWeatherMap** | None | None | None | None | None | — | — |
| **Stormglass** | Full | Full | Full | Full | None | Global | 10/day |
| **WorldTides** | None | Full | None | None | None | Global (8K+) | 100 credits |
| **Copernicus Marine** | Full | Model-derived | Full | Full | None | Global | Free (Python) |

**Key:** Obs = observations only (no forecasts). Model-derived = tidal signal embedded in sea-level height, not discrete high/low predictions. Full = forecasts + observations or predictions.

### Provider Notes

#### Open-Meteo Marine Weather API

The strongest free option. Separate API base (`marine-api.open-meteo.com/v1/marine`) from the regular weather API. Wraps 10 wave models:
- ECMWF WAM (9 km, global) — highest resolution
- Meteo-France MFWAM (8 km, global)
- NCEP GFS Wave (16–25 km, global)
- DWD EWAM (5 km, Europe only) — best European resolution
- DWD GWAM (25 km, global)
- ERA5-Ocean (50 km, global historical back to 1940)

Provides: wave height/period/direction, up to 3 swell components, sea surface temperature, ocean currents, sea-level height.  
Forecast range: 7–16 days depending on model.  
No API key needed for non-commercial use.  
**Limitation:** Tides are model-embedded (not discrete high/low predictions). Coastal accuracy is explicitly disclaimed.

#### Xweather (formerly Aeris)

Already a configured provider in Clear Skies. Two marine endpoints exist with no module built:
- `/maritime` — global marine forecasts (waves, swell, SST, currents, surge), updated every 6 hours, forecasts to 15 days. 1× cost multiplier.
- `/tides` — predicted tidal information, **US locations only**. Max 75 locations per request. 1× cost multiplier.
- `/maritime/archive` — historical data from 2024+. 5× cost multiplier.

Maritime fields: `seaSurfaceTemperatureC/F`, `seaCurrentSpeedKTS/KPH/MPS/MPH`, `seaCurrentDir`, `significantWaveHeightM/FT`, `primaryWaveDir/Period`, `primarySwellHeightM/FT`, `secondarySwellHeight`, `tertiarySwellHeight`, `tidesM/FT`, `surgeM/FT`.

#### NOAA Sources (all free, no API key)

- **NWS API** (`api.weather.gov`): Marine zone forecasts with text narratives, wind, seas, visibility. The only source for official marine forecast text. 15 marine area codes covering Atlantic, Gulf, Great Lakes, Pacific, Hawaii. Requires `User-Agent` header only.
- **CO-OPS** (`api.tidesandcurrents.noaa.gov`): The authoritative US tide prediction source. 420+ water level stations, 6-minute observations, harmonic-based predictions. Also water temperature, currents, barometric pressure. Most mature NOAA marine API.
- **NDBC** (`ndbc.noaa.gov`): ~1,300 buoy/station observations. File-based access (not REST). Standard met (`.txt`), spectral wave (`.spec`), ADCP currents (`.adcp`), oceanographic (`.ocean`).
- **WaveWatch III**: Global spectral wave model, 0.25–0.5° resolution. GRIB2 via NOMADS/ERDDAP. This is what Phase II downloads directly.

#### Solunar / Fishing Data

Solunar calculations are purely algorithmic. Given lat/lon, date, and timezone, the algorithm computes moon position (transit, underfoot, rise, set) and derives major/minor activity periods. No external API is needed. Clear Skies already uses **Skyfield** for almanac computations (moon phases, planet positions, eclipses) — the same library can compute solunar times.

Fishing forecast quality is determined by combining solunar periods with barometric pressure trends, tide state, water temperature, wind, and species-specific modifiers. All inputs are available through other Clear Skies data sources.

No fishing forecast API exists for developer consumption. Consumer apps (Fishnotify, HookCast, Fishingreminder) combine solunar + weather + tides internally but expose no public API.

#### Other Providers Investigated

- **Stormglass** (stormglass.io): Good aggregator (9 met agencies), global, includes waves + tides + SST + currents. But free tier is only 10 requests/day — too limited. Paid from €19/mo.
- **WorldTides** (worldtides.info): Dedicated global tide API, 8,000+ locations, aggregates NOAA + BODC (UK) + BoM (Australia) + more. Credit-based pricing from $4.99/mo.
- **Windy API**: Marine data available (wave models, currents, tidal currents). Free tier returns corrupted data (development only). Paid: €990/year.
- **Copernicus Marine Service**: Comprehensive (global wave, SST, currents, biogeochemistry) but is a scientific data service, not a simple REST API. Requires Python toolbox to access NetCDF/Zarr data. Free.
- **Surfline**: No public API. MagicSeaweed API shut down in 2023 after Surfline acquisition. No legitimate programmatic surf forecast source.
- **Surf-forecast.com**: 7,000+ surf spots, star ratings, but no API.

---

## 4. Global Coverage Gap Analysis

### By Data Type

| Data Type | US Coverage | Global Coverage | Gaps |
|-----------|-------------|----------------|------|
| **Wave forecasts** (height, period, direction) | Full (NOAA + Open-Meteo + Xweather) | Full (Open-Meteo 10 models + Xweather) | Polar regions (>77°), nearshore accuracy limited by model resolution (5–50 km) |
| **Swell components** (primary, secondary, tertiary) | Full | Full (Open-Meteo + Xweather, 3 systems each) | Tertiary swell limited to select models |
| **Tide predictions** (discrete high/low) | Full (CO-OPS, 3,000+ stations) | Partial (WorldTides 8K+, model-derived elsewhere) | West Africa, remote Pacific islands, Arctic coasts, Patagonia. Model accuracy: ±20 min, ±25 cm |
| **Water temperature** (SST) | Full (NDBC + CO-OPS obs + models) | Full (Open-Meteo + Xweather model) | Nearshore accuracy limited; cloud gaps in IR satellite; sparse open-ocean buoys |
| **Marine text forecasts** (NWS-style narratives) | Full (NWS marine zones) | **Gap** — no global aggregator API | Each country issues its own format. Canada (XML), UK (no API post-2025), Australia (no official API). No unified service. |
| **Ocean currents** | Full (CO-OPS point obs + models) | Full (Open-Meteo + Xweather model) | All models 8–25 km; cannot resolve harbor/channel currents. CO-OPS is US-only. |
| **Buoy observations** (real-time, not model) | Full (NDBC ~1,300 stations) | **Gap** — no global buoy API | National agencies operate independent networks. Southern Hemisphere sparse. |
| **Solunar / fishing** | Full | Full | Purely algorithmic — computable for any location. No coverage gap. |

### Unfillable Gaps

**Marine text forecasts** outside the US/Canada cannot be obtained from any single provider. The GFE text engine in Clear Skies (already built, 12 languages) could generate synthetic narratives from numerical marine data — this would be the only way to serve text forecasts globally.

**Buoy observations** are inherently regional and institutional. For non-US locations, model data is the only practical option via API.

### Wave Forecast vs. Surf Forecast — Critical Distinction

A wave forecast (what models provide) and a surf forecast are fundamentally different:

| Aspect | Wave Forecast (model output) | Surf Forecast |
|--------|------------------------------|---------------|
| Spatial scale | 5–50 km grid cells in open ocean | A specific beach or break |
| Predicts | Significant wave height, period, direction in deep water | Wave face height, quality, surfability at a spot |
| Bathymetry | Ignored or coarse | High-resolution, site-specific |
| Quality rating | None | Yes (clean/choppy, star ratings) |
| Tide integration | Sometimes sea level | Tied to surfability windows |
| Who can do it | Anyone with model access | Requires per-spot calibration |

The Phase II extension attempted the "last mile" (deep-water → specific break) with shoaling, refraction, and breaking calculations, though these were never wired into the main loop. Clear Skies could implement this as an enrichment processor, but the accuracy gap vs. Surfline (proprietary LOTUS model + 35 years calibration data) should be set as an expectation.

---

## 5. Clear Skies Integration Assessment

### What Already Exists in the Codebase

| Component | Location | Status | What It Does |
|-----------|----------|--------|-------------|
| Marine wave phrases | `sse/gfe/marine_phrases.py` | **Built** | `wave_height_phrase()` and `chop_phrase()` with 10 height ranges, 7 chop categories |
| Marine wind phrases | `sse/gfe/wind_phrases.py` | **Built** | `marine_wind_phrase()` for gale/storm force/hurricane force descriptors |
| Marine thresholds | `sse/gfe/thresholds.py` | **Built** | `WAVE_HEIGHT_RANGES`, `CHOP_CATEGORIES`, `MARINE_WIND_DESCRIPTORS`, `MARINE_SEAS_THRESHOLD` |
| Wave connectors | `sse/gfe/connectors.py` | **Built** | `scalar_connector()` handles `WaveHeight` with "building to" / "subsiding to" |
| i18n marine keys | `locales/*.json` | **Built** | All marine phrases translated into 12 languages |
| Provider dispatch | `providers/_common/dispatch.py` | **Ready** | `domain` field is a free string — adding `"marine"` needs only a new module + dict entry |
| Xweather `/maritime` | Documented in PROVIDER-MANUAL | **No module** | Endpoint exists, global marine data |
| Open-Meteo Marine API | Documented in PROVIDER-MANUAL | **No module** | Separate API base URL, global, free |
| Pressure/dewpoint/visibility | aeris.py, nws.py, owm.py | **Parsed, dropped** | Wire models parse these fields but they are never mapped to canonical output |

### Reusable Infrastructure (no changes needed)

- `ProviderHTTPClient` — retry, backoff, dual-stack
- `RateLimiter` — per-module rate limiter
- Cache system — memory or Redis, custom TTLs
- Error taxonomy — `QuotaExhausted`, `KeyInvalid`, `GeographicallyUnsupported`, etc.
- Datetime utilities — `to_utc_iso8601_from_offset()`, `epoch_to_utc_iso8601()`
- Dispatch registry — add rows, done
- Capability registry — `wire_providers()` works for any domain string
- Provider attribution — `ProviderAttribution` dataclass works for any provider

### What Would Need to Be Created

- **Canonical marine models** in `models/responses.py`: `MarineForecastPoint` (wave height/period/direction, swell components, SST, currents), `TidePrediction` (time, type, height, datum), `MarineForecastBundle`
- **Provider modules** under `providers/marine/`: at minimum `openmeteo.py` and `aeris.py`
- **Tide provider modules** (possibly `providers/tides/`): `coops.py` (NOAA, US), `aeris.py` (Xweather, US), optionally `worldtides.py` (global, paid)
- **API endpoints**: `GET /api/v1/marine`, `GET /api/v1/tides`, `GET /api/v1/surf`, `GET /api/v1/fishing`
- **Enrichment processors**: surf quality scorer (from Phase II scoring logic), fishing forecast generator (solunar + conditions)
- **Dashboard pages**: Marine Forecast, Surf Conditions, Fishing Forecast
- **Wizard steps**: marine provider selection, surf/fishing spot configuration

### What Does NOT Need to Be a weewx Extension

**Nothing from either extension needs to remain a weewx extension.** The extensions' sole purpose is fetching external API data and computing derived values — exactly what the Clear Skies provider + enrichment architecture does, with better error handling, caching, multi-provider fallback, i18n, and unit conversion.

The weewx extension pattern (StdService, dedicated DB tables, Cheetah SearchList) was the right approach *before Clear Skies existed*. Now that the API has a provider dispatch system, canonical field mapping, Redis caching, and a GFE text engine with marine vocabulary, all of this data should flow through the API.

### Reusable Assets from the Extensions

- **NOAA API knowledge:** CO-OPS products, NDBC file formats, station discovery patterns → informs provider module implementations
- **Surf scoring algorithm:** Wave height + period + wind + swell dominance → 1–5 stars → starting point for surf enrichment processor (physics need to be properly wired)
- **Fishing scoring logic:** Pressure trend + tide movement + time-of-day + species modifiers → enrichment processor (solunar should be computed via Skyfield)
- **Bathymetry approach:** GEBCO via OpenTopoData for ocean floor depth at surf spots → setup-time calculation stored in spot config

---

## 6. Architectural Recommendations

### 1. Add a `"marine"` provider domain

Follow the existing pattern: `providers/marine/openmeteo.py` as primary (free, global), `providers/marine/aeris.py` as secondary (Xweather, already keyed). Canonical model includes wave height, period, direction, 3 swell components, SST, ocean currents. Endpoint: `GET /api/v1/marine`.

**Open-Meteo first** because it's free, global, needs no API key for non-commercial, and provides 10 wave models with automatic best-resolution selection.

### 2. Add a `"tides"` provider domain

Tides are a distinct data type from marine forecasts (discrete events vs. continuous fields). US: `providers/tides/coops.py` (NOAA, free, authoritative) or `providers/tides/aeris.py` (Xweather, US only). Global: `providers/tides/worldtides.py` (paid, 8K+ locations) or model-derived from Open-Meteo (less accurate, free). Endpoint: `GET /api/v1/tides`.

### 3. Add NWS marine zone forecasts (US supplement)

The existing NWS provider module can be extended to fetch marine zone forecasts from `/zones/marine/{zoneId}/forecast`. These provide official text narratives (wind, seas, visibility, hazards) that no other provider can supply. The GFE text engine's marine vocabulary can generate synthetic narratives for non-US locations from numerical data.

### 4. Compute solunar in the API via Skyfield

Skyfield is already a dependency (almanac computations). Solunar times are pure celestial mechanics: moon transit, moon underfoot, moonrise, moonset, plus phase-weighted intensity. No new dependency. No external API call. Computable for any location on Earth. Endpoint: fold into `GET /api/v1/fishing` or `GET /api/v1/almanac/solunar`.

### 5. Build surf and fishing as enrichment processors

Surf quality scoring takes marine data + spot config (beach facing, bottom type, bathymetry) and produces a 1–5 star rating with conditions text. Fishing scoring takes solunar + pressure trend + tide state + species rules. Both fit the API's enrichment pattern: input data → domain logic → derived output. Configure spots in the wizard or admin UI.

### 6. Three new dashboard pages

- **Marine Forecast:** Wave conditions, sea state, SST, currents, marine text forecast (NWS or synthetic), tide chart
- **Surf Conditions:** Per-spot wave forecast with quality rating, swell breakdown, wind analysis, tide overlay
- **Fishing Forecast:** Solunar calendar, per-spot activity ratings, pressure/tide/conditions overlay, species-specific timing

All three pages are optional (controlled by `pages.json` visibility, same as Seismic or Reports).

---

## 7. Open Questions

| # | Question | Options | Impact |
|---|----------|---------|--------|
| 1 | **Tide data source for non-US locations.** NOAA CO-OPS and Xweather tides are US-only. Global tide predictions require WorldTides (paid, ~$5–100/mo) or model-derived sea-level height from Open-Meteo (free but no discrete high/low predictions). | WorldTides as keyed provider; Open-Meteo model-derived with reduced accuracy; tides US-only in v1 | Whether non-US stations can display tide information |
| 2 | **Surf/fishing spot configuration model.** Phase II stored up to 5 spots per category in weewx.conf. Where should this live in Clear Skies? | In `api.conf` (operator edits); in wizard/admin UI (guided setup); hybrid | Wizard scope, admin UI scope, config file structure |
| 3 | **Marine page scope for v1.** Three new pages is significant scope. Should all three ship together? | All three; marine first + surf/fishing in v2; marine + surf in v1, fishing in v2 | Planning and phasing |
| 4 | **GRIB processing.** Phase II downloads WaveWatch III GRIB files directly. Clear Skies providers use REST JSON APIs. Should there be a GRIB-based provider? | REST APIs only (simpler, no GRIB dependency); GRIB provider for higher resolution (adds eccodes dependency) | Dependency footprint and data resolution |
| 5 | **Marine station (buoy) discovery.** Phase I had interactive station discovery. How should Clear Skies handle nearby-station selection? | Auto-discover via CO-OPS/NDBC metadata APIs in wizard; operator enters station IDs manually; both with auto-suggest | Wizard complexity and operator experience |

---

## 8. Storage Analysis: Extension Pattern vs. Clear Skies Architecture

### What the Extensions Store and How

Both extensions write directly to the weewx archive database — the same database file (SQLite) or schema (MariaDB) that weewx uses for weather observations. They create their own tables inside it and perform INSERT, DELETE, and REPLACE operations via the weewx `db_manager.connection`.

**Phase I creates 3 tables in the weewx database:**

| Table | Data | Write Pattern | Volume | Retention |
|-------|------|--------------|--------|-----------|
| `coops_realtime` | Water level + temperature observations | REPLACE INTO every 10 min per station | ~144 rows/day/station | Unbounded (never cleaned up) |
| `tide_table` | 7-day rolling tide predictions (high/low events) | DELETE old + INSERT new every 6 hr per station | ~28 events/week/station | 24-hour cleanup (predictions older than yesterday deleted) |
| `ndbc_data` | Buoy observations (waves, wind, temp, pressure) | REPLACE INTO every 1 hr per station | ~24 rows/day/station | Unbounded (never cleaned up) |

**Phase II creates 2 tables in the weewx database:**

| Table | Data | Write Pattern | Volume | Retention |
|-------|------|--------------|--------|-----------|
| `marine_forecast_surf_data` | Surf forecasts with quality ratings (30 columns) | DELETE all for spot + INSERT new every 6 hr per spot | ~24 rows/spot/cycle (72hr forecast at 3hr steps) | Replaced each cycle |
| `marine_forecast_fishing_data` | Fishing forecasts with activity ratings (14 columns) | DELETE all for spot + INSERT new every 6 hr per spot | ~15 rows/spot/cycle (5 periods × 3 days) | Replaced each cycle |

**Phase II also writes to weewx.conf** (not the database): bathymetric profile data is persisted as individual keys (`point_0_depth`, `point_0_latitude`, etc.) directly into the weewx configuration file via configobj. This is a one-time operation per surf spot.

### Why This Violates Clear Skies Architecture

The Clear Skies API has a **hard read-only constraint** on the weewx database, enforced at three levels:

1. **Database grants:** MariaDB user gets `SELECT` only. SQLite opens with `?mode=ro&uri=true`.
2. **Startup write probe:** The API attempts a write at startup — if it succeeds, the service exits. The API *refuses to start* if it has write access.
3. **Architectural rule:** "The API never holds a writable DB connection" (API-MANUAL.md anti-patterns table).

The extensions' approach — creating custom tables inside the weewx database and writing to them from background threads — is fundamentally incompatible with this architecture. It would require giving the API write access to the weewx database, which defeats the entire defense-in-depth model.

### What Actually Needs Persistent Storage

Analyzing each data type the extensions store, categorized by whether it needs persistence at all:

#### Data that does NOT need persistent storage (ephemeral / cache-appropriate)

| Data | Why it doesn't need a database | Clear Skies equivalent |
|------|-------------------------------|----------------------|
| **CO-OPS water level observations** | Latest-value only. The extension fetches `date=latest` and overwrites the previous row. Only the most recent reading matters. | **Redis cache** with TTL. The provider module fetches, caches the response for 10 min. Same as current forecast/AQI/alerts caching. |
| **CO-OPS water temperature** | Same — latest-value, overwritten every 10 min. | **Redis cache** with TTL. |
| **NDBC buoy observations** | Same — latest-value, overwritten every hour. The extension stores only the most recent data row from the .txt file. | **Redis cache** with TTL. |
| **Surf forecasts** | Replaced entirely every 6 hours. The DELETE-all-then-INSERT pattern means previous forecasts are discarded. Only the current forecast matters. | **Redis cache** with 6-hour TTL (or `refreshInterval` from provider). Provider module fetches wave data, enrichment processor computes quality score, result cached. |
| **Fishing forecasts** | Same — replaced entirely every 6 hours. | **Redis cache** with 6-hour TTL. Provider data + solunar computation + scoring, result cached. |

All five of these are **provider response cache** data. Clear Skies already caches provider responses in Redis with per-domain TTLs (forecast 30 min, alerts 5 min, AQI 15 min). Marine data would get its own TTL (e.g., marine observations 10 min, marine forecast 30 min, tides 6 hr).

#### Data that needs persistence but NOT in the weewx database

| Data | Why it needs persistence | Clear Skies equivalent |
|------|------------------------|----------------------|
| **Tide predictions (7-day)** | Tide predictions are valid for a known future window and change infrequently (harmonic-based, deterministic). Fetching on every request wastes API quota. But they're still ephemeral — they're replaced every 6 hours with a fresh 7-day window. | **Redis cache** with 6-hour TTL. CO-OPS predictions are deterministic (harmonic); refreshing every 6 hours is more than sufficient. The cache stores the full 7-day prediction set as a single cached response. |
| **Bathymetric profiles** | Computed once per surf spot from GEBCO API. Ocean floor doesn't change. Must survive API restarts. | **Config file** (`api.conf`). Spot configuration (lat/lon, bottom type, beach facing) already lives in config. Bathymetry results are a one-time computation stored alongside spot config — same as the forecast correction model path being stored in config. Alternatively, a small JSON file in `/etc/weewx-clearskies/` per spot. |
| **Surf spot / fishing spot configuration** | Operator-defined locations with parameters (coordinates, bottom type, beach facing, target species). | **Config file** (`api.conf`). These are operator settings, not runtime data. Same pattern as provider API keys, station metadata, chart configuration. Written by the wizard/admin UI, read by the API at startup. |

#### Data that needs its own persistent storage (if historical tracking is desired)

| Data | Use case for persistence | Clear Skies pattern |
|------|------------------------|---------------------|
| **Historical marine observations** (wave height, SST, buoy data over time) | Trend charts, climatology comparisons ("average wave height this month vs. last year"). The extensions don't actually do this — they only store the latest value. | **Not needed for v1.** If historical marine data is desired later, it follows the forecast correction engine precedent: a separate SQLite database at `/etc/weewx-clearskies/marine_history.db`, never the weewx archive. |
| **Historical surf/fishing scores** | "Was last Tuesday a good surf day?" review. The extensions don't support this either — they overwrite each cycle. | **Not needed for v1.** Same separate-DB pattern if ever needed. |

### The Existing Precedent: Forecast Correction Engine (ADR-079)

The Clear Skies API already has one component that needs its own persistent storage: the forecast correction engine. Its approach is the template for any future persistence needs:

- **Separate SQLite database** at `/etc/weewx-clearskies/forecast_correction.db` — never the weewx archive
- **Separate trained model file** at `/etc/weewx-clearskies/forecast_correction_model.pkl`
- The weewx archive DB remains read-only
- The correction DB is created by the API on first use
- Written atomically (model file), or via simple INSERT (pair collection)

### Recommended Storage Strategy

| Extension Data | Current Pattern | Clear Skies Pattern | Storage |
|---------------|----------------|--------------------|---------| 
| Water level / temp observations | REPLACE INTO weewx DB every 10 min | Provider module → Redis cache | Redis, 10 min TTL |
| Buoy observations | REPLACE INTO weewx DB every 1 hr | Provider module → Redis cache | Redis, 60 min TTL |
| Tide predictions (7-day) | DELETE old + INSERT new every 6 hr | Provider module → Redis cache | Redis, 6 hr TTL |
| Surf quality forecasts | DELETE all + INSERT every 6 hr | Enrichment processor → Redis cache | Redis, 30 min TTL (or `refreshInterval`) |
| Fishing forecasts | DELETE all + INSERT every 6 hr | Enrichment processor → Redis cache | Redis, 30 min TTL (or `refreshInterval`) |
| Bathymetric profiles | Persisted to weewx.conf | One-time computation → config file or JSON | `/etc/weewx-clearskies/` file |
| Spot configuration | weewx.conf `[SurfFishingService]` | Wizard/admin UI → `api.conf` | `api.conf` sections |
| Historical marine data (if ever) | Not implemented | Separate SQLite DB (forecast correction precedent) | `/etc/weewx-clearskies/marine_history.db` |

### Summary

**The extensions treat the weewx database as a general-purpose data store.** They create custom tables and do full CRUD operations alongside weewx's own archive data. This works in the weewx extension model where the extension runs inside the weewx process and has full database access.

**Clear Skies treats the weewx database as a read-only data source.** External data (forecasts, alerts, AQI, earthquakes, marine) flows through provider modules into Redis cache. Derived data (Beaufort scale, comfort index, conditions text, surf scores) is computed by enrichment processors and served from memory or cache. The only persistent storage the API owns is in `/etc/weewx-clearskies/` — config files and the forecast correction SQLite DB.

**Nothing the extensions store requires a database.** Every data type is either latest-value-only (cache), periodically-replaced forecasts (cache), or one-time configuration (config file). The DELETE-all-then-INSERT pattern used by both extensions is functionally identical to a cache replacement — it just uses SQL instead of a cache key.

---

## Appendix A: Phase I Detailed Architecture (weewx-noaa_marine_API)

### A.1 Class Inventory

**`MarineDataService`** (StdService, lines 54–328)
- Entry point. Loads config, validates, creates API clients, starts 3 daemon threads.
- Key state: `db_manager` (shared), `selected_stations`, `field_mappings`, `coops_client`, `ndbc_client`
- Also has `_get_today_tides()` and `_get_week_tides()` query methods (unused at runtime — duplicated in SearchList)

**`ThreadHealthMonitor`** (Thread, lines 331–460)
- Daemon thread checking every 300s. Detects dead threads (`.is_alive()`) or stuck threads (no collection in 7200s for CO-OPS, 10800s for NDBC). Restarts by setting `running=False`, `join(5)`, creating a new thread with same params.

**`COOPSBackgroundThread`** (Thread, lines 824–1063)
- Daemon thread. Main loop: every 60s checks if collection intervals have elapsed. Calls `_collect_water_level_data()` every 600s (water level + water temp), `_collect_tide_predictions()` every 21600s. Each collection iterates stations, calls API client, inserts to DB.
- Contains `_get_database_type()` and `_get_upsert_sql()` (duplicated with NDBC thread).

**`NDBCBackgroundThread`** (Thread, lines 1065–1187)
- Daemon thread. Main loop: every 300s checks if collection interval (3600s) has elapsed. Iterates stations, fetches `.txt` file, applies unit conversions (hardcoded US units), inserts to DB.
- Contains duplicate `_get_database_type()` and `_get_upsert_sql()`.

**`COOPSAPIClient`** (lines 1190–1273)
- Stateless HTTP client. Three methods: `get_water_level()`, `get_water_temperature()`, `get_predictions()`. All delegate to `_make_api_request()` which handles retries with exponential backoff (2^attempt seconds). Returns `None` for "No data found" (not an error).
- Base URL hardcoded: `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter`

**`NDBCAPIClient`** (lines 1276–1324)
- Stateless HTTP client. Single method `get_station_data()` fetches the `.txt` file and calls `_parse_ndbc_data()`. Parser: line 0 = headers, line 2 = most recent data, skips `MM` values. No retry logic.
- Base URL hardcoded: `https://www.ndbc.noaa.gov/data/realtime2`

**`TideTableSearchList`** (SearchList, lines 1327–1564)
- Provides 5 template variables: `$next_high_tide`, `$next_low_tide`, `$today_tides`, `$week_tides`, `$tide_range_today`. All query the `tide_table` directly via SQL.

**`MarineDataTester`** (lines 464–821)
- CLI test harness. Tests: service registration in weewx.conf, API connectivity (hardcoded test stations), database table existence and INSERT/SELECT/DELETE cycle.

### A.2 Call Graph — Startup to Data Collection

```
weewx engine discovers MarineDataService in data_services
  └─ MarineDataService.__init__(engine, config_dict)
       ├─ Extract config_dict['MarineDataService']
       ├─ Check enable flag
       ├─ engine.db_binder.get_manager('wx_binding') → shared db_manager
       ├─ _load_station_selection()
       │    └─ Read selected_stations.coops_stations / ndbc_stations
       │       Filter for value == 'true'
       ├─ _load_field_mappings()
       │    └─ Read field_mappings subsection
       ├─ validate_essential_config()
       │    └─ Check required keys exist
       ├─ COOPSAPIClient(timeout=30, retry_attempts=3)
       ├─ NDBCAPIClient(timeout=30)
       ├─ _start_background_threads()
       │    ├─ COOPSBackgroundThread(stations, fields, client, db_manager, config).start()
       │    └─ NDBCBackgroundThread(stations, fields, client, db_manager, config).start()
       └─ _start_health_monitor()
            └─ ThreadHealthMonitor(self, 300).start()
```

### A.3 Call Graph — CO-OPS Collection Cycle

```
COOPSBackgroundThread.run()  [loops every 60s]
  ├─ IF water_level_interval (600s) elapsed:
  │    _collect_water_level_data()
  │      FOR each station:
  │        ├─ api_client.get_water_level(station_id)
  │        │    └─ _make_api_request({product: water_level, station: id, ...})
  │        │         └─ urllib.request.urlopen(url, timeout=30)
  │        │         └─ json.loads(response) → raw API dict
  │        ├─ IF data: _insert_coops_data(station_id, data)
  │        │    ├─ Build insert_data from data.get('water_level'), etc.
  │        │    │    ⚠ BUG: keys don't match API response shape
  │        │    ├─ _get_upsert_sql('coops_realtime', fields)
  │        │    │    └─ _get_database_type() → SELECT VERSION() every time
  │        │    └─ db_manager.connection.execute(sql, values)
  │        │         ⚠ BUG: no commit()
  │        ├─ api_client.get_water_temperature(station_id)
  │        └─ IF data: _insert_coops_data(station_id, temp_data)
  │
  └─ IF predictions_interval (21600s) elapsed:
       _collect_tide_predictions()
         FOR each station:
           ├─ api_client.get_predictions(station_id, begin_7day, end_7day)
           └─ IF data['predictions']:
                _insert_tide_predictions(station_id, data)
                  ├─ DELETE FROM tide_table WHERE tide_time < yesterday
                  ├─ Parse each prediction → {tide_time, type, height, days_ahead}
                  ├─ Calculate summary: next_high, next_low, tide_range
                  ├─ FOR each event: INSERT into tide_table
                  └─ db_manager.connection.commit() ✓
```

### A.4 Thread Architecture

| Thread | Daemon | Sleep | Health Threshold |
|--------|--------|-------|-----------------|
| COOPSBackgroundThread | Yes | 60s loop | 7200s (2 hr) stuck detection |
| NDBCBackgroundThread | Yes | 300s loop | 10800s (3 hr) stuck detection |
| ThreadHealthMonitor | Yes | 300s loop | — |

**No synchronization primitives.** All three threads share the same `db_manager` (single DB connection). Thread safety relies entirely on the underlying database driver (SQLite serialized mode or MySQL thread safety). The `self.running` boolean and `self.last_successful_collection` timestamp are read/written across threads without locks — works under CPython GIL but is not formally thread-safe.

### A.5 Database Schema

```sql
-- coops_realtime (CO-OPS water level + temperature)
CREATE TABLE IF NOT EXISTS coops_realtime (
    dateTime INTEGER NOT NULL,
    station_id TEXT NOT NULL,
    marine_current_water_level REAL,
    marine_water_level_sigma REAL,
    marine_water_level_flags TEXT,
    marine_coastal_water_temp REAL,
    marine_water_temp_flags TEXT,
    PRIMARY KEY (dateTime, station_id(20)),      -- ⚠ station_id(20) is MySQL-only
    INDEX idx_recent_coops (station_id(20), dateTime)  -- ⚠ inline INDEX is MySQL-only
);

-- tide_table (7-day rolling tide predictions)
CREATE TABLE IF NOT EXISTS tide_table (
    dateTime INTEGER NOT NULL,
    station_id TEXT NOT NULL,
    tide_time INTEGER NOT NULL,
    tide_type TEXT NOT NULL,
    predicted_height REAL,
    datum TEXT,
    days_ahead INTEGER,
    marine_next_high_time TEXT,
    marine_next_high_height REAL,
    marine_next_low_time TEXT,
    marine_next_low_height REAL,
    marine_tide_range REAL,
    PRIMARY KEY (station_id(20), tide_time, tide_type(1)),
    INDEX idx_upcoming_tides (station_id(20), tide_time)
);

-- ndbc_data (buoy observations)
CREATE TABLE IF NOT EXISTS ndbc_data (
    dateTime INTEGER NOT NULL,
    station_id TEXT NOT NULL,
    marine_wave_height REAL,        -- WVHT: m → ft (* 3.28084)
    marine_wave_period REAL,        -- DPD: seconds (passthrough)
    marine_wave_direction REAL,     -- MWD: degrees (passthrough)
    marine_wind_speed REAL,         -- WSPD: m/s → mph (* 2.23694)
    marine_wind_direction REAL,     -- WDIR: degrees (passthrough)
    marine_wind_gust REAL,          -- GST: m/s → mph (* 2.23694)
    marine_air_temp REAL,           -- ATMP: °C → °F
    marine_sea_surface_temp REAL,   -- WTMP: °C → °F
    marine_barometric_pressure REAL,-- PRES: hPa → inHg (* 0.0295301)
    marine_visibility REAL,         -- VIS: passthrough
    marine_dewpoint REAL,           -- DEWP: °C → °F
    PRIMARY KEY (dateTime, station_id(20)),
    INDEX idx_recent_ndbc (station_id(20), dateTime)
);
```

**Upsert pattern:** MySQL uses `REPLACE INTO`, SQLite uses `INSERT OR REPLACE INTO`. Database type detected by `SELECT VERSION()` — executed on every single insert (should be cached).

---

## Appendix B: Phase II Detailed Architecture (weewx-fish_and_surf_forecasts)

### B.1 Class Inventory (10 classes, ~7,900 lines)

**`GRIBProcessor`** (lines 43–285)
- Detects GRIB library at init (`eccodes` preferred, `pygrib` fallback, `None` if neither).
- `process_gfs_wave_file(path, lat, lon)` — dispatches to eccodes or pygrib backend. Finds nearest grid point to target coordinates. Returns list of `{parameter, value, forecast_time, lat, lon}` dicts.
- eccodes path: iterates messages via `codes_grib_new_from_file`, uses `codes_get_nearest()`.
- pygrib path: uses numpy distance calculation across full lat/lon grid.

**`MarineStationIntegrationManager`** (lines 288–486)
- Loads Phase I station metadata from `config_dict['MarineDataService']`.
- Quality scoring by distance: wave quality (0.3–1.0), atmospheric quality (0.4–1.0), tide quality (0.3–1.0).
- Station selection: `select_optimal_wave_source()`, `select_optimal_atmospheric_sources(max=3)`, `select_optimal_tide_source()`.

**`DataFusionProcessor`** (lines 489–667)
- Distance-weighted interpolation of multiple atmospheric data sources.
- Temporal consistency validation (pressure trend agreement across sources).
- IQR-based outlier detection.

**`WaveWatchDataCollector`** (lines 669–1368)
- Core GRIB download manager. Reads GFS Wave config from CONF (base URL, grids, schedule).
- `fetch_forecast_data(spot_config)` — selects grid by geographic priority, downloads GRIB files with caching, processes via GRIBProcessor, organizes by forecast time.
- Grid selection: 6 grids with priority (1=regional, 2=global, 3=fallback). Checks if spot coordinates fall within grid bounds.
- Cycle fallback: tries up to 4 GFS cycles (current + 3 previous, 6h apart).
- File validation: minimum file size + first 4 bytes must be `b'GRIB'`.
- Cache management: stores in `{WEEWX_ROOT}/cache/surf_fishing/grib/`, keeps 3 most recent cycles.

**`BathymetryProcessor`** (lines 1370–3211, 28 methods)
- Calculates ocean floor profile between surf break and deep water.
- `_find_deep_water_point()` — searches outward from surf break along beach_facing bearing in 1km increments up to 75km, validates depth via GEBCO API and GRIB data. Falls back to adjusted bearings (±45°, ±90°) if direct path hits land.
- GEBCO API: `https://api.opentopodata.org/v1/gebco2020?locations=lat,lon` — elevation < 0 = water.
- Two profile methods: original (16-point linear interpolation) and adaptive (gradient-based refinement with IQR anomaly smoothing).
- Results persisted to weewx.conf via configobj (writes `point_N_depth`, `point_N_latitude`, etc.).

**`SurfForecastGenerator`** (lines 3213–5718, 30+ methods)
- Core surf scoring engine. `generate_surf_forecast()` iterates forecast periods, extracts wave parameters, integrates Phase I tides, calls `assess_surf_quality_complete()`.
- Also contains wave transformation physics (shoaling, refraction, breaking, bottom friction) — wired into `_apply_multi_point_wave_transformation()` but that method is not called from the main forecast flow.

**`SurfForecastSearchList`** (SearchList, lines 5721–5831)
- Provides `$surf_forecasts`, `$surf_summary`, `$surf_spots_count`, `$surf_last_update` to Cheetah templates.

**`FishingForecastGenerator`** (lines 5833–6810)
- Core fishing scoring engine. `generate_fishing_forecast()` creates 15 periods (5 per day × 3 days). Each period scored by `score_fishing_period_unified()`.

**`FishingForecastSearchList`** (lines 6812–6917)
- ⚠ Does NOT extend `weewx.cheetahgenerator.SearchList` — extends `object` implicitly.
- Provides `$fishing_forecasts`, `$fishing_summary`, etc.

**`SurfFishingService`** (StdService, lines 6919–7866)
- Main entry point. Creates all processors and generators at init. Spawns single daemon thread running `_forecast_loop()`. Uses `threading.Event` for clean shutdown.

### B.2 Call Graph — Main Forecast Loop

```
SurfFishingService.__init__(engine, config_dict)
  ├─ _setup_unit_system_from_conf()
  ├─ GRIBProcessor(config_dict)
  │    └─ _detect_grib_library() → 'eccodes' | 'pygrib' | None
  ├─ BathymetryProcessor(config_dict, grib_processor, engine)
  ├─ SurfForecastGenerator(config_dict, None)
  ├─ FishingForecastGenerator(config_dict, engine)
  ├─ [if station_supplement mode]: MarineStationIntegrationManager + DataFusionProcessor
  └─ _start_forecast_thread()
       └─ Thread(target=_forecast_loop, daemon=True).start()

_forecast_loop()  [runs every forecast_interval, default 6 hours]
  ├─ open_manager_with_config() → thread-local db_manager
  ├─ Create thread-local SurfForecastGenerator(config_dict, db_manager)
  ├─ Create thread-local FishingForecastGenerator(config_dict, engine)
  │
  ├─ FOR each surf_spot in _get_active_surf_spots():
  │    ├─ IF not bathymetry_calculated:
  │    │    bathymetry_processor.process_surf_spot_bathymetry(spot)
  │    │      ├─ _find_deep_water_point(lat, lon, beach_facing)
  │    │      │    └─ Search 1km increments, GEBCO API + GRIB validation
  │    │      ├─ _create_adaptive_surf_path_and_collect_bathymetry()
  │    │      │    ├─ 16-point linear interpolation → GEBCO batch query
  │    │      │    ├─ Gradient-based refinement (up to 3 iterations)
  │    │      │    └─ IQR anomaly smoothing + conservative coarsening
  │    │      └─ persist_bathymetry_to_weewx_conf(spot_id, data)
  │    │
  │    ├─ IF grib_processor.is_available():
  │    │    WaveWatchDataCollector(config_dict, grib_processor)
  │    │    gfs_data = collector.fetch_forecast_data(spot_config)
  │    │      ├─ Select grid by geographic priority
  │    │      ├─ _download_grib_files(grid, for_forecasting=True)
  │    │      │    └─ Try 4 cycles, download forecast hours, validate files
  │    │      ├─ GRIBProcessor.process_gfs_wave_file(path, lat, lon)
  │    │      │    └─ Extract wave_height, wave_period, wave_dir, wind, swell
  │    │      └─ _organize_forecast_data() → list of forecast-period dicts
  │    │
  │    ├─ surf_forecast = surf_generator.generate_surf_forecast(spot, gfs_data)
  │    │    FOR each forecast period:
  │    │      ├─ Extract critical fields (wave_height, wave_period, wave_dir, wind)
  │    │      ├─ Query Phase I tide_table → tide_stage, tide_height
  │    │      ├─ assess_surf_quality_complete() → 1–5 stars
  │    │      │    ├─ Size score: wave_height → range lookup (0.1–1.0)
  │    │      │    ├─ Period score: wave_period → range lookup (0.2–1.0)
  │    │      │    ├─ Wind score: classify direction + speed → lookup
  │    │      │    ├─ Swell dominance: H²×T² energy ratio
  │    │      │    └─ Overall = size×0.35 + period×0.35 + wind×0.20 + swell×0.10
  │    │      └─ _enhance_forecast_with_calculated_fields()
  │    │
  │    └─ surf_generator.store_surf_forecasts(spot_id, forecast, db_manager)
  │         ├─ DELETE FROM marine_forecast_surf_data WHERE spot_id = ?
  │         └─ INSERT INTO marine_forecast_surf_data (30 columns)
  │
  └─ FOR each fishing_spot in _get_active_fishing_spots():
       ├─ marine_conditions = _get_phase_i_marine_conditions(lat, lon)
       │    ├─ SELECT FROM ndbc_data WHERE dateTime > 6_hours_ago
       │    └─ SELECT FROM coops_realtime WHERE dateTime > 6_hours_ago
       │
       ├─ fishing_forecast = fishing_generator.generate_fishing_forecast(spot, conditions)
       │    FOR each of 15 periods (5/day × 3 days):
       │      score_fishing_period_unified(period, spot, marine_conditions)
       │        ├─ Pressure: _collect_pressure_data() → trend → CONF score
       │        │    (stable_high=1.0, falling_slow=0.9, rising_fast=0.2)
       │        ├─ Tide: _determine_fishing_tide_movement() → Phase I query
       │        │    (outgoing=1.0, incoming=0.8, high_slack=0.4, low_slack=0.3)
       │        ├─ Time: hour → CONF score
       │        │    (dawn=1.0, dusk=1.0, night=0.8, morning=0.7, midday=0.4)
       │        ├─ Species: category modifier × (pressure×0.4 + tide×0.4 + 0.2)
       │        └─ Overall = pressure×0.4 + tide×0.3 + time×0.2 + species×0.1
       │             → 0.8+=5★, 0.6+=4★, 0.4+=3★, 0.2+=2★, else=1★
       │
       └─ fishing_generator.store_fishing_forecasts(spot_id, forecast, db_manager)
            ├─ DELETE FROM marine_forecast_fishing_data WHERE spot_id = ?
            └─ INSERT INTO marine_forecast_fishing_data (14 columns)
```

### B.3 Scoring Algorithms

#### Surf Quality (4 components, 1–5 stars)

| Component | Weight | Method | Example Ranges |
|-----------|--------|--------|---------------|
| Wave Height | 0.35 | Range lookup from CONF | 0–0.5ft=0.1, 1.5–3=0.8, 3–6=1.0, 10–15=0.6, 15+=0.2 |
| Wave Period | 0.35 | Range lookup from CONF | 0–6s=0.2, 8–10=0.6, 12–16=1.0, 20+=0.8 |
| Wind Quality | 0.20 | Direction classification + speed brackets | Offshore light=1.0, calm=0.92, onshore strong=0.17 |
| Swell Dominance | 0.10 | Energy ratio: swell H²×T² vs wind wave H²×T² | swell_dominant, wind_wave_dominant, or mixed |

Wind classification: relative angle between wind direction and beach_facing determines offshore/onshore/cross-shore. Speed brackets (light/moderate/strong/extreme) further refine the score.

Stars = `max(1, min(5, int(overall × 5)))`

#### Fishing Forecast (4 components, 1–5 stars)

| Component | Weight | Method | Key Values |
|-----------|--------|--------|-----------|
| Pressure Trend | 0.40 | CONF lookup by trend category | stable_high=1.0, falling_slow=0.9, rising_fast=0.2 |
| Tide Phase | 0.30 | Phase I tide_table query → movement | outgoing=1.0, incoming=0.8, high_slack=0.4, low_slack=0.3 |
| Time of Day | 0.20 | Hour → period name → CONF score | dawn=1.0, dusk=1.0, night=0.8, midday=0.4 |
| Species Activity | 0.10 | Category modifier × base score | Per fish_categories in CONF |

When pressure data unavailable: weight redistributed to remaining 3 components.

Stars: 0.8+=5, 0.6+=4, 0.4+=3, 0.2+=2, else=1

### B.4 Wave Transformation Physics (exists, partially wired)

The following physics methods exist in `SurfForecastGenerator` and are wired into `_apply_multi_point_wave_transformation()` (line 5634). However, `_transform_to_local_conditions()` which calls that pipeline is **never invoked** from the main forecast flow. The scoring operates on raw GFS Wave data.

| Physics | Method | Implementation |
|---------|--------|---------------|
| Shoaling | `calculate_shoaling_coefficient()` | Linear wave theory, iterative dispersion relation, Ks = √(C₁/C₂), capped at 1.5 |
| Refraction | `calculate_refraction_coefficient()` | Snell's Law, Kr = √(cos θ₀/cos θ₁), capped at 1.2 |
| Breaking | `apply_breaking_limit()` | Depth-limited: H_max = γ × depth. γ from bottom type (sand=0.78, rock=1.0, coral=1.2) |
| Bottom Friction | `_calculate_bottom_friction()` | Only below 5m depth. Max 20% energy loss. Coefficients from CONF. |
| Structure Effects | `_apply_structure_wave_effects()` | 5 structure types (jetty, pier, breakwater, seawall, groin) with reflection/transmission coefficients |

**To wire in:** `generate_surf_forecast()` would need to call `_transform_to_local_conditions()` on offshore data BEFORE passing to `assess_surf_quality_complete()`, so scoring operates on physically-transformed heights.

### B.5 GRIB Processing Pipeline

**Grid selection:** 6 grids with geographic bounds and priority. Spot coordinates checked against bounds; highest-priority (lowest number) grid wins. Grids: us_east_coast (atlocn.0p16, priority 1), us_west_coast (wcoast.0p16, 1), hawaii_pacific (epacif.0p16, 1), alaska_arctic (arctic.9km, 1), global_primary (global.0p16, 2), global_fallback (global.0p25, 3).

**Cycle selection:** Current UTC minus 4-hour processing delay → most recent model run from [0, 6, 12, 18]. Falls back to 3 previous cycles if current unavailable.

**Download:** `{base_url}gfs.{YYYYMMDD}/{HH}/wave/gridded/gfswave.t{HH}z.{grid}.f{FFF}.grib2` for forecast hours [0,3,6,...,72]. Requires ≥8 valid files per cycle. Files cached in `{WEEWX_ROOT}/cache/surf_fishing/grib/`.

**Validation:** File size ≥ grid-specific minimum (200KB global, 100KB regional) AND first 4 bytes = `b'GRIB'`.

**Extracted fields** (13 total): swh (wave height), perpw (peak period), dirpw (direction), ws (wind speed), wdir (wind direction), u/v (wind components), shww/mpww/wvdir (wind wave), shts/mpts/swdir (total swell).

### B.6 Thread Architecture

Single daemon thread `SurfFishingForecast`. Uses `threading.Event` (`shutdown_event`) for clean shutdown — `shutdown_event.wait(timeout=forecast_interval)` instead of `time.sleep()`. A `threading.Lock` (`_db_lock`) protects delayed init of the main `_db_manager`, but the forecast loop creates its own thread-local DB connection via context manager.

### B.7 Configuration Structure (weewx.conf)

```
[SurfFishingService]
    forecast_interval = 21600

    [[noaa_gfs_wave]]              # GFS Wave download config
        base_url, url_pattern, file_pattern
        [[grids]]                  # 6 grids with bounds + priority
        [[schedule]]               # model_runs, forecast_hours
        [[field_mappings]]         # 13 GRIB field definitions

    [[scoring_criteria]]
        [[[surf_scoring]]]         # Physics params, height/period/wind ranges, weights
        [[[fishing_scoring]]]      # Pressure/tide/time/species ranges, weights

    [[fish_categories]]            # 4 categories with species lists

    [[bathymetry_data]]            # GEBCO API config, adaptive spacing params

    [[seafloor_physics]]           # Breaking coefficients by bottom type
    [[structure_physics]]          # 5 coastal structure types

    [[surf_spots]]                 # Up to 5 spots with lat/lon/bottom_type/beach_facing
        [[[spot_0]]]               # + computed bathymetric_path after first run
    [[fishing_spots]]              # Up to 5 spots with lat/lon/target_category

    [[station_integration]]        # noaa_only | station_supplement
```
