# ROUND W GUARDS BRIEF — tests for the DDD breaking physics

**Identity:** test-author round for Round W (operator-approved 2026-08-05: Dally-Dean-
Dalrymple post-breaking physics replacing the B-J + roller + clamp sequence). Lead:
coordinator. You: clearskies-test-author. Repo: `repos/weewx-clearskies-marine`, local
checkout, main at `c09a78c` (W1 `e048494`, W2 `71f6bff`, W3 `c09a78c` on top of
`36fab04`). Verify that hash before starting; if the repo is not at `c09a78c`, STOP and
report via SendMessage.

## What Round W changed (read the code, not just this summary)

`weewx_clearskies_marine/services/surf_1d_analytical.py`:
- New `_ddd_breaking_march(Hs_in, d, gamma, dx, Cg, Kr) -> (Hs_out, onset_indices)` —
  offshore→shore state machine: UNBROKEN = conservative flux march with refraction
  ratio; ONSET at `H >= gamma*d` (gamma = 0.73, unchanged); BREAKING = forward-Euler
  integration of `d(H²·h^½)/dx = −(K/h)·[H²·h^½ − Γ²·h^(5/2)]` in the state variable
  `y = H²·h^½`, derivative at the trailing point; CESSATION at `H <= Γ*d` (reform),
  after which flux marching resumes from the reformed height and a later onset
  re-crossing records a NEW onset index.
- New constants `_DDD_STABLE_GAMMA = 0.40`, `_DDD_DECAY_K = 0.15` (primary source:
  Dally, Dean & Dalrymple 1985, recommended values, mean error 0.1423).
- The unconditional `Hs = np.minimum(Hs, gamma * depths)` clamp is GONE; in its place
  an invariant `logger.warning` fires if `np.any(Hs > gamma*depths*1.02)`.
- `_find_break_points(..., onset_indices=None)`: when onset_indices is provided
  (production path), breaks = those indices filtered by `_MIN_BREAK_DEPTH_M` /
  `_MIN_BREAK_HS_M` — no ratio scan, no hysteresis. When None, the legacy
  hysteresis path is byte-unchanged.
- `Analytical1DResult.break_onset_indices: list[int]` (internal, not wire contract).
- `_battjes_janssen` / `_roller_model` deprecated, zero call sites.
- New exported `apply_ddd_saturation(hs_total, depths, distances, gamma=0.73)` —
  the same state machine applied to an RSS-combined profile (UNBROKEN = pass-through
  of the input, BREAKING = same forward-Euler DDD step, CESSATION = resume
  pass-through).

`weewx_clearskies_marine/services/surf_1d_pipeline.py`:
- `_combine_partition_hs(partition_profiles, depths, gamma, distances)` — min-clamp
  replaced by `apply_ddd_saturation`; the per-partition redistribution ratio is now
  `hs_total / hs_total_raw` (can exceed 1 where the DDD relaxation sits ABOVE the raw
  RSS profile — this is intentional carry-over of proportional redistribution, note it
  in your test comments, do not "fix" it).

## Deliverables

**T-W1 — closed-form shelf KAT (known-answer test).** On a horizontal shelf (constant
depth h) the DDD equation reduces to exponential relaxation:
`H²(x) = Γ²·h² + (H_b² − Γ²·h²)·exp(−K·(x − x_b)/h)`.
Build a constant-depth grid, feed a boundary Hs above gamma*d so breaking starts at
index 0, run `_ddd_breaking_march`, and compare against HAND-COMPUTED literal values of
the closed form at ≥3 interior x positions. The literals must appear in the test as
plain numbers with the arithmetic shown in comments (known-answer mandate,
rules/verification.md) — not recomputed by the test from the same formula via numpy
convenience. Tolerance: justify from forward-Euler truncation at your chosen dx (keep
dx small enough that ≤1% relative passes honestly; state the bound you derived).

**T-W2 — bar-trough double-onset guard.** Synthetic bar-trough profile (adapt
`_synthetic_profile` or hand-build one): shallow bar → deeper trough → shore. Assert:
(a) exactly 2 entries in `break_onset_indices`; (b) the first onset is on the bar, the
second inshore of the trough (assert by index position relative to your profile's
known geometry); (c) between cessation and second onset there is at least one point
where `Hs < gamma*d*(1 − margin)` — the wave genuinely backed off (pick and state the
margin from your profile's numbers).

**T-W3 — constant pins.** Pin `_DDD_STABLE_GAMMA == 0.40` and `_DDD_DECAY_K == 0.15`
with a comment citing the paper's recommended-values sentence and the operator ruling
date. Also pin that onset gamma default is still 0.73 wherever it is declared.

**T-W4 — invariant-warning test.** The invariant (`Hs > gamma*depths*1.02`) is hard to
violate through the public API by design — the march physics keeps Hs under the onset
ceiling. So test the WARNING plumbing directly: caplog-assert that
`run_1d_analytical` on a normal profile emits NO invariant warning, and unit-test the
warning branch by monkeypatching or by calling the check logic with a synthetic Hs
array exceeding gamma*d*1.02 if the structure allows. Do not weaken the production
code to make it testable — if the branch is unreachable without monkeypatching, a
caplog-negative test on the normal path plus a direct construction is acceptable;
state which you did.

**T-W5 — apply_ddd_saturation tests.** (a) Pass-through: a profile always below
gamma*d comes back unchanged (exact equality). (b) Saturation: a profile exceeding
gamma*d on a shoaling stretch relaxes toward Γ*d, never hard-equals gamma*d over a
run of points (the old clamp signature was `Hs == gamma*d` exactly on the pinned
stretch — assert that is now absent). (c) Reform: construct depths so cessation
occurs and assert pass-through resumes.

**T-W6 — detection-from-state tests.** `_find_break_points` with explicit
`onset_indices`: (a) floors still apply (an onset at depth ≤ `_MIN_BREAK_DEPTH_M` or
Hs ≤ `_MIN_BREAK_HS_M` is dropped); (b) legacy path (`onset_indices=None`) result on a
fixed profile is IDENTICAL before/after your changes (regression pin — compute once,
pin literals).

**T-W7 — repair 2 stale tests (only these two; touch nothing else):**
1. `tests/test_surf_1d_handoff_boundary.py::test_every_partition_gets_the_same_truncated_grid`
   — the assertion "adding energy can only raise the combined Hs (up to the γd cap)"
   pins the superseded min-clamp monotonicity. Under DDD, a 3-partition combined
   profile can trip onset earlier and decay BELOW the 1-partition profile downstream —
   physically correct. Replace that single assertion with one that survives the new
   physics (e.g. assert monotonicity only on the grid-identity claims the test is
   actually about, or assert the combined profile ≥ single-partition profile at the
   OFFSHORE boundary point only). Document the supersession in a comment with the
   Round W date. Keep the grid-identity assertions unchanged.
2. `tests/test_bathy_refinement.py::test_beach_profile_module_imports_and_calls_refinement`
   — PRE-EXISTING stale pin (fails at `36fab04` too, before Round W): Round P moved
   profile refinement out of `endpoints/beach_profile.py` into the pipeline
   (`surf_1d_pipeline.py:2343`) and the SurfBeat path (`endpoints/surf.py:951`, via
   `ANALYTICAL_TARGET_DX_M`). Re-point the wiring test at the real call sites (same
   wiring-level proof style: the names bound in those modules are the ones defined in
   `bathymetry_refine.py`). Comment the move with the Round P reference.

## Rules

- Files you may modify: new test file(s) `tests/test_ddd_breaking_w*.py` (your
  naming), plus EXACTLY the two stale tests named in T-W7. You must NOT touch
  production code. If a test cannot pass without a production change, STOP and report
  via SendMessage — that is a finding, not a licence.
- Known-answer mandate: KAT literals hand-computed, arithmetic in comments.
- Run the full suite locally (`python -m pytest tests/ -q --ignore=tests/services`)
  before closeout; expected result is 0 failures after your T-W7 repairs. Report the
  full tail.
- Git: `git add` / `git commit` / `git status` / `git log` / `git diff` ONLY. No
  push/pull/fetch/rebase/merge/checkout. Never run anything on containers/librewxr.
- Architectural changes: none are authorized. Anything hitting the 7-trigger list
  (CLAUDE.md) → STOP and report. "Acceptance criteria unreachable" / "a document says
  so" do not authorize you.
- Protocol: SendMessage a one-paragraph scope ack to "main" BEFORE writing code (what
  you will deliver, what you will not touch, your verification plan). WAIT for
  confirmation. Closeout via SendMessage: commit hash(es), full pytest tail, list of
  KAT literals with their hand arithmetic.
