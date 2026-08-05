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
