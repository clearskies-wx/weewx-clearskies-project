# Clear-Sky Baseline Methodology — Research Archive

**Research task:** R2.1 — BSRN / SURFRAD Clear-Sky Baseline Methodology
**Archived:** 2026-06-21
**Purpose:** Document the statistical methodology used by ground-based radiometric networks (BSRN, SURFRAD, ARM) to determine clear-sky baselines — to inform defensible design of auto-calibration for our Kcs (clear-sky index) system.

---

## Table of Contents

1. [Sources and Verification Status](#1-sources-and-verification-status)
2. [The Core Ecosystem: ARM / BSRN / SURFRAD](#2-the-core-ecosystem)
3. [ARM SW Flux Analysis Algorithm (SWFLUXANAL)](#3-arm-sw-flux-analysis-algorithm)
4. [BSRN Quality Control and Clear-Sky Identification](#4-bsrn-quality-control)
5. [SURFRAD RadFlux Analysis Product](#5-surfrad-radflux-analysis-product)
6. [Sandia SAND2012-2389 — Model Validation Methodology](#6-sandia-sand2012-2389)
7. [Reno & Hansen (2016) — GHI-Only Clear-Sky Detection](#7-reno--hansen-2016)
8. [Renner et al. (2019) — Quantile Regression Approach](#8-renner-et-al-2019--quantile-regression-approach)
9. [Correa (2022) — Daily Transmittance Threshold Method](#9-correa-2022--daily-transmittance-threshold-method)
10. [Cross-Cutting Findings](#10-cross-cutting-findings)
11. [Assessment: Minimum Defensible Approach for a Consumer PWS](#11-assessment-minimum-defensible-approach-for-a-consumer-pws)

---

## 1. Sources and Verification Status

All claims below are sourced from fetched documents or web search results. No claim rests on training-data memory alone. Source quality is noted per section.

### Primary Sources (Fetched or Searched)

| Source | URL / DOI | Access Status |
|--------|-----------|---------------|
| ARM SWFLUXANAL VAP page | https://www.arm.gov/capabilities/science-data-products/vaps/swfluxanal | FETCHED — HTML (limited detail) |
| ARM TR-004 (Long & Gaustad 2004) | https://www.arm.gov/publications/tech_reports/arm-tr-004.pdf | BINARY PDF — not text-extractable |
| ARM TR-004.1 (updated) | https://www.arm.gov/publications/tech_reports/arm-tr-004.1.pdf | BINARY PDF — not text-extractable |
| ARM TR-004 OSTI record | https://www.osti.gov/biblio/1020737 | FETCHED — abstract + metadata only |
| ARM TR-004.1 OSTI record | https://www.osti.gov/biblio/1808704 | FETCHED — abstract + metadata only |
| ARM TR-228 RADFLUXANAL | https://www.osti.gov/servlets/purl/1569477/ | BINARY PDF — not text-extractable |
| ARM TR-228 ARM.gov | https://www.arm.gov/publications/tech_reports/doe-sc-arm-tr-228.pdf | BINARY PDF — not text-extractable |
| PMC open-access paper (SURFRAD/BSRN methodology) | https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/ | FETCHED — full text, HTML |
| BSRN Izaña station paper (Copernicus) | https://gi.copernicus.org/articles/8/77/2019/ | FETCHED — HTML |
| BSRN publications list | https://bsrn.awi.de/other/publications/establishment-and-development-of-the-bsrn/ | FETCHED — list only, no full text |
| Sandia SAND2012-2389 (OSTI PDF) | https://www.osti.gov/servlets/purl/1039404 | BINARY PDF — not text-extractable |
| Sandia SAND2012-2389 (UNT Digital Library) | https://digital.library.unt.edu/ark:/67531/metadc831646/ | FETCHED — metadata + abstract only |
| Sandia publications page | https://www.sandia.gov/research/publications/details/global-horizontal-irradiance-clear-sky-models-implementation-and-analysis-2012-03-01/ | FETCHED — abstract only |
| Reno & Hansen 2016 (OSTI PDF) | https://www.osti.gov/servlets/purl/1239983 | BINARY PDF — not text-extractable |
| pvlib detect_clearsky API docs | https://pvlib-python.readthedocs.io/en/stable/reference/generated/pvlib.clearsky.detect_clearsky.html | FETCHED — full HTML |
| Renner et al. 2019 (Wiley) | https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2019EA000686 | HTTP 403 FORBIDDEN |
| Renner 2019 ETH Zurich PDF | https://iacweb.ethz.ch/doc/publications/Renner_et_al-2019-Earth_and_Space_Science.pdf | BINARY PDF — not text-extractable |
| cleaRskyQuantileRegression GitHub | https://github.com/laubblatt/cleaRskyQuantileRegression | FETCHED — README, full text |
| cleaRskyQuantileRegression Zenodo | https://zenodo.org/records/3380327 | FETCHED — metadata |
| Correa 2022 (Wiley) | https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2021EA002197 | HTTP 403 FORBIDDEN |
| Web search: ARM 110-point threshold | query: "ARM TR-004 minimum number of points clear sky fit daily" | SEARCH RESULT — snippet verified |
| Web search: Renner 85th percentile | query: "Renner Wild 2019 quantile regression clear sky 0.95 OR 95th percentile" | SEARCH RESULT — confirmed 85% |
| Web search: SURFRAD RadFlux description | query: "SURFRAD RadFlux clear sky analysis methodology Long 2006" | SEARCH RESULT — confirmed RadFlux algorithm |
| Web search: SAND2012-2389 findings | query: "Sandia SAND2012-2389 30 sites 300 site-years" | SEARCH RESULT — confirmed 30 sites / 300 site-years |
| Meyers et al. 2019 Statistical Clear-Sky Fitting (arxiv) | https://arxiv.org/abs/1907.08279 | FETCHED — abstract only |

### What COULD NOT be verified from primary text
- Exact 110-point minimum threshold for ARM daily fit: confirmed from web search snippet attributing this to ARM TR-004, but could not read the PDF. Treat as [SEARCH-SNIPPET].
- Renner 2019 full methodology (seasonal vs monthly bins, exact sample requirements per bin): confirmed 85th percentile and monthly windows from README + search snippets; full paper inaccessible.
- Long & Ackerman (2000) primary text: paywalled at Wiley (see `long-ackerman-2000-summary.md` for details).
- Correa 2022 full methodology: Wiley 403 Forbidden; confirmed from search snippet only.

---

## 2. The Core Ecosystem

Three measurement networks collectively define the industry standard for ground-based clear-sky baseline methodology:

**BSRN (Baseline Surface Radiation Network)** — operated since 1992, >70 globally diverse sites, highest-accuracy broadband surface radiation. Clear-sky detection uses Long & Ackerman (2000) as the reference algorithm. As of the PMC paper cited below, "over 7000 site-months of RadFlux data are available from 42 BSRN sites" spanning 1992–2017. [SOURCE: PMC open-access paper, https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/]

**ARM (Atmospheric Radiation Measurement)** — U.S. DOE program, multiple globally diverse sites. Developed the definitive clear-sky fitting algorithm (Long & Ackerman 2000, formalized as ARM TR-004) and the SWFLUXANAL VAP (Value-Added Product) that operationalizes it. [SOURCE: ARM VAP page, https://www.arm.gov/capabilities/science-data-products/vaps/swfluxanal]

**SURFRAD (Surface Radiation Budget Network)** — NOAA Global Monitoring Division, established 1993, U.S. continental stations. Uses the ARM RadFlux methodology (Long & Ackerman algorithm) through its "Radiative Flux Analysis" (RadFlux) product. [SOURCE: search snippet via https://www.esrl.noaa.gov/gmd/grad/surfrad/overview.html and PMC paper]

**Key insight:** These three networks do not independently develop clear-sky algorithms. They share the Long & Ackerman (2000) / ARM SW flux analysis algorithm as a common foundation. The RadFlux product is the operational implementation that runs at both ARM and SURFRAD sites, and was expanded to 42 BSRN sites.

---

## 3. ARM SW Flux Analysis Algorithm (SWFLUXANAL)

**Reference:** Long, C.N. and Gaustad, K.L. (2004). "The Shortwave (SW) Clear-Sky Detection and Fitting Algorithm: Algorithm Operational Details and Explanations." ARM TR-004. DOE/SC-ARM/TR-004.
- OSTI record (TR-004): https://www.osti.gov/biblio/1020737
- OSTI record (TR-004.1 update): https://www.osti.gov/biblio/1808704
- ARM page: https://www.arm.gov/capabilities/science-data-products/vaps/swfluxanal

### 3.1 Detection Phase

The algorithm applies **four tests** (inherited from Long & Ackerman 2000 — see `long-ackerman-2000-summary.md`) to 1-minute measurements of total shortwave (GHI) and diffuse shortwave (DHI):

1. **Normalized total shortwave magnitude test** — GHI within site-specific bounds as function of solar zenith angle
2. **Maximum diffuse shortwave test** — DHI below a site-specific maximum threshold
3. **Rate-of-change test** — GHI first-difference between consecutive minutes below a threshold (~8 W/m²/min at ARM SGP)
4. **Normalized diffuse ratio (NDR) variability test** — standard deviation of DHI/GHI ratio over an 11-minute window below a threshold (~0.0012 dimensionless)

All four tests must be passed simultaneously. The algorithm was designed for **sub-15-minute resolution data** (nominally 1-minute). [SOURCE: PMC paper https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/ — direct quote of four-test structure]

### 3.2 Fitting Phase

Once clear-sky periods are identified, the algorithm fits an **exponential function of cosine(solar zenith angle)**:

```
F = A * exp(B / cos(Z))
```

where:
- `F` is either GHI or DHI
- `A` is an amplitude coefficient that varies **day to day** (capturing aerosol and water vapor variation)
- `B` is a shape coefficient
- `Z` is solar zenith angle

This fitting is done separately for GHI and DHI. The amplitude factor `A` captures day-to-day atmospheric variation implicitly — a hazy day has a lower `A` than a pristine day. [SOURCE: ARM SWFLUXANAL page; PMC paper; search snippets describing ARM TR-004 content]

### 3.3 Minimum Sample Requirement for a Valid Daily Fit

**Critical threshold: 110 minutes of detected clear-sky data** (at 1-minute resolution) are required for the algorithm to perform a daily curve fit. A day meeting this threshold is called a "**clear enough day**."

- For other data resolutions, the minimum scales: divide 110 by the data interval (minutes) and round up. So for 5-minute data: ceil(110/5) = 22 samples minimum.
- The threshold is set in the algorithm's **configuration file** and can be adjusted by the operator.
- [SOURCE: Web search snippet attributed to ARM TR-004: "it is required that 110 minutes of data (data points) be detected as clear for fitting a given day" — https://www.osti.gov/biblio/1020737]
- [STATUS: Confirmed from search snippet citing TR-004; primary text not readable (binary PDF)]

### 3.4 Two Operating Modes: Daily Fit vs. One-Fit-For-All

The algorithm has **two operational modes** depending on site climate:

**Mode 1: Daily fit** (for sites with semi-frequent clear skies)
- A separate set of fit coefficients (A, B) is determined for each "clear enough" day
- Days without enough clear-sky data have coefficients **interpolated** between neighboring clear-sky days
- Interpolated fits produce clear-sky estimates with ~3% RMS uncertainty (due to undetected water vapor and aerosol changes between fitted days) [SOURCE: search snippet citing ARM TR-004]

**Mode 2: One-fit-for-all** (for persistently cloudy sites, e.g., ARM Tropical Western Pacific)
- A single set of fit coefficients represents the **entire data period** (not daily)
- For this mode, the minimum sample threshold is much lower: "15 to 30 minutes equivalent minimum number of detected clear-sky values" [SOURCE: search snippet citing ARM TR-004]
- The algorithm was extended to support persistently cloudy sites after initial deployment at ARM SGP (Southern Great Plains) [SOURCE: ARM SWFLUXANAL page]

### 3.5 Stratification

**The ARM algorithm does NOT stratify by season.** It fits coefficients **per day** using the cosine(solar zenith angle) as the independent variable, which implicitly captures the diurnal cycle. Seasonal variation in aerosol loading and water vapor is captured implicitly through day-to-day variation in the amplitude coefficient `A`.

No explicit time-of-day or seasonal binning is applied. The solar zenith angle dependence in the exponential fit handles diurnal variation continuously rather than discretely. [SOURCE: ARM TR-004 description in multiple search results; confirmed in PMC paper]

### 3.6 Handling of Persistent Haze

The ARM algorithm does NOT distinguish between clear-but-hazy days and pristine clear days. A day with stable, smooth aerosol loading passes all four detection tests and is treated as "clear sky" for fitting purposes. The amplitude coefficient `A` will be lower on hazy days, producing a lower fitted clear-sky curve — this is **by design**. The fit tracks actual atmospheric conditions.

The ~3% interpolation uncertainty between clear-sky fitted days is partly caused by undetected aerosol and water vapor changes. [SOURCE: search snippet citing ARM TR-004]

---

## 4. BSRN Quality Control

**References:**
- Driemel, A. et al. (2018). "Baseline Surface Radiation Network (BSRN): structure and data description (1992–2017)." *Earth System Science Data*, 10, 1491–1501. https://doi.org/10.1594/PANGAEA.880000
- Long & Dutton (2002). "BSRN Global Network recommended QC tests, V2.0." (Referenced at https://bsrn.awi.de/other/publications/establishment-and-development-of-the-bsrn/)
- García et al. (2019). "Description of the BSRN station at Izaña Observatory (2009–2017)." *Geoscientific Instrumentation, Methods and Data Systems*, 8, 77–103. https://gi.copernicus.org/articles/8/77/2019/

### 4.1 QC Test Structure

BSRN uses a two-tier QC system for radiation measurements:
1. **Physically Possible Limits (PPLs)** — absolute bounds that can never be exceeded physically
2. **Extremely Rare Limits (ERLs)** — statistical bounds that would be extremely unusual
3. **Component consistency comparisons** — cross-checks between GHI, DHI, and DNI

At the Izaña station (which has both pristine and Saharan-dust-affected sky conditions), clear-sky periods are identified using "an adaptation of Long and Ackerman's method based on 1-minute SWD and DIF measurements" with the same four tests as ARM. [SOURCE: FETCHED — Izaña paper https://gi.copernicus.org/articles/8/77/2019/]

### 4.2 Clear-Sky Baseline at BSRN Sites

During identified clear-sky periods, instantaneous and daily measurements are compared against **LibRadtran radiative transfer model simulations**. Required inputs include:
- Precipitable water vapor
- Aerosol optical depth (from AERONET or co-located sunphotometer)
- Total ozone column
- Surface albedo

This means BSRN sites use a **physics-driven model** as the clear-sky reference, not a data-learned upper envelope. The model is parameterized with in-situ atmospheric measurements. [SOURCE: FETCHED — Izaña paper]

### 4.3 BSRN Data Availability Standard

Quality control requires "at least 95% of the original records available for an hourly or daily mean" and "at least 80% of daily means available for a monthly mean." These are data-completeness thresholds, not clear-sky-day count thresholds. [SOURCE: PMC paper https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/]

### 4.4 Persistent Haze at BSRN Sites

The Izaña station periodically operates "under the effects of the Saharan Air Layer characterized by high mineral dust content" but the paper does not describe a separate algorithmic path for these conditions. The Long & Ackerman detection tests are applied uniformly; high-dust days that are smooth in GHI/DHI pass the tests and are treated as clear sky. The LibRadtran model comparison uses measured AOD as input, so the physics model accounts for aerosol loading explicitly. [SOURCE: FETCHED — Izaña paper]

---

## 5. SURFRAD RadFlux Analysis Product

**References:**
- Augustine, J.A. et al. (2005). "An Update on SURFRAD — The GCOS Surface Radiation Budget Network for the Continental United States." *Journal of Atmospheric and Oceanic Technology*, 22, 1460–1472. DOI: 10.1175/JTECH1806.1
- Long, C.N. et al. (2006). Cloud fraction formulation from diffuse solar measurements (implemented in RadFlux)
- ARM TR-228: DOE/SC-ARM-TR-228 — RADFLUXANAL technical report https://www.osti.gov/servlets/purl/1569477/ [BINARY PDF — not text-extractable]
- Dataset record: https://data.ucar.edu/en/dataset/noaa-gml-surfrad-radflux-analysis-products-radiation-and-cloud-iss-site

### 5.1 What RadFlux Does

The Radiative Flux Analysis (RadFlux) product is the operational implementation of the ARM SW flux analysis algorithm at SURFRAD sites. It:

1. **Detects clear-sky periods** using the Long & Ackerman four-test algorithm (same as ARM SWFLUXANAL)
2. **Fits exponential functions** of cos(solar zenith angle) to detected clear-sky GHI and DHI
3. **Produces continuous clear-sky estimates** by interpolating fitted coefficients to non-clear-sky periods
4. **Infers cloud fraction** by comparing measured diffuse irradiance to modeled clear-sky diffuse (based on Long et al. 2006 formulation validated against Total Sky Imager data, accuracy ±10%)

**Key quote:** "RADFLUX processing first identifies clear-sky time periods using the magnitude and variability of the diffuse and total SW irradiance that have been normalized to remove the impacts of the diurnal cycle." [SOURCE: web search snippet from SURFRAD/RadFlux description]

### 5.2 Normalization Removes Diurnal Cycle

This is the key design decision: detection tests are applied to **normalized** quantities (GHI divided by cos(Z), DHI divided by cos(Z)^b) rather than raw irradiance values. This means the diurnal cycle (sun rising and setting) does not cause false detections. Variability at any time of day is assessed on the same scale. This is the mechanism by which the algorithm avoids needing separate time-of-day bins for the detection phase.

### 5.3 Clear-Sky Outputs

RadFlux produces:
- Clear-sky shortwave downwelling (estimated)
- Clear-sky longwave downwelling (when nighttime algorithm is active)
- Cloud fraction (0–1 scale)
- Net radiation
- Transmissivity

[SOURCE: dataset record https://data.ucar.edu/en/dataset/noaa-gml-surfrad-radflux-analysis-products-radiation-and-cloud-iss-site]

---

## 6. Sandia SAND2012-2389

**Full citation:** Reno, M.J., Hansen, C.W., and Stein, J.S. (2012). "Global Horizontal Irradiance Clear Sky Models: Implementation and Analysis." Sandia National Laboratories Technical Report SAND2012-2389. DOI: 10.2172/1039404.
- Sandia page: https://www.sandia.gov/research/publications/details/global-horizontal-irradiance-clear-sky-models-implementation-and-analysis-2012-03-01/
- UNT Digital Library: https://digital.library.unt.edu/ark:/67531/metadc831646/
- OSTI (binary PDF): https://www.osti.gov/servlets/purl/1039404

**Access status:** PDF is binary-compressed and not text-extractable. Metadata and abstract only. Key findings below are sourced from multiple search results consistently describing the report. [STATUS: SEARCH-SNIPPET — not read from primary text]

### 6.1 Scale of Validation

- **30 sites worldwide**, ~**300 site-years** of data [CONFIRMED from multiple search results]
- Sites chosen to span diverse climates and altitudes

### 6.2 Clear-Sky Detection for Validation

The report includes **a new algorithm for automatically identifying clear-sky periods** in a GHI time series (this is the precursor to Reno & Hansen 2016). The purpose was to extract reference periods for model evaluation.

### 6.3 Key Finding on Temporal Stratification

**"Simpler models exhibit errors that vary with time of day and season, whereas errors for complex models vary less over time."** [CONFIRMED from search snippets]

**Implication for our design:** This finding validates the importance of stratification. Simple parameterizations (like a fixed Kcs threshold) will have errors that vary by time of day and season. If we want a stratification-free approach to work, we need a model-driven baseline (like Ineichen-Perez or REST2) rather than a fixed empirical threshold.

### 6.4 Complex vs. Simple Models

"Complex models that correctly account for all atmospheric parameters are slightly more accurate, but at low elevations, comparable accuracy can be obtained from some simpler models." [SOURCE: Sandia publications page]

---

## 7. Reno & Hansen (2016) — GHI-Only Clear-Sky Detection

**Full citation:** Reno, M.J. and Hansen, C.W. (2016). "Identification of periods of clear sky irradiance in time series of GHI measurements." *Renewable Energy*, 90, 520–531. DOI: 10.1016/j.renene.2015.12.031.
- OSTI record: https://www.osti.gov/pages/biblio/1239983
- OSTI PDF (binary): https://www.osti.gov/servlets/purl/1239983
- pvlib implementation: https://pvlib-python.readthedocs.io/en/stable/reference/generated/pvlib.clearsky.detect_clearsky.html

**Access status:** OSTI PDF is binary-compressed. Details below from pvlib documentation (FETCHED) and search snippets. [STATUS: FETCHED — pvlib docs; SEARCH-SNIPPET for paper details]

### 7.1 Algorithm Overview

Reno & Hansen extend the Long & Ackerman framework to **GHI-only** (no diffuse measurement required). Instead of comparing GHI to site-derived thresholds, it compares measured GHI to a **clear-sky model output** (e.g., Ineichen-Perez, Bird, or similar).

### 7.2 The Five Criteria (from pvlib docs — FETCHED)

Applied over a **10-minute sliding window** with **minimum 3 data points** per window:

| Criterion | Parameter | Default threshold | What it tests |
|-----------|-----------|-------------------|---------------|
| c1: mean_diff | mean_diff | 75 W/m² | Mean(measured) ≈ Mean(model × α) |
| c2: max_diff | max_diff | 75 W/m² | Max(measured) ≈ Max(model × α) |
| c3: line_length | lower/upper_line_length | −5 to +10 | Curve shape agreement |
| c4: var_diff | var_diff | 0.005 Hz | Normalized std dev of rate-of-change |
| c5: slope_dev | slope_dev | 8 W/m² | Max successive value change |

### 7.3 Iterative Scaling

An **iterative scaling factor α** is applied to the clear-sky model output to account for systematic bias (e.g., model calibration error, site-specific atmosphere). The algorithm:
1. Identifies initial clear periods
2. Estimates α from those periods (ratio of measured to modeled)
3. Scales model output by α
4. Re-detects clear periods with the adjusted model
5. Repeats until convergence (max 20 iterations by default)

### 7.4 Minimum Sample Requirement

"Each window must contain at least three data points." For default 10-minute windows with 1-minute data, this means at least 3 samples per window. [SOURCE: FETCHED — pvlib docs]

This is a **per-window** minimum, not a per-day or per-month requirement. There is no stated minimum for how many clear-sky windows must be identified before α is considered converged.

### 7.5 Stratification

**None explicit.** No seasonal or time-of-day stratification. The normalization against cos(Z) via the clear-sky model handles diurnal variation. The algorithm is applied as a single pass over the time series.

### 7.6 Persistent Haze

Hazy days with stable GHI curves will tend to pass the criteria at a reduced value of α. The algorithm will classify these as "clear sky" with the model scaled down by α. This is the same behavior as Long & Ackerman. A separate measurement (e.g., AOD or visibility) would be required to distinguish hazy-clear from pristine-clear.

---

## 8. Renner et al. (2019) — Quantile Regression Approach

**Full citation:** Renner, M., Wild, M., Schwarz, M., and Kleidon, A. (2019). "Estimating Shortwave Clear-Sky Fluxes From Hourly Global Radiation Records by Quantile Regression." *Earth and Space Science*, 6(8), 1532–1546. DOI: 10.1029/2019EA000686.
- Wiley page (HTTP 403): https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2019EA000686
- ETH Zurich PDF (binary): https://iacweb.ethz.ch/doc/publications/Renner_et_al-2019-Earth_and_Space_Science.pdf
- R package GitHub: https://github.com/laubblatt/cleaRskyQuantileRegression [FETCHED — README]
- Zenodo: https://zenodo.org/records/3380327 [FETCHED — metadata]

**Access status:** Full paper text not accessible (Wiley 403, ETH PDF binary). Methodology confirmed from search snippets, R package README, and Zenodo record. [STATUS: SEARCH-SNIPPET + FETCHED-README]

### 8.1 Core Concept

Renner et al. propose an **alternative to point-in-time detection methods**. Instead of identifying individual clear-sky moments, they fit an **upper quantile regression line** to a scatter plot of:
- X axis: Potential solar radiation (TOA, i.e., extraterrestrial irradiance after solar geometry correction)
- Y axis: Observed surface GHI (hourly or half-hourly)

In clear-sky conditions, observed GHI forms a linear upper boundary of this scatter (it tracks TOA minus atmospheric losses). The slope of this upper boundary is the **fractional clear-sky transmission** (τ_cs).

### 8.2 Quantile Used

**The 85th percentile** (τ = 0.85) is the default. [SOURCE: search snippet "the only free parameter is the quantile ω used in the quantile regression (here 85%)"; confirmed in R package README: `tau = 0.85` in examples]

This choice means the clear-sky baseline is set at the level exceeded by only 15% of observed GHI values relative to TOA — in other words, clear-sky observations are expected to cluster in the upper 15% of the distribution relative to potential radiation.

### 8.3 Stratification: Monthly Windows

The quantile regression is performed on **monthly samples** (one month of hourly data per regression). This provides:
- Seasonal variation: separate fits for each calendar month
- Sufficient sample sizes at hourly resolution even in partly cloudy climates
- A smooth seasonal trend in clear-sky transmission

For sites with persistent cloud cover, the R package "performs the regression for different time windows, which can be required when there is persistent cloud cover," with window length "determined internally by the goodness of fit (R²) and deviations of the monthly τ from the site mean τ." [SOURCE: FETCHED — GitHub README]

### 8.4 Validation Scale

The method was validated against "42 stations of the Baseline Surface Radiation Network" using "very good agreement" with the standard Long & Ackerman clear-sky identification method. [SOURCE: search snippet]

### 8.5 Handling Persistent Haze

**This is the key advantage of the quantile approach over point-detection methods.** In a monthly sample containing both clear and hazy days:
- On pristine clear days: GHI/TOA ratio is high (near 1.0 × τ_cs)
- On uniformly hazy days: GHI/TOA ratio is moderate (below τ_cs)
- The 85th quantile regression will estimate the **upper boundary** — which captures the cleanest days in the month

However, if **all** days in a month are uniformly hazy (no pristine clear days), the 85th percentile will reflect the hazy-clear transmission, not pristine clear-sky transmission. This is an acknowledged limitation — the method estimates the best conditions observed, not an absolute physical clear-sky value.

### 8.6 Sample Size Requirement

No explicit minimum sample-per-month threshold is documented in the available sources. At hourly resolution with a full month of data (≈720 daylight-hour samples in summer), this is well-sufficient. The adaptive windowing for persistently cloudy sites suggests the method can work with fewer samples if the goodness of fit is adequate.

---

## 9. Correa (2022) — Daily Transmittance Threshold Method

**Full citation:** Correa, P. et al. (2022). "A Method for Clear-Sky Identification and Long-Term Trends Assessment Using Daily Surface Solar Radiation Records." *Earth and Space Science*, 9. DOI: 10.1029/2021EA002197.
- Wiley page (HTTP 403): https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2021EA002197

**Access status:** Wiley 403 Forbidden. Details from search snippets only. [STATUS: SEARCH-SNIPPET]

### 9.1 Motivation

Works with **daily mean** surface solar radiation (not sub-daily or 1-minute), making it applicable to legacy datasets where only daily aggregates exist. Designed to detect multi-decadal trends in surface solar radiation (Global Dimming / Brightening research).

### 9.2 Method

- Calculates **station-specific daily transmittance thresholds for every calendar month** (12 thresholds per site)
- Days with transmittance below the threshold for that month are flagged as **cloudy** and excluded
- Days above the threshold are flagged as **clear sky**
- Thresholds are calibrated using daily mean **fractional cloud cover** from satellite data

### 9.3 Stratification

**Monthly stratification is the core mechanism.** Twelve separate thresholds (one per calendar month) capture seasonal variation in atmospheric transmission (water vapor, aerosol, ozone). This is the simplest form of seasonal stratification that is practically implemented. [SOURCE: search snippet]

### 9.4 Sample Requirements

Not explicitly stated in available sources. The method was designed for "existing long-term daily mean surface solar radiation measurement data from around the globe" — implying it works with multi-year datasets of daily means.

---

## 10. Cross-Cutting Findings

### 10.1 The Diurnal Question: Are Time-of-Day Bins Required?

**Summary: Explicit time-of-day bins are NOT used in any of the reviewed methods. The solar zenith angle is the universal substitute.**

All methods handle diurnal variation by normalizing to cos(solar zenith angle) or to TOA irradiance (which already encodes solar geometry). This converts the problem from "GHI varies by time of day" to "GHI/GHI_expected varies by atmospheric state." The normalized quantity is then uniform across the diurnal cycle.

| Method | How diurnal variation is handled |
|--------|----------------------------------|
| Long & Ackerman (2000) / ARM | Exponential fit of GHI vs cos(Z); NDR = (DHI/GHI)/cos(Z)^b |
| BSRN QC | LibRadtran model provides geometry-corrected reference |
| Reno & Hansen (2016) | Clear-sky model provides cos(Z)-corrected reference; α scales it |
| Renner et al. (2019) | Scatter: GHI vs TOA (= f(cos(Z))) — upper quantile of this normalized scatter |
| Correa (2022) | Daily transmittance (GHI_daily / expected_daily) — geometry already integrated |

**None of these methods divide the day into morning/afternoon/noon bins.** The zenith-angle normalization makes such bins unnecessary.

### 10.2 The Seasonal Question: Is Seasonal Stratification Required?

**For detection algorithms (Long & Ackerman, Reno & Hansen): No — not explicit.** Seasonal variation in aerosol and water vapor is absorbed into day-to-day variation of the amplitude coefficient A (Long & Ackerman) or the scaling factor α (Reno & Hansen).

**For baseline construction from long records (Renner 2019, Correa 2022): Yes — monthly bins.** When the goal is to characterize the clear-sky transmission level across a long time series (months to years), monthly stratification is the standard. Reasons:
- Seasonal variation in aerosol loading (dust seasons, agricultural burning, etc.)
- Seasonal variation in atmospheric water vapor
- Seasonal variation in ozone
- The Sandia SAND2012-2389 finding: simpler models show time-of-day and seasonal error variation; complex models don't. This implies seasonal effects are real.

### 10.3 Sample Size Requirements — What the Literature Says

| Method | Minimum samples for valid baseline | Context |
|--------|-----------------------------------|---------|
| ARM SWFLUXANAL (daily fit mode) | **110 minutes** (at 1-minute resolution) per day | Minimum for a "clear enough day" to fit daily coefficients |
| ARM SWFLUXANAL (one-fit-for-all mode) | **15–30 minutes** equivalent at site data resolution | For persistently cloudy sites; one set of coefficients for entire record |
| Reno & Hansen (2016) | **3 samples** per 10-minute window | Per-window minimum only; no per-day minimum stated |
| Renner et al. (2019) | Not specified; presumably one month of hourly data | Monthly quantile regression; adaptive windowing for persistent cloud |
| ARM TR-004 interpolation | Coefficients are interpolated between fitted days; ~3% RMS error from interpolation | Suggests at least one clear-sky day every few days is needed for low interpolation error |

**Key inference not directly stated in literature:** The ARM interpolation uncertainty of ~3% "caused by undetected column water vapor and aerosol changes normally occurring between clear-sky fitted days" implies that sites with fewer than ~1 clear day per week will have increasingly uncertain baselines. The literature does not state a minimum number of clear-sky days per month, but the 3% interpolation error figure is a practical quality indicator.

### 10.4 Quantile-Based Approaches — Are They Used?

**Yes — but only in one major published method (Renner et al. 2019).**

The Long & Ackerman / ARM / SURFRAD / BSRN mainstream approach is **NOT quantile-based**. It is detection-based: identify clear-sky moments point-by-point, then fit a physics-motivated curve through them.

Renner et al. (2019) introduced the quantile regression alternative, specifically for cases where:
- Only daily or hourly data are available (not 1-minute)
- Explicit clear-sky detection is not feasible
- The goal is monthly-scale clear-sky characterization rather than moment-by-moment detection

The 85th percentile was chosen empirically and validated against 42 BSRN stations. The quantile approach is complementary to, not a replacement for, the mainstream detection approach.

### 10.5 Persistent Haze Sites

No network uses a fundamentally different algorithm for persistently hazy sites. The practical adaptations are:

1. **ARM one-fit-for-all mode:** For sites where clear skies almost never occur (tropical maritime, permanently cloudy), fit a single set of coefficients from whatever clear moments can be detected. Accept higher uncertainty.
2. **Renner quantile regression:** Uses the upper quantile of observed data, so the "baseline" tracks the clearest conditions in the dataset. In perpetually hazy climates, the baseline reflects hazy-clear, not pristine-clear.
3. **BSRN LibRadtran approach:** Uses measured AOD as a model input, so the modeled baseline accounts for aerosol loading explicitly. This is the only method that can produce a "pristine atmosphere" reference even when the actual atmosphere is hazy.

**Critical implication for our system:** If our goal is to detect haze relative to a clean-sky baseline, we need a baseline that represents the **pristine atmosphere**, not the typical atmosphere. The ARM fitting algorithm's amplitude coefficient A varies day to day — hazy days lower A, clean days raise it. Our Kcs baseline should target the **maximum (cleanest)** A values, not the average A across all identified "clear" days.

---

## 11. Assessment: Minimum Defensible Approach for a Consumer PWS

### 11.1 What the Literature Requires vs. What We Have

| Requirement | Research network standard | Consumer PWS reality |
|-------------|--------------------------|---------------------|
| Data resolution | 1-minute | 5-minute or worse |
| Sensor type | Precision thermopile pyranometer | Silicon photodiode (cheap), likely no shadow-band for DHI |
| DHI measurement | Required by Long & Ackerman | Not available |
| AOD / water vapor | Available from co-located instruments | Not available |
| Data record length | Years to decades | Weeks to months |

**Conclusion:** The full Long & Ackerman algorithm cannot be implemented on a consumer PWS — it requires DHI (diffuse irradiance from a shadow-band pyranometer). The Reno & Hansen (2016) / pvlib approach is the closest match: GHI-only, 10-minute windows, comparison against a clear-sky model.

### 11.2 The Defensible Minimum Approach

**Recommended approach:** A hybrid of Reno & Hansen (2016) detection + Renner et al. (2019) upper-quantile accumulation.

**Step 1: Moment-by-moment detection (Reno & Hansen criteria)**
- Compare measured GHI to clear-sky model (Ineichen-Perez or similar)
- Use a 10-minute sliding window (or equivalent in 5-minute data)
- Apply 5 criteria: mean_diff ≤ 75 W/m², max_diff ≤ 75 W/m², slope_dev ≤ 8 W/m², line_length within bounds, var_diff ≤ 0.005
- Minimum 3 samples per window
- Iteratively estimate scaling factor α

**Step 2: Kcs baseline accumulation (quantile-inspired)**
- Accumulate Kcs samples from windows that passed the clear-sky detection test AND have Kcs in the expected "clean sky" range (e.g., Kcs ∈ [0.85, 1.10])
- Use the **90th or 95th percentile** of accumulated Kcs samples as the baseline, rather than the mean — this preferentially weights the cleanest observed days over hazy-clear days
- Stratify by **solar zenith angle bins** (e.g., 10° bins from 10° to 80°), NOT by time of day explicitly — zenith angle is the correct normalization variable
- Accumulate for at least **30 days** before treating the baseline as initialized (to capture a range of clear-sky conditions), or equivalently, collect at least **20 distinct "clear enough" periods** across at least 5 different days

**Step 3: Seasonal adaptation**
- Compute separate baselines for each **calendar month** (or 3-month rolling window), following Correa (2022)
- Seasonal stratification matters because summer atmospheric loading differs from winter — a baseline calibrated in July should not be used in December
- In practice, with a consumer PWS that has months of data, use a 90-day rolling window rather than calendar months

### 11.3 Sample Size: How Many Clean-Sky Observations Do We Need?

Based on ARM TR-004 guidance and Renner (2019) validation:

- **Per calibration period (e.g., monthly):** Aim for at least **10–20 distinct clear-sky episodes** (where one "episode" = one day or partial day with >110 minutes of detected clear-sky at 1-minute res, or equivalent at lower resolution)
- **Per solar zenith angle bin (if binning):** At least **5–10 samples** per 10° bin. With a 5-minute data interval, a typical clear-sky day provides ~12 samples per 10° zenith bin (assuming the bin covers ~1 hour of the day)
- **Initialization period:** A minimum of **30 days** of data collection before the baseline is used operationally, targeting climates with at least occasional clear-sky conditions. For very cloudy climates, extend to 90 days.

**For our specific implementation (Kcs baseline as scalar, no binning):**
- If we choose NOT to bin by zenith angle (simpler but less accurate): accumulate at least **50–100 Kcs samples** from diverse times of day and solar elevations before the baseline is considered converged. The 90th percentile of these samples becomes the Kcs_baseline.
- The Sandia SAND2012-2389 finding implies this approach will have time-of-day and seasonal error — acceptable for consumer PWS, not acceptable for research-grade calibration.

### 11.4 Self-Audit of This Assessment

**What this assessment gets right:**
- Correctly identifies that no network uses explicit time-of-day bins — cosine(Z) normalization is universal
- Correctly identifies monthly stratification as the seasonal norm in long-record methods
- Correctly identifies that quantile approaches (85th–95th percentile) are used in one peer-reviewed method (Renner 2019) and validated against 42 BSRN stations
- Correctly notes that the ARM algorithm's "110 minutes of clear-sky" threshold translates to a defensible minimum sample count

**What remains uncertain:**
- Whether the 85th vs. 90th vs. 95th percentile choice matters significantly for consumer PWS — no direct comparison study found
- Minimum sample count for convergence with a pure scalar Kcs baseline (unbinned) — this number (50–100) is inferred from the ARM daily-fit threshold scaled to our data, not directly from a cited study
- Whether zenith-angle binning is necessary given that we apply Kcs = GHI/GHI_model (the model already handles cos(Z)) — probably not, since the model normalization handles it

**Known gaps not addressed in this research:**
- How PWS silicon-photodiode spectral response bias affects Kcs (silicon sensors have different spectral sensitivity from broadband thermopile — this introduces a systematic offset in Kcs that the calibration would need to absorb)
- Whether the 3% ARM interpolation error applies at our time scale or whether it's an optimistic bound for research-grade sensors

---

## 12. Source URL Index

All sources fetched or searched for this document:

**ARM / SURFRAD / BSRN operational documents:**
- ARM SWFLUXANAL VAP: https://www.arm.gov/capabilities/science-data-products/vaps/swfluxanal
- ARM TR-004 (OSTI): https://www.osti.gov/biblio/1020737
- ARM TR-004.1 (OSTI): https://www.osti.gov/biblio/1808704
- ARM TR-228 RADFLUXANAL (OSTI): https://www.osti.gov/servlets/purl/1569477/
- BSRN publications: https://bsrn.awi.de/other/publications/establishment-and-development-of-the-bsrn/
- BSRN Izaña paper: https://gi.copernicus.org/articles/8/77/2019/
- SURFRAD overview: https://gml.noaa.gov/grad/surfrad/overview.html
- SURFRAD RadFlux dataset: https://data.ucar.edu/en/dataset/noaa-gml-surfrad-radflux-analysis-products-radiation-and-cloud-iss-site
- PMC paper (RadFlux / BSRN methodology): https://pmc.ncbi.nlm.nih.gov/articles/PMC7837425/

**Key papers:**
- Long & Ackerman 2000: https://doi.org/10.1029/2000JD900077 (paywalled — see long-ackerman-2000-summary.md)
- Reno, Hansen & Stein 2012 (SAND2012-2389): https://doi.org/10.2172/1039404
- Sandia publications page: https://www.sandia.gov/research/publications/details/global-horizontal-irradiance-clear-sky-models-implementation-and-analysis-2012-03-01/
- UNT Digital Library (SAND2012-2389): https://digital.library.unt.edu/ark:/67531/metadc831646/
- Reno & Hansen 2016: https://doi.org/10.1016/j.renene.2015.12.031 (OSTI: https://www.osti.gov/pages/biblio/1239983)
- pvlib detect_clearsky: https://pvlib-python.readthedocs.io/en/stable/reference/generated/pvlib.clearsky.detect_clearsky.html
- Renner et al. 2019: https://doi.org/10.1029/2019EA000686
- R package (cleaRskyQuantileRegression): https://github.com/laubblatt/cleaRskyQuantileRegression
- Renner Zenodo: https://zenodo.org/records/3380327
- Correa 2022: https://doi.org/10.1029/2021EA002197
- AERONET/parameterization (PMC): https://pmc.ncbi.nlm.nih.gov/articles/PMC4585779/
- Meyers et al. 2019 statistical fitting (arxiv): https://arxiv.org/abs/1907.08279
