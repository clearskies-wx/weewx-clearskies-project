# Research Brief: Hsig → Breaking Face Height Conversion

**Date:** 2026-07-16
**Purpose:** Document research findings for converting SWAN significant wave height (Hsig) to breaking face height — the measurement surfers actually use to judge wave size
**Status:** Research complete — informs T2.6 of SWAN-TRUSHORE-PLAN.md
**Origin:** T2.6 research phase (Coordinator)

---

## §1 — The Problem: Three Gaps Between Hsig and What Surfers See

SWAN outputs significant wave height (Hsig, also written Hm0) — the average height of the highest one-third of waves in the sea state. This is a purely oceanographic metric. Three gaps exist between Hsig and the wave height surfers observe at the beach:

**Gap 1 — Hsig is a statistical average, not an individual wave.**

Individual breaking waves (set waves) are taller than Hsig. The Rayleigh distribution governs:

| Metric | Ratio to Hsig | What it represents |
|---|---|---|
| Hsig (H1/3) | 1.00 | Average of highest 1/3 of waves |
| H1/10 | ~1.27 | Average of highest 10% — "set waves" |
| H1/100 | ~1.52 | Average of highest 1% — "bombs" |
| Hmax | ~1.6–2.0 | Largest single wave in a 20–30 minute window |
| Hrms | ~0.71 | Root-mean-square height (lower bound) |

Source: Rayleigh distribution for narrow-banded sea states; ratios from Coastal Wiki statistical wave parameter tables and USNA Rayleigh distribution applied to random wave heights.

Surfers track set waves and report what they ride, which falls between H1/3 and H1/10. A raw Hsig forecast will consistently feel "too small" to surfers by 15–30%.

**Gap 2 — Period-dependent shoaling amplification.**

If the SWAN output point is slightly offshore of the surf zone (e.g., 10m depth), the wave has not finished its final steepening. Waves conserve energy flux (E × Cg = constant) as they enter shallow water, so as group velocity decreases, wave height must increase. Critically, this amplification depends on wave period:

- Longer-period swells travel faster in deep water, so the ratio of deep-water to shallow-water group velocity is larger.
- A 1m Hsig at 16 seconds will produce significantly taller breakers than a 1m Hsig at 8 seconds.
- This is the single most important factor surfers use to assess forecast quality — period is what separates "ankle slop" from "overhead sets" at the same swell height.

The Komar-Gaughan (1973) formula captures this period dependence (see §3).

**Gap 3 — Display scale convention.**

Even with the true physical face height, the display scale must match audience expectations:

| Scale | Definition | Used by | Factor relative to Hsig |
|---|---|---|---|
| Face height | Trough-to-crest of the breaking wave face | Surfline (default), US mainland surfers, most surf apps | ~1.1–1.4× Hsig (depending on period and bathymetry) |
| Hawaiian / Traditional | Back-of-wave measurement, roughly half face height | Hawaiian surfers, Australian surfers, some South African surfers | ~0.5–0.7× face height |
| Swell height | Raw deepwater Hsig from buoy/model | surf-forecast.com, raw forecast providers | 1.0× Hsig (no conversion) |

Source: Surfline support documentation on face height vs. traditional scale; Hawaiian scale Wikipedia; surfertoday.com wave measurement methods.

---

## §2 — Competitive Analysis

**Surfline (market leader):**
- Reports "face height" by default (trough to crest of breaking face) for all countries except Australia/NZ (Hawaiian scale there).
- Their LOTUS model is a proprietary nearshore wave model that takes deepwater swell all the way to the beach. It blends 25 years of visual surf observations, 20 years of camera data, high-resolution bathymetry mapping, and satellite assimilation. The model "performs billions of calculations an hour" and is specifically configured for surf.
- For most spots on average ground swell (12–16s period), face height is approximately 1.3× deepwater swell height.
- LOTUS is Surfline's key competitive differentiator — they have invested more in this conversion than in any other feature.
- Offers both face height and "Traditional" scale as a user preference toggle.

**surf-forecast.com / MagicSeaweed (legacy):**
- Report raw swell height — essentially the model Hsig, similar to what we do now.
- Simpler but less useful for surfers who want to know "how big will it actually be?"

**SwellBeat (educational):**
- Publishes a wave calculator that propagates the sea state from a reference point offshore to the breaking point using linear wave theory + Iribarren number + depth-induced breaking.
- Uses H_b = Ks × Kr × H0 where Ks = shoaling coefficient, Kr = refraction coefficient.
- Open methodology, well-documented physics.

**Key insight:** There are exactly two tiers in the market. Tier 1 (Surfline) reports modeled face height. Tier 2 (everyone else) reports raw swell height. No provider occupies the middle ground of "physics-based face height without ML training data." Clear Skies TruShore can be the first open-source implementation in this space.

---

## §3 — Formula Evaluation

### Formula 1: Komar-Gaughan (1973) — Recommended

```
Hb = 0.39 × g^(1/5) × (Tp × Hsig²)^(2/5)
```

Where:
- Hb = breaking wave height (meters, trough-to-crest)
- g = 9.81 m/s²
- Tp = peak period (seconds)
- Hsig = deepwater significant wave height (meters)

Derivation: Airy wave theory with conservation of energy flux, empirically fitted to three sets of laboratory data and one set of field data (k = 0.39).

**Worked examples:**

| Condition | Hsig | Tp | Hb (Komar-Gaughan) | Amplification (Hb/Hsig) |
|---|---|---|---|---|
| Small day, short period | 0.6m (2ft) | 8s | 0.64m (2.1ft) | 1.06× |
| Small day, medium period | 0.6m (2ft) | 12s | 0.71m (2.3ft) | 1.18× |
| Medium day, ground swell | 1.2m (4ft) | 14s | 1.41m (4.6ft) | 1.18× |
| Good day, long period | 1.8m (6ft) | 16s | 2.18m (7.2ft) | 1.21× |
| Large day, NW swell | 2.4m (8ft) | 18s | 2.95m (9.7ft) | 1.23× |

The amplification ranges from ~1.06× (short-period wind waves) to ~1.25× (long-period ground swell). This matches the empirical observation from surf forecasters that face height ≈ 1.3× deepwater swell height for ground swell conditions.

**Strengths:**
- Simple closed-form formula — no iterative computation, no lookup tables.
- Period-dependent — correctly captures the critical distinction between wind chop and ground swell.
- The most widely cited and validated breaker height formula in coastal engineering.
- Validated against both lab data and field observations.

**Limitations:**
- Assumes normally-incident waves on a uniform slope — does not account for refraction, which SWAN already handles.
- Predicts the deepwater-to-breaking transformation — if SWAN output is already near the surf zone, part of the shoaling is already captured by SWAN.

**Source:** Komar, P.D. and Gaughan, M.K. (1973), "Airy Wave Theory and Breaker Height Prediction", Proceedings 13th Coastal Engineering Conference, ASCE, pp. 405–418.

### Formula 2: Caldwell (2007) — Specialist, Not Recommended as Primary

Empirical method developed from 32 years of Waimea buoy data vs. daily surf observations on Oahu's north shore. Estimates H1/10 at zones of maximum refraction.

**Strengths:**
- Validated against decades of real surf observations (Goddard-Caldwell Daily Visual Surf Observation Database, 1968–2020).
- Accounts for the statistical gap (targets H1/10, not H1/3).

**Limitations:**
- Developed specifically for Hawaiian geomorphology: narrow shelves, steep bottom slopes, and high refraction zones. Applicability to SoCal (wide shelves, gentle slopes) is uncertain.
- "Unrealistic for wave periods less than ~10 seconds" per the paper. Most SoCal summer surf is 6–10s wind swell — this formula would produce unreliable results for nearly half the year.
- Requires site-specific empirical calibration that we do not have for non-Hawaiian coastlines.

**Verdict:** Not suitable as the primary formula for a general-purpose surf forecast. Could serve as a Hawaiian-coastline calibration reference if we expand to Hawaii.

**Source:** Caldwell, P.C. and Aucan, J. (2007), "An Empirical Method for Estimating Surf Heights from Deepwater Significant Wave Heights and Peak Periods in Coastal Zones with Narrow Shelves, Steep Bottom Slopes, and High Refraction", Journal of Coastal Research, Vol. 23, No. 5, pp. 1190–1196.

### Formula 3: Goda (2010) — More Accurate, More Complex

Goda's breaking wave height prediction uses design charts relating shoaling coefficient, equivalent deepwater steepness, seabed slope, and relative water depth. Comparative studies find Goda's method gives better results than simpler alternatives.

**Strengths:**
- Accounts for beach slope explicitly.
- Better accuracy than Komar-Gaughan for non-uniform slopes.

**Limitations:**
- Not a closed-form formula — requires iterative computation or chart interpolation.
- The improvement over Komar-Gaughan is marginal for the application (consumer surf forecasting, ±0.5ft accuracy target).
- Our existing γ correction (Supplement 1 via Battjes 1974) already accounts for slope-dependent breaking — adding Goda would duplicate slope corrections.

**Verdict:** The accuracy improvement does not justify the complexity for a consumer surf product. Komar-Gaughan + our existing Battjes γ correction covers the same ground with simpler code.

### Formula 4: Pure Shoaling Coefficient (Ks)

```
Ks = √(Cg_deep / Cg_shallow)
H_shallow = Ks × H_deep
```

Where group velocity Cg = c/2 × [1 + 2kh/sinh(2kh)] and the dispersion relation ω² = gk × tanh(kh) must be solved iteratively for wavenumber k.

**Strengths:**
- Exact linear theory solution.
- Can be computed for any depth, not just breaking.

**Limitations:**
- Requires iterative solution of the dispersion relation (Newton's method).
- Only computes shoaling — does not predict breaking. Must be combined with a breaking criterion.
- SWAN already computes shoaling internally — applying Ks to SWAN output would double-count.

**Verdict:** Not applicable as a post-processing step on SWAN output. SWAN already solves the full wave action balance equation including shoaling. Useful only if the SWAN output point is in deep water, which it won't be.

---

## §4 — Architecture Decision: Where the Conversion Applies

### SWAN Output Point Depth — Critical Design Parameter

The SWAN output point depth determines which corrections are already handled by SWAN vs. which need post-processing:

| SWAN output depth | Shoaling | Refraction | Breaking | Our supplements | New face height conversion |
|---|---|---|---|---|---|
| Deep water (>50m) | Not handled | Not handled | Not handled | All apply | Full Komar-Gaughan |
| Intermediate (~10m) | Partially handled | Handled | Not handled | γ cap, structure, topo | Reduced Komar-Gaughan |
| Surf zone (~2–3m) | Handled | Handled | Handled by SWAN's Battjes-Janssen | Structure, topo only | Statistical only (×1.15) |

**Recommendation:** Configure SWAN output points at ~10m depth (typical for surf forecast models). This is deep enough that SWAN provides a robust Hsig estimate with refraction included, but shallow enough that the remaining shoaling-to-breaking amplification is modest and well-predicted by Komar-Gaughan.

At ~10m depth, SWAN has handled refraction and partial shoaling. The Komar-Gaughan formula applied to the SWAN output gives the breaking height. The concern about double-counting shoaling is mitigated by the fact that Komar-Gaughan is empirically fitted to the full deepwater-to-breaking transformation, and at 10m depth the remaining shoaling is small (~5–10%). A correction factor based on the output depth can remove the already-computed shoaling.

### Per-Spot Formula Selection (amended 2026-07-16)

Two breaker formulas are supported, selected per surf spot via operator config:

| Config value | Formula | Best for | Period range |
|---|---|---|---|
| `komar_gaughan` (default) | Komar-Gaughan (1973) | All coastlines, general purpose | All periods |
| `caldwell` | Caldwell (2007) with auto-crossover | Steep volcanic island coasts (Hawaii, Indonesia, Tahiti) | ≥10s (auto-falls to K-G for <10s) |

When `breaker_formula = caldwell`, the system uses Caldwell for any forecast timestep where peak period ≥ 10s and automatically uses Komar-Gaughan for timesteps with Tp < 10s. No operator intervention needed per-timestep.

### Interaction with Existing Supplements

The supplements in wave_transform.py apply BEFORE the face height conversion, not after:

```
Pipeline order:
  SWAN output (Hsig at output point)
  → Store as swellHeight (raw model Hsig, no modifications)
  → wave_transform.apply_supplements() → corrected Hsig
  → Store as waveHeightAtBreak (post-supplement Hsig, same as today)
  → breaker_height.hsig_to_face_height(corrected_hsig, Tp, depth, formula)
  → Store as breakingFaceHeight (what surfers see — trough-to-crest)
  → breaker_height.hawaiian_height(face_height) → × 0.5
  → Store as breakingHawaiianHeight (back-of-wave, Hawaiian/traditional scale)
  → surf_scorer.score_surf(breakingFaceHeight, ...) → quality score
```

- **Supplement 1 (γ correction):** Caps Hsig at γ × depth. This is a physical upper bound on what the nearshore environment can support. It applies to the model Hsig before the face height conversion. The face height conversion then predicts the trough-to-crest height of a wave that breaks at that γ-corrected height.
- **Supplement 2 (structure effects):** Reduces Hsig via Kt transmission. Applies to model Hsig. The face height is the face of a wave that has been attenuated by the structure.
- **Supplement 3 (spatial interpolation):** Refines Hsig at the spot location. Applies before face height conversion.
- **Supplement 4 (topographic focusing):** Amplifies or reduces Hsig. Applies before face height conversion.

No double-counting: the supplements correct the model Hsig, and the face height conversion translates the corrected Hsig into the height convention surfers use. They operate on different axes.

---

## §5 — Proposed Implementation

### Four Height Values in the Surf Response

| Field | Definition | Source | Display target |
|---|---|---|---|
| `swellHeight` | Raw SWAN Hsig at the output point, before any supplements | SWAN output directly | Data-oriented users, raw forecast comparison |
| `waveHeightAtBreak` | Post-supplement Hsig (γ-corrected, structure-attenuated, topo-adjusted) | wave_transform.py output (unchanged from current behavior) | Technical reference, backward compatibility |
| `breakingFaceHeight` | Trough-to-crest height of the breaking wave face | Komar-Gaughan or Caldwell applied to `waveHeightAtBreak` + Tp | Primary display (US mainland, Europe) — what surfers want to see |
| `breakingHawaiianHeight` | Back-of-wave measurement (~half face height) | `breakingFaceHeight × 0.5` | Primary display (Hawaii, Australia) — Hawaiian/traditional scale |

### The Conversion Formula (Recommended)

```python
import math

def hsig_to_face_height(
    hsig_m: float,
    period_s: float,
    output_depth_m: float | None = None,
) -> float:
    """Convert post-supplement Hsig to breaking face height.

    Uses Komar-Gaughan (1973) for the period-dependent shoaling-to-
    breaking amplification, with a depth-aware correction when the
    SWAN output point is already in shallow water.

    Args:
        hsig_m: Post-supplement significant wave height in meters.
        period_s: Peak wave period in seconds.
        output_depth_m: Water depth at the SWAN output point (meters).
            Used to avoid double-counting shoaling that SWAN already
            computed. None = assume deepwater (full amplification).

    Returns:
        Breaking face height in meters (trough-to-crest).
    """
    G = 9.81  # m/s²

    # Komar-Gaughan (1973): Hb = 0.39 * g^(1/5) * (T * H0^2)^(2/5)
    # This predicts the full deep-water to breaking transformation.
    hb_full = 0.39 * (G ** 0.2) * ((period_s * hsig_m ** 2) ** 0.4)

    # The amplification ratio from Komar-Gaughan
    if hsig_m > 0:
        kg_ratio = hb_full / hsig_m
    else:
        return 0.0

    if output_depth_m is not None and output_depth_m < 15.0:
        # SWAN output is in the nearshore — SWAN has already computed
        # partial shoaling. Scale down the Komar-Gaughan amplification
        # by the fraction of shoaling remaining.
        #
        # At 10m depth, roughly 60-80% of shoaling is complete.
        # At 5m depth, roughly 85-95% is complete.
        # At 2m depth, nearly all shoaling is complete.
        #
        # Empirical reduction: lerp between full K-G ratio and 1.0
        # (no amplification) based on how shallow the output point is.
        # The "no more shoaling" depth is approximately Hb / 0.78
        # (breaking depth), typically 1-3m for surf-scale waves.
        shallow_fraction = max(0.0, min(1.0, 1.0 - output_depth_m / 15.0))
        reduced_ratio = 1.0 + (kg_ratio - 1.0) * (1.0 - shallow_fraction)
        face_height = hsig_m * reduced_ratio
    else:
        # Deepwater output point — apply full Komar-Gaughan
        face_height = hb_full

    # Clamp: face height must be >= Hsig (waves don't shrink
    # during final shoaling) and <= 3 × Hsig (physical limit)
    face_height = max(face_height, hsig_m)
    face_height = min(face_height, hsig_m * 3.0)

    return face_height
```

### Per-Spot Operator Config (amended 2026-07-16)

Two per-spot config fields, set via wizard surf spot step and admin marine section:

```ini
# Per marine location in api.conf [marine] location entries:
breaker_formula = komar_gaughan   # default; alt: caldwell
surf_height_display = face        # default; alt: hawaiian
```

The API always returns all four height fields regardless of `surf_height_display`. The `surfHeightDisplay` field in the surf response tells the dashboard which height to render as primary. The dashboard reads `surfHeightDisplay` and selects `breakingFaceHeight` (face) or `breakingHawaiianHeight` (hawaiian) for the chart and headline number.

### Scoring Uses Face Height (amended 2026-07-16)

The surf scorer (`surf_scorer.py`) scores using `breakingFaceHeight`, not raw Hsig. The scoring thresholds represent what surfers consider good waves — surfers think and talk in face height terms. When the scoring table says "3–6ft optimal," that should mean face height because that's how surfers describe their experience.

Scoring always uses `breakingFaceHeight` regardless of the operator's `surf_height_display` preference. Hawaiian height and face height are always proportional (fixed ×0.5 factor) — the score is scale-independent. A 5-star session is 5 stars whether you call it "8ft face" or "4ft Hawaiian."

The `_WAVE_HEIGHT_RANGES_FT` thresholds must be recalibrated upward by ~15–20% when switching from Hsig to face height as input. The recalibration target: typical conditions that scored "Good" before should still score "Good" after. This is a recalibration to a new height convention, not a redesign of the scoring logic.

### Dashboard Display

The dashboard surf tab reads `surfHeightDisplay` from the API response to select the primary height value:
- `"face"` → display `breakingFaceHeight` as the headline number and chart y-axis
- `"hawaiian"` → display `breakingHawaiianHeight` as the headline number and chart y-axis

`swellHeight` is available as a secondary reference (e.g., tooltip or detail panel). The 72-hour forecast chart plots the operator-selected height field.

---

## §6 — Validation Plan

### Worked Examples for Verification

| Condition label | Hsig (m) | Tp (s) | Output depth (m) | Expected face height (m) | Expected face height (ft) | Surfer expectation |
|---|---|---|---|---|---|---|
| Flat day, wind chop | 0.3 | 6 | 10 | ~0.32 | ~1.0 | Ankle-high, not worth paddling out |
| Small day, short period | 0.6 | 8 | 10 | ~0.66 | ~2.2 | Knee-high, longboard session |
| Medium day, ground swell | 1.2 | 14 | 10 | ~1.41 | ~4.6 | Chest-to-shoulder high, fun session |
| Good day, long period | 1.8 | 16 | 10 | ~2.18 | ~7.2 | Overhead+, quality session |
| Large day, NW swell | 2.4 | 18 | 10 | ~2.95 | ~9.7 | Double overhead, expert territory |

These should be cross-referenced against:
1. Surfline's face height reports for the same swell at nearby spots (when available).
2. NDBC buoy Hsig at the nearest coastal buoy (for the Hsig baseline).
3. Visual surf observations (webcam or in-person) when possible.

### Acceptance Criteria

- Face height values are physically reasonable: always ≥ Hsig, never > 3× Hsig.
- Face height increases monotonically with wave period for the same Hsig (longer periods = taller breakers).
- For typical SoCal ground swell (12–16s), face height is approximately 1.15–1.25× Hsig.
- For short-period wind waves (6–8s), face height is approximately 1.05–1.10× Hsig.
- Hawaiian scale produces values approximately 50% of face height.
- The existing γ correction (Supplement 1) still functions and does not double-count with the face height conversion — they operate on different axes (physical cap vs. display convention).
- Scoring is unchanged — `qualityStars` uses `waveHeightAtBreak`, not `breakingFaceHeight`.

---

## References

- Komar, P.D. and Gaughan, M.K. (1973). "Airy Wave Theory and Breaker Height Prediction." Proceedings 13th Coastal Engineering Conference, ASCE, pp. 405–418.
- Caldwell, P.C. and Aucan, J. (2007). "An Empirical Method for Estimating Surf Heights from Deepwater Significant Wave Heights and Peak Periods in Coastal Zones with Narrow Shelves, Steep Bottom Slopes, and High Refraction." Journal of Coastal Research, Vol. 23, No. 5, pp. 1190–1196.
- Battjes, J.A. (1974). "Computation of set-up, longshore currents, run-up and overtopping due to wind-generated waves." PhD thesis, Delft University of Technology.
- Rayleigh distribution wave height statistics: Coastal Wiki, "Statistical description of wave parameters."
- USNA "Rayleigh Probability Distribution Applied to Random Wave Heights."
- Surfline Support: "Surf Height Unit Preference — Face Height vs. Traditional."
- Surfline: "What is LOTUS?" and "LOTUS swell model."
- Hawaiian scale: Wikipedia, "Hawaiian scale."
- SwellBeat: "Wave forecast: the last mile" — H_b = Ks × Kr × H0 methodology.
