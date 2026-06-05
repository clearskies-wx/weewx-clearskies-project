# 7Timer! API Reference

Captured: 2026-06-04 from https://www.7timer.info/doc.php?lang=en
Live response verified against: https://www.7timer.info/bin/api.pl?lon=-117.98&lat=33.66&product=astro&output=json

## Overview

7Timer! is a free, open-source meteorological forecast service derived from NOAA/NCEP's Global Forecast System (GFS). It covers ~1.5 million geographic points globally with updates four times daily.

**No API key required.** No registration needed.

**Usage restriction:** "you can use or redistribute them as long as you are not using them for commercial purpose." Operators using Clear Skies commercially should be aware of this restriction.

**Notification requested:** "Program developers are asked to notify me when using the data so I can track the server workload."

**No documented rate limits** for the data API itself. (Google Geocoding limit of 2,500/day applies only to the web UI, not the data API.)

---

## ASTRO Product (Primary — Astronomical Observations)

### Endpoint

```
GET http://www.7timer.info/bin/api.pl?lon={lon}&lat={lat}&product=astro&output=json
```

### Query Parameters

| Param | Required | Type | Description |
|-------|----------|------|-------------|
| `lon` | Yes | float | Longitude (e.g., -117.98). Precision: 0.001 |
| `lat` | Yes | float | Latitude (e.g., 33.66). Precision: 0.001 |
| `product` | Yes | string | `astro` for astronomical forecast |
| `output` | Yes | string | `json` or `xml` |
| `ac` | No | int | Altitude correction: 0 (default), 2, or 7 |

### Response Format

```json
{
  "product": "astro",
  "init": "2026060412",
  "dataseries": [
    {
      "timepoint": 3,
      "cloudcover": 1,
      "seeing": 2,
      "transparency": 4,
      "lifted_index": 10,
      "rh2m": 10,
      "wind10m": { "direction": "SW", "speed": 2 },
      "temp2m": 17,
      "prec_type": "none"
    }
  ]
}
```

### Field: `init`

Model initialization time. Format: `YYYYMMDDHH` (UTC). Updates 4x daily (00, 06, 12, 18 UTC).

### Field: `timepoint`

Hours from init time. ASTRO product provides 3-hour intervals for 3 days (timepoint 3, 6, 9, ... 72).

### Field: `cloudcover` (1-9)

| Value | Coverage | Percentage |
|-------|----------|------------|
| 1 | 0%-6% | Clear |
| 2 | 6%-19% | |
| 3 | 19%-31% | |
| 4 | 31%-44% | |
| 5 | 44%-56% | |
| 6 | 56%-69% | |
| 7 | 69%-81% | |
| 8 | 81%-94% | |
| 9 | 94%-100% | Overcast |

### Field: `seeing` (1-8) — Astronomical Seeing

**Lower values = better seeing.** Derived from atmospheric turbulence modeling in GFS.

| Value | Arcseconds | Quality |
|-------|-----------|---------|
| 1 | < 0.5" | Perfect |
| 2 | 0.5" - 0.75" | Excellent |
| 3 | 0.75" - 1.0" | Good |
| 4 | 1.0" - 1.25" | Fair |
| 5 | 1.25" - 1.5" | Moderate |
| 6 | 1.5" - 2.0" | Poor |
| 7 | 2.0" - 2.5" | Very Poor |
| 8 | > 2.5" | Severe |

**Note:** This measures upper-atmosphere turbulence only. Does NOT capture ground-layer seeing (telescope thermal, local terrain effects). Should be labeled "Upper Atmospheric Stability" in UI.

### Field: `transparency` (1-8) — Atmospheric Transparency

**Lower values = better transparency.** Measures sky clarity — scattering/absorption from moisture, dust, aerosols.

| Value | Mag/Airmass | Quality |
|-------|-----------|---------|
| 1 | < 0.3 | Pristine |
| 2 | 0.3 - 0.4 | Clear |
| 3 | 0.4 - 0.5 | Good |
| 4 | 0.5 - 0.6 | Fair |
| 5 | 0.6 - 0.7 | Hazy |
| 6 | 0.7 - 0.85 | Poor |
| 7 | 0.85 - 1.0 | Very Poor |
| 8 | > 1.0 | Obscured |

**Planetary viewing note:** Transparency has minimal impact on bright planetary targets. A night with seeing=1 and transparency=5 is still excellent for planets. Weight transparency at < 5% in planetary viewing formulas.

### Field: `lifted_index`

Atmospheric stability indicator. Negative values = unstable (convective).

| Value | Range | Meaning |
|-------|-------|---------|
| -10 | below -7 | Very unstable |
| -6 | -7 to -5 | Unstable |
| -4 | -5 to -3 | Slightly unstable |
| -1 | -3 to 0 | Near neutral |
| 2 | 0 to 4 | Slightly stable |
| 6 | 4 to 8 | Stable |
| 10 | 8 to 11 | Very stable |
| 15 | over 11 | Extremely stable |

### Field: `rh2m` (Relative Humidity at 2m)

16-point scale:

| Value | RH% |
|-------|-----|
| -4 | 0%-5% |
| -3 | 5%-10% |
| -2 | 10%-15% |
| -1 | 15%-20% |
| 0 | 20%-25% |
| 1 | 25%-30% |
| ... | ... |
| 16 | 100% |

Formula: `RH% = (value + 4) * 5` (approximate midpoint)

### Field: `wind10m`

Object with `direction` (cardinal: N, NE, E, SE, S, SW, W, NW) and `speed` (1-8 Beaufort-derived scale):

| Value | Speed Range | Description |
|-------|-----------|-------------|
| 1 | < 0.3 m/s | Calm |
| 2 | 0.3 - 3.4 m/s | Light |
| 3 | 3.4 - 8.0 m/s | Moderate |
| 4 | 8.0 - 10.8 m/s | Fresh |
| 5 | 10.8 - 17.2 m/s | Strong |
| 6 | 17.2 - 24.5 m/s | Gale |
| 7 | 24.5 - 32.6 m/s | Storm |
| 8 | > 32.6 m/s | Hurricane |

### Field: `temp2m`

Temperature at 2m in degrees Celsius. Range: -76 to +60.

### Field: `prec_type`

Precipitation type: `none`, `rain`, `snow`, `frzr` (freezing rain), `icep` (ice pellets).

### Undefined Values

All fields use `-9999` for undefined/unavailable data.

---

## METEO Product (Also has seeing/transparency)

The METEO product also includes `seeing` and `transparency` with the same scales as ASTRO, plus additional meteorological data: wind/humidity profiles at pressure levels (950-200 hPa), MSL pressure, snow depth, and cloud layering (total/high/mid/low). 8-day forecast range vs ASTRO's 3-day.

Endpoint: same URL with `product=meteo`.

---

## Data Characteristics

- **Model source:** NOAA/NCEP GFS
- **Spatial resolution:** ~20 km (0.25° GFS grid)
- **Temporal resolution:** 3-hour intervals
- **Forecast range:** 3 days (ASTRO), 8 days (METEO/CIVIL)
- **Update frequency:** 4x daily (00, 06, 12, 18 UTC)
- **Coverage:** Global

---

## Example Response (Huntington Beach, CA — 2026-06-04)

```json
{
  "product": "astro",
  "init": "2026060412",
  "dataseries": [
    {"timepoint":3,"cloudcover":1,"seeing":2,"transparency":4,"lifted_index":10,"rh2m":10,"wind10m":{"direction":"SW","speed":2},"temp2m":17,"prec_type":"none"},
    {"timepoint":6,"cloudcover":1,"seeing":2,"transparency":3,"lifted_index":6,"rh2m":6,"wind10m":{"direction":"SW","speed":2},"temp2m":23,"prec_type":"none"},
    {"timepoint":9,"cloudcover":1,"seeing":2,"transparency":3,"lifted_index":6,"rh2m":7,"wind10m":{"direction":"SW","speed":3},"temp2m":24,"prec_type":"none"},
    {"timepoint":12,"cloudcover":1,"seeing":2,"transparency":3,"lifted_index":6,"rh2m":7,"wind10m":{"direction":"S","speed":3},"temp2m":23,"prec_type":"none"},
    {"timepoint":15,"cloudcover":1,"seeing":4,"transparency":5,"lifted_index":15,"rh2m":13,"wind10m":{"direction":"S","speed":2},"temp2m":21,"prec_type":"none"},
    {"timepoint":18,"cloudcover":1,"seeing":5,"transparency":4,"lifted_index":15,"rh2m":14,"wind10m":{"direction":"S","speed":2},"temp2m":18,"prec_type":"none"},
    {"timepoint":21,"cloudcover":1,"seeing":6,"transparency":4,"lifted_index":15,"rh2m":13,"wind10m":{"direction":"SW","speed":2},"temp2m":17,"prec_type":"none"},
    {"timepoint":24,"cloudcover":1,"seeing":6,"transparency":3,"lifted_index":15,"rh2m":13,"wind10m":{"direction":"S","speed":2},"temp2m":17,"prec_type":"none"}
  ]
}
```

Interpretation of this forecast: Tonight (timepoints 15-24 = evening through midnight) has clear skies (cloudcover=1) but seeing degrades from fair (4) to poor (6) — significant upper-atmosphere turbulence despite calm surface conditions. Transparency fair to good. Not ideal for high-magnification planetary observation despite the clear sky.
