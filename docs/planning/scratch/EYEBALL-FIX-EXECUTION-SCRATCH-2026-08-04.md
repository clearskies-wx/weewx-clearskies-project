# EYEBALL-FIX execution scratch — 2026-08-04 session

**Plan:** docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md (v2). Coordinator session scratch —
survives compaction. Update after every state change.

## Session authorizations (operator, this session's opening message)
- Push/deploy authorized "as necessary for testing purposes" (standing for this plan's rounds).
- Operator redirect mid-session: walk the DECISION QUEUE (§4) FIRST, one at a time, in order
  (D2 → D5 → D6 → D7), before/alongside round execution.

## Pre-flight (verified 2026-08-04)
- dashboard repo: clean, main @ 63733b1 (D10.2 renders + About imagery credit)
- api repo: clean, main @ c1a8212 (D10.2 F3 shadowFaceHeight conversion)
- Plan loci verified: companion_proxy.py:141-142 (_PROXY_REQUEST_TIMEOUT_S = 15.0, used :443);
  SurfingTab.tsx:204-282 ScoreBar (fillPct at :219 = Math.min(100, abs(score)) — the /100 drift;
  per-category relPct already used for COLOR at :238, not width); ScoreBar call sites :2102, :2121.
- NOT yet verified: BeachProfileChart.tsx:740-850, DESIGN-MANUAL:1343 SURF-1, useApiQuery hook,
  SurfingTab.tsx:2257 peel row, marine repo state (repos/weewx-clearskies-marine).

## Decision queue state
- **D2: RULED 2026-08-04 (operator chat) — STRIP BOTH.** Shadow line + AT BREAK rows come OFF
  the Current Swell card ("no user will know what the hell that is"; "these were computed for
  other parts of the dashboard, NOT FOR THE CURRENT SWELL CONDITIONS CARD — I never said to put
  them on this card"). Render-only removal; marine/API keep emitting
  shadowFaceHeight/perPartitionBreaks (D10.2 wire contract untouched). Plan S-SPEC-2 + §4
  updated. A2 now has NO exception — full strip to baseline + peel row.
- **D5: REFRAMED by operator 2026-08-04 — these are ERRORS, not design preferences.** "The
  question on why 300 feet of beach is rhetorical. THERE SHOULD NOT BE 300 FEET OF BEACH! The
  whole point is to model the surf zone plus a reasonable distance seaward, NOT to show a bunch
  of beach… What I was pointing out were complete ERRORS." No mockup session. Design intent now
  stated: chart spans surf zone + reasonable seaward margin (minimal dry beach), correct
  orientation (water surface up, not upside-down / negative-only y-axis), waves not pointing up,
  squiggle glyphs honor the Show-wave-shapes toggle (9g folded in as same-family error), info
  content minimal (9h). NEXT: coordinator reads BeachProfileChart.tsx + a live profile payload,
  writes a LOCKED corrected spec (plan pattern: coordinator designs, agents implement), presents
  for sign-off before dispatch. Becomes its own dashboard round (Round P) — A3 label-collision
  fix still lands in Round A first (it's independent and purely mechanical).
- **D5 mockup DELIVERED 2026-08-04:** interactive proposal at
  https://claude.ai/code/artifact/86d75d59-5fc7-42b2-890c-5820dd3db374 (source:
  session scratchpad beach-profile-redesign.html — copy into repo before implementing).
  Design: domain 280 ft→shore + sand sliver (drops the −297 ft flat-slab artifact from display;
  slab realness stays an open model question §5); y = elevation about LMSL waterline (water
  right-side up); ±hs/2 wave envelope riding the surface; break crest glyphs with
  cluster-merged face labels (no collisions); zone strip below axis; wave-shapes toggle honored
  + domain-clipped (only 1 of 31 payload glyphs is in-frame; rest were being drawn from up to
  7,022 ft away); info diet per 9h; hover tooltip depth/wave/distance. D6 demo toggle included.
  AWAITING operator verdict on the design.
- **D6 (zones per break, item 10):** PRESENTED with mockup toggle. FACT (live payload
  2026-08-04): wire contract has exactly ONE impactZone + ONE foamZone object; breakPoints has
  3 entries. Per-break zones require marine-side computation + contract change (trigger 4) —
  operator yes/no pending.
- **D7 (heatmap long-term precompute vs synchronous):** presented 2026-08-04 with
  recommendation to rule after B1 ships; no ruling yet.
- **UNIFICATION RULED 2026-08-04 (operator "Yes" to option (a)):** delete the endpoint-local
  `run_1d_analytical()` side-run (beach_profile.py:676-701); compute surfZones + waveShapes +
  jackingFactors from the MAIN pipeline's per-transect results (real tide, all partitions),
  zones tied to the published break points. Wire shape for zones unchanged for now; per-break
  zone LISTS (D6 proper) deferred until unified data exists and a corrected mockup is reviewed.
- **Tide finding (operator Q 2026-08-04):** the side-run's `tide_level=0.0` is a defect, not a
  design: the main pipeline REFUSES to compute with tide=0 in tidal regions
  (surf_pipeline_timestep.py:95-115 TideSeriesUnavailableError, "never substitute
  tide_level=0.0"); the endpoint side-run silently bypasses exactly that guard. Dies with
  unification.
- **Waterline requirement (operator, same message):** card must show the ACTUAL waterline —
  flat-slab investigation (real berm vs fallback-profile artifact, −297..0 ft shelf) is now
  BLOCKING for the profile card redesign, and the waterline must be tide-aware.
- **Shoaling display requirement:** operator rejects flat envelope band; model data DOES shoal
  (hs 1.7→2.31 ft peaking at x=60 ft then decaying — ~6 px at mockup scale, invisible). Next
  design iteration: data-driven wave forms marching shoreward (regime: stokes→cnoidal→breaking
  →bore, amplitude from local hs, break forms scaled to face height) so shoaling is VISIBLE.
- **Mockup ITERATION 2 delivered 2026-08-04** (same artifact URL): sea surface DRAWN from the
  model hs profile — Stokes-sharpened crests, shallow-water wavelength at 14 s, phase anchored
  so a crest breaks at the primary break (crest ≈ +1.9 ft vs face 2.9 ft trough-to-crest),
  whitewater overlay inside the break, still-water dashed datum, NOTHING drawn right of the
  0 ft shore ref ("waterline TBD" pending flat-slab investigation), zones re-anchored to the
  published breaks (unification preview; phantom 77–156 ft zones dropped from display).
  AWAITING operator verdict on iteration 2.

## Round state
- **D5 iteration 2b (double break drawn) APPROVED-IN-DIRECTION** (operator: "yes this is what
  I was expecting"); final verdict after unification + waterline. Artifact URL unchanged.
- **Round A: DISPATCHED 2026-08-04.** Brief: docs/planning/briefs/ROUND-A-DASHBOARD-BRIEF-2026-08-04.md.
  Agent `round-a-dashdev` (clearskies-dashboard-dev), scope-ack received + confirmed. Baseline
  dashboard main @ 63733b1. A3b (9g toggle fix) folded in. PLAN ERRATUM caught pre-dispatch:
  S-SPEC-4 `pollInterval: 120_000` is wrong units — useApiQuery takes SECONDS (×1000 at
  useApiQuery.ts:307-308); lead call = `pollInterval: 120`.
- **Round B: B1 committed api d818461 (15→45 s), pushed, deploy-api.sh running in background.**
  Lead-direct deviation from plan's agent column (api-dev) under the standing ≤50-line
  mechanical-fix rule — recorded here. Gate B live heatmap check pending post-deploy.
- Coordinator owns this round's doc edits (DESIGN-MANUAL SURF-1 deletion + Swell Card row)
  AFTER A1/A2 land — doc-code sync same round.
- Flat-slab/waterline investigation: Explore agent `flatslab-inv` dispatched (read-only).
- Round S: blocked until A/B deployed + gates walked. Marine unification round queued after
  the flat-slab brief returns.

## FINDING (2026-08-04, coordinator code-trace, prompted by operator D5 mockup review)
**The beach-profile payload is a chimera of two different model runs:**
- `transect` (hs envelope) + `breakPoints` = the MAIN 1D pipeline (SwellTrack handoff, all
  partitions, SurfBeat-blended): beach_profile.py:531-558 (`tr.hs_total_profile`,
  `tr.per_partition[..].break_points`).
- `surfZones` + `waveShapes` + `jackingFactors` = a SECOND, endpoint-local
  `run_1d_analytical()` call (beach_profile.py:676-701) fed ONLY the dominant partition's
  deep-water Hs/Tp/dir, `tide_level=0.0` hardcoded, gamma=0.73, on the raw
  `bathymetric_profile` — a different model with different inputs than the envelope/breaks.
- Consequence seen live: zones span 77–156 ft while the published breaks sit at 11–54 ft
  ("phantom zones", operator-spotted); waveShapes emitted out to 7,022 ft (full raw transect).
- Zone classifier itself (surf_1d_analytical.py:514-578) keys zones off its own run's
  break_points[0] — internally consistent, but its breaks are not the published breaks.
- D6 note: per-break zones only make sense AFTER unifying the source; zones should derive from
  the same pipeline results that produce the published break points. Surfaced to operator as a
  decision (input-rewiring within the marine endpoint; no wire-contract change for the single
  zone shape, contract change only if zones become per-break lists).
- Mockup errata owned by coordinator: the steep dry-sand wedge right of x=0 in the first
  mockup was SYNTHESIZED (payload has no dry beach: 2.2 ft depth at x=0, flat ~300 ft shelf
  landward — the known flat-slab open question). Next mockup iteration: no invented bathymetry.

## FLAT-SLAB INVESTIGATION RESULT (flatslab-inv Explore agent, 2026-08-04) — RESOLVED
- The slab is REAL CUDEM subaerial beach data, sampled deliberately landward to the HAT
  contour (ADR-093 Amendment 4; walk terminates at HAT / grid edge / 2000 m ceiling —
  grid_sizing_chain.py:2159-2219, bathymetry.py:2059-2081).
- distance=0 anchors at the LMSL depth-0 crossing (bathymetry.py:2007-2021, :2096-2100) —
  the MEAN-sea-level contour, NOT the instantaneous waterline. Water at x=0 ≡ tide height
  (2.2 ft = today's tide above MSL — plausible vs MHHW ≈ +0.8 m).
- The 0.03 ft floor: surf_1d_analytical.py:780-781 `depths = max(signed+tide, 0.01)` —
  0.01 m = 0.0328 ft. Solver floor destroys the sign; published `transect[].depth` is the
  CLAMPED MODEL INPUT, not beach geometry. No landward truncation anywhere; shared fallback
  profile structurally cannot produce negative distances (PCHIP rejects) → not an artifact.
- TRUE WATERLINE computable now from existing quantities: signed unclamped
  `bathymetric_profile` (in scope at beach_profile.py:660) + `_tide_level` (:1053) +
  `_interpolate_zero_depth_crossing` (bathymetry.py:1928-1953; solve signed == −tide).
- NEW FINDINGS to surface: (1) surf.py:389-423 `_compute_median_bathy_profile` feeds SurfBeat
  with NO distance filter → negative-distance land points enter the median profile;
  (2) confirmed the same payload carries two tide bases (pipeline real tide vs side-run 0).

## GATE B EVIDENCE (2026-08-04, coordinator-run, commands in transcript)
- Deploy: api d818461 pulled+restarted on weewx, health 200 (deploy-api.sh output).
- COLD path through proxy: 503 at 45.19 s ("read operation timed out" in API journal
  00:34:59Z) — cold all-transects compute exceeded 45 s UNDER ABNORMAL LOAD: librewxr load
  avg 21.4, radar-container python PID 3332150 at 795% CPU for 23h48m, 726 MB available.
- DIRECT marine (warm per-timestep cache): 200 in 26.58 s, 4.7 MB.
- WARM through proxy: 200 in 28.08 s, 4.98 MB. Through Caddy full chain: 200 in 30.43 s.
- Proxy caches profile responses 1800 s → heatmap instant for 30 min after first success.
- Marine /health during compute: 8/8 probes 200 at 0.02-0.12 s (service does NOT block).
- B2 contention: /marine/{id} THROUGH THE API stalled during in-flight proxy compute
  (probe1 hang 20 s, probe5 hang 20 s, probe6 15.02 s) while direct marine health stayed
  fast → contention is API-side, not marine-side. Post-B1 starvation persists on the cold
  path only.
- GATE B VERDICT: heatmap end-to-end = PASS on warm/cached path (28-30 s < 45 s, 200);
  cold path under radar-load = FAIL once (45.19 s timeout). Radar container CPU surfaced to
  operator; D7 (precompute) materially strengthened.

## GATE A EVIDENCE (in progress, 2026-08-04)
- Round A commits a35373d/ca0689e/c39fe30/0debd2a verified vs allowlist (git show --stat,
  4 files only); coordinator grep re-run: stripped markup absent from Current Swell card
  (remaining matches only in 72h forecast section, out of A2 scope); fillPct spot-check
  (SurfingTab.tsx:219-224) and backoff spot-check (useApiQuery.ts:240-300) both match spec.
- Deviation noted: implementer ran read-only vitest locally on DILBERT (reference forbids
  node toolchains there) — results treated as smoke only; weather-dev is canonical.
- Deployed: dashboard 0debd2a pushed + redeploy-weather-dev.sh OK (built 4.31 s).
- LIVE screenshots (Playwright on weather-dev, saved in session scratchpad):
  - Row 1 (A1 bars): PASS — Wave Height 28/35 ≈ 80% fill, Wave Period 1/35 sliver,
    Organization 18/30 ≈ 60% (gate-a-surf-full.png).
  - Row 2 (A2 strip): PASS — card = title + 3 stat tiles + peel + component table +
    compass; no shadow/AT BREAK/SurfBeat/best-peak/zone text (same shot).
  - Row 3 (A3 labels): **FAIL** — bg chips present but face labels overlap ("2.8/2.2 ft" +
    stray "2"), partition strings overprint, "Spilling" clipped (gate-a3-heatmap.png).
    Remediation sent to round-a-dashdev (stagger must move the 4-row label unit together;
    all-vs-all collision test; clamp to plot area).
  - Row 4 (A4): network log shows all API 200 + retry=0 error states; live 503-kill test
    still to run at gate close. NOTE: imagery tile 503s observed (6 tiles) — imagery
    provider issue, unrelated to Round A; parked.
- Gate B addendum: Surf Height Map card RENDERS LIVE with real data (gate-a3-heatmap.png
  bottom) — the card that was structurally unable to load before B1.
- A-T: test-author acked + implementing; scope extended (lead call) to reconcile stale
  D4.2 zone-context-line test (pins S-SPEC-2-stripped text; sibling D5.2 overlay test
  untouched).
- Radar container restarted per operator (runaway python 795% CPU 24 h): load 21→15↓,
  available mem 726 MB→2.87 GB, top consumer now marine 3.5%.
- A-T ACCEPTED: commits 963d311 (D2/A1/D4.2 guards) + 6a8c6a2 (A4 backoff guard), allowlist
  clean (2 test files), fail-against-pre-change transcripts provided for all 3 guard
  families. Pushed. CANONICAL weather-dev run: `npx vitest run SurfingTab.test.tsx
  useApiQuery.test.ts` → 27/27 pass (00:57Z). Brief erratum recorded by agent: restore
  steps must use `git checkout HEAD -- <file>`, not the intermediate commit.
- Doc-code sync (coordinator, same round): DESIGN-MANUAL — SURF-1 /100 section replaced
  with per-category fill rule + provenance/denial note; factor-bar bullet + additive-identity
  line updated; Swell Card row rewritten to stripped baseline with NOT-on-card list.

## GATE A/B CLOSE-OUT SYNTHESIS (2026-08-04 ~01:20Z)
- A3 follow-up 8f035cd deployed; live 3-point screenshot (decisive.png) STILL shows
  overlaps: stray glyph behind "2.8 ft"; 2nd break's partition/breaker rows overprint the
  x-axis title + zone chips. ROOT CAUSE (confirmed by blind audit F1): collision set only
  contains OTHER break-point labels — axis title/zone chips are not obstacles; algorithm
  saturates at BP_LABEL_MAX_LEVELS=6 with clamp collapsing rows onto identical Y (auditor
  simulated with real constants: 5 clustered points → 10 residual overlapping pairs).
- Kill test (A4/Gate A row 4): marine stopped 01:03:52-01:06:28Z (156 s); client polls
  (120 s cadence) returned 200 throughout — API response cache absorbed the outage; tab
  never degraded, no reload needed. PASS (retry path itself proven by fake-timer guard that
  fails pre-change). Post-restart transient: profile card showed "empty" text ~20-60 s while
  marine recomputed; resolves itself (90 s check: unavailable-text 0, svg present).
- BLIND AUDIT (round-a-audit closeout): A1/A2/A4 PASS adversarial review (ruled out /100
  regression, orphaned i18n, strip overreach, pollInterval units, timeout leakage, retry
  hammering). F1 MAJOR (A3, above). F1b MEDIUM: no BeachProfileChart regression test (A3
  guard was never in the plan's A-T row — lead omission to note). F2 BLOCKER (Gate B): at
  ~01:13Z two consecutive all-transects requests hit the 45 s timeout and were served by
  the proxy's STALE-CACHE fallback (journal: "read operation timed out" + "serving cached
  response") — 200 masking a failing live compute. Lead synthesis on F2 evidence: the
  auditor's "timestep 4 h old = stale" sub-claim is miscalibrated (21:00Z is the model
  cycle timestep; fresh computes return the same value) — but the journal cache-fallback
  evidence is solid. Timing context: auditor measured minutes after the kill-test restart
  (cold marine caches). Coordinator's genuine live measurements (00:40Z): 26.6 s direct /
  28.1 s proxy / 30.4 s Caddy fresh 200s. VERDICT: compute sits 26-50 s depending on load
  → 45 s budget is knife-edge; structural impossibility fixed, reliability not guaranteed.
- Audit process note accepted: shipped A3 algorithm differs from S-SPEC-3's literal 56px/
  14px text (lead-authorized during remediation) — plan spec text needs sync whenever A3
  disposition lands.
- OPERATOR RULINGS (2026-08-04, chat): (1) A3/F1 → drop the partition-annotation +
  breaker-type text rows from the interim chart; stop investing in the old chart ("why are
  we wasting time on the old chart?"). Lead-direct (mechanical deletion). (2) F2/Gate B →
  D7 precompute is the proper fix, done in NORMAL plan order ("does not need accelerated,
  everything in the plan is a priority"). Coordinator's conservative read: NO timeout bump
  (45 s stays; cache-fallback behavior stands until D7) — flagged to operator for cheap
  correction if misread. (3) Unification contract addition APPROVED: publish signed beach
  elevations + tide-aware waterline. Round P (profile unification) is now fully authorized:
  side-run deletion + zones/shapes/jacking from pipeline + new waterline/elevation fields.

## ROUND P (unification) — acceptance + deploy (2026-08-04 evening)
- Implementation ACCEPTED: marine 4e0ff18 (P1.1-P1.3) + 8c2def8 (P1.4), api ac96064 (P2).
  Allowlist clean (4 files/2 repos). Coordinator grep re-runs: zero run_1d_analytical call
  sites in beach_profile.py; no live tide_level=0.0; new fields in response dict +
  conversion table. Spot-checks: zones fed seaward-first published breaks (sort :658 →
  classifier outer=[0] ✓); waterline helper keeps seaward-most crossing on ascending
  signed profile ✓; jacking gamma=0.73 unchanged ✓. P1.3 extraction declared
  (_compute_wave_shapes, byte-identical). Brief over-spec caught by agent: tideLevel
  already in conversion table (marine_response_conversion.py:229, lead-verified) — only
  waterlineDistance/elevation added.
- BASELINE (pre-deploy, fresh timestep): impact zone 155.0→112.3 ft vs breaks
  [219.8, 200.2, 137.9, 118.3] ft (disjoint = the defect); waveShapes N=31 max dist
  7008.7 ft; new fields absent.
- EXPECTED post-deploy (stated pre-look): impactZone.startDistance ≈ 219.8 ±5 ft;
  waveShapes max distance ≤ ~463 ft; tideLevel finite; waterlineDistance ∈ [−297, 0] ft
  (or null + WARNING); beachElevation present, signed.
- Pushed both repos; deploy-marine.sh running (47c8084 dead-code + Round P ride together);
  deploy-api.sh next; then live checks + journal sweep + reality gate + publish-liveness.

## ══════════ RESUME POINT (session compressed 2026-08-04 ~20:20 PT) ══════════

**WHERE WE STOPPED:** Round P deployed to librewxr — verified running commit 8c2def8,
process started Wed 2026-08-05 03:14:25 UTC, /health + /manifest 200, auth enforced
(deploy-marine.sh transcript). 47c8084 dead-code deletion deployed with it.
deploy-api.sh (Round P conversion entries, api ac96064) was LAUNCHED in background at
stop time — VERIFY IT COMPLETED on resume (`ssh weewx` → API health, or re-run
`./scripts/deploy-api.sh --skip-pull` if unclear; API warm-up 130 s).

**IMMEDIATE NEXT STEPS (in order):**
1. Verify deploy-api.sh completed (health 200) — if not, re-run it.
2. Round P LIVE CHECKS against the pre-stated expected numbers (baseline + expectations
   recorded in the "ROUND P acceptance + deploy" section above):
   `ssh -F .local/ssh/config weewx "curl -sk 'https://localhost:8765/api/v1/surf/huntington-city-beach-pier/profile'"`
   → impactZone.startDistance ≈ outermost breakPoint distance ±5 ft (baseline defect:
   155 vs 220); waveShapes max distance ≤ ~463 ft (was 7,009); tideLevel finite;
   waterlineDistance ∈ [−297, 0] ft or null+WARNING in journal; beachElevation present
   signed; units block has waterlineDistance/elevation in ft.
3. Post-deploy journal sweep (sudo!): `ssh librewxr "sudo journalctl -u
   weewx-clearskies-marine --since '2026-08-05 03:14' --no-pager | grep -iE
   'error|warning'"` — new classes vs pre-deploy = findings.
4. Publish-liveness + reality gate (rules/verification.md): forecast still publishing
   within one cycle; paste our dominant partition Hs/Tp/dir beside NDBC 46253 obs (state
   comparison quantity + tolerance BEFORE looking). This deploy didn't touch model
   physics — expect unchanged vs pre-deploy.
5. Dispatch test-author for Round P guards (P-T): waterline-crossing KAT (hand-computed
   fixture; new function → pre-change proof = ImportError, declare non-falsifiable pin);
   zones-anchor-to-published-breaks guard; _compute_wave_shapes extraction-fidelity pin.
   Then blind auditor for Round P (include the surf.py:389-423 median-bathy land-points
   investigation in its scope).
6. Rebuild the D5 mockup from the UNIFIED live payload (real zones, real waterline, real
   beachElevation — no synthesized anything) → operator final D5 sign-off → then the
   dashboard profile-card implementation round. Mockup source PERSISTED at
   docs/planning/mockups/beach-profile-redesign-mockup.html (+ data json). Artifact URL
   (same one throughout): https://claude.ai/code/artifact/86d75d59-5fc7-42b2-890c-5820dd3db374
7. Then D6 re-present (zones per break — now meaningful), D7 in normal plan order,
   Round S (surf score rebuild per plan §S-SPEC-1) next major round.

**STANDING SESSION FACTS:**
- Operator authorized push/deploy for testing all session. All agent rounds used
  scope-ack protocol; all agents completed (none in flight at stop).
- Repos at stop: meta local main 9ae2dea+1 uncommitted scratch edit (commit on resume);
  dashboard main 96f5478 (pushed/deployed); marine main 8c2def8 (pushed/deployed);
  api main ac96064 (pushed; deploy launched).
- Rounds A/B CLOSED (evidence above). Round P: implementation accepted, deploy done
  (marine)/in-flight (api), QC (guards+audit+gates) NOT yet done.
- Radar container librewxr-librewxr-1 restarted this session (runaway 8-core python);
  watch for re-pin — if compute times degrade again, check it first.
- Plan erratum fixed in flight: S-SPEC-4 pollInterval units (seconds not ms). Brief
  erratum: restore steps must use `git checkout HEAD -- <file>`.
- DESIGN-MANUAL synced for A1/A2 (SURF-1 removed, provenance note added, Swell Card row
  rewritten). API-MANUAL/plan §S-SPEC-3 text sync for A3-as-shipped still owed at Round P
  close (add to doc-sync checklist).

## Evidence log
(append gate rows / command outputs here as rounds close)

## ══════════ RESUME POINT 2 (session compressed 2026-08-05 ~07:45Z / ~00:45 PT) ══════════

**IN FLIGHT AT STOP: roundw-dev (clearskies-api-dev agent, named "roundw-dev") is
mid-implementation of Round W.** Scope ack CONFIRMED; expect its closeout via
SendMessage/task-notification. Its brief:
docs/planning/briefs/ROUND-W-WAVE-REFORM-BRIEF-2026-08-05.md — READ IT before acting on
the closeout. NOTE: the marine repo may gain W1/W2/W3 commits at any time; do not touch
that repo until the closeout lands.

**RESUME CHECKLIST (in order):**
1. Process roundw-dev closeout → ACCEPTANCE GATE: independent local pytest re-run
   (expect listed Z2-pin failures ONLY — each must be explainable as pinning superseded
   clamp/hysteresis behavior; any other failure = investigate); allowlist diff (2 files:
   surf_1d_analytical.py, surf_1d_pipeline.py); verify its 3 throwaway-script outputs
   (closed-form shelf agreement, bar-trough double onset, real-transect run); grep
   checks (both clamps gone, no B-J/roller call sites).
2. Dispatch clearskies-test-author for W guards: KAT vs the paper's closed-form shelf
   relaxation H²(x)=Γ²h²+(H_b²−Γ²h²)·exp(−K(x−x_b)/h) with hand-computed literals;
   bar-trough double-onset guard; constants pins (Γ=0.40, K=0.15); UPDATE the Z2 pins
   that the state-based path supersedes (document supersession); invariant-warning test.
3. Blind auditor (fresh brief; auditor must attack: numerical stability of forward-Euler
   on nonuniform dx, energy conservation sanity, behavior at clamp-removal edge cases,
   the combined-profile saturation helper, unexpected reshaping of faces/zones/jacking).
4. Push + deploy-marine.sh + canonical librewxr pytest + journal sweep.
5. REALITY GATE (pre-state expectations BEFORE looking): (a) structural test vs operator
   orthophoto anchors — two distinct breaks, outer ≈3× inner's waterline distance
   (~300 ft vs ~100 ft, approximations sufficient to judge); waterline-relative =
   published distance − waterlineDistance; (b) matched-time webcam at known tide for
   sharpening (inv-break-geometry method); (c) NDBC 46253 beside; (d) OPERATOR
   worked-examples review MANDATORY before round close (every surf number reshapes).
6. After W closes: D5 dashboard implementation round (card consumes the reshaped
   payload; skips zero-width bands; smoothing direction per operator), then Round S
   (surf score rebuild, ADR-101).
7. LESSON TRIAGE to operator (owed): 2 over-escalations (reality-gate disposition,
   hotstart comparison); invented vocabulary ("model-run-semantics"); 3
   speculation-as-fact incidents (ankle-deep dismissal, bathymetry-staleness story,
   fabricated ±100 ft tide figure — all operator-corrected); standing directive "real
   physics over clamps/bandaids, project-wide". Proposed rules-file edits go to
   operator BEFORE landing.

**REPO STATE AT STOP:** dashboard main 96f5478 (pushed/deployed weather-dev). marine
main 36fab04 (pushed/deployed librewxr 06:07:06Z; roundw-dev will add local commits).
api main c99f6d5 (pushed/deployed weewx). meta local main (not pushed — no instruction).

**STANDING FACTS (this session):**
- Round W authorization is explicit and total: operator ordered real physics replacing
  the fake clamps; bathymetry-first recommendation REJECTED; DDD constants Γ=0.40
  K=0.15 verified from the ORIGINAL paper (PDF fetched; recommended pair for varying
  slopes; closed-form shelf solution exists → KAT basis). Onset γ=0.73 UNCHANGED.
- Operator ground truth: HB double break is LONG-STANDING; outer ≈300 ft / inner
  ≈100 ft from the (orthophoto) waterline; approximations sufficient to judge the
  model. NO uncertainty figure on record (coordinator's ±100 ft claim STRUCK as
  fabricated). Real HB tide movements are not extreme on average (operator).
- Rounds A/B/P/Z CLOSED with full evidence (see blocks above). First-ever warm start
  proven 05:26:05Z; foam-to-waterline live; perBreakZones live in ft.
- Radar container: operator repaired; post-repair radar 64% CPU (was 211%); load avg
  still ~9 → RE-CHECK after rebuild settles; open finding if unexplained.
- Deploy scripts: ./scripts/deploy-marine.sh (meta root; --no-restart exists),
  ./scripts/deploy-api.sh (meta root). Marine tests on librewxr:
  `sudo -u ubuntu bash -c "cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest <files> -q"`.
  LOCAL marine unit tests work (Python 3.14 + pytest, from repo root).
- Marine-direct payload: ssh librewxr, bearer from /etc/weewx-clearskies/marine/secrets.env,
  https://localhost:8780/surf/huntington-city-beach-pier/profile (slow under load; use
  --max-time 300). Proxy cache-bust: ?cb=<nonce> on the weewx API URL.
- Agent names still addressable: roundw-dev (in flight), roundz-dev, roundz-tests,
  roundz-audit, roundp-tests, roundp-audit, inv-wave-reform (all completed).
- OPERATOR STYLE (hard-learned tonight): plain words, no invented vocabulary, define
  terms; never state unverified reasoning as fact — label hypotheses or omit; do not
  escalate operational-code dispositions (only genuine physics/architecture); the
  operator's domain knowledge outranks model-derived estimates about this beach.

## ROUND P LIVE CHECKS — completed 2026-08-05 03:14–03:27 UTC (coordinator)

**Deploys verified complete:**
- marine: commit 8c2def8, process start 03:14:25 UTC, health/manifest 200, auth 401 ✓
- api: deploy-api.sh exit 0, "API health check: 200 OK" after 130s cache-warm ✓

**First proxy fetch was STALE CACHE** (generatedAt 03:13:50Z, predates restart; showed all
baseline defects). Bypassed two ways: (a) marine direct on librewxr:8780 with bearer secret,
(b) proxy with cache-buster `?cb=roundp1` → fresh generatedAt 03:24:30Z. Un-busted proxy URL
serves stale until 03:43:50Z (TTL by design).

**Check results (fresh payload, timestep 2026-08-05T03:00:00Z):**
1. Zones anchor to published breaks: impactZone.startDistance 25.55 m vs outermost break
   25.6 m (Δ 0.05 m, well within ±1.5 m) — **PASS** (baseline defect was 47 m disjoint).
2. tideLevel: −0.34 m, finite — **PASS**. API converts → −1.1155 ft exact.
3. waterlineDistance: +9.44 m (→ +30.98 ft). Pre-stated range [−297, 0] ft was written for
   an above-datum tide; tide is −0.34 m so the waterline sits SEAWARD of the LMSL zero —
   sign convention verified: interpolated beachElevation at 9.44 m = −0.339 m ≈ tideLevel
   exactly — **PASS, range expectation superseded by sign-consistency proof**.
4. beachElevation: 261 pts, signed, dist −73.5..2157.6 m, elev +2.91..−15.03 m — **PASS**.
   Per-item ft conversion exact (−73.5 m → −240.98 ft).
5. units block: tideLevel/waterlineDistance/elevation all "ft" — **PASS** (P2 verified).
6. waveShapes max distance: 2157.6 m ≈ 7078 ft vs pre-stated "≤ ~463 ft" — **EXPECTATION
   ERRATUM, not a defect**: _compute_wave_shapes emits 31 evenly-spaced samples across
   whatever arrays it receives; baseline behaved identically (−275..7009 ft). The ≤463 ft
   figure wrongly assumed pipeline arrays were trimmed to the nearshore domain. Unification
   goal (shapes from same arrays as transect/breaks) IS met. Whether to trim shapes for the
   card is a D5 display decision — flag to operator.
7. jackingFactors: 0 entries — SAME in baseline (pre-deploy payload also 0). Pre-existing,
   not a Round P regression. Note for auditor.

**Journal sweep (since 03:14):** no tracebacks/marine errors. Only ERRORs = HRRR NOMADS
404s (t02z f13–f18 not yet published upstream; pre-existing pattern).

**Reality gate: PENDING — restart transient.** Post-restart cycles run with bulk-fallback
on ALL 162 transects (Hs 0.49 m Tp 4.7 s Dir 219°) because SWAN L1/L2 cold-started
("persistent hotstart timestamp unparseable" → stale hotstart deleted). Pre-restart cycles
(02:57, 03:13) had bulk-fallback=none. Precedent: 01:06 restart showed same pattern,
recovered clean by 02:57 (~1 warm SWAN cycle). Expect recovery ~04:30–05:00Z; run reality
gate (dominant Hs/Tp/dir vs NDBC 46253, tolerance stated before looking) AFTER fallback
clears. Fresh-vs-baseline break differences ([84,54] ft vs [220..118] ft, same timestep)
are explained by this input-state transient, NOT Round P code (pipeline/SWAN untouched).

**NEW parked finding (for auditor / backlog):** "hotstart timestamp unparseable
(token=None)" is CHRONIC — 223 journal hits since Jul 28, across multiple process
instances, recurring even mid-process (Jul 30 04:42 AND 07:05 same PID). Every occurrence
forces a SWAN cold start (wasted compute + transient all-transect bulk fallback + degraded
partitions). Pre-dates Round P and 47c8084. Deserves its own investigation item.

**Remaining Round P QC:** test-author guards (waterline KAT, zones-anchor guard,
_compute_wave_shapes extraction pin) → blind auditor (scope: + surf.py:389-423 median-bathy,
jackingFactors-always-empty, chronic hotstart) → reality gate after fallback clears →
doc sync (API-MANUAL new fields, plan §S-SPEC-3 A3-as-shipped) → round close.

## ROUND P QC session 2 (2026-08-05 03:30Z →)

- Doc sync DONE (meta 3c74170): API-MANUAL single-transect table — 3 new field rows
  (tideLevel/waterlineDistance/beachElevation), waveShapes/surfZones/jackingFactors rows
  re-provenance'd to the unified pipeline arrays, units paragraph extended; plan
  S-SPEC-3 "AS SHIPPED" note (label rows deleted per operator ruling, 96f5478) +
  S-SPEC-4 pollInterval erratum note (120 s, not 120_000).
- Targeted marine pytest vs deployed 8c2def8 (librewxr, cmd:
  `sudo -u ubuntu bash -c "cd /home/ubuntu/repos/weewx-clearskies-marine && .venv/bin/python -m pytest <5 files> -q"`):
  **10 failed, 85 passed** — all 10 = `TypeError: _build_transect_profile() missing
  required arg 'tide_level'` in test_beach_profile_partition_index_spaces.py. Introduced
  stale call sites (contract change per brief; implementer correctly barred from tests).
  BLOCKS round close until repaired. Reproduced locally (local Python 3.14 + deps CAN run
  marine unit tests — "no local toolchain" assumption in Round P brief was WRONG; canonical
  run stays librewxr py3.12).
- test-author DISPATCHED (brief docs/planning/briefs/ROUND-P-TESTS-BRIEF-2026-08-05.md):
  T0 repair 10 call sites (tide_level=0.0, lead call), T1 waterline KAT (hand-computed,
  non-falsifiable-vs-pre-change declared), T2 zones-anchor guard (must fail vs 47c8084 —
  coordinator verifies via read-only checkout at acceptance), T3 _compute_wave_shapes pin,
  T4 new-fields guard. Scope ack received + confirmed 03:33Z.
- **GUARDS ACCEPTED (2026-08-05 ~03:57Z).** test-author commits 7ee5a3c (T0, 9 call
  sites +tide_level=0.0), 1d6c9b0 (T1 waterline KAT, 6 tests), 541644d (T2-T4, 6 tests).
  Acceptance evidence: (1) independent local re-run `67 passed in 0.21s`; (2) allowlist
  diff clean — 3 commits touch exactly the 3 allowed test files, 0 source files;
  (3) fail-against-pre-change verified by coordinator in read-only worktree at 47c8084:
  raw run = collection ImportError (helpers absent); with T3-imports+tide_level kwargs
  harness-stripped, T2 fails AT ITS ASSERTION (`response["surfZones"] is None` — old
  side-run yields no zones from pipeline-shaped fixtures) and T4 fails KeyError
  'tideLevel' — 4 failed, 2 deselected; worktree removed; (4) T1 hand-math spot-check
  (tide −1.0 → frac 3/5 → 6.0 m) verified independently; T1 declared
  non-falsifiable-vs-pre-change (new function) per rule. (5) CANONICAL librewxr run at
  541644d (pushed 8c2def8..541644d; deploy-marine.sh --no-restart, STALE PROCESS banner
  expected — test-only commits, running 8c2def8 source identical): `67 passed, 1 warning
  in 0.55s`. No-restart chosen deliberately: a restart re-triggers the chronic hotstart
  cold-start and would wreck the just-recovered partitions.
- **SWAN partitions RECOVERED 03:53:02Z** (monitor caught `bulk-fallback transect(s)=none`,
  best_peak 0.79 m) — ~40 min after restart, consistent with the 01:06 precedent.
- **Radar container RE-PINNING (watch item FIRED, surfaced to operator):** librewxr-
  librewxr-1 python at 211% CPU, 408 CPU-min since 00:44 start; load 7-9. NOT restarted —
  no standing authority; last restart was a one-time operator order. Marine endpoint
  recompute currently slow (>45 s → proxy 503 on uncached keys, known Gate B marginality).
- Blind auditor DISPATCHED (brief docs/planning/briefs/ROUND-P-AUDIT-BRIEF-2026-08-05.md):
  disprove unification claim + 3 side-investigations (surf.py:389-423 median-bathy land
  points; jackingFactors always empty; chronic hotstart token=None).
- **REALITY GATE — PRE-STATED (before looking at post-recovery numbers):**
  Comparison quantity: dominant partition at handoff, HB pier, first post-recovery cycle
  (bulk-fallback=none) vs pre-deploy baseline (physics untouched ⇒ structure preserved).
  PRE-DEPLOY BASELINE (timestep 03:00Z, generated 03:13:50Z, stale payload): PT0
  groundswell 14.33 s @ 197.2°, heightM 1.242 at handoff, meanFace 2.56 m, meanBreakDist
  123.2 m; PT1 wind_swell 5.40 s @ 257.6° (no breaks). TOLERANCE: period ±2 s, direction
  ±15°, Hs ±30%, classification unchanged (allows hourly evolution across model cycles).
  NDBC 46253 obs pasted BESIDE for the record — NOT gated (model-vs-ocean belongs to the
  parked inv-swell investigation). Out-of-tolerance vs baseline = deploy FAILED → rollback
  first, diagnose second.

- **REALITY GATE RUN (2026-08-05 04:05Z, post-recovery payload: timestep 04:00Z,
  transect 14, marine-direct, cmd + json in scratchpad roundp-postrecovery.json):**
  | quantity | baseline (03:00Z, pre-deploy) | post-recovery (04:00Z) | tolerance | verdict |
  | PT0 period | 14.330 s | 14.315 s | ±2 s | **PASS** (Δ0.02 s) |
  | PT0 direction | 197.20° | 197.23° | ±15° | **PASS** (Δ0.03°) |
  | PT0 class | groundswell | groundswell | unchanged | **PASS** |
  | PT1 | wind_swell 5.40 s @ 257.6° | wind_swell 5.40 s @ 257.7° | — | **PASS** |
  | PT0 heightM @ handoff | 1.242 m | 0.378 m | ±30% | **OUT OF TOLERANCE (−70%)** |
  NDBC 46253 beside (03:26Z obs): WVHT 0.7 m, DPD 13 s, MWD 178°; spectral: swell 0.3 m
  @ 13.3 s S, wind-wave 0.7 m @ 8.3 s W (cmd: curl ndbc.noaa.gov/data/realtime2/46253.txt|.spec).
  **Analysis (surfaced to operator, disposition PENDING — NOT auto-rolled-back):** the
  Hs shift is state-driven, not code-driven: (a) Round P diff = 3 files
  (endpoint/bathymetry-helper/extraction), 0 lines in the partition-handoff/SWAN path
  that produces heightM (`git diff 47c8084..8c2def8 --stat`); extraction pinned by T3 +
  pre-existing test_wave_shape_classification.py 23 tests still pass unchanged;
  (b) the buoy SIDES WITH THE NEW VALUE: NDBC swell 0.3-0.4 m vs new PT0 0.378 m
  (match) vs baseline 1.242 m (3-4× buoy) while the ocean barely moved between obs
  hours (0.8→0.7 m); (c) baseline state was produced downstream of the CHRONIC hotstart
  corruption (223× "timestamp unparseable" → perpetual cold-start cycling), the deploy
  restart re-derived SWAN state from scratch. Hypothesis for auditor/operator: the
  pre-deploy inflated heightM is a SYMPTOM of the chronic hotstart defect (stale/corrupt
  SWAN state), i.e. the gate's failing leg indicts the BASELINE, not the deploy.
  Rollback NOT executed: it would not restore baseline state (state is regenerated, not
  in the code), would re-trigger another cold start, and the buoy evidence says the
  current value is the better one. Operator rules on disposition.
  **DISPOSITION (2026-08-05, operator: "is this architecture? No... so why am I being
  bothered about it?"):** deploy ACCEPTED, no rollback — coordinator's call, per the
  evidence above. Inflated pre-deploy heightM folded into the chronic-hotstart
  investigation (auditor side-investigation #3). Corroborating second sample: the
  original hung fetch completed with identical partitions (14.3145 s @ 197.225°).
  PROCESS-LESSON CANDIDATE (triage to operator at round close, per lesson-capture rule):
  a verification-gate failure whose evidence clearly indicts the baseline — and where no
  actual rollback would be executed — is a coordinator disposition to record, not an
  operator escalation. Candidate edit to rules/verification.md reality-gate wording.
- **Radar container re-pin:** operator 2026-08-05 "i will look into it" — theirs; no
  restart by coordinator; watch item stays.
- **D5 GO (operator 2026-08-05 "D5 yes at it"):** build the mockup from the live unified
  payload now (not held for audit close). D6 (per-break zones y/n) still UNANSWERED —
  re-present WITH the rebuilt mockup via its per-break-zones demo toggle, per the
  original "re-present after unified data + corrected mockup" instruction.

## ROUND Z (surf-zone truthing) — acceptance + deploy (2026-08-05 ~04:40Z →)
- Authorized: operator "1. yes. 2. yes." + D6 "yes" + domain ruling "HB is notorious for
  its double break". Brief: docs/planning/briefs/ROUND-Z-SURF-ZONE-TRUTHING-BRIEF-2026-08-05.md.
- Implementation: marine f4354b2 (Z0 hotstart bounded line-scan, cap 2 MB), 4c0f7e7
  (Z1 waterline foam-end + Z2 hysteresis 0.15 / depth floor 0.15 m / _MIN_BREAK_HS_M),
  b551d03 (Z3 perBreakZones + unavailable mirror), api c99f6d5 (Z4 breakDistance entry —
  converter mechanism VERIFIED by agent and lead independently: _walk recurses
  unconditionally by structure, _resolve_group matches leaf key names, nested zone keys
  pre-covered at _FIELD_GROUPS:218-222).
- ACCEPTANCE PASS: (1) independent pytest re-run 99 passed (marine, 7 files);
  (2) allowlist diffs clean (4 commits, exactly the 4 allowed files); (3) spot-checks:
  hysteresis armed-state machine correct (filtered crossings don't disarm), Z0
  incremental line-iterate (no slurp, cap enforced, None-safe); (4) behavioral proof on
  live SI arrays (transect 14, 04:00Z): old breaks [67.7, 62.7] m → NEW detector returns
  EXACTLY [67.68] (jitter inner break eliminated); aggregate + per-break foam end 19.66 m
  = first sample inside waterline 20.52 m (one 4-m sample spacing, as specced);
  perBreakZones single entry consistent. NOTE: coordinator's pre-statement misremembered
  the older payload's break distances (25.6/16.6) — corrected to this payload's actual
  67.7/62.7 before judging; substance identical. (5) beach_profile reorder deviation
  (flagged by agent): 49+/38− consistent with pure move + threading; confirmed via live
  payload checks post-deploy.
- DEPLOYED: marine b551d03, process start 04:52:26 UTC, health/manifest 200, auth 401.
  Near-miss recorded: first push pair hit the marine repo twice (cwd error) — api push
  initially skipped, caught by reading push output; api pushed ac96064..c99f6d5 after.
  deploy-api.sh re-run from meta root (first attempt used wrong path from api repo cwd).
- Z-gate pre-stated live expectations: journal ZERO "hotstart timestamp unparseable"
  post-04:52 once SWAN levels run; single-entry breakPoints (no jitter pair) on saturated
  profiles; foam end within one sample of waterlineDistance; perBreakZones in marine SI +
  API ft payloads with units.breakDistance = ft.
- LIVE CHECKS PASS (05:00-05:05Z): marine-direct 05:00Z transect 88 — breaks [26.29 m]
  single entry; foam 21.29→9.29 m vs waterline 9.30 m (foam-to-waterline live);
  perBreakZones 1 entry consistent. API ?cb=roundz1: break 86.3 ft, foam→30.5 ft ==
  waterline 30.5 ft, units.breakDistance=ft. Z0 read PROVEN live (journal parses stamps:
  "stamped 20260807.180000 != requested start ..." — impossible pre-Z0; hotstart saved
  9.8 MB). API deployed (health 200; first deploy attempt used wrong script path from api
  cwd — rerun from meta root).
- GUARDS ACCEPTED (05:20Z-ish): 6a4851e/a3a0ae9/1321d8d; independent re-run 34 passed;
  allowlist clean (3 test files only); fail-pre-change proven NON-VACUOUSLY in worktree
  at 541644d with constants patched to literals: T-Z0 4096-prefix test FAILED, T-Z2
  jitter-suppression FAILED, T-Z2 shallow-shorebreak FAILED (0 breaks under old 0.3 m
  floor) — 3 failed, 10 passed; worktree removed.
- Z5 DISPATCHED to roundz-dev (operator ruling: stamp comparison is a coding-correctness
  fix, not an escalation — "you know what the intent is... why am I being asked this?").
  Design: `!=` → `<` (delete only when stamp PREDATES requested start); manual-verified
  (swan-user-manual.txt :2776-2779 INIT HOTSTART stationary initial values; :5757-5761
  hotfile time feeds only nonstationary COMPUTE defaults; crash-retry path :5145-5151 is
  the safety net). Expected stale-test signal: test_mismatched_hotfile_timestamp_cold_starts
  may fail (pins old equality rule) — test-author updates it next.
- Z5 test-update ACCEPTED (59f5e49; independent 10 passed; supersession documented in
  docstring). Full stack PUSHED b551d03..59f5e49, DEPLOYED 05:21:53 UTC (running commit
  59f5e49); canonical librewxr pytest 35 passed at 59f5e49.
- **FIRST-EVER WARM START PROVEN LIVE 05:26:05 UTC:** "SWAN level1: using hotstart from
  previous run (stamped 20260808.000000, requested start 2026...)". Zero crashes/
  predates/unparseable since deploy. Post-restart bulk-fallback window in progress —
  recovery timer running (cold-start baseline ~40 min; warm should beat it).
- Blind Z auditor dispatched (brief ROUND-Z-AUDIT-BRIEF-2026-08-05.md); priority
  question: quantitative over-suppression check of the 0.15 hysteresis on real HB
  bar-trough CUDEM profiles.
- **Z AUDIT CLOSEOUT (05:50Z-ish):** claims 1/3/4 could-not-disprove (waterline
  no-off-by-one; perBreakZones contract + null mirror; hotstart read+ordering incl.
  down-past-horizon path traced). Claim 2 DISPROVEN in part: F1 [HIGH] δ=0.15
  over-suppresses genuine double breaks (auditor ran DEPLOYED code on real CUDEM, 162
  transects: 4-18% re-arm at 2m/12-16s; most transects' trough ratio never drops below
  γ at all — roller momentum keeps Hs pinned ≥ γd, so most of the loss is PHYSICS
  ceiling, not tuning). F2 [MED] "0.15-0.3 m shorebreak registers" overclaim —
  saturation + _MIN_BREAK_HS_M=0.15 gives effective floor 0.2055 m (crossover verified
  numerically). F3 [LOW-MED] zero-width foamZone when impact clamp hits next break
  (5/162 transects live). Notes: waterline None-fallback dead-in-practice at this spot;
  hotstart accept path unbounded above (assumption documented, no live scenario).
- **COORDINATOR δ-SENSITIVITY SCAN (same method, monkeypatched deployed module,
  2m/16s SW/tide 0):** δ 0.15→7, 0.10→23, 0.05→46, 0.03→48, 0.01→52 (of 162).
  Detector ceiling ≈ 32%; δ=0.05 captures 88% of ceiling and keeps 2.5× margin over
  the ±2% jitter class. Knee = 0.05. Remaining ~68% unreachable by ANY δ (model's
  saturated Hs never dips below γ over HB's subtle trough relief — physics-level item,
  related to roller/decay modeling; candidate future round, NOT detector tuning).
- Lead synthesis: F1 accept → recommend δ 0.15→0.05 (operator judges at gate — the
  constant was explicitly gate-presented); F2 accept → fix overclaiming comment
  (lead-direct doc fix in code comment), _MIN_BREAK_HS_M change = operator option
  (recommend keep); F3 accept → recommend D5 card skips zero-width bands (display),
  contract unchanged; document in API-MANUAL.
- **GATE RULINGS (operator 2026-08-05, in chat):** (1) δ 0.15→0.05 YES + wave-reform
  physics investigation ordered ("that is what needs to happen"); (2) _MIN_BREAK_HS_M
  0.15→0.10 YES; (3) zero-width foam bands: card-side skip, tied to operator's standing
  heat-map SMOOTHING want ("so a few transects zeroing out does not make a difference" —
  fold into D5/D7 design). Operator communication flag (3rd tonight): explain in plain
  words, no invented terms.
- RETUNE SHIPPED lead-direct (operator-approved constants): marine 36fab04 (two
  constants + provenance comments + guard pins/hand-traces updated). Local 73 passed;
  pushed 59f5e49..36fab04; deployed, process start 06:07:06 UTC; canonical librewxr
  35 passed at 36fab04.
- **FIRED GUARD (gate event, investigated, benign):** 06:05:35 "SWAN level1: crashed
  with hotstart loaded — deleting stale hotstart and retrying cold" — same journal
  second shows `systemd: Stopping` — the RETUNE DEPLOY's restart killed SWAN
  mid-compute; the crash-retry heuristic misattributed the SIGTERM to the hotstart and
  deleted a good file. The 05:26:05 warm start completed cleanly (no crash signals
  05:26-05:31). Warm starts WORK. NEW parking-lot note: crash-retry cannot distinguish
  crash from shutdown → every mid-compute deploy costs one cold start (fix: check
  shutdown flag/exit signal before deleting; small, non-urgent).
- Wave-reform investigation: OPERATOR-ORDERED — post-breaking decay keeps Hs pinned at
  γ·d (waves never back off/reform); ~68% of transects can never show the real double
  break at any detector setting. Investigation = read our breaking/roller decay code vs
  the standard published treatment (broken waves decay toward a LOWER stable height,
  Dally-type reforming); findings + options to operator BEFORE any physics change.
- PROCESS CORRECTION (2nd over-escalation tonight, both operator-flagged): reality-gate
  disposition + hotstart stamp comparison were both coordinator calls presented as
  operator decisions. Lesson candidate for round close (surface triage per lesson-capture
  rule): operational validity checks (cache/state reuse, gate dispositions where evidence
  is one-sided and no rollback would execute) are NOT trigger-1 physics criteria; also
  ban invented vocabulary ("model-run-semantics") — plain English rule applies to
  coordinator reports.

## Verification evidence — Round Z (ROUND CLOSED 2026-08-05 ~06:30Z)
- Scope walkthrough (ROUND-Z-SURF-ZONE-TRUTHING-BRIEF + follow-ons): Z0 DONE f4354b2;
  Z1+Z2 DONE 4c0f7e7 (gate retune 36fab04: δ 0.05, Hs floor 0.10 — operator-approved);
  Z3 DONE b551d03; Z4 DONE c99f6d5 (api); Z5 DONE d0075fe (+ test update 59f5e49);
  guards DONE 6a4851e/a3a0ae9/1321d8d (+ pins updated in 36fab04). 0 MISSING.
- pytest: local 73 passed at 36fab04 (7-file set); canonical librewxr 35 passed at
  36fab04 (5-file Z set). Fail-pre-change proven non-vacuously in worktree (3 failed at
  assertions: T-Z0 4096-prefix, T-Z2 jitter, T-Z2 shorebreak).
- Auditor findings: 3 (F1 HIGH hysteresis over-suppression → REMEDIATED by gate retune
  to the measured knee 0.05; F2 MED floor overclaim → REMEDIATED, floor 0.10 + comments
  corrected; F3 LOW-MED zero-width foam → dispositioned card-side skip per operator,
  documented in API-MANUAL consumer note). 0 unremediated introduced findings.
- Live checks: single break on saturated profile (26.29 m), foam 21.29→9.29 m vs
  waterline 9.30 m, perBreakZones consistent in SI + ft (units.breakDistance=ft);
  Z0 read proven live; FIRST-EVER warm start 05:26:05 completed cleanly; 06:05 "crash"
  = deploy-restart interruption (investigated, benign; parking-lot note filed).
- Doc sync: API-MANUAL 149133b (perBreakZones + foam/detection semantics + known reform
  limitation + Z4 conversion note).
- Deferred/parked out of this round (all tracked in plan §2 STATUS parking lot):
  wave-reform physics investigation (inv-wave-reform, operator-ordered, IN FLIGHT);
  crash-retry-vs-shutdown note; parking lot 1a (stamp semantics) RESOLVED by Z5.
- ADR spot-check: ADR-093 Amendment 4 signed profile → waterline crossing consistent
  PASS; ADR-097 profile contract → manual updated same-round PASS.

## Verification evidence — Round P (ROUND CLOSED 2026-08-05 ~04:30Z)
- Scope walkthrough (brief ROUND-P-UNIFICATION-BRIEF-2026-08-04.md): P1.1 side-run
  deletion DONE (marine 4e0ff18); P1.2 zones-from-pipeline DONE (4e0ff18); P1.3
  shapes/jacking extraction DONE (4e0ff18, byte-identical declared + T3-pinned); P1.4
  three new fields DONE (8c2def8); P2 API conversion DONE (ac96064; tideLevel entry
  pre-existed). Guards leg (brief ROUND-P-TESTS-BRIEF-2026-08-05.md): T0–T4 DONE
  (7ee5a3c/1d6c9b0/541644d). 0 MISSING, 0 DEFERRED from scope.
- pytest: local `python -m pytest <5 files> -q` → 67 passed (coordinator re-run);
  canonical `ssh librewxr sudo -u ubuntu ... .venv/bin/python -m pytest <5 files> -q`
  → 67 passed at 541644d (py3.12).
- Auditor findings: main claim COULD NOT DISPROVE (5 named rule-outs, live in both unit
  systems at matching timestep 04:00Z). 4 findings, ALL pre-existing (median-bathy land
  points; hotstart 4096-byte read window root cause + vacuous test fixture; best-transect
  docstring drift; jacking-empty-by-selection non-defect) → all promoted to the plan §2
  STATUS parking lot (tracked, not narrative). 0 introduced-by-round findings.
- Lead synthesis: accept all 4 as parking-lot items; no remediation owed inside Round P
  (none introduced by the round); hotstart fix recommended as its own small round (also
  explains the reality-gate Hs anomaly and the 40-min post-restart degradation).
- Reality gate: period/direction/classification PASS vs baseline + NDBC 46253 beside;
  Hs leg out-of-tolerance → disposed ACCEPTED (state-driven; buoy sides with new value;
  operator declined escalation as non-architectural).
- Lead spot-check: waterline hand-interpolation reproduced published value exactly in m
  AND ft (audit reproduced independently to the last digit — two independent checks).
- ADR spot-check: ADR-093 Amendment 4 (signed landward sampling) — beachElevation now
  publishes the signed profile unclamped, consistent, PASS. ADR-097 (profile endpoint) —
  contract addition documented in API-MANUAL single-transect table + units, PASS.
- Doc-code sync: API-MANUAL (3c74170) matches shipped payload (fields verified live);
  plan §S-SPEC-3 as-shipped + S-SPEC-4 erratum notes committed same session.

## Round W — implementation ACCEPTED (2026-08-05 ~08:10Z); guards + audit IN FLIGHT

**OPERATOR AUTONOMY GRANT (2026-08-05 ~08:05Z, in chat, verbatim intent):** "please
continue autonomously for as much as you can, including D5, D6 and completion of Round
S." → Proceed through W close, D5/D6 dashboard round, and Round S without waiting.
The Round W reality-gate operator worked-examples review remains MANDATORY before W is
*formally* closed — prepare it fully, queue for operator return; do not block D5/S on it.

**Acceptance gate on roundw-dev closeout — PASS:**
- Commits e048494 (W1) / 71f6bff (W2) / c09a78c (W3) on marine main atop 36fab04, ahead
  3, NOT pushed. Allowlist diff verified by lead: only the 2 permitted files; pipeline
  diff = import + signature + docstring + body + 2 call sites, exactly the amended
  allowlist. Deviation accepted: apply_ddd_saturation takes gamma as 4th arg (existing
  onset gamma threaded, not a new constant).
- Lead-independent pytest (local, at c09a78c): 2 failed, 804 passed, 2 skipped —
  IDENTICAL to dev's tail. Failure dispositions (lead-verified):
  1. test_every_partition_gets_the_same_truncated_grid — pins superseded clamp
     monotonicity ("adding energy can only raise combined Hs"); not a property of real
     DDD physics. Supersession repair = guards brief T-W7.1.
  2. test_beach_profile_module_imports_and_calls_refinement — PRE-EXISTING (lead proof:
     `git show 36fab04:...beach_profile.py | grep -c refine` → 0; refinement moved in
     Round P to surf_1d_pipeline.py:2343 + endpoints/surf.py:951, both alive). Stale
     wiring pin, NOT a dropped-refinement regression. Repair = T-W7.2.
- Greps (lead-independent): both clamps gone; _battjes_janssen/_roller_model have zero
  call sites (defs + prose mentions only).
- Dev KAT outputs (accepted): shelf vs closed form <0.5% at 3 points; synthetic two-bar
  → 2 onsets [48,161], cessation ratio ≤0.40 in trough, min ratio 0.252 (real reform);
  real HB transect 2m/16s → SINGLE onset at 30.02 m (~98 ft), no outer break (ratio
  ~0.48 at ~91 m < 0.73 onset). CARRY TO REALITY GATE: inner break lands near the
  operator's ~100 ft anchor; the ~300 ft outer break does NOT appear at these standalone
  inputs. Measurement only — cause UNESTABLISHED (inv-break-geometry is the instrument;
  do not theorize). Production runs per-partition + SurfBeat blending, so live payload
  is the true test.
- Lead observations passed to auditor as attack vectors: (a) _combine_partition_hs
  redistribution ratio hs_total/hs_total_raw can exceed 1 (scales partitions UP where
  DDD relaxation > raw RSS); (b) apply_ddd_saturation cessation resumes RAW pass-through
  (discontinuity).

**In flight:** roundw-tests (clearskies-test-author; brief
docs/planning/briefs/ROUND-W-GUARDS-BRIEF-2026-08-05.md: T-W1..T-W6 new guards + T-W7
repairs the 2 stale tests; expects 0 failures at close) and roundw-audit
(blind adversarial; attack surface: forward-Euler stability on nonuniform dx, unbroken
flux march energy sanity, clamp-removal edge cases, combined-profile saturation +
redistribution>1 + cessation discontinuity, downstream faces/zones/jacking/perBreakZones
reshaping, scope). Both dispatched ~08:12Z, running in parallel (tests write only test
files; audit read-only).

**Next after both close:** push+deploy-marine.sh, canonical librewxr pytest, journal
sweep, reality gate w/ PRE-STATED expectations (structural: two breaks where present,
outer ≈3× inner waterline distance, ~300/~100 ft anchors ±slop for undated-orthophoto
waterline; matched-time webcam at known tide; NDBC 46253 beside) → operator
worked-examples review QUEUED for operator return. In parallel: D5/D6 dashboard round
(payload SHAPE unchanged by W — perBreakZones/zones/waterline fields already live from
Z; W changes values only), then Round S (ADR-101) after W deploy.

## Round W reality gate — PRE-STATED expectations (recorded 2026-08-05 ~08:30Z, BEFORE deploy/live look)

Ground truth (operator, 2026-08-05): HB pier double break is the persistent norm; outer
break ≈300 ft and inner ≈100 ft from the waterline — estimates measured off an UNDATED
orthophoto's visible waterline, "approximation... sufficient to judge whether or not our
model is approximate or not". Tide shifts the waterline some tens of ft per ft of tide,
and HB does not average extreme tide swings (operator).

Pre-registered PASS bands (coordinator's, coarse by design to match the ground truth's
own precision; operator may override at review):
- E1 STRUCTURE: at least one transect family near the pier shows TWO distinct published
  breaks (perBreakZones length 2) under swell conditions comparable to the orthophoto's
  (SW groundswell present). If live conditions are small/short-period, note and defer
  rather than fail.
- E2 INNER: inner-break waterline-relative distance (published distance −
  waterlineDistance) within 50–200 ft (0.5×–2× of the 100 ft anchor).
- E3 OUTER: outer break, when present, within 150–600 ft (0.5×–2× of 300 ft).
- E4 RATIO: outer/inner waterline-relative ratio within 2–4 (anchor 3.0).
- E5 NO-REGRESSION: foam zone still ends at the tide-aware waterline (±0.1 m of the
  crossing); faces/zones/jacking present and finite; no invariant WARNINGs in the
  journal at steady state; NDBC 46253 offshore Hs/Tp within the same tolerance bands
  used in the Round P gate.
- E6 KNOWN CARRY-IN: standalone kernel at 2 m/16 s produced a single break at ~98 ft
  (inner anchor ≈ match; no outer break — ratio at 300 ft was ~0.48 < 0.73 onset). If
  the LIVE payload also shows a single break while a matched-time webcam shows a double
  break, that is a FINDING routed to inv-break-geometry (bathymetry/inputs question,
  cause UNESTABLISHED — do not theorize), not a silent pass/fail; Round W's own claim is
  the PHYSICS (reform capability + no clamps), proven by the synthetic two-bar KAT.
- Webcam check: matched-time screenshot at known tide beside the rendered profile;
  operator worked-examples review MANDATORY before W formally closes (queued).

## Round W audit round — 4 findings, DEPLOY BLOCKED, W1b remediation in flight (2026-08-05 ~09:05Z)

Blind audit (roundw-audit) findings + lead dispositions:
- F1 HIGH CONFIRMED: forward-Euler unstable at depth < ds*K/2 = 0.075 m on the 1 m grid
  (inside the eps=0.01 floor); reproduced spike H/d=2.486 then snap-to-zero tail on 1:20
  slope. THE EULER STEP WAS THE LEAD'S OWN BRIEF SPEC — design error caught by audit.
  Fix W1b-1: exact integrating-factor step y_i = Γ²h^2.5 + (y_prev−Γ²h^2.5)·exp(−K·ds/h)
  in both march + apply_ddd_saturation (same ODE, different arithmetic — LC-22 precedent,
  methodology).
- F2 HIGH SPLIT: steep-slope H/d holding 0.75–0.88 (not relaxing to 0.40) judged REAL DDD
  behavior (stable target falls with depth; ratio equilibrium > Γ until depth stops
  falling — reform lives in troughs/flats; consistent w/ dev's real-transect decay).
  Miscalibrated-invariant sub-finding CONFIRMED (1.02·γd premise is wrong physics — γd is
  onset, not a during-breaking cap; ALSO the lead's own brief spec). Fix W1b-2: warn iff
  Hs > 1.5·γ·d at depths > _MIN_BREAK_DEPTH_M, in BOTH functions (also resolves F4).
  Supersedes W1a d373375 (which landed mid-race; interim, accepted, replaced).
- F3 MED-HIGH CONFIRMED: apply_ddd_saturation published up to 18% ABOVE raw RSS input
  (ratio>1) and goes blind to raw drops while BREAKING (6.8× stale demonstrated). Fix
  W1b-3: BREAKING output = min(marched, raw input) — energy-conservation bound (satur-
  ation may only remove energy vs its input; tracks drops). NOT the banned γd-flattening
  clamp (nothing flattens to γd; both physics signals preserved) — FLAG PROMINENTLY AT
  OPERATOR REVIEW anyway given clamp history. Dead hs_stack redistribution: pre-existing
  (old code also discarded), stays.
- F4 LOW-MED CONFIRMED: pipeline path had no invariant check → resolved inside W1b-2.
- Audit's clean rulings: equation/constants transcription faithful; Kr bookkeeping faith-
  ful; boundary-condition contract holds; no >/>= mismatch across detection paths; no
  scope creep (pipeline :750 face clamp is pre-existing/unrelated/untouched).
- Test-author independent pre-finding (same theme, before audit landed): old 1.02 check
  fired via honest public API on ~38% of a 42-combo sweep (onset detection-lag transient
  up to 1.064; floored-terminal degenerate to 2.2×). Consistent with audit F2's ~90%-of-
  points under some conditions.

Sequencing: W1a (d373375) accepted as interim, superseded. W1b in flight with roundw-dev.
roundw-tests: T-W2/T-W3/T-W6/T-W7 proceeding now; T-W1/T-W4/T-W5/T-W8 (new: auditor's
1:20 regression pin) HELD until W1b hashes relay. roundw-audit: standing by to re-verify
F1/F3 kill + warning silence on ordinary conditions once W1b lands. DEPLOY BLOCKED until:
W1b accepted + tests 0-fail + audit re-verify clean. Reality-gate bands E1–E6 unchanged.

LESSON (for operator triage): two of four audit findings trace to the LEAD'S brief design
(forward-Euler spec; 1.02 invariant premise) — the blind audit + independent test-author
sweep caught both before deploy. Process worked; brief-level numerics deserve the same
adversarial check as implementer code.

## W1b verification + reachability ruling (2026-08-05 ~09:45Z) — DEPLOY UNBLOCKED pending tests

Audit re-verify of W1b (d373375+c88fa5a): scope PASS; F2/F4 KILLED (silent on ordinary
conditions incl. 1:20 traces; fires on artificial runaway H/d=9.75); F3 KILLED (ratio
caps at exactly 1.0; raw drops tracked immediately); F1 MIXED — kernel divergence fixed
(converges to 0.400 and holds), residual one-point transient at the eps-floor crossing
(sub-publication-floor, self-correcting); pipeline path: auditor characterized a
PRE-EXISTING structural gap in apply_ddd_saturation (cessation→raw-pass-through→instant
re-onset ping-pong at d≈eps when raw ≥ γ·d there; old Euler code had the identical
behavior; H/d≈90 possible on adversarial flat-raw input, invisible to the invariant's
depth gate).

LEAD EMPIRICAL REACHABILITY CHECK (production-shaped, local): shallowest real transect
(43, wet depths 14.62→0.005 m, 251 pts) × 4 realistic partitions (1.2m/16s, 0.8m/12s,
0.5m/8s, 0.4m/6s) through the real run_1d_analytical + _combine_partition_hs at
c88fa5a: ZERO sawtooth points (no adjacent jump >2×); tail decays smoothly
0.39→0.31→0.23→0.15→0.11 m; terminal floored point publishes Hs=0.11 m (H/d ratio 11 is
meaningless by construction at the 0.01 m depth floor — height itself smooth/plausible).
Also: 94/162 transects have wet points < 0.15 m, so swash DEPTHS are in-domain — but the
ping-pong additionally needs raw ≥ γ·d exactly where marched reached Γ·d, which realistic
relaxed partitions do not produce (auditor's own caveat, now confirmed on the real path).

RULING: deploy UNBLOCKED once roundw-tests closes at 0 failures. The structural gap is
PARKED + goes to the OPERATOR DECISION QUEUE (below) because the candidate fix (gate
cessation on depths > _MIN_BREAK_DEPTH_M) modifies the operator-approved cessation
criterion (H ≤ Γ·d) — trigger-1 gray zone; not self-authorized (7/25 history).

### OPERATOR DECISION QUEUE (Round W, plain English)
DQ-W1. Swash-zone state machine (apply_ddd_saturation): in water shallower than 15 cm
  (our own minimum-depth floor for publishing breaks), the combined-profile treatment
  can in principle flip rapidly between "breaking" and "passing the raw value through",
  which on ADVERSARIAL inputs publishes garbage heights unflagged. Real inputs cannot
  currently produce it (verified on the real shallowest transect). Options:
  (a) leave as-is, documented + monitored (current state);
  (b) forbid "the wave has reformed" below the 15 cm floor — one-line guard; physically:
      waves do not reform in ankle-deep water; reform exists for troughs/deep spots.
      This edits the approved cessation criterion, so it needs your yes/no.
  Recommendation: (b) at the next natural marine round, not urgent.
DQ-W2. Kernel one-point transient at the depth floor: at the single grid step where
  depth crosses to the 1 cm floor, the marched height can spike for exactly one point
  then self-correct (sub-floor, sub-publication, invisible in the smooth real-transect
  tails). Options: accept+document (current), or task a discretization tweak (same
  equation, endpoint choice). Recommendation: accept+document; revisit only if the
  reality gate shows visible artifacts.
DQ-W3. Energy-conservation bound (W1b-3): while "breaking", the combined-profile value
  is now bounded by its own raw input (min(marched, raw)) so saturation can only remove
  energy, never add it (audit had shown it publishing 18% ABOVE the partitions' own
  physics). This is NOT the banned flatten-to-γd clamp — nothing is pinned to γd, both
  signals are preserved — but you banned clamps, so this bound is explicitly surfaced
  for your review rather than slipped in. Already shipped in W1b; say the word and it
  gets reworked if you disagree.

## Round W DEPLOYED (2026-08-05 08:44:26Z) — awaiting post-deploy cycle for reality gate

- Test round CLOSED: 9 commits e54b7ba..0dc6aa7 (7 new files T-W1..T-W8 + 2 T-W7 repairs,
  1140 lines). Author full suite 840 pass; LEAD-INDEPENDENT re-run at final tree: 841
  pass 0 fail (discrepancy explained: author's run raced their last test addition; my
  841 collected all 8 T-W4 tests). Fail-pre-change proofs supplied per group (incl.
  T-W7.1 pre-fix AssertionError paste; T-W7.2 fails at 36fab04 = pre-existing proof;
  T-W8 declared non-falsifiable-vs-Euler in docstring per verification.md).
- Steep-slope finding (test-author): literal 1:20 (12m/220-240m) exceeds H/d 1.0 and
  trips runaway warning at HEAD → dispositioned OUT-OF-CALIBRATION LIMITATION (HB real
  slopes ~1:40-60 verified clean; warning firing there = intentional signaling). Pinned
  by an honest interior positive test; W1c docstring applicability note (0525394).
- Audit round CLOSED (see prior entry). W1c accepted (docstring-only, 11 insertions).
- Pushed 36fab04..0525394 (14 commits); deploy-marine.sh OK; running commit 0525394,
  proc start 08:44:26Z; /health 200; canonical librewxr pytest of the 11 Round W/Z test
  files: 78 pass.
- Post-deploy: HRRR cycle 06Z fetched; full SWAN cycle started 08:45:35Z; background
  watcher armed for completion → then journal sweep (runaway warnings must be ABSENT
  at steady state per E5) + live payload vs bands E1-E6 + operator packet.
- Round S marine leg DISPATCHED (rounds-marine-dev) — marine repo free after test round;
  commits stay local, merge gated on operator worked-examples review.

## INCIDENT: Z5 hotstart guard fataled the first post-deploy cycle (2026-08-05 08:48Z)

- Journal: level1 warm-start attempted from hotfile stamped 20260808.000000 (END of the
  previous forecast horizon) for requested start 20260805.060000 → SWAN fatal
  "** Error: [time] before current time" → convergence gate → NOTHING published;
  runner retries the SAME poisoned file each interval → indefinite staleness
  (last-good cache serving). NOT a Round W physics issue — Round W never touched SWAN.
- Root cause: Z5's ordering rule (delete only when stamp PREDATES start) keeps
  future-stamped files, which SWAN cannot initialize from. Z5 converted chronic
  "never warm-starts" into "fatals at every cross-cycle boundary". (First-ever warm
  start on 05:26Z was same-cycle — stamp matched; cross-cycle is where it breaks.)
- Mitigation (lead, 09:0xZ): removed /run/weewx-clearskies/swan/{level1,level2,
  level3_0}_hotstart.dat (evidence-backed: journal proves the file fatals SWAN; files
  regenerate each cycle). Cold retry under way; watcher armed for first
  "hotstart saved" or failure.
- Fix Z5b dispatched to roundw-dev (authorized under the operator's earlier ruling
  that hotfile save/read correctness is the lead's): hotfile USABLE only when stamp
  EQUALS requested start; any mismatch (earlier OR later) → delete + cold start with
  direction-naming log. tests/services/test_hotstart_timestamp.py pins updated to
  equality-only with incident citation. Cross-cycle warm start remains PARKED (1a,
  operator design ruling still needed — Z5b is safe-not-clever).
- Round S dev rulings issued mid-incident: S-GAP-1 (jacking sweetener structurally
  ready but unwired this leg — surfaced by name in the operator packet; no
  surf_1d_pipeline.py touch, no logic duplication) + wire shape approved (five factors
  + weights{} + dataState{}). Dev proceeding.
