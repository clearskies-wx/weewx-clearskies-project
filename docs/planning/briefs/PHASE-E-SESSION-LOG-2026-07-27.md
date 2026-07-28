# Phase E session log — 2026-07-27 (coordinator scratch, survives session limits)

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
