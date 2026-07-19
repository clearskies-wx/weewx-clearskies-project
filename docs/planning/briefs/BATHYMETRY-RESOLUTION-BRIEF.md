# Research Brief: Bathymetry Data Sources for SWAN Nearshore Modeling

**Date:** 2026-07-19 (updated from 2026-07-18)
**Status:** RESEARCH COMPLETE — implementation needed
**Origin:** Production SWAN Level 3 (10m grid) produced garbage output. Investigation revealed: (1) the `DEM_all` mosaic serves ~200-300m effective resolution at HB Pier, (2) CUDEM 1/9" tiles do not exist for SoCal, (3) domain sizing placed grids half on land. Multiple alternative high-res data sources identified.

---

## §1 — Problem Statement

The 3-level SWAN implementation queries the NCEI ArcGIS `DEM_all` ImageServer endpoint for bathymetry. This endpoint serves the U.S. Coastal Relief Model (CRM) at ~3 arc-second (~90m cell size) for SoCal, with only ~200-300m effective resolution due to sparse source survey data.

**Empirical testing at HB Pier (33.6568°N, 117.998°W):**
- 10m query spacing: 1 unique depth value out of 10 points
- 30m spacing: 2 unique values
- 100m spacing: 3 unique values
- 300m spacing: 8 unique values
- 500m spacing: 10 unique values

Both `getSamples` (batch) and `identify` (per-point) endpoints return identical coarse data — the limitation is the source DEM, not the API.

---

## §2 — CUDEM 1/9 Arc-Second (~3.4m) Does NOT Cover SoCal

Verified via NCEI THREDDS `tiled_19as` catalog:
- 1/9" tiles at w117/w118 (SoCal) **DO NOT EXIST**
- Pacific coast 1/9" tiles only cover Washington state (w122-w124, lat 47-49°N)
- California directory only has NorCal tiles (36.75°N to 38.75°N)
- 1/3" CUDEM also has no CA directory

The metadata bounding box (23-52°N) is the intended coverage — tiles are only generated where source data exists.

---

## §3 — Available High-Resolution Data Sources

### Tier 1: NCEI Regional Coastal DEMs (THREDDS) — FREE, PROGRAMMATIC

NCEI maintains **262 regional coastal DEMs** on their THREDDS server at `https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.html`. Built for tsunami inundation modeling (NTHMP program), these integrate the best available survey data (NOS hydrographic, CSMP multibeam, JALBTCX lidar) for each region.

**Resolution:** Typically 1/3 arc-second (~10m). Some regions at 1 arc-second (~30m) or 8/15 arc-second (~17m).

**Access:** Each file is NetCDF, queryable via:
- OPeNDAP (bbox subset): `https://www.ngdc.noaa.gov/thredds/dodsC/regional/{filename}.html`
- Direct download: `https://www.ngdc.noaa.gov/thredds/fileServer/regional/{filename}`
- WCS: `https://www.ngdc.noaa.gov/thredds/wcs/regional/{filename}`

**SoCal coverage (verified via NCEI coverage map — full coast covered):**

| File | Resolution | Bounding box |
|------|-----------|-------------|
| `orange_county_13_navd88_2015.nc` | 1/3" (~10m) | 32.62-33.85°N, 117.45-118.90°W — **covers HB Pier** |
| `san_pedro_bay_P050_2018.nc` | varies | San Pedro Bay, overlaps OC north |
| `santa_monica_13_navd88_2010.nc` | 1/3" (~10m) | Santa Monica to Malibu |
| `santa_monica_bay_P060_2018.nc` | varies | Santa Monica Bay |
| `san_diego_13_navd88_2012.nc` | 1/3" (~10m) | San Diego coast |
| `santa_barbara_13_mhw_2008.nc` | 1/3" (~10m) | Santa Barbara |
| `port_san_luis_13_navd88_2011.nc` | 1/3" (~10m) | Central coast |

**Filename convention:**

| Pattern | Resolution |
|---------|-----------|
| `_13_` | 1/3 arc-second (~10m) |
| `_1_` | 1 arc-second (~30m) |
| `_815_` | 8/15 arc-second (~17m) |
| `_83_` | 8/3 arc-second (~85m) |
| `_3_` | 3 arc-second (~90m) |
| `_P0xx_` / `_G0xx_` | varies (newer format) |

**Data vintage:** Source surveys vary by region. SoCal bathymetry likely from CSMP multibeam (2009-2012) and JALBTCX lidar (2009, 2014-2015). Deeper nearshore structure (reefs, channels at 5-30m depth) is essentially static over decades. Surf zone sandbars (0-5m) shift seasonally — no publicly maintained dataset tracks this.

### Tier 2: USGS Great Lakes Seamless Topobathymetric DEMs — FREE, DOWNLOADABLE

**Published:** June 2025 (Rohweder, USGS data release DOI: 10.5066/P1DA6L6U)
**Source data:** 2006-2016, lidar + USACE dredge surveys
**Resolution:** ~3-5m (estimated from file sizes — Lake Michigan 1.4 GB compressed)
**Format:** GeoTIFF, per-lake downloads from ScienceBase

| Lake | ScienceBase item | Compressed size |
|------|-----------------|----------------|
| Michigan | `669041b8d34e341cbf15576c` | 1.4 GB |
| Erie | `66903b2dd34e7f6636ec211b` | 521 MB |
| Huron | `66904150d34e341cbf15576a` | 546 MB |
| Ontario | `669041edd34e341cbf15576e` | 154 MB |
| Superior | `6690427ad34e341cbf155772` | 903 MB |
| St. Clair | `66904251d34e341cbf155770` | 168 MB |

**Coverage:** All 5 Great Lakes + St. Clair, full lake extent including nearshore. Specifically designed to fill nearshore gaps in existing data.

### Tier 3: CRM / DEM_all Mosaic — FREE, EVERYWHERE, COARSE

The fallback. 3 arc-second (~90m cells, ~200-300m effective) for most of the US coast. Adequate for Level 1 (1km grid) but not for nearshore grids.

### Not available for integration: Satellite-Derived Bathymetry (SDB)

Commercial vendors (TCarta, EOMAP, DHI/Bathymetrics Data Portal) produce 2-10m SDB grids from multispectral satellite imagery, covering to 20-30m depth. These fill the exact gaps we have. However:
- No open APIs
- No open pricing
- Custom procurement per area
- Not viable for a product that needs to work automatically

---

## §4 — Other Data Sources Investigated

**USGS CoNED Southern California (1m):**
- 1m topobathymetric DEM, compiled 2016 from 1930-2014 source data
- Extends to 2,847m depth (covers all grid levels)
- Available on AWS S3: `noaa-nos-coastal-lidar-pds.s3.us-east-1.amazonaws.com/dem/CA_Southern_CoNED_DEM_2016_8658/`
- **Issue:** Source bathymetric data from ~2007. Old.

**California Seafloor Mapping Program (CSMP, 2m):**
- 2m multibeam grids within 3-nautical-mile California State Waters
- USGS Data Series 781
- Surveys from ~2009-2013 for SoCal blocks

**USACE JALBTCX Topobathy Lidar:**
- 5m bathy / 1m topo point spacing
- Coverage: ~1000m offshore from shore (laser extinction depth)
- Surveyed SoCal: 2009 and 2014-2015
- ArcGIS ImageServer at `arcgis.usacegis.com` — timed out when tested
- Available via NOAA Digital Coast Data Access Viewer as custom download

**NOAA Digital Coast Data Access Viewer:**
- URL: `coast.noaa.gov/dataviewer/`
- 4m topobathy data available for HB Pier area
- Custom download by bbox → GeoTIFF
- Not a real-time API — manual/batch download

**NOAA Seabed 2030 Coverage Assessment:**
- URL: `iocm.noaa.gov/seabed-2030-bathymetry.html`
- 100m grid assessment of US waters bathymetry coverage quality
- "Better mapped" (3+ soundings per 100m cell) vs "minimally mapped"
- Could serve as coverage quality indicator in the wizard

---

## §5 — Competition

**Surfline (LOTUS):** Uses "high-res bathymetry mapping" — deliberately vague about source. Built on 35+ years of proprietary data starting with LOLA (2001). Likely uses same public NOAA/USGS data plus manual forecaster corrections accumulated over decades. 900+ surf cams worldwide but no evidence cameras are used for bathymetry derivation.

**Everyone else (Windy, Wisuki, etc.):** Shows raw WW3 offshore data with no nearshore modeling. No bathymetry, no breaking, no surf zone physics.

The bathymetry data gap hamstrings everyone equally. Surfline's advantage is accumulated corrections, not a better source dataset.

---

## §6 — Architecture: Bathymetry Resolver

### Data source hierarchy

1. **NCEI Regional DEM** (where available): 10m resolution, OPeNDAP query. Use for Level 2 and Level 3.
2. **USGS Great Lakes DEM** (all 5 lakes): 3-5m resolution, pre-downloaded GeoTIFF. Use for Level 2 and Level 3.
3. **CRM / DEM_all fallback**: ~90-300m resolution. Use for Level 1 always. Use for Level 2/3 ONLY when no better source exists — but warn the operator that nearshore accuracy will be degraded.

### Coverage gate

The system does NOT refuse to run when only CRM data is available. It runs with degraded accuracy and indicates this in the wizard/admin: "High-resolution nearshore bathymetry is available for this location" vs "Using lower-resolution bathymetry — surf zone features like sandbars and break points may not be resolved."

### Implementation needed

1. **Static index file:** JSON mapping each of the 262 regional DEMs' bounding boxes to their THREDDS filenames. Built once by querying OPeNDAP metadata. Ships with the API.
2. **OPeNDAP query function:** Given a bbox and target resolution, fetch a depth grid subset from the best available regional DEM. Replaces the `DEM_all/ImageServer/getSamples` call for Level 2/3.
3. **Great Lakes loader:** Read pre-downloaded GeoTIFF tiles for Great Lakes spots.
4. **Wizard coverage indicator:** Report bathymetry tier at setup time.

---

## §7 — Domain Sizing Bug (found and fixed during session)

All three grid levels were extending symmetrically around spot coordinates, placing ~50% of the grid on land. Level 2 had 46% dry cells — swell entering the offshore boundary hit land before reaching the Level 3 nest location. No wave energy propagated through.

**Root cause:** `_compute_level2()` and `_compute_level3_grid()` in `swan_domain.py` did not use `beach_facing_degrees`. They extended equally in all directions.

**Fix (committed b44e3c3):** All three levels now use `beach_facing_degrees` to extend primarily offshore with minimal land margin:
- Level 1: offshore_km in bearing direction, 1km landward
- Level 2: 6km offshore, 0.5km landward
- Level 3: 1km offshore, 0.1km landward

---

## §8 — Sources

- NCEI `DEM_all` mosaic (tested): `gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_all/ImageServer`
- NCEI Regional DEMs THREDDS catalog (262 files): `ngdc.noaa.gov/thredds/catalog/regional/catalog.html`
- Orange County DEM metadata: `ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.ngdc.mgg.dem:11506`
- U.S. CRM SoCal V2: `ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.ngdc.mgg.dem:4970`
- CUDEM 1/9" THREDDS: `ngdc.noaa.gov/thredds/catalog/tiles/tiled_19as/catalog.html`
- CUDEM 1/9" HTTP mirror CA: `chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/CA/`
- USGS Great Lakes DEMs: `sciencebase.gov/catalog/item/663e3e53d34eaf9729f7add6` (DOI: 10.5066/P1DA6L6U)
- USGS CoNED SoCal: `sciencebase.gov/catalog/item/5af335b2e4b0da30c1b26dab`
- CSMP data catalog: USGS Data Series 781
- JALBTCX ImageServer: `arcgis.usacegis.com/arcgis/rest/services/JALBTCX/JALBTCX_Products_1mGrid/ImageServer`
- NOAA Digital Coast: `coast.noaa.gov/dataviewer/`
- NOAA Seabed 2030 coverage: `iocm.noaa.gov/seabed-2030-bathymetry.html`
- Carignan et al. (2023), CUDEMs: `mdpi.com/2072-4292/15/6/1702`
- Ludka et al. (2019), San Diego beach surveys: `pmc.ncbi.nlm.nih.gov/articles/PMC6715754/`
- O'Reilly et al. (2016), CDIP wave monitoring: Coastal Engineering vol. 116, pp. 118-132
- SWAN User Manual v41.51: `swanmodel.sourceforge.io/download/zip/swanuse.pdf`
- SWAN nesting documentation: `swanmodel.sourceforge.io/online_doc/swanuse/node27.html`
