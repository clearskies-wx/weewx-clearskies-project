# S3 brief — Substitution cleanup: doc round + `ww3_boundary` input recorder (PA7; C19/C20; Q10-7)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S3. Date 2026-08-27. Lead: coordinator.
Teammates: `clearskies-docs-author` (meta docs, part a), `clearskies-api-dev` (marine `service.py`,
part c), `clearskies-test-author` (guard test, part c). Auditor: Gate S sweep (Z6) + lead spot-check.
**The `level1` label rename (part b) is DEFERRED to after S8.1 closes** (plan "S3 lead mechanics" (b));
the hotstart-age gate (d) is dropped (Q10-5). NOTHING live is deleted under this task (plan §S3 —
`_reused_l1_boundary_command_lines()`, `swan/level1/`, `ww3_chain_enabled` are LIVE dependencies).

**Pre-round verification (lead, 2026-08-27):** marine HEAD `4810294` (S12/S4/S4b/S5 landed); meta
HEAD `bbf102f3`. Concurrent agents: S1 (`vchain.py`, `swan_runner.py`; PROVIDER-MANUAL §14.15),
S8.1-A (`swan_domain.py`, `bathymetry_resolver.py`; ARCHITECTURE ⚓ WW3 sentence, PROVIDER-MANUAL WW3
section, ADR-109 amendment). **Shared-file rule for this round:** before `git add` of any file
another agent may be editing (ARCHITECTURE.md, PROVIDER-MANUAL.md, ADR-109), run `git diff -- <file>`
and confirm every hunk is yours; if a foreign hunk is present, wait 5 minutes and re-check — never
commit another agent's hunks (two sweeps happened this session).

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"S3 — Substitution cleanup" (what the review found;
Remaining scope (a)–(d)) + "S3 lead mechanics" (a)–(d); carry-over rows C19/C20; Q10 items 7 and 5;
PA7. The corrections themselves are stated there line by line — implement them, do not reinterpret.

## Scope — docs-author (part a)
**Allowlist (meta repo):** `docs/ARCHITECTURE.md` (lines ~130/132 wrong "no-op"/"vestigial" claims →
the truth in plan §S3; Known-gaps rows #12–#16 re-stated per the lead mechanics), `docs/manuals/PROVIDER-MANUAL.md`
(`:2529` swell-card bullet — true only via fallback since Q16-B), `docs/manuals/API-MANUAL.md` §17
(`swellSource` + `closeoutFraction` field rows — read the marine `endpoints/surf.py` serialisation
for the exact names/semantics; the Q16 Round B and PEEL-SEGMENTS CHANGELOG entries describe them),
`docs/decisions/ADR-109-*.md` (G7 row struck as built — `service.py:831`; D14 item 2 re-homed:
"Phase V dropped (Q1); the per-cycle buoy ledger is the standing instrument"; items 1/3 stay as
notes), `docs/CHANGELOG.md` (one S3 entry). **NOT to touch:** the plan, `docs/archive/`, repos.
**Verification:** `grep -n "no-op\|vestigial" docs/ARCHITECTURE.md` shows no wrong claim about the
three live items; each edited line quoted in the closeout with its source citation.

## Scope — api-dev (part c)
**Allowlist (marine repo):** `weewx_clearskies_marine/service.py` — exactly the four sites named in
"S3 lead mechanics (c)": `state.record_input("ww3_boundary", available=True)` immediately after
`boundary_reconstruction.ww3_boundary_files_and_deck()` succeeds in the leg (`~:899–901`) and in the
horizon march (`~:1359–1361`); `available=False` in both `except BoundaryNotViableError` branches.
Nothing else; `CHANGELOG.md` entry. Measure the baseline FIRST: `.venv_local\Scripts\python.exe -m pytest tests/test_health.py tests/test_health_ww3_block.py tests/services/test_ww3_cycle_integration.py -q --tb=no -p no:cacheprovider` (paste).
**NOT to touch:** `state.py` (`_KNOWN_INPUT_NAMES` already contains `ww3_boundary`), `health.py`
(the required-input entry stays — Q10-7 "record it"), anything else.

## Scope — test-author (part c)
**Allowlist:** NEW `tests/test_s3_ww3_boundary_recorded.py`: (1) leg path — `reconstruct_boundary`
raises `BoundaryNotViableError` → `state` shows `ww3_boundary` recorded unavailable and `/health`
lists `required input unavailable: ww3_boundary`; (2) leg success path → recorded available;
(3) horizon-march path — same two. Mirror `tests/services/test_ww3_cycle_integration.py`'s
`_prep_happy_path_fixture` (post-S4b shape: `SimpleNamespace(cycle_used=cycle_dt)`). Pre-change
failure transcript in the docstring (run at HEAD 4810294 first).

## Reading list
Plan §S3 + lead mechanics + C19/C20 + Q10; `scratch/ADVERSARIAL-PLAN-REVIEW-2026-08-28.md` findings
#1/#2/#15/#20/#26 (the evidence); `weewx_clearskies_marine/service.py` `:880–930`, `:1320–1375`;
`state.py:40–120`; `endpoints/health.py:120–160`, `:440–460`; `docs/ARCHITECTURE.md:95–140`,
`:836–857`; `docs/manuals/PROVIDER-MANUAL.md:2515–2540`; `docs/manuals/API-MANUAL.md` §17;
`docs/decisions/ADR-109-*.md` (G7, G10, D14); marine `endpoints/surf.py` (grep `swellSource`,
`closeoutFraction`).

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote
branches. You may only `git add <explicit paths>`, `git commit`, `git status`, `git log`, `git diff`,
`git show`. Never move, rename or delete a file outside your allowlist by any means. If the remote is
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
*Coordinator statement:* recording the `ww3_boundary` input (Q10-7 "record it") and the doc
corrections (PA7) are operator-approved. Deleting any of the three live items is NOT.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
