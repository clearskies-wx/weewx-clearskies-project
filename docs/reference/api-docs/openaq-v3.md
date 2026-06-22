# OpenAQ API v3 — Reference Documentation

**Captured:** 2026-06-22 via docs.openaq.org (v3 API)
**Use case:** Bootstrap-only — historical PM2.5 data for auto-calibration baseline (ADR-068).
**NOT used as a real-time AQI provider** — latency too high (~1-2 hours) for real-time haze detection.

---

## Base URL

```
https://api.openaq.org/v3/
```

Versions 1 and 2 were retired January 31, 2025 and return HTTP 410.

## Authentication

**API key required.** Register at: https://explore.openaq.org/register

Manage/rotate key at: https://explore.openaq.org/account

Pass via HTTP header on every request:

```
X-API-Key: YOUR-OPENAQ-API-KEY
```

Example:
```bash
curl --request GET \
  --url "https://api.openaq.org/v3/locations/2178" \
  --header "X-API-Key: YOUR-OPENAQ-API-KEY"
```

## Rate Limits

| Tier | Requests/minute | Requests/hour |
|------|----------------|---------------|
| Free | 60 | 2,000 |
| Custom | Higher (contact OpenAQ) | Higher |

- Scoped per API key
- Exceeding returns **HTTP 429 Too Many Requests**
- Repeated violations can lead to temporary or permanent ban

**Response headers:**

| Header | Description |
|--------|-------------|
| `x-ratelimit-used` | Requests consumed in current period |
| `x-ratelimit-limit` | Maximum allowed in period |
| `x-ratelimit-remaining` | Requests left before limit |
| `x-ratelimit-reset` | Timestamp when counter resets |

**Bootstrap compliance:** At 60 req/min, pulling 2 years of hourly data for one monitor (17,520 records at 1,000/page = 18 requests) takes ~18 seconds. Well within limits.

## Response Format

JSON. REST principles with resource-oriented URLs, standard HTTP status codes.

**Pagination metadata** in every response:

```json
{
  "meta": {
    "name": "openaq-api",
    "website": "/",
    "page": 1,
    "limit": 100,
    "found": 16492
  },
  "results": [...]
}
```

### Pagination

| Parameter | Default | Maximum | Description |
|-----------|---------|---------|-------------|
| `limit` | 100 | 1,000 | Results per page |
| `page` | 1 | — | Page number |

`meta.found` gives total matching records. Iterate pages until `page * limit >= found`.

**Performance tip:** For `/measurements` and `/hours`, use `date_from` and `date_to` to narrow to a single year or less. This leverages database indexes.

## Date/Time Format

**ISO-8601:** `YYYY-MM-DDTHH:MM:SS.SSSSZ`

**Timezone handling:** If no timezone specified, assumes the local time of the monitoring station. API returns both UTC and local:

```json
{
  "utc": "2019-07-11T20:00:00Z",
  "local": "2019-07-11T14:00:00-06:00"
}
```

**Time-ending convention:** Hourly measurements are timestamped at their end. `03:00` represents data from `02:00–02:59`.

## Key Endpoints for Bootstrap

### 1. Find nearest PM2.5 monitors

**Endpoint:** `GET /v3/locations`

**Geospatial query parameters:**

| Parameter | Description |
|-----------|-------------|
| `coordinates` | `latitude,longitude` (WGS84/EPSG:4326) |
| `radius` | Distance in meters (max 25,000 = 25 km) |

Example — find monitors within 25 km of a station:
```
GET /v3/locations?coordinates=40.7128,-74.0060&radius=25000
```

Filter by parameter to find PM2.5 monitors specifically. The PM2.5 parameter ID can be looked up via `GET /v3/parameters`.

**Bounding box alternative:**
```
?bbox=min_lon,min_lat,max_lon,max_lat
```

Cannot combine `coordinates` and `bbox` in one query (HTTP 422).

### 2. Get sensor details for a location

**Endpoint:** `GET /v3/locations/{locationsId}`

Returns all sensors at a location, including their parameter (PM2.5, PM10, etc.) and sensor IDs.

### 3. Pull historical measurements

**Endpoint:** `GET /v3/sensors/{sensorsId}/measurements`

**Key parameters:**

| Parameter | Description |
|-----------|-------------|
| `date_from` | Start of date range (ISO-8601) |
| `date_to` | End of date range (ISO-8601) |
| `limit` | Results per page (max 1,000) |
| `page` | Page number |

**Response fields per measurement:**

| Field | Type | Description |
|-------|------|-------------|
| `value` | float | PM2.5 concentration in the sensor's units (typically µg/m³) |
| `parameter` | object | `{id, name, units, displayName}` |
| `period` | object | `{label, interval, datetimeFrom, datetimeTo}` (UTC and local) |
| `coordinates` | object | `{latitude, longitude}` (null for stationary monitors) |
| `coverage` | object | `{expectedCount, observedCount, percentComplete, ...}` |

**Performance warning:** Large date ranges without `date_from`/`date_to` constraints can timeout (HTTP 408). Query in chunks of ≤1 year.

### 4. Latest measurement (informational only)

**Endpoint:** `GET /v3/locations/{locationsId}/latest`

**Caveat:** The latest value does NOT represent the most recent ingested measurement. Measurements can arrive out of order. Do not rely on this for real-time data coverage.

## Data Coverage

- **Parameters:** PM2.5, PM10, SO2, NO2, CO, O3, BC, relative humidity, temperature. Limited locations: PM1, PM4, CO2, NO, NOx, CH4, UFP.
- **Countries:** 141+ countries with government reference monitors
- **History:** ~2016 onward for most monitors
- **Data sources:** Government reference-grade monitors aggregated from national air quality agencies worldwide

## Bootstrap Workflow

1. **Find nearest monitor:** `GET /v3/locations?coordinates={lat},{lon}&radius=25000` — filter results for PM2.5 sensors
2. **Get sensor ID:** From the location response, extract the `sensorsId` for the PM2.5 sensor
3. **Pull historical data:** `GET /v3/sensors/{sensorsId}/measurements?date_from=2024-01-01&date_to=2025-01-01&limit=1000` — paginate through all results
4. **Process:** Match PM records against weewx archive timestamps, compute Kcs, seed calibration

## Configuration Keys (api.conf)

```ini
[openaq]
api_key = (from env: WEEWX_CLEARSKIES_OPENAQ_API_KEY)
```

The API key is stored in `secrets.env` and referenced by environment variable, following the ADR-027 secrets pattern.
