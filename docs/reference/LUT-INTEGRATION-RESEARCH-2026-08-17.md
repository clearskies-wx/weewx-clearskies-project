# LUT Integration Research Brief — Precomputed Wave Transfer for the Clear Skies Marine System

**Date:** 2026-08-17  
**Author:** Coordinator (Opus), research via web search + published literature  
**Purpose:** Determine how to replace per-cycle wave model runs with precomputed
lookup tables (LUTs). This brief feeds the plan restructuring and ADR-110 design.  
**Audience:** The project operator. Every technical term is defined at first use.

---

## 1. The problem this brief addresses

The current marine system runs four wave models in sequence every forecast cycle:

1. **WW3** (WaveWatch III) — propagates swell (long-period waves generated far away)
   from NOAA's deep-ocean boundary data through the Southern California Bight's
   island geometry to intermediate water depth. Runtime: **~70 minutes.**
2. **SWAN L2** (Simulating WAves Nearshore, level 2) — propagates waves from the WW3
   output through intermediate depths where bottom friction begins to matter.
   Runtime: **~10 minutes.**
3. **SWAN L3/L4** (levels 3 and 4) — resolves wave behavior around complex local
   features like piers, harbors, and headlands at fine grid resolution. Only runs
   where the surf spot's geometry requires it. Runtime: **~5–10 minutes.**
4. **SurfBeat** — a 1D (one-dimensional, cross-shore only) model that transforms
   waves through the surf zone (the breaking region near the beach) to produce
   the final surf forecast. Runtime: **seconds.**

**Total per-cycle compute: ~90+ minutes,** dominated by WW3 and SWAN.

The operator's direction (2026-08-15, confirmed 2026-08-17): replace per-cycle model
runs with precomputed transfer functions that produce results in seconds. Accept a
more intensive one-time upfront computation in exchange for eliminating the per-cycle
cost permanently.

---

## 2. What a "transfer function" is and why it works

A **transfer function** (also called a transfer coefficient or transfer matrix) is a
precomputed multiplier that maps wave energy at one location to wave energy at
another location. If you know the wave spectrum (energy at each frequency and
direction) at an offshore boundary, you multiply each spectral bin by its
precomputed transfer coefficient to get the wave spectrum at a nearshore point.

**Why this works for swell:** In deep and intermediate water, swell propagation is
**linear** — each frequency-direction component of the wave spectrum travels
independently through the domain, bending (refracting) according to the water depth
and being blocked by islands. The total wave field is simply the sum of all
components. Because each component is independent, you can precompute how each one
transforms through the domain geometry and apply that transformation to any new
incoming spectrum instantly.

**Where this breaks down:** The transfer-function approach fails when the physics
becomes **nonlinear** — when the transformation of one wave component depends on
the presence of other components or on the wave height itself. The primary nonlinear
process in wave modeling is **depth-limited breaking**: when a wave enters water
shallower than roughly 1.3× its height, it breaks and loses energy. The amount of
energy lost depends on the wave height, which means the transfer is not a fixed
coefficient — it changes with the conditions. Breaking is the boundary between what
can be precomputed and what must be computed per-cycle.

---

## 3. What the field does — operational precedents

### 3.1 CDIP (Coastal Data Information Program) — the direct precedent

**What it is:** An operational wave monitoring and prediction system run by the
Scripps Institution of Oceanography at UC San Diego. Covers the entire California
coast, including the Southern California Bight — the same geography as our system.
Has been operational for over 15 years.

**How it works:**
1. Deep-water wave buoys measure the 2D wave spectrum (energy as a function of
   frequency and direction) continuously.
2. **Precomputed transfer coefficients** — computed once per bathymetry using
   **backward ray tracing** (explained below) — transform the deep-water spectrum
   to nearshore output points at ~10–15 m water depth, spaced ~100 m along the
   coast.
3. Per-cycle runtime: **milliseconds** per spectrum (a matrix multiplication).
4. Coefficients rebuild only when bathymetry changes (rare — years between updates).

**What CDIP does NOT cover with its LUT:**
- **Wind-sea** (locally generated short-period waves, typically < 8 seconds period).
  Wind-sea is not a boundary-propagation problem — it's created by local wind
  blowing over local water. CDIP handles wind-sea separately using nearby buoy
  observations, not the transfer matrix.
- **Breaking.** CDIP's output points are at 10–15 m depth, above the breaking zone
  for most conditions. The surf zone is outside their transfer-function domain.

**Sources:** O'Reilly, W.C. and Guza, R.T. (1993), "A comparison of two spectral
wave models in the Southern California Bight," *Coastal Engineering* 19:263–282.
O'Reilly et al. (2016), "The California Coastal Wave Monitoring and Prediction
System," *Coastal Engineering* 116:118–132. Crosby et al. (2019), "Regional Swell
Transformation by Backward Ray Tracing and SWAN," *J. Atmos. Ocean. Tech.* 36(2).

### 3.2 Backward ray tracing — the precomputation method

**What it is:** A technique for computing transfer coefficients. Instead of sending
wave energy forward from offshore toward the coast (which creates mathematical
singularities called **caustics** where rays converge), you trace rays **backward**
from each nearshore output point out to deep water. This tells you, for each
(frequency, direction) bin at the output point, where the energy came from and how
much of it survived the journey through the bathymetry.

**Why backward:** Forward ray tracing fails in complex bathymetry (islands, submarine
canyons) because rays pile up at caustics. Backward ray tracing avoids this by
design — each output point gets its own set of rays, each traced independently.

**Computational structure:** Each ray (one per frequency × direction × output point)
is fully independent of every other ray. This is called "embarrassingly parallel" —
the computation scales perfectly with the number of CPU cores or GPU threads.

**Existing tool:** **WaveRay** (Oceanum, New Zealand) is an open-source Python
package (pip install waveray, github.com/oceanum/waveray) that implements the
O'Reilly/Guza backward ray tracing methodology. It precomputes a transfer operator,
saves it to a file, and applies it to new spectra at runtime. WaveRay currently
uses CPU only (numpy); it has no GPU support.

**Sources:** Crosby et al. (2019) — methodology paper. WaveRay documentation at
oceanum.github.io/waveray.

### 3.3 Dutch Wave Transformation Matrix (WTM) — the nearshore approach

**What it is:** A precomputed lookup table for nearshore wave conditions, built by
running SWAN in stationary mode (SWAN solves for the steady-state wave field given
fixed boundary conditions, without time-stepping) for a matrix of offshore wave
conditions. The WTM stores the nearshore output for each combination of offshore
(Hs, Tp, direction, water level). At runtime, the nearshore conditions for any
given offshore state are obtained by interpolation from the table.

**Where it's used:** Rijkswaterstaat (Dutch national water authority) and Deltares
use WTMs operationally for the entire Holland Coast. Validated against field
measurements with correlation coefficients ≥ 0.9 for Hs, direction, period, and
surge.

**Key design parameter — dimensionality:** The number of precomputed SWAN runs
scales multiplicatively with the number of parameter values:
- 2D WTM (Hs × direction): works where breaking and friction are not significant
- 3D WTM (adding water level OR period): needed where breaking or friction causes
  significant energy dissipation — water level shifts the breaking point
- 4D WTM (Hs × Tp × direction × water level): needed for the full nearshore, costs
  thousands of SWAN runs

**Sources:** Bianco and Lavagnini (2024), "Efficient computation of wave
transformation matrices to support coastal management," *Estuarine, Coastal and
Shelf Science.* Dutch Coast WTM documentation at ecoshape.org. BinWaves
documentation, University of Cantabria.

### 3.4 SnapWave — the fast-solver alternative

**What it is:** An open-source implicit wave transformation model developed by
Deltares (the same organization behind SWAN). SnapWave is NOT a LUT — it solves the
wave propagation equations at runtime, but 200× faster than SWAN by using simplified
physics (no wind input, no quadruplet interactions) and an efficient implicit
numerical scheme.

**What it includes:** Refraction, shoaling, breaking (Baldock et al. 1998
formulation), and bottom friction.

**What it excludes:** Wind input, nonlinear wave-wave interactions, diffraction.

**Performance:** 0.15–0.6 microseconds per grid node per directional bin per wave
condition. A 340,000-node coastal model runs in 1.9 seconds per condition. 200×
faster than SWAN on the same grid.

**Relevance:** SnapWave could replace SWAN for the nearshore portions (L2, L3/L4)
either as a per-cycle fast solver OR as the engine inside a WTM (replacing the
thousands of SWAN runs with thousands of SnapWave runs, shrinking precomputation
from days to minutes).

**Source:** Roelvink et al. (2025), "SnapWave: an efficient spectral wave model for
nearshore and coastal applications," *Geoscientific Model Development* 18:9469.

### 3.5 NOAA NWPS — the per-cycle model approach (no LUT)

**What it is:** NOAA's Nearshore Wave Prediction System. Runs WW3 for deep water,
then SWAN for nearshore, fully per-cycle — no precomputation, no LUT.

**Why no LUT:** NWPS includes wind input, wave-current interaction, water level
variations, and breaking — physics that is either nonlinear, time-dependent, or
state-dependent. NWPS runs on NOAA's supercomputer and accepts the compute cost.

**Relevance:** NWPS demonstrates that a pure per-cycle approach works but requires
substantial compute resources. Our system needs to run on a single server, not a
supercomputer — hence the LUT direction.

**Source:** NOAA NWPS documentation at emc.ncep.noaa.gov and polar.ncep.noaa.gov.

---

## 4. Per-model analysis — what gets precomputed, what keeps running

### 4.1 WW3 (deep water): PRECOMPUTE VIA RAY TRACING

**Confidence: HIGH.** CDIP does exactly this, in the same geography, operationally.

**What happens:** Backward ray tracing computes transfer coefficients for each
(frequency, direction) bin at each output point. Output points are the L2 boundary
locations plus any deep-water validation points (buoys).

**Per-cycle after LUT:** Fetch NOAA spectrum → multiply by transfer coefficients →
output spectra at all points. **Milliseconds.**

**Precomputation cost:** The only published claim (WaveRay documentation) is
"seconds" per output site for operator construction. For our domain (~200 output
points), this suggests minutes on CPU. No published benchmark exists for a domain
of our size (143×171 cells, ~1 km resolution, Channel Islands geometry). The
computation is embarrassingly parallel (each ray independent).

**Precomputation cost is an OPEN QUESTION.** The "minutes" estimate is informal.
The actual cost for our specific domain must be measured by prototype, not assumed.

**Rebuild trigger:** Geometry change only (new spot, bathymetry update).

**Wind-sea gap:** Transfer coefficients do NOT capture wind-sea (locally generated
waves < ~8 s period). See §5.

### 4.2 SWAN L2 (intermediate depth): OPEN — DEPENDS ON BREAKING INCIDENCE

**Confidence: LOW.** The right approach depends on whether breaking occurs within
L2's depth range, which has not been analyzed.

**If no breaking in L2's domain (depths stay > ~10 m):** The ray tracing transfer
from §4.1 can extend through L2's depth range to its output boundary. No separate
treatment needed. L2 disappears into the LUT along with WW3.

**If breaking occurs in L2's domain (some spots have L2 output in shallower water):**
The transfer becomes nonlinear where breaking happens. Options:
1. **Dutch WTM** — precompute SWAN stationary runs for a matrix of conditions.
   Requires thousands of runs, but L2 grids are moderate-sized.
2. **SnapWave** — replace SWAN L2 with SnapWave per-cycle (seconds, includes
   breaking). Not a LUT, but achieves the same goal (eliminate the 10-minute cost).
3. **Extend ray tracing + add a breaking correction** — apply the linear transfer,
   then apply a parametric breaking dissipation at the output depth. This is an
   approximation; accuracy depends on how much breaking occurs.

**OPEN QUESTIONS:**
1. What is L2's output depth range across all configured spots?
2. How often does breaking occur within L2's domain?
3. If L2 needs separate treatment: WTM vs. SnapWave vs. breaking correction?

### 4.3 SWAN L3/L4 (nearshore, complex features): OPEN — BREAKING IS CERTAIN

**Confidence: LOW.** Breaking is certain at L3/L4 depths (2–10 m for typical swell).
The linear transfer-function approach does not work here. Multiple alternatives exist
in the literature; the best choice for our system has not been determined.

**Options from the literature:**
1. **Dutch WTM** — precompute SWAN (or SnapWave) stationary runs for a condition
   matrix. L3/L4 grids are small, so individual runs are fast. But each spot has
   its own L3/L4 grid, so the WTM must be built per-spot.
2. **SnapWave per-cycle** — replace SWAN L3/L4 with SnapWave. Seconds per solve,
   includes breaking. No precomputation. Simple.
3. **Keep running SWAN** — L3/L4 grids are small and already fast (~5 min). If the
   combined savings from LUT-replacing WW3 + L2 bring total per-cycle time to
   ~5 minutes, this may be acceptable without further optimization.

**Factors that may constrain the choice:**
- Does L3/L4 require diffraction (wave bending around piers, harbor entrances)?
  SnapWave does NOT include diffraction. SWAN does (command DIFFRACTION, used in
  our L3/L4 decks per ADR-102).
- How many spots have L3/L4 grids? If few, the per-spot WTM build cost is small.

**OPEN QUESTIONS:**
1. WTM vs. SnapWave vs. keep-running-SWAN for L3/L4?
2. Does diffraction rule out SnapWave for these grids?
3. How many spots require L3/L4?

### 4.4 SurfBeat (1D surf zone): KEEPS RUNNING PER-CYCLE

**Confidence: HIGH.** All sources in the research agree. No proven operational
system precomputes surf zone breaking physics via LUT.

**Why it can't be a LUT:** The surf zone is dominated by **depth-limited breaking**
— waves break when they enter water shallower than roughly 1.3× their height. This
is nonlinear: the energy lost depends on the wave height itself, not just the
geometry. A static transfer coefficient that depends only on geometry cannot capture
this. Additionally, **infragravity waves** (long-period oscillations generated by
groups of breaking waves) are produced by a process that requires information about
wave groups, which a spectral transfer matrix discards.

**Why this is fine:** SurfBeat already runs in **seconds per cycle.** It is not the
compute bottleneck. Eliminating the WW3 + SWAN upstream cost from ~80 minutes to
seconds means the total per-cycle pipeline becomes: LUT lookups (milliseconds) +
SurfBeat (seconds) = **seconds total.** SurfBeat's cost is negligible in this
picture.

**One published research-stage alternative:** Echevarria et al. (2025, *JGR: Machine
Learning and Computation*) precompute XBeach-SurfBeat runs for representative
conditions and use ML interpolation for operational efficiency. This is not deployed
operationally anywhere and is not recommended for our system at this time.

**Sources:** Battjes and Janssen (1978), "Energy loss and set-up due to breaking in
random waves." Thornton and Guza (1983), "Transformation of wave height
distribution." Echevarria et al. (2025).

---

## 5. Wind-sea: handled via parametric formula with precomputed fetch

**What wind-sea is:** Short-period waves (typically < 8 seconds) generated by local
wind blowing over the water surface. Unlike swell (which travels from distant storms
and arrives at the boundary), wind-sea is created locally within the domain.

**Wind-sea CANNOT be dropped.** It is a mandatory component of the forecast. In
swell-dominated environments (Southern California), wind-sea contributes 0.3–0.8 ft
during afternoon sea breezes and can be the largest individual spectral component
at sheltered locations (CDIP 092 Aug 16 2026: 2.5 ft @ 6s from W was the dominant
component). **On the Great Lakes, wind-sea IS the entire forecast** — there is no
distant ocean swell. Dropping wind-sea would produce zero forecast for any Great
Lakes installation.

**Wind-sea CAN be precomputed / looked up.** The inputs to wind-sea generation are
all known or precomputable:

1. **Wind speed** — known from GFS forecast. A predictable input, available every
   cycle.
2. **Wind direction** — known from GFS forecast. Same.
3. **Fetch** — the distance the wind blows unobstructed over water before reaching
   the output point. Fetch depends on the **geometry** (coastline shape, islands,
   lake boundaries) and the wind direction. For a fixed geometry, fetch is a fixed
   function of wind direction at each output point — **precomputable, one-time,**
   using the same ray-tracing methodology (trace rays from each point outward in
   each direction until they hit land) that the swell transfer uses. Our system
   already computes fetch: the ray-tracing fetch fan in the setup-derivation chain
   (``compute_domains()``, ``cast_fetch_fan()``) calculates fetch distances for each
   spot as a function of direction.

**How wind-sea enters the LUT pipeline:**

**Precompute (one-time per geometry):**
- For each output point and each wind direction, compute fetch by tracing from
  the point in the upwind direction until hitting land. Store the fetch table:
  ``fetch(output_point, wind_direction) → distance_in_meters``.

**Per-cycle (runtime):**
- Read GFS wind speed ``U`` and direction ``θ`` for the forecast hour.
- Look up ``fetch = fetch_table[point][θ]``.
- Apply a standard parametric formula to compute the wind-sea spectrum:
  - **JONSWAP** (Hasselmann et al. 1973): the standard spectral shape for
    fetch-limited wind-sea. Produces peak frequency, spectral shape, and Hs as
    functions of (wind speed, fetch). Well-established, textbook equations.
  - **Pierson-Moskowitz** (1964): the fully-developed wind-sea spectrum, a special
    case of JONSWAP for unlimited fetch.
  - **SMB (Sverdrup-Munk-Bretschneider)** method: empirical Hs and Tp from
    (wind speed, fetch, duration). The simplest approach.
- The parametric calculation is a formula evaluation — **microseconds**, not a
  model run.
- Add the wind-sea spectrum to the swell spectrum from the swell transfer LUT.
- Total output = swell (from swell LUT) + wind-sea (from parametric formula).

**Why this works for the Great Lakes:** The same approach applies. Fetch depends on
lake geometry and wind direction (precomputable from the lake's coastline). Wind-sea
spectrum depends on (wind speed, fetch) — same parametric formulas. The only
difference: on the Great Lakes, wind-sea IS the forecast (the swell LUT contributes
nothing or nearly nothing), so the parametric wind-sea accuracy is more critical.
For large lakes where the wind field varies spatially across long fetches, a
multi-point fetch correction or a WTM indexed by (wind speed, wind direction) may
be needed — this is an ADR-110 design question.

**What CDIP does differently and why:** CDIP uses local buoy observations for
wind-sea instead of parametric formulas, because they have buoys everywhere along
the California coast and buoy measurements are more accurate than any formula. Our
system cannot assume a buoy at every spot, so the parametric approach is the
right path — it works everywhere, requires only GFS wind (already fetched) and
precomputed fetch (geometry-only), and adds zero per-cycle compute.

**Great Lakes: spatially varying wind over long fetches (RESEARCHED 2026-08-17).**

The standard parametric formulas (JONSWAP, SMB, CEM) assume uniform wind along
the fetch. This is baked into the math. For the Great Lakes, where fetches exceed
100-200 km and GFS wind can vary significantly across that distance (especially
during frontal passages), three approaches exist:

1. **Fetch-average wind:** Average GFS wind values along the fetch path, plug into
   JONSWAP. The retired NOAA GLERL parametric model (Schwab et al. 1984, operational
   1984-2006) did essentially this — used wind at the prediction point with geometric
   fetch, acknowledged spatial uniformity as a limitation. For strong sustained
   synoptic winds (the dominant wave-generation case), this is adequate within
   ~10-20% for Hs. For frontal/transitional events, it can be significantly wrong.
   (Source: NOAA TM GLERL-51)

2. **Kudryavtsev characteristic-form integration** (Kudryavtsev, Yurovskaya, and
   Chapron, 2021, "2D Parametric Model for Surface Wave Development Under Varying
   Wind Field in Space and Time," JGR Oceans 126(4)): Integrates the parametric
   growth equations along FETCH RAYS using local wind at each point — the wind-sea
   analog of backward ray tracing for swell. Fast per-cycle computation (orders
   of magnitude faster than SWAN/WW3). Handles spatially varying wind correctly.
   Published and validated for open-ocean extra-tropical cyclones; NOT validated
   for lake applications. This is the theoretically correct solution.

3. **Wind-sea WTM:** Precompute stationary SWAN runs indexed by (wind speed, wind
   direction) instead of the swell WTM's (Hs, Tp, direction, water level). For a
   single output point: 12 wind speeds × 36 directions = 432 precomputed runs.
   Feasible but never published for lake applications.

**For SoCal (the current installation):** Simple parametric (single-point wind +
precomputed fetch) is sufficient. Fetches are short (< 50 km), swell dominates,
wind-sea is secondary.

**For Great Lakes:** Either Kudryavtsev integration (fast per-cycle, correct physics)
or the wind-sea WTM (precomputed, millisecond lookup). Both require validation
against NDBC Great Lakes buoys (45001-45012) — a Phase V activity for a Great Lakes
test installation, not a SoCal blocker.

**Sources:** Schwab, Bennett, and Lynn (1984), NOAA TM GLERL-51. Kudryavtsev et al.
(2021), JGR Oceans 126(4). Donelan (1980). Rohweder et al. (2018), Scientific Data
5:180295 (Great Lakes effective fetch maps). USACE CEM EM 1110-2-1100 Part II Ch 2.
Alves et al. (2023), BAMS 104(4) (GLWU). Anderson and Schwab (2024), GMD 17:1023.

---

## 6. Precomputation cost

### 6.1 Ray tracing (deep water, §4.1)

**Published data:** No wall-clock benchmarks exist in the literature for backward ray
tracing at our domain scale. WaveRay docs claim "seconds" per site. Papers describe
the computation as "efficient" and "embarrassingly parallel" without reporting
timing.

**Structure of the computation:** For our domain:
- Output points: ~200 (L2 boundary + surf spots + buoy validation points)
- Spectral bins: 35 freq × 72 dir = 2,520 per output point
- Total rays: ~504,000
- Each ray: integrate an ODE (ordinary differential equation — Snell's law) through
  ~160 grid cells of bathymetry
- Each ray is independent (parallelizable)

**Must be measured by prototype.** The "minutes on CPU" estimate is a first-principles
extrapolation, not a published number. The actual cost depends on integration step
size, convergence criteria, and island-interaction complexity. A prototype
measurement is required before the plan can commit to a precomputation budget.

### 6.2 SWAN WTM (nearshore, §4.2/§4.3, if needed)

**Published data:** A typical 4D WTM requires:
- 8 Hs × 8 Tp × 24 directions × 4 water levels = 6,144 SWAN stationary runs
- Each SWAN stationary run on a ~25,000-cell grid: ~1.5 seconds (extrapolated from
  published per-grid-point cost of 6.0×10⁻⁵ s, Dietrich et al. 2021 GMD)
- Total: ~2.5 hours single-core, ~20 minutes on 8 cores

**If SnapWave replaces SWAN:** 200× faster → total drops to ~45 seconds single-core.

**Per-spot:** Each spot's L3/L4 grid needs its own WTM. With small grids (L3/L4 are
fine-resolution but spatially limited), each WTM build is fast. Multiply by number
of spots.

### 6.3 Rebuild lifecycle

| Trigger | What rebuilds | Expected frequency |
|---------|--------------|-------------------|
| New spot added | Ray tracing for the new spot's output points + WTM for its L3/L4 grid | Per spot addition |
| Bathymetry update | Full ray tracing rebuild + all WTMs | Rare (years between significant surveys) |
| Model physics change | All WTMs (ray tracing unaffected if physics change is in source terms only) | Rare (operator-ruled) |
| Spot relocated | Same as new spot added | Per relocation |

---

## 7. GPU acceleration

**Current state:** No existing wave ray tracing tool (WaveRay, CDIP SRM, or any
published system) uses GPU acceleration. WaveRay is CPU-only (numpy).

**Applicability:** Backward ray tracing is a near-ideal GPU workload — hundreds of
thousands of independent rays, each a simple ODE integration. Published GPU ray
tracing in related fields (underwater acoustics) achieves 67–6700× speedup.

**Our hardware:** librewxr has an NVIDIA RTX A400 (Ampere, 768 CUDA cores, 4 GB
VRAM). Driver loaded, but CUDA toolkit and GPU Python packages are not installed.
The A400 is entry-level — fine for prototyping, limited for production. Estimated
ray tracing speedup: 10–50× over single CPU core.

**Recommended approach:** Prototype on CPU first (using WaveRay or custom
implementation). If precomputation time is a concern, add GPU acceleration using
Numba CUDA (fastest Python path) or JAX (production-quality). The computation
structure maps directly to GPU threads with no algorithmic changes needed.

**For the SWAN WTM portion:** GPU does not help. SWAN has no GPU port. The
parallelism is CPU multi-process (many independent SWAN instances). SnapWave is
CPU-only but 200× faster than SWAN, achieving comparable speedup without GPU.

**Sources:** WaveRay GitHub (no GPU refs). KTH thesis on GPU underwater acoustic ray
tracing. WW3 OpenACC port (Abdolali et al. 2023, GMD). WAM6-GPU (Wedi et al. 2024,
GMD — 37× speedup on 8 A100s). SnapWave (Roelvink et al. 2025, GMD).

---

## 8. Summary — the per-cycle pipeline after LUT integration

### What is definitively resolved

| Component | Treatment | Confidence | Basis |
|-----------|----------|------------|-------|
| WW3 deep-water swell propagation | **Precomputed** via backward ray tracing transfer coefficients | **HIGH** | CDIP 15-year operational precedent in same geography |
| Wind-sea generation | **Parametric formula with precomputed fetch** — fetch is geometry-only (one-time ray trace), wind speed/direction from GFS, JONSWAP/SMB formula at runtime (microseconds) | **HIGH** | Standard parametric methods (JONSWAP, Pierson-Moskowitz, SMB); our system already computes fetch; inputs (wind speed, direction) are known per-cycle from GFS |
| SurfBeat 1D surf zone | **Keeps running per-cycle** — already fast (seconds), physics is nonlinear, no proven LUT method | **HIGH** | Universal agreement across all sources |
| Wind-sea | **Separate handling** — LUT cannot capture it; buoy obs, parametric, or lightweight model | **HIGH** (that LUT can't do it) | Universal agreement |

### Resolved by operator direction (2026-08-17: "if we are computing LUTs lets get it done once")

| Component | Treatment | Confidence | Basis |
|-----------|----------|------------|-------|
| SWAN L2 intermediate depth | **Precomputed WTM** — stationary model runs for a condition matrix (Hs, Tp, direction, water level), one-time per geometry | **HIGH** | Dutch WTM operational precedent; operator direction to precompute everything |
| SWAN L3/L4 nearshore | **Precomputed WTM** — same approach, per-spot grids | **HIGH** | Same; L3/L4 grids are small, so per-spot WTM build is fast |

### Remaining ADR-110 implementation questions

| Question | Options | Key dependency |
|----------|---------|---------------|
| WTM engine: SWAN stationary or SnapWave? | (a) SWAN stationary — proven, includes diffraction, (b) SnapWave — 200× faster, no diffraction | Whether L3/L4 spots need diffraction |
| Precomputation cost budget | Measured by prototype | WTM build time on our hardware |
| GPU investment | Prototype on CPU first; add GPU if precompute time is a concern | Measured precompute time |

### Expected per-cycle runtime after LUT

| Scenario | Per-cycle compute | Notes |
|----------|------------------|-------|
| Best case (ray tracing covers through L2, no L3/L4 at this spot) | Milliseconds (swell LUT + wind-sea parametric) + seconds (SurfBeat) = **seconds** | Most spots |
| Moderate case (L3/L4 needed, handled by SnapWave) | Milliseconds (swell LUT + wind-sea) + seconds (SnapWave) + seconds (SurfBeat) = **seconds** | Complex spots |
| Conservative case (L3/L4 keeps running SWAN) | Milliseconds (swell LUT + wind-sea) + minutes (SWAN L3/L4) + seconds (SurfBeat) = **~5 minutes** | If SnapWave can't handle diffraction |

**All scenarios: 90+ minutes drops to seconds or single-digit minutes.** Wind-sea
adds zero meaningful compute in any scenario (parametric formula evaluation =
microseconds).

### Out-of-range input handling — boundary monitor + correction runs

The LUT covers a precomputed parameter space. Real ocean conditions can exceed
that space — an unusually long-period groundswell from a direction the LUT doesn't
cover, extreme wind speeds, anomalous water levels. The system must detect this
and respond correctly, never silently extrapolate.

**Per-cycle bounds check (before every lookup):**

Each cycle, before performing any LUT lookup, compare the current inputs against
the precomputed parameter ranges:

- **Swell LUT:** Does the incoming NOAA spectrum contain energy in (frequency,
  direction) bins that fall outside the precomputed transfer coefficient grid?
  (Unlikely if the spectral grid matches the reconstruction axes, but possible
  for very low-frequency energy outside the grid's range.)
- **Wind-sea LUT:** Does the current GFS wind speed or direction fall outside the
  precomputed (wind speed, wind direction) grid? (Possible during extreme events —
  hurricane-force winds, unusual directions.)
- **Nearshore WTM:** Does the intermediate-depth Hs, Tp, direction, or water level
  fall outside the precomputed condition matrix? (Possible during large swell
  events combined with extreme tides.)

**What happens when an input is out of range:**

| Condition | Action |
|-----------|--------|
| All inputs within LUT range | Normal lookup — milliseconds |
| One or more inputs outside LUT range | **Refuse the lookup. Run the actual model** (backward ray tracing, Kudryavtsev integration, SWAN/SnapWave stationary, or full chain as needed) for the out-of-range condition. **Add the result to the LUT** so the same condition never triggers a second model run. |

**Design principles:**

1. **The LUT starts with a conservatively wide parameter grid.** Size it using
   historical buoy and wind data for the region — cover the range of conditions
   the site actually sees. For SoCal swell: historical NDBC/CDIP records give the
   observed (Hs, Tp, direction) envelope. For wind: GFS wind climatology gives
   the observed (speed, direction) range. The initial grid should cover at least
   the 99th percentile of historical conditions.

2. **The per-cycle bounds check is trivial.** Comparing input values against the
   LUT's index ranges is a simple min/max check — microseconds, no model needed.

3. **Out-of-range triggers a model run, not an extrapolation.** Extrapolating
   outside the precomputed grid can produce physically nonsensical results
   (negative energy, direction reversals, unbounded growth). The system runs the
   actual model instead — slower (minutes), but correct. This is the existing
   refuse-not-degrade posture (PRIME DIRECTIVE 8) applied to the LUT: if the
   LUT can't answer, refuse the fast path and take the slow-but-correct path.

4. **The correction result gets folded back into the LUT.** After the model run
   completes, the new (input → output) mapping is added to the LUT's stored
   table. The next time the same unusual condition occurs, it's a normal lookup.
   The LUT grows over time to cover the site's full observed climate.

5. **Out-of-range is a named health state.** The health/refuse surface (PW5)
   reports "LUT correction run in progress" as a specific, visible state — not
   a silent degradation. The cycle may take minutes instead of seconds; the
   operator and the admin page see why.

6. **Rebuild vs. extend.** A geometry change (new spot, bathymetry update)
   triggers a full LUT REBUILD (new transfer coefficients, new WTM, new fetch
   table). An out-of-range condition triggers a LUT EXTENSION (add entries to
   the existing table without recomputing the rest). These are different
   operations with different costs.

**Expected frequency of correction runs:** If the initial parameter grid is sized
from historical climate data, out-of-range events should be rare — a few times per
year for extreme events (El Niño swells, hurricane remnants, anomalous storm tracks).
Each correction run adds the new condition permanently, so the LUT converges toward
complete coverage of the site's climate over the first year of operation.

---

## 9. Open questions for ADR-110

1. Does L2's depth range stay above the breaking zone for typical conditions?
2. If L2/L3/L4 need separate nearshore treatment: WTM vs. SnapWave vs. keep SWAN?
3. Does diffraction (SWAN L3/L4 feature) rule out SnapWave for those grids?
4. What spectral resolution does the LUT need? (Must match reconstruction axes, or
   can it be coarser for the transfer computation?)
5. How does the LUT lifecycle hook into the existing geometry-change detection?
6. What accuracy tolerance is acceptable for LUT output vs. full model output?
   (Defines the validation acceptance criteria in Phase V)
7. What is the actual precomputation cost on our hardware? (Requires a prototype
   measurement, not an estimate)
8. For Great Lakes installations with long fetches (100+ km), is the single-point
   parametric wind-sea formula sufficient, or does a multi-point approach provide
   materially better accuracy? (Requires Great Lakes buoy validation)

---

## 10. References

- Battjes, J.A. and Janssen, J.P.F.M. (1978). "Energy loss and set-up due to breaking in random waves."
- Bianco and Lavagnini (2024). "Efficient computation of wave transformation matrices to support coastal management." *Estuarine, Coastal and Shelf Science.*
- Crosby, S.C. et al. (2017). "Assimilating Global Wave Model Predictions and Deep-Water Wave Observations in Nearshore Swell Predictions." *J. Atmos. Ocean. Tech.* 34:1823–1836.
- Crosby, S.C. et al. (2019). "Regional Swell Transformation by Backward Ray Tracing and SWAN." *J. Atmos. Ocean. Tech.* 36(2).
- Echevarria et al. (2025). "Hybrid Surf Zone Downscaling." *JGR: Machine Learning and Computation.*
- O'Reilly, W.C. and Guza, R.T. (1993). "A comparison of two spectral wave models in the Southern California Bight." *Coastal Engineering* 19:263–282.
- O'Reilly, W.C. et al. (2016). "The California Coastal Wave Monitoring and Prediction System." *Coastal Engineering* 116:118–132.
- Roelvink, D. et al. (2025). "SnapWave: an efficient spectral wave model for nearshore and coastal applications." *Geoscientific Model Development* 18:9469.
- Siegelman, M. et al. (2025). "Spectral Refraction Modeling of Waves Around the Steep Reef at Palau." *J. Geophys. Res.: Oceans.*
- Thornton, E.B. and Guza, R.T. (1983). "Transformation of wave height distribution."
- WaveRay documentation: oceanum.github.io/waveray, github.com/oceanum/waveray
- CDIP MOP documentation: cdip.ucsd.edu/documents/index/product_docs/mops/
- CDIP wave models: cdip.ucsd.edu/m/documents/models.html
- Dutch Coast WTM: ecoshape.org/en/tools/nearshore-wave-transformation-table-dutch-coast/
- SnapWave source: github.com/Deltares/SFINCS (SnapWave module)
- NOAA NWPS: emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/nwps.php
- Dietrich et al. (2021). "Parallel computing efficiency of SWAN." *GMD* 14:4241.
- WW3 OpenACC GPU port: Abdolali et al. (2023). *GMD* 16:1445.
- WAM6-GPU: Wedi et al. (2024). *GMD* 17:6123.
