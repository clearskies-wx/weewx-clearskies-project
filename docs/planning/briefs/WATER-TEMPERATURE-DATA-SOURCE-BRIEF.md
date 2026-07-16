# Water Temperature Data Source Brief

**Date:** 2026-07-13
**Status:** Research complete — pending ADR-091 revision
**Origin:** Review of MARINE-CARD-DATA-SOURCE-PLAN.md T0.1 Decision 1, which specified NDBC buoy as sole water temperature source

---

## Problem

The plan specifies NDBC buoy 46253 as the primary (and only) water temperature source for all marine locations. This is wrong:

1. **Wrong location.** Buoy 46253 sits in the San Pedro Channel, ~12 miles offshore in 66m of deep water. Deep ocean water does not heat like the coastal shelf. Beach surface water can be 5–9°F warmer than open ocean on calm sunny days due to solar heating of the shallow shelf.
2. **Surface only.** The buoy reports a single surface observation. Fishing needs water column temperature profiles — thermocline depth, bottom temps — not just surface.
3. **No forecast.** Current observations only. No 72-hour water temp forecast capability.
4. **Identical for all locations.** All 7 locations show the same 20.8°C because they all read from the same offshore buoy.

There was a nearshore NDBC buoy at Huntington Beach (station 46230), but NOAA decommissioned it in 2006.

---

## Architecture Decision

### Data source hierarchy

**Tier 1 — On-premises sensor.** A physical sensor literally at the marine location — the operator's own weather station or a CO-OPS gauge mounted on that pier. Only used when a sensor exists at the site itself, not "nearby." This is primary when available because it measures what the visitor actually experiences.

**Tier 2 — NOAA OFS regional coastal model via THREDDS.** The most accurate nearshore water temperature source. NOAA operates 15 Operational Forecast System models covering major US coastal areas. These are high-resolution (34m–4km) physics-based ocean models (ROMS, FVCOM) that resolve coastal processes — upwelling, eddies, river plumes, shallow shelf heating, tidal mixing. They provide full water column temperature at multiple depth levels plus 48–120 hour forecasts.

The IOOS regional association models (SCCOOS ROMS, CeNCOOS ROMS, LiveOcean, etc.) have largely been folded into this OFS system. The few remaining independent regional models on ERDDAP (PacIOOS for Hawaii, CARICOOS for Caribbean) supplement OFS in areas it doesn't cover.

OFS data is served via THREDDS/OPeNDAP at `opendap.co-ops.nos.noaa.gov/thredds/`. This requires an OPeNDAP-capable provider (Python `xarray` + `netCDF4`), not the ERDDAP griddap HTTP pattern.

**Tier 3 — Fallback, split by use case:**

- **Surface / current conditions display** (location cards, beach safety tab): **NASA MUR SST** via ERDDAP. 1km resolution, global, gap-free, daily, ~1-day latency. Simple HTTP query, no depth dimension. Good enough for "water temp is 68°F" on a card. Measures foundation temperature (~1–5m depth), which can understate actual surface by 2–5°F on calm sunny days — but is reliable and always available.

- **Water column profiles + forecasts** (fishing tab, detailed marine): **NOAA RTOFS** via ERDDAP. Global operational HYCOM model, 1/12° (~8km), 41 depth levels through the full water column, 8-day forecast. Coarser than OFS but covers everywhere OFS doesn't.

**Dropped:**
- **NDBC offshore buoys** — demoted to labeled reference data only. If shown, labeled "Offshore Buoy (12mi)" so visitors know it is not beach water.
- **OISST** — 25km resolution, too coarse. One grid cell covers the entire Huntington-to-Long Beach coast.
- **IOOS ERDDAP as a universal regional model tier** — only 2 of 11 regions have active models on ERDDAP. The regional modeling has moved to NOAA OFS on THREDDS.

---

## NOAA OFS Model Inventory

All served via THREDDS at `opendap.co-ops.nos.noaa.gov/thredds/`. Updated 4x daily. Each model provides water temperature at multiple depth levels plus surface elevation, salinity, and currents.

### ROMS-based models (structured curvilinear grid)

| Model | Area | Resolution | Depth Levels | Forecast | Temp Variable |
|---|---|---|---|---|---|
| WCOFS | US West Coast (24N–54N) | ~4km | 40 sigma | 72hr | `temp` |
| GOMOFS | Gulf of Maine + shelf | ~700m | 30 sigma | 72hr | `temp` |
| CBOFS | Chesapeake Bay + shelf | 34m–4.9km | 20 sigma | 48hr | `temp` |
| DBOFS | Delaware Bay + shelf | 100m–3km | 10 sigma | 48hr | `temp` |
| TBOFS | Tampa Bay + shelf | 100m–1.2km | 11 sigma | 48hr | `temp` |
| CIOFS | Cook Inlet, Alaska | 10m–3.5km | 30 sigma | 48hr | `temp` |

### FVCOM-based models (unstructured triangular mesh)

| Model | Area | Resolution | Depth Layers | Forecast | Temp Variable |
|---|---|---|---|---|---|
| SFBOFS | San Francisco Bay | 10m–3.9km | Unspecified | 48hr | `temp` |
| NGOFS2 | Northern Gulf of Mexico | 45m–300m | Unspecified | 48hr | `temp` |
| SSCOFS | Salish Sea + Columbia River | 100m–10km | 10 sigma | 72hr | `temp` |
| LMHOFS | Lake Michigan + Huron | 50m–2.5km | 21 sigma | 120hr | `temp` |
| LEOFS | Lake Erie | 400m–4km | Unspecified | 120hr | `temp` |
| LOOFS | Lake Ontario | 200m–2.5km | 21 sigma | 120hr | `temp` |
| LSOFS | Lake Superior | Unspecified | Unspecified | 120hr | `temp` |

### Other model types

| Model | Area | Model Type | Forecast | Temp Variable |
|---|---|---|---|---|
| NYOFS | Port of NY/NJ | POM | 48hr | `temp` |
| SJROFS | St. Johns River, FL | EFDC | 48hr | `temp` |

### OFS geographic coverage

OFS covers major US coastal areas but not the entire coastline. Gaps include:
- Open Atlantic coast south of Cape Hatteras to Florida (between CBOFS/DBOFS and TBOFS)
- Most of the Gulf coast west of the NGOFS2 domain
- Oregon/Washington open coast (SSCOFS covers Salish Sea/Columbia River but not the outer coast — WCOFS covers this at coarser resolution)
- Hawaii, Caribbean, Pacific territories (not covered by OFS — PacIOOS ROMS and CARICOOS FVCOM fill these via ERDDAP)
- Remote Alaska coastline outside Cook Inlet

Where OFS has no coverage, RTOFS (global, 8km) fills the gap.

---

## How Water Temperature Integrates with Each Activity

### Which depth, for what purpose

| Consumer | Depth needed | What it's used for | Source tier |
|---|---|---|---|
| Location card `waterTemp` | Surface (0m) | "Water: 68°F" display | On-premises → OFS surface → MUR SST |
| Beach safety — comfort | Surface (0m) | Comfort classification (comfortable / cool / cold / dangerous) | Same as card |
| Beach safety — hypothermia risk | Surface (0m) | <55°F warning threshold | Same as card |
| Surfing — wetsuit recommendation | Surface (0m) | Full suit / spring suit / trunks | Same as card |
| Boating — water temp forecast | Surface (0m), 72hr time series | Trip planning, engine cooling expectations | OFS forecast → RTOFS forecast |
| Fishing — species temperature scoring | **Species-specific depth** | Evaluate temp at the depth where the fish lives | OFS column → RTOFS column |
| Fishing — thermocline detection | Full column profile | Identify the depth where temp drops fastest — key info for anglers | OFS column → RTOFS column |
| Fishing — bottom temperature | Deepest model layer | Bottom species (halibut, lingcod) live on the seafloor | OFS column → RTOFS column |

### Species depth targeting for temperature scoring

The species YAML database already defines optimal/good/marginal temperature ranges per species. What's missing is **at what depth** to evaluate temperature. Each species entry needs a `target_depth_range_m: [min, max]` field so the scorer queries the right OFS/RTOFS depth levels.

Depth categories for SoCal species:

| Category | Depth range | Example species | What to query |
|---|---|---|---|
| Pelagic | 0–30m | Yellowtail, Bonito, Barracuda, Mahi-Mahi | Surface to thermocline — average temp across 0–30m depth levels |
| Kelp/reef | 5–30m | Calico Bass, Sheephead, Garibaldi | Mid-water — average temp across 5–30m depth levels |
| Mid-water | 10–50m | White Seabass, Yellowtail (deep) | Mid-column — average temp across 10–50m depth levels |
| Deep reef | 30–200m | Rockfish, Lingcod (rocky habitat) | Deep — temp at 30m, 50m, 100m, 150m, 200m levels |
| Bottom/demersal | Seafloor | Halibut, Sanddab, Sole | Bottom layer — temp at deepest OFS/RTOFS level at this location (use `h` bathymetry to determine actual depth) |

The scorer evaluates: "what is the temperature at this species' target depth range?" → compare to the species' optimal/good/marginal temp thresholds → produce a temperature suitability score (0–100).

### Why this is not optional — the current scoring is broken

The existing fishing scorer evaluates species temperature suitability, but it uses NDBC buoy 46253 surface temperature — a single reading from 12 miles offshore at the ocean surface. A rockfish species living at 100m on a reef is being scored against open-ocean surface temp. A halibut on the bottom in 20m of water is being scored against the same number. The scores are fiction.

Water column data from OFS/RTOFS is not a nice-to-have enhancement — it is the **input that makes species temperature scoring produce real answers**. Without depth-specific temperature at the species' actual habitat depth, the temperature suitability component of the fishing score is meaningless. This is the highest-impact data source change in this plan.

### Thermocline detection from the water column profile

Given a vertical temperature profile from OFS or RTOFS (temp at each depth level), the thermocline is the depth where `dT/dz` (rate of temperature change with depth) is greatest:

```
For each pair of adjacent depth levels (z[i], z[i+1]):
    gradient = abs(temp[i] - temp[i+1]) / (depth[i+1] - depth[i])
thermocline_depth = depth at max gradient
thermocline_strength = max gradient value (°C/m)
```

Display on the fishing tab: "Thermocline at 15m (2.3°F/m)" — tells anglers where the cold water boundary is.

---

## Technical Detail: OFS Model Assignment

### How a marine location gets assigned to an OFS model

This is done **at configuration time** (setup wizard or `api.conf`), not at runtime. Each OFS model has a fixed geographic domain. When an operator configures a marine location with a lat/lon, the system checks which OFS model domain(s) contain that point.

**OFS domain bounding boxes** (approximate — stored as a lookup table in the provider module):

| Model | Lat South | Lat North | Lon West | Lon East |
|---|---|---|---|---|
| WCOFS | 24.0 | 54.0 | -134.0 | -115.0 |
| GOMOFS | 39.5 | 46.0 | -72.0 | -62.0 |
| CBOFS | 36.5 | 39.8 | -77.5 | -75.0 |
| DBOFS | 38.0 | 41.5 | -76.0 | -73.0 |
| TBOFS | 27.0 | 28.5 | -83.5 | -82.0 |
| CIOFS | 58.5 | 61.5 | -155.0 | -148.0 |
| SFBOFS | 37.3 | 38.2 | -123.0 | -121.8 |
| NGOFS2 | 25.0 | 31.0 | -98.0 | -84.0 |
| SSCOFS | 45.5 | 50.5 | -127.0 | -121.0 |
| LMHOFS | 41.5 | 46.5 | -87.5 | -79.5 |
| LEOFS | 41.3 | 42.9 | -83.5 | -78.8 |
| LOOFS | 43.0 | 44.5 | -79.8 | -76.0 |
| LSOFS | 46.0 | 49.5 | -92.2 | -84.0 |
| NYOFS | 40.3 | 41.0 | -74.5 | -73.5 |
| SJROFS | 29.5 | 30.6 | -82.0 | -81.0 |

**Multiple model overlap:** A location may fall within multiple OFS domains (e.g., a point on the Oregon coast is in both WCOFS at 4km and SSCOFS at 100m–10km). When domains overlap, assign the **highest-resolution model** — the one with the smallest grid spacing at that point. Store a ranked list so the second model becomes the OFS-level fallback.

**Assignment output:** The location config stores:
```
ofs_model = "WCOFS"           # primary OFS model for this location
ofs_fallback = "SSCOFS"       # secondary OFS model if primary fails (optional)
ofs_region = null              # ERDDAP regional model, if location is in Hawaii/Caribbean
```

For locations outside all OFS domains (Hawaii, Caribbean, remote Alaska), `ofs_model` is null and the system skips directly to tier 3 fallback. If the location is in a PacIOOS or CARICOOS region, `ofs_region` stores that assignment instead.

**When is this computed?** At location creation/update in the setup wizard or config. The bounding box check is pure geometry — no network calls. The assignment is persisted in `api.conf` so the runtime never re-computes it.

---

## Technical Detail: THREDDS/OPeNDAP Data Extraction

### File structure and selection (verified from live THREDDS catalog 2026-07-13)

OFS models produce multiple file types per run cycle. File organization on the THREDDS server:

```
https://opendap.co-ops.nos.noaa.gov/thredds/dodsC/NOAA/{MODEL}/MODELS/{YYYY}/{MM}/{DD}/{filename}
```

**Verified WCOFS file inventory for a single day (2026-07-13, cycle t03z):**

| File type | Pattern | Count | Step | Content |
|---|---|---|---|---|
| `regulargrid` | `wcofs.t03z.20260713.regulargrid.{n\|f}NNN.nc` | 27 | 3hr | Pre-interpolated to regular lat/lon grid |
| `fields` | `wcofs.t03z.20260713.fields.{n\|f}NNN.nc` | 27 | 3hr | Native curvilinear grid (do NOT use) |
| `2ds` | `wcofs.t03z.20260713.2ds.{n\|f}NNN.nc` | 97 | 1hr | 2D surface fields only |
| `stations` | `wcofs.t03z.20260713.stations.{nowcast\|forecast}.nc` | 2 | — | Point extracts |
| `avg` | `wcofs.t03z.20260713.avg.{nowcast\|forecast}.nc` | 2 | — | Daily averages |

Nowcast hours: n003–n024 (3hr steps). Forecast hours: f003–f072 (3hr steps).
WCOFS runs 1 cycle per day (t03z). Most other OFS models run 4 cycles (t00z, t06z, t12z, t18z).

**Always use `regulargrid` files.** Pre-interpolated from native curvilinear/unstructured mesh to a regular lat/lon grid. The `fields` files use curvilinear coordinates (ROMS) or unstructured meshes (FVCOM) requiring spatial interpolation — avoid.

**Cycle selection logic:** Data availability lags the cycle time by ~3–4 hours. To get the latest:
1. Compute most recent cycle: `floor(current_utc_hour / 6) * 6` (for 4x/day models)
2. Try that cycle's first forecast file (`f003` for regulargrid, `f001` for 2ds)
3. If 404, fall back to previous cycle (same pattern as NWPS provider in `providers/marine/nwps.py`)

### Verified regulargrid variable structure (from GOMOFS OPeNDAP metadata)

Fetched live from `gomofs.t00z.20260713.regulargrid.f003.nc`:

```
Dimensions:
  time:  1
  Depth: 40
  ny:    737
  nx:    1066

Coordinates:
  Latitude    Float64  [ny=737][nx=1066]    "Latitude in common grid" (degrees_north)
  Longitude   Float64  [ny=737][nx=1066]    "Longitude in common grid" (degrees_east)
  Depth       Float64  [Depth=40]            "Depths of Standard Layer" (meters, positive down)
  time        Float64  [time=1]              "time since initialization" (seconds since 2016-01-01)

Variables:
  temp         Float32  [time][Depth][ny][nx]   standard_name: "sea_water_temperature" (Celsius)
  salt         Float32  [time][Depth][ny][nx]   standard_name: "sea_water_salinity" (PSU)
  u_eastward   Float32  [time][Depth][ny][nx]   standard_name: "eastward_sea_water_velocity" (m/s)
  v_northward  Float32  [time][Depth][ny][nx]   standard_name: "northward_sea_water_velocity" (m/s)
  zeta         Float32  [time][ny][nx]          standard_name: "sea_surface_elevation" (meters)
  zetatomllw   Float32  [time][ny][nx]          "free-surface vs. mean lower low water" (meters)
  h            Float64  [ny][nx]                standard_name: "sea_floor_depth_below_mean_sea_level" (meters)
  mask         Float64  [ny][nx]                standard_name: "sea_binary_mask" (0=land, 1=water)
```

**Variable name is `temp` across all ROMS-based OFS models** (WCOFS, GOMOFS, CBOFS, DBOFS, TBOFS, CIOFS). FVCOM-based models also use `temp`.

**Critical:** `Latitude` and `Longitude` are 2D arrays indexed by `(ny, nx)`, NOT 1D coordinate axes. `ds.sel(Latitude=33.65)` will NOT work — xarray label-based selection requires 1D coords.

### FMRC aggregated datasets (native grid — different structure)

7 OFS models have aggregated 7-day forecast collections (CBOFS, CIOFS, DBOFS, GOMOFS, NYOFS, SJROFS, TBOFS):
```
https://opendap.co-ops.nos.noaa.gov/thredds/dodsC/{MODEL}/fmrc/Aggregated_7_day_{MODEL}_Fields_Forecast_best.ncd
```

**These use the native ROMS grid, NOT regulargrid.** Verified CBOFS FMRC structure:
```
Dimensions: time=252, s_rho=20, eta_rho=291, xi_rho=332
Variable:   temp Float32 [time=252][s_rho=20][eta_rho=291][xi_rho=332]
Coords:     lon_rho[eta_rho][xi_rho], lat_rho[eta_rho][xi_rho] — 2D curvilinear
Vertical:   s_rho (sigma, -1 to 0) — NOT meters, requires conversion using h and zeta
```

The FMRC datasets allow querying the full 7-day time series in one OPeNDAP call (time=252 @ hourly), but require sigma-to-depth conversion and curvilinear grid interpolation. Use them only if the per-file regulargrid approach is too slow.

### Opening the data with xarray

```python
import xarray as xr

url = (
    f"https://opendap.co-ops.nos.noaa.gov/thredds/dodsC/NOAA/{model}/MODELS/"
    f"{date:%Y}/{date:%m}/{date:%d}/"
    f"{model.lower()}.t{cycle:02d}z.{date:%Y%m%d}.regulargrid.f{fhr:03d}.nc"
)

ds = xr.open_dataset(url, engine="netcdf4")
# LAZY open — only metadata fetched. No bulk download.
```

### Finding the nearest grid point to a query lat/lon

```python
import numpy as np

lat_target, lon_target = 33.6531, -118.0038
lat_grid = ds["Latitude"].values   # shape (ny, nx)
lon_grid = ds["Longitude"].values  # shape (ny, nx)

# Compute great-circle distance from every grid point to the target
dist = np.sqrt((lat_grid - lat_target)**2 + (lon_grid - lon_target)**2)

# Find the (ny, nx) indices of the minimum distance
iy, ix = np.unravel_index(dist.argmin(), dist.shape)

# Check the land mask — if nearest point is land, search further
if ds["mask"].values[iy, ix] == 0:
    # Mask land points with inf and re-find
    dist[ds["mask"].values == 0] = np.inf
    iy, ix = np.unravel_index(dist.argmin(), dist.shape)

# Extract temperature profile at this grid point (all depths)
temp_profile = ds["temp"].isel(time=0, ny=iy, nx=ix).values  # shape (Depth,)
depth_levels = ds["Depth"].values                              # actual depth in meters

# Extract surface temperature only
surface_temp = ds["temp"].isel(time=0, Depth=0, ny=iy, nx=ix).values  # scalar, Celsius
```

**Performance note:** The `xr.open_dataset()` call fetches only metadata. The `.values` call on `Latitude`/`Longitude` fetches those arrays (~1–5 MB). The `.isel().values` call on `temp` fetches only the requested slice over OPeNDAP — a single column profile is a few KB. Total network: ~2–6 MB per location query, not the full multi-GB file.

### Caching the grid coordinates

The `Latitude`, `Longitude`, `Depth`, `h`, and `mask` arrays are the same for every forecast file of a given OFS model — they describe the fixed grid. Cache them after the first fetch:

```python
# Cache key: model name (e.g., "WCOFS")
# Cache value: (lat_grid, lon_grid, depth_levels, mask, h) numpy arrays
# TTL: 24 hours (grid never changes, but re-validate daily)
```

With the grid cached, subsequent queries only fetch the temperature variable slice (~KB), not the coordinate arrays (~MB).

### Sigma coordinate depth conversion (native grid files only)

The `regulargrid` files have pre-computed `Depth` in meters — no conversion needed. This section applies only if using the native `fields` files (which we should avoid when possible).

ROMS sigma layers: actual depth = `h * s_rho + zeta * (1 + s_rho)` where `h` is bathymetry, `s_rho` is the sigma coordinate (-1 to 0), and `zeta` is sea surface elevation.

FVCOM sigma layers: actual depth = `-1 * (siglay * h + zeta * (1 + siglay))` where `siglay` goes from 0 (surface) to -1 (bottom).

### Extracting a forecast time series

For a water temp forecast (e.g., 72 hours for boating tab):

```python
# Fetch multiple forecast hour files and concatenate
temps = []
times = []
for fhr in range(1, 73):  # f001 through f072
    filename = f"{model.lower()}.t{cycle:02d}z.{date:%Y%m%d}.regulargrid.f{fhr:03d}.nc"
    url = f"{base_url}/{filename}"
    try:
        ds_f = xr.open_dataset(url, engine="netcdf4")
        t = ds_f["temp"].isel(Depth=0, ny=iy, nx=ix).values  # surface temp
        times.append(ds_f["time"].values[0])
        temps.append(float(t))
    except OSError:
        break  # no more forecast hours available
```

**Optimization:** Some OFS models provide FMRC (Forecast Model Run Collection) aggregated datasets that combine all forecast hours into one OPeNDAP endpoint. Available for CBOFS, CIOFS, DBOFS, GOMOFS, NYOFS, SJROFS, TBOFS:
```
https://opendap.co-ops.nos.noaa.gov/thredds/dodsC/{MODEL}/fmrc/Aggregated_7_day_{MODEL}_Fields_Forecast_best.ncd
```
These allow a single `open_dataset` + time-range selection instead of looping over files. However, they use the native grid (not regulargrid), requiring spatial interpolation.

---

## Technical Detail: Fallback Decision Logic

### Decision tree at runtime

```
For a given marine location with lat/lon:

1. On-premises sensor configured AND sensor is reporting?
   → Use sensor reading for surface temp (no water column from a sensor)
   → Continue to step 2 for water column / forecast data

2. location.ofs_model is set?
   → Try OFS model via THREDDS
   → If OFS returns data:
      • Surface temp: OFS surface layer (Depth=0)
      • Water column: OFS all depth levels
      • Forecast: OFS forecast hours
      → Done
   → If OFS fails (THREDDS 404, timeout, model not producing):
      → Try location.ofs_fallback (secondary OFS model) if set
      → If that also fails, continue to step 3

3. location.ofs_region is set? (PacIOOS or CARICOOS)
   → Try regional ERDDAP model
   → If returns data: same as OFS (surface + column + forecast)
   → If fails, continue to step 4

4. Fallback — split by what the consumer needs:

   Consumer needs SURFACE TEMP ONLY (cards, beach safety):
   → NASA MUR SST via ERDDAP (1km, surface, ~1-day-old)
   → If MUR fails: RTOFS surface layer via ERDDAP (8km)
   → If RTOFS fails: null (display "—")

   Consumer needs WATER COLUMN or FORECAST (fishing, detailed marine):
   → RTOFS via ERDDAP (41 depth levels, 8-day forecast, global)
   → If RTOFS fails: null (display "—")
```

### When MUR SST vs RTOFS as fallback

The split is by **what the consumer is asking for**, not by which source is available:

| Consumer | Needs | Fallback source | Why |
|---|---|---|---|
| Location card `waterTemp` | Single current surface value | MUR SST | 1km resolution, gap-free, no depth dimension to deal with, simple |
| Beach safety tab | Current surface + comfort classification | MUR SST | Same — just a number for the display |
| Fishing tab water column | Temperature at multiple depths | RTOFS | MUR is surface-only, useless for column profiles |
| Fishing tab forecast | Temp forecast over 72+ hours | RTOFS | MUR has no forecast capability (1-day-old analysis) |
| Boating tab forecast | Surface temp trend over time | RTOFS | MUR is one value per day, no intra-day or forward forecast |
| Marine detail `waterTemp` | Current surface for display | MUR SST | Simple display value |

MUR SST and RTOFS are never in competition with each other — they serve different needs. A location with no OFS coverage uses **both**: MUR for the card/beach display, RTOFS for the fishing/forecast tabs.

### Error handling at each tier

Each tier is independently wrapped. A failure at one tier does not prevent trying the next:

- THREDDS 404 (file not found) → cycle fallback, then tier fallback
- THREDDS timeout (>10s) → skip to next tier
- THREDDS returns data but grid point is land (mask=0) → treat as no data, fall to next tier
- ERDDAP returns empty result → fall to next tier
- ERDDAP 500/503 → fall to next tier
- All tiers exhausted → null with `source: "unavailable"` in response

---

## Fallback Data Sources

### NASA MUR SST (surface temp fallback)

- **What:** Multi-scale Ultra-high Resolution SST. Level 4 global satellite analysis blending MODIS, AMSR2, AVHRR, VIIRS, and in-situ data.
- **Resolution:** 0.01° (~1km)
- **Coverage:** Global — all US coasts, Hawaii, Alaska, Great Lakes, territories
- **Temporal:** Daily, ~1-day latency
- **Depth:** Surface only (foundation SST at ~1–5m depth)
- **Forecast:** None
- **Access:** ERDDAP griddap:
  ```
  https://coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.csv?analysed_sst[(last)][(33.65)][(-118.00)]
  ```
- **Limitation:** Measures foundation temperature, which can understate actual surface by 2–5°F on calm sunny days. Independent coastal studies show higher spatial resolution does not always mean better accuracy near shore — specialized coastal models (like OFS) capture reality more effectively because they process continuous local atmospheric data over the shallow shelf.
- **Use case:** Simple current water temp display on cards and beach safety tabs, when OFS has no coverage for that location.

### NOAA RTOFS (water column + forecast fallback)

- **What:** Real-Time Ocean Forecast System. Global operational HYCOM with 3DVar data assimilation.
- **Resolution:** 1/12° (~8km)
- **Coverage:** Global
- **Depth:** 41 hybrid vertical levels, full water column
- **Forecast:** 8-day, updated daily
- **Variables:** Temperature, salinity, water velocity, sea surface elevation
- **Access:** ERDDAP griddap:
  - 3D: `ncepRtofsG3DForeDaily` at `coastwatch.pfeg.noaa.gov`
  - 2D surface: `ncepRtofsG2DFore3hrlyProg`
  ```
  https://coastwatch.pfeg.noaa.gov/erddap/griddap/ncepRtofsG3DForeDaily.csv?temperature[(last)][(0)][(33.65)][(-118.00)]
  ```
- **Use case:** Water column profiles and forecasts for fishing/marine tabs, when OFS has no coverage for that location. Also universal surface temp fallback behind MUR SST.

### Regional ERDDAP models (supplementary, specific regions only)

Two IOOS regions still operate independent ocean models on ERDDAP, supplementing OFS in areas it doesn't cover:

| Region | ERDDAP Server | Model | Dataset ID | Resolution | Depth |
|---|---|---|---|---|---|
| PacIOOS (Hawaii/Pacific) | pae-paha.pacioos.hawaii.edu | ROMS | `roms_hiig` | ~4km | 36 levels |
| CARICOOS (PR/USVI) | dm3.caricoos.org | FVCOM | `FVCOM_Historical_3D_StructuredGrid` | ~800m | 11 levels |

These use the standard ERDDAP griddap API pattern and are preferred over RTOFS for their respective regions due to higher resolution.

---

## ERDDAP API Consistency

For all ERDDAP-accessed sources (MUR SST, RTOFS, PacIOOS, CARICOOS), the griddap URL pattern is standardized:

```
https://{server}/erddap/griddap/{datasetID}.{format}?{variable}[(time)][(depth)][(lat)][(lon)]
```

- Dimension order: always time, depth, latitude, longitude
- Output formats (.json, .csv, .nc): same everywhere
- What varies per dataset: variable name (`temp` vs `water_temp` vs `analysed_sst`), longitude convention (0–360 vs ±180), number of depth levels

A single ERDDAP griddap provider module with per-dataset config handles all ERDDAP sources uniformly.

---

## OFS Data Beyond Temperature

### What OFS provides (verified from live OPeNDAP metadata)

OFS models produce more than water temperature. From the same files we open for temperature, we get:

**3D regulargrid files (all 15 OFS models):**

| Variable | Name | Units | Depth levels | Use case |
|---|---|---|---|---|
| `temp` | Water temperature | Celsius | Full column | Temperature profiles, species scoring, thermocline |
| `salt` | Salinity | PSU | Full column | Species habitat, halocline, river plume detection |
| `u_eastward` | Eastward current velocity | m/s | Full column | Current speed + direction at any depth |
| `v_northward` | Northward current velocity | m/s | Full column | Same — combine with u for vector |
| `zeta` | Sea surface elevation vs MSL | meters | Surface | Modeled water levels including storm surge |
| `zetatomllw` | Sea surface elevation vs MLLW | meters | Surface | Same, referenced to tide datum |
| `h` | Bathymetry | meters | Static | Model-grid seafloor depth (NOT a replacement for CUDEM) |
| `mask` | Land/water mask | 0/1 | Static | Grid point filtering |

**2D surface files (ROMS models only — WCOFS, GOMOFS, CBOFS, DBOFS, TBOFS, CIOFS):**

| Variable | Name | Units | Use case |
|---|---|---|---|
| `temp_sur` | Surface water temperature | Celsius | Quick surface temp without opening 3D file |
| `salt_sur` | Surface salinity | PSU | River plume tracking near river mouths |
| `u_sur` / `v_sur` | Surface current velocity | m/s | Current reporting for boating, fishing drift |
| `Pair` | Surface air pressure | millibar | Barometric pressure over the water |
| `Uwind` / `Vwind` | Surface wind components | m/s | Marine-optimized wind (over ocean, not land) |
| `Tair` | Surface air temperature | Celsius | Air temp over the water |
| `swrad` | Solar shortwave radiation | W/m² | UV/solar indicator |

### Modeled vs observed — critical distinction

**ALL OFS output is modeled.** OFS solves fluid dynamics equations on a grid, forced by atmospheric data (GFS weather model), tidal harmonics, river discharge, and boundary conditions from RTOFS. It assimilates some observations (satellite SST, tide gauge data) to nudge the model, but the output is a physics simulation. When OFS says "18.2°C at this grid point," that's what the equations calculated, not what a thermometer read.

| Data type | Source | What it represents | Strengths | Limitations |
|---|---|---|---|---|
| **Modeled** (OFS, RTOFS, MUR SST) | Physics simulation or satellite analysis | What the model calculates reality should be | Continuous spatial coverage, depth profiles, forecasts | Subject to model error, grid resolution limits, biased near complex coastlines |
| **Observed** (CO-OPS station, NDBC buoy, on-premises sensor) | Physical sensor reading | What was actually measured at one point | Ground truth at that exact location | Single point, no depth profile, no forecast, may be offline |

The resolver's `mode="modeled"` vs `mode="observed"` distinction exists so consumers can get either, and know which they got.

### OFS bathymetry vs CUDEM — keep CUDEM

OFS `h` is bathymetry smoothed to the model's grid resolution (700m–4km). CUDEM is 1/9 arc-second (~3m). For surf spot profiling where we care about specific reef structures, jetties, and sandbars, CUDEM is orders of magnitude more detailed. OFS `h` tells you "average depth in this 4km cell is 25m." CUDEM tells you "there's a 3m reef at this exact lat/lon." Keep CUDEM for bathymetry. OFS `h` is useful only as a quick "how deep is the water here" reference, not for habitat or surf analysis.

### OFS water levels vs CO-OPS tide predictions — different things, both needed

| | CO-OPS harmonic predictions | OFS `zeta` / `zetatomllw` |
|---|---|---|
| **What it models** | Astronomical tide only (moon + sun gravitational pull) | Total water level: tide + storm surge + wind setup + atmospheric pressure + river discharge |
| **Based on** | Decades of harmonic analysis at specific stations | Physics simulation forced by weather + tide |
| **Accuracy for normal tides** | Very high at the station location | Model-dependent, can have systematic biases |
| **Storm surge / extreme events** | Not included — predictions don't account for storms | Included — this is the model's strength |
| **High/low classification** | Yes — labeled "High" and "Low" with times | No — continuous water level, no labels |
| **Coverage** | Specific station locations only | Every grid point in the OFS domain |
| **Outside OFS areas** | Available wherever CO-OPS has a station | Not available |

**Decision:** CO-OPS harmonic predictions remain primary for tide display (high/low times, predicted heights). OFS water levels are supplementary — they tell you "the actual water level will be 0.8 ft higher than the prediction because of onshore wind and low pressure." This matters for storm surge warnings, king tides, and coastal flooding alerts.

**Research needed:** How well do OFS water levels perform as continuous tidal information compared to CO-OPS predictions? Could OFS `zetatomllw` provide per-location water levels that differ between locations 2km apart (which CO-OPS predictions cannot, since all locations sharing the same station show identical tides)? This needs investigation before committing to using OFS water levels as a primary tide source.

### OFS coverage reality — significant gaps

The 15 OFS models cover major ports, bays, and economically important waterways. They do NOT cover the entire US coastline.

**Covered:**

| Coast | OFS model | Coverage |
|---|---|---|
| Entire Pacific coast | WCOFS | 24N–54N, ~4km — continuous coverage |
| Salish Sea + Columbia River | SSCOFS | Higher res in Puget Sound / Columbia |
| San Francisco Bay | SFBOFS | High res inside the bay |
| Gulf of Maine | GOMOFS | Maine to Cape Cod, ~700m |
| Chesapeake Bay + shelf | CBOFS | VA/MD coast |
| Delaware Bay + shelf | DBOFS | NJ/DE coast |
| NY/NJ Harbor | NYOFS | Port area only |
| Tampa Bay + shelf | TBOFS | Tampa/St. Pete area |
| Northern Gulf of Mexico | NGOFS2 | Panama City FL to western Louisiana |
| St. Johns River FL | SJROFS | Jacksonville area only |
| Cook Inlet AK | CIOFS | Anchorage area |
| Great Lakes | LMHOFS, LEOFS, LOOFS, LSOFS | All 5 lakes (Michigan+Huron combined) |

**NOT covered (significant gaps):**

| Gap | Miles of coast | What's there | Fallback |
|---|---|---|---|
| Cape Hatteras NC to Jacksonville FL | ~600 miles | Outer Banks, Myrtle Beach, Charleston, Savannah, Jacksonville beaches | RTOFS (8km) + MUR SST |
| Florida Atlantic coast (Jacksonville to Miami) | ~350 miles | Daytona, Palm Beach, Fort Lauderdale, Miami Beach | RTOFS + MUR SST |
| Florida Keys | ~150 miles | Key West, fishing/diving destinations | RTOFS + MUR SST |
| Gulf coast: western LA to TX/Mexico border | ~600 miles | Galveston, Corpus Christi, South Padre Island | RTOFS + MUR SST |
| Hawaii | All islands | Major beach/surf destination | PacIOOS ROMS (ERDDAP) |
| Caribbean (PR/USVI) | All islands | Beach destinations | CARICOOS FVCOM (ERDDAP) |
| Alaska (outside Cook Inlet) | Vast | Kodiak, Juneau, Sitka | RTOFS + MUR SST |

**Bottom line:** For the Pacific coast, the Great Lakes, and major East Coast ports, OFS provides excellent coverage. For the Southeast coast, Gulf coast west of Louisiana, Florida Atlantic coast, and Hawaii/Caribbean, the system falls back to RTOFS + MUR SST + regional ERDDAP models where available.

### How to use currents, salinity, and other OFS data

**Currents — simple reporting, not vector field maps.** From `u_eastward` and `v_northward` at a single grid point:
- Current speed: `sqrt(u² + v²)` → display as "1.2 kt"
- Current direction: `atan2(v, u)` → display as "flowing NNW"
- Report as a stat tile on boating/fishing tabs: "Current: 1.2 kt NNW"
- Forecast as a time series chart (like wind forecast)
- At-depth for fishing: "Current at 15m: 0.8 kt WSW"

We do NOT build vector field maps or current visualizations. If an operator wants spatial current maps in the future, third-party providers (e.g., Xweather maritime) offer that as a service. Not in scope now.

**Salinity — species scoring and reporting.**
- Report surface salinity on marine/boating detail tabs
- Feed salinity at species' target depth into the fishing scorer — species have salinity preferences (some prefer brackish water near river mouths, others avoid it)
- Near river mouths (e.g., Santa Ana River at Huntington Beach), salinity drops significantly and affects species presence
- Report as "Salinity: 33.2 PSU" stat tile

**Air pressure / wind / air temp from 2D files — supplementary.**
- These are the atmospheric forcing fields the model uses. They can supplement or validate the forecast provider data for marine locations.
- Not a replacement for the forecast provider — the forecast provider handles inland/station conditions. OFS atmospheric data is specifically over-ocean.
- Use case: when the forecast provider is unavailable, OFS `Pair`, `Tair`, `Uwind`/`Vwind` could fill the gap for marine locations.

---

## System Integration: Marine Ocean Data Resolver

### Design principle — provider agnostic

The dashboard never knows where ocean data came from. No card developer, no tab developer, no page developer ever thinks about OFS vs MUR SST vs RTOFS vs a pier sensor. The API exposes `waterTemp` as a float, `currentSpeed` as a float, `salinity` as a float. The source resolution happens entirely inside the API.

This is the same pattern as wind data: `windSpeed` on a card works whether the station hardware provided it or the forecast provider did. `is_station_served()` decides internally; the dashboard renders a number.

### Ocean data resolver — service layer component

New component: `services/ocean_data_resolver.py`

This is NOT a provider module. Providers fetch raw data from external sources. The resolver orchestrates the fallback chain across providers and normalizes the output. Endpoints call the resolver, not the providers directly.

The resolver handles ALL OFS-sourced data — temperature, salinity, currents, water levels — not just water temp. One resolver call returns everything the endpoint needs from ocean model data, because it all comes from the same OFS file.

```python
class OceanDataResult:
    # Temperature
    surface_temp: float | None        # Celsius, pre-conversion
    column_profile: list[dict] | None # [{"depth_m": 0, "temp_c": 18.2, "salt_psu": 33.5}, ...]
    thermocline_depth_m: float | None
    bottom_temp_c: float | None
    seafloor_depth_m: float | None

    # Currents
    surface_current_speed: float | None   # m/s
    surface_current_dir: float | None     # degrees true north
    current_profile: list[dict] | None    # [{"depth_m": 0, "speed_ms": 0.4, "dir_deg": 315}, ...]

    # Salinity
    surface_salinity: float | None        # PSU

    # Water levels (modeled — includes storm surge, supplementary to CO-OPS)
    water_level_msl: float | None         # meters above MSL
    water_level_mllw: float | None        # meters above MLLW

    # Forecast (surface temp + currents over time)
    forecast: list[dict] | None           # [{"time": iso8601, "temp_c": ..., "current_speed": ..., ...}, ...]

    # Metadata
    source: str                           # "ofs:WCOFS", "rtofs", "mur_sst", etc.
    source_type: str                      # "modeled" or "observed"
    timestamp: str                        # ISO 8601
    coverage_tier: str                    # tells the endpoint what data to expect
```

### The `coverage_tier` field — graceful degradation

When a location falls outside OFS coverage, the resolver returns less data. The `coverage_tier` field tells the endpoint what it got, so the endpoint populates the response without branching on provider names — it just checks which fields are non-null:

| `coverage_tier` | What's populated | What's null | Typical location |
|---|---|---|---|
| `"ofs"` | Everything — temp, column, salinity, currents, water levels, forecast | Nothing | Pacific coast, Chesapeake Bay, Great Lakes |
| `"regional_erddap"` | Temp, column, salinity, forecast | Currents, water levels (model-dependent) | Hawaii (PacIOOS), Caribbean (CARICOOS) |
| `"rtofs"` | Temp, column, currents, salinity, forecast (coarser: 8km, 41 levels) | Water levels (RTOFS doesn't provide MLLW-referenced levels) | SE Atlantic, Gulf coast, remote Alaska |
| `"mur_sst"` | Surface temp only | Column, salinity, currents, water levels, forecast | Anywhere — last resort surface temp |
| `"observed"` | Surface temp only (from physical sensor) | Everything else | When `mode="observed"` and sensor exists |
| `"unavailable"` | Nothing | Everything | All sources failed |

The endpoint checks field presence, never coverage tier:

```python
ocean = resolver.resolve(lat, lon, config)

response.waterTemp = convert(ocean.surface_temp, ...)  # always attempt

if ocean.column_profile:
    response.waterColumnProfile = [convert_layer(l) for l in ocean.column_profile]
if ocean.surface_current_speed is not None:
    response.currentSpeed = ocean.surface_current_speed
    response.currentDirection = ocean.surface_current_dir
if ocean.surface_salinity is not None:
    response.salinity = ocean.surface_salinity
```

Fields that aren't available for this location's coverage tier are null, and the dashboard handles null the same way it handles any other missing data — graceful "—" display.

### Two query modes

```python
def resolve(
    lat: float,
    lon: float,
    location_config: dict,     # ofs_model, ofs_fallback, ofs_region from api.conf
    mode: str = "modeled",     # "modeled" or "observed"
    needs: str = "surface",    # "surface" or "full"
) -> OceanDataResult:
```

**`mode="modeled"` (default):** Run the standard tier chain. Every consumer uses this unless it specifically wants a sensor reading.

```
1. location_config.ofs_model set?
   → OFS provider: fetch surface + column + forecast
   → If fails: try ofs_fallback
   → If fails: continue

2. location_config.ofs_region set? (PacIOOS / CARICOOS)
   → ERDDAP regional model provider
   → If fails: continue

3. Global fallback — split by `needs`:
   needs="full":
     → RTOFS via ERDDAP (temp column + currents + salinity, 41 levels)
     → coverage_tier = "rtofs"
     → If fails: MUR SST surface only → coverage_tier = "mur_sst"
     → If fails: coverage_tier = "unavailable"

   needs="surface":
     → MUR SST via ERDDAP (surface temp only, 1km)
     → coverage_tier = "mur_sst"
     → If fails: RTOFS surface layer → coverage_tier = "rtofs"
     → If fails: coverage_tier = "unavailable"
```

**`mode="observed"`:** Look for a real sensor reading. Does NOT fall back to models — if the caller asks for observed and there's no sensor, they get null, because the answer is "no observation available," not a modeled substitute.

```
1. On-premises sensor at this location? (operator's station or CO-OPS gauge
   within the on-premises threshold distance configured in api.conf)
   → Return sensor reading (surface only — sensors don't do depth profiles)

2. NDBC buoy within configured max observation distance?
   → Return buoy reading, tagged with distance and station ID
   → e.g., source: "observed:ndbc:46253:12.3mi"

3. No sensor in range → return null
   (caller can then decide whether to show "No observation available"
    or fall back to calling resolve again with mode="modeled")
```

### How each consumer uses the resolver

No consumer needs to know the internal source or coverage tier. The endpoint calls the resolver and populates whichever response fields came back non-null:

| Endpoint | Resolver call | What it uses from the result |
|---|---|---|
| `GET /marine` (card list) | `resolve(needs="surface")` | `surface_temp` → `currentConditions.waterTemp` |
| `GET /marine/{id}` (detail) | `resolve(needs="full")` | All fields — temp, column, currents, salinity, water levels, forecast |
| `GET /surf/{id}` | `resolve(needs="surface")` | `surface_temp` → wetsuit recommendation |
| `GET /fishing/{id}` | `resolve(needs="full")` | Column profile → species scorer. Currents, salinity → conditions scoring. Thermocline → display. |
| `GET /beach-safety/{id}` | `resolve(needs="surface")` | `surface_temp` → comfort classification |
| `GET /tides/{id}` | `resolve(needs="full")` | `water_level_msl`/`water_level_mllw` → supplementary to CO-OPS predictions (when OFS available) |
| Any endpoint, optional | `resolve(mode="observed")` | `surface_temp` → `observedWaterTemp` supplementary field |

### Canonical data models (new)

Add to `models/responses.py`:

```python
class WaterColumnLayer:
    depth_m: float
    temperature: float      # operator display units (after convert())
    salinity: float | None  # PSU (no conversion needed)

class WaterColumnProfile:
    layers: list[WaterColumnLayer]
    thermocline_depth_m: float | None
    bottom_temp: float | None
    seafloor_depth_m: float | None
    source: str
    timestamp: str

class OceanCurrentSnapshot:
    speed: float            # operator display units
    direction: float        # degrees true north
    depth_m: float | None   # null = surface

class OceanForecastPoint:
    time: str               # ISO 8601
    surface_temp: float     # operator display units
    current_speed: float | None
    current_direction: float | None
    source: str
```

### Unit conversion

- Temperature: all providers return Celsius → `convert(value, "degree_C", target_temp_unit)`
- Current speed: m/s → knots via `convert(value, "meter_per_second", target_speed_unit)`
- Salinity: PSU — no conversion, universal unit
- Water levels: meters → operator's `group_water_level` via `convert()`
- Same enrichment pipeline as every other field. No special handling.

### Source attribution

Every response that includes ocean data carries source fields in the `sources` block:

```json
{
  "sources": {
    "ocean": "NOAA OFS (WCOFS)",
    "oceanMode": "modeled",
    "oceanCoverageTier": "ofs"
  }
}
```

When observed:
```json
{
  "sources": {
    "ocean": "NOAA CO-OPS Station 9410660 (Los Angeles)",
    "oceanMode": "observed",
    "oceanDistance": "0.3 mi"
  }
}
```

Fallback:
```json
{
  "sources": {
    "ocean": "NOAA RTOFS + NASA MUR SST",
    "oceanMode": "modeled",
    "oceanCoverageTier": "rtofs"
  }
}
```

Dashboard uses `oceanCoverageTier` only for attribution display text, never for branching logic.

---

## Setup Wizard: Data Coverage Panel

When an operator configures a marine location (selects a lat/lon), the setup wizard displays a **Data Coverage** panel showing exactly what data sources are available for that point. This serves two purposes: (1) the operator understands what level of data their location will get, and (2) when an operator reports accuracy issues, support can ask "what does the coverage panel show?" to diagnose the data tier.

### Panel content (computed at location selection time)

| Section | What it shows | How it's determined |
|---|---|---|
| **OFS Model** | Model name + resolution, or "None — outside OFS coverage" | Bounding box check against the 15 OFS domains |
| **Coverage Tier** | "Full ocean model" / "Regional model" / "Global fallback (RTOFS)" / "Surface only (MUR SST)" | Based on OFS assignment + regional ERDDAP check |
| **Available Data** | Checkmarks: ✓ Water column profile, ✓ Currents, ✓ Salinity, ✓ Modeled water levels, ✓ Surface temp, ✓ Forecast | Derived from coverage tier |
| **Nearest CO-OPS Station** | Station name, ID, distance, water temp capability yes/no | CO-OPS metadata API query |
| **Nearest NDBC Buoy** | Station ID, distance, depth, what it reports | NDBC station list lookup |
| **NWS Marine Zone** | Zone ID + name | Existing NWS zone discovery (§14.8) |
| **NWPS WFO** | WFO identifier | Existing NWPS WFO lookup |
| **On-Premises Sensor** | "Within threshold" / "Not configured" / "Too far" | `is_station_served()` check |

### Example panel display

```
┌─ Data Coverage ──────────────────────────────────────┐
│                                                       │
│  OFS Model:    WCOFS (West Coast, ~4km)               │
│  Coverage:     Full ocean model                       │
│                                                       │
│  Available:    ✓ Water column profile (41 levels)     │
│                ✓ Ocean currents                       │
│                ✓ Salinity                             │
│                ✓ Modeled water levels                 │
│                ✓ Surface temperature                  │
│                ✓ 72-hour forecast                     │
│                                                       │
│  Nearest CO-OPS:  9410580 Newport Beach (8.2 mi)     │
│                   Water temp: Yes                     │
│  Nearest NDBC:    46253 San Pedro Channel (12.1 mi)  │
│                   Depth: 66m (offshore)               │
│  NWS Zone:        PZZ673                             │
│  NWPS WFO:        LOX                                │
│  On-Premises:     Within threshold (0.3 mi)          │
│                                                       │
└───────────────────────────────────────────────────────┘
```

For a location outside OFS coverage (e.g., Myrtle Beach, SC):

```
┌─ Data Coverage ──────────────────────────────────────┐
│                                                       │
│  OFS Model:    None — outside OFS coverage            │
│  Coverage:     Global fallback (RTOFS 8km + MUR SST)  │
│                                                       │
│  Available:    ✓ Water column profile (41 levels)     │
│                ✓ Ocean currents (coarse)              │
│                ✓ Salinity (coarse)                    │
│                ✗ Modeled water levels                 │
│                ✓ Surface temperature (1km MUR SST)    │
│                ✓ 8-day forecast (RTOFS)               │
│                                                       │
│  Nearest CO-OPS:  8661070 Springmaid Pier (2.1 mi)   │
│                   Water temp: Yes                     │
│  Nearest NDBC:    41004 Edisto (120 mi, offshore)     │
│  NWS Zone:        AMZ252                             │
│  NWPS WFO:        ILM                                │
│  On-Premises:     Not configured                     │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Implementation

The coverage panel is a setup-time-only computation. It calls the same bounding box check and station distance lookups that the resolver uses for OFS assignment. The panel data is computed by `GET /setup/marine/coverage?lat={lat}&lon={lon}` — a new setup endpoint that returns the coverage analysis as JSON. The wizard renders it.

The panel data is also persisted in the location config alongside `ofs_model`, `ofs_fallback`, etc. — so it's available for diagnostics without re-querying.

---

## Provider Modules Needed

| Module | Protocol | Domain | Serves |
|---|---|---|---|
| `providers/ocean/ofs.py` | THREDDS/OPeNDAP (`xarray` + `netCDF4`) | `ocean` | NOAA OFS — surface + water column + currents + salinity + water levels + forecast. Primary modeling source. |
| `providers/ocean/erddap_ocean.py` | ERDDAP griddap (HTTP) | `ocean` | MUR SST (surface), RTOFS (column + forecast), PacIOOS, CARICOOS. Config-driven per dataset. |
| `services/ocean_data_resolver.py` | Internal (calls providers) | — | Orchestrates fallback chain, normalizes output. Not a provider — a service. |
| `endpoints/setup.py` addition | Internal | — | `GET /setup/marine/coverage` — coverage panel data for the wizard. |

The resolver is the only component that knows the fallback order. Providers just fetch data. Endpoints just consume normalized results.

---

## Impact on MARINE-CARD-DATA-SOURCE-PLAN.md

1. **ADR-091 Decision 1** — waterTemp row: NDBC buoy → on-premises / OFS / MUR SST / RTOFS hierarchy
2. **ADR-091 new decision** — OFS as primary ocean data source, not just water temp. Currents, salinity, modeled water levels all come from the same OFS files.
3. **New provider** — `providers/ocean/ofs.py` via THREDDS (primary modeling source, build first)
4. **New provider** — `providers/ocean/erddap_ocean.py` via ERDDAP (MUR SST + RTOFS + regional models, config-driven)
5. **New service** — `services/ocean_data_resolver.py` (fallback chain orchestration, normalization)
6. **New setup endpoint** — `GET /setup/marine/coverage` for the wizard Data Coverage panel
7. **Phase 3** (STOFS-2D-Global) — likely replaced by OFS `zeta`/`zetatomllw` water levels from the same model files. Research needed on OFS water level accuracy vs CO-OPS harmonic predictions before committing.
8. **Fishing tab** — water column profiles, salinity, depth-specific species scoring all enabled by OFS/RTOFS column data
9. **Boating tab** — ocean currents (speed + direction) as new data
10. **T1.2** (waterTemp unit conversion) — still needed, source changes from NDBC to resolver output
11. **New dependency** — `xarray` and `netCDF4` for THREDDS/OPeNDAP access (add to `[marine]` pip extra)
12. **Setup wizard** — Data Coverage panel showing OFS assignment, coverage tier, nearest stations, available data

### Open research items

- **OFS water levels vs CO-OPS tide predictions:** How well does OFS `zetatomllw` perform as per-location tidal information? Can it provide differentiated water levels for locations 2km apart (which CO-OPS cannot)? Needs side-by-side comparison before replacing or supplementing CO-OPS.
- **Current visualization:** Simple speed + direction reporting is in scope. Vector field maps are not — third-party providers (Xweather maritime) offer this if needed later.

---

## Data Source Summary

| Product | Type | Resolution | Depth | Forecast | Coverage | Access | Role |
|---|---|---|---|---|---|---|---|
| NOAA OFS (15 models) | Coastal ocean model | 34m–4km | 10–40 levels | 48–120hr | Major US coasts | THREDDS | **Primary** — most accurate nearshore |
| NASA MUR SST | Satellite analysis | 1km | Surface only | None | Global | ERDDAP | **Surface fallback** — cards, beach safety |
| NOAA RTOFS | Global ocean model | 8km | 41 levels | 8-day | Global | ERDDAP | **Column + forecast fallback** — fishing, marine |
| PacIOOS ROMS | Regional model | 4km | 36 levels | 3-day | Hawaii/Pacific | ERDDAP | **Supplement** — Hawaii coverage |
| CARICOOS FVCOM | Regional model | 800m | 11 levels | 3-day | PR/USVI | ERDDAP | **Supplement** — Caribbean coverage |
| CO-OPS stations | In-situ sensor | Point | 1–2m | None | 239 US stations | REST API | **On-premises only** — when sensor is at the location |
| NDBC buoys | In-situ sensor | Point | Surface | None | Offshore | REST API | **Demoted** — labeled offshore reference only |
