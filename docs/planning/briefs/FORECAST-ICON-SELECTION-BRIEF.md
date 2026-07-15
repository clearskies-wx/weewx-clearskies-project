# Brief: Forecast & Current Conditions Hero Icon Selection — Industry Research, Audit & Recommendations

**Date:** 2026-07-14 (updated 2026-07-14 — added provider mapping deficiency, atmosphere condition analysis, current conditions pipeline)  
**Scope:** How major weather services select forecast icons based on PoP (Probability of Precipitation), what hero icons Clear Skies currently has, what's missing, how to handle split/mixed forecasts, and how atmospheric obscuration conditions (smoke, dust, haze) should combine with cloud cover  
**Trigger:** Showers icon displayed for a forecast period with only 10% PoP  
**Deliverable:** Research brief only — no code changes

---

## Executive Summary

Clear Skies shows a rain/showers icon whenever the upstream provider (Open-Meteo) assigns a precipitation WMO code — **regardless of the PoP value.** There is no PoP threshold in our pipeline. The provider's `weatherCode` flows through opaquely from the API to the dashboard with no filtering or override based on precipitation probability.

This is architecturally different from every major weather service. The NWS, Weather.com, AccuWeather, and Apple Weather all gate precipitation icons behind a PoP floor — typically **20% or higher.** Below that, they show sky-condition icons (clear, partly cloudy, etc.) even if the model detects trace precipitation in its internals. Our current behavior — showing showers at 10% PoP — is more aggressive than any major service.

The audit also found that our 11 hero glyphs cover the basics but lack visual distinction for several conditions that other services treat as separate icons: freezing rain, sleet, wintry mix, hail, and "sun + precipitation" combinations. Additionally, the NWS provider's shortname codes (`"rain"`, `"sct"`, `"tsra"`) don't map through `toWmoCode()` and produce no icon at all — a bug if NWS is used as the forecast provider.

**Provider mapping deficiency (added 2026-07-14):** All three non-Open-Meteo providers (Aeris, NWS, OWM) send atmospheric obscuration conditions (smoke, dust, haze, volcanic ash) that we silently drop. OWM has an entire "Atmosphere" group (700-series condition IDs: mist, smoke, haze, dust, sand, ash, squall, tornado) that returns `null` from our mapping. Aeris codes `BD` (blowing dust), `K` (smoke), `H` (haze), `VA` (volcanic ash) are similarly unmapped. These conditions are sent **alongside** separate cloud cover fields — meaning providers give us both "what's in the atmosphere" and "how cloudy is it," which should drive combined icons (e.g., "partly cloudy + smoke") rather than standalone obscuration icons.

**Current conditions pipeline:** The API's conditions engine already derives WMO codes from station sensor data (pyranometer-based sky classification, rain gauge, fog/haze detection) and emits them to the same `WeatherIcon` component used by forecast. This pipeline is already unified at the code level. Any new icon added to `WMO_MAP` is automatically available to both forecast and current conditions.

---

## 1. Industry Research: How Major Services Select Forecast Icons

### 1.1 NWS (National Weather Service)

The NWS has the most thoroughly documented system. Their icon selection is built on three concepts: PoP ranges, verbal uncertainty expressions, and areal coverage terms.

**NWS PoP terminology and icon behavior:**

| PoP | Verbal Expression | Areal Coverage | Icon Behavior |
|-----|-------------------|----------------|---------------|
| 0% | No mention | — | Sky-condition icon only |
| 10% | Isolated (or no mention) | Isolated / Few | May or may not show precipitation in icon |
| 20% | "Slight Chance" | Isolated / Widely Scattered | Precipitation consistently appears in icon |
| 30–50% | "Chance" | Scattered | Precipitation icon shown |
| 60–70% | "Likely" | Numerous | Precipitation icon shown |
| 80–100% | No qualifier needed | Occasional / Periods of | Precipitation icon with no hedging text |

**Key takeaway:** The NWS shows precipitation icons consistently starting at **20% PoP** ("Slight Chance"). At 10%, an icon may or may not include precipitation depending on the weather type. Below 10%, precipitation is never depicted.

**Split forecasts:** When the PoP changes by ≥30 percentage points between the two 6-hour halves of a 12-hour period, the NWS shows **dual icons** side-by-side with an arrow (implemented July 2015). Text uses transitional phrasing: "Rain, then chance rain" or "Freezing rain today changing to rain after noon." This system handles both changing probability and changing precipitation type.

**Day/night:** NWS uses `/icons/land/day/` and `/icons/land/night/` URL paths. The API returns an `isDaytime` boolean. Night icons swap sun elements for moon/dark-sky backgrounds. Precipitation-only icons are identical day and night.

**Icon filename convention:** Codes like `skc` (clear), `few`, `sct`, `ovc`, `ra` (rain), `sn` (snow), `tsra` (thunderstorms), `fzra` (freezing rain), `mix` (wintry mix), `fg` (fog). PoP suffixes from 10–100 are appended (e.g., `ra30.jpg` for 30% chance of rain).

*Sources: [weather.gov/forecast-icons](https://www.weather.gov/forecast-icons), [weather.gov/bgm/forecast_terms](https://www.weather.gov/bgm/forecast_terms), [weather.gov/bmx/nwsterms](https://www.weather.gov/bmx/nwsterms), [weather.gov/eax/pointforecastdualimage](https://www.weather.gov/eax/pointforecastdualimage)*

### 1.2 Weather.com / The Weather Channel

Uses **48 icon codes** (0–47). Not publicly documented in detail, but their icon set reveals the approach:

- Separate codes for "Scattered Showers" (39/45 day/night) vs. "Showers" (11) vs. "Rain" (12) — implying graded icon selection by coverage/probability
- Explicit day/night variants for sky conditions (codes 27–34) and some precipitation (scattered thunderstorms, scattered showers, scattered snow showers)
- Dedicated mixed-precipitation icons: Rain/Snow (5), Rain/Sleet (6), Wintry Mix (7)

PoP threshold not officially documented. Weather.com's PoP definition includes precipitation amounts below 0.01 inch and extends ±3 hours from the forecast period — broader than NWS.

*Source: [developer.weather.com/docs/icon-codes-icon-images](https://developer.weather.com/docs/icon-codes-icon-images)*

### 1.3 AccuWeather

Uses **44 icon codes** (1–44 with gaps). Distinctive for combining sky condition + precipitation into single icons:

- "Partly Sunny w/ Showers" (14), "Mostly Cloudy w/ T-Storms" (16) — the icon encodes both cloud cover and precipitation type simultaneously
- Separate day (1–32) and night (33–44) code ranges
- Dedicated mixed: Rain and Snow (29)
- Uses proprietary "AccuPOP" at **3-hour granularity** (finer than NWS 12-hour periods)
- Returns `HasPrecipitation` boolean and `PrecipitationType` as separate fields alongside the icon code

*Source: [developer.accuweather.com/documentation/weather-icons](https://developer.accuweather.com/documentation/weather-icons)*

### 1.4 Apple Weather / WeatherKit (formerly Dark Sky)

Uses condition codes rather than numbered icons: `Clear`, `MostlyClear`, `PartlyCloudy`, `MostlyCloudy`, `Cloudy`, `Rain`, `HeavyRain`, `Drizzle`, `Snow`, `HeavySnow`, `Flurries`, `Thunderstorms`, `IsolatedThunderstorms`, `ScatteredThunderstorms`, `StrongStorms`, `FreezingRain`, `FreezingDrizzle`, `WintryMix`, `Sleet`, `Hail`, `Blizzard`, `BlowingSnow`, `SunShowers`, `SunFlurries`, `Foggy`, `Haze`, `Smoky`, `Breezy`, `Windy`, `BlowingDust`, `Frigid`, `Hot`, `Hurricane`, `TropicalStorm`.

**Notably:** Apple includes **combined sun+precipitation codes** (`SunShowers`, `SunFlurries`) as first-class conditions — handling mixed conditions at the data model level rather than through icon composition.

**Pirate Weather reverse-engineering of the Dark Sky algorithm:**
- Current conditions: precipitation icon when accumulation > 0.02 mm
- Hourly forecasts: precipitation icon when PoP > **25%** AND accumulation > 0.02 mm
- Daily forecasts: uses cumulative accumulation thresholds (0.25 mm for 1 period, 10 mm = heavy rain, 5 cm = heavy snow)

*Sources: [developer.apple.com/documentation/weatherkit/weathercondition](https://developer.apple.com/documentation/weatherkit/weathercondition), [docs.pirateweather.net](https://docs.pirateweather.net/en/latest/API/)*

### 1.5 Industry Consensus

| Provider | PoP floor for precipitation icon |
|----------|----------------------------------|
| NWS | 20% (consistent); 10% (occasional, isolated) |
| Dark Sky / Pirate Weather | 25% AND accumulation > 0.02 mm |
| Most commercial services | ~20–30% based on observed behavior |
| **Clear Skies (current)** | **0% — no threshold exists** |

**The de facto standard is 20% PoP** as the floor for showing a precipitation icon. Below 20%, services show sky-condition icons even when their models detect trace precipitation. Most services also apply a **two-factor test**: PoP must exceed the threshold AND expected accumulation must be non-trivial (> 0.01–0.02 mm).

---

## 2. Current Icon Audit

### 2.1 Glyph Inventory

All hero icons are inline Material Symbols SVGs with Meteocons-style gradient fills, implemented as React components in [weather-icon-glyphs.tsx](../../repos/weewx-clearskies-dashboard/src/components/weather-icon-glyphs.tsx).

| # | Glyph | Visual Description | Day/Night Variants |
|---|-------|--------------------|--------------------|
| 1 | `GlyphSunny` | Sun circle + 8 rays | Day only (night → `GlyphBedtime`) |
| 2 | `GlyphPartlyCloudy` | Cloud blob + sun behind | Day variant |
| 3 | `GlyphPartlyCloudyNight` | Cloud blob + crescent moon behind | Night variant |
| 4 | `GlyphCloud` | Single cloud blob | Same day/night |
| 5 | `GlyphFoggy` | Cloud + fog stripe dots | Same day/night |
| 6 | `GlyphRainy` | Cloud + 3 angled rain streaks | Same day/night |
| 7 | `GlyphSnowy` | Cloud + 6 snow dots | Same day/night |
| 8 | `GlyphThunderstorm` | Cloud + 2 lightning bolts | Same day/night |
| 9 | `GlyphBedtime` | Crescent moon (clear night) | Night only |
| 10 | `GlyphHazy` | Clipped sun (top) + amber haze stripes | Day variant |
| 11 | `GlyphHazyNight` | Clipped moon (top) + amber haze stripes | Night variant |

**Total: 11 distinct glyphs** mapping to **32 WMO codes** via the `WMO_MAP` in [weather-icon.tsx](../../repos/weewx-clearskies-dashboard/src/components/weather-icon.tsx).

### 2.2 WMO Code Mapping (complete)

| WMO Code | Condition | Glyph Used | Notes |
|----------|-----------|------------|-------|
| 0 | Clear sky | Sunny / Bedtime | Day/night variants |
| 1 | Mainly clear | PartlyCloudy | Day/night variants |
| 2 | Partly cloudy | PartlyCloudy | Day/night variants |
| 3 | Overcast | Cloud | — |
| 4* | Heavy overcast | Cloud | API extension |
| 5* | Haze | Hazy | Day/night variants; API extension |
| 10* | Mist | Foggy | API extension |
| 45 | Fog | Foggy | — |
| 48 | Depositing rime fog | Foggy | — |
| 51–55 | Drizzle (light→dense) | **Rainy** | No drizzle-specific glyph |
| 56–57 | Freezing drizzle | **Rainy** | No freezing-specific glyph |
| 61–65 | Rain (slight→heavy) | **Rainy** | No intensity distinction |
| 66–67 | Freezing rain | **Rainy** | No freezing-specific glyph |
| 71–75 | Snow (slight→heavy) | **Snowy** | No intensity distinction |
| 77 | Snow grains | **Snowy** | No distinct glyph |
| 79* | Sleet | **Snowy** | API extension; no sleet-specific glyph |
| 80–82 | Rain showers | **Rainy** | No showers-specific glyph |
| 85–86 | Snow showers | **Snowy** | No showers-specific glyph |
| 95 | Thunderstorm | Thunderstorm | — |
| 96, 99 | Thunderstorm + hail | **Thunderstorm** | No hail-specific glyph |

\* = Clear Skies API extension codes beyond standard WMO.

### 2.3 Gap Analysis: Missing Icons

Comparing against what major services provide as distinct icons:

| Condition | Our Status | NWS Has? | AccuWeather Has? | Apple Has? | Priority |
|-----------|-----------|----------|------------------|------------|----------|
| **Freezing rain** | Uses `GlyphRainy` (no distinction) | Yes (`fzra`) | Yes (code 26) | Yes (`FreezingRain`) | **High** — safety-critical; visitors need to see freezing precip is different from rain |
| **Sleet / ice pellets** | Uses `GlyphSnowy` (no distinction) | Yes (`ip`) | Yes (code 25) | Yes (`Sleet`) | **High** — safety-critical |
| **Wintry mix** (rain+snow) | No icon at all | Yes (`mix`) | Yes (code 29) | Yes (`WintryMix`) | **High** — common transitional condition |
| **Smoke** | Silently dropped from providers; station haze detection maps smoke→haze | Yes (`smoke`) | No | Yes (`Smoky`) | **High** — SoCal wildfire smoke is common; needs cloud-cover variants (see §2.6) |
| **Dust / blowing dust** | Silently dropped from all providers | Yes (`dust`) | No | Yes (`BlowingDust`) | **Medium** — regional but important where it occurs; needs cloud-cover variants (see §2.6) |
| **Hail** | Uses `GlyphThunderstorm` (no distinction) | Implied via text | No distinct icon | Yes (`Hail`) | Medium — always with thunderstorms; text may suffice |
| **Sun + showers** (sun still visible) | No icon | No | Yes ("Partly Sunny w/ Showers") | Yes (`SunShowers`) | Medium — AccuWeather's signature; nice for low-PoP periods |
| **Sun + flurries** | No icon | No | Yes ("Partly Sunny w/ Flurries") | Yes (`SunFlurries`) | Low — same concept as sun+showers |
| **Drizzle** (visually lighter than rain) | Uses `GlyphRainy` | No distinct icon | No distinct icon | Yes (`Drizzle`) | Low — most services don't distinguish |
| **Heavy rain** (visually heavier) | Uses `GlyphRainy` | No distinct icon | No distinct icon | Yes (`HeavyRain`) | Low — intensity conveyed via text |
| **Windy** | No icon | Yes (`wind`) | Yes (code 32) | Yes (`Windy`) | Low — debatable as a "weather" icon |
| **Hot / Cold** | No icon | Yes (`hot`/`cold`) | Yes (codes 30–31) | Yes (`Hot`/`Frigid`) | Low — temperature, not weather condition |

### 2.4 Bugs Found During Audit

**Bug 1: NWS weatherCode shortnames are not mapped.** The NWS provider passes icon shortnames like `"rain"`, `"sct"`, `"tsra"` as `weatherCode` strings. In the dashboard, `parseInt("rain", 10)` returns `NaN`, which is not in `WMO_MAP` → **no icon renders.** The `toWmoCode()` function only handles Aeris code format and raw WMO integers. If NWS is configured as the forecast provider, all forecast periods show blank icons.

**Bug 2: OWM condition IDs are not mapped.** OpenWeatherMap uses its own numeric IDs (200–804 range), not WMO codes. A string like `"500"` would parse as integer 500, which is not in `WMO_MAP` → no icon renders.

**Bug 3: Four API-extension WMO codes (4, 5, 10, 79) have no test coverage** in [weather-icon.test.tsx](../../repos/weewx-clearskies-dashboard/src/components/weather-icon.test.tsx). The test suite exercises 28 of the 32 mapped codes.

### 2.5 Provider Atmosphere Condition Mapping Deficiency

All three non-Open-Meteo providers send atmospheric obscuration conditions that we silently drop. These conditions return `null` from our mapping functions and produce no icon.

**What each provider sends (and we drop):**

| Provider | Code Format | Conditions Sent | Where Dropped |
|----------|-------------|-----------------|---------------|
| **Aeris/Xweather** | `weatherPrimaryCoded` string | `K` (smoke), `BD` (blowing dust), `BS` (blowing snow), `BY` (blowing spray), `H` (haze), `VA` (volcanic ash) | `AERIS_TO_WMO` in `weather-code.ts` — no entries for these codes |
| **NWS** | Icon URL shortname | `smoke`, `dust`, `haze`, `hot`, `cold`, `wind_skc/few/sct/bkn/ovc`, `blizzard`, `tornado`, `hurricane`, `tropical_storm` | `toWmoCode()` — NWS shortnames not handled at all (Bug 1) |
| **OWM** | Condition ID (integer) | 701 (Mist), 711 (Smoke), 721 (Haze), 731 (Sand/Dust whirls), 741 (Fog), 751 (Sand), 761 (Dust), 762 (Volcanic ash), 771 (Squall), 781 (Tornado) | `parseInt()` produces IDs outside `WMO_MAP` range (Bug 2) |
| **Open-Meteo** | WMO integer | **Does not send atmosphere obscuration codes.** WMO 0–99 has no codes for smoke, dust, haze, sand. Open-Meteo users will never see these conditions from the provider — only from the API's own conditions engine (current conditions only). | N/A |

**Impact:** Any operator using Aeris, NWS, or OWM as their forecast provider will see blank icons when smoke, dust, haze, or other atmosphere conditions are the dominant weather. This is a data-loss bug, not just a missing-icon cosmetic issue.

**What the API conditions engine handles (current conditions only):**
The API's `_derive_weather_code()` already produces WMO extension code 5 (haze) from station sensors (Kcs deficit + PM2.5/PM10) and defers to provider `weatherText` keywords ("smoke", "hazy") at night. Smoke detected this way maps to haze (code 5). There is no station-based dust detection — dust would only come from provider codes, which we currently drop.

### 2.6 Atmospheric Obscuration Icons Need Cloud-Cover Combinations

Providers send atmosphere conditions (smoke, dust, haze) **alongside** separate cloud cover data — not as a replacement for sky condition:

- **OWM:** `weather[0].id` = 711 (Smoke) **+** `clouds.all` = 30 (cloud cover %)
- **Aeris:** `weatherPrimaryCoded` = `::K` (smoke) **+** `cloudsCoded` = "SC" **+** `sky` = 25 (cloud cover %)
- **NWS:** Compound icon URLs: `/icons/land/day/sct/smoke` (scattered clouds + smoke)

This means we have both "what's in the atmosphere" and "how cloudy is it" as independent fields. The correct icon should reflect both — light smoke over a mostly clear SoCal sky is a visually different condition from heavy smoke obscuring the sky entirely.

**The cloud-cover × atmosphere-condition matrix:**

| Cloud Cover | Smoke | Dust | Haze |
|------------|-------|------|------|
| Clear (0–25%) | ☀️+smoke | ☀️+dust | ☀️+haze *(existing: `GlyphHazy`)* |
| Partly cloudy (25–50%) | ⛅+smoke | ⛅+dust | ⛅+haze *(missing)* |
| Mostly cloudy / overcast (50%+) | ☁️+smoke | ☁️+dust | ☁️+haze *(missing)* |

Day/night variants are needed for the clear and partly cloudy tiers (sun vs. moon), same as existing `GlyphHazy`/`GlyphHazyNight`. The overcast tier doesn't need day/night variants (no celestial body visible).

**Note on haze:** Our current `GlyphHazy` only covers the clear-sky case (sun+haze stripes, moon+haze stripes). It needs the same cloud-cover variant treatment as smoke and dust. This means haze also needs "partly cloudy + haze" and "overcast + haze" icons that we don't have today.

**Icon design approach:** Use the Meteocons combined cloud-cover + obscuration icons as the visual reference, then build them as Material Symbols SVG components with our gradient treatment (same process used for the existing 11 glyphs per ADR-049).

**Selection logic for atmosphere conditions:**

```
If atmosphere condition is present (smoke/dust/haze):
  1. Read cloud cover from the same provider response
  2. Pick the cloud-cover tier: clear (0–25%), partly cloudy (25–50%), cloudy (50%+)
  3. Pick the day/night variant (clear and partly cloudy tiers only)
  4. Select the combined icon: e.g., "partly cloudy night + smoke"
```

For the API's current conditions engine, the same logic applies but using station-derived sky classification + the detected atmosphere condition.

---

## 3. The Root Cause: No PoP Gate on Icon Selection

### 3.1 Current Pipeline

The forecast icon pipeline is:

```
Provider (Open-Meteo/NWS/Aeris/OWM)
  ↓ assigns weatherCode based on internal model
API passes weatherCode through as opaque string
  ↓ no filtering, no PoP check
Dashboard toWmoCode() normalizes to WMO integer
  ↓ no PoP check
WeatherIcon renders glyph from WMO_MAP
```

**PoP is a completely separate field.** It influences the GFE text engine's verbal phrases ("slight chance of showers" vs. "showers likely") but has zero effect on which icon is displayed.

### 3.2 Why This Is Wrong

Open-Meteo's `weather_code` and `precipitation_probability` are independent forecast variables from their model. Open-Meteo may assign WMO code 80 ("Slight rain showers") to an hour based on its internal atmospheric model even when the PoP for that hour is 10%. Their model is saying "if precipitation occurs, it would be shower-type" — but the dashboard interprets that as "showers ARE occurring" by showing the showers icon.

Every major weather service resolves this tension by applying a PoP gate: "don't show a precipitation icon unless there's a meaningful probability that it will actually precipitate." Without this gate, the icon overstates the forecast.

### 3.3 Where PoP Thresholds DO Exist (Text Only)

The GFE text engine in the API ([thresholds.py](../../repos/weewx-clearskies-api/weewx_clearskies_api/sse/gfe/thresholds.py)) already has well-calibrated thresholds, but these only affect the text narrative — not the icon:

| Threshold | Value | Effect |
|-----------|-------|--------|
| `POP_LOWER_THRESHOLD` | 15% | Below this, weather type is NOT mentioned in text (first 24h) |
| `POP_LOWER_THRESHOLD_EXTENDED` | 25% | Same suppression for extended-range periods |
| `POP_WX_LOWER_THRESHOLD` | 20% | PoP-related weather types suppressed in phrasing below this |
| `POP_SKY_LOWER_THRESHOLD` | 55% | When PoP ≥ 55%, sky phrase is omitted (precip dominates text) |
| `POP_SNOW_LOWER_THRESHOLD` | 60% | Snow accumulation phrasing requires PoP ≥ 60% |

These thresholds follow the NWS pattern closely and are already correct. The icon system just doesn't use them.

---

## 4. Handling Split / Mixed Forecasts

### 4.1 What "Split Forecast" Means

A split forecast occurs when a single forecast period (e.g., "Today", "Tonight") has either:
- **Changing probability:** PoP rises or falls significantly within the period (e.g., 20% morning → 60% afternoon)
- **Changing type:** precipitation type transitions (e.g., rain in the morning → snow in the afternoon)
- **Mixed type:** multiple precipitation types simultaneously (e.g., wintry mix of rain and snow)

### 4.2 Industry Approaches

| Approach | Who Uses It | How It Works |
|----------|-------------|--------------|
| **Dual icons** | NWS | Two icons side-by-side with an arrow when PoP changes by ≥30 points between 6-hour halves. Handles both probability and type transitions. |
| **Combined condition codes** | Apple/WeatherKit | First-class codes for mixed states: `WintryMix`, `SunShowers`, `SunFlurries`. The data model encodes the combination. |
| **Composite icons** | AccuWeather | Single icons that combine sky + precipitation: "Partly Sunny w/ Showers". Sky condition and precip type are visible simultaneously. |
| **Sub-period granularity** | Weather.com, AccuWeather | Rely on hourly/3-hour forecasts so the user sees the transition across time blocks rather than needing one icon to represent it. |
| **Dedicated mixed icons** | Weather.com, NWS | Specific icon codes for Rain/Snow, Rain/Sleet, Wintry Mix — used when simultaneous mixed precipitation is expected. |

### 4.3 Our Current State

Clear Skies has:
- **Hourly forecasts** (which naturally handle split probability by showing a different icon each hour)
- **Daily forecasts** that use a single `weatherCode` from the provider — the day's "dominant" condition
- **No dual-icon capability** for daily summaries
- **No combined sky+precipitation icons** (e.g., no "partly cloudy with showers")
- **No mixed-precipitation icons** (no wintry mix, rain+snow, etc.)

The GFE text engine already handles split forecasts well in prose — it generates text like "Slight chance of showers in the morning, then showers likely in the afternoon" by analyzing the 6-hour sub-period PoPs. The gap is purely visual (the icon).

---

## 5. Recommendations

### 5.1 Add a PoP Gate to Icon Selection (High Priority)

**Recommendation:** When PoP is below 20%, suppress the precipitation icon and show a sky-condition icon instead — derived from cloud cover.

This aligns with the NWS "Slight Chance" threshold and matches the GFE text engine's existing `POP_WX_LOWER_THRESHOLD` of 20%. The logic would be:

```
If weatherCode indicates precipitation AND PoP < 20%:
  → Show sky-condition icon based on cloudCover instead
     (0–25% → clear, 25–50% → partly cloudy, 50–87% → mostly cloudy, 87–100% → overcast)
Else:
  → Show the provider's weatherCode icon as today
```

**Where to implement:** This should be a dashboard-side decision, not API-side. The API should continue passing the provider's raw `weatherCode` and `precipProbability` (or `precipProbabilityMax` for daily). The dashboard's `WeatherIcon` component (or a wrapper) applies the gate using both fields. This keeps the API as a general-purpose data layer (per ADR-010) while letting the dashboard make the presentation decision.

**Open question: Should the threshold be 15% or 20%?** The GFE text engine uses 15% for first-24h and 20% for weather-specific suppression. The NWS uses 20% as the "Slight Chance" floor. AccuWeather and Dark Sky use ~25%. Starting at 20% is the safest default — it matches NWS and our own text engine's `POP_WX_LOWER_THRESHOLD`.

### 5.2 Add Wintry Mix Glyph (High Priority)

One new precipitation glyph consolidates freezing rain, sleet, and wintry mix into a single icon:

**`GlyphWintryMix`** — Cloud (grey gradient) + rain streaks (rain gradient, angled) + snowflake/dot shapes (snow gradient), all falling from the same cloud. Uses the existing split-path technique with three path groups:
- Cloud body → `greyGrad` + `CLOUD_STROKE` (reuse existing cloud path from `GlyphRainy`)
- Rain streaks → `rainGrad` (subset of existing rain paths — fewer streaks to leave room for snow)
- Snow shapes → `snowGrad` (subset of existing snow dot paths — interspersed with rain)

**Serves all icy/mixed precipitation WMO codes:**
- 56–57: Freezing drizzle (light, dense)
- 66–67: Freezing rain (light, heavy)
- 79: Sleet / ice pellets (API extension)
- Rain+snow wintry mix (when providers send mixed type)

**Design rationale:** Freezing rain is visually indistinguishable from regular rain while falling — the "freezing" happens on contact with the ground. Sleet is already a rain+ice mix. A single icon showing rain+snow together communicates "icy mixed precipitation" for all three conditions. The specific type (freezing rain vs. sleet vs. wintry mix) is conveyed by the text label from the GFE text engine, which already handles this well.

**No day/night variants needed** — same as existing rain and snow glyphs (no celestial body in the icon).

### 5.3 Add Combined Sky+Precipitation Icons (Medium Priority)

AccuWeather's approach of showing "Partly Cloudy w/ Showers" is more informative than our current binary (either pure sky or pure precipitation). This matters most at moderate PoP values (20–50%) where the sky is still partly visible. These icons work directly with the PoP gate (§5.1) to show the intermediate state between "just clouds" and "full precipitation."

**6 new glyphs — partly cloudy base + precipitation, with day/night variants:**

| Glyph | Day Base | Night Base | Precipitation Element |
|-------|----------|------------|----------------------|
| `GlyphPartlyCloudyRainDay` | `GlyphPartlyCloudy` paths | — | Rain streaks (`rainGrad`) |
| `GlyphPartlyCloudyRainNight` | — | `GlyphPartlyCloudyNight` paths | Rain streaks (`rainGrad`) |
| `GlyphPartlyCloudySnowDay` | `GlyphPartlyCloudy` paths | — | Snow dots (`snowGrad`) |
| `GlyphPartlyCloudySnowNight` | — | `GlyphPartlyCloudyNight` paths | Snow dots (`snowGrad`) |
| `GlyphPartlyCloudyWintryMixDay` | `GlyphPartlyCloudy` paths | — | Rain streaks + snow dots (`rainGrad` + `snowGrad`) |
| `GlyphPartlyCloudyWintryMixNight` | — | `GlyphPartlyCloudyNight` paths | Rain streaks + snow dots (`rainGrad` + `snowGrad`) |

**Implementation:** Purely additive composition — take the existing `GlyphPartlyCloudy` / `GlyphPartlyCloudyNight` SVG paths (cloud + sun/moon) and add the precipitation paths from `GlyphRainy` / `GlyphSnowy` / `GlyphWintryMix` underneath the cloud. All existing gradients reused, all existing path data reused, just composed together in a single `<svg>`.

**Selection logic (works with the PoP gate):**
- PoP < 20% → sky-condition icon only (§5.1 gate)
- PoP 20–50% AND cloud cover < 75% → combined sky+precipitation icon (this section)
- PoP > 50% OR cloud cover ≥ 75% → precipitation-only icon (existing `GlyphRainy` / `GlyphSnowy` / `GlyphWintryMix`)

### 5.4 Fix Provider Code Mapping Bugs (High Priority, Separate Task)

1. **Add NWS shortname mapping** to `toWmoCode()` or as a parallel `NWS_TO_WMO` table. NWS shortnames: `skc`→0, `few`→1, `sct`→2, `bkn`→3, `ovc`→3, `fg`→45, `ra`→61, `sn`→71, `tsra`→95, `fzra`→66, `mix`→79, `ip`→67, `dust`→(new dust code), `smoke`→(new smoke code), `haze`→5, `hot`→0, `cold`→0, `wind_skc`→0, `wind_few`→1, `wind_sct`→2, `wind_bkn`→3, `wind_ovc`→3.
2. **Add OWM condition ID mapping** — the full 200–804 range to WMO codes, including the Atmosphere group: 701→10 (mist), 711→(new smoke code), 721→5 (haze), 731/761→(new dust code), 741→45 (fog), 751→(new dust code), 762→(new ash code or dust), 771→(squall, TBD), 781→(tornado, TBD).
3. **Add Aeris atmosphere code mapping** — `K`→(new smoke code), `BD`→(new dust code), `H`→5 (haze), `BS`→(blowing snow, TBD), `VA`→(new ash code or dust).
4. **Add test coverage** for WMO extension codes 4, 5, 10, 79 and all new atmosphere codes.

**Note:** Dust, smoke, and other atmosphere conditions need new API extension WMO codes (similar to existing extensions 4, 5, 10, 79). Proposed assignments:

| Proposed Code | Condition | Rationale |
|---------------|-----------|-----------|
| 5 | Haze | Already assigned (API extension) |
| 6* | Smoke | New — distinct from haze (wildfire smoke vs. PM-based haze) |
| 7* | Dust / blowing dust | New — sand/dust storms |
| 8* | Volcanic ash | New — rare but safety-critical |

\* = Proposed new API extension codes. These don't conflict with standard WMO (which uses 4–9 for historical present-weather codes that Open-Meteo doesn't emit).

### 5.5 Add Atmosphere Condition × Cloud Cover Icons (High Priority)

Smoke, dust, and haze need combined icons that show both the atmospheric condition and the sky state. Providers send both pieces of data in every response (see §2.6). The existing `GlyphHazy` (clear sky + haze) is the prototype — this extends the pattern to all three conditions across cloud-cover tiers.

**Required icon matrix (Meteocons-style visual reference):**

| Atmosphere Condition | Clear Sky (day) | Clear Sky (night) | Partly Cloudy (day) | Partly Cloudy (night) | Overcast |
|---------------------|-----------------|-------------------|--------------------|-----------------------|----------|
| **Haze** | ✅ `GlyphHazy` | ✅ `GlyphHazyNight` | ❌ Missing | ❌ Missing | ❌ Missing |
| **Smoke** | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing | ❌ Missing |
| **Dust** | ❌ Missing (standalone) | ❌ Missing (standalone) | N/A (uses dust standalone) | N/A (uses dust standalone) | ❌ Missing (standalone) |

**Total new glyphs needed:** ~14 (see per-condition breakdown below).

**Per-condition design approach (informed by Meteocons visual reference):**

Each condition uses a DIFFERENT composition technique. This was determined by examining how Meteocons handles each condition — the approaches differ because the visual characteristics of haze, smoke, and dust are fundamentally different.

#### Dust — Standalone icons (3 glyphs)

Meteocons treats dust as a standalone condition with three variants: `dust` (generic/cloudy), `dust-day` (sun visible), `dust-night` (moon visible). Dust is NOT combined with cloud-cover icons — the dust effect IS the whole icon. This is the right call because dust particles would visually clutter if overlaid on cloud shapes.

| Glyph | When Used | Visual |
|-------|-----------|--------|
| `GlyphDustDay` | Cloud cover 0–50%, daytime | Dust with sun visible |
| `GlyphDustNight` | Cloud cover 0–50%, nighttime | Dust with moon visible |
| `GlyphDust` | Cloud cover 50%+, or default | Just dust, no celestial body |

**New gradient needed:** earth-tone tan/brown for dust particles.

#### Smoke — Overlay on existing sky icons (5 glyphs)

Meteocons combines smoke with each cloud-cover level. Smoke "bubbles" (rounded wisps/puffs) are **superimposed on top of** the existing sky condition icons. This is NOT the cutout/clip approach used for haze — the underlying icon stays intact and the smoke is an additional visual layer on top. This keeps the icons readable because smoke wisps are visually distinct from the cloud/sun/moon shapes underneath.

| Glyph | When Used | Visual |
|-------|-----------|--------|
| `GlyphSmokeDay` | Clear sky, daytime | Sun icon + smoke bubbles overlaid |
| `GlyphSmokeNight` | Clear sky, nighttime | Moon icon + smoke bubbles overlaid |
| `GlyphSmokePartlyCloudyDay` | Partly cloudy, daytime | Partly cloudy icon + smoke bubbles overlaid |
| `GlyphSmokePartlyCloudyNight` | Partly cloudy, nighttime | Partly cloudy night icon + smoke bubbles overlaid |
| `GlyphSmokeOvercast` | Mostly cloudy / overcast | Cloud icon + smoke bubbles overlaid |

**New gradient needed:** darker grey than clouds for smoke wisps (so they're visually distinct from the cloud gradient).

**Implementation note:** Smoke bubbles are additional SVG path groups layered on top of the existing glyph paths. The existing sun/cloud/moon paths are reused verbatim — only the smoke overlay paths are new. This could potentially be implemented as a compositing wrapper rather than 5 entirely separate glyph components.

#### Haze — Cutout approach, extend existing pattern (3 new glyphs)

Haze keeps the existing cutout/clip technique (sun/moon clipped at a boundary with haze stripes below). The clear-sky variants already exist (`GlyphHazy`, `GlyphHazyNight`). Need to extend to partly cloudy and overcast:

| Glyph | When Used | Visual | Status |
|-------|-----------|--------|--------|
| `GlyphHazy` | Clear sky, daytime | Clipped sun + amber haze stripes | ✅ Exists |
| `GlyphHazyNight` | Clear sky, nighttime | Clipped moon + amber haze stripes | ✅ Exists |
| `GlyphHazyPartlyCloudyDay` | Partly cloudy, daytime | Clipped partly cloudy day icon + amber haze stripes | ❌ Missing |
| `GlyphHazyPartlyCloudyNight` | Partly cloudy, nighttime | Clipped partly cloudy night icon + amber haze stripes | ❌ Missing |
| `GlyphHazyOvercast` | Mostly cloudy / overcast | Clipped cloud + amber haze stripes | ❌ Missing |

**Existing gradient reused:** `hazeGrad` (`#CDAA6D` → `#A07840`).

**Selection logic:** When the provider sends an atmosphere condition, check the cloud cover field from the same response to pick the correct combined icon (see §2.6 for the full algorithm).

### 5.6 Split Forecast Display for Daily Summaries (Medium Priority, Deferred)

For daily forecast columns, when the PoP changes significantly across the day (e.g., morning vs. afternoon), consider a visual indicator. Options from simplest to most complex:

1. **Text annotation only** — the GFE text engine already handles this well
2. **PoP badge on the icon** — small "60%" overlay on the icon corner (Weather.com style)
3. **Dual mini-icons** — NWS-style side-by-side icons for the halves of the day

Recommendation: Start with option 1 (rely on GFE text) for v1. The hourly forecast strip already shows the transition visually. Dual icons add complexity for marginal benefit when hourly data is available.

### 5.7 Day/Night Handling for Precipitation Icons (Low Priority)

Currently, precipitation icons (rain, snow, thunderstorm, fog) look identical day and night. This is the most common approach — NWS, AccuWeather, and Weather.com all share precipitation icons across day/night. Only sky-condition icons (clear, partly cloudy) need celestial-body variants. Our current approach is correct and standard.

---

## 6. Summary of Prioritized Actions

| # | Action | Priority | Scope | Status |
|---|--------|----------|-------|--------|
| 1 | Add PoP gate (≥20%) to icon selection in dashboard | **High** | Dashboard `WeatherIcon` or wrapper | **Done** — `selectWeatherIcon()` in `icon-selection.ts` |
| 2 | Fix NWS shortname → WMO mapping in `toWmoCode()` | **High** | Dashboard `weather-code.ts` | **Done** — `NWS_TO_WMO` table with 23 shortnames |
| 3 | Fix OWM condition ID → WMO mapping (including 700-series Atmosphere group) | **High** | Dashboard `weather-code.ts` | **Done** — `OWM_TO_WMO` table covering 200–804 |
| 4 | Fix Aeris atmosphere code mapping (`K`, `BD`, `H`, `BS`, `VA`) | **High** | Dashboard `weather-code.ts` | **Done** — added `K`, `BD`, `H`, `BS`, `BY`, `VA`, `WM`, `RS`, `SI` |
| 5 | Add wintry mix glyph (covers freezing rain + sleet + rain/snow mix) | **High** | Dashboard `weather-icon-glyphs.tsx` | **Done** — `GlyphWintryMix` (WMO 56, 57, 66, 67, 79) |
| 6 | Add smoke overlay icons (5 glyphs: smoke bubbles overlaid on existing sky icons) | **High** | Dashboard `weather-icon-glyphs.tsx` | **Done** — 5 smoke SVG files |
| 7 | Add dust standalone icons (3 glyphs: dust, dust-day, dust-night) | **High** | Dashboard `weather-icon-glyphs.tsx` | **Done** — 3 dust SVG files |
| 8 | Add missing haze cloud-cover variants (3 glyphs: partly cloudy day/night + overcast) | **High** | Dashboard `weather-icon-glyphs.tsx` | **Done** — 3 haze SVG files |
| 9 | Define new API extension WMO codes for smoke, dust, volcanic ash | **High** | API + Dashboard coordination | **Done** — codes 6 (smoke), 7 (dust), 8 (ash) in API + dashboard |
| 10 | Add combined sky+precipitation glyphs (6 glyphs: partly cloudy + rain/snow/mix × day/night) | **High** | Dashboard `weather-icon-glyphs.tsx` | **Done** — 6 combined SVG files |
| 11 | Add test coverage for WMO codes 4, 5, 10, 79 + all new codes | **High** | Dashboard tests | **Done** — 234 tests (weather-icon + icon-selection) |
| 12 | Split forecast display for daily summaries | Medium | Deferred to later phase | Deferred |
| 13 | Intensity-specific glyphs (heavy rain, drizzle) | Low | Future enhancement | **Done** — `GlyphDrizzle` added (WMO 51–55) |
| — | ~~Wind glyph~~ | **Excluded** | No provider sends "windy" as a dominant weather condition. Open-Meteo has no wind WMO code, Aeris has no wind weather code, OWM only has 771 (Squall). NWS has `wind_*` shortnames but only for advisory-level winds, which the alert system already covers. If a provider adds wind as a condition in the future, the design approach would be standalone icons like dust (wind-day, wind-night, wind-overcast) — partly cloudy + wind is too visually complex. |
| — | ~~Hot/Cold glyphs~~ | **Excluded** | Temperature is already displayed numerically; a thermometer icon next to a number is redundant. Extreme heat/cold are covered by the alert system. |

**Icon count impact:** Current 11 glyphs → 32 glyphs (32 SVG files in `public/icons/`). Breakdown of 21 new glyphs:
- Sky conditions: mostly cloudy day/night (2) = **2**
- Atmosphere conditions: smoke overlays (5) + dust standalone (3) + haze cloud-cover variants (3) = **11**
- Precipitation: wintry mix (1) + drizzle (1) = **2**
- Combined sky+precipitation: partly cloudy + rain/snow/mix × day/night (6) = **6**

---

## 7. Reference: Provider PoP Terminology

For context, the verbal descriptions services attach to PoP ranges:

| PoP % | NWS Expression | Common Display | Clear Skies GFE Text |
|-------|----------------|----------------|---------------------|
| 0% | No mention | — | Suppressed |
| 10% | Isolated | 10% | Suppressed (below 15% threshold) |
| 15–19% | Slight Chance | 15–19% | "Slight chance" (first 24h) / suppressed (extended) |
| 20–24% | Slight Chance | 20–24% | "Slight chance" |
| 25–29% | Chance | 25–29% | "Chance" (extended threshold kicks in) |
| 30–50% | Chance | 30–50% | "Chance" |
| 55–74% | Likely | 55–74% | "Likely"; sky phrase omitted |
| 75–100% | (no qualifier) | 75–100% | Separated into own phrase |

Most commercial services display the raw percentage (e.g., "30%") rather than verbal descriptors. The NWS verbal terminology is specific to government forecasts.
