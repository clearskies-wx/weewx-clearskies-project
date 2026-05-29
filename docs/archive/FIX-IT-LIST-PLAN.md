# Fix-it List Execution Plan (Items 1–22)

**Created:** 2026-05-25  
**Source:** UAT findings from 2026-05-24/25 deployment testing session  
**Status:** Planned, not yet executed  

## Session-Start Context

The Clear Skies dashboard is deployed natively (not Docker) on two hosts:
- **weewx host** (192.168.7.20): API service via systemd (`weewx-clearskies-api.service`), config at `/etc/weewx-clearskies/api.conf`, venv at `/home/ubuntu/repos/weewx-clearskies-api/.venv`
- **weather-dev** (192.168.2.113): Caddy reverse proxy, realtime SSE service, config UI service, dashboard static files at `/var/www/clearskies/`

**Deploy workflow (code changes take effect via):**

| Change | Commands on target host |
|--------|------------------------|
| API code | `cd /home/ubuntu/repos/weewx-clearskies-api && git pull && sudo systemctl restart weewx-clearskies-api` |
| Realtime code | `cd /home/ubuntu/repos/weewx-clearskies-realtime && git pull && sudo systemctl restart weewx-clearskies-realtime` |
| Config UI code | `cd /home/ubuntu/repos/weewx-clearskies-stack && git pull && sudo systemctl restart weewx-clearskies-config` |
| Dashboard code | `cd /home/ubuntu/repos/weewx-clearskies-dashboard && git pull && npm run build && cp -r dist/. /var/www/clearskies/` |

**Agent model:** Lead = Opus (orchestration + judgment only, no code writing). ALL delegated work = Sonnet agents. Each task scoped to ~30 min max. Process rules at `rules/clearskies-process.md`.

**Deferred items:**
- Item 14 (Charts page) — separate session
- Item 21 (Local conditions engine) — research complete in this plan (Phase 6), implementation is a future session

**The fix-it list itself** lives at `docs/planning/CLEAR-SKIES-PLAN.md` under "Fix-it list (cosmetic / non-blocking issues spotted during deployment testing, 2026-05-24)" starting at item 1, and "Dashboard UAT findings (2026-05-25)" starting at item 10.

---

## Pre-Phase: Verification Sprint

**Goal:** Check items 2–8 before writing fix code. Items 3–6 may already be resolved by wizard apply. Items 7–8 have committed code fixes needing verification.

**Agent:** 1 general-purpose Sonnet agent  
**Method:** SSH to weewx (192.168.7.20) and weather-dev (192.168.2.113), run verification commands  

| Item | Check command | Resolved if... |
|------|--------------|-----------------|
| 2 (API unhealthy 22h) | `systemctl status weewx-clearskies-api` | Service running, no restart loops (Docker-specific issue, likely N/A for native) |
| 3 (No providers) | `curl -sk https://localhost:8765/api/v1/capabilities` on weewx | `providers` array is non-empty |
| 4 (PROXY_SECRET) | `grep PROXY_SECRET /etc/weewx-clearskies/secrets.env` on weewx | Variable is set |
| 5 (NOAA reports dir) | `grep reports_directory /etc/weewx-clearskies/api.conf` + `ls` the path on weewx | Config points to existing dir with NOAA files |
| 6 (Content dir) | `ls /etc/weewx-clearskies/content/` on weewx | Dir exists with about.md + legal.md |
| 7 (Wizard restart) | Check `setup.py` restart endpoint implementation in api repo | Code fix is in place |
| 8 (Wizard bind_host) | Check `api.conf` for `[api] bind_host` on weewx | bind_host = 0.0.0.0 present |

**Deliverable:** Status table — which items are resolved, which need work.  
**Acceptance:** Clear pass/fail for each item. Unresolved items get added to Phase 5 (Wizard) or flagged for manual attention.

---

## Phase 1: Significant Figures (Item 10)

**Impact:** Highest — raw float noise (`62.42000000000005°F`) appears on every page. Must fix before any other visual work.

### Task 1.1: Create formatting utility + apply to Now page

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `repos/weewx-clearskies-dashboard/src/routes/now.tsx` — Now page with all inline formatting
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — Observation type (field names)

**Work:**
- Create `src/utils/format.ts` with a `formatValue(value: number | null, type: string): string` utility
- Precision rules (based on standard meteorological display conventions):

| Type | Decimals | Examples |
|------|----------|---------|
| `temperature` | 1 | 62.4°F |
| `barometer` | 2 | 29.92 inHg |
| `wind` | 0 | 12 mph |
| `humidity` | 0 | 45% |
| `rain` | 2 | 0.25 in |
| `rainRate` | 2 | 0.10 in/hr |
| `uv` | 0 | 7 |
| `solar` | 0 | 842 W/m² |
| `earthquakeMag` | 1 | 4.2 |
| `earthquakeDepth` | 1 | 10.3 km |
| `percent` | 0 | 65% |
| `degrees` | 0 | 225° |
| `default` | 1 | fallback |

- Apply to all values in `now.tsx`: Current Conditions, Station Observations dl, Today's Highlights, Wind tile, AQI, Lightning, Earthquake, Forecast summary
- Handle `null` gracefully (return `'--'` or locale-appropriate placeholder)

**Acceptance:** No raw float noise on Now page. `formatValue` is exported and reusable.

### Task 1.2: Apply formatting to all other pages

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/utils/format.ts` (from 1.1)
- `src/routes/forecast.tsx` — temps, wind, precip %
- `src/routes/earthquakes.tsx` — magnitude, depth
- `src/routes/records.tsx` — all record values
- `src/routes/almanac.tsx` — any numeric values
- `src/routes/reports.tsx` — NOAA table values (if rendered from API, not raw text)

**Work:** Import `formatValue` and apply to every displayed numeric value on each page.

**Acceptance:** Zero raw float noise on any page in the app.

### QC Gate 1
Deploy dashboard to weather-dev. Browser-verify every page: Now, Forecast, Earthquakes, Records, Almanac, Reports, About. Every numeric value shows appropriate precision.

---

## Phase 2: Now Page Redesign (Items 20, 22)

**Impact:** The Now page is the landing page. Current layout has redundant hero, monolithic Station Observations blob, buried forecast, and missing data (rain rate, barometer trend with degrees).

### Task 2.1: Remove hero + new Current Conditions card

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/now.tsx` — current Now page layout
- `src/components/hero-section.tsx` — hero component (to be removed)
- `src/api/types.ts` — Observation fields (windchill, heatindex, outTemp)

**Work:**
- Delete `HeroSection` component import and usage from `now.tsx`
- Delete `src/components/hero-section.tsx` file
- Create new `CurrentConditions` card as the first tile:
  - Station name (from useStation)
  - Large temperature display (from observation.outTemp)
  - Feels-like temperature (from observation.appTemp or computed)
  - Weather description (from observation.weatherText, fallback to provider text)
  - Dewpoint + relative humidity
  - Smart comfort index: show wind chill when outTemp < 50°F, heat index when outTemp > 80°F, never both. These are standard NWS thresholds for when each index becomes meaningful.
- Keep aria-live announcements for SSE-updated values

**Acceptance:** Hero gone. Current Conditions is first visible card. Comfort index logic correct (wind chill OR heat index, never both). No redundant temperature display.

### Task 2.2: Wind tile with animated compass

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/now.tsx` — existing Wind card (already has WindCompass SVG)
- Existing `beaufortLabel()` function in now.tsx (lines ~41-55)

**Work:**
- Enhance existing Wind card:
  - Display cardinal direction label ("WSW") AND numeric degrees ("248°")
  - Ensure compass SVG uses `transform: rotate(${windDir}deg)` with CSS `transition: transform 0.5s ease` for smooth animation — NOT snapping to 16-point cardinal
  - Wind speed + gust with `formatValue` from Phase 1
  - Beaufort label (already exists)
- Verify the existing WindCompass component handles continuous rotation

**Acceptance:** Cardinal + degrees both displayed. Compass arrow rotates smoothly on real data updates. No 16-point snapping.

### Task 2.3: Solar/UV tile + Precipitation/Barometer tile

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/now.tsx` — current Station Observations section (inline dl)
- `src/api/types.ts` — radiation, UV, rainRate, rain, barometer, barometerTrend fields

**Work:**
- **Solar/UV tile:** New card component
  - Solar radiation value (W/m²)
  - UV index with EPA-style colored bar: green (0-2), yellow (3-5), orange (6-7), red (8-10), violet (11+)
  - Exposure risk label: "Low" / "Moderate" / "High" / "Very High" / "Extreme"
  - Use i18n keys for labels

- **Precipitation/Barometer tile:** New card component
  - Rain today total (`rain` field from daily archive or today stats)
  - Rain rate (`rainRate` field — currently missing from display!)
  - Barometer with trend arrow (existing `barometerTrendArrow()` function reusable)
  - Barometer trend as descriptive text: "Rising" / "Falling" / "Steady" based on 3-hour delta

**Acceptance:** Both tiles render with real data. Rain rate displays when available. UV bar shows correct color for current value. Barometer trend arrow works.

### Task 2.4: Tile grid layout + Today's Forecast positioning

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/now.tsx` — full page with all tiles

**Work:**
- Reorganize tile grid order (top → bottom):
  1. **Row 1:** Current Conditions (wide) + Today's Forecast (side by side on desktop)
  2. **Row 2:** Wind + Solar/UV
  3. **Row 3:** Precipitation/Barometer + AQI
  4. **Row 4:** Sun & Moon + Lightning
  5. **Row 5:** Recent Earthquake + Temperature Trend
  6. **Row 6:** Radar Map (full width)
- Remove the old "Station Observations" inline `<dl>` block entirely — all its data points are now in purpose-built tiles
- Verify mobile stacking (single column)
- Keep AlertBanner at top (before tiles, after any header)

**Acceptance:** Logical flow top→bottom. Today's Forecast visible above fold on desktop. No leftover Station Observations blob. Mobile responsive.

### Task 2.5: Footer powered logo

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `Graphics/clearskies logo POWERED blue.svg` — existing SVG (8.4 KB, viewBox 0 0 1161.58 379.97, color #2568a3)
- `src/components/layout/footer.tsx` — current footer with `t('footer.poweredBy')` text

**Work:**
- Copy SVG to `src/assets/clearskies-powered-blue.svg`
- Create dark-mode variant: same SVG but with white/light fill (change `#2568a3` to `#93c5fd` or similar light blue for dark backgrounds)
- Replace `t('footer.poweredBy')` text span in footer with `<img>` (or inline SVG React component) that switches between light/dark variants based on theme
- Set appropriate height (~20-24px) to fit footer
- Add `alt="Powered by Clear Skies"` for accessibility

**Acceptance:** Logo renders in footer. Correct variant shown for light/dark theme. Alt text present.

### QC Gate 2
Deploy dashboard. Browser-verify:
- Hero gone, no redundancy
- Current Conditions card is first, shows comfort index correctly
- Wind compass animates smoothly
- Rain rate displays
- UV bar colored correctly
- Barometer trend shows
- Today's Forecast above fold
- Footer logo visible, theme-aware
- Mobile: single column, no overflow, touch targets OK

---

## Phase 3: Per-Page Fixes (Items 11, 12, 13, 15, 17, 18, 19)

Individual page fixes. Can run some tasks in parallel.

### Task 3.1: Lightning tile i18n fix (Item 11)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/now.tsx:565-590` — Lightning card
- `public/locales/en/now.json` — has a `"lightning"` key conflict (top-level string at line 8 AND nested object at lines 117-123)

**Work:**
- Fix the i18n key conflict: the `"lightning"` key is used both as a section title string AND as an object with nested keys. Rename the title key to `"lightningTitle"` (or use `"lightning.title"` as a nested key) and update the component reference.
- Verify lightning column automap works: check if `lightning_strike_count`, `lightning_distance`, `lightning_energy` flow through from the observation. The `useLightning(observation)` derived hook extracts these — verify the field names match what the API returns.

**Acceptance:** No i18n error in console. Lightning tile renders data when lightning fields are present in observation.

### Task 3.2: Radar map fix (Item 12)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/components/shared/radar-map.tsx` — radar map with RainViewer tile builder
- `src/routes/now.tsx` — where radar map is rendered

**Work:**
- Investigate: is the radar provider configured? Check if `/api/v1/radar/providers/{id}/frames` returns data
- Check `buildTileUrl()` function — verify `{host}`, `{path}`, `{time}`, `{size}`, `{color}`, `{options}` placeholders are all resolved correctly
- Check if the component handles the case where no radar provider is configured (should show a "No radar provider configured" message, not a broken map)
- Verify Leaflet TileLayer renders the overlay on top of the OpenStreetMap base
- If the issue is provider config (no radar frames returned), the fix is config-side, not code-side

**Acceptance:** Radar overlay visible on map when provider is configured. Graceful fallback when not configured.

### Task 3.3: Forecast page weather icons (Item 13)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/forecast.tsx` — forecast page
- `src/components/weather-icon.tsx` — WeatherIcon component (WMO code 0-99 mapping, already built)
- `public/locales/en/weather.json` — WMO code descriptions

**Work:**
- Wire `WeatherIcon` into daily forecast cards at a prominent size (size 24 or larger)
- Wire `WeatherIcon` into hourly forecast strip items
- Add precipitation probability visual bar (colored fill proportional to %)
- Add wind direction arrows on daily cards (small arrow SVG rotated by wind direction degrees)
- Improve visual hierarchy: icon should be the dominant visual element on each card, not text

**Acceptance:** Each forecast card has a weather condition icon. Precip probability bars visible. Hourly strip has icons. Visual improvement over text-only.

### Task 3.4: Earthquake page fixes (Item 15)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/earthquakes.tsx` — earthquake page
- Leaflet map already exists with `CircleMarker` plotting

**Work:**
- Limit the earthquake list to 20 most recent. Add "Show more" button that loads 20 more (client-side pagination from the full API response)
- Fix magnitude badge CSS overflow: the 14×14 badge with "M" label + magnitude value bleeds into adjacent text. Fix with `overflow: hidden`, `flex-shrink-0`, or increase badge size
- Verify earthquake markers are plotted on the Leaflet map (the code exists: `CircleMarker` with magnitude-scaled radius and PAGER-colored fill). If markers aren't showing, check if earthquake data includes lat/lng coordinates.

**Acceptance:** List shows max 20 initially with "Show more". Magnitude badges don't overlap text. Earthquakes visible on map with colored markers.

### Task 3.5: Records page — today's comparison (Item 17)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/records.tsx` — records page with semantic table
- `src/hooks/useWeatherData.ts` — `useObservation()` hook for current data

**Work:**
- Add a "Today" column to the records table showing today's value for each record category
- Pull today's values from `useObservation()` (current data) or `useTodayStats()` (today's high/low)
- Format: existing columns + new "Today" column. Each row shows: Record label | Record value | Date | Today's value
- Apply `formatValue` from Phase 1 to both record and today values

**Acceptance:** Today's values visible next to records. Proper sig figs on all values.

### Task 3.6: Reports page multi-year fix (Item 18)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/reports.tsx` — reports page with year/month selectors
- API endpoint: `GET /api/v1/reports` returns available report list

**Work:**
- Investigate: does the API return reports for years before 2025? If not, the issue is likely `[weewx] reports_directory` config pointing to wrong path or the directory only contains 2025 files. This would be a config fix on the weewx host, not a code fix.
- If the API does return multiple years: fix the year selector to show all available years
- Clean up year/month navigation: Year selector at top, Month selector below (only enabled after year selected). "Annual" is a special option in the month selector (already implemented this way — verify it works)
- Verify the NOAA table parser handles both monthly and yearly report formats

**Acceptance:** All available years accessible. Year → month navigation is clean and intuitive.

### Task 3.7: About page font polish (Item 19)

**Agent:** `clearskies-dashboard-dev` (Sonnet)  
**Input files:**
- `src/routes/about.tsx` — about page

**Work:**
- Audit font sizes and weights for consistency with the rest of the dashboard
- Ensure Inter font with proper weights renders everywhere (check if any elements fall back to system font)
- Check heading hierarchy (h1, h2, h3) sizing consistency

**Acceptance:** Typography consistent with other pages. No font fallback visible.

### QC Gate 3
Deploy dashboard (+ API if any config changes needed for items 5/18). Browser-verify each page:
- Lightning tile: no i18n error, data shows when available
- Radar: overlay visible (or graceful "not configured" message)
- Forecast: icons on every card, precip bars, wind arrows
- Earthquakes: limited list, no badge overflow, map markers
- Records: today's values in table
- Reports: all years accessible
- About: consistent fonts

---

## Phase 4: Performance Investigation (Item 16)

### Task 4.1: Profile and diagnose

**Agent:** general-purpose Sonnet agent  
**Method:** SSH to weewx + weather-dev

**Work:**
- Measure API response times for key endpoints: `/current`, `/forecast`, `/alerts`, `/aqi/current`, `/station`, `/capabilities`, `/branding`, `/earthquakes`, `/almanac`
- Check if dashboard makes API calls sequentially or in parallel (read `now.tsx` hook invocations — each `useApiQuery` call is independent, but React may serialize them)
- Check if Redis cache is configured and hitting (provider responses should be cached)
- Check if any provider upstream calls are slow (especially external HTTP calls)
- Measure time from browser navigation to full page render

**Deliverable:** Root cause analysis with specific latency numbers + recommended fixes.

### Task 4.2: Implement fixes (conditional on 4.1 findings)

**Agent:** `clearskies-dashboard-dev` or `clearskies-api-dev` depending on findings  

Likely fixes:
- **Dashboard:** Ensure independent API calls fire in parallel (React.useEffect with Promise.all or parallel hooks — verify the hooks already do this via independent useApiQuery calls)
- **API:** Check provider timeout settings, DB connection pool health
- **Network:** Check if Caddy proxy adds latency between weather-dev and weewx API

**Acceptance:** Measurable improvement in page load time. Specific before/after numbers.

### QC Gate 4
Before/after timing comparison for key pages.

---

## Phase 5: Wizard UI Polish (Items 1, 9) + Unresolved Pre-Phase Items

### Task 5.1: Wizard progress bar + completion page

**Agent:** general-purpose Sonnet agent (these are Jinja2/CSS templates, not React)  
**Input files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/layout.html` — CSS lines 11-78 for progress bar
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/_progress_bar.html` — step indicator partial
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_complete.html` — completion page
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/restart_status_fragment.html` — HTMX status fragment

**Work:**
- **Item 1 (progress bar):** Fix uneven spacing. Current CSS: `flex: 1 1 0` + `min-width: 5rem`. "Live Updates" wraps to two lines. Fix: add `white-space: nowrap` to step labels, reduce font-size slightly if needed, or abbreviate "Live Updates" to "Updates" or "Realtime". Alternatively, use `text-overflow: ellipsis` with `overflow: hidden`.
- **Item 9 (completion page):** The restart_status_fragment.html shows realtime status even when `realtime_unknown` is true (meaning systemd unit doesn't exist). Fix: wrap the realtime status row in `{% if not realtime_unknown %}...{% endif %}` so it only shows when the realtime service is actually managed by the wizard.

**Acceptance:** Progress bar steps are visually even. Completion page hides irrelevant realtime status when not applicable.

### Task 5.2: Unresolved items from Pre-Phase (conditional)

If the pre-phase verification found items 3–6 still unresolved, fix them here:
- Item 5 (NOAA reports dir): Add `[weewx] reports_directory` to api.conf pointing to the correct path
- Item 6 (Content dir): Create `/etc/weewx-clearskies/content/` with placeholder about.md and legal.md
- Items 3/4: May require a wizard re-run or manual secrets.env edit

**Agent:** general-purpose Sonnet agent (SSH config work)

### QC Gate 5
Deploy config UI. Verify wizard progress bar in browser. Verify completion page with a mock restart scenario.

---

## Phase 6: Local Conditions Engine — Research Deliverable (Item 21)

**Status:** Research complete. No implementation this session. The findings below are the deliverable — a full implementation spec for a future session.

### Core Design: Blended Local + Provider Conditions

The engine is **not** pure local-sensor — it's a **blend** of local sensor readings and provider forecast text. Two categories of conditions cannot be reliably derived from station sensors alone:

1. **Snow/frozen precipitation.** Most home weather stations have tipping-bucket rain gauges that get covered by snow and register zero precipitation. Snow measurement (beyond expensive laser disdrometers) is still a human job. When the station detects no precipitation but the provider reports snow, the provider wins.

2. **Nighttime sky condition.** Solar radiation = 0 at night, so the clearness index is undefined. Provider text is the authoritative source for nighttime sky conditions.

**Blending rules:**

| Element | Daytime (sun >10° altitude) | Nighttime / Dawn-Dusk |
|---------|---------------------------|----------------------|
| **Sky condition** | **Local** — clearness index Kt from radiation/maxSolarRad | **Provider** — pull sky condition from forecast provider's current text |
| **Precipitation (rain)** | **Local** — rainRate from station sensor | **Local** — rainRate (rain gauge works fine at night) |
| **Precipitation (snow/ice)** | **Provider** — station can't detect snow reliably. If local sensors show rainRate=0 but provider says snow/ice, use provider. If local sensors show rain AND wet-bulb >35°F, use local. | **Provider** — same logic |
| **Wind** | **Local** — windSpeed, windGust, windDir from station | **Local** — wind sensors work 24/7 |
| **Comfort** | **Local** — dewpoint, humidity from station | **Local** — same |

**Implementation pattern:**
```python
def derive_conditions_text(
    observation: Observation,
    max_solar_rad: float | None,
    provider_text: str | None,   # from forecast provider's current conditions
    sun_altitude: float | None,  # from almanac service
) -> str:
```

The function checks sun altitude to decide local-vs-provider for sky condition, checks for the snow gap (no local precip detected + provider says snow -> trust provider), and assembles the composite from whichever source wins each element.

### Validated Thresholds (from NWS/WMO/academic sources)

| Element | Thresholds | Source |
|---------|-----------|--------|
| **Sky — clearness index Kt** | >0.80 = Clear, 0.65-0.80 = Mostly Sunny, 0.45-0.65 = Partly Cloudy, 0.30-0.45 = Mostly Cloudy, <0.30 = Overcast | Solar resource assessment literature (SCIRP, PVsyst) |
| **Rain intensity (in/hr)** | <0.01 = Drizzle, 0.01-0.10 = Light Rain, 0.10-0.30 = Moderate Rain, >0.30 = Heavy Rain | WMO / NWS METAR encoding |
| **Snow vs rain** | Wet-bulb temp <=33°F (0.5°C) = Snow, 33-35°F = Mixed, >35°F = Rain. Wet-bulb approx: Stull 2011 formula from temp + RH | Wang et al. 2019 (Geophysical Research Letters) |
| **Wind (mph sustained)** | 0-3 = Calm (omit), 4-12 = Light, 13-18 = Moderate, 19-24 = Breezy, 25-38 = Windy, 39-54 = High Wind, >=55 = Extreme | NWS Beaufort scale. **Must match** dashboard's existing `beaufortLabel()` in now.tsx |
| **Gusty qualifier** | gust >= sustained + 12 mph AND gust >= 18 mph | WMO gust definition + NWS METAR reporting thresholds |
| **Dewpoint comfort (°F)** | <50 = Dry (omit), 50-59 = Comfortable (omit), 60-64 = Sticky (omit), 65-69 = Humid, 70-74 = Oppressive, >=75 = Miserable | NWS Tampa Bay / La Crosse dewpoint comfort scale |
| **Nighttime sky** | Delegate to provider text. Cache last provider sky reading in Redis with TTL matching forecast cache (30 min). | N/A — provider blending |
| **Dawn/dusk exclusion** | Sun altitude <10° — Kt becomes unreliable, delegate to provider | Solar resource assessment best practice |

### Composite Construction

Priority: Sky -> Precipitation -> Wind -> Comfort. Omit neutral elements. "and" for last element, commas otherwise.

Examples:
- "Clear and Calm"
- "Partly Cloudy, Light Rain, Breezy and Humid"
- "Overcast with Heavy Rain" (provider sky at night + local rain)
- "Snow, Windy and Gusty" (provider precip + local wind)
- "Mostly Cloudy" (provider sky at night, no other notable conditions)

### Integration Point

Called in `endpoints/observations.py` GET /current handler, populates `observation.weatherText`. Needs access to:
- Current observation (all sensor fields)
- maxSolarRad (from weewx computed field)
- Provider's current conditions text (from forecast provider's cached response)
- Sun altitude (from almanac service, already wired)

### Resolved Design Decisions

1. **Beaufort labels:** API-side labels MUST match the dashboard's existing `beaufortLabel()` function (now.tsx lines ~41-55). Single source of truth — extract to a shared constant or ensure they're identical.

2. **Nighttime/provider cache:** Redis (not in-memory). The provider text cache already uses Redis (30 min TTL for forecast). The conditions engine piggybacks on this — when it needs provider text for nighttime sky or snow, it reads from the same cached forecast response. No new cache infrastructure needed.

3. **Operator configurability:** Yes — the engine should be disable-able via `api.conf`:
   ```ini
   [conditions]
   engine = local    # "local" (blended local+provider) | "provider" (provider-only, legacy) | "off" (no weatherText)
   ```
   **However**, this ties into a broader future effort: **per-card show/hide configuration** across all dashboard pages. The operator should be able to configure which tiles/cards appear on each page (e.g., hide earthquake card if not in a seismic area, hide AQI if no provider configured). The conditions engine on/off is one instance of this pattern. **Pin this — acknowledge it as part of that future card-configuration session, don't solve it in isolation here.**

### New File

`weewx_clearskies_api/services/local_conditions.py` (~200-250 lines Python, up from 150-200 estimate to account for blending logic)

### Provider Data Parsing — No Free-Text NLP Needed

The blending engine does NOT need to parse arbitrary English text. The API already normalizes provider responses into structured fields:

| Provider | Sky condition source | Precipitation type source |
|----------|---------------------|--------------------------|
| **Open-Meteo** | WMO weather code (integer 0-99), already mapped via `_WMO_CODE_TO_TEXT` in `openmeteo.py` | `precipType` canonical field ("rain" / "snow" / "freezing-rain" / null) |
| **NWS** | `shortForecast` — semi-structured English from a small fixed vocabulary ("Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy", "Fog") | `shortForecast` keywords: "Snow", "Ice", "Sleet", "Freezing Rain", "Rain" — pattern-matchable, NOT free-form prose |
| **Aeris** | Structured descriptor codes (e.g., "S" -> snow, "ZR" -> freezing rain) | Same descriptor codes |
| **OWM** | Weather condition ID (integer, e.g., 601 = snow) | Same condition IDs |

The conditions engine reads the **cached forecast response** (already in memory/Redis from the forecast provider) and extracts:
1. `weatherCode` (WMO integer) -> deterministic lookup, no parsing
2. `precipType` (canonical enum) -> direct string comparison
3. For NWS only: keyword match on `shortForecast` against a ~15-word vocabulary list ("Snow", "Sleet", "Ice Pellets", "Freezing Rain", "Rain", "Drizzle", "Thunderstorm", "Fog", "Haze", "Smoke", "Clear", "Sunny", "Cloudy", "Partly", "Mostly")

This is deterministic pattern matching, not text detection. The WMO code path (Open-Meteo) and condition-ID path (OWM) are fully machine-structured. NWS is the only one with English text, and that text follows strict NWS encoding conventions with a bounded vocabulary.

### Open Items for Implementation Session

- For NWS `shortForecast` parsing: build a keyword extractor that maps NWS vocabulary to canonical sky/precip tokens. ~15-20 keywords covers >99% of NWS output. Edge cases ("Areas of Fog", "Chance of Showers") follow consistent NWS phrasing patterns.
- Decide how to handle conflicting signals (e.g., local says rain via rainRate, provider says snow — who wins? Proposal: if wet-bulb is in the ambiguous 33-35°F range, provider wins)
- Test with real winter data (capture fixtures from a snowy day to validate blending)
- Coordinate with the per-card configuration effort — the `[conditions] engine` setting should follow whatever pattern that session establishes for operator config knobs

---

## Appendix A: Key File Paths

### Dashboard (repos/weewx-clearskies-dashboard/src/)
| File | Purpose |
|------|---------|
| `routes/now.tsx` | Now page — hero, all tiles, inline formatting |
| `routes/forecast.tsx` | Forecast page |
| `routes/earthquakes.tsx` | Earthquake page |
| `routes/records.tsx` | Records page |
| `routes/reports.tsx` | Reports page |
| `routes/about.tsx` | About page |
| `components/hero-section.tsx` | Hero banner (to be deleted) |
| `components/weather-icon.tsx` | WMO code -> Weather Icons mapping |
| `components/shared/radar-map.tsx` | Leaflet radar map |
| `components/layout/footer.tsx` | Footer with "Powered by" text |
| `hooks/useWeatherData.ts` | Per-domain API hooks |
| `hooks/useRealtimeObservation.ts` | REST + SSE data hook |
| `api/types.ts` | TypeScript interfaces (Observation, etc.) |
| `api/client.ts` | API client functions |
| `lib/utils.ts` | Only `cn()` — no formatting utils yet |
| `public/locales/en/now.json` | Now page i18n (lightning key conflict) |

### Config UI (repos/weewx-clearskies-stack/)
| File | Purpose |
|------|---------|
| `weewx_clearskies_config/templates/wizard/layout.html` | Wizard CSS + layout |
| `weewx_clearskies_config/templates/wizard/_progress_bar.html` | Step indicators |
| `weewx_clearskies_config/templates/wizard/step_complete.html` | Completion page |
| `weewx_clearskies_config/templates/wizard/restart_status_fragment.html` | HTMX status polling |

### API (repos/weewx-clearskies-api/)
| File | Purpose |
|------|---------|
| `weewx_clearskies_api/endpoints/observations.py` | GET /current handler |
| `weewx_clearskies_api/models/responses.py` | Observation model |
| `weewx_clearskies_api/services/` | Service modules (future local_conditions.py) |

### Assets
| File | Purpose |
|------|---------|
| `Graphics/clearskies logo POWERED blue.svg` | Powered logo (8.4 KB, #2568a3 blue) |

## Appendix B: Existing Patterns to Reuse

- **`beaufortLabel(speedMph, t)`** in now.tsx — Beaufort scale labels, already i18n-aware
- **`barometerTrendArrow(trend)`** in now.tsx — trend arrow (up/down/steady)
- **`aqiColor(aqi)` / `aqiCategory(aqi, t)`** in now.tsx — AQI display helpers
- **`windDirLabel(deg)`** in now.tsx — 16-point compass direction
- **`WeatherIcon` component** — WMO code 0-99 -> weather icons, with day/night variants
- **`TileSkeleton` / `TileError`** — loading/error state pattern (defined inline in now.tsx, consider extracting)
- **`useApiQuery` hook** — generic API fetch with loading/error/data/refetch pattern
- **`formatValue` (TO CREATE)** — new shared formatting utility

## Verification

After each phase, deploy and verify in browser at `http://192.168.2.113` (weather-dev via Caddy):
1. **Phase 1:** Check every numeric value on every page — no float noise
2. **Phase 2:** Check Now page layout, hero gone, all new tiles render, footer logo
3. **Phase 3:** Check each fixed page individually
4. **Phase 4:** Measure page load times before/after
5. **Phase 5:** Check wizard flow in browser at `http://192.168.2.113/wizard`
