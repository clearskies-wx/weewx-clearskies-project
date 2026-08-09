# SWAN Whitecapping & Wind Chop Survival — Research Brief

**Created:** 2026-08-07
**Origin:** Webcam comparison at Huntington Beach revealed the beach profile card showing a
4.3s wind chop as the outermost breaker at 98.6m — the cam shows zero chop, only clean
groundswell lines. Diagnostic traced the phantom break to SWAN delivering the 4.3s
partition at 1.24m at the L4 handoff (10.7m depth), amplified 3.3× from its deep-water
reference height of 0.37m. The amplification cannot be explained by shoaling between 15m
and 10.7m for a 4.3s wave (Ks ≈ 1.0 at those depths for that period). SWAN's wind-input
source terms are generating energy the real ocean does not have, and the whitecapping
dissipation formulation is not removing it.

---

## 1. Current SWAN physics configuration

Emitted by `swan_formats.py` (line 1783–1795):

```
GEN3 WESTHUYSEN
BREAKING CONSTANT 1.0 0.73
FRICTION JON 0.038
TRIAD
```

No `WCAPPING` override (uses AB defaults). No `NEGATINP`. No `SSWELL`. No `CDFAC`.

**What each component is:**

- **GEN3 WESTHUYSEN** — third-generation physics: Alves & Banner (2003) saturation-based
  whitecapping + Yan (1987) wind input. SWAN default.
- **WCAPPING AB** (implicit) — Alves & Banner whitecapping with default parameters:
  - C'ds = 5.0E-5 (proportionality coefficient)
  - Br = 1.75E-3 (threshold saturation level)
- **Yan (1987)** wind input — no explicit negative wind-input term; adverse-wind attenuation
  is weak and scales down for low-energy high-frequency bins.
- **NEGATINP** — not present. Without it, SWAN has no mechanism to actively remove spectral
  energy opposing the wind direction; it can only suppress positive wind input.

## 2. The Westhuysen whitecapping formulation and why it fails for wind chop

**Source:** SWAN Scientific/Technical Documentation §3.5 (swanmodel.sourceforge.io); SWAN
User Manual §4.5.4 WCAPPING (local: `docs/reference/swan-user-manual.txt`).

The dissipation source term (Van der Westhuysen et al., 2007; Alves & Banner, 2003):

```
S_ds,break(σ,θ) = −C'ds · [B(k)/Br]^(p/2) · tanh(kh)^((2−p₀)/4) · √(gk) · E(σ,θ)
```

Where B(k) = ∫ cg · k³ · E(σ,θ) dθ is the azimuthal-integrated spectral saturation — a
wavenumber-dependent metric "positively correlated with the probability of wave
group-induced breaking" (SWAN tech doc).

**Two regimes, controlled by B(k) relative to Br:**

| Regime | Condition | Exponent p | Dissipation strength |
|--------|-----------|-----------|---------------------|
| Active breaking | B(k) > Br | p = p₀ (typically 4) | Strong: scales as [B(k)/Br]² |
| Below threshold | B(k) ≤ Br | p = 0 | Residual only: [B(k)/Br]⁰ = 1 — constant, independent of saturation |

**The failure mode for wind chop:** A 4.3s wave at 0.37m deep-water height carries very
little absolute spectral energy E. Its spectral saturation B(k) = ∫ cg·k³·E dθ can fall
below the threshold Br = 1.75E-3. When this happens, the exponent drops to p=0 and
dissipation becomes a weak constant residual — the saturation-based amplification that
would aggressively damp a breaking wave is inactivated. The chop propagates across the
grid with only this weak residual dissipation and bottom friction acting on it.

**The absent negative wind input:** Without `NEGATINP`, when wind opposes or crosses the
chop's propagation direction, SWAN stops adding energy to it (wind input → 0) but does
NOT actively remove energy. The chop coasts through with no source and only the
sub-threshold residual sink. The Yan (1987) wind-input formulation has a weak
adverse-wind term, but it "scales down dramatically" for small-scale high-frequency
noise (per the mechanism analysis).

## 3. Literature verification

### 3.1 Lei et al. (2023) — Optimal Cds calibration

**Citation:** Lei, Z., Wu, W., Gu, Y., Zhai, F., & Li, P. (2023). "A general method to
determine the optimal whitecapping dissipation coefficient in the SWAN model." *Frontiers
in Marine Science*, 10, 1298727. doi:10.3389/fmars.2023.1298727

**Key findings relevant to our problem:**

1. **Optimal Cds range for WST: [0.72E-5, 1.12E-5]** — 14–22% of the default 5.0E-5.
   The default OVER-dissipates across the full spectrum, not under-dissipates. The
   overall effect of WST's saturation-based approach is too aggressive for the spectral
   bulk, leading to systematic underestimation of significant wave height.

2. **"WST exhibits the most pronounced underestimation among the evaluated schemes"** —
   at the optimal Cds, Slope (simulated/observed SWH ratio) is consistently below 1.0
   for all seasons and years.

3. **"The overall simulation performance of KOMEN and JANSSEN surpasses that of WST"** —
   WST only achieves d-index above 0.90 in winter; KOMEN and JANSSEN exceed 0.90 in
   most seasons.

4. **The optimal Cds is wind-field-dependent** — "the optimal Cds value shows a
   one-to-one correspondence with the applied wind field." This means the correct Cds
   depends on the wind forcing quality (ERA5, HRRR, GFS) and cannot be universally
   fixed.

**Critical implication:** Raising Cds (as Gemini recommended: 5.0E-5 → 7.5E-5) would
worsen the already-pronounced SWH underestimation. The Cds parameter is
FREQUENCY-INDEPENDENT — it cannot be tuned to selectively increase chop dissipation
without proportionally increasing groundswell dissipation. **Tuning Cds and Br within
the WST scheme cannot fix the chop survival problem without degrading swell accuracy.**

### 3.2 Rapizo et al. (2019) — WST vs Komen in wind-sea environments

**Citation:** Rapizo, H., Durrant, T. H., & Babanin, A. V. (2019). "Predicting ocean
waves along the US east coast during energetic winter storms: sensitivity to whitecapping
parameterizations." *Ocean Science*, 15, 691–715. doi:10.5194/os-15-691-2019

**Key findings:**

1. In a pure wind-sea environment (US east coast, January 2009, dominant westerly winds),
   **Komen outperformed WST** for both wave height (bias 0.19m vs 0.33m) and mean period.

2. **WST "significantly underestimated wave periods across all four buoys"** — consistent
   with Lei et al.'s finding of systematic underestimation.

3. Despite using identical wind forcing, Komen produced "larger sum of source terms at the
   peak frequency" — more effective energy transfer at the spectral peak.

### 3.3 Rogers et al. (2012) — ST6 observation-consistent physics

**Citation:** Rogers, W. E., Babanin, A. V., & Wang, D. W. (2012).
"Observation-Consistent Input and Whitecapping Dissipation in a Model for Wind-Generated
Surface Waves." *Journal of Atmospheric and Oceanic Technology*, 29(9), 1329–1346.
doi:10.1175/JTECH-D-11-00092.1

**Key features relevant to our problem:**

1. ST6 wind input includes explicit **positive AND adverse (negative)** components.
   The adverse component scales with friction velocity and actively removes energy from
   spectral bins opposing the wind — the mechanism absent in our configuration.

2. Designed to work with `SSWELL ZIEGER` (non-breaking swell dissipation) and `NEGATINP`
   (negative wind input activation, recommended rdcoef=0.04 per SWAN manual).

3. The whitecapping formulation uses four tunable parameters (a1sds, a2sds, p1sds, p2sds)
   that independently control local and cumulative dissipation terms — more degrees of
   freedom than WST's single Cds.

### 3.4 SWAN User Manual (local) — Command syntax

**Source:** `docs/reference/swan-user-manual.txt` §4.5.4

**WCAPPING AB syntax (positional, NOT keyword=value):**

```
WCAPPING AB [cds2] [br]
```

Where `[cds2]` = C'ds proportionality coefficient (default 5.0E-5), `[br]` = threshold
saturation Br (default 1.75E-3). Gemini's syntax `GEN3 WESTHUYSEN br=0.0014 cds=7.5e-5`
is **invalid SWAN syntax** — SWAN uses positional parameters.

**GEN3 ST6 syntax:**

```
GEN3 ST6 [a1sds] [a2sds] [p1sds] [p2sds] UP HWANG AGROW
SSWELL ZIEGER [b1]
NEGATINP [rdcoef]
```

Example from the SWAN manual:

```
GEN3 ST6 5.7E-7 8.0E-6 4.0 4.0 UP HWANG U10PROXY 28.0 AGROW
SSWELL ZIEGER 0.00025
NEGATINP 0.04
```

### 3.5 Van der Westhuysen et al. (2007) — Original WST paper

**Citation:** Van der Westhuysen, A. J., Zijlema, M., & Battjes, J. A. (2007).
"Nonlinear saturation-based whitecapping dissipation in SWAN for deep and shallow water."
*Coastal Engineering*, 54(2), 151–170. doi:10.1016/j.coastaleng.2006.08.006

Introduced the saturation-based whitecapping to "remove the dependence on mean spectra,
increasing its suitability for nearshore applications." The formulation divides dissipation
into breaking (B(k) > Br, exponent p₀) and non-breaking (B(k) ≤ Br, exponent 0) regimes.

## 4. Measured evidence from this system

| Measurement | Value | Source |
|-------------|-------|--------|
| Wind swell Hs at deep-water ref (15m, L2) | 0.37m (1.21 ft) | Live API `spectralComponents[0]`, 2026-08-07 |
| Wind swell Hs at L4 handoff (10.7m) | 1.24m | Live API `perPartitionBreaks[0].heightM` |
| Amplification ratio (15m → 10.7m) | 3.3× | Computed |
| Expected shoaling Ks (15m → 10.7m, T=4.3s) | ≈1.0 (deep water at both depths) | Linear wave theory |
| Wind swell breaks at | 98.6m from shore, depth 3.44m | Live API `breakPoints[0]` |
| Webcam shows | Zero chop; clean glassy groundswell lines | Surfcam screenshot, 2026-08-07 11:47am |
| 19.3s groundswell at handoff | 0.88m | Live API `perPartitionBreaks[2].heightM` |
| 19.3s groundswell break position | 10.2m from shore, depth 1.79m | Live API `breakPoints[2]` (when present) |
| SWAN physics package | GEN3 WESTHUYSEN (AB defaults) | `swan_formats.py:1784` |
| NEGATINP | Not present | `swan_formats.py:1783-1795` (exhaustive) |
| Bottom friction | JONSWAP 0.038 m²/s³, uniform all frequencies | `swan_formats.py:1792` |

## 5. Diagnosis

The 4.3s wind chop survives from the WW3 boundary through all four SWAN grid levels to
the handoff because of three compounding failures:

1. **Sub-threshold saturation.** The chop's spectral saturation B(k) falls below Br =
   1.75E-3, dropping the whitecapping exponent to p=0 (residual-only dissipation). The
   active breaking dissipation mechanism is not engaged for this spectral bin.

2. **No negative wind input.** Without `NEGATINP`, SWAN has no mechanism to actively
   remove energy from spectral bins whose propagation direction opposes or crosses the
   wind. The Yan (1987) wind input's own adverse term is too weak for low-energy
   high-frequency components.

3. **Frequency-independent Cds.** The WST Cds parameter controls dissipation uniformly
   across all frequencies. It cannot be raised to kill the chop without proportionally
   increasing dissipation on the groundswells — which the system already underestimates
   (Lei et al., 2023: WST has "the most pronounced underestimation" of SWH).

## 6. Fix options evaluated

### Option A: Tune WST parameters (Br, Cds)

Lower Br to engage active breaking at lower saturation levels; raise Cds to increase
dissipation strength once engaged.

**Verdict: NOT RECOMMENDED.** Lei et al. (2023) showed the default Cds already
OVER-dissipates overall; the optimal range is 0.72–1.12E-5 (14–22% of default). Raising
Cds worsens groundswell underestimation. Lowering Br alone may help for chop but has
unknown effects on the swell-frequency regime — no published study isolates Br tuning
for selective high-frequency suppression. The Cds parameter is frequency-independent —
it cannot selectively increase chop dissipation without proportionally increasing
groundswell dissipation.

### Option B: Switch ALL levels to GEN3 ST6 + NEGATINP + SSWELL ZIEGER

Replace the entire physics package on all grid levels with the Rogers et al. (2012)
observation-consistent formulation.

**Verdict: NOT RECOMMENDED (compute cost).** ST6 adds approximately 60% wall-clock time
(CDIP report). Applied to all four grid levels this is operationally blocking for a
hobbyist deployment. See Option D for the scoped variant.

### Option C: Keep WST, add NEGATINP alone

The SWAN manual states `NEGATINP` is "intended only for use with non-breaking swell
dissipation SSWELL ZIEGER." Using it with WST is undocumented. Additionally, NEGATINP
may be code-gated to the ST6 wind-input pathway in SWAN's source — the Yan (1987) wind
input used by WESTHUYSEN is a separate code path that may not hook into the NEGATINP
command. **Not recommended — undocumented interaction, possible silent no-op.**

### Option D: ST6 on L1 only — RECOMMENDED

**Apply GEN3 ST6 + NEGATINP + SSWELL ZIEGER on Level 1 only.** Levels 2, 3, and 4
remain on GEN3 WESTHUYSEN unchanged.

**Rationale:** The WW3 boundary chop enters at L1 (the shelf-edge grid). ST6's negative
wind input (NEGATINP) kills the chop as it propagates across L1 under offshore/cross-
shore wind conditions. By the time the spectrum reaches L2 via BOUNDNEST1, the chop is
already dissipated. L2/L3/L4 never see it. The nearshore physics (where WESTHUYSEN's
saturation-based approach is designed to work) are completely unchanged.

**Compute cost:**

Measured grid sizes (librewxr, 2026-08-07):

| Level | Grid cells (MCGRD) | % of total | Physics |
|-------|-------------------|-----------|---------|
| L1 | 1,065 | **5.8%** | ST6 + NEGATINP + SSWELL ZIEGER |
| L2 | 6,151 | 33.2% | WESTHUYSEN (unchanged) |
| L3 | 2,445 | 13.2% | WESTHUYSEN (unchanged) |
| L4 | 8,841 | **47.8%** | WESTHUYSEN (unchanged) |

A 60% compute increase on 5.8% of total cells = **~3–4% total compute increase.**
Negligible for any deployment.

**Why mixed-physics nesting is safe:** Each SWAN grid level runs as a separate SWAN
execution with its own INPUT file. Level 2 reads Level 1's output via BOUNDNEST1 —
a spectral boundary condition that is physics-agnostic. The inner grid applies its own
physics to whatever spectrum it receives. This is the same mechanism used in WW3→SWAN
nesting (entirely different models), which is standard operational practice worldwide.
SWAN→SWAN nesting with different physics packages within the same model is a simpler
case of the same principle — the boundary is a spectrum, not a source term.

**SWAN INPUT for L1 (replacing current GEN3 WESTHUYSEN):**

```
GEN3 ST6 4.7E-7 6.6E-6 4.0 4.0 UP HWANG VECTAU U10PROXY 28.0 AGROW
SSWELL ZIEGER 0.00025
NEGATINP 0.04
```

Parameters from the SWAN manual's own recommended calibration (§4.5.4, first example).
`NEGATINP 0.04` is the manual's recommended value (Zieger et al., 2015). All other
physics commands (`BREAKING CONSTANT 1.0 0.73`, `FRICTION JON 0.038`, `TRIAD`) remain
unchanged on L1.

**L2/L3/L4 INPUT files:** No change whatsoever. They continue to emit `GEN3 WESTHUYSEN`
and the same physics block they have today.

**What this fixes:**
- The 4.3s wind chop (0.112m Hs at the WW3 boundary) is dissipated by ST6's negative
  wind input as it crosses L1 under offshore/cross-shore winds. It does not reach L2.
- The groundswell (13.1s, 19.3s from SSW) propagates WITH the dominant wave direction —
  NEGATINP does not penalize aligned swell. Groundswell energy reaches L2 unchanged.
- On onshore-wind days when the chop IS real, ST6's positive wind input is
  observation-consistent (Rogers et al., 2012) and correctly maintains the wind sea.

**What this does NOT fix:**
- Any chop generated by SWAN's own wind input INSIDE L2/L3/L4 from the HRRR wind field.
  However, the fetch across L2 (~3 km at 100m resolution, 75 cells) is very short — too
  short for significant wind-sea generation from scratch. The L1 boundary is where the
  chop enters, and that's where ST6 kills it.

**Risks:**
- ST6 parameters (a1sds=4.7E-7, a2sds=6.6E-6) are the SWAN manual's published defaults,
  not regionally calibrated for Southern California. However, L1 is a coarse (1 km)
  shelf-scale grid where regional bathymetric detail doesn't matter — it's doing
  open-ocean propagation, which is what these defaults were calibrated for.
- The DIA quadruplet interaction approximation's frequency-resolution requirement
  (df/f ≈ 0.1) applies to ST6 as well as WESTHUYSEN. Our current spectral grid (34 bins,
  df/f ≈ 0.109) meets this requirement for both packages — no spectral grid change needed.

**Validation plan (before production deployment):**
1. Run one full 72h cycle with L1 on ST6, L2/L3/L4 on WESTHUYSEN.
2. Compare the L2 deep-water reference spectrum at 15m: the 4.3s wind-swell partition
   should be substantially reduced or absent under offshore/cross-shore wind hours.
3. Compare the groundswell partitions (13.1s, 19.3s) at the same point: should be
   unchanged (within 5%) from a WESTHUYSEN-only run.
4. Compare total Hs against NDBC buoy 46222 (the nearest boundary station at 487.9m
   depth) — ST6 should not degrade the bulk Hs accuracy.
5. Webcam reality gate: the beach profile card should show groundswell breaks only,
   no phantom chop break, on a clean/glassy day.

### Option E: Post-SWAN wind-sea partition gate (fallback)

If Option D proves insufficient (e.g., SWAN internally generates chop on L2/L3/L4 from
the HRRR wind despite no boundary seed), a conditional gate in the SwellTrack pipeline
(`surf_1d_pipeline.py`) suppresses the `is_wind_sea` partition when the onshore wind
component is ≤ 0:

```
onshore_component = wind_speed * cos(wind_dir - beach_facing)
if partition.is_wind_sea AND onshore_component <= 0:
    skip this partition
```

Zero compute cost. The pipeline already has `is_wind_sea`, `wind_dir_deg`, and
`beach_facing`. This is a safety net for residual chop that survives past L1, not a
replacement for fixing the physics at the source. Can be deployed independently of or
alongside Option D.

## 7. Minimum surfable period — the 5-second floor (operator ruling 2026-08-07)

### 7.1 Research findings: wave period and surfability

The surf forecasting community has a clear, source-convergent consensus on period
thresholds for surfability:

| Period | Classification | Surfability | Sources |
|--------|---------------|-------------|---------|
| 1–4s | Wind chop | **Not surfable** — disorganized, no wave shape | Surfology [11], Mundo Surf [12], GetFoamie [13] |
| 5–6s | Wind swell | **Marginal** — "if you're eager, you might catch something" | Surfology [11], Bali Surfing Camp [14] |
| 7–9s | Short-period swell | **Surfable but weak** — depends on the break | Mundo Surf [12], GetFoamie [13] |
| 10s+ | Swell / groundswell | **Reliably surfable** — clean, organized sets | All sources |
| 12s+ | Groundswell | **Quality surf** — long sets, good shape | Surfology [11], Bali Surfing Camp [14] |

**Great Lakes exception confirms the floor, not lowers it.** Great Lakes surfing runs
almost entirely on wind swell — 5–6s typical, 7–8s on exceptional days (Surfer Today
[15], Red Bull [16]). There is no groundswell on a lake. Wind swell IS the surf there —
but it is still 5–6s minimum, never 4s. A 4-second wave is chop everywhere, even on
fetch-limited bodies.

**No published surf forecast service reports sub-5s energy as surf height.** Surfline's
LOTUS model reports face height "where the wave is peaking and breaking" (Surfline [17]).
Surf-forecast.com tracks "wind waves" separately from swell and describes them as "chop
that on occasion can ruin the shape of waves" (Surf-forecast.com FAQ [18]). Neither
includes sub-5s energy in the headline surf height range.

### 7.2 The three-layer treatment (operator-approved 2026-08-07)

| Layer | Sees chop (T < 5s)? | Why |
|-------|-------------------|-----|
| **SWAN** (L1–L4) | YES — processes all frequencies | SWAN needs the full spectrum for correct energy balance, quadruplet interactions, and wind-input/dissipation source terms. Artificial spectral cutoffs corrupt the physics. ST6 on L1 kills the chop when the physics says it should die. |
| **SwellTrack** (1D surf model) | **NO — hard 5s floor.** Partitions with Tp < 5s are not passed to `run_1d_analytical()`. They produce no break points, no face heights, no beach profile visualization. | Sub-5s energy is not surfable. It does not produce rideable waves at any break type. Processing it creates phantom breaks that mislead the display. Even if it survives SWAN (legitimately, on a strong onshore day), it belongs in the conditions score, not the surf zone model. |
| **Surf scorer** | YES — chop degrades the conditions score | If there is 4s wind chop making the surface choppy, that is real information about surf quality. The scorer already uses wind speed/direction for the conditions factor. The chop partition, when present, carries signal about surface texture that should penalize the score. The chop hurts conditions; it just does not produce rideable waves. |

### 7.3 Surf height as a range, not a single number (operator ruling 2026-08-07)

**The combined face height (RSS combination of per-partition face heights at one point)
is RETIRED as a reported quantity.** It is a statistical abstraction that does not
correspond to any physical wave a surfer would ride. Individual swells break at different
locations along the transect; combining their energies at one artificial point produces a
number nobody standing on the beach would observe.

**Replacement: a height RANGE (min–max) derived from qualifying swell partitions'
individual face heights.** The range reflects what a surfer actually sees — the smallest
and largest surfable waves breaking at the spot this hour:

- **Min** = the smallest face height among qualifying (T ≥ 5s) swell partition break
  points on the representative transect.
- **Max** = the largest face height among the same set.
- When only ONE qualifying partition breaks: min = max (a single height, not a range).
- When ZERO qualifying partitions break: report flat / no surf.

This matches the reporting convention used by Surfline ("2–3 ft"), surf-forecast.com,
and every other consumer surf forecast.

## 8. Recommendation

**Three complementary measures, each independently valuable:**

1. **Option D (ST6 on L1 only)** — fixes the physics at the source. Kills boundary chop
   via negative wind input. ~3–4% compute increase.

2. **Option E (post-SWAN wind-direction gate)** — safety net. Suppresses the wind-sea
   partition under offshore/cross-shore wind even if it survives SWAN. Zero compute cost.

3. **The 5-second floor** — hard cutoff in SwellTrack. No partition with Tp < 5s enters
   the 1D model, regardless of source, direction, or height. Prevents phantom breaks from
   any non-surfable energy that makes it through the upstream layers. Zero compute cost.
   Does NOT apply to the surf scorer, which continues to see all partitions for conditions
   grading.

4. **Surf height as a range** — replaces the combined face height with min–max of
   qualifying partition face heights. Presentation change only; no physics change.

All require operator approval (trigger 1 for items 1–3; the range is a data-contract
change for item 4).

## References

1. Alves, J. H. G. M., & Banner, M. L. (2003). Performance of a saturation-based
   dissipation-rate source term in modeling the fetch-limited evolution of wind waves.
   *J. Phys. Oceanogr.*, 33, 1274–1298.

2. Day, J. C., & Dietrich, J. C. (2022). Improved wave predictions with ST6 Physics
   and ADCIRC+SWAN. *Shore & Beach*, 90(3). NCSU Coastal & Computational Hydraulics
   Team. https://ccht.ccee.ncsu.edu/sb-2022-st6/

3. Lei, Z., Wu, W., Gu, Y., Zhai, F., & Li, P. (2023). A general method to determine
   the optimal whitecapping dissipation coefficient in the SWAN model. *Front. Mar. Sci.*,
   10, 1298727. doi:10.3389/fmars.2023.1298727

4. Rapizo, H., Durrant, T. H., & Babanin, A. V. (2019). Predicting ocean waves along
   the US east coast during energetic winter storms: sensitivity to whitecapping
   parameterizations. *Ocean Science*, 15, 691–715. doi:10.5194/os-15-691-2019

5. Rogers, W. E., Babanin, A. V., & Wang, D. W. (2012). Observation-Consistent Input
   and Whitecapping Dissipation in a Model for Wind-Generated Surface Waves.
   *J. Atmos. Ocean. Tech.*, 29(9), 1329–1346. doi:10.1175/JTECH-D-11-00092.1

6. Van der Westhuysen, A. J., Zijlema, M., & Battjes, J. A. (2007). Nonlinear
   saturation-based whitecapping dissipation in SWAN for deep and shallow water.
   *Coastal Eng.*, 54(2), 151–170. doi:10.1016/j.coastaleng.2006.08.006

7. Zieger, S., Babanin, A. V., Rogers, W. E., & Young, I. R. (2015). Observation-based
   source terms in the third-generation wave model WAVEWATCH. *Ocean Modelling*, 96,
   2–25. doi:10.1016/j.ocemod.2015.07.014

8. CDIP, Scripps Institution of Oceanography. A Cost Benefit Analysis of SWAN with
   Source Term Package ST6.
   https://cdip.ucsd.edu/themes/media/docs/publications_references/reports/A_Cost-Benefit_Analysis_of_SWAN_with_Source_Team_Package_ST6.pdf

9. SWAN User Manual, Cycle III version 41.51. §4.5.4 WCAPPING, §4.5.4 NEGATINP,
   §4.5.4 GEN3. Local: `docs/reference/swan-user-manual.txt`.

10. SWAN Scientific/Technical Documentation, Cycle III version 41.51. §3.5 Dissipation
    of wave energy. swanmodel.sourceforge.io/download/zip/swantech.pdf

11. Surfology (2024). "Understanding Wave Period — Definition with Examples."
    https://surfology.blog/wave-period/

12. Mundo Surf. "The wave period: What it is, How to read It, and its impact on Surfing."
    https://www.mundo-surf.com/en/blog/general/the-wave-period-what-it-is-how-to-read-it-and-its-impact-on-surfing/

13. GetFoamie. "What Does Wave Period Mean?"
    https://getfoamie.com/what-does-wave-period-mean/

14. Padang Padang Surf Camp. "Surfer's guide to Wave period."
    https://www.balisurfingcamp.com/blog/wave-period/

15. Surfer Today. "Surfing the Great Lakes: when, where and how."
    https://www.surfertoday.com/surfing/the-ultimate-guide-to-surfing-the-great-lakes

16. Red Bull. "Surfing the Great Lakes — Top Spots, Forecasting & more."
    https://www.redbull.com/au-en/surfing-the-great-lakes-canada-guide

17. Surfline. "Surfline's Rating of Surf Heights."
    https://www.surfline.com/surf-news/surfline-s-rating-of-surf-heights/120143

18. Surf-forecast.com. "FAQs."
    https://www.surf-forecast.com/pages/faq
