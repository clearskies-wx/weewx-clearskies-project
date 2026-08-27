# S1 brief — C6 seam-fidelity ledger row (marine repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S1 (PA5, EVO-Q16 C6). Date 2026-08-27.
Lead: coordinator. Teammates: `clearskies-api-dev` (code, marine repo) + `clearskies-test-author`
(KATs). Auditor: `clearskies-auditor`, results-free gate file `scratch/GATE-S1-DEFINITION.md`.
**Dispatch condition:** after S12's dev closeout is accepted (both rounds edit `swan_runner.py`).

**Pre-round verification (lead, 2026-08-27):** marine HEAD `fca09ec` (S12 landed), clean; baseline
`.venv_local\Scripts\python.exe -m pytest tests/test_vchain_swan_seam.py tests/services -q --tb=no -p no:cacheprovider`
→ **14 failed (all pre-existing, listed in `docs/planning/briefs/S4B-TEST-DEBT-BRIEF-2026-08-27.md` — an S4b
agent may repair them concurrently; a change in that list is a finding), 320 passed**. Other agents
active in this repo: S4b (tests/services test files only), S5 (`service.py`) — none touch your files.

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"S1 — C6 seam-fidelity ledger row" (the design
paragraph AND "S1 lead mechanics" — the seam point rule, the band constants, the row shape, the
KATs, the docs), plus NAMED CONSTANTS (energy-ledger band edges) and PA5.

## Scope — api-dev
**Allowlist:** `weewx_clearskies_marine/services/vchain.py` (constants, `integrate_spectrum` optional
mask, the `seam` block in `record_chain_cycle_ledger_row` success path, a helper that locates the
seam transfer point + computes the SWAN point), `weewx_clearskies_marine/services/swan_runner.py`
(ONLY the DWR block `~:3600–3790`: the `SEAM` POINTS/SPECOUT lines; nothing else in this file),
`weewx_clearskies_marine/services/swan_spectral.py` ONLY if a unit-conversion helper for
SPECOUT→per-radian density is missing (additive function; report it in the ack),
`CHANGELOG.md`; meta docs (separate commit): `docs/manuals/OPERATIONS-MANUAL.md` (marine monitoring
— the ledger `seam` row), `docs/manuals/PROVIDER-MANUAL.md` §14.15 (the SEAM output point).
**NOT to touch:** `service.py`, `boundary_reconstruction.py`, `swan_formats.py`, `ww3_formats.py`,
the BOUNDNEST3 command, any grid geometry, tests/, anything S12 touched outside the DWR block.
**Named traps:** never raise from the ledger writer; the row is written even when the seam
comparison fails (`error` named); the SWAN point is one L2 cell INSIDE the boundary (not on it —
ADR-095 Amendment 2: no SPECOUT at a boundary cell); units converted before comparing (cite both
parsers' docstrings); the ledger schema version `_LEDGER_SCHEMA` is bumped to 3 with the additive key.
**Verification:** the baseline command + the test-author's `tests/test_s1_seam_ledger_kat.py`.

## Scope — test-author
**Files:** `tests/test_s1_seam_ledger_kat.py` (new), fixtures under `tests/fixtures/s1/`. KATs (a)–(d)
verbatim from the plan's S1 lead mechanics; pre-change failure transcript in the module docstring.

## Reading list
1. Plan §S1 (+ lead mechanics), NAMED CONSTANTS, PA5; EVO plan Q16 C6 record
   (`docs/planning/MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.md`, grep "C6").
2. `weewx_clearskies_marine/services/vchain.py` `:1–150` (constants/schema), `:150–375`
   (transfer parse, integrate_spectrum, buoy summary), `:960–1107` (the ledger row writer).
3. `weewx_clearskies_marine/services/swan_runner.py` `:3560–3800` (the DWR block: POINTS/SPECOUT/
   TABLE emission, UTM transform, insertion before COMPUTE) and `:3812–3906` (how SPEC_DWR files are
   parsed after the run — mirror for `SPEC_SEAM.txt`).
4. `weewx_clearskies_marine/services/swan_spectral.py` `:60–120` (`parse_specout_file` output units),
   `docs/reference/swan-commands-extract.md` (SPECOUT SPEC2D ABS units — local only; never download
   SWAN docs), `docs/reference/swan-user-manual.txt` Appendix D lines the extract cites.
5. `weewx_clearskies_marine/services/swan_domain.py:3320–3331` (`l2_boundary_points`) and how
   `swan_grid_sizing.json`'s `ww3_leg` block is read at runtime (grep `ww3_leg` in `service.py`).
6. `tests/test_vchain_swan_seam.py` (existing seam-adjacent tests — do not break them).

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
*Coordinator statement:* the one new L2 output point, the `SPEC_SEAM.txt` file and the additive
ledger field (trigger 7) are operator-approved — plan PA5 (EVO-Q16 C6, "ok" 2026-08-25).

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
