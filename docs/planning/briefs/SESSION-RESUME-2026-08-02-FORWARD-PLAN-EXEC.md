# Session state — MARINE-FORWARD-PLAN execution (2026-08-02/03)

## ═══ RESUME HERE (rewritten 2026-08-03 ~06:00 UTC, post-C3 implementation) ═══

**Role:** Coordinator. **Mission:** CONTINUE EXECUTING `docs/planning/MARINE-FORWARD-PLAN.md`.
**Standing directive:** "ok continue autonomously with plan implementation" (chat 2026-08-02).

## ── CURRENT STATE SNAPSHOT ──
**Deployed:** marine = `2e67966` (librewxr proc 02:57:32Z; carries H5 pipeline-wind,
resolution refinement 1m/0.5m, waveShapeClassification, swellDominance ratio, NDBC fix,
C8 bool-return); dashboard = `fc93876` (weather-dev; carries D1 phantom deletion, chart
tier fix, transect marker removal); config service = `692ad76` (weather-dev port 9876).
**ALL repos pushed (except marine C3 commit):** marine deployed=`2e67966`, local HEAD=`052906f`
(C3 not yet pushed); dashboard `fc93876`, stack `692ad76`, meta needs push, api `f10e8ce`.

**Segment geometry:** ~~VERIFIED... Working correctly~~ **CORRECTED 2026-08-03 (audit):** the
"162 open" in that very log line meant ZERO structure-affected transects — the pier had been
wiped from config at 22:12:54Z (admin-save clobber; API copy never carried coordinates) and the
transect count was verified while invariants 3+7 were firing. Pier restored 06:11Z (interim
manual restore, both configs). Full story + all Opus-window audit findings:
[AUDIT-OPUS-WINDOW-2026-08-03.md](AUDIT-OPUS-WINDOW-2026-08-03.md) — READ THAT FIRST on resume.

**CLOSED THIS SESSION (continuation, 10 tasks from previous compaction + this session):**
Previous 10 tasks: C9, C8, D1, NDBC V3-F8, swellDominance, chart tier fix,
waveShapeClassification, transect markers, 1D resolution, H5 — all deployed.

**THIS SESSION:**
1. Segment geometry verified (162 transects, 1,610m)
2. Phase LM rewritten — ortho imagery approach replaces landmarks (NAIP + ESRI)
3. C3 implementation complete (marine `052906f`) — audit needed before push/deploy

## ── C3 STATUS ──
**Implementation:** COMPLETE. Marine `052906f` (local, not pushed).
- `swan_runner.py`: `run_stationary_full_nest()` trims wind to 24h, passes
  `stationary_sequence=True` to `run_3level()`
- `swan.py`: `_run_quick_update_locked()` builds 24 hourly tide predictions, merges all
  24 returned forecast points into cache
- `tests/test_c3_24h_fill.py`: 4 KATs all pass
- 39 regression tests pass (stationary sequence, quickupdate merge, H5, serve-nothing)

**Lead gate:** PASSED (independent verification of tests, code spot-check of all 5 design
elements, allowlist diff clean).

**Adversarial audit:** NEEDED — was dispatched but may have been killed by compaction. Re-
dispatch before push/deploy. The audit brief is in the previous session context (commit
`052906f`, 3 files, focus areas: wind trimming edge cases, tide/valid_times alignment,
cache merge collision, swelltrack merge, scope violations, doc-code sync).

**Doc-code sync residual:** PROVIDER-MANUAL.md §"Two-tier schedule" still describes fill as
"single snapshot" — update needed with or after push.

## ── DISPATCHABLE NEXT (in order) ──
1. **C3 audit + push + deploy** — re-dispatch auditor, remediate findings, push, deploy via
   `scripts/deploy-marine.sh`, reality gate (verify 24 forecast points per fill in the
   service journal).
2. **C4 — modelStatus grading** (UNBLOCKED, operator-approved threshold rule). Owner:
   `clearskies-api-dev`. `endpoints/surf.py` `_determine_model_status` + pipeline
   bookkeeping. Wire semantics change → API-MANUAL same round.
3. **C7 — bimodal facing investigation** (investigation-first, then fixes). 240.0° vs 216.4°
   transect dual-computation from non-surf endpoints.
4. **Phase LM — ortho imagery** (3 tasks: API provider, dashboard background, config UI).
   Multi-repo. NAIP proxied+cached, ESRI direct-browser. See plan §LM.
5. **Heatmap smoothing** — interpolate discrete transect columns. Not yet scoped.
6. Gate D formal close → Gate C after C3/C4 → V1/V2 weather-dependent.

## ── PHASE LM DESIGN (operator-directed 2026-08-03) ──
Ortho imagery replaces the original landmark/marker approach for heatmap geographic context.
- **NAIP (US):** API provider proxies + caches tiles. Browser → Caddy → API → USGS.
  Public domain, no limits. Cached server-side.
- **ESRI (global):** API provides config only (tile URL + attribution). Browser fetches
  tiles directly from ESRI. No proxy, no cache, no terms issue. Non-commercial, 2M tiles/mo.
- **Provider selection:** NAIP preferred for US, ESRI for non-US. Configurable in admin.
- **Dashboard:** heatmap renders ortho as background, wave data as semi-transparent overlay.
- All operator rulings recorded in plan §LM and decision log.

## ── KNOWN RESIDUALS (don't re-find) ──
Same as previous resume state plus:
- PROVIDER-MANUAL.md "Two-tier schedule" stale (C3 doc-sync)
- 4 orphaned locale keys from transect marker removal
- 5 pre-existing wizard test failures (earthquake ×4, topology ×1)
- `hrrr.py` `bbox_for_location()` orphaned (H5 residual)
- HeatMapCard break-zone-band overflow near x-domain minimum (pre-existing)
