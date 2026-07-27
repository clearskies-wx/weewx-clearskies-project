# ADR-098: Vertical Datum Consistency for SWAN Inputs

**Status:** Proposed
**Date:** 2026-07-19
**Amended:** 2026-07-26 — grid-wise conversion to LMSL adopted for the US (reversing the CMVD deferral), worldwide path enumerated, cross-level datum guard added. 2026-07-27 — the single-datum contract is split by region: LMSL for ocean/tidal domains (unchanged), per-lake `LWD_IGLD85` for Great Lakes domains (new — the Great Lakes are non-tidal, so no tidal datum including LMSL applies to them). 2026-07-27 (later same day) — Great Lakes bathymetry source routing corrected from NCEI Great Lakes Bathymetry to the USGS Rohweder 2025 DEM the code actually calls (C-106), and that source decided at all three levels, superseding the "undecided option" framing this ADR carried briefly. Amendments are marked inline.
**Supersedes:** None
**Related:** ADR-093 (SWAN nearshore model), ADR-095 (SWAN model corrections), C-90 (fabricated bathymetry / datum findings, `docs/planning/MARINE-SEP-CONCERNS.md`)

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

> **Amended 2026-07-26.** Match-at-source stands, but it can no longer produce a single datum by itself. It assumed one DEM served every level. Once L1 is a **global** product (ETOPO 2022, MSL — chosen because regional coastal DEMs cannot be relied on to span L1's shelf-edge-to-shore extent) and L2/L3 remain regional (predominantly NAVD 88 — 665 of 1000 catalogue rasters), two datums exist across the nest regardless of how sources are selected. Measured at HB Pier: CO-OPS NAVD − MSL = **0.799 m**. In the surf zone, depth-limited breaking `Hb ≈ γ·d` turns that into ~0.6 m of breaking height and shifts the break point ~40 m on a 1:50 slope — not a rounding error. The common datum is therefore established by **grid-wise conversion to LMSL** (below), with match-at-source then supplying WLEVEL in MSL.

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

> **Amended 2026-07-26 — cross-level guard.** This clause was never enforced *between* levels, and the code reads one datum for the whole run ("L2 preferred, L1 fallback"), stamping it on every level. Nothing verifies that L1, L2 and L3 agree. They happen to agree today (all five live caches are NAVD 88) but by coincidence, not construction: the same Huntington box offers `socal_1as`/`socal_3as` on **MSL** alongside `orange_county_13_navd88_2015` on **NAVD 88**, and each level looks a DEM up independently. An L2/L3 disagreement would put the full 0.6 m breaking-height error in the surf zone silently. **Every level's datum must be verified to agree before a run; disagreement refuses.** Note that `UNKNOWN_CRM` is a truthy string and so passed this clause's existing check — the label was assigned by us, not published by the source, and is itself removed (the mosaic catalogue publishes `VerticalDatum` per raster).
>
> **Amended 2026-07-27 — the guard is per-region, because the common datum is now per-region (C-103, `docs/planning/MARINE-SEP-CONCERNS.md`).** The invariant this clause enforces has not changed shape — every level *within one SWAN domain* must still share exactly one datum — but which datum that is now depends on where the domain sits. Ocean/tidal domains unify on **LMSL** (`NOAA:1761`) as this ADR already specifies, unchanged. Great Lakes domains — non-tidal, so no tidal datum including LMSL applies to them — unify on that lake's own **`LWD_IGLD85`** (`NOAA:1759`, Low Water Datum on the International Great Lakes Datum 1985). The cross-level guard therefore runs **within a region, never across regions**: a Great Lakes run's L1/L2/L3 must agree with each other on `LWD_IGLD85`; an ocean run's levels must agree with each other on LMSL; a Great Lakes level's datum is never compared against an ocean level's, because the two are never inputs to the same SWAN domain. See "Great Lakes datum branch" below for the source routing and conversion pair this adds.

### Operator uploads

Operator specifies the datum from the CO-OPS-supported list: NAVD88, MLLW, MHW, MHHW, MSL. No local conversion in v1. If the operator's data is in a different datum, they convert before uploading.

### Grid-wise datum conversion — NOW (US) and LATER (worldwide)

**Amended 2026-07-26.** The original text deferred `coastalmodeling-vdatum` as "not a v1 dependency," on the grounds recorded in Context §2: the library was not installed and the VDatum **REST API** returned 412s. That reasoning was sound about the implementation we had and wrong about the capability that exists. Two facts found on re-examination:

- `normalize_to_msl(depths, datum, center_lat, center_lon)` collapses the whole grid to its **domain centre** and applies one scalar. Tidal-datum separations vary over short distances, so a single offset is not a valid transformation of a grid — which is the real reason the deferred path looked unusable.
- The published libraries convert **entire grids offline**. `vdatum.convert(vd_from, vd_to, lat, lon, z, ...)` accepts arrays, and offline mode reads local separation GeoTIFFs — no REST API, no per-point call.

So the deferral rested on a single-point call against a flaky web service, not on the grid-wise offline capability. It is reversed.

**NOW — United States, ocean/tidal domains.** Unify every SWAN input on **LMSL**:

- L1 (ETOPO 2022 15 arc-sec) is natively MSL — no conversion.
- L2/L3 regional DEMs convert **per cell** from NAVD 88 (or MHW/MHHW) to LMSL using NOAA's separation grids through PROJ.
- One CO-OPS WLEVEL fetch in MSL, matching all levels.

**Amended 2026-07-27 — Great Lakes datum branch (operator ruling, C-103, `docs/planning/MARINE-SEP-CONCERNS.md`).** The Great Lakes are non-tidal, so LMSL — a tidal datum — does not apply there: *"the Great Lakes are NOT AT SEA LEVEL"* (operator, verbatim). Confirmed against live data: CO-OPS Great Lakes stations publish only `GL_LWD` and no MSL at all — station 9087044 (Calumet Harbor) returns `GL_LWD: 577.43 ft` (176.0 m) with `LAT`/`HAT` both null. This is why the ADR's single-datum contract (above, and the cross-level guard amendment) is now "one datum per region" rather than "one datum everywhere."

- **NOAA VDatum publishes a separate Great Lakes datum family**, distinct from the tidal family this ADR already validated: `IGLD85` (International Great Lakes Datum 1985), `LWD_IGLD85` (Low Water Datum on IGLD85), `OHWM_IGLD85` (Ordinary High Water Mark on IGLD85). Both families come from the same national NWLD 4.7.0 product line and share the source CRS `EPSG:6318+EPSG:5703`.
- **Ruling: Great Lakes SWAN domains — bathymetry and WLEVEL alike — unify on `LWD_IGLD85`.** Verified separations from the LMSL/ocean control (−0.8274 m at HB Pier, T8.11a) are roughly 200× larger for the Great Lakes: about **−176.10 m** across the Lake Michigan basin, **−173.50 m** at Lake Erie — matching NOAA's published Low Water Datum plane elevations for those lakes (176.0 m Michigan–Huron, 173.5 m Erie). Anyone reading or writing code against these separations should not assume the ocean case's sub-metre scale.
- **Bathymetry source routing — corrected 2026-07-27 (adversarial audit; C-106, `docs/planning/MARINE-SEP-CONCERNS.md`).** This clause originally named NCEI Great Lakes Bathymetry as the L1/L2 source, natively referenced to each lake's own low water datum and needing **no conversion**, with only the L3-grade NOAA OCM Coastal DEM (~3 m) requiring `NAVD88 → LWD_IGLD85`. That is wrong about the code. `_try_great_lakes()` in `providers/nearshore/swan.py` — reached via `_ensure_great_lake_dem()` / `fetch_great_lake_grid()` in `services/bathymetry_resolver.py` — is the sole Great Lakes bathymetry source at **all three levels**, L1 through L3. It downloads the **USGS Rohweder 2025** ScienceBase release (DOI `10.5066/P1DA6L6U`, cached to `/etc/weewx-clearskies/great_lakes/{lake}.tif`), the same NOAA OCM Great Lakes Coastal DEM lineage — roughly 3 m resolution and confirmed **NAVD88**-referenced against NOAA's own InPort metadata record. `_try_great_lakes()` correctly hardcodes `grid["vertical_datum"] = "NAVD88"`. **NCEI Great Lakes Bathymetry is not implemented anywhere in this codebase, and per C-106 (coordinator ruling, 2026-07-27, under operator instruction not to leave the question open) it will not be added: USGS Rohweder 2025 is the decided Great Lakes bathymetry source at L1, L2 and L3.** NCEI's only apparent advantage — a native-LWD source needing no conversion — is worth nothing now that `NAVD88 → LWD_IGLD85` is implemented, automatic, and empirically verified (table below); a split source (NCEI at L1/L2, USGS at L3) would also seam one domain's levels across two different surveys, exactly the inconsistency this ADR exists to eliminate; and NCEI's ~90 m nominal grid (compiled at 1:250,000 with 5 m contours) cannot serve L3's 10 m target regardless. Consequence: `NAVD88 → LWD_IGLD85` conversion is required, and is performed, at **every** Great Lakes level — L1 and L2 are not conversion-free as this clause originally assumed. The T8.11a conversion pipeline (plain `pyproj`, pointed at NOAA's PROJ data directory — see below) is retargeted to this pair; it is generic to any PROJ-published vertical transform, so only the source/target CRS pair changes for the Great Lakes branch. ~~**Whether NOAA's grid set covers this specific transform has not been verified** — flagged as a check to run, not assumed true.~~ **Verified 2026-07-27** empirically against the staged VDatum grids on host `librewxr`, using `pyproj` 3.7.0 against NOAA's own `proj.db` (CRS codes read directly from `proj.db`, not guessed: `NOAA:1759` = `NAD83(2011) + LWD_IGLD85 (nwldatum_4.7.0_20240621) height`; `NOAA:1758` = the plain IGLD85 sibling):

  | point | separation |
  |---|---|
  | Whiting, IN (41.680, -87.470) | -176.1036 m |
  | Calumet Harbor (41.730, -87.538) | -176.1039 m |
  | Lake Michigan mid-south (42.000, -87.200) | -176.0995 m |
  | Lake Erie mid (41.900, -81.500) | -173.4996 m |

  These match NOAA's published Low Water Datum plane elevations (176.0 m Michigan–Huron, 173.5 m Erie) — a
  result the C-96b ballpark-no-op failure mode could not produce, since that failure returns exactly 0.0. Ocean
  control unchanged at -0.8274 m. NOAA's grid set does cover the transform.
- **Runtime parity, same requirement as the WW3 boundary-criterion ruling (C-99).** Whichever code path selects a level's datum at runtime must route Great Lakes levels to `LWD_IGLD85` and ocean levels to `LMSL` — not only a config-time or setup-time diagnostic.

**What this does not change.** L1 remains ETOPO 2022 for ocean domains per the existing 2026-07-26 ruling. This is additive: it defines the Great Lakes branch the original "NOW — United States" text did not have. No task status is marked complete by this amendment — implementation of the Great Lakes branch was in flight in the marine repo at the time this amendment was recorded.

~~Library: **`vyperdatum`** (`noaa-ocs-hydrography`) in preference to `coastalmodeling-vdatum`. Both are open and grid-capable, but `coastalmodeling-vdatum` hardcodes NOAA S3 paths in `_path.py` with no configurable base directory, whereas `vyperdatum` resolves grids via the `VYPER_GRIDS` environment variable and transforms through PROJ. That difference is what makes adding a jurisdiction a tweak rather than a fork.~~

**Amended 2026-07-26 (operator ruling, reversing the library choice above the same day it was written).** T8.11a's proof-of-transform (`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` T8.11a STATUS) found that `vyperdatum`'s contribution is NOAA's `proj.db` plus its grid set — the vertical step itself is one `pyproj` call between compound CRSs, and `pyproj` is already a marine dependency. Installing `vyperdatum` for that would additionally require **GDAL, which is not on librewxr** (`vyperdatum/__init__.py` imports `osgeo.gdal` at package import, pulling in geopandas, pyarrow, pyogrio, h5py, laspy, lxml, networkx for BAG/LAS/parquet handling this system does not do), and it mutates `PROJ_DEBUG`, `PROJ_NETWORK`, and `PROJ_DATA` as process-wide environment variables at import — unacceptable inside a long-lived service process sharing `pyproj` with other code (`docs/planning/MARINE-SEP-CONCERNS.md` C-96a). Shown this evidence, the operator approved dropping `vyperdatum` in favour of the NOAA grid set accessed through plain `pyproj` directly. **Library: `pyproj`, pointed at NOAA's VDatum PROJ data directory (`proj.db` + separation grid TIFFs) via `pyproj.datadir.set_data_dir()`.** No new Python package is added for this capability. NOAA's desktop VDatum application remains **not** a candidate: distributed without source, and its terms of use prohibit reverse engineering.

**Amended 2026-07-26 (operator ruling, same day) — `pyproj` version pin.** NOAA's `proj.db` is database layout 1.3. PROJ 9.5+ (`pyproj>=3.7.1`) requires layout 1.4 and refuses to open it — but the refusal is only a `UserWarning`, after which `pyproj` silently falls back to its own bundled database, the `NOAA` authority is simply absent, and a NAVD 88 → LMSL conversion resolves to a ballpark no-op: a 0.0 m offset wearing the appearance of a conversion (`docs/planning/MARINE-SEP-CONCERNS.md` C-96b). Measured on librewxr: `pyproj` 3.6.1 and 3.7.0 load the NOAA authority; 3.7.1 and 3.7.2 do not. The operator approved pinning marine to `pyproj==3.7.0` as a result — a downgrade of an existing shared dependency, accepted specifically because the alternative (a version bump reintroducing a silent zero offset) is the defect this ADR exists to remove. The implementing code additionally checks for the NOAA authority and refuses at runtime if it is absent or the resolved operation is ballpark, so a future bump cannot reintroduce the failure quietly — but the pin is what prevents it happening in the first place.

**LATER — worldwide.** Adding a jurisdiction is a deliberate per-market code change, not per-install configuration. Each requires: that jurisdiction's **geoid** model (orthometric↔ellipsoid; OSGM15 for the UK where the US uses G2018/xGEOID20B), its **tidal separation** grids (ellipsoid↔chart datum), a **PROJ pipeline** declaring its datum pairs (LAT/Chart Datum rather than MLLW), a jurisdiction detector, and licensing clearance.

The surfaces already exist as authority-published models, so this is integration rather than research:

| Authority | Model | Coverage | Stated accuracy (1σ) |
|---|---|---|---|
| NOAA | VDatum | US | — |
| UKHO | VORF | UK + Ireland | ±10 cm inshore, ±15 cm offshore |
| SHOM | BATHYELLI | France | — |
| CHS | CCVD/CCDCW | Canada | ±10 cm |
| AHS | AusCoastVDT | Australia | — |
| NL/BE | NEVREF | Netherlands, Belgium | — |

For coastlines with no authority model, tidal datums can be derived from a global tide model (FES2022 via PyFES, or TPXO) — the same method applied globally, at lower nearshore accuracy. That is the fallback, not the primary.

**Prefer selecting a source already on the target datum over converting one (operator direction, 2026-07-26).** Conversion machinery is a last resort for regions that leave no choice — which, counter-intuitively, is the **United States**: its regional DEMs are overwhelmingly NAVD 88 (665 of 1000 catalogue rasters) with no MSL equivalent at 10 m resolution.

Europe is the opposite case. The **EMODnet Bathymetry DTM (2024)** publishes the same coverage in **both LAT and MSL** — the ESRI ASCII tiles are downloadable in either — at 1/16 × 1/16 arc-minute (≈115 m), under **CC BY 4.0** (redistributable with attribution, unlike VORF's UKHO licensing). Its regions are geographic rather than political, so the **British Isles are covered** (Greater North Sea, English Channel, Celtic Seas). For European L1/L2 the correct action is therefore to *select the MSL product* and skip datum conversion entirely.

Residual gap: ≈115 m suits L2 (100 m) but not L3 (10 m), so a European L3 still needs a national high-resolution DEM, and those carry national datums — meaning the conversion path is needed at L3 only, not across the whole nest.

**That residual L3 gap may close without any jurisdiction work — filed as future research, not assumed.** Satellite-derived bathymetry calibrated against **ICESat-2 ATL03** is ellipsoid-referenced (ATL03 reports photon elevations relative to the WGS 84 ellipsoid), so ellipsoid → MSL is a **geoid model** (EGM2008, global and free) rather than a tidal separation grid. L3 could then be produced natively in MSL anywhere, making the per-jurisdiction machinery above a US-and-existing-DEM concern rather than the global architecture. Unresolved: accuracy (0.43–1.5 m RMSE) is comparable to the datum error being eliminated, the clarity-vs-morphology compositing tension, permanently turbid coasts, and whether this puts us in the data-supply business or ships as an operator-run pipeline. See [FUTURE-ENHANCEMENTS.md](../planning/FUTURE-ENHANCEMENTS.md) "Satellite-derived bathymetry (SDB) for the surf zone", update 2026-07-26.

**Licensing is the gate, not availability.** VDatum is public domain. VORF is UKHO-licensed; SHOM and AHS terms are unverified. A jurisdiction may therefore require the operator to supply their own licensed grids rather than us redistributing them.

**Implementation risk, recorded rather than hidden:** whether PROJ already carries a given jurisdiction's vertical pipelines, or we must define them, has not been verified hands-on. PROJ separation-grid downloads become a deployment dependency.

## Consequences

1. Two CO-OPS fetches per SWAN run (MLLW for display, DEM-native for SWAN). Cache keys include the datum so predictions in different datums are cached separately.

2. Bathymetry cache gains a `vertical_datum` field. Existing cache files without this field are treated as stale and re-downloaded on next run.

3. `TidePrediction` model gains a `datum` field. Display endpoint returns `"MLLW"`. SWAN pipeline receives the DEM-native datum internally.

4. ~~VDatum normalization code (`normalize_to_msl()` in `bathymetry_resolver.py`) is preserved but not called from `download_bathymetry_for_level()`. Kept for future edge cases.~~ **Superseded 2026-07-26:** `normalize_to_msl()` as written is not fit for use at all — it applies a single domain-centre offset to an entire grid. It is replaced by per-cell conversion through PROJ separation grids, not un-deferred as-is. `_query_vdatum_offset()` additionally returns 0.0 silently in two paths despite its docstring claiming otherwise (C-90b), which must be fixed or removed with it.

5. 34 UNKNOWN DEMs in `ncei_regional_dem_index.json` must be resolved before those areas are served. `find_best_dem()` skips DEMs with `"UNKNOWN"` datum.

6. Operator upload endpoint stops calling `normalize_to_msl()`. Records the operator-specified datum and uses it for CO-OPS matching.

## Out of Scope

- ~~Installing `coastalmodeling-vdatum` on production — deferred, not needed for v1.~~ ~~**Superseded 2026-07-26** — a VDatum-grid dependency (`vyperdatum`) is now in scope for the US; see "Grid-wise datum conversion" above.~~ **Amended 2026-07-26 (operator ruling, same day):** no new VDatum library is installed at all. The NOAA grid set is read directly through `pyproj` (already a marine dependency, pinned to `==3.7.0`); `vyperdatum` was evaluated and rejected. See "Grid-wise datum conversion" above.
- International datum support (LAT, CD) — still future, but no longer open-ended: the per-jurisdiction path, the authority models, and the four integration steps are enumerated above.
- ~~Grid-based VDatum conversion — the code exists but is not called; not deleted, not enhanced.~~ **Superseded 2026-07-26** — grid-based conversion is now the mechanism that establishes the common datum. The single-point code that stood in for it is not what gets enabled.
- Authoring our own separation grids for a jurisdiction that has none. The GTX format is documented and horizontal registration to NAD 83 (2011) is a routine reprojection, so the plumbing is not the barrier — but producing the surfaces needs a validated regional tide model plus a geoid, which is a modelling project per coastline. Use an authority model, or the global-tide-model fallback.
- Changing the public display datum from MLLW.

## Acceptance Criteria

1. SWAN WLEVEL uses predictions in the DEM's native datum (not hardcoded MLLW).
2. Display endpoint (`/api/v1/tides`) still uses MLLW — no change.
3. Bathymetry cache files contain a `vertical_datum` field.
4. ~~`normalize_to_msl()` is not called from `download_bathymetry_for_level()`.~~ **Replaced 2026-07-26:** bathymetry is converted to LMSL **per cell** via PROJ separation grids. No single-offset conversion is applied to a grid anywhere, and a code path that would do so is a defect.
5. CO-OPS datum fetch failure produces ERROR, not silent fallback to 0.0m.
6. `TidePrediction` model has a `datum` field.
7. Zero DEMs in the index have `"UNKNOWN"` datum.
8. All test baselines hold.

Added 2026-07-26:

9. Every SWAN level's bathymetry datum is verified to agree before a run; disagreement refuses rather than stamping one level's datum on another.
10. No datum label is invented by us. A datum is either published by the source (the NCEI mosaic catalogue's `VerticalDatum` field, an operator declaration, or a pinned raster) or the source is unusable. `UNKNOWN_CRM` no longer exists.
11. Outside the coverage of an available separation model, the install refuses rather than running on mixed datums.

## Implementation

See `docs/planning/SWAN-DATUM-PLAN.md` (Phases 1–7).
