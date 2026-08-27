# M1-STACK brief — Basemap admin section (weewx-clearskies-stack repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M1 (admin page). Date 2026-08-27. Lead:
coordinator. Teammate: `clearskies-dashboard-dev` (owns ALL UI surfaces including the stack config
UI — operator-confirmed routing 2026-08-03). Auditor: folded into Gate M (results-free rows in
`scratch/GATE-M1-DASH-DEFINITION.md` will gain an admin row; you never edit gate files).

**Pre-round verification (lead, 2026-08-27):** stack repo
`c:\CODE\weather-belchertown\repos\weewx-clearskies-stack` HEAD `940047f` = origin/main, clean. The
API endpoints this page calls (`GET /api/v1/basemap/status`, `POST /setup/basemap/update`) are being
built concurrently (M1-API round) to the contract in the plan; they are NOT deployed — you test with
the stack's existing unit-test pattern (mocked API client, `tests/test_admin_*.py`).

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §M1 ("Admin page: one 'update basemap' action +
status"; "Lead mechanics — API side" for the exact status/update response shapes:
per-tier `{available, size_bytes, updated_at, bounds, minzoom, maxzoom}` + `updating`, `last_error`,
`last_started_at`, `last_finished_at`; POST → 202 `{"status":"started"}` / 409
`{"status":"already_running"}`). ADR-078's admin section STAYS this round (additive build — journal
J3); the basemap section is added beside it.

**Lead mechanics — stack (binding):**
- `admin/routes.py`: `_fetch_basemap_status()` mirroring `_fetch_geographic_features_status()`
  (`:297–311`) against `/api/v1/basemap/status`; a new `ADMIN_SECTIONS` entry directly after the
  `geographic-features` one (`:965–971`): `section_id "basemap"`, display name "Basemap", group
  `advanced`, url `/admin/basemap`, description "The map ground under every Clear Skies map: world,
  local and radar tiers extracted from OpenStreetMap data (Protomaps)."; landing summary rows
  (`:1134–1148` pattern) → `custom_landing_values["basemap"]` = one row per tier ("World"/"Local"/
  "Radar": "Available (N MB)" | "Not extracted") plus "Updating…" when `updating`; routes
  `GET /admin/basemap` and `POST /admin/basemap/update` mirroring `:1607–1649`, except: the POST
  handles 202 → flash "Basemap update started — this page refreshes while it runs.", 409 → flash
  "A basemap update is already running.", any other error → the existing error path.
- `templates/admin/basemap.html`: mirror `geographic_features.html` structure (breadcrumb, `<h2>`,
  `help_trigger("/admin/help/basemap")`, intro paragraph, flash, status section, update section,
  back button). Status section = a table with one row per tier: Tier | Availability (the same
  green/grey dot pattern) | Size (MB) | Zoom range (`minzoom–maxzoom`) | Last updated (date).
  Above it: when `status.updating` is true, a `role="status"` line "Update in progress (started
  {last_started_at})" and the section root carries `hx-get="/admin/basemap"
  hx-trigger="every 10s" hx-target="#admin-content" hx-swap="innerHTML"` so it refreshes until
  done; when `status.last_error` is set, a `role="alert"` warning quoting it. Update section: the
  button is `disabled` while `updating`; hint text: "Extracts three files on the API host (world,
  local, radar) from the Protomaps daily build — typically under a minute; the local file for this
  install measured about 500 MB." Every string through `_()`.
- Help content: `help.admin.basemap.title/body/tip` keys in ALL 13 translation files, mirroring the
  `help.admin.geographic_features.*` keys (`translations/en.json:1236–1238`) — the `body` explains,
  in plain English, that every Clear Skies map (marine, seismic, radar/satellite, surf height map)
  draws its dark-theme ground and its labels from these files, that the extent is derived from the
  station, the earthquake radius and the marine locations (never typed), and that the radar tier
  covers the radar provider's coverage box; the `tip`: run once after setup, re-run after changing
  the station location, earthquake radius, marine locations or radar bounds.
- `docs/OPERATOR-MANUAL.md` (stack repo): a "Basemap" subsection beside the Geographic Features one,
  same content as the help body/tip; CHANGELOG entry.
- Tests: `tests/test_admin_basemap.py` mirroring `tests/test_admin_status.py`/`test_admin_imagery.py`
  patterns — GET renders the three tier rows from a mocked status; POST 202 → started flash; POST
  409 → already-running flash; `updating: true` → button disabled + polling attribute present;
  `last_error` → alert shown. (You own these tests — dashboard-dev writes stack tests in this repo
  per the existing admin-round precedent.)

## Scope
**Allowlist (exhaustive):** `weewx_clearskies_config/admin/routes.py`,
`weewx_clearskies_config/templates/admin/basemap.html` (new), the 13 `weewx_clearskies_config/translations/*.json`
(the three new keys only), `docs/OPERATOR-MANUAL.md`, `CHANGELOG.md`, `tests/test_admin_basemap.py` (new).
**NOT to touch:** `geographic_features.html`, the geographic-features routes/help keys (stay until
the ADR-078 amendment is accepted), wizard templates/routes, `config_writer.py`, `state_persistence.py`,
any other template, the API/dashboard repos, meta-repo docs.
**Named traps:** no operator-typed bounds or zoom fields on the page (directive 14; PRIME DIRECTIVE 11);
no direct call to the marine service; no new config key; a11y — the table has `<th scope="col">`,
the status dot pattern keeps its `aria-label`, `role="status"`/`role="alert"` as above.
**Verification command:** from the stack repo root, its documented test invocation (read
`DEVELOPMENT.md`; local venv if present else `uv run --frozen pytest`) for
`tests/test_admin_basemap.py tests/test_admin_status.py -q --tb=short`; render the page once
(the stack app's dev run per `DEVELOPMENT.md`, API mocked or unreachable → the "Status unavailable"
path must render cleanly) and screenshot it to `scratch/m1-stack-renders/basemap.png`; Read it and
describe it.

## Reading list
1. Plan §M1 (whole) + PRIME DIRECTIVE 13–15 + PA2.
2. `weewx_clearskies_config/admin/routes.py` `:1–60`, `:290–320`, `:900–1000`, `:1100–1160`, `:1600–1650`;
   `templates/admin/geographic_features.html` (whole); `templates/macros/help_panel.html`; the help
   route that serves `/admin/help/<section>` (grep `help/` in `admin/routes.py`);
   `translations/en.json:1230–1240`; `tests/test_admin_status.py`, `tests/test_admin_imagery.py`;
   `docs/OPERATOR-MANUAL.md` (grep "Geographic Features"); `DEVELOPMENT.md`.
3. `rules/coding.md` §5 (a11y), §6.3 (wizard/admin i18n), §4 (render and look).

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
*Coordinator statement for this round:* the new admin routes/section consuming the new API
endpoints (trigger 7) are operator-approved — plan PA2 ("Admin page: one 'update basemap' action +
status"). That statement is your full authorization for exactly those items and nothing else.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first, then proceed (pre-confirmed unless the ack names a file outside the allowlist).
Status every ~4 minutes. Closeout per your agent definition with raw outputs and the render description.
