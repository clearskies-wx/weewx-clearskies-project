# Phase E session log — 2026-07-27 (coordinator scratch, survives session limits)

═══════════════════════════════════════════════════════════════════════════════
## ▶▶ RESUME / CURRENT STATE (compaction-safe snapshot, 2026-07-27 session 2) ◀◀
═══════════════════════════════════════════════════════════════════════════════

**Who/what:** Coordinator driving the Marine Model Restoration Plan Phase E. Read, in order:
MARINE-MODEL-RESTORATION-PLAN.md "START HERE", findings §0A/§0B, rules/{agents,verification,
coordinator}.md, THEN this whole session log (rulings are below this block). Operator gave STANDING
push+deploy permission and "keep going, only stop if you need me."

**Deploy posture:** NOTHING is deployed. Marine service on librewxr is STOPPED+DISABLED (E0,
deliberate). Deployed marine commit = `de71775`. There is ONE Phase-E deploy, at the END, in E0's
mandatory order: code → config re-push (resizes grid) → confirm last_run advances 2 cycles → re-run
HB wizard discovery+Apply so real pier coords land in marine.conf. Do NOT run deploy-marine.sh before
E2b+E5+E8+E9+E10 are done (it re-enables the service onto the still-cached 41,895-cell grid = thrash).

**◀◀◀ LATEST STATE — session 3, 2026-07-28, PRE-COMPACTION #3. THIS supersedes everything below. ▶▶▶**

**PHASE E IMPLEMENTATION IS 100% COMPLETE + PUSHED.** Every E-task (E1–E13) + the E8 redesign + the
projection fix are landed, coordinator-acceptance-gated, adversarially audited where warranted, and on origin.

**SESSION-3 COMMIT LEDGER (all `main`, all PUSHED, each gated by me):**
- E5 `2bad206` + guard `d68465a` (three-way handoff L4→L3→L2; doc-sync D4). E10 `054df69` + doc `fa02203`
  (per-transect profiles rebased to transect line, FINE→MEDIUM source fallback; supersedes C4).
- **E8 REDESIGNED** (was a SWAN-only-era REMNANT: emitted grid points, never ran the 1D chain, never wired to the
  loop). New design (operator-approved): full runs every 6h on extended HRRR cycles (00/06/12/18Z); hourly **full-nest
  STATIONARY fill** L1→L4 (reuses last full run's WW3 boundary read from persisted level1/INPUT + runs the SwellTrack
  1D chain) wired into service.py loop. Commits `618378c`+`bbcec8f`+`c3fa5b6`, audit-fix F2 `1b7699b`, guards `0979b99`
  (docs `d9abcdd`/`66f9516`). Adversarially audited (0 blockers).
- **E8 audit F1** (stale hotstart/WW3 on grid resize) → operator Option A: config-push **cold-start** clears swan_work
  run state `c3ceaa8`, PLUS geometry-changing push **signals an immediate full run** `12907ca` (docs `1c00f41`/`a6f0f4c`).
- **PROJECTION FIX** (audit F1 "UTM-zone straddle"; operator Option A): ONE locked UTM zone per DEPLOYMENT (L1/L2 are
  global) from the deployment centroid, threaded to all 31 projection sites, 5 per-grid `utm_zone()` recomputes deleted,
  `lonlat_to_utm`/`utm_to_lonlat` now require an explicit zone, setup width guard **WARN>1°/refuse>2°**, runtime tripwire.
  `f6033ed`+`dba0fd4`+`55c3964`+`1584136` (doc `19f862e`). **Adversarial audit CLEAN (0 blockers).** Antimeridian F2
  (circular-mean centroid + minimal-arc span — operator: product expands beyond US) `71939fd`+`b136f15` (doc `a249c86`).
- Plan doc-sync (flipped stale ⬜ markers → ✅ with hashes; E2b heading added; projection-fix + deploy-req sections) `241f5b8`.

**REMAINING — 3 items:**
1. 🔄 **Governing-doc drift fix — agent `phaseE-driftfix` (a47f573cac1540e9c) RUNNING.** E2/E2b/E3/E4/E7/E9 never
   doc-synced ARCHITECTURE.md/manuals/ADR-093 (E5/E8/E10/projection each did). 6 stale spots: ARCH ~98/116 (L3-as-10m-
   structure-grid — now L4), ARCH ~102 + API-MANUAL ~2480 (DIFFRACTION "L3 only" — now L4/structure per E7), PROVIDER-MANUAL
   §14.15 (3-level L1→L3 — now 4-level w/ L4), ADR-093 Amd2 ~231 ("L3 offshore edge stays 15m — closed" — REVERSED by
   operator D2/D6, needs NEW append-only amendment). Docs-only; verify against CODE not plan prose. Accept when it closes:
   read diffs, confirm matches code+rulings, spot-check the ADR amendment matches D2/D6. **Does NOT block the deploy.**
2. ⬜ **DEPLOY — OPERATOR-GATED (surfaced; awaiting go on TIMING + the marine deploy PROCEDURE — I asked, no answer yet).**
   Marine service on librewxr is STOPPED+DISABLED (E0); deployed commit still `de71775`. The E2b/E5/E8/E9/E10 gate that
   blocked deploy is now SATISFIED. E0 deploy order: deploy code → **MANDATORY config re-push** (regenerates
   swan_grid_sizing.json with `locked_utm_zone` + geometry signature — else `run_3level` RAISES RuntimeError on the old
   cache; fail-clean, confirmed by projection audit F1; one-time migration; the re-push ALSO auto-triggers a full run via
   the immediate-full-run change) → re-enable/start marine runner → confirm last_run advances → re-run HB wizard
   discovery+Apply so real pier coords land in marine.conf. Confirm the actual deploy script/steps against reality before running.
3. ⬜ **Gate E** — 27-row live validation + adversarial, on the deployed system. Owed-at-Gate-E items scattered in plan:
   E6 row 11 (oblique-swell calibration), E11 item 2 (shadow classification w/ live config), E12 (deployed config has NO
   `swan_timeout_s` key → runs 900s code default, not documented 3600s; cycle-bound decision pending).

**KEY SESSION-3 DECISIONS (detail lower + in the plan's 2026-07-28 decision log):** E8-is-a-remnant finding → full-nest
stationary fill rebuild; F1 cold-start + immediate-full-run; projection Option A (one frame/deployment) + antimeridian-aware;
F2-antimeridian ruled NOT out-of-scope (global expansion); config-push cold-start is the fix for stale-state-on-resize
(NOT a fill-side guard). Legacy 2-level SWAN path (`run()`/`run_with_tmpdir`/`_run_outer_grid`) confirmed DEAD (no live/test
caller) — projection fix makes it fail-loud, safe.

**QC METHOD (unchanged — keep doing):** every agent report is a CLAIM — re-run pytest myself (currently **348 passed, 2
skipped**), `git show <hash> --stat` vs allowlist, read the key diff, reproduce the core property when safety-critical
(this session I: hand-checked the antimeridian span math, re-ran the F2 honest-skip guard against a pre-change worktree,
traced the legacy-2level path dead, re-ran the E5 known-answer guard in a worktree). Highest-risk → ADVERSARIAL AUDIT
(clearskies-auditor, never saw impl) — did this for E8 and the projection fix, both clean. **PUSH BUG:** a second `git push`
in a compound command runs in the FIRST repo's cwd — always `cd` to the meta repo and push it as its own command.

═══════════════════════════════════════════════════════════════════════════════
**▼▼▼ EVERYTHING BELOW IS SUPERSEDED SESSION-2 DETAIL (kept for history) ▼▼▼**

**◀◀ LATEST STATE — updated 2026-07-27 session 2, pre-compaction #2. This supersedes the older detail below. ▶▶**

**COMMIT LEDGER — all on `main`, all PUSHED to origin, each coordinator-acceptance-gated:**
- Session-1 (pushed earlier): E13 (marine `8d87ad2`/`1307386`/guard `634c430`; api `5ca6a93`; meta `3444fa1`;
  stack `19d9332`), E2 `7ea961b`+guard `97e08d1`, E3 `49df65c`, E7 `d517084`, E4 `6b48abd`, E6 `dba85ea`,
  E1/E11/E12 (see task table lower in file).
- Session-2 NEW (all pushed): E3+E7 guards `af7bcda`; E9 impl `416e1fc` + guard `255d192`; l_tip Option-C
  finalize `0b1cb34`; E2b part1 `9ceab5d`; **E3-AMENDMENT `53abe07`** (decoupled child NGRID rotation — fixed
  E3's incomplete rotated nesting); **E2b part2 `c3f22f7`** (L4 runs nested under L3-middle); E2b/E3 guards `e14baa2`.

**PHASE E TASK STATUS:**
- ✅ DONE+PUSHED: E1(dead/superseded), E2, E3, **E3-amendment**, E4, E6, E7, E9(+guard), E11, E12, E13,
  **E2b parts 1+2 (ADVERSARIAL AUDIT CLEAN — 0 blocker/major)**, all guards (E3/E7, E9, E2b/E3-decoupled).
- 🔄 **E5 — IN FLIGHT**: agent `e5-handoff` (clearskies-api-dev) IMPLEMENTING now (I sent GO). Three-way
  handoff L4→L3→L2. TURNED OUT SMALL: the L4 band already reaches the select call (E2b skips _parse_output on
  L3-outer, so L4 is the sole band), it was just MISLABELED "L3" → a 4-edit labeling fix + refine_handoff_with_qb
  →("L3","L4") + rule-2 pure logic + doc-sync(D4). ALLOWLIST CORRECTED (plan was wrong): transect_handoff.py +
  swan_runner.py (call sites :808/:1943, _parse_output, the two _select_l3_handoff_* helpers) + surf_pipeline_timestep.py
  (no change needed) + docs(ARCHITECTURE.md, API-MANUAL.md) + surf_1d_pipeline.py(doc-only). RULE-2 (L3-refraction for
  L4-uncovered transects) is NOT WIRED (L3 runs outer-only when it nests L4 → uncovered transects fall to L2 via E2b
  fallback) — TRACKED KNOWN GAP, needs grid-role dispatch (E4/E7 territory), untested-by-design. Accept E5 when it
  closes out (my own suite run + byte-identical-non-L4 + doc-sync in same commit).
- ⬜ E5 guard (test-author) — after E5 lands. ⬜ E8 (hourly quick-update runs every handoff grid; swan_runner.py
  run_stationary_level3) — sequence AFTER E5 (shared file). ⬜ E10 (per-transect profiles span own handoff→shore;
  reworks C4 `060a56b`; files grid_sizing_chain.py, enrichment/bathymetry.py, swan.py, endpoints/beach_profile.py) — after E5.
- ⬜ **Phase-E consolidated doc-sync** (ARCHITECTURE.md SWAN section line ~98 + manuals + ADR-093 cross-refs still
  describe the PHASE-14 grid: "L3=10m surf zone, runs to 15m, handoff 1.3·Hs/0.73") — reconcile ONCE after E10, BEFORE Gate E.
- ⬜ Single Phase-E deploy (E0 order: code → config re-push resizes grid → confirm last_run advances 2 cycles →
  re-run HB wizard) → Gate E (27 rows live + adversarial) → Phase F → Phase D.

**⚠ NEW OPERATOR-DECIDED TASK — COORDINATE FRAME (Option A, decided 2026-07-27):** Operator chose **A: keep Cartesian,
fix the projection to ONE frame per site** (NOT spherical — SWAN forbids rotated grids in spherical, would kill the L4
structure grid). Root cause (audit F1): our code picks a UTM zone PER-GRID from each grid's centroid (swan_formats.py:1364,
swan_runner.py:1037/4276/4488, + default inside lonlat_to_utm:101) → parent/child near a 6° zone seam desync → silent
energy-zero. FIX: choose the zone/frame ONCE per run from a canonical site point and thread it to ALL projection calls
(replace the per-grid utm_zone() recomputes; ~33 lonlat_to_utm/utm_to_lonlat call sites across swan_formats.py[10]/
swan_runner.py[22]/swan.py[1]); add a loud guard that refuses to run if any grid resolves to a different frame. Primitives:
swan_formats.py:90 utm_zone, :95 lonlat_to_utm(zone optional), :135 utm_to_lonlat. ARCHITECTURAL — operator approved A.
NON-HB-blocking, not triggered at HB. **SEQUENCE AFTER E5/E8/E10** (collides on swan_runner.py/swan_formats.py). Design-ack
required (cross-cutting). This ALSO kills the ~2m flat-earth-vs-UTM residual finding. Dedicated task, own allowlist.

**KEY RULINGS/FINDINGS THIS SESSION (detail in sections lower in file):** (1) l_tip_m persistence = Option C (validated at
setup by _l3_viability_check, per-cycle re-check omitted — no new field). (2) E9 allowlist was wrong (assertions live at
swan.py/surf_1d_pipeline.py call sites, not invariants.py) — corrected. (3) E3 was INCOMPLETE for rotated nesting (own-CGRID
& child-NGRID coupled to one rotation_deg + NGRID geom from axis-aligned bbox) → E3-amendment `53abe07` added inner_rotation_deg,
NGRID reproduces child CGRID by construction (contract: inner_dims==child dims). (4) E2b design choices confirmed: mis-oriented
L4 degrades that cluster to no-L4; orphaned-spot fallback also covers L3-middle convergence failure. (5) Coordinate frame = Option A.
TRACKED tidy-ups: getattr(domains,"level4_clusters",[]) swan_runner.py:3455 (fix stale test fixture later); F4 idx-align (pinned by guard).

**QC METHOD (keep doing):** every agent report is a CLAIM — re-run its check myself, `git show <commit> --stat` vs allowlist,
read the key diff section, reproduce the core property myself when safety-critical (e.g. I ran /c/tmp/e3_verify.py for the
E3-amendment; reproduced the decoupled-nesting emission). Highest-risk changes get an ADVERSARIAL AUDIT (clearskies-auditor,
never saw the impl) + guard tests before building on them (did this for E2b part2). Agents: mandatory git-restriction +
arch-change blocks; DESIGN-ack before code on anything non-trivial; hold code-writes to avoid 2 agents on the shared checkout.

**ACTIVE AGENTS AT COMPACTION:** `e5-handoff` (a...ac471ee46f83ad505 / name "e5-handoff") — IMPLEMENTING E5, will report
closeout. Reattach via SendMessage to name "e5-handoff". No other agent running.

═══════════════════════════════════════════════════════════════════════════════


**Resume context for a fresh session:** read MARINE-MODEL-RESTORATION-PLAN.md "START HERE",
findings §0A/§0B, rules/{agents,verification,coordinator}.md. Marine repo baseline at session
start: `060a56b` (C4, committed NOT deployed; librewxr runs `de71775`), tree clean, main up to
date with origin. Marine service on librewxr is DELIBERATELY stopped+disabled (E0) — expected.
Restart order on deploy: code → config re-push (resize) → confirm last_run advances 2 cycles.

## Standing operator authorizations this session (2026-07-27, in chat)
- Standing permission to **push and deploy** as necessary for testing. Do not re-ask.
- Do not stop mid-plan; surface blocks, keep working unblocked items.
- Only bring issues NOT already decided by briefs/ADRs/manuals.

## Task states (this session)
| Task | State | Notes |
|---|---|---|
| E1 impl | LANDED `19b0d4b` + remediation in flight | swan_domain.py only; coordinator independently re-ran verification (matches); allowlist diff clean (1 file, +138) |
| E1 guard | LANDED `f03d688` + extension in flight | 15 tests pass; coordinator demonstrated fail-against-pre-change (checkout 060a56b → collection error) and pass-after (15 passed); reference is brentq + _G constant only |
| E1 adversarial | DONE — COULD-NOT-DISPROVE | 2 findings: (M) no monotonicity guard in tip_depth_from_fine_profile → remediation dispatched (non-ascending → None); (L) D7 dx-vs-source-resolution check has no code home → DEFERRED TO E2's sizing wiring, include in E2 brief |
| E6 impl | LANDED `dba85ea`, ACCEPTED code-level | pier TRANSM 0.95→0.82 w/ Elgar 2001 citation; other rows untouched; live OBSTACLE check = Gate E row 11 |
| E12 impl | LANDED `eba9622`, ACCEPTED | coordinator re-ran: 2h→degraded `cycle_overrun: running 7200s > 3600s`, 5min→ok. health.py only; `_compute_status` gained internal `run_in_progress` kwarg (authorized). |
| E12 guard | LANDED `85ce1a2` + `f2f4c31`, ACCEPTED | 6 new tests; guard proven failing vs 49839ac. Date-drift fixture fix landed (clock-relative `_iso_ago` helper); coordinator re-ran: 16 passed / 0 failed. |
| E12 Finding 2 (timeout) | REPORTED TO OPERATOR | Timeout is PER SWAN INVOCATION (`_spawn_swan` swan_runner.py:4065-4074, `swan_timeout_s` default 900 at :2214); a cycle = (2+N_clusters)×timeout worst case; NOTHING bounds the cycle. Coordinator confirmed NO swan_timeout key anywhere in /etc/weewx-clearskies on librewxr → production runs the 900 s default — yet E0 observed a swan process resident far beyond it, so the per-invocation timeout appears ineffective in production. No change made (config key = trigger 7). Operator decision owed: cycle-level bound + reconcile 900 vs "documented 3600". |
| E11 impl | LANDED `3e40238`, ACCEPTED | swan_runner.py only (+64/-14). Call sites now :2904/:3885. Lead-ruled seam: spot configs at those sites are dicts WITHOUT structures; threading uses the spot_id-tagged domain OBSTACLE list (built from C2's StructureConfig objects — same geometry) filtered per spot, converted locally to StructureConfig. Cosmetic: reconstructed length_m=0.0 → "pier(0m)" labels (label-only; geometry uses .coordinates). Coordinator re-ran AST verification: both sites pass structures= and trace_context(spot_id=...). |
| E11 item 2 | OPEN — resolve at Gate E | Probe: TRUE OSM pier line → 0/32 shadowed (matches live trace); DEPLOYED displaced line → 6/32. Neither authoritative: probe used 201.9 as beach_facing (real config uses segment-perpendicular ~237°) and live-at-trace-time config unconfirmed. Re-run probe with actual live values at Gate E row 19. Probe script: scratchpad/e11_item2_probe.py (session temp — recreate from this description if lost). |
| E11 item 3 | CONFIRMED | Invariant 3 (transect_handoff.py:526-532) was trivially passing at both broken call sites: empty structures list → `not structures` True → never fires. After threading it becomes live. |
| E11 guard | LANDED `af02d19`, ACCEPTED | 2 tests, both call sites, wrap-don't-fake capture of real classifier; guard proven FAILING vs pre-E11 `f2f4c31` (via temporary read-only worktree, since removed — coordinator confirmed single worktree remains); coordinator re-ran: 2 passed. |
| E6/E11/E12 adversarial | DONE — COULD-NOT-DISPROVE, 0 findings | Auditor's own probes: E6 diff pier-row-only + no second 0.95 path + no TRANS2D; E11 minimal-dict StructureConfig constructs cleanly, spot_id filter correct, structures=None safe, invariant 3 DEMONSTRATED firing on far-structure/0-shadowed and silent on near-structure/16-shadowed, transect_handoff untouched in range; E12 59/61-min boundary exact, future-timestamp (negative elapsed) safe, naive-timestamp caught, failed never downgraded (early return :146 before overrun check :160), state read fresh per call. NOTE: auditor's 16/32-shadowed probe used its own geometry — not comparable to E11 item-2's 0/6 numbers; item 2 still resolves at Gate E with live config. |

## Phase E status at pause point (all unblocked work complete)
- CLOSED code/test level, adversarially audited: E1 (`19b0d4b`,`b044f91`), E6 (`dba85ea`), E11 (`3e40238`), E12 (`eba9622`) + guards (`f03d688`,`9331841`,`85ce1a2`,`f2f4c31`,`af02d19`). All commits LOCAL on main, NOT pushed (operator gave standing push/deploy permission — push when a deployable increment exists, i.e. after E2-geometry work unblocks; nothing deploys before Phase E geometry is complete per E0 restart order).
- BLOCKED on operator: E2 (design-Tp source; pier geometry ruling), hence E3/E4/E5/E7/E8/E9/E10.
- E9 note: rescoped invariant 6 needs E2's structure-grid cache shape — keep after E2.
- Owed operator decisions parked: cycle-level bound + swan_timeout_s 900-vs-3600 reconciliation (E12 Finding 2).
| E2–E5, E7–E10 | BLOCKED / waiting | E2 blocked on operator rulings 1+2 below; E3/E4/E5/E7/E8/E9/E10 depend on E2's grid |

## Pier geometry finding (2026-07-27, coordinator measurement — E2's "report, do not fix" trap CONFIRMED)
OSM way 45074900 (Huntington Beach Pier), principal-axis analysis of 35-node polygon:
- axis length **566.8 m**, bearing **221.0°** — EXACTLY config length_m/bearing_degrees → config derives from OSM.
- pier landward base: (33.6568071, -118.0023173) = pin + 406.2 m @ 21.1°. Seaward tip: (33.6529618, -118.006337) = pin + 230.8 m @ 257.8°.
- config `distance_m = 124.5` equals pin→NEAREST pier-edge point (bearing 302° ≈ perpendicular to axis) — i.e. lateral offset, matching `bearing_to_spot_degrees` field's "nearest point" semantics.
- BUT `_populate_structure_coordinates()` (marine_config.py:392-405, C2/`de71775`, DEPLOYED) projects: start = pin + distance_m ALONG BEARING 221°, end = start + length. Modeled pier ≈ pin+124.5→pin+691 m @221° — displaced ~500 m along its own axis vs reality. Matches findings §7 item 1's suspicion.
- Consequence: deployed OBSTACLE line and shadow geometry use a pier ~500 m seaward of the real one; plausibly explains E11 item 2 (`count:1, shadowed_count:0`). E2 sizing from this base would be wrong — plan E2 says stop and report. STOPPED.

## Surfaced to operator (pending answer; E2 blocked on #1 and #2)
1. **Where does design Tp come from?** Options: (a) new spot-config key `design_tp_s`
   (trigger 7 — wizard + marine_config + docs; recommended), (b) derive from swell climate data
   (unspecified design), (c) hardcoded constant (rejected — TRANSM 0.95 pattern). Also E2 needs a
   "swell-climate direction window"; config has `directional_exposure` (marine_config.py:555) —
   coordinator intends to rule it usable as the window (8×45° sectors, HB: S/SE/SW/W) unless operator objects.
2. **Pier geometry** (above): the honest fix candidates: (a) populate true `coordinates` from
   OSM/discover-structures into the spot config (config data change, no code; schema already supports it —
   StructureConfig.coordinates documented as auto-populated by GET /setup/marine/discover-structures);
   (b) reinterpret distance_m in the projection (data-contract semantics change — trigger 4);
   (c) leave as-is (known-wrong geometry). Coordinator recommends (a). E2, and possibly a C2 projection
   correction, wait on this ruling.
3. (Info) Gate E row 1's "dx = 12.5 m at HB" prediction is inconsistent with the approved formula at the
   findings' own L_tip≈132 m @ 8 m tip depth (gives ceiling 15.0). True d_tip from cached FINE profile
   still unread (owed measurement 2). Expectation to be corrected to derived value at Gate E.

## E1 design rulings made by coordinator (within plan authority)
1. **Design Tp arrives as a function parameter.** No `design_tp` / swell-period field exists
   anywhere in any repo (grepped marine + all repos: no design_tp|design_period|swell_period|tp_s).
   Findings §5.1.1 claims it is "already available" — FALSE against the code; §1–§8 unreliable per
   §0A preamble. E1's allowlist (swan_domain.py only) cannot create config anyway. Source of the
   value is SURFACED TO OPERATOR — must be ruled before E2 wires the call site.
2. **Formula wins over the 12.5 example.** Plan E1 says L_tip≈118 m → dx=12.5, but
   min(118/8, 15)=14.75. D6 item 2 (operator ruling) approves the FORMULA min(L_tip/8,15) floor 10;
   12.5 is a prediction contingent on d_tip ("Do not hardcode 12.5 — it is a result"). Implement
   formula exactly; Gate E row 1's "12.5" expectation may need correcting to the derived value once
   the real cached-profile d_tip is read. NOTED for operator, not a decision request.
3. **Sizing-cache emission deferred to E2's call site.** E1 has no caller (structure grid doesn't
   exist until E2). The helper returns a dict {dx_m, l_tip_m, d_tip_m, reason} which E2 must place
   into the structure-grid geometry under key `structure_grid_resolution` so it lands in
   /etc/weewx-clearskies/swan_grid_sizing.json for E7 + auditor. Key name fixed NOW.
4. **Reuse `_dispersion()`** from services/surf_1d_analytical.py:85 (same equation ω²=gk·tanh(kd),
   already known-answer-tested). Importing an existing function is not helper extraction.
5. Signatures (design, agents may not change):
   - `compute_structure_grid_resolution(design_tp_s: float, d_tip_m: float | None) -> dict`
     keys: dx_m, l_tip_m, d_tip_m, reason ∈ {derived, ceiling_applied, floor_applied,
     tip_depth_unavailable_floor_applied}. d_tip None/<=0 → WARNING + floor 10.0.
   - `tip_depth_from_fine_profile(distances_m, depths_m, tip_distance_m) -> float | None`
     linear interp between adjacent FINE-profile samples; None outside range; NO extrapolation;
     never interpolates between contour distances (findings §7 item 2 trap).
   - Module constants `_STRUCTURE_GRID_DX_FLOOR_M = 10.0`, `_STRUCTURE_GRID_DX_CEILING_M = 15.0`,
     `_TIP_WAVELENGTH_DIVISOR = 8.0`, comments citing SWAN manual L/5–L/10-at-tip criterion +
     plan E1 + findings D6 item 2.

## Surfaced to operator (pending answer; E2 blocked on #1, E1 NOT blocked)
1. **Where does design Tp come from?** Options: (a) new spot-config key `design_tp_s`
   (trigger 7 — wizard + marine_config + docs; recommended), (b) derive from swell climate data
   (unspecified design), (c) hardcoded constant (rejected — TRANSM 0.95 pattern). Also E2 needs a
   "swell-climate direction window"; config has `directional_exposure` (marine_config.py:555) —
   verify adequacy before E2, ask together if not.

## Verification evidence (fill as gates walk)
- (none yet — no live system until Phase E deploys; E1 evidence is code+test level)

---

# 2026-07-27 (continued) — new session, operator rulings + E13 execution

## OPERATOR RULING — structure grid resolution is a CONSTANT 10 m. Supersedes E1 derivation + D6 item 2.
Given in chat after the coordinator explained design-Tp only sets grid cell size (~10 vs ~12.5 m):
*"Just use a 10m grid for when L4 is needed, period."*
- **Structure grid (L4) dx = 10.0 m, fixed.** The `min(L_tip/8, 15)`-floor-10 derivation (E1, D6 item 2)
  is **retired**. E1's landed code (`19b0d4b` `compute_structure_grid_resolution`,
  `tip_depth_from_fine_profile`) is now **dead** — it has no caller; E2 uses the constant directly.
  Leave E1 code dormant or delete it in E2's commit (coordinator's call at E2 dispatch).
- **`design_tp_s` config key is OFF THE TABLE.** No new config key, no wizard field, no per-spot value.
  The E2 blocker "where does design Tp come from" is CLOSED by this ruling.
- **Residual, surfaced to operator (proceeding unless overruled):** E2 still needs a wavelength to size
  the grid-EXTENT margin (grid edge sits ~2 wavelengths past the pier near-field). Coordinator ruling:
  compute that margin from a **single fixed representative period (~15 s) as a documented sizing constant,
  applied uniformly to every spot** — affects only grid extent/cell count, never a published wave number.
  Alternative offered: a flat fixed margin distance. Settle at E2 dispatch.
- D7 (dx-vs-source-resolution safety) is trivially satisfied: fixed 10 m == HB source bathymetry 10 m.
- Gate E rows 1–2 ("dx derived = 12.5 m") are now **wrong by design** — restate as "dx = 10 m constant per
  operator ruling" when Gate E is walked.

## FINDING + coordinator decision — structure `coordinates` never round-tripped; JSON encoding chosen.
While QC-ing E13's api portion the coordinator empirically tested configobj (write nested list → read):
- configobj returns coordinates as a **list of strings** (native nested list) or a **single string**
  (JSON), NEVER a list of float-pairs. The marine reader `[[float(c[0]),float(c[1])] for c in
  section.get("coordinates",[])]` hits `float('[')` and dies either way.
- **`coordinates` has NEVER executed in production** (no config ever had it — session-log history above),
  so this reader has never actually parsed real data. E13 as written would persist coordinates the SWAN
  model silently cannot read → "passes every gate, broken at runtime."
- **Decision (coordinator, within E13's authorized contract — same field, shape, [lon,lat] order):**
  JSON-string encode on write, `json.loads` on read.
  - **stack** hidden inputs carry JSON `[[lon,lat],…]`; wizard→api payload is a real parsed list.
  - **api** `_build_marine_conf_section` writes `json.dumps(coords)`; `_serialize_marine_locations_section`
    decodes str→`json.loads` (tolerant list fallback kept).
  - **marine** reader gains `import json` + str→`json.loads` decode (4 lines, same file, within allowlist).
    Follow-up commit after the deletion `8d87ad2`.
- **Not architectural:** on-disk encoding is not a trigger-4 attribute (field name/shape/nullability/units
  all unchanged); `json` is stdlib (no new dep); `coordinates` already exists (no new key). Defect fix.
- **Guard mandate for test-author:** the E13 guard MUST round-trip through a REAL configobj file
  (write json.dumps → configobj write → configobj read → StructureConfig → assert pairs). A hand-built
  Python list would PASS while production FAILS — that is exactly the bug that hid here.

## COORDINATOR DESIGN RULING — E2 across-span is a wavelength-bounded halo, NOT a geometric ray-cast
The E2 agent implemented the plan's literal "geometric shadow union" as a ray-cast from the structure
to the shoreward-edge line, per exposure sector. It correctly STOPPED at the trip-wire: at HB the SE
sector sits ~94° from the pier axis, so a near-grazing ray runs almost parallel to the shoreward line
and produces across_span = 8648 m / 57 156 cells. That is the *opposite* of findings §3.2, which says
the strongly-modified zone stays SMALL (within ~2–4 wavelengths of the tip) precisely because
directional spreading fills geometric shadows.

**Ruling (coordinator, within E2's authorized "size the structure grid" scope — methodology, not an
architecture change; grounded in §3.2, not invented):** replace the ray-cast with a wavelength-bounded
halo:
1. Project eligible structure coords onto the axis-perpendicular → alongshore footprint [p_min, p_max].
2. A side of the axis is "illuminated" if any True `directional_exposure` sector's propagation
   (`sector+180°`) has a positive component along that side's normal (`d·n > 0`).
3. Extend the footprint: **4·L_tip** on each illuminated side (outer bound of §3.2's 2–4-wavelength
   halo — subsumes lee offset + diffraction recovery), **2·L_tip** on each non-illuminated side
   (§3.2's ~2-wavelength recovery). `_STRUCTURE_MARGIN_FALLBACK_M = 150` substitutes for L_tip when
   d_tip is unavailable.
4. across = (p_max + margin_high) − (p_min − margin_low).
At HB both sides illuminate → across ≈ 8·L_tip ≈ 960 m, × ~646 m along at 10 m ≈ 6–8k cells — back in
range. The ≥90° skip / shoreward-line intersection are dropped. **Gate E rows 1–6 & adversarial:
expect across derived from L_tip halo, NOT any geometric-shadow-to-shoreline number.**

## ⚠ TRACKED GAP — NEW TASK "E2b": run L4 through the swan.py orchestration
**Found during E2 QC (coordinator, 2026-07-27).** E2 sizes + (via E4) caches the L4 structure grid,
but `providers/nearshore/swan.py` — the SWAN-run orchestrator — iterates ONLY `level1/level2/
level3_clusters`. It touches L3 at ~11 sites: vertical-datum agreement (`:662`), `download_all_
bathymetry` ("three keys level1/level2/level3", `:709`), grid emission + SWAN run (`:2882` etc.),
POINTS parsing. **No Phase-E task owns teaching swan.py to run L4 as a 4th nested tier** (E3=swan_
formats emission only; E4=swan_domain+grid_sizing_chain sizing only; E8=swan_runner HOURLY only).
Without this, E2's L4 is cached but never executed — two writers, zero readers.

**Coordinator plan (surfaced to operator as FYI; proceeding unless redirected):** add **task E2b —
"run L4 through the pipeline"**, allowlist `providers/nearshore/swan.py` (+ possibly `swan_runner.py`
for the full-cycle path), owner `clearskies-api-dev`. It teaches the orchestrator that L4 nests under
L3-nests-under-L2: bathymetry download for L4, datum check includes L4, emit+run L4 (using E3's
rotated CGRID/NGRID), parse L4 POINTS for E5's handoff. Sequenced AFTER E3 (rotated emission) + E4
(L4 cached). This is the necessary INTEGRATION of the already-authorized L4 grid (D6 item 1), not a
new architectural decision — but it is large and cross-cutting, so it is tracked here as its own task
rather than smuggled into E4's allowlist.

## E3/E4 coordinator rulings (2026-07-27)
- **E3 item 4 (xlenc/ylenc "along rotated axes"):** plan's `:258-259` ref is STALE (that's INPGRID
  sampling, stays unrotated). Real target = `build_swan_input` xlenc/ylenc corner-projection
  (~:1288-1293). Branch: rotation==0 → existing formula unchanged (byte-identical L1/L2/L3);
  rotation!=0 → xlenc=mxc·dx, ylenc=myc·dy using the dx/dy already in scope (no new dims key).
- **E3 item 5 (L2 contains the rotated rectangle) → RELOCATED TO E4.** Emission (swan_formats) has no
  L2 bbox; containment is a sizing check. E4 now asserts L2 ⊇ L3 ⊇ (all 4 rotated L4 corners),
  fail-loud + disable cluster. A future reader of E3 will find item 5 intentionally absent there.
- **E4 role B (refraction-feature L3) resolution = 40 m too** (D6 item 5), not just role-A nest.
- **E4 reorder APPROVED as methodology:** L4 sized inside the per-cluster loop (after the FINE profile
  is extracted for d_tip), then role-A L3 re-sized as the coarse nest around L4. Same function/
  lifecycle → not trigger 5. `smart_size_l3_grid` still provides the initial FINE-download bbox.
- **E4 hard boundary:** does NOT touch bathymetry download/cache orchestration. The cache-key-vs-grid
  mismatch created by overwriting cluster.grid, and the L4(10m)+L3(40m) download split, are **E2b's**
  to resolve — E4 flags, does not fix.

## E2b DESIGN + RISK MAP (from read-only survey of swan.py + swan_runner.py, 2026-07-27)
Confirmed: ZERO L4 references in the run pipeline — L4 is sized+cached but never executed. E2b surface:
- **LOW risk:** add `"level4"` key to `download_all_bathymetry` dict (swan.py:709/751 + hourly :2887);
  datum guard includes L4 (swan.py:662, gates whole run); `bathymetry_cache_path` level-4 branch
  (swan.py:240) — but key L4's cache off the SAME persisted `StructureGridDomain`, not a re-derived
  bbox (E4 key-mismatch hazard + rotation).
- **HIGH risk (the core):** in `swan_runner.run_3level()` L3 loop (:3253-3405), **L3 must become a
  "middle" grid** — read L2 via BOUNDNEST1 AND write a NESTOUT sized to its L4 child, then run L4 as a
  new nested inner grid (copy L3 NESTOUT → L4 BOUNDNEST1, call build_swan_input with rotation_deg +
  is_structure_grid=True). Template = L2's existing outer-then-text-patch trick (:2673-2761). **This
  path already caused a production zero-energy bug (SWAN-FIXES-PLAN Bug 1): the NESTOUT-write file and
  BOUNDNEST1-read file MUST be different filenames or SWAN silently zeroes energy.** Adds a 4th nest
  filename set + `level4_{...}` hotstart key. Mirror in `run_stationary_level3()` (:3455, hourly) is
  E8's concern but depends on L3 persisting a NESTOUT in the full run first.
- **Handoff (E5):** currently sourced from L3 CURVE/POINTS (`_select_l3_handoff_position_and_spectrum`
  swan_runner.py:673, `_select_l3_handoff_spectra` :1532). E2b must make L4 EMIT CURVE/POINTS (run it
  as inner with scoped spots/transects); E5 then re-sources the handoff from L4.
- **Coordinator approach ruling:** replicate the PROVEN L2 middle-grid pattern for L3 (reuse
  battle-tested code incl. the different-filename constraint) rather than invent a new middle mode.
  Byte-identical L1/L2/L3 output when a cluster has NO L4. Agent stops-and-surfaces if it must diverge
  from the L2 template. The L2→L3→L4 nesting itself is APPROVED design (§0A D2), so E2b is authorized
  integration, not a new architectural decision — but it is the highest-risk implementation in Phase E.

## E9 IMPL — ACCEPTED (2026-07-27 session 2). Commit `416e1fc` (marine, LOCAL, not pushed).
Agent `e9-invariants`. Coordinator acceptance gate — all re-run/re-checked independently:
- `git show 416e1fc --stat` = ONLY the 3 allowlisted files (swan.py inv-6 block +161, invariants.py +79, surf_1d_pipeline.py inv-2 block); tree clean; single worktree.
- Full marine suite MY OWN run: 268 passed / 2 skipped (matches agent).
- Renamed INVARIANT_6 string value ("...reaches_15m_contour" → "...reaches_feature_it_was_sized_for"):
  grepped ALL repos + docs — ZERO references outside this session log. Safe rename (tests use the attribute).
- `git diff 416e1fc^ 416e1fc` adds/removes NO lines mentioning INVARIANT_1/3/4/5/7/8/9; surf_1d change is one
  contiguous hunk @@ -1204,30 +1204,33 @@ (invariant 2 only). Other invariants byte-unchanged — verified, not trusted.
- Spot-read swan.py 2308-2429: per-grid-kind branches exactly as ruled — structure-grid→loud skip (info, not
  check); L3+structure→REAL independent check `rotated_rect_clearance_to_bbox_m(L4.corners vs L3 bbox) ≥ 2·L3 dx`
  (non-tautological: two independently-sized shapes); L3-only→15 m-contour assertion retained byte-faithful;
  neither→explicit non-vacuous skip. New helper `rotated_rect_clearance_to_bbox_m` is pure geometry.
- OWED: E9 GUARD (test-author). Plan's guard text ("fire against short structure grid") targets the NOW-STUBBED
  tip+L_tip branch → REDIRECT the guard to the real new check: fire when L3 does NOT contain L4 w/ 2-cell
  clearance, NOT fire when it does; plus assert the structure-grid branch emits the skip (not a check/pass).

## ⚠⚠ SURFACED TO OPERATOR — COORDINATE SYSTEM (Cartesian/UTM vs Spherical). Architectural; operator's call. (2026-07-27)
Operator challenged F1 (UTM-zone straddle) as unacceptable for a general (non-HB) product and asked what SWAN says +
why not spherical. Coordinator answered from the LOCAL manual (docs/reference/swan-user-manual.pdf), verbatim facts:
- SWAN supports BOTH: "SWAN operates either in a Cartesian coordinate system or in a spherical coordinate system".
  We run CARTESIAN + project lat/lon→UTM. Zones exist ONLY because of that projection; SWAN has no zone concept.
- **Spherical FORBIDS rotated grids:** "in case of spherical coordinates regular grids must always be oriented E-W,
  N-S, i.e. [alpc]=0, [alpinp]=0, [alpfr]=0." Our L4 structure grid is ROTATED (alpc≈229°, the whole point of E2/E3 —
  2-3× cell savings, pier-aligned resolution). Spherical ⇒ lose grid rotation (bigger axis-aligned structure grid).
- Secondary: "set-up is not computed correctly with spherical coordinates" (now mostly moot — setup delivered via WLEVEL).
- Nesting must use the SAME coordinate system parent+child. Cartesian origin is "chosen totally arbitrarily by the user."
- **The F1 zone bug is OURS, not SWAN's:** our projection picks a UTM zone PER-GRID from each grid's own centroid, so a
  parent+child near a 6° zone seam land in different frames. SWAN only requires ONE consistent Cartesian frame for the
  whole nest.
**DECISION OWED (operator), two honest paths:**
  - **A (coordinator RECOMMENDS):** keep Cartesian, fix the projection to ONE frame per site (lock the UTM zone once from
    site center, or a site-centered transverse-Mercator/local tangent plane — no zone seams). Kills the straddle bug AND
    the ~2 m flat-earth residual, KEEPS rotated grids. Contained to the projection layer (utm_zone/lonlat_to_utm sites) +
    a loud guard refusing to run if parent/child resolve to different frames.
  - **B:** switch to COORDINATES SPHERICAL — matches native lat/lon datums, no projection/zones — but every grid becomes
    axis-aligned (structure grid loses rotation, grows 2-3×) and it ripples through E3's rotated CGRID/NGRID emission.
Non-blocking for E5/E8/E10 (handoff/output logic is coordinate-frame-agnostic — they survive either A or B). If B is
chosen, the rotated-grid layer (E2/E3/E2b/E7 geometry) needs rework; the handoff pipeline built on top does not.
AWAITING OPERATOR A/B. Pipeline continues on A/B-agnostic work meanwhile.

## E2b+E3 GUARDS — ACCEPTED (2026-07-27). Commit `e14baa2` (marine). Closes audit F2/F3/F4 coverage gaps.
Agent `e2b-guards`. 2 test files (+770): test_swan_formats_grid_emission.py +65 (F2 decoupled-rotation, proven FAIL at
53abe07^ via worktree/TypeError), NEW test_swan_runner_l4_nesting.py (8 tests driving REAL run_3level, only SWAN
subprocess/convergence/parse stubbed; _write_input_files real). Covers: no-L4 inner branch, L4 nested outer→inner +
NESTOUT distinct-filename collision-safety, orphaned-spot fallback, L3-middle convergence-fail, RuntimeError-degrade,
scope-restore (normal+exception), F4 idx-align pin. Coordinator gate: `git show e14baa2 --stat`=2 test files only; MY OWN
`pytest tests/`=285 passed/2 skipped (+9). Honest limit: no real SWAN binary (monkeypatched boundary, same as existing).

## E2b PART 2 — ADVERSARIAL AUDIT CLEAN (2026-07-27). Agent `e2b-audit` (clearskies-auditor, never saw the impl).
0 BLOCKER, 0 MAJOR, 4 MINOR. Auditor built its OWN probes (monkeypatched run_3level), did an ACTUAL git-worktree
byte-diff of no-L4 level1/2/3 INPUT+BOTTOM+WIND (stronger than the author's structural claim — zero diff), reproduced
the REAL asymmetric rotation case, and could-not-disprove all 5 invariants. E2b part 2 is CLEARED to build E5 on.
Findings + disposition:
- **F1 [MINOR, latent, NOT this diff]** build_swan_input computes UTM `_zone` from the CALLING grid's centroid and
  reuses it for the child's inner_dims/NGRID projection; the child's own inner call recomputes its own zone. If a
  parent+child ever STRADDLE a UTM zone boundary (6° wide), CGRID/NGRID diverge by km → silent energy-zero. At HB both
  are zone 11 (auditor confirmed match). Pre-existing (affects L1→L2/L2→L3 too), not introduced by c3f22f7.
  **DISPOSITION: TRACKED non-HB limitation — do NOT fix in E2b (out of scope, not triggered).** The E3-amendment's
  "match by construction" guarantee has a hidden precondition: parent+child share a UTM zone. Before ANY non-HB
  deployment, add a same-zone assertion/handling in build_swan_input. Candidate cheap guard: assert L3.zone==L4.zone.
- **F2 [MINOR, coverage]** test 148 (the one 53abe07 updated) still passes the SAME rotation to both params — it does
  NOT exercise the production asymmetry (parent rotation_deg=0, child inner_rotation_deg≠0). → covered by the queued
  E3-amendment decoupled guard.
- **F3 [MINOR, coverage]** NO repo test exercises run_3level's new ~250-line L4 branch. → covered by the queued E2b guard.
- **F4 [verified NOT a bug]** L4 bathymetry `bathymetry["level4"][idx]` uses the L3-loop idx; `level4_clusters` is built
  1:1 in the SAME loop in grid_sizing_chain.py:786-827 (grid=None placeholder when no L4), so positionally aligned by
  construction — but the guarantee lives in a 3rd file with no local assert. → add a PINNING TEST (guard) that a future
  grid_sizing_chain filter of level4_clusters would break, so misalignment can't land silently.
**DECISION: E2b (parts 1+2) fully accepted. Dispatch (a) test-author guards covering F2+F3+F4, (b) E5 (design-ack gated
behind guards landing to avoid shared-tree pytest race). E5 code-write does NOT start until I review its design.**

## E2b PART 2 — ACCEPTED AT CODE LEVEL (2026-07-27). Commit `c3f22f7` (marine). Adversarial audit + guards PENDING.
Agent `e2b-l4run`. swan_runner.py only (+571/-66). Runs L4 as a nested inner grid under L3-as-middle. Coordinator gate:
- Scope = swan_runner.py only; my OWN full suite = 276/2; tree clean.
- READ the whole L4 branch (swan_runner.py:3454-3863): no-L4 path (3474-3639) BYTE-IDENTICAL to original (same
  _write_input_files "inner" call + args; scope-restore just moved into finally = safe superset). L4 path: L3 runs
  "outer" with inner_dims_override=l4_dims + inner_rotation_deg=l4_alpc (L3's own rotation stays 0), INPUT patched
  BOUNDSPEC→BOUNDNEST1 (proven L2 trick), NO _parse_output on L3-outer (correct — outer emits no POINTS); L4 runs
  "inner" reading l3_dir/nest_out.dat→l4_dir/nest_in.dat (distinct dirs+filenames), rotation_deg=l4_alpc,
  is_structure_grid=True, dims_override=l4_dims; parse→all_results. All 4 amendments present+correct: orphaned-spot
  fallback (3828-3855, loud WARNING, self-flags as Gate-E sizing finding), corner assertion (_l4_dims_and_alpc,
  Kabsch fit + empirical self-check, RuntimeError→degrade, tol=resolution_m), L4 hotstart invalidation (3727-3757),
  finally-restore (3856-3860).
- Agent's evidence: corner recon 2.20 m worst on real HB grid (alpc=229.10, CGRID==NGRID); NESTOUT chain proof;
  hotstart 3-run cold/warm/cold demo; orphaned-spot 2-spot demo. NOTE: SWAN binary NOT run (monkeypatched, same as
  existing tests) — REAL nesting behavior is unverified until the Gate-E deploy.
- 2 design choices CONFIRMED by coordinator: (1) mis-oriented L4 degrades that cluster to no-L4 (loud ERROR) not
  abort-run; (2) orphaned-spot fallback also covers L3-middle convergence failure. Both good judgment, surfaced not silent.
- MINOR TRACKED tidy-up: `getattr(domains,"level4_clusters",[])` at :3455 is defensive for a stale SimpleNamespace test
  double; fix that fixture + use direct access later (test-file change, was outside E2b allowlist). Harmless.
- PENDING before E5 builds on this: (a) adversarial audit (clearskies-auditor, never saw the impl); (b) guard tests
  (test-author): byte-identical no-L4 INPUT, NESTOUT chain, corner assertion, orphaned-spot, + the E3-amendment
  decoupled-nesting guard still owed. E5 does NOT dispatch until the audit clears.

## E3-AMENDMENT — ACCEPTED (2026-07-27). Commit `53abe07` (marine, LOCAL). Fixes the rotated-nesting defect below.
Agent `e3-ngrid-fix`. Added `inner_rotation_deg` to build_swan_input; NGRID alpn + geometry now key off it (decoupled
from the parent's own CGRID `rotation_deg`). Design elegance: NGRID reproduces the child's CGRID by running the
IDENTICAL formula on the IDENTICAL dims (contract: outer-call `inner_dims` == child inner-call `dims`, and
`inner_rotation_deg` == child's `rotation_deg`) — a match by construction, not a second geometry derivation.
Coordinator acceptance gate:
- `git show 53abe07 --stat` = swan_formats.py (+the 1-line authorized mechanical fix to test 148); tree clean.
- Full suite MY OWN run: 276 passed / 2 skipped.
- Diff confirms NGRID block (branch select + `_alpn`) now uses `inner_rotation_deg`; CGRID block still `rotation_deg`.
- **I INDEPENDENTLY REPRODUCED the previously-broken case** (scratch /c/tmp/e3_verify.py): outer call rotation_deg=0.0
  + inner_rotation_deg=221.0 → parent CGRID alpc="0.", NGRID alpn="221.00", and NGRID x/y/xlenc/ylenc/mxc/myc ==
  the child's own inner-CGRID fields EXACTLY. This is the case that silently zeroed energy before; now correct.
- **inner_dims CONTRACT for E2b (verbatim):** when the child is rotated (`inner_rotation_deg != 0`), the outer call's
  `inner_dims` MUST be field-for-field identical to the `dims` dict passed to that child's OWN `grid_level="inner"`
  call, and `inner_rotation_deg` == that child's `rotation_deg`. lon_sw/lat_sw = the grid's ORIGIN CORNER (local (0,0)
  on its rotated axes), NOT a bbox SW corner. E2b: build ONE dims dict for L4, pass it as both L4's inner `dims` and
  L3's outer `inner_dims`, with the same rotation value.
- OWED: NEW positive guard (test-author) — the updated test 148 still only tests the COUPLED case (both 221); the
  decoupled parent-0/child-221 case is currently guarded only by my scratch reproduction. Dispatch AFTER E2b part 2
  (shared-tree/pytest-collection concurrency). Guard asserts: parent CGRID alpc=0 + same INPUT NGRID alpn=child-rot +
  NGRID fields == child inner-CGRID fields.

## 🛑 FINDING (E2b review) — E3 is INCOMPLETE for rotated NESTING. New blocker: E3-amendment task. (2026-07-27)
Surfaced while reviewing E2b's design + the agent's Amendment-2 (corner-reconstruction) work. Coordinator
independently verified by reading swan_formats.py:1388 (own CGRID) and :1595-1634 (child NGRID):
- **Problem A (rotation coupling):** in one `grid_level="outer"` build_swan_input call, the grid's OWN CGRID
  (`_alpc_alpn`, :1344/1388) and the child's NGRID (`_alpn`, :1627) BOTH use the single `rotation_deg`. For
  L3-as-middle nesting a ROTATED L4, L3's own CGRID must be alpc=0 while L4's NGRID must be alpn=L4-rotation —
  one param can't do both. Wrong → CGRID(L4) ≠ NGRID(L4-from-L3) → SWAN silently zeroes L4 energy (the exact bug
  E3 point 2 warns of).
- **Problem B (NGRID geometry):** the NGRID origin/extents (:1601-1623) come from an AXIS-ALIGNED inner bbox
  (`inner_dims` via `_compute_swan_grid_dims`), not L4's rotated rectangle. Even with correct alpn the child's
  position/extent would be wrong.
- **Root cause:** E3 delivered rotated SELF-CGRID (works for L4 describing itself) but never a rotated-child
  NGRID from an UNROTATED parent. The E3 guard (test_swan_formats_grid_emission.py:126) only tested the COUPLED
  case (a grid's own inner-CGRID vs a synthetic parent's outer-NGRID, BOTH rotation 221) — passed, gave false
  confidence. The real L3(0)→L4(221) case was never emitted or tested.
- **NOT a new architectural decision** — E3's own plan (MARINE-...-PLAN.md:1079-1102) mandates working rotated
  CGRID/NGRID nesting; this is a defect fix to make E3 meet its stated contract (emitter's job unchanged).
  In-scope, no operator approval needed. But it's OUTSIDE E2b's allowlist (swan_formats.py = E3's file).
- **ACTION:** E2b PAUSED on the L3-middle/L4 branch (committed its independent part-1 plumbing first). Dispatch an
  E3-amendment task on swan_formats.py: decouple the parent's own-CGRID rotation from the child's NGRID
  rotation+geometry (add e.g. `inner_rotation_deg` + source NGRID origin/extents from the child's ROTATED
  descriptor, not an axis-aligned bbox); byte-identical for all-unrotated; then EXTEND the E3 guard to the
  unrotated-parent→rotated-child case (NGRID alpn=child-rot AND same INPUT's CGRID alpc=0; NGRID origin/extents
  match the child's rotated rectangle). Then resume E2b.

## 📌 TRACKED FINDING (not fixed now) — swan_domain corners (flat-earth/true-north) vs swan_formats (UTM/grid-north).
E2b's Amendment-2 reconstruction found a ~2.2 m irreducible residual (least-squares 4-corner best-fit) between
`compute_structure_grid_domain`'s corner construction (equirectangular local E/N, true north, swan_domain.py
~2020-2036) and build_swan_input's real-UTM projection (grid north; meridian convergence ~0.5° at HB's ~1° offset
from the zone central meridian). Sub-grid-cell (dx=10 m), physically negligible vs 2-4·L_tip margins; nest stays
internally consistent (CGRID=NGRID from one value). Also confirmed: `alpc = (90 - rotation_deg) mod 360` (compass→
SWAN-Cartesian) is required and is the CALLER's (E2b's) job — build_swan_input's docstring already says so.
E2b ships the corner-reconstruction guard with tolerance = resolution_m (10 m). A swan_domain UTM-consistent
corner rebuild is a SEPARATE future task if ever warranted — not now (no functional impact at HB).

## ✅ OPERATOR DECISION — l_tip_m persistence: OPTION C (no persistence). Resolved 2026-07-27, commit `0b1cb34`.
Operator reframed (correctly) that grids are sized+validated ONCE at setup and frozen — nothing re-sizes at runtime.
Coordinator verified: the structure grid's offshore reach IS validated at config-push by `_l3_viability_check()`
(swan_domain.py:355), which runs with the freshly-computed L_tip in hand and disables a grid that can't reach its
structure. So the per-cycle invariant-6 structure-grid reach check is REDUNDANT with the setup gate, and persisting
l_tip_m buys only a re-check of a frozen value (catches cache corruption only — not invariant 6's purpose).
**RULING: keep the per-cycle structure-grid branch a permanent loud skip. NO l_tip_m persistence, NO new field, NO
HARD-BLOCK change.** Coverage is complete without it: "L4 reaches structure" = setup viability test; "L3 still
contains L4" = per-cycle invariant-6 nesting check (E9); "L4 reaches tip+L_tip per cycle" = redundant, skipped.
Coordinator's earlier framing (that this was a coverage gap) was wrong — over-weighted the per-cycle invariant vs
the setup gate. Finalized swan.py + invariants.py skip text to state this rationale (`0b1cb34`, comment/log only).
LESSON (→ candidate rules/verification.md): a "frozen-at-setup" quantity should be validated at the setup gate
where all inputs are in hand, NOT re-checked per-cycle against a lossy persisted cache — the per-cycle check is
either redundant or forced-tautological. Ask "does this re-check catch anything the setup gate can't?" before persisting.

## E9 GUARD — ACCEPTED (2026-07-27 session 2). Commit `255d192` (marine, pushed).
Agent `e9-guard`. tests/test_swan_invariant6_grid_kind.py, 8 tests (+390). Acceptance gate (re-run independently):
- `git show 255d192 --stat` = only the new test file; tree clean; single worktree.
- MY OWN `pytest tests/test_swan_invariant6_grid_kind.py -q` → 8 passed. Full suite (agent) 276 passed / 2 skipped.
- Change-guards: tests 1-2 (known-answer on rotated_rect_clearance_to_bbox_m, 222.64 m hand-computed) + tests 3-4
  (threshold boundary 79.9 m FIRES / 80.1 m does NOT, around 2·dx=80). These 5 depend on the E9-new helper →
  AttributeError at 416e1fc^ (helper absent — verified during E9 accept). The 3 that pass pre-change pin UNCHANGED
  behavior (refraction branch + structure-no-L3 no-op) — regression pins, not change-guards. Correct.
- Test 5 spies invariants.check via monkeypatch → proves structure-grid stub NEVER calls check() (not a silent pass;
  get_invariant_state only records firings so the spy is the right observable). Honest coverage caveat carried in
  the module + per-test docstrings (helper+predicate level, NOT swan.py dispatch — see the RESIDUAL note below).

## 📌 TRACKED (NOT a silent deferral) — E9 guard covers helper + branch predicates, NOT swan.py dispatch wiring.
The invariant-6 block is inline in `_run_all_spots_locked` (~1000 lines; wind/bathymetry/SWAN-exec run before
it), so it is not unit-drivable without a disproportionate mock stack, and extracting a testable helper would
collide with E2b (concurrently editing swan.py). E9 guard (`e9-guard`, tests/test_swan_invariant6_grid_kind.py)
therefore: (1) known-answer-tests the new helper `rotated_rect_clearance_to_bbox_m` directly — the real new
geometry; (2) drives the branch predicates + the 2·dx-clearance boundary + check()-firing with swan.py's own
args, but NOT swan.py's 4-way branch dispatch. **RESIDUAL: a regression introduced only in swan.py's branch
selection would not be caught.** CLOSE THIS when swan.py is next legitimately open (after E2b lands) by
extracting the invariant-6 evaluation into a small pure helper + a test that drives it — methodology, not
architecture (invariant's job unchanged). Not urgent (dispatch logic is simple boolean cluster-membership,
coordinator-read-verified), but tracked so it doesn't rot.

## 📌 TRACKED (NOT a silent deferral) — Phase-E consolidated doc-sync before Gate E.
The governing docs do NOT enumerate invariants by number, so E9 has no per-invariant doc obligation. BUT
ARCHITECTURE.md (line ~98) + ADR-093 + API/OPERATIONS/PROVIDER manuals still describe the PHASE-14 SWAN grid:
"L3 = 10 m surf zone, does not run to shore, handoff at 1.3×Hs/0.73, alongshore smart-sized around structures."
Phase E's D2/D3 redesign supersedes ALL of that (L4 rotated structure grid; L3 = coarse 40 m nest OR refraction
grid; handoff rule D3; per-transect profiles). This is real doc-code drift but it can only be reconciled ONCE the
final design lands (after E2b/E5/E8/E10) — writing it now would document a half-built state. **ACTION: a single
doc-sync task updating ARCHITECTURE.md SWAN section + the manuals + ADR cross-refs, run AFTER E10, BEFORE the
Phase-E deploy/Gate E, same increment.** Do not skip — it is a Gate-E precondition.

## ⚠ SURFACED TO OPERATOR — l_tip_m persistence dropped by the 10 m ruling (silent deferral). E9 partially blocked.
Found by agent `e9-invariants` during E9 prep, independently confirmed by coordinator (2026-07-27 session 2).
- **The gap:** invariant 6's structure-grid branch is specced as "structure-grid offshore edge ≥ tip + 1·L_tip."
  But `l_tip_m` is NOT persisted in the sizing cache — `domain_sizing_to_dict()` (swan_domain.py:2216) emits
  only corners/rotation_deg/resolution_m/along_span_m/across_span_m/level. The corners/along_span_m ALREADY
  bake in tip + L_tip, so any check reading them for both sides is TAUTOLOGICAL; the only independent L_tip
  needs a dispersion recompute against the FINE profile, which E9 forbids. No non-tautological in-scope path exists.
- **Root cause = silent deferral:** plan E1 ruling #3 fixed the key `structure_grid_resolution` (carrying
  `l_tip_m`) and required it persisted "for E7 + auditor." The 10 m operator ruling then killed
  `compute_structure_grid_resolution` (dx now constant) — but NEVER stated l_tip_m was no longer needed.
  E9/E7/auditor still need it; it fell out of the cache unnoticed. Exactly the "silent deferral never dealt
  with by the coordinator" pattern flagged at session start.
- **Coordinator handling (no lead call on the arch part):** E9 proceeds on all other branches + invariant 2
  now; the structure-grid branch ships as a LOUD, tracked skip (INFO, not a pass) naming this reason, so
  coverage loss is visible and a one-line follow-up can flip it to the real check once L_tip is persisted.
- **OPERATOR DECISION OWED** (adding a field to the sizing cache = trigger 4/7, arch HARD BLOCK — needs your nod):
  - Option A (RECOMMENDED): restore the plan's own intent — persist `l_tip_m` + structure tip position into
    the StructureGridDomain serialization at sizing time (small E2-amendment task: swan_domain.py sizing +
    domain_sizing_to_dict/from_dict). Then invariant 6's structure-grid check becomes a genuine, non-tautological
    cache-consistency + collapse guard (persisted-L_tip vs corners-derived edge, two independent values that can disagree).
  - Option B: accept a WEAKER check — structure-grid edge ≥ structure tip (tip from the persisted config OSM
    coords, independent of grid sizing); catches a full collapse but not the 1·L_tip margin. In-scope for E9, under the plan spec.
  - Option C: leave the structure-grid branch as the permanent loud-skip (coverage gap accepted; invariant 6
    never validates the case E6/E2 care about most). NOT recommended.

## E3+E7 GUARDS — ACCEPTED (2026-07-27 session 2). Commit `af7bcda` (marine, LOCAL, not pushed).
Agent `e37-tests`. tests/test_swan_formats_grid_emission.py, 8 tests (8 functions for 7 numbered guards;
guard 4 split). Coordinator acceptance gate (all independently re-run, not trusted):
- `git show af7bcda --stat` = ONLY the test file, +362; `git worktree list` = primary only; tree clean.
- `pytest tests/test_swan_formats_grid_emission.py -q` on main → 8 passed (my own run).
- Fail-vs-pre-change corroborated by API presence: `rotation_deg` count 0 in 49df65c^ → 12 in 49df65c;
  `is_structure_grid` count 0 in d517084^ → 4 in d517084. Guards must TypeError against the parents.
- Agent honestly flagged test 4 pins the mxc*dx formula (algebraically == corner projection at this grid
  size, so value-indistinguishable — pins against a future dx-rederivation regression, not a branch divergence)
  and that guard 6 caught a REAL pre-E7 regression (L3-style call emitted DIFFRACTION before E7 gated it).
  Both acceptable. Full suite (agent) 268 passed / 2 skipped; pure-addition test file cannot break prod, accepted.

## FINDING + coordinator decision — E9 allowlist ("invariants.py only") is WRONG; corrected to 3 files.
Verified before dispatch (2026-07-27 session 2). The plan's E9 header says **Files: invariants.py only**, but
the actual invariant ASSERTIONS do not live there — invariants.py holds only the geometry helper
(`ray_box_exit_distance_m`) and the name constants. The real `invariants.check()` call sites are:
- **Invariant 6** assertion → `providers/nearshore/swan.py:2308-2354` (reads `domains.level3_clusters`,
  `runtime_profile.contour_15m_distance_m`, measures bbox exit along bearing, compares to 15 m contour).
- **Invariant 2** skip → `services/surf_1d_pipeline.py:1205-1231` (already logs a SKIP, NOT a pass, per the
  7fb75f9 lead ruling — but frames the zero-overlap as a *data-flow* artifact, not the D3 architectural boundary).

**Coordinator ruling:** the "invariants.py only" line is a plan defect (wrong about code location), NOT an
architectural question — the invariant's job (observe grid collapse, log, never alter output) is unchanged;
only the assertion predicate (per-grid-kind) and invariant-2's recorded rationale change, both explicitly
authorized by E9 + D2/D3. **Corrected allowlist: `invariants.py` + the invariant-6 block in `swan.py`
(2308-2354 only) + the invariant-2 block in `surf_1d_pipeline.py` (1205-1231 only).** Must-not-touch:
every OTHER line of swan.py and surf_1d_pipeline.py, and the call sites of invariants 1,3,4,5,7,8,9.
- **Grid-kind is inferable from existing fields (no new field needed):** `DomainSizing.level4_clusters`
  (StructureGridCluster, each `.grid: StructureGridDomain`) + `level3_clusters`. Per spot:
  in level4 → structure grid; has L3 AND in level4 → L3 nesting step; has L3 NOT in level4 → L3 refraction
  (retain 15 m assertion); neither → skip (not vacuous pass). `StructureGridDomain.along_span_m` is defined
  as reaching tip + 1·L_tip, so the structure-grid check must be MEANINGFUL (fail against a shrunk grid),
  not tautological — measure the actual seaward corners vs tip+L_tip, matching E9's mandated guard.
- E9 is INDEPENDENT of E2b: it reads the sizing cache written at config-push by E2/E4 (already committed),
  not the L4 SWAN run. Dispatched in parallel with the E3/E7 guards.

## E13 execution log (this session)
| Portion | State | Commit |
|---|---|---|
| marine deletion (item 3) | ACCEPTED — coordinator re-ran greps (111320 gone, helper gone, 2 files) | `8d87ad2` |
| marine reader decode (finding above) | dispatched follow-up | (pending) |
| api field + JSON encode (item 2) | encoding confirmed, implementing | (pending) |
| stack wizard/admin carry-through (item 1) | scope confirmed, implementing | (pending) |
| test-author guards (item 4) | dispatch after marine reader lands; MUST use real configobj round-trip | (pending) |
