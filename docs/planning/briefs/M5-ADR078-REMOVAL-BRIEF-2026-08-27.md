# M5 brief — remove the ADR-078 single-file geographic-features feature (Amendment 2 ACCEPTED 2026-08-27)

**Round identity:** MARINE-AND-MAPS-PLAN follow-up round M5 (the "removal commit" ADR-078 Amendment 2
queued behind its acceptance). Date 2026-08-27. Lead: coordinator. Teammates: `clearskies-api-dev` ×2
(`m5-api` = API repo + meta docs/contract; `m5-stack` = stack repo) + `clearskies-test-author` (`m5-test`,
both repos). Auditor: `clearskies-auditor`, results-free gate `scratch/GATE-M5-DEFINITION.md`.

**Pre-round verification (lead, 2026-08-27):** API HEAD `811fe88` (LIVE on weewx since 16:1x UTC), clean;
stack HEAD `d3d8bec` (LIVE on weather-dev), clean; dashboard `c8c38bc` LIVE — the dashboard has NO reader of
`/api/v1/geographic-features/*` (Gate M sweep P2, Gate D1 X12 confirmed by grep). Baselines to paste FIRST:
API `.venv\Scripts\python.exe -m pytest tests/test_endpoints_basemap.py tests/test_basemap_extract.py tests/test_imagery_config_basemap.py tests/test_m4b_imagery_removed.py tests/test_openapi.py -q --tb=no -p no:cacheprovider`;
stack `.venv_local\Scripts\python.exe -m pytest tests/test_admin_basemap.py tests/test_m4b_imagery_removed.py tests/test_wizard_providers.py -q --tb=no -p no:cacheprovider`.
No other agent is active in either repo. Test runner for the stack = `.venv_local` (never `uv run`).

## What goes (lead inventory, this hour — every hit verified by grep)
**API repo:** `weewx_clearskies_api/endpoints/geographic_features.py` (both routers: `GET /api/v1/geographic-features/tiles`,
`GET /api/v1/geographic-features/status`, `POST /setup/geographic-features/update`, `wire_geographic_features_settings`,
`_check_proxy_auth`); `weewx_clearskies_api/services/geographic_features.py` (download/extract/status helpers);
`app.py:56-57` imports, `:143`, `:198`, `:211` `include_router` calls; `__main__.py:84` import + `:955` wiring call;
`config/settings.py` `GeographicFeaturesSettings` (`:696–748`), the `Settings.geographic_features` field/param/
construction/validate (`:1536`, `:1574`, `:1608–1610`, `:1643`) and the load-time `cfg.get("geographic_features")`
(`:1752`, `:1798`); `CONFIG.md` `[geographic_features]` section; comment-only mentions in
`services/basemap_extract.py:3,12,235,291` and `endpoints/basemap.py:4-7,19,23,74` and
`tests/test_endpoints_basemap.py:11` (reword to history — the basemap code does NOT import the old module).
**Stack repo:** `admin/routes.py` — the `_fetch_geographic_features_status()` helper (`:297–31x`), the landing
card `section_id "geographic-features"` (`:968–972`), the landing status rows (`:1143–1156`), the two routes
`GET /admin/geographic-features` / `POST /admin/geographic-features/update` (`:1633–1675`), and the docstring
lines `:30–31`; `templates/admin/geographic_features.html`; the help keys `help.admin.geographic_features.*`
in all 13 `translations/*.json` (count per file in the closeout); `docs/OPERATOR-MANUAL.md` mentions; CHANGELOG.
`templates/admin/marine.html:5` mentions the template name in a comment only — reword.
**Meta:** `docs/contracts/openapi-v1.yaml` — the three `deprecated: true` paths added by D1 (`ee6cb141`) are REMOVED;
`docs/manuals/API-MANUAL.md` §12c → one-line removal note; `docs/ARCHITECTURE.md`, `OPERATIONS-MANUAL.md`
(config-key table + a migration note: the legacy `[geographic_features]` api.conf section is inert and may be
deleted; the old single PMTiles file on disk may be deleted — name its path from `services/geographic_features.py`),
`PROVIDER-MANUAL.md`, `DASHBOARD-MANUAL.md` mentions → history/removal notes; ADR-078 Amendment 2: one sentence
"removal landed <hashes> 2026-08-27"; CHANGELOG (meta).
**STAYS:** everything `basemap` (M1) — it mirrors but does not import the old code; `[basemap]` settings.

## Lead mechanics (binding)
1. **Config migration, not a crash.** api.conf on weewx still carries `[geographic_features]`. The loader must
   ignore it silently (same as `[imagery]` after M4-B — verify the same code path; KAT: a conf with the section
   loads; no per-section warning). Nothing deletes the operator's on-disk file.
2. **Pure removal.** No surviving behaviour changes. `grep -rn -i "geographic.features" <repo>` after the round →
   API: 0 outside CHANGELOG/history comments; stack: 0 outside CHANGELOG.
3. **Tests (test-author):** API — no dedicated test file exists for the old feature (verify with grep; if one
   exists, delete it with the reason); NEW `tests/test_m5_geographic_features_removed.py`: legacy
   `[geographic_features]` conf loads and `Settings` has no `geographic_features` attr; the three routes are
   absent from `app.routes` (enumerate like `tests/test_openapi.py`); `GET /api/v1/geographic-features/status` → 404;
   `import weewx_clearskies_api.endpoints.geographic_features` → `find_spec` is None; `test_openapi.py` still
   passes against the amended contract. Stack — NEW `tests/test_m5_geographic_features_removed.py`:
   `GET /admin/geographic-features` → 404 for an authed client; landing section list has no
   `geographic-features`; no locale file contains `help.admin.geographic_features`; `admin/basemap` still renders.
   Pre-change evidence = the baselines + `git show <base>:<file>` (no live pre-change run is possible once the
   devs land; say so, never fabricate a transcript). Test-author writes and runs its guards at the pinned HEADs
   BEFORE telling the devs to start editing shared files.
4. Docs cite the commit hashes; ADR-078 header `status:` stays `Accepted` (it always was) and Amendment 2 gets
   the removal line.

## Scope / allowlists
`m5-api`: the API files above + `CHANGELOG.md` + the meta files above. `m5-stack`: the stack files above +
`docs/OPERATOR-MANUAL.md` + `CHANGELOG.md`. `m5-test`: the two new guard files + any dedicated old test it finds.
NOT to touch: anything `basemap`; the dashboard; the plan archive.
Verification: each repo's baseline + the guard file; `import ast` on edited Python; the grep of item 2;
render-and-look for the stack (admin landing shows no Geographic Features card; `/admin/basemap` still works).

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
`git stash`, `git checkout`/`git restore`/`git clean` of any path, or `git checkout` of remote branches.
You may only `git add <explicit paths>`, `git rm <explicit allowlisted paths>`, `git commit`, `git status`,
`git log`, `git diff`, `git show`. Never move, rename or delete a file outside your allowlist by any means —
including files your own tests produce, anything under `C:\etc\weewx-clearskies`, or anything on a container.
Before `git add` of any file, `git diff -- <file>` and confirm every hunk is yours. If the remote is ahead or
behind, STOP and report via SendMessage. Edit and commit ONLY on the local machine; SSH to containers is
read-only.

**Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your task
requires one, STOP and report via SendMessage — do not implement it, do not work around it, do not pick an
option. A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
**These do NOT authorize you:** "my task's acceptance criteria are unreachable without it", or "a plan/manual/ADR
says so". You MAY still: resolve a contradiction inside one document by its own examples; apply a rule already
written in the rules files; fix code that diverges from its own stated contract.
**The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via
SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval
exists, that statement is your full authorization.
*Coordinator statement:* deleting the ADR-078 single-file feature — the three endpoints, the service module,
the `[geographic_features]` config key, the admin section — (triggers 2 and 7) is operator-approved:
ADR-078 Amendment 2 is **Accepted** (2026-08-27; the plan's PA2 was the approval, operator in chat "that was
in the plan"). That is your full authorization for exactly those items. Touching anything `basemap` is NOT.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP and report
it via SendMessage — do not modify code to make it pass, and do not delete it on your own authority. Your
closeout lists every test modified or deleted, with the reason, and every guard that fired.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
