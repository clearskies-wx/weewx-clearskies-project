# Marine Implementation Remediation Plan

**Status:** APPROVED
**Created:** 2026-07-11
**Origin:** Post-deployment audit of the marine feature (Phases 1–8 of MARINE-SURF-FISHING-PLAN.md). Eight critical issues were found and fixed during the T8.2 deploy smoke test. The subsequent comprehensive audit (3 parallel agents, live API testing, cross-referencing all governing documents) surfaced 36 additional open items.

## Context

The marine feature shipped with significant integration gaps — providers coded against nonexistent API endpoints, providers never tested against live data, wizard-to-API contract mismatches, and dashboard rendering bugs. The root cause across all critical/high findings: **live API verification was skipped during implementation.** Providers were coded against documentation and research briefs without confirming the external APIs actually behave as described.

This plan remediates all 36 open findings from the audit, organized into 4 phases by severity and dependency.

## 0. Orientation — Execution Context

Same as MARINE-SURF-FISHING-PLAN.md §0 — read those files, use those deploy scripts, follow those SSH rules. Additionally:

**Audit scratchsheet:** `scratchpad/marine-audit.md` (session temp) — full finding details with evidence.

**Verification mandate:** Every provider fix in this plan MUST include a live API test as part of the acceptance criteria. "Code compiles and unit tests pass" is not sufficient — the provider must return real data from the real external API.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | 4097 passed, 341 skipped (pre-existing OWM AQI failures excluded) | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | 320 passed, 26 failed (pre-existing) | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

---

## Phase 1 — Critical Provider Fixes (P1–P3, P4–P6)

The NWS SRF parser is non-functional against live data, and the bathymetry provider uses a nonexistent API endpoint. These block beach safety and surf physics.

### T1.1 — Rewrite NWS SRF parser (P1, P2, P4, P5, P6)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nws_srf.py`
- Reference: PROVIDER-MANUAL §14.5, live SRF product from WFO ILM

**Problem:** The SRF parser has 5 structural issues that make it return empty results for every real SRF product:

1. **P1 — Rip current regex:** NWS uses `Rip Current Risk*...` with an asterisk footnote annotation. The regex `RISK\.\.\.` fails because of the `*` between "Risk" and the dots.
2. **P2 — False zone headers:** `_ZONE_HEADER_RE` matches any line starting with a letter and ending with `...`. Live SRF text has `Tides...`, `Remarks...`, `Weather...` lines that all match, causing the parser to skip real data blocks.
3. **P4 — UV Index regex:** NWS uses `UV Index**...` (double asterisk). Regex expects `INDEX\.\.\.`.
4. **P5 — Wind regex:** NWS uses `Winds.....` (plural "Winds"). Regex expects `WIND\.\.\.`.
5. **P6 — UGC zone boundaries:** Parser processes ALL period markers across the entire SRF text (which contains 5 county-zone sections separated by `$$`). It mixes data from all zones instead of extracting only the target zone's section.

**The real SRF format** (verified from live WFO ILM product):
- Structure: zone-then-period (not period-then-zone). Each zone starts with a UGC line (`NCZ108-120515-`), zone name, beach list, then period blocks (`.REST OF TODAY...`, `.SUNDAY...`, `.EXTENDED...`). Zones separated by `$$`.
- Field labels use dot-leaders with optional asterisk annotations: `Rip Current Risk*...........Moderate.`
- Period labels include `REST OF TODAY` (most common first period), day names (`SUNDAY`, `MONDAY`), `EXTENDED`.
- Some zones split fields into sub-regions (e.g., "East of Ocean Isle Beach" / "Ocean Isle Beach West").
- Footnote definitions appear after `&&` at end of each zone section.
- `_DAY_OFFSET_BY_LABEL` only knows 6 labels. Real products use day names and `REST OF TODAY`.

**Do:**
- Restructure parser: first split text by `$$` into zone sections. Match target zone by UGC code prefix. Parse only that section.
- Fix field regexes to allow optional `*{0,3}` between field name and dot-leaders.
- Fix `WIND` → `WINDS?` (allow optional trailing "s").
- Expand `_DAY_OFFSET_BY_LABEL` to handle day-of-week names and `REST OF TODAY`.
- Handle sub-region splits (take the first sub-region value, or average if numeric).
- Tighten zone header regex to not match field labels (`Tides...`, `Remarks...`, etc.).

**Accept:**
- `fetch(zone_id='NCZ108', wfo='ILM')` returns ≥2 `SurfZoneForecast` objects with non-null `ripCurrentRisk` and `surfHeightMin`.
- Live verification against WFO ILM SRF product shows correct extraction of rip current risk, surf height, UV index, wind text for the target county zone.
- Fetching a zone from a different WFO (e.g., `NCZ106`) returns that zone's data, not a mix of all zones.

### T1.2 — Fix bathymetry provider to use NCEI ArcGIS ImageServer + unified bounding box download (P3)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py`, `endpoints/setup.py`
- Reference: PROVIDER-MANUAL §14.7

**Problem:** The code queries `https://api.opentopodata.org/v1/cudem` but OpenTopoData's public API does not host a `cudem` dataset (returns 404 "Dataset 'cudem' not in config"). No real bathymetric data is ever retrieved — the system always falls back to generic regional profiles.

**The correct access method** (verified live during this audit): NCEI ArcGIS ImageServer at `https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_all/ImageServer/identify` serves actual CUDEM 1/9 arc-second (~3.4m) data via simple REST point queries:
```
GET /identify?geometry={lon},{lat}&geometryType=esriGeometryPoint&returnGeometry=false&f=json
→ {"value": "-3.30559", "catalogItems": {"features": [{"attributes": {"Name": "ncei19_n34x25_w078x00_2019v1"}}]}}
```
- Free, no API key, returns JSON
- Returns depth in meters (negative = below sea level)
- `catalogItems.features[0].attributes.Name` confirms the CUDEM tile used
- Same data source (NOAA CUDEM), correct access method

**Unified bounding box download:** The current implementation downloads one profile per location independently, and the wizard forces the operator to manually trigger each download. Operators configure multiple locations in the same coastal area — these share the same regional bathymetry. The fix:
1. After the operator confirms all marine locations (wizard apply or admin save), compute a single bounding box encompassing all configured locations (with padding for offshore transect extent — ~10km beyond the outermost location).
2. Download CUDEM data for the bounding box in one operation, then extract per-location transect profiles from the cached dataset.
3. This is automatic — no separate "download bathymetry" button in the wizard. The download happens during apply, with a progress indicator (HTMX).
4. The `/setup/marine/bathymetry` endpoint changes from "download one profile for one location" to "download regional CUDEM data for all locations, extract profiles for each surf/fishing spot."
5. Re-download triggers automatically when locations are added or moved in the admin.

**Do:**
- Replace the OpenTopoData URL with the NCEI ArcGIS ImageServer identify endpoint.
- Parse the `value` field as the depth (float, meters, negative = water).
- Compute unified bounding box from all configured location coordinates + transect padding.
- Download CUDEM data for the bounding box (batch of point queries or, if the ImageServer supports it, an area export).
- Extract per-location transect profiles from the downloaded data.
- Make the download automatic during wizard apply / admin save — no manual trigger.
- Keep the existing fallback profiles for when the NCEI service is unavailable.
- Keep the existing adaptive refinement and anomaly smoothing logic.

**Accept:**
- `download_bathymetric_profile(lat=34.21, lon=-77.79, bearing=135, ...)` returns a real depth profile with physically reasonable values (negative near shore, increasingly negative offshore).
- The profile uses CUDEM 1/9 arc-second data (verify via `catalogItems` tile name prefix `ncei19`).
- Multiple locations in the same area share one CUDEM download, not N independent downloads.
- Bathymetry download is automatic at apply time — no manual wizard button.
- Fallback to regional profiles still works when the NCEI service is unavailable.

### T1.3 — Update PROVIDER-MANUAL §14.5, §14.7

- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do: Update §14.5 to document the real SRF wire format (zone-then-period structure, UGC delimiters, asterisk annotations, day-name period labels). Update §14.7 to document the NCEI ArcGIS ImageServer as the CUDEM access method (replacing the OpenTopoData reference). Update §14.1 spectral band count from 46 to "variable (typically 47–98 depending on station)".
- Accept: Manual matches the implemented code and the actual external API behavior.

### T1.4 — Populate Wrightsville Beach species list (E10)

- Owner: Coordinator (Opus) or `clearskies-api-dev`
- File: `/etc/weewx-clearskies/api.conf` on weewx (config change, not code)
- Do: The fishing spot is configured with an empty species list. The code has `fishing_species.SPECIES_BY_REGION` with `atlantic_se` + `saltwater_inshore` → Redfish, Speckled Trout, Flounder, Snook, Sheepshead, Cobia. Add these to the `[marine] [[locations]] [[[wrightsville_beach]]] [[[[fishing]]]]` section in api.conf. Verify via `GET /fishing/wrightsville_beach` that `speciesScores` is non-null.
- Accept: Fishing endpoint returns species-level scoring for the configured species.

### QC Gate 1
- SRF parser returns real data from live NWS products for ≥2 WFOs.
- Bathymetry provider returns real CUDEM depth profiles (not fallback).
- All test baselines hold.
- PROVIDER-MANUAL §14.5 and §14.7 match implemented code.

---

## Phase 2 — High-Priority Wizard UX Fixes (U1, U2, U4, U6)

These are operator-facing usability issues that make the wizard confusing or impossible to configure correctly.

### T2.1 — Add marine unit groups to wizard unit step (U1)

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/units.py`
- Reference: API-MANUAL §16 marine unit groups, existing `UNIT_OPTIONS` pattern

**Do:** Add 5 marine unit groups to the wizard's unit customization step:
- `group_wave_height`: foot (US default), meter
- `group_wave_period`: second (single unit — display only, not selectable)
- `group_water_level`: foot (US default), meter
- `group_ocean_speed`: knot (ALL presets default), meter_per_second, mile_per_hour, km_per_hour
- `group_visibility`: nautical_mile (ALL presets default), statute_mile, kilometer

Add entries to `UNIT_OPTIONS`, `UNIT_GROUP_LABELS`, and all 3 presets in `UNIT_PRESETS`. The template is data-driven — no template changes needed. Update the JavaScript `PRESETS` object if it's hardcoded in the template.

Add i18n keys for the group labels (e.g., `wizard.units.group_wave_height`, `wizard.units.group_ocean_speed`) across all 13 locale files.

- Accept: Wizard unit step shows marine unit groups with correct preset defaults. Changing a marine unit group persists through apply and shows the correct unit in API responses.

### T2.2 — Interactive map for location selection (UX improvement)

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/static/` (Leaflet JS/CSS if self-hosted)
  - Translation files (13 locales)

**Problem:** Adding a marine location currently requires the operator to manually enter lat/lon coordinates, which means going back and forth to an external map service to find the right values. This is error-prone and unfriendly.

**Do:** When the operator clicks "Add Location," show an interactive Leaflet map (the dashboard already uses Leaflet, so the pattern is established). The operator clicks on the map to place a pin at the desired location. The pin's coordinates auto-fill the lat/lon fields. The operator can drag the pin to adjust. A search box (geocoding) above the map lets them type a place name to center the map.

Implementation:
- Embed Leaflet (JS + CSS) in the marine wizard step only — lightweight, no build step needed. Either inline from a CDN-free self-hosted copy in `/static/`, or bundle the ~40KB Leaflet files directly.
- Use OpenStreetMap tiles (free, no API key) for the base map. The dashboard already uses this tile source.
- On pin placement: populate hidden `lat` and `lon` inputs via JS. Reverse geocode (Nominatim, free) to auto-suggest a location name.
- When editing an existing location, center the map on the stored coordinates with the pin pre-placed.
- The map also helps the operator visualize where their locations are relative to each other — useful context for the unified bathymetry bounding box (T1.2).

- Accept: Operator can add a marine location by clicking on a map. Lat/lon fields auto-fill. Pin is draggable. Editing an existing location shows the pin at the stored position.

### T2.3 — Move marine alert radius to alerts sub-section (U2)

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_providers.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` (if the field handling needs to move between step handlers)
- Do: The `marine_alert_radius_miles` input is currently a standalone field in the provider step, not associated with any provider. Move it into the alerts provider sub-section so it appears as a conditional field when the alerts provider is selected — alongside the NWS contact email. Add help text explaining what it does ("Discovers nearby NWS marine zones for coastal weather alerts like Small Craft Advisories. Set to 0 to disable.").
- Accept: Marine alert radius appears inside the alerts provider configuration, not as a top-level field. Help text is present. Apply still works correctly.

### T2.4 — Add help text for directional exposure (U4)

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - Translation files (13 locales)
- Do: Add help text for the directional exposure input explaining: "Select which compass directions have open ocean exposure at this spot. A south-facing beach with headlands to the east and west would have S, SE, SW exposed and N, NE, NW, E, W blocked. Swells from blocked directions cannot reach this spot and are excluded from the surf forecast." Include a simple visual example if the HTMX pattern supports it.
- Accept: Operator can understand what directional exposure means without external documentation.

### T2.5 — Replace species free-text with checkbox selectors (U6)

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
  - Translation files (13 locales)
- Reference: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/fishing_species.py` — `SPECIES_BY_REGION`, `classify_region()`

**Do:** Replace the species free-text textarea with checkboxes. When the operator enters coordinates and selects `fishing` as an activity:
1. Use the API's `classify_region(lat, lon)` → biogeographic region.
2. Look up `SPECIES_BY_REGION[region][target_category]` for the selected target category.
3. Present the species list as checkboxes, all pre-checked by default.
4. Operator can uncheck species they don't target.

This requires either: (a) an HTMX endpoint on the API that returns the species list for a region+category, or (b) embedding the species data in the wizard (duplicating). Option (a) is cleaner — add a `GET /setup/marine/species?lat={}&lon={}&category={}` endpoint.

- Accept: Operator sees checkboxes with recognizable species names. Default is all species for the region checked. Unchecking a species excludes it from scoring.

### T2.6 — Add help text for remaining marine wizard inputs (U5)

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `step_marine.html`, translation files
- Do: Add help text for: beach facing bearing ("Compass direction the beach faces toward the ocean, in degrees. A beach facing south = 180°."), bottom type ("Seabed composition at the surf break. Affects wave breaking behavior."), topographic feature ("Coastal landform shape. Point breaks focus wave energy; bays shelter it."), structure config fields.
- Accept: Every marine wizard input has help text visible to the operator.

### QC Gate 2
- Wizard unit step shows all 5 marine unit groups.
- Alert radius is inside the alerts sub-section.
- Directional exposure has clear help text.
- Species selection uses checkboxes from the region's species list.
- All help text is present in English and placeholder-present in other 12 locales.

---

## Phase 3 — Medium-Priority API + Dashboard Fixes

### T3.1 — Add `units` block to surf/fishing/beach-safety list endpoints (E1)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/surf.py`, `endpoints/fishing.py`, `endpoints/beach_safety.py`
- Do: Add `"units": _units_block()` to the return dict in each list handler, matching the pattern used by `endpoints/marine.py` and `endpoints/tides.py`.
- Accept: `GET /surf`, `GET /fishing`, `GET /beach-safety` all include `units` in the response envelope.

### T3.2 — Fix SpectralWaveComponent height conversion (E2)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `endpoints/marine.py`
- Do: In `_convert_observation()`, after converting top-level fields, iterate over `observation.spectralComponents` (if present) and convert each component's `height` from base unit (meters) to the operator's `group_wave_height` display unit.
- Accept: `GET /marine/wrightsville_beach` returns spectral heights in feet when US preset is active.

### T3.3 — Fix beach-safety waterTemp unit (E3)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `endpoints/beach_safety.py`
- Do: The classification logic correctly converts to °F internally. The response should return `water_temp_c` (base unit Celsius), not `water_temp_f`. Keep the °F conversion internal for safety threshold classification.
- Accept: METRIC operators see Celsius waterTemp; US operators see the same base-unit value (Celsius) — consistent with the marine endpoint's convention.

### T3.4 — Change marine page icon to Waves (U3)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/src/routes/marine.tsx`, nav configuration
- Do: Import `Waves` from `@phosphor-icons/react` (confirmed available in package). Replace `Compass` with `Waves` in the PageLayout title icon and the nav rail entry.
- Accept: Marine nav item and page header show the Waves icon.

### T3.5 — Add per-activity alert filtering to tabs (D1)

- Owner: `clearskies-api-dev` (API) + `clearskies-dashboard-dev` (dashboard)
- Files: API `endpoints/marine.py` (summary), dashboard `routes/marine.tsx` + `AlertsPanel.tsx`
- Do: The API's `MarineLocationSummary.activeAlerts` currently returns flat headline strings. Add an `alertType` field to each alert (e.g., `"marineZone"`, `"coastalFlood"`, `"beachHazard"`, `"surfAdvisory"`). Dashboard filters alerts per tab per DASHBOARD-MANUAL §12 matrix: Boating gets marineZone + coastalFlood; Surfing gets marineZone + beachHazard + surfAdvisory; Fishing gets marineZone only; Beach Safety gets beachHazard + coastalFlood + surfAdvisory.
- Accept: Different tabs show different subsets of active alerts based on their activity type.

### T3.6 — Add eccodes availability check to wizard (D6)

- Owner: `clearskies-docs-author` (stack) + `clearskies-api-dev` (API)
- Files: API `endpoints/setup.py` (new probe endpoint), stack `wizard/routes.py` + `step_marine.html`
- Do: Add `GET /setup/marine/eccodes-check` that returns `{"available": true/false, "install_instructions": "..."}`. Wizard marine step calls this on load. If unavailable, show a blocking banner with platform-specific install instructions instead of the marine enable toggle.
- Accept: Wizard blocks marine setup when eccodes is missing, with clear install instructions.

### T3.7 — Add species field to admin marine section (D7)

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`, `admin/routes.py`
- Do: Add species textarea (or checkboxes matching T2.4) to the admin marine edit form. Include species in `_validate_marine_location_form` and `_build_marine_apply_payload`.
- Accept: Operator can view and edit species in the admin section.

### T3.8 — Resolve NWS rate limiter sharing (P8)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `providers/marine/nws_marine.py`, `providers/marine/nws_srf.py`, `providers/_common/nws_zones.py`, PROVIDER-MANUAL
- Do: The codebase uses per-module rate limiters (intentional pattern per nws forecast provider precedent), but PROVIDER-MANUAL §14.4 says "shared 5 req/s." Either share a single rate limiter across all NWS API consumers, or update the manual to document the per-module approach with a note on combined rate. Decision: update the manual — the per-module pattern is established and coupling module quotas creates fragile cross-dependencies.
- Accept: PROVIDER-MANUAL accurately describes the rate limiting behavior.

### QC Gate 3
- All list endpoints include `units` block.
- Spectral heights convert correctly.
- Beach-safety waterTemp returns Celsius.
- Marine nav uses Waves icon.
- Alert filtering works per tab.
- eccodes check blocks when missing.
- Admin species field works.
- Test baselines hold.

---

## Phase 4 — Low-Priority Doc Sync + Polish

### T4.1 — Add i18n locale keys for marine enrichment (E4)

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/locales/*.json` (13 files)
- Do: Add keys for `surf.*` (quality labels, wind quality, swell classification, conditions templates), `fishing.*` (period labels, species status, habitat, conditions, solunar caveat), `beach_safety.*` (safety levels, comfort levels, rip current risk), `marine.*` (swell classification). English authoritative; placeholder English for other 12 locales.
- Accept: API responses show translated text instead of raw key paths.

### T4.2 — Update API-MANUAL with undocumented values/scores (E5–E8)

- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Do:
  - §16 SurfForecast.windQuality: add `"glassy"` (wind <5 mph).
  - §17 fishing time-of-day: change "Dawn/dusk = 100" to "Dawn = 100, Dusk = 90."
  - §17 fishing solunar: add "During major period (non-peak moon) = 80."
  - §17 fishing tide: add `"peak_flow"` (score 70, midpoint between tidal extremes).
- Accept: Manual matches code exactly for all scoring values.

### T4.3 — Update stale Bundle classes (E9)

- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`
- Do: Update `SurfBundle`, `FishingBundle`, `BeachSafetyBundle` to match the actual response shapes their endpoints return — or remove them if they're unused. API-MANUAL §16 documents this as a known cleanup.
- Accept: Bundle classes either match their endpoint responses or are removed.

### T4.4 — Dashboard polish (D2–D5, D3)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/marine/LocationCard.tsx`, `src/components/marine-summary-card.tsx`
- Do:
  - D3: Append `{units?.waveHeight ?? 'ft'}` after wave height value in LocationCard, matching the wind speed pattern.
  - D5: Render `surfRating` (stars) and `beachSafetyLevel` (badge) in the Now-page marine summary card when non-null.
  - D2, D4: Defer — require API changes to provide hero weather icon and boating/fishing qualitative scores in MarineLocationSummary. Document as future enhancement.
- Accept: Wave height shows unit label. Summary card shows surf rating and safety level.

### T4.5 — Fix nwps_cg_grid handling (D8)

- Owner: Coordinator (Opus)
- Do: Determine if `nwps_cg_grid` is resolved at runtime from coordinates (no config storage needed) or must be stored. If runtime, document in OPERATIONS-MANUAL. If stored, add to wizard/admin.
- Accept: Behavior documented or implemented.

### T4.6 — Fix doc comments (P9, P10)

- Owner: Coordinator (Opus)
- Files: PROVIDER-MANUAL §14.1 (spectral band count), `providers/_common/nws_zones.py` (zone count comment)
- Do: Update band count "46" → "variable (47–98 depending on station)". Update zone count "101" → "~570".
- Accept: Comments match reality.

### QC Gate 4
- All locale keys produce translated text in English.
- API-MANUAL scoring values match code.
- Bundle classes cleaned up.
- Dashboard polish items complete.
- All doc comments accurate.
- Full test baselines hold.

---

## Verification

After all phases complete:
- All marine endpoints return real data for configured Wrightsville Beach location
- SRF parser extracts rip current risk, surf height, UV index from live NWS products
- Bathymetry provider returns real CUDEM 1/9 arc-second depth profiles (not fallback)
- Wizard marine step has complete help text, species checkboxes, eccodes check
- Marine unit groups customizable in wizard
- Alert filtering differs per activity tab
- All governing documents match implemented code
- Test baselines hold
