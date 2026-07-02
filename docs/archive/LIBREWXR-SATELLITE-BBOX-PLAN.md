# LibreWXR High-Resolution Satellite + BBOX Geographic Crop — Execution Plan

**Status:** COMPLETE — implemented and deployed 2026-06-28
**Created:** 2026-06-28
**Components:** LibreWXR fork (`repos/librewxr`), branch `deploy/shaneburkhardt`
**Target:** Upstream PR to `JoshuaKimsey/LibreWXR` (AGPL-3.0)

---

## Current State (session context for continuation)

### What happened on 2026-06-28

The LibreWXR radar integration was completely broken. Root cause investigation revealed cascading failures:

1. **BBOX code was never deployed.** A previous session created `fix/dual-stack-bind-clean` for a clean upstream PR but dropped the BBOX commit (`3e52850`) during the rebase. The Docker image `librewxr-bbox:latest` was built from that branch — so `LIBREWXR_BBOX` env var was set but silently ignored. Every radar frame was full CONUS at 63 MB instead of the expected 0.8 MB.

2. **Memory thrashing → segfaults.** Without BBOX crop: 24 frames × 63 MB = 1.5 GB radar + 360 MB satellite + 200 MB alerts = ~2 GB in a 3 GB LXD container. The container had 1.3 GB in swap. Exit code 139 (SIGSEGV) every ~2.5 hours from memmap page faults under swap pressure.

3. **GMGSI satellite is useless at regional scale.** 6-7 km resolution, hourly updates. At the SoCal BBOX scale, only ~61×86 pixels of actual data. The satellite layer showed a tiny smear that "never fully forms" — same issue exists on the upstream author's hosted demo.

### What was fixed

- **Renamed branch** `fix/dual-stack-bind` → `deploy/shaneburkhardt` as the production deployment branch
- **BBOX radar crop** is now on `deploy/shaneburkhardt` (the original commit `3e52850` was already there)
- **Alert BBOX filtering** committed and deployed (`59a3e57`) — filters 3800 global alerts to only those intersecting the BBOX using Shapely `intersects()`
- **Dual-stack bind** fixed to `host: str | None = None` (same commit)
- **Docker image rebuilt** from `deploy/shaneburkhardt` and restarted on the `librewxr` LXD container
- **Memory verified:** 498 MB RSS, 34 MB swap (was 1.3 GB swap). No segfaults since rebuild.
- **Radar works end-to-end:** 30 frames, tiles loading, animation playing
- **Dashboard radar card** updated: `maxBounds`, `showAlerts`, `alertUrl`, `caddyPrefix` props now wired in card view (commits `7731456`, `54967b0` on dashboard `main`)
- **Satellite BBOX crop was attempted** but reverted — cropping global GMGSI to BBOX produces tiles with data in only a tiny corner, visually broken. The correct fix is replacing GMGSI with GOES/Himawari.

### Current repo/branch state

| Repo | Branch | HEAD | State |
|------|--------|------|-------|
| `repos/librewxr` | `deploy/shaneburkhardt` | `59a3e57` | Deployed to `librewxr` LXD container. Has BBOX radar crop + alert filter + bind fix. Satellite source file (`gmgsi/source.py`) has uncommitted partial changes from the reverted BBOX crop attempt — **discard these before starting new work.** |
| `repos/librewxr` | `fix/dual-stack-bind-clean` | `97e0f5a` | Clean PR branch for upstream dual-stack fix only. Do not touch. |
| `repos/librewxr` | `main` | tracks upstream | Upstream main. |
| `repos/weewx-clearskies-dashboard` | `main` | `54967b0` | Deployed to weather-dev. Radar card has bounds + alert props. |

### Infrastructure state

| System | State |
|--------|-------|
| `librewxr` LXD container (ratbert, 192.168.7.22, VLAN 7) | Running. Docker image `librewxr-bbox:latest` from `deploy/shaneburkhardt`. 3 GB RAM, ~500 MB used, ~34 MB swap. BBOX crop active for radar + alerts. Satellite enabled but GMGSI (useless at BBOX scale). |
| Caddy on weather-dev | `/librewxr/*` proxies to `http://librewxr.shaneburkhardt.com:8080`. Working. |
| API on weewx | `[radar] provider = librewxr` configured. Frames endpoint returns 30 radar + 12 satellite frames. Working. |
| Dashboard on weather-dev | Radar card + expanded view both working. Satellite toggle exists but imagery is too coarse (GMGSI). |

### SSH access (from project root)

```
ssh -F .local/ssh/config weewx "<cmd>"        # API host
ssh -F .local/ssh/config weather-dev "<cmd>"   # Dashboard/Caddy host  
ssh -F .local/ssh/config ratbert "lxc exec librewxr -- <cmd>"  # LibreWXR container
```

### What this plan covers

Replace GMGSI with GOES-18/19 (Americas) and Himawari-9 (Asia-Pacific) as high-resolution satellite sources. Add BBOX as a first-class feature (radar crop + alert filter + satellite source selection). Package as a single upstream PR.

---

## Context

LibreWXR's satellite imagery uses NOAA GMGSI — a global 3000×5000 mosaic at 6–7 km resolution, updated hourly. For operators with a geographic bounding box (sub-region deployments), this is wasteful: 15 MB/frame for the entire planet, 360 MB total for 12 frames, and the resolution is too coarse to show meaningful cloud detail at regional scale.

GOES-18 (West) and GOES-19 (East) serve the same CONUS/PACUS area at **2 km IR / 0.5 km visible, every 5 minutes** via anonymous S3. Himawari-9 covers Asia-Pacific at the same resolution. These sources are 3–10× sharper, 6× faster-updating, and use **less memory** than GMGSI even at full-sector coverage because they don't carry the whole planet.

This PR adds:
1. **`LIBREWXR_BBOX`** — geographic bounding box that crops radar regions, filters alerts, and enables high-res satellite source selection
2. **GOES-18/19 satellite source** — replaces GMGSI for operators in the Americas
3. **Himawari-9 satellite source** — replaces GMGSI for operators in Asia/Pacific/Oceania
4. **Auto-selection** — picks the best satellite source based on station coordinates; GMGSI remains the fallback for uncovered regions

### Memory impact (SoCal BBOX example)

| Subsystem | Before (GMGSI, no BBOX) | After (GOES + BBOX) |
|-----------|------------------------|---------------------|
| Radar (24 frames) | 1,512 MB | 20 MB |
| Satellite (12 frames, 2 channels) | 360 MB | 4 MB |
| Alerts | ~200 MB | ~0 MB |
| **Total data** | **~2,072 MB** | **~24 MB** |

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — project overview, architecture, development conventions
- `docs/adding-a-source.md` — canonical pattern for new source packages
- `docs/satellite-implementation-plan.md` — original GMGSI design decisions
- `docs/configuration-reference.md` — env var documentation standards

**Key existing code paths:**
- `src/librewxr/sources/_base.py` — `SatelliteSource` Protocol, `SatelliteContribution` dataclass
- `src/librewxr/sources/satellite/gmgsi/` — reference implementation (LW + VIS channels)
- `src/librewxr/sources/__init__.py` — `collect_satellite_contributions()` discovery walker, `SATELLITE_PROVIDERS` list
- `src/librewxr/tiles/satellite_renderer.py` — VIS-over-LW composite; calls `source.sample(lat, lon, timestamp)`
- `src/librewxr/tiles/coordinates.py` — projection math (LAEA, Transverse Mercator, lat/lon); `tile_pixel_latlons()` used by satellite renderer
- `src/librewxr/main.py` — satellite wiring: `collect_satellite_contributions()` → `satellite_grids_by_slug` → `routes.satellite_grids`
- `src/librewxr/api/routes.py` — `/v2/satellite/{timestamp}/...` tile endpoint, `weather-maps.json` satellite frame listing
- `src/librewxr/config.py` — `Settings` class, all `LIBREWXR_*` env vars, `get_bbox()` helper

**Satellite source interface contract** (from `_base.py` Protocol + GMGSI reference):
- `name: str` — display name
- `timestamps: list[int]` — sorted Unix epoch list of loaded frames
- `loaded: bool` — True when at least one frame is available
- `data_bytes: int` — total memory across all frames (for `/health`)
- `async fetch() -> bool` — ingest new frames from S3; return True if new data
- `sample(lat: ndarray, lon: ndarray, timestamp: int | None) -> ndarray` — nearest-neighbor lookup; returns uint8 array shaped like lat/lon; 0 = no data
- `async close() -> None` — cleanup
- `__getstate__` / `__setstate__` — pickle for multi-worker snapshot

**Provider registration** (from `sources/satellite/gmgsi/__init__.py`):
- Package exposes `satellite_provider(settings, cache_dir) -> list[SatelliteContribution]`
- Discovery walker in `sources/__init__.py` calls it automatically
- Return `[]` when source is not applicable (wrong region, disabled)

**No new runtime dependencies needed.** `pyproj` is dev-only; all existing projections are implemented inline with numpy. Geostationary projection is ~20 lines of numpy (GOES-R PUG Vol 5 §4.2.8).

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote. Coordinator pushes after QC.

---

## 1. Feature Inventory

### A. BBOX Geographic Crop (already implemented, needs commit cleanup)

| # | Item | Status | Description |
|---|------|--------|-------------|
| A1 | BBOX config field + validation | DONE (commit `3e52850`) | `LIBREWXR_BBOX` env var, `get_bbox()` helper, field_validator |
| A2 | Radar region cropping | DONE (commit `3e52850`) | `_apply_bbox_crop()` in `data/regions.py` |
| A3 | IEM PNG sub-region slicing | DONE (commit `3e52850`) | `_parse_n0q_png()` crop in `iem/source.py` |
| A4 | Alert BBOX filtering | DONE (uncommitted) | `_fetch_once()` in `alerts_fetcher.py` — Shapely `intersects()` filter |
| A5 | Dual-stack bind fix | DONE (uncommitted) | `host: str | None = None` in `config.py` |

### B. GOES-18/19 Satellite Source (new)

| # | Item | Status | Description |
|---|------|--------|-------------|
| B1 | Geostationary projection math | TODO | Forward transform: lat/lon → scan angles (radians). GOES-R PUG Vol 5 §4.2.8. ~20 lines numpy. |
| B2 | GOES base source class | TODO | `GOESSource(GMGSISource)` or standalone. S3 fetch from `noaa-goes18` / `noaa-goes19`. NetCDF4 decode for ABI L2 CMI. BBOX-aware crop after decode. |
| B3 | GOES IR channel (Band 13, 10.3 µm) | TODO | `GOESIRSource` subclass. 2 km resolution. Day+night. S3 path: `ABI-L2-CMIPC/{year}/{doy}/{hour}/`. |
| B4 | GOES VIS channel (Band 2, 0.64 µm) | TODO | `GOESVISSource` subclass. L2 CMI at 2 km (full sector), L1b-RadC at 0.5 km (BBOX only). Day only. |
| B5 | GOES-East/West auto-selection | TODO | Pick satellite based on station longitude: west of ~100°W → GOES-18, east → GOES-19. Both use identical code, different S3 bucket + satellite params. |
| B6 | GOES `satellite_provider()` | TODO | Package `__init__.py`. Returns IR + VIS contributions when station is in Americas. Returns `[]` otherwise. |
| B7 | Config env vars | TODO | `LIBREWXR_GOES_ENABLED`, `LIBREWXR_GOES_IR_ENABLED`, `LIBREWXR_GOES_VIS_ENABLED`, `LIBREWXR_GOES_VIS_HIRES` (use L1b 0.5 km when BBOX set). |

### C. Himawari-9 Satellite Source (new)

| # | Item | Status | Description |
|---|------|--------|-------------|
| C1 | Himawari base source class | TODO | Same geostationary projection (different sat longitude: 140.7°E). S3 fetch from `noaa-himawari9` (confirmed bucket). AHI sensor is ABI-class but NOT identical — spectral response functions differ slightly. Shares `GeoSource` base with GOES but needs separate decode/value-mapping for AHI NetCDF format. |
| C2 | Himawari IR channel (Band 13) | TODO | 2 km, 10-min cadence. AHI Band 13 (10.4 µm, ~equivalent to GOES Band 13). |
| C3 | Himawari VIS channel (Band 3) | TODO | 0.5–1 km visible (AHI Band 3, 0.64 µm). |
| C4 | Himawari `satellite_provider()` | TODO | Returns contributions when station is in Asia/Pacific. |
| C5 | Config env vars | TODO | `LIBREWXR_HIMAWARI_ENABLED`, `LIBREWXR_HIMAWARI_IR_ENABLED`, `LIBREWXR_HIMAWARI_VIS_ENABLED`. |

### D. Auto-Selection + GMGSI Fallback

| # | Item | Status | Description |
|---|------|--------|-------------|
| D1 | Source priority ordering | TODO | GOES/Himawari (priority 5) > GMGSI (priority 10). When a regional source covers the station, it wins. |
| D2 | GMGSI stays as global fallback | N/A | No changes to existing GMGSI code. It still provides if no regional source covers the station. |
| D3 | Satellite renderer compatibility | TODO | Verify `satellite_renderer.py` works with GOES/Himawari sources (same `sample()` interface). May need to handle different LW value ranges (GOES CMI uses Kelvin, GMGSI uses 0-255 brightness temp). |

### E. Documentation

| # | Item | Status | Description |
|---|------|--------|-------------|
| E1 | `docs/configuration-reference.md` | TODO | Add all new env vars with descriptions. |
| E2 | `CLAUDE.md` | TODO | Update Architecture Notes satellite section. |
| E3 | `README.md` | TODO | Update satellite section with GOES/Himawari info. |
| E4 | `docs/adding-a-source.md` | TODO | Add "Adding a satellite source" section. Currently only covers radar + NWP. Document the `satellite_provider()` pattern, `SatelliteContribution` dataclass, `SatelliteSource` Protocol, and `sample()` interface contract. |

### F. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| GOES mesoscale sectors (60s cadence) | Sector position not guaranteed over any fixed area. Opportunistic enhancement for a follow-up PR. |
| Meteosat / FY-4B / INSAT | Restricted access; not feasible for self-hosted open-source. |
| Band 8 (water vapor) | Nice-to-have overlay, not part of the core IR+VIS composite. Follow-up PR. |
| Fire/hot spot detection (FDCC) | Separate feature, separate PR. |
| Satellite tile caching by BBOX | Current tile cache already handles this via the renderer. |

---

## 2. Implementation Phases

### PHASE 0 — BBOX Consolidation

Consolidate the existing BBOX work (radar crop from commit `3e52850` + uncommitted alert filter + bind fix) into a clean commit on a new feature branch from upstream `main`.

**T0.1 — Create feature branch and consolidate BBOX commits**
- Owner: Coordinator (Opus)
- Do: Create `feature/bbox-and-regional-satellite` branch from upstream `main`. Cherry-pick `3e52850` (radar BBOX crop). Apply alert BBOX filter and bind fix as a second commit.
- Accept: Branch has 2 clean commits. `LIBREWXR_BBOX` works for radar + alerts. Tests pass.

**QC (Opus):** Verify BBOX radar crop with `LIBREWXR_BBOX=32.0,-120.5,35.5,-114.5` — regions should crop. Alert filter should log "BBOX filter: N → M". Bind should use `host=None`.

### PHASE 1 — Geostationary Projection + GOES Base

**T1.1 — Implement geostationary forward projection**
- Owner: `librewxr-dev` (Sonnet)
- File: New `src/librewxr/tiles/geostationary.py`
- Do: Vectorized numpy implementation of the GOES-R fixed grid ↔ lat/lon transform. Forward (lat/lon → scan angle x,y in radians) and inverse (scan angle → lat/lon). Parameters: satellite longitude, satellite height, semi-major/semi-minor axes. Visibility check (point behind earth → NaN). Based on GOES-R PUG Vol 5 §4.2.8.
- Accept: Unit test with known GOES-18 coordinates (137°W, height 35786023 m). Forward/inverse round-trip within 0.001° for 100 random points in CONUS. Points behind earth return NaN.

**T1.2 — Implement geostationary satellite base class + GOES source**
- Owner: `librewxr-dev` (Sonnet)
- Files: New `src/librewxr/sources/satellite/_geo_base.py` (shared geostationary base), new `src/librewxr/sources/satellite/goes/__init__.py`, new `src/librewxr/sources/satellite/goes/source.py`
- Do: `GeoSatSource` abstract base class in `_geo_base.py` (shared by GOES and Himawari). Concrete `GOESSource(GeoSatSource)` in `goes/source.py`. Key differences from GMGSI:
  - S3 bucket: `noaa-goes18` or `noaa-goes19` (parameterized)
  - Path structure: `ABI-L2-CMIPC/{year}/{day_of_year}/{hour}/`
  - File naming: `OR_ABI-L2-CMIPC-M6C{band}_G{sat}_{timestamps}.nc`
  - Grid: Geostationary fixed grid (not Mercator). Uses `geostationary.py` projection.
  - Decode: CMI variable (float32 Kelvin for IR, reflectance factor for VIS). Map to uint8 for compatibility with existing renderer.
  - BBOX crop: After decode, crop the fixed-grid array to the BBOX scan-angle bounds. Store only cropped array.
  - `sample()`: Convert lat/lon → scan angles via forward projection, then index into the stored (possibly cropped) grid.
  - `_list_recent_keys()`: Walk S3 hour directories. CMIPC files have one file per band per 5-min slot.
  - `_parse_start_timestamp()`: Parse the `_s{YYYYDDDHHMMSSt}` token (day-of-year format, differs from GMGSI).
  - Cache/memmap: Same pattern as GMGSI but with GOES grid dimensions.
  - Serialization: `__getstate__`/`__setstate__` for multi-worker.
- Accept: `GOESSource` can fetch Band 13 from `noaa-goes18`, decode, crop to BBOX, and `sample()` returns valid uint8 values for SoCal coordinates. Memmap cache round-trips.

**T1.3 — Implement GOES IR and VIS channel subclasses**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/sources/satellite/goes/source.py`
- Do: `GOESIRSource(GOESSource)` for Band 13 (10.3 µm, L2 CMIPC, 2 km). `GOESVISSource(GOESSource)` for Band 2 (0.64 µm, L2 CMIPC at 2 km; optionally L1b-RadC at 0.5 km when BBOX is set and `LIBREWXR_GOES_VIS_HIRES=true`). Each pins `band`, `s3_product_path`, `friendly_name`, `s3_filename_prefix`.
- Accept: Both channels fetch, decode, and sample independently. VIS correctly returns 0 at night (encoded reflectance = 0 in dark).

**T1.4 — CMI value mapping for renderer compatibility**
- Owner: `librewxr-dev` (Sonnet)
- Files: `source.py`, possibly `satellite_renderer.py`
- Do: GOES CMI Band 13 returns brightness temperature in Kelvin (float32). The existing satellite renderer expects uint8 0–255 (GMGSI encoding). Map GOES Kelvin → uint8 using the same brightness-temperature scale as GMGSI: `uint8 = clip((T_K - offset) * scale, 0, 255)`. Determine correct offset/scale from GMGSI documentation or empirical comparison. Alternatively, adjust the renderer to accept Kelvin and handle the LW threshold (`_LW_CLOUD_THRESHOLD`) in Kelvin space.
- Accept: GOES IR tiles look visually comparable to GMGSI IR tiles for the same timestamp and region. Cloud tops are bright, warm ground is transparent, same behavior.

**QC (Opus) — after Phase 1:** Run GOES source with `LIBREWXR_BBOX=32.0,-120.5,35.5,-114.5`. Verify:
- S3 fetch succeeds for Band 13 and Band 2
- Geostationary projection round-trip accuracy < 0.001° over CONUS
- `sample()` returns non-zero uint8 for SoCal coordinates
- Satellite tile renders with visible cloud detail at zoom 7 over SoCal
- Memory: cropped GOES frames < 1 MB total for 12 frames at SoCal BBOX

### PHASE 2 — GOES Provider Registration + Auto-Selection

**T2.1 — GOES `satellite_provider()` with auto-selection**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/sources/satellite/goes/__init__.py`
- Do: `satellite_provider(settings, cache_dir)` that:
  1. Checks if GOES is enabled (`settings.goes_enabled`, default True)
  2. Determines station location from `settings.get_bbox()` center point, or `settings.public_url` if no BBOX (fallback: skip)
  3. If station longitude is between -170°W and -30°W (Americas + Caribbean + Hawaii): proceed
  4. Pick GOES-18 for stations west of -100°W, GOES-19 for east of -100°W
  5. Return `[GOESIRContribution, GOESVISContribution]` with priority 5 (wins over GMGSI's priority 10)
  6. Return `[]` if station not in Americas
- Accept: Auto-selection picks correct satellite for SoCal (GOES-18), NYC (GOES-19), Tokyo (none → falls through to Himawari/GMGSI).

**T2.2 — Config env vars for GOES**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/config.py`
- Do: Add fields:
  - `goes_enabled: bool = True` — master toggle for GOES satellite
  - `goes_ir_enabled: bool = True` — IR channel toggle
  - `goes_vis_enabled: bool = True` — VIS channel toggle
  - `goes_vis_hires: bool = False` — when True and BBOX is set, use L1b 0.5 km instead of L2 2 km for VIS
  - `goes_max_frames: int = 0` — 0 = use `satellite_max_frames` default; >0 = override
- Accept: Env vars parse correctly. `LIBREWXR_GOES_ENABLED=false` suppresses GOES source entirely.

**QC (Opus) — after Phase 2:** Verify auto-selection by setting `LIBREWXR_PUBLIC_URL` to a SoCal URL → GOES-18 selected. Set to NYC URL → GOES-19 selected. Set to Tokyo URL → GOES skipped, GMGSI used. Health endpoint shows GOES channels loaded.

### PHASE 3 — Himawari-9 Source

**T3.1 — Implement Himawari source**
- Owner: `librewxr-dev` (Sonnet)
- Files: New `src/librewxr/sources/satellite/himawari/__init__.py`, new `src/librewxr/sources/satellite/himawari/source.py`
- Do: Same structure as GOES. S3 bucket: `noaa-himawari9`. Satellite at 140.7°E, same geostationary projection math (different `sat_lon` parameter). Himawari ABI equivalent: AHI. Band 13 (10.4 µm, IR), Band 3 (0.64 µm, VIS). S3 path structure may differ from GOES — verify from bucket listing. Coverage: station longitude between 60°E and 180°E (Asia + Pacific + Oceania + eastern Africa).
- Accept: Himawari source fetches, decodes, samples correctly for Tokyo coordinates. Auto-selection picks Himawari-9 for Asia-Pacific stations.

**T3.2 — Himawari config env vars**
- Owner: `librewxr-dev` (Sonnet)
- File: `src/librewxr/config.py`
- Do: `himawari_enabled`, `himawari_ir_enabled`, `himawari_vis_enabled`, `himawari_max_frames` — same pattern as GOES.
- Accept: Env vars parse, toggles work.

**QC (Opus) — after Phase 3:** Satellite tile renders for Tokyo coordinates via Himawari-9. Memory comparable to GOES. Auto-selection: Tokyo → Himawari, SoCal → GOES, London → GMGSI.

### PHASE 4 — Integration Testing + Documentation

**T4.1 — End-to-end integration test**
- Owner: `librewxr-test` (Sonnet)
- Files: New test files under `tests/`
- Do: Tests for:
  - Geostationary projection forward/inverse round-trip
  - GOES source fetch + decode + sample (mocked S3 or small fixture)
  - Himawari source fetch + decode + sample
  - Auto-selection logic for various longitudes
  - BBOX crop correctness (GOES grid cropped to BBOX, sample returns 0 outside)
  - Alert BBOX filter (alerts inside/outside/bisecting the box)
  - Radar region BBOX crop
  - Renderer compatibility (GOES source produces valid tiles via satellite_renderer)
- Accept: `pytest` passes with all new tests. No regressions in existing tests.

**T4.2 — Documentation updates**
- Owner: `librewxr-docs` (Sonnet)
- Files: `docs/configuration-reference.md`, `CLAUDE.md`, `README.md`
- Do:
  - `configuration-reference.md`: Add BBOX section, GOES section, Himawari section with all new env vars
  - `CLAUDE.md`: Update Architecture Notes → Satellite section
  - `README.md`: Update satellite description — mention GOES/Himawari as primary for Americas/Pacific, GMGSI as global fallback, BBOX crop description
- Accept: All new env vars documented with descriptions and defaults. README accurately describes the new satellite sources.

**T4.3 — `.env.example` update**
- Owner: `librewxr-docs` (Sonnet)
- File: `.env.example`
- Do: Add commented examples for `LIBREWXR_BBOX`, `LIBREWXR_GOES_ENABLED`, `LIBREWXR_HIMAWARI_ENABLED`, `LIBREWXR_GOES_VIS_HIRES`.
- Accept: Example file is self-documenting.

**QC (Opus) — after Phase 4:** All tests pass. Documentation complete. `.env.example` updated. Full deployment test on `librewxr` LXD container with SoCal BBOX.

### PHASE 5 — Deploy + Final Verification

**T5.1 — Build and deploy to librewxr container**
- Owner: Coordinator (Opus)
- Do: Merge feature branch into `deploy/shaneburkhardt`. Build Docker image. Restart container. Verify satellite tiles render at 2 km resolution over SoCal.
- Accept: Satellite imagery visible and detailed in dashboard. Memory under 1.5 GB total. No segfaults after 4+ hours.

**T5.2 — Prepare upstream PR**
- Owner: Coordinator (Opus)
- Do: Create clean PR from `feature/bbox-and-regional-satellite` → upstream `main`. PR description covers: problem (GMGSI too coarse for regional), solution (GOES + Himawari + BBOX), memory impact, configuration, backward compatibility.
- Accept: PR is clean, tests pass, documentation complete, no deployment-specific code included.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1 Branch + BBOX consolidation | Coordinator | Opus | Immediate |
| 1 | T1.1 Geostationary projection | `librewxr-dev` | Sonnet | After Phase 1 |
| 1 | T1.2 GOES base source class | `librewxr-dev` | Sonnet | After Phase 1 |
| 1 | T1.3 GOES IR + VIS subclasses | `librewxr-dev` | Sonnet | After Phase 1 |
| 1 | T1.4 CMI value mapping | `librewxr-dev` | Sonnet | After Phase 1 |
| 2 | T2.1 Provider + auto-selection | `librewxr-dev` | Sonnet | After Phase 2 |
| 2 | T2.2 Config env vars | `librewxr-dev` | Sonnet | After Phase 2 |
| 3 | T3.1 Himawari source | `librewxr-dev` | Sonnet | After Phase 3 |
| 3 | T3.2 Himawari config | `librewxr-dev` | Sonnet | After Phase 3 |
| 4 | T4.1 Integration tests | `librewxr-test` | Sonnet | After Phase 4 |
| 4 | T4.2 Documentation | `librewxr-docs` | Sonnet | After Phase 4 |
| 4 | T4.3 .env.example | `librewxr-docs` | Sonnet | After Phase 4 |
| 5 | T5.1 Deploy | Coordinator | Opus | After deploy |
| 5 | T5.2 Upstream PR | Coordinator | Opus | After deploy |

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- Python: `ruff check` clean. `mypy` no introduced errors. `python -m py_compile <file>` passes.
- All new code has SPDX license headers per project convention.

### Gate 2 — Feature Correctness (per phase)
- Phase 1: GOES tiles render with visible cloud detail. Geostationary projection accurate.
- Phase 2: Auto-selection picks correct satellite. Config toggles work.
- Phase 3: Himawari tiles render for Asia-Pacific coordinates.
- Phase 4: All tests pass. Documentation complete.

### Gate 3 — Memory Verification (Phase 5)
- SoCal BBOX: total satellite memory < 5 MB
- Full CONUS (no BBOX): total satellite memory < 100 MB (vs 360 MB for GMGSI)
- No swap usage after 30 minutes of operation

### Gate 4 — Backward Compatibility
- No changes to GMGSI source code — it must continue to work as-is
- Default config (no BBOX, no GOES/Himawari toggles) behaves identically to current upstream
- `weather-maps.json` format unchanged — satellite frames listed in same structure

---

## 5. Technical Details

### Geostationary Projection (GOES-R PUG Vol 5 §4.2.8)

Forward transform (lat/lon → scan angles):
```python
# Parameters from NetCDF goes_imager_projection variable
sat_lon = -137.0  # GOES-18 (or -75.0 for GOES-19)
sat_height = 35786023.0  # meters
r_eq = 6378137.0
r_pol = 6356752.31414

# Forward: lat/lon → (x, y) scan angles in radians
phi = radians(lat)
lam = radians(lon) - radians(sat_lon)
phi_c = arctan(r_pol²/r_eq² * tan(phi))  # geocentric latitude
r_c = r_pol / sqrt(1 - (r_eq²-r_pol²)/r_eq² * cos²(phi_c))
H = sat_height + r_eq
sx = H - r_c * cos(phi_c) * cos(lam)
sy = -r_c * cos(phi_c) * sin(lam)
sz = r_c * sin(phi_c)
x = arcsin(-sy / sqrt(sx² + sy² + sz²))
y = arctan(sz / sx)
```

Vectorize with numpy. ~20 lines.

### GOES S3 Path Structure
```
s3://noaa-goes18/ABI-L2-CMIPC/{year}/{day_of_year}/{hour}/
  OR_ABI-L2-CMIPC-M6C13_G18_s{start}_e{end}_c{creation}.nc
```

### NetCDF Variable
- L2 CMI: `CMI` variable (float32). For IR: brightness temperature in Kelvin. For VIS: reflectance factor (0–1).
- Quality: `DQF` variable (0 = good).
- Grid: `x` and `y` variables (scan angles in radians). `goes_imager_projection` variable has all projection params.

### BBOX Crop in Geostationary Space
1. Convert BBOX corners to scan angles using forward projection
2. Find min/max x,y in scan-angle space
3. Map to pixel indices using the x/y coordinate arrays from the NetCDF
4. Slice the CMI array to those indices after decode
5. Store crop offset for `sample()` to adjust

### Satellite Source Selection Logic
```python
def satellite_provider(settings, cache_dir):
    bbox = settings.get_bbox()
    if bbox:
        center_lon = (bbox[1] + bbox[3]) / 2  # (west + east) / 2
    else:
        # Parse longitude from public_url or station config
        center_lon = _infer_station_longitude(settings)
    
    if center_lon is None:
        return []  # Can't determine location → fall through to GMGSI
    
    # Americas: -170 to -30
    if -170 <= center_lon <= -30:
        sat = "goes18" if center_lon < -100 else "goes19"
        return _build_goes_contributions(settings, cache_dir, sat)
    
    # Asia-Pacific: 60 to 180
    if 60 <= center_lon <= 180:
        return _build_himawari_contributions(settings, cache_dir)
    
    return []  # Outside coverage → GMGSI fallback
```

---

## 6. Self-Audit

**Risk: GOES CMI value range differs from GMGSI.** GMGSI encodes brightness temperature as uint8 0–255. GOES CMI Band 13 returns Kelvin (float32, typically 180–320 K). The satellite renderer's `_LW_CLOUD_THRESHOLD` is calibrated for GMGSI's encoding. Mitigation: T1.4 maps GOES Kelvin to the same 0–255 encoding OR adjusts the renderer threshold. The mapping must be verified visually — GOES and GMGSI tiles for the same region/time should look comparable.

**Risk: Himawari AHI ≠ GOES ABI.** Both are ABI-class imagers but spectral response functions differ. The decode/value-mapping code cannot be shared 1:1 — GOES and Himawari need separate decode paths within a shared base class. The geostationary projection math IS shared (same satellite geometry, different parameters). Mitigation: T1.2 designs a `GeoSatSource` abstract base with shared projection + fetch + cache, leaving `_decode_netcdf()` abstract for sensor-specific subclasses. T3.1 verifies Himawari NetCDF variable names and value ranges against the `noaa-himawari9` bucket before coding.

**Risk: GOES data latency (15–25 min).** Frames may not be available on S3 for 15–25 minutes after observation. The fetcher must handle missing recent slots gracefully (same pattern GMGSI already uses).

**Risk: GOES-19 bucket naming.** Confirmed: bucket is `noaa-goes19` (operational since April 7, 2025). GOES-16 data archived at `noaa-goes16`. No risk remaining.

**Risk: No GMGSI changes.** GMGSI source stays untouched. If GOES/Himawari auto-selection fails, GMGSI still works as-is. Backward compatibility preserved.

**Risk: Satellite renderer assumes GMGSI grid shape.** Check that `satellite_renderer.py` doesn't hardcode `GRID_SHAPE`, `LAT_VEC`, `LON_VEC` from the GMGSI module. It shouldn't — it calls `source.sample()` which abstracts the grid. But verify.
