# WW3 Command Reference Extract

> **FROZEN.** This file is a pure extract of the WaveWatch III (WW3) v6.07 User Manual
> (`docs/reference/ww3-user-manual-v6.07.txt`). It is deck-syntax lookup ONLY — no
> project-specific usage, measured corrections, or design decisions live here. Project
> WW3 usage, physics-switch choices, and grid/deck decisions live in
> `docs/decisions/ADR-109-ww3-deep-water-leg.md`, `docs/manuals/PROVIDER-MANUAL.md`, and
> `docs/ARCHITECTURE.md`. The full manual (committed above) is the authoritative source
> for anything not covered here. Cites are `6.07:NNNN` = line number in the committed
> `.txt`. Cite locations below are pulled from
> `docs/reference/SYNTAX-607-VERIFICATION.md` (the re-verified 6.07 line-cite map), not
> re-searched blind.

Covers the six programs the project uses per ADR-109's accepted set: `ww3_grid`,
`ww3_strt`, `ww3_prep`, `ww3_bound`, `ww3_shel`, `ww3_outp`.

## ww3_grid — grid definition

Spectral definition line (6.07:14548–14562):
```
[XFR] [FR1] [NK] [NTH] [THOFF]
```
Worked example: `1.1 0.04118 25 24 0.` (increment factor, first frequency Hz, freq
count, direction count, directional offset).

Model flags line (6.07:14566–14578), space-separated:
```
FLDRY FLCX FLCY FLCTH FLCK FLSOU
```
Example values: `F T T T F T` (manual's own printed `FTTTFT` at 6.07:14560 is a
page-compaction artifact — not valid space-delimited input).

Time-steps line (6.07:14608–14612), 4 values in seconds:
```
[DTMAX] [DTCFL] [DTCFLI] [DTMIN]
```
Example: `900. 950. 900. 300.`

`&MISC FLAGTR = n` subgrid-transparency codes (6.07:15349–15361):
```
0  No subgrid information.
1  Transparencies at cell boundaries between grid points.
2  Transp. at cell centers.
3  Like 1 with cont. ice.
4  Like 2 with cont. ice.
```
Example: `&MISC CICE0 = 0.25, CICEN = 0.75, FLAGTR = 4 /` (6.07:15490).

Grid-def worked example (6.07:15716–15721):
```
'RECT' T 'NONE'
12  12
1.  1.   4.
-1. -1.  4.
```

Bottom-depth read line fields (6.07:15665–15696): limiting depth, min depth, unit,
scale factor (multiplicative), IDLA, IDFM, format string, FROM, filename.

IDLA codes (6.07:15669–15675):
```
1  Read line-by-line bottom to top.
2  Like 1, single read statement.
3  Read line-by-line top to bottom.
4  Like 3, single read statement.
```

IDFM codes (6.07:15677–15681):
```
1  Free format.
2  Fixed format with above format descriptor.
3  Unformatted.
```

Unit 10 = field read inline in the deck itself, no comment lines allowed
(6.07:15665–15667).

Status-map legend (6.07:16050–16054):
```
0  Land point.
1  Regular sea point.
2  Active boundary point.
3  Point excluded from grid.
```

Output boundary points block: mandatory, terminated by a closing zero-point line even
when no output boundary points are wanted (6.07:16148–16179):
```
0. 0. 0. 0.  0
```

## ww3_strt — initial conditions

ITYPE=5, calm start, no additional data required (worked example at G.2.1,
6.07:17622–17707).

## ww3_prep — field preprocessor (non-NetCDF)

Field-type line grammar: type/format/time-flag/header-flag (6.07:17944–17960). Field
type codes: `IC1 IC5 ICE ISI LEV WND WNS CUR DAT`. Format types: `AI LL F1 F2`.

Grid-range line (6.07:17994–17999):
```
[x0] [xn] [nx] [y0] [yn] [ny]
```
Example: `-0.25 2.5 15 -0.25 2.5 4`

Data-file definition line: `FROM`/IDLA/IDFM + format, then unit + filename; unit 10 =
inline (6.07:18027–18040). `ww3_prep`'s own shipped example field-type line is
`'ICE' 'LL' F T` (6.07:17983) — `'WND' 'LL' T T` belongs to `ww3_prnc`'s example
(6.07:18178), not `ww3_prep`'s.

## ww3_bound — external boundary assembly (ASCII; `ww3_bounc` is the NetCDF form)

HARD CONSTRAINT: input spectra files must share one spectral grid (App B.2, was C.2 in
5.16; 6.07:13810–13820).

`ww3_bound.inp` mode/method line (G.3.1, 6.07:17722–17738):
```
[boundary option: READ or WRITE]
[interpolation method: 1=nearest, 2=linear]
```
Example: `WRITE` / `2`.

Input spectra file list is closed by the literal terminator:
```
'STOPSTRING'
```

## ww3_shel — main run driver

Forcing-flags block, fixed order, space-separated T/F pairs (6.07:18480–18517): water
levels, currents, winds, ice concentrations, assimilation (mean/1-D spectra/2-D
spectra).

Time frame lines, `yyyymmdd hhmmss` (6.07:18519–18527):
```
19680606 000000
19680606 060000
```

`IOSTYP = 1` generally recommended (6.07:18542–18544).

Output-type header, shared by all types: first-time, interval(s), last-time; interval 0
disables that output type (6.07:18566–18578).

Output types (6.07:19023–19178):
```
Type 2  Point output: lon lat 'NAME' (name <=10 chars, no spaces advised),
        list closed by a point named 'STOPSTRING'.
Type 4  Restart files (no additional data required).
Type 5  Boundary (nest) data (no additional data required).
Type 6  Separated wave field data (dummy for now).
Type 7  Coupling (must be fully commented unless switch COU is compiled in).
```

Homogeneous field data block is closed by the mandatory stop string:
```
'STP'
```

## ww3_outp — post-processor / transfer-file writer

ITYPE=1 (spectra), OTYPE=3 (transfer file to another model, e.g. the WW3→SWAN
boundary), plus scaling/unit/unformatted-flag inputs (6.07:21674–21690). Example line
(6.07:21688):
```
1 0. 0. 33 F
```

Transfer-file record structure (6.07:21692–21708): file ID + NFREQ/NDIR/NPOINTS +
grid name; frequency bins in Hz; direction bins in radians, oceanographic convention;
per-time-step, per-point: name (C*10), lat, lon, depth, U10 and direction, current
speed and direction, then E(f,theta). Formatted output is free-format readable
throughout (6.07:21710).
