# Clear Skies — API Manual

Single authority for all Clear Skies API implementation rules. Consumers: API dev agents and human reviewers.

When this document conflicts with any other source (ADRs, code comments, conversation history), **this document wins**. ADRs explain *why* decisions were made; this manual says *what to do*.

Companion documents:

- **ARCHITECTURE.md** — system topology, ports, containers (what the system IS)
- **PROVIDER-MANUAL.md** — provider module rules
- **contracts/canonical-data-model.md** — per-field data catalog (the field inventory)

Last updated: 2026-07-02

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
| `SurfBundle` | Container: surf forecast + rating per location |
| `FishingBundle` | Container: fishing forecast + scoring per location |
| `BeachSafetyBundle` | Container: beach safety assessment per location |

### Response shapes

**Observation endpoints** (`/current`, SSE stream) return `ConvertedValue` dicts for each observation field:

```json
{"value": 22.5, "label": "°C", "formatted": "22.5"}
```

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

**Not implemented (deferred):** the i18n compliance plan's research phase (§1D of `docs/planning/I18N-COMPLIANCE-PLAN.md`) called for three additional pieces that are **not** present in the current code, even though every locale file carries JSON fields that look like wiring for them:

- **Per-locale composer dispatch.** `ja.json`, `zh-CN.json`, and `zh-TW.json` each carry `"composition": {"pattern": "custom", "composer": "ja"}` (or `"zh"`) — but no code reads `composition.pattern` or `composition.composer`, and there is no `locales/composers/` module. The generic `_compose()` above runs unconditionally for every locale.
- **CJK compound-expression composition.** JMA-style forms (時々/一時/のち operators producing e.g. 曇り時々晴れ) and CMA-style space-separated wind-grade forms were researched but not built. Japanese and Chinese `weatherText` at runtime uses the same English-derived word order and punctuation-joining pattern as every other locale, with Japanese/Chinese words and the locale's own separator/connector substituted in — this produces grammatically acceptable but not JMA/CMA-native phrasing.
- **Locale-driven component order.** Locale files (e.g. `ru.json`, `de.json`) carry a `composition.order` array (`["sky", "temperature", "wind", "precipitation"]` for German and Russian, reflecting those languages' natural word order) — but `build_weather_text()` never reads it; the Python-side order is fixed for all locales.
- **Case-inflected composition for Russian.** `i18n.t_case()` exists and correctly resolves grammatical-case dicts (nominative/instrumental/genitive), but `_compose()` calls only `t()` — the composition path does not invoke `t_case()`, so Russian `weatherText` uses the nominative form throughout rather than switching to instrumental/genitive forms for "with X" / "without X" constructions.

None of this is a defect in what shipped — the template approach produces correct, readable `weatherText` in all 13 locales. It is a scope reduction from the plan's research relative to native-speaker phrasing for `ja`/`zh-CN`/`zh-TW`/`ru`. Tracked as a deferred item in `docs/planning/I18N-COMPLIANCE-PLAN.md`.

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
5. Haze (05) — new, ADR-067
6. Sky condition

**Active code set:**

| WMO code | Phenomenon | Status |
|----------|-----------|--------|
| 05 | Haze | Added — ADR-067 |
| 10 | Mist | Added — ADR-069 |
| 45 | Fog | Existing |
| 48 | Depositing rime fog (ice on surfaces + fog) | Added — ADR-070 |
| 60–69 | Rain variants | Existing |
| 70–79 | Snow variants | Existing |
| 79 | Ice pellets | Existing |
| 96 | Thunderstorm | Existing |

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
| Fire: humidity | `humidity_max/min` | max/min(outHumidity) | `outHumidity` | Y | — | Y | Y |
| Fire: LAL | `weather_codes` + `precip_coverage` | derived | `weatherCode` + PoP | Y | Y | Y | Y |

When a provider does not supply a field (marked "—"), the engine omits the corresponding phrase. It does not fabricate data.

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
| `frequencyRange` | list[float] | — | No | [min_hz, max_hz] bounds of this spectral partition |
| `classification` | str | — | No | (locale) `"groundswell"` (period ≥ 12s), `"swell"` (8–12s), `"wind_swell"` (< 8s) |

#### TidePrediction

Predicted tide event from CO-OPS harmonic predictions.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Prediction time (UTC ISO-8601) |
| `height` | float | `group_water_level` | No | Predicted water level relative to datum |
| `type` | str | — | Yes | `"high"`, `"low"`, or null for interpolated points |

#### WaterLevel

Observed water level from CO-OPS gauges.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `time` | str | — | No | Observation time (UTC ISO-8601) |
| `height` | float | `group_water_level` | No | Observed water level relative to datum |
| `datum` | str | — | No | Reference datum (e.g., `"MLLW"`, `"MSL"`, `"NAVD88"`) |
| `quality` | str | — | Yes | Quality flag from CO-OPS (e.g., `"v"` verified, `"p"` preliminary) |

#### MarineForecastPoint

Single timestep from WaveWatch III wave forecast.

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
| `waveHeightAtBreak` | float | `group_wave_height` | No | Wave height at breaking (after NWPS supplements) |
| `period` | float | `group_wave_period` | No | Dominant period |
| `direction` | float | — | No | Dominant swell direction (degrees true north) |
| `qualityStars` | int | — | No | 1–5 star rating |
| `qualityLabel` | str | — | No | (locale) Text label: "Poor", "Fair", "Good", "Very Good", "Epic" |
| `conditionsText` | str | — | No | (locale) Natural-language conditions summary |
| `windQuality` | str | — | No | (locale) "glassy", "offshore", "cross_offshore", "cross", "cross_onshore", "onshore" |
| `swellDominance` | float | — | No | Ratio of primary swell energy to total energy (0.0–1.0) |
| `multiSwell` | list[SpectralWaveComponent] | — | Yes | Individual swell systems (when spectral data available) |

#### FishingForecast

Fishing conditions forecast for one spot for one period.

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `periodStart` | str | — | No | Period start time (UTC ISO-8601) |
| `periodEnd` | str | — | No | Period end time (UTC ISO-8601) |
| `periodLabel` | str | — | No | (locale) Human-readable period: "Early Morning", "Late Afternoon", etc. |
| `overallScore` | int | — | No | Composite score 0–100 |
| `pressureScore` | int | — | No | Pressure component sub-score 0–100 |
| `tideScore` | int | — | No | Tide component sub-score 0–100 |
| `solunarScore` | int | — | No | Solunar component sub-score 0–100 |
| `waterTempScore` | int | — | No | Water temperature component sub-score 0–100 |
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
| `safetyLevel` | str | — | No | (locale) `"safe"`, `"caution"`, or `"dangerous"` |
| `waveHeight` | float | `group_wave_height` | Yes | Current/forecast wave height |
| `wavePeriod` | float | `group_wave_period` | Yes | Current/forecast wave period |
| `ripCurrentRisk` | str | — | Yes | (locale) `"low"`, `"moderate"`, `"high"` (from SRF or NWPS v1.5) |
| `waterTemp` | float | `group_temperature` | Yes | Water temperature |
| `comfortLevel` | str | — | Yes | (locale) `"comfortable"`, `"cool"`, `"cold"`, `"dangerous"` |
| `uvIndex` | int | — | Yes | UV index |
| `visibility` | float | `group_visibility` | Yes | Visibility |
| `windSpeed` | float | `group_ocean_speed` | Yes | Wind speed |
| `windDirection` | float | — | Yes | Wind direction |
| `activeAlerts` | list[str] | — | No | Alert headlines relevant to beach safety |

#### MarineLocationSummary

Summary snapshot for one marine location (used by Now page summary card).

| Field | Type | Unit group | Nullable | Description |
|---|---|---|---|---|
| `locationId` | str | — | No | Location slug from config |
| `name` | str | — | No | Display name |
| `coordinates` | object | — | No | `{lat, lon}` |
| `activities` | list[str] | — | No | Enabled activities for this location |
| `currentConditions` | MarineObservation | — | Yes | Latest buoy observation (if buoy activity enabled) |
| `currentTide` | object | — | Yes | Next high/low tide `{type, time, height}` |
| `activeAlerts` | list[str] | — | Yes | Active marine alert headlines |
| `surfRating` | int | — | Yes | Current surf quality stars (1–5, if surf enabled) |
| `beachSafetyLevel` | str | — | Yes | Current safety level (if beach_safety enabled) |

#### Bundle types

Bundles wrap domain-specific models with location metadata, freshness block (§2), and stationClock (§2). Follow the existing `ForecastBundle` pattern.

**`MarineBundle` and `TideBundle` are implemented as declared** — `endpoints/marine.py` and `endpoints/tides.py` construct and `model_dump()` these exact Pydantic models from `models/responses.py`.

| Bundle | Contains | Response for |
|---|---|---|
| `MarineBundle` | `MarineObservation`, `list[MarineForecastPoint]`, `list[MarineTextForecast]` | `GET /api/v1/marine[/{locationId}]` |
| `TideBundle` | `list[TidePrediction]`, `list[WaterLevel]` | `GET /api/v1/tides[/{locationId}]` |

Each bundle also carries: `locationId`, `locationName`, `coordinates`, `freshness` block, `stationClock`, `units`.

**`SurfBundle`, `FishingBundle`, and `BeachSafetyBundle` in `models/responses.py` do NOT match what their endpoints return.** Those three Pydantic classes were written in Phase 0C, ahead of the Phase 5 endpoint implementations; `endpoints/surf.py`, `endpoints/fishing.py`, and `endpoints/beach_safety.py` each build and return a plain dict directly (the standard envelope, §2) and never import or construct the corresponding Bundle class. **Cleanup finding (not a Phase 8 blocker):** `models/responses.py`'s `SurfBundle`/`FishingBundle`/`BeachSafetyBundle` need to be updated to match the shapes below, or removed if they stay unused. The tables below are the actual, ground-truth shapes — sourced by reading the endpoint code directly — and are what `docs/contracts/openapi-v1.yaml` documents.

##### Surf bundle (actual shape) — `GET /api/v1/surf[/{locationId}]`

Source: `endpoints/surf.py`.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `forecast` | list[SurfForecast] | No | 0 or 1 entries. Populated only when NWPS (preferred) or WaveWatch III (fallback) supplied a wave height; empty list if both providers failed |
| `zoneForecast` | SurfZoneForecast | Yes | NWS SRF forecast for the covering county zone; `null` if unavailable |
| `spectralComponents` | list[SpectralWaveComponent] | No | Current NDBC spectral swell decomposition; empty list if no spectral-capable buoy configured or NDBC fetch failed |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions for the surf page's tide overlay (informational, not scored). **Not a field on `SurfBundle` in models/responses.py.** |
| `source` | str | No | Fixed string `"nwps+wavewatch+ndbc+coops+nws_srf"` |
| `generatedAt` | str | No | UTC ISO-8601 with Z |

##### Fishing bundle (actual shape) — `GET /api/v1/fishing[/{locationId}]`

Source: `endpoints/fishing.py`. Structurally different from `FishingBundle` in models/responses.py — there is no flat top-level `forecast` list or singular top-level `solunar` field.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `days` | list[object] | No | One entry per forecast day (3 days). Each entry: `{"date": "YYYY-MM-DD", "periods": list[FishingForecast], "solunar": SolunarTimes}` |
| `species` | list[str] | No | From the location's `FishingSpotConfig.species` |
| `targetCategory` | str | No | From the location's `FishingSpotConfig.target_category` |
| `habitatFeatures` | object \| null | Yes | CUDEM-derived habitat annotations (drop-offs, reefs, ledges, channels, pinnacles); `null` when the location has no bathymetric profile (i.e., no `surf` sub-block configured) |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions, also used server-side to derive each period's `tide_state` input to the fishing scorer |
| `source` | str | No | Fixed string `"ndbc+coops+solunar"` |
| `generatedAt` | str | No | UTC ISO-8601 with Z |

`days`, `species`, `targetCategory`, and `habitatFeatures` do not exist on `FishingBundle` in models/responses.py.

##### Beach-safety bundle (actual shape) — `GET /api/v1/beach-safety[/{locationId}]`

Source: `endpoints/beach_safety.py`. There is no `zoneForecast` field in the actual response — SRF-sourced rip current risk and UV index are folded directly into `assessment` instead.

| Field | Type | Nullable | Description |
|---|---|---|---|
| `locationId` | str | No | Location slug from config |
| `locationName` | str | No | Display name |
| `coordinates` | object | No | `{lat, lon}` |
| `assessment` | object (`BeachSafetyAssessment` shape) | No | `safetyLevel`, `waveHeight`, `wavePeriod`, `ripCurrentRisk`, `waterTemp`, `comfortLevel`, `uvIndex`, `visibility`, `windSpeed`, `windDirection`, `activeAlerts` |
| `nwpsV15` | object \| null | Yes | `{ripCurrentProbability, totalWaterLevel, waveRunup}` when the covering WFO supplies NWPS v1.5 fields; `null` otherwise. **Not on `BeachSafetyBundle`.** |
| `tidePredictions` | list[TidePrediction] | No | CO-OPS tide predictions. **Not on `BeachSafetyBundle`.** |
| `waterLevels` | list[WaterLevel] | No | CO-OPS observed water levels. **Not on `BeachSafetyBundle`.** |
| `externalLinks` | list[object] | No | `{label, url}` from the location's `BeachSafetyConfig.external_links`. **Not on `BeachSafetyBundle`.** |
| `source` | str | No | Fixed string `"nwps+ndbc+nws_srf+coops+nws_alerts"` |
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

### NWPS supplement processor

**File:** `enrichment/wave_transform.py`
**Registration:** Against the surf scoring pipeline — runs after NWPS fetch, before `surf_scorer.py`.
**Inputs:** NWPS wave data (height, period, direction), spot config (bottom type, slope, structures, topographic feature, coordinates), CUDEM bathymetric profile.
**Outputs:** Corrected wave height, period, direction at the spot location.

Applies four targeted supplements to correct documented NWPS/SWAN limitations. No-op when NWPS data is unavailable (WaveWatch III data passes through unmodified).

**Supplement 1 — Breaker index correction (γ tuning):**

SWAN uses a constant γ = 0.73. The actual γ varies from ~0.6 (spilling breakers on gentle sand) to ~1.2 (plunging breakers on steep reef).

Formula: **γ = 1.06 + 0.14 ln ξ** (Battjes 1974)

Where ξ = tan α / √(H₀/L₀) is the Iribarren number:
- tan α = average nearshore bottom slope (from CUDEM bathymetric profile)
- H₀ = NWPS-provided significant wave height
- L₀ = deep-water wavelength = g × T² / (2π), where T = NWPS-provided peak period, g = 9.81 m/s²

Application: H_max = γ_corrected × depth (recompute maximum wave height at breaking using site-specific γ instead of SWAN's constant 0.73).

**Validation:** γ output clamped to [0.5, 1.4] (physical bounds from literature). Values outside this range logged as warnings — indicate bad slope or wave data.

Operator inputs: `bottom_type` (sand/rock/coral_reef/mixed), `beach_slope` (computed from CUDEM).

**Supplement 2 — Coastal structure effects (transmission/reflection):**

H_transmitted = Kt × H_incident

| Material | Kt | Examples |
|---|---|---|
| Impermeable | 0.10 ± 0.05 | Concrete seawall, solid breakwater |
| Semi-permeable | 0.35 ± 0.15 | Rubble mound, rock jetty |
| Permeable | 0.75 ± 0.10 | Timber pier, open groin |

Influence zone: effects apply within structure-type-specific distance (jetty: 3–5× length, breakwater: 2–4× length) and diminish as 1/r² with distance from the structure.

All output labeled: "estimated — structure effects are approximate."

Operator inputs: structure type, material, dimensions, position relative to spot.

**Supplement 3 — Sub-grid spatial interpolation:**

Bilinear interpolation using the four surrounding NWPS grid nodes. No operator input required — coordinates already configured.

**Supplement 4 — Topographic wave focusing/sheltering:**

Multiplicative adjustment based on operator-classified feature:

| Feature | Multiplier | Effect |
|---|---|---|
| Point break | × 1.1 | Wave focusing around headland |
| Headland | × 1.2 | Refraction enhancement |
| Bay break | × 0.9 | Sheltering, height reduction |
| Straight beach | × 1.0 | No modification |

Operator inputs: topographic feature classification from spot config.

**What is NOT supplemented:** Shoaling, refraction, bottom friction, wave-current interaction. NWPS/SWAN computes these with its own bathymetry and RTOFS currents. Re-running them would duplicate NWPS's work without improving it.

All physics constants (γ bounds, Kt values, topographic multipliers) defined as module-level constants with source citations.

### Surf quality scorer

**File:** `enrichment/surf_scorer.py`
**Registration:** Against the surf endpoint — runs after wave_transform.
**Inputs:** Corrected wave data (from wave_transform or raw WaveWatch III), spectral components (from NDBC), spot config (beach facing, directional exposure), wind data.
**Outputs:** `SurfForecast` with quality_stars (1–5), quality_label, conditions_text.

Scoring factors:
- **Wave height:** Larger = better (within rideable range for the spot)
- **Period:** Longer = better (cleaner, more powerful waves)
- **Swell dominance:** Higher ratio of primary swell energy to total energy = cleaner conditions
- **Wind quality:** Offshore (blowing from land to sea) = best (holds wave face up); onshore = worst. Classification: offshore → cross_offshore → cross → cross_onshore → onshore, based on angle between wind direction and beach-facing direction.
- **Beach angle alignment:** Per-component directional filter — a swell from a direction blocked by the beach's `directional_exposure` config scores zero for that component.
- **Multi-swell interference:** Compatible swells (similar direction) combine constructively; opposing swells create confused seas and score lower.

Quality labels: 1 = "Poor", 2 = "Fair", 3 = "Good", 4 = "Very Good", 5 = "Epic".

### Fishing scorer

**File:** `enrichment/fishing_scorer.py`
**Registration:** Against the fishing endpoint.
**Inputs:** Pressure trend (from weewx archive or NDBC buoy), tide state (from CO-OPS), water temperature (from NDBC/CO-OPS), solunar intensity (from solunar processor), current time.
**Outputs:** `FishingForecast` with overall_score (0–100) and per-component sub-scores.

**Five-component weighted scoring:**

| Component | Weight | Scoring method |
|---|---|---|
| Barometric pressure trend | 0.30 | 3-hour pressure delta. Rapid drop (> 3 hPa/3hr) = 100 (peak). Falling = 80. Stable = 50. Rising = 30 initially, improving to 60 over 12–24 hr. |
| Tide state | 0.25 | Position in tidal cycle from CO-OPS predictions. Outgoing (ebb) = 100 (flushes bait). Incoming (flood) = 80. Peak flow (midpoint between tidal extremes) = 70. Slack high = 30. Slack low = 20. |
| Water temperature | 0.20 | Compared to species-specific optimal ranges. Within optimal = 100. Good range = 80. Marginal = 50. Outside active range = 10. |
| Solunar intensity | 0.15 | From solunar processor. During major period + new/full moon = 100. During major period (non-peak moon) = 80. During minor period = 60. Outside any period = 30. |
| Time of day | 0.10 | Dawn = 100, Dusk = 90 (low-light feeding peaks). Morning = 70. Night = 50 (species-dependent). Midday = 30. |

**Final score** = Σ(component_score × weight) × species_modifier × seasonal_multiplier, scaled to 0–100 integer.

**Species profiles:** Four target categories, each with species auto-populated from 11 US biogeographic regions:

| Category | Example species | Pressure sensitivity | Typical temp range (°F) |
|---|---|---|---|
| Saltwater inshore | Redfish, Speckled Trout, Flounder, Snook | High | 55–85 |
| Bottom fish | Grouper, Snapper, Sheepshead, Tautog | Moderate | Species-specific, varies widely |
| Freshwater sport | Bass, Walleye, Pike, Catfish | High | 55–75 |
| Salmonids | Salmon, Steelhead, Trout | Moderate | 45–65 |

Each species has: optimal temp range (1.0×), good range (0.8×), marginal range (0.5×), inactive below/above (0.1×). Spawning season multipliers (2.0–3.0× during peak runs).

Species data is hardcoded lookup tables in `enrichment/fishing_species.py`, keyed by biogeographic region and target category. No external API.

**Solunar evidence caveat:** Presented as one factor with appropriate context — "Solunar theory suggests feeding activity correlates with moon position. Scientific evidence is mixed; environmental conditions (pressure, temperature, tides) have stronger research support."

### Solunar computation

**File:** `enrichment/solunar.py`
**Registration:** Against the solunar and fishing endpoints.
**Inputs:** Date, location coordinates.
**Outputs:** `SolunarTimes` model.

Computed locally via Skyfield — no external API call. Skyfield is already a project dependency (almanac feature).

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
| `SurfForecast.conditionsText` | "3-4 ft at 12s from SSW. Offshore winds 5-10 mph." | `surf.conditions.*` composition templates | Compose via locale-aware templates per §6 composition pattern. Direction abbreviations, unit labels, connectors all locale-resolved. |
| `SpectralWaveComponent.classification` | "groundswell" | `marine.swell_class.<value>` | `i18n.t("marine.swell_class.groundswell")` |
| `FishingForecast.periodLabel` | "Early Morning" | `fishing.period.<value>` | `i18n.t("fishing.period.early_morning")` |
| `FishingForecast.conditionsText` | "Falling pressure with incoming tide..." | `fishing.conditions.*` composition templates | Compose via locale-aware templates |
| `FishingForecast.speciesScores[].status` | "active" | `fishing.species_status.<value>` | `i18n.t("fishing.species_status.active")` |
| `BeachSafetyAssessment.safetyLevel` | "caution" | `beach_safety.level.<value>` | `i18n.t("beach_safety.level.caution")` |
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

**Implementation requirement:** Each enrichment processor's output function must accept a `locale` parameter (defaulting to `i18n.get_active_locale()`). All label lookups use `i18n.t(key, locale=locale)`. All number formatting in composed text uses `i18n.format_number(value, decimals, locale=locale)`. This is the same pattern used by `enrichment/conditions_text.py` — read that module for the reference implementation.

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
| `GET /api/v1/beach-safety[/{locationId}]` | `list[object]` (`locationId`, `name`, `lat`, `lon`, `safetyLevel`, `ripCurrentRisk`, `waterTemp` — live-fetched per card) | Beach-safety bundle, actual shape (§16) | At least one location with `beach_safety` activity enabled |
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
| `/marine` | 1800 | Matches WaveWatch III / NWPS cache TTL |
| `/tides` | 600 | Observed water levels update every 6–10 min |
| `/surf` | 1800 | Matches wave forecast cache TTL |
| `/fishing` | 3600 | Scoring inputs change slowly |
| `/beach-safety` | 1800 | Matches wave forecast cache TTL |
| `/almanac/solunar` | 86400 | Celestial mechanics — changes daily |

### Capability gating and the activity matrix

Which provider modules and enrichment processors are activated depends on the union of enabled activities across all configured locations. The activity capability matrix (consolidated from ADR-090) defines which capabilities each activity enables. The API activates only the provider modules required by the union of activities. See PROVIDER-MANUAL §14 for per-provider details.

When no marine locations are configured (no `[marine]` section in `api.conf`), no marine provider modules register, no marine endpoints are available, and the API behaves identically to a non-marine installation.
