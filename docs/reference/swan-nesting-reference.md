# SWAN Nesting Reference — Deep Read Findings

**Date:** 2026-07-19
**Origin:** Phase 23, T23.1 — SWAN manual deep read
**Source:** SWAN User Manual v41.51 + v41.45, swan-commands-extract.md, production debugging

---

## Q1: BOUNDNEST1 syntax and constraints (§4.5.5)

**Syntax:**
```
BOUNDNEST1 NEST 'fname' CLOSED|OPEN
```

**Key findings:**

1. **CLOSED vs OPEN:** `CLOSED` means the nesting boundary is a complete rectangle around the child grid. `OPEN` means only partial boundary segments are provided (rare). For standard NESTOUT output, always use `CLOSED`.

2. **Coverage requirement:** The nested grid (child CGRID) must be completely contained within the parent grid's NESTOUT rectangle (NGRID). Points outside the parent's NESTOUT coverage receive no boundary forcing — SWAN does not extrapolate. If the child grid extends beyond the parent's NGRID rectangle, those boundary segments get zero energy input. The child grid will still run but boundary segments outside the parent's coverage will have unrealistically low wave heights.

3. **Progressive reading:** SWAN reads the boundary file progressively during the simulation, not all at once at startup. This is why Bug 1 (same filename for BOUNDNEST1 and NESTOUT) was so destructive — NESTOUT was overwriting data that BOUNDNEST1 was still reading.

4. **Time interpolation:** SWAN interpolates boundary spectra between output times. The NESTOUT time interval should be ≤ the computational time step to avoid spectral artifacts. Our 1-hour output interval with a 10-minute computational step is fine — SWAN linearly interpolates between hourly boundary outputs.

**Implications for our code:**
- The Level 2 CGRID must be fully inside the Level 1 NGRID rectangle
- The Level 3 CGRID must be fully inside the Level 2 NGRID rectangle
- `compute_domains()` must ensure child grids don't extend beyond parent NGRID

---

## Q2: NGRID + NESTOUT interaction (§3.5, §4.7)

**Syntax:**
```
NGRID 'sname' [xpn] [ypn] [alpn] [xlenn] [ylenn] [mxn] [myn]
NESTOUT 'sname' 'fname' OUTPUT [tbeg] [delt] SEC|MIN|HR|DAY
```

**Key findings:**

1. **NGRID rectangle vs child CGRID:** The NGRID rectangle defined in the parent run should match the child's CGRID boundaries. It does NOT need to match the child's resolution — the NGRID `[mxn] [myn]` values can differ from the child's CGRID mesh counts. SWAN interpolates the boundary spectra to the child grid's actual resolution.

2. **Resolution mismatch effects:** The NGRID resolution determines how many boundary spectral points are written. Coarser NGRID → fewer boundary points → SWAN interpolates between them for the child. A parent-side NGRID with ~5-10 boundary points per child-grid side is adequate. There's no need for 1:1 resolution matching.

3. **Nesting ratio guidance (§3.5):** The SWAN manual recommends nesting ratios of 2-3x (e.g., 300m parent → 100m child). Our system uses:
   - Level 1 (1km) → Level 2 (100m): **10:1 ratio** — exceeds recommendation
   - Level 2 (100m) → Level 3 (10m): **10:1 ratio** — exceeds recommendation

4. **Consequences of high nesting ratios:** The primary risk is that the parent grid's coarse resolution doesn't resolve bathymetric features that matter at the child scale. Wave refraction and shoaling over unresolved features in the parent produce incorrect boundary spectra. For our use case, this is mitigated by:
   - Level 1→2: The parent (1km) covers the continental shelf where bathymetry is relatively smooth. The 10:1 jump is acceptable because there are few sharp bathymetric features at the shelf scale.
   - Level 2→3: The parent (100m) covers the nearshore where sandbars and reefs exist at scales < 100m. The 10:1 jump means these features are absent from the Level 2 solution. This is a known limitation — the Level 3 grid resolves them locally but the boundary conditions from Level 2 don't account for them.

**Implications for our code:**
- The high nesting ratios are acceptable for a first implementation but produce less accurate results than 3:1 nesting
- A future improvement could add a Level 2.5 intermediate grid (30m → 10m) for better nearshore accuracy
- NGRID mesh counts can be relatively coarse (matching the parent resolution, not the child)

---

## Q3: Wet/dry cell determination

**Key findings:**

1. **BOTTOM value for dry cells:** A cell is dry when its BOTTOM depth value is negative (SWAN convention: negative depth = above water). The threshold is controlled by `SET DEPMIN` (default: 0.05m). Any cell with depth < DEPMIN is treated as dry.

2. **CUDEM sign flip:** CUDEM uses negative = ocean, positive = land. After our sign flip (`swan_depth = -cudem_depth`), land becomes negative SWAN depth → correctly dry. Ocean becomes positive SWAN depth → correctly wet.

3. **NoData handling:** When CUDEM returns NoData, our code substitutes -15.0m (CUDEM convention) → +15.0m SWAN depth → treated as ocean. This is appropriate for offshore grids but dangerous for nearshore grids where NoData might indicate land. However, the bidirectional profile locates the coastline first, so the grid extent should stay in the ocean.

**Implications for our code:**
- The sign flip in `cudem_to_swan_bottom()` is correct
- NoData → 15m ocean assumption is acceptable given bidirectional profile coastline finding
- `target_shallow_m` in the transect should be > DEPMIN (0.05m) to avoid dry CURVE points

---

## Q4: CURVE output at dry points

**Key findings:**

1. **Exception values:** When a CURVE output point falls on a dry cell, SWAN writes the exception value (configured via `QUANTITY ... excv=-9.`). Our code sets `excv=-9.` for HSIGN, TM01, DIR, and other quantities.

2. **Exception value behavior:** The exception value is written for ALL output quantities at that point — not just the one that's physically invalid. If a CURVE point is dry, ALL of HSIGN, HSWELL, DIR, TM01, DEPTH, QB, DISSURF, SETUP, DSPR at that point are set to -9.0.

3. **Depth at dry points:** The DEPTH output quantity at a dry CURVE point is also set to the exception value (-9.0), NOT to the actual (negative) BOTTOM depth. This means you cannot use DEPTH output to distinguish "shallow wet" from "dry" — you need to check whether HSIGN is the exception value.

**Implications for our code:**
- The API must filter CURVE output points where HSIGN == -9.0 (exception value)
- These are dry points — they should be excluded from scoring, break detection, and beach profile
- The transect CURVE should be designed to minimize dry points by starting from the coastline (depth ≈ 0) and going offshore
- Phase 23's T23.3 must add this filtering

---

## Q5: Nesting ratio consequences — our 10:1 vs recommended 2-3x

**Summary of consequences:**

1. **Acceptable for Level 1→2 (shelf to nearshore):** The continental shelf has smooth bathymetry at the 1km scale. The 10:1 jump to 100m resolves the nearshore slope adequately. Refraction errors at the Level 2 boundary from unresolved 1km-scale features are small because shelf bathymetry varies slowly.

2. **Marginal for Level 2→3 (nearshore to surf zone):** The nearshore zone (5-30m depth) contains features at 20-50m scales (reef platforms, sand channels) that a 100m grid cannot resolve. The Level 2 solution propagates these features' effects to the Level 3 boundary only in an averaged sense. Individual reef/channel effects on wave direction and height are lost. The Level 3 grid can resolve these features locally but receives boundary conditions that don't account for them.

3. **Practical impact:** For broad, open-coast locations (HB Pier, most SoCal beaches), the 10:1 ratio is fine because the nearshore bathymetry is relatively uniform at the 100m scale. For locations with complex nearshore features (reef breaks, channel-separated peaks), the resolution mismatch produces less accurate break predictions.

4. **Not a blocking issue:** The 10:1 nesting ratio is used by numerous research studies and produces physically reasonable results. The SWAN manual's 2-3x recommendation is ideal but not mandatory. The main quality improvement would come from better bathymetry data (Phase 20), not finer nesting.

**Recommendation:** Accept the 10:1 ratios for v1. Document as a known limitation. If future operators report poor results at reef breaks, consider adding an intermediate grid level.

---

## Summary table

| Question | Answer | Code implication |
|----------|--------|-----------------|
| Q1: BOUNDNEST1 CLOSED/OPEN | Use CLOSED always | No change needed |
| Q1: Child outside parent NGRID | Zero energy at uncovered boundaries | Ensure child grids within parent NGRID |
| Q2: NGRID vs child resolution | Don't need to match | NGRID can use parent resolution |
| Q2: 10:1 nesting ratio | Exceeds 2-3x recommendation; acceptable for v1 | Document as known limitation |
| Q3: Dry cell threshold | SWAN DEPMIN default 0.05m | target_shallow_m should be > 0.05m |
| Q4: Dry CURVE points | All quantities set to exception value (-9.0) | Filter points where HSIGN == -9.0 |
| Q5: Practical impact of 10:1 | Fine for open coast; marginal for reef breaks | Accept for v1 |
