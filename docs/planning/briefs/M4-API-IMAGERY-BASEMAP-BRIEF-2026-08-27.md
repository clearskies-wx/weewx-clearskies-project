# M4-API brief — surf height map background: `/imagery/config` answers with the product basemap (PA9)

**Round identity:** MARINE-AND-MAPS-PLAN Phase M, task M4 (API side). Date 2026-08-27. Lead:
coordinator. Teammates: `clearskies-api-dev` (code) + `clearskies-test-author` (tests). Auditor:
folded into Gate M (results-free rows to be added to `scratch/GATE-M4-DEFINITION.md`).

**Pre-round verification (lead, 2026-08-27):** API repo HEAD `346ae13` on `main`, clean (M1-API +
gate fix landed; unpushed as expected). Baseline: `.venv\Scripts\python.exe -m pytest tests/test_endpoints_imagery_integration.py tests/test_wire_imagery_settings.py tests/test_config_settings_imagery_validation.py tests/test_current_config_imagery_prefill.py -q -p no:cacheprovider`
→ the dev measures and pastes the count BEFORE any edit.

## The design — read it at the source
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` §"M4 — SURF-MAP-BASEMAP … lead mechanics"
(the **API** bullet is your spec: provider `"basemap"` regardless of `[imagery] provider`, the
response shape with `light`/`dark`/`zoomMin`/`zoomMax`, legacy top-level fields carrying the light
values, one startup WARNING naming the ignored value, `/imagery/tiles` untouched), PA9, directive 15,
Q5, Q10-6 (OPEN: modules/key/admin/wizard stay).

**Lead mechanics (binding):**
- `endpoints/imagery.py`: `get_imagery_config()` no longer 404s when `[imagery]` is absent and no
  longer calls `_select_provider()`; it returns `ImageryConfigResponse(provider="basemap",
  tileUrl=<OSM light template with {s}→a>, attribution=<OSM attribution string — reuse the constant
  the marine light maps use if one exists in the API, else the OSM copyright string>,
  proxyMode="direct", bounds=None, light={tileUrl, attribution}, dark={pmtilesUrl:
  "/api/v1/basemap/local/tiles", maxDataZoom: 15, attribution: "© OpenStreetMap contributors ©
  Protomaps"}, zoomMin=0, zoomMax=19)`. `wire_imagery_settings()` keeps reading `[imagery]` and logs
  ONE WARNING at wiring time when `provider` is set: "[imagery] provider=<v> is no longer used by any
  user-facing surface (PA9, 2026-08-27); the surf height map draws the product basemap". The
  `/imagery/tiles/{z}/{x}/{y}` NAIP proxy and `_select_provider()` (still used by the tile proxy's
  404 logic) stay as they are. `_MAX_ZOOM` stays 20 for the proxy; the config's `zoomMax` is 19
  (the surf map's own ceiling).
- `models/responses.py`: `ImageryLightSource(tileUrl, attribution)`, `ImageryDarkSource(pmtilesUrl,
  maxDataZoom, attribution)`; `ImageryConfigResponse` gains optional `light`, `dark`, `zoomMin`,
  `zoomMax` (additive; `provider` docstring gains `"basemap"`).
- `docs/contracts/openapi-v1.yaml` (meta repo): the `/imagery/config` response schema gains the new
  optional fields; `docs/manuals/API-MANUAL.md` §12a rewritten to the as-built (basemap answer;
  the naip/esri/map providers noted as no longer reachable from user-facing surfaces; Q10-6
  pending); CHANGELOG (meta + API repo).
- `providers/imagery/*` capability registration in `__main__.py` (`:589–600`): UNTOUCHED (Q10-6).

## Scope — api-dev
**Allowlist:** `weewx_clearskies_api/endpoints/imagery.py`, `weewx_clearskies_api/models/responses.py`
(the imagery models only), `CHANGELOG.md`; meta docs listed above (separate commit).
**NOT to touch:** `providers/imagery/*`, `config/settings.py` (`ImagerySettings` stays), `__main__.py`,
the stack/dashboard repos, tests/.
**Named traps:** never 404 the config (the surf map must always get a basemap); the dark
`pmtilesUrl` is the LOCAL tier (the surf map lives inside the local box by construction); the
legacy fields must still validate for an old client; the WARNING fires once (wiring), not per request.
**Verification:** the baseline command + the test-author's updates.

## Scope — test-author
**Allowlist:** `tests/test_endpoints_imagery_integration.py`, `tests/test_wire_imagery_settings.py`
(both pin the naip/esri/map decision tree — STALE BY DESIGN for `/imagery/config` only; the
`/imagery/tiles` assertions stay), NEW `tests/test_imagery_config_basemap.py` (config shape for
`[imagery]` absent / `provider=naip` / `provider=map`; the legacy fields; the WARNING logged once at
wiring with `caplog`; `/imagery/tiles` behaviour unchanged for `provider=naip`). List every changed
assertion with its reason; pre-change failure transcript in the new module's docstring.

## Reading list (both)
Plan §M4 + PA9 + Q5 + Q10-6; `docs/manuals/API-MANUAL.md` §12a; `weewx_clearskies_api/endpoints/imagery.py`
(whole, 326 lines); `models/responses.py:1429–1449`; `tests/test_endpoints_imagery_integration.py`,
`tests/test_wire_imagery_settings.py`; `repos/weewx-clearskies-dashboard/src/hooks/useImageryConfig.ts`
+ `src/api/types.ts:2308–2350` (the consumer — the dashboard round M4-DASH follows);
`rules/coding.md` §1 (trust boundaries), `rules/verification.md` "Stale tests".

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
*Coordinator statement:* the `/imagery/config` response change and the un-wiring of the
`[imagery] provider` selection from the user-facing surf map (triggers 2, 4) are operator-approved —
plan PA9 (Q5, 2026-08-27: "get rid of the orthophotography for the surf height map and replace it
with a regular basemap"). Removal of the modules/key/admin/wizard is NOT authorized (Q10-6 open).

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing. *For this round the lead pre-identifies the `/imagery/config` provider-selection
assertions in the two named test files as stale-by-design; the test-author updates them.*

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
