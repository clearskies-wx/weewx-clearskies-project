# Fixit Plan: Cache Warming + Almanac Enhancements + Wizard Branding/Social

## Context

Four problems:
1. **Page load delays.** The records page takes 11-14 seconds because the API queries the full archive on-demand. Almanac and AQI history are likely slow too. Belchertown had zero delay because weewx pre-computed everything into static HTML every 5 minutes. Clear Skies needs the same pattern: pre-compute in the background, serve instantly from cache.
2. **Wizard Step 11 not done.** The wizard is missing branding (site title, logo, favicon) and social link screens. These were deferred from the unit-system plan and are the only remaining item.
3. **Almanac page missing climatological chart.** Belchertown has an "Average Climatological Values by Month" chart showing avg high/low temp, avg dewpoint, and avg monthly rainfall across all years. Clear Skies almanac page is astronomy-only — no weather/climate data.
4. **Almanac page missing expanded astronomy.** ADR-024 scoped "planets visible tonight, eclipses, meteor showers, conjunctions" to Phase 6+. Skyfield (the existing library) already supports all of these natively with the loaded DE421 ephemeris — no external API or new dependencies needed.

---

## Item 1: Background Cache Warming (ADR-045 + implementation)

### Step 1: Write ADR-045 — Background pre-computation caching

New ADR (not an amendment to ADR-017, which covers provider-response caching only). Cross-references ADR-017, ADR-012 (DB access).

**Caching policies per endpoint:**

| Endpoint | Refresh interval | Rationale |
|---|---|---|
| `/records?period=all-time` | 30 min | All-time records change rarely (only when broken). 11s query. |
| `/records?period=ytd` | 15 min | YTD records change with new extremes. 1.1s query but still worth caching. |
| `/almanac/sun-times` | 6 hours | Astronomy data changes once per day. 365-point calculation is CPU-bound. |
| `/almanac/moon-phases` | 6 hours | Same as sun-times — daily granularity. |
| `/aqi/history` | 30 min | Archive scan. Changes with each archive record but not time-critical. |
| Provider endpoints (forecast, alerts, AQI, earthquakes, radar) | Per ADR-017 | Already cached. No change. |
| `/current`, `/station`, `/branding`, `/capabilities`, `/pages`, `/reports` | No caching | Already fast (<100ms). |

**Key decisions for the ADR:**
- Cache backend: reuses ADR-017's `CacheBackend` protocol (memory or Redis)
- Daemon thread (not async task) — matches existing codebase pattern
- First refresh runs at startup (before first request)
- Cache miss = live query (graceful degradation, not error)
- Config: `[cache_warmer]` section in `api.conf` with `enabled`, `records_interval`, `almanac_interval`, `aqi_history_interval`

### Step 2: Dashboard quick fix — records default to YTD

**File:** `C:\CODE\weewx-clearskies-dashboard\src\routes\records.tsx` line 88
**Change:** Default period from `'all-time'` to `'ytd'`
**Why:** Immediate UX improvement. YTD loads in ~1s vs 14s. Users who want all-time click deliberately.

### Step 3: Create `services/cache_warmer.py`

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\services\cache_warmer.py` (new)

Class `BackgroundCacheWarmer`:
- Constructor takes: SQLAlchemy engine, ColumnRegistry, cache backend, intervals dict, station config (lat/lon for almanac)
- `start()` → launches daemon thread
- Thread loop: cycles through warm functions, sleeps for shortest remaining interval
- `warm_records()` — calls `get_records()` for `all-time` and `ytd`, serializes to cache
- `warm_almanac()` — calls almanac service for sun-times + moon-phases (current year), serializes to cache
- `warm_aqi_history()` — calls AQI history service, serializes to cache
- Each warm function catches all exceptions (log WARNING, skip, retry next cycle)
- Needs its own DB session per cycle (not request-scoped)

**Cache key pattern:** `warmer:{endpoint}:{params_hash}` (e.g., `warmer:records:all-time`, `warmer:almanac:sun-times:2026`)

### Step 4: Wire cache checks into endpoint handlers

**Files to modify:**
- `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\records.py` — check cache before calling `get_records()`
- `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\almanac.py` — check cache for sun-times and moon-phases
- `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\aqi.py` — check cache for history

Pattern (same as existing provider caching):
```python
cached = get_cache().get(cache_key)
if cached is not None:
    return RecordsResponse.model_validate(cached)
# ... live query, then set cache ...
```

### Step 5: Launch warmer in `__main__.py`

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\__main__.py`
- After step 6h (cache wired), create `BackgroundCacheWarmer` and call `start()`
- First refresh runs synchronously before server starts (so first request hits warm cache)
- Subsequent refreshes run in daemon thread

### Step 6: Config + docs

- Add `[cache_warmer]` to `C:\CODE\weewx-clearskies-api\config\api.conf.example`
- Add `CacheWarmerSettings` to `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\config\settings.py`

---

## Item 2: Wizard Branding + Social (2 new screens)

### What's included
- **Screen 1 (Branding):** Site title, logo (light + dark), favicon
- **Screen 2 (Social):** Facebook, Twitter/X, Instagram, YouTube URL inputs

### What's NOT included (per user direction)
- No accent color picker (not allowing that level of operator customization)
- No theme mode selector (built into dashboard, per-user choice)
- No display labels screen (i18n already handles this across 13 locales)

### Step 7: API — Extend branding model + config

**Files:**
- `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\branding.py`
- `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\config\settings.py`

**Changes:**
- Add to `BrandingSettings`: `site_title`, `logo_light_url`, `logo_dark_url`, `favicon_url`
- Add `SocialSettings`: `facebook_url`, `twitter_url`, `instagram_url`, `youtube_url`
- Add to `BrandingConfig` response: `siteTitle`, `logo.light`, `logo.dark`, `faviconUrl`, `social` object
- Read from `api.conf` `[branding]` section (site_title, logos, favicon) and `[social]` section (URLs)

### Step 8: API — Extend `/setup/apply` for branding + social

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\setup.py`

Add `BrandingApplyConfig` and `SocialApplyConfig` to the apply request schema. `_write_api_conf()` writes values to `[branding]` and `[social]` sections.

### Step 9: Stack — Add WizardState fields

**File:** `C:\CODE\weewx-clearskies-stack\weewx_clearskies_config\wizard\state.py`

Add fields: `site_title`, `logo_light_path`, `logo_dark_path`, `favicon_path`, `facebook_url`, `twitter_url`, `instagram_url`, `youtube_url`

### Step 10: Stack — Add branding + social route handlers

**File:** `C:\CODE\weewx-clearskies-stack\weewx_clearskies_config\wizard\routes.py`

- `step_branding_get/post` — GET pre-fills from `state.imported_config["extras"]["branding"]` + `state.imported_images`. POST validates and saves to state. Shows file type/size requirements (PNG/SVG, max 500KB for logos; ICO/PNG, max 100KB for favicon). Auto-pulls files if skin.conf already references them.
- `step_social_get/post` — GET pre-fills from `state.imported_config["extras"]["social"]`. POST saves URLs to state. Simple URL inputs, no toggles — blank = not shown.

### Step 11: Stack — Create wizard templates

**New files:**
- `C:\CODE\weewx-clearskies-stack\weewx_clearskies_config\templates\wizard\step_branding.html`
- `C:\CODE\weewx-clearskies-stack\weewx_clearskies_config\templates\wizard\step_social.html`

### Step 12: Stack — Wire into wizard flow

**Files:**
- `wizard/routes.py` — webcam POST redirects to branding (new step 8), branding POST → social (step 9), social POST → review (step 10)
- `templates/wizard/_progress_bar.html` — add Branding + Social labels
- `templates/wizard/step_review.html` — add branding/social summary sections
- `wizard/config_writer.py` — extend `build_skin_conf_payload()` for branding/social
- `wizard/state_persistence.py` — extend `_merge_from_existing_config()` for re-run pre-fill

### Step 13: Dashboard — Social footer icons

**File:** `C:\CODE\weewx-clearskies-dashboard\src\components\layout\footer.tsx` (or wherever the footer is)

Add social icons component:
- Icon-only inline SVGs from Simple Icons (simpleicons.org) — Facebook, Twitter/X, Instagram, YouTube
- 20x20px, `fill="currentColor"`, muted color default, hover to accent
- No border, no background — flex row with gap
- Only render platforms with non-empty URLs from branding API response
- Style matches coinrollhunting.org share button pattern

### Step 14: Dashboard — Wire branding fields

**Files:**
- `src/lib/branding.ts` — add `siteTitle`, `faviconUrl`, `social` to types
- `src/lib/branding-provider.tsx` — map new API fields, set document title from `siteTitle`
- `src/api/client.ts` — update `ApiBrandingConfig` type

---

## Item 3: Almanac — Climatological Values Chart

### What Belchertown shows
A spline/bar chart with 12 months on the X-axis, 4 data series:
- Average daily high temperature (avg of daily max per month, across all years) — red line
- Average daily low temperature (avg of daily min per month, across all years) — line
- Average dewpoint (straight avg per month, across all years) — purple line
- Average monthly rainfall total (avg of monthly rain sum, across all years) — blue column/bar

### Step 15: API — New climatology endpoint

**New file:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\services\climatology.py`
**New file:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\climatology.py`

`GET /api/v1/climatology/monthly` — returns 12 data points per series:

```json
{
  "data": {
    "months": ["Jan", "Feb", ..., "Dec"],
    "avgHighTemp": [45.2, 48.1, ...],
    "avgLowTemp": [28.3, 30.1, ...],
    "avgDewpoint": [22.1, 24.5, ...],
    "avgRainfall": [3.2, 2.8, ...]
  }
}
```

**SQL approach:** Group archive records by calendar month number (1-12) using existing `_month_bucket_sql()` from records.py. For each month:
- High temp: `AVG(MAX(outTemp) per day)` — subquery groups by day, takes MAX, outer query groups by month, takes AVG
- Low temp: `AVG(MIN(outTemp) per day)` — same pattern with MIN
- Dewpoint: `AVG(dewpoint)` — straight average
- Rainfall: `AVG(SUM(rain) per month-year)` — subquery groups by year-month, sums rain, outer query groups by month number, takes AVG

Reuses `_month_bucket_sql()` and `_day_bucket_sql()` from records.py. Self-hides fields not in ColumnRegistry.

**This endpoint is slow (full archive scan) → add to cache warmer** with 6-hour refresh (climatological averages change imperceptibly).

### Step 16: Dashboard — Climatological chart on almanac page

**File:** `C:\CODE\weewx-clearskies-dashboard\src\routes\almanac.tsx`

Add a new card: "Average Climatological Values by Month"
- Uses Recharts (already in the project) — ComposedChart with Line series for temps/dewpoint and Bar series for rainfall
- Dual Y-axes: left for temperature (°F/°C), right for rainfall (in/mm)
- New API hook: `useClimatology()` → `GET /api/v1/climatology/monthly`
- Place below existing sun/moon cards, above positional data

---

## Item 4: Almanac — Expanded Astronomy

All features use Skyfield with DE421 ephemeris (already loaded). No external APIs. No new dependencies.

### Step 17: API — Planet visibility by viewing period

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\services\almanac.py`

New function `_compute_planets_for_date()`:
- Loop 5 naked-eye planets: Mercury, Venus, Mars, Jupiter, Saturn
- For each: rise/set times (same pattern as moon), apparent magnitude via `skyfield.magnitudelib.planetary_magnitude()`
- Classify into **three viewing periods** based on rise/set vs sunset/sunrise:
  - **Evening** — planet is above horizon after sunset, sets before ~midnight. Best seen in western sky after dark.
  - **Morning** — planet rises after ~midnight, still above horizon at sunrise. Best seen in eastern sky before dawn.
  - **All night** — planet rises before sunset and sets after sunrise (near opposition). Visible all night.
- Use existing sunset/sunrise times from `_compute_sun_for_date()` + midnight as the classification boundaries
- Filter: only include planets with magnitude < 6.0 (naked-eye visible)

**New endpoint:** `GET /api/v1/almanac/planets`

Returns:
```json
{
  "data": {
    "date": "2026-05-27",
    "evening": [
      {"name": "Venus", "rise": "04:12", "set": "21:45", "magnitude": -3.9}
    ],
    "morning": [
      {"name": "Saturn", "rise": "03:30", "set": "12:15", "magnitude": 0.9}
    ],
    "allNight": [
      {"name": "Jupiter", "rise": "18:30", "set": "05:15", "magnitude": -1.9}
    ],
    "notVisible": ["Mercury", "Mars"]
  }
}
```

~100 lines of new code in almanac.py. Add to cache warmer with 6-hour refresh.

### Step 18: API — Special moon names + lunar eclipses

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\services\almanac.py`

Extend existing moon data with:

**Special full moon names** (~30 lines total):
- Traditional names by month: Wolf (Jan), Snow (Feb), Worm (Mar), Pink (Apr), Flower (May), Strawberry (Jun), Buck (Jul), Sturgeon (Aug), Corn (Sep), Hunter (Oct), Beaver (Nov), Cold (Dec) — simple lookup table
- Harvest moon: full moon nearest autumnal equinox — compare `moon_phases()` full moon dates with `seasons()` equinox date
- Blue moon: 2nd full moon in same calendar month — Counter on full moon dates
- Hunter's moon: next full moon after harvest moon
- Supermoon: full moon within 90% of perigee distance — check `observe(moon).distance()` at each full moon

**Lunar eclipses** (~20 lines):
- `skyfield.eclipselib.lunar_eclipses(t0, t1, eph)` — returns date + type (penumbral/partial/total)
- Add to existing `/almanac/moon-phases` response as `upcomingEclipses` array
- Or new endpoint `GET /api/v1/almanac/eclipses`

**Solar eclipses — DEFERRED.** Skyfield 1.54 has no built-in `solar_eclipses()`. Geographic path tracking requires external data (NASA eclipse catalog or dedicated API). Pinned for future consideration.

### Step 19: API — Meteor showers (static data + radiant visibility)

**New file:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\data\meteor_showers.py`

Static table of 12 major meteor showers:
- Quadrantids (Jan 3-4), Lyrids (Apr 22-23), Eta Aquariids (May 5-6), Delta Aquariids (Jul 28-29), Perseids (Aug 12-13), Draconids (Oct 8-9), Orionids (Oct 21-22), Taurids (Nov 4-5), Leonids (Nov 17-18), Geminids (Dec 13-14), Ursids (Dec 22-23)
- Each entry: name, peak date range, radiant RA/Dec, typical ZHR (zenithal hourly rate), parent body
- Skyfield computes radiant altitude at peak night from station lat/lon → "visible from your location" flag
- Moon phase at peak (from existing moon service) → viewing conditions rating

**New endpoint:** `GET /api/v1/almanac/meteor-showers` — upcoming showers for the year

### Step 20: Dashboard — Expanded almanac page

**File:** `C:\CODE\weewx-clearskies-dashboard\src\routes\almanac.tsx`

Add new cards below existing sun/moon:

1. **Planets Visible Tonight** — card with planet icons, rise/set times, magnitude. Simple table or icon grid.
2. **Special Moon** — badge/label on existing moon card showing traditional name, harvest/blue/supermoon indicator
3. **Upcoming Eclipses** — small card listing next lunar eclipse date + type
4. **Meteor Showers** — card listing upcoming showers with peak date, ZHR, viewing conditions (moon interference)

### Step 21: Update ADR-045 cache policies

Add to the caching policy table:

| Endpoint | Refresh interval | Rationale |
|---|---|---|
| `/climatology/monthly` | 6 hours | Climatological averages barely change. Full archive scan. |
| `/almanac/planets` | 6 hours | Planet positions change slowly. CPU-bound Skyfield calc. |
| `/almanac/eclipses` | 24 hours | Eclipse dates are fixed for the year. |
| `/almanac/meteor-showers` | 24 hours | Static data + radiant visibility changes slowly. |

---

## Item 5: Seismic Page Overhaul

### Current state
The page already has a Leaflet map + paginated list, but the layout is vertical (map then long scrollable list), the config card is hardcoded, there's no list-to-map interaction, no fault line overlay, and the wizard doesn't capture radius/magnitude/time settings.

### Step 22a: ADR-024 amendment — page taxonomy updates

**File:** `c:\CODE\weather-belchertown\docs\decisions\ADR-024-page-taxonomy.md`

Amend three items (status stays Accepted, add amendment date):
- **Earthquakes → Seismic:** Rename page, two-card layout (map + scrollable list), wizard-configurable radius/magnitude/time
- **Almanac — add climatological chart:** "Average Climatological Values by Month" chart (avg high/low temp, dewpoint, rainfall by calendar month across all years). New endpoint `GET /api/v1/climatology/monthly`.
- **Almanac — astronomy features now (not Phase 6+):** Planets visible by viewing period, special moon names, lunar eclipses, meteor showers. Skyfield handles all natively per ADR-014.

### Step 22b: ADR-046 (new) — GEM Active Faults data source

**New file:** `c:\CODE\weather-belchertown\docs\decisions\ADR-046-gem-active-faults.md`

**Context:** The seismic page needs a fault line overlay. Plate boundary datasets (Peter Bird) only show tectonic plate edges, missing significant intraplate faults (Newport-Inglewood, New Madrid, Hayward, Wasatch, etc.).

**Decision:** Use the GEM Global Active Faults Database (GAF-DB) from the Global Earthquake Model foundation.

**Key points:**
- **Why GEM over USGS Quaternary Faults:** GEM is global; USGS QFaults is US-only
- **Why GEM over plate boundaries:** Plate boundaries miss intraplate faults that produce real earthquakes
- **Licensing:** CC-BY-SA 4.0 — compatible with GPL v3, requires attribution in the UI (e.g., "Fault data: GEM Global Active Faults Database")
- **Bundling:** GeoJSON file shipped with the API package (not fetched at runtime). ~10MB uncompressed.
- **Serving:** API clips to station radius and serves only nearby faults. Dashboard receives a small GeoJSON subset.
- **Update cadence:** GEM updates ~annually. Rebundle with API releases.

### Step 22c: Rename "Earthquakes" to "Seismic"

**Dashboard files:**
- `src/routes/earthquakes.tsx` → rename to `src/routes/seismic.tsx`
- Router config — update route path from `/earthquakes` to `/seismic`
- Nav component — update menu label from "Earthquakes" to "Seismic"
- i18n locale files — update `earthquakes.title` key to `seismic.title` across all 13 locales
- API endpoint path stays `/api/v1/earthquakes` (no breaking API change — only the dashboard route and display name change)

### Step 23: API — Add configurable defaults for min magnitude + time window

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\config\settings.py`

Extend `EarthquakesSettings`:
- `min_magnitude: float = 2.0` — default minimum magnitude (was unconfigured, effectively 0)
- `default_days: int = 7` — default time window ("past week"); used when no `from`/`to` query params
- `default_radius_km` already exists (100 km)

**File:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\endpoints\earthquakes.py`

- Apply `min_magnitude` from config as the default when `?min_magnitude` query param is absent
- Apply `default_days` to set `starttime` when no `from` param is provided
- Pass `minmagnitude` to the USGS API call (not just post-cache filtering) to reduce payload size

**File:** Add `[earthquakes]` section to `config/api.conf.example` documenting all three settings.

### Step 24: API — Seismic config endpoint

**New endpoint:** `GET /api/v1/earthquakes/config`

Returns the operator's configured settings so the dashboard can display them:
```json
{
  "data": {
    "provider": "usgs",
    "radiusKm": 100,
    "minMagnitude": 2.0,
    "defaultDays": 7
  }
}
```

Dashboard reads this to populate the config summary card (replacing hardcoded values).

### Step 25: Wizard — Seismic configuration fields

**Stack repo files:**
- `wizard/state.py` — add `earthquake_radius_km: float = 100`, `earthquake_min_magnitude: float = 2.0`, `earthquake_default_days: int = 7`
- `wizard/routes.py` — extend provider step (step 6) to show earthquake-specific config fields when earthquake provider is selected: radius (km), minimum magnitude, time period dropdown (past 24h / past week / past 2 weeks / past 30 days)
- `templates/wizard/step_providers.html` — add earthquake config inputs (inline with provider selection, not a separate step)
- `wizard/config_writer.py` — include earthquake settings in the `[earthquakes]` section of the apply payload

### Step 26: Dashboard — Two-card layout with map-list interaction

**File:** `C:\CODE\weewx-clearskies-dashboard\src\routes\seismic.tsx`

Redesign the page layout:

**Desktop:** Two cards side by side (CSS grid `grid-cols-2`)
- **Left card: Map** — Leaflet map (already exists, restructure into a card). Full height of viewport minus header.
- **Right card: Scrollable list** — earthquake list in a scrollable container with fixed max-height. Remove "Show More" pagination — show all events in the scroll area.

**Mobile:** Stack vertically — map card on top (fixed height ~300px), scrollable list below.

**Map-list interaction:**
- Click an earthquake in the list → map pans/zooms to that event, opens its popup, highlights the circle marker (increase size or add pulsing animation)
- Click a circle marker on the map → scroll the list to that event, highlight it
- Selected state tracked via React state (`selectedEarthquakeId`)

**Config summary:** Read from new `GET /earthquakes/config` endpoint instead of hardcoded values. Show radius, min magnitude, time period, provider.

### Step 27: API + Dashboard — Active fault line overlay

Plate boundary data only shows where tectonic plates meet (San Andreas yes, Newport-Inglewood no). Active fault databases include all mapped faults — plate boundaries AND intraplate faults like Newport-Inglewood, Hayward, New Madrid, Wasatch, etc.

**Data source:** GEM Global Active Faults Database (GAF-DB) from the Global Earthquake Model foundation. Comprehensive global coverage of mapped active faults. Open data, available as GeoJSON.

**API side — radius-clipped fault serving:**

**New file:** `C:\CODE\weewx-clearskies-api\weewx_clearskies_api\data\gem-active-faults.geojson` (bundled with the API)
**New endpoint:** `GET /api/v1/earthquakes/faults`

- Loads the full GEM GeoJSON at startup (one-time, cached in memory)
- Returns only fault features within `default_radius_km` of the station lat/lon (same radius as earthquake search)
- Clipping: for each fault LineString, include it if any vertex is within the radius. Simple haversine distance check.
- Response is standard GeoJSON FeatureCollection — Leaflet renders it natively
- Add to cache warmer (6-hour refresh — faults don't move)

This way the dashboard only receives faults relevant to the station area (a few KB) instead of the full global dataset (~10MB+).

**Dashboard side:**

**File:** `C:\CODE\weewx-clearskies-dashboard\src\routes\seismic.tsx`

- New API hook: `useFaultLines()` → `GET /api/v1/earthquakes/faults`
- Render as Leaflet `GeoJSON` layer: thin lines (1-2px), semi-transparent, distinct color from earthquake markers (e.g., muted orange or brown)
- Toggle: layer control checkbox "Show fault lines" — on by default since the data is small (pre-clipped to station area)
- Fault line popups: show fault name + slip type (from GEM metadata) on click

### Step 28: Cache warmer — Add seismic config endpoint

Add `/earthquakes/config` to the fast-endpoint list (no caching needed — it reads config, not DB).

The earthquake data itself is already cached by the provider module (60s TTL per ADR-017). No change needed for the data endpoint.

---

## Granular Task Breakdown

### File conflict analysis

**API `config/settings.py`** is the bottleneck — touched by cache warmer (CacheWarmerSettings), branding (BrandingSettings + SocialSettings), and seismic (EarthquakesSettings). These three must run **sequentially** in the API repo to avoid merge conflicts.

**API `services/almanac.py`** — touched by planets, moon names, eclipses, and meteors. All must be one agent.

**Dashboard `src/routes/almanac.tsx`** — touched by climatological chart AND expanded astronomy cards. Must be one agent.

**Stack `wizard/state.py` + `wizard/routes.py`** — touched by branding/social AND seismic config. Must be one agent.

Everything else is in new files or separate page files — safe to parallelize.

---

### Detailed task specifications

---

#### T1: ADRs (meta repo) — Batch 1, parallel
**Agent:** general (sonnet) | **Depends:** none | **Est:** 10 min

**Deliverables — 3 files:**

**ADR-045-background-cache-warming.md** (new):
- Status: Proposed
- Context: Records endpoint takes 11s (all-time), almanac sun-times/moon-phases are CPU-bound. Belchertown pre-computed via report engine. Clear Skies needs equivalent.
- Decision: Background daemon thread pre-computes slow endpoints on configurable intervals. Reuses ADR-017 CacheBackend protocol. First refresh at startup. Cache miss = live query (graceful degradation).
- Include the full caching policy table (copy from Step 1 + Step 21 in this plan)
- Cross-references: ADR-017 (provider caching, different tier), ADR-012 (DB access)
- Config: `[cache_warmer]` section in `api.conf`

**ADR-046-gem-active-faults.md** (new):
- Status: Proposed
- Context: Seismic page needs fault overlay. Plate boundaries miss intraplate faults (Newport-Inglewood, New Madrid, etc.)
- Decision: Use GEM GAF-DB. CC-BY-SA 4.0 (attribution required). Bundled with API, served radius-clipped. Global coverage.
- Options considered: Peter Bird plate boundaries (too general), USGS QFaults (US-only), GEM GAF-DB (global, comprehensive)

**ADR-024 amendment:**
- Add amendment date section at bottom
- Earthquakes → Seismic (menu name + route, API path unchanged)
- Almanac: add climatological chart, move astronomy features from "Phase 6+" to current phase
- Keep status Accepted

**Done when:** All 3 files committed, INDEX.md updated with ADR-045 and ADR-046 entries.

---

#### T2: Dashboard records default to YTD — Batch 1, parallel
**Agent:** dashboard-dev (sonnet) | **Depends:** none | **Est:** 2 min

**Exact change:** In `C:\CODE\weewx-clearskies-dashboard\src\routes\records.tsx`, find the state initialization for the period (around line 88). Change the default from `'all-time'` to `'ytd'`.

**Done when:** `npm run build` passes. Committed.

---

#### T3: API climatology service + endpoint — Batch 1, parallel
**Agent:** api-dev (sonnet) | **Depends:** none | **Est:** 15 min

**New files to create:**

`services/climatology.py`:
- Function: `get_monthly_climatology(db: Session, registry: ColumnRegistry) -> ClimatologyBundle`
- Returns 12-element arrays for: avgHighTemp, avgLowTemp, avgDewpoint, avgRainfall
- SQL for temps: subquery groups by day bucket → takes MAX(outTemp) and MIN(outTemp) per day → outer query groups by month number (1-12) → AVG across all years
- SQL for dewpoint: straight AVG(dewpoint) grouped by month number
- SQL for rainfall: subquery groups by year-month → SUM(rain) per month → outer query groups by month number → AVG across years
- Reuse `_day_bucket_sql()` and `_month_bucket_sql()` from records.py (import them or duplicate the helpers)
- Handle SQLite vs MySQL dialect (same pattern as records.py)
- Self-hide: if outTemp not in registry, omit temp series. If dewpoint not in registry, omit. If rain not in registry, omit.
- Return month labels as ["Jan", "Feb", ..., "Dec"]

`endpoints/climatology.py`:
- `GET /api/v1/climatology/monthly` — calls `get_monthly_climatology()`, returns `ClimatologyResponse`
- Response model: `ClimatologyResponse(data=ClimatologyBundle, source="weewx", generatedAt=<utc>)`
- Mount router in `app.py`: `app.include_router(climatology_router, prefix="/api/v1")`

**Done when:** Endpoint returns valid JSON with 12-element arrays. `python -m pytest tests/ -q` shows no new failures. Committed.

---

#### T4: API almanac astronomy extensions — Batch 1, parallel
**Agent:** api-dev (sonnet) | **Depends:** none | **Est:** 20 min

**File: `services/almanac.py` — 4 additions:**

**1. Planet visibility** (~100 lines):
- New function `_compute_planets_for_date(t, location, eph, sun_rise, sun_set)`:
  - Loop: Mercury, Venus, Mars, Jupiter, Saturn (5 planets)
  - For each: `almanac_find_risings(eph, planet, location, t0, t1)` for rise/set times (same pattern as moon rise/set)
  - Apparent magnitude: `from skyfield.magnitudelib import planetary_magnitude; planetary_magnitude(apparent)`
  - Classification: compare planet set time vs sunset+midnight → "evening" / compare planet rise vs midnight+sunrise → "morning" / else "allNight"
  - Filter: magnitude < 6.0 only
- New endpoint in `endpoints/almanac.py`: `GET /api/v1/almanac/planets` → returns `{evening: [...], morning: [...], allNight: [...], notVisible: [...]}`

**2. Special moon names** (~40 lines):
- Lookup table: `_TRADITIONAL_MOON_NAMES = {1: "Wolf", 2: "Snow", 3: "Worm", 4: "Pink", 5: "Flower", 6: "Strawberry", 7: "Buck", 8: "Sturgeon", 9: "Corn", 10: "Hunter", 11: "Beaver", 12: "Cold"}`
- Harvest moon: find full moon nearest to autumnal equinox from `almanac.seasons()`
- Blue moon: Counter on full moon months, flag 2nd occurrence
- Hunter's moon: next full moon after harvest moon
- Supermoon: `observe(moon).distance().au` at each full moon, flag if within 90% of closest approach
- Add `traditionalName`, `isHarvestMoon`, `isBlueMoon`, `isHuntersMoon`, `isSupermoon` fields to moon-phase response entries

**3. Lunar eclipses** (~20 lines):
- `from skyfield.eclipselib import lunar_eclipses`
- `lunar_eclipses(t0, t1, eph)` → returns times + types
- New endpoint: `GET /api/v1/almanac/eclipses` → list of `{date, type: "penumbral"|"partial"|"total"}`
- Or add `upcomingEclipses` to existing `/almanac` response

**4. Meteor showers:**
- New file `data/meteor_showers.py` — static table of 12 showers: name, peak month/day, duration days, radiant RA (degrees), radiant Dec (degrees), ZHR, parent body
- New function `_compute_meteor_showers(year, location, eph)`: for each shower, compute radiant altitude at peak night from station lat/lon, moon illumination at peak (viewing conditions)
- New endpoint: `GET /api/v1/almanac/meteor-showers` → list of `{name, peakDate, zhr, radiantAltitude, moonIllumination, viewingConditions: "excellent"|"good"|"fair"|"poor"}`
- Viewing: excellent = radiant high + moon < 25%, good = radiant high + moon < 50%, fair = radiant moderate or moon bright, poor = radiant below horizon

**Done when:** All 4 new endpoints return valid JSON. Existing almanac tests still pass. New tests cover planet classification, moon names, eclipse listing. Committed.

---

#### T5: API cache warmer — Batch 2, sequential
**Agent:** api-dev (sonnet) | **Depends:** T3, T4 committed | **Est:** 20 min

**New file: `services/cache_warmer.py`:**

```python
class BackgroundCacheWarmer:
    def __init__(self, engine, registry, cache, settings, station_lat, station_lon): ...
    def start(self): ...  # launches daemon thread
    def _loop(self): ...  # sleeps, calls warm functions on schedule
    def _warm_records(self): ...  # get_records for all-time + ytd, serialize to cache
    def _warm_almanac(self): ...  # sun-times + moon-phases for current year
    def _warm_aqi_history(self): ...  # AQI history, skip if no AQI columns
```

- Daemon thread (`threading.Thread(daemon=True)`)
- Own DB session per cycle: `with Session(engine) as db:`
- Cache keys: `warmer:records:all-time`, `warmer:records:ytd`, `warmer:almanac:sun-times:2026`, etc.
- Each warm function: try/except, log WARNING on failure, continue
- First run: synchronous in `main()` before server starts (warm cache before first request)

**Modify `config/settings.py`:** Add `CacheWarmerSettings` class:
```python
class CacheWarmerSettings:
    enabled: bool = True
    records_interval_seconds: int = 1800  # 30 min
    almanac_interval_seconds: int = 21600  # 6 hours
    aqi_history_interval_seconds: int = 1800  # 30 min
```
Read from `[cache_warmer]` section of api.conf.

**Modify `__main__.py`:** After step 6h (cache wired), instantiate `BackgroundCacheWarmer` and call `start()`.

**Modify endpoint handlers — add cache-check-first guard:**

`endpoints/records.py`:
```python
cache_key = f"warmer:records:{params.period}"
if params.section is None:  # only use cache for unfiltered requests
    cached = get_cache().get(cache_key)
    if cached is not None:
        return RecordsResponse.model_validate(cached)
```

Same pattern for `endpoints/almanac.py` (sun-times, moon-phases) and `endpoints/aqi.py` (history).

**Modify `config/api.conf.example`:** Add documented `[cache_warmer]` section.

**Done when:** API starts, logs show "Cache warmer: initial warm complete" before "Uvicorn running". Second request to `/records?period=all-time` returns in <100ms. All existing tests pass. Committed.

---

#### T6: API branding + social — Batch 2, sequential
**Agent:** api-dev (sonnet) | **Depends:** T5 committed | **Est:** 15 min

**Modify `config/settings.py`:**
- Extend `BrandingSettings`: add `site_title: str = ""`, `logo_light_url: str = ""`, `logo_dark_url: str = ""`, `favicon_url: str = ""`
- New `SocialSettings` class: `facebook_url: str = ""`, `twitter_url: str = ""`, `instagram_url: str = ""`, `youtube_url: str = ""`
- Read `[social]` section from api.conf

**Modify `endpoints/branding.py`:**
- Extend `BrandingConfig` response model: add `siteTitle`, `logo: {light, dark}` (use actual URLs, not null), `faviconUrl`, `social: {facebook, twitter, instagram, youtube}`
- `get_branding()` reads from both `BrandingSettings` and `SocialSettings`

**Modify `endpoints/setup.py`:**
- Add `BrandingApplyConfig` and `SocialApplyConfig` to the apply request
- `_write_api_conf()` writes `site_title`, `logo_light_url`, `logo_dark_url`, `favicon_url` to `[branding]` and social URLs to `[social]`

**Done when:** `GET /api/v1/branding` returns full response with siteTitle, logo, favicon, social. `/setup/apply` writes branding+social to api.conf. Tests pass. Committed.

---

#### T7: API seismic settings + config + faults — Batch 2, sequential
**Agent:** api-dev (sonnet) | **Depends:** T6 committed | **Est:** 15 min

**Modify `config/settings.py`:**
- Extend `EarthquakesSettings`: add `min_magnitude: float = 2.0`, `default_days: int = 7`

**Modify `endpoints/earthquakes.py`:**
- Apply `min_magnitude` from config as default when query param absent
- Apply `default_days` to compute `starttime` when no `from` param
- Pass `minmagnitude` to USGS API call (not just post-cache)
- New endpoint: `GET /api/v1/earthquakes/config` → returns `{provider, radiusKm, minMagnitude, defaultDays}`

**New file `services/faults.py`:**
- Load GEM GeoJSON at module level (one-time)
- Function: `get_faults_within_radius(lat, lon, radius_km) -> GeoJSON FeatureCollection`
- Haversine distance check: include fault LineString if any vertex within radius
- Return standard GeoJSON that Leaflet can render directly

**New file `data/gem-active-faults.geojson`:**
- Download from GEM GAF-DB repository
- If file too large (>15MB), agent should simplify geometry or report to lead

**New endpoint: `GET /api/v1/earthquakes/faults`** — calls `get_faults_within_radius` with station lat/lon and configured radius

**Modify `config/api.conf.example`:** Add `[earthquakes]` section documenting `provider`, `default_radius_km`, `min_magnitude`, `default_days`.

**Done when:** `/earthquakes/config` returns settings. `/earthquakes/faults` returns GeoJSON with fault features near station. `/earthquakes` respects min_magnitude and default_days from config. Tests pass. Committed.

---

#### T8: Stack wizard — branding + social + seismic config — Batch 3
**Agent:** general (sonnet) | **Depends:** T6, T7 committed | **Est:** 25 min

**Modify `wizard/state.py`:** Add fields:
- `site_title: str = ""`
- `logo_light_path: str = ""`
- `logo_dark_path: str = ""`
- `favicon_path: str = ""`
- `facebook_url: str = ""`
- `twitter_url: str = ""`
- `instagram_url: str = ""`
- `youtube_url: str = ""`
- `earthquake_radius_km: float = 100.0`
- `earthquake_min_magnitude: float = 2.0`
- `earthquake_default_days: int = 7`

**Modify `wizard/routes.py`:**
- New handlers: `step_branding_get/post`, `step_social_get/post`
- Branding GET: pre-fill from `state.imported_config["extras"]["branding"]` + `state.imported_images`. Show file type/size guidance (PNG/SVG ≤500KB for logos, ICO/PNG ≤100KB for favicon).
- Social GET: pre-fill from `state.imported_config["extras"]["social"]`. 4 URL inputs (Facebook, Twitter/X, Instagram, YouTube). Blank = not shown on site.
- Extend provider step (step 6): when earthquake provider selected, show inline config fields — radius (km, number input), min magnitude (number input, step 0.1), time period (dropdown: 1 day / 7 days / 14 days / 30 days)
- Wire flow: webcam POST → branding → social → review. Update step numbering.

**New templates:**
- `step_branding.html`: site title text input, logo light/dark file uploads (with type/size labels), favicon upload. Pre-fill values. Match existing template style (Pico CSS, HTMX).
- `step_social.html`: 4 URL text inputs with platform labels + inline SVG icons. Pre-fill values. Note: "Leave blank to hide from your site."

**Modify existing templates:**
- `_progress_bar.html`: add Branding + Social step labels, update total step count
- `step_review.html`: add branding summary (site title, logo status, favicon status) + social summary (which platforms configured) + seismic config summary (radius, magnitude, days)

**Modify `wizard/config_writer.py`:**
- `build_skin_conf_payload()`: include edited branding values (site_title, logo paths, favicon) and social URLs in the skin_conf extras
- Include earthquake settings (radius, min_magnitude, default_days) in the `[earthquakes]` section of the apply payload

**Modify `wizard/state_persistence.py`:**
- `_merge_from_existing_config()`: restore branding, social, and earthquake fields from existing config on wizard re-run

**Done when:** Wizard flow walks through all steps including branding → social → review. Review shows branding/social/seismic summaries. `python -m pytest tests/ -q` passes. Committed.

---

#### T9: Dashboard branding + social footer — Batch 3
**Agent:** dashboard-dev (sonnet) | **Depends:** T6 committed | **Est:** 15 min

**Modify `src/api/client.ts`:** Update `ApiBrandingConfig` type to include `siteTitle`, `logo: {light, dark}`, `faviconUrl`, `social: {facebook, twitter, instagram, youtube}`.

**Modify `src/lib/branding.ts`:** Update `BrandingConfig` internal type to match new API fields.

**Modify `src/lib/branding-provider.tsx`:**
- Map new API fields to internal type
- Set `document.title` from `siteTitle` when non-empty
- Set favicon `<link>` from `faviconUrl` when non-empty

**Modify footer component** (find via grep for "footer"):
- Add social icons row: inline SVG paths from Simple Icons for Facebook, Twitter/X, Instagram, YouTube
- Each icon: 20x20px, `fill="currentColor"`, `className` for muted color + hover accent
- Flex row with `gap-4`. Only render platforms where URL is non-empty.
- Each icon wraps an `<a href={url} target="_blank" rel="noopener noreferrer">`
- Add GEM attribution line: "Fault data © GEM Foundation (CC BY-SA 4.0)" — small muted text

**Done when:** `npm run build` passes. Footer renders social icons when branding API provides URLs. No icons shown when URLs empty. Committed.

---

#### T10: Dashboard almanac overhaul — Batch 3
**Agent:** dashboard-dev (sonnet) | **Depends:** T3, T4 committed | **Est:** 20 min

**Modify `src/routes/almanac.tsx`** — add 5 new cards below existing sun/moon:

**1. Climatological chart card:**
- New hook: `useClimatology()` → `GET /api/v1/climatology/monthly`
- Recharts `ComposedChart`: Line series (avgHighTemp red, avgLowTemp blue, avgDewpoint purple) + Bar series (avgRainfall light blue)
- Dual Y-axes: left for temperature, right for rainfall
- X-axis: 12 month labels
- Responsive: full width, ~300px height
- Skeleton loader while fetching

**2. Planets Visible card:**
- New hook: `usePlanets()` → `GET /api/v1/almanac/planets`
- Three sections: Evening, Morning, All Night
- Each planet row: name, rise/set times, magnitude badge
- If no planets visible: "No planets visible tonight"

**3. Moon name badge on existing moon card:**
- Read `traditionalName`, `isHarvestMoon`, `isBlueMoon`, `isSupermoon` from almanac response
- Show as badges/tags on the moon card (e.g., "Flower Moon", "Supermoon" badge)

**4. Upcoming eclipses card:**
- New hook: `useEclipses()` → `GET /api/v1/almanac/eclipses`
- Simple list: date + type (penumbral/partial/total)
- If none upcoming: "No lunar eclipses in the next year"

**5. Meteor showers card:**
- New hook: `useMeteorShowers()` → `GET /api/v1/almanac/meteor-showers`
- Table: shower name, peak date, ZHR, viewing conditions (color-coded badge)
- Highlight upcoming showers (within 30 days) vs past

**Done when:** `npm run build` passes. Almanac page shows all 5 new sections with skeleton loaders. Committed.

---

#### T11: Dashboard seismic overhaul — Batch 3
**Agent:** dashboard-dev (sonnet) | **Depends:** T7 committed | **Est:** 25 min

**Rename:** `src/routes/earthquakes.tsx` → `src/routes/seismic.tsx`. Update all imports.

**Router config:** Change route path from `/earthquakes` to `/seismic`.

**Nav component:** Change menu label from "Earthquakes" to "Seismic".

**i18n:** In all 13 locale dirs (`public/locales/{en,de,es,fil,fr,it,ja,nl,pt-PT,pt-BR,ru,zh-CN,zh-TW}/`), rename the earthquakes namespace key to seismic (or add seismic keys).

**Redesign `seismic.tsx` layout:**

Desktop (>= lg breakpoint): CSS grid `grid-cols-2 gap-4`
- Left: Map card (Leaflet, full height of viewport - header - padding)
- Right: Scrollable list card (`max-h-[calc(100vh-12rem)] overflow-y-auto`)

Mobile (< lg): Stack vertically
- Map: fixed height 300px
- List: below, scrollable

**Map-list interaction:**
- React state: `const [selectedId, setSelectedId] = useState<string | null>(null)`
- Click list item → `setSelectedId(eq.id)` → map `flyTo([eq.lat, eq.lon], 10)` → open popup for that marker
- Click map marker → `setSelectedId(eq.id)` → scroll list to that item (`ref.scrollIntoView({behavior: 'smooth'})`)
- Selected list item gets highlight class (ring or background)
- Selected map marker: larger radius or pulsing CSS animation

**Config card:** Replace hardcoded "100 km" / "USGS" with data from `GET /api/v1/earthquakes/config`. New hook: `useSeismicConfig()`.

**Fault line overlay:**
- New hook: `useFaultLines()` → `GET /api/v1/earthquakes/faults`
- Render as Leaflet `GeoJSON` component: `style={{ color: '#b45309', weight: 1.5, opacity: 0.6 }}`
- Layer control toggle: "Show fault lines" (on by default)
- Popup on fault click: fault name + slip type from GeoJSON properties

**Remove** "Show More" pagination — all events in scroll container.

**Done when:** `npm run build` passes. Route is `/seismic`. Map and list side-by-side on desktop, stacked on mobile. Click interaction works both directions. Fault lines render. Config card reads from API. Committed.

---

#### T12: API cache warmer additions — Batch 4
**Agent:** api-dev (sonnet) | **Depends:** T3, T4, T5, T7 | **Est:** 10 min

**Modify `services/cache_warmer.py`:** Add warm functions for:
- `_warm_climatology()` — calls climatology service, cache key `warmer:climatology:monthly`, interval 6 hours
- `_warm_planets()` — calls planets endpoint logic, cache key `warmer:almanac:planets:{date}`, interval 6 hours
- `_warm_eclipses()` — calls eclipse logic, cache key `warmer:almanac:eclipses:{year}`, interval 24 hours
- `_warm_meteor_showers()` — calls meteor shower logic, cache key `warmer:almanac:meteor-showers:{year}`, interval 24 hours
- `_warm_faults()` — calls fault service, cache key `warmer:earthquakes:faults`, interval 6 hours

**Add cache-check-first guards** to the new endpoints: climatology, planets, eclipses, meteor-showers, faults.

**Done when:** All new endpoints serve from cache on second request. Warmer logs show all warm functions running. Tests pass. Committed.

---

#### T13: OpenAPI contract update — Batch 4
**Agent:** general (sonnet) | **Depends:** All API tasks | **Est:** 10 min

**Modify `docs/contracts/openapi-v1.yaml`:**
- Add `GET /api/v1/climatology/monthly` schema
- Add `GET /api/v1/almanac/planets` schema
- Add `GET /api/v1/almanac/eclipses` schema
- Add `GET /api/v1/almanac/meteor-showers` schema
- Add `GET /api/v1/earthquakes/config` schema
- Add `GET /api/v1/earthquakes/faults` schema (GeoJSON response)
- Update `GET /api/v1/branding` schema with new fields
- Update `GET /api/v1/earthquakes` schema with new query params
- Update almanac moon-phases schema with special moon name fields

**Done when:** Contract reflects all new/modified endpoints. Committed.

---

#### T14: Independent test verification — Batch 5
**Agent:** general (sonnet) | **Depends:** All code tasks | **Est:** 10 min

Run from fresh shell (lead verifies, not agents):
- API: `cd C:\CODE\weewx-clearskies-api && python -m pytest tests/ -q --tb=line --ignore=tests/integration`
- Stack: `cd C:\CODE\weewx-clearskies-stack && python -m pytest tests/ -q --tb=line`
- Dashboard: `cd C:\CODE\weewx-clearskies-dashboard && npm run build`

**Pass criteria:** Zero new failures in API/stack. Dashboard builds with zero TS errors.

---

#### T15: Deploy all repos — Batch 5
**Agent:** general (sonnet) | **Depends:** T14 passes | **Est:** 5 min

- API: `ssh ratbert "lxc exec weewx -- bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull && source .venv/bin/activate && pip install -e . && sudo systemctl restart weewx-clearskies-api'"`
- Realtime: `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-realtime && git pull && sudo systemctl restart weewx-clearskies-realtime"`
- Stack: `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-stack && git pull && sudo systemctl restart weewx-clearskies-config"`
- Dashboard: `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && git pull && VITE_SSE_URL=/sse npm run build && sudo rm -rf /var/www/clearskies/assets && sudo cp -r dist/. /var/www/clearskies/"`

**Done when:** All 4 services healthy. API logs show cache warmer running.

---

#### T16: Live verification — Batch 5
**Agent:** general (sonnet) | **Depends:** T15 | **Est:** 10 min

Hit each endpoint through the BFF and verify:
1. `/api/v1/records?period=all-time` returns in <200ms (cached)
2. `/api/v1/climatology/monthly` returns 12-element arrays
3. `/api/v1/almanac/planets` returns evening/morning/allNight groupings
4. `/api/v1/almanac/eclipses` returns upcoming eclipses
5. `/api/v1/almanac/meteor-showers` returns shower list with viewing conditions
6. `/api/v1/branding` returns siteTitle, logo, social fields
7. `/api/v1/earthquakes/config` returns radius, minMagnitude, defaultDays
8. `/api/v1/earthquakes/faults` returns GeoJSON with fault features
9. `/api/v1/earthquakes` respects min_magnitude filter
10. Dashboard loads — check records (fast), almanac (all cards), seismic (two-card layout + faults), footer (social icons if configured)

---

### Execution timeline

```
Time ──────────────────────────────────────────────────────────────────►

Batch 1 (parallel):
  T1 [ADRs] ██████████
  T2 [records YTD] ██
  T3 [climatology API] ███████████████
  T4 [almanac astronomy API] ████████████████████

                        ↓ T3+T4 done
Batch 2 (sequential, settings.py chain):      ↓ T10 starts early
  T5 [cache warmer] ████████████████████
                     T6 [branding API] ███████████████
                                        T7 [seismic API] ███████████████

                                         ↓ T6 done        ↓ T7 done
Batch 3 (parallel):
  T10 [dashboard almanac] ████████████████████   (starts after T3+T4)
  T9  [dashboard branding] ███████████████       (starts after T6)
  T11 [dashboard seismic] █████████████████████████  (starts after T7)
  T8  [stack wizard] █████████████████████████       (starts after T7)

Batch 4 (after all API + dashboard):
  T12 [warmer additions] ██████████
  T13 [OpenAPI update] ██████████

Batch 5:
  T14 [test verify] ██████████
  T15 [deploy] █████
  T16 [live verify] ██████████
```

### Agent management rules for execution

1. **Lead spawns Batch 1 (T1-T4) in one parallel launch.** T1 meta + T2 dashboard are background. T3 and T4 are background (API, different files, safe to parallel).

2. **T10 (dashboard almanac) starts as soon as T3+T4 commit** — doesn't need to wait for Batch 2. Lead monitors T3/T4 git logs and spawns T10 immediately.

3. **Batch 2 is strictly sequential.** Lead spawns T5 after T3+T4 commit. Waits for T5 commit → spawns T6. Waits for T6 commit → spawns T7. Each must fully commit before the next starts (settings.py merge conflicts).

4. **T9 (dashboard branding) spawns as soon as T6 commits.** Doesn't wait for T7.

5. **T8 (stack wizard) and T11 (dashboard seismic) spawn as soon as T7 commits.** T8 is the biggest Batch 3 task — start it immediately.

6. **Independent lead-pytest-verify (T14):** Before accepting any agent's test claim, re-run from fresh shell. API: `python -m pytest tests/ -q --tb=line`. Stack: `python -m pytest tests/ -q`. Dashboard: `npm run build`.

7. **GEM fault data (T7):** Agent must download the GEM GAF-DB GeoJSON and bundle it. If download fails or file is too large, the agent should report and the lead decides whether to defer faults or use a smaller subset.

8. **Commit convention:** Each agent writes its commit message to `c:\tmp\<task-id>-msg.txt`, then `git commit -s -F c:\tmp\<task-id>-msg.txt`.

9. **Monitor cadence:** Check git log every 3-4 min for background agents. SendMessage after 4 min of silence. TaskStop after 3 silent pings.

---

### Total estimates

- **16 tasks**, **~200 min of agent compute** (wall time much less due to parallelism)
- **Critical path:** T4 (20 min) → T5 (20 min) → T6 (15 min) → T7 (15 min) → T8/T11 (25 min) → T12 (10 min) → T14 (10 min) = **~115 min wall clock** for the longest dependency chain
- **3 repos touched:** api (9 tasks), dashboard (4 tasks), stack (1 task), meta (2 tasks)

---

## Verification

1. **Cache warming:** Hit `/api/v1/records?period=all-time` — should return in <100ms (cache hit). Check API logs for "cache warmer" entries.
2. **Records UX:** Records page defaults to YTD (fast). Switching to all-time also fast (cached).
3. **Climatological chart:** Almanac page shows 12-month bar/line chart with avg temps + rainfall.
4. **Planets:** Almanac page shows planet visibility by period (evening/morning/all night) with rise/set + magnitude.
5. **Moon names:** Moon card shows traditional name (e.g., "Flower Moon"), harvest/blue/supermoon badges.
6. **Eclipses:** Upcoming lunar eclipses listed with date + type.
7. **Meteor showers:** Upcoming showers with peak date + viewing conditions.
8. **Wizard flow:** Walk through all steps — branding + social screens present, seismic config in provider step, review summarizes all.
9. **Branding API:** `GET /api/v1/branding` returns `siteTitle`, logo URLs, social links.
10. **Footer icons:** Dashboard footer shows social platform icons for configured platforms.
11. **Seismic page:** Route is `/seismic`, menu says "Seismic". Two-card layout: map left, scrollable list right. Click event in list → map highlights it. Config card shows real values from API.
12. **Seismic config:** Wizard provider step shows radius/magnitude/time period fields when earthquakes selected. API `[earthquakes]` section has all three settings.
13. **Fault lines:** Toggle "Show plate boundaries" on seismic map renders tectonic plate boundary lines.
