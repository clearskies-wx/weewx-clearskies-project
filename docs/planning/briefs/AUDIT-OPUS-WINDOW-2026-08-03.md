# Opus-window audit — 2026-08-03

## ═══ RESUME HERE (written pre-compaction, 2026-08-03 ~07:45Z) ═══

**Role:** Coordinator (Fable). **Mission:** finish the Opus-window remediation queue, then resume
MARINE-FORWARD-PLAN (C4 → C7 → Phase LM). Operator grants this session: push/deploy for testing;
TIP-deploy strategy DELEGATED to coordinator ("whatever you think is best").

**Marine repo:** deployed = `2e67966`; local = 7 unpushed audited commits `052906f → 53d10d2 →
46d55e0 → 7be3c9e → 33dd56b → 4db71c6 → 370e142` (ledger below; ALL adversarially audit-clean
except 53d10d2 whose two follow-ups are the fix-jacking2 round).

**IN FLIGHT at compaction (background agents — results arrive as task notifications):**
1. `fix-jacking2` (clearskies-api-dev, GO given): _compute_jacking decoupling (peak within ±window
   of crest, NOT same sample) + constants 10 m/50 m + edge clamp; allowlist surf_1d_analytical.py
   `_compute_jacking`+constants + tests/test_jacking_resolution.py; ONE commit; closeout must have
   stash falsifiability (offset-extrema KAT: 0 detections at 1 m pre-change) + per-test ledger.
2. `diag-fetch` (read-only investigation): (A) negative-fetch crash — wind_sea_growth ValueError
   (fetch_m=-0.52, depth 0.98 m) at surf_1d_pipeline.py:1457 F5 path kills whole spot-hours
   (29/31 unavailable live NOW); which transect, why, remediation options w/ trigger classification;
   (B) L3 viability contradiction — 06:12:31 log "FAILED, unreachable ~235 m, disabled" vs sizing
   cache carrying L3/L4 clusters (different bbox) vs run executing L3+L4 fine.

**STATUS UPDATE 2 (2026-08-03 ~13:30Z, autonomous window — supersedes update 1 below):**
EVERYTHING through Phase LM is CLOSED, AUDITED, DEPLOYED, PUSHED. Live state: marine `0946ed8`
on librewxr (inv-1 cured, 67/67 hours ok, C4 grading live, inv-4 = decision item 10); API
`b369ee6` on weewx (imagery domain live, `[imagery] provider=auto` in api.conf, pre-fill fix);
weather-dev = dashboard `fed72f8` + stack `159731d` (ortho heatmap + imagery config UI, both
surfaces). Closed this window: Opus-audit remediation tip (11 commits), fix-jacking2, fetch-fix
(+clamp-detection leak-fix), bearing_to_spot deletion (both repos), doc-batch, C4, LM-1/2/3,
Gate C, D2 + D4 (both verified already-done, stale rows), all manual syncs. OPERATOR QUEUE:
decisions items 1-13 in this file + eyeball items (heatmap ortho alignment — unrotated mosaic,
expect tweak; admin imagery; admin structures; prjc1→PRJC1). NEXT WORK: G6.1/G6.2 (sizing-chain
geometry — careful briefs, read phase header first), D10.2 awaits rulings, D1/H5 parked,
V1/V2 weather-dependent. Tracked-follow-ups list lives in the todo + this file's tracking
paragraphs. Monitors: none armed (journal monitor was stopped — journalctl needs sudo; use
Bash+ssh with sudo for sweeps).

**STATUS UPDATE (post-compaction, 2026-08-03 ~08:30Z):** fix-jacking2 ACCEPTED (`6c013d2`, ledger
row below); doc-batch LANDED (meta `94b4148`, api `c29b85b`, dashboard `8d6e733`, ledger row
below; item 2c l3-wording DEFERRED to marine-side batch — lives at API-MANUAL §H1:3386-3388);
fetch-fix round DISPATCHED (agent `fetch-fix`, generic type pinned model=sonnet, scope-ack
pending). Remaining order: accept fetch-fix → lead-direct marine bearing_to_spot deletion +
marine-side doc remainders (wave_transform :39-45 docstring, stale n_l3_enabled log,
§H1 l3-wording) → ONE adversarial audit over 6c013d2 + fetch-fix + doc-batch → TIP push/deploy +
gate battery (step 4 below). 06z run re-confirmed pier-inclusive (162/23) across cycles; transect
83 inv-1 fired again 08:00Z valid-time = phantom-depth class, cured by fetch-fix as predicted.

**NEXT STEPS in order (after those two land):**
1. ~~Accept fix-jacking2 (independent test run + stat), surface diag-fetch findings to operator →
   likely one ruling on the negative-fetch remediation shape → dispatch that fix round.~~ DONE.
2. Lead-direct: marine-side `bearing_to_spot_degrees` deletion (marine_config.py ~:337 annotation,
   ~:354 decode, ~:379-386 validate + tolerance KAT — mirror API repo commit `858279b` pattern).
3. Adversarial audit (one auditor) of fix-jacking2 + fetch-fix commits.
4. TIP push (`git push origin main`, operator-delegated) + `scripts/deploy-marine.sh` + post-deploy
   battery: journal sweep (new ERROR classes), publish-liveness, reality gate PRE-STATED: served
   Hs vs NDBC 46222 matched hour, tolerance ±30%; verify jackingFactors non-empty if bars exist;
   verify 29/31-unavailable is cured; C3 fill runtime measured (AUD-C3 F3 evidence).
5. Doc-batch (meta): swellDominance truth ×4 (API-MANUAL:2049, api responses.py:1672 comment is
   API-repo, dashboard openapi:3243, contracts openapi:3484), wave_transform.py:39-45 false
   docstring, PROVIDER-MANUAL §14.15 fetch()-returns-8-keys row, §14.9 missing coordinates field.
6. Operator actions pending: eyeball admin structure tools on weather-dev (Discover + Draw,
   deployed `7a27e3e`); prjc1→PRJC1 in api.conf via admin (V3-F8 residual).
7. Then plan queue: C4 (modelStatus grading, ruled thresholds in plan §C4) → C7 → Phase LM (ortho).
8. Lessons capture at close (CLAUDE.md routing): model-selection check on session start; silent
   DEBUG no-publish paths; vacuous KAT shapes; per-unit exception isolation pattern.

**Live system state at compaction:** marine /health degraded (persisted l3_viability_failed reason
+ possibly stale — see diag-fetch B); 06z full run COMPLETE (L1-L4 converged, L4 vf 100%, pier
shadowing 23/162, inv-7 QUIET post-cycle) but 29/31 served hours modelStatus=unavailable from the
negative-fetch crash (PRE-EXISTING defect exposed by new geometry, NOT our commits). Dashboard =
fc93876, stack = 7a27e3e (both deployed). Monitor on marine journal may lapse — re-arm with the
ABSOLUTE ssh config path (c:/CODE/weather-belchertown/.local/ssh/config).

**Hard rules refresher for post-compaction self:** read CLAUDE.md + rules/{coordinator,agents,
verification}.md before dispatching; scope-ack before GO; adversarial audit before round close;
stash-falsifiability required in closeouts; never full pytest; agents never push/pull; one
implementation agent at a time in the marine repo.

## ⛔ DECISIONS FOR OPERATOR — running list (autonomous window, 2026-08-03)

Operator stepped away 2026-08-03 ~08:45Z with: "continue with the remainder of the plan items…
operate autonomously… Log major issues that I need to decide on." Items below are PARKED for
operator ruling — work continues around them; nothing here is decided by the coordinator.

**Operator discretion directive (chat, 2026-08-03 ~08:50Z):** "just try to use discretion of what
is truly architectural, and what is really something that is a fix for something already
previously authorized." Coordinator's operating interpretation for this window: fixes that
implement/repair an ALREADY-AUTHORIZED design (extending an approved rule uniformly, making code
match its authorized contract, completing a ruled design) PROCEED with the reasoning recorded;
changes making a NEW architectural decision (new formula/boundary/responsibility/contract) still
PARK here. Each discretionary call gets a one-line entry in this file as it's made.

1. **H5 remediation shape** (plan §H5, ⛔ pre-existing): Stage 1 done; Stage 2 ruling outstanding.
2. **D1 deletion sign-off** (plan §D1): delete dead `_transect_band_depths()` — deletion needs
   operator sign-off per the plan's own gate (trigger-2-adjacent).
3. **C-E03 transect-count cap** (plan Phase C carry-forward): no cap exists today; add one or not.
4. **`CLEARSKIES_MARINE_DEBUG_TRACE=1` in production network.env** (C7a NOTE): keep-or-remove.
5. **TA-C21 paper-trail residual**: confirm G4.6's invariant-3 rescope was the criterion change
   you intended (code done either way).
6. **Operator actions pending**: eyeball admin structure tools on weather-dev (`7a27e3e`);
   `prjc1`→`PRJC1` in api.conf via admin (V3-F8 residual).
7. **Smart-L3 disposition**: investigation scoped (handoff wiring + 40 m size criterion);
   coordinator may RUN the read-only investigation autonomously, ruling stays operator's.
8. **Wizard-resets-study-area defect** (tracked 2026-08-03): remediation shape undecided.
9. **V3-F1 mid-forecast wind-coverage hole**: investigation → likely operator for any fix.
10. **Invariant 4 recalibration (NEW 2026-08-03, post-tip-deploy):** `4:distinct_handoff_depths_
    across_transects` now fires EVERY timestep in the low-Hs regime ("only 1 distinct handoff
    depth across 162 transects"). Root cause verified in journal: all 162 transects clamp
    (target ~1.0 m below grid floor) and the L4 station ladder carries COMMON depth values
    across transects (stations 22/23/24 all depth=3.27 m, boundary 2.82 m everywhere) — so one
    distinct depth is the TRUE clamped state. The invariant was calibrated against the phantom
    per-transect-varying depths the operator-approved d0d0077 fix removed; it can no longer
    distinguish legitimate uniform clamping from the scalar-uniform bug class it exists to
    catch. Consequence: /health shows degraded on every low-Hs cycle (standing false alarm;
    truthful data underneath). **Coordinator recommendation:** gate the invariant on the clamped
    flag — don't fire when all contributing transects' HandoffSelections are clamped (the
    uniformity is then explained); still fire when uniform WITHOUT uniform clamping. This is a
    verification-criterion change → parked for your ruling, not made under discretion.
11. **LM-3 attribution toggle (NEW 2026-08-03):** plan §LM-3(c) sketched an "attribution display
    toggle (default on)" but no backend key exists (deployed ImagerySettings = provider/api_key/
    tile_cache_ttl_seconds only). Shipped WITHOUT it — attribution renders unconditionally.
    **Coordinator recommendation: drop the toggle permanently** — ESRI's ToS requires
    attribution; a hide-toggle invites a violation with no upside. Alternative: add an
    `[imagery]` key API-side in a follow-up. Your call; plan text updated only after it.
12. **Lessons-capture routing table (drafted 2026-08-03, autonomous window — per CLAUDE.md the
    routing needs your sign-off BEFORE rule-file edits land; nothing below is committed to a
    rules file yet):**

    | # | Lesson | Proposed destination | Draft rule text (one line) |
    |---|---|---|---|
    | L1 | Model silently reverted to Opus on VS Code restart; cost a full re-audit | user-global `CLAUDE.md` (cross-project) | "At session start (and after any IDE restart the user mentions), state which model is coordinating; if it is not the intended coordinator model, stop and surface before any work." |
    | L2 | Commit trailers are copied text, not model telemetry (agents copied 2e67966's Opus trailer) | `rules/verification.md` | "Never use commit trailers as model-identity or authorship evidence — transcripts' model fields are the only reliable source." |
    | L3 | Skip/no-op paths logged at DEBUG are invisible in production (C8 livelock, F5 class) | `rules/coding.md` | "Any code path that silently declines to do scheduled work logs WARNING or higher, naming the unit skipped and the reason." |
    | L4 | Vacuous KATs: a KAT that passes pre-change proves nothing (multiple rounds this window) | `rules/verification.md` (fold into KAT mandate) | "Every KAT closeout states which tests FAIL against pre-change code, with the transcript; non-falsifiable pins are declared as such." |
    | L5 | One try/except around 162 units killed whole spot-hours (surf_pipeline_timestep.py:544-578) | `rules/coding.md` | "Exception isolation is per-unit for per-unit work loops; a shared catch around N independent units is a finding." |
    | L6 | Blind monitor: `journalctl -u` without sudo returns empty for the claude user on librewxr — monitor watched an empty stream; silence looked like health | `reference/clearskies-dev.md` (fact: sudo needed) + `rules/coordinator.md` (practice) | "Before trusting any watch/monitor, prove it can see a known-present line first; a filter that would stay silent on crash or permission failure is not armed." |
    | L7 | An authorized behavior change can invalidate an invariant's calibration premise (inv-4 vs d0d0077) | `rules/verification.md` | "When changing published semantics, enumerate invariants whose firing criteria reference the changed quantity and pre-state which will move — before deploy, not after." |
    | L8 | Ledger line numbers drift as commits land; briefs must say 'verify against HEAD' (both rounds hit this benignly) | `rules/agents.md` (fold into reading-list rule) | "Cited line numbers in briefs are anchors, not truth — agents verify against HEAD and report drift." |
    | L9 | clearskies-dashboard-dev declined stack-repo work TWICE (radmin-parity 08-02, g63-polygon 08-03) — role text says React SPA only, but the plan/convention assigns ALL UI surfaces (React + config-service templates) to it (C9b, G6.3, R-ADMIN, LM-3 precedents) | `.claude/agents/clearskies-dashboard-dev.md` (one line) | "Scope includes the stack repo's config-service UI (wizard/admin Jinja templates + Leaflet JS) — 'dashboard' in the name is historical." |

13. **D10.2 — three rulings on the phantom SurfForecast fields** (plan §D10, investigation
    COMPLETE, investigator recommends RESTORE for all three): (1) `partitionBreakInfo` — emit
    existing `perPartitionBreaks` shape on SurfForecast + re-point dashboard type (kills the
    duplicate schema; investigator-preferred) vs build the bespoke shape (data-contract
    choice); (2) `shadowFaceHeight` — is a non-headline shadow aggregate a legitimate
    `is_structure_affected` consumer under BD-8 (investigator: yes, secondary readout)?
    (3) `waveShapeClassification` — authorize the real round (regime threading + 4-way cut
    points = NEW formula criteria, trigger 1) or defer/pin. Full detail in plan §D10.
14. *(append as found)*

**Additional tracked follow-ups (2026-08-03 afternoon, non-decision):** wizard-path imagery
`api_key` silently dropped at apply (`_provider_secrets()` has no imagery branch and no plain-
api.conf write path for any domain's api_key; field unused v1 — LM-3 finding 2; admin path
writes it correctly). Wizard re-run pre-fill for imagery FIXED lead-direct (api `b369ee6`,
stash-falsifiable KAT, deployed same hour — LM-3 finding 3; discretion-directive class:
authorized imagery domain joining an existing generic mechanism, silent-reset defect class).

**Discretionary calls made under the directive (running):**
- **2026-08-03 ~09:00Z, fetch-fix round:** authorized fixing the `clamped` flag to match its own
  documented contract (comment: "clamped means the target genuinely wanted the real grid edge,
  not that a break zone happened to limit the search" — implementation computed the check over
  the BD-2-restricted prefix instead of the full range). Exposure: `max_seaward_break_index ==
  n-1` + below-grid target → phantom depth leaked through BOTH the clamp and BD-2 conditions.
  Classification: code-diverges-from-own-stated-contract (explicitly permitted fix class) +
  same authorized publish-real-depth rule extended to one more constrained-selection corner.
  Selection logic untouched. KAT-7 pins the corner with stash falsifiability. Found via
  fetch-fix agent's KAT-6 unreachability analysis; leak derivation verified by lead code-read
  and independently re-derived by the agent before implementing.

---

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

## Jacking remediation status (2026-08-03)

- `53d10d2` (local, unpushed): _compute_jacking metre-based windows + dedupe. Lead gate PASSED
  (allowlist exact, 9 KATs + 60 collateral green, coordinator independent probe: no false
  negatives on smooth profiles; BONUS confirmed — old code diluted factors toward 1.0 at fine
  spacing [1.84→1.00]; new code stable [1.84→1.64]).
- AUD-NUM re-verification vs its own F1 repro: **PARTIAL**.
  - FIXED: resolution collapse for coincident-extremum bars (control: 1 detection at every
    spacing 8.57→0.5 m) + factor dilution.
  - NOT FIXED (2nd, PRE-EXISTING defect, masked at native res): `_compute_jacking` requires
    Hs-peak AND depth-trough at the SAME array index. Real/synthetic profiles offset the two by
    ~metres (auditor's: 3.9 m); native 8.57 m quantization coincidentally merged them, 1 m
    resolves them to different indices → 0 detections. Likely bites REAL 1 m profiles in
    production. Candidate fix (OPERATOR DECISION, trigger-1 criterion change): decouple — bar
    (depth-trough) candidate + Hs peak within the ±8.57 m window, not same sample. Docstring's
    own intent ("local Hs peak before breaking" at "each bar crest") supports proximity.
  - NEW REGRESSION (c1, introduced by 53d10d2): full-window-fit gate silently drops bars within
    8.57 m of profile ends; OLD code degraded gracefully with partial windows (detected 1.377 on
    a 30 m truncated profile; new: 0). Real case: short handoff-truncated transects. Candidate
    fix: clamp windows at array edges (restores old graceful degradation) — methodology.
- HOLD jacking deploy until follow-up ruled + landed; deployed prod still has the original
  (fully broken) jacking, so no live regression from holding.

## Remediation round ledger (2026-08-03, running)

| Round | Commit | Lead gate | Adversarial | Status |
|---|---|---|---|---|
| bearing_to_spot deletion (API) | api `858279b` | PASS (my run 9/9, stat exact, grep 0) | **PASS**, 1 MINOR (API-MANUAL:3294 example) → fixed lead-direct, meta committed | **CLOSED** (deploy rides next api push) |
| Jacking fix (marine) | `53d10d2` | PASS | PARTIAL (aud-num re-verify) — 2 follow-ups, deploy HELD | Open: operator ruling on same-index decoupling; edge-clamp fix queued |
| Livelock fix (marine) | `46d55e0` | PASS (my run 14/14, stat exact) | **PASS 0 findings** (1 NOTE: "no-publish-skip:" prefix ≠ record_no_publish contract — intentional, KAT-pinned). Auditor's mutation pinned BEHAVIOR (return-False-with-log → KAT fails), stronger than implementer's TypeError evidence. Ruled out: double-run storm (marker rewrite unconditional), sub-5-min hot loop (unconditional sleep on every exit), log-order race (synchronous). Pre-existing residual noted: force_full_run_signal is an Event, a 2nd concurrent push during a forced run could coalesce — NOT worsened, tracked. | **AUDIT-CLEAN** (deploy pending stack order) |
| Period-0 guard (marine) | `7be3c9e` | PASS (my run 23/23, stat exact; pre-fix ZeroDivisionError repro via stash) | pending (batch with next marine audit) | Landed |
| NaN guard (marine) | — | — | — | Implementing (GO given) |
| Admin parity (stack) | `7a27e3e` | PASS (my run 25/25, stat exact) | **PASS**, 2 MINOR both INHERITED from wizard (F1: type/material/material_source data-attrs unescaped — real breakout primitive, proven, but unreachable via API's fixed maps; F2: `_marine_esc` lacks quote-escaping). → tracked hardening item BOTH surfaces (wizard routes.py:3397-3399 + admin routes.py:3020-3025 + widen _marine_esc), future round. Known limitation disclosed: admin map doesn't re-paint saved structure geometry on reload (paint step = candidate follow-up). | **CLOSED** — deploying to weather-dev |
| NaN guard (marine) | `33dd56b` | PASS (my run 25/25; bonus: pre-fix silently DROPPED distance-NaN rows) | **PASS** (aud-batch; MINOR: guard's own astype crashes on dtype=object-with-strings — unreachable via all 3 real call sites, tracked residual) | **AUDIT-CLEAN** |
| C3 merge remediation (marine) | `4db71c6` | PASS (my run 8/8; KAT-a proven to fail pre-fix) | **PASS** (aud-batch; extra adversarial shapes incl. a real randomized 6-way collision handled correctly where old code silently botched it; MINOR: test-file labels stale → fixed lead-direct `370e142`, comment/msg strings only, 8/8 green) | **AUDIT-CLEAN**; PROVIDER-MANUAL synced (`0c621e3`) |
| Period-0 guard (adversarial) | `7be3c9e` | (above) | **PASS** (aud-batch; other _dispersion callers confirmed different period source, unexposed; 0.1 s classifies; mutation kills 2/23) | **AUDIT-CLEAN** |
| Jacking follow-up (marine) | `6c013d2` | PASS (my run 15/15; stat exact 2-file; design-conformance diff read: two-stage decouple, strict-inequality edge rejection kills monotone-shoaling false positives, 10/50 native-equivalent, distance_m=crest, dedupe by factor; stash falsifiability: pre-change 1@native/0@1m vs post 1@all, factors within 3.4%; bonus edge-clamp before/after proof) | pending (batch with fetch-fix audit) | **ACCEPTED** — closes 53d10d2's two follow-ups; deploy at tip |
| Doc-batch (meta/api/dash) | meta `94b4148`, api `c29b85b`, dash `8d6e733` | PASS (stat exact ×3; repo-wide grep "never an intermediate" = 0; content spot-check of API-MANUAL:2049 row + §14.9 geometry paragraph — accurate, wire-vs-internal crisp, axis-order foot-gun documented) | pending (batch) | **LANDED**. Brief correction accepted: §14.9 wire field is `geometry` `[[lat,lon],...]` (NOT `coordinates` — that's /setup/apply's field, `[[lon,lat],...]`). Item 2c l3-wording deferred to marine-side batch (API-MANUAL §H1:3386-3388) |

| **PRE-TIP BATCH ADVERSARIAL AUDIT (aud-tip, 2026-08-03 ~10:10Z)** | marine `6c013d2`+`d0d0077`+`ba7b45d`+`5cc8f1f`, meta `94b4148`+`dec94f6`, api `c29b85b`, dash `8d6e733` | (lead gates recorded per-row above) | **ALL PASS, 0 BLOCKER / 0 MAJOR / 1 MINOR.** Independent reproduction: every headline KAT re-proven to fail vs pre-change code (md5-verified source swaps); 4 mutation probes each isolating one claim (edge-clamp gate, leak-fix range, WARNING level, tolerance KAT); native-equivalence arithmetic checked (10.0∈(8.57,17.14), 50.0∈[42.85,51.42)); blast-radius greps clean — surf_pipeline_timestep.py:261 already ASSUMED handoff_depth==station_depth, fix makes it true; §H1 wording traced against _record_l3_viability_failures() (runs pre-D2-nest, non-contradiction confirmed). **F1 MINOR (TRACKED test-hardening):** KAT-6 unreachability argument assumes monotonic station arrays — never asserted/enforced in code; add a non-monotonic-station-fixture KAT or assert the precondition (batch with C8 7/9 no-op path tests). | **DEPLOY UNGATED** |

| C4 modelStatus grading (marine) | `0946ed8` | PASS (my run 13/13; stat exact 4-file; diff read: grading branch exactly per ruled rule, zero-bulk path falls through unchanged, WARNING both grades; agent's own 17-file/229-test sweep clean; `.degraded` semantics untouched for beach_profile consumer; API-proxy pass-through verified by lead pre-GO) | pending (batch with LM-1 audit) | **ACCEPTED — NOT YET PUSHED/DEPLOYED** (rides next marine window after audit). Lead-direct doc sync landed: API-MANUAL:2967 rewritten (also fixed stale "fall back to L2" draft), dashboard types.ts union + openapi enum + tsc clean (`59674fd`), meta pushed. **TRACKED doc-gap:** `docs/contracts/openapi-v1.yaml` carries NO modelStatus field at all (pre-existing drift vs dashboard copy) — contracts-sync candidate, not folded into this round. |

**Trailer artifact finding (2026-08-03, lessons-capture candidate):** subagent commits `052906f`/
`46d55e0`/`4db71c6`/`6c013d2` carry "Co-Authored-By: Claude Opus 4.6 (1M context)" — investigated:
agent definitions all pin `claude-sonnet-5`, no hardcoded trailer anywhere in `.claude/agents/`,
and the ONLY Opus-window commit with that trailer is `2e67966` (the Opus coordinator's lead-direct
commit, top of git log when remediation began). Conclusion: agents copied the trailer style from
git history — trailers are TEXT, not model telemetry; do not use them as model-identity evidence
(the transcript's model fields are the only reliable source, as used for the window boundary).
Definitive per-agent model check via transcript remains available if the operator wants it.

**Marine branch state (7 local commits, ALL adversarially audited except 53d10d2's two follow-ups):**
052906f → 53d10d2 → 46d55e0 → 7be3c9e → 33dd56b → 4db71c6 → 370e142.
**Deploy-strategy decision for operator:** the branch is linear and fixes stack on their defects
(C3's fix is 5 commits after C3; jacking's follow-up will be at the tip) — every pre-tip deploy
point carries a known-defective intermediate state, so strict one-functional-change-per-deploy
is IMPOSSIBLE without history rewriting. Coordinator recommendation: single TIP deploy after the
jacking follow-up lands, with full journal sweep + reality gate; deviation from deploy-discipline
rule #1 justified by: every change individually adversarially audited w/ falsifiability evidence,
attribution preserved by the per-commit audit trail. Operator to approve/deny.

**Marine deploy-ordering note:** local marine branch is linear 2e67966 → 052906f (C3, needs
remediation) → 53d10d2 (jacking, held) → 46d55e0 (livelock) → …; deploy-marine.sh pulls
origin/main. Plan: when all commits are audit-clean, push INCREMENTALLY (git push origin
<sha>:main one commit at a time) with a deploy + journal sweep + reality gate between each —
preserves one-functional-change-per-deploy without history rewriting. C3 (052906f) sits first
on the branch, so its remediation commit must land BEFORE any push; jacking follow-up ditto.

## DIAG-FETCH CLOSEOUT (negative-fetch + L3 contradiction) — root cause PINNED

**A. Root cause:** `select_hourly_handoff()` (transect_handoff.py L4 branch ~:790-865; L3 branch
:983-990 identical gap): when the target depth (1.3·Hs/0.73) falls outside the grid's usable
range it CLAMPS the station pick to the nearest interior station (real depth e.g. 3.27 m) but
still RETURNS `handoff_depth_m = target_depth_m` (raw 0.85-1.00 m). The same function's BD-2
branch got exactly this fixed on 2026-08-01 (F1: "returned handoff_depth_m is the selected
station's own station_depth_m, mirroring T2.2 PART B") — never extended to the plain-clamp case.
Downstream: `_truncate_bathy_at_handoff()` truncates the 1D profile at the phantom shallow depth →
on transects with non-monotonic near-waterline DEM (pier-adjacent), the snap point lands
SUBAERIAL → fetch = bathy[:,0].max() is NEGATIVE → F5's wind_sea_growth raises. Named transects:
156 (fetch -1.17), 157 (-0.52), latent 160 (-0.04) — all in the clamped structure band T140-161.
Transect 83's 0.75 m handoff (inv-1 fire) = same phantom-depth class.
**B.** Kill radius confirmed: ONE try/except around all 162 transects (surf_pipeline_timestep.py
:544-578); zero per-transect isolation. 2 surviving hours = wind not onshore → F5 skipped.
**C.** Latent since E5 (2026-07-27); F5 (2026-07-30) is the first input-validating consumer.
Pre-F5 the phantom depth silently over-truncated the 1D domain (coverage loss, no crash).
**D. L3 contradiction RESOLVED — not a bug:** two L3 roles. Smart L3 (handoff-source candidate)
failed viability (bbox ...-118.021...) and is NOT wired into the run path anyway (documented KNOWN
GAP transect_handoff.py:888-902). Coarse L3 nest (L4 containment, D2 item 1) succeeded (bbox
33.6413-33.6577 — matches sizing cache) and is what ran as level3_0; containment assertions
passed. /health's l3_viability_failed = accurate about the smart L3, misleading wording only.
MINOR tracked: grid_sizing_chain.py:2385-2389 completion log reuses pre-overwrite `n_l3_enabled`
(stale count); wording gap for the health reason → doc-batch.
**E. Options:** (i) skip F5 per-transect when fetch≤0 w/ WARNING (methodology, minimal);
(ii) blanket per-transect catch (rejected by lead: silences future bugs, anti fail-loud);
(iii) setup-time degenerate-transect validation (design-first, trigger-3 adjacent, parked);
(iv) ROOT FIX: publish clamped station's real depth whenever clamped (extends the operator-
approved 2026-08-01 BD-2 rule uniformly; L4+L3 branches) — moves the 1D start depth for ALL
clamped transect-hours (currently the T140-161 band) → trigger-3 adjacent, OPERATOR ASKED.
**Lead recommendation to operator:** approve (iv)+(i) together, one round: (iv) fixes the lie
(the 1D model must start where SWAN actually handed off), (i) guards any residual degenerate
fetch gracefully per-transect. (iii) parked to geometry-phase work; (ii) rejected.
**✅ OPERATOR APPROVED 2026-08-03 (chat: "1. ok. 2. ok")** — round dispatches after fix-jacking2
frees the marine repo.

**✅ TIP DEPLOY GATE — PASSED 2026-08-03 (pushed 2e67966..5cc8f1f 08:38Z, deployed 08:39:19Z,
first post-deploy full cycle 08:40:27→09:18:44Z = 38m17s):**
1. Journal sweep: ZERO unexplained ERRORs. **Invariant 1: 0 fires (was every cycle) — phantom-
   depth class CURED.** Invariant 7: quiet all cycle. F5 negative-fetch crash class: absent.
   Only ERROR = invariant 4 ×67 (explained, decision item 10). NDBC spectral QuotaExhausted
   tracebacks = pre-existing WARNING-level noise class, non-blocking.
2. Publish-liveness: PASS (cycle complete, /health last_run=09:18:44Z).
3. 29/31-unavailable CURE: **67/67 hours modelStatus=ok** (baseline: 2/31; window itself grew
   back to full 67 timesteps because the pipeline no longer dies mid-run).
4. Reality gate (PRE-STATED ±30%): NDBC 46222 WVHT 0.8 m @08:56Z vs served waveHeightAtBreak
   0.758 m @09:00Z = **-5.3% — PASS** (comparison basis: total breaking Hs vs buoy total Hs;
   swellHeight 0.39 m is the swell-partition-only HSWELL, not the comparator).
5. Matched-hour before/after (expected-shift evidence, NOT regression): 11:00Z whb 0.579→0.743,
   12:00Z 0.419→0.748 — un-amputated 1D domains, direction consistent with restored physics.
6. jackingFactors: key present on /profile wire, [] across sampled hours while breakPoints=4 —
   plausible at 0.5 m surf / 3.27 m start depth; mechanism KAT-proven. **WATCH (V2-style,
   weather-dependent): first ≥1.5 m swell should show non-empty jacking on barred transects.**
7. C3 fill runtime (AUD-C3 F3): NOT measurable this cycle (full cycle, not fast+fill) —
   **pending next fast-cycle event**; tracked.

**PRE-DEPLOY BASELINE (captured 2026-08-03 ~09:55Z — clock note: actual push 08:38Z, so this
capture was ~08:25Z; deployed=2e67966, marine last_run 07:17:45Z)
— the "before" half of the matched-hour reality-gate evidence:** `GET /surf/huntington-city-beach-pier`
serves 31 forecast entries, **29 unavailable / 2 ok** — the 2 ok: 2026-08-03T11:00Z
(whb 0.579 m, bestPeak 0.802 m) and 12:00Z (whb 0.419 m, bestPeak 0.581 m) = the
wind-not-onshore hours where F5 was skipped, exactly per root cause. /health degraded, reasons:
l3_viability_failed (misleading-but-accurate wording, doc'd), invariant 1 (phantom-depth class,
cure expected), **invariant 7 fired at/after 07:17 last_run (NEW at this capture — was quiet
post-cycle earlier; watch at post-deploy sweep, do not assume same cause as the 08-02 firing)**.
Post-deploy expectation (PRE-STATED): most/all 29 unavailable hours become populated; small-surf
served numbers SHIFT broadly (un-amputated 1D domains) — judged against NDBC 46222 matched hour
±30%, not against this baseline's 2 surviving values.

**DIAG-FETCH FOLLOW-UP — SYSTEMIC quantification (2026-08-03):** 162/162 transects clamped at
least once in the 06z run (5,022 clamp WARNINGs parsed): Hs 0.36-0.56 m → target depth
0.64-1.09 m, ALWAYS shallower than the L4 grid's shallowest usable station (~2.8-3.3 m
everywhere). So in low-Hs regimes the phantom-depth defect amputates the 1D domain on the WHOLE
segment; 156/157/160 additionally crash (non-monotonic near-waterline DEM → subaerial snap),
transect 83 trips invariant 1 instead (break depth 0.77 > phantom handoff 0.75; NOT wave-shadowed,
mid-segment — L4 GRID MEMBERSHIP [162/162] ≠ wave-shadowed classification [23]). Post-deploy
reality gate must EXPECT broad served-number shifts in small surf (domains un-amputated) —
capture matched-hour before/after as gate evidence, not as regression alarm. Also explains the
inv-1 fire class.

**Smart-L3 disposition (operator Q 2026-08-03):** largely pre-L4 vestige AT THIS SPOT (L4 took
structure resolution + handoff; L3's live role = containment nest; smart-L3-as-handoff-source
documented unwired), BUT `l3_enabled=auto` also triggers on topographic features
(point_break/headland/bay_break) with no structure/L4 — smart L3 may be the intended fine grid
for such future spots. Deletion would be architectural (trigger 2) and needs a dead-code-grade
investigation first. TRACKED plan item: "smart-L3 disposition — investigate vestige-vs-future
before any ruling." Near-term: doc-batch fixes the misleading /health wording + stale
n_l3_enabled summary count.
**Operator guidance for that investigation (chat 2026-08-03):** today's handoff is strictly
L2/L4 — activating smart L3 for topographic-feature spots would require WIRING an L3 handoff
path (the documented unwired gap becomes real work, not just a flag). And because L3 is a 40 m
grid, the qualification criterion must be size-aware: only features large enough for 40 m to be
the appropriate resolution belong in that category — the current `l3_enabled=auto` trigger list
(point_break/headland/bay_break) should be re-examined against that bar (a small point break
does not warrant a 40 m grid). Both points scope the investigation: (1) what wiring would an L3
handoff need; (2) what feature-size threshold qualifies; (3) only then vestige-vs-future ruling.

## Operator rulings 2026-08-03 (second batch, chat)

- **Jacking follow-up APPROVED ("1. yes. 2. yes"):** (1) decouple same-sample requirement —
  Hs peak qualifies within ±window of the bar crest; (2) window constants 10 m extremum /
  50 m approach (one / five L4 cells; operator asked why 8.57 — answer: it was a fidelity
  constant, not physics; 10/50 remain provably native-equivalent). Round dispatched
  (`fix-jacking2`): decoupling + 10/50 + edge-clamp (aud-num c1) in one commit.
- **Deploy strategy DELEGATED ("whatever you think is best")** → coordinator proceeding with
  single TIP deploy after fix-jacking2 + negative-fetch remediation land, full journal sweep +
  reality gate; deviation from one-change-per-deploy documented here (linear branch, fixes
  stack on own defects, every commit individually adversarially audited w/ falsifiability).

## FIRST 162-TRANSECT FULL RUN (06z, completed 07:17:45Z) — verdict MIXED, new live defect

**Good:** forced run executed once 06z rolled the dedup key; L1 100% / L2 99.6% / L3_0 99.5% /
L4_0 99.9% + valid_fraction 100% (pre-incident baseline matched); 23 structure-affected/139 open
every transect computation; **invariant 7 QUIET post-cycle (0 fires)** — spectral_dwr channel
restored; no new ERROR classes post-cycle other than the below; run 867 s, 1/1 spots cached.

**NEW LIVE DEFECT (pre-existing latent, exposed by the redrawn geometry — NOT from our unpushed
commits; deployed=2e67966):** 1D pipeline raises per-timestep:
`wind_sea_growth: fetch_m and depth_m must both be > 0 (got fetch_m=-0.52, depth_m=0.979...)`
via surf_1d_pipeline.py:1457 `compute_wind_sea_growth(_onshore, _fetch, handoff_depth)` on the
F5 wind-sea-synthesis path (onshore wind 1.2 m/s @ 239°, seed Tp 0.3 s). Per-timestep catch
(surf_pipeline_timestep.py:555 region) converts ONE degenerate transect → whole spot-hour
`modelStatus=unavailable`. Served: 31 entries, 29 unavailable, 2 ok. Same kill-radius class as
the period-0 BLOCKER. Negative fetch + ~1 m handoff depth suggest a degenerate transect at the
new segment's south end (handoff nearly beached / landward of datum).

**UNRESOLVED CONTRADICTION (same investigation):** 06:12:31 sizing: "L3 viability FAILED —
structure unreachable by ~235 m (bbox 33.630-33.655 × -118.021--118.004); L3 disabled" +
"0 of 1 clusters enabled" + persisted /health reason. YET swan_grid_sizing.json (06:12 mtime)
carries level3_clusters + level4_clusters (L4 corners rotated 216.95°), and the 07:0x run RAN
level3_0 + level4_0 to convergence with structure effects served. Which decision governed, and
is the ~235 m unreachability computed against the RIGHT grid? Ties into the operator's standing
design concern: structures just outside the drawn study area must still shadow into it.

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
