# Ryan-Stolzenbach Clear-Sky Solar Radiation Model

**Purpose:** Reference for R2.2 haze detection research. Documents exactly what weewx computes as `maxSolarRad` and what the `atc` parameter physically represents, so we can reason about the Kcs = GHI / maxSolarRad clear-sky index.

**Archived:** 2026-06-21  
**Researcher:** Claude (research agent, task R2.2)

---

## 1. Provenance

The model originates from:

> Ryan, P.J., and K.D. Stolzenbach. "Chapter 1: Environmental Heat Transfer." In *Engineering Aspects of Heat Disposal from Power Generation*, edited by D.R.F. Harleman. R.M. Parsons Laboratory for Water Resources and Hydrodynamics, Dept. of Civil Engineering, MIT, Cambridge, MA, 1972.

This is a textbook chapter, not a journal paper. It is not open-access and likely not digitized online. The chapter derived an empirical clear-sky solar radiation formula in the context of thermal pollution analysis for power plant cooling water discharge studies.

Secondary citation confirming provenance:
- Annear, R.L., and S.A. Smith (2007). "A comparison of five models for estimating clear-sky solar radiation." *Water Resources Research*, 43, W10415. DOI: 10.1029/2006WR005055. [Wiley](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2006WR005055)
- Search result summary of Ryan and Harleman (1971/1972) context: "Ryan and Harleman recommended that clear sky solar radiation be determined from empirical information." The atmospheric transmission coefficient was reported with daily values ranging from 0.60 to 0.91 in the literature.

---

## 2. Exact weewx Formula

**Source file:** `src/weewx/wxformulas.py`, function `solar_rad_RS()`, lines 390–435.  
**Source URL (master, pinned to commit `5169d6380d83`):**  
`https://github.com/weewx/weewx/blob/master/src/weewx/wxformulas.py#L390`  
**Raw URL fetched:** `https://raw.githubusercontent.com/weewx/weewx/master/src/weewx/wxformulas.py`  
**Docstring citation:** "Ryan-Stolzenbach, MIT 1972 — http://www.ecy.wa.gov/programs/eap/models.html"

### Full function (verbatim from source)

```python
def solar_rad_RS(lat, lon, altitude_m, ts=None, atc=0.8):
    """Calculate maximum solar radiation
    Ryan-Stolzenbach, MIT 1972
    http://www.ecy.wa.gov/programs/eap/models.html

    lat, lon - latitude and longitude in decimal degrees
    altitude_m - altitude in meters
    ts - time as unix epoch
    atc - atmospheric transmission coefficient (0.7-0.91)
    """
    from weewx.almanac import Almanac
    if atc < 0.7 or atc > 0.91:
        atc = 0.8
    if ts is None:
        ts = time.time()
    sr = 0.0
    try:
        alm = Almanac(ts, lat, lon, altitude_m)
        el = alm.sun.alt          # solar elevation degrees from horizon
        R  = alm.sun.earth_distance  # Earth-Sun distance in AU
        z  = altitude_m
        nrel = 1367.0             # NREL solar constant, W/m²
        sinal = math.sin(math.radians(el))
        if sinal >= 0:            # sun must be above horizon
            rm = math.pow((288.0 - 0.0065 * z) / 288.0, 5.256) \
                 / (sinal + 0.15 * math.pow(el + 3.885, -1.253))
            toa = nrel * sinal / (R * R)
            sr  = toa * math.pow(atc, rm)
    except (AttributeError, ValueError, OverflowError):
        sr = None
    return sr
```

---

## 3. Formula Decomposition: Every Term Defined

### Step 1 — Top-of-atmosphere irradiance on a horizontal surface

```
toa = nrel × sin(el) / R²
```

| Symbol | Meaning | Value / Units |
|--------|---------|---------------|
| `nrel` | Solar constant (NREL value) | 1367.0 W m⁻² |
| `el` | Solar elevation angle above horizon | degrees (from PyEphem `alm.sun.alt`, converted to radians for `math.sin`) |
| `sin(el)` | Cosine of the solar zenith angle (= sin of elevation) | dimensionless; projects beam onto a horizontal surface |
| `R` | Earth-Sun distance | AU (astronomical units, from PyEphem) |
| `R²` | Earth-Sun distance squared | Accounts for the inverse-square law; R=1 AU at mean distance |
| `toa` | Extraterrestrial irradiance on a horizontal surface | W m⁻² |

Note: `sin(el) = cos(θz)` where θz is the solar zenith angle. This is the standard geometric projection of beam radiation onto a horizontal plane.

### Step 2 — Pressure-corrected optical air mass

```
rm = [(288 - 0.0065 × z) / 288]^5.256
     ──────────────────────────────────────────────────────
     sin(el) + 0.15 × (el + 3.885)^(−1.253)
```

**Numerator — altitude pressure correction:**

| Component | Meaning |
|-----------|---------|
| `288.0` | Standard sea-level temperature, K (≈ 15 °C) |
| `0.0065` | Standard tropospheric lapse rate, K m⁻¹ |
| `z` | Site altitude, meters |
| `(288 - 0.0065z)/288` | Temperature ratio T(z)/T₀ at altitude z under standard atmosphere |
| `^5.256` | Barometric pressure ratio exponent: P(z)/P₀ = (T(z)/T₀)^(g/RₛL) where g=9.80665, Rₛ=287.05, L=0.0065; the exponent evaluates to ≈5.256 |

This numerator is the **pressure ratio P(z)/P₀** from the International Standard Atmosphere (ISA), tropospheric layer. It corrects the air mass for the thinner atmosphere at elevated sites — less atmosphere above you means less extinction per unit path. Source: ISA barometric formula, confirmed by search results from barometric pressure calculators and the ISA standard.

**Denominator — geometric path length through the atmosphere:**

```
sin(el) + 0.15 × (el + 3.885)^(−1.253)
```

This is a well-known empirical approximation for **optical air mass AM** as a function of solar elevation `el` (degrees), attributed to Kasten and Young (1989) in a slightly different but equivalent form. The Kasten-Young (1989) formula appears in the literature as:

```
AM = 1 / [sin(γ) + a(γ + b)^(−c)]
     with a=0.15, b=3.885, c=1.253
```

where γ is solar elevation. The simple form 1/sin(el) diverges at el=0°; the empirical correction term `0.15×(el+3.885)^−1.253` prevents divergence at the horizon and accounts for Earth's spherical curvature and finite atmospheric depth (approximately 9 km scale height).

Source on these coefficients: Kasten, F., and A.T. Young (1989). "Revised optical air mass tables and approximation formula." *Applied Optics*, 28(22), 4735–4738. DOI confirmed via PubMed (PMID 20555942) and NASA ADS. Search result from scispace.com confirms the 1989 paper has 1151+ citations.

**Combined rm:**

`rm = P(z)/P₀ × AM(el)` — the **pressure-corrected relative optical air mass**. At sea level (z=0), the numerator is exactly 1.0 and rm equals the geometric air mass. At altitude, less atmosphere exists above the observer, so rm is reduced accordingly.

### Step 3 — Surface irradiance

```
sr = toa × atc^rm
```

| Symbol | Meaning |
|--------|---------|
| `atc` | Atmospheric transmission coefficient (dimensionless, 0.7–0.91, default 0.8) |
| `rm` | Pressure-corrected optical air mass (dimensionless) |
| `atc^rm` | Fraction of TOA radiation transmitted through `rm` atmospheric path lengths |
| `sr` | Estimated clear-sky global horizontal irradiance at surface | W m⁻² |

This is a **Beer-Lambert law** form: `T = atc^AM`, where atc is the per-unit-air-mass transmittance. When AM=1 (sun directly overhead at sea level), exactly `atc` fraction of TOA radiation reaches the surface. When AM=2, `atc²` fraction reaches the surface.

---

## 4. What `atc` Physically Represents

### The short answer

`atc` is a **single lumped empirical coefficient** that collapses all atmospheric extinction processes into one number. It does **not** separately account for Rayleigh scattering, water vapor absorption, ozone absorption, or aerosol scattering — it bundles all of them together into one empirical per-air-mass transmittance.

### Physical meaning

In more detailed clear-sky models (e.g., Bird-Hulstrom 1981), the total transmittance is a product of separate terms:

```
T_total = T_Rayleigh × T_ozone × T_water_vapor × T_gases × T_aerosol
```

Ryan-Stolzenbach replaces this entire product with a single `atc^AM` term. The coefficient `atc` was calibrated empirically from observed solar radiation data at various sites. It is a **daily constant for a given location** — it does not vary with time of day, solar angle, or atmospheric state within a day.

### What extinction sources are implicitly included

Because `atc` was fitted to actual measured solar data under clear-sky conditions, it implicitly aggregates:

- **Rayleigh scattering** (molecular scattering by N₂, O₂) — always present
- **Water vapor absorption** — at the climatological-mean level for the calibration sites
- **Aerosol scattering and absorption** — at the climatological-mean level
- **Ozone absorption** — at climatological mean
- **Uniformly-mixed gas absorption** (CO₂, O₂, etc.) — at climatological mean

What it **cannot** separately represent:

- **Day-to-day or hour-to-hour aerosol variability** (haze events, wildfire smoke, dust)
- **Day-to-day water vapor variability** (humid vs. dry days)
- **Ozone column variations**

The Bras model (also in weewx, `solar_rad_Bras`) separates these more explicitly: its `nfac` parameter is "atmospheric turbidity" (2=clear, 4–5=smoggy), and it uses a separate `a1 = 0.128 - 0.054 × log₁₀(m)` term for molecular scattering coefficient, with aerosol effects folded into `nfac`.

### Calibrated range

The valid range 0.7–0.91 reflects observed daily-average clear-sky transmission at diverse sites. Values toward 0.7 represent persistently hazy or high-humidity climates; values toward 0.91 represent exceptionally clear, dry, high-altitude locations. The default 0.8 represents a mid-latitude average.

**Citation for the lumped-parameter characterization:**
- Annear & Smith (2007), DOI 10.1029/2006WR005055, confirmed by web search summary: "They characterized atmospheric attenuation variables into one empirical transmission coefficient, which was often used to calibrate their models to data and represented a daily constant for a specific location."
- OSTI report 1039404 (*Global Horizontal Irradiance Clear Sky Models*), fetched 2026-06-21: "The atmospheric transmission coefficient encompasses three primary attenuation mechanisms: Rayleigh scattering (molecular scattering), aerosol extinction (particle scattering and absorption), water vapor absorption (molecular absorption)."

---

## 5. Does the Formula Include an Air Mass / Path-Length Correction?

**Yes.** The formula explicitly includes the optical air mass `rm`, which is the pressure-corrected Kasten-Young air mass formula. The model accounts for path length in the Beer-Lambert exponent: `atc^rm`. When the sun is high (small AM), less extinction occurs; when the sun is low (large AM), more extinction occurs.

The path length correction is:

1. **Geometric path length:** via `sin(el) + 0.15×(el+3.885)^−1.253` in the denominator of rm — this models how much longer the atmospheric path is when the sun is near the horizon compared to overhead.
2. **Altitude correction:** via `(288-0.0065z)/288)^5.256` numerator — this reduces rm for observers at high altitude (less atmosphere above them).

Both corrections operate on the exponent of `atc`, so they produce the correct Beer-Lambert scaling.

---

## 6. Is Kcs Already Normalized for Path Length?

**Short answer: Kcs = GHI / maxSolarRad is NOT fully normalized for path length. It has a residual systematic air-mass dependence.**

### Why it is partially normalized

Both GHI (measured) and maxSolarRad (modeled) contain the `sin(el)` geometric projection factor. The `toa` term in maxSolarRad explicitly includes `sin(el)`, so the denominator already scales with solar elevation. Dividing GHI by maxSolarRad removes the dominant solar-elevation geometric effect.

### Why residual air-mass dependence remains

The problem is the atmospheric transmission term `atc^rm`. This term in the denominator (maxSolarRad) represents the clear-sky model's view of how much atmosphere the beam passes through. If the actual atmosphere behaves differently from what the model assumes — particularly at high air mass (low elevation) — then Kcs will be systematically biased:

1. **Model underestimation at low elevation (high AM):** The weewx mailing list (fetched 2026-06-21 from `https://www.mail-archive.com/weewx-user@googlegroups.com/msg32382.html`) reports: "the R-S curve is quite a bit lower, maybe as much as 20% lower, at dawn and dusk." This means maxSolarRad is too low at low elevations, causing the denominator to be too small, which inflates Kcs above 1.0 even under clear-sky conditions near sunrise/sunset. Users observed GHI exceeding maxSolarRad at these times.

2. **atc is constant within the day:** Real atmospheric extinction (especially aerosol) varies within a day, and the ratio of actual to modeled extinction changes with air mass because each extinction mechanism scales differently with path length. A single `atc^rm` cannot reproduce this correctly.

3. **Aerosol scaling is non-Beer-Lambert:** Real aerosol aerosols follow Beer-Lambert at a fixed wavelength, but spectrally-integrated broadband aerosol transmittance does not scale as a clean power law with air mass because the spectral weighting changes with path length (the Langley plot problem).

### Practical implication for haze detection

- **At high solar elevations (el > 30°, AM < 2):** Kcs is reasonably path-length-normalized. A Kcs < threshold reliably indicates haze.
- **At low solar elevations (el < 10°–15°):** Kcs is unreliable. maxSolarRad underestimates true clear-sky values by ~20%, inflating Kcs. The threshold comparison becomes meaningless. **Haze detection should be gated on a minimum solar elevation — suggested el > 10° (AM < ~5.8) and ideally el > 15°.**

---

## 7. Known Limitations of the Ryan-Stolzenbach Model

1. **Single lumped parameter:** `atc` cannot represent aerosol variability within or between days. On a hazy day, `atc` would need to be lower, but weewx uses a fixed value. This means maxSolarRad is not a "true" clear-sky reference — it is a fixed-atmosphere reference.

2. **Low elevation underestimation (~20% at dawn/dusk):** Confirmed by weewx user community. The Kasten-Young air mass formula at very low elevations (el < 5°) is less accurate, and the Beer-Lambert exponential amplifies small model errors in `rm` at high air mass values.

3. **No spectral decomposition:** The formula gives broadband irradiance only. It cannot distinguish Rayleigh-dominated (clear blue sky) from aerosol-dominated (hazy sky) scenarios at the same total irradiance level.

4. **No cloud geometry:** When clouds are present, GHI can briefly exceed maxSolarRad due to cloud-edge enhancement (circumsolar brightening). This is unrelated to the model's clear-sky estimate but contributes to Kcs > 1 situations that haze detection code must handle.

5. **Fixed solar constant:** Uses 1367.0 W m⁻². The actual solar constant varies by ±0.1% with the solar cycle and is measured today as ~1361 W m⁻² (TSI Composite). This causes a small systematic offset (~0.5%) in Kcs.

6. **R is Earth-Sun distance in AU, squared:** This correction is included and correct; it accounts for the ~±3% variation in solar irradiance due to Earth's orbital eccentricity.

---

## 8. Original Paper Citation

**This is an MIT technical chapter, not a journal article.** It is likely in library collections only and is paywalled / not digitized online. No open-access version was found.

Correct bibliographic form:

> Ryan, P.J., and K.D. Stolzenbach (1972). "Chapter 1: Environmental Heat Transfer." In: D.R.F. Harleman (ed.), *Engineering Aspects of Heat Disposal from Power Generation*. R.M. Parsons Laboratory for Water Resources and Hydrodynamics, Dept. of Civil Engineering, MIT, Cambridge, MA.

Note: Some citations list this as "Ryan, P.J., and K.D. Stolzenbach (1972). *Environmental Heat Transfer*. Ralph M. Parsons Laboratory, MIT." The Harleman-edited compilation title varies in citation databases.

---

## 9. Source URLs (All Fetched 2026-06-21)

| Source | URL |
|--------|-----|
| weewx wxformulas.py (raw) | https://raw.githubusercontent.com/weewx/weewx/master/src/weewx/wxformulas.py |
| weewx wxformulas.py (GitHub browse) | https://github.com/weewx/weewx/blob/master/src/weewx/wxformulas.py#L390 |
| weewx StdWXCalculate docs | https://weewx.com/docs/5.2/reference/weewx-options/stdwxcalculate/ |
| Annear & Smith 2007 (Wiley, paywalled) | https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2006WR005055 |
| Kasten & Young 1989 (Optica, paywalled) | https://opg.optica.org/ao/abstract.cfm?uri=ao-28-22-4735 |
| OSTI GHI Clear Sky Models report | https://www.osti.gov/servlets/purl/1039404 |
| weewx-user mailing list (dawn/dusk underestimation) | https://www.mail-archive.com/weewx-user@googlegroups.com/msg32382.html |
| Washington State Ecology (SolRad, now redirected) | https://ecology.wa.gov/programs/eap/models.html |
| Air mass Wikipedia | https://en.wikipedia.org/wiki/Air_mass_(solar_energy) |
| PVEducation air mass | https://www.pveducation.org/pvcdrom/properties-of-sunlight/air-mass |
| ISA barometric formula | https://agodemar.github.io/FlightMechanics4Pilots/mypages/international-standard-atmosphere/ |

---

## 10. Summary Answers to R2.2 Questions

| Question | Answer |
|----------|--------|
| Exact weewx formula | `sr = (nrel × sin(el) / R²) × atc^rm` where `rm = (P(z)/P₀) / (sin(el) + 0.15×(el+3.885)^−1.253)` |
| What does `atc` represent? | Single lumped empirical coefficient aggregating ALL atmospheric extinction: Rayleigh + water vapor + aerosol + ozone + gases. It does NOT separate them. |
| Does atc account for aerosol? | Yes, but only at a climatological average level baked into the fitted coefficient. It cannot represent day-to-day or event-driven aerosol variability. |
| Does formula include air mass? | Yes — `rm` is the pressure-corrected Kasten-Young optical air mass. Path length is explicitly in the Beer-Lambert exponent. |
| Is Kcs air-mass normalized? | Partially. The `sin(el)` geometric projection cancels. But the atmospheric transmission term does not cancel, and model errors in `rm` at low elevation inflate Kcs by ~20% near dawn/dusk. |
| Systematic air-mass dependence? | Yes: Kcs is unreliable at low solar elevation (el < 10–15°). The R-S model underestimates clear-sky values at high air mass, causing Kcs > 1.0 for actual clear-sky near sunrise/sunset. |
| Known limitations at low elevation? | ~20% underestimation confirmed by weewx community; the Beer-Lambert exponent amplifies small air-mass errors at high AM; lumped atc cannot represent spectral or aerosol variability with AM. |
| Original paper | Ryan & Stolzenbach (1972), MIT technical chapter — likely paywalled, not digitized. Not a journal article. |
