# Deployment Fix-It List

Bugs and issues found during end-to-end deployment testing (2026-05-26).
Items marked FIXED were resolved in-session or in follow-up commits. Open items need follow-up work.

---

## Open

None. All items resolved.

---

## Fixed (follow-up commits)

### 1. Wizard re-run overwrites column mappings
**Severity:** High — loses operator work  
**Found:** Wizard apply sent auto-detected default column mappings, overwriting any customizations the operator made in a previous run.  
**Root cause:** The column mapping step re-ran auto-detection instead of reading back from the existing `api.conf`. Persisted wizard state did not preserve column_mapping between sessions.  
**Fixed:** Inverted key bug in `populate_from_config` corrected. Steps 2 and 3 now merge instead of replace. 11 new tests added.  
**Repos:** stack

### 2. Wizard apply should back up config before overwriting
**Severity:** Medium — safety net for data loss  
**Found:** `api.conf` was overwritten with no backup.  
**Fixed:** API commit `989c9ab` — `.bak` copy written before `api.conf` write. Stack commit `1ed5e18` — `.bak` copies written before `realtime.conf`, `stack.conf`, and `secrets.env` writes.  
**Repos:** API (setup.py), stack (config_writer.py)

### 3. No `[units]` subsections written to `realtime.conf`
**Severity:** Low — works with defaults, but imported subsections discarded  
**Found:** `write_realtime_conf` only wrote `[units][[groups]]`. Custom string_formats, labels, and ordinates imported from skin.conf were lost in `realtime.conf`.  
**Fixed:** Stack commit `1ed5e18` — `write_realtime_conf` now writes `[[string_formats]]`, `[[labels]]`, and `[[ordinates]]` from imported skin.conf. UTF-8 encoding fix included.  
**Repos:** stack (config_writer.py)

### 4. Column mapping "leave blank to skip" copy is ambiguous
**Severity:** Low — UX confusion  
**Found:** `step_schema.html` said "leave blank to skip" in 4 places. Actual behavior is "leave unmapped — exclude from API output."  
**Fixed:** "leave blank to skip" → "leave blank to exclude from API" throughout. Dropdown default option changed to `— not mapped —`.  
**Repos:** stack (templates/wizard/step_schema.html)

### 5. BFF REST proxy doesn't apply string formatting (rounding)
**Severity:** High — ugly raw floats on initial page load  
**Found:** On page load, dashboard `/api/v1/current` responses showed raw floats (68.82677966101694). SSE data arrived correctly rounded. The BFF REST proxy converted units but did not apply StringFormats rounding.  
**Fixed:** Realtime commits `3917276`, `94bc25b`, `c2ac993`, `f799fe2` — proxy now detects `{data, units}` envelope, infers unit system, applies `transform_record` with formatting, and flattens to scalar values.  
**Repos:** realtime (proxy.py)

### 6. Solar radiation and other values show floating point artifacts
**Severity:** Medium — ugly numbers  
**Found:** Solar radiation showed `349.73300000000006` (IEEE 754 artifact). Pass-through groups (radiation, humidity, UV) did not get `format_value` applied.  
**Fixed:** Same commits as #5, plus commit `498dbcc`. Pass-through groups now receive `format_value`. Format precision: radiation `%.1f`, barometer `%.2f`.  
**Repos:** realtime (units/transformer.py)

### 7. Weather description "Clear" when it's overcast/partly cloudy
**Severity:** High — visible incorrect information  
**Found:** Dashboard showed "Clear and Gentle Breeze" under overcast/partly cloudy conditions. Sky condition logic used naive single-reading Kt thresholds without temporal analysis.  
**Fixed:** ADR-044 implemented — 2D classification (mean kc + σ variability) over 30-min rolling window, solar radiation as primary source, provider as night fallback. ADR-044 accepted.  
**Repos:** API, realtime (BFF), stack

### 8. Partly cloudy detection needs temporal sampling
**Severity:** Medium — design improvement  
**Found:** Single-reading kc could not distinguish thin uniform overcast from broken cumulus.  
**Fixed:** Via ADR-044 — rolling 30-min window with σ(kc) > 0.10 threshold separates stable (stratus) from intermittent (cumulus) skies. New `sky_condition.py` module in BFF.  
**Repos:** realtime (BFF)

---

## Fixed in-session

### F1. SKIN_ROOT relative path not resolved
**Severity:** Blocker — skin.conf import and generation both failed  
**Found:** weewx.conf says `SKIN_ROOT = skins` (relative). API used literal string instead of resolving against weewx.conf directory.  
**Fixed:** commit `93738fc` (API) — `Path.is_absolute()` check, resolve against `Path(wconf.filename).parent`

### F2. Permissions on /etc/weewx/skins/ClearSkies/
**Severity:** Blocker — skin.conf write failed with PermissionError  
**Found:** API runs as `ubuntu`, skins dir owned by `weewx:weewx`. ClearSkies dir didn't exist.  
**Fixed:** Added `ubuntu` to `weewx` group, created dir with `2775` perms. Long-term: API installer/bootstrap should handle this.

### F3. Wizard apply wiped BFF proxy config
**Severity:** Blocker — all API calls through BFF stopped working  
**Found:** `write_realtime_conf` only wrote `[sse]`, `[input]`, `[units]` — the manually-added `[api]` section was lost.  
**Fixed:** commit `ade5259` (stack) — `write_realtime_conf` now writes `[api]` section from `state.api_address`.

### F4. Import step file upload doesn't work on headless
**Severity:** High — primary import path was broken for headless installs  
**Found:** File browse button opens the operator's local machine, not the server where skin.conf lives.  
**Fixed:** commit `9764141` (stack) — Moved import to step 2 (after API connect). Primary UX is now a skin-name text field that fetches via API. File upload kept as collapsible fallback.
