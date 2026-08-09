# SESSION SCRATCH / HANDOFF — L1-BOUNDARY-REBUILD-PLAN execution (2026-08-08 → 09)

**Read FIRST when resuming, with `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md`
(the plan — phase checkboxes + gate records + OPEN OPERATOR QUESTIONS section are all
current as of the 2026-08-09 checkpoint) and
`docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` (authority).**

## ⏭ RESUME HERE — exact next actions (2026-08-09 checkpoint)
1. **Finish B5** (partial commit `c217d8f`, PUSHED). DONE: test_boundary_reconstruction.py
   (22 tests — K1/K2/K3/K4/K5/K7, with in-file falsifiability controls for K1+K5); 2
   authorized deletions (ledger in commit body); 5 station-mock repairs (42 tests green);
   3 more files verified no-change-needed. **REMAINING (fresh test-author round, brief
   `L1-PHASE-B-TEST-BRIEF-2026-08-09.md`):** (a) tests/test_partition_fields.py — K6
   (GLWU hourly cadence + 2.5 km corridor, independent arithmetic) + the migrated
   aggregated-cycle-fallback-WARNING idiom vs `fetch_partition_corridor_with_cycle_fallback()`
   + optional shared-http-client-reuse KAT; (b) live mutation-and-revert falsifiability
   demos for K1/K2/K5 (Gate B row 1 needs them — the auditor can perform them itself if
   the test round doesn't).
2. **Gate B blind audit** — brief READY at `briefs/L1-GATE-B-AUDIT-BRIEF-2026-08-09.md`
   (already includes the 35-frequency correction + commit list; append B5's commit ids).
3. **B-Accept deploy** — deploy-marine.sh FROM META ROOT, between cycles (check journal
   "SWAN: starting" vs "full SWAN cycle complete"; pgrep -x swan). Protocol per plan
   B-Accept: matched cycle vs the banked station-boundary baseline (level1/BOUND_* files
   on librewxr from the 18z run + W-Accept's reality-gate numbers), boundary Hs at the 4
   old station positions ±10% vs same-cycle .spec m0, headline delta ≤15% recorded,
   wall-clock ≤ +3 min vs ~37 min, boundary file count/bytes/read-time measured.
   CAPTURE THE SERVED PAYLOAD BEFORE DEPLOYING (R5's lesson).
4. **W6** (operator-ruled): fix HRRR Lambert-parameter extraction — task spec in plan
   Phase W. Dispatch AFTER Gate B closes (one round at a time in the marine repo).
   dev brief pattern: `briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` mandatory blocks.
5. Then Phase G (briefs not yet written; G sites pre-verified below), then S, A,
   C1+Gate C, V per plan order.

## Operator authorizations in force (this session, 2026-08-08 chat)
- "As coordinator, you have permission to push/deploy as needed."
- "Architectural changes called for within the plan are pre-approved" (the plan's
  Pre-approval register P1–P15 is the grant; anything outside it → STOP and ask).
- "Work through the entire plan and only stop if there are architectural issues not
  foreseen in the plan."
- Standing rules: no AskUserQuestion; plain-English reports; scratch files maintained.

## Phase status

| Phase | Status | Notes |
|---|---|---|
| R5 close (SURF-REMEDIATION dependency) | **DEPLOYED, accept pending** | Pushed + deployed 2026-08-08 23:35:16Z (deploy-marine.sh verify: running a399eb6, health 200). Awaiting first post-deploy full cycle (00Z HRRR, ~01:07Z) → run R5-Accept checks from SURF-REMEDIATION plan Phase R5 (partitionIndex uniformity, single outer break, ≤6 markers, INV-13→0, headline unchanged). Watcher armed. |
| DOC | **CLOSED — Gate DOC PASSED** | Meta `9dc1fe3` (11 files, docs-only). Blind audit 7/7 rows, 0 findings. ADR shipped as **ADR-104**. Plan checkboxes updated. NOT yet pushed. |
| W | **CLOSED — Gate W PASSED, deployed `95abc74` (proc 00:41:16Z), W-Accept recorded in plan** | Commits: marine f7c2b04/35f98f6/9cb1b43/6ab1df0/84f4757/95abc74 (all pushed+deployed); meta 96070c2/5870b45. Byte-identity deviation root-caused (rotation approximation depends on fetch bbox — inherent to P6; headline −5.3% on wind-sea day). Real drill banked. Reality gate: model 0.62 m vs buoys 0.8/0.9 m, dir gap ~35–40° = pre-plan boundary defect, the V1/V2 "before" measurement. |
| B | B1–B4 ✅ (marine 10c8d70/f81e520/dcfd84a/f190fcd + r-pin 5ebc1fa; doc-sync meta b22e80f); B5 IN FLIGHT (checkpoint-committed); Gate B + B-Accept PENDING | **B NOT DEPLOYED** — librewxr runs 95abc74 (station boundary). Gate B audit brief ready. |
| G | not started (sites pre-verified, see below) | |
| S | not started | two deploys: S1+S4a currents, S2+S4b wlevel |
| A | not started | |
| C | C2/C3 CODE DONE + lead-verified (dashboard `7cfd475`+`e8be970`, meta `edd3d89`; 46 tests pass, my re-run). NOT yet deployed to weather-dev; visual accept + Gate C wait for C1. 3 approved plan-text deviations recorded in closeout + DASHBOARD-MANUAL. | R5 CLOSED 00:20Z. C1 (server aggregates, endpoints/surf.py) later — marine repo single-threaded with W/B/G/S. |
| V | not started | |

## Coordinator findings so far
- **ADR numbering in plan is stale:** plan says "ADR-101" for the new ADR; ADR-101
  (surf-score-geometric-mean), ADR-102, ADR-103 already exist. New ADR takes **ADR-104**.
  Lead call, recorded in DOC brief.
- **ADR-103 (Multi-Station Real Spectral Boundary, Accepted 2026-08-06)** documents the
  station-boundary design this plan's Phase B deletes (P4/P5). Plan's DOC.1 names only
  ADR-093 + ADR-100 amendment notes; ADR-103 also needs one (superseded-pending, tagged).
  Lead call, added to DOC scope — doc-code sync requirement, not new architecture.
- Meta repo HEAD `245e47b`; untracked planning files expected (plan + briefs, committed
  as part of DOC round or when convenient).
- Marine repo clean at `a399eb6` (R5, unpushed). Remote NOT ahead.

## Pre-flight facts
- librewxr deployed commit `b3f8092`, ExecMainStartTimestamp 2026-08-08 08:43:13 UTC.
- Full-cycle wall-clock baseline 31m57s (disk work tree, R4).
- Deploy: `scripts/deploy-marine.sh` FROM META REPO ROOT (running from marine repo
  silently no-ops the deploy — handoff warning).
- librewxr journal needs sudo; marine unit name `weewx-clearskies-marine`.

## Pre-round code verification (lead, 2026-08-08, marine HEAD a399eb6)
- Phase W sites ALL verified: `_HRRR_MARGIN_DEG=1.0` marine_config.py:1036 region,
  hrrr_bbox :1112-1120, service.py :337 ±1.0 bbox, wind_gatherer `_bbox_for_locations`
  :468-482 (caller :689), swan.py outer_bbox :2666/:2691/:2726/:3109/:3431/:4078,
  swan_formats NaN→"0.0000" :387-388, swan_runner `_write_current_txt` :2355,
  `_ZERO_BLOCK` :2408/:2431-2438.
- Phase G sites verified: geography.py `resolve_regime_horizon_km` :170-192 (shelf+10,
  fallback 40, GL 200), `RayResult` :135-152 (no open_water_resume field yet — G2 adds),
  swan_domain.py shelf+10 sizing :1123-1132, wrap-enclosure-at-full-horizon block
  :1169-1187.
- Phase B: `services/ww3_station_selection.py`, `ww3_station_catalogue.py`,
  `ww3_spectrum.py` exist; catalogue JSON at
  `weewx_clearskies_marine/data/ww3_station_catalogue.json` (plan path "data/..." is
  package-relative); `ww3_boundary_files_and_command` at swan_formats.py:2563.
- Briefs written: `L1-DOC-ROUND-BRIEF-2026-08-08.md` (dispatched),
  `L1-PHASE-W-DEV-BRIEF-2026-08-08.md` (ready, dispatch after Gate DOC).

## Parking lot (tracked findings, not this plan's scope)
- **Dashboard bundle-baseline methodology mismatch** (dash-phase-c, 2026-08-09): repo now
  code-splits per-route; ADR-033's 200 KB table (reference/clearskies-dev.md, pre-split)
  doesn't map. Measured: main entry chunk 203.00 KB gzip (nominally over budget,
  pre-existing), marine lazy chunk 41.73 KB (carries C2/C3). Needs its own
  methodology/budget ruling.
- **BeachProfileCardBody.test.tsx "D6 per-break zones" 2 tests fail pre-existing** at
  dashboard HEAD 749ba29 (foam-zone band fills removed 2026-08-05 `ad2ecf9`; test never
  updated). Stale-test protocol: surfaced, untouched.
- **Orphaned `shadowedTransect` i18n key** after C3 overlay removal (noted in
  DASHBOARD-MANUAL by dash-phase-c).
- **openapi-v1.yaml pre-existing drift** (docs-author finding, Phase DOC scope-ack):
  SurfForecast schema is missing already-live fields — scoring, breakPoints, tideLevel,
  modelSurfHeightMin/Max. Needs its own doc-sync round; NOT fixed in Phase DOC (additive
  P13 fields only).

## W-Accept baseline (captured PRE-deploy, 18z cycle, run 23:36→00:13:59Z on a399eb6)
- WIND.txt md5 `fb2e0e52e81f655d4dff07113075ecc1`, 1,120,722 bytes
  (`/var/lib/weewx-clearskies/swan/level1/WIND.txt`).
- level1/ boundary files: BOUND_W_46222/46253/46256 + BOUND_S_46223 (station path —
  ALSO Phase B's "last station-boundary cycle" reference).
- Cycle wall-clock: 23:36:18 → 00:13:59 ≈ 37m41s (incl. runner-loop fetches).
- Served headline h0 (18Z hour): face 1.089 m, min 0.838, max 1.089 (R5 accept capture).
- Old wind fetch bbox (URLs in journal): (-119.0039, 32.6534, -117.0039, 34.6534) = spot ±1.0°.
  New expected: L1 bbox + 0.3° ≈ (-118.48, 33.17, -117.48, 34.01).
- **Deploy timing:** restart triggers prev=None full run on current available HRRR cycle.
  If deployed BEFORE 00z HRRR posts (~01:05Z), the rerun is 18z = matched cycle → WIND.txt
  byte-compare valid. If 00z lands first, item 1 degrades to bbox/dims + value spot-check
  (record deviation).

## GATE EVENT — W3 guard fired live (2026-08-09 00:34:28Z, first post-W-deploy cycle)
- `no-publish: wind_coverage_failed` — fetched wind lat[33.0068,34.1641] lon[-118.4061,-117.5293]
  vs required (L1+pad) lat[33.1650,34.0058] lon[-118.4786,-117.4775]. **L1 itself IS fully
  covered** (lon needs [-118.179,-117.777]) — the assert wrongly required coverage of the
  0.3° FETCH pad, which the grib filter's inset/Lambert raggedness makes unreliable.
- Ruling: C-90 pattern — request domain+pad, REQUIRE domain. Plan W3's "(+ pad)"
  parenthetical resolved against the plan's own pad rationale (same-document ambiguity
  resolution). Fix dispatched to dev-phase-w: call sites require `domains.level1` bbox
  exactly; W2 NaN-raise remains the sub-cell backstop.
- **Silver lining — W-Accept drill item CAPTURED FOR REAL:** /health = "degraded", reasons[]
  carries the full wind_coverage_failed message; last-good preserved (surf 200,
  lastRunTime 23:40:26Z, h0 face 1.089 unchanged); loud retry loop, no publish. This IS
  the forced-drill evidence, end-to-end, unsynthesized.

## ~~OPEN OPERATOR DECISION — B2's `r` constant~~ RESOLVED 2026-08-09: operator accepted the recommendation ("Q1: ok"), **r = 1.0 pinned, marine `5ebc1fa`**. B-Accept unblocked. Historical record below.
Plan: `r` (wind-sea mean→peak period ratio, `Tp = r × WVPER`) measured-then-pinned,
bounds [1.10, 1.35], "out-of-bounds → STOP and surface, do not pick."
**Measured (station 46222 vs co-located gfswave cell, live):** 00Z r=1.0136, 06Z r=1.0559
(12Z: grid cell had no wind-sea data — only 2 of 3 cycles usable). Direction convention
independently CONFIRMED (agreement 2.4°/2.5°, no flip for GRIB2 — Lead Call 2 validated).
**Interpretation (recommendation, not ruling):** the WMO GRIB name for WVPER says "mean
period," but WW3's partitioned output is documented as partition PEAK period and NOAA maps
partitions onto those GRIB slots — measured r ≈ 1.0 says WVPER is already peak-like. The
plan's mean→peak premise appears miscalibrated, not the measurement.
**RECOMMENDED RULING: pin r = 1.0** (treat WVPER as peak; no inflation), evidence
documented in the module. Alternative: pin the measured mean ≈ 1.035.
**Status:** B1–B4 ALL COMMITTED (marine 10c8d70/f81e520/dcfd84a/f190fcd, doc-sync meta
b22e80f); placeholder loudly marked NOT-PINNED. The pin is a 1-line follow-up commit on
the operator's word. **Swell-side corroboration attempted, INCONCLUSIVE by confound:**
height-ranked grid partition ≠ the station's long-period peak train (grid SWELL1 period
jumped 4.2–11.0 s across cycles while the station peak held 17.8–19.0 s) — comparing
different physical trains, not evidence either way. Wind-sea pairs stand on their own.
A period-matched redo is parked if the operator wants deeper evidence. B-Accept deploy
HOLDS until r is ruled (deploying a knowingly-unpinned physics constant would pollute
the matched-cycle comparison).

## Lead rulings issued mid-round (record)
- **B2 AFREQ count = 35, not 34 (2026-08-09).** Dev-phase-b STOPped on plan-vs-manual
  mismatch. Empirical ground truth: deployed binary's own SPECOUT
  (`level2/SPEC_DWR_1.txt`) declares `AFREQ / 35`. msc=34 ⇒ count=msc+1=35 (manual :1532
  /:3719, codebase gamma comment agrees). Plan §2 template, PROVIDER-MANUAL B2 amendment,
  and B dev brief corrected (matrix = 35 rows × 72 cols). ADR-104 unaffected (doesn't
  carry the count). Pinned CGRID CIRCLE 72 0.03 1.0 34 unchanged.
- **Gate W F1 (accepted, MEDIUM-HIGH):** quick-update path gets W3 assert + WindCoverageError/
  CurrentCoverageError catches recording slugs, keeping return-False contract; one lead-directed
  KAT same commit; API-MANUAL §19.7 both-paths qualifier. (Reversed my earlier acceptance of the
  dev's quick-update exclusion; inside register P6.)
- **W stale-fixture rulings:** (1) test_swan_quickupdate_swelltrack_merge.py `_stitch_wind` empty→
  covering field, authorized; (2) Finding A: same fix for test_c3_24h_fill.py, test_h5_pipeline_wind.py,
  test_serve_nothing_on_failure.py, SAME commit as F1 remediation; (3) Finding B: test_service_hrrr_cadence.py
  harness gains load_grid_sizing_cache mock, SEPARATE commit labeled W1 follow-up. All intent-preserving;
  assertions must execute against real values.
- **C2/C3 rulings:** (1) empty-breakPoints branch unchanged, NO new prop (plan fallback presumed a
  selectable list; deviation recorded); (2) rotation ref = representativeTransectIndex row bearing →
  middle row → none; test pins math for sign-flip detection; (3) y-axis title "Transect", no fabricated
  unit (plan's "unit family" assumed metric axis; deviation recorded); (4) overlay removal = dim+hatch+
  legend; sr-only data column stays.
- **R5 accept #6 deviation:** pre-deploy payload not captured (coordinator miss) → criterion verified
  structurally (diff touches serving only). Recorded in SURF-REMEDIATION plan.

## Operator rulings 2026-08-09 (Q1–Q3, all closed — full text in plan decision log)
- Q1: `r` = 1.0 (marine `5ebc1fa`).
- Q2: page-weight budget = guideline not gate (ADR-033 amended, dev-reference updated).
- Q3: W6 created — fix HRRR Lambert extraction properly ("reading it properly, not
  estimating based upon wobble"). Dispatches after Gate B.
- Also: "targeted tests only, never full suite" reinforced → rules/agents.md sharpened
  (plan "full suite" baseline rows = changed-files + affected directory).
- Also: open questions live in the plan's OPEN OPERATOR QUESTIONS section, plain English
  → rules/coordinator.md §5 updated.

## Repo/deploy state at checkpoint (2026-08-09)
| Repo | HEAD (local) | Pushed? | Deployed? |
|---|---|---|---|
| marine | `5ebc1fa` + any B5 checkpoint commit(s) | pushing at checkpoint | librewxr runs **`95abc74`** (W phase). B NOT deployed. |
| dashboard | `e8be970` | YES | weather-dev serves it (C2/C3 live on weather-test; visual accept pending at Gate C) |
| meta | checkpoint commit (see git log) | pushing at checkpoint | n/a |
- Marine service healthy at checkpoint; known noise: INV-11 (operator item, SURF-REM
  plan), NDBC QuotaExhausted, HRRR Lambert WARNING (goes away with W6).
- Agents at checkpoint: test-phase-b wrapping (B5 partial commit); all others closed.

## Decision log (this session)
- 2026-08-08: Execution session started. Rules loaded (agents/verification/coordinator/
  process/dev-reference/ARCHITECTURE). Plan order DOC → W → B → G → S → A → V; C after
  R5 closes. R5 deploy+accept adopted as unblocking step (pre-ruled work from
  SURF-REMEDIATION plan, committed, undeployed — leaving it would contaminate W's deploy).
