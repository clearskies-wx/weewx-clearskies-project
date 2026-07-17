---
status: Archived — consolidated into API-MANUAL.md, PROVIDER-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
superseded-by: ADR-093
deciders: shane
---

# ADR-084: NWPS as primary nearshore source with site-specific supplementation

**Superseded by ADR-093.** NWPS is eliminated. The nearshore source is now SWAN+TruShore (locally-run SWAN instance). The four supplements defined here continue to apply to SWAN output.

## Context

Surf forecasting requires nearshore wave data — wave height, period, and direction as they approach the beach, not in deep water. NOAA's Nearshore Wave Prediction System (NWPS) runs the SWAN spectral model at 50m–1.8 km resolution for all 36 US coastal WFOs plus Great Lakes. NWPS output includes post-transformation values: shoaling, refraction, bottom friction, and wave-current interaction are already computed by SWAN using high-resolution bathymetry and RTOFS ocean currents.

NWPS has four documented limitations that site-specific corrections can address:

1. SWAN uses a single constant breaker index (γ = 0.73) across its entire domain, while the actual value varies from ~0.6 to ~1.2 depending on bottom slope and type.
2. SWAN cannot model wave diffraction behind coastal structures (breakwaters, jetties, piers) because it is a phase-decoupled model.
3. NWPS CG1 grids are ~1.8 km — an operator's spot may fall between grid nodes.
4. Large-scale coastal morphology (headlands, bays) creates focusing/sheltering effects that NWPS may not fully resolve.

The pre-Clear-Skies Phase II extension contains a full wave transformation pipeline (shoaling, refraction, breaking, bottom friction) that was never wired into its main loop. Porting the full pipeline would duplicate physics that NWPS already computes better (NWPS uses higher-resolution bathymetry and actual ocean currents). Only the four specific corrections above add value over raw NWPS output.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Use NWPS as-is, no supplementation | Simplest. No physics code to maintain. | Misses real limitations (constant γ, no structure effects). Scoring operates on uncorrected values. |
| Full wave transformation pipeline (port Phase II shoaling/refraction/breaking/friction) | Maximum control over nearshore physics | Duplicates what NWPS already computes with better bathymetry. Maintenance burden of a full physics pipeline. |
| Targeted supplementation of four specific NWPS limitations | Corrects documented limitations without duplicating NWPS physics. Manageable code surface. Research-validated methods. | Still requires operator config (bottom type, structures). Corrections are approximate. |

## Decision

NWPS is the primary nearshore data source for US. Four specific supplements correct documented NWPS/SWAN limitations:

### Supplement 1 — Breaker index correction (γ tuning)

SWAN uses γ = 0.73 (Battjes & Stive 1985 average). Actual γ varies from ~0.6 (spilling, gentle sand) to ~1.2 (plunging, steep reef).

**Formula:** γ = 1.06 + 0.14 ln ξ (Battjes 1974), where ξ = tan α / √(H₀/L₀) is the Iribarren number:
- tan α = average nearshore bottom slope (computed from NOAA CUDEM bathymetric profile at setup, 1/9 arc-second ~3.4m resolution)
- H₀ = NWPS-provided significant wave height
- L₀ = deep-water wavelength = g × T² / (2π), where T = NWPS-provided peak period

**Application:** Recompute maximum wave height at breaking as H_max = γ_corrected × depth, using the site-specific γ instead of SWAN's constant 0.73.

**Operator inputs:** bottom type (sand/rock/coral_reef/mixed), beach slope (computed from CUDEM bathymetric profile).

**Validation:** γ output clamped to [0.5, 1.4] (physical bounds from literature).

### Supplement 2 — Coastal structure effects (transmission/reflection)

SWAN cannot model diffraction behind structures at NWPS grid scales (confirmed by SWAN documentation and Holthuijsen et al.).

**Method:** Apply transmission coefficient: H_transmitted = Kt × H_incident.

**Coefficients by material permeability:**
- Impermeable (concrete seawall, solid breakwater): Kt = 0.10 ± 0.05
- Semi-permeable (rubble mound, rock jetty): Kt = 0.35 ± 0.15
- Permeable (timber pier, open groin): Kt = 0.75 ± 0.10

**Influence zone:** Effects apply within structure-type-specific distance and diminish as 1/r².

**Caveat:** All output labeled "estimated — structure effects are approximate."

**Operator inputs:** structure type, material, dimensions, position relative to spot.

### Supplement 3 — Sub-grid spatial interpolation

**Method:** Bilinear interpolation using the four surrounding NWPS grid nodes.

**No operator input required** — coordinates already configured.

### Supplement 4 — Topographic wave focusing/sheltering

**Method:** Multiplicative adjustment based on operator-classified feature:
- Point break (focusing around headland): × 1.1
- Headland (refraction enhancement): × 1.2
- Bay break (sheltering): × 0.9
- Straight beach (no modification): × 1.0

**Operator inputs:** topographic feature classification.

### What we do NOT supplement

Shoaling, refraction, bottom friction, wave-current interaction. NWPS/SWAN computes these with its own bathymetry and RTOFS currents. Re-running them would duplicate NWPS's work without improving it.

### No fallback transformation pipeline

NWPS data availability verified against NOMADS (July 2026): all 36 coastal WFOs produce 2–3 cycles/day. When NWPS is temporarily unavailable, the marine page shows WaveWatch III offshore data without nearshore supplementation. No separate code path.

## Consequences

- **Enrichment processor:** `enrichment/wave_transform.py` applies the four supplements to NWPS data before surf scoring.
- **Operator config required:** Bottom type, structures (optional), topographic feature per surf spot. Beach slope computed from bathymetric profile at setup time.
- **Bathymetry source:** NOAA CUDEM (1/9 arc-second, ~3.4m resolution) via NCEI THREDDS/OPeNDAP. One-time per-spot download at setup. CUDEM covers all US coastal areas including territories (Hawaii, PR, USVI, Guam, CNMI, American Samoa). At ~3.4m resolution, individual reef structures, sandbars, and ledges are visible — producing accurate slope computations for the Battjes formula and rich habitat profiles for fishing (ADR-088). International bathymetry sources are out of scope for v1.
- **No full physics pipeline to maintain.** Only four targeted corrections.
- **Future improvement:** Statistical calibration (forecast-vs-observation pairs over time) is a v2+ feature, following the same pattern as the forecast correction engine (ADR-079).

## Acceptance criteria

- [ ] Enrichment processor applies γ correction using Battjes 1974 formula with operator-configured bottom type and CUDEM-derived slope
- [ ] γ output clamped to [0.5, 1.4]; values outside this range logged as warnings
- [ ] Structure transmission reduces wave height by the configured Kt coefficient within the influence zone
- [ ] Bilinear interpolation produces values at exact spot coordinates from surrounding NWPS grid nodes
- [ ] Topographic adjustment applies the correct multiplier for each feature type
- [ ] Enrichment processor is a no-op when NWPS data is unavailable (WaveWatch III data passes through unmodified)
- [ ] Existing enrichment pipeline tests pass unchanged

## Implementation guidance

- **File:** `enrichment/wave_transform.py` — registered against the surf scoring pipeline, runs after NWPS fetch and before `surf_scorer.py`.
- **Inputs:** NWPS wave data (height, period, direction), spot config (bottom type, slope, structures, topographic feature, coordinates), CUDEM bathymetric profile.
- **Outputs:** Corrected wave height, period, direction at the spot location.
- **Constants:** All physics constants (γ bounds, Kt values, topographic multipliers) defined as module-level constants with source citations in comments.
- **Out of scope:** NWPS GRIB fetching (that's the provider module, Phase 2). Surf scoring (Phase 3). Bathymetry download (Phase 3). This ADR defines the supplement logic only.

## References

- Battjes 1974 — breaker index γ formula: [Coastal Wiki](https://www.coastalwiki.org/wiki/Breaker_index)
- Battjes & Stive 1985 — γ variability dataset (0.6–0.83)
- Carini et al. 2021 — predicting breaking onset: [JGR Oceans](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020JC016935)
- Ruiz de Alegría-Arzaburu et al. 2021 — nearshore γ parameterization, 10–24% improvement: [arXiv](https://arxiv.org/abs/2104.00208)
- Ocean Engineering 2022 — modified γ for spectral models: [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0029801822018108)
- SWAN limitations (diffraction, single γ): [SWAN docs](https://swanmodel.sourceforge.io/online_doc/swanuse/node4.html)
- van der Westhuysen 2010 — NWPS breaking rescaling: [JGR Oceans](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2009JC005433)
- Zanuttigh & Van der Meer 2006 — structure transmission coefficients
- Goda 2000 — Random Seas and Design of Maritime Structures
- CERC 1984 — Shore Protection Manual
- Camus et al. 2011 — statistical nearshore downscaling validation
- Related ADRs: ADR-083 (domain architecture), ADR-085 (eccodes dependency), ADR-086 (multi-spot location model)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §3, §5.2.1, §7, §11.4–11.5
