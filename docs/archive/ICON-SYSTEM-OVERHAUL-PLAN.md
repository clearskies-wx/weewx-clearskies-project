# Forecast & Current Conditions Icon System Overhaul

**Status:** APPROVED
**Created:** 2026-07-14
**Origin:** Research brief [FORECAST-ICON-SELECTION-BRIEF.md](../../CODE/weather-belchertown/docs/planning/briefs/FORECAST-ICON-SELECTION-BRIEF.md). User noticed showers icon at 10% PoP. Audit revealed: no PoP gate on icon selection, provider code mapping silently dropping atmosphere conditions, 11 glyphs collapsing 32+ conditions into too few visuals.

## Context

The dashboard's `WeatherIcon` component renders hero weather icons for current conditions, hourly forecasts, and daily forecasts. Three categories of problems were found:

1. **No PoP gate** — the provider's `weatherCode` flows through to the icon with no precipitation probability check. A 10% PoP still shows rain. Industry standard is 20%+ before showing precipitation icons.
2. **Provider mapping gaps** — NWS shortnames (`"rain"`, `"sct"`), OWM condition IDs (200–804), and Aeris atmosphere codes (`K`, `BD`, `H`) all return null from our mapping, producing blank icons.
3. **Missing glyphs** — 11 existing icons collapse too many conditions. No wintry mix, drizzle, mostly cloudy, smoke, dust, or combined sky+precipitation icons. Haze only has clear-sky variants.

## 0. Orientation — Execution Context

**Repos:**
- Dashboard: `repos/weewx-clearskies-dashboard`
- API: `repos/weewx-clearskies-api`

**Critical files:**
- `dashboard/src/components/weather-icon-glyphs.tsx` — SVG glyph components (11 existing)
- `dashboard/src/components/weather-icon.tsx` — `WMO_MAP` + `WeatherIcon` component
- `dashboard/src/utils/weather-code.ts` — `toWmoCode()` provider code normalization
- `dashboard/src/components/weather-icon.test.tsx` — glyph tests (28 of 32 codes covered)
- `dashboard/src/components/current-conditions-card.tsx` — hero icon render (line 453)
- `dashboard/src/components/forecast/HourlyStrip.tsx` — hourly icon render (line 202)
- `dashboard/src/components/forecast/DailyColumns.tsx` — daily icon render (line 313)
- `api/weewx_clearskies_api/models/responses.py` — `HourlyForecastPoint`, `DailyForecastPoint`, `Observation`
- `api/weewx_clearskies_api/sse/enrichment/weather_text.py` — `_derive_weather_code()` (current conditions)

**Existing mockup reference:** `docs/design/mockups/A3-material-gradient.html` — self-contained HTML with gradient SVGs, theme toggle, size slider. New mockup follows this format.

**Icon source:** Google Material Symbols (filled) SVG paths via Iconify, recolored with Meteocons-style gradients per ADR-049. Visual reference for new icons: Meteocons icon set (composition patterns only — we use Material Symbols paths with our gradient treatment).

**Test baselines (must not regress):**

| Suite | Command |
|-------|---------|
| Dashboard vitest | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |
| API pytest | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |

**Known data gaps for PoP gate implementation:**
- `DailyForecastPoint` has NO `cloudCover` field (API or dashboard) — needs to be added
- `Observation` TS interface in dashboard lacks `cloudcover` (API Python model has it)
- `current-conditions-card.tsx` does not plumb `cloudCover` or `precipProbability` to icon render
- `HourlyStrip.tsx` has both `cloudCover` and `precipProbability` available — easiest consumer
- `DailyColumns.tsx` has `precipProbabilityMax` but no `cloudCover`
- Marine `LocationCard.tsx` has neither — exempt from PoP gate

---

## Phase 1 — Documentation & Design Foundation

Doc changes come first. Define what we're building before building it. The mockup is the visual approval gate — no production glyph work starts until the mockup is approved.

### T1.1 — Update DESIGN-MANUAL with expanded icon inventory

- Owner: Coordinator (Opus)
- File: `docs/manuals/DESIGN-MANUAL.md`

**Do:** Add/update the hero weather icon section to document:
- The complete icon inventory (11 existing + 21 new = 32 total)
- The three composition techniques: standalone (dust), overlay (smoke), cutout (haze)
- The cloud-cover × atmosphere-condition matrix
- The PoP-gated icon selection tiers (< 20% = sky only, 20–50% + cloud < 75% = combined sky+precip, > 50% or cloud ≥ 75% = precip only)
- New gradient definitions needed (smoke grey, dust tan/brown)
- Day/night variant rules per icon category
- Excluded icons with rationale (wind, hot/cold)

### T1.2 — Update DASHBOARD-MANUAL with PoP gate behavior

- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md`

**Do:** Document the icon selection pipeline:
- PoP gate: 20% threshold, dashboard-side decision
- Cloud-cover fallback tiers when PoP suppresses precipitation icon
- Atmosphere condition selection logic (smoke=overlay, dust=standalone, haze=cutout, each with cloud-cover tier)
- Data flow: API passes raw `weatherCode` + `cloudCover` + `precipProbability` → dashboard applies selection logic

### T1.3 — Update API-MANUAL with new WMO extension codes

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`

**Do:** Document new API extension WMO codes alongside existing extensions (4, 5, 10, 79):
- Code 6: Smoke (new)
- Code 7: Dust / blowing dust (new)
- Code 8: Volcanic ash (new)
- Document that `DailyForecastPoint` gains a `cloudCover` field (max cloud cover across the day's hourly points)

### T1.4 — Create full icon mockup

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `docs/design/mockups/A3-icon-system-expansion.html`
- Reference: `docs/design/mockups/A3-material-gradient.html` (format template)

**Do:** Create a self-contained HTML mockup showing all 32 icons in a grid with labels. Organized by category:

**Section 1 — Sky conditions (existing + new):**
- Clear day / Clear night (existing)
- Partly cloudy day / Partly cloudy night (existing)
- Mostly cloudy day / Mostly cloudy night (NEW — sun/moon barely visible behind cloud)
- Overcast (existing)

**Section 2 — Precipitation (existing + new):**
- Rain (existing)
- Drizzle (NEW — cloud + small rain dots, not streaks)
- Snow (existing)
- Wintry mix (NEW — cloud + rain streaks + snow dots)
- Thunderstorm (existing)

**Section 3 — Combined sky + precipitation (all NEW):**
- Partly cloudy + rain (day/night)
- Partly cloudy + snow (day/night)
- Partly cloudy + wintry mix (day/night)

**Section 4 — Atmosphere conditions:**
- Haze clear day / night (existing)
- Haze partly cloudy day / night (NEW — cutout technique)
- Haze overcast (NEW — cutout technique)
- Smoke clear day / night (NEW — overlay technique, bubbles on top)
- Smoke partly cloudy day / night (NEW — overlay technique)
- Smoke overcast (NEW — overlay technique)
- Dust day / night / overcast (NEW — standalone technique)

**Section 5 — Fog (existing):**
- Fog / Mist / Rime fog (existing, same glyph)

Must include: theme toggle (light/dark), size slider, WMO code labels, gradient color swatches for new gradients (smoke grey, dust tan/brown). Use Meteocons as visual reference for composition patterns.

**Accept:** Mockup renders all 32 icons. User approves visual direction before Phase 4 begins.

### QC Gate 1

**Adversarial audit** (`clearskies-auditor`, Sonnet): Before closing this phase, spawn an auditor agent to independently verify:
- Every icon listed in the DESIGN-MANUAL inventory has a corresponding entry in the mockup (completeness check)
- PoP gate thresholds in DASHBOARD-MANUAL match the research brief's §5.1 recommendation (20%)
- New WMO extension codes in API-MANUAL don't collide with any existing codes or standard WMO codes used by Open-Meteo
- Mockup renders all 32 icons without visual defects in both light and dark themes
- Doc prose is consistent across all three manuals (no contradictions in threshold values, code assignments, or selection logic)

**Pass criteria:**
- DESIGN-MANUAL documents the full 31-icon inventory with selection logic
- DASHBOARD-MANUAL documents the PoP gate behavior and data flow
- API-MANUAL documents new WMO extension codes and `cloudCover` on daily
- Mockup renders all 32 icons with theme toggle and is approved by the user
- Auditor findings: zero blockers (informational findings acceptable)

---

## Phase 2 — Provider Code Mapping & Data Model Fixes

Fix the silent data-loss bugs. After this phase, all providers' conditions map to WMO codes and the data needed for the PoP gate is available at every icon render site.

### T2.1 — Add NWS shortname mapping

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/utils/weather-code.ts`

**Do:** Add an `NWS_TO_WMO` mapping table and update `toWmoCode()` to check it when the input is a non-numeric string that doesn't match any Aeris code. NWS shortnames to map:

| NWS Shortname | WMO Code | Condition |
|---------------|----------|-----------|
| `skc` | 0 | Clear |
| `few` | 1 | Few clouds |
| `sct` | 2 | Scattered clouds |
| `bkn` | 3 | Broken / mostly cloudy |
| `ovc` | 3 | Overcast |
| `fg` / `fg/ovc` | 45 | Fog |
| `ra` | 61 | Rain |
| `shra` | 80 | Rain showers |
| `sn` | 71 | Snow |
| `tsra` | 95 | Thunderstorm |
| `fzra` | 66 | Freezing rain |
| `mix` | (wintry mix code) | Wintry mix |
| `ip` | 79 | Sleet |
| `dust` | 7 | Dust (new extension) |
| `smoke` | 6 | Smoke (new extension) |
| `haze` | 5 | Haze |
| `hot` | 0 | Hot (show clear icon) |
| `cold` | 0 | Cold (show clear icon) |
| `blizzard` | 75 | Heavy snow |
| `wind_skc` | 0 | Windy + clear |
| `wind_few` | 1 | Windy + few clouds |
| `wind_sct` | 2 | Windy + scattered |
| `wind_bkn` | 3 | Windy + broken |
| `wind_ovc` | 3 | Windy + overcast |

Also handle compound NWS icon URLs that contain two shortnames separated by `/` (e.g., `sct/smoke` — take the more specific/severe condition).

### T2.2 — Add OWM condition ID mapping

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/utils/weather-code.ts`

**Do:** Add an `OWM_TO_WMO` mapping table. OWM uses integer IDs in the 200–804 range. The mapping must intercept numeric codes that fall outside the WMO 0–99 range and map them. Key mappings:

| OWM ID Range | WMO Code | Condition |
|-------------|----------|-----------|
| 200–232 | 95 | Thunderstorm group |
| 300–321 | 51 | Drizzle group |
| 500–504 | 61 | Rain group |
| 511 | 66 | Freezing rain |
| 520–531 | 80 | Rain showers |
| 600–622 | 71 | Snow group |
| 701 | 10 | Mist |
| 711 | 6 | Smoke (new extension) |
| 721 | 5 | Haze |
| 731, 761 | 7 | Dust (new extension) |
| 741 | 45 | Fog |
| 751 | 7 | Sand → dust |
| 762 | 8 | Volcanic ash (new extension) |
| 771 | 3 | Squall → overcast |
| 781 | 95 | Tornado → thunderstorm (closest) |
| 800 | 0 | Clear |
| 801 | 1 | Few clouds |
| 802 | 2 | Scattered clouds |
| 803 | 3 | Broken clouds |
| 804 | 3 | Overcast |

Update `toWmoCode()` or `WeatherIcon`'s code processing to check `OWM_TO_WMO` for numeric codes > 99.

### T2.3 — Add Aeris atmosphere code mapping

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/utils/weather-code.ts`

**Do:** Add missing Aeris codes to the existing `AERIS_TO_WMO` table:

| Aeris Code | WMO Code | Condition |
|-----------|----------|-----------|
| `K` | 6 | Smoke |
| `BD` | 7 | Blowing dust |
| `H` | 5 | Haze |
| `BS` | 75 | Blowing snow → heavy snow |
| `BY` | 80 | Blowing spray → rain showers |
| `VA` | 8 | Volcanic ash |
| `WM` | (wintry mix code) | Wintry mix |
| `RS` | (wintry mix code) | Rain/snow mix |
| `SI` | 79 | Snow/sleet |

### T2.4 — Add `cloudCover` to DailyForecastPoint

- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)

**API side** (`api/models/responses.py`):
- Add `cloudCover: float | None = None` to `DailyForecastPoint`

**Provider modules** — each provider that populates daily forecasts must compute `cloudCover` for the day:
- **Open-Meteo** (`providers/forecast/openmeteo.py`): Add `cloud_cover_max` or `cloud_cover_mean` to the daily variables request. Open-Meteo supports `cloud_cover_max` and `cloud_cover_mean` on the daily endpoint. Use max (conservative — matches precipProbabilityMax approach).
- **Aeris** (`providers/forecast/aeris.py`): Daily periods have `sky` field (0–100). Map to `cloudCover`.
- **NWS** (`providers/forecast/nws.py`): Daily periods don't have a numeric cloud cover field. Derive from icon shortname: `skc`→0, `few`→15, `sct`→35, `bkn`→70, `ovc`→95. Or leave null.
- **OWM** (`providers/forecast/openweathermap.py`): Daily periods have `clouds` field (0–100). Map directly.

**Dashboard side** (`dashboard/src/types.ts`):
- Add `cloudCover: number | null` to `DailyForecastPoint` interface

### T2.5 — Add `cloudcover` to dashboard Observation TS type

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/types.ts`

**Do:** Add `cloudcover: number | null` to the `Observation` interface (the API Python model already has this field at `responses.py` line 79, but the dashboard TS type omits it). This enables the current conditions card to use cloud cover for the PoP gate.

### T2.6 — Define new WMO extension codes in API conditions engine

- Owner: `clearskies-api-dev` (Sonnet)
- File: `api/weewx_clearskies_api/sse/enrichment/weather_text.py`

**Do:** The `_derive_weather_code()` function currently emits code 5 for haze. Add support for:
- Code 6: Smoke — when provider `weatherText` contains smoke keywords AND the conditions engine confirms (existing nighttime/missing-pyranometer deferral path already detects smoke via provider text)
- Code 7: Dust — when provider `weatherText` contains dust keywords (new detection path, provider-only since no station sensor detects dust)

This ensures the current conditions pipeline can emit the new codes, not just the forecast pipeline.

### T2.7 — Update test coverage

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon.test.tsx`

**Do:**
- Add WMO extension codes 4, 5, 10, 79 to `ALL_WMO_CODES` test array
- Add new extension codes 6 (smoke), 7 (dust), 8 (volcanic ash)
- Add tests for `toWmoCode()` with NWS shortnames, OWM IDs, and Aeris atmosphere codes
- Add tests for OWM codes > 99 mapping correctly

### QC Gate 2

**Adversarial audit** (`clearskies-auditor`, Sonnet): Spawn an auditor to independently verify:
- Every NWS shortname from the [NWS icon documentation](https://www.weather.gov/forecast-icons) is mapped (no gaps in the table)
- Every OWM condition ID from [OWM Weather Conditions](https://openweathermap.org/weather-conditions) is mapped (no gaps in 200–804 range)
- Every Aeris weather type code from the Aeris API docs is either mapped or explicitly documented as out-of-scope
- `toWmoCode()` handles edge cases: empty string, malformed codes, codes with unexpected delimiters
- No WMO code collisions between the three provider mapping tables
- `cloudCover` on `DailyForecastPoint` is populated by at least Open-Meteo and Aeris (the two providers most likely to be configured)
- New WMO extension codes 6, 7, 8 in `_derive_weather_code()` have correct priority ordering relative to existing conditions (smoke/dust should be lower priority than precipitation, higher than sky-only)

**Pass criteria:**
- `toWmoCode("rain")` returns 61, `toWmoCode("sct")` returns 2, `toWmoCode("smoke")` returns 6
- `toWmoCode("500")` or numeric 500 maps to 61 (rain), 711 maps to 6 (smoke)
- `toWmoCode("::K")` returns 6 (smoke), `toWmoCode("::BD")` returns 7 (dust)
- `DailyForecastPoint` includes `cloudCover` from all providers that supply it
- Dashboard `Observation` type includes `cloudcover`
- All existing + new WMO codes tested
- Auditor findings: zero blockers
- Test baselines hold

---

## Phase 3 — PoP Gate Implementation

Add the 20% PoP threshold to icon selection. Below 20%, show a sky-condition icon based on cloud cover instead of the provider's precipitation icon.

### T3.1 — Create icon selection utility

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: NEW `dashboard/src/utils/icon-selection.ts`

**Do:** Create a utility function that applies the PoP gate and atmosphere condition logic:

```ts
function selectWeatherIcon(params: {
  weatherCode: number | null;
  precipProbability: number | null;
  cloudCover: number | null;
  isNight: boolean;
}): { code: number; isNight: boolean }
```

Logic:
1. If `weatherCode` is null → return code 0 (clear)
2. If `weatherCode` indicates precipitation (WMO 51–99 range) AND `precipProbability < 20`:
   - Suppress precipitation icon
   - Return sky-condition code based on `cloudCover`: 0–25% → 0 (clear), 25–50% → 2 (partly cloudy), 50–87% → 3 (mostly cloudy), 87–100% → 3 (overcast)
3. If `weatherCode` indicates precipitation AND `precipProbability` 20–50 AND `cloudCover < 75`:
   - Return a combined sky+precipitation code (new codes TBD — e.g., 101 = partly cloudy + rain, 102 = partly cloudy + snow, etc.)
4. If `weatherCode` indicates atmosphere condition (5=haze, 6=smoke, 7=dust):
   - Use `cloudCover` to pick the correct cloud-cover tier variant
   - Return the appropriate compound code
5. Otherwise → return `weatherCode` as-is

### T3.2 — Plumb data to icon call sites

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `current-conditions-card.tsx`, `HourlyStrip.tsx`, `DailyColumns.tsx`

**Do for each consumer:**

**HourlyStrip** (easiest — data already available):
- Replace `toWmoCode(hour.weatherCode)` with `selectWeatherIcon({ weatherCode: toWmoCode(hour.weatherCode), precipProbability: hour.precipProbability, cloudCover: hour.cloudCover, isNight })` 

**DailyColumns:**
- Replace `toWmoCode(day.weatherCode)` with `selectWeatherIcon({ weatherCode: toWmoCode(day.weatherCode), precipProbability: day.precipProbabilityMax, cloudCover: day.cloudCover, isNight: false })`

**CurrentConditionsCard:**
- Thread `observation.cloudcover` and `precipProbability` (from hourly[0] or todayForecast) to the icon render
- For current conditions, the PoP gate may not apply the same way (current conditions come from the station's own sensors, not a probabilistic forecast). Decision: apply the gate only to forecast-sourced weatherCodes (the fallback path), not to the conditions engine's direct weatherCode.

**Marine LocationCard:**
- Exempt from PoP gate (no precip probability data available on marine observations)

### T3.3 — Add tests for icon selection utility

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: NEW `dashboard/src/utils/icon-selection.test.ts`

**Do:** Test all selection paths:
- PoP < 20% with precipitation code → returns sky-condition code based on cloud cover
- PoP 20–50% with cloud < 75% → returns combined sky+precip code
- PoP > 50% → returns precipitation code unchanged
- Atmosphere conditions (smoke/dust/haze) → returns correct cloud-cover tier variant
- Null inputs → graceful defaults

### QC Gate 3

**Adversarial audit** (`clearskies-auditor`, Sonnet): Spawn an auditor to independently verify:
- The PoP gate logic handles boundary values correctly: exactly 20% PoP should show precipitation (≥ 20 threshold, not > 20)
- Cloud-cover fallback tiers produce the correct icon at each boundary (24% vs 26%, 49% vs 51%, 86% vs 88%)
- Combined sky+precipitation codes only activate when BOTH conditions are met (PoP 20–50% AND cloudCover < 75%) — not just one
- Atmosphere condition logic correctly selects cloud-cover tier for smoke/dust/haze
- The current conditions card correctly exempts station-sourced weatherCodes from the PoP gate
- Marine LocationCard is correctly exempted
- No regression: icons that were correct before (e.g., rain at 60% PoP) still show rain

**Pass criteria:**
- HourlyStrip shows cloud icon (not rain) when PoP = 10% and weatherCode = 80
- HourlyStrip shows partly cloudy + rain icon when PoP = 30% and cloudCover = 40%
- HourlyStrip shows rain icon when PoP = 60%
- DailyColumns applies same PoP gate
- CurrentConditionsCard applies gate only on forecast-fallback path
- All icon selection test cases pass
- Auditor findings: zero blockers
- Test baselines hold

---

## Phase 4 — New Glyph Components

Build all 21 new SVG glyph components. This phase starts only after the mockup from T1.4 is approved by the user.

### T4.1 — Add new gradient definitions

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**Do:** Add to `GradientDefs`:
- `smokeGrad` — darker grey than clouds (e.g., `#9EA5AD` → `#6B7280`) for smoke wisps
- `dustGrad` — earth-tone tan/brown (e.g., `#D4A574` → `#A0734A`) for dust particles

### T4.2 — Build sky condition glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (2):**
- `GlyphMostlyCloudyDay` — cloud (greyGrad) with sun barely peeking out (goldGrad, smaller/more occluded than GlyphPartlyCloudy)
- `GlyphMostlyCloudyNight` — cloud (greyGrad) with moon barely visible (moonGrad)

### T4.3 — Build precipitation glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (2):**
- `GlyphDrizzle` — cloud (greyGrad) + small round rain dots (rainGrad). Dots not streaks — visually lighter than `GlyphRainy`.
- `GlyphWintryMix` — cloud (greyGrad) + rain streaks (rainGrad, angled) + snow dots (snowGrad). Merge lower halves of `GlyphRainy` and `GlyphSnowy` paths under one cloud.

### T4.4 — Build combined sky+precipitation glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (6):**
- `GlyphPartlyCloudyRainDay` — PartlyCloudy paths + rain streaks (rainGrad)
- `GlyphPartlyCloudyRainNight` — PartlyCloudyNight paths + rain streaks
- `GlyphPartlyCloudySnowDay` — PartlyCloudy paths + snow dots (snowGrad)
- `GlyphPartlyCloudySnowNight` — PartlyCloudyNight paths + snow dots
- `GlyphPartlyCloudyWintryMixDay` — PartlyCloudy paths + rain streaks + snow dots
- `GlyphPartlyCloudyWintryMixNight` — PartlyCloudyNight paths + rain streaks + snow dots

Implementation: reuse existing cloud+sun/moon paths from `GlyphPartlyCloudy`/`GlyphPartlyCloudyNight` and add precipitation paths from `GlyphRainy`/`GlyphSnowy`/`GlyphWintryMix` underneath.

### T4.5 — Build smoke overlay glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (5):**
- `GlyphSmokeDay` — GlyphSunny paths + smoke bubble paths overlaid (smokeGrad)
- `GlyphSmokeNight` — GlyphBedtime paths + smoke bubble paths overlaid
- `GlyphSmokePartlyCloudyDay` — GlyphPartlyCloudy paths + smoke bubble paths overlaid
- `GlyphSmokePartlyCloudyNight` — GlyphPartlyCloudyNight paths + smoke bubble paths overlaid
- `GlyphSmokeOvercast` — GlyphCloud paths + smoke bubble paths overlaid

**Technique:** Smoke bubbles are additional SVG path groups layered ON TOP of the existing glyph paths. NOT clipped/cut out. The underlying icon stays intact. Smoke wisps use `smokeGrad` (darker grey than clouds so they're visually distinct).

### T4.6 — Build dust standalone glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (3):**
- `GlyphDustDay` — dust particles (dustGrad) with sun element visible
- `GlyphDustNight` — dust particles (dustGrad) with moon element visible
- `GlyphDust` — dust particles (dustGrad) with cloud, no celestial body

**Technique:** Standalone — dust IS the dominant visual, not an overlay. Use Meteocons dust icons as composition reference.

### T4.7 — Build haze cloud-cover variant glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon-glyphs.tsx`

**New glyphs (3):**
- `GlyphHazyPartlyCloudyDay` — PartlyCloudy paths clipped + amber haze stripes below (hazeGrad)
- `GlyphHazyPartlyCloudyNight` — PartlyCloudyNight paths clipped + amber haze stripes below
- `GlyphHazyOvercast` — Cloud path clipped + amber haze stripes below

**Technique:** Same cutout/clip approach as existing `GlyphHazy`/`GlyphHazyNight` — clip the sky element at a boundary, render haze stripes (hazeGrad) below. Reuse existing `hazePaths` array and `hazeGrad`.

### T4.8 — Update WMO_MAP with all new glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon.tsx`

**Do:** Expand `WMO_MAP` to include:
- New WMO extension codes: 6 (smoke), 7 (dust), 8 (volcanic ash → use smoke overlay glyphs, not dust — ash stays suspended in atmosphere like smoke, not ground-level like dust)
- New internal compound codes for combined sky+precip icons (used by the icon selection utility from T3.1)
- Map drizzle codes 51–55 to `GlyphDrizzle` (currently mapped to `GlyphRainy`)
- Map wintry mix codes (56–57, 66–67, 79) to `GlyphWintryMix` (currently mapped to `GlyphRainy`/`GlyphSnowy`)
- Add mostly cloudy glyph for a new mostly-cloudy code (or remap existing code 3 behavior based on cloud cover)
- Add i18n description keys for all new codes

### T4.9 — Add i18n keys for new conditions

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `dashboard/public/locales/*/weather.json` (13 locale files)

**Do:** Add translation keys for new icon descriptions:
- `wmo.6` (Smoke), `wmo.7` (Dust), `wmo.8` (Volcanic ash)
- Keys for compound conditions: partly cloudy + rain, partly cloudy + snow, etc.
- Keys for mostly cloudy, drizzle, wintry mix
- English authoritative; placeholder English for other 12 locales

### T4.10 — Update test coverage for new glyphs

- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `dashboard/src/components/weather-icon.test.tsx`

**Do:**
- Add all new WMO codes to `ALL_WMO_CODES`
- Add render tests for all 21 new glyphs
- Add gradient stop tests for new gradients (smokeGrad, dustGrad)
- Add split-path tests for new composite glyphs (smoke overlays, haze variants, combined sky+precip)

### QC Gate 4

**Adversarial audit** (`clearskies-auditor`, Sonnet): Spawn an auditor to independently verify:
- Every glyph in `weather-icon-glyphs.tsx` uses `useId()` for gradient ID scoping (no global ID collisions when multiple icons render)
- Every glyph has `aria-hidden="true"` and `focusable="false"` on the SVG element
- Every new WMO code in `WMO_MAP` has a corresponding `descriptionKey` that exists in the English locale file
- Gradient stop colors for new gradients (smokeGrad, dustGrad) meet WCAG 3:1 contrast against both light and dark theme backgrounds
- No glyph component has hardcoded color values outside of `GradientDefs` (all fills reference gradient URLs)
- `CLOUD_STROKE` and `CLOUD_STROKE_WIDTH` applied consistently on all cloud paths in new glyphs
- SVG viewBox is `0 0 24 24` on all new glyphs (matches existing)
- Wintry mix glyph serves ALL intended WMO codes (56, 57, 66, 67, 79) — no code left pointing to old GlyphRainy/GlyphSnowy
- Drizzle codes 51–55 ALL remap to GlyphDrizzle (not partially left on GlyphRainy)

**Pass criteria:**
- All 32 glyphs render without errors
- Each new glyph uses correct gradients (smoke=smokeGrad, dust=dustGrad, haze=hazeGrad)
- Day/night variants show correct celestial body
- Drizzle visually distinct from rain (dots vs streaks)
- Wintry mix shows both rain streaks and snow dots
- Mostly cloudy shows sun/moon barely visible (less than partly cloudy)
- Smoke overlays show bubbles on top of intact underlying icon
- Dust standalone icons show dust as dominant visual
- Haze cloud-cover variants use cutout technique with amber stripes
- All i18n keys present
- All tests pass
- `npx tsc --noEmit` returns zero errors
- Auditor findings: zero blockers
- Test baselines hold

---

## Phase 5 — Integration, Deploy & Visual Verification

### T5.1 — Build and render verification

- Owner: Coordinator (Opus)
- Do: Build the dashboard (`tsc -b && vite build`). Deploy to weather-dev via `scripts/redeploy-weather-dev.sh`. Render screenshots of:
  - Current conditions card with various weather conditions
  - Hourly forecast strip showing PoP gate in action (mix of low and high PoP hours)
  - Daily forecast columns
- Compare rendered icons against the approved mockup from T1.4
- Verify icon selection logic: hours with PoP < 20% show sky-condition icons, hours with PoP 20–50% show combined icons, hours with PoP > 50% show precipitation icons

### T5.2 — Accessibility verification

- Owner: Coordinator (Opus)
- Do: Run `npx @axe-core/cli` against the forecast page. Verify:
  - Every new icon has an sr-only label with the translated condition text
  - Every SVG has `aria-hidden="true"` and `focusable="false"`
  - New gradient colors meet contrast requirements against photo backgrounds (both themes)

### T5.3 — Update brief with completion status

- Owner: Coordinator (Opus)
- File: `docs/planning/briefs/FORECAST-ICON-SELECTION-BRIEF.md`
- Do: Update the action summary table with completion status for each item.

### QC Gate 5

**Adversarial audit** (`clearskies-auditor`, Sonnet): Final comprehensive audit. Spawn an auditor to independently verify:
- **Doc-code sync:** Every icon in the rendered dashboard matches its DESIGN-MANUAL entry. Every WMO code in `WMO_MAP` is documented in API-MANUAL. PoP gate behavior in DASHBOARD-MANUAL matches the actual `selectWeatherIcon()` logic.
- **Visual fidelity:** Rendered icons match the approved mockup from T1.4 at the deployed size (115px hero, 36px forecast strip). No geometry explosions, clipping artifacts, or gradient fill losses.
- **PoP gate end-to-end:** Manually verify against the live forecast data: identify an hour with PoP < 20% and confirm it shows a sky icon, an hour with PoP 30–50% and confirm combined icon, an hour with PoP > 50% and confirm precipitation icon.
- **Provider mapping end-to-end:** If NWS or Aeris is configured, verify their forecast icons render (not blank). If only Open-Meteo, verify atmosphere conditions from the conditions engine render correctly.
- **Accessibility:** axe-core zero violations. Keyboard-navigate the forecast page and confirm screen reader announces each icon's condition text.
- **No regressions:** Compare current conditions card, hourly strip, and daily columns against a pre-change screenshot to confirm no visual regressions in existing icon rendering.

**Pass criteria:**
- Dashboard builds and deploys without errors
- Rendered icons match the approved mockup
- PoP gate working: low-PoP hours show sky icons, high-PoP hours show precip icons
- axe-core: zero violations on forecast page
- All sr-only labels present and translated
- Both light and dark themes verified
- Auditor findings: zero blockers
- Test baselines hold

---

## Verification

After all phases complete:
- 32 hero weather icons render correctly (11 existing + 21 new)
- PoP gate suppresses precipitation icons below 20% PoP
- Combined sky+precipitation icons show at 20–50% PoP with low cloud cover
- NWS shortnames map to correct WMO codes (no more blank icons)
- OWM 700-series atmosphere group maps correctly (smoke, dust, haze, fog)
- Aeris atmosphere codes (`K`, `BD`, `H`, `VA`) map correctly
- Smoke overlays show bubbles on top of sky condition icons
- Dust standalone icons show for all cloud-cover tiers
- Haze icons extend to partly cloudy and overcast conditions
- Wintry mix icon shows for freezing rain, sleet, and rain/snow mix
- Drizzle icon visually distinct from rain (dots vs streaks)
- Mostly cloudy icon distinct from overcast (sun/moon barely visible)
- Current conditions engine emits new WMO codes 6 (smoke), 7 (dust)
- All governing documents match implementation
- All tests pass, zero TS errors
