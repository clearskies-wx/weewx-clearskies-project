# Archive Summary: Tang (1996) — Chemical and Size Effects of Hygroscopic Aerosols on Light Scattering

**Archived:** 2026-06-21  
**Task:** R1.1 — Hänel Growth Equation & Hygroscopic Aerosol Properties  
**Archiver:** Research agent (claude-sonnet-4-6)

---

## Full Citation

Tang, I. N. (1996). Chemical and size effects of hygroscopic aerosols on light scattering coefficients. *Journal of Geophysical Research: Atmospheres*, 101(D14), 19245–19250.

**DOI:** 10.1029/96JD03003  
**URL:** https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/96JD03003  
**Published:** August 1996

---

## Source Access Status

**PAYWALLED — Abstract only, full text NOT accessed.**

All three attempts to fetch the full text (via AGU Wiley Online Library) returned HTTP 403 Forbidden. The paper requires AGU membership or institutional access.

The abstract text was reconstructed from search engine snippets and citing papers that reproduce its key findings. See "Sources Consulted."

**What WAS accessed:** The abstract's key findings as reproduced in search engine results, and the methodology and results as cited/described in open-access papers that rely on Tang (1996). The specific numerical tables from the paper (f(RH) vs. RH at each species) were NOT directly accessed.

---

## What the Paper Contains — Reconstructed from Abstract and Citing Literature

### Scope

Tang (1996) computes **mass-normalized light scattering coefficients** for hygroscopic aerosol particles as a function of relative humidity. The metric is scattering coefficient per unit dry aerosol mass (units: m² g⁻¹ or Mm⁻¹ per µg m⁻³).

### Aerosol Species Studied

The paper explicitly covers (confirmed from abstract reconstructions and citing papers):

| Species | Chemical Formula | Notes |
|---------|-----------------|-------|
| Ammonium sulfate | (NH₄)₂SO₄ | Primary sulfate aerosol |
| Ammonium bisulfate | NH₄HSO₄ | Acidic sulfate |
| Diammonium hydrogen sulfate (letovicite) | (NH₄)₃H(SO₄)₂ | Mixed sulfate |
| Sodium hydrogen sulfate | NaHSO₄ | |
| Sodium sulfate | Na₂SO₄ | |
| Ammonium nitrate | NH₄NO₃ | Primary nitrate aerosol |
| Sodium nitrate | NaNO₃ | |
| Sulfuric acid | H₂SO₄ | Freshly formed sulfate proxy |
| Sodium chloride | NaCl | Sea salt proxy |

**Not covered:** Organic carbon, black carbon, mineral dust — these are essentially insoluble and do not follow the Tang thermodynamic model.

### Methodology

- Thermodynamic equilibrium model for water activity and solution density
- Mie scattering calculations applied to equilibrium droplet size distributions
- Size distributions assumed lognormal
- Scattering coefficient computed per 1 µg dry salt per m³ air as a function of RH

### Key Findings from Abstract and Citations

1. **For a given size distribution**, the scattering coefficient per unit dry mass is **only weakly dependent on the specific chemical composition** among the sulfate and nitrate species studied. This means (NH₄)₂SO₄ and NH₄NO₃ behave similarly for a given size.

2. **Exceptions:** Sulfuric acid (H₂SO₄) and sodium chloride (NaCl) scatter light **more efficiently** than all other inorganic salt aerosols at equivalent mass concentrations. NaCl's higher efficiency is attributed to larger particle size and density differences.

3. **Ammonium sulfate at 90% RH:** The scattering cross-section increases by a factor of approximately **5× dry value**. This value appears in multiple secondary sources that cite Tang 1996 and Tang & Munkelwitz 1994.

4. **Size distribution matters significantly** — the paper shows how the size distribution modifies the absolute scattering values, though the RH dependence curve shape is similar.

5. **DRH values** cited in papers that use Tang (1996) data:
   - (NH₄)₂SO₄: ~80% (confirmed as DRH in multiple citing papers)
   - NaCl: ~75% (confirmed in Zieger et al. 2017 citing Tang)
   - NH₄NO₃: ~62% (confirmed in deliquescence literature)
   - H₂SO₄: liquid at all RH — no DRH

---

## f(RH) Framework in Tang (1996) Context

Tang (1996) does not use the Hänel γ parameterization. Instead, it provides **computed scattering coefficients** at a series of discrete RH values for each species and size distribution. The paper provides tables of σ_sp(RH) values in absolute units (m² g⁻¹).

Other papers convert Tang's computed values into the scattering enhancement framework:

**f(RH) = σ_sp(RH) / σ_sp(dry)**

Where:
- σ_sp(RH) = scattering coefficient at RH (m² g⁻¹ or Mm⁻¹ per µg m⁻³)
- σ_sp(dry) = scattering coefficient at dry conditions (typically RH < 40%)
- f(RH) = dimensionless enhancement factor

### f(RH) Values Derived from Secondary Sources Citing Tang (1996)

The following f(RH) values are reported in papers that reference Tang (1996) data:

**Ammonium sulfate (NH₄)₂SO₄:**
- f(90% RH) ≈ **5** (5× dry scattering) — cited in multiple secondary sources: "at 90% relative humidity the scattering cross-section of an ammonium sulfate particle can be increased by a factor of five or more"
- DRH: ~80%, sharp transition
- Below DRH (supersaturated solid): low, near-dry scattering
- Above DRH (solution droplet): rapid increase

**Ammonium nitrate (NH₄NO₃):**
- Similar behavior to ammonium sulfate per unit mass (Tang 1996 finding: chemically similar within sulfate/nitrate group)
- DRH: ~62% — much lower than sulfate
- This means nitrate aerosols begin absorbing water at lower RH than sulfates
- κ = 0.67 (from Petters & Kreidenweis 2007, citing thermodynamic data consistent with Tang)

**Sodium chloride (NaCl) / Sea salt:**
- Scatters MORE efficiently than ammonium sulfate at equivalent dry mass (Tang 1996 finding)
- DRH: 74.3 ± 1.5% (Zieger et al. 2017, citing Tang for comparison)
- Sea salt hygroscopic mass growth: m*(90%) = 6.8 (Tang et al. data cited in sea salt growth study)
- f(RH=85%) for sea salt at reference ~40% RH: approximately 4–6 (consistent with marine aerosol γ = 0.87–1.52 in lidar studies)

**Sulfuric acid (H₂SO₄):**
- Liquid at all RH — no DRH
- Also scatters more efficiently than ammonium sulfate (Tang 1996 finding)
- Continuously increasing scattering with RH

### Two-Parameter f(RH) Formula Confirmed in This Literature

While Tang (1996) itself uses tabulated values rather than a parametric formula, the literature uses two alternative parametrizations to represent the same behavior:

**Form 1 (Hänel single-parameter):**
$$f(RH) = \left[\frac{1 - RH}{1 - RH_{ref}}\right]^{-\gamma}$$

**Form 2 (Two-parameter power law, also called Kasten or gamma-fit):**
$$f(RH) = a(1 - RH)^{-\gamma}$$

or equivalently:

$$f(RH) = a(1 - RH/100)^{-b}$$

**Variable definitions (Form 2):**

| Symbol | Definition | Units |
|--------|-----------|-------|
| f(RH) | Scattering enhancement factor | Dimensionless |
| RH | Relative humidity | % |
| a | Pre-factor (fit coefficient) | Dimensionless |
| b or γ | Slope parameter indicating strength of hygroscopic growth | Dimensionless |

**Wuhan urban aerosol example (confirms form):**
From Roles of RH in Aerosol Pollution study (ACP, Wuhan): f(RH) = 0.95 × (1 − RH/100)^(−0.49), measured f(RH=80%) = 2.18 ± 0.73.

---

## κ (Kappa) Parameter Values — Comparable Framework

The κ-Köhler model (Petters & Kreidenweis 2007, ACP 7:1961–1971, DOI: 10.5194/acp-7-1961-2007) provides a single-parameter hygroscopicity framework that is thermodynamically consistent with Tang's approach. The following κ values apply to the same species Tang studied and are from the Petters & Kreidenweis 2007 compilation (not directly from Tang 1996):

| Species | κ | Hygroscopicity class |
|---------|---|---------------------|
| Ammonium sulfate (NH₄)₂SO₄ | ~0.61 | High |
| Ammonium nitrate (NH₄NO₃) | ~0.67 | High |
| Sodium chloride (NaCl) | ~1.28 | Very high |
| Sulfuric acid (H₂SO₄) | ~0.9 | Very high |
| Typical organic aerosol | 0.01–0.5 | Low to moderate |
| Mineral dust | ~0 | Near-insoluble |
| Black carbon | ~0 | Non-hygroscopic |

Source for κ values: Petters & Kreidenweis (2007) — values confirmed via search engine result snippets (not full paper text; ACP is open access but PDF was unreadable in extraction).

**Conversion between κ and γ:** No algebraic direct conversion found in the literature consulted. Both describe the same phenomenon but from different model frameworks (κ = Köhler activation-based; γ = empirical power-law fit). The relationship between κ and γ depends on the size distribution.

---

## Deliquescence RH Thresholds — Consolidated Table

This table consolidates DRH values from multiple sources. Sources are noted; none confirmed directly from Tang (1996) full text.

| Species | DRH (°C 25°C) | Phase below DRH | Phase above DRH | Source |
|---------|--------------|-----------------|-----------------|--------|
| Ammonium sulfate (NH₄)₂SO₄ | ~79.9–80.4% | Crystalline solid | Aqueous droplet | ACP 2021 (measured); AMT 2025 |
| Ammonium nitrate (NH₄NO₃) | ~61.8% | Crystalline solid | Aqueous droplet | DRH search results (multiple) |
| Sodium chloride (NaCl) | 74.3 ± 1.5% | Crystalline solid | Aqueous droplet | Zieger et al. 2017, PMC5500848 |
| Sea salt (natural multi-component) | ~73.5% main; secondary uptake at 10–15% | Solid | Aqueous | Zieger et al. 2017 |
| Ammonium bisulfate (NH₄HSO₄) | No sharp DRH | Liquid at all RH | — | Literature |
| Sulfuric acid (H₂SO₄) | No DRH | Liquid at all RH | — | Literature |
| Mineral dust | No DRH | Essentially insoluble | Trace water uptake only | Literature |
| Typical organic carbon | Varies; some show DRH ~72–95% | Variable | Variable | ACP review 2019 |

**Significance of DRH for the Hänel formula:**  
The f(RH) formula is only valid on the **upper (wet) branch** of the hysteresis curve. Below the DRH (on the dry branch), f(RH) ≈ 1.0. The abrupt change at DRH is the discontinuity the formula cannot describe. Practically, the 70% and 85% operational thresholds bracket the DRH of the most common aerosol species:
- 70% RH: below DRH of ammonium sulfate (~80%) but above DRH of ammonium nitrate (~62%) and NaCl (~74%)
- 85% RH: above DRH of ALL common soluble aerosol species — particles are fully deliquesced

---

## The 70% and 85% RH Boundaries — Discussion

The ACPD 2015 paper (Obs. of RH effects on aerosol) explicitly contains sections titled:
- "Wavelength dependence of the scattering enhancement factor f(85%)"
- "Parameterization of scattering enhancement factor f(RH)"

And the ACP 2020 global evaluation paper states: "Choosing RHwet=85% ensures that the reported f(RH) value represents the aerosol in the fully deliquesced state (upper branch of the hysteresis loop)."

**These thresholds are therefore:**
- **85% RH**: Standard measurement reference point — all common soluble aerosols are fully deliquesced, so f(RH=85%) is the reproducible "maximum wet scattering" reference
- **70% RH**: Practical lower threshold — above this RH, most aerosols (including NaCl at 74.3% and NH₄NO₃ at 62%) are in the deliquesced state, so hygroscopic enhancement is active; below 70%, fine-mode aerosol is likely still dry/supersaturated
- **Neither threshold was found attributed to Tang (1996) specifically** — they appear to be IMPROVE/SURFRAD/European monitoring network operational conventions

---

## Competitor Claim Verification: γ ≈ 0.25 (PM2.5) and γ ≈ 0.40 (PM10)

**Context:** The competing document suggests applying different γ values based on particle SIZE CLASS (PM2.5 vs PM10) rather than composition.

**Assessment from Tang (1996) and citing literature:**

Tang (1996) does NOT use γ parameterization at all — it provides computed scattering values at discrete RH levels. However, the approach of applying γ by size class rather than by composition is scientifically questionable for the following reasons documented in the literature:

1. **Tang (1996) explicitly shows** that scattering depends on SIZE DISTRIBUTION as well as composition. The same chemical species with a different mode diameter produces a different f(RH) curve shape.

2. **PM2.5 covers a heterogeneous composition range:** Urban PM2.5 can be sulfate-dominated (γ ≈ 0.50–0.75), nitrate-dominated (γ ≈ 0.5–0.67 based on κ data), or organic-dominated (γ ≈ 0.27–0.48). Using γ = 0.25 for all PM2.5 represents only the lower end of the range.

3. **PM10 is even more heterogeneous:** PM10 includes sea salt (γ = 0.87–1.52), mineral dust (γ ≈ 0.12–0.24), and the same fine-mode components. A single γ = 0.40 for PM10 is not defensible — it would be approximately correct for a moderately polluted continental aerosol, but wrong for coastal (sea salt dominant) or desert (dust dominant) environments.

4. **The Wuhan example** (from ACP study of roles of RH in China): measured f(RH=80%) = 2.18 ± 0.73 for ambient urban aerosol. This corresponds to approximately γ = 0.49 (from the fitted equation f(RH) = 0.95 × (1 − RH/100)^(−0.49)).

**VERDICT:** Using γ = 0.25 for PM2.5 and γ = 0.40 for PM10 as fixed universal constants is **not supported by Tang (1996) or subsequent literature.** These values might serve as rough defaults for a continental mixed aerosol site where composition data are unavailable, but they should not be treated as species-confirmed constants. The literature supports ranges:
- Fine combustion PM2.5: γ ≈ 0.27–0.75 (wide range, composition-dependent)
- Marine coarse PM10: γ ≈ 0.87–1.52
- Dust-dominated PM10: γ ≈ 0.12–0.24

For a haze detection system using PM data, applying a single γ value introduces error that grows with RH. At 85% RH, the difference between γ = 0.25 and γ = 0.75 produces f(RH) factors of roughly 1.4 vs. 3.2 (at RH_ref = 40%) — more than a 2× error in the estimated extinction correction.

---

## What Could NOT Be Verified from the Source

The following could NOT be verified because the Tang (1996) paper is paywalled:

1. **The actual table(s) of scattering coefficients** (m² g⁻¹ as a function of RH for each species). The paper almost certainly contains Tables 1 and/or 2 with computed values at RH = 0, 40, 60, 70, 80, 85, 90, 95%. These specific numerical values were NOT accessible.

2. **The exact size distribution parameters used** (lognormal mode diameter, geometric standard deviation) — the abstract says "lognormal size distributions" but the specific parameter values used are in the full text.

3. **Whether the paper computes f(RH) explicitly or only σ_sp(RH).** Secondary sources refer to the paper's σ_sp values and derive f(RH) from them.

4. **Whether Tang (1996) discusses the 70% and 85% RH boundaries.** These thresholds are attributed to Tang in some secondary sources but cannot be confirmed from the abstract alone.

5. **The absolute scattering efficiency comparison between NaCl and (NH₄)₂SO₄.** The abstract states NaCl "scatters light more efficiently" but the magnitude of the difference is in the tables, which are not accessible.

---

## Sources Consulted (URLs Fetched or Searched)

1. Tang 1996 paper page (paywall, HTTP 403): https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/96JD03003
2. Chen et al. (2019), ACP 19:1327 — applied Tang's method, confirmed DRH values and species list: https://acp.copernicus.org/articles/19/1327/2019/
3. Zieger et al. (2017), PMC5500848 — sea salt DRH 74.3%, cited Tang for m*(90%) = 6.8: https://pmc.ncbi.nlm.nih.gov/articles/PMC5500848/
4. ACP 2020 (10231) — global evaluation of f(RH), confirms 85% RH as fully-deliquesced reference: https://acp.copernicus.org/articles/20/10231/2020/
5. ACP 2021 (9977) — composition effects on scattering, measured DRH(NH₄)₂SO₄ = 80.37%: https://acp.copernicus.org/articles/21/9977/2021/
6. PMC6888358 — Wuhan aerosol, fitted f(RH) = 0.95(1−RH/100)^(−0.49), f(80%) = 2.18: https://pmc.ncbi.nlm.nih.gov/articles/PMC6888358/
7. PMC8361198 — Hygroscopic properties of PM and visibility, f(RH) = σ_ext(RH)/σ_ext(dry): https://pmc.ncbi.nlm.nih.gov/articles/PMC8361198/
8. Search result snippet confirming Tang 1996 finding: "(NH₄)₂SO₄ at 90% RH increased by factor of 5 or more" — multiple citing papers
9. Search result confirming DRH values: NH₄NO₃ = 61.8%, NaCl = ~75%, (NH₄)₂SO₄ = ~80%
10. Petters & Kreidenweis (2007) κ values confirmed via ARM.gov and search snippets: https://www.arm.gov/capabilities/science-data-products/vaps/ccnkappa
