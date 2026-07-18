# SWAN Command Reference Extract

Extracted from SWAN User Manual v41.45 for agent use. Only the commands and quantities needed for Clear Skies are included.

## CURVE — define output locations along a curve

Syntax:
```
CURVE 'sname' [xp1] [yp1] < [int] [xp] [yp] >
```

- `'sname'` — name of this output set (max 8 chars), used by TABLE/SPECOUT
- `[xp1] [yp1]` — coordinates of the first point (in problem coordinates, i.e., lon/lat for spherical)
- `< [int] [xp] [yp] >` — repeatable: `[int]` = number of output points between previous point and `[xp] [yp]`. The total number of output points = sum of all `[int]` values + 1.

Example (10 points along a cross-shore transect):
```
CURVE 'hb_pier' -117.9950 33.6350 9 -117.9900 33.6300
```
This creates 10 output points (9 intervals + 1) from (-117.9950, 33.6350) to (-117.9900, 33.6300).

## TABLE — write output quantities at output locations

Syntax:
```
TABLE 'sname' HEAD|NOHEAD 'fname' [quantity1] [quantity2] ... OUTPUT [tbeg] [delt] MIN|HR|DAY
```

- `'sname'` — name of the output set defined by CURVE or POINTS
- `HEAD` — include header lines (recommended for parsing)
- `'fname'` — output filename
- quantities — space-separated list of SWAN output quantity names
- `OUTPUT` — followed by time window specification

## SPECOUT — write spectral output

Syntax:
```
SPECOUT 'sname' SPEC2D ABS 'fname' OUTPUT [tbeg] [delt] MIN|HR|DAY
```

- `'sname'` — name of the output set (POINTS or CURVE)
- `SPEC2D` — two-dimensional spectrum (frequency × direction)
- `ABS` — absolute frequencies (not relative)
- `'fname'` — output filename

## POINTS — define isolated output points

Syntax:
```
POINTS 'sname' [xp] [yp]
POINTS 'sname' FILE 'fname'
```

## Output quantity names (for TABLE command)

| Quantity name | What it is | Units |
|---|---|---|
| `HSIGN` | Significant wave height (Hs) | m |
| `HSWELL` | Swell-only significant wave height. Requires `[fswell]` frequency cutoff (default 0.1 Hz). Only the energy below `[fswell]` contributes. | m |
| `TM01` | Mean absolute wave period | s |
| `DIR` | Mean wave direction (nautical convention, coming from) | degrees |
| `DEPTH` | Water depth (positive = wet) | m |
| `QB` | Fraction of breaking waves (0–1). 0 = no breaking, 1 = all waves breaking. | dimensionless |
| `DISSURF` | Energy dissipation rate due to depth-induced wave breaking | W/m² |
| `SETUP` | Wave-induced water level setup | m |
| `DSPR` | Directional spreading of the wave spectrum | degrees |
| `XP` | X-coordinate of output point | degrees (spherical) |
| `YP` | Y-coordinate of output point | degrees (spherical) |
| `TIME` | Output time | YYYYMMDD.HHmmss |
| `DIST` | Distance along a CURVE from the first point | m |

## QUANTITY — set output parameters

To set the swell frequency cutoff for HSWELL:
```
QUANTITY HSWELL fswell=0.1
```
Default fswell = 0.1 Hz (period = 10s). Waves with frequency < fswell are classified as swell.

## Exception value

```
QUANTITY HSIGN TM01 DIR excv=-9.
```
Sets the no-data sentinel value. Points with this value are dry land or have no spectral energy.

## SPECOUT file format (for parsing)

The SPECOUT file contains one spectrum per output time per output location. Each spectrum block:
1. Header line with time stamp
2. Frequency axis: `nf` frequency bins
3. Direction axis: `nd` direction bins
4. Energy density matrix: `nf` rows × `nd` columns (units: m²/Hz/deg or m²/Hz/rad)

The spectrum can be decomposed into swell systems by finding peaks in the (frequency, direction) space.
