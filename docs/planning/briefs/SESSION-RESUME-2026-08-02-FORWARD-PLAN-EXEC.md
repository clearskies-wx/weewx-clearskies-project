# Session state — MARINE-FORWARD-PLAN execution (2026-08-02/03)

## ═══ RESUME HERE (rewritten pre-compaction, 2026-08-03 ~03:00 UTC) ═══

**Role:** Coordinator. **Mission:** CONTINUE EXECUTING `docs/planning/MARINE-FORWARD-PLAN.md`.
**Standing directive:** "ok continue autonomously with plan implementation" (chat 2026-08-02).

## ── CURRENT STATE SNAPSHOT ──
**Deployed:** marine = `2e67966` (librewxr proc 02:57:32Z; carries H5 pipeline-wind,
resolution refinement 1m/0.5m, waveShapeClassification, swellDominance ratio, NDBC fix,
C8 bool-return); dashboard = `fc93876` (weather-dev; carries D1 phantom deletion, chart
tier fix, transect marker removal); config service = `692ad76` (weather-dev port 9876).
**ALL repos pushed:** marine `2e67966`, dashboard `fc93876`, stack `692ad76`,
meta `c3f7505`, api `f10e8ce`.

**Segment geometry:** operator re-drew the HB segment to 1,610m / 162 transects (was 315m/32
after an admin save truncated it). Next cycle will pick up the new geometry via forced full
run (geometry change → cold start). This is the FIRST thing to verify on resume.

**CLOSED THIS SESSION (10 tasks, all deployed):**
1. C9 — Auto/Override exposure labeling + config-service deploy (stack `692ad76`)
2. C8 — forced-full-run false-success fix (marine `f2b3ce0`, audit PASS)
3. D1 — delete phantom fields partitionBreakInfo + shadowFaceHeight (dashboard `54b1563`)
4. NDBC V3-F8 — station ID .upper() normalization + negative-cache 404s (marine `02feb1d`)
5. swellDominance — continuous 0.0-1.0 ratio instead of buckets (marine `a751c9a`)
6. Beach profile + heatmap chart tier fix — Math.abs on break distances (dashboard `9aa67a8`)
7. waveShapeClassification — per-hour wave shape on surf forecast (marine `6d489da`)
8. Remove transect markers from public view (dashboard `fc93876`)
9. 1D transect resolution — PCHIP 1m analytical + 0.5m SurfBeat (marine `f13e475`,
   operator-approved trigger 3)
10. H5 — HRRR wind interpolation moved from request-time to pipeline-time (marine `ba515ed`
    + dead imports `2e67966`, audit PASS 0 functional defects, 2 findings remediated)

**OPERATOR Q&A RULINGS (all recorded in plan decision log, meta `3c47bcd`):**
Q1 firewall resolved. Q2 D1 delete 2 phantom fields (waveShape is real bug → fixed).
Q3 covered by Q2. Q4 D5 eyeball: 3 findings (outer break=bathy resolution, transect
markers=removed, smoothing=pending). Q5 NDBC fix approved+deployed. Q6 TA-C21 confirmed.
Q7 C-E11/C-E12 resolved by C3 (24h stationary restore). Q8 transect spacing: auto+slider
future task, L1/L2 skip pinned. Q9 swellDominance ratio deployed. Debug trace: keep on.
Single-flight: superseded by H5 pipeline-wind fix. H5 HRRR wind: pipeline-persisted,
endpoint fetch removed, warming thread deleted.

**DISPATCHABLE NEXT (autonomy grant, in order):**
1. **C3 — restore 24h stationary fast-cycle scope** (APPROVED, both H5 and C3 approved
   this session). The fast fill currently does 1 stationary snapshot per hour. Should do
   24 stationary snapshots (one per forecast hour, 0-24h). The `stationary_sequence`
   code path already exists in `swan_formats.py` (T1.0, implemented 2026-07-29) but is
   only used by the FULL run, not the fast fill. The fast fill uses
   `run_stationary_full_nest()` → `run_3level(stationary=True)` which does a single
   `COMPUTE STAT`. Need to change it to use the sequence path for 24 timesteps.
   Key constraint: each stationary snapshot needs its own HRRR wind for that forecast
   hour. The fast fill currently gets ONE HRRR wind field. Needs 24.
   Operator context: "running 24 stationary runs for each transect will still be faster
   than running it non-stationary." L1 is 37×27 km (well under 100km threshold for
   stationary per SWAN manual). All 4 levels already use stationary sequence in the
   full run (T1.0). Estimated fast-cycle time: 24 × ~33s/snapshot = ~13 min SWAN +
   ~12-14s 1D pipeline = ~14 min total (vs current ~33s for 1 snapshot).
   L1/L2 skip for fast cycle: PINNED by operator ("worried about losing wind effects").
2. **Heatmap smoothing** — interpolate discrete transect columns into smooth shapes
   (dashboard). Operator: "instead of showing these as pixelated individual transects,
   would it be better to smooth these into shapes." Not yet scoped.
3. **Config prjc1 → PRJC1** — operator admin UI action (code fix deployed).
4. **Outer break detection** — root cause = CUDEM bathy resolution doesn't capture
   sandbars. Resolution refinement (1m) may help slightly but won't create features
   that aren't in the data. Needs real survey data for bar-driven breaks.
5. Gate D formal close, Gate C after C3/C4, V1/V2 weather-dependent.

**Known findings/residuals (tracked, don't re-find):**
- `hrrr.py` `bbox_for_location()` orphaned (no production callers after H5; not deleted,
  MUST-NOT-TOUCH in H5 scope)
- `test_surf_spectral_extractions.py` vestigial `hrrr_provider.fetch` monkeypatch (harmless
  no-op, not on any task's allowlist)
- SurfBeat strip at 0.5m = ~400-1000 points, 1D SWAN grid — runtime not yet measured live
- PROVIDER-MANUAL cache payload table updated to 9 keys (was stale at 6)
- `_is_station_active()` dead 404-status-code branch (ProviderHTTPClient always raises)
- HeatMapCard break-zone-band overflow near x-domain minimum (pre-existing)
- 4 orphaned locale keys from transect marker removal (cleanup pass queued)
- 5 pre-existing wizard test failures (earthquake ×4, topology ×1)

**Agent roster:** `l4-rewrite` (marine coder, deep context), `d4-dashboard` (dashboard),
`round1-auditor` (adversarial auditor). All resumable via SendMessage by name.

## Execution pattern (proven this session)
Brief → scope-ack → GO → implement → closeout → adversarial audit (for significant
changes) → lead gate (independent pytest + stat + spot-check) → push → deploy
(cycle-window discipline) → reality gate → plan record.
