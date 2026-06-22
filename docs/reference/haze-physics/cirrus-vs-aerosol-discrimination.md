# R4.1 — Literature Search: Ground-Based Aerosol vs Cirrus Discrimination

**Research date:** 2026-06-21  
**Task:** Determine whether ground-based broadband pyranometry (GHI-only) combined with surface PM2.5/PM10 can reliably distinguish aerosol haze layers from thin cirrus clouds.  
**Verdict summary:** Cannot reliably distinguish these two conditions with the instruments described. Partial discriminators exist but none individually provides certainty. Multiple additional instruments can resolve the ambiguity.

---

## 1. The Core Problem

Both thin cirrus clouds and aerosol layers (haze, smoke) produce nearly identical signatures in a broadband pyranometer record:

- Moderate, smooth GHI deficit relative to the clear-sky model
- Low variability (no rapid fluctuations) — both pass a Kv < 0.03 cloud-free test
- Both can persist for many hours
- Broadband extinction does not encode the wavelength-dependence needed to distinguish ice crystals from fine-mode particles

Furthermore, there is a well-documented disconnect between column aerosol burden and surface PM2.5 that makes "no elevated PM" an unreliable proxy for "no aerosol."

This is not a gap in our algorithm — it is a fundamental physical limitation of the measurement class.

---

## 2. What the Literature Says

### 2.1 Pyranometer Cloud-Type Estimation — Aerosol/Cirrus Confusion Is Documented

**Duchon and O'Malley (1999)** is the most directly relevant paper.

> "Estimating Cloud Type from Pyranometer Observations." *Journal of Applied Meteorology and Climatology*, Vol. 38, No. 1, pp. 132–141. DOI: 10.1175/1520-0450(1999)038<0132:ECTFPO>2.0.CO;2

The method classifies sky state using the mean clearness index (Kt) and standard deviation of GHI over a 21-minute moving window. Key finding:

> **"The presence of aerosols causes the pyranometer to overestimate the occurrence of cirrus and cirrus plus cumulus."**

The method and human observers agreed only about 45% of the time overall. The paper explicitly states that "aerosols can fool the pyranometer method into classifying clear sky into cirrus because their irradiance time series can be quite similar." The recommended fix is external data — specifically, ASOS visibility measurements — to flag haze events. The paper notes that estimating aerosols using only a pyranometer is not possible, and more elaborate instrumentation is required.

**Verification status:** Paper is paywalled (AMS, 10.1175 DOI). Content confirmed via Semantic Scholar abstract and multiple secondary citations in the literature found during this search.

---

### 2.2 Long and Ackerman (2000) — Clear-Sky Method and Its Blind Spots

**Long and Ackerman (2000):**

> "Identification of clear skies from broadband pyranometer measurements and calculation of downwelling shortwave cloud effects." *Journal of Geophysical Research: Atmospheres*, Vol. 105, No. D12. DOI: 10.1029/2000JD900077

This paper, foundational to the Reno/Hansen clear-sky algorithm family, explicitly notes that when the algorithm classifies a period as "clear sky," the sky may still contain:

- Haze or aerosol (which repartitions direct to diffuse but keeps total GHI similar to clear)
- Thin cirrus with optical depths so small the radiative impact is below the algorithm's detection threshold (average radiative impact of thin cirrus: approximately −5 W m⁻² out of 375 W m⁻² total shortwave — below typical noise floors)

The algorithm was not designed to discriminate these conditions — it was designed to find cloud-free periods for climate analysis. The algorithm treats haze and thin cirrus alike: both pass as "clear" or "quasi-clear."

**Verification status:** Paper is paywalled (AGU/Wiley). DOI verified. Content confirmed via Correa et al. (2022), ARM/DOE technical report DOE/SC-ARM/TR-004.1, and multiple derivative papers found in this search.

---

### 2.3 Spectral Analysis CAN Discriminate — But Requires More Than a Broadband Pyranometer

**Norgren et al. (2022)** is the most technically detailed paper on cirrus-aerosol discrimination from irradiance measurements:

> "Above-aircraft cirrus cloud and aerosol optical depth from hyperspectral irradiances measured by a total-diffuse radiometer." *Atmospheric Measurement Techniques*, Vol. 15, pp. 1373–1394. DOI: 10.5194/amt-15-1373-2022  
> URL: https://amt.copernicus.org/articles/15/1373/2022/

The instrument used is a **hyperspectral total-diffuse sunshine pyranometer (SPN-S)** measuring 350–1000 nm at 1 nm spectral resolution — not a broadband pyranometer. Two retrieval methods are developed:

- **RD method (Diffuse Ratio):** Uses the diffuse-to-total ratio at specific wavelengths (500, 670, 870 nm). Works best at low optical depths.
- **RS method (Spectral Shape):** Uses wavelength bands at 460–540, 665–684, 746–785, and 860–879 nm. Exploits the fact that fine-mode aerosols (smoke) show high Ångström wavelength dependence, while cirrus ice crystals (large particles) show low Ångström dependence — similar to coarse-mode dust.

Key finding on broadband limitation:

> **"Significant uncertainty exists in quantifying the optical properties of atmospheric systems containing one or both constituents."** Spectral information is essential. The authors developed these methods specifically because broadband pyranometers cannot make this discrimination.

Limitations even with the hyperspectral instrument:
- Coarse-mode aerosols (dust) have near-zero Ångström exponent — can look like cirrus
- Absorbing aerosols: single-scattering albedo is unknown without additional instruments
- High optical depths: diffuse ratio saturates above τ ≈ 5

**Verification status:** Open-access paper at amt.copernicus.org. Content directly fetched and verified.

---

### 2.4 MFRSR — A Practical Middle Ground (Not Consumer Grade)

The ARM program's **Multi-Filter Rotating Shadowband Radiometer (MFRSR)** measures total and diffuse irradiance at six narrowband channels: 415, 500, 615, 673, 870, and 940 nm, plus one broadband channel.

> URL: https://arm.gov/capabilities/instruments/mfrsr  
> ARM Handbook DOI: https://www.osti.gov/biblio/1020261

From the MFRSR's spectral AOD retrievals, the **Ångström exponent** can be calculated across channels. Fine-mode smoke aerosol: Ångström exponent > 1.5–2.0. Cirrus ice crystals: Ångström exponent near 0 (similar to large particles). This provides a practical discriminator — but the MFRSR is research-grade equipment ($5,000–$20,000), not consumer hardware.

The ARM Southern Great Plains (SGP) site in Oklahoma uses collocated MFRSRs, hyperspectral radiometers (HSR1, 360–1100 nm, 3 nm resolution), Cimel sun photometers, and Micropulse Lidars to perform cirrus-aerosol discrimination. The HSR1 at SGP showed AOD agreement with Cimel within 0.01 uncertainty for only 28% of comparisons — illustrating that even research-grade spectral instruments have meaningful uncertainty.

> Evaluation study: https://amt.copernicus.org/articles/17/3783/2024/

---

### 2.5 Aerosol Turbidity from Broadband Pyranometer — Cirrus Contaminates the Result

**Gueymard's line of work** on deriving aerosol turbidity (Ångström/Linke coefficient) from broadband direct-beam irradiance (Beer-Lambert-Bouguer method) explicitly identifies cirrus as a contamination source. The method works when skies are truly clear. When optically thin cirrus is present:

- The direct beam is attenuated by ice crystal forward scattering
- The derived turbidity is **overestimated** (the algorithm cannot know whether extinction is from aerosol or ice crystals)
- The forward scattering by cirrus adds diffuse radiation while reducing the apparent direct beam

Key reference: Gueymard, C.A. (1998) "Determination of atmospheric turbidity from the diffuse-beam broadband irradiance ratio." *Solar Energy*, Vol. 63, pp. 135–157. DOI: 10.1016/S0038-092X(98)00065-6 (paywalled — abstract confirmed via ScienceDirect).

Also referenced: Gueymard (2004) — "The sun's total and spectral irradiance for solar energy applications and solar radiation models." *Solar Energy*, Vol. 76, pp. 423–453. DOI: 10.1016/S0038-092X(03)00303-7. Confirmed via Semantic Scholar and SciDirect. This paper defines reference spectral models (SMARTS) but does not resolve the cirrus-aerosol broadband ambiguity.

---

### 2.6 The PM2.5 / Column Aerosol Disconnect

**A critical finding:** Surface PM2.5 readings are NOT a reliable proxy for column aerosol optical depth, especially for elevated plumes.

Key paper:

> "Decoupling between PM2.5 concentrations and aerosol optical depth at ground stations in China." *Frontiers in Environmental Science*, 2022. DOI: 10.3389/fenvs.2022.979918  
> URL: https://www.frontiersin.org/journals/environmental-science/articles/10.3389/fenvs.2022.979918/full

Findings:
- Correlation coefficients between daily PM2.5 and column AOD: **0.03–0.60** across stations — very weak
- In southern China during spring, cross-boundary transport of biomass burning aerosols floats at **high altitudes** and causes **limited impacts on surface PM2.5**
- Specific humidity dominates PM2.5-AOD differences (R² improvement from 0.49 to 0.74 when humidity added)

Supporting evidence from ACP 2026 paper on NASA GEOSCCM:

> "From column to surface: connecting the performance in simulating aerosol optical properties and PM2.5 concentrations in the NASA GEOSCCM." *Atmospheric Chemistry and Physics*, Vol. 26, pp. 3025–, 2026. URL: https://acp.copernicus.org/articles/26/3025/2026/

Finding: elevated aerosol transport (biomass burning) frequently produces high column AOD with **low surface PM2.5** because plume-rise injects aerosol above the planetary boundary layer, where surface monitors do not sample it.

**Implication for our system:** A wildfire smoke plume injected at 3,000–15,000 ft (1–5 km), transported hundreds of miles, can produce GHI deficits of 10–30% while registering **near-background PM2.5 at the surface.** This is indistinguishable from thin cirrus using our current instrument set.

---

### 2.7 AERONET and Sun Photometer — What Would Actually Work

AERONET sun photometers (Cimel) measure direct solar beam at multiple wavelengths (340, 380, 440, 500, 675, 870, 1020 nm). The Ångström exponent derived from these measurements provides aerosol type information:

- Smoke/fine-mode: Ångström exponent > 1.5 (steep spectral slope)
- Dust/coarse-mode: Ångström exponent < 0.5
- Cirrus ice crystals: Ångström exponent near 0, but **increases AOD and decreases Ångström exponent** in the same way as coarse aerosol

However, AERONET's own Spectral Deconvolution Algorithm (SDA) has documented limitations when cirrus is present:

> "Limitations of AERONET SDA product in presence of cirrus clouds." *Journal of Quantitative Spectroscopy and Radiative Transfer*, 2018. DOI: 10.1016/S0022-4073(17)30613-1 (paywalled — confirmed via ResearchGate abstract)

Finding: Cirrus clouds contaminate the SDA fine-mode AOD retrieval, causing significant errors. AERONET uses cloud-screening algorithms specifically because cirrus routinely passes undetected through naïve clear-sky tests.

Even AERONET (research-grade, 8-wavelength sun photometer, ~$15,000) requires lidar co-location to reliably screen cirrus.

---

### 2.8 Satellite — Practical Discriminator Available Free

**GOES-16/17/18 ABI Band 4 (1.37–1.38 µm, "Cirrus Band")** is specifically designed to detect cirrus. The 1.38 µm spectral region falls in a strong water vapor absorption band. Physical mechanism:

- Solar radiation at 1.38 µm is completely absorbed by water vapor in the lower troposphere
- High-altitude cirrus (above most water vapor, typically > 6 km / 20,000 ft) reflects 1.38 µm radiation back to the satellite — creates a bright signal
- Low-level clouds and surface: invisible (absorbed by water vapor below them)
- **Low-altitude smoke/aerosol** (< 5 km / 15,000 ft): also invisible at 1.38 µm (below most water vapor)

This gives the 1.38 µm band nearly unique sensitivity to high-altitude ice: it sees cirrus and sub-visible cirrus, but not surface haze or low-level smoke. High-altitude smoke injected above most atmospheric water vapor (stratospheric events) could in theory appear, but this is rare and associated with extreme pyrocumulus events.

Data is **freely available** on AWS S3 (no authentication required):  
- Bucket: `noaa-goes16`  
- Product: ABI-L2-CMIPF (or -CMIPM, -CMIPF for full-disk, mesoscale, CONUS)  
- Band 04 = 1.37 µm cirrus channel  
- Format: NetCDF4, 10-minute cadence (CONUS), 5-minute for mesoscale  
- Python: `s3fs`, `satpy`, `GOES-2-Go` packages  

> Registry: https://registry.opendata.aws/noaa-goes/  
> AWS download guide: https://aws.github.io/open-data-docs/docs/noaa/noaa-goes16/  
> Band reference: https://www.weather.gov/media/zhu/GOES_16_Guides_FINALBIS.pdf

**Limitation:** Daytime only (reflected solar). 10-minute latency. Pixel size ~1–4 km. Does not detect sub-visible cirrus with optical depth < ~0.03.

---

### 2.9 Lidar — Gold Standard, Not Consumer-Accessible

Ground-based Micropulse Lidar (MPL) and ceilometers detect backscatter from aerosol layers and cloud particles as a function of altitude. This directly solves the ambiguity:

- Aerosol layer at 2 km altitude → clear boundary layer feature → surface PM2.5 should be elevated  
- Aerosol layer at 8 km altitude → free troposphere feature → surface PM2.5 low but GHI reduced
- Cirrus at 10–12 km → distinct high-altitude feature with temperature < −37°C

The ARM 20-year MPLNET study at Greenbelt, MD confirms that lidar + radiative transfer modeling is the standard method:

> "Long-term trends in daytime cirrus cloud radiative effects: analyzing twenty years of Micropulse Lidar Network measurements." *Atmospheric Chemistry and Physics*, Vol. 26, pp. 411–, 2026. URL: https://acp.copernicus.org/articles/26/411/2026/

Consumer ceilometers (e.g., Campbell CS135, SkyVue PRO): $10,000–$50,000. Can detect cloud base and aerosol layers up to 15 km. Practical for a serious monitoring site but not typical consumer weather station hardware.

---

### 2.10 Infrared Sky Temperature — Partial Cirrus Indicator, Weak

Consumer infrared thermometers (e.g., MLX90614) pointed at the sky measure effective sky temperature:

- Clear sky: effective sky temperature −20°C to −40°C (mostly upper troposphere emission)
- Low cloud: near 0°C to +10°C (cloud base emission)
- **Thin cirrus:** modestly warmer than true clear sky (−15°C to −30°C range) but cooler than low cloud

The temperature sensitivity to thin cirrus is weak. Thin cirrus at −50°C (high altitude) produces minimal thermal emission change detectable at the surface. The method works well for optically thick low-level clouds. For cirrus optical depths below 0.5–1.0, the signal is likely below noise for consumer-grade sensors.

**Status:** Unverified for thin cirrus specifically at consumer sensor resolution. Flagged as uncertain.

---

## 3. Explicit Assessment: What CAN vs CANNOT Be Determined

### CANNOT be determined (with GHI pyranometer + surface PM2.5 alone):

1. **Whether a smooth GHI deficit with low PM2.5 is cirrus or elevated aerosol.** Both produce identical pyranometer signatures. This is the fundamental finding of Duchon & O'Malley (1999) and is supported by all subsequent literature.

2. **Whether low surface PM2.5 means the atmosphere is aerosol-free.** Elevated smoke plumes routinely decouple from surface PM2.5 (Frontiers 2022 paper; AOD-PM2.5 correlations as low as R = 0.03).

3. **Aerosol type from broadband measurements alone.** Spectral information is required (Norgren et al. 2022).

4. **Layer altitude from surface radiometry.** No altitude information is encoded in total-sky GHI.

### CAN be determined (with high confidence):

1. **That a GHI deficit exists** relative to the clear-sky model.

2. **Whether variability is high or low** — rapidly fluctuating GHI indicates broken cumulus/cumulonimbus; smooth deficit indicates either haze, thin cirrus, or thin stratiform cloud.

3. **If surface PM2.5 is elevated AND GHI is depressed**: aerosol in the boundary layer is the likely cause. The cirrus scenario does not elevate PM2.5.

4. **If surface PM2.5 is NOT elevated AND GHI is depressed**: the cause is ambiguous — could be cirrus, elevated smoke, or subvisual thin cirrus. No further determination is possible with the described instruments alone.

### Partial Discriminators (probabilistic, not definitive):

| Signal | Cirrus more likely | Elevated aerosol more likely |
|---|---|---|
| NWS upper-air sounding shows moist layer near tropopause | Yes | No |
| GOES-16 Band 4 (1.38 µm) shows bright region over site | Yes (high confidence) | Unlikely unless stratospheric smoke |
| Surface visibility (ASOS/AWOS) near site is reduced | No | Yes |
| Regional wildfire smoke forecasts active (NOAA Hazard Mapping System) | No | Yes |
| Surface dewpoint very low, atmosphere dry | Yes (cirrus favored thermodynamically) | Lower probability |
| Event disappears quickly (< 1 hour) | Cirrus or broken alto | Either |
| Event persists all day during active fire weather | Smoke likely | Higher probability |

None of these alone is definitive. In combination, a confidence weight can be assigned.

---

## 4. What State-of-the-Art Requires for Reliable Discrimination

Listed in order of increasing cost and capability:

| Instrument | What It Adds | Practical Access |
|---|---|---|
| **GOES-16 ABI Band 4 (1.38 µm)** | Detects cirrus present/absent at scale | Free via AWS, API-accessible, no hardware cost |
| **NWS ASOS visibility** at nearest airport | Flags near-surface haze/fog | Public data, METAR format, free |
| **NOAA Hazard Mapping System smoke product** | Identifies active smoke transport events | Free, public |
| **NWS upper-air soundings (raobs)** | Shows atmospheric layers, moisture | Free at weather.gov, twice daily |
| **Cimel sun photometer (AERONET)** | Multi-wavelength AOD + Ångström exponent | Research-grade, $15K–$25K; nearest AERONET site data may be available |
| **MFRSR (multi-filter shadowband)** | Spectral AOD at 6 wavelengths, diffuse ratio | Research-grade, $5K–$20K |
| **Backscatter lidar / ceilometer** | Layer altitude, backscatter intensity | Consumer-adjacent: $10K–$50K; ARM data free via arm.gov |
| **Hyperspectral pyranometer (SPN-S type)** | Full-spectrum discrimination per Norgren 2022 | Specialist equipment, ~$10K+ |

**Most practical immediate step:** Query GOES-16 Band 4 for the site coordinates. A bright Band 4 pixel at the time of a smooth GHI deficit is strong evidence for cirrus. Absence of a bright Band 4 signal shifts probability toward aerosol.

---

## 5. Best Achievable With Consumer Equipment

Our system (broadband pyranometer + surface PM2.5/PM10) can make the following statement with reasonable confidence:

**IF:** GHI deficit is smooth (Kv < 0.03), PM2.5 is NOT elevated, AND Band 4 GOES-16 image at the event time/location shows NO enhanced 1.38 µm reflectance →  
**THEN:** Elevated aerosol or very thin subvisual cirrus not detectable by GOES is the most likely cause. Cannot further discriminate.

**IF:** GHI deficit is smooth, PM2.5 is NOT elevated, AND Band 4 shows BRIGHT region over the site →  
**THEN:** Cirrus is confirmed. Report as cirrus or cirrostratus.

**IF:** GHI deficit is smooth AND PM2.5 IS elevated →  
**THEN:** Boundary layer aerosol haze. Cirrus may or may not also be present.

This three-branch logic using free GOES-16 data is the most cost-effective upgrade path from the current two-instrument setup.

---

## 6. Citations and Verification Status

All sources below were found via web search and/or directly fetched during this research session. Paywalled status is noted explicitly.

| # | Citation | URL / DOI | Status |
|---|---|---|---|
| 1 | Duchon, C.E. and O'Malley, M.S. (1999). "Estimating Cloud Type from Pyranometer Observations." *J. Appl. Meteor.*, 38(1), 132–141. | DOI: 10.1175/1520-0450(1999)038<0132:ECTFPO>2.0.CO;2 | Paywalled (AMS). Content confirmed via Semantic Scholar abstract and secondary citations. Key finding verified. |
| 2 | Long, C.N. and Ackerman, T.P. (2000). "Identification of clear skies from broadband pyranometer measurements." *J. Geophys. Res. Atmos.*, 105(D12). | DOI: 10.1029/2000JD900077 | Paywalled (Wiley/AGU). Content confirmed via ARM TR-004.1 and derivative papers. Key limitations verified. |
| 3 | Norgren, M.S. et al. (2022). "Above-aircraft cirrus cloud and aerosol optical depth from hyperspectral irradiances measured by a total-diffuse radiometer." *Atmos. Meas. Tech.*, 15, 1373–1394. | https://amt.copernicus.org/articles/15/1373/2022/ | Open access. Content directly fetched. Key findings verified. |
| 4 | ARM/DOE (2013). Cirrus Clouds and Aerosol Properties Campaign (CCAP). Southern Great Plains site. | https://www.arm.gov/research/campaigns/sgp2013ccap | Open access. Campaign description confirmed; detailed findings not available on landing page. |
| 5 | Bi et al. (2022). "Decoupling between PM2.5 concentrations and aerosol optical depth at ground stations in China." *Front. Environ. Sci.*, 10, 979918. | https://www.frontiersin.org/journals/environmental-science/articles/10.3389/fenvs.2022.979918/full | Open access. Content directly fetched. Key PM2.5-AOD decoupling findings verified. |
| 6 | Zhao et al. (2026). "From column to surface: connecting the performance in simulating aerosol optical properties and PM2.5." *Atmos. Chem. Phys.*, 26, 3025–. | https://acp.copernicus.org/articles/26/3025/2026/ | Open access. Content directly fetched. Elevated smoke-column PM2.5 disconnect confirmed. |
| 7 | Gueymard, C.A. (1998). "Determination of atmospheric turbidity from the diffuse-beam broadband irradiance ratio." *Solar Energy*, 63, 135–157. | DOI: 10.1016/S0038-092X(98)00065-6 | Paywalled (Elsevier). Abstract confirmed via ScienceDirect. Cirrus contamination of turbidity estimates confirmed via secondary sources. |
| 8 | Gueymard, C.A. (2004). "The sun's total and spectral irradiance for solar energy applications and solar radiation models." *Solar Energy*, 76, 423–453. | DOI: 10.1016/S0038-092X(03)00303-7 | Paywalled. Citation confirmed via Semantic Scholar, SciLit, scirp.org. Paper defines SMARTS reference spectra; does not resolve the cirrus-aerosol broadband ambiguity directly. |
| 9 | Sitnov et al. (2017). "Limitations of AERONET SDA product in presence of cirrus clouds." *J. Quant. Spectrosc. Radiat. Transfer*, 2018. | DOI: 10.1016/S0022-4073(17)30613-1 | Paywalled (Elsevier). Abstract confirmed via ScienceDirect and ResearchGate. Cirrus contamination of SDA aerosol retrieval confirmed. |
| 10 | ARM MFRSR Handbook. | https://arm.gov/capabilities/instruments/mfrsr | Open access. Content directly fetched. Wavelengths and capabilities verified. |
| 11 | Barragan et al. (2024). "Evaluation of the hyperspectral radiometer (HSR1) at the ARM SGP site." *Atmos. Meas. Tech.*, 17, 3783–. | https://amt.copernicus.org/articles/17/3783/2024/ | Open access. Content directly fetched. Instrument comparisons verified. |
| 12 | Pappalardo et al. / MPLNET (2026). "Long-term trends in daytime cirrus cloud radiative effects: 20 years of MPLNET." *Atmos. Chem. Phys.*, 26, 411–. | https://acp.copernicus.org/articles/26/411/2026/ | Open access. Content directly fetched. Lidar + RTM methodology for cirrus CRE confirmed. |
| 13 | NOAA/GOES-R. ABI Band 4 (1.37 µm) Cirrus Band reference. | https://www.weather.gov/media/zhu/GOES_16_Guides_FINALBIS.pdf | Open access. Content confirmed via CIMSS and NWS band guide. Cirrus detection mechanism verified. |
| 14 | NOAA Open Data on AWS — GOES-16. | https://registry.opendata.aws/noaa-goes/ | Open access. Confirmed freely available. |

---

## 7. Honest Summary for the Haze Detection System

**The fundamental answer: No, broadband pyranometry + surface PM2.5 cannot reliably distinguish thin cirrus from high-altitude smoke. This is not a calibration or algorithm problem — it is a physics problem. Both phenomena produce identical integrated-irradiance signatures, and surface PM2.5 is an unreliable proxy for column aerosol when the aerosol is above the boundary layer.**

What we can do:

1. **Acknowledge the ambiguity explicitly.** When PM2.5 is near-background and GHI is suppressed with low variability, report the result as "possible cirrus or elevated aerosol — cannot distinguish with available instruments."

2. **Use GOES-16 Band 4 as a free discriminator.** Query the 1.37 µm reflectance for the site's lat/lon at the event time. Bright = cirrus. Dark = probable aerosol or subvisual cirrus. This is the highest-leverage zero-cost improvement.

3. **Use ancillary NWS/EPA data as probability weights:** ASOS visibility (haze indicator), NWS soundings (upper-level moisture), NOAA Hazard Mapping System smoke product (active transport events).

4. **Be explicit about sub-categories of "uncertain."** The haze detection system can return a three-way classification: (a) confirmed haze (PM2.5 elevated + GHI suppressed), (b) confirmed cirrus (GOES Band 4 positive), (c) ambiguous deficit (neither confirmation available). Category (c) is honest; false certainty in either direction is not.

5. **For future hardware:** A rotating shadowband radiometer ($5K–$15K) at 6 wavelengths would provide Ångström exponent information sufficient to discriminate fine-mode smoke (high Ångström) from cirrus (near-zero Ångström). A consumer ceilometer ($10K–$50K) would give layer altitude directly. Both are beyond typical hobbyist budgets but within the reach of a serious monitoring site.
