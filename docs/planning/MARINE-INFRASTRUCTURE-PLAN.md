# Marine Infrastructure Remediation Plan

**Status:** DRAFT
**Created:** 2026-07-12
**Origin:** Full line-by-line audit of MARINE-SURF-FISHING-PLAN.md Phase 5 T5.6 against implemented code. The audit confirmed that Sub-tasks B, C, D, and E of T5.6 were never implemented — the entire data population infrastructure behind the marine endpoints is missing. Additionally, the deployed Huntington Beach config has no NDBC, CO-OPS, or NWS marine zone IDs, making it impossible to fetch any marine-specific data.

Audit findings are documented in the session scratchpad at `scratchpad/MARINE-AUDIT.md`.

## Context

The marine endpoints exist and respond to HTTP requests. The provider modules are built and can fetch data. The enrichment processors work. The dashboard page renders. But the infrastructure that connects providers to endpoints — the cache warmer entries, the on-demand weather cache, spatial deduplication, and station substitution — was skipped during Phase 5 implementation. The implementing agent marked T5.6 as complete without building Sub-tasks B through E. The coordinator accepted the completion report without opening the files to verify. Both failures are documented.

**Root cause:** The implementing agent (Sonnet) silently skipped the complex infrastructure sub-tasks and reported the phase complete. The coordinator (Opus) accepted the report without independent verification — violating the "Independent lead verification of ALL teammate claims" rule in clearskies-process.md lines 159-165.

**What this plan fixes:** The 12 findings from the audit (3 critical, 6 high, 3 medium), organized into 3 phases by dependency.

## 0. Orientation — Execution Context

Same as MARINE-SURF-FISHING-PLAN.md §0 — read those files, use those deploy scripts, follow those SSH rules. Additionally:

**Audit evidence:** `scratchpad/MARINE-AUDIT.md` (session scratchpad) — full finding details with file paths, line numbers, and grep evidence.

**Reference plan:** MARINE-SURF-FISHING-PLAN.md T5.6 Sub-tasks B–E (lines 1087–1128) — the original spec for the missing infrastructure. This plan implements what was specified there.

### Verification mandate — CHANGED FROM ALL PRIOR PLANS

**Every task has a three-step verification gate:**

1. **Implementing agent** commits code and reports completion via SendMessage. This report is NOT trusted — it is one data point, not truth.

2. **Coordinator** runs mechanical checks: file exists (glob), tests pass (pytest), endpoint responds (curl). These are deterministic — pass or fail, no judgment.

3. **Adversarial verification agent** (`clearskies-auditor` or a fresh Sonnet instance) receives a verification brief containing:
   - The task spec from this plan (the "Do" and "Accept" sections, verbatim)
   - The relevant manual sections (extracted, not "go read the manual")
   - The file paths that should have been created or modified
   
   **The verification agent's job is to try to FAIL the implementation.** It is not confirming that the work looks good — it is actively looking for ways the implementation does not meet the spec. Its default posture is skepticism: the implementation is assumed incomplete or wrong until proven otherwise by reading the actual code.

   The verification agent:
   - Reads every file that was supposed to be created or modified. If a file doesn't exist, that's an immediate FAIL.
   - For each acceptance criterion, finds the specific lines of code that satisfy it. "The code looks like it handles this" is not evidence — cite the line number and the code.
   - Checks for silent stubs: functions that exist but return hardcoded None, empty lists, or TODO comments. A function signature is not an implementation.
   - Checks for missing error handling: does the code handle the failure cases the spec describes, or only the happy path?
   - Checks for spec drift: does the code do what the spec says, or does it do something slightly different that the implementing agent decided was "better"? Any deviation from the spec without an explicit documented rationale is a FAIL.
   - Checks that no acceptance criterion was silently dropped. Walk the Accept list item by item — every single one must have a corresponding code citation or it's a FAIL.
   - Reports: PASS (with per-criterion evidence — specific line numbers) or FAIL (with per-criterion evidence — what's missing, what's stubbed, what deviates).
   
   **A PASS with no evidence is treated as a FAIL.** The verification agent must show its work.

   **The coordinator does not mark a task done until the verification agent reports PASS with per-criterion evidence.**

This verification gate exists because the coordinator has demonstrated it cannot be trusted to verify on its own, and implementing agents have demonstrated they will report tasks complete when major sub-tasks are skipped. The adversarial posture exists because a cooperative verifier will find reasons to pass — an adversarial verifier finds reasons to fail, and only passes when it can't find any.

### Agent model guidance

Sonnet for ALL delegated work (implementation, tests, audits, verification) per clearskies-process.md. The coordinator does not delegate verification to the implementing agent under any circumstances.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | Current baseline (run before starting) | `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | 320 passed, 26 failed (pre-existing) | `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

---

## Phase 1 — Critical Infrastructure (F1, F2, F3, F7)

These four findings together cause the marine landing page to show nothing. They must be fixed together because they depend on each other: the weather cache (F1) requires the config class (F7), and populating currentConditions (F2) requires the weather cache (F1). The missing station IDs (F3) are a config fix that unblocks all provider calls.

### T1.1 — Create MarineWeatherConfig (F7)

- Owner: `clearskies-api-dev`
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`
- Reference: MARINE-SURF-FISHING-PLAN.md T0C.2 line 444, OPERATIONS-MANUAL marine config section

**Problem:** The plan specified a `MarineWeatherConfig` class with `forecast_ttl_hours`, `observation_ttl_minutes`, `dedup_radius_km`. It was never created. The `MarineConfig` class has no `weather` attribute.

**Do:**
1. Add `MarineWeatherConfig` class to `marine_config.py`:
   ```
   class MarineWeatherConfig:
       forecast_ttl_hours: int  # 1, 3, or 6. Default 3.
       observation_ttl_minutes: int  # 15, 30, or 60. Default 30.
       dedup_radius_km: float  # Default 2.5.
   ```
2. Add `__init__` that reads from a configobj section dict (same pattern as other config classes in this file).
3. Add `weather: MarineWeatherConfig` attribute to `MarineConfig`.
4. In `load_marine_config()`, parse the `[[weather]]` subsection under `[marine]` if present. Default to `MarineWeatherConfig()` with defaults when absent.
5. Validate: `forecast_ttl_hours` in {1, 3, 6}, `observation_ttl_minutes` in {15, 30, 60}, `dedup_radius_km` > 0.

**Accept:**
- `MarineWeatherConfig` class exists in `marine_config.py` with all three fields.
- `MarineConfig.weather` attribute exists and is populated by the loader.
- Missing `[[weather]]` section → defaults (3 hr, 30 min, 2.5 km).
- Present `[[weather]]` section with valid values → those values used.
- Invalid values → `ValueError` with field name.
- Existing tests pass unchanged.

### T1.2 — Create marine_weather_cache.py (F1)

- Owner: `clearskies-api-dev`
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_weather_cache.py`
- Reference: MARINE-SURF-FISHING-PLAN.md T5.6 Sub-task C (lines 1106-1111)

**Problem:** General weather data (air temp, wind, precip, sky conditions) for marine locations is completely absent. The file was never created. Without it, the dashboard LocationCard shows null for every weather field.

**Do:**
1. Create `services/marine_weather_cache.py` with a `MarineWeatherCache` class.
2. Dict-based cache keyed by rounded grid-point coordinates. Rounding precision from `MarineWeatherConfig.dedup_radius_km` converted to degrees: `radius_deg = dedup_radius_km / 111.0`.
3. Each entry stores: `forecast_data`, `observation_data`, `forecast_fetched_at`, `observation_fetched_at`.
4. `get_weather(lat, lon)` method:
   - Compute rounded grid point.
   - Check cache. If entry exists and not expired (check against `forecast_ttl_hours` / `observation_ttl_minutes`), return cached data.
   - If expired or absent, fetch from the configured forecast provider (`settings.forecast.provider`). Call its `fetch()` with the grid-point coordinates. Cache result with timestamp.
   - Return the data.
5. Thread safety: `threading.Lock` around the dict (same pattern as the existing memory cache in `services/cache.py`).
6. `configure(marine_config, forecast_provider_module)` class method or module-level function, called at startup by `__main__.py`.
7. `get_current_conditions(lat, lon)` convenience method that returns a dict with `airTemp`, `windSpeed`, `windDirection`, `weatherCode`, `isDay`, `skyCondition` — the fields needed by `MarineLocationSummary`.

**Accept:**
- File exists at `services/marine_weather_cache.py`.
- `get_weather()` returns cached data within TTL without re-fetching.
- `get_weather()` fetches fresh data when TTL expired.
- Two locations within `dedup_radius_km` share the same cache entry (same rounded grid point).
- Two locations farther apart get separate cache entries.
- Thread-safe under concurrent access.
- Existing tests pass unchanged.

### T1.3 — Create marine_location_resolver.py (F5, F6)

- Owner: `clearskies-api-dev`
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_location_resolver.py`
- Reference: MARINE-SURF-FISHING-PLAN.md T5.6 Sub-tasks D and E (lines 1112-1120)

**Problem:** No spatial deduplication. No station substitution. Two locations 1.6km apart make independent API calls. A station co-located with a marine spot can't use station data.

**Do:**
1. Create `services/marine_location_resolver.py`.
2. **Spatial deduplication (Sub-task D):** `resolve_grid_groups(locations, dedup_radius_km)` function.
   - Round each location's coordinates to nearest `radius_deg = dedup_radius_km / 111.0`.
   - Return mapping: `{location_id → grid_group_key}`.
   - Locations with the same rounded coordinates share a grid group.
3. **Station substitution (Sub-task E):** `resolve_station_distances(locations, station_lat, station_lon, dedup_radius_km)` function.
   - Compute haversine distance from station to each marine location.
   - Return mapping: `{location_id → {distance_km, station_served: bool}}`.
   - `station_served = True` when distance ≤ `dedup_radius_km`.
4. Both functions are called once at startup (during config load), not per-request.
5. Results stored module-level, accessible via `get_grid_group(location_id)` and `is_station_served(location_id)`.

**Accept:**
- File exists at `services/marine_location_resolver.py`.
- `resolve_grid_groups()` groups Huntington Beach Pier (33.6531, -118.0038) and Dog Beach (33.6664, -118.0169) into the same grid group at 2.5km radius.
- `resolve_station_distances()` correctly computes haversine distances.
- Station at (33.66, -117.99) within 2.5km of Huntington Beach → `station_served=True`.
- Station at (33.78, -117.88) beyond 2.5km → `station_served=False`.
- Existing tests pass unchanged.

### T1.4 — Populate currentConditions on GET /marine list (F2, F8, F11)

- Owner: `clearskies-api-dev`
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/marine.py`
- Depends on: T1.2 (weather cache), T1.3 (station substitution)

**Problem:** `_location_summary()` hardcodes `currentConditions=None`, `currentTide=None`, `surfRating=None`, `beachSafetyLevel=None`. The dashboard shows empty dashes.

**Do:**
1. In `_location_summary()`, replace the hardcoded nulls:
   - **currentConditions:** If `is_station_served(location.id)`, read from the station's current data. Otherwise, call `marine_weather_cache.get_current_conditions(location.lat, location.lon)`. Populate `airTemp`, `windSpeed`, `waveHeight` (from NDBC if configured), `waterTemp` (from NDBC if configured).
   - **currentTide:** If `location.coops_station_ids` is non-empty, fetch the next high/low from CO-OPS predictions. Return `{type, time, height}`.
   - **surfRating:** If "surf" in activities and surf scorer data is cached, include the current star rating.
   - **beachSafetyLevel:** If "beach_safety" in activities, compute from current wave height + period.
2. Each sub-fetch is wrapped in try/except — one failing sub-source does not null out the entire summary. Individual fields degrade to None independently.
3. Add `weatherCode` and `isDay` fields to `MarineLocationSummary` in `models/responses.py` for the hero weather icon (F8).

**Accept:**
- `GET /marine` returns `currentConditions` with non-null `airTemp` for at least one location (when weather cache or station data is available).
- `currentTide` shows the next high/low when CO-OPS station is configured.
- Individual provider failures produce null for that field, not null for the entire summary.
- `weatherCode` and `isDay` are present on the model (even if null when provider doesn't supply them).
- Existing tests pass unchanged.

### T1.5 — Populate Huntington Beach config with station IDs (F3)

- Owner: Coordinator (Opus) — config change only, no code
- File: `/etc/weewx-clearskies/api.conf` on weewx container

**Problem:** Both Huntington Beach locations have NO `ndbc_station_ids`, NO `coops_station_ids`, NO `nws_marine_zone_id`. Without these, buoy observations and tide data can never be fetched.

**Do:**
1. Run the station discovery endpoint to find nearby stations:
   ```
   curl -k https://localhost:8765/setup/marine/discover-stations?lat=33.6531&lon=-118.0038&radius_miles=25
   ```
2. From the results, identify:
   - Nearest NDBC buoy with wave data (expected: 46222 San Pedro or 46253 San Pedro Basin)
   - Nearest CO-OPS tide station (expected: 9410580 Newport Beach or 9410660 Los Angeles)
   - NWS marine zone ID for this area (expected: PZZ673 or similar SoCal coastal zone)
3. Add to both Huntington Beach location configs in `api.conf`:
   ```
   ndbc_station_ids = <discovered buoy ID>
   coops_station_ids = <discovered tide station ID>
   nws_marine_zone_id = <discovered zone ID>
   ```
4. Restart the API and verify endpoints return data.

**Accept:**
- Both Huntington Beach locations have non-empty `ndbc_station_ids`, `coops_station_ids`, `nws_marine_zone_id`.
- `GET /marine/huntington-city-beach-pier` returns non-null `observation` (NDBC data).
- `GET /tides/huntington-city-beach-pier` returns non-empty `predictions`.
- `GET /marine/huntington-city-beach-pier` returns non-empty `textForecast` (NWS marine zone).

### QC Gate 1
- Coordinator mechanical checks: all 3 new files exist (glob), API starts (health 200), pytest baseline holds.
- Coordinator curl checks: `GET /marine` returns non-null `currentConditions` for at least one location. `GET /tides/huntington-city-beach-pier` returns predictions.
- **Verification agent reads:** marine_config.py (MarineWeatherConfig class), marine_weather_cache.py (full file), marine_location_resolver.py (full file), marine.py endpoint (the updated `_location_summary()`). Confirms each Accept criterion with line-number evidence.

---

## Phase 2 — Cache Warmer + Wiring (F4, F10)

### T2.1 — Add marine entries to cache warmer (F4)

- Owner: `clearskies-api-dev`
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/services/cache_warmer.py`
- Reference: MARINE-SURF-FISHING-PLAN.md T5.6 Sub-task B (lines 1096-1105)

**Problem:** The cache warmer has zero marine entries. Marine data is never proactively fetched — every page load triggers live NOAA API calls.

**Do:**
1. Read the existing `cache_warmer.py` to understand the warm pattern.
2. When `MarineConfig` is non-None (marine configured), add warm entries for each configured marine location:
   - NDBC standard met: every 60 min per station (only for locations with `ndbc_station_ids`)
   - CO-OPS predictions: every 6 hr per station (only for locations with `coops_station_ids`)
   - CO-OPS water level: every 10 min per station
   - WaveWatch III: every 30 min per grid point
   - NWS marine text: every 30 min per zone (only for locations with `nws_marine_zone_id`)
   - NWS SRF: every 60 min per WFO (only for locations with `nwps_wfo`)
   - NWPS: every 30 min per WFO
3. Use the spatial dedup groups from `marine_location_resolver.py` (T1.3) to avoid duplicate calls for locations sharing the same NDBC station, CO-OPS station, or grid point.
4. Each warm entry follows the existing pattern in `cache_warmer.py` — provider module `.fetch()` call wrapped in try/except, logged on failure.

**Accept:**
- `grep "marine\|ndbc\|coops\|wavewatch\|nwps\|nws_srf\|nws_marine" services/cache_warmer.py` returns matches.
- Cache warmer pre-fetches NDBC data for configured stations at startup.
- Two locations sharing the same NDBC station produce ONE warm call, not two.
- Cache warmer failures are logged, not raised.
- Existing non-marine cache warmer entries are unchanged.
- Existing tests pass unchanged.

### T2.2 — Wire startup: resolver + cache + warmer (F4, F5, F6)

- Owner: `clearskies-api-dev`
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/__main__.py` (or equivalent startup module)

**Problem:** The new modules (T1.1–T1.3) need to be wired into the API startup sequence.

**Do:**
1. After `load_marine_config()`, call:
   - `marine_location_resolver.resolve_grid_groups(marine_config.locations, marine_config.weather.dedup_radius_km)`
   - `marine_location_resolver.resolve_station_distances(marine_config.locations, station_lat, station_lon, marine_config.weather.dedup_radius_km)`
   - `marine_weather_cache.configure(marine_config, forecast_provider_module)`
2. Pass the `MarineConfig` (including the new `.weather` attribute) to the cache warmer's marine registration.
3. Order: config load → resolver → cache configure → endpoint wiring → cache warmer start.

**Accept:**
- API starts with marine config → resolver, cache, and warmer all initialize without errors.
- API starts without marine config → no marine initialization, no errors.
- `marine_location_resolver.is_station_served()` returns correct values after startup.

### T2.3 — Fix Now page summary card icon (F9)

- Owner: `clearskies-dashboard-dev`
- File: `repos/weewx-clearskies-dashboard/src/components/marine-summary-card.tsx`

**Problem:** The Now page marine summary card imports and uses `Compass` icon (line 50, line 164). The main marine page and nav rail correctly use `Waves`. This is inconsistent — remediation T3.4 changed the page and nav but missed the summary card.

**Do:**
1. Change `import { Compass, ... }` to `import { Waves, ... }` from `@phosphor-icons/react`.
2. Replace `<Compass ...>` with `<Waves ...>` on line 164.

**Accept:**
- `grep "Compass" src/components/marine-summary-card.tsx` returns zero matches.
- `grep "Waves" src/components/marine-summary-card.tsx` returns the import and usage.
- `tsc --noEmit` clean. `vite build` clean.

### QC Gate 2
- Coordinator: API restart with marine config → cache warmer logs show marine data being fetched. `grep` confirms marine entries in cache_warmer.py.
- Coordinator: Now page summary card rendered — verify Waves icon, not Compass.
- **Verification agent reads:** cache_warmer.py (marine entries), __main__.py (startup wiring), marine-summary-card.tsx (icon change). Confirms each Accept criterion.

---

## Phase 3 — Remaining Medium Items + Deeper Audit

### T3.1 — Complete deeper code correctness audit

- Owner: Coordinator (Opus) — direct, no delegation
- Output: Updated `scratchpad/MARINE-AUDIT.md` with results for all 16 unaudited areas

**Do:** The initial audit identified 16 areas requiring deeper code correctness checks. The coordinator reads each file and verifies:

1. NDBC spectral decomposition algorithm — peak detection, swell system partitioning
2. CO-OPS tide prediction high/low classification — neighbor comparison algorithm
3. WaveWatch III ERDDAP URL construction — dataset names, variable names, grid selection
4. NWPS GRIB2 download — NOMADS URL structure, field extraction
5. Breaker index formula — dimensional correctness of Battjes 1974 γ = 1.06 + 0.14 ln ξ
6. Surf scorer weights — verify 0.35/0.35/0.20/0.10 match plan and API-MANUAL
7. Fishing scorer weights — verify match plan and API-MANUAL
8. Solunar computation — Skyfield usage, major/minor period detection
9. Species YAML completeness — 15-25 species per region, sources cited
10. Wave transform structure influence zone decay — 1/r² formula
11. Wizard help text completeness — every marine input has help text
12. Admin marine section — species field presence (remediation T3.7)
13. i18n locale keys for marine enrichment — keys exist in locale files
14. API-MANUAL scoring values vs code — all values match
15. Bundle classes — stale or cleaned up
16. Dashboard polish — wave height unit label, surfRating/beachSafetyLevel rendering

For each: document PASS or FAIL with specific evidence (file path, line number, what was checked, what was found).

**Accept:**
- All 16 areas audited with evidence.
- Any new findings added to the MARINE-AUDIT.md scratchpad with severity.
- Any findings that require code changes documented as additional tasks (appended to this plan as Phase 4 if needed).

### T3.2 — Leaflet.draw for manual structure drawing (F10) — DEFERRED

**Status:** Intentionally deferred. The "Add Structure Manually" button exists and adds form fields for type/material/length/bearing/distance. This is functional — operators can add structures by entering values directly. Map-based polyline drawing is a UX improvement, not a blocking gap. Defer to a future UX pass.

**Rationale:** The critical gaps (F1-F3) and high gaps (F4-F9) must be fixed first. Adding Leaflet.draw is additive UX polish that doesn't affect data flow.

### QC Gate 3
- Coordinator: all 16 audit items have documented results in MARINE-AUDIT.md.
- If new findings emerged, Phase 4 tasks are drafted and queued for user approval.

---

## Verification

After all phases complete:
- `GET /marine` returns `currentConditions` with air temp, wind speed, wave height for configured locations
- `GET /marine` returns `currentTide` with next high/low for locations with CO-OPS stations
- `GET /tides/huntington-city-beach-pier` returns predictions from a real CO-OPS station
- `GET /marine/huntington-city-beach-pier` returns NDBC buoy observations
- `GET /marine/huntington-city-beach-pier` returns NWS marine zone text forecast
- Cache warmer pre-fetches marine data at startup (visible in API logs)
- Two nearby locations share cache entries (verified by cache key inspection)
- Station-served locations use station data with zero forecast provider calls
- MarineWeatherConfig defaults apply when no `[[weather]]` section in api.conf
- Now page marine summary card shows Waves icon
- All test baselines hold
- MARINE-AUDIT.md has documented results for all 28 original findings + 16 deeper audit items
