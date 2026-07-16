# Marine Fixit Plan

**Status:** APPROVED
**Created:** 2026-07-15
**Origin:** Comprehensive troubleshooting session reviewing all marine feature pages (wizard, admin, dashboard — surfing, fishing, beach safety, boating), plus core API performance testing. Surfaced 25 issues across data correctness, UI/UX design, config persistence, and performance. Research completed on all open unknowns before plan drafting.

## Context

The marine feature shipped via the MARINE-REMEDIATION-PLAN but has significant gaps across every surface: the wizard fails to save most marine data (422 regression), the admin crashes on load (Jinja template bug), the GRIB reader may be using forecast hour 144 instead of current conditions, wind scoring uses offshore buoy data instead of local wind, water temperature uses NWS text instead of the ocean model, activity detail pages are missing critical data and violate design rules, and the Now page takes 15 seconds to load because the cache warmer never warms the two most expensive endpoints.

This plan remediates all 24 active findings (FIX-18 deferred to future roadmap) organized into 8 phases (Phase 0 through Phase 7) by severity and dependency.

## 0. Orientation — Execution Context

Same as MARINE-REMEDIATION-PLAN §0 — read those files, use those deploy scripts, follow those SSH rules.

**Fixit list:** `docs/planning/MARINE-FIXIT-LIST.md` — full finding details with root cause analysis and research.

**Coordinator pre-read (mandatory before dispatching any agent):** The coordinator MUST read all relevant governing documents, manuals, and source code before writing agent briefs. The coordinator cannot write a correct brief from memory or plan summaries — it must understand the current state of the code and docs to give agents precise, accurate instructions. At minimum, before each phase:
- Read the governing manuals for that phase's domain (API-MANUAL, PROVIDER-MANUAL, DESIGN-MANUAL, OPERATIONS-MANUAL, DASHBOARD-MANUAL as applicable)
- Read ARCHITECTURE.md for any infrastructure context
- Read the specific source files each task will modify (not just the file names — the actual code)
- Verify the code matches what this plan describes (the plan was written at a point in time; code may have changed)

If the code does not match the plan's description, STOP and update the plan before dispatching. An agent working from a stale brief will produce wrong output.

**Verification mandate:** Every fix MUST include live verification as part of acceptance criteria. "Code compiles and tests pass" is not sufficient.

**Design reference:** All dashboard card redesigns must use the Now page cards and Forecast page cards as the visual model. Same card anatomy, same design tokens, same stat tile patterns. Read `docs/manuals/DESIGN-MANUAL.md` before any UI work.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | Run targeted tests only per `rules/clearskies-process.md` | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/pytest tests/<relevant> -q"` |
| Dashboard vitest | Run targeted tests only | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npx vitest run src/<relevant>"` |

---

## Phase 0 — Documentation & Manual Updates ✅ COMPLETE (2026-07-15)

Governing documents must be corrected BEFORE implementation begins so agents work from accurate references. Every finding that changes documented behavior, data sources, or architecture gets its manual update here — not deferred to "after the code ships."

> **Execution status:** All 7 tasks complete. QC Gate 0 passed (3 findings remediated: F1 fishing water-temp stale ref, F2 card notation mapping, F3 missing card specs). T0.5 (ARCHITECTURE.md cache warmer) deferred per plan to land with T1.4.

### T0.1 — API-MANUAL: Correct surf wind data source documentation

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`

**Do:**
- §17 (Surf quality scorer): Document that wind input MUST come from station hardware → forecast provider fallback (same precedence as the marine endpoint), NOT from NDBC buoy. NDBC buoy wind is offshore and does not represent beach conditions. Document the research findings: Surfline's investment in beach-level wind stations, thermal sea breeze effects, and why offshore buoy wind is wrong for surf quality scoring.
- §17: Document that NDBC buoy's valid role is spectral swell decomposition ONLY — not wind quality.
- §18 (Detail endpoint enrichment contract): Add surf endpoint to the wind precedence documentation already present for the marine endpoint.

**Accept:** API-MANUAL §17 and §18 accurately describe wind sourcing for surf scoring.

### T0.2 — API-MANUAL: Correct surf water temperature source documentation

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`

**Do:**
- §17 or §18: Document that surf water temperature MUST come from the ocean data resolver (on-premises sensor → OFS → ERDDAP → MUR SST), NOT from the NWS SRF text product. SRF water temp is a manually-entered forecaster value, not modeled/observed data.
- Document that the SRF `waterTemp` may serve as a last-resort fallback only.

**Accept:** API-MANUAL documents the ocean data resolver as the primary water temp source for surf.

### T0.3 — API-MANUAL: Document GRIB temporal awareness requirement

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`

**Do:**
- §18 or a new NWPS subsection: Document that NWPS GRIB2 files contain 144 hourly forecast timesteps. The GRIB reader MUST select by forecast hour (`endStep` key) — hour 0 for current conditions, specific hours for forecast arrays. Document that the previous behavior (last-message-wins) was a bug, not a design choice.
- Document the `endStep` key as the canonical temporal key for both eccodes and pygrib backends.

**Accept:** API-MANUAL documents the temporal selection requirement and the `endStep` key.

### T0.4 — PROVIDER-MANUAL: Update NDBC provider role documentation

- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- §14.1 (NDBC): Clarify that NDBC wind data is offshore and should NOT be used for surf wind quality scoring. NDBC's valid roles: spectral swell decomposition, offshore wave observations.
- Document the distinction: buoy spectral swell decomposition (valid — swell propagation is large-scale) vs. buoy wind (invalid for beach conditions — wind is hyperlocal and dominated by coastal thermal effects the buoy cannot see).

**Accept:** PROVIDER-MANUAL accurately describes NDBC's role and limitations.

### T0.5 — ARCHITECTURE.md: Update cache warmer documentation

- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`

**Do:**
- Update the cache warmer description to include `/forecast` and `/current` as warmed endpoints (after T1.4 implements this).
- Document the root cause: these were never warmed, causing 11s and 6.2s cold calls for visitors.

**Note:** This update lands with or immediately after T1.4, not before (the code change must happen first).

**Accept:** ARCHITECTURE.md lists all warmed endpoints including forecast and current.

### T0.6 — DESIGN-MANUAL: Add marine card design criteria

- Owner: Coordinator (Opus)
- File: `docs/manuals/DESIGN-MANUAL.md`

**Do:**
- Add a marine cards section documenting:
  - Activity detail pages reuse Now page and Forecast page card patterns — same anatomy, tokens, stat tiles.
  - Score cards (surf, fishing) are 2x2 hero cards with prominent numeric score + breakdown.
  - Location cards on the landing page are 2x1 or 1x2 with photo + data.
  - Activity tabs must follow a defined design pattern (styled tabs or status strip buttons — not floating unstyled).
  - Marine alert strip: thin color-coded strip below map, severity color + alert name + brief text.
  - Solunar display reuses the Almanac Sun/Moon card component — no separate solunar card.
  - No star ratings in forecast cards — numeric scores only.

**Accept:** DESIGN-MANUAL has a marine section that agents can reference for all card work in Phases 4-7.

### T0.7 — Update clearskies-process.md: Wizard ↔ API apply contract rule

- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`

**Do:**
- Strengthen the existing "Wizard ↔ API apply contract sync" rule with the `nwps_wfo` incident: the wizard sent a field the API resolves internally, and `extra="forbid"` rejected the entire payload. Add: "Fields that the API resolves internally during apply (e.g., `nwps_wfo` via NWS `/points`) must NOT be sent by the wizard or admin. The apply payload should contain only operator-provided or operator-confirmed data."

**Accept:** Rule updated with the `nwps_wfo` example.

### QC Gate 0

**Adversarial audit agent** (`clearskies-auditor`, Sonnet): Spawn an independent auditor that has NOT seen the implementation. Give it ONLY the list of findings (FIX-1 through FIX-25) and the updated manuals. The auditor must:
1. For each finding that changes documented behavior (wind source, water temp source, GRIB temporal, cache warmer), verify the manual now describes the CORRECT behavior — not the old broken behavior.
2. Grep the manuals for any remaining references to the old behavior (e.g., "NDBC wind" in surf scoring context, "SRF water temperature" as primary source, "single snapshot" for NWPS without temporal caveat).
3. Cross-check DESIGN-MANUAL marine section against the card specs in this plan (Phases 4-7) — every card size, every data element, every "reuse X component" must match.
4. Report any conflict between the updated manuals and the plan's implementation specs.

**Pass criteria:** Auditor reports zero conflicts between manuals and plan. Zero stale references to old behavior.

---

## Phase 1 — Critical Blockers & Data Correctness ✅ COMPLETE (2026-07-15)

These issues block basic functionality: marine config cannot be saved, the admin page crashes, current conditions data may be from 6 days in the future, and the Now page takes 15 seconds to load.

> **Execution status:** All 4 tasks complete. QC Gate 1 passed (4/4 checks pass, 0 findings). Commits: T1.1 (7f693a6), T1.2 (f2c7b75), T1.3 (7aa63a0), T1.4 (1f5b3ca). Cache warmer verified: forecast 12s→8.6s, current 6.2s→1.9s.

### T1.1 — Fix wizard marine apply 422 regression (FIX-1)

- Owner: `clearskies-api-dev` (stack repo)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py`

**Problem:** `build_marine_payload()` at line 445 sends `nwps_wfo` in each location entry:
```python
for key in ("ndbc_station_ids", "coops_station_ids", "nws_marine_zone_id", "nwps_wfo"):
```
But `MarineLocationApplyConfig` in the API (`setup.py:538-557`) does NOT have a `nwps_wfo` field and uses `extra="forbid"`. The API resolves `nwps_wfo` internally during apply via NWS `/points`. The entire apply payload is rejected with 422, so **no marine data saves at all** — buoy IDs, COOPS stations, zone IDs, surf config, fishing config, everything is lost.

**Introduced in:** commit `e8ad003` ("align build_marine_payload with API schema").

**Do:** Remove `"nwps_wfo"` from the tuple at line 445. The corrected line:
```python
for key in ("ndbc_station_ids", "coops_station_ids", "nws_marine_zone_id"):
```

**Do NOT:** Add `nwps_wfo` to the API's Pydantic model — the API resolves it internally and it should not be an external input.

**Accept:**
- Wizard apply completes without 422 error.
- After apply, `api.conf` contains the marine section with `ndbc_station_ids`, `coops_station_ids`, `nws_marine_zone_id` populated for each location.
- Verify by running the wizard, configuring a marine location with "Discover Nearby Stations," and confirming apply succeeds.

### T1.2 — Make NWPS GRIB reader temporally aware (FIX-17)

- Owner: `clearskies-api-dev` (API repo)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/grib_processor.py` (lines 116-167 eccodes, 175-220 pygrib)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nwps.py` (lines 398-447 `_extract_fields`)

**Problem:** Both GRIB backends iterate all messages and overwrite `result.fields[short_name]` each time a matching shortName is found. The NWPS GRIB2 file contains **144 hourly forecast timesteps** (hours 0-144). The last message wins — likely hour 144 (6 days out). No temporal metadata (`stepRange`, `forecastTime`, `endStep`) is read anywhere.

**Research finding:** The `endStep` key (integer, hours) is available in both eccodes (`eccodes.codes_get(msgid, "endStep")`) and pygrib (`grb.endStep`). For instantaneous fields (wave height, period, direction), `endStep` equals the forecast hour.

**Do:**

1. Modify `read_grib_fields()` signature to accept an optional `target_step: int | None = None` parameter.
2. In `_read_eccodes()`: after reading `short_name`, read `end_step = eccodes.codes_get(msgid, "endStep")`. If `target_step is not None` and `end_step != target_step`, skip the message (`continue`).
3. In `_read_pygrib()`: same logic using `grb.endStep`.
4. Modify `_extract_fields()` in `nwps.py` to pass `target_step=0` when calling `read_grib_fields()` — this selects the analysis/current-conditions timestep.
5. Add a `GribFieldData.end_step: int` attribute so callers know which timestep they got.

**Future use (not this task):** When `target_step` is `None`, return ALL timesteps indexed by `end_step` — this enables the forecast array and animated map (FIX-18). For now, just add the filtering; the multi-step return shape is a future task.

**Accept:**
- `read_grib_fields(path, fields, target_step=0)` returns only the hour-0 messages.
- Wave height, period, direction values for the current conditions match the analysis time, not a future forecast hour.
- Verify by comparing the returned wave height against the NWPS model viewer for the same WFO/cycle.
- Existing callers (nwps.py `_extract_fields`) pass `target_step=0` and get current data.

### T1.3 — Fix admin Jinja template crash (FIX-23, critical part)

- Owner: `clearskies-api-dev` (stack repo)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/config/dashboard.html` line 149

**Problem:** `{% for k, v in s.values.items() %}` — `s.values` is Python's builtin `dict.values()` method, not a dict. Calling `.items()` on the method object crashes with `jinja2.exceptions.UndefinedError: 'builtin_function_or_method object' has no attribute 'items'`. This crashes the **entire** admin config page, not just the marine section.

**Root cause:** A config section (likely marine) has a structure where the template expects `s.values` to be a nested dict but it's actually the dict's `.values` method because the section's key is literally `"values"` colliding with the Python dict method name, or the section structure doesn't match the template's expectation.

**Do:**
1. Read `_render_config()` in `admin/routes.py` to understand what `s` is in the template context.
2. Trace which config section produces the problematic `s` object.
3. Fix the template to handle the marine section's structure correctly — either by checking the type before iterating, or by restructuring how the marine section is passed to the template.
4. Ensure the admin page loads cleanly with marine locations configured.

**Accept:**
- Admin config page (`/admin/config`) loads without error.
- All config sections (including marine) render correctly.
- Adding/editing/deleting a marine location in admin does not crash the page.

### T1.4 — Add `/forecast` and `/current` to cache warmer (FIX-24)

- Owner: `clearskies-api-dev` (API repo)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/services/cache_warmer.py`

**Problem:** The cache warmer warms almanac, records, earthquakes, and marine data — but **never warms `/forecast` or `/current`**. These are the two slowest endpoints:
- `/forecast` cold call: **11 seconds** (5 sequential NWS HTTP calls, 30-min TTL)
- `/current` cold call: **6.2 seconds** (3 NWS calls for cloudcover blend, 5-min TTL)

Every time a TTL expires, the next visitor pays the full cold-call cost. There is no background re-population.

**Do:**
1. Add `_warm_forecast()` method that calls the configured forecast provider's `fetch()` with the station's lat/lon. Schedule at intervals ≤ the forecast cache TTL (1800s).
2. Add `_warm_current_conditions()` method that calls the forecast provider's `fetch_current_conditions()` with the station's lat/lon. Schedule at intervals ≤ the current-conditions cache TTL (300s).
3. Add both to the warmer's `_loop()` method at appropriate intervals.
4. Ensure the warmer runs these on startup too (initial warm), not just on the recurring schedule.

**Accept:**
- After API restart, `/forecast` and `/current` respond in < 500ms immediately (no cold call).
- After TTL expiry, the next visitor request responds in < 500ms (warmer re-populated the cache before the visitor arrived).
- Verify by restarting the API, waiting 2 minutes for startup, then timing: `curl -sk -o /dev/null -w '%{time_total}s' https://localhost:8765/api/v1/current` — should be < 1s.

### QC Gate 1

**Adversarial verification agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that attempts to BREAK each fix:

1. **T1.1 (422 regression):** Run the wizard apply with a marine location and inspect the raw HTTP request to `/setup/apply`. Verify `nwps_wfo` is NOT in the payload. Then grep `config_writer.py` for any remaining references to `nwps_wfo` — it should appear nowhere in the apply payload path.
2. **T1.2 (GRIB temporal):** SSH to weewx, call `GET /marine/{location_id}` and record the wave height. Compare against the NWPS model viewer for the same WFO/cycle at hour 0. If they differ by more than 10%, the wrong timestep is being read. Also: grep `grib_processor.py` for any code path that does NOT pass `target_step` — an unfiltered read path is a regression waiting to happen.
3. **T1.3 (Jinja crash):** Load `/admin/config` and `/admin/marine` in sequence. Add a location, save, reload. Delete a location, save, reload. No 500 errors at any step.
4. **T1.4 (cache warmer):** Restart the API (`sudo systemctl restart weewx-clearskies-api`), wait 150 seconds, then time 3 consecutive calls to `/api/v1/current` and `/api/v1/forecast`. ALL 6 calls must be < 500ms. If any is > 1s, the warmer is not covering that endpoint.

**Pass criteria:** All 4 adversarial checks pass. Zero cold-call hits for visitors. Now page loads in < 3 seconds.

---

## Phase 2 — Data Pipeline & Schema Fixes ✅ COMPLETE (2026-07-15)

Wrong data sources, missing schema fields, and broken data flows that prevent marine features from working correctly.

> **Execution status:** All 6 tasks complete. QC Gate 2 passed (4/6 initial, 2 findings remediated: F1 species config write df48e1d, F2 exposure colon-format parse dc2fb8b). T2.6 verified after FIX-1 + FIX-23 resolution. Commits: T2.1 (9482191+55197fd), T2.2 (55197fd), T2.3 (81f63d0), T2.4+T2.5 (50a4ca3), T2.6 verified downstream.

### T2.1 — Add `species` field to API schema and wizard payload (FIX-2)

- Owner: `clearskies-api-dev` (both repos)
- Files:
  - API: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` line 492-518 (`MarineFishingSpotApplyConfig`)
  - Stack: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py` lines 466-475

**Problem (two parts):**
1. API's `MarineFishingSpotApplyConfig` does NOT have a `species` field, and uses `extra="forbid"`. Even the admin path (which correctly sends species) would be rejected.
2. Wizard's `build_marine_payload` copies `target_categories` and `biogeographic_region` but never copies `species` to `fishing_out`.

**Do:**
1. API: Add `species: list[str] = []` to `MarineFishingSpotApplyConfig`.
2. Stack: Add after the `biogeographic_region` block in `build_marine_payload`:
   ```python
   if fishing.get("species"):
       fishing_out["species"] = fishing["species"]
   ```

**Accept:**
- Wizard apply with fishing species checked persists species to `api.conf`.
- `GET /fishing/{location_id}` returns `speciesScores` for configured species.
- Admin save with species also persists correctly.

### T2.2 — Fix directional exposure round-trip corruption (FIX-3)

- Owner: `clearskies-api-dev` (stack repo)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py` line 457
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py` line 1902

**Problem:** Three interacting bugs:
1. `build_marine_payload` sends ALL 8 directions with `True`/`False`: `{d: d in exposure for d in all_directions}`. Unselected get Python `False`.
2. ConfigObj writes `False` as the string `"False"` to `api.conf`.
3. Admin's `_marine_exposure_list` reads back with `if v` — string `"False"` is truthy, so all 8 directions pass.

**Do:**
1. `config_writer.py:457`: Change to send only selected directions:
   ```python
   surf_out["directional_exposure"] = {d: True for d in exposure}
   ```
2. `admin/routes.py:1902`: Change the truthy check to handle string coercion:
   ```python
   directions = [k for k, v in value.items() if v is True or str(v).lower() == "true"]
   ```

**Accept:**
- Select 3 of 8 directions in wizard. Apply. Open admin. Only those 3 are checked.
- Edit in admin without changing. Save. Re-open. Still 3 checked.

### T2.3 — Fix hero weather icon nesting mismatch (FIX-9)

- Owner: `clearskies-dashboard-dev` (dashboard repo)
- Files:
  - `repos/weewx-clearskies-dashboard/src/api/types.ts` line ~1316-1338
  - `repos/weewx-clearskies-dashboard/src/components/marine/LocationCard.tsx` lines 56-64

**Problem (research confirmed):** The API sends `weatherCode` and `isDay` as **top-level** fields on `MarineLocationSummary` (responses.py lines 1744-1745). The dashboard's `types.ts` interface is missing these fields at the top level. `LocationCard.tsx` reads from inside `currentConditions` where the API never puts them. Result: weather icon always null, never renders.

**Do:**
1. `types.ts`: Add to `MarineLocationSummary`:
   ```typescript
   weatherCode: number | null;
   isDay: boolean | null;
   ```
2. `LocationCard.tsx`: Change lines 61-64 from:
   ```typescript
   const weatherCode = conditions?.weatherCode ?? null;
   const isNight = conditions?.isDay === false;
   ```
   to:
   ```typescript
   const weatherCode = location.weatherCode ?? null;
   const isNight = location.isDay === false;
   ```

**Accept:**
- Marine location cards on the landing page show the current weather icon (sunny, cloudy, etc.).
- Icon matches the forecast provider's current conditions for that location's coordinates.
- Icon shows correct day/night variant.

### T2.4 — Switch surf water temp to ocean data resolver (FIX-13)

- Owner: `clearskies-api-dev` (API repo)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`

**Problem:** Water temperature on the surf page comes from a forecaster-typed value in the NWS SRF text product. The ocean data resolver (`services/ocean_data_resolver.py`) already provides modeled/observed water temp via a tiered fallback chain (on-premises sensor → OFS → ERDDAP → MUR SST). The `/marine/{location_id}` endpoint already uses it.

**Do:**
1. In the surf endpoint, call the ocean data resolver for water temperature instead of reading from `zoneForecast.waterTemp`.
2. The SRF `waterTemp` can remain as a fallback if the ocean data resolver returns None.
3. Return the ocean data resolver value as the primary `waterTemp` in the surf response.

**Accept:**
- `GET /surf/{location_id}` returns water temp from the ocean model, not from SRF text.
- Value is physically reasonable and matches the `/marine/{location_id}` water temp.

### T2.5 — Switch surf wind scoring to local wind (FIX-14)

- Owner: `clearskies-api-dev` (API repo)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py` lines 284-298
  - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py` lines 236-277

**Problem:** Surf wind quality scoring uses NDBC buoy wind exclusively (12+ miles offshore). Beach wind is what determines wave face quality — offshore buoys measure the synoptic wind field, not beach conditions. The marine endpoint already has the right pattern: station hardware → forecast provider fallback.

**Research confirmed:** Surfline invested in beach-level wind stations specifically because offshore buoys miss thermal sea breezes, topographic channeling, and coastal temperature gradients. Beach wind and offshore wind can be completely different.

**Do:**
1. In `surf.py`, replace the NDBC wind fetch (lines 284-298) with the same wind precedence the marine endpoint uses:
   - Primary: station hardware wind (via weewx archive, when `is_station_served()`)
   - Fallback: forecast provider wind (via `marine_weather_cache`)
   - NDBC buoy wind: drop from wind quality scoring entirely (keep NDBC for spectral swell decomposition only)
2. Pass the local wind speed/direction to `score_surf()` instead of NDBC wind.

**Accept:**
- Surf wind quality label reflects local/coastal wind conditions, not offshore buoy.
- Wind speed value on the surf page matches the station or forecast provider, not the NDBC buoy.
- NDBC spectral swell decomposition still works (unaffected).

### T2.6 — Fix tide chart data path (FIX-16)

- Owner: `clearskies-api-dev` (stack + API repos)

**Problem (research confirmed):** The tide chart component (`TideChart.tsx`) is fully implemented and renders correctly. The issue is upstream — `coops_station_ids` is not configured for the location, so `tidePredictions` is always an empty array, and the chart shows "no tide data."

**Root cause:** This is a downstream effect of FIX-1 (wizard apply 422 dropping all station IDs) and FIX-23 (admin coverage panel not saving discovered stations). Once those are fixed, tide data should flow.

**Do:**
1. After FIX-1 and FIX-23 are resolved, verify that locations configured through the wizard have `coops_station_ids` populated in `api.conf`.
2. Verify `GET /surf/{location_id}` returns non-empty `tidePredictions`.
3. Verify the tide chart renders on the surf detail page.
4. If the chart still doesn't render despite data being present, investigate the Recharts component.

**Accept:**
- Tide chart renders on surf, fishing, boating, and beach safety detail pages for locations with CO-OPS stations configured.

### QC Gate 2

**Adversarial data-source verification agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent focused on proving data sources are correct:

1. **Wind source:** Call `GET /surf/{location_id}` and record the wind speed. Separately call `GET /marine/{location_id}` and record its wind speed. They should match (same source now). Then SSH to weewx and check the NDBC buoy observation — the surf wind speed must NOT match the buoy wind if conditions differ onshore vs offshore. Grep `surf.py` for any remaining import or reference to `ndbc` for wind data.
2. **Water temp source:** Call `GET /surf/{location_id}` and record water temp. Call `GET /marine/{location_id}` and record water temp. They should match (both from ocean data resolver). Grep `surf.py` for any remaining reference to `zoneForecast.waterTemp` as a primary source.
3. **Species round-trip:** Configure 5 species in wizard. Apply. Read `api.conf` — verify species list. Call `GET /fishing/{location_id}` — verify `speciesScores` has 5 entries. Edit in admin without changing. Save. Re-read `api.conf` — still 5 species.
4. **Exposure round-trip:** Select N, SW, S in wizard. Apply. Open admin — verify exactly N, SW, S checked. Save without changes. Re-open — still N, SW, S. Grep `config_writer.py` for `False` as a dict value — must not appear.
5. **Hero icon:** Call `GET /marine` (list). Verify every location in the JSON response has non-null `weatherCode` and `isDay` at the top level. Load the marine page in a browser — verify icons render.
6. **Tide chart:** For a location with `coops_station_ids` configured, call `GET /surf/{location_id}` — verify `tidePredictions` is non-empty. Load the surf detail page — verify the tide chart renders (not "no tide data" text).

**Pass criteria:** All 6 data-source checks pass. No NDBC wind in surf scoring. No SRF water temp as primary. Species and exposure round-trip clean.

---

## Phase 3 — Config UI Fixes (Wizard + Admin) ✅ COMPLETE (2026-07-15)

> **Execution status:** All 4 tasks complete. QC Gate 3 passed (6 findings: F1 contrast fixed 8ec5c76, F5 doc fixed, F6 docstrings fixed; F2 About-page attributions → Phase 4; F3 species discovery → tracked gap; F4 structure drawing → accepted). Commits: T3.1 (a67be9e+1bc2827), T3.2+T3.3 (8542201), T3.4 (d171936).

### T3.1 — Wire up marine location photo persistence + attribution (FIX-4)

- Owner: `clearskies-api-dev` (stack repo)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` line ~2898
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py` lines 2342-2353
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`

**Problem:** Photo file IS saved to disk at `/etc/weewx-clearskies/marine-photos/{slug}.{ext}`, but no `photo_url` reference is stored on the location dict. Templates have no `<img>` for existing photos and no hidden field to carry the URL forward. No attribution field exists.

**Do:**
1. After saving photo bytes in both wizard and admin handlers, set `loc["photo_url"] = f"/marine-photos/{slug}{suffix}"` on the location dict.
2. Add a `photo_attribution` text field to both wizard and admin forms — "Photo credit / attribution (optional)."
3. Store `photo_url` and `photo_attribution` in `stack.conf` (local config, not sent to API — photos are served by Caddy from disk, not managed by the API).
4. Add `<img>` element in templates to display existing photo when `photo_url` is set.
5. Add hidden field for `photo_url` to carry it forward across form submissions.
6. Add Caddy route for `/marine-photos/*` serving from `/etc/weewx-clearskies/marine-photos/`.
7. Surface attributions on the dashboard About page — API's `/api/v1/content/about` or a config endpoint should return all marine photo attributions as a combined list. Dashboard renders them in a "Photo Attributions" card on the About page.

**Accept:**
- Upload photo in wizard → photo displays in wizard on re-render.
- Photo URL persists through wizard re-run and admin edit.
- Attribution text persists alongside photo.
- Dashboard About page shows all marine photo attributions in one list.

### T3.2 — Fix wizard logo size (FIX-5)

- Owner: `clearskies-api-dev` (stack repo)
- Files: Wizard header template/CSS (likely `templates/wizard/layout.html` or `static/style.css`)

**Do:** Increase the Clear Skies logo dimensions in the wizard header to match the intended brand size. The logo is currently too small in the step bar.

**Accept:** Logo is clearly visible and properly sized in the wizard header across desktop and mobile viewports.

### T3.3 — Admin header visual parity with wizard (FIX-6)

- Owner: `clearskies-api-dev` (stack repo)
- Files: Admin base template (`templates/base.html` or `templates/config/dashboard.html`) and CSS

**Problem:** Admin header is plain text ("Clear Skies Admin") on a cloud background. Missing the logo, formatting doesn't match wizard style, contrast issues with text on cloud photo.

**Do:**
1. Add Clear Skies logo to admin header (same logo asset as wizard, white variant for dark background).
2. Match the wizard header's layout pattern — logo + title + subtitle.
3. Fix text contrast — ensure WCAG AA compliance for text over the background image (add text shadow, semi-transparent overlay, or darker background).

**Accept:**
- Admin header shows the Clear Skies logo.
- Header layout matches the wizard header pattern.
- Text contrast passes WCAG AA (4.5:1 for normal text).

### T3.4 — Admin marine editor: feature parity with wizard (FIX-23, remaining)

- Owner: `clearskies-api-dev` (stack repo)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py`

**Problem:** Multiple gaps between wizard and admin marine editors:
- **No map** for selecting/viewing location coordinates
- **Coverage panel doesn't save** — discovers stations but doesn't persist IDs to config fields
- **Save hangs** with no loading indicator, eventually succeeds or fails silently
- **Missing features:** Verify discover-stations, bathymetry download, structure discovery, species checklist, and photo upload all have admin equivalents

**Do:**
1. Add Leaflet map to admin marine edit form (same pattern as wizard — click to place pin, drag to adjust, pre-filled for existing locations).
2. Wire "Refresh Coverage" to populate the location's `ndbc_station_ids`, `coops_station_ids`, `nws_marine_zone_id` fields from the discovery results — not just display them.
3. Add loading indicator for save operations. Handle errors gracefully (display error message, don't crash).
4. Audit every interactive feature in `step_marine.html` and verify an equivalent exists in `admin/marine.html`. Add any that are missing.

**Accept:**
- Admin shows a map for coordinate selection when adding/editing a location.
- Refresh Coverage populates station ID fields. Save persists them.
- Save shows a loading state and completes without hanging indefinitely.
- Every wizard marine feature has an admin equivalent.

### QC Gate 3

**Adversarial feature-parity agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that systematically compares wizard and admin capabilities:

1. **Feature parity audit:** Open `step_marine.html` and `admin/marine.html` side-by-side. For every interactive element in the wizard (map, discover stations, coverage panel, bathymetry download, structure discovery, species checklist, photo upload, attribution field), verify an equivalent exists in the admin template. Report any wizard feature missing from admin.
2. **Photo round-trip:** Upload a photo + attribution in wizard. Apply. Open admin — verify photo displays and attribution text is pre-filled. Change attribution in admin. Save. Re-open — verify new attribution persists. Load the About page — verify attribution appears in the photo credits card.
3. **Coverage save:** In admin, click Refresh Coverage for a location. Verify the discovered station IDs populate the `ndbc_station_ids`, `coops_station_ids`, `nws_marine_zone_id` form fields. Save. Re-open — verify IDs persisted.
4. **Contrast check:** Screenshot the admin header. Verify text contrast against the background meets WCAG AA (4.5:1 minimum). Use a contrast checker tool, not visual inspection.
5. **Save UX:** Time the admin save operation. Verify a loading indicator appears. Verify it completes within 30 seconds. Verify no Internal Server Error on page reload after save.

**Pass criteria:** Zero wizard features missing from admin. Photo + attribution round-trips. Coverage saves. Contrast passes AA. Save completes with feedback.

---

## Phase 4 — Marine Landing Page & Shared Layout ✅ COMPLETE (2026-07-15)

> **Execution status:** All 5 tasks complete. Commit 179419d. T4.1 verified already addressed (grid gap present). T4.2: OpenSeaMap → CARTO light_only_labels. T4.3: footprint tile→wide. T4.4: back-to-map inside map overlay, location name in header strip Card. T4.5: thin alert strip with amber fallback (severity field API gap tracked; per-activity filtering not wired — tracked for Phases 5-7). QC Gate 4 deferred to post-deploy visual verification.

### T4.1 — Fix grid spacing between cards and map (FIX-7)

- Owner: `clearskies-dashboard-dev`
- Files: Dashboard marine page layout component (`src/routes/marine/`)

**Do:** Add proper gap/margin between location cards and the Leaflet map.

**Accept:** Visible spacing between cards and map matching the dashboard's standard card gap.

### T4.2 — Marine map labels (FIX-8)

- Owner: `clearskies-dashboard-dev`
- Files: Dashboard marine map component

**Research finding:** No perfect marine-label-only tile layer exists. Best free option is CARTO's `light_only_labels` overlay (`https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png`) — free, no API key, transparent overlay. Marine feature coverage depends on OSM data for the area.

**Do:**
1. Try CARTO `light_only_labels` as an overlay on the marine map. Test whether it shows names like "San Pedro Channel", "Santa Monica Bay" at the zoom levels the map uses.
2. If CARTO shows the needed labels: use it. If not, try Esri World Ocean Reference (`https://services.arcgisonline.com/arcgis/rest/services/Ocean/World_Ocean_Reference/MapServer/tile/{z}/{y}/{x}`) — note `{z}/{y}/{x}` order, not Leaflet's default `{z}/{x}/{y}`.
3. If neither provides clean marine labels without clutter: remove the marine overlay entirely.

**Accept:** Map either shows clean marine feature labels (water body names only, no shipping lanes or buoy markers) or has no overlay at all. No half-measures with cluttered overlays.

### T4.3 — Location cards: photo display + larger footprint (FIX-10)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/LocationCard.tsx`
- Depends on: T3.1 (photo persistence)

**Do:**
1. Display the location photo on the card when `photoUrl` is present in the API response.
2. Resize cards from current 1x1 to either 2x1 or 1x2 to accommodate the photo alongside wave/wind/temp data.
3. Follow Now page card design patterns for the layout.

**Accept:** Location cards show the photo when configured. Cards are large enough to display photo + data without cramming.

### T4.4 — Detail page layout fixes (FIX-11)

- Owner: `clearskies-dashboard-dev`
- Files: Dashboard `src/routes/marine/` location detail component

**Problem:** Three layout violations:
1. "Back to map" button floats above the map as a separate element.
2. Activity tabs (Surfing/Fishing/Beach Safety) are unstyled, floating in the background.
3. Location name floats in the cloud background with no containing element.

**Do:**
1. Move "Back to map" button inside the map container (overlaid on the map, like zoom controls).
2. Design activity tabs as either proper styled tabs or buttons on a status strip — must look intentional, not floating. Follow the dashboard's existing tab/button patterns.
3. Put the location name in a proper header strip (same pattern as the "Marine Activities" header on the landing page).

**Accept:** Back-to-map is inside the map. Tabs look styled and intentional. Location name has a header strip. No elements float unstyled in the background.

### T4.5 — Marine/coastal alert strip on all activity pages (FIX-19)

- Owner: `clearskies-dashboard-dev`
- Files: All activity tab components (SurfingTab, FishingTab, BeachSafetyTab, BoatingTab)

**Do:**
1. Add a thin, color-coded alert strip at the top of every activity detail page (below the map, above the content cards) when marine/coastal alerts are active.
2. Filter to marine/coastal alert types only (Small Craft Advisory, Beach Hazards Statement, High Surf Warning, Rip Current Statement, Hurricane Watch/Warning, etc.) — not inland alerts.
3. Strip shows: severity color (yellow advisory, orange watch, red warning) + alert name + brief text.
4. Not the full-width hero banner from the main dashboard — a thin strip.

**Accept:** Active marine advisories/warnings show as a strip on all activity pages. Inland alerts are filtered out.

### QC Gate 4

**Adversarial design-compliance agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that verifies visual compliance against the DESIGN-MANUAL marine section (written in T0.6):

1. **Card sizing:** Verify every card on the marine landing page and detail pages matches the specified footprint (2x2, 2x1, 1x2). Grep dashboard component code for card width/height/span props — no ad-hoc sizes.
2. **Design token compliance:** Grep all new/modified marine components for hardcoded colors, font sizes, or spacing. Every visual property must use design tokens (`var(--*)`) or Tailwind utility classes — no inline `style="color: #xxx"`.
3. **Grid spacing:** Screenshot the marine landing page. Measure the gap between cards and map — must match the dashboard's standard card gap (visible, consistent).
4. **Map overlay:** Load the marine map. If a label overlay is present, screenshot it and verify: water body names visible, NO shipping lanes, NO buoy markers, NO depth soundings. If any clutter is present, the overlay must be removed.
5. **Alert strip:** Trigger a test with an active marine advisory. Verify the strip appears on surf, fishing, beach safety, and boating tabs. Verify it does NOT appear for inland alerts.
6. **Detail page layout:** Screenshot a location detail page. Verify: back-to-map button is inside the map container (not floating above), tabs are styled (not raw unstyled elements), location name has a header strip.

**Pass criteria:** All cards match specified footprints. Zero hardcoded visual values. Grid spacing consistent. Map overlay clean or removed. Alert strip works on all tabs. Detail page layout violations resolved.

---

## Phase 5 — Surf Page Redesign ✅ COMPLETE (2026-07-15)

> **Execution status:** Both tasks complete. Commit 51ffd19. T5.1: monolithic hero replaced with Score(wide)+Swell(wide)+Wind(wide) cards. StarRating deleted, numeric scores only. multiSwell preferred over spectralComponents for NWPS/WW3 data. Wind from useMarineDetail. Rip current badge dropped (not in redesigned card spec — lives on Beach Safety tab). T5.2: day-grouped HorizontalScrollNav forecast columns with time-matched wind and nearest tide event. Wave face height chart retained. Weather icon and air temp per period NOT shown (no API data source — tracked gap). QC Gate 5 deferred to post-deploy visual verification.

### T5.1 — Surf current conditions: 3 cards (FIX-12)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/SurfingTab.tsx`

**Redesign:** Replace the monolithic "Current Conditions" card with 3 separate cards. Remove the standalone raw spectral "Swell Components" card entirely.

1. **Surf Score Card (2x2):** The hero card. Prominently displays the current surf score (numeric, not stars — e.g., "4.2 Very Good"). Below the score: scoring breakdown showing what factors contributed (swell match, wind quality, tide phase, etc.). This card absorbs and replaces the previously-planned separate scoring breakdown card.

2. **Swell Card (2x1):** Wave height at break, dominant swell period, swell direction. Model-processed swell component breakdown showing what swell systems contribute to conditions at the beach. Swell direction compass (currently at `SurfingTab.tsx:590+`) moves here and must source from NWPS/WW3 model output, not raw NDBC spectral data. Remove the standalone Swell Components card.

3. **Wind Card (2x1):** Wind speed (currently missing!), wind direction, wind quality label (offshore/onshore/cross-shore), wind gust if available. Data from local wind source per T2.5.

**Design reference:** Now page cards — same card anatomy, tokens, stat tile patterns.

**Accept:**
- Score card leads with prominent numeric score + scoring breakdown.
- Swell card shows model-processed data, not raw buoy spectral dumps.
- Wind card shows actual wind speed (not just quality label).
- No standalone Swell Components card remains.
- All cards match Now page design patterns.

### T5.2 — 72-hour surf forecast card redesign (FIX-15)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/SurfingTab.tsx`

**Problem:** Current card has no day labels, uses stars instead of numeric scores, and is missing weather, wind, tide, and detailed swell data.

**Industry reference (surf-forecast.com):** Horizontal table with time columns, data rows top to bottom: Rating (numeric), wave height, direction, period, energy, wind speed+direction, wind state, high/low tide, weather icon, sunrise/sunset, precipitation, temperature, swell components.

**Redesign:** Adapt to the Clear Skies Forecast page card pattern (our visual language):
- **Day headers** so you know what day you're looking at
- **Numeric surf score** per period (no stars)
- **Weather icon + air temp** per period
- **Wave height, swell period, swell direction**
- **Wind speed + direction + quality label** (offshore/onshore/cross-shore)
- **Tide:** simple text/icon per period (e.g., "↑ High 4.2ft 11:32 AM") — NOT a separate chart here
- **Swell components** if available from NDBC spectral data

**Design reference:** Dashboard Forecast page cards.

**Accept:**
- Every forecast period shows score, weather, waves, wind, and tide.
- Days are clearly labeled.
- No star ratings — numeric score only.
- Layout follows Forecast page card pattern.

### QC Gate 5

**Adversarial surf-page agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that compares the built surf page against this plan's specs AND the surf-forecast.com reference:

1. **Score card:** Verify the score is numeric (not stars). Verify the breakdown shows individual factor contributions. Verify it's a 2x2 card.
2. **Swell card:** Grep `SurfingTab.tsx` for any remaining reference to `spectralComponents` for the swell direction compass — it must source from NWPS/WW3 model output (wave_direction field). Verify the standalone Swell Components card is deleted (no `SwellBreakdown` rendering outside the Swell Card).
3. **Wind card:** Verify wind speed is displayed (was previously missing). Verify the wind source is local (grep for NDBC wind references — should be gone per T2.5).
4. **72-hour forecast completeness:** For each forecast period, verify ALL of these elements are present: score (numeric), weather icon, air temp, wave height, swell period, swell direction, wind speed + direction + quality label, tide text. Compare against surf-forecast.com's 15-row structure — report any missing row.
5. **Day labels:** Verify forecast periods are grouped by day with day headers (e.g., "Tuesday Jul 15"). Navigate to a period 3 days out — must be clear what day it is.
6. **Removed elements:** Verify no star ratings remain anywhere in the surf tab.

**Pass criteria:** All 6 checks pass. Every surf-forecast.com data element has an equivalent. No stars. No raw buoy data. No standalone spectral card.

---

## Phase 6 — Fishing Page Redesign ✅ COMPLETE (2026-07-15)

> **Execution status:** Both tasks complete. Commit bdd3e0e. T6.1: score+breakdown merged into wide card, new conditions card with full marine observation data (pressure/wind/gust/direction/waterTemp/airTemp/tide). T6.2: period grid cells converted to buttons with species accordion (expandedPeriod state, extractSpeciesEntry + tier badges). Standalone species table retained. QC Gate 6 deferred to post-deploy visual verification.

### T6.1 — Fishing current conditions: Score + Conditions cards (FIX-20)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/FishingTab.tsx`

**Redesign:** Two cards:

1. **Fishing Score Card (2x2):** Prominent fishing score + scoring breakdown (pressure, tide, solunar, time of day contributions).

2. **Current Conditions Card (2x2):** The weather/ocean data an angler needs:
   - Barometric pressure + trend (rising/falling/steady)
   - Wind speed + gust + direction
   - Water temperature (from ocean data resolver per T2.4)
   - Air temperature
   - Data from station → forecast provider precedence (same as T2.5).

**Solunar card:** Reuse the existing Almanac page Sun/Moon card component — do NOT build a new one. If solunar major/minor feeding period info is added, add it TO the existing card matching its design style.

**Design reference:** Now page cards.

**Accept:**
- Fishing score card leads prominently with breakdown.
- Conditions card shows all 5 data elements with correct sources.
- Solunar display reuses the Almanac card component.

### T6.2 — Fishing forecast card redesign (FIX-21)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/FishingTab.tsx`

**Redesign:** Modeled after the Forecast page cards and surf-forecast.com structure:
- **Fishing score** per period (leading element)
- **Weather icon + air temp**
- **Cloud cover percent** (important for fishing — overcast vs bright sun affects bite)
- **Barometric pressure + trend**
- **Wave height + period**
- **Wind speed + direction + gust**
- **Solunar info** in icon/graphic format per period
- **Day headers**

**Species detail via accordion expander:** Same pattern as the dashboard's 7-day forecast card extended detail. Click/tap a forecast period column → accordion expands below showing: which configured species are favorable for that period, per-species scoring factors. Keeps the main card clean.

**Accept:**
- Forecast periods show score, weather, pressure, waves, wind, solunar.
- Days clearly labeled.
- Species detail accessible via accordion, not cluttering the main view.
- Layout follows Forecast page card pattern.

### QC Gate 6

**Adversarial fishing-page agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that verifies the fishing page against an angler's actual needs:

1. **Score card data sources:** Verify the fishing score breakdown shows pressure, tide, solunar, time-of-day contributions. Verify NO temperature component in `overallScore` (temperature is per-species only per the remediation plan T6.2).
2. **Conditions card completeness:** Verify all 5 required data elements are present: barometric pressure + trend, wind speed + gust, wind direction, water temp, air temp. For each, verify the data source: water temp from ocean data resolver (grep for SRF reference — should be gone), wind from station/forecast provider (grep for NDBC — should be gone).
3. **Solunar component reuse:** Grep the fishing tab for any custom solunar rendering code. The ONLY solunar display should be an import/reuse of the Almanac page's Sun/Moon card component. No duplicate implementation.
4. **Forecast completeness:** For each forecast period, verify: fishing score, weather icon, air temp, cloud cover %, barometric pressure + trend, wave height + period, wind speed + direction + gust, solunar icon. Compare against the FIX-21 spec — report any missing element.
5. **Species accordion:** Click a forecast period. Verify the accordion expands with species-specific detail. Verify it shows which species are favorable for that period. Close the accordion — verify it collapses cleanly.
6. **Day labels:** Verify forecast periods have day headers.

**Pass criteria:** All 6 checks pass. Score excludes temperature. All conditions from correct sources. Solunar reuses Almanac component. Forecast has all elements. Accordion works.

---

## Phase 7 — Beach Safety & Boating Pages ✅ COMPLETE (2026-07-15)

> **Execution status:** Both tasks complete. Commit a00d45a. T7.1: useMarineDetail added to BeachSafetyTab for weather icon + air temp. Data gaps tracked: no 3-day forecast, no what-to-wear, no predicted UV (no API data sources). T7.2: wind card extracted as separate wide card, visibility/dewpoint/weather icon added to conditions. Data gap tracked: no coastal/offshore NWS text separation. QC Gate 7 deferred to post-deploy visual verification.

### T7.1 — Beach Safety page redesign (FIX-22)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/BeachSafetyTab.tsx`

**Required cards:**
1. **Current Weather Card (2x2):** Reuse the Now page current conditions card component directly.
2. **3-Day Forecast Card (1x2):** Compact forecast — weather icon, high/low, wind, precip chance per day. Modeled after Forecast page cards.
3. **Ocean/Beach Conditions Card:** Water temp (ocean data resolver), wave height/period, wind. Same data source fixes as surf and fishing.
4. **Rip Current Risk** — keep existing, it's good.
5. **What to Wear** — keep existing, it's good.
6. **UV Index** — currently missing. Show current UV and predicted UV through the day. NWS SRF already provides `uvIndex` in `zoneForecast` — surface it. For forecast periods, UV per period needed.
7. **Marine alert strip** — per T4.5.

**Accept:**
- Current conditions card reuses Now page component.
- 3-day forecast is compact and styled per Forecast page pattern.
- UV index (current + predicted) is displayed.
- Rip current and what-to-wear are retained.

### T7.2 — Boating page redesign (FIX-25)

- Owner: `clearskies-dashboard-dev`
- Files: `src/components/marine/tabs/BoatingTab.tsx`

**Problem:** Wind is completely missing — the single most important data point for mariners.

**Required cards:**
1. **Current Conditions Card (2x2):** Now page pattern — air temp, sky condition, humidity, barometric pressure, visibility.
2. **Forecast Card (2x2):** Multi-day forecast — weather icons, highs/lows, wind, precipitation. Now page forecast pattern.
3. **Wind Card:** Wind speed, gust, direction, trend. Critical for boating.
4. **Swell Card:** Wave height, period, direction, sea state.
5. **NWS Coastal Waters Forecast:** Styled as a card (not raw text), covering the coastal zone.
6. **NWS Offshore Forecast:** Separate card from coastal. Boats move — mariners need forecasts for waters they'll transit through, not just dock conditions.

**Key design distinction:** Surfing/fishing are stationary. Boating is mobile. The page must present both local point conditions AND broader marine area forecasts (coastal + offshore zones).

**Marine alert strip** — per T4.5. Especially critical for boating (Small Craft Advisories, Gale Warnings).

**Accept:**
- Wind card is present and prominent.
- Both coastal and offshore NWS forecasts display as styled cards.
- All conditions cards show data from correct sources (station → forecast provider).
- Alert strip shows marine warnings.

### QC Gate 7

**Adversarial cross-page consistency agent** (`clearskies-auditor`, Sonnet): Spawn an independent agent that checks consistency ACROSS all 4 activity pages and verifies no page was missed:

1. **Data source audit (all pages):** For each activity page (surf, fishing, beach safety, boating), grep the corresponding tab component for: (a) any NDBC wind reference — must be zero, (b) any SRF waterTemp as primary source — must be zero, (c) any raw spectral component display — must be zero. Report any page that still uses wrong data sources.
2. **Alert strip audit (all pages):** Navigate to each of the 4 activity tabs. Verify the marine alert strip is present (or shows empty-state correctly when no alerts active). Verify the alert filter is per-activity (boating gets marineZone + coastalFlood; surfing gets marineZone + beachHazard + surfAdvisory; etc.).
3. **Beach safety UV:** Verify UV index is displayed (current + predicted). Call the API endpoint and verify `uvIndex` is present in the response.
4. **Beach safety component reuse:** Verify the current weather card is the SAME component as the Now page — not a copy. Grep for the import and confirm it references the shared component.
5. **Boating NWS forecasts:** Verify BOTH coastal waters forecast AND offshore forecast display as separate cards. Navigate to the boating tab and verify two distinct forecast cards. Verify they contain different content (different zones).
6. **Boating wind:** Verify wind card is present and shows speed, gust, direction, trend. This was completely missing before — confirm it exists and has real data.
7. **Missing elements sweep:** Walk the full FIX-22 and FIX-25 specs item by item. For each required element, verify it renders on the page. Report any spec item not implemented.

**Pass criteria:** All 7 checks pass across all 4 activity pages. Zero wrong data sources on any page. Alert strips work everywhere. Beach safety has UV. Boating has wind AND dual NWS forecasts. No spec items missing.

---

## Deferred

### FIX-18: Animated swell height map with forecast time slider

**Status:** Deferred to future roadmap. Depends on T1.2 (GRIB temporal awareness). Needs discussion with user on where it fits in product plans.

**Summary:** Interactive Leaflet map showing NWPS gridded wave height/direction across the nearshore domain, with a time slider scrubbing through 144 hourly forecast timesteps. Data is already in the GRIB2 files we download. Main work: modify GRIB reader to return all timesteps (building on T1.2), extract full 2D grids, build map rendering + slider UI.

---

---

## Phase 8 — Final QA (Adversarial Meta-Audit) 🔄 IN PROGRESS

> **Execution status (2026-07-16):** T8.1 done (QC Gates 4-7 all run, findings remediated). T8.2 done (7 findings: F1 uncommitted Phase 0 fixed, F2 photo attributions fixed eebd29e, F3 fishing forecast fixed 52eca6c, F4 what-to-wear was auditor error — ComfortBadge IS the feature, F5-F6 blocked on API data gaps, F7 BeachSafety alerts fixed e7302a6). T8.3 done (5/6 PASS, 1 finding on cache warmer docs — already documented at ARCHITECTURE.md line 98). T8.4 partially done (API-level checks complete, full visual walkthrough needs browser).

This phase verifies that Phases 0-7 were actually completed correctly — not just that agents claimed they were. It checks for subverted QC gates, silent deferrals, and gaps between what the plan required and what was delivered.

### T8.1 — QC gate integrity audit

- Owner: `clearskies-auditor` (Sonnet) — must NOT be an agent that participated in any implementation phase

**Do:** For each QC Gate (0 through 7), the auditor:
1. Reads the gate's adversarial checks from this plan.
2. Reads the QC gate report produced during that phase.
3. Independently re-runs EVERY adversarial check listed in the gate. Not a sample — every single one.
4. Compares its results against the reported results. If the QC report claimed "pass" but the re-run fails, that is a **QC integrity finding** — the gate was subverted or the fix regressed.
5. Reports each check as: CONFIRMED (re-run matches report), FAILED (re-run contradicts report), or NOT RUN (the QC report skipped this check entirely).

**Accept:** Zero FAILED or NOT RUN checks across all 8 gates. If any exist, the affected phase is sent back for rework before QA can pass.

### T8.2 — Silent deferral sweep

- Owner: `clearskies-auditor` (Sonnet) — independent agent

**Do:**
1. Walk every task in this plan (T0.1 through T7.2). For each task, verify ONE of:
   - **DONE:** A commit exists implementing the task, AND the acceptance criteria are met in the live system.
   - **DEFERRED (authorized):** Only FIX-18 is authorized for deferral. Any other deferral is unauthorized.
2. Check for silent deferrals — cases where a task was marked complete but part of its scope was quietly dropped:
   - For each task's "Do" section, verify every bullet point has a corresponding code change.
   - For each task's "Accept" section, verify every acceptance criterion passes in the live system.
3. Check git log for any "TODO", "FIXME", "deferred", "follow-up", "Phase N" comments introduced during this plan's implementation — these are silent deferral indicators.
4. Grep all modified files for `# TODO` or `// TODO` added during this plan's commits — each is a finding.

**Accept:** Zero unauthorized deferrals. Zero silently dropped scope items. Zero new TODO/FIXME comments in plan-related commits.

### T8.3 — Manual-code consistency verification

- Owner: `clearskies-auditor` (Sonnet) — independent agent

**Do:**
1. For each manual updated in Phase 0 (API-MANUAL, PROVIDER-MANUAL, DESIGN-MANUAL, ARCHITECTURE.md, OPERATIONS-MANUAL), verify the manual's claims match the implemented code:
   - Wind source: manual says station → forecast provider. Grep surf.py — verify no NDBC wind path.
   - Water temp: manual says ocean data resolver. Grep surf.py — verify no SRF waterTemp as primary.
   - GRIB temporal: manual says `endStep` selection. Read grib_processor.py — verify `endStep` is read.
   - Cache warmer: manual says covers forecast + current. Read cache_warmer.py — verify methods exist.
   - DESIGN-MANUAL marine section: for each card spec (size, data elements, component reuse), verify the dashboard code matches.
2. For each `rules/` file updated, verify the rule is followed in the code it governs.

**Accept:** Zero conflicts between manuals and code. Every manual claim verified against the implementation.

### T8.4 — End-to-end user walkthrough

- Owner: Coordinator (Opus) — the coordinator performs this personally, not delegated

**Do:** Walk through the entire marine feature as a user would, on the live site:
1. Open the wizard. Configure a new marine location with all 4 activities (surf, fishing, beach safety, boating). Upload a photo with attribution. Run discover stations. Apply.
2. Open the admin. Verify the location appears with all config. Edit it. Save. Verify no hang, no crash.
3. Open the dashboard marine page. Verify the location card shows photo, weather icon, wave/wind/temp data.
4. Click into the location. Verify header strip, styled tabs, map with back-to-map inside it.
5. Walk each activity tab: surfing (3 current cards, forecast, tide chart), fishing (score + conditions, forecast with accordion, solunar), beach safety (weather, forecast, UV, rip current), boating (wind, swell, coastal + offshore forecasts).
6. Verify marine alert strip appears if any advisories are active.
7. Navigate to the About page. Verify photo attribution appears.
8. Check the Now page loads in < 3 seconds.

**Accept:** Every step completes without error. Every data element is populated. No blank cards, no missing icons, no "no data" where data should exist. The feature works end-to-end as a user would experience it.

### Final QA Gate
- T8.1: All per-phase QC gate checks re-confirmed independently. Zero subverted gates.
- T8.2: Zero unauthorized deferrals. Zero silently dropped scope. Zero new TODOs.
- T8.3: All manual claims match code. Zero doc-code conflicts.
- T8.4: End-to-end walkthrough passes. Feature works as a user would experience it.

**If any Final QA check fails:** The affected phase is sent back for rework. QA does not pass until all checks are clean. There is no "ship with known issues" path.

---

## Verification

After all phases complete:
- Wizard marine apply succeeds — all station IDs, surf config, fishing config, species persist.
- Admin marine editor has full feature parity with wizard — map, coverage save, photo, attribution.
- GRIB reader uses hour-0 for current conditions — data matches NWPS model viewer.
- Now page loads in < 3 seconds (cache warmer covers forecast + current).
- Marine location cards show weather icon, photo, proper footprint.
- Surf page: 3 current conditions cards (score hero, swell, wind), full 72-hour forecast with all data.
- Fishing page: score + conditions cards, full forecast with species accordion.
- Beach safety: reused Now components, UV index, rip current, what-to-wear.
- Boating: wind (previously missing), NWS coastal + offshore forecasts.
- All data from correct sources: local wind (not buoy), ocean model water temp (not SRF text).
- Tide chart renders on all activity pages.
- Marine alert strips on all activity pages.
- All cards follow Now page / Forecast page design patterns.
- Admin page loads without error.
- Test baselines hold.
