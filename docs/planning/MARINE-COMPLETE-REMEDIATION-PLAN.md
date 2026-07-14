# Marine Feature Complete Remediation Plan

**Status:** APPROVED
**Approved:** 2026-07-14
**Created:** 2026-07-14
**Origin:** Post-deployment testing and troubleshooting of the marine dashboard page, admin marine section, and all four activity tabs. 25 findings (F0–F25) documented in `docs/planning/briefs/ADMIN-MARINE-FIXIT-BRIEF.md` with industry research across surf, fishing, beach safety, and boating sites.

## Context

The marine feature's data pipeline is non-functional (F0 — two bugs silently drop every location to the same offshore buoy data), all four activity tabs ignore the DESIGN-MANUAL and scoring systems (F21–F25), the landing page bypasses the grid system (F9), and the admin page has usability issues (F1–F7). This plan addresses every finding in the fixit brief with no deferrals.

**NOTE TO ALL IMPLEMENTING AGENTS:** This plan is extremely specific about what to build because prior implementations ignored the DESIGN-MANUAL, ignored built scoring systems, and shipped broken UIs that passed QC gates. Every task specifies exact component APIs, exact file paths, exact visual patterns to follow. Do not deviate. Do not simplify. Do not skip features because they seem complex. If a task says "use the Card component with CardHeader/CardTitle," that means the Card component — not a hand-rolled `<section>` with inline classes.

---

## Plan structure — this file is a starting point

This plan covers all 25+ findings from the fixit brief. Due to the massive scope, I'm writing Phase 0 (docs) and Phase 1 (critical data pipeline) in full here. The remaining phases will be added as implementation progresses, following the same granular task structure. Each phase has its own QC gate with adversarial auditor verification.

**Phase overview:**

| Phase | Scope | Findings addressed |
|---|---|---|
| 0 | Doc & manual updates — establish what tabs SHOULD look like before building | F25 (design system), all industry research |
| 1 | Critical data pipeline — fix the two bugs killing wave/water temp data | F0 (NWPS case bug, ERDDAP constructor bug, config case normalization, harbor wave handling) |
| 2 | API detail endpoint enrichment — wire forecast provider/models into GET /marine/{id} | F21a/b/d/e root cause, F13 (weatherCode/isDay) |
| 3 | Marine landing page — grid, icons, map, cards | F8, F9, F10, F11, F12, F13, F15, F16 |
| 4 | Location photo system — upload, storage, serving | F14 |
| 5 | Detail page shell — map zoom, marine labels, combo card, phantom text | F17, F18, F19, F20 |
| 6 | BoatingTab complete redesign | F21 (all sub-issues), F25 compliance |
| 7 | SurfingTab complete redesign — surface the scoring system | F22 (all sub-issues), F25 compliance |
| 8 | FishingTab complete redesign — surface the scoring system | F23 (all sub-issues), F25 compliance |
| 9 | BeachSafetyTab complete redesign — replace crude classifier | F24 (all sub-issues), F25 compliance |
| 10 | Admin & wizard fixes | F1, F2, F3, F4, F5, F6, F7 |

---

## 0. Orientation — Execution Context

Same as MARINE-CARD-DATA-SOURCE-PLAN.md §0 and MARINE-REMEDIATION-PLAN.md §0.

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety, SSH access, filesystem permissions
- `rules/coding.md` — coding standards
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, QC gates, doc-code sync
- `docs/ARCHITECTURE.md` — services, ports, provider module layout
- `docs/manuals/API-MANUAL.md` — data model, unit system, endpoint patterns
- `docs/manuals/PROVIDER-MANUAL.md` — provider module contract
- `docs/manuals/DASHBOARD-MANUAL.md` — §12 marine page behavior
- **`docs/manuals/DESIGN-MANUAL.md`** — **THE SINGLE AUTHORITY FOR ALL UI DESIGN. Every UI task in this plan MUST comply. No exceptions.**

**Repos (paths on containers):**

| Repo | Container | Path |
|---|---|---|
| `weewx-clearskies-api` | weewx | `/home/ubuntu/repos/weewx-clearskies-api` |
| `weewx-clearskies-dashboard` | weather-dev | `/home/ubuntu/repos/weewx-clearskies-dashboard` |
| `weewx-clearskies-stack` | weather-dev | `/home/ubuntu/repos/weewx-clearskies-stack` |
| `weewx-clearskies-project` (meta) | local | `c:\CODE\weather-belchertown` |

**Deploy:**
- Dashboard + Config UI: `bash scripts/redeploy-weather-dev.sh`
- API: `bash scripts/deploy-api.sh`

**Agent assignments:**

| Agent type | Role |
|---|---|
| Coordinator (Opus) | Plan authoring, ADR/manual updates, QC gates, orchestration |
| `clearskies-api-dev` (Sonnet) | API endpoints, provider modules, enrichment, models |
| `clearskies-dashboard-dev` (Sonnet) | Dashboard pages, components, charts |
| `clearskies-auditor` (Sonnet) | Adversarial verification — tries to FAIL each phase |

**Verification mandate:** Same three-step gate as prior plans.
1. Implementing agent commits and reports (NOT trusted)
2. Coordinator runs mechanical checks (deterministic pass/fail)
3. **Adversarial `clearskies-auditor` agent** tries to FAIL — reads every file, cites line numbers, checks for stubs, checks for spec drift, verifies DESIGN-MANUAL compliance. A PASS with no evidence is treated as FAIL.

**CRITICAL — DESIGN-MANUAL compliance check added to every QC gate:**
Every dashboard task's QC gate includes this checklist:
- [ ] Uses `Card` component from `components/ui/card.tsx` with `footprint` and `rowSpan` props — NOT a hand-rolled `<section>` or `Panel` function
- [ ] Uses `CardHeader` + `CardTitle` (with `as` prop for heading level) — NOT a bare `<h3>` with inline styles
- [ ] Header has underline via `border-b border-border` from CardHeader — NOT manually styled
- [ ] Stats use a shared `StatTile` component — NOT local per-tab duplicates
- [ ] Typography uses `var(--text-*)` tokens — zero hardcoded font sizes
- [ ] Charts fill content slot via `ResponsiveContainer width="99%" height="100%"` — NOT hardcoded pixel heights
- [ ] Icons from Phosphor (regular weight for utility/stat, duotone for page headers) or designated cross-pack exceptions
- [ ] `font-feature-settings: '"tnum"'` on all numeric values
- [ ] Every `<img>` has `alt`, every icon-only button has `aria-label`
- [ ] Tab content placed in the official 4-column Grid — NOT a `flex flex-col` vertical stack

**Test baselines (must not regress):**

| Suite | Command |
|---|---|
| API pytest | `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && sudo -u ubuntu /home/ubuntu/.local/bin/uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |
| Dashboard build | `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm run build 2>&1 \| grep gzip"` |

---

## Phase 0 — Doc & Manual Updates

No code. Establish what the marine tabs SHOULD look like before any implementation begins. Implementation agents read these updated manuals as their source of truth.

### T0.1 — Update DASHBOARD-MANUAL §12 with complete marine tab specifications

- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md`

**Do:** Rewrite §12 to specify the exact component composition, data sources, and visual patterns for each marine tab. Include:

1. **Landing state specification:**
   - LocationCards use `Card` component with `footprint="tile"` as direct Grid children
   - Each card shows: number badge (matching map pin), location name, hero weather icon (from `WeatherIcon` component at ~28px) + air temp, stat row with Phosphor icons (Waves/Wind/Thermometer) + wave height/wind/water temp, location photo on right ~40% with gradient overlay
   - Remove "Updated X minutes ago"
   - Map uses numbered `L.divIcon` pins with `--primary` accent color
   - Linked hover: card hover highlights pin (scale 1.3×), pin hover highlights card (`ring-2 ring-primary`)
   - Responsive map: aspect ratio computation determines horizontal vs vertical layout

2. **Detail state specification:**
   - Combo card: map (zoomed to single location at zoom 14-15, OpenSeaMap overlay) on left, location photo on right
   - All tab content uses official `Card` / `CardHeader` / `CardTitle` / `CardContent` components
   - No hand-rolled `Panel` functions, no local `StatTile` duplicates
   - Shared `MarineStatTile` component (extracted, not duplicated per tab)

3. **Per-tab specifications referencing industry research:**
   - **Boating:** Unified conditions dashboard (Windfinder/My Marine Forecast pattern). Wind + waves + conditions + water temp in a single Card. Marine forecast as structured columns (DailyColumns pattern). Tide chart (fixed, no clipping). Remove buoy panel entirely.
   - **Surfing:** Hero conditions summary showing `conditionsText` from surf scorer. 72h scored timeline (ForecastTimeline with multi-point data). Scoring factor breakdown (4 weighted bars). Swell components ranked by energy with direction arrows matching WindCompassCard visual quality. Compass redesigned to match WindCompassCard.
   - **Fishing:** `conditionsText` from fishing scorer as hero headline. 0-100 score with tap-to-explain breakdown (Fish & Tides pattern). Solunar timeline matching Almanac page's `SunMoonDetailCard` visual quality (MoonPhaseIcon, same arc styling). Species forecast table populated with per-species scores. Forecast periods as structured columns (DailyColumns pattern).
   - **Beach Safety:** Itemized hazard indicators (Beach Report flag pattern) — NOT crude safe/caution/dangerous from two `if` statements. Each hazard (rip current, UV, water temp, wave height, wind) as a separate status badge. UV from forecast provider (not null SRF). Flag color system (green/yellow/red/double-red).

**Accept:** §12 specifies component names, prop values, data source fields, and visual patterns for every element on every tab. An implementing agent reading only §12 can build compliant tabs without guessing.

### T0.2 — Update API-MANUAL §18 with detail endpoint enrichment contract

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`

**Do:** Document that `GET /marine/{id}` must return enriched observation data using the same sources as the card summary:

| Response field | Source | Fallback |
|---|---|---|
| `observation.windSpeed` | Station hardware (`is_station_served()`) or forecast provider (`marine_weather_cache`) | null |
| `observation.airTemp` | Same as windSpeed | null |
| `observation.pressure` | Station hardware or forecast provider | null |
| `observation.visibility` | Forecast provider | null |
| `observation.waveHeight` | NWPS + wave_transform (surf locations), WaveWatch III, NDBC last resort | null |
| `observation.waterTemp` | Ocean data resolver (OFS → MUR SST → RTOFS) | NDBC buoy |
| `observation.weatherCode` | Forecast provider | null |
| `observation.isDay` | Forecast provider | null |

Also document that `GET /surf/{id}` must return multi-point forecast (score_surf against each NWPS time step, not just current snapshot).

**Accept:** API-MANUAL §18 specifies the enriched data contract. Implementing agents know exactly which fields come from which sources.

### T0.3 — Update DESIGN-MANUAL with marine component patterns

- Owner: Coordinator (Opus)
- File: `docs/manuals/DESIGN-MANUAL.md`

**Do:** Add a new §20 "Marine Activity Tab Patterns" documenting:
1. Marine tabs MUST use `Card` / `CardHeader` / `CardTitle` / `CardContent` — not local Panel functions
2. Shared `MarineStatTile` component specification (icon + label + value + unit, matching the `StatItem` pattern from `todays-highlights-card.tsx` but exported as a shared component)
3. Marine forecast columns follow the `DailyColumns` pattern from `ForecastDailyCard`
4. Swell direction compass follows the `WindCompassCard` tick-ring visual pattern
5. Solunar display follows the `SunMoonDetailCard` arc + `MoonPhaseIcon` pattern
6. Scoring factor breakdown uses horizontal bar segments with the gauge color tokens

**Accept:** §20 exists with component specifications.

### QC Gate 0
- DASHBOARD-MANUAL §12 specifies exact component composition for all 4 tabs
- API-MANUAL §18 specifies enriched data contract for detail endpoint
- DESIGN-MANUAL §20 specifies marine component patterns
- No code changes

---

## Phase 1 — Critical Data Pipeline Fixes (F0)

Fix the two bugs that make ALL marine data fall back to the single offshore buoy.

### T1.1 — Fix NWPS case-sensitive WFO lookup (Bug 1)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/providers/marine/nwps.py`

**Problem:** Config stores `nwps_wfo = LOX` (uppercase). `_WFO_TO_REGION` dict at line 105 has lowercase keys (`"lox": "wr"`). Line 491-492:
```python
wfo = wfo_override or _determine_wfo(lat, lon)
if wfo not in _WFO_TO_REGION:
```
`"LOX" not in {"lox": "wr"}` → True → `GeographicallyUnsupported`. Every NWPS fetch fails.

**Do:** Change line 491 to:
```python
wfo = (wfo_override or _determine_wfo(lat, lon)).lower()
```

That's it. One line. Do NOT add any other changes to this file.

**Accept:**
- `nwps.fetch(lat=33.6531, lon=-118.0038, wfo_override="LOX")` succeeds (no GeographicallyUnsupported)
- `nwps.fetch(lat=33.6531, lon=-118.0038, wfo_override="lox")` also succeeds
- Cache warmer logs show "NWPS refreshed" instead of "NWPS warm failed"
- Existing tests pass unchanged

### T1.2 — Fix ERDDAP ocean provider constructor bug (Bug 2)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/providers/ocean/erddap_ocean.py`

**Problem:** Line 81 passes `base_url=` to `ProviderHTTPClient.__init__()` which does not accept that keyword argument. `TypeError` on every call. Both MUR SST and RTOFS fail for every location.

**Do:**
1. Read `providers/_common/http.py` to find the correct `ProviderHTTPClient` constructor signature.
2. Fix line 81 to use the correct parameter name or positional argument.
3. Verify the HTTP client is instantiated correctly and can make requests.

**Accept:**
- `erddap_ocean.fetch(dataset="mur_sst", lat=33.6531, lon=-118.0038)` returns non-null `surface_temp`
- `erddap_ocean.fetch(dataset="rtofs_2d", lat=33.6531, lon=-118.0038)` returns non-null `surface_temp`
- Cache warmer logs show "ERDDAP fetch" succeeding instead of TypeError
- Surface temp values are physically reasonable for SoCal (15-25°C)
- Existing tests pass unchanged

### T1.3 — Normalize case in config loader (Bug 1a)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/config/marine_config.py`

**Problem:** `_opt_str()` at line 102 does `str(value).strip()` with no case normalization. WFO codes, zone IDs, and model names are stored in whatever case the operator typed.

**Do:** For fields that are used as lookup keys, normalize to lowercase at parse time. Specifically, in `MarineLocation.__init__()`:
- `self.nwps_wfo = _opt_str(section, "nwps_wfo")` → add `.lower()` if non-None
- `self.nws_marine_zone_id = _opt_str(section, "nws_marine_zone_id")` — audit `nws_marine.py` line 448 to determine if zone IDs need case normalization, then normalize if needed
- `self.nws_srf_wfo = _opt_str(section, "nws_srf_wfo")` → add `.lower()` if non-None (SRF provider handles upper internally, but normalizing at source is safer)

Do NOT change `_opt_str()` itself — it's a generic helper. Normalize in the specific field assignments where case matters.

**Accept:**
- `location.nwps_wfo` returns `"lox"` when config has `nwps_wfo = LOX`
- All downstream consumers (`nwps.py`, `nws_srf.py`, `nws_marine.py`) receive lowercase values
- Existing tests pass unchanged

### T1.4 — Handle harbor locations (no open-ocean wave data)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/endpoints/marine.py`

**Problem:** Huntington Harbor and Newport Bay have `activities = [marine, fishing]` — no `surf`. They bypass the NWPS + wave_transform path and fall through to WaveWatch III → NDBC buoy, both returning open-ocean swell data that is physically meaningless for enclosed harbors.

**Do:** In `_location_summary()`, after the wave height fallback chain (lines 389-437), add harbor detection:
1. If the location does NOT have `surf` in its activities AND the wave height source is WaveWatch III or NDBC buoy (not NWPS), check whether the location is a harbor/enclosed water.
2. Harbor detection: if the location name contains "harbor", "harbour", "bay", "inlet", "marina", "channel", "lagoon" (case-insensitive), OR if the location config has a future `sheltered = true` flag, set `wave_height_meters = None` (suppress wave data rather than show misleading offshore values).
3. The card renders "—" for wave height when null — this is correct behavior for a harbor.

**Accept:**
- `GET /marine` returns `waveHeight: null` for Huntington Harbor and Newport Bay
- `GET /marine` returns non-null `waveHeight` (from NWPS) for surf-enabled beach locations
- No crash when wave height is null — LocationCard already handles null with "—"
- Existing tests pass unchanged

### T1.5 — Verify data pipeline end-to-end after fixes

- Owner: Coordinator (Opus)
- No code changes — verification only

**Do:** After T1.1-T1.4 are deployed, verify:
1. `GET /marine` returns DIFFERENT `waveHeight` values for different locations (not identical 2.13 ft for all 7)
2. `GET /marine` returns DIFFERENT `waterTemp` values where ocean model coverage differs (or the same value with a different source — OFS/MUR SST, not buoy 46253)
3. Huntington Harbor and Newport Bay show `waveHeight: null`
4. Cache warmer logs show successful NWPS and ERDDAP fetches
5. Surf endpoint `GET /surf/{id}` returns NWPS-sourced wave data (source field includes "nwps")

**Accept:** Evidence pasted in the plan with actual API response data showing differentiated values.

### QC Gate 1
**Coordinator mechanical checks:**
- Cache warmer: NWPS shows "refreshed" not "warm failed"
- Cache warmer: ERDDAP shows successful fetches, not TypeError
- `GET /marine` wave heights differ across locations
- `GET /marine` harbor locations show null wave height
- `GET /marine` water temp source is ocean resolver, not buoy 46253
- API pytest baseline holds

**Adversarial auditor verification:**
- Read `nwps.py` line 491 — confirms `.lower()` applied to wfo
- Read `erddap_ocean.py` line 81 — confirms correct ProviderHTTPClient constructor
- Read `marine_config.py` MarineLocation.__init__ — confirms case normalization on WFO/zone fields
- Read `marine.py` _location_summary — confirms harbor detection logic
- Attempt to break: pass mixed-case WFO codes, verify they all resolve correctly
- Verify: no hardcoded "lox" or "LOX" anywhere — the code handles any case

---

## Phase 2 — API Detail Endpoint Enrichment + Multi-Point Surf Scoring

The detail endpoint (`GET /marine/{id}`) returns raw NDBC buoy observation only. The card summary endpoint correctly enriches from forecast provider, NWPS, and ocean resolver. The detail endpoint needs the same enrichment. Additionally, the surf endpoint needs to score multiple NWPS time steps for the 72-hour timeline.

### T2.1 — Enrich `GET /marine/{id}` observation with forecast provider + model data

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/endpoints/marine.py` (`get_marine_location()` at line 447+)
- Reference: `_location_summary()` in the same file (lines 316-500) — this is the reference implementation that correctly enriches from all sources. Copy the same dispatch pattern.

**Problem:** `get_marine_location()` returns only the raw NDBC buoy observation as `MarineBundle.observation`. The buoy (46253) does not report wind, pressure, air temp, visibility, or weatherCode. The dashboard's BoatingTab, FishingTab, and BeachSafetyTab all read from this observation and show "—" for everything.

**Do:** After the existing NDBC buoy fetch in `get_marine_location()`, enrich the observation with data from the same sources `_location_summary()` uses:

1. **Wind/air temp/conditions** — call `marine_location_resolver.is_station_served(location.id)`. If True: read from weewx archive (`db.get_current()`). If False: read from `marine_weather_cache.get_current_conditions(location.lat, location.lon)`. Populate: `windSpeed`, `windDirection`, `windGust`, `airTemp`, `pressure`, `visibility`, `weatherCode`, `isDay`.

2. **Wave height** — same NWPS → WaveWatch III → NDBC fallback chain from `_location_summary()` lines 389-437. Override the buoy's raw `waveHeight` with the model-derived value.

3. **Water temp** — call `ocean_data_resolver.resolve(lat, lon, location_config, needs="surface")`. Override the buoy's raw `waterTemp` with the resolver's `surface_temp`.

4. **Unit conversion** — apply `_convert_observation()` to the enriched observation (same as current behavior, but now with non-null fields).

5. Add `weatherCode: int | null` and `isDay: bool | null` fields to `MarineObservation` in `models/responses.py` if not already present. Add them to `MarineBundle` response as top-level fields as well.

**Do NOT refactor `_location_summary()` and `get_marine_location()` into a shared function.** The two endpoints have different response shapes and different additional data (the detail endpoint fetches text forecast, NWS marine text, etc. that the summary does not). Copy the enrichment pattern — don't create a fragile shared abstraction.

**Accept:**
- `GET /marine/huntington-city-beach-pier` returns non-null `observation.windSpeed`, `observation.airTemp`
- `observation.waveHeight` matches the card summary's value (from NWPS, not buoy)
- `observation.waterTemp` matches the card summary's value (from ocean resolver, not buoy)
- `observation.weatherCode` and `observation.isDay` are present (may be null if provider doesn't supply them for this grid point — that's fine)
- Existing fields that WERE populated from the buoy (dominantPeriod, averagePeriod, spectralComponents) are still present
- Existing tests pass unchanged

### T2.2 — Add `weatherCode` and `isDay` to `MarineObservation` type

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/models/responses.py` (API), `src/api/types.ts` (dashboard)

**Do:**
1. In `models/responses.py`: add `weatherCode: int | None = None` and `isDay: bool | None = None` to `MarineObservation` (Pydantic model).
2. In `src/api/types.ts`: add `weatherCode: number | null` and `isDay: boolean | null` to `MarineObservation` interface.

**Accept:** Both API and dashboard types include the new fields. No runtime errors.

### T2.3 — Multi-point surf forecast scoring

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `weewx_clearskies_api/endpoints/surf.py`
- Reference: `enrichment/surf_scorer.py` `score_surf()` function

**Problem:** The surf endpoint runs `score_surf()` once for the current NWPS snapshot and returns `forecast: [one_point]`. The dashboard's `ForecastTimeline` component is designed for multi-point data but only ever gets one point. The surf scorer produces rich output (conditionsText, windQuality, swellDominance, multiSwell) that the dashboard should display across a 72-hour timeline.

**Do:**
1. After fetching NWPS data, extract ALL available forecast time steps (NWPS typically provides data at multiple time points across its forecast cycle).
2. For each time step, run `score_surf()` with that time step's wave height, period, direction, and the corresponding wind data.
3. Return the full array as `SurfDetailData.forecast` (the response model already supports `list[SurfForecast]`).
4. If NWPS only provides one time step (current snapshot), still return it as a single-element array — the dashboard handles this case already.
5. Each `SurfForecast` in the array includes: `time`, `qualityStars`, `qualityLabel`, `conditionsText`, `windQuality`, `swellDominance`, `waveHeightAtBreak`, `period`, `direction`, `multiSwell`.

**Accept:**
- `GET /surf/huntington-city-beach-pier` returns `forecast` array with ≥1 element
- When NWPS provides multiple time steps, the array has multiple elements with different times and potentially different scores
- Each element includes `conditionsText` (the composed natural-language summary)
- Each element includes all scoring fields (`qualityStars`, `windQuality`, `swellDominance`, etc.)
- Existing tests pass unchanged

### T2.4 — Investigate and fix null weatherCode/isDay on card summary

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `weewx_clearskies_api/services/cache_warmer.py`, `weewx_clearskies_api/endpoints/marine.py`

**Problem:** QC Gate 6 noted `weatherCode/isDay: null` on all locations. The forecast provider's `fetch_current_conditions()` is called in the cache warmer, but the response may not include `weatherCode`/`isDay` for the SoCal grid points, or the fields may not be wired through to the summary.

**Do:**
1. Check what `marine_weather_cache.get_current_conditions()` returns for a configured location — does it include `weatherCode` and `isDay`?
2. If the forecast provider returns them: verify they're wired through `_location_summary()` into the response.
3. If the forecast provider does NOT return them for these grid points: check whether the NWS forecast API's `icon` field can be parsed into a WMO code as a fallback.
4. If no source provides them: document this gap clearly so the dashboard knows to handle null gracefully (no empty icon placeholder — just show temperature without an icon).

**Accept:**
- Root cause of null weatherCode/isDay identified and documented
- If fixable: `GET /marine` returns non-null `weatherCode` for at least one location
- If not fixable: documented in this plan's decision log with the specific reason

### QC Gate 2
**Coordinator mechanical checks:**
- `GET /marine/huntington-city-beach-pier` returns non-null `windSpeed`, `airTemp` (not "—")
- `GET /marine/huntington-city-beach-pier` `waveHeight` matches card summary value
- `GET /surf/huntington-city-beach-pier` returns `forecast` array with `conditionsText` on each element
- `weatherCode`/`isDay` status documented (either working or root cause identified)
- API pytest baseline holds

**Adversarial auditor verification:**
- Read `get_marine_location()` — verify enrichment from forecast provider, NWPS, ocean resolver (not just buoy)
- Read `surf.py` — verify multi-point scoring loop over NWPS time steps
- Verify `MarineObservation` model has `weatherCode` and `isDay` fields
- Verify dashboard `MarineObservation` type matches API model
- Attempt: call detail endpoint for a harbor location — should still return enriched wind/temp but null wave height

---

## Phase 3 — Marine Landing Page Redesign

Refactor the marine page landing state to use the official grid system, proper Card components, numbered pins, linked hover, stat icons, weather icons, and responsive map layout.

### T3.1 — Fix page header icons (Marine + Seismic) (F8)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/routes/marine.tsx`, `src/routes/seismic.tsx`, `src/components/icons/earthquake.tsx`

**Do:**
1. `marine.tsx` line 200: change `icon={<Waves aria-hidden="true" className="h-7 w-7" />}` to `icon={<Waves weight="duotone" />}`. Remove the `h-7 w-7` className and the redundant `aria-hidden` (the `PageHeaderCard` wrapper already sets `aria-hidden="true"` on the icon container).
2. `earthquake.tsx` line 24: change the component so when no `size` prop is passed, it uses `width="1em" height="1em"` instead of `width={20} height={20}`. This makes it inherit the font-size from the `PageHeaderCard` wrapper (3.75rem), matching Phosphor's behavior. When `size` IS passed (for use in alert icons at specific sizes), continue using `width={size} height={size}`.
3. `seismic.tsx` line 230: change `icon={<Earthquake size={28} />}` to `icon={<Earthquake />}`.

**Accept:**
- Marine page header icon is ~60px duotone Waves (same visual weight as Forecast's CloudSun)
- Seismic page header icon is ~60px Earthquake (same visual weight as other page headers)
- Both icons are visually proportional to the page title text
- `tsc --noEmit` clean. `vite build` clean.

### T3.2 — Remove "Use my location" button (F11)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/marine.tsx`

**Do:** Remove:
1. The `handleUseMyLocation` function (lines 126-146)
2. The `geoStatus` and `geoErrorMessage` state declarations (lines 118-119)
3. The `findNearestLocation` and `haversineKm` helper functions (lines 34-61)
4. The Button + error display JSX (lines 228-241)
5. The `Crosshair` import from `@phosphor-icons/react` (line 14, if no longer used)
6. The `div` wrapper around the button (lines 226-242) — the `<h2 className="sr-only">` can remain but moves outside this wrapper

**Accept:**
- No "Use my location" button or geolocation code in marine.tsx
- No `Crosshair` import
- Page still renders correctly without the button
- `tsc --noEmit` clean

### T3.3 — Remove "Updated X minutes ago" from LocationCards (F12)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationCard.tsx`

**Do:**
1. Remove the `updatedLabel` computation (lines 52-56)
2. Remove the `updatedLabel` rendering in the bottom row (lines 131-135)
3. Remove the `formatRelativeTime` import if no longer used elsewhere in this file
4. The bottom row now contains only the alert badge (when alerts > 0) or nothing. If no alerts and no updated label, the empty `<span />` placeholder (line 130) and the wrapping `div` (lines 114-136) can be simplified or removed entirely.

**Accept:**
- No "Updated X minutes ago" text on any LocationCard
- Alert badge still renders when alerts > 0
- `tsc --noEmit` clean

### T3.4 — Refactor marine landing state to use official Grid (F9)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/marine.tsx`, `src/components/marine/LocationCard.tsx`

**Problem:** The landing state wraps everything in a single `col-span-full` div and creates an internal `grid-cols-3` grid. LocationCards are not `Card` components. This bypasses the 4-column Grid system.

**Do:**
1. **LocationCard**: Refactor to use the `Card` component from `components/ui/card.tsx`. The card should:
   - Accept `footprint="tile"` (1 column) — placed as a direct child of the Grid
   - Be a `<button>` inside the Card (for click-to-select), not the Card itself being a button
   - Use `CardContent` for the stat area
   - Keep the existing glass surface styling (Card provides this via `card-glass`)

2. **Landing state layout**: Remove the `col-span-full` wrapper div. Place the map and LocationCards as direct children of the PageLayout's Grid:
   - Map: `footprint="full"` element (spans all 4 columns at lg)
   - Each LocationCard: `footprint="tile"` (1 column each, flowing 4 per row at lg, 2 per row at md, 1 on mobile)
   - This replaces the internal `grid-cols-3` grid

3. **Remove the internal grid wrapper** (`div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3"` at line 252). Cards flow naturally in the Grid.

**Accept:**
- LocationCards are `Card` components with `footprint="tile"`
- LocationCards are direct children of the Grid, not wrapped in an internal grid
- At lg (1024px+): 4 cards per row
- At md (768px+): 2 cards per row
- Mobile: 1 card per row (stacked)
- Map spans full width above the cards
- `tsc --noEmit` clean. `vite build` clean.

### T3.5 — Numbered map pins + LocationCard badges (F15)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/LocationMap.tsx`, `src/components/marine/LocationCard.tsx`, `src/routes/marine.tsx`

**Do:**
1. **Numbered pins** — In `LocationMap.tsx`, replace the generic `defaultIcon` (line 66) with numbered `L.divIcon` markers. Each location gets a number (1-based index from the locations array). The pin style:
   - 24×24px circle with `background: var(--primary)` (the operator accent color, available as a CSS variable)
   - White number text, centered, font-size 12px, font-weight 600
   - Same shadow/border treatment as the existing alert icon (line 49-55)
   - Alert locations: amber circle with number (same size, `background: #f59e0b`)
   - Create a function `createNumberedIcon(index: number, isAlert: boolean): L.DivIcon`

2. **Card badges** — In `LocationCard.tsx`, add a small number badge in the top-left area (next to or above the location name). The badge should:
   - Show the same number as the map pin
   - Be a small circle (20×20px) with `bg-primary text-primary-foreground` and the number centered
   - Accept `index: number` as a prop from the parent

3. **Pass index** — In `marine.tsx`, pass `index={i}` (0-based) to each LocationCard and the locations array to LocationMap (already passed). The numbering must be consistent: `locations.map((loc, i) => ...)` uses the same order for both pins and cards.

**Accept:**
- Each map pin shows a number (1, 2, 3...)
- Each LocationCard shows the same number as a badge
- Numbers match: pin #3 corresponds to card #3
- Alert locations show amber numbered pins
- `tsc --noEmit` clean

### T3.6 — Linked hover states between pins and cards (F15)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/routes/marine.tsx`, `src/components/marine/LocationMap.tsx`, `src/components/marine/LocationCard.tsx`

**Do:**
1. **State**: Add `hoveredId` state to `MarinePage`: `const [hoveredId, setHoveredId] = useState<string | null>(null);`

2. **Card → pin**: LocationCard accepts `onHover: (id: string | null) => void` and `isHovered: boolean` props. On `onMouseEnter`: call `onHover(locationId)`. On `onMouseLeave`: call `onHover(null)`. When `isHovered` is true: apply `ring-2 ring-primary bg-foreground/5` (stronger than current `hover:ring-primary/40`). Also apply the strong hover on actual CSS hover: `hover:ring-2 hover:ring-primary hover:bg-foreground/5`.

3. **Pin → card**: LocationMap accepts `hoveredId: string | null` and `onHoverLocation: (id: string | null) => void` props. Each marker gets `mouseover` → `onHoverLocation(loc.locationId)` and `mouseout` → `onHoverLocation(null)`. When a pin's locationId matches `hoveredId`, the pin visually enlarges (scale the divIcon to 1.3× via CSS transform or create a larger variant).

4. **Thread props**: `MarinePage` passes `hoveredId`, `setHoveredId` as `onHover`/`onHoverLocation` to both components.

**Accept:**
- Hovering a card highlights the corresponding map pin (visually larger/different)
- Hovering a map pin highlights the corresponding card (ring-2 ring-primary)
- Leaving hover returns both to default state
- No flicker or lag — state updates are synchronous
- `tsc --noEmit` clean

### T3.7 — Add stat icons to LocationCard (F16)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationCard.tsx`

**Do:** In the `<dl>` stat grid (lines 84-103), add Phosphor icons inline with each `<dt>` label:

```tsx
<dt className="flex items-center gap-1 text-muted-foreground" style={{ fontSize: 'var(--text-label)' }}>
  <Waves aria-hidden="true" focusable="false" className="size-3" />
  {t('waveHeight')}
</dt>
```

| Stat | Icon | Import |
|---|---|---|
| Wave Height | `Waves` | `@phosphor-icons/react` |
| Wind | `Wind` | `@phosphor-icons/react` |
| Water Temp | `Thermometer` | `@phosphor-icons/react` |

Icons at `className="size-3"` (12px, matching `--text-label` at 0.75rem). All decorative (`aria-hidden`, `focusable="false"`).

**Accept:**
- Each stat label has its designated Phosphor icon
- Icons are 12px, visually aligned with label text
- `tsc --noEmit` clean

### T3.8 — Add hero weather icon next to temperature (F13)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationCard.tsx`

**Do:** In the top row (lines 70-82), when `conditions?.weatherCode` is non-null, render the `WeatherIcon` component next to the air temperature:

```tsx
<div className="flex items-center gap-1.5 shrink-0">
  {conditions?.weatherCode != null && (
    <WeatherIcon
      code={conditions.weatherCode}
      isNight={conditions.isDay === false}
      size={28}
    />
  )}
  <span
    className="font-semibold text-foreground"
    style={{ fontSize: 'var(--text-stat-tile)', fontFeatureSettings: '"tnum"' }}
  >
    {formatValue(airTemp, 'temperature', locale)}{units?.temperature ?? ''}
  </span>
</div>
```

When `weatherCode` is null, show temperature only (current behavior). No empty placeholder.

Import `WeatherIcon` from `@/components/weather-icon`.

**Accept:**
- Weather icon renders next to temperature when weatherCode is non-null
- No icon when weatherCode is null (no empty space)
- Icon uses day/night variant based on `isDay`
- `tsc --noEmit` clean

### T3.9 — Responsive map layout based on site geography (F10)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/routes/marine.tsx`, `src/components/marine/LocationMap.tsx`

**Do:**
1. In the landing state, compute the bounding box aspect ratio from location coordinates:
```tsx
const { layoutMode, mapHeight } = useMemo(() => {
  if (!locations || locations.length < 2) return { layoutMode: 'horizontal' as const, mapHeight: 400 };
  const lats = locations.map(l => l.coordinates.lat);
  const lons = locations.map(l => l.coordinates.lon);
  const latSpan = Math.max(...lats) - Math.min(...lats);
  const centerLat = (Math.max(...lats) + Math.min(...lats)) / 2;
  const lonSpan = (Math.max(...lons) - Math.min(...lons)) * Math.cos(centerLat * Math.PI / 180);
  const aspect = latSpan > 0 ? lonSpan / latSpan : 2;
  if (aspect <= 0.8) return { layoutMode: 'vertical' as const, mapHeight: 600 };
  return { layoutMode: 'horizontal' as const, mapHeight: 400 };
}, [locations]);
```

2. **Horizontal layout** (aspect ≥ 0.8): current pattern — map full-width above, cards below in grid. Map height 400px.
3. **Vertical layout** (aspect < 0.8): at lg breakpoint, map on one side (`footprint="panel"`, 3 columns) and cards stacked on the other side (1 column). Map height 600px (tall). At md and below, collapse to stacked (map on top, cards below).
4. `LocationMap` accepts a `height` prop (number, px) instead of the hardcoded `h-[400px]`.

**Accept:**
- SoCal locations (wider than tall) → horizontal layout
- A hypothetical north-south coast → vertical layout (test with modified coordinates)
- Mobile: always stacked regardless of aspect
- Map height adapts to layout mode
- `tsc --noEmit` clean. `vite build` clean.

### QC Gate 3
**Coordinator mechanical checks:**
- Page header icons: Marine ~60px duotone Waves, Seismic ~60px Earthquake (same size as Forecast CloudSun)
- No "Use my location" button or geolocation code
- No "Updated X ago" on cards
- LocationCards are `Card` components with `footprint="tile"` in the Grid
- 4 cards per row at lg, 2 at md, 1 on mobile
- Numbered pins (1-7) match numbered badges on cards
- Hover card → pin highlights, hover pin → card highlights
- Stat icons: Waves/Wind/Thermometer on each card
- `tsc --noEmit` clean. `vite build` clean.

**Adversarial auditor verification — DESIGN-MANUAL compliance:**
- LocationCard uses `Card` component (not hand-rolled `<section>`)
- No internal `grid-cols-3` grid — cards are direct Grid children
- Typography uses `var(--text-*)` tokens
- `fontFeatureSettings: '"tnum"'` on all numeric values
- Icons from Phosphor, correct weight
- Hover states use `ring-2 ring-primary`, not `ring-primary/40`
- Map height uses prop, not hardcoded class

---

## Phase 4 — Location Photo System (F14)

### T4.1 — Config UI photo upload (wizard + admin)

- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo
- Files: `weewx_clearskies_config/templates/wizard/step_marine.html`, `weewx_clearskies_config/templates/admin/marine.html`, `weewx_clearskies_config/wizard/routes.py`, `weewx_clearskies_config/admin/routes.py`

**Photo is static content — handled by the Config UI (stack repo), NOT the API.** Per the architecture, the API handles weewx data and provider information. Static files are served by Caddy. The Config UI handles all operator configuration including file uploads.

**Do:**
1. **Wizard**: In the marine step, after the location name/coordinates fields, add a file input for the location photo. Accept `.webp`, `.jpg`, `.jpeg`. Max file size 200KB (client-side validation + server-side check). Preview thumbnail after selection.
2. **Admin**: In the per-location edit form, add the same file input with preview. Add a "Remove photo" button when a photo exists.
3. **Route handlers**: On form submission, save the uploaded file to `/etc/weewx-clearskies/marine-photos/{location_id}.webp`. If JPEG, convert to WebP using Pillow (already available in the stack's Python environment). Validate: min 600×400, max 200KB after conversion.
4. **Photo URL in config**: Store `photo_path = /etc/weewx-clearskies/marine-photos/{location_id}.webp` in the `[marine][[locations]][[[{id}]]]` section of `api.conf`. The API reads this and returns a URL in the response.
5. **Help content**: Add i18n keys explaining photo format (WebP/JPEG, 600×400 min, 200KB max, landscape orientation, recognizable view of the location).

### T4.2 — Caddy route for marine photos

- Owner: Coordinator (Opus) — documentation + config
- Files: Caddyfile variants in stack repo, `docs/ARCHITECTURE.md`

**Do:**
1. Add `/marine-photos/*` route to all Caddyfile variants (frontend-host, single-host, reverse-proxy):
```
handle /marine-photos/* {
    root * /etc/weewx-clearskies
    file_server
}
```
2. Update ARCHITECTURE.md Caddy routing table with the new route.

### T4.3 — API returns photo URL in MarineLocationSummary

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `weewx_clearskies_api/models/responses.py`, `weewx_clearskies_api/endpoints/marine.py`, `src/api/types.ts`

**Do:**
1. Add `photoUrl: str | None = None` to `MarineLocationSummary` (API model).
2. In `_location_summary()`, read the `photo_path` from location config. If the file exists, set `photoUrl = f"/marine-photos/{location.id}.webp"`. If not, `photoUrl = None`.
3. Add `photoUrl: string | null` to `MarineLocationSummary` in dashboard types.

### T4.4 — Render photo on LocationCard

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationCard.tsx`

**Do:** When `location.photoUrl` is non-null, render the photo on the right ~40% of the card:
1. Card layout becomes `flex-row` (horizontal) instead of `flex-col`
2. Left ~60%: existing text content (name, temp, stats)
3. Right ~40%: `<img>` with `object-fit: cover`, clipped to the card's right border-radius
4. Gradient overlay where text meets photo: `linear-gradient(to right, rgb(var(--card-glass)) 55%, transparent 100%)`
5. When `photoUrl` is null: card renders as text-only (current layout, `flex-col`)
6. Photo `alt` text: location name

**Accept:**
- Cards with photos show the photo on the right
- Cards without photos render text-only (no empty placeholder)
- Photo is `object-fit: cover`, no stretching
- Text is readable over the gradient overlay
- Mobile: photo may stack below text or shrink — test at all breakpoints

### QC Gate 4
- Wizard: photo upload field present, validates format/size
- Admin: photo upload + remove present
- Photos stored at `/etc/weewx-clearskies/marine-photos/`
- Caddy serves `/marine-photos/*`
- `GET /marine` includes `photoUrl` for locations with photos
- LocationCards render photos when available
- No photos: cards render text-only
- JPEG uploads converted to WebP

---

## Phase 5 — Detail Page Shell (F17-F20)

### T5.1 — Fix phantom fixed text (F17)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/routes/marine.tsx`, potentially `src/components/marine/ActivityTabs.tsx`

**Problem:** Text on the detail page stays fixed on the viewport and does not scroll with content. **This has been reported twice and was supposedly fixed in T1.5 but wasn't.** The implementing agent MUST verify the fix in a browser by scrolling the page — grep-based verification is not sufficient.

**Do:**
1. Open the marine detail page in a browser (all 4 tabs)
2. Scroll the page and identify which text element(s) remain fixed
3. Fix: remove `position: fixed`, `position: sticky`, or any z-index/stacking context issue causing the text to separate from the scroll flow
4. Verify the fix by scrolling again — ALL text must scroll with the page

**Accept:**
- All text on the detail page scrolls with the page content
- No fixed-position text elements remain
- Verified in a browser at both desktop and mobile viewport widths

### T5.2 — Detail map zooms to single location (F18)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationMap.tsx`

**Do:**
1. When `variant="hero"`, compute `bounds` from the selected location only (not all locations). Use `center` + `zoom` props on MapContainer instead of `bounds`: `center={[selectedLoc.lat, selectedLoc.lon]}`, `zoom={14}`.
2. Only render the selected marker — remove all other markers in hero mode.
3. Remove the `FlyToSelected` component call in hero mode — no animation needed when the map starts centered.

**Accept:**
- Hero map shows only the selected location's marker at zoom 14-15
- Coastal features (pier, harbor entrance, breakwater) are visible at this zoom
- No other location markers visible
- No fly-to animation on initial render

### T5.3 — Add OpenSeaMap marine feature overlay (F19)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/LocationMap.tsx`

**Do:** Add a second `TileLayer` for OpenSeaMap, rendered above the basemap:
```tsx
<TileLayer
  url="https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png"
  attribution='Map data: &copy; <a href="http://www.openseamap.org">OpenSeaMap</a> contributors'
  opacity={0.7}
/>
```

This adds buoys, beacons, harbors, channels, depth contours, and pier labels to both the landing map and the detail hero map.

**Accept:**
- Marine features (buoys, channels, harbors) visible on both maps
- OpenSeaMap tiles load without CORS errors
- Tiles render correctly in both light and dark themes
- Attribution includes OpenSeaMap

### T5.4 — Detail combo card: map + photo (F20)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/routes/marine.tsx`, `src/components/marine/LocationMap.tsx`

**Do:** Replace the 120px hero map strip with a combo card:
1. Use `Card` component with `footprint="full"` — not a bare div
2. Interior layout: `flex-row` at md+, `flex-col` on mobile
3. Left side (~60%): `LocationMap` with `variant="hero"`, height 220px (not 120px), zoomed to single location (T5.2), with OpenSeaMap overlay (T5.3)
4. Right side (~40%): `<img src={selectedLocation.photoUrl}>` with `object-fit: cover`, clipped to the card's right border-radius
5. No photo fallback: map takes full width, height 220px
6. On mobile: map full width 180px, photo below (or hidden to save space)

**Accept:**
- Combo card renders map + photo side by side on desktop
- Map is zoomed to single location with marine labels
- Photo is clipped to card shape
- Falls back to full-width map when no photo
- Card uses proper `Card` component with `footprint="full"`

### QC Gate 5
- Phantom text fixed — verified by scrolling in browser
- Detail map zoomed to single location at zoom 14-15
- OpenSeaMap overlay visible on both maps
- Combo card renders map + photo (or map-only when no photo)
- All Card components used (no bare divs for cards)

---

## Phase 6 — BoatingTab Complete Redesign (F21)

Complete rebuild of the Boating tab using proper Card components, enriched API data (from Phase 2), and the unified conditions dashboard pattern from industry research.

### T6.1 — Create shared `MarineStatTile` component

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: NEW `src/components/marine/shared/MarineStatTile.tsx`

**Problem:** `StatTile` is duplicated as a local function in all 4 tab files. It doesn't match the `StatItem` pattern from `todays-highlights-card.tsx` (which uses icon + value + micro-label with display font).

**Do:** Create a shared, exported component:
```tsx
interface MarineStatTileProps {
  icon?: React.ReactNode;
  label: string;
  value: string;
  unit?: string;
}
```
- Icon (optional): Phosphor icon, decorative (`aria-hidden`), `size-4` (16px)
- Label: `--text-label`, `text-muted-foreground`, `<dt>`
- Value: `--text-stat-tile`, `font-semibold`, `fontFeatureSettings: '"tnum"'`, `<dd>`
- Unit: `--text-label`, `text-muted-foreground`, appended after value
- Layout: `flex flex-col gap-0.5` (label above value, icon inline with label)

**Accept:**
- Component exported from `shared/MarineStatTile.tsx`
- All 4 tab files import it instead of defining local duplicates
- Matches the design manual stat tile specification

### T6.2 — Rebuild BoatingTab with Card components and enriched data

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/BoatingTab.tsx` — complete rewrite

**The tab must use these components:**
- `Card` from `components/ui/card.tsx` with `footprint` props — NOT the local `Panel` function
- `CardHeader` + `CardTitle` (with `as="h3"` for heading level) — NOT bare `<h3>` elements
- `CardContent` — NOT bare children
- `MarineStatTile` from `shared/MarineStatTile.tsx` — NOT local `StatTile`
- `ChartContainer` for charts — same as current
- `TideChart` from `shared/TideChart.tsx` — same as current but with clipping fix (T6.3)

**Panel structure (top to bottom):**

1. **Alerts** — `AlertsPanel` (unchanged, already shared)

2. **Current Conditions** — Single `Card footprint="full"`:
   - `CardHeader` → `CardTitle as="h3"` → "Current Conditions"
   - `CardContent` → `<dl>` grid with `MarineStatTile` components:
     - Wind: speed + gust + direction (from enriched observation — Phase 2)
     - Air temp (from enriched observation)
     - Water temp (from ocean resolver)
     - Pressure + trend indicator (from enriched observation)
     - Barometric trend arrow (existing `PressureTrend` component, kept)
     - Water level offset stat (from tide compositor, if available)
     - Storm surge badge (if `stormSurgeLevel` non-null)
   - When `conditionsText` is available from a future boating scorer: show as headline text above the stat grid
   - If ALL fields are null (provider down): show "Conditions unavailable" with retry button

3. **Waves** — Single `Card footprint="full"`:
   - Current wave stats (height, period, direction) as `MarineStatTile` tiles at top
   - 72h wave forecast chart below (existing `WaveForecastChart`, with legend)
   - All wave data from NWPS/model sources (not buoy)
   - Self-hides entirely for harbor locations where wave data is null

4. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` (fixed, no clipping — T6.3)
   - Total water level overlay (if compositor data available)

5. **Marine Forecast** — `Card footprint="full"`:
   - Redesigned as structured columns following `DailyColumns` pattern
   - Each forecast period as a column: period name at top, wind (speed + direction icon), seas (wave height text), visibility, weather text
   - Use `HorizontalScrollNav` for horizontal scrolling when many periods
   - NOT expandable `<details>/<summary>` text blobs

6. **Remove entirely:**
   - "Nearest Offshore Buoy" panel (F21b)
   - "Weather at..." panel (duplicate of conditions data)
   - Wind forecast chart as a separate panel (wind data consolidated into Conditions)

**Accept:**
- BoatingTab uses `Card` + `CardHeader` + `CardTitle` + `CardContent` — zero local Panel functions
- Uses shared `MarineStatTile` — zero local StatTile duplicates
- Conditions panel shows actual data (not "—") when API enrichment (Phase 2) is deployed
- Marine forecast uses structured columns (not expandable text)
- No buoy observation panel
- `tsc --noEmit` clean. `vite build` clean.

### T6.3 — Fix TideChart left-side clipping (F21f)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/shared/TideChart.tsx`

**Do:**
1. Read `docs/reference/recharts-axis-reference.md` before making changes
2. Increase `margin.left` to accommodate the YAxis label + tick values (likely needs 40-48px, not the current value)
3. Ensure `XAxis domain` starts at or before the first data point timestamp
4. Ensure the `Area` component's data starts from the first prediction point
5. Test with multiple locations to verify no clipping at any zoom level

**Accept:**
- Left side of tide chart renders completely — no clipped curve
- YAxis labels fully visible
- Chart renders correctly for all 7 locations
- Verified visually in browser

### QC Gate 6
**DESIGN-MANUAL compliance (mandatory):**
- [ ] BoatingTab uses `Card` component — NOT local `Panel`
- [ ] Uses `CardHeader` + `CardTitle as="h3"` — NOT bare `<h3>`
- [ ] Uses shared `MarineStatTile` — NOT local `StatTile`
- [ ] Typography uses `var(--text-*)` tokens only
- [ ] Charts use `ChartContainer` with `ResponsiveContainer`
- [ ] Marine forecast uses structured columns (DailyColumns pattern) — NOT `<details>/<summary>`
- [ ] No buoy observation panel

**Adversarial auditor:**
- `grep "function Panel" BoatingTab.tsx` returns zero matches
- `grep "function StatTile" BoatingTab.tsx` returns zero matches
- Every `Card` component has `footprint` prop
- Every `CardTitle` has `as` prop
- No hardcoded font sizes
- TideChart: no left-side clipping (visual check required)

---

## Phase 7 — SurfingTab Complete Redesign (F22)

Surface the surf scoring system. Use `conditionsText` as the hero headline. Show the 72-hour scored timeline. Display scoring factor breakdown. Redesign swell components and compass.

### T7.1 — Rebuild SurfingTab with Card components and scoring system

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/SurfingTab.tsx` — complete rewrite

**The surf scorer (`enrichment/surf_scorer.py`) produces these fields per `SurfForecast`. ALL must be surfaced:**

| Field | Where to display | Visual treatment |
|---|---|---|
| `conditionsText` | **Hero headline** — top of tab, inside the first Card | Large text at `--text-body` or `--text-stat-label`. The composed summary: "3-4 ft at 12 seconds from the SSW. Offshore winds 5-10 mph. Clean conditions." |
| `qualityStars` | Hero card, badge | Star rating badge with `qualityColorClasses` (existing function) |
| `qualityLabel` | Hero card, alongside stars | "Poor" / "Fair" / "Good" / "Very Good" / "Epic" |
| `waveHeightAtBreak` | Hero card, stat tile | Height in display units with icon |
| `period` | Hero card, stat tile | Period in seconds |
| `direction` | Hero card, compass indicator | Compass direction (see T7.2 for compass redesign) |
| `windQuality` | Hero card, badge | "Offshore" / "Glassy" / "Cross-shore" / "Onshore" with color |
| `swellDominance` | Scoring breakdown | 0-1 score visualized as bar segment |
| `multiSwell` | Swell components section | Spectral breakdown (see T7.3 for redesign) |

**Panel structure (top to bottom):**

1. **Alerts** — `AlertsPanel`

2. **Current Conditions Hero** — `Card footprint="full"`:
   - `conditionsText` as the headline (large text, full width)
   - Star rating badge + quality label (e.g., "★★★★ Very Good")
   - Stat grid: wave height at break, period, direction compass, wind quality badge, water temp
   - Rip current risk as a status badge here (not a separate card) — from `zoneForecast.ripCurrentRisk`

3. **Scoring Breakdown** — `Card footprint="full"`:
   - 4 horizontal bars showing the weighted factors:
     - Wave Height (35%): green/amber/red fill proportional to score
     - Wave Period (35%): same
     - Wind Quality (20%): same
     - Swell Dominance (10%): same
   - Beach alignment and directional exposure filters shown as multipliers
   - Use gauge color tokens (`--gauge-fill`, `--gauge-unfill`) for the bars
   - This tells visitors WHY the rating is what it is

4. **72-Hour Surf Forecast Timeline** — `Card footprint="full"`:
   - `HorizontalScrollNav` with star-rated time slots (existing `ForecastTimeline` component, now with multi-point data from Phase 2 T2.3)
   - Wave face height chart below the timeline
   - Each slot shows: time, star rating, quality color

5. **Swell Components** — `Card footprint="full"`:
   - Redesigned per T7.3 (industry research patterns)

6. **Swell Direction Compass** — redesigned per T7.2

7. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` (with clipping fix from T6.3)

**Remove entirely:**
- Standalone "Conditions" card (wind quality + beach alignment were split from the hero — consolidate)
- Standalone rip current alert banner at the bottom (rip current becomes a condition badge)

### T7.2 — Redesign swell direction compass to match WindCompassCard

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/SurfingTab.tsx` (or extract to shared component)

**Problem:** The `BeachAlignmentDiagram` is a minimal SVG (circle + 4 cardinal labels + arrow line). The Now page's `WindCompassCard` uses a polished 72-tick ring with lit segments, animated bearing, cardinal labels, and center readout.

**Do:** Build a `SwellDirectionCompass` component following the `WindCompassCard` visual pattern (`src/components/WindCompassCard.tsx`):
- SVG `viewBox="0 0 420 420"` (same as wind compass)
- 72 ticks every 5° around the dial, same geometry (outer radius 175, tick length 24px)
- Ticks within ±8° of the swell direction are "lit" with `--chart-2` color (not `--primary` — differentiate from wind)
- Cardinal labels (N/S/E/W) at the same positions
- Center overlay: swell direction as degrees + cardinal text, dominant swell height + period
- No animation needed (swell direction doesn't change at loop-packet frequency)
- Smaller than the Wind Compass: render at ~160×160px within the Card content area

**Accept:**
- Swell compass visually matches the WindCompassCard's tick-ring style
- Direction indicated by lit tick segments (not a rotating arrow)
- Cardinal labels in the same positions
- Center shows direction + swell stats

### T7.3 — Redesign swell breakdown (industry research patterns)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/SurfingTab.tsx`

**Problem:** Current swell breakdown uses cramped colored `<li>` pills with `--text-micro` stats. No visual hierarchy — all components look equally important.

**Do:** Following the industry research (F22d):
1. Each swell component as a distinct row/card, ranked by energy contribution (primary → secondary → wind swell)
2. Primary swell is visually larger (more padding, larger text) than secondary/wind swells
3. Each component shows:
   - Classification badge ("Groundswell" / "Swell" / "Wind Swell") with color
   - Direction as a small compass arrow indicator (8px arrow icon rotated to the direction)
   - Height with unit
   - Period with quality tier label (e.g., "14s — Great" per Windy.app's tiers: 8s=normal, 11s=good, 14+=great)
   - Energy value
4. Use `Card` component for the container, `MarineStatTile` for individual stats

**Accept:**
- Primary swell is visually dominant
- Each component has direction arrow, height, period with tier, energy
- Period quality tiers match industry standards (8s normal, 11s good, 14+ great)
- Classification badges have distinct colors

### QC Gate 7
**DESIGN-MANUAL compliance (mandatory):**
- All SurfingTab cards use `Card` + `CardHeader` + `CardTitle`
- `conditionsText` displayed as hero headline
- Star rating + quality label visible
- Scoring breakdown shows all 4 weighted factors as visual bars
- 72h timeline renders multi-point data (if available from Phase 2)
- Swell compass matches WindCompassCard visual quality
- Swell breakdown has visual hierarchy (primary > secondary > wind)

**Adversarial auditor:**
- Verify `conditionsText` is read from `SurfForecast` response and displayed
- Verify all scoring fields (qualityStars, windQuality, swellDominance) are surfaced
- Verify no local Panel/StatTile duplicates
- Verify swell compass SVG viewBox matches WindCompassCard (420×420)

---

## Phase 8 — FishingTab Complete Redesign (F23)

Surface the fishing scoring system. Use `conditionsText` as the hero headline. Fix species data pipeline. Redesign solunar to match Almanac page. Show scoring breakdown.

### T8.1 — Fix species data pipeline (F23d)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `weewx_clearskies_api/endpoints/fishing.py`, `weewx_clearskies_api/config/marine_config.py`

**Problem:** `speciesScores` is null/empty in the API response. The species YAML database has species, and the location config has species listed, but the data isn't reaching the scorer.

**Do:**
1. Trace the path: `api.conf [marine][[locations]][[[{id}]]][[[[fishing]]]] species = ...` → `marine_config.py` FishingSpotConfig → `endpoints/fishing.py` → `score_fishing(species=[...])` → `FishingForecast.speciesScores`
2. At each step, verify the species list is non-empty
3. If the species are configured but not reaching the scorer: fix the wiring
4. If the species are not configured in `api.conf`: add them (the species YAML database was populated with 20+ SoCal species)
5. Verify `GET /fishing/huntington-city-beach-pier` returns `speciesScores` with non-null entries

**Accept:**
- `GET /fishing/{id}` returns `speciesScores` with ≥1 species entry
- Each species entry has: name, score, status, temperature suitability info

### T8.2 — Rebuild FishingTab with Card components, scoring system, and solunar

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/FishingTab.tsx` — complete rewrite

**Panel structure (top to bottom):**

1. **Alerts** — `AlertsPanel`

2. **Current Conditions Hero** — `Card footprint="full"`:
   - `conditionsText` from `FishingForecast` as the headline (e.g., "Good fishing. Falling pressure and incoming tide favor activity. Yellowfin croaker and California halibut are active.")
   - Overall score (0-100) as a prominent numeric display
   - Stat grid: pressure (+ trend), tide state, wind speed, water temp
   - All from enriched data (Phase 2)

3. **Scoring Breakdown** — `Card footprint="full"`:
   - 4 horizontal bars (pressure 37.5%, tide 31.25%, solunar 18.75%, time 12.5%)
   - Each bar: label, score (0-100), colored fill proportional to score
   - Green for high scores (>60), amber for moderate (30-60), muted for low (<30)
   - Tap/click each bar for explanation (what this factor means, why it scored high/low)

4. **Forecast Periods** — `Card footprint="full"`:
   - Structured columns following `DailyColumns` pattern
   - Each period: time window, overall score, color-coded (green/amber/red)
   - `HorizontalScrollNav` for scrolling

5. **Solunar Calendar** — `Card footprint="full"`:
   - **MUST match the Almanac page's `SunMoonDetailCard` visual quality**
   - Use `MoonPhaseIcon` from `components/moon-phase-icon.tsx` (same component the Almanac uses)
   - Show major/minor feeding periods as time windows on a horizontal timeline
   - Moon phase icon + illumination percentage
   - Arc visualization similar to the Almanac's sun/moon arc (from `SunMoonDetailCard`)
   - Major periods: accent color bars. Minor periods: muted color bars.
   - Current time indicator on the timeline

6. **Species Forecast** — `Card footprint="full"`:
   - Table with `<thead>/<tbody>/<th scope>` following DESIGN-MANUAL §11 data table pattern
   - Columns: Species name, Score (0-100), Status (active/moderate/inactive with color badge), Temperature suitability (optimal/good/marginal with color), Seasonal note
   - Alternating row backgrounds (`bg-muted/30`)
   - Sticky first column on mobile (`position: sticky, left: 0`)
   - Species without profiles: show "—" for temp suitability

7. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` with tide direction color coding (flood=blue, ebb=amber, slack=muted) per Fish & Tides research

### QC Gate 8
**DESIGN-MANUAL compliance + scoring system surfaced:**
- `conditionsText` displayed as hero headline
- Scoring breakdown shows all 4 factors as visual bars
- Solunar display uses `MoonPhaseIcon` from `components/moon-phase-icon.tsx`
- Species table follows data table pattern (thead/tbody/th scope, sticky first column)
- All Cards use `Card` + `CardHeader` + `CardTitle`
- Forecast periods use structured columns (DailyColumns pattern)

---

## Phase 9 — BeachSafetyTab Complete Redesign (F24)

Remove the crude `classify_sea_state()` safety classifier. Present itemized hazards. Wire UV index from forecast provider.

### T9.1 — Remove crude safety classifier from API

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/endpoints/beach_safety.py`

**Problem:** `classify_sea_state()` (line 195) uses two `if` statements: wave height >3ft = "dangerous", period <6s = "dangerous." The user explicitly rejected this approach. The plan's "What this plan does NOT fix" section said: "Overall safety computation — user does not like the approach, needs rethinking."

**Do:**
1. Keep `classify_sea_state()` and `classify_water_comfort()` for internal use (they provide data to the response) but do NOT use `safetyLevel` as a single overall assessment. The response should include the individual hazard data points — not a single collapsed label.
2. The `safetyLevel` field in the response: set to `null` or remove it. The dashboard will display individual hazards, not a single badge.
3. Each hazard indicator remains in the response as a separate field:
   - `ripCurrentRisk`: from NWS SRF (low/moderate/high)
   - `uvIndex`: from forecast provider (integer 0-11+)
   - `waveHeight` + `wavePeriod`: from NWPS/model data
   - `windSpeed` + `windDirection`: from enriched observation
   - `waterTemp` + `comfortLevel`: from ocean resolver + classify_water_comfort()

### T9.2 — Wire UV index from forecast provider

- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/endpoints/beach_safety.py`

**Problem:** `assessment.uvIndex` is always null because the NWS SRF product doesn't include UV for all WFOs/times. The forecast provider (`fetch_current_conditions()`) returns UV index.

**Do:**
1. Read UV index from `marine_weather_cache.get_current_conditions()` (same cache the card summary uses for wind/air temp)
2. If the cache has UV, use it. If not, fall back to the SRF value (which may also be null).
3. UV index is an integer 0-11+.

**Accept:**
- `GET /beach-safety/{id}` returns non-null `uvIndex` when the forecast provider supplies it
- UV is from the forecast provider cache, not from SRF

### T9.3 — Rebuild BeachSafetyTab with itemized hazards

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/marine/tabs/BeachSafetyTab.tsx` — complete rewrite

**NO overall "safe/caution/dangerous" badge.** We don't have enough information to issue a safety assessment. Present the data and let the visitor evaluate.

**Panel structure:**

1. **Alerts** — `AlertsPanel`

2. **Beach Conditions** — `Card footprint="full"`:
   - **Itemized hazard indicators** (Beach Report flag pattern) — each hazard as its own status row:
     - **Rip Current Risk**: badge (low=green, moderate=amber, high=red) + text label + guidance ("Stay close to shore, swim near lifeguards")
     - **UV Index**: numeric value + EPA tier label (Low/Moderate/High/Very High/Extreme) + SPF recommendation + guidance text
     - **Wave Height**: stat tile with height + period
     - **Wind**: stat tile with speed + direction
     - **Water Temperature**: stat tile with temp + comfort label (comfortable/cool/cold)
   - Storm surge badge (if `stormSurgeLevel` non-null — from compositor)
   - NO composite "Dangerous" badge — each hazard speaks for itself

3. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` with clipping fix

4. **Coastal Flooding Risk** (show-when-available) — `Card footprint="full"`:
   - NWPS v1.5 total water level and wave runup (existing, kept)

5. **Local Resources** (show-when-available) — external links (existing, kept)

**Remove entirely:**
- `SafetyIndicator` component and its "Safe/Caution/Dangerous" badge
- Standalone `RipCurrentPanel` (rip current becomes a hazard row in conditions)
- Standalone `WaterTempPanel` (water temp becomes a stat tile in conditions)
- Standalone `UVIndexPanel` (UV becomes a hazard row in conditions)

### QC Gate 9
- No "Safe/Caution/Dangerous" badge anywhere
- No `SafetyIndicator` component imported or rendered
- Each hazard shown as a separate indicator with its own color/badge
- UV index shows non-null value (from forecast provider)
- Rip current risk as a condition badge (not a full card)
- All Cards use `Card` + `CardHeader` + `CardTitle`

---

## Phase 10 — Admin & Wizard Fixes (F1-F7)

### T10.1 — Replace activity text badges with designated icons (F1)

- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo
- File: `weewx_clearskies_config/templates/admin/marine.html`

**Do:** Replace the `page-badge-list` div (lines 402-406) with inline SVG icons. The SVG paths for each activity:
- **Sailboat** (marine/boating): extract from Phosphor's `Sailboat` regular weight SVG
- **Surfing**: copy path data from `weewx-clearskies-dashboard/src/components/marine/SurfingIcon.tsx` (Material Symbols, viewBox `0 -960 960 960`)
- **FishSimple** (fishing): extract from Phosphor's `FishSimple` regular weight SVG
- **PersonSimpleSwim** (beach safety): extract from Phosphor's `PersonSimpleSwim` regular weight SVG

Each icon: 18×18px, `fill="currentColor"`, `<title>` with activity name for tooltip. Flex row with `gap: 4px`.

### T10.2 — Fix button styling (F2, F3, F7)

- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo
- File: `weewx_clearskies_config/templates/admin/marine.html`

**Do:**
1. Remove `style="font-size:0.75rem;padding:0.15rem 0.5rem"` from all buttons (lines 415, 423)
2. Remove `role="group"` from both button wrapper divs (lines 414, 434). Replace with `<div style="display:flex;gap:0.5rem">` for spacing.
3. Rename the "Connectivity" column header to "Status" (line 386)
4. Relabel "Test" button to "Check Sources" (line 420)

### T10.3 — Show NWS zone in list view (F5)

- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo
- File: `weewx_clearskies_config/templates/admin/marine.html`

**Do:** Change the Stations cell (lines 408-411) to include the NWS zone:
```html
<td style="white-space:nowrap;font-size:0.85rem">
  {{ loc.ndbc_station_ids | length }} {{ _("NDBC") }},
  {{ loc.coops_station_ids | length }} {{ _("CO-OPS") }}
  {% if loc.nws_marine_zone_id %}
  <br><span style="color:var(--pico-muted-color)">{{ _("NWS") }}: {{ loc.nws_marine_zone_id }}</span>
  {% else %}
  <br><span style="color:var(--pico-color-amber-500,#f59e0b)">{{ _("NWS: not configured") }}</span>
  {% endif %}
</td>
```
Rename column header from "Stations" to "Data Sources".

### T10.4 — Remove per-location bathymetry buttons (F4)

- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo
- Files: `weewx_clearskies_config/templates/admin/marine.html`, `weewx_clearskies_config/templates/wizard/step_marine.html`

**Do:**
1. Admin: Remove the "Update Bathymetry" button (lines 422-429)
2. Wizard: Remove the "Download Bathymetry" button (line 183), the spinner (line 192), and the results div (line 196)
3. Bathymetry downloads happen automatically during `/setup/apply` per PROVIDER-MANUAL §14.7 — no manual trigger needed

### QC Gate 10
- Activity icons (4 SVGs) render correctly in admin list
- Buttons are standard Pico CSS size, not shrunken
- Edit/Delete are separate buttons with gap, not merged
- NWS zone shown in list view with amber indicator when missing
- No per-location bathymetry buttons in admin or wizard
- "Check Sources" label on the diagnostic button
- Column header says "Data Sources" not "Stations" or "Connectivity"

---

## Verification (after all phases)

After all 10 phases complete:
- **Data pipeline**: NWPS wave data differs across locations. Ocean resolver provides water temp. Harbors show null wave height.
- **Landing page**: Grid conformance, numbered pins, linked hover, stat icons, weather icons, location photos, responsive map
- **Detail page**: Map zoomed to single location, OpenSeaMap overlay, combo map+photo card, no phantom text
- **BoatingTab**: Unified conditions dashboard, enriched data (not buoy dashes), structured marine forecast, no buoy panel
- **SurfingTab**: conditionsText hero, scoring breakdown, 72h timeline, polished compass, ranked swell components
- **FishingTab**: conditionsText hero, scoring breakdown, species table populated, solunar matching Almanac, structured forecast periods
- **BeachSafetyTab**: Itemized hazards (no crude "Dangerous" badge), UV index working, rip current as condition indicator
- **Admin**: Activity icons, standard buttons, NWS zone shown, no bathymetry buttons
- **All tabs**: DESIGN-MANUAL compliant — Card/CardHeader/CardTitle, shared MarineStatTile, proper Grid, proper typography, proper icons

---

## Priority order (all phases)

| Priority | Phase | Findings | Rationale |
|---|---|---|---|
| **0** | Phase 0 (docs) | F25, all research | Establish standards before building |
| **1** | Phase 1 (data pipeline) | F0 | Core pipeline non-functional |
| **2** | Phase 2 (API enrichment) | F21 root cause, F13 | Detail endpoint serves wrong data |
| **3** | Phase 3 (landing page) | F8-F12, F15-F16 | Grid conformance, card redesign |
| **4** | Phase 4 (photos) | F14 | New feature supporting card redesign |
| **5** | Phase 5 (detail shell) | F17-F20 | Map + combo card + phantom text |
| **6** | Phase 6 (BoatingTab) | F21 | Complete redesign with enriched data |
| **7** | Phase 7 (SurfingTab) | F22 | Surface scoring system |
| **8** | Phase 8 (FishingTab) | F23 | Surface scoring system |
| **9** | Phase 9 (BeachSafetyTab) | F24 | Replace crude classifier |
| **10** | Phase 10 (admin/wizard) | F1-F7 | Admin usability |
