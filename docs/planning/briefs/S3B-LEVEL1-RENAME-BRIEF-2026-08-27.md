# S3(b) brief — `level1` label rename in the marine code (PA7; plan §S3 (b); LAST marine code round)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S3 part (b). Date 2026-08-27. Lead: coordinator.
Teammates: `clearskies-api-dev` (rename) + `clearskies-test-author` (read-compat KAT + grep guard).
Auditor: Gate S sweep (Z6) + lead spot-check. **Dispatch condition:** S8.1-B AND S2 closed out and
accepted (this round touches `service.py`, `swan_domain.py`, `grid_sizing_chain.py`, `swan_runner.py`,
`vchain.py`, `ww3_grid_files.py` — every file the concurrent rounds edit; it runs ALONE in the marine tree).

**Pre-round verification (lead, fill at dispatch):** marine HEAD `<hash>`, clean, NO other agent in the
tree; occurrence inventory `grep -rn "level1\|LEVEL1" weewx_clearskies_marine/ | wc -l` → `<n>` (193 across
12 files at `8fd5a24`); baseline `.venv_local\Scripts\python.exe -m pytest tests/services tests/test_health.py tests/test_health_ww3_block.py tests/test_bathy_refinement.py -q --tb=no -p no:cacheprovider` → `<n passed>`.

## What the plan says (binding)
Plan §S3 "Remaining scope (b)": *`level1` label rename in code/cache names (170 occurrences, cosmetic;
cache-file rename needs a migration note — do NOT rename the on-disk `swan/level1/` directory).*
ARCHITECTURE.md `:107`: the `level1`/`"L1"` name is *the label for the deep-water domain's extent — a
geometry reference only (consumed by WW3's own grid sizing), not a running SWAN level.* The rename makes
the code say what it means. Nothing else changes: no formula, no grid, no file on disk, no wire field.

## Lead mechanics (binding; deviations are findings to report BEFORE coding)
- **Target label: `deep_water`** (identifiers `deep_water`, `DEEP_WATER`, class/attr names `DeepWater…`;
  human text "deep-water domain"). Journal J13 holds this name for the operator's veto; if the operator
  renames it, it is a mechanical re-run of the same round.
- **Step 1 — inventory FIRST, report BEFORE renaming.** Classify every occurrence into: (i) Python
  identifiers/attributes/parameters (`stage1.level1`, `DomainSizing.level1`, `_INTEG_L1`…); (ii) comments,
  docstrings, log/exception TEXT; (iii) **persisted keys** — `swan_grid_sizing.json`'s `level1` block
  (`domain_sizing_to_dict`/`from_dict`, `swan_domain.py:2875`), the ETOPO cache filename
  `swan_bathymetry_L1.json` (`C:\etc\weewx-clearskies` / `/etc/weewx-clearskies`), any provenance
  dicts; (iv) **on-disk paths that MUST NOT change** — `swan/level1/` directory constants and everything
  that resolves into it (`_reused_l1_boundary_command_lines()`, `vchain.py:727` scaffold reads, the 22
  `B_*.txt`), `swan_bathymetry_L1.json` on disk; (v) SWAN deck text / point names (`L2P####` are L2 —
  untouched); (vi) test files (test-author's). Send the table (file, line, class) to the coordinator; wait
  for the ack before step 2.
- **Step 2 — rename classes (i) and (ii)** everywhere in `weewx_clearskies_marine/`. Pure text rename;
  `import ast`-parse every file; the baseline suite must pass unchanged (a test that pins an old
  identifier is stale-by-design → the test-author updates it in the same round; list each).
- **Step 3 — persisted keys (iii): READ both, WRITE the new.** `domain_sizing_from_dict()` accepts
  `deep_water` and falls back to `level1` (logging INFO once per load: "legacy `level1` key read");
  `domain_sizing_to_dict()` writes `deep_water` ONLY. Same pattern for any other persisted `level1` key
  you find. The cache FILE names on disk do not change (class iv). Migration note in OPERATIONS-MANUAL:
  the next sizing-chain run rewrites `swan_grid_sizing.json` with the new key; no operator action.
- **Step 4 — class (iv) stays byte-identical.** Add ONE named constant per on-disk path if one is missing
  (e.g. `SWAN_LEVEL1_DIRNAME = "level1"  # on-disk name kept — plan §S3 (b)`), so the surviving literal
  is documented, not accidental.
- **Docs (meta, separate commit):** ARCHITECTURE.md `:107` follow-up sentence → done; PROVIDER-MANUAL
  and API-MANUAL wherever they name the `level1` sizing block; OPERATIONS-MANUAL migration note;
  CHANGELOG (meta + marine).

## Scope — api-dev
**Allowlist (marine):** the 12 files of the inventory under `weewx_clearskies_marine/` (`config/marine_config.py`,
`service.py`, `tools/reestablish_spot.py`, `providers/nearshore/swan.py`, `endpoints/discovery.py`,
`services/{geography,grid_sizing_chain,swan_spectral,swan_runner,swan_domain,vchain,ww3_grid_files}.py`),
marine `CHANGELOG.md`; meta docs listed. **NOT to touch:** any test, any on-disk file/dir name, any wire
field name in `models/` (grep `level1` there — expected 0; if not 0, STOP and report: a wire field is
trigger 4), the plan.
**Verification:** baseline command; `grep -rn "level1\|LEVEL1" weewx_clearskies_marine/` → only class-(iv)
constants and the from_dict fallback remain (list each surviving line in the closeout).

## Scope — test-author
**Files:** NEW `tests/services/test_s3b_level1_rename.py`: (1) `domain_sizing_from_dict` on a dict with the
legacy `level1` key → same `DomainSizing` as with `deep_water`; (2) `to_dict` emits `deep_water` and NOT
`level1`; (3) round-trip old-key → object → dict has the new key; (4) grep guard: every surviving `level1`
literal in `weewx_clearskies_marine/` is in the dev's reported class-(iv) list (assert the set equality so a
regression is loud); (5) the on-disk `swan/level1/` path constant resolves to `.../level1` unchanged.
Plus: update any existing test pinned to a renamed identifier (list each, with the reason).

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote
branches. You may only `git add <explicit paths>`, `git commit`, `git status`, `git log`, `git diff`,
`git show`. Never move, rename or delete a file outside your allowlist by any means (no `mv`, no
`rm`) — including files your own tests or tools produce, and NEVER anything under `C:\etc\weewx-clearskies`
or on a container. Tests write only under `tmp_path`. If the remote is ahead or behind, STOP and report
via SendMessage. Edit and commit ONLY on the local machine; SSH to containers is read-only.

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
*Coordinator statement:* the label rename including the persisted sizing-JSON key with read-compatibility
(trigger 4/7 on a persisted file's field name) is operator-approved — plan PA7 / §S3 (b) "cache-file
rename needs a migration note". Renaming any on-disk directory or file, or any wire field, is NOT.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *Pre-identified stale-by-design: tests pinning `level1` identifiers/keys (the test-author
updates them; the dev reports them).*

## Reporting
Scope ack first; the step-1 inventory table BEFORE any rename; status every ~4 minutes; closeout per
your agent definition with raw output and the surviving-literal list.
