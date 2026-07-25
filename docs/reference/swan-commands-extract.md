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

## Spectral partitioning output (PT* quantities)

SWAN partitions the 2D spectrum internally using the **watershed algorithm of Hanson and
Phillips (2001)** — every spectral bin is assigned to exactly one partition, so the result is
energy-conserving. **Partition 01 is the wind sea**; partitions 02–10 are swells ordered by
descending significant wave height. At most 10 partitions.

Valid in both `BLOCK` and `TABLE`. Source: manual p. 106 and `swanpre2.ftn:1572`.

**Each keyword expands to a fixed block of columns** — the manual says up to 10, but the
41.51AB build in use emits **6**. See the measured correction below before relying on either
number. You cannot request an individual partition — SWAN rejects e.g. `PT02HS` with
*"Invalid partitioning output specification. Use PTHSIGN instead."*

| Keyword | Column names | What it is | Exception value |
|---|---|---|---|
| `PTHSIGN` | `HsPT01` … `HsPT10` | Partition significant wave height (m) | `-9` |
| `PTRTP` | `TpPT01` … `TpPT10` | Partition relative peak period (s) | `-9` |
| `PTWLEN` | `WlPT01` … `WlPT10` | Partition average wave length (m) | `-9` |
| `PTDIR` | `DrPT01` … `DrPT10` | Partition peak wave direction (deg) | **`-999`** |
| `PTDSPR` | `DsPT01` … `DsPT10` | Partition directional spreading (deg) | `-9` |
| `PTWFRAC` | `WfPT01` … `WfPT10` | Partition wind fraction (dimensionless) | `-9` |
| `PTSTEE` | `StPT01` … `StPT10` | Partition wave steepness (dimensionless) | `-9` |

> **PARSER TRAP — `PTDIR` uses `-999`; every other PT variable uses `-9`.** Verified in
> `swanmain.ftn:2649+` (`OVEXCV` per `IVTYPE`: 100→-9, 110→-9, 120→-9, **130→-999**, 140→-9,
> 150→-9, 160→-9). A parser assuming one uniform sentinel will misread those points.
>
> *Possibly normalisable via `QUANTITY PTDIR excv=-9.` — *unverified*, do not rely on it without
> testing.*

> ### ⚠ CORRECTION 2026-07-25 — measured against real output, supersedes the two claims above
>
> Both of the following were wrong in this document and were corrected against a real
> production `TABLE_1.txt` (SWAN 41.51AB, HB Pier L3, 1273 data rows, run 10:14Z). Raw file
> preserved at `librewxr:/home/claude/p4b/TABLE_1_20260725T1014Z.txt`.
>
> **1. Each PT keyword expands to 6 columns, NOT 10.** The real header is
> `HsPT01…HsPT06`, `TpPT01…TpPT06`, `DrPT01…DrPT06`, `DsPT01…DsPT06`. A row emitted with
> `TIME XP YP HSIGN HSWELL TM01 DIR DEPTH QB DISSURF DSPR PTHSIGN PTRTP PTDIR PTDSPR` has
> **35 columns**, not the 51 that "10 columns per keyword" predicts. Any output-size or
> column-offset estimate derived from 10 is wrong.
>
> **2. Absent partitions at wet points carry `0.00000` — NOT the exception value.** Checked
> every PT column of all 1273 rows: **zero occurrences of `-9` or `-999`**, and 25,288
> exactly-zero entries. The exception value applies to points where the variable is
> *undefined* (dry/masked), not to unused partition slots at a wet point. An empty slot is
> legitimately zero energy.
>
> **Consequence — a parser that skips a slot only on the sentinel emits phantom
> partitions.** A version of `services/swan_spectral.py`'s `parse_table_pt_partitions()` did
> exactly this (`if hs is None: continue`, reached only via `_is_pt_exception`), which would
> report 6 partitions per row — 5 of them height 0, period 0, direction 0 — where SWAN
> actually found 1.
>
> **Fixed in `12f9ddc` (T4B.2, operator-approved 2026-07-25, deployed to librewxr).**
> `parse_table_pt_partitions()` now treats `HsPT0k ≈ 0` (tolerance `0.0005`, comfortably below
> SWAN's own `HSPMIN = 0.05` m partition floor) as the PRIMARY absence signal for a slot. The
> documented `-9`/`-999` exception-value check (`_is_pt_exception`) is still applied too,
> belt-and-braces, for a SWAN build/config that might emit it — but real output never has, so
> it is never the only signal relied on. This function is no longer latent: it is the live
> production source of partitions at every call site that used to call `decompose_spectrum()`
> — the L2 deep-water-reference baseline and the L3 CURVE handoff (see
> `docs/manuals/PROVIDER-MANUAL.md` §14.15 and `docs/ARCHITECTURE.md`'s SWAN nearshore model
> note). `decompose_spectrum()` itself still exists, unchanged, for
> `scripts/compare_partitioning.py`'s direct measurement of the two algorithms against each
> other — it has no production caller.
>
> **Observed partition counts** (rows with Hs > 0.05, n = 1254): 1 partition in 95.2%,
> 2 in 4.6%, 3 in 0.2%; slots 4–6 never populated. Energy closure
> `sqrt(Σ PTHs²)/Hsig` = 1.0161 mean (1.0007–1.0254).

**`PARTIT` is BLOCK-only.** The manual states it "cannot be used as an output parameter in
TABLE," and it must not be combined with other parameters in BLOCK.

**Why this matters here:** `run_1d_analytical()` takes scalars (`hs`, `tp`, `direction`), and
ADR-093 Amendment 2 states SwellTrack "marches bulk parameters per partition and reconstructs no
surface." So TABLE with PT* quantities supplies what SwellTrack consumes directly, without
writing and re-partitioning full 2D spectra. Measured 2026-07-25 at HB: `TABLE_1.txt` 204 KB vs
`SPEC_1.txt` 7.4 MB for the same 18 stations × 73 timesteps.

## INITIAL HOTSTART — warm-start from a previous run's HOTFILE

```
INITial < HOTStart < MULTiple > 'fname' < FREE        >
                    | SINGle  |          | UNFormatted
```

**`SINGLE` or `MULTIPLE` is REQUIRED.** It sits between `HOTSTART` and the quoted filename.
There is no `fname=` prefix — the filename is a bare quoted string. `FREE` is the default
format and may be omitted.

- `SINGLE` — read from one (concatenated) hotfile. This is what a serial/OpenMP run wants.
- `MULTIPLE` — read the per-process hotfiles produced by a previous **parallel MPI** run.

Source: [SWAN User Manual, Cycle III 41.51 §4.5](https://swanmodel.sourceforge.io/online_doc/swanuse/node27.html).

> **`swan_formats.py:1207` emits the keyword-less form `INIT HOTSTART 'hotstart.dat'`, and
> that is NOT the problem.** Tested directly against the 41.51AB binary on librewxr: both the
> keyword-less form and the manual's `INIT HOTSTART SINGLE 'hotstart.dat'` parse identically
> and produce the identical error. This build accepts the legacy form. Do not "fix" the
> syntax expecting it to help.
>
> ### ⚠ WHY THE HOTSTART ACTUALLY FAILS — timestamp, not syntax (measured 2026-07-25)
>
> **`HOTFILE` writes the wave field at the END of the forecast window; every cycle restarts
> that window from its BEGINNING. SWAN cannot rewind, so it aborts.**
>
> Evidence, from the L1 hotfile written by the 10:23Z cycle:
> ```
> 20260728.000000                         date and time
> ```
> The next cycle's `COMPUTE NONST 20260725.060000 10 MIN 20260728.000000` asks to start
> **66 hours before** the state in the file. SWAN's PRINT, reproduced on the real production
> window with a valid 66-hour span:
> ```
> ** Error        : start time [tbegc] before current time
> ** Severe error : start time [tbegc] greater or equal end time [tendc]
> ```
> (It reports the first, clamps the start to the hotfile's time, and the clamped start then
> equals the end — hence the second.) L1 aborted 1.4 s in, L2 0.5 s, L3 0.6 s.
>
> **Consequence: hotstart is unusable with the current run scheduling, regardless of syntax.**
> Each cycle recomputes an overlapping window from a fixed start; the hotfile is always from
> the far end of the previous window. Making it work requires an architectural decision — write
> the hotfile at the *next* cycle's start time, chain the windows forward instead of
> overlapping them, or drop hotstart entirely. **Operator decision, not a code fix.**
>
> Two separate defects had to be fixed before this was even visible: the file was never loaded
> at all (save used `level1`/`level2`/`level3_<idx>`, load used `outer`/`inner` — fixed in
> `a1fa14f`), so SWAN never got the chance to reject it. 113 MB/cycle of hotfiles have been
> written and discarded since the feature was added.
>
> **This entry did not exist before 2026-07-25.** Unlike CURVE/POINTS/TABLE/PT*, HOTSTART was
> never checked against the manual or the binary.

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

**Datum consistency requirement:** SWAN does not detect or report datum mismatches between BOTTOM and WLEVEL. A mismatch produces silently wrong depth calculations — SWAN computes total depth as BOTTOM_depth - WLEVEL, so any datum offset appears as a systematic depth bias across the entire domain. The system ensures consistency by requesting CO-OPS predictions in the DEM's native datum (ADR-098).

**Phase 7 note:** The setup estimate is added to the tide value at each grid point BEFORE writing WLEVEL.txt. SWAN sees one combined water level — it does not know or care that it contains both tide and setup components.

## SURFBEAT — infragravity energy module (Reniers & Zijlema 2022)

**Verified 2026-07-21** against installed SWAN 41.51AB binary (source at `/tmp/swan_src/src/swanpre1.ftn`) and the SWAN 41.51 user manual. The command is recognized by the parser; all restrictions below are enforced at runtime.

Syntax:
```
SURFBeat [df] [nmax] [emin] UNIForm|LOGarithmic
```

- `[df]` — IG frequency bin size (Hz). Default: 0.01.
- `[nmax]` — maximum short-wave pairs for bichromatic group forcing. Default: 50000.
- `[emin]` — energy threshold as fraction of spectral peak. Default: 0.05.
- `UNIForm|LOGarithmic` — IG frequency spacing. Default: UNIForm.

**Two-COMPUTE procedure (mandatory):**
1. First COMPUTE: sea-swell spectrum + bound infragravity waves.
2. Second COMPUTE: reflected (free) infragravity waves.
3. More than 2 COMPUTEs with SURFBEAT triggers error: "command COMPUTE must appear no more than twice."

**Grid restrictions (enforced at runtime):**
- **1D mode forbidden:** "surfbeat computation not allowed in 1D mode"
- **Non-rectilinear grids forbidden:** "surfbeat only supported for rectilinear grids" — regular (REG) grids only, not curvilinear or unstructured.

**Mode restriction:** Stationary conditions only.

**Boundary requirement:** "boundary specification is not correct in case of surfbeat -- please only west boundary should be specified." Offshore spectrum imposed on the west boundary only.

**Geometry convention:** Positive x-axis pointing eastward. Mild, alongshore-uniform bottom slopes assumed. Shoreline IG reflection configured via OBSTACLE on the east side.

**OBSTACLE IG reflection setup:**
The OBSTACLE command's `FIG` sub-command handles shoreline IG generation:
```
OBSTACLE ... FIG [alpha1] [hss] [tss] [dss] [dd] [minfr] [shape]
```
This is separate from the SURFBEAT command itself — configured on the OBSTACLE line that represents the shoreline.

**OBSTACLE sea-swell reflection:**
```
OBSTACLE ... REFLec [reflc] RSPEC|RDIFF [pown]
```
- `[reflc]` — reflection coefficient (0.0-1.0)
- `RSPEC` — specular reflection
- `RDIFF` — diffuse reflection
- `[pown]` — power of the cosine in diffuse reflection

**Output:** IG energy appears as explicit low-frequency bins in spectral output (SPECOUT). Extract Hs_ig by integrating below the split frequency (typically 0.04 Hz).

**SurfBeat strip configuration (for benchmark — see 1D-MODEL-BENCHMARK-BRIEF §7.3):**
```
PROJECT 'SBstrip' '001'
MODE STATIONARY
CGRID REG [xp] [yp] 0. [xlenc] [ylenc] [mxc] [myc] CIRCLE 36 0.004 1.0 60
$  IG range: 0.004-1.0 Hz, 60 freq bins (captures IG + sea-swell)
INPGRID BOTTOM REG [xp] [yp] 0. [mxc] [myc] [dx] [dy]
READINP BOTTOM 1. 'bottom.txt' 3 0 FREE
BOUND SIDE WEST ...  $ offshore spectrum
OBSTACLE ... FIG ...  $ shoreline east side with IG reflection
SURFBEAT
COMPUTE  $ first: sea-swell + bound IG
COMPUTE  $ second: reflected free IG
$ output spectral stations along centerline
POINTS 'SB1' [x1] [y1]
SPECOUT 'SB1' SPEC2D ABS 'SPEC_SB1.txt'
STOP
```

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
