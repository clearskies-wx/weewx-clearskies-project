# Satellite Display Performance & Animation Cadence Fix — Execution Plan

**Status:** APPROVED — Ready for implementation
**Created:** 2026-06-30
**Components:** LibreWXR fork (`repos/librewxr`, branch `deploy/shaneburkhardt`), Dashboard SPA (`repos/weewx-clearskies-dashboard`), Infrastructure (LXD container `librewxr`)

---

## Context

The expanded radar view (`/radar`) has unpredictable animation cadence when satellite imagery is enabled — some frames lag, then 1–3 frames speed through to catch up. Additionally, LibreWXR tile serving is inconsistent — sometimes 30 frames arrive quickly, sometimes a single frame takes 30–60 seconds followed by a long pause then a chunk.

Root-cause investigation traced the full pipeline (LibreWXR S3 fetch → tile rendering → tile cache → Caddy proxy → dashboard animation) and identified these **verified** issues:

1. **Satellite tile warmer warms the wrong zoom level.** The warmer covers zoom 0–6 (`warm_overview_zoom_regional=6` default), but the dashboard requests z=7 tiles (displayed zoom 8 with `tileSize=512, zoomOffset=-1`). First access to z=7 satellite tiles takes **400–540ms** vs **1.5ms** for warmed z=6 tiles. **Verified via curl timing tests.**

2. **No demand-driven satellite warming.** Radar tiles trigger `tile_warmer.warm()` on every cache miss, pre-rendering all other timestamps at the same (z,x,y). Satellite tiles do NOT — they only warm in batch after each 10-minute fetch cycle. **Verified by reading routes.py: radar endpoint calls `tile_warmer.warm()` at line 405; satellite endpoint does not.**

3. **Nowcast frames animate alongside satellite.** The radar animation includes 30 frames (24 past + 6 nowcast) while satellite has 24 frames. Both animate simultaneously at different tick rates via an accumulator pattern: radar at ~113ms/substep, satellite at ~142ms/substep. The accumulator creates an irregular 3:1 advance/skip cadence — satellite advances 3 ticks then skips 1, producing visible stutter. **Verified by reading radar-map.tsx animation timer (lines 857–914).**

4. **LAYER_BUFFER causes DOM mount/unmount churn.** During playback, frames outside ±3 of the current position are unmounted by React (`return null`), destroying `<img>` DOM elements. When they re-enter the window, Leaflet creates new elements. The LAYER_BUFFER was added (commit `6758347`) based on a claim that Leaflet's `will-change: opacity` on tiles caused GPU compositor overload. **Research debunked this:** Leaflet removed `will-change` from tile images in v1.8.0 ([PR #7872](https://github.com/Leaflet/Leaflet/releases/tag/v1.8.0)); we run **v1.9.4**. The problem the LAYER_BUFFER was solving doesn't exist in our version. Additionally, the `display: none` toggling used to hide inactive layers is expensive — [MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/display) states "unhiding is as expensive as rendering a new element." We toggle this 2× per animation tick.

5. **No client-side tile prefetching.** Satellite tiles are static URLs at known timestamps. The browser should prefetch all tile URLs into its HTTP cache before animation starts. We don't do this. [Leaflet community](https://github.com/Leaflet/Leaflet/discussions/9333) confirms manual prefetching is the key solution for animated tile playback. [MDN](https://developer.mozilla.org/en-US/docs/Web/HTML/Preloading_content) confirms `new Image().src = url` populates the browser cache for later `<img>` reuse.

6. **Cache-Control headers too short for immutable content.** Past satellite tiles (deterministic URLs, data never changes) use `max-age=7200` (2 hours). Should use `max-age=31536000, immutable` so the browser never revalidates. **Verified via curl:** `Cache-Control: public, max-age=300` on latest, `max-age=7200` on older timestamps.

7. **VIS channels download 0.5km data and downsample to 2km.** IR provides sufficient all-weather satellite imagery. VIS only adds daytime cloud edge detail and is all-zeros at night. Disabling VIS eliminates 2 S3 fetch channels and reduces per-tile render cost.

8. **LXD container CPU limit.** Container has `limits.cpu=8`; host has 32 cores. `LIBREWXR_WARMER_THREADS=7` is explicitly set. Removing the CPU limit and auto-detecting threads lets burst rendering use idle cores.

**What is NOT the problem:**
- **Cache eviction:** tile cache is at 144.4/400 MB (36%) — no eviction pressure.
- **GOES-19 being loaded:** both GOES-18 and GOES-19 are REQUIRED for full BBOX coverage. GOES-18 covers 91%, GOES-19 covers 74%. The 9% not covered by GOES-18 must come from GOES-19. A grey void is unacceptable.
- **Thread starvation from S3 fetches:** 32 CPUs visible to Docker → 31-thread pool. 4 satellite fetches every 10 min is negligible.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — build verification, WCAG accessibility
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — system topology, endpoints, config files, caching
- `docs/manuals/DASHBOARD-MANUAL.md` — §10 Radar Card & Expanded View (satellite section lines 746–759)
- `repos/librewxr/CLAUDE.md` — LibreWXR architecture, satellite section

**Repos:**
- `weewx-clearskies-dashboard` at `repos/weewx-clearskies-dashboard` — React SPA. Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `librewxr` at `repos/librewxr` — LibreWXR fork. Branch: `deploy/shaneburkhardt`. Python 3.12+, pytest.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- LibreWXR: Rebuild Docker image on `librewxr` LXD container, restart container.
- SSH: `ssh -F .local/ssh/config weewx "<cmd>"`, `ssh -F .local/ssh/config weather-dev "<cmd>"`, `ssh -F .local/ssh/config ratbert "lxc exec librewxr -- <cmd>"`

**Key code paths (LibreWXR — `repos/librewxr/src/librewxr/`):**
- `tiles/warmer.py` line 363 — `warm_satellite()`: batch satellite warming, uses `warm_overview_zoom_regional` (default 6)
- `tiles/warmer.py` line 165 — `warm()`: radar demand-driven warming — satellite has NO equivalent
- `api/routes.py` line 528 — `satellite_tile()`: endpoint, uses `_find_all_satellite_families()` for multi-satellite compositing
- `api/routes.py` line 398–414 — radar tile endpoint triggers `tile_warmer.warm()` after cache miss; satellite does NOT
- `api/routes.py` line 643 — `max_age = 7200` for past satellite tiles (should be immutable)
- `tiles/satellite_renderer.py` line 199 — `render_multi_satellite_tile()`: per-pixel compositing, has fast path for single-source tiles (line 243)
- `config.py` line 69–70 — `warm_overview_zoom=4`, `warm_overview_zoom_regional=6` defaults

**Key code paths (Dashboard — `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`):**
- Line 74–78 — `LAYER_BUFFER = 3` constant (to be removed)
- Line 544–550 — `frames` derivation includes ALL radar frames (past + nowcast)
- Line 566 — `satelliteActive` derivation
- Line 671 — `frameCount = frames.length` (includes nowcast)
- Line 691–705 — `applyRadarStep`: sets opacity + toggles `display: none`/`display: ''`
- Line 857–914 — animation timer: radar tick + satellite accumulator with independent rates
- Line 948 — `nowcastStartIndex` identifies nowcast boundary
- Line 1037–1049 — stale comment claiming "all TileLayers rendered simultaneously" (no longer true with LAYER_BUFFER)
- Line 1051–1059 — `<MapContainer>` (no `preferCanvas`)
- Line 1087–1091 — satellite LAYER_BUFFER guard: `if (isPlaying && satDist > LAYER_BUFFER) return null`
- Line 1110–1113 — radar LAYER_BUFFER guard: `if (isPlaying && radarDist > LAYER_BUFFER) return null`

**Current deployed LibreWXR environment (`librewxr` LXD container):**
```
LIBREWXR_BBOX=26.75,-129.5,40.75,-105.5
LIBREWXR_SATELLITE_MAX_FRAMES=24
LIBREWXR_TILE_CACHE_MB=400
LIBREWXR_WARMER_THREADS=7
LIBREWXR_FETCH_INTERVAL=600
LIBREWXR_NOWCAST_ENABLED=true
LIBREWXR_COORD_CACHE_SIZE=512
LIBREWXR_WORKERS=1
# warm_overview_zoom_regional NOT set — defaults to 6
# GOES_VIS_ENABLED NOT set — defaults to true
# MULTI_SATELLITE NOT set — defaults to true
```

**Leaflet version:** 1.9.4 (confirmed via `node_modules/leaflet/package.json`)

**Test hardware:** ASUS Zenbook 14 OLED 3404, Intel integrated GPU (Iris Xe), shared VRAM.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

---

## 1. Feature Inventory

### A. LibreWXR: Satellite Tile Warming Fix

| # | Item | Description |
|---|------|-------------|
| A1 | Increase satellite warm zoom | Set `LIBREWXR_WARM_OVERVIEW_ZOOM_REGIONAL=7` to cover z=7 tiles the dashboard requests |
| A2 | Add demand-driven satellite warming | New `warm_satellite_demand()` in warmer.py — on satellite tile cache miss, pre-render all other timestamps at the same (z,x,y). Same pattern as radar's `warm()` (line 165) |
| A3 | Immutable Cache-Control on past satellite tiles | Change `max-age=7200` to `max-age=31536000, immutable` for non-latest timestamps. Latest keeps `max-age=300` |

### B. Dashboard: Animation Fixes

| # | Item | Description |
|---|------|-------------|
| B1 | Filter nowcast from radar animation when satellite active | When `satelliteActive`, exclude `kind === 'nowcast'` frames. Equalizes frame counts (both 24), eliminates accumulator cadence mismatch |
| B2 | Remove LAYER_BUFFER + use `visibility: hidden` | Mount all layers permanently. Replace `display: none` toggling with `visibility: hidden`/`visible`. **Research basis:** (1) Leaflet 1.9.4 has no `will-change: opacity` on tiles — LAYER_BUFFER premise is moot. (2) `display: none` toggling is expensive per MDN. (3) `opacity: 0` creates stacking contexts, Firefox still composites them. `visibility: hidden` avoids all three — no stacking context, no paint, cheap toggle, cross-browser safe |
| B3 | Client-side tile prefetching | On frame list arrival, `new Image().src = url` for all tile URLs at current viewport zoom. MDN-confirmed: populates browser HTTP cache for later `<img>` reuse |
| B4 | `preferCanvas` on MapContainer | Add `preferCanvas={true}`. Only affects vector overlays (alert polygons, GeoJSON, CircleMarker) — NOT tile animation. Minor optimization |
| B5 | Update stale code comment | Lines 1037–1049: describe all-layers-mounted + visibility + prefetch strategy |

### C. Config Changes

| # | Item | Description |
|---|------|-------------|
| C1 | Disable GOES VIS download | `LIBREWXR_GOES_VIS_ENABLED=false`. IR sufficient. Renderer handles `vis_source=None` gracefully |
| C2 | Remove LXD CPU limit | `lxc config unset librewxr limits.cpu`. Linux CFS handles fair sharing |
| C3 | Auto-detect warmer threads | Unset `LIBREWXR_WARMER_THREADS`. Auto-sizes to available CPUs |

### D. Documentation Updates (docs first, before code)

| # | Item | Description |
|---|------|-------------|
| D1 | DASHBOARD-MANUAL.md §10 | Add: nowcast excluded when satellite active. Update: pre-warming covers dashboard viewport zoom. Add: VIS disabled by default. Add: tile prefetching + visibility strategy. Add: `preferCanvas` |
| D2 | ARCHITECTURE.md LibreWXR deploy section | Update: warm zoom 7, VIS disabled, demand-driven satellite warming |
| D3 | LibreWXR CLAUDE.md | Add: demand-driven satellite warming, VIS disabled in deploy |

### Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| Multi-satellite compositing optimization (per-tile source selection) | Both satellites required; compositing runs server-side and tiles are cached. Refinement after core fixes land |
| Satellite selection logic replacement (`bbox_overlaps_disk` → coverage-fraction) | Current selection correctly identifies both required satellites. Future enhancement |
| Synchronized radar+satellite animation (matching timestamps) | Frame count equalization (nowcast removal) addresses the cadence issue |

---

## 2. Implementation Phases

### PHASE 0 — Documentation Updates (docs first, no code)

**T0.1 — Update DASHBOARD-MANUAL.md §10 satellite section**
- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md` lines 746–759
- Do:
  - After line 749 add: "When satellite is active, nowcast (radar extrapolation) frames are excluded from the radar animation — only past/current radar frames animate alongside satellite. This ensures both layers have matching frame counts and consistent animation cadence."
  - Update line 756: "pre-renders satellite tiles at zoom levels matching the dashboard viewport (configured via `warm_overview_zoom_regional`) after each ingest cycle. On cache miss, demand-driven warming pre-renders all timestamps at the same tile coordinate."
  - Add: "Default configuration: IR-only (VIS disabled). IR provides all-weather satellite imagery at 2 km resolution. VIS can be enabled via `LIBREWXR_GOES_VIS_ENABLED=true` for daytime cloud edge detail."
  - Add: "All tile layers remain mounted during animation with `visibility: hidden` on inactive frames (no mount/unmount churn). Client-side tile prefetching via `new Image()` populates browser cache before animation starts."

**T0.2 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md` line 123 (LibreWXR deploy paragraph)
- Do: Add: "Satellite tile warmer covers zoom 0–7 (matching dashboard `tileSize=512, zoomOffset=-1`). VIS channels disabled (`GOES_VIS_ENABLED=false`). Demand-driven satellite warming pre-renders all timestamps at a tile coordinate on first cache miss."

**T0.3 — Update LibreWXR CLAUDE.md**
- Owner: Coordinator (Opus)
- File: `repos/librewxr/CLAUDE.md`
- Do: Update satellite/warmer sections to note demand-driven satellite warming and VIS disabled in deploy.

**QC (Opus):** All three docs consistent with each other and with the planned implementation.

### PHASE 1 — LibreWXR: Satellite Warming Fix + Cache Headers

**T1.1 — Add demand-driven satellite warming**
- Owner: `librewxr-dev` (Sonnet)
- Files: `src/librewxr/tiles/warmer.py`, `src/librewxr/api/routes.py`
- Do:
  1. In `warmer.py`, add `warm_satellite_demand(timestamp, z, x, y, tile_size, fmt)` — iterates ALL satellite timestamps at (z,x,y), renders uncached ones. Same pattern as `warm()` (line 165–224). Uses warmer's `_executor`. The multi-satellite renderer's fast path (line 243) handles single-source tiles automatically.
  2. In `routes.py` `satellite_tile()`, after cache miss + render (around line 640), call `tile_warmer.warm_satellite_demand()` via `asyncio.ensure_future()` — same as radar's `tile_warmer.warm()` call (line 405).
- Accept: After first satellite tile at (z,x,y), all other timestamps warmed in background. `ruff check` clean.

**T1.2 — Immutable Cache-Control on past satellite tiles**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/api/routes.py`
- Do: Line 643 — change `max_age = 7200` to `max_age = 31536000` for non-latest timestamps. Line 646 — use `f"public, max-age={max_age}, immutable"` for past frames, `f"public, max-age={max_age}"` (no immutable) for latest.
- Accept: `curl` non-latest tile → `Cache-Control: public, max-age=31536000, immutable`. Latest → `max-age=300`. `ruff check` clean.

**T1.3 — Increase warm zoom config**
- Owner: Coordinator (Opus)
- Do: Add `LIBREWXR_WARM_OVERVIEW_ZOOM_REGIONAL=7` to LibreWXR `.env`.
- Accept: After rebuild, satellite warm logs show zoom 7 tiles.

**QC (Opus):** curl satellite tile at z=7 → <5ms (warmed). Verify Cache-Control headers. Verify z=6 still warmed.

### PHASE 2 — Dashboard: Animation + Tile Performance

**T2.1 — Filter nowcast when satellite active**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Do:
  1. After `frames` derivation (line 544–550), when `satelliteActive` is true, filter to exclude `kind === 'nowcast'`.
  2. Ensure `frameCount` is derived AFTER filter.
  3. `nowcastStartIndex` (line 948) naturally returns -1 when no nowcast → FrameProgressBar handles correctly (line 255).
- Accept: Satellite on → 24 radar frames, 24 satellite, same tick rate. Satellite off → 30 frames (past + nowcast). `tsc --noEmit` + `vite build` clean.

**T2.2 — Remove LAYER_BUFFER, use `visibility: hidden`**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Research basis:
  - Leaflet 1.9.4 has NO `will-change: opacity` on tiles (removed v1.8.0 [PR #7872](https://github.com/Leaflet/Leaflet/releases/tag/v1.8.0)). LAYER_BUFFER premise is moot.
  - `display: none` unhiding "as expensive as rendering a new element" ([MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/display)). We toggle 2×/tick.
  - `opacity: 0` creates stacking contexts; Firefox composites them ([MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/opacity)).
  - `visibility: hidden`: no stacking context, no paint, cheap toggle, cross-browser safe.
- Do:
  1. Remove LAYER_BUFFER guards at lines 1091 and 1113. Keep all TileLayer components mounted always.
  2. In `applyRadarStep` (691–705) and `applySatStep` (707–719): replace `display: none`/`display: ''` with `visibility: hidden`/`visibility: visible`. Use `visibility: hidden` for inactive, `visibility: visible` + `setOpacity(value)` for active cross-fading layers.
  3. Remove `LAYER_BUFFER` constant (line 74–78) and `satDisplayIdx` computation (line 1087–1088).
  4. Rename preload threshold (line 813 `2 * LAYER_BUFFER + 1`) to `PRELOAD_FRAME_COUNT = 7`.
- Verify: Profile with Chrome DevTools Performance tab. Confirm no layout thrash, consistent frame timing.
- Accept: All layers mounted permanently. `visibility: hidden` on inactive. Zero tile re-fetches during animation loop. `tsc --noEmit` clean.

**T2.3 — Client-side tile prefetching**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Do:
  1. Add useEffect that runs when frame list arrives.
  2. For each frame (radar + satellite), compute tile URLs for current viewport at current zoom.
  3. Prefetch via `new Image().src = url`.
  4. Run before `isPlaying` is set to true.
- Accept: Network tab shows prefetch on load. After first loop, tiles from memory cache. `tsc --noEmit` clean.

**T2.4 — `preferCanvas` on MapContainer**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: Add `preferCanvas={true}` to `<MapContainer>` (line 1051). Only affects vector layers — not tile animation.
- Accept: Alert polygons + GeoFeaturesLayer still render. `tsc --noEmit` clean.

**T2.5 — Update stale code comment**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do: Update lines 1037–1049 to describe: all layers mounted, `visibility: hidden` for inactive, prefetch on load. Cite Leaflet 1.9.4 `will-change` removal.

**QC (Opus):** `tsc --noEmit` + `vite build` clean. Deploy to weather-dev. Verify:
1. Satellite on → smooth cadence, no stutter
2. Satellite off → nowcast visible, accent-color progress bar segment
3. Frame count: 24 with satellite, 30 without
4. Network: zero re-fetches during loop; prefetch visible on load
5. No `display: none` toggling during animation
6. Chrome DevTools Performance: no layout thrash

### PHASE 3 — Config Changes: VIS + Infrastructure

**T3.1 — Disable VIS channels**
- Owner: Coordinator (Opus)
- Do: Add `LIBREWXR_GOES_VIS_ENABLED=false` to `.env`.
- Accept: Health shows only IR channels. Satellite memory reduced.

**T3.2 — Remove LXD CPU limit**
- Owner: Coordinator (Opus)
- Do: `lxc config unset librewxr limits.cpu` on ratbert.
- Accept: `nproc` inside LXD shows 32.

**T3.3 — Auto-detect warmer threads**
- Owner: Coordinator (Opus)
- Do: Remove `LIBREWXR_WARMER_THREADS=7` from `.env`.
- Accept: Thread pool auto-sized.

**QC (Opus):** VIS absent in health. 32 cores visible. RSS reasonable after 30 min.

### PHASE 4 — Deploy + End-to-End Verification

**T4.1 — Rebuild and deploy LibreWXR**
- Do: Rebuild Docker image with updated `.env`. Restart. Wait for satellite ingest.
- Accept: Health shows IR-only, warm logs show zoom 7, z=7 tiles are cache hits.

**T4.2 — Deploy dashboard**
- Do: `tsc --noEmit` + `npm run build` clean. Deploy via `scripts/redeploy-weather-dev.sh`.

**T4.3 — End-to-end verification**
1. Satellite tiles load quickly (pre-warmed at z=7)
2. Animation cadence consistent — no lag-then-speedup
3. Nowcast NOT shown with satellite on (24 frames, not 30)
4. Nowcast DOES show with satellite off (30 frames)
5. Full BBOX coverage — no grey voids (both GOES-18 + GOES-19)
6. IR-only satellite (no VIS)
7. Radar overlay works when both on
8. No regressions: radar-only, alerts, labels, wind arrows

---

## 3. Agent Assignments

| Phase | Task | Owner | QC Timing |
|-------|------|-------|-----------|
| 0 | T0.1–T0.3 Doc updates | Coordinator (Opus) | Immediate |
| 1 | T1.1 Demand warming | `librewxr-dev` (Sonnet) | After Phase 1 |
| 1 | T1.2 Immutable cache headers | `librewxr-dev` (Sonnet) | After Phase 1 |
| 1 | T1.3 Warm zoom config | Coordinator (Opus) | After Phase 1 |
| 2 | T2.1–T2.5 Dashboard animation | `clearskies-dashboard-dev` (Sonnet) | After Phase 2 |
| 3 | T3.1–T3.3 Config changes | Coordinator (Opus) | After Phase 3 |
| 4 | T4.1–T4.3 Deploy + verify | Coordinator (Opus) | After deploy |

**Parallelism:** Phase 1 (LibreWXR) and Phase 2 (Dashboard) are independent — run in parallel. Phase 3 (config) is independent. Phase 4 depends on all.

---

## 4. QC Gates

| Gate | Check | When |
|------|-------|------|
| Code Quality | LibreWXR: `ruff check`. Dashboard: `tsc --noEmit` + `vite build` | Every phase |
| Manual Compliance | Implementation matches DASHBOARD-MANUAL §10 | After each phase |
| Feature Correctness | Per-phase acceptance criteria | After each phase |
| Doc-Code Sync | All governing docs match implementation | After Phase 4 |

---

## 5. Self-Audit

**Risk: Warm zoom 7 increases tile count.** ~100 tiles at z=7 (vs ~25 at z=6). 24 timestamps × 100 = 2400 tiles per warm cycle at ~500ms each with 7+ threads ≈ 171 seconds background. Demand-driven warming (T1.1) covers the gap for the first browser request.

**Risk: VIS removal loses daytime cloud detail.** IR shows clouds by temperature; VIS shows all clouds by reflected light. Thin/low clouds and fog can be invisible in IR. Operator can re-enable: `LIBREWXR_GOES_VIS_ENABLED=true`. No code change needed.

**Risk: LXD CPU limit removal.** LibreWXR is idle 99% of the time. Linux CFS handles sharing. 3GB memory limit stays for safety.

**Risk: Nowcast exclusion.** Radar nowcast over satellite-only past creates timeline mismatch. Progress bar hides nowcast segment, making change visible.

**Risk: LAYER_BUFFER removal + visibility strategy.** Research confirmed: LAYER_BUFFER premise (Leaflet `will-change: opacity`) was fixed in v1.8.0; we run 1.9.4. `visibility: hidden` is cross-browser safe — no stacking context, no paint, cheap toggle. Profile on ASUS Zenbook (Intel iGPU) in Chrome and Firefox after implementation.

**Risk: Tile prefetch volume.** 24 frames × ~24 tiles = 576 `new Image()` calls. Browser's 6-connection limit naturally throttles. `PRELOAD_DELAY_MS = 1500ms` window provides initial prefetch time.

**Risk: `preferCanvas` changes vector rendering.** Canvas uses pixel-based drawing vs SVG DOM. Verify alert popup clicks still work.

**Risk: `Cache-Control: immutable` through Caddy.** Caddy's `reverse_proxy` passes upstream headers through by default. Verify after deploy that the browser sees the `immutable` directive.
