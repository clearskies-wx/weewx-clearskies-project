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

## Phase 5 — Coastal Structure Configuration UI

The API has full support for coastal structures (jetties, piers, breakwaters, seawalls, groins) — config model (`StructureConfig`), apply endpoint (`MarineStructureApplyConfig`), and physics engine (`wave_transform.apply_structure_effects` with per-structure distance-attenuated Kt, linear superposition for multiple structures). But the wizard has no UI for configuring them. Without this, structure effects are never applied — operators cannot configure the inputs the physics code needs.

**Primary workflow: auto-discovery via OpenStreetMap.** The Overpass API provides a free, queryable database of coastal structures worldwide with geometry and material tags. Tested against Newport Beach (breakwaters with `material=rock`), Huntington Beach (pier with 35-node outline), and Lorain OH (99 structures including breakwaters, groins, and named piers on the Great Lakes). The wizard queries Overpass when the operator saves a surf spot, displays discovered structures on the satellite map, and the operator confirms which ones affect their break. Manual drawing via Leaflet.draw is the fallback for structures not in OSM.

**OSM tag → our structure type mapping:**

| OSM tag | Our `type` | Notes |
|---------|-----------|-------|
| `man_made=breakwater` | `breakwater` | Direct match. May also represent jetties — operator confirms type. |
| `man_made=groyne` | `groin` | Spelling difference only (British vs. American). |
| `man_made=pier` | `pier` | Filter out `floating=yes` (marina dock fingers don't affect waves). |
| `barrier=*` + `wall=seawall` | `seawall` | Confirmed working (Galveston Seawall returned with 77 nodes). |
| `man_made=dyke` | `seawall` | Functionally equivalent for wave transmission effects. |

**OSM `material` tag → our `material` mapping:**

| OSM `material` | Our `material` | Rationale |
|----------------|---------------|-----------|
| `concrete` | `impermeable` | Solid pour, minimal wave transmission. |
| `rock`, `stone` | `semi_permeable` | Rubble mounds have interstitial gaps. |
| `wood` | `permeable` | Timber pilings, open structure. |
| `metal` | `semi_permeable` | Sheet pile or steel pilings. |
| _(not tagged)_ | **Needs operator input** | Common for piers. Wizard prompts. |

**What still requires operator input:**
1. **Material** when OSM doesn't tag it (most piers, some breakwaters).
2. **Confirming relevance** — not all nearby structures affect a given surf spot. A harbor full of dock fingers is irrelevant; the main jetty is critical.
3. **Structure type correction** — OSM has no `man_made=jetty` tag; jetties are tagged as `breakwater` or `pier`. The operator corrects the type via dropdown.
4. **Seawall length/bearing** — `wall=seawall` features along the Galveston model use `barrier=retaining_wall` and may not provide clean length/bearing from geometry alone.

**Overpass API operational constraints:**
- Free, no API key, AGPL v3 license.
- Fair use: <10,000 queries/day, <1 GB/day. Our usage: one query per surf spot save — trivial.
- Must send `User-Agent` header identifying the application.
- Main endpoint: `https://overpass-api.de/api/interpreter`
- Query timeout default 3 min; our queries return in <1 second.
- Mirrors available: `https://maps.mail.ru/osm/tools/overpass/api/interpreter`, `https://overpass.private.coffee/api/interpreter`.

**Overpass query template:**
```
[out:json][timeout:10];
(
  way["man_made"~"breakwater|groyne|pier"](around:{radius},{lat},{lon});
  way["wall"="seawall"](around:{radius},{lat},{lon});
  way["man_made"="dyke"](around:{radius},{lat},{lon});
);
out body geom;
```

### T5.1 — Add satellite imagery toggle to marine location maps

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`

**Do:** Add a Leaflet layer control to the existing location maps that lets the operator toggle between OpenStreetMap (street) and Esri World Imagery (satellite/aerial). Esri World Imagery is free, no API key, tile URL: `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}`. Default to street view; satellite is opt-in. The toggle is the standard Leaflet `L.control.layers` radio — no custom UI needed.

**Why:** Operators need to see actual coastal structures in aerial photography to confirm discovered structures and draw any the auto-discovery missed.

**Accept:** Layer control appears on the map. Toggling to satellite shows aerial imagery with structures visible. Toggling back to street restores OSM tiles. Both layers zoom and pan correctly. Pico CSS does not interfere with the layer control styling (add scoped CSS overrides following the zoom-button pattern already in step_marine.html).

### T5.2 — OSM structure auto-discovery via Overpass API

- Owner: `clearskies-docs-author` (Sonnet) + `clearskies-api-dev` (Sonnet)
- Files:
  - Stack: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` (HTMX endpoint)
  - Stack: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - API: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (new endpoint)

**Do:** Add a `GET /setup/marine/discover-structures?lat={}&lon={}&radius_m={}` endpoint to the API that queries the Overpass API and returns discovered structures mapped to our schema. The wizard calls this endpoint via HTMX when the operator clicks "Discover Nearby Structures" (or automatically when a surf spot pin is placed/moved and surf activity is checked).

**API endpoint behavior:**
1. Query Overpass with the template above (default radius 2000m).
2. For each returned OSM way, compute from its geometry:
   - `length_m` — geodesic length of the way (Haversine sum of segments).
   - `bearing_degrees` — bearing from the first node to the last node.
   - `distance_m` — geodesic distance from the query point (lat/lon) to the nearest node on the way.
3. Map `man_made` tag → our `type` (breakwater→breakwater, groyne→groin, pier→pier) and `wall=seawall`/`man_made=dyke` → seawall.
4. Map OSM `material` tag → our `material` using the table above. Set `null` when no material tag exists.
5. Filter out `floating=yes` piers (dock fingers — irrelevant to wave physics).
6. Filter out structures shorter than 5m (noise — tiny mapped features).
7. Return sorted by distance from the spot (nearest first).
8. Include OSM metadata: `osm_id`, `name` (if tagged), `osm_type` (the raw `man_made`/`wall` value for operator reference).
9. Send `User-Agent: ClearSkies-WeatherStation/1.0 (structure-discovery)` header per Overpass API policy.
10. Cache results in Redis for 24 hours keyed by `(lat_rounded, lon_rounded, radius)` — structures don't move.

**Response shape:**
```json
{
  "structures": [
    {
      "osm_id": 368975798,
      "osm_type": "breakwater",
      "name": null,
      "type": "breakwater",
      "material": "semi_permeable",
      "material_source": "osm",
      "length_m": 623.4,
      "bearing_degrees": 195.2,
      "distance_m": 147.8,
      "geometry": [[33.5935, -117.8812], [33.5882, -117.8795]]
    }
  ],
  "query_radius_m": 2000,
  "source": "openstreetmap_overpass"
}
```

**Wizard integration:**
- When structures are returned, display them on the map as colored polylines (blue for breakwater, green for pier, orange for groin, red for seawall).
- Below the map, show a checklist of discovered structures with name (if tagged), type, material, distance. Each has a checkbox (default unchecked — operator must consciously select the ones that affect their spot).
- Checking a structure adds its config card (T5.3) pre-filled with the auto-computed values. Material shows "Auto-detected: semi-permeable (rock)" or "Not tagged — please select" if OSM had no material.
- Type dropdown is pre-filled but editable (operator can change breakwater→jetty if that's more accurate).

**Accept:**
- API endpoint returns structures with correct type/material mapping for Newport Beach, Huntington Beach, and Lorain OH test cases.
- Discovered structures appear as polylines on the wizard map.
- Operator can check/uncheck individual structures.
- Checked structures populate config cards with correct pre-filled values.
- Structures with no OSM material tag prompt the operator to select material.
- `floating=yes` piers are excluded from results.
- Redis caching prevents redundant Overpass queries.

### T5.3 — Manual structure drawing (fallback) + configuration cards

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/static/lib/leaflet-draw/` (self-hosted plugin ~30KB)
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
  - Translation files (13 locales)

**Do:** Self-host Leaflet.draw 1.0.4 (JS + CSS) under `/static/lib/leaflet-draw/`. Add an "Add Structure Manually" button below the auto-discovered structures list (appears inside the surf activity section). This is the fallback for structures not in OpenStreetMap — seawalls, private jetties, recently constructed features, etc.

**Manual workflow (per structure):**
1. Operator clicks "Add Structure Manually."
2. A polyline draw tool activates. Operator switches to satellite view if not already (T5.1).
3. Operator draws a line along the structure's centerline on the map.
4. On draw complete, JavaScript auto-computes from the polyline + surf spot pin:
   - `length_m` — geodesic length (Haversine between vertices, summed).
   - `bearing_degrees` — bearing from first vertex to last vertex.
   - `distance_m` — geodesic distance from surf spot pin to nearest point on the polyline.
5. A structure config card appears (same format as auto-discovered cards) with:
   - **Type** — dropdown: Jetty, Pier, Breakwater, Seawall, Groin.
   - **Material** — dropdown: Impermeable, Semi-permeable, Permeable.
   - **Length, Bearing, Distance** — pre-filled from polyline, editable.
   - **Remove** button — deletes the structure and its polyline from the map.
6. The drawn polyline stays on the map as a colored line, labeled with the structure type.
7. Multiple manual structures supported alongside auto-discovered ones.

**Structure config cards (shared by auto-discovery and manual drawing):**
Both workflows produce the same card format. Each card shows type dropdown, material dropdown, length/bearing/distance fields (editable), and a remove button. Auto-discovered cards note "Source: OpenStreetMap" and manual cards note "Source: Manually drawn."

**Form serialization:** Each structure (auto-discovered or manual) becomes hidden inputs:
- `loc_{idx}_structure_{n}_type`
- `loc_{idx}_structure_{n}_material`
- `loc_{idx}_structure_{n}_length_m`
- `loc_{idx}_structure_{n}_bearing_degrees`
- `loc_{idx}_structure_{n}_distance_m`

The POST handler in `routes.py` collects these by scanning for `loc_{idx}_structure_` prefixed fields, groups by structure index, validates, and includes them in the apply payload under `surf.structures`.

**Accept:**
- Leaflet.draw loads without errors. Polyline tool activates on "Add Structure Manually."
- Drawn polylines compute length, bearing, distance correctly.
- Manual and auto-discovered structures coexist on the same map.
- All structure cards serialize correctly to the apply payload.
- Removing a structure removes both the card and the map feature.
- Editing an existing location with saved structures shows the structure cards pre-filled.
- Apply sends structures to the API and they persist in api.conf.

### T5.4 — Structure help content

- Owner: `clearskies-docs-author` (Sonnet)
- Files: Translation files (13 locales)

**Do:** Add comprehensive help content for the structure configuration section, keyed under `help.wizard.step_marine.structures.*`. Content must cover:

**Auto-discovery explanation:**
- "When you check the Surf activity and place a pin, the wizard searches OpenStreetMap for nearby coastal structures (breakwaters, jetties, piers, groins, seawalls). These appear as colored lines on your map. Check the ones that affect waves at your surf spot — not every nearby structure matters. If a structure is missing from the auto-discovery results, use 'Add Structure Manually' to draw it on the satellite view."

**Structure types** (with plain-language descriptions):
- **Jetty** — A narrow structure extending from shore into the water, typically made of rock or concrete. Commonly found at harbor/inlet entrances to keep sand from blocking the channel. Example: the rock jetties flanking an inlet. Note: OpenStreetMap often tags jetties as "breakwater" — change the type dropdown if the auto-detected type is wrong.
- **Pier** — An elevated platform extending over the water, supported by pilings. Waves pass partially underneath. Example: fishing piers, municipal piers like Huntington Beach Pier.
- **Breakwater** — A structure built offshore or at an angle to the shore to protect a harbor or beach from wave action. Can be detached (an island) or attached to shore. Example: harbor entrance breakwaters.
- **Seawall** — A vertical or near-vertical wall built along the shoreline. Reflects wave energy rather than absorbing it. Example: the Galveston Seawall, concrete seawalls protecting oceanfront property.
- **Groin** — A short structure extending perpendicular from the shore, designed to trap sand and prevent beach erosion. Usually shorter than jetties. Example: the regularly-spaced rock groins along a beach.

**Material types** (with examples and wave effect):
- **Impermeable** — Solid construction that blocks nearly all wave energy. Examples: poured concrete walls, sheet pile, solid stone masonry. Blocks ~90% of wave energy.
- **Semi-permeable** — Rubble or armored construction with gaps that allow some wave energy through. Examples: rock rubble mounds (riprap), dolosse or tetrapod armor units, spaced concrete blocks. Blocks ~65% of wave energy. This is the most common material for breakwaters and jetties.
- **Permeable** — Open construction that allows significant wave energy through. Examples: timber piling piers, open steel pipe pilings, widely-spaced concrete columns. Blocks ~25% of wave energy.

**Measurement guidance:**
- "Switch to satellite view to see structures clearly. For precise measurements, use Google Earth (free) to measure structure length and verify distances."
- "Length is measured along the structure's centerline from end to end."
- "Distance is measured from your surf spot pin to the nearest point of the structure."
- "Bearing is the compass direction the structure points, measured from its shore end to its water end. 0° = North, 90° = East, 180° = South, 270° = West."
- "All values are auto-computed from the structure geometry. You can edit any value if you have more accurate measurements."

**Multiple structures note:**
- "A surf spot can be affected by multiple structures. For example, The Wedge in Newport Beach is shaped by the Newport Harbor jetty to the west and the offshore breakwater to the north. Add each structure separately — the system combines their wave-blocking effects automatically."

**Accept:** Help panel for step 13 includes the structures section. All 5 types and 3 materials have plain-language descriptions with real-world examples. Auto-discovery workflow is explained. Measurement guidance references Google Earth. Multiple-structure use case is explained.

### T5.5 — Structure configuration in admin marine section

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py`

**Do:** Add structure editing to the admin marine location edit form. The admin provides:
1. **Re-run discovery** button that calls `GET /setup/marine/discover-structures` for the current location and shows new/changed structures.
2. **Table/card view** of existing structures with type/material dropdowns and length/bearing/distance fields — add, edit, delete.
3. No map-based drawing in the admin — operators who want the map experience re-run the wizard. The admin is for direct value editing.

When editing an existing location, pre-fill structure cards from the stored `api.conf` values. Include the same type/material dropdowns with the same validation.

**Accept:** Admin marine section shows existing structures for each surf spot. Operator can add, edit, remove structures, and re-run discovery. Changes persist through apply. Validation matches T5.3 (same 5 types, 3 materials, bearing 0–360, positive length/distance).

### T5.6 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- OPERATIONS-MANUAL: Document the structure configuration UI in the wizard marine step and admin marine section. Include auto-discovery workflow, manual drawing fallback, multi-structure support, and the Overpass API dependency (free, no key, fair-use limits).
- API-MANUAL: Verify §16 documents `StructureConfig` fields and the multi-structure Kt multiplication behavior.
- PROVIDER-MANUAL: Document the Overpass API integration as a setup-time data source (not a runtime provider — queried once during configuration, results stored in api.conf). Include the OSM tag mapping table, the query template, caching strategy, and `User-Agent` requirement.

**Accept:** Manuals match the implemented UI and physics behavior. Overpass API dependency is documented.

### QC Gate 5
- Satellite imagery toggle works on all marine location maps.
- Auto-discovery returns correct structures for Newport Beach, Huntington Beach, and Lorain OH test coordinates.
- Discovered structures appear as colored polylines on the map with correct type coloring.
- Operator can check/uncheck discovered structures; checked ones populate config cards.
- OSM material tag maps correctly; missing material prompts operator input.
- `floating=yes` piers are excluded from discovery results.
- Manual drawing fallback produces correct length/bearing/distance from polyline geometry.
- Multiple structures (auto-discovered + manual) coexist per surf spot.
- Type dropdown allows operator to correct auto-detected type (e.g., breakwater→jetty).
- Structures persist through apply and appear in api.conf.
- Admin section shows, edits, and re-discovers structures.
- Help content covers auto-discovery, all 5 types, 3 materials, measurement guidance, and multi-structure use case.
- Existing test baselines hold.
- Redis cache prevents redundant Overpass queries (24h TTL).

---

## Phase 6 — Per-Species Fishing Forecast Scoring

**Origin:** Wizard troubleshooting surfaced two issues: (1) species endpoint was broken (wrong `classify_region` import — fixed in `b64d32e`), and (2) the target category selector is a single dropdown, but fishing categories are not mutually exclusive. An angler at Huntington Beach targeting halibut (saltwater_inshore) and rockfish (bottom_fish) cannot express that with the current UI.

**Industry practice (researched):** Fishbrain, the leading fishing forecast app, shows **per-species** bite scores independently — one score per species, each with its own conditions assessment. Anglers don't think in categories; they think "is it a halibut day or a rockfish day?" The category is a config-time convenience for filtering which species checkboxes appear, not a runtime scoring input.

**Current architecture problem:** The scorer has two temperature scoring layers that overlap:
1. **Category-level** `_score_water_temp(water_temp_f, target_category)` → produces `waterTempScore` (line 660) → baked into `weighted_base` (line 666-673).
2. **Species-level** `_species_temp_multiplier(profile, water_temp_f)` → multiplied into each species' individual score (line 453).

The `weighted_base` already includes the category temp score, then each species multiplies its own temp adjustment on top. This double-counts temperature. And the category temp ranges (`_CATEGORY_TEMP_RANGES_F`) are just rough averages of the species in that category — the per-species profiles (`SPECIES_PROFILES`) have more precise ranges for each species.

**Fix:** Remove the category-level temp score from the base calculation. Temperature becomes purely per-species — each species' score uses its own `temp_optimal`/`temp_good`/`temp_marginal` from `SPECIES_PROFILES`. The `overallScore` in the response represents general conditions (pressure, tide, solunar, time of day) without a temperature component — temperature is species-specific and only appears in the per-species scores. The `waterTempScore` response field either becomes the neutral score (50) or is removed.

### T6.1 — Multi-category species selection in wizard

- Owner: Coordinator (Opus) or stack dev
- Files:
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
  - `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
  - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (species endpoint)

**Do:** Change the target category from a single `<select>` dropdown to checkboxes (multi-select). When multiple categories are checked, the species endpoint returns the **union** of all selected categories' species lists (deduplicated). The wizard's HTMX species loader sends all checked category values.

**Config model change:** `FishingSpotConfig.target_category` (currently `str`) becomes `target_categories: list[str]`. The apply Pydantic model, config writer, config loader, and admin form all need to accept a list. Backward compat: if a single string is found in `api.conf` (existing installs), the loader wraps it in a list.

**Species endpoint change:** `GET /setup/marine/species` accepts `category` as a comma-separated list (e.g., `category=saltwater_inshore,bottom_fish`). Returns the union of species across all specified categories for the detected region.

**Accept:**
- Operator can check multiple category checkboxes.
- Species list shows the union of all checked categories' species (no duplicates).
- Checking/unchecking a category dynamically updates the species list via HTMX.
- Config stores `target_categories` as a list.
- Existing single-category configs load without error.

### T6.2 — Remove category-level temp scoring from the scorer

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/fishing_scorer.py`
  - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/fishing.py`

**Problem:** `weighted_base` includes `water_temp_score * _WEIGHT_WATER_TEMP` from the category-level temp ranges, then each species' score multiplies its own `_species_temp_multiplier` on top. Temperature is double-counted, and the category-level ranges are less accurate than the per-species profiles.

**Do:**
1. Remove `water_temp_score` from the `weighted_base` calculation. The base becomes: `pressure * W_p + tide * W_t + solunar * W_s + time * W_tod` (4 components, not 5).
2. Redistribute the `_WEIGHT_WATER_TEMP` weight across the remaining 4 components proportionally so they still sum to 1.0 (or whatever the current total is).
3. Temperature scoring moves entirely to `_score_one_species` — each species already applies `_species_temp_multiplier(profile, water_temp_f)` which uses the species' own temp ranges. This becomes the sole temperature input to each species' score.
4. The `waterTempScore` field in the `FishingForecast` response: set to `None` (it no longer has a single meaningful value — temp is per-species). Update the response model to make it `Optional[int]`.
5. Remove `_score_water_temp()` and `_CATEGORY_TEMP_RANGES_F` — dead code after this change.
6. The `target_category` / `target_categories` parameter to `score_fishing()`: no longer used by the scorer. Keep it in the signature for now (the endpoint passes it), but it's not read. Document this in the docstring.

**Species without profiles:** Species not in `SPECIES_PROFILES` get `_get_profile()`'s default neutral profile. Verify the default profile has reasonable temp ranges (not all zeros). If missing, add fallback ranges.

**Accept:**
- `overallScore` reflects pressure + tide + solunar + time of day (no temperature).
- Each species in `speciesScores` reflects its own temperature preference.
- A 72°F water temp scores high for redfish (optimal 68-80) but low for striped bass (optimal 55-68) — in the same forecast period.
- `waterTempScore` is null in the response.
- No scoring regression for species that have profiles.
- Species without profiles get a neutral (non-penalizing) temperature score.

### T6.3 — Update FishingSpotConfig and apply models

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`
  - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (apply models)

**Do:**
1. `FishingSpotConfig.target_category` → `target_categories: list[str]`. The `__init__` loader reads from `api.conf`; if it finds a bare string, wrap in `[string]`. If it finds a list (configobj returns lists for multi-value keys), use directly.
2. `MarineFishingSpotApplyConfig.target_category` → `target_categories: list[str] | str`. Add a validator that normalizes a bare string to `[string]`.
3. Config writer in both wizard (`config_writer.py`) and admin (`admin/routes.py`) sends `target_categories` as a list.
4. `_write_api_conf()` in setup.py writes `target_categories` as a comma-separated value or configobj list.

**Accept:**
- New configs write `target_categories = saltwater_inshore, bottom_fish`.
- Old configs with `target_category = saltwater_inshore` load without error (normalized to `["saltwater_inshore"]`).
- Round-trip: wizard save → api.conf → API reload → admin load → admin save → api.conf stays consistent.

### T6.4 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
- API-MANUAL §17: Update scoring description — temperature is per-species only, `overallScore` excludes temperature, `waterTempScore` is null. Document that `target_categories` is a list. Update the FishingForecast response shape.
- OPERATIONS-MANUAL: Update fishing config docs — `target_categories` is multi-select, species list is the union.

**Accept:** Manuals match the implemented scoring and config behavior.

### QC Gate 6
- Multiple categories can be selected in wizard and admin.
- Species list is the union of selected categories (no duplicates).
- `overallScore` does not include a temperature component.
- Per-species scores reflect each species' own temperature preference.
- Same water temp produces different species scores (e.g., redfish vs striped bass).
- `waterTempScore` is null in the API response.
- Old single-category configs load without error.
- API-MANUAL and OPERATIONS-MANUAL match implementation.
- Existing test baselines hold.

---

## Phase 7 — Directional Structure Wave Physics

**Origin:** Wizard troubleshooting (2026-07-12) revealed two problems: (1) the Huntington Beach Pier returned a bearing of 0.0° because OSM maps it as a closed area polygon, not a line — the first-to-last node calculation returned undefined (fixed in `182046d`); (2) investigating why bearing matters exposed that the wave physics engine (`wave_transform.py`) is entirely direction-agnostic. It treats every structure as an omnidirectional wave attenuator regardless of the structure's orientation relative to the incoming swell. A 600m breakwater running parallel to the coast gets the same Kt attenuation as one running perpendicular — physically wrong.

**Current state:** `apply_structure_effects()` uses only `material` (Kt lookup), `type` (influence zone multiplier), `length_m`, and `distance_m`. The `bearing_degrees` field is collected from operators, computed from OSM geometry, stored in `api.conf`, but never read by the physics code. The incoming `wave_direction` from NWPS data flows through `apply_supplements()` untouched and is never passed to the structure function.

**What the research brief covers (§11.5):** Kt coefficients by material, influence zone multipliers by structure type, shadow zone extents, multi-structure superposition. All treat structures as omnidirectional — no angular dependence.

**What the research brief does NOT cover:** How Kt varies with the angle between incoming wave direction and structure orientation. How to determine whether a surf spot falls within a structure's shadow zone for a given wave direction. Diffraction of wave energy around structure endpoints.

**Literature that covers it (already cited but not extracted):** Goda (2000) Ch 6 (diffraction diagrams, angular coefficients) and Ch 10 (transmission through/over structures at oblique incidence); d'Angremond, van der Meer & de Jong (1996) — Kt as a function of wave height, period, crest freeboard, AND angle of incidence; CERC/CEM Part II-7 "Transmission and Reflection." Penney & Price (1952) for semi-empirical diffraction.

### T7.1 — Research: Directional Kt dependence and shadow zone geometry

- Owner: Coordinator (Opus)
- Output: Amendment to research brief §11.5 with extracted formulas

**Research questions (each must produce a formula or lookup table, not prose):**

1. **Angular Kt modulation:** How does the transmission coefficient vary with the angle θ between incoming wave direction and structure normal? The structure bearing gives the structure's long axis; the normal is perpendicular to it. Waves approaching perpendicular to the structure face (θ = 0°) should see the full documented Kt. Waves approaching parallel (θ = 90°) should see Kt → 1.0 (no blocking). Extract the functional form from d'Angremond et al. (1996) and Goda (2000).

2. **Shadow zone geometry:** Given a structure's position, bearing, and length, and the incoming wave direction, is the surf spot in the structure's wave shadow? This is a geometric computation: the shadow zone extends behind the structure (opposite the wave approach direction) in a cone whose width depends on the structure length and distance. Extract the shadow zone angle and decay formulas from Goda (2000) Ch 6 and CERC (1984).

3. **Diffraction around structure ends:** Waves bend around the tips of structures. The diffraction coefficient Kd reduces wave height in the geometric shadow but also means the shadow is never total. Extract the simplified angular diffraction coefficient from Goda (2000) Ch 6 — the full Sommerfeld solution is overkill; the semi-empirical diagram approach is standard practice for engineering applications.

4. **Interaction with directional exposure:** The surf spot's `directional_exposure` (8 compass directions) already filters which swells can reach the spot. How should structure shadow zones interact with this? A structure blocking waves from a direction already marked as "blocked" in directional exposure is redundant. Define the precedence.

**Do:**
- Search the web for the specific formulas from the cited sources.
- Document each formula with: the equation, variable definitions, valid ranges, source citation, and a worked example using Huntington Beach Pier (bearing ~221°, length ~567m, distance ~150m from a surf spot to its south, incoming swell from SSW at 200°).
- Add the formulas to research brief §11.5 as a new sub-section "11.5.1 Directional dependence."

**Accept:**
- Each research question has a formula with source citation and worked example.
- The formulas are implementable — no ambiguous prose, no "it depends."
- The worked example produces physically reasonable results (pier parallel to swell → minimal blocking; pier perpendicular to swell → near-full Kt).

### T7.2 — Implement directional Kt in wave_transform.py

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py`
- Depends on: T7.1 (research formulas)

**Do:**
1. Modify `_structure_kt_effective()` to accept `wave_direction` (degrees, 0=N, direction waves travel FROM) and `structure.bearing_degrees`.
2. Compute the angle between the wave approach direction and the structure normal.
3. Apply the angular Kt modulation formula from T7.1 — scale Kt from its full material value (waves perpendicular to structure) toward 1.0 (waves parallel to structure).
4. Add shadow zone geometry check: if the surf spot is not in the structure's shadow for this wave direction, the structure has no effect (Kt = 1.0) regardless of distance.
5. Modify `apply_structure_effects()` to accept `wave_direction` parameter.
6. Modify `apply_supplements()` to pass `wave_direction` (already available from `nwps_data`) to `apply_structure_effects()`.

**Accept:**
- Huntington Beach Pier (bearing 221°, semi-permeable) with swell from SSW (200°): swell is nearly parallel to pier → Kt approaches 1.0 (minimal blocking).
- Same pier with swell from WSW (250°): swell hits pier at ~30° off perpendicular → significant Kt reduction.
- Same pier with swell from NNE (20°): surf spot is not in the pier's shadow for this direction → Kt = 1.0.
- Existing tests continue to pass (structures with no wave_direction input degrade gracefully — use omnidirectional behavior as fallback).

### T7.3 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- API-MANUAL §17 Supplement 2: Update to document directional Kt behavior, the angular modulation formula, and shadow zone geometry. Document that `bearing_degrees` is now an active input to the physics (not just stored metadata).
- PROVIDER-MANUAL: Document that `bearing_degrees` from OSM auto-discovery computes the principal axis for closed polygons (area-mapped structures like piers).

**Accept:** Manuals match the implemented physics and the research brief formulas.

### T7.4 — Fix OSM closed-polygon bearing in discovery results display

- Owner: `clearskies-docs-author` (Sonnet)
- Files: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py`
- Status: **Partially complete** — API-side fix landed in `182046d` (principal axis computation for closed polygons). Wizard-side field source indicators landed in `a5384c8`. Remaining: remove the blanket ⚠ on bearing now that the API computes it correctly for both open ways and closed polygons. Instead, show ⚠ only on material when `material_source != "osm"`.

**Accept:** Bearing shows without a warning indicator for auto-discovered structures. Material still shows ⚠ when not tagged in OSM.

### QC Gate 7
- Research brief §11.5.1 contains directional Kt formula, shadow zone geometry, and diffraction coefficient with worked examples.
- Swell parallel to a structure produces Kt approaching 1.0 (minimal blocking).
- Swell perpendicular to a structure produces the full material Kt.
- Surf spot outside a structure's shadow zone for the current wave direction sees Kt = 1.0.
- Fallback: when wave_direction is unavailable, omnidirectional behavior is preserved (no regression).
- Closed-polygon OSM structures produce correct bearing via principal axis.
- Governing documents match implementation.
- Test baselines hold.

---

## Phase 8 — Species Data Externalization & Research

**Origin:** Wizard testing (2026-07-12) revealed the `pacific_sw` species list is missing obvious SoCal species (leopard shark, calico bass, mackerel, barracuda, white seabass, bonito, etc.). Investigation found the root cause is twofold: (1) species data is hardcoded in Python source (`fishing_species.py`) instead of an editable data file — a regression from the original `weewx-fish_and_surf_forecasts` extension which used operator-configurable YAML (`surf_fishing_fields.yaml`); (2) the species lists, temperature profiles, and seasonal behavior tables were agent-generated from LLM training data during Phase 4 T4.2, not sourced from fisheries research or the original project code. The plan said "seed 5–10 species per category per region as a starting default" and the agent did exactly that — but from general knowledge, not authoritative sources.

**What the original code had** (`weewx-fish_and_surf_forecasts`, `surf_fishing_fields.yaml`):
- 4 categories: freshwater_sport, saltwater_inshore, saltwater_offshore, bottom_fish
- 4 generic starter species per category (not regional)
- Species lists were YAML config — operators edited the file to add local species
- Scoring weights, pressure preferences, tide relevance per category — all YAML-configurable
- No per-species temperature profiles or seasonal behavior (those were added in Clear Skies)

**What Clear Skies did wrong:**
- Hardcoded everything in Python (`SPECIES_BY_REGION`, `SPECIES_PROFILES`, `SEASONAL_BEHAVIOR`)
- Expanded to 11 regions with 5–10 species each — but from LLM knowledge, not fisheries data
- Operators cannot add species without editing Python source code
- Never referenced the original project code despite the research brief citing it

### T8.1 — Research: Species data requirements and sources

- Owner: Coordinator (Opus)
- Output: Findings documented in this section (below) — no separate research brief

**What the scorer needs per species (from `SpeciesProfile` and `SeasonalEntry`):**

| Field | Source | Available from external API? |
|-------|--------|------------------------------|
| `pressure_sensitivity` (0.0–1.0) | Swim bladder size → barometric response. Fisheries biology concept. | No. Must be manually curated from species biology literature. |
| `temp_optimal` (min, max °F) | Peak feeding/activity temperature range | **Partially.** FishBase `stocks` table has `TempMin`/`TempMax` — but that's survival range, not optimal feeding. Optimal must be derived (narrower window within survival range). |
| `temp_good` (min, max °F) | Active but not peak — superset of optimal | No. Derived from optimal with margins (typically ±5–8°F). |
| `temp_marginal` (min, max °F) | Present but sluggish — superset of good | No. Derived from good with wider margins (typically ±5–10°F). Can use FishBase `TempMin`/`TempMax` as the outer bound. |
| `tide_preference` | incoming/outgoing/slack/any | No. Angler domain knowledge, not in any database. |
| `tide_multiplier` | How much tide phase matters for this species | No. Must be manually curated. |
| `time_preference` | dawn/dusk/night/any | **Partially.** FishBase `ecology` table has some diurnal/nocturnal flags, but not in our scoring format. |
| `time_multiplier` | How much time-of-day matters | No. Must be manually curated. |
| `seasonal_behavior` by month | Spawning runs, migrations, regulatory closures | **Partially.** FishBase `spawning` table has months. Regulatory closures are state-specific — CDFW, FWC, etc. |

**Conclusion: No single API provides what we need.** The scorer's data model is behavioral/angling-oriented (pressure sensitivity, tide preference, time preference, multipliers). Fisheries databases are taxonomic/ecological. The data must be curated into a static YAML file that ships with the product.

**Data sourcing strategy (internal research tooling, not shipped):**

1. **Species lists by region:** Bootstrap from FishBase parquet data (`stocks` table, species by FAO area → mapped to our biogeographic regions). Validate against state fish & wildlife agency species guides (CDFW for pacific_sw, FWC for atlantic_se/gulf, etc.). Cross-reference with NOAA MRIP catch data (top species caught by region). FishBase data is CC BY-NC 4.0 — compatible with our PolyForm Noncommercial license.

2. **Temperature ranges:** Start with FishBase `TempMin`/`TempMax` from `stocks` table as the marginal (survival) range. Derive optimal as the inner 40% of the survival range, good as the inner 70%. Validate against species-specific fisheries biology literature where available.

3. **Behavioral fields** (pressure sensitivity, tide/time preferences, multipliers): Manually curate from:
   - Fisheries biology textbooks and papers (swim bladder morphology → pressure sensitivity)
   - State fishing guides and regulations (seasonal closures, spawning runs)
   - Established angling knowledge bases (tide/time preferences are well-documented per species in fishing literature)

4. **Geographic organization:** Regions keyed by our current slugs (`pacific_sw`, `atlantic_se`, etc.). Each region maps to FAO fishing areas for future world expansion. Species appear in every region where they're commonly targeted by recreational anglers — a species can appear in multiple regions.

**Sources evaluated:**

| Source | What it provides | Access | License | Verdict |
|--------|-----------------|--------|---------|---------|
| **FishBase** (fishbase.org) | Species lists, temperature survival ranges, spawning months, ecology flags, FAO area distribution. 35,000+ species. | S3 parquet files (rfishbase v5). Old REST API is deprecated. | CC BY-NC 4.0 | **Use for bootstrap.** Temperature ranges and species-by-region lists. Internal tooling only — we ship the derived YAML, not a runtime dependency. |
| **NOAA MRIP** (fisheries.noaa.gov) | Recreational catch data by region/state — tells us what anglers actually catch. CSV downloads. | Query tool + CSV downloads. No structured API. Atlantic/Gulf coasts + Hawaii. California covered but limited. | Public domain (US govt) | **Use for validation.** Cross-check our species lists against actual catch data to ensure we include species anglers target, not just species that exist. |
| **State Fish & Wildlife** (CDFW, FWC, etc.) | Authoritative species guides, regulations, seasonal closures, size limits. | Web pages, PDFs. No API. Per-state, fragmented. | Public domain (state govt) | **Use for closures/regulations.** The only authoritative source for regulatory closures. Manual extraction per state. |
| **IGFA** (igfa.org) | Game fish records, species identification. World Records API at wrec-api.igfa.org. | API exists but documentation sparse. | Unknown — likely restrictive | **Skip.** Records data doesn't help with behavioral profiles. |
| **Fishbrain / FishAngler** | Crowd-sourced catch data, species by location. | Private companies, no data licensing. Scraping violates ToS. | Proprietary | **Skip.** Cannot use. |
| **FishWatch** (fishwatch.gov) | NOAA consumer seafood profiles. | API was at fishwatch.gov/api/species — **now 301 redirects to fisheries.noaa.gov. API appears deprecated.** | Was public domain | **Dead.** API no longer functional. |
| **iNaturalist** | Species observations by location. CC-licensed. | REST API available. | CC0 / CC BY-NC | **Optional validation.** Can confirm species presence in regions but no behavioral data. |

### T8.2 — Externalize species data to YAML

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/data/species.yaml`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/fishing_species.py`

**Do:**
1. Create `data/species.yaml` containing all four data tables currently hardcoded in `fishing_species.py`:
   - `regions` — biogeographic region bounding boxes (currently `BIOGEOGRAPHIC_REGIONS`) with FAO area mappings for future world expansion
   - `species_by_region` — species lists per region per category (currently `SPECIES_BY_REGION`)
   - `species_profiles` — per-species scoring profiles (currently `SPECIES_PROFILES`)
   - `seasonal_behavior` — spawning/migration/closure data (currently `SEASONAL_BEHAVIOR`)
2. YAML schema must be documented in the file header — field names, types, valid values, and an example entry for each section so operators can add their own species.
3. Modify `fishing_species.py` to load from the YAML file at startup. Keep `classify_region()` as Python code (it's logic, not data). The module's public API (`SPECIES_BY_REGION`, `SPECIES_PROFILES`, etc.) stays the same — no caller changes.
4. The YAML file path: default location is `data/species.yaml` relative to the package. Overridable via `api.conf` key `species_data_path` so operators can point to their own file without modifying the shipped default.
5. Add a `GET /setup/marine/species-database` endpoint that returns the loaded species data — the admin UI can display it for reference.

**Accept:**
- `fishing_species.py` contains no hardcoded species data — all loaded from YAML at startup.
- Editing the YAML file and restarting the API changes the species available in the wizard and scoring.
- Operators can override the default YAML path via `api.conf`.
- Existing tests pass without modification (the public API is unchanged).
- YAML schema is documented in the file header with examples.

### T8.3 — Populate species database from research

- Owner: Coordinator (Opus)
- Depends on: T8.2 (YAML structure exists to populate)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/data/species.yaml`

**Internal research process (not shipped — we ship only the resulting YAML):**
1. Run a one-time bootstrap script against FishBase parquet data (S3, free, no auth) to extract species-by-FAO-area and `TempMin`/`TempMax` for recreationally relevant species. Map FAO areas to our 11 US biogeographic regions.
2. Cross-reference against NOAA MRIP catch data to ensure the species list reflects what anglers actually target in each region, not just what exists there taxonomically.
3. Manually curate behavioral fields (pressure sensitivity, tide/time preferences, multipliers) from fisheries biology literature and established angling knowledge.
4. Extract regulatory closures from state fish & wildlife agencies (CDFW, FWC, TPWD, etc.).

**Species coverage targets:**
- 15–25 species per region across all applicable categories.
- `pacific_sw` must include at minimum: leopard shark, thresher shark, shovelnose guitarfish, calico/kelp bass, sand bass, white seabass, Pacific mackerel, Pacific bonito, California barracuda, California halibut, corbina, surfperch, opaleye, sheepshead, yellowtail, bat ray, white croaker, sculpin, lingcod, rockfish.
- Every species entry must have: all `SpeciesProfile` fields populated, source attribution comment, and seasonal behavior where applicable.
- Temperature ranges sourced from FishBase survival ranges, narrowed to optimal/good/marginal bands, validated against species-specific literature where available.

**Accept:**
- All 11 regions have 15–25 species with complete profiles.
- `pacific_sw` includes all species listed above.
- Temperature ranges are derived from FishBase data, not LLM general knowledge.
- Source attribution present for each species entry.
- Behavioral fields cite the source (fisheries biology literature reference or "angling domain knowledge" when no formal source exists).
- Wizard species checkboxes show the full regional list.

### T8.4 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
- API-MANUAL §17: Update to document that species data is loaded from `data/species.yaml`, not hardcoded. Document the YAML schema and the `species_data_path` override. Remove any reference to hardcoded species tables.
- OPERATIONS-MANUAL: Document how operators customize the species database — editing the YAML file, adding species, modifying temperature ranges, adding seasonal closures. Document the restart requirement after edits. Include a worked example of adding a new species.

**Accept:** Manuals match the implemented data loading and customization workflow.

### QC Gate 8
- No species data hardcoded in Python source — all loaded from YAML.
- YAML file has 15–25 species per region with complete profiles and source attribution.
- Editing the YAML and restarting the API changes wizard species checkboxes and scoring behavior.
- Operators can override the YAML path via `api.conf`.
- `pacific_sw` includes sharks, bass species, mackerel, barracuda, and other common SoCal targets.
- Species profiles (temperature ranges) derived from FishBase data; behavioral fields cited to source.
- Governing documents match implementation.
- Test baselines hold.

---

## Phase 9 — Logo TM Mark Update

**Origin:** Brand logo updated with TM (trademark) mark in Illustrator source files. The updated source SVGs are in `docs/design/`. All deployed logo variants across the dashboard, wizard, and public assets need to be regenerated from the updated source artwork.

**Updated source files (in `docs/design/`):**
- `clearskies logo blue.ai` / `.svg` — master brand logo, now includes TM mark (lines 25–28 of SVG)
- `clearskies logo POWERED blue.ai` / `.svg` — "POWERED" variant, **TM mark not yet added** — needs Illustrator update first

**Deployed logo files that need regeneration:**

| File | Used by | Color variant | Has TM? |
|------|---------|--------------|---------|
| `dashboard/public/clearskies-logo.svg` | `index.html` splash screen | Blue on transparent | No |
| `dashboard/src/assets/clearskies-powered-light.svg` | `footer.tsx` site footer | Light/white on transparent | No |
| `dashboard/src/assets/clearskies-powered-blue.svg` | Not currently imported (blue variant) | Blue on transparent | No |
| `stack/static/clearskies-logo-white.svg` | `wizard/layout.html` wizard nav bar | White on transparent | No |
| `dashboard/dist/clearskies-logo.svg` | Built output (overwritten by build) | Blue on transparent | No |

### T9.1 — Regenerate all deployed logo variants

- Owner: `clearskies-dashboard-dev` (Sonnet) + `clearskies-docs-author` (Sonnet)
- Note: Both source .ai/.svg files already updated by user with TM mark.

**Do:**
1. From the updated `clearskies logo blue.svg` source (with TM), generate:
   - `dashboard/public/clearskies-logo.svg` — blue variant, sized for splash screen
   - `stack/static/clearskies-logo-white.svg` — white variant (change fill from `#2568a3` to `#ffffff`), sized for wizard nav bar
2. From the updated `clearskies logo POWERED blue.svg` source (with TM), generate:
   - `dashboard/src/assets/clearskies-powered-blue.svg` — blue variant
   - `dashboard/src/assets/clearskies-powered-light.svg` — light variant (change fill to light color matching current footer rendering)
3. Verify each SVG renders correctly at its deployed size — the TM mark must be legible but not dominant.
4. Rebuild dashboard (`npm run build`) to regenerate `dist/clearskies-logo.svg`.

**Accept:**
- All 4 deployed SVGs contain the TM mark.
- TM mark is visible at each logo's rendered size (splash screen, footer, wizard nav).
- No visual regression — logos render correctly in light and dark mode.
- Dashboard build succeeds.

### T9.2 — Deploy and verify

- Owner: Coordinator (Opus)
- Do: Deploy dashboard and stack to weather-dev. Verify TM mark visible on:
  - Dashboard splash screen (page load)
  - Dashboard footer ("Powered by Clear Skies")
  - Wizard header nav bar
- Accept: TM mark visible in all three locations at both desktop and mobile viewport sizes.

### QC Gate 9
- All deployed logo SVGs contain TM mark.
- TM visible at splash screen, footer, and wizard nav bar sizes.
- Light and dark mode rendering correct.
- No broken images or missing logos.

---

## Verification

After all phases complete:
- All marine endpoints return real data for configured Wrightsville Beach location
- SRF parser extracts rip current risk, surf height, UV index from live NWS products
- Bathymetry provider returns real CUDEM 1/9 arc-second depth profiles (not fallback)
- Wizard marine step has complete help text, species checkboxes, eccodes check
- Marine unit groups customizable in wizard
- Alert filtering differs per activity tab
- Coastal structure auto-discovery returns real OSM data and structures persist through apply
- Structure physics accounts for wave direction relative to structure orientation
- Closed-polygon OSM structures (piers mapped as areas) produce correct bearing and length
- Species data loaded from editable YAML file, not hardcoded — operators can customize
- Species database has 15–25 species per region with research-sourced profiles
- All deployed logos include TM mark
- All governing documents match implemented code
- Test baselines hold
