# Clear Skies — API Manual

Single authority for all Clear Skies API implementation rules. Consumers: API dev agents and human reviewers.

When this document conflicts with any other source (ADRs, code comments, conversation history), **this document wins**. ADRs explain *why* decisions were made; this manual says *what to do*.

Companion documents:

- **ARCHITECTURE.md** — system topology, ports, containers (what the system IS)
- **PROVIDER-MANUAL.md** — provider module rules
- **contracts/canonical-data-model.md** — per-field data catalog (the field inventory)

Last updated: 2026-07-15

---

## Contents

1. [Purpose and Principles](#1-purpose-and-principles)
2. [Data Model](#2-data-model)
3. [Database Access](#3-database-access)
4. [Versioning](#4-versioning)
5. [Column Mapping](#5-column-mapping)
6. [Unit System](#6-unit-system)
7. [skin.conf Compliance](#7-skinconf-compliance)
8. [Conditions Text Engine](#8-conditions-text-engine)
9. [Charts System — API Side](#9-charts-system--api-side)
10. [weewx Integration](#10-weewx-integration)
11. [SSE and Realtime](#11-sse-and-realtime)
12. [Radar Endpoints and Capability Model](#12-radar-endpoints-and-capability-model)
13. [Anti-Patterns](#13-anti-patterns)
14. [Forecast Correction Engine](#14-forecast-correction-engine)
15. [Forecast Text Generation](#15-forecast-text-generation)
16. [Marine Data Model](#16-marine-data-model)
17. [Marine Enrichment](#17-marine-enrichment)
18. [Marine Endpoints](#18-marine-endpoints)

---

## §1 Purpose and Principles

### THE API IS NOT A FILE SERVER

THE API SERVES WEEWX DATA AND EXTERNAL PROVIDER DATA. NOTHING ELSE. It does not serve static files, resolve photo URLs, check filesystem paths for images, or perform any function that belongs to Caddy or the stack. Static assets (location photos, branding images, config JSON files) are served by Caddy from `/etc/weewx-clearskies/`. The API has zero involvement in static file serving — no filesystem existence checks, no URL construction, no file path resolution. If a proposed change involves the API reading a file to tell the dashboard where a static asset is, that change is wrong. Caddy serves static files. The dashboard constructs static asset URLs from known patterns. The API is not in the middle.

### What the API is

The API (`weewx-clearskies-api`) is the weewx application layer — not merely a dashboard backend. It is the canonical programmatic interface to weewx station data. Any client (dashboard, Home Assistant, third-party scripts) that needs weather station data connects to the API. The API does not exist solely to serve the dashboard.

The API runs on the weewx host, co-located with the weewx process and its archive database (per ADR-056). This co-location is a deployment constraint, not a preference — the API reads `weewx.conf` locally and shares the filesystem with the weewx archive.

### Computation boundary

The API owns three distinct layers of responsibility:

1. **Data access.** Query the weewx archive database via SQLAlchemy. Return raw observation and aggregate values.
2. **Unit conversion and derived values.** Convert raw values to operator display units. Compute Beaufort scale, comfort index selector, barometer trend direction, and cardinal wind directions. This is the enrichment pipeline.
3. **Provider data.** Aggregate external data (forecast, AQI, alerts, earthquakes, radar) via internal provider plugin modules. Apply the same unit conversion pipeline to provider-sourced data.

The dashboard owns rendering and presentation-level computation: client-side binning for visualizations (wind rose direction-by-Beaufort matrix), LTTB downsampling, chart layout, theming. The dashboard reads API-provided derived fields but does not recompute them.

**The test:** If a proposed endpoint handler requires unit conversion, threshold classification, or produces output shaped for a specific chart type, it belongs in the enrichment pipeline or the dashboard — not in the endpoint handler.

### General-purpose data access

The API exposes general-purpose data access endpoints. It does not expose chart-specific or visualization-specific endpoints. The API serves `/archive` time-series, `/archive/grouped` categorical aggregates, `/current` observation snapshot, and `/charts/config` for operator-defined chart definitions. The dashboard determines what to fetch and how to render it.

Do not create endpoint paths named after a chart type (e.g., `/charts/wind-rose`, `/charts/temperature-range`). The single exception is `/charts/custom-query/{series_id}`, which executes operator-defined SQL from `charts.conf` — not a chart-type endpoint, a config-driven query executor.

### Setup mode

When `settings.configured = False`, the API starts in setup mode. In setup mode:

- Only setup endpoints under `/setup/*` are active.
- `/api/v1/status` returns `{"configured": false}` and is always active regardless of mode.
- All other `/api/v1/*` endpoints return HTTP 503 with an RFC 9457 problem body: `{"type": "urn:clearskies:not-configured", "title": "Station not configured", "status": 503}`.
- No database connection is established. No provider modules load. No data routers run.
- The SSE stream is not available.

After the operator completes the setup wizard and the API receives `POST /setup/apply`, the API writes its config files and restarts into normal mode.

### Startup sequence

The API startup executes in the following ordered steps. Steps marked **fatal** exit the process non-zero on failure. Steps marked **non-fatal** log a warning and continue.

| Step | Action | Error handling |
|------|--------|----------------|
| 1 | Load and validate `settings` from `api.conf` and `secrets.env` | Fatal |
| 2 | Initialize structured JSON logging (stdout, stdlib `logging`) | Fatal |
| 3 | Initialize TLS (load or generate Ed25519 self-signed certificate) | Fatal |
| 4 | Initialize trust manager (load pinned fingerprints and session store) | Fatal |
| 5 | Start FastAPI engine, mount middleware (CORS, security headers, request size limit) | Fatal |
| 6 | Run write probe against the database; exit non-zero if writes succeed | Fatal |
| 7 | Run schema reflection (`MetaData.reflect()` on archive table) → populate column registry | Fatal |
| 8 | Read `weewx.conf` for station metadata auto-detection | Non-fatal (warning) |
| 9 | Load unit system config (`api.conf [units]`); validate column units | Non-fatal (warnings per mismatch) |
| 10 | Load station metadata (lat, lon, altitude, timezone, station name) | Non-fatal |
| 11 | Initialize ephemeris (Skyfield for almanac). pvlib is used at bootstrap time for McClear clear-sky GHI (ADR-072), not at runtime. | Non-fatal |
| 12 | Load reports config (`api.conf [reports]`) | Non-fatal |
| 13 | Load content config (custom pages) | Non-fatal |
| 14 | Initialize cache backend (memory or Redis per `api.conf [cache]`) | Non-fatal (falls back to memory) |
| 15 | Start cache warmer daemon thread | Non-fatal |
| 16 | Load database metrics | Non-fatal |
| 17 | Initialize provider registry; load per-domain provider modules | Non-fatal per provider |
| 18 | Load per-domain provider settings (forecast, AQI, alerts, earthquakes, radar) | Non-fatal per domain |
| 19 | Run health probe (loopback `/health/ready` on port 8081) | Non-fatal |
| 20 | Initialize SSE infrastructure (emitter, 64-packet overflow buffer, 15-second keepalive) | Fatal |
| 21 | Initialize `UnitTransformer` with loaded unit config | Fatal |
| 22 | Register enrichment processors in order (see §8 for processor registration order) | Fatal |
| 23 | Wire endpoint enrichment (barometer trend, wind rolling average, conditions text, etc.) | Fatal |
| 24 | Serve (uvicorn begins accepting connections) | — |

This is a 24-step process. Each step has explicit error handling. Do not collapse steps or add silent fallbacks that mask startup failures.

---

## §2 Data Model

For the complete per-field inventory — field names, types, units by unit system, and provider-to-canonical mapping tables — see `contracts/canonical-data-model.md`.

### Naming

Use weewx-aligned camelCase in both Python and JSON. Python field names and JSON key names are identical — no alias mechanism, no snake_case-to-camelCase translation at serialization time. The Pydantic ruff rule N815 (mixed-case variables) is suppressed on model fields.

### Entity types

The canonical data model defines 9 core entity types and 2 container types:

| Entity | Description |
|--------|-------------|
| `Observation` | Single current-conditions snapshot (loop-packet-derived) |
| `ArchiveRecord` | One archive interval record (DB-derived) |
| `HourlyForecastPoint` | Hourly forecast from a provider module |
| `DailyForecastPoint` | Daily forecast summary from a provider module |
| `ForecastDiscussion` | Full NWS Area Forecast Discussion text |
| `AlertRecord` | Single severe-weather alert |
| `EarthquakeRecord` | Single earthquake event |
| `AQIReading` | Air quality index reading from a provider module |
| `StationMetadata` | Station identity (name, lat, lon, alt, timezone, archiveIntervalSeconds, weekStartDay) |
| `MarineObservation` | Buoy observation snapshot (NDBC standard met) |
| `SpectralWaveComponent` | Single swell system from spectral decomposition (NDBC) |
| `TidePrediction` | Predicted high/low tide event (CO-OPS) |
| `WaterLevel` | Observed water level reading (CO-OPS) |
| `MarineForecastPoint` | Single timestep of marine wave forecast (WaveWatch III) |
| `MarineTextForecast` | NWS marine zone text forecast period |
| `SurfForecast` | Surf quality forecast per spot per timestep |
| `FishingForecast` | Fishing conditions forecast per spot per period |
| `SolunarTimes` | Solunar major/minor feeding periods for a date |
| `SurfZoneForecast` | NWS Surf Zone Forecast per county per day |
| `BeachSafetyAssessment` | Beach safety composite assessment per location |
| `MarineLocationSummary` | Summary snapshot for one marine location |
| `ForecastBundle` | Container: hourly + daily + discussion in one response |
| `AlertList` | Container: list of active alerts |
| `MarineBundle` | Container: marine conditions + forecast per location |
| `TideBundle` | Container: predictions + observations per location |
| `MarineAlertSummary` | One active NWS alert tagged with a dashboard-tab `alertType` (T3.5) |

Note: `GET /api/v1/surf[/{locationId}]`, `GET /api/v1/fishing[/{locationId}]`, and `GET /api/v1/beach-safety[/{locationId}]` return plain dicts (the standard envelope, §2), not Pydantic-backed bundle models — see "Surf bundle (actual shape)," "Fishing bundle (actual shape)," and "Beach-safety bundle (actual shape)" below for their ground-truth field tables.

### Response shapes

**Observation endpoints** (`/current`, SSE stream) return `ConvertedValue` dicts for each observation field:

```json
{"value": 22.5, "label": "°C", "formatted": "22.5"}
```

**`GET /current?units=si` — canonical SI mode for companion services (C-47, 2026-07-25).** Additive: absent the parameter, `/current` is byte-for-byte unchanged. Exists so the marine service — which works in canonical SI only and deliberately has no unit-conversion path of its own (C-29) — can query the API for the live station observation (surf scoring's t=0 wind/temperature/pressure input) without round-tripping through the operator's display unit and back, a precision loss and a needless reintroduction of conversion logic into a repo that intentionally has none. Scoped to `windSpeed`, `windGust` (m/s), `outTemp` (°C), `barometer` (hPa), `windDir`, `windGustDir` (degrees, unconverted — a single unit regardless of system) — not the full observation shape; extending it further would need a canonical-SI target for every weewx unit group, which nothing has asked for yet. Response shape in this mode is **raw scalars**, not the `{value, label, formatted}` wrapper shown above — a machine client gains nothing from a `formatted` display string or an operator-overridable `label` for a value that is, by contract, always in a fixed SI unit:

```json
{"data": {"timestamp": "2026-07-26T04:11:14Z", "windSpeed": 4.47, "windDir": 180.0, "windGust": 6.71, "windGustDir": 190.0, "outTemp": 21.11, "barometer": 1015.92}, "units": {"windSpeed": "m/s", "windGust": "m/s", "outTemp": "°C", "barometer": "hPa", "windDir": "°", "windGustDir": "°"}, "source": "weewx", "generatedAt": "...", "stationClock": {...}, "freshness": {...}}
```

Source values are converted from the archive's actual native weewx unit system (read via a dedicated `usUnits` lookup — `services/archive.py`'s `get_current_us_units()` — not inferred from the operator's display-unit labels, which can legitimately differ from the archive's native system when the operator has overridden per-group display targets) to SI using the same `units/conversion.py` `convert()` every other unit conversion in this API uses. An unknown `?units=` value is rejected with 422 problem+json (`ConfigDict(extra="forbid")`, security-baseline §3.5) — `si` is the only accepted value.

**Archive endpoints** (`/archive`, `/archive/grouped`) return flat scalars except for `beaufort`, which retains its `ConvertedValue` dict to allow dashboard-side wind rose binning without recomputing Beaufort from wind speed.

Both endpoint classes carry a `units` envelope (see below).

### Units metadata

Every API response carries a `units` metadata block. Use display-friendly symbols (`°F`, `mph`, `inHg`) not weewx-internal identifiers (`degree_F`, `mile_per_hour`, `inHg`). Example:

```json
{
  "units": {
    "temperature": "°F",
    "speed": "mph",
    "pressure": "inHg",
    "rain": "in",
    "rainRate": "in/hr"
  }
}
```

Never return a response that omits the `units` block.

### Time

Use UTC ISO-8601 with a `Z` suffix on all time fields in API responses: `"2026-06-18T14:30:00Z"`. Never include local-time strings. Python `datetime` objects must carry `tzinfo=UTC` — naive datetimes are forbidden in API-layer code. Display-side timezone conversion happens in the dashboard using the station's IANA timezone from `StationMetadata`.

#### Station clock contract (ADR-075)

The API is the sole source of "what time is it at the station." Every API response includes a `stationClock` block computed at response time. It does not require a database query or any external call.

```json
{
  "stationClock": {
    "date": "2026-06-27",
    "time": "2026-06-27T22:30:00-04:00",
    "timezone": "America/New_York"
  }
}
```

| Field | Type | Meaning |
|-------|------|---------|
| `date` | YYYY-MM-DD | Station-local date. The canonical answer to "what day is it at the station?" The dashboard uses this for all date-boundary logic (forecast "Today" labeling, high/low today, almanac "tomorrow"). |
| `time` | ISO-8601 with UTC offset | Station-local time with UTC offset included. The offset lets the dashboard convert to UTC epoch for elapsed-time math without a timezone library. |
| `timezone` | IANA identifier string | e.g., `"America/New_York"`. Redundant with `StationMetadata.timezone` but included for self-contained interpretation of each response. |

#### Timezone source priority

The API resolves the station timezone using this priority chain at startup:

| Priority | Source | When used |
|----------|--------|-----------|
| 1 | Operator setting in `api.conf` or wizard | Always preferred when set |
| 2 | weewx.conf `[Station] timezone` | Auto-detected at startup |
| 3 | OS timezone of the weewx host | Fallback when weewx.conf has no timezone |
| 4 | UTC + startup warning | Last resort; operator must configure |

The wizard auto-populates the timezone from the OS timezone during initial setup. The operator can change it in the admin UI. weewx stores all data as UTC and treats the OS timezone as the local-time reference — the API must be the explicit timezone authority for all downstream consumers (ADR-075).

### Response envelope

Every API response follows this envelope shape:

```json
{
  "data": { "...": "..." },
  "stationClock": {
    "date": "2026-06-27",
    "time": "2026-06-27T22:30:00-04:00",
    "timezone": "America/New_York"
  },
  "freshness": {
    "generatedAt": "2026-06-28T02:30:00Z",
    "validUntil": "2026-06-28T03:00:00Z",
    "refreshInterval": 1800
  },
  "units": { "...": "..." },
  "generatedAt": "2026-06-28T02:30:00Z"
}
```

`stationClock` is present in every response. `freshness` is present in all cacheable REST responses. Responses that do **not** carry `freshness`:

- **SSE events** — real-time push; no polling cycle.
- **Setup endpoints** (`/setup/*`) — one-time configuration flow; no caching concern.

### Data freshness

Every cacheable REST response includes a `freshness` block:

```json
{
  "freshness": {
    "generatedAt": "2026-06-28T02:30:00Z",
    "validUntil": "2026-06-28T03:00:00Z",
    "refreshInterval": 1800
  }
}
```

| Field | Type | Meaning |
|-------|------|---------|
| `generatedAt` | UTC ISO-8601 Z | When the API produced this response. |
| `validUntil` | UTC ISO-8601 Z | When the data should be considered stale. After this time, the dashboard refetches. |
| `refreshInterval` | integer (seconds) | How often this data type typically updates at the source. Cards use this as a proactive poll interval. |

The dashboard uses `validUntil` to schedule refetches (`Date.now() > new Date(freshness.validUntil).getTime()`), not hardcoded intervals. Cards may also use `refreshInterval` to set a proactive poll timer so they do not have to wait until the response has already expired.

#### Per-domain defaults

Per-domain `refreshInterval` defaults are configured in the `[freshness]` section of `api.conf`. The operator can override any domain's interval there.

| Domain | `refreshInterval` | `validUntil` | Rationale |
|--------|-------------------|-------------|-----------|
| Current observation (REST) | `archiveIntervalSeconds` (from weewx.conf) | generatedAt + archiveInterval | Matches weewx archive write cadence |
| SSE loop packets | — (push) | — | Real-time; no polling needed |
| Forecast | 1800 (30 min) | generatedAt + 30 min | Provider update cadence |
| Alerts | 300 (5 min) | generatedAt + 5 min | Safety-critical |
| AQI | 900 (15 min) | generatedAt + 15 min | Provider update cadence |
| Almanac (daily) | 86400 (24 hr) | station-local next midnight | Changes once per calendar day |
| Almanac (positions) | 60 (1 min) | generatedAt + 1 min | Continuously changing |
| Radar frames | 300 (5 min) | generatedAt + 5 min | Frame metadata cadence |
| Earthquakes | 300 (5 min) | generatedAt + 5 min | USGS update cadence |
| Records | `archiveIntervalSeconds` (from weewx.conf) | generatedAt + archiveInterval | New records appear at archive write cadence |
| Charts config | 86400 (24 hr) | generatedAt + 24 hr | Static unless operator edits |
| Station metadata | 86400 (24 hr) | generatedAt + 24 hr | Static unless operator edits |
| Seeing forecast | 10800 (3 hr) | generatedAt + 3 hr | 7Timer update cadence |

The `current_observation` and `records` domains derive their `refreshInterval` from `archiveIntervalSeconds` (read from `weewx.conf [StdArchive] archive_interval`, already loaded by the API at startup via `StationInfo`). This ensures the dashboard polls at the cadence data actually arrives — not faster (wasted requests) or slower (stale data). Do not hardcode a magic number like `300` for these domains.

### Idle configuration

Idle settings are operator-configured in `api.conf` (wizard/admin) and served to the dashboard as part of station metadata:

| Setting | Type | Default | Meaning |
|---------|------|---------|---------|
| `idleTimeout` | integer (minutes) | 30 | After this many minutes of no user interaction (mouse move, keypress, scroll, touch), cards reduce their refresh rate by multiplying `refreshInterval` by `idleRefreshFactor`. |
| `idleRefreshFactor` | integer | 10 | Divisor applied to `refreshInterval` during idle. Factor 10 means a 30-second refresh card refreshes every 300 seconds when idle. |

Setting `idleTimeout` to `0` disables idle detection entirely (kiosk / wall-display mode — cards refresh at full rate indefinitely). The SSE connection stays open regardless of idle state; it is push-based and has no polling cost. Any user interaction (mouse move, keypress, scroll, touch) resets the idle timer and immediately restores normal refresh rates.

### Nullability

Every field is `Optional[T]`. The key is always present in the response; use `null` for missing values. Never omit a key because the value is absent.

Pydantic model config:

```python
model_config = ConfigDict(
    extra="forbid",
    populate_by_name=True,
)
```

Serialize with `model.model_dump_json(exclude_none=False)` — `null` values must appear in the output, not be stripped. Serialize `inf` and `NaN` as strings (`ser_json_inf_nan="strings"`) to produce valid JSON.

### Provenance

Every record carries a `source: str` field. Use `"weewx"` for archive-derived data. Use the provider module's identifier string (e.g., `"open_meteo"`, `"nws"`, `"openweathermap"`) for upstream-derived data.

### Custom columns

Non-core columns (columns the operator has mapped from their archive schema but that do not correspond to a canonical entity field) go into `extras: dict[str, Any]`. Stock weewx columns never appear in `extras` — they appear at their canonical field names.

The `/archive` endpoint serves all columns present in the archive schema with no whitelist gate. Any column in the database is queryable by passing its column name as `observation_type`.

### Earthquake fields

Magnitude (a dimensionless number) and coordinates (WGS84 decimal degrees) are not converted — they never appear in the `units` block. However, `depth` and `distance` participate in `group_distance` unit conversion (see below).

`depth` and `distance`, however, participate in the `group_distance` unit system (mile/km) like any other distance field:

- The endpoint computes `distance` (haversine distance from the operator's station to the epicenter, via `services/station.py` `StationInfo` lat/lon) for every `EarthquakeRecord`.
- Both `depth` and `distance` are converted to the operator's configured `group_distance` display unit using the canonical conversion registry (`units/conversion.py`) — never a hand-rolled factor, per the conversion-factor-accuracy rule below.
- The `units` block reflects the unit actually used: `{"depth": "mi"|"km", "distance": "mi"|"km", "magnitude": ""}`.
- The operator's `group_distance` preference is resolved by reading the units block populated at startup (`services/units.py` `get_units_block()`), keyed off a `group_distance` member field (`windrun`) rather than inferring from the temperature-based US/METRIC/METRICWX system check — this correctly reflects a `[StdReport][[Units]][[Groups]]` override applied specifically to `group_distance`, independent of other groups.

### Prose layers

Three layers of text prose exist in the data model:

| Layer | Field | Source | Transport |
|-------|-------|--------|-----------|
| Conditions text | `weatherText` | Conditions engine (§8) | REST only (`/current`) |
| Daily forecast prose | `narrative` | Provider daily forecast | REST (`/forecast`) |
| Area forecast discussion | `ForecastDiscussion` | NWS AFD API | REST (`/forecast/discussion`) |

`weatherText` is not included in the SSE field map.

### Pydantic configuration summary

| Setting | Value |
|---------|-------|
| `extra` | `"forbid"` |
| `exclude_none` | `False` (always serialize null) |
| Field naming | camelCase (ruff N815 suppressed) |
| Serialization | `model.model_dump_json(exclude_none=False)` |
| Inf/NaN | `"strings"` |

---

## §3 Database Access

### Driver

Use SQLAlchemy 2.x with parameterized queries throughout. Never concatenate SQL strings with user-supplied or operator-supplied values. Use SQLAlchemy Core for read-heavy aggregation queries (not ORM). Refer to `rules/coding.md` §1 for the parameterized-query requirement.

### Backends

Support SQLite (weewx default) and MariaDB. Write no per-driver code paths in endpoint handlers — SQLAlchemy abstracts the dialect. The same endpoint code must work on both backends.

### Read-only enforcement

Apply defense in depth across two independent layers:

1. **Database-level grants.** For MariaDB: operator provisions `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'`. For SQLite: open the file with `?mode=ro&uri=true` plus filesystem read-only permissions. Document the exact SQL grant in `INSTALL.md`.
2. **Startup write probe.** At startup (step 6), attempt a write to a throwaway table. If the write succeeds, log an error and exit non-zero. The API refuses to start if it has write access. This probe runs before schema reflection and before any endpoint is registered.

The startup write probe is not optional. Do not remove it or make it conditional.

### Schema introspection

At startup (step 7), run `MetaData.reflect()` against the archive table. The reflected column list populates the column registry. Endpoints select columns from the operator's mapping (§5) derived from this registry — not from a hardcoded column list.

Re-introspection is triggered by the config UI when the operator re-runs the mapping flow (e.g., after adding a new weewx extension). The API never re-reflects mid-request.

### Connection lifecycle

Yield a SQLAlchemy session per request via FastAPI dependency injection. Close the session at request end. Do not hold long-lived sessions in endpoint code.

### Pool settings

| Backend | Pool type | pool_size | max_overflow |
|---------|-----------|-----------|--------------|
| SQLite | `NullPool` | — | — |
| MariaDB | `QueuePool` | 5 | 10 |

Use `NullPool` for SQLite because SQLite's `?mode=ro` URI does not support connection pooling safely.

### Security constraints

| Constraint | Value |
|------------|-------|
| Archive query time-range cap | 366 days maximum |
| DB query timeout | 30 seconds (both engines) |
| Custom SQL source | Config file only — never from HTTP request body or query params |
| Custom SQL validation | `EXPLAIN` pre-validation at startup, read-only transaction, 10-second timeout, DDL keyword blocklist |

---

## §4 Versioning

### URL path versioning

All API endpoints use the `/api/v1/` path prefix. The version segment is `v1`. Do not add `v2` segments until a breaking change is required.

### What constitutes a breaking change

A major version bump (`v1` → `v2`) is required when any of the following occur:

- An endpoint is removed or its path changes
- A required field is removed from a response schema
- A field's type or nullability changes in a backward-incompatible way
- A field is renamed
- Validation is tightened in a way that rejects previously valid requests
- A response's default behavior changes in a way that breaks existing clients

### What does not require a version bump

- Adding a new endpoint
- Adding a new optional field to a response
- Loosening validation (accepting more input shapes)
- Adding a new query parameter (optional, with documented defaults)
- Performance improvements with no wire-shape change

### No support-window promise

Clear Skies is GPL v3 software provided AS-IS. Do not include any support-window, security-backport, LTS, or end-of-life schedule language anywhere in API documentation or code comments.

### Error format

All error responses across all API versions use RFC 9457 `application/problem+json`. Never return a plain-text or HTML error body. The minimum error response shape:

```json
{
  "type": "urn:clearskies:<error-code>",
  "title": "Human-readable title",
  "status": 400
}
```

The `type` field is a URN, not a URL. Use `urn:clearskies:` as the prefix for all Clear Skies error types.

### OpenAPI

FastAPI auto-generates the OpenAPI specification. The spec is served at:

- `/api/v1/docs` — Swagger UI (interactive)
- `/api/v1/redoc` — ReDoc (readable)
- `/api/v1/openapi.json` — machine-readable spec

The canonical committed contract is `docs/contracts/openapi-v1.yaml`. When the implementation diverges from this contract, update the contract — do not suppress FastAPI's auto-generation to match a stale file.

---

## §5 Column Mapping

### Auto-mapping stock columns

Stock weewx columns (`outTemp`, `barometer`, `windSpeed`, etc.) auto-map silently at startup using a built-in lookup table. The operator does not interact with stock column mapping. The auto-map table ships as part of the API repo.

### Presenting non-stock columns

Non-stock columns discovered by schema reflection (step 7) are presented to the operator in the config UI wizard. For each non-stock column, the wizard offers a heuristic name-match suggestion (case-insensitive substring match against the canonical field catalog) and lets the operator pick a canonical field or select "not mapped."

### Persistence

The confirmed mapping persists in the operator's `api.conf` under `[column_mapping]`. The mapping takes effect on the next request — no service restart required when the operator updates a mapping through the config UI.

### Operator confirmation required

When all discovered columns are stock, the wizard presents the mapping table with pre-filled suggestions and requires operator confirmation before advancing. The operator always confirms — nothing auto-maps silently and the step never auto-advances (per ADR-056 amendment to ADR-035).

### Battery and diagnostic column exclusion

Columns matching any of the patterns `*Battery*`, `*Link*`, or `*Status*` are excluded from the mapping suggestion list. These columns carry sensor metadata, not weather observations. They are silently skipped — no warning to the operator.

### Validation at submit

The mapping table validates before advancing. Flag these errors inline with visual callouts:

- **Duplicate canonical mapping** — two archive columns mapped to the same canonical field
- **Invalid canonical name** — the operator entered a field name not in the canonical catalog

The step cannot advance while any inline error is present.

### weewx metadata import

Use `import weewx.units` to access `obs_group_dict` for unit group auto-detection. This maps each stock weewx field name to its `group_*` identifier, enabling the wizard to auto-populate the unit group for operator-confirmed custom columns where the group can be inferred from the field name pattern.

---

## §6 Unit System

### Scope

The API implements full weewx unit system compatibility across 14 unit groups. The dashboard has zero unit knowledge — it renders the `label` and `formatted` strings the API provides without performing any unit math.

### Unit groups

| Group | Valid units | Default (US) |
|-------|-------------|--------------|
| group_temperature | degree_F, degree_C, degree_K, degree_E | degree_F |
| group_speed | mile_per_hour, km_per_hour, knot, meter_per_second | mile_per_hour |
| group_speed2 | mile_per_hour2, km_per_hour2, knot2, meter_per_second2 | mile_per_hour2 |
| group_pressure | inHg, mbar, hPa, kPa | inHg |
| group_pressurerate | inHg_per_hour, mbar_per_hour, hPa_per_hour, kPa_per_hour | inHg_per_hour |
| group_rain | inch, cm, mm | inch |
| group_rainrate | inch_per_hour, cm_per_hour, mm_per_hour | inch_per_hour |
| group_altitude | foot, meter | foot |
| group_distance | mile, km | mile |
| group_direction | degree_compass | degree_compass |
| group_radiation | watt_per_meter_squared | watt_per_meter_squared |
| group_uv | uv_index | uv_index |
| group_percent | percent | percent |
| group_moisture | centibar | centibar |
| group_volt | volt | volt |

### The API is the single conversion authority

The API converts all values to operator display units before any response leaves the service. This applies to both REST responses and SSE events. The dashboard never receives raw weewx units — it receives converted values with labels attached.

### Target unit system inference

Derive the operator's target unit system (US / METRIC / METRICWX) from `api.conf [units][[groups]]`:

1. Check `group_temperature`.
2. If `degree_F` → target is US.
3. If `degree_C` → check `group_rain`: if `mm` → target is METRICWX; otherwise target is METRIC.

This inference is used internally for system-level documentation. The API converts per-field using the explicit per-group configuration — it does not apply a blanket unit system conversion.

### Column unit validation at startup

At startup (step 9), `_validate_column_units()` cross-checks the operator's confirmed unit settings against weewx metadata (`obs_group_dict`). On a mismatch, log a warning — do not exit. The operator-confirmed unit wins. Never silently revert to a different unit without the operator's explicit action.

### REST conversion path

1. Read archive record with `usUnits` field.
2. Look up each field's group via `obs_group_dict`.
3. Convert from archive source unit to operator display unit using `units/conversion.py`.
4. Attach `label` (from `units/labels.py`) and `formatted` string (from `api.conf [units][[string_formats]]`).
5. Return `{"value": ..., "label": "...", "formatted": "..."}`.

### SSE conversion path

1. Receive loop packet from socket reader (Unix socket from `ClearSkiesLoopRelay`).
2. Read `usUnits` field from the packet to identify the source unit system.
3. Convert each observation field to operator display unit.
4. Attach label.
5. Emit via SSE.

### Additional unit configuration

| Config subsection | Controls | v0.1 status |
|-------------------|----------|-------------|
| `[[string_formats]]` | Decimal places per unit (`degree_F = %.1f`) | Supported |
| `[[labels]]` | Display symbols per unit (`degree_F = " °F"`) | Supported |
| `[[ordinates]]` | Compass direction labels (N, NNE, NE, …) | Supported |
| `[[trend]]` | Barometer trend window and grace period | Supported |
| `[[time_formats]]` | strftime patterns for different contexts | Out of scope v0.1 |
| `[[degree_days]]` | Base temperatures for HDD/CDD/GDD | Out of scope v0.1 |

### Derived values

| Derived field | Computation | Location |
|---------------|-------------|----------|
| Beaufort number and label | Computed from wind speed in any source unit; converted to m/s internally before applying Beaufort thresholds | `units/derived.py` |
| `comfortIndex` | String selector: `"windChill"` (appTemp ≤ 50 °F), `"heatIndex"` (appTemp ≥ 80 °F), or `"none"` (moderate range). Dashboard reads this string to decide which comfort field to display. | `units/derived.py` |
| `barometerTrendDirection` | Direction string from `enrichment/barometer_trend.py` over the operator-configured trend window | Enrichment pipeline |
| `windDirCardinal`, `windGustDirCardinal` | 16-point compass codes computed by the API | Enrichment pipeline |

The dashboard does not recompute any of these from raw observations.

### Conversion factor accuracy

Conversion factors in `units/conversion.py` must exactly match weewx's own values. Source: weewx Python source code at `weewx/units.py`. Do not use approximations, Wikipedia values, or reference-book constants. Floating-point precision is handled by `string_formats` rounding at format time — do not round intermediate values.

### File layout

```
weewx_clearskies_api/
└── units/
    ├── __init__.py
    ├── groups.py        # Group definitions, valid units, field→group mapping
    ├── conversion.py    # Conversion factors (from weewx source)
    ├── labels.py        # Display symbols per unit
    ├── transformer.py   # Applies conversion + formatting to data dicts
    └── derived.py       # API-computed derived fields: beaufort(), comfort_index()
```

### Locale resolution and translated output (i18n)

**Single operator-configured locale — no per-request resolution.** The API resolves one active locale at startup from `api.conf [station] default_locale` (validated against the 13 supported locale codes in ADR-021 by `StationSettings`) and uses it for every response — REST and SSE alike. There is **no** `Accept-Language` header parsing anywhere in the API. Changing the language means the operator changes `default_locale` (via the wizard/admin UI, which writes `api.conf`) and the API restarts.

Startup wiring (`__main__.py`, immediately after settings load): `i18n.load_locales()` populates all 13 locale dictionaries from disk, then `i18n.set_active_locale(settings.station.default_locale)` sets the process-wide active locale. This runs once, early in startup, independent of which endpoints are later registered — there is zero per-request locale overhead.

`GET /api/v1/station` exposes the resolved value as `defaultLocale` (`StationMetadata.defaultLocale`) so the dashboard knows which language the API is emitting and can switch its own UI chrome to match (see DASHBOARD-MANUAL.md §3).

**`weewx_clearskies_api/i18n.py`** is the locale infrastructure module:

| Function | Purpose |
|----------|---------|
| `load_locales(locale_dir=None)` | Loads every `*.json` file under `weewx_clearskies_api/locales/` into memory, keyed by filename stem (`"en"`, `"de"`, `"pt-BR"`, …). Defaults to the `locales/` directory bundled next to the module. |
| `set_active_locale(locale)` / `get_active_locale()` | Process-wide active-locale state, set once at startup from `default_locale`. |
| `t(key, locale=None)` | Dot-path string lookup (e.g. `"beaufort.0"`, `"aqi.good"`, `"records.high_temperature"`). Resolution: requested locale (or the active locale) → `"en"` fallback → the key itself. An empty string in a not-yet-fully-translated locale file is treated as untranslated and falls through the same chain — never rendered blank. |
| `t_case(key, case="nominative", locale=None)` | Same resolution chain as `t()`, but when the locale value at *key* is a dict of grammatical-case → string (used for Russian inflected forms), returns the requested case, falling back to `"nominative"`. Returns a plain string unchanged regardless of `case`. |
| `format_number(value, decimals, locale=None)` | Locale-correct decimal separator and digit grouping via `babel.numbers.format_decimal()`. Builds a Babel pattern from `decimals` (e.g. `"#,##0.0"`) rather than using `%` formatting. |

`load_locales()` is also called defensively on first lookup if nothing has loaded yet (`_ensure_locales_loaded()`), so unit tests or any code path that resolves a string before `main()` runs still get correct behavior — but production startup's explicit call is the documented contract, not an implementation detail to rely on.

Locale files live at `weewx_clearskies_api/locales/{locale}.json` — 13 files (`en`, `de`, `es`, `fil`, `fr`, `it`, `ja`, `nl`, `pt-PT`, `pt-BR`, `ru`, `zh-CN`, `zh-TW`), all populated (Phase 6 of the i18n compliance plan). `en.json` is the authoritative source; every other locale is spot-checked against it for key coverage.

**`babel`** (PyPI package) is a runtime dependency of `weewx_clearskies_api`, added for `babel.numbers.format_decimal()`. It is the only new i18n dependency — no other translation framework (gettext, Django i18n, etc.) is used API-side.

**Unit labels resolve through the locale file, with operator override still winning.** `units/labels.py`'s `get_label(unit, overrides=None, locale=None)` resolution order:

1. `overrides` — the operator's `api.conf [units][[labels]]` config always wins, unchanged from pre-i18n behavior.
2. `locale` — looks up `unit_labels.<unit>` in the active locale file (e.g. `unit_labels.hPa` → `"гПа"` for `ru`). Used only when *locale* is passed and a non-key-echo translation exists.
3. `DEFAULT_LABELS` — the built-in English fallback table (unchanged).

`format_value(value, unit, overrides=None, locale=None)` still resolves the *decimal-place count* from the resolved `%`-style format string (`DEFAULT_FORMATS` or the operator's `[[string_formats]]` override), but when `locale` is passed, rendering itself goes through `i18n.format_number()` (babel) instead of Python `%` formatting — so `1013.2` renders as `1 013,2` for `ru` or `22,5` for `de` rather than always using `.` as the decimal separator. When `locale` is `None` (the pre-i18n call shape), behavior is byte-for-byte unchanged: plain `%` formatting. Every call site that renders a display value for a station configured with a non-English `default_locale` passes the active locale through.

**All API-computed display text resolves through the locale file** — this is not limited to unit labels:

| Text | Resolves via | Locale key pattern |
|------|--------------|---------------------|
| Beaufort labels | `units/derived.py`'s `beaufort(wind_speed, source_unit, locale=None)` | `beaufort.<0-12>` |
| AQI categories | `providers/aqi/_units.py`'s `epa_category(aqi, locale=None)` | `aqi.<category_key>` |
| Record labels | `services/records.py`'s per-`_RecordSpec` label resolution | `records.<labelKey>` |
| Moon traditional names | `services/almanac.py`'s `compute_special_moon_names(year, locale=None)` | `moon_names.<1-12>` |
| Temperature comfort tiers | `sse/temperature_comfort.py` | (comfort tier keys) |
| Sky condition labels | `sse/sky_condition.py` | `sky.<key>` (e.g. `sky.clear`, `sky.mostly_sunny`) |
| Precipitation intensity labels | `sse/conditions_text.py`'s `_precip_label()` | `precipitation.<key>` (e.g. `precipitation.light_rain`, `precipitation.freezing_rain`) |

Every function above accepts an optional `locale` parameter with the same contract: when omitted, it resolves via `i18n`'s active locale (which defaults to English until `set_active_locale()` runs); passing an explicit locale is how per-request or per-test overrides work. See §8 for the conditions-text composition engine that consumes these labels.

---

## §7 skin.conf Compliance

### Section disposition table

| skin.conf section | Disposition | Where it lands |
|-------------------|-------------|----------------|
| `[Units][[Groups]]` | KEEP | `api.conf [units][[groups]]` |
| `[Units][[StringFormats]]` | KEEP | `api.conf [units][[string_formats]]` |
| `[Units][[Labels]]` | KEEP | `api.conf [units][[labels]]` |
| `[Units][[Ordinates]]` | KEEP | `api.conf [units][[ordinates]]` |
| `[Units][[TimeFormats]]` | KEEP | `api.conf [units][[time_formats]]` |
| `[Units][[DegreeDays]]` | KEEP | `api.conf` |
| `[Units][[Trend]]` | KEEP | `api.conf` |
| `[Units][[TimeZone]]` | KEEP | Pre-fills wizard station step |
| `[Labels][[Generic]]` | KEEP | i18n override file |
| `[Texts]` | REPLACE | react-i18next (ingest translations) |
| `[Extras]` — branding | KEEP | Wizard branding step |
| `[Extras]` — feature toggles | INGEST, DEFER | Parsed and stored; display deferred |
| `[Extras]` — provider config | INGEST | Map API keys to provider config |
| `[Extras]` — social | KEEP | Wizard social config step |
| `[Extras]` — PWA/manifest | KEEP | Generate `manifest.json` |
| `[Extras]` — MQTT | IGNORE | MQTT eliminated (per ADR-058) |
| `[Almanac]` — moon_phases | KEEP | Feed 8 lunar phase labels into i18n |
| `[Generators]` | IGNORE | Cheetah-specific; silently skip |
| `[CheetahGenerator]` | IGNORE | Cheetah-specific; silently skip |
| `[ImageGenerator]` | IGNORE | Cheetah-specific; silently skip |
| `[CopyGenerator]` | IGNORE | Cheetah-specific; silently skip |

Silently skip IGNORE sections — no warnings to the operator for expected ignores. Log warnings for unknown `[Extras]` keys but do not treat them as fatal.

### Wizard import flow

The wizard offers two paths at step 0:

1. **Start fresh** — begin with defaults; no file import.
2. **Import from existing skin** — operator uploads a `skin.conf` file.

The parser uses `configobj` (same library weewx uses). Each subsequent wizard step displays imported values with a visual indicator ("imported from Belchertown") and allows the operator to edit before advancing.

### Image import resolution order

When a `skin.conf` import includes image paths (e.g., `logo_image`, `logo_image_dark`, `favicon`):

1. **Local filesystem** — if the wizard and weewx host are the same machine, resolve the path relative to the source skin directory and copy to Clear Skies static assets.
2. **API endpoint** — for split-host deployments, `GET /setup/skin-file?skin=Belchertown&path=images/logo.png` serves the file from the weewx host. Validate that the requested path stays within the skin directory (no directory traversal). Wizard downloads and stores locally.
3. **Neither accessible** — display an amber warning listing unreachable files with their original paths. Operator uploads replacements in the Branding wizard step or copies manually.

### Generated skin.conf

The wizard writes a `skin.conf` to `/etc/weewx/skins/ClearSkies/skin.conf` when the operator applies configuration. This file contains `[Units]` (all subsections), `[Labels][[Generic]]`, `[Extras]` (branding, social, feature toggles), and `[Almanac]`. Cheetah sections are omitted. The API reads unit preferences from `api.conf [units]` at runtime — the generated `skin.conf` is the portable canonical copy. Only the wizard writes these files; they cannot drift.

---

## §8 Conditions Text Engine

### Overview

The conditions text engine is a multi-module stateful system that produces the `weatherText` field in `/current` responses. It runs as part of the API's enrichment pipeline. `weatherText` is a REST-only field — it is not included in the SSE field map.

### Sky condition

**Primary source (daytime):** Kv-first decision tree in the Duchon & O'Malley (1999) tradition, using SkyPyEye Technology indices (adapted from CAELUS research library; Ruiz-Arias & Gueymard 2023). See ADR-073 for full scientific reasoning.

- Measure GHI (radiation from weewx) and clear-sky reference (maxSolarRad from weewx).
- Bin 5-second LOOP packets into 1-minute averages. Maintain a 30-minute ring buffer of MinuteRecord entries.
- Compute five indices from the ring buffer:

| Index | Formula | Window | Used in |
|-------|---------|--------|---------|
| Kcs | latest GHI / latest maxSolarRad, clamped [0, 1.2] | Latest minute | Cloud enhancement gate, uniform clear check |
| Km | (1/n) Σ(GHI_i / maxSolarRad_i) — mean of per-minute ratios | 30 min | Uniform branch (clear vs. overcast thickness) |
| Kmf | Same formula as Km | 10 min | Variable branch (coverage degree) |
| Kv | Σ\|ΔGHI - ΔmaxSolarRad\| / window_span | 30 min | Asymmetric gate (both must be calm for uniform) |
| Kvf | Same formula as Kv | 10 min | Asymmetric gate (either triggers variable), cloud enhancement |

Kv is the cumulative absolute first-derivative of **clear-sky-detrended** GHI. Each minute-to-minute GHI change has the corresponding maxSolarRad change subtracted before taking the absolute value and summing. This removes the deterministic solar geometry signal (the sun rising and setting changes GHI even under clear skies) and isolates cloud-induced variability. Without detrending, a clear afternoon's steady GHI decline produces elevated Kv, causing false "Mostly Clear" classifications.

**Scientific basis:** See ADR-073 §2 for why clear-sky detrending is necessary and the research (Stein et al. 2012, Coimbra et al. 2013) that establishes it as standard practice. Full citations in `docs/reference/sky-classification-science.md` §2.

**Classification — Kv-first decision tree:**

*Step 0: Pre-checks*

- Night/twilight (max(radiation, maxSolarRad) < 20 W/m²) → clear ring buffer, return None
- Solar elevation < 15° → return None (SZA guard; see below)
- Ring buffer < 3 entries → return None (insufficient data)

*Step 1: Cloud enhancement (evaluated before Kv split)*

| Conditions | Display label |
|-----------|---------------|
| Kcs > 1.06 AND Kv > 0.20 AND Kvf > 0.20 AND maxSolarRad > 100 W/m² | Partly Cloudy |

Cloud enhancement (GHI exceeding clear-sky) physically requires nearby cloud edges — a broken-cloud scenario. Maps to "Partly Cloudy" rather than "Clear" for physical accuracy. See ADR-073 §6.

*Step 2: Primary axis — asymmetric Kv/Kvf gate (uniform vs. variable sky)*

Six independent papers confirm the inverted-U relationship between cloud fraction and irradiance variability: variability peaks at ~50% cloud fraction and drops to near-zero at 0% (clear) and 100% (overcast). Low Kv means uniform sky (either clear or fully overcast). Elevated Kv means broken coverage. See ADR-073 §1.

The gate uses asymmetric sensitivity across the two variability windows:

| Condition | Branch | Rationale |
|-----------|--------|-----------|
| Kv ≥ 0.05 OR Kvf ≥ 0.05 | Variable sky → Step 4 | Responsive: any recent variability (even only in the 10-min window) means the sky is broken *now* |
| Kv < 0.05 AND Kvf < 0.05 | Uniform sky → Step 3 | Conservative: declaring "no breaks" requires sustained calm across both the 30-min and 10-min windows |

This asymmetry matches perception: a single cloud transit is immediately visible to anyone looking at the sky, but "the sky has been completely uniform for a while" is a stronger claim that needs more evidence. It also replaces explicit hysteresis — entering the variable branch is easy (fast response to cloud transits), returning to uniform is hard (prevents premature "Overcast" calls during brief lulls in a broken sky).

*Step 3: Uniform sky (both Kv AND Kvf < 0.05) — Km distinguishes clear vs. overcast*

| Conditions | Display label |
|-----------|---------------|
| Km > 0.85 AND Kcs > 0.80 | Clear |
| Km > 0.35 | Overcast |
| Km ≤ 0.35 | Heavy Overcast |

In the uniform branch, both variability windows confirm no cloud-edge transitions. Every non-clear outcome is overcast by definition (NWS OVC, 8/8, no gaps). Km distinguishes cloud thickness within the overcast family: thin to moderate uniform layer (Overcast) vs. thick layer with low transmittance, correlated with imminent precipitation (Heavy Overcast).

*Step 4: Variable sky (Kv OR Kvf ≥ 0.05) — Kmf distinguishes coverage degree*

| Conditions | Display label |
|-----------|---------------|
| Kmf > 0.85 | Mostly Clear |
| Kmf > 0.60 | Partly Cloudy |
| Kmf > 0.40 | Mostly Cloudy |
| Kmf ≤ 0.40 | Cloudy |

The variable branch uses **Kmf** (10-minute mean transmittance) instead of Km (30-minute). When the sky has breaks and conditions are actively changing, the last 10 minutes reflect what the visitor sees now — not what the sky looked like 20 minutes ago. The uniform branch retains Km (30-minute) because stable sky conditions warrant a longer average.

"Cloudy" here (NWS: 87–100%, includes 7/8 BKN) differs from "Overcast" (8/8 OVC) by the existence of breaks — variability confirms them even when infrequent.

**Dynamic threshold function:**

Km thresholds are not fixed constants. `get_dynamic_clear_threshold(α)` computes the boundary as a function of solar elevation α (degrees):

```
K_threshold(α) = K_min + (K_max - K_min) · (1 − e^(−b · α))
```

This exponential saturating function approaches K_max at high solar elevations and floors at K_min near the horizon. Scientific basis: Smith, Bright & Crook (2017) proved that clear-sky index distributions shift with solar elevation — fixed thresholds cannot work across all elevations. Full derivation in `docs/reference/sky-classification-science.md` §14.

**Default parameters:**

| Parameter | Default | Role |
|---|---|---|
| `dt_k_max_clear` | 0.80 | Asymptotic upper bound (K_max) for the clear/mostly-clear boundary |
| `dt_k_min` | 0.35 | Floor value (K_min) at zero elevation |
| `dt_b` | 0.1 | Scaling factor controlling how quickly the threshold rises with elevation |

**Threshold constants (non-dynamic):**

| Constant | Value | Role |
|---|---|---|
| `_KV_UNIFORM` | 0.05 | Primary split: uniform vs. variable sky |
| `_UNIFORM_CLEAR_MIN_KCS` | 0.80 | Uniform branch: clear sky Kcs sanity check |
| `_UNIFORM_HEAVY_MAX_KM` | 0.35 | Uniform branch: heavy overcast maximum Km (not elevation-adjusted) |

**How the dynamic threshold applies:**

Both the uniform and variable branches call `get_dynamic_clear_threshold(α)` with branch-specific K_max values:

| Branch | Boundary | K_max applied |
|--------|----------|---------------|
| Uniform | Clear vs. Overcast | 0.80 |
| Variable | Mostly Clear vs. Partly Cloudy | 0.80 |
| Variable | Partly Cloudy vs. Mostly Cloudy | 0.60 |
| Variable | Mostly Cloudy vs. Cloudy | 0.40 |

K_min (0.35) and b (0.1) are shared across all branches.

**Operator adjustability:** `configure()` accepts `dt_k_max_clear`, `dt_k_min`, `dt_b`, and `sza_guard_elevation` to override defaults. These will be exposed in `api.conf [sky_classification]` (not yet wired — future task).

**Temporal coherence filter:** A raw classification must persist for 5 consecutive minutes before becoming the stable label. On startup, 2-minute grace applies. (Reduced from 15/3 minutes — the 30-minute Kv/Km averaging and the asymmetric Kv/Kvf gate already provide substantial smoothing; stacking a 15-minute coherence filter on top created up to 45 minutes of lag, which is unacceptable for a weather display.)

**Startup backfill:** On API restart, `backfill()` seeds the ring buffer from archive records (last 30 minutes) for immediate classification. Full accuracy after ~30 minutes of live LOOP data.

**GHI mirroring across sunrise/sunset:** At sunrise, the trailing 30-minute window has only a few minutes of data. Under overcast, this inflates Km (diffuse radiation at low angles is a high fraction of the small clear-sky reference), producing incorrect sunny/scattered labels. The mirroring algorithm (adapted from CAELUS library's `sky_indices.py:mirror_ghi_with_pandas()`) generates synthetic pre-sunrise data points using cos(zenith) interpolation from post-sunrise measurements, stabilizing the rolling statistics. Station coordinates (lat/lon/altitude from `services/station.py`) and Skyfield ephemeris (from `services/almanac.py`) are used to compute cos(zenith) for both real and mirrored entries. Full scientific description in `docs/reference/sky-classification-science.md` §3. See ADR-073 §4.

**SZA < 75° classification guard:** When solar elevation < 15° (SZA > 75°), `classify()` returns None. The downstream consumer (`enrichment/weather_text.py`) falls back to provider cloud cover. Below 15° elevation, pyranometer readings are dominated by diffuse radiation and cosine error — the clear-sky index loses discriminatory power. Solar elevation is computed via Skyfield from station coordinates (same ephemeris used by the almanac service). The `_MIN_SOLAR_RAD = 20 W/m²` proxy is retained for ring buffer data acceptance — data still accumulates below the SZA threshold to be available when elevation crosses 15°. See ADR-073 §5.

**Haze/smoke detection:** Implemented — see §8 Haze detection subsection below (ADR-067).

**Secondary source (night / twilight / startup / no pyranometer):** Provider cloud cover percentage, via `_cloud_pct_to_sky()`. Thresholds: ≤10% Clear, ≤25% Mostly Clear, ≤50% Partly Cloudy, ≤85% Mostly Cloudy, ≤95% Cloudy, >95% Overcast. Note: these code thresholds are wider bins than NWS ASOS okta-based categories and are a pragmatic approximation. Operator adjustability planned via the admin UI.

**Scientific basis:** ADR-073 records the scientific reasoning behind every threshold and classification decision. Full citations in `docs/reference/sky-classification-science.md`.

### Day/night display vocabulary

Apply day/night vocabulary at display time via substring replacement ("Clear"→"Sunny", "Mostly Clear"→"Mostly Sunny"):

| Classification | Day display | Night display |
|----------------|-------------|---------------|
| Clear | Sunny | Clear |
| Mostly Clear | Mostly Sunny | Mostly Clear |
| Partly Cloudy | Partly Cloudy | Partly Cloudy |
| Mostly Cloudy | Mostly Cloudy | Mostly Cloudy |
| Cloudy | Cloudy | Cloudy |
| Overcast | Overcast | Overcast |
| Heavy Overcast | Heavy Overcast | Heavy Overcast |

Solar zenith > 96° = night; 75–96° = twilight/SZA guard zone (fall back to provider); < 75° = day (solar classification active). Solar elevation computed via Skyfield from station lat/lon/altitude (`services/almanac.py`). The SZA < 75° guard (elevation ≥ 15°) gates classification; below this threshold `classify()` returns None and the provider fallback supplies the sky label.

**Scientific basis:** ADR-073 (supersedes ADR-044). Full citations in `docs/reference/sky-classification-science.md`.

### Precipitation

**Primary source:** Local rain gauge (`rainRate`). Use WMO/AMS thresholds (in in/hr; convert from station units before comparing):

| rainRate | Category |
|----------|----------|
| 0 or null | No precipitation |
| > 0 and < 0.10 | Light Rain |
| ≥ 0.10 and < 0.30 | Moderate Rain |
| ≥ 0.30 | Heavy Rain |

**Frozen precipitation:** When `rainRate > 0` AND provider reports `precipType` of "snow", "freezing-rain", or "sleet", use the provider's type only if the Stull (2011) wet-bulb temperature is ≤ 35 °F. Above 35 °F, frozen precipitation is thermodynamically implausible — use "Rain" regardless of provider forecast.

Wet-bulb formula (Stull 2011, T in °C, RH in %):

```
Tw = T × atan(0.151977 × (RH + 8.313659)^0.5) + atan(T + RH)
   − atan(RH − 1.676331) + 0.00391838 × RH^1.5 × atan(0.023101 × RH)
   − 4.686035
```

### Wind

**Hybrid Beaufort/GFE wind scale** (ADR-082, settled decision #11). Below 30 mph: Beaufort labels provide fine-grained descriptors. At 30 mph and above: GFE/NWS descriptors replace Beaufort to avoid misleading labels (Beaufort 12 "Hurricane" implies a tropical system — wrong for straight-line thunderstorm winds or derechos; "Hurricane Force Winds" describes speed without implying storm type). All comparisons use m/s internally — convert from station unit before comparing.

| Speed (mph) | m/s range | Label | Source |
|---|---|---|---|
| < 1 | < 0.5 | Calm | Beaufort 0 |
| 1–3 | 0.5–1.5 | Very Light Breeze | Beaufort 1 |
| 4–7 | 1.6–3.3 | Light Breeze | Beaufort 2 |
| 8–12 | 3.4–5.4 | Gentle Breeze | Beaufort 3 |
| 13–17 | 5.5–7.9 | Moderate Breeze | Beaufort 4 |
| 18–24 | 8.0–10.7 | Fresh Breeze | Beaufort 5 |
| 25–29 | 10.8–12.9 | Strong Breeze | Beaufort 6 (partial) |
| 30–39 | 13.0–17.4 | Windy | GFE/NWS |
| 40–49 | 17.5–21.9 | Very Windy | GFE/NWS |
| 50–73 | 22.0–32.6 | Strong Winds | GFE/NWS |
| ≥ 74 | ≥ 33.0 | Hurricane Force Winds | GFE/NWS |

Labels use sentence case. Beaufort 0 ("Calm") appears in the composed text — calm is a real atmospheric state, not the absence of data.

**Gusty qualifier:** Report gusts only when `windGust - windSpeed > 10 mph`. Phrase: "with gusts to around {gust speed} mph" (GFE phrasing — replaces the previous "and Gusty" qualifier). Convert speeds to mph before comparison regardless of station unit. The qualifier only fires when wind is not Calm.

### Temperature-comfort (2D matrix)

**Temperature axis** — apparent temperature (`appTemp` in °F):

| Tier | appTemp range | Base label |
|------|---------------|------------|
| 1 | ≤ −10 °F | Dangerously Cold |
| 2 | −9 to 0 °F | Bitter Cold |
| 3 | 1 to 10 °F | Extreme Cold |
| 4 | 11 to 20 °F | Very Cold |
| 5 | 21 to 32 °F | Cold |
| 6 | 33 to 45 °F | Chilly |
| 7 | 46 to 60 °F | Cool |
| 8 | 61 to 75 °F | Pleasant |
| 9 | 76 to 85 °F | Warm |
| 10 | 86 to 95 °F | Hot |
| 11 | 96 to 104 °F | Very Hot |
| 12 | ≥ 105 °F | Dangerously Hot |

**Moisture axis** — dewpoint (°F):

| Tier | Dewpoint range | Moisture modifier |
|------|----------------|-------------------|
| A | < 45 °F | (omitted) |
| B | 45–54 °F | (omitted) |
| C | 55–59 °F | Slightly Humid |
| D | 60–64 °F | Humid |
| E | 65–69 °F | Very Humid |
| F | 70–74 °F | Oppressive |
| G | ≥ 75 °F | Miserable |

**Composition rules:**

1. Cold temperatures (appTemp ≤ 32 °F, tiers 1–5): always omit moisture modifier. Output = temperature label only.
2. Warm temperatures, dry moisture (tiers 6–12 × A–B): output = temperature label only.
3. Warm temperatures, humid moisture (tiers 6–12 × C–G): output = temperature label + "and" + moisture label.
4. **NWS Heat Index danger escalation** (overrides rules 1–3): HI ≥ 125 °F → "Extreme Danger Heat"; HI ≥ 104 °F → "Dangerous Heat".
5. **NWS Wind Chill danger escalation** (overrides rules 1–3): WC ≤ −45 °F → "Extreme Danger Cold"; WC ≤ −25 °F → "Dangerous Cold".
6. **Near-saturation override:** When dewpoint depression (outTemp − dewpoint) ≤ 5 °F, append "and Foggy" to any output from rules 1–5.

When `appTemp` is null or absent, omit the temperature-comfort component entirely.

### Input stability

Apply three stability mechanisms before any threshold comparison:

**Smoothing windows:**

| Input | Window |
|-------|--------|
| Solar radiation (GHI → 1-min bins) | 30 min |
| UV | Directional hysteresis (see below) |
| appTemp, dewpoint, outTemp | 10 min |
| windSpeed, windGust | 5 min |
| rainRate | 2 min |
| heatIndex, windChill | 10 min |

**Hysteresis bands:**

| Dimension | Band |
|-----------|------|
| Temperature thresholds | ±2 °F |
| Wind thresholds | ±2 mph |
| Dewpoint thresholds | ±2 °F |
| Rain rate thresholds | ±0.02 in/hr |

**Minimum hold time:** 5 minutes. After composition, hold the conditions text string for 5 minutes before allowing any change, even when smoothed + hysteresis inputs produce a different result.

**Sky condition stability:** The sky classifier uses a temporal coherence filter instead of hysteresis — a raw classification must persist for 15 consecutive minutes before replacing the stable label. This is independent of the 5-minute conditions text hold time, which still applies to the composed `weatherText` string.

**UV directional hysteresis:** The UV field on `/current` uses asymmetric hysteresis instead of a rolling mean. Rises require 3 consecutive samples above the current displayed value (~15 seconds) before the displayed value updates upward. Falls require 60 consecutive samples below the current displayed value (~5 minutes) before stepping down to the current reading. This prevents transient cloud-shadow dips from showing a misleadingly low UV while allowing genuine increases to surface quickly. The dashboard excludes UV from the SSE overlay merge — the card reads the REST-enriched value only. Raw UV continues to flow through SSE for charts and other consumers that need instantaneous readings.

### Composition order

Assemble components in this order: **[temperature-comfort, sky, wind, precipitation]**. Drop null or omitted components.

| Number of non-null parts | Format |
|--------------------------|--------|
| 1 | `"{part}"` |
| 2 | `"{a}, with {b}"` |
| 3+ | `"{a}, {b}, with {last}"` |

Examples: "Warm and Humid, Overcast, with Light Rain" / "Pleasant, Partly Cloudy, with Moderate Breeze" / "Chilly, with Light Rain".

### Locale-aware composition (i18n)

`sse/conditions_text.py`'s `build_weather_text()` / `_compose()` produce `weatherText` in the operator's `default_locale` (§6). All labels the composer assembles — temperature-comfort, sky condition (with the day/night vocabulary swap), wind (hybrid Beaufort/GFE, with the "with gusts to around X mph" qualifier — see §15 for the hybrid wind treatment), and precipitation intensity — resolve through `i18n.t()` against the active locale before composition, per the table in §6.

**What is implemented:** a single generic template composer, used for all 13 locales including the three CJK locales (`ja`, `zh-CN`, `zh-TW`). Each locale file's `composition` block supplies three values that `_compose()` reads:

```json
{
  "composition": {
    "separator": "、",
    "connector_and": "と",
    "connector_with": "を伴う"
  }
}
```

- `separator` joins 3+ parts.
- `connector_and` is used before the final part when it equals the locale's Beaufort-0 ("Calm") text (avoids the unnatural "with Calm").
- `connector_with` is used before the final part otherwise (avoids a double "and" when the temperature-comfort label is itself compound, e.g. "Warm and Humid").

**Component order is fixed in Python, not locale-driven.** `build_weather_text()` always assembles `[temperature-comfort, sky, wind, precipitation]` in that order for every locale — the order in which `parts.append(...)` calls occur in the function body.

**Not implemented (deferred):** the i18n compliance plan's research phase (§1D of `docs/archive/I18N-COMPLIANCE-PLAN.md`) called for three additional pieces that are **not** present in the current code, even though every locale file carries JSON fields that look like wiring for them:

- **Per-locale composer dispatch.** `ja.json`, `zh-CN.json`, and `zh-TW.json` each carry `"composition": {"pattern": "custom", "composer": "ja"}` (or `"zh"`) — but no code reads `composition.pattern` or `composition.composer`, and there is no `locales/composers/` module. The generic `_compose()` above runs unconditionally for every locale.
- **CJK compound-expression composition.** JMA-style forms (時々/一時/のち operators producing e.g. 曇り時々晴れ) and CMA-style space-separated wind-grade forms were researched but not built. Japanese and Chinese `weatherText` at runtime uses the same English-derived word order and punctuation-joining pattern as every other locale, with Japanese/Chinese words and the locale's own separator/connector substituted in — this produces grammatically acceptable but not JMA/CMA-native phrasing.
- **Locale-driven component order.** Locale files (e.g. `ru.json`, `de.json`) carry a `composition.order` array (`["sky", "temperature", "wind", "precipitation"]` for German and Russian, reflecting those languages' natural word order) — but `build_weather_text()` never reads it; the Python-side order is fixed for all locales.
- **Case-inflected composition for Russian.** `i18n.t_case()` exists and correctly resolves grammatical-case dicts (nominative/instrumental/genitive), but `_compose()` calls only `t()` — the composition path does not invoke `t_case()`, so Russian `weatherText` uses the nominative form throughout rather than switching to instrumental/genitive forms for "with X" / "without X" constructions.

None of this is a defect in what shipped — the template approach produces correct, readable `weatherText` in all 13 locales. It is a scope reduction from the plan's research relative to native-speaker phrasing for `ja`/`zh-CN`/`zh-TW`/`ru`. Tracked as a deferred item in `docs/archive/I18N-COMPLIANCE-PLAN.md`.

### Startup

On API restart, `backfill()` seeds the sky classifier's ring buffer from archive records (last 30 minutes), enabling immediate classification. A 3-minute startup grace period applies to the temporal coherence filter. If no archive records are available (fresh install), fall back to provider cloud cover until the ring buffer accumulates ≥ 3 minutes of live LOOP data. If no provider data is available, report sky condition absent (wind and comfort components still compose).

### Transport

`weatherText` is REST-only. It appears in `/current` responses. It is not transmitted via SSE.

### Enrichment processor registration order

Register processors in this exact order — the smoother must run before classifiers:

1. `input_smoother`
2. `uv_smoother`
3. `sky_tap`
4. `wind_rolling_window`
5. `lightning_strike_buffer`
6. `scene_packet_tap`

### Endpoint enrichment registration

Two endpoint keys receive enrichment:

| Endpoint key | Enrichments registered |
|--------------|------------------------|
| `"current"` | barometer_trend, wind_rolling_average, lightning_history, weather_text, uv, scene (6 total) |
| `"almanac/planets"` | planet_viewing (1 total) |

### Haze detection

Two-channel confirmation is required before the engine labels conditions as hazy. Haze is only reported when BOTH channels confirm: (1) pyranometer Kcs deficit below the dynamic clear-sky threshold (Channel 1 uses `get_dynamic_clear_threshold(α)` from `sky_condition.py` — the same elevation-dependent threshold function used by the sky classifier) AND (2) PM2.5 or PM10 from an observed-data AQI provider (ADR-066) exceeds the confirmation threshold.

**Solar elevation gate:** el > 15° required. Below 15°, the clear-sky index is unreliable due to diffuse radiation dominance and cosine error. Haze detection is inactive when el ≤ 15°. This gate matches the sky classifier's SZA guard.

**PM confirmation thresholds:**

| RH range | PM2.5 threshold | PM10 threshold | Basis |
|----------|----------------|----------------|-------|
| < 60% (dry) | > 50 µg/m³ | > 100 µg/m³ | CMA dry haze threshold (~54 µg/m³ PM2.5 for vis < 10 km). Coarse mass scaled by IMPROVE extinction ratio. |
| 60–80% (moderate) | > 35 µg/m³ | > 75 µg/m³ | CMA moderate humidity, EPA 24-hr NAAQS, WMO dusty-air midpoint, China secondary standard. |
| 80–90% (humid) | > 25 µg/m³ | > 50 µg/m³ | Hygroscopic swelling — less mass produces same extinction. EEA annual standard, WMO/Australia lower bound. |

Both PM2.5 and PM10 are independent first-class indicators evaluated in parallel. Either species alone confirms Channel 2. PM10 is NOT a fallback. See `docs/reference/haze-detection-research.md` for the full research backing these thresholds.

**f(RH) hygroscopic correction:** Applied to the Kcs-deficit channel before threshold comparison:

```
f(RH) = [(1 - RH) / (1 - RH_ref)]^(-γ)
```

Default γ = 0.45 (moderate, composition-unknown). γ is a composition property (range 0.12 for mineral dust to 1.52 for sea salt per Hanel 1976 and Tang 1996) — it is NOT a particle-size property. Operator-configurable by region via admin UI.

**RH type discriminator:**

| RH range | Classification |
|----------|---------------|
| < 80% | Dry haze |
| 80–90% | Damp haze (hygroscopic swelling enhances scattering) |
| > 90% | Defer to fog/mist detection (ADR-069) — do NOT report haze |

**Gates and suppression:**

1. **Wet deposition gate:** Suppress haze during active precipitation and for 30 minutes after rain ends. Rain scavenges aerosols.
2. **Temporal coherence:** 5-minute persistence filter (matches sky classifier coherence window). Prevents haze label flicker.
3. **Clear-sky-only constraint:** Haze is a clear-sky modifier. Do NOT apply haze when sky is classified as Mostly Cloudy, Cloudy, Overcast, or Heavy Overcast. "Hazy and Overcast" is invalid.
4. **Stale PM data:** If last PM reading is > 2 hours old, treat as unavailable. Do not conclude "no haze" from stale data — absence of fresh evidence is not evidence of absence.

**Haze-eligible providers:** Only AQI providers where `ProviderCapability.is_observed_source = True` (ADR-066). Open-Meteo (CAMS model) is not an observed-data source and its PM readings are never used for haze confirmation. (OpenWeatherMap AQI and OpenAQ AQI were removed entirely from the AQI domain in Phase 2 API removals — OWM AQI returned SILAM model predictions, not observed data; OpenAQ AQI was an orphaned module never wired into dispatch.)

**Graceful degradation:** When no observed PM data is available, the haze channel is absent. The existing sky classifier continues operating unchanged. No haze label is emitted.

**Display format:**

| Verbosity | Format |
|-----------|--------|
| Standard / verbose | "Sunny. Hazy." — separate sentence (NWS convention) |
| Terse | "Sunny, Hazy" — compound form |

**WMO weather code:** 05 (Haze). Priority ordering: precipitation > fog > mist > haze > sky.

### Haze detection configuration (api.conf [conditions])

The following keys in the `[conditions]` section of `api.conf` control haze detection behavior (ADR-067/068). All keys are optional; defaults match the algorithm constants.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `haze_detection` | bool | `true` | Enable or disable haze detection entirely. When `false`, `detect_haze()` always returns `None`. |
| `haze_aqi_provider` | str or absent | (inherits from `[aqi]`) | Override the AQI provider used for haze PM data. If absent or empty, uses the provider configured in `[aqi]`. |
| `gamma` | float | `0.45` | Hygroscopic correction exponent γ (Hanel 1976 / Tang 1996). Controls how strongly relative humidity amplifies apparent aerosol extinction. Advanced operator override — the default 0.45 is the composition-unknown value suitable for most stations. Range: 0.1–1.0. |
| `sky_decay_rate` | float | `0.06` | Controls how aggressively sky classification thresholds adjust at lower sun angles. Smaller values = more threshold reduction at moderate elevation (20–30°). Maps to the `b` parameter in the exponential decay formula. Range: 0.01–0.20. |
| `sky_clear_threshold` | float | `0.80` | Km boundary for "Clear" classification in the uniform branch. Higher values require more solar radiation to classify as clear. Range: 0.5–1.0. |
| `sky_threshold_floor` | float | `0.35` | Minimum threshold value at the horizon — the floor that all dynamic thresholds decay toward at low sun angles. Range: 0.1–0.5. |
| `sky_min_elevation` | float | `15.0` | Minimum solar elevation (degrees) for sky classification. Below this angle, the classifier returns None and defers to provider cloud cover. Range: 5.0–30.0. |

Validation errors in any of these keys cause a fatal startup failure with a descriptive message.

**Graceful sensor failover:**

| Sensor absent | Failover |
|---------------|---------|
| `radiation` (no pyranometer) | Sky: provider cloud cover % (unchanged). Haze: provider present weather (HZ) 24/7. |
| `dewpoint` (no hygrometer) | Fog/mist: provider present weather (BR/FG). f(RH) correction: skipped (uncorrected Kcs deficit used). |

Dashboard never shows null data — absent sensors silently defer to provider present-weather codes.

---

### Fog/mist detection

Replaces the single-variable T-Td ≤ 1°F near-saturation override (Temperature-comfort rule 6). The multi-parameter algorithm below achieves >90% hit rate vs ~40% false-alarm rate from single-variable T-Td detection (Izett et al. 2018, PMC6208920). Note: the Temperature-comfort rule 6 text remains in place until a dedicated cleanup pass — this subsection is the operative rule.

**T-Td gate (ASOS standard):** Widened from 1°F to ≤ 4°F. Fog and mist are suppressed when T-Td > 4°F.

**Fog/mist split:**

| T-Td | Classification | WMO code |
|------|---------------|----------|
| ≤ 2°F | Foggy | 45 (Fog) |
| 2–4°F | Misty | 10 (Mist) |

**Wind gate:** Convert from the operator's configured unit system to m/s before comparison.

| Wind speed | Fog-eligible | Mist-eligible |
|------------|-------------|---------------|
| ≤ 3 m/s (~7 mph) | Yes | Yes |
| 3–7 m/s (~15 mph) | No | Yes |
| > 7 m/s | No — suppressed | No — suppressed |

**Daytime solar suppression:**

| Condition | Result |
|-----------|--------|
| Kcs > 0.3 AND T-Td 2–4°F | Suppress — humid air, not fog |
| Kcs > 0.3 AND T-Td ≤ 2°F | Do NOT suppress — dense fog persists through sunrise |

**PM2.5 disambiguation:** When T-Td ≤ 4°F AND PM2.5 > 35 µg/m³, report "Hazy" rather than "Foggy" or "Misty". Elevated PM in near-saturated conditions indicates particulate haze with moisture absorption, not water-droplet fog. Only applied when fresh PM data is available; if PM data is absent or stale, fog/mist classification proceeds without this check.

**Additional gates:**

1. **Rain gate:** Suppress fog/mist during active precipitation. Precipitation fog is a distinct phenomenon not reported here.
2. **Fog dissipation:** After sunrise, suppress fog label when Kcs > 0.5 AND T-Td is widening beyond 4°F. Prevents a stale fog label persisting into a sunny morning.
3. **Temporal coherence:** 15-minute persistence filter. Prevents rapid cycling when T-Td oscillates near threshold.

**Display format:** "Foggy." or "Misty." as a separate sentence (NWS convention).

**Irreducible limitation:** Without a visibility sensor, the engine reports conditions favorable for fog, not confirmed fog. The provider cross-check mitigates this by requiring a visibility-equipped station to corroborate, but the fundamental limitation remains for hyper-local fog events. This matches WMO Code 4680 automated-station constraints.

---

### Provider cross-check (fog/mist)

Local T-Td detection identifies conditions favorable for fog but cannot confirm ground-level visibility reduction without a visibility sensor. To reduce false positives — particularly in coastal environments where marine-layer humidity routinely drives T-Td below 2°F without producing fog — the engine requires provider corroboration before reporting fog or mist.

**Bidirectional confirmation table:**

| Local sensors | Provider observation | Result |
|---|---|---|
| Favorable (T-Td ≤ 2°F, calm) | Reports fog/mist | **Foggy/Misty** — both agree |
| Favorable | No fog/mist reported | **Suppress** — near-saturation but no visibility confirmation |
| Favorable | Provider data stale/unavailable | **Allow local** — absence of data is not evidence of absence |
| Not favorable (T-Td > 4°F or windy) | Reports fog/mist | **No adoption** — local conditions do not support fog at this station |

**Provider keyword matching:** Lowercase provider weather text, substring search for `"fog"` or `"mist"`. Matches: "Fog", "Dense Fog", "Patchy Fog", "Fog/Mist", "Mist", etc.

**Stale-data grace:** When provider data is unavailable (> 2 hours old or never set), the cross-check does not fire. Local detection stands on its own. This prevents the system from going silent about fog when the provider is down.

**Scientific justification:** ASOS/AWOS visibility sensors (WMO, ICAO) are the operational standard for fog detection. This station lacks a visibility sensor; the cross-check supplements local thermodynamic detection with a remote visibility observation from the nearest equipped station.

**Tradeoff:** Reduced false positives at the cost of delayed detection for genuinely hyper-local fog events. Real fog at the station may not be reported until the provider's station (~5-30 min lag) also detects it. For stations in marine-layer-prone coastal environments, this tradeoff favors accuracy over immediacy.

**Graceful degradation:** When no forecast provider is configured or the provider does not supply current weather text, the cross-check is inactive. Local fog detection operates standalone (original behavior).

---

### Nighttime mode

At night (solar elevation below the haze detection gate, el ≤ 10–15°), the pyranometer contributes nothing to haze detection. Three channels are assigned distinct data sources:

| Condition | Nighttime source |
|-----------|-----------------|
| Cloud cover | Provider observation (existing behavior, unchanged) |
| Haze / smoke | Provider current-conditions present weather field |
| Fog / mist | Local multi-parameter detection (ADR-069) — T-Td + wind |

**Rationale for split:** Provider stations (ASOS/AWOS at airports, EPA monitors) have visibility sensors and present weather detectors. For haze, their sensor suite outperforms PM-only local estimation. For fog, the station-level T-Td measurement is genuinely more local than the nearest airport observation (potentially 10+ km away) — hyper-local sensors add real value for radiation fog that forms post-sunset.

**Sunrise handoff:** When solar elevation crosses the haze detection gate (10–15°), the full local two-channel model resumes. Provider haze/smoke stops being authoritative; local detection takes over.

**Fog continuity:** `detect_fog_mist()` runs continuously regardless of mode. At night, solar radiation is zero, so daytime solar suppression does not trigger — fog detection proceeds on T-Td and wind alone. There is no handoff gap at sunrise; the solar dissipation check (Kcs > 0.5) simply becomes active as an additive condition.

**Provider data freshness:** If provider data is > 2 hours old at night, nighttime haze is unavailable — not "no haze." Apply the same stale-data suppression rule as daytime PM (absence of fresh data is not evidence of absence).

**Graceful degradation:** Provider absent or present-weather field missing = no haze reported at night. Fog/mist continues from local detection unaffected.

---

### Observation model

A METAR-like structured intermediate representation is populated from the enrichment pipeline on each observation cycle, before text generation. All fields are nullable.

**Local-source to METAR/WMO field mapping:**

| Local source | METAR/WMO field |
|-------------|----------------|
| `outTemp` | Temperature |
| `dewpoint` | Dewpoint |
| `windSpeed` + `windDir` + `windGust` | Wind group |
| SkyPyEye sky class | Sky condition (CLR / FEW / SCT / BKN / OVC) |
| Haze detection (ADR-067) | Present weather HZ |
| Fog/mist detection (ADR-069) | Present weather FG / BR |
| Precipitation type + rate | Present weather RA / SN / FZRA / etc. |
| `barometer` + trend | Pressure group |

**SkyPyEye-to-okta mapping:**

| SkyPyEye class | METAR sky code | Oktas |
|-------------|---------------|-------|
| CLOUDLESS | CLR | 0 |
| THIN_CLOUDS | FEW / SCT | 1–4 |
| SCATTERED | SCT | 3–4 |
| MOSTLY_CLOUDY | BKN | 5–7 |
| OVERCAST | OVC | 8 |

Specific okta assignment within each SkyPyEye class uses the Km thresholds defined in §8 Sky condition (Kv-first threshold constants table).

---

### Present weather codes

The `_derive_weather_code()` function emits WMO Code Table 4677/4680 codes. Priority ordering (highest to lowest):

1. Precipitation (RA / SN / FZRA / etc.)
2. Thunderstorm (96)
3. Fog (45)
4. Mist (10) — new, ADR-069
5. Smoke (06) — new, icon system expansion
6. Dust (07) — new, icon system expansion
7. Haze (05) — new, ADR-067
8. Sky condition

**Active code set:**

| WMO code | Phenomenon | Status |
|----------|-----------|--------|
| 05 | Haze | Added — ADR-067 |
| 06 | Smoke | New — icon system expansion. Forecast: provider mapping. Conditions engine: provider weather text keyword scan ("smoke", "smoky"). |
| 07 | Dust / blowing dust | New — icon system expansion. Forecast: provider mapping. Conditions engine: provider weather text keyword scan ("dust", "dusty", "sand", "sandy", "blowing dust"). |
| 08 | Volcanic ash | New — icon system expansion |
| 10 | Mist | Added — ADR-069 |
| 45 | Fog | Existing |
| 48 | Depositing rime fog (ice on surfaces + fog) | Added — ADR-070 |
| 60–69 | Rain variants | Existing |
| 70–79 | Snow variants | Existing |
| 79 | Ice pellets | Existing |
| 96 | Thunderstorm | Existing |

Codes 4, 5, 6, 7, 8, 10, and 79 are Clear Skies API extensions to the WMO code table. Standard WMO codes 0–3, 45–99 are used as-is from the Open-Meteo API. The extension codes do not collide with any WMO codes used by Open-Meteo (which uses only 0–3, 45–99).

Anti-pattern: do NOT emit both a precipitation code and a fog/mist/haze code for the same observation cycle. Precipitation takes priority; fog/mist/haze codes are suppressed during active precipitation.

---

### Text generation engine

Three verbosity levels are available. `weatherText` carries the terse level (backward compatible). Two additional fields are populated on `/api/v1/current`. As of ADR-082 (NWS GFE Text Generation System with WorldCast Technology), the standard and verbose tiers are generated by the shared GFE text engine (`sse/gfe/composer.py`'s `compose_current_text()`, called via `sse/gfe/__init__.py`'s `generate_current_text()`) instead of the retired `sse/text_generator.py` module. The terse tier is untouched — it remains `sse/conditions_text.py`'s `build_weather_text()`.

**Verbosity levels:**

| Level | Field | Style |
|-------|-------|-------|
| Terse | `weatherText` | Current style — compound form OK: "Sunny, Hazy, Warm and Humid." |
| Standard | `weatherTextStandard` | NWS one-sentence per component: "Sunny. Hazy. Temperature in the mid 80s. South winds around 8 mph." |
| Verbose | `weatherTextVerbose` | Full narrative: "Currently in the mid 80s under hazy sunshine. Dew point in the lower 60s. South winds around 8 mph with gusts to around 25 mph." |

**GFE threshold tables** (ported from AWIPS-II GFE text formatter, public domain):

Sky coverage buckets (6), used for FORECAST periods (ADR-082 GFE text engine):

| Upper threshold (%) | Daytime phrase | Nighttime phrase |
|---|---|---|
| 5 | Sunny | Clear |
| 25 | Sunny | Mostly Clear |
| 50 | Mostly Sunny | Partly Cloudy |
| 69 | Partly Sunny | Mostly Cloudy |
| 87 | Mostly Cloudy | Mostly Cloudy |
| 100 | Cloudy | Cloudy |

Note: this is the GFE 6-bucket table, ported from the AWIPS-II GFE text formatter, used for forecast-period text composition AND as the current-conditions fallback when `sky_label` is unavailable (no pyranometer classification yet, e.g. missing-Kcs / startup) but a provider cloud-cover percentage is present. When a SkyPyEye classification IS available, current conditions use the separate SkyPyEye 7-level classification (which includes Overcast/Heavy Overcast), documented elsewhere in this manual — SkyPyEye output is preferred and takes priority over the GFE bucket fallback.

Wind descriptor thresholds (natively in mph — see "Unit-aware rendering" below for how these render under METRIC/METRICWX):

| Threshold | Descriptor |
|-----------|-----------|
| < 5 mph | Calm |
| 5–15 mph | Light |
| ~N mph (sustained) | Around N |
| N–M mph range | N to M |
| Gusts | "with gusts to around N" when gust − sustained > 10 mph |

Wind category breaks: 25 / 30 / 40 / 50 / 74 mph. These hybrid Beaufort/GFE descriptor breaks apply to the terse tier's compound wind label (`sse/conditions_text.py`, always active) and to `sse/gfe/wind_phrases.py`'s standalone `wind_descriptor()`; the standard/verbose current-conditions wind sentence itself is a direction + magnitude(+gust) phrase with no adjective label, matching `wind_phrase()`'s forecast-sentence shape (see API-MANUAL SS15 for the forecast wind phrase).

Temperature decade phrases (standard and verbose levels): "in the upper 80s", "in the lower 20s" — ported from GFE's decade/position algorithm (`sse/gfe/temp_phrases.py`). Exact round-decade or extreme values (≥ 90, ≤ 19, zero-crossing) use the GFE exception table instead ("around 60", "around 105") — see the forecast temperature spec above for the full exception table. The same decade phrasing is used for the verbose tier's dew point sentence.

Extreme-temperature descriptors (standard and verbose levels, new since ADR-082): a trailing sentence ("Very Hot.", "Bitterly Cold.") is appended when `sse/gfe/thresholds.py`'s `EXTREME_TEMP_DESCRIPTORS` rules match the current temperature. Current conditions only evaluate the temperature-only branches of that table — `Observation` does not carry `heat_index`/`wind_chill` (those remain TERSE-tier `temperature_comfort` inputs, ADR-082 decision #12), so the humidity/wind-chill-combined branches never fire for standard/verbose text.

**NWS phrasing conventions:**

1. Haze and fog appear as separate sentences at the standard level: "Sunny. Hazy." not "Hazy and Sunny." At the verbose level, haze/fog fuse into the opening narrative clause instead ("Currently ... under hazy sunshine.", "Currently ... with fog limiting visibility.") — unchanged from the pre-ADR-082 verbose narrative shape.
2. Precipitation modifies sky with "with": "Mostly Cloudy with Light Rain."
3. Day/night terminology: "Sunny" / "Clear" at night; "Partly Sunny" / "Partly Cloudy". Day/night determined by `is_daytime()` from the sky classifier (solar elevation based). Note: unlike the retired `text_generator.py`, the shared day-mapping helper (`conditions_text._to_display_label()`, reused from the preserved terse tier) does not map "Partly Cloudy" → "Partly Sunny" — daytime "Partly Cloudy" renders unchanged at all three tiers for consistency.

**Unit-aware rendering:** `Observation` temperature/dewpoint/wind fields are always US units (°F, mph) per `observation_model.py`'s contract. GFE branch selection (decade/exception-table lookup, extreme-temperature descriptor rules) always runs on the raw °F/mph value — the threshold tables themselves are Fahrenheit/mph-specific by construction and are not converted. Only the rendered numerals that carry no GFE threshold semantics (the temperature/dewpoint decade digits, the wind speed/gust digits) are converted to the operator's configured unit system (US / Metric / MetricWX) at render time, via `sse/gfe/composer.py`'s `configure(unit_system)` (wired at startup in `__main__.py`, replacing the retired `text_generator.configure()` call). The current-conditions wind sentence uses a dedicated composer-local formatter (not `wind_phrases.wind_phrase()`) so METRIC/METRICWX numerals get the correct unit label — this is a deliberate consistency choice, not a limitation of `wind_phrase()` itself (see the forecast-side paragraph below, where `wind_phrase()` now supports unit-aware rendering directly).

**Forecast-side unit-aware rendering (ADR-082 gap closure, 2026-07-06):** unlike `Observation`, `ForecastPeriod` temperature/wind fields are NOT guaranteed raw °F/mph — forecast providers fetch data already converted to the operator's configured `target_unit` (§15 "Forecast input traceability"), and `period_aggregator.py` does not convert it back. `compose_forecast_text()` reads the same operator-wide `_unit_system` state `configure()` sets (shared with the current-conditions path above) to render correctly: `temp_phrase()` (decade phrasing) receives the `ForecastPeriod` value unchanged, since GFE's decade/position math generalizes across unit systems; `temp_descriptor()` (extreme-temperature descriptor) converts the value back to °F via the canonical conversion registry (`units/conversion.py`) before evaluating its Fahrenheit-calibrated thresholds; `wind_phrase()` (`sse/gfe/wind_phrases.py`) accepts a `unit_system` argument that converts `WIND_NULL_THRESHOLD`/`WIND_GUST_DIFFERENCE` forward into the target unit for its calm/gust comparisons and resolves a locale-correct label for the `{unit}` placeholder now present in the `wind.*` locale templates (all 13 locales) in place of the previously-hardcoded "mph" suffix. Known remaining gap, not addressed in this round: snow/ice accumulation phrasing (`snow_ice_phrases.py`, inch-calibrated) and the period aggregator's own `TEMP_TREND_THRESHOLD` comparison (`period_aggregator._temp_trend()`) have the same class of unit mismatch and are tracked as a follow-up.

**Backward compatibility:** `weatherText` continues to carry terse output. Existing dashboard code reading `weatherText` is unchanged. `weatherTextStandard` and `weatherTextVerbose` are additive fields.

---

## §9 Charts System — API Side

### Configuration format

Charts are configured in `charts.conf`, a ConfigObj/INI file with three-level nesting: group → chart → series. The format is intentionally identical to Belchertown's `graphs.conf` so that migrating operators can reuse their existing configuration.

Parse `charts.conf` at API startup in `services/charts_config.py`. Never re-parse mid-request.

### Self-hide pruning

At startup, after parsing `charts.conf`, prune any series whose `observation_type` is not in the column registry. Cascade the removal: if all series in a chart are removed, remove the chart. If all charts in a group are removed, remove the group. Serve the pruned config tree from `GET /api/v1/charts/config`.

Operators do not see charts for data their station does not collect.

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/charts/config` | GET | Returns the full pruned config tree |
| `/api/v1/charts/custom-query/{series_id}` | GET | Executes a pre-validated operator-defined SQL query |
| `/api/v1/archive` | GET | Time-series archive data with optional aggregation |
| `/api/v1/archive/grouped` | GET | Categorical aggregation grouped by calendar period |

Do not add chart-type-specific endpoints. The API provides general-purpose data access; the dashboard determines what to fetch and how to render it.

### Custom SQL security

Accept custom SQL from `charts.conf` on disk only. Never accept SQL from HTTP request bodies or query parameters. Apply these controls in sequence:

1. **EXPLAIN pre-validation** at startup — run `EXPLAIN` on each custom query. Queries that fail `EXPLAIN` are logged as errors and excluded from the config tree.
2. **DDL keyword blocklist** — reject any query containing `CREATE`, `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` (case-insensitive).
3. **Read-only transaction** — execute in a read-only SQLAlchemy transaction.
4. **10-second timeout** — abort queries exceeding 10 seconds.

### Archive query parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `observation_type` | string | Column name from the archive schema |
| `from` | integer | Start epoch timestamp (Unix seconds) |
| `to` | integer | End epoch timestamp (Unix seconds) |
| `aggregate_interval` | integer | Bucket size in seconds (≥ 60, no upper cap) |
| `agg_map` | string | Per-field aggregation: `field:agg_type` comma-separated |

The `aggregate_interval` parameter accepts any value ≥ 60 seconds — there is no upper bound.

### Supported aggregate types

| Type | Behavior |
|------|----------|
| `avg` | SQL AVG |
| `max` | SQL MAX |
| `min` | SQL MIN |
| `sum` | SQL SUM |
| `count` | SQL COUNT |
| `sumcumulative` | SQL SUM per bucket, then running total post-processed in Python |

The `sumcumulative` type replaces Belchertown's hardcoded `rainTotal` post-processing. Use it for cumulative rain totals.

### Archive grouped endpoint

`GET /api/v1/archive/grouped` provides categorical aggregation grouped by calendar period:

| Parameter | Type | Description |
|-----------|------|-------------|
| `group_by` | string | Grouping period: `month`, `day`, `hour`, or `year` |
| `fields` | string | Comma-separated field specs: `field:agg_type` or `field:agg_type:avg_type` |
| `from` | integer (optional) | Start epoch timestamp |
| `to` | integer (optional) | End epoch timestamp |
| `force_full_period` | boolean (optional) | Fill missing calendar slots with null when true |

There is no separate `/climatology/*` endpoint family. Use `/archive/grouped` for all calendar-grouped aggregation.

### Archive conversion

Apply `transform_record()` to all `/archive` responses. This injects `beaufort` and unit-converts all fields. Values are flattened to full-precision scalars. The exception: `beaufort` retains its `ConvertedValue` dict form so the dashboard wind rose can bin by Beaufort number without re-deriving from wind speed.

### Special series types

Four series names in `charts.conf` trigger automatic rendering behavior — the dashboard switches chart component and data-fetching strategy without additional operator config:

| Series name | Rendering | Key automatic behaviors |
|-------------|-----------|------------------------|
| `windRose` | Custom SVG polar chart (16 directions × 7 Beaufort speed bands) | Raw (unaggregated) separate archive fetch for `windSpeed`+`windDir`. Default Beaufort colors, overridable via `beaufort0`–`beaufort6` keys. Always polar. |
| `weatherRange` | Recharts arearange (default) or columnrange. Polar ONLY when `polar=true` explicitly set. | 15-band temperature color zones (°F and °C variants). Dual archive fetch `agg=min`+`agg=max`, `aggregate_interval=86400`. |
| `haysChart` | Recharts arearange, always polar | Circular 24-hour wind chart (Mount Washington Observatory style). Queries `windSpeed`+`windGust` max. `yAxis_softMax` controls radial scale. |
| `rainTotal` | Standard time-series | Migration tool auto-promotes to `aggregate_type = sumcumulative`. Queries `rain` column with `observation_type = rain`. |

All other series render as standard Recharts time-series charts (line/spline/area/column/scatter).

### All archive columns served

The `/archive` endpoint has no column whitelist gate. Any column present in the weewx archive schema is queryable by its database column name. The column registry (populated at startup by schema reflection) governs self-hide pruning — not endpoint access.

---

## §10 weewx Integration

### Co-location constraint

Deploy the API on the same host as weewx. This is an architecture constraint (per ADR-056 and ADR-034), not a recommendation. The API reads `weewx.conf` from the local filesystem; the weewx archive database is on the same host; the loop relay Unix socket is on the same host.

### weewx.units import

Use `import weewx.units` to access `obs_group_dict` for unit group auto-detection at startup. This is the authoritative mapping from weewx field name to unit group.

Import path: auto-detect by checking standard install paths, then read from `api.conf [weewx] python_path` if the operator has set a custom path. Store the resolved path in config on first successful import.

### Graceful degradation

If `import weewx.units` fails (weewx not installed at the detected path), log a warning and continue. The API still serves data. Unit group auto-detection is unavailable; the operator must specify unit groups manually in the wizard.

Never make the weewx import a fatal startup failure.

### Security boundary

The API imports only `weewx.units`. It never imports:

- `weewx.engine` — the weewx engine
- `weewx.drivers` — hardware driver modules
- `weewx.manager` — the database manager

Importing engine or driver modules could trigger hardware initialization, file locks, or database writes. Importing manager could provide accidental write access to the archive. These imports are forbidden.

---

## §11 SSE and Realtime

### Endpoint

The SSE stream is served at `GET /sse` on API port 8765. Caddy routes both `/api/v1/*` and `/sse` to port 8765. There is no separate realtime service (the former `weewx-clearskies-realtime` is deprecated per ADR-058).

### Event format

Each SSE event uses the named event type `"loop"`:

```
event: loop
data: {"outTemp": {"value": 72.3, "label": "°F", "formatted": "72.3"}, ..., "units": {...}}
```

The data field is a unit-converted JSON object in the same shape as `/current` responses, excluding `weatherText` (REST-only). Every SSE event carries the `units` metadata block.

### Input: Unix socket

The socket reader connects to the Unix socket at `/var/run/weewx-clearskies/loop.sock` published by the `ClearSkiesLoopRelay` weewx extension. The socket reader auto-reconnects with exponential backoff on weewx restart. MQTT is eliminated — direct mode via Unix socket is the only input path.

### Keepalive and buffer

- 15-second keepalive comment (`": keepalive"`) sent to all connected clients to prevent proxy timeout.
- 64-packet overflow buffer. When the buffer is full, the oldest packet is dropped.

### Module-level state

Twelve enrichment processors run in the API process. Several carry intentional process-level state:

- Ring buffers (solar radiation kc window, wind rolling window)
- Sky condition classifier (30-minute kc buffer, current classification)
- Scene descriptor (current background image state)
- Lightning strike buffer

This state is preserved correctly in a single-process deployment. Multi-worker deployment would require state sharing — this is out of scope for v0.1. The API runs as a single uvicorn worker.

### Caddy routing

Both `/api/v1/*` and `/sse` route to the API at port 8765. Example Caddyfile stanzas (single-host, dual-stack):

```
handle /api/v1/* {
    reverse_proxy localhost:8765
}
handle /sse {
    reverse_proxy localhost:8765
}
```

For dual-stack binding (IPv4 and IPv6), bind Caddy on both `0.0.0.0:443` and `[::]:443`. The API listens on `0.0.0.0:8765` (loopback or LAN depending on topology — see ARCHITECTURE.md for the authoritative port registry and topology rules).

---

## §12 Radar Endpoints and Capability Model

### Radar capability metadata

The `/api/v1/capabilities` response includes radar provider metadata. For LibreWxR, this is richer than for other providers because LibreWxR supports multiple features (nowcast, color schemes, alerts) that the dashboard adapts to.

LibreWxR capability declaration includes:

| Field | Type | Description |
|---|---|---|
| `provider` | string | `"librewxr"` |
| `attribution` | string | `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"` |
| `bounds` | `{south, west, north, east}` or `null` | Geographic bounding box from `[radar] librewxr_bounds` config. `null` = global. |
| `caddy_prefix` | string | `"/librewxr"` — the Caddy proxy path prefix for tiles and alerts |
| `tile_url_template` | string | `/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp` |
| `alert_url` | string | `/librewxr/v2/alerts` |
| `nowcast` | bool | Whether nowcast frames are available |
| `color_schemes` | list of `{id, name}` | Available color schemes (from `weather-maps.json`) |
| `alerts` | bool | Whether weather alerts are available |
| `satelliteAvailable` | bool | Whether satellite imagery frames are available (parsed from `satellite.infrared` in `weather-maps.json`) |
| `satelliteTileUrlTemplate` | string or `null` | Satellite tile URL template: `{caddyPrefix}/{path}/{size}/{z}/{x}/{y}/0/0_0.webp`. `null` when satellite is unavailable. |
| `refresh_interval` | int | Seconds between dashboard frame metadata re-fetches (from `[radar] librewxr_refresh_interval` config, default 600) |

RainViewer capability is minimal: provider name, attribution, and `degraded: true` with `operator_notes` documenting the free-tier limitations.

### Radar endpoints

**Frame metadata (all providers):**
- `GET /api/v1/radar/providers/{id}/frames` — API fetches upstream metadata (e.g., `weather-maps.json` for LibreWxR/RainViewer), normalizes to canonical `RadarFrameList`, caches (60s TTL for LibreWxR, existing TTL for others).
- **Satellite frames (LibreWxR only):** The `RadarFrameList` response includes a `satelliteFrames` field containing satellite imagery frame metadata parsed from `satellite.infrared` in `weather-maps.json`. Frames older than 24 hours are filtered out (staleness guard). The field is present but empty for non-LibreWxR providers.

**Tile proxy (keyed providers only):**
- `GET /api/v1/radar/providers/{provider_id}/tiles/{z}/{x}/{y}` — serves tile bytes for keyed providers. Currently only `openweathermap` uses this endpoint. Query parameters: `?t=` (frame timestamp).
- `_PROXIED_RADAR_PROVIDERS` contains `openweathermap` only. LibreWxR tiles go through Caddy, not the API. RainViewer tiles go direct to CDN.

**LibreWxR tiles are NOT proxied by the API.** Caddy handles tile routing via `/librewxr/*`. The API provides metadata only (capabilities + frame lists). This is a deliberate architecture boundary — the API never touches tile traffic for LibreWxR.

### LibreWxR configuration

Config fields in `api.conf`:

| Field | Section | Default | Description |
|---|---|---|---|
| `librewxr_endpoint` | `[radar]` | `https://api.librewxr.net` | LibreWxR instance URL. Public API or self-hosted. |
| `librewxr_bounds` | `[radar]` | *(empty = global)* | Geographic bounding box `south,west,north,east` (e.g., `32.0,-120.5,35.5,-114.5` for SoCal). Dashboard enforces `maxBounds` from this. |
| `librewxr_refresh_interval` | `[radar]` | `600` | Seconds between dashboard frame metadata re-fetches. Operator matches this to their LibreWxR instance's `LIBREWXR_FETCH_INTERVAL`. |

### Deprecated providers

`iem_nexrad` and `noaa_mrms` modules remain on disk. When configured, they log a migration warning at startup:
```
WARNING: Radar provider 'iem_nexrad' is deprecated. Consider migrating to 'librewxr' for better radar quality.
WARNING: Radar provider 'noaa_mrms' is deprecated. Consider migrating to 'librewxr' for better radar quality.
```
They continue to function as before — no breaking change for existing operators.

`aeris` is removed from radar. Vaisala Xweather credentials remain wired for forecast/AQI/alerts.

### Provider attribution metadata (ADR-080)

The `/api/v1/capabilities` response includes a `ProviderAttributionResponse` block on each provider's `CapabilityDeclaration`. This tells the dashboard what attribution text, logo, and link to render for each provider.

**Schema (`ProviderAttributionResponse`):**

| Field | Type | Default | Purpose |
|---|---|---|---|
| `attributionRequired` | `bool` | — | Whether the host must render a footer |
| `displayName` | `str` | — | Human-readable provider name (about page, fallback text) |
| `attributionText` | `str` | — | ToS-mandated wording, rendered verbatim |
| `url` | `str` | — | Provider URL (linked from attribution text) |
| `textTranslatable` | `bool` | `false` | False = render verbatim. True = pass through `t()` (future) |
| `textLanguage` | `str` | `"en"` | BCP-47 language tag for the attribution text |
| `logoRequired` | `bool` | `false` | Whether the provider's ToS mandates a logo |
| `doNotUseLogo` | `bool` | `false` | Whether the provider's ToS forbids logo use |

**Per-provider attribution values (v0.1):**

| Provider ID | `attributionRequired` | `attributionText` | `logoRequired` | `doNotUseLogo` |
|---|---|---|---|---|
| `aeris` | true | "powered by Vaisala Xweather" | true | false |
| `nws` | false | "Data courtesy of the National Weather Service" | false | false |
| `openmeteo` | true | "Weather data by Open-Meteo.com" | false | false |
| `owm` | true | "Weather data provided by OpenWeather" | true | false |
| `iqair` | true | "Powered by IQAir" | false | true |
| `usgs` | false | "Earthquake data courtesy of the U.S. Geological Survey" | false | false |
| `rainviewer` | true | "RainViewer" | false | false |
| `librewxr` | true | "LibreWxR — Data: CC-BY-4.0" | false | false |
| `seven_timer` | false | "7Timer!" | false | false |

`textTranslatable` is `false` for ALL providers in v0.1. ToS-mandated text must not be translated.

The API-side dataclass (`ProviderAttribution`) lives in `providers/_common/capability.py`. Each provider module populates it on its `CAPABILITY` declaration. The Pydantic response model (`ProviderAttributionResponse`) lives in `models/responses.py`.

---

## §13 Anti-Patterns

Never do any of the following.

| Anti-pattern | Correct approach |
|--------------|-----------------|
| **Create chart-specific API endpoints** (e.g., `/charts/wind-rose`, `/charts/temperature-range`). | The API is general-purpose data access. Serve `/archive` and let the dashboard determine rendering. Use `/charts/custom-query/{series_id}` only for operator-defined SQL queries from `charts.conf`. |
| **Duplicate Beaufort, comfort-index, or unit conversion thresholds in dashboard code.** | The API computes all derived values. The dashboard reads `beaufort.value`, `comfortIndex`, and `label` strings. It performs zero unit math. |
| **Hardcode weewx column names in endpoint handlers.** | Use the column registry populated by schema reflection at startup. Endpoints select columns from the operator's mapping — never from a hardcoded list. |
| **Serve local-time strings in API responses.** | All time fields use UTC ISO-8601 with a `Z` suffix. Display-side timezone conversion happens in the dashboard using the station's IANA timezone from `StationMetadata`. |
| **Write to the weewx database.** | The API is read-only by architecture. The startup write probe enforces this. The API never holds a writable DB connection. |
| **Import `weewx.engine`, `weewx.drivers`, or `weewx.manager`.** | Import only `weewx.units`. Engine and driver imports risk hardware initialization and file locks. Manager imports risk write access. |
| **Accept custom SQL from HTTP.** | Custom SQL comes from `charts.conf` on disk only. Config file is operator-controlled (same trust model as Belchertown). HTTP-supplied SQL is rejected unconditionally. |
| **Return a response without the `units` metadata block.** | Every API response — observation, archive, forecast, AQI, alert — carries the `units` block. Use `exclude_none=False` serialization. |
| **Place secrets in `.conf` files.** | Secrets (API keys, DB passwords, cache URL with credentials) go in `secrets.env` (mode 0600), injected as environment variables. Config files (`api.conf`, `charts.conf`) are operator-readable and must contain no credentials. |
| **Exceed the 366-day time-range cap on archive queries.** | Enforce a 366-day maximum on all archive time-range parameters. Return HTTP 400 with RFC 9457 body when the requested range exceeds the cap. |
| **Use a separate conversion layer between the API and dashboard.** | The former realtime BFF proxy is eliminated. The API converts directly. Caddy routes `/api/v1/*` and `/sse` both to the API at port 8765. There is no intermediate service. |
| **Use MQTT as the loop packet input.** | MQTT input mode is eliminated (per ADR-058). The only input path is the Unix socket at `/var/run/weewx-clearskies/loop.sock` from the `ClearSkiesLoopRelay`. |
| **Use naive datetimes (no tzinfo) in API-layer Python code.** | All `datetime` objects in API code must carry `tzinfo=UTC`. Use `datetime.now(UTC)`, never `datetime.now()`. Naive datetimes are a silent source of DST and timezone bugs (ADR-075). |
| **Return local-time strings in responses (except `stationClock.time`).** | All timestamps use UTC ISO-8601 Z. The only exception is `stationClock.time`, which carries a UTC offset for self-contained interpretation. No other response field may contain a local-time string. |
| **Omit `stationClock` from a response envelope.** | Every API response includes `stationClock`. It is computed at response time from the station's configured timezone — no DB query required (ADR-075). |
| **Omit `freshness` from a cacheable response.** | Every cacheable REST response includes `freshness`. Only SSE events and setup endpoints omit it (ADR-075). |
| **Hardcode refresh intervals that should come from weewx.conf.** | `current_observation` and `records` derive their `refreshInterval` from `archiveIntervalSeconds`. Do not use magic numbers like `300` for these domains — the actual archive interval is station-specific (ADR-075). |

---

## §14 Forecast Correction Engine

Governs the `correction/` package in `weewx-clearskies-api`. See ADR-079 for the decision record.

### Pipeline position

The correction engine runs **after** cache lookup and sunrise/sunset injection, **before** the hours/days slice and response construction. Raw provider data stays in cache — correction is applied in-flight per request. If correction is disabled or no model is available, raw forecasts pass through unchanged (no-op).

Sequence within `endpoints/forecast.py`:
1. Provider dispatch (cache hit or upstream fetch)
2. Cache storage (raw provider data)
3. Sunrise/sunset injection
4. **Correction applied here** (`correct_bundle(bundle)`) — hourly points only
5. Hours/days slice
6. Response construction

### Data collection

A background `ForecastCollector` daemon thread fires once per `archive_interval`. Per tick:

1. Query the latest archive record for `outTemp` + `dateTime` from the weewx archive DB (read-only session).
2. Read the current cached forecast bundle.
3. Find the `HourlyForecastPoint` whose `validTime` is closest to the archive timestamp.
4. Extract 7 features (all forecast-side — no observation-time features).
5. Write the forecast-observation pair to `forecast_correction.db` via `correction/db.py:insert_pair()`.
6. Skip (no error) if: archive record missing, cached forecast missing, pair for this timestamp already exists (UNIQUE constraint on `timestamp`).

The collector runs when `collection_enabled = true` in `[forecast_correction]`. Collection is independent of correction — pairs are collected even when correction is disabled, building data toward the `min_samples` threshold for future training.

The weewx archive DB is never written to. The correction engine uses a separate SQLite DB.

### Model features

Seven features, all from the forecast point (MOS methodology — no observation data exists for future forecast hours):

| # | Feature | Source field | Notes |
|---|---------|-------------|-------|
| 1 | `month` | `validTime` (1–12) | Seasonal bias variation |
| 2 | `hour` | `validTime` (0–23) | Diurnal bias cycle |
| 3 | `fcst_temp` | `outTemp` | Bias may scale with predicted value |
| 4 | `fcst_wind_dir` | `windDir` (degrees, nullable) | Offshore vs onshore thermal regime |
| 5 | `fcst_humidity` | `outHumidity` (%, nullable) | Air mass type proxy |
| 6 | `fcst_cloud_cover` | `cloudCover` (%, nullable) | Radiative heating modulator |
| 7 | `fcst_wind_speed` | `windSpeed` (nullable) | Wind mixing affects microclimate |

`day_of_year` is also stored in the DB for future experiments but is not used as a training feature — `month` provides cleaner seasonal bins for Random Forest splits.

Nullable features use median imputation. Compute feature medians from the training set and store them alongside the model. Apply the same stored medians at prediction time — never recompute medians at prediction time.

### Model training

**Algorithm:** `RandomForestRegressor(n_estimators=150, max_depth=6, random_state=42)` from scikit-learn.

**Target:** `actual_temp - fcst_temp` (bias). Apply as: `corrected = fcst_temp + predicted_bias`.

**Training data split:**
- Training set: all pairs older than 30 days.
- Validation set: pairs from the last 30 days.
- **Bootstrap mode:** When all pairs are within the last 30 days (fresh deployment — training set empty) or all pairs are older than 30 days (validation set empty), use all available data for both training and validation. This allows the first model to be trained as soon as `min_samples` total pairs are collected, without waiting 30 days for the normal split to produce a non-empty training set.

**Minimum samples gate:** Do not train unless `total_pair_count >= min_samples` (default 500, minimum configurable value 100). The gate checks total pairs across both training and validation sets, not just the training subset. Return early with a status dict when the gate is not met.

**Data retention:** Purge records older than `retention_years` (default 3) at the start of each training run.

**Model serialization:** Serialize model + feature medians dict together using `joblib.dump()`. Write to a temp file in the same directory, then `os.rename()` to the target path. This is an atomic write — a concurrent forecast request never reads a partial model.

**Retraining schedule:** Configured via `retrain_schedule` (`daily` / `weekly` / `manual`, default `daily`). Daily retrains at approximately 03:00 station time. Weekly retrains on `retrain_day` (0=Monday, 6=Sunday) at 03:00. Manual requires an explicit `POST /setup/forecast-correction/retrain` call. A background `BackgroundRetrainer` daemon thread manages scheduled retraining.

### TruScore metrics

Computed during each training run using the 30-day validation window:

| Metric | Formula | Meaning |
|--------|---------|---------|
| **Provider Score** | `100 − MAE_raw` | Forecast accuracy before correction. Higher = more accurate raw forecast. |
| **Correction Score** | `100 − MAE_corrected` | Forecast accuracy after correction. Same scale as Provider Score — higher = better. Directly comparable: a Provider Score of 97.8 becoming a Correction Score of 99.8 immediately shows the improvement. |

`MAE_raw` = mean absolute error of raw forecasts vs observations over the validation window.
`MAE_corrected` = mean absolute error of corrected forecasts vs observations over the same window.

Store both MAE values and both scores in `model_metadata` in the correction SQLite. The admin status endpoint exposes them.

### Admin endpoints

All three endpoints are on the `router` defined at `/setup` prefix in `endpoints/setup.py`, using the `require_setup_active` auth dependency (proxy auth).

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/setup/forecast-correction/status` | GET | Returns `CorrectionStatusResponse`: model availability, `is_active`, pair count, date range, last trained timestamp, sample count, MAE values, TruScore metrics, settings state (`enabled`, `collection_enabled`, `retrain_schedule`). |
| `/setup/forecast-correction/toggle` | POST | Accepts `CorrectionToggleRequest` (`enabled`: bool, `collection_enabled`: bool). Updates runtime state via `corrector.set_enabled()` and collection flag. Returns `CorrectionToggleResponse` with new state. |
| `/setup/forecast-correction/retrain` | POST | Triggers synchronous model training (training takes <5 s). Calls `trainer.train_model()` then `corrector.reload_model()`. Returns `RetrainResponse` with success flag, metrics, and sample count. Returns success=false (not HTTP error) when `min_samples` gate is not met. |

Use `ConfigDict(extra="forbid")` on all request models. Setup endpoints omit `freshness` (per §13 anti-patterns — `freshness` applies to cacheable data responses, not admin actions).

### Correction behavior

- **Hourly points:** `correct_bundle(bundle)` iterates `bundle.hourly`. For each point: extract 7 features, impute None features using stored medians, predict bias, set `point.outTemp = round(point.outTemp + predicted_bias, 1)`.
- **Daily points:** For each `bundle.daily` point, predict bias for `tempMax` at hour=14 (typical afternoon high) and `tempMin` at hour=5 (typical early morning low). Weather features (wind, humidity, cloud cover, wind speed) use stored medians since daily points don't carry per-hour values.
- `is_active()` returns `True` only when both `enabled = true` AND a model is loaded. The no-op path (`not is_active()`) returns the bundle unmodified.
- After `os.rename()` completes a new model file, `corrector.reload_model()` loads it. There is a brief window where forecast requests use the prior model — this is acceptable.

### Provider-agnostic behavior

The correction engine works with any configured forecast provider. `provider_id` is logged with each forecast-observation pair. Training uses all pairs regardless of `provider_id` — bias patterns are station-local. When an operator switches forecast providers, new pairs are logged with the new `provider_id`; existing pairs are retained; the next training run learns from mixed-provider data.

---

## §15 Forecast Text Generation

Governs the `sse/gfe/` package — the NWS GFE Text Generation System with WorldCast Technology. See ADR-082 for the decision record. GFE = Graphical Forecast Editor, the NWS tool that generates Zone Forecast Products. WorldCast = the i18n extension to 13 locales.

### Engine scope

One engine serves two data paths with different input sources:

| Path | Input | Output | Example |
|---|---|---|---|
| **Forecast** | Provider hourly data → period aggregation → `ForecastPeriod` | NWS-style period narrative | "Today: Mostly sunny. High in the mid 80s. South winds 10 to 15 mph." |
| **Current conditions** | weewx sensor data → `Observation` (enrichment pipeline) | Single-instant summary | "Warm and Humid, Overcast, with Light Rain" |

These paths share the hybrid wind scale, gust phrasing, and GFE threshold tables. They differ in sky classification, temperature phrasing, precipitation detection, and composition pattern. The differences are by design — see the preservation directive below.

### NWS pass-through

When the operator selects NWS as the forecast provider, the `detailedForecast` field from the NWS `/gridpoints/{office}/{x},{y}/forecast` endpoint is returned unchanged. The text engine is NOT invoked. English only. NWS does not provide granular hourly forecast data through its public API — the endpoint returns pre-composed period narratives, not the gridded data the engine needs.

### Current-conditions preservation directive

The following current-conditions systems are preserved intact. The GFE engine does NOT replace them. Any agent modifying `sse/enrichment/weather_text.py`, `sse/sky_condition.py`, `sse/conditions_text.py`, or `sse/text_generator.py` MUST read this directive first. Deleting or replacing preserved systems is a blocking defect.

| System | What it does | Why it stays |
|---|---|---|
| **SkyPyEye 7-level classification** | Pyranometer-based sky (Clear, Mostly Clear, Partly Cloudy, Mostly Cloudy, Cloudy, Overcast, Heavy Overcast) with cloud enhancement detection, temporal coherence, startup backfill, SZA guard, provider fallback | Physical measurement is more accurate than percentage lookup. 7 levels (including Overcast/Heavy Overcast distinction) provide finer granularity than the GFE 6-bucket table. The 6-bucket table is used for forecast periods only, where we have provider cloud cover percentages but no pyranometer data. |
| **Temperature-comfort 2D matrix** | 12 appTemp tiers × 7 dewpoint tiers → "Warm and Humid", "Pleasant", "Chilly" + NWS HI/WC danger escalation + near-saturation "and Foggy" override (§8) | Describes how it FEELS, not the numeric value. GFE decade phrasing ("in the mid 80s") tells the number — different purpose. Comfort matrix stays for the terse tier; decade phrasing used for forecast periods. |
| **Sensor-based precipitation** | Local rain gauge with WMO/AMS thresholds (Light/Moderate/Heavy Rain) + Stull wet-bulb frozen precipitation cross-check (§8) | Sensor is authoritative for "is it raining NOW." Coverage language ("scattered showers") doesn't apply to a single station point observation. GFE coverage system used for forecast periods only. |
| **Haze detection** | Kcs + PM2.5/PM10 two-channel confirmation (§8) | No GFE equivalent. Station-specific sensor detection. |
| **Fog/mist detection** | Hygrometer + dewpoint depression (§8) | No GFE equivalent. Station-specific sensor detection. |
| **Input stability** | Smoothing windows, hysteresis bands, 5-minute hold time, temporal coherence filter (§8) | No GFE equivalent. Required for real-time display — prevents label flickering from noisy sensor data. |
| **Current-conditions composition** | `[comfort, sky, wind, precip]` with ", with" connectors → "Warm and Humid, Overcast, with Light Rain" (§8) | Designed for single-instant snapshots. GFE's period-based composition is for forecast. |
| **Provider weather text deferral** | Nighttime haze/smoke deferral, missing pyranometer deferral, missing hygrometer fog/mist deferral (§8) | Graceful degradation when sensors unavailable. |

**What the GFE engine DOES change for current conditions:**
- Wind labels at ≥ 30 mph switch from Beaufort (Near Gale / Gale / Storm / Violent Storm / Hurricane) to GFE/NWS (Windy / Very Windy / Strong Winds / Hurricane Force Winds). Below 30 mph, Beaufort labels stay. See §8 Wind for the hybrid table.
- Gust phrasing upgrades from "and Gusty" to GFE's "with gusts to around X mph" (states the gust speed).
- Standard and verbose verbosity tiers gain GFE decade phrasing, extreme temperature descriptors, and improved wind connectors. The terse tier composition pattern is unchanged.

### Forecast period convention

NWS 6am/6pm fixed periods in the operator's local time. "Today" = 6am–6pm, "Tonight" = 6pm–6am. Sunrise/sunset are used for day/night VOCABULARY selection only (e.g., cloud cover < 25% produces "Sunny" during daytime and "Mostly Clear" at nighttime). Sunrise/sunset do NOT define period boundaries.

72 hourly forecast points aggregate into 6 `ForecastPeriod` instances: Today, Tonight, Tomorrow, Tomorrow Night, weekday, weekday Night.

### Forecast input traceability

Each phrase generator consumes specific fields from the `ForecastPeriod` dataclass. The `ForecastPeriod` is populated by the period aggregator from `HourlyForecastPoint` data. This table traces from phrase generator → period field → aggregation method → hourly provider field → which providers supply it.

| Phrase generator | ForecastPeriod field | Aggregation | Hourly source | Xweather | NWS | Open-Meteo | OWM |
|---|---|---|---|---|---|---|---|
| Sky | `sky_percent`, `is_daytime` | mean(cloudCover) | `cloudCover` | Y | — | Y | Y |
| Temperature (decade) | `temp_high` / `temp_low` | max/min(outTemp) | `outTemp` | Y | Y | Y | Y |
| Temperature (extreme) | `feels_like_max` / `feels_like_min` | max/min(feelsLike) | `feelsLike` | Y | — | Y | Y |
| Temperature (trend) | `temp_trend` | compare latter-half outTemp vs extreme | `outTemp` | Y | Y | Y | Y |
| Wind | `wind_speed_min/max`, `wind_gust`, `wind_direction` | min/max, max, mode | `windSpeed`, `windGust`, `windDir` | Y | Y (no gust) | Y | Y |
| Weather/precip | `weather_codes`, `precip_type`, `pop`, `precip_coverage` | union, mode, max, derived from pop | `weatherCode`, `precipType`, `precipProbability` | Y | Y | Y | Y |
| Snow accumulation | `snow_amount` | sum(precipAmount) where type=snow | `precipAmount` | Y | — | Y | Y |
| Ice accumulation | `ice_accumulation` | from daily `iceAccumulation` | daily field | Y | — | — | — |
| Dewpoint | `dewpoint` | passthrough | `dewpoint` | Y | — | Y | — |
| Fire: humidity | `humidity_max/min` | max/min(outHumidity) | `outHumidity` | Y | — | Y | Y |
| Fire: LAL | `weather_codes` + `precip_coverage` | derived | `weatherCode` + PoP | Y | Y | Y | Y |

When a provider does not supply a field (marked "—"), the engine omits the corresponding phrase. It does not fabricate data.

### `cloudCover` on `DailyForecastPoint`

Max cloud cover (0–100) across the day's hourly forecast points. Added to support the dashboard's PoP-gated icon selection — combined sky+precipitation icons need cloud cover to determine the sky condition tier. This is a distinct field from `HourlyForecastPoint.cloudCover` (see "Forecast input traceability" table above, `sky_percent` row) — the hourly field is the raw per-hour value the aggregator means together for the GFE sky phrase; the daily field is the day's maximum, computed independently for icon selection.

Populated by each provider:
- **Open-Meteo:** `cloud_cover_max` from the daily variables endpoint
- **Aeris:** `sky` field (0–100) from daily forecast periods
- **NWS:** Derived from icon shortname (`skc`→0, `few`→15, `sct`→35, `bkn`→70, `ovc`→95). Returns null when no sky-cover shortname is recognised.
- **OWM:** `clouds` field (0–100) from daily periods

### Current-conditions input traceability

For current conditions, all inputs come from the weewx archive and the API enrichment pipeline — not from providers (except for nighttime/fallback sky via provider `cloudcover`).

| Phrase component | weewx field | Available on `/current`? | Notes |
|---|---|---|---|
| Temperature-comfort | `appTemp` (apparent temp), `dewpoint` | Yes | Calculated by `StdWXCalculate` from outTemp + outHumidity + windSpeed |
| HI/WC danger escalation | `heatindex`, `windchill` | Yes | Calculated by `StdWXCalculate` |
| Sky | `radiation`, `maxSolarRad` | Yes | SkyPyEye classification from pyranometer data |
| Sky (night fallback) | provider `cloudcover` | Yes | Blended from provider current conditions |
| Wind | `windSpeed`, `windGust`, `windDir` | Yes | Direct sensor or calculated |
| Precipitation | `rainRate` | Yes | Rain gauge |
| Frozen precip type | provider `precipType` | Yes | Cross-checked with Stull wet-bulb from outTemp + outHumidity |
| Haze | `radiation`, `maxSolarRad` + provider PM2.5/PM10 | Yes | Two-channel: Kcs deficit + PM confirmation |
| Fog/mist | `outTemp`, `dewpoint`, `windSpeed`, `rainRate` | Yes | Dewpoint depression ≤ threshold |

### PoP-to-coverage derivation

Providers supply probability of precipitation (PoP) as a percentage, not NWS-style coverage codes. The engine derives the coverage term from PoP. Which term applies depends on whether the weather type is PoP-related (rain, snow, thunderstorms) or areal (fog, haze, smoke):

| PoP range | PoP-related types (R, RW, S, SW, T, IP, ZR) | Areal types (F, ZF, IF, H, K, BS, BN, BD) |
|---|---|---|
| < 15% (first 24h) / < 25% (extended) | (suppressed — no weather mention) | (suppressed) |
| 15–24% | Slight chance (SChc) | Isolated (Iso) |
| 25–54% | Chance (Chc) | Scattered (Sct) |
| 55–74% | Likely (Lkly) | Numerous (Num) |
| 75–100% | (coverage omitted, PoP separated into own phrase) | Widespread (Wide) / Definite (Def) |

### Forecast composition

Single-pass sequential assembly: sky phrase (suppressed when PoP ≥ 55%), temperature with localized Highs/Lows prefix, wind (with optional gust), weather/precipitation (PoP-gated), snow/ice accumulation, temperature trend, extreme temperature descriptor. Non-empty phrases joined with ". " (period + space). Each sentence capitalized. This is a simplified version of the GFE `assembleSubPhrases` pattern — no GFE tree traversal with fixed-point iteration, and no combined sky+PoP+weather phrase; sky and precipitation are always composed as separate sentences.

### Forecast verbosity

One level per forecast period, matching GFE's single narrative product. Current observations retain three tiers (terse/standard/verbose) per §8.

### Response field: forecastText

The composed narrative is exposed on `DailyForecastPoint.forecastText` (see [canonical-data-model.md §3.4](../contracts/canonical-data-model.md)) — an NWS-style forecast narrative for that period. `sse/forecast_text_enrichment.py` populates it on the `/api/v1/forecast` response: for non-NWS providers it is the GFE engine's `compose_forecast_text()` output; for the NWS provider it is the pass-through `detailedForecast` value (see NWS pass-through, above). It is `null` when hourly data is insufficient for generation.

### Module inventory

| Module | Purpose |
|---|---|
| `sse/gfe/__init__.py` | Package init + public API: `generate_forecast_text(period, locale)`, `generate_current_text(obs, verbosity, locale)` (placeholder — raises `NotImplementedError`), `aggregate_periods(hourly_data, sunrise, sunset, current_time, timezone, locale)`, plus re-exports `compose_forecast_text` and `compose_nws_passthrough` |
| `sse/gfe/thresholds.py` | All threshold tables (sky, temp, wind, weather, PoP, snow/ice, marine, fire, sub-period time descriptors) |
| `sse/gfe/sky_phrases.py` | Sky coverage (6-bucket for forecast; SkyPyEye stays for current) |
| `sse/gfe/temp_phrases.py` | Temperature decade phrasing, exceptions, trends, extremes |
| `sse/gfe/wind_phrases.py` | Hybrid Beaufort/GFE wind scale, gusts, marine wind |
| `sse/gfe/wx_phrases.py` | Weather/precip: 24 types, 16 coverages, intensity, conjunctions, PoP |
| `sse/gfe/snow_ice_phrases.py` | Snow/ice accumulation phrasing |
| `sse/gfe/marine_phrases.py` | Marine phrase templates (tables only, no provider) |
| `sse/gfe/fire_phrases.py` | Fire weather (tiered — Tier 1 active, Tier 2/3 dormant) |
| `sse/gfe/connectors.py` | Scalar/vector/weather connector strategies |
| `sse/gfe/composer.py` | Single-pass composition engine (`compose_forecast_text`, `compose_nws_passthrough`) |
| `sse/forecast_model.py` | `ForecastPeriod` dataclass |
| `sse/period_aggregator.py` | Aggregate hourly provider data into day/night periods |
| `sse/forecast_text_enrichment.py` | Enrichment adapter for `/api/v1/forecast` |

### i18n inflection in forecast composition

`sse/gfe/wx_phrases.py` wires `t_inflected()` (Romance gender/number agreement) and `t_case()` (Russian grammatical case) into forecast composition. Coverage and intensity words for Romance locales (French, Spanish, Italian, Portuguese) resolve through `t_inflected()` against a per-locale, per-GFE-type gender/number code (`WEATHER_TYPE_GENDER` in `wx_phrases.py`) so they agree with the weather type they modify (e.g. French "dispersée" for feminine-singular "pluie" vs. "dispersés" for masculine-plural "orages"). Weather type words resolve through `t_case()`, defaulting to the nominative case — Russian carries case-inflected `wx.type.*` dicts (nominative/instrumental/genitive); other locales carry plain strings, which both functions return unchanged regardless of the gender/case argument passed. This differs from the current-conditions composition path (§8), which still resolves these terms as plain strings — that limitation remains open there.

All GFE phrase generators (`wx_phrases.py`, `wind_phrases.py`, `temp_phrases.py`, `snow_ice_phrases.py`) render numeric values via `i18n.format_number()`, not `str()`, so decimal separators follow locale convention (e.g. `10,5` in French vs. `10.5` in English).

Locale JSON files carry `wind.*` keys (the hybrid Beaufort/GFE wind-scale labels, magnitude/gust templates, and marine wind descriptors) for all 13 supported locales.

### GFE code reuse directive

Agents building or modifying `sse/gfe/` modules MUST study the GFE source code analysis at `docs/reference/nws-text-system/gfe-source-code-analysis.md` and port algorithms faithfully. The GFE source is public domain (17 USC §105 — US government work). Do not reinvent what NWS already wrote and tested. Replicate threshold values and decision logic. Adapt for single-station use and 13-locale i18n, but keep core algorithms faithful to the original.

---

## §16 Marine Data Model

### Marine canonical models

All marine models follow the §2 naming convention (weewx-aligned camelCase, identical in Python and JSON). Pydantic models in `models/responses.py`.

**Locale-resolved fields:** Several marine model fields carry human-readable strings that must resolve through `i18n.t()` at enrichment time — not hardcoded English. These are marked with "(locale)" in the Description column below. See §17 "Marine i18n" for the full locale key inventory and implementation requirements. Fields NOT marked "(locale)" carry raw values, enum identifiers, or provider-sourced prose passed through verbatim.

#### MarineObservation

Single buoy observation snapshot from NDBC standard met data.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `windSpeed` | float | `group_ocean_speed` | Yes | Sustained wind speed |
| `windDirection` | float | — | Yes | Wind direction (degrees true north, meteorological convention) |
| `windGust` | float | `group_ocean_speed` | Yes | Wind gust speed |
| `waveHeight` | float | `group_wave_height` | Yes | Significant wave height (Hs) |
| `dominantPeriod` | float | `group_wave_period` | Yes | Dominant wave period |
| `averagePeriod` | float | `group_wave_period` | Yes | Average wave period |
| `meanWaveDirection` | float | — | Yes | Mean wave direction (degrees true north) |
| `pressure` | float | `group_pressure` | Yes | Sea-level pressure |
| `airTemp` | float | `group_temperature` | Yes | Air temperature |
| `waterTemp` | float | `group_temperature` | Yes | Sea surface temperature |
| `dewpoint` | float | `group_temperature` | Yes | Dewpoint temperature |
| `visibility` | float | `group_visibility` | Yes | Visibility |
| `pressureTendency` | float | `group_pressure` | Yes | 3-hour pressure tendency |
| `tideLevel` | float | `group_water_level` | Yes | Tide level (where reported) |
| `stationId` | str | — | No | NDBC station identifier |
| `time` | str | — | No | Observation time (UTC ISO-8601) |
| `spectralComponents` | list[SpectralWaveComponent] | — | Yes | Decomposed swell systems (when spectral data available) |

#### SpectralWaveComponent

Single swell system from NDBC spectral decomposition.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `height` | float | `group_wave_height` | No | Significant wave height for this swell system (Hs = 4√m₀) |
| `period` | float | `group_wave_period` | No | Peak period (Tp = 1/fp) |
| `direction` | float | — | No | Mean wave direction (energy-weighted circular mean, degrees true north) |
| `energy` | float | — | No | Zeroth spectral moment m₀ (m²) |
| `frequencyRange` | list[float] | — | No | [min_hz, max_hz] bounds of this spectral partition. For NDBC (`spectralComponents`), real bounds from that partition's local-maxima boundaries. **For SWAN (`multiSwell`), always `[0.0, 0.0]`** — SWAN's TABLE PT* bulk output (T4B.2) carries no per-partition frequency-bin bounds, so this field is not derivable on the SWAN path and is emitted as `[0.0, 0.0]` rather than a real value. Do not read the zeros as meaningful, and do not rely on this field for SWAN-sourced components. |
| `classification` | str | — | No | (locale) `"groundswell"` (period ≥ 12s), `"swell"` (8–12s), `"wind_swell"` (< 8s) |

#### TidePrediction

Predicted tide event from CO-OPS harmonic predictions.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Prediction time (UTC ISO-8601) |
| `height` | float | `group_water_level` | No | Predicted water level relative to datum |
| `type` | str | — | Yes | `"high"`, `"low"`, or null for interpolated points |
| `datum` | str | — | No | Vertical datum of the prediction (default `"MLLW"`). The public display endpoint always returns `"MLLW"`. The SWAN pipeline fetches an additional set of predictions in the DEM's native datum for WLEVEL input — those predictions carry the DEM datum here. |

#### WaterLevel

Observed water level from CO-OPS gauges.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Observation time (UTC ISO-8601) |
| `height` | float | `group_water_level` | No | Observed water level relative to datum |
| `datum` | str | — | No | Reference datum (e.g., `"MLLW"`, `"MSL"`, `"NAVD88"`) |
| `quality` | str | — | Yes | Quality flag from CO-OPS (e.g., `"v"` verified, `"p"` preliminary) |

### Vertical Datum Metadata Contract (ADR-098)

Every geospatial data product the API serves carries its vertical datum as a metadata field. Consumers must not assume a datum — they must read the field. This rule applies to all marine and nearshore data products.

#### Datum fields by data product

| Data product | Field | Value | Notes |
|---|---|---|---|
| `TidePrediction` | `datum` | `"MLLW"` (display) | New field added in ADR-098. Public `/api/v1/tides` endpoint always returns `"MLLW"`. The SWAN pipeline fetches a separate set of predictions in the DEM's native datum (never exposed to the dashboard). |
| `WaterLevel` | `datum` | `"MLLW"` | Existing field. CO-OPS observed water levels returned in MLLW. |
| Bathymetry cache JSON | `vertical_datum` | DEM native (e.g., `"NAVD88"`) | New field added in ADR-098. Written when the cache file is created. Old cache files without this field are treated as stale and re-downloaded. |
| DEM index entry | `vertical_datum` | Per DEM | Existing field in `ncei_regional_dem_index.json`. Source of truth for the NCEI and Great Lakes DEMs. |
| Coverage endpoint response | `vertical_datum` | Per level | Included in each level's response. `datum_warning: true` is added when the source is CRM/DEM_all (mixed or unknown datum). |

#### Dual-datum pattern for tides

The API serves tide predictions to two consumers with different datum requirements:

- **Dashboard display (`/api/v1/tides`):** Always fetches and returns predictions in `"MLLW"` (US chart datum standard). This is what users see. The `datum` field on each `TidePrediction` object will be `"MLLW"`.
- **SWAN WLEVEL pipeline:** Fetches predictions in the bathymetry DEM's native datum (e.g., `"NAVD88"` for the Orange County NCEI DEM). This fetch is internal — the SWAN datum predictions are never exposed to the dashboard or to API consumers. The SWAN pipeline caches these predictions separately (cache key includes the datum) so MLLW and DEM-native predictions do not collide.

These are two separate CO-OPS requests per SWAN run. The display datum and the SWAN datum are intentionally different and must stay separate.

#### Accepted datums for operator-uploaded bathymetry

Operator-supplied bathymetry files must use one of the datums that CO-OPS supports as a predictions request parameter: **NAVD88, MLLW, MHW, MHHW, MSL**. The system fetches CO-OPS predictions in the operator-specified datum for SWAN input — no local datum conversion is performed. If the operator's data is in a different datum, they must convert it before uploading (using VDatum at vdatum.noaa.gov or QGIS).

The upload endpoint validates the datum against this accepted list and rejects uploads specifying datums outside it.

#### No silent datum fallbacks

If datum matching cannot be confirmed — for example, if a DEM's `vertical_datum` is `"UNKNOWN"` or if CO-OPS does not support the datum as a request parameter — the SWAN level fails explicitly with an ERROR log. The system never proceeds with an unverified datum combination. A `datum_warning` in the coverage endpoint response signals operator attention is needed.

#### MarineForecastPoint

Single timestep from WaveWatch III wave forecast, optionally enriched with OFS water temperature.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Forecast valid time (UTC ISO-8601) |
| `waveHeight` | float | `group_wave_height` | Yes | Significant wave height |
| `wavePeriod` | float | `group_wave_period` | Yes | Peak wave period |
| `waveDirection` | float | — | Yes | Peak wave direction (degrees true north) |
| `windSpeed` | float | `group_ocean_speed` | Yes | 10m wind speed |
| `windDirection` | float | — | Yes | Wind direction |
| `swellHeight` | float | `group_wave_height` | Yes | Primary swell height |
| `swellPeriod` | float | `group_wave_period` | Yes | Primary swell period |
| `swellDirection` | float | — | Yes | Primary swell direction |
| `windWaveHeight` | float | `group_wave_height` | Yes | Wind wave height |
| `windWavePeriod` | float | `group_wave_period` | Yes | Wind wave period |
| `windWaveDirection` | float | — | Yes | Wind wave direction (degrees true north) |
| `waterTemp` | float | `group_temperature` | Yes | Sea surface water temperature from OFS model forecast time series. Populated by `ocean_data_resolver.resolve_forecast()` → `ofs.fetch_forecast()`. Null when OFS is not configured for the location, the location is on land, or all OFS cycles are unavailable. Source: `ofs.py` `fetch_forecast()`, PROVIDER-MANUAL §14.10. |

#### MarineTextForecast

Single period from NWS marine zone text forecast.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `periodName` | str | — | No | Period label (e.g., "Tonight", "Thursday") |
| `text` | str | — | No | Full forecast narrative |
| `wind` | str | — | Yes | Wind description extracted from narrative |
| `seas` | str | — | Yes | Seas description |
| `visibility` | str | — | Yes | Visibility description |
| `weather` | str | — | Yes | Weather description |

#### SurfForecast

Surf quality forecast for one spot at one timestep.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Forecast valid time (UTC ISO-8601) |
| `waveHeightAtBreak` | float | `group_wave_height` | No | Wave height at breaking (post-supplement Hsig, backward compatible) |
| `period` | float | `group_wave_period` | No | Dominant period |
| `direction` | float | — | No | Dominant swell direction (degrees true north) |
| `qualityStars` | int | — | No | 1–5 star rating |
| `qualityLabel` | str | — | No | (locale) Text label: "Poor", "Fair", "Good", "Very Good", "Epic" |
| `conditionsText` | str | — | No | (locale) Natural-language conditions summary |
| `windQuality` | str | — | No | (locale) "glassy", "offshore", "cross_offshore", "cross", "cross_onshore", "onshore" |
| `swellDominance` | float | — | No | Ratio of primary swell energy to total energy (0.0–1.0) |
| `multiSwell` | list[SpectralWaveComponent] | — | Yes | Individual swell systems from SWAN's own watershed partitioning — TABLE PT* output, not a decomposition of the SPECOUT energy matrix (T3.3/T3.5, algorithm replaced by T4B.2). **Sampled at the deep-water reference point: one per spot, in the L2 grid, on the spot's measured ~15 m contour — never at the SwellTrack handoff.** `null` when SPECOUT is unavailable for this timestep, when PT* partition data is unavailable for the point/timestep (TABLE file missing, or no coordinate match within tolerance), **or when the spot has no locatable 15 m contour** so no deep-water reference is emitted at all — none of these is recomputed and the handoff partitions are never substituted (marine `83f0205`, `bd8c928`). Not populated from NDBC. Every component's `frequencyRange` is `[0.0, 0.0]` (see `SpectralWaveComponent` above). |
| `scoring` | SurfScoringBreakdown | — | Yes | Per-factor scoring breakdown (see below) |
| `swellHeight` | float | `group_wave_height` | Yes | Height of the dominant `multiSwell` partition — i.e. the deep-water reference, the same point as `multiSwell` (marine `83f0205`). When the deep-water reference is unavailable for that timestep the field falls back to the cross-shore transect reference point's SWAN `HSWELL`, or to that point's `HSIGN` when `HSWELL` is absent — a different quantity at a different place; `multiSwell` still goes `null`. Nullable in the schema, but not emitted null in practice: a timestep whose reference point carries no `waveHeight` is skipped in its entirety, so an entry that exists always carries a `swellHeight`. |
| `breakingFaceHeight` | float | `group_wave_height` | Yes | Face height (trough-to-crest) at SwellTrack's break point — the H1/10 Rayleigh factor (1.27 × Hs) applied to the break-point Hs, per ADR-095 Amendment 1 "K-G/Caldwell — amended". `null` when unavailable. |
| `breakingHawaiianHeight` | float | `group_wave_height` | Yes | Hawaiian scale = `breakingFaceHeight × 0.5`. `null` when unavailable. |
| `windSource` | str | — | Yes | `"hrrr"` for forecast timesteps; `"station"` or `"forecast_provider"` for t=0. |
| `breakPoints` | list[object] | — | Yes | QB peak locations along the cross-shore transect (T3.4). `null` when no QB peak ≥ 0.25 detected (flat conditions, single-point mode, or QB data absent). Multiple entries for multi-bar beaches (outer bar + inner bar). |
| `breakPoints[].distanceFromShore` | float | — | — | Distance from shore in meters. |
| `breakPoints[].depth` | float | — | — | Water depth at the break point in meters. |
| `breakPoints[].waveHeight` | float | — | — | Wave height (HSIGN) at the break point in meters (not unit-converted — physical position). |

> **Sampling position — corrected 2026-07-27.** `swellHeight` and `breakingFaceHeight` previously read "at the ~10m depth point" / "at ~10m depth". Both are void: ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture, and Amendment 1 moved the face-height calculation to SwellTrack's break point.

#### SurfScoringBreakdown

Per-factor scoring detail returned inside each `SurfForecast` entry. Three weighted factors (max 100) plus three signed adjustments. Additive identity: `total = waveHeight + wavePeriod + waveOrganization + beachAlignment + directionalExposure + timeOfDay`.

| Field | Type | Description |
|---|---|---|
| `waveHeight` | int | Wave height factor score (0–35) |
| `wavePeriod` | int | Wave period factor score (0–35+; multipliers may exceed 35) |
| `waveOrganization` | int | Wave organization composite score (0–30) |
| `organizationWind` | float | Wind effect contribution within organization (0–~15; 50% of 30) |
| `organizationSwellDominance` | float | Swell dominance contribution (0–7.5; 25% of 30) |
| `organizationDirectionalSpread` | float | Directional spread contribution (0–4.5; 15% of 30). From SWAN DSPR. |
| `organizationCrossSwell` | float | Cross-swell interference contribution (0–3; 10% of 30). From SPECOUT. |
| `beachAlignment` | int | Signed; beach angle alignment adjustment (0 = direct hit, negative = misaligned) |
| `directionalExposure` | int | Signed; 0 when open, negative when blocked by headland/bathymetry |
| `timeOfDay` | int | Signed; positive at dawn (bonus), negative in afternoon (penalty), 0 otherwise |

#### FishingForecast

Fishing conditions forecast for one spot for one period.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `periodStart` | str | — | No | Period start time (UTC ISO-8601) |
| `periodEnd` | str | — | No | Period end time (UTC ISO-8601) |
| `periodLabel` | str | — | No | (locale) Human-readable period: "Early Morning", "Late Afternoon", etc. |
| `overallScore` | int | — | No | Composite score 0–100 (pressure + tide + solunar + time of day; does NOT include temperature — temperature is per-species only) |
| `pressureScore` | int | — | No | Pressure component sub-score 0–100 |
| `tideScore` | int | — | No | Tide component sub-score 0–100 |
| `solunarScore` | int | — | No | Solunar component sub-score 0–100 |
| `waterTempScore` | int\|null | — | No | Always null — temperature scoring is per-species via `speciesScores`, not a single composite value. Retained in the response schema for backward compatibility. |
| `timeofdayScore` | int | — | No | Time-of-day component sub-score 0–100 |
| `speciesScores` | list[object] | — | Yes | Per-species score adjustments; each entry's `status` field is (locale) |
| `conditionsText` | str | — | No | (locale) Natural-language conditions summary |
| `windSpeed` | float | `group_ocean_speed` | Yes | Wind speed (informational, not scored) |
| `windDirection` | float | — | Yes | Wind direction (informational) |
| `windGust` | float | `group_ocean_speed` | Yes | Wind gust (informational) |
| `swellHeight` | float | `group_wave_height` | Yes | Swell height (informational, not scored) |
| `swellPeriod` | float | `group_wave_period` | Yes | Swell period (informational) |

#### SolunarTimes

Solunar major/minor feeding periods for one date at one location. Computed via Skyfield — no external API.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `date` | str | — | No | Date (YYYY-MM-DD) |
| `moonPhase` | str | — | No | (locale — reuse existing `moon_phases.*` keys) `"new"`, `"waxing_crescent"`, `"first_quarter"`, `"waxing_gibbous"`, `"full"`, `"waning_gibbous"`, `"last_quarter"`, `"waning_crescent"` |
| `moonIllumination` | float | — | No | 0.0–1.0 |
| `moonrise` | str | — | Yes | Moonrise time (UTC ISO-8601, null if moon doesn't rise) |
| `moonset` | str | — | Yes | Moonset time (UTC ISO-8601, null if moon doesn't set) |
| `moonTransit` | str | — | No | Moon transit (highest point) time (UTC ISO-8601) |
| `moonUnderfoot` | str | — | No | Moon underfoot (opposite transit) time (UTC ISO-8601) |
| `sunrise` | str | — | Yes | Sunrise time (UTC ISO-8601) **for this request's `lat`/`lon`**, not the operator's weewx station — added C-47 (2026-07-25) so a caller needing sun times for an arbitrary coordinate (the marine service's fishing period/scoring math for a fishing spot) never has to substitute the station's sun times for a spot that may be far away. Null on polar day/night, same convention as `moonrise`/`moonset`. |
| `sunset` | str | — | Yes | Sunset time (UTC ISO-8601), same lat/lon and nullability notes as `sunrise` |
| `majorPeriods` | list[object] | — | No | Two per day, centered on transit and underfoot. Each: `{start, end}` (UTC ISO-8601) |
| `minorPeriods` | list[object] | — | No | Two per day, centered on moonrise and moonset. Each: `{start, end}` (UTC ISO-8601) |
| `intensity` | float | — | No | 0.0–1.0, driven by moon phase (new/full = 1.0, quarter = 0.7, between = 0.5) |

#### SurfZoneForecast

NWS Surf Zone Forecast per county zone per day.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `date` | str | — | No | Forecast date (YYYY-MM-DD) |
| `countyZone` | str | — | No | NWS county zone identifier |
| `ripCurrentRisk` | str | — | No | (locale) `"low"`, `"moderate"`, or `"high"` |
| `surfHeightMin` | float | `group_wave_height` | Yes | Minimum breaking surf height |
| `surfHeightMax` | float | `group_wave_height` | Yes | Maximum breaking surf height |
| `uvIndex` | int | — | Yes | UV index (1–11+) |
| `waterTemp` | float | `group_temperature` | Yes | Water temperature |
| `windText` | str | — | Yes | Wind description |
| `hazardsText` | str | — | Yes | Hazard statements |

#### BeachSafetyAssessment

Composite beach safety assessment per location.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `safetyLevel` | str \| null | — | Yes | **Always null in v1 (T9.1).** The two-threshold sea-state classifier (`classify_sea_state()` in `endpoints/beach_safety.py`) that used to produce `"safe"`/`"caution"`/`"dangerous"` was rejected as a crude composite — a single label collapsing wave height and period loses information a visitor needs to make their own judgment call. The function is retained in the module (used by tests exercising the classification thresholds directly) but its output is no longer wired into the response. The individual hazard fields below (`ripCurrentRisk`, `waveHeight`, `wavePeriod`, `uvIndex`, `comfortLevel`, `visibility`, `windSpeed`, `activeAlerts`) speak for themselves; the field is kept in the response shape (rather than removed) for backward compatibility. |
| `waveHeight` | float | `group_wave_height` | Yes | Current/forecast wave height |
| `wavePeriod` | float | `group_wave_period` | Yes | Current/forecast wave period |
| `ripCurrentRisk` | str | — | Yes | (locale) `"low"`, `"moderate"`, `"high"` (from SRF) |
| `waterTemp` | float | `group_temperature` | Yes | Water temperature |
| `comfortLevel` | str | — | Yes | (locale) `"comfortable"`, `"cool"`, `"cold"`, `"dangerous"` |
| `uvIndex` | int | — | Yes | UV index |
| `visibility` | float | `group_visibility` | Yes | Visibility |
| `windSpeed` | float | `group_ocean_speed` | Yes | Wind speed |
| `windDirection` | float | — | Yes | Wind direction |
| `activeAlerts` | list[str] | — | No | Alert headlines relevant to beach safety |

#### MarineLocationSummary

Summary snapshot for one marine location (used by the marine landing page location cards and the Now page summary card).

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `locationId` | str | — | No | Location slug from config |
| `name` | str | — | No | Display name |
| `coordinates` | object | — | No | `{lat, lon}` |
| `activities` | list[str] | — | No | Enabled activities for this location |
| `currentConditions` | MarineObservation | — | Yes | Latest conditions — populated from the card data source contract (below), not raw NDBC buoy |
| `currentTide` | object | — | Yes | **Null on cards (ADR-091).** All locations sharing a CO-OPS station show identical tide data — visual noise on the landing page. Tide information lives in the activity detail tabs (boating, fishing, beach safety, surfing) where it has context. |
| `activeAlerts` | list[MarineAlertSummary] | — | Yes | Active marine alerts, each `{headline, alertType}`; `alertType` is one of `marineZone`, `coastalFlood`, `beachHazard` (classified from the NWS `event` string for dashboard per-tab filtering, T3.5) |
| `surfRating` | int | — | Yes | Current surf quality stars (1–5, if surf enabled) |
| `beachSafetyLevel` | str | — | Yes | Current safety level (if beach_safety enabled) |
| `photoUrl` | str | — | Yes | Always `null`. Location photos are static files served by Caddy at `/marine-photos/*` — the API is not involved in photo URL resolution (ARCHITECTURE.md layer responsibilities: static assets served by Caddy are not API concerns). The dashboard constructs photo URLs directly from the location ID. |

#### Card data source contract (ADR-091)

`_location_summary()` in `endpoints/marine.py` populates card fields from these sources. The dashboard never sees provider names — it renders whatever the API returns.

| Card field | Primary source | Fallback | Unit conversion |
|---|---|---|---|
| `waveHeight` | WaveWatch III first forecast point (offshore, deep-water, 50 km resolution) | NDBC buoy Hs (already-fetched observation) → null. Suppressed (null) for harbor-classified locations. Surf forecasts use SWAN via the dedicated surf endpoint, not this card. | meter → operator `group_wave_height` |
| `windSpeed` | Station hardware via weewx archive (when `is_station_served()` returns True) | Configured forecast provider `fetch_current_conditions(lat, lon)` | Provider handles conversion |
| `windDirection` | Same as windSpeed | Same as windSpeed | degrees (no conversion) |
| `airTemp` | Same as windSpeed | Same as windSpeed | Provider handles conversion |
| `waterTemp` | Ocean data resolver `resolve(needs="surface")` — tiered: on-premises sensor → OFS → MUR SST → RTOFS | Full chain in PROVIDER-MANUAL §14.12 | Celsius → operator `group_temperature` |
| `weatherCode` | Configured forecast provider `fetch_current_conditions(lat, lon)` | None | WMO code (no conversion) |
| `isDay` | Configured forecast provider | None | boolean |

`is_station_served()` (in `services/marine_location_resolver.py`) determines whether a marine location is within `dedup_radius_km` (default 2.5 km) of the weather station. Locations within range get station hardware data; all others get forecast provider data.

#### Ocean data canonical models (ADR-091)

These models are the output of the ocean data resolver (`services/ocean_data_resolver.py`). Endpoints call the resolver and populate response fields from whichever result fields are non-null — no branching on provider names or coverage tier. Full architecture, per-consumer usage table, coverage tier semantics, and unit conversion rules in `docs/planning/briefs/WATER-TEMPERATURE-DATA-SOURCE-BRIEF.md` §"System Integration: Marine Ocean Data Resolver".

##### OceanDataResult

Resolver output — all ocean model data for one location at one point in time.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `surface_temp` | float | Yes | Surface water temperature (Celsius, pre-conversion) |
| `column_profile` | list[WaterColumnLayer] | Yes | Temperature + salinity at each depth level |
| `thermocline_depth_m` | float | Yes | Depth of maximum dT/dz gradient |
| `bottom_temp_c` | float | Yes | Temperature at deepest non-null depth level |
| `seafloor_depth_m` | float | Yes | Model-grid seafloor depth (NOT CUDEM — model resolution only) |
| `surface_current_speed` | float | Yes | Surface current speed (m/s) |
| `surface_current_dir` | float | Yes | Surface current direction (degrees true north) |
| `current_profile` | list[object] | Yes | `[{"depth_m", "speed_ms", "dir_deg"}, ...]` |
| `surface_salinity` | float | Yes | Surface salinity (PSU) |
| `water_level_msl` | float | Yes | Modeled water level vs MSL (meters) |
| `water_level_mllw` | float | Yes | Modeled water level vs MLLW (meters) |
| `forecast` | list[OceanForecastPoint] | Yes | Surface temp + currents over forecast horizon |
| `source` | str | No | e.g. `"ofs:WCOFS"`, `"rtofs"`, `"mur_sst"` |
| `source_type` | str | No | `"modeled"` or `"observed"` |
| `timestamp` | str | No | ISO 8601 |
| `coverage_tier` | str | No | `"ofs"`, `"regional_erddap"`, `"rtofs"`, `"mur_sst"`, `"observed"`, `"unavailable"` |

##### WaterColumnLayer

| Field | Type | Nullable | Description |
|---|---|---|---|
| `depth_m` | float | No | Depth in meters |
| `temperature` | float | No | Temperature (operator display units after `convert()`) |
| `salinity` | float | Yes | Salinity in PSU (no conversion) |

##### WaterColumnProfile

| Field | Type | Nullable | Description |
|---|---|---|---|
| `layers` | list[WaterColumnLayer] | No | One entry per depth level |
| `thermocline_depth_m` | float | Yes | Depth of maximum temperature gradient |
| `bottom_temp` | float | Yes | Temperature at deepest level (operator display units) |
| `seafloor_depth_m` | float | Yes | Model-grid seafloor depth |
| `source` | str | No | e.g. `"ofs:WCOFS"` |
| `timestamp` | str | No | ISO 8601 |

##### OceanCurrentSnapshot

| Field | Type | Nullable | Description |
|---|---|---|---|
| `speed` | float | No | Current speed (operator display units) |
| `direction` | float | No | Degrees true north |
| `depth_m` | float | Yes | null = surface |

##### OceanForecastPoint

| Field | Type | Nullable | Description |
|---|---|---|---|
| `time` | str | No | ISO 8601 |
| `surface_temp` | float | No | Surface temperature (operator display units) |
| `current_speed` | float | Yes | Current speed (operator display units) |
| `current_direction` | float | Yes | Degrees true north |
| `source` | str | No | Provider attribution |

#### Composite water level models (ADR-091)

Output of the water level compositor (`services/water_level_compositor.py`). Combines CO-OPS harmonic predictions with OFS non-tidal residual. Full algorithm rationale, bias correction technique, and persistence fallback formula in `docs/planning/briefs/TIDE-ACCURACY-BRIEF.md` §"The Optimal Architecture: Composite Water Level" and §"Implementation Design" (compositor algorithm, data flow diagram, API response shape). CO-OPS vs OFS accuracy comparison in §"Research Questions — Answered" Q1/Q3/Q4. Dashboard display design (TideChart overlays, residual stat tile, storm surge indicator) in §"Dashboard Display Design".

##### Compositor output fields (on TideBundle)

The compositor output is inlined into the `TideBundle` response (not a separate model). The compositor's `compute_composite()` returns these fields, which are set directly on the TideBundle:

| Field | Type | Nullable | Description |
|---|---|---|---|
| `currentResidual` | object | Yes | `{"value": float, "quality": "good"\|"stale", "source": "coops_observed", "description": str}` — measured meteorological water level offset. Quality is `"good"` when most recent observation ≤1h old, `"stale"` when 1–6h old. Null when no CO-OPS observations available or most recent is >6h old. |
| `totalWaterLevelForecast` | list[object] | Yes | `[{"time": iso, "height": float, "residual": float}, ...]` — composite forecast: CO-OPS prediction + bias-corrected OFS residual (or persistence-decayed residual). Heights and residuals in the operator's target unit. |
| `residualForecastSource` | str | Yes | `"ofs"` (bias-corrected OFS forecast), `"persistence"` (exponentially decayed current residual), or `"unavailable"`. |
| `stormSurgeLevel` | str | Yes | Classification of current absolute residual: `"elevated"` / `"depressed"` (0.15–0.5 ft), `"significant"` (0.5–1.0 ft), `"storm_surge"` (>1.0 ft), or null (normal, <0.15 ft). Thresholds apply after unit conversion to target unit. |

The existing TideBundle fields (`predictions`, `waterLevels`, `locationId`, `locationName`, `coordinates`, `source`) are unchanged. All compositor fields are nullable — when OFS is unavailable or the compositor returns no residual, the response is identical to the pre-compositor behavior.

**Composite algorithm:** (1) Observed residual = CO-OPS observation − interpolated CO-OPS prediction for each past 24h timestamp. (2) Current residual = most recent observed residual. (3) When OFS available: forecast residual = OFS zeta − CO-OPS prediction, bias-corrected by anchoring to observed residual at current time. When OFS unavailable: persistence fallback — decay current residual exponentially (tau = 12h). (4) Total water level = prediction + corrected residual.

#### Bundle types

Bundles wrap domain-specific models with location metadata, freshness block (§2), and stationClock (§2). Follow the existing `ForecastBundle` pattern.

**`MarineBundle` and `TideBundle` are implemented as declared** — `endpoints/marine.py` and `endpoints/tides.py` construct and `model_dump()` these exact Pydantic models from `models/responses.py`.

| Bundle | Contains | Response for |
|---|---|---|
| `MarineBundle` | `MarineObservation`, `list[MarineForecastPoint]`, `list[MarineTextForecast]` | `GET /api/v1/marine[/{locationId}]` |
| `TideBundle` | `list[TidePrediction]`, `list[WaterLevel]`, `totalWaterLevelForecast` (ADR-091), `currentResidual` (ADR-091), `stormSurgeLevel` (ADR-091) | `GET /api/v1/tides[/{locationId}]` |

Each bundle also carries: `locationId`, `locationName`, `coordinates`, `freshness` block, `stationClock`, `units`.

**There are no `SurfBundle`, `FishingBundle`, or `BeachSafetyBundle` Pydantic models.** Earlier drafts of those three classes (written in Phase 0C, ahead of the Phase 5 endpoint implementations) were removed from `models/responses.py` (T4.3, Phase 4 cleanup) — they were never referenced by `endpoints/surf.py`, `endpoints/fishing.py`, or `endpoints/beach_safety.py`, which each build and return a plain dict directly (the standard envelope, §2), and their field shapes had drifted from what those endpoints actually return. The tables below are the actual, ground-truth shapes — sourced by reading the endpoint code directly — and are what `docs/contracts/openapi-v1.yaml` documents.

##### Surf bundle (actual shape) — `GET /api/v1/surf[/{locationId}]`

Source: `endpoints/surf.py`.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `forecast` | list[SurfForecast] | No | One entry per SWAN forecast timestep. Contains all four height fields (`swellHeight`, `waveHeightAtBreak`, `breakingFaceHeight`, `breakingHawaiianHeight`) plus `windSource`, `scoringBreakdown`, and `breakPoints` (QB peak locations, T3.4) per timestep. Empty list if SWAN has never run successfully. |
| `zoneForecast` | SurfZoneForecast | Yes | NWS SRF forecast for the covering county zone; `null` if unavailable |
| `spectralComponents` | list[SpectralWaveComponent] | No | NDBC buoy spectral swell decomposition — **reference data only**. Not used for scoring or `multiSwell` display (T3.5). Empty list if no spectral-capable buoy configured or NDBC fetch failed. |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions for the surf page's tide overlay (informational, not scored) |
| `nearshoreModel` | str | No | `"SWAN + SwellTrack"` (ADR-093/096) |
| `lastRunTime` | str | Yes | ISO-8601 timestamp of SWAN run completion |
| `dataAge` | int | Yes | Age of SWAN output in seconds |
| `breakerFormula` | str | No | `"komar_gaughan"` or `"caldwell"` per spot config |
| `surfHeightDisplay` | str | No | `"face"` or `"hawaiian"` per spot config |
| `source` | str | No | Fixed string `"swan+ndbc+coops+nws_srf"` (ADR-096) |
| `generatedAt` | str | No | UTC ISO-8601 with Z |

##### Fishing bundle (actual shape) — `GET /api/v1/fishing[/{locationId}]`

Source: `endpoints/fishing.py`. Nested by day: no flat top-level `forecast` list or singular top-level `solunar` field — each day carries its own periods and solunar data.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `days` | list[object] | No | One entry per forecast day (3 days). Each entry: `{"date": "YYYY-MM-DD", "periods": list[FishingForecast], "solunar": SolunarTimes}` |
| `species` | list[str] | No | From the location's `FishingSpotConfig.species` |
| `targetCategory` | str | No | First entry from the location's `FishingSpotConfig.target_categories` list (singular for wire compatibility; config supports multiple categories) |
| `habitatFeatures` | object \| null | Yes | CUDEM-derived habitat annotations (drop-offs, reefs, ledges, channels, pinnacles); `null` when the location has no bathymetric profile (i.e., no `surf` sub-block configured) |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions, also used server-side to derive each period's `tide_state` input to the fishing scorer |
| `source` | str | No | Fixed string `"ndbc+coops+solunar"` |
| `generatedAt` | str | No | UTC ISO-8601 with Z |

##### Beach-safety bundle (actual shape) — `GET /api/v1/beach-safety[/{locationId}]`

Source: `endpoints/beach_safety.py`. There is no `zoneForecast` field in the actual response — SRF-sourced rip current risk and UV index are folded directly into `assessment` instead. UV index falls back to `services/marine_weather_cache.py`'s `get_current_conditions()` (T9.2) when NWS SRF doesn't supply it — currently a no-op in practice because no forecast provider's `fetch_current_conditions()` populates a UV field yet (see PROVIDER-MANUAL §4 "Fields available from provider APIs but not yet mapped"); wired so `uvIndex` starts flowing automatically once a provider adds one.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `assessment` | object (`BeachSafetyAssessment` shape) | No | `safetyLevel`, `waveHeight`, `wavePeriod`, `ripCurrentRisk`, `waterTemp`, `comfortLevel`, `uvIndex`, `visibility`, `windSpeed`, `windDirection`, `activeAlerts` |
| ~~`nwpsV15`~~ | ~~object \| null~~ | — | Removed (NWPS eliminated per ADR-093). Rip current data sourced from NWS SRF when available. |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions |
| `waterLevels` | list[WaterLevel] | No | CO-OPS observed water levels |
| `externalLinks` | list[object] | No | `{label, url}` from the location's `BeachSafetyConfig.external_links` |
| `source` | str | No | Fixed string `"swan+ndbc+nws_srf+coops+nws_alerts"` (ADR-096) |
| `generatedAt` | str | No | UTC ISO-8601 with Z |

### Marine unit groups

Five new unit groups for marine data. Registered in `units/groups.py` and `services/units.py`.

| Group | Base unit | Conversions |
|---|---|---|
| `group_wave_height` | meter | meter ↔ foot (× 3.28084) |
| `group_wave_period` | second | Single unit — no conversion. Group exists for canonical consistency. |
| `group_water_level` | meter | meter ↔ foot (× 3.28084) |
| `group_ocean_speed` | meter_per_second | m/s ↔ knot (× 1.94384), m/s ↔ mph (× 2.23694), m/s ↔ km/h (× 3.6) |
| `group_visibility` | nautical_mile | nm ↔ statute_mile (× 1.15078), nm ↔ kilometer (× 1.852) |

**Preset defaults:**

| Marine group | US | METRIC | METRICWX |
|---|---|---|---|
| `group_wave_height` | foot | meter | meter |
| `group_wave_period` | second | second | second |
| `group_water_level` | foot | meter | meter |
| `group_ocean_speed` | **knot** | **knot** | **knot** |
| `group_visibility` | nautical_mile | nautical_mile | nautical_mile |

**`group_ocean_speed` defaults to knots in ALL three presets.** Maritime convention overrides land convention. WMO, IMO, and every national maritime service uses knots for wind speed and current speed over water. Even countries that use m/s on land use knots at sea. Similarly, `group_visibility` defaults to nautical miles universally.

**`group_ocean_speed` vs `group_speed`:** These are separate groups. The existing `group_speed` (land wind) remains unchanged — it maps to mph / km·h⁻¹ / m·s⁻¹ per the existing presets. An operator using METRICWX sees land wind in m/s and marine wind in knots by default — which is correct practice (weather services do exactly this). If they want both in m/s, they override `group_ocean_speed = meter_per_second` in `api.conf [units][[groups]]`.

Display labels: `"kt"` (knot), `"ft"` (foot), `"m"` (meter), `"s"` (second), `"nm"` (nautical mile), `"mi"` (statute mile), `"km"` (kilometer).

---

## §17 Marine Enrichment

Four enrichment processors for marine data. Each follows the existing enrichment pipeline pattern (register against an endpoint key, run after provider fetch and before response serialization).

### SWAN nearshore model (ADR-093, corrected ADR-095)

**SWAN is the only nearshore wave model.** SWAN runs in the marine service on a schedule tied to the extended HRRR cycles (4×/day at 00/06/12/18Z). All SWAN code left the API this phase; there is no `[nearshore]` pip extra in the API. There is no `nearshore_model` config key — SWAN runs when the marine service is configured and has SWAN available. NWPS is eliminated (ADR-093 supersedes ADR-084).

**WaveWatch III is NOT a surf forecast source.** WW3 remains the deep-water boundary input to SWAN (via `providers/marine/wavewatch.py`) and continues serving the marine endpoint's offshore forecast. WW3 is never used as a surf endpoint data source. The surf endpoint serves the last successful SWAN cache if the runner fails — no fallback to any other model.

**Data pipeline per forecast timestep (ADR-095 corrected, amended for SwellTrack):**

```
SWAN L2 deep-water reference point, on the spot's measured ~15m contour (POINTS + SPECOUT + TABLE PT*)
  → SWAN's own watershed partitions from TABLE PT* columns (T4B.2) → N swell partitions
  → carried on the internal "spectral_dwr" channel
  → store as multiSwell (deep-water values, comparable to NDBC buoy; frequencyRange always [0.0, 0.0])
  → swellHeight = dominant partition height; cross-swell and swell-dominance scoring inputs
  → canonical partition list for partition matching

SWAN handoff point (L3 CURVE at structure-affected depth, or L2 at 15m for open spots — SPECOUT + TABLE PT*)
  → SWAN's own watershed partitions from TABLE PT* columns (T4B.2) → N partitions for SwellTrack input
  → carried on the internal "spectral" channel, with the SPECOUT freqs/dirs/energy arrays
  → match to canonical partition list from the deep-water reference point
  → a handoff partition matching nothing in the canonical list lands in the "other" bucket,
    partitionIndex = -1

PT* data unavailable for a given (point, timestep) — TABLE missing, or no coordinate match
within tolerance — → partitions empty, WARNING logged naming spot and timestep, never recomputed
(no-silent-fallback rule)

Deep-water reference unavailable — for the whole forecast (the spot has no locatable 15m
contour, so no DWR POINTS/SPECOUT/TABLE is emitted at all) or for one timestep —
  → multiSwell null, canonical partition list None, WARNING logged
  → the handoff partitions are NEVER substituted: they are sampled at the handoff depth,
    inside or beside the surf zone, and publishing them as the swell card is the defect this
    rule exists to prevent (SURF-23)

Each partition × each transect → independent SwellTrack run (handoff to shore)
  → the transect bathymetry profile is truncated at that transect's per-hour handoff depth
    before the model runs, so SwellTrack never re-shoals water SWAN already carried
  → a profile that cannot be truncated there is skipped with a WARNING, never run untruncated
  → Hs at 3-5m CUDEM resolution (friction enabled: cfjon=0.038 swell, 0.067 windsea)
  → break point: H/d = gamma crossing
  → breaker type: Iribarren number (xi_0)
  → wave shapes: Stokes/cnoidal by depth regime

SurfBeat strip (every 3 hours, when surfbeat_enabled=true):
  → SWAN SURFBEAT stationary 2D strip run
  → IG spectral analysis: Hs_ig below 0.04 Hz
  → set timing from IG spectral peak period
  → approach-zone Hs for blended beach profile

At each transect point: Hs_total = sqrt(sum(Hs_partition_i²))
  → combined saturation check: Hs_total ≤ γd

At each partition's break point:
  → face height = 1.27 × Hs (Rayleigh H1/10, source="break_point")
  → store as breakingFaceHeight

Across open transects:
  → best peak face height, spot average face height
  → peel angle from break point spatial variation

surf_scorer.score_surf(bestPeakFaceHeight, DSPR, partitions, ...) → quality score
```

**Cross-shore transect reference point (what remains of the pre-SwellTrack path):**

```
SWAN cross-shore transect output for the timestep
  → select_reference_point() (services/surf_pipeline_timestep.py):
      the transect point just offshore of the biggest QB peak (>= 0.25),
      or — when nothing is breaking — the point nearest 10 m depth
  → HSIGN at that point: required. Absent → the whole timestep is skipped.
  → HSWELL at that point → swellHeight, UNLESS the deep-water reference has
    partitions for this timestep, in which case the dominant partition's
    height overwrites it (marine 83f0205)
  → DSPR at that point → directionalSpread, and the directional-spread
    scoring sub-factor
  → QB peaks along the transect → breakPoints
```

> **Corrected 2026-07-27.** This block previously read "find ~10m depth point on transect / HSWELL at ~10m depth → store as swellHeight / HSIGN at ~10m depth → store as waveHeightAtBreak (backward compatible) / breaker_height.hsig_to_face_height(..., source="deep_water") → store as breakingFaceHeight / degraded: true in response". Three parts of that are void. The reference point is not a fixed ~10 m depth — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture, and `select_reference_point()` picks by QB peak, using 10 m only as the no-breaking tiebreak. `waveHeightAtBreak` and `breakingFaceHeight` have no transect-derived fallback at all: when SwellTrack produces no face height, both are `null` (`endpoints/surf.py`). And `degraded` was replaced by `modelStatus`.

**SWAN integration (ADR-095 corrections):** All components below run in the marine service.

| Component | Source |
|---|---|
| Wave physics engine | SWAN (Fortran subprocess in the marine service) — two-level nested grid per cycle |
| Wind forcing (hours 0–48) | HRRR forecast wind at 3km via NOMADS (`providers/wind/hrrr.py`) — extended cycles only (00/06/12/18Z) |
| Wind forcing (hours 48–72) | GFS forecast wind at 0.25° (~25km) via NOMADS (`providers/wind/gfs.py`) — supplements HRRR to reach 72h |
| Deep-water boundary | WaveWatch III directional spectrum via ERDDAP (`providers/marine/wavewatch.py`) |
| Bathymetry (2-D grid) | CUDEM via NCEI getSamples endpoint (`enrichment/bathymetry.py`) — lazy-downloaded on first run, cached to `/etc/weewx-clearskies/swan_bathymetry.json` |
| Water level (WLEVEL) | CO-OPS tidal predictions (`providers/tides/coops.py`) — time-varying, uniform across domain, hourly timestep (ADR-095). Required as of C-77 (2026-07-26): a datum-mismatch/fetch failure aborts the SWAN run rather than omitting WLEVEL (rules/coding.md §1); superseded a prior reading of ADR-098 that treated WLEVEL as optional |
| Ocean currents (CURRENT) | OFS surface current U/V components (`providers/ocean/ofs.py`) — time-varying per grid point. Required as of C-77 (2026-07-26): a failed or empty fetch aborts the SWAN run rather than omitting CURRENT (rules/coding.md §1 "A model runs on all its inputs or it does not run"); superseded the ADR-095 "omitted when unavailable" behavior |
| Structure physics (OBSTACLE) | SWAN native OBSTACLE command — structure types from wizard Overpass API discovery. Replaces wave_transform Supplement 2 (ADR-095) |

**Nested grid architecture:** SWAN executes two sequential runs per cycle — an outer grid (~2–3 km resolution, ~5,000–8,000 points) covering the continental shelf approach, then an inner nest (~200–500m resolution, ~3,000–8,000 points) focused tightly on the configured surf locations. The outer run writes `NESTOUT` boundary files; the inner run reads them via `NGRID`. Total memory budget: ≤300 MB combined (both grids). This matches the operational pattern used by NWPS, PacIOOS, and other production nearshore systems — no operational system runs fine resolution over the full domain.

**Blended wind forcing:** HRRR (3km) provides high-resolution wind for hours 0–48 from extended cycles (00/06/12/18Z, 4×/day). GFS (0.25°, ~25km) supplements hours 48–72 to fill the 72-hour surf forecast card. The SWAN runner stitches HRRR and GFS wind grids into a single continuous wind input spanning 72 hours. The resolution transition at hour 48 does not affect nearshore physics — wave refraction, shoaling, and breaking are computed at the SWAN grid resolution, not the wind grid resolution.

**SWAN runner:** `services/swan_runner.py` in the marine service — executes two SWAN runs per cycle (outer grid + inner nest). Writes input files (computational grid, wind field, boundary spectra, bathymetry, WLEVEL, CURRENT, OBSTACLE, output CURVE transects), spawns SWAN subprocess, parses TABLE output and SPECOUT files. Output: transect data per surf spot per timestep across 72 forecast hours. Working directory: `/var/run/weewx-clearskies/swan/` (fixed path, not tempfile). **Hotstart:** each run writes a hotstart file after `COMPUTE`; the next run reads it via `INIT HOTSTART` so t=0 immediately has the real wave field from the previous run (no cold-start spin-up). Hotstart files persist at `{outer,inner}_hotstart.dat` in the SWAN workdir.

**Cross-shore CURVE transect output (ADR-095).** Each surf spot gets a CURVE transect perpendicular to the beach, from ~15m depth to ~1m depth, ~50m spacing (10–20 output points). Direction derived from `beach_facing_degrees + 180°`. Replaces the single-point OUTPUT POINTS command. TABLE output at each transect point: `HSIGN HSWELL DIR TM01 DEPTH QB DISSURF DSPR XP YP` (SETUP removed — SWAN SETUP command disabled in parallel OpenMP runs; `setup` field returns `null` in API responses). Break points identified by QB peaks along the transect.

> **SPECOUT placement — corrected 2026-07-27.** The paragraph above previously ended "SPECOUT (2D directional-frequency spectrum) at the ~10m depth point only (one per spot)." That is void — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture. There are two SPECOUT extractions per spot, each with its own companion `TABLE PT*`: the **deep-water reference** (one per spot, L2, on the spot's measured ~15 m contour) and the **handoff** (one per unique handoff grid cell, now first-match-wins L4 → L3 → L2 per transect per hour — E5 ruling D3, otherwise the same L2 point). ADR-095 Amendment 1 "SPECOUT extraction — amended"; PROVIDER-MANUAL §14.13 "Multi-SPECOUT extraction". **The deep-water reference is always L2-sourced and is NOT the 1D model's (SwellTrack's) starting point** (E5 ruling D4) — it stays on L2 at the spot's own 15 m contour in every case, regardless of which grid level supplies that spot's handoff, so a later reader must not "fix" an observed handoff/reference depth mismatch by moving the reference to whichever finest grid happens to cover 15 m.

**SWAN physics enabled (ADR-095).** TRIAD (Eldeberky 1996 defaults) for shallow-water triad wave-wave interactions — enabled at all levels. SETUP removed (unsupported in parallel OpenMP runs; nest boundary condition structurally wrong). Setup effect is delivered via WLEVEL input (tide + future analytic estimate). Per-level DIFFRACTION: stabilized (`DIFFRACTION 1 0.2 <smnum>`) at the structure grid (L4) only — L1, L2, and L3 (including L3's own 40 m nest) emit none. `smnum` scales with the grid's own `dx` (`smnum = round((90 / dx) ** 2 / 3)`; 27 at L4's fixed 10 m). L3 was the finest, and only, fine-detail grid before ADR-093 Amendment 3 (plan task E7, 2026-07-27) rescoped L3 to a coarser need-driven nesting/refraction step and moved DIFFRACTION to the new L4 structure grid.

**Two-tier schedule:** Full runs 4× daily on extended HRRR cycles (00/06/12/18Z) — outer + inner grids, 72-hour nonstationary forecast, ~7–12 min runtime. Hourly quick updates between full runs — stationary inner nest only with latest HRRR wind, <1 min runtime, single-snapshot merged into the existing forecast cache. Quick updates keep the "current conditions" entry fresh (< 1 hour old) without re-running the expensive outer grid. Not in the request path. Cache TTL = 6 hours (matches extended cycle interval). On failure, last-good cache retained indefinitely — stale SWAN data is always preferred to no data.

**Height fields in every `SurfForecast` entry (amended for SwellTrack):**

| Field | What it is | Source |
|---|---|---|
| `swellHeight` | Dominant deep-water swell partition height | Deep-water reference point at ~15m (L2), SWAN's own watershed partitions from TABLE PT* (T4B.2). Comparable to NDBC buoy reports. |
| `waveHeightAtBreak` | Total wave height at the break point (backward-compatible field name) | `breakingFaceHeight ÷ 1.27` — the SwellTrack break-point Hs. **No SWAN fallback:** `null` whenever SwellTrack produced no face height (`endpoints/surf.py`). The former "or ~10m SWAN fallback" is void — ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture. |
| `breakingFaceHeight` | Trough-to-crest breaking face height at actual break point | 1.27 × Hs at SwellTrack break point (H1/10 Rayleigh factor). Best peak across open transects. |
| `breakingHawaiianHeight` | Back-of-wave height (×0.5 of face height) | breakingFaceHeight × 0.5 |
| `bestPeakFaceHeight` | Highest face height among open transects | Max of breakingFaceHeight across non-structure-affected transects |
| `spotAverageFaceHeight` | Mean face height across open transects | Mean of breakingFaceHeight across non-structure-affected transects |
| `peelAngle` | Break line angle relative to wave crest | Computed from break point spatial variation across adjacent open transects (degrees) |
| `peelClassification` | Peel angle classification | `"closeout"` (<30°), `"fast"` (30-45°), `"good"` (45-66°), `"mellow"` (>66°) |
| `transectCount` | Total transects in measurement zone | Integer |
| `openTransectCount` | Transects not crossing any OBSTACLE | Integer |
| `degraded` | SwellTrack fallback indicator | `true` when SwellTrack failed and legacy SWAN pipeline used |
| `setTimingMinutes` | float \| null | Set wave timing from SurfBeat IG spectral peak (minutes between sets). `null` when SurfBeat disabled or unavailable. |
| `setAmplitudeM` | float \| null | IG wave height at shoreline (m). `null` when SurfBeat disabled or unavailable. |
| `igWaveHeightM` | float \| null | Infragravity significant wave height at shoreline (m). `null` when SurfBeat disabled or unavailable. |

**swellHeight and breakingFaceHeight are now from fundamentally different sources.** `swellHeight` is the dominant deep-water partition from SWAN's own watershed partitioning at ~15m (TABLE PT*, T4B.2) — what's arriving at the coast. `breakingFaceHeight` is H1/10 (1.27× Hs) at the actual break point from SwellTrack — what surfers see. The ratio varies with bathymetry, swell period, and tide.

All four fields are present in every response regardless of the operator's `surfHeightDisplay` preference. The API returns all representations; the dashboard selects which to show as primary.

**Breaker formulas (`enrichment/breaker_height.py`):**

Two formulas supported, configured per-spot via `breaker_formula` in the marine location config:

- **Komar-Gaughan (1973)** (default): `Hb = 0.39 × g^(1/5) × (Tp × Hsig²)^(2/5)`. General-purpose, works for all periods and coastline types. Depth-aware correction when SWAN output is in shallow water (< 15m). Output clamped to [Hsig, 3 × Hsig].
- **Caldwell (2007)** (opt-in `caldwell`): Empirically tuned for steep volcanic island coasts (Hawaii, Indonesia, Tahiti). Predicts H1/10 (set waves). **Auto-crossover:** when Tp < 10s, automatically falls to Komar-Gaughan (Caldwell is unreliable for short-period wind swell).

`hawaiian_height(face_height_m)` returns `face_height_m × 0.5`. Always proportional — no independent calculation.

**Scorer uses face height.** `surf_scorer.py` scores using `breakingFaceHeight`, not raw Hsig. The scoring thresholds represent what surfers consider good waves — surfers think in face height. `_WAVE_HEIGHT_RANGES_FT` are calibrated in face-height feet.

### SwellTrack configuration

| Config key | Type | Default | Location | Description |
|---|---|---|---|---|
| `friction_coefficient` | float | `0.038` | Per-spot (`SurfSpotConfig`) | Bottom friction coefficient (cfjon). Swell default 0.038, windsea 0.067. Always enabled — frictionless propagation is not production-valid. |
| `surfbeat_enabled` | bool | `true` | Per-spot (`SurfSpotConfig`) | Enable SurfBeat strip for IG/set timing. Increases compute time by ~12 min per cycle. |
| `surfbeat_cadence_hours` | int | `3` | Per-spot (`SurfSpotConfig`) | Hours between SurfBeat strip runs. Intermediate hours carry forward the last result (not interpolated). |
| `max_hs_m` | float | `4.0` | Per-spot (`SurfSpotConfig`) | Maximum expected significant wave height (m) for this spot. Used to compute the surf zone depth threshold: `d_break_max = max_hs_m / gamma`. The 1D grid uses 1–2m dx from shore to `d_break_max`. Computed at wizard setup from wave climate or operator input. |

**`surf_compute_host` / `surf_compute_verify_tls` removed from the API (T6.8, 2026-07-25).** `marine_service_url` (`api.conf [providers]`, §19.2) is the single key that replaced them. `POST /setup/providers/test-compute` (which tested connectivity using them) was orphaned by that removal and is itself removed as of T7.3/C-49 (2026-07-25), replaced by `POST /setup/providers/test-marine` (§18 setup-endpoint table; tests the marine service, not the retired compute-offload connection). SwellTrack/SurfBeat compute offloading is entirely internal to the marine service now; this note is historical.

**1D grid resolution (variable, depth-based).** The SwellTrack 1D grid uses variable resolution defined by depth zones, not distance from shore (see SURF-ZONE-MODEL-BRIEF §6.1 for full rationale). Depth zones are computed at wizard setup from the CUDEM bathymetric profile, the spot's `max_hs_m`, and the L3 SWAN grid extent:

| Zone | Depth range | Grid dx | Why |
|---|---|---|---|
| Fine zone | Shore to `max(1.3 × max_hs_m / gamma, structure_zone_depth)` | 1–2 m | Breaking, dissipation, break point detection, structure interactions. XBeach: dx ≤ 2m eliminates grid influence. 1.3× margin accounts for shoaling amplification before breaking. |
| Shoaling zone | Fine zone max to ~15m | 3–5 m | Shoaling, refraction, bar/trough structure. |
| Approach zone | > ~15m | CUDEM native (3–10 m) | Minimal wave transformation. |

**Relationship to the SWAN→SwellTrack handoff** (decided 2026-07-25, ADR-093 Amendment 2). `1.3 × max_hs_m / gamma` sizes SwellTrack's fine zone for the spot's **largest** swell — that is correct here, because the cached profile must serve every forecast hour including the biggest. Do not reuse this expression as the handoff depth: the handoff moves per forecast hour with that hour's own breaking depth (`Hs(hour) / gamma`), and freezing it at the largest-swell value was an error corrected on 2026-07-25. The fine zone is a static property of the cached profile; the handoff is a per-hour sampling choice. `structure_zone_depth` can only deepen the fine zone — it never moves the handoff.

**SwellTrack starts at the handoff, not at the seaward end of the profile** (marine `7fb75f9`). The per-transect, per-hour handoff depth is resolved before the model runs and the cached profile is truncated there — the seaward-most profile sample at or shallower than the handoff becomes the model's first point. SwellTrack takes its shoaling reference (`Cg0`) from the first point of whatever profile it is handed, so without the truncation the handoff `Hs` — which SWAN had already carried to the handoff depth — was injected at the profile's deepest sample and shoaled a second time over water SWAN had already modelled. Truncation is on the **raw, untided** profile depth, matching the upstream handoff selection, and it snaps shoreward to an existing sample so the model can never start seaward of the handoff. The handoff is keyed by transect index, so every partition of a transect gets an identical grid and the shared-grid RSS combination holds by construction. A profile that cannot be truncated (handoff shallower than every sample, fewer than two samples left, non-physical depth) logs a WARNING and the transect is skipped — it never falls back to the untruncated profile.

The dispersion relation `ω² = g·k·tanh(kd)` is solved by Newton-Raphson on the dimensionless form `y·tanh(y) = x`, started from the Fenton & McKee (1990) explicit approximation, with a relative-step convergence test and an iteration cap (marine `7fb75f9`). The same equation was previously iterated as a fixed-point map a fixed number of times; that map does not converge for `kd ≲ 1` and returned wavelengths as low as 24% of the true value in shallow water.

The fine zone extends to whichever is deeper: the maximum breaking depth with shoaling margin (`1.3 × max_hs_m / gamma`) or the structure interaction depth (`structure_zone_depth` — deepest structure depth + margin, 0.0 when no structures configured). The 1.3× margin accounts for shoaling amplification before breaking (a 4m offshore swell can break at ~7m depth, not 5.5m). `structure_zone_depth` is 0.0 by default — it only extends the fine zone when structures are present. Structure changes re-trigger profile generation.

The CUDEM source profile is interpolated to the variable-resolution grid using **PCHIP** (Piecewise Cubic Hermite Interpolating Polynomial) — preserves sandbar curvature without overshoot artifacts. The interpolated profile is generated once at spot setup and cached at `/etc/weewx-clearskies/spot_profiles/{spot_id}.json`. SwellTrack reads the pre-interpolated profile from the cache on every call. Structure changes re-trigger profile generation.

> **Every distance in a cached spot profile is measured from the profile's coastline anchor, never from the spot pin.** This is a property of how the profile is generated, not a convention a consumer may choose: `services/grid_sizing_chain.py` passes the anchor (`coast_lat`, `coast_lon` — from `find_shoreline_from_grid()`, the depth-zero crossing shoreward of the pin) into both `extract_native_profile_from_grid()`, which produces the per-sample `distance_m` values, and `enrichment/bathymetry.py`'s `find_depth_contour_distance()`, which produces `contour_15m_distance_m` and `contour_30m_distance_m`. The anchor is stored in the same JSON as `coastline_lat`/`coastline_lon`. **A consumer that projects one of these distances from the spot pin overshoots by the pin's own offshore offset from the anchor** — at `huntington-city-beach-pier` the pin is on the pier, 209.6 m offshore of the anchor on bearing 238.0°, in 4.26 m of water. The operator-drawn shoreline segment is not the anchor either: it lies 213.5 m offshore of it at the same spot. See PROVIDER-MANUAL §14.15 "Per-spot profile and grid-sizing caches" and the anchor note under "Multi-SPECOUT extraction" for the producer side and the two consumers that got this wrong (marine `bd8c928`, `ac6bd8a`).

**Precomputed SwellTrack cache (T4B).** `GET /api/v1/surf/{locationId}`'s per-timestep loop no longer runs the 1D pipeline on every request — it reads a precomputed result from the SWAN forecast cache (`payload["swelltrack"][validTime]`), falling back to the on-demand call only on a cache miss or a malformed entry. The precompute happens once per forecast timestep per spot at the end of each successful SWAN cycle. See PROVIDER-MANUAL §14.15 "Precomputed SwellTrack cache" for the full design, the measured cache-size tradeoff, and why `GET /api/v1/surf/{locationId}/profile` (the beach-profile endpoint) deliberately stays on its on-demand call rather than reading this cache.

### Blended beach profile

The beach profile endpoint (`GET /api/v1/surf/{locationId}/profile`) returns a cross-shore wave height profile. When SurfBeat data is available, the profile blends two sources with a 50m linear taper centered on the break point:

- **Offshore of (break_point + 25m):** 100% SurfBeat strip Hs (approach zone — physically accurate, avoids the 24% SwellTrack overestimate)
- **Between (break_point ± 25m):** Linear ramp from SurfBeat to SwellTrack
- **Shoreward of (break_point - 25m):** 100% SwellTrack Hs (surf zone — detailed breaking physics)

When SurfBeat is unavailable: SwellTrack Hs for the entire profile (no blend). The blend affects only the display profile — face height, scoring, and break points always come from SwellTrack.

### Validation method

Surf model output is validated against competing surf forecasts (Surfline, BSR) — comparison of face heights, breaker types, and timing under varied swell conditions. No webcam validation (no webcam at HB Pier). No SWASH ground truth (SWASH is unvalidated and ruled out entirely).

**Per-spot operator config:**
- `breaker_formula`: `komar_gaughan` (default) or `caldwell`
- `surf_height_display`: `face` (default) or `hawaiian`

Full research at `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md`.

**Additional response fields:**

| Field | Value | Description |
|---|---|---|
| `nearshoreModel` | `"SWAN + SwellTrack"` | Always present when SWAN + SwellTrack is active (ADR-093/096) |
| `lastRunTime` | ISO timestamp | When the SWAN run that produced this data completed |
| `dataAge` | integer (seconds) | Age of the SWAN output |
| `breakerFormula` | `"komar_gaughan"` or `"caldwell"` | Which formula was used for this spot |
| `surfHeightDisplay` | `"face"` or `"hawaiian"` | Operator's configured display preference |
| `directionalSpread` | float (degrees) | DSPR from SWAN TABLE at the cross-shore transect reference point — `select_reference_point()`, not a fixed depth (the "at ~10m depth" this row used to carry is void; ADR-095 Amendment 2). Typically 10–40° for nearshore conditions |
| `setup` | float \| null | Wave-induced setup. Currently `null` — SETUP command removed (unsupported in parallel runs). Future: analytic estimate via WLEVEL injection. |

**Wind source for surf quality scoring (ADR-094, updated ADR-096):**

For SWAN surf forecasts, the wind source is HRRR (the same model run that drove SWAN). Station hardware wind observations remain the source for `t=0` current-conditions scoring when available.

| Timestep | Wind source | `windSource` field value |
|---|---|---|
| `t=0` (current conditions) | Station hardware → forecast provider → HRRR `t=0` | `"station"` or `"forecast_provider"` |
| `t+1h` through `t+48h` (forecast, HRRR range) | HRRR forecast wind at 3km from SWAN cache | `"hrrr"` |
| `t+49h` through `t+72h` (forecast, GFS range) | GFS forecast wind at 0.25° from SWAN cache | `"gfs"` |

The NDBC buoy wind exclusion (HARD RULE) is unchanged — NDBC buoy wind is never used for surf quality scoring regardless of source mode.

#### Wave transform supplements (from ADR-084; REMOVED 2026-07-25, T4A.7)

**File:** `enrichment/wave_transform.py`

All four originally-defined supplements are now gone. `apply_supplements()` no longer exists. What remains in the module is `bilinear_interpolate()` alone, kept for an unrelated live caller — `endpoints/surf.py` uses it to interpolate HRRR wind U/V grid components to a spot's coordinates for surf-quality scoring, not for wave height.

| Supplement | Status |
|---|---|
| 1 — Breaker index correction (γ tuning, Battjes 1974) | **REMOVED 2026-07-25 (T4A.7).** Dead code: its guard required `SurfSpotConfig.bathymetric_profile`, a field the config loader no longer defines, so the branch never executed. Also superseded in principle — the SwellTrack 1D model (`services/surf_1d_pipeline.py`) computes local slope and Iribarren number at every point from the real CUDEM profile, finer than this supplement's single configured `beach_slope` scalar. |
| 2 — Coastal structure transmission/reflection effects | **REMOVED (ADR-095).** Replaced by the SWAN native OBSTACLE command — see the SWAN integration table above. |
| 3 — Sub-grid spatial interpolation (bilinear) | **REMOVED 2026-07-25 (T4A.7), verification-gated.** The gate: confirm whether the SWAN handoff spectrum is emitted at the requested coordinate or at a grid-cell centre. Confirmed against the installed SWAN user manual (§2.6.4 "Output grids", §4.6.1 POINTS/CURVE) and SWAN source (`swanout1.ftn` `SWOEXA`/`SWOEXD`) that SWAN bilinearly interpolates POINTS/SPECOUT output to the exact requested coordinate from the four surrounding computational-grid nodes. The handoff SPECOUT is emitted via `POINTS` at explicit coordinates (`services/swan_formats.py`, `services/swan_runner.py`), so there is no leftover grid-cell value for this supplement to refine. Also confirmed already unreachable at its one historical call site — `grid_data`/`grid_lats`/`grid_lons` were never populated. |
| 4 — Topographic wave focusing/sheltering | **REMOVED (ADR-093 Amendment 2 §5b, 2026-07-25).** The multipliers (point break ×1.1, headland ×1.2, bay break ×0.9, straight beach ×1.0) stood in for refraction that SWAN's nested L2 grid (100 m) now computes physically; applying them on top double-counted. The operator's topographic classification is retained in spot config — its job is now the L3 enable trigger (PROVIDER-MANUAL §14.15), not a wave-height adjustment. |

**What feeds the 1D model now:** the SwellTrack pipeline's boundary condition comes directly from the SWAN handoff SPECOUT — no supplement stage runs between SWAN and the 1D model, and never actually did (the design this section described pre-T4A.7 was never implemented; see `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md` §7).

**What is NOT supplemented:** Shoaling, refraction, bottom friction, wave-current interaction. SWAN computes these with its own bathymetry and input currents.

### Surf quality scorer (ADR-096 restructure)

**File:** `enrichment/surf_scorer.py`
**Registration:** Against the surf endpoint — runs after SwellTrack pipeline (or the legacy CURVE-transect fallback) and breaker height conversion.
**Inputs:** `breakingFaceHeight` (from H1/10 at SwellTrack break point, or legacy K-G fallback), DSPR (from SWAN TABLE), SPECOUT spectral components (deep-water reference from L2 at ~15m), spot config (beach facing, directional exposure, measurement zone segment), wind data (HRRR for forecast timesteps, station hardware for `t=0`), multi-transect aggregation (best peak, spot average from open transects).
**Outputs:** `SurfForecast` with quality_stars (1–5), quality_label, conditions_text, full scoring breakdown, peel angle, wave shape classification.

**All scoring data from SWAN + SwellTrack (ADR-096, amended).** NDBC spectral data is NOT passed to the scorer. The scorer uses multi-transect SwellTrack output for wave height (best peak or average from open transects), deep-water SPECOUT for swell composition, and SWAN TABLE for DSPR. NDBC spectral data is retained in the surf response as reference data but does not feed scoring or multiSwell.

**Scorer uses `breakingFaceHeight`, not raw Hsig.** The scoring thresholds (`_WAVE_HEIGHT_RANGES_FT`) are calibrated in face-height feet. **Scoring recalibration required** — SwellTrack's break-point H1/10 face heights (with friction enabled) will differ from the legacy ~10m K-G values. Thresholds validated via SURF-MODEL-FIX-PLAN Phase 7 T7.6.

**Wind source for surf quality scoring (HARD RULE):**

Wind input for the surf scorer uses HRRR forecast wind for forecast timesteps (`t > 0`) and station hardware or forecast provider for current conditions (`t=0`). See §17 "Wind source for surf quality scoring (ADR-094)" above for the full precedence.

**NDBC buoy wind — NEVER used for surf quality scoring.** Offshore buoys (typically 12+ miles out) measure the synoptic wind field, which can be completely different from beach conditions.

**Three-component weighted scoring (ADR-096):**

| Component | Weight | Max score | Scoring method |
|---|---|---|---|
| Wave Height | 0.35 | 35 | Larger = better within rideable range for the spot. Scaled linearly against the spot's configured ideal range. |
| Wave Period | 0.35 | 35 | Longer = better (cleaner, more powerful waves). Ground swell (≥12s) scores highest. |
| Wave Organization | 0.30 | 30 | Composite sub-score (see below). Higher = cleaner, more organized wave conditions. |

**Wave Organization sub-factors (weights within the 30%):**

| Sub-factor | Weight within Organization | Effective weight | Source | Scoring |
|---|---|---|---|---|
| Wind effect | 50% | 15% | HRRR/station wind | Offshore = best, onshore = worst. Same classification as before. |
| Swell dominance | 25% | 7.5% | SWAN `TABLE PT*` at the **deep-water reference** (L2, the spot's measured ~15 m contour) | Ratio of primary swell energy to total energy, computed over the same watershed partitions as `multiSwell` (T4B.2). Not NDBC. |
| Directional spread | 15% | 4.5% | SWAN `DSPR` at the cross-shore transect reference point | The reference point is the transect point just offshore of the largest break, or — when nothing is breaking — the point nearest 10 m depth (`services/surf_pipeline_timestep.py` `select_reference_point()`). < 15° → 1.0, 15–25° → 0.7, 25–35° → 0.4, > 35° → 0.2 |
| Cross-swell interference | 10% | 3% | SWAN `TABLE PT*` at the **deep-water reference** (same partition list as `multiSwell`) | No cross-swell → 1.0, secondary system > 50% primary energy at > 30° angle diff → 0.4 |

> **Sampling position — corrected 2026-07-27.** The three rows above previously read "at ~10m". That was stale pre-amendment text: ADR-095 Amendment 2 states the ~10 m reference point does not exist in the current architecture, and ADR-096 Amendment 1 places the cross-swell input "at the deep-water reference point (L2 at ~15m)". Swell dominance and cross-swell both operate on the deep-water partition list (`enrichment/surf_scorer.py` `score_surf(multi_swell=...)`, fed from the `spectral_dwr` extraction — marine `83f0205`). Directional spread has never come from a fixed depth; it is read from the selected cross-shore transect point.

Organization sub-score = weighted sum of sub-factors × 30.

**Visible penalty/bonus factors (ADR-096):**

| Factor | Type | Description |
|---|---|---|
| Beach alignment | Penalty (signed integer) | Per-component directional filter — swell from blocked direction scores zero |
| Directional exposure | Penalty (signed integer) | 0 when open, negative when blocked. Previously hidden. |
| Time of day | Bonus/penalty (signed integer) | Positive at dawn, negative in afternoon, 0 otherwise. Previously hidden. |

**Total score:** `total = waveHeight + wavePeriod + waveOrganization + beachAlignment + directionalExposure + timeOfDay`. All factors visible — no hidden modifiers.

**Score bar normalization:** Each bar's fill is proportional to its own maximum, not to 100. Wave Height 28/35 = 80% fill. Wave Organization 24/30 = 80% fill.

Quality labels: 1 = "Poor", 2 = "Fair", 3 = "Good", 4 = "Very Good", 5 = "Epic".

### Fishing scorer

**File:** `enrichment/fishing_scorer.py`
**Registration:** Against the fishing endpoint.
**Inputs:** Pressure trend (from weewx archive or NDBC buoy), tide state (from CO-OPS), water temperature (from ocean data resolver — same tiered fallback as marine/surf endpoints; NDBC/CO-OPS as last-resort fallback only), solunar intensity (from solunar processor), current time.
**Outputs:** `FishingForecast` with overall_score (0–100) and per-component sub-scores.

**Four-component weighted scoring (general conditions):**

| Component | Weight | Scoring method |
|---|---|---|
| Barometric pressure trend | 0.375 | 3-hour pressure delta. Rapid drop (> 3 hPa/3hr) = 100 (peak). Falling (1–3 hPa/3hr) = 80. Stable (< 1 hPa/3hr) = 50. Rising slow (1–3 hPa/3hr) = 30. Rising rapid (> 3 hPa/3hr) = 20 (fish stop feeding during rapid pressure increases). |
| Tide state | 0.3125 | Position in tidal cycle from CO-OPS predictions. Outgoing (ebb) = 100 (flushes bait). Incoming (flood) = 80. Peak flow (midpoint between tidal extremes) = 70. Slack high = 30. Slack low = 20. |
| Solunar intensity | 0.1875 | From solunar processor. During major period + new/full moon = 100. During major period (non-peak moon) = 80. During minor period = 60. Outside any period = 30. |
| Time of day | 0.125 | Dawn = 100, Dusk = 90 (low-light feeding peaks). Morning = 70. Night = 50 (species-dependent). Midday = 30. |

Water temperature is **not** part of the general `overallScore`. Temperature is scored **per species** using each species' own optimal/good/marginal ranges from `SPECIES_PROFILES` — a 72°F day scores high for redfish (optimal 68–80°F) but low for striped bass (optimal 55–68°F). This matches industry practice (Fishbrain, BassForecast) where bite scores are species-specific.

**Final score** = Σ(component_score × weight) × species_modifier × temp_multiplier × seasonal_multiplier, scaled to 0–100 integer.

**Species profiles:** Four target categories (operators can select multiple), each with species auto-populated from 11 US biogeographic regions:

| Category | Example species | Pressure sensitivity | Typical temp range (°F) |
|---|---|---|---|
| Saltwater inshore | Redfish, Speckled Trout, Flounder, Snook | High | 55–85 |
| Bottom fish | Grouper, Snapper, Sheepshead, Tautog | Moderate | Species-specific, varies widely |
| Freshwater sport | Bass, Walleye, Pike, Catfish | High | 55–75 |
| Salmonids | Salmon, Steelhead, Trout | Moderate | 45–65 |

Each species has: optimal temp range (1.0×), good range (0.8×), marginal range (0.5×), inactive below/above (0.1×). Spawning season multipliers (2.0–3.0× during peak runs).

Species data is loaded from `data/species.yaml` (an operator-editable reference file; parsed once at process start by `enrichment/fishing_species.py`), keyed by biogeographic region and target category. No external API.

**Solunar evidence caveat:** Presented as one factor with appropriate context — "Solunar theory suggests feeding activity correlates with moon position. Scientific evidence is mixed; environmental conditions (pressure, temperature, tides) have stronger research support."

### Solunar computation

**File:** `enrichment/solunar.py`
**Registration:** Against the solunar and fishing endpoints.
**Inputs:** Date, location coordinates.
**Outputs:** `SolunarTimes` model.

Computed locally via Skyfield — no external API call. Skyfield is already a project dependency (almanac feature).

**Sunrise/sunset (C-47, 2026-07-25).** `SolunarTimes.sunrise`/`.sunset` are computed for the request's own `lat`/`lon` — not the operator's weewx station — using the same lightweight `almanac.risings_and_settings()` + `find_discrete()` pattern this function already uses for moonrise/moonset, applied to the sun instead of the moon, over the same station-local day window. This exists because no other almanac endpoint returns sunrise/sunset for an arbitrary coordinate: `GET /almanac` and `GET /almanac/sun-times` are station-location-only, and `GET /almanac/solunar` itself previously carried moon events only. The marine service's fishing endpoint needs sun times for the fishing spot's own coordinates (period-window and scoring inputs) and consumes this field rather than falling back to the station's sun times, which would be a real accuracy regression for any spot far from the station. Deliberately not routed through `services/almanac.py`'s `_compute_sun_for_date()` — that function is heavier (civil twilight, solar transit, next-equinox/solstice search up to two years out) and none of that is needed here; duplicating its overhead across up to 30 days per request (`days` query parameter) would cost more than it's worth for two fields already obtainable from the same technique this function uses elsewhere in its own body.

**Major periods:** Centered on moon transit (highest point) and moon underfoot (opposite side). Duration: ± 1.5 hours from event time. Two per day.

**Minor periods:** Centered on moonrise and moonset. Duration: ± 1 hour from event time. Two per day (when moon rises/sets — at high latitudes one or both may be absent).

**Moon phase intensity:**
- New moon = 1.0 (strongest gravitational pull, combined with sun)
- Full moon = 1.0 (strongest gravitational pull, opposed to sun)
- First/last quarter = 0.7
- Waxing/waning crescents and gibbous = 0.5

**Period duration modulation:** New/full moon → wider windows (major: ± 2 hr, minor: ± 1.5 hr). Quarter moon → standard windows.

**Solunar endpoint availability:** `GET /api/v1/almanac/solunar` is NOT gated by the marine feature. Solunar times are useful for hunting, wildlife photography, and general outdoor planning. Available to all operators.

### Marine i18n — locale-resolved fields

**All marine enrichment output that carries human-readable text must resolve through `i18n.t()` (§6).** This is not optional — it is the same requirement that applies to Beaufort labels, AQI categories, moon names, and conditions text. An enrichment processor that returns hardcoded English strings violates `rules/coding.md` §6 and will fail the QA gate.

**Locale key inventory for marine features:**

| Response field | Example English value | Locale key pattern | Resolution |
|---|---|---|---|
| `SurfForecast.qualityLabel` | "Epic" | `surf.quality.<1-5>` | `i18n.t("surf.quality.5")` → "Epic" (en), "Épique" (fr), "エピック" (ja) |
| `SurfForecast.windQuality` | "offshore" | `surf.wind_quality.<value>` | `i18n.t("surf.wind_quality.offshore")` |
| `SurfForecast.conditionsText` | "3-4 ft at 12s from SSW. Offshore winds 5-10 mph." | `surf.conditions.*` composition templates | Flat `i18n.t()` template strings filled in with `str.format()` (T4.4) — not the full component-order/CJK-dispatch architecture of `sse/conditions_text.py` (weatherText); surf/fishing sentences are short enough that per-locale sentence templates suffice. Compass abbreviations (N/NE/E/...) are not locale-resolved — cross-locale marine/aviation notation. |
| `SpectralWaveComponent.classification` | "groundswell" | `marine.swell_class.<value>` | `i18n.t("marine.swell_class.groundswell")` |
| `FishingForecast.periodLabel` | "Early Morning" | `fishing.period.<value>` | `i18n.t("fishing.period.early_morning")` |
| `FishingForecast.conditionsText` | "Falling pressure with incoming tide..." | `fishing.conditions.*` composition templates | Flat `i18n.t()` template strings filled in with `str.format()` (T4.4); see `SurfForecast.conditionsText` row |
| `FishingForecast.speciesScores[].status` | "active" | `fishing.species_status.<value>` | `i18n.t("fishing.species_status.active")` |
| ~~`BeachSafetyAssessment.safetyLevel`~~ | ~~"caution"~~ | ~~`beach_safety.level.<value>`~~ | **Deprecated (T9.1).** `safetyLevel` is always null in v1 — see §16 "BeachSafetyAssessment". The `beach_safety.level.<value>` locale keys may remain in locale files harmlessly unused; no code path resolves them. |
| `BeachSafetyAssessment.comfortLevel` | "cool" | `beach_safety.comfort.<value>` | `i18n.t("beach_safety.comfort.cool")` |
| `SurfZoneForecast.ripCurrentRisk` | "moderate" | `beach_safety.rip_risk.<value>` | `i18n.t("beach_safety.rip_risk.moderate")` |
| `SolunarTimes.moonPhase` | "waxing_crescent" | `moon_phases.<value>` | Already exists in locale files (reuse existing moon phase keys from almanac feature) |
| Habitat feature labels | "Drop-off at 200m offshore" | `fishing.habitat.<feature_type>` | `i18n.t("fishing.habitat.dropoff")` — the distance/depth numbers use `format_number()` |
| Solunar evidence caveat | "Solunar theory suggests..." | `fishing.solunar_caveat` | Single key, full-text per locale |

**What does NOT need i18n in marine responses:**
- Canonical field names (camelCase identifiers in JSON keys)
- NWS-sourced prose passed through verbatim (`MarineTextForecast.text`, `SurfZoneForecast.windText`, `SurfZoneForecast.hazardsText`) — these are English from the NWS; translating them is a provider-level concern (non-US locale providers would supply locale-native text)
- Station IDs, zone IDs, location slugs, coordinates, timestamps
- Numeric values (these are locale-formatted by `format_number()` at serialization, not by the enrichment processor)

**Implementation requirement:** Each enrichment processor's output function must accept a `locale` parameter (defaulting to `i18n.get_active_locale()`). All label lookups use `i18n.t(key, locale=locale)`. All number formatting in composed text uses `i18n.format_number(value, decimals, locale=locale)`. `surf_scorer.py` and `fishing_scorer.py` compose `conditionsText` from flat `surf.conditions.*`/`fishing.conditions.*` template strings (T4.4); this is deliberately lighter than the component-order + connector + custom-CJK-composer architecture in `sse/conditions_text.py` (used for the current-conditions `weatherText` field), which exists to handle a longer, more structurally variable sentence (temperature/sky/wind/precipitation in locale-dependent order). Surf/fishing conditions text is short and fixed-shape enough that per-locale sentence templates are sufficient — read `sse/conditions_text.py` only if a future marine feature needs component reordering or CJK-specific composition.

**Locale file additions:** Each locale file (`locales/{locale}.json`) must gain the following top-level sections:
- `"surf"` — quality labels (5), wind quality labels (5), swell classifications (3), conditions composition templates
- `"fishing"` — period labels (6), species status labels (3), habitat feature labels (5), conditions composition templates, solunar caveat text
- `"beach_safety"` — safety level labels (3), comfort level labels (4), rip current risk labels (3)
- `"marine"` — swell classification labels (3, shared with surf)

English (`en.json`) is the authoritative source. All 12 other locale files must have the same key structure — placeholder English values are acceptable for v1, to be replaced with proper translations before release.

---

## §18 Marine Endpoints

Marine endpoints follow existing patterns: capability gating, unit conversion, freshness block, stationClock. Each of the five activity endpoints (`/marine`, `/tides`, `/surf`, `/fishing`, `/beach-safety`) is actually **two routes**:

- `GET /api/v1/{endpoint}` (no `locationId`) — returns a list: one summary/card entry per configured location that qualifies for that endpoint's capability gate. This is what the dashboard's location-card grid (§12) renders. 404 (`"<Feature> not configured"` / `"No <activity> locations configured"`) when zero locations qualify.
- `GET /api/v1/{endpoint}/{locationId}` — returns the full bundle for one location. 404 when `locationId` does not match a configured, capability-qualifying location.

**There is no "first configured location" fallback.** An earlier draft of this manual said the no-`locationId` route returns data for the first configured location; the implemented behavior is the list above (confirmed against `endpoints/marine.py`, `endpoints/tides.py`, `endpoints/surf.py`, `endpoints/fishing.py`, `endpoints/beach_safety.py` — each has an explicit list-vs-detail route pair).

### Endpoint inventory

| Endpoint | List-route response | Detail-route response | Capability gate |
|---|---|---|---|
| `GET /api/v1/marine[/{locationId}]` | `list[MarineLocationSummary]` | `MarineBundle` | At least one location with `marine` activity enabled |
| `GET /api/v1/tides[/{locationId}]` | `list[MarineLocationSummary]` | `TideBundle` | At least one location with a `coops_station_ids` entry configured. Per ADR-090, all four activities (marine, surf, fishing, beach_safety) use tide data, so "tide-capable" means "has a CO-OPS station configured," not a specific activity value. |
| `GET /api/v1/surf[/{locationId}]` | `list[object]` (`locationId`, `name`, `lat`, `lon`, `qualityStars`, `conditionsText` — metadata only, no live fetch) | Surf bundle, actual shape (§16) | At least one location with `surf` activity enabled |
| `GET /api/v1/fishing[/{locationId}]` | `list[object]` (`locationId`, `name`, `lat`, `lon`) | Fishing bundle, actual shape (§16) | At least one location with `fishing` activity enabled |
| `GET /api/v1/beach-safety[/{locationId}]` | `list[object]` (`locationId`, `name`, `lat`, `lon`, `safetyLevel` — always null, T9.1 — `ripCurrentRisk`, `waterTemp` — live-fetched per card) | Beach-safety bundle, actual shape (§16) | At least one location with `beach_safety` activity enabled |
| `GET /api/v1/almanac/solunar` | — (single route, no location list) | `SolunarTimes` (or `list[SolunarTimes]` when `days` > 1) | Always available (not gated by marine feature) |

### Request parameters

**Location endpoints** (`/marine`, `/tides`, `/surf`, `/fishing`, `/beach-safety`):

| Parameter | Type | Required | Description |
|---|---|---|---|
| `locationId` | str (path) | No | Location slug from config. Omit to get the list-of-locations response (see "Endpoint inventory" above); a 404 is returned if the given `locationId` does not exist or does not qualify for the endpoint's capability gate — there is no fallback to any other location. |

**Solunar endpoint** (`/almanac/solunar`):

| Parameter | Type | Required | Description |
|---|---|---|---|
| `date` | str (query) | No | Date in YYYY-MM-DD. Default: station-local today. |
| `lat` | float (query) | No | Latitude. Default: station latitude. |
| `lon` | float (query) | No | Longitude. Default: station longitude. |
| `days` | int (query) | No | Number of days (1–30). Default: 1. |

### Response shape

All marine endpoints return the standard response envelope (§2): `data`, `stationClock`, `freshness`, `units`, `generatedAt`. The `data` field contains the domain-specific bundle.

### Freshness defaults

| Endpoint | `refreshInterval` (seconds) | Rationale |
|---|---|---|
| `/marine` | 1800 | Matches WaveWatch III cache TTL |
| `/tides` | 600 | Observed water levels update every 6–10 min |
| `/surf` | 1800 | Matches wave forecast cache TTL |
| `/fishing` | 3600 | Scoring inputs change slowly |
| `/beach-safety` | 1800 | Matches wave forecast cache TTL |
| `/almanac/solunar` | 86400 | Celestial mechanics — changes daily |

### Card summary: currentTide removed (ADR-091)

`GET /api/v1/marine` returns `currentTide: null` for all locations. All locations sharing a CO-OPS station show identical tide predictions — this is visual noise on the landing page, not useful differentiation. Tide information surfaces in the activity detail tabs (boating, fishing, beach safety, surfing) via `GET /api/v1/tides/{locationId}` where it provides context for the specific activity.

### Composite water level on tides endpoint (ADR-091)

`GET /api/v1/tides/{locationId}` returns additional fields when composite water level data is available:

| Field | Type | Nullable | Description |
|---|---|---|---|
| `totalWaterLevelForecast` | list[object] | Yes | `[{"time": iso, "height": float, "residual": float}, ...]` — CO-OPS prediction + bias-corrected OFS non-tidal residual |
| `currentResidual` | object | Yes | `{"value": float, "quality": str, "source": str, "description": str}` — measured meteorological effect at current time |
| `residualForecastSource` | str | Yes | `"ofs:WCOFS"`, `"persistence"`, or `"unavailable"` |
| `stormSurgeLevel` | str | Yes | `"elevated"`, `"depressed"`, `"significant"`, `"storm_surge"`, or null (normal) |

All new fields are nullable — when OFS is unavailable or the compositor returns no residual, the response is identical to the current behavior (predictions + observations only). Zero regression.

The `sources` block includes `"waterLevelComposite"` attribution when compositor data is present.

### Capability gating and the activity matrix

Which provider modules and enrichment processors are activated depends on the union of enabled activities across all configured locations. The activity capability matrix (consolidated from ADR-090, amended 2026-07-13 per ADR-091 with ocean data rows) defines which capabilities each activity enables. The API activates only the provider modules required by the union of activities. See PROVIDER-MANUAL §14 for per-provider details.

When no marine locations are configured (no `[marine]` section in `api.conf`), no marine provider modules register, no marine endpoints are available, and the API behaves identically to a non-marine installation.

### Detail endpoint enrichment contract

`GET /api/v1/marine/{locationId}` must return an enriched `MarineBundle` observation using the same data sources as the card summary endpoint (`_location_summary()`). The raw NDBC buoy observation alone is insufficient — most buoys do not report wind, air temp, pressure, visibility, or weather conditions.

**Enrichment sources (applied after the NDBC buoy fetch):**

| Response field | Primary source | Fallback | Notes |
|---|---|---|---|
| `observation.windSpeed` | Station hardware (when `is_station_served()`) | `marine_weather_cache.get_current_conditions()` | Knots in API internal units |
| `observation.windDirection` | Station hardware | `marine_weather_cache` | Degrees |
| `observation.windGust` | Station hardware | `marine_weather_cache` | Knots |
| `observation.airTemp` | Station hardware | `marine_weather_cache` | °C internal |
| `observation.pressure` | Station hardware | `marine_weather_cache` | hPa internal |
| `observation.visibility` | `marine_weather_cache` | null | km internal |
| `observation.waveHeight` | WaveWatch III first forecast point (offshore, deep-water) | NDBC buoy Hs (already-fetched observation) → null | Meters internal. Surf forecasts use SWAN via the dedicated surf endpoint, not this field. Null for harbor locations. |
| `observation.waterTemp` | `ocean_data_resolver.resolve()` (OFS → MUR SST → RTOFS) | NDBC buoy | °C internal |
| `observation.weatherCode` | `marine_weather_cache` | null | WMO code integer |
| `observation.isDay` | `marine_weather_cache` | null | boolean |

**Implementation rule:** Do NOT refactor `_location_summary()` and `get_marine_location()` into a shared function. The two endpoints have different response shapes and different additional data. Copy the enrichment dispatch pattern.

**Unit conversion:** Apply `_convert_observation()` to the enriched observation (same as current behavior, but now with non-null fields).

**Existing fields preserved:** `dominantPeriod`, `averagePeriod`, `spectralComponents` from the NDBC buoy remain in the response when available.

### GRIB2 temporal awareness requirement

GRIB2 files (used by HRRR wind provider and WaveWatch III boundary conditions) contain multiple hourly forecast timesteps. The GRIB reader (`providers/marine/grib_processor.py` in the marine service) MUST select messages by forecast hour using the `endStep` key — it must NOT iterate all messages and let the last one win.

**The `endStep` key** is an integer representing the forecast hour. It is available in both GRIB backends:
- eccodes: `eccodes.codes_get(msgid, "endStep")` → integer
- pygrib: `grb.endStep` → integer

For instantaneous fields (wave height, period, direction, wind), `endStep` equals the forecast hour directly.

**Temporal selection rules:**
- **Current conditions:** Pass `target_step=0` to `read_grib_fields()` to select the analysis/hour-0 timestep.
- **Unfiltered (default):** When `target_step` is `None`, the reader iterates all messages and the last matching field wins (legacy behavior). Not correct for current conditions — always pass `target_step=0` for that use case.
- **Multi-timestep (SWAN):** The SWAN runner reads all timesteps from the HRRR GRIB2 to construct the full wind forcing field for the SWAN simulation.

**Previous bug (fixed):** Both `_read_eccodes()` and `_read_pygrib()` iterated all GRIB messages and overwrote `result.fields[short_name]` for each matching field name. Since GRIB2 messages are typically ordered chronologically, the last overwrite was the furthest forecast hour. The "current conditions" values were showing far-future predictions instead of what was happening at the time.

### Surf endpoint data source rules

**Water temperature:** The surf endpoint (`GET /api/v1/surf/{locationId}`) MUST source water temperature from the ocean data resolver (`services/ocean_data_resolver.py`), which provides modeled/observed water temp via a tiered fallback chain: on-premises sensor → OFS regional model → regional ERDDAP → RTOFS/MUR SST global. This is the same source the marine endpoint uses for `observation.waterTemp`.

The NWS SRF text product's `waterTemp` field (a manually-entered forecaster value parsed from the SRF text, not modeled or observed data) may serve as a last-resort fallback only — not as the primary source. The SRF water temp is a stale, hand-typed value that does not update with ocean conditions.

**Wind:** For forecast timesteps (`t > 0`), the surf endpoint uses HRRR forecast wind from the SWAN cache (ADR-094). For `t=0` current conditions, the existing precedence applies: station hardware → forecast provider. NOT NDBC buoy wind. See §17 "Wind source for surf quality scoring (ADR-094)" for the full rationale and rules.

### Multi-point surf forecast contract

`GET /api/v1/surf/{locationId}` must return multi-point forecast data by scoring each SWAN forecast timestep.

| Field | Type | Description |
|---|---|---|
| `forecast` | `list[SurfForecast]` | One entry per SWAN output timestep across the forecast cycle |
| `forecast[].time` | ISO 8601 | Time of this forecast point |
| `forecast[].qualityStars` | int (1-5) | Star rating from `score_surf()` using `breakingFaceHeight` |
| `forecast[].qualityLabel` | str | "Poor"/"Fair"/"Good"/"Very Good"/"Epic" |
| `forecast[].conditionsText` | str | Composed natural-language summary |
| `forecast[].windQuality` | str | "Offshore"/"Glassy"/"Cross-shore"/"Onshore" |
| `forecast[].windSource` | str | `"hrrr"` or `"gfs"` for forecast timesteps, `"station"` or `"forecast_provider"` for `t=0` (ADR-096) |
| `forecast[].swellHeight` | float | Dominant deep-water-reference partition height in display units (L2, the spot's measured ~15 m contour — marine `83f0205`); falls back to the transect reference point's HSWELL when that timestep has no deep-water reference |
| `forecast[].waveHeightAtBreak` | float | SwellTrack break-point Hs (`breakingFaceHeight ÷ 1.27`) in display units, or `null` (backward-compatible field name) |
| `forecast[].breakingFaceHeight` | float | Trough-to-crest breaking face height in display units |
| `forecast[].breakingHawaiianHeight` | float | Back-of-wave height (×0.5 of face height) in display units |
| `forecast[].period` | float | Dominant period in seconds |
| `forecast[].direction` | float | Swell direction in degrees |
| `forecast[].multiSwell` | list[object] \| null | Swell partitions at the deep-water reference per timestep (not NDBC — ADR-095/096); `null` when no deep-water reference exists for that timestep |
| `forecast[].directionalSpread` | float | DSPR at the cross-shore transect reference point, in degrees (ADR-095; not a fixed ~10 m depth) |
| `forecast[].setup` | float \| null | Wave-induced setup. Currently always `null` — SWAN SETUP command removed. Field retained for API contract stability. |
| `forecast[].breakPoints` | list[object] \| null | QB peak locations — break points along the transect (T3.4) |
| `forecast[].scoring` | object | 3-factor + 3-penalty scoring breakdown (ADR-096) |
| `forecast[].modelStatus` | str | `"ok"`, `"no_breaking"`, `"degraded_bulk"`, or `"unavailable"` (`_determine_model_status()`). Replaces the old boolean `degraded` field. `"unavailable"` means this timestep's 1D pipeline result could not be produced — in remote SWAN mode (`[swan] service_url` set) this happens when the `swelltrack` cache entry for that timestep is missing or malformed, and the endpoint does NOT recompute locally: it logs, reports the gap via `POST /report/gap` on the model host, and reports `"unavailable"` (SURF-PUBLISH-RESULTS-ONLY §3.5). In bundled single-host mode (`[swan] service_url` unset, SWAN in-process), the same statuses come from the on-demand 1D pipeline call, unchanged. |
| `nearshoreModel` | str | `"SWAN + SwellTrack"` (ADR-093/096) |
| `lastRunTime` | ISO 8601 | When the SWAN run completed |
| `dataAge` | int | Age of SWAN output in seconds |
| `breakerFormula` | str | `"komar_gaughan"` or `"caldwell"` |
| `surfHeightDisplay` | str | `"face"` or `"hawaiian"` — operator's configured display preference |

**`scoring` fields (ADR-096):** `waveHeight` (out of 35), `wavePeriod` (out of 35), `waveOrganization` (out of 30), `organizationWind`, `organizationSwellDominance`, `organizationDirectionalSpread`, `organizationCrossSwell` (sub-factors), `beachAlignment` (signed penalty), `directionalExposure` (signed penalty), `timeOfDay` (signed bonus/penalty).

SWAN always produces multi-timestep output. The dashboard's 72-hour forecast chart shows `breakingFaceHeight` (or `breakingHawaiianHeight` per operator config) — not `swellHeight` or `waveHeightAtBreak`.

### Beach profile endpoint (ADR-097, corrected 2026-07-25)

**This subsection was rewritten, not incrementally patched.** The previous text (a flat `transect`/`breakPoints` shape, "distance and depth are always in meters") described a response the endpoint has never returned in its current form — confirmed stale against `endpoints/beach_profile.py` independently of the SURF-PUBLISH-RESULTS-ONLY changes below. Specifically wrong: (1) the actual response nests everything under the standard envelope (`data`/`stationClock`/`freshness`/`units`/`generatedAt`, §2) and `data` itself, which the old text never mentioned; (2) the real per-transect fields are `transectIndex`/`isStructureAffected`/`transectBearingDeg`/`transect`(an Hs envelope, not the six-field point list documented)/`breakPoints`(different shape)/`waveShapes`/`surfZones`/`jackingFactors`/`handoffDepthM`/`handoffSourceLevel` — none of which the old table listed; (3) the `transect_index` query parameter (`best`/`all`/integer) was undocumented entirely, including the `all`-mode `profiles` array; (4) distance and depth are NOT always meters — they follow the operator's configured display unit (`_distance_unit()`: foot for a `US` operator, meter otherwise), exactly like `waveHeight`.

`GET /api/v1/surf/{location_id}/profile` returns the 1D (SwellTrack) pipeline's cross-shore output for the forecast timestep closest to now.

**Query parameter:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `transect_index` | str (query) | `"best"` | `"best"` (open transect with the highest face height), `"all"` (array of every transect's profile), or a non-negative integer transect index. HTTP 422 on an unparseable or negative value. |

**Response — `data` object, all modes:**

| Field | Type | Description |
|---|---|---|
| `locationId` | str | Location slug |
| `timestep` | str \| null | ISO-8601 forecast time this profile is for (the timestep closest to now); null when no forecast timestep exists at all |
| `modelStatus` | str | `"ok"` or `"unavailable"` (SURF-PUBLISH-RESULTS-ONLY §3.6) |
| `perPartitionBreaks` | list[object] \| null | Per-partition break overlay, serialized from the pipeline's `per_partition_breaks`; null when `modelStatus` is `"unavailable"`. `partitionIndex` is a **canonical** (deep-water-reference) index, plus `-1` for the aggregated "other" bucket — see "Two partition index spaces" below. |
| `metadata` | object | See below |

**Two partition index spaces (marine `35af390`).** This endpoint's response mixes values derived from both SWAN spectral extractions, and they are indexed differently:

- **Canonical** — the deep-water reference (L2, the spot's measured ~15 m contour) partition list. `perPartitionBreaks[].partitionIndex` and `breakPoints[].partitionInfo.partitionIndex` are values in this space, plus `-1` for the aggregated "other" bucket that handoff partitions matching no canonical partition fall into.
- **Handoff** — the SwellTrack boundary-condition partition list. The pipeline's internal per-transect results are ordered by it.

The two coincided until marine `83f0205` gave the two extractions separate channels and `bd8c928` moved the deep-water point onto the 15 m contour; the lists now differ in length, ordering and content, and the endpoint converts between the spaces at each lookup rather than treating an index from one as valid in the other. Where the pipeline ran with **no** canonical list (no deep-water reference for the timestep) or reported `degraded`, `partitionIndex` falls back to handoff ordering and the two spaces coincide again — that degrade is logged at WARNING and is never repaired by substituting the handoff partitions for the deep-water ones.

A handoff partition that matches no canonical partition still has its break points published — attributed to the `-1` "other" bucket, or, when no "other" bucket exists (the partition broke only on structure-affected transects, which are excluded from aggregation), published with `partitionInfo: null` and a WARNING naming the transect and handoff index. Break points are never dropped and never attributed to partition 0. Response field names, types and nullability are unchanged by this.

**`transect_index=all`:** `data.profiles` is a `list[object]` — one entry per transect, each shaped as the single-transect fields below — or `null` when `modelStatus` is `"unavailable"`.

**`transect_index="best"` or an integer:** the single-transect fields are merged directly into `data` (not nested under a `profiles` key), or all null when `modelStatus` is `"unavailable"`:

| Field | Type | Description |
|---|---|---|
| `transectIndex` | int \| null | Zero-based transect index |
| `isStructureAffected` | bool \| null | True when this transect crosses a discovered OBSTACLE |
| `transectBearingDeg` | float \| null | Transect bearing in degrees |
| `transect` | list[object] \| null | RSS-combined Hs envelope from handoff to shore (per-partition combination, depth-limited saturation applied) |
| `breakPoints` | list[object] \| null | H/d = gamma crossings with Iribarren number, breaker type, and face height. Each carries `partitionInfo` (`partitionIndex`/`periodS`/`directionDeg`/`classification`/`heightM`), nullable — see "Two partition index spaces" above. |
| `waveShapes` | list[object] \| null | Stokes 2nd order / cnoidal / bore surface shape samples from `run_1d_analytical()`, computed on the dominant swell partition |
| `surfZones` | object \| null | Impact / foam / total / reform-trough zone widths |
| `jackingFactors` | list[object] \| null | Per-bar `barIndex`/`distance`/`factor` (Hs at bar crest ÷ Hs approach) |
| `handoffDepthM` | float \| null | This transect's per-hour handoff depth (T4A.9 per-hour selection, not the setup-time placeholder) |
| `handoffSourceLevel` | str \| null | `"L4"`, `"L3"`, or `"L2"` — which grid level the handoff spectrum came from (E5 ruling D3, 2026-07-27: first match wins — L4 if the transect's cross-shore line enters the structure grid's footprint, else L3 if a classified refraction feature covers it, else L2 at the fixed 15 m reference depth) |

**`metadata` object (present in both modes, fields null when `modelStatus` is `"unavailable"`):**

| Field | Type | Description |
|---|---|---|
| `axisUnits` | object | `{"x": <distance symbol>, "y": <distance symbol>}` |
| `verticalDatum` | str \| null | Read from the per-spot profile cache. **Known, independently-tracked defect, not addressed by SURF-PUBLISH-RESULTS-ONLY:** this is currently always null, including on `modelStatus: "ok"` responses — the value does not yet reach the API. Do not read a null here as evidence the model has no answer. |
| `transectCount` | int \| null | Total transects computed for this spot |
| `openTransectCount` | int \| null | Transects not excluded as structure-affected |
| `handoffDepthM` | float \| null | Representative handoff depth (the "best" transect's) |
| `handoffSourceLevel` | str \| null | Representative handoff source level — `"L4"`, `"L3"`, or `"L2"` (E5 ruling D3) |

**`units` object:** `distance` and `depth` use the operator's configured distance display unit (foot or meter — same resolution path as `group_wave_height`'s unit group); `hs` uses the wave-height display unit. Unit conversion is applied to all wave-height and distance/depth fields; nothing in this response is a fixed physical unit.

**HTTP 404 — configuration error, unchanged behavior:**
- Location does not exist or does not have `surf` enabled.
- No surf-spot configuration is present for the location.
- No transects available (spot not configured, or the shoreline segment has zero length).
- `transect_index` is an integer with no matching transect in the computed set.

**HTTP 200 with `modelStatus: "unavailable"` and a null payload (SURF-PUBLISH-RESULTS-ONLY §3.6) — model gap, NOT a configuration error:**
- No SWAN data has been cached for the location yet.
- No forecast timesteps are available.
- The 1D pipeline produced no usable output for the requested timestep (degraded, no bathymetric profile loaded yet, or — in remote mode — the model host has no answer for that hour).

A missing profile used to raise HTTP 404 for all of the above, which read as "wrong URL" when the truth was "the model has no answer for this hour." The 200/null response keeps the exact key set a success response for the requested `transect_index` mode would have used (nulled), so a client branches on `modelStatus` alone, never on which keys are present.

**Remote vs. bundled mode (SURF-PUBLISH-RESULTS-ONLY §3.2/§3.5) — the topology condition that changes what this endpoint does at the model-gap boundary:**

- **Remote mode** (`[swan] service_url` set — a separate model host exists, e.g. `librewxr`): this endpoint calls that host's own `GET /surf/{spot_id}/profile?time=<timestep>` (PROVIDER-MANUAL §14.15) instead of running the 1D pipeline here. The model host runs the pipeline against its own full internal spectral data (never the trimmed published forecast view) and returns SI units; **this host performs zero unit conversion input processing beyond what it already does for the response** — it converts and shapes the model host's result, it does not build `specout_data`/`handoff_by_transect` or POST them anywhere. A `None` result (no cached data, 503 from the model host, network error, or a malformed body) becomes the 200/null response above, and a `POST /report/gap` is sent to the model host.
- **Bundled mode** (`[swan] service_url` unset — no separate model host): the existing in-process 1D pipeline / optional `surf_compute_host` offload cascade runs exactly as before this brief — **this IS the model in this topology, not a fallback**, and this case is unaffected by the remote-mode changes above. It can still yield the same 200/null response on a genuine local pipeline failure (degraded, no bathymetric profile).

---

## §19 Marine Service Companion Pattern (target — pending ADR-099 acceptance)

This section documents the target-state architecture for the marine service (`weewx-clearskies-marine`). The patterns described here take effect when the marine service is extracted from the API into a standalone companion service per ADR-099. The current state (SWAN runner, SwellTrack, all marine providers embedded in the API) continues to apply until ADR-099 is accepted and the migration executed.

**Current state:** All marine logic — SWAN runner, SwellTrack, SurfBeat, and all provider modules listed in PROVIDER-MANUAL §14 — runs inside the API process. Marine endpoints (`/surf`, `/marine`, `/tides`, `/fishing`, `/beach-safety`) are hardcoded routes in `endpoints/`.

**Target state:** Marine logic moves to a standalone FastAPI service (`weewx-clearskies-marine`) on port 8780. The API communicates with it over HTTP (authenticated, TLS). Marine endpoints are dynamically mounted from the service's manifest. Zero API code changes are needed to add or modify a marine endpoint after the separation.

**Implementation status (Phase 6 re-merge round, 2026-07-25):** `services/companion_proxy.py` is implemented — manifest fetch at startup, dynamic route mounting under `/api/v1/`, 5-minute manifest refresh (same clock as the startup-unreachable retry), and the three-state rule below. The API's hardcoded marine routers described in "Current state" above are still mounted (T6.5–T6.8 delete them later in Phase 6); until then, an operator who configures `marine_service_url` has both a native route and a companion-proxy route registered for the same overlapping paths, and FastAPI resolves to whichever was registered first (the native router — it is registered before `register_companion_proxy()` runs). §19.3 (response envelope wrapping + unit conversion, T6.2) and §19.8 (post-conversion enrichment, the re-merge round) are both implemented. One item remains open — surf t=0 station wind restoration — see §19.8.

**The three-state rule (proxy failure vs. model gap vs. missing resource).** These three situations must stay distinguishable end to end — collapsing any two of them reintroduces the ambiguity SURF-PUBLISH-RESULTS-ONLY (§18 above) removed:

| Situation | Response |
|---|---|
| Marine service unreachable (network failure, non-JSON body, or any HTTP status other than 200/404) and no cached response exists for the route | The proxy's own **503**, with a `detail` naming the unreachable route. Never dressed up as a `modelStatus` value. |
| Marine service answers HTTP 200, including a null payload with `modelStatus: "unavailable"` | Passed through **untouched** as 200 — a successful proxied response, cached like any other 200. There is no `modelStatus`-specific branch in the proxy; it does not inspect the body to decide how to respond. |
| Unknown location / bad parameter | The marine service's own **404**, passed through untouched, never cached. |

If the marine service is reachable but returns something other than 200/404 (5xx, or 401/403 from a misconfigured `MARINE_SERVICE_SECRET`), the proxy treats it the same as "unreachable": serve the last cached response if one exists, else its own 503.

**Gap reporting client (C-10).** `POST {marine_service_url}/report/gap` is intentionally **not** in the manifest — it is a fire-and-forget POST with no cacheable resource and no TTL, so the manifest schema (path/method/upstream/cache_ttl) has nothing to describe for it. `services/companion_proxy.py`'s `report_gap()` calls it directly, with the same bounded dedup/queue/single-worker semantics as the legacy `providers/nearshore/swan.py` client it succeeds. `swan.py` itself is unaffected; T6.6 removes it later in Phase 6 and its call sites move to `companion_proxy.report_gap()` at that point — nothing calls the new function yet.

### §19.1 Manifest registration

The marine service exposes `GET /manifest` (no auth required). The API fetches this manifest at startup, refreshes it periodically (every 5 minutes), and re-fetches on each `/setup/apply` call. Declared routes are mounted dynamically under `/api/v1/`. Endpoint additions in the marine service take effect within 5 minutes without an API restart; endpoint removals de-register the route on the next refresh.

**Manifest response shape:**

```json
{
  "version": "1.0.0",
  "endpoints": [
    {
      "path": "/surf/{location_id}",
      "method": "GET",
      "upstream": "/surf/{location_id}",
      "cache_ttl": 1800,
      "capability": "surf",
      "description": "Surf forecast and scoring for a configured marine location"
    },
    {
      "path": "/surf/{location_id}/profile",
      "method": "GET",
      "upstream": "/surf/{location_id}/profile",
      "cache_ttl": 1800,
      "capability": "surf",
      "description": "Cross-shore transect for the current forecast timestep"
    },
    {
      "path": "/marine/{location_id}",
      "method": "GET",
      "upstream": "/marine/{location_id}",
      "cache_ttl": 300,
      "capability": "marine",
      "description": "Marine observation bundle for a configured location"
    },
    {
      "path": "/tides/{location_id}",
      "method": "GET",
      "upstream": "/tides/{location_id}",
      "cache_ttl": 3600,
      "capability": "tides",
      "description": "Tide prediction and composite water level bundle"
    },
    {
      "path": "/fishing/{location_id}",
      "method": "GET",
      "upstream": "/fishing/{location_id}",
      "cache_ttl": 1800,
      "capability": "fishing",
      "description": "Fishing score and species scoring for a configured location"
    },
    {
      "path": "/beach-safety/{location_id}",
      "method": "GET",
      "upstream": "/beach-safety/{location_id}",
      "cache_ttl": 900,
      "capability": "beach_safety",
      "description": "Beach safety bundle (rip current risk, surf height, UV, water temp)"
    }
  ],
  "capabilities": ["surf", "marine", "tides", "fishing", "beach_safety"]
}
```

`capabilities` is a flat list of capability id strings (matching the marine service's own `endpoints/manifest.py` `compute_capabilities()` and the plan's example manifest) — not a list of `{id, displayName, requiresConfig}` objects. An earlier draft of this section showed the richer object shape; that was never implemented on either side and is corrected here (C-35, MARINE-SEP-CONCERNS.md).

**Dynamic route mounting:** At startup, the API fetches the manifest and registers one proxy handler per declared endpoint. Each proxy handler:

1. Forwards the incoming request (including path parameters and query string) to the marine service at `marine_service_url + path`.
2. Attaches `Authorization: Bearer {MARINE_SERVICE_SECRET}` to the outbound request.
3. Receives raw SI-unit data from the marine service.
4. Wraps the response in the standard API envelope (see §19.3).
5. Returns the wrapped response to the dashboard.

Adding a new marine endpoint requires a manifest update in the marine service only — zero API code changes.

**When marine service is not configured** (`marine_service_url` absent from `api.conf`): no manifest is fetched, no marine routes are mounted, and the API behaves identically to a non-marine installation. The marine endpoint inventory in §18 remains accurate for the current embedded state.

**List routes are also in the manifest.** The example above shows the six `{location_id}`-scoped detail/profile routes; the marine service's actual manifest carries eleven entries — one additional list route per family with no `location_id` (`/surf`, `/marine`, `/tides`, `/fishing`, `/beach-safety`), each returning the configured locations for that activity as metadata (no live provider fetch), cached at the same TTL as its family's detail route. These back the dashboard's marine location-card grids. Omitted from the example JSON above for brevity, not omitted from the manifest itself.

**The three-state rule.** A proxy handler's response falls into exactly one of three states, and they must never be conflated:

| State | HTTP status | Meaning | Cached? |
|---|---|---|---|
| Marine service unreachable (network failure, non-JSON body, or any HTTP status other than 200/404 — including 5xx and an auth failure from a misconfigured secret) and no prior successful response is cached for this route | **503** (the proxy's own) | The system is broken | No — this is the failure state itself |
| Marine service answers HTTP 200 (including a null payload carrying `modelStatus: "unavailable"`) | **200**, passed through untouched | The system works; the model has no answer for this hour | Yes |
| Unknown `location_id` or bad parameter | **404**, passed through untouched | You asked for something that does not exist | No |

A 200 carrying `modelStatus: "unavailable"` is a successful proxied response — it is never rewritten to 503, never treated as a cache miss, and is cached like any other 200. The proxy's own 503 is likewise never dressed up as a `modelStatus` value. When the marine service is reachable but returns something other than 200 or 404 (5xx, a stale/expired secret, etc.), the proxy falls back to the last successfully-cached response for that route if one exists, and only returns 503 when no such fallback exists — "stale preferred to no data," the same principle applied elsewhere in this manual to provider outages.

### §19.2 Configuration key

Two keys in the `[providers]` section of `api.conf` replace both the legacy `surf_compute_host`/`surf_compute_verify_tls` keys (removed T6.8) and the `[swan] service_url` key (removed T7.2):

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `marine_service_url` | str or null | `null` | Base URL of the marine service. Same-host example: `https://localhost:8780`. Separate-host example: `https://192.0.2.10:8780` or `https://[2001:db8::1]:8780`. When null, no marine service is connected and no marine endpoints are mounted. |
| `marine_verify_tls` | bool | `true` | Verify TLS certificate on marine service requests. Set `false` for a self-signed cert on the same VLAN (TLS encryption stays active either way). |

**IPv6 note:** When using an IPv6 address directly (without a hostname), enclose it in square brackets: `https://[2001:db8::1]:8780`. Both IPv4 and IPv6 addresses are valid values.

**Wizard-writable (T7.2, 2026-07-25).** Both keys, plus `MARINE_SERVICE_SECRET`, are set via `POST /setup/apply`'s top-level `marine_service_url` / `marine_verify_tls` / `marine_service_secret` fields — the same top-level position the legacy `surf_compute_host` used to occupy on `ApplyRequest`. `marine_service_url`/`marine_verify_tls` are written to `api.conf [providers]`; `marine_service_secret` is written to `secrets.env` as `MARINE_SERVICE_SECRET` and never to `api.conf`. `GET /setup/current-config` returns all three back (secret unmasked, matching the `openaq_api_key` convention — this endpoint already requires proxy auth) so a wizard re-run pre-fills the connection.

**A blank URL is never sent as an empty string (C-64, 2026-07-26).** `marine_service_url` is `str | None` and Pydantic accepts `""` as a valid `str`, so an empty submission would pass validation and be written to `api.conf` verbatim as a URL that can never resolve — with no 422 and no visible failure. Both config-UI surfaces therefore omit the key entirely (and `marine_verify_tls` with it, since the API writes the pair together) whenever the URL box is empty; omitting it is the API's "leave the existing value alone" signal. **Consequence, by design:** clearing the box does not clear a URL already on disk. Removing a configured marine service is a manual `api.conf` edit; there is no "disconnect" affordance in the UI.

**Config-UI guards on the blank URL.** The wizard blocks the providers step when marine features are enabled with no URL (C-57, keyed off wizard session state). The admin has no session state, so it keys off persisted state instead: "marine is enabled" on the admin surface means **the saved config holds at least one marine location** (C-64). The Marine Service section refuses to save a blank URL while any marine location exists, and the Marine Locations section refuses to add a new location while `marine_service_url` is unset. Editing an existing location is not blocked, so a pre-existing config in that state stays repairable. Both are UI-side guards only — `ApplyRequest` has no apply-time backstop for either, deliberately (C-57).

`MARINE_SERVICE_SECRET` goes in `secrets.env` (not in `api.conf`). See OPERATIONS-MANUAL §4 for the deployment procedure.

### §19.3 Response envelope wrapping

The marine service returns raw SI-unit data. The API wraps every marine response in the standard envelope before returning it to the dashboard.

**Marine service response (raw):**

```json
{
  "locationId": "rincon",
  "waveHeight": 1.4,
  "wavePeriod": 12.0,
  "waveDirection": 280
}
```

**API response (wrapped):**

```json
{
  "data": {
    "locationId": "rincon",
    "waveHeight": 4.6,
    "wavePeriod": 12.0,
    "waveDirection": 280
  },
  "stationClock": {"localTime": "...", "utcOffset": "..."},
  "freshness": {"dataAge": 1240, "refreshInterval": 1800, "isStale": false},
  "units": {"waveHeight": "ft", "wavePeriod": "s"}
}
```

Raw scalar values in `data`, with a flat `{fieldName: label}` map in `units` — this is `units/response_conversion.py`'s "Shape 2" envelope (`{data: dict, units: label_dict, ...}`, the same one `/current` and `/archive` already emit), not a per-field `{value, label, formatted}` wrapper. An earlier draft of this example showed the wrapped form; it was never implemented anywhere in this codebase and is corrected here (C-36, MARINE-SEP-CONCERNS.md). `waveDirection` carries no entry in `units` because direction fields are unconverted (compass degrees, a single universal unit — see the field inventory in `services/marine_response_conversion.py`).

Unit conversion from SI to the operator's configured unit system is applied by the API proxy handler — the marine service always returns SI units and the API always converts.

### §19.4 Capability merging

Marine capabilities declared in the manifest (`/manifest` → `capabilities` array) are merged into `GET /api/v1/capabilities` when the marine service is connected. When the marine service is absent or unreachable, the marine capability entries are omitted from the capabilities response. All other (non-marine) capabilities are unaffected by marine service connectivity.

The capabilities merge is live — the manifest is re-fetched every 5 minutes and on each `/setup/apply` call. If the marine service becomes unreachable, the next manifest fetch will detect the absence and remove marine capabilities from the response — capabilities are removed, not served stale, on a failed refresh; this differs deliberately from proxied routes, which keep serving their last-cached response on the same failure (§19.1's three-state table) because a route with no fresher data is still useful, but a capability list is a live "is this connected" signal.

Each capability id is represented in `CapabilityRegistry.providers` as its own `CapabilityDeclaration` (`providerId: "marine:{id}"`, `domain: "marine"`, `geographicCoverage: "us_coastal"`, `suppliedCanonicalFields: []`) — the existing capability model, not a new response field.

### §19.5 Config push model

Marine service configuration is never read directly from `api.conf`. It is pushed from the API.

**Flow:**

1. Operator saves marine location settings in the wizard or admin UI.
2. Wizard/admin sends `POST /setup/apply` to the API.
3. The API writes the validated config to `api.conf [marine]` and then POSTs the marine-relevant config subset to `POST {marine_service_url}/config` with `Authorization: Bearer {MARINE_SERVICE_SECRET}`.
4. The marine service receives the config, validates it, persists it to local disk, and begins using it for the next run cycle.
5. The API returns success to the wizard/admin whether or not the push succeeded (see failure handling below) — `/setup/apply`'s own success reflects api.conf having been written, not the marine service's reachability.

**Config push failure handling (T6.4):** The push is attempted once, synchronously, at the end of `/setup/apply`, after `api.conf` and `secrets.env` have both been written and any newly-supplied secrets mirrored into the process's own environment (T7.6 — this ordering matters: a `MARINE_SERVICE_SECRET` supplied for the first time in the *same* apply call, via the `marine_service_secret` field, must already be readable before the push fires, or every operator's first-ever apply would report "secret not set"). If `marine_service_url` is not configured, nothing is attempted. If the marine service is unreachable, returns a non-2xx status, or `MARINE_SERVICE_SECRET` is not set in the API's own environment, the failure is logged at **ERROR** and `/setup/apply` still returns success — a marine service outage never blocks the rest of setup. The marine service picks the config up on the next `/setup/apply` call, or recovers it itself on restart via the pull described below (T6.4b).

**Push result surfaced to the caller (T7.6, 2026-07-25).** `ApplyResponse` carries `marine_config_push: {attempted: bool, ok: bool, error: str|null}` — `attempted` is `false` (with `ok`/`error` not meaningful) when `marine_service_url` isn't configured; otherwise `ok` reflects whether the marine service accepted the push, and `error` is a human-readable reason when it did not. This does not change the failure-handling behavior above — the push still never fails `/setup/apply` — it only gives the wizard/admin UI something to render instead of the outcome living solely in the API's own ERROR log.

**Config recovery pull (T6.4b):** `GET /setup/marine/config`, authenticated with `Authorization: Bearer {MARINE_SERVICE_SECRET}`, returns exactly the payload the push above sends — both are built by one serializer (`_build_marine_service_config_payload()` in `endpoints/setup.py`) so the push and pull shapes cannot drift apart. The marine service calls this only at startup, and only when it has no local config on disk (an existing local config always wins — the pull never overwrites it). See OPERATIONS-MANUAL.md "Config push model" for the marine-side trigger conditions (`CLEARSKIES_MARINE_API_URL`) and failure/degradation behaviour.

The marine service never parses `api.conf` directly. This ensures the API remains the single source of truth for all operator-facing configuration.

**Payload shape.** Every field below has a live consumer in the marine service's `config/marine_config.py` loader (`load_marine_config()` / `load_swan_config()`), verified by reading that file directly — no field is sent without a reader, and no field the loader reads is omitted.

```json
{
  "marine": {
    "locations": {
      "<location_id>": {
        "name": "Wrightsville Beach",
        "lat": 34.2085,
        "lon": -77.7964,
        "activities": ["surf", "beach_safety", "fishing"],
        "ndbc_station_ids": ["41110", "41037"],
        "coops_station_ids": ["8658163"],
        "nws_marine_zone_id": "AMZ250",
        "nws_srf_zone_id": "CAZ552",
        "nws_srf_wfo": "sgx",
        "ofs_model": "cbofs",
        "ofs_fallback": "ngofs2",
        "surf": {
          "segment_start_lat": 34.0262, "segment_start_lon": -118.0010,
          "segment_end_lat": 34.0265, "segment_end_lon": -118.0040,
          "transect_spacing_m": 10.0,
          "bottom_type": "sand",
          "beach_slope": 0.02,
          "topographic_feature": "straight_beach",
          "directional_exposure": {
            "N": false, "NE": false, "E": true, "SE": true,
            "S": true, "SW": true, "W": false, "NW": false
          },
          "breaker_formula": "komar_gaughan",
          "surf_height_display": "face",
          "l3_enabled": "auto",
          "friction_coefficient": 0.038,
          "surfbeat_enabled": true,
          "surfbeat_cadence_hours": 3,
          "max_hs_m": 4.0,
          "bathymetric_profile": {"0": {"distance_m": 0.0, "depth_m": 0.0}},
          "structures": {
            "0": {
              "type": "jetty", "material": "impermeable",
              "length_m": 120.0, "bearing_degrees": 45.0, "distance_m": 300.0,
              "bearing_to_spot_degrees": 90.0,
              "coordinates": [[-77.7964, 34.2085], [-77.7960, 34.2090]]
            }
          }
        },
        "fishing": {
          "target_categories": ["saltwater_inshore", "bottom_fish"],
          "biogeographic_region": "carolinian",
          "species": ["red_drum", "spotted_seatrout"]
        },
        "beach_safety": {
          "external_links": {
            "water_quality": {"label": "NC Beach Water Quality", "url": "https://ncdeq.gov/beach-water-quality"}
          }
        }
      }
    }
  },
  "swan": {
    "omp_num_threads": 0,
    "outer_grid_resolution_km": 3.0,
    "inner_nest_resolution_m": 200
  },
  "station": {
    "lat": 34.2075,
    "lon": -77.7980
  }
}
```

Notes:

- **`directional_exposure` wire shape is pinned to the JSON-native dict** (`{"N": false, ...}`) — never the list-of-`"DIR:bool"`-strings form `configobj` uses internally for api.conf's own on-disk storage (MARINE-SEP-CONCERNS.md C-23). The API's serializer converts api.conf's on-disk list form to this dict on the way out; the marine service's parser accepts the dict form only — the list-tolerance branch it carried before this was pinned has been deleted (no caller, per rules/coding.md §3).
- Every top-level key (`marine`, `swan`, `station`) is present only when the corresponding data exists — an installation with no marine locations and no `[swan]` config sends `{}`; `station` is attached only alongside `marine` (it exists to serve marine locations) and only when the API's station metadata is loaded at the time the payload is built.
- `[[weather]]` (marine forecast/observation TTLs) is never sent — the API never writes it to api.conf, and the marine service's `MarineWeatherConfig` defaults apply.
- `swan` is included because the marine service's ported config loader still reads it today; ADR-099's plan to fold it into `marine_service_url` alone is a later phase, not this one. **`providers.surf_compute_host` / `surf_compute_verify_tls` are removed as of T6.8 (2026-07-25)** — the API no longer has these config fields to send (superseded entirely by `marine_service_url`); a payload example showing them was stale as of this edit and is corrected here. **`swan.service_url` is removed as of T7.2 (2026-07-25)** — `marine_service_url` (top-level `[providers]`, §19.2) is the single connection key now; the marine service doesn't need its own hostname told back to it inside the config it receives. Verified safe: `config/marine_config.py`'s `SwanConfig.service_url` defaults to the bundled-mode sentinel when the key is absent from the payload, and `is_remote` has no consumer anywhere in the marine service beyond its own `validate()`.
- **`station.lat` / `station.lon` (C-51, DECIDED 2026-07-25):** the weewx station's own coordinates, sourced from `services/station.py`'s `get_station_info()`. Added so the marine service's `is_station_served()` spatial test (C-47's t=0 station-wind fetch, `endpoints/surf.py`) has something to compare a marine location's distance against — before this, `resolve_station_distances()` was never called and every location was unconditionally treated as not station-served. **Absence is a normal state, not an error.** If station metadata isn't loaded when the payload is built, `station` is simply omitted — never defaulted to `0,0` or any other placeholder. The marine side (`config/marine_config.py`) treats a missing `station` key exactly like every location being outside `dedup_radius_km`: `is_station_served()` returns `False` for every location and every location takes the forecast-provider wind path, same behavior as before C-51.
- **Station timezone and elevation are deliberately excluded.** The marine service's fishing endpoint has no consumer for either field — sunrise/sunset moved to the API's `GET /almanac/solunar` (C-47, DECIDED 2026-07-25), which resolves them for whatever lat/lon it's given, dissolving the station-timezone question C-27 raised. Elevation remains unattached — no marine-service consumer as of this writing.
- **`structures[].coordinates` (E13, ADR-095 Decision 3):** the structure's real outline from the wizard's Overpass API discovery, `[[lon, lat], ...]` — the marine `StructureConfig.coordinates` contract. Optional on `POST /setup/apply`'s `MarineStructureApplyConfig`; absent when no discovery geometry was captured (e.g. a hand-entered structure with only the five scalar fields). On `api.conf`, `[[[structures]]][[[[N]]]]` stores it as one JSON-encoded string value (`configobj` cannot round-trip a native nested list into a shape a plain `float()` reader can parse — it comes back as a flat list of per-element strings); `_serialize_marine_locations_section()` decodes it back to `[[lon, lat], ...]` for the push/pull payload. The API stores and forwards whatever order arrives — it does not convert `[lat, lon]` (OSM's order) to `[lon, lat]`; that conversion happens once, at the wizard.

### §19.6 Marine alerts remain in the API

**Marine alerts (coastal flood, high surf, rip current, marine zone alerts) are NOT part of the marine service. They remain in the unified API alert system regardless of whether the marine service is installed.**

The alert system in the API (§8, ADR-089) handles all alert types through a single provider registry. Marine zone alerts use the NWS marine zone discovery utility (`providers/_common/nws_zones.py`) to discover relevant zones at setup time. These alerts are served from the API's `/api/v1/alerts` endpoint alongside all other alert types.

This is a hard architectural boundary: alerts never move to the marine service. The marine service provides wave physics and environmental data; alert aggregation and deduplication remain centralized.

**Why:** Alert deduplication, priority ordering, and the unified alert banner on the dashboard require a single alert source. Splitting alert sources would produce duplicate suppression failures and ordering inconsistencies. See ADR-089 for the rationale.

### §19.7 Health check

The marine service exposes a health check endpoint that the API polls every 60 seconds:

`GET {marine_service_url}/health` — no auth required.

**Response (B3, MARINE-MODEL-RESTORATION-PLAN.md, 2026-07-27 — `status` was previously hardcoded to `"ok"` on every call regardless of what the model was actually doing; `reasons`/`inputs`/`invariants` are additive):**

```json
{
  "status": "ok",
  "version": "0.1.0",
  "last_run": "2026-07-22T14:00:00Z",
  "spots": ["huntington-city-beach-pier"],
  "run_in_progress": false,
  "reasons": [],
  "inputs": {
    "ww3_boundary": {"available": true, "age_s": 3600},
    "wind": {"available": true, "age_s": 1800},
    "bathymetry": {"available": true, "age_s": 432000},
    "tide": {"available": true, "age_s": 900}
  },
  "invariants": {"fired_total": 0, "last_fired_at": null, "last_fired_names": []}
}
```

| Field | Description |
|-------|-------------|
| `status` | One of `"ok"` / `"degraded"` / `"failed"` — **`failed` is new as of B3**; see below. |
| `version` | Marine service package version |
| `last_run` | ISO-8601 UTC timestamp of the last completed SWAN cycle, or `null` if none has ever completed |
| `spots` | Configured surf spot ids (list of strings) |
| `run_in_progress` | `true` when a SWAN run is currently executing |
| `reasons` | List of short machine-readable strings explaining a non-`ok` status. Empty when `ok`. |
| `inputs` | Per required input (`ww3_boundary`, `wind`, `bathymetry`, `tide`): `{"available": bool, "age_s": int \| null}`. An input never recorded reports `{"available": false, "age_s": null}`. |
| `invariants` | `{"fired_total": int, "last_fired_at": str \| null, "last_fired_names": [str]}` from the B2 runtime invariant registry, scoped to firings at or after `last_run`. |

**`status` resolution (precedence: `failed` > `degraded` > `ok`):**

- `failed` — `last_run` is `null` (no cycle has ever completed — nothing has been published), or a required input is unavailable. All four inputs are required (rules/coding.md §1, C-77): a missing/failed fetch aborts the SWAN run rather than substituting a default, so an unavailable required input means nothing was published this cycle.
- `degraded` — the cycle completed and every input is available, but an input is stale past its own monitoring threshold, or a B2 invariant fired at or after `last_run`.
- `ok` — otherwise.

Immediately after a service restart, `/health` reports `failed` until the first cycle completes — this is the honest state, not a regression.

**Note:** `POST /setup/providers/test-marine`'s `TestMarineResponse` (§18 setup-endpoint table, API repo) still documents its own `status` field as `"ok" | "degraded"` only — that is a separate, narrower six-field pinned schema for the wizard's connectivity test (see the distinction called out below), not this endpoint's contract, and is unaffected by B3. It has not been updated to add `failed` as part of this task; flagging here rather than changing the API repo.

**Failure response:** Three consecutive health check failures → API logs ERROR, removes marine capabilities from `/api/v1/capabilities`, and continues serving the last-good cached marine data. When the marine service recovers, the next successful health check re-fetches the manifest and restores capabilities.

The health check does not affect non-marine API functionality. Dashboard pages not using marine data are unaffected by marine service failures.

**Admin status pass-through — `GET /setup/marine/health` (Marine Model Restoration Plan B4, part A).** Nothing outside the API may contact the marine service directly (ARCHITECTURE.md "The marine service is an add-on reached only through the API — INVARIANT"), so the admin status page reads marine health through this endpoint rather than calling `{marine_service_url}/health` itself. Session-authenticated (same as the other `/setup/marine/*` endpoints); the marine service's own `/health` stays auth-exempt, so no bearer token is sent upstream. Response: `{reachable: bool, error: str|null, health: object|null}`.

`health` is an **opaque pass-through of the marine service's own `/health` JSON body — verbatim, unmodeled**. The API does not name, validate, or reshape any key inside it. This is deliberate: B3 is adding `reasons`/`inputs`/`invariants` alongside the existing `status`/`version`/`last_run`/`spots`/`run_in_progress` keys, and this endpoint must carry whatever the marine service publishes — including keys added after this endpoint shipped — without code changes on the API side. Do not add a nested Pydantic schema for `health`'s contents later; doing so would silently drop any key the schema doesn't enumerate, which is the same class of defect `GET /health` used to have when it hardcoded `"status": "ok"`. This is *not* the same contract as `POST /setup/providers/test-marine` (§18 setup-endpoint table), which intentionally narrows the marine health response to a pinned six-field shape for the wizard's connectivity test — the two endpoints answer different questions and must not be merged.

Always HTTP 200 (session auth failure aside) — an unreachable or misbehaving marine service is itself a status the admin page renders, not an error page:

| Condition | `reachable` | `error` |
|---|---|---|
| `marine_service_url` not configured | `false` | `"Marine service is not configured"` |
| Connection refused | `false` | `"Connection refused"` |
| Timeout (5 s) | `false` | `"Connection timed out"` |
| Other transport exception | `false` | `"Connection failed: <ExceptionClassName>"` |
| Non-2xx upstream status | `false` | `"Marine service returned HTTP <code>"` |
| 2xx but body is not a JSON object | `false` | `"Marine service returned a non-JSON response"` |
| 2xx with a JSON object body | `true` | `null` (`health` carries the body) |

### §19.8 Post-conversion enrichment — station observations, alerts, locale text

The marine service has no weewx archive and no locale/i18n configuration (ADR-034 co-location; MARINE-SEP-CONCERNS.md C-24/C-29). Four categories of data that lived in the pre-separation API's marine endpoints are therefore restored **on the API side**, after §19.3's unit conversion and before envelope wrapping — `services/marine_enrichment.py`, called from `services/companion_proxy.py`'s `_apply_post_conversion_enrichment()` seam. This is the API's own logic operating on its own data (weewx archive, alert provider, locale files); it is not a second copy of anything the marine service does.

**Station observations (C-24).** Where a marine location is within `dedup_radius_km` of the weewx station (`services/marine_location_resolver.is_station_served()`), the API overwrites the marine service's cache/forecast-sourced wind/temperature/pressure fields with the operator's own instrument reading:

| Route | Fields restored |
|---|---|
| `GET /marine` (list) | `windSpeed`, `windDirection`, `airTemp` |
| `GET /marine/{location_id}` (detail) | `windSpeed`, `windDirection`, `windGust`, `airTemp`, `pressure` |

Values are passed through unconverted (matching the pre-separation endpoint's own documented interim behavior). **Not yet implemented: surf t=0 station wind.** Restoring `windSource: "station"` for the t=0 surf forecast entry requires recomputing every wind-derived scoring field (`windQuality`, `scoring.organizationWind`, and transitively `waveOrganization`/`qualityStars`/`conditionsText`'s wind clause) — doing that in the API would duplicate `score_surf()`'s composite formula across two services. Escalated to the operator; surf entries keep `windSource: "forecast_provider"` at t=0 until a decision lands.

**Active alerts (C-25).** Alerts never move to the marine service (§19.6, unconditional). Restored from `providers/alerts/nws.py`:

| Route | Field | Marine service sends | API restores |
|---|---|---|---|
| `GET /marine` (list) | `MarineLocationSummary.activeAlerts` | `null` | classified alert list |
| `GET /beach-safety/{location_id}` (detail) | `assessment.activeAlerts` | `[]` | filtered headline list (ADR-090 event-type filter) |

`GET /marine/{location_id}` and `GET /beach-safety` (list) never carried alerts and are unaffected.

**Locale text composition (C-29).** The marine service performs all scoring/classification and emits **semantic keys** plus raw SI ingredients; the API resolves keys via `i18n.t()` and composes sentences via `services/marine_enrichment.py`'s relocated `_compose_surf_conditions_text()` / `_compose_fishing_conditions_text()` (ported essentially unchanged from `enrichment/surf_scorer.py` / `enrichment/fishing_scorer.py` — both deleted from the API by Phase 6, `fishing_scorer.py` as orphaned dead code, audit finding F2, 2026-07-25). No scoring or classification logic is reproduced in the API. **Corrected (C-44 sweep, 2026-07-25):** `conditionsTextParts.heightM` IS a `§19.3` `_FIELD_GROUPS` entry (`group_wave_height`) and is therefore already display-unit converted by the generic proxy conversion step by the time `marine_enrichment.py` reads it — that module uses it directly, with no second conversion. Only `windSpeedMps` is genuinely outside `_FIELD_GROUPS` (by design — a bare `Mps`-suffixed field would collide with nothing, but is left out so the generic converter never touches it) and is converted once, here, from raw SI. An earlier version of this paragraph and of `marine_enrichment.py`'s own docstring both claimed `heightM` was also outside `_FIELD_GROUPS`; that was wrong and had caused `marine_enrichment.py` to convert `heightM` a second time — a live double-conversion defect, fixed in the same change as this correction.

Wire shape (`SurfForecast`, confirmed against the marine service):

```json
{
  "qualityKey": "surf.quality.4",
  "windQualityKey": "surf.wind_quality.offshore",
  "conditionsTextParts": {
    "unavailable": false,
    "heightM": 1.2, "periodS": 13.0, "directionDeg": 260.0,
    "compass": "W", "windSpeedMps": 3.0,
    "swellSummaryKey": "surf.conditions.swell_clean"
  }
}
```

resolves to the outward `SurfForecast` shape the dashboard has always seen — `qualityLabel`, `windQuality`, `conditionsText` — with the `*Key`/`conditionsTextParts` fields removed. `qualityKey` is `null` in the unavailable case (`conditionsTextParts.unavailable: true`, every other part field `null`); `windQualityKey` stays populated (wind is an independent observation). `FishingForecast` follows the same pattern: `periodLabelKey` → `periodLabel`, `speciesScores[].statusKey` → `speciesScores[].status`, and a `conditionsTextParts` object of `{overallLabelKey, pressurePhraseKey, tidePhraseKey, solunarClauseKey, activeSpeciesNames}`.

**`currentResidual` (C-37).** The marine service emits `{"valueM": 0.45, "quality": "good", "source": "coops_observed"}` — canonical meters, no description. The API converts `valueM` to the operator's display unit and adds `value` (rounded) and `description` (`"+0.45 m vs prediction"` / `"+1.48 ft vs prediction"`), matching the pre-separation format exactly.

`*Key` field names exist only on the wire between the two services — they never reach the dashboard.
