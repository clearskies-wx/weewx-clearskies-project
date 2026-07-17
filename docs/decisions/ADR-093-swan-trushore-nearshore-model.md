---
status: Accepted
date: 2026-07-16
deciders: shane
supersedes: ADR-084
superseded-by:
---

# ADR-093: SWAN+TruShore replaces NWPS as nearshore wave model

## Context

The surf endpoint depends on NWPS (Nearshore Wave Prediction System) as its primary nearshore data source. NWPS is an NWS operational tool for forecasters, not a public data service. Its run schedule is gated on human forecaster input (2–8 runs/day, no fixed schedule). When a cycle has not posted, NOMADS returns 404 and our 30-minute cache TTL discards valid data, forcing fallback to WaveWatch III — a 50km deep-water model with no nearshore physics. On fallback, the surf forecast returns identical wave values across all 144 timesteps and all four wave_transform.py supplements are skipped.

No commercial surf forecast provider depends on NWPS. Surfline, MSW, WindGuru, and SwellWatch all run their own nearshore models on fixed automated schedules.

NWPS IS SWAN — it runs the same Fortran spectral wave model we would run ourselves. The only things NWPS adds are forecaster-edited wind grids (marginal value for routine conditions per published research) and operational infrastructure across 36 WFOs (irrelevant — we serve specific configured locations). Full research at `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep NWPS as primary (current) | No new code. Leverages NWS infrastructure. | Human-gated schedule, no guaranteed availability. 404 → cache discard → WW3 fallback. WW3 fallback produces flat-line forecasts. Sole external dependency for surf data quality. |
| NWPS with extended cache TTL | Mitigates cache discard. No new infrastructure. | Still human-gated. Stale NWPS data can be 12+ hours old. Does not fix the WW3 fallback problem — just delays it. |
| Own SWAN instance — TruShore (chosen) | Fixed hourly schedule, guaranteed availability. Same physics as NWPS. HRRR at 3km is finer than NWPS's 5km NDFD input. Cache-last-good-run eliminates WW3 fallback for surf. Existing wave_transform.py and surf_scorer.py wire directly. | SWAN Fortran binary dependency. HRRR wind provider needed. NWPS code/docs must be removed. |

## Decision

Replace NWPS with a locally-run SWAN instance (TruShore). NWPS is eliminated entirely — code, documentation, cache warmer schedule, and config keys are removed. There is no legacy mode and no `nearshore_model` config key. When the `[nearshore]` pip extra is installed, SWAN+TruShore runs as the only nearshore model.

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
- **Cache policy:** TTL 6 hours (matching the extended cycle interval). On failure, retain last-good cache indefinitely. Stale TruShore data is always preferred to no data.
- **Optional separated service:** `weewx-clearskies-trushore` pip package for operators who want SWAN on dedicated hardware. API reads from it via `[trushore] service_url`. See Phase 4 of the implementation plan.
- **Memory budget:** Total SWAN memory must stay under 300 MB (both grid levels combined) to coexist with the API, MariaDB, Redis, and weewx on a 2 GB host.

## References

- Supersedes: ADR-084 (NWPS as primary nearshore source with supplementation)
- Related: ADR-094 (HRRR forecast wind source for surf scoring)
- Research: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md`
- Plan: `docs/planning/SWAN-TRUSHORE-PLAN.md`
