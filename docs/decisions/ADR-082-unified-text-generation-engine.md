---
status: Accepted
date: 2026-07-05
deciders: shane
supersedes:
superseded-by:
---

# ADR-082: NWS GFE Text Generation System with WorldCast Technology

## Context

The current conditions text engine (`text_generator.py`, `conditions_text.py`, `enrichment/weather_text.py`) uses a narrower rule set than the NWS GFE (Graphical Forecast Editor) system. Specific gaps:

- **Temperature:** "Temperature near 85 degrees" — no decade phrasing ("in the mid 80s"), no exception table for zero-crossing or sub-zero, no extended forecast ranges, no trend detection ("temperatures falling into the 50s in the afternoon").
- **Wind:** "South winds around 8 mph" — no transition connectors ("shifting to the northwest", "increasing to"), no scalar/vector distinction, no marine wind descriptors (gales, storm force, hurricane force).
- **Precipitation:** "Light Rain" — no coverage language (16 NWS coverage levels from "isolated" to "definite"), no PoP (probability of precipitation) qualification ("chance of rain 40 percent"), no conjunction logic ("rain and snow", "rain with possible thunderstorms"), no serial comma rule.
- **Sky:** Basic cloud cover mapping — no adjacent-transition suppression ("mostly sunny" → "partly sunny" is suppressed as too similar), no PoP-based sky suppression (omit sky when PoP ≥ 55%).
- **No forecast text at all** — `/api/v1/forecast` returns provider-sourced `narrative`/`detailedForecast` for NWS, and nothing for Open-Meteo/Xweather/OWM.

Building a separate forecast text engine alongside the current conditions engine creates two systems producing different-quality text for the same vocabulary. The forecast engine needs the full GFE rule set; the current conditions engine should use it too.

The GFE source code is public domain (17 USC §105 — US government work, hosted at `github.com/Unidata/awips2`). The full analysis of ~10,800 lines across 6 core files plus 3 formatter examples is at `docs/reference/nws-text-system/gfe-source-code-analysis.md`.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| A: Unified GFE-derived engine (chosen) | Faithful port of NWS threshold tables + phrase logic; one engine serves current + forecast; full i18n from day one; no vocabulary divergence between current and forecast text; public-domain source eliminates licensing risk | Larger up-front build (14 new modules); requires faithful GFE source study; must adapt grid-based GFE model to single-station use |
| B: Separate current/forecast engines | Smaller initial scope per engine; current engine can ship without forecast changes | Duplicates vocabulary and threshold tables; two systems to maintain; forecast/current text quality diverges over time; double the i18n surface |
| C: LLM-generated text | No threshold-table porting; flexible phrasing; could handle any language | Non-deterministic — same inputs produce different text on each call; can't guarantee correctness for safety-critical weather text; per-request latency (~1-3s) and API cost; no offline operation; hallucination risk with numeric weather values |

## Decision

Replace `text_generator.py` and `conditions_text.py` with a single GFE-derived text generation engine. The engine handles both current observations (single-instant input via `observation_model.py`) and forecast periods (day/night aggregated input from provider hourly data). It ports GFE threshold tables and phrase logic faithfully from the public-domain AWIPS-II source and extends the existing i18n infrastructure to cover all forecast vocabulary.

**Brand:** "NWS GFE Text Generation System with WorldCast Technology" in all documentation. WorldCast refers to the i18n expansion beyond GFE's French/Spanish to 13 locales with proper sentence structure per locale. Not a legal brand.

**Scope boundary:** Builds the text engine and all threshold tables (including marine and fire weather). Does NOT build marine or fire weather provider modules (separate plan). Does NOT touch dashboard rendering (separate plan).

### Settled decisions

**1. Period convention.** NWS 6am/6pm fixed periods. "Today" = 6am–6pm local time, "Tonight" = 6pm–6am local time. Sunrise/sunset are used for day/night VOCABULARY selection only — e.g., cloud cover < 25% produces "Sunny" during daytime and "Mostly Clear" at nighttime (per the sky 6-bucket table below). Sunrise/sunset do NOT define period boundaries.

**2. Branding.** "NWS GFE Text Generation System with WorldCast Technology" in documentation.

**3. SkyPyEye Technology.** The pyranometer sky classification system is rebranded from "CAELUS" to "SkyPyEye Technology" across all active code and documentation. The CAELUS library (`github.com/jararias/caelus`) remains as a cited research reference. Completed as Phase 0 prerequisite.

**4. i18n architecture.** Extends the existing 13-locale JSON file + custom composer module system. Two modes:

- **Template mode (9 locales):** de, es, fr, it, nl, pt-BR, pt-PT, ru, fil. Locale JSON files carry all translated strings. Romance languages (es, fr, it, pt-BR, pt-PT) include gender/number-coded forms for weather type modifiers using the GFE `Translator.py` pattern: each weather type has a gender code (MS = masculine singular, MP = masculine plural, FS = feminine singular, FP = feminine plural), and each coverage/intensity adjective carries 4 inflected forms indexed by gender code. Russian carries case-inflected forms (nominative/instrumental/genitive). Filipino uses English per PAGASA convention. German and Dutch follow DWD/KNMI conventions respectively.

- **Custom mode (3 locales):** ja, zh-CN, zh-TW. Custom composer modules produce locale-native sentence structure that cannot be achieved through string substitution. Japanese: JMA-style temporal operators (tokidoki = 時々, ichiji = 一時, nochi = のち). Chinese: CMA/CWA-style structured fields.

**New i18n function:** `t_inflected(key, gender_code, locale)` — when the value at `key` is a dict of gender_code → string, returns the matching form. When plain string, returns unchanged. Follows existing `t()` resolution chain.

**5. Marine.** Build GFE §17 threshold tables and phrase templates only. No marine provider module in this scope. Tables are stable data that prevent re-reading GFE source later.

**6. Fire weather — tiered activation.**
- Tier 1 (active now): Humidity recovery (uses `outHumidity` from Xweather/Open-Meteo/OWM) + LAL heuristic (derived from weather codes + coverage level).
- Tier 2 (tables built, inactive): Haines Index — requires Open-Meteo pressure-level variables not yet fetched.
- Tier 3 (tables built, inactive): Smoke Dispersal / VentRate — requires boundary layer height + pressure-level wind data.
- All threshold tables are built now; what activates depends on available provider data.

**7. NWS pass-through.** When the operator selects NWS as the forecast provider, the `detailedForecast` field is passed through directly to the response. The text engine is NOT invoked. English only. Reason: NWS does not provide granular hourly forecast data through its public API — the `/gridpoints/{office}/{x},{y}/forecast` endpoint returns pre-composed period narratives, not the gridded data the engine needs.

**8. Forecast verbosity.** One level for forecast periods, matching GFE's single narrative product per period. Current observations retain three tiers (terse/standard/verbose).

**9. GFE code reuse directive.** Agents MUST study the GFE source code analysis document and port algorithms faithfully. Do not reinvent what NWS already wrote and tested. Replicate the GFE's structure, threshold values, and decision logic. The GFE source is the reference implementation — our code adapts it for single-station use and extends it for 13 locales, but the core algorithms stay faithful to the original.

**10. WU removal.** The Weather Underground provider is removed as a Phase 0 prerequisite (insufficient data quality). Completed.

**11. Hybrid wind scale.** Below 30 mph: Beaufort labels (Calm through Strong Breeze). At 30 mph and above: GFE/NWS descriptors (Windy through Hurricane Force Winds). Rationale: Beaufort provides better granularity at lower speeds; GFE avoids misleading labels at high speeds (Beaufort 12 = "Hurricane" which implies a tropical system — wrong for straight-line thunderstorm winds or derechos; GFE's "hurricane force winds" describes speed without implying storm type). See hybrid wind table in the technical specification.

**12. Current-conditions preservation directive.** The GFE engine is the PRIMARY system for forecast text and the UPGRADE path for current-conditions standard/verbose tiers. It does NOT replace the following current-conditions systems, which are preserved intact:

| System | What it does | Why it stays |
|---|---|---|
| **SkyPyEye 7-level classification** | Pyranometer-based sky (Clear, Mostly Clear, Partly Cloudy, Mostly Cloudy, Cloudy, Overcast, Heavy Overcast) with cloud enhancement detection, temporal coherence, startup backfill, SZA guard, provider fallback | Physical measurement is more accurate than percentage lookup. 7 levels (including Overcast/Heavy Overcast distinction) provide finer granularity than GFE's 6 buckets. GFE 6-bucket table is used for forecast periods only, where we have provider cloud cover percentages, not pyranometer data. |
| **Temperature-comfort 2D matrix** | 12 appTemp tiers × 7 dewpoint tiers → "Warm and Humid", "Pleasant", "Chilly" + NWS HI/WC danger escalation + near-saturation "and Foggy" override | Describes how it FEELS, not the numeric value. GFE decade phrasing ("in the mid 80s") tells the number — different purpose. Comfort matrix stays for terse tier; decade phrasing used in forecast. |
| **Sensor-based precipitation** | Local rain gauge with WMO/AMS thresholds (Light/Moderate/Heavy Rain) + Stull wet-bulb frozen precipitation cross-check | Sensor is authoritative for "is it raining NOW." Coverage language ("scattered showers") doesn't apply to a single station point observation. GFE coverage system used for forecast only. |
| **Haze detection** | Kcs + PM2.5/PM10 based haze classification | No GFE equivalent. Station-specific sensor detection. |
| **Fog/mist detection** | Hygrometer + dewpoint depression | No GFE equivalent. Station-specific sensor detection. |
| **Input stability** | Smoothing windows, hysteresis bands, 5-minute hold time, temporal coherence filter | No GFE equivalent. Required for real-time display — prevents label flickering from noisy sensor data. |
| **Current-conditions composition** | `[comfort, sky, wind, precip]` with ", with" connectors → "Warm and Humid, Overcast, with Light Rain" | Designed for single-instant snapshots. GFE's period-based composition ("Today: Mostly cloudy. High in the mid 80s.") is for forecast periods. |
| **Provider weather text deferral** | Nighttime haze/smoke deferral, missing pyranometer deferral, missing hygrometer fog/mist deferral | Graceful degradation when sensors unavailable. |

**What the GFE engine DOES change for current conditions:**
- Wind labels at ≥ 30 mph switch from Beaufort (Near Gale / Gale / Storm / Violent Storm / Hurricane) to GFE/NWS (Windy / Very Windy / Strong Winds / Hurricane Force Winds). Below 30 mph, Beaufort labels stay.
- Standard and verbose verbosity tiers gain GFE decade phrasing, GFE extreme temperature descriptors, and improved wind phrase connectors. The terse tier composition pattern is unchanged.
- Gust phrasing upgrades from "and Gusty" to GFE's "with gusts to around X mph" (more informative — states the gust speed).

**Implementation safety rule:** Any agent modifying `sse/enrichment/weather_text.py`, `sse/sky_condition.py`, `sse/conditions_text.py`, or `sse/text_generator.py` MUST read this preservation directive first. Deleting or replacing preserved systems is a blocking defect. The coordinator MUST verify preservation at every QC gate that touches current-conditions code.

---

## Technical specification

### Sky coverage — 6-bucket threshold table

Source: `ScalarPhrases.py`, method `sky_valueList()`

| Upper threshold (%) | Daytime phrase | Nighttime phrase |
|---|---|---|
| 5 | Sunny | Clear |
| 25 | Sunny | Mostly Clear |
| 50 | Mostly Sunny | Partly Cloudy |
| 69 | Partly Sunny | Mostly Cloudy |
| 87 | Mostly Cloudy | Mostly Cloudy |
| 100 | Cloudy | Cloudy |

**Adjacent-transition suppression** (`similarSkyWords_list`): transitions between adjacent pairs are too similar to report as a trend. Daytime pairs: (sunny, mostly sunny), (mostly sunny, partly sunny), (partly sunny, mostly cloudy), (mostly cloudy, cloudy). Nighttime pairs: (clear, mostly clear), (mostly clear, partly cloudy), (mostly cloudy, cloudy).

**Sky suppression by PoP** (`pop_sky_lower_threshold`): when PoP ≥ 55% for > 50% of sub-periods, the sky phrase is omitted entirely — precipitation dominates the sky condition.

### Temperature — decade phrasing algorithm

Source: `ScalarPhrases.py`, methods `getTempPhrase()`, `getDecadeStr()`, `tempPhrase_boundary_dict()`

**Core algorithm (`getTempPhrase`):**
1. Check exception table first (zero-crossing, above-100, exact-decade)
2. If `abs(maxVal - minVal) > 4°F`: report exact range "23 to 29"
3. Otherwise: map to decade + position within decade

**Decade naming (`getDecadeStr`):**

| Decade | Name |
|---|---|
| 0 | "single digits" |
| 10 | "teens" |
| -10 | "teens below zero" |
| other | `{decade}s` (e.g., "80s") |

**Position within decade (`tempPhrase_boundary_dict`):**

| Ones digit | Position |
|---|---|
| 0–3 | "lower" |
| 4–6 | "mid" |
| 7–9 | "upper" |

Examples: 83°F → "lower 80s", 86°F → "mid 80s", 89°F → "upper 80s". When min and max span the full decade (lower to upper): "in the 80s".

**Exception table (`tempPhrase_exceptions`):**

| Min range | Max range | Equality phrase | Range phrase |
|---|---|---|---|
| (100,200) | (100,200) | "around {min}" | "{min} to {max}" |
| (90,99) | (100,200) | — | "{min} to {max}" |
| (1,19) | (1,29) | "around {min}" | "{min} to {max}" |
| (0,0) | (0,29) | "near zero" | "zero to {max}" |
| (-200,0) | (0,0) | "near zero" | "{min} to zero" |
| (-200,-1) | (1,200) | "near zero" | "{min} to {max} zero" |
| (-200,-1) | (-200,-1) | "around {min}" | "{max} to {min} zero" |
| (N,N) for N=20,30,...90 | (N,N) | "around {min}" | "{min} to {max}" |

**Extended forecast ranges** (default `extended_temp_range = 10`):

| Digit | Phrase |
|---|---|
| 0–2 | "{decade-5} to {decade+5}" |
| 3–7 | "in the {decade}s" |
| 8–9 | "{decade+5} to {decade+15}" |

**Extreme temperature descriptors (`extremeTemps_words`):**

**Forecast input:** `ForecastPeriod.feels_like_max` (for heat rules) and `ForecastPeriod.feels_like_min` (for cold rules), aggregated from hourly `feelsLike`. Hourly `feelsLike` supplied by Xweather (`feelslikeF/C`), Open-Meteo (`apparent_temperature`), OWM (`feels_like`). Not supplied by NWS — extreme descriptors omitted when unavailable.

**Current-conditions input:** weewx `heatindex` and `windchill` — calculated by `StdWXCalculate` from outTemp + outHumidity + windSpeed, stored in the archive, served as first-class fields on `/current`.

Daytime:
- T > 99 AND (heatIndex - T) > 7 → "very hot and humid"
- T > 99 → "very hot"
- T > 95 AND (heatIndex - T) > 6 → "hot and humid"
- T > 95 → "hot"
- T < 20 AND windChill < -9 → "bitterly cold"
- T < 20 → "very cold"
- heatIndex ≥ 108 → "hot and humid"
- windChill ≤ 0 → "bitterly cold"

Nighttime:
- T < 5 AND windChill ≤ 0 → "bitterly cold"
- T < 5 → "very cold"
- windChill ≤ 0 → "bitterly cold"

**Steady temperature:** When diurnal range (max - min of hourly T) < 4°F: "near steady temperature in the mid 20s".

**Temperature trends (`temp_trends_words`):** Compare hourly T in latter half of period against MaxT/MinT. If difference > 20°F:
- Daytime: "temperatures falling into the [lower] 50s in the afternoon"
- Nighttime: "temperatures rising into the [upper] 30s after midnight"

### Wind — magnitude and descriptor thresholds

Source: `VectorRelatedPhrases.py` (1,564 lines)

**Magnitude phrasing:**
- maxMag < 5 mph (null threshold): "light winds" (first period) / "light" (subsequent)
- maxMag == minMag: "around {maxMag} mph"
- minMag < 5 mph: "up to {maxMag} mph"
- Otherwise: "{minMag} to {maxMag} mph"

**Summary descriptors — hybrid Beaufort/GFE scale (settled decision #11):**

Below 30 mph, Beaufort labels. At 30 mph and above, GFE/NWS descriptors. Applies to both current conditions and forecast.

| Wind speed (mph) | Descriptor | Source |
|---|---|---|
| < 1 | "Calm" | Beaufort 0 |
| 1–3 | "Very Light Breeze" | Beaufort 1 |
| 4–7 | "Light Breeze" | Beaufort 2 |
| 8–12 | "Gentle Breeze" | Beaufort 3 |
| 13–17 | "Moderate Breeze" | Beaufort 4 |
| 18–24 | "Fresh Breeze" | Beaufort 5 |
| 25–29 | "Strong Breeze" | Beaufort 6 |
| 30–39 | "Windy" | GFE |
| 40–49 | "Very Windy" | GFE |
| 50–73 | "Strong Winds" | GFE |
| ≥ 74 | "Hurricane Force Winds" | GFE |

**Forecast-only magnitude phrasing** (in addition to summary descriptor):
- maxMag < 5 mph (null threshold): "light winds" (first period) / "light" (subsequent)
- maxMag == minMag: "around {maxMag} mph"
- minMag < 5 mph: "up to {maxMag} mph"
- Otherwise: "{minMag} to {maxMag} mph"

**Gust qualification:** Report gusts only when `gusts - maxWind > 10 mph`. Phrase: "with gusts to around {gusts} mph". Replaces the current "and Gusty" qualifier for both current and forecast.

**Marine wind descriptors:**

| Wind (kt) | Descriptor |
|---|---|
| ≥ 64 | "hurricane force winds to" |
| ≥ 45 | "storm force winds to" |
| ≥ 34 | "gales to" |
| > 25 | "up to" (no descriptor) |

### Weather type system

Source: `WxPhrases.py` (1,943 lines)

**24 weather types in priority order:**

| Code | Type | Code | Type |
|---|---|---|---|
| WP | Waterspouts | R | Rain |
| RW | Rain showers | T | Thunderstorms |
| L | Drizzle | ZR | Freezing rain |
| ZL | Freezing drizzle | S | Snow |
| SW | Snow showers | IP | Ice pellets |
| F | Fog | ZF | Freezing fog |
| IF | Ice fog | IC | Ice crystals |
| H | Haze | BS | Blowing snow |
| BN | Blowing sand | K | Smoke |
| BD | Blowing dust | FR | Frost |
| ZY | Freezing spray | BA | Unknown/misc |

PoP-related types (correlate with probability of precipitation): ZR, R, RW, S, SW, T, IP.

**16 coverage levels (strongest → weakest):**

| Code | Term | Code | Term |
|---|---|---|---|
| Def | Definite | Wide | Widespread |
| Brf | Brief | Frq | Frequent |
| Ocnl | Occasional | Pds | Periods of |
| Inter | Intermittent | Lkly | Likely |
| Num | Numerous | Sct | Scattered |
| Chc | Chance | Areas | Areas of |
| SChc | Slight chance | WSct | Widely scattered |
| Iso | Isolated | Patchy | Patchy |

**Coverage similarity lists** (transitions between these are suppressed):
- SChc ≈ Iso (slight chance ≈ isolated)
- Chc ≈ Sct (chance ≈ scattered)
- Lkly ≈ Num (likely ≈ numerous)
- Brf ≈ Frq ≈ Ocnl ≈ Pds ≈ Inter ≈ Def ≈ Wide (all "definite" variants)

**PoP-to-coverage derivation.** Providers supply PoP as a percentage, not NWS-style coverage codes. The engine derives coverage from PoP. Which term in each pair depends on whether the weather type is PoP-related (rain, snow, thunderstorms → "chance" family) or areal (fog, haze, smoke → "isolated" family):

| PoP range | PoP-related types (R, RW, S, SW, T, IP, ZR) | Areal types (F, ZF, IF, H, K, BS, BN, BD) |
|---|---|---|
| < 15% (first 24h) / < 25% (extended) | (suppressed — no weather mention) | (suppressed) |
| 15–24% | Slight chance (SChc) | Isolated (Iso) |
| 25–54% | Chance (Chc) | Scattered (Sct) |
| 55–74% | Likely (Lkly) | Numerous (Num) |
| 75–100% | (coverage omitted, PoP separated into own phrase) | Widespread (Wide) / Definite (Def) |

**4 intensity codes:** `+` heavy, `m` moderate, `-` light, `--` very light/trace.

**Special type descriptors:**
- Very light snow showers (SW, --) → "flurries"
- Rain showers at temp < 60°F → "rain showers"; ≥ 60°F → "showers"
- Very light rain showers (RW, --) → "sprinkles"
- Thunderstorms with Dry attribute → "dry thunderstorms"

**Weather conjunction rules:**

| Situation | Conjunction | Example |
|---|---|---|
| Default between types | " and " | "rain and snow" |
| Definite + Likely coverage | " with " | "rain with possible thunderstorms" |
| "OR" attribute | " or " | "rain or snow" |
| Mixed precipitation | " mixed with " | "snow mixed with sleet" |
| Uncertain secondary | " with possible " | "snow with possible freezing rain" |
| 3+ items | Serial comma | "rain, snow and freezing rain" |

**Heavy precipitation detection:** types R/RW (rain), S/SW (snow), IP/ZR/L/ZL (other). Descriptors: "locally heavy rainfall possible", "rain may be heavy at times", "snow may be heavy at times", "precipitation may be heavy at times".

**Severe weather:** intensity `+` on thunderstorms → "some thunderstorms may be severe" + attribute descriptors (DmgW=damaging winds, GW=gusty winds, FL=frequent lightning, LgA=large hail, SmA=small hail, TOR=tornadoes, HvyRn=heavy rain).

### PoP thresholds

Source: `ScalarPhrases.py`

- `pop_lower_threshold`: 15% (first 24h) or 25% (extended) — below this, weather is not mentioned
- `pop_wx_lower_threshold`: 20% — suppress weather mention below this in WxPhrases
- `pop_upper_threshold`: 100%
- PoP type qualification: R→"rain", RW→"showers", S→"snow", SW→"snow", T→"thunderstorms", [IP,ZL,ZR,ZF,ZY]→"precipitation" (always generic)
- Rounding increment: 10% (PoP values are rounded to nearest 10)

### Snow and ice accumulation

Source: `ScalarPhrases.py`

**Snow accumulation** (requires PoP ≥ 60% AND accumulating weather types S, SW, IP, IC):

| Condition | Phrase |
|---|---|
| max < 0.5" | "no snow accumulation" |
| max < 1" | "little or no snow accumulation" |
| min < 1", max < 3" | "up to {max} inches" |
| max - min < 2" | "around {max} inches" |
| otherwise | "of {min} to {max} inches" |

**Descriptive snow:**

| Max accumulation | Phrase |
|---|---|
| < 1 inch | (none) |
| 1–2 inches | "light snow accumulations" |
| 2–5 inches | "moderate snow accumulations" |
| > 5 inches | "heavy snow accumulations" |

**Ice accumulation** (fractional-inch):

| Value | Phrase |
|---|---|
| < 0.2" | "less than one quarter" |
| 0.2–0.4" | "one quarter" |
| 0.4–0.7" | "one half" |
| 0.7–0.9" | "three quarters" |
| 0.9–1.3" | "one" |
| 1.3–1.8" | "one and a half" |
| ≥ 1.8" | integer rounded |

### Marine phrase tables

Source: `MarinePhrases.py` (~370 lines). Tables only — no marine provider module in scope.

**Wave height text ranges:**

| Average (ft) | Text |
|---|---|
| 0 | "less than 1 foot" |
| 1 | "1 foot or less" |
| 1.5 | "1 to 2 feet" |
| 2 | "1 to 3 feet" |
| 3 | "2 to 4 feet" |
| 5 | "3 to 6 feet" |
| 8 | "6 to 10 feet" |
| 12 | "10 to 14 feet" |
| 20 | "15 to 20 feet" |
| 100 | "over 20 feet" |

**Chop categories:**

| Wind (kt) | Chop |
|---|---|
| ≤ 7 | "smooth" |
| 8–12 | "a light chop" |
| 13–17 | "a moderate chop" |
| 18–22 | "choppy" |
| 23–27 | "rough" |
| 28–32 | "very rough" |
| > 32 | "extremely rough" |

**Marine wind:** ≥34 kt → gales, ≥45 kt → storm force, ≥64 kt → hurricane force. Combined seas reported when wind > 34 kt or both waves > 7 ft AND swells > 7 ft.

### Fire weather tables

Source: `FirePhrases.py` (~540 lines). Tiered — see settled decision #6.

**Smoke dispersal (Tier 3 — requires VentRate data):**

| VentRate (knot-ft) | Category |
|---|---|
| < 40,000 | "poor" |
| 40,000–59,999 | "fair" |
| 60,000–99,999 | "good" |
| 100,000–149,999 | "very good" |
| ≥ 150,000 | "excellent" |

**Haines Index (Tier 2 — requires pressure-level data):**

| Index | Text |
|---|---|
| 0–3 | "very low potential for large plume dominated fire growth" |
| 4 | "low potential..." |
| 5 | "moderate potential..." |
| 6–10 | "high potential..." |

**Humidity recovery (Tier 1 — active, uses available humidity data):**

MaxRH > 50% → "Excellent" immediately. Otherwise, diff from 24h prior:

| Threshold (% diff) | Category |
|---|---|
| ≤ 25 | "Poor" |
| ≤ 55 | "Moderate" |
| ≤ 70 | "Good" |
| ≤ 100 | "Excellent" |

**LAL — Lightning Activity Level (Tier 1 — active, heuristic from weather codes):**

| LAL | Description |
|---|---|
| 1 | "No Tstms" |
| 2 | "1-8 strikes" |
| 3 | "9-15 strikes" |
| 4 | "16-25 strikes" |
| 5 | ">25 strikes" |
| 6 | "Dry lightning" |

Coverage-to-LAL mapping: Iso/SChc → 2-3, Patchy → 2, Areas/Chc/Sct → 4, Lkly through Wide → 5, any Dry T → 6.

### Time descriptors

Source: `TimeDescriptor.py` (761 lines)

**Period labels:**

| Situation | Label |
|---|---|
| Current day, daytime | "Today" |
| Current day, nighttime | "Tonight" |
| Current day, < 12h remaining, day | "Rest of Today" |
| Current day, < 12h remaining, night | "Rest of Tonight" |
| Next day, daytime | "Tomorrow" |
| Next day, nighttime | "Tomorrow Night" |
| Future weekday, daytime | "Saturday" |
| Future weekday, nighttime (> 6h) | "Saturday Night" |
| Future weekday, nighttime (≤ 6h) | "Saturday Evening" |

**Sub-period time descriptors** (42-entry table, times relative to 6 AM local):

| Start → End | Phrase |
|---|---|
| 6a–9a | "early in the morning" |
| 6a–noon | "in the morning" |
| 6a–3p | "until late afternoon" |
| 6a–6p | "" (full day — no descriptor) |
| 6a–9p | "until early evening" |
| 6a–midnight | "through the evening" |
| 9a–noon | "late in the morning" |
| 9a–3p | "in the late morning and early afternoon" |
| 9a–6p | "in the late morning and afternoon" |
| noon–3p | "early in the afternoon" |
| noon–6p | "in the afternoon" |
| noon–9p | "in the afternoon and evening" |
| 3p–6p | "late in the afternoon" |
| 3p–9p | "early in the evening" |
| 3p–midnight | "in the evening" |
| 3p–3a | "until early morning" |
| 6p–9p | "early in the evening" |
| 6p–midnight | "in the evening" |
| 6p–3a | "until early morning" |
| 6p–6a | "" (full night — no descriptor) |
| 9p–midnight | "late in the evening" |
| 9p–3a | "in the late evening and early morning" |
| 9p–6a | "in the late evening and overnight" |
| midnight–3a | "after midnight" |
| midnight–6a | "after midnight" |
| 3a–6a | "early in the morning" |

### Connector strategies

Source: `PhraseBuilder.py` (4,237 lines), `ConfigVariables.py`

**Scalar connector:** Returns "then", "increasing to", or "decreasing to" based on value comparison.
- Sky element: "then becoming" (for all three cases)
- WaveHeight: "building to" / "subsiding to"
- Default: "then" / "increasing to" / "decreasing to"

**Vector connector (wind):** Direction + magnitude-aware:
- Same direction, different magnitude → "increasing to" / "decreasing to"
- Same magnitude, different direction → "shifting to the"
- Both different, high wind (≥ 45 mph) → "becoming {dir} and increasing/decreasing to"
- Both different, normal → "increasing to" / "becoming"

**Weather connector:** Period-separated (". ") or ", then " between weather sub-phrases. Manages a flag to avoid chains of "then...then...then".

**Marine vector connector:** "rising to", "easing to", "backing", "veering", "becoming onshore".

### Composition engine — single-pass sequential

Source: `PhraseBuilder.py` (`assembleSubPhrases`), `CombinedPhrases.py` (`skyPopWx_phrase`)

Our engine uses a simplified single-pass sequential assembly, NOT the GFE's tree traversal with fixed-point iteration. The GFE tree architecture solves the AWIPS problem of resolving interdependent phrase methods across gridded data with multiple edit areas — our provider data is pre-structured, so sequential assembly suffices.

**Assembly order per period:** period label + colon, sky, temperature, wind, precipitation/weather.

**`skyPopWx` combined phrase:** The compound sky+PoP+weather phrase that produces NWS-style sentences like "Partly cloudy with a 20 percent chance of showers and thunderstorms." Pipeline:
1. Separate non-precip weather (fog, haze, smoke) into standalone phrase
2. Consolidate weather keys across sub-phrases
3. Decide: include sky? include PoP? abort combined phrase?
4. Merge identical-text sub-phrases
5. Insert null phrases ("light winds" etc.)
6. Moderate time descriptors
7. Assemble with connectors
8. Post-process (cleanup + locale resolution)

**Key decision rules:**
- When PoP ≥ 60%: PoP is separated into its own `popMax_phrase`, not combined
- When areal coverage terms exist: PoP is also separated
- Non-precipitation weather (fog, haze, smoke) is always pulled into a separate phrase

**Sentence assembly:**
- `sentence(s)` = capitalize first letter + ". " suffix
- Combining single-word sentences: "Warm. Dry." → "Warm, dry."
- Oxford comma: 2 items = "rain and snow"; 3+ items = "rain, snow, and freezing rain"

### Period aggregation

Source: GFE `SampleAnalysis.py` §15 (adapted for single-station hourly provider data)

**Period boundaries:** 6am/6pm local time (NWS convention). `is_daytime` flag set from sunrise/sunset (for vocabulary selection only — period boundaries are always 6am/6pm).

**Aggregation rules for `HourlyForecastPoint` → `ForecastPeriod`:**

| Field | Aggregation | Source |
|---|---|---|
| temp_high (day) | max(outTemp) | hourly outTemp |
| temp_low (night) | min(outTemp) | hourly outTemp |
| sky_percent | mean(cloudCover) | hourly cloudCover |
| sky_label | 6-bucket table lookup on sky_percent | computed |
| pop | max(precipProbability) | hourly precipProbability |
| precip_type | mode(precipType) | hourly precipType |
| wind_speed_min/max | min/max(windSpeed) | hourly windSpeed |
| wind_gust | max(windGust) | hourly windGust |
| wind_direction | mode(windDir, 8-point compass) | hourly windDir |
| weather_codes | union(weatherCode) | hourly weatherCode |
| snow_amount | sum(precipAmount) where precip_type=snow | hourly precipAmount |
| humidity_max/min | max/min(outHumidity) | hourly outHumidity |
| feels_like_max/min | max/min(feelsLike) | hourly feelsLike |
| thunder_risk | max(thunderRisk) or weather code heuristic | hourly thunderRisk |
| precip_coverage | derived from pop (see PoP-to-coverage table) | computed |
| temp_trend | compare hourly outTemp latter-half vs period extreme; > 20°F diff → "falling"/"rising", else None | computed |

**Period labels:** Generated per the time descriptors table above. 72 hourly points → 6 ForecastPeriod instances (Today, Tonight, Tomorrow, Tomorrow Night, weekday, weekday Night).

### Provider data availability

Cross-provider matrix — what each provider supplies for text generation inputs:

**Hourly forecast fields:**

| Field | Xweather | NWS | Open-Meteo | OWM | Engine use |
|---|---|---|---|---|---|
| outTemp | Y | Y | Y | Y | Temperature phrases |
| outHumidity | Y | — | Y | Y | Fire: humidity recovery |
| windSpeed | Y | Y | Y | Y | Wind phrases |
| windDir | Y | Y | Y | Y | Wind direction |
| windGust | Y | — | Y | Y | Gust phrases (> sustained + 10) |
| precipProbability | Y | Y | Y | Y | PoP qualification |
| precipAmount | Y | — | Y | Y | Coverage language, snow accumulation |
| precipType | Y | Y | Y | Y | Weather type phrases |
| cloudCover | Y | — | Y | Y | Sky phrases (6-bucket) |
| weatherCode | Y | Y | Y | Y | Weather type hierarchy, LAL heuristic |
| feelsLike | Y | — | Y | Y | Extreme temperature descriptors (heat index / wind chill) |

**Daily forecast fields:**

| Field | Xweather | NWS | Open-Meteo | OWM | Engine use |
|---|---|---|---|---|---|
| tempMax / tempMin | Y | Y | Y | Y | Decade phrasing |
| precipProbabilityMax | Y | Y | Y | Y | PoP gating |
| windSpeedMax | Y | Y | Y | Y | Wind descriptor |
| windGustMax | Y | — | Y | Y | Gust phrases |
| snowAmount | Y | — | Y | Y | Snow accumulation |
| iceAccumulation | Y | — | — | — | Ice accumulation phrases |
| humidityMax / humidityMin | Y | — | Y | Y/— | Fire: humidity recovery |
| sunrise / sunset | Y | Skyfield | Y | Y | Day/night vocabulary |
| narrative | Y | Y (detailedForecast) | — | Y | NWS pass-through |

**Not available from any provider:** Marine data (wave height, swell, sea temp), fire weather pressure-level data (mixing height, transport wind, VentRate, Haines, direct LAL). Tables are built; provider modules are separate scope.

**Available but not yet mapped:** Ice accumulation — Xweather supplies `iceaccumMM`/`iceaccumIN` on daily forecasts. Requires adding `iceAccumulation` to `DailyForecastPoint` and parsing from the Xweather wire model. No other provider supplies ice accumulation.

### i18n — gender/number agreement for Romance languages

Source: GFE `Translator.py` (~460 lines)

GFE uses a "generate English, then replace" multi-pass engine for French and Spanish. We take a different approach — locale-first composition — but adopt GFE's gender/number classification system for Romance language adjective agreement.

**Gender codes per weather type (example for French):**

| Weather type | French word | Gender code |
|---|---|---|
| Rain | pluie | FS (feminine singular) |
| Thunderstorms | orages | MP (masculine plural) |
| Fog | brouillard | MS (masculine singular) |
| Showers | averses | FP (feminine plural) |

**Adjective inflection:** Each coverage/intensity adjective in the locale file carries 4 forms:

```
"scattered": {
  "MS": "dispersé",
  "MP": "dispersés", 
  "FS": "dispersée",
  "FP": "dispersées"
}
```

The engine calls `t_inflected("forecast.coverage.scattered", weather_type_gender_code, locale)` to resolve the correct form.

**Russian:** Case inflection (nominative/instrumental/genitive) for the "with" construction, already in the existing locale system.

**Japanese (custom composer):** JMA temporal operators: tokidoki (時々, "sometimes"), ichiji (一時, "temporarily"), nochi (のち, "later"). Sentence structure: `[time] [sky] [tokidoki/ichiji] [weather]` — word order incompatible with English template substitution.

**Chinese (custom composer):** CMA/CWA structured fields. Period labels, weather types, wind grades, temperature vocabulary follow national conventions.

---

## Module inventory

### New modules (under `sse/gfe/` in weewx-clearskies-api)

| Module | Purpose | GFE reference |
|---|---|---|
| `sse/gfe/__init__.py` | Package init + public API | — |
| `sse/gfe/thresholds.py` | All threshold tables (sky, temp, wind, weather, PoP, snow/ice, marine, fire) | §1-4, 7, 9-10, 17-18 |
| `sse/gfe/sky_phrases.py` | Sky coverage phrase generator | §1 |
| `sse/gfe/temp_phrases.py` | Temperature decade phrasing, exceptions, trends, extremes | §2 |
| `sse/gfe/wind_phrases.py` | Wind magnitude, descriptors, gusts, marine wind | §3 |
| `sse/gfe/wx_phrases.py` | Weather/precip: 24 types, 16 coverages, intensity, conjunctions, PoP | §4 |
| `sse/gfe/snow_ice_phrases.py` | Snow/ice accumulation phrasing | §9 |
| `sse/gfe/marine_phrases.py` | Marine phrase templates (tables only) | §17 |
| `sse/gfe/fire_phrases.py` | Fire weather generators (tiered) | §18 |
| `sse/gfe/time_descriptors.py` | Period labels + sub-period table | §6 |
| `sse/gfe/connectors.py` | Scalar/vector/weather/marine connector strategies | §5.2 |
| `sse/gfe/composer.py` | Single-pass composition engine, skyPopWx | §5.3, §11 |

### New modules (outside gfe/ package)

| Module | Purpose |
|---|---|
| `sse/forecast_model.py` | ForecastPeriod dataclass (structured input for one day/night period) |
| `sse/period_aggregator.py` | Aggregate hourly provider data into day/night periods |
| `sse/forecast_text_enrichment.py` | Enrichment adapter for `/api/v1/forecast` |

### Public API (`sse/gfe/__init__.py`)

- `generate_forecast_text(period: ForecastPeriod, locale: str) -> str`
- `generate_current_text(obs: Observation, verbosity: str, locale: str) -> str`
- `aggregate_periods(hourly_data, sunrise, sunset, current_time, timezone, locale) -> list[ForecastPeriod]`
- `configure(unit_system)` — module-level unit setup

### Modules replaced

| Current module | Disposition |
|---|---|
| `sse/text_generator.py` | Replaced — generation moves to shared engine |
| `sse/conditions_text.py` | Replaced — terse composition moves to shared engine |
| `sse/enrichment/weather_text.py` | Refactored to input adapter only — detection stays, generation delegates |

### Modules unchanged

`sse/sky_condition.py` (SkyPyEye classifier), `sse/haze_condition.py`, `sse/fog_condition.py`, `sse/temperature_comfort.py`, `sse/enrichment/input_smoother.py`, `sse/observation_model.py` — all sensor-data detection modules stay as the current-conditions input path.

---

## Consequences

- `sse/text_generator.py` and `sse/conditions_text.py` are deleted; generation logic moves to `sse/gfe/`.
- `sse/enrichment/weather_text.py` becomes an input adapter only — detection logic (fog, haze, provider deferral, cross-checks) stays; phrase generation and composition delegate to `sse/gfe/composer.py`.
- 14 new modules under `sse/gfe/` plus 3 outside the package (forecast model, period aggregator, enrichment adapter).
- `/api/v1/forecast` gains a `forecastText` field per `DailyForecastPoint`.
- `/api/v1/current` fields (`weatherText`, `weatherTextStandard`, `weatherTextVerbose`) are unchanged in response shape; text content improves in quality (decade phrasing, coverage language, connectors).
- ~300 new i18n keys × 13 locales. Romance languages carry gender/number inflected forms (4 forms per adjective); Russian carries case-inflected forms.
- Marine and Tier 2/3 fire weather tables are built but dormant until provider data exists — accepted cost to avoid re-reading GFE source sections later.
- Trade-off accepted: larger initial implementation surface (Option A) in exchange for eliminating long-term vocabulary divergence (Option B's failure mode).
- Existing tests for `/api/v1/current` must continue to pass; assertion updates for improved phrasing are expected and acceptable.

## Acceptance criteria

- [ ] Every threshold value in `sse/gfe/thresholds.py` matches the values documented in this ADR's technical specification section (which are ported from `gfe-source-code-analysis.md`). Spot-checked at QC Gate 2.
- [ ] `sky_phrase(30, True, "en")` returns "Mostly Sunny". `sky_phrase(30, False, "en")` returns "Partly Cloudy". Adjacent-transition suppression works.
- [ ] `temp_phrase(83, 89, True, "en")` returns a phrase containing "80s". Zero-crossing, teens, single digits all produce correct output per the exception table.
- [ ] Wind descriptors at each threshold boundary (24/25/29/30/39/40/49/50/73/74 mph) produce the correct descriptor. Gust suppression fires when gust - sustained ≤ 10.
- [ ] All 16 coverage levels resolve to correct English terms. Conjunctions produce natural text. Serial comma applies for 3+ items.
- [ ] All 13 locales resolve every forecast i18n key with no raw-key fallback in output.
- [ ] Romance language gender/number: `t_inflected("forecast.coverage.scattered", "FS", "fr")` returns the feminine singular French form.
- [ ] NWS-provider forecasts return `detailedForecast` text unchanged; the engine is not invoked.
- [ ] `/api/v1/current` fields (`weatherText`, `weatherTextStandard`, `weatherTextVerbose`) are present; existing tests pass (adjusted assertions for improved phrasing are acceptable).
- [ ] `/api/v1/forecast` `DailyForecastPoint` includes a populated `forecastText` field for non-NWS providers.
- [ ] 72 hourly forecast points aggregate into 6 ForecastPeriod instances with correct labels (Today/Tonight/Tomorrow/Tomorrow Night/weekday/weekday Night). Day=6am-6pm, Night=6pm-6am.
- [ ] Marine wave height table has 10 entries; fire smoke dispersal has 5 categories; LAL has 6 levels; chop has 7 categories. All match GFE source values.

Checked at: (a) round close by coordinator QC, (b) phase-boundary QC gates per TEXT-ENGINE-PLAN.md, (c) Phase 9 QA audit.

## Implementation guidance

See `docs/planning/TEXT-ENGINE-PLAN.md` for the full 10-phase implementation sequence, agent assignments, QC gate criteria, and inter-phase dependencies.

**Out of scope for this ADR:** Marine/fire weather provider modules (separate plan), dashboard rendering changes (separate plan), Config UI changes.

## References

### Project documents
- Related ADRs: ADR-070 (archived — NWS text generation system), ADR-073 (archived — sky-condition-kv-first-classification)
- GFE source analysis: `docs/reference/nws-text-system/gfe-source-code-analysis.md` (~10,800 lines across 6 files)
- International patterns: `docs/reference/nws-text-system/international-forecast-text-patterns.md` (13 locales verified against national met services)
- Implementation plan: `docs/planning/TEXT-ENGINE-PLAN.md`
- Brief: `docs/planning/briefs/FORECAST-TEXT-ENGINE-BRIEF.md`

### NWS GFE source code (public domain, 17 USC §105)

Repository: [Unidata/awips2](https://github.com/Unidata/awips2) — public domain US government work.
Base path: `cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/`

| File | Lines | Raw URL |
|---|---|---|
| ScalarPhrases.py | 2,747 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ScalarPhrases.py) |
| VectorRelatedPhrases.py | 1,564 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/VectorRelatedPhrases.py) |
| WxPhrases.py | 1,943 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/WxPhrases.py) |
| PhraseBuilder.py | 4,237 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/PhraseBuilder.py) |
| ConfigVariables.py | ~1,280 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ConfigVariables.py) |
| TimeDescriptor.py | 761 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/TimeDescriptor.py) |
| Translator.py | ~460 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/Translator.py) |
| MarinePhrases.py | ~370 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/MarinePhrases.py) |
| FirePhrases.py | ~540 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/FirePhrases.py) |
| SampleAnalysis.py | 2,970 | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/SampleAnalysis.py) |
| CombinedPhrases.py | — | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/CombinedPhrases.py) |
| ForecastNarrative.py | — | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ForecastNarrative.py) |

Formatter examples:
| File | Raw URL |
|---|---|
| RecreationFcst.py | [raw](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/python/testFormatters/RecreationFcst.py) |
| HSF.py | (textProducts/HSF.py in same repo path) |
