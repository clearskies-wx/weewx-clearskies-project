# M4-B brief — remove the Esri/NAIP imagery provider machinery (Q10-6 RULED "if we don't need it then get rid of it"; PA9 extended)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M4 round B. Date 2026-08-27. Lead: coordinator.
Teammates: `clearskies-api-dev` ×2 — one for the API repo (`m4b-api`), one for the stack repo (`m4b-stack`) —
+ `clearskies-test-author` (`m4b-test`, both repos). Auditor: `clearskies-auditor`, results-free gate
`scratch/GATE-M4B-DEFINITION.md`.

**Pre-round verification (lead, 2026-08-27):** API HEAD `39cd51a`, clean (M4-API landed: `/imagery/config`
always answers `provider:"basemap"`). API baseline (`.venv\Scripts\python.exe -m pytest tests/providers/imagery tests/test_config_settings_imagery_validation.py tests/test_current_config_imagery_prefill.py tests/test_wire_imagery_settings.py tests/test_endpoints_imagery_integration.py tests/test_imagery_config_basemap.py tests/test_endpoints_basemap.py tests/test_basemap_extract.py -q --tb=no -p no:cacheprovider`) → `123 passed`.
Stack HEAD `065ac62`, clean. **Test runner (lead, 2026-08-27): `uv run` does not work in the stack repo (no lockfile; `weewx-clearskies-api` is a registry dep). The lead built `.venv_local` (API from its local path + `weewx-clearskies-config[dev]`); use `.venv_local\Scripts\python.exe -m pytest … -q --tb=no -p no:cacheprovider` from the stack root.** Lead baseline `46 passed, 1 warning` for `tests/test_admin_imagery.py tests/test_wizard_imagery.py tests/test_wizard_marine_roundtrip.py tests/test_admin_basemap.py tests/test_wizard_providers.py`
FIRST. No other agent is active in either repo. The dashboard side (About-page rows, `HeatMapCard`) is
M4-DASH's — not this round.

## What the operator ruled (plan Q10-6, 2026-08-27)
"q10/6 if we dont need it then get rid of it." Nothing user-facing reads the `[imagery]` provider any
more (M4-API: `/imagery/config` answers the product basemap regardless). The lead's inventory (this
hour) of what exists ONLY to choose the surf map's aerial-photo source — and therefore goes:

**API repo:** `providers/imagery/{__init__,esri,esri_topo,naip}.py`; their three rows in
`providers/_common/dispatch.py:91–93` (+ the imports `:63–65` and the docstring `:26–27`);
`config/settings.py` `ImagerySettings` (`:898–955`) and its construction `:1819` (`settings.imagery`);
`__main__.py:590–616` (startup imagery-module checks) and `:1071–1073` (`wire_imagery_settings`);
`endpoints/imagery.py`: `wire_imagery_settings`/`reset_imagery_settings_for_tests`/`_select_provider`/
`_imagery_provider` globals/the startup WARNING, the `/imagery/tiles/{z}/{x}/{y}` NAIP proxy
(`get_imagery_tile`, `_validate_tile_coords`, `_get_imagery_tile_params`) — **`GET /imagery/config` STAYS**
(the dashboard consumes it) and keeps accepting its `lat`/`lon` query params unchanged (documented as
accepted-and-ignored — removing a required param is a wire change and is NOT authorized);
`models/params.py` `ImageryTileQueryParams` (`ImageryConfigQueryParams` stays); `endpoints/setup.py:2779`
`"imagery"` dropped from `_PROVIDER_DOMAINS`; any `imagery` provider entry the wizard-apply path writes.
**Stack repo:** admin section `("api","imagery",…)` `admin/routes.py:395–401`, `:423`, `:948–952`, `:1107`;
`templates/config/imagery_section.html` + its include in `templates/config/section.html:19–20`;
wizard step-6 imagery fieldset `templates/wizard/step_providers.html:203–240`; `wizard/routes.py:2113–2126`
(`"imagery"` out of the domain tuple, the `auto` default, `imagery_api_key`) and `:4167–4177`;
`wizard/state.py:181–188` `imagery_api_key`; help keys `help.admin.imagery-provider.*` and
`help.wizard.imagery.*` plus the fieldset strings in ALL 13 `translations/*.json`; `docs/OPERATOR-MANUAL.md`
sections that describe them. **STAYS:** the marine-step satellite toggle `templates/wizard/step_marine.html:931`
(operator-only, a direct browser URL — Q10-6 text); everything `basemap`.

## Lead mechanics (binding)
1. **Config migration, not a crash.** An existing `api.conf` on the host carries `[imagery] provider = …`.
   After this round the loader must IGNORE an unknown `[imagery]` section silently (verify how
   `config/settings.py` treats unknown sections — if it raises or warns per-section, add ONE INFO log
   "ignoring legacy [imagery] section" and nothing else). KAT: a conf with `[imagery]` loads.
   OPERATIONS-MANUAL migration note: the section is inert and may be deleted by the operator.
2. **`/imagery/config`** stays byte-identical in its response (M4-API's tests `test_imagery_config_basemap.py`
   keep their ASSERTIONS untouched; ruled 2026-08-27: that file's setup constructs `ImagerySettings` and calls
   `wire_imagery_settings()`, both deleted — the test-author amends the setup only, allowlist extension). `/imagery/tiles/...` returns 404 (route gone) — KAT.
3. **Contract + docs (meta, separate commit):** `docs/contracts/openapi-v1.yaml` — remove the
   `/imagery/tiles/{z}/{x}/{y}` path and `ImageryTileQueryParams`-shaped schema if present (leave the
   config path); API-MANUAL §12a rewritten (no provider table, no NAIP proxy, the `[imagery]` key gone);
   OPERATIONS-MANUAL config-key table + migration note; PROVIDER-MANUAL imagery-provider section removed
   (leave a one-line "removed 2026-08-27 (Q10-6)" pointer); ARCHITECTURE.md provider inventory;
   stack `docs/OPERATOR-MANUAL.md` (admin Imagery section + wizard field removed); help-key removal =
   Operator-Manual update (CLAUDE.md doc-code sync); CHANGELOGs (API, stack, meta).
4. **Tests (test-author):** delete `tests/providers/imagery/` (3 files + `__init__`), `test_config_settings_imagery_validation.py`,
   `test_current_config_imagery_prefill.py`, `test_wire_imagery_settings.py`, `test_endpoints_imagery_integration.py`
   (API); `tests/test_admin_imagery.py`, `tests/test_wizard_imagery.py` (stack); amend
   `tests/test_wizard_marine_roundtrip.py:27,269` references. NEW guard tests: API `tests/test_m4b_imagery_removed.py`
   (legacy `[imagery]` conf loads; `/imagery/tiles/1/1/1` → 404; `/imagery/config` unchanged; dispatch table has
   no `imagery` domain; `import weewx_clearskies_api.providers.imagery` raises ImportError); stack
   `tests/test_m4b_imagery_removed.py` (`GET /admin/config/api/imagery` → 404; admin section list has no
   `imagery-provider`; `POST /wizard/step/6` with a stray `provider_imagery` field is accepted and NOT stored;
   `_SECTION_ALLOWED_KEYS` has no `("api","imagery")`; no locale file contains `help.admin.imagery-provider`
   or `help.wizard.imagery`). Deleting a test file is a listed action of this round — each deletion is listed
   in the closeout with the reason "module removed under Q10-6".
5. Pure removal: no behaviour of any surviving code changes. `grep -rn -i "naip\|esri\|arcgis" <repo>` after the
   round → API: 0 outside CHANGELOG/history; stack: only `step_marine.html:931` (the toggle) and CHANGELOG.

## Scope — m4b-api (API repo + meta docs) / m4b-stack (stack repo + stack docs)
Allowlists = exactly the files named above for your repo + that repo's CHANGELOG + the meta docs in item 3
(m4b-api owns the meta docs; m4b-stack owns stack `docs/OPERATOR-MANUAL.md` and the locale files).
**NOT to touch:** anything `basemap`; the dashboard repo; `step_marine.html`; `/imagery/config`'s response
or params; tests (test-author's).
**Verification:** your repo's baseline command (post-change count will drop by the deleted files — state it)
+ the test-author's new guard file; `python -c "import ast"`-parse every edited file; `grep` per item 5.

## Scope — m4b-test (both repos)
Files: the deletions + two new guard files in item 4 + the `test_wizard_marine_roundtrip.py` reference
amendment. Capture, BEFORE the devs land, the baseline counts and the fact that the to-be-deleted tests
pass at HEAD (that is the pre-change evidence for a removal). Never obtain pre-change evidence by moving
or stashing anything.

## Reading list
Plan §M4 lead mechanics, §Q10 item 6, PA9; `docs/manuals/API-MANUAL.md` §12a; `docs/manuals/OPERATIONS-MANUAL.md`
config-key table; `docs/manuals/PROVIDER-MANUAL.md` (grep imagery); `docs/contracts/openapi-v1.yaml` (grep
imagery); API `endpoints/imagery.py` in full, `config/settings.py:890–960, :1810–1825`, `__main__.py:585–620,
:1065–1075`, `providers/_common/dispatch.py:20–100`, `endpoints/setup.py:2770–2785`; stack `admin/routes.py:380–430,
:940–960, :1100–1110`, `wizard/routes.py:2105–2130, :4160–4180`, `wizard/state.py:175–190`, the two templates;
`rules/coding.md`; `rules/verification.md`.

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote
branches. You may only `git add <explicit paths>`, `git rm <explicit paths listed in your allowlist>`,
`git commit`, `git status`, `git log`, `git diff`, `git show`. Never move, rename or delete a file outside
your allowlist by any means. Pre-change evidence comes from `git show <base>:<file>` into scratch or from
running tests BEFORE the dev lands. Before `git add` of a file another agent may be editing, `git diff --
<file>` and confirm every hunk is yours. If the remote is ahead or behind, STOP and report via SendMessage.
Edit and commit ONLY on the local machine; SSH to containers is read-only.

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
*Coordinator statement:* deleting the imagery provider modules, the `/imagery/tiles` endpoint, the
`[imagery]` config key, the admin section and the wizard selector (triggers 2 and 7) is operator-approved —
plan Q10-6, operator 2026-08-27 "if we dont need it then get rid of it"; recorded as PA9 (extended). That
statement is your full authorization for exactly those items. Changing `/imagery/config`'s response or
required params, or touching the marine-step satellite toggle, is NOT.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *Pre-identified for this round: the test files named in item 4 are deleted BY THE
TEST-AUTHOR (listed action); a dev finding any OTHER failing test reports it.*

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
