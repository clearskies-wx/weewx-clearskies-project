# MEM-3 / M-0d Session State — 2026-08-07 ~06:10 UTC

## What's deployed on librewxr (commit c6d6447)

Five commits pushed and pulled, service restarted at ~06:05 UTC:

1. `9b6b122` — **M-0d: precomputed profile store (SQLite)**. Per-spot SQLite DB at
   `/var/run/weewx-clearskies/swan/profile_store/{spot_id}.db`. Writes untrimmed
   TransectResult arrays during the precompute loop. beach_profile.py reads from store
   instead of running on-demand pipeline. reestablish_spot teardown deletes the DB.
2. `b4875ab` — **MEM-3: explicit del** of dead run-phase data (runner, bathymetry,
   ww3_boundary, ofs_currents, domains, wind fields) at high-water-mark points. ~80-130 MB
   savings.
3. `e5331f8` — **MEM-3: tracemalloc instrumentation**. Three snapshots per SWAN cycle
   (pre-run, post-run_3level, post-precompute). Gated by `[swan] trace_memory = true` in
   marine.conf (the marine service's JSON config, NOT api.conf).
4. `c06445a` — **Fix: trace_memory config key** added to SwanConfig + WAL mode on the
   profile store SQLite DB.
5. `c6d6447` — **F1/F2 adversarial audit remediation**: read_closest_timestep() now uses
   two-query pattern (SELECT timestep first, then SELECT data WHERE timestep=?) instead of
   fetchall() that loaded ~720 MB. exc_info=True removed from per-timestep loop handler.

## What's in progress

- **Background poll** (task buztji1qn) watching for cycle completion + tracemalloc output.
  Checks every 30s for up to 30 min.
- **Radar container is STOPPED** on librewxr to give the marine service memory headroom.
  Must be restarted after tracemalloc data is collected:
  `ssh -F .local/ssh/config ratbert "lxc exec librewxr -- docker start librewxr-librewxr-1"`
- **trace_memory = true** is set in `/etc/weewx-clearskies/marine/marine.conf` (JSON).
  Must be set back to false after collecting one cycle's data.

## What the tracemalloc data will show

Three snapshots fire during the SWAN cycle in `_run_all_spots_locked()` (swan.py):
- Snapshot #1 (pre): before run_3level() — baseline
- Snapshot #2 (post-run_3level): after SWAN binary completes + spectral parsing — peak
- Snapshot #3 (post-precompute): after per-spot precompute loop + MEM-3 del cuts — residual
Each logs: top-20 allocators by file:line, RSS, delta from previous snapshot, malloc_trim test.

## What the memory timeline showed (from the earlier cycle before M-0d fix)

| Time | Memory | Event |
|---|---|---|
| 04:07:50 | 1.65 GB | SWAN L1 running |
| **04:08:20** | **3.87 GB** | **+2.2 GB spike — SWAN output parsing** |
| 04:08:50 | 3.58 GB (peak 3.97 GB) | L2/L3 or parsing |
| 04:10:20 | 2.34 GB | run_3level returned, MEM-3 dels fired (-1.6 GB) |
| 04:10:50+ | 2.5→2.85 GB | Precompute loop climbing |

The 2.2 GB spike at L1 completion is the target. MEM-3 investigation estimated ~120-180 MB of
traced Python objects, leaving ~900 MB-1.2 GB unexplained — suspected CPython arena fragmentation.

## Adversarial audit status

- **Auditor**: clearskies-auditor, completed at commit 9b6b122
- **F1 [HIGH]**: FIXED (c6d6447) — fetchall loading 720 MB → two-query, ~10 MB
- **F2 [MEDIUM]**: FIXED (c6d6447) — exc_info=True removed from loop
- **F3 [MEDIUM]**: TRACKED — doc-code sync gap (ARCHITECTURE, PROVIDER-MANUAL, API-MANUAL,
  OPERATIONS-MANUAL all need M-0d updates). Ships when round closes.
- **F4 [LOW]**: TRACKED — no staleness ceiling on profile store reads

## Other session work completed

- **rules/coding.md §12** — eight memory management rules added (committed to meta repo)
- **.claude/agents/clearskies-auditor.md** — memory discipline added to reading list, audit
  categories, and adversarial scope
- **Plan amendments** — Task M-0d added, decision register items 14 + 15, doc table updated
- **MEM-3 scratch doc** — docs/planning/scratch/MEM-3-CYCLE-MEMORY-2026-08-07.md

## Outstanding items

1. Collect tracemalloc data from the current cycle (background poll running)
2. After collection: set trace_memory=false, restart radar container
3. Verify profile store is populated and beach profile/heat map endpoints respond <2s/<5s
4. F3 doc-code sync (docs updates)
5. F4 staleness ceiling decision
6. Deeper memory investigation based on tracemalloc results (the ~1 GB gap)
7. Round X reality gate is still HELD (plan register 11g — checker design pass needed)
