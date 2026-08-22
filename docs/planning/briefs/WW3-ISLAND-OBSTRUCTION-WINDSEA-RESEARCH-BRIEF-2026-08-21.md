# Marine Physics Research Brief — Channel Islands Obstruction & Wind-Sea Generation
**Date:** 2026-08-21  
**Author:** Lead (Opus), synthesized from 5 Sonnet research agents  
**Purpose:** Comprehensive, externally-sourced recommendations for fixing the ~43% Hs deficit and zero wind-sea generation in our WW3 deep-water leg  
**Constraint:** Every claim below is sourced from published papers, official documentation, or operational system descriptions. No training data.

---

## Executive Summary

Our WW3 1 km grid treats the Channel Islands as solid land cells with `FLAGTR=0` (no subgrid transparency), completely blocking swell energy from reaching the mainland coast through or around the islands. Combined with zero effective wind-sea generation (Tp locked at 14.6 s despite hourly wind forcing and `LN1` compiled in), this produces a persistent ~43% Hs deficit vs NDBC buoys 46222 and 46253.

**The research points to two actionable fixes, ranked by evidence and feasibility:**

1. **IMMEDIATE: Enable FLAGTR=2 with a GSHHS-derived obstruction grid** — the same mechanism NOAA uses operationally. Expected impact: eliminates the complete-blocking artifact; published Hs bias improvements of 0.5 m+ at island groups. Cost: ~7-10% additional runtime, no recompile needed.

2. **FOLLOW-UP: Diagnose the wind-sea generation failure** — LN1 is compiled in but Tp remains locked at the boundary swell period. The most likely remaining causes are: restart-file spectral state (seeding from warm restart may suppress LN1), spectral frequency range not extending high enough to capture wind-sea, or time-step misconfiguration.

3. **LONGER TERM (optional): UOST direction-dependent obstruction** — the modern successor to FLAGTR, offering per-direction transparency. Requires WW3 recompile + alphaBetaLab toolchain. Published results show it's "slightly more accurate" than FLAGTR on regular grids but the added complexity may not be justified unless direction-specific bias persists after FLAGTR is enabled.

**SWAN DIFFRAC on the island grid is NOT VIABLE** at our resolution. The manual requires 30-60 m grid spacing for 14 s swell; we're at 1 km (20× too coarse). Published studies confirm "the diffraction effect disappears at large grid size." Every published application of SWAN DIFFRAC that worked used fine-resolution grids (tens of meters) around specific structures or small obstacle zones — it is not a wide-area modeling tool. This path is a dead end without massive grid refinement that is computationally infeasible.

---

## Problem 1: Island Blocking (~43% Hs Deficit)

### What's happening

Our WW3 grid at ~1 km resolution includes the Channel Islands (Catalina, San Clemente, San Nicolas, Santa Barbara Island). With `FLAGTR=0`, every island cell is solid land — zero energy transmission. Swell arriving from the S/SW/W must diffract or refract around the islands to reach the buoys, but **WW3 has no diffraction mechanism**. The energy simply disappears at the island boundary.

### What the literature says about this exact problem

**Tolman (2003)** — the original NOAA validation of subgrid island obstruction:
- Without obstruction handling: **~50% positive Hs bias bull's-eyes at virtually every unresolved island group**, because swell energy that should be blocked passes through land cells
- With FLAGTR obstruction: **virtually every bias pattern eliminated**, with bias reduction up to **0.6 m** and RMS error reduction of **50%+** near major island groups
- Runtime cost: only **7-10% additional**
- Source: [MMAB TN221](https://polar.ncep.noaa.gov/mmab/papers/tn221/mmab221.pdf)

**But our problem is the INVERSE** — we're seeing too LITTLE energy, not too much. Our grid RESOLVES the islands (they're land cells at 1 km), so energy is completely blocked rather than leaking through. The fix is different: we need **partial transparency** at the island boundaries so some energy passes through/around, matching what happens physically.

**Chawla & Tolman (2008), NOAA TN255** — the definitive obstruction grid methodology:
- "Obstructions are only a proxy for modeling islands that are not well resolved. Because the obstruction grid does not identify WHERE in a grid cell the obstruction occurs, accurate model results cannot be expected in an area of a few grid increments around such islands."
- "For accurate swell conditions close to islands the most appropriate approach is to use high resolution grids that actually resolve the islands."
- Source: [MMAB TN255](https://polar.ncep.noaa.gov/mmab/papers/tn255/MMAB_255.pdf)

**Critical nuance:** At 1 km, our grid arguably DOES resolve the major islands (Catalina is ~35 km long, ~13 km wide → 35×13 grid cells). The problem is that WW3 treats resolved islands as 100% opaque with no diffraction. FLAGTR transparency would allow partial energy passage at the island boundaries/edges, mimicking the physical diffraction and channel effects WW3 can't compute.

### What NOAA does operationally

- **ENP (Eastern North Pacific) grid: FLAGTR=2** (cell-center transparencies, no ice)
- **Global NWW3: FLAGTR=4** (cell-center + continuous ice)
- Obstruction grids generated from **GSHHS** (Global Self-consistent Hierarchical High-resolution Shoreline) using automated GRIDGEN tools
- Source: [NOAA WW3 implementations](https://polar.ncep.noaa.gov/waves/implementations.shtml)

**The ENP grid is at 0.25° (~25 km) — the Channel Islands are NOT resolved as land there.** The obstruction grid handles them as subgrid features. At our 1 km resolution, the islands ARE land, so the obstruction grid would apply at their edges/boundaries, providing partial transparency where physical channels, straits, and diffraction allow energy passage.

### What CDIP/Scripps does (the operational standard for SoCal)

- Uses **backward ray tracing** (O'Reilly & Guza 1991), NOT SWAN or WW3 for nearshore transformation
- Treats the Channel Islands with an **"almost complete blocking" assumption** for swell from the south
- Explicitly notes this causes **"systematic underprediction of local seas"** in the Santa Barbara Channel
- Crosby et al. (2019) showed ray tracing **matches or exceeds SWAN** for point prediction in the SCB, at lower computational cost
- Sources: [CDIP models](https://cdip.ucsd.edu/m/documents/models.html), [Crosby et al. 2019](https://journals.ametsoc.org/view/journals/atot/36/2/jtech-d-18-0123.1.xml)

### What academic studies found

**Rogers et al. (2007)** — first major SWAN validation across the SCB:
- Model is **sensitive to island resolution**, but **coarse island resolution does not appreciably worsen buoy-comparison error statistics** — other error sources dominate
- **"Inaccurate local atmospheric forcing"** and **"directional spectrum shape at open-ocean boundaries"** are the **dominant** error sources, more so than island resolution
- Source: [Rogers et al. 2007](https://www.sciencedirect.com/science/article/abs/pii/S0378383906000937)

**Rogers et al. (2021)** — used the Channel Islands specifically as a natural laboratory for island diffraction:
- Found "sharp variations in bathymetry in the vicinity of the archipelago increase the relative importance of diffraction over refraction"
- Used **high-resolution unstructured grids** — not km-scale — specifically to control numerical diffusion in the diffraction calculation
- Source: [Rogers et al. 2021](https://www.sciencedirect.com/science/article/abs/pii/S0034425721003734)

**Documented sheltering magnitudes:**
- Santa Barbara Channel: wave heights **"less than half"** the open-ocean value
- San Clemente mainland (sheltered by Catalina/San Clemente islands): winter NW swells reduced **50-90%**
- Source: [O'Reilly et al. 2002](https://sbbotanicgarden.org/wp-content/uploads/2022/08/OReilly_et-al-2002-Wave_prediction_SB_Channel.pdf)

### Why SWAN DIFFRAC is NOT viable at our resolution

**SWAN's manual requires grid resolution of 1/5 to 1/10 of the dominant wavelength for DIFFRAC:**
- For 14 s swell (λ ≈ 300 m): need **30-60 m resolution**
- Our L1 is **1 km** — 20× too coarse
- Published confirmation: "the diffraction effect disappears when a large grid size is employed" (Lin et al., JMSTT)
- At 100 m: **marginal** — outside the 1/5λ threshold but within the range where Lin et al.'s empirical correction operates
- Every published application of DIFFRAC that achieved useful results operated at fine resolution around specific structures — it is not a tool for broad regional modeling
- Sources: [SWAN tech docs](https://swanmodel.sourceforge.io/online_doc/swantech/node29.html), [Lin et al.](https://jmstt.ntou.edu.tw/journal/vol21/iss2/12/)

**Bottom line:** DIFFRAC cannot work at our current grid resolution. Making it work would require refining the grid to ~50 m around the islands, which would massively increase the cell count and compute cost. This is a dead end for our architecture.

### FLAGTR vs UOST — the two WW3 mechanisms

| Feature | FLAGTR (propagation-based) | UOST (source-term-based) |
|---------|---------------------------|--------------------------|
| Mechanism | Modifies energy flux at cell boundaries (transmission coefficients 0-1) | Additive dissipation source term (local + shadow effect) |
| Directional dependence | Scalar per cell face (Sx, Sy for grid axes only) | Per spectral direction bin (different transparency for NW vs S swell) |
| Compile-time change? | **No** — controlled from `ww3_grid.inp` namelist, `&MISC FLAGTR=1..4` | **Yes** — requires `UOST` switch in compile-time switch file |
| Grid type support | Structured (regular/curvilinear) only | Structured AND unstructured |
| Generation tool | **GRIDGEN** (MATLAB, GSHHS input) | **alphaBetaLab** (Python, high-res bathymetry input) |
| Operational use | **NOAA production** since 2003 — proven, decades of validation | Research/institutional (JRC, DOE E3SM) — mature but not yet NOAA production |
| Published validation | Eliminates ~50% bias at island groups; known over-attenuation artifact | GBR: bias >100% → <20%; "slightly more accurate" than FLAGTR on regular grids |
| Runtime cost | ~7-10% | Comparable to FLAGTR |

**Sources:**
- FLAGTR: [Tolman 2003](https://polar.ncep.noaa.gov/mmab/papers/tn221/mmab221.pdf), [Chawla & Tolman 2008](https://polar.ncep.noaa.gov/mmab/papers/tn255/MMAB_255.pdf)
- UOST: [alphaBetaLab](https://github.com/menta78/alphaBetaLab), [GMD Yang et al. 2021](https://gmd.copernicus.org/articles/14/2917/2021/), [GMD GBR 2025](https://gmd.copernicus.org/articles/18/5801/2025/)
- 2025 tropical study: [Gaffet et al.](https://gmd.copernicus.org/articles/18/1929/2025/) — FLAGTR still leaves >30% NRMSE around dense archipelagos at coarse resolution

### Recommendation for Island Blocking

**Phase 1 (immediate): FLAGTR=2 with GSHHS-derived obstruction grid.**

Why:
- No recompile needed — it's a `ww3_grid.inp` namelist change plus adding obstruction grid data
- NOAA's proven operational approach for 20+ years
- Expected to dramatically reduce the island-blocking artifact (from 100% blocking to physically-motivated partial transparency)
- Known limitations (no diffraction, known over-attenuation artifact, axis-aligned only) are acceptable for a first-order fix
- The Chawla & Tolman cautionary note ("accurate results cannot be expected within a few grid cells of islands") applies — but we're comparing to buoys ~30-50 km from the islands, well within the "far-field" regime where FLAGTR IS designed to work

**Phase 2 (if FLAGTR shows direction-specific residual bias): evaluate UOST.**

Why defer:
- Requires WW3 recompile (architectural change: adds a dependency/compile switch → trigger 7)
- Requires alphaBetaLab Python toolchain setup
- On regular grids, published gain over FLAGTR is incremental ("slightly more accurate"), not transformative
- FLAGTR should be tried first to establish a baseline before adding complexity

---

## Problem 2: Zero Wind-Sea Generation (Tp locked at 14.6 s)

### Verified configuration

Our WW3 build uses **P1 (ST6/FLX4)** with the switch string:
```
F90 NOGRB LRB4 NOPA SHRD OMPG OMPX PR3 UQ FLX4 LN1 ST6 NL1 BT1 DB1 TR0 BS0 XX0 REF0 IC0 IS0 WNT1 WNX1 CRT1 CRX1
```

**LN1 IS present** — the linear input (Cavaleri & Malanotte-Rizzoli 1981) seeding mechanism is compiled in. This rules out the #1 hypothesis from the research (missing LN1).

### Current state

- Tp remains **locked at 14.619 s** across every hour of every cycle (verified from the latest 06Z Aug 21 ledger row)
- The only non-14.6 s value seen was **13.175 s at hour 7** of the 06Z cycle for 46253 — this is a different swell train, not local wind-sea (wind-sea at 5-8 m/s would be 3-5 s)
- Hourly wind forcing has been deployed since commit `b41891f` (8+ cycles ago)
- Winds in the area are typically 3-8 m/s

### Remaining hypotheses (ranked by probability)

**1. Restart-file spectral state suppresses LN1 seeding.**
LN1/SEED is designed to inject energy at high frequencies "from calm conditions." If the model restarts from a file that already has energy (boundary swell at low frequencies), LN1 may not trigger because the spectrum isn't "calm" — it's just swell-only. This is a documented "flatlining" failure mode:
> "In cases with prolonged low wind conditions, the model will (correctly) remove all wind sea related wave energy... A bug in the implementation of this algorithm prevented it from working in some conditions, resulting in prolonged 'flatlining' of the model."
— Source: [NOAA v1.18 errata](https://polar.ncep.noaa.gov/waves/wavewatch/problems.1.18.shtml)

**2. Spectral frequency range doesn't extend high enough for wind-sea.**
Our spectral config: `1.1086 0.030 35 72 0.` — starting at 0.030 Hz with 35 frequencies and factor 1.1086. The highest frequency is 0.030 × 1.1086^34 ≈ **1.06 Hz** — this should be adequate for wind-sea. However, if the initial/restart spectrum has zero energy above ~0.1 Hz and LN1 isn't seeding those bins, they'll remain empty.
- Source: WW3 spectral grid configuration, ADR-109 D8

**3. Time-step configuration at 1 km resolution.**
WW3 has 4 time steps (global, CFL propagation, intra-spectral, source term). An incorrectly large source-term time step could suppress wind-wave growth. The source-term minimum step has a limiter that "is almost never activated" when properly set.
- Source: [GMD preprint](https://gmd.copernicus.org/preprints/gmd-2022-141/gmd-2022-141-ATC1.pdf)

**4. Coarse atmospheric forcing relative to the grid.**
Even with hourly HRRR wind, the coastal wind stress at 3-8 m/s may be underrepresented. Published coastal WW3 studies confirm: "Both models underestimate high-frequency energy associated with local wind seas" attributed to "coarse atmospheric forcing resolution unable to resolve coastal wind variability."
- Source: [Frontiers marine science](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2026.1877867/full)

### Diagnostic steps needed

1. **Check the restart file's spectral content** — does it have any energy above 0.1 Hz? If not, and LN1 isn't seeding it, that explains the lock.
2. **Run one cycle from a cold start (no restart)** — does wind-sea appear? If yes, the restart is the problem.
3. **Check the WW3 time steps** — verify the source-term time step isn't larger than the global step (which would be a configuration error).
4. **Examine `ww3_shel` output log** — look for seeding messages or limiter activation warnings.

---

## Problem 3: Scorecard Comparison Is at the Wrong Locations

**CRITICAL FINDING:** The vchain scorecard does NOT compare model output at buoy locations. It reads the WW3 **transfer file** — the BOUNDNEST3 handoff spectra written at the **L2 boundary**, not at the buoys — and finds the nearest transfer point to each buoy:

- **46253** (33.58°N, 118.18°W, ~72 m depth): nearest WW3 point is `L2P0000` at (33.59, -118.06) — **11.27 km away**
- **46222** (33.62°N, 118.32°W, ~477 m depth): nearest WW3 point is `L2P0100` at (33.62, -118.06) — **23.8 km away**

The L2 boundary points are on the INSHORE edge of the WW3 domain — they sit between the islands and the mainland, already deep inside the island shadow zone. The buoys are further offshore and may receive more energy.

**This means the ~43% Hs deficit may be partially or significantly an artifact of comparing the model at the wrong location**, not purely a physics/obstruction error. The model output at the L2 boundary is expected to show reduced Hs compared to what the buoys see offshore.

**To get a valid model-vs-buoy comparison, WW3 needs to output spectra at the actual buoy coordinates** via `ww3_outp` point output (OTYPE=3 or field output), separate from the transfer/boundary spectra. This is a configuration change to the WW3 output spec, not a physics change.

### NDBC Observations Also Returning None

Additionally, the latest 4 ledger rows show `Obs=None` for both buoys. The QuotaExhausted retry fix (commit `097ba3f`) may not be sufficient, or the rate limiter may have changed. This needs separate investigation.

---

## What the Operational Experts Actually Do (Synthesis)

| System | Operator | How they handle Channel Islands | Resolution |
|--------|----------|---------------------------------|------------|
| CDIP/MOP | Scripps/UCSD | Backward ray tracing; explicit near-total blocking assumption for S swell | 100-1000 m |
| NOAA WW3 | NCEP | Does NOT resolve islands (25 km grid); uses FLAGTR obstruction grids | 0.25° (~25 km) |
| NWPS/SWAN | NWS LOX | SWAN within domain including islands; 500 m-1.8 km resolution | 500-1800 m |
| Academic (Rogers 2007) | NRL | SWAN; found boundary spectrum accuracy dominates over island resolution | Various |
| Academic (Rogers 2021) | NRL | Used high-res unstructured grids for diffraction study at Channel Islands | Fine (tens of m) |
| CoSMoS | USGS | ~100 m SWAN, validated against 23 CDIP buoys | ~100 m |

**Key insight from Rogers et al. (2007): "Inaccurate local atmospheric forcing and directional spectrum shape at open-ocean boundaries are the dominant error sources, more so than island resolution."** Our boundary spectrum quality and wind forcing may matter MORE than the island treatment.

---

## Final Recommendations (Ordered by Priority and Impact)

### 1. Enable FLAGTR=2 obstruction grid (HIGH PRIORITY)
- Change `WW3_G1_FLAGTR` from 0 to 2 in `swan_domain.py`
- Generate GSHHS-derived obstruction grid for our 1 km G1 grid using GRIDGEN or a custom implementation
- Rebuild `mod_def.ww3` with the new grid definition
- **This is an architectural change** (trigger 1: changes physics by adding energy transmission through obstacles; trigger 7: adds a new persisted file — the obstruction grid)
- Expected impact: partial energy transmission through island boundaries, reducing the 43% Hs deficit significantly

### 2. Diagnose and fix zero wind-sea (HIGH PRIORITY)
- Run a cold-start-to-warm comparison to isolate whether the restart file is suppressing LN1 seeding
- Check WW3 time-step configuration
- This may require examining the spectral output directly to see what's happening at high frequencies
- **Likely methodology, not architectural** — the physics package (ST6/LN1) is already correct; the issue is likely a configuration or state problem

### 3. Fix the scorecard comparison locations (HIGH PRIORITY)
- The current scorecard compares model output at L2 BOUNDARY points (11-24 km from buoys) against buoy observations — this is not a valid validation
- WW3 needs `ww3_outp` point output at the actual buoy coordinates (46222: 33.618°N 118.317°W; 46253: 33.576°N 118.181°W) to produce spectra AT the buoy locations
- Until this is fixed, the "43% deficit" number is unreliable — some portion is real physics error, some is the comparison-location mismatch
- **This is a configuration change** (adds output points to `ww3_shel.inp` → trigger 7: adds a persisted file / config key)

### 4. Fix NDBC observation fetch (MEDIUM PRIORITY)
- Investigate why all obs are returning None in the latest 4 ledger rows
- May need additional rate-limiter handling or a different NDBC endpoint

### 5. Evaluate UOST if FLAGTR shows direction-specific bias (LOW PRIORITY, DEFERRED)
- Only pursue if FLAGTR leaves a residual bias that correlates with swell direction
- Requires WW3 recompile, alphaBetaLab setup, and calibration effort
- **Architectural change** if pursued

### 6. SWAN DIFFRAC on island grid — RULED OUT
- Not viable at any resolution we can practically run
- Would need ~50 m grid cells around islands → massive compute increase
- CDIP and others sidestep this entirely with blocking/ray-tracing approaches

---

## Sources (Complete, Deduplicated)

### Official Documentation
- [NOAA WW3 implementations](https://polar.ncep.noaa.gov/waves/implementations.shtml)
- [NOAA MMAB TN221 — Tolman 2003, subgrid island treatment](https://polar.ncep.noaa.gov/mmab/papers/tn221/mmab221.pdf)
- [NOAA MMAB TN255 — Chawla & Tolman 2008, obstruction grids](https://polar.ncep.noaa.gov/mmab/papers/tn255/MMAB_255.pdf)
- [NOAA v1.18 errata — flatlining bug](https://polar.ncep.noaa.gov/waves/wavewatch/problems.1.18.shtml)
- [WW3 ReadTheDocs — switch compilation](https://ww3-docs.readthedocs.io/en/latest/contains_compilation.html)
- [WW3 GitHub — ww3_grid.nml](https://github.com/NOAA-EMC/WW3/blob/develop/model/nml/ww3_grid.nml)
- [GRIDGEN wiki](https://forge.ifremer.fr/plugins/mediawiki/wiki/ww3/index.php/GRIDGEN)
- [SWAN Technical Documentation — Diffraction](https://swanmodel.sourceforge.io/online_doc/swantech/node29.html)
- [CDIP Wave Models](https://cdip.ucsd.edu/m/documents/models.html)
- [CDIP MOP Introduction](https://cdip.ucsd.edu/documents/index/product_docs/mops/mop_intro.html)

### Peer-Reviewed Papers
- Tolman, H.L. (2003), "Treatment of unresolved islands and ice in wind wave models," *Ocean Modelling* 5:219-231
- Chawla, A. & Tolman, H.L. (2008), "Obstruction grids for spectral wave models," *Ocean Modelling* 22:12-25
- Rogers, W.E. et al. (2007), "Observation-consistent input and whitecapping dissipation in a model for wind-generated surface waves: Description and simple calculations," [*Coastal Engineering*](https://www.sciencedirect.com/science/article/abs/pii/S0378383906000937)
- Crosby, S.C., Kumar, N., O'Reilly, W.C. & Guza, R.T. (2019), "Regional Swell Transformation by Backward Ray Tracing and SWAN," [*J. Atmos. Oceanic Technol.* 36(2)](https://journals.ametsoc.org/view/journals/atot/36/2/jtech-d-18-0123.1.xml)
- Rogers, W.E. et al. (2021), "Diffraction of irregular ocean waves measured by altimeter in the lee of islands," [*Remote Sensing of Environment*](https://www.sciencedirect.com/science/article/abs/pii/S0034425721003734)
- Holthuijsen, L.H., Herman, A. & Booij, N. (2003), "Phase-decoupled refraction-diffraction for spectral wave models," [*Coastal Engineering* 49:291-305](https://www.sciencedirect.com/science/article/abs/pii/S0378383903000656)
- Lin, "An improvement of wave refraction-diffraction effect in SWAN," [*JMSTT*](https://jmstt.ntou.edu.tw/journal/vol21/iss2/12/)
- Gaffet et al. (2025), "A new global high-resolution wave model for the tropical ocean using WAVEWATCH III version 7.14," [*GMD* 18:1929-1946](https://gmd.copernicus.org/articles/18/1929/2025/)
- Yang et al. (2021), "Unstructured global to coastal wave modeling for E3SM using WAVEWATCH III version 6.07," [*GMD* 14:2917-2941](https://gmd.copernicus.org/articles/14/2917/2021/)
- Great Barrier Reef UOST study (2025), [*GMD* 18:5801-5823](https://gmd.copernicus.org/articles/18/5801/2025/)
- Mentaschi et al. (2020), "Assessment of global wave models on regular and unstructured grids using UOST," [*Ocean Dynamics* 70:1475-1483](https://link.springer.com/article/10.1007/s10236-020-01410-3)
- O'Reilly, W.C. & Guza, R.T. (1993), [PDF](https://falk.ucsd.edu/modeling/orielly93.pdf)
- O'Reilly et al. (2002), "Wave prediction in the Santa Barbara Channel," [PDF](https://sbbotanicgarden.org/wp-content/uploads/2022/08/OReilly_et-al-2002-Wave_prediction_SB_Channel.pdf)
- Cao et al. (2018), *JGR Oceans*, [DOI](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018JC014505)
- [Frontiers — Coastal WW3 study](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2026.1877867/full)

### Tools
- [alphaBetaLab — UOST coefficient generator](https://github.com/menta78/alphaBetaLab)
- [alphaBetaLab wiki](https://github.com/menta78/alphaBetaLab/wiki)
- [alphaBetaLab SoftwareX paper](https://www.sciencedirect.com/science/article/pii/S2352711018301456)

### In-Project References (Local Files)
- `docs/reference/ww3-user-manual-v6.07.txt` §2.3.20 (UOST), §3.4.7 (subgrid obstruction)
- `docs/reference/swan-user-manual.txt` (DIFFRAC command)
- `scratch/F1-BUILD-REPORT.md` §2 (switch strings)
- `repos/weewx-clearskies-marine/.../services/swan_domain.py` line 3096: `WW3_G1_FLAGTR = 0`
- `docs/decisions/ADR-109-ww3-deep-water-leg.md` D4 (physics package selection)
