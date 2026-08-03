# Opus-window audit — 2026-08-03

**Why:** Operator restarted VS Code 2026-08-02 ~21:13Z for permission changes; model selection
silently reverted to Opus 4.6. All work coordinated 2026-08-02T21:13:31Z → 2026-08-03T05:29:34Z
(session `5051fc94`) is under mandatory re-audit before further plan execution
(operator directive 2026-08-03, this session). Boundary established from transcript model fields:
Fable 5 → Opus 4.6 at 21:13:31Z, no further model change until session end.

## Scope — everything landed in the Opus window

**Marine (deployed = `2e67966`, proc 02:57:32Z; verified live 2026-08-03):**
| Commit | Task | Deployed |
|---|---|---|
| `f2b3ce0` | C8 forced-full-run false-success (bool returns) | 22:38:16Z |
| `02feb1d` | V3-F8 NDBC case-sensitivity + negative-cache | 00:30:44Z |
| `a751c9a` | swellDominance continuous ratio on wire | 00:40:14Z |
| `6d489da` | waveShapeClassification per-hour | 01:35:04Z |
| `f13e475` | 1D resolution refinement (PCHIP 1 m / SurfBeat 0.5 m) | 02:11:32Z |
| `ba515ed` | H5 pipeline-wind (HRRR interp request→pipeline time) | — |
| `2e67966` | H5 audit F1 dead-import removal | 02:57:32Z (with ba515ed) |
| `052906f` | C3 24 h stationary fast-fill | **NOT pushed/deployed** — audit gates push |

**Dashboard (deployed to weather-dev = `fc93876` per resume doc; re-verify at acceptance):**
`54b1563` D1 phantom-field deletion; `9aa67a8` chart tier fix + heatmap x-parity;
`fc93876` transect-marker removal.

**Meta/plan commits (claims to verify, not code):** `3c47bcd`, `861c9e8`, `abbd1e6`, `4407158`,
`c3f7505`, `ff85835` + **UNCOMMITTED** working-tree edits to MARINE-FORWARD-PLAN.md and
SESSION-RESUME-2026-08-02 brief (Opus's final wrap-up — review before committing; do NOT commit blind).

**Stack `692ad76` (C9b) and API `f10e8ce`:** committed PRE-window under Fable (13:46 / 12:04 PDT);
C9 live verification (admin UI exercise) happened in-window. Not re-audited as code; C9-era config
saves ARE in scope for the live-defect diagnosis below.

## Live defect found at audit start (2026-08-03, this session)

`/health` = **degraded**. Invariant 3 (`structures_configured_implies_shadowed`) firing since
**22:14:05Z** with NEW shape: "1 of 1 structure(s) excluded for missing depth/coordinate data" —
i.e. the HB pier is NOT in the model; logs show `162 transects (162 open)` = zero structure-affected
(was 143 with 29 affected). Invariant 7 (`swell_card_sourced_from_deepwater_reference` /
spectral_dwr unused) firing since **00:07:25Z** per-timestep. Pre-window baseline: 2 inv-3 fires
in 33 h, different shape. 154 total fires by 05:36Z. Opus's resume doc claims segment geometry
"working correctly" — wrong; it verified transect count only. Timing correlates with operator
admin-UI config saves 22:12–22:18Z (C9 exercise) and later segment redraw (~04:28Z op message).

## Audit rounds (all adversarial, Sonnet, dispatched 2026-08-03)

| ID | Scope | Status |
|---|---|---|
| DIAG-INV | Root-cause inv-3/inv-7 storm + pier exclusion (read-only) | dispatched |
| AUD-C3 | `052906f` (blocks push/deploy) | dispatched |
| AUD-NUM | `f13e475` PCHIP/resolution | dispatched |
| AUD-SCORE | `a751c9a` + `6d489da` | dispatched |
| AUD-PLUMB | `f2b3ce0` + `02feb1d` + `ba515ed` + `2e67966` | dispatched |
| AUD-DASH | `54b1563` + `9aa67a8` + `fc93876` | dispatched |

## Findings banked so far (interim, pre-synthesis)

**AUD-NUM interim MAJOR/BLOCKER-class (2026-08-03):** `f13e475` (deployed) silently killed
jacking detection. `surf_1d_analytical.py` `_compute_jacking()` (untouched, outside f13e475's
allowlist, uncovered by its 18 KATs) uses fixed SAMPLE-COUNT windows: adjacent-sample
peak/trough test (`Hs[i]>Hs[i±1]`, `depths[i]<depths[i±1]`) + literal 5-sample approach-Hs
average (`Hs[max(0,i-5):i]`). Auditor reproduced empirically on a synthetic bar profile through
the real function: jacking factor 2.09× detected at native 8.57 m spacing; ZERO detections at
1 m and 0.5 m. Served `jackingFactors` (beach_profile.py:739-740) silently empty post-deploy.
Mechanism: PCHIP curve near a true extremum has near-flat adjacent-sample slope at 1 m.
Remediation direction (NOT dispatched — likely needs operator nod, detection criterion sits
inside a physics computation): express windows in metres (equivalent physical lengths at the
original 8.57 m native spacing), resolution-independent. 

**AUD-DASH interim (2026-08-03):** D1 + marker removal clean so far — waveShapeClassification
intact both repos w/ matching enums, no residual phantom refs, tsc clean, SurfingTab 16/16,
4 orphaned locale keys = already-disclosed residual. Tier fix (Math.abs semantics) under review.

**AUD-NUM CLOSEOUT (f13e475) — verdict: could NOT pass the claim:**
- F1 MAJOR (reproduced): jacking regression as banked above; detected 2.09× at 8.57 m,
  ZERO at 4/2/1/0.5 m. → FIX DISPATCHED (operator chat "go ahead and fix the jacking"):
  agent `fix-jacking`, distance-based windows 8.57 m/42.86 m criterion-preserving, dedupe,
  KATs incl. old-algorithm-embedded equivalence proof + falsifiability. Allowlist:
  surf_1d_analytical.py `_compute_jacking` + constants only, + new test file.
- F2 MEDIUM (trigger unconfirmed): `_refine_bathy_profile()` raises uncaught ValueError on any
  NaN depth (PchipInterpolator finite-check) at 3 live call sites (surf_1d_pipeline.py:2123,
  beach_profile.py:708, surfbeat_runner._interp_profile); prior np.interp tolerated NaN.
  Could not confirm NaN reaches 1D transect profiles in production. → operator disposition
  needed (guard = small behavior change on a live path).
- F3 MINOR: measured runtime 2.0 ms→13.0 ms per transect (6.5×); ~2.1 s per analytical pass
  at 162 transects. Not verified vs live cycle telemetry. Likely fine; note for C3 cadence.
- Ruled out: PCHIP shape distortion (no overshoot on bar fixture), SurfBeat dx feed-through
  verified into CGRID/INPGRID lines, allowlist/frozen-core clean, 18/18 + 139/139 related green.
- Not checked: live cycle telemetry, "3 mutations" claim, real CUDEM edge shapes.

**AUD-DASH CLOSEOUT (54b1563/9aa67a8/fc93876) — verdict: could not disprove; 0 BLOCKER/MAJOR:**
- F1 MINOR: tier heuristic (BeachProfileChart.tsx:122-127 + HeatMapCard selectHeatMapTier)
  Math.abs picks outermost break BY MAGNITUDE regardless of sign — a large landward break
  (-600 m) + small seaward break (+50 m) would force Extended tier. No mixed-sign test exists
  (both new tests all-negative). Bounded by realistic magnitudes; rendering positions stay
  signed (verified). → regression-test candidate, fold into next dashboard round.
- F2 NOTE: the 4 orphaned locale keys = exactly the pre-disclosed residual, count verified, no
  additional orphans.
- Ruled out with evidence: waveShape survival (render/type/openapi intact, enum verbatim match
  to marine), zero phantom refs at HEAD, stale test updated in-commit (not deleted), tier
  constants identical both components (100/300/1000), landward clipping safe, gutter-band
  overflow unaffected, file/line-count claims exact. tsc 0 errors, 16/16 + 37/37, build OK.
- Not checked: live axe scan (none wired into these test files — the Opus-era "0 new axe
  violations" claim is NOT independently reproducible), deployed bundle inspection.

**DIAG-INV CLOSEOUT — root cause CONFIRMED (pier exclusion + inv-3/7 storm):**
- Pier `coordinates` (~29-point polyline) LOST from /etc/weewx-clearskies/marine/marine.conf at
  the 2026-08-02 22:12:54Z admin save (operator's directional-exposure save). NOT the redraw
  (04:28Z) — loss precedes it. Structure now has only bearing/length/distance/material/type.
- Coordinator follow-up closed DIAG-INV's open question: weewx api.conf `[[[[[structures]]]]]`
  section has NO coordinates key EITHER → hypothesis (a) CONFIRMED: the API's durable copy
  never carried coordinates (one-time wizard-discovery→marine path); the admin save faithfully
  round-tripped the API's incomplete copy over marine's good file. Admin template renders the
  hidden coordinates field only when present at GET-render → silent clobber. C9b code NOT the
  cause (touches only directional_exposure). Marine decode + ADR-095 no-fabrication exclusion
  working as designed. Jul-31 backup with full polyline: marine.conf.bak-preseg-1785521385.
- Invariant 7 = REAL downstream signal: no usable coordinates → structure not L4-eligible →
  l3_enabled=auto silently disables L3 → spectral_dwr collapses to same object as handoff
  components (swan.py:3433-3441 documents identity for L3-off) → multiSwell mis-sourced.
- IMPACT LIVE: 0/162 structure-affected; L3 10 m grid not running; pier shadow physics ABSENT
  from published forecast. last_run STALE 03:21:36Z.
- NEW: /health flipped back to "ok" (fired_total 222) despite ongoing fires + stale last_run —
  invariant fires may not durably flip health (H1-truthfulness gap candidate).
- NEW (coordinator live check): forced-full-run LIVELOCK since the ~04:28Z redraw push: retries
  every ~5 min (05:38/05:43/05:49...), each no-ops INSTANTLY (same ms as "starting full SWAN
  cycle", NO WARNING/ERROR logged despite the message pointing "above"). Suspected inner
  same-HRRR-cycle dedup (cycle=prev=00z) blocking despite forced bypass of the outer gate →
  C8 False+forced keeps signal → livelock until next HRRR cycle. Evidence sent to AUD-PLUMB.
  CONSEQUENCE: the 162-transect geometry has never had a successful full run; served data is
  the 03:21Z cache.
- Operator config residual: api.conf ndbc `prjc1` still lowercase (V3-F8 fix pending).

**AUD-C3 CLOSEOUT (052906f) — recommendation: DO NOT PUSH as-is:**
- F1 MAJOR (reproduced on real merge code): 24-point merge silently drops fill points when
  existing_forecast is sparse/coarse (6-entry 3-hourly seed → only 6 of 24 survive, no log).
  Nominal 73-entry hourly cache safe (24/24). Shipped KAT seeds the one shape that can't
  collide (vacuous). Needs defensive guard or non-aligned-cache KAT + fix before push.
- F2 MAJOR: PROVIDER-MANUAL §Two-tier schedule stale ("single snapshot, <1 min") — must land
  with push per doc-code sync.
- F3 flagged: NO runtime evidence 24 stationary full-nest computes fit hourly cadence; overrun
  → silent skip via non-blocking _swan_run_lock. Needs one measured cycle or operator accept.
- F4 NOTE: "0-24h" is actually hours 0-23 (24 points). F5 ruled safe (tide interp real, not positional).
- Mutations 3/3 caught; 38/46 green independent runs; allowlist exact; frozen core zero-diff.

**AUD-SCORE CLOSEOUT (a751c9a + 6d489da) — verdict: DISPROVED (1 BLOCKER):**
- F1 BLOCKER (latent, reproduced): `_classify_wave_shape(period_s=0.0)` → ZeroDivisionError at
  surf_1d_analytical._dispersion:125 → 500s the ENTIRE /surf request (RFC7807 catch-all).
  Reachable: surf.py:1072's own `or 0.0` proves zero/missing wavePeriod anticipated; pipeline
  break point is independent. Not yet fired live (67/67 periods ≥3.06 s). 20 KATs never test
  period 0. Fix pattern: null classification when period_s<=0 (matches the pipeline-unavailable
  null branch at surf.py:1340-1356).
- F2 MAJOR: swellDominance doc drift ×4 (API-MANUAL:2049 "never intermediate"; api repo
  responses.py:1672; dashboard openapi:3243; contracts openapi:3484) — live payload falsifies
  (67 distinct continuous values). Doc-batch + api-repo comment fix needed.
- NOTEs: plan closeout undercounts a 4th ruling (peel<=30 → walled_closeout regardless of
  regime — recorded only in commit msg); Iribarren boundary xi=0.5 divergence vs _iribarren()
  (intentional, tested, undocumented).
- Ruled out: bucket-compare consumers (dashboard uses round(x*100) only), scoring regression
  (mutations caught), enum match both repos + live (57 walled/7 mushy/3 steep/0 hollow),
  L0 + dispersion dimensional checks, totality. 40 + 103 tests green independently.

**AUD-PLUMB CLOSEOUT (f2b3ce0/02feb1d/ba515ed/2e67966) — verdict: C8 DISPROVED; V3-F8 + H5 HELD:**
- F1 BLOCKER = the livelock (detail below). Remediation direction: thread `forced: bool` into
  `_run_all_spots_locked()` to bypass the dedup marker when forced (or geometry-fingerprint the
  key), + upgrade swan.py:2497 DEBUG→WARNING. Operator nod pending.
- F2 MEDIUM: `wave_transform.bilinear_interpolate()` is a NEW undocumented orphan (its only
  production caller was surf.py's deleted `_interpolate_hrrr_wind()`; 2e67966 removed the
  import). Module docstring :39-45 now FALSE ("surf.py uses it... it stays for that reason
  alone"). Unlike bbox_for_location (tracked), never disclosed. Disposition: docstring truth-fix
  in doc-batch; deletion (if wanted) = operator deletion-round ruling.
- F3 MINOR: PROVIDER-MANUAL §14.15 (c3f7505) says fetch() returns "all nine keys" — fetch()
  (swan.py:1678-1725) returns 8 of 9 (never reads `hrrr_cycle_time`) + data_age_seconds.
  Nothing consumes the missing key. Fold into doc-batch.
- F4 MINOR: only 2 of 9 C8 no-op paths have automated False-return assertions (no-surf-spots,
  hrrr-wind-failed); other 7 verified only by auditor code-read. Test-author batch candidate.
- V3-F8 HELD: casing fix live-verified (PRJC1 200s), negative-cache correctly 404-only (5xx =
  different exception class), no 4th URL site. H5 HELD: zero request-time HRRR fetch remains,
  old-cache wind_for_display double-guarded, no KeyError live since deploy.
- Incidental pre-existing (NOT these commits): WCOFS OPeNDAP KeyError; NDBC rate-limiter
  QuotaExhausted on spectral fetch. Track, don't conflate.
- Full suite: 816 passed / 2 skipped (auditor self-noted the full-suite run vs standing rule).

**AUD-PLUMB livelock detail (BLOCKER, live-reproduced):**
- (a) swan.py `_run_all_spots_locked()` :2492-2501 dedup gate: cache marker keyed purely on
  `hrrr_cycle_time`; `run_all_spots()` has NO forced/force_full_run parameter — forced-ness is
  never threaded into swan.py. service.py bypasses only ITS outer cadence gate. Any forced run
  landing inside an already-completed HRRR cycle window can NEVER execute until the cycle key
  rolls (up to ~6 h) — violates operator ruling 2026-07-28 ("geometry push → immediate full
  run"). Reproduces on ANY forced push, correct config or not. C8's False+forced retry loops
  on it every ~5 min.
- (b) :2497 log is DEBUG — never upgraded by C8 (plan scope-ack ruled the return value for the
  dedup path but not its log level; 7 of 9 paths got WARNING, dedup didn't). service.py's "see
  WARNING/ERROR above" is FALSE on this path — exact H1 silent-no-publish class (Gate H row 2).
- Fix direction (operator decision pending): thread `forced` through run_all_spots →
  _run_all_spots_locked to override the dedup marker (+ upgrade :2497 to WARNING). Restores
  the 2026-07-28 ruled behavior; service.py's own WARNING text already claims this bypass.
- AUD-PLUMB full-suite run: 816 passed / 2 skipped, no collection errors.
- NOTE: livelock self-clears when the next HRRR cycle posts — but the first successful full run
  will compute the 162-transect geometry WITHOUT the pier (coords still missing). Restore order
  matters: pier coords first, then full run.

**OPERATOR CONTEXT (2026-08-03 chat, mid-audit):** the wizard RESET the surf study area when
re-entered; operator re-drew it just SOUTH of the pier to Beach Blvd — pier likely just OUTSIDE
the drawn area now. Operator ruling-in-waiting: structures just outside the drawn study area
still shadow into it and MUST be pickable-up; if the exclusion is geometric, the structure-
detection design needs revisiting (operator raised — design options go back to operator).
Forwarded to DIAG-INV. Also: wizard resetting the study area on re-entry is itself a defect
candidate (second occurrence per operator: "that was a problem before").

## Operator rulings given in the Opus window (extracted from transcript — honor these; they are valid)
- waveShapeClassification is legitimate + was broken; restore it. partitionBreakInfo/shadowFaceHeight: delete (D1).
- Transect markers: remove from public view.
- Heatmap smoothing (shapes vs pixel transects): future idea, raised 21:21Z — in plan as "Heatmap smoothing".
- C3: fast cycle = first 24 h only, stationary; approved trigger-6.
- 1D resolution: 1 m analytical / 0.5 m SurfBeat-in-surf-zone, PCHIP; approved trigger-3. "ok good, that is the swan recommended setting" + "approved".
- H5 pipeline-wind: surf card HRRR data must come from the model-fetch cache, not its own fetch (22:08Z).
- swellDominance: serve continuous ratio (zero compute cost).
- NDBC: Option A (silent None) + 1800 s negative TTL.
- Chart tiers: keep already-decided distances; do NOT change to 250 m (00:36Z).
- Breaking parameter check queued after resolution change ("let's check... whether that may also be set too high") — NOT yet done; tracked.
- LM: ortho imagery design (NAIP proxied+cached via API/dashboard proxy chain; ESRI direct-browser; wizard/admin provider config). Operator corrected Opus twice: API is NOT public — NAIP tiles go browser→dashboard proxy→API; marine service is on librewxr.
- Post-compaction Opus failed to retain architecture; operator ordered re-read of ARCHITECTURE.md before continuing plan.

## Operator rulings 2026-08-03 (post-synthesis chat)

1. **Pier/structures — root problem is admin incompleteness.** Operator: the admin/wizard
   "completely lacks the ability to scan for structures and no ability to draw them in";
   Opus originally added the pier geometry MANUALLY and never built the UI; "We should do
   that now." → NEW WORK: wizard/admin structure capability (scan + draw + persist through
   apply so coordinates durably round-trip into api.conf). Investigation-first round
   dispatched (how coords originally landed, what discovery code exists, gap list) →
   operator design review before any build. Interim manual restore of pier coords from the
   Jul-31 backup: PROPOSED to operator, awaiting yes/no.
2. **Period-0 crash guard: approved** ("sounds good"). Dispatch after fix-jacking lands.
3. **C3 remediation + push/deploy + measured cycle: no objection.** Proceed.
4. **NaN guard (PCHIP refine helper): FIX** (operator: "fix").
5. **Livelock fix: approved** ("ok"). Thread `forced` through to dedup gate + WARNING upgrade.

**Marine-repo sequencing (one implementation agent at a time, one functional change per
deploy):** fix-jacking (running) → R3 livelock → R2 period-0 guard → R-NaN guard → R4 C3
remediation (rebases on 052906f). R-ADMIN investigation runs in parallel (read-only,
stack/api repos).

## INTERIM PIER RESTORE — DONE 2026-08-03 06:11Z (operator-approved "yes do the interim manual restore")

- Backups made: marine.conf.bak-prerestore-<ts> (librewxr), api.conf.bak-prerestore-<ts> (weewx).
- marine.conf: 35-pt pier polyline injected from marine.conf.bak-preseg-1785521385 (structures.0).
- api.conf (weewx): `coordinates = "<json>"` line inserted in the pier structure block, EXACTLY the
  format setup.py:1317-1319 writes (json.dumps [[lon,lat],...]) — future admin saves now round-trip
  it, no more clobber.
- Activated via documented POST /config (bearer from secrets.env, per PHASE-E-DEPLOY-RESUME
  2026-07-28 recipe) → HTTP 200; journal 06:11:18Z: "Persisted marine config", "SWAN structure
  emitted: type=pier ... 35 coordinate points (explicit)", grid sizing chain restarted (UTM 11,
  L1 38x28). Monitor armed for sizing completion + structure-affected counts + next full run.
- Full run still livelocked until 06z HRRR posts (C8 F1) — but config now correct, so the first
  successful run computes WITH the pier.

## INV-STRUCTURES CLOSEOUT — provenance + capability truth (operator briefing)

- Provenance: pier coords were a ONE-OFF manual POST /config on 2026-07-28 (Overpass way 45074900,
  hand-built payload, documented in PHASE-E-DEPLOY-RESUME-2026-07-28.md:162-193 — "wizard/admin UI
  is currently BROKEN... use manual config push for now"). Never touched api.conf — hence never
  round-tripped.
- CAPABILITY CORRECTION: the WIZARD already has BOTH structure scan (T5.2/T5.3 Overpass discovery,
  PROVIDER-MANUAL §14.9) AND draw (dedicated L.Draw polyline control, step_marine.html:1285-1368),
  wired through E13 persistence (unit-tested round-trip incl. api.conf write). The ADMIN panel is
  what lacks origination (round-trips coordinates only if already present — the clobber mechanism).
  TA-C15's "live api.conf durability unverified — minor" residual is the thing that bit.
- Contract complete except: `bearing_to_spot_degrees` half-wired (API decodes, no form writes,
  marine doesn't decode) — disposition needed.
- ADR-095 Decision 3 constraint: NEVER fabricate coordinates from bearing/length (a prior
  fabrication path was deliberately deleted at E13); any admin UI must respect this.
- Recommended tasks (operator ruling pending):
  R-ADMIN-1: admin "Discover Nearby Structures" button reusing existing API endpoint (stack, small).
  R-ADMIN-2: admin draw control mirroring wizard's — recommend explicit G6.3 scope-widening or
  G6.3b (operator wrote wizard/admin parity into G6.3 already).
  R-ADMIN-3: option (a) admin render falls back to marine's copy when api.conf lacks coords, or
  (b) no code — durability now fixed forward by the restore + R-ADMIN-1/2. Operator picks.
  R-DOC: PROVIDER-MANUAL §14.9 missing the coordinates output field (E13 drift);
  bearing_to_spot_degrees disposition.

## Next after audits
Remediate findings (scoped rounds) → C3 push+deploy w/ reality gate → C4 → C7 → Phase LM → heatmap smoothing → Gate D/C closes. Push/deploy authorized for testing by operator this session ("You have permission, as coordinator, for push/deploy as needed for testing").
