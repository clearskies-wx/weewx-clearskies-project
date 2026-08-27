# S5 brief — First-install WW3 warm-start bootstrap (marine repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S5 (C17, EVO-Q9 option 2). Date 2026-08-27.
Lead: coordinator. Teammates: `clearskies-api-dev` (code) + `clearskies-test-author` (guard tests).
Auditor: lead spot-check + the Gate S sweep (small round).
**Dispatch condition:** after S12's dev closeout is accepted (keeps one dev in the marine repo at a
time; S5 touches only `service.py`, which S12 does not).

**Pre-round verification (lead, 2026-08-27):** marine HEAD `fca09ec`, clean; baseline
`.venv_local\Scripts\python.exe -m pytest tests/test_service_full_run_trigger.py tests/test_service_vchain_trigger.py tests/test_health_ww3_block.py -q --tb=no -p no:cacheprovider`
→ **1 failed (pre-existing: `test_service_vchain_trigger.py::test_leg_silent_disabled_call_site_is_inert`,
being deleted by the concurrent S4b round as a superseded pin), 42 passed**. Other agents active in this
repo: S1 (`vchain.py`, `swan_runner.py`), S4b (`tests/services/*` + that one file) — none touch `service.py`.
The S4-repaired `_base_monkeypatches()` in `tests/test_service_full_run_trigger.py` is the current harness
for `_run_ww3_leg` stubbing (test-author: mirror it; you may not edit that file).

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"S5 — First-install WW3 warm-start bootstrap"
and "S5 lead mechanics" (the provenance-note file name and JSON shape, the accept-once rule at
`service.py:798–810`, the consume-after-success rule, the refusal wording, the install step, the
ADR-109 D10 amendment, the three guard tests). EVO-Q9 record for the operator's words.

## Scope — api-dev
**Allowlist:** `weewx_clearskies_marine/service.py` (the restart-chaining block `:743–830` and the
post-success point where the note is consumed — find the leg's success record call
`state.record_ww3_leg_success` and delete the note right after it), `CHANGELOG.md`; meta docs
(separate commit): `docs/manuals/OPERATIONS-MANUAL.md` "Marine service deployment" — a "First
install — WW3 warm start" step with the exact `cat > restart_<token>.provenance.json` snippet and
where the seed restart comes from (the EVO-Q9 seed procedure, quoted); `docs/decisions/ADR-109-*`
D10 amendment (Proposed) describing the note.
**NOT to touch:** `ww3_runner.py`, `state.py`, `health.py` (no new health field — the WARNING log
and the ADR are the visibility), any physics/grid code, tests/.
**Named traps:** the note is accepted ONCE (deleted after the successful leg — never left in place);
a note that does not match refuses with today's slug and quotes the note; the D11 age gate still
applies to the accepted cycle; no note → byte-identical behaviour.
**Verification:** the baseline command + the test-author's `tests/test_s5_warm_start_bootstrap.py`.

## Scope — test-author
**Files:** `tests/test_s5_warm_start_bootstrap.py` (new). The three guard tests from the plan's S5
lead mechanics, on `tmp_path` work roots, mirroring `tests/test_service_full_run_trigger.py`'s
harness for `_run_ww3_leg` (after S4's repairs land, that harness is current). Pre-change failure
transcript in the module docstring.

## Reading list
1. Plan §S5 + lead mechanics; `docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md` (grep "Q9"
   for the seed procedure and the operator ruling); `docs/decisions/ADR-109-ww3-deep-water-leg.md`
   D10/D11/D12.
2. `weewx_clearskies_marine/service.py` `:280–320` (constants), `:700–1100` (`_run_ww3_leg`: restart
   chaining, march, next-restart write, success record).
3. `rules/coding.md` §1 "A model runs on all its inputs or it does not run".

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
*Coordinator statement:* the provenance-note persisted file and the accept-once lifecycle step
(triggers 5, 7) are operator-approved — EVO-Q9 ruling 2026-08-19 (option 2, "parked as a pre-ship
row") carried into this plan's S5/C17; the operator's execute-the-plan order covers it.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
