# SWAN Vertical Datum Consistency — Implementation Plan

**Status:** EXECUTING (Phases 1-6 complete, Phase 7 audit in progress)
**Created:** 2026-07-19
**Origin:** Production audit found SWAN bathymetry (BOTTOM) and water level (WLEVEL) inputs are on different vertical datums (NAVD88 vs MLLW), the VDatum normalization code is silently failing, and 34 DEMs in the index have unknown datums. Full diagnosis in `docs/planning/briefs/SWAN-DATUM-CONSISTENCY-BRIEF.md`.
**Prerequisite:** Read the datum consistency brief (§1-§10) in full before executing any phase.

---

## 0. Orientation — Execution Context

Same as SWAN-L3-STABILITY-PLAN.md — read those files, use those deploy scripts, follow those SSH rules. Additionally:

**Governing brief:** `docs/planning/briefs/SWAN-DATUM-CONSISTENCY-BRIEF.md` — the governing diagnosis. Every code change must trace to a finding (Bug 1-5) or a section (§3-§9) in that brief.

**Core principle:** All bathymetry (BOTTOM) and water level (WLEVEL) inputs to SWAN must be referenced to the same vertical datum. The primary strategy is match-at-source (request CO-OPS data in the DEM's native datum) to avoid local conversion entirely. No datum conversion software (VDatum, CMVD) is required for v1.

**Regression prevention:** SWAN-FIXES-PLAN Phase 14 RULES 1-5 remain binding. In particular:
- RULE 1: Preserve proven INPUT patterns.
- RULE 4: No blind refactoring of `build_swan_input()`.
- RULE 5: Read `docs/reference/swan-commands-extract.md` before writing any SWAN INPUT generation code.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | Current passing count | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/python -m pytest --tb=no -q 2>&1 \| tail -3"` |

**Deploy script:** `scripts/deploy-api.sh` — the only authorized deploy path.

---

## Phase 1 — ADR + Documentation (HARD PREREQUISITE)

Governing documents must accurately describe the datum consistency requirement BEFORE agents write code. An agent reading the manuals must understand that BOTTOM and WLEVEL must share a datum, that the match-at-source strategy is the primary approach, and that silent datum fallbacks are prohibited.

### T1.1 — Draft ADR: Vertical Datum Consistency for SWAN Inputs

- Owner: Coordinator (Opus)
- File: `docs/decisions/ADR-XXX-swan-datum-consistency.md` (next available number)

**Do:** Draft ADR as Proposed. Content:

1. **Context:** SWAN requires BOTTOM and WLEVEL on the same vertical datum (SWAN User Manual v41.51, "water level positive upward relative to the same datum level as used in option BOTTOM"). Production audit found a datum mismatch (NAVD88 vs MLLW), a silently failing VDatum normalization, and 34 DEMs with unknown datums.

2. **Decision:**
   - Primary strategy: match datums at source. Request CO-OPS predictions in the DEM's native datum for SWAN input. No local datum conversion for the common case.
   - Public display datum: MLLW (US chart standard). Separate from SWAN input.
   - Datum metadata: every data product (bathymetry, tide predictions, water levels) carries its vertical datum as a metadata field.
   - No silent fallbacks: if datum matching cannot be confirmed, the run fails explicitly — never proceeds with an unverified datum.
   - Operator uploads: operator specifies the datum from the CO-OPS-supported list. No local conversion in v1.
   - CMVD deferred: `coastalmodeling-vdatum` is not a v1 dependency. Revisit for international expansion.

3. **Consequences:** Two CO-OPS fetches per SWAN run (one MLLW for display, one DEM-native for SWAN). Bathymetry cache gains a `datum` field. `TidePrediction` model gains a `datum` field. VDatum normalization code is disabled (not deleted — kept for future edge cases). 34 UNKNOWN DEMs must be resolved before those areas are served.

**Accept:** ADR is Proposed. User reviews and approves before Phase 2.

### T1.2 — Update PROVIDER-MANUAL §14.7 (Bathymetry)

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
1. Add datum consistency rule: "All bathymetry (BOTTOM) and water level (WLEVEL) inputs to SWAN must be referenced to the same vertical datum. Mixing datums produces depth errors that corrupt wave breaking predictions."
2. Document the match-at-source strategy: the system fetches CO-OPS tide predictions in the same datum as the bathymetry DEM's native datum.
3. Document the DEM datum inventory (NCEI: MHW/MHHW/NAVD88/MSL/UNKNOWN; Great Lakes: NAVD88; CRM: mixed/unknown).
4. Document the CRM datum limitation: "CRM/DEM_all has no guaranteed datum — datum uncertainty is an additional quality limitation of the coarse fallback."
5. Document accepted datums for operator uploads: NAVD88, MLLW, MHW, MHHW, MSL.
6. Remove or qualify any existing text that implies bathymetry is normalized to MSL.

**Accept:** An agent reading §14.7 understands that datum consistency is mandatory, that match-at-source is the strategy, and that CRM has datum uncertainty.

### T1.3 — Update PROVIDER-MANUAL §14.15 (SWAN Runner)

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
1. Document the dual CO-OPS fetch: MLLW for display, DEM-native datum for SWAN WLEVEL.
2. Document that the SWAN pipeline passes the DEM's `vertical_datum` to the CO-OPS tide fetch.
3. Document that the display endpoint (`/api/v1/tides`) stays MLLW and is unaffected.
4. Document the prohibited pattern: single-point VDatum query applied uniformly to a grid. Reference brief §3.3-§3.5 for rationale.
5. Document the failure mode: if the DEM datum is UNKNOWN or CO-OPS doesn't support it, the SWAN level fails explicitly with an ERROR log — no silent 0.0m fallback.

**Accept:** An agent reading §14.15 can correctly implement the datum-aware WLEVEL pipeline.

### T1.4 — Update OPERATIONS-MANUAL

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
1. Add operator guidance for bathymetry uploads: "Your bathymetry file's vertical datum must match one of the datums supported by your nearest CO-OPS tide station. Common datums: NAVD88, MLLW, MHW, MSL. If your data is in a different datum, convert it before uploading using VDatum (vdatum.noaa.gov) or QGIS."
2. Document the accepted datum list.
3. Document that the system handles datum matching automatically for NCEI and USGS data sources.
4. Document the CRM quality caveat: resolution AND datum uncertainty.

**Accept:** An operator reading the manual knows what datums to use for uploads and understands that SWAN requires datum consistency.

### T1.5 — Update API-MANUAL: Datum Metadata on Data Products

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md`

**Do:**
1. Add a new subsection (or extend §16) documenting the datum metadata contract: every geospatial data product the API serves must carry its vertical datum as a metadata field. Consumers must not assume a datum — they read the field.
2. Document the specific models and their datum fields:
   - `TidePrediction`: `datum` field (new — added in T3.3). Display endpoint returns `"MLLW"`. SWAN pipeline receives the DEM-native datum internally.
   - `WaterLevel`: `datum` field (already exists, value `"MLLW"`).
   - Bathymetry cache JSON: `vertical_datum` field (new — added in T3.1). Value is the DEM's native datum.
   - DEM index entry: `vertical_datum` field (already exists).
   - Coverage endpoint response: includes `vertical_datum` per level and `datum_warning` when uncertain.
3. Document the dual-datum pattern for tides: the API serves predictions in MLLW for public display, while the SWAN pipeline internally fetches in the DEM-native datum. The display endpoint response always carries `datum: "MLLW"`. The SWAN datum is internal and never exposed to the dashboard.
4. Document the accepted datums list for operator-uploaded bathymetry: NAVD88, MLLW, MHW, MHHW, MSL — must match a CO-OPS-supported datum.
5. Remove or qualify any existing §16-§18 text that implies data is in MSL when it is in MLLW, or that omits the datum field from response shapes.

**Accept:** An agent or developer reading the API-MANUAL knows that every geospatial response carries a datum field, what the accepted values are, and that the display and SWAN datums are intentionally different. No response model description omits its datum field.

### T1.6 — Update ARCHITECTURE.md SWAN section

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md`

**Do:**
1. In the SWAN nearshore model note: add "Vertical datum normalization to MSL via NOAA VDatum REST API (spatially-varying offsets — not constant)" → replace with: "Vertical datum consistency enforced by matching CO-OPS tide prediction datum to the bathymetry DEM's native datum. No local datum conversion for the common case."
2. Remove the VDatum reference from the architecture description (it's no longer the primary mechanism).

**Accept:** ARCHITECTURE.md matches the to-be-implemented datum approach. No stale references to VDatum as the primary datum strategy.

### T1.7 — Update `swan-commands-extract.md`

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/reference/swan-commands-extract.md`

**Do:**
1. In the READINP WLEV section (line 271), verify the text says: "read water level values (meters, positive upward, same datum as BOTTOM)."
2. In the WLEVEL sign convention note (line 289), verify it says: "Positive upward relative to the same datum level as BOTTOM."
3. Add a datum consistency warning: "SWAN does not detect or report datum mismatches between BOTTOM and WLEVEL. A mismatch produces silently wrong depth calculations. The system ensures consistency by requesting CO-OPS predictions in the DEM's native datum."

**Accept:** The SWAN command reference explicitly states the datum consistency requirement.

### QC Gate 1

- `clearskies-auditor` verifies:
  - ADR exists as Proposed with correct content.
  - PROVIDER-MANUAL §14.7 contains the datum consistency rule, match-at-source strategy, DEM datum inventory, CRM caveat, and accepted upload datums.
  - PROVIDER-MANUAL §14.15 describes the dual CO-OPS fetch, prohibited single-point pattern, and explicit failure mode.
  - OPERATIONS-MANUAL contains operator datum guidance.
  - API-MANUAL documents the datum metadata contract: every geospatial data product carries a `datum` field. `TidePrediction`, `WaterLevel`, bathymetry cache, DEM index, and coverage endpoint all documented with their datum fields and accepted values.
  - API-MANUAL documents the dual-datum pattern (MLLW for display, DEM-native for SWAN).
  - API-MANUAL documents accepted datums for operator uploads.
  - ARCHITECTURE.md does not reference VDatum as the primary datum strategy.
  - `swan-commands-extract.md` READINP WLEV section states "same datum as BOTTOM."
  - `grep -ri "normalize_to_msl\|normalize.*msl\|convert.*to.*msl" docs/manuals/` returns zero hits that describe MSL normalization as the active strategy (only historical references allowed).
  - All test baselines hold.

---

## Phase 2 — Resolve UNKNOWN DEMs (BLOCKING Research)

34 DEMs in `ncei_regional_dem_index.json` have `"vertical_datum": "UNKNOWN"`. Several cover critical areas (SoCal, Gulf coast). If `find_best_dem()` returns one, the system cannot match datums and would proceed with an unverified mismatch.

### T2.1 — Research: Identify datums for all 34 UNKNOWN DEMs

- Owner: Coordinator (Opus)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/data/ncei_regional_dem_index.json`
  - Modify: `repos/weewx-clearskies-api/scripts/build_ncei_dem_index.py`

**Do:**
1. For each of the 34 UNKNOWN files, query the NCEI metadata endpoint: `https://www.ncei.noaa.gov/metadata/geoportal/rest/metadata/item/gov.noaa.ngdc.mgg.dem:{id}/xml` or the THREDDS catalog landing page. Extract the vertical datum.
2. Cross-reference with the DEM filename convention: files with `_P/_G/_N/_S` + 3-digit suffix (e.g., `san_pedro_bay_P050_2018.nc`) are NOAA Tsunami Program DEMs — these typically use MHW. Files with `_isl_` suffix are island DEMs — typically MSL.
3. Record findings in a table: filename → actual datum → source of determination.
4. Update `ncei_regional_dem_index.json` with the resolved datums.
5. Update `scripts/build_ncei_dem_index.py` with a fallback lookup table keyed by filename for DEMs whose `.das` metadata doesn't expose the datum. Add a comment explaining why the lookup exists.

**Critical SoCal DEMs that MUST be resolved:**
- `san_pedro_bay_P050_2018.nc` — covers Long Beach / San Pedro
- `santa_monica_bay_P060_2018.nc` — covers Santa Monica / Malibu
- `san_diego_bay_P020_2017.nc` — covers San Diego
- `monterey_bay_P080_2018.nc` — covers Monterey / Santa Cruz

**Accept:**
- All 34 previously-UNKNOWN DEMs now have a verified datum in the index.
- Each datum determination is documented with its source (NCEI metadata page URL or document reference).
- The index builder script handles these files without producing UNKNOWN.
- Zero entries in the index have `"vertical_datum": "UNKNOWN"`.

### T2.2 — Verify CO-OPS datum support for configured station

- Owner: Coordinator (Opus)

**Do:**
1. Test fetch: `GET https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&datum=NAVD88&station=9410660&begin_date=20260719&range=6&time_zone=gmt&units=metric&format=json`
2. If 200 with data → NAVD88 is supported. Record.
3. Repeat for MHW, MHHW, MSL — verify the station supports all datums that appear in the DEM index.

**Accept:** Station 9410660 supports predictions in NAVD88, MHW, MHHW, and MSL (or the specific subset verified). Results documented.

### QC Gate 2

- `clearskies-auditor` verifies:
  - `grep -c '"UNKNOWN"' ncei_regional_dem_index.json` returns 0.
  - Each of the 4 critical SoCal DEMs has a verified non-UNKNOWN datum.
  - The index builder script includes a fallback lookup table for DEMs without `.das` datum metadata.
  - CO-OPS station 9410660 supports the datums needed for the resolved DEMs.
  - All test baselines hold.

---

## Phase 3 — Datum-Aware SWAN Pipeline (Core Fix)

Replace the broken VDatum-normalize-to-MSL approach with match-at-source: fetch CO-OPS SWAN predictions in the DEM's native datum.

### T3.1 — Add datum metadata to bathymetry cache

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` (`download_bathymetry_for_level`)

**Do:**
1. When writing a bathymetry cache JSON file, include `"vertical_datum"` from the DEM index entry (e.g., `"vertical_datum": "NAVD88"`).
2. When reading a cached file, if `"vertical_datum"` is missing (old cache), treat as stale — re-download.
3. The datum field is informational for the OPeNDAP path (bathymetry stays in its native datum) but is consumed by the SWAN pipeline to know which datum to request from CO-OPS.

**Logging:** INFO: `"CUDEM L{level}: cached bathymetry datum=%s source=%s"` on cache read.

**Accept:**
- Newly cached bathymetry files contain `"vertical_datum"` field.
- Old cache files without the field trigger a re-download.
- Logged datum matches the DEM index.

### T3.2 — Remove VDatum normalization from the bathymetry download path

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` (`download_bathymetry_for_level`)

**Do:**
1. Remove the call to `normalize_to_msl()` from `download_bathymetry_for_level()` (line ~276). Bathymetry stays in its native datum.
2. Remove the import of `normalize_to_msl` from `bathymetry_resolver`.
3. If the DEM's `vertical_datum` is `"UNKNOWN"`, **do not proceed** — log ERROR: `"Cannot use DEM %s: vertical datum is UNKNOWN. Resolve in ncei_regional_dem_index.json."` and fall through to the next source in the resolver chain.
4. **Do NOT delete** `normalize_to_msl()` or `_query_vdatum_offset()` from `bathymetry_resolver.py` — they may be needed for future edge cases. Just remove the call site.

**Accept:**
- `download_bathymetry_for_level()` no longer calls `normalize_to_msl()`.
- An UNKNOWN-datum DEM produces an ERROR log and falls through to the next source.
- `bathymetry_resolver.py` still contains the VDatum code (unused but preserved).

### T3.3 — Add `datum` field to `TidePrediction` model

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/tides/coops.py`

**Do:**
1. Add `datum: str = "MLLW"` to `TidePrediction` model (default preserves backward compatibility).
2. In `_fetch_predictions()`, set the `datum` field on each returned `TidePrediction` to the datum used in the request (currently hardcoded `"MLLW"`).
3. This is preparatory — the SWAN pipeline will use a separate fetch with a different datum (T3.4), but the model must support carrying the datum.

**Accept:**
- `TidePrediction` objects include a `datum` field.
- The display endpoint returns `datum: "MLLW"` in each prediction (backward compatible).

### T3.4 — Datum-aware CO-OPS fetch for SWAN WLEVEL

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/tides/coops.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`

**Do:**
1. In `coops.py`, add a `datum` parameter to `_fetch_predictions()` (default `"MLLW"` for backward compatibility). Pass it to the CO-OPS API request instead of the hardcoded `"MLLW"`. Include the datum in the cache key so MLLW and NAVD88 predictions are cached separately.
2. In `swan.py:run_all_spots()`, after bathymetry download, read the bathymetry's `vertical_datum` from the cache.
3. Fetch CO-OPS predictions for SWAN using `datum=vertical_datum` instead of the default MLLW.
4. Pass these datum-matched predictions to the SWAN runner for WLEVEL.
5. The display endpoint (`/api/v1/tides`) continues to call `_fetch_predictions()` with the default `datum="MLLW"` — no change.

**Logging:**
- INFO: `"SWAN: CO-OPS tide predictions fetched in datum=%s (matching DEM %s)"`.
- If CO-OPS returns an error for the requested datum, ERROR: `"CO-OPS does not support datum=%s for station %s — SWAN run cannot proceed with unmatched datums."` Do NOT fall back to MLLW silently.

6. Apply the same pattern in `_run_quick_update_locked()` — the quick update path must also use the datum-matched fetch.

**Accept:**
- SWAN WLEVEL uses predictions in the DEM's native datum (e.g., NAVD88 for the OC DEM).
- The display endpoint still uses MLLW.
- CO-OPS datum fetch failure is an ERROR that blocks the SWAN level, not a silent fallback.
- Quick update path also uses the datum-matched fetch.
- Log confirms the datum used for each SWAN run.

### T3.5 — Fix docstrings and comments

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (line 598)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/bathymetry_resolver.py` (normalize_to_msl docstring)

**Do:**
1. `swan_runner.py:598`: Change "positive up from MSL" to "positive up from the DEM's native datum (must match BOTTOM)".
2. `bathymetry_resolver.py:normalize_to_msl()` docstring: Add note that this function is not called in the primary code path — datum matching is done at source per ADR-XXX.
3. Grep for any other references to "MSL" in the SWAN pipeline that imply MSL normalization is active: `grep -rn "MSL\|msl" repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`. Fix any that are misleading.

**Accept:**
- No docstrings in the SWAN pipeline claim the data is in MSL when it is not.
- `normalize_to_msl()` is documented as inactive in the primary path.

### QC Gate 3

- `clearskies-auditor` verifies:
  - Bathymetry cache files contain `"vertical_datum"` field.
  - `normalize_to_msl()` is NOT called from `download_bathymetry_for_level()`.
  - UNKNOWN-datum DEMs produce an ERROR and fall through (not silently used).
  - `TidePrediction` model has a `datum` field.
  - SWAN pipeline fetches CO-OPS predictions in the DEM's native datum.
  - Display endpoint still fetches MLLW.
  - CO-OPS datum failure produces ERROR, not silent fallback.
  - Quick update path uses datum-matched fetch.
  - Docstrings do not claim MSL when data is in a different datum.
  - `grep -rn "normalize_to_msl" repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` returns zero hits (call removed).
  - Changes match PROVIDER-MANUAL §14.7 and §14.15 (updated in Phase 1).
  - All test baselines hold.

---

## Phase 4 — CRM Fallback Datum Handling

The CRM/`DEM_all` fallback has mixed/unknown datums. This phase adds visibility into that limitation without blocking it — CRM is already flagged as degraded quality.

### T4.1 — Query CRM `VerticalDatum` attribute when available

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py` (`download_swan_depth_grid`)

**Do:**
1. The `DEM_all` ImageServer exposes a `VerticalDatum` attribute per pixel in the `getSamples` response. Check if this attribute is present in the response.
2. If present and consistent across sampled points: record in the cache as `"vertical_datum": "{value}"`. Use this for CO-OPS datum matching.
3. If absent, inconsistent, or unrecognizable: record as `"vertical_datum": "UNKNOWN_CRM"`. Log WARNING: `"CRM bathymetry has unknown vertical datum — SWAN depth calculations may have up to ~1m vertical bias."` Request CO-OPS in MSL as the best-available assumption.

**Accept:**
- CRM-sourced bathymetry cache includes `"vertical_datum"` field (actual or `"UNKNOWN_CRM"`).
- Known CRM datum enables correct CO-OPS matching.
- Unknown CRM datum produces a WARNING and uses MSL as best-effort assumption.

### T4.2 — Add datum warning to coverage endpoint

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (coverage endpoint)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/locales/*.json` (13 locale files)

**Do:**
1. When the coverage endpoint reports `"degraded"` quality for CRM-sourced levels, add `"datum_warning": true` and a locale-keyed message explaining the datum uncertainty.
2. Add i18n key: `marine.bathymetry.warning.datum_unknown` — "Bathymetry data source has unknown vertical datum. Wave model depth calculations may have reduced accuracy."

**Accept:**
- Coverage endpoint includes `datum_warning` for CRM-sourced levels.
- Warning text comes from locale key (not hardcoded English).

### QC Gate 4

- `clearskies-auditor` verifies:
  - CRM-sourced cache includes `"vertical_datum"` field.
  - Coverage endpoint includes `datum_warning` for CRM-sourced levels.
  - Warning text is locale-keyed.
  - All test baselines hold.

---

## Phase 5 — Complete Operator Bathymetry Upload (SWAN-FIXES-PLAN Phase 24 Remainder)

SWAN-FIXES-PLAN Phase 24 is partially complete: the API-side resolver (`get_operator_grid`), upload endpoint (`POST /setup/marine/bathymetry/upload`), priority chain wiring, and locale keys are implemented. What remains: the admin UI, the datum handling fix (upload endpoint still calls the broken `normalize_to_msl` path), and governing document updates.

### T5.1 — Fix upload endpoint datum handling

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` (upload endpoint, line ~3648)

**Do:**
1. The upload endpoint currently calls `normalize_to_msl()` to convert the operator's bathymetry to MSL. This is the broken VDatum approach documented in brief §4. Remove this call.
2. Instead, record the operator-specified datum in the metadata file (`operator_meta.json`) as `"vertical_datum": "{operator_selection}"`.
3. The resolver (`get_operator_grid` in `bathymetry_resolver.py`) must return the datum in the grid dict so the SWAN pipeline can match CO-OPS to it (same pattern as NCEI DEMs in T3.4).
4. Restrict the datum dropdown to CO-OPS-supported datums only: NAVD88, MLLW, MHW, MHHW, MSL. Remove LAT, EGM2008, and "Other with manual offset" — these require conversion we are not implementing in v1. If an operator has data in one of those datums, they convert before uploading (per brief §9.4).
5. Update the Pydantic validation model to reject datums not in the accepted list.

**Logging:** INFO: `"Operator bathymetry uploaded: datum=%s, resolution=%.1fm, bbox=(%s)"`.

**Accept:**
- Upload endpoint does NOT call `normalize_to_msl()`.
- `operator_meta.json` records the operator-specified datum.
- `get_operator_grid()` returns `"vertical_datum"` in the grid dict.
- SWAN pipeline fetches CO-OPS in the operator's specified datum (same match-at-source pattern).
- Datums outside the accepted list (LAT, EGM2008, etc.) are rejected with a locale-keyed error message.

### T5.2 — Admin UI for bathymetry upload (SWAN-FIXES-PLAN T24.3)

- Owner: `clearskies-docs-author` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
  - Modify: `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py`
  - Modify: all 13 locale translation files in `repos/weewx-clearskies-stack/weewx_clearskies_config/translations/`

**Do:** Add a "Bathymetry" card in the admin marine section with:
1. File upload field (accepts GeoTIFF, NetCDF, ASCII XYZ).
2. Datum dropdown — restricted to: NAVD88, MLLW, MHW, MHHW, MSL. Help text: "Select the vertical datum of your bathymetry file. The system will fetch tide predictions in the same datum to ensure consistency. If your data is in a different datum, convert it before uploading using VDatum (vdatum.noaa.gov) or QGIS."
3. Validation results display (HTMX-loaded from the upload endpoint response): per-level coverage, resolution assessment, datum recorded.
4. Replace/Remove buttons.
5. Current status display: if operator bathymetry is active, show the datum, resolution, and upload date from `operator_meta.json`.

**i18n:** Add keys to all 13 stack translation files:
- `admin.marine.bathymetry.upload.title` — upload section heading
- `admin.marine.bathymetry.upload.label` — file input label
- `admin.marine.bathymetry.upload.help` — accepted formats help text
- `admin.marine.bathymetry.datum.label` — datum dropdown label
- `admin.marine.bathymetry.datum.navd88` / `mllw` / `mhw` / `mhhw` / `msl` — datum option labels
- `admin.marine.bathymetry.datum.help` — datum selection help text (the "convert before uploading" guidance)
- `admin.marine.bathymetry.actions.replace` / `actions.remove` — button labels
- `admin.marine.bathymetry.validation.*` — validation result labels
All visible text must render from translation keys. No hardcoded English in templates.

**Accept:** HTMX upload works end-to-end. Datum dropdown shows only the 5 accepted datums. Validation results display correctly. Replace/remove works. All visible text from translation keys.

### T5.3 — Update governing documents (SWAN-FIXES-PLAN T24.4)

- Owner: Coordinator (Opus)
- Files: `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- OPERATIONS-MANUAL: Document operator bathymetry upload — accepted formats (GeoTIFF, NetCDF, ASCII XYZ), accepted datums (NAVD88, MLLW, MHW, MHHW, MSL), where to find bathymetry data (NOAA, USACE, state agencies), how to verify the datum, how to convert if needed (VDatum desktop tool or QGIS), how to remove the upload and revert to automated sources.
- PROVIDER-MANUAL §14.7: Document operator file as highest priority in the resolver chain. Document that the operator-specified datum is used for CO-OPS datum matching (no local conversion).

**Accept:** Manuals match implementation. Operator guidance covers the datum requirement.

### QC Gate 5

- `clearskies-auditor` verifies:
  - Upload endpoint does NOT call `normalize_to_msl()` — `grep -n "normalize_to_msl" repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py` returns zero hits in the upload handler.
  - `operator_meta.json` records the datum.
  - `get_operator_grid()` returns `vertical_datum` in the grid dict.
  - SWAN pipeline uses the operator datum for CO-OPS matching.
  - Datum dropdown restricted to 5 accepted datums (no LAT, EGM2008, or "Other").
  - Admin UI end-to-end: upload → validation display → replace → remove.
  - All visible text from translation keys — `grep -rn "GeoTIFF\|NetCDF\|ASCII XYZ\|NAVD88\|MLLW" repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html` returns zero hardcoded instances (all from translation keys).
  - OPERATIONS-MANUAL and PROVIDER-MANUAL match implementation.
  - All test baselines hold.

---

## Phase 6 — Deploy & Production Verification

### T6.1 — Deploy and purge

- Owner: Coordinator (Opus)
- Depends on: Phases 1-5 complete, ADR Accepted, all QC gates passed.

**Do:**
1. Deploy the API via `scripts/deploy-api.sh`.
2. Purge cached bathymetry files (they lack datum metadata):
   ```
   ssh weewx "sudo rm -f /etc/weewx-clearskies/swan_bathymetry_L*.json /etc/weewx-clearskies/swan_bathymetry_L3_*.json"
   ```
3. Verify the API started: `systemctl status weewx-clearskies-api`.
4. Check logs for startup errors.

**Accept:** API running. Purged files removed. No startup errors.

### T6.2 — Wait for and verify full SWAN run

- Owner: Coordinator (Opus)

**Do:** Wait for the next HRRR cycle to trigger a full SWAN run. Then verify:

1. **Bathymetry cache has datum metadata.** Check: `sudo python3 -c "import json; d=json.load(open('/etc/weewx-clearskies/swan_bathymetry_L2.json')); print('datum:', d.get('vertical_datum', 'MISSING'))"` — should show the DEM's datum (e.g., NAVD88), not MISSING.

2. **CO-OPS fetch uses DEM datum for SWAN.** Check logs: `journalctl -u weewx-clearskies-api | grep "CO-OPS tide predictions fetched in datum"` — should show the DEM's datum, not MLLW.

3. **No VDatum errors.** Check: `journalctl -u weewx-clearskies-api | grep -i "vdatum\|datum.*offset\|normalize_to_msl"` — should find no VDatum query attempts (the call is removed).

4. **SWAN convergence OK.** Check: logs show convergence check passed for all levels.

5. **Surf forecast non-zero.** Check: `curl -s http://localhost:8765/api/v1/surf/huntington-city-beach-pier | python3 -m json.tool | grep swellHeight` — non-zero values.

6. **Display endpoint still MLLW.** Check: the tide endpoint returns predictions without change from pre-deploy behavior.

**Accept:** All 6 items pass with evidence (log excerpts, command output).

### T6.3 — Verify quick update

- Owner: Coordinator (Opus)

**Do:** Wait for the next hourly quick update. Verify:

1. **Quick update uses DEM datum.** Check logs for datum-matched CO-OPS fetch.
2. **Quick update convergence OK.**
3. **Card timestamp advances.**

**Accept:** All 3 items pass.

### QC Gate 6

- `clearskies-auditor` verifies (independently):
  - All T6.2 evidence items are genuine (re-run verification commands).
  - All T6.3 evidence items are genuine.
  - No `normalize_to_msl` calls in production logs.
  - Bathymetry cache files have `vertical_datum` field.
  - CO-OPS SWAN fetch uses DEM datum, not MLLW.

---

## Phase 7 — Final Adversarial Audit

### T7.1 — QC gate verification audit

- Owner: `clearskies-auditor` (independent — NOT the implementing agent)

**Do:** For EVERY QC gate in Phases 1-6, verify each item was actually satisfied — not just checked off.

1. **Re-run acceptance tests.** For each Accept criterion that references a testable output, run the test independently and record the command and its output.

2. **Check for silent deferrals.** Search the codebase for:
   - `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER` added during this plan's implementation.
   - Functions that return hardcoded values where real computation was specified.
   - `pass` statements in functions that should have implementations.
   - Any code path that silently returns 0.0 as a datum offset.

3. **Check datum consistency end-to-end.** For the production SWAN run:
   - Read the bathymetry cache → extract `vertical_datum`.
   - Read the SWAN WLEVEL log → extract the CO-OPS fetch datum.
   - Verify they match.
   - Read the WLEVEL.txt file → verify values are in the expected range for the datum.

4. **Check for stale datum references.** Grep the codebase:
   - `grep -rn "positive up from MSL" repos/weewx-clearskies-api/` — should find zero in the SWAN pipeline (only in VDatum code docstrings).
   - `grep -rn '"datum": "MLLW"' repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/` — should find zero (SWAN path uses DEM datum, not hardcoded MLLW).
   - `grep -rn "normalize_to_msl" repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` — should find zero (call removed).

5. **Log evidence, not assertions.** Every finding includes the command run and output observed.

**Accept:** Audit report with pass/fail per QC gate item, evidence for each, and a list of any silent deferrals found.

### T7.2 — Doc-code consistency audit

- Owner: `clearskies-auditor`

**Do:**
1. For each document updated in Phase 1:
   - Read the document section.
   - Read the corresponding code.
   - Flag any claim in the doc that does not match the code.
2. Specific checks:
   - PROVIDER-MANUAL §14.7 datum consistency rule — matches actual `download_bathymetry_for_level()` behavior.
   - PROVIDER-MANUAL §14.15 dual CO-OPS fetch — matches actual `run_all_spots()` and `_run_quick_update_locked()`.
   - OPERATIONS-MANUAL operator datum guidance — accepted datums match the CO-OPS supported list.
   - ARCHITECTURE.md SWAN section — no stale VDatum-as-primary references.
   - `swan-commands-extract.md` READINP WLEV — "same datum as BOTTOM" present.
   - ADR matches implementation.

**Accept:** Zero doc-code mismatches, or all mismatches reported with specific file:line references.

### T7.3 — Lessons capture

- Owner: Coordinator (Opus)

**Do:** After the audit, triage lessons into the correct files:
- "SWAN BOTTOM and WLEVEL must use the same vertical datum — SWAN does not detect or correct mismatches" → `docs/reference/swan-commands-extract.md`
- "Never silently fall back to 0.0m offset for datum conversion failure — fail explicitly" → `rules/clearskies-process.md`
- "Match datums at source (request data in the needed datum) rather than converting locally — avoids conversion errors and computational overhead" → `rules/clearskies-process.md`
- "Datum metadata must be tracked on every geospatial data product — bathymetry, water levels, tide predictions" → `docs/manuals/PROVIDER-MANUAL.md`
- "Public tide display uses MLLW (US chart standard); SWAN input uses the DEM's native datum — these are separate consumers with separate requirements" → `docs/manuals/PROVIDER-MANUAL.md`

**Accept:** Each lesson routed to the correct file. No lessons left only in this plan's narrative.

### QC Gate 7 (Final)

All of the following must be true:

- Every QC gate item from Phases 1-6 independently verified with evidence.
- Zero silent deferrals (or all deferrals explicitly documented with `# TODO` and a plan reference).
- Zero doc-code mismatches (or all reported and fixed).
- Production verification (T6.2 + T6.3) passes with evidence.
- Lessons captured in the correct rule/reference files.
- All test baselines hold.
- `grep -rn "normalize_to_msl" repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` returns zero.
- `grep -c '"UNKNOWN"' repos/weewx-clearskies-api/weewx_clearskies_api/data/ncei_regional_dem_index.json` returns zero.
- Bathymetry cache files on production contain `"vertical_datum"` field.
- SWAN WLEVEL log shows DEM-native datum, not MLLW.
- Operator upload endpoint does NOT call `normalize_to_msl()`.
- Admin bathymetry upload UI functional with datum dropdown restricted to 5 accepted datums.
- SWAN-FIXES-PLAN Phase 24 fully complete (no remaining tasks).

**Sign-off:** The coordinator presents the T7.1 audit report to the user. The user decides whether the plan is complete.

---

## Execution Order

```
Phase 1 (Docs + ADR)       ← HARD PREREQUISITE — agents read manuals before coding
Phase 2 (UNKNOWN DEMs)     ← BLOCKING — must resolve before datum-matching works
Phase 3 (Core Fix)         ← The datum-aware pipeline
Phase 4 (CRM Fallback)     ← Visibility into CRM datum limitation
Phase 5 (Operator Upload)  ← Complete SWAN-FIXES-PLAN Phase 24 (datum fix + admin UI + docs)
Phase 6 (Deploy)           ← Deploy, purge, verify
Phase 7 (Audit)            ← Adversarial verification of every QC gate
```

**Sequence constraints:**
1. Phase 1 blocks everything. Agents read manuals before coding.
2. Phase 2 blocks Phase 3. The DEM index must have no UNKNOWN datums before the match-at-source logic can rely on it.
3. Phases 3, 4, and 5 can be developed in parallel but must all complete before Phase 6.
4. Phase 5 depends on Phase 3 (T3.4 establishes the datum-aware CO-OPS fetch pattern that T5.1 must follow).
5. Phase 6 is deploy + verify.
6. Phase 7 is last. Adversarial audit. User sign-off.

---

## Out of Scope (explicit — do not let agents drift into these)

- Installing `coastalmodeling-vdatum` (CMVD) on production — deferred, not needed for v1.
- International datum support (LAT, CD) — future, when international tide sources are added.
- Grid-based VDatum conversion implementation — the code exists but is not called; not deleted, not enhanced.
- `convergence_retry = true` degradation ladder — separate concern, tracked in SWAN-L3-STABILITY-PLAN.
- Any rewrite/"cleanup" of `build_swan_input()` beyond docstring fixes (RULE 4).
- Modifying the `DEM_all` ImageServer queries to return per-pixel datum (T4.1 only reads what's already returned).
- Changing the public display datum from MLLW to anything else.
