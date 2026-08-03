# Wizard resets study area — root-cause report (READ-ONLY investigation, 2026-08-03)

> Produced by the read-only Explore agent dispatched 2026-08-03 (decision item 8,
> AUDIT-OPUS-WINDOW-2026-08-03.md). Saved verbatim by the coordinator.

All line numbers are at HEAD: stack `2abb5ef`, api `b369ee6`. No files were modified.

---

## 0. Orientation — what "study area" is, in code

`docs/archive/MARINE-GEOMETRY-MODEL-PLAN.md:149`: *"The operator-drawn segment is for the **study area only**, never the facing."* So the "drawn surf study area" = the shoreline segment `segment_start_lat/lon` → `segment_end_lat/lon`, drawn by the two-click tool in `step_marine.html`, persisted in `api.conf [marine][[locations]][[[<id>]]][[[[surf]]]]`.

---

## 1. MECHANISM

### 1a. What the marine step pre-fills at GET-render, and from where

`GET /wizard/marine` is `step_marine_get()` — `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py:2867-2878`. **It reads nothing.** It calls `get_wizard_state(session_id)`, overlays the local photo sidecar, and renders. Every value on the marine step comes from `state.marine_locations` and nothing else.

`state.marine_locations` has **exactly one** population path from persisted config:

> `_merge_from_api_current_config()` — `wizard/routes.py:4889`, marine block at **`:5110-5210`** — fed by `GET /setup/current-config` (`api/endpoints/setup.py:2562`), whose `marine` field is a verbatim copy of api.conf's `[marine]` section (`setup.py:2838-2842`).

That function is invoked from **exactly one call site**: `wizard/routes.py:1285`, inside the `if rerun:` branch of `POST /wizard/step/1`.

Verified by executing the real code against a realistic api.conf-shaped `[marine]` section (in-memory only):

| Field | Restored by `:5110-5210`? | Rendered by template? |
|---|---|---|
| `segment_start/end_lat/lon` | **yes** (`surf_copy = dict(surf)`, `:5142`) — as ConfigObj **strings** | yes → hidden inputs `step_marine.html:193-196`; JS redraws `:1275-1282` |
| `bottom_type`, `topographic_feature` | yes | yes (`:198-218`) |
| `directional_exposure` | yes, normalised (C9b, `:5154-5202`) | yes (`:229-254`) |
| `surfbeat_enabled/cadence` | yes | yes (`:220-227`) |
| `structures` (type/material/length/bearing/distance) | yes — but **left as ConfigObj dict-of-dicts `{"0": {...}}`** | **NO — crashes**, see 1c |
| structure `coordinates` | yes (as JSON string) | **NO — template has no field for it**, see 1d |
| `transect_spacing_m`, `l3_enabled`, `max_hs_m`, `friction_coefficient`, `breaker_formula`, `surf_height_display` | restored into state | no UI |
| `[swan]` / TruShore knobs | **NO restore code anywhere** — `CurrentConfigResponse` has no `swan` field | hardcoded defaults rendered |
| imagery `api_key` | **NO** (`state.imagery_api_key` never restored) | renders `""` |

**No per-step fallback for marine.** Step 2 has `_merge_from_existing_config()` (`routes.py:4743`) as its fallback pattern; `wizard_index()`'s prior-progress merge (`routes.py:975-1098`) lists ~45 fields and **contains no marine field at all**.

### 1b. What apply writes, and what happens to fields rendered empty

- `step_marine_post()` `routes.py:2938-3007` rebuilds `surf_cfg` **from form fields only**; segment all-or-nothing (`:2949`); nothing merges with prior state.
- `build_marine_payload()` `wizard/config_writer.py:449-480` filters `surf` through an **explicit whitelist** (`:452-463`) that **omits `transect_spacing_m`, `l3_enabled`, `max_hs_m`**.
- API apply: `_write_api_conf()` `setup.py:1952-1965` does **`cfg["marine"] = new_marine`** — whole-section replace; only `_PRESERVE_KEYS = ("ndbc_station_ids", "coops_station_ids", "nws_marine_zone_id")` (`:1958`), location-level. **Nothing inside `[[[[surf]]]]` is preserved.**
- `_build_marine_conf_section()` `setup.py:1264-1323` writes surf from the Pydantic model → omitted fields come back at **model defaults** (`transect_spacing_m`→10.0, `l3_enabled`→"auto", `max_hs_m`→4.0 — `setup.py:579, 602, 617`); api.conf keys not on the model (e.g. `beach_slope`, still read by `:1496-1498`) are **deleted**.

### 1c. The precise path to a RESET study area

`segment_*` are **required** on `MarineSurfSpotApplyConfig` (`setup.py:569-575`) → an apply omitting them **422s**; it cannot silently blank them on disk. The reset is therefore a **GET-render failure**: the form came up with no segment, the operator redrew, and the *new* segment was written legitimately. Two live render-side paths:

**Path A — the merge never ran (blank card).** `_merge_from_api_current_config` is reachable *only* via `POST /wizard/step/1` **in rerun mode** (`routes.py:1285`; `_is_rerun_mode` `:801-815` needs pinned fingerprint + proxy secret). First-run branch (`:1302-1376`) never calls it; `GET /wizard/marine`, `wizard_index`, `step_features_post`→`step_marine_get` (`:2760`) never call it. `clear_wizard_state`/`delete_progress` (`state.py:374-379`) wipes progress after a successful apply, so a fresh re-entry starts empty and depends entirely on that one call site. Any re-entry not passing through a rerun-mode step-1 POST → `state.marine_locations == {}` → `step_marine.html:697-698` renders **zero location cards**.

**Path B — the merge ran and the marine step 500s.** `surf["structures"]` comes back as dict `{"0": {...}}` (empirically confirmed). Template: `{% for struct in surf.get("structures", []) %}` (`step_marine.html:276`) iterates **string keys** → `struct.get('type')` on a `str` → verified against real Jinja2: `RAISED UndefinedError 'str object' has no attribute 'get'`. **Any location with a persisted structure → correctly-pre-filled wizard re-run = HTTP 500 on the marine step.** Admin normalises via `_marine_structures_list()` (`admin/routes.py:1985-1992`); the wizard has **no equivalent**. The dict also reaches `build_marine_payload` unnormalised → would 422 against `structures: list` (`setup.py:590`).

The operator's box has a structure in api.conf → Path B armed. **Path A matches the observed symptom** (blank form, no error). Which fired on 2026-08-03 is not determinable from the repo — needs the config-service log (`get_current_config failed`/`network error` WARNING at `routes.py:4903/4906`, or a 500 on `GET /wizard/marine`).

### 1d. Bonus, same class, confirmed: the wizard drops structure `coordinates` on every re-run

E13 (`19d9332`) added the `coordinates` hidden input to **only the JS-built card** (`step_marine.html:829-832`) and the **admin** server render (`admin/marine.html:433-434`). **Never added to the wizard's server-rendered loop** (`step_marine.html:275-323` — no coordinates field). `step_marine_post` reads `loc_{n}_structure_{m}_coordinates` (`routes.py:2983-2992`), gets nothing → `setup.py:1317` writes none. Literally the admin clobber mechanism from DIAG-INV, except worse: admin round-trips coordinates when present; the wizard **never** does. INV-STRUCTURES' "wired through E13 persistence" claim is true only for the POST direction.

---

## 2. WHY TWICE

**No prior fix attempt for segment pre-fill exists.** `e670279 fix(wizard): hydrate marine config from API on re-run` (2026-07-11) is the only marine pre-fill commit — it predates the shoreline-segment UI (`4c0a8ed`) and structures-with-coordinates entirely; only C9b (`692ad76`) touched it since (directional_exposure only). The only written record of the defect is AUDIT-OPUS-WINDOW-2026-08-03.md:451-457.

**b369ee6 is the same defect CLASS, different mechanism** (provider-domain tuple on the API side); extending it literally does nothing for the segment. The marine path has three *independent* holes: single call site, dict/list shape mismatch, missing hidden field.

**Why CI is blind:** `tests/test_wizard_marine_structures.py` tests POST direction only; the one GET-render test (`tests/test_marine_exposure_override.py:340-365`) hand-seeds state with no `structures` key and float segment values — the shape the restore *doesn't* produce. Both paths invisible to CI (matches G6.3's "wizard had NO coordinates round-trip net at all").

---

## 3. FULL SILENT-RESET INVENTORY

### A — pre-fills correctly on re-run (given the Path-A precondition)
DB config · providers + credentials incl. imagery *provider* (b369ee6) · AQI · LibreWxR · marine service URL/TLS/secret · station · branding/social · earthquakes · column mapping · alert radius · marine location name/lat/lon/activities/NDBC/CO-OPS/zone · **segment start/end** · bottom type, topo feature, directional exposure, surfbeat · fishing, beach safety · units. (Cites: `routes.py:4913-5233`.)

### B — renders empty but harmless (nothing persisted to destroy)
imagery `api_key` (no write path at all — LM-3 finding 2, already tracked); `nws_srf_zone_id`/`nws_srf_wfo`/`ofs_*` (API recomputes at apply, `setup.py:1244-1262`).

### C — renders empty AND clobbers persisted state at apply *(the defect class)*

| # | Field / section | Render gap | Clobber at apply |
|---|---|---|---|
| C1 | **Study area segment** | Path A: no card; Path B: 500 before render | Not silent-on-disk (422-guarded); reset is operator-mediated: blank form → redraw → different geometry written |
| C2 | **Structure `coordinates`** | wizard server loop emits no input | read-nothing → write-nothing → whole-section replace ⇒ geometry gone ⇒ structure not L4-eligible ⇒ auto-L3 off (DIAG-INV inv-7 chain) |
| C3 | **Structures list** | dict-shaped restore → 500 (`step_marine.html:276`) | if past template: 422 (`setup.py:590`) |
| C4 | `transect_spacing_m` | no wizard UI | not in whitelist ⇒ reset to 10.0 |
| C5 | `l3_enabled` | no wizard UI (admin has it, `admin/routes.py:2366`) | not in whitelist ⇒ reset to "auto" |
| C6 | `max_hs_m` | no UI in wizard OR admin | in neither payload ⇒ reset to 4.0 on **every save from either surface** |
| C7 | `breaker_formula`, `surf_height_display` | no wizard UI | **admin** omits ⇒ admin save resets to `komar_gaughan`/`face` |
| C8 | `beach_slope` | nowhere | not on the model (`extra="forbid"`) ⇒ **deleted by any apply**, though `:1496-1498` still reads it |
| C9 | `[swan]`/TruShore (3 keys) | no restore possible (no response field) | wizard sends `swan` unconditionally (`routes.py:4209-4217`) ⇒ overwritten with rendered defaults |
| C10 | `bathymetric_profile` | no UI | survives only via the fragile restore; fails under Path A |
| C11 | `directional_exposure` | fixed (C9b) — still rides the single restore call site | — |

**Cross-cutting root cause:** `cfg["marine"] = new_marine` whole-section replace + wizard whitelist ⊂ API model ⊂ api.conf contents — three successively lossy filters in series.

---

## 4. REMEDIATION OPTIONS (not ranked — operator rules)

- **R1 — marine pre-fill fallback at the marine step** (mirror step 2's fallback pattern). *stack/wizard/routes.py.* Pure defect-fix; lifecycle-point nuance flagged (a UI read, not a computation — read as NOT trigger 5).
- **R2 — normalise `structures` dict→list in the restore** (mirror `admin/routes.py:1985-1992`). Fix-of-stated-contract; currently a live 500.
- **R3 — render the `coordinates` hidden input in the wizard server loop** (copy `admin/marine.html:433-434`). Completes E13 under the standing wizard/admin parity ruling; respects ADR-095 D3 (renders only when present, never fabricates).
- **R4 — widen wizard/admin whitelists** to round-trip `transect_spacing_m`, `l3_enabled`, `max_hs_m` (+admin: `breaker_formula`, `surf_height_display`) opaquely. No mechanical trigger, but hands the wizard ownership of model-behaviour knobs with no UI — design call flagged.
- **R5 — apply merge-not-overwrite inside `[[[[surf]]]]`** (surf-level preserve set / deep-merge). **Trigger 4** — inverts absence-semantics on the wizard→API contract for a subtree; changes what "delete in UI" means. Only option fixing C4-C8 generically.
- **R6 — restore `[swan]` on re-run**: add `swan` to `CurrentConfigResponse` (**trigger 4/7**) OR send-only-when-completed variant (no trigger, leaves visibility gap). Pick.
- **R7 — regression net**: GET-render round-trip KATs (api.conf-shaped section → merge → real GET → assert segment + coordinates in HTML → POST back → byte-identity). Already authorized under G6.3's round-trip-test grant.

## What needs an operator ruling vs what is fix-of-authorized-mechanism

**Fix-of-authorized-mechanism (no ruling needed):** R2, R3, R1 (nuance flagged), R7.
**Needs ruling:** R5 (trigger 4); R6 (which variant); R4 + C6/C8 ownership (`max_hs_m` reset to 4.0 by BOTH surfaces every save; `beach_slope` deleted by any apply — wizard-owned / admin-owned / untouchable?).
**Sequencing:** R1 alone turns Path A's blank form into Path B's 500 on the operator's live config (structure present) — **R1 and R2 must ship together**, or R2 first.

**Diagnostic still open:** which path fired 2026-08-03 — resolvable from the config-service log (WARNING at `routes.py:4903/4906` vs 500 on `GET /wizard/marine`).

**Line-drift notes:** wizard draw control now `step_marine.html:1285-1394` (end +26 from G6.3); `tests/test_wizard_marine_structures.py:7`'s cite of `routes.py:2961-2996` exact at HEAD.
