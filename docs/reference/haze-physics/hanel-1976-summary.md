# Archive Summary: Hänel (1976) — Hygroscopic Aerosol Properties

**Archived:** 2026-06-21  
**Task:** R1.1 — Hänel Growth Equation & Hygroscopic Aerosol Properties  
**Archiver:** Research agent (claude-sonnet-4-6)

---

## Full Citation

Hänel, G. (1976). The properties of atmospheric aerosol particles as functions of the relative humidity at thermodynamic equilibrium with the surrounding moist air. In H. E. Landsberg and J. Van Mieghem (Eds.), *Advances in Geophysics*, Volume 19, pp. 73–188. Academic Press, New York.

**DOI:** 10.1016/S0065-2687(08)60142-9  
**DOI confirmed via:** Search engine metadata (ScientificResearch Publishing, ADS)

---

## Source Access Status

**PAYWALLED — Full text NOT accessed.**

The paper is a book chapter in *Advances in Geophysics* (Academic Press/Elsevier). The full text is behind the ScienceDirect paywall:  
https://www.sciencedirect.com/science/chapter/bookseries/abs/pii/S0065268708601429

The ADS abstract page returned no readable abstract:  
https://ui.adsabs.harvard.edu/abs/1976AdGeo..19...73H/abstract

**What WAS accessed:** The citation metadata and Hänel's formula as reproduced and applied in multiple open-access papers that cite this work. See "Sources Consulted" below.

---

## What the Paper Contains (from Citations and Reviews — NOT Full Text)

From multiple open-access papers that cite and apply Hänel (1976), the paper covers:

- Theoretical evaluation of aerosol particle mass, size, mean density, and mean refractive index as functions of relative humidity
- Techniques for measuring hygroscopic properties
- Coefficients of mass increase (growth coefficients) for different aerosol types
- Mean densities and refractive indices at thermodynamic equilibrium with moist air at various RH levels
- Measurement results for continental, marine, and urban aerosol types

The 1976 volume is 116 pages, making it a comprehensive monograph rather than a short paper.

---

## The Hänel Growth Equation — VERIFIED FROM CITING PAPERS

The one-parameter Hänel formula for hygroscopic growth of aerosol optical properties is widely reproduced in the literature citing this work. Two open-access lidar studies provide the exact formulation:

### Formula (from Fernández et al. 2018, ACP, citing Hänel 1976):

$$f_\beta^\lambda(RH) = \left[\frac{1 - RH/100}{1 - RH_{ref}/100}\right]^{-\gamma(\lambda)}$$

### Formula (from Granados-Muñoz et al. 2015 / AMT 2025 paper, citing Hänel 1976):

$$f_{scatt}(RH) = \left[\frac{1 - RH}{1 - RH_{ref}}\right]^{-\gamma}$$

**Variable Definitions:**

| Symbol | Definition | Units |
|--------|-----------|-------|
| f(RH) | Hygroscopic enhancement factor — ratio of aerosol optical property (backscatter or scattering coefficient) at elevated RH to value at reference RH | Dimensionless |
| RH | Relative humidity at the point of interest | % (0–100) |
| RH_ref | Reference relative humidity — typically the minimum observed RH in the measurement layer, or a dry reference (often 40%–60%); must be below deliquescence threshold | % |
| γ (lambda) | Hänel hygroscopicity parameter — empirical, dimensionless; larger γ = stronger hygroscopic growth; wavelength-dependent for backscatter applications | Dimensionless |

**Key property of the formula:**  
- At RH = RH_ref: f(RH) = 1.0 (by definition)
- As RH → 100%: f(RH) → ∞ (unbounded; valid only below ~95% RH in practice)
- The formula is monotonically increasing with RH for all γ > 0

**Sources confirming the formula:**
- Fernández et al. (2018), ACP 18:7001–7024 — Equation 3, explicitly citing Hänel (1976): https://acp.copernicus.org/articles/18/7001/2018/
- Granados-Muñoz et al. AMT 2025, citing Hänel (1976) for backscatter growth: https://amt.copernicus.org/articles/18/7629/2025/
- Chen et al. (2019), ACP 19:1327–1342 — "Hänel single-parameter model": https://acp.copernicus.org/articles/19/1327/2019/

### Note on the Size Growth Form

An alternative Hänel formulation describes the ratio of wet to dry particle radius. The size growth coefficient (ε or β) relates as: g(RH) = (r_wet / r_dry) = (1 + ε×W)^(1/3) where W is water uptake. This is the underlying microphysical form; the scattering enhancement formula above is the observable form derived from it. The AMT 2025 lidar paper cites Hänel (1976) with ε = 0.285 for water-soluble aerosols.

---

## γ (Gamma) Values — Verified from Open-Access Literature

**CRITICAL NOTE:** Specific γ values for individual pure aerosol species were NOT found in the original Hänel 1976 text (paywalled). The following values come from citing papers that APPLY the Hänel parameterization to measured ambient aerosol data.

### Values from AMT 2025 lidar paper (citing Hänel 1976):

| Aerosol Type / Condition | γ at 532 nm | Source |
|--------------------------|-------------|--------|
| Marine / sea salt mixture | 1.52 | AMT 2025, Table 2, Case 8 |
| Marine-dominated | 0.87 | AMT 2025, Table 2, Case 7 |
| Pollution-aged transport | 0.75 | AMT 2025, Table 2, Case 3 |
| Continental pollution | 0.50–0.53 | AMT 2025, Table 2, Cases 2&5 |
| Background / young aerosols | 0.30–0.38 | AMT 2025, Table 2, Cases 1,4,6 |

Source: https://amt.copernicus.org/articles/18/7629/2025/

### Values from Fernández et al. (2018, ACP SLOPE I campaign, Granada):

| Aerosol Composition | γ at 532 nm | γ at 355 nm | Method |
|--------------------|-------------|-------------|--------|
| Organic (62%) + sulfate (24%) + nitrate (10%) + BC (2%) | 0.48 ± 0.01 | 0.40 ± 0.01 | Remote sensing (lidar) |
| Organic (62%) + sulfate (24%) + nitrate (10%) + BC (2%) | 0.53 ± 0.02 | 0.45 ± 0.02 | Mie theory |
| Organic aerosol (Cabauw, Netherlands) | 0.59 | — | Literature citation |
| Marine particles | 0.88 | — | Literature citation |
| Dust (Xinzhou, China) | 0.24 | 0.12 | Literature citation |

Source: https://acp.copernicus.org/articles/18/7001/2018/

### Values from Granados-Muñoz et al. (Tellus B 2014, southern Spain):

| Campaign | γ (ambient aerosol) | f(RH=85%) |
|----------|---------------------|-----------|
| Winter (urban/continental mix) | 0.27 | 1.5 ± 0.2 |
| Spring (continental, Saharan dust influence) | 0.40 | 1.6 ± 0.3 |
| Saharan dust event (April 16) | Not specified | 1.3 ± 0.2 |

Source: https://b.tellusjournals.se/articles/10.3402/tellusb.v66.24536

### Historical reference cited in AMT 2025:

- Chazette & Liousse (2001), pollution aerosols: γ ≈ 0.26 at 532 nm
- Hänel (1976), water-soluble aerosols: ε = 0.285 (size growth equivalent — not directly γ for scattering)

### Summary of γ Ranges by Aerosol Type:

| Aerosol Category | γ Range (scattering) | Hygroscopicity |
|-----------------|----------------------|----------------|
| Sea salt / marine | 0.87 – 1.52 | Very high |
| Sulfate-dominated | ~0.50 – 0.75 | High |
| Mixed urban/continental | 0.27 – 0.59 | Moderate |
| Organic-dominated | 0.40 – 0.59 | Moderate |
| Mineral dust | ~0.12 – 0.24 | Low |

---

## Competitor Claim Verification: γ ≈ 0.25 (PM2.5) and γ ≈ 0.40 (PM10)

**Assessment: PARTIALLY CONSISTENT but oversimplified.**

- γ ≈ 0.25 for PM2.5 (fine combustion): This is consistent with winter/continental/dust-influenced conditions (range 0.24–0.40), but PM2.5 in urban/sulfate-dominated environments shows γ = 0.50–0.75, and organic-dominated PM2.5 shows γ = 0.40–0.59. The value 0.25 represents the LOW end of the PM2.5 range and would apply to dust-influenced or lightly hygroscopic fine aerosol, not typical urban combustion PM2.5.

- γ ≈ 0.40 for PM10 (coarse dust/sea salt): This is INCONSISTENT with sea salt (γ = 0.87–1.52). PM10 γ depends strongly on composition: dust-dominated PM10 has low γ (0.12–0.24), while sea-salt-dominated PM10 has very high γ (0.87–1.52). The single value 0.40 is not representative of PM10 as a class.

**VERDICT:** The competitor document's use of γ as a size-class property (PM2.5 vs PM10) conflates composition with size. γ is a composition property, not a size property. A sulfate aerosol in the PM2.5 range has γ ≈ 0.50–0.75; a dust aerosol in PM10 has γ ≈ 0.12–0.24. The values 0.25 and 0.40 do not reflect the Hänel literature as clean bins. However, they are within the plausible range for specific composition scenarios (combustion-influenced fine, or mixed coarse aerosol at a continental site).

---

## Deliquescence Relative Humidity (DRH) Values

DRH is the RH at which a solid aerosol particle abruptly absorbs water and transitions to an aqueous droplet, causing a discontinuous jump in size and scattering. The Hänel formula applies on the upper (wet) branch of the hysteresis curve above the DRH.

**Values compiled from open-access literature (not directly from Hänel 1976):**

| Aerosol Species | DRH | Source |
|----------------|-----|--------|
| Ammonium sulfate (NH₄)₂SO₄ | ~80% (79.9–80.4%) | ACP 2021 study; confirmed in AMT 2025 |
| Ammonium nitrate (NH₄NO₃) | ~62% | Literature consensus; cited in DRH review papers |
| Sodium chloride (NaCl) — sea salt proxy | 74.3 ± 1.5% | Zieger et al. 2017 (PMC5500848); DRH review |
| Actual sea salt (multi-component) | ~73.5% main transition; secondary uptake 10–15% RH | Zieger et al. 2017 |
| Ammonium bisulfate (NH₄HSO₄) | No sharp DRH; hygroscopic at all RH | Literature |
| Sulfuric acid (H₂SO₄) | No DRH — liquid at all RH | Literature |
| Mineral dust | No sharp DRH; near-insoluble, weak water uptake | Literature |
| Organic carbon (typical) | Broad or no DRH; partially hygroscopic | Literature; κ values vary widely 0.01–0.5 |

**Note on 70% and 85% RH thresholds:**

- **70% RH** is a common operational threshold used as a "pre-deliquescence" point. Below ~70%, most soluble aerosols are still in the solid or glassy state (for super-saturated solutions). The transition region begins around 60–75% depending on species.
- **85% RH** is used in IMPROVE and European aerosol monitoring networks as a standard reference point because it is above the DRH of all common soluble aerosols (all are fully deliquesced), while remaining below the fog/cloud formation regime. The ACP 2020 global model paper confirms: "Choosing RHwet=85% ensures that the reported f(RH) value represents the aerosol in the fully deliquesced state."
- The ACP 2015 paper (ACPD-15-2853) explicitly includes sections titled "Wavelength dependence of the scattering enhancement factor f(85%)" and "Parameterization of scattering enhancement factor f(RH)," confirming these are standard thresholds in the field.

---

## What Could NOT Be Verified from the Source

The following claims from citing papers could NOT be verified against the original Hänel (1976) text because the paper is paywalled:

1. **Original species-specific γ values** from Hänel's own measurements of continental, marine, and urban aerosols. The citing papers reference Hänel's data but do not reproduce the original tables.

2. **The exact derivation** of the growth equation from thermodynamic first principles. The equation is well-established in the literature, but the full thermodynamic derivation across 116 pages is not accessible.

3. **Whether Hänel (1976) itself discusses the 70% and 85% RH boundaries** as thresholds. These boundaries appear in modern literature citing Hänel but may be post-Hänel operational conventions rather than original Hänel conclusions.

4. **ε values (size growth coefficients) by aerosol type** from the original measurements. The citing literature references ε = 0.285 for water-soluble aerosol but this may be from Hänel (1980) rather than (1976).

---

## Sources Consulted (URLs Fetched)

1. ADS abstract page (blank content returned): https://ui.adsabs.harvard.edu/abs/1976AdGeo..19...73H/abstract
2. ScienceDirect chapter page (paywall): https://www.sciencedirect.com/science/chapter/bookseries/abs/pii/S0065268708601429
3. Fernández et al. (2018), ACP 18:7001 — EARLINET SLOPE I: https://acp.copernicus.org/articles/18/7001/2018/
4. AMT 2025 — Granados-Muñoz et al., humidity effects on lidar-derived aerosol optical properties: https://amt.copernicus.org/articles/18/7629/2025/
5. Chen et al. (2019), ACP 19:1327 — Haze events northern China: https://acp.copernicus.org/articles/19/1327/2019/
6. Granados-Muñoz et al. (2014), Tellus B 66:24536 — Southern Spain aerosol: https://b.tellusjournals.se/articles/10.3402/tellusb.v66.24536
7. Zieger et al. (2017), PMC5500848 — Sea salt hygroscopicity: https://pmc.ncbi.nlm.nih.gov/articles/PMC5500848/
8. ACP 2021 (9977) — Chemical composition effects on scattering: https://acp.copernicus.org/articles/21/9977/2021/
9. ACP 2020 (10231) — Global model-measurement evaluation f(RH): https://acp.copernicus.org/articles/20/10231/2020/
10. ACPD 15, 2853–2904 — Observations of RH effects on aerosol: https://acp.copernicus.org/articles/15/8439/2015/acpd-15-2853-2015.pdf (structure only, text unreadable)
