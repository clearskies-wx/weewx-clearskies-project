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
- PROCESS CORRECTION (2nd over-escalation tonight, both operator-flagged): reality-gate
  disposition + hotstart stamp comparison were both coordinator calls presented as
  operator decisions. Lesson candidate for round close (surface triage per lesson-capture
  rule): operational validity checks (cache/state reuse, gate dispositions where evidence
  is one-sided and no rollback would execute) are NOT trigger-1 physics criteria; also
  ban invented vocabulary ("model-run-semantics") — plain English rule applies to
  coordinator reports.

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
