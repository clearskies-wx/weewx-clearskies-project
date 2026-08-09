# ROUND BRIEF — S2 re-land: STOFS wlevel provider, memory-safe (L1-BOUNDARY-REBUILD-PLAN)

**Round identity:** S2 re-land after the 2026-08-09 OOM rollback (decision log, session
5). Lead: coordinator. Dev: `clearskies-api-dev`. Tests: the reverted S4b S2-test
commits are re-landed BY THE DEV via `git revert` of the revert commits, then amended —
see "Re-land mechanics". QC: Gate S. **Repo:**
`c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`. Dispatches after G-Accept
closes (one round at a time; lead states HEAD at dispatch).

**Why the first landing died (read the decision-log entry "DEPLOY `3065289` FAILED"):**
`stofs_wlevel.py` held each hourly field as the FULL CONUS-west grid (2145×1377) in
nested Python float lists (~100+ MB/grid), × 73 forecast hours ≈ 7 GB → OOM crash loop
on librewxr (~1.7 GB free). The revert was surgical: S2 production (`5d9d88b`) + its 3
test commits (`e9ef833`/`6c89be9`/`04997b3`) — reverts `48dcdb5`/`b48eb22`/`9a88c8d`/
`439aa7c`. S3 and its tests were NOT reverted.

## BINDING RE-LAND CONSTRAINTS (plan §S2, rewritten)
1. **Subset at extraction.** The eccodes/pygrib extraction returns ONLY the rows/cols
   covering the requested bbox + a 2-cell pad — computed from the message's own grid
   coordinates before materializing values. The full-grid array may exist only
   transiently inside the per-message decode, released before the next hour's fetch.
2. **Compact storage.** Extracted fields are numpy `float32` arrays (the repo already
   ships numpy), never nested Python lists. The per-field dict may carry the subgrid's
   own lat/lon origin+deltas for sampling.
3. **Memory KAT (test side).** For a production-shaped bbox (~1°×1°), assert the
   returned 73-field list's total array bytes < 50 MB (`sum(f.values.nbytes)`), and
   assert values dtype is float32. This KAT must FAIL against the reverted design
   (demonstrate by mutation: store full grid / tolist()).
4. **Fetch-path peak-memory accept row (lead runs at deploy):** RSS of the service
   sampled across the STOFS fetch window; the fetch must not add more than ~200 MB
   over the pre-fetch baseline.
5. Everything else from the original S2 design + the six rulings stands unchanged
   (water-level only; region tokens; per-cycle gap semantics; nearest-2h sampling;
   loud chain; `sample_wlevel_at` plain function). The bias gate (−0.044 m PASS,
   session-5 decision log) carries forward — do NOT re-run it; the lead re-checks at
   cutover only if NOAA changes something.

## Re-land mechanics
Start by reverting the four revert commits (restores the original code+tests exactly),
then apply the memory redesign as follow-up commits — this preserves both histories
and lets the diff show exactly what the redesign changed. Commit order: reverts first
("S2 re-land: restore"), then the redesign ("S2 re-land: subset-at-extraction +
float32"), then test updates (memory KAT + any KAT signature drift).

## READING LIST
1. Plan §S2 (reopened status line) + the session-5 incident decision-log entry.
2. `git show 5d9d88b` — the original implementation you are restoring+redesigning.
3. The reverted test files (via `git show 5d9d88b`-era paths or the revert commits).
4. `providers/wind/hrrr.py` — the existing subset-at-extraction idiom for NOMADS grids.
5. `docs/planning/briefs/L1-PHASE-S-DEV-BRIEF-2026-08-09.md` §MANDATORY BLOCKS pointer.

## SCOPE
Same allowlist as the original S2 (stofs_wlevel.py new, swan.py tide site,
swan_runner.py wiring) + the 3 restored test files. Nothing else. NEVER the full suite.
**SCOPE-ACK REQUIRED before code**, per standing process — the lead confirms.
