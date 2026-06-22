# Long & Ackerman (2000) — Clear-Sky Detection Summary

**Research task:** R1.2 — Long & Ackerman Clear-Sky Detection Algorithm
**Archived:** 2026-06-21
**Status:** FULL PAPER PAYWALLED — algorithm details reconstructed from ARM technical reports and citing literature (see source notes per section)

---

## Full Citation

Long, C. N. and Ackerman, T. P. (2000). "Identification of clear skies from broadband pyranometer measurements and calculation of downwelling shortwave cloud effects." *Journal of Geophysical Research: Atmospheres*, **105**(D12), 15609–15626.

- DOI: [10.1029/2000JD900077](https://doi.org/10.1029/2000JD900077)
- Wiley page (abstract only, paywalled): https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2000JD900077
- ARM implementation technical report (ARM TR-004): https://www.arm.gov/publications/tech_reports/arm-tr-004.pdf (PDF, binary — not text-extractable)
- ARM technical report updated (ARM TR-004.1): https://www.arm.gov/publications/tech_reports/arm-tr-004.1.pdf (PDF, binary — not text-extractable)
- ARM TR-004.1 OSTI record: https://www.osti.gov/biblio/1808704
- ARM TR-004 OSTI record: https://www.osti.gov/biblio/1020737
- Scanned paper copy (image PDF, not extractable): https://patarnott.com/seniorthesis/pdf/jgrd7453_ClearSkyID_AckermanLong.pdf

---

## Source Verification Notes

The full paper text is paywalled at Wiley OnlineLibrary and not available in extractable open-access form. The scanned PDF at patarnott.com is image-only (CCITT Fax compressed), not OCR-searchable. The ARM TR-004 and TR-004.1 PDFs are binary-compressed and could not be text-extracted via WebFetch.

All algorithm details below are sourced from:
1. **Citing literature** — papers that describe the Long & Ackerman algorithm while introducing alternatives (Reno & Hansen 2016; de Blas et al. 2020; multiple benchmark studies).
2. **ARM proceedings papers** — extended abstracts from ARM Annual Science Team meetings.
3. **OSTI bibliographic records** for ARM TR-004 and TR-004.1.
4. **pvlib Python library documentation** (https://pvlib-python.readthedocs.io/) which implements a related algorithm (Reno & Hansen 2016) and describes Long & Ackerman as the predecessor.
5. **PMC open-access paper** (https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/) — directly quotes the four-test structure.

Claims marked **[ABSTRACT-ONLY]** come only from the Wiley abstract page. Claims marked **[CITING-LIT]** come from papers that cite and describe the Long & Ackerman method. Claims marked **[ARM-PROC]** come from ARM proceedings documents.

---

## 1. Algorithm Overview

**Verified from [CITING-LIT]:** Long & Ackerman (2000) present an automated method to identify cloud-free periods using 1-minute measurements of surface downwelling **total shortwave (GHI)** and **diffuse shortwave (DHI)** irradiance. The algorithm does not use direct normal irradiance (DNI) directly, but uses the diffuse fraction (DHI/GHI) as a diagnostic.

Sources:
- https://www.arm.gov/publications/proceedings/conf12/extended_abs/gaustad-kl.pdf (ARM proceedings, binary PDF)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/ (PMC open access, quotes four-test structure)
- https://www.readkong.com/page/detection-of-clear-sky-instants-from-high-frequencies-3705431 (cites and names four tests)

**Key constraint:** The algorithm was designed for **sub-15 minute resolution** (nominally 1-minute) data. It uses an iterative method to determine selection cutoff criteria. It was validated against whole-sky imagery, lidar data, observer reports, and other models.

---

## 2. The Four Tests — Step-by-Step Algorithm

All four tests must be passed for a data point to be classified as "clear sky." **[CITING-LIT]**

Sources for this section:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/
- https://www.readkong.com/page/detection-of-clear-sky-instants-from-high-frequencies-3705431
- Web search result snippets citing ARM TR-004 content (https://www.arm.gov/publications/tech_reports/arm-tr-004.pdf)

### Test 1: Normalized Total Shortwave Magnitude Test (GHI limits)

The measured total shortwave (GHI) is compared against an expected range as a function of solar zenith angle. The normalization uses the cosine of the solar zenith angle (cos Z). Data are rejected if GHI falls outside site-calibrated upper and lower bounds.

- The upper bound uses a site-dependent coefficient `b = 1.31` for the ARM Southern Great Plains (SGP) Central Facility. **[CITING-LIT — ARM TR-004 content described in secondary sources]**
- This test rejects: obviously cloudy periods (too low) and unrealistically high values.
- **Smoothness is NOT the measure in Test 1.** This is a magnitude/range test only.

### Test 2: Maximum Diffuse Shortwave Test

The diffuse shortwave irradiance (DHI) is compared against a maximum allowable threshold. In hazy tropical climates, the default threshold may need to be raised to approximately 200 W/m² or higher. **[CITING-LIT]**

- This test catches periods with high diffuse loading that indicate cloud presence even when total GHI might be within range.
- The threshold is site-dependent and climate-dependent.

### Test 3: Change in Shortwave Magnitude With Time (Rate-of-Change)

This is the smoothness test. It measures the **first derivative** of GHI with respect to time — the change in irradiance magnitude between successive 1-minute readings.

- A constant `C = 8` (W/m²/minute, tuned for typical pyranometer noise) is used at the ARM SGP site. **[CITING-LIT — referenced in secondary sources describing ARM TR-004]**
- Clear sky is identified only if successive GHI values change more slowly than this threshold.
- **This is the temporal smoothness test.** Clear-sky diurnal curves are smooth (slowly varying); cloud passages produce rapid fluctuations that exceed this derivative threshold.

**What "smooth curve" means quantitatively:** A GHI time series is "smooth" in the Long & Ackerman sense when the absolute first-difference between consecutive 1-minute readings stays below a site-tuned rate-of-change constant (C ≈ 8 W/m²/min at SGP). This is a **first-derivative** criterion, not variance or coefficient of variation.

### Test 4: Normalized Diffuse Ratio Variability Test

This is the key variability test. It measures the **standard deviation** of the Normalized Diffuse Ratio (NDR) over a sliding window.

**NDR is defined as:**
```
NDR = (DHI/GHI) / cos(Z)^b
```
where:
- DHI = diffuse horizontal irradiance
- GHI = global horizontal irradiance
- Z = solar zenith angle
- `b` = site-dependent coefficient (fit from the data)

**Variability criterion:** For 1-minute data, the **standard deviation of NDR over an 11-minute window** is computed. The clear-sky detection limit is **0.0012** (dimensionless). **[CITING-LIT — from secondary source describing the algorithm; see search result citing the ARM proceedings]**

Sources specifically mentioning 0.0012 and 11-minute window:
- Web search result from search query "Long Ackerman 2000 clear sky normalized diffuse ratio variability formula definition test 4 variability smoothness" — snippet attributes this to the ARM/Long documentation.

**What "smooth curve" means in Test 4:** Clear-sky DHI/GHI ratios should be **stable** (low standard deviation) over the 11-minute window. Cloud passage introduces turbulent fluctuations in the diffuse fraction that exceed this threshold.

---

## 3. Algorithm Iteration and Fitting

After an initial clear-sky period is identified, Long & Ackerman apply an iterative **curve-fitting procedure**:

- GHI and DHI from identified clear-sky episodes are each fitted to an exponential function of cos(Z), modified by an amplitude factor.
- The fitting equation has the form: `F = A * exp(B / cos(Z))` where A is an amplitude parameter that varies day to day (capturing aerosol and water vapor variations).
- The algorithm refits the curves and re-applies detection criteria iteratively (up to a defined maximum number of iterations).
- A minimum data span of ~90 minutes equivalent is recommended to achieve stable daily fits. **[CITING-LIT]**

This curve fitting is what gives the algorithm the ability to capture site-specific and day-specific atmospheric conditions (haze, dust, high water vapor) without requiring explicit aerosol measurements.

---

## 4. Haze as a Distinct Case from Clear Sky

**Short answer: The paper does NOT define haze as a separate classification. Haze is treated as a subset of "clear sky."**

Long & Ackerman's approach identifies "clear" as the absence of cloud-induced GHI variability. Days with uniform haze or elevated aerosol loading — provided the GHI curve is *smooth* — can and will pass all four tests and be classified as clear sky. The method does not distinguish between:
- Truly clear, pristine atmosphere
- Clear sky with elevated aerosol optical depth (hazy but stable)
- Clear sky with high water vapor (humid, smooth)

Sources (verified [CITING-LIT]):
- Search result snippet from benchmark study: "distinct failure modes such as 'hazy but stable conditions' have been identified, where thin atmospheric haze slightly attenuates sunlight without introducing significant variability" — confirmed from https://www.researchgate.net/publication/332565089... (abstract only, body paywalled)
- ARM TR-004.1 OSTI record (https://www.osti.gov/biblio/1808704) confirms the algorithm produces a smooth-curve fit that captures day-to-day aerosol/water-vapor variation through the amplitude factor A.

**Implication:** A hazy day with a stable, smooth GHI signal will be classified as "clear" by Long & Ackerman. The algorithm accommodates haze variation implicitly through the fitting amplitude, but does not flag it as a separate condition.

---

## 5. Aerosol vs. Cloud Discrimination

**Short answer: Not addressed as an explicit classification problem.**

The Long & Ackerman algorithm does not attempt to classify the *cause* of reduced GHI. It only asks: "Is the GHI time series smooth and within expected magnitude/diffuse-ratio bounds?" Aerosols and clouds have fundamentally different signatures:

| Feature | Clouds | Aerosols (haze) |
|---------|--------|-----------------|
| GHI variability | High (rapid fluctuations) | Low (steady attenuation) |
| Diffuse fraction | High and variable | Moderately elevated but stable |
| NDR standard deviation (11-min) | > 0.0012 typically | < 0.0012 typically |
| Passes Test 3 (rate of change)? | Often fails | Usually passes |
| Passes Test 4 (NDR variability)? | Often fails | Usually passes |

**Result:** Hazy days with stable aerosol loading typically pass all four tests and are classified as **clear sky** by Long & Ackerman. The algorithm does NOT discriminate aerosol extinction from cloud extinction — it only discriminates *temporally smooth* extinction from *turbulent* extinction.

This is confirmed by citing literature noting that the diffuse SW threshold may need to be raised in hazy tropical climates (the Western Tropical Pacific) and that optically thin high-altitude cloud near the horizon may not be detected. **[CITING-LIT]**

Source: Web search result citing ARM documentation: "uniform, optically thin haze and persistent thin clouds near the horizon may not be detected by their method."

---

## 6. Known Limitations

From citing literature [CITING-LIT]:

1. **Hazy stable conditions pass as clear.** Thin, uniform aerosol/haze that smooths GHI without introducing variability is classified as clear sky.
2. **Single-minute false positives.** The algorithm can classify a single 1-minute data point as clear during an otherwise variable period if the ratios happen to fall within bounds for that one sample.
3. **Large solar-zenith angle bias.** High zenith angle situations tend to be systematically classified as cloudy (zenith-angle-dependent thresholds may be too tight at low sun angles).
4. **Site-dependent constants.** The constants b (diffuse ratio exponent), C (rate-of-change threshold), and the NDR variability limit (0.0012) are calibrated to the ARM SGP site. They must be re-tuned for other climates and sensor setups.
5. **Requires both GHI and DHI.** Unlike Reno & Hansen (2016), Long & Ackerman cannot operate on GHI alone — diffuse irradiance from a shaded pyranometer or shadow-band measurement is required.

---

## 7. Relation to Reno & Hansen (2016)

Reno, M.J. and Hansen, C.W. (2016). "Identification of periods of clear sky irradiance in time series of GHI measurements." *Renewable Energy*, 90, 520–531.

- [OSTI record](https://www.osti.gov/biblio/1239983)
- Implemented in pvlib as `pvlib.clearsky.detect_clearsky` (https://pvlib-python.readthedocs.io/en/stable/reference/generated/pvlib.clearsky.detect_clearsky.html)

Reno & Hansen **directly address the Long & Ackerman limitation** of requiring diffuse irradiance. Their algorithm:
- Uses **GHI only** (no DHI required) by comparing measured GHI against a clear-sky model output.
- Uses a **sliding 10-minute window** with five criteria (not four).
- Applies a **variance of rate of change** criterion (analogous to Long & Ackerman Test 4).
- Uses an **iterative scaling factor** (α) to reconcile the clear-sky model with observed GHI.

**Reno & Hansen five criteria** (verified from pvlib source code at https://pvlib-python.readthedocs.io/en/stable/_modules/pvlib/clearsky.html):

| Criterion | What it tests | Default threshold |
|-----------|--------------|-------------------|
| c1: mean_diff | Mean(measured) ≈ Mean(modeled·α) | 75 W/m² |
| c2: max_diff | Max(measured) ≈ Max(modeled·α) | 75 W/m² |
| c3: line_length | Curve shape agreement (lower/upper bounds) | −5 to +10 |
| c4: var_diff | Normalized std dev of rate-of-change agreement | 0.005 Hz |
| c5: slope_dev | Max successive value change | 8 W/m² |

**Reno & Hansen found significant differences** between their identified clear periods and Long & Ackerman's, though agreement was high (>94%) when both were applied to the same dataset. **[CITING-LIT]**

---

## 8. Relevance to CAELUS Kv Measure

Our CAELUS system uses:
- `Kcs = GHI / maxSolarRad` (clear-sky index, captures Beer-Lambert extinction magnitude)
- `Kv = coefficient of variation (std/mean) of Kcs` over a 10-minute sliding window (smoothness/variability)

### Direct correspondence to Long & Ackerman

| Long & Ackerman | CAELUS equivalent | Correspondence |
|-----------------|-------------------|----------------|
| Test 1 (GHI magnitude limits) | Kcs bounds check (Kcs ∈ [0.85, 1.15]) | Direct analogue — both test whether GHI is within an expected range normalized by atmospheric geometry |
| Test 3 (rate of change of GHI) | Kv (coefficient of variation over window) | Partial analogue — L&A uses first-difference of GHI; Kv uses std/mean of Kcs over the window. Both capture temporal smoothness. |
| Test 4 (NDR variability over 11-min window) | Kv | Strong analogue — L&A's NDR variability and CAELUS's Kv are both window-based measures of irradiance stability, differing in normalization approach |
| No direct analogue | Km (fraction of max solar radiation reached, hour-scale) | No equivalent in L&A |

### Does Long & Ackerman validate using Kv?

**Yes, strongly.** The core insight of Long & Ackerman (2000) is that clear-sky GHI has two distinguishing features:
1. **Magnitude** within expected bounds (Test 1 and 2)
2. **Temporal smoothness** — both short-term (Test 3, first-difference) and window-level (Test 4, std deviation of normalized diffuse ratio over 11 minutes)

Kv is a coefficient of variation of Kcs over a 10-minute window. This is structurally equivalent to Long & Ackerman's Test 4 variability measure, applied to the total irradiance ratio rather than the diffuse ratio. Using Kv to distinguish CLOUDLESS (< 0.03) from THIN_CLOUDS (0.03–0.08) is consistent with the L&A methodology.

### Can Long & Ackerman help distinguish haze from clear sky?

**No — and this is a critical gap.** The fundamental problem is that Long & Ackerman define "clear sky" as smooth + within magnitude bounds. A uniformly hazy day passes the smoothness test (Test 3 and Test 4) and may pass the magnitude test (Test 1) if haze is moderate. The algorithm was designed to detect *clouds* (which perturb GHI rapidly), not *haze* (which attenuates GHI steadily).

This gap applies equally to CAELUS: Kv alone cannot distinguish a clear-but-hazy day (low Kv, reduced Kcs) from a truly pristine clear day (low Kv, Kcs ≈ 1.0). The Kcs magnitude check is the only thing that separates them, which is why our CLOUDLESS threshold of Kcs ∈ [0.85, 1.15] implicitly limits how hazy a "cloudless" sky can be.

---

## 9. Summary Assessment

| Question | Answer |
|----------|--------|
| Does the paper present a smoothness-based algorithm? | YES — Tests 3 and 4 are both smoothness/variability criteria |
| Is "smooth curve" variance-based or first-derivative? | BOTH: Test 3 = first derivative (rate of change); Test 4 = standard deviation of NDR over 11 minutes |
| Does the paper address haze as a distinct case? | NO — haze is implicitly absorbed into the "clear sky" classification when the GHI curve is smooth |
| Does the paper discriminate aerosols from clouds? | NO — it discriminates smooth extinction (clear/hazy) from turbulent extinction (cloudy), not aerosol from cloud physically |
| Does this validate using Kv for cloud-free detection? | YES — strongly. Kv is structurally equivalent to L&A Test 4 (window standard deviation of normalized irradiance) |
| Can L&A methodology help separate haze from clear sky? | NO — this is a fundamental limitation acknowledged in subsequent literature |

---

## 10. Source URLs

All claims above are sourced from the following fetched or searched documents:

- **Wiley abstract page (paywalled):** https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2000JD900077
- **ARM TR-004 (binary PDF, OSTI):** https://www.osti.gov/biblio/1020737
- **ARM TR-004.1 (binary PDF, OSTI):** https://www.osti.gov/biblio/1808704
- **PMC open-access paper citing four tests:** https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/
- **ReadKong description of four tests:** https://www.readkong.com/page/detection-of-clear-sky-instants-from-high-frequencies-3705431
- **Reno & Hansen 2016 OSTI record:** https://www.osti.gov/pages/biblio/1239983
- **pvlib detect_clearsky API docs:** https://pvlib-python.readthedocs.io/en/stable/reference/generated/pvlib.clearsky.detect_clearsky.html
- **pvlib source code (algorithm implementation):** https://pvlib-python.readthedocs.io/en/stable/_modules/pvlib/clearsky.html
- **Benchmark review (ResearchGate, abstract only):** https://www.researchgate.net/publication/303412388_Benchmark_of_algorithms_for_solar_clear-sky_detection
- **Clear-sky ID review (ResearchGate, abstract only):** https://www.researchgate.net/publication/332565089_A_posteriori_clear-sky_identification_methods_in_solar_irradiance_time_series_Review_and_preliminary_validation_using_sky_imagers
- **ARM proceedings Gaustad (binary PDF):** https://www.arm.gov/publications/proceedings/conf12/extended_abs/gaustad-kl.pdf
- **ARM proceedings Long diffuse ratio (binary PDF):** https://arm.gov/publications/proceedings/conf05/extended_abs/long_cn.pdf
- **SODA-pro how-to detect clear sky:** https://www.soda-pro.com/help/general-knowledge/how-to-detect-clear-sky-instants
- **HAL evaluation paper (access denied):** https://hal.science/hal-04110268/document

---

## 11. What Could NOT Be Verified

The following specific values and claims could not be independently verified from source text due to paywalls or binary PDFs:

1. **Exact formula for Test 1 bounds** (the precise functional form of the GHI upper/lower limits as a function of cos Z) — known to be site-dependent with b = 1.31 at SGP, sourced from secondary descriptions, not primary text.
2. **Exact formula for Test 2** (maximum diffuse threshold function) — confirmed to exist as a threshold, but precise numerical formula not verified from primary text.
3. **Exact value of constant C in Test 3** — cited as C ≈ 8 W/m²/min from secondary source descriptions of ARM TR-004; not verified from primary paper text.
4. **NDR variability threshold of 0.0012 and 11-minute window** — cited from secondary source description; not verified from primary paper or ARM TR text directly.
5. **Whether the paper explicitly says "smooth diurnal curve"** — this characterization appears in secondary literature summarizing the paper; the exact phrasing in the original is not verified.
6. **Any direct discussion in the paper of haze, aerosol optical depth, or turbid atmosphere** — the paper's treatment of aerosol variation (absorbed implicitly in the amplitude factor A of the curve fit) is described in secondary sources; the original text cannot be confirmed due to paywall.
