# MEM-3 — in-cycle memory growth investigation (static analysis @ 9afda8f, 2026-08-07)

Condensed from the MEM-3 read-only agent report. Context: marine service grows from ~1.0 GB idle
to ~2.9 GB during SWAN cycle, causing OOM kills (56 total). M-0b/M-0c deployed, saving ~734 MB.
Residual 1.9 GB growth traced below.

## Ranked memory holders during a full SWAN cycle

| # | Data structure | Location | Est. size | Verdict |
|---|---|---|---|---|
| 1 | `hrrr_wind_field` (49 grids, Python list\[list\[float\]\]) | service.py:341→swan.py:2522 | ~44 MB | Needed for run, but alive for entire function scope — unused after precompute |
| 2 | `gfs_wind_field` (9 grids, same structure) | service.py:422→swan.py:2523 | ~8 MB | Same: unused after `_stitch_wind()` |
| 3 | `blended_wind` (73 grids, stitched HRRR+GFS) | swan.py:3551 | ~22 MB new data (HRRR grids ref-shared) | Needed for precompute only |
| 4 | `bathymetry` (L1+L2+L3 depth grids) | swan.py:3317 | ~10-30 MB | Dead after `run_3level()` returns |
| 5 | `ww3_boundary` (station spectra) | swan.py:2791 | ~5-15 MB | Dead after `run_3level()` returns |
| 6 | `ofs_currents` (surface U/V arrays) | swan.py:3026 | ~5-10 MB | Dead after `run_3level()` returns |
| 7 | `disk_payloads` (ALL spots' payloads accumulated) | swan.py:3583 | ~20-40 MB | §12.2 violation: accumulates instead of writing per-spot |
| 8 | TTLCache spot payloads (7-day TTL) | swan.py:3717 | ~10-20 MB/spot | Needed at idle for endpoint serving |
| 9 | `runner` instance (config, parsed data) | swan.py:3347 | ~1-2 MB | Dead after spectral results extracted |
| 10 | `forecast_dicts` + `transect_by_time` per spot | swan.py:3594/3613 | ~1-2 MB/spot | Needed, scoped |

**Traced total: ~120-180 MB** of identified Python objects at peak.

## The gap: ~900 MB-1.2 GB unexplained by static analysis

The observed ~1.9 GB growth (1.0 GB→2.9 GB) minus ~120-180 MB traced objects leaves ~900 MB-1.2
GB unaccounted for. Three likely sources (require live measurement to confirm):

1. **CPython arena fragmentation (the "RSS ratchet").** Prior SWAN cycles (and the pre-M-0b code)
   allocated ~484 MB of spectral arrays as Python `list[list[float]]`. Each Python float is 28
   bytes + 8 bytes pointer = 36 bytes/element, allocated in CPython's 256 KB arenas. When these
   objects are freed, **CPython does NOT return arenas to the OS if even one object in them is
   still alive.** The M-0b fix stops CREATING those objects, but arenas from prior allocations
   (or shared arenas where small long-lived objects landed alongside the spectral data) may never
   be returned. This ratchet effect means RSS only goes UP, never down, until the process restarts.

2. **SWAN Fortran subprocess memory within the cgroup.** The SWAN binary runs as a subprocess
   (separate PID) but its RSS counts toward the SAME cgroup memory limit. L1 spectral array alone:
   ~9,000 cells × 2,520 spectral bins × 8 bytes = ~181 MB. L2 is larger. If SWAN hasn't exited
   before the Python precompute allocates heavily, the two overlap.

3. **Transient SPECOUT parsing peak.** `swan_runner.py`'s `_parse_output()` creates many temporary
   Python list objects while parsing SPECOUT files. Even though M-0c gated the energy matrix
   construction, the parse step itself builds temporary objects that claim arenas.

## Recommended cuts (ranked by estimated savings)

| # | Cut | File:line | Savings | Risk |
|---|---|---|---|---|
| 1 | `del hrrr_wind_field, gfs_wind_field, blended_wind` after precompute loop | swan.py: after ~3704 | ~50-74 MB | None: no reads after that point |
| 2 | `del bathymetry, ww3_boundary, ofs_currents` after `run_3level()` | swan.py: after ~3484 | ~30-55 MB | None: no reads after that point |
| 3 | Write `disk_payloads` per-spot or from TTLCache instead of accumulating | swan.py:3583-3734 | ~20-40 MB | Structural: disk-write atomicity changes |
| 4 | `del runner` after extracting spectral results | swan.py: after ~3557 | ~1-2 MB | None: no reads after extraction |
| 5 | Remove `exc_info=True` from per-timestep loop handlers | swan.py:2469, 2512 | Negligible | §12.4 compliance |

## §12 violations found

- **§12.2:** `disk_payloads` accumulates full payloads across ALL spots before writing.
- **§12.3:** No explicit `del` at any high-water-mark point (wind fields, bathymetry, boundary,
  currents, runner all stay alive as locals long past their last use).
- **§12.4 (potential):** `exc_info=True` in per-timestep exception handlers captures traceback
  frames; low risk unless logging handler buffers.

## Open: live measurement needed

The ~900 MB-1.2 GB gap requires live instrumentation to diagnose:
- `tracemalloc` snapshot comparison (before vs. after `run_3level()`)
- `/proc/<pid>/smaps` to identify RSS pages not backed by tracked objects
- `ctypes.CDLL("libc.so.6").malloc_trim(0)` after explicit `del` to test if arena pages
  can be returned
- Process-restart between cycles (crude but tests whether fragmentation is the dominant cause)
