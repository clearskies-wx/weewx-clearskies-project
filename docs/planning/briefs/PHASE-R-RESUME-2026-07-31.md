# Phase R resume prompt — coordinator session (Opus)

**Written 2026-07-31 by the Fable diagnosis session. Paste this as the opening prompt of the next
coordinator session.** Rules and profiles were updated this date — a session started before then
must restart so the new profiles load.

---

You are the coordinator for the Clear Skies marine model. This session works **Phase R of
`docs/planning/MARINE-MODEL-RESTORATION-PLAN.md` and nothing else**. The geometry plan
(`MARINE-GEOMETRY-MODEL-PLAN.md`) is SUSPENDED — do not execute any G-phase task.

## Read in this order before doing anything

1. `rules/coordinator.md`, `rules/agents.md`, `rules/verification.md` — updated 2026-07-31 with
   the reality gate, publish-liveness, deploy discipline (§7), evidence hygiene, and the
   stale-test mandatory prompt block. These bind every action this session.
2. `MARINE-MODEL-RESTORATION-PLAN.md` → **PHASE R** (end of file). The R-DIAGNOSIS table is the
   factual record of the 2026-07-31 collapse, measured from primary artifacts — not from prior
   session reports.
3. `MARINE-GEOMETRY-MODEL-CONCERNS.md` → TC-21 and TC-23 **including their CORRECTION blocks**.
   Prior sessions' claims — "the L4 grid is 35% dry land", "the regression window is G3∪G4" —
   are FALSE and corrected there with measurements. Do not resurrect them.
4. `docs/planning/briefs/STUDY-AREA-GEOMETRY-BRIEF.md` §3.1 (the FIXED table) — the design of
   record for handoff/geometry, including the L4→L3→L2 handoff ladder and the 1.78 m
   shoreward-reach rationale.

## Facts you do not re-litigate (all measured; evidence cited in the R-DIAGNOSIS table)

- The model last published at 07:00Z Jul 31. The cliff is the 11:13Z deploy of `4828d99`.
- The L4 grid is **100% wet**. All 96 handoff stations are **wet but OUTSIDE the grid**, 4–56 m
  shoreward of its frozen shoreward edge.
- The WW3 boundary files carry the real swell (13.6 s @ 185°, matching Surfline); the model's
  15 m reference does not. The loss is inside L1/L2 boundary application — task R2 pins the line.
- G3, G4, and the `len_deg` defect are **exonerated as the trigger** (R5 still fixes `len_deg`
  as a latent defect). Spend no cycles re-investigating them beyond their named tasks.
- The marine service on librewxr is **deliberately stopped**. Start it only as part of an R-task
  run, and stop it again after, until Gate R row 1 passes.
- The operator's architecture ruling (TC-23 correction, verbatim): L4 models
  refraction/diffraction around the obstacle; it is NEVER the sole handoff; an open beach has no
  L3/L4; a transect that does not intersect L4 continues to L2.

## What to do first

1. **Ask the operator for "go" on R1** (the `f337648` bisect-confirmation run). Do not assume it.
2. **While waiting, dispatch R8** (test audit — docs/tests lane, no deploys). Its deliverable,
   `TEST-INVENTORY.md`, is an operator ask in its own right.
3. Then **R2 → R3 → R4**, strictly **one functional change per deploy**, every deploy closed with
   the reality-gate + publish-liveness evidence PASTED (`rules/verification.md` → "Marine deploy
   verification"). Fold the continuous reality invariant and `last_publish_age_s` health field
   into R4's dispatch; the NOMADS backoff into R6.
4. **R7 is architectural**: write the three designs, bring them to the operator for sign-off,
   implement nothing until each is approved.

## Non-negotiables (the mess this phase exists to end)

- Every implementation agent prompt carries the git block, the architectural block, AND the
  stale-test block from `rules/agents.md` — verbatim, all three, every prompt.
- **A fired guard, invariant, or viability check is a gate event**: paste it, surface it to the
  operator, never continue past it silently. (On Jul 31 the L3 viability guard caught the frame
  break at 11:16 and the session continued past it; the model never published again.)
- **Numbers carry their command.** Nothing enters a gate record, a concerns entry, or an operator
  report without the command + artifact that produced it.
- Never code back to a stale test; never accept an agent report that did.
- **Baseline capture** before replacing anything that works: facing, DWR partitions,
  valid_fraction, station-band depths, grid-sizing log lines — recorded before, diffed after.
- No push without the operator's word "push". No architectural change without operator approval
  in chat. Both rules are unchanged and fully in force.

## Evidence locations (for verification, not re-derivation)

- Preserved failed L4 workdir: librewxr `/tmp/g1r-gate-level4_0-failed/` (INPUT, BOTTOM.txt,
  POINTS_1_*, TABLE_PT_1_*, PRINT).
- Last run's level workdirs: librewxr `/var/run/weewx-clearskies/swan/level{1,2,3_0,4_0}/`.
- B1 trace: librewxr `/var/log/weewx-clearskies/marine-trace-2026073*.jsonl` (the 07:00Z Jul 31
  `published` records are the last-working evidence).
- Diagnostic scripts from the Fable session: librewxr `/tmp/l4_diag.py` (grid/station wetness +
  grid-frame positions), `/tmp/spec_hs.py`, `/tmp/spec_content.py` (boundary-file spectral content).
- Operator-facing map of the grid/station geometry (failed run):
  https://claude.ai/code/artifact/d86974d6-d289-410d-9a4c-34ac070146ba
