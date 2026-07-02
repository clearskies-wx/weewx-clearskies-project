# Geographic Features Overlay: Overpass GeoJSON → PMTiles Vector Tiles — Execution Plan

**Status:** COMPLETE — implemented and deployed 2026-06-29
**Created:** 2026-06-29
**Components:** API (`weewx-clearskies-api`), Dashboard SPA (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`)

---

## Context

The Overpass API approach for geographic features (ADR-078) does not scale. For the current BBOX (14° × 24°, covering SoCal + surrounding states), it produces 125K raw OSM features / 101 MB of GeoJSON that OOM-kills the API during fetch and is too large for the browser to download. Grid subdivision and feature merging brought it to 3,311 features but the response is still 101 MB of coordinate data. Operators with CONUS or Europe BBOXes would be far worse.

**PMTiles** is a single-file archive of pre-processed, zoom-level-simplified vector tiles from OpenStreetMap. The browser loads only the tiles visible in the current viewport via HTTP Range requests — typically 20-50 KB per tile. Geometry is pre-simplified per zoom level (coarse at zoom 5, detailed at zoom 12). This is the industry standard for this exact problem.

**What changes:** The data source changes from live Overpass API queries to a static PMTiles file. The rendering changes from a single GeoJSON blob to on-demand vector tile loading via `protomaps-leaflet`. The API serves the PMTiles file with Range request support. An admin action triggers download and BBOX extraction of the PMTiles data.

**What stays the same:** The visual result (unfilled lines for boundaries, roads, water on the satellite view), the architectural principle (API as single backend), the operator-configurable bounds.

### Current State (session context for continuation)

**What was implemented and needs removal:**
- An Overpass-based geographic features system was built across 3 repos (API service + endpoint + config, dashboard hook + client + GeoFeaturesLayer component). It works for small BBOXes but OOM-kills the API and produces 101 MB responses for the current 14° × 24° BBOX.
- The Overpass code is deployed but non-functional at scale. The Redis cache contains a 101 MB entry that should be cleared.

**BBOX fix also completed this session:**
- LibreWXR `get_bbox()` in `config.py` had a hardcoded 4x expansion — removed. Raw BBOX now means what it says.
- docker-compose.yml BBOX updated from `32.0,-120.5,35.5,-114.5` to `26.75,-129.5,40.75,-105.5` (the actual desired extent).
- LibreWXR rebuilt and redeployed with new BBOX.

**Multi-satellite compositing also completed this session:**
- Phases 3-4 of GEO-FEATURES-MULTI-SAT-PLAN.md landed in LibreWXR: BBOX-edge-aware auto-selection, `_find_all_satellite_families()`, `render_multi_satellite_tile()`, warmer updates. All QC'd and deployed.

**Repo state at session end:**

| Repo | Branch | Latest commit | State |
|------|--------|---------------|-------|
| `weewx-clearskies-api` | `main` | `003bcd1` | Has Overpass code (to be removed). Deployed on weewx. |
| `weewx-clearskies-dashboard` | `main` | `47d2a4e` | Has GeoJSON/GeoFeaturesLayer code (to be removed). Deployed on weather-dev. |
| `weewx-clearskies-stack` | `main` | (unchanged) | No geographic features code yet. |
| `repos/librewxr` | `deploy/shaneburkhardt` | `2b4fa0f` | Multi-satellite + BBOX fix deployed. |
| meta (weather-belchertown) | `main` | `cb3c13b` | ADR-078 (Accepted, needs amendment), ARCHITECTURE.md, manuals updated for Overpass approach (need amendment). |

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — build verification, WCAG accessibility
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — system topology, endpoints, config files, caching
- `docs/manuals/PROVIDER-MANUAL.md` — §9a Geographic Features (to be amended)
- `docs/manuals/DASHBOARD-MANUAL.md` — §10 Radar Card (geographic features section to be amended)

**Repos:**
- `weewx-clearskies-api` at `repos/weewx-clearskies-api` — FastAPI backend. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-dashboard` at `repos/weewx-clearskies-dashboard` — React SPA. Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-stack` at `repos/weewx-clearskies-stack` — Config UI. Branch: `main`.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh` or manual `npm run build` + `rsync`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)
- Config UI: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`

**Key references:**
- ADR-078 (current, to be amended): Geographic features overlay via Overpass
- Protomaps docs: https://docs.protomaps.com/pmtiles/
- protomaps-leaflet: https://github.com/protomaps/protomaps-leaflet (Canvas-based vector tile renderer for Leaflet)
- PMTiles daily builds: https://docs.protomaps.com/basemaps/downloads
- `pmtiles` CLI extract: https://docs.protomaps.com/pmtiles/create

**Existing code to remove (from earlier Overpass implementation):**

API:
- `services/geographic_features.py` (484 lines — Overpass query builder, grid subdivision, feature merge)
- `endpoints/geographic_features.py` (133 lines — GET /geographic-features endpoint)
- `GeographicFeaturesSettings` in `config/settings.py` (lines 789-849 + references at 1347, 1381, 1411-1413, 1439, 1545, 1574)
- Import + router in `app.py` (lines 53, 178)
- Import + wire in `__main__.py` (lines 85, 911)

Dashboard:
- `getGeographicFeatures()` in `api/client.ts` (lines 182-185)
- `useGeographicFeatures()` in `hooks/useWeatherData.ts` (lines 1045-1068 + import line 34)
- `GeoFeaturesLayer` component, `GEO_*_STYLE` constants, `GEO_STYLE_MAP`, `geoFeatures` fetch, conditional render in `radar-map.tsx` (lines 346-393, 464, 944-946)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase. No phase advances until coordinator signs off.

---

## 1. Feature Inventory

### A. Documentation (Phase 0 — before any code)

| # | Item | Description |
|---|------|-------------|
| A1 | Amend ADR-078 | Change data source from Overpass to PMTiles. Status back to Proposed → user approves → Accepted. |
| A2 | Update PROVIDER-MANUAL.md §9a | Replace Overpass data source with PMTiles. Document file format, extraction, admin update mechanism. |
| A3 | Update DASHBOARD-MANUAL.md §10 | Replace GeoJSON vector overlay section with protomaps-leaflet vector tile layer. |
| A4 | Update ARCHITECTURE.md | Replace `/api/v1/geographic-features` endpoint description. Add PMTiles file to config files table. Add `/setup/geographic-features/update` to setup endpoints. |

### B. Remove Overpass Implementation (Phase 1)

| # | Item | Repo | Description |
|---|------|------|-------------|
| B1 | Delete Overpass service + endpoint | API | Remove `services/geographic_features.py`, `endpoints/geographic_features.py` |
| B2 | Remove settings + wiring | API | Remove `GeographicFeaturesSettings` from settings, app.py, __main__.py |
| B3 | Remove dashboard GeoJSON code | Dashboard | Remove client function, hook, GeoFeaturesLayer component, style constants |
| B4 | Clear Redis cache | Deploy | Remove cached Overpass GeoJSON from Redis |
| B5 | Remove `[geographic_features]` from api.conf | Deploy | Clean up config on weewx host |

### C. API: PMTiles Serving + Admin Download (Phase 2)

| # | Item | Repo | Description |
|---|------|------|-------------|
| C1 | PMTiles file serving endpoint | API | `GET /api/v1/geographic-features/tiles` — serves PMTiles file with HTTP Range request support via `FileResponse` |
| C2 | Config section | API | `[geographic_features]` — `enabled` (bool), `bounds` (CSV BBOX for extraction) |
| C3 | Admin download + extract endpoint | API | `POST /setup/geographic-features/update` — downloads Protomaps daily build, extracts to operator BBOX, stores result |
| C4 | Status/info endpoint | API | `GET /api/v1/geographic-features/status` — returns whether PMTiles file exists, size, last-updated timestamp |

### D. Dashboard: protomaps-leaflet Integration (Phase 3)

| # | Item | Repo | Description |
|---|------|------|-------------|
| D1 | Install protomaps-leaflet + pmtiles | Dashboard | npm packages for vector tile rendering |
| D2 | Vector tile layer in radar-map.tsx | Dashboard | Replace GeoFeaturesLayer with protomaps-leaflet layer. Satellite-only. Lines for boundaries (white), roads (gray), water (blue). |
| D3 | Handle missing data gracefully | Dashboard | When PMTiles file not yet downloaded (404), show no overlay — not an error state |

### E. Admin UI: Download Trigger (Phase 4)

| # | Item | Repo | Description |
|---|------|------|-------------|
| E1 | Geographic features section in admin config | Stack | "Map Data" or "Geographic Features" section with Update button |
| E2 | Download progress/status display | Stack | Shows last-updated, file size, download progress |

### F. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| Custom feature type selection | v0.1 ships sensible defaults; operator picks feature types in v2 |
| Self-hosted PMTiles generation from raw OSM | Operator downloads pre-built from Protomaps; custom builds are v2 |
| Multiple PMTiles files per zoom range | Single file with maxzoom sufficient for v0.1 |
| MapLibre GL JS migration | protomaps-leaflet works with existing Leaflet; full MapLibre migration is a separate effort |

---

## 2. Implementation Phases

### PHASE 0 — Documentation (docs first, no code)

**T0.1 — Amend ADR-078: Change data source to PMTiles**
- Owner: Coordinator (Opus)
- File: `docs/decisions/ADR-078-geographic-features-overlay.md`
- Do: Amend the decision. Keep the Context (CSS blend-mode hack failure). Change the Decision from "Overpass → cache → GeoJSON endpoint → Leaflet vector rendering" to "PMTiles static file → API Range-request serving → protomaps-leaflet vector tile rendering." Update Options (add PMTiles as Option D, mark it as chosen; mark Overpass Option C as "rejected — does not scale beyond metro-area BBOXes"). Update Consequences, Acceptance Criteria, Implementation Guidance. Status back to Proposed.
- Accept: ADR exists with amended content and status Proposed. User must approve before Phase 1.

**T0.2 — Update PROVIDER-MANUAL.md §9a**
- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do: Replace Overpass data source section with PMTiles. Document: file format (PMTiles v3, OpenStreetMap data, ODbL license), data source (Protomaps daily builds), extraction (BBOX crop via pmtiles CLI/library), admin update mechanism (`POST /setup/geographic-features/update`), file location (`/etc/weewx-clearskies/geographic-features.pmtiles`). Note: NOT a provider module — utility data source, same as GEM Active Faults.
- Accept: §9a accurately describes PMTiles approach.

**T0.3 — Update DASHBOARD-MANUAL.md §10**
- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do: Replace "Geographic features vector overlay (ADR-078)" section. Document: protomaps-leaflet Canvas-based renderer, vector tile layer from API endpoint, per-type line styling (boundaries white, roads gray, water blue), satellite-only rendering, on-demand tile loading (no upfront fetch), graceful handling when PMTiles not yet downloaded. Remove references to GeoJSON, Overpass, `useGeographicFeatures` hook, `getGeographicFeatures` client function.
- Accept: §10 geographic features section matches the PMTiles approach.

**T0.4 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do: In endpoint groups table, replace `/api/v1/geographic-features` (GeoJSON FeatureCollection) with `/api/v1/geographic-features/tiles` (PMTiles file with Range requests) and `/api/v1/geographic-features/status` (file status). Add `POST /setup/geographic-features/update` to setup endpoints table. Add `geographic-features.pmtiles` to configuration files table. Update `[geographic_features]` config description (remove `refresh_days`, `overpass_endpoint`, `radius_km`).
- Accept: ARCHITECTURE.md reflects PMTiles endpoints, config, and file.

**QC (Opus):** Review all doc changes for consistency. Verify ADR amendment addresses the scaling failure. **User must approve ADR amendment before Phase 1.**

### PHASE 1 — Remove Overpass Implementation

**T1.1 — Remove API Overpass code**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to delete: `services/geographic_features.py`, `endpoints/geographic_features.py`
- Files to modify: `config/settings.py` (remove `GeographicFeaturesSettings` class + all references), `app.py` (remove import + router), `__main__.py` (remove import + wire call)
- Do NOT delete `[geographic_features]` from api.conf — the config section will be repurposed in Phase 2 with different fields.
- Accept: `ruff check` clean (no worse than baseline). API starts without geographic features code. No import errors.

**T1.2 — Remove dashboard GeoJSON code**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify: `api/client.ts` (remove `getGeographicFeatures`), `hooks/useWeatherData.ts` (remove `useGeographicFeatures` hook + import), `components/shared/radar-map.tsx` (remove `GeoFeaturesLayer` component, `GEO_*_STYLE` constants, `GEO_STYLE_MAP`, `geoFeatures` fetch, conditional render, `FeatureCollection` type import if unused)
- Accept: `tsc --noEmit` 0 errors. `vite build` clean. Satellite view renders without geographic features (no lines, no errors).

**T1.3 — Clean up deployed config**
- Owner: Coordinator (Opus)
- Do: Clear Redis geo_features cache on weewx. Remove or comment out `[geographic_features]` section from `/etc/weewx-clearskies/api.conf` on weewx host.
- Accept: No stale Overpass data in Redis. api.conf clean.

**QC (Opus) — after Phase 1:** API starts cleanly. Dashboard satellite view works (no lines, no errors). No references to Overpass, `geographic_features.py`, or `GeoFeaturesLayer` in either repo. `ruff check` + `tsc --noEmit` + `vite build` clean.

### PHASE 2 — API: PMTiles Serving + Admin Download

**T2.1 — PMTiles file serving endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `endpoints/geographic_features.py` (reuse the filename)
- Do: `GET /api/v1/geographic-features/tiles` endpoint. Serves `/etc/weewx-clearskies/geographic-features.pmtiles` using FastAPI's `FileResponse` with `media_type="application/octet-stream"`. Must support HTTP Range requests (Starlette's `FileResponse` handles this natively). Returns 404 with JSON body `{"detail": "Geographic features data not available. Use the admin panel to download map data."}` when file doesn't exist. Public endpoint (no auth).
- Accept: `curl -sk -H "Range: bytes=0-99" https://localhost:8765/api/v1/geographic-features/tiles` returns 206 Partial Content when file exists. Returns 404 when file absent.

**T2.2 — Config section + settings**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `config/settings.py`
- Do: New `GeographicFeaturesSettings` class (simplified from Overpass version): `enabled: bool = True`, `bounds: str | None = None` (CSV BBOX for extraction). Wire into `Settings`, `load_settings()`. No `refresh_days`, `overpass_endpoint`, `radius_km`.
- Accept: Settings load with defaults. Validation passes.

**T2.3 — Admin download + extract endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: New `services/geographic_features.py` (reuse filename), modify `endpoints/geographic_features.py`
- Do: `POST /setup/geographic-features/update` endpoint. Auth: proxy secret (same as other `/setup/*`). Logic:
  1. Download latest Protomaps basemap daily build PMTiles file (planet or latest URL from `https://maps.protomaps.com/builds/`)
  2. Extract to operator BBOX using the `pmtiles` Python package (`pip install pmtiles`) or shell out to the `go-pmtiles` CLI
  3. Apply maxzoom limit (configurable, default 12) to keep file size reasonable
  4. Write result to `/etc/weewx-clearskies/geographic-features.pmtiles`
  5. Return `{"status": "ok", "size_bytes": N, "updated_at": "ISO8601"}`
  - On error: return appropriate error response, don't leave partial files
  - This is a long-running operation (download could be minutes). Consider: (a) synchronous with long timeout, (b) background task with status polling. Start with synchronous for v0.1.
- Accept: `POST /setup/geographic-features/update` downloads, extracts, and stores PMTiles file. Subsequent `GET /api/v1/geographic-features/tiles` serves the file.

**T2.4 — Status endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `endpoints/geographic_features.py`
- Do: `GET /api/v1/geographic-features/status` — returns `{"available": bool, "size_bytes": int|null, "updated_at": "ISO8601"|null}`. Checks if PMTiles file exists.
- Accept: Returns correct status before and after download.

**T2.5 — Wire router + settings in app.py and __main__.py**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `app.py`, `__main__.py`
- Do: Register geographic features router (data endpoints in configured mode, setup endpoint in setup mode). Wire settings.
- Accept: All endpoints accessible. `ruff check` clean.

**QC (Opus) — after Phase 2:**
- Verify `POST /setup/geographic-features/update` successfully downloads and stores PMTiles file (test on weewx host)
- Verify `GET /api/v1/geographic-features/tiles` serves Range requests (206 Partial Content)
- Verify `GET /api/v1/geographic-features/status` returns correct metadata
- Verify 404 when file doesn't exist
- `ruff check` clean
- Monitor memory during download — must not OOM the API

### PHASE 3 — Dashboard: protomaps-leaflet Integration

**T3.1 — Install npm packages**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: `npm install protomaps-leaflet pmtiles`
- Accept: Packages in package.json. `npm run build` still succeeds.

**T3.2 — Vector tile layer in radar-map.tsx**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `components/shared/radar-map.tsx`
- Do: When `satelliteActive`, add a protomaps-leaflet vector tile layer pointing at `/api/v1/geographic-features/tiles`. Style rules:
  - Boundaries (admin level 2/4): white (#ffffff), weight 1.5, opacity 0.7, no fill
  - Roads (motorway, trunk): gray (#999999), weight 1, opacity 0.5, no fill
  - Water (rivers, lakes): blue (#4a90d9), weight 1, opacity 0.6, no fill
  - All other features: hidden (no labels, no buildings, no landuse — lines only)
- Use a `useEffect` + `useMap()` pattern (same as the `GeoFeaturesLayer` component we're removing, but with protomaps-leaflet instead of L.geoJSON)
- Check `/api/v1/geographic-features/status` first — if not available, don't add the layer (no error state)
- Accept: Satellite view shows crisp vector lines for boundaries, roads, water. Lines render at appropriate detail per zoom level. No lines on normal basemap view. `tsc --noEmit` + `vite build` clean.

**T3.3 — Verify color tuning against satellite imagery**
- Owner: Coordinator (Opus)
- Do: Visual QC of line colors against real satellite tiles. Adjust colors if needed — values are starting points per ADR-078.
- Accept: Lines visible but not overpowering on satellite imagery.

**QC (Opus) — after Phase 3:**
- Visual verify: vector lines on satellite view at multiple zoom levels
- Verify no lines on normal basemap view
- Verify graceful handling when PMTiles not downloaded (no error, just no lines)
- Verify tile loading is fast (on-demand per viewport, not upfront bulk)
- `tsc --noEmit` + `vite build` clean
- Check against DASHBOARD-MANUAL.md §10 requirements

### PHASE 4 — Admin UI: Download Trigger

**T4.1 — Geographic features section in admin config**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: Modify admin routes + templates in `weewx_clearskies_config/config/`
- Do: Add "Geographic Features" or "Map Data" section to admin config page. "Update Map Data" button that calls `POST /setup/geographic-features/update`. Shows current status (available/not, file size, last updated) from `GET /api/v1/geographic-features/status`. Download progress indicator (loading spinner during the synchronous download). Success/error feedback after completion.
- Accept: Admin page shows geographic features section. Button triggers download. Status updates after completion.

**QC (Opus) — after Phase 4:**
- Full end-to-end test: admin button → download → verify PMTiles file → dashboard shows lines
- Verify re-download (update) works — replaces existing file
- Templates render without Jinja2 errors

### PHASE 5 — Deploy + Final Verification

**T5.1 — Deploy all three components**
- Owner: Coordinator (Opus)
- Do: Push all repos. Deploy API (pull + restart on weewx). Deploy dashboard (pull + build + rsync on weather-dev). Deploy config UI (restart on weather-dev). Trigger geographic features download via admin UI.
- Accept: Geographic features visible on satellite view on `https://weather-test.shaneburkhardt.com/radar`.

**T5.2 — End-to-end verification**
- Geographic features: vector lines on satellite view covering full BBOX
- Lines render at appropriate detail for each zoom level (coarse at zoom 5, detailed at zoom 12)
- No Overpass dependency — feature works entirely from local PMTiles file
- No OOM, no 100 MB responses — tiles loaded on demand (~20-50 KB each)
- Admin UI can trigger re-download to refresh OSM data
- No regressions: radar, alerts, labels, animation all working

**Final QC (Opus):** Walk all acceptance criteria. Verify against amended ADR-078 and updated manuals. Record evidence.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1-T0.4 ADR amendment + manual updates | Coordinator | Opus | Immediate; user approves ADR |
| 1 | T1.1 Remove API Overpass code | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.2 Remove dashboard GeoJSON code | `clearskies-dashboard-dev` | Sonnet | After Phase 1 |
| 1 | T1.3 Clean up deployed config | Coordinator | Opus | After Phase 1 |
| 2 | T2.1-T2.5 PMTiles serving + admin download | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 3 | T3.1-T3.2 protomaps-leaflet integration | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 3 | T3.3 Color tuning | Coordinator | Opus | After Phase 3 |
| 4 | T4.1 Admin UI section | `clearskies-stack-dev` | Sonnet | After Phase 4 |
| 5 | T5.1-T5.2 Deploy + verify | Coordinator | Opus | After deploy |

**Parallelism:** Phase 1 tasks T1.1 (API) and T1.2 (dashboard) are independent — can run in parallel. Phase 2 and Phase 3 are sequential (dashboard needs the API endpoint). Phase 4 can run in parallel with Phase 3 (admin UI only needs the API endpoint, not the dashboard).

---

## 4. QC Gates

| Gate | Check | When |
|------|-------|------|
| Code Quality | API: `ruff check` + no new `mypy` errors. Dashboard: `tsc --noEmit` + `vite build`. Stack: `python -m py_compile`. | Every phase |
| Manual Compliance | Implementation matches PROVIDER-MANUAL §9a, DASHBOARD-MANUAL §10, ARCHITECTURE.md | After each phase |
| ADR Compliance | ADR-078 acceptance criteria met | After Phase 5 |
| Feature Correctness | Per-phase acceptance criteria verified by coordinator | After each phase |
| Doc-Code Sync | All governing docs match implementation | After Phase 5 |

---

## 5. Open Research Questions

These must be resolved during Phase 0 or early Phase 2:

1. **Protomaps daily build download URL** — exact URL for the latest planet PMTiles. Docs say `maps.protomaps.com/builds/` — verify the download mechanism and file naming.

2. **PMTiles extraction tool** — Python `pmtiles` package (`pip install pmtiles`) vs Go `go-pmtiles` CLI binary. Which is available/practical on the weewx host? Can the Python package do BBOX extraction with maxzoom limit?

3. **Regional extract file size** — what does a 14° × 24° extract at maxzoom 10-12 look like? Must be manageable for the API to serve via Range requests and for disk.

4. **protomaps-leaflet styling** — how to render lines-only (boundaries, roads, water) without a full basemap (no labels, no buildings, no landuse). Need to understand the styling/theming API for selective layer rendering.

5. **Range request compatibility** — verify FastAPI/Starlette `FileResponse` handles the specific Range request patterns that the PMTiles JavaScript client sends (multi-range? single-range?).

---

## 6. Self-Audit

**Risk: Download size.** The full planet PMTiles is ~120 GB. The extraction step must handle streaming download or downloading only the needed region. Mitigation: use `pmtiles extract` with a remote URL — it reads only the necessary byte ranges from the source file, not the whole planet. Verify this works with the Protomaps CDN.

**Risk: protomaps-leaflet maintenance mode.** The library is in maintenance mode — Protomaps recommends MapLibre GL JS for new projects. However, protomaps-leaflet is stable, our use case is simple (lines-only overlay, not a full basemap), and it works with existing Leaflet. Switching to MapLibre would require replacing the entire MapContainer — a much larger effort deferred to v2.

**Risk: API serving large file.** The PMTiles file could be 50-200 MB on disk. FastAPI's `FileResponse` serves it via Range requests (20-50 KB per tile request), so the API never loads the full file into memory. Verify Starlette's Range handling is correct for this access pattern.

**Risk: Admin download duration.** Downloading and extracting PMTiles could take minutes. The synchronous approach means the admin UI's HTTP request hangs during download. For v0.1 this is acceptable (it's a one-time operation, admin can wait). v2 could add background task + polling.

**Risk: Backward compat.** Removing the Overpass endpoint is a breaking change for any dashboard version that still calls `GET /api/v1/geographic-features`. Since dashboard and API are deployed together, this is acceptable — there are no external consumers.
