# Session prompt — resume Marine Service Separation Phase 4/4A

**Updated:** 2026-07-25, after the L3/1D boundary decisions landed (`5f4f7b6`).

Copy everything below the line into a new session.

---

You are the coordinator (Opus) resuming execution of Phase 4A of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`. Phase 4 is complete and closed;
do not re-open it.

**Read these first, in this order, before doing anything or dispatching anyone:**

1. `CLAUDE.md` and the domain files it routes to — at minimum
   `rules/clearskies-process.md`, `rules/coding.md`, `reference/clearskies-dev.md`.
2. `docs/ARCHITECTURE.md` — the SWAN/SwellTrack paragraph (~line 98) was rewritten
   2026-07-25 and is current.
3. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` **Amendment 2** and
   `docs/decisions/ADR-095-swan-model-corrections.md` **Amendment 2**. These are the
   authoritative L3/1D boundary decisions. Read them before touching any grid,
   handoff, or SPECOUT code.
4. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — Phase 4A's intro block, then
   T4A.3 and T4A.9 through T4A.13 in full.
5. `c:\tmp\marine-sep-P4A-scratch.md` — the decision record. Read the **SESSION
   HANDOFF** section at the bottom: stop event, a coordinator error the operator
   corrected, the lead-call index, and verified facts you should not re-derive.
6. `c:\tmp\marine-sep-P4-scratch.md` — Phase 4's record, including QC Gate 4 closure
   and the adversarial audit's 5 findings.

Optional, and only if you need the reasoning behind a boundary decision rather than
the decision itself: `docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md`. It
records several **discarded** approaches alongside the adopted one. Read the
superseding box at the top of D2 first or you will pick up a withdrawn answer.

## What changed since the last session

The L3/1D cross-shore boundary questions are **settled**. Do not re-derive them, do
not re-litigate them, and do not let an agent "improve" on them.

The finding: the 1D-model introduction changed L3's *alongshore* extent and made L3
*optional*, but never changed its *cross-shore* extent. L3 kept the pre-1D geometry
— offshore edge at the 15 m contour, shoreward edge at the shoreline — long after
SWAN stopped being the model that runs to the beach.

Decided:

- **L3 does not run to shore.** Grid frozen at setup; the cell the handoff spectrum
  is read from moves per forecast hour at `1.3 * Hs(hour) / gamma`, gamma = 0.73.
- **Do not freeze the handoff at `1.3 * max_hs_m / gamma`.** That is the year's
  largest swell applied to every hour. An earlier revision of these documents said
  exactly that and it was wrong — it sits far seaward of anything breaking on an
  ordinary day and shrinks L3 below the size needed to reach its own structures.
- **L3 enables on a discovered structure OR the operator's point/headland/bay
  classification.** Structure-only could never enable L3 at a point break.
- **Setup-time viability test.** If the grid cannot reach the feature it exists for,
  L3 is disabled — and must log what was unreachable and by how much.
- **Setup calculation is depth-based only.** No contour curvature, orientation
  variation, or automatic break-type detection.
- **L3's offshore edge stays at the 15 m contour.**
- **Supplement 4's topographic multipliers are removed** — they double-count
  refraction L2 has computed since nesting landed.
- **No SPECOUT may be extracted at an L3 boundary cell.**

Consequences for the task list:

- **T4A.3 is unblocked.** Its L3 sizing steps were rewritten to match.
- **T4A.3.0 is scope-reduced and no longer gates T4A.3.** What remains: the
  intended-vs-actual diff for SWAN-side changes not already covered (CURVE role,
  SurfBeat strip domain, per-level bathymetry), plus the inventory of
  governing-document statements still describing the pre-1D design.
- **Five new tasks: T4A.9–T4A.13** — per-hour handoff selection, the runtime
  breaking-zone assertion, the trigger and viability test, Supplement 4 removal, and
  superseded banners on two research briefs.

## Open questions for the operator

**None outstanding as of 2026-07-25.** You may begin work. If you find yourself about to
re-raise something below, read the recorded reasoning first.

**Resolved 2026-07-25 — do not re-raise:**

- **The uncommitted T4A.3 work — reviewed and committed** (`244ee08`, API repo, +541/−9:
  `services/swan_domain.py`, `enrichment/bathymetry.py`). It adds staged sizing entry
  points so L1 → coarse download → 30 m contour → L2 → medium download → 15 m contour →
  L3 runs in the right order without any grid being resized after computation; sizes L2
  from the real 30 m contour instead of a hardcoded 6 km; and makes both estimate
  fallbacks log that they are estimates.

  **Correction on the record:** an earlier version of this prompt stated that part of
  `swan_domain.py` implemented a retracted instruction and "must not survive review."
  **That was wrong and was repeated without opening the file.** The code pins L3's
  *offshore* edge to each spot's own depth contour, fixing an observed defect where a
  live run silently clipped one spot's transect from 2440 m to 950 m. The retracted
  instruction concerned a different edge. See the verification rule added to
  `rules/clearskies-process.md` — a claim that code is dead needs *more* checking than a
  claim that it is fine.

  **Known gap:** it sizes L3's offshore edge only. T4A.9/T4A.11 must extend it to the
  shoreward edge per ADR-093 Amendment 2. They extend it; they do not replace it.

  **Left uncommitted deliberately, for separate review:** a one-line field removal in
  `providers/alerts/nws.py` (`ends: str | None = None`) with no explanation and no
  connection to this task, and an untracked `services/surfbeat_strip_benchmark.py`.

- **T4A.7 — approved, with a verification gate.** Read the banner at the top of the task.
  By 2026-07-25 it is no longer a live-component deletion: supplement #2 went with
  ADR-095, #4 is operator-approved and split to T4A.12, #1 is a branch that has never
  executed. **#3 is the only real decision, and it is gated** — confirm the handoff
  spectrum is emitted at requested coordinates rather than cell centres before removing
  it. If SWAN does not interpolate to the requested point, #3 stays. Run T4A.12 first.

- **LC-22** (Battjes-Janssen breaking-fraction term moved from an approximation to an
  iterative solve). Operator approved 2026-07-25 and ruled it **not architectural** —
  same equation, different arithmetic. SWAN's own source solves it the same way
  (Newton-Raphson, `swancom2.for`), so this aligns SwellTrack with the model it is
  benchmarked against. **One review item remains:** confirm the solve clamps as the
  breaking fraction approaches 1, where the logarithm runs away. Fold into whichever task
  touches `surf_1d_analytical.py`.

- **T4A.6 and T4A.8** — keep both. T4A.6 gained item (g) on 2026-07-25.

- **Coordinator latitude** — settled. The trigger list, the architecture-vs-methodology
  table now in `CLAUDE.md`, and the coordinator self-check in
  `rules/clearskies-process.md` are the standard. Note especially that **size of change
  is not the signal**: a 500-line bug fix can be pure methodology, and a one-character
  coefficient edit is architectural.

## Deferred by operator direction, with a reason — do not assign an owner yet

**The `nan_count=1061` L3 convergence failure.** Deferred until Phase 4A's L3 changes are
implemented, because **the work may remove the cause.** Both recorded L3 divergences
occurred at breaking: SWAN-L3-STABILITY-BRIEF §1 records the field staying finite for ~14
simulated hours and going NaN "at the hour the 3.5 ft SSW swell arrived and surf-zone
breaking began." L3 was unstable because it contained the surf zone. Under ADR-093
Amendment 2 it no longer does — it stops seaward of breaking by construction.

Re-measure after T4A.9/T4A.11 land. If failures persist in an L3 that never contains
breaking, that is a genuinely different problem and gets an owner then. Do not chase it
before the boundary work is in. The same applies to the 18Z-cycle correlation below.

## Ordering suggestion, for the operator to confirm

T4A.9 and T4A.11 are the load-bearing ones — everything else in the new group either
guards them (T4A.10) or is independent cleanup (T4A.12, T4A.13). T4A.12 and T4A.13
can run in parallel with anything.

## Operating constraints you must honour

- The plan's **NO DEFERRAL RULE** applies. It exists because of exactly the
  half-implementation this phase is remediating.
- **The architectural change block is in force.** Every implementation agent prompt
  carries it verbatim (`rules/clearskies-process.md`, "Architectural change block —
  mandatory agent prompt section"), plus the git-restrictions block and an explicit
  scope block. Run your own instructions against the 7 triggers before sending them —
  the 2026-07-25 L3 grid-resize error was a coordinator *instruction*, not agent
  initiative.
- Agents commit locally only. Never push, never edit files on any container, never
  use worktree isolation.
- Multiple agents in one repo stage only their own named paths — never `git add -A`.
- Independently verify every agent claim. Past sessions caught a "zero hits" claim
  that was substantively right but literally wrong, an audit that would have been
  Windows-only, and a coordinator reference table an agent correctly proved wrong.
- Round briefs go in `docs/planning/briefs/`. Append to scratch files continuously,
  not retroactively.
- **Plain English, and keep technical terms to roughly one per sentence**
  (`rules/clearskies-process.md`, Communication rules). Defining a term is not enough
  — four defined terms in one sentence still fails to communicate.

## Two traps specific to the new work

**T4A.9 must not touch grid geometry.** The handoff moving per hour is a *lookup*.
`compute_domains()` output must be byte-identical across a forecast cycle. In July an
agent that could not get structures into `compute_domains()` added a runtime grid
override instead of fixing the caller; the result was 0.01 m wave heights during a
6–8 ft swell, with a valid HTTP 200. A per-hour handoff sits close enough to that
mistake to warrant an explicit test.

**T4A.10 exists because the per-hour handoff creates a new silent-failure path.** If
the hourly depth is computed wrong, the sampled cell sits in breaking water, SWAN's
wave height there is already dissipated, and the output looks like an ordinary small
day. Same shape as the July incident. The assertion is not optional polish.

## Deployment state

- Meta repo `main` at `5f4f7b6` (the boundary decisions), **not pushed**.
- Local API repo `main` at `11b5242`, **not pushed**. weewx runs `0d87b28`.
- Local dashboard `main` at `20c6e50`, **not pushed**.
- librewxr API repo at `bfff1f7`; SWAN and compute services active.
- `weewx-clearskies-marine` complete, pushed, private on GitHub at `9ab0766` + the
  audit-fix commit; cloned on weather-dev for verification.

Verify each of these yourself before dispatching anyone — this list is a snapshot and
may be stale.

## Live production reality

SWAN on librewxr is **working** — 10 successful runs and 3 convergence failures over
5 days, most recent run (2026-07-25 01:40) successful. The empty surf page is caused
by the broken 50-point spot profile starving SwellTrack, which T4A.2 fixed and T4A.5
deploys.

A previous coordinator claimed SWAN was "discarding every run" and called that the
root cause. That was wrong — extrapolated from a single log line. Do not repeat it.

**Tracked, not a blocker:** all 3 convergence failures fell on the 18Z HRRR cycle (0
on 00Z/06Z/12Z). Suggestive at 3 data points. The operator's direction is explicit —
**finish implementing the model first**; the 18Z pattern is chased after Phase 4A
closes.
