# Geographic Features Overlay + Multi-Satellite Compositing — Execution Plan

**Status:** PROPOSED — Pending user review
**Created:** 2026-06-29
**Components:** API (`weewx-clearskies-api`), Dashboard SPA (`weewx-clearskies-dashboard`), LibreWXR fork (`repos/librewxr`, branch `deploy/shaneburkhardt`)

---

## Context

Two independent features address gaps in the satellite/radar map view:

**Feature A — Geographic Features Overlay:** The satellite view needs unfilled vector overlays for political boundaries, major roads, and water features. Free raster tile providers don't offer "lines only on transparent background." The current CSS blend-mode hack (`filter: invert(1) brightness(1.8); mix-blend-mode: multiply` on CartoDB `dark_nolabels` tiles) produces poor results — bleed-through artifacts, washed-out colors, and feature lines that are too faint. The fix: the Clear Skies API queries the Overpass API for OSM vector data within the operator's configured bounds, caches the GeoJSON (90-day TTL), and serves it at a new endpoint. The dashboard renders it as native Leaflet `<GeoJSON>` vector lines — crisp, unfilled, per-feature-type styled.

**Feature B — Multi-Satellite Compositing:** When an operator's BBOX spans a satellite coverage boundary (e.g., GOES-18 disk edge), the satellite view shows a hard cutoff. Currently each satellite provider uses exclusive center-longitude checks to pick one family. The fix: make longitude checks BBOX-edge-aware, enable multiple families when the BBOX spans coverage zones, and composite them per-tile with first-valid-pixel selection.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — build verification, WCAG accessibility
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — system topology, endpoints, config files, caching

**Repos:**
- `weewx-clearskies-api` at `repos/weewx-clearskies-api` — FastAPI backend. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-dashboard` at `repos/weewx-clearskies-dashboard` — React SPA. Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `librewxr` at `repos/librewxr` — LibreWXR fork. Branch: `deploy/shaneburkhardt`. Python 3.12+, pytest.

**Key reference patterns:**
- **Fault line overlay (model for Feature A):** `services/faults.py` (lazy-load GeoJSON, clip to radius, cache in module variable) + `endpoints/earthquakes.py` line 352 (`GET /earthquakes/faults`, returns FeatureCollection with attribution)
- **Dashboard GeoJSON rendering:** `radar-map.tsx` line 921 (`<GeoJSON>` for alert polygons, per-feature styling) + `seismic.tsx` line 341 (`<GeoJSON>` for fault lines, `FAULT_STYLE` static PathOptions, `interactive={false}`)
- **Dashboard data hooks:** `hooks/useWeatherData.ts` line 1018 (`useEarthquakeFaults()` wraps `useApiQuery`) + `api/client.ts` line 176 (`getEarthquakeFaults()`)
- **API caching:** `providers/_common/cache.py` — `CacheBackend` protocol, `MemoryCache`/`RedisCache`, per-entry TTL (arbitrary seconds, supports days/weeks)
- **LibreWXR satellite auto-selection:** `sources/satellite/goes/__init__.py` (center-lon check, -170° to -30°, split at -100°), `sources/satellite/himawari/__init__.py` (60°E to 180°E), `sources/__init__.py` line 203 (`collect_satellite_contributions()`)
- **LibreWXR satellite routing:** `api/routes.py` line 464 (`_find_satellite_sources()` — returns first family only)
- **LibreWXR fetcher:** `data/fetcher.py` lines 370-378 — already handles multiple satellite contributions as independent async tasks

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

---

## 1. Feature Inventory

### A. Geographic Features Overlay (OSM via Overpass API)

| # | Item | Repo | Description |
|---|------|------|-------------|
| A1 | ADR: Geographic features overlay | meta | Architecture decision: Overpass query, caching, endpoint, dashboard rendering |
| A2 | `[geographic_features]` config section | API | New settings: `enabled`, `bounds` (fallback cascade), `refresh_days`, `overpass_endpoint` |
| A3 | Overpass query builder + cache service | API | New `services/geographic_features.py` — builds Overpass QL, fetches, converts to GeoJSON, caches in Redis (90-day TTL) |
| A4 | `GET /api/v1/geographic-features` endpoint | API | Returns cached GeoJSON FeatureCollection with `type` property per feature |
| A5 | Dashboard hook + API client | Dashboard | `useGeographicFeatures()` hook, `getGeographicFeatures()` client function |
| A6 | GeoJSON vector layer in radar-map.tsx | Dashboard | `<GeoJSON>` with per-type styling (boundaries=white, roads=gray, water=blue), replaces CSS hack |
| A7 | Remove CSS blend-mode hack | Dashboard | Remove `.satellite-features` from `index.css`, remove `dark_nolabels` TileLayer from `radar-map.tsx` |
| A8 | Doc updates | meta | ARCHITECTURE.md, PROVIDER-MANUAL.md, DASHBOARD-MANUAL.md |

### B. Multi-Satellite Compositing (LibreWXR)

| # | Item | Repo | Description |
|---|------|------|-------------|
| B1 | ADR: Multi-satellite compositing | meta | Architecture decision: BBOX-edge detection, multi-family rendering, zenith-angle priority |
| B2 | BBOX-edge-aware auto-selection | LibreWXR | Modify GOES + Himawari `satellite_provider()` to check BBOX edges, not just center |
| B3 | `_find_all_satellite_families()` | LibreWXR | New function returning all loaded families (not just first) |
| B4 | `render_multi_satellite_tile()` | LibreWXR | New renderer compositing from multiple source families per-pixel |
| B5 | Satellite tile endpoint + warmer updates | LibreWXR | Use multi-family rendering when available, update cache keys |
| B6 | `LIBREWXR_MULTI_SATELLITE` config flag | LibreWXR | Default True; disables multi-satellite when False |
| B7 | Doc updates | meta + LibreWXR | ARCHITECTURE.md, LibreWXR CLAUDE.md |

### Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| Custom feature type selection in wizard | v0.1 ships sensible defaults; operator customization is v2 |
| Weighted-average blending in satellite overlap zones | First-valid-pixel is sufficient; zenith-weighted blending is a visual refinement for v2 |
| GMGSI as gap-fill in multi-satellite | GMGSI is hourly at 8 km; mixing with 5-min 2 km GOES/Himawari would look jarring |
| Overpass circuit breaker / retry | 90-day cache = ~4 queries/year; not worth complexity |
| GeoJSON simplification (Douglas-Peucker) | Only needed if payloads exceed ~2 MB for large BBOXes |

---

## 2. Implementation Phases

### PHASE 0 — ADRs + Documentation (docs first, no code)

**T0.1 — Draft ADR: Geographic Features Overlay**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-XXX-geographic-features-overlay.md`
- Content: Context (CSS blend-mode hack failure), options (raster providers, CSS tricks, server-side OSM extraction), decision (Overpass → cache → GeoJSON endpoint → Leaflet vector rendering), consequences, implementation guidance (follow faults pattern, 90-day TTL, bounds cascade: explicit > librewxr_bounds > station+radius), acceptance criteria
- Accept: ADR exists with status Proposed

**T0.2 — Draft ADR: Multi-Satellite Compositing**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-XXX-multi-satellite-compositing.md`
- Content: Context (BBOX spanning satellite disk boundary → hard cutoff), options (operator manual config, center-only auto-select [current], BBOX-edge-aware), decision (edge detection + multi-family rendering + first-valid-pixel compositing), consequences (memory +56 MB per family, renderer/router redesign), implementation guidance, acceptance criteria
- Accept: ADR exists with status Proposed

**T0.3 — Update governing documentation**
- Owner: Coordinator (Opus)
- Files:
  - `docs/ARCHITECTURE.md` — add `GET /api/v1/geographic-features` to endpoint groups, add `[geographic_features]` to config table, note multi-satellite in LibreWXR deploy section
  - `docs/manuals/PROVIDER-MANUAL.md` — add Overpass API as data source (keyless, ODbL, 90-day cache)
  - `docs/manuals/DASHBOARD-MANUAL.md` — document geographic features vector layer (replaces CSS hack), conditional rendering (satellite-only), z-index 250
  - `repos/librewxr/CLAUDE.md` — document multi-satellite compositing, BBOX-edge detection, `_find_all_satellite_families()`, `render_multi_satellite_tile()`

**QC (Opus):** Review ADRs against existing code patterns. Verify all doc updates. **User must approve ADRs before Phase 1.**

### PHASE 1 — Geographic Features: API Endpoint

**T1.1 — Config section**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `config/settings.py`
- Do: Add `GeographicFeaturesSettings` class (pattern: `RadarSettings` at line 720):
  - `enabled: bool` (default True)
  - `bounds: str | None` ("south,west,north,east" CSV; fallback to `RadarSettings.librewxr_bounds`, then station lat/lon + `radius_km`)
  - `radius_km: float` (default 200.0, used when no explicit bounds)
  - `refresh_days: int` (default 90)
  - `overpass_endpoint: str` (default `https://overpass-api.de/api/interpreter`)
- Accept: Settings instantiate with defaults. `ruff check` clean.

**T1.2 — Overpass query builder + cache service**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `services/geographic_features.py`
- Do (follow `services/faults.py` pattern):
  - `build_overpass_query(south, west, north, east) → str` — Overpass QL extracting:
    - `relation["boundary"="administrative"]["admin_level"~"2|4"]` (country + state boundaries)
    - `way["highway"~"motorway|trunk|primary"]` (major roads)
    - `relation["natural"="water"]` + `way["waterway"="river"]` (lakes + rivers)
  - `fetch_overpass(query, endpoint) → dict` — HTTP POST, parse, convert OSM elements to GeoJSON FeatureCollection with `type` property per feature (`"boundary"`, `"road"`, `"water"`)
  - `get_geographic_features(settings, radar_settings, station_lat, station_lon) → dict` — cache-first via `get_cache()`:
    - Key: `"geo_features:" + sha256(bounds + feature_types)`
    - TTL: `refresh_days × 86400` seconds
    - On miss: resolve bounds (cascade), build query, fetch, cache
    - On hit: return cached FeatureCollection
- Accept: Returns valid FeatureCollection. Cache hit on second call. `ruff check` clean.

**T1.3 — Endpoint + startup wiring**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: New `endpoints/geographic_features.py`, modify `__main__.py`
- Do: `GET /api/v1/geographic-features` returning `{"data": <FeatureCollection>, "attribution": "© OpenStreetMap contributors (ODbL)"}`. Empty FeatureCollection when disabled. Register router in `__main__.py`.
- Accept: Endpoint accessible. Returns features for configured bounds. `ruff check` + `mypy` clean.

**QC (Opus):** `curl /api/v1/geographic-features` returns valid GeoJSON with boundary/road/water features. Second request is instant (cache hit).

### PHASE 2 — Geographic Features: Dashboard Rendering

**T2.1 — API client + hook + GeoJSON layer**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `api/client.ts`, `hooks/useWeatherData.ts`, `components/shared/radar-map.tsx`, `index.css`
- Do:
  - Add `getGeographicFeatures()` in `client.ts` (pattern: `getEarthquakeFaults()`)
  - Add `useGeographicFeatures()` hook in `useWeatherData.ts` (pattern: `useEarthquakeFaults()`)
  - In `radar-map.tsx`: call hook, add `<GeoJSON>` component when `satelliteActive`:
    - `fill: false` for all features (unfilled lines only)
    - Boundaries: white, weight 1.5, opacity 0.7
    - Roads: gray (#999), weight 1, opacity 0.5
    - Water: blue (#4a90d9), weight 1, opacity 0.6
    - zIndex 250 (above satellite 100, below labels 300)
    - `interactive={false}` (no popups, just visual context)
  - Remove `SATELLITE_FEATURES_URL` constant and its `<TileLayer>` (the `dark_nolabels` + CSS hack)
  - Remove `.satellite-features` class from `index.css`
- Accept: Satellite view shows crisp vector lines. No blend-mode artifacts. `tsc --noEmit` + `vite build` clean.

**QC (Opus):** Visual verify on weather-dev: white boundaries, gray roads, blue water visible on satellite. Not shown on normal basemap view. Labels still render on top.

### PHASE 3 — Multi-Satellite: Auto-Selection + Config (LibreWXR)

**T3.1 — Config flag**
- Owner: `librewxr-dev` (Sonnet)
- File: `config.py`
- Do: Add `multi_satellite: bool = True` to Settings class. `LIBREWXR_MULTI_SATELLITE=false` disables.
- Accept: Config flag works. pytest passes.

**T3.2 — BBOX-edge-aware auto-selection**
- Owner: `librewxr-dev` (Sonnet)
- Files: `sources/satellite/goes/__init__.py`, `sources/satellite/himawari/__init__.py`
- Do: When `settings.multi_satellite` is True, check BBOX west/east edges (not just center longitude):
  - GOES: BBOX spanning -100° → enable BOTH GOES-18 + GOES-19
  - Himawari: BBOX overlapping 60°-180°E → enable Himawari alongside GOES
  - When `multi_satellite` is False: preserve current center-only behavior
- Accept: BBOX spanning -110° to -80° returns contributions for both GOES-18 and GOES-19. pytest passes.

**QC (Opus):** Verify `collect_satellite_contributions()` returns multiple families for boundary-spanning BBOX. Config flag disables correctly.

### PHASE 4 — Multi-Satellite: Rendering + Route Handler (LibreWXR)

**T4.1 — `_find_all_satellite_families()` in routes.py**
- Owner: `librewxr-dev` (Sonnet)
- File: `api/routes.py`
- Do: New function returning `dict[str, tuple[ir, vis]]` for ALL loaded families (not just first). Keep existing `_find_satellite_sources()` for backward compat (timestamp catalog).
- Accept: Returns multiple families when loaded. pytest passes.

**T4.2 — `render_multi_satellite_tile()` in satellite_renderer.py**
- Owner: `librewxr-dev` (Sonnet)
- File: `tiles/satellite_renderer.py`
- Do: New function taking `list[tuple[ir_source, vis_source | None]]`. Per-pixel: sample all sources, use first with data (encoded > 0). In overlap zones, prefer source whose sub-satellite longitude is closest to pixel longitude (proxy for lower zenith angle). Apply same VIS-over-IR composite math as `render_geo_satellite_tile()`.
- Accept: Tile renders with data from multiple families. No seam at coverage boundary. pytest passes.

**T4.3 — Update satellite tile endpoint + warmer**
- Owner: `librewxr-dev` (Sonnet)
- Files: `api/routes.py`, `tiles/warmer.py`
- Do: When multiple families loaded, use `render_multi_satellite_tile()`. Update cache key to include sorted family names. Update `warm_satellite()` to iterate all families.
- Accept: Tiles render without hard cutoff. Cache keys are distinct. Warming logs show multi-family rendering.

**QC (Opus):** Deploy LibreWXR. Verify no hard satellite cutoff (may need temporary BBOX modification to test boundary spanning). pytest passes.

### PHASE 5 — Deploy + End-to-End Verification

**T5.1 — Deploy all three components**
- Deploy API (geographic features endpoint) → verify `curl /api/v1/geographic-features`
- Deploy dashboard (GeoJSON vector layer) → verify satellite view shows vector lines
- Deploy LibreWXR (multi-satellite) → verify no cutoff at boundaries

**T5.2 — End-to-end verification**
- Geographic features: vector lines on satellite, not on basemap, correct per-type styling, ODbL attribution
- Multi-satellite: no hard cutoff (if BBOX spans boundary), single-family BBOX unchanged
- No regressions: radar, alerts, labels, animation all working

**Final QC (Opus):** Walk all acceptance criteria. Verify against both ADRs. Record evidence.

---

## 3. Agent Assignments

| Phase | Tasks | Owner | QC Timing |
|-------|-------|-------|-----------|
| 0 | T0.1-T0.3 ADRs + docs | Coordinator (Opus) | Immediate; user approves ADRs |
| 1 | T1.1-T1.3 API endpoint | `clearskies-api-dev` (Sonnet) | After Phase 1 |
| 2 | T2.1 Dashboard rendering | `clearskies-dashboard-dev` (Sonnet) | After Phase 2 |
| 3 | T3.1-T3.2 LibreWXR auto-selection | `librewxr-dev` (Sonnet) | After Phase 3 |
| 4 | T4.1-T4.3 LibreWXR rendering | `librewxr-dev` (Sonnet) | After Phase 4 |
| 5 | T5.1-T5.2 Deploy + verify | Coordinator (Opus) | After deploy |

**Parallelism:** Phase 1 (API) and Phase 3 (LibreWXR auto-selection) are independent — can run in parallel. Phase 2 depends on Phase 1. Phase 4 depends on Phase 3.

---

## 4. QC Gates

| Gate | Check | When |
|------|-------|------|
| Code Quality | API: `ruff check` + `mypy`. Dashboard: `tsc --noEmit` + `vite build`. LibreWXR: `pytest` + `ruff check`. | Every phase |
| Feature Correctness | Per-phase acceptance criteria verified by coordinator | After each phase |
| ADR Compliance | Both ADRs' acceptance criteria met | After Phase 5 |
| Doc-Code Sync | All governing docs match implementation | After Phase 5 |

---

## 5. Self-Audit

**Risk: Overpass API availability.** 90-day cache = ~4 queries/year. Config allows overriding endpoint to self-hosted instance. On fetch failure, returns empty FeatureCollection (graceful degradation).

**Risk: GeoJSON payload size.** Query filters to admin_level 2/4, motorway/trunk/primary roads, named rivers/lakes only. Typical metro BBOX should be under 2 MB. Douglas-Peucker simplification deferred to v2 if needed.

**Risk: Multi-satellite memory.** +56 MB per additional family. Current SoCal BBOX is entirely within GOES-18 — zero impact. Only activates for boundary-spanning BBOXes. Within 3 GB container budget.

**Risk: Satellite seam at family boundaries.** GOES-18 and GOES-19 are both ABI instruments with same radiometric characteristics — overlap seams should be minimal. First-valid-pixel with longitude-proximity preference handles the transition cleanly.

**Risk: Backward compat of `_find_satellite_sources()`.** Kept unchanged for `/public/weather-maps.json` timestamp catalog. New `_find_all_satellite_families()` is additive.
