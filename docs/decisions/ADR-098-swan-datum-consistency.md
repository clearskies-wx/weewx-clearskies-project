# ADR-098: Vertical Datum Consistency for SWAN Inputs

**Status:** Proposed
**Date:** 2026-07-19
**Supersedes:** None
**Related:** ADR-093 (SWAN nearshore model), ADR-095 (SWAN model corrections)

## Context

SWAN computes total water depth by combining BOTTOM (bathymetry) and WLEVEL (water level) inputs. The SWAN User Manual v41.51 requires WLEVEL to be "positive upward relative to the same datum level as used in option BOTTOM." SWAN does not detect or report datum mismatches — a mismatch produces silently wrong depth calculations that corrupt wave breaking predictions.

Production audit (2026-07-19) found:

1. **Datum mismatch:** BOTTOM is in NAVD88 (the DEM's native datum), WLEVEL is in MLLW (hardcoded CO-OPS request). At HB Pier (station 9410660), NAVD88 − MLLW = 0.061m. At other US locations the offset reaches 0.26m.

2. **VDatum normalization silently failing:** The code designed to convert bathymetry to MSL fails on production — `coastalmodeling-vdatum` is not installed, and the VDatum REST API returns 412 errors. The code falls back to a 0.0m offset and proceeds as if nothing is wrong.

3. **Even if VDatum worked, the mismatch would be worse:** The code converts bathymetry to MSL, but CO-OPS predictions are fetched in MLLW (not MSL). This would create a 0.86m mismatch at HB Pier — 14× worse than the current bug.

4. **34 DEMs in the index have unknown datums.** If `find_best_dem()` returns one, datum matching cannot be confirmed.

Full diagnosis: `docs/planning/briefs/SWAN-DATUM-CONSISTENCY-BRIEF.md` (§1–§10).

## Decision

### Primary strategy: match datums at source

Request CO-OPS predictions in the DEM's native datum for SWAN input. No local datum conversion for the common case.

- Bathymetry stays in its native datum (no VDatum conversion, no spatial error).
- The SWAN pipeline reads the DEM's `vertical_datum` from the bathymetry cache and passes it to the CO-OPS fetch: `datum={DEM's vertical_datum}`.
- CO-OPS does the conversion server-side using authoritative tidal datum models.

### Public display datum: MLLW

The public tide display (`/api/v1/tides`) stays MLLW (US chart standard). This is separate from the SWAN input datum and does not change. Two CO-OPS fetches per SWAN run: one MLLW for display, one DEM-native for SWAN.

### Datum metadata on all geospatial data products

Every data product (bathymetry, tide predictions, water levels) carries its vertical datum as a metadata field. Consumers must not assume a datum — they read the field.

- `TidePrediction` model gains a `datum` field (default `"MLLW"` for backward compatibility).
- Bathymetry cache JSON gains a `vertical_datum` field from the DEM index.
- Old cache files without the field trigger a re-download.

### No silent fallbacks

If datum matching cannot be confirmed (DEM datum is UNKNOWN, CO-OPS doesn't support the datum), the SWAN level fails explicitly with an ERROR log. The system never proceeds with an unverified datum mismatch.

### Operator uploads

Operator specifies the datum from the CO-OPS-supported list: NAVD88, MLLW, MHW, MHHW, MSL. No local conversion in v1. If the operator's data is in a different datum, they convert before uploading.

### CMVD deferred

`coastalmodeling-vdatum` is not a v1 dependency. The VDatum code in `bathymetry_resolver.py` is preserved but not called in the primary code path. Revisit for international expansion or edge-case datums CO-OPS doesn't support.

## Consequences

1. Two CO-OPS fetches per SWAN run (MLLW for display, DEM-native for SWAN). Cache keys include the datum so predictions in different datums are cached separately.

2. Bathymetry cache gains a `vertical_datum` field. Existing cache files without this field are treated as stale and re-downloaded on next run.

3. `TidePrediction` model gains a `datum` field. Display endpoint returns `"MLLW"`. SWAN pipeline receives the DEM-native datum internally.

4. VDatum normalization code (`normalize_to_msl()` in `bathymetry_resolver.py`) is preserved but not called from `download_bathymetry_for_level()`. Kept for future edge cases.

5. 34 UNKNOWN DEMs in `ncei_regional_dem_index.json` must be resolved before those areas are served. `find_best_dem()` skips DEMs with `"UNKNOWN"` datum.

6. Operator upload endpoint stops calling `normalize_to_msl()`. Records the operator-specified datum and uses it for CO-OPS matching.

## Out of Scope

- Installing `coastalmodeling-vdatum` on production — deferred, not needed for v1.
- International datum support (LAT, CD) — future, when international tide sources are added.
- Grid-based VDatum conversion — the code exists but is not called; not deleted, not enhanced.
- Changing the public display datum from MLLW.

## Acceptance Criteria

1. SWAN WLEVEL uses predictions in the DEM's native datum (not hardcoded MLLW).
2. Display endpoint (`/api/v1/tides`) still uses MLLW — no change.
3. Bathymetry cache files contain a `vertical_datum` field.
4. `normalize_to_msl()` is not called from `download_bathymetry_for_level()`.
5. CO-OPS datum fetch failure produces ERROR, not silent fallback to 0.0m.
6. `TidePrediction` model has a `datum` field.
7. Zero DEMs in the index have `"UNKNOWN"` datum.
8. All test baselines hold.

## Implementation

See `docs/planning/SWAN-DATUM-PLAN.md` (Phases 1–7).
