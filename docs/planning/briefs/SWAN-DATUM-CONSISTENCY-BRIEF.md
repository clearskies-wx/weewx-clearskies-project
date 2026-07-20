# SWAN Vertical Datum Consistency — Research Brief

**Status:** RESEARCH IN PROGRESS
**Created:** 2026-07-19
**Origin:** Post-stability-plan audit discovered that SWAN bathymetry (BOTTOM) and water level (WLEVEL) inputs are on different vertical datums, and the code intended to normalize them is silently failing in production.

---

## §1 — What SWAN Requires

SWAN does not mandate a specific vertical datum. From the SWAN User Manual v41.51 ([Input grids and data, node26](https://swanmodel.sourceforge.io/online_doc/swanuse/node26.html)):

- **BOTTOM:** "bottom level positive downward relative to an **arbitrary horizontal datum level**"
- **WLEV (READINP):** "water level positive upward relative to the **same datum level as used in option BOTTOM**"

SWAN computes total water depth by combining BOTTOM depth and WLEVEL elevation. If these two inputs are on different datums, every depth-dependent calculation is wrong: refraction, shoaling, breaking (Hs/d ≈ γ), bottom friction, triad interactions.

**The requirement is datum consistency, not any specific datum.** NAVD88, MLLW, MSL — any datum works, as long as BOTTOM and WLEVEL both use the same one.

---

## §2 — What We Currently Have (Production State, 2026-07-19)

### §2.1 — Bathymetry (BOTTOM)

| Property | Value |
|----------|-------|
| Source | NCEI Orange County regional DEM (`orange_county_13_navd88_2015.nc`) via OPeNDAP |
| Native datum | **NAVD88** |
| Datum correction applied | **None** (0.0m offset — see §3) |
| Datum as fed to SWAN | **NAVD88** (uncorrected) |
| Cache file | `/etc/weewx-clearskies/swan_bathymetry_L{1,2}.json`, `swan_bathymetry_L3_{hash}.json` |
| Cache has datum metadata | No — only `"source": "ncei_regional"`, no `vertical_datum` or `datum_offset` fields |

The DEM index (`ncei_regional_dem_index.json`) correctly records `"vertical_datum": "NAVD88"` for this DEM.

### §2.2 — Water Level (WLEVEL)

| Property | Value |
|----------|-------|
| Source | CO-OPS Data API, `product=predictions` |
| Request datum parameter | `"datum": "MLLW"` (hardcoded at `coops.py:484`) |
| Native datum of response | **MLLW** (Mean Lower Low Water) |
| Datum as fed to SWAN | **MLLW** (no conversion applied anywhere in the pipeline) |
| CO-OPS station | 9410660 (Los Angeles) |

The CO-OPS predictions are fetched with `datum=MLLW` and the raw height values flow through unchanged:
1. `coops.py:_fetch_predictions()` → `TidePrediction` objects with `height` in MLLW
2. `swan.py:run_all_spots()` converts `TidePrediction` to plain dicts `{"time": ..., "height": ...}`
3. `swan_runner.py:_write_wlevel_txt()` writes the height values directly to `WLEVEL.txt`
4. No datum conversion happens at any step

The docstring at `swan_runner.py:598` claims the values are "positive up from MSL" — this is wrong. They are positive up from MLLW.

### §2.3 — The Datum Mismatch

At CO-OPS station 9410660 (Los Angeles), the published datum elevations relative to STND (station datum, feet) are:

| Datum | Elevation (ft) | Elevation (m) |
|-------|----------------|---------------|
| STND | 0.000 | 0.000 |
| MLLW | 3.830 | 1.167 |
| NAVD88 | 4.030 | 1.228 |
| MSL | 6.650 | 2.027 |

**NAVD88 − MLLW = 0.200 ft = 0.061 m**

This means our BOTTOM (NAVD88) and our WLEVEL (MLLW) are offset by ~6 cm at HB Pier. SWAN sees a water level that is 6 cm lower than it should be relative to the bathymetry.

For context, at other US locations this offset can be much larger:

| Location | Station | NAVD88 − MLLW (m) |
|----------|---------|-------------------|
| Los Angeles, CA | 9410660 | +0.061 |
| Sandy Hook, NJ | 8531680 | ~+0.26 |
| Key West, FL | 8724580 | ~+0.14 |

The sign means NAVD88 is higher than MLLW. So SWAN thinks the water is 6 cm shallower than it actually is (at LA). At locations with larger offsets, the error grows proportionally.

### §2.4 — The Failed VDatum Normalization

The code was designed to convert bathymetry from the DEM's native datum to MSL via the NOAA VDatum REST API or the `coastalmodeling-vdatum` library. In production, **both paths fail:**

1. **`coastalmodeling-vdatum` library:** Not installed on production. `ModuleNotFoundError` on import → falls through to REST API.

2. **VDatum REST API:** Returns HTTP 200 but body contains `{"errorCode": 412, "message": "Uncaught error, please contact NOAA VDatum Program Support team."}`. The query point (33.59, -118.07 for L1) may be too far offshore for VDatum's tidal datum grids. The error is swallowed and the code falls back to 0.0m offset.

**Production log evidence (2026-07-19 08:47:34 PDT):**
```
VDatum API unavailable for datum='NAVD88' at (33.59, -118.07) region='contiguous'
— no datum correction applied. Bathymetry may have up to ~1m vertical bias.
...
Applied NAVD88 to MSL offset: 0.000m via VDatum at (33.59, -118.07)
```

The WARNING is logged but the run proceeds with uncorrected bathymetry. Then the INFO line misleadingly logs `offset: 0.000m` as if the conversion succeeded.

### §2.5 — Even If VDatum Worked, There Would Still Be a Mismatch

The VDatum code converts bathymetry to **MSL**. But the CO-OPS predictions are in **MLLW**, not MSL. At LA station 9410660:

- MSL − MLLW = 6.65 − 3.83 = 2.82 ft = **0.860 m**

If VDatum were working, we would have:
- BOTTOM in MSL
- WLEVEL in MLLW
- Mismatch: **0.860 m** (much worse than the current 0.061 m NAVD88-vs-MLLW mismatch)

So the VDatum "fix" would actually make the datum inconsistency **worse**, not better — it would convert the bathymetry away from the water level datum instead of toward it.

---

## §3 — What Conversion Is Actually Needed

### §3.1 — The Correct Approach: Match Datums, Don't Force MSL

SWAN needs BOTTOM and WLEVEL on the **same** datum. There are two ways to achieve this:

**Option A — Convert WLEVEL to match BOTTOM's datum:**
- Keep bathymetry in its native datum (NAVD88 for the Orange County DEM)
- Request CO-OPS predictions in NAVD88 instead of MLLW: `"datum": "NAVD88"`
- Both inputs on NAVD88. No VDatum needed.

**Option B — Convert BOTTOM to match WLEVEL's datum:**
- Keep CO-OPS predictions in MLLW
- Convert bathymetry from NAVD88 to MLLW using VDatum
- Both inputs on MLLW. Requires VDatum.

**Option C — Convert both to MSL (current design, but broken):**
- Convert bathymetry from NAVD88 to MSL via VDatum
- Change CO-OPS request to `"datum": "MSL"` (currently requests MLLW)
- Both inputs on MSL. Requires VDatum AND a CO-OPS request change.
- Note: the current code only does half of this (converts bathymetry, doesn't change the CO-OPS datum)

### §3.2 — Option A Is Simplest and Most Reliable

CO-OPS supports `datum=NAVD88` as a request parameter for predictions. The NCEI DEM is already in NAVD88. Changing one string in the CO-OPS fetch eliminates the VDatum dependency entirely for NAVD88 DEMs.

**Complications for non-NAVD88 DEMs:**
- Some NCEI DEMs use MHW, MHHW, or MLLW datums
- CO-OPS supports these as request parameters: `NAVD88`, `MSL`, `MLLW`, `MHW`, `MHHW`, `MLW`, `MTL`, `DTL`, `STND`, `IGLD`, `LMSL`, `LWD`, `NGVD`
- For any DEM datum that CO-OPS supports directly, we can request predictions in that datum — no VDatum needed
- For exotic datums CO-OPS doesn't support, VDatum conversion of one input would be needed (rare/unlikely)

**Great Lakes:** USGS Great Lakes DEMs use IGLD85. CO-OPS supports `datum=IGLD` for Great Lakes stations. Same approach works.

### §3.3 — The Single-Point Sampling Problem

**The current code's single-point approach is wrong as a general method.** Converting a 2D grid between vertical datums requires per-point (or per-cell) conversion using the actual VDatum separation raster surfaces, not a single center-point query applied uniformly to every cell. NOAA's VDatum tidal datum grids exist at ~100m resolution (~0.001°) specifically because the offsets are spatially varying. A single-point query discards that spatial structure.

**Where the error matters depends on the datums and location:**

- **NAVD88-to-MSL (the TSS component):** On the open straight SoCal coast, this offset varies slowly (~0.1-0.3 mm/km). A single-point query is coincidentally adequate at our grid scales for this specific datum pair at this specific location — but this is not a validation of the approach; it's a coincidence of geography.

- **Tidal datums (MLLW, MHW, MHHW) relative to NAVD88 or each other:** These vary more sharply, and the variation is largest in the **cross-shore direction** — exactly the direction our grids extend. Tidal dynamics change fundamentally between the surf zone (shallow, breaking, bottom interaction) and open water (deep, no bottom interaction). The VDatum FAQ explicitly notes: "tidal datums can vary locally due to variable bathymetry, the presence of tidal flats, river interactions, presence of barrier islands." The Santa Ana River mouth is ~2 km from HB Pier — exactly the kind of feature that creates local tidal datum variation within a single L3 grid extent.

- **Our actual grid scales are not "small areas":**
  - **L3:** ~2.3 km cross-shore × ~0.5 km alongshore at 10 m resolution (~230 × 50 cells). A single center-point query gives a value correct at one point in the middle, and increasingly wrong toward the beach and toward open water — the two extremes where tidal datum offsets diverge most.
  - **L2:** ~5+ km cross-shore (shore to 30 m depth) at 100 m resolution. Even larger spatial extent.
  - **L1:** Shore to shelf edge (~20+ km) at 1 km resolution.

  The pier itself is ~500 m long. A single-point query might be adequate for the pier's footprint. But L3 extends 4-5× further than the pier, and L2 extends 10×+ further. These are not pier-scale grids.

- **At other operator locations:** An operator near an inlet, harbor, or river mouth could see tidal datum variations of centimeters across a 2.5 km grid. A single center-point query would produce a systematic depth bias that varies across the grid — largest at the edges, exactly where the break point and scoring happen.

### §3.4 — Why This Matters for Wave Modeling

SWAN's depth-dependent physics are highly sensitive to small depth errors in shallow water:

- **Breaking criterion:** Hs/d ≈ γ (0.73). A 5 cm depth error at 1.5 m depth shifts the break point by ~1 grid cell (10 m). A 20 cm error shifts it by ~3 cells (30 m). Breaking controls QB, DISSURF, and the entire surf forecast scoring chain.
- **Refraction:** Shallow-water wave speed is √(gd). A depth error produces a refraction error that compounds along the entire cross-shore propagation path — waves arriving at the break point have the wrong direction and energy distribution.
- **Shoaling:** Wave height amplification scales as (d_deep/d_shallow)^(1/4). A systematic depth bias across the grid distorts the shoaling profile and shifts where energy concentrates.
- **Triad interactions:** Triad wave-wave interactions (activated at all levels) are strongly depth-dependent. A depth error at the seaward end of the surf zone produces a different spectral shape at the break point.

These effects are nonlinear and cumulative. A spatially varying datum error (correct at the grid center, increasingly wrong toward the edges) does not average out — it distorts the wave field in a direction-dependent way. The break point and scoring happen at the shallow end of the grid, which is the end furthest from the center-point query and therefore has the largest datum error.

**Single-point datum shortcuts are not acceptable for wave modeling grids at this scale.** The spatial extent of our grids (2.3 km cross-shore for L3, 5+ km for L2, 20+ km for L1) spans fundamentally different tidal regimes, and the physics amplify depth errors rather than smooth them.

### §3.5 — The Correct Way to Convert a Grid Between Datums

When grid-based datum conversion IS required (e.g., for edge-case datums CO-OPS doesn't support, or for the CRM fallback path), it must be done as a proper per-cell operation using the VDatum separation raster surfaces:

**Method 1 — `coastalmodeling-vdatum` grid mode (preferred):**
The `coastalmodeling-vdatum` library supports grid-based transforms via integration with OCSMesh. It uses NOAA's official VDatum separation GeoTIFF grids (~100 m resolution) through PROJ. For a 2D bathymetry grid:
1. Build a mesh or point array from the grid coordinates
2. Call the library's batch transform to convert all points from the source datum to the target datum
3. Each grid cell receives its own spatially-correct offset
4. Works offline once the separation grids are downloaded

**Method 2 — VDatum REST API multi-point (fallback):**
If the offline library is unavailable, query the VDatum REST API at a set of grid points (e.g., every 10th cell, or at the grid corners and edges) and bilinearly interpolate the offsets across the full grid. This is slower but still spatially correct. Rate-limit at 1 request/second. For a 230×50 L3 grid sampled every 10th cell, that's ~115 queries (~2 minutes).

**Method 3 — Single-point query (PROHIBITED for production grids):**
A single center-point query applied uniformly is a shortcut that produces depth errors that grow toward the grid edges — exactly where the surf zone physics happen. This approach is only acceptable for diagnostic/debugging purposes on grids smaller than ~500 m (pier-scale), never for production SWAN runs.

**What the code must do on conversion failure:**
If both VDatum methods fail, the conversion must fail explicitly — not fall back to 0.0 m offset. Serving a bathymetry grid with an unknown datum error to SWAN produces scientifically meaningless output. The run should either:
- Fall back to a different data source whose datum IS known (e.g., CRM in MSL with CO-OPS in MSL)
- Abort the level and log an ERROR that the operator can see
- Never silently proceed with uncorrected data

### §3.6 — Option A Still Sidesteps Conversion Entirely for the Common Case

All of §3.4-§3.5 applies when grid conversion is needed. But for the most common case — NAVD88 DEMs on the US coast — **Option A (§3.2) eliminates the conversion entirely:**

- Keep bathymetry in its native datum (no conversion, no VDatum, no spatial error)
- Request CO-OPS predictions in the same native datum
- Both inputs are exact in their own right, and they match

This is not a shortcut — it is the correct approach. The bathymetry is in its native datum at every grid point (inherently spatially correct). The water level is in the same datum at the station (inherently correct, applied uniformly — which is a separate, accepted simplification for tidal uniformity across the domain).

Option A should be the primary path. Grid-based VDatum conversion (§3.5 Methods 1-2) is the fallback for edge-case datums that CO-OPS doesn't support as a request parameter.

---

## §4 — Is Our Code Doing It Correctly Now?

**No. There are four bugs:**

### Bug 1: Datum mismatch between BOTTOM and WLEVEL
- BOTTOM is in NAVD88 (DEM native, uncorrected)
- WLEVEL is in MLLW (CO-OPS hardcoded)
- Current error at HB Pier: ~6 cm (NAVD88 − MLLW = 0.061m)
- At other US locations: up to ~26 cm

### Bug 2: VDatum normalization is silently failing
- `coastalmodeling-vdatum` not installed on production
- VDatum REST API returning 412 errors for the query points
- Code falls back to 0.0m offset and logs a WARNING, but proceeds as if nothing is wrong
- Cached bathymetry files contain no record that datum correction was skipped

### Bug 3: Even if VDatum worked, WLEVEL datum would still be wrong
- The VDatum code converts bathymetry to MSL
- But CO-OPS predictions are fetched in MLLW
- This would create a 0.86m mismatch at HB Pier (worse than the current 0.06m)
- The design assumed both inputs would be in MSL, but only implemented the bathymetry side

### Bug 4: Misleading logging
- `"Applied NAVD88 to MSL offset: 0.000m"` logs at INFO level even when VDatum failed
- Reads as if the conversion succeeded with a zero offset, not that it failed
- The WARNING with the actual error is logged separately and easy to miss in noisy logs

### Bug 5: Docstring claims MSL when values are MLLW
- `swan_runner.py:598`: "positive up from MSL" — actually MLLW
- Agents reading this code would believe the datum is MSL

---

## §5 — Impact Assessment

### §5.1 — Current Impact at HB Pier (NAVD88 vs MLLW, 0.061m)

At 2m water depth, a 6 cm error is a 3% depth error. SWAN's breaking criterion shifts the break point by roughly one grid cell (10m). This is within the noise of other model uncertainties (wind forcing, bathymetry resolution). **The current forecast is plausible despite the bug** — but only because the NAVD88-MLLW offset happens to be small at this location.

### §5.2 — Impact If VDatum Had Worked (MSL vs MLLW, 0.860m)

At 2m water depth, a 86 cm error is a 43% depth error. SWAN would produce physically meaningless results. **The VDatum failure is accidentally preventing a much worse outcome.**

### §5.3 — Impact at Other US Locations

The NAVD88-MLLW offset varies dramatically by location. An operator in New Jersey (NAVD88-MLLW ≈ 0.26m) would have a 13% depth error at 2m — significant enough to shift break points by 2-3 grid cells and affect scoring accuracy.

---

## §6 — Public Display Datum vs SWAN Input Datum

### §6.1 — Public tide display must use MLLW

MLLW is the standard chart datum for the United States. NOAA's tide predictions, nautical charts, and all major tide apps (Surfline, Windy, etc.) display heights relative to MLLW. When a visitor sees "High 5.2 ft" on our tide chart and checks NOAA's website, the numbers must match.

Our dashboard currently displays tide data fetched with `datum=MLLW` and does not show the datum name anywhere on the chart. This is correct — MLLW is the assumed convention for US tide displays, and labeling it would add noise for visitors who don't know what MLLW means.

If we switched the display to NAVD88, our tide values would be offset by ~0.06 m (0.2 ft) at HB Pier. Visitors comparing to any other tide source would see a mismatch. At locations with larger MLLW-NAVD88 offsets (e.g., NJ at ~0.26 m / 0.85 ft), the discrepancy would be clearly noticeable.

**Rule: The public-facing tide display datum is MLLW. This does not change.**

### §6.2 — SWAN needs a different datum than the display

The SWAN pipeline needs tide predictions in whatever datum the bathymetry DEM uses (NAVD88 for the Orange County DEM). The public display needs MLLW. These are two different consumers with two different requirements.

Currently, one CO-OPS fetch (`datum=MLLW`) serves both purposes. The fix must separate them:

- **Dashboard tide endpoint (`/api/v1/tides`):** Continues to fetch and serve in MLLW. No change.
- **SWAN WLEVEL pipeline (`swan.py` → `swan_runner.py`):** Fetches (or converts to) the DEM's native datum for SWAN input. This is internal — never displayed to visitors.

The SWAN pipeline already makes its own call path through `swan.py:run_all_spots()` which fetches tide predictions separately from the display endpoint. The fix is to change the datum parameter on that fetch, not to change the display endpoint.

### §6.3 — International operators

Outside the US, chart datums vary:
- **UK, Australia, most of the world:** Lowest Astronomical Tide (LAT)
- **US:** MLLW
- **Some European countries:** MSL or local chart datum

CO-OPS only serves US stations, so this is not an immediate concern. If/when international tide sources are added, the display datum should follow the local convention. The SWAN datum-matching logic (use the DEM's native datum) is location-independent.

---

## §7 — Recommended Fix (Pending User Decision)

**Primary path: match the SWAN CO-OPS request datum to the DEM's native datum.**

1. `find_best_dem()` already returns the DEM's `vertical_datum` (e.g., `"NAVD88"`)
2. In the SWAN pipeline's tide fetch (separate from the display endpoint), pass the DEM's datum to CO-OPS: `"datum": dem_datum`
3. Remove the VDatum normalization call from `download_bathymetry_for_level()` — bathymetry stays in its native datum
4. Remove the 0.0m fallback path in `_query_vdatum_offset()` — if datum matching is needed and can't be done, the run should fail explicitly, not proceed with bogus data
5. Purge cached bathymetry files (they have no datum metadata; fresh downloads will be clean)
6. Fix the docstring at `swan_runner.py:598`
7. The display endpoint (`/api/v1/tides`) stays MLLW — no change (§6.1)

**Edge cases to handle:**
- CO-OPS doesn't support the DEM's datum → fall back to MSL for both (convert bathymetry via VDatum using proper grid-based conversion per §3.5, request CO-OPS in MSL). This is the rare case where VDatum is actually needed.
- No CO-OPS station configured → WLEVEL is not emitted (current behavior, no datum concern)
- CRM fallback bathymetry (`DEM_all`) → need to verify its datum (likely MSL), then request CO-OPS in that datum

**What to do with VDatum code:**
- Keep it for the edge cases above and for the Stage 2 analytic setup computation
- If grid-based VDatum conversion is needed, it must use the `coastalmodeling-vdatum` grid mode or multi-point REST queries — never a single center-point query (§3.5)
- Fix the 412 error (likely offshore query point — use a coastal point instead)
- Install `coastalmodeling-vdatum` on production as a belt-and-suspenders measure
- Remove the 0.0m silent fallback — make failure explicit

---

## §8 — Datum Architecture (Broader Design Direction)

### §8.1 — Datum as first-class metadata

Every data product the API handles — bathymetry grids, water level observations, tide predictions, current fields — must carry its vertical datum as metadata. Consumers pick the datum they need, or receive the datum tag so they know what they're working with.

Current state of datum tracking in the codebase:

| Data product | Datum tracked? | Actual datum |
|---|---|---|
| `TidePrediction` model | **No** — no datum field | MLLW (hardcoded at fetch) |
| `WaterLevel` model | **Yes** — `datum: str` field | "MLLW" (hardcoded at line 400) |
| Bathymetry cache JSON | **No** — only `"source"` field | DEM native (NAVD88 for OC DEM), uncorrected |
| DEM index entry | **Yes** — `"vertical_datum"` | Correct per DEM |
| WLEVEL.txt (SWAN input) | **No** — raw numbers, no header | MLLW (from CO-OPS, undocumented) |

**Target state:** Every data product carries `datum` as a string field. Bathymetry cache records the datum. WLEVEL pipeline knows and logs the datum. The `TidePrediction` model gains a `datum` field.

### §8.2 — Primary strategy: match at source, avoid conversion

When a data source supports multiple datums as request parameters, fetch in the datum you need. Two cheap HTTP requests are always preferable to one request plus a local datum conversion that can fail, introduce spatial error, and add computational overhead.

**CO-OPS supported datums (verified):** NAVD88, MSL, MLLW, MHW, MHHW, MLW, MTL, DTL, STND, IGLD, LMSL, LWD, NGVD.

This means for any NCEI DEM using NAVD88, MHW, MHHW, MLLW, or MSL — CO-OPS can provide predictions directly in that datum. No conversion needed.

**The dual-fetch pattern:**
1. Dashboard display: `datum=MLLW` (US chart standard)
2. SWAN WLEVEL: `datum={DEM's vertical_datum}` (matching bathymetry)

Both fetches hit the same CO-OPS API with different datum parameters. CO-OPS does the conversion server-side using their authoritative tidal datum models — more accurate and more reliable than any local conversion we could do.

### §8.3 — Fallback: CMVD for cases where source-matching isn't possible

When the data source doesn't support the needed datum (operator-uploaded bathymetry, international DEMs, exotic datums), local conversion is needed. The right tool is `coastalmodeling-vdatum` (CMVD).

**The VDatum landscape (three different things):**

| Tool | What it is | Suitable for us? |
|---|---|---|
| **VDatum Desktop** | Java GUI + CLI, ~95 MB software + ~1 GB grid data. Designed for desktop GIS. | **No** — Java, huge, GUI-oriented, not suitable for headless server |
| **VDatum REST API** | Single-point web service at `vdatum.noaa.gov`. Currently returning 412 errors for our queries. | **No for grids** — single-point only, rate-limited, flaky. Acceptable for one-off point checks. |
| **`coastalmodeling-vdatum` (CMVD)** | Python library (`pip install coastalmodeling-vdatum`). NOAA Ocean Modeling team (Cassalho et al. 2026). Offline mode with local GeoTIFF grids. Supports mesh/grid transforms via OCSMesh. | **Yes** — right tool for grid-based datum conversion when needed |

**CMVD details:**
- Datums supported: NAVD88, MLLW, MLW, MHW, MHHW, LMSL, IGLD85, LWD, xGEOID20B
- Online mode: calls VDatum REST API under the hood (same flaky endpoint)
- Offline mode: uses locally downloaded GeoTIFF separation grids from NOAA S3. Works without internet once grids are cached. Grid size TBD — likely a few hundred MB per region, not the full 1 GB.
- Grid/mesh support: converts entire bathymetry grids per-cell, not single-point
- Sign convention: expects positive overland, negative underwater (same as CUDEM)
- Already in our `pyproject.toml` but not installed on production

**When CMVD is needed:**
- Operator uploads bathymetry in a datum CO-OPS doesn't support
- Operator uploads bathymetry in a datum different from their nearest CO-OPS station's available datums
- International DEMs with non-US datums (future)
- Any edge case where source-matching can't work

**When CMVD is NOT needed (and should not be used):**
- CO-OPS can provide predictions in the DEM's datum directly (the common US case)
- Both data sources are already in the same datum

### §8.4 — Operator responsibility for uploaded data

For operator-uploaded bathymetry (Phase 24 of SWAN-FIXES-PLAN), the operator specifies the datum via a dropdown (NAVD88, MLLW, MSL, MHW, LAT, etc.). Options:

**Option A — Operator matches to their CO-OPS station's datums:**
Tell the operator: "Your bathymetry and tide data must be in the same vertical datum for SWAN. Your nearest CO-OPS station (9410660) supports NAVD88, MLLW, MSL, MHW. Upload bathymetry in one of these datums." We fetch CO-OPS predictions in whatever datum they chose. No conversion.

**Option B — We convert for them using CMVD:**
Accept bathymetry in any supported datum. Use CMVD to convert the entire grid to match the CO-OPS fetch datum. More user-friendly, more engineering complexity.

**Option C — Hybrid:**
Accept any datum. If it matches a CO-OPS-supported datum, fetch predictions in that datum (no conversion). If not, use CMVD to convert the bathymetry grid. Transparent to the operator.

Option C is the most robust but requires CMVD to be installed and working. Option A is simplest for v1.

### §8.5 — International extensibility

The datum tracking system must not be US-centric:
- Datum fields are free-form strings, not a US-specific enum
- LAT (Lowest Astronomical Tide) is the international chart standard — used by UK, Australia, most of the world
- European countries use various local chart datums
- Different regions have different separation grids (CMVD only covers US waters currently)

For v1 (US only, CO-OPS only), the match-at-source strategy covers everything. International expansion will need:
- International tide data sources (not CO-OPS) — each with their own datum support
- International bathymetry sources — with different datum conventions
- Potentially different conversion tools (CMVD is US-only; international operators may need pyproj + local geoid models)

The architecture (datum as metadata + match at source + convert as fallback) is location-independent. Only the specific tools and data sources change per region.

---

## §9 — Datum Compatibility Audit: Do We Even Need Conversion?

The question: can we serve all US coastal waters (including territories) by matching datums at source, without ever needing local conversion software?

### §9.1 — Data source datum inventory

**NCEI Regional DEMs (199 indexed, our primary automated source):**

| Datum | DEMs | CO-OPS supports? | Coverage |
|-------|------|-------------------|----------|
| MHW | 80 | **YES** | Gulf, Atlantic, Pacific, islands |
| MHHW | 50 | **YES** | Pacific coast, NE coast |
| UNKNOWN | 34 | **N/A** | Mixed — see below |
| NAVD88 | 32 | **YES** | Scattered nationwide |
| MSL | 3 | **YES** | Islands, Pacific |

**165 of 199 DEMs (83%) have a known datum that CO-OPS directly supports.** No conversion needed for these.

**34 DEMs have UNKNOWN datum.** The `.das` OPeNDAP metadata for these files does not include a `geospatial_bounds_vertical_crs` attribute. These include several important SoCal DEMs (san_pedro_bay, santa_monica_bay, san_diego_bay, monterey_bay), Gulf coast DEMs, and Pacific island DEMs. The datum IS encoded in these files somewhere (the data had to be compiled against a datum), but the metadata doesn't expose it. This is a gap in the index builder — the actual datum would need to be determined from NCEI documentation per DEM, not from the `.das` endpoint.

For the UNKNOWN DEMs: these are typically newer "tsunami-inundation" style DEMs (post-2017, with the `_P/_G/_N/_S` naming convention). NCEI's documentation for this generation of DEMs typically states MHW as the vertical datum, but this must be verified per file.

**CRM / `DEM_all` (our fallback for areas without regional DEM coverage):**
The NCEI `DEM_all` ImageServer is a mosaic of DEMs from multiple sources with **mixed vertical datums**. The ArcGIS service exposes a `VerticalDatum` attribute field per pixel, but does not normalize to a single datum. NCEI's own documentation states: "source elevation data were not converted to a common vertical datum due to the large cell size." This means the CRM fallback has **no guaranteed datum** — a query might return data in MSL, MLLW, MHW, or NAVD88 depending on which source DEM covers that location. **This is a known quality limitation of the coarse fallback — the CRM path is already degraded in resolution (~90m); the datum uncertainty is an additional reason to prefer regional DEMs whenever available.**

**USGS Great Lakes DEMs (Rohweder 2025):**
The Great Lakes DEMs are referenced to **NAVD88** (orthometric heights). IGLD85 uses dynamic heights — the difference is a few centimeters and varies spatially (requires NGS hydraulic corrector grids). CO-OPS Great Lakes stations support `datum=IGLD` and `datum=NAVD88`. **If the DEMs are in NAVD88, we request CO-OPS in NAVD88 — no conversion needed.** The IGLD85-vs-NAVD88 distinction is a subtlety (orthometric vs dynamic height) that matters for precision geodesy but produces <5 cm differences, within SWAN's depth uncertainty.

**USACE hydrographic survey data (likely operator-upload source):**
USACE surveys typically use **MLLW** or **NAVD88**. Both are directly supported by CO-OPS. An operator uploading USACE survey data would specify the datum (MLLW or NAVD88) and we'd fetch CO-OPS predictions in the same datum. **No conversion needed.**

### §9.2 — Coverage summary

| Source | Datum(s) | CO-OPS match? | Conversion needed? |
|--------|----------|---------------|-------------------|
| NCEI Regional (83% of DEMs) | NAVD88, MHW, MHHW, MSL | YES | **NO** |
| NCEI Regional (17% UNKNOWN) | Likely MHW (needs verification) | YES if MHW | **NO** (once verified) |
| CRM / DEM_all fallback | **Mixed / unknown** | **UNRELIABLE** | See note below |
| USGS Great Lakes | NAVD88 | YES | **NO** |
| USACE surveys (operator upload) | MLLW or NAVD88 | YES | **NO** |
| Operator GeoTIFF (unknown datum) | Operator-specified | YES (if in CO-OPS list) | **NO** (operator matches) |

### §9.3 — Conclusion: CMVD is not needed for v1 (with a caveat on CRM)

**Every automated bathymetry source we use — except the CRM fallback — has a known datum that CO-OPS directly supports.** The match-at-source strategy covers all cases where a regional DEM or Great Lakes DEM is available.

**The CRM fallback is the problem child.** Its datum is mixed/unknown, so we cannot reliably match it with CO-OPS. However, the CRM fallback is already degraded in resolution (~90m staircase data) and is only used when no regional DEM covers the area. For v1, we accept this limitation: CRM-sourced bathymetry has both resolution AND datum uncertainty, and the surf forecast quality is degraded accordingly. The coverage endpoint (Phase 22) already flags CRM-sourced areas as `"degraded"` quality. A datum warning should be added to that flag.

**The fix priority is clear:** ensure regional DEM coverage for all configured spots (which we already prioritize via the DEM index), and treat CRM as a last-resort fallback where datum uncertainty is one of several known quality limitations.

**For operator uploads:** operators savvy enough to bring their own bathymetry data know what datum it's in. We tell them the accepted datums (NAVD88, MLLW, MHW, MHHW, MSL — the CO-OPS list) and they upload accordingly. If their data is in a datum CO-OPS doesn't support, they convert it before uploading — standard GIS practice.

**CMVD is deferred to "needed when needed":**
- Not installed on production
- Not a dependency for v1
- Revisit if/when international marine support is added (non-US datums like LAT, CD)
- Revisit if a specific US territory or island has no CO-OPS station datum match (not identified yet)

The engineering effort goes into: (1) datum metadata tracking across all data products, (2) the dual-fetch pattern for CO-OPS, (3) recording the DEM's datum in the bathymetry cache, and (4) verifying the 34 UNKNOWN DEMs.

---

### §9.4 — Documentation rule: datum consistency is a hard requirement

The following must be stated clearly in governing documents:

**PROVIDER-MANUAL §14.7 (bathymetry) and §14.15 (SWAN runner):**
> All bathymetry (BOTTOM) and water level (WLEVEL) inputs to SWAN must be referenced to the same vertical datum. Mixing datums produces depth errors that corrupt wave breaking predictions. The system enforces this by fetching CO-OPS tide predictions in the same datum as the bathymetry DEM. Operators uploading custom bathymetry must specify their data's vertical datum and it must be one that the configured CO-OPS station supports.

**OPERATIONS-MANUAL (operator guidance):**
> Bathymetry and water level data must be in the same vertical datum for SWAN wave modeling. The system handles this automatically for NCEI and USGS data sources. For operator-uploaded bathymetry: specify the datum (NAVD88, MLLW, MHW, MHHW, or MSL) on upload. The system will fetch tide predictions in the matching datum. Do not mix datums between bathymetry and water level — SWAN cannot detect or correct datum mismatches.

**Operator Manual (help text for bathymetry upload):**
> Your bathymetry file's vertical datum must match one of the datums supported by your nearest CO-OPS tide station. Common datums: NAVD88, MLLW, MHW, MSL. If your data is in a different datum, convert it before uploading using VDatum (vdatum.noaa.gov) or QGIS.

---

## §10 — Remaining Open Questions and Required Tasks

### Required before implementation:

1. **Resolve the 34 UNKNOWN DEMs (BLOCKING).** The `.das` OPeNDAP metadata for these files does not expose the vertical datum, but each DEM has a landing page on NCEI (`https://www.ncei.noaa.gov/metadata/geoportal/rest/metadata/item/gov.noaa.ngdc.mgg.dem:{id}`) with full metadata including the vertical datum. This is a one-time manual research task:
   - For each of the 34 UNKNOWN files, look up the NCEI metadata page and record the actual vertical datum.
   - Update `ncei_regional_dem_index.json` with the correct datum.
   - Update `scripts/build_ncei_dem_index.py` to handle the files where `.das` doesn't expose the datum (hardcode a fallback lookup table keyed by filename, or parse the landing page metadata).
   - **This is blocking** because `find_best_dem()` could return one of these for a configured spot. If the datum is UNKNOWN, the system cannot match it with CO-OPS and the run proceeds with an unverified datum mismatch — the exact bug this brief documents.
   - Several of the UNKNOWN DEMs cover critical SoCal areas: `san_pedro_bay_P050_2018.nc`, `santa_monica_bay_P060_2018.nc`, `san_diego_bay_P020_2017.nc`, `monterey_bay_P080_2018.nc`.

2. **CO-OPS station datum support verification.** Verify that station 9410660 (Los Angeles) supports `datum=NAVD88` for predictions. Some stations may not support all datums — check the CO-OPS station capabilities endpoint or attempt a test fetch.

### Should be done but not blocking:

3. **Great Lakes DEM datum verification.** Confirm Rohweder 2025 files are NAVD88, not IGLD85 dynamic heights. Check the GeoTIFF CRS metadata with `rasterio` or `gdalinfo`. The difference is <5 cm but should be documented correctly.

4. **CRM datum characterization.** The `DEM_all` ImageServer exposes a `VerticalDatum` attribute per pixel. Investigate whether we can query this attribute for a given point to at least log the datum of the CRM data we're using, even if we can't guarantee it. This would turn a silent unknown into a logged known.

5. **Bathymetry cache format.** Add a `datum` field to the cache JSON so the SWAN pipeline knows what datum the cached bathymetry is in without re-querying the DEM index. Should include both the source datum and the data source name (for auditability).

---

## Sources

- [SWAN User Manual — Input grids and data](https://swanmodel.sourceforge.io/online_doc/swanuse/node26.html) — BOTTOM/WLEVEL datum requirement
- [CO-OPS Station 9410660 Datums](https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/9410660/datums.json) — LA datum values
- [CO-OPS Station 9410580 Datums](https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/9410580/datums.json) — Newport Beach datum values
- Production logs, 2026-07-19 08:47:34 PDT — VDatum 412 failure evidence
- `bathymetry_resolver.py` lines 463-578 — VDatum implementation
- `coops.py` line 484 — hardcoded `datum=MLLW`
- `swan_runner.py` line 598 — incorrect MSL docstring
