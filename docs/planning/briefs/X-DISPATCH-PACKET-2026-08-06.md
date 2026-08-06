# ROUND X DISPATCH PACKET — breaking-energy remodel (SURF-PHYSICS-REMODEL-PLAN Round X)

Drafted 2026-08-06 by the coordinator while M-0 gate cycles accumulate. The DESIGN is the
plan's X-DESIGN section (X-D1..X-D5) — operator-approved; this packet adds only dispatch
mechanics: anchors, task split, sequencing, prohibitions, live checks. Agents read the plan's
X-DESIGN and `scratch/X0-FACT-PIN-2026-08-05.md` directly — briefs do NOT restate the design.

## Sequencing (coordinator-ruled)
- LOCAL BUILD may begin as soon as the marine repo frees up (H-1 fix + H-1 test commits
  landed). Plan order M-0 → H-1 → X binds DEPLOYS and REALITY GATES, not local build.
- Dispatch order inside X (one dev at a time in the repo, commits serialized):
  1. **X12-dev** — X1 + X2 as ONE task (the Q_b state machine and the Q_b_eff-weighted
     one-sided step are one coherent rewrite of `_ddd_breaking_march` + revival of
     `_solve_breaking_fraction`). Includes its own KAT-support fixtures but NOT the test
     files (X5 owns those).
  2. **X3-dev** — roller march (revive `_roller_model` basis) + E_r carried on internal
     result objects + zone extents through `endpoints/beach_profile.py` (D-6).
  3. **X4-dev** — W1b cap deletion (`apply_ddd_saturation` :720 at d74c578-era anchors) +
     INVARIANT_11 (roller closure, 1%) + INVARIANT_12 (no-gain, marched ≤ raw + 1 mm),
     slotting into `services/invariants.py`'s registry pattern (:54-101 constants,
     `check()` :124-156).
  4. **X5-tests** — X-K1..K4 KATs + state-machine units + the Round-W guard-test
     dispositions per X0 Table 2 (1 file keep / 2 files superseded / 3 files+1 assertion
     re-derive; every disposition listed + justified in the closeout).
  5. **X6-docs** — ADR-102 (X-DESIGN verbatim + constants + worked X-K2 example) +
     ARCHITECTURE marine-section delta + API-MANUAL §17-18 break-point semantics. Ships
     alongside the code commits (cross-repo: meta commits in the same task window).
  6. **S-5 rider** (EYEBALL-FIX-PLAN, ruled 2026-08-05): dominant-partition direction —
     dispatched in X's window per the plan's doc table. PLUS the SW-1b fix if its findings
     land in time and the operator approves its scope (SW-1b findings return to operator
     first; regression fix + missing guard).
  7. **X7 gate**: six-row QC gate, blind adversarial audit briefed from the plan's X-QC
     attack text, deploy via script, reality gate rows 1-3 as pre-stated in the plan.
- X's DEPLOY happens only after H-1's deploy + accept close (collapsed hours would corrupt
  X's reality-gate evidence — plan's stated reason).

## Anchor re-pin requirement
X0's anchors were pinned at `d74c578`. Since then: `9535e8a` (D-1b — swan.py cache region
only), `5ca8fcc` (H-1 — swan_runner/surf_1d_pipeline/state/health/swan.py) + the pending H-1
degraded-return fix + H-1 test file. **surf_1d_analytical.py is untouched by all of these**
— X0's Table 1 anchors (:236-316 `_solve_breaking_fraction`, :319-405 `_battjes_janssen`,
:408-449 `_roller_model`, :452-612 `_ddd_breaking_march`, :615-749 `apply_ddd_saturation`
w/ cap at :720, :892 `_MIN_BREAK_DEPTH_M`, :909-972 `_find_break_points`, :975-1167
zone classifiers) remain valid; each dev re-verifies its own anchors by symbol at dispatch
HEAD and reports drift. surf_1d_pipeline.py anchors (X0: `_combine_partition_hs` :619-673
w/ apply call :660; `PartitionBreakResult` :105-144; `TransectResult` :147-205; second cap
:754 — EXPLICIT NON-GOAL per D-5) shifted slightly with H-1's additions — re-locate by
symbol.

## Standing constraints carried into every X brief (verbatim blocks required)
- Git restrictions block, architectural block (with the note that X-D1..X-D5 as written in
  the plan ARE the operator-approved design — constants γ 0.73, Γ 0.40, K 0.15,
  Q_B_VISIBLE 0.05, Q_B_CESSATION 0.02, β_D 0.10 are FIXED; any deviation = STOP), 
  stale-test block.
- Named traps, all briefs: the SECOND γ·d cap at `_combine_partition_faces_11_3` (D-5:
  OUT of scope, explicit non-goal — do not touch, do not "fix while there"); the legacy
  `onset_indices=None` path in `_find_break_points` (unchanged); `_MIN_BREAK_DEPTH_M`'s
  publication-filter role (stays); wire/payload shapes (Q_b/E_r ride INTERNAL result
  objects only — no served-payload changes in X); swan-commands-extract.md FROZEN; no new
  dependencies; never the full test suite.
- X-K2 fixture ground truth (X0-verified live): `profiles_by_transect["55"]`, 261 pts,
  bar depth-minimum 1.545 m at 79.74 m; gamma field = 0.73; depth sign convention MUST be
  confirmed against `vertical_datum`/`hat_m` before use (X0 "could not determine" #2).
- Live checks (X7, pre-stated): deploy via `scripts/deploy-marine.sh` only; publish-liveness
  within one cycle; two new invariants registered and ZERO firings across 4 consecutive
  cycles (Row 2); Row 1 webcam gate on the first ≥3 ft / ≥12 s groundswell day (operator
  screenshot beside payload, ±40 ft of bar crest, H-1-clean hours only); Row 3 journal sweep.

## X-K fail-pre-change requirements (X5)
- X-K2's double-break row MUST fail against pre-change HEAD (transcript recorded).
- X-K1 vs an INDEPENDENT Brent solve (not a rearrangement); reference table
  Hrms/Hmax ∈ {0.3, 0.5, 0.7, 0.85, 1.0}.
- X-K3 closure vs independent trapezoid integration, 1%.
- X-K4 bar–trough–bar adversarial profile: no relaxation-driven growth anywhere.
