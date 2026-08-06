# MEM-2 — in-cycle memory holders (static analysis @ 2bb1cd1, 2026-08-06)

Condensed from the MEM-2 read-only agent report (full text in session transcript). Context:
marine service holds 3.1G anon RSS mid-cycle (3.5G peak) vs ~0.5G historical budget.

## Ranked candidates for the 3.1G

**#1 — `SWANRunner._spectral_results[spot_id]` untrimmed per-transect 2-D spectral carrier
(LIFECYCLE fix, not architectural).**
- Built at `swan_runner.py:6236-6251`; per-entry construction at `swan_runner.py:1062-1071`
  attaches `freqs_hz`/`dirs_deg`/`energy` (:1065-1067) by REFERENCE from
  `specout.station_timesteps[curve_idx][t_idx]` (:1029).
- Energy matrix shape from code: CIRCLE 72 dirs, msc=34 → **35×72 = 2,520 floats** per matrix
  (swan_formats.py:1663, :1643-1644) — NOT the assumed 50×36.
- Count: 162 transects × 34 ts (full run) = 5,508 entries (matches D-1b fact-pin's on-disk
  measurement 95.5% of 223MB). In-memory ~90-95 KB/matrix as Python lists → **~90 MB
  (quick-update 24 ts, if ref-shared) to ~484 MB (full run, no sharing)** per cycle.
- **Recurs ~hourly**: quick-update (`run_stationary_full_nest` → `run_3level`, 24 snapshots,
  ~20×/day) rebuilds it too — not just the 4×/day full runs. Alloc/free churn at this size
  plausibly ratchets RSS (CPython arenas not returned to OS).
- **ZERO readers of the three fields anywhere** — confirmed independently by
  M0-D1B-FACT-PIN Q2 AND the trim function's docstring; only `components`/`handoff_depth_m`/
  `handoff_source_level`/`clamped` are consumed downstream (incl.
  `_precompute_swelltrack_for_spot`, which receives the untrimmed dict directly).
- Fix shape: stop attaching the dead fields at construction (all attachment sites, incl.
  inside handoff_by_transect values), or trim immediately after run_3level returns.
- UNKNOWN (needs live measure): ref-sharing ratio across transects (swings 90↔484 MB);
  whether arenas return to OS between cycles.

**#2 — startup monolithic `json.loads` of forecast_cache.json** (swan.py:1482-1546) —
structurally present but its dominant driver (spectral key) was trimmed by D-1b; post-D-1b
file ~17MB. Read-side streaming parser explicitly NOT approved (comment :1454-1463).

**#3 — per-request pipeline recompute, no memoization (ARCHITECTURAL — parked).**
`endpoints/surf.py:1160-1243`: swelltrack-cache miss → full 162-transect pipeline per
request, ~78-105 MB transient per request (all-timesteps miss), every ~50s per the observed
storm; result never written back anywhere (:1244-1270). Fix = new caching layer OR fix why
precompute cache misses — both design decisions, stays parked for operator.

Also noted: `TransectResult` gained a 4th same-grid array (`combined_roller_energy_profile`,
X3) — pure per-call transient, not in cache codec. MEM-1's "transect key is huge" suspicion
likely WRONG — `payload["transect"]` built from the single diagnostic CURVE, not 162
transects (plausible correction, not fully traced).
