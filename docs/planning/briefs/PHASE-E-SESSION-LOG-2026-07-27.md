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

**COMMIT LEDGER (all on `main`, each independently acceptance-gated by coordinator):**
- Phase E DONE + PUSHED (all repos): E13 — marine `8d87ad2`+`1307386`+guard `634c430`; api `5ca6a93`;
  meta(API-MANUAL) `3444fa1`; stack `19d9332`. (Real OSM structure coords persisted wizard→api→marine;
  pin-projection fabrication deleted; JSON-encoded coords contract fixed — configobj can't round-trip
  a nested list.)
- Phase E DONE, marine, PUSHED (session 2, just pushed): E2 `7ea961b` + guard `97e08d1`; E3 `49df65c`;
  E7 `d517084`; E4 `6b48abd`.
- E6 (pier TRANSM 0.82) `dba85ea`, E1/E11/E12 — done in session 1 (see task table further down).

**PHASE E TASK STATUS:**
- ✅ E13, E1(⛔superseded by 10m ruling — dead code dormant), E2, E3, E4, E6, E7, E11, E12 — DONE.
- 🔄 E3+E7 guards: test-author agent `adf822c0fe2974f44`, scope CONFIRMED, writing
  `tests/test_swan_formats_grid_emission.py` (7 guards). Accept when it closes out (diff+rerun+worktree-clean).
- ⬜ **E2b (NEXT, HIGH RISK)** — run L4 through swan.py/swan_runner.py. Full design+risk map is in the
  "E2b DESIGN + RISK MAP" section below. Core: L3 must become a "middle" grid writing a NESTOUT for L4
  (replicate the PROVEN L2 pattern at swan_runner.py:2673-2761; DIFFERENT filenames or SWAN zeroes
  energy — known prod bug). Byte-identical L1/L2/L3 when no L4. Then L4 emits CURVE/POINTS for E5.
  Allowlist: `providers/nearshore/swan.py` (+ `services/swan_runner.py`). Owner clearskies-api-dev.
  Operator nod on "replicate L2 pattern" approach requested but NOT blocking (D2 already approves the
  nesting). Sites: bathymetry dict +"level4" (swan.py:709/751,:2887); datum guard +L4 (swan.py:662);
  bathymetry_cache_path level-4 branch keyed off the persisted StructureGridDomain (swan.py:240);
  run_3level L3 loop (swan_runner.py:3253-3405); pass rotation_deg+is_structure_grid at swan_runner.py:4021.
- ⬜ E9 (invariants 2+6 rescope) — INDEPENDENT of E2b (reads sizing cache, not L4 run). Can dispatch in
  parallel. Files: services/invariants.py. Invariant 6 → per-grid-kind reach; invariant 2 → mark N/A
  where handoff is a clean boundary (D3). Must-not-touch invariants 1,3,5,7,8,9.
- ⬜ E5 (handoff rule D3, first-match-wins per transect; deep-water ref stays L2; DOC-SYNC in same
  commit) — depends on E2b (L4 must emit output). Files: transect_handoff.py, surf_1d_pipeline.py.
- ⬜ E8 (hourly quick update runs every handoff grid; swan_runner.py) — depends on E2b (L3-middle).
- ⬜ E10 (per-transect profiles span own handoff→shore; reworks C4 `060a56b`) — depends on E5.
  Files: grid_sizing_chain.py, enrichment/bathymetry.py, providers/nearshore/swan.py, endpoints/beach_profile.py.
- Then: single Phase-E deploy → Gate E (27 rows, live) + adversarial → Phase F (F1-F5, wind source term
  in 1D model; F3 needs Young&Verhagen 1996 paper — HARD GATE) + Gate F → Phase D (D1) + Gate D.

**KEY RULINGS THIS SESSION (detail in sections below):** (1) OPERATOR: structure grid dx = fixed 10m;
kills design_tp_s + E1 derivation. (2) E2 across-span = wavelength-bounded halo (4·L_tip illuminated
side / 2·L_tip not), NOT geometric ray-cast. (3) coords JSON-encoded across api↔marine (configobj
can't round-trip nested list). (4) E3 item4 xlenc branch on rotation (no new dims key); item5
relocated to E4. (5) E7 NUMERIC follows DIFFRACTION to L4. (6) E4 role-B L3 also 40m; E4 flags but
doesn't fix bathymetry cache-rekey (→E2b). (7) E2b = replicate L2 middle-grid pattern.

**QC METHOD (keep doing):** every agent report is a claim — re-run its check myself, `git show
<commit> --stat` vs allowlist, spot-read one design element, confirm no must-not-touch file changed.
Agents dispatched with mandatory git-restriction + arch-change blocks; scope-ack before code.

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

## E13 execution log (this session)
| Portion | State | Commit |
|---|---|---|
| marine deletion (item 3) | ACCEPTED — coordinator re-ran greps (111320 gone, helper gone, 2 files) | `8d87ad2` |
| marine reader decode (finding above) | dispatched follow-up | (pending) |
| api field + JSON encode (item 2) | encoding confirmed, implementing | (pending) |
| stack wizard/admin carry-through (item 1) | scope confirmed, implementing | (pending) |
| test-author guards (item 4) | dispatch after marine reader lands; MUST use real configobj round-trip | (pending) |
