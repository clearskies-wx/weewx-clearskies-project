# Clear Skies — Provider Manual

Single authority for building and modifying provider modules in the Clear Skies API. ADRs explain *why*; this manual says *what to do*.

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **API-MANUAL.md** — API implementation rules (data model, units, enrichment)
- **ARCHITECTURE.md** — system topology, provider module layout
- **contracts/canonical-data-model.md** — per-field data catalog

Last updated: 2026-07-15

---

## Table of Contents

1. [Module Contract](#1-module-contract)
2. [Compliance](#2-compliance)
3. [Caching](#3-caching)
4. [Forecast Providers](#4-forecast-providers)
5. [Air Quality](#5-air-quality)
6. [Almanac](#6-almanac)
7. [Radar](#7-radar)
8. [Alerts](#8-alerts)
9. [Earthquakes](#9-earthquakes)
10. [Error Taxonomy](#10-error-taxonomy)
11. [Testing Pattern](#11-testing-pattern)
12. [Provider Attribution](#12-provider-attribution)
13. [Anti-Patterns](#13-anti-patterns)
14. [Marine & Coastal Providers](#14-marine--coastal-providers)

---

## §1 Module Contract

### One module per provider; one module per domain

Each provider lives in a self-contained module (single file or directory package) named after the provider. A provider that spans multiple data domains (e.g., Xweather supplies both forecast and AQI) gets one module per domain — a `providers/forecast/aeris.py` and a separate `providers/aqi/aeris.py`. These modules share nothing except any common auth constants they each independently define. Do not create modules that cross domain boundaries.

Adding a provider means adding a new module. Removing a provider means deleting that module. Do not refactor existing modules to absorb a new provider.

### Five responsibilities per module

Every provider module is responsible for exactly these five things, and nothing else:

1. **Outbound API call** — provider URL, authentication, query parameters, rate-limit handling. The module owns its own rate limiter instance for per-provider quota enforcement.
2. **Response parsing** — interpret the provider's response format (JSON, GeoJSON, XML, WMS capabilities).
3. **Canonical field translation** — unit conversion, scale normalization, identifier normalization (`PM2.5` / `pm25` / `pm2_5` → canonical `PM2.5`), time format → ISO 8601 UTC `Z`. Translate per the field catalog in `contracts/canonical-data-model.md`.
4. **Capability declaration** — a static, deterministic statement of which canonical fields this module supplies. Read at process startup to populate the runtime capability registry.
5. **Error handling** — translate every provider error condition into the canonical error taxonomy (see §10). No upstream error type leaks past the module boundary.

Anything outside these five — caching, logging format, persistence, dashboard rendering, alert banner display — is owned by other system layers. Do not implement those concerns inside a provider module.

### Shared infrastructure vs. per-module code

**Shared (`weewx_clearskies_api/providers/_common/`):**
- HTTP client wrapper with TLS, timeouts, and dual-stack (IPv4/IPv6) per coding rules §1
- Retry/backoff helper
- Canonical error class hierarchy
- Capability declaration data structure and registry plumbing
- Rate-limiter primitive

**Per-module:**
- Provider URL, authentication scheme, query parameter construction
- Response parsing and translation to canonical fields
- Module-level rate limiter instance (instantiated from the shared primitive)
- Domain-specific helpers needed only by this provider

**Canonical model package (not in providers at all):**
- Domain-wide helpers such as EPA AQI category lookup, Beaufort scale conversion, US-NWS alert-code translation
- These belong in the canonical-model package per the data model contract — never implement them inside a provider module

### Module file layout

```
weewx_clearskies_api/providers/
├── _common/         # HTTP client, retry, errors, capability, rate-limiter, nws_zones.py
├── forecast/        # Forecast domain modules (§4)
├── aqi/             # AQI domain modules (§5)
├── alerts/          # Alerts domain modules (§8)
├── earthquakes/     # Earthquakes domain modules (§9)
├── radar/           # Radar domain modules (§7)
├── seeing/          # 7Timer seeing forecast (§6 exception — see below)
├── marine/          # Marine domain modules (§14): wavewatch, nws_marine, nws_srf
├── tides/           # Tides domain modules (§14): coops
└── buoy/            # Buoy domain modules (§14): ndbc
```


### Capability declaration fields

Every module exports a static `CAPABILITY` structure at module-load time. For most modules this is a plain module-level constant. Required fields:

| Field | Type | Description |
|---|---|---|
| `provider_id` | string | Stable identifier, lowercase, no spaces. Examples: `"aeris"`, `"openmeteo"`, `"usgs"`. |
| `domain` | string | One of `"forecast"`, `"aqi"`, `"alerts"`, `"earthquakes"`, `"radar"`, `"marine"`, `"tides"`, `"buoy"`. One module = one domain. |
| `supplied_canonical_fields` | list[str] | Enumerated canonical fields this module can supply. Reference the field catalog in `contracts/canonical-data-model.md`. |
| `geographic_coverage` | string or list[str] | `"global"` or enumerated regions. Used by the setup wizard to warn when operator's lat/lon is outside coverage. |
| `auth_required` | list[str] | Operator-config keys required (e.g., `["AERIS_CLIENT_ID", "AERIS_CLIENT_SECRET"]`). Empty list for providers that need no key. |
| `default_poll_interval_seconds` | int | Recommended polling cadence. |
| `operator_notes` | string | Free text surfaced in the configuration UI for provider-specific quirks and ToS reminders. |
| `is_observed_source` | bool | Whether the provider returns observed (measured) data from monitoring stations vs. model/forecast data. Default `True`. Only model-based AQI providers (Open-Meteo AQI) set `False`. Used by the haze detection engine (ADR-067) to determine which PM2.5/PM10 data is eligible for haze confirmation. Non-AQI modules omit this field or leave it at the default. |

Radar modules add these optional fields to the capability declaration:

| Field | Type | Description |
|---|---|---|
| `tile_url_template` | string or None | XYZ tile URL template for raster tile providers. |
| `wms_endpoint_url` | string or None | WMS endpoint URL for WMS-T providers. |
| `wms_layer_name` | string or None | WMS layer identifier. |
| `tile_content_type` | string or None | MIME type of tile response (e.g., `"image/png"`). |
| `iframe_url` | string or None | Operator-configured URL for the iframe provider. Null in CAPABILITY; populated at runtime. |

**Iframe provider exception:** The `iframe` radar module uses a `make_capability()` factory function instead of a static `CAPABILITY` constant. The `iframe_url` is operator-configured at runtime and cannot be known at module-load time. All other modules use the static `CAPABILITY` pattern.

**Seeing provider exception:** The 7Timer seeing forecast provider is wired via direct import in `__main__.py`, not through the dispatch registry. It does not follow the `PROVIDER_MODULES` dispatch pattern. All other providers use the dispatch registry.

### Dispatch registry

`PROVIDER_MODULES` in `dispatch.py` is an explicit `dict[(domain, provider_id) → ModuleType]`. The registry is the canonical source of which providers exist and are active.

To add a provider:
1. Write the module file in the appropriate domain subdirectory.
2. Add an `import` of that module at the top of `dispatch.py`.
3. Add one dict entry: `("domain", "provider_id"): module_name`.

No entry-points. No runtime loading from operator config. No dynamic module discovery. The bundled set is the full set. Outside contributors open a pull request; the project reviews and merges or declines.

### ProviderHTTPClient

Each provider module instantiates **one** `ProviderHTTPClient` at module-load time — not per-request. Instantiate it as a module-level constant.

Required configuration:

| Parameter | Value |
|---|---|
| Max retries | 2 (3 total attempts) |
| Retry base delay | 0.5 s |
| Retry backoff factor | 2.0 |
| Retry delay cap | 5.0 s |
| Retry jitter | ±25% |
| `follow_redirects` | `False` (prevent token leak via accidental 30x redirect) |

Do not bypass this client by calling `httpx`, `requests`, or any other HTTP library directly. Do not instantiate per-request clients. Do not override retry parameters without an ADR.

4xx errors are **not** retried. Only 5xx responses and transport-level errors (DNS, TCP, TLS) trigger the retry loop.

---

## §2 Compliance

### End-user-managed keys

End users register and manage their own API keys with each provider. The project ships code only. Do not bundle any working API key in source, configuration examples, or test fixtures that will be committed to the repository.

### No proxied calls through a project service

Do not proxy provider API calls through any project-run infrastructure. Each operator's deployment calls providers directly using their own credentials. Two server-side proxies are allowed: (1) the API tile proxy for keyed radar providers (OpenWeatherMap) — an anti-browser-key-exposure measure within a single operator's deployment, and (2) the Caddy reverse proxy for LibreWxR — routing all tile/alert traffic through the operator's own Caddy so visitors never contact external services directly. Neither is a cross-operator proxy.

### Per-provider documentation requirements

Every provider module's `operator_notes` field and its companion entry in `docs/reference/api-docs/` must include:

- Link to the provider's Terms of Service
- Free-tier limits and rate limits
- Key signup URL and process
- Any commercial-use restrictions
- Attribution requirements

### Key absence behavior

When a required key environment variable is unset or empty, the module reports itself as disabled at startup and the rest of the service starts normally. The log line for a disabled provider must include the signup URL so the operator can enable it later. Do not raise an exception that prevents other providers or endpoints from starting.

### No telemetry

Do not add any call, log, or metric that leaks usage patterns to providers, to the project, or to third parties. Usage data stays within the operator's own deployment.

---

## §3 Caching

### Cache backends

The cache backend is pluggable. Two backends are supported:

| Backend | Use case | Config |
|---|---|---|
| `memory` | Single-worker deployments (default) | No config needed; LRU+TTL, maxsize ~1000 entries |
| `redis` | Multi-worker deployments | `CLEARSKIES_CACHE_URL=redis://localhost:6379/0` in `secrets.env` |

Multi-worker deployments **must** use Redis. If multiple uvicorn workers run with the `memory` backend, each worker maintains a separate in-memory cache and the operator's API quotas are burned proportionally to the worker count.

### Per-provider TTLs

Default TTLs are operator-overridable via config. Declare the default in the module's capability structure. The table below is the project default:

| Domain / endpoint | Default TTL |
|---|---|
| Forecast (current, hourly, daily) | 30 min |
| Alerts | 5 min |
| AQI current reading | 15 min |
| Radar tile metadata (frame timestamps) | 5 min |
| Radar tile bytes (proxied keyed providers) | Match upstream `Cache-Control`; otherwise 5 min |
| Seeing forecast | 3 hours |

### Cache key construction

The cache key is a deterministic hash of `(provider_id, endpoint, normalized_params)`.

Normalization rules:
- Sort query parameters alphabetically by key.
- Round `lat` and `lon` to 4 decimal places before including in the hash.
- Use lowercase for all string keys.

### Cache invalidation

TTL-only. There is no manual purge endpoint at v0.1. Operators clear the cache by bouncing the service (memory backend) or running `redis-cli FLUSHDB` (Redis backend). Do not implement a purge endpoint without an ADR.

### Cache observability

Expose cache hit and miss counters in both structured logs and Prometheus metrics. Provider modules do not instrument this directly — the cache abstraction layer handles it. Do not add cache-hit logging inside provider modules.

### Background cache warming

A daemon thread pre-computes slow endpoints on configurable intervals. It reuses the same `CacheBackend` as provider response caching. The first warm pass runs at startup. A cache miss falls through to a live query — graceful degradation, never a hard dependency.

Warmer intervals and cache keys (all operator-overridable via `[cache_warmer]` in `api.conf`):

| Endpoint | Default interval | Cache key |
|---|---|---|
| Records (all-time) | 30 min | `records:all-time` |
| Records (YTD) | 30 min | `records:ytd` |
| Almanac sun-times (current year) | 6 hours | `almanac:sun-times:{year}` |
| Almanac moon-phases (current year) | 6 hours | `almanac:moon-phases:{year}` |
| AQI history | 30 min | `aqi:history` |
| Climatology monthly | 6 hours | `climatology:monthly` |
| Planets | 6 hours | `almanac:planets:{date}` |
| Eclipses | 24 hours | `almanac:eclipses` |
| Meteor showers | 24 hours | `almanac:meteor-showers:{year}` |

### Cache warmer configuration

```ini
[cache_warmer]
enabled = true
records_interval_minutes = 30
almanac_interval_minutes = 360
aqi_interval_minutes = 30
climatology_interval_minutes = 360
astronomy_interval_minutes = 360
eclipses_interval_minutes = 1440
```

---

## §4 Forecast Providers

### Day-1 provider set

Four forecast provider modules ship at v0.1:

| Module | Location | Key required | Coverage | Constraints |
|---|---|---|---|---|
| `aeris` | `providers/forecast/aeris.py` | Yes | US, Canada, Europe + global | Developer trial free tier. Operator selects forecast model: Standard (`/forecasts`) or Xcast (`/xcast/forecasts`, ML-enhanced temp/wind). Config key: `aeris_forecast_model` in `[forecast]` (default: `xcast`). Xcast applies to hourly only; daynight always uses standard. |
| `nws` | `providers/forecast/nws.py` | No (User-Agent header required) | USA only | USA-only geographic gate |
| `openmeteo` | `providers/forecast/openmeteo.py` | No (free, non-commercial) | Global | No alerts endpoint |
| `openweathermap` | `providers/forecast/openweathermap.py` | Yes | Global | Hourly/daily/alerts require One Call 3.0 subscription |

Each module is independently enable/disable. A missing key disables that provider's module only — other providers start normally.

### Geographic and feature limitations

These limitations are enforced at the module level, not the endpoint level:

- **NWS:** Disable at config time if operator's lat/lon is outside the USA. Report `GeographicallyUnsupported`.
- **OpenMeteo:** Report `FieldUnsupported` when alerts are queried. Current, hourly, and daily forecasts work normally.
- **OpenWeatherMap:** Distinguish basic-tier vs. One Call 3.0 at runtime. When the operator's key has only basic-tier access, return `FieldUnsupported` for hourly, daily, and alerts.

### Hidden data behavior

When no configured provider supplies a given data type (e.g., all configured providers lack an alerts endpoint), the dashboard hides that panel. Do not render any "no provider configured" message on the dashboard. Do not add explanatory text for absent data — absence is the correct rendering.

### Normalizer contract

Every forecast provider module must implement these five callables:

| Callable | Returns |
|---|---|
| `normalize_current(raw)` | Canonical current-conditions object |
| `normalize_hourly(raw)` | List of canonical hourly forecast objects |
| `normalize_daily(raw)` | List of canonical daily forecast objects |
| `normalize_discussion(raw)` | Canonical `ForecastDiscussion` object or `None` |
| `normalize_alerts(raw)` | List of canonical `AlertRecord` objects or empty list |

Return types reference the canonical model in `contracts/canonical-data-model.md`. Do not add callables beyond this set without updating this manual.

### NWS forecast text pass-through

When the operator selects NWS as the forecast provider, the `detailedForecast` field from the NWS response is passed through directly to the API response. The GFE text generation engine is NOT invoked. English only. NWS does not provide granular hourly forecast data through its public API — the `/gridpoints/{office}/{x},{y}/forecast` endpoint returns pre-composed period narratives, not the gridded data the text engine needs. (ADR-082, settled decision #7)

### Forecast text generation — cross-provider field matrix

The GFE text engine (API-MANUAL §15) generates forecast narratives from provider hourly data. This matrix documents which hourly and daily fields each provider supplies for text generation. When a provider does not supply a field, the text engine omits the corresponding phrase — it does not fabricate data.

**Hourly forecast fields for text generation:**

| Field | Xweather | NWS | Open-Meteo | OWM | Text engine use |
|---|---|---|---|---|---|
| `outTemp` | Y | Y | Y | Y | Temperature phrases |
| `outHumidity` | Y | — | Y | Y | Fire weather (humidity recovery) |
| `windSpeed` | Y | Y | Y | Y | Wind phrases |
| `windDir` | Y | Y | Y | Y | Wind direction |
| `windGust` | Y | — | Y | Y | Gust phrases (> sustained + 10 mph) |
| `precipProbability` | Y | Y | Y | Y | PoP qualification + coverage derivation |
| `precipAmount` | Y | — | Y | Y | Coverage language, snow accumulation |
| `precipType` | Y | Y | Y | Y | Weather type phrases |
| `cloudCover` | Y | — | Y | Y | Sky phrases (6-bucket table) |
| `weatherCode` | Y | Y | Y | Y | Weather type hierarchy, LAL heuristic |
| `feelsLike` | Y | — | Y | Y | Extreme temperature descriptors (heat index / wind chill) |

**Daily forecast fields for text generation:**

| Field | Xweather | NWS | Open-Meteo | OWM | Text engine use |
|---|---|---|---|---|---|
| `tempMax` / `tempMin` | Y | Y | Y | Y | Temperature decade phrasing |
| `snowAmount` | Y | — | Y | Y | Snow accumulation phrases |
| `iceAccumulation` | Y | — | — | — | Ice accumulation phrases |
| `humidityMax` / `humidityMin` | Y | — | Y | Y/— | Fire: humidity recovery |
| `narrative` | Y | Y (`detailedForecast`) | — | Y | NWS pass-through |

**NWS is the thinnest provider** for text engine fields. Its default `/forecast/hourly` endpoint provides only temperature, wind (as string), precip probability, weather icon/text. It does not supply humidity, wind gust, precip amount, cloud cover, visibility, UV, dewpoint, or feels-like without using the raw `/gridpoints` endpoint (out of scope). This is why NWS uses pass-through instead of the text engine.

### Fields available from provider APIs but not yet mapped

ADR-082 added canonical `HourlyForecastPoint`/`DailyForecastPoint` fields for `feelsLike` and `iceAccumulation`. Both are mapped in the provider modules as of commit eb64bf3 — see the tables above for provider coverage. `dewpoint` remains the one relevant field with no canonical mapping:

| Field | Xweather | Open-Meteo | OWM | Status |
|---|---|---|---|---|
| `dewpoint` (hourly) | Wire model parses, discards | Available as `dew_point_2m` (not yet requested) | Wire model parses, discards | No canonical field yet — future work |

### Fire weather data availability

Fire weather text phrases (ADR-082) are tiered by data availability:

| Tier | Data needed | Xweather | Open-Meteo | OWM | NWS | Status |
|---|---|---|---|---|---|---|
| 1 (active) | `outHumidity` (hourly) | Y | Y | Y | — | Humidity recovery phrases active for 3 of 4 providers |
| 1 (active) | Thunderstorm weather codes | Y | Y | Y | Y | LAL heuristic active for all providers |
| 2 (dormant) | 850mb/700mb temp + dewpoint | — | Available (`pressure_level` API) but not yet fetched | — | — | Haines Index — requires Open-Meteo pressure-level vars to be added to `_HOURLY_VARS` |
| 3 (dormant) | Boundary layer height, transport wind | — | Available (`boundary_layer_height`, pressure-level winds) but not yet fetched | — | — | Smoke Dispersal / VentRate — future provider expansion |

### Marine data availability

No current provider module fetches marine forecast data. The following provider endpoints exist for future work:

| Provider | Endpoint | Data available | Status |
|---|---|---|---|
| Xweather | `/maritime` | Marine forecasts, wave data, sea temp | Endpoint exists; no module built. Xweather also has `/tides` for tidal data. |
| Open-Meteo | Marine Weather API (`marine-weather-api`) | Wave height, wave direction, wave period, swell height, ocean current | Separate API base URL; no module built. |

Marine phrase tables (wave height, chop, marine wind) are built in `sse/gfe/marine_phrases.py` and dormant until a provider module supplies the data.

---

## §5 Air Quality

### Two operator paths

Operators supply AQI data through one of two independent paths:

**Path A — weewx archive columns:** The operator runs their own weewx extension that writes AQI columns to the archive. At setup, they map those columns to canonical AQI fields via the column-mapping wizard step. Clear Skies never sees the extension; it queries the archive the same way it queries any other observation columns.

**Path B — API provider module:** The operator selects an AQI provider in the setup wizard. The corresponding module handles the API call and canonical translation.

The two paths do not coordinate. An operator can use both simultaneously.

### Day-1 AQI provider set

| Module | Location | Key required | Coverage | Data type | Haze-eligible |
|---|---|---|---|---|---|
| `aeris` | `providers/aqi/aeris.py` | Yes | Global; 8 regional AQI scales | Observed (monitoring networks) | Yes |
| `iqair` | `providers/aqi/iqair.py` | Yes | Global; US EPA and China MEP scales | Observed (monitors + crowd-sourced) | Yes |
| `openmeteo` | `providers/aqi/openmeteo.py` | No | Global; US EPA and European AQI | Model-based (CAMS forecast) | No |

**Removed (Phase 2 API removals):** `openweathermap` — OWM AQI returned SILAM model
predictions, not observed PM data; removed entirely rather than merely deprecated.
`openaq` — orphaned module, never wired into the dispatch registry or offered in the
wizard; deleted. Neither module exists in the codebase any longer. (OpenAQ remains in
use as the haze-calibration bootstrap data source — a separate feature; see
OPERATIONS-MANUAL §Haze calibration bootstrap.)

### Observed vs model data classification

Haze detection (ADR-067) requires *observed* PM2.5/PM10 — actual measurements from monitoring stations, not atmospheric model predictions. Providers that return model or forecast PM data cannot confirm that particulate matter is physically present at the station at the time of observation; they predict what should be present based on emissions inventories and atmospheric transport modeling.

The `is_observed_source` capability flag on each provider module controls haze eligibility. The haze detection engine ignores PM2.5 and PM10 values from any provider where `is_observed_source = False`.

| Provider | `is_observed_source` | Data origin |
|---|---|---|
| `aeris` | `True` | Blended real-time monitoring networks (observed) |
| `iqair` | `True` | Monitoring stations + crowd-sourced sensors (observed) |
| `openmeteo` | `False` | CAMS global atmospheric composition model (forecast) |

Operators may still configure model-based providers for general AQI display. Only the haze detection engine enforces the `is_observed_source` gate; the AQI card renders normally regardless of which provider is configured.

### Multi-jurisdiction AQI — pass-through architecture

Providers compute AQI natively using their own regional scale. Pass through what they return. Do not compute AQI from raw concentrations (the EPA-breakpoint computation in `_units.py` — originally added for OWM AQI, retained as a shared utility after OWM AQI's removal — is the only permitted exception).

`aqiScale` carries the provider's actual scale identifier. `aqiCategory` passes through from the provider's response — do not set it to null. Possible scale values include `"airnow"`, `"india"`, `"eaqi"`, `"caqi"`, `"uk"`, `"de"`, `"cai"`, `"mep"`.

Do not drop any pollutant field. All eight pollutant fields must be passed through when the provider returns them:

| Canonical field | Pollutant |
|---|---|
| `pollutantPM25` | PM2.5 |
| `pollutantPM10` | PM10 |
| `pollutantO3` | Ozone |
| `pollutantNO2` | Nitrogen dioxide |
| `pollutantSO2` | Sulfur dioxide |
| `pollutantCO` | Carbon monoxide |
| `pollutantNO` | Nitric oxide |
| `pollutantNH3` | Ammonia |

### Provider-specific regional configuration

Each AQI provider that supports multiple scales requires an operator-configurable setting:

| Provider | Setting | Valid values | Default |
|---|---|---|---|
| Xweather (`aeris`) | `aeris_aqi_filter` | `airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai` | `airnow` |
| OpenMeteo | `openmeteo_aqi_index` | `us_aqi`, `european_aqi` | `us_aqi` |
| IQAir | `iqair_aqi_scale` | `us`, `cn` | `us` |

Pass the configured setting as the appropriate query parameter on each API call. Xweather (`aeris`): `filter=`. OpenMeteo: determines which variable name to request. IQAir: determines whether to read `aqius` or `aqicn`.

The setup wizard auto-suggests the regional setting based on the operator's station lat/lon → country lookup.

### Xweather AQI provider

**Module:** `providers/aqi/aeris.py`  
**`is_observed_source`:** `True`

**Endpoint:** Xweather conditions endpoint — `GET /conditions/{lat},{lon}` — returns current air quality with PM2.5, PM10, O3, NO2, SO2, and CO values alongside the composite AQI and scale.

**Auth:** Reuses existing Xweather credentials. The module reads `AERIS_CLIENT_ID` and `AERIS_CLIENT_SECRET` from `secrets.env` — the same credential pair used by the forecast module. No additional key registration is required if the operator already has a Xweather forecast subscription.

**Rate limits:** Per Xweather subscription tier. PWSWeather Contributor Plan (free for PWS data contributors): 1,000 API accesses/day at 100/minute. Air quality endpoints count as standard API accesses (1x multiplier for current conditions; the archive endpoint carries a 5x multiplier — see §3 cache warming).

**Regional configuration:** The `aeris_aqi_filter` setting in `[aqi]` selects the AQI scale (default: `airnow`). Valid values: `airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai`. Passed as the `filter=` query parameter on each API call.

**Canonical field mapping:**

| Xweather wire field | Canonical field | Notes |
|---|---|---|
| `periods[0].aqi` | `aqi` | Composite AQI for the selected scale |
| `periods[0].category.p` | `aqiCategory` | Pass through as-is |
| `periods[0].pollutants[N].valueUGM3` where `type == "pm25"` | `pollutantPM25` | µg/m³; pollutants is an array of typed objects, not keyed by name |
| `periods[0].pollutants[N].valueUGM3` where `type == "pm10"` | `pollutantPM10` | µg/m³ |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "o3"` | `pollutantO3` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "no2"` | `pollutantNO2` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "so2"` | `pollutantSO2` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "co"` | `pollutantCO` | Convert ppb to ppm |

**`is_observed_source = True`** — Xweather blends real-time data from monitoring networks. PM2.5 and PM10 values are observed concentrations eligible for haze confirmation.

**ToS:** https://www.xweather.com/legal/terms  
**Key signup:** https://www.pwsweather.com/contributor-plan/ (free for PWS contributors) or https://www.xweather.com/

### AQI provider recommendation hierarchy

| Priority | Provider | Key cost | Latency | AQI index | Haze-eligible | Notes |
|---|---|---|---|---|---|---|
| 1 | `aeris` | Free for PWS contributors | Minutes | Yes (8 scales) | Yes | Recommended default. Free via PWSWeather Contributor Plan; returns composite AQI + full pollutant suite from observed monitoring networks. |
| 2 | `iqair` | Paid | Minutes | Yes (US EPA, China MEP) | Yes | Gold standard for latency and data quality. Proprietary network + government monitors. Use when accuracy is the priority and budget allows. |
| 3 | `openmeteo` | Free | Hours | Yes (US EPA, European) | No | Model-based (CAMS). No observed data; not haze-eligible. Use only when no observed provider is available and haze detection is not required. |

### Per-pollutant sub-index pass-through

All three active AQI providers (Xweather, Open-Meteo, IQAir Startup+) compute per-pollutant sub-AQI values server-side and return them on the wire. The `pollutantSubIndices` field on `AQIReading` passes these through as a dict keyed by canonical pollutant id (`"PM2.5"`, `"PM10"`, `"O3"`, `"NO2"`, `"SO2"`, `"CO"`). Values are numeric sub-AQI on the same scale as the main `aqi` field, capped at 500.

| Provider | Source | Keys |
|----------|--------|------|
| Xweather (`aeris`) | `pollutants[].aqi` per entry | 6 (all standard pollutants) |
| Open-Meteo (US) | `us_aqi_pm2_5`, `us_aqi_pm10`, etc. | 6 |
| Open-Meteo (European) | `european_aqi_pm2_5`, `european_aqi_pm10`, etc. | 5 (no CO in EAQI formula) |
| IQAir (Startup+) | `{p2,p1,o3,n2,s2,co}.aqius` or `.aqicn` | Variable (only pollutants with data at the station) |
| IQAir (free Community) | — | `null` (no per-pollutant objects on free tier) |
| weewx Path A | — | `null` (archive columns have no sub-index concept) |

This is a pass-through — no AQI breakpoint computation on the Clear Skies side. Anti-pattern #11 ("Computing AQI from raw concentration breakpoints") still applies.

### AQI card rendering

The AQI card always renders on the Now page. When `aqi` is null (no provider configured, or provider returned no data), render the "no data" placeholder. Do not conditionally remove the AQI card from the layout.

---

## §6 Almanac

### Data source

All almanac calculations run server-side using **Skyfield** (https://rhodesmill.org/skyfield/), MIT-licensed, with NASA JPL DE421 ephemerides (~17 MB, bundled or downloaded on first run). Do not use `pyephem` — it is unmaintained.

Calculations are stateless given (lat, lon, time). Expensive computations (sun-times, moon-phases, planets, eclipses, meteor showers) are pre-computed by the background cache warmer (§3) on 6-hour or 24-hour intervals. Cache misses fall through to live Skyfield computation — never a hard dependency.

### Almanac endpoints

| Endpoint | Description |
|---|---|
| `GET /almanac` | Snapshot: today's sun/moon data |
| `GET /almanac/sun-times` | Year series: rise/set/transit/twilight for each day |
| `GET /almanac/moon-phases` | Year grid: new/first/full/last quarter dates |
| `GET /almanac/seeing-forecast` | 7Timer ASTRO seeing forecast (proxied) |
| `GET /almanac/planets` | Planet positions, visibility, and viewing quality |
| `GET /almanac/moon-names` | Cultural moon names for full moons in the year |
| `GET /almanac/eclipses/lunar` | Lunar eclipse list with visibility tiers |
| `GET /almanac/eclipses/solar` | Solar eclipse list with visibility tiers |
| `GET /almanac/meteor-showers` | Meteor shower list with viewing quality tiers |
| `GET /almanac/positions` | Current sky positions for sun, moon, planets |

Default twilight definition: **civil**. Do not change this default without an ADR.

### Visibility ranking — unified 5-tier color scale

All almanac visibility ratings use the same color scale. The tier label set is: Excellent, Good, Fair, Poor, Not Visible.

| Tier | Label | Color | Hex |
|---|---|---|---|
| 1 (best) | Excellent / Fully Visible | Green | `#22c55e` |
| 2 | Good / Mostly Visible | Lime | `#84cc16` |
| 3 | Fair / Partially Visible | Yellow | `#eab308` |
| 4 | Poor / Barely Visible | Orange | `#f97316` |
| 5 (worst) | Not Visible | Red | `#ef4444` |

Do not invent additional tiers. Do not use different colors for different event types.

### Solar eclipse visibility tiers

Solar eclipses use 4 tiers (no "Not Visible" tier — AstronomyAPI.com only returns eclipses whose shadow reaches the observer's location).

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/sun`). Use `output=rows` query parameter to get `data.rows[].events[]` structure.

**Important:** AstronomyAPI.com returns `extraInfo.obscuration` as a 0–1 fraction. Multiply by 100 before applying the thresholds below.

| Tier | Condition |
|---|---|
| 1 Green | `totalStart` is non-null (observer is in path of totality or annularity) |
| 2 Lime | Obscuration O ≥ 75% |
| 3 Yellow | 10% ≤ O < 75% |
| 4 Orange | O < 10% |

**Graceful degradation:** When AstronomyAPI.com credentials are not configured, return eclipse dates and types from Skyfield only. Set visibility tier to null. Do not crash.

### Lunar eclipse visibility tiers

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/moon`). Use `output=rows` query parameter.

Tier computation is based on peak altitude A at the observer's location and contact altitudes:

| Tier | Condition |
|---|---|
| 1 Green | Peak A > 15° AND all contact altitudes > 0° |
| 2 Lime | Peak A > 15° AND some contacts < 0° |
| 3 Yellow | 0° < Peak A ≤ 15° |
| 4 Orange | 0° < Peak A ≤ 5° |
| 5 Red | Peak A ≤ 0° (eclipse entirely below horizon) |

### Meteor shower visibility tiers

**Data source:** Skyfield (radiant altitude R, moon illumination M at peak date). Static shower catalog from IMO/AMS (ZHR, velocity, radiant RA/Dec, descriptions).

| Tier | Condition |
|---|---|
| 1 Green | R > 40° AND M < 25% |
| 2 Lime | R > 20° AND M < 50% (and not tier 1) |
| 3 Yellow | R > 10° AND (M ≥ 50% OR R ≤ 40°) (and not tier 1 or 2) |
| 4 Orange | R ≤ 10° OR (M > 75% AND R ≤ 30°) |
| 5 Red | R < 0° (radiant never rises at this latitude) |

### Planet viewing quality

**Formula:** `score = (seeing_score × 0.80) + (transparency_score × 0.05) + (altitude_score × 0.15)`

Special gates (applied before the score formula):
- Cloud gate: `cloudcover > 6` → Not Visible (tier 5). Do not compute a score.
- Mercury elongation gate: elongation < 12° → Not Visible. Elongation 12°–18° → cap result at Good (tier 2).
- Uranus/Neptune moon penalty: apply when applicable.

Score → tier mapping:

| Score | Tier |
|---|---|
| ≥ 0.75 | 1 Excellent |
| 0.50–0.74 | 2 Good |
| 0.30–0.49 | 3 Fair |
| < 0.30 | 4 Poor |

**Data sources:**
- Seeing and cloud cover: 7Timer ASTRO product (`GET /almanac/seeing-forecast`)
- Planet altitude, elongation, magnitude: Skyfield

### Eclipse query window and progressive fill

Both eclipse endpoints default to a **10-year window (3652 days)**.

Dashboard progressive fill rule (max 4 columns, no horizontal scroll):
1. Filter to eclipses within the next 2 years.
2. If the 2-year set fills or exceeds 4 columns, show only the first 4.
3. If fewer than 4 in the 2-year window, backfill from the full 10-year set until 4 columns are filled or data runs out.

### Data provenance

| Data | Source |
|---|---|
| Solar/lunar eclipse dates and types | Skyfield `eclipselib` |
| Eclipse contact times, altitudes, obscuration | AstronomyAPI.com Events endpoint (optional) |
| Meteor shower ZHR, velocity, radiant RA/Dec | IMO Meteor Shower Working List (static catalog) |
| Meteor shower descriptions | IMO + AMS published characteristics |
| Meteor shower radiant altitude | Skyfield (computed per observer location and peak date) |
| Meteor shower moon illumination | Skyfield (computed for peak date) |
| Planet positions, altitude, elongation, magnitude | Skyfield |
| Planet seeing forecast | 7Timer ASTRO product |

---

## §7 Radar

### Map library

Use **Leaflet** with **OpenStreetMap** base tiles. OSM attribution is required. Do not use MapLibre — it is a heavier WebGL stack with no advantage for the use cases here.

### Day-1 radar provider modules

Modules in `providers/radar/`:

| Module | Type | Key required | Coverage | Status |
|---|---|---|---|---|
| `rainviewer` | XYZ tiles (browser-direct to CDN) | No | Global mosaic | **Default.** Degraded since Jan 2026: zoom 7 max, no nowcast, single color scheme (Universal Blue), PNG only. |
| `librewxr` | XYZ tiles (Caddy-proxied) | No | Global (public API) or operator-defined (self-hosted) | **Optional upgrade.** Zoom 12, 13 color schemes, WebP, 60-min nowcast, satellite, weather alerts. |
| `openweathermap` | XYZ tiles (API-proxied) | Yes | Global — labeled "Model precipitation" in UI, NOT "Radar" | Active |
| `msc_geomet` | WMS-T | No | Canada national mosaic (Environment Canada) | Active (not in wizard — regional) |
| `dwd_radolan` | WMS-T | No | Germany RADOLAN (DWD GeoWebService) | Active (not in wizard — regional) |
| `iframe` | Iframe | Operator-supplied URL | Operator-defined (BoM Australia, MetService NZ, etc.) | Active |
| `iem_nexrad` | WMS-T | No | US CONUS NEXRAD (Iowa Environmental Mesonet) | **Deprecated.** Logs migration warning. Raw imagery too noisy — use LibreWxR instead. |
| `noaa_mrms` | WMS-T | No | US AK / HI / PR / Guam (NOAA MapServer) | **Deprecated.** Logs migration warning. Raw imagery too noisy — use LibreWxR instead. |

**Removed from radar domain:** `aeris` — 3,000 map units/day is unviable for radar tiles. Xweather is retained for forecast, AQI, and alerts domains.

### Tile routing model

Three routing patterns exist depending on the provider:

| Pattern | Providers | How it works |
|---|---|---|
| **Caddy-proxied** | `librewxr` | Caddy reverse-proxies `/librewxr/*` to the LibreWxR instance (public API or self-hosted). Browser talks to Caddy only. API never touches tile or alert traffic — it provides metadata (capabilities, frame lists) only. |
| **API-proxied** | `openweathermap` | API proxies tile requests server-side via `GET /api/v1/radar/providers/{id}/tiles/{z}/{x}/{y}`. API keys never reach the browser. |
| **Browser-direct** | `rainviewer`, `msc_geomet`, `dwd_radolan` | Browser fetches tiles directly from the provider CDN/WMS. No proxy involved. |

**Frame metadata for all providers:** `GET /api/v1/radar/providers/{id}/frames` — API fetches upstream metadata, normalizes to canonical `RadarFrameList`, caches.

### LibreWxR module rules

- **Configurable upstream:** `[radar] librewxr_endpoint` in `api.conf`. Default: `https://api.librewxr.net` (public API, no SLA). Operators can point to a self-hosted instance.
- **Metadata fetch:** `GET {endpoint}/public/weather-maps.json` — RainViewer v2-compatible wire format. Cached 60 seconds. Parses both `radar` and `satellite.infrared` frames.
- **Satellite frames:** The LibreWxR module parses `satellite.infrared` frames from `weather-maps.json` and returns them as `satelliteFrames` on the `RadarFrameList` response. Source: NOAA GMGSI composite (daytime visible over longwave IR with natural terminator crossfade). Hourly cadence. Coverage: ±72.7° latitude. Staleness guard: frames older than 24 hours are filtered out.
- **No `get_tile()` method.** Caddy proxies tiles directly (both radar and satellite). The API never handles tile bytes for LibreWxR.
- **Capability declaration includes:**
  - Provider name and attribution string
  - Geographic bounds (bounding box from `[radar] librewxr_bounds` config, or empty = global)
  - Caddy proxy path prefix (`/librewxr`) for tiles and alerts
  - Available features: `nowcast` (bool), `color_schemes` (list of `{id, name}`), `alerts` (bool), `satelliteAvailable` (bool)
  - Tile URL template (relative to Caddy): `/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`
  - Satellite tile URL template: `{caddyPrefix}/{path}/{size}/{z}/{x}/{y}/0/0_0.webp` (via `satelliteTileUrlTemplate` field)
  - Alert URL: `/librewxr/v2/alerts`
  - Refresh interval (from `[radar] librewxr_refresh_interval` config, default 600 seconds)
- **Rate limiter:** polite-use guard (5 req/s) for weather-maps.json fetches — prevents hammering the metadata endpoint.
- **Alert overlay data:** LibreWxR `/v2/alerts` returns GeoJSON FeatureCollection with WMO CAP metadata (severity, urgency, event, headline, expiry). Supports `?bbox=` query. Routed through Caddy at `/librewxr/v2/alerts`.
- **Color schemes:** 13 schemes (IDs 0–11 + 255). List comes from `weather-maps.json` → `radar.colorSchemes`. Dashboard uses the `color` path segment in tile URLs.
- **License:** AGPL-3.0 (code), CC-BY-4.0 (data).

### RainViewer degradation note

RainViewer gutted its free API tier on 2026-01-01:
- Zoom capped at 7 (was 8+)
- Nowcast discontinued
- Single color scheme (Universal Blue only)
- PNG only (no WebP)
- 100 req/IP/min rate limit

RainViewer remains the default because it works out of the box with zero infrastructure. The wizard displays a degradation note so operators know what they're getting. Operators who want better quality upgrade to LibreWxR.

### OpenWeatherMap radar label

Always label OpenWeatherMap radar as **"Model precipitation"** in the UI, operator notes, and documentation. Never label it as "Radar." It provides model-derived precipitation data, not true radar reflectivity.

### Geographic bounds

Provider capabilities include a geographic bounding box. The dashboard enforces `maxBounds` on the Leaflet map to prevent zooming out past the provider's coverage area.

- **RainViewer:** global (no bounds restriction)
- **LibreWxR (public API):** global (no bounds restriction)
- **LibreWxR (self-hosted):** bounds from `[radar] librewxr_bounds` config (operator sets this in wizard). For BBOX-cropped instances, the bounds match the crop area.
- **No bounds configured:** map allows global zoom (default behavior)

### Setup wizard radar suggestion

The wizard suggests radar providers based on simplicity, not quality:

| Recommendation | Provider | Note |
|---|---|---|
| Primary (all regions) | `rainviewer` | Works everywhere, zero setup |
| Alternative (all regions) | `librewxr` | "Better quality — requires public API or self-hosting" |

Operator may override the suggestion freely. Regional providers (`msc_geomet`, `dwd_radolan`) are not surfaced in the wizard — they exist for operators who configure manually.

### Attribution

Render attribution per each source's terms on the radar map. Required attribution strings:

| Provider | Attribution |
|---|---|
| `rainviewer` | `"RainViewer (https://www.rainviewer.com/)"` |
| `librewxr` | `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"` |
| `openweathermap` | `"OpenWeatherMap (https://openweathermap.org/)"` |
| `msc_geomet` | `"Environment and Climate Change Canada"` |
| `dwd_radolan` | `"Deutscher Wetterdienst"` |
| Base map (always) | `"© OpenStreetMap contributors"` |

Both the in-map Leaflet attribution control and any below-map caption must agree.

Radar and seismic page attribution is handled by Leaflet attribution controls on the map. No card footer is used.

---

## §8 Alerts

### Day-1 provider set

Three alert provider modules ship at v0.1 in `providers/alerts/`. One source per deploy.

| Module | Coverage | Key required |
|---|---|---|
| `nws` | US + US territories + adjacent waters | No |
| `aeris` | US, Canada, Europe, UK, Japan, Australia, India, Brazil, South Africa, South Korea, Mexico | Yes (PWS-contributor path) |
| `openweathermap` | Global government alerts | Yes (One Call 3.0 paid tier) |

### Severity model

The canonical `AlertRecord` uses a two-field severity model:

| Field | Type | Description |
|---|---|---|
| `severityLevel` | `int \| null` | Integer 1–4 (1 = lowest, 4 = highest). Used for sorting, filtering, ARIA urgency. |
| `severityLabel` | `string \| null` | Source system's native severity name (e.g., "Amber", "Warning", "Vigilance jaune"). Used programmatically; not displayed as a visual badge in the alert banner. |

The old `advisory | watch | warning` severity enum is removed. The `?severity=` query parameter filter on `/alerts` is replaced by `?minLevel=` (integer).

### Severity level mapping across national systems

| Level | NWS (US/CA) | MeteoAlarm (EU) | UK Met Office | JMA (Japan) | BoM (Australia) | IMD (India) | INMET (Brazil) | SAWS (S. Africa) | KMA (S. Korea) | SMN (Mexico) |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 (Extreme) | Warning | Red | Red | Emergency/Urgent Warning | Severe/Very Dangerous | Red | Red (Grande Perigo) | Level 9–10 | Red | Red/Purple |
| 3 (Severe) | Watch | Orange | Amber | Warning | Warning | Orange | Orange (Perigo) | Level 5–8 | Orange | Orange |
| 2 (Moderate) | Advisory | Yellow | Yellow | Advisory | Watch | Yellow | Yellow (Atenção) | Level 3–4 | Yellow | Yellow |
| 1 (Minor) | Statement | Green | — | — | Advice | Green | Gray | Level 1–2 | Green | Green |

### NWS provider severity fix

Map severity from the **event name tier** (Warning/Watch/Advisory/Statement suffix), NOT the CAP severity field. Use the event string suffix or VTEC code suffix (`.W`/`.A`/`.Y`/`.S`). Do not use `_NWS_SEVERITY_MAP` or any mapping from CAP severity values.

- Warning → `severityLevel=4`
- Watch → `severityLevel=3`
- Advisory → `severityLevel=2`
- Statement → `severityLevel=1`

### Xweather alert enrichment

The Xweather (`aeris`) provider must capture these additional fields from the wire response:

| Wire field | Canonical field |
|---|---|
| `dataSource` | `alertSystem` |
| `localLanguages[0].name` | `nativeName` |
| `details.color` | `color` |
| `details.cat` | `hazardType` |

Map Xweather suffix codes to `severityLevel`: `.EX`→4, `.SV`→3, `.MD`→2, `.MN`→1.

### OWM default mode

OWM One Call 3.0 provides no severity metadata. Set `severityLevel=2` and `severityLabel="Alert"` for all OWM alerts. This is an operator directive: if an alert exists, it warrants advisory-level visibility. Do not set null.

Operator documentation must state this quality tradeoff explicitly: OWM alerts receive level-2 advisory visibility by default, not derived from provider metadata.

### Additional canonical alert fields

| Field | Source |
|---|---|
| `alertSystem` | Xweather (`aeris`) `dataSource`, NWS literal `"nws"`, OWM `sender_name` where recognizable |
| `hazardType` | Xweather (`aeris`) `details.cat`, OWM `tags[0]` |
| `nativeName` | Xweather (`aeris`) `localLanguages[0].name` |
| `color` | Xweather (`aeris`) `details.color` (provider-recommended hex; not the national system's official color) |

### Two rendering modes

**Rich mode** (Xweather, NWS): `severityLevel` and `severityLabel` are populated. Dashboard renders severity-colored icon panel, native label in ARIA, hazard-specific icon.

**OWM default mode**: `severityLevel=2`, `severityLabel="Alert"`. Dashboard renders level-2 (yellow/advisory) icon panel, `ph:warning` icon, `role="status"` ARIA.

### Uncovered regions

For operators whose region is not covered by any configured provider, return an empty `alerts` list. The `AlertBanner` component uses a direct early-return inside the component when `alerts.length === 0`. This is not part of the category-10 sensor-availability self-hide system. No error, no placeholder message.

### Setup wizard alert suggestion

| Operator region | Suggested module |
|---|---|
| US | `nws` |
| Canada, Europe/UK, Mexico, Brazil, South Africa, India, Japan, South Korea, Australia | `aeris` |
| Elsewhere | `openweathermap` (with note on paid One Call 3.0 tier) |

### Marine zone alert extension

**Problem:** All three alerts providers query by lat/lon point. NWS marine alerts (Small Craft Advisory, Gale Warning, Storm Warning, Hurricane Force Wind Warning, Hazardous Seas, Dense Fog, Special Marine Warning, Low Water Advisory) are issued against **coastal marine zones** — water polygons with ocean-prefixed codes (AMZ, GMZ, PZZ, ANZ, PKZ, PHZ). A lat/lon point on land does not fall inside a water polygon unless it is on a narrow barrier island or pier. Any coastal station whose weewx installation is not directly on the waterline misses marine alerts — regardless of which alerts provider the operator uses.

**This is a general alerts improvement, NOT gated by the marine feature.** The marine alert radius is configured in the alerts section of the wizard/admin, not inside marine location setup. An operator who never enables marine pages still sees marine zone alerts in the standard alert banner if their station is near the coast.

**Configuration (in `api.conf [alerts]`):**

| Key | Type | Default | Description |
|---|---|---|---|
| `marine_alert_radius_miles` | float | 0.0 (disabled) | Radius for marine zone discovery. 0 = no zone queries = identical to current behavior. |
| `marine_alert_zone_ids` | list[str] | [] | Discovered zone IDs, stored after setup-time discovery. |

The wizard auto-suggests 25 miles when the station is within 50 miles of a marine zone.

**Zone discovery algorithm (setup time only, not per-request):**

1. Station lat/lon → `GET /points/{lat},{lon}` → extract `cwa` (WFO office ID)
2. `GET /zones/coastal` filtered by CWA → typically 6–16 zones per WFO
3. For each zone: `GET /zones/coastal/{zoneId}` → extract polygon geometry
4. Compute minimum haversine distance from station to each polygon's nearest vertex
5. Select zones within the operator's configured radius
6. Present discovered zones with names and distances to the operator for confirmation
7. Store confirmed zone IDs in `api.conf`

Uses the shared NWS zone discovery utility at `providers/_common/nws_zones.py` (also used by NWS marine text forecast and NWS SRF providers — see §14).

**NWS zone taxonomy:**

| Zone type | Prefix examples | What it covers | How captured |
|---|---|---|---|
| Public zones | NCZ, CAZ, FLZ | Land-based coastal areas. Beach Hazards Statement, Coastal Flood Advisory/Warning, Storm Surge Warning/Watch. | Existing `?point=` query (when station is in a coastal county) |
| Coastal marine zones | AMZ, GMZ, PZZ, ANZ, PKZ, PHZ | Nearshore waters out to 20–60 NM. SCA, Gale, Storm, Hurricane Force, Hazardous Seas, Dense Fog (marine), Special Marine Warning, Low Water Advisory. | Zone queries from this extension (required for any station not directly on the waterline) |

**Alert query changes — all three providers:**

**NWS (`providers/alerts/nws.py`):** After the existing `?point=` query, check if `marine_alert_zone_ids` is non-empty. For each configured zone: `GET /alerts/active?zone={zoneId}`. Merge results with point-based results. De-duplicate by alert `id` field. Use the same `ProviderHTTPClient`, rate limiter (5 req/s shared), and cache infrastructure. Cache key: `(provider_id, "zone", zone_id)` — distinct from point cache key. Same TTL (5 min).

**Xweather (`providers/alerts/aeris.py`):** Test whether Xweather returns marine alerts for the station's point. If not (expected for stations >1 km from water): add supplemental NWS `?zone=` queries for each configured marine zone. NWS marine zone alerts are free — this is a supplemental data source, not a provider switch. Merge and de-duplicate by alert ID.

**OWM (`providers/alerts/openweathermap.py`):** Same test-and-supplement approach. If no One Call 3.0 key available for testing, implement the NWS supplemental query unconditionally (free, no harm if OWM already returns the alerts).

**Zero-config preservation:** When `marine_alert_radius_miles = 0` (the default), no zone queries execute. The alerts provider behaves identically to the current implementation — zero regression.

---

## §9 Earthquakes

### Day-1 provider set

Four earthquake provider modules ship at v0.1 in `providers/earthquakes/`. All four need no key. One source per deploy.

| Module | Coverage | License |
|---|---|---|
| `usgs` | Global (M2.5+ globally; US-comprehensive) | Public domain |
| `geonet` | New Zealand | CC BY 3.0 NZ |
| `emsc` | Europe + Mediterranean + global | CC BY 4.0 |
| `renass` | Mainland France + neighboring countries | CC BY 4.0 |

USGS provides global coverage — there is no uncovered-region case for earthquakes.

### Setup wizard earthquake suggestion

| Operator region | Suggested module |
|---|---|
| US, Americas, global default | `usgs` |
| New Zealand | `geonet` |
| Europe, Mediterranean | `emsc` |
| France | `renass` |

### ReNASS endpoint

Use `https://api.franceseisme.fr/fdsnws/event/1/query`. The legacy endpoint `https://renass.unistra.fr/fdsnws/event/1/query` returns 404 since the EPOS-France migration. Do not reference the legacy URL anywhere.

### Canonical EarthquakeRecord fields

Required fields:

| Field | Type |
|---|---|
| `id` | string |
| `time` | ISO 8601 UTC string |
| `lat` | float |
| `lon` | float |
| `magnitude` | float |
| `source` | string (provider_id) |

Optional canonical fields:

| Field | Type |
|---|---|
| `depth` | float or null |
| `magnitudeType` | string or null |
| `place` | string or null |
| `url` | string or null |
| `tsunami` | bool or null |
| `felt` | int or null |
| `mmi` | float or null |
| `alert` | string or null |
| `status` | string or null |

Provider-specific data not listed above goes into the `extras` dict. Do not add provider-specific fields to the canonical schema — use `extras`.

**`distance` (float or null) is endpoint-computed, not provider-supplied.** The `/earthquakes` endpoint computes it as the haversine distance from the operator's station to each event's epicenter — no provider module populates it. Provider modules supply `depth` in km as usual; the endpoint converts both `depth` and `distance` to the operator's configured `group_distance` unit (mile/km) before the response is built. See API-MANUAL.md §2 "Earthquake fields".

### Provider-specific canonical mappings

These wire fields map to canonical fields directly — do not put them in `extras`:

| Provider | Wire field | Canonical field |
|---|---|---|
| GeoNet | `mmi` (lowercase) | `mmi` |
| EMSC | `flynn_region` | `place` |

### Per-provider extras keys

| Provider | `extras` keys |
|---|---|
| `usgs` | `cdi`, `sig`, `net`, `code`, `ids`, `sources`, `types`, `nst`, `dmin`, `rms`, `gap`, `type`, `title` |
| `geonet` | `quality` |
| `emsc` | `evtype`, `auth`, `source_id`, `source_catalog`, `lastupdate` |
| `renass` | `type`, `description_fr`, `url_fr` |

Only include `extras` keys when the value is non-null in the provider response.

### GEM Global Active Faults overlay

The seismic faults overlay is not a provider module. It is served from a bundled GeoJSON file at `GET /api/v1/earthquakes/faults`, radius-clipped to the operator's configured earthquake radius.

- Data: GEM Global Active Faults Database, CC-BY-SA 4.0
- Required attribution: `"Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0"`
- Render attribution in both the in-map Leaflet attribution control and in a below-map caption
- The below-map caption is hidden when the fault layer is toggled off
- Fault toggle: default on (`showFaults` initialized `true`)
- Fault trace style: uniform amber, no fault-type differentiation
- Fault popups: `feature.properties.name` + `feature.properties.slip_type`; both fall back to localized "unknown" when absent
- Updates: periodic manual refresh from GEM GitHub — no auto-update mechanism

---

## §9a Geographic Features — REMOVED (ADR-078, deleted M5 — ADR-078 Amendment 2, Accepted 2026-08-27)

The original ADR-078 single-file PMTiles overlay (`endpoints/geographic_features.py`,
`services/geographic_features.py`, the `[geographic_features]` api.conf section, the three routes
`GET /api/v1/geographic-features/tiles`, `GET /api/v1/geographic-features/status`, `POST
/setup/geographic-features/update`) is deleted. Superseded entirely by the `[basemap]` family — see
the "Basemap" entries in ARCHITECTURE.md and API-MANUAL.md §12b.

---

## §10 Error Taxonomy

### Canonical error types

All provider modules raise from this closed set. No other exception types may cross the module boundary.

| Error type | Meaning |
|---|---|
| `QuotaExhausted` | Rate-limit or daily cap hit; transient, retry after backoff |
| `KeyInvalid` | Authentication failure; permanent until operator updates config |
| `GeographicallyUnsupported` | Provider does not cover the operator's location |
| `FieldUnsupported` | Provider does not supply the requested data type |
| `TransientNetworkError` | DNS, TCP, TLS failure, or HTTP 5xx; retry with backoff |
| `ProviderProtocolError` | Unexpected response format (provider changed API silently); requires module update |

Do not catch and re-wrap these with generic Python exceptions. Do not let upstream provider exception types (e.g., `httpx.HTTPStatusError`, `requests.RequestException`) propagate past the module boundary.

### Error base class fields

Every canonical error carries:

| Field | Type | Description |
|---|---|---|
| `provider_id` | string | Which provider raised the error |
| `domain` | string | Which domain was being queried |
| `retry_after_seconds` | int or None | Present on `QuotaExhausted` when the provider supplies a `Retry-After` value |
| `status_code` | int or None | HTTP status code, for HTTP-boundary dispatch |

### Error → HTTP status mapping

| Error type | HTTP status | Notes |
|---|---|---|
| `QuotaExhausted` | 503 | Include `Retry-After` response header when `retry_after_seconds` is non-null |
| `GeographicallyUnsupported` | 503 | |
| `KeyInvalid` | 502 | |
| `FieldUnsupported` | 502 | |
| `TransientNetworkError` | 502 | |
| `ProviderProtocolError` | 502 | Log at ERROR level for triage; indicates module needs an update |

### Retry behavior

- 4xx errors: **never retried**. They indicate a permanent condition (bad key, bad request, geography gate).
- 5xx errors and transport errors: retried per the `ProviderHTTPClient` backoff policy (§1).
- `ProviderProtocolError`: not retried; log at ERROR and propagate.

---

## §11 Testing Pattern

### Fixture-first approach

Every provider module requires recorded fixtures of real provider API responses committed to the test suite. Fixtures live at:

```
tests/fixtures/providers/{provider_id}/
```

Use real response shapes. Do not construct synthetic fixtures from guesswork — capture from live API calls during initial module development, then commit. Use a real-capture fixture or the L3 synthetic-from-real fallback (documented in the test author's agent definition) when live-network access is unavailable during CI.

### Test file layout

Test files follow the nested pattern:

```
tests/providers/{domain}/test_{provider_id}.py       # Unit tests (parser)
tests/test_providers_{domain}_{provider_id}_integration.py  # Integration tests
```

Do not create flat test files at `tests/test_providers_{domain}_{provider_id}_unit.py` — the nested pattern is the project standard.

### Parser unit tests

Load the recorded fixture. Assert canonical field translation is correct:
- Units are converted correctly
- Identifiers are normalized to canonical form
- Times are in ISO 8601 UTC format with `Z` suffix
- Scale values match the expected canonical scale identifier
- `extras` dict contains only keys documented in §9 (for earthquake modules)
- Null fields are null, not absent, not empty string

### Mock-network tests

Use `respx` (or equivalent) to mock HTTP responses without live network calls. Verify:
- Authentication parameters are present and correctly formatted
- Rate-limit response (HTTP 429) raises `QuotaExhausted`
- Auth failure (HTTP 401/403) raises `KeyInvalid`
- HTTP 5xx raises `TransientNetworkError`
- Unexpected response shape raises `ProviderProtocolError`
- `retry_after_seconds` is populated when `Retry-After` header is present

### No live-network tests in CI

Live-network tests exist in the test suite but are gated behind an explicit environment variable or pytest marker (e.g., `@pytest.mark.live_network`). The CI pipeline never sets the enabling variable. The default `pytest` run (no markers, no env vars) never makes a live network call.

Developer-local live tests are permitted and encouraged for initial fixture capture and regression verification.

---

## §12 Provider Attribution

### Two-layer attribution model

| Layer | Location | Format | Scope |
|---|---|---|---|
| **About page** | Centralized provider index | Plain text links, no logos, no marketing language | All dynamic providers (from capabilities API) + static providers always shown |
| **In-context card footer** | Card displaying that provider's data | Provider-specific ToS wording from capabilities API | Driven by capabilities API `attribution` block — host renders when `attributionRequired` is true |

**About page:** Plain-text link list. No logos, no marketing copy. Provider lookup is via the capabilities API's `attribution.displayName` and `attribution.url` fields. Static entries (infrastructure providers not in the capabilities API) are listed separately.

**In-context card footers:** Rendered by the host page using the `ProviderAttribution` component (`src/components/shared/ProviderAttribution.tsx`). Each provider's footer shows its ToS-mandated `attributionText` from the capabilities API. Sized by card type:

| Card type | Logo variant | Size |
|---|---|---|
| Wide / full cards | Standard | 32px |
| Tiles | Compact | 16px |
| Alert banner (expanded detail) | Text-only | N/A |

### Provider logo requirements

| Provider | Logo required by ToS | Logo available | Theme variants |
|---|---|---|---|
| Xweather | Yes (mandatory) | SVG dark + light | Swapped via `dark:` classes |
| OpenWeatherMap | Yes (Free–Professional tiers) | PNG master + negative | Swapped via `dark:` classes |
| NWS | No | SVG (circular seal) | Same both themes |
| Open-Meteo | No | PNG (app icon) | Same both themes |
| IQAir | Do not use (ToS reserves rights) | N/A | Text-only: "Powered by IQAir" |
| AstronomyAPI | Do not use (ToS §12.2) | N/A | N/A |

Provider module authors populate attribution in their CAPABILITY declaration (`ProviderAttribution` dataclass in `providers/_common/capability.py`). The dashboard reads it from `GET /api/v1/capabilities`. See API-MANUAL §12 for the full schema.

Logo assets live at `public/providers/` in the dashboard repo, named by `{provider_id}.{ext}` convention.

### Attribution not required

| Source | Reason |
|---|---|
| Station data | Operator's own sensors |
| Skyfield | MIT license |
| NASA JPL (DE421 ephemerides) | Public domain |
| 7Timer | No formal ToS |
| USGS | Public domain; credit recommended but not required |

---

## §13 Anti-Patterns

The following patterns are forbidden. Any pull request introducing them must be rejected.

| Anti-pattern | Why forbidden |
|---|---|
| Bundling API keys in source, config templates, or committed fixtures | Violates ADR-006; every provider ToS prohibits key redistribution |
| Proxying provider calls through a project-run service | Violates ADR-006; creates project-level liability and uptime obligation |
| Leaking upstream provider exception types past the module boundary | Breaks the canonical error taxonomy; callers must not handle provider-specific errors |
| Live-network calls in CI tests | Makes CI non-deterministic and quota-burning; use fixtures and `respx` mocks |
| Hardcoding EPA AQI lookup tables, Beaufort scale, or other domain-wide helpers inside a provider module | These belong in the canonical-model package; duplicating them in providers creates drift |
| A single module spanning multiple data domains (e.g., one Xweather module that handles both forecast and AQI) | Violates "one module = one domain"; modules must be independently enable/disable per domain |
| Subclassing a shared `ProviderBase` or any other abstract base class | Rejected pattern; the project uses flat modules with a documented contract, not a class hierarchy |
| Storing credentials in `.conf` files | Credentials go in `secrets.env` as environment variables only; `.conf` files are world-readable on many deployments |
| Bypassing `ProviderHTTPClient` with a direct `httpx` or `requests` call | The shared client provides retry, backoff, follow_redirects=False, and dual-stack — these must not be bypassed |
| Per-request client instantiation | Instantiate `ProviderHTTPClient` once at module-load time; per-request instantiation wastes resources and bypasses connection pooling |
| Setting `follow_redirects=True` on any provider HTTP call | Redirects can leak auth tokens to a third-party destination |
| Computing AQI from raw concentration breakpoints (beyond the existing EPA-breakpoint path in `_units.py`) | The project is a dashboard, not an AQI computation service; providers compute AQI natively |
| Implementing a purge/invalidation endpoint for the cache | No manual purge at v0.1; requires an ADR |
| Using `pyephem` for almanac calculations | Unmaintained; Skyfield is the mandated library |
| Referencing the legacy ReNASS endpoint `renass.unistra.fr` | Returns 404 since EPOS-France migration; use `api.franceseisme.fr` |
| Labeling OpenWeatherMap radar as "Radar" | It is model precipitation data; must be labeled "Model precipitation" |
| Adding a `mapbox_jma` module | Dropped from day-1 set — Mapbox JMA tilesets are raster-array / GL-JS-only, incompatible with Leaflet |
| Routing LibreWxR tile traffic through the API | Caddy proxies LibreWxR tiles and alerts directly; the API provides metadata only. Routing tiles through the API wastes resources and adds latency. |
| Adding `aeris` as a radar provider | Removed — 3,000 map units/day is unviable for radar tiles. Xweather is retained for forecast/AQI/alerts only. |

---

## §14 Marine & Coastal Providers

Six provider modules across three existing domains (`"marine"`, `"tides"`, `"buoy"`) plus two providers in the new `"ocean"` domain (ADR-091), two service-layer components (ocean data resolver, water level compositor), one data-access component (bathymetry), and one shared utility (NWS zone discovery). All v1 marine providers are NOAA sources — free, keyless, US-only. Each module follows the §1 Module Contract.

**Ocean domain (ADR-091, 2026-07-13):** Two provider modules + one resolver + one compositor service for ocean model data. The resolver provides a provider-agnostic interface — endpoints call the resolver, never the ocean providers directly. The compositor combines CO-OPS tidal predictions with OFS meteorological water level signals. See §14.10–§14.13.

### Provider set

| Module | File | `PROVIDER_ID` | `DOMAIN` | Source | Key required |
|---|---|---|---|---|---|
| NDBC buoy observations | `providers/buoy/ndbc.py` | `ndbc` | `buoy` | NOAA NDBC | No |
| CO-OPS tides & water levels | `providers/tides/coops.py` | `coops` | `tides` | NOAA CO-OPS | No |
| WaveWatch III forecasts | `providers/marine/wavewatch.py` | `wavewatch` | `marine` | NOAA WaveWatch III via ERDDAP | No |
| NWS marine zone text | `providers/marine/nws_marine.py` | `nws_marine` | `marine` | NWS API | No |
| NWS Surf Zone Forecast | `providers/marine/nws_srf.py` | `nws_srf` | `marine` | NWS API (SRF text product) | No |
| ~~NWPS nearshore wave data~~ | ~~`providers/marine/nwps.py`~~ | — | — | Eliminated (ADR-093). Replaced by SWAN. | — |
| HRRR wind | `providers/wind/hrrr.py` | `hrrr` | `wind` | NOAA HRRR GRIB2 via NOMADS | No |
| SWAN runner | `providers/nearshore/swan.py` | `swan` | `nearshore` | Local SWAN subprocess (ADR-096 renamed) | No |
| OFS ocean model data | `providers/ocean/ofs.py` | `ofs` | `ocean` | NOAA OFS via THREDDS/OPeNDAP | No |
| ERDDAP ocean data | `providers/ocean/erddap_ocean.py` | `erddap_ocean` | `ocean` | MUR SST, RTOFS, PacIOOS, CARICOOS via ERDDAP | No |

Supporting components (not dispatch-registered provider modules):

| Component | File | Purpose |
|---|---|---|
| NOAA CUDEM bathymetry | `enrichment/bathymetry.py` | One-time per-spot bathymetric profile download |
| OSM Overpass structure discovery | `endpoints/setup.py` (`GET /setup/marine/discover-structures`) | Setup-time-only coastal structure (jetty/pier/breakwater/seawall/groin) discovery for surf spot configuration (§14.9) |
| NWS zone discovery | `providers/_common/nws_zones.py` | Shared utility: station → CWA → marine zones → distance filtering |
| Ocean data resolver | `services/ocean_data_resolver.py` | Orchestrates OFS → ERDDAP fallback chain, normalizes output (§14.12) |
| Water level compositor | `services/water_level_compositor.py` | Combines CO-OPS predictions + OFS non-tidal residual (§14.13) |

### §14.1 NDBC buoy observations

**Module identity:** `providers/buoy/ndbc.py`, `PROVIDER_ID = "ndbc"`, `DOMAIN = "buoy"`.

**Role change (ADR-091, 2026-07-13):** NDBC buoy observations are demoted from primary water temperature source to **labeled offshore reference data**. The ocean data resolver (§14.12) is now the primary source for water temperature. NDBC buoy data remains available for spectral wave decomposition and as an observational reference — when displayed, it is labeled with the buoy's station ID and offshore distance (e.g., "Nearest Offshore Buoy (46253)") so visitors understand this data is not at the beach location.

**Wind data limitation (HARD RULE):** NDBC buoy wind data is **offshore** and must NOT be used for surf wind quality scoring. Buoys are typically 12+ miles from shore and measure the synoptic-scale wind field, which can be completely different from beach conditions. Coastal wind is dominated by thermal effects (sea/land breezes, topographic channeling, coastal temperature gradients) that offshore buoys cannot see.

**NDBC's valid roles:**
1. **Offshore reference data** — swell propagation is large-scale; offshore spectral data accurately represents the swell systems arriving at the coast. Returned in the surf response as `spectralComponents` for operators and third-party consumers. **Not used for scoring or multiSwell display** — the surf score and `multiSwell` use the SWAN **deep-water reference** extraction instead: L2 at the spot's measured ~15 m contour, partitions read from the companion `TABLE PT*` (ADR-096 Amendment 1, ADR-095 Amendment 1 §1; see "Multi-SPECOUT extraction" in §14.15). *An earlier revision of this line said "SWAN SPECOUT at ~10m depth"; that is void — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture.*
2. **Offshore wave height/period reference** — as labeled observational data (not as beach conditions).

**NDBC's invalid role for surf scoring:**
- Wind speed and direction for surf quality classification. Beach wind and offshore wind can be completely different — SoCal morning glass-off conditions at the beach while the buoy reports a steady westerly. The surf quality scorer uses station hardware → forecast provider wind instead (see API-MANUAL §17).

**CAPABILITY:** `geographic_coverage = "us_coastal"`, `auth_required = []`. `supplied_canonical_fields` includes wind speed, wind direction, wind gust, wave height, dominant period, average period, mean wave direction, pressure, air temp, water temp (SST), dewpoint, visibility, pressure tendency, tide level. Spectral fields (per-swell-system height, period, direction, energy, classification) when station has spectral sensors.

**Wire format and parsing:**

NDBC serves flat files over HTTP (not a REST API). Three file types per station:

| File | URL pattern | Format | Content |
|---|---|---|---|
| Standard met (`.txt`) | `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.txt` | Fixed-width text columns | Wind, waves, pressure, temp, visibility |
| Spectral density (`.data_spec`) | `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.data_spec` | `VALUE(FREQ)` token pairs (variable, typically 47–98 depending on station) | Wave energy density (m²/Hz) at 0.02–0.485 Hz |
| Spectral direction (`.swdir`) | `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.swdir` | `VALUE(FREQ)` token pairs (variable, typically 47–98 depending on station) | Mean wave direction (degrees) at each frequency |

**Standard met parsing:** First two rows are headers (column names + units). Data rows follow, most recent first. Parse the most recent row. Columns: WDIR, WSPD, GST, WVHT, DPD, APD, MWD, PRES, ATMP, WTMP, DEWP, VIS, PTDY, TIDE. Handle `MM` markers as `None` (missing data — not an error). NDBC reports in metric (m, m/s, °C, hPa) — convert via `UnitTransformer` to canonical types.

**Spectral decomposition (when `.data_spec`/`.swdir` available):**

1. Parse energy density at each frequency band from `.data_spec` (most recent row; band count varies by station, typically 47–98).
2. Parse mean direction at each band from `.swdir`.
3. Identify spectral peaks: local maxima where energy(f) > energy(f-1) and energy(f) > energy(f+1).
4. Discard peaks below 5% of the dominant peak's energy (noise threshold).
5. Partition frequencies: assign each band to the nearest peak. Boundary = frequency with minimum energy between adjacent peaks.
6. Per partition, compute:
   - Significant wave height: Hs = 4√m₀, where m₀ = Σ(S(f) × Δf) over the partition (trapezoidal integration)
   - Peak period: Tp = 1/fp (frequency of peak energy in this partition)
   - Mean direction: energy-weighted circular mean = atan2(Σ(S(f)×sin(dir(f))×Δf), Σ(S(f)×cos(dir(f))×Δf))
   - Classification: ≥ 12s = `"groundswell"`, 8–12s = `"swell"`, < 8s = `"wind_swell"` (standard NWS thresholds)
7. Cap at 4 swell systems. If more peaks detected, merge weakest into adjacent partitions.
8. Map each partition to a `SpectralWaveComponent` canonical model.

No scipy dependency — at most ~100 values per station, not a signal processing problem.

**Station discovery:** Fetch `https://www.ndbc.noaa.gov/activestations.xml`. Parse XML for station ID, coordinates, sensor types. Differentiate station capabilities:
- **Full capability:** wave sensors + atmospheric sensors + spectral (3 file types)
- **Wave + atmospheric, no spectral:** `.txt` only (2 file types, no `.data_spec`/`.swdir`)
- **Atmospheric only (C-MAN stations):** wind, pressure, temp — no wave data

Return stations sorted by haversine distance from the target coordinates, with capabilities and distances.

**Cache:** Key = `(provider_id, station_id, file_type)`. TTL = 60 min for all three file types. Station discovery (`activestations.xml`) cached 24 hr. **Negative cache (V3-F8, 2026-08-02):** a standard-met 404 is cached as empty (`observation=None`) at a shorter 30-min TTL (`_NEGATIVE_CACHE_TTL = 1800`), preventing repeated network requests for misconfigured or non-existent station IDs.

**Station ID casing (V3-F8):** NDBC's flat-file server is case-sensitive (`PRJC1.txt` → 200, `prjc1.txt` → 404). All URL construction applies `.upper()` to the station ID; cache keys, `MarineObservation.stationId`, and log messages retain the original configured casing.

**Error handling:** HTTP 404 for standard-met file → `observation=None` (negative-cached, see above; formerly raised `ProviderProtocolError`). Spectral file 404 → `available=False` (not an error — station lacks that sensor). Empty file body → log WARNING, return empty observation (not error). Network errors → canonical taxonomy via `ProviderHTTPClient`.

**Rate limiting:** 1 req/s per module instance. NDBC has no documented rate limit, but the server is a flat-file host with modest capacity — be polite.

### §14.2 CO-OPS tides & water levels

**Module identity:** `providers/tides/coops.py`, `PROVIDER_ID = "coops"`, `DOMAIN = "tides"`.

**CAPABILITY:** `geographic_coverage = "us_coastal"`, `auth_required = []`. `supplied_canonical_fields` includes tide prediction times and heights, observed water levels, water temperature, currents.

**Dual-product usage for water level compositor (ADR-091, 2026-07-13):** This provider fetches both `predictions` (harmonic, 72h) and `water_level` (observed, 24h) products. Both are consumed by the water level compositor (§14.13) to compute the observed non-tidal residual: `residual = observed − predicted` at matching timestamps. The observed water level is ground truth for the meteorological effect at the station.

**Wire format and parsing:**

CO-OPS Data API returns JSON. Base URL: `https://api.tidesandcurrents.noaa.gov/api/prod/datagetter`. All requests must include `application=clearskies` (CO-OPS requires application identification).

| Product | Key parameters | Response array | Canonical model |
|---|---|---|---|
| `predictions` | `product=predictions&datum=MLLW&range=72&units=metric&time_zone=gmt&format=json` | `predictions[]` | `TidePrediction` |
| `water_level` | `product=water_level&datum=MLLW&range=24&units=metric&time_zone=gmt&format=json` | `data[]` | `WaterLevel` |
| `water_temperature` | `product=water_temperature&range=24&units=metric&time_zone=gmt&format=json` | `data[]` | water temp values |

**Tide prediction high/low classification:** CO-OPS prediction responses return water level at regular intervals (typically 6-minute). Classification is performed by `_classify_tide_predictions()` in `coops.py` using a plateau-aware peak-finding algorithm. The algorithm groups consecutive equal-height points into plateaus, then checks the neighbours outside each plateau: if both outer neighbours are lower, the first plateau point is marked "high"; if both outer neighbours are higher, the first plateau point is marked "low". All other points are interpolated. This handles the case where CO-OPS's 6-minute resolution produces two adjacent points at identical heights near a tide peak or trough — a strict greater-than/less-than comparison would miss these extrema. The `TidePrediction` canonical model carries the `type` field (`"high"` or `"low"` for extremes, `null` for interpolated points).

**Datum handling:** All requests use `datum=MLLW` (Mean Lower Low Water) as the reference. The `WaterLevel` canonical model carries the datum string. CO-OPS supports MLLW, MSL, NAVD88 — MLLW is the standard tidal datum for navigation and the default for marine weather.

**Station discovery:** `GET https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=waterlevels&units=metric`. Filter by distance from target coordinates. Return station ID, name, distance, available products (predictions, water_level, water_temperature, currents). Some stations report only predictions (subordinate stations); some report observations but not predictions.

**Cache:** Predictions TTL = 6 hr (harmonic predictions don't change within a tidal epoch). Observations TTL = 10 min. Water temperature TTL = 30 min. Station metadata TTL = 24 hr. Key = `(provider_id, station_id, product)`.

**Error handling:** Station with no data for requested product → empty list (not error). Invalid station ID → `ProviderProtocolError`. Rate limit or server error → canonical taxonomy via `ProviderHTTPClient`.

**Rate limiting:** No documented rate limit from CO-OPS, but use 2 req/s as courtesy limit.

### §14.3 WaveWatch III forecasts

**Module identity:** `providers/marine/wavewatch.py`, `PROVIDER_ID = "wavewatch"`, `DOMAIN = "marine"`.

**Rewritten 2026-08-06 (SW-2, SURF-PHYSICS-REMODEL-PLAN-2026-08-05 register item 10, operator ruling).** The prior ERDDAP (PacIOOS `ww3_global`) source is deleted outright — no dual-source, no toggle. This module now downloads and parses NOAA's own raw WaveWatch III (GFS Wave) gridded GRIB2 output directly, the same NOMADS/eccodes machinery the GFS/HRRR wind providers already use (§14.14, §14.16) — no new dependency.

**CAPABILITY:** `geographic_coverage = "global"` (excludes waters south of -77.5°S), `auth_required = []`. `supplied_canonical_fields` now has 15 entries: wave height/period/direction (combined total), wind-wave height/period/direction, and swell height/period/direction **times 3** — `swellHeight/Period/Direction` (WW3 partition 1, unchanged field names from the ERDDAP era), `swell2Height/Period/Direction`, `swell3Height/Period/Direction` (new, additive, optional). `CAPABILITY = None` when no eccodes/pygrib backend is available (same pattern as §14.14/§14.16), so the provider is simply not registered. Still does **not** supply true 10m wind speed/direction.

**Wire format and parsing:** NOAA NOMADS `filter_gfswave.pl` grib-filter CGI, product `gfswave.tCCz.global.0p16.fXXX.grib2` under `gfs.YYYYMMDD/CC/wave/gridded/` (same GFS cycle root as §14.16's wind product). One subsetted GRIB2 request per 3-hour forecast step (f000..f072, 25 requests), bbox = a small margin around the requested point — never the whole global file. A single combined request per forecast hour carries every needed `var_`/`lev_` flag (surface fields + all 3 swell-partition levels) in one round trip.

**NOMADS wire name vs. eccodes `shortName` — these are different strings, do not conflate:** `HTSGW`→`swh` (waveHeight), `PERPW`→`perpw` (wavePeriod), `DIRPW`→`dirpw` (waveDirection), `WVHGT`→`shww` (windWaveHeight), `WVPER`→`mpww` (windWavePeriod), `WVDIR`→`wvdir` (windWaveDirection), `SWELL`/`SWPER`/`SWDIR` (×3 levels)→`shts`/`mpts`/`swdir` (swell1/2/3 Height/Period/Direction). The 3 swell-partition messages share one eccodes `shortName` each, distinguished only by GRIB2 `level` at `typeOfLevel="orderedSequenceData"` — `grib_processor.read_grib_fields()` is level-aware and keys these `"{shortName}:{level}"`; every other field keeps its bare-shortName key.

**Missing-value sentinel:** gfswave's real GRIB2 `missingValue` is `9999` (live-verified), not the generic `9.999e20` `grib_processor.py`'s own `extract_nearest_value()`/`bilinear_interpolate()` hardcode. This module applies its own guard (treats any extracted value ≥ 9998.0 as missing) at its canonical-mapping boundary, independent of `grib_processor.py`'s generic (and, for this product, too-permissive) filtering.

**Cycle discipline (register item 10 — "the old-batch reuse is DEAD"):** never a step-back-through-older-cycles fallback while a last-good forecast already exists for a location. Two cache tiers: a last-good forecast (TTL = the cache backend's own ceiling, 86400s for the default MemoryCache) and a poll gate (TTL = `_CYCLE_POLL_INTERVAL_SECONDS = 600`, 10 min) throttling how often NOMADS is even asked whether the newest cycle has posted. Steady state: one attempt per poll interval at the expected cycle only; any failure (not yet published, a later hour still missing mid-cycle, or a genuine network/protocol/quota error) is logged with a distinct slug (`ww3_cycle_unpublished` / `ww3_cycle_partial` / `ww3_fetch_failed`) and answered by continuing to serve the existing last-good forecast unchanged — never a raise. **One bootstrap exception:** when there is no valid last-good at all (true cold start, or one that fell off the cache's TTL ceiling), a bounded backward search (`_MAX_BOOTSTRAP_CYCLE_LOOKBACK = 3` further 6-hourly cycles) finds the newest cycle NOAA has actually published; once any cycle succeeds, steady-state rules apply forever after for that location. If every bootstrap attempt fails, `ProviderUnavailableError` propagates — "the provider says so and serves nothing."

**Cache key:** `SHA-256(provider_id, role["last_good"|"poll_gate"], product, lat/lon rounded to 0.16°)` — two independent cache slots per location.

**Grid:** Single global gfswave 0.16° grid, coverage unchanged from the ERDDAP era (-77.5°..77.5°S, global longitude).

**Error handling:** `GeographicallyUnsupported` (south of -77.5°S); `ProviderUnavailableError` when no valid last-good exists and bootstrap is also exhausted; `QuotaExhausted`/`KeyInvalid`/`TransientNetworkError`/`ProviderProtocolError` only propagate when there is no last-good forecast to fall back to — while one exists, these are logged and absorbed, never raised. `endpoints/marine.py`'s 3 call sites now let `ProviderError` propagate to the RFC 9457 handler (`errors.py`) instead of swallowing it in a bare `except Exception:`.

**Rate limiting:** 2 req/s (NOMADS is shared NOAA infrastructure), paced with a 0.55s sleep between per-forecast-hour requests — same pattern as §14.14/§14.16.

**RW-1 (register ruling 13, "ONE source of offshore truth", 2026-08-06): this provider is no longer called for surf-spot locations.** `endpoints/marine.py`'s 3 card call sites now branch on `location.id in marine_config.surf_spots` — a surf-spot location's wave fields come from `services/model_wave_source.py` (the wave model's own SWAN watershed partitions, §14.15) instead, with no fallback to this module even when the model has no cached data yet. This module still serves every non-surf marine location, and still feeds the L1 SWAN boundary (a different code path — see §14.3a).

### §14.3a WW3 station spectral boundary fetch (T8.10b) — SUPERSEDED, deleted 2026-08-09 (Phase B, ADR-104 D3/D4)

**HISTORICAL REFERENCE ONLY — this mechanism is deleted.** Per ADR-104 (D3/D4), the L1 WW3 boundary is now
reconstructed per-L1-cell from gridded WW3 partition fields — see "§14.3a/b Amendment: partition-reconstruction
boundary" below for the live design. `services/ww3_station_selection.py`, `services/ww3_station_catalogue.py`,
and `data/ww3_station_catalogue.json` are deleted outright; `services/ww3_spectrum.py` is reduced to a
docstring-only stub (the station fetch/parse code below is gone — the Appendix-D 2-D spectrum WRITER this
module's docstring referenced never actually lived here; it lived in `services/swan_formats.py` and was
extracted/replaced by `write_swan_2d_spectrum_file()` there, B2/B3). Everything below this line documents the
pre-Phase-B mechanism as it ran in production, kept for the historical record.

**Module identity:** `services/ww3_spectrum.py` (marine repo), `PROVIDER_ID = "ww3_spectrum"`, `DOMAIN = "marine"`. **Not a dispatch-registered provider module** — same placement rationale as `services/bathymetry_resolver.py`: it fetches remote data over HTTP but feeds a model boundary condition (the SWAN L1 spectral boundary, T8.10c) rather than a canonical `MarineForecastPoint` field. It is a separate module from `providers/marine/wavewatch.py` (§14.3 above) — both read NOAA NOMADS since SW-2 (2026-08-06), but they fetch different NOAA products (this one: full 2-D per-station directional spectrum `.spec` files for the SWAN boundary; §14.3: gridded GRIB2 bulk/partition fields for the forecast cards) with different return shapes.

**What it fetches:** NOAA WaveWatch III's own per-station `.spec` files — the full 2-D directional spectrum `E(f,theta)` at a fixed output point, in the exact format SWAN's `BOUNDNEST3`/`BOUNDSPEC ... FILE` boundary commands are built to read. Two products, **one parser, no format branching** — the file's own header self-describes `nfreq`/`ndir`:

| Product | URL pattern (live-verified 2026-07-26) | Header | Size |
|---|---|---|---|
| Ocean (`gfswave`) | `https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.YYYYMMDD/CC/wave/station/bulls.tCCz/gfswave.<STATION>.spec` | `50 36`, freq 0.035–0.964 Hz (28.6 s–1.04 s) | 7.75 MB |
| Great Lakes (`glwu`) | `https://nomads.ncep.noaa.gov/pub/data/nccf/com/glwu/prod/glwu.YYYYMMDD/bulls.tCCz/glwu.<STATION>.spec` — note: no `/CC/` directory level, unlike the ocean product | `32 36`, freq 0.050–0.960 Hz (20.0 s–1.04 s), measured live 2026-07-26 | 1.94 MB |

Per-station files only — **never** the tarballs (`spec_tar.gz` 1.72 GB, `ibp_tar` 11.37 GB). `fetch_station_spectrum(station_id, product, cycle)` takes an explicit `cycle: datetime`; it makes no cadence assumption (ocean is 00/06/12/18Z, GLWU is hourly — brief §10.5) — cycle selection belongs to the caller, and since T8.10e that is `select_boundary_stations_with_cycle_fallback()`, which derives both the product and its cadence from the L1 extent (§14.3b).

**Wire format and the one non-obvious parsing fact:** the per-timestep header line carries station id, lat, lon, depth (m), wind speed/dir, current speed/dir — lat/lon can appear glued together with no separating space when longitude is negative (Fortran fixed-width output), parsed by extracting all `-?\d+\.\d+` tokens rather than splitting on whitespace. **The energy matrix is direction-major, frequency-minor** (`energy[i_dir][i_freq]`) — the opposite axis order from SWAN's own SPECOUT format. This was live-verified, not assumed: reading it frequency-major (matching SWAN's own format by unexamined analogy) reproduces the correct bin counts and "looks" fine, but integrates to a significant wave height ~24% too high against the station's own `.bull` bulk Hs. Direction-major integration reconciles to within 1–3% across six independent ocean timesteps (station 46222) and five Great Lakes timesteps (station 45002). The direction axis is in radians, spans the full circle, and is not guaranteed monotonic (wraps through zero mid-array on real files) — m0 integration uses a circular (wrap-aware) bin-width calculation for direction, not the plain midpoint spacing SWAN's own (monotonic 0–360) direction axis uses. Longitude in the per-timestep header is -180..180 for the ocean product but 0..360 for the Great Lakes product; both are normalized to -180..180 in the parsed output.

**No `missingValue` sentinel applies here** — that GRIB2 concept (T8.10b/T8.10f's "9999" guidance) belongs to the gridded WW3 products read via `grib_processor.py`'s eccodes backend. The station `.spec` files are plain ASCII WW3 point output with no `missingValue` key; this module instead raises `WW3SpectrumParseError` on any malformed or truncated file (empty file, unparseable header, an axis array or energy matrix cut short by EOF, an unparseable per-timestep header) — it never returns a partial spectrum, per rules/coding.md §1.

**Rate limiting:** 2 req/s against `nomads.ncep.noaa.gov`, via a dedicated `RateLimiter` instance (`ww3-spectrum-nomads`) independent of the WW3 station-catalogue discovery module's own NOMADS client (T8.10a). Two independent in-process limiters against the same host can double the real request rate if both run concurrently — flagged for a possible future shared-limiter consolidation, not yet implemented.

**Error handling:** `ProviderHTTPClient` exceptions (`QuotaExhausted`, `KeyInvalid`, `TransientNetworkError`, `ProviderProtocolError`) propagate unwrapped from `fetch_station_spectrum()` — a 404 (cycle not yet published) surfaces as `ProviderProtocolError` with `status_code=404` for the caller to branch on.

### §14.3b WW3 station selection + spatially varying SWAN L1 boundary (T8.10c round 2; marine-repo half of T8.10f) — SUPERSEDED, deleted 2026-08-09 (Phase B, ADR-104 D3/D4)

**HISTORICAL REFERENCE ONLY — this mechanism is deleted** (`services/ww3_station_selection.py` removed
outright). See the Amendment below for the live per-L1-cell reconstruction design that replaced it in Phase B.

**Module identity:** `services/ww3_station_selection.py`, plus `services/swan_formats.py`'s `ww3_boundary_files_and_command()`. Not a dispatch-registered provider module — same rationale as §14.3a.

**Why round 2 exists.** Round 1 (§14.3a note above the deleted `ww3_to_swan_boundary()`) landed the real 2-D spectrum writer (`ww3_spectrum_to_swan_boundary()`) but deliberately did not rewire the call site, because doing so first required a station-selection layer that did not exist. The research brief's own §10.1 decision — one station, `BOUNDSPEC ... CONSTANT FILE`, a spatially uniform boundary — was **REJECTED by the operator 2026-07-26**: *"YOU CANNOT JUST PICK ONE STATION POINT... YOU ARE MANDATED TO USE THE WWIII GRID! YOU ARE TO PROVIDE THE DIFFERENT VALUES AT THE BOUNDARY BASED UPON THE WWIII DATA FROM THAT GRID!"* This section documents the replacement: a real, multi-station, spatially varying boundary.

**Selection is depth/agreement-led and distance-bounded, both computed from live data, neither guessed:**

| Filter | Rule | Basis |
|---|---|---|
| Depth / agreement | `deep water OR tanh(kd) agreement`, applied to **both** products (ocean and Great Lakes) | **Ruled 2026-07-27, C-99 (`docs/archive/MARINE-SEP-CONCERNS.md`), superseding the depth-only filter this table originally documented.** `deep water` is the unchanged `depth_m >= 0.78 × T_max²` linear-wave-theory threshold (`d/L0 > 0.5`, `L0 = 1.56×T²`) — `_DEEPWATER_DEPTH_COEFFICIENT = 0.78` is confirmed correct and was not touched. `tanh(kd)` — the depth-dependent factor in the dispersion relation `ω² = g·k·tanh(kd)` — is the general agreement test: bounded to `[0, 1)`, it saturates to 1.0 as depth grows, so two deep points agree **by construction**, making `deep water` the degenerate case of the same test (`kd > π`) rather than a second, independent branch. This replaces an earlier round's relative-`kd` difference metric, which was rejected on the round's own regression evidence: relative `kd` grows without bound with depth in deep water, so it wrongly *rejected* a 2000 m station serving a 1500 m boundary (both unambiguously deep) at 33% relative difference — `tanh(kd)`, compared by *absolute* difference, agrees on that same case at 0.0000. `T_max` is now measured by **energy content** in the station's own live-fetched spectrum this cycle, replacing a peak-spectral-density-ratio measure (`_ENERGY_TAIL_FRACTION = 0.01` against the timestep's own peak density) that was reproducing GLWU's own 32-bin spectral grid edges — 13.66 s and 12.42 s, bins 4 and 5 of the grid's `f0 = 0.05 Hz`, `XFR = 1.1` ladder — as a false 120–146 m depth requirement rather than measuring real sea state; against a synthetic GLWU-shaped spectrum with real energy near 4.5 s, the old measure returned `T_max = 13.66 s`, the new measure `5.27 s`. **The agreement tolerance (`_KD_AGREEMENT_SHORTFALL_TOLERANCE ≈ 0.321`, `services/ww3_station_selection.py:353`; doc-sync 2026-08-06 — the symmetric tanh(kd) absolute-difference form this row previously named as `_TANH_KD_AGREEMENT_TOLERANCE` was replaced by a directional raw-kd shortfall test applied only in the shallow-station direction, T8.10f/C-104 round 5) is provisional, awaiting operator sign-off (C-104)** — it is derived by analogy from GLWU's published bulk-`Hs` RMSE (0.257 m in the 0–0.8 m regime, normalised by the regime's 0.8 m upper bound), not from a closed physical derivation; a shoaling-coefficient-based derivation was attempted and abandoned as degenerate near `kd = π`. Proximity alone does not imply suitability: in-bbox ocean stations near Long Beach Channel (46253, 46256) are measurably too shallow (291.5 m / 114.7 m against a required ~424–485 m for a 23–25 s period, live-verified 2026-07-26) and fail on both branches. |
| Distance | One native WW3 grid cell from the assigned side | Ocean `gfswave.global.0p16`: ~18.5 km (0.1667° at the equator). Great Lakes `glwu.grlc_2p5km`: 2.5 km (self-describing in the product name; corrects an earlier "0.25° / ~27.8 km" figure that did not match the product's own live-measured 2026-07-26 resolution — recorded as a finding, not silently adopted). |

**Config-time validator is split, not moved (C-99 ruling item 5).** `_validate_ww3_boundary_viability()` (§14.3, T8.10f) runs in two stages so a bathymetry or datum failure cannot silently swallow the WW3-boundary finding: Stage 1 (catalogue, routing, distance) still runs **before** the L1 bathymetry download, unchanged; Stage 2 (the depth/`tanh(kd)` agreement test) runs **after** it, since it needs the L1 grid's own depth at the boundary to compute `kd`.

**Runtime path carries the same criterion, not just the config-time diagnostic (C-99 ruling item 6).** `providers/nearshore/swan.py`'s boundary-selection call receives the L1 bathymetry every forecast cycle and applies the identical `deep OR tanh(kd)-agrees` test — an earlier implementation proposal that left the runtime path on deep-water-only (an optional L1-grid kwarg defaulting to `None`) was rejected, because the runtime path feeds SWAN every cycle while the config-time check is a one-time setup diagnostic.

**Boundary sides come from the geography OPEN-WATER bearing, NOT beach facing (2026-08-01).** Which sides of the axis-aligned L1 box receive the WW3 spectrum is decided by `_offshore_sides(bearing)` — the two box sides whose outward normals are closest to the bearing — where the bearing is the **open-water seaward bearing** from the geography ray-cast (ADR-100 / AD-2, `geography.open_water_bearing_deg`), i.e. the measured direction of open ocean. It is **not** beach facing. Beach facing is a bad proxy for where the swell enters — Malibu faces its cove while its swell window is elsewhere — which is the entire reason the ray-cast open-water system exists; nature's swells do not care which way the beach points. This supersedes the round-2 "always W and S" text below (which predated C-94's change from hardcoded sides to bearing-derived). **Persistence wiring (the actual 2026-08-01 fix):** the open-water bearing is computed once at apply time (`grid_sizing_chain.run_grid_sizing_chain()` → `geography.analyze_study_area_geometry`), frozen into `DomainSizing.open_water_bearing_deg` and written to `swan_grid_sizing.json` (`domain_sizing_to_dict`), then read back at run time by `providers/nearshore/swan.py` and passed as `select_boundary_stations_with_cycle_fallback(offshore_bearing_deg=domains.open_water_bearing_deg)`. **Before this fix the runtime call omitted that argument**, so it silently fell back to `_resolve_offshore_bearing_deg()` (beach-facing / segment-perpendicular) — the geography open-water result was computed at apply time and then thrown away before the run could use it. Apply-time boundary sizing already used the open-water bearing (`grid_sizing_chain.py:1099`); only the runtime path was unwired. A `None` bearing (boxed-in spot, or a sizing cache written before this field landed) preserves the prior beach-facing fallback.

**Side assignment and `[len]` geometry.** L1's W and S sides are unchanged from round 1 (`build_swan_input()`'s outer BOUNDSPEC block always applies WW3 conditions to west and south). A candidate station is assigned to whichever side's line it sits geometrically closer to (perpendicular distance to the S-side line at `lat_min` vs the W-side line at `lon_min`). SWAN's `BOUNDSPEC SIDE <s> CCW ... [len]` measures distance from the "begin point of the side," CCW around the full domain boundary; for a rectangle traversed SW→SE→NE→NW→SW, the S side's begin point is SW (len increases eastward) and the W side's begin point is NW (len increases southward). `[len]` is emitted in degrees (plain coordinate difference along that side's own axis) to match this codebase's spherical/lat-lon SWAN mode throughout.

**Refusal, never degradation (rules/coding.md §1).** `select_boundary_stations()` raises `BoundaryNotViableError` when fewer than 2 stations qualify overall, or when either the W or S side ends up with zero — it never falls back to a single uniform spectrum (the rejected design) or to the gridded bulk product. Live-verified 2026-07-26: the CURRENT production single-spot Huntington L1 extent (read from `/etc/weewx-clearskies/swan_grid_sizing.json`) yields only 1 qualifying station (46222) from the known nearby buoy set — 46221 sits 37.3 km from the W side (exceeds the 18.5 km limit), 46223 sits outside the S side's coordinate span despite being close, and 46253/46256 fail the depth check. This is the exact "one spot yields the minimum possible L1" case the plan's own research flags; a wider, multi-spot-realistic L1 (Seal Beach → The Wedge scale, ~61.6 km N-S × 73.7 km E-W) yields 3 real qualifying stations (2 on W, 1 on S) in the same live probe. **Recorded as a finding, not resolved by relaxing a threshold** — a single-spot configuration at Huntington may not admit a spatially varying boundary at all; multi-spot configurations spanning more coastline do.

**Product routing and cycle selection (T8.10e).** `select_boundary_stations_with_cycle_fallback()` decides the product itself, from the L1 extent it is already given: `product_for_extent()` classifies the extent's **centre** (not its corners — L1 spans tens of km and a corner can sit over land) with `enrichment/bathymetry.py`'s `classify_region()`, and a `REGION_GREAT_LAKES` centre routes to **GLWU**, everything else to the global ocean product. The same function already picks this domain's DEM and depth-contour ladder, so the water body has one answer rather than two that can disagree. Neither call site — the runtime path nor the config-time viability check — chooses a product. **The cadence travels with the product:** GLWU publishes hourly, the ocean product 6-hourly. It rounds the anchor time (the HRRR cycle time, for the runtime caller) down to the nearest published cycle hour for the routed product and retries up to 3 older cycles at that product's own interval if the newest is not yet published — same "fall back to 3 previous cycles" idiom §14.3 already documents for `wavewatch.fetch()`. Also handles NOMADS's `QuotaExhausted` (2 req/s) with an unbounded wait-and-retry (mirrors T8.10a's `ww3_station_catalogue.py`'s own `_acquire_rate_limit()`) and a short bounded retry for a transient `KeyInvalid` (HTTP 403) — NOMADS/Akamai is independently documented (T8.10a) to return 403 for a not-yet-ready path rather than a true permanent auth failure, and this was live-observed during this task's own verification run.

**Boundary file assembly.** `ww3_boundary_files_and_command()` (`swan_formats.py`) takes an already-selected, already-fetched `BoundaryStationSelection` and writes one real 2-D spectrum file per station (`ww3_spectrum_to_swan_boundary()`, unchanged from round 1 — direction-major axis order and the strictly monotonic NDIR axis SWAN requires are both preserved per file) plus one `BOUNDSPEC SIDE <s> CCW VARIABLE FILE <len1> 'f1' <len2> 'f2' ...` command line per populated side. Per the SWAN User Manual, a `VARIABLE FILE`'s own embedded `LONLAT` header is ignored by SWAN for positioning — only `[len]` places each spectrum along the side — so getting `len_deg` right in selection is what actually matters, not the file's own coordinate header (which remains the station's real position, informational only).

**Runtime rewire.** `providers/nearshore/swan.py`'s `_run_all_spots_locked()` calls `select_boundary_stations_with_cycle_fallback()` (which routes the product from L1's extent — see "Product routing" above) in place of the deleted `wavewatch.fetch(lat=center_lat, lon=center_lon)` single-centroid scalar fetch. Domain sizing (`load_grid_sizing_cache()`) was moved ahead of the boundary fetch in this function so L1's real extent is available for selection. A `BoundaryNotViableError` (or any other selection failure) raises exactly as a WW3 fetch failure did under the original C-76 ruling — the runner loop's retry-same-cycle handling fires, `last_hrrr_cycle` is not advanced, and last-good cache is preserved.

**Distinct boundary-refusal naming (H-1, SURF-PHYSICS-REMODEL-PLAN-2026-08-05, plan item 3 / D-3, 2026-08-06).** `providers/nearshore/swan.py`'s boundary-selection `try`/`except` now catches `BoundaryNotViableError` with its own except clause, BEFORE the generic `except Exception:` — a D-3 refusal (too few qualifying boundary stations) records `state.record_no_publish("ww3_boundary_refused", f"D-3 refusal — {exc}")`, distinct from the generic `ww3_boundary_failed` slug a network/parse failure still records. Both still raise (D-3 refuse stands — no fallback tiers, no degraded boundary of any kind); `GET /health` surfaces whichever slug fired as `no-publish: <slug> <detail>`.

**Bulk-fallback health flag (H-1, SURF-PHYSICS-REMODEL-PLAN-2026-08-05, 2026-08-06).** Two silent-collapse mechanisms both land in `surf_1d_pipeline.py`'s `_run_pipeline_per_transect()` per-transect Step 1 loop as the SAME `if not parts:` bulk-fallback branch: (A) `swan_runner.py`'s `_select_l3_handoff_position_and_spectrum()` produced an entry with `components=[]` (a per-transect TABLE_PT row genuinely had no partitions), or (B) the transect is simply absent from `handoff_by_transect` for that hour (one of four silent `continue` exits in that same function fired). `_run_pipeline_per_transect()` now counts every entry into that branch per call (one call = one timestep) — the authoritative bulk-fallback ground truth, distinct from the pre-existing `bulk_fallback_transect_count`/C4-G7.5 field, which counts only the successful-substitution sub-case. The count rides back on the internal `PipelineResult.bulk_fallback_count` field (never serialized to the swelltrack cache or any persisted/wire payload — internal instrumentation only). On the SWAN-cycle precompute path only (`providers/nearshore/swan.py`'s `_precompute_swelltrack_for_spot()` per-timestep loop, called from both `_run_all_spots_locked()` and `_run_quick_update_locked()`), when `bulk_fallback_count >= bulk_fallback_flag_threshold(transect_count)` the hour is recorded via `state.record_bulk_fallback_hour(spot_id, time_iso, count, n_transects)`. Request-time on-demand pipeline runs (`endpoints/surf.py`, `endpoints/beach_profile.py`) never route through `_precompute_swelltrack_for_spot()`, so they never write this state — gating is achieved by call-site placement, not a parameter. The registry (`state.py`'s `_bulk_fallback_hours`) is reset once at the start of each cycle's per-spot publish pass (both `_run_all_spots_locked()` and `_run_quick_update_locked()`), same rebuild-per-cycle shape as `_l3_viability_failures`. Threshold: `bulk_fallback_flag_threshold(n_transects) = max(_H1_BULK_FALLBACK_MIN_COUNT=8, ceil(_H1_BULK_FALLBACK_MIN_FRACTION=0.25 * n_transects))` — DESIGN CONSTANTS reviewed at the H-1 gate, not admin config; observed collapse events are 154–162/162 (95–100%) transects, healthy hours are 0–2, so a 25%-with-floor-8 rule has wide margin both directions and stays meaningful at the 32-transect beach_profile spot config (flags at 8). `GET /health` surfaces flagged hours (see OPERATIONS-MANUAL.md "Marine service deployment" health reasons).

**Aggregate handoff-collapse WARNING (H-1, per-hour, plan item 1).** `swan_runner.py`'s `_select_l3_handoff_position_and_spectrum()` gains an optional `exit_causes_out: dict[str, str] | None = None` out-param (time_iso → cause-slug); pure observation, the four silent `continue` exits keep their existing control flow exactly. The four causes: `no_hs_proxy` (no Hs proxy this hour), `breaking_zone_exhausted` (`HandoffBreakingError`), `no_station_selected` (no viable band station), `no_curve_match` (no nearest CURVE station). The caller loop (same function's caller in `swan_runner.py`) accumulates these per spot into one `H-1 handoff-collapse: spot %r @ %s — %d/%d transect(s) have no per-transect handoff entry this hour (silent-exit causes: %s)` WARNING per AFFECTED HOUR — never per transect — covering the union of carrier times and silent-exit times, so an hour where every transect silently exits (never entering the carrier at all) still gets its WARNING.

**Configuration-time viability (marine-repo half of T8.10f — partial).** `services/grid_sizing_chain.py`'s `run_grid_sizing_chain()` (runs on `POST /config`, "same shape as the existing L3 cluster viability test") calls the same selection logic once per config push and logs the result loudly (ERROR with the full rejection list on failure, INFO with selected stations on success) — but this chain "never raises past its own boundary" (it is a `BackgroundTasks` job with no synchronous HTTP response to attach a rejection message to), so it cannot synchronously refuse the operator's config push the way the plan's "fail at configuration time and tell the operator" language describes. **The operator-facing message (station id/distance/depth surfaced at setup) is cross-repo** (marine → API → config UI) and is dispatched separately to `clearskies-api-dev` + the config-UI owner — this section's contribution is limited to making the real check run and log early, and to the runtime path's own per-cycle raise (above), which is the actual per-cycle enforcement that never silently degrades.

#### §14.3a/b Amendment: partition-reconstruction boundary (IMPLEMENTED 2026-08-09, Phase B of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D3/D4; B2/B3 target-state superseding B2's spacing/sampling, `(ruled 2026-08-10; lands with Phase B2 of MARINE-PAGE-FIXIT-PLAN)`, ADR-106 R1, PA1)

**Status: LIVE for B1/B4 below (2026-08-09); B2/B3's spacing and per-point sampling are SUPERSEDED — the
tagged paragraphs below this subsection's original B2/B3 text describe the CURRENT design until Phase B2
of the fixit plan ships, at which point this subsection's own doc-sync removes the tag.** **Update
2026-08-23: the B1/B4 spectral-construction math (JONSWAP/Gaussian reconstruction) is still live and is
now consumed by WW3's own deep-water leg (§14.18) via `services/ww3_formats.py`, not by a SWAN L1 run —
SWAN's own L1 compute was removed 2026-08-23 (marine `3c550ae`/`c29266d`; `providers/nearshore/swan.py`'s
own code comment confirms "`reconstruct_boundary()` is NOT called — SWAN L1 never runs"). The B3
`BOUNDSPEC ... FILE`/`BOUNDNEST1` emission described below fed SWAN's own (now-removed) L1 boundary —
treat it as historical unless independently reverified against current code.** §14.3a/§14.3b
originally above (pre-2026-08-09) are historical reference only (deleted mechanism); this subsection
describes the current production boundary path, then the ruled target state.

**B1 — gridded partition-field fetcher (`services/ww3_partition_fields.py`) — untouched by the fixit plan's
Phase B2 (ADR-106 R1 changes only B2's per-point sampling and B3's position list, below; the corridor fetch
itself is out of scope).** Fetches, per
forecast step, the corridor bbox = L1 bbox + one native WW3 cell pad, fields `WVHGT`/`WVPER`/`WVDIR`,
`SWELL`/`SWPER`/`SWDIR` sequences 1–3, and `HTSGW` (validation only). Ocean product: NOMADS `filter_gfswave.pl`,
`gfswave.tCCz.global.0p16`, f000–f072 3-hourly (the same CGI family §14.3 already uses), one file per forecast
hour. Great Lakes: NOMADS `filter_glwu.pl` (pinned over the `.idx` byte-range alternative after a live check
2026-08-08/09 — the filter CGI needs no new byte-range-parsing code and mirrors the ocean product's own
mechanism), one file per cycle bundling many hourly steps (live-verified ≥150 hourly steps per cycle),
extracted per-hour via `grib_processor.read_grib_fields(target_step=hour)`. Product routing by L1-centre region
(`classify_region`, the same rule the station path used). Reuses `providers/_common/http.py`'s client/rate
limiter, `grib_processor.py`'s eccodes backend, and the existing ≥9998 missing-value guard (PROVIDER-MANUAL
§14.3 conventions). **Rate limit — waits, never fails (J26, 2026-08-28):** this module's 2-per-second NOMADS
courtesy limiter is taken with `RateLimiter.acquire_blocking(max_wait_seconds=10)` (a marine-only divergence
from the API's verbatim limiter mirror; the limiter's deque is also lock-protected because the runner thread's
WW3 leg and a config push's grid-sizing chain share this instance). Why: the NOAA cycle fallback (newest cycle
not posted yet → previous cycle) issues its next request within the same second, and the non-blocking
`acquire()` raised the service's own `QuotaExhausted` — at 02:59:58Z on 2026-08-28 that aborted a config
push's whole grid-sizing chain, leaving the previous sizing cache in place with nothing surfaced. Every other
provider still uses the non-blocking `acquire()`; only this fetcher blocks. Any missing field in a successfully-downloaded file raises (`BoundaryNotViableError`,
retained as the exception type, new message) — never a partial fetch; a not-yet-published cycle is a distinct,
retryable condition (`fetch_partition_corridor_with_cycle_fallback()`, the bounded cycle-fallback idiom carried
over from the deleted station path).

**Coverage-window-driven fetch depth (Z3.9a, 2026-08-13, MARINE-PAGE-FIXIT-PLAN-2026-08-10 finding V2).**
`fetch_partition_corridor_with_cycle_fallback(..., anchor_time, coverage_end=None)` gains an optional
`coverage_end` (this run's own t_end). Per candidate cycle in the fallback ladder, fetch depth is derived —
`hours_needed = ceil((coverage_end − candidate_cycle) / 1h)`, rounded UP to the product's own per-file step
(3 h ocean, 1 h Great Lakes), floored at the legacy fixed depth (72 h) as a MINIMUM, never a cap — instead of
resetting to a fixed 72 h span from whichever cycle the fallback ladder happens to land on. Because
`anchor_time` is unchanged across every fallback candidate, an OLDER candidate automatically computes a
DEEPER required depth, closing the defect where fetch coverage structurally fell short of the run's real
window end whenever the ladder fell back to an older cycle. `coverage_end=None` (both existing callers —
`boundary_reconstruction.reconstruct_boundary()`, which has no `coverage_end` parameter of its own; the
live run's `anchor_time` is already correctly the run's own HRRR cycle `C`, and the config-time grid-sizing
smoke test's `anchor_time=datetime.now(UTC)`) derives `coverage_end` internally as
`anchor_time + <product's legacy fixed depth>`, byte-identical to pre-Z3.9a behavior for both — this is why
`coverage_end` did not need to be threaded as a new parameter through `reconstruct_boundary()` itself.

**Boundary-coverage belt-and-suspenders check (Z3.9a finding V4).** `services/swan_runner.py` compares the
WW3 boundary reconstruction's own last timestep against the run's t_end at the
`ww3_boundary_files_and_command()` call site; a gap raises `BoundaryCoverageError` (reason
`boundary_coverage_gap`), naming both times and the gap in hours. This exists even though the fetch-depth
fix above makes it "impossible" in practice — a silently shorter boundary tail would otherwise leave SWAN
holding the boundary spectrum at its last available timestep for every remaining `COMPUTE STAT` hour with
no diagnostic at all. `providers/nearshore/swan.py` also logs one INFO after every boundary reconstruction
(finding V5) naming the run's own cycle `C`, the WW3 cycle actually used, the delta between them, and the
boundary reconstruction's own last timestep.

**B2 — reconstruction module (`services/boundary_reconstruction.py`).**
- **Boundary points:** every L1 boundary cell along the two offshore sides (sides resolved from
  `open_water_bearing` via the existing `_offshore_sides` logic, which moves into this module when the
  station module is deleted). Spacing = L1 `dx` = 1 km (D4).
- **Parameter sampling per point per partition:** bilinear over the 4 surrounding WW3 cells, using WET cells
  only with renormalized weights; 0 of 4 wet → nearest wet cell within 2 cells; none → raise. Directions
  interpolate as unit vectors. A partition missing (9999 sentinel) at contributing cells → that partition
  contributes zero energy at that point (partitions legitimately die out spatially); ALL partitions zero
  while interpolated `HTSGW > 0.1 m` → raise (inconsistent source).

> **`(ruled 2026-08-10; lands with Phase B2 of MARINE-PAGE-FIXIT-PLAN)` — B2 boundary points/sampling
> SUPERSEDED (ADR-106 R1, PA1; fixit log Item 1).** Live measurement against the design above found the
> per-point spatial sampling was the confirmed root cause of a slot-mixing defect: averaging each WW3
> partition slot by NUMBER across 4 cells does not guarantee the same physical wave system from cell to
> cell — a live corridor survey found adjacent cells carrying unrelated systems in the same slot (9.8 s
> west swell @ 277° next to 3.6 s chop @ 259° next to 8.7 s SSE @ 172°), so slot-number averaging both
> fabricated trains that exist nowhere and annihilated real ones. Operator ruling, verbatim: *"We should
> not be interpolating and then having SWAN interpolate our interpolation."* **Target state:** the entire
> spatial parameter-interpolation layer above (`_bilinear_corners`, `_sample_scalar`, `_sample_direction`,
> `_sample_train`, `_sample_point_partitions`, `_nearest_wet_value`, and the per-point sampling loop) is
> DELETED. Boundary-point selection becomes **cell selection per offshore side**: for an S/N side (east–west
> line), the WW3 cell ROW whose centre latitude is nearest the side's latitude; for a W/E side (north–south
> line), the cell COLUMN nearest the side's longitude. From that row/column, every WET cell (the same ≥9998
> missing-mask test on HTSGW, unchanged) whose centre projects within `[0, side_length]` onto the side
> becomes one boundary position at `len` = the UTM projection of the cell centre onto the side. Each
> position's spectrum is built from that ONE cell's OWN partition values only — wind sea (`WVHGT`/`WVPER`/
> `WVDIR`, absent = calm, legitimate) + swell slots 1–3 (`SWELL`/`SWPER`/`SWDIR`; a missing slot contributes
> nothing) — zero spatial math. Viability: fewer than 2 selected wet cells on any side → `BoundaryNotViableError`
> (existing role, unchanged); `services/grid_sizing_chain.py`'s config-time smoke test updates to the same
> criterion. Expected scale: ~7–10 cells per side (vs today's ~93–132 points per side at 1 km spacing).

> **`(landed 2026-08-14, Plan Amendment A1; as-built)` — boundary perimeter moves with the big-L1 box (D3, ADR-108).** The per-wet-cell WW3 reconstruction mechanism above is UNCHANGED — same source, same time axis, same coverage-window rule (Z3.9a). Only the perimeter's position moves with the extended L1 box (D1, as-built 142×169 meshes / ≈145.07 × 167.07 km): as measured live (boundary_reconstruction, cycle 2026-08-14T00:00:00Z), S side at ~32.60°N = **9 wet gfswave 0p16 cells**, W side at ~119.25°W = **9 wet cells**, 25 timesteps each — 22 boundary files on disk (11 `B_S_*` + 11 `B_W_*`) vs the old grid's 15 (design estimated ~7–8/~9 cells; both sides comfortably clear the 2-wet-cell viability floor). No change to cell-selection logic, spectrum construction, or the `BoundaryNotViableError` viability floor.

- **Spectrum per point:** `E(f,θ) = Σ_p (Hs_p²/16) · S_p(f) · D_p(θ)`, emitted on the CGRID spectral axes (**35**
  log-spaced freqs 0.03–1.0 Hz — `CIRCLE … 34` is msc, and the frequency count is msc+1 (SWAN manual :1532/:3719;
  live-verified against the deployed binary's own SPECOUT `AFREQ / 35`, 2026-08-09) — 72 directions) so SWAN never
  interpolates the boundary spectrum itself.
  Wind-sea train: JONSWAP `γ = 3.3`, `Tp = r × WVPER` (`r = 1.0`, operator-ruled 2026-08-09 — see the
  measured-then-pinned constants paragraph below), spread cos²ˢ `s = 7` (σθ ≈ 30°). Swell trains: Gaussian `σf = 0.015 Hz` centred at
  `1/SWPER` (narrow-band: mean ≈ peak), spread cos²ˢ `s = 28` (σθ ≈ 15°) — **except short-period swell trains
  (`SWPER ≤ 8 s`, `_SHORT_PERIOD_SWELL_MAX_PERIOD_S`; operator ruling 2026-08-22 "1 ok")**, which take the wind-sea
  JONSWAP frequency shape (`γ = 3.3`, `fp = 1/SWPER`, same `s = 28` spread): they are decayed wind sea the source's
  partitioner relabels "swell" once local wind is light, and the Gaussian gave them no high-frequency tail (live
  2026-08-22 12Z: W-edge point zero energy above 0.21 Hz vs NDBC 46025's broad 0.13–0.27 Hz spectrum 23 km
  inside; band totals matched, the split did not). Each `S_p(f)`/`D_p(θ)` normalized to
  unit integral on the discrete grid BEFORE scaling by `Hs_p²/16`, so the bin-sum identity is exact by
  construction.
- **Runtime guard:** per point, `|4√m0 − √(ΣHs_p²)| ≤ 5%` (the discretization identity) → raise on breach. No
  runtime guard against `HTSGW` (a 4th WW3 partition legitimately makes the partition sum < HTSGW) — that
  comparison is a known-answer test (KAT) only.
- **Time:** nonstationary files, one file per boundary point carrying all timesteps (ocean 3-hourly; GLWU
  hourly).

**B3 — emission** reworks `ww3_boundary_files_and_command()` (`services/swan_formats.py`) in place, same
public name: `BOUNDSPEC SIDE <s> CCW VARIABLE FILE <len_1> 'B_<side>_<i>.txt' 1 ...` per offshore side,
`[len]` in UTM METRES (L1 is `COORDINATES CARTESIAN`/UTM since F1-proj) from the side's CCW begin corner —
strictly ascending, one point per L1 boundary cell at `len_i = i × dx` (cell-corner grid points, not
cell-centres). CCW begin corners: S begins SW (grows east), W begins NW (grows south), E begins SE (grows
north), N begins NE (grows west). `BOUNDSPEC ... PAR`, `BOUND SHAPE`, `BOUNDNEST2/3` are never emitted;
`BOUNDNEST1 NEST 'nest_in.dat' CLOSED` (the L1→L2/inner mechanism) is untouched. Full SWAN syntax
prescriptions and manual line citations: `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` "SWAN SYNTAX
PRESCRIPTIONS".

> **`(ruled 2026-08-10; lands with Phase B2 of MARINE-PAGE-FIXIT-PLAN)` — B3 position list SUPERSEDED
> (ADR-106 R1, PA1).** Command grammar above is UNCHANGED (`BOUNDSPEC SIDE ... VARIABLE FILE`, same CCW
> corner map, `&`-continuation wrapping, one command per side). **Target state:** the position list becomes
> B2's per-cell `len`s (above, superseded paragraph), strictly ascending, PLUS two endpoint byte-copies — the
> first/last supplied position on each side (`len = 0.0` and `len = side_length`) is a byte-copy of the
> nearest selected wet cell's spectrum file, guaranteeing full-side coverage independent of SWAN's
> beyond-endpoint behavior. Same file naming scheme, same `&`-wrapping, same one-command-per-side. Expected
> scale: ~7–10 cells + 2 copies per side (≈20 files total, down from today's ~194) — retires the SWAN 99-file
> command-cap parking-lot concern from `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`. `BOUNDSPEC ...
> PAR`, `BOUND SHAPE`, `BOUNDNEST2/3` remain forbidden; `BOUNDNEST1` remains untouched. Manual authority for
> letting SWAN fill the space between listed positions: *"The wave spectra for grid points on the boundary
> of the computational grid are calculated by SWAN by the spectral interpolation technique described in
> Section 2.6.3"* (SWAN manual, `VARIABLE FILE` description) — see the fixit plan's "SWAN SYNTAX
> PRESCRIPTIONS" section for full citations.
>
> **Unchanged by this ruling (both B2 and B3):** all single-cell spectrum-construction math — JONSWAP
> wind-sea shape (γ=3.3), Gaussian swell shapes (adaptive σf), cos²ˢ directional spreads (s=28 swell / s=7
> wind-sea), normalization, the bin-sum identity guard (≤5%), the HTSGW-inconsistency guard (0.1 m) — and the
> timestep structure (one file per position carrying every step of the cycle window). This ruling changes
> WHERE a spectrum is built (per wet cell, zero spatial averaging), never HOW a single cell's spectrum is
> built. See ADR-106 R1 for the full ruling record.

**B4 — retirement of the station path.** `services/ww3_station_selection.py`,
`services/ww3_station_catalogue.py`, `data/ww3_station_catalogue.json` are deleted outright. `services/ww3_spectrum.py`
is reduced to a docstring-only stub (verified: `swan_spectral.py`'s own `parse_specout_file()` — the
"SPECOUT-mirror parser" — is a DIFFERENT function in a DIFFERENT module, never lived in `ww3_spectrum.py`, and
is untouched) — no importable symbol remains; the module's WW3 `.spec` direction-convention research is kept
in its docstring for the historical record. `services/grid_sizing_chain.py`'s config-time viability
check (`_validate_ww3_boundary_viability()`) replaces the two-stage station check with a single
partition-reconstruction smoke test — one live cycle, corridor bbox, every boundary point's spectrum actually
built via `boundary_reconstruction.reconstruct_boundary()` — same loud config-push refusal role, verified live
2026-08-09 against both a passing Huntington-scale extent (43 points, 25 timesteps each) and a deliberately
land-locked domain (ERROR logged naming the extent, function returns without raising further).

**Measured-then-pinned constants (see ADR-104):** the GLWU fetch method pinned (NOMADS `filter_glwu.pl`, see
B1 above). `r` (wind-sea mean→peak period ratio) — **pinned `r = 1.0`, operator-ruled 2026-08-09, marine
commit `5ebc1fa`** (`WIND_SEA_TP_MEAN_TO_PEAK_RATIO_R = 1.0` in `boundary_reconstruction.py`). History: the
plan's original bounds were `[1.10, 1.35]` on a mean→peak premise; the one-shot measurement 2026-08-09
against station 46222 (live NOMADS, 2 of 3 attempted cycles yielded a usable wind-sea pair) produced
r=1.0136 and r=1.0559, BOTH below that floor. Per ADR-104 ("out of bounds → STOP and surface, never pick")
the result was surfaced; the operator ruled the gridded `WVPER` field behaves as (near-)peak period, so no
mean→peak inflation is applied and the bound is superseded for this constant (plan decision log 2026-08-09).
The direction-convention cross-check passed cleanly (2.4–2.5° agreement, no flip needed for the GRIB2 path,
confirming it matches `providers/marine/wavewatch.py`'s handling).

### §14.4 NWS marine zone text forecasts

**Module identity:** `providers/marine/nws_marine.py`, `PROVIDER_ID = "nws_marine"`, `DOMAIN = "marine"`.

**CAPABILITY:** `geographic_coverage = "us_coastal"`, `auth_required = []`. `supplied_canonical_fields` includes period name, forecast text, wind, seas, visibility, weather.

**Wire format and parsing (corrected 2026-07-11):** `GET https://api.weather.gov/zones/coastal/{zoneId}/forecast` does **not exist** on the live NWS API — it returns 404 "Forecasts for marine areas are not yet supported by this API." Marine zone forecasts are published only as CWF (Coastal Waters Forecast) free-text products, keyed by WFO (not by zone), the same product-list/product-detail resource shape §14.5 uses for SRF:

1. `GET https://api.weather.gov/products/types/CWF/locations/{wfo}` with `User-Agent: weewx-clearskies-api/{version} (contact email)` — a JSON-LD envelope with an `@graph` array of product stubs, most recent first in practice. Take `@graph[0]`; use its `@id` URL, or fall back to `{base}/products/{id}` from its `id` (UUID).
2. `GET` that product URL → `productText`, the raw CWF text.

**WFO determination:** `fetch()` takes `zone_id` only (no lat/lon required) — the WFO is resolved via `providers/_common/nws_zones.py::get_wfo_for_zone(zone_id)` (§14.8), which reuses the already-cached (24h) `type=coastal` zone list's `cwa` property. An optional `wfo_override` kwarg lets a caller that already knows the WFO skip this lookup.

**CWF text parsing:** A CWF product concatenates one UGC (Universal Geographic Code) header segment per zone-group, e.g. `AMZ250-121115-` (zone id + 6-digit expiration), each terminated by a `$$` line. A header may abbreviate additional zones sharing identical text to their 3-digit suffix (e.g. `AMZ250-256-262-121115-` → `AMZ250`, `AMZ256`, `AMZ262`). Locate the segment for the operator's configured `zone_id`, then split it into forecast periods on `.PERIOD...` markers (e.g. `.TONIGHT...`, `.SUN...`, `.SUN NIGHT...` — the narrative follows immediately on the same line, unlike SRF's standalone day-period header lines). Per period:

- `period_name` — the marker text, title-cased (e.g. "Tonight", "Sun Night").
- `text` — the full, whitespace-normalized period narrative.
- `wind` — first sentence matching `<compass> winds...` (e.g. "W winds 10 to 15 kt with gusts up to 20 kt.").
- `seas` — first sentence starting with "Seas" (e.g. "Seas 2 to 4 ft."); a "Wave Detail..." sentence immediately following is folded into `seas`.
- `visibility` — first sentence starting with "Visibility" (rare in CWF coastal-waters text; usually absent).
- `weather` — remaining, unclassified sentences (e.g. "A chance of showers and tstms, mainly this evening.").

`text` always carries the full narrative even when wind/seas/visibility/weather extraction misses.

**Zone ID source:** The zone ID comes from the operator's marine location configuration (`nws_marine_zone_id` field). Zone IDs are shared with the marine zone alerts extension (§8). The NWS zone discovery utility (§14.8) discovers zones at setup time.

**Cache:** TTL = 30 min. Key = `(provider_id, zone_id)` — unchanged by the wire-format fix; WFO is not part of the cache key since a zone_id maps to a stable WFO and the WFO lookup itself is independently cached by `nws_zones.py`.

**Error handling:**
- `zone_id` not present in the NWS `type=coastal` zone list (no WFO determinable) → `ProviderProtocolError`, raised by `get_wfo_for_zone()`.
- WFO has no CWF product registered (empty `@graph`, or 404 on the products-list/product-detail call) → empty result, **not** an error (mirrors §14.5 SRF's "WFO issues no product" handling).
- CWF product fetched successfully but contains no section for `zone_id` (misconfigured/stale zone_id) → `ProviderProtocolError` (the direct analog of the old "zone ID not found (404)" case).
- CWF product's zone section has no parseable `.PERIOD...` markers → empty result, not an error (logged at WARNING).
- Rate limit / 5xx → retried by `ProviderHTTPClient`, surfaces as `QuotaExhausted` / `TransientNetworkError`.

**Rate limiting:** 5 req/s to `api.weather.gov` — shared rate limiter with the existing NWS alerts provider. Use the same `RateLimiter` instance or a shared pool keyed by hostname. The `zone_id → WFO` lookup uses `nws_zones.py`'s own `"nws-zones"` limiter instance, not this module's.

### §14.5 NWS Surf Zone Forecast (SRF)

**Module identity:** `providers/marine/nws_srf.py`, `PROVIDER_ID = "nws_srf"`, `DOMAIN = "marine"`.

**CAPABILITY:** `geographic_coverage = "us_coastal"`, `auth_required = []`. `supplied_canonical_fields` includes rip current risk, surf height range, UV index, water temperature, wind text, hazards text.

**Wire format and parsing:**

`GET https://api.weather.gov/products/types/SRF/locations/{wfo}` to get the latest SRF text product for the WFO covering the spot. The SRF (Surf Zone Forecast) is a free-text product issued 1–2 times per day. It contains per-county-zone forecasts for 2+ days.

**SRF text structure (zone-then-period, verified from live WFO ILM product 2026-07-11):**

The SRF product contains multiple county-zone sections separated by `$$`. Each zone section:

1. **UGC line** — zone ID + expiration (e.g., `NCZ108-120515-`)
2. **Zone name** — human-readable (e.g., `NEW HANOVER COUNTY BEACHES`)
3. **Beach list** — enumeration of specific beaches covered
4. **Period blocks** — each starts with a period marker (`.REST OF TODAY...`, `.SUNDAY...`, `.MONDAY NIGHT...`, `.EXTENDED...`)
5. **Footnotes** — after `&&` at end of each zone section (asterisk-annotated field definitions)

Within each period block, field labels use dot-leaders with optional asterisk footnote annotations:
```
Rip Current Risk*...........Moderate.
Surf Height.................2 to 4 feet.
UV Index**..................8.
Winds.......................Southwest 10 to 15 mph.
Water Temperature...........78 degrees.
```

Key format details:
- Field names may have 0–3 asterisks between the name and the dot-leaders (footnote annotations)
- "Winds" (plural) is the standard label — not "Wind"
- Period labels include: `REST OF TODAY`, day-of-week names (`SUNDAY`, `MONDAY`, etc.), `TONIGHT`, `TOMORROW`, `TOMORROW NIGHT`, `EXTENDED`
- Some zones split fields into sub-regions (e.g., "East of Ocean Isle Beach" / "Ocean Isle Beach West")
- Compound rip-current-risk values (e.g., "MODERATE TO HIGH") resolve to the higher-risk category (safety-critical)

**Parser approach:** Split text by `$$` into zone sections → match target zone by UGC code prefix in the zone's UGC line → strip footnotes after `&&` → parse period blocks within that section → extract field values.

**County-zone matching:** The spot's public forecast zone ID (from `/points/{lat},{lon}` → `properties.forecastZone`) identifies the UGC zone prefix to search for in the SRF text's zone sections.

Parse the text product to extract per-county-zone per-period:
- Rip current risk: `low`, `moderate`, or `high`
- Surf height: breaking wave height range (min/max in feet)
- UV index: integer 1–11+
- Water temperature: degrees
- Wind: text description
- Hazards: text statement

Map to `SurfZoneForecast` canonical model.

**WFO determination:** Reuse the NWS `/points` → CWA lookup from the shared zone discovery utility (§14.8).

**Cache:** TTL = 60 min (SRF is issued 1–2 times/day). Key = `(provider_id, wfo, county_zone)`.

**Error handling:** WFO with no SRF product (not all WFOs issue SRF) → empty result (not error). Text parsing failure → log WARNING with the raw text, return partial result for successfully parsed fields.

**Rate limiting:** Per-module rate limiter (5 req/s to `api.weather.gov`), matching the established per-module pattern used by other NWS providers.

### §14.6 (Removed — NWPS eliminated per ADR-093)

NWPS is eliminated. The nearshore wave model is SWAN (§14.15). The `providers/marine/nwps.py` module, its tests, cache warmer entry, and all config keys (`nwps_wfo`, `nearshore_model`) are deleted. The historical decision rationale is preserved in the archived ADR-084.

### §14.7 Bathymetry data sources

**Not a dispatch-registered provider module.** Bathymetry is accessed through two components: `services/bathymetry_resolver.py` (2-D grid resolution for SWAN) and `enrichment/bathymetry.py` (1-D profile extraction for surf/fishing spots), both now in the marine service. Both run at SWAN run time, not per-request.

#### Data source priority chain

The bathymetry resolver (`services/bathymetry_resolver.py` in the marine service) selects the highest-resolution available data source for each SWAN grid level:

| Priority | Source | Resolution | Access method | Coverage |
|----------|--------|-----------|---------------|----------|
| 1 | Operator-supplied file | Varies | GeoTIFF/NetCDF/ASCII XYZ upload via admin UI | Operator's site |
| 2 | NCEI regional coastal DEMs | ~10m (1/3") | OPeNDAP subset via `xarray` | 199 US coastal regions |
| 3 | USGS Great Lakes DEMs | ~3-5m | GeoTIFF windowed read via `rasterio` | All 5 Great Lakes + St. Clair |
| 4 | CRM/DEM_all (fallback) | ~90m (3") | NCEI ArcGIS ImageServer getSamples | All US coast |

**Resolution impact:** CRM at ~90m produces staircase depth profiles — the same depth value repeats across 5-10 adjacent 10m cells. Level 3 surf-zone grids require at least 10m bathymetry to resolve sandbars and break points. The resolver ensures the finest available source is used per grid level.

#### NCEI regional coastal DEMs (Priority 2)

**Static index:** `data/ncei_regional_dem_index.json` — 199 NetCDF files from the NCEI THREDDS server at `https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.xml`. Built offline by `scripts/build_ncei_dem_index.py` (not shipped). Each entry records filename, bounding box, resolution (arc-seconds), vertical datum, and elevation variable name (`z` or `Band1`).

**OPeNDAP access:** `fetch_opendap_grid()` opens the remote NetCDF file via `xarray.open_dataset()` using the OPeNDAP URL (`https://www.ngdc.noaa.gov/thredds/dodsC/regional/{filename}`). Only the requested bbox subset is downloaded — not the full file. For Level 2 (100m), a typical download is ~75×75 cells and takes <10 seconds. For Level 3 (10m), ~220×220 cells.

**Resolution lookup:** `find_best_dem(bbox)` finds all index entries that fully contain the query bbox, then returns the one with the finest (smallest) `resolution_arcsec`. Partial matches return `None` — the caller falls back to the next priority.

**Elevation variable inconsistency:** Older DEMs (pre-~2015) use `Band1`; newer DEMs (post-~2018) use `z`. The index records the correct variable name per file.

#### Vertical datum consistency

**Requirement:** All bathymetry (BOTTOM) and water level (WLEVEL) inputs to SWAN must be referenced to the same vertical datum. Mixing datums produces depth errors that corrupt wave breaking predictions. SWAN does not detect or report datum mismatches — a mismatch produces silently wrong depth calculations.

**Primary strategy — match at source (ADR-098):** The SWAN pipeline reads the DEM's `vertical_datum` from the bathymetry cache and requests CO-OPS tide predictions in that datum for WLEVEL. CO-OPS performs the datum conversion server-side using authoritative tidal datum models. No local VDatum conversion is applied for the common case. Bathymetry stays in its native datum — no spatial conversion error is introduced.

**DEM datum inventory (199 NCEI regional DEMs):**

| Datum | DEMs | CO-OPS direct support | Notes |
|-------|------|-----------------------|-------|
| MHW | 80 | YES | Gulf, Atlantic, Pacific, islands |
| MHHW | 50 | YES | Pacific coast, NE coast |
| MLLW | 21 | YES | US coast tsunami DEMs (_P/_G/_S/_N/_F suffix) |
| NAVD88 | 32 | YES | Scattered nationwide |
| MSL | 15 | YES | Islands, Pacific, Mariana Trench |
| PRVD02 | 1 | NO (PR only) | San Juan, Puerto Rico |

**UNKNOWN datums (resolved):** The index previously had 34 DEMs with `"vertical_datum": "UNKNOWN"`. All were resolved in T2.1 by querying NCEI XML metadata (US coast tsunami DEMs → MLLW, EPSG:5866; island DEMs → MSL per NCEI convention). The index now has 0 UNKNOWN entries. `download_bathymetry_for_level()` in `swan.py` rejects DEMs with UNKNOWN datum — it logs an ERROR and falls through to the next source in the resolver chain. `find_best_dem()` returns the finest-resolution DEM regardless of datum; the UNKNOWN guard is downstream in the download function.

**CRM datum limitation:** CRM/DEM_all has no guaranteed datum — the mosaic combines DEMs from multiple sources with mixed vertical datums without normalizing them. Datum uncertainty is an additional quality limitation of the coarse fallback (alongside its ~90m resolution). CRM-sourced areas are flagged as degraded quality in the coverage endpoint.

> **`(landed 2026-08-14, Plan Amendment A1; as-built)` — D4 datum policy for the big-L1 box (ADR-108).** The existing chain (NCEI regional DEM → CRM fallback, `bathymetry_resolver.py`) is unchanged in mechanism; ADR-098 discipline applies to the big box in full. **As-built (A1.2 satisfied by A1.1(f)):** the big-L1 BOTTOM source is **ETOPO 2022 15s** (`etopo_2022_15s:ETOPO_2022_v1_15s_bed_elev`), datum **LMSL** — the same source and datum L1 already used before the extension; ETOPO's global coverage answers the extended SW corner (32.60°N, 119.25°W) directly, so **the CRM fallback never triggers and D4's STOP-and-surface clause did not fire** — no operator datum ruling was needed. Hard requirements verified: (i) BOTTOM datum KNOWN — ETOPO's published LMSL, no UNKNOWN-datum rejection; (ii) CRM is NOT in play (moot for this box, still binding if a future box reaches it — CRM has no guaranteed datum, see "CRM datum limitation" above, so CRM answering any big-L1 box remains a STOP-and-surface, not an automatic pass); (iii) WLEVEL (STOFS ≈ LMSL) already matches BOTTOM's LMSL — no reconciliation change needed for the new box; (iv) cross-level datum consistency: L2/L3/L4 regional DEMs are also normalized to LMSL via VDatum — no level-to-level offset.

**Accepted datums for operator-uploaded bathymetry:** NAVD88, MLLW, MHW, MHHW, MSL. These are the datums the configured CO-OPS station supports as prediction request parameters. The operator specifies the datum on upload; the pipeline fetches CO-OPS predictions in that datum. If the operator's data is in a different datum, they convert before uploading.

**Historical note:** `bathymetry_resolver.py:normalize_to_msl()` and `_query_vdatum_offset()` are preserved in the marine service's codebase for potential future edge cases (exotic datums CO-OPS does not support, international expansion) but are not called from `download_bathymetry_for_level()`. The match-at-source strategy eliminates the need for local datum conversion in all common US cases.

#### USGS Great Lakes DEMs (Priority 3)

Per-lake GeoTIFF files from ScienceBase (Rohweder 2025, DOI: 10.5066/P1DA6L6U). Downloaded on first use, cached at `/etc/weewx-clearskies/great_lakes/{lake}.tif`, 365-day TTL. Requires `rasterio` (optional dependency, conditional import). Windowed reads load only the tiles intersecting the requested bbox — <50 MB from a 1.4 GB file.

#### CRM fallback (Priority 4)

NCEI ArcGIS ImageServer `getSamples` endpoint (POST, multipoint, 1000-point batches). ~90m effective resolution for most of the US coast. Adequate for Level 1 (1km grid) but produces staircase artifacts in Level 2/3 grids.

#### Profile extraction (1-D)

`download_bidirectional_profile()` in `enrichment/bathymetry.py` produces a 1-D depth transect from the coastline to deep water (~15m). Used for Level 3 grid sizing and cross-shore CURVE placement. When a regional DEM covers the spot, the profile uses OPeNDAP data (smooth depth progression). Otherwise falls back to single-point CRM queries (staircase pattern with ~5-6 unique values across 48 points).

#### Cache paths

| Data | Path | TTL |
|------|------|-----|
| Level 1 grid | `/etc/weewx-clearskies/swan_bathymetry_L1.json` | 180 days |
| Level 2 grid | `/etc/weewx-clearskies/swan_bathymetry_L2.json` | 180 days |
| Level 3 grid | `/etc/weewx-clearskies/swan_bathymetry_L3_{hash}.json` | 180 days |
| Spot profile | `/etc/weewx-clearskies/spot_profiles/{spot_id}.json` | 180 days |
| Great Lakes DEM | `/etc/weewx-clearskies/great_lakes/{lake}.tif` | 365 days |

**Attribution:** NOAA CUDEM data requires attribution: "NOAA National Centers for Environmental Information." Display on any page showing bathymetric data.

### §14.8 Shared NWS marine zone discovery utility

**File:** `providers/_common/nws_zones.py`

**Not a provider module.** Shared utility used by:
- NWS marine zone text forecast provider (§14.4) — `get_wfo_for_zone(zone_id)` to determine the WFO whose CWF product covers a known zone_id (no coordinates needed)
- NWS Surf Zone Forecast provider (§14.5) — `get_cwa(lat, lon)` to determine WFO from coordinates
- ~~NWPS nearshore wave data provider (§14.6)~~ — eliminated per ADR-093
- Marine zone alerts extension (§8) — `discover_marine_zones(lat, lon, radius_miles)` to discover marine zones within the operator's alert radius

**Functions:**

- `get_cwa(lat, lon) -> str` — `GET /points/{lat},{lon}` → the `cwa` (WFO office ID, e.g., `"ILM"`). Cached 24h, keyed by rounded coordinates.
- `get_wfo_for_zone(zone_id) -> str` — looks up `zone_id` in the cached `type=coastal` zone list (below) and returns the first entry of its `cwa` array. Raises `ProviderProtocolError` if `zone_id` isn't a known NWS coastal zone.
- `discover_marine_zones(lat, lon, radius_miles) -> list[MarineZone]` — see algorithm below. Each `MarineZone` has: `zone_id` (str), `name` (str), `distance_miles` (float).

**`discover_marine_zones` algorithm:**

1. `GET /points/{lat},{lon}` → extract `cwa` (WFO office ID, e.g., `"ILM"`)
2. `GET /zones/coastal` filtered by CWA → list of coastal marine zone IDs for this WFO (typically 6–16); this same cached zone list (24h TTL) backs `get_wfo_for_zone`'s lookup
3. For each zone: `GET /zones/coastal/{zoneId}` → extract polygon geometry (GeoJSON coordinates)
4. Compute minimum haversine distance from the input coordinates to each polygon's nearest vertex
5. Return zones within `radius_miles`, sorted by distance ascending

**Haversine accuracy:** ~0.1 miles is sufficient. Use the standard haversine formula or the existing project utility if one exists.

**Rate limiting:** Per-module rate limiter (5 req/s to `api.weather.gov`), matching the established per-module pattern. Each NWS consumer module (nws_marine, nws_srf, nws_zones, NWS alerts, NWS forecast) maintains its own rate limiter instance. Combined NWS traffic across all modules may exceed 5 req/s during cache-warming bursts — acceptable because NWS's actual enforcement threshold is well above 5 req/s per IP, and burst traffic only occurs at startup or after TTL expiry, not sustained.

**Invocation context:** `discover_marine_zones` is called at setup/wizard time, not per-request; results are stored in configuration. `get_cwa` and `get_wfo_for_zone` are called per-request by their respective providers (each independently cached — 24h for `get_cwa`, and `get_wfo_for_zone` rides the 24h-cached zone list).

### §14.9 OSM Overpass structure discovery

**File:** `endpoints/setup.py` (`GET /setup/marine/discover-structures`), T5.2.

**Not a dispatch-registered provider module.** Setup-time-only helper, same category as §14.7 (bathymetry) and §14.8 (NWS zone discovery): populates `config/marine_config.py`'s `StructureConfig` entries (`type`, `material`, `length_m`, `bearing_degrees`, `distance_m` — see OPERATIONS-MANUAL.md "Structure configuration") so the operator doesn't have to enter every jetty/pier/breakwater/seawall/groin by hand during surf spot setup. Feeds API-MANUAL §17 "Supplement 2 — Coastal structure effects" (the wave-transmission/reflection correction applied to SWAN output).

**Data source:** OpenStreetMap via the Overpass API — free, keyless, global coverage wherever OSM has coastal structure data mapped. `POST/GET https://overpass-api.de/api/interpreter`, `User-Agent: ClearSkies-WeatherStation/1.0 (structure-discovery)`.

**Query (Overpass QL):**

```
[out:json][timeout:10];
(
  way["man_made"~"breakwater|groyne|pier"](around:{radius_m},{lat},{lon});
  way["wall"="seawall"](around:{radius_m},{lat},{lon});
  way["man_made"="dyke"](around:{radius_m},{lat},{lon});
);
out body geom;
```

`radius_m` defaults to 2000 (query parameter, operator/wizard-adjustable).

**Tag mapping — OSM value → canonical `StructureConfig.type`:**

| OSM tag | `type` |
|---|---|
| `man_made=breakwater` | `breakwater` |
| `man_made=groyne` | `groin` |
| `man_made=pier` | `pier` |
| `wall=seawall` | `seawall` |
| `man_made=dyke` | `seawall` |

The response's `osm_type` field carries the raw OSM tag value (e.g. `groyne`, `dyke`) so the wizard/operator can see provenance even where it diverges from the mapped `type` (groyne→groin, dyke→seawall).

**Material mapping — OSM `material` tag → canonical `StructureConfig.material`:**

| OSM `material` | `material` | `material_source` |
|---|---|---|
| `concrete` | `impermeable` | `osm` |
| `rock` | `semi_permeable` | `osm` |
| `stone` | `semi_permeable` | `osm` |
| `wood` | `permeable` | `osm` |
| `metal` | `semi_permeable` | `osm` |
| missing or unrecognised | `null` | `operator` |

`material_source: "operator"` signals the wizard to require an operator choice before the structure can be saved — `_VALID_STRUCTURE_MATERIALS` has no "unknown" value.

**Geometry computation** (from each way's `geometry` array of `{lat, lon}` node objects, local Haversine/bearing helpers in `endpoints/setup.py` — no project-wide haversine helper exists, same per-module-copy pattern as §14.8 and every other haversine use in this codebase):

- `length_m` — sum of Haversine distances between consecutive nodes.
- `bearing_degrees` — forward-azimuth bearing from the first node to the last node (0=N, 90=E, 180=S, 270=W).
- `distance_m` — minimum Haversine distance from the query point (`lat`, `lon`) to any node on the way.

**Filtering:** Ways tagged `floating=yes` (marina dock fingers — irrelevant to wave physics) are excluded. Ways with computed `length_m` < 5.0 are excluded as digitisation noise. Remaining structures are sorted by `distance_m` ascending.

**Response field `geometry`.** Each `MarineDiscoveredStructure` (`endpoints/setup.py`) carries `geometry: list[list[float]]` — the way's full node list, `[[lat, lon], ...]` in OSM order, always present (every returned structure has ≥2 points; that's the length-computation input). This is a different field from `/setup/apply`'s `MarineStructureApplyConfig.coordinates` (`[[lon, lat], ...]` — **opposite axis order**), which the wizard populates from this endpoint's `geometry` before persisting to `config/marine_config.py`'s `StructureConfig.coordinates`. Do not assume the two share an axis order when wiring discovery output into an apply payload.

**Cache:** `get_cache()` (ADR-017 pluggable memory/Redis backend), TTL = 86400s (24h) — coastal structures rarely change. Key = hash of `(provider_id="overpass", endpoint="structure_discovery", {lat4, lon4, radius_m})`, same construction as §14.8's cache keys (lat/lon rounded to 4 decimal places per §3 "Cache key construction" — not the 3-decimal-place grouping originally sketched for this endpoint in the round brief; superseded to match the one established convention used everywhere else in this codebase).

**Rate limiting:** 1 req/s "be polite" guard against the free, shared `overpass-api.de` instance (`RateLimiter(name="overpass-structures", ...)`) — this is a setup-time-only endpoint, called once per surf spot then cached 24h, so the limit never trips in normal use.

**Error handling:** Any canonical `ProviderError` from the Overpass call (timeout, quota, 5xx after `ProviderHTTPClient` retries, unexpected response shape) is caught in the endpoint handler and returns HTTP 200 with an empty `structures` list and an `error` string populated — never a 500, and the failed lookup is not cached, so the next call retries live. Mirrors §14.7 bathymetry's "best-effort setup-time convenience" pattern: an Overpass outage does not block the wizard, the operator can still add structures manually.

### §14.10 NOAA OFS ocean model data (ADR-091)

**Module identity:** `providers/ocean/ofs.py`, `PROVIDER_ID = "ofs"`, `DOMAIN = "ocean"`.

**CAPABILITY:** `geographic_coverage = "us_coastal"` (major coasts — see coverage table below), `auth_required = []`. Supplies: water temperature (full column), salinity (full column), ocean currents (u/v components, full column), sea surface elevation (vs MSL and MLLW), seafloor depth, forecast time series. Dependencies: `xarray` + `netCDF4` + `fsspec` + `aiohttp` + `h5netcdf`, now in the marine service's `[nearshore]` pip extra (the API's `[marine]` extra is removed).

**Data source:** NOAA Operational Forecast Systems — 15 physics-based coastal ocean models (ROMS, FVCOM) at 34m–4km resolution, served via THREDDS/OPeNDAP at `opendap.co-ops.nos.noaa.gov/thredds/`. Updated 1–4 times daily depending on the model. Full research, verified OPeNDAP metadata, grid structure details, and code examples in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"Technical Detail: THREDDS/OPeNDAP Data Extraction".

**THREDDS timeout + NODD S3 fallback rung (operator-ordered 2026-08-16):** CO-OPS THREDDS hung indefinitely twice in 3 days (host root 200, all `/thredds` paths timed out; production refused and served stale for 7+ h both times), while the same files were verifiably present the whole time on NOAA's Open Data Dissemination (NODD) S3 mirror. Every THREDDS/OPeNDAP dataset open (`_get_grid`, `_extract_data`, the `fetch_forecast` per-fhr loop, and both opens in `fetch_surface_currents`) now goes through `_open_regulargrid_dataset(url)`:
1. THREDDS is tried first (unchanged primary), bounded to `_DATASET_TIMEOUT` seconds (60s, up from the previously-unused 20s constant) via `_open_dataset_with_timeout()` — a single-worker `ThreadPoolExecutor` per call, discarded with `shutdown(wait=False, cancel_futures=True)` on timeout (mirrors `services/bathymetry_resolver.py::fetch_opendap_grid`'s existing OPeNDAP-timeout idiom). A hung endpoint costs at most 60s per attempt, never an open-ended stall.
2. On THREDDS failure (timeout or any other exception), the same logical file is retried via its NODD S3 mirror URL — `_thredds_to_nodd_s3_url()` maps `NOAA/{MODEL}/MODELS/{Y}/{M}/{D}/{fname}` → `{model_lower}/netcdf/{Y}/{M}/{D}/{fname}` under `https://noaa-nos-ofs-pds.s3.amazonaws.com`. Opened via `fsspec.open(url, mode="rb").open()` + `xr.open_dataset(..., engine="h5netcdf")` for HTTPS ranged reads (never a whole-file download; the bucket verified HTTP 206 support). Same 60s timeout bound applies.
3. Both rungs failing raises, which every existing call site already catches identically to a pre-change failure — the file/cycle is treated as failed and the existing cycle-fallback loop continues. One INFO log line fires when the S3 rung succeeds (`OFS S3 fallback used: THREDDS failed for %s; served from NODD S3 mirror %s`). The three "cycles exhausted" refuse/warning messages in `fetch()`, `fetch_forecast()`, and `fetch_surface_currents()` now name both paths as exhausted. The C-77 refuse semantics in `providers/nearshore/swan.py` (empty-result → no-publish) are unchanged — this rung only changes how hard `fetch_surface_currents()` tries before returning empty.

**OFS models covered:** WCOFS (US West Coast, ~4km), GOMOFS (Gulf of Maine, ~700m), CBOFS (Chesapeake Bay, 34m–4.9km), DBOFS (Delaware Bay, 100m–3km), TBOFS (Tampa Bay, 100m–1.2km), CIOFS (Cook Inlet, 10m–3.5km), SFBOFS (San Francisco Bay, 10m–3.9km), NGOFS2 (Northern Gulf of Mexico, 45m–300m), SSCOFS (Salish Sea + Columbia River, 100m–10km), LMHOFS (Lake Michigan + Huron), LEOFS (Lake Erie), LOOFS (Lake Ontario), LSOFS (Lake Superior), NYOFS (Port of NY/NJ), SJROFS (St. Johns River FL). Full coverage and gap analysis in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md`.

**Key implementation rules:**
- Always use `regulargrid` files (pre-interpolated to regular lat/lon). Never use native `fields` files (curvilinear/unstructured grids requiring spatial interpolation).
- Grid point lookup: `Latitude` and `Longitude` are 2D arrays `[ny, nx]`. Use Euclidean distance with land mask filtering — `ds.sel()` does not work on 2D coordinate arrays.
- Cache grid coordinates per model (lat, lon, depth, mask, h arrays). TTL = 24h.
- Cycle selection: `floor(current_utc_hour / 6) * 6` for 4x/day models, fixed cycle for 1x/day (WCOFS = 03z). Fall back up to 4 cycles.
- Variables extracted at the nearest water grid point: `temp`, `salt`, `u_eastward`, `v_northward` (all `[time, Depth, ny, nx]`), `zeta`, `zetatomllw` (`[time, ny, nx]`), `h`, `mask` (`[ny, nx]`).

**Cache:** Key includes model name + cycle + lat/lon (rounded to 3 decimals). TTL = 1800s.

**Error handling:** Any THREDDS open failure for a given file — a 404, a timeout (>60s, `_DATASET_TIMEOUT`), or any other exception — tries the NODD S3 fallback rung (above) for that same file before anything else; the code does not discriminate by failure type. Only when *both* rungs fail for a file does the existing cycle-fallback loop step back to the prior cycle. Grid point on land → null result. All per error taxonomy.

**Implementation details (from code, 2026-07-13):**

- `fetch(*, model: str, lat: float, lon: float) -> dict` — primary entry point. Returns dict with `source`, `surface_temp`, `column_profile`, `surface_current_speed`, `surface_current_dir`, `salinity`, `water_level_msl`, `water_level_mllw`, `seafloor_depth`. Returns `{"source": "unavailable"}` on total failure.
- `find_ofs_model(lat: float, lon: float) -> tuple[str | None, str | None]` — returns `(primary, fallback)` by checking `OFS_DOMAINS` bounding boxes. When domains overlap, sorts by `_MODEL_RESOLUTION_DEG` (smallest first) and returns the two highest-resolution matches.
- `_get_grid(model: str)` — fetches and caches lat/lon/depth/mask/h arrays per model. Cache key: `ofs:grid:{model}`, TTL 86400s.
- `_find_nearest_water_point(lat_grid, lon_grid, mask, lat, lon)` — Euclidean `sqrt((lat_grid - lat)² + (lon_grid - lon)²)`, masks land cells (`mask == 0`), rejects if minimum distance > 0.5°.
- `_extract_data(ds, ny, nx, depth_levels)` — pulls `temp`, `salt`, `u_eastward`, `v_northward`, `zeta`, `zetatomllw`, `h` via xarray indexing.
- `_select_cycle(model, now_utc)` — walks back up to 48 hours in 6-hour steps. Returns the most recent valid cycle. 1x/day models (WCOFS) use fixed cycle (03z).
- Result cache key: `ofs:{model}:{lat:.3f}:{lon:.3f}`, TTL 1800s.
- Grid cache key: `ofs:grid:{model}`, TTL 86400s (grid topology is static).
- Constants: `_RESULT_CACHE_TTL = 1800`, `_GRID_CACHE_TTL = 86400`, `_MAX_CYCLE_FALLBACKS = 3`, `_DATASET_TIMEOUT = 60` seconds (raised from 20s 2026-08-16; now enforced via `_open_dataset_with_timeout()`, previously declared but unused).
- `_thredds_to_nodd_s3_url(thredds_url)` / `_open_dataset_with_timeout(opener, url, timeout)` / `_open_regulargrid_dataset(url)` — the THREDDS-timeout + NODD S3 fallback chain (2026-08-16), see above.

### §14.10a RTOFS surface-current provider for SWAN forcing (target — Phase S of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D9) **(ruled 2026-08-08; lands with Phase S of L1-BOUNDARY-REBUILD-PLAN)**

**Status: target — not yet implemented.** This section documents the S1 design verbatim from the plan. RTOFS
is already a Clear Skies data source in a different role — `providers/ocean/erddap_ocean.py` serves
`rtofs_3d` ("Temp column + currents + salinity, 8 km global, 41 levels, 8-day forecast") as the deep fallback
in the water-temperature chain (§14.12). This section describes RTOFS's NEW role as a SWAN current-forcing
input, a distinct gridded-U/V fetch path from that existing point/column ERDDAP query.

**Module identity (target):** new `providers/ocean/rtofs_currents.py`.

**Selection rule (P7 as amended 2026-08-09, operator-approved — a containment LADDER of
tidal-inclusive sources; the original RTOFS+STOFS composite below is VOID):**
`providers/ocean/ofs.py`'s `find_ofs_model` gains `find_current_source(l1_bbox)` returning the first
rung whose domain CONTAINS the entire L1 bbox (containment, never centre-in-box):

1. **Regional OFS** (`OFS_DOMAINS` containment; highest-resolution qualifier wins) — tidal-inclusive natively.
2. **STOFS-3D-Atlantic** (US East Coast + Gulf of Mexico + Puerto Rico) — 3-D baroclinic SCHISM;
   its horizontal water velocity is the TOTAL current (circulation + tide + surge), used directly.
   Velocity netCDF output pinned from the NCO inventory at implementation (one live shape check).
3. **PacIOOS ROMS Main Hawaiian Islands** (Hawaii) — 4 km, 3-hourly, 7-day, TPXO tidal elevation+velocity
   forcing, data-assimilating; via ERDDAP/THREDDS (the `pacioos` server §14.11 already lists, dataset
   `roms_hiig` family).
4. **Ladder exhausted → REFUSE (operator re-ruling 2026-08-09 — the RTOFS-alone rung is REMOVED:
   "the fallback is not a fallback... it is missing information... garbage data").** A bbox no
   tidal-inclusive rung contains raises `CurrentCoverageError` at selection → C-77 no-publish
   (`currents_fetch_failed` class), message naming the bbox and the declined rungs. Non-tidal-only
   currents are missing required input, never a degraded run. No RTOFS module exists. Inside the
   D7/D12 service area the three rungs blanket every supported region, so the refusal is a
   coverage-hole tripwire (surfaces at setup/config time via the Phase-A source report), not an
   expected runtime path.

**NO summing on any rung** — every rung is tide-complete; summing anything with
STOFS-3D or an OFS would double-count circulation. Missing timestep on the selected source →
`CurrentCoverageError`; source selection is per-cycle, never per-timestep (no cross-rung mixing mid-run).

**Currents tail-hold (Z3.9a, MARINE-PAGE-FIXIT-PLAN-2026-08-10 finding V3, operator ruling 2026-08-13
"(a)").** C-77 (a model runs on all its inputs or it does not run) is amended for the TAIL only: when the
selected current source's own forecast reach (e.g. WCOFS, `max_fhr=72`) ends BEFORE this run's window
does, `services/swan_runner.py::_write_current_txt()` holds (repeats) the last available U/V field for
the wind timesteps beyond that reach, rather than refusing the whole run, logging one WARNING naming the
reach time, the window end, and the held timestep count, and recording the note via
`state.record_currents_hold()` (surfaced at `GET /health` as `currentsTailHeld`). An INTERIOR gap (a wind
timestep inside the source's covered range with no match within 2 h) still raises `CurrentCoverageError`
unchanged, and a ZERO-field selection still refuses via the ladder above unchanged — the amendment is
tail-only, never for an interior hole or a total absence of usable current data.

**Why the composite died (evidence, 2026-08-09):** STOFS-2D-Global publishes NO velocity in ANY product —
regional GRIB2 carries exactly water level + surge (+1 unknown field; eccodes-inspected live), the global
netCDF fields files carry `zeta` + mesh topology only (header-inspected), and NOAA's own NOMADS STOFS
description page lists water levels as 2D-Global's only variables. The tide-only velocity field the
composite assumed does not exist operationally.

**Product (~~RTOFS rung~~ HISTORICAL — rung removed by the 2026-08-09 operator re-ruling above; the
route research is kept for the record only):** direct NOMADS netCDF
`pub/data/nccf/com/rtofs/prod/rtofs.YYYYMMDD/rtofs_glo_2ds_n{NNN}_prog.nc` (~155 MB/file, 3-hourly u/v,
xarray/netCDF4) — the ONLY live route: NOMADS has no `filter_rtofs.pl` CGI and retired OPeNDAP
server-side subsetting NOMADS-wide; §14.11's coastwatch ERDDAP rtofs datasets are gone from the live
server (stale rows flagged below). Output shape identical to `fetch_surface_currents` (list of
`{time, u_grid, v_grid}` at SWAN grid dims), so `_write_current_txt` (`services/swan_runner.py`) is
untouched. Selection logged once per cycle at INFO (provenance, not flagging).

### §14.11 ERDDAP ocean data (ADR-091)

**Module identity:** `providers/ocean/erddap_ocean.py`, `PROVIDER_ID = "erddap_ocean"`, `DOMAIN = "ocean"`.

**CAPABILITY:** `geographic_coverage = "global"`, `auth_required = []`. Config-driven module that handles multiple ERDDAP datasets through a single interface.

**Datasets:**

| Dataset key | Server | Dataset ID | Content | Depth | Lon convention |
|---|---|---|---|---|---|
| `mur_sst` | coastwatch.pfeg.noaa.gov | `jplMURSST41` | Surface temp only (1km, global, daily) | Surface | -180/+180 |
| `rtofs_3d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG3DForeDaily` **⚠ STALE — dataset gone from the live server (verified 2026-08-09, Phase-S scope-ack); water-temp chain's deep fallback silently unavailable; needs its own fix round** | Temp column + currents + salinity (8km, global, 41 levels, 8-day forecast) | 41 levels | 0–360 |
| `rtofs_2d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG2DFore3hrlyProg` **⚠ STALE — same, gone from the live server** | Surface SST (8km, global, 3-hourly) | Surface | 0–360 |
| `pacioos` | pae-paha.pacioos.hawaii.edu | `roms_hiig` | Full column (4km, Hawaii/Pacific, 36 levels) | 36 levels | -180/+180 |
| `caricoos` | dm3.caricoos.org | `FVCOM_Historical_3D_StructuredGrid` | Full column (800m, PR/USVI, 11 levels) | 11 levels | -180/+180 |

Standard ERDDAP griddap URL pattern: `https://{server}/erddap/griddap/{datasetID}.json?{variable}[(time)][(depth)][(lat)][(lon)]`. Handles longitude convention conversion per dataset. Full ERDDAP API consistency analysis and per-dataset details in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"ERDDAP API Consistency" and §"Fallback Data Sources".

**Cache:** Key includes dataset key + lat/lon. TTL per dataset: MUR SST 3600s (daily), RTOFS 1800s.

**Implementation details (from code, 2026-07-13):**

- `fetch(*, dataset: str, lat: float, lon: float) -> dict | None` — primary entry point. Returns dict with provider-standard fields (`surface_temp`, `column_profile`, etc.) or `None` on failure.
- `_build_url(dataset_config, lat, lon)` — constructs ERDDAP griddap JSON query URL with per-dataset variable names and longitude convention conversion (`lon + 360` for 0–360 datasets).
- `_parse_response(resp_json, dataset_config)` — parses `table.columnNames`/`table.rows`, filters NaN values, builds depth-level profile list when `has_depth=True`.
- `DATASETS` dict: keyed by dataset name, each entry specifies `server`, `dataset_id`, `variables` (dict of temp/salt/current variable names), `has_depth`, `lon_convention`, `ttl`.
- Cache key: `erddap_ocean:{dataset}:{lat:.3f}:{lon:.3f}`. TTL: MUR SST 3600s, all others 1800s.
- Error handling: broad try/except around HTTP fetch → `logger.warning(exc_info=True)`, returns `None`. Empty ERDDAP response (no data for time range) logged at WARNING.

### §14.12 Ocean data resolver (ADR-091)

**Not a provider module.** Service-layer orchestrator (`services/ocean_data_resolver.py`) that implements the ADR-091 fallback chain across providers and normalizes output. Endpoints call the resolver, not the ocean providers directly. Full architecture, canonical data models (`OceanDataResult` fields), two query modes, coverage tier semantics, per-consumer usage table, and unit conversion rules in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"System Integration: Marine Ocean Data Resolver".

**Interface:** `resolve(lat, lon, location_config, mode="modeled", needs="surface") -> OceanDataResult`

**Fallback chain (`mode="modeled"`):**

1. `location_config.ofs_model` set → OFS provider (§14.10). If fails, try `ofs_fallback`.
2. `location_config.ofs_region` set → ERDDAP regional model (§14.11, PacIOOS/CARICOOS).
3. Global fallback, split by `needs`:
   - `needs="full"`: RTOFS via ERDDAP (column + forecast), then MUR SST (surface only).
   - `needs="surface"`: MUR SST via ERDDAP (1km surface), then RTOFS surface.
4. All sources exhausted → `coverage_tier = "unavailable"`.

**`mode="observed"`:** Returns only a real sensor reading (on-premises or NDBC buoy within threshold). Does NOT fall back to models — null if no sensor. The caller can decide whether to then call again with `mode="modeled"`.

**Coverage tier field:** Set on the result so endpoints can populate response fields without branching on provider names. Values: `"ofs"`, `"regional_erddap"`, `"rtofs"`, `"mur_sst"`, `"observed"`, `"unavailable"`.

**Derived computations:**
- Thermocline depth: depth of maximum `abs(dT/dz)` gradient between adjacent depth levels
- Bottom temperature: temperature at the deepest non-null depth level
- Current speed/direction: `sqrt(u² + v²)` and `atan2(v, u)` from u_eastward + v_northward at depth=0

Each tier is independently wrapped in try/except — failure at one tier does not prevent trying the next.

**Implementation details (from code, 2026-07-13):**

- `resolve(lat: float, lon: float, location_config: dict, mode: str = "modeled", needs: str = "surface") -> OceanDataResult` — primary entry point. `location_config` keys: `ofs_model`, `ofs_fallback`, `ofs_region`.
- `_resolve_modeled(lat, lon, location_config, needs)` — runs the fallback chain. Each tier independently try/excepted with `logger.warning(..., exc_info=True)`.
- `_build_result(raw_data, coverage_tier)` — normalizes provider output into `OceanDataResult`. Computes derived values:
  - Thermocline depth: scans adjacent depth-level pairs for maximum `abs(dT/dz)` gradient
  - Bottom temperature: temperature at the deepest non-null profile entry
  - Current speed: `sqrt(u² + v²)` from u_eastward + v_northward at depth=0
  - Current direction: `atan2(v, u)` converted to meteorological convention (direction FROM)
- `mode="observed"` currently returns `coverage_tier="unavailable"` (no on-premises sensor support implemented yet).
- All returned values in raw units: °C, m/s, PSU, meters. Unit conversion happens at the endpoint layer.

**RTOFS's second role (target — Phase S of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D9) `(ruled 2026-08-08; lands with Phase S of L1-BOUNDARY-REBUILD-PLAN)`.**
RTOFS already appears in this resolver's fallback chain as `providers/ocean/erddap_ocean.py`'s `rtofs_3d`
column/point query — the deep fallback for water temperature and, incidentally, general ocean currents at a
point. §14.10a documents a SEPARATE, new role: RTOFS as a gridded SWAN current-forcing INPUT, fetched via a
distinct direct-NOMADS-netCDF gridded-U/V path (`providers/ocean/rtofs_currents.py`), selected as the LAST
rung of the §14.10a containment ladder (P7 as amended 2026-08-09 — no compositing; RTOFS serves alone,
loudly non-tidal). The two roles read the same underlying NOAA model but through different fetch paths for different
consumers (this resolver serves point/column queries for the water-temperature/ocean-data endpoints; the
SWAN current-forcing path serves a gridded U/V field to `_write_current_txt`) — they are not merged and do
not share a cache.

### §14.13 Water level compositor (ADR-091)

**Not a provider module.** Service-layer component (`services/water_level_compositor.py`) that combines CO-OPS harmonic predictions with the OFS non-tidal residual to produce a composite total water level forecast. See API-MANUAL §16 `CompositeWaterLevel` for the output model. Full algorithm and pseudocode in `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md` §"Implementation Design" → "Compositor algorithm". Bias correction rationale and OFS accuracy data in §"Research Questions — Answered" Q1/Q3/Q4. Cache warmer integration in §"Cache warmer integration". STOFS-2D-Global comparison (why it's not needed separately) in §"What STOFS-2D-Global Offers".

**Interface:** `compute_composite(predictions, observations, ofs_water_levels, now, target_unit="foot") -> dict`

**Algorithm:**
1. **Observed residual:** For each CO-OPS observation in the past 24h, interpolate the 6-minute prediction series to the observation timestamp. Compute `residual = observation.height − interpolated_prediction`.
2. **Current residual:** Most recent observed residual — ground truth for the meteorological effect.
3. **Forecast residual (OFS available):** `ofs_residual = ofs_zeta − coops_prediction`. Bias-correct: `bias = current_observed_residual − ofs_residual_at_now`. Apply `corrected = ofs_residual + bias`.
4. **Forecast residual (OFS unavailable):** Persistence — `residual_t = current_residual × exp(−dt / tau)` where tau = 12 hours.
5. **Total water level:** `prediction + corrected_residual` at each time step.

**Storm surge classification:** Configurable per location. Default thresholds: < 0.15 ft normal, 0.15–0.5 ft `"elevated"`/`"depressed"`, 0.5–1.0 ft `"significant"`, > 1.0 ft `"storm_surge"`.

**Cache warmer integration:** Runs after CO-OPS + OFS warm calls. Composite cached at 10-minute TTL (matches CO-OPS `water_level` observation refresh). The endpoint reads the cached composite, not recomputing per request.

**Implementation details (from code, 2026-07-13):**

- `compute_composite(predictions, observations, ofs_water_levels, now, target_unit="foot") -> dict` — primary entry point. The `target_unit` parameter (added in implementation) allows the compositor to return values in the operator's display unit directly.
- Returns dict with keys: `currentResidual` (object or None), `totalWaterLevelForecast` (list or None), `stormSurgeLevel` (str or None), `residualForecastSource` (str).
- `currentResidual` shape: `{"value": float, "quality": "good"|"stale", "source": "coops_observed", "description": str}`. Quality is `"good"` when the most recent observation is ≤1h old, `"stale"` when 1–6h old, absent when >6h.
- `_interpolate_prediction(predictions, target_time)` — linear interpolation of CO-OPS 6-minute prediction series. Handles edge cases (target before first or after last prediction).
- `_compute_ofs_residual_at_time(ofs_levels, predictions, target_time)` — finds the closest OFS forecast point within 2 hours, computes `ofs_height - interpolated_prediction`.
- `_classify_surge(abs_residual_ft, signed_residual_ft)` — applies threshold table. Note: classification operates on converted values (target unit), not raw meters.
- Persistence decay constant: `_PERSISTENCE_TAU_HOURS = 12.0`.
- Surge threshold constants: `_SURGE_THRESHOLDS_FT = {"minor": 0.15, "moderate": 0.5, "major": 1.0}`.
- Unit conversion via `weewx_clearskies_api.units.conversion.convert()`.

### §14.13a STOFS-2D-Global water-level provider + WLEVEL chain (Phase S of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D10)

**Status: LIVE (2026-08-09, marine `462b38f` — the RE-LAND).** The first landing
(`5d9d88b`) was reverted the same day after an OOM crash loop: the fetcher retained
each hourly field as the full conus.west grid (2145×1377) in nested Python float
lists, ~7 GB across the 73-hour fetch (plan decision log, session 5). The re-land adds
two binding memory-safety properties that are now part of this section's contract:
**(1) subset-at-extraction** — the eccodes/pygrib decode is sliced to the requested
bbox + a 2-cell pad, computed from the message's own grid coordinates, before
retention (full-grid buffers are transient, released per message); **(2) compact
storage** — retained values are numpy `float32` arrays (~0.5 MB total for an L1-shaped
bbox × 73 hours, vs ~7 GB in the reverted design). A memory KAT
(`TestMemorySafeExtraction`) pins both. Implementation notes discovered live: STOFS
regional GRIB2 files carry a 4-byte length prefix (no `GRIB` at byte 0); native
longitudes are [0,360), normalized on extraction; last-gridpoint eccodes keys are
absent (coordinate-array fallback). The section below documents the S2 design as
ruled.
Replaces the single-CO-OPS-station uniform WLEVEL stamp (§14.13's compositor, and `swan.py`/`swan_runner.py`'s
existing tide fetch site) with a spatially-varying grid at every SWAN level.

**Module identity (target):** new `providers/ocean/stofs_wlevel.py`.

**Product:** STOFS-2D-Global (`stofs_2d_glo`), NOAA's Surge and Tide Operational Forecast System (formerly
ESTOFS), 4 cycles/day live-verified, forecast to 180 h; the regional GRIB2 grid covering the domain. Region
tokens live-verified 2026-08-09: two-part for CONUS — **`conus.west`** (Huntington Beach), `conus.east` —
plus `hawaii`, `alaska`, `guam`, `puertori`, `northpacific`; pattern
`stofs_2d_glo.t{00,06,12,18}z.{region}.f{000..180}.grib2`. The GRIB2 carries the combined water level
(`elevhtml`, "Ocean Surface Elevation Relative to Geoid") plus a surge-only field; the water-level field is
what S2 consumes. Per-timestep water-level grid sampled to SWAN grid dims at each level.

**~~Dual extraction~~ VOID (2026-08-09, P7 ladder amendment).** The original design had this fetcher also
extract velocity for §14.10a's composite. **STOFS-2D-Global publishes no velocity in any product**
(GRIB2 + netCDF inspected live; NOAA's NOMADS STOFS description confirms water levels only). This fetcher
extracts the WATER-LEVEL field only; SWAN current forcing comes from §14.10a's amended source ladder.

**Datum.** STOFS ≈ LMSL. **Cutover gate:** before STOFS becomes primary, 24 h of STOFS values at the
tide-station cell are compared against CO-OPS predictions; `|mean bias| ≤ 0.15 m` passes. A breach means
CO-OPS stays primary and the round STOPs and surfaces — never a silent proceed on an unverified bias.

**WLEVEL chain (AMENDED 2026-08-11 — operator ruling, MARINE-PAGE-FIXIT-PLAN Phase T: "ONE SOURCE.
THAT IS IT."; supersedes the STOFS → CO-OPS-uniform → refuse chain below):** water level = **STOFS
only**, for every run type (full cycles AND the hourly stationary fill, previously CO-OPS-uniform) and
every model consumer — SWAN's WLEVEL forcing, the 1-D surf pipeline's per-timestep tide (sampled from
the same STOFS field at the coastline anchor via `_precompute_swelltrack_for_spot(stofs_wlevel=...)`),
and the beach-profile serving path. STOFS unavailable or gapped → the run REFUSES loudly
(`tide_fetch_failed` no-publish, per-spot, first missing timestep named); there is NO fallback source
and NO substituted value anywhere in the model path (the shared fetch helper is
`_fetch_stofs_wlevel_or_refuse()`, one definition, both run paths). CO-OPS tide predictions remain in
use only by display/informational consumers outside the model (tide charts, fishing/beach-safety
overlays). Landed: marine `53eea82` + `a8a27e2`; ADR-104 D10 amendment same date. ~~Original chain
(historical): STOFS → CO-OPS-uniform (fallback selection logged loudly at fetch) → refuse
(`tide_fetch_failed`).~~ The "~30 km uniform tide"
in-code justification comment (§6 row 5 of the brief) is deleted with the uniform-primary path it justified —
not kept as stale commentary.

**Field-based writer (corrected 2026-08-09, lead code-read).** The spatially-varying writer ALREADY EXISTS:
`services/swan_runner.py::_write_wlevel_grid_txt` (:2329, takes `grids[timestep][j][i]`); `_write_wlevel_txt`
(:2285) is the spatially-UNIFORM stamp being retired from primary duty. S2 is WIRING — the all-levels wlevel
path routes STOFS per-timestep grids into the existing grid writer; neither writer is rewritten. Command
grammar (`INPGRID/READINP WLEVEL ... NONSTAT`) is pinned unchanged; only the VALUES in `WLEVEL.txt` change.
Source selection is per-cycle: a timestep gap within STOFS data = STOFS fetch failure for the whole cycle →
**REFUSE (`tide_fetch_failed`) — the CO-OPS-uniform fallback was removed 2026-08-11 (ONE SOURCE
amendment above)**; never mixed sources within one run.

**Coverage-window-driven fetch depth (Z3.9a, 2026-08-13, MARINE-PAGE-FIXIT-PLAN-2026-08-10 finding V1).**
`fetch_stofs_wlevel(bbox, *, coverage_end)` no longer takes a fixed `forecast_hours` depth — the caller
(`providers/nearshore/swan.py`'s tide fetch site) states the coverage window it requires (`coverage_end`,
this run's own t_end — for the full cycle, the run's HRRR cycle `C` + 72 h; for the hourly fast cycle, that
cycle's own 12-hour window end), and the fetcher derives how deep the selected cycle must be fetched:
`required_hours = ceil((coverage_end − candidate_cycle) / 1h)`. A `required_hours` beyond STOFS's own 180 h
forecast ceiling refuses immediately (an older candidate only ever needs MORE hours, never fewer, so no
fallback could help) rather than attempting a doomed fetch. This closes the defect where every supporting
feed was fetched a fixed 72 h deep from its OWN (sometimes older, fallback) cycle, so coverage structurally
fell short of the run's real window end whenever the fallback ladder fired. The candidate-cycle
availability-lag constant (`_CYCLE_AVAILABILITY_LAG`) is corrected from 2 h to **6 h** (measured
2026-08-13 via Last-Modified probe against live NOMADS — STOFS posts markedly later than the 2 h this
module previously assumed).

### §14.14 HRRR wind provider (ADR-093, ADR-094)

**Module identity:** `providers/wind/hrrr.py`, `PROVIDER_ID = "hrrr"`, `DOMAIN = "wind"`.

**CAPABILITY:** `geographic_coverage = "us"`, `auth_required = []`. `supplied_canonical_fields` includes U-component and V-component of wind at 10m above ground level, earth-relative.

**Region-aware wind sourcing (target — Phase W of L1-BOUNDARY-REBUILD-PLAN, ADR-104 D8) `(ruled 2026-08-08; lands with Phase W of L1-BOUNDARY-REBUILD-PLAN)`.**
Wind source is selected per region at setup: HRRR CONUS product for CONUS (this module, unchanged); **HRRR-AK**
for Alaska (dormant per D12's territory descope, not implemented); **GFS alone** (§14.16) wherever no HRRR
product exists — Hawaii, PR/USVI, other territories. This module's `dir=/hrrr.{date}/conus` hardcode
(`providers/wind/hrrr.py:598`) is CONUS-only by construction; a Hawaii/no-HRRR region needs a GFS-only mode
for the 0–72 h wind blend (`swan_runner.py:2690-2807`), reusing the existing 48–72 h GFS 3-hourly→hourly
interpolation leg for the full 0–72 h range instead of only the tail. C-77 (all-inputs-required) stays
intact in a GFS-only region: GFS is the required input there; nothing is silently dropped or substituted.

**Availability:** Part of the marine service, not the API. Invoked by the marine service's SWAN runner (`services/swan_runner.py`), not by the API cache warmer. The marine service fires HRRR warm at startup and on the extended cycle schedule (4×/day at 00/06/12/18Z) when the marine service's `[nearshore]` pip extra is installed.

**Data source (primary):** NOMADS Grib Filter at `https://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_2d.pl`. Supports geographic subsetting (bounding box), variable selection (UGRD/VGRD at 10m AGL), and GRIB2 output. Free, no API key.

**Data source (backup):** AWS S3 at `s3://noaa-hrrr-bdp-pds/`. Same data, hosted by Amazon as a public dataset.

**Schedule:** HRRR runs on a fixed hourly schedule (00Z through 23Z). Availability: ~45–60 minutes after the nominal run hour. Completely predictable — no dependency on human forecaster input.

**Forecast range limitation:** HRRR does not produce a consistent forecast range. NCEP allocates different forecast lengths depending on the cycle:

| Cycle times (UTC) | Forecast range | Hourly wind grids |
|---|---|---|
| 00Z, 06Z, 12Z, 18Z (4 per day) | 48 hours | f00–f48 (49 grids) |
| All other hours (20 per day) | 18 hours | f00–f18 (19 grids) |

SWAN uses only the 4 extended cycles (00/06/12/18Z) to get the full 48-hour HRRR range. GFS wind (§14.16) supplements hours 48–72 to fill the 72-hour surf forecast card. See §14.15 for the blended wind architecture.

**Posting is not atomic.** NOAA posts an extended cycle's forecast-hour files sequentially over roughly 60–90 minutes after the nominal cycle hour, not all at once. A fetch made while posting is still in progress returns only the hours posted so far, and the current code does not verify it received all 49 grids before accepting the cycle as complete — a live journal survey (2026-08-03) found every extended-cycle first fetch partial, ranging 7–31 of 49 grids.

**Extracted variables:**

| GRIB2 parameter | Variable | Description |
|---|---|---|
| UGRD:10 m above ground | U-component | East-west wind at 10m AGL |
| VGRD:10 m above ground | V-component | North-south wind at 10m AGL |

**Wind rotation (CRITICAL):** HRRR uses a Lambert Conformal Conic projection. Wind components in GRIB2 files are grid-relative (U positive = East along the grid's X axis, not geographic East). Before passing winds to SWAN, they MUST be rotated to earth-relative using the Lambert Conformal grid parameters:

Rotation formula (full NCEP Lambert Conformal, NCEP Office Note 388 Appendix C):
1. Compute cone factor: `n = sin(latin1)` (tangent case, latin1 = latin2 = 38.5° for HRRR → n ≈ 0.6225)
2. Per grid point: `alpha = radians(n × (lon_grid_point - lov))`
3. Rotate: `U_earth = U_grid × cos(alpha) - V_grid × sin(alpha)`, `V_earth = U_grid × sin(alpha) + V_grid × cos(alpha)`

Source the exact HRRR Lambert parameters (`lov`, `latin1`, `latin2`) from the GRIB2 metadata (eccodes or pygrib). The cone factor `n` must NOT be omitted — dropping it (equivalent to n=1, Polar Stereographic) over-rotates HRRR winds by ~60%. Skipping rotation entirely produces wind inputs that are systematically wrong by up to ~20° near domain boundaries.

Python formula approach preferred (eliminates wgrib2 binary requirement for wind rotation). If wgrib2 subprocess is used, log a clear error if wgrib2 is not found on PATH.

**Incident note (W6, 2026-08-09, marine `70d442f`):** from the module's introduction until this fix, the eccodes extraction requested the misspelled key `LovInDegrees` (correct: `LoVInDegrees`, capital V) inside a single try/except that zeroed all three Lambert parameters on every real fetch — `latin1=latin2=0 → n=0 → alpha=0`, i.e. **no rotation at all** (not the lon_first/lon_last approximation the old WARNING text claimed; per-point longitudes are read outside that try/except, so the approximation branch never engaged). The three parameters are now read independently (one failing key cannot zero the others, both eccodes and pygrib backends), extraction is KAT-pinned against a recorded NOMADS fixture (`tests/test_hrrr_lambert_rotation.py`), and the lon_first/lon_last per-column approximation survives only as a last-resort fallback for files with no per-point longitudes, logging at ERROR — it should never fire on a well-formed NOMADS response.

**Cycle fallback:** "Posted" is determined by f00 alone — if f00 returns data, the cycle is treated as posted regardless of how many later forecast hours are actually available. The per-hour fetch loop stops at the first 404 *after* f00 and returns whatever hours it collected as a success (logged at DEBUG); the cycle-fallback loop (up to 2 earlier cycles, stepped back 6 h at a time for extended cycles) is reached only when f00 itself 404s. A partially-posted extended cycle is therefore indistinguishable from a fully-posted one and never triggers fallback to an earlier, fully-posted cycle. This fetch-and-fallback behavior describes `hrrr.py`'s own inline fetch — the mechanism the wind-provider rework (`docs/planning/briefs/WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03.md`) supersedes for its consumers, one migration step at a time (§5): the full 48h SWAN run (step 3) and the hourly fast cycle (step 4) now read `services/wind_timeline_store.py`'s assembled store instead, which tracks per-cycle completeness itself and never hands either run trigger a partial cycle (`get_wind_records()`'s regime-aware refuse-on-gap contract). Display wind (step 2) reads the SAME assembled store but through a deliberately DIFFERENT, tolerant accessor — `get_present_hours()` — which never refuses on a gap; it is PRIMARY for every hour it returns, with the run-forced `wind_for_display` field as the PERMANENT per-hour fallback (Q3 ruling, 2026-08-11 — see the cache-key table above), because the store's self-bounding design (age-out at wall-clock now + native 3-hourly far window) means a refuse-on-gap whole-timeline read can essentially never succeed for the served forecast range. The inline fetch described in this paragraph stays live for the manual trigger and tests until migration step 5 deletes it outright (for the run triggers; display wind's own request-time HRRR fetch was deleted at migration step 2).

**Bounding box:** Configurable per marine location. Default: spot coordinates ± 0.2° (configurable via wizard SWAN grid bbox settings).

> **`(landed 2026-08-14, Plan Amendment A1; as-built)` — wind-store bbox growth with the big-L1 domain (D6, ADR-108).** The wind-timeline-store gatherer's bbox derives from the L1 domain via the EXISTING derivation (unchanged mechanism, no new code) — extending L1 to its as-built 142×169 meshes (≈145.07 × 167.07 km, D1) grew the gatherer bbox with it; the store was cleared and regathered at the wider box, **`leftlon = -119.60`**. HRRR CONUS and GFS both cover 32.6°N offshore, so no wind-source change was required. Disk/transfer growth is bounded and trivial versus the existing store; no schedule/cadence change, no store schema change. WW3 input at the new S boundary verified good from raw GRIB: HTSGW 0.77–1.17 m vs the old boundary's 0.46–0.93 m — the 30–60% energy A1 exists to capture.

**Cache:** Key = `(provider_id, bbox_hash, cycle_time)`. TTL = 3300s (55 min) (`hrrr.py:101` `_CACHE_TTL_SECONDS`).

**Error handling:** 404 on all attempted cycles → `ProviderUnavailableError`. Network errors → canonical taxonomy. GRIB2 parse error → `ProviderProtocolError`.

**Rate limiting:** 2 req/s to NOMADS (shared NOAA infrastructure).

### §14.15 SWAN runner (ADR-093, corrected ADR-095)

**Not a network provider.** `providers/nearshore/swan.py` is a thin provider wrapper around `services/swan_runner.py`. It follows the existing provider interface pattern but runs a local SWAN subprocess instead of making a network call.

**Module identity:** `providers/nearshore/swan.py`, `PROVIDER_ID = "swan"`, `DOMAIN = "nearshore"` (ADR-096 renamed from `trushore`).

**SWAN binary:** SWAN 41.51AB (Fortran; version self-reported in PRINT output, verified on librewxr 2026-08-06 — docs previously claimed 41.45). Compiled from source via `scripts/install_swan.sh` or included in the Docker image. Binary on PATH at `/usr/local/bin/swan`. Marine service startup check: if `[nearshore]` extra is installed but SWAN binary is not found, log CRITICAL with installation instructions. The surf endpoint returns null surf data until SWAN is available — no fallback to any other model.

**Input sources (all from cache — they run on their own schedules):**

| Input | Source | Cache key pattern |
|---|---|---|
| Wind forcing (hours 0–48) | HRRR wind provider (§14.14) — 3km resolution, extended cycles only | `(hrrr, bbox, cycle_time)` |
| Wind forcing (hours 48–72) | GFS wind provider (§14.16) — 0.25° resolution, supplements HRRR | `(gfs, bbox, cycle_time)` |
| Deep-water boundary | WaveWatch III (§14.3) | `(wavewatch, ...)` |
| Bathymetry (2-D grid) | Resolver chain: operator file > NCEI regional OPeNDAP > Great Lakes > CRM fallback (§14.7) | Per-level cache: `swan_bathymetry_L{1,2,3}.json`, 180-day TTL |
| Water level (WLEVEL) | CO-OPS tidal predictions — fetched in the DEM's native datum (not MLLW). Datum-matched to BOTTOM per ADR-098. Display endpoint stays MLLW. | Cache key includes datum |
| Ocean currents (CURRENT) | OFS surface current U/V (§14.10) — time-varying per grid point. Omitted when unavailable (ADR-095) | `(ofs, ...)` |
| Coastal structures (OBSTACLE) | Wizard Overpass API discovery — native SWAN OBSTACLE command (ADR-095) | From marine location config |

#### Datum matching

**Rule:** SWAN requires BOTTOM (bathymetry) and WLEVEL (water level) on the same vertical datum. SWAN does not detect or report datum mismatches — a mismatch produces silently wrong depth calculations that corrupt wave breaking predictions.

**Dual CO-OPS fetch:** Each SWAN run makes two separate CO-OPS tide prediction fetches:

1. **Display fetch** (`datum=MLLW`): Serves the `/api/v1/tides` public endpoint. MLLW is the US chart standard. This fetch is unchanged by ADR-098 and is unaffected by any SWAN datum changes.
2. **SWAN fetch** (`datum={DEM's vertical_datum}`): Used for WLEVEL input to SWAN. The SWAN pipeline reads the DEM's `vertical_datum` from the bathymetry cache and passes it to the CO-OPS request. CO-OPS performs the datum conversion server-side. Both fetches are cached separately; cache keys include the datum parameter.

**What the pipeline does:** After downloading bathymetry, `swan.py:run_all_spots()` reads the `vertical_datum` from the bathymetry cache JSON. It then fetches CO-OPS predictions with `datum={vertical_datum}` and passes them to the SWAN runner for WLEVEL. The display endpoint (`/api/v1/tides`) continues to use `datum=MLLW` — no change to public output.

**Prohibited pattern:** A single-point VDatum query applied uniformly to the entire bathymetry grid is not an acceptable alternative. Vertical datum offsets are spatially varying — tidal datums (MLLW, MHW, MHHW relative to NAVD88) vary in the cross-shore direction, exactly the direction SWAN grids extend. A single center-point offset is increasingly wrong toward the grid edges, which is where breaking and scoring occur. See `docs/planning/briefs/SWAN-DATUM-CONSISTENCY-BRIEF.md` §3.3–§3.5 for the full rationale. The match-at-source strategy avoids this class of error entirely.

**Failure mode:** If the bathymetry DEM's `vertical_datum` is `"UNKNOWN"`, or if CO-OPS does not support the requested datum for the configured station, the SWAN level fails explicitly with an ERROR log. The system never proceeds with an unverified datum mismatch. There is no silent 0.0 m fallback.

**SWAN runner** (`services/swan_runner.py`) — **this subsection predates ADR-108/ADR-109 and describes an older three-level-SWAN design; `_run_level1()` was deleted 2026-08-23 (marine `3c550ae`/`c29266d`) and no longer exists. The deep-water leg is WW3 (§14.18); SWAN's own chain now starts at L2, fed by WW3 via BOUNDNEST3, not by a SWAN L1 subprocess's `NESTOUT`.** Remaining bullets below describe L2/L3 unchanged:

- `SWANRunner.__init__`: takes config (per-level grid bboxes, surf spot coordinates, bathymetry data, SWAN binary path)
- `run(hrrr_wind_field, gfs_wind_field, ww3_boundary, cudem_bathymetry, tide_predictions, ofs_currents)`: orchestrates the nested SWAN run (L2 → L3, WW3-fed at L2), returns transect data per spot keyed by spot_id (ADR-095)
- ~~`_run_level1(...)`: runs Level 1 (1 km) SWAN~~ — REMOVED 2026-08-23; WW3 computes the deep-water leg instead (§14.18)
- `_run_level2(tmpdir, blended_wind, cudem_bathymetry, wlevel, current)`: runs Level 2 (100 m) SWAN with WLEVEL/CURRENT inputs, writes `NESTOUT` boundary files for Level 3
- `_run_level3(tmpdir, blended_wind, cudem_bathymetry, wlevel, current, obstacles)`: runs Level 3 (40 m) SWAN with WLEVEL/CURRENT/OBSTACLE inputs, outputs CURVE transect TABLE and the **handoff** SPECOUT/`TABLE PT*` at each unique per-transect handoff cell. *Previously described as "SPECOUT at ~10m depth points"; void — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture. The deep-water-reference SPECOUT is written by `_run_level2()`, not here.*
- `_stitch_wind(hrrr_wind_field, gfs_wind_field)`: blends HRRR (hours 0–48) and GFS (hours 48–72) into a single 72-hour wind input. **Z3 migration step 3:** the SWAN input writer (`services/swan_formats.hrrr_to_swan_wind()`) now hard-validates the stitched series' cadence — a non-uniform/gapped result raises `WindCadenceError` (caught as `no-publish: wind_cadence_non_uniform`) rather than being passed through unchecked. Since migration step 3, the wind gatherer's assembled store (below) also refuses a gapped window at the source (`wind_series_gap`), so a gapped stitch is structurally unreachable in the store-driven run path; the writer's own validation remains as a second, independent check.
- `_write_input_files(tmpdir, wind_field, boundary, bathymetry, grid_level, swan_level="L2")`: writes SWAN INPUT, BOTTOM.txt, WIND.txt, BOUND_SPEC.txt for a given grid level. **`swan_level`** (WC-D1) selects the physics package: `"L1"` would emit GEN3 ST6 + SSWELL ZIEGER + NEGATINP (that branch is now unreachable — no caller passes `"L1"` since SWAN's own L1 run was removed 2026-08-23); the default `"L2"` emits GEN3 WESTHUYSEN. Returns grid_info dict
- `_spawn_swan(tmpdir)`: subprocess `swan < INPUT`, captures stdout/stderr, raises `SWANRunError` on non-zero exit or severe errors in Errfile
- `_check_convergence(tmpdir, grid_level)`: health checks after each SWAN run — PRINT scan for `******`, NaN scan in hotstart/TABLE output, and valid-point fraction check; raises `SWANConvergenceError` on failure (see convergence gate subsection below)
- `_save_hotstart(run_dir, grid_level)`: copies hotstart file from run dir to persistent parent dir for next cycle; only called for nonstationary runs (see hotstart isolation subsection below)
- `_parse_output(tmpdir, grid_info)`: reads SWAN TABLE output (HEAD format), discovers column indices from header line. Extracts HSIGN, HSWELL, DIR, TM01, DEPTH, QB, DISSURF, DSPR at each transect point. Matches rows to spots by (Xp, Yp) coordinates. Also parses the two SPECOUT/TABLE extractions — the deep-water reference (L2, the spot's measured ~15 m contour) and the per-transect handoff — into their two separate result channels (ADR-095 Amendment 1; see "Multi-SPECOUT extraction" below). *Previously described as "SPECOUT files at ~10m depth points"; void — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture.*

**Nested grid architecture (ADR-093 Amendment 3, plan task E4/E2b, 2026-07-27 — supersedes the three-level description that follows this note in older readings; updated 2026-08-23 for L1 removal):** The WW3 deep-water leg (§14.18) always runs and hands off to SWAN L2 via BOUNDNEST3; a cluster with an eligible structure or an operator-classified refraction feature (point break/headland/bay break) additionally runs L3 and, for a structure, L4 — `WW3 → L2 → L3 → L4`. A cluster with neither is unchanged: `WW3 → L2` only. No operational nearshore system runs fine resolution over the full domain — all use nested grids.

| Grid level | Config key | Resolution | Typical domain | Runs when |
|---|---|---|---|---|
| WW3 (deep-water leg, formerly "L1") | `outer_grid_resolution_km`; code/config label `deep_water` (renamed from `level1` 2026-08-27, marine `c57bb8e`, plan §S3 (b); the on-disk `swan/level1/` directory and `swan_bathymetry_L1.json` filename are unchanged) | ~1 km | ~145km × 167km (contains the Channel Islands, ADR-108 D1 containment) | Always — WW3, not SWAN (SWAN's own L1 compute removed 2026-08-23, marine `3c550ae`/`c29266d`) |
| L2 (inner) | `inner_nest_resolution_m` | ~100 m | ~20–30km × 10–15km (tight around surf spots, from `swan_domain_bbox`) | Always |
| L3 (coarse nest / refraction) | — (`_L3_RESOLUTION_M`, `services/swan_domain.py`) | 40 m | ~1,500m × 1,300m ≈ ~1,400 cells at HB (contains L4 + clearance); *not* the 30 m contour | Structure present (nests L4) OR classified point break/headland/bay break — never otherwise (ADR-093 Amendment 3, D2) |
| L4 (structure grid) | — (`_STRUCTURE_GRID_DX_FLOOR_M`, `services/swan_domain.py`) | 10 m, fixed (operator ruling 2026-07-27) | Rotated rectangle in the **beach frame** (rotation = resolved beach facing, not a structure axis) — the union of every eligible structure's footprint + the handoff points of every transect it shadows (marine `4e79d21`, 2026-08-01); measured HB regen 2026-08-01: 46×137 = 6,302 cells, u_span 450 m, v_span 1358 m, rot 216.4° | Eligible structure (pier/jetty/groin/breakwater) present AND it shadows ≥1 surf-area transect |

The `~10,000–20,000` grid-point / `≤400 MB` total that this table previously cited was the pre-Phase-E three-level (L1+L2+L3-always) figure and no longer applies uniformly — an open-beach spot with neither trigger runs only WW3+L2 (well under that figure); a structure spot additionally runs L3+L4 (L2+L3+L4 ≈ 12,600 cells at HB, ADR-093 Amendment 3 D8). WW3 hands its spectrum to SWAN's L2 boundary via **BOUNDNEST3** (ADR-109 D6) — a different mechanism from SWAN's own `NESTOUT`/`NGRID` chain that the rest of this paragraph describes for L2→L3→L4. L2 reads L3's boundary needs via SWAN's `NGRID` command and writes its own `NESTOUT`; when L3 runs, it reads L2's `NESTOUT`; when L3 nests L4 (structure case), L3 itself writes a further `NESTOUT` sized to L4, which L4 reads. Multiple surf spots on the same coastline share the WW3 leg and L2; each cluster gets its own L3/L4 nest when triggered. The runner copies boundary files between level subdirs: WW3's transfer file (`level0/`) → `level2/nest_in.dat` (via BOUNDNEST3, not a file copy), `level2/nest_out.dat` → `level3_{idx}/nest_in.dat`, and (structure case) `level3_{idx}/nest_out.dat` → `level4_{idx}/nest_in.dat`. The `level1/` directory name persists in code/config as the legacy geometry label for the deep-water domain WW3 now sizes itself over — it no longer holds a SWAN L1 nest.

Time step: 10 minutes (SWAN default non-stationary). Output timestep: 1 hour. Forecast span: 72 hours (HRRR hours 0–48, GFS hours 48–72).

**Output:** `dict[spot_id, list[MarineForecastPoint]]` — 72 forecast hours per spot. Each `MarineForecastPoint` carries `waveHeight=Hs`, `wavePeriod=Tm01`, `waveDirection=MWD`, and `time` (ISO-8601). Source attribution ("swan") is set at the `SwanProvider` response level, not inside `MarineForecastPoint` (which has no `source` field). **Validation:** SWAN INPUT files set `QUANTITY HSIGN TM01 DIR excv=-9.` (explicit no-data sentinel per SWAN user manual §3.5). The TABLE parser rejects rows with values ≤ -9 (exception value) or extreme upper bounds (Hs > 25m, Tm01 > 35s). NaN values are also rejected. Sub-1s Tm01 and near-zero Hs are physically valid SWAN output for weak wind-sea and are NOT rejected.

**SWAN INPUT file conventions (per SWAN 41.51 user manual):**

| Setting | Value | Why |
|---|---|---|
| `SET ... MAXERR 2` | Fail on SEVERE errors (level 3) only; warnings (level 1, including the boundary-height-mismatch warning) and SWAN's own auto-repairable errors (level 2) still let the run continue | Was `MAXERR 3` ("run no matter what"), which hid genuinely broken runs (marine `51543b1`, 2026-08-01, operator: "set the model to fail if it is not running correctly, not hide a bad run"). The old `MAXERR 3` row's own rationale was itself wrong — PRINT shows the boundary mismatch as a level-1 `** WARNING`, not level 2, so `MAXERR 2` does not halt on it. SWAN's own default is `MAXERR 1`. |
| `QUANTITY HSIGN TM01 DIR excv=-9.` | Explicit no-data sentinel | Without this, SWAN uses an implementation default indistinguishable from real near-zero values |
| `TABLE ... TIME XP YP HSIGN TM01 DIR` | SWAN output quantity names | `HSIGN` (not `HS`) is the correct quantity name; `TIME` must be explicitly requested (not automatic) |
| `INIT HOTSTART 'hotstart.dat'` | Load wave field from previous run | Eliminates cold-start spin-up; t=0 has realistic waves immediately. **Must be emitted after both `CGRID` and `READ BOT`** — see below |
| `HOTFILE 'hotstart.dat'` | Write wave field after COMPUTE | Saved to persistent location for next cycle |

**`INIT` command ordering is load-bearing** (marine `aa4553d`). SWAN requires `INIT` to follow both `CGRID` and `READ BOT` (`swanpre1.f` `INITVA` guards: *"command INIT should follow CGRID"*, *"command INIT should follow READ BOT or READ UNSTRUC"*). Both guards raise at MSGERR level 2 — **non-fatal** — so SWAN keeps running with `MXC`/`MCGRD` unset instead of stopping, and the failure presents as a hotstart crash that self-heals via cold retry every cycle rather than as an input error. Reproduced directly: with `INIT` before `CGRID`, SWAN's free-unit-number reader falls back to an unconnected default `fort.21` (0 bytes) and hits immediate EOF; with `INIT` after `CGRID` but before `READ BOT`, it segfaults inside `initva_`. `build_swan_input()` emits it after both predecessors. The `HOTFILE` write side, grid, and physics are unaffected by this ordering.

**Nonstationary `COMPUTE` keyword — readers must accept every legal abbreviation** (marine `bed7ec7`). `build_swan_input()` emits SWAN's shortest legal form, `COMPUTE NONST <tbeg> <dt> MIN <tend>`. Two readers previously tested for longer spellings (`COMPUTE NONSTATIONARY`, `COMPUTE NONSTAT`) and therefore never matched, with two consequences: the L2 deep-water-reference `SPECOUT`/`TABLE` commands were emitted with no `OUTPUT <tbeg> <dt> MIN` clause, so SWAN wrote only the final computed time — 1 row where 67 (one per forecast hour) are expected — and every nonstationary run was QA'd against the *stationary* convergence criteria. Both readers are now centralised on `_is_compute_nonstat()` / `_compute_nonstat_tbeg()`, which match on the prefix SWAN itself accepts (`COMPUTE` plus a second token beginning `NONST`); `tbeg` is token 2 for every accepted form. The writer is deliberately unchanged.

**QB breaking-zone guard tolerates per-station gaps** (marine `bed7ec7`). SWAN writes its exception value (`Hs = -9`) at a station that has run dry, and `_parse_transect_table()` drops that row, so the station has no QB entry. Both handoff selectors previously replaced the **whole** per-hour QB array with `None` when **any** station was missing, which returned `refine_handoff_with_qb()` at its "no QB data available" path — silently, for every station, every hour, every cycle, while its own docstring promised never to serve a sample from a breaking cell. `refine_handoff_with_qb()` now accepts per-station `None` entries: a station with unknown QB is never read as clean (the seaward search steps over it) and the stations that do have data are asserted normally. `_DEFAULT_QB_THRESHOLD` (0.05) is unchanged. Coverage is accumulated per run and logged at **WARNING** once per transect, naming the reason and the count of stations and hours affected, so the guard going dark is no longer silent.

**Per-level physics (SWAN-L3-STABILITY-PLAN Phase 2):**

The shared physics block is differentiated per level. Common commands emitted at all levels: `GEN3 WESTHUYSEN`, `BREAKING CONSTANT 1.0 0.73`, `FRICTION JON 0.038`, `TRIAD`. **`FRICTION JON` was `0.067`; corrected to `0.038` (marine `51543b1`, 2026-08-01)** — the SWAN User Manual §FRICTION recommends 0.038 m²/s³ for typical sandy bottoms, applied to both wind sea and swell, and explicitly discourages 0.067 "even for wind sea conditions." The old 0.067 value (~76% more bottom drag) was over-dissipating long-period swell over the propagation fetch — found during the 2026-08-01 swell-loss regression investigation. Level-specific:

**Table below is the pre-Phase-E, three-level physics assignment; superseded by ADR-093 Amendment 3 (plan task E7, 2026-07-27) — DIFFRACTION and its NUMERIC under-relaxation now belong to L4 (structure grid), not L3. Current assignment. The "L1" column is a dead row as of 2026-08-23 — SWAN's own L1 compute (and its physics settings) no longer runs; the deep-water leg is WW3, which does not read this table (kept for the historical record of what SWAN's L1 emitted before removal):**

| Command | L1 (1 km, REMOVED 2026-08-23) | L2 (100 m) | L3 (40 m, need-driven) | L4 (10 m, structure grid) |
|---|---|---|---|---|
| SETUP | Removed (unsupported in OpenMP parallel runs; nest BC structurally wrong) | Removed | Removed | Removed |
| DIFFRACTION | Removed (sub-grid at 1 km) | Removed (sub-grid at 100 m) | Removed (sub-grid even at 40 m) | `DIFFRACTION 1 0.2 <smnum>` (smoothed; `smnum = round((90/dx)**2/3)` = 27 at dx=10 m, target εx≈45m) |
| NUMERIC alfa | — | — | — | Stationary only: `NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=<N> alfa=0.01` (travels with DIFFRACTION, E7). `mxitst` = 500 on L1 (WC-D1 follow-up) and **150 on L2/L3/L4** (2026-08-27: after the first WW3 grid rebuild + cold start, L3's first stationary step reached only 95.5–96.4 % at the SWAN default of 50 while every later step converged; solver iteration ceiling only — the 99.5 % gate and all tolerances unchanged). |

The SETUP physical effect (~10–15 cm near shore) is delivered via the WLEVEL input grid. Stage 2 (current): tide + analytic radiation-stress-balance setup estimate (`services/wave_setup.py`). The setup profile is computed from the previous run's cached Hs using Green's law shoaling to find breaking, then Longuet-Higgins & Stewart (1964) radiation-stress integration (K ≈ 0.167 for γ=0.73). First run (no previous cache), or genuinely flat offshore conditions (Hs < 0.1m), falls back to tide-only WLEVEL — both are a real computed value, not a caught failure. A genuine computation failure inside the setup pipeline instead aborts the SWAN run as of C-77 (2026-07-26, rules/coding.md §1) rather than silently substituting tide-only WLEVEL for every spot.

**Convergence gate (SWAN-L3-STABILITY-PLAN Phase 4):**

After every SWAN run, `_check_convergence()` performs three health checks:
1. PRINT scan: any `******` in accuracy lines → FAIL.
2. NaN scan: any NaN in the run's hotstart or TABLE output → FAIL.
3. Valid-point fraction: wet transect points with non-exception values below 80% → FAIL.

Behavior controlled by `convergence_retry` config key (default `false`):
- `false` (testing/default): ERROR log with metrics, no retry, failed workdir preserved untouched, no hotstart saved, API serves last-good run.
- `true` (future production): quarantine evidence to `/var/lib/weewx-clearskies/swan/failed/{cycle}_{level}/` (historical: `/var/run/weewx-clearskies/swan/failed/{cycle}_{level}/`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4), then degrade: smnum×2 → DIFFRACTION removed → abandon cycle. API serves last-good run with honest timestamp.

A diverged run NEVER saves a hotstart, NEVER overwrites the last-good cache, and NEVER fails silently.

**Grid geometry immutability (2026-07-23):** All grid bounding boxes (L1, L2, L3) and the L2 NESTOUT targeting area are computed together in `compute_domains()` at domain setup time — BEFORE any SWAN level runs. No code may resize, reposition, or override `cluster.grid` after `compute_domains()` returns. The NESTOUT NGRID written into Level 2's INPUT file must cover the entirety of every Level 3 grid it feeds. If any portion of an L3 grid boundary falls outside the NESTOUT area, those boundary segments receive zero wave energy and swell is blocked. This mismatch is invisible to SWAN convergence checks — the run "succeeds" with near-zero wave heights. Structure-aware sizing (smart sizing from pier shadow zones) must happen INSIDE `compute_domains()`, not as a post-hoc override at runtime.

**Why (2026-07-23):** A runtime `smart_size_l3_grid()` call in `swan_runner.py` resized the L3 grid AFTER Level 2 had already written its NESTOUT. The L3 grid extended 1,383m east and 666m north beyond the NESTOUT boundary. Only ~40% of the southern boundary received swell spectra. SWAN produced Hs=0.01m during a 6-8 ft south swell (Beach Hazards Statement active). The fix: pass structures to `compute_domains()` so L3 grids include structure shadow zones at domain computation time. The runtime override was deleted.

**Wind forcing is mandatory in every SWAN INPUT file (2026-07-23):** GEN3 WESTHUYSEN activates wind generation physics including quadruplet wave-wave interactions. SWAN refuses to run quadruplets with zero-wind conditions (exit code 2: "not recommended to use quadruplets in combination with zero wind conditions"). Every SWAN INPUT file that runs GEN3 must include an INPGRID WIND + READINP WIND section with actual wind data (this note originally named the SurfBeat strip too; SurfBeat was removed from the system 2026-08-23). The SurfBeat strip uses a uniform wind field from HRRR interpolated to the spot coordinates at the forecast timestep.

**Why (2026-07-23):** The SurfBeat strip INPUT had GEN3 WESTHUYSEN but no wind input. SWAN exited with code 2 on every invocation. The API fell back to a local SWAN binary that didn't exist (disabled during audit), then the request timed out from repeated failures across all cadence hours.

**Per-level physics (WC-D1, 2026-08-07).** Level 1 runs GEN3 ST6 (Rogers et al. 2012) with SSWELL ZIEGER 0.00025 and NEGATINP 0.04 — observation-consistent wind input that actively removes boundary wind chop via negative wind-input dissipation. Levels 2, 3, and 4 run GEN3 WESTHUYSEN (unchanged). SurfBeat strips continue running GEN3 WESTHUYSEN regardless of level. BREAKING CONSTANT 1.0 0.73, FRICTION JON 0.038, and TRIAD are shared by all physics configurations. Parameters from the SWAN manual §4.5.4 first recommended calibration; compute cost: ~3-4% total increase (ST6 on L1's 1,065 cells = 5.8% of total grid cells). Nesting is physics-agnostic: BOUNDNEST1 passes a spectrum, not source terms.

**Compute service data locality (2026-07-23):** The compute service on librewxr loads CUDEM bathymetric profiles from its own local filesystem at `/etc/weewx-clearskies/spot_profiles/`. The API on weewx does NOT replicate or pre-populate these profiles — it sends the `spot_id` in the SwellTrack request, and the compute service loads the profile by spot_id from its local cache. Data that exists on the compute host stays on the compute host.

**Why (2026-07-23):** The CUDEM profiles are downloaded by the SWAN setup phase on librewxr. They do not exist on weewx (where the API runs). The original code tried to load profiles on weewx and stuff them into transect objects before serializing over HTTP — the directory didn't exist, all profiles were empty, SwellTrack degraded every transect to zero.

**Hotstart isolation:**

Stationary quick updates do NOT save hotstart files. The nonstationary chain's persistent hotstarts (`level3_{idx}_hotstart.dat`) are only written by full nonstationary runs. This prevents a diverged stationary snapshot from infecting the next full run's warm-start.

**OBSTACLE emission from bearing/length/distance:**

When a structure config has `bearing_degrees`, `length_m`, and `distance_m` but no explicit `coordinates` field, the runner computes endpoint coordinates (geodesic projection from the spot pin) and emits the OBSTACLE line. Every structure is logged at INFO as emitted or WARNING as skipped — never silent.

**Quick update WLEVEL:**

The stationary quick update now includes a WLEVEL input (current tide at compute time). Previously, quick updates ran with no tidal water level correction — up to ±1m depth error.

**Hotstart:** Each nonstationary SWAN run writes a hotstart file (`HOTFILE` command, placed immediately after `COMPUTE`) capturing the full spectral state at the end of computation. The next full run reads it via `INIT HOTSTART`, starting from the previous run's wave field instead of the default near-zero JONSWAP spectrum. Hotstart files persist at `/var/lib/weewx-clearskies/swan/level1_hotstart.dat`, `level2_hotstart.dat`, and `level3_{idx}_hotstart.dat` across subdir cleanup between runs (historical: `/var/run/weewx-clearskies/swan/`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4). If no hotstart exists (first run ever), SWAN initializes from the default wind-derived spectrum — a one-time cold start. Stationary quick updates do not write hotstart files; see the hotstart isolation subsection above.

**SWAN error detection:** `_spawn_swan()` checks both exit code AND stderr/Errfile content. SWAN (Fortran) can exit 0 despite writing "Severe error" to its Errfile. When severe errors are detected, `SWANRunError` is raised so the failure is visible and the run_marker is not stored.

**Cache:** Key = `(provider_id, spot_domain_id, hrrr_cycle_time)`. TTL = 21600s (6 hours) — matches the extended HRRR cycle interval (4×/day at 00/06/12/18Z). On SWAN run failure: log ERROR, retain last-good cache indefinitely. Do NOT invalidate cache on failure — stale SWAN data is always preferred to no data. **Run marker:** stored only when `spots_cached > 0` — prevents a failed SWAN run (exit 0 but no valid output) from blocking future attempts for the same HRRR cycle.

**Cache payload shape** (per-spot, stored at `last_good_key`):

| Key | Type | Description |
|---|---|---|
| `forecast` | `list[dict]` | Serialised `MarineForecastPoint` objects — one entry per transect point per timestep (all timesteps, all transect positions). Grouped by time in `surf.py`. |
| `spectral` | `list[dict]` | Per-timestep SPECOUT spectra. Each entry: `{time, freqs_hz, dirs_deg, energy, components}` — `components` is SWAN's own watershed partitioning from the companion TABLE's PT* columns (T4B.2), not a decomposition of `energy`; empty when PT* data was unavailable for that point/timestep. |
| `transect` | `dict[str, list[dict]]` | Full cross-shore transect per timestep, keyed by ISO-8601 time string (T3.4). Each list entry: `{distanceFromShore, depth, waveHeight, swellHeight, breakingFraction, breakingDissipation}` for one transect point. Used by the beach profile endpoint (T5.1). |
| `swelltrack` | `dict[str, dict]` | Precomputed 1D (SwellTrack) pipeline result per forecast timestep, keyed by ISO-8601 time string (T4B). See "Precomputed SwellTrack cache" below. |
| `wind_for_display` | `dict[str, dict]` | Per-timestep wind at the spot pin (not the coastline anchor), keyed by ISO-8601 time string. Each value: `{"windSpeed": float, "windDirection": float}` or `null`. Added H5 2026-08-02. **Q3 ruling (2026-08-11) — PERMANENT hybrid, supersedes the Z3.2 "TRANSITION fallback" framing:** the surf endpoint's display wind reads `services/wind_timeline_store.py`'s `get_present_hours()` (a tolerant sibling of `get_wind_series()` that never refuses on a gap) PRIMARILY, per hour, at request time; this field is the PERMANENT fallback for every hour the store does not cover — aged-out past hours, 3-hourly far-window off-slot hours, or a store-absent/cold read. It is **NOT deleted** in migration step 5: production evidence (16/16 requests falling back post-restart, `docs/planning/MARINE-PAGE-FIXIT-PLAN-2026-08-10.md` Z3.5 STATUS) showed the store's self-bounding design (age-out at wall-clock now + native 3-hourly far window) means it can never cover the served timeline's full range by construction, so this fallback is a structural, permanent need, not a transition artifact. |
| `spectral_dwr` | `list[dict]` | Per-timestep deep-water-reference SPECOUT spectra (L2 at ~15m, SURF-23). Same shape as `spectral`. |
| `swelltrack_tide_predictions` | `list[dict]` | Tide predictions used by the SwellTrack pipeline this cycle. |
| `run_time` | `str` | ISO-8601 UTC timestamp when the SWAN run completed. |
| `hrrr_cycle_time` | `str` | HRRR cycle time that forced this SWAN run. |

`fetch()` (`swan.py` `:1631-1725`) returns 8 of these 9 stored keys — it never reads `hrrr_cycle_time` back out — plus `data_age_seconds`, computed live from `run_time` (not a stored key). Nothing consumes `hrrr_cycle_time` via the `fetch()` path; the key is written to the cache payload but has no reader here. **`wind_for_display`** SURVIVES migration step 5 (Q3 ruling, 2026-08-11 — see the table row above): the original design scoped it for deletion once the store became display wind's exclusive source; production evidence showed the store cannot cover the served timeline by construction, so only this one deletion was reversed — the rest of migration step 5's deletions (below) proceed unchanged. This key list is a whitelist, not a passthrough of whatever the caller stored — a key added to the stored payload that is not also added here is silently dropped on read. `_remote_health_loop()` (see "Optional separated service" below) has the identical whitelist for the separated-service sync path; both must be kept in sync with each other and with whatever keys `_run_all_spots_locked()` actually writes.

**A second consumer of `spectral_dwr` (RW-1, register ruling 13, 2026-08-06):** `services/model_wave_source.py` reads `fetch(spot_id)["spectral_dwr"]` — the same read-only, no-trigger call `endpoints/surf.py` already makes for `multiSwell` — and reshapes each timestep's `components` list into a `MarineForecastPoint`, so `endpoints/marine.py`'s 3 card call sites can source a surf-spot location's wave fields from the model instead of WaveWatch III (§14.3). `waveHeight`/`wavePeriod`/`waveDirection` combine all of a timestep's partitions (`services/swan_runner.py`'s `_bulk_params_from_components()`, reused, not reimplemented); `swellHeight`/`swell2Height`/`swell3Height` take the largest non-wind-sea partitions in order; `windWaveHeight` takes the single partition with `is_wind_sea=True`. A spot with no cached `spectral_dwr` entries yet (cold start — `fetch()` itself returns `None`) yields `None` from this reader; the caller never substitutes WaveWatch III for a surf-spot location.

**A second, independent allowlist lives in the separated `weewx-clearskies-swan-swelltrack` package itself** (`weewx_clearskies_swan/service.py`'s `_FORECAST_CACHE_DEFAULTS`/`_copy_cache_entry()`), governing what that service's own HTTP-serving `_forecast_cache` accepts from its runner's cache payload before this API-side `fetch()` ever sees it. This is a distinct list from the one in the paragraph above, on the other side of the `GET /surf/{spot_id}/forecast` HTTP boundary, in a different repo — keeping it in sync with the six keys above is a separate, ongoing responsibility, not automatic. It regressed silently: `swelltrack` was added to the runner's payload (this section, above) but never added to the SWAN service's own copy allowlist, so it reached disk and Redis on the model host and never reached the API — measured live 2026-07-25 as `swelltrack present: False` on the published payload. Fixed by making that allowlist explicit and logging a WARNING when the runner's payload contains a key it doesn't recognize (SURF-PUBLISH-RESULTS-ONLY, 2026-07-25).

**Precomputed SwellTrack cache (T4B, caching change).** Before this change, the 1D (SwellTrack) pipeline ran once per forecast timestep **per request** inside `endpoints/surf.py`'s per-timestep loop — ~67-72 `run_pipeline()`/`remote_swelltrack()` calls for every `GET /surf/{location_id}` request, with no caller-side caching. Evidenced 2026-07-25: ~1,260 `run_pipeline` calls logged by the compute service in 70 minutes (~18/min sustained) while a SWAN L2 run was executing on the same host.

The pipeline now runs once per forecast timestep **per SWAN cycle**, at the end of a successful full run in `_run_all_spots_locked()` (`_precompute_swelltrack_for_spot()`), and the result is cached under `payload["swelltrack"][valid_time]`. `endpoints/surf.py`'s per-timestep loop checks this cache first and only falls back to the on-demand call (unchanged, still fully functional) on a miss or a malformed entry. Both the precompute call and the on-demand fallback call the same reference-point-selection, handoff-selection, and pipeline-invocation functions in `services/surf_pipeline_timestep.py` — a cached result cannot silently diverge from what the on-demand path would have computed for that timestep, because it is not a second implementation.

The cached entry is encoded with a **trimmed** codec (`services/swelltrack_cache.py`) that drops `TransectResult`'s three heavy per-transect arrays (`hs_total_profile`, `distances`, `depths`). Measured (30 transects, ~594 bathymetric profile points each): a full per-timestep `PipelineResult` serializes to 558 KB — ~39 MB/spot/cycle, ~196 MB across 5 spots, an unreasonable amount of data to write to disk every ~6 hours and ship over the separated-service HTTP sync (30 s timeout). The trimmed shape serializes to 5.2 KB/timestep — ~0.37 MB/spot/cycle, ~1.84 MB for 5 spots. `endpoints/surf.py` never reads those three arrays (only checks `per_transect` truthiness); `endpoints/beach_profile.py` is the only consumer that needs them, and only for one timestep per request (closest to now), not the full forecast — it was never part of the reported problem (1 pipeline call per profile-page request, not 67-72) and **deliberately does not read this cache**; it stays on its existing on-demand `run_pipeline()`/`remote_swelltrack()` call. Do not wire `beach_profile.py` up to this cache without first re-measuring a full-fidelity cache entry's size and re-approving the growth.

`run_quick_update()` does not write a `swelltrack` entry — it fetches the existing cached payload dict and mutates only `forecast`/`run_time` in place (`last_good["forecast"] = existing_forecast`), so whatever `swelltrack` data the last full run wrote is preserved untouched (slightly stale for the one timestep the quick update refreshed, same staleness the quick update already accepts for `spectral`/`transect`).

**On-disk forecast cache persistence (SWAN-L3-STABILITY-PLAN Phase 8):** The in-memory cache is also persisted to `/var/lib/weewx-clearskies/swan/forecast_cache.json` (historical: `/var/run/weewx-clearskies/swan/forecast_cache.json`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4) after every successful full run and quick update (atomic write via temp+rename). On API startup, `fetch()` loads the on-disk cache if it exists and is less than 12 hours old. This ensures API restarts do not lose surf forecast data — the dashboard immediately serves the last-good forecast without waiting for a new SWAN run.

**Two-tier schedule:**

**Table below (grid column, "L3 only") predates ADR-093 Amendment 3 (plan task E8, operator-approved 2026-07-27) — the quick-update path was rebuilt as the "hourly fill" and now runs every grid a cluster has, not L3 alone — and predates C3 (operator-approved trigger-6 cadence change, 2026-08-03), which changed the hourly fill's Mode/Forecast span from a single stationary snapshot to a stationary sequence. Current shape:**

| Tier | Trigger | Grids | Mode | Forecast span | Runtime | Interval |
|---|---|---|---|---|---|---|
| Full run | `wind_gatherer`'s `extended_cycle_assembled` event, or a geometry-changing config push (`force_full_run_signal`) — both converge on `providers.nearshore.swan.run_full_swan_cycle_from_store()` (Z3 migration step 3, WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03 §5); ≤300s (`check_interval_s`) latency from assembly/push to run, same bound the forced path already accepted pre-step-3 | L1 + L2 (+ L3 + L4 where triggered) | Nonstationary (72h time-stepping) | 72 hours | ~7–12 min | ~4×/day (00/06/12/18Z, one per HRRR extended cycle) |
| Hourly fast cycle | `wind_gatherer`'s `hourly_cycle_assembled` event — converges on `providers.nearshore.swan.run_quick_update_from_store()` (Z3 migration step 4, WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03 §5); ≤300s (`check_interval_s`) latency from assembly to run; no forced-bypass analog exists (fires ONLY on assembled-complete, operator Q3 ruling) | Full nest — L1 + L2 (+ L3 + L4 where triggered), same as a full run | Stationary sequence (12 stationary snapshots, hours 0-11, `stationary_sequence=True`, one `COMPUTE STAT` per forecast hour, HRRR wind read from the assembled store, trimmed to its first 12 hourly grids) | 12 hourly timesteps (hours 0-11) | not yet re-measured post-Z3.4 (finding 13: the pre-Z3.4 trigger was unreachable in production, so no live measurement exists yet) | Every hour (per `hourly_cycle_assembled` event) |

**Full runs** produce the 72-hour forecast. All active grid levels must complete within 15 minutes total. Peak memory: ≤400 MB (all grids run sequentially, not simultaneously).

**Full-run wind input (Z3 migration step 3).** `run_full_swan_cycle_from_store()` reads `services/wind_timeline_store.py`'s `get_wind_records()` over the run's own 0–72h window — native HRRR-hourly 0–48h, native GFS-3-hourly 48–72h (a regime-aware sibling of `get_wind_series()`, which enforces a single uniform-hourly contract the far window's native cadence cannot satisfy) — instead of `run_all_spots()`'s own inline HRRR/GFS fetch. `SWANRunner._stitch_wind()` interpolates the far window to uniform hourly exactly as before (unchanged; only the raw-hour source moved). A gap in either regime refuses the run (`state.record_no_publish("wind_series_gap", ...)`, named reason, no last-good cache overwritten) rather than publishing a shortened or time-shifted field. The SWAN input writer (`services/swan_formats.hrrr_to_swan_wind()`) also gained a hard validation of its own: a non-uniform-hourly blended series raises `WindCadenceError` (caught in `providers/nearshore/swan.py` as `no-publish: wind_cadence_non_uniform`) — closes the mid-forecast-hole time-shift defect class (`docs/planning/briefs/V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md` §3b) structurally, independent of the store switch.

**Far-window wind-grid geometry homogenization (Z3.7, gate-A second failure, option 2, operator ruling 2026-08-12).** The store keeps ONE record per hour; whichever source's fetch won the boundary hour's (cycle+48h) freshness race is what BOTH regimes see there (`services/wind_timeline_store.py`'s `get_wind_records()` docstring, corrected same round — it no longer claims GFS's own f048 is guaranteed present). In production HRRR usually wins that hour, and HRRR's grid geometry (native ~3km, e.g. nj=65×ni=60) differs from GFS's (native 0.25°, nj=6×ni=7) — `SWANRunner._stitch_wind()` interpolates far-window grid pairs elementwise using the FIRST grid's `nj`/`ni`, so an unhomogenized geometry mismatch there is an `IndexError`, not a degraded result (the live gate-A crash: `swan_runner.py:2894`, every cycle). `run_full_swan_cycle_from_store()` now homogenizes the far window at store-read time, BEFORE `_stitch_wind()` (which stays frozen — same equation, same location): it picks the first GFS-sourced far-window record as the target geometry, and resamples every far-window grid whose own six-tuple geometry (`lat_first`/`lon_first`/`lat_last`/`lon_last`/`ni`/`nj`) doesn't match it, via the new `_resample_grid_to_geometry()` helper (module-level in `providers/nearshore/swan.py`, reusing `swan_formats._bilinear_interp()` — no new interpolation routine). In production this means the HRRR-sourced boundary-hour record is resampled onto the GFS grid and anchors the h49–50 interpolation — this changes those two hours' interpolation inputs from the pre-Z3.7 assumption of GFS's own f048 to an HRRR-derived value (approved; not "restored" to legacy). Clamp policy: each target grid point's lat/lon is clamped into the source grid's own bounding box before sampling — nearest-edge extrapolation, not NaN-propagation and not a refusal — for the production GFS-box overhang past the HRRR box (≤0.061°, ~5.6 km, which exceeds `_bilinear_interp()`'s own one-grid-cell edge tolerance); the resampled grid is interpolation scaffolding for the h49–50 anchor only, never a forced/emitted hour in its own right. A far window with no GFS-sourced record at all (no target geometry to homogenize onto), or a resample failure (degenerate 1-row/1-column grid — refused, never guessed, per rules/coding.md §1), both refuse the run the same way a store gap does — named no-publish reasons `far_window_no_gfs_records` / `far_window_resample_failed`, last-good cache preserved, `inputs.wind` recorded unavailable.

**The OLD inline-fetch full-run trigger inside `_marine_runner_loop()` (service.py) is DELETED (Z3.5, 2026-08-11, migration step 5)** — the wind gatherer's `extended_cycle_assembled` event (or the forced-geometry-push path) is now the loop's ONLY trigger for the full run; `run_all_spots()`'s own inline HRRR/GFS fetch fallback stays live for the manual trigger and tests (untouched).

**Hourly fast-cycle wind input (Z3 migration step 4, finding 13 fix).** `run_quick_update_from_store()` reads the SAME assembled store, over a window anchored to the triggering `hourly_cycle_assembled` event's own cycle_time (its top-of-hour timestamp, NOT wall-clock `datetime.now(UTC)` — so the requested hourly slots always align to the store's own hourly grid). A `WindSeriesGapError` refuses the fast cycle the same way a gap refuses the full run (`wind_series_gap`, named reason, no last-good cache overwritten). Before this step, the hourly fill's trigger was unreachable in production (V3-F1-WIND-HOLE-INVESTIGATION-2026-08-03.md finding 13): `_marine_runner_loop()`'s own inline HRRR fetch always requested 48h, which always snapped to an extended cycle, so the fill's `else:` branch never ran live. **The OLD inline-fetch stationary-fill trigger inside `_marine_runner_loop()` is DELETED (Z3.5, 2026-08-11, migration step 5)** — the wind gatherer's `hourly_cycle_assembled` event is now the loop's ONLY trigger for the fast cycle; `run_quick_update()`'s own inline-fetch fallback stays live for the manual trigger and tests (untouched).

**Migration step 5 (Z3.5, 2026-08-11) deletions, complete.** `_marine_runner_loop()`'s entire inline HRRR/GFS fetch + `_is_extended_hrrr_cycle()` cadence classification + `last_hrrr_cycle` change-detection bookkeeping is removed outright — both trigger paths above are event-driven ONLY now. `GET /health`'s `inputs.wind` freshness signal (previously recorded by that inline fetch) is recorded by `run_full_swan_cycle_from_store()`/`run_quick_update_from_store()` themselves now, right after their own store read — the same signal, re-sourced to the path that actually supplies production wind. The wind gatherer (`services/wind_gatherer.py`) is the sole ROUTINE NOMADS caller for wind as of this step, and its own rate limiter is restored to the full 2 req/s policy (the coexistence-window halving it ran at while the run path's inline fetch was still a concurrent caller no longer applies).

**The hourly fast cycle runs the full nest stationary** (`SWANRunner.run_stationary_full_nest()`, `services/swan_runner.py`) as a 12-snapshot stationary sequence (hours 0-11, `stationary_sequence=True` — Z3.4/WIND-PROVIDER-ARCHITECTURE-DESIGN-2026-08-03 §5 step 4, operator ruling verbatim "half a day", supersedes C3's original 24-snapshot/hours-0-23 sequence) — L1 through whichever of L2/L3/L4 this cluster has, not L3 alone, not a single snapshot. L1 reuses the last full run's WW3 boundary files already on disk rather than re-fetching (deep-water swell changes slowly). The fast cycle also runs the 1D SwellTrack chain for every one of its 12 snapshots and merges every returned forecast point into the existing forecast cache: collision-aware since the 2026-08-03 remediation — the nearest-index mapping for all 12 snapshots is computed first, and any cache index ≥2 snapshots map to (a non-fully-populated-hourly cache) is resolved deterministically (closest-in-time-to-slot wins, tie → earlier snapshot) rather than silently overwritten; a WARNING is logged naming the dropped count when this occurs. So it refreshes the actual surf card at every spot — including open-beach (L2-only) spots — not just SWAN grid points. Hours 12-72 remain untouched until the next 6-hourly full run. Per SWAN user manual §4.7: "For small domains (< 100 km), a stationary computation is recommended." Warm-starts from, but never saves, the full run's hotstart chain (T4.2 isolation).

**Working directory:** SWAN runs in `/var/lib/weewx-clearskies/swan/` (fixed path, not tempfile; historical: `/var/run/weewx-clearskies/swan/`, RAM-backed tmpfs, corrected 2026-08-08 Phase R4 — cgroup memory accounting was charging the tmpfs pages to the service, measured 5.1G memory peak against a 6G container cap). **CORRECTED 2026-08-27 (D1 as-built re-sync — this paragraph predated the SWAN L1 removal/CHAIN-SERVES round and described a SWAN L1 subprocess that no longer exists; see the "SWAN runner" caveat above):** subdirectories `level2/` and `level3_{idx}/` (one per cluster) are cleaned at the start of each run and hold live SWAN nesting output; the `level1/` subdirectory is NOT a running SWAN level's working directory any more — SWAN L1 is SKIPPED ENTIRELY (no `_write_input_files()` call, no SWAN subprocess, no convergence check, no hotstart save, no nest archive; `swan_runner.py`'s `run_3level()` docstring, `l1_nest_source` parameter). `level1/` on disk holds only the legacy BOUNDSPEC scaffold (`INPUT` + the 22 `B_*.txt` files) that `_reused_l1_boundary_command_lines()` still reads every production cycle (`vchain.py`'s `_stage_l2_boundary()`) — a live dependency, not dead, but a scaffold read, not a running level. There is no `level1_hotstart.dat` (nothing to warm-start — L1 never runs); `level2_hotstart.dat`/`level3_{idx}_hotstart.dat` persist between runs as before. Nesting file flow: L2's BOUNDNEST1 input for L3 is copied from `level2/nest_out.dat` to `level3_{idx}/nest_in.dat` as before — L2's own boundary comes from WW3 via **BOUNDNEST3** (§14.18), not from a `level1/nest_out.dat` file. The fixed path is visible from SSH (unlike `tempfile.mkdtemp` which was hidden by systemd's `PrivateTmp=yes`) and survives service restarts.

**2-D bathymetry grid:** **(T4A.3, 2026-07-25; moved into the marine service by MARINE-SEP-CONCERNS.md C-41, DECIDED, same day) Downloaded and sized on marine config receipt (`POST /config`), not lazily on first SWAN run, and not by the API.** `weewx-clearskies-marine`'s `services/grid_sizing_chain.py` `run_grid_sizing_chain()` (a `BackgroundTasks` job scheduled from `endpoints/config.py`'s `POST /config` handler whenever the pushed config declares at least one surf spot) resolves the bathymetry resolver priority chain (§14.7: operator file → NCEI regional OPeNDAP → Great Lakes → CRM fallback) for each grid level and writes the per-level caches at `/etc/weewx-clearskies/swan_bathymetry_L{1,2,3}.json` (180-day TTL) via `download_bathymetry_for_level()`. Previously this ran inside the API's `endpoints/setup.py` `_run_marine_apply_chain()` at `POST /setup/apply` time — a holdover from when SWAN ran inside the API process, not a statement of whose job grid sizing is (operator ruling 2026-07-25). **At SWAN runtime, the same function is called with `allow_download=False`** — a missing cache is an ERROR (that level falls back to uniform 15m depth for the cycle) and a stale cache is used anyway with a WARNING; there is no runtime download path. `cudem_to_swan_bottom()` bilinear-interpolates the source grid onto SWAN grid dimensions. Sign convention: CUDEM (negative = ocean) → SWAN (positive = ocean). Vertical datum consistency enforced by matching CO-OPS tide prediction datum to the bathymetry DEM's native datum. No local datum conversion for the common case (ADR-098).

**Per-spot profile and grid-sizing caches** (T4A.3, producer moved by C-41): `run_grid_sizing_chain()` also writes `/etc/weewx-clearskies/spot_profiles/{spot_id}.json` (PCHIP variable-resolution profile — API-MANUAL §17 — plus `structure_zone_depth`, `fine_zone_max_depth`, both contour distances, and the source grid's actual `vertical_datum`) and `/etc/weewx-clearskies/swan_grid_sizing.json` (the computed L1/L2/L3 `DomainSizing`, serialized via `services/swan_domain.domain_sizing_to_dict()`). Both path constants are defined once, in `providers/nearshore/swan.py`, and imported by `grid_sizing_chain.py` — producer and consumer are the same repo now, so the pre-C-41 duplicate-constant arrangement (one copy per repo, kept in sync by convention) is gone; there is exactly one definition. The SWAN runtime loads both via `load_grid_sizing_cache()` and the per-spot profile read — it never calls `compute_domains()`/`compute_level3_domains()` itself. `download_bidirectional_profile()` (§14.7) has no remaining production caller as of this change; the coordinator is verifying and routing its disposition separately.

**Optional separated service:** When `[swan] service_url` is set to a remote host, `SwanProvider.fetch()` calls the remote HTTP endpoint instead of running SWAN locally. Health check polls `GET {service_url}/health` every 60 seconds, unchanged. Three consecutive failures → log ERROR, serve last-good cache.

**Published forecast is a trimmed view; forecast fetch is now conditional (SURF-PUBLISH-RESULTS-ONLY, 2026-07-25).** `GET {service_url}/surf/{spot_id}/forecast` drops four heavy per-timestep `spectral` fields (`energy`, `freqs_hz`, `dirs_deg`, `handoff_by_transect`) at the model host's HTTP-serving boundary — the model host's own `_forecast_cache` and on-disk `forecast_cache.json` keep the full data (needed to answer `GET /surf/{spot_id}/profile` below, including after a restart). `_remote_health_loop()` still polls `GET {service_url}/health` every 60 seconds as above, but now only downloads the (trimmed) forecast when the health response's `last_run` differs from the `run_time` already in this host's local last-good cache — a missing cache entry always fetches (the last-good cache has a 7-day TTL and can expire). Measured 2026-07-25: ~21 MB wire payload per fetch, previously every 60 s; now ~2.4 MB roughly once per ~25-minute model cycle.

**Two additional endpoints on the same separated service (SURF-PUBLISH-RESULTS-ONLY §3.2/§3.3):**

- `GET {service_url}/surf/{spot_id}/profile?time=<ISO8601>` — Bearer auth (same secret as `/forecast`). Exact-match lookup of `time` against the model host's full internal spectral data (never the trimmed view), runs the 1D pipeline for that one timestep on the model host, and returns the result in SI units using the identical wire format `POST /compute/swelltrack` already produces (`compute_client.deserialize_pipeline_result`, exposed as a public alias for this reuse). HTTP 503 with a structured `{"error": "no_answer", "reason": ..., "spot_id": ..., "time": ...}` body when the timestep is absent or the pipeline yields nothing (`reason` ∈ `no_forecast_data`, `spot_not_configured`, `timestep_not_found`, `pipeline_unavailable`). Called by `endpoints/beach_profile.py` in remote mode instead of recomputing on the weewx host — see API-MANUAL §18.
- `POST {service_url}/report/gap` — Bearer auth. Body `{spot_id, valid_time, endpoint, run_time}`. Returns 204. Logs one WARNING per distinct `(spot_id, valid_time, endpoint, run_time)` combination on the model host, deduplicated with a bounded in-memory structure (2,000 entries) so a dashboard refresh loop cannot flood the log or grow the process without limit. Called (fire-and-forget, via a single bounded-queue background worker, never inline in the request path) by `endpoints/surf.py` and `endpoints/beach_profile.py` when a timestep's `swelltrack` entry is missing/malformed in remote mode.

**No recomputation on the API host in remote mode — topology-gated, bundled mode unaffected.** When `[swan] service_url` is set, `endpoints/surf.py` and `endpoints/beach_profile.py` (`is_remote_mode()` returns true) no longer run the 1D SwellTrack pipeline or round-trip spectra to the compute service on the weewx host: a missing/malformed timestep becomes `modelStatus: "unavailable"` (surf) or a 200/null response (beach profile), reported via `POST /report/gap`, never recomputed locally. **When `[swan] service_url` is unset (bundled single-host mode, no separate model host), this rule does not apply** — the existing in-process 1D pipeline / optional `surf_compute_host` offload cascade is the model in that topology and is unchanged by this brief.

See ARCHITECTURE.md for the standalone `weewx-clearskies-swan-swelltrack` package (ADR-096 renamed, ADR-099 re-renamed) and its full remote-mode data-flow callout.

#### §14.15 Amendment: Multi-transect + SwellTrack architecture (2026-07-21)

Per SURF-1D-IMPLEMENTATION-PLAN and SURF-ZONE-MODEL-BRIEF:

**L3 optional per location.** L3 is enabled automatically when Overpass API structure discovery finds structures near the spot. No structures → L3 skipped, SPECOUT extracted from L2 at ~15m depth. Operator can override in admin (force L3 on/off per location). When L3 is skipped for a spot, that spot's cluster index is excluded from the `level3_{idx}` loop — the WW3 leg and L2 run unchanged for all spots.

**L3 smart sizing around structures.** When L3 is enabled, the L3 bbox is computed from structure positions + shadow zone extent (structure length + 2× structure length downstream in predominant wave direction) + 100m pad. Not the entire beach segment. This means a single pier on a 1km beach produces a ~500m L3 grid.

**L3 does not run to shore, and the handoff is not a fixed depth (decided 2026-07-25; margin still open).** See ADR-093 Amendment 2 for the full decision and its rejected alternatives.

Grid geometry is frozen at setup — that rule is unchanged. But *which cell the handoff spectrum is read from* is a sampling choice, not geometry, and it moves per forecast hour.

```
At setup:  size the L3 grid to reach as far shoreward as it is EVER useful —
           down to the shallowest depth any forecast hour's handoff could sit at.
           Small-swell days break shallow, so this is the SHALLOW end of the
           breaking range, not the deep end.

Per hour:  breaking depth this hour = Hs(hour) / gamma        # gamma = 0.73
           read the handoff spectrum just SEAWARD of that contour.
```

> **Do not freeze the handoff at `1.3 * max_hs_m / gamma`.** That is the breaking depth for the spot's *largest* swell. Holding it there all year hands SwellTrack a long leg SWAN could have carried on ordinary days, and shrinks L3 to a band too thin to reach the structures it exists for. At HB Pier the breaking zone moves between ~1.4 m depth (1 m swell) and ~5.5 m (4 m swell) across a year.

**Margin above breaking — decided: the 1.3 factor, applied per hour.**

```
handoff depth (this hour) = 1.3 * Hs(hour) / gamma
grid shoreward reach      = smallest value that expression ever produces here
```

SwellTrack needs enough room to see the `Hs/d = gamma` crossing inside its own domain rather than on its boundary, and to have an approach value seaward of the outer bar for the jacking factor. It does **not** need wavelengths of shoaling run-up — SWAN has already shoaled the wave, and SwellTrack traverses the nonlinear inner zone regardless of where it starts. A 30% margin on the hour's own breaking depth covers both with no new constant.

The 1.3 factor was never the defect. Feeding it `max_hs_m` and freezing the result was. Per hour at HB: 1 m swell → 1.8 m; 2 m → 3.6 m; 4 m → 7.1 m.

**How "the smallest value that expression ever produces" is evaluated (T4A.11, P4A Round 2 "Blocker 2", resolved 2026-07-25).** The expression needs a *minimum* Hs — the spot's smallest expected swell — and no config field supplies one. It is therefore a fixed **design constant**, `_MIN_DESIGN_HS_M = 1.0` in `services/swan_domain.py`, carrying the same status as gamma itself: not a per-spot value, not a config key. `l3_shoreward_edge_depth_m()` returns `1.3 × 1.0 / 0.73 ≈ **1.78 m**`, matching this ADR's own worked example above (1 m swell → 1.8 m) and Amendment 2 §5's conclusion that "a grid reaching ~2 m depth spans the pier end to end." The apply-time chain converts that depth to a distance by searching the MEDIUM bathymetry grid for the contour along each spot's own bearing — the same mechanism already used for the 15 m and 30 m offshore contours — and threads it through as `shoreward_distance_m`.

> **Feature geometry does NOT size the shoreward edge.** A structure cannot push L3's boundary past the depth where SWAN stops being reliable; `structure_zone_depth` can only ever deepen *SwellTrack's* fine zone into water L3 already covers, never move the handoff. Structure extent still sizes the **alongshore** shadow zone (ADR-093 Amendment 1 §2, unaffected). Feature reach is a **viability-test input, not a sizing input**: §2 sizes the grid, then §4 tests whether it reaches the feature and disables the cluster if not. Two earlier implementations reversed this — first sizing from feature coverage (3× structure length / ~100 m pin margin), then from `fine_zone_max_depth` with `max_hs_m` — and both were coordinator errors, not operator rulings. Neither survives; see `l3_shoreward_edge_depth_m()`'s docstring.

**L3 offshore edge stays at the 15 m contour.** Reopened briefly, then closed — the collapse-to-zero-thickness problem that motivated changing it only existed under the frozen 15 m handoff.

#### §14.15 Amendment: the handoff is per transect, not per spot (Phase 4B, approved 2026-07-25)

Everything above describes the handoff in the **singular** — "*the* handoff", "*which cell* the
spectrum is read from". That phrasing describes the pre-4B implementation and is being superseded.

**What it was.** One `CURVE` was emitted per *spot*, and the per-hour selection from it was
replicated across every transect (`endpoints/surf.py` built `handoff_by_transect` as a dict
comprehension assigning one value to all N keys). A transect inside a pier's shadow received the
same unshadowed spectrum as one 150 m up the beach. **The alongshore variation the 2D L3 grid
exists to compute was discarded at the boundary.**

**What it becomes.** Each 1D line reads the wave field at **its own coordinates**. Output points
are declared with `POINTS 'sname' FILE 'fname'` (arbitrary coordinates, degrees for spherical)
rather than a single `CURVE`, at the **L3 grid's own 10 m resolution** rather than the previous
hardcoded 50 m. The handoff then varies in two dimensions: **depth per hour, location per
transect.** Point output is interpolated from the computational grid (manual p. 90;
`SWOEXA`/`SWOEXD`), so this samples the field at the transect's position — it is not a regrid.

**Why 50 m had to go.** On HB's ~1:50 nearshore slope, 50 m of horizontal spacing is ~1.4 m of
depth, so the two shallowest stations were 0.98 m (the grid boundary, correctly excluded) and
2.37 m with nothing between. Measured 2026-07-25: **all 73 timesteps clamped**, landing at ~2.25×
breaking depth instead of the intended 1.3× — in 4–6 ft surf, not marginal conditions.

**Partitioning.** SWAN's own `PTHSIGN`/`PTRTP`/`PTDIR`/`PTDSPR` in `TABLE` supply per-partition
bulk parameters via the Hanson & Phillips (2001) watershed algorithm, which is energy-conserving.
`run_1d_analytical()` takes scalars, so this is what SwellTrack actually consumes. This replaces
a bespoke ±4-bin neighbourhood peak-finder (`decompose_spectrum()`, `services/swan_spectral.py`)
that measurement against 67 real spectra showed reported one swell system two to five times
rather than distinct systems (energy closure up to 227% of available energy); that function
remains in the codebase, unchanged, only for `scripts/compare_partitioning.py`'s direct
measurement of the two algorithms — it has no production caller (T4B.2, operator-approved
2026-07-25, deployed to librewxr in `12f9ddc`).

This TABLE PT* output is not limited to the L3 CURVE handoff: the L2 deep-water-reference
baseline (per spot) and every T4B.4 per-transect-cell point carry the same four columns, so spots
with no L3 grid also read SWAN's own partitions instead of a recomputed approximation. A (point,
timestep) with no PT* data available — the TABLE file missing entirely, or its rows not matching
that point's coordinates within tolerance — degrades to empty components plus a WARNING naming
the spot and timestep; nothing is recomputed to fill the gap. `frequencyRange` on a
SWAN-partition-sourced `SpectralWaveComponent` is always `[0.0, 0.0]`: TABLE's bulk PT* output
carries no per-partition frequency-bin bounds, so the field is not derivable on this path (see
API-MANUAL §17 `SpectralWaveComponent`).

Absence of a partition slot in real output is signalled by an exact `HsPT0k ≈ 0`, not the
documented `-9`/`-999` exception value (SWAN's own `HSPMIN = 0.05` m partition floor gives this a
wide, safe margin). See "Measured deviations of the deployed SWAN binary (41.51AB) from the
manual" below for column names, the measured absence signal, and the exception-value sentinel
(checked belt-and-braces, but never the sole signal relied on — real output has never emitted it).

**L3-disabled spots** get the same treatment against L2, bounded by L2's 100 m resolution: ~3
distinct cells across a 320 m spot. That is the honest ceiling and is better than one — but it is
also why higher-resolution bathymetry shoreward of 15 m is a standing limitation.

> **SurfBeat is deliberately excluded, and this is not an oversight** (and as of 2026-08-23 SurfBeat is removed from the system altogether — this note is historical). The IEM's biphase evolution
> equation is derived "under the assumption that the bottom slopes are mild and **alongshore
> uniform**" (SWAN manual p. 80). Per-transect IG strips would model alongshore variation with a
> module that assumes none. SurfBeat also runs stationary, on its own regular grid with a
> west-side offshore boundary and two COMPUTEs — it is not part of the L3 nonstationary run and
> does not share its output geometry. `surfbeat_runner.py` keeps its own 25 m station spacing.
> **Do not "fix" SurfBeat to match the L3 handoff. They look alike and are not.**

**L3 trigger — structures OR operator classification.** L3 turns on when Overpass API discovers a manmade structure **or** the operator has classified the spot as a point break, headland, or bay break. The old structure-only trigger meant a point break could never enable L3 — the case where 2D refraction matters most and where SwellTrack is least able to help. A point break is defined by alongshore geometry (the shoreline bends, contours fan) and a single cross-shore profile cannot detect it; the operator's classification supplies the answer without new analysis.

**Setup-time calculation scope.** IN: everything depth-based from the apply-time bathymetry — contour positions, local slope, breaking depths, horizontal span between offshore edge and handoff, grid extents and cell counts, profile relief. L3 sizing and the viability test are built on these. OUT: contour curvature, orientation variation along the segment, headland detection, automatic break-type classification.

**L3 viability test at setup.** The trigger is necessary, not sufficient. Size L3, then test it: if the grid cannot reach the feature it was created for, L3 is **disabled** for that cluster and the spot runs WW3 → L2 → SwellTrack from L2's ~15 m reference. **The test MUST log which feature was unreachable and by how much** — a grid reaching too far shoreward announces itself at runtime as breaking inside L3, but a grid stopping too far seaward is silently indistinguishable from "nothing here to model."

**HB Pier status is UNDETERMINED** pending a real run against HB's bathymetry. An earlier revision of this manual recorded HB as failing the test; that followed from the frozen-handoff error above and is void. A grid reaching ~2 m depth would span the pier end to end. The trigger and viability-test mechanism described above is implemented (T4A.11, P4A Round 2) — what remains is running the grid-sizing chain against HB's real data (`weewx-clearskies-marine`'s `services/grid_sizing_chain.py` `run_grid_sizing_chain()`, T4A.5; moved from the API's `endpoints/setup.py` `_run_marine_apply_chain()` by C-41) and reading the result, not a further decision.

**Where L3 earns its keep (sizing guidance, not pass/fail).** On steep feature-driven seabed — reef ledges, points, canyon rims — the band between clean water and breaking is a few hundred metres, so a 10 m grid across it is small and resolves 10–50 m features nothing coarser sees. On a gentle sand shelf that band is kilometres wide, the grid is enormous, and what it resolves is sandbars SwellTrack already handles from the depth profile.

**Supplement 4 topographic multipliers are REMOVED.** Point break ×1.1, headland ×1.2, bay break ×0.9, straight beach ×1.0 stood in for refraction the model now computes. They predate nesting — once L2 existed at 100 m it began computing that refraction itself, so they have been double-counting since. Removed outright, not made conditional. The operator's classification is retained as the L3 trigger.

**This depth is the SWAN→SwellTrack handoff surface.** L3's shoreward boundary and the handoff depth are one quantity, not two — no configuration can place the handoff outside the grid. It is also, by construction, the top of SwellTrack's fine-resolution zone (`fine_zone_max_depth`, API-MANUAL §17): SwellTrack's 1–2 m grid begins exactly where SWAN stops.

**Structure geometry never sets this boundary.** Structures determine whether L3 exists, and set its alongshore and offshore extent. They cannot push the shoreward edge past the breakdown depth — a pier that reaches the beach does not make SWAN accurate at the beach. Note that the handoff is a depth *contour* while a SWAN grid is a *rectangle*: the grid's shoreward edge must reach the landward-most excursion of that contour across the cluster.

**Multi-SPECOUT extraction.** Two distinct SPECOUT types per spot:

1. **Deep-water reference SPECOUT (L2):** One per spot at ~15m depth along the central transect bearing. SWAN POINTS + SPECOUT syntax. **Feeds the swell display card only via FALLBACK, since Q16 Round B (2026-08-25, S3 correction, MARINE-AND-MAPS-PLAN §S3):** the card's primary source is now a small fan of true deep-water (≥200 m) WW3 reference points (`services/model_wave_source.py`'s `get_deep_swell_catalog()`, `endpoints/surf.py`'s `swellSource: "deep_reference"`), derived once at grid-sizing time from the WW3 leg — never SWAN L2/L3/L4. This L2 ~15 m SPECOUT serves the card only for forecast hours the WW3 leg's currently-staged transfer file does not cover (`swellSource: "nearshore_table"`, today: hours beyond the leg's ~6h march window). It still unconditionally feeds `canonical_partitions`/cross-swell scoring (the pipeline's own consumers, distinct from the card), which this correction does not touch — SwellTrack's own boundary condition is the separate Handoff SPECOUT (item 2 below), unaffected. See API-MANUAL §17.

2. **Handoff SPECOUT (L3 or L2):** One per unique L3 grid cell at each transect's handoff depth. When L3 is enabled, extracted from L3 (includes structure effects). When L3 is disabled, same as the deep-water reference (L2 at 15m). Deduplicated: multiple transects sharing the same grid cell share one SPECOUT. Feeds SwellTrack as boundary condition.

Both SPECOUT types are paired with a companion `TABLE` carrying the PT* watershed columns at the same point (T4B.2). The swell partitions attached to each entry (`multiSwell`, and the partitions SwellTrack runs on) come from that companion TABLE, not from decomposing the SPECOUT energy matrix — SPECOUT's `freqs_hz`/`dirs_deg`/`energy` are retained on the same entry as reference data (e.g. for NDBC-comparable display), but partitioning itself is a separate read.

**The two extractions are carried on two separate channels and never overwrite each other** (marine `83f0205`). `swan_runner.py` holds `_spectral_dwr_results` (written once per run from the L2 deep-water-reference parse) alongside `_spectral_results` (the handoff slot, which the L3 write rebinds). `providers/nearshore/swan.py` caches and serves them as two keys: `"spectral_dwr"` (time + components only) and `"spectral"` (which additionally carries the SPECOUT `freqs_hz`/`dirs_deg`/`energy` arrays its consumer needs). Consumers: `spectral_dwr` → `multiSwell`, `swellHeight`, the cross-swell and swell-dominance scoring inputs, and `canonical_partitions` for both `endpoints/surf.py` and `endpoints/beach_profile.py`; `spectral` → SwellTrack's boundary condition (`ts_handoff_specout`). For an L3-disabled spot both channels hold the same L2 entries by design (ADR-095 Amendment 1 §2), so nothing is rebound. **A missing deep-water reference is never substituted with the handoff partitions** — `multiSwell` goes null, `canonical_partitions` goes `None`, and both the whole-list and per-timestep gaps log at WARNING.

**Deep-water reference placement — the spot's own measured 15 m contour, or nothing** (marine `bd8c928`; operator ruling 2026-07-27 authorising the move to the documented position, CLAUDE.md trigger 3). `_compute_15m_point()` has exactly two paths and no fallback:

1. **Walk the cached profile** — the first sample at `depth_m >= 15.0`.
2. **The profile's own `contour_15m_distance_m`** — written at config-receipt time by `find_depth_contour_distance()`, which walks the MEDIUM (L2) DEM offshore from the coastline anchor along the spot's own bearing in 50 m steps and back-interpolates the crossing. It raises rather than substituting when the contour is not reached (LC-10), so the field is a measured crossing or is absent. A cached profile can stop short of 15 m while this number exists, because the profile is cut to the narrower FINE (L3) DEM's extent while the contour search runs on MEDIUM.

When neither path yields a point the function logs at **ERROR** naming the spot and returns `None`; the L2 emit block then writes no `POINTS`/`SPECOUT`/`TABLE` for that spot or its per-transect cells, and the spot publishes `multiSwell: null` with a WARNING rather than a number computed at an unverified depth. The former behaviour — projecting a fixed 2.5 km offshore along `beach_facing_degrees` at whatever depth the bathymetry happened to have — is **removed**; the `fallback_km` parameter no longer exists. `DWR<n>` numbering comes from the same `enumerate()` the parse block uses, so a skipped spot shifts nothing else.

> **Profile distances are anchor-relative — a fact about the data, not a convention.** Every distance in a cached spot profile (`distance_m` per sample, `contour_15m_distance_m`, `contour_30m_distance_m`) is measured from the profile's **coastline anchor**, stored in the same JSON as `coastline_lat`/`coastline_lon`, and never from the spot pin. That is how `grid_sizing_chain.py` generates them: it resolves the anchor with `find_shoreline_from_grid()` (the depth-zero crossing shoreward of the pin) and passes `coast_lat`, `coast_lon` into both `extract_native_profile_from_grid()` and `find_depth_contour_distance()`. **Any consumer projecting one of these distances must project from the anchor, or subtract the pin's offshore offset from it first.** `_compute_15m_point()` did neither and placed the Huntington deep-water reference 209.6 m too far offshore — measured at 17.29 m depth instead of 15 m — on both of its paths (`_profile_origin_offset_m()`, marine `bd8c928`). A bare-list profile carries no anchor; the offset is then 0.0, which is the best available and is why that shape's behaviour is unchanged.
>
> **The operator-drawn shoreline segment is not the anchor either.** `TransectInfo.origin_lat`/`origin_lon` is a point on the segment the operator drew, which normally lies offshore of the true shoreline — 213.5 m at `huntington-city-beach-pier`, in ~4.3 m of water. `compute_spot_transect()` documents its `coastline_lat`/`coastline_lon` argument as "the actual shoreline … so the CURVE transect starts at the true coastline" and projects the profile-derived station distances from it, so passing the transect origin there placed every T4B.1 per-transect POINTS band station 213.5 m too far out: transect 0's band was sized for 3.03 m → 1.01 m of water and physically sat in 8.51 m → 7.17 m, with no station anywhere in the target range. `band_depths_m` is built from the *intended* profile-interpolated depths, so `select_hourly_handoff()` was then choosing a handoff station by a depth its spectrum had not been computed at, and SwellTrack truncated and re-shoaled from that depth. **`_band_ray_origin()` (marine `ac6bd8a`) shifts each transect's own origin shoreward by the profile offset rather than substituting the bare anchor** — substituting the anchor would collapse all 32 transects onto one ray and destroy the per-transect geometry T4B.1 exists to produce. `_shift_along_bearing()` uses the same flat-earth constants as `_profile_origin_offset_m()` and `compute_spot_transect()`'s own `_offset()`, so measuring the offset and undoing it round-trips without a projection residual. With no anchor in the profile the offset is 0.0 and the transect origin is returned unchanged.
>
> **The contour-sized grid edges are projected from the anchor too** (marine `c28588b`). All three cross-shore SWAN grid edges — L3's shoreward edge (the ADR-093 Amendment 2 §2 breaking-depth contour, ≈1.78 m), L3's offshore edge (the 15 m contour), and L2's offshore edge (the 30 m contour) — are sized by `find_depth_contour_distance()`, which walks offshore **from the coastline anchor**. `swan_domain.py` projected all three from the spot-pin centroid instead, displacing every one of them by the pin's offshore offset. At Huntington the L3 shoreward edge was worst: the distance is applied shoreward from the origin, so the edge landed at `anchor + (pin_offset − distance)` — 179.6 m offshore of the anchor instead of 30.0 m, putting the edge that exists to guarantee L3 reaches breaking depth on a 3.56 m seabed rather than the 1.78 m the criterion names. The 15 m and 30 m edges were 209.6 m over-covered, which is the safe direction (the 30 m case is absorbed by its own 500 m margin). `grid_sizing_chain.py` now threads `coastline_by_spot` into `compute_level2_domain()` (COARSE anchors) and `compute_level3_domains()` (MEDIUM anchors), and `_cross_shore_origin()` resolves a cluster's anchor centroid in place of the pin centroid. **The structure-derived offshore term in `smart_size_l3_grid()` is deliberately unchanged** — it is a distance from the cluster centre to the most-offshore structure point, so the centre is its correct origin; only the contour-sized terms moved. Where no anchor is available (the pre-apply `/marine/compute-estimate` preview, which has no bathymetry at all) `coastline_origin=None` preserves the pre-anchor arithmetic verbatim.

> **The 1-D profile's LANDWARD boundary is HAT, sized once at setup — the beach face is kept, not deleted** (ADR-093 Amendment 4, TA-C18). Every prior rule above concerns the profile's *offshore* extent and *anchor*. Amendment 4 adds its *landward* extent. **Bug (TA-C18):** above ≈+0.5 m of tide the served surf collapsed to 0.00 m at HB Pier because each per-transect 1-D profile stopped ~1 m deep — it anchored at the SWAN sampling-band origin (`_band_ray_origin`, ~1 m seaward of the waterline) and the sampler deleted the subaerial beach *twice* (`_grid_depth_below_msl()` clamps land to depth 0, then a `depth_m > 0` filter drops those zeros). `run_1d_analytical` adds tide to every depth, so at high tide the shallowest modeled point rose above breaking depth (`Hs/γ`) → no break → zero. The DEM held land up to +15.1 m the whole time; the beach was being deleted, not missing. **Fix — three coupled changes, per-transect 1-D profiles ONLY:**
> 1. **Own-shoreline anchor.** Each 1-D transect now finds its OWN true shoreline via `find_shoreline_from_grid()` (elevation crosses 0 along the transect's own bearing on the covering FINE/MEDIUM grid), instead of the SWAN POINTS-band origin. The 1-D model is independent of SWAN except at the handoff.
> 2. **Signed subaerial sampling + landward walk.** `extract_native_profile_from_grid(signed_subaerial=True, e_landward_m=…)` samples with `_grid_signed_depth_below_msl()` (land kept as NEGATIVE depth, not clamped to 0) and walks landward up the beach face at native spacing until seabed elevation reaches `E_landward = HAT` (or a defensive `_MAX_LANDWARD_SEARCH_M` = 2000 m ceiling, F2). **Distances are then re-based so `distance_from_shore = 0` is the TRUE WATERLINE — the interpolated depth-0 crossing, not the landward-most beach point — so beach-face points landward of it carry NEGATIVE distance and underwater points POSITIVE.** This is load-bearing: `distance_m` is returned in `Analytical1DResult` and serialized as absolute `distanceFromShore` (API-MANUAL breakPoints), so a break — always seaward of the waterline — must report a distance measured from the waterline that is identical whether or not the transect was extended up the beach (F1; the earlier "landward-most = 0" re-base inflated it by the per-transect beach-face length). The clamped `_grid_depth_below_msl()` is UNCHANGED — SWAN bathymetry and `find_shoreline_from_grid()` still depend on land-clamps-to-0.
> 3. **`E_landward = HAT`, computed ONCE at setup.** HAT is the maximum of the SAME CO-OPS harmonic predictions feeding `tide_level` (`providers/tides/coops.py fetch()`), for the spot's **LOCATION's** `coops_station_ids[0]` — the station is a field on `MarineLocation`, NOT on the surf-spot sub-config (`SurfSpotConfig` has no such field); resolving it from the location is the same source SWAN's runtime tide fetch uses. Requested over a ≥1-year `interval=hilo` window in the DEM's own datum (match-at-source, ADR-098 — tide and seabed share a datum). **No storm-surge term, no wave/runup term** — a surf model, not a flood model. Stored in the per-spot profile cache as `e_landward_m`, `hat_m`, `hat_station_id`, `hat_datum`. On fetch failure the chain logs a WARNING and degrades (no landward extension), never aborts.
>
> `run_1d_analytical`'s existing `depth = max(seabed + tide, 0.01)` clamp then wets/dries the new beach-face cells per forecast hour automatically — grid geometry stays frozen at setup, only the wet/dry state moves. The `depth_m > 0` filters in `providers/nearshore/swan.py` and `endpoints/beach_profile.py` are replaced with keep-if-not-None so the signed land points survive to SwellTrack. **Crucially, this touches only the per-transect 1-D profiles (`profiles_by_transect`, which take priority in SwellTrack) — the per-spot PCHIP `profile` that feeds `interpolate_profile_pchip()` and L4 SWAN-grid sizing is UNCHANGED** (PCHIP rejects negative depths by contract; SWAN grid geometry is out of Amendment 4's scope). A transect whose topobathy cannot reach HAT logs a WARNING naming the spot, shortfall, and transect index (guard, never a silent cap).

**OBSTACLE coefficients — superseded 2026-08-02 by AD-8 (see §14.15).** The per-type coefficients now in force
are the AD-8 static cited values: pier `TRANSM 0.74` (Elgar et al. 2001, ~45% energy blocking, height-ratio
converted); seawall `REFL 0.9 RSPEC` (JMSE 9(9):937, 2021); breakwater/jetty/groin keep their static `DAM
GODA`/`DAM DANGremond` forms (`services/swan_formats.py` `_OBSTACLE_PARAMS`). No plain TRANSM range applies to
breakwater/jetty/seawall/groin as of this correction.

**Hotstart invalidation on grid resize.** When the L3 bbox changes (spot added/removed, segment moved, structure discovered/removed), detected by comparing new bbox hash against cached bathymetry hash. On change: delete old hotstart and bathymetry cache for that cluster. L2's hotstart is unaffected (there is no L1 hotstart any more — SWAN's own L1 was removed 2026-08-23; WW3 keeps its own restart-file chaining, §14.18).

**SwellTrack model section:** See §14.17.

**SurfBeat strip — REMOVED 2026-08-23 (operator ruling "surfbeat is gone"; SURFBEAT-REMOVAL round).** There is no SurfBeat code, cache key, API field, config key or ledger key in the system any more; the surf score's consistency factor uses the swell-dominance bucketing until the set-timing/set-amplitude definition in `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` is ruled and coded. Why: see ARCHITECTURE.md's SurfBeat paragraph (its infragravity peak is the within-set wave-group period, not a set interval; the score's inputs come from the spectrum + SwellTrack). **Everything below in this SurfBeat section is the HISTORICAL record of the deleted design, kept for the archive — none of it is live.** *(Former text:)* A complementary SWAN run type for infragravity energy. Uses the SURFBEAT command in a stationary 2D strip configuration. **Since the SURFBEAT-CYCLE round (2026-08-23, operator rulings in chat): it runs IN THE FORECAST CYCLE, once per forecast hour, next to the SwellTrack precompute** — `services/surfbeat_precompute.py` `precompute_surfbeat_for_spot()` is called from BOTH `providers/nearshore/swan.py` precompute sites (full run and hourly quick-update/fill; the quick-update merges by the same closest-key rule as `swelltrack`), 4 strips in parallel (`_SURFBEAT_WORKERS`, `OMP_NUM_THREADS=2`, nice 10), results cached as scalars under the payload key `surfbeat` (`{iso_time: {hsIgShoreline, setTimingMinutes, setAmplitudeM, hsIgBoundShoreline, hsIgFreeShoreline, runtimeMs, boundaryHsM, boundaryDirDeg}}`, whitelisted in `fetch()`); `endpoints/surf.py` only READS (`_surfbeat_fields_for_time`), never computes. Its boundary is the hour's **deep-water-reference 2-D spectrum** (`SPEC_DWR_<n>` — the 15 m-contour point on the beach bearing, which IS the strip's seaward start; arrays re-attached to the in-memory `spectral_dwr_results` entries only, never cached), matched by EXACT forecast time (a missing hour is skipped with a WARNING, never substituted). `surfbeat_cadence_hours` is no longer read by anything (dead config key; removal is an operator decision — flagged 2026-08-23). The former request-time loop in `get_surf()` (25 strips per request, 3-hourly with carry-forward) is deleted.

**SurfBeat strip SURFBEAT syntax — HISTORICAL (code deleted 2026-08-23; kept as the record of how the SWAN IEM strip was driven, should SURFBEAT ever be revisited)** (SURFBEAT-FIX round 1, 2026-08-22, operator "1 ok" — deck brought to the SWAN 41.51 manual's IEM prescription, `docs/reference/swan-user-manual.txt` §SURFBEAT :3942–3999; see `docs/reference/swan-commands-extract.md` §SURFBEAT):
- Grid: regular 2D (REG), not 1D or curvilinear; `CGRID … CIRCLE 36 0.04 1.0 34` — **the CGRID low frequency IS the IG cut-off fig** (manual :3960–3962; no separate fig parameter, summary :6359–6369). The pre-fix deck's 0.004 Hz made the free-IG range `[df, fig]` empty (PRINT "NTF 1") — no IG existed in any run before this round.
- Mode: STATIONARY; two bare COMPUTEs (not `COMPUTE STAT`): first = sea-swell + bound IG, second = reflected free IG
- Boundary: west side only — **since SURFBEAT-CYCLE (2026-08-23): `BOUNDSPEC SIDE WEST CCW CONSTANT FILE 'BOUND.spc' 1`** (manual :2380–2410, :2548–2557 — a 2-D spectral file serves a STATIONARY boundary; file coordinates ignored), where `BOUND.spc` is the hour's DWR 2-D spectrum written in SWAN Appendix-D stationary form (`swan_formats.write_swan_2d_spectrum_file_stationary`, no TIME block; SWAN accepted it live, PRINT :42) with its direction axis rotated into the strip frame and re-sorted ascending (`_rotate_spectrum_to_strip_frame`); the DWR frequency axis is passed through unchanged (SWAN interpolates, manual :2552–2555). The manual's IEM prescription is "an offshore directionally spread spectrum must be imposed on the west side" (:3964–3965) — the former parametric `BOUND SIDE WEST … PAR hs tp dir 10` (three bulk numbers from the outermost SERVED point, 460 m / 9 m — 1.5 km from where the strip starts) is gone. SWAN REFUSES additional lateral boundaries with SURFBEAT ("boundary specification is not correct in case of surfbeat", live 2026-08-23) — width stays 500 m (ny 20 × dy 25 m; measured: 250 m loses 10 % Hs / 12–17 % IG, 100 m 37–45 %). **Strip frame (2026-08-23):** the strip's x-axis is the beach's shore-normal; the offshore boundary is always the WEST side and the shoreline obstacle the EAST side (manual :3964–3966, :3978–3980), so shore-normal arrival is "from 270°" in strip coordinates whatever the beach faces. `run_surfbeat_strip()` takes WORLD nautical wave and wind directions plus `beach_facing_deg` (`SurfSpotConfig.beach_facing_degrees`) and rotates both with `strip_frame_direction() = (world − facing + 270) mod 360` (rigid rotation, handedness preserved). Until 2026-08-23 both callers passed the world direction straight through (213° at Huntington, facing 216° → 57° oblique in the strip) and the swell leaked out of the strip's open lateral side before reaching the shore (live: Hs 0.58 m at the 14 m boundary → 0.04 m in 9 m of water; vchain 0.61 → 0.27 m over 400 m) — every IG number before that date was forced by a leaking strip.
- Physics: IEM only (manual :3962–3964 — propagation, shoaling, refraction, breaking, friction): no `GEN`/`TRIAD` line; `OFF WINDGROWTH`, `OFF QUAD`, `OFF WCAP` (manual :4082–4121); `BREAKING`, `FRICTION JON` kept
- Wind: **none (removed 2026-08-23).** Under `OFF WINDGROWTH` the field was inert — live control run with a uniform 5 m/s wind spliced back in produced byte-identical TABLEs (run5 vs run5_windctl) — and the manual's IEM process list (:3962–3964) has no wind. Removing it also removed the "missing wind → skip hour" failure mode.
- Cross-shore spacing `_SURFBEAT_DX_M = 1.0 m` (operator ruling 2026-08-23: same as the 1-D model's `ANALYTICAL_TARGET_DX_M`; replaces the 0.5 m of 2026-08-02) over the FULL cached median profile (15 m contour → shore, ~2 km / ~2,000 columns at Huntington; the strip is not shortened — ruling 2026-08-23); ~48 s per strip on librewxr; `_DEFAULT_TIMEOUT_S = 600`.
- Shore end = SWAN-wet cells only (D10, 2026-08-23): the profile's shore-end samples with `depth <= _SWAN_DEPMIN_M` (0.05, the SAME constant the deck's `SET … [depmin]` uses; manual :1269–1271 — a point is wet only when depth > depmin) are trimmed before gridding, so the shore station, the obstacle line and the 2-cell pad are wet (the full profile ends at the 0.0 m waterline; un-trimmed, station and pad were dry and the reflection was NOT taken into account — free IG 0.0008 m vs 0.064 m after the trim). < 2 wet samples → `SurfBeatRunError`.
- `SURFBEAT 0.005 50000 0.05 UNIFORM` (lead call df = 0.005 Hz → 8 free-IG bins 0.005–0.04 Hz; manual default 0.01 gives 4)
- OBSTACLE on the east side TWICE (manual :3978–3982): `TRANSM 1.0` before the first COMPUTE, `TRANSM 0.0 REFL [reflc] RDIFF [pown]` before the second (POWN required). **Placement (2026-08-22, operator "fix it"; manual :3690–3706):** the line sits INSIDE the grid, mid-cell, half a cell east of the profile's shore end, and the grid carries a 2-cell wet landward pad at the shore-end depth (`_SHORE_PAD_CELLS`) — a reflecting line on a boundary is not reflected and must be bordered by wet points on both sides; the shore output station is half a cell seaward of the line (live run with the line on the boundary gave a degenerate free-IG value there)
- Production path (2026-08-23): `services/surfbeat_precompute.py` builds the spot's transects with the identical call the SwellTrack precompute uses, fills them from the per-spot profile cache (`beach_profile._populate_local_bathymetric_profile`), takes the pointwise median across open transects and PCHIP-refines it to `ANALYTICAL_TARGET_DX_M` — the same bathymetry pipeline `get_surf()` ran at request time from 2026-08-22 until this round (that request-time block is deleted). The chain ledger's SurfBeat companion (`vchain._run_surfbeat_companion`) now records the production `surfbeat[t0]` result instead of running its own strip (D5 read-from-production).
- `TABLE … HEAD … HSIGN HBIG HSWELL TM01 DIR DEPTH QB` at every station; `HBIG` = bound-IG Hs, first COMPUTE only (manual :5159); row 2's `Hsig` = free-IG Hs
- `SPECOUT … SPEC2D ABS` (S, sea-swell) and `SPECOUT … SPEC2D ABS L` (IG, frequencies below fig; manual :5455–5504) at the shore station
- Parsing: SWAN's `TABLE HEAD` writes `%`-prefixed header lines with SWAN's OWN printed names (`Hsig`, not `HSIGN`); SPEC2D files are frequency-major (nf rows × nd cols), `VaDens` in m²/Hz/**degr**, integer-scaled by FACTOR, and SurfBeat's stationary files carry one block per COMPUTE back-to-back with NO timestamp (the production `parse_specout_file_multi` cannot read them — the runner has a dedicated reader)

**Friction per condition type:**
- Swell (Tp ≥ 10s): cfjon = 0.038 (default)
- Windsea (Tp < 10s): cfjon = 0.067
- Friction is always enabled in production — frictionless propagation was a development default only.

#### §14.15 Measured deviations of the deployed SWAN binary (41.51AB) from the manual

Findings from testing the actual installed binary against real output, where the manual is
silent, ambiguous, or (on one point) contradicted by what the binary emits. This section is the
authorized home for this material — `docs/reference/swan-commands-extract.md` is frozen to
manual-only content (operator ruling 2026-08-06) and must not carry any of it.

**BOUNDSPEC file-name count: the manual caps one command at 99 file names (:1223); the
deployed 41.51AB binary accepted 132.** Measured 2026-08-09 at the Phase-G relocation deploy
(marine `eecfabc`): the W-side `BOUNDSPEC SIDE W CCW VARIABLE FILE` command carried 132 boundary
files (`&`-continuation-wrapped), the S side 93, and multiple full L1 runs ended with
`Normal end of run v1` and only the pre-existing boundary-difference WARNING class (35 hits over
225 points = 0.16/point, an improvement on B-Accept's 0.85/point). The 99-name cap did not bite.
Do not rely on exceeding it by design forever — treat >99 as measured-tolerated, not
manual-guaranteed; the G9 box cap brings the counts back near ~100+93 regardless.

**PT* column count: the manual states "at most 10 partitions"; the deployed 41.51AB binary
emits 6 columns per keyword, not 10.** Measured 2026-07-25 against a real production
`TABLE_1.txt` (HB Pier L3, 1273 data rows, run 10:14Z): the real header carries `HsPT01…HsPT06`,
`TpPT01…TpPT06`, `DrPT01…DrPT06`, `DsPT01…DsPT06`. A row emitted with `TIME XP YP HSIGN HSWELL
TM01 DIR DEPTH QB DISSURF DSPR PTHSIGN PTRTP PTDIR PTDSPR` has 35 columns, not the 51 that "10
columns per keyword" predicts. Any output-size or column-offset estimate derived from the
manual's "at most 10" figure is wrong for this binary — use 6.

**Per-quantity exception value: `PTDIR` uses `-999`; every other PT* quantity uses `-9`.** The
manual does not document per-quantity exception-value defaults for PT* at all. Verified in the
SWAN source (`swanmain.ftn:2649+`, `OVEXCV` dispatched on `IVTYPE`: 100→-9, 110→-9, 120→-9,
**130→-999**, 140→-9, 150→-9, 160→-9). A parser assuming one uniform sentinel across PT* columns
will misread `PTDIR` points. `QUANTITY PTDIR excv=-9.` may normalise this — unverified, not to
be relied on without testing.

**Absent partition slots at a wet point carry `0.00000`, not the exception value — not even
`PTDIR`'s `-999`.** Checked every PT column of all 1273 rows above: zero occurrences of `-9` or
`-999` anywhere, and 25,288 exactly-zero entries. The exception value applies only where the
variable is genuinely undefined (dry/masked); an unused partition slot at a wet point is
legitimately zero energy. **Consequence:** a parser that skips a slot only on the sentinel value
emits phantom partitions. A version of `services/swan_spectral.py`'s
`parse_table_pt_partitions()` did exactly this (`if hs is None: continue`, reached only via
`_is_pt_exception`), which reported 6 partitions per row — 5 of them height 0, period 0,
direction 0 — where SWAN actually found 1. **Fixed in `12f9ddc`** (T4B.2, operator-approved
2026-07-25, deployed to librewxr): `parse_table_pt_partitions()` now treats `HsPT0k ≈ 0`
(tolerance `0.0005`, well below SWAN's own `HSPMIN = 0.05` m partition floor) as the PRIMARY
absence signal for a slot. The documented `-9`/`-999` exception-value check (`_is_pt_exception`)
is still applied too, belt-and-braces, for a SWAN build/config that might emit it — but real
output never has, so it is never the only signal relied on.

**Observed partition counts** (rows with Hs > 0.05, n = 1254, same measurement): 1 partition in
95.2% of rows, 2 in 4.6%, 3 in 0.2%; slots 4–6 never populated in this dataset. Energy closure
`sqrt(Σ PTHs²)/Hsig` = 1.0161 mean (range 1.0007–1.0254).

**You cannot request an individual partition index.** The command syntax offers only the
aggregate keywords (`PTHSIGN`, `PTRTP`, etc.), which expand to the full column block; there is no
`PT02HS`-style per-partition quantity name. The 41.51AB binary rejects an attempt at one with
`"Invalid partitioning output specification. Use PTHSIGN instead."`

**Sizing:** TABLE with PT* quantities is what `run_1d_analytical()` (which takes scalar `hs`,
`tp`, `direction` per partition) actually consumes — it supplies bulk per-partition parameters
without writing and re-partitioning full 2D spectra. Measured 2026-07-25 at HB: `TABLE_1.txt`
204 KB vs `SPEC_1.txt` 7.4 MB for the same 18 stations × 73 timesteps.

**`INIT HOTSTART` keyword-less form is accepted identically to the manual's form.**
`swan_formats.py:1207` emits `INIT HOTSTART 'hotstart.dat'` (no `SINGLE`/`MULTIPLE` keyword).
Tested directly against the 41.51AB binary: both the keyword-less form and the manual's
`INIT HOTSTART SINGLE 'hotstart.dat'` parse identically and produce identical results — this
build accepts the legacy keyword-less form.

**Hotstart failure root cause is a timestamp/scheduling mismatch, not command syntax (measured
2026-07-25).** `HOTFILE` writes the wave field at the END of the forecast window; a run that
restarts an overlapping window from its BEGINNING asks SWAN to rewind, which it cannot do.
Evidence from an L1 hotfile written by a 10:23Z cycle (`20260728.000000` recorded as the file's
date/time) against the next cycle's `COMPUTE NONST 20260725.060000 10 MIN 20260728.000000` (a
start 66 hours before the hotfile's state) reproduced SWAN's own PRINT errors: `"start time
[tbegc] before current time"` then `"start time [tbegc] greater or equal end time [tendc]"` (SWAN
clamps the start to the hotfile's time, which then equals the end). **Two separate defects
preceded and enabled this finding, and are already fixed in code:** the hotfile was never loaded
at all (save used `level1`/`level2`/`level3_<idx>` naming, load used `outer`/`inner` — fixed in
`a1fa14f`), so SWAN never got the chance to reject a mismatched hotstart before this finding
surfaced it. **Making hotstart usable under the current overlapping-window run scheduling needs
an architectural decision (write the hotfile at the next cycle's start time, or chain windows
forward instead of overlapping, or drop hotstart) — not a code fix, and not decided here.**

**Proven WLEVEL emission pattern** (`swan_formats.py` lines 812-818, `idla=3` convention):
```
INPGRID WLEVEL REG {x_sw} {y_sw} 0. {mxc} {myc} {dx} {dy} NONSTAT {t_start} {dt} HR {t_end}
READINP WLEV 1. 'WLEVEL.txt' 3 0 FREE
```
Stationary (quick update, single timestep):
```
INPGRID WLEVEL REG {x_sw} {y_sw} 0. {mxc} {myc} {dx} {dy}
READINP WLEV 1. 'WLEVEL.txt' 3 0 FREE
```
`idla=3` (left-to-right, bottom-to-top) matches SWAN's south-to-north internal convention, so
`WLEVEL.txt` is written south-to-north, west-to-east — row 1 southernmost.

**BOUNDNEST1/NESTOUT filename collision — root cause of the 2026-07-19 forecast failure
(SWAN-FIXES-PLAN Bug 1).** In a run using both BOUNDNEST1 (reads parent boundary data) and
NESTOUT (writes child boundary data), the two commands must reference different filenames — if
they share one, NESTOUT overwrites the parent data BOUNDNEST1 is still reading mid-run, producing
corrupt output and zero wave energy in the child. The runner's `level{n}/nest_out.dat` →
`level{n+1}/nest_in.dat` copy-between-subdirs convention (§14.15 above) exists specifically so
the filenames never collide within one working directory.

#### §14.15 Amendment: HANDOFF-RESTART — the handoff station is checked, not trusted (S12, 2026-08-27, ADR-093 Amendment 9)

**Why.** The handoff formula (`1.3 × Hs(hour) / γ`, above) places the SWAN→SwellTrack boundary
~30% seaward of that hour's breaking depth — but it is a target-depth lookup against a fixed
station set, not a guarantee. Measurement after the BREAK-REFORM round (2026-08-26) found
SwellTrack reported its main break AT its own starting line on roughly a third of transect-hours
(was a tenth before BREAK-REFORM): the margin the formula assumes (30%) and the margin actually
realized against the 1-D model's own 5% breaking-onset criterion (`Q_B_VISIBLE`) is only ~3.5% in
practice (`1.72 × Hs` vs `1.78 × Hs`) — close enough that ordinary variability in the shoaling
between the formula's target and SWAN's own station grid regularly crosses it. The operator's
ruling (Q11, verbatim): *"the handoff point is never SET IN STONE ... if 1d starts running and
finds the break is wrong, then it restarts the run from the correct location."*

**The mechanism.** SWAN's per-transect band (T4B.1, 10 m spacing, §14.15 above) already exists for
every transect with an L3/L4 handoff; the runner (`swan_runner._select_l3_handoff_position_and_
spectrum()`) now additionally publishes, on every hourly handoff entry, a `band_stations` list:
every band station strictly seaward of the formula's own pick, ordered seaward-most first, each
carrying its own depth and PT* watershed partitions for that hour. The 1-D pipeline
(`surf_1d_pipeline._run_pipeline_per_transect()`) reads that list and, ONE handoff per
transect-hour (not per partition — every surfable partition of a transect shares the same walk and
the same shared truncated profile):

1. Runs attempt 0 (today's formula station) — every partition at/above the 5 s surfability floor.
2. **Acceptance test, both parts, every voting partition:** (i) the wave at the profile's own
   first node is already below the 5% breaking-onset criterion (not `onset_at_node0`); AND (ii)
   when a partition produced a break, its outermost published marker sits at least
   `HANDOFF_BREAK_CLEARANCE_M` (10 m — one L4 cell, matching the SWAN band's own 10 m station
   spacing; `services/transect_handoff.py`) shoreward of the attempt's own handoff station.
3. Any failure re-truncates the SHARED profile at the next band station seaward and re-runs every
   voting partition. A partition's own component is re-matched at the new station by nearest
   period (≤ 2 s, tie → nearest direction); no match leaves that partition ABSENT for the attempt
   (does not block the rest of the transect, one aggregate WARNING per transect-hour). A wind-sea
   (F5-synthesized) partition has no station component — it simply recomputes its growth from the
   new station's own fetch and depth.
4. The band's deep end reached without every voting partition passing → the WHOLE transect-hour is
   REFUSED (`handoff_restart_exhausted`) — nothing is served from the last failed attempt (rules/
   coding.md §1, "a model runs on all its inputs or it does not run"). Attempt cap =
   `len(band_stations) + 1` (never exceeds the band; the existing ≤ 150 station clamp bounds it).

**What is published.** `handoffDepthM`/`handoffSourceLevel` (API-MANUAL §17) are the SETTLED
station's, not necessarily the formula's first pick — same grid level (L4/L3/L2), different
station along it. The `handoff_selection` trace stage gains `restart_attempts` and
`restart_reason` (`None` | `"onset_at_node0"` | `"clearance"` | `"handoff_restart_exhausted"`).
`GET /health` gains an additive `handoffRestart` block: `runs`/`restartedRuns`/`exhausted`/
`attemptsHistogram`/`lastExhaustedAt` counters since service start (count only, never changes
`status`).

**INVARIANT_1 redefined** (`services/invariants.py`): both sides now UNTIED (the break depth
`run_1d_analytical()` reports is tide-adjusted; the handoff depth was already chart-datum —
comparing them directly was the alarm's own bug, Q11 finding A) plus the same clearance test the
restart loop itself enforces. A post-S12 firing therefore means the restart loop failed to hold
its own contract, not a tide-datum mismatch. This redefinition applies at BOTH INVARIANT_1 call
sites — the per-transect settled check, and the shared-spectrum (non-per-transect) legacy path,
which carries no restart loop and evaluates the same redefined test against attempt-0's own
handoff/profile.

**Two spacings, not to be confused.** The SWAN band stations the restart walks between are the
existing 10 m T4B.1 spacing. SwellTrack's own profile is the variable-resolution PCHIP profile
from the 3 m bathymetry download (~1.5 m nodes in the breaking zone, ~4 m in the shoaling zone,
native points beyond 15 m) — a different grid entirely. `HANDOFF_BREAK_CLEARANCE_M` is a
DISTANCE (metres), never a node count on either grid.

**What does NOT change.** `select_hourly_handoff()`'s own formula/rule-of-three (L4→L3→L2) and
`breaking_margin_depth_m()` (`1.3 × Hs / γ`) are unchanged — the formula's station stays the FIRST
attempt only. No SWAN grid geometry moves; the restart walks an already-existing, already-sized
band. See ADR-093 Amendment 9 for the decision record.

#### §14.15 Amendment: geography-aware study-area geometry (target — Marine Geometry-Model Plan G0–G6; ADR-093 Amendment 5 + ADR-100)

**This amendment changes the VALUES fed into the SWAN emitters, never their syntax, and never the sizing
formulas.** The sizing formulas and constants of §14.15 (`1.3 × Hs / γ`, γ = 0.73, `_MIN_DESIGN_HS_M`, the
30 m/15 m contour criteria, tier resolutions, nesting ratios, the shadow-union + 2λ formula) are **unchanged
and off-limits**. What changes is *which bearing / exposure / open-water direction / grid axis / L3-enable
trigger* is passed into that machinery. Items marked "(target — Phase GX)" are not yet code-migrated.

**Facing derivation — the smoothed-0 m-shoreline normal, per-transect (AD-1R, Phase G1R; SUPERSEDES the AD-1
isobath ray-fit).** `beach_facing_degrees` and each transect bearing are the **seaward perpendicular of the
smoothed 0 m shoreline's local tangent** (USGS DSAS smoothed-baseline / CliffMetrics v1.0), NOT the 2 m/5 m isobath
ray-fit (which gave 202° vs the true ~220° at Huntington and is deleted). `shoreline_normal_bearing(grid, segment
endpoints, *, anchor_lat=None, anchor_lon=None)` in `enrichment/bathymetry.py` traces the 0 m shoreline as an
ordered polyline seeded along the drawn segment, moving-average-smooths its coordinates over an alongshore window
swept 500 → 2500 m until the heading settles (≤ 5° change between windows), and returns the seaward normal of the
smoothed tangent; degenerate/short-run shoreline falls back to the segment-perpendicular + WARNING. The strip
bathymetry it runs over is fetched from the **drawn segment alone** (`fetch_shoreline_strip_bathymetry`, a
segment-bbox coverage box through the existing profile-bathymetry downloader) — **no SWAN grid/domain input**, so
the facing is defined at spot-definition time before any nest is sized (a no-structure spot never has an L4). The
pinned equations/constants live in MARINE-GEOMETRY-MODEL-PLAN §AD-1R and are implemented verbatim. Producers:
`config/marine_config.py` (the restored `beach_facing_degrees` + `beach_facing_source` config keys),
`services/grid_sizing_chain.py` (reads the stored facing; re-derives only when the source is `fallback_segment_perp`
or absent; derives the per-transect bearings from the strip), `services/swan_formats.py` (`compute_spot_transects`
per-transect via the same helper / the `transect_bearings` override). Consumers are **unchanged** —
`find_shoreline_from_grid`, `find_depth_contour_distance`, `compute_transect_shadows` already take a bearing.
Operator override: `beach_facing_source = "operator"` wins at every consumer and makes per-transect bearings
uniform. **Sizing aggregation is coverage-driven:** L2/L3 enclose the **union** of every transect's own
offshore-contour reach (the covering envelope already computed), not a single averaged bearing — the bearing's only
sizing role is the contour-measurement direction. Validated on the real Huntington config 2026-07-31: the chain
resolved the facing to 217.0° from the strip (within 220° ± 5°; 202° did not reproduce).
**Runtime reach (G1.6, landed).** Because the SWAN runtime process re-parses the persisted operator config fresh
(recomputing the segment-perpendicular) and reads only caches, the resolved bearings are **persisted into the
per-spot profile cache** (`spot_profiles/{spot_id}.json` gains `beach_facing_degrees` = the midpoint shoreline-normal
and `transect_bearings` = the per-transect list, index-aligned with `profiles_by_transect`). At runtime the marine
service writes the cached `beach_facing_degrees` back onto the `SurfSpotConfig` via a setter at profile-cache load
(so every existing `beach_facing_degrees` read, incl. the invariant-6 check, then uses the shoreline-normal — which
also makes invariant-6 self-consistent, since its 15 m-contour reference was already measured along the
shoreline-normal), and threads the cached `transect_bearings` into `compute_spot_transects` (a new override param;
priority override > grid > scalar) for both the served SWAN CURVE emission and the SwellTrack precompute. This is a
**value-only** change into the existing emission — no SWAN command syntax changes. A cache lacking the fields falls
back cleanly to the segment-perpendicular. The served effect is validated live at Gate GR.

**L1 (deep-water domain) aim + WW3 boundary sides — the open-water fetch fan (AD-3, ADR-100, Phase G2). IMPLEMENTED + DEPLOYED.** "L1" below is the deep-water domain's geometry name (`deep_water` in code/config, renamed from `level1` 2026-08-27, marine `c57bb8e`, plan §S3 (b)) — the domain WW3 now computes over; it is not a SWAN compute level (SWAN's own L1 was removed 2026-08-23, marine `3c550ae`/`c29266d`).
(marine `51543b1`, 2026-08-01 — confirmed against current code, not just the commit message: `_compute_deep_water()`
takes `open_water_bearing_deg`/`regime`/`fetch_value_km`/`rays`/`horizon_km`, `services/grid_sizing_chain.py`
passes all five from `geography_result` at apply time, and `providers/nearshore/swan.py` passes
`offshore_bearing_deg=domains.open_water_bearing_deg` into `select_boundary_stations_with_cycle_fallback()` at
runtime). `_compute_deep_water` (`services/swan_domain.py`) aims the L1 offshore extension along the **open-water
bearing** from the fetch fan (`services/geography.py`, ADR-100), not `mean_offshore_bearing_deg`;
`ww3_station_selection`'s offshore-side selection reads the same open-water bearing — see §14.3b above for the
runtime-wiring defect this fixed (the runtime call previously omitted the argument and silently fell back to
beach facing). **VALUE change only** — L1/L2 stay axis-aligned; the CGRID/INPGRID emission, the
`mean_offshore_bearing_deg` definition, the WW3 station **qualification** criterion (`deep water OR tanh(kd)`),
and the cardinal-only (N/E/S/W) side set are all unchanged. **Wrap-candidate directions** (island/headland/
peninsula with ≥5 km open water beyond) enlarge L1 to enclose the intervening land + the open water beyond so
WW3 computes the wrap-around (SWAN never sees this domain — it starts at L2). **Great Lakes** L1 is sized from the fan's fetch value (lake fetch), not
`find_shelf_distance` (which returns the nearest ocean shelf and oversizes a lake L1); the GLWU product routing
already exists.

**Exposure source — fan-derived (AD-2, Phase G3).** `enrichment/surf_scorer.py` reads the **fan-derived**
exposure (directly-open & wrap-candidate = EXPOSED, truly-blocked = sheltered) in the **same
dict-of-8-compass-sectors→bool shape** the config field used. The typed `directional_exposure` config field
becomes an optional override. **`compute_structure_grid_domain()` no longer takes a `directional_exposure`
parameter at all** — the 2026-08-01 L4 sizing rewrite (marine `4e79d21`, ADR-093 Amendment 6) dropped the
exposure-derived lateral-halo margin along with the OMBB axis method; L4's lateral extent is now the footprint/
shadowed-handoff-point envelope described in §14.15 below, with no separate exposure input. **VALUE change
only** for the surf-scorer consumer —
`compute_structure_grid_domain` and the L4 sizing math are unchanged.

**L4 axis + clustering (AD-4, Phase G0.1 + G4) — ⛔ REVERSED 2026-08-01, see below for current design.** The
OMBB-axis design this subsection originally described (`services/structure_geometry.py`, shapely
`minimum_rotated_rectangle`, `rotation_deg` from the obstacle-plus-shadow OMBB long-axis, primary-structure
selection for far-apart obstacles) never reached a converged deployment — Gate G4 failed (L4 grid landed on
land; see MARINE-GEOMETRY-MODEL-PLAN.md Critical finding 2) — and was replaced before AD-4 shipped. Kept for the
historical record only; **do not implement.**

**L4 sizing — CURRENT design (`compute_structure_grid_domain()`, marine `4e79d21`, 2026-08-01, R3 residual
"L4-transect co-registration"; ADR-093 Amendment 6, operator-approved).** `rotation_deg` = the resolved **beach
facing** (`avg_bearing` — the same shoreline-strip-derived bearing AD-1R computes), never a structure axis. The
grid is the beach-frame bounding rectangle of **every eligible structure's own footprint UNION the handoff
points of every surf-area transect any one of them shadows**:
- **Shadow test** is per-structure (never a union footprint — a gap between two structures must not itself be
  shadowed, since that gap is exactly where swell passes through) against the geography fetch fan's open rays
  (`open_rays` — any classification but `truly_blocked`; `wrap_candidate` counts as open, conservative
  coverage).
- **Shoreward edge** (`u_min`) = the minimum-`u` shadowed transect handoff point only — never a structure
  footprint point (a pier root on the beach must not drag the grid landward; footprint points landward of
  `u_min` are expected-clipped, and the SWAN obstacle line is clipped at the grid edge). Each transect's own
  handoff point is its own first seaward crossing of the ADR-093 `l3_shoreward_edge_depth_m()` contour
  (`1.3 × _MIN_DESIGN_HS_M / γ` = `1.3 × 1.0 / 0.73` ≈ **1.78 m**, `services/swan_domain.py`) on its own profile.
- **Seaward edge** (`u_max`) = the seaward-most footprint point across every eligible structure, + one margin
  wavelength (unchanged tip-depth/dispersion arithmetic — only the lookup point moved from the OMBB tip to
  this).
- **Lateral extent** (`v_min`/`v_max`) = min/max across every eligible structure's footprint UNION the shadowed
  handoff points, ± one `resolution_m` (10 m, `_STRUCTURE_GRID_DX_FLOOR_M`) cell of slack.
- **Zero shadowed transects** → L4 is skipped (not sized) for that cluster.

**No primary-structure selection** (operator ruling 2026-08-01, same day as the rewrite): a beach may have no
dominant structure (two equal breakwaters; a jetty with adjoining breakwaters). Every operator-identified
eligible structure participates in the ONE sized grid — `_cluster_structures_by_proximity()`/
`_select_primary_group()` are deleted; the "far-apart obstacles get the primary structure's L4, others logged to
concerns" behaviour described above no longer exists. **Only the `alpc`/`alpn` values and extents change;
CGRID/NGRID syntax is unchanged.** Sized once at config push, frozen — no runtime resizing.

**Measured production numbers (HB regen, 2026-08-01 ~19:00 UTC, deployed commit `4e79d21`):** beach facing
resolved 216.4° from the shoreline strip; L4 = 46×137 = 6,302 cells, u_span 450 m, v_span 1358 m, rot 216.4°,
dx 10 m, 143/143 transects shadowed, 37 open rays, `n_footprint_clipped`=16, `L_tip` 128.3 m; L3 coarse nest
45×40 @ 40 m around L4 (≥200 m clearance). For contrast, the superseded OMBB-axis grid measured 458×1247 m,
rot 47.3°, 46×125 = 5,750 cells, median depth −0.17 m, 54% dry, 333/352 handoff points outside the grid,
valid_fraction 5.2%. **A full SWAN test run against this rewrite was in progress as of this doc-sync pass —
test-run/reality-gate results are not yet available; see MARINE-MODEL-RESTORATION-PLAN.md §R3.**

**Obstacle representation (AD-8, Phase G4.3–G4.5).** `normalize_structure` (via the OMBB) routes each structure
to `line` or `footprint`: a solid structure (`breakwater|jetty|groin|seawall|mole`) **≥ 3 L4 cells (~30 m) wide**
→ **burn its footprint into the L4 BOTTOM** as emergent cells (values in `BOTTOM.txt`; INPGRID/READINP BOTTOM
syntax unchanged, stationary-only, `idla=3`), no OBSTACLE line; everything else (all piers; solid < 3 cells) → an
**OBSTACLE line** on the simplified OMBB centerline (≤180-char `&` wrap; OBSTACLE LINE format unchanged, only the
vertex list simplified). **Static cited per-type coefficients** (`_OBSTACLE_PARAMS`, `services/swan_formats.py`):
pier `TRANSM 0.74` (Elgar 2001, ~45 % energy blocking); seawall `REFL 0.9 RSPEC` (smooth vertical / sheet-pile,
JMSE 2021); breakwater/jetty/groin keep their existing `DAM GODA …` / `DAM DANGremond …` forms unchanged.
Dynamic per-segment crest `Rc` and Seelig–Ahrens reflection are DEFERRED. **Presence check:** a structure already
emergent in the DEM (emergent-cell fraction ≥ 0.65 AND an elevation-anomaly ridge) → skip injection, logged (no
double-count). Dep: **shapely only — no `rasterio`.**

**L3 trigger — derived break-type (AD-5, Phase G5).** The L3-enable decision (`services/swan_domain.py`,
`_TOPOGRAPHIC_L3_TRIGGERS`) reads the **derived** point-break/headland/bay classification (from the measured
shoreline/isobath curvature, a `services/geography.py` helper reusing the isobath analysis) instead of the config
`topographic_feature`. `topographic_feature` is retained as an **optional override** (e.g. a submerged reef).
**Only *whether* L3 emits changes** — L3's CGRID/NGRID emission and the viability test are unchanged.

**`classify_region` reuse (AD-7, Phase G0.2).** The coarse **5-region coastal** `classify_region` +
`REGION_*` constants are moved to a shared `services/region.py` (pure move, identical logic); both
`enrichment/bathymetry.py` and the geometry water-body regime import it. The **11-region biogeographic**
same-named function in `enrichment/fishing_species.py` is renamed `classify_biogeographic_region` (callers
updated). **The two are NOT merged — different taxonomies; merging is a bug.**

**T4B.1 per-transect POINTS bands — full grid crossing, not an Hs bracket (BD-1, `SURF-ZONE-BREAK-DETECTION-
SPEC-2026-08-01`, marine `03b33e1`, 2026-08-01).** The per-transect station band (`swan_runner.py`, the loop that
writes each transect's `POINTS_{n}_{index}.txt`/`TABLE_PT_{n}_{index}.txt`) used to bracket only the expected
handoff depth (`_TRANSECT_BAND_PAD_FRACTION = 0.5`, padding an L2-Hs-derived target on both ends). It now spans
each transect's FULL crossing of the inner grid it samples, so BD-1's break-suspect scan (below) has the whole
line to search, not just the neighbourhood of one depth guess. Mechanism: `compute_spot_transect()`'s call site
passes a deliberately out-of-range deep target (`_TRANSECT_BAND_FULL_CROSSING_DEEP_M = 999.0`) so the function's
own `_dist_at_depth()` substitutes the profile's deepest sampled point (already logged there), and the seaward
end is then determined SOLELY by that function's **existing** `grid_bbox` clip (already logged there too) — the
actual inner grid's own edge along the transect's bearing, not a new depth guess or new geometry. No new
ray/bbox-intersection code. `_TRANSECT_BAND_MAX_POINTS` raised **60 → 150** — a clamp headroom, not an
allocation target: measured production station counts on the deployed L4 (u_span 450.2 m, 2026-08-01) are
~45–55 stations/transect at `_TRANSECT_BAND_SPACING_M` (10 m); 150 is well above that, sized for the old
narrow-bracket assumption's replacement.

**Mandatory memory fix — TABLE_PT parse-and-delete.** Full-length bands multiply each transect's `TABLE_PT_*`
file size roughly in proportion to the wider station count. Measured at HB (143 transects/spot): **42 MB/cycle**
at the old pad-bracket width → **~170 MB/cycle** at full-length, on a memory-tight tmpfs box, if each file were
left for the run's final tmpdir cleanup like before. The offsetting fix (mandatory, not an optimization): each
`TABLE_PT_*` file is deleted from tmpfs immediately after its content is captured into `_t_table_text` during
the per-transect handoff-selection loop (`swan_runner.py`, T4B.3), rather than persisting until cleanup.

**Known limitation — this shortens the tail, not the peak.** `_check_convergence()`'s Check 3 (valid-point
fraction, R7.2-scoped to `TABLE_PT_*` for `level4_*` runs) reads every declared `TABLE_PT_*` file's full text
BEFORE the T4B.3 handoff-selection loop runs and deletes them — `_check_convergence()` is called once per grid
level immediately after that level's SWAN run completes, which is earlier in the cycle than the per-transect
handoff selection. SWAN itself writes every `TABLE_PT_*` file to tmpfs during its own COMPUTE step, before any
consumer reads or deletes anything — so the PEAK simultaneous tmpfs footprint (every file present at once) is
already reached before `_check_convergence()` runs, let alone before T4B.3's delete-after-parse. The T4B.3 fix
reduces how long the files linger AFTER being consumed (the tail); it does not reduce how many exist
simultaneously right after SWAN writes them (the peak). Recorded as a known limitation, not a defect in the
fix — the fix's own authorized scope was the offsetting cost of full-length bands, not `_check_convergence()`'s
read pattern.

**Handoff selection — break-suspect scan + seaward-of-break constraint (BD-1/BD-2, marine `03b33e1`/`ea62e85`,
ADR-093 Amendment 7).** Before `select_hourly_handoff()` picks this hour's handoff station, every transect's
full band (now full-crossing, above) is scanned seaward→shore by `find_outermost_break_index()`
(`services/transect_handoff.py`) for the first station where either the depth-limited criterion
`Hs ≥ γ·depth` or QB ≥ the existing QB threshold indicates active breaking — both criteria reused from this
module's own existing constants (`_GAMMA_BREAKING`, `_DEFAULT_QB_THRESHOLD`), no new formula. `None` entries
(dry cell / no row this hour) are skipped, never treated as breaking or clean. The result
(`max_seaward_break_index`) restricts `select_hourly_handoff()`'s nearest-to-target-depth search (both the L4
and L3 branches) to stations strictly seaward of that index — the SAME target-depth formula and QB refinement
as before, only the candidate pool narrows. No suspected break anywhere on the band → unconstrained search,
byte-identical to before this change. **When the constraint actually moves the pick, the published
`handoff_depth_m` follows the selected station's own depth** rather than the untouched formula target
(adversarial audit Finding F1, `ea62e85`) — see ADR-093 Amendment 7 for why (a published depth shallower than
every station on the shifted profile silently drops the transect downstream at `_truncate_bathy_at_handoff()`).
See ADR-093 Amendment 7 for the full architectural framing (this is a trigger-1 criterion change, authorized by
`SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01` + operator sign-off — the target-depth formula itself, Amendment 2
§2, is unchanged).

**Primary-break reporting (BD-4, marine `03b33e1`/`ea62e85`/`b60ef92`, ADR-093 Amendment 7).**
`PartitionBreakResult.break_points` stays a list ordered outermost-first, unchanged — but the break reported as
"the" break for a partition/transect is no longer unconditionally `break_points[0]`. `primary_break_index`
(default 0) names the break with the LARGEST face height, usually but not always the outermost. Every consumer
that reports "the break" reads `break_points[primary_break_index]`: `PartitionBreakResult.face_height_m`/
`hs_at_break_m` themselves, the peel-angle break-point choice, `per_partition_breaks` summaries, and the §11.3
combined-face depth cap (`_combine_partition_faces_11_3()`, which now caps against the PRIMARY break's depth,
not unconditionally the outermost's). `endpoints/beach_profile.py` emits, per partition, one entry pairing the
PRIMARY break's own geometry with its own face height, plus every OTHER break point in that partition (each
with its OWN geometry and its OWN freshly-computed face height, never the primary's) — see API-MANUAL.md §18
for the wire-level detail. **`INVARIANT_1` and diagnostic `trace.emit()` sites intentionally keep reading
`break_points[0]` (outermost)** — unchanged, by design: they observe the outermost/seaward-most break, a
different question from "which break is biggest," and BD-2's seaward-of-break constraint only strengthens what
they observe.

**Adversarial audit note.** `03b33e1`'s initial implementation was audited before this round closed; two
findings (F1 above, and F2 — `beach_profile.py` pairing the outermost break's geometry with the primary's face
height on a double-break day) were fixed (`ea62e85`) and re-audited PASS. F2's own remediation flagged, without
fixing, a companion defect in the same file's non-primary-break loop; `b60ef92` fixed it same-day with its own
dedicated test. Full narrative: `MARINE-MODEL-RESTORATION-PLAN.md` decision log, Round-1 entry.
`_transect_band_depths()`/`_TRANSECT_BAND_PAD_FRACTION` (the retired band-sizing helper) are kept, not deleted —
`tests/test_swan_l4_intersection.py` still tests the helper directly and is outside this round's scope.

**Round 1 live verification — CLOSED, PASSED (2026-08-01, post doc-sync).** The full SWAN test run that was
"in progress" when this section was first written completed and passed: L4 accuracy 99.6%, valid_fraction
100.0%, 0 NaN; 143 transects × 67/67 timesteps resolved on their own bands; 3,266 total band points (~23/
transect average — full-length crossing chords vary per transect, no 150-cap hits, memory roughly half the
170 MB/cycle estimate above); 143× "no suspected break zone … handoff selection unconstrained (byte-identical)"
INFO lines — the case-(c)/`None`-constraint no-op path verified live, not just by known-answer test; forecast
published. Round 1 gates: adversarial audit PASS, lead gate 141/141, docs committed+pushed.

**Round 2 — main-break-zone headline (BD-7), representative transect (BD-9), BD-8 retirement (marine
`9719db1`/`732e87d`, ADR-093 Amendment 7).**

`_compute_main_break_zone()` (`services/surf_1d_pipeline.py`) is the single source of truth for the headline
and the representative-transect pick, called once and shared by both aggregation paths
(`_run_pipeline_per_transect()` and `run_pipeline()` Step 6 — never duplicated). Algorithm, exactly as
implemented:
1. `spot_mean` = mean `best_face_height_m` over every SUCCESSFUL transect (BD-8: structure-affected included).
2. Candidate = `face >= spot_mean`.
3. Maximal contiguous runs of candidates, by `transect_index` — a failed/missing transect breaks a run exactly
   like a non-candidate does.
4. Main zone = the candidate run with the highest MEAN face among runs of length `>= 5` (the operator-ruled
   minimum-zone-width; spec §6.2).
5. **Fallback A** (no candidate run reaches length 5, but `>= 5` successful transects total): the highest-mean
   5-consecutive-transect window among ALL successful transects, still index-contiguous. **Fallback B**
   (`< 5` successful transects total, OR — a residual case the spec names by ruling but not by number, operator-
   approved 2026-08-01 — `>= 5` total but no contiguous block reaches length 5 because of scattered failures):
   the main zone is every successful transect handed to the function. `main_zone_transect_count` is therefore a
   MEMBER count, not necessarily an index span (Fallback B can leave gaps between `main_zone_start_index` and
   `main_zone_end_index`).
6. `zone_mean`/`zone_sigma` = mean and POPULATION standard deviation (`statistics.pstdev`) of in-zone faces.
   Effective qualifying threshold = `min(zone_mean + 0.75 × zone_sigma, 5th_highest_in_zone_face)` — the
   operator-ruled upper-tail semantics (spec §6.1: SWAN conveys hourly-averaged statistics, not individual
   waves, so the upper tail of transects — not a symmetric band around the mean — is what corresponds to the
   set waves surfers judge by). When the zone has fewer than 5 members (only reachable via Fallback B),
   "5th-highest" degenerates to the zone's minimum face, so the threshold can never exclude every member.
7. Qualifying = in-zone entries `>= ` that threshold. `main_zone_face_height_m` (THE headline) = mean of
   qualifying faces — always non-empty by construction (the threshold is a `min()` against one of the zone's
   own faces, so at least the zone maximum always qualifies; can admit more than 5 on ties).
8. BD-9 representative transect = the in-zone entry (not just the qualifying subset) whose face is closest to
   `main_zone_face_height_m`; ties broken by smallest `|transect_index − zone_alongshore_center_index|`, then
   by lower `transect_index`.

**`INVARIANT_10`** (`services/invariants.py`, `"10:main_zone_face_leq_best_peak"`) checks
`main_zone_face_height_m <= best_peak_face_height_m + ε`, gated on a non-empty zone — a mean of a subset can
never exceed the true whole-area max by construction; this is a sanity backstop, not a new rule.

**BD-8 retirement — `is_structure_affected` is metadata/map-UI only.** Both aggregation call sites
(`_run_pipeline_per_transect()` and `run_pipeline()` Step 6) were renamed from `open_transect_results` to
`aggregation_transect_results` — the structure-affected filter that used to build that list is gone.
`open_transect_count` is now computed SEPARATELY, purely as a reported count, and reads nothing into any
aggregation path (best peak, spot average, peel angle, or the BD-7 zone algorithm above). The dead "no open
transects" WARNING branches this filter used to trigger are removed. A structure-degraded transect simply
fails to clear the candidate/threshold gates on its own merits; a structure-improved one legitimately
qualifies — neither is special-cased.

**`endpoints/surf.py` wire derivation.** `_swelltrack_face_m` (which feeds `breakingFaceHeight`,
`waveHeightAtBreak`, `breakingHawaiianHeight`) = `main_zone_face_height_m` when `> 0.0`, else
`best_peak_face_height_m` — the same "nothing broke this hour" trigger `modelStatus == "no_breaking"` already
used. **`bestPeakFaceHeight` is decoupled** from this derivation (bugfix, not a behavior choice: it was
previously silently aliased to whatever fed `breakingFaceHeight`, so at times it reported the open-transect
max under a "best peak" label rather than the true whole-area max) — it is now always
`PipelineResult.best_peak_face_height_m` directly, the true single-transect maximum over every successful
transect. Five new camelCase wire fields (`mainBreakZoneFaceHeight`/`mainBreakZoneStartIndex`/
`mainBreakZoneEndIndex`/`mainBreakZoneQualifyingCount`/`representativeTransectIndex`) are populated in both the
data-present and `modelStatus: "unavailable"` (all-null) branches — see API-MANUAL.md §17/§18 for the full wire
contract.

**`endpoints/beach_profile.py` — `_select_best_transect()`.** `transect_index=best` now prefers
`pipeline_result.representative_transect_index` when present; falls back BYTE-IDENTICAL to the legacy
open-transect max-face selection only when that field is `None` or not found in the transect list (a pre-
round-2 cache entry, or a degenerate case) — a deliberate coordinator ruling to leave the legacy path
unchanged for old cache entries rather than reinterpret them.

**Cache codec (`services/swelltrack_cache.py`) — 7 new `PipelineResult` fields + a Round-1 latent-defect fix.**
`main_zone_face_height_m`/`main_zone_start_index`/`main_zone_end_index`/`main_zone_transect_count`/
`main_zone_qualifying_count`/`main_zone_threshold_m`/`representative_transect_index` are serialized and
deserialized; an old cache entry written before this round simply lacks these keys, and the decoder's `.get()`
calls supply the dataclass's own defaults (`0.0`/`None`/`0` per field) — never raises on an old payload.
**Separately, `primary_break_index` (BD-4, Round 1) is now round-tripped on `PartitionBreakResult`** — this
closes a LATENT Round-1 defect: the encoder never wrote the field and the decoder never read it, so every
cached `PartitionBreakResult` silently reset to `primary_break_index=0` (outermost) on every cache read, even
when the pipeline had just computed and served a genuine non-zero primary index moments earlier in the same
run. Found at this round's scope-ack review and confirmed live in the actual published forecast cache before
the fix (not merely inferred from reading the code). Fixed the same way as the 7 new fields: encoder writes it,
decoder reads `int(d.get("primary_break_index", 0))` — an old payload still defaults to 0, never raises.

**Adversarial audit — PASS WITH FINDINGS (`732e87d`).** `9719db1`'s initial Round-2 implementation was audited
before this round closed. **F1 (MAJOR, test-evidence gap):**
`test_two_candidate_runs_both_geq_five_higher_mean_wins`'s fixture had a `spot_mean` that excluded one of the
two supposed candidate runs from ever being a candidate at all, so "higher mean wins between two candidate
runs" was never actually exercised by the test that claimed to prove it. Remediated: the fixture was rebuilt
with an explicit low-background precondition (asserted in the test itself) pulling `spot_mean` below both
runs, plus a position-variant test proving the winner is chosen by mean alone, not array position, in both
directions. Re-audited PASS (19 passed, was 18; targeted 7-file set 84 passed, was 83). **F2 (the Fallback-B
residual case — scattered failures leaving gaps within the zone's index span):** operator-APPROVED in chat
2026-08-01 as a real, intentionally-scoped case, not a defect — the Fallback-B code itself is UNCHANGED by this
audit. **F3 (MINOR):** `main_zone_transect_count`'s docstring corrected to state it is a member count, not
necessarily an index-contiguous span — see the field's own docstring, above.

**Full suite / targeted-test discipline (operator directive 2026-08-01).** `9719db1`'s own full-suite run
(completed BEFORE the operator's "skip full suite going forward" directive landed) measured 627 passed / 2
failed (pre-existing `test_serve_nothing_on_failure.py` failures, unrelated to this round) / 2 skipped — the
608/2/2/1 baseline plus 19 new Round-2 tests. Not re-run after the directive. `732e87d`'s own remediation
verification and the lead's gate both ran targeted sets only (per operator directive): `732e87d` itself
verified via `tests/test_main_break_zone_headline.py` (19 passed) + a 7-file targeted set (84 passed); the
lead's own gate ran 140 targeted tests including the Round-1 guard files, in its own separate shell.

**Live verification pending (Round 2).** A full SWAN test run against this Round-2 implementation was being
pushed/deployed at the time of this doc-sync pass. No run/convergence/reality-gate result is claimed here.

#### §14.15 Amendment: C6 seam-fidelity ledger row (S1, 2026-08-27, PA5, EVO-Q16 C6)

**One additive L2 output point, `SEAM`.** The L2 deck's existing DWR block (`swan_runner.py`'s `run_3level()`,
the `_dwr_lines` insertion before `COMPUTE`) gains one extra `POINTS`/`SPECOUT` pair beyond the per-spot DWR
points it already emits: `POINTS 'SEAM' x y` + `SPECOUT 'SEAM' SPEC2D ABS 'SPEC_SEAM.txt'`, same `OUTPUT`-clause
convention (per-hour when the deck's own nonstationary/stationary-sequence output is enabled) and the same UTM
transform (`lonlat_to_utm`, the deployment's locked zone) the per-spot DWR points use. This is monitoring
instrumentation, not a new model input or handoff point — it changes nothing about what any surf spot's own
DWR/TABLE points compute or where L3/L4 nest.

**Where `SEAM` sits.** The WW3-handed side is the transfer file's own most-seaward L2 boundary/seam point — among
the `L2P####`-named points the WW3 march deck's Type-2 point list emits (Gap G8, §14.18), the one with the
largest projection onto the deployment's `open_water_bearing_deg` from the L2 grid's centre
(`services/vchain.py`'s `locate_seam_point()`). The SWAN-absorbed side, `SEAM` itself, sits exactly one L2 cell
(the deployment's live `resolution_m`, always 100 m today) inward from that same boundary point along the same
bearing, toward the L2 centre — **never AT a boundary cell** (ADR-095 Amendment 2: SWAN does not compute usable
energy at its own boundary row). Both point identities (the transfer point's name/lat/lon and the `SEAM`
point's lat/lon) are carried into the ledger row, not just the number.

**Failure posture.** `locate_seam_point()` and the deck-emission call site never raise — a missing WW3 transfer
file, an absent `open_water_bearing_deg` (a boxed-in deployment with no open direction, or a pre-G2 grid-sizing
cache), or a transfer file with no `L2P`-named point logs ERROR/WARNING and skips `SEAM` emission for that
cycle only; every surf spot's own DWR/TABLE output is computed exactly as it would be without this addition.

**The ledger comparison.** `services/vchain.py`'s `record_chain_cycle_ledger_row()` reads `swan/level2/
SPEC_SEAM.txt` (via the SAME `swan_spectral.parse_specout_file()` the per-spot DWR points use) and compares it,
per `SEAM_BAND_EDGES_HZ` frequency band, against the WW3 transfer spectrum already parsed for the row's `ww3`
block (never a second transfer-file read) — see OPERATIONS-MANUAL.md's "Seam-fidelity row" for the full row
shape, tolerance, and named-error contract. **Unit/basis conversion**, cited from both parsers' own docstrings:
SWAN's `SPECOUT ... SPEC2D ABS` density is m²/Hz/deg (SWAN manual Appendix D, p.141) on a NAUTICAL "coming FROM"
direction axis in degrees — the deck carries an explicit `SET NAUTICAL` line (`swan_formats.py`), matching
`swan_spectral.parse_specout_file()`'s own docstring. The WW3 transfer format (`vchain.parse_transfer_file()` /
`ww3_formats.py`) is m²/Hz/rad on a "going TO" axis in radians. `vchain._swan_specout_to_going_to_per_radian()`
converts the SWAN side to the WW3 side's basis before either side is integrated — direction via the exact
inverse of `integrate_spectrum()`'s own `dir_from_deg` conversion, density via the standard per-degree →
per-radian rescale (`× 180/π`).

**A measured noise floor, not a defect.** The WW3 transfer-file writer stores its frequency axis at 4
significant figures (`%0.3E`); the SWAN SPECOUT writer stores the SAME nominal axis at 6 (`%.5E`). Re-parsed
back, the two sides' own bin-width calculations differ by a few tenths of a percent, propagating into each
side's Hs via `4×√m0` — a real property of the two file formats' differing text precision, not a bug in either
parser or in the comparison logic (each side correctly uses its own parsed axis; assuming the two files share
an unrounded axis would be the actual defect). `SEAM_HS_TOLERANCE` (±10%) is sized well above this floor.

### §14.16 GFS wind provider (Phase 7 — supplements HRRR for 72-hour forecast)

**Module identity:** `providers/wind/gfs.py`, `PROVIDER_ID = "gfs"`, `DOMAIN = "wind"`.

**CAPABILITY:** `geographic_coverage = "global"`, `auth_required = []`. `supplied_canonical_fields` includes U-component and V-component of wind at 10m above ground level, earth-relative.

**Availability:** Part of the marine service, not the API. Invoked by the marine service's SWAN runner alongside the HRRR wind provider. The marine service fires GFS warm at startup and on the 6-hour schedule when the marine service's `[nearshore]` pip extra is installed.

**Purpose:** Supplements HRRR wind (which reaches only 48 hours on extended cycles) to fill the 72-hour surf forecast card. GFS provides wind data for forecast hours 48–72. GFS is coarser than HRRR (0.25° / ~25km vs. HRRR's 3km), but the resolution transition at hour 48 does not affect SWAN's nearshore physics — wave refraction, shoaling, and breaking are computed at the SWAN grid resolution (200–500m), not the wind grid resolution.

**Data source (primary):** NOMADS Grib Filter at `https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl`. Supports geographic subsetting (bounding box), variable selection (UGRD/VGRD at 10m AGL), and GRIB2 output. Free, no API key.

**Data source (backup):** AWS S3 at `s3://noaa-gfs-bdp-pds/`. Same data, hosted by Amazon as a public dataset.

**Schedule:** GFS runs on a 6-hourly schedule (00Z, 06Z, 12Z, 18Z). Availability: ~3.5–4.5 hours after the nominal run hour (GFS takes longer to post than HRRR due to its global domain). Aligned with the SWAN extended HRRR cycle schedule.

**Forecast range:** GFS produces forecasts to 384 hours (16 days) at 3-hour timesteps (f00–f384). For SWAN, the wind gatherer fetches hours 48–108 (21 grids at 3-hour intervals, f048…f108; raised from f048–f072 to f084 in Z3.6, 2026-08-12, so the full-run window's far edge — HRRR cycle + 72 h — is always already held even though GFS's own cycle lags the HRRR extended cycle by at least one 6 h cadence step; to f096 at Q16.1, 2026-08-25, for the daily 96 h WW3 horizon march; to f108 at Q17, 2026-08-27, because the same one-step lag applies to the march — see §14.18 "Fetch depths extended"). The old inline manual-trigger path still fetches f048–f072 (gfs.py defaults unchanged). The SWAN runner interpolates 3-hourly GFS wind to hourly resolution to match the HRRR cadence.

**Extracted variables:**

| GRIB2 parameter | Variable | Description |
|---|---|---|
| UGRD:10 m above ground | U-component | East-west wind at 10m AGL |
| VGRD:10 m above ground | V-component | North-south wind at 10m AGL |

**Wind rotation:** GFS uses a regular latitude-longitude grid (0.25° spacing). Wind components are earth-relative by default — no rotation required (unlike HRRR's Lambert Conformal grid). Verify by checking the GRIB2 metadata `componentFlags` field.

**Bounding box:** Same as the HRRR bounding box for the marine location — configured per spot via the wizard SWAN grid bbox settings.

**Cache:** Key = `(provider_id, bbox_hash, cycle_time)`. TTL = 21600s (6 hours) — matches the GFS cycle cadence.

**Error handling:** 404 on all attempted cycles → `ProviderUnavailableError`. Network errors → canonical taxonomy. GRIB2 parse error → `ProviderProtocolError`. Required as of C-77 (2026-07-26, rules/coding.md §1 "A model runs on all its inputs or it does not run"): on GFS failure, the SWAN run aborts (raise, caught by the marine runner loop's retry-same-cycle handling) rather than publishing a forecast silently shortened to HRRR hours 0–48. Supersedes the prior "shortened forecast rather than no forecast" behavior.

**Rate limiting:** 2 req/s to NOMADS (shared NOAA infrastructure, same rate as HRRR).

### §14.17 SwellTrack — cross-shore wave transformation model

**Not a network provider.** Post-SWAN cross-shore wave transformation. Runs as a Python module within the API process (or via compute offloading to a remote service when `surf_compute_host` is configured) after SWAN output is parsed and SPECOUT is decomposed.

**Model selection (decided):** SwellTrack (analytical, pure Python — `surf_1d_analytical.py`). SWASH and XBeach are ruled out entirely — for production, LUT precomputation, and referee/benchmark use (1D-MODEL-BENCHMARK-BRIEF Round 2 results, 2026-07-21).

**Module:** `services/surf_1d_analytical.py`.

**Inputs:**
- Spectrum (from handoff SPECOUT decomposition) or bulk parameters (Hs, Tp, DIR) per partition
- CUDEM bathymetric profile per transect (3-5m resolution)
- Tide level (from CO-OPS predictions)
- Handoff depth per transect (from the pre-model handoff algorithm)

**Outputs per transect:**
- Hs at every 3-5m from handoff to shore
- Break point locations (list — multiple bars on multi-bar beaches)
- Breaker type per break point (Iribarren number: spilling/plunging/surging)
- Jacking factor per bar (Hs_bar_crest / Hs_approach)
- Surf zone widths (impact zone, foam zone, total surf zone, reform trough)
- Wave shape data (Stokes 2nd order / cnoidal / bore by depth regime)

**Per-partition pipeline:** Each swell partition is transformed independently through SwellTrack. At each transect point, combined Hs_total = sqrt(sum(Hs_partition_i²)). Combined depth-limited saturation check: Hs_total ≤ γd enforced after combination. If exceeded, Battjes-Janssen dissipation applied to total energy and redistributed proportionally across partitions.

**Bottom friction (always enabled):** cfjon=0.038 (swell, Tp ≥ 10s) or 0.067 (windsea, Tp < 10s). Implemented as cumulative exponential attenuation per the Battjes-Janssen (1978) formulation. Configured per-spot via `friction_coefficient` in `SurfSpotConfig` (default 0.038).

**Computational cost:** ~1ms per transect run. Full spot: 3 partitions × 30 transects × ~1ms = ~90ms. Negligible relative to SWAN runtime.

**Compute offloading:** When `surf_compute_host` is configured (in `api.conf [providers]`), SwellTrack runs on the remote compute service instead of in-process. Per-timestep granularity: `POST /compute/swelltrack` with one timestep's data, returns results in <500ms. Fallback to in-process when compute service unreachable.

**Error handling:** SwellTrack crash → log ERROR, fall back to SWAN CURVE data (legacy path). `degraded: true` in response. Partial failure: if SwellTrack fails on some transects, exclude those from aggregation but continue with remaining.

### §14.18 WW3 deep-water leg — WW3 as OUR model (as-built; ADR-109, CHAIN-SERVES round)

**Live — the only deep-water leg, at every location.** This subsection documents the WW3 deep-water leg's data-flow contract, fixed by ADR-109 and deployed 2026-08-19 (CHAIN-SERVES, operator order in chat). SWAN's own L1 compute (§14.15 above, ADR-108) was fully removed 2026-08-23 (marine `3c550ae`/`c29266d`) — there is no shadow mode, no legacy fallback path, and no per-location conditionality left: WW3 runs the deep-water leg and hands off to SWAN at L2 via BOUNDNEST3, for every location, always. ADR-108's geometry (island containment, the domain cap) is unchanged and now sizes WW3's grid instead of a SWAN L1 subprocess — the code/config label `level1` is a legacy geometry name, not a running SWAN level.

**What changed:** before ADR-109, Clear Skies consumed NOAA's own WW3 output at what was then SWAN's L1 boundary (§14.3, NOMADS `filter_gfswave.pl`). Under ADR-109, Clear Skies instead runs WW3 **6.07.1** (NOAA-EMC/WW3 source, LGPL v3) as our own process — the "deep-water leg" — for the offshore domain; NOAA's WW3 output now serves only as WW3's own boundary forcing (§14.3), not as the domain Clear Skies models directly. **Always-on, no per-site conditionality** (ADR-109 D1, Q1 ruled 2026-08-15). The per-location `ww3_chain_enabled` flag (CHAIN-SERVES D1) that used to gate consumption is now a no-op — the SWAN-L1 fallback it gated no longer exists in code; removal of the dead key is tracked as a follow-up.

**Inputs — boundary reconstruction reuse (no new construction math):**
- The existing per-cell parametric-spectra reconstruction (§14.3a/b Amendment above, ADR-104/ADR-106) is REUSED unchanged — spectral-construction constants (JONSWAP γ 3.3, cos²ˢ spreads s=28/s=7, adaptive σf rule, bin-sum identity guard) are untouched (ADR-109 PW4). It gains a new WW3-consumable OUTPUT PATH: one transfer-format file per boundary position (never multiple positions inside one file — ADR-109 trap 15/measured trap), spectrum block written **frequency-fastest** (ADR-109 D5 caveat/trap 21 — matches NOAA's own `ww3_outp.ftn` writer convention; a direction-fastest emitter silently scrambles every assembled spectrum, energy-sum preserved but shape/Hs corrupted), **and the direction axis + energy columns emitted in `ww3_outp`'s own bin ORDER and SENSE** — nautical going-TO 90° DESCENDING, first direction π/2 (ADR-109 D5 second caveat/trap 24, 2026-08-22: `ww3_bound` copies bins positionally and `W3IOBC` aligns on the first direction only, so an axis in the opposite sense is ingested mirrored about the N–S axis, FROM_model = 360° − FROM_file; `services/ww3_formats.py::_ww3_direction_bin_order`).
- Each boundary file is assembled by `ww3_bound` (ASCII assembly program, ADR-109 D5) into `nest.ww3`. A `nest.ww3` needs ≥2 time records bracketing the run — a single-record file self-disarms boundary forcing after its first application (ADR-109 trap 22, WW3 source-confirmed, not a fallback path to rely on).
- Wind: the assembled GFS/HRRR wind store, regridded onto the WW3 grid through `ww3_prep` (ASCII wind preprocessor, ADR-109 D7) → `wind.ww3`. Wind-only forcing at this leg (ADR-109 D9) — water level and currents stay SWAN-side, L2 down. WW3's forcing-field reader requires the wind file's grid dimensions to match the model grid EXACTLY (no automatic cross-resolution interpolation, ADR-109 trap 16) — each grid variant needs its own re-prepped wind file.

**Per-cycle run sequence (ADR-109 D12 + D13 Group 6):** wind prep (`ww3_prep`) → boundary assembly (`ww3_bound`) → `ww3_shel` march → handoff extraction (`ww3_outp`, which does NOT read stdin — it opens a file literally named `ww3_outp.inp` in the CWD, ADR-109 trap 12). `ww3_grid` (producing `mod_def.ww3`) runs ONLY on geometry/config change, not every cycle. Initial state per cycle is restart-file chaining (`restart.ww3`, WW3's native hotstart, ADR-109 D10) — a restart file initializes ONLY a run starting at its exact timestamp; WW3 refuses a mismatched restart in source (`w3iorsmd.ftn`, `EXTCDE(20)`, no fallback — ADR-109 trap 23), so the chaining design must emit each cycle's restart stamped at the next cycle's exact start time. Handoff to SWAN's L2 boundary is via **BOUNDNEST3** (ADR-109 D6, WW3-native SWAN command reading WW3's own transfer format — proven end-to-end against real production SWAN 41.51AB with zero boundary-read errors, ADR-109 D6 evidence).

**Binary pins (J24, 2026-08-27).** Before any step the runner hashes each `ww3_*` program and refuses `ww3_binaries_invalid` on a missing or mismatched pin. The expected values are NOT operator config: `scripts/deploy-marine.sh` generates `/etc/weewx-clearskies/marine/ww3-binaries.json` from the installed binaries on every deploy, and the marine config loader lays that file's `binary_dir`/`binary_sha256` over the pushed `ww3` block (which a config push may rewrite at any time). See OPERATIONS-MANUAL.md "Binary checksum pins" and ADR-109's J24 amendment.

**Refuse semantics — no silent fallback (PRIME DIRECTIVE 8):** a build/run failure on the WW3 leg refuses, never degrades to a fabricated or stale-but-unflagged boundary — the same refuse-not-degrade posture every input in this chain follows (rules/coding.md §1). The restart-chaining staleness gate is `WW3_RESTART_MAX_AGE_H = 9` (ADR-109 D11, by analogy to the legacy `L1_NEST_MAX_AGE_H` constant name — a proposed value, not a WW3-specific measurement; the name is now shared/repurposed as the WW3-chain archive staleness gate, marine `3c550ae`): when the WW3 leg's most recent restart exceeds this age, the WW3-leg cycle refuses to publish its artifacts and health reports the named reason (see OPERATIONS-MANUAL.md for the full monitoring-key list).

**Full parameterization catalog — pointer only, not duplicated here.** Every WW3 configuration input (switch-file physics-package selections, `ww3_grid.inp` namelist parameters, grid definition, the four deck time steps, spectral discretization, boundary placement/point spacing, obstruction-grid generation, wind regridding, nest-output point placement) traces to a derivation rule in **ADR-109 D13's embedded F5 parameterization catalog** — the full catalog, including the 7 catalog groups and the 23 measured hands-on traps, is the single source of truth (PRIME DIRECTIVE 11: no generic model setup; a deck line with no catalog row is a defect, not a default). Do not duplicate the catalog here — see ADR-109 D13 directly.

**Physics package:** P1 (ST6/FLX4 — ST6 is the wave-growth/decay physics package, FLX4 its paired wind-stress formulation; the same physics family as the existing SWAN deck's `GEN3 ST6 … AGROW`) — ADR-109 D4, the only candidate with real-ocean buoy validation (`scratch/F4-BUOY-VALIDATION-REPORT.md`: restart-chained G1×P1 matches NDBC 46253/46222 within 5–15% on Hs, direction within ±10–15°, period within ±3 s).

**G1 partially-land cells — fraction-based mask, FLAGTR=2 transparency field (S8.1-A, 2026-08-27; ADR-109 amendment, Proposed).** The G1 wet/dry mask (D3) used to classify every cell wet or dry from ONE ETOPO 2022 15" (~460 m) sample nearest its centre — a coastline cell was entirely wall or entirely pass on the luck of which sample sat there, over- or under-counting an island whose tip only partly covers a cell (operator direction 2026-08-27: "it should also apply to cells that are not 100 percent island"). `derive_ww3_setup()` (`services/swan_domain.py`) now accepts an optional `fine_dem` — a NOAA NCEI Coastal Relief Model (CRM) Vol. 6 cut (~90 m/3", `services/bathymetry_resolver.fetch_crm_grid()`, a second OPeNDAP THREDDS collection distinct from the existing `regional/` DEMs) fetched/cached once by `services/ww3_grid_files.fetch_or_load_g1_fine_dem()` as `/etc/weewx-clearskies/swan_bathymetry_G1_fine.npz`. When supplied, every G1 cell gets a real **open-water fraction** `f` (share of native-resolution fine samples inside the cell's footprint with elevation < 0, vectorised binning — never a Python loop over the fine source). A cell is DRY iff `f ≤ F_DRY` (named constant, `0.05`, Q10-2), WET otherwise, carrying transparency `τ = f`; the S-row/W-column active-boundary test reads the SAME fraction mask. `G1_bottom.txt` keeps the ETOPO nearest-sample depth for every cell EXCEPT one wet by fraction whose centre ETOPO sample is land — that cell's depth becomes the mean of the fine-DEM's own wet samples inside it (`services/ww3_grid_files.wet_mean_depth()`; refuses rather than fabricates a depth if none exist). The deck gains `&MISC FLAGTR = 2 /` and the obstruction read line (`   12 1.0 1 1 '(....)' 'NAME' 'G1_obstr.txt'` — unit 12, distinct from the bottom/status units) **between the bottom-depth read and the status-map read** (as-built correction 2026-08-27, marine `d7d8632`: the first production `ww3_grid` run refused rc=62 with the obstruction line after the status map, and `G1_obstr.txt` must carry TWO NX×NY maps — x- then y-direction, written identical — or `w3grid` fails `PREMATURE END OF FILE`; and — second correction, 2026-08-28 reality gate — the maps hold **fractional obstruction `1 − τ`** (manual :15931: "fractional obstructions", 0 = open water), NOT the transparency `τ`: written as `τ`, every open-water cell was a full wall and the first rebuilt-grid transfer carried exactly 0.0 m at every point for every hour; all pinned by `tests/services/test_s81_ww3_grid_live_grammar.py`); `services/ww3_grid_files.write_ww3_grid_name_files()` writes `G1_bottom.txt`/`G1_status.txt`/`G1_obstr.txt` (nothing wrote these files before this round). `fine_dem=None` (no fine DEM available) reproduces the pre-round derivation byte-identical — FLAGTR=0, no obstruction field. A fetch failure refuses the whole `ww3_leg` derivation for that cycle (no ETOPO substitution — ETOPO's ~5.6 samples/cell cannot meet the fraction field's accuracy target). **Round A does not run `ww3_grid` or touch `level0/mod_def.ww3`** — the production rebuild hook on geometry/config change is a separate round (S8.1-B, Gap G10). See ADR-109's "Amendment (2026-08-27): D3/D13 Group2 — G1 partially-land cells" for the full design and KAT record.

**Daily continuation march (Q16 Round A, 2026-08-25; ADR-109 amendment note) — the fix for the frozen-forecast defect.** Before this round, SWAN L2's 73-hour full run consumed the leg's 7-record (6 h) transfer as its offshore boundary for all 73 forecast hours, holding the +6 h ocean state frozen from hour 7 on (SWAN's own log: "data on boundary file exhausted," every cycle since 2026-08-19). Once daily at the **00Z** cycle, strictly AFTER that cycle's own 6 h leg and its production publish complete, WW3 marches **cycle+6 h → cycle+96 h** on the same G1 grid/binary/physics, starting from a **COPY** of the leg's own +6 h restart file (the leg's restart chain, D10, trap 23 stamping, is untouched — never consumed or diverted). 96 h, not 73: the worst-placed consumer cycle runs 24 h after the daily march, so covering all 72 forecast hours for every intervening cycle requires 24 + 72 = 96 h exact cover (Q16.1). Wall-clock ≈4 h at the standing D12 contention budget (`OMP_NUM_THREADS ≤ 4`, `nice 15`, never concurrent with a production full run); ceiling 6 h. Constants are fixed, not config keys: cycle 00Z, span 96 h, retention 2 (newest `level0/horizon_<token>/` directories kept). Failure-isolated: a horizon-march failure logs a named refusal and can never delay, block, or alter a production publish.

**NOAA cycle pin.** The horizon march re-fetches NOAA boundary data but is PINNED to the exact NOAA cycle the same day's 6 h leg used, persisted per cycle as `level0/boundary_cycle_<token>.txt`. Pin unavailable → named refusal `ww3_horizon_cycle_unpinned`; the pinned fetch makes exactly one attempt, no fallback ladder — an unpinned substitute NOAA cycle at the horizon march would reintroduce a physics discontinuity at the +6 h splice, the exact failure class this round closes. **The horizon march never re-derives a NOAA cycle independently of the leg** — it is always the leg's own cycle choice, carried forward. Implemented as additive `pinned_cycle` parameters through the fetch layer and the existing reconstruction entry point (pure forwarding); the default (unpinned) path is byte-identical, mutation-verified.

**Fetch depths extended (Q16.1; wind corrected Q17).** Boundary partition fields to **+99 h** (was 72); GFS far-window wind to **+108 h** (was 84; Q16.1 set 96, corrected to 108 by Q17, operator ruling 2026-08-27 "a": the wind gatherer holds the GFS run one 6 h step BEHIND the march's HRRR cycle when the march fires — NOAA posts the 00Z GFS +96 h file ~04:00Z, after the ~03:30Z march — so +96 h reached only cycle+90 h and the march refused `ww3_horizon_wind_short` on every attempt; +108 h covers cycle+96 h under a two-step lag, +4 GRIB2 files per GFS cycle, 17 → 21), at GFS's own native 3-hourly cadence — no interpolation code of ours added anywhere; WW3 interpolates forcing internally (manual-cited: `docs/reference/ww3-user-manual-v6.07.txt` :8211, :10155–159, :14405–409). Per-cycle fetch cost: 25 → 34 GRIB2 files (**+36%**), uniformly across all cycles (the leg's own fetch depth grows too, to stay one fetch path — not just the 00Z long-march cycle). Great-Lakes product depth deliberately NOT extended (unused at this deployment).

**Merged boundary transfer (the delivery mechanism for the march above — no change inside SWAN itself).** Each full cycle stages ONE BOUNDNEST3 transfer file for SWAN L2: the cycle's own 6 h leg records for hours 0–6, the newest horizon march's records for hours 7–72. Byte-preserving splice; header/axis/point-list must be byte-identical between the two sources or the merge refuses loudly. No horizon file (or short coverage) → stage the nowcast file alone with one WARNING (`ww3_horizon_short`) — never a crashed cycle. Hourly fill cycles (CHAIN-SERVES D8's hourly-substitution design) inherit the staged (merged) file unchanged — no new mechanism at that seam.

**Health surfaces.** New top-level `ww3Horizon` block (`lastSuccessCycleTime`, `coverageEndTime`, `wallClockS`, `refuseReason`) and new `fullRun.l2BoundaryExhausted` boolean: a detector scans SWAN L2's PRINT output every run for the "data on boundary file exhausted" warning and surfaces it (one WARNING log line + the health boolean, FALSE=healthy, TRUE=a regression signal). See OPERATIONS-MANUAL.md for the full monitoring-key list.

**New artifacts + retention.** `level0/horizon_<token>/` (retention: newest 2), `level0/hstage_<token>/` (merge staging), `level0/boundary_cycle_<token>.txt` (the NOAA cycle pin above) — additive to ADR-109 D12's `level0/` layout. Disk: horizon transfer output runs to hundreds of MB/day, retention-bounded (394 GB free measured at implementation time).

**UNCHANGED by this round:** the 6 h leg and its restart chaining (trap-23 stamping), all deck grammar (builder bodies zero-diff), SWAN physics/decks, the 1-D pipeline, scoring, boundary_reconstruction physics (a 9-line signature-only diff), and `get_wind_series()`'s strict contract. See ADR-109's amendment note for the full ruling record.

### §14.19 Swell-card deep-water reference points (Q16 Round B, 2026-08-25)

**What this is.** The swell display card's catalog (`multiSwell`, `swellHeight`, `swellHeightMinFt`/`MaxFt`, `periodMinS`/`MaxS`, `spectralComponents`) is now sourced primarily from watershed partitions of the WW3 deep-water leg's own spectra (§14.18), read at a small fan of **deep-water reference points** — deep water (≥ 200 m), post-island-shadowing, PRE-refraction (the industry-convention, Surfline-style deep-water swell reading). The 15 m SWAN L2 deep-water-reference table described in §14.15's "Multi-SPECOUT extraction" above is unchanged and keeps every job it had except naming the card's swells — see "Fallback" below. **NOT changed by this round:** the 1-D surf pipeline's `canonical_partitions`, `score_surf()`'s cross-swell input, SwellTrack, `perPartitionBreaks`, the 15 m DWR SPECOUT/TABLE outputs, and all surf-score scoring criteria — all still read the 15 m machinery exactly as §14.15/§14.17 describe.

**Derivation rule (grid-sizing time, once — never per cycle).** Reference points are computed exactly once, when a spot's grid sizing runs (config push or geometry change), never recomputed per forecast cycle. From the spot's 15 m anchor (§14.15's `_compute_15m_point()`), rays are cast across the spot's open-water exposure window (`open_water_bearing_deg` ± 90°, 5° sampling — §14 ⚙ GEOMETRY MODEL's fetch-fan machinery). Each ray's reference point is the first crossing of **≥ 200 m depth** (deep water for a 16 s swell — half its wavelength). Land-blocked ray directions are excluded. A shadow-edge guardrail requires the point's perpendicular neighbors to also be wet, pushing the point farther seaward when it sits too close to an island-shadow boundary; a point failing this test is kept with `guardrail_unmet: true` rather than dropped. Points are deduplicated to the WW3 G1 grid's own cells and merged within 3 km of each other, with direction coverage across the exposure window preserved by assertion after the merge. Real Huntington geometry produces **8 points**. Derivation failure (e.g. no ray reaches 200 m) logs **ERROR** and the persisted block is omitted for that spot — nothing else in the sizing chain breaks.

**Persisted schema.** A new block `deep_reference_points` is written to `swan_grid_sizing.json`, sibling to the existing `ww3_leg` block: a list of `{name, lat, lon, depth_m, dir_window_deg, guardrail_unmet}` entries, one per surviving reference point.

**WW3 deck output points.** Each persisted reference point becomes a Type-2 point output in the existing `ww3_shel` deck (§14.18), named `DREF00`, `DREF01`, … (bare names, no `B` prefix — distinct from the existing buoy co-location points `B46222`/`B46253` and the `L2P*` boundary-handoff points already in that deck). An absent `deep_reference_points` block (derivation failure, or a spot sized before this round) logs one **WARNING** and the deck is emitted byte-identical to its pre-round form — no `DREF*` lines.

**Catalog build, per hour.** Each `DREF*` point's WW3 spectrum is partitioned with the same watershed method already in use (§14.15's Hanson & Phillips PT* mechanism). `multiSwell` is built by taking each swell train from the reference point whose position best aligns with that train's arrival direction (within ±25°) — one point per swell, never averaged across points. Where the same physical train shows up at more than one reference point (period within ±15%, direction within ±20%), the trains are merged and the better-aligned point's reading wins. **DREF-MERGE-FIX (2026-08-26, marine `6abb831`):** BEFORE that cross-point merge, fragments of one swell that the watershed partitioner split at a SINGLE point are recombined energy-conserving (height = sqrt(sum of squared heights), energy-weighted period/direction, unioned frequency range) — the cross-point better-aligned-wins rule is unchanged and operates on the recombined trains. Previously the best-aligned single fragment's height was published alone, silently dropping the rest of that swell's energy (live case 2026-08-26 21Z: served 0.09 m for a ~15 s W swell whose recombined height is 0.26 m; buoy 46222 measured 0.24 m in that band).

**Fallback — hours the WW3 transfer does not cover.** Forecast hours beyond the WW3 leg's current transfer horizon (today: beyond ~+6 h; narrows as Round A's full-horizon march lands, §14.18) are not read from the `DREF*` points at all — those hours keep the prior source, the SWAN watershed table at the 15 m DWR point (§14.15), with byte-identical behavior to pre-round for those hours.

**New response field `forecast[].swellSource`.** Additive field, values `"deep_reference" | "nearshore_table" | null`, one per forecast timestep, naming which of the two sources above produced that hour's `multiSwell`.

**`multiSwell[].frequencyRange` now populated.** On the deep-reference path, the field carries the partition's real frequency band (Hz) rather than the `[0.0, 0.0]` placeholder §14.15 documents for the SWAN-TABLE-sourced path (TABLE's bulk PT* output carries no per-partition frequency-bin bounds, so `[0.0, 0.0]` is unchanged on the `nearshore_table` fallback path).

### Source ADRs

§14 consolidates prescriptive rules from: ADR-083 (marine domain architecture), ADR-084 (NWPS supplementation — superseded by ADR-093), ADR-085 (eccodes dependency), ADR-087 (NDBC spectral data), ADR-088 (fishing scoring — bathymetry for habitat), ADR-089 (marine zone alerts), ADR-091 (marine card data sources, OFS ocean data, composite water level), ADR-093 (SWAN + SwellTrack replaces NWPS — amended for multi-transect, SurfBeat, compute offloading), ADR-094 (HRRR wind source for surf scoring), ADR-095 (SWAN model corrections — amended for multi-SPECOUT + SwellTrack break points), ADR-096 (scoring restructure — amended for multi-transect inputs), ADR-097 (beach profile — amended for SwellTrack; the "blended SurfBeat output" amendment was REVERSED 2026-08-23 by operator ruling — the profile is SwellTrack only). ADRs are archived in `docs/archive/decisions/` and explain the *why* behind these rules.

---

## §15 Marine Service Provider Architecture (target — pending ADR-099 acceptance)

This section documents the target-state provider architecture for the standalone marine service (`weewx-clearskies-marine`). It describes how the provider modules listed in §14 move from the API codebase into the marine service, and what the boundary between the two services looks like after the separation.

**Current state:** All provider modules in §14 (`ndbc`, `coops`, `wavewatch`, `nws_marine`, `nws_srf`, `hrrr`, `gfs`, `ofs`, `erddap_ocean`, `swan`), all supporting components (bathymetry resolver, NWS zone discovery, ocean data resolver, water level compositor, SwellTrack; SurfBeat removed 2026-08-23), and all DOMAIN registrations (`"marine"`, `"tides"`, `"buoy"`, `"wind"`, `"nearshore"`, `"ocean"`) live inside `weewx_clearskies_api/`. The `PROVIDER_MODULES` registry in the API dispatches to them.

**Target state:** The modules and components listed above move to `weewx_clearskies_marine/`. The API's `PROVIDER_MODULES` registry has zero marine entries. The API never directly imports any marine provider module. All marine data flows through the HTTP interface described in API-MANUAL §19.

### §15.1 Provider modules that move to the marine service

The following modules (currently in `weewx_clearskies_api/providers/`) become internal to `weewx_clearskies_marine/providers/` and are no longer registered in the API's dispatch registry:

| Module | Current API path | Marine service path | Domain |
|--------|-----------------|---------------------|--------|
| NDBC buoy observations | `providers/buoy/ndbc.py` | `providers/buoy/ndbc.py` | `buoy` |
| CO-OPS tides & water levels | `providers/tides/coops.py` | `providers/tides/coops.py` | `tides` |
| WaveWatch III forecasts | `providers/marine/wavewatch.py` | `providers/marine/wavewatch.py` | `marine` |
| NWS marine zone text | `providers/marine/nws_marine.py` | `providers/marine/nws_marine.py` | `marine` |
| NWS Surf Zone Forecast (SRF) | `providers/marine/nws_srf.py` | `providers/marine/nws_srf.py` | `marine` |
| HRRR wind | `providers/wind/hrrr.py` | `providers/wind/hrrr.py` | `wind` |
| GFS wind | `providers/wind/gfs.py` | `providers/wind/gfs.py` | `wind` |
| SWAN runner | `providers/nearshore/swan.py` | `providers/nearshore/swan.py` | `nearshore` |
| OFS ocean model data | `providers/ocean/ofs.py` | `providers/ocean/ofs.py` | `ocean` |
| ERDDAP ocean data | `providers/ocean/erddap_ocean.py` | `providers/ocean/erddap_ocean.py` | `ocean` |

Supporting components that also move:

| Component | Current API path | Notes |
|-----------|-----------------|-------|
| CUDEM bathymetry | `enrichment/bathymetry.py` | Profile extraction for surf/fishing spots |
| Bathymetry resolver | `services/bathymetry_resolver.py` | 2-D grid resolution for SWAN (moved — Phase 7, C-48) |
| NWS zone discovery utility | `providers/_common/nws_zones.py` | Shared by nws_marine and nws_srf |
| Ocean data resolver | `services/ocean_data_resolver.py` | OFS → ERDDAP fallback chain |
| Water level compositor | `services/water_level_compositor.py` | CO-OPS predictions + OFS residual |
| SWAN runner service | `services/swan_runner.py` | Three-level nested SWAN execution |
| SwellTrack | `services/surf_1d_analytical.py` | Cross-shore wave transformation |
| SurfBeat strip | REMOVED 2026-08-23 (operator ruling) | — |
| Wave setup service | `services/wave_setup.py` | Radiation-stress-balance setup estimate |
| OSM Overpass structure discovery | `endpoints/setup.py` (setup-time only) | Remains callable via API `/setup/marine/discover-structures` proxy |

### §15.2 The §1 Module Contract applies unchanged

Every provider module in the marine service follows the same §1 Module Contract as API provider modules: one module per provider per domain, CAPABILITY declaration, `fetch()` interface, canonical field mapping, canonical error taxonomy, `ProviderHTTPClient` for all outbound HTTP calls. Nothing in §14 changes except the location where these modules run.

**Internal registry:** The marine service maintains its own `MARINE_PROVIDER_MODULES` dispatch registry. It is structurally identical to the API's `PROVIDER_MODULES` registry but contains only marine modules. It is not visible to the API and is not part of the capabilities API response. Marine capabilities appear in `/api/v1/capabilities` only as entries merged from the manifest (see API-MANUAL §19.4) — not from the API's own registry.

**Same caching rules:** Cache TTLs, cache key construction, and the pluggable cache backend (ADR-017) apply unchanged inside the marine service. The marine service runs its own cache instance (Redis or in-memory) independent of the API's cache.

**Same error taxonomy:** The closed set of canonical error types (§10) applies to marine provider modules. The marine service translates these errors into appropriate HTTP responses when returning data to the API proxy handler.

### §15.3 Data sources fetched directly by the marine service

In the target state, the marine service makes all outbound data fetches listed below. The API never fetches from these sources directly:

| Data source | Provider module | Protocol | Auth required |
|-------------|----------------|----------|---------------|
| NOAA NDBC (buoy flat files) | `ndbc` | HTTPS flat files | No |
| NOAA CO-OPS (tides, water levels) | `coops` | HTTPS REST JSON | No |
| NOAA NWS API (marine zone text, SRF) | `nws_marine`, `nws_srf` | HTTPS REST + text products | No |
| NOAA HRRR (wind GRIB2 via NOMADS) | `hrrr` | HTTPS or S3 | No |
| NOAA GFS (wind GRIB2 via NOMADS) | `gfs` | HTTPS or S3 | No |
| NOAA WaveWatch III (via ERDDAP/PacIOOS) | `wavewatch` | HTTPS ERDDAP griddap JSON | No |
| NOAA OFS (ocean currents, temp via THREDDS/OPeNDAP) | `ofs` | OPeNDAP/xarray | No |
| ERDDAP ocean datasets (MUR SST, RTOFS, PacIOOS, CARICOOS) | `erddap_ocean` | HTTPS ERDDAP griddap JSON | No |
| NCEI coastal DEMs (bathymetry) | bathymetry resolver | HTTPS OPeNDAP/xarray | No |
| USGS Great Lakes DEMs (bathymetry) | bathymetry resolver | HTTPS GeoTIFF | No |
| NCEI CRM fallback (bathymetry) | bathymetry resolver | HTTPS ArcGIS ImageServer | No |
| OpenStreetMap Overpass (structure discovery) | setup-time utility | HTTPS POST | No |
| SWAN subprocess (local) | swan runner | Local subprocess | N/A |

All v1 marine data sources are NOAA sources — free, keyless, US-only (except ERDDAP RTOFS and MUR SST which are global). No operator-supplied API keys are required for any marine data source.

### §15.4 What remains in the API after separation

The following marine-adjacent components are NOT moved to the marine service:

| Component | Stays in API | Reason |
|-----------|-------------|--------|
| Marine zone alerts (NWS coastal flood, high surf, rip current) | Yes | Unified alert system; cannot be split (see API-MANUAL §19.6) |
| Marine location config storage (`api.conf [marine]`) | Yes | Single source of truth for operator config |
| Marine location setup endpoints (`/setup/marine/*`) | Yes | Wizard-facing endpoints; API validates and pushes config to marine service |
| `/api/v1/capabilities` marine capability entries | Yes (merged from manifest) | API owns the capabilities endpoint; marine entries arrive via manifest |
| Marine endpoint proxy handlers | Yes | Thin HTTP proxy; no marine domain logic |
| `GET /api/v1/marine` list route | Yes | Location list aggregation stays in API |
| Alert rate limiting and deduplication | Yes | Alert system is unified; all providers run in API process |

### §15.5 Module authoring in the marine service

New marine provider modules are written in `weewx_clearskies_marine/providers/` following the same §1 module contract. The marine service's `MARINE_PROVIDER_MODULES` registry is populated at import time exactly as the API's registry is. To add a new marine data source:

1. Write the provider module in `providers/{domain}/{provider_id}.py` inside `weewx_clearskies-marine`.
2. Register it in `MARINE_PROVIDER_MODULES`.
3. Add its endpoint(s) to `GET /manifest`.
4. Restart the marine service.

No changes to the API codebase are required. The API dynamically picks up the new endpoint from the updated manifest on the next `/setup/apply` call or on API restart.

### §15.6 Provider attribution in the marine service

The marine service declares attribution for each provider module in its own CAPABILITY objects (same `ProviderAttribution` dataclass shape as §12). The marine service includes attribution data in its manifest (`/manifest` → `capabilities[].attribution`). The API merges these into the capabilities response so the dashboard's About page and in-context card footers receive attribution data for marine providers via the same channel as non-marine providers.

All NOAA marine data sources are public domain — attribution is recommended but not mandated by the data provider. Attribution is still included in CAPABILITY declarations as `attributionRequired = false` with the NOAA credit text, so it renders on the About page.

### Source ADR

§15 is governed by ADR-099 (marine service separation — pending user acceptance as of 2026-07-22). The module-level implementation details (fetch interfaces, error taxonomy, cache rules, test patterns) are unchanged from §14 and continue to be governed by the ADRs listed in §14's "Source ADRs" section.

---

## §16 Imagery Providers — removed 2026-08-27 (Q10-6)

The orthophoto/map imagery providers (`naip`, `esri`, `esri_topo`) and their selection machinery
(`[imagery]` config, the `/imagery/tiles` proxy, the admin section, the wizard selector) were
removed entirely — operator ruling, plan Q10-6, 2026-08-27: "if we dont need it then get rid of
it." Nothing user-facing had read the `[imagery]` provider since SURF-MAP-BASEMAP (PA9, Q5, §M4)
made `/imagery/config` always answer the product basemap. See API-MANUAL §12a for the surviving
`/imagery/config` endpoint (unchanged) and §12b for the product basemap it now serves.
