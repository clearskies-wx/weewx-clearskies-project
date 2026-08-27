# M1-API brief — CS-BASEMAP, API side (weewx-clearskies-api repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M1 (API round; M3/M4 dashboard rounds follow;
the stack admin page is its own round). Date 2026-08-27. Lead: coordinator. Teammates:
`clearskies-api-dev` (code) + `clearskies-test-author` (tests). Auditor: `clearskies-auditor`,
adversarial, results-free gate file `scratch/GATE-M1-API-DEFINITION.md` (lead-written; teammates
never edit it).

**Pre-round verification (lead, 2026-08-27):** API repo `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`
HEAD `cf0318d` on `main`, clean, 2 commits ahead of origin (S10 fog reverts, unpushed — expected).
`pmtiles` CLI v1.30.3 at `/usr/local/bin/pmtiles` on weewx (supports `--minzoom`); live
`/api/v1/geographic-features/status` → `{"available":true,"size_bytes":36309923,...}` (the ADR-078
file exists and stays untouched this round). Live station 33.65683/−117.98267, quake radius 200 km,
2 marine locations, radar bounds `26.75,-129.5,40.75,-105.5` (M0 agent, live API, 2026-08-27).
Tests for the API repo run on weewx normally; unpushed code can only be tested locally this round
— use the repo's venv on this machine if present (`ls .venv*`), else `uv run --frozen pytest` locally;
state which in your closeout. Host rerun owed after the push (journal J5).

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` → §"M1 — CS-BASEMAP" (the whole block: extent
derivation, radar tier, files, endpoint family, admin, dashboard paragraph for context, ADR-078
paragraph, and **Lead mechanics — API side**), PRIME DIRECTIVE 13–15, PRE-APPROVAL PA2. Every
sentence of "Lead mechanics — API side" is binding.

## Scope — api-dev
**Files you may create/modify (exhaustive):**
- NEW `weewx_clearskies_api/services/basemap_extract.py`
- NEW `weewx_clearskies_api/endpoints/basemap.py`
- `weewx_clearskies_api/config/settings.py` — add `BasemapSettings` (`[basemap] enabled`), wire it
  into `Settings.__init__`/`validate()`/`load_settings()` exactly where `GeographicFeaturesSettings`
  is wired (`:695–748`, `:1573`, `:1610`, `:1644`, `:1679`, `:1788`, `:1834`). Do NOT remove
  `GeographicFeaturesSettings`.
- `weewx_clearskies_api/app.py` (`:54–56`, `:139–141`, `:193–205` pattern) and
  `weewx_clearskies_api/__main__.py` (`:83`, `:986–988` pattern) — mount + wire.
- `CHANGELOG.md`, `CONFIG.md` (the `[basemap]` key) in the API repo.
- `etc/` example config(s) that carry `[geographic_features]` — add `[basemap]` beside it (grep first).
**Files NOT to touch:** `endpoints/geographic_features.py`, `services/geographic_features.py`
(they stay live until the ADR-078 amendment is accepted — journal J3); `endpoints/imagery.py` and
`providers/imagery/*` (M4 is a later round); `tests/` (test-author); the stack and dashboard repos;
`docs/` in the meta repo (docs-author round follows; you only list what must change in your closeout).

**Named traps:** (1) no operator-typed box, no zoom keys — `[basemap]` has ONE key (directive 14,
PRIME DIRECTIVE 11). (2) The radar tier's box comes from `settings.radar.librewxr_bounds` ONLY
(read `RadarSettings` `:783–840` and `providers/radar/librewxr.py` `configure()` for the string's
order — do not guess; the capability publishes it as `[[south, west], [north, east]]`). (3) The
marine locations come ONLY through `companion_proxy.marine_discovery_get("/marine", {})` — never
from `settings` (the API does not hold them in remote mode) and never from a direct URL. Read
`repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/marine.py:417` for the response
shape. (4) Marine configured but unreachable → the extract refuses with a named error in
`last_error`; it does NOT fall back to the seismic box. (5) One background thread, never two;
`start_extract_in_background()` returns `False` when one is running. (6) Never write outside
`/etc/weewx-clearskies/` (rules/coding.md §1 API constraint 1). (7) Do not modify the ADR-078
endpoints' behaviour in any way.

**Verification command (before closeout):** `pytest tests/test_basemap_extract.py tests/test_endpoints_basemap.py tests/test_wire_imagery_settings.py tests/test_config_settings_imagery_validation.py -q --tb=short` (run from the API repo root with the local venv or `uv run --frozen`; paste the raw output) plus `ruff check weewx_clearskies_api/services/basemap_extract.py weewx_clearskies_api/endpoints/basemap.py weewx_clearskies_api/config/settings.py` clean.

**Deliverable:** commits on API `main` (local; never push) — module, endpoint, settings, wiring,
CHANGELOG/CONFIG; closeout with the exact `[basemap]` semantics, the computed bounds for THIS install
(call `compute_local_bounds()` against the live config values above and paste the string), and the
list of meta-repo doc sections the docs round must update.

## Scope — test-author
**Files:** NEW `tests/test_basemap_extract.py`, NEW `tests/test_endpoints_basemap.py`. Nothing else.
- Bounds KAT (rules/verification.md known-answer mandate): compute the seismic box for station
  33.65683/−117.98267, radius 200 km × 1.15, by an INDEPENDENT route (e.g. `pyproj`/`geopy` if
  present in the venv, else a hand-derived haversine inverse — not the module's own arithmetic) and
  assert the module's box matches to 1e-3°; the marine 40-px pad at z15/lat 33.66 computed
  independently (156543.03·cos(lat)/2^15 m per px); the union; the radar box passthrough; the
  no-marine case (seismic only); the unreachable-marine case (raises, no file written — patch
  `marine_discovery_get` to raise `MarineDiscoveryUnavailableError`).
- Endpoints: `GET /api/v1/basemap/local/tiles` with a `Range` header → 206 + `Accept-Ranges: bytes`
  (use `tmp_path` and monkeypatch the file path constant — never `/etc`); unknown tier → 404;
  missing file → 404 JSON; `GET /api/v1/basemap/status` shape (all three tiers present,
  `updating: false`, `last_error: null` on a fresh state); `POST /setup/basemap/update` → 503 with
  no secret, 401 wrong secret, 202 `{"status":"started"}` with the extractor patched to a no-op
  thread, 409 while `updating` is true.
- Pre-change failure transcript in the module docstring (tests written first, run at `cf0318d`,
  fail on import/404; then re-run after the dev commits).
**Verification command:** the same pytest line as the dev's. Deliverable: commits on API `main`.

## Reading list (both, in order)
1. Plan §M1 (whole block) + PRIME DIRECTIVE 13–15 + PA2.
2. `docs/decisions/ADR-078-geographic-features-overlay.md` (the feature being generalised).
3. `docs/manuals/API-MANUAL.md` — grep `geographic-features` and `imagery` for the sections that
   describe the pattern; `docs/manuals/OPERATIONS-MANUAL.md` §4 "File inventory" (`:537`).
4. `weewx_clearskies_api/services/geographic_features.py` (whole), `endpoints/geographic_features.py`
   (whole) — the mechanics to reuse; `config/settings.py:626–660` (earthquakes), `:695–748`,
   `:783–840` (radar), `:1560–1700`, `:1780–1840`.
5. `weewx_clearskies_api/services/companion_proxy.py:385–432` (`marine_discovery_get`) and
   `:160–215` (state/errors); `services/station.py` (`get_station_info()`); `endpoints/earthquakes.py:280–370`
   (how station lat/lon and radius are read today — mirror it).
6. `weewx_clearskies_api/app.py:40–210`, `__main__.py:75–90`, `:560–600`, `:980–990`, `:1060–1070`.
7. `rules/coding.md` §1 (API security constraints 1, 4), §3 DRY, §12.
8. Existing tests to mirror: `tests/test_wire_imagery_settings.py`, `tests/test_endpoints_imagery_integration.py`,
   and any `tests/*geographic*` file (grep).

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
*Coordinator statement for this round:* the new endpoint family, the `[basemap]` config key, the
three persisted `basemap-*.pmtiles` files and the background extract thread (triggers 7, 4, 5) are
operator-approved — plan PA2 (operator rulings 2026-08-27, EVO-Q18/Q6/Q5/Q8). That statement is your
full authorization for exactly those items and nothing else.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first (SendMessage to the lead), then proceed — pre-confirmed unless your ack names a
file outside the allowlist. Status every ~4 minutes. Closeout per your agent definition with raw
command output.
