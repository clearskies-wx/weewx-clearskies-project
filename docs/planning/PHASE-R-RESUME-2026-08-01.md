# Phase R — Session Resume Brief (2026-08-01)

Coordinator handoff / post-compaction state. Read this + `MARINE-MODEL-RESTORATION-PLAN.md`
(PHASE R, incl. the "R1 RESULT" block) + `rules/coordinator.md`/`agents.md`/`verification.md`
before acting. All findings below are MEASURED this session from primary artifacts.

## THE HEADLINE FINDING (this is where the work stands)

**The vanishing swell dies INSIDE the coarse L1 grid, before the first grid handoff.** Measured
swell (T>10s) trace at the nowcast hour, deployed commit `5581b0a` (R5), facing 217°:

| Stage | Swell | note |
|---|---|---|
| WW3 source / L1 south boundary (input) | **0.74 m @ 185°** | real swell present (matches Surfline ~0.85 m) |
| L1 → L2 handoff (`level1/nest_out.dat`) | **0.12 m** | ~85% already lost crossing L1 |
| 15 m checkpoint inside L2 (`spec_l2_dwr`) | **0.04 m** | |
| L2 → L3 handoff (`level2/nest_out.dat`) | 0.06 m | |

The WW3→SWAN entry is HEALTHY. The nest handoffs are NOT the loss point. The swell is destroyed
while propagating across the 1 km L1 grid. Loss is steady across ALL 16 forecast hours (~95% every
hour) → NOT a cold-start/spin-up delay; the swell is actively dissipated or mis-propagated.

**L1 physics config (from `/tmp/r5-run/level1/INPUT`):** `GEN3 WESTHUYSEN`, live wind field
(`READINP WIND 'WIND.txt'`), `FRICTION JON 0.067`, `BREAKING CONSTANT 1.0 0.73`, `TRIAD`,
`MODE NONSTATIONARY`. Near-shore dominated by 3.8 s chop from ~270° (W) = local wind sea.
**Leading (UNPROVEN) hypothesis:** 3rd-gen model over-dissipating south swell in the presence of a
cross/opposing westerly wind sea, ± bottom friction over the long fetch. NOT yet isolated.

## NEXT STEP (awaiting operator go — asked, not yet answered)
Run **controlled L1 isolation tests** (toggle friction / whitecapping / wind one at a time) to
identify the exact term draining the swell. This is a **physics/settings change → operator sign-off
required** before any permanent change. Investigation is read-only; the FIX is not.

## What's DONE this session (all evidence-stamped in the plan)
- **R8 (test audit)** ✅ DONE, PUSHED. Commits `5874578`→`99f2378`→`cb0fe57`→`14b769f`. Suite is
  essentially clean (zero own-assertion stale tests); removed one dead-E1 KAT, kept the live
  `tip_depth_from_fine_profile` guards. Operator waived pytest re-verify. `TEST-INVENTORY.md` in
  marine repo `docs/planning/briefs/`.
- **R1 (bisect)** ✅ RAN — **PREMISE REFUTED.** `f337648` (pre-cliff) is ALSO swell-starved →
  starvation is chronic, older than the `4828d99` cliff. Contradicts R-DIAGNOSIS root-regression #1
  and the len_deg exoneration. Evidence: `librewxr:/tmp/r1-f337648-run/`.
- **R5 (BOUNDSPEC [len] degrees→meters)** ✅ CODE DONE + DEPLOYED (`5581b0a`). Confirmed live (S=37975 m,
  W=646/9517/13952 m; west 3-station mangling fixed). Did NOT fix the swell (as predicted — single-
  spectrum south side). Correct defect fix, not the swell cause.
- **Trace-logging fix** ✅ CODE DONE, ACCEPTED, **NOT PUSHED** (commit `67911d2`, local marine repo).
  Root cause: `_trace_nest_handoff` parsed NESTOUT with the SPECOUT parser; only mismatch was
  `RFREQ` vs `AFREQ` keyword; bare `except: return` hid it → handoff logging emitted ZERO records.
  Fixed: RFREQ alias + silent-swallow→WARNING + per-band `hs_m` accuracy (band `energy` omits
  `dtheta`; use new `hs_m`, or multiply energy by dtheta=360/ndir). KAT + fixture added. 10 tests pass.

## Current system state (VERIFIED 2026-08-01)
- **librewxr:** service **STOPPED** (inactive), deployed commit **`5581b0a`** (R5). Persisted geometry
  on disk is R5's 217° recompute. R5-run workdirs + nest_out samples preserved at `/tmp/r5-run/`.
- **Marine repo (local `c:\CODE\...\repos\weewx-clearskies-marine`):** HEAD `67911d2`, origin/main
  `5581b0a` → **`67911d2` (trace-fix) is UNPUSHED**. Untracked `test_claim2.py` at root = old scratch,
  operator said ignore (do NOT commit/delete it).
- **Meta repo:** plan + this brief edits (commit them).

## Open items / pending decisions
1. **Operator go** on the L1 physics isolation tests (the swell-fix path). Fix = sign-off territory.
2. **Push + deploy** the trace-fix `67911d2` (operator granted standing push/deploy for testing) — do
   this with the next diagnostic run so the permanent handoff logging is verified live.
3. **L3→L4 handoff logging gap** (agent finding): `swan_runner.py:~4255-4268` (run_3level per-cluster
   L4 loop) copies L3-NESTOUT→L4 with NO `_trace_nest_handoff` call — a genuine untraced production
   handoff. Also legacy `run_stationary_inner` (~3072-3103) untraced (likely dead path — verify). Add
   the L3→L4 trace call to fully satisfy "log ALL handoffs" (touches runner control flow — scope it tight).
4. **R2/R3/R4/R6/R7/R9/R10** all still ⬜ NOT STARTED. R7 is architectural (designs → operator sign-off).

## Diagnostic tools created this session (local `c:\tmp\`, also scp'd to librewxr `/tmp/`)
- `spec_probe.py` — Hs/swell/peak from a single SWAN SPECOUT/boundary text spectrum.
- `swell_trace2.py` — valid-time-aligned swell trace from the B1 log (`spec_l1_boundary` vs
  `spec_l2_dwr`). **Note the dtheta fix:** band swell Hs = `4*sqrt((e_long+e_mid)*360/ndir)`.
- `nestout_probe.py` — parses NESTOUT `nest_out.dat` (multi-location, RFREQ/NDIR/VaDens) for per-
  handoff swell. Used to trace L1→L2 / L2→L3.
- Trace stages in the B1 log: `spec_ww3_raw`, `spec_l1_boundary`, `spec_l2_dwr`, `spec_l4_handoff`,
  `swan_sample`, `handoff_selection`/`resolution`, `profile_to_1d`, `swelltrack`. (nestout stages
  `spec_l1_nestout`/`spec_l2_nestout` will now fire once `67911d2` is deployed.)

## Non-negotiables (the mess this phase exists to end)
- No architectural change without operator approval in chat. No push without the word "push"
  (operator gave standing push/deploy for testing this session — confirm it still holds next session).
- A fired guard / silent-failure is a gate event: surface it, never continue past silently. (The
  trace bug WAS a silent swallow — exact shape this phase targets.)
- Numbers carry their command/artifact. Reality-gate every marine deploy (model vs NDBC/Surfline).
- One functional change per deploy during recovery.
