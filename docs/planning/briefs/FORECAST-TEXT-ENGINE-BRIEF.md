# Brief: Unified Text Generation Engine

**Date:** 2026-07-05  
**Scope:** Replace the current split text generation system with a single GFE-derived engine that handles both current observations and forecast periods  
**Research basis:** [gfe-source-code-analysis.md](../../reference/nws-text-system/gfe-source-code-analysis.md) (~18,700 lines across 15 GFE files), [international-forecast-text-patterns.md](../../reference/nws-text-system/international-forecast-text-patterns.md) (13 locales verified against national met services)

---

## Problem

The current conditions text engine (`text_generator.py`, `conditions_text.py`, `enrichment/weather_text.py`) uses a simpler, narrower rule set than what NWS actually uses. Temperature is just "Temperature near 85 degrees" — no decade phrasing. Wind is just "South winds around 8 mph" — no transition connectors. Precipitation is just "Light Rain" — no coverage language or PoP qualification.

Building a separate forecast text engine alongside this creates two systems producing different-quality text for the same vocabulary. The forecast engine needs the full GFE rule set; the current conditions engine should use it too.

## Decision

One engine, two input paths. The new engine replaces `text_generator.py` and `conditions_text.py`. The detection modules (CAELUS sky classifier, haze/fog/mist detection, temperature comfort, input smoother) stay as the sensor-data input path.

## Architecture

```
SENSOR INPUT PATH (existing — stays):
  sky_condition.py      → sky label (CAELUS Kv-first)
  haze_condition.py     → haze detection (two-channel PM)
  fog_condition.py      → fog/mist detection (provider cross-check)
  temperature_comfort.py → comfort label (2D matrix)
  input_smoother.py     → smoothed sensor values
  observation_model.py  → Observation dataclass

PROVIDER INPUT PATH (new):
  Hourly forecast data  → period aggregation
  Cloud cover %         → sky label (GFE 6-bucket table)
  PoP + precip type     → coverage language
  High/low temp         → decade phrasing
  Wind speed/dir        → wind descriptors + connectors
  Weather codes         → weather type descriptors
  Sunrise/sunset        → period day/night determination

SHARED TEXT ENGINE (new — replaces text_generator.py + conditions_text.py):
  Threshold tables      — GFE-derived, all domains (sky, temp, wind,
                           precip, marine, fire, hazard timing)
  Phrase generators     — one per element, using threshold tables
  Connectors            — scalar/vector/weather/marine strategies
  Time descriptors      — 42-entry sub-period table + period labels
  Composition rules     — skyPopWx combined phrase, element ordering,
                           serial comma, "with"/"and"/"then" conjunctions
  i18n resolution       — locale files + custom composers (JA/ZH) +
                           gender/number agreement (Romance) +
                           case inflection (RU)
  Verbosity levels      — terse / standard / verbose (extensible)
```

## What the engine consumes

Both input paths produce the same vocabulary — the engine doesn't care whether "Partly Cloudy" came from the CAELUS classifier or from a cloud cover percentage lookup. The structured inputs are:

**For current observations** (single instant):
- Sky label, present weather codes, temperature + comfort label, wind speed/direction/gust, precipitation intensity + type, haze/fog/mist state

**For forecast periods** (12-hour day/night blocks):
- Period label (Today/Tonight/Saturday/Saturday Night), sky label from cloud cover, high or low temp, PoP + precipitation type + coverage, wind speed/direction/gust, weather code, snow/ice amounts

## What the engine produces

Per the GFE model, the output is structured text at the configured verbosity:

**Current observation example (one period, present tense):**
> Partly sunny. Hazy. Temperature in the mid 80s. South winds around 8 mph.

**Forecast example (multiple periods, future tense):**
> Today: Mostly sunny, with a high near 92. South winds 5 to 10 mph.
> Tonight: Partly cloudy, with a low around 68. Light winds.
> Saturday: Sunny, with a high near 95. Breezy, with west winds 15 to 20 mph.

**NWS pass-through** (when operator selects NWS as forecast provider):
> Forecast text fields populated directly from NWS `detailedForecast`. Engine not invoked.

## What gets replaced

| Current module | Disposition |
|---|---|
| `sse/text_generator.py` | **Replaced** — standard/verbose generation moves to shared engine |
| `sse/conditions_text.py` | **Replaced** — terse composition moves to shared engine |
| `sse/enrichment/weather_text.py` | **Refactored** — becomes the current-conditions input adapter, no longer contains text generation logic |
| `sse/observation_model.py` | **Stays** — sensor-data structured input, feeds the engine |
| `sse/sky_condition.py` | **Stays** — CAELUS classifier, sensor-data path |
| `sse/haze_condition.py` | **Stays** — two-channel haze detection |
| `sse/fog_condition.py` | **Stays** — fog/mist with provider cross-check |
| `sse/temperature_comfort.py` | **Stays** — comfort labels for current conditions |
| `sse/enrichment/input_smoother.py` | **Stays** — ring buffer smoothing for sensor data |

## What gets built

| New module | Role |
|---|---|
| Forecast period model | Structured dataclass for a forecast period (like `Observation` but for forecast data) |
| Period segmentation | Aggregate hourly provider data into 12-hour day/night periods using sunrise/sunset |
| Period summary statistics | Compute per-period: high/low temp, dominant sky, max wind, max PoP, dominant precip type, snow/ice amounts |
| GFE threshold tables | All tables from GFE source analysis: sky (§1), temperature decade (§2), wind descriptors (§3), weather types + coverage (§4), snow/ice (§9), PoP (§10), marine (§17), fire weather (§18) |
| Phrase generators | Per-element functions using threshold tables. Sky phrase, temperature phrase, wind phrase, precipitation phrase, marine phrase, fire weather phrase |
| Connector system | Scalar/vector/weather connectors from GFE §5.2, simplified for single-station (no local effects) |
| Time descriptor system | Period labels (Today/Tonight/weekday) from GFE §6.1, sub-period descriptors from GFE §6.2, timing connectors from GFE §19.3 |
| Composition engine | Single-pass sequential composer (not GFE tree traversal). Assembles element phrases into period sentences per NWS element order. Handles skyPopWx combined phrase pattern. |
| Forecast text enrichment | Enrichment adapter for `/api/v1/forecast` — generates text fields per period for non-NWS providers, passes through NWS text for NWS provider |
| i18n forecast keys | Period labels, coverage terms, transition phrases, temperature decade vocabulary, gender/number agreement forms for all 13 locales |

## GFE source reference sections (by new module)

| New module | GFE reference sections |
|---|---|
| Threshold tables | §1 sky, §2 temperature, §3 wind, §4 weather types, §7 configuration, §9 snow/ice, §10 PoP, §17 marine, §18 fire |
| Phrase generators | §1-4 (ScalarPhrases, VectorRelatedPhrases, WxPhrases methods) |
| Connectors | §5.2 (four strategies), §7 phrase_connector_dict |
| Time descriptors | §6 (TimeDescriptor), §19.2-19.4 (DiscretePhrases timing tables) |
| Composition | §5.3 (assembleSubPhrases), §11 (skyPopWx combined phrase), §5.1 (pipeline) |
| Translation/i18n | §14 (Translator gender/number pattern), international-forecast-text-patterns.md |
| Period segmentation | §15.1 (time range segmentation), §16.1 (period definition by product) |

## Design decisions (settled)

1. **NWS pass-through**: NWS provider → pass through `detailedForecast` directly. Engine generates text only for Open-Meteo, Aeris, OWM.
2. **Period structure**: 12-hour day/night per NWS convention, using provider sunrise/sunset.
3. **All GFE domains included**: Sky, temperature, wind, precipitation, marine, fire weather, hazard timing. What activates depends on what provider data supports, not design-time exclusion.
4. **i18n from day one**: All generated text resolves through locale files. 13 locales. No hardcoded English.
5. **One engine**: Replaces `text_generator.py` + `conditions_text.py`. Current observations and forecast periods use the same phrase generators, connectors, and composition rules.

## Prerequisite

Remove Weather Underground provider from codebase before implementation begins (user directive, repeated — 17 files across API repo + meta repo docs, scoped in research brief §8).

## Response surface

**Current observations** — existing fields, same endpoint:
- `weatherText` (terse), `weatherTextStandard`, `weatherTextVerbose` on `GET /api/v1/current`
- Generated by shared engine via current-conditions input adapter

**Forecast periods** — new fields on existing endpoint:
- Per-period text fields on `GET /api/v1/forecast` response (similar pattern to how current observation has three verbosity levels)
- NWS provider: populated from `detailedForecast` pass-through
- Other providers: generated by shared engine via forecast input adapter
