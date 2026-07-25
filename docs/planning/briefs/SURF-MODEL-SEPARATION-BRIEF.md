# Marine Service Separation Audit Brief

**Created:** 2026-07-22
**Status:** AUDIT COMPLETE — remediation plan required
**Origin:** User-ordered full audit after discovering the surf/marine system was improperly embedded in the API and partially migrated to librewxr, leaving nothing functional.

---

## 1. The Architectural Violation and the Correct Architecture

### What should exist

The Clear Skies API provides everything weather **except marine**. When an operator wants marine capabilities, they install the **marine service** — a completely self-contained standalone extension that handles everything marine: wave physics (SWAN), surf zone modeling (SwellTrack, SurfBeat), tides, buoy data, marine weather forecasts, ocean currents, fishing/solunar, beach safety.

The marine service is a **little brother to the API**:
- Same architectural DNA — same provider module pattern, same structure, same feel
- Completely standalone — fetches its own data from external sources (NOAA, NCEI, etc.)
- Can sit on the same host as the API or on a separate host
- Never talks to the dashboard directly — always communicates through the API
- The API is the single source of truth for the dashboard — one place to go for all data

Just like LibreWxR is an external service the API consumes, the marine service is an external service the API consumes. The only difference: the marine service is a Clear Skies component (same licensing, same repo conventions, same config patterns), not a third-party service.

```
librewxr (or any compute-capable host, or same host as API)
+------------------------------------------------------+
| Marine Service (standalone)                          |
|                                                      |
|  Wave physics:                                       |
|   - SWAN 3-level nested grid (HRRR+GFS wind)        |
|   - SwellTrack per-transect 1D transformation        |
|   - SurfBeat IG strip (set timing)                   |
|                                                      |
|  Marine data providers (same pattern as API):        |
|   - NDBC buoy (spectral, met, water temp)            |
|   - CO-OPS tides (predictions, observations)         |
|   - NWS marine weather (zone forecasts)              |
|   - NWS NWPS surf forecast                           |
|   - WaveWatch III (boundary spectra)                 |
|   - HRRR wind (3 km, 0-48h)                         |
|   - GFS wind (0.25°, 48-72h)                        |
|   - CUDEM bathymetry (NCEI)                          |
|   - OFS ocean currents                               |
|   - ERDDAP ocean data                                |
|                                                      |
|  Enrichment:                                         |
|   - Surf scoring, breaker classification             |
|   - Beach profile blending                           |
|   - Face height calculation                          |
|   - Solunar, beach safety assessments                |
|                                                      |
|  Serves complete marine data via HTTP endpoints      |
|  One port, one health check, one auth token          |
+------------------------------------------------------+
         ↑
         | HTTP (authenticated, TLS)
         ↓
weewx host
+------------------------------------------------------+
| Clear Skies API                                      |
|   - Marine provider module (thin HTTP client)        |
|     Same pattern as NWS/LibreWxR providers           |
|   - Serves /api/v1/surf/{id}                         |
|   - Serves /api/v1/marine/{id}                       |
|   - Serves /api/v1/tides/{id}                        |
|   - Serves /api/v1/fishing/{id}                      |
|   - Serves /api/v1/beach-safety/{id}                 |
|   - Serves /api/v1/surf/{id}/profile                 |
|   - No marine physics code, no SWAN, no provider     |
|     modules for marine data sources                   |
+------------------------------------------------------+
         ↑
         | HTTP (Caddy proxy)
         ↓
+------------------------------------------------------+
| Dashboard                                            |
|   - Calls API endpoints as always                    |
|   - Has zero knowledge of the marine service         |
|   - Nothing changes in the dashboard                 |
+------------------------------------------------------+
```

### What was built instead

The entire marine data stack — ~35,000 lines across 45+ files — was embedded directly inside the API. A partial extraction was attempted: a "SWAN service" on librewxr:8767 runs wave physics, and a "compute service" on librewxr:8770 offloads SwellTrack/SurfBeat. But:
- The API still contains ALL the same code and falls back to running SWAN locally
- Two separate services on two ports instead of one unified service
- The API can't even connect to the SWAN service (TLS cert verification failure)
- Everything is broken — empty surf page for 24+ hours

---

## 2. Audit Findings — What's On Each Host

### 2.1 weewx (API host)

**API service:** Running and healthy (port 8765). Non-marine endpoints work fine.

**Surf endpoint (`/api/v1/surf/huntington-city-beach-pier`):**
- Returns `forecast: []`, `lastRunTime: null`, `surfForecastError: "surf forecast unavailable"`
- `nearshoreModel: "SWAN + SwellTrack"` (attribution correct, data empty)
- Spectral components (NDBC), tide predictions (CO-OPS), zone forecast (NWS) work — but these are fetched directly by the embedded provider modules, not from a marine service

**Beach profile endpoint:** Returns 404: "No SWAN data cached for location"

**SWAN on weewx — the choking problem (NOW DISABLED):**
- SWAN binary was at `/usr/local/bin/swan` (renamed to `swan.disabled` during this audit)
- The API's SWAN provider probes `https://192.168.7.22:8767` at startup
- **Fails every time:** `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate`
- Falls back to "bundled SWAN mode" — runs SWAN locally on weewx
- Full 3-level run: **42 minutes**, fails at L3 (39.4% valid fraction)
- Hourly quick updates: 53 seconds, succeeds (1 spot resolved, 48/48 valid), but **0 spots cached** (handoff bug)
- Repeating for 24+ hours: burning CPU, producing nothing

**API repo on weewx:** At commit `fa48126` — 1 commit behind origin

**Config on weewx (`api.conf`):**
```ini
[swan]
    omp_num_threads = 16
    service_url = https://192.168.7.22:8767

[providers]
    surf_compute_host = https://192.168.7.22:8770
    surf_compute_verify_tls = false
```

Two separate config keys pointing at two separate services — this is part of the problem.

### 2.2 librewxr (compute host)

**SWAN standalone service (port 8767):** Running, healthy, actively computing.
- Health: `{"status":"ok","version":"1.0.0","last_run":"2026-07-22T13:44:05Z","spots":["huntington-city-beach-pier"],"run_in_progress":true}`
- Actively running 3-level SWAN, fetching HRRR/GFS wind
- L1 and L2 converge successfully
- Source: `weewx-clearskies-swan` repo (3 files, ~350 lines) — a thin wrapper around the same `providers/nearshore/swan.py` code from the API repo
- Uses different auth mechanism than compute service

**Compute service (port 8770):** Running, healthy, idle.
- Auth works (SURF_COMPUTE_SECRET), endpoints validated
- No compute requests in 11+ hours
- Only handles SwellTrack/SurfBeat, not SWAN

**API repo on librewxr:** At commit `7dab1c5` — **5 commits behind origin**

**Memory pressure:** 4.3 GB of 5.6 GB used, 1.0 GB in swap

### 2.3 weather-dev (dashboard/config host)

- Dashboard: deployed, serving, up to date. SurfingTab.tsx (2,625 lines) is complete — waiting for data.
- Config UI: running. SurfBeat toggle, compute host config, friction settings all deployed.
- Surf page renders but shows no forecast data.

### 2.4 Local repos (DILBERT)

All up to date with origin. API: `6a0513e`, Dashboard: `9603fe6`, Stack: `f8beb34`.

---

## 3. Root Cause Chain

```
1. Everything marine embedded in API (architectural violation)
      ↓
2. Partial extraction: SWAN on librewxr:8767, SwellTrack/SurfBeat on librewxr:8770
   BUT API still contains all the same code
      ↓
3. API tries remote SWAN → self-signed TLS cert → CERTIFICATE_VERIFY_FAILED
      ↓
4. Falls back to "bundled mode" — runs SWAN locally on weewx
      ↓
5. Local SWAN full runs fail at L3; quick updates succeed but 0 spots cached
      ↓
6. No SWAN data → no SwellTrack → no SurfBeat → no surf forecast
      ↓
7. Surf endpoint returns empty forecast, beach profile returns 404
      ↓
8. Dashboard surf page has no data
```

---

## 4. Complete Code Inventory — What Moves to the Marine Service

### 4.1 Marine data provider modules (move entirely to marine service)

These follow the API's provider pattern today. They move to the marine service and keep the same architecture — same CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL management.

| Provider module | Lines | What it provides |
|----------------|-------|-----------------|
| `providers/buoy/ndbc.py` | 1,001 | NDBC buoy observations (wave height, period, water temp, met) |
| `providers/tides/coops.py` | 774 | CO-OPS tide predictions and observations |
| `providers/marine/nws_marine.py` | 645 | NWS marine zone weather forecasts |
| `providers/marine/nws_srf.py` | 1,215 | NWS NWPS surf forecasts |
| `providers/marine/wavewatch.py` | 578 | WaveWatch III deep-water boundary spectra |
| `providers/marine/grib_processor.py` | 449 | GRIB2 processing for marine data |
| `providers/wind/hrrr.py` | 907 | HRRR 3 km wind forcing (0-48h) |
| `providers/wind/gfs.py` | 729 | GFS 0.25° wind forcing (48-72h) |
| `providers/ocean/ofs.py` | 665 | OFS ocean surface currents |
| `providers/ocean/erddap_ocean.py` | 247 | ERDDAP ocean data |
| `providers/nearshore/swan.py` | 2,307 | SWAN orchestration (rewritten as internal pipeline, not a provider) |
| **Subtotal** | **9,517** | |

### 4.2 Wave physics and model code (move entirely)

| Module | Lines | What it does |
|--------|-------|-------------|
| `services/swan_runner.py` | 2,628 | 3-level SWAN subprocess execution |
| `services/swan_domain.py` | 634 | Grid domain sizing, spot clustering |
| `services/swan_formats.py` | 1,511 | SWAN INPUT file generation |
| `services/swan_spectral.py` | 555 | SPECOUT parsing |
| `services/surf_1d_analytical.py` | 612 | SwellTrack 1D cross-shore model |
| `services/surf_1d_pipeline.py` | 1,091 | SwellTrack per-transect pipeline |
| `services/surfbeat_runner.py` | 961 | SurfBeat IG strip |
| `services/wave_setup.py` | 316 | Wave-induced water level |
| `services/bathymetry_resolver.py` | 1,070 | CUDEM bathymetry resolution |
| `services/shelf_boundary.py` | 80 | GSFM shelf distance |
| `services/transect_handoff.py` | 742 | SWAN→SwellTrack handoff |
| `enrichment/bathymetry.py` | 1,197 | SWAN depth grid generation |
| **Subtotal** | **11,397** | |

### 4.3 Enrichment / scoring (move to marine service)

Scoring, breaker classification, and wave transforms happen where the data lives — in the marine service. The API receives fully scored results.

| Module | Lines | What it does |
|--------|-------|-------------|
| `enrichment/breaker_height.py` | 283 | Breaking wave calculations |
| `enrichment/surf_scorer.py` | 730 | Surf quality scoring |
| `enrichment/wave_transform.py` | 312 | Wave transformation utilities |
| **Subtotal** | **1,325** | |

### 4.4 Marine config and services (move to marine service)

| Module | Lines | What it does |
|--------|-------|-------------|
| `config/marine_config.py` | 934 | Marine location config parsing |
| `services/marine_location_resolver.py` | 140 | Location resolution |
| `services/marine_weather_cache.py` | 135 | Marine weather caching |
| **Subtotal** | **1,209** | |

### 4.5 Delete (artifacts of the partial extraction)

| Module | Lines | Why delete |
|--------|-------|-----------|
| `services/compute_service.py` | 681 | The broken half-service on librewxr:8770 — replaced by the unified marine service |
| `services/compute_client.py` | 361 | Client for the broken half-service — replaced by the marine service client |
| **Subtotal** | **1,042** | |

### 4.6 Marine endpoints (delete from API — replaced by dynamic registration)

These endpoints are **deleted entirely** from the API. They are replaced by the marine service's own endpoints, dynamically registered via the manifest (§5.3). The API mounts proxied routes automatically — no per-endpoint code needed.

| Endpoint | Lines | Disposition |
|----------|-------|-------------|
| `endpoints/surf.py` | 1,317 | Delete — marine service serves `/surf/{id}`, API mounts via manifest |
| `endpoints/beach_profile.py` | 881 | Delete — marine service serves `/surf/{id}/profile` |
| `endpoints/marine.py` | 1,040 | Delete — marine service serves `/marine/{id}` |
| `endpoints/fishing.py` | 510 | Delete — marine service serves `/fishing/{id}` |
| `endpoints/beach_safety.py` | 497 | Delete — marine service serves `/beach-safety/{id}` |
| **Subtotal** | **4,245** | All deleted |

### 4.7 Summary

| Category | Lines | Disposition |
|----------|-------|-------------|
| Provider modules → marine service | 9,517 | Move |
| Wave physics → marine service | 11,397 | Move |
| Enrichment/scoring → marine service | 1,325 | Move |
| Config/services → marine service | 1,209 | Move |
| Delete (broken partial extraction) | 1,042 | Delete |
| Delete (endpoints replaced by dynamic registration) | 4,245 | Delete |
| **Total removed from API** | **~28,735** | |
| **API-side addition** | **~200-300 lines** | Generic companion-service proxy + manifest handler (works for any companion, not marine-specific) |

---

## 5. Marine Service Architecture

### 5.1 Provider module pattern (mirrors the API)

The marine service uses the **same provider module architecture** as the API. A developer who knows how to add a provider to the API immediately knows how to add a data source to the marine service.

Each data source module has:
- **CAPABILITY declaration** — what fields it can supply, what tier
- **`fetch()` function** — retrieves data from the external source
- **Canonical field mapping** — maps wire format to internal canonical fields
- **Cache TTL management** — per-provider cache lifetimes
- **Error handling** — graceful degradation on source failure

This matters for extensibility. When we need to add a new marine data source (different buoy network, different bathymetry provider, international tide service), the pattern is identical to adding a provider to the API.

### 5.2 Deployment model

The marine service is a pip package: `weewx-clearskies-marine`. Repo: `weewx-clearskies-marine`.

**Same-host deployment:** Operator installs the marine service on the weewx host alongside the API. API calls `localhost:{port}`. No network overhead.

**Separate-host deployment:** Operator installs on a dedicated compute machine (librewxr or any Linux box with SWAN installed). API calls `https://{host}:{port}`. Useful when SWAN's compute requirements (16+ cores, GB of RAM) would impact the API host.

### 5.3 Dynamic endpoint registration

**The API does NOT hardcode marine endpoints.** If we hardcode `/api/v1/surf/{id}`, `/api/v1/marine/{id}`, `/api/v1/tides/{id}`, etc. in the API's source code, then every time we add or change a marine endpoint we have to remember two codebases. Instead, the marine service **registers its endpoints with the API at startup**.

The flow:

1. **Operator configures `marine_service_url`** in `api.conf` (or via wizard).

2. **API startup:** When the API sees a `marine_service_url`, it calls the marine service's registration endpoint (e.g., `GET /manifest`).

3. **Marine service returns its endpoint manifest** — a JSON document describing every endpoint it serves:

```json
{
  "service": "clearskies-marine",
  "version": "1.0.0",
  "endpoints": [
    {
      "path": "/surf/{location_id}",
      "method": "GET",
      "upstream": "/surf/{location_id}",
      "cache_ttl": 1800,
      "description": "Surf forecast with wave heights, break points, scoring"
    },
    {
      "path": "/surf/{location_id}/profile",
      "method": "GET",
      "upstream": "/surf/{location_id}/profile",
      "cache_ttl": 1800
    },
    {
      "path": "/marine/{location_id}",
      "method": "GET",
      "upstream": "/marine/{location_id}",
      "cache_ttl": 300
    },
    {
      "path": "/tides/{location_id}",
      "method": "GET",
      "upstream": "/tides/{location_id}",
      "cache_ttl": 3600
    },
    {
      "path": "/fishing/{location_id}",
      "method": "GET",
      "upstream": "/fishing/{location_id}",
      "cache_ttl": 1800
    },
    {
      "path": "/beach-safety/{location_id}",
      "method": "GET",
      "upstream": "/beach-safety/{location_id}",
      "cache_ttl": 900
    }
  ],
  "capabilities": ["surf", "tides", "marine_weather", "fishing", "beach_safety"],
  "locations": ["huntington-city-beach-pier"]
}
```

4. **API dynamically mounts routes.** For each endpoint in the manifest, the API creates a FastAPI route under `/api/v1/` that proxies to the marine service. Mechanically: a `APIRouter` with routes generated from the manifest, each handler fetches from `{marine_service_url}{upstream_path}`, caches with the specified TTL, wraps in the standard API response envelope (`data`, `stationClock`, `freshness`, `units`), and serves.

5. **Adding a new marine endpoint requires zero API code changes.** The marine service adds the endpoint to its own codebase and its manifest. On next API restart (or manifest refresh), the new route appears at `/api/v1/`. The dashboard can then call it.

**What this means in practice:**

| Action | Where the change happens | API code changes |
|--------|--------------------------|-----------------|
| Add a new marine endpoint (e.g., `/coral-reef/{id}`) | Marine service only | None — manifest registration handles it |
| Change marine response shape | Marine service only | None — API proxies the response |
| Add a new marine data source provider | Marine service only | None — provider architecture is internal |
| Change cache TTL for a marine endpoint | Marine service manifest | None — API reads TTL from manifest |
| Remove a marine endpoint | Marine service manifest | None — route disappears on next refresh |

**What the API still owns:**
- Response envelope wrapping (`data`, `stationClock`, `freshness`, `units`)
- Unit conversion (the marine service returns SI; the API converts to operator display units)
- Auth/rate-limiting (API middleware applies to proxied routes same as native routes)
- The `/api/v1/capabilities` endpoint (merges marine capabilities into the capability response)
- Setup endpoints for marine config (wizard/admin POST to API, API pushes to marine service)

**This pattern is extensible.** If we build another companion service in the future (say, an air quality modeling service), it uses the same manifest registration. The API becomes a hub that dynamically composes its endpoint surface from its own native endpoints plus registered companion services.

### 5.4 Service-side endpoints

One port. One auth token. One health check.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness, last run time, configured spots, run status (no auth) |
| `/manifest` | GET | Endpoint registration manifest for API dynamic mounting (no auth) |
| `/surf/{location_id}` | GET | Complete surf forecast (auth required) |
| `/surf/{location_id}/profile` | GET | Beach profile (auth required) |
| `/marine/{location_id}` | GET | Marine observations (auth required) |
| `/tides/{location_id}` | GET | Tide predictions and observations (auth required) |
| `/fishing/{location_id}` | GET | Fishing conditions (auth required) |
| `/beach-safety/{location_id}` | GET | Beach safety assessment (auth required) |
| `/config` | POST | Receive config push from API on apply (auth required) |

### 5.5 Data flow

```
External sources (NOAA, NCEI, CO-OPS, etc.)
      ↓ (marine service provider modules fetch independently)
Marine Service
      ↓ SWAN → SwellTrack → SurfBeat → scoring → cache
      ↓ Buoy → tides → marine weather → cache
      ↓
      ↓ HTTP response (complete, scored, ready to display)
      ↓
Clear Skies API
      ↓ dynamically-mounted route (from manifest registration)
      ↓ fetches from marine service, wraps in response envelope
      ↓ applies unit conversion, caching, auth
      ↓
Dashboard (unchanged — calls /api/v1/surf, /api/v1/marine, etc.)
```

### 5.6 Configuration (decided: API pushes on apply)

The wizard and admin talk only to the API. When the operator saves marine config (spots, segments, transects, friction, structures, SurfBeat settings), the API's `/setup/apply` handler POSTs the marine config to the marine service's `/config` endpoint. The marine service stores it locally (its own config file, not `api.conf`) and restarts its run loop.

One source of truth (wizard/admin → API), one push path (API → marine service). The marine service never reads `api.conf`. This matches the existing architecture where the wizard/admin never talks to anything except the API.

---

## 6. What Needs To Be Cleaned Up on weewx

Once the marine service is working standalone:

### Filesystem cleanup:
- `/usr/local/bin/swan.disabled` (was `swan` — remove entirely, SWAN runs on marine service host)
- `/var/run/weewx-clearskies/swan/` (working directory with hotstart files — remove entirely)
- `/etc/weewx-clearskies/swan_bathymetry_*.json` (bathymetry caches — marine service manages its own)
- `/etc/weewx-clearskies/spot_profiles/` (profile caches — marine service manages its own)

### Config cleanup on weewx (`api.conf`):
- Remove `[swan]` section (no longer needed — marine service is a provider, not an embedded component)
- Replace `surf_compute_host` + `service_url` (two keys for two services) with one key: `marine_service_url` in `[providers]`
- Remove `surf_compute_verify_tls` — follow the same TLS pattern as other provider URLs

---

## 7. Wizard/Admin Config Updates

### Current state (works but targets wrong architecture):
- **Wizard step_providers.html:** "Wave Modeling" section with compute host URL + secret + test connection
- **Wizard step_marine.html:** SurfBeat toggle, cadence, per-spot surf config
- **Admin providers section:** Compute host URL + secret update + test connection
- **Admin marine section:** Per-spot SurfBeat, cadence, friction

### What needs to change:
- **Rename** "Wave Modeling" to "Marine Service" (or "Marine Compute Service") in wizard and admin
- **Unify** the two URL fields (`surf_compute_host` + `service_url`) into one: `marine_service_url`
- **Test Connection** button tests the unified marine service health endpoint
- **Config push on apply:** When the operator applies marine config (spots, segments, transects), the API also pushes the config to the marine service (if Option A is chosen)
- **Blank URL = error when marine features enabled.** Unlike the old architecture where blank meant "run in-process," the marine service is required when marine features are enabled. The wizard should validate this.
- **Same-host shortcut:** If the marine service is on the same host as the API, the URL is `https://localhost:{port}`. The wizard could offer a "Same host" toggle that auto-fills this.

---

## 8. What Exists on librewxr That Can Be Reused

### 8.1 SWAN standalone service (`weewx-clearskies-swan` repo)

A working standalone at `/home/ubuntu/repos/weewx-clearskies-swan/`:
- 3 source files: `__init__.py`, `__main__.py`, `service.py` (~350 lines total)
- Runs SWAN via background thread, serves `/health` and `/surf/{id}/forecast`
- Reads `api.conf` for spot config, fetches HRRR/GFS wind, calls `_run_all_spots_locked()`
- This is the **seed** for the marine service — it works, it's deployed, it needs to grow

### 8.2 Compute service (`compute_service.py` in the API repo)

681 lines. Handles SwellTrack/SurfBeat as HTTP endpoints. The code inside (calling `run_pipeline()` and `run_surfbeat_strip()`) gets folded into the marine service's internal pipeline. The HTTP wrapping goes away — SwellTrack and SurfBeat become internal steps, not external endpoints.

### 8.3 All the physics code in the API repo

The 11,397 lines of wave physics code (§4.2) work — they just live in the wrong place. They move to the marine service repo as-is, then get wired into the unified pipeline.

### 8.4 All the provider modules in the API repo

The 9,517 lines of marine data provider code (§4.1) also work. They move to the marine service repo and keep their exact architecture — same CAPABILITY, same `fetch()`, same caching. A developer who's written an API provider can write a marine service provider without learning anything new.

---

## 9. Immediate Actions Taken During This Audit

1. **SWAN binary disabled on weewx:** `sudo mv /usr/local/bin/swan /usr/local/bin/swan.disabled` — prevents new SWAN runs from choking the API. Reversible.

---

## 10. Data Sources — Self-Contained Fetching

The marine service fetches ALL of its inputs directly from public NOAA/NCEI servers. It does NOT query the Clear Skies API for any of them.

| Input | What it is | Source | Protocol |
|-------|-----------|--------|----------|
| HRRR wind (hours 0-48) | 3 km gridded wind forcing | NOAA NOMADS | HTTP (GRIB2) |
| GFS wind (hours 48-72) | 0.25° gridded wind forcing | NOAA NOMADS | HTTP (GRIB2) |
| WW3 boundary spectra | Deep-water wave energy at domain edge | NOAA WaveWatch III | HTTP |
| Bathymetry (3 levels) | Ocean floor depth at 1km/100m/10m | NCEI CUDEM (OPeNDAP) | HTTP, cached to disk |
| Tide predictions | Harmonic tidal water level | NOAA CO-OPS | HTTP API |
| Tide observations | Verified water levels | NOAA CO-OPS | HTTP API |
| Ocean currents | OFS surface U/V velocity | NOAA OFS (OPeNDAP) | HTTP |
| Buoy observations | Wave spectra, met, water temp | NDBC | HTTP |
| Marine weather | Zone forecasts, surf forecasts | NWS | HTTP API |
| Spot configuration | Transects, segments, friction, structures | Local config or API push | File or HTTP |

This self-sufficiency is key to the deployment model. The marine service can run on any host with internet access and a SWAN binary. It doesn't need the API to be reachable to do its work — it only needs the API to consume its output.

---

## 11. Decisions (resolved 2026-07-22)

1. **Repo name: `weewx-clearskies-marine`.** The marine name reflects the full scope — tides, buoy data, fishing, beach safety, surf physics — not just SWAN.

2. **Config model: Option A — API pushes config on apply.** The wizard and admin talk only to the API (existing architecture). When the operator saves marine config, the API's `/setup/apply` handler pushes the marine config to the marine service's `/config` endpoint. One source of truth, one push path. The marine service never needs `api.conf`.

3. **Timeline: Quick patches first, then full separation.** Phase 1: fix the immediate issues (TLS, caching bug) so the existing SWAN service on librewxr feeds data to the API and the surf page works. Phase 2: build the unified marine service with proper architecture. This gets the user-facing surf page functional while the larger separation is planned and executed.

4. **Alerts stay in the API.** Alerts are a core feature, not a marine extension. Marine alerts (coastal flood, high surf, rip current) are part of the unified alert system regardless of whether the marine service is installed. The marine service covers what's defined by the marine page and its tabs — not alerts. Alerts never move.
