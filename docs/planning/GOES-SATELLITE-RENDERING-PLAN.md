# GOES Satellite Rendering Overhaul — Execution Plan

**Status:** COMPLETE — All 5 phases implemented and deployed 2026-06-29. Opaque GOES renderer, route dispatch, satellite tile warming, dashboard basemap swap + radar toggle + 512px tiles + loading indicators + z-order fix, jemalloc memory optimization. Follow-up items (geographic features overlay, multi-satellite compositing) planned in GEO-FEATURES-MULTI-SAT-PLAN.md.
**Created:** 2026-06-29
**Components:** LibreWXR fork (`repos/librewxr`, branch `deploy/shaneburkhardt`), Dashboard SPA (`repos/weewx-clearskies-dashboard`), Clear Skies API (`repos/weewx-clearskies-api` — no changes)
**Target:** Upstream PR to `JoshuaKimsey/LibreWXR` (AGPL-3.0) for LibreWXR changes; dashboard changes are Clear Skies only.

---

## Current State (session context for continuation)

### What happened on 2026-06-29

A deep diagnostic session traced the GOES satellite pipeline end-to-end and found the **data pipeline is fully correct** but the **presentation layer is broken**:

1. **Data pipeline verified correct.** GOES-18 S3 fetch, NetCDF decode, geostationary projection, BBOX crop, pixel sampling — all working. IR data: 98.2% filled (values 0-167, mean 51.5). VIS data: 100% filled (values 5-238, mean 67.8). Every pixel in the SoCal viewport has valid satellite data.

2. **Satellite renderer produces invisible clouds.** The renderer (`satellite_renderer.py`) was designed for GMGSI — a coarse global overlay rendered as semi-transparent RGBA (alpha ~172/255, gray). GOES tiles overlay the OSM basemap at 67% opacity, making clouds nearly invisible. Users expect opaque imagery (white clouds on dark background). Manually decoding the tile PNG confirmed: 100% of pixels have data, mean alpha 172, average RGB (102, 102, 107). The data is correct — the rendering approach is wrong for GOES.

3. **Satellite tiles are NOT pre-warmed.** The tile warmer pre-renders radar tiles but skips satellite entirely. All 1260 satellite tile requests (36 frames × 35 viewport tiles) hit the Python renderer cold, taking 2+ minutes through the Caddy proxy chain.

4. **Dashboard loads ALL satellite frames simultaneously.** `radar-map.tsx` creates a Leaflet TileLayer for every satellite frame at page open. With 36 frames × 35 tiles = 1260 requests (before the 512px optimization).

5. **Memory is 1.6 GB** in a 3 GB container. Tile cache maxed at 200 MB, coord caches at 149 MB, "other" at 846 MB. The satellite data itself is only 56 MB — efficient. The overhead is in caching/coord projections.

### Current repo/branch state

| Repo | Branch | HEAD | State |
|------|--------|------|-------|
| `repos/librewxr` | `deploy/shaneburkhardt` | `96cc9a7` | Deployed to `librewxr` LXD container. GOES-18 IR+VIS source working, BBOX crop active, alert filter active. Satellite renderer produces semi-transparent tiles (wrong for GOES). No satellite warming. |
| `repos/weewx-clearskies-dashboard` | `main` | `a9f0d76` | Deployed to weather-dev. Satellite toggle works but imagery invisible due to renderer. OSM/CartoDB basemap obscures semi-transparent satellite. No `tileSize`/`zoomOffset` on satellite TileLayer. |
| `repos/weewx-clearskies-api` | `main` | — | No changes needed. Satellite frame passthrough already works. |

### Infrastructure state

| System | State |
|--------|-------|
| `librewxr` LXD container (ratbert, 192.168.7.22, VLAN 7) | Running. Docker image `librewxr-bbox:latest` from `deploy/shaneburkhardt`. 3 GB RAM, ~1.6 GB used. GOES-18 IR+VIS ingesting 36 frames each. BBOX `32.0,-120.5,35.5,-114.5`. |
| Caddy on weather-dev | `/librewxr/*` proxies to `http://192.168.7.22:8080`. Working. |
| API on weewx | `[radar] provider = librewxr` configured. Frames endpoint returns 30 radar + 36 satellite frames. |
| Dashboard on weather-dev | Satellite toggle exists. Imagery effectively invisible due to semi-transparent renderer + opaque basemap. |

### SSH access (from project root)

```
ssh -F .local/ssh/config weewx "<cmd>"        # API host
ssh -F .local/ssh/config weather-dev "<cmd>"   # Dashboard/Caddy host
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- <cmd>"  # LibreWXR container
```

### Diagnostic commands (verified working)

```bash
# Check LibreWXR health
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- curl -s http://localhost:8080/health"

# Check satellite frame listing
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- curl -s http://localhost:8080/public/weather-maps.json"

# Fetch a satellite tile (timestamp from health endpoint latest)
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- curl -w 'HTTP:%{http_code} TIME:%{time_total}s SIZE:%{size_download}bytes\n' -s -o /dev/null 'http://localhost:8080/v2/satellite/{timestamp}/256/8/43/103/0/0_0.png'"

# Check container logs
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- docker logs librewxr-librewxr-1 2>&1 | tail -50"

# Check Docker container name
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- docker ps"
```

---

## Context

The GOES-18 satellite data pipeline implemented per the LIBREWXR-SATELLITE-BBOX-PLAN is fully functional — S3 fetch, NetCDF decode, geostationary projection, BBOX crop, and pixel sampling all verified correct. Every pixel in the SoCal viewport has valid data.

The problems are in the **presentation layer**, not the data pipeline:

1. **Invisible clouds.** The satellite renderer (`satellite_renderer.py`) was designed for GMGSI — a coarse global overlay rendered as semi-transparent RGBA (alpha ~172/255, gray). GOES tiles overlay the OSM basemap at 67% opacity, making clouds nearly invisible against the busy map. Users expect opaque satellite imagery (white clouds on dark background) — the standard TV weather satellite look.

2. **2+ minute load time.** The tile warmer pre-renders radar tiles but **skips satellite entirely**. All 1260 satellite tile requests (36 frames × 35 viewport tiles) hit the Python renderer cold. Through the Caddy proxy chain with single-worker uvicorn, this takes 2+ minutes.

3. **Memory bloat.** Tile cache maxed at 200 MB, coordinate caches at 149 MB, total RSS 1.6 GB. The satellite data itself IS efficient (56 MB) — the overhead is in caching and coord projections.

This plan fixes the rendering, adds satellite warming, reduces memory, and updates the dashboard to display satellite tiles properly — all as additive changes to LibreWXR (~150 lines new code), not a rewrite. GMGSI renderer stays untouched for backward compatibility.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety, doc-code sync rules
- `repos/librewxr/CLAUDE.md` — LibreWXR architecture, satellite section, development conventions
- `rules/coding.md` — coding rules

**Key existing code paths (LibreWXR):**
- `src/librewxr/tiles/satellite_renderer.py` — current GMGSI renderer: `render_gmgsi_tile()` (IR-only), `render_gmgsi_composite_tile()` (VIS+IR composite), `_lw_brightness_and_alpha()` (alpha ramp), `_disk_edge_feather()` (latitude edge fade using GMGSI limits ±72.7°), `_pack_rgba()` (RGBA encoding with +5 blue tint)
- `src/librewxr/tiles/warmer.py` — `TileWarmer` class: `warm_latest()` (startup), `warm_overview()` (periodic), `schedule_warm()` (fetcher hook), `_build_tile_lists()` (generates tile coords per zoom), `_submit_compute()` (dispatches to thread pool). Constructor takes `store, cache, executor, enabled_regions, nowcast_store, ecmwf_grid, nwp_chain`. **Radar only — no satellite parameters or code.**
- `src/librewxr/api/routes.py` — `satellite_tile()` endpoint at line 493, `_find_satellite_sources()` at line 462 (groups by family slug suffix: `_ir_grid`, `_lw_grid`, `_vis_grid`), `satellite_grids` module-level dict (populated by `main.py` lifespan). Cache key: `("sat", backing, timestamp, z, x, y, tile_size, ext)`.
- `src/librewxr/sources/satellite/_geo_base.py` — `GeoSatSource` base class (line 38). `sample()` at line 455: forward-projects lat/lon via `geostationary.forward()`, maps to pixel indices via stored x/y coordinate vectors, nearest-neighbor lookup. Returns uint8, 0 = no data.
- `src/librewxr/sources/satellite/goes/source.py` — `GOESSource(GeoSatSource)` at line 50. IR: `_map_to_uint8()` maps Kelvin 170-320 → uint8 cold=high (255), warm=low (0). VIS: reflectance 0-1 → uint8 0-255.
- `src/librewxr/sources/satellite/gmgsi/source.py` — `GMGSIGrid` class (NOT a `GeoSatSource` subclass). `LAT_MAX = 72.7154`, `LAT_MIN = -72.7368` (used by disk-edge feather).
- `src/librewxr/tiles/geostationary.py` — `forward(lat, lon, sat_lon, sat_height)` returns scan angles (radians), NaN for invisible points. `inverse()` also available.
- `src/librewxr/data/fetcher.py` — `_fetch_satellite_background()` at line 380: runs satellite fetch detached from radar cycle, fires `_fire_cycle_complete()` on new frames (line 400). `_schedule_warm()` at line 273: calls `warmer.schedule_warm()` for radar only.
- `src/librewxr/config.py` — Mode defaults at line 17-25: single mode has `tile_cache_mb: 200`, `coord_cache_size: 2048`. Settings: `satellite_max_frames: int = 36`, `warm_overview_zoom: int = 4`, `warm_overview_zoom_regional: int = 6`.

**Key existing code paths (Dashboard):**
- `src/components/shared/radar-map.tsx` — `TILE_CONFIG` at line 327 (light: OSM `tile.openstreetmap.org`, dark: CartoDB `dark_all`). `baseTile` resolved at line 365 via `resolvedTheme` from `useTheme()`. Satellite TileLayer at lines 804-830: maps ALL `satelliteFrames`, creates TileLayer with `zIndex={100}`, `opacity` from `getFrameOpacity()`, URL = `${caddyPrefix}${frame.path}/${RAINVIEWER_TILE_SIZE}/{z}/{x}/{y}/0/0_0.webp`. **No `tileSize` or `zoomOffset` props.** `RAINVIEWER_TILE_SIZE = 512` at line 92 (already in URL, but Leaflet assumes 256px tile area).
- `src/components/shared/radar-layer-panel.tsx` — Satellite toggle checkbox at line 172, shown when `satelliteAvailable=true`.
- `src/routes/radar.tsx` — `showSatellite` state from localStorage key `clearskies-radar-satellite`. Passed as prop to `RadarMap`.

**Governing documents that need updating:**
- `docs/manuals/DASHBOARD-MANUAL.md` §10 lines 746-754 — satellite section still says "NOAA GMGSI composite"
- `docs/ARCHITECTURE.md` line 123 — LibreWXR deploy description
- `repos/librewxr/CLAUDE.md` line 81 — satellite_renderer.py description

**Critical class hierarchy for renderer dispatch:**
- `GeoSatSource` (in `_geo_base.py`) → `GOESSource` → `GOES18IRSource`, `GOES18VISSource`, `GOES19IRSource`, `GOES19VISSource`
- `GeoSatSource` → `HimawariSource` → `Himawari9IRSource`, `Himawari9VISSource`
- `GMGSIGrid` (in `gmgsi/source.py`) — **NOT a GeoSatSource subclass**. `isinstance(source, GeoSatSource)` correctly discriminates.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote. Coordinator pushes after QC.

---

## 1. Feature Inventory

### A. Opaque Satellite Renderer (LibreWXR — new)

| # | Item | Status | Description |
|---|------|--------|-------------|
| A1 | `render_geo_satellite_tile()` function | TODO | New opaque renderer in `satellite_renderer.py`. Alpha=255 for all pixels with data, alpha=0 for no-data. VIS reflectance as grayscale (white clouds, dark ground). IR for night side via existing composite math — just output at full opacity. |
| A2 | Route handler renderer selection | TODO | `satellite_tile()` in `routes.py` detects `GeoSatSource` instances (GOES/Himawari) → calls new opaque renderer. GMGSI sources → existing semi-transparent renderer. |
| A3 | Disk-edge feather for GOES coverage | TODO | Current feather uses GMGSI lat limits (±72.7°). New renderer uses no-data mask (`ir_encoded == 0`) as the disk boundary — alpha=0 for no-data, alpha=255 for data. No separate feather function needed. |

### B. Satellite Tile Warming (LibreWXR — new)

| # | Item | Status | Description |
|---|------|--------|-------------|
| B1 | `warm_satellite()` method on TileWarmer | TODO | New method: iterates satellite timestamps × visible tiles, renders and caches satellite tiles using the existing thread pool. |
| B2 | Warmer receives satellite sources | TODO | Extend `TileWarmer.__init__` to accept `satellite_grids` dict. Wire in `main.py` lifespan. |
| B3 | Fetcher triggers satellite warming | TODO | In `_fetch_satellite_background()`, after new frames are ingested, call `warmer.warm_satellite()` or similar. |

### C. Memory Reduction (LibreWXR — config)

| # | Item | Status | Description |
|---|------|--------|-------------|
| C1 | Reduce tile cache size | TODO | `LIBREWXR_TILE_CACHE_MB` env var in docker-compose. 200 MB → 100 MB. |
| C2 | Reduce coord cache size | TODO | `LIBREWXR_COORD_CACHE_SIZE` env var. 2048 → 512 entries per cache. |

### D. Dashboard Satellite Display (Dashboard — new)

| # | Item | Status | Description |
|---|------|--------|-------------|
| D1 | Basemap swap when satellite active | TODO | When `showSatellite=true`, switch basemap from OSM/CartoDB to CartoDB labels-only overlay (`light_only_labels` / `dark_only_labels`). Transparent background with state boundaries, city names, roads, water labels. |
| D2 | 512px satellite tile optimization | TODO | Add `tileSize={512}` and `zoomOffset={-1}` to satellite TileLayer. Reduces tile requests 4x (same pixel density). |

### E. Documentation Updates (first — per user instruction)

| # | Item | Status | Description |
|---|------|--------|-------------|
| E1 | DASHBOARD-MANUAL.md §10 satellite section | TODO | Update lines 746-754: GOES/Himawari replaces GMGSI, opaque rendering, basemap swap, 512px tiles. |
| E2 | ARCHITECTURE.md LibreWXR deploy | TODO | Update line 123: reflect GOES satellite, tile warming. |
| E3 | LibreWXR CLAUDE.md | TODO | Update satellite_renderer.py description to cover both GMGSI and geo renderers. |

### F. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| GeoColor-like multi-band true color | Requires 6+ bands. Huge scope expansion. Follow-up PR. |
| Satellite frame count reduction | User says: fix rendering first, then decide. |
| Lazy-load satellite frames | Optimization after warming is in place. |
| Static tile file serving via Caddy | Can be added later if warming + cache isn't fast enough. |
| Additional uvicorn workers | Workers replicate entire app state. No memory budget. |

---

## 2. Implementation Phases

### PHASE 0 — Documentation Updates

**T0.1 — Update DASHBOARD-MANUAL.md satellite section**
- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md` lines 746-754
- Do: Replace the "Satellite imagery layer" section. New content: GOES-18/19 (Americas, 2km, 5-min) and Himawari-9 (Asia-Pacific, 2km, 10-min) as primary sources, GMGSI as global fallback. Opaque rendering for GOES/Himawari (white clouds on dark ground, alpha=255 for data pixels). Basemap switches to CartoDB labels-only overlay when satellite is active. 512px tiles with `tileSize={512}` / `zoomOffset={-1}` for 4x fewer requests. Pre-warmed by tile warmer after each ingest.
- Accept: Section accurately describes the planned behavior.

**T0.2 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md` line 123
- Do: Update the "Current LibreWxR deploy" description to mention GOES-18 satellite with opaque rendering and tile warming.
- Accept: Architecture doc reflects current + planned state.

**T0.3 — Update LibreWXR CLAUDE.md**
- Owner: Coordinator (Opus)
- File: `repos/librewxr/CLAUDE.md` line 81
- Do: Update `satellite_renderer.py` description to mention both GMGSI semi-transparent renderer and GOES/Himawari opaque renderer. Mention `isinstance(ir_source, GeoSatSource)` dispatch in routes.py.
- Accept: CLAUDE.md accurately describes the satellite renderer code.

**QC (Opus):** Verify all three docs are consistent with each other and with the planned implementation.

### PHASE 1 — Opaque Satellite Renderer + Route Wiring (LibreWXR)

**T1.1 — Implement `render_geo_satellite_tile()` in satellite_renderer.py**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/tiles/satellite_renderer.py`
- Do: Add new function alongside existing GMGSI functions (which stay untouched). The function:
  1. Samples IR and VIS at tile lat/lon (same `tile_pixel_latlons()` + `source.sample()` pattern)
  2. Computes composite brightness using the same VIS-over-IR math: `out_brightness = vis_brightness * vis_alpha + ir_brightness * (1 - vis_alpha)`. Night side (VIS=0) falls through to IR automatically.
  3. Sets alpha=255 for all pixels with data (`ir_encoded > 0 OR vis_encoded > 0`), alpha=0 for no-data only
  4. No disk-edge feather needed — the no-data mask (`ir_encoded == 0`) already marks the GOES disk boundary cleanly
  5. Builds RGBA: R=G=B=`out_brightness`, A=alpha. No blue tint for opaque satellite tiles.
  6. Returns PNG/WebP via existing `_encode_image()`.
  7. Also add a companion IR-only path for when VIS is unavailable (same function with `vis_source=None` parameter)
- Accept: Rendered satellite tile at zoom 8 over SoCal shows white clouds on dark ground. Alpha is 255 for all data pixels, 0 only for no-data. `python -m py_compile` passes. Existing GMGSI functions unchanged.

**T1.2 — Wire route handler to select renderer by source type**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/api/routes.py`
- Do: In `satellite_tile()` endpoint, after `_find_satellite_sources()` returns the IR source, check `isinstance(ir_source, GeoSatSource)`. If True, call `render_geo_satellite_tile()`. If False (GMGSI), call existing `render_gmgsi_composite_tile()` / `render_gmgsi_tile()`. Import `GeoSatSource` from `librewxr.sources.satellite._geo_base` and `render_geo_satellite_tile` from the renderer module.
- Accept: GOES sources use opaque renderer. GMGSI sources use existing renderer. No behavioral change for GMGSI deployments. `ruff check` clean.

**QC (Opus) — after Phase 1:** Render a satellite tile via `curl` to LibreWXR. Verify: tile is opaque (alpha=255 everywhere except no-data edges). Compare cloud shapes to NOAA GOES imagery for same timestamp. Verify GMGSI path still works (set `LIBREWXR_GOES_ENABLED=false`, confirm semi-transparent GMGSI tiles render).

### PHASE 2 — Satellite Tile Warming + Memory Reduction (LibreWXR)

**T2.1 — Add satellite warming to TileWarmer**
- Owner: `librewxr-dev` (Sonnet)
- Files: `src/librewxr/tiles/warmer.py`, `src/librewxr/main.py`
- Do:
  1. Extend `TileWarmer.__init__` to accept optional `satellite_grids: dict[str, object] | None` and store it.
  2. Add `warm_satellite(timestamps: list[int] | None = None)` method that:
     - Resolves IR+VIS sources from `satellite_grids` (reuse `_find_satellite_sources` logic from routes.py or extract shared helper)
     - Gets satellite timestamps from the IR source
     - Builds tile list using existing `_build_tile_lists()` at `warm_overview_zoom` / `warm_overview_zoom_regional`
     - For each timestamp × tile, checks cache for `("sat", backing, timestamp, z, x, y, 512, "webp")` key
     - If miss, renders via `render_geo_satellite_tile()` (or GMGSI renderer for non-geo sources) in thread pool and caches
     - Runs as async background task (does not block fetcher)
  3. In `main.py` lifespan, pass `satellite_grids=satellite_grids_by_slug` to `TileWarmer` constructor.
- Accept: After a satellite fetch cycle, satellite tiles are pre-rendered for overview zoom levels. Log output shows "Satellite warm: N submitted, M skipped".

**T2.2 — Hook satellite warming to fetch cycle**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/data/fetcher.py`
- Do: In `_fetch_satellite_background()`, after `new_frames` confirmed (line 399-400), call `self._warmer.warm_satellite()` (if warmer is not None). Schedule as `asyncio.create_task()` to avoid blocking the fetch loop.
- Accept: Satellite tiles are warm within seconds of new GOES frames arriving. Browser requests hit cache.

**T2.3 — Reduce tile cache and coord cache defaults**
- Owner: `librewxr-dev` (Sonnet)
- File: Docker compose or env configuration on the `librewxr` LXD container
- Do: Set `LIBREWXR_TILE_CACHE_MB=100` and `LIBREWXR_COORD_CACHE_SIZE=512` in the container's environment.
- Accept: Health endpoint shows `tile_cache.max_mb: 100` and coord cache entries ≤512. Resident memory reduced vs current 1.6 GB baseline.

**QC (Opus) — after Phase 2:** Wait for a GOES ingest cycle. Check logs for "Satellite warm" messages. Request a satellite tile via `curl` — should be an instant cache hit (<5ms). Check `/health` for memory reduction.

### PHASE 3 — Dashboard Basemap Swap + 512px Tiles

**T3.1 — Add labels-only basemap for satellite mode**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Do:
  1. Extend `TILE_CONFIG` with satellite variants:
     - `'satellite-light'`: CartoDB `light_only_labels` (`https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png`)
     - `'satellite-dark'`: CartoDB `dark_only_labels` (`https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png`)
  2. In the basemap selection logic (around line 365), derive the key: if `showSatellite` is true and satellite frames are available, use `satellite-${resolvedTheme}` key; otherwise use `resolvedTheme` key.
  3. CartoDB attribution already present in dark theme config — verify it covers labels-only layers.
- Accept: With satellite enabled, basemap shows only labels/boundaries/roads on transparent background. Satellite tiles visible as the "ground" layer. With satellite disabled, normal OSM/CartoDB basemap. `tsc --noEmit` passes.

**T3.2 — Add tileSize and zoomOffset to satellite TileLayer**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Do: Add `tileSize={512}` and `zoomOffset={-1}` props to the satellite `<TileLayer>` component (around line 812). Radar TileLayer unchanged.
- Accept: At zoom 8, satellite requests use zoom 7 tile coordinates with 512px tiles. Tile request count reduced 4x. Visual quality unchanged. `tsc --noEmit` passes.

**T3.3 — Update DASHBOARD-MANUAL.md if implementation details diverged**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do: If any implementation detail in T3.1/T3.2 diverged from Phase 0's planned description, update the manual to match.
- Accept: Manual matches implementation exactly.

**QC (Opus) — after Phase 3:** `tsc --noEmit` clean. `npm run build` clean. Deploy to weather-dev. Visual verification: satellite enabled shows opaque imagery with labels overlay; satellite disabled shows normal basemap.

### PHASE 4 — Deploy + Final Verification

**T4.1 — Build and deploy LibreWXR**
- Owner: Coordinator (Opus)
- Do: Build Docker image on `librewxr` LXD container from `deploy/shaneburkhardt`. Restart container with `LIBREWXR_TILE_CACHE_MB=100` and `LIBREWXR_COORD_CACHE_SIZE=512`. Wait for GOES ingest + satellite warming cycle.
- Accept: Health endpoint shows GOES channels loaded, tile cache at 100 MB max, satellite tiles pre-warmed.

**T4.2 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: `npm run build` clean. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: Dashboard renders satellite with opaque tiles, labels-only basemap, 512px tiles.

**T4.3 — End-to-end verification**
- Owner: Coordinator (Opus)
- Do: Open `weather.shaneburkhardt.com/radar` with satellite enabled. Verify:
  1. Satellite tiles show opaque imagery (white clouds, dark ground)
  2. Basemap shows only labels/boundaries/roads on transparent background
  3. Cloud shapes match NOAA GOES imagery for same timestamp
  4. Load time under 10 seconds (tiles are pre-warmed)
  5. Animation plays smoothly across 36 frames
  6. Memory under 1.2 GB after 30 minutes of operation (vs 1.6 GB before)
  7. Radar tiles unaffected (same behavior as before)
  8. Satellite toggle off → normal basemap returns
- Accept: All 8 verification points pass.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1-T0.3 Doc updates | Coordinator | Opus | Immediate |
| 1 | T1.1 Opaque renderer | `librewxr-dev` | Sonnet | After Phase 1 |
| 1 | T1.2 Route wiring | `librewxr-dev` | Sonnet | After Phase 1 |
| 2 | T2.1 Satellite warming | `librewxr-dev` | Sonnet | After Phase 2 |
| 2 | T2.2 Fetcher hook | `librewxr-dev` | Sonnet | After Phase 2 |
| 2 | T2.3 Memory reduction | `librewxr-dev` | Sonnet | After Phase 2 |
| 3 | T3.1 Basemap swap | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 3 | T3.2 512px tiles | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 3 | T3.3 Doc sync | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 4 | T4.1-T4.3 Deploy + verify | Coordinator | Opus | After deploy |

**Parallelism:** Phase 1 (LibreWXR renderer) and Phase 3 (Dashboard) can execute in parallel — different repos, different agents. Phase 2 depends on Phase 1.

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- LibreWXR: `ruff check` clean. `python -m py_compile <file>` passes for all modified files.
- Dashboard: `tsc --noEmit` 0 errors. `npm run build` clean.
- SPDX license headers on all new files per LibreWXR convention.

### Gate 2 — Feature Correctness (per phase)
- Phase 1: Opaque satellite tile renders correctly. GMGSI path unbroken.
- Phase 2: Satellite tiles pre-warmed after GOES ingest. Memory reduced.
- Phase 3: Labels-only basemap when satellite active. 4x fewer tile requests.

### Gate 3 — Memory Verification (Phase 4)
- Tile cache ≤ 100 MB. Coord caches ≤ 75 MB. Total RSS < 1.2 GB after 30 minutes.
- No swap usage.

### Gate 4 — Backward Compatibility
- GMGSI renderer untouched — existing `render_gmgsi_tile()` and `render_gmgsi_composite_tile()` produce identical output.
- Default config (no BBOX, no GOES) behaves identically to current upstream.
- `weather-maps.json` format unchanged.
- All existing LibreWXR tests pass.

### Gate 5 — Upstream PR Scope
- LibreWXR changes are additive: new renderer function, new warmer method, route selection by source type.
- No modifications to existing GMGSI code.
- Estimated diff: ~150 lines new code in LibreWXR.
- Dashboard changes are Clear Skies only (not part of upstream PR).

---

## 5. Self-Audit

**Risk: CartoDB labels-only tiles are a third-party dependency.** CartoDB/CARTO provides free tile layers but could change terms or deprecate. Mitigation: Attribution is already included. If CartoDB becomes unavailable, fallback to a transparent Stamen Toner Labels layer or self-hosted vector tiles. Low probability — CartoDB tiles have been stable for 10+ years.

**Risk: Disk-edge feather for geostationary sources.** The existing `_disk_edge_feather()` uses GMGSI lat limits (±72.7°). For the new opaque renderer, we use the no-data mask (`ir_encoded == 0`) directly as the disk boundary — alpha=0 for no-data, alpha=255 for data. This produces a clean hard edge at the GOES disk boundary. If the hard edge is visually jarring, a smoothstep feather can be added in a follow-up by computing angular distance from the sub-satellite point. Start with the simple approach.

**Risk: Tile cache reduction could cause more cache misses.** Reducing from 200 MB to 100 MB means fewer cached tiles. With satellite warming adding tiles to the cache, the effective capacity for radar may decrease. Mitigation: Satellite tiles are typically smaller (WebP ~5-15 KB each). The warmer re-warms on each cycle, so evicted tiles get re-populated. Monitor cache hit rate via `/health` after deploy.

**Risk: `warm_satellite()` competes with radar warming for thread pool.** Both use the same `_executor`. Mitigation: Satellite warm cycles are infrequent (every 10 min) and fast (36 timestamps × ~9-15 tiles at overview zoom = ~324-540 tiles ≈ 30 seconds). Radar warm cycles run at the same cadence. Both complete within a minute — no sustained contention.

**Risk: Warming at overview zoom fills the cache.** At `warm_overview_zoom=4` (256 tiles) × 36 timestamps = 9,216 tiles × ~10 KB = ~92 MB. This would nearly fill the 100 MB cache. Mitigation: Warm satellite tiles only at the zoom levels actually requested by the dashboard (zoom 6-7 after `zoomOffset={-1}` from displayed zoom 7-8). The regional zoom bounds already limit the tile set. If cache pressure is too high, reduce satellite warm scope to latest N timestamps rather than all 36.

**Risk: `isinstance(ir_source, GeoSatSource)` import in routes.py.** Importing `GeoSatSource` in routes.py creates a dependency on the satellite source package. Mitigation: Lightweight import (class reference only). No circular dependency — `GeoSatSource` is in `sources/satellite/_geo_base.py` which has no route-layer dependencies. The module is already loaded when satellite sources are registered at startup.
