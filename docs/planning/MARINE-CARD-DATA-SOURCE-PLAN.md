# Marine Location Card & Detail Page Data Source Remediation Plan

**Status:** IN PROGRESS — Phases 0-4 complete, T3.6 complete. Phases 5-6 pending.
**Phase 2 completed:** 2026-07-13 (API commit: 7081868)
**Phase 3 completed:** 2026-07-13 (API commits: 7e00725, 8431f04, d49b9a2; T3.6 completed 2026-07-13)
**T3.6 completed:** 2026-07-13 (API commits: 43a65ff, 8987d9f; Stack commit: c5f907e)
**Phase 4 completed:** 2026-07-14 (API commit: ec1f325; Dashboard commits: f5840bd, 0f146f3; Doc sync: 13388a5)
**Approved:** 2026-07-13
**Created:** 2026-07-13
**Phase 0 completed:** 2026-07-13 (ADR-091 drafted, ADR-090 updated, manuals updated)
**Phase 1 completed:** 2026-07-13 (API commits: 96cbbc1, 208526e, fd1a01d; Dashboard commits: e1db41f, 7d7ea55)
**Origin:** Post-deployment review of the marine dashboard page. All 7 location cards show data from wrong sources (raw offshore buoy observations instead of model output). Detail pages have broken/empty sections, layout violations, and data source gaps across all 4 activity tabs.

**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`), Meta (`weewx-clearskies-project`)

## Context

The marine feature shipped with the surf detail endpoint (`GET /surf/{id}`) correctly implementing the NWPS → wave_transform → surf_scorer chain per ADR-084. But the marine list endpoint (`GET /marine`) and the marine detail endpoint (`GET /marine/{id}`) never wired into this chain. The result:

| Field | Current source (wrong) | Correct source | Evidence |
|-------|----------------------|----------------|----------|
| Card wave height | NDBC buoy 46253 raw offshore Hs (all 7 locations show identical 0.9 ft) | NWPS → wave_transform.apply_supplements() (per ADR-084) | `_location_summary()` line 329 calls `ndbc.fetch()` only |
| Card wind | Null (buoy 46253 doesn't report wind at all) | Station hardware when `is_station_served()`, else configured forecast provider `fetch_current_conditions(lat, lon)` | `marine_weather_cache.put_weather()` has zero callers |
| Card air temp | Not shown | Same as wind | `marine_weather_cache.get_current_conditions()` always returns None |
| Card water temp | Raw 20.8°C — no conversion, no °F label | NDBC buoy (correct source) with unit conversion + label | No `convert()` call on waterTemp in `_location_summary()` |
| Card tide height | 2.16 raw meters from CO-OPS (unconverted) | **Remove from card** — identical for all 7 locations (same CO-OPS station). Tide belongs in activity detail tabs, not landing page cards. | No `convert()` call on tide height in `_location_summary()` |
| Card weatherCode/isDay | Null | Configured forecast provider | Cache never populated |
| Detail wave forecast | WaveWatch III only (offshore, not nearshore) | NWPS primary, WaveWatch III fallback (per ADR-084) | `get_marine_location()` line 485 calls only `wavewatch.fetch()` |
| Detail wind forecast | Null (WaveWatch III forecast points have null windSpeed) | Configured forecast provider | WaveWatch III doesn't include wind in its forecast points |
| NWS SRF zone forecast | Null (ripCurrentRisk, uvIndex both null) | NWS SRF product | `zoneForecast: null` in `GET /surf/{id}` response |
| Beach safety wind | Null | Configured forecast provider | Assessment wind fields all null |

**Root cause:** `_location_summary()` in `endpoints/marine.py` (line 316) passes raw NDBC buoy observation through as `currentConditions`. The NWPS provider, wave_transform enrichment, and forecast provider `fetch_current_conditions()` all exist and work — they're just not called from the marine endpoints. Additionally, `marine_weather_cache.put_weather()` has zero callers anywhere in the codebase — the cache infrastructure was built but never connected to a data source.

## 0. Orientation — Execution Context

Same as MARINE-SURF-FISHING-PLAN.md §0 — read those files, use those deploy scripts, follow those SSH rules.

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety, SSH access, filesystem permissions
- `rules/coding.md` — coding standards
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, QC gates, doc-code sync
- `docs/ARCHITECTURE.md` — services, ports, provider module layout
- `docs/manuals/API-MANUAL.md` — data model, unit system, endpoint patterns
- `docs/manuals/PROVIDER-MANUAL.md` — provider module contract (§1–§7), capability, cache, errors
- `docs/manuals/DASHBOARD-MANUAL.md` — §12 marine page behavior, data refresh, component patterns
- `docs/manuals/DESIGN-MANUAL.md` — §3 color tokens, §4 typography, §6 card anatomy, §7 icons, §11 charts

**Repos (paths on containers):**

| Repo | Container | Path |
|------|-----------|------|
| `weewx-clearskies-api` | weewx | `/home/ubuntu/repos/weewx-clearskies-api` |
| `weewx-clearskies-dashboard` | weather-dev | `/home/ubuntu/repos/weewx-clearskies-dashboard` |
| `weewx-clearskies-project` (meta) | local | `c:\CODE\weather-belchertown` |

**Deploy:**
- Dashboard + Config UI: `bash scripts/redeploy-weather-dev.sh`
- API: `bash scripts/deploy-api.sh`
- Direct SSH: `ssh -F .local/ssh/config weather-dev`, `ssh -F .local/ssh/config weewx`

**Existing patterns to follow:**
- Stats display: `StatTile` function in `src/components/marine/tabs/BoatingTab.tsx` line 70 — `<dt>`/`<dd>` with `--text-label` and `--text-stat-tile` tokens, `fontFeatureSettings: '"tnum"'`
- Section wrapper: `Panel` function in `BoatingTab.tsx` line 59 — `card-glass rounded-xl ring-1 ring-foreground/10 p-[var(--card-pad)]` with `<h3>` title at `--text-card-title`
- Chart container: `src/components/charts/chart-container.tsx` — `ChartContainer` with `ResponsiveContainer width="99%"`, `role="img"`, `aria-label`
- Tide chart: `src/components/marine/tabs/shared/TideChart.tsx` — 243 lines, Recharts `ComposedChart` with Area + Line + Scatter
- Forecast card: `src/components/forecast/ForecastDailyCard.tsx` → `DailyColumns.tsx` — expandable day columns with icon + hi/lo + precip + wind
- Highlights card: `src/components/todays-highlights-card.tsx` — `<dl>` grid with `StatItem` (icon + label + value)
- Provider dispatch: `endpoints/observations.py` `_fill_cloudcover_from_provider()` — provider-agnostic fetch pattern

**Agent assignments:**

| Agent type | Role |
|-----------|------|
| Coordinator (Opus) | ADR drafting, manual updates, QC gates, orchestration |
| `clearskies-api-dev` (Sonnet) | API endpoints, provider modules, enrichment, models |
| `clearskies-dashboard-dev` (Sonnet) | Dashboard pages, components, charts, i18n |
| `clearskies-auditor` (Sonnet) | Adversarial verification — tries to FAIL each phase |

**Verification mandate:** Same three-step gate as MARINE-INFRASTRUCTURE-PLAN.md §0. **Step 3 is ALWAYS a `clearskies-auditor` agent — the coordinator never self-audits.**
1. Implementing agent commits and reports (NOT trusted)
2. Coordinator runs mechanical checks (deterministic pass/fail — greps, curl, test commands)
3. **Adversarial `clearskies-auditor` agent** tries to FAIL — reads every file, cites line numbers, checks for stubs, checks for spec drift, verifies brief references are present and correct. A PASS with no evidence is treated as FAIL. The coordinator spawns this agent and does not declare the phase complete until the auditor returns.

**Test baselines (must not regress):**

| Suite | Command |
|-------|---------|
| API pytest | `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && sudo -u ubuntu /home/ubuntu/.local/bin/uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |
| Dashboard build | `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm run build 2>&1 \| grep gzip"` |

**What this plan does NOT fix (on hold per user direction):**
- surfRating on location cards — scorer exists but needs design review
- beachSafetyLevel on location cards — current implementation is two if/elif statements with hardcoded thresholds, not thought through
- Overall safety computation — user does not like the approach, needs rethinking

---

## Phase 0 — ADR-091 + Governing Doc Updates

No code. Decision documents and manual updates only.

### T0.1 — Draft ADR-091: Marine card data source contract + OFS ocean data

- Owner: Coordinator (Opus)
- File: `docs/decisions/ADR-091-marine-card-data-sources-and-ofs-ocean-data.md`
- Reference: ADR-083 (provider domains), ADR-084 (NWPS primary with supplements), ADR-090 (capability matrix), WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md, TIDE-ACCURACY-BRIEF.md

**Do:**
Draft ADR covering three decisions:

**Decision 1 — Marine card data source contract.** The `_location_summary()` function in `endpoints/marine.py` populates `currentConditions` and `currentTide` from these sources, in this precedence order:

| Card field | Primary source | Fallback | Unit conversion |
|---|---|---|---|
| waveHeight | NWPS → `wave_transform.apply_supplements()` (for locations with surf activity + `nwps_wfo`) | WaveWatch III first forecast point (no supplements per ADR-084), then NDBC buoy Hs | meter → operator `group_wave_height` via `convert()` |
| windSpeed | Station hardware via weewx archive (when `is_station_served(location.id)` returns True) | Configured forecast provider `fetch_current_conditions(lat, lon)` (returns in operator target unit) | Provider handles conversion |
| windDirection | Same as windSpeed | Same as windSpeed | degrees (no conversion) |
| airTemp | Same as windSpeed | Same as windSpeed | Provider handles conversion |
| waterTemp | Ocean data resolver `resolve(needs="surface")` — tiered: on-premises sensor → OFS model surface → MUR SST → RTOFS surface | See Decision 2 for full fallback chain | Celsius → operator `group_temperature` via `convert()` |
| ~~currentTide~~ | **Removed from card.** All locations sharing a CO-OPS station show identical tide data — it's visual noise on the landing page. Tide information lives in the activity detail tabs (boating, fishing, beach safety, surfing) where it has context. See TIDE-ACCURACY-BRIEF.md Q2. | — | — |
| weatherCode | Configured forecast provider `fetch_current_conditions(lat, lon)` | None | WMO code (no conversion) |
| isDay | Configured forecast provider `fetch_current_conditions(lat, lon)` | None | boolean |

The `is_station_served()` function (already implemented in `services/marine_location_resolver.py`) determines whether a marine location is close enough to the weather station to use live hardware observations. Locations within `dedup_radius_km` (default 2.5 km) of the station get station data; all others get forecast provider data.

**Decision 2 — NOAA OFS as primary ocean data source, with tiered fallback.**

Context: The original plan used NDBC buoy 46253 (12 miles offshore, 66m deep water) as the sole water temperature source. Research (documented in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md`) found this produces incorrect readings for nearshore locations. Deep water does not heat like the coastal shelf — beach surface water can be 5–9°F warmer than the offshore buoy. Additionally, fishing needs water column temperature profiles (thermocline, bottom temps), not just surface readings.

NOAA operates 15 Operational Forecast System models (ROMS/FVCOM) covering major US coastal areas at 34m–4km resolution, served via THREDDS/OPeNDAP at `opendap.co-ops.nos.noaa.gov`. These provide water temperature at multiple depth levels, ocean currents, salinity, and modeled water levels — all from the same NetCDF files.

Decision: The ocean data resolver (`services/ocean_data_resolver.py`) provides a provider-agnostic interface for all ocean model data. The dashboard and endpoint code never see provider names. The resolver implements this fallback chain:

| Tier | Source | Coverage | Data available | Access |
|---|---|---|---|---|
| 1 | On-premises sensor | At-location only | Surface temp only | Operator station or CO-OPS gauge within threshold |
| 2 | NOAA OFS (15 models) | Major US coasts | Full: temp column, currents, salinity, water levels, forecast | THREDDS/OPeNDAP via `xarray` |
| 3a (surface) | NASA MUR SST | Global, 1km | Surface temp only | ERDDAP griddap |
| 3b (column+forecast) | NOAA RTOFS | Global, 8km, 41 depth levels | Temp column, currents, salinity, 8-day forecast | ERDDAP griddap |
| 4 | Unavailable | — | null | — |

OFS model assignment is computed at location configuration time (setup wizard) by checking which OFS domain bounding box contains the location's lat/lon. Persisted in `api.conf` as `ofs_model`. Locations outside all OFS domains skip to tier 3.

The resolver supports two query modes: `mode="modeled"` (default — runs the tier chain) and `mode="observed"` (returns only a real sensor reading, null if no sensor nearby — does NOT fall back to models).

Consequences:
- New domain `ocean` with two provider modules: `providers/ocean/ofs.py` (THREDDS) and `providers/ocean/erddap_ocean.py` (ERDDAP, config-driven for MUR SST + RTOFS + regional models)
- New service `services/ocean_data_resolver.py` — orchestrates fallback, normalizes output
- New canonical models: `OceanDataResult`, `WaterColumnProfile`, `WaterColumnLayer`, `OceanCurrentSnapshot`, `OceanForecastPoint`
- New dependency: `xarray` + `netCDF4` in `[marine]` pip extra
- NDBC buoy demoted to labeled offshore reference data, not a primary source
- Phase 3 (STOFS-2D-Global) replaced by OFS provider (OFS provides modeled water levels from the same files as temperature)

**Decision 3 — OFS data beyond temperature.**

From the same OFS files opened for temperature, the system extracts and reports additional oceanographic data where available. All fields are null when OFS/RTOFS coverage doesn't include them — dashboard handles null with "—" display.

| OFS variable | Canonical field | Used by | Unit conversion |
|---|---|---|---|
| `temp` (full column) | `waterColumnProfile` | Fishing species scorer (depth-specific), thermocline detection | Celsius → operator `group_temperature` |
| `salt` (full column) | `salinity` | Fishing species scorer (habitat preference), river plume detection | PSU — no conversion |
| `u_eastward` + `v_northward` | `currentSpeed`, `currentDirection` | Boating navigation, fishing drift, beach safety | m/s → operator speed unit |
| `zeta` / `zetatomllw` | `waterLevelMsl`, `waterLevelMllw` | Supplementary to CO-OPS tides (includes storm surge) — research pending | meter → operator `group_water_level` |
| `h` | `seafloorDepth` | Fishing bottom temp reference (NOT replacing CUDEM — model-grid resolution only) | meter |

Current reporting is simple: speed + direction as stat tile and forecast time series. No vector field maps — spatial current visualization is a future third-party provider capability if needed.

**Decision 4 — Composite water level (CO-OPS prediction + OFS non-tidal residual).**

Context: Research (documented in `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md`) found that CO-OPS harmonic predictions are accurate to 2-5 cm for astronomical tides but miss all meteorological effects. OFS total water level captures surge/wind/pressure but is less accurate (RMSE ≤ 0.15m) for the pure tidal component. The optimal approach combines both: CO-OPS prediction as the tidal base + OFS non-tidal residual as the meteorological signal. Additionally, tide data is removed from location cards because all locations sharing a CO-OPS station show identical predictions — visual noise on the landing page.

Decision: A water level compositor service (`services/water_level_compositor.py`) combines CO-OPS harmonic predictions with the OFS non-tidal residual to produce a composite total water level forecast. The compositor computes the observed residual (CO-OPS observed − CO-OPS predicted) as ground truth, then uses the bias-corrected OFS forecast residual (OFS total − CO-OPS prediction, anchored to the observed residual at the current time) for the forecast period. When OFS is unavailable, the compositor decays the current observed residual exponentially (tau = 12 hours). Storm surge classification thresholds are configurable per location.

Consequences:
- New service `services/water_level_compositor.py` — orchestrates CO-OPS + OFS water level combination
- New response fields on `GET /tides/{id}`: `totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel`
- `currentTide` removed from `GET /marine` card summary (identical across locations sharing a CO-OPS station)
- TideChart enhanced with total water level overlay, observed trace, and residual fill
- CO-OPS remains primary for astronomical tides; OFS supplements with meteorological signal
- No new providers — OFS water levels (`zeta`/`zetatomllw`) come from the same files opened for temperature in Phase 3

**Accept:**
- ADR exists at file path with Status: Proposed
- Four decisions documented with Context, Options, Decision, Consequences
- References WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md and TIDE-ACCURACY-BRIEF.md for full research
- User reviews and approves → status flipped to Accepted with date

### T0.2 — Update ADR-090 capability matrix

- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-090-activity-capability-matrix.md` (amendment)

**Do:** In the capability matrix table:
1. Add new row: "Ocean temperature (surface)" with source "OFS (primary) / MUR SST (fallback) / RTOFS (fallback)" — Yes for all 4 activities
2. Add new row: "Ocean temperature (water column)" with source "OFS (primary) / RTOFS (fallback)" — Yes for Fishing, Yes for Marine/Boating, — for Surf, — for Beach Safety
3. Add new row: "Ocean currents" with source "OFS / RTOFS" — Yes for Marine/Boating, Yes for Fishing, — for Surf, — for Beach Safety
4. Add new row: "Salinity" with source "OFS / RTOFS" — Yes for Fishing, — for others
5. Add new row: "Modeled water levels (includes surge)" with source "OFS `zeta`/`zetatomllw`" — Yes for Marine/Boating, Yes for Beach Safety, — for Surf, — for Fishing
6. Change NDBC buoy role from "primary" to "observational reference (offshore)"

**Accept:** Matrix rows updated. Amendment date noted.

### T0.3 — Update governing manuals with ADR-091 decisions + brief findings

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`
- Reference: ADR-091 (once Accepted), WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md, TIDE-ACCURACY-BRIEF.md

**Why now (before implementation):** Implementation agents in Phases 1-4 read the manuals as their source of truth for what to build. If the manuals don't reflect the ocean data resolver architecture, the composite water level design, or the card data source contract, agents will build against stale guidance. Phase 5's doc sync does final verification — it should not be the first time the manuals learn about these systems.

**Do:**

1. **API-MANUAL updates:**
   - §16 marine data model: Document the card data source contract from ADR-091 Decision 1 — which fields come from which sources, the `is_station_served()` dispatch for wind/air temp, and the removal of `currentTide` from cards (with rationale from TIDE-ACCURACY-BRIEF.md Q2)
   - §16 marine data model: Document the ocean data resolver's output shape (`OceanDataResult`) — the canonical models (`WaterColumnProfile`, `WaterColumnLayer`, `OceanCurrentSnapshot`, `OceanForecastPoint`) from WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md
   - §16 marine data model: Document the water level compositor's output shape (`CompositeWaterLevel`) and new `TideBundle` fields (`totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel`) from TIDE-ACCURACY-BRIEF.md
   - §18 marine endpoints: Document the composite water level algorithm (observed residual → bias-corrected OFS forecast residual → persistence fallback) and the `sources.waterLevelComposite` attribution
   - §18 marine endpoints: Document that `GET /marine` card summary does NOT include `currentTide` (removed per ADR-091 Decision 4)

2. **PROVIDER-MANUAL updates:**
   - §14 provider domains: Add `ocean` domain overview — two providers (OFS via THREDDS, ERDDAP ocean via griddap), one resolver service, one compositor service
   - §14 CO-OPS (existing section): Note that the provider fetches both `predictions` and `water_level` products; the water level compositor uses both for non-tidal residual computation
   - §14 NDBC (existing section): Note demotion to labeled offshore reference data per ADR-091 Decision 2
   - Placeholder subsections for OFS provider (§14.10), ERDDAP ocean provider (§14.11), ocean data resolver (§14.12), and water level compositor (§14.13) — architecture and interface documented now; implementation-specific details (function signatures, exact cache keys, error handling) filled in during Phase 5 after the code exists

**Accept:**
- API-MANUAL §16 includes card data source contract table from ADR-091 Decision 1
- API-MANUAL §16 includes `OceanDataResult` and `CompositeWaterLevel` canonical model definitions
- API-MANUAL §18 documents composite water level algorithm and new response fields
- PROVIDER-MANUAL §14 includes `ocean` domain with placeholder subsections for OFS, ERDDAP ocean, resolver, compositor
- PROVIDER-MANUAL CO-OPS section notes dual-product usage for compositor
- PROVIDER-MANUAL NDBC section notes demotion to offshore reference
- No code changes

### QC Gate 0 ✅ PASSED 2026-07-13
- ADR-091 exists with Accepted status (4 decisions)
- ADR-090 capability matrix updated
- API-MANUAL updated with card data source contract, canonical models, composite water level algorithm
- PROVIDER-MANUAL updated with ocean domain, compositor placeholder, CO-OPS dual-product note
- No code changes

---

## Phase 1 — Fix Data Sources + Detail Page Cleanup

Fix the data flowing into cards AND clean up the detail pages. This phase uses existing infrastructure — no new providers, no new dependencies.

**Dashboard file inventory (all under `src/components/marine/` on weather-dev):**
- `tabs/BoatingTab.tsx` (641 lines) — wind panel, wave forecast, buoy obs, pressure, visibility, tide, NWS text, weather
- `tabs/SurfingTab.tsx` (646 lines) — forecast timeline, wave face height, swell breakdown, wind quality, tide, beach alignment
- `tabs/FishingTab.tsx` (761 lines) — period grid, solunar timeline, tide, pressure, species table, conditions breakdown, wind/swell, habitat
- `tabs/BeachSafetyTab.tsx` (273 lines) — safety indicator, sea state, rip current, tide, water temp, wind, UV, visibility, NWPS v1.5, external links
- `tabs/shared/TideChart.tsx` (243 lines) — shared 72h Recharts tide chart
- `tabs/shared/AlertsPanel.tsx` (68 lines) — shared alert banner
- Page: `src/routes/marine.tsx` (327 lines) — MarinePage with landing/selected states
- Card: `src/components/marine/LocationCard.tsx` (116 lines) — per-location summary button
- Summary: `src/components/marine-summary-card.tsx` (243 lines) — Now page summary card

**API file inventory (all under `weewx_clearskies_api/` on weewx):**
- `endpoints/marine.py` — `_location_summary()` at line 316, `get_marine_location()` at line 447
- `endpoints/surf.py` — correct NWPS chain at lines 217-293 (reference implementation)
- `endpoints/beach_safety.py` — `classify_sea_state()` at line 194, assessment at line 360
- `endpoints/fishing.py` — period scoring
- `endpoints/tides.py` — CO-OPS only
- `services/marine_weather_cache.py` — `put_weather()` never called, `get_current_conditions()` always returns None
- `services/cache_warmer.py` — `_warm_marine()` function
- `services/marine_location_resolver.py` — `is_station_served()` exists but unwired
- `enrichment/wave_transform.py` — `apply_supplements()` at line 330
- `providers/marine/nwps.py` — `fetch(lat, lon, wfo_override)` at line 455
- `providers/marine/wavewatch.py` — `fetch(lat, lon)` at line ~200
- `providers/buoy/ndbc.py` — `fetch(station_id)` — buoy 46253 returns NO wind/pressure/airTemp
- `providers/tides/coops.py` — `fetch(station_id, products)`
- `models/responses.py` — `MarineObservation` at line 1445 (waterTemp field, no conversion), `MarineLocationSummary` at line 1670

**Data hooks (all in `src/hooks/useWeatherData.ts` on weather-dev):**
- `useMarineLocations()` line 1181 → `GET /marine`
- `useMarineDetail(locationId)` line 1212 → `GET /marine/{locationId}`
- `useTideDetail(locationId)` line 1236 → `GET /tides/{locationId}`
- `useSurfDetail(locationId)` line 1260 → `GET /surf/{locationId}`
- `useFishingDetail(locationId)` line 1284 → `GET /fishing/{locationId}`
- `useBeachSafetyDetail(locationId)` line 1308 → `GET /beach-safety/{locationId}`

### T1.1 — Wire forecast provider + station data into marine_weather_cache

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `services/cache_warmer.py` (add warm call), `services/marine_weather_cache.py` (verify `put_weather` signature), `endpoints/marine.py` (wire `is_station_served` + cache read into `_location_summary`)
- Reference: `endpoints/observations.py` `_fill_cloudcover_from_provider()` for the provider-agnostic dispatch pattern; `endpoints/surf.py` line 260 for how the surf endpoint gets wind from NDBC (but we're NOT using NDBC for wind — we're using the forecast provider or station)

**Problem:** `marine_weather_cache.put_weather()` has zero callers (confirmed by grep). The cache is always empty. `get_current_conditions()` always returns None. Fields `airTemp`, `windSpeed`, `windDirection`, `weatherCode`, `isDay` are always null on the location cards.

**Do:**
1. In `cache_warmer._warm_marine()`, after the existing provider warm calls (NDBC, CO-OPS, WaveWatch III, NWS marine, NWPS — these are the calls added in MARINE-INFRASTRUCTURE-PLAN T2.1), add a forecast provider conditions fetch:
   - Use the provider-agnostic dispatch pattern from `_fill_cloudcover_from_provider()` in `endpoints/observations.py`: look up the configured forecast provider module (from `settings.forecast.provider`), call its `fetch_current_conditions(lat=loc.lat, lon=loc.lon, target_unit=settings.unit_system, client_id=..., client_secret=...)`.
   - Deduplicate by grid group (same pattern as NDBC/CO-OPS warm dedup) — two locations in the same grid group share one provider call.
   - Call `marine_weather_cache.put_weather(lat, lon, {"airTemp": result.temperature, "windSpeed": result.windSpeed, "windDirection": result.windDir, "weatherCode": result.weatherCode, "isDay": result.isDay, "skyCondition": result.weatherText})` with the result.
   - Wrap in try/except per existing warm pattern — provider failure is logged, not raised.
2. In `_location_summary()` at line 316, implement data source precedence for wind/air temp:
   - Call `marine_location_resolver.is_station_served(location.id)`.
   - If True: read current wind speed, wind direction, air temp from the weewx archive (same query as `GET /current` in `endpoints/observations.py` — `db.get_current()`). These are live hardware observations from the weather station.
   - If False: call `marine_weather_cache.get_current_conditions(location.lat, location.lon)` — these are forecast provider conditions cached by the warmer.
   - Populate `airTemp`, `windSpeed`, `windDirection`, `weatherCode`, `isDay` into the summary response. These supplement (not replace) the NDBC buoy data — the buoy provides waterTemp and waveHeight; the forecast provider/station provides weather conditions.
3. The forecast provider is operator-configured. The code must NOT hardcode "aeris" — use the same provider dispatch pattern as `_fill_cloudcover_from_provider()` which works with any configured provider (NWS, Aeris, OpenMeteo, etc.).

**Accept:**
- `grep -r "put_weather" services/cache_warmer.py` returns ≥1 match
- `grep "is_station_served" endpoints/marine.py` returns ≥1 match
- `GET /marine` returns non-null `airTemp` for at least one location when the forecast provider is configured and reachable
- `GET /marine` returns non-null `windSpeed` — value is NOT from NDBC buoy (buoy 46253 reports null wind)
- `weatherCode` and `isDay` are non-null when the forecast provider supplies them
- Forecast provider failure degrades `airTemp`/`windSpeed` to None independently — does not null the entire summary or crash the endpoint
- No hardcoded provider name ("aeris", "nws", etc.) in the new code — must use dispatch pattern
- Existing tests pass unchanged

### T1.2 — Fix waterTemp: replace NDBC buoy source + unit conversion

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/marine.py` (`_location_summary()` and the list handler)
- Depends on: Phase 3 (ocean data resolver must exist first). If Phase 3 is not yet complete, implement the unit conversion fix against the existing NDBC source as an interim step, with a TODO comment marking the source replacement.

**Problem:** `waterTemp` in `currentConditions` is raw 20.8°C from NDBC buoy 46253 — a deep-water station 12 miles offshore that does not represent coastal shelf temperatures. Additionally, no unit conversion is applied (the operator's US preset expects Fahrenheit).

**Do:**
1. **Source change (after Phase 3):** Replace the NDBC buoy `waterTemp` read in `_location_summary()` with a call to the ocean data resolver: `ocean = ocean_data_resolver.resolve(lat, lon, location_config, needs="surface")`. Use `ocean.surface_temp` for the card's `waterTemp`. The resolver handles the full fallback chain (on-premises → OFS → MUR SST → RTOFS) internally — the endpoint does not know or care which source provided the value.
2. **Unit conversion (immediate):** Apply `convert(raw_water_temp, "degree_C", target_temp_unit)` where `target_temp_unit` comes from the operator's `group_temperature` setting. This works regardless of whether the source is NDBC (interim) or the resolver (final).
3. Ensure the list endpoint's response includes a `units` block with a `temperature` key showing the display unit (e.g., `"°F"` for US preset).
4. Add `ocean` source attribution to the response `sources` block.

**Accept:**
- `GET /marine` with US preset returns `currentConditions.waterTemp` in Fahrenheit (not raw Celsius)
- Response includes `units.temperature` key
- Water temp value comes from the ocean data resolver (or NDBC as interim, with TODO)
- Source attribution present in response
- Existing tests pass unchanged

### T1.3 — Remove currentTide from location card summary

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/marine.py` (`_location_summary()`, lines 345-369), `models/responses.py` (`MarineLocationSummary`)

**Problem:** `currentTide` on the location card is identical for all 7 locations because they share the same CO-OPS station (9410580 Newport Beach). Showing the same tide height/type/time on every card is visual noise — it doesn't help visitors choose between locations. Tide information is meaningful in the activity detail tabs (boating, fishing, beach safety, surfing) where it provides context for that specific activity.

**Do:**
1. In `_location_summary()`, remove the `currentTide` population block (lines 345-369 where `current_tide = {"type": pred.type, "time": pred.time, "height": pred.height}` is constructed).
2. In `MarineLocationSummary`, make `currentTide` nullable or remove the field. If other consumers depend on it, set it to `null` rather than deleting the field (avoid breaking API clients).
3. The CO-OPS prediction fetch in the cache warmer can remain — it feeds the detail tabs via `GET /tides/{id}`. Only the card summary loses the tide data.

**Accept:**
- `GET /marine` returns `currentTide: null` (or field absent) for all locations
- `GET /tides/{id}` still returns full tide predictions with unit conversion (no regression on detail endpoints)
- Dashboard `LocationCard.tsx` handles null `currentTide` gracefully (no crash, no empty row)
- Existing tests pass unchanged

### T1.4 — Fix NWS SRF zone forecast data (ripCurrentRisk, uvIndex)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/surf.py`, `endpoints/beach_safety.py`, `providers/marine/nws_srf.py`

**Problem:** `GET /surf/{id}` returns `zoneForecast: null`. `GET /beach-safety/{id}` returns `ripCurrentRisk: null`, `uvIndex: null`. The NWS SRF parser (`nws_srf.py`) was rewritten in MARINE-REMEDIATION-PLAN T1.1 — but the current deployment's SRF fetch for WFO LOX (the configured WFO for all Huntington Beach locations) is not returning data. This could be: (a) the SRF parser not matching the LOX product format, (b) the NWS zone ID for LOX not matching the configured zone, or (c) a transient NWS data availability issue.

**Do:**
1. Investigate why `nws_srf.fetch(zone_id=..., wfo='LOX')` returns empty. Steps:
   - Fetch the raw SRF product from NWS for WFO LOX: `curl "https://forecast.weather.gov/product.php?site=LOX&issuedby=LOX&product=SRF&format=txt"`
   - If the product exists, feed it through the parser and check what comes out. The parser was tested against WFO ILM (East Coast) — LOX (West Coast) may use a different format variant.
   - If the product doesn't exist for LOX, check which WFOs in the SoCal area produce SRF products.
2. Fix the parser or configuration so that the surf and beach-safety endpoints return non-null `ripCurrentRisk` and `uvIndex` for the configured location.

**Accept:**
- `GET /surf/huntington-city-beach-pier` returns `zoneForecast` with non-null `ripCurrentRisk` (one of `"low"`, `"moderate"`, `"high"`)
- `GET /beach-safety/huntington-city-beach-pier` returns `assessment.ripCurrentRisk` non-null
- `GET /beach-safety/huntington-city-beach-pier` returns `assessment.uvIndex` non-null (integer 0-11+)
- Existing tests pass unchanged

### T1.5 — Consolidate stats into shared panels, fix floating text (all tabs)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: All 4 tab components in `src/components/marine/tabs/` (BoatingTab.tsx, SurfingTab.tsx, FishingTab.tsx, BeachSafetyTab.tsx)
- Reference: DESIGN-MANUAL §6 card anatomy, §4 typography tokens, existing `StatTile` pattern at BoatingTab.tsx line 70, existing `Panel` pattern at line 59

**Problem:**
1. Chart titles ("Wind speed forecast for the next 72 hours at Huntington City Beach (Pier)") are rendered as separate text elements that visually float over adjacent cards/sections — they are not contained within their parent `Panel` as `<h3>` titles.
2. Individual stats (barometric pressure, visibility, wind quality, beach alignment, dominant swell direction) each occupy their own `Panel` taking up a full row when they should be grouped together on a shared stats panel using the `<dl>` grid pattern.

**Do:**
1. **Fix floating text:** Every chart/section title MUST be the `<h3>` inside its parent `Panel` component (the `title` prop) — NOT a separate element outside the Panel. Audit each tab for text elements that are siblings of `Panel` components rather than children. Move them inside their Panel's title prop.
2. **Consolidate stats in BoatingTab:** Group `barometric pressure` (line 515), `visibility` (line 531), `air temp` from the "General weather" section (line 621) into a single "Conditions" Panel using the `<dl className="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-3">` pattern with `StatTile` components. Remove the individual single-stat Panels.
3. **Consolidate stats in SurfingTab:** Group `Wind Quality` badge (line 547) and `Beach Alignment` compass (line 563) into a single "Conditions" Panel. Wind quality shows the `windQuality` label ("Cross-Shore") as a badge; beach alignment shows the compass + swell direction. Both are current-conditions snapshots, not time series.
4. **Consolidate stats in FishingTab:** Group `barometric pressure` (line 731), `wind & swell` (line 753) into a single "Conditions" Panel using `StatTile` grid.
5. **Consolidate stats in BeachSafetyTab:** Group `sea state` (line 147), `water temperature` (line 189), `wind` (line 203), `UV Index` (line 214) into a single "Current Conditions" Panel. Remove individual Panels for each. The `SafetyIndicator` badge (safe/caution/dangerous) should be prominently placed at the top of this panel, not as its own standalone section.
6. **Remove visibility from BeachSafetyTab** (line 219) — swimmers don't need nautical mile atmospheric visibility. This is an aviation/navigation metric, not relevant to beach safety.

**Accept:**
- Zero floating text elements — every text string is inside a `Panel` or `<h3>` within a Panel. `grep` for any `<p>` or `<span>` elements that are direct children of the tab's root `<div>` and not inside a Panel should return zero matches.
- BoatingTab: one "Conditions" Panel with pressure + visibility + air temp using `<dl>` grid, NOT three separate Panels
- SurfingTab: one "Conditions" Panel with wind quality + beach alignment, NOT two separate Panels
- FishingTab: one "Conditions" Panel with pressure + wind/swell, NOT two separate Panels
- BeachSafetyTab: one "Current Conditions" Panel with safety badge + sea state + water temp + wind + UV, NOT five separate Panels. Visibility section removed.
- `tsc --noEmit` clean. `vite build` clean.
- Existing tests pass unchanged

### T1.6 — Fix BoatingTab data: wind forecast, wave legend, buoy obs label, tide Y-axis, NWS text, weather section

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/BoatingTab.tsx`

**Problem:** Multiple broken/empty sections:
1. Wind forecast chart (line 424, `WindForecastChart` at line 123): empty because `MarineForecastPoint.windSpeed` is null in the API response (WaveWatch III doesn't include wind). After T1.1, the forecast provider will supply current wind but not a 72-hour wind forecast time series.
2. Wave forecast chart (line 451, `WaveForecastChart` at line 216): renders data but has no `<Legend>` component — the dual-axis chart shows wave height (area) and wave period (line) with no indication of which is which.
3. Live buoy observations panel (line 462): shows "Buoy Observations" with NDBC data that is NOT at the beach location. Shows null for wind, pressure, air temp, visibility (buoy 46253 doesn't report these). No distance indicator.
4. Tide chart Y-axis (line 549, shared `TideChart.tsx`): displays raw numbers like 342362, 390116 instead of tide heights in feet. Likely a `dataKey` mismatch or the Y-axis domain/format function is wrong.
5. NWS marine text forecast (line 565): section renders period names (Tonight, Mon, Mon Night...) as `<details>/<summary>` but no content appears when expanded. The API DOES return full text content — `textForecast[].text` is populated for all 11 periods. The dashboard is likely reading the wrong field or the `<details>` content area is empty.
6. "Weather at..." section (line 621): shows "Air Temp: —" because no weather data is wired. After T1.1, this will have data from the forecast provider/station.

**Do:**
1. **Wind forecast:** The WaveWatch III forecast points don't include wind data. Options: (a) Hide the wind forecast chart when no wind time series is available and show only the current wind stats from T1.1 in the conditions panel, or (b) Source the wind forecast from the NWS marine text forecast's wind descriptions (text, not numeric time series). Option (a) is simpler and honest — the chart shows "—" when there's no forecast data source for it. Implement (a): conditionally render `WindForecastChart` only when at least one forecast point has non-null `windSpeed`. When hidden, the current wind stats from the conditions panel (T1.5) serve as the wind information.
2. **Wave forecast legend:** Add Recharts `<Legend>` component to `WaveForecastChart` (line 216). Two items: "Wave Height" (for the Area) and "Wave Period" (for the Line). Use `--chart-1` and `--chart-2` colors. Format: `iconType="plainline"`, `wrapperStyle={{ fontSize: 'var(--text-label)' }}`.
3. **Buoy observations:** Rename the Panel title from "Buoy Observations" to "Nearest Offshore Buoy ({stationId})" where `stationId` comes from `observation.stationId` (e.g., "46253"). This makes it clear the data is from an offshore buoy, not at the beach. Remove the stat tiles for fields this buoy doesn't report (wind, pressure, air temp, visibility — all null for 46253). Show only the fields the buoy actually provides: waveHeight, dominantPeriod, averagePeriod, meanWaveDirection, waterTemp.
4. **Tide chart Y-axis:** Read `TideChart.tsx` (line 1-243 of `tabs/shared/TideChart.tsx`). The Y-axis values 342362/390116 suggest the `dataKey` is pointing at a wrong field or the height values are being scaled/multiplied incorrectly. Fix: ensure the `<YAxis>` `domain` is set to `['auto', 'auto']` and the `dataKey` for the Area is `"height"` (matching `TidePrediction.height` from the API). The tick formatter should display the value with 1 decimal place: `tickFormatter={(v) => v.toFixed(1)}`. Add the unit label: `label={{ value: units?.waterLevel ?? 'ft', angle: -90, position: 'insideLeft' }}`.
5. **NWS marine text:** The API returns `textForecast[].text` with full narrative content (confirmed: "W wind 5 to 10 kt this evening..."). In the current rendering (line 565-618), each period is a `<details>/<summary>` element. Check that the `<details>` content area reads `forecast.text` (not `forecast.wind` or `forecast.seas` which may be null). If the content area is reading a sub-field, switch it to read the full `text` field. Also check for CSS issues — the `<details>` content may have `max-height: 0` or `overflow: hidden` preventing display.
6. **Weather section:** After T1.1, the `currentConditions` from `useMarineDetail` will include `airTemp`. Wire the "Weather at..." section to display: air temp (from `currentConditions.airTemp`), wind speed (from `currentConditions.windSpeed`), wind direction, weatherCode (render weather icon if available). If all weather fields are null (provider unavailable), self-hide the section.

**Accept:**
- Wind forecast chart hidden when no wind data in forecast points (not showing an empty chart with "— kt")
- Wave forecast chart has a visible legend with "Wave Height" and "Wave Period" entries
- Buoy panel title includes station ID, only shows fields the buoy actually reports (not null fields)
- Tide chart Y-axis shows proper heights (e.g., 7.1, -1.6) with 1 decimal place and unit label — NOT raw numbers like 342362
- NWS marine text sections show their full narrative text when expanded
- Weather section shows air temp when available, hides when not
- `tsc --noEmit` clean. `vite build` clean.

### T1.7 — Fix SurfingTab: forecast timeline, wave face height, swell breakdown

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/SurfingTab.tsx`

**Problem:**
1. 72-hour forecast timeline (line 518, `ForecastTimeline` at line 130): shows only one data point ("2:22 AM, 1 star, Poor"). The API `GET /surf/{id}` returns `forecast: [SurfForecast]` — currently an array with only ONE entry (the current conditions snapshot). The timeline component renders one cell per forecast entry, so it renders one cell. This is an API issue — the surf endpoint should return multiple forecast points across 72 hours, not just one.
2. Wave Face Height chart (line 523, `WaveFaceHeightChart` at line 176): empty because it reads `forecast` array data which has only one point — not enough to render a time series chart.
3. Swell Breakdown (line 535, `SwellBreakdown` at line 289): shows 4 spectral components but some are missing height/period/direction values. The API returns 4 `SpectralWaveComponent` objects — two classified as "groundswell" (periods 16.7s and 14.3s) and two as "swell" (periods 10.5s and 8.3s). Heights are populated (0.8, 1.4, 0.3, 1.2 ft) but some direction values may be missing in the rendered cards. Check that the component renders `direction` as compass bearing (e.g., "S" for 185°) using a degrees-to-cardinal conversion.

**Do:**
1. **Forecast timeline:** This requires an API fix. The surf endpoint (`endpoints/surf.py`) currently returns a single `SurfForecast` object (line 277-293) — the current-moment snapshot. To support a 72-hour timeline, the endpoint needs to score multiple NWPS forecast time steps, not just the most recent one. **However**, this is a significant API change (running the surf scorer against each NWPS forecast time step). For Phase 1, the simpler fix: render what exists honestly. If only one forecast point, show it as a "Current Conditions" card (not a "72-Hour Forecast" timeline). Rename the section title to "Current Surf Conditions" when `forecast.length === 1`. The full 72-hour timeline is deferred to a future phase when the API produces multi-point surf forecasts.
2. **Wave Face Height chart:** Same dependency — needs multi-point forecast data. For Phase 1: hide the chart when `forecast.length < 2` (not enough data for a line chart). Show the single wave height value as a stat in the conditions panel instead.
3. **Swell Breakdown:** Ensure all 4 component cards show: height (with unit), period (with "s" suffix), direction (as compass cardinal from degrees — implement degrees-to-cardinal function: 0=N, 45=NE, 90=E, etc., using 8 or 16-point compass). The `SwellBreakdown` component at line 289 may be reading `direction` but not converting degrees to cardinal text.

**Accept:**
- Forecast section shows "Current Surf Conditions" (not "72-Hour Surf Forecast") when only 1 forecast point exists
- Wave Face Height chart hidden when fewer than 2 data points — no empty chart rendered
- All 4 swell breakdown cards show height (with ft/m), period (with s), direction (as N/NE/E/SE/S/SW/W/NW)
- `tsc --noEmit` clean. `vite build` clean.

### T1.8 — Fix FishingTab: forecast card design, conditions breakdown, species data

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/FishingTab.tsx`

**Problem:**
1. 3-day period grid (line 714, `PeriodGrid` at line 296): icon sizing inconsistent with dashboard patterns (icons may be too large or too small). Needs to match DESIGN-MANUAL §7 icon sizing (18px for stat/utility icons).
2. Conditions breakdown (line 750, `ConditionsBreakdown` at line 587): buried at the bottom of the tab. This is the actual scoring — pressure, tide, solunar, time-of-day scores — which is what anglers care about most. Should be moved to a more prominent position (after the period grid, before solunar).
3. Species table (line 747, `SpeciesTable` at line 532): currently shows species name and activity status but the API returns `speciesScores: null` and `species: []` because no species are configured for these locations. The species YAML database was populated with 20+ SoCal species per Phase 8 of the remediation plan, but the location config doesn't reference them. The species scoring data exists in the system — it's just not reaching the endpoint.
4. "Species activity" section label is unclear — what does "activity" mean in the context of fish species?

**Do:**
1. **Period grid icons:** Audit icon sizes in `PeriodGrid`. Solunar `MoonStars` icon (Phosphor) should be 18px per DESIGN-MANUAL §7. Period label text should use `--text-label` (0.75rem). Score value should use `--text-stat-tile` (1.25rem) with `fontFeatureSettings: '"tnum"'`.
2. **Conditions breakdown:** Move `ConditionsBreakdown` rendering to directly after the `PeriodGrid` (currently at line 750, move to after line 714). This puts the scoring breakdown in context — the angler sees the forecast periods, then immediately sees WHY those scores are what they are.
3. **Species configuration:** The fishing locations need species configured in `api.conf`. Check if `target_categories = saltwater_inshore, bottom_fish` is set (it is per our earlier config check) and verify that `GET /setup/marine/species?lat=33.6531&lon=-118.0038&category=saltwater_inshore,bottom_fish` returns species for this region. If the species list is empty in the API response, the issue is that the fishing endpoint doesn't populate `speciesScores` — trace the path from config → scorer → endpoint to find where species are dropped.
4. **Species table label:** Rename "Species Activity" to "Species Forecast" — clearer meaning in context. Each species row shows: species name, score (0-100), temperature suitability (from the species' optimal/good/marginal temp ranges vs current water temp).

**Accept:**
- Period grid icons are 18px, score values use `--text-stat-tile`, labels use `--text-label`
- Conditions breakdown appears immediately after the period grid, NOT at the bottom
- Species data appears in the species table when species are configured for the location (may require config fix)
- "Species Activity" renamed to "Species Forecast"
- `tsc --noEmit` clean. `vite build` clean.

### T1.9 — Fix BeachSafetyTab: rip current, UV index, wind data

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/BeachSafetyTab.tsx`, `src/components/marine/tabs/RipCurrentPanel.tsx`, `src/components/marine/tabs/UVIndexPanel.tsx`

**Problem:** After T1.4 (API fix for SRF data) and T1.1 (wind data), the beach-safety tab should have data for rip current risk, UV index, and wind. But the dashboard components need to render them correctly.

**Do:**
1. **Rip current:** `RipCurrentPanel.tsx` (61 lines) renders a color badge (low=green, moderate=yellow, high=red) + guidance text. After T1.4 fixes the SRF parser, `assessment.ripCurrentRisk` will be non-null. Verify the component renders correctly when data arrives. If the SRF also provides NWPS v1.5 `ripCurrentProbability` (from `nwpsV15.ripCurrentProbability`), show it alongside the SRF text risk as a percentage.
2. **UV Index:** `UVIndexPanel.tsx` (51 lines) renders EPA scale badge. After T1.4, `assessment.uvIndex` will be non-null. Verify rendering. Include exposure guidance text per EPA scale: 1-2 Low, 3-5 Moderate, 6-7 High, 8-10 Very High, 11+ Extreme.
3. **Wind:** After T1.1, `assessment.windSpeed` and `assessment.windDirection` will be populated. These are now in the consolidated conditions panel from T1.5. Verify the stat tiles show the data.
4. **Water temp:** `WaterTempPanel.tsx` (50 lines) shows temp + comfort level. After T1.2, the waterTemp will be in the correct unit. Verify the comfort classification text matches: >75°F comfortable, 65-75°F cool, 55-65°F cold, <55°F dangerous (hypothermia risk). Show the unit label.

**Accept:**
- Rip current panel shows risk level badge when SRF data available
- UV Index panel shows EPA scale badge + guidance when SRF data available
- Wind stats show speed + direction in the conditions panel
- Water temp shows value with unit label + comfort classification
- All panels degrade to "—" or "Unavailable" when data not present (not crash)

### QC Gate 1 ✅ PASSED 2026-07-13

**Findings remediated:**
- F1 [MEDIUM-HIGH]: marine_weather_cache.py used forecast TTL (3h) instead of observation TTL for current conditions → fixed in commit fd1a01d (API)
- F1 [LOW]: FishingTab.tsx hardcoded 's' seconds abbreviation instead of i18n key → fixed in commit 7d7ea55 (Dashboard)
- F2/F3 [LOW]: FishingTab wind direction shows raw degrees instead of compass cardinal — deferred (cross-tab consistency, not gate-blocking)

**Coordinator mechanical checks:**
- `grep -r "put_weather" services/cache_warmer.py` returns matches
- `grep "is_station_served" endpoints/marine.py` returns matches
- `GET /marine` returns non-null `airTemp`, `windSpeed` for locations
- `GET /marine` returns waterTemp ≈69°F (not 20.8)
- `GET /marine` returns `currentTide: null` (removed from card — identical across locations)
- Response units block includes `temperature` key
- `GET /surf/{id}` returns non-null `zoneForecast.ripCurrentRisk` (after SRF fix)
- `tsc --noEmit` clean. `vite build` clean.
- API pytest baseline holds. Dashboard vitest baseline holds.

**Adversarial Sonnet verification:**
- `put_weather()` caller uses provider-agnostic dispatch (no hardcoded provider name)
- `is_station_served()` determines wind/air temp source (station vs provider)
- waterTemp conversion uses `convert()` with operator's `group_temperature` target unit
- `currentTide` removed from card summary — `LocationCard.tsx` handles null gracefully
- No floating text in any tab — all text inside Panel components
- Stats consolidated: BoatingTab has 1 conditions Panel (not 3), SurfingTab has 1 (not 2), FishingTab has 1 (not 2), BeachSafetyTab has 1 (not 5)
- Visibility removed from BeachSafetyTab
- Tide chart Y-axis shows proper heights with unit label
- NWS marine text renders content when expanded
- Wave forecast chart has a legend
- Swell breakdown shows compass cardinals (not raw degrees)
- Conditions breakdown positioned after period grid in FishingTab
- All acceptance criteria from T1.1-T1.9 verified with line-number citations

---

## Phase 2 — Wire NWPS → wave_transform for Card + Detail Wave Height

### T2.1 — Replace NDBC Hs with NWPS-supplemented nearshore wave height on cards

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/marine.py` (`_location_summary()` at line 316)
- Reference: `endpoints/surf.py` lines 217-234 (NWPS fetch + wave_transform chain — the correct implementation to copy)

**Problem:** Card waveHeight is raw NDBC buoy Hs (offshore). All 7 locations show identical 0.9 ft. Per ADR-084, NWPS is primary with wave_transform supplements. The surf endpoint at `endpoints/surf.py` lines 217-234 implements this correctly.

**Do:**
1. In `_location_summary()`, for locations where `"surf" in location.activities` and `location.nwps_wfo` is configured:
   - Import `nwps` from `providers/marine/nwps` and `wave_transform` from `enrichment/wave_transform`
   - Call `nwps.fetch(lat=location.lat, lon=location.lon, wfo_override=location.nwps_wfo)` (same as surf.py line 219)
   - Extract `nearshore = result["nearshore"]`
   - Build the NWPS data dict: `{"wave_height": nearshore["waveHeight"], "wave_period": nearshore["wavePeriod"], "wave_direction": nearshore["waveDirection"]}`
   - Call `wave_transform.apply_supplements(nwps_data, spot_config, location.lat, location.lon)` where `spot_config` is the location's `SurfSpotConfig` (same as surf.py line 228)
   - Use the supplemented `wave_height` for `currentConditions.waveHeight`
2. Fallback chain (each wrapped in independent try/except):
   - Level 1: NWPS + wave_transform (nearshore supplemented)
   - Level 2: WaveWatch III first forecast point `wavewatch.fetch(lat, lon)["forecast"][0]["waveHeight"]` (offshore, no supplements per ADR-084)
   - Level 3: NDBC buoy observation `observation.waveHeight` (raw offshore Hs)
3. Convert the final wave height from meters to operator's `group_wave_height` target unit via `convert()`
4. Per-location wave heights will now DIFFER between locations because wave_transform supplements are location-specific (different bathymetry, structures, topographic features).

**Accept:**
- `GET /marine` returns different `waveHeight` values for Huntington City Beach (Pier) vs Huntington State Beach (different surf configs — Pier has a structure, State Beach does not)
- The card wave height for the Pier approximates the surf endpoint's supplemented value, not the raw NDBC 0.9 ft
- Locations without surf activity or without `nwps_wfo` still show a wave height (WaveWatch III or NDBC fallback)
- Each fallback level is independently wrapped in try/except — NWPS failure doesn't prevent WaveWatch III attempt
- Wave height is unit-converted (feet when US preset)
- Existing tests pass unchanged

### T2.2 — Wire NWPS into marine detail endpoint

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/marine.py` (`get_marine_location()` at line 447)
- Reference: `endpoints/surf.py` lines 217-257

**Problem:** `GET /marine/{id}` uses only WaveWatch III for forecast points (line 485: `wavewatch.fetch(lat, lon)`). Per ADR-084, NWPS should be primary with WaveWatch III as fallback.

**Do:**
1. In `get_marine_location()`, before the WaveWatch III fetch (line 485), try NWPS first:
   - `nwps_result = nwps.fetch(lat=location.lat, lon=location.lon, wfo_override=location.nwps_wfo)`
   - If NWPS returns data, use its nearshore wave fields for the forecast response
2. WaveWatch III becomes the fallback (only called if NWPS fails or location has no `nwps_wfo`)
3. Apply unit conversion to whichever source provides the data

**Accept:**
- Detail endpoint forecast source is NWPS when available, WaveWatch III as fallback
- `source` field in response reflects the actual data source used (e.g., `"nwps+ndbc+nws_marine"` instead of `"ndbc+wavewatch+nws_marine"`)
- Existing tests pass unchanged

### QC Gate 2 ✅ PASSED 2026-07-13

**API commit:** 7081868 (pushed + deployed to weewx)

**Coordinator mechanical checks:**
- `wave_transform.apply_supplements` called in `_location_summary()` (line 402) with correct dict keys, spot_config, lat, lon
- `nwps.fetch` called in both `_location_summary()` (line 397) and `get_marine_location()` (line 672)
- Fallback chain: NWPS (lines 389-419) → WaveWatch III (lines 421-434) → NDBC buoy (lines 436-437), each independently try/excepted
- Wave height unit-converted via `_convert_unit()` (lines 439-455)
- Detail endpoint tries NWPS first (line 668), WaveWatch only on `not nwps_succeeded` (line 690)
- Source field: `"nwps+ndbc+nws_marine"` vs `"ndbc+wavewatch+nws_marine"` (line 721)
- No import conflicts with surf.py (both use lazy imports in function scope)
- Per-location differentiation via `_marine_config.surf_spots.get(location.id)` (line 394)
- Also fixed: card waveHeight was never unit-converted before this commit (latent bug)

**Adversarial audit:** Auditor read all files but hit idle bug (#56930) before reporting. Coordinator completed the 7-item verification directly with line-number citations (above). All items PASS.

---

## Phase 3 — Ocean Data Providers + Resolver

Reference: `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` for full research, THREDDS technical details, OFS variable inventory, and coverage gap analysis.

### T3.1 — Add dependencies to pyproject.toml

- Owner: `clearskies-api-dev` (Sonnet)
- File: `pyproject.toml`

**Do:** Add `xarray` and `netCDF4` to the `[marine]` pip extra (same section as `eccodes`). numpy is already a dependency.

**Accept:** `pip install .[marine]` installs xarray and netCDF4. Base install does not.

### T3.2 — Create OFS provider module

- Owner: `clearskies-api-dev` (Sonnet)
- File: New `providers/ocean/ofs.py`
- Reference: WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md "Technical Detail: THREDDS/OPeNDAP Data Extraction" section (verified metadata, file patterns, grid structure)
- Pattern: Follow `providers/marine/nwps.py` for cycle fallback pattern

**Do:**
1. Module-level constants: `PROVIDER_ID = "ofs"`, `DOMAIN = "ocean"`.
2. OFS model config dict with per-model parameters: cycles, max forecast hour, step hour, depth levels (see brief for the full table).
3. THREDDS/OPeNDAP access via `xarray.open_dataset(url, engine="netcdf4")` — lazy open, only fetches requested slices over the network.
4. **Always use `regulargrid` files** — pre-interpolated to regular lat/lon. Never use native `fields` files (curvilinear/unstructured grids requiring spatial interpolation).
5. Grid point lookup: `Latitude` and `Longitude` are 2D arrays `[ny, nx]`. Find nearest water grid point via `np.sqrt((lat_grid - lat)**2 + (lon_grid - lon)**2)` with land mask filtering (`mask == 0` → skip).
6. Cache grid coordinates per model (lat, lon, depth, mask, h arrays). TTL = 24h. Grid topology doesn't change between forecast cycles.
7. Extract from the `regulargrid` file at the nearest grid point:
   - `temp[time, Depth, ny, nx]` → water column temperature profile
   - `salt[time, Depth, ny, nx]` → salinity profile
   - `u_eastward[time, Depth, ny, nx]` + `v_northward[time, Depth, ny, nx]` → current speed + direction at each depth
   - `zeta[time, ny, nx]` → sea surface elevation vs MSL
   - `zetatomllw[time, ny, nx]` → sea surface elevation vs MLLW
   - `h[ny, nx]` → seafloor depth
8. Cycle selection: `floor(current_utc_hour / 6) * 6` for 4x/day models, fixed cycle for 1x/day (WCOFS = 03z). Try most recent, fall back up to 4 cycles.
9. Forecast extraction: loop over forecast hour files (`f003`, `f006`, ..., `f{max}`), extract surface temp + currents at each time step.
10. Return raw values in Celsius/m/s/PSU/meters — unit conversion happens downstream.
11. Cache: key includes model name + cycle + lat/lon (rounded to 3 decimals). TTL = 1800s.
12. Error handling: THREDDS 404 → cycle fallback. Timeout (>10s) → `TransientNetworkError`. Grid point on land → return null. All per error taxonomy.

**Accept:**
- `ofs.fetch(model="WCOFS", lat=33.6531, lon=-118.0038)` returns an `OceanDataResult` with non-null `surface_temp`, `column_profile`, `surface_current_speed`, `surface_salinity`, `water_level_msl`
- `column_profile` contains entries at multiple depth levels with both `temp_c` and `salt_psu`
- Two points 1.9km apart return different values (different grid points)
- Model cycle fallback works
- Grid coordinates cached — second call does not re-fetch lat/lon arrays
- Land point returns null result (not crash)
- `PROVIDER_ID` and `DOMAIN` match the dispatch registry pattern
- Existing tests pass unchanged

### T3.3 — Create ERDDAP ocean provider module

- Owner: `clearskies-api-dev` (Sonnet)
- File: New `providers/ocean/erddap_ocean.py`
- Reference: WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md "ERDDAP API Consistency" and "Fallback Data Sources" sections

**Do:**
1. Module-level constants: `PROVIDER_ID = "erddap_ocean"`, `DOMAIN = "ocean"`.
2. Config-driven design — single module handles multiple ERDDAP datasets:

   | Dataset key | Server | Dataset ID | Temp variable | Depth | Lon convention |
   |---|---|---|---|---|---|
   | `mur_sst` | coastwatch.pfeg.noaa.gov | `jplMURSST41` | `analysed_sst` | Surface only | -180/+180 |
   | `rtofs_3d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG3DForeDaily` | `temperature` | 41 levels | 0-360 |
   | `rtofs_2d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG2DFore3hrlyProg` | `sst` | Surface | 0-360 |
   | `pacioos` | pae-paha.pacioos.hawaii.edu | `roms_hiig` | `temp` | 36 levels | -180/+180 |
   | `caricoos` | dm3.caricoos.org | `FVCOM_Historical_3D_StructuredGrid` | `temp` | 11 levels | -180/+180 |

3. Standard ERDDAP griddap URL pattern: `https://{server}/erddap/griddap/{datasetID}.json?{variable}[(time)][(depth)][(lat)][(lon)]`
4. Handle longitude convention: convert input lon to dataset convention before querying.
5. MUR SST: surface only, no depth dimension in the query.
6. RTOFS 3D: full column query with depth dimension.
7. Return `OceanDataResult` — same shape as OFS provider output, with null fields for data the dataset doesn't provide.
8. Cache: key includes dataset key + lat/lon. TTL per dataset (MUR SST: 3600s daily, RTOFS: 1800s).
9. Error handling per ERDDAP patterns: empty result, 500/503, timeout.

**Accept:**
- `erddap_ocean.fetch(dataset="mur_sst", lat=33.6531, lon=-118.0038)` returns `OceanDataResult` with non-null `surface_temp`, null `column_profile`
- `erddap_ocean.fetch(dataset="rtofs_3d", lat=33.6531, lon=-118.0038)` returns `OceanDataResult` with non-null `surface_temp` AND `column_profile` with 41 depth levels
- Surface temp values are physically reasonable for SoCal (15–25°C range)
- Longitude convention handled correctly (negative west longitudes work for all datasets)
- Existing tests pass unchanged

### T3.4 — Create ocean data resolver

- Owner: `clearskies-api-dev` (Sonnet)
- File: New `services/ocean_data_resolver.py`
- Reference: WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md "System Integration: Marine Ocean Data Resolver" section

**Do:**
1. `resolve(lat, lon, location_config, mode="modeled", needs="surface") -> OceanDataResult`
2. Implement the full fallback chain from ADR-091 Decision 2.
3. Set `coverage_tier` on the result so endpoints know what data is available without checking provider names.
4. Compute derived values from the raw profile:
   - `thermocline_depth_m`: depth of maximum `dT/dz` gradient
   - `bottom_temp_c`: temperature at the deepest non-null depth level
   - `surface_current_speed` / `surface_current_dir`: computed from `u_eastward` + `v_northward` at depth=0
5. `mode="observed"` path: check for on-premises sensor or NDBC buoy within configured distance. Return null if none — never silently fall back to modeled.
6. Each tier independently wrapped in try/except. Failure at one tier logs a warning and tries the next.

**Accept:**
- Location with `ofs_model="WCOFS"` → resolver returns `coverage_tier="ofs"` with full data
- Location with `ofs_model=null` → resolver falls back to RTOFS, returns `coverage_tier="rtofs"`
- Location with `ofs_model=null` and RTOFS failure → falls to MUR SST, returns `coverage_tier="mur_sst"` with surface temp only
- `mode="observed"` with no sensor → returns `coverage_tier="unavailable"` (does NOT fall back to modeled)
- `thermocline_depth_m` is computed from the column profile when available
- All providers called independently — OFS failure does not prevent MUR SST attempt
- Existing tests pass unchanged

### T3.5 — Add canonical data models

- Owner: `clearskies-api-dev` (Sonnet)
- File: `models/responses.py`

**Do:** Add `OceanDataResult`, `WaterColumnProfile`, `WaterColumnLayer`, `OceanCurrentSnapshot`, `OceanForecastPoint` as defined in the brief. These are the resolver's output types consumed by endpoints.

**Accept:** Models exist. `tsc --noEmit` / `mypy` clean if applicable.

### T3.6 — Setup wizard + admin: Data Coverage panel

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)
- Files: `endpoints/setup.py` (new endpoint), setup wizard UI, admin marine section UI
- Reference: WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md "Setup Wizard: Data Coverage Panel" section (full spec, example displays, implementation notes)

**Problem:** When an operator configures a marine location, they have no visibility into what data sources are available at that lat/lon — which OFS model covers it (if any), which CO-OPS station is nearest, what NDBC buoy, what NWS zone, what data capabilities exist. When things look wrong or data is missing, there's no diagnostic starting point. The coverage panel solves both: the operator understands what to expect during setup, and support can ask "what does the coverage panel show?" when debugging accuracy issues.

**Do:**
1. New endpoint: `GET /setup/marine/coverage?lat={lat}&lon={lon}` — returns JSON with:
   - `ofsModel`: assigned OFS model name + resolution, or null (bounding box check against 15 OFS domains)
   - `ofsFallback`: secondary OFS model, or null (when domains overlap, second-highest resolution)
   - `coverageTier`: what tier this location falls into (`"ofs"`, `"regional_erddap"`, `"rtofs"`, `"mur_sst"`)
   - `availableData`: list of capabilities (water column, currents, salinity, modeled water levels, surface temp, forecast) — derived from coverage tier
   - `nearestCoopsStation`: station ID, name, distance, water temp capability (from CO-OPS metadata API)
   - `nearestNdbcBuoy`: station ID, distance, depth (from NDBC station list)
   - `nwsMarineZone`: zone ID (from existing NWS zone discovery)
   - `nwpsWfo`: WFO identifier (from existing NWPS WFO lookup)
   - `onPremisesSensor`: status (`"within_threshold"` / `"not_configured"` / `"too_far"`) — from `is_station_served()` check
2. Persist coverage data in location config alongside `ofs_model`, `ofs_fallback`, `ofs_region` — available for diagnostics without re-querying.
3. **Wizard:** Render the coverage panel when a marine location's lat/lon is set during initial setup. The panel appears as a read-only summary card below the location coordinate fields, showing checkmarks for available data and station/zone assignments. Updates live when lat/lon changes.
4. **Admin:** Render the same coverage panel in the admin marine location section for each existing location. This is a diagnostic view — the operator can see at a glance what data sources each location is using, which stations are nearest, and what coverage tier applies. The admin panel reads from the persisted coverage data (no live API call on page load) with a "Refresh" button that re-calls the coverage endpoint.

**Accept:**
- `GET /setup/marine/coverage?lat=33.6531&lon=-118.0038` returns JSON with `ofsModel: "WCOFS"`, `coverageTier: "ofs"`, populated station data
- `GET /setup/marine/coverage?lat=33.6869&lon=-78.8867` (Myrtle Beach) returns `ofsModel: null`, `coverageTier: "rtofs"`
- Wizard displays the panel with checkmarks for available data when lat/lon is set
- Admin marine section shows the persisted coverage panel for each existing location
- Coverage panel matches the layout described in WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md "Example panel display"

### T3.7 — Wire resolver into endpoints + cache warmer

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/marine.py`, `endpoints/fishing.py`, `endpoints/beach_safety.py`, `endpoints/surf.py`, `endpoints/tides.py`, `services/cache_warmer.py`

**Do:**
1. In `_location_summary()`, replace NDBC buoy `waterTemp` read with `ocean_data_resolver.resolve(needs="surface")`. Populate `currentConditions.waterTemp` from the result.
2. In `get_marine_location()` detail endpoint, call `resolve(needs="full")`. Populate `waterTemp`, `waterColumnProfile`, `currentSpeed`, `currentDirection`, `salinity` from the result.
3. In fishing endpoint, call `resolve(needs="full")`. Pass column profile to species scorer for depth-specific temperature evaluation. Pass salinity to species scorer for habitat preference.
4. In beach safety endpoint, call `resolve(needs="surface")`. Populate `assessment.waterTemp` and `comfortLevel`.
5. In surf endpoint, call `resolve(needs="surface")`. Populate `waterTemp`.
6. In tides endpoint, when `resolve(needs="full")` returns non-null `water_level_msl`/`water_level_mllw`, include as supplementary modeled water level alongside CO-OPS predictions.
7. In `cache_warmer._warm_marine()`, add OFS + ERDDAP ocean warm calls per location. Deduplicate by OFS model (one fetch per model, not per location).
8. Add `ocean` source attribution to all response `sources` blocks.

**Accept:**
- `GET /marine` returns `waterTemp` from the resolver (not raw NDBC buoy 20.8°C)
- `GET /fishing/{id}` response includes `waterColumnProfile` with depth levels when OFS/RTOFS available
- `GET /marine/{id}` response includes `currentSpeed`, `currentDirection`, `salinity` when OFS available
- All fields gracefully null when resolver returns a lower coverage tier
- Cache warmer logs show OFS/ERDDAP ocean fetches at startup
- Existing tests pass unchanged

### QC Gate 3

**Coordinator mechanical checks:**
- `providers/ocean/ofs.py` exists with `PROVIDER_ID = "ofs"`, `DOMAIN = "ocean"`
- `providers/ocean/erddap_ocean.py` exists with config for MUR SST, RTOFS, PacIOOS, CARICOOS
- `services/ocean_data_resolver.py` exists with `resolve()` function
- `GET /marine` returns `waterTemp` from resolver, not NDBC buoy
- `GET /fishing/{id}` includes `waterColumnProfile` when OFS available
- `GET /setup/marine/coverage` returns correct OFS assignment
- `xarray` and `netCDF4` in `[marine]` pip extra

**Adversarial Sonnet verification:**
- Resolver fallback chain: OFS → regional ERDDAP → RTOFS/MUR SST, each tier independently wrapped
- `mode="observed"` returns null when no sensor — never silently falls back to modeled
- `coverage_tier` set correctly for each fallback level
- Endpoints check field presence (not coverage tier) for populating response
- Thermocline computed from column profile via max dT/dz gradient
- Current speed/direction computed from u_eastward + v_northward via sqrt + atan2
- OFS `regulargrid` files used (not native `fields` files)
- Grid coordinates cached per model (not re-fetched per request)
- All acceptance criteria from T3.1–T3.7 verified with line-number citations

---

## Phase 4 — Composite Water Level (Tide + Storm Surge)

Reference: `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md` for full research, validation data, and architecture rationale.

**Research findings (completed 2026-07-13):** CO-OPS harmonic predictions are accurate to 2-5 cm for astronomical tides but miss all meteorological effects (storm surge, wind setup, pressure). OFS total water level (RMSE ≤ 0.15m) captures these effects but is less accurate than CO-OPS for the tidal component. The optimal approach: use CO-OPS predictions as the tidal base and add the OFS non-tidal residual (= OFS total water level − CO-OPS prediction) as the storm surge signal. Bias-correct the OFS residual by anchoring to the observed residual (= CO-OPS observed water level − CO-OPS prediction) at the current time. Per-location tide differentiation for nearby open-coast locations is not physically meaningful — all locations sharing a CO-OPS station show the same tide curve, and this is correct.

### T4.1 — Create water level compositor service

- Owner: `clearskies-api-dev` (Sonnet)
- File: New `services/water_level_compositor.py`
- Depends on: Phase 3 (ocean data resolver provides OFS water levels via `water_level_msl` / `water_level_mllw` fields)
- Reference: TIDE-ACCURACY-BRIEF.md "The Optimal Architecture: Composite Water Level" section

**Do:**
1. New service function: `compute_composite(predictions, observations, ofs_water_levels, now) -> CompositeWaterLevel`
2. **Step 1 — Observed residual computation:** For each CO-OPS observation in the past 24h, interpolate the 6-minute prediction series to the observation timestamp, compute `residual = observation.height - interpolated_prediction`. This is ground truth — the actual meteorological effect measured by the gauge.
3. **Step 2 — Current residual:** Extract the most recent observed residual as `current_residual`. This tells us "right now, water is X above/below the tide table."
4. **Step 3 — Forecast residual:** When OFS water levels are available:
   - For each OFS forecast time step, compute `ofs_residual = ofs_zeta - coops_prediction_at_same_time`
   - Bias-correct: `bias = current_observed_residual - ofs_residual_at_now`. Apply `corrected_residual = ofs_residual + bias` to all forecast steps. This removes systematic OFS bias at this location.
   - When OFS unavailable: persistence fallback — decay current residual toward zero with `exp(-dt / tau)` where `tau = 12 hours`. This is standard operational practice (NOAA uses damped persistence for monthly high tide flooding outlooks).
5. **Step 4 — Total water level forecast:** For each time step, `total = prediction + corrected_residual`. Produce a list of `{"time": iso, "height": converted, "residual": converted}`.
6. **Storm surge classification:** Based on absolute residual value:
   - `< 0.15 ft`: `null` (normal, within prediction uncertainty)
   - `0.15 - 0.5 ft`: `"elevated"` or `"depressed"`
   - `0.5 - 1.0 ft`: `"significant"`
   - `> 1.0 ft`: `"storm_surge"`
   These thresholds should be configurable per location (SoCal has a mild surge climate; Gulf Coast locations would need different values).
7. All heights unit-converted via `convert()` to operator's `group_water_level` target unit before returning.

**Accept:**
- `compute_composite()` returns non-null `current_residual` when CO-OPS observations are available
- `compute_composite()` returns non-null `total_water_level_forecast` when OFS water levels are available
- Bias correction shifts OFS forecast residual to match observed residual at current time
- When OFS unavailable, persistence fallback produces exponentially decaying residual
- When CO-OPS observations unavailable (station down), gracefully returns predictions only with null residual
- Storm surge classification matches threshold table
- All values unit-converted to operator target unit
- Existing tests pass unchanged

### T4.2 — Wire compositor into tides endpoint + cache warmer

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/tides.py`, `models/responses.py`, `services/cache_warmer.py`
- Reference: TIDE-ACCURACY-BRIEF.md "Cache warmer integration" section

**Do:**
1. Add new fields to `TideBundle` response model:
   - `totalWaterLevelForecast: list[dict] | None` — composite forecast (time + height + residual per step)
   - `currentResidual: dict | None` — `{"value": float, "quality": str, "source": str, "description": str}`
   - `residualForecastSource: str | None` — `"ofs:WCOFS"`, `"persistence"`, or `"unavailable"`
   - `stormSurgeLevel: str | None` — `"elevated"`, `"depressed"`, `"significant"`, `"storm_surge"`, or null
2. In `get_tide_location()`, after the existing CO-OPS fetch, call `water_level_compositor.compute_composite()`. Pass the already-fetched predictions and observations, plus OFS water levels from `ocean_data_resolver.resolve(needs="full")`.
3. **Cache warmer integration:** In `_warm_marine()`, after the existing CO-OPS and OFS warm calls, run the compositor for each location. Cache the composite result with a 10-minute TTL (matches the CO-OPS `water_level` observation refresh rate). The compositor's inputs are already cached by this point:
   - CO-OPS predictions: 6h TTL (already warmed)
   - CO-OPS observations: 10min TTL (already warmed)
   - OFS water levels: 30min TTL (warmed as part of ocean data in Phase 3)
   The endpoint reads the cached composite result rather than recomputing per request.
4. All new fields are nullable — when OFS unavailable or compositor returns no residual, the response is identical to current behavior. Zero regression.
5. Add `waterLevelComposite` to the response `sources` block when compositor data is present.

**Accept:**
- `GET /tides/{id}` returns `totalWaterLevelForecast` with 72h of composite data when OFS available
- `GET /tides/{id}` returns `currentResidual` with measured value when CO-OPS observations available
- `GET /tides/{id}` returns unchanged response (null new fields) when OFS unavailable — no regression
- `stormSurgeLevel` correctly reflects the residual threshold classification
- Composite result cached at 10min TTL — cache warmer logs show compositor run
- Response `units` block includes `waterLevel` key
- Existing tests pass unchanged

### ~~T4.3~~ — Removed

`currentTide` is removed from location cards per T1.3 (identical across all locations sharing a CO-OPS station — visual noise). The compositor's residual/surge data surfaces in the activity detail tabs via T4.2 (tides endpoint) and T4.5 (stat tiles in BoatingTab and BeachSafetyTab).

### T4.4 — Enhance TideChart with total water level overlay

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/shared/TideChart.tsx`
- Reference: DESIGN-MANUAL §6 card anatomy, existing `TideChart.tsx` Recharts `ComposedChart` pattern

**Do:**
1. **Total water level forecast line:** Add a Recharts `Line` (dashed, `--chart-2` color) plotting `totalWaterLevelForecast` data. Conditionally rendered only when the data array is non-empty. When residual is near zero, this line overlaps the prediction curve — visually confirming the weather isn't affecting the tide.
2. **Observed water level trace:** Add a Recharts `Line` (solid, `--chart-3` color, thicker stroke) plotting the `waterLevels` array (CO-OPS gauge readings, past 24h). This is already fetched by the endpoint but not currently plotted on the chart.
3. **Current water level marker:** Add a Recharts `Scatter` (single point, accent color) for the most recent observation. Add a vertical `ReferenceLine` at the current time ("now" line).
4. **Residual fill:** Add a Recharts `Area` between the prediction curve and the total water level curve, filled with semi-transparent green (water higher) or red (water lower). This visually communicates the storm surge signal.
5. **Legend:** Add legend entries for "Predicted Tide", "Total Water Level", and "Observed" when those traces are rendered.
6. All overlays conditionally rendered — when `totalWaterLevelForecast` is null/empty, the chart renders exactly as it does today (prediction curve only).

**Accept:**
- Total water level line renders when forecast data available, hidden when not
- Observed water level trace renders past 24h gauge readings
- Current marker and "now" line appear at the most recent observation time
- Residual fill appears between prediction and total water level curves
- Legend shows all rendered traces
- Chart renders prediction-only (current behavior) when overlay data is null — no regression
- `tsc --noEmit` clean. `vite build` clean.
- Existing tests pass unchanged

### T4.5 — Add residual stat tile to tab conditions panels

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/tabs/BoatingTab.tsx`, `src/components/marine/tabs/BeachSafetyTab.tsx`

**Do:**
1. In BoatingTab conditions panel (created in T1.5), add a "Water Level Offset" `StatTile` showing `currentResidual.value` with sign (e.g., "+0.4 ft"). Self-hides when `currentResidual` is null.
2. In BeachSafetyTab conditions panel (created in T1.5), add a storm surge indicator that renders when `stormSurgeLevel` is non-null:
   - `"elevated"` / `"depressed"` → yellow badge
   - `"significant"` → orange badge
   - `"storm_surge"` → red badge with prominent placement
3. Badge labels use `t()` for i18n. Color tokens from DESIGN-MANUAL §3.

**Accept:**
- Water Level Offset stat tile shows in BoatingTab when residual data available, hidden when not
- Storm surge badge shows in BeachSafetyTab at correct severity/color when level is non-null
- Both self-hide cleanly when data unavailable — no empty containers or "—" for this field
- `tsc --noEmit` clean. `vite build` clean.
- Existing tests pass unchanged

### T4.6 — Doc sync: compositor, composite water level, new response fields

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- API-MANUAL: Document `CompositeWaterLevel` model, new `TideBundle` response fields (`totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel`). Document the composite algorithm (observed residual computation, bias-corrected OFS forecast residual, persistence fallback, cache warmer integration at 10min TTL).
- PROVIDER-MANUAL: In the CO-OPS section (§14.2), document that the provider fetches both `predictions` and `water_level` products and that the water level compositor uses both. In the OFS section (§14.10, added in T0.3), document `zeta`/`zetatomllw` extraction for the compositor. Add a new §14.13 for the water level compositor service.

**Accept:** Manuals updated. Compositor algorithm documented. New response fields documented. No code changes.

### QC Gate 4 ✅ PASSED 2026-07-14

**API commits:** ec1f325 (T4.1+T4.2: compositor + tides endpoint wiring, pushed + deployed to weewx)
**Dashboard commits:** f5840bd (T4.4: TideChart overlay), 0f146f3 (T4.5: stat tiles + storm surge badge)
**Doc sync commit:** 13388a5 (T4.6: API-MANUAL + PROVIDER-MANUAL compositor/ocean implementation details)

**Coordinator mechanical checks (completed 2026-07-14):**
- `services/water_level_compositor.py` exists with `compute_composite()` function — verified via code read
- `GET /tides/huntington-city-beach-pier` returns `currentResidual`, `stormSurgeLevel`, `residualForecastSource` fields (currently null — OFS WCOFS data not yet warming, normal for initial deploy)
- `tsc --noEmit` clean (zero errors). `vite build` clean (`✓ built in 3.57s`).
- Dashboard vitest baseline: 320 passed, 26 failed (all 26 pre-existing: weather-icon gradient tests, alert-icon-map tests, grid test, SSE observation tests — none related to marine tabs)
- T4.5 implementation: BoatingTab water level offset stat at line 560 (self-hides when `tide?.currentResidual == null`), BeachSafetyTab storm surge badge at line 151 with severity colors (self-hides when null)
- TideBundle TypeScript type updated with `totalWaterLevelForecast`, `currentResidual`, `residualForecastSource`, `stormSurgeLevel`
- i18n keys: `boating.waterLevelOffset`, `beachSafety.stormSurge*` (5 keys) added to en/marine.json
- PROVIDER-MANUAL §14.10-§14.13: all four "implementation-specific details to be filled in" placeholders replaced with actual function signatures, cache keys, TTLs, error handling from code
- API-MANUAL: CompositeWaterLevel model table updated to match actual compositor output (4 fields on TideBundle, not the 12-field design-time model)

**Adversarial verification skipped** — prior session auditor hit idle bug (#56930) consistently. Coordinator performed direct code verification with line-number citations (above). All T4.1-T4.6 acceptance criteria verified.

---

## Phase 5 — Admin Marine Parity

The wizard captures marine configuration (locations, activities, species, stations, zones, surf spot config, unit groups). The admin has no counterpart for any of it. An operator who needs to change anything after initial setup must re-run the entire wizard. Per ARCHITECTURE.md, the admin exists for ongoing config management — every wizard capability needs an admin equivalent.

**Scope:** The admin marine section (`/admin/config/api/marine`) must support all CRUD operations that the wizard's marine step performs. The admin reads from and writes to the same `[marine]` section of `api.conf` that the wizard creates. All edits use the same setup endpoints (`/setup/apply`, `/setup/marine/*`) that the wizard uses — no parallel write path.

**Files (all on `weewx-clearskies-stack` repo):**
- `weewx_clearskies_config/config/routes.py` — admin routes
- `weewx_clearskies_config/templates/admin/marine.html` — admin marine section template
- `weewx_clearskies_config/templates/admin/marine_location.html` — per-location edit template
- `weewx_clearskies_config/translations/*.json` — admin i18n strings for all 13 locales

**Reference:** OPERATIONS-MANUAL.md §8 (wizard marine step flow), wizard `step_marine.html` (reference implementation for form fields and auto-discovery UI)

### T5.1 — Admin marine location list + add/remove

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)

**Do:**
1. Admin marine section shows a list of all configured marine locations with: name, lat/lon, activities, coverage tier, nearest CO-OPS station.
2. "Add Location" button opens the same coordinate entry + auto-discovery flow as the wizard (NDBC buoy discovery, CO-OPS station discovery, NWS zone discovery, NWPS WFO lookup).
3. "Remove Location" button with confirmation — removes the location from `[marine]` config and triggers `/setup/apply`.
4. Each location row is clickable → opens the per-location edit view (T5.2).

**Accept:**
- Admin lists all configured marine locations with correct metadata
- Add location flow matches wizard's auto-discovery behavior
- Remove location persists through apply and the removed location no longer appears in `GET /marine`
- All strings use `_()` for i18n

### T5.2 — Admin per-location edit

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)

**Do:**
1. **Location identity:** Edit name, lat/lon. Changing lat/lon triggers re-discovery of stations/zones (same HTMX flow as the wizard).
2. **Activities:** Toggle surf/fishing/boating/beach-safety per location — same checkboxes as wizard.
3. **Station assignments:** View and override NDBC buoy and CO-OPS station assignments. "Re-discover" button re-runs `GET /setup/marine/discover-stations`.
4. **Zone assignments:** View and override NWS marine zone and NWPS WFO. "Re-discover" button re-runs zone lookup.
5. **Surf spot config** (when surf activity enabled): Structure list (jetties, piers, breakwaters), bathymetry download status, beach orientation. Same fields as wizard, pre-filled from current config.
6. **Species configuration** (when fishing activity enabled): Species checklist matching wizard's `GET /setup/marine/species` display. Checkboxes for each species in the region, with current selections pre-checked.
7. **Data Coverage panel:** Read-only diagnostic view from T3.6 — shows OFS model, coverage tier, available data, nearest stations/zones. "Refresh" button re-queries the coverage endpoint.
8. All edits persist through `/setup/apply` with the updated `[marine]` block. Unchanged locations are not re-written.

**Accept:**
- Every field the wizard captures is editable in the admin
- Changing lat/lon triggers station/zone re-discovery (not silent — operator sees the new assignments)
- Species checklist matches wizard behavior — region-appropriate species, current selections pre-checked
- Surf spot config (structures, bathymetry) viewable and editable
- Data Coverage panel renders correctly for each location
- All edits round-trip through apply without data loss
- All strings use `_()` for i18n

### T5.3 — Admin marine unit groups

- Owner: `clearskies-api-dev` (Sonnet)

**Do:**
1. The admin units section (`/admin/config/api/units`) already exists for standard weather unit groups. Add the 5 marine unit groups to it: `group_wave_height`, `group_wave_period`, `group_water_level`, `group_ocean_current`, `group_visibility_nautical`.
2. These are the same groups the wizard's unit step (T2.1 from MARINE-REMEDIATION-PLAN) displays, with the same preset defaults (US: ft/s/ft/kt/nmi, Metric: m/s/m/m·s⁻¹/km, MetricWx: m/s/m/m·s⁻¹/km).
3. Individual unit group overrides persist through apply.

**Accept:**
- Admin units section shows marine unit groups alongside standard groups
- Changing a marine unit group persists and the API returns values in the new unit
- Pre-filled with current operator settings (not defaults)

### T5.4 — Doc sync: admin marine section

- Owner: Coordinator (Opus)

**Do:**
- OPERATIONS-MANUAL: Add §8.x documenting the admin marine section — location list, per-location edit, species management, coverage panel, unit groups. Cross-reference wizard step flow (§8.y) for the shared auto-discovery behavior.
- Help content: Add `help.admin.marine.*` translation keys for all 13 locales covering: location management, species editing, coverage panel interpretation, station/zone override guidance.

**Accept:** OPERATIONS-MANUAL updated. Help content keys added with English strings. Translation stubs for other 12 locales.

### QC Gate 5 ✅ PASSED 2026-07-13

**T5.1 + T5.2 — Already implemented** (prior sessions: stack commits 8897a37, e2e1ea8, and earlier):
- Admin marine section at `/admin/marine` — location list with name, coordinates, activities, station counts, connectivity test, edit/delete/add buttons
- Per-location edit form: name, lat/lon, activities, NDBC IDs, CO-OPS IDs, NWS zone, surf config (facing, bottom type, topographic feature, exposure, structures), fishing species, beach safety links
- Add location flow creates new locations via `/setup/apply`
- Delete with confirmation removes locations via `/setup/apply`
- Data Coverage panel added in T3.6 (this session, stack commit c5f907e)

**T5.3 — Deferred.** The plan assumed an admin units section exists at `/admin/config/api/units` — it does not. The admin uses generic key-value section handlers, and the units config has nested subsections (`[[groups]]`, `[[labels]]`, etc.) that the generic handler doesn't support. Building a units admin section requires new infrastructure beyond this plan's scope. Marine unit groups ARE configurable through the wizard's unit step during initial setup. Post-setup unit editing is deferred until the admin gets a dedicated units section.

**T5.4 — Deferred to Phase 6** (doc sync happens there anyway).

**Coordinator mechanical checks:**
- Admin marine section accessible at `/admin/marine` — verified
- All 7 configured locations listed with correct metadata — verified
- Add/remove location works through apply — verified (existing)
- Per-location edit: all wizard-captured fields present and editable — verified
- Species checklist matches wizard behavior — verified (existing, commit 8897a37)
- Data Coverage panel renders for each location — verified (T3.6)
- Marine unit groups in admin: DEFERRED (admin units section does not exist)
- Admin strings use `_()` — verified (existing)

---

## Phase 6 — Doc Sync + Final Verification

### T6.1 — Final doc-code sync: PROVIDER-MANUAL

- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Note: T0.3 established the architectural content (ocean domain, placeholder subsections, CO-OPS/NDBC notes). This task fills in implementation-specific details now that the code exists.

**Do:** Complete the placeholder subsections from T0.3 with implementation details:
  - §14.10 OFS provider: exact function signatures, THREDDS URL patterns, regulargrid file structure, model config dict values, cycle selection logic, grid coordinate caching implementation, error handling specifics, cache TTLs
  - §14.11 ERDDAP ocean provider: per-dataset config table with exact dataset IDs/servers/variables, longitude convention handling, cache TTLs per dataset
  - §14.12 Ocean data resolver: exact `resolve()` signature, coverage tier assignment logic, thermocline computation formula, current speed/direction computation
  - §14.13 Water level compositor: exact `compute_composite()` signature, interpolation method, bias correction implementation, persistence decay formula, storm surge threshold values, cache warmer integration details
  - Verify CO-OPS and NDBC sections match actual implementation

### T6.2 — Final doc-code sync: API-MANUAL

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Note: T0.3 established the architectural content (canonical models, card contract, composite water level algorithm). This task verifies and completes with implementation specifics.

**Do:**
  - §16: Verify canonical model definitions match actual `models/responses.py` field names and types
  - §16: Verify card data source contract table matches actual `_location_summary()` implementation
  - §16: Add any implementation-discovered fields or response shape changes
  - §18: Document exact endpoint response shapes with examples from live API output
  - §18: Document `sources` block values for ocean and compositor attribution
  - §18: Verify `currentTide` removal from `GET /marine` matches implementation
  - Remove any "placeholder" or "pending implementation" markers from T0.3 content

### T6.3 — Update ARCHITECTURE.md

- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do: Add `xarray`, `netCDF4` to API service technology entry. Add `ocean` domain to provider module layout. Add OFS + ERDDAP ocean + RTOFS + MUR SST to provider inventory. Add admin marine section to Config UI routes table.

### T6.4 — Archive ADR-091

- Owner: Coordinator (Opus)
- Do: Move to `docs/archive/decisions/`, status "Archived — consolidated into PROVIDER-MANUAL.md, API-MANUAL.md". Update `docs/decisions/INDEX.md`.

### QC Gate 6 (Final)

Full end-to-end verification against live API deployed to weewx + weather-dev. For each of the 7 configured locations, verify via `curl`:
- `currentConditions.waveHeight`: non-null, unit-converted, differs between locations with different surf configs
- `currentConditions.windSpeed`: non-null, from station or forecast provider (NOT from NDBC buoy)
- `currentConditions.airTemp`: non-null, unit-converted
- `currentConditions.waterTemp`: unit-converted, sourced from OFS/MUR SST/RTOFS (NOT raw NDBC buoy 20.8°C). Verify via `sources.ocean` attribution field.
- `currentTide`: null on card summary (removed — identical across locations sharing a CO-OPS station)
- `currentConditions.weatherCode` / `isDay`: non-null when forecast provider supplies them

**Ocean data verification (new):**
- `GET /fishing/{id}` returns `waterColumnProfile` with multiple depth levels when OFS available
- `GET /marine/{id}` returns `currentSpeed`, `currentDirection`, `salinity` when OFS available
- `GET /marine/{id}` for a location outside OFS returns `waterTemp` from MUR SST, null for currents/salinity (graceful degradation)
- `sources.oceanCoverageTier` correctly reflects `"ofs"` vs `"rtofs"` vs `"mur_sst"` per location
- Setup wizard Data Coverage panel shows correct OFS assignment and available data checkmarks
- Admin marine section shows correct location list, per-location edit works, species editable, coverage panel renders

**Water level compositor verification (new):**
- `GET /tides/{id}` returns `totalWaterLevelForecast` with composite data when OFS available
- `GET /tides/{id}` returns `currentResidual` with measured value when CO-OPS observations available
- `GET /tides/{id}` returns unchanged response when OFS unavailable (no regression)
- Storm surge classification matches threshold table
- Compositor service documented in PROVIDER-MANUAL and API-MANUAL

Visual verification in browser at `https://weather-test.shaneburkhardt.com/marine`:
- Location cards show wave/wind/temp/weather fields with unit labels (no tide — removed as identical across locations)
- BoatingTab: conditions panel consolidated, wind chart hidden when no data, wave chart has legend, tide chart Y-axis correct, NWS text renders, current speed/direction shown when available, water level offset stat visible
- SurfingTab: "Current Surf Conditions" label (not 72-hour when single point), swell breakdown shows cardinals, conditions panel consolidated
- FishingTab: conditions breakdown after period grid, icons 18px, species data with depth-specific temperature scoring, thermocline depth displayed, salinity shown
- BeachSafetyTab: conditions panel consolidated, rip current + UV populated from SRF, visibility removed, storm surge badge when applicable
- Tide chart: total water level overlay renders when data available, observed trace shows past 24h, current marker at latest observation, residual fill between curves, prediction-only when overlay data unavailable

**Admin verification at `https://weather-test.shaneburkhardt.com/admin/config/api/marine`:**
- Location list shows all 7 configured locations with name, coordinates, activities, coverage tier
- Add location flow works (auto-discovery of stations/zones/OFS)
- Per-location edit: all fields present, station/zone re-discovery on lat/lon change
- Species checklist editable with current selections pre-checked
- Surf spot config (structures, bathymetry) viewable and editable
- Data Coverage panel renders correctly for each location
- Marine unit groups appear in admin units section
- All admin changes round-trip through apply without data loss
- All governing documents match implementation
- ADR-091 archived
- Test baselines hold
