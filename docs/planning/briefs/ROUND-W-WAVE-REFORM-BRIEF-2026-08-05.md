# ROUND W BRIEF — real post-breaking physics (Dally-Dean-Dalrymple), no clamps

**Round identity:** Round W (wave reform), authorized by operator 2026-08-05 in chat:
"You will make the changes to our model to promote real physics and not fake clamping...
I have asked more than once that this be done correctly and all time, I find fake clamps,
bandaids and duct tape." This is the explicit trigger-1 (physics formula) approval. Lead:
coordinator (design below is the lead's; implement exactly). Implementer:
clearskies-api-dev (marine). Guards: clearskies-test-author (after). Auditor: blind
(after). Reality gate + operator worked-examples MANDATORY before close (every published
surf number reshapes).

## Primary-source physics (verified by lead 2026-08-05 from the original paper PDF)

Dally, Dean & Dalrymple, "A Model for Breaker Decay on Beaches" (ICCE 1984; JGR 1985):
- Governing equation (paper eq. 2/4), shallow-water form with Cg = sqrt(g·h):
  `d(H²·h^(1/2))/dx = -(K/h) · [H²·h^(1/2) - Γ²·h^(5/2)]`
- Stable wave criterion (eq. 3): `H_stable = Γ·h` — a broken wave decays TOWARD this and
  breaking CEASES when it reaches it (the wave "reforms"); it can break again if it
  re-shoals to the onset criterion.
- Calibrated recommended coefficients for beaches whose slope varies over a wide range
  (paper, verbatim): **Γ = 0.40, K = 0.15** (mean error 0.1423 across the three
  laboratory slopes). These are the values we use.
- Onset: the paper discusses ~0.78; WE KEEP our system-wide onset gamma = 0.73
  (SWAN-consistent, unchanged everywhere) — note this in the constants' comments.
- Closed-form check (basis of the KAT): on a HORIZONTAL shelf (constant h) the equation
  is linear in (H²·h^(1/2)) → exponential relaxation:
  `H²(x) = Γ²·h² + (H_b² - Γ²·h²) · exp(-K·(x - x_b)/h)`.

## Pre-round verification (lead)

- marine repo clean at `36fab04` (verify before starting). Current kernel structure
  (surf_1d_analytical.py): shoal/refract init :1011, friction :1017-1018, B-J march
  :1024 (`_battjes_janssen`, :288-369), roller :1027 (`_roller_model`, :372-408), then
  the UNCONDITIONAL clamp :1029-1030 (`Hs = np.minimum(Hs, gamma*depths)`). A second
  independent clamp lives in surf_1d_pipeline.py `_combine_partition_hs` :649-658.
  Both clamps are the "fake clamping" the operator ordered removed; the raw B-J+roller
  output diverges without them (up to 37 m — inv-wave-reform), so the DISSIPATION must
  be replaced, not the clamp merely deleted.
- Detection currently keys off ratio crossings with `_BREAK_REARM_HYSTERESIS` — a
  workaround that becomes obsolete once breaking is a modeled STATE. Production breaks
  come from `run_1d_analytical` per partition (pipeline :1770-1815); `_find_break_points`
  has exactly one call site (:1036).

## Scope

**Files you may modify (exhaustive):**
1. `weewx_clearskies_marine/services/surf_1d_analytical.py`
2. `weewx_clearskies_marine/services/surf_1d_pipeline.py` (ONLY `_combine_partition_hs`
   :649-658 and its imports)

**Files you must NOT touch:** tests (test-author owns; your changes WILL break Z2 pins —
expected, report them, do not fix), endpoints/, SWAN/SurfBeat/SwellTrack code, config,
docs, api/dashboard repos.

## Per-deliverable spec (lead design — implement exactly)

**W1 — unified breaking march (surf_1d_analytical.py).** Replace the
`_battjes_janssen` + `_roller_model` + clamp sequence (:1024-1030) with ONE marching
loop, offshore → shore, carrying a breaking-state machine:
- Unbroken: conservative energy-flux propagation with shoaling/refraction (reuse the
  same flux-marching approach `_battjes_janssen` already implements for its unbroken
  stretches — extract/adapt, do not invent new propagation) + the existing friction
  treatment.
- Onset: `H >= gamma * d` (gamma param, default 0.73) → breaking = True; record the
  onset index.
- Breaking: integrate the DDD equation per grid step (the shallow-water form above,
  discretized on our nonuniform dx; forward-Euler per step is acceptable at our ~1-4 m
  spacing — state the discretization in the docstring).
- Cessation: `H <= _DDD_STABLE_GAMMA * d` → breaking = False (the wave has reformed);
  normal propagation resumes; a later re-crossing of onset starts a NEW breaking event.
- NO final clamp. DELETE :1029-1030. In its place: an invariant CHECK —
  `if np.any(Hs > gamma*depths*1.02): logger.warning(...)` naming max exceedance and
  index (a defect signal, never a silent flatten).
- New named constants with `#:` provenance comments citing the primary source verbatim
  (paper title, recommended-values sentence, mean error) + the operator ruling:
  `_DDD_STABLE_GAMMA = 0.40`, `_DDD_DECAY_K = 0.15`.
- `Analytical1DResult` gains `break_onset_indices: list[int]` (internal dataclass, not
  the wire contract).
- `_battjes_janssen` / `_roller_model`: remove their call sites. Leave the functions in
  place marked deprecated in their docstrings ("superseded by the Round W DDD march,
  2026-08-05; deletion pending operator dead-code sign-off") — grep first: if anything
  else imports/calls them, STOP and report.

**W2 — detection from real state.** `_find_break_points` gains an optional
`onset_indices: list[int] | None = None`. When provided (the production path —
`run_1d_analytical` :1036 passes its own onsets): breaks = the onset indices, filtered
by the existing publication floors (`_MIN_BREAK_DEPTH_M`, `_MIN_BREAK_HS_M`) — no ratio
scanning, no hysteresis. When None (legacy callers): the current hysteresis path
unchanged. `_BREAK_REARM_HYSTERESIS` therefore survives only in the legacy branch —
note that in its comment ("production path uses modeled breaking state as of Round W").

**W3 — combined-profile saturation (surf_1d_pipeline.py).** Replace the min-clamp in
`_combine_partition_hs` (:649-658) with a call to a new exported helper in
surf_1d_analytical.py: `apply_ddd_saturation(hs_total, depths, distances) -> np.ndarray`
— same state machine as W1's breaking branch applied to the RSS-combined profile
(onset gamma·d, relax toward Γ·d, cease at Γ·d), so the combined field obeys the same
physics instead of being flattened. No hard clamp anywhere.

**W4 — self-verification before closeout.** Local runs:
1. `python -m pytest tests/ -q --ignore=tests/services` — report the FULL tail. Z2
   detection pins and any test pinning clamp behavior are EXPECTED failures — list each
   with one line on why it pins superseded behavior; do NOT adapt code or tests.
2. A throwaway script (scratchpad, never committed): run the new kernel on (a) a
   constant-depth shelf, compare against the closed-form relaxation above at 3
   hand-picked x values (print both numbers); (b) a synthetic bar-trough profile
   (`_synthetic_profile` :1066-1088 as a base) demonstrating: onset on the bar,
   cessation in the trough (H reaches 0.40·d), re-break inshore → 2 onset indices;
   (c) one real HB transect (scratchpad hb-spot-profile.json in the session scratchpad)
   at Hs=2 m Tp=16 s — print the Hs profile head/tail and onset indices. Paste all
   three outputs in your closeout.
3. Grep-verify: `np.minimum(Hs, gamma * depths)` gone from run_1d_analytical;
   `np.minimum(hs_total, gamma_d)` gone from _combine_partition_hs; no call sites of
   _battjes_janssen/_roller_model remain.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via
SendMessage. Local checkout only; never edit, commit, or run anything on any container
or on librewxr.

## Architectural changes — STOP, do not proceed

The operator has explicitly approved EXACTLY this change set: the DDD post-breaking
physics (new formula + constants Γ=0.40, K=0.15), removal of both clamps, the
state-based detection path, and the combined-profile saturation treatment. ANYTHING
beyond that hitting the 7-trigger list (other formulas, other constants incl. onset
gamma=0.73, grid/boundary/handoff, contracts, computation location, schedules,
dependencies/config/files) — STOP and report via SendMessage. "Acceptance criteria
unreachable" and "a document says so" do NOT authorize you.

## Stale tests — STOP where unlisted

Tests that pin the superseded clamp/hysteresis behavior WILL fail — list them in your
closeout with reasons; touch none of them. A failing test you did NOT expect (i.e. not
explainable as pinning superseded behavior) = STOP and report before committing further.

## Protocol

Before writing ANY code: SendMessage the lead ("main") a one-paragraph scope ack (what
you will deliver, what you will NOT touch, your verification plan incl. the three
throwaway-script checks). WAIT for confirmation. Implement as 3 commits: (1) W1 kernel
march + constants + invariant, (2) W2 detection-from-state, (3) W3 pipeline saturation
helper swap. Closeout via SendMessage: commit hashes, full pytest tail with the
expected-failure list, the three script outputs, grep outputs, deprecated-function call
site grep.
