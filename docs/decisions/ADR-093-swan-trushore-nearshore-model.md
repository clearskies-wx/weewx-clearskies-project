---
status: Accepted
date: 2026-07-16
deciders: shane
supersedes: ADR-084
superseded-by:
---

# ADR-093: SWAN+SwellTrack replaces NWPS as nearshore wave model

## Context

The surf endpoint depends on NWPS (Nearshore Wave Prediction System) as its primary nearshore data source. NWPS is an NWS operational tool for forecasters, not a public data service. Its run schedule is gated on human forecaster input (2–8 runs/day, no fixed schedule). When a cycle has not posted, NOMADS returns 404 and our 30-minute cache TTL discards valid data, forcing fallback to WaveWatch III — a 50km deep-water model with no nearshore physics. On fallback, the surf forecast returns identical wave values across all 144 timesteps and all four wave_transform.py supplements are skipped.

No commercial surf forecast provider depends on NWPS. Surfline, MSW, WindGuru, and SwellWatch all run their own nearshore models on fixed automated schedules.

NWPS IS SWAN — it runs the same Fortran spectral wave model we would run ourselves. The only things NWPS adds are forecaster-edited wind grids (marginal value for routine conditions per published research) and operational infrastructure across 36 WFOs (irrelevant — we serve specific configured locations). Full research at `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep NWPS as primary (current) | No new code. Leverages NWS infrastructure. | Human-gated schedule, no guaranteed availability. 404 → cache discard → WW3 fallback. WW3 fallback produces flat-line forecasts. Sole external dependency for surf data quality. |
| NWPS with extended cache TTL | Mitigates cache discard. No new infrastructure. | Still human-gated. Stale NWPS data can be 12+ hours old. Does not fix the WW3 fallback problem — just delays it. |
| Own SWAN instance + SwellTrack (chosen) | Fixed hourly schedule, guaranteed availability. Same physics as NWPS. HRRR at 3km is finer than NWPS's 5km NDFD input. Cache-last-good-run eliminates WW3 fallback for surf. Existing wave_transform.py and surf_scorer.py wire directly. SwellTrack proprietary 1D model provides high-resolution surf zone physics. | SWAN Fortran binary dependency. HRRR wind provider needed. NWPS code/docs must be removed. |

## Decision

Replace NWPS with a locally-run SWAN instance paired with SwellTrack (proprietary analytical 1D cross-shore wave transformation model). NWPS is eliminated entirely — code, documentation, cache warmer schedule, and config keys are removed. There is no legacy mode and no `nearshore_model` config key. When the `[nearshore]` pip extra is installed, SWAN+SwellTrack runs as the only nearshore model.

**SwellTrack** is the named 1D analytical wave transformation model that runs per-transect from the SWAN handoff depth to shore. It replaces the generic "analytical 1D" label used during development.

**SurfBeat strip** is a complementary SWAN run (stationary 2D strip with the SURFBEAT command) that produces infragravity (IG) wave energy — set/lull timing that SwellTrack cannot compute (phase-averaged model). SurfBeat runs at 3-hour intervals alongside SwellTrack's hourly cadence. Enabled per-spot via `surfbeat_enabled` config.

**SWASH and XBeach are ruled out entirely** — for production, LUT precomputation, and referee/benchmark use. SWASH is unvalidated itself and cannot serve as a truth standard. XBeach surfbeat's runtime (~2 min for a 30-min simulation) is incompatible with the 72-timestep forecast pipeline.

**Compute offloading** is operator-configurable via `surf_compute_host` in `api.conf`. When set, SwellTrack and SurfBeat computations run on a remote compute service (e.g., librewxr) instead of in-process on the weewx host. Fallback to in-process when unconfigured or unreachable.

The four supplements from ADR-084 (γ correction, structure effects, spatial interpolation, topographic focusing) survive unchanged and apply to SWAN output. Only the primary nearshore source decision changes.

## Consequences

- **New dependency:** SWAN Fortran binary (compiled from source — pre-compiled binaries are ABI-incompatible across gfortran versions). Installed via `[nearshore]` pip extra pattern following the eccodes precedent. Source: https://gitlab.tudelft.nl/citg/wavemodels/swan
- **Nested grid architecture:** SWAN runs with a two-level nested grid (standard operational practice per NWPS, PacIOOS, USGS CoSMoS). Level 1: coarse outer grid (~2–3 km) for shelf wave propagation. Level 2: fine inner nest (~200–500m) around each surf spot for nearshore feature resolution. Total memory: ~200–300 MB. See research brief §2 "Grid Configuration: Nested Grids" for operational precedents and domain sizing.
- **New provider:** `providers/wind/hrrr.py` — HRRR forecast wind at 3km from NOMADS, hourly fixed schedule (0–48h). See ADR-094.
- **New provider:** `providers/wind/gfs.py` — GFS forecast wind at 0.25° from NOMADS for hours 48–72 (HRRR only extends to 48h on extended cycles; GFS extends to 384h). Required to fill the 72-hour surf forecast card.
- **New service:** `services/swan_runner.py` — writes SWAN input files for each nesting level, spawns SWAN subprocess, parses TABLE output to `MarineForecastPoint` objects.
- **NWPS eliminated:** `providers/marine/nwps.py`, its tests, cache warmer entry, config keys (`nwps_wfo`, `nearshore_model`), and all documentation removed. ADR-084 archived as superseded.
- **No WW3 surf fallback:** WW3 remains the deep-water boundary input to SWAN and continues serving the marine endpoint's offshore forecast. WW3 is never used as a surf forecast source. The surf endpoint serves last-successful SWAN cache on runner failure.
- **Surf data quality:** Wave data varies across all forecast timesteps. All four supplements fire on every run.

## Acceptance criteria

- [ ] SWAN binary installed and callable from the API process when `[nearshore]` extra is present
- [ ] HRRR wind provider returns earth-relative wind fields for the configured coastal bounding box
- [ ] SWAN runner produces `MarineForecastPoint` objects with physically reasonable values (Hs 0.1–10m, Tm01 5–20s) for the test domain
- [ ] Wave data varies across forecast timesteps (not identical values)
- [ ] All four wave_transform.py supplements fire on SWAN output
- [ ] `grep -ri "nwps" repos/weewx-clearskies-api/` returns zero hits (excluding git history)
- [ ] No `nearshore_model` config key exists anywhere
- [ ] WW3 never appears as a surf endpoint data source
- [ ] SWAN failure retains last-good cache — no fallback to WW3 for surf

## Implementation guidance

- **Pip extra:** `[nearshore]` in `pyproject.toml`, following the `[marine]` pattern (which adds eccodes). Includes cfgrib/xarray, HRRR provider, SWAN binary documentation.
- **SWAN compiled from source:** Pre-compiled binaries from SourceForge are ABI-incompatible with Ubuntu 24.04's gfortran 13.3 (Fortran allocatable array metadata layout differs between runtime versions). Docker images compile SWAN at build time, eliminating the ABI issue. Native installs use `install_swan.sh` which builds from the TU Delft GitLab source.
- **Nested grid execution:** Two sequential SWAN runs per cycle. Outer grid completes first, producing boundary condition files that feed the inner nest. SWAN natively supports this via its `NESTOUT`/`NGRID` commands. Domain sizing follows NWPS SGX pattern: outer ~200km at ~3km, inner ~20km at ~200–500m.
- **Wind forcing:** HRRR (3km, hours 0–48) blended with GFS (0.25°, hours 48–72) to fill the 72-hour forecast card. HRRR and GFS wind grids are interpolated onto the SWAN computational grid independently; the SWAN runner stitches them at the 48-hour boundary.
- **Schedule:** SWAN runs on the HRRR extended cycle schedule (4×/day at 00/06/12/18Z) when the 48-hour HRRR is available. Not in the request path — the surf endpoint reads from cache.
- **Cache policy:** TTL 6 hours (matching the extended cycle interval). On failure, retain last-good cache indefinitely. Stale SwellTrack data is always preferred to no data.
- **Optional separated service:** `weewx-clearskies-trushore` pip package for operators who want SWAN on dedicated hardware. API reads from it via `[trushore] service_url`. See Phase 4 of the implementation plan.
- **Memory budget:** Total SWAN memory must stay under 300 MB (both grid levels combined) to coexist with the API, MariaDB, Redis, and weewx on a 2 GB host.

## Amendments

### Amendment 1 (2026-07-21): Multi-transect architecture and optional L3

Per SURF-ZONE-MODEL-BRIEF and SURF-1D-IMPLEMENTATION-PLAN:

**1. L3 grid is now optional per location.** L3 is enabled automatically when Overpass API discovers structures near the spot, disabled for open beaches. The operator can override in admin (force L3 on/off per location). Spots with no structures skip L3 entirely — SPECOUT extracted from L2 at ~15m depth.

**2. When L3 is enabled, grid is smart-sized around structures.** L3 bbox is computed from structure positions + shadow zone extent (structure length + 2× structure length downstream in predominant wave direction) + 100m pad. A single pier on a 1km beach produces a ~500m L3 grid, not a 1km+ grid. Transects outside the L3 bbox hand off from L2 at ~15m depth.

**3. Multi-transect architecture replaces single-pin transect.** The operator draws a shoreline segment (not a pin) to define the surfable zone. The system generates transects perpendicular to local isobath orientation at 10m spacing across the segment. Each transect is cross-checked against OBSTACLE structures — transects crossing an OBSTACLE are flagged as "structure-affected" and excluded from headline metrics (best peak, spot average). Structure-affected transects are still rendered on the heat map.

**4. 1D model runs from handoff to shore per transect.** SWAN runs 2D all the way to shore. At the handoff depth (10m default, shallower for structure-shadowed transects, per the pre-model handoff algorithm), the full 2D spectrum is extracted via SPECOUT. A 1D cross-shore wave transformation model then runs independently per transect from the handoff to shore, providing Hs at 3-5m resolution, break points, breaker classification, wave shapes, surf zone widths, jacking factor, and peel angle. Model selection pending Phase 1 benchmark (analytical, XBeach-1D surfbeat, SWASH-1D).

**5. Compute budget updated.** L3 compute is proportional to structure coverage, not beach length. Spots with no structures skip L3 entirely. The 1D analytical model adds ~30-90ms per spot (30 transects × 3 partitions × ~1ms) — negligible relative to SWAN runtime.

**6. Pin-based configuration replaced entirely.** No backwards compatibility needed (no other operators). The shoreline segment replaces `spot_lat`, `spot_lon`, `beach_facing_degrees` with `segment_start_lat/lon`, `segment_end_lat/lon`, and `transect_spacing_m`.

## References

- Supersedes: ADR-084 (NWPS as primary nearshore source with supplementation)
- Related: ADR-094 (HRRR forecast wind source for surf scoring)
- Research: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`, `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`, `docs/planning/briefs/1D-MODEL-BENCHMARK-BRIEF.md`
- Plan: `docs/planning/SWAN-TRUSHORE-PLAN.md`, `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md`, `docs/planning/SURF-MODEL-FIX-PLAN.md`
