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
├── buoy/            # Buoy domain modules (§14): ndbc
├── wind/            # Wind domain modules (§14): hrrr ([nearshore] extra)
└── nearshore/       # Nearshore domain modules (§14): swan ([nearshore] extra)
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

## §9a Geographic Features (ADR-078)

### Data source

OpenStreetMap via PMTiles vector tiles. PMTiles is a single-file archive of pre-processed, zoom-level-simplified vector tiles. The browser loads only the tiles visible in the current viewport via HTTP Range requests — typically 20-50 KB per tile. Geometry is pre-simplified per zoom level (coarse at zoom 5, detailed at zoom 12). Data license: ODbL (OpenStreetMap contributors).

| Property | Value |
|---|---|
| Format | PMTiles v3 (vector tiles) |
| Data source | Protomaps daily builds (`https://build.protomaps.com/YYYYMMDD.pmtiles`) |
| Auth | None (public download) |
| License | ODbL — attribution required |
| File location | `/etc/weewx-clearskies/geographic-features.pmtiles` |
| Update mechanism | Operator-triggered via admin UI (`POST /setup/geographic-features/update`) |
| Extraction tool | Go `pmtiles` CLI (`go-pmtiles`) — BBOX extraction with maxzoom limit |

### What gets rendered

Three feature types from the Protomaps basemap layers, rendered as unfilled lines only:

| Feature type | PMTiles layer | Filter | Line style |
|---|---|---|---|
| Political boundaries | `boundaries` | All (country + state/region) | White, weight 1.5, opacity 0.7 |
| Major roads | `roads` | `pmap:kind` in `highway`, `trunk` | Gray, weight 1, opacity 0.5 |
| Water features | `water` | All (rivers, lakes, ocean) | Blue, weight 1, opacity 0.6 |

### Data pipeline

The PMTiles file is created in two steps, both triggered by the admin's "Update Map Data" action:

1. **Download:** The API's setup endpoint downloads the latest Protomaps daily build PMTiles file. The Go `pmtiles extract` command reads only the byte ranges needed for the operator's BBOX — it does NOT download the full planet file (~120 GB).
2. **Extract:** `pmtiles extract <remote-url> <output> --bbox=<west,south,east,north> --maxzoom=<N>` crops to the operator's configured bounds and zoom limit. Result written to `/etc/weewx-clearskies/geographic-features.pmtiles`.

Expected extract size: 200-500 MB for a 14°×24° regional BBOX at maxzoom 12.

### Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/v1/geographic-features/tiles` | GET | Serves PMTiles file with HTTP Range request support (206 Partial Content). Returns 404 when file not yet downloaded. Public, no auth. |
| `/api/v1/geographic-features/status` | GET | Returns `{available: bool, size_bytes: int|null, updated_at: str|null}`. Public. |
| `/setup/geographic-features/update` | POST | Downloads latest Protomaps build, extracts to operator BBOX, stores result. Auth: proxy secret. |

### Config

`[geographic_features]` section in `api.conf`:

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | bool | `true` | Whether geographic features are available |
| `bounds` | str | None | CSV BBOX for extraction (`west,south,east,north`). Falls back to LibreWxR bounds if unset. |

### Not a provider module

Geographic features are NOT a provider module (no capability declaration, no dispatch registry entry, no `PROVIDER_MODULES` entry). PMTiles is a utility data source, similar to the GEM Active Faults file — not a switchable provider. The service is wired directly in `__main__.py` like the faults service.

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
1. **Offshore reference data** — swell propagation is large-scale; offshore spectral data accurately represents the swell systems arriving at the coast. Returned in the surf response as `spectralComponents` for operators and third-party consumers. **Not used for scoring or multiSwell display** — the surf score and multiSwell use SWAN SPECOUT at ~10m depth instead (ADR-096).
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

**Cache:** Key = `(provider_id, station_id, file_type)`. TTL = 60 min for all three file types. Station discovery (`activestations.xml`) cached 24 hr.

**Error handling:** HTTP 404 for non-existent station → `ProviderProtocolError`. Empty file body → log WARNING, return empty observation (not error). Network errors → canonical taxonomy via `ProviderHTTPClient`.

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

**CAPABILITY:** `geographic_coverage = "global"` (excludes waters south of -77.5°S), `auth_required = []`. `supplied_canonical_fields` includes wave height, peak period, peak direction, wind wave height/period/direction, swell height/period/direction. Does **not** supply true 10m wind speed/direction — see below.

**Wire format and parsing:**

ERDDAP JSON access (NOT GRIB). Construct griddap URL (live-verified 2026-07-11):

```
https://pae-paha.pacioos.hawaii.edu/erddap/griddap/ww3_global.json?{var1}[({time_start}):3:({time_end})][(0.0)][({lat_nearest})][({lon_nearest})],{var2}[...]...
```

Each requested variable needs its own `[time][depth][lat][lon]` bracket-subset suffix — a bare comma-separated variable list sharing one trailing subset returns an ERDDAP 500 error. The dataset has a `depth` dimension fixed at a single surface value; `[(0.0)]` selects it. Native time resolution is hourly; a stride of `3` in the time bracket (`[(t0):3:(t1)]`) recovers 3-hour forecast steps. Longitude on this server is 0..360, not -180..180 — convert (`lon + 360` when `lon < 0`) before building the URL; the response echoes back the converted value.

**Server note:** NOAA CoastWatch's ERDDAP (`coastwatch.pfeg.noaa.gov`) also lists this dataset (as `NWW3_Global_Best`), but it is a mirror alias that 302-redirects to the origin above — `ProviderHTTPClient` disables redirect-following by default (security-baseline), so the module queries the origin server directly. Do not switch back to the CoastWatch alias without adding redirect support.

Variables (all 9 are `[time][depth][latitude][longitude]`): `Thgt` (significant wave height), `Tper` (peak period), `Tdir` (peak direction), `whgt` (wind wave height), `wper` (wind wave period), `wdir` (wind wave direction — this server's `wdir` is the wind-driven-wave direction, not true 10m wind direction), `shgt` (swell height), `sper` (swell period), `sdir` (swell direction).

**Grid selection logic:** Single global grid — the reachable ERDDAP servers (CoastWatch and its PacIOOS origin) host only one WaveWatch III dataset; no regional US-coast/Alaska/Pacific subsets exist (the originally documented `erddap.aoml.noaa.gov` 7-grid table was never live-verified and was found completely unreachable):

| Grid dataset | Coverage | Resolution | Priority |
|---|---|---|---|
| `ww3_global` | Global (lat -77.5..77.5) | 0.5° | 1 |

**Forecast extraction:** 72-hour forecast at 3-hour steps (25 timesteps). Each timestep maps to a `MarineForecastPoint` canonical model. Model run cycle determination: current UTC hour minus 4.5-hour data availability delay → most recent cycle from {00, 06, 12, 18}. Fall back to 3 previous cycles if the current cycle is unavailable.

**Cache:** TTL = 30 min. Key = `(provider_id, grid_id, lat_rounded, lon_rounded)` where lat/lon are rounded to grid resolution (0.5°, pre-conversion to the 0..360 wire convention).

**Error handling:** ERDDAP returns HTTP 404 for invalid grid/variable combinations, 500 for backend failures. Both → canonical taxonomy. Empty response (no data for time range) → log WARNING, return empty forecast.

**Rate limiting:** 2 req/s (ERDDAP is a shared resource).

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

**Not a dispatch-registered provider module.** Bathymetry is accessed through two components: `services/bathymetry_resolver.py` (2-D grid resolution for SWAN) and `enrichment/bathymetry.py` (1-D profile extraction for surf/fishing spots). Both run at SWAN run time, not per-request.

#### Data source priority chain

The bathymetry resolver (`services/bathymetry_resolver.py`) selects the highest-resolution available data source for each SWAN grid level:

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

#### Vertical datum normalization

SWAN expects depth relative to MSL (Mean Sea Level). NCEI regional DEMs use different datums (NAVD88, MHW, MHHW, MLLW). The offsets between datums are spatially varying — a constant regional offset is wrong.

**VDatum REST API:** `_query_vdatum_offset()` queries `https://vdatum.noaa.gov/vdatumweb/api/convert` to get the MSL offset at the grid center. No API key required. Rate limit: 1 req/s. Result cached per (rounded lat, rounded lon, datum).

| Location | NAVD88→MSL offset | Impact on 2m depth |
|----------|------------------|--------------------|
| San Diego | -0.764m | 38% depth error |
| Sandy Hook NJ | +0.073m | 3.7% depth error |

On VDatum API failure: 0.0m offset applied with a warning log. The SWAN run proceeds with potentially biased bathymetry rather than failing entirely.

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

**Cache:** `get_cache()` (ADR-017 pluggable memory/Redis backend), TTL = 86400s (24h) — coastal structures rarely change. Key = hash of `(provider_id="overpass", endpoint="structure_discovery", {lat4, lon4, radius_m})`, same construction as §14.8's cache keys (lat/lon rounded to 4 decimal places per §3 "Cache key construction" — not the 3-decimal-place grouping originally sketched for this endpoint in the round brief; superseded to match the one established convention used everywhere else in this codebase).

**Rate limiting:** 1 req/s "be polite" guard against the free, shared `overpass-api.de` instance (`RateLimiter(name="overpass-structures", ...)`) — this is a setup-time-only endpoint, called once per surf spot then cached 24h, so the limit never trips in normal use.

**Error handling:** Any canonical `ProviderError` from the Overpass call (timeout, quota, 5xx after `ProviderHTTPClient` retries, unexpected response shape) is caught in the endpoint handler and returns HTTP 200 with an empty `structures` list and an `error` string populated — never a 500, and the failed lookup is not cached, so the next call retries live. Mirrors §14.7 bathymetry's "best-effort setup-time convenience" pattern: an Overpass outage does not block the wizard, the operator can still add structures manually.

### §14.10 NOAA OFS ocean model data (ADR-091)

**Module identity:** `providers/ocean/ofs.py`, `PROVIDER_ID = "ofs"`, `DOMAIN = "ocean"`.

**CAPABILITY:** `geographic_coverage = "us_coastal"` (major coasts — see coverage table below), `auth_required = []`. Supplies: water temperature (full column), salinity (full column), ocean currents (u/v components, full column), sea surface elevation (vs MSL and MLLW), seafloor depth, forecast time series. New dependency: `xarray` + `netCDF4` in the `[marine]` pip extra.

**Data source:** NOAA Operational Forecast Systems — 15 physics-based coastal ocean models (ROMS, FVCOM) at 34m–4km resolution, served via THREDDS/OPeNDAP at `opendap.co-ops.nos.noaa.gov/thredds/`. Updated 1–4 times daily depending on the model. Full research, verified OPeNDAP metadata, grid structure details, and code examples in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"Technical Detail: THREDDS/OPeNDAP Data Extraction".

**OFS models covered:** WCOFS (US West Coast, ~4km), GOMOFS (Gulf of Maine, ~700m), CBOFS (Chesapeake Bay, 34m–4.9km), DBOFS (Delaware Bay, 100m–3km), TBOFS (Tampa Bay, 100m–1.2km), CIOFS (Cook Inlet, 10m–3.5km), SFBOFS (San Francisco Bay, 10m–3.9km), NGOFS2 (Northern Gulf of Mexico, 45m–300m), SSCOFS (Salish Sea + Columbia River, 100m–10km), LMHOFS (Lake Michigan + Huron), LEOFS (Lake Erie), LOOFS (Lake Ontario), LSOFS (Lake Superior), NYOFS (Port of NY/NJ), SJROFS (St. Johns River FL). Full coverage and gap analysis in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md`.

**Key implementation rules:**
- Always use `regulargrid` files (pre-interpolated to regular lat/lon). Never use native `fields` files (curvilinear/unstructured grids requiring spatial interpolation).
- Grid point lookup: `Latitude` and `Longitude` are 2D arrays `[ny, nx]`. Use Euclidean distance with land mask filtering — `ds.sel()` does not work on 2D coordinate arrays.
- Cache grid coordinates per model (lat, lon, depth, mask, h arrays). TTL = 24h.
- Cycle selection: `floor(current_utc_hour / 6) * 6` for 4x/day models, fixed cycle for 1x/day (WCOFS = 03z). Fall back up to 4 cycles.
- Variables extracted at the nearest water grid point: `temp`, `salt`, `u_eastward`, `v_northward` (all `[time, Depth, ny, nx]`), `zeta`, `zetatomllw` (`[time, ny, nx]`), `h`, `mask` (`[ny, nx]`).

**Cache:** Key includes model name + cycle + lat/lon (rounded to 3 decimals). TTL = 1800s.

**Error handling:** THREDDS 404 → cycle fallback. Timeout (>10s) → `TransientNetworkError`. Grid point on land → null result. All per error taxonomy.

**Implementation details (from code, 2026-07-13):**

- `fetch(*, model: str, lat: float, lon: float) -> dict` — primary entry point. Returns dict with `source`, `surface_temp`, `column_profile`, `surface_current_speed`, `surface_current_dir`, `salinity`, `water_level_msl`, `water_level_mllw`, `seafloor_depth`. Returns `{"source": "unavailable"}` on total failure.
- `find_ofs_model(lat: float, lon: float) -> tuple[str | None, str | None]` — returns `(primary, fallback)` by checking `OFS_DOMAINS` bounding boxes. When domains overlap, sorts by `_MODEL_RESOLUTION_DEG` (smallest first) and returns the two highest-resolution matches.
- `_get_grid(model: str)` — fetches and caches lat/lon/depth/mask/h arrays per model. Cache key: `ofs:grid:{model}`, TTL 86400s.
- `_find_nearest_water_point(lat_grid, lon_grid, mask, lat, lon)` — Euclidean `sqrt((lat_grid - lat)² + (lon_grid - lon)²)`, masks land cells (`mask == 0`), rejects if minimum distance > 0.5°.
- `_extract_data(ds, ny, nx, depth_levels)` — pulls `temp`, `salt`, `u_eastward`, `v_northward`, `zeta`, `zetatomllw`, `h` via xarray indexing.
- `_select_cycle(model, now_utc)` — walks back up to 48 hours in 6-hour steps. Returns the most recent valid cycle. 1x/day models (WCOFS) use fixed cycle (03z).
- Result cache key: `ofs:{model}:{lat:.3f}:{lon:.3f}`, TTL 1800s.
- Grid cache key: `ofs:grid:{model}`, TTL 86400s (grid topology is static).
- Constants: `_RESULT_CACHE_TTL = 1800`, `_GRID_CACHE_TTL = 86400`, `_MAX_CYCLE_FALLBACKS = 3`, `_DATASET_TIMEOUT = 20` seconds.

### §14.11 ERDDAP ocean data (ADR-091)

**Module identity:** `providers/ocean/erddap_ocean.py`, `PROVIDER_ID = "erddap_ocean"`, `DOMAIN = "ocean"`.

**CAPABILITY:** `geographic_coverage = "global"`, `auth_required = []`. Config-driven module that handles multiple ERDDAP datasets through a single interface.

**Datasets:**

| Dataset key | Server | Dataset ID | Content | Depth | Lon convention |
|---|---|---|---|---|---|
| `mur_sst` | coastwatch.pfeg.noaa.gov | `jplMURSST41` | Surface temp only (1km, global, daily) | Surface | -180/+180 |
| `rtofs_3d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG3DForeDaily` | Temp column + currents + salinity (8km, global, 41 levels, 8-day forecast) | 41 levels | 0–360 |
| `rtofs_2d` | coastwatch.pfeg.noaa.gov | `ncepRtofsG2DFore3hrlyProg` | Surface SST (8km, global, 3-hourly) | Surface | 0–360 |
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

### §14.14 HRRR wind provider (ADR-093, ADR-094)

**Module identity:** `providers/wind/hrrr.py`, `PROVIDER_ID = "hrrr"`, `DOMAIN = "wind"`.

**CAPABILITY:** `geographic_coverage = "us"`, `auth_required = []`. `supplied_canonical_fields` includes U-component and V-component of wind at 10m above ground level, earth-relative.

**Availability:** Active only when the `[nearshore]` pip extra is installed. Not part of the standard provider registry startup — invoked by the SWAN runner (`services/swan_runner.py`), not by the cache warmer directly. The cache warmer fires HRRR warm at startup and on the extended cycle schedule (4×/day at 00/06/12/18Z) when `[nearshore]` is installed.

**Data source (primary):** NOMADS Grib Filter at `https://nomads.ncep.noaa.gov/cgi-bin/filter_hrrr_2d.pl`. Supports geographic subsetting (bounding box), variable selection (UGRD/VGRD at 10m AGL), and GRIB2 output. Free, no API key.

**Data source (backup):** AWS S3 at `s3://noaa-hrrr-bdp-pds/`. Same data, hosted by Amazon as a public dataset.

**Schedule:** HRRR runs on a fixed hourly schedule (00Z through 23Z). Availability: ~45–60 minutes after the nominal run hour. Completely predictable — no dependency on human forecaster input.

**Forecast range limitation:** HRRR does not produce a consistent forecast range. NCEP allocates different forecast lengths depending on the cycle:

| Cycle times (UTC) | Forecast range | Hourly wind grids |
|---|---|---|
| 00Z, 06Z, 12Z, 18Z (4 per day) | 48 hours | f00–f48 (49 grids) |
| All other hours (20 per day) | 18 hours | f00–f18 (19 grids) |

SWAN uses only the 4 extended cycles (00/06/12/18Z) to get the full 48-hour HRRR range. GFS wind (§14.16) supplements hours 48–72 to fill the 72-hour surf forecast card. See §14.15 for the blended wind architecture.

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

**Cycle fallback:** If the most recent cycle (e.g., 15Z) returns 404 (not yet posted), try the previous cycle (14Z). Log at INFO level which cycle was used.

**Bounding box:** Configurable per marine location. Default: spot coordinates ± 0.2° (configurable via wizard SWAN grid bbox settings).

**Cache:** Key = `(provider_id, bbox_hash, cycle_time)`. TTL = 21600s (6 hours) — matches the extended cycle interval (4×/day at 00/06/12/18Z). Previous TTL was 3300s (55 min) when SWAN ran hourly; now aligned with the 6-hour extended cycle cadence.

**Error handling:** 404 on all attempted cycles → `ProviderUnavailableError`. Network errors → canonical taxonomy. GRIB2 parse error → `ProviderProtocolError`.

**Rate limiting:** 2 req/s to NOMADS (shared NOAA infrastructure).

### §14.15 SWAN runner (ADR-093, corrected ADR-095)

**Not a network provider.** `providers/nearshore/swan.py` is a thin provider wrapper around `services/swan_runner.py`. It follows the existing provider interface pattern but runs a local SWAN subprocess instead of making a network call.

**Module identity:** `providers/nearshore/swan.py`, `PROVIDER_ID = "swan"`, `DOMAIN = "nearshore"` (ADR-096 renamed from `trushore`).

**SWAN binary:** SWAN 41.45 (Fortran). Compiled from source via `scripts/install_swan.sh` or included in the Docker image. Binary on PATH at `/usr/local/bin/swan`. API startup check: if `[nearshore]` extra is installed but SWAN binary is not found, log CRITICAL with installation instructions. The surf endpoint returns null surf data until SWAN is available — no fallback to any other model.

**Input sources (all from cache — they run on their own schedules):**

| Input | Source | Cache key pattern |
|---|---|---|
| Wind forcing (hours 0–48) | HRRR wind provider (§14.14) — 3km resolution, extended cycles only | `(hrrr, bbox, cycle_time)` |
| Wind forcing (hours 48–72) | GFS wind provider (§14.16) — 0.25° resolution, supplements HRRR | `(gfs, bbox, cycle_time)` |
| Deep-water boundary | WaveWatch III (§14.3) | `(wavewatch, ...)` |
| Bathymetry (2-D grid) | Resolver chain: operator file > NCEI regional OPeNDAP > Great Lakes > CRM fallback (§14.7) | Per-level cache: `swan_bathymetry_L{1,2,3}.json`, 180-day TTL |
| Water level (WLEVEL) | CO-OPS tidal predictions (§14.8) — time-varying, uniform across domain, hourly (ADR-095) | Reuses existing tide fetch |
| Ocean currents (CURRENT) | OFS surface current U/V (§14.10) — time-varying per grid point. Omitted when unavailable (ADR-095) | `(ofs, ...)` |
| Coastal structures (OBSTACLE) | Wizard Overpass API discovery — native SWAN OBSTACLE command (ADR-095) | From marine location config |

**SWAN runner** (`services/swan_runner.py`):

- `SWANRunner.__init__`: takes config (per-level grid bboxes, surf spot coordinates, bathymetry data, SWAN binary path)
- `run(hrrr_wind_field, gfs_wind_field, ww3_boundary, cudem_bathymetry, tide_predictions, ofs_currents)`: orchestrates the full nested SWAN run (L1 → L2 → L3), returns transect data per spot keyed by spot_id (ADR-095)
- `_run_level1(tmpdir, blended_wind, ww3_boundary, cudem_bathymetry, wlevel, current)`: runs Level 1 (1 km) SWAN with WLEVEL/CURRENT inputs, writes `NESTOUT` boundary files for Level 2
- `_run_level2(tmpdir, blended_wind, cudem_bathymetry, wlevel, current)`: runs Level 2 (100 m) SWAN with WLEVEL/CURRENT inputs, writes `NESTOUT` boundary files for Level 3
- `_run_level3(tmpdir, blended_wind, cudem_bathymetry, wlevel, current, obstacles)`: runs Level 3 (10 m) SWAN with WLEVEL/CURRENT/OBSTACLE inputs, outputs CURVE transect TABLE and SPECOUT at ~10m depth points
- `_stitch_wind(hrrr_wind_field, gfs_wind_field)`: blends HRRR (hours 0–48) and GFS (hours 48–72) into a single continuous 72-hour wind input
- `_write_input_files(tmpdir, wind_field, boundary, bathymetry, grid_level)`: writes SWAN INPUT, BOTTOM.txt, WIND.txt, BOUND_SPEC.txt for a given grid level; returns grid_info dict
- `_spawn_swan(tmpdir)`: subprocess `swan < INPUT`, captures stdout/stderr, raises `SWANRunError` on non-zero exit or severe errors in Errfile
- `_check_convergence(tmpdir, grid_level)`: health checks after each SWAN run — PRINT scan for `******`, NaN scan in hotstart/TABLE output, and valid-point fraction check; raises `SWANConvergenceError` on failure (see convergence gate subsection below)
- `_save_hotstart(run_dir, grid_level)`: copies hotstart file from run dir to persistent parent dir for next cycle; only called for nonstationary runs (see hotstart isolation subsection below)
- `_parse_output(tmpdir, grid_info)`: reads SWAN TABLE output (HEAD format), discovers column indices from header line. Extracts HSIGN, HSWELL, DIR, TM01, DEPTH, QB, DISSURF, DSPR at each transect point. Matches rows to spots by (Xp, Yp) coordinates. Also parses SPECOUT files at ~10m depth points for spectral decomposition (ADR-095)

**Nested grid architecture:** Three sequential SWAN runs per cycle (L1 → L2 → L3). No operational nearshore system runs fine resolution over the full domain — all use nested grids.

| Grid level | Config key | Default resolution | Typical domain | Grid points | Memory |
|---|---|---|---|---|---|
| L1 (outer) | `outer_grid_resolution_km` | ~1 km | ~200km × 150km (continental shelf approach, from `hrrr_bbox`) | ~5,000–8,000 | ~100–150 MB |
| L2 (inner) | `inner_nest_resolution_m` | ~100 m | ~20–30km × 10–15km (tight around surf spots, from `swan_domain_bbox`) | ~3,000–8,000 | ~50–150 MB |
| L3 (surf) | `surf_nest_resolution_m` | ~10 m | ~2–5km × 1–2km (per surf cluster) | ~2,000–4,000 | ~50–100 MB |
| **Total** | | | | **~10,000–20,000** | **≤400 MB** |

Level 1 writes `NESTOUT` boundary files; Level 2 reads them via SWAN's `NGRID` command and writes its own `NESTOUT`; Level 3 reads Level 2's `NESTOUT`. Multiple surf spots on the same coastline share Levels 1 and 2; each cluster gets its own Level 3 nest. The runner copies boundary files between level subdirs: `level1/nest_out.dat` → `level2/nest_in.dat`, `level2/nest_out.dat` → `level3_{idx}/nest_in.dat`.

Time step: 10 minutes (SWAN default non-stationary). Output timestep: 1 hour. Forecast span: 72 hours (HRRR hours 0–48, GFS hours 48–72).

**Output:** `dict[spot_id, list[MarineForecastPoint]]` — 72 forecast hours per spot. Each `MarineForecastPoint` carries `waveHeight=Hs`, `wavePeriod=Tm01`, `waveDirection=MWD`, and `time` (ISO-8601). Source attribution ("swan") is set at the `SwanProvider` response level, not inside `MarineForecastPoint` (which has no `source` field). **Validation:** SWAN INPUT files set `QUANTITY HSIGN TM01 DIR excv=-9.` (explicit no-data sentinel per SWAN user manual §3.5). The TABLE parser rejects rows with values ≤ -9 (exception value) or extreme upper bounds (Hs > 25m, Tm01 > 35s). NaN values are also rejected. Sub-1s Tm01 and near-zero Hs are physically valid SWAN output for weak wind-sea and are NOT rejected.

**SWAN INPUT file conventions (per SWAN 41.51 user manual):**

| Setting | Value | Why |
|---|---|---|
| `SET ... MAXERR 3` | Only stop on severe errors (level 3) | Default MAXERR=1 stops on boundary mismatch warnings (level 2), which are normal for nonstationary TPAR boundaries |
| `QUANTITY HSIGN TM01 DIR excv=-9.` | Explicit no-data sentinel | Without this, SWAN uses an implementation default indistinguishable from real near-zero values |
| `TABLE ... TIME XP YP HSIGN TM01 DIR` | SWAN output quantity names | `HSIGN` (not `HS`) is the correct quantity name; `TIME` must be explicitly requested (not automatic) |
| `INIT HOTSTART 'hotstart.dat'` | Load wave field from previous run | Eliminates cold-start spin-up; t=0 has realistic waves immediately |
| `HOTFILE 'hotstart.dat'` | Write wave field after COMPUTE | Saved to persistent location for next cycle |

**Per-level physics (SWAN-L3-STABILITY-PLAN Phase 2):**

The shared physics block is differentiated per level. Common commands emitted at all levels: `GEN3 WESTHUYSEN`, `BREAKING CONSTANT 1.0 0.73`, `FRICTION JON 0.067`, `TRIAD`. Level-specific:

| Command | L1 (1 km) | L2 (100 m) | L3 (10 m) |
|---|---|---|---|
| SETUP | Removed (unsupported in OpenMP parallel runs; nest BC structurally wrong) | Removed | Removed |
| DIFFRACTION | Removed (sub-grid at 1 km) | Removed (sub-grid at 100 m) | `DIFFRACTION 1 0.2 27` (smoothed; filter εx≈45m) |
| NUMERIC alfa | — | — | Stationary only: `NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01` |

The SETUP physical effect (~10–15 cm near shore) is delivered via the WLEVEL input grid. Stage 2 (current): tide + analytic radiation-stress-balance setup estimate (`services/wave_setup.py`). The setup profile is computed from the previous run's cached Hs using Green's law shoaling to find breaking, then Longuet-Higgins & Stewart (1964) radiation-stress integration (K ≈ 0.167 for γ=0.73). First run (no previous cache) falls back to tide-only.

**Convergence gate (SWAN-L3-STABILITY-PLAN Phase 4):**

After every SWAN run, `_check_convergence()` performs three health checks:
1. PRINT scan: any `******` in accuracy lines → FAIL.
2. NaN scan: any NaN in the run's hotstart or TABLE output → FAIL.
3. Valid-point fraction: wet transect points with non-exception values below 80% → FAIL.

Behavior controlled by `convergence_retry` config key (default `false`):
- `false` (testing/default): ERROR log with metrics, no retry, failed workdir preserved untouched, no hotstart saved, API serves last-good run.
- `true` (future production): quarantine evidence to `/var/run/weewx-clearskies/swan/failed/{cycle}_{level}/`, then degrade: smnum×2 → DIFFRACTION removed → abandon cycle. API serves last-good run with honest timestamp.

A diverged run NEVER saves a hotstart, NEVER overwrites the last-good cache, and NEVER fails silently.

**Hotstart isolation:**

Stationary quick updates do NOT save hotstart files. The nonstationary chain's persistent hotstarts (`level3_{idx}_hotstart.dat`) are only written by full nonstationary runs. This prevents a diverged stationary snapshot from infecting the next full run's warm-start.

**OBSTACLE emission from bearing/length/distance:**

When a structure config has `bearing_degrees`, `length_m`, and `distance_m` but no explicit `coordinates` field, the runner computes endpoint coordinates (geodesic projection from the spot pin) and emits the OBSTACLE line. Every structure is logged at INFO as emitted or WARNING as skipped — never silent.

**Quick update WLEVEL:**

The stationary quick update now includes a WLEVEL input (current tide at compute time). Previously, quick updates ran with no tidal water level correction — up to ±1m depth error.

**Hotstart:** Each nonstationary SWAN run writes a hotstart file (`HOTFILE` command, placed immediately after `COMPUTE`) capturing the full spectral state at the end of computation. The next full run reads it via `INIT HOTSTART`, starting from the previous run's wave field instead of the default near-zero JONSWAP spectrum. Hotstart files persist at `/var/run/weewx-clearskies/swan/level1_hotstart.dat`, `level2_hotstart.dat`, and `level3_{idx}_hotstart.dat` across subdir cleanup between runs. If no hotstart exists (first run ever), SWAN initializes from the default wind-derived spectrum — a one-time cold start. Stationary quick updates do not write hotstart files; see the hotstart isolation subsection above.

**SWAN error detection:** `_spawn_swan()` checks both exit code AND stderr/Errfile content. SWAN (Fortran) can exit 0 despite writing "Severe error" to its Errfile. When severe errors are detected, `SWANRunError` is raised so the failure is visible and the run_marker is not stored.

**Cache:** Key = `(provider_id, spot_domain_id, hrrr_cycle_time)`. TTL = 21600s (6 hours) — matches the extended HRRR cycle interval (4×/day at 00/06/12/18Z). On SWAN run failure: log ERROR, retain last-good cache indefinitely. Do NOT invalidate cache on failure — stale SWAN data is always preferred to no data. **Run marker:** stored only when `spots_cached > 0` — prevents a failed SWAN run (exit 0 but no valid output) from blocking future attempts for the same HRRR cycle.

**Cache payload shape** (per-spot, stored at `last_good_key`):

| Key | Type | Description |
|---|---|---|
| `forecast` | `list[dict]` | Serialised `MarineForecastPoint` objects — one entry per transect point per timestep (all timesteps, all transect positions). Grouped by time in `surf.py`. |
| `spectral` | `list[dict]` | Per-timestep SPECOUT spectral decompositions from SWAN SPECOUT at the ~10m depth point (T3.3). Each entry: `{time, components}`. |
| `transect` | `dict[str, list[dict]]` | Full cross-shore transect per timestep, keyed by ISO-8601 time string (T3.4). Each list entry: `{distanceFromShore, depth, waveHeight, swellHeight, breakingFraction, breakingDissipation}` for one transect point. Used by the beach profile endpoint (T5.1). |
| `run_time` | `str` | ISO-8601 UTC timestamp when the SWAN run completed. |
| `hrrr_cycle_time` | `str` | HRRR cycle time that forced this SWAN run. |

`fetch()` returns all five keys from `last_good_key`; `data_age_seconds` is computed live from `run_time`.

**On-disk forecast cache persistence (SWAN-L3-STABILITY-PLAN Phase 8):** The in-memory cache is also persisted to `/var/run/weewx-clearskies/swan/forecast_cache.json` after every successful full run and quick update (atomic write via temp+rename). On API startup, `fetch()` loads the on-disk cache if it exists and is less than 12 hours old. This ensures API restarts do not lose surf forecast data — the dashboard immediately serves the last-good forecast without waiting for a new SWAN run.

**Two-tier schedule:**

| Tier | Trigger | Grids | Mode | Forecast span | Runtime | Interval |
|---|---|---|---|---|---|---|
| Full run | Extended HRRR cycle (00/06/12/18Z) + GFS + WW3 | L1 + L2 + L3 | Nonstationary (72h time-stepping) | 72 hours | ~7–12 min | Every 6 hours |
| Quick update | Any HRRR cycle (hourly) | L3 only | Stationary (single snapshot, no time-stepping) | 1 timestep ("now") | <1 min | Every hour |

**Full runs** produce the 72-hour forecast. All three grid levels must complete within 15 minutes total. Peak memory: ≤400 MB (all three grids run sequentially, not simultaneously).

**Quick updates** run a stationary Level 3 SWAN computation per cluster with the latest HRRR wind, reusing Level 2's `nest_out.dat` from the last full run. Per SWAN user manual §4.7: "For small domains (< 100 km), a stationary computation is recommended." Each Level 3 grid is ~2-5 km. The stationary result is merged into the existing forecast cache (replaces the entry closest to the snapshot time). Skipped for 30 minutes after a full run completes (no overlap). Quick updates refresh nearshore wind effects (sea breeze, wind chop, wind quality scoring) hourly; the deep-water swell propagation stays correct from the last full run.

**Working directory:** SWAN runs in `/var/run/weewx-clearskies/swan/` (fixed path, not tempfile). Subdirectories `level1/`, `level2/`, and `level3_{idx}/` (one per cluster) are cleaned at the start of each run. Hotstart files (`level1_hotstart.dat`, `level2_hotstart.dat`, `level3_{idx}_hotstart.dat`) persist between runs. Nesting file flow: Level 1 writes `nest_out.dat`, runner copies to Level 2 as `nest_in.dat`; Level 2 writes `nest_out.dat`, runner copies to Level 3 as `nest_in.dat`. The fixed path is visible from SSH (unlike `tempfile.mkdtemp` which was hidden by systemd's `PrivateTmp=yes`) and survives service restarts.

**2-D bathymetry grid:** Downloaded lazily on first SWAN run via the bathymetry resolver priority chain (§14.7): operator file → NCEI regional OPeNDAP → Great Lakes → CRM fallback. Per-level caches at `/etc/weewx-clearskies/swan_bathymetry_L{1,2,3}.json` with 180-day TTL. `cudem_to_swan_bottom()` bilinear-interpolates the source grid onto SWAN grid dimensions. Sign convention: CUDEM (negative = ocean) → SWAN (positive = ocean). Vertical datum normalized to MSL via VDatum REST API.

**Optional separated service:** When `[swan] service_url` is set to a remote host, `SwanProvider.fetch()` calls the remote HTTP endpoint instead of running SWAN locally. Health check polls `GET {service_url}/health` every 60 seconds. Three consecutive failures → log ERROR, serve last-good cache. See ARCHITECTURE.md for the standalone `weewx-clearskies-swan` package (ADR-096 renamed).

### §14.16 GFS wind provider (Phase 7 — supplements HRRR for 72-hour forecast)

**Module identity:** `providers/wind/gfs.py`, `PROVIDER_ID = "gfs"`, `DOMAIN = "wind"`.

**CAPABILITY:** `geographic_coverage = "global"`, `auth_required = []`. `supplied_canonical_fields` includes U-component and V-component of wind at 10m above ground level, earth-relative.

**Availability:** Active only when the `[nearshore]` pip extra is installed. Invoked by the SWAN runner alongside the HRRR wind provider — not by the cache warmer directly. The cache warmer fires GFS warm at startup and on the 6-hour schedule when `[nearshore]` is installed.

**Purpose:** Supplements HRRR wind (which reaches only 48 hours on extended cycles) to fill the 72-hour surf forecast card. GFS provides wind data for forecast hours 48–72. GFS is coarser than HRRR (0.25° / ~25km vs. HRRR's 3km), but the resolution transition at hour 48 does not affect SWAN's nearshore physics — wave refraction, shoaling, and breaking are computed at the SWAN grid resolution (200–500m), not the wind grid resolution.

**Data source (primary):** NOMADS Grib Filter at `https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl`. Supports geographic subsetting (bounding box), variable selection (UGRD/VGRD at 10m AGL), and GRIB2 output. Free, no API key.

**Data source (backup):** AWS S3 at `s3://noaa-gfs-bdp-pds/`. Same data, hosted by Amazon as a public dataset.

**Schedule:** GFS runs on a 6-hourly schedule (00Z, 06Z, 12Z, 18Z). Availability: ~3.5–4.5 hours after the nominal run hour (GFS takes longer to post than HRRR due to its global domain). Aligned with the SWAN extended HRRR cycle schedule.

**Forecast range:** GFS produces forecasts to 384 hours (16 days) at 3-hour timesteps (f00–f384). For SWAN, only hours 48–72 are fetched (9 grids at 3-hour intervals: f048, f051, f054, f057, f060, f063, f066, f069, f072). The SWAN runner interpolates 3-hourly GFS wind to hourly resolution to match the HRRR cadence.

**Extracted variables:**

| GRIB2 parameter | Variable | Description |
|---|---|---|
| UGRD:10 m above ground | U-component | East-west wind at 10m AGL |
| VGRD:10 m above ground | V-component | North-south wind at 10m AGL |

**Wind rotation:** GFS uses a regular latitude-longitude grid (0.25° spacing). Wind components are earth-relative by default — no rotation required (unlike HRRR's Lambert Conformal grid). Verify by checking the GRIB2 metadata `componentFlags` field.

**Bounding box:** Same as the HRRR bounding box for the marine location — configured per spot via the wizard SWAN grid bbox settings.

**Cache:** Key = `(provider_id, bbox_hash, cycle_time)`. TTL = 21600s (6 hours) — matches the GFS cycle cadence.

**Error handling:** 404 on all attempted cycles → `ProviderUnavailableError`. Network errors → canonical taxonomy. GRIB2 parse error → `ProviderProtocolError`. On GFS failure, SWAN produces a shortened forecast (HRRR hours 0–48 only) rather than no forecast.

**Rate limiting:** 2 req/s to NOMADS (shared NOAA infrastructure, same rate as HRRR).

### Source ADRs

§14 consolidates prescriptive rules from: ADR-083 (marine domain architecture), ADR-084 (NWPS supplementation — superseded by ADR-093), ADR-085 (eccodes dependency), ADR-087 (NDBC spectral data), ADR-088 (fishing scoring — bathymetry for habitat), ADR-089 (marine zone alerts), ADR-091 (marine card data sources, OFS ocean data, composite water level), ADR-093 (SWAN replaces NWPS), ADR-094 (HRRR wind source for surf scoring), ADR-095 (SWAN model corrections — transect, WLEVEL, CURRENT, OBSTACLE), ADR-096 (scoring restructure, TruShore branding removal). ADRs are archived in `docs/archive/decisions/` and explain the *why* behind these rules.
