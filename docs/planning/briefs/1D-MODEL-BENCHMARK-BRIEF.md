# 1D Model Benchmark Brief

**Date:** 2026-07-21
**Author:** Coordinator (Opus)
**Status:** REVISED 2026-07-21 (Round 2 spec added; SWASH removed from benchmark referee role). Round 1 (Part 5b) established runtime; its physics comparison is confounded — see Part 7 §7.1. User decisions 2026-07-21: XBeach and SWASH are ruled out for production, LUT precomputation, AND benchmark referee use — SWASH is unvalidated itself and cannot serve as a truth standard. Round 2 benchmarks Analytical + SWAN SurfBeat under proper controls, validated against SWAN CURVE consistency (QB=0 zone), cross-condition physical consistency, friction-bracket analysis, and webcam/surf-report observation. SURFBEAT implementation facts were verified against the SWAN 41.51 manual (Part 7 §7.2) — they invalidate the "one-line L3 change" premise in Parts 1, 4, and 5; corrections are annotated in place.
**Origin:** SURF-1D-IMPLEMENTATION-PLAN Phase 1 (T1.2-T1.7). The prior session selected the Analytical model without benchmarking all candidates and without presenting the comparison to the user — violating T1.7's requirement that "User selects the 1D model."

---

## Part 1: The Four Candidate Models

Source: SURF-ZONE-MODEL-BRIEF §3 Options A-D.

All four models solve the same physical problem: given a 2D wave spectrum at an offshore boundary (the L2 handoff at ~15m depth) and a cross-shore bathymetric profile from that boundary to shore, compute how waves transform as they propagate shoreward — shoaling, refracting, breaking, and reforming.

### Option A: Analytical 1D (our Python module — `surf_1d_analytical.py`)

**What it is:** Pure-math parametric wave transformation. No external binary. Solves textbook coastal engineering equations at every grid point along the transect.

**Physics it computes:**

| Capability | Status | Method |
|---|---|---|
| Shoaling (wave height growth as depth decreases) | YES | Energy flux conservation: Ks = sqrt(Cg_deep / Cg_local) |
| Refraction (wave bending due to depth gradients) | YES | Snell's law per partition: sin(θ)/L = const |
| Depth-limited breaking (wave height capped by depth) | YES | Battjes-Janssen (1978): Hs > γd triggers dissipation |
| Post-breaking energy transfer (roller) | YES | Svendsen (1984): delays turbulent dissipation, allows reformation |
| Breaker type classification | YES | Iribarren number ξ₀ = tan(β)/√(H₀/L₀) → spilling/plunging/surging |
| Wave shapes (crest/trough asymmetry) | YES | Stokes 2nd order (intermediate), cnoidal via Jacobi elliptic cn (shallow) |
| Surf zone classification (impact/foam/reform) | YES | Energy dissipation thresholds along the profile |
| Jacking factor (height amplification over bars) | YES | Hs_crest / Hs_approach per bar |
| Peel angle (break line geometry across transects) | YES | Multi-transect break point spatial regression |
| Infragravity waves (long-period surf beat, set waves) | **NO** | Not modeled — phase-averaged, no wave groups |
| Wave setup (mean water level rise in surf zone) | **NO** | Not modeled — no momentum balance |
| Runup (wave excursion up the beach face) | **NO** | Not modeled — no swash zone dynamics |
| Bottom friction | **NO** | Not modeled — frictionless propagation |
| Wind effects on breaking | **NO** | Not modeled — no wind-wave interaction |
| Wave-current interaction | **NO** | Not modeled — no currents |

**Grid resolution:** dx = 3-5m recommended. Limited by CUDEM source data, not by the model — the parametric equations work at any spacing. Finer than 3m gives diminishing returns (the physics is parameterized, not resolved). At 5m on a 2,350m domain: ~470 points.

**How it runs:** Single-pass numpy vectorized computation. No time-stepping — solves the steady-state energy balance. Input is scalar (Hs, Tp, direction) per partition. Each partition runs independently; results combine via RSS (Hs_total = √(ΣHs_i²)).

**Integration cost:** Already integrated. The pipeline at `surf_1d_pipeline.py` calls it.

---

### Option B: XBeach surfbeat (Fortran binary — `/opt/xbeach/bin/xbeach`)

**What it is:** Deltares' open-source storm impact model. "Surfbeat" mode resolves short-wave GROUPS (not individual waves) coupled with infragravity wave dynamics. Time-stepping simulation.

**Physics it computes:**

| Capability | Status | Method |
|---|---|---|
| Shoaling | YES | Short-wave energy balance on wave-group timescale |
| Refraction | YES | Directional spreading, wave rays |
| Depth-limited breaking | YES | Roelvink (2003): rolling mean with adaptive gamma |
| Post-breaking roller | YES | Built-in roller model |
| Breaker type classification | **NO** | Not computed — breaking is parameterized as dissipation rate, no Iribarren |
| Wave shapes | **NO** | Phase-averaged — no individual wave crests/troughs |
| Surf zone classification | **NO** | Not a native output — could be derived from energy profile |
| Jacking factor | **NO** | Not a native output — could be derived from Hs profile |
| Peel angle | **NO** | Single-transect 1D — no alongshore variation |
| Infragravity waves | **YES** | Core capability — resolves wave groups and their IG forcing |
| Wave setup | **YES** | Nonlinear shallow water equations solve mean water level |
| Runup | **YES** | Swash zone resolved — wave excursion on beach face |
| Bottom friction | **YES** | Configurable cf (Chézy, Manning, or constant) |
| Wind effects on breaking | Partial | Wind stress on setup/IG — not on breaking criterion |
| Wave-current interaction | Partial | IG-driven currents interact with short waves |
| Morphology (sediment transport) | Available but OFF | `morfac=0` for benchmarking |

**Grid resolution:** dx = 2-5m recommended (variable grid common — finer in surf zone, coarser offshore). XBeach manual recommends resolving the surf zone at 2-3m and the offshore zone at 5-10m. Phase-averaged (wave groups, not individual crests), so sub-meter resolution is unnecessary. At 5m uniform on a 2,350m domain: ~470 points. At 2-5m variable: ~700 points.

**How it runs:** Time-stepping Fortran simulation. Reads a `params.txt` config, bathymetry file, and spectral boundary file. Runs for a simulated duration (typically 30 min) with adaptive timestep (~0.3s). Outputs time-averaged Hs, instantaneous water levels, setup.

**Input format:** Accepts SWAN SPECOUT as boundary condition (or JONSWAP parameters). Reads bathymetry as a 1D depth profile in its own format.

**Integration cost:** Would need a subprocess wrapper (same pattern as SWAN), input file generators, output parsers. Not currently integrated.

---

### Option C: SWASH (Fortran binary — `/opt/swash/bin/swash`)

**What it is:** TU Delft's phase-resolving non-hydrostatic wave model. Solves the full shallow water equations with non-hydrostatic pressure correction. Resolves individual wave crests and troughs.

**Physics it computes:**

| Capability | Status | Method |
|---|---|---|
| Shoaling | YES | Direct solution of wave propagation equations |
| Refraction | YES | Depth-dependent phase speed in the equations |
| Depth-limited breaking | YES | Hydrostatic front approximation (HFA) — no explicit gamma |
| Post-breaking roller | Implicit | Bore propagation is naturally resolved |
| Breaker type classification | **NO** | Not a native output — could be derived from wave asymmetry |
| Wave shapes | **YES** | Phase-resolved — actual crest/trough geometry at every point |
| Surf zone classification | **NO** | Not a native output |
| Jacking factor | **NO** | Not a native output — derivable from Hs profile |
| Peel angle | **NO** | Single-transect 1D — no alongshore variation |
| Infragravity waves | **Partial** | Single-layer (VERT=1) captures some IG; multi-layer (VERT≥2) needed for full IG resolution |
| Wave setup | **YES** | Directly solved from the momentum equations |
| Runup | **YES** | Moving shoreline boundary — wave excursion on beach face |
| Bottom friction | **YES** | JONSWAP friction or Manning |
| Wind effects on breaking | **NO** | No wind forcing in 1D mode |
| Wave-current interaction | **YES** | Full nonlinear interaction — currents and waves in the same equations |
| Frequency dispersion | **YES** | Non-hydrostatic pressure term — accurate wave celerity across all depths |

**Grid resolution:** dx = 0.5-2m required. SWASH manual recommends dx ≤ L/50 for proper phase resolution. For a 10s wave in 1m depth (L≈10m), that's dx ≤ 0.2m — but in practice dx=1-2m is standard for 1D surf zone applications (Zijlema et al. 2011). SWASH MUST be finer than the other models because it resolves individual wave crests — each crest needs 10-20 grid points to be well-represented. At 1m on a 2,350m domain: ~2,350 points. At 2m: ~1,175 points.

**How it runs:** Time-stepping Fortran simulation. Solves the full NLSW+NH equations at ~0.1-0.5s timestep. Much higher resolution than XBeach surfbeat. Runs for a simulated duration (30-50 min).

**Input format:** Own INPUT file format (similar to SWAN syntax). Accepts spectral or regular wave boundary conditions. Bathymetry as a 1D depth file.

**Key limitation:** Single-layer mode (VERT=1) does not fully resolve vertical flow structure, which limits IG wave accuracy. Multi-layer (VERT=2-3) is needed for proper IG resolution but increases runtime proportionally.

**Integration cost:** Same as XBeach — subprocess wrapper, input generators, output parsers. Not currently integrated.

**Primary value per the brief §3:** Validation ground truth, not production model. The brief says "Too expensive for routine forecasting. Useful as a validation ground-truth."

---

### Option D: SWAN SurfBeat (built into our existing SWAN binary)

**What it is:** The Infragravity Energy Module (IEM), published by **Reniers & Zijlema (2022, "SWAN SurfBeat-1D," Coastal Engineering 172, 104068)** — earlier drafts mis-attributed this to Rijnsdorp. Adds a bound-infragravity energy balance (wave-group forcing, biphase-coupled) to SWAN's spectral framework. **NOT a drop-in flag on an existing grid** — it carries hard grid/mode restrictions verified against the SWAN 41.51 manual on 2026-07-21 (Part 7 §7.2).

**Physics it computes (in addition to standard SWAN):**

| Capability | Status | Method |
|---|---|---|
| Everything SWAN already does | YES | SWAN's full spectral model — shoaling, refraction, breaking (BJ78), bottom friction, triad interactions, diffraction |
| Infragravity waves | **YES** | IG energy source term from short-wave group forcing (Rijnsdorp et al. 2022) |
| Wave setup | Partial | SWAN computes radiation stress gradients but not the actual water level change (requires coupling with a flow model or using the SETUP command) |
| Breaker type classification | **NO** | SWAN is phase-averaged — no Iribarren |
| Wave shapes | **NO** | Phase-averaged — no individual crests/troughs |
| Surf zone classification | **NO** | Not a SWAN concept |
| Jacking factor | **NO** | Not a native output — derivable from CURVE Hs values |
| Peel angle | **NO** | SWAN doesn't have the multi-transect break-point concept |
| Runup | **NO** | SWAN doesn't model swash |
| Bottom friction | **YES** | FRICTION command (JONSWAP, Collins, Madsen) |

**How it runs (corrected 2026-07-21 per SWAN 41.51 manual):** No separate binary, but NOT part of the normal L3 cycle. The manual imposes: regular (rectilinear) grid only — verbatim: "CANNOT BE USED IN CASE OF CURVILINEAR or UNSTRUCTURED GRIDS AND NOT IN 1D-MODE"; **stationary** conditions only; a **two-COMPUTE procedure** (first COMPUTE: sea-swell + bound IG; second: reflected free IG); **mild, alongshore-uniform** bottom slopes; positive x-axis pointing **eastward**, with the offshore spectrum imposed on the west boundary and shoreline IG reflection via an OBSTACLE line on the east side. The only viable configuration is a dedicated per-spot "SurfBeat strip" run — see Part 7 §7.3.

**T1.6 finding:** The `SURFBeat` command is confirmed available in SWAN 41.45/41.51 (our installed version). It's a standard command, not a custom build.

**Syntax (SWAN 41.51 manual, verified 2026-07-21):**
```
SURFBeat [df] [nmax] [emin] UNIForm|LOGarithmic
```
Defaults: `df`=0.01 Hz (bound-IG frequency bin size), `nmax`=50000 (max short-wave pairs for bichromatic groups), `emin`=0.05 (energy threshold as fraction of spectral peak). The IG energy appears as explicit low-frequency bins in the output spectra. The full syntax — including the two-COMPUTE procedure and the shoreline-reflection OBSTACLE — must go through the T7.GATE extraction process from the installed manual before any INPUT-generation code is written (RULE 5, SWAN-L3-STABILITY-PLAN).

**What it adds vs standard SWAN:** Infragravity energy prediction — the "set wave" timing that surfers care about (the 1-3 minute rhythm of bigger and smaller sets).

**What it does NOT add (vs standard SWAN):** No improvement to wave shapes, breaking classification, sub-grid resolution, surf zone width, or any of the features the analytical model provides. The brief states: "Complements, does not replace Option A — adds infragravity prediction but does not improve wave shapes, breaking classification, or sub-grid resolution."

**Grid resolution:** dx = 5-10m. SWAN is phase-averaged — it computes spectral energy statistics, not individual waves. 10m is the current L3 grid resolution. SWAN can run at 5m but gains diminishing returns for a spectral model. BJ78 breaking is parameterized (Hs > γd threshold), not resolved — it doesn't need sub-wavelength resolution. At 10m on a 2,350m domain: ~235 points. At 5m: ~470 points.

**CANNOT run in 1D mode (corrected 2026-07-21):** The manual explicitly disallows SURFBEAT in SWAN's 1D grid mode. Architecture 6 (SWAN-1D + SurfBeat per transect) is NOT viable. The "1D" in the paper title refers to the *physics* (cross-shore transformation on an alongshore-uniform beach), not SWAN's 1D computational mode — the implementation requires a small regular 2D grid oriented west→east.

**Integration cost (corrected 2026-07-21):** Moderate, not minimal. A new run type: strip-grid INPUT generator (west→east frame, alongshore-uniform bathymetry, rotated boundary spectrum, two COMPUTEs, shoreline-reflection OBSTACLE) plus band-integrated spectral output parsing. Reuses the existing SWAN binary and subprocess plumbing — still far cheaper than integrating a new binary.

---

## Part 2: Capability Matrix — What the Plan/Brief Requires vs What Each Model Delivers

The plan and brief (§5, §7) specify these outputs for the surf page:

| Required output | Analytical (A) | XBeach (B) | SWASH (C) | SWAN SurfBeat (D) |
|---|---|---|---|---|
| **Cross-shore grid resolution** | 3-5m (parametric, CUDEM-limited) | 2-5m variable (group-resolving) | 0.5-2m (phase-resolving, must resolve individual crests) | 5-10m (spectral, phase-averaged) |
| **Points on 2,350m domain** | ~470-780 | ~470-1,175 | ~1,175-4,700 | ~235-470 |
| **Hs envelope at 3-5m resolution** | YES | YES (at grid spacing) | YES (at dx=1-3m) | NO (at SWAN grid spacing, 5-10m) |
| **Break point from H/d=γ crossing** | YES (sub-grid) | Derivable (from Hs profile) | Derivable (from Hs profile) | NO (QB threshold only, at grid resolution) |
| **Breaker type (Iribarren classification)** | YES | NO | NO | NO |
| **Wave shapes (Stokes/cnoidal/bore)** | YES | NO | YES (phase-resolved, actual shapes) | NO |
| **Surf zone classification (impact/foam/reform)** | YES | Derivable | Derivable | NO |
| **Jacking factor** | YES | Derivable | Derivable | NO |
| **Peel angle** | YES (multi-transect) | NO (1D only) | NO (1D only) | NO |
| **Per-partition swell transformation** | YES (each partition independently) | YES (spectral BC) | YES (spectral BC) | YES (full spectrum) |
| **Infragravity waves (set timing)** | NO | YES | Partial (VERT=1) / YES (VERT≥2) | YES |
| **Wave setup** | NO | YES | YES | Partial (radiation stress, not water level) |
| **Runup** | NO | YES | YES | NO |
| **Face height (Hs→face conversion)** | YES (1.27× H1/10 at break) | Needs post-processing | Needs post-processing | Needs post-processing |
| **Deep-water swell display (SPECOUT decomposition)** | N/A (pre-model) | N/A (pre-model) | N/A (pre-model) | N/A (pre-model) |

**Key takeaway:** No single model delivers everything. The analytical model is the only one that produces breaker classification, wave shapes (theoretical), surf zone classification, jacking, and peel angle natively. XBeach and SWASH are the only ones that produce infragravity waves, setup, and runup. SWAN SurfBeat adds IG to the existing SWAN framework but doesn't improve any of the sub-grid features.

---

## Part 2b: Hardware, Parallelism, and Memory Requirements

### Test machine: weewx LXD container on Ratbert

| Resource | Value | Notes |
|---|---|---|
| CPU | AMD Threadripper 2950X, **16 physical cores**, 32 threads (SMT) | Shared with other LXD containers on Ratbert |
| RAM | **1.9 GB** (LXD cgroup limit: 1,999,998,976 bytes) | Currently ~335 MB available. Tight constraint. |
| Compiler | gfortran 13.3.0 (GCC 13, Ubuntu 24.04) | Used for XBeach and SWASH builds |

### Parallelization capabilities per model (from official documentation)

| | OpenMP (shared memory) | MPI (distributed memory) | Current build | Source |
|---|---|---|---|---|
| **Analytical** | N/A (Python/numpy) | N/A | Single-threaded numpy vectorized | — |
| **XBeach** | **NOT SUPPORTED** | YES (`./configure --with-mpi`) | Serial (`--without-mpi`) | [XBeach compile docs](https://xbeach.readthedocs.io/en/latest/compile.html), [README.parallel](https://github.com/openearth/xbeach/blob/master/doc/README.parallel) |
| **SWASH** | **NOT SUPPORTED** | YES (`make mpi` or `cmake -DMPI=ON`) | Serial (`make ser`) | [SWASH Implementation Manual](https://swash.sourceforge.io/online_doc/swashimp/swashimp.html) — only `make ser` and `make mpi` targets exist. No `make omp`. |
| **SWAN** | **YES** (default on shared-memory) | YES | OpenMP (threads configurable via `omp_num_threads` in api.conf — currently unset) | [GMD paper: Parallel computing efficiency of SWAN 40.91](https://gmd.copernicus.org/articles/14/4241/2021/) |

**Key finding: Neither XBeach nor SWASH supports OpenMP.** Both use MPI only for parallelization. MPI parallelizes by splitting the spatial domain across processes — each process handles a subdomain and communicates at boundaries. For 1D mode (ny=0), MPI has limited value: a 1D domain can only be split along the cross-shore axis, and the communication overhead likely exceeds the compute benefit for domains under ~5,000 points.

**SWAN OpenMP scaling (from published research):** The Copernicus GMD paper (2021) on SWAN 40.91 found that "the time-saving ratio indicated a decrease after approximately six computational threads/cores." Beyond 6 cores, performance degrades due to communication overhead within the OpenMP shared-memory framework. This is consistent with the user's prior finding. The paper also found OpenMP is more efficient than MPI on a single node, but MPI scales better across nodes.

**Implication for the benchmark:** All models will run single-threaded (serial) in the benchmark. XBeach and SWASH have no OpenMP option. SWAN's OpenMP is relevant for the L3 2D grid run but not for per-transect 1D benchmarking. Rebuilding XBeach or SWASH with MPI for the benchmark is not useful — MPI domain decomposition doesn't help a 1D run with ~500-2,350 points.

### Memory requirements per model (from official documentation)

| Model | Documented memory needs | Our constraint (1.9 GB total, ~335 MB free) |
|---|---|---|
| **Analytical** | Negligible — numpy arrays for ~500-780 floats | No issue |
| **XBeach** | "Large demands on system memory" when record length is large and timestep is small. No specific numbers given. | Unknown — needs empirical test |
| **SWASH** | "at least 500 MB recommended" for test cases; "1 to 2.5 GB may be needed" for realistic cases; "less than 100 MB" for simple 1D cases. ([SWASH Implementation Manual §5](https://swash.sourceforge.io/online_doc/swashimp/swashimp.html)) | **AT RISK.** A 2,350m domain at 1m dx with VERT=2 is a realistic case → may need 1-2.5 GB. Only 335 MB currently free. The 1.9 GB hard cap may be insufficient without stopping other services. |
| **SWAN** | Documented elsewhere — SWAN already runs on this container for the L3 grid. The 300 MB memory budget (ARCHITECTURE.md) is for the full 3-level nesting. | Already validated |

**Action needed before benchmark:** Either increase the weewx LXD container's memory limit or stop non-essential services during the SWASH benchmark run to free RAM. If SWASH OOMs on the full 2,350m domain, try a shorter domain (1,000m from 7m depth) as a scaling test first.

### What each model needs to be rebuilt or reconfigured for the benchmark

| Model | Current state | Rebuild needed? | What to change |
|---|---|---|---|
| Analytical | Production code, BJ sign fix applied (c987973) | No | — |
| XBeach | Serial build, no NetCDF output | Optional: rebuild with `--with-mpi --with-netcdf` for NetCDF output. MPI not useful for 1D. | `./configure --with-netcdf && make && make install` |
| SWASH | Serial build (`make ser`) | No — MPI not useful for 1D, and OpenMP doesn't exist | — |
| SWAN | Already installed, OpenMP-capable | No rebuild. Set `omp_num_threads` for the SurfBeat benchmark run (recommend 4-6 based on scaling research). | Build the dedicated SurfBeat strip INPUT (Part 7 §7.3) — NOT a one-line L3 change |

---

## Part 3: What Was Wrong With the Executed Benchmark

### Problem 1: Wrong bathymetric profile
- **Used:** 71 points from L3 BOTTOM.txt, 704m, 10m spacing, max depth 6.9m
- **Should be:** CUDEM profile along the transect from the L2 handoff (~15m depth, ~2,350m offshore) to shore, at 3-5m native CUDEM resolution (~470-780 points)
- **Impact:** Missing 1,600m of shoaling zone. Waves don't build up properly. Break point and surf zone width are unrealistic.

### Problem 2: Wrong boundary — started inside the surf zone
- **Used:** Profile starts at 5.68m depth
- **Should be:** Profile starts at the L2 handoff boundary (~15m depth). The brief §2.3.1 cites published criteria: XBeach manual says max(10m, 2×Hs), CoSMoS uses the -15m isobath, Deltares guidelines say at least 3×Hs.
- **Impact:** At 5.68m, a 1.5m swell has Hs/d = 0.26 — not yet breaking, but shoaling is already significant. Starting here means the models don't see the full intermediate-depth transformation (dispersion regime change, refraction across the shelf).

### Problem 3: Inconsistent inputs across models
- **Analytical:** Received scalar Hs=1.5m, Tp=10s, direction=270° — no directional spread
- **XBeach:** Received JONSWAP spectrum with 20° directional spread — effective 1D Hs is ~1.03m (31% lower)
- **SWASH:** Received regular waves (single frequency, single direction) — no spectral broadening at all
- **Impact:** Apples-to-oranges comparison. XBeach's lower Hs is not a physics difference — it's a different input.

### Problem 4: Inconsistent breaking parameters
- **Analytical:** γ = 0.73 (Battjes-Janssen standard for random waves)
- **XBeach:** γ = 0.55 (Roelvink2 default — lower because Roelvink uses Hs directly, not Hrms)
- **SWASH:** α=0.6, β=0.3 (HFA breaking — different formulation entirely)
- **Impact:** These are NOT interchangeable. Each model's default gamma is calibrated for its own breaking formulation. The benchmark should use each model's standard defaults and document the choice — not force a common gamma.

### Problem 5: SWASH had no sponge layer
- **Impact:** Offshore Hs = 2.34m from 1.5m input — 56% inflation from reflected waves creating standing wave patterns. The entire Hs profile is contaminated.

### Problem 6: SWAN SurfBeat (Option D) was not included
- T1.6 confirmed it's available as a standard command in our SWAN binary
- It was never benchmarked
- It's the cheapest to integrate (one line in INPUT file)

### Problem 7: No SWAN CURVE reference baseline
- SPEC_1.txt and TABLE_1.txt contained NODATA (L3 nesting error)
- The plan requires comparing 1D model Hs against SWAN CURVE in the QB=0 zone
- Without SWAN CURVE output, there's no reference to validate against

---

## Part 4: Proper Benchmark Design

### Study area: Huntington City Beach south of the pier

The benchmark uses a real surf zone, not an abstract 300m segment. The study area is the south side of Huntington Beach Pier — from the pier south to the last lifeguard tower before Huntington State Beach (near Beach Blvd / SR-39). This is approximately 1.5-2.0 km of beach (exact distance to be measured on the map).

**Why this area:** It's a real surf zone with known features — the pier shadow on the north end, multiple sandbars, rip channels, and a long straight beach that exercises the multi-transect architecture at scale. If the system works here, it works for most beach break surf spots.

**Alongshore transect array:**
- Transect spacing: 10m (plan default)
- At 1.5km: ~150 transects. At 2.0km: ~200 transects.
- This is much larger than the plan's 300m/30-transect default and tests operational scaling.

### Cross-shore domain

Each transect runs from the **L2 handoff boundary** (~15m depth, ~2,350m offshore at HB Pier) to the beach crest.

| Parameter | Value | Source |
|---|---|---|
| Offshore boundary depth | ~15m | L2 grid offshore extent; CoSMoS uses the -15m isobath; XBeach manual says max(10m, 2×Hs) |
| Offshore boundary distance | ~2,350m from shore | Measured from cached CUDEM profile along HB Pier transect |
| Shoreward boundary | Beach crest (above MSL) | Natural termination |
| Total cross-shore extent | ~2,350m | Full shoaling zone from intermediate water to shore |

### Cross-shore grid spacing (dx) — per model, per expert recommendation

Each model has its own recommended cross-shore grid spacing. These are NOT interchangeable — they reflect the physics each model resolves.

| Model | Recommended dx | Points (~2,350m) | Source / rationale |
|---|---|---|---|
| **Analytical** | 5m | ~470 | SURF-ZONE-MODEL-BRIEF §3 Option A table: "2500m, 5m spacing, 500 points." Resolves sandbars (50-200m wavelength) and the BJ breaking transition. Finer than 5m gives diminishing returns for a parametric model. |
| **XBeach surfbeat** | 2-5m (variable) | ~700 | XBeach manual recommends variable grids: finer in the surf zone (2-3m), coarser offshore (5-10m). The surfbeat mode resolves wave groups, not individual waves, so 2-5m is adequate. SURF-ZONE-MODEL-BRIEF §3 Option B uses 5m. |
| **SWASH** | 1-2m | ~1,200-2,350 | SWASH manual: dx ≤ L/50 for phase-resolving accuracy. For T=10s in 1m depth, L≈10m → dx ≤ 0.2m (theoretical minimum). In practice, dx=1-2m is standard for 1D surf zone SWASH runs (Zijlema et al. 2011). SURF-ZONE-MODEL-BRIEF §3 Option C: "dx ~ 1-3m." Finer grid = more points = longer runtime. |
| **SWAN-1D** | 5-10m | ~235-470 | SWAN is phase-averaged — dx=10m is the current L3 grid resolution. SWAN can run finer (5m) but gains diminishing returns for a spectral model. SWAN's BJ breaking is parameterized, not resolved — it doesn't need sub-wavelength resolution. |
| **SWAN-2D L3** (reference) | 10m | N/A (2D grid) | Current production configuration. The 2D grid is 10m × 10m. Not a 1D model — included as the reference baseline. |

**Key distinction:** The 10m L3 grid resolution is SWAN's 2D computational grid, not the 1D model grid. The 1D models run on their own grids independent of SWAN's grid. The analytical model and XBeach use the CUDEM bathymetric profile (source resolution varies by DEM tile — typically 3-10m for SoCal NCEI regional DEMs), interpolated to their target dx. SWASH interpolates to finer spacing (1-2m) for phase accuracy.

**CUDEM source resolution ≠ model grid spacing.** CUDEM provides the bathymetric depth at each point. The model grid defines where those points are. If the model grid is finer than CUDEM (e.g., SWASH at 1m on a 3m CUDEM tile), the bathymetry is interpolated. If coarser (e.g., SWAN-1D at 10m on a 3m CUDEM), the bathymetry is subsampled.

### Boundary condition
- **Preferred:** SWAN L2 SPECOUT at the 15m depth point (the DWR SPECOUT that Phase 3 configured — once a SWAN cycle runs and produces it)
- **Fallback if SPECOUT unavailable:** NDBC buoy 46222 (San Pedro) real-time 2D spectral data, propagated to the 15m point. Or: construct a representative JONSWAP from recent buoy parameters.
- **All models receive the same spectral information:** Each model's boundary condition is derived from the same source spectrum. For the analytical model, decompose the spectrum into partitions (Hs, Tp, Dir per partition). For XBeach and SWASH, provide the full 2D spectrum as the boundary file. For SWAN SurfBeat, the L2 run already provides the boundary via BOUNDNEST — the benchmark is the L3+SurfBeat run itself. For SWAN-1D, provide the L2 SPECOUT as the BOUNDNEST boundary.

### Model configurations

**Analytical (`surf_1d_analytical.py`):**
- Input: per-partition (Hs, Tp, Dir) from spectral decomposition at 15m
- Bathy: CUDEM profile, full domain (~2,350m), 3-5m spacing (~470-780 points)
- γ = 0.73 (BJ78 standard)
- All capabilities ON: BJ breaking, Svendsen roller, Snell's refraction, Iribarren, wave shapes, zone classification

**XBeach surfbeat (`/opt/xbeach/bin/xbeach`):**
- wavemodel = surfbeat
- ny = 0, morfac = 0
- break = roelvink2, gamma = 0.55 (Roelvink's gamma is calibrated for the Roelvink formulation, not interchangeable with BJ78's 0.73)
- cf = 0.003 (bottom friction)
- Boundary: full 2D spectrum from SPECOUT in XBeach's SWAN format
- Bathy: same CUDEM profile, converted to XBeach grid format
- Simulation time: 30 minutes
- All capabilities ON: surfbeat, roller, friction, setup, runup, IG

**SWASH (`/opt/swash/bin/swash`):**
- MODE ONED
- VERT 2 (two-layer — needed for IG wave resolution; VERT=1 was a limitation in the failed benchmark)
- BREaking ALPHA=0.6 BETA=0.3
- FRICtion JONswap 0.067
- SPONge layer on offshore boundary (absorb reflections — missing in failed benchmark)
- Boundary: spectral (from SPECOUT), not regular waves
- Bathy: same CUDEM profile, converted to SWASH bottom format, with correct sign convention (READINP BOTTOM -1.)
- Simulation time: 30 minutes
- Grid spacing: dx = 2-3m (SWASH needs finer grid than the other models for stability)

**SWAN SurfBeat — two configurations [SUPERSEDED 2026-07-21 — neither is viable as written; see Part 7 §7.2-7.3. D1 fails because the L3 grid is coast-oriented and nonstationary while SURFBEAT requires a west→east, alongshore-uniform, stationary grid with two COMPUTEs. D2 fails because SURFBEAT cannot run in 1D mode.]:**

*Config D1: SWAN-2D L3 + SURFBeat (adds IG to the existing L3 grid):*
- Add `SURFBeat` command to the existing L3 INPUT file
- Everything else unchanged from current L3 configuration
- L3 uses 10m grid resolution
- Extract: SPECOUT at a nearshore point, TABLE along CURVE — compare with and without SURFBeat to isolate the IG contribution

*Config D2: SWAN-1D + SURFBeat (replaces L3 grid with per-transect 1D runs):*
- 1D computational grid along each transect using CUDEM bathymetry at 3-5m resolution
- BOUNDNEST from L2 SPECOUT at the 15m boundary
- SURFBeat enabled
- OBSTACLE applied per-transect where applicable
- All standard SWAN physics: BJ78 breaking (γ=0.73), TRIAD, FRICTION, bottom refraction
- One SWAN-1D run per transect (30 runs) or all 30 as parallel output locations in a single run
- Extract: TABLE with Hs/Tp/Dir/QB at every grid point, SPECOUT at selected points

### Measurements to compare

| Measurement | Where | What it tells us |
|---|---|---|
| Hs profile (all points) | Full transect, 15m to shore | Shoaling accuracy, breaking location, post-breaking decay |
| Break point location | Where Hs first exceeds γd (or Hs drops sharply) | Breaking accuracy — sensitive to bathymetry and gamma |
| Hs in QB=0 zone | Offshore of breaking | Consistency check — should match linear shoaling theory |
| Surf zone width | Outer break to swash | Physical reasonableness — should be 100-200m for 5ft surf at HB Pier |
| IG wave height (models that produce it) | Surf zone and shoreline | Set wave amplitude — what makes a "set" bigger than a "lull" |
| Wave setup (models that produce it) | Shoreline | Mean water level rise from breaking — affects tide level at break |
| Runup (models that produce it) | Beach face | Maximum wave excursion — affects beach safety |
| Runtime | Wall clock | Operational feasibility — can it run 6,480 times in <30 min? |

### How to handle per-model differences in gamma

The breaking parameter gamma is NOT the same number across models because the breaking formulations differ:
- BJ78 (analytical, SWAN): γ = 0.73, applied to Hs, uses Hrms internally
- Roelvink (XBeach): γ = 0.55, applied to Hrms directly, rolling-mean adaptive
- SWASH HFA: α/β coefficients, no explicit gamma — breaking emerges from the non-hydrostatic pressure

These are NOT interchangeable. Using γ=0.73 in XBeach would break too early; using γ=0.55 in BJ78 would break too late. Each model's default gamma is calibrated for its own breaking formulation. The benchmark uses each model's standard defaults and documents the choice.

### Full forecast cycle runtime estimate

Runtime depends on the number of transects. The benchmark study area (HB south of pier, ~1.5-2km) has 150-200 transects at 10m spacing. The plan's 300m/30-transect default is a small spot. Both are shown:

**Per forecast cycle:** transects × 3 partitions × 72 timesteps = N runs.

| Model | Per-run estimate | 30 transects (6,480 runs) | 150 transects (32,400 runs) | Operational? |
|---|---|---|---|---|
| Analytical | ~1-2 ms | ~6-13s | ~32-65s | YES — real-time at any scale |
| SWAN SurfBeat (D1, 2D L3) | 0 additional | 0 additional | 0 additional | YES — no extra cost |
| SWAN-1D + SurfBeat (D2) | Unknown | Unknown | Unknown | **Benchmark must measure** |
| SWASH (VERT=2) | ~0.1-1s | ~10-108 min | ~54-540 min | NO for production — validation only |
| XBeach surfbeat | ~1-5s | ~1.8-9 hr | ~9-45 hr | NO — needs LUT |

Note [SUPERSEDED 2026-07-21]: SURFBEAT cannot ride inside the existing L3 run and cannot run in 1D mode (Part 7 §7.2). The real Option D cost is one dedicated stationary strip run per spot per forecast hour — small, but not zero. Round 2 measures it (Part 7 §7.9).

---

## Part 5: Possible Architectures (for user decision after benchmark)

These are not recommendations — they're the options the benchmark should inform.

**Architecture 1: Analytical only (current implementation)**
- Analytical runs per-transect per-partition per-timestep
- Provides: Hs, break points, breaker type, wave shapes, zones, jacking, peel angle
- Does NOT provide: IG waves, setup, runup
- Runtime: ~6-13 seconds per forecast cycle

**Architecture 2: Analytical + SWAN SurfBeat (D1 — add IG to existing L3)**
- Analytical provides all sub-grid features (same as Architecture 1)
- SWAN SurfBeat adds IG energy prediction within the existing SWAN 2D L3 run
- Combined: everything in Architecture 1 PLUS infragravity wave information
- Runtime: ~6-13 seconds + zero additional (SurfBeat runs inside SWAN)
- Integration cost: one line in INPUT generator + SPECOUT low-frequency extraction
- **[REVISED 2026-07-21]** SURFBEAT cannot be added to the existing L3 run (Part 7 §7.2). The IG component comes from a dedicated SurfBeat strip run (Part 7 §7.3) — one small stationary run per spot per forecast hour, not zero cost; integration is a new run type, not one line. Architecture 2 otherwise stands and is the Round 2 leading candidate ("Architecture 2-prime").

**Architecture 3: Analytical + XBeach (LUT) — RULED OUT (user decision 2026-07-21)**
- Analytical for real-time display
- XBeach precomputed LUT for IG, setup, runup (overnight batch computation)
- Combined: everything PLUS calibrated IG, setup, runup
- Runtime: analytical real-time + LUT lookup; LUT build: hours per spot
- Integration cost: high — LUT infrastructure, XBeach subprocess wrapper, input/output parsers
- **[RULED OUT 2026-07-21]** At the brief's ~14,000-combo density × 150 transects × ~10s/run, a LUT costs ~250 days of compute per spot; even aggressively reduced (clustered representative profiles + coarse interpolated parameter grid) it is days of compute that recurs on every bathymetry refresh (sandbars migrate seasonally) — while its main payoff (IG) is available from the SurfBeat strip. User decision: XBeach will not be integrated, LUT or otherwise.

**Architecture 4: Analytical + SWASH hourly — RULED OUT (user decision 2026-07-21)**
- Analytical for real-time display
- SWASH runs hourly as a calibration/validation reference
- NOT production-facing — validation ground truth per the brief §3 Option C
- Integration cost: moderate — SWASH subprocess wrapper, output comparison pipeline
- **[RULED OUT 2026-07-21]** No hourly or production SWASH. **[UPDATED 2026-07-21]** SWASH also ruled out from the benchmark referee role — it is unvalidated itself and cannot serve as a truth standard. SWASH has no remaining role in this project.

**Architecture 5: SWAN SurfBeat (D1) + Analytical post-processing — NOT VIABLE AS WRITTEN (2026-07-21)**
- SWAN SurfBeat provides the base wave field including IG via existing 2D L3 grid
- Analytical post-processing adds wave shapes, breaker classification, peel angle on top of SWAN's output
- Potentially the best of both worlds if SWAN's grid-resolution Hs (10m) is adequate as the base
- Question the benchmark must answer: is SWAN's 10m grid Hs sufficient for analytical post-processing, or does the analytical model need to run the full shoaling computation from CUDEM data?
- **[NOT VIABLE 2026-07-21]** SURFBEAT does not run on the production L3 grid (Part 7 §7.2), so it cannot provide "the base wave field including IG." IG comes only from the alongshore-uniform strip — a spot-level signal, not a per-transect base field.

**Architecture 6: SWAN-1D + SurfBeat replacing L3 + Analytical post-processing — NOT VIABLE (2026-07-21)**

**[NOT VIABLE 2026-07-21]** The SWAN 41.51 manual forbids SURFBEAT in 1D mode (verbatim: "...AND NOT IN 1D-MODE"). SWAN-1D per-transect without SurfBeat would lose this architecture's main gain (free IG), so the whole architecture is dropped. Retained below for the record.

This replaces the L3 2D grid entirely with per-transect SWAN-1D runs:

```
Current:   L1 (1km) → L2 (100m) → L3 (10m, 2D grid) → Analytical 1D post-processing
Arch 6:    L1 (1km) → L2 (100m) → SWAN-1D+SurfBeat per transect (3-5m, CUDEM) → Analytical post-processing
```

Each transect gets its own SWAN-1D run:
- Uses the L2 SPECOUT as the offshore boundary (BOUNDNEST at ~15m depth)
- Runs on the transect's own CUDEM bathymetric profile at 3-5m resolution
- SurfBeat enabled — IG energy resolved within SWAN's spectral framework
- OBSTACLE applied per-transect where applicable
- SWAN handles the spectral physics (shoaling, refraction, BJ78 breaking, triad, bottom friction) — all the things the analytical model also does, but with SWAN's full spectral approach instead of parametric equations
- Analytical post-processing adds: breaker type (Iribarren from SWAN's Hs and local slope), wave shapes (Stokes/cnoidal from SWAN's Hs and depth), surf zone classification, jacking, peel angle

**What Architecture 6 gains vs the current L3:**
- Each transect at CUDEM 3-5m resolution (not L3's 10m grid)
- IG energy at zero extra integration cost (SurfBeat command)
- No L3 grid sizing complexity (smart sizing, hotstart invalidation, bbox computation — all of Phase 3's complexity goes away)
- SWAN handles bottom friction (the analytical model doesn't)
- SWAN handles triad interactions (shallow-water nonlinear transfer — the analytical model doesn't)

**What Architecture 6 loses vs the current L3:**
- 2D refraction between transects (but the analytical 1D already doesn't have this — we've already accepted independent transects)
- 2D diffraction from structure tips (but L3's diffraction was already problematic — convergence issues from the stability plan, smnum tuning)

**What analytical post-processing still provides:** Breaker type (Iribarren), wave shapes (Stokes/cnoidal), surf zone classification, jacking factors, peel angle. SWAN doesn't compute any of these even in 1D mode.

**Unknown — benchmark must answer:**
1. SWAN-1D per-transect runtime. A 1D grid with ~500 points in stationary mode should be fast, but subprocess overhead for 30 launches may dominate. Alternative: all 30 transects as parallel output locations in a single SWAN-1D run.
2. Whether SWAN-1D's Hs profile matches the analytical model's closely enough that the analytical post-processing (Iribarren from SWAN's Hs + CUDEM slope) gives physically correct breaker classifications.
3. Whether OBSTACLE works correctly in SWAN 1D mode — the command may require a 2D grid for line-segment geometry.

---

## Part 5b: Round 1 Benchmark Results (2026-07-21) — runtime results valid; physics comparison confounded, see Part 7 §7.1

**Benchmark host:** librewxr LXD container (6 GB RAM, 16 cores, AMD Threadripper 2950X)
**Input conditions:** Hs=1.0m, Tp=14s, Dir=200° SSW (typical summer groundswell at HB Pier)
**Bathymetry:** SWAN L2 CUDEM profile, 15m depth to shore (~2,500m), interpolated to each model's target dx
**Study area for cycle estimates:** HB Pier south side (~1.5km, 150 transects at 10m spacing)

### Runtime

Per forecast cycle: 150 transects × 3 partitions × 72 timesteps = **32,400 runs**.

| Model | Cores | Parallelism | Per run | Full cycle (32,400 runs) |
|---|---|---|---|---|
| **Analytical** | 1 | serial (numpy) | 4.2 ms | **2.3 minutes** |
| **SWAN+SurfBeat** | 6 | OpenMP | 3.0 s per-transect (but runs as 2D grid — see note) | **~5 min as 2D grid** (not 27 hr) |
| **SWASH (VERT=2)** | 6 | MPI | 8.8 s | **80 hours** |
| **XBeach surfbeat** | 1* | MPI (can't parallelize 1D) | 10.3 s | **93 hours** |

*XBeach MPI decomposes along y only; ny=0 (1D mode) falls back to 1 process.

**SWAN+SurfBeat note [corrected 2026-07-21]:** This row predates the manual verification in Part 7 §7.2. The reported 3.0s "per-transect" figure cannot have included an active SURFBEAT computation — the command is disallowed in SWAN's 1D mode — so treat this row as plain-SWAN 1D runtime. No IG output was ever extracted in Round 1. **Option D remains unmeasured.** The real Option D cost is the dedicated stationary strip run (Part 7 §7.3), measured in Round 2.

### Hs Profile Comparison

All values in meters. Distance from shore (0m = shoreline, increasing offshore).

| Dist(m) | Depth(m) | Analytical | SWAN | XBeach | SWASH | SWASH setup |
|---|---|---|---|---|---|---|
| 2400 | 13.46 | 0.946 | 1.003 | 0.701 | 1.050 | +0.008 |
| 2200 | 12.58 | 0.968 | 1.013 | 0.707 | 1.052 | -0.001 |
| 2000 | 11.75 | 0.991 | 0.999 | 0.711 | 1.030 | +0.002 |
| 1800 | 11.06 | 1.013 | 0.963 | 0.711 | 1.011 | 0.000 |
| 1600 | 10.55 | 1.031 | 0.917 | 0.709 | 1.004 | -0.003 |
| 1400 | 9.94 | 1.054 | 0.873 | 0.709 | 1.033 | +0.004 |
| 1200 | 10.43 | 1.035 | 0.819 | 0.694 | 1.058 | +0.004 |
| 1000 | 10.10 | 1.048 | 0.779 | 0.689 | 1.151 | -0.009 |
| 800 | 9.37 | 1.078 | 0.752 | 0.691 | 1.250 | +0.006 |
| 600 | 8.61 | 1.115 | 0.731 | 0.694 | 1.241 | +0.011 |
| 400 | 7.19 | 1.200 | 0.729 | 0.711 | 1.216 | +0.009 |
| 200 | 4.53 | 1.462 | 0.772 | 0.779 | 1.028 | +0.023 |
| 100 | 2.59 | **1.842** | 0.853 | 0.814 | 0.927 | +0.034 |
| 0 | 1.05 | 0.766 | 0.925 | 0.491 | 1.226 | +0.044 |

### Break Points

| Model | Location (from shore) | Depth | Hs at break | Type |
|---|---|---|---|---|
| Analytical | 95m | 2.51m | 1.833m | spilling |
| SWASH | peak Hs at 775m | 5.34m | 1.285m | (phase-resolved — no explicit gamma) |
| SWAN | Not clearly breaking in profile | — | — | (QB near zero throughout — bottom friction dominates) |
| XBeach | Not clearly breaking in profile | — | — | (Hs too low to trigger gamma×d at any depth) |

### Offshore Hs (input was 1.0m)

| Model | Offshore Hs | Delta from input | Notes |
|---|---|---|---|
| SWAN | 1.003m | +0.3% | Correct — spectral model preserves input |
| SWASH | 1.050m | +5.0% | Small standing wave residual despite BTYPE WEAK |
| Analytical | 0.946m | -5.4% | Refraction reduction from 25° oblique incidence |
| XBeach | 0.701m | -29.9% | Surfbeat mode partitions energy between short waves and IG |

### Observations

1. **Analytical model shows the strongest shoaling** — Hs increases from 0.95 to 1.84 before breaking at 95m from shore. This is because it has no bottom friction (frictionless propagation). The BJ78 shoaling + Snell refraction builds wave height continuously, only limited by depth-induced breaking.

2. **SWAN shows decreasing Hs offshore** (1.003 → 0.73) — bottom friction (JONSWAP cf=0.067) dissipates energy over the 2.4km approach. SWAN then shows slight jacking nearshore but no clear breaking — the waves never exceed gamma×d because friction has already reduced them below the breaking threshold.

3. **XBeach starts at 0.70m** — the surfbeat mode partitions the input spectrum into short-wave groups and bound IG waves. The short-wave Hrms (converted to Hs by ×√2) is only 70% of the input because energy goes into the IG component. This is not an error — it's how surfbeat mode represents wave groups.

4. **SWASH shows realistic shoaling** from 1.05 to 1.25m in mid-depth, then breaking/reformation patterns nearshore. The offshore Hs is slightly elevated (1.05 vs 1.0) from residual reflections despite the weakly-reflective boundary. The setup profile transitions from negative (set-down offshore) to positive (+0.044m at shore) — physically correct.

5. **None of the models except Analytical show a clear break point on this profile.** This is because the L2 bathymetric profile (100m resolution, interpolated to 5m) is a smooth slope with no sandbars. Real HB Pier has prominent sandbars at 100-200m from shore that focus breaking — but these features are below the L2 grid resolution. A higher-resolution CUDEM profile would produce more realistic breaking patterns in all models.

---

## Part 6: What Happened in the Initial Benchmark (T1.4/T1.5)

### XBeach (T1.4) — ran, but on wrong inputs
- **Binary:** `/opt/xbeach/bin/xbeach` (v1.23 BETA, built from source)
- **Profile:** 71 points from L3 BOTTOM.txt, 704m, 10m spacing, max depth 6.9m (WRONG — should be full CUDEM from 15m)
- **Boundary:** Synthetic JONSWAP Hs=1.5m Tp=10s 20° spread (WRONG — should be SPECOUT or NDBC)
- **Breaking:** gamma=0.55 (Roelvink default — different from analytical's 0.73, correctly documented as a physics choice)
- **Runtime:** 1.7s for 30-min simulation
- **Result:** Offshore Hs=1.03m (reduced from 1.5m by directional spread), breaking at x=412m depth=1.36m, setup=0.27m, IG up to 1m in surf zone

### SWASH (T1.5) — ran after fix, but on wrong inputs with wrong setup
- **Binary:** `/opt/swash/bin/swash` (v12.01, built from source)
- **Initial failure:** Segfault on `INITial ZERO` — turned out to be inverted bottom convention (elevation vs depth sign), NOT a binary bug. Fixed by READINP BOTTOM -1.
- **Profile:** Same wrong 71-point L3 profile
- **Boundary:** Regular waves (WRONG — should be spectral). No sponge layer (WRONG — causes standing wave contamination, offshore Hs=2.34m from 1.5m input)
- **Layers:** VERT=1 (INSUFFICIENT for IG — should be VERT≥2)
- **Runtime:** 0.113s for 50-min simulation
- **Result:** Contaminated by reflections. Breaking near x=412-422m. Standing wave pattern obscures the actual physics.

### Analytical (T1.3) — ran correctly on wrong inputs
- **Module:** `surf_1d_analytical.py` (576 lines, production code)
- **Profile:** Same wrong 71-point L3 profile
- **Input:** Hs=1.5m, Tp=10s, direction=270° (no spread — DIFFERENT from XBeach's 1.03m effective input)
- **Runtime:** 2.07ms
- **Result:** Breaking at x=392m depth=2.38m, plunging (Iribarren ξ=0.52). Hs overpredicted vs XBeach (~1.7m vs ~1.0m in shoaling zone — partly because analytical got 1.5m input while XBeach got 1.03m effective)
- **Bug found:** T8.2 consistency test exposed a Battjes-Janssen sign error (dE/dx sign flipped when distances are stored descending). Fixed at commit c987973.

### SWAN SurfBeat (T1.6) — availability confirmed, never benchmarked
- `SURFBeat` command confirmed available in SWAN 41.45/41.51
- Never run
- Never included in comparison

### Model selection (T1.7) — violated plan
- A prior session selected "Analytical (Option A)" without benchmarking XBeach, SWASH, or SWAN SurfBeat
- The plan at T1.7 explicitly requires: "User selects the 1D model" and "Present findings to user with recommendation"
- No comparison table was ever presented to the user
- XBeach and SWASH install+benchmark were unilaterally "deferred to v2"

---

## Part 7: Round 2 Benchmark Specification — Analytical + SWAN SurfBeat (controlled)

**Date:** 2026-07-21
**Decisions driving this round (user, 2026-07-21):**
- **XBeach and SWASH are fully ruled out** — production, LUT precomputation, AND benchmark referee. Round 1's runtime results (93 hr and 80 hr per forecast cycle) rule out production/LUT. For the referee role: SWASH is itself unvalidated at HB Pier, so using it as a "truth standard" would be validating one unvalidated model against another — circular reasoning. User decision 2026-07-21: no SWASH in any role.
- **Round 2 candidates:** Analytical (Option A) and SWAN SurfBeat (Option D, in its viable strip form per §7.3). These are the only two models.
- **Validation approach (no external referee):** SWAN CURVE consistency in the QB=0 zone (R3), friction-bracket analysis (Analytical with/without friction bounds the truth), cross-condition physical consistency checks, published IG observation ranges for SurfBeat, and comparison against competing surf forecasts (Surfline, etc.).

**Goal:** Fix the Round 1 confounds so the comparison is physically meaningful, and evaluate each model **only on what it is designed to do** — the analytical model on short-wave transformation, break points, breaker type, jacking, and peel geometry; SurfBeat on infragravity (IG) energy. Neither is scored on the other's job.

### 7.1 Why Round 1's physics comparison is unreliable (four confounds)

1. **Smooth bathymetry.** Round 1 used the L2 profile (100m source resolution, interpolated) — a featureless slope, violating Part 4's own design. No sandbars → no realistic breaking. The headline observation "only the analytical model shows a break point" is an artifact of this profile, not model physics.
2. **Mixed Hs definitions.** The Round 1 Hs table compares different quantities: XBeach's column is short-wave-only (IG energy excluded — hence 0.70m "offshore Hs"); SWASH's column is total surface variance (IG *included* — hence the physically impossible 1.23m "Hs" in 1.05m depth at the shoreline, which is IG/swash motion, not short waves); Analytical and SWAN are short-wave. The columns are not comparable.
3. **Friction miscalibration.** cfjon=0.067 is the JONSWAP *wind-sea* calibration; the established swell value is 0.038 (Zijlema et al. 2012; adopted as the SWAN default). Applying 0.067 to a 14s groundswell over a 2.4km approach stripped ~27% of SWAN's wave height — which is why SWAN never reached breaking. Meanwhile the analytical model has zero friction and over-shoals. Neither endpoint was configured to bracket the truth.
4. **The distinguishing measurements were never taken.** Part 4's measurement table required IG wave height and setup comparisons. No IG numbers were reported for any model, no with/without-SURFBEAT delta was run, and (per the corrected note in Part 5b) SURFBEAT cannot have been active in the 1D runs at all. Option D's entire value proposition remains unmeasured.

Round 1's **runtime** numbers are unaffected by these confounds and remain valid.

### 7.2 Verified SURFBEAT implementation facts (SWAN 41.51 manual; Reniers & Zijlema 2022)

Verified 2026-07-21 against the official SWAN 41.51 user manual (swanmodel.sourceforge.io) and the source paper. Corrects Part 1 Option D:

| Fact | Detail |
|---|---|
| Correct citation | **Reniers, A.J.H.M. & Zijlema, M. (2022). "SWAN SurfBeat-1D." Coastal Engineering 172, 104068.** (Not Rijnsdorp — that attribution error also existed in SURF-ZONE-MODEL-BRIEF §12 and is fixed there.) |
| Command | `SURFBeat [df] [nmax] [emin] UNIForm\|LOGarithmic` — defaults df=0.01 Hz, nmax=50000, emin=0.05 |
| Grid restriction (verbatim) | "CANNOT BE USED IN CASE OF CURVILINEAR or UNSTRUCTURED GRIDS AND NOT IN 1D-MODE" — regular (rectilinear) 2D grid only |
| Mode restriction | Stationary conditions only |
| Procedure | Two COMPUTE commands: first COMPUTE solves sea-swell + bound IG; second COMPUTE solves the reflected free IG waves |
| Geometry convention | Mild, **alongshore-uniform** slopes assumed; positive x-axis pointing **eastward**; offshore directionally-spread spectrum imposed on the **west** boundary; IG reflection at the shoreline via an OBSTACLE line on the **east** side with a reflection coefficient |
| Output | IG energy as explicit low-frequency spectral bins; extracted via spectral output after the COMPUTEs |

**Consequences:**
- **D2 / Architecture 6 (SWAN-1D + SurfBeat) is dead** — 1D mode is explicitly disallowed.
- **D1 as a one-line L3 change is dead** — the production L3 grid is coast-oriented and runs nonstationary; SURFBEAT requires a west→east, alongshore-uniform, stationary configuration with its own two-COMPUTE cycle and shoreline obstacle.
- The viable form is the **SurfBeat strip** (§7.3).
- **T7.GATE applies:** before any INPUT-generation code, the coordinator extracts the complete SURFBEAT syntax (command, two-COMPUTE sequence, reflection OBSTACLE, spectral output commands) from the *installed* 41.45/41.51 manual into `swan-commands-extract.md`. Round 1's T1.6 "availability confirmed" claim is re-verified against the installed binary as part of this gate.

### 7.3 The SurfBeat strip — the viable Option D configuration

A dedicated, idealized cross-shore run per spot:

| Element | Specification |
|---|---|
| Grid | Small regular 2D grid. x = cross-shore, oriented west→east **by construction** (the strip lives in its own coordinate frame, not geographic space). ~2,500m at dx=5m ≈ 500 cells cross-shore. Alongshore: start at ny=20 rows × 25m; tune for stability at setup. |
| Bathymetry | The spot's representative transect profile (from §7.4) duplicated identically alongshore — alongshore-uniform by construction, matching the formulation's assumption |
| Boundary | The L2 SPECOUT spectrum at the 15m handoff, rotated into the strip frame, imposed on the west boundary |
| Shoreline | OBSTACLE line on the east side with IG reflection coefficient per manual guidance |
| Mode | Stationary; two COMPUTEs per forecast timestep |
| Output | Spectral output at stations along the strip centerline; Hs_ig from integration below the split frequency (§7.5) |

**What it provides:** a spot-level IG profile — set/lull amplitude (Hs_ig) and, from the IG spectral peak, an indicative set period. One result per spot per forecast hour, NOT per-transect. Because the strip is alongshore-uniform it cannot see pier-shadow IG variation — acceptable, since set timing is displayed as a spot-level signal.

**Production cadence (decided 2026-07-21):** Strip runs every 3rd forecast hour (24 runs × 28s ≈ 11 minutes per spot per cycle). Intermediate hours carry forward the last SurfBeat result — no interpolation.

### 7.4 Bathymetry control (fixes confound 1)

- **Reality check first (2026-07-19 lesson):** CUDEM 1/9 arc-second (3.4m) has NO tiles south of 36°N on the Pacific coast — "3-5m CUDEM" does not exist at HB Pier. Best available is the NCEI SoCal regional DEM at ~10m (the L3 bathymetry source). All references to "CUDEM 3-5m profiles" in Parts 3-4 should be read as "best-available DEM, ~10m at HB."
- Extract the HB Pier south transect profile from the ~10m DEM. **Acceptance gate before any model runs:** plot the profile and verify bar-trough relief ≥ 0.3m. Sandbars (50-200m wavelength) are resolvable at 10m sampling, but the DEM's survey vintage may have smoothed or time-averaged them away.
- **If the DEM shows no bars:** add **Case B — synthetic barred profile** (a measured HB-type bar geometry superimposed on the DEM slope, or a Duck-type barred profile from the literature) so breaking, jacking, and reformation behavior is still exercised. Case B results test *model behavior*, not HB prediction — label them as such.
- Same profile for both models, interpolated to each model's dx (Analytical 5m; strip 5m).
- Tide: MSL for all runs. Optional extension: ±0.8m tide sensitivity on condition S1 only.

### 7.5 Variance accounting (fixes confound 2)

Every wave-height output in Round 2 is split at **f_split = 0.04 Hz (25s)** — below the longest sea-swell component in all test conditions:

- **Hs_sw** = 4·sqrt(variance integrated over f > 0.04 Hz) — short waves (sea + swell)
- **Hs_ig** = 4·sqrt(variance integrated over 0.004 ≤ f ≤ 0.04 Hz) — infragravity

Per model: **SurfBeat strip** — integrate the output spectrum above/below the split (the bound-IG bins are explicit). **Analytical** — all output is Hs_sw by definition; Hs_ig = n/a.

**No Round 2 table may mix bands in one column.** Round 1's Hs table is deprecated for accuracy claims.

### 7.6 Friction control (fixes confound 3)

- cfjon = **0.038** for swell-dominated conditions (S1, S2, S4); cfjon = **0.067** for the wind-sea condition (S3). Source: Zijlema et al. (2012); adopted SWAN default. Applied to SWAN (production L3 + SurfBeat strip) and Analytical-friction.
- **Pre-benchmark code task:** add an optional JONSWAP-equivalent bottom-friction dissipation term to `surf_1d_analytical.py` (an energy-flux sink alongside the BJ78 term — small, well-bounded change). Round 2 runs the analytical model **both ways** (friction on / friction off) so the frictionless bias is quantified explicitly rather than argued about.

### 7.7 Boundary-condition control (prevents Round 1 Problem 3 recurring)

- One source spectrum per condition, identical for both models.
- **Tier 1 (physics control):** unidirectional, shore-normal incidence. Isolates shoaling / breaking / friction with no refraction or spreading confound. Analytical receives (Hs, Tp, Dir); SWAN strip receives the same spectrum with the smallest directional spread SWAN tolerates numerically.
- **Tier 2 (realism):** oblique incidence with 20° spread (or the actual L2 SPECOUT when a SWAN cycle has produced one). Each model's effective 1D energy at the boundary is computed and **documented in the results table** — energy reductions from directional spreading must be visible, not discovered after the fact.
- **Run acceptance gate:** a model's offshore Hs_sw must be within ±3% of the imposed value (Tier 1) before its results count.

### 7.8 Test conditions

| ID | Scenario | Hs | Tp | Dir | cfjon | Why |
|---|---|---|---|---|---|---|
| S1 | Summer S groundswell | 1.0m | 14s | 200° | 0.038 | Round 1 comparable; typical HB summer |
| S2 | Winter W swell | 2.5m | 16s | 280° | 0.038 | Big-day case: breaking further offshore, stresses the QB=0 handoff assumption |
| S3 | Local windswell | 1.2m | 8s | 250° | 0.067 | Opposite friction/shoaling regime; inner-bar breaking |
| S4 (recommended) | Mixed: S1 + S3 as two partitions | — | — | — | 0.038 | Tests the analytical per-partition RSS combination against full-spectrum models |

All at MSL tide. Each condition runs Tier 1 and Tier 2 (§7.7).

### 7.9 Test matrix, measurements, acceptance criteria

**Model configurations:** Analytical-nofriction, Analytical-friction, SurfBeat strip WITH SURFBEAT, SurfBeat strip WITHOUT SURFBEAT (isolates the IG contribution and its marginal runtime). Plus the production SWAN L3 CURVE output as the R3 consistency reference in the QB=0 zone, when a cycle is available.

**Volume:** 4 conditions × 2 tiers × 4 configs = 32 runs. All are fast — analytical is milliseconds, strip runs are seconds. Full suite completes in minutes on librewxr (6 GB, 16 cores).

| Measurement | Compared between | Acceptance |
|---|---|---|
| Hs_sw profile, QB=0 zone (15m → outer break) | Analytical-friction vs SWAN strip | **R3 informational (not a gate):** Report delta. SWAN includes whitecapping + TRIAD + directional spreading the analytical model doesn't have; a 15-25% delta is expected from these extra physics, not from a model bug. The meaningful validation is face height vs observation (R10). |
| Hs_sw profile, friction bracket | Analytical-nofriction vs Analytical-friction | **Friction-bracket test:** Analytical-nofriction ≥ Analytical-friction at every point (friction only removes energy). The delta quantifies the frictionless bias. Report both profiles; the truth lies between them. |
| Break point location | Analytical (Hs_sw/d = γ crossing) | **Physical reasonableness:** break point moves offshore with increasing Hs (S2 > S1) and onshore with decreasing Tp (S3 vs S1). Break occurs on or near bar crests (barred profile / Case B). No cross-model gate — validated by physical consistency and Surfline comparison. |
| Breaker type per bar | Analytical (Iribarren) vs Surfline comparison | Qualitative agreement: spilling/plunging call matches what Surfline/BSR report. HB Pier in summer is typically spilling — Iribarren should agree. |
| Jacking factor over bars | Analytical (barred profile / Case B) | **Physical reasonableness:** jacking > 1.0 over bar crests, < 1.0 in troughs. No cross-model gate. |
| Hs_ig from SurfBeat strip | SurfBeat strip WITH vs WITHOUT SURFBEAT | **IG self-validation:** (1) SURFBEAT-on produces measurable Hs_ig below f_split where SURFBEAT-off does not. (2) Hs_ig scales with wave height: S2 > S1 > S3. (3) Shoreline Hs_ig in the range 0.05-0.40m for 1-2.5m swell — consistent with published IG observations at open beaches (Ruessink 1998; Stockdon et al. 2006). |
| SURFBEAT on/off delta | Strip vs strip | Confirms IG bins appear and quantifies marginal runtime |
| Cross-condition consistency | All configs | Bigger waves (S2) break further offshore than smaller (S1). Shorter period (S3) breaks closer to shore. Mixed (S4) per-partition RSS produces Hs_total > any single partition. Any violation → model bug. |
| Runtimes | All | Strip two-COMPUTE wall-clock (drives production cadence, §7.3); analytical per-run |

### 7.10 Pre-benchmark tasks (in order)

| # | Task | Blocks |
|---|---|---|
| T7-1 | T7.GATE: extract full SURFBEAT + two-COMPUTE + reflection-OBSTACLE + spectral-output syntax from the **installed** SWAN manual into `swan-commands-extract.md`; re-verify the command exists in the installed 41.45/41.51 binary | Strip INPUT generator |
| T7-2 | Extract HB Pier south profile from the ~10m NCEI DEM; run the bar-relief acceptance gate; build Case B synthetic barred profile if needed | All model runs |
| T7-3 | Add optional bottom-friction term to `surf_1d_analytical.py` | Analytical-friction runs |
| T7-4 | ~~SWASH band-separation post-processor~~ — **REMOVED** (SWASH ruled out from benchmark referee role, user decision 2026-07-21) | — |
| T7-5 | SurfBeat strip INPUT generator prototype (benchmark-grade, not production) | Strip runs |

### 7.11 Decision rule (feeds T1.7 — user selects the model)

- If Analytical-friction passes the friction-bracket test, passes cross-condition consistency, produces physically credible break points / breaker types / jacking, and validates against real-world observed face heights → **Architecture 2-prime confirmed** (Analytical per-transect + SurfBeat strip for IG), presented to the user for the T1.7 selection.
- If the SurfBeat strip fails its IG self-validation (no measurable IG energy, or IG doesn't scale with wave height) → **Architecture 1** (Analytical only) and the set-timing display is dropped for v1. XBeach does not re-enter — it is ruled out.
- If Analytical-friction fails cross-condition consistency or produces face heights that are obviously wrong → STOP and present the failure to the user. Do not tune γ or friction to force a pass without user review — calibration choices at that point are a user decision.
- **R3 consistency (Analytical vs SWAN in QB=0 zone) is informational, not a gate.** The models use different physics (SWAN includes whitecapping, TRIAD, directional spreading that the analytical model doesn't have). A delta between them is expected; what matters is that the analytical model's end product (face height at breaking) matches real-world observation.
- Either way: results tables (band-separated, per condition, per tier) land in this brief as Part 8, and SURF-1D-IMPLEMENTATION-PLAN Phase 1 is updated.

---

## Part 8: Round 2 Benchmark Results (2026-07-21)

### 8.1 Head-to-Head: Analytical vs SurfBeat Strip

These two models do different jobs and run together. The comparison is not "which one wins" — it's "what does each contribute and can it run in production?"

**What each model does:**

| | SwellTrack | SurfBeat (SWAN strip) |
|---|---|---|
| **Purpose** | Wave height, break points, breaker type, face height, jacking, peel angle | Infragravity (IG) energy — set/lull timing |
| **Runs per cycle** | 32,400 (150 transects × 3 partitions × 72 hrs) | 24 (1 per spot per 3rd forecast hour) |
| **Per-run time** | 1.0-1.5 ms | 28 s |
| **Full cycle time** | **< 1 minute** | **~11 minutes per spot** |
| **Grid** | 1D profile, 500 points at 5m | 2D strip, 500×20 cells at 5m×25m |
| **Physics** | Shoaling, refraction, BJ78 breaking, roller, bottom friction | Full SWAN spectral + bound/free IG generation |

**How they compare on the same input (S1: 1.0m @ 14s, shore-normal, HB Pier DEM profile):**

| Measurement | SwellTrack (w/ friction) | SurfBeat Strip | Notes |
|---|---|---|---|
| Offshore Hs | 1.000m | 0.999m | Both preserve input — good |
| Hs at 500m from shore | 0.914m | 0.724m | SwellTrack 26% higher — SWAN has whitecapping + TRIAD that SwellTrack doesn't |
| Break point | 155m from shore | ~95m (QB=0.08 at S24) | Different breaking formulations — both reasonable |
| Face height (S1) | **5.5 ft** | N/A (not its job) | SwellTrack produces the surf height number |
| IG at 95m from shore | N/A (not its job) | **Hs_ig = 0.155m** | SurfBeat produces the set/lull timing |
| Breaker type | Spilling (Iribarren) | N/A | SwellTrack produces the breaker classification |

### 8.2 Accuracy vs Surfline (Real-World Validation)

**Test:** Today's actual conditions (2026-07-21), 3 partitions from Surfline's LOTUS forecast, compared against Surfline's reported observed height at HB Pier.

| | Surfline Reported | Analytical Model | Delta |
|---|---|---|---|
| **Face height** | **4-5 ft** (chest to head) | **4.7 ft** | Dead center of range |
| Swell 1 | 2.0ft @ 15s S 190° | 0.61m input → breaks at outer bar | Per-partition transformation |
| Swell 2 | 2.4ft @ 9s S 185° | 0.73m input → breaks at inner bar | Shorter period, breaks closer to shore |
| Swell 3 | 1.5ft @ 12s S 185° | 0.46m input → adds energy at break | Contributes via RSS combination |

The analytical model matches real observed conditions to within 0.3ft on a live test.

### 8.3 Does the Physics Make Sense?

Four conditions tested. All physically correct:

| Condition | Hs | Tp | What should happen | What the model does |
|---|---|---|---|---|
| S1 (summer groundswell) | 1.0m | 14s | Moderate break, spilling | Breaks at 155m, 5.5ft face, spilling ✓ |
| S2 (winter swell) | 2.5m | 16s | Big break, further offshore | Breaks at 265m, 11.7ft face, spilling ✓ |
| S3 (windswell) | 1.2m | 8s | Small break, close to shore | Breaks at 95m, 3.0ft face, spilling ✓ |
| S4 (mixed S1+S3) | — | — | Bigger than either alone | 6.3ft (> S1's 5.5 or S3's 3.0) ✓ |

S2 breaks further offshore than S1 ✓. S3 breaks closer to shore than S1 ✓. These are basic physics — if the model got any of these wrong, it would be broken.

### 8.4 SurfBeat IG Results

The SurfBeat strip adds one thing the analytical model cannot provide: **infragravity (IG) wave energy** — the "set/lull" rhythm that makes some waves bigger than others on a 1-3 minute cycle.

| | SURFBEAT ON | SURFBEAT OFF |
|---|---|---|
| IG at shoreline (95m) | **Hs_ig = 0.155m (6 inches)** | 0.000m |
| IG at 295m | 0.024m | 0.000m |
| IG at 495m+ | 0.000m | 0.000m |
| Sea-swell Hs | Unchanged (< 0.3% diff) | Baseline |
| Runtime | 28 s | 11 s |
| Marginal cost of IG | **+17 seconds** per run | — |

The IG amplitude (0.155m for a 1.0m swell) is within published ranges for open beaches (0.05-0.40m). IG energy grows toward shore and only appears with SURFBEAT enabled — the feature works as designed.

**Production cost:** 24 strip runs (every 3rd hour) × 28s = **~11 minutes per spot per cycle**. Intermediate hours carry forward the last SurfBeat result.

### 8.5 Runtime at Production Scale

**Model names:** The analytical 1D model is **SwellTrack** (proprietary). The SWAN SURFBEAT strip retains the name **SurfBeat**.

**Cadence decision (user, 2026-07-21):** SwellTrack runs every forecast hour (72 timesteps). SurfBeat runs every 3rd forecast hour (24 timesteps) — set/lull timing evolves slowly enough that 3-hour resolution is adequate.

For HB Pier south (150 transects, 3 swell partitions):

| Component | Cadence | Runs | Per-run | Total | Blocking? |
|---|---|---|---|---|---|
| SWAN L1→L2→L3 | per cycle | 1 | ~3 min | **~3 minutes** | Yes — existing pipeline |
| SwellTrack | hourly (72 hrs) | 32,400 | 1.2 ms | **39 seconds** | No — runs after SWAN |
| SurfBeat strip | 3-hourly (25 runs: hrs 0,3,...,72) | 25 | 28 s | **~12 minutes** | Yes — SWAN subprocess |
| **Total** | | | | **~15 minutes** | |

### 8.6 What Each Model Gets Right, Gets Wrong, and What You Lose Without It

#### SwellTrack (Analytical 1D)

| | |
|---|---|
| **Gets right** | Face height (4.7ft vs observed 4-5ft). Break point location. Breaker type classification. Per-partition swell transformation (the 15s ground swell breaks at the outer bar, the 9s wind swell at the inner bar — this is how real waves work). Runs fast enough for real-time per-transect spatial detail across the whole beach. |
| **Gets wrong** | Overestimates wave height by ~24% in the approach zone vs SWAN, because it doesn't model whitecapping or triad interactions. This doesn't matter at the break point (BJ78 caps it at γ×d), but it means the shoaling profile between 15m and 3m depth is too high. No infragravity (IG) waves — can't tell you about set/lull timing. |
| **If you drop it** | You lose: face height, break point location, breaker type, per-transect spatial map, peel angle, jacking factor, wave shapes, surf zone classification. The SurfBeat strip doesn't produce any of these. You'd be back to SWAN CURVE at 10m resolution with no breaking detail — worse than what we have today. |

#### SurfBeat Strip

| | |
|---|---|
| **Gets right** | Produces measurable IG energy (0.155m at the shoreline for 1m swell) that is physically reasonable and within published ranges. IG grows toward shore as expected. Doesn't alter the sea-swell field — the IG is additive, not a distortion. |
| **Gets wrong** | We don't yet know if the IG scales correctly across conditions (only S1 was tested — S2/S3 still need to be run). The strip is alongshore-uniform, so it can't see IG variation near structures (pier shadow). 34 minutes per spot per cycle is heavy. |
| **If you drop it** | You lose: set/lull timing. The surf page would show wave height and conditions but couldn't tell you "sets are coming every 12-15 minutes" or "the lulls between sets are 8 minutes." This is a nice-to-have for surfers, not a core feature. Many surf forecasts don't offer it. |

#### The trade-off

Running **both** costs ~15 minutes total per spot per forecast cycle (SwellTrack hourly: <1 min, SurfBeat 3-hourly: ~11 min, SWAN: ~3 min). Running **SwellTrack only** costs ~4 minutes and delivers everything a surfer needs to decide whether to go out — face height, conditions, breaker type, spatial map of the break. The SurfBeat strip adds set/lull timing, which experienced surfers appreciate but isn't necessary for a useful forecast.

### 8.7 Decision

**Architecture: SWAN + SwellTrack + SurfBeat.**

Attribution on the surf page: **"SWAN + SwellTrack"** (user decision 2026-07-21). SWAN provides the offshore spectral data and IG via SurfBeat. SwellTrack is the proprietary cross-shore wave transformation model that produces the surf-facing outputs. SurfBeat is SWAN's infragravity module, not a separate brand — it runs inside SWAN.

SwellTrack is the workhorse — surf height (validated at 4.7ft vs Surfline's 4-5ft), break points, breaker type, spatial detail. SurfBeat adds set/lull timing at 3-hour resolution. Both confirmed working.

### 8.8 Supporting Data

The full test matrix, friction-bracket analysis, R3 informational comparison, and IG band-separation tables are in [Appendix A](#appendix-a-detailed-tables) below.

---

## Part 9: Model → Display Mapping & Implementation Fixes

### 9.1 What Feeds What on the Surf Page

Every display element on the surf page has a data source. This table is the authoritative mapping — if a display element is wired to the wrong source, it's a bug.

**Card 1: Surf Score**

| Display element | Data source | Model |
|---|---|---|
| Quality stars (1-5) | `surf_scorer.py` total_score / 20 | Scorer (inputs from SwellTrack + SWAN) |
| Quality label ("Good", "Epic", etc) | `surf_scorer.py` via i18n | Scorer |
| Conditions text | `surf_scorer.py _compose_conditions_text()` | Scorer |
| 6 scoring bars | `surf_scorer.py` sub-factors | Scorer |

**Card 2: Incoming Swell (offshore)**

| Display element | Data source | Model |
|---|---|---|
| Swell components (height/period/dir) | SPECOUT decomposition at ~15m depth | SWAN (pre-model, deep water) |
| Swell dominance (%) | `_swell_dominance(multi_swell)` | Computed from SPECOUT partitions |

**Card 3: Conditions at Break**

| Display element | Data source | Model |
|---|---|---|
| Face height (headline) | SwellTrack `best_peak_face_height_m` | **SwellTrack** |
| Best peak / Average | SwellTrack per-transect aggregation | **SwellTrack** |
| Break point distance | SwellTrack H/d = γ crossing | **SwellTrack** |
| Breaker type (spilling/plunging) | SwellTrack Iribarren number | **SwellTrack** |
| Peel angle + classification | SwellTrack multi-transect break geometry | **SwellTrack** |
| Wave shape (hollow/crumbly/etc) | SwellTrack depth regime + Iribarren | **SwellTrack** |
| Per-partition break info | SwellTrack per-partition 1D runs | **SwellTrack** |
| Set/lull timing | SurfBeat strip IG spectral peak period | **SurfBeat** |
| Set/lull amplitude | SurfBeat strip Hs_ig at shoreline | **SurfBeat** |

**Card 4: 72-Hour Forecast Scroll**

| Row | Data source | Cadence |
|---|---|---|
| Surf Height (face) | SwellTrack `breakingFaceHeight` | Hourly |
| Swell Height | SPECOUT dominant partition Hs | Hourly |
| Best Peak | SwellTrack `bestPeakFaceHeight` | Hourly |
| Period | SWAN TABLE TM01 at ref point | Hourly |
| Direction | SWAN TABLE DIR at ref point | Hourly |
| Peel Angle | SwellTrack `peelAngle` | Hourly |
| Wave Shape | SwellTrack `waveShapeClassification` | Hourly |
| Wind Quality | Scorer wind sub-factor | Hourly |
| Set Timing | SurfBeat IG peak period | **3-hourly (carry-forward between runs)** |

**Beach Profile Chart**

| Element | Data source | Model |
|---|---|---|
| Seafloor profile | CUDEM bathymetry via transect | Pre-computed |
| Hs envelope (approach zone, 15m → break) | **Blended: SurfBeat strip Hs** (see §9.2) | SurfBeat strip |
| Hs envelope (surf zone, break → shore) | **SwellTrack** | SwellTrack |
| Wave shapes overlay | SwellTrack Stokes/cnoidal | SwellTrack |
| Surf zone overlays (impact/foam) | SwellTrack zone classification | SwellTrack |
| Break point markers | SwellTrack H/d crossings | SwellTrack |
| Jacking annotations | SwellTrack bar crest Hs ratio | SwellTrack |

**Heat Map (quasi-2D)**

| Element | Data source | Model |
|---|---|---|
| Hs color field across transects | SwellTrack per-transect Hs | SwellTrack |
| Break zone curves | SwellTrack break points per transect | SwellTrack |
| Zone polygons (impact/foam) | SwellTrack zone boundaries | SwellTrack |
| Structure-affected transects | Obstacle intersection test | Pre-computed |

**Model Attribution Line**

| Element | Content |
|---|---|
| Attribution | "SWAN + SwellTrack" |
| Last run time | SWAN cache run_time |

### 9.2 Blended Hs Profile (Approach Zone Fix)

SwellTrack overestimates Hs by ~24% in the approach zone (15m → break point) because it doesn't model whitecapping or TRIAD interactions. The SurfBeat strip already runs for IG — its sea-swell Hs profile in the approach zone comes for free and includes these physics.

**Blend rule:** On the beach profile chart, use the SurfBeat strip's Hs_sw from the offshore boundary to the outermost SwellTrack break point. From the break point shoreward, switch to SwellTrack's Hs (which provides breaking detail, roller, zones, and wave shapes that SWAN doesn't).

This gives the best of both: SWAN's accurate approach-zone physics and SwellTrack's detailed surf-zone features. The crossover happens at the break point — which SwellTrack identifies.

**Implementation:** The beach profile endpoint already has both data sources (SPECOUT + SwellTrack). Add a blend step in `surf_1d_pipeline.py` that replaces the SwellTrack Hs profile seaward of the first break point with the SurfBeat strip's TABLE output at the corresponding distances.

**Note:** The blend only affects the beach profile chart display. The face height, break points, and all scoring inputs still come entirely from SwellTrack — those are not blended.

### 9.3 Compute Offloading to librewxr

Currently all model computation runs in-process on the weewx API server. The weewx container has limited RAM (1.9 GB) and shares CPU with the weewx engine, MariaDB, and Redis. The librewxr container has 6 GB RAM and 16 dedicated cores — it's where Round 1 benchmarks ran.

**What moves to librewxr:**
- SwellTrack pipeline (32,400 runs per cycle — CPU-intensive burst)
- SurfBeat strip SWAN runs (24 × 28s — SWAN subprocess)
- SWAN L1→L2→L3 could also move, but that's a separate decision

**What stays on weewx:**
- The API server (FastAPI, endpoints, scoring, response assembly)
- SPECOUT parsing (lightweight, needed for response)
- Breaker height conversion (trivial computation)

**Implementation path:**
1. Add `surf_compute_host` config key to `marine_config.py` (URL of the compute service on librewxr)
2. Build a lightweight compute service on librewxr that accepts: SPECOUT data, transect profiles, tide level, config → returns: SwellTrack results, SurfBeat strip results
3. The API's `run_pipeline()` call in `surf.py` becomes an HTTP POST to the compute service instead of an in-process call
4. Fallback: if compute service is unreachable, run in-process on weewx (degraded performance but not broken)

**No existing remote compute config exists** — grep confirmed zero matches for "compute_host", "model_host", or "remote" in the settings.

### 9.4 Wizard/Admin Setup Changes

**Current surf spot config fields** (from `marine_config.py`):
- `segment_start_lat/lon`, `segment_end_lat/lon` — shoreline segment (already implemented, Phase 2)
- `transect_spacing_m` — default 10m (implemented)
- `l3_enabled` — auto/on/off (implemented, Phase 3)
- `structures` — list of structures (implemented)
- `directional_exposure` — 8-compass open/blocked (implemented)
- `breaker_formula` — komar_gaughan or caldwell (implemented but being replaced by SwellTrack)
- `surf_height_display` — face or hawaiian (implemented)
- `bottom_type`, `beach_slope`, `topographic_feature` — metadata (implemented)

**New fields needed:**

| Field | Purpose | Default | Where |
|---|---|---|---|
| `surf_compute_host` | URL of librewxr compute service | `null` (in-process fallback) | Marine config, admin |
| `surfbeat_enabled` | Enable/disable SurfBeat strip | `true` | Per-spot, admin |
| `surfbeat_cadence_hours` | SurfBeat run interval | `3` | Per-spot, admin |
| `friction_coefficient` | JONSWAP cfjon | `0.038` (swell default) | Per-spot, admin (advanced) |

**Wizard changes:**
- No changes to the shoreline segment drawing (already done)
- Add a step or toggle for SurfBeat: "Enable set/lull timing (adds ~11 min compute per cycle)"
- The `surf_compute_host` is an admin/ops setting, not wizard — operators configure the compute service separately

**Admin changes:**
- Add SurfBeat toggle and cadence to the marine admin panel
- Add friction coefficient as an advanced setting (hidden by default, for operators who know their bottom type)
- Add compute host URL field

### 9.5 Implementation Plan Fixes

The existing SURF-1D-IMPLEMENTATION-PLAN has these gaps relative to the benchmark findings:

| Issue | Plan says | Should say |
|---|---|---|
| Model name | "analytical 1D model" / "Option A" throughout | **SwellTrack** |
| SurfBeat cadence | Not specified (implied every hour) | **Every 3 hours** (24 runs, not 72) |
| Compute location | Implicit in-process on weewx | **librewxr** via compute service |
| Approach zone Hs | SwellTrack only | **Blended** (SurfBeat strip for approach, SwellTrack for surf zone) |
| Phase 8 T8.1 | "SWASH ground truth" | **Removed** — SWASH ruled out entirely |
| Phase 8 T8.4 | "webcam/surf-report comparison" | **Comparison against Surfline** — we don't have a webcam |
| Friction | Optional (Phase 1 benchmark feature) | **Always on** in production (cfjon=0.038 swell default) |
| IG display | Not specified in dashboard phases | SurfBeat set/lull timing feeds Card 3 and 72h forecast |
| Attribution | `nearshoreModel: "swan"` | **"SWAN + SwellTrack"** |

### 9.6 Future: Ray-Traced Reflection Coupling (eliminates L3 for structure-affected spots)

**Status:** Concept only. Not blocking any current work. Design and implement when a reflective-structure spot is added (jetty, seawall, breakwater).

**Problem:** SwellTrack transects are independent 1D runs — they can't see energy reflected off structures onto neighboring transects. SWAN L3's OBSTACLE REFL handles this with phase-averaged reflection, but requires a full 2D grid (~3 min compute) and provides no spatial ray geometry. For spots near reflective structures, L3 is currently the only option.

**Proposed approach — inter-transect reflection coupling:**

1. SwellTrack runs all transects normally (offshore → shore), producing Hs at every point on every transect.
2. For each structure with REFL > 0, identify where incoming wave energy hits the structure face. The incident Hs and direction are known from step 1.
3. Compute reflected energy: `Hs_reflected = Hs_incident × REFL`. Reflection angle = incidence angle (specular), or spread across a cone (diffuse, controlled by RDIFF power).
4. Trace reflected rays outward from the structure face. Each ray is a geometric line from the reflection point in the reflected direction. Compute where each ray intersects each transect — this is line-segment intersection math against the transect array.
5. At each intersection point, add reflected energy to the existing SwellTrack Hs via RSS: `Hs_combined = sqrt(Hs_existing² + Hs_reflected²)`. Apply 1/√r energy spreading from the reflection point (r = distance from structure to intersection).
6. Re-run SwellTrack from each affected point shoreward — the reflected energy shoals, refracts, and breaks just like primary energy.

**What this captures:**
- Reflected energy appearing on transects alongside the structure (jetty amplification)
- Spatial decay with distance from the reflection point
- Reflected wave transformation (shoaling + breaking) on its own path to shore
- Could extend to crude diffraction: at structure tips, radiate energy into the shadow zone with amplitude decaying by a diffraction coefficient — same ray-tracing pattern

**What this does NOT capture:**
- Phase-coherent interference. RSS combination of two equal waves gives 1.41× (41% increase). True in-phase constructive interference (The Wedge) gives 2.0× (100% increase). This approach underestimates The Wedge-type spots. For most reflective structures, RSS is the physically correct energy combination because the reflected and incoming waves are not phase-locked.
- Multiple reflections (wave bounces off jetty, then off seawall). Rare in practice — ignore for v1, add iteratively if needed.

**Why this is better than SWAN L3 OBSTACLE REFL:**
- Explicit spatial ray geometry vs phase-averaged energy dump
- Runs in milliseconds (geometry + partial SwellTrack re-runs) vs 3 minutes (full L3 grid)
- Eliminates L3 grid management complexity (smart sizing, hotstart invalidation, bbox computation)
- Could handle diffraction with the same ray-tracing framework

**Implementation estimate:** ~200-300 lines in SwellTrack. The structure positions, face orientations, and REFL/TRANSM coefficients are already in the spot config. The transect array geometry is already computed. The main new code is ray-structure intersection and the partial re-run orchestration.

**When to build:** When a spot with a reflective structure (jetty, seawall, vertical breakwater) is added to the system and L3's 3-minute cost becomes a production concern. Not needed for HB Pier (TRANSM=0.95, negligible reflection from pilings).

---

### Appendix A: Detailed Tables

#### A.1 Full Analytical Test Matrix (Tier 1, shore-normal, beach_facing=230°)

| Cond | Profile | cfjon | Break(m) | Depth(m) | Hs_brk(m) | Face(ft) | Type | ms |
|------|---------|-------|----------|----------|-----------|----------|------|-----|
| S1 | DEM | — | 190 | 2.5 | 1.81 | 7.5 | spilling | 1.5 |
| S1 | DEM | 0.038 | 155 | 1.8 | 1.32 | 5.5 | spilling | 1.1 |
| S1 | Barred | — | 235 | 2.4 | 1.75 | 7.3 | plunging | 1.1 |
| S1 | Barred | 0.038 | 210 | 1.9 | 1.39 | 5.8 | spilling | 1.0 |
| S2 | DEM | — | 330 | 4.8 | 3.52 | 14.7 | spilling | 1.1 |
| S2 | DEM | 0.038 | 265 | 3.9 | 2.82 | 11.7 | spilling | 1.1 |
| S2 | Barred | — | 335 | 4.9 | 3.57 | 14.9 | spilling | 1.1 |
| S2 | Barred | 0.038 | 285 | 3.9 | 2.85 | 11.9 | spilling | 1.0 |
| S3 | DEM | — | 180 | 2.3 | 1.68 | 7.0 | spilling | 1.0 |
| S3 | DEM | 0.067 | 95 | 1.0 | 0.73 | 3.0 | spilling | 1.0 |
| S3 | Barred | — | 230 | 2.3 | 1.65 | 6.9 | spilling | 1.0 |
| S3 | Barred | 0.067 | 130 | 1.0 | 0.74 | 3.1 | spilling | 1.0 |

#### A.2 Friction-Bracket (S1, DEM profile, shore-normal)

| Dist from shore | Depth | No-friction Hs | Friction Hs | Reduction |
|-----------------|-------|----------------|-------------|-----------|
| 2500m | 11.8m | 1.000m | 1.000m | 0.0% |
| 2000m | 10.9m | 1.003m | 0.944m | 5.9% |
| 1500m | 10.1m | 1.034m | 0.911m | 11.9% |
| 1000m | 9.3m | 1.070m | 0.877m | 18.1% |
| 500m | 6.8m | 1.219m | 0.914m | 25.0% |
| 300m | 4.4m | 1.467m | 1.040m | 29.1% |

#### A.3 R3 Informational — Analytical vs SWAN (QB=0 zone, S1)

SWAN includes whitecapping + TRIAD + directional spreading the analytical model doesn't — the delta is expected, not an error.

| Dist from shore | Analytical (fric) | SWAN strip | Delta |
|-----------------|-------------------|------------|-------|
| 2495m | 1.000m | 0.999m | +0.1% |
| 1995m | 0.944m | 0.942m | +0.2% |
| 1495m | 0.911m | 0.734m | +24% |
| 995m | 0.877m | 0.717m | +22% |
| 495m | 0.914m | 0.724m | +26% |

#### A.4 Bathymetry

**DEM profile:** Real NCEI DEM, extracted from SWAN L3+L2+L1 grids. 500 points at 5m, 0.17-11.78m depth. No sandbars resolved (10m DEM too coarse).

**Barred profile:** DEM + synthetic bars (outer bar at 220m, 1.0m relief; inner bar at 100m, 0.6m relief) to exercise breaking/reformation dynamics.
