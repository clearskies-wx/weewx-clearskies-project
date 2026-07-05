# Pinned Items Execution Plan

**Status:** COMPLETE — All 8 phases executed, QC passed at every gate (2026-07-04)
**Created:** 2026-07-04
**Components:** Config UI (`weewx-clearskies-stack`), API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`)
**Items covered:** Pinned Items 1–17, 19–23 (22 of 23)
**Not in scope:** 18 (Volcanic monitoring — research completed, deferred to a future plan)

---

## Context

During a review of the live site and wizard flow, 23 items were identified that need to be addressed. These range from dead code removal to new features to performance fixes. This plan turns those items into phased, granular tasks with agent assignments, QC gates, and acceptance criteria — modeled on the UI-Legal-Wizard plan.

Item 18 (volcanic monitoring) research is complete but deferred to a future plan. Item 17 (seismic enhancements) research is complete and included as Phase 7.

**No deferrals.** Every item in this plan is mandatory. The coordinator does not have authority to skip items.

---

## 0. Orientation — Execution Context

**Read before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — WCAG, build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — system topology, ports, routing, config files

**Repos:**
- `repos/weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`.
- `repos/weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Branch: `main`.
- `repos/weewx-clearskies-stack` — Config wizard + admin (FastAPI + Jinja2 + HTMX + Pico CSS). Branch: `main`.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- Wizard: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warmup)

**Agent model:** Lead = Opus (orchestration + QC). Teammates = Sonnet (implementation). Lead reads all relevant code before writing agent briefs. QC is per-phase, not batched.

---

## 1. Research Findings (Pre-Plan)

These findings were established during planning and inform the task specs below.

### Wizard Structure
- Steps are named by function (`step_db.html`, `step_units.html`), not numbered.
- Step order is defined in `_progress_bar.html` (a `step_names` array + `step_url` macro).
- Routes use mixed scheme: some numbered (`/step/1`, `/step/2`), some named (`/wizard/units`, `/wizard/eula`).
- POST handlers chain via direct function calls (e.g., `step_units_post` calls `step6_get(request)`).
- Step headings are hardcoded in templates ("Step 6 of 15 — Station Identity") and in 13 translation JSON files.
- **Dead step:** "Step 8: Realtime" appears in `_progress_bar.html` but has NO route handler. The Units step's "Next" button points to this nonexistent route. Must be removed.

### File Upload Pattern (reusable for items 1, 13, 19)
- Upload rules dict: `_BRANDING_UPLOAD_RULES` in `routes.py` — maps field name to `(allowed_exts, allowed_mimes, max_bytes)`.
- Handler: `_handle_branding_upload(form, field_name)` — validates, sanitizes filename, writes to `{config_dir}/branding/`, returns URL.
- Template: `hx-encoding="multipart/form-data"` on form + `<input type="file">`.
- Storage: `{config_dir}/branding/` directory, served via StaticFiles mount at `/wizard/branding/`.

### Item 15 Root Cause — CSS Class Mismatch
- `form_fields.html` macro outputs: `accent-swatches`, `swatch-label`, `swatch`
- `layout.html` CSS targets: `accent-swatch-group`, `accent-swatch-label`, `accent-swatch-circle`
- Selectors don't connect → fields render as unstyled native radio buttons.
- Same issue for theme mode: CSS targets `.theme-radio-card` but macro outputs plain `<fieldset>`.

### Item 10 — AQI Regional Scale Support
- **Aeris**: 8 scales (airnow, china, india, eaqi, caqi, uk, de, cai). Config: `aeris_aqi_filter`.
- **IQAir**: 2 scales (us, cn). Config: `iqair_aqi_scale`.
- **Open-Meteo**: 2 scales (us_aqi, european_aqi). Config: `openmeteo_aqi_index`.
- **OWM**: No regional config (being removed anyway).
- **OpenAQ**: No regional config (being removed anyway).
- Wizard already has `step_aqi_regional_fields.html` that loads per-provider selectors via HTMX.

### Item 21 Root Causes — Dashboard Performance
- **Excessive reloading:** All data lives in component-local `useState` (no React Query, no SWR, no context cache). When route components unmount, all data is destroyed and re-fetched. The `/radar` route sits OUTSIDE `AppLayout`, so navigating there unmounts the entire app shell.
- **Background flash:** Module-level `SCENE_DEFAULT` constant computed once at import from localStorage. Becomes stale after scene changes (sunset/sunrise). When `AppLayout` remounts, stale default is used until API responds → visible flash → 1.2s cross-fade. The `visible` prop on `SceneBackground` was designed to prevent this but is not wired up. Two copies of `getCachedScene()` use inconsistent parsing logic.

### Alert Provider Coverage (Item 12)
- **NWS**: US + territories + marine zones. Keyless.
- **Xweather (Vaisala Xweather)**: US, Canada, Europe (MeteoAlarm), UK, Japan, Australia, India, Brazil, South Africa, South Korea, Mexico. Requires API key.
- **OWM**: Global. Requires paid "One Call" subscription.
- **Open-Meteo**: Does not provide alerts.

### OWM AQI Status (Item 7)
- Fully working code wired into dispatch + endpoints (not just a deprecation stub).
- Returns SILAM model predictions, NOT observed PM data. Not a valid AQI provider.
- Must be removed from: dispatch table, endpoint dispatch, module file, `__init__.py`.

### OpenAQ Status (Item 8)
- Module exists but is NOT wired into dispatch registry. Dead code for AQI flow.
- Wizard section collecting OpenAQ key is for dropped calibration bootstrap feature.

---

## 2. Implementation Phases

### PHASE 1 — Step Reorder + Dead Step Removal (Item 5)

**Rationale:** This phase changes step numbering across the wizard. Do it first so all subsequent wizard work targets the new order.

**T1.1 — Remove dead "Realtime" step and reorder Units before Station**
- Owner: `clearskies-stack-dev` (Sonnet)
- **What changes:**
  1. Remove "Realtime" from `_progress_bar.html` `step_names` array (currently position 7, display step 8).
  2. Swap "Station" and "Units" in `step_names` — new order: ..., Columns (5), Units (6), Station (7), Providers (8), ...
  3. Update `step_url` macro to map new positions to correct URLs.
  4. Update `routes.py`: (a) step context integers in all render calls, (b) POST handler chaining — `step3_post` → `step_units_get`, `step_units_post` → `step4_get` (Station), `step4_post` → `step6_get` (Providers). (c) Remove any route/handler for the dead Realtime step if one exists. (d) Update docstring step table.
  5. Update step template headings: `step_units.html` "Step 6 of 14", `step_station.html` "Step 7 of 14" (was 15 steps, now 14 with Realtime removed). All subsequent steps renumber.
  6. Update Previous/Next button `hx-get` targets in `step_units.html` and `step_station.html`.
  7. Update `step_complete.html` progress entries.
  8. Update 13 translation JSON files — swap step number references for Units and Station, remove Realtime references, renumber all subsequent steps.
  9. Update `cli_wizard.py` step references if applicable.
- **Files:** `_progress_bar.html`, `routes.py`, `step_units.html`, `step_station.html`, `step_complete.html`, `cli_wizard.py`, 13 files in `translations/`.
- **Files NOT to touch:** No template content changes — only step numbers, headings, and navigation targets.
- Accept: Wizard flows correctly through all steps in new order. Progress bar shows 14 steps (no Realtime). Units step immediately follows Column Mapping. All Previous/Next buttons navigate correctly. `python -m py_compile` passes on all `.py` files. All 13 locale JSON files parse cleanly.

**QC (Opus) — after Phase 1:** Walk the full wizard flow on weather-dev: verify step sequence matches new order, progress bar highlights correctly, Previous/Next buttons work on every step, no dead links. Spot-check 3 translation files for correct step numbers.

---

### PHASE 2 — Removals & Cleanup (Items 4, 6, 7, 8, 9, 14, 23)

Seven independent removal tasks. Can be parallelized across agents (API removals in one agent, wizard removals in another, cross-repo rename in a third).

**T2.1 — Rename "Xweather (Vaisala)" to "Vaisala Xweather" (Item 4)**
- Owner: `clearskies-stack-dev` + `clearskies-api-dev` + `clearskies-dashboard-dev` (can be split or sequential)
- **API repo:** Change `display_name="Xweather (Vaisala)"` to `display_name="Vaisala Xweather"` in 4 files:
  - `providers/aqi/aeris.py` (line 239)
  - `providers/alerts/aeris.py` (line 197)
  - `providers/radar/aeris.py` (line 131)
  - `providers/forecast/aeris.py` (line 199)
- **API repo:** Update `operator_notes` strings that say "Aeris" or "AerisWeather" to say "Vaisala Xweather" in the same 4 files.
- **Dashboard repo:** Update `PROVIDER_INFO` in `about.tsx` — change `"Aeris Weather (DTN)"` to `"Vaisala Xweather"`, URL to `https://www.xweather.com`.
- **Dashboard repo:** Update `"Aeris Weather"` references in `legal.json` across all 13 locale files to `"Vaisala Xweather"`.
- **Stack repo:** Update `providers.py` display name, `signup_url` to xweather.com, `docs/providers.md`, and `EULA.txt` (all 13 locale versions) references from "Aeris" to "Vaisala Xweather".
- **Docs:** Update PROVIDER-MANUAL.md, OPERATIONS-MANUAL.md, ARCHITECTURE.md references to "Aeris Weather" → "Vaisala Xweather" (human-visible name only — machine identifiers like `aeris` provider_id stay).
- Accept: `grep -ri "Aeris Weather\|AerisWeather\|Xweather (Vaisala)" repos/ docs/` returns zero hits outside of archived docs, snapshots, git history, and reference/api-docs.

**T2.2 — Remove provider auto-selection (Item 6)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **File:** `step_providers.html`
  - Line 47: Change `state.providers.get(domain) or recommendations.get(domain)` to `state.providers.get(domain)` — remove the `recommendations` fallback.
  - Lines 78-79: Remove the "Selected for your location" badge markup.
  - Remove or comment out the `is_recommended` variable (line 61).
- **File:** `routes.py` — remove `recommend_providers()` call in `step6_get()` (line 1833) and the `recommendations` context variable. Keep `recommend_providers` function if used elsewhere; delete if orphaned.
- **Validation:** Add or verify that the POST handler rejects submission if no provider is selected for a required domain.
- Accept: Provider step renders with no pre-selected providers. No "Selected for your location" badge appears. Operator must explicitly select a provider. Step blocks advancement if required domain has no selection.

**T2.3 — Remove OWM from AQI (Item 7)**
- Owner: `clearskies-api-dev` (Sonnet)
- OWM returns SILAM model predictions, not observed PM data. Not a valid AQI provider.
- **Delete:** `providers/aqi/openweathermap.py`
- **Update:** `providers/aqi/__init__.py` — remove any OWM reference.
- **Update:** `providers/_common/dispatch.py` — remove `("aqi", "openweathermap")` entry.
- **Update:** `endpoints/aqi.py` — remove OWM branch from endpoint dispatch.
- **Update:** `config/settings.py` — remove `"openweathermap"` from valid AQI providers set (line 461).
- **Update:** PROVIDER-MANUAL.md — remove OWM from AQI provider list.
- Accept: No OWM AQI module exists. API starts cleanly. `ruff check` passes. PROVIDER-MANUAL updated.

**T2.4 — Remove OpenAQ as standalone AQI provider (Item 8)**
- Owner: `clearskies-api-dev` (Sonnet) + `clearskies-stack-dev` (Sonnet)
- **API repo — Delete:** `providers/aqi/openaq.py`
- **API repo — Update:** `providers/aqi/__init__.py` — remove any OpenAQ reference.
- **API repo — Verify:** OpenAQ is NOT in dispatch table (confirmed in research). If any reference exists, remove it.
- **Stack repo — Remove:** "Haze Calibration Bootstrap (OpenAQ)" section in `step_providers.html` (lines 115-138). Remove the entire fieldset collecting `openaq_api_key`.
- **Stack repo — Update:** `state.py` — remove `openaq_api_key` field.
- **Stack repo — Update:** `routes.py` — remove any handling of `openaq_api_key` in POST handlers, apply, and merge.
- **Docs:** Update PROVIDER-MANUAL.md — remove OpenAQ from AQI provider list.
- Accept: No OpenAQ AQI module exists. No OpenAQ section in wizard. API starts cleanly. PROVIDER-MANUAL updated.

**T2.5 — Remove LibreWxR bounds from wizard UI (Item 9)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **File:** `step_providers.html` — remove the `<details>` section containing the LibreWxR bounds input (lines 226-242).
- **Do NOT touch:** `state.py` `librewxr_bounds` field, routes.py handling of `librewxr_bounds` in POST/apply/merge, or any backend code that reads bounds from config. The bounds continue to work when manually configured.
- Accept: No bounds input appears in the wizard when LibreWxR is selected. LibreWxR still works as a provider option. Manually-configured bounds in config still function.

**T2.6 — Remove Custom CSS entirely (Item 14)**
- Owner: `clearskies-stack-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)
- **Stack repo:** Remove `custom_css_url` from `state.py`. Remove field from `step_appearance.html`. Remove from POST handler, apply, merge, and review template in `routes.py`.
- **Stack repo:** Remove from admin section if present.
- **Stack repo:** Remove field declaration from `declarations.py` if present.
- **Dashboard repo:** Remove any code that loads or applies a custom CSS URL from `branding.json` (check `branding-provider.tsx`, `app-layout.tsx`).
- **Config:** Remove `customCssUrl` from `branding.json` schema (if wizard writes it).
- Accept: No custom CSS field in wizard or admin. No custom CSS loading in dashboard. `branding.json` does not contain `customCssUrl`.

**T2.7 — Remove social media links from wizard AND admin (Item 23)**
- Owner: `clearskies-stack-dev` (Sonnet)
- The dashboard footer has share-to-social buttons that work without any configuration. The social URLs go into `branding.json` but the dashboard never reads them.
- **Stack repo:** Remove `facebook_url`, `twitter_url`, `instagram_url`, `youtube_url` from `state.py`.
- **Stack repo:** Remove the Social Media fieldset from `step_appearance.html`.
- **Stack repo:** Remove social fields from POST handler, apply (`write_branding_json`), merge, and review template.
- **Stack repo:** Remove social fields from admin section.
- **Stack repo:** Remove field declarations from `declarations.py` if present.
- **Config:** Remove `social` section from `branding.json` schema.
- Accept: No social media fields in wizard or admin. `branding.json` does not contain social URLs.

**QC (Opus) — after Phase 2:**
- Grep verification: `"Aeris Weather"`, `"AerisWeather"`, `"Xweather (Vaisala)"` → zero hits outside archives.
- Grep verification: `openweathermap` in `providers/aqi/` → zero hits.
- Grep verification: `openaq` in `providers/aqi/` → zero hits (module deleted).
- Grep verification: `custom_css_url` → zero hits across all repos.
- Grep verification: `facebook_url|twitter_url|instagram_url|youtube_url` in stack repo → zero hits.
- Wizard flow test on weather-dev: provider step shows no auto-selection, no badges, no OpenAQ section, no LibreWxR bounds, no social fields, no custom CSS field.
- API starts cleanly after OWM/OpenAQ removal. `ruff check` passes.
- Dashboard builds cleanly (`tsc --noEmit` + `vite build`).
- PROVIDER-MANUAL.md accurately reflects remaining providers.

---

### PHASE 3 — Wizard Bug Fixes & Enhancements (Items 2, 15, 16)

**T3.1 — Fix accent color and theme mode rendering (Item 15)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Root cause:** CSS class name mismatch between `form_fields.html` macro output and `layout.html` styles.
- **Fix option A (preferred):** Update `form_fields.html` macro to output the class names that `layout.html` CSS expects:
  - `radio_swatch` block: `accent-swatches` → `accent-swatch-group`, `swatch-label` → `accent-swatch-label`, `swatch` → `accent-swatch-circle`, add `accent-swatch-name` span for the label text.
  - `radio` block (theme mode): add `theme-radio-group` class to fieldset, `theme-radio-card` class to each label.
- **Fix option B:** Update `layout.html` CSS to target the classes the macro already outputs. (Less preferred — the CSS was written with intentional design, the macro was the afterthought.)
- **Verify:** Both controls render with styled appearance (color swatches show as circles, theme mode shows as cards). Values save and restore on wizard re-run.
- Accept: Accent color swatches render as colored circles. Theme mode options render as card-style radio buttons. Pre-selected values show correctly on re-run. `python -m py_compile` passes.

**T3.2 — Wizard step 4 SQLite support (Item 2)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Three sub-tasks:**
  - (a) **Detect DB type from weewx.conf:** The API's `/setup/db-defaults` endpoint reads `weewx.conf`. Verify it returns the database type (SQLite vs MySQL). If not, add a `db_type` field to the response. The wizard's `step2_db_get` handler should pass DB type to the template context.
  - (b) **Conditional form rendering:** `step_db.html` should detect DB type and show the right form. SQLite: show only a file path input (pre-filled from weewx.conf `[DatabaseTypes] [[SQLite]] SQLITE_ROOT`). MySQL: show host, port, user, password, database name (current behavior). The DB test endpoint (`/setup/db-test`) must handle SQLite (test file exists and is readable).
  - (c) **Help content:** Remind the operator which DB type was detected. Explain that fields are pre-filled from weewx.conf. For MySQL: explain how to recover credentials (check `weewx.conf [DatabaseTypes] [[MySQL]]`, or `mysql -u root -p` to reset). For SQLite: explain that the path should match what's in weewx.conf.
- **Research needed by coordinator before writing brief:** Read `/setup/db-defaults` endpoint in the API to verify what it returns. Read `step_db.html` current template. Read `/setup/db-test` endpoint.
- Accept: SQLite operators see a file path input. MySQL operators see connection fields. DB test works for both types. Help content matches detected DB type. Round-trip works (wizard re-run pre-fills correctly).

**T3.3 — Privacy regions: add "None" option (Item 16)**
- Owner: `clearskies-stack-dev` (Sonnet) + `clearskies-dashboard-dev` (Sonnet)
- **Stack repo:**
  - `declarations.py` (around line 148): Add `FieldOption(value="none", label="None / Disabled")` to the privacy region options list.
  - Help text / disclaimer: "You are responsible for compliance with applicable privacy laws in your jurisdiction. Selecting 'None' disables the cookie consent banner."
- **Dashboard repo:**
  - Cookie consent banner logic: when `privacyRegions` is `"none"` (or empty/absent) AND GA ID is configured → GA loads without consent banner.
  - When GA ID is blank → no banner, no GA (implicit "none").
  - Existing behavior for other regions (EU, US, Global, Both) unchanged.
- Accept: "None" option appears in wizard privacy step. GA loads without banner when "None" selected and GA ID present. No banner when GA ID blank. Existing region behavior unchanged. Disclaimer text present.

**QC (Opus) — after Phase 3:**
- Accent color swatches render as styled circles on weather-dev. Theme mode renders as cards. Values round-trip.
- DB step: test with SQLite config (verify against weewx container's actual `weewx.conf`). Verify conditional rendering.
- Privacy "None": configure GA ID + "None" → verify GA loads without banner. Remove GA ID → verify no banner and no GA. Set EU → verify banner appears.

---

### PHASE 4 — Wizard New Features (Items 1, 3, 13, 19, 20)

**T4.1 — Chart migration in wizard import step (Item 1)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Research needed by coordinator before writing brief:** Read the `clearskies-migrate-charts` CLI tool code to understand: (a) is the conversion logic importable as a Python function, or tightly coupled to CLI arg parsing? (b) what inputs does it need (file path only, or other context)? (c) what does it output?
- **Scope (pending research):**
  - Add a file input to the wizard's import step (`step_import.html`) for `graphs.conf`.
  - POST handler reads the uploaded file, calls the conversion logic, writes `charts.conf` to `/etc/weewx-clearskies/` on apply.
  - If the conversion logic is CLI-coupled, refactor to extract a callable function.
  - The CLI tool remains available as an alternative.
- Accept: Wizard import step offers `graphs.conf` upload. Conversion produces valid `charts.conf`. File written on apply. CLI tool still works independently.

**T4.2 — Help button discoverability animation (Item 3)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Add CSS keyframe animation (pulse or bounce) to the help button element in the wizard.
  - On first wizard step load, check `sessionStorage` for a `help-intro-seen` flag.
  - If not set: add animation class to help button, set flag after animation plays (or after a short delay).
  - Animation plays once per session, does not repeat on subsequent steps.
- **Files:** Wizard layout template (wherever the help button is rendered), `layout.html` or inline `<style>` for the keyframes.
- Accept: Help button pulses/bounces on first step of a new session. Does not animate on subsequent steps or return visits within the same session. Animation is subtle, not disruptive.

**T4.3 — Custom background uploads in Appearance step (Item 13)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Add a file upload field to the appearance step for custom background images.
  - Reuse the `_BRANDING_UPLOAD_RULES` / `_handle_branding_upload` pattern.
  - Upload rules: `.jpg`, `.jpeg`, `.png`, `.webp` formats. Max 5 MB. Suggested: landscape orientation, minimum 1920×1080.
  - Storage: `{config_dir}/branding/backgrounds/` subdirectory.
  - The custom background should interface with the existing background selector — operator picks one of the 6 built-in options OR uploads their own. If a custom background is uploaded, it appears as a 7th option (or replaces the selector with a preview + "remove" button).
  - Write the custom background URL to `branding.json` so the dashboard can read it.
- **Dashboard repo:** Read custom background URL from `branding.json`. If set, use it instead of the scene-keyed built-in backgrounds. Verify it renders properly in both light and dark themes.
- Accept: Operator can upload a background image through the wizard. Image persists across wizard re-runs. Dashboard renders the custom background. Built-in selector still works when no custom background is set.

**T4.4 — TLS Manual mode: certificate file upload (Item 19)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Modify the TLS step (`step_tls.html`) Manual mode fields.
  - Add file upload inputs alongside the existing path inputs for cert and key.
  - Reuse `_handle_branding_upload` pattern but with different rules: `.pem`, `.crt`, `.key` extensions, `text/plain` or `application/x-pem-file` MIME, max 100 KB.
  - Storage: `{config_dir}/tls/` subdirectory (NOT branding).
  - If file is uploaded, write to disk and use that path. If path is provided, use the path directly. Upload takes precedence.
  - Update `state.py` to track whether cert/key came from upload vs path.
- Accept: Operator can upload cert and key files through the wizard. Files written to `/etc/weewx-clearskies/tls/`. Path-based approach still works. Round-trip on re-run pre-fills correctly (shows "using uploaded certificate" or similar).

**T4.5 — Review & Apply: detect API restart and show status (Item 20)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - After the Apply POST triggers the API restart, the wizard's response page (or a new intermediate page) shows a clean status UI instead of forwarding to the dashboard (which would show errors during the ~2 min restart).
  - JavaScript on the post-apply page: poll the API health endpoint (`GET /health` on port 8765) every 5 seconds.
  - Display states: "Applying configuration..." → "API is restarting, please wait..." (with a spinner/progress indicator) → "API is ready!" → auto-redirect to dashboard (or show a "Go to Dashboard" button).
  - Handle the case where the health check fails repeatedly (timeout after 5 minutes → show error with manual retry option).
- **Files:** `step_complete.html` or new `step_restarting.html` template, inline JavaScript for polling.
- Accept: After Apply, operator sees a clean status page. No error wall. Auto-detection when API is back up. Redirect or button to proceed.

**QC (Opus) — after Phase 4:**
- Chart migration: upload a `graphs.conf` from the Belchertown skin → verify `charts.conf` is generated correctly.
- Help animation: open wizard in new browser session → verify help button animates on step 1, does not animate on step 2+.
- Background upload: upload a custom image → verify it renders in the dashboard. Remove it → verify built-in backgrounds work.
- TLS upload: upload test cert/key files → verify they're written to `/etc/weewx-clearskies/tls/`.
- Restart detection: run Apply → verify status page shows progress → verify redirect when API is ready.

---

### PHASE 5 — Dashboard Performance (Item 21)

**T5.1 — Add client-side data cache layer**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- **Root cause:** `useApiQuery` stores data in component-local `useState`. Data is destroyed on unmount and re-fetched on remount. No external cache exists.
- **Fix:** Add a module-level `Map<string, CachedResponse>` inside `useApiQuery` that survives component unmount/remount (lives outside React's lifecycle). No new dependency. The existing stale-while-revalidate logic in `useApiQuery` already handles background refetches — the Map just ensures cached data is returned immediately on remount instead of re-fetching. Needs TTL logic so stale entries are eventually evicted.
- **Additional fix:** Move `/radar` route inside the `<Route element={<AppLayout />}>` wrapper so navigating to/from radar no longer unmounts the app shell. This preserves shared state (observation, alerts, station) across radar transitions. Radar page already uses `AppLayout`'s data — it should be a child route, not a sibling.
- **Additional fix:** Deduplicate `useObservation()` / `useStation()` calls — these are called independently in AppLayout AND page components, creating duplicate poll loops. Lift shared data hooks to AppLayout and pass via context or props.
- Accept: Navigating away from Now page and returning shows data immediately (no loading skeletons, no re-fetch for recently-cached data). Navigating to/from radar does not destroy app shell state. No duplicate concurrent API calls for the same endpoint. `tsc --noEmit` + `vite build` clean.

**T5.2 — Fix day/night background flash**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- **Root cause:** Module-level `SCENE_DEFAULT` is computed once at import and becomes stale after scene changes. Two copies of `getCachedScene()` use inconsistent parsing logic. The `visible` prop on `SceneBackground` is not wired up.
- **Fix:**
  - Replace module-level `SCENE_DEFAULT` constant with a function call that reads localStorage at use time (not import time). Or move the cached scene read into the hook's initialization.
  - Unify the two `getCachedScene()` implementations into one shared function with consistent parsing (`daytime === 'true'`).
  - Wire up the `visible` prop on `SceneBackground` in `AppLayout` — set `visible={sceneLoaded}` so the background doesn't render until real API data arrives (on route transitions, not just initial load).
  - Ensure `cacheScene()` writes to localStorage on every scene update so the next mount reads the correct value.
- Accept: Navigating to/from radar (or any route) does not produce a visible background flash. The correct day/night background renders immediately. No 1.2s cross-fade on route transitions when the scene hasn't actually changed.

**QC (Opus) — after Phase 5:**
- Navigate: Now → Forecast → Now. Verify Now page data appears immediately without loading skeletons.
- Navigate: Now → Radar → Now. Verify: (a) Now page data appears immediately, (b) no background flash, (c) correct day/night background.
- Open browser DevTools Network tab. Navigate between pages. Verify no duplicate concurrent requests to the same endpoint.
- `tsc --noEmit` + `vite build` clean.
- ADR-055 compliance: stale-while-revalidate behavior still works for background refetches.

---

### PHASE 6 — Help Content (Items 10, 11, 12)

**Depends on:** Phases 2-4 completing (provider list finalized, removals done).

**T6.1 — AQI regional scale clarification (Item 10)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Verify the wizard already conditionally shows the AQI scale selector only for providers that support it (Vaisala Xweather, IQAir, Open-Meteo). If not, add conditional visibility.
  - Update help text for the AQI regional scale to explain: what it does (determines which country/region's AQI standard is used for the index calculation), which providers support it, and what the options mean for each provider.
  - The selector should NOT appear when a provider without regional support is selected.
- Accept: AQI scale selector appears only for Vaisala Xweather, IQAir, Open-Meteo. Help text explains the setting clearly. Selector hidden for other providers.

**T6.2 — Comprehensive per-provider help for step 9 (Item 11)**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Rewrite the help content for the provider selection step (now step 8 after reorder).
  - Collapsible `<details>/<summary>` section per provider within each domain.
  - Each provider section includes: registration link, free tier details, whether PWS data is available, key vs no-key, coverage area, any usage limits.
  - Help panel infrastructure: verify `<details>/<summary>` renders correctly in the help panel. If the help panel uses markdown, may need direct HTML support.
  - **Alert coverage (Item 12):** Include clear coverage information for alert providers: NWS (US only, keyless), Vaisala Xweather (global — US, Canada, Europe, UK, Japan, Australia, India, Brazil, South Africa, South Korea, Mexico; requires API key), OWM (global, requires paid subscription). Operators outside the US need Vaisala Xweather or OWM for alerts.
- Accept: Help panel for provider step has collapsible sections per provider per domain. Each section has registration link, free tier info, coverage area. Alert provider coverage is clearly documented. All 13 locales updated with translated help content.

**T6.3 — Alert provider coverage documentation (Item 12)**
- Owner: `clearskies-stack-dev` (Sonnet) + `clearskies-docs-author` (Sonnet)
- **Scope:** (Merged into T6.2 for the wizard help content.) Additionally:
  - Update PROVIDER-MANUAL.md alert provider section to accurately document coverage areas.
  - Ensure the wizard's provider step makes it clear which alert providers cover which regions.
  - No new provider modules needed — the existing three (NWS, Vaisala Xweather, OWM) cover global needs. Open-Meteo does not provide alerts.
- Accept: PROVIDER-MANUAL.md alert section reflects actual coverage. Wizard help communicates coverage clearly.

**QC (Opus) — after Phase 6:**
- AQI scale selector: select each AQI provider in the wizard → verify selector shows/hides correctly.
- Provider help: open help panel on provider step → verify collapsible sections exist for each active provider in each domain. Verify registration links work. Verify alert coverage is documented.
- Spot-check 3 locale translations for help content.
- PROVIDER-MANUAL.md reflects actual provider set (no OWM AQI, no OpenAQ, correct alert coverage).

---

### PHASE 7 — Seismic Enhancements (Item 17)

**Research findings:** USGS already returns MMI in their response and the canonical `EarthquakeRecord` already has an `mmi` field mapped. The dashboard types include `mmi` but neither the Now card nor the Seismic page display it. A locale key `"mmi": "MMI: {{mmi}}"` exists but is unreferenced. Distance from station is not computed anywhere. `group_distance` (km/mile) exists with conversion functions. Depth is hardcoded as km ("unit-system-invariant"). The Now card shows 2 quakes with magnitude badge, place, relative time, depth, and source label. The Seismic page list shows magnitude badge, place, absolute time, depth, tsunami badge, and PAGER alert. Map popups show place, magnitude+type, depth, PAGER, time. No "View all" link from Now card to Seismic page.

**Design decisions (confirmed with user):**
- USGS event-level MMI is sufficient — no local shaking estimation (IPE would be inaccurate without geological data, especially in areas like LA with variable soil conditions).
- Distance from station displayed in metadata line alongside depth on both Now card and Seismic page list.
- Source label ("USGS") dropped from display — attributed elsewhere (About page).
- MMI shown only in the Seismic page map popup (not in list — would overflow, especially on Now card).
- Both depth and distance use `group_distance` (km/miles), controlled by a single unit selector.
- Add "View all" link from Now card to `/seismic`.

**T7.1 — API: add distance-from-station field + unit conversion**
- Owner: `clearskies-api-dev` (Sonnet)
- **Scope:**
  - Add `distanceKm: float | None = None` to `EarthquakeRecord` in `models/responses.py`.
  - In the earthquake endpoint (or a post-fetch enrichment step), compute haversine distance from station lat/lon to each quake's lat/lon. Station coordinates available from `StationInfo`.
  - Apply `group_distance` unit conversion to both `distanceKm` and `depth` fields. This means earthquake responses are no longer "unit-system-invariant" — they participate in the unit conversion pipeline.
  - Include distance and depth in the response `units` dict with appropriate labels.
  - Update OpenAPI schema (auto-generated from the model change).
- **Files:** `models/responses.py`, earthquake endpoint file, unit conversion wiring.
- **Files NOT to touch:** Dashboard code, wizard code.
- Accept: `/api/v1/earthquakes` response includes `distanceKm` (or `distance` after conversion) for each quake. Depth and distance are unit-converted per operator preference. `ruff check` passes. OpenAPI spec reflects new field.

**T7.2 — API: haversine utility**
- Owner: `clearskies-api-dev` (Sonnet) (can be combined with T7.1)
- **Scope:** Implement a haversine distance function if one doesn't already exist in the codebase. Inputs: two lat/lon pairs. Output: distance in km. Standard formula, well-known — no external dependency needed.
- Accept: Function returns correct distances (spot-check: LA to San Francisco ≈ 559 km).

**T7.3 — Wizard/Admin: earthquake unit selector**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Add a unit selector for earthquake distance/depth to the wizard's units step. Single selector: "Earthquake distance & depth: km / miles".
  - Wire into `WizardState`, POST handler, apply (writes to `api.conf [units] [[groups]]`), and merge.
  - Add corresponding field to admin units section.
- Accept: Wizard units step includes earthquake distance/depth selector. Value persists to `api.conf`. Admin section mirrors it. Round-trip on re-run.

**T7.4 — Dashboard: display distance, MMI in popup, drop source, add "View all"**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- **Scope:**
  - **Now card (`earthquake-card.tsx`):**
    - Drop source label from metadata line (remove `· USGS`).
    - Add distance-from-station to metadata line: `Depth: 8 km · 142 mi away`. Read `distance` and `distanceUnit` from the API response units dict.
    - Add "View all" link at bottom of card pointing to `/seismic`.
  - **Seismic page list (`seismic.tsx`):**
    - Drop source label.
    - Add distance to metadata row alongside depth: `Depth: 8 km · 142 mi away`.
  - **Seismic page map popup (`seismic.tsx`):**
    - Add MMI line when `quake.mmi` is non-null. Format: `MMI: IV (Light Shaking)`. Use the existing `"mmi"` locale key. Map numeric MMI to Roman numeral + description label (I=Not Felt, II=Weak, III=Weak, IV=Light, V=Moderate, VI=Strong, VII=Very Strong, VIII=Severe, IX=Violent, X+=Extreme).
    - Add distance line.
  - **TypeScript types:** Add `distance: number | null` (or similar) to `EarthquakeRecord` interface. The field name will match whatever the API returns after unit conversion.
  - **Locale files:** Add/update translation keys for distance display and MMI descriptions across all 13 locales.
- Accept: Now card shows distance, no source label, has "View all" link. Seismic list shows distance. Map popup shows MMI (when available) with Roman numeral + description. Units match operator preference (km or miles). `tsc --noEmit` + `vite build` clean.

**T7.5 — Documentation updates**
- Owner: `clearskies-docs-author` (Sonnet)
- **Scope:**
  - API-MANUAL.md: document new `distance` field on earthquake response, unit conversion for earthquake data.
  - ARCHITECTURE.md: update earthquake endpoint description to note distance computation and unit conversion. Remove "unit-system-invariant" language for earthquakes.
  - DASHBOARD-MANUAL.md: update earthquake card and seismic page field descriptions.
- Accept: All three manuals reflect the new earthquake response shape and display changes.

**QC (Opus) — after Phase 7:**
- API: verify `/api/v1/earthquakes` returns distance for each quake. Spot-check haversine accuracy (known lat/lon pairs). Verify depth and distance are unit-converted when operator selects miles.
- Dashboard: Now card shows 2 quakes with distance, no source label. "View all" navigates to `/seismic`. Seismic list shows distance. Map popup shows MMI for a quake that has it (check a recent M4+ if available in data). Popup omits MMI line for quakes with `mmi: null`.
- Wizard: units step shows earthquake distance/depth selector. Value round-trips.
- Docs: all three manuals updated.

---

### PHASE 8 — Admin Help Sync (Item 22)

**Depends on:** All previous phases completing (wizard help finalized).

**T8.1 — Sync admin help with wizard help**
- Owner: `clearskies-stack-dev` (Sonnet)
- **Scope:**
  - Read all finalized wizard help content from wizard step templates.
  - Identify corresponding admin help keys (`help.admin.*`).
  - Apply all content fixes, jargon removal, compliance disclaimers, and format guidance to admin help.
  - Sections to sync: station, database, providers, appearance, TLS, privacy/legal, features.
  - Ensure admin help reflects all removals (no Custom CSS, no social media, no OpenAQ bootstrap, no OWM AQI, correct provider names).
- Accept: Admin help content matches wizard help in tone, accuracy, and completeness. No references to removed features. All 13 locales updated.

**QC (Opus) — after Phase 8:**
- Walk every admin section on weather-dev. Verify help content is present, accurate, and consistent with wizard help.
- Verify no references to removed features (custom CSS, social media, OpenAQ, OWM AQI).
- Spot-check 3 locale translations.

---

## 3. Agent Assignments

| Phase | Task | Repo | Owner | QC Timing |
|-------|------|------|-------|-----------|
| 1 | T1.1 Step reorder + Realtime removal | stack | `clearskies-stack-dev` | After Phase 1 |
| 2 | T2.1 Xweather rename | api + dashboard + stack + docs | Split across agents | After Phase 2 |
| 2 | T2.2 Remove auto-selection | stack | `clearskies-stack-dev` | After Phase 2 |
| 2 | T2.3 Remove OWM AQI | api + docs | `clearskies-api-dev` | After Phase 2 |
| 2 | T2.4 Remove OpenAQ | api + stack + docs | Split | After Phase 2 |
| 2 | T2.5 Remove LibreWxR bounds UI | stack | `clearskies-stack-dev` | After Phase 2 |
| 2 | T2.6 Remove custom CSS | stack + dashboard | Split | After Phase 2 |
| 2 | T2.7 Remove social media links | stack | `clearskies-stack-dev` | After Phase 2 |
| 3 | T3.1 Fix accent/theme rendering | stack | `clearskies-stack-dev` | After Phase 3 |
| 3 | T3.2 SQLite support | stack + api | `clearskies-stack-dev` | After Phase 3 |
| 3 | T3.3 Privacy "None" option | stack + dashboard | Split | After Phase 3 |
| 4 | T4.1 Chart migration in wizard | stack | `clearskies-stack-dev` | After Phase 4 |
| 4 | T4.2 Help button animation | stack | `clearskies-stack-dev` | After Phase 4 |
| 4 | T4.3 Custom background uploads | stack + dashboard | Split | After Phase 4 |
| 4 | T4.4 TLS cert upload | stack | `clearskies-stack-dev` | After Phase 4 |
| 4 | T4.5 Restart detection | stack | `clearskies-stack-dev` | After Phase 4 |
| 5 | T5.1 Client-side cache layer | dashboard | `clearskies-dashboard-dev` | After Phase 5 |
| 5 | T5.2 Fix background flash | dashboard | `clearskies-dashboard-dev` | After Phase 5 |
| 6 | T6.1 AQI scale clarification | stack | `clearskies-stack-dev` | After Phase 6 |
| 6 | T6.2 Provider help content | stack | `clearskies-stack-dev` | After Phase 6 |
| 6 | T6.3 Alert coverage docs | stack + docs | `clearskies-docs-author` | After Phase 6 |
| 7 | T7.1 API distance field + unit conversion | api | `clearskies-api-dev` | After Phase 7 |
| 7 | T7.2 Haversine utility | api | `clearskies-api-dev` | After Phase 7 |
| 7 | T7.3 Earthquake unit selector | stack | `clearskies-stack-dev` | After Phase 7 |
| 7 | T7.4 Dashboard display changes | dashboard | `clearskies-dashboard-dev` | After Phase 7 |
| 7 | T7.5 Seismic docs updates | docs | `clearskies-docs-author` | After Phase 7 |
| 8 | T8.1 Admin help sync | stack | `clearskies-stack-dev` | After Phase 8 |

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- Stack: `python -m py_compile` on all modified `.py` files. Templates render without Jinja2 errors.
- API: `ruff check` no introduced errors.
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.

### Gate 2 — Feature Correctness (per phase, Opus verifies)
- Phase 1: Full wizard step sequence flows correctly in new order.
- Phase 2: All removed features confirmed absent via grep. Remaining features unbroken.
- Phase 3: Accent swatches render styled. SQLite form appears for SQLite configs. Privacy "None" works with GA logic.
- Phase 4: File uploads work for charts, backgrounds, TLS certs. Restart detection shows clean status.
- Phase 5: No loading skeletons on route return. No background flash. No duplicate API calls.
- Phase 6: Help content present, accurate, collapsible sections work. AQI scale conditional visibility works.
- Phase 7: Distance field present in earthquake API response. Haversine accuracy verified. MMI in map popup (when available). Source label removed. "View all" link works. Unit conversion applies to depth and distance.
- Phase 8: Admin help matches wizard help.

### Gate 3 — Doc-Code Sync (every phase)
- PROVIDER-MANUAL.md reflects actual provider set after removals/renames.
- ARCHITECTURE.md updated if wizard steps, config schema, or routing changes.
- OPERATIONS-MANUAL.md updated if TLS or config changes.
- DASHBOARD-MANUAL.md updated if caching strategy or data flow changes.

### Gate 4 — Completeness (after Phase 8)
- Walk every pinned item (1-17, 19-23) against the plan. Each must map to a completed task with evidence.
- Walk the pinned items document and verify each item is fully addressed — not partially, not "mostly done."
- No outstanding grep hits for removed features.
- Full wizard flow test: new session → every step → apply → re-run → verify pre-fill.

---

## 5. Coordinator Pre-Work (Before Each Phase)

The coordinator MUST complete these steps before dispatching any agent for a phase:

1. **Read relevant code:** Open and read every file the phase's tasks will modify. Not skim — read.
2. **Verify repo state:** `git status` + `git log --oneline -1` on each repo involved. No uncommitted changes, no unexpected HEAD.
3. **Write the brief:** Per `rules/clearskies-process.md` — scope block, reading list, pre-round verification, per-deliverable spec, lead calls.
4. **QC against plan:** After agent delivers, verify against THIS PLAN's acceptance criteria, not just "it looks fine."

---

## 6. Not In Scope

### Item 18 — Volcanic Activity Monitoring
Research completed 2026-07-04. USGS provides clean JSON APIs for US volcano alert levels (`getElevatedVolcanoes`, GeoJSON endpoint). Smithsonian GVP has a global volcano database mirrored via USGS `volcanoesGVP` endpoint (1,400+ volcanoes, JSON). Global eruption status requires parsing Smithsonian weekly RSS (XML, no JSON API). Deferred to a future plan.

---

## 7. Self-Audit

**Risk: Step reorder cascading breakage.** Renumbering touches routes, templates, translations, and flow chaining. Mitigation: do it first (Phase 1) before any other wizard work. Full flow test in QC.

**Risk: OWM AQI removal breaks operators who configured it.** OWM AQI is a SILAM model, not observed data — it should never have been offered. Operators using it need to switch to a real AQI provider. The wizard will prompt them to select a new provider on re-run since their configured provider no longer exists. Mitigation: ensure the API handles a missing/unknown AQI provider gracefully (log warning, return empty AQI, don't crash).

**Risk: Dashboard cache layer is a significant architectural change.** Adding a cache layer (React Query or module-level cache) touches the entire data fetching strategy. Mitigation: coordinator decides the approach before writing the brief. Option B (module-level Map) is lowest risk. Thorough testing of stale-while-revalidate behavior (ADR-055).

**Risk: Custom background uploads and display.** The dashboard's scene/background system is complex (day/night keying, 6 built-in options, cross-fade transitions). A custom background needs to integrate with or bypass this system. Mitigation: coordinator reads the full scene-background code before writing the brief.

**Risk: File upload security.** New upload endpoints (backgrounds, TLS certs) need the same validation as existing logo uploads: extension whitelist, MIME check, size limit, filename sanitization. Reusing `_handle_branding_upload` inherits these protections. TLS key files should be stored with restricted permissions (mode 0600).
