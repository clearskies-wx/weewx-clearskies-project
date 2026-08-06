# SWAN Command Reference Extract

> **FROZEN — operator ruling 2026-08-06.** This file is a pure extract of the SWAN User Manual
> (v41.51, `docs/reference/swan-user-manual.txt`). It MAY NOT BE AMENDED without the operator's
> direct authorization, and it MAY NOT contain any language that is not present in the SWAN
> manual. Project-specific usage, measured corrections, and design decisions live in the
> authorized manuals (PROVIDER-MANUAL.md, ARCHITECTURE.md) — never here. (Content history:
> project-specific material accumulated 2026-07-25..08-01 was moved out on this date.)

Extracted from the SWAN User Manual for agent use. Only the commands and quantities needed for
Clear Skies are included. Every retained section cites the manual page(s) it is drawn from —
`docs/reference/swan-user-manual.txt` is the source of truth; consult it directly for anything
not covered here.

## CURVE — define output locations along a curve

Syntax (manual p.90-91):
```
CURVE 'sname' [xp1] [yp1] < [int] [xp] [yp] >
```

- `'sname'` — name of this output set (max 8 chars), used by TABLE/SPECOUT
- `[xp1] [yp1]` — coordinates of the first point (in problem coordinates, i.e., lon/lat for spherical)
- `< [int] [xp] [yp] >` — repeatable: `[int]` = number of subdivisions between the previous corner
  point and `[xp] [yp]`. SWAN generates output at `[int]-1` equidistant locations between two
  subsequent corner points of the curve, in addition to the corner points themselves.

Example (10 points along a straight line):
```
CURVE 'trans1' 0.0 0.0 9 1.0 1.0
```
This creates 10 output points (8 interior + 2 corner points) from (0.0, 0.0) to (1.0, 1.0).

The manual also defines pre-defined curves `BOUNDARY` (whole outer boundary) and `BOUND 01`,
`BOUND 02`, etc. (parts of the boundary) that do not require a CURVE command.

## TABLE — write output quantities at output locations

Syntax (manual p.107-108):
```
TABLE 'sname' HEADER|NOHEADER|INDEXED 'fname' [quantity1] [quantity2] ... (OUTPUT [tbegtbl] [delttbl] SEC|MIN|HR|DAY)
```

- `'sname'` — name of the output set defined by CURVE, POINTS, FRAME, or GROUP
- `HEADER` — fixed-format output with header lines giving name and unit per column (4 header lines)
- `NOHEADER` — floating-point output with no headers, for processing by other programs
- `INDEXED` — a table usable directly as GIS input; requires two separate TABLE commands (one for XP/YP, one for the other quantities)
- `'fname'` — output filename (required for NOHEADER)
- quantities — space-separated list of SWAN output quantity names (same set as command BLOCK)
- `OUTPUT [tbegtbl] [delttbl] SEC|MIN|HR|DAY` — optional; without it, SWAN gives output for the last computed time step only

## SPECOUT — write spectral output

Syntax (manual p.108-109):
```
SPECOUT 'sname' SPEC2D|SPEC1D ABS|REL 'fname' (OUTPUT [tbegspc] [deltspc] SEC|MIN|HR|DAY)
```

- `'sname'` — name of the output set (POINTS, CURVE, FRAME, or GROUP)
- `SPEC2D` — two-dimensional (frequency-direction) spectrum; `SPEC1D` — one-dimensional (frequency) spectrum
- `ABS` — absolute frequency (measured at a fixed point); `REL` — relative frequency (measured moving with the current)
- `'fname'` — output filename; format described in Appendix D. A `.nc` extension generates netCDF.
- `OUTPUT [tbegspc] [deltspc] SEC|MIN|HR|DAY` — optional; without it, output is for the last computed time step only

## POINTS — define isolated output points

Syntax (manual p.92-93):
```
POINTS 'sname' < [xp] [yp] >
POINTS 'sname' FILE 'fname'
```

- `'sname'` — name of the points
- `[xp] [yp]` — problem coordinates of one output location (repeatable)
- `FILE 'fname'` — read output locations from a file instead

## Output quantity names (for TABLE/BLOCK commands)

Manual Appendix A, p.101-106:

| Quantity name | What it is | Units |
|---|---|---|
| `HSIGN` | Significant wave height (Hs) | m |
| `HSWELL` | Swell wave height. Uses the `[fswell]` frequency cutoff set by QUANTITY (default 0.1 Hz). | m |
| `TM01` | Mean absolute wave period | s |
| `DIR` | Mean wave direction (Cartesian or Nautical convention, per command SET) | degrees |
| `DEPTH` | Water depth (not the bottom level) | m |
| `QB` | Fraction of breaking waves due to depth-induced breaking | dimensionless |
| `DISSURF` | Energy dissipation due to surf breaking | W/m² or m²/s (per command SET) |
| `SETUP` | Set-up due to waves | m |
| `DSPR` | Directional spreading of the waves | degrees |
| `XP` | X-coordinate of the output location in the problem coordinate system | — |
| `YP` | Y-coordinate of the output location in the problem coordinate system | — |
| `TIME` | Full date-time string; TABLE only, useful only for nonstationary computations | — |
| `DIST` | Distance along a CURVE from the first point, measured to the output location | m |

## Spectral partitioning output (PT* quantities)

Manual p.106: partitioning of wave spectra is based on the **watershed algorithm of Hanson and
Phillips (2001)**. The first partition is due to wind sea; the remaining partitions are the swell,
ordered from highest to lowest significant wave height. **There will be at most 10 partitions.**

| Keyword | What it is | Units |
|---|---|---|
| `PTHSIGN` | Partition significant wave height | m |
| `PTRTP` | Partition relative peak period | s |
| `PTWLEN` | Partition average wave length | m |
| `PTDIR` | Partition peak wave direction | degrees |
| `PTDSPR` | Partition directional spreading | degrees |
| `PTWFRAC` | Partition wind fraction — the fraction of that partition actively forced by wind | dimensionless |
| `PTSTEEP` | Partition wave steepness | dimensionless |

There is also `PARTIT`, a separate command (not a TABLE/BLOCK quantity name): it instructs SWAN
to generate a raw spectral partition file for wave-system-tracking post-processing. **`PARTIT`
cannot be used as an output parameter in TABLE** (manual p.106), and when used in BLOCK it must
not be combined with other parameters — coordinates, depth, wind, current, Hs, Tp, wave direction,
directional spreading, and wave length are automatically included.

## INITIAL HOTSTART — warm-start from a previous run's HOTFILE

Syntax (manual p.56-57):
```
INITial < HOTStart < MULTiple > 'fname' < FREE        >
                    | SINGle  |          | UNFormatted
```

- `SINGLE` — read from one (concatenated) hotfile.
- `MULTIPLE` — read the per-process hotfiles produced by a previous **parallel MPI** run. The
  number of files equals the number of processors, and the present run must use the same number
  of processors. **This is the manual's default option** (marked with the `->` default-indicator
  in the command syntax, per the manual's own notational convention).
- `FREE` — hotfile read with free format (the default).
- `UNFORMATTED` — hotfile is binary.
- Only meant for structured grids.

This command can be used to specify initial values for a stationary (INITIAL HOTSTART only) or
nonstationary computation, overriding SWAN's default initialization. If the previous run was
nonstationary, the time found on the hotfile is assumed to be the initial time of computation.
The computational grid (geographic and spectral) must be identical to the run in which the
initial wave field was computed.

## QUANTITY — set output parameters

To set the swell frequency cutoff for HSWELL (manual p.95-96):
```
QUANTITY HSWELL fswell=0.1
```
Default `[fswell]` = 0.1 Hz. Frequencies below `[fswell]` are classified as swell for the HSWELL quantity.

## Exception value

```
QUANTITY HSIGN TM01 DIR excv=-9.
```
`[excv]` sets the value written when there is no valid value for that output quantity at a point
(e.g. wave height at a dry point). The manual's own example for the significant wave height
default is `-9` (p.94).

## NGRID — define nested grid output boundary

Syntax (manual p.93-94):
```
NGRID 'sname' [xpn] [ypn] [alpn] [xlenn] [ylenn] [mxn] [myn]
```

- `'sname'` — name for this output grid (referenced by NESTOUT)
- `[xpn] [ypn]` — origin coordinates of the nested grid rectangle, in the problem coordinate system
- `[alpn]` — direction of positive x-axis of the nested grid (degrees, Cartesian convention)
- `[xlenn] [ylenn]` — lengths of the rectangle in x and y (in problem coordinates)
- `[mxn] [myn]` — number of meshes in x and y (one less than the number of grid points); SWAN
  interpolates if these differ from the nested computation's own mesh counts

Command NESTOUT is required after NGRID to generate the boundary data for the subsequent nested
run — NGRID only defines the output-location set, of type NGRID (an outline, not a region).

## NESTOUT — write boundary spectra for a child grid

Syntax (manual p.109):
```
NESTOUT 'sname' 'fname' OUTPUT [tbegnst] [deltnst] SEC|MIN|HR|DAY
```

- `'sname'` — name matching a previously defined NGRID
- `'fname'` — output file for 2D boundary spectral data, format per Appendix D
- `[tbegnst]` — begin time
- `[deltnst]` — time interval between boundary outputs

## BOUNDNEST1 — read boundary spectra from a parent grid

Syntax (manual p.52):
```
BOUNDNEST1 NEST 'fname' CLOSED|OPEN
```

- `'fname'` — file created by a previous coarse-grid SWAN run's NESTOUT command
- `CLOSED` — the nesting boundary is a closed rectangle (this is the manual's default)
- `OPEN` — boundary is not closed

The CGRID command must precede BOUNDNEST1. The computational grid for the nested run is the area
bounded by the coarse run's nest (its NGRID boundary points) — the boundaries of the coarse run's
nest and the nested run's computational area should be (nearly) identical. The spectral
frequencies/directions of the two runs do not need to coincide; SWAN interpolates. Not available
for 1D computations — use SPECOUT and BOUNDSPEC instead for that case.

## SPECOUT file format (Appendix D, p.137-142)

The SPECOUT file contains one spectrum per output time per output location, self-described by a
`SWAN` keyword and version number on its first line. A spectrum block includes:
1. A header line with the time stamp (for time-dependent files)
2. The frequency axis (`RFREQ` or `AFREQ`, with a stated count)
3. The direction axis (`CDIR` or `NDIR`, with a stated count), for 2D spectra
4. The energy/variance density matrix, one value per (frequency, direction) pair, in units of
   `m²/Hz/degr` per the manual's own worked example (p.141)

## SETUP — wave-induced water level

Syntax (manual p.79):
```
SETUP [supcor]
```
Computes wave-induced water level setup and adds it to the depth obtained from `READ BOTTOM` and
`READ WLEVEL`. `[supcor]` shifts the computed setup by a constant (default: setup is zero at the
deepest point in the grid); default `[supcor]` = 0.

**Restrictions (manual p.79):**
- Not supported in case of parallel runs using either MPI or OpenMP.
- Can only be applied to open coast (unlimited supply of water from outside the domain), in
  contrast to a closed basin (e.g. lakes, estuaries), where it should not be used.
- Set-up is not computed correctly with spherical coordinates.
- Cannot be used in case of unstructured grids.

## DIFFRACTION — wave bending around obstacles

Syntax (manual p.79-80):
```
DIFFRACTION [idiffr] [smpar] [smnum] [cgmod]
```

- `[idiffr]` — indicates the use of diffraction; if `[idiffr]=0` no diffraction is taken into
  account. Default: `[idiffr]=1`.
- `[smpar]` — smoothing parameter a for the calculation of ∇√Etot; every smoothing step, grid
  points exchange `[smpar]` times the energy with their neighbours. Default: `[smpar]=0`.
- `[smnum]` — number of smoothing steps n. Default: `[smnum]=0`.
- `[cgmod]` — adaption of propagation velocities in geographic space due to diffraction; if
  `[cgmod]=0`, no adaption. Default: `[cgmod]=1`.

The diffraction approximation in SWAN does not properly handle diffraction in harbours or in
front of reflecting obstacles; behind breakwaters with a down-wave beach, results "seem
reasonable." Spatial resolution near (the tip of) the diffraction obstacle should be 1/5 to 1/10
of the dominant wave length.

**Stabilization (manual p.79-80):** "Without extra measures, the diffraction computations with
SWAN often converge poorly or not at all." Two measures:

1. **(RECOMMENDED)** Under-relaxation via NUMERIC parameter `[alfa]`. "Very limited experience
   suggests `[alfa]` = 0.01."
2. Smoothing of the wave field for diffraction-parameter computation only (the wave field
   remains intact for all other computations and output), via repeated convolution filtering. For
   `smpar` = 0.2 (recommended), the final filter width is εx = ½√(3n)·Δx, where n is the number of
   repetitions (`[smnum]`); solving for `[smnum]` given a target εx: `smnum ≈ (2·εx/Δx)²/3`.
   This smoothing option cannot be applied to unstructured meshes.

`[idiffr]=1` with default `[smpar]=0`/`[smnum]=0` provides no smoothing — the manual's warning
above about poor convergence applies unless one of the two measures is taken.

**OBSTACLE and DIFFRACTION are independent commands.** OBSTACLE (below) defines a sub-grid
blocking/transmission/reflection line; DIFFRACTION is a separate optional command that refines
the wave field near the edges of the resulting shadow zone.

## NUMERIC — solver parameters (relevant subset)

Syntax (manual p.85-87):
```
NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01
```

- `STOPC [dabs] [drel] [curvat] [npnts]` — criterion for terminating the iterative procedure
  (stationary and nonstationary). SWAN stops when the relative change in Hs between iterations is
  less than `[drel]` and the curvature of the Hs iteration curve is less than `[curvat]`, OR the
  absolute change in Hs is less than `[dabs]` — both fulfilled in more than `[npnts]`% of wet grid
  points. Defaults: `[dabs]=0.005` m, `[drel]=0.01`, `[curvat]=0.005`, `[npnts]=99.5`.
- `STAT [mxitst] [alfa]` — parameters for a stationary computation (this is the manual's default
  branch over `NONSTAT`). `[mxitst]` — maximum stationary iterations, default 50. `[alfa]` —
  proportionality constant for frequency-dependent under-relaxation, default 0.00; suggested 0.01,
  "recommended" for diffraction computations; **not meaningful for nonstationary computations.**
- `NONSTAT [mxitns]` — maximum iterations per time step for a nonstationary computation, default 1.

## INPGRID — define input field grids (WLEVEL, WIND, CURRENT, BOTTOM)

Syntax (regular grid, manual p.36-40):
```
INPGRID WLEVEL REG [xpinp] [ypinp] [alpinp] [mxinp] [myinp] [dxinp] [dyinp] NONSTAT [tbeginp] [deltinp] HR [tendinp]
```

Stationary form (omit NONSTAT and time parameters — the NONSTAT clause is optional in the manual's
own syntax):
```
INPGRID WLEVEL REG [xpinp] [ypinp] [alpinp] [mxinp] [myinp] [dxinp] [dyinp]
```

- `WLEVEL` — the input field type. Other options: `BOTTOM`, `WIND`, `CURRENT`, `FRICTION`, etc.
- `REG` — regular (uniform rectangular) grid. Also available: `CURVILINEAR`, `UNSTRUCTURED`.
- `[xpinp] [ypinp]` — geographic origin of the input grid in problem coordinates.
- `[alpinp]` — direction of positive x-axis of the input grid (degrees, Cartesian convention). Default: 0.
- `[mxinp] [myinp]` — number of MESHES (not points) in x and y.
- `[dxinp] [dyinp]` — mesh size in x and y.
- `NONSTAT` — marks the field as time-varying.
- `[tbeginp]` — begin time of first field (ISO format: `19870530.153000` → `YYYYMMDD.HHmmss`).
- `[deltinp]` — time interval between fields, followed by unit (`SEC`, `MIN`, `HR`, `DAY`).
- `[tendinp]` — end time of last field.

**Key rules:** The INPGRID command must precede the corresponding READINP command. One
INPGRID + READINP pair per field type suffices even with multiple COMPUTE commands. The input
grid can differ from the computational grid (CGRID) — SWAN interpolates internally.

## READINP — read input field values from file

Syntax (manual p.41-45):
```
READINP WLEV [fac] 'fname' [idla] [nhedf] FREE
```

- `WLEV` — read water level values (m), positive upward relative to the same datum level as `BOTTOM`.
- `[fac]` — multiplication factor applied to all values read from file. Default 1.0; `[fac]=0` is not allowed.
- `'fname'` — filename containing the values.
- `[idla]` — layout of data in the file:
  - `1` = left-to-right, top-to-bottom (row 1 = top of grid). New map line = new file line. (Default.)
  - `2` = same as 1 but a new map line need not start on a new file line.
  - `3` = left-to-right, bottom-to-top (row 1 = bottom of grid). New map line = new file line.
  - `4` = same as 3 but a new map line need not start on a new file line.
  - `5`/`6` = top-to-bottom by column, starting lower-left, with/without forced new file lines.
  - Only meant for structured grids.
- `[nhedf]` — number of header lines at the start of the file. Default: 0.
- `FREE` — free (space-separated) format; the default reading format.

**Datum note (manual p.42):** water level is positive upward relative to the same datum as
BOTTOM. If the water level is constant in space and time, the SET command can add it to the
water depth directly instead of using READINP WLEV.

## SURFBEAT — infragravity energy module (Reniers & Zijlema 2022)

Syntax (manual p.80-83):
```
SURFBeat [df] [nmax] [emin] UNIForm|LOGarithmic
```

- `[df]` — constant size of the bound-infragravity (BIG) frequency bin (Hz). Default: 0.01.
- `[nmax]` — maximum number of short-wave pairs used to create bichromatic wave groups. Default: 50000.
- `[emin]` — energy threshold, as a fraction of the spectral peak energy, below which a short-wave
  component is excluded from bichromatic group forcing. Default: 0.05.
- `UNIFORM|LOGARITHMIC` — frequency spacing for reflected (free) IG waves. Default: UNIFORM.

**Cannot be used for curvilinear or unstructured grids, and not in 1D mode.**

**Two-COMPUTE procedure (manual p.81):**
1. First COMPUTE: sea-swell spectrum and bound infragravity waves are computed together. An
   offshore directionally spread spectrum must be imposed on the west side of the domain (assumes
   a regular grid with the positive x-axis pointing eastward).
2. Second COMPUTE: the bound IG waves are assumed to reflect at the shoreline (east side); an
   OBSTACLE line with a reflection coefficient must be specified there (the same obstacle line
   must also appear in the first COMPUTE with a transmission coefficient of 1, so the sea-swell
   field is unaffected). The reflected (free) IG waves are then predicted by the conventional
   energy balance equation, over the frequency range `[[df], fig]`.

**Physics assumption:** the biphase evolution equation for obliquely incident waves assumes
bottom slopes are mild and alongshore uniform.

**OBSTACLE FIG sub-command** (shoreline IG generation, manual p.77):
```
OBSTACLE ... FIG [alpha1] [hss] [tss] [dss] [dd] [minfr] [shape]
```

**OBSTACLE REFLEC sub-command** (sea-swell reflection):
```
OBSTACLE ... REFLec [reflc] RSPEC|RDIFF [pown]
```
- `[reflc]` — reflection coefficient (0.0-1.0)
- `RSPEC` — specular reflection (manual's default)
- `RDIFF [pown]` — diffuse reflection, with `[pown]` the power of the cosine term (default 1)

## Per-command manual page index

| Command | Manual page(s) |
|---|---|
| CURVE | 90-91 |
| TABLE | 107-108 |
| SPECOUT | 108-109 |
| POINTS | 92-93 |
| Output quantities (Appendix A) | 101-106 |
| PT* / PARTIT | 106 |
| INITIAL HOTSTART | 56-57 |
| QUANTITY | 95-97 |
| NGRID | 93-94 |
| NESTOUT | 109 |
| BOUNDNEST1 | 52 |
| SPECOUT file format (Appendix D) | 137-142 |
| SETUP | 79 |
| DIFFRACTION | 79-80 |
| NUMERIC | 85-87 |
| INPGRID | 36-40 |
| READINP | 41-45 |
| SURFBEAT | 80-83 |
| OBSTACLE FIG / REFLEC | 74-78 |
