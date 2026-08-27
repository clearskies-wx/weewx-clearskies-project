# S4b brief — Test-debt triage, second class: `tests/services/` (marine repo, tests only)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S4b (follow-up to S4/C13). Date 2026-08-27.
Lead: coordinator. Teammate: `clearskies-test-author` (the S4 author, resumed). Auditor: lead
reproduces counts.

**Pre-round verification (lead, 2026-08-27, local `.venv_local`, marine HEAD `3785f44`):**
`.venv_local\Scripts\python.exe -m pytest tests/services -q --tb=line -p no:cacheprovider` → **14 failed, 316 passed**:
- `tests/services/test_hourly_fill_chain_boundary.py::test_legacy_default_is_byte_identical`
- `tests/services/test_swan_runner.py::test_l2_default_boundary_source_input_is_byte_identical_before_and_after`
- `tests/services/test_swan_runner.py::test_l2_boundary_source_default_parameter_is_boundnest1`
- `tests/services/test_swan_runner.py::test_l2_boundnest3_shadow_path_is_never_taken_by_default`
- `tests/services/test_swan_runner.py::test_l2_boundnest3_shadow_path_emits_when_explicitly_requested`
- `tests/services/test_wind_gatherer.py::TestColdStartReconcile::test_loads_store_then_polls_and_persists`
- `tests/services/test_ww3_cycle_integration.py::` ×8 (`test_shadow_leg_is_true_no_op_when_no_site_has_flag_set`,
  `test_shadow_leg_is_no_op_when_locations_list_is_empty`, `test_refuses_restart_missing_when_no_restart_file_present`,
  `test_refuses_restart_missing_when_stamp_does_not_equal_cycle_start`, `test_refuses_restart_missing_when_no_provenance_recorded`,
  `test_runner_step_specs_are_wd10_order_with_no_phantom_chained_paths`, `test_runner_success_updates_state_and_health`,
  `test_runner_ww3runerror_slug_lands_verbatim_in_leg_state`) — the three "refuses restart missing" ones
  now see `ww3_wind_regrid_failed` (the leg proceeds past the restart check).

## Design — the S4 class rules apply verbatim (`docs/planning/briefs/S4-TEST-DEBT-BRIEF-2026-08-27.md` §Design)
Class A delete (pins superseded behaviour — name the superseding change), Class B repair harness
(behaviour still exists), Class C STOP (test right, code wrong), Class D probe-keyed skip (Windows-path
artefact — the plan names `test_wind_gatherer::TestColdStartReconcile` as exactly this). Superseding
facts you will likely need: BOUNDNEST3 from the WW3 transfer file is the ONLY L2 boundary path since
CHAIN-SERVES (2026-08-19) and the SWAN-L1 removal (`3c550ae`, 2026-08-23); the WW3 chain is
unconditional (`3226723`, ADR-109 D1); a TRUE cold start (no prior WW3 success) proceeds without a
restart file (operator order 2026-08-24, `service.py:748–796`) — a "refuse when no restart" pin is
superseded ONLY for the true-cold-start case; the transient-gap refusal still exists (`:775–796`) and
those tests may be Class B (seed a prior success so the refusal path is exercised). Classification
table first, via SendMessage; wait for the lead's confirmation; then execute.

## Scope
**Allowlist:** the four test files named above; `tests/services/conftest.py` only if a shared fixture is
required. Nothing else — never `weewx_clearskies_marine/`.
**Verification:** the pre-round command → 0 failed (Class C rows, if any, stay failing and are reported)
+ `tests/test_break_reform_kat.py tests/test_s12_handoff_restart_kat.py` still green (S12 landed in this
tree; do not touch its tests).

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote
branches. You may only `git add <explicit paths>`, `git commit`, `git status`, `git log`, `git diff`,
`git show`. Never move, rename or delete a file outside your allowlist by ANY means. If the remote is
ahead or behind, STOP and report via SendMessage. Edit and commit ONLY on the local machine.

**Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your
task requires one, STOP and report via SendMessage — do not implement it, do not work around it, do
not pick an option. A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. This does NOT cover changing how the same equation is solved — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
**These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
**The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *Deleting/repairing a test is authorized ONLY per the class ruling the lead confirms.*

## Reporting
Classification table as the scope ack; wait for confirmation; closeout with before/after counts.
