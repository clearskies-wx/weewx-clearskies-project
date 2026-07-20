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

## NGRID — define nested grid output boundary

Syntax:
```
NGRID 'sname' [xpn] [ypn] [alpn] [xlenn] [ylenn] [mxn] [myn]
```

- `'sname'` — name for this output grid (referenced by NESTOUT)
- `[xpn] [ypn]` — origin coordinates of the nested grid rectangle
- `[alpn]` — direction of positive x-axis (degrees, Cartesian convention; 0.0 for axis-aligned)
- `[xlenn] [ylenn]` — lengths of the rectangle in x and y (in problem coordinates)
- `[mxn] [myn]` — number of meshes in x and y

The NGRID rectangle must match the CGRID boundaries of the child nested run.

## NESTOUT — write boundary spectra for a child grid

Syntax:
```
NESTOUT 'sname' 'fname' OUTPUT [tbegnst] [deltnst] SEC|MIN|HR|DAY
```

- `'sname'` — name matching a previously defined NGRID
- `'fname'` — output file for 2D boundary spectral data
- `[tbegnst]` — begin time
- `[deltnst]` — time interval between boundary outputs

NESTOUT appears before COMPUTE. During the COMPUTE step, SWAN writes boundary
spectra at the specified interval. The child run reads this file via BOUNDNEST1.

## BOUNDNEST1 — read boundary spectra from a parent grid

Syntax:
```
BOUNDNEST1 NEST 'fname' CLOSED|OPEN
```

- `'fname'` — file created by a **previous** parent SWAN run's NESTOUT command
- `CLOSED` — the nesting boundary is a closed rectangle (standard for NESTOUT output)
- `OPEN` — boundary is not closed (rare)

BOUNDNEST1 must appear after the CGRID command. SWAN reads the boundary file
progressively throughout the simulation (not all at once at the start).

**CRITICAL:** In a run that uses BOTH BOUNDNEST1 (reads parent data) and
NESTOUT (writes child data), the two commands MUST reference DIFFERENT
filenames. If they share the same file, NESTOUT overwrites the parent boundary
data that BOUNDNEST1 is still reading, producing corrupt output and zero wave
energy in the child run. This is the root cause of the 2026-07-19 forecast
failure (SWAN-FIXES-PLAN Bug 1).

### 3-level nesting file flow

```
Level 1:  NESTOUT → writes nest_out.dat
          ↓ copy to Level 2 as nest_in.dat
Level 2:  BOUNDNEST1 reads nest_in.dat  |  NESTOUT → writes nest_out.dat
          ↓ copy to Level 3 as nest_in.dat
Level 3:  BOUNDNEST1 reads nest_in.dat
```

Each level runs sequentially. The runner copies `nest_out.dat` from the parent
directory to `nest_in.dat` in the child directory between runs. The filenames
never collide within a single working directory.

## SPECOUT file format (for parsing)

The SPECOUT file contains one spectrum per output time per output location. Each spectrum block:
1. Header line with time stamp
2. Frequency axis: `nf` frequency bins
3. Direction axis: `nd` direction bins
4. Energy density matrix: `nf` rows × `nd` columns (units: m²/Hz/deg or m²/Hz/rad)

The spectrum can be decomposed into swell systems by finding peaks in the (frequency, direction) space.

## SETUP — wave-induced water level (REMOVED from all levels)

Syntax:
```
SETUP
```

Computes wave-induced water level setup via an internal elliptic (Poisson) solve. The computed setup is added to the depth from `READ BOTTOM` and `READ WLEVEL`.

**Restrictions (SWAN User Manual v41.51, p. 79):**
- "Not supported in case of parallel runs using either MPI or OpenMP." Our runner always uses OpenMP (all available cores). This alone mandates removal.
- In a nested grid (BOUNDNEST1), the setup boundary condition is structurally wrong: BOUNDNEST1 carries only spectral energy densities, not water-level fields. The solve falls back to Neumann BC with "a constant added such that the set-up is zero in the deepest point" — false when the deepest point has nonzero true setup.
- "Can only be applied to open coast … in contrast to closed basin" (p. 79).
- "Set-up is not computed correctly with spherical coordinates" (p. 79) — requires Cartesian (UTM).

**Our status:** REMOVED from all generated INPUT files (all three levels). The physical setup effect (~10-15 cm near shore for a 3 ft breaker) is delivered instead via the WLEVEL input grid (tide + analytic setup estimate in Stage 2). The UTM Cartesian transformation is preserved (needed independently for metric grid math).

## DIFFRACTION — wave bending around obstacles

Syntax:
```
DIFFRACTION [idiffr] [smpar] [smnum] [cgmod]
```

- `[idiffr]` — 1 = activate (default when command is present)
- `[smpar]` — smoothing coefficient for the diffraction parameter (default 0, recommended 0.2)
- `[smnum]` — number of smoothing steps (default 0). Filter width: εx = ½·√(3n)·Δx
- `[cgmod]` — 1 = modify group velocity for diffraction (default 1)

**Stabilization (SWAN User Manual v41.51, pp. 79-80):**

> "Without extra measures, the diffraction computations with SWAN often converge poorly or not at all."

Two measures:
1. **(RECOMMENDED)** Under-relaxation via NUMERIC parameter `[alfa]`. "Very limited experience suggests [alfa] = 0.01." **Not meaningful for nonstationary computations** — stationary runs only.
2. Smoothing of the wave field for diffraction parameter computation. "The wave field remains intact for all other computations and output" — outputs unaffected. For `smpar = 0.2` (recommended): filter width εx = ½·√(3·smnum)·Δx. Worked example: Δx = 10m, target εx ≈ 45m → smnum = (2·εx/Δx)²/3 ≈ 27.

**Important:** A bare `DIFFRACTION` command (no arguments) uses `smpar=0, smnum=0` — zero stabilization. This WILL diverge at surf-zone resolution (10m). Never emit bare `DIFFRACTION`.

**OBSTACLE vs DIFFRACTION:** OBSTACLE is the structure itself (sub-grid blocking/attenuation line). It is fully functional WITHOUT DIFFRACTION and numerically unconditionally safe. DIFFRACTION only refines the edges of the shadow zone. Removing DIFFRACTION does not remove obstacle modeling.

**Our usage:**
- L1 (1 km) and L2 (100 m): DIFFRACTION removed — sub-grid at these resolutions, can only destabilize.
- L3 (10 m) nonstationary and stationary: `DIFFRACTION 1 0.2 27` — smoothing (filter width εx ≈ 45m ≈ half dominant wavelength).
- L3 stationary additionally: NUMERIC with `alfa=0.01` (see below).

## NUMERIC — solver parameters (relevant subset)

Syntax (stationary iterative solver control):
```
NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01
```

- `dabs`, `drel`, `curvat` — absolute, relative, and curvature convergence criteria
- `npnts` — percentage of wet grid points required to meet criteria (99.5% = stringent)
- `mxitst` — maximum iterations for stationary computation (default 50)
- `alfa` — under-relaxation factor for the iterative solver (default 0.01). Stabilizes DIFFRACTION convergence. **"Not meaningful for nonstationary computations"** — emit only in stationary (quick update) INPUT.

**Our usage:** Emitted only for L3 stationary (quick update) runs, providing both convergence criteria and the `alfa` under-relaxation that stabilizes DIFFRACTION in the iterative solver.

## INPGRID — define input field grids (WLEVEL, WIND, CURRENT, BOTTOM)

Syntax (regular grid, WLEVEL example):
```
INPGRID WLEVEL REG [xpinp] [ypinp] [alpinp] [mxinp] [myinp] [dxinp] [dyinp] NONSTAT [tbeginp] [deltinp] HR [tendinp]
```

Stationary form (omit NONSTAT and time parameters):
```
INPGRID WLEVEL REG [xpinp] [ypinp] [alpinp] [mxinp] [myinp] [dxinp] [dyinp]
```

- `WLEVEL` — the input field type. Other options: `BOTTOM`, `WIND`, `CURRENT`, `FRICTION`, etc.
- `REG` — regular (uniform rectangular) grid. Also available: `CURVILINEAR`, `UNSTRUCTURED`.
- `[xpinp] [ypinp]` — geographic origin of the input grid in problem coordinates (UTM meters for Cartesian mode).
- `[alpinp]` — direction of positive x-axis of the input grid (degrees, Cartesian convention). Default: 0.
- `[mxinp] [myinp]` — number of MESHES (not points!) in x and y. Number of grid points = meshes + 1.
- `[dxinp] [dyinp]` — mesh size in x and y (meters for Cartesian mode).
- `NONSTAT` — marks the field as time-varying. Omit for stationary (single timestep) runs.
- `[tbeginp]` — begin time of first field (ISO format: `19870530.153000` → `YYYYMMDD.HHmmss`).
- `[deltinp]` — time interval between fields, followed by unit (`SEC`, `MIN`, `HR`, `DAY`).
- `[tendinp]` — end time of last field (same format as `[tbeginp]`).

**Key rules:**
- `INPGRID BOTTOM` only allows stationary input (no NONSTAT). All other field types allow nonstationary.
- The INPGRID command must PRECEDE the corresponding READINP command.
- One INPGRID + READINP pair per field type suffices even with multiple COMPUTE commands.
- The input grid CAN differ from the computational grid (CGRID) — SWAN interpolates internally.

**Our proven WLEVEL pattern** (from `swan_formats.py` lines 812-818, verified working):
```
INPGRID WLEVEL REG {x_sw} {y_sw} 0. {mxc} {myc} {dx} {dy} NONSTAT {t_start} {dt} HR {t_end}
READINP WLEV 1. 'WLEVEL.txt' 3 0 FREE
```

Stationary (quick update, single timestep):
```
INPGRID WLEVEL REG {x_sw} {y_sw} 0. {mxc} {myc} {dx} {dy}
READINP WLEV 1. 'WLEVEL.txt' 3 0 FREE
```

## READINP — read input field values from file

Syntax:
```
READINP WLEV [fac] 'fname' [idla] [nhedf] FREE
```

- `WLEV` — read water level values (meters, positive upward, same datum as BOTTOM).
- `[fac]` — multiplication factor applied to all values. Default 1.0. Use -1 to flip sign.
- `'fname'` — filename containing the values.
- `[idla]` — layout of data in the file:
  - `1` = left-to-right, top-to-bottom (row 1 = top of grid). New map line = new file line.
  - `2` = same as 1 but new map lines can continue on same file line.
  - `3` = left-to-right, bottom-to-top (row 1 = bottom of grid). New map line = new file line. **This is what we use** — matches SWAN's south-to-north internal convention.
  - `4` = same as 3 but new map lines can continue on same file line.
- `[nhedf]` — number of header lines at the start of the file to skip. Default: 0.
- `FREE` — free format (space-separated values).

**WLEVEL.txt file layout** (for our `[idla]=3` convention):
- One value per grid point, space-separated, free format.
- Grid order: south-to-north, west-to-east (row 1 = southernmost row).
- For nonstationary: one complete grid per timestep, in chronological order (no separator between timesteps).
- Total values per timestep: `(mxinp + 1) × (myinp + 1)`.
- For stationary: exactly one grid (single timestep).

**Water level sign convention:** Positive upward relative to the same datum level as BOTTOM. When BOTTOM uses SWAN convention (positive = depth below datum), WLEVEL positive means water level ABOVE the datum. SWAN computes total depth as `BOTTOM_depth - WLEVEL` (internal sign handling).

**Phase 7 note:** The setup estimate is added to the tide value at each grid point BEFORE writing WLEVEL.txt. SWAN sees one combined water level — it does not know or care that it contains both tide and setup components.

## Per-level physics summary

| Command | L1 (1 km) | L2 (100 m) | L3 nonstationary | L3 stationary |
|---------|-----------|------------|------------------|---------------|
| GEN3 WESTHUYSEN | emit | emit | emit | emit |
| BREAKING CONSTANT 1.0 0.73 | emit | emit | emit | emit |
| FRICTION JON 0.067 | emit | emit | emit | emit |
| TRIAD | emit | emit | emit | emit |
| SETUP | **REMOVED** | **REMOVED** | **REMOVED** | **REMOVED** |
| DIFFRACTION | **REMOVED** | **REMOVED** | `DIFFRACTION 1 0.2 27` | `DIFFRACTION 1 0.2 27` |
| NUMERIC alfa | — | — | — | `NUMERIC ... alfa=0.01` |
| OBSTACLE | as configured | as configured | as configured | as configured |
