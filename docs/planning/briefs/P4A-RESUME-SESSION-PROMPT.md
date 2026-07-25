# Session prompt — resume Marine Service Separation Phase 4A

Copy everything below the line into a new session.

---

You are the coordinator (Opus) resuming execution of Phase 4A of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`. Phase 4 is complete and
closed; do not re-open it.

**Read these first, in this order, before doing anything or dispatching anyone:**

1. `CLAUDE.md` and the domain files it routes to — at minimum
   `rules/clearskies-process.md`, `rules/coding.md`,
   `reference/clearskies-dev.md`.
2. `docs/ARCHITECTURE.md`.
3. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — the **CURRENT STATUS**
   block near the top is the handoff summary. Then read **T4A.3.0** and
   **T4A.3** in full.
4. `c:\tmp\marine-sep-P4A-scratch.md` — the full decision record. Read the
   **SESSION HANDOFF** section at the bottom in full: it contains the stop
   event, a coordinator error the operator corrected, the operator's
   architectural correction, the lead-call index, the open questions, and a list
   of verified facts you should not waste tokens re-deriving.
5. `c:\tmp\marine-sep-P4-scratch.md` — Phase 4's record, including QC Gate 4
   closure and the adversarial audit's 5 findings.

**Do not start work until the operator answers the open questions** listed at the
bottom of `marine-sep-P4A-scratch.md`. Put them to the operator in plain text in
your first reply. Summarised:

1. **The uncommitted T4A.3 work** — the API repo has ~460 uncommitted lines in
   `enrichment/bathymetry.py` (+264) and `services/swan_domain.py` (+204) from a
   halted agent. Zero commits were made. Keep, stash, or discard? Note that part
   of `swan_domain.py`'s addition (around lines 733, 750, 870) implements a
   **retracted** coordinator instruction requiring L3 to contain the full
   transect — that logic is wrong and should not survive review.
2. **LC-22** — the previous coordinator authorised replacing the Battjes-Janssen
   `Qb` formula with the exact implicit relation. It is committed and tested.
   Review, keep, or revert?
3. **T4A.6, T4A.7, T4A.8** — three tasks the previous coordinator added to the
   plan. Keep or strike?
4. **Coordinator latitude** — how much should you decide versus bring to the
   operator? The previous coordinator over-reached; the operator flagged it.
5. **The L3 target model** — this blocks T4A.3 and T4A.3.0 exists to inform it.
6. **The `nan_count=1061` L3 convergence failure** — assigned to no task. Needs
   an owner.

**The one thing that is unambiguously next** is **T4A.3.0**: a research-only task
that reconstructs what the 1D-model introduction was supposed to change on the
SWAN side versus what was actually coded. The operator's finding is that the 1D
rollout was **half-implemented** — the 1D models were built, but L3 extent, L3
conditionality and the governing documents still describe the pre-1D
architecture. `ARCHITECTURE.md` lines 98 and 114 contradict each other on this,
as do `SURF-ZONE-MODEL-BRIEF.md` lines 371 and 578. T4A.3.0 modifies **zero**
source files; it produces an intended-vs-actual diff and surfaces the open
architectural questions for the operator to decide.

Do not resume T4A.3's implementation until the operator has ruled on the target
L3 model.

**Operating constraints you must honour:**

- The plan's **NO DEFERRAL RULE** applies. It exists because of exactly the
  half-implementation this phase is now remediating.
- Every implementation agent prompt carries the git-restrictions block and an
  explicit scope block (`rules/clearskies-process.md`). Agents commit locally
  only; they never push, never edit files on any container.
- Multiple agents in one repo must stage only their own named paths — never
  `git add -A`. Two agents ran concurrently in the API repo last session without
  incident because of this.
- Independently verify every agent claim. Last session this caught a "zero hits"
  claim that was substantively right but literally wrong, an audit that would
  have been Windows-only until redirected to Linux, and a coordinator reference
  table that an agent correctly proved wrong.
- Round briefs go in `docs/planning/briefs/`. Append to the scratch files
  continuously, not retroactively.

**Deployment state — nothing was deployed last session:**

- Local API repo `main` at `11b5242`, **not pushed**. weewx runs `0d87b28`.
- Local dashboard `main` at `20c6e50`, **not pushed**.
- librewxr API repo at `bfff1f7`; SWAN and compute services active.
- `weewx-clearskies-marine` is complete, pushed, **private** on GitHub at
  `9ab0766` + the audit-fix commit; cloned on weather-dev for verification.

**Live production reality:** SWAN on librewxr is **working** — 10 successful runs
and 3 convergence failures over 5 days, most recent run (2026-07-25 01:40)
successful. The empty surf page is caused by the broken 50-point spot profile
starving SwellTrack, which T4A.2 fixed and T4A.5 deploys.

A previous coordinator claimed SWAN was "discarding every run" and called that
the root cause. That was wrong — extrapolated from one log line. Do not repeat
it. The correction, and the real numbers, are in the plan's status block.

**Tracked, not a blocker:** all 3 convergence failures fell on the 18Z HRRR
cycle (0 failures on 00Z/06Z/12Z). Suggestive at 3 data points. The operator's
direction is explicit — **finish implementing the model first**; the 18Z pattern
is chased after Phase 4A closes.
