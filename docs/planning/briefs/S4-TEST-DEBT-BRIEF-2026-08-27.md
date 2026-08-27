# S4 brief — Test-debt triage (marine repo, tests only)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S4 (C13). Date 2026-08-27. Lead: coordinator.
Teammate: `clearskies-test-author`. Auditor: lead reproduces counts (no separate adversarial pass —
no production code moves).

**Pre-round verification (lead, 2026-08-27, local `.venv_local`):**
`.venv_local\Scripts\python.exe -m pytest tests/test_serve_nothing_on_failure.py tests/test_service_full_run_trigger.py -q --tb=line -p no:cacheprovider`
→ **18 failed, 19 passed** at marine HEAD `2a05856` (8 in `TestConvergenceFailuresRecorded`/
`TestFillPathServeNothingGuard`/`TestFullRunServeNothingGuard`; 10 in `test_service_full_run_trigger.py`).
Other agents (S12) are committing production code in this repo concurrently — you touch tests only.

## Design (plan §S4, verbatim rule; read it there first)
For EACH failing test, classify it into exactly one class and apply the lead's ruling for that class:
- **Class A — pins superseded behaviour** (e.g. an "L1 level" convergence path that no longer exists
  since the SWAN-L1 removal 2026-08-23, or the pre-CHAIN-SERVES optional WW3 chain): DELETE the test,
  with a one-line reason in the commit body naming the superseding change (commit hash or ADR/plan
  item). Deleting a whole file is allowed only when every test in it is Class A.
- **Class B — the behaviour under test still exists; only the harness/fixture/signature is stale**
  (e.g. `_run_full_swan_cycle` gained a kw-only argument, a fixture builds a pre-L4 cluster shape,
  a patched module path moved): REPAIR the harness to the current design so the test exercises the
  same behaviour it always did. The assertion's INTENT must not weaken.
- **Class C — the test is correct and the production code is wrong**: STOP. Do not modify anything;
  report the test name, the assertion, and the code path via SendMessage. This is a finding.
- **Class D — Windows-path artefact** (only if you find one): keep with a probe-keyed `skipif`
  naming the probe (not a bare `sys.platform` skip).
**Before changing anything**, SendMessage the lead your classification table (test → class → one-line
reason). The lead confirms or re-rules per row; then you execute. Nothing in
`weewx_clearskies_marine/` moves under this task, ever.

## Scope
**Allowlist:** `tests/test_serve_nothing_on_failure.py`, `tests/test_service_full_run_trigger.py`,
and `tests/conftest.py` only if a Class-B repair needs a shared fixture. Nothing else.
**Verification command:** the pre-round command above; deliverable = 0 failed in those two files
(Class C rows, if any, stay failing and are reported), with the before/after counts pasted, and
`tests/test_break_reform_kat.py` + `tests/test_c8_forced_run_no_op.py` + `tests/test_forced_run_dedup_override.py`
still passing (adjacent suites — rules/verification.md post-remediation reruns).

## Reading list
1. Plan §S4 and C13 row; `rules/verification.md` "Evidence hygiene — Stale tests" and the
   post-remediation rerun rule; `rules/agents.md` "Stale-test block".
2. The two test files (whole) and the production modules they exercise:
   `weewx_clearskies_marine/service.py` (`:2000–2300` full-run trigger; grep the names the tests
   patch), `weewx_clearskies_marine/providers/nearshore/swan.py` (grep `_convergence_failures`,
   `run_full_swan_cycle_from_store`), `weewx_clearskies_marine/services/swan_runner.py` (grep
   `_check_convergence`, `_convergence_failures`).
3. `docs/ARCHITECTURE.md` ⚓ MARINE HANDOFF MODEL block (`:98–101`) — "No SWAN L1 compute level
   exists" (2026-08-23) — the superseding fact for any L1-path test.
4. Git history for the superseding changes: `git log --oneline -40 -- weewx_clearskies_marine/service.py weewx_clearskies_marine/providers/nearshore/swan.py`.

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
or `git checkout` of remote branches. You may only `git add <explicit paths>`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve
it yourself. Edit and commit ONLY on the local machine; SSH to containers is read-only.

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
pre-existing. *For this round, deleting/repairing a test is authorized ONLY per the class ruling the
lead confirms on your classification table.*

## Reporting
Scope ack + classification table first; wait for the lead's confirmation of the table before
editing. Status every ~4 minutes. Closeout per your agent definition with raw before/after output.
