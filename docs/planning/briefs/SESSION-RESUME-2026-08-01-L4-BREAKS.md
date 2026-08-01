# Session state — L4 rewrite coordination (2026-08-01)

## ═══ RESUME HERE (final update ~22:50 UTC 2026-08-01 — ROUND 1 CLOSED) ═══
**FINAL: the live run COMPLETED and PASSED before compaction.** Measured (testrun_round1.log,
code b60ef92): RUN_ALL_SPOTS_DONE clean; L4 accuracy 99.6% / valid_fraction 100.0% / 0 NaN;
**143 transects × 67/67 timesteps resolved on their own bands** (this cycle had 67 forecast
hours); 3,266 total band points (~23/transect avg — full-length crossing chords vary per
transect, no 150-cap hits, memory ~half the 170 MB estimate); 143× "no suspected break zone …
handoff selection unconstrained (byte-identical)" INFO lines — correct for today's small swell,
the case-(c) path verified LIVE; published forecast_cache.json 206 MB @ 22:42. Service
RESTARTED, active. Meta docs 07bee6b + resume-brief 4a6b1d6 pushed. **ROUND 1 IS CLOSED — all
gates: adversarial audit PASS, lead gate 141/141, docs committed+pushed, live check PASS.**
On resume: go straight to briefing Round 2 (below). Steps 1-4 of the old checklist are DONE.

**Superseded pre-compaction state (kept for context):** Round 1 live run was in flight on librewxr
(/tmp/testrun_round1.log, launched ~22:02 UTC, deployed commit b60ef92). At last check: all 4
levels converged (L4 accuracy 99.6%, valid_fraction=100.0%, nan=0), run was in the per-transect
parse/handoff/1D/publish phase — the exact phase Round 1 rewrote. Marine SERVICE IS STOPPED
(stopped deliberately for the run) — MUST be restarted after the run finishes:
`ssh -F .local/ssh/config librewxr "sudo systemctl start weewx-clearskies-marine"`.
A background bash task (held ssh) watches the run and completes when it exits.

**On resume, in order:**
1. Check run: `ssh -F .local/ssh/config librewxr "tail -20 /tmp/testrun_round1.log; pgrep -f testrun.py || echo DONE"`
   Measure (grep the log + forecast_cache.json like the earlier run): RUN_ALL_SPOTS_DONE;
   "resolved a per-hour position on its own 10 m band" count (expect 143 × "35/35" — the F1 fix
   protects exactly this); actual band station counts (expect ~45-55/transect); the new
   per-transect INFO lines (n_suspected_zones / outermost zone / chosen handoff); valid_fraction
   (expect 100%); publish (forecast_cache.json fresh); handoff_source_level + handoff_depth_m
   per transect (with small swell + no suspected zones expect ≈1.05 m L4 like prior run; if
   zones suspected, depths must be seaward/deeper).
2. Restart service; verify active + /health 200.
3. Push meta repo docs commit 07bee6b (docs Round-1 pass, QC'd/accepted) — operator granted
   STANDING push/deploy this session ("you, as coordinator, have permission to push/deploy as
   necessary"); if resuming a NEW session, re-confirm before pushing.
4. Post-deploy journal sweep on next service cycle: confirm the killed "0/35 resolved a
   per-hour L4 station" line and its clamp WARNING spam are GONE (kill commit 1c98507).
5. Close Round 1 (all gates already passed — audit PASS, lead gate 141/141, docs committed).
   Then brief Round 2.

**Round 2 (next dispatch, fully ruled, nothing open):** BD-7 main-break-zone headline
(upper-tail > mean+0.75σ, fallback min(mean+0.75σ, 5th-highest face); zone window ≥5 consecutive
transects) + BD-9 representative-transect cross-section (in-zone transect closest to
band-filtered zone mean, tiebreak nearest zone center) + BD-8 retirement (is_structure_affected
→ metadata only, open_transect_count semantics update) + §7a Round-2 doc list (API-MANUAL
headline contract, DASHBOARD-MANUAL, ARCHITECTURE/PROVIDER-MANUAL, SURF-ZONE-MODEL-BRIEF
addendum, plan log). Spec: docs/planning/briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md.
Process: Sonnet implementer (agent "l4-rewrite" — resumable by name, has full repo context) →
adversarial auditor (agent "round1-auditor") BEFORE lead gate → docs agent ("doc-sync") →
push/deploy → live check. Operator directive: ALWAYS Sonnet coding agent + adversarial QC agent.

**Deferred/parked items (do not lose):**
- _transect_band_depths() dead in production, deletion blocked by tests/test_swan_l4_intersection.py
  imports — needs explicit sign-off round.
- tmpfs peak: _check_convergence reads all TABLE_PT before the unlink loop — parse-and-delete
  shortens tail not peak (~170 MB full-length peak). Known limitation, recorded in docs.
- test_serve_nothing_on_failure.py: 2 pre-existing failures (stale fixture missing
  open_water_bearing_deg, from 51543b1) — parking lot.
- _STRUCTURE_STUDY_MARGIN_K derivation comment stale vs new lateral formula (grid_sizing_chain
  ~198); assert_grid_encloses fails loudly if margin insufficient — watch at future regens.
- Break-zone merge threshold: deferred; tune only if HB double-break gate shows fragmenting.
- HB two-break reality gate: NOT yet confirmable — awaits real double-break conditions matching
  operator's observation (outer break ~mid-pier). First matching day: check cross-section +
  heatmap show both breaks.

**Repo state at compaction:** marine main = b60ef92 (pushed+deployed). Meta main = 5b528db
pushed + 07bee6b LOCAL. Untracked test_claim2.py in marine repo: ignore, never commit/delete.
═══════════════════════════════════════════════════════════════════

## Role
Coordinator (Fable). Task from operator: reconstruct fired Opus session (transcript
fe48ca39-82df-43db-86aa-8c64b82f85f6.jsonl, ends with "your fired"), then drive a Sonnet agent to
finish the L4 grid-siting code so we can do a full model test run. NO push/deploy without the
operator's explicit word.

## Reconstruction (DONE — reported to operator)
- R2 deployed+verified (south boundary 38/38 wet, 215° open-water boundary, nest swell 0.64m max).
- R7 deployed (marine 2087fc1): prune/L2-routing/gate-rescope/Hs-floor; publish restored.
- Meta repo pushed through ffb6e28.
- marine.conf on librewxr: segment edited to pier→Huntington State Beach (~1.4km); backup
  marine.conf.bak-preseg-1785521385; NOT regenerated yet. Wizard is broken (wrote bad segment).
- Rejected partial edit in swan_domain.py: diff preserved at scratchpad
  rejected-partial-edit-swan_domain.diff; file restored to HEAD 2087fc1.
- Outstanding: R3 residual — L4 grid landward (median −0.17m, 54% dry, 333/352 handoff pts
  outside, valid_fraction 5.2%).

## Settled design (operator rulings in fired session; locked in brief)
L4 box = beach-frame bounding rect of {structure footprint ∪ handoff points of surf-area
transects the structure shadows}. Shadows cast down-wave of every non-truly_blocked geography
ray (72-ray fan). Shoreward edge = min shadowed handoff u (l3_shoreward_edge_depth_m contour per
transect's own profile). Seaward edge = max footprint u + 1-wavelength margin (existing tip-depth
logic at seaward-most footprint pt). v-span = footprint∪handoffs ± 1 cell. rotation_deg =
avg_bearing. Sized once at config push, frozen. Reverses AD-4 (OMBB) — operator approved in chat.

## Agent dispatch (IN FLIGHT)
- Agent name: l4-rewrite (clearskies-api-dev, sonnet). Brief: scratchpad/L4-rewrite-brief.md.
- Scope ack CONFIRMED. Baseline: tests/test_structure_grid_extent.py 12 passed @ 2087fc1.
- Viability-check refinement sent: check (i) footprint pts with u>=u_min inside rect (real
  guard); (ii) shadowed handoff pts inside (backstop); log count of expected-clipped landward
  footprint pts.
- Allowlist: swan_domain.py, grid_sizing_chain.py, tests/test_structure_grid_extent.py ONLY.
- Deliverables: local commits (no push), pytest counts, HB real-input numbers block (box corners,
  spans, ni×nj vs 46×125=5750, n shadowed of ~143 transects, corner depths from L4 bathy cache).

## Acceptance gate TODO (when agent reports)
1. Independently re-run pytest tests/test_structure_grid_extent.py -q, paste raw output.
2. git show <commits> --stat vs allowlist.
3. Spot-check shadow-test geometry + u_min/u_max construction by opening swan_domain.py.
4. Re-run the HB verification script myself; check box wet (corner depths), footprint containment,
   shadowed count > 0.
5. Then report numbers to operator; WAIT for "push" before push/deploy.

## TEST RUN RESULTS (2026-08-01 19:06:57Z run, commit 4e79d21, MEASURED)
- RUN_ALL_SPOTS_DONE clean. PUBLISHED: forecast_cache.json 106 MB @ 19:23, real spectral DWR
  (0.51m @ 13.3s @ 197.5° groundswell + 2 wind-swell components), 35 hourly transect timesteps.
- Convergence: L1 acc 100%, L2 99.7%, L3 99.7%, **L4 acc 99.6% valid_fraction=100.0%** (was 5.2%).
- Nest swell L1→L2: max 0.52m @ 13.2s @ 198°, median 0.42m, 227/306 locs >0.3m (healthy; prior
  cycle 0.64/0.54).
- Regen guard event: initial L3 viability fired ("unreachable ~254m"), superseded by role-A
  coarse nest (enabled). Service restarted post-run, active, health 200.
- **RESIDUAL FINDING (surfaced to operator, NOT fixed): L4 per-hour station selection 0/35
  timesteps resolved** (log: "0/35 timestep(s) resolved a per-hour L4 station (T4A.9/T4B.3)").
  Mechanism per WARNINGs: (a) small swell Hs=0.59m → hourly target depth 1.3×Hs/0.73 = 1.05m,
  shallower than grid design floor 1.78m (=Hs 1.0 design min) → target outside grid; (b) the
  spot-level band is PIN-anchored and its ray runs through the pier scour trench: profile spans
  3.40–15.845m — shallowest band station 3.40m ⇒ L4 station resolves only when Hs ≳ 1.9m.
  (b) contradicts the pin-zero-bearing ruling. 1D fell back to L2/DWR path (R7 design) — output
  path same as pre-fix. Both are operator decisions (handoff criteria / band anchoring —
  architectural triggers). Setup WARNINGs logged: "profile never reaches 1.00m — SUBSTITUTION"
  + "deep end clipped to grid bbox" at pin line.

## CORRECTION to test-run finding + operator-ordered kill (2026-08-01, after run)
- The "0/35 resolved" line = the LEGACY SPOT-LEVEL pin-anchored diagnostic CURVE pick
  (_select_l3_handoff_spectra, swan_runner.py:2073 + call block 6220-6263) — NOT the main
  handoff. The per-transect T4B.3 path (the design) resolved **143/143 transects × 35/35
  timesteps**; published `spectral` = [{time, handoff_by_transect}] built FROM per-transect
  entries. Run = clean PASS on all axes. Operator: "that line has been the bane of my existence
  the past 5 days" → ruled: kill it.
- Phase-1 consumption trace (agent, verified vs code): CURVE geometry + TABLE_n (feeds published
  `forecast`) + SPEC_n specout (feeds surviving per-transect selector's time axis/spectrum) ALL
  STAY — only the spot-level pick + call block die. Today: byte-identical. Big-swell gap-transect
  scalar fallback degrades measured→formula (accepted; aligns with pin-zero-bearing).
- Phase 2 in flight: delete function + block + now-unreachable merge branch (6341-57) + orphaned
  helpers; rewrite decouple test 1, delete decouple test 2 + curve-selector Defect-2 test, WRITE
  replacement end-to-end Defect-2 test through _select_l3_handoff_position_and_spectrum; report
  stale doc references for the pending meta docs commit. Local commit, no push.
- PENDING after QC: operator word to push+deploy the kill commit; fold test-run results + kill
  into docs (d4a71ca still local); next deploy's journal must show 0/35 line + clamp spam GONE.

## SURF-ZONE BREAK-DETECTION SPEC (APPROVED) + ROUND 1 IN FLIGHT (2026-08-01 evening)
- Spec: docs/planning/briefs/SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01.md — APPROVED, all pushed
  through 5b528db. Rulings: BD-7 band = UPPER TAIL > mean+0.75σ (fallback: lower threshold until
  ≥5 qualify = min(mean+0.75σ, 5th-highest face)); zone window ≥5 transects; BD-8 RESCINDED
  (flag = metadata only); merge threshold deferred; BD-9 representative transect (closest to
  band-filtered zone mean, tiebreak nearest zone center); §6.5 full-length bands (measured 42MB
  → ~170MB/cycle, parse-and-delete mandatory); §7a REQUIRED per-round doc-sync task.
- Verified EXISTS already: _find_break_points (multi-break), _classify_zones (impact/foam/
  REFORM zone for double breaks) in surf_1d_analytical.py — starved by handoff domain only.
- Round 1 (BD-1/BD-2/BD-4 + bands) DISPATCHED to l4-rewrite (Sonnet); brief at scratchpad/
  round1-break-domain-brief.md. Scope-ack CONFIRMED with: cap 150 (clamp; production ~45-55
  stations — agent's 1057m figure was its wrong-frame harness, corrected); trace emissions stay
  break_points[0] + clarifying comment; sentinel-target + existing grid_bbox clip for band
  extent; _transect_band_depths() deleted if no other callers; TABLE_PT-only delete;
  find_outermost_break_index + max_seaward_break_index (None = byte-identical); None-Hs skip.
- OPERATOR DIRECTIVE: adversarial QC — on Round 1 closeout, dispatch clearskies-auditor (Sonnet)
  against commit+brief+spec BEFORE lead gate (hunt spec deviations, weakened invariants,
  skipped memory rule, can't-fail test assertions). Same for Round 2.
- Round 1 closeout: commit 03b33e1 (6 files, +812/−67, 98→107 tests). ADVERSARIAL AUDIT
  (round1-auditor, sonnet): **FAIL**. F1 BLOCKER (reproduced): select_hourly_handoff publishes
  handoff_depth_m=target_depth_m even when BD-2 constraint displaces selection →
  _truncate_bathy_at_handoff truncates at the shallow formula value → returns None → transect
  SILENTLY DROPPED (fixture: published 1.4247 < all station depths; correct = station depth
  3.8501). Fix principle = existing T2.2 PART B (truncation depth follows the selected sample).
  The new guard-test assertion pinned the defective value. F2 MAJOR: beach_profile.py:610 pairs
  break_points[0] geometry with post-BD-4 primary face height (mismatched break identity).
  Audit CONFIRMED: selection math, byte-identical default, band mechanism, unlink, BD-4 internal
  consistency, allowlist, test falsifiability. NOTE: peak tmpfs at _check_convergence (reads all
  TABLE_PT pre-unlink) — fix shortens tail not peak; known limitation.
- REMEDIATION dispatched to l4-rewrite (new commit on 03b33e1): F1 fix (constraint-bound →
  handoff_depth_m = selected station depth, both branches; guard-test back to 3.8501 via new
  mechanism; new known-answer test through _truncate_bathy_at_handoff), F2 fix (allowlist
  extended: endpoints/beach_profile.py primary-pairing only). Re-audit F1/F2 by round1-auditor
  before lead gate. Round stays OPEN (false-claim protocol).
- REMEDIATION DONE: ea62e85 (F1: constraint-bound → handoff_depth_m = station depth, both
  branches, verified vs auditor's prove_finding.py; F2: beach_profile primary pairing both
  sites) + b60ef92 (companion: non-primary loop enumerates skipping primary_break_index).
  RE-AUDIT: **PASS** (6 adversarial F1 edge cases incl. forced tie; companion test proven
  non-vacuous by pre-fix simulation). LEAD GATE: PASS (141/141 own shell, chain/stat clean,
  F1 code spot-checked at transect_handoff.py:848-858/982-990).
- Round 1 PUSHED (1c98507..b60ef92) + DEPLOYED (b60ef92, proc 22:00:55Z). Service stopped;
  LIVE RUN launched (/tmp/testrun_round1.log, watcher = held ssh task). Expected: 143/143×35/35
  maintained, ~45-55 stations/band (INFO lines), valid_fraction 100%, publish, n_suspected_zones
  INFO present. Restart service after run + measure.
- Round-1 doc-sync pass dispatched to doc-sync agent (§7a: ADR-093 amendment, PROVIDER-MANUAL,
  ARCHITECTURE ~117, API-MANUAL primary_break_index/breakPoints, plan decision log w/ audit
  narrative + deferred items). Scope-ack pending.
- Round 2 (BD-7 + BD-9 + BD-8 retirement + doc sync) — ready to brief after Round 1 closes.
- Operator standing grant this session: push/deploy as necessary (given ~20:45Z).
- Marine deployed: 1c98507 (20:49:47Z). Meta pushed through 5b528db.

## Docs pass (DONE, QC'd)
Meta commit d4a71ca local (NOT pushed): 10 files — ARCHITECTURE, PROVIDER-MANUAL (friction 0.038/
maxerr 2 verified from code), API-MANUAL phrase, ADR-093 Amendment 6, ADR-100 consumers note,
AD-4/G4.2 SUPERSEDED markers, plan R3 + decision log (4 rulings), OBSTACLE-BEST-PRACTICES +
GRID-STRATEGY addenda, swan-commands-extract alpc note. No run results claimed (verified).
Doc agent found+fixed 2 extra stale claims (directional_exposure param; Amendment 3 line).

## Lead calls flagged to operator (veto-able)
1. wrap_candidate rays count as open. 2. Geometric shadow, no diffraction-spread margin.
3. Footprint landward of shoreward edge clipped (logged). 4. Zero shadowed transects → L4 None.

## Operator rulings (2026-08-01, this session — carry to plan decision log at doc pass)
- Transect spacing: KEEP 10m (~143 transects); evaluate performance impact in the test run.
- Pin: do NOT move. Pin is a site designator only and must have ZERO bearing on any actual
  measurement; operator may move it further south later (site is "Huntington Beach - South of
  Pier"). Agent tasked to confirm pin-invariance of the new geometry in closeout.
- Residual pin influence (1) geography ray-fan origin = study-area centroid: operator ruled
  ACCEPTABLE ("general enough measurement"). No action.
- Residual pin influence (2) primary-structure selection: operator ruled it a DEFECT — a beach
  may have no primary structure (two equal breakwaters; The Wedge jetty+breakwaters). RULING
  (2026-08-01, in chat, architectural delta approved): L4 sized against ALL operator-identified
  eligible structures; primary-group narrowing (G4.2) removed from compute_structure_grid_domain.
  Amendment sent to agent: per-STRUCTURE shadow bands (never union — gap between breakwaters must
  not be falsely shadowed), box bounds all footprints ∪ all shadowed handoffs, new known-answer
  test case (e) two-breakwaters-with-gap, viability over all structures' seaward footprint pts.
  Operator criticism logged: HB-pier-centric thinking was a repeated failure mode of the fired
  session — the design must be structure-count- and structure-shape-agnostic. Doc pass must
  reflect the no-primary-structure ruling (G4.2 deferral language dies).
- CLARIFICATION (operator, same day): shadow selection decides grid INCLUSION only, not physics.
  Over-inclusion (e.g. gap between breakwaters marked shadowed) is BENIGN — the grid models the
  energy transference; cost is cells, never correctness. Per-structure bands kept, but test (e)'s
  required assertions = box spans both structures + both lees + the gap region; gap-center-
  unshadowed demoted to optional behavioral note. Design principle for doc pass: when in doubt,
  include in the grid — SWAN inside the box is the authority on the physics.

## Doc-sync inventory (operator ordered: update briefs/ADRs/manuals on grid sizing after code)
Governing docs to update (historical session logs/concerns files are records — do NOT rewrite):
- docs/ARCHITECTURE.md (SWAN nearshore model / L4 section)
- docs/manuals/PROVIDER-MANUAL.md (§14.x structure grid), docs/manuals/API-MANUAL.md (check 4 hits)
- docs/decisions/ADR-093-swan-trushore-nearshore-model.md (E2/L4 sizing — needs amendment)
- docs/decisions/ADR-100-geography-aware-study-area-geometry.md (rays gain L4-sizing consumer)
- AD-4 definition (find where it lives — likely MARINE-GEOMETRY-MODEL-PLAN.md, 37 hits) — mark
  REVERSED with pointer to new design; do not rewrite history sections.
- docs/planning/MARINE-MODEL-RESTORATION-PLAN.md (R3 progress + decision log)
- briefs: SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md, SWAN-NESTING-RESEARCH-BRIEF.md,
  SWAN-GRID-STRATEGY-RESEARCH-FINDINGS.md, L3-1D-BOUNDARY-DECISIONS-BRIEF (verify name),
  docs/reference/swan-commands-extract.md (alpc/CGRID note)
Grep at doc-pass time; don't trust this list alone.

## Sourced physics findings worth carrying into docs (from fired session research)
- SWAN diffraction meaningful only 1–2λ from obstacle tip (SWAN tech doc, obstacles node25).
- Classical practice terminates diffraction shadow ~20λ (CEM/ICCE diffraction diagrams).
- Duck FRF pier observations: shadow strong ~200m downwave, healed ~400m (Elgar et al. 2001).
- Depth-limited breaking (γ≈0.79) + friction dissipate shadow through shallows.
