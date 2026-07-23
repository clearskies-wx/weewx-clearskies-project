# Surf Zone 1D Model — Research Brief

**Created:** 2026-07-20
**Revised:** 2026-07-20 (merged research findings — multi-transect architecture, handoff algorithm, computational costs, Gemini fact-check, peel angle method; dropped Approach 2)
**Origin:** SURF-FIXIT-LIST investigation revealed that the SWAN CURVE transect samples at 50m spacing (5x coarser than the L3 grid), break points are undetected due to undersampling, the beach profile chart lacks meaningful wave shape information, and the breaking face height calculation uses a single-point formula approximation rather than continuous wave transformation. A 1D cross-shore wave transformation model, seeded by SWAN output at a nearshore boundary, could resolve all of these issues and enable a set of surfer-facing features that no consumer surf forecast currently provides.

---

## 1. Problem Statement

SWAN is a phase-averaged spectral model. It computes wave energy statistics (significant wave height Hs, mean period TM01, mean direction) at each grid point, but it does not:

- Model individual wave shapes (it has no concept of a wave crest or trough)
- Resolve the breaking process in detail (it parameterizes breaking dissipation via Battjes-Janssen)
- Track wave transformation at sub-grid resolution (the L3 grid is 10m; CURVE output was set to 50m)
- Classify breaker type (spilling, plunging, surging)
- Compute surf zone width, impact zone extent, or foam zone

The current pipeline applies a single-point Komar-Gaughan or Caldwell breaker formula at one depth to estimate breaking face height. This misses the continuous shoaling, jacking, breaking, and reformation that occurs across the surf zone.

## 2. Proposed Solution: SWAN -> 1D Surf Zone Enhancement

### 2.1 Core concept

SWAN runs 2D all the way to shore (preserving structure interaction and bathymetric refraction). Multiple parallel 1D cross-shore models then enhance SWAN's output by:
- Running independent transects at 10-20m spacing across each surf spot
- Interpolating between SWAN grid points at CUDEM bathymetric resolution (3-5m) along each transect
- Computing wave shapes (Stokes -> cnoidal) that phase-averaged models cannot produce
- Classifying breaker type (Iribarren number) from the local beach slope per transect
- Detecting precise break point locations within SWAN grid cells
- Producing a quasi-2D map of wave height, breaker type, and break point location across the spot

### 2.2 Multi-Transect Architecture

#### 2.2.1 Established practice

Running multiple independent parallel 1D cross-shore transects across a beach is established operational methodology in coastal engineering:

- **USGS CoSMoS** (Coastal Storm Modeling System) runs 4,802 parallel 1D XBeach transects along the Southern California coast for quasi-2D flood and wave hazard mapping. (Barnard et al., CoSMoS v3.0)
- **FEMA coastal flood hazard mapping** uses 1D transects for wave transformation, runup, and overtopping. (FEMA Coastal Floodplain Mapping Guidance, 2019)

Both operate at regional scale (100m+ spacing) for flood hazard — not surf forecasting. Our application requires much denser spacing (see below).

#### 2.2.2 Measurement zone definition (operator-configured)

The current system uses a single pin on a map. A pin defines a point, but surfing happens along a **stretch of beach**. The pin-to-transect approach produces one cross-shore line whose placement determines everything — and as demonstrated at HB Pier (SURF-21), a single transect can go through a structure and produce systematically wrong results.

**Proposed: Replace the pin with a shoreline segment.** The operator draws a line along the beach (on the map in the wizard) to define the surfable zone. The system then:

1. **Generates transects perpendicular to the segment** at 10m spacing across its length.
2. **Shows the transect array on the map** so the operator sees exactly what will be measured.
3. **Cross-checks each transect against known OBSTACLE structures** (from Overpass API discovery). Transects that intersect an OBSTACLE are flagged as "structure-affected."
4. **The operator can adjust** — shorten/extend the segment, shift it to avoid a rip zone they know about, add a second segment for a spot with two distinct peaks separated by a headland.

**Segment length drives transect count:**

| Segment length | Transects at 10m | Compute (analytical) |
|---|---|---|
| 100m (point break, tight spot) | 10 | ~10ms |
| 200m (typical beach break) | 20 | ~20ms |
| 300m (wide beach) | 30 | ~30ms |
| 500m (long beach) | 50 | ~50ms |

The pin-based configuration is replaced entirely — no backwards compatibility needed (no other operators exist yet).

#### 2.2.3 Obstacle-aware transect filtering

After generating transects, each is checked against the configured OBSTACLE structures:

1. **Intersection test:** Does this transect's cross-shore line cross any OBSTACLE line segment? Uses the same structure coordinates already computed for SWAN OBSTACLE emission.

2. **Classification:**
   - **Open transect** — does not cross any OBSTACLE. Used for all headline metrics (best peak, spot average, face height).
   - **Structure-affected transect** — crosses an OBSTACLE. Excluded from headline metrics. Still shown on the quasi-2D heat map (the shadow is real, surfers should see it — "don't paddle out here, the pier blocks the swell"). Can be reported separately: "In the pier shadow: 1-2ft."

3. **Minimum open transect count:** If more than 50% of transects are structure-affected, warn the operator that the measurement zone should be shifted. A spot where most of the beach is in a structure shadow is either configured wrong or is a genuinely sheltered spot where the shadow IS the dominant feature.

4. **Reporting:**
   - **Best peak:** Highest face height among OPEN transects only.
   - **Spot average:** Mean face height across OPEN transects only.
   - **Structure shadow:** Reported separately if present — "South of pier: 4-6ft. In pier shadow: 1-3ft."
   - **Heat map:** All transects rendered, with structure-affected transects visually distinguished.

**Connection to handoff algorithm (§2.3.4):** The geometric shadow computation used for handoff depth is the same geometry used here for obstacle intersection. One computation serves both purposes.

#### 2.2.4 Transect spacing: 10-20m for surf spot scale

A single surf spot covers 200-500m of beach. Within that stretch, features that determine wave quality vary on 10-50m scales:

| Feature | Typical width | Spacing needed to resolve |
|---|---|---|
| Sandbar peak (where waves jack up) | 20-50m | 10-25m |
| Rip channel (flat/unfavorable zone) | 10-30m | 5-15m |
| Peak-to-peak variation | 30m+ | 15m |
| Structure shadow gradient | varies | 10-20m |

**Recommendation: 10m default spacing.** This matches the L3 grid resolution (every transect aligns with a SWAN grid node, so SPECOUT extraction has no interpolation penalty). Each transect gets its own CUDEM bathymetric profile. Computational cost is negligible for the analytical model (~30ms for a full 30-transect spot). See §3 for compute details.

CoSMoS's ~100m spacing is for regional coastal hazard mapping across hundreds of km — at that spacing a 300m surf spot gets only 3 transects, which is useless for resolving sandbar variability.

| Spacing | Transects (300m spot) | What it resolves | Compute (analytical) |
|---|---|---|---|
| 10m | 30 | Individual peaks, rip channels, peel angle, full variability | ~30ms |
| 15m | 20 | Major peaks, rip channels, good peel angle | ~20ms |
| 20m | 15 | Major peaks, decent peel angle, some detail loss | ~15ms |
| 50m | 6 | Broad trends only, misses peaks | ~6ms |

#### 2.2.5 What multi-transect enables

With transects across the operator-defined segment, obstacle-filtered per §2.2.3:

- **Best peak:** Highest face height among open transects — "the bar is firing 50m south of the pier"
- **Spot average:** Mean face height across open transects — the "what you'll probably get" number
- **Worst section:** Rip channels and flat zones — useful for beach safety
- **Structure shadow:** Separately reported for structure-affected transects — "in the pier shadow: 1-3ft"
- **Peel angle:** Break line angle computed from spatial variation of break points across adjacent open transects (see §5.8)
- **Quasi-2D heat map:** All transects (open + structure-affected) rendered, showing the full spatial picture including shadow zones

#### 2.2.6 Multi-transect limitations

Multi-1D assumes zero alongshore gradients on each individual transect. It CANNOT resolve:

- **Longshore currents** — driven by oblique wave breaking; require alongshore momentum balance (Longuet-Higgins, 1970)
- **Rip currents** — require 2D circulation cells (Castelle et al. 2016)
- **Wave-current interaction** — refraction/breaking modification by currents is a 2D feedback
- **Diffraction bending** — waves wrapping around headlands, structures, reef gaps

These require full 2D modeling (XBeach-2D or FUNWAVE-TVD). True 2D is too computationally expensive for operational forecasting without LUT pre-computation. The multi-1D approach still provides more spatial detail than any consumer surf forecast, which uses single-point bulk parameter estimates.

### 2.3 Handoff Point

#### 2.3.1 Published criteria

All published criteria require wave conditions (Hs) as input:

| Source | Criterion | Typical depth |
|---|---|---|
| **XBeach manual (Deltares)** | max(10m, 2xHs) | 10-16m |
| **Deltares boundary condition guidelines (2020)** | At least 3xHs; cg/c < 0.9 | 9-15m for Hs=3-5m |
| **CoSMoS (USGS)** | Fixed at -15m isobath | 15m |
| **Fiedler et al. (2019, Coastal Engineering)** | Fixed 11m; notes 10-30m typical | 10-30m |

#### 2.3.2 Structure influence is geometric, not proportional

Between 15m and 8m depth, structure influence does NOT decay proportionally. It is binary per-structure: either the wave has physically passed the structure or it hasn't. Structures have specific depth extents — a pier's pilings reach to maybe 6-8m, a jetty to 10m, a breakwater to 15m. Once waves pass the structure tip, the shadow WIDENS as you move shoreward (diffraction fills in gradually). The transition width grows proportionally to sqrt(distance x wavelength).

```
Depth:   15m -------- 12m -------- 8m -------- 5m -------- shore

Pier     |            |            | [pilings]  |============|
(6-8m)   | no effect  | no effect  | STARTS     | FULL       |

Jetty    |            | [structure] |============|============|
(10m)    | no effect  | STARTS      | widening   | full       |

Deep     | [structure]|=============|============|============|
Bkwtr    | STARTS     | widening    | widening   | full       |
(15m)    |            |             |            |            |
```

The Deltares recommendation to hand off at 5-8m for structure-affected spots means "most structures terminate by this depth, so the spectrum has passed through all of them."

#### 2.3.3 Risks at different depths

| Handoff depth | Risk | Notes |
|---|---|---|
| Too deep (>15m) | Misses structure effects if structures are shoreward | Structure shadow not yet in the spectrum |
| 10-15m (typical) | Clean physics zone — QB almost certainly 0 | Safe default for open beaches |
| 5-8m | SWAN's Battjes-Janssen may have contaminated Hs (QB > 0) | For typical surf (Hs 1-2m), QB is still 0 at 5-8m. Verified at HB Pier: QB = 0 down to 3.7m at current conditions. Risk increases for big swells. |
| <5m | QB very likely > 0 for moderate+ waves | Not recommended as handoff depth |

#### 2.3.4 Pre-model handoff determination algorithm

The handoff depth must be determined during surf spot setup (wizard), before any SWAN run. Wave conditions (Hs, Tp, DIR), wavelength, and QB are NOT available at setup time.

**Available inputs at setup time:**
- CUDEM bathymetric profiles along each transect (3-5m resolution)
- Structure positions, orientations, and types from Overpass API discovery
- `beach_facing_degrees` (predominant wave approach direction)
- Beach slope (derivable from CUDEM gradient)

**Algorithm:**

**Step 1: Determine structure depth extents.** For each structure discovered by Overpass API, sample CUDEM depth at the structure's seaward end to get `structure_max_depth`.

**Step 2: Compute geometric shadow per transect.** For each transect, determine which structures cast a shadow on it using ray projection from structure tips in the wave approach direction. Since wave direction varies, compute shadows for three approach angles: `beach_facing_degrees` and `beach_facing +/- 30 degrees`. A transect is "shadowed" if ANY of the three angles places it in the shadow. The geometric shadow (ray optics) is a conservative approximation — narrower than the true shadow including diffraction — which is acceptable for handoff purposes.

**Step 3: Assign handoff depth per transect.**

```
For each transect:
    shadowing_structures = structures whose geometric shadow
                           intersects this transect (any of 3 angles)
    
    if no shadowing structures:
        handoff_depth = 10m
        # Safe default. Breaking (H > gamma*d) starts at d = Hs/0.73:
        #   Hs=2m -> 2.7m, Hs=3m -> 4.1m, Hs=5m -> 6.8m
        # 10m is safely above breaking for Hs up to 7.3m.
    
    else:
        # Find shallowest structure depth that shadows this transect
        shallowest = min(s.max_depth for s in shadowing_structures)
        
        # Handoff just shoreward of the structure (1.5m buffer)
        handoff_depth = shallowest - 1.5
        
        # Never shallower than 5m (breaking contamination risk)
        handoff_depth = max(handoff_depth, 5.0)
    
    # Never deeper than L3 offshore boundary
    handoff_depth = min(handoff_depth, 15.0)
```

**Step 4: Per-run dynamic refinement (optional, at model runtime).** Once SWAN runs for a specific forecast cycle, the CURVE output provides QB at every point. A runtime refinement can adjust the pre-configured handoff: scan from the configured handoff toward deep water, verify QB ~ 0. If QB > 0 at the configured depth (extreme event), move handoff deeper until QB ~ 0. Log a warning when this occurs.

**Worked example — HB Pier:**
- HB Pier extends from shore to ~7m depth. 30 transects at 10m across 300m.
- ~3-5 transects in the pier's geometric shadow: handoff at 7 - 1.5 = 5.5m
- ~25-27 transects outside shadow: handoff at 10m (default)
- Verified: QB = 0 from 15m to 3.7m depth on 2026-07-20. The 5.5m handoff is in the clean zone.

#### 2.3.5 SWAN grid scale at the handoff

At 15m depth (open beaches), the handoff sits at L3's offshore boundary — the same spectrum L2 provides via nesting. L3 has not added independent computation at its own edge. This is acceptable because:

- At 15m depth, 100m resolution (L2) is adequate — waves haven't entered the surf zone, bathymetry is smooth
- The 1D model provides all fine-scale enhancement from the handoff to shore
- For structure-affected spots, the handoff moves shallower where L3 HAS done work (OBSTACLE blocking, fine-scale refraction)

Always extract SPECOUT from L3 regardless. L3 is already running, and extraction from a 10m grid gives cleaner spatial sampling for the multi-transect array (30 points at 10m spacing) than interpolation from L2's 100m grid.

### 2.4 Coupling approach: Standard one-way (Approach 1 only)

The established methodology (SWANSURF, SWAN->SWASH, SWAN->XBeach):

1. SWAN runs the full 2D domain to shore.
2. Extract SPECOUT (full 2D spectrum) or bulk parameters (Hs, Tp, DIR) at the handoff point per transect.
3. Each 1D transect runs **independently** from its handoff point to shore.
4. Structure effects captured by SWAN upstream of the handoff are inherited via the spectrum.

**Scientific basis:** USACE SWANSURF model, SWAN-SWASH coupling (Rijnsdorp et al.), hybrid phase-averaged/phase-resolving methods (ASCE 2010, Malej et al. 2025).

**Limitation:** Structure effects shoreward of the handoff are missed. The handoff must be placed shoreward of all relevant structures — resolved by the per-transect algorithm in §2.3.4.

**Approach 2 (constraint-based sub-grid enhancement) was evaluated and dropped.** No published precedent exists for using SWAN grid-node values as mid-domain constraints for a 1D model. The research investment to validate a novel coupling approach is not justified when standard one-way coupling is established and sufficient.

### 2.5 Established coupling pattern: SWAN 2D -> XBeach-1D surfbeat

Documented by Deltares (creators of both SWAN and XBeach):

1. SWAN runs 2D all the way past structures, down to 5-8m depth.
2. Extract SPECOUT at 5-8m depth at strategic locations inside/outside structure shadows.
3. XBeach-1D surfbeat runs from 5-8m to shore per transect.
4. Multiple dense transects near structures (10-50m spacing) capture spatial variation.

### 2.6 Practical constraints

- **Transects must be perpendicular to local depth contours** (isobaths), not just drawn from `beach_facing_degrees`. Computing isobath orientation from smoothed CUDEM gradients is a code change from the current `compute_spot_transect()` implementation.
- **Multiple transects per spot** at 10-20m spacing (see §2.2.2).
- **New SWAN INPUT commands (POINTS/SPECOUT) must go through the T7.GATE syntax verification process** (RULE 5, SWAN-L3-STABILITY-PLAN). Coordinator extracts syntax into `swan-commands-extract.md` before any agent writes INPUT-generation code.

---

## 3. Model Options Evaluated

### Option A: Analytical 1D (Linear Wave Theory + Battjes-Janssen Breaking)

**What it is:** Pure-math wave transformation using textbook coastal engineering equations. No external software. Implemented as a Python module.

**Wave height statistic:** The model transforms **Hs** (significant wave height = 4 sqrt(m0)), consistent with SWAN's output. Battjes-Janssen operates on Hrms internally (Hrms = Hs/sqrt(2) for Rayleigh-distributed waves) with Hmax = gamma*d as the depth-limited maximum. The breaking criterion H > gamma*d uses SWAN's gamma = 0.73, applied to Hs (not Hrms). All equations in this section use Hs unless explicitly stated otherwise.

**Equations:**
1. **Dispersion relation** -> local wavelength L at each depth: `L = gT^2/(2pi) x tanh(2pi*d/L)` (iterative, converges in ~5 iterations)
2. **Group velocity** Cg from L and depth -> energy propagation speed
3. **Shoaling coefficient** Ks = sqrt(Cg0/Cg) -> Hs transformation
4. **Refraction** from Snell's law if wave angle changes relative to bathymetric contours
5. **Breaking criterion** Hs > gamma*d (gamma = 0.73) -> initiate dissipation
6. **Battjes-Janssen dissipation** -> energy decay in the surf zone, Hs reduction
7. **Roller model (Svendsen, 1984)** — likely required for realistic post-breaking behavior (see Limitations)
8. **Wave shape** via theory selection by depth regime:
   - Deep/intermediate (d/L > 0.05): Stokes 2nd order
   - Shallow (d/L < 0.05): Cnoidal theory -> sharp crests, flat troughs via Jacobi elliptic cn function

**Dependencies:** `math` for core equations. Cnoidal wave shapes require Jacobi elliptic functions — either `scipy.special.ellipj`/`ellipk` (scipy is already an API dependency via eccodes/xarray) or a hand-rolled arithmetic-geometric mean (AGM) implementation (~50 lines). The "zero dependencies" claim in earlier drafts was incorrect.

**Estimated size:** 200-350 lines including the roller model and elliptic function handling.

**Computational cost:**

| Transect length | Grid spacing | Points | numpy vectorized | Pure Python |
|---|---|---|---|---|
| 300m (shallow spot) | 3m | 100 | ~0.1ms | ~1ms |
| 1000m (moderate) | 5m | 200 | ~0.3ms | ~2ms |
| 2500m (HB Pier, 15m to shore) | 5m | 500 | ~0.5ms | ~5ms |

**Full spot (30 transects at 10m spacing): ~10-60ms.** Computational cost is irrelevant to the transect spacing decision.

**Limitations:**
- Phase-averaged breaking (Battjes-Janssen) — doesn't resolve individual breaking events
- **Reformation requires a roller model.** Plain Battjes-Janssen energy-balance models bias break points seaward and underpredict inner-surf-zone wave heights. The wave roller (Svendsen 1984) delays energy transfer from the organized wave to turbulence, producing more realistic post-breaking decay and reformation in bar/trough systems. SimpleWaves1D (Stresser) includes roller effects for this reason. The roller model adds ~30-50 lines but is likely necessary for multi-bar beaches.
- No infragravity wave generation (long-period surf beat)
- No wave-current interaction
- Wave shapes are steady-state theoretical solutions (Stokes/cnoidal); real waves are irregular
- No runup or swash zone modeling
- **Wind effects on breaking are not modeled.** Offshore wind holds wave faces up and delays breaking; onshore wind degrades face quality and triggers earlier breaking. The surf scorer already has wind quality scoring, but the 1D model's breaking criterion ignores wind entirely. At minimum this is a documented limitation; ideally a wind modifier on gamma (e.g., gamma_effective = gamma x wind_factor) could be investigated.

### Option B: XBeach in Surfbeat Mode (1D)

**What it is:** Deltares' open-source storm impact model. Surfbeat mode resolves short-wave groups and infragravity waves. Fortran binary, runs as a subprocess (same pattern as SWAN).

**How it works:** Solves the short-wave energy balance on the wave-group timescale, coupled with the nonlinear shallow water equations for infragravity waves and mean flow. Short-wave phase is not resolved (saves compute), but wave groups and their forcing of long waves are captured.

**1D setup:** `ny = 0`, `morfac = 0` (disable sediment transport). Takes a 1D bathymetric profile and offshore wave spectrum (from SWAN SPECOUT). Outputs wave height, setup, runup, infragravity wave height along the transect.

**Computational cost:** No published benchmark for 1D surfbeat with `morfac=0`. XBeach profile mode is ~100x faster than XBeach 2D (CoSMoS documentation). Meta-model literature (NHESS 2022) reports XBeach morphodynamic simulations take "several hours" across transect sets, with emulators achieving "10^3-10^4x faster" computation — but those are full storm simulations with sediment transport.

**Estimated runtime per transect (morfac=0, surfbeat, 1D — UNVERIFIED):**

| Domain length | Grid spacing | Points | Sim time | Estimated wall clock |
|---|---|---|---|---|
| 300m | 5m | 60 | 30 min | 10-30s |
| 1000m | 5m | 200 | 30 min | 30-90s |
| 2500m | 5m | 500 | 30 min | 60-180s |

**For a full spot (30 transects):**

| Domain | Per transect | 30 serial | 30 on 8 cores |
|---|---|---|---|
| 300m | ~20s | ~10 min | ~1.5 min |
| 1000m | ~60s | ~30 min | ~4 min |
| 2500m | ~120s | ~60 min | ~8 min |

**R6 benchmark is still required before committing to v2 architecture.** If per-transect runtime exceeds ~30s, the LUT approach is needed.

**Accuracy:** Better than Option A for infragravity waves, wave setup, runup, wave group statistics. Roughly equivalent for Hs transformation and breaking location.

**Key advantage:** Infragravity waves — set timing, lull patterns. No other lightweight option captures these.

### Option C: SWASH (1D Non-Hydrostatic)

**What it is:** TU Delft's phase-resolving non-hydrostatic wave model. Resolves individual waves. Fortran binary.

**Computational cost:** High. dx ~ 1-3m, dt ~ 0.1-0.5s. For a 300m 1D transect, 30-minute simulation: estimated 30-120 seconds. Too expensive for routine forecasting. **Useful as a validation ground-truth** (see §10).

### Option D: SWAN SurfBeat-1D (Rijnsdorp et al. 2022)

**What it is:** An extension to SWAN adding an infragravity energy source term. Published in Coastal Engineering, 172, 104068.

**Availability:** The brief initially assumed a custom SWAN build is required. **Research needed:** check whether the SurfBeat extension has been mainlined in SWAN 41.5x releases. If it's a configuration flag, Option D's cost drops dramatically.

**Complements, does not replace** Option A — adds infragravity prediction but does not improve wave shapes, breaking classification, or sub-grid resolution.

### Option E: FUNWAVE-TVD (2D Boussinesq)

**What it is:** USACE ERDC fully nonlinear Boussinesq wave model. Phase-resolving, 2D. Fortran binary, open source. GPU-accelerated version available (FUNWAVE-GPU, Yuan et al. 2020).

**Key advantage:** Handles 2D phase-coherent effects that neither SWAN nor any 1D model can: reflection (The Wedge), diffraction around structure tips, wave focusing patterns, longshore current generation.

**Computational cost:** 1-5 minutes on CPU for a 500m x 300m domain at 3m resolution. Manageable via the LUT approach (see §9).

**When needed:** Spots where reflection, diffraction, or wave channeling are the dominant processes (The Wedge, inlet breaks, harbor mouths). Not needed for open beach breaks.

---

## 4. Recommendation

### Single authoritative recommendation

**v1: Option A (Analytical 1D) with standard one-way coupling, multi-transect architecture.**
- SWAN L3 runs to shore (current architecture, no changes).
- CURVE output at 10m spacing (SURF-19 fix).
- 30 SPECOUT extraction points per spot at the handoff depth (10m spacing across 300m).
- Handoff depth per transect determined by the pre-model algorithm (§2.3.4): 10m default, shallower for structure-shadowed transects.
- Analytical 1D model runs from each handoff to shore independently per transect.
- Provides: wave height envelope, sub-grid break points, breaker classification, surf zone widths, wave shapes, jacking factor, peel angle, quasi-2D heat map, best-peak/average/worst reporting.
- Accept that diffraction/reflection accuracy in structure shadow zones is limited by SWAN's phase-averaged approach.

**v2: Add XBeach-1D surfbeat** for infragravity wave prediction (set timing, lull patterns).
- Same SWAN->1D coupling pattern — SWAN provides the pre-warped spectrum, XBeach-1D surfbeat runs from the handoff to shore.
- Option A's analytical outputs (wave shapes, Iribarren, jacking) are retained as post-processing on top of XBeach-1D's Hs output, or computed from XBeach's output directly.
- LUT approach if XBeach-1D runtime exceeds ~30 seconds per transect (benchmark first — R6).
- At 30 transects per spot, XBeach-1D may require 20m spacing (15 transects) to stay within compute budget.

**Future: FUNWAVE-TVD for structure-dominated spots** (The Wedge, inlet breaks, harbor mouths).
- Phase-resolving 2D for reflection, diffraction, and wave channeling.
- LUT approach to manage compute cost (~14,000 pre-computed combinations per spot).
- Significant engineering effort. Not needed for the majority of surf spots.

**XBeach surfbeat has the same diffraction limitation as SWAN** (short-wave diffraction neglected in surfbeat mode). It does NOT replace FUNWAVE for diffraction-dominated spots. Its value is infragravity waves, not structure interaction.

**SWASH is not recommended for production** — its value is as a validation ground-truth tool for the 1D model (see §10).

---

## 5. Outputs from the 1D Model

### 5.1 Wave Height Envelope (Hs, continuous)

Hs at every 3-5m along each transect from the handoff to shore. Shows shoaling buildup over sandbars, height reduction in troughs, jacking, breaking decay, and (with the roller model) reformation in deeper troughs and secondary breaking over inner bars.

With multi-transect architecture: 30 parallel Hs envelopes, stitchable into a quasi-2D heat map.

**Note on reformation:** Plain Battjes-Janssen without a roller model biases break points seaward and underpredicts inner-surf-zone heights. The roller model (Svendsen 1984) is likely required for realistic multi-bar beach profiles. This is a known limitation of SimpleWaves1D-class models without roller effects.

### 5.2 Breaking Face Height (improved Hs input, K-G/Caldwell still required)

The 1D model improves the **location** and **Hs input** to the K-G/Caldwell face-height conversion. Instead of applying the breaker formula at a single SWAN grid point, the 1D model provides Hs at the precise break location (sub-grid resolution via CUDEM bathymetry).

With multi-transect architecture: face height per transect enables best-peak, average, and worst-section reporting.

**K-G/Caldwell is NOT eliminated.** Hs is a statistical wave height (4 sqrt(m0)). Breaking face height (trough-to-crest of the actual wave) requires a conversion from Hs — that's exactly what K-G/Caldwell provides. The 1D model gives better inputs to that conversion, not a replacement for it. Alternatively, cnoidal wave theory at the break point can estimate crest/trough asymmetry directly, but this would need validation against the existing K-G/Caldwell calibration.

**Scoring recalibration check:** The surf scorer's `_WAVE_HEIGHT_RANGES_FT` thresholds are calibrated in face-height feet against the current single-point K-G/Caldwell output. If the 1D model changes the Hs input to K-G/Caldwell (different break location, different Hs), the resulting face heights will differ. The scoring thresholds must be validated against the new face heights to ensure score continuity. This is not a blocker but must be checked before deployment.

### 5.3 Wave Shape Profiles

At each point along each transect, the local wave shape computed from the appropriate theory:

| Depth regime | d/L | Theory | Shape |
|---|---|---|---|
| Intermediate | 0.05 - 0.5 | Stokes 2nd/3rd order | Slightly steepened crests, flattened troughs |
| Shallow | < 0.05 | Cnoidal | Sharp peaked crests, wide flat troughs |
| Near-breaking | Hs/d -> gamma | Steepened cnoidal | Pitched forward, steep front face |
| Post-breaking | -- | Bore/turbulent | Foam front propagation |

Rendered on the beach profile chart as actual wave surface shapes instead of a flat blue envelope.

### 5.4 Breaker Classification (Iribarren Number)

**Two formulations exist — must use matched form + thresholds.**

The Iribarren number has a deep-water form (xi_0) and a breaker form (xi_b). Their classification thresholds differ (Battjes 1974). Using mismatched form + thresholds systematically misclassifies breakers.

**Using the deep-water form (xi_0) — recommended** (inputs directly available from SWAN):

**xi_0 = tan(beta) / sqrt(H_0/L_0)** where:
- `tan(beta)` = local beach slope from CUDEM bathymetry at the break location
- `H_0` = deep-water equivalent Hs (from SWAN at the handoff)
- `L_0` = deep-water wavelength = `gT^2/(2pi)` (from SWAN period)

| xi_0 range | Classification | Description |
|---|---|---|
| < 0.5 | Spilling | Gradual breaking, crumbly whitewater — beginner-friendly |
| 0.5 - 3.3 | Plunging | Pitching lip, hollow — performance surfing (barrel potential at xi_0 > 1.5) |
| > 3.3 | Surging/Collapsing | Wave runs up slope without clean breaking — not surfable |

*Source: Battjes (1974). The xi_b form uses thresholds 0.4/2.0 with breaker-point Hb/Lb — do not mix.*

Computed at each break point along each transect. Different bars AND different transects can produce different classifications — the multi-transect architecture captures spatial variation in breaker type across the spot.

### 5.5 Surf Zone Widths

Derived from the Hs and QB profile per transect:

| Zone | Definition | Computation |
|---|---|---|
| **Impact zone** | Outermost break to ~50% energy loss | From first Hs/d > gamma to where Hs has decayed to ~71% of breaking Hs (energy proportional to Hs^2, 50% energy = 71% height) |
| **Foam zone** | End of impact zone to swash | From 50% energy loss to bore-propagation minimum (~0.3m) |
| **Total surf zone** | Outer break to swash line | Impact + foam zone width |

### 5.6 Wave Jacking Factor

`jacking_factor = Hs_bar_crest / Hs_approach`

A jacking factor of 1.5 means waves increase 50% in height over the bar — the sudden "stand up" surfers see on steep sandbars. With multi-transect architecture, jacking varies per transect based on local bar shape.

### 5.7 Hold-Down Time Estimate

**The formula below is an unvalidated heuristic** — it was composed during discussion, not sourced from literature. It needs calibration against empirical data before it ships.

`hold_down_seconds ~ (T / 2) x (H_break / H_ref)^0.5`

Sanity check failure: T=10s, H=2m, H_ref=2m gives 5s — but empirical ranges for head-high surf are 12-15s. The formula undershoots by ~2x. **This needs either a literature-sourced model or calibration against empirical ranges (5-8s small waves, 12-15s head-high, 20-30s big waves) before implementation.**

Breaker-type adjustments (conceptually sound, coefficients unvalidated):
- Plunging: longer hold (more violent turbulence)
- Spilling: shorter hold (gentler breaking)

### 5.8 Peel Angle (from multi-transect break point comparison)

Peel angle (Walker 1974, Scarfe et al. 2003) — how fast the breaking point translates along the wave crest. Determines whether a wave is surfable (peeling) or a closeout (breaks all at once).

| Peel angle | Classification | Surfing implication |
|---|---|---|
| < 30 deg | Closeout | Breaks all at once — not surfable |
| 30-45 deg | Fast | Expert-only, barrel potential |
| 45-66 deg | Optimal | Performance surfing, most skill levels |
| > 66 deg | Slow/mushy | Beginner-friendly, longboard waves |

**Multi-transect computation method (geometrically sound, no direct published precedent):**

1. Each transect identifies its primary break point (cross-shore position where H first exceeds gamma*d).
2. Adjacent transects (delta_y apart alongshore) have break points at cross-shore positions x_1 and x_2.
3. Break line angle relative to shore = arctan((x_2 - x_1) / delta_y).
4. Peel angle = |wave_crest_angle - break_line_angle|, where wave_crest_angle is perpendicular to SWAN's wave direction at the handoff.

All parallel transects use the same time reference (same forecast hour, same SWAN output). Since the analytical 1D model is steady-state and all transects are seeded from the same SWAN cycle, the break points are simultaneous — peel angle comes from the spatial geometry of where they break, not temporal sequencing.

At 10m transect spacing, even 3-5m differences in break point location across adjacent transects produce resolvable peel angles. At 100m spacing, arctan(delta_x/100) barely resolves anything — another reason 10m spacing is correct for surf forecasting.

---

## 6. Required Inputs (datum consistency)

The 1D model computes Hs/d at every point — d must be **tide-adjusted, datum-consistent depth**. This connects directly to the SWAN-DATUM-PLAN work.

| Input | Source | Datum requirement |
|---|---|---|
| **Bathymetric depth** | CUDEM profile at 3-5m resolution | DEM's native vertical datum (from `ncei_regional_dem_index.json` — NAVD88, MHW, etc.) |
| **Tide level** | CO-OPS predictions | Must be in the **same datum as the bathymetry** (match-at-source per SWAN-DATUM-PLAN) |
| **Hs, Tp, DIR** | SWAN CURVE/SPECOUT at the handoff point | Already unit-converted by the surf endpoint |
| **Effective depth** | d_effective = bathymetric_depth + tide_level | Only valid when both are in the same datum. The 1D model must verify datum consistency before computing. |

**If the DEM datum is UNKNOWN or doesn't match the tide prediction datum, the 1D model must fail explicitly** — same "no silent fallbacks" rule as the SWAN pipeline (SWAN-DATUM-PLAN §T3.2).

### 6.1 Variable-resolution 1D grid (added 2026-07-23)

The 1D cross-shore grid must be fine enough to resolve wave breaking, shoaling over sandbars, and reformation in troughs. A uniform coarse grid (e.g. 50m or even 10m) causes the Battjes-Janssen dissipation to over-attenuate wave energy and miss break points entirely (confirmed: 50m grid at HB produced zero face height; 5m grid found 3 break points with correct physics).

**Grid resolution zones (depth-based, not distance-based):** Distance from shore varies wildly between locations — a steep reef break hits 2m depth at 20m from shore; a gentle shelf like HB hits it at 100m. Resolution zones are defined by depth because the physics depends on depth.

| Zone | Depth range | Grid dx | Rationale |
|---|---|---|---|
| **Surf zone** | Shore to max breaking depth | 1–2 m | Breaking, dissipation, wave shape transitions, break point detection. XBeach documentation: grid influence "almost eliminated for dx ≤ 2m." |
| **Shoaling zone** | Max breaking depth to ~15m | 3–5 m | Shoaling, refraction, bar/trough structure. Moderate resolution captures sandbar crests without excessive points. |
| **Approach zone** | > ~15m | CUDEM native (3–10 m) | Waves propagating with minimal transformation. No benefit from finer grid. |

**Max breaking depth computation:** `d_break_max = Hs_max / gamma`, where `Hs_max` is the maximum expected significant wave height for the spot (from operator wave climate config or SWAN boundary conditions) and `gamma` is the breaking parameter (default 0.73). For a spot that sees 4m winter swells: `d_break_max = 4.0 / 0.73 ≈ 5.5m`. The surf zone extends from shore to 5.5m depth — covering outer bars, inner bars, and reform troughs between them. This is critical for multi-bar beaches (e.g. Huntington Beach) where waves break, reform, and break again.

**Computed at wizard setup time:** The depth zone thresholds are derived from the CUDEM bathymetric profile and the spot's wave climate when the spot is configured. Stored in the per-spot config (`SurfSpotConfig`). The 1D model reads them at runtime — no recomputation per call.

**Interpolation method: PCHIP (Piecewise Cubic Hermite Interpolating Polynomial).** NCEI's own CUDEM program uses spline interpolation internally ("waffles" tool). Cubic splines preserve sandbar curvature that linear interpolation destroys (slope discontinuities at every sample point affect Iribarren number and breaker type). PCHIP avoids the overshoot artifacts of natural cubic splines in sparse regions — it is monotonicity-preserving, so interpolated depths never create phantom bars or troughs between CUDEM samples.

**The interpolated profile is generated once** (at spot setup or when CUDEM bathymetry is first downloaded for the spot) and cached as the spot's `bathymetric_profile`. Every SwellTrack call reads the pre-interpolated variable-resolution profile from the cache.

**Research basis:**
- XBeach documentation: dx ≤ 2m eliminates grid influence on breaking ([XBeach Manual](https://xbeach.readthedocs.io/en/latest/xbeach_manual.html))
- ERDC/CHL CHETN-I-64: nearshore model sensitivity to bathymetric resolution ([ERDC](https://apps.dtic.mil/sti/tr/pdf/ADA588527.pdf))
- NCEI: spline interpolation most accurate for bathymetric gridding ([CUDEM paper](https://www.researchgate.net/publication/369471727))
- Battjes-Janssen dissipation: coarse grids over-dissipate energy ([SWAN tech docs](https://swanmodel.sourceforge.io/online_doc/swantech/node16.html))

---

## 7. Integration with Existing Modules

Three existing components overlap with the 1D model's scope. The integration must be explicit to avoid duplicate/conflicting computations.

| Existing module | What it does | Relationship to 1D model |
|---|---|---|
| `enrichment/wave_transform.py` | Applies bathymetric/structure supplements to SWAN Hs | **Feeds the 1D model.** The 1D model receives the post-supplement Hs from SWAN. wave_transform.py continues to operate on SWAN's raw output before the handoff. No overlap. |
| `enrichment/breaker_height.py` | K-G/Caldwell: converts Hs -> face height | **Still required.** The 1D model provides better Hs and break location as inputs to K-G/Caldwell, but does NOT replace the Hs-to-face-height conversion itself (see §5.2). The existing module stays; its inputs improve. |
| `services/wave_setup.py` | Stage 2 analytic setup (SWAN-L3-STABILITY-PLAN Phase 7) — radiation-stress setup profile injected into SWAN WLEVEL | **Potential overlap.** The 1D model's shoaling computation implicitly produces radiation stress gradients that could yield setup. However, wave_setup.py feeds SWAN's WLEVEL input *before* SWAN runs, while the 1D model runs *after* SWAN. They operate at different points in the pipeline. No conflict in v1, but if the 1D model ever computes setup independently, it must be reconciled with the WLEVEL injection. |

### Per-partition swell transformation (critical — replaces L3 spectral decomposition)

The 1D model replaces SWAN L3 for the final leg of wave transformation. The SPECOUT at the handoff point (from L2 at ~15m or L3 where available) is the last point where the full 2D spectrum exists. From there, the 1D model takes over — and the 1D model has no spectrum, only bulk parameters (Hs, Tp, DIR).

**This means spectral decomposition MUST happen at the handoff point, BEFORE the 1D model runs.** Each partition is then transformed independently through the 1D model, preserving the per-component information all the way to the break point.

**Full data pipeline:**

```
SWAN (L1 → L2) runs to ~15m depth
        │
        ▼
SPECOUT at handoff point (one per unique grid cell across the segment)
        │
        ▼
Spectral decomposition at handoff (SURF-11 fix — must find all components)
        │
        ├── Partition 1: 2.6ft, 12s, S 184°  (swell)
        ├── Partition 2: 2.3ft, 9s, S 180°   (wind swell)
        └── Partition 3: 1.2ft, 16s, SSW 194° (groundswell)
        │
        ▼
SWELL CARD: Display these as deep-water swell components
(what's arriving — comparable to buoy reports and Surfline's swell card)
        │
        ▼
Each partition × each transect → independent 1D run
(3 partitions × 30 transects = 90 runs × ~1ms = ~90ms)
        │
        ├── Partition 3 (16s) breaks at outer bar → face height per transect
        ├── Partition 1 (12s) breaks at middle bar → face height per transect
        └── Partition 2 (9s) breaks at inner bar → face height per transect
        │
        ▼
At each transect point: Hs_total = sqrt(P1² + P2² + P3²)
K-G/Caldwell at each partition's break point → per-partition face height
        │
        ▼
SURF HEIGHT CARD: Best peak / spot average face height from open transects
PER-PARTITION DISPLAY: "16s SSW groundswell breaking at outer bar, 5ft faces"
HEAT MAP: All transects, all partitions, structure-affected flagged
```

**What each display element shows:**

| Display element | Data source | What it represents |
|---|---|---|
| **Swell card** (incoming swells) | SPECOUT decomposition at handoff | Deep water swell components — what's arriving. Heights are pre-transformation. Comparable to NDBC buoy partitions and Surfline's swell card. |
| **Surf height** (headline number) | 1D model output at break point, K-G/Caldwell applied | Face height at the break — what surfers see. Best peak and spot average from open transects. |
| **Per-partition break info** | 1D model output per partition per transect | Where each swell component breaks, how high, what breaker type. "The 16s groundswell breaks at the outer bar with 5ft plunging faces; the 9s windswell breaks at the inner bar with 3ft spilling faces." |
| **Heat map** | 1D model output across all transects | Spatial view of Hs, breaker type, and break points across the spot. Structure-affected transects shown but visually distinguished. |

**Why per-partition transformation matters physically:** A 16s groundswell has a wavelength of ~400m and feels the bottom at ~200m depth — it shoals over a long distance and breaks far offshore on the outer bar. A 9s windswell has a wavelength of ~125m and doesn't shoal significantly until much closer to shore. Transforming them as one averaged wave (the current single-component approach) produces a break point and face height that is wrong for both components. Per-partition runs capture the distinct behavior of each swell system.

**Computational cost with per-partition transformation:** 3 partitions × 30 transects × ~1ms = ~90ms. Still negligible. Even with 5 partitions: ~150ms.

This design directly addresses three SURF-FIXIT-LIST items:
- **SURF-11** (decomposition masks data): Fixed by decomposing at the handoff and carrying all partitions through the 1D model
- **SURF-23** (swell display uses nearshore values): Fixed by displaying the handoff-point partitions as the swell card (deep water values)
- **SURF-22** (K-G at wrong depth): Fixed by applying K-G at each partition's actual break point from the 1D model

### Break point authority

**Conflict:** Two break point definitions will coexist:
- **SWAN's QB** — breaking fraction at each CURVE point (currently threshold 0.25, proposed 0.10 in SURF-9d)
- **1D model's H/d = gamma** — continuous crossing detection at CUDEM resolution

**Resolution:** The 1D model's break point is the primary authority for the beach profile chart and surf scoring (finer resolution, physically derived). SWAN's QB is retained as a diagnostic/validation metric and as the safety check for handoff depth refinement (§2.3.4 Step 4). The SURF-9d threshold lowering (QB from 0.25 to 0.10) remains valid as an independent improvement to SWAN's own break point detection, but the 1D model's output takes precedence when available.

---

## 8. SWAN's Structure Interaction Capabilities and Limitations

| Effect | Real-world example | SWAN accuracy |
|---|---|---|
| **Energy blocking** | Breakwater sheltering a beach | **Good.** OBSTACLE with `TRANSM 0.0`. |
| **Bathymetric refraction** | Reef passes, submarine canyons | **Good.** Core strength. |
| **Wave channeling** | Inlet mouths between jetties | **Partial.** Refraction/shoaling yes; phase-coherent amplification no. |
| **Current-wave interaction** | Ebb tide steepening waves | **Partial.** CURRENT input parameterized. |
| **Diffraction** | Waves wrapping around a pier tip | **Poor.** "Phase-decoupled models cannot in general deal with diffraction behind structures." |
| **Reflection** | The Wedge — wave doubling off jetty | **Poor.** Cannot compute reflection and diffraction simultaneously. |

**The Wedge (verified):** Constructive interference from south swell reflecting off the Newport Harbor jetty doubles wave height. SWAN cannot model this — it requires phase-coherent tracking (FUNWAVE-TVD).

**Implication:** SWAN + 1D works well for the majority of surf spots (open beaches, energy-blocking structures). Phase-coherent phenomena (reflection, diffraction bending) require FUNWAVE-TVD — a future capability.

**Rip currents and nearshore circulation** are NOT modeled by SWAN, the 1D model, or XBeach-1D. These are 2D circulation patterns requiring XBeach 2D or Delft3D-FLOW. Relevant to the beach safety tab, not the surf forecast.

---

## 9. L3 Grid Architecture with the 1D Model

SWAN L3's value in the nearshore is the **2D spatial wave energy field** — structure interaction and bathymetric refraction, not wave height accuracy (the 1D model does that better).

### Options

**Option 1: Keep L3 to shore + add 1D post-processing.** Zero risk. All 2D interaction preserved. **This is the v1 approach.**

**Option 2: Coarsen L3 (15-20m instead of 10m).** 2-4x compute savings. OBSTACLE energy blocking and bulk refraction don't need 10m resolution. The 1D model fills in surf zone detail. **Investigation needed** — and must include re-deriving DIFFRACTION smoothing parameters (`smnum=27` was tuned for 10m grid) and re-running the convergence gate validation from SWAN-L3-STABILITY-PLAN.

**Option 3: Truncate L3 at handoff depth.** Loses all nearshore structure interaction. **Not recommended** for structure-affected spots.

### LUT for expensive models

Pre-compute ~14,000 combinations per spot (Hs x Tp x DIR x tide) for XBeach-1D or FUNWAVE-TVD. Build overnight, look up at runtime. Only needed for models with multi-second runtime — the analytical 1D model at ~1ms doesn't need a LUT.

XBeach-1D surfbeat runtime is estimated at 10-120s per transect (see §3 Option B) but remains **unverified** — R6 benchmark needed before deciding LUT vs compute-on-demand.

---

## 10. Research Tasks (pre-implementation)

| # | Task | Method | Blocks |
|---|---|---|---|
| R1 | **Validate handoff algorithm** | Run the pre-model handoff algorithm (§2.3.4) for HB Pier. Compare its assigned depths against the CURVE QB profile. Verify QB ~ 0 at every assigned handoff point across 3-5 representative swell conditions. | Architecture decision |
| R2 | **Validate 1D model Hs** | ~~SWASH ground truth~~ — **REVISED 2026-07-21:** SWASH ruled out from all roles including benchmark referee (unvalidated itself). Validation via: (a) SWAN CURVE consistency in QB=0 zone (R3); (b) friction-bracket analysis (with/without bounds the truth); (c) cross-condition physical consistency; (d) webcam comparison (R10). See 1D-MODEL-BENCHMARK-BRIEF Part 7 §7.9. | Implementation |
| R3 | **Consistency check** | Verify that the 1D model reproduces SWAN's own CURVE Hs values in the QB=0 zone (automatic acceptance test). | Implementation |
| R4 | **Iribarren validation** | Compute xi_0 for known surf spots with documented breaker types. Cross-check against webcam/surf-report classification. | §5.4 |
| R5 | **Hold-down calibration** | Source empirical hold-down data from literature or surf safety research. Fit formula coefficients to match. | §5.7 |
| R6 | ~~**XBeach-1D benchmark**~~ | **COMPLETED / CLOSED 2026-07-21.** Round 1 measured XBeach at 10.3s/run = 93 hr/cycle. User ruled out XBeach for all roles. | — |
| R7 | ~~**SWAN SurfBeat-1D availability**~~ | **COMPLETED 2026-07-21.** SURFBEAT confirmed available in SWAN 41.45/41.51. Cannot run in 1D mode — requires regular 2D grid, stationary, two-COMPUTE procedure. Viable as SurfBeat strip (1D-MODEL-BENCHMARK-BRIEF §7.3). | — |
| R8 | **L3 coarsening impact** | Run L3 at 10m vs 15m vs 20m for the same swell event. Compare Hs at SPECOUT points and OBSTACLE shadow patterns. Re-derive DIFFRACTION smoothing parameters for each resolution. | Compute optimization |
| R9 | **Roller model necessity** | Implement Battjes-Janssen without roller, compare Hs profile with/without roller on a barred profile (Case B from benchmark). If inner-bar reformation is missing without the roller, the roller is confirmed necessary. Validate against SWAN CURVE consistency (R3) and webcam observation (R10). ~~SWASH ground truth~~ removed 2026-07-21. | §5.1 accuracy |
| R10 | **Webcam/surf-report comparison** | Qualitative validation — compare 1D model wave height and breaker type against live surf reports and webcam observations for 5-10 sessions. | Overall confidence |
| R11 | **Multi-transect peel angle validation** | Compute peel angle from multi-transect break points for known spots. Compare against webcam observations and Surfline/BSR peel descriptions. | §5.8 |

---

## 11. Gemini Fact-Check

The user received multi-1D architecture suggestions from Gemini. Fact-check against peer-reviewed sources:

| Gemini claim | Verdict | Reality |
|---|---|---|
| "Multi-1D is an established technique" | **Correct** | CoSMoS (USGS) and FEMA both use parallel 1D transects. Established methodology. |
| "XBeach-1D run takes less than 3 seconds" | **Unverified** | No published benchmark for XBeach-1D surfbeat with morfac=0. Estimated 10-120s depending on domain length. For the analytical 1D model, it's ~1ms. Gemini conflates the two. |
| "Peel angle from time delay between runs" | **Wrong mechanism, right conclusion** | Steady-state models have no time progression between transects. Peel angle comes from spatial variation of break point location across transects with a shared time reference. |
| "50-100m for open beaches, 10m near structures" | **Wrong scale** | 100m is for regional flood mapping. For surf spot scale: 10-20m everywhere. |
| "Captures complex sandbar topography" | **Correct** | Primary advantage — each transect gets its own CUDEM bathymetric profile. |
| "2D context without 2D compute cost" | **Correct with caveats** | True for cross-shore processes. Cannot resolve longshore currents, rip currents, wave-current interaction, or diffraction — these are inherently 2D. |
| "Dense spacing near structures, coarse on open beaches" | **Wrong for surf** | Variable spacing saves compute for regional mapping. At surf spot scale, uniform 10-20m is cheap and resolves all features. |

---

## 12. References

- Baldock, T.E., Holmes, P., Bunker, S., and van Weert, P. (1998). "Cross-shore hydrodynamics within an unsaturated surf zone." Coastal Engineering, 34(3-4), 173-196.
- Barnard, P.L., et al. (2014). "Development of the Coastal Storm Modeling System (CoSMoS) for predicting the impact of storms on high-energy, active-margin coasts." Natural Hazards, 74(2), 1095-1125.
- Battjes, J.A. (1974). "Surf similarity." Proc. 14th Int. Conf. Coastal Eng., ASCE, pp. 466-480.
- Battjes, J.A. and Janssen, J.P.F.M. (1978). "Energy loss and set-up due to breaking of random waves." Proc. 16th Int. Conf. Coastal Eng., ASCE, pp. 569-587.
- Castelle, B., et al. (2016). "Rip current types, circulation and hazard." Earth-Science Reviews, 163, 1-21.
- Contardo, S. and Symonds, G. (2016). "Bathymetric control on spatial distribution of wave breaking." Coastal Engineering, 114, 25-37.
- Deltares (2020). "Boundary Condition Guidelines for XBeach Simulations." Technical Report.
- Enet, F., et al. "Evaluation of diffraction behind a semi-infinite breakwater in the SWAN wave model." 9th International Workshop on Wave Hindcasting and Forecasting.
- FEMA (2019). "Coastal Floodplain Mapping — Guidance for Coastal Flood Hazard Analyses." November 2019.
- Fenton, J.D. (1999). "The cnoidal theory of water waves." Developments in Offshore Engineering, pp. 55-100.
- Fiedler, J.W., et al. (2019). "The offshore boundary condition in surf zone modeling." Coastal Engineering, 143, 12-20.
- Hutt, J.A., Black, K.P., and Mead, S.T. (2001). "Classification of surf breaks in relation to surfing skill." Journal of Coastal Research, SI 29, pp. 66-81.
- Longuet-Higgins, M.S. (1970). "Longshore currents generated by obliquely incident sea waves." Journal of Geophysical Research, 75(33), 6778-6789.
- Malej, M., et al. (2025). "A Comprehensive Review of Phase-Averaged and Phase-Resolving Wave Models for Coastal Modeling Applications." arXiv:2511.21856.
- NHESS (2022). "Estimating dune erosion at the regional scale using a meta-model based on neural networks." Natural Hazards and Earth System Sciences, 22, 3897-3915.
- Reniers, A.J.H.M. and Zijlema, M. (2022). "SWAN SurfBeat-1D." Coastal Engineering, 172, 104068. (Citation corrected 2026-07-21 — previously mis-attributed to Rijnsdorp. Implementation restrictions verified against the SWAN 41.51 manual: see 1D-MODEL-BENCHMARK-BRIEF Part 7 §7.2.)
- Roelvink, D., et al. (2025). "SnapWave: fast, implicit wave transformation from offshore to nearshore." Geoscientific Model Development, 18, 9469-9490.
- Scarfe, B.E., Healy, T.R., and Rennie, H.G. (2003). "Research-based surfing literature for coastal management and the science of surfing." Journal of Coastal Research, 25(3), 539-557.
- Svendsen, I.A. (1984). "Mass flux and undertow in a surf zone." Coastal Engineering, 8(4), 347-365.
- USACE Coastal Engineering Manual (CEM), Chapter II-3: "Wave Transformation."
- Van der Westhuysen, A.J. (2010). "Modeling of depth-induced wave breaking under finite depth wave growth conditions." J. Geophys. Res., 115, C01008.
- Vitousek, S. and Barnard, P.L. (2017). "Integrating Longshore and Cross-Shore Processes for Predicting Long-Term Shoreline Response to Climate Change." JGR Earth Surface, 122(4), 782-806.
- Walker, J.R. (1974). "Recreational surf parameters." Look Laboratory Technical Report No. 30, University of Hawaii.
- Yuan, Y., et al. (2020). "FUNWAVE-GPU: Multiple-GPU Acceleration of a Boussinesq-Type Wave Model." JAMES, 12, e2019MS001957.

**Model documentation:**
- CSHORE 2022 (USACE ERDC): https://www.erdc.usace.army.mil/Media/Fact-Sheets/Fact-Sheet-Article-View/Article/2638911/cshore/
- FUNWAVE-TVD: https://github.com/fengyanshi/FUNWAVE-TVD
- SimpleWaves1D (MATLAB reference): https://github.com/mstresser/SimpleWaves1D
- SWAN Limitations: https://swanmodel.sourceforge.io/online_doc/swanuse/node4.html
- SWAN SurfBeat-1D: https://doi.org/10.1016/j.coastaleng.2021.104068
- SWASH: https://swash.sourceforge.io/
- XBeach: https://xbeach.readthedocs.io/en/stable/

**Surf science references:**
- The Wedge wave physics: https://en.wikipedia.org/wiki/The_Wedge_(surfing)
- Wave breaking classification: https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/05:_Coastal_hydrodynamics/5.02:_Wave_transformation/5.2.5:_Wave_breaking
- Peel angle and surfability: Scarfe, B.E. (2002). "Categorising surfing manoeuvres using wave and reef characteristics." M.Sc. thesis, University of Waikato.
- Diffraction theory: https://geo.libretexts.org/Bookshelves/Oceanography/Coastal_Dynamics_(Bosboom_and_Stive)/05:_Coastal_hydrodynamics/5.02:_Wave_transformation/5.2.4:_Diffraction
