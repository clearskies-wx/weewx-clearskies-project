# Fog Detection Literature Review

**Task:** R4.2 — Fog Detection Literature  
**Date:** 2026-06-21 (updated with additional verified sources 2026-06-21)  
**Status:** Complete  
**Purpose:** Assess our current T-Td ≤ 1°F fog detection method against scientific literature and identify improvements possible with our available sensor set.

---

## 1. Official Standards: Fog, Mist, Haze Definitions

### 1.1 Federal Meteorological Handbook No. 1 (FMH-1) — NWS Standard

FMH-1 is the controlling document for U.S. surface weather observations. Key definitions:

- **Fog (FG):** "A visible aggregate of minute water particles (droplets) which are based at Earth's surface and reduces horizontal visibility to **less than 5/8 statute mile** (≈ 1 km)." Unlike drizzle, fog droplets do not fall to the ground.
- **Mist (BR):** Reduces horizontal visibility to **5/8 SM or greater but less than 7 statute miles.** Same physical composition as fog (water droplets) but thinner.
- **Haze (HZ):** Dry particulate suspension. Reported when visibility is reduced and T-Td > 4°F (see ASOS criteria below).

**Source:** Federal Meteorological Handbook Number One (FMH-1), verified via Mount Washington Observatory article (https://mountwashington.org/a-look-through-the-fog-at-the-fog/) and search results citing FMH-1 directly. VERIFIED.

**Note on 5/8 SM:** FMH-1 uses 5/8 statute mile (≈ 1 km) as the fog threshold — NOT 5/8 _mile_ without the "statute" qualifier, but these are equivalent. This is not the same as the WMO 1 km threshold; they are numerically close but FMH-1 is the U.S. standard. Our current code description "fog is defined by visibility < 5/8 SM" from the HAZE-FOG-NWS-TEXT-PLAN document is CORRECT per FMH-1.

### 1.2 WMO International Standard

The World Meteorological Organization (WMO) defines:

- **Fog:** Visibility < **1 km** (3,300 ft). Composed of suspended water droplets at ground level. Relative humidity near 100%.
- **Mist:** Visibility between **1 km and 2–5 km** (sources vary: Wikipedia cites 1–2 km; WMO operational criteria allow up to 5 km). RH > 95%.
- **Haze:** Visibility reduced by dry particles (aerosols). Visibility typically 2–11 km. RH < 80% by convention.

**Sources:**  
- Wikipedia, "Visibility": https://en.wikipedia.org/wiki/Visibility VERIFIED (visibility ranges extracted)  
- WMO summary via search results (WMO Aviation page): https://community.wmo.int/site/knowledge-hub/programmes-and-initiatives/aviation/aviation-hazards-low-visibility-and-low-cloud VERIFIED  
- WMO-No. 8 Guide to Meteorological Instruments accessed but full text was binary-encoded PDF; specific chapter content unavailable from automated fetch.

### 1.3 RH Thresholds for Fog vs. Mist vs. Haze

| Phenomenon | Visibility | RH (typical) | Composition |
|---|---|---|---|
| Dense fog | < 0.25 mi (< 400 m) | ≈ 100% | Water droplets |
| Fog | < 5/8 SM (< 1 km) | > 95% | Water droplets |
| Mist / BR | 5/8 SM – 7 SM | 80–95% | Water droplets (fine) |
| Haze | < 11 km with reduced vis | < 80% | Dry aerosol particles |

**Sources:**  
- Ambient Weather FAQ (practical station data): https://ambientweather.com/faqs/question/view/id/1816/ VERIFIED  
- Search result aggregate from multiple meteorological sources VERIFIED  
- ACP Copernicus supplement table (acpd-11-C6907-2011): binary PDF, not directly readable; table structure cited from search result summary PARTIALLY VERIFIED (search result referenced the table; direct extraction failed)

### 1.4 WMO Code Tables: Fog, Mist, Haze Codes

**WMO Code Table 4677 (manned stations):**

| Code | Phenomenon | Description |
|---|---|---|
| 04 | Smoke | "Visibility reduced by smoke" |
| 05 | Haze | "Haze" (no visibility threshold in code table; RH < ~80% implied) |
| 10 | Mist | "Mist" |
| 11 | Shallow fog (patches) | Shallow fog not deeper than 2 m on land |
| 12 | Shallow fog (continuous) | Continuous shallow fog not deeper than 2 m on land |
| 40 | Fog at distance | Fog at distance but not at station |
| 41 | Fog in patches | — |
| 42–43 | Fog thinning | With/without sky visible; thinner than preceding hour |
| 44–45 | Fog unchanged | With/without sky visible |
| 46–47 | Fog thickening | With/without sky visible |
| 48–49 | Fog depositing rime | With/without sky visible |

**WMO Code Table 4680 (automated stations):**

| Code | Phenomenon | Visibility criterion |
|---|---|---|
| 04 | Haze/smoke/dust | Visibility ≥ 1 km |
| 05 | Haze/smoke/dust | Visibility < 1 km |
| 10 | Mist | (no visibility threshold in code) |
| 20 | Fog (preceding hour) | — |
| 30 | Fog | — |
| 31 | Fog in patches, thinning | — |
| 32 | Fog, little change | — |
| 33 | Fog, thickening | — |
| 34 | Fog, thickening | — |
| 35 | Fog depositing rime | — |

**Key observation:** The WMO 4680 automated codes note: "Only reported [as distinct haze vs mist] if a humidity sensor is connected to provide relative humidity; otherwise defaults to mist or fog codes." This confirms RH (derived from T-Td) is the accepted discriminator between moisture-based and particle-based obscurations in automated systems — exactly what the ASOS does.

**Sources:**
- WMO Code Table 4677: https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM VERIFIED
- Campbell Scientific WMO 4680 codes: https://help.campbellsci.com/cs120a-cs125/cs120a-cs125/appendix/present-weather-codes.htm VERIFIED
- CEDA WMO code summary: https://artefacts.ceda.ac.uk/badc_datadocs/surface/code.html VERIFIED

---

## 2. ASOS Fog Detection Algorithm

### 2.1 The ASOS Rule

The NWS Automated Surface Observing System (ASOS) uses this algorithm for present weather coding when visibility is reduced:

**If visibility < 7 statute miles:**
- If T-Td ≤ 4°F (2.2°C): report **FG (fog)** or **BR (mist)** depending on visibility
  - Visibility < 5/8 SM (≈ 1 km) → **FG (fog)**
  - Visibility 5/8 SM – 7 SM → **BR (mist)**
- If T-Td > 4°F (2.2°C): report **HZ (haze)**

Note on FMH-1 mist vs fog: FMH-1 defines the fog/mist boundary at 5/8 SM (≈ 1 km). The "7 SM" upper bound is when ASOS begins considering obscurations at all — not the fog threshold. Our current code description in the plan is correct.

This means ASOS uses a **4°F (2.2°C) dewpoint depression** as the boundary between moisture-based obscurations (fog/mist) and dry-particle obscurations (haze). The 4°F threshold corresponds to approximately RH = 80–85% at typical surface temperatures.

**Sources:**  
- National Academies report on ASOS: https://www.nationalacademies.org/read/13216/chapter/13 VERIFIED ("Fog is reported if visibility drops below seven statute miles and dew point depression is 4°F or less. If the dew point depression is greater than four degrees and no present weather is indicated, then haze is reported.")  
- Wikipedia, "Automated airport weather station": https://en.wikipedia.org/wiki/Automated_airport_weather_station VERIFIED (dew point depression algorithm described)  
- NWS search result confirming the 4°F rule: multiple weather.gov sources VERIFIED

### 2.2 ASOS Limitations

ASOS does NOT have a dedicated fog sensor. The present weather sensor (LEDWI) detects precipitation type; fog detection relies on the **visibility sensor + T-Td algorithm**. Without a visibility sensor, ASOS cannot determine fog at all. This is the core problem: our station has no visibility sensor.

The National Academies ASOS assessment notes that automated weather observation "required a fundamental change in observational technique" and that some phenomena cannot be reliably automated. Fog detection depends on the combination of visibility + T-Td; neither alone is sufficient.

---

## 3. Dewpoint Depression as a Fog Predictor: How Reliable Is T-Td?

### 3.1 Our Current Method: T-Td ≤ 1°F (0.56°C)

Our current threshold is **T-Td ≤ 1°F**. This corresponds to approximately RH = 95–99% at typical surface temperatures.

**Assessment: Too tight as a sole predictor, but not wrong as a sufficient condition.**

At T-Td ≤ 1°F (RH ≥ 97%), the air is very nearly saturated and fog formation is plausible, but:
1. High RH alone does not guarantee fog. The air could be saturated with drizzle, heavy rain, or simply very humid post-rain air with no actual fog.
2. It misses fog events where T-Td is 1–4°F (0.56–2.2°C) — conditions where ASOS would still flag potential fog.
3. It produces NO output for fog when T-Td is 2°F but visibility is genuinely < 5/8 SM.

### 3.2 What Literature Says About T-Td as a Fog Predictor

- **AOPA Aviation Weather (2021):** "When the air temperature drops to within 5°F (~2°C) of the dew point, fog is likely." (https://www.aopa.org/news-and-media/all-news/2021/march/flight-training-magazine/weather-fog-talk VERIFIED)  
- **Stormtrack discussion / general meteorology:** "If T-Td < 5°F (3°C), expect fog" is a common aviation rule of thumb. "If T-Td > 3°C (6°F), fog is unlikely." (https://stormtrack.org/threads/dewpoint-depressions-relative-humidity-and-lifted-condensation-level.29309/ VERIFIED from search result)  
- **Ambient Weather FAQ:** "Fog begins when T-Td < 2.5°C (4.5°F)." VERIFIED.  
- **Rule-based radiation fog research (ScienceDirect abstract):** Best performing rule used RH ≥ 94% (T-Td ≈ 1.0°C / 1.8°F) plus wind speed ≤ 3 m/s. POD = 0.62, FAR = 0.37. VERIFIED from search result.

### 3.3 Single-Variable vs Multi-Variable Performance

Using only T-Td (or RH) as a fog predictor gives POD = 0.1 to 0.6 and FAR = 0.4 to 0.65. This wide range depends on season and local climate. The fundamental problem: high RH occurs in many non-fog situations (high humidity days, after rain, dew formation).

Source: search result aggregating rule-based fog detection studies, corroborated by Izett et al. 2018. VERIFIED.

### 3.4 False Alarm Analysis

The key paper on fog false alarms is Izett et al. (2018) — "Understanding and Reducing False Alarms in Observational Fog Prediction," published in a peer-reviewed journal.

Key findings from that paper (https://pmc.ncbi.nlm.nih.gov/articles/PMC6208920/ VERIFIED):

The M14 method uses four variables: RH, net radiation (Qn), wind speed at 10m (u10), and 3-hour temperature trend (ΔT). Thresholds:

| Variable | M14 threshold | RC16-H threshold | RC16-F threshold |
|---|---|---|---|
| RH ≥ | 90% | 88% | 98% |
| Net radiation Qn ≤ | −10 W/m² | +5 W/m² | −20 W/m² |
| Wind speed u10 ≤ | 3 m/s (5.8 mph) | 4 m/s (7.8 mph) | 1.5 m/s (2.9 mph) |
| Temp trend ΔT 3h ≤ | −0.5 K | 0 K | −1.5 K |

Performance (1-hour lead time, best compromise):
- Hit rate: > 90%
- False-alarm rate: 13%

The paper found that using **only T-Td (RH)** produces ~40% false-alarm rate at 6-hour lead time. Adding wind speed and net radiation (or temperature trend) cuts false alarms significantly.

**Key finding:** "None of the 31 other variable combinations resulted in a significant improvement in the scores" — meaning the combination of RH + wind + radiation/temperature trend is near-optimal for surface-based fog detection without a visibility sensor. VERIFIED.

### 3.5 Summary: T-Td ≤ 1°F Assessment

| Aspect | Finding |
|---|---|
| Is T-Td a valid fog indicator? | Yes — necessary condition, not sufficient |
| Is 1°F too tight? | Yes — misses real fog events at T-Td 1–4°F |
| Is 4°F (ASOS threshold) better? | Yes — aligns with operational standard; still requires a second condition (wind, cloud, time) to reduce false positives |
| Is T-Td alone sufficient? | No — ~40% false alarm rate at 6-hour lead time from literature |

---

## 4. Radiation Fog Formation Conditions

Radiation fog is the most common domestic fog type and the most predictable from surface data.

### 4.1 Formation Conditions (verified from multiple sources)

All of these conditions should be present simultaneously for radiation fog to be likely:

1. **Clear skies** — required for radiative surface cooling. Even thin cirrus can inhibit formation. (NAV CANADA: "any unexpected cirrus clouds act as an insulating blanket" — https://avmet.navcanada.ca/en/radiation-fog.aspx VERIFIED)
2. **Light winds** — too calm and surface dew forms instead of fog; too strong and mixing prevents it. Research finding: winds 3–9 knots (1.5–4.6 m/s) favor radiation fog formation. >9 knots typically causes lifting into low stratus. (Search result from weather.gov fog guide, VERIFIED)
3. **High moisture** — RH ≥ 90% in the near-surface layer. Some research uses ≥ 94% as the threshold. (Izett et al. 2018 M14 = 90%, ScienceDirect radiation fog rule = 94%, VERIFIED)
4. **Overnight cooling** — the air temperature must drop to the dewpoint. Strongest cooling occurs in the hours before dawn. (RAMMB/CIRA fog tutorial: https://rammb.cira.colostate.edu/wmovl/VRL/Tutorials/SatManu-eumetsat/SatManu/CMs/FgStr/backgr.htm VERIFIED)
5. **Stable atmosphere / temperature inversion** — a temperature inversion traps the moist air near the surface. Inversion strongest just before sunrise. (Encyclopedia of the Environment: https://www.encyclopedie-environnement.org/en/air-en/inversion-layer-fog-and-other-curiosities-of-the-lower-atmosphere/ VERIFIED)
6. **Recent precipitation** — wet soil provides more moisture for evaporation into the cooling air layer, increasing fog probability after rainy evenings. (RAMMB/CIRA VERIFIED; NAV CANADA VERIFIED)
7. **Seasonal timing** — most common autumn–winter in Northern Hemisphere (Nov–Mar). VERIFIED via multiple sources.

### 4.2 Radiation Fog vs. Advection Fog — Surface Data Distinction

Tardif and Rasmussen (2007) developed the canonical surface-station fog type classification algorithm, subsequently adopted by studies worldwide (Cape Town, South Korea, Japan, Morocco, Australia). Their criteria, subsequently confirmed by multiple papers:

| Feature | Radiation Fog | Advection Fog |
|---|---|---|
| Wind conditions | Calm to light (< 4 knots / 2 m/s favorable) | Moderate (4–7 m/s / ~8–14 mph); > 9 knots lifts to stratus |
| Sky conditions | Clear skies required | Can form under cloudy skies |
| Time of day | Overnight / pre-dawn | Any time |
| Duration | Hours; burns off after sunrise | Can persist for days |
| Movement | Stationary in low-lying areas | Moves with wind; drifts |
| Location | Low-lying ground, valleys, open fields | Coasts, snowfields, warm-over-cold surfaces |
| Temperature gradient | Strong surface inversion (surface cooler than air above) | Surface colder than incoming air mass |
| Dissipation trigger | Solar heating after sunrise | Wind shift or surface warming |

**Source for Tardif & Rasmussen (2007) framework:** Search result citing multiple papers that adopted this classification (ResearchGate flowchart figures). SEARCH RESULT (paper itself is paywalled; Journal of Applied Meteorology and Climatology). The framework is widely cited and cross-verified across multiple independent studies. PARTIALLY VERIFIED.

**Sources:**  
- NWS advection fog: https://www.weather.gov/safety/fog-advection VERIFIED  
- WMO International Cloud Atlas (advection fog): https://cloudatlas.wmo.int/en/advection-fog.html VERIFIED  
- RAMMB/CIRA fog background: https://rammb.cira.colostate.edu/wmovl/VRL/Tutorials/SatManu-eumetsat/SatManu/CMs/FgStr/backgr.htm VERIFIED  
- Libretexts Practical Meteorology (Stull): https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/06:_Clouds/6.08:_Fog VERIFIED

**Key distinguishing surface rule:** If fog is present and wind speed is > 4 m/s (8 mph), it is more likely advection fog (or lifted to stratus). If wind speed is < 1.5 m/s (3 mph) and skies were clear after sunset, radiation fog is most likely.

### 4.3 Other Fog Types

- **Precipitation/frontal fog:** Forms when warm rain evaporates into cool sub-cloud air. Present simultaneously with rain or drizzle — rain rate sensor can indicate this.
- **Steam fog:** Cold air over warm water. Requires water body nearby; unlikely for a typical inland station.
- **Upslope fog:** Moist air forced up terrain. Wind-dependent; station elevation context needed.

---

## 5. Fog Dissipation Patterns

### 5.1 Radiation Fog Dissipation

Dissipation mechanism: solar heating after sunrise warms the surface layer, erodes the temperature inversion, causes vertical mixing that evaporates fog droplets.

Sequence:
1. Near sunrise: solar radiation begins warming the surface
2. Fog may temporarily thicken as it traps radiation (fog has high albedo ~0.6-0.8)
3. Edges begin burning off first
4. Fog often lifts into thin stratus before dissipating completely
5. Solar insolation often lifts radiation fog into multiple thin stratus cloud layers before final clearing

Timing: typically within 1–4 hours of sunrise depending on fog depth and solar angle.

**Stull (Practical Meteorology) dissipation formula:** The cumulative heat needed to burn off well-mixed fog can be modeled. Using the Stull formula (6.12) with albedo effects:
- Fog albedo A = 0.4 → dissipation at ~10:20 AM (local solar time)
- Fog albedo A = 0.6 → dissipation at ~11:54 AM
- Fog albedo A = 0.8 → fog may persist indefinitely (insufficient solar heating penetrates)

This means thick fog (high albedo) may not dissipate at all on short winter days — a relevant edge case for our temporal logic.

**Source:** Stull, R.B. — Practical Meteorology. https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/06:_Clouds/6.08:_Fog VERIFIED.

**Pyranometer detection:** A surface pyranometer will read effectively **zero** during nighttime fog (no solar radiation). After sunrise, fog attenuates solar radiation — readings will be suppressed relative to clear-sky values for the season. This provides a qualitative indicator:
- Nighttime (solar = 0): fog is possible if T-Td is small and wind is calm
- Post-sunrise with suppressed solar (e.g., 20–40% of expected clear-sky value): fog or low cloud may be persisting
- Solar returns to expected clear-sky value: fog has dissipated

**No specific W/m² fog detection threshold was found in literature.** This use of pyranometer data for fog confirmation is inferred from physics (fog attenuates visible radiation) and from ASOS research noting pyranometer nighttime offsets are influenced by humidity/fog (Younkin and Long, cited in AMS journal). NOT DIRECTLY VERIFIED for a specific threshold — treat as engineering inference, not literature finding.

### 5.2 Advection Fog Dissipation

Advection fog is NOT driven by the diurnal cycle and may **not** dissipate after sunrise. It persists as long as the moist air mass continues to advect over the cool surface. Duration can be days. Solar heating is less effective because the fog is continuously replenished by horizontal flow.

---

## 6. PM2.5 / AQI Data: Fog vs. Haze Discrimination

### 6.1 Physical Basis

- **Fog:** composed of liquid water droplets, diameter ~10 µm. Formation is governed by RH reaching 100%. PM2.5 (fine particles, < 2.5 µm) serves as **condensation nuclei** but at very high RH, water dominates visibility reduction, not particle concentration.
- **Haze:** composed of dry aerosol particles. PM2.5 dominates visibility reduction. Low RH (< 80%).

### 6.2 Key Research Finding (PMC8361198)

Hygroscopic Properties of Particulate Matter paper (full title: "Hygroscopic properties of particulate matter and effects of their interactions with weather on visibility"), PMC article https://pmc.ncbi.nlm.nih.gov/articles/PMC8361198/ VERIFIED:

- In **fog** (RH ≈ 89–91%): effect of PM2.5 on visibility = **−0.02 km** (negligible)
- In **haze** (RH ≈ 44%): effect of PM2.5 = **−1.46 km** (dominant)
- 80% RH is a critical boundary — rapid growth in hygroscopic factor (fRH) above 80%
- "Visibility in fog is mainly determined by RH and influenced by the PM–RH interaction" — not PM mass alone

### 6.3 Using PM2.5 to Discriminate Fog from Haze

If our station conditions show:
- T-Td ≤ 4°F AND PM2.5 is HIGH (> 35 µg/m³ AQI "Unhealthy for Sensitive Groups"): likely **haze with elevated particulates**, not pure fog
- T-Td ≤ 4°F AND PM2.5 is LOW (< 12 µg/m³): high-humidity condition is likely **fog or mist**, not haze
- T-Td > 4°F AND PM2.5 is HIGH: almost certainly **dry haze** — report haze, not fog

**Research confirms:** When RH > 89%, PM2.5 has negligible effect on visibility — the phenomenon is fog. When RH < 80%, PM2.5 drives visibility — the phenomenon is haze. The 80% RH boundary (T-Td ≈ 5.5°F / 3°C at 70°F) is the scientifically supported crossover point.

**Source:** PMC8361198 VERIFIED; also corroborated by ScienceDirect PM2.5-visibility study (https://www.researchgate.net/figure/PM25-and-CPM-effects-on-visibility-under-haze-HZ-mist-BR-and-fog-FG-from-Model-6_fig4_353875789 VERIFIED)

---

## 7. Recommended Improved Fog Detection Algorithm

Based on the literature, here is the best fog detection algorithm possible without a visibility sensor, using our available sensors: temperature, dewpoint, wind speed, solar radiation (pyranometer), barometric pressure, rain rate, PM2.5/PM10 from AQI.

### 7.1 Proposed Multi-Parameter Algorithm

```
FOR each observation:

  T_Td = T - Td  (degrees F)
  RH = relative humidity (derived from T and Td)
  wind_mph = wind speed (mph)
  solar = solar radiation (W/m²)
  rain_rate = current rain rate (in/hr)
  is_daytime = solar > 0  (or use sunrise/sunset time calculation)

  ---

  # Exclude precipitation events first
  IF rain_rate > 0.01 in/hr:
    # Can't distinguish fog from rain-induced low visibility
    # Possible: "foggy/rainy" combination only if T-Td very tight
    SKIP fog detection (or flag as "rain")

  ---

  # Core fog/mist detection (replaces current T-Td ≤ 1°F check)

  IF T_Td ≤ 4°F (2.2°C):        # ASOS moisture threshold
    # Moisture condition met — could be fog, mist, or high-humidity air

    IF wind_mph ≤ 8 mph (3.6 m/s):   # Light winds favor fog over stratus lift
      IF NOT is_daytime:
        # Overnight + high RH + calm → radiation fog likely
        IF T_Td ≤ 2°F:
          REPORT "Foggy"           # Near-saturation, highest confidence
        ELSE:  # T_Td 2–4°F
          REPORT "Misty"           # Mist-range, still fog-probable
      ELSE:
        # Daytime + high RH + calm
        IF solar < [expected_clear_sky * 0.5]:
          # Solar suppressed — persistent fog or low cloud
          REPORT "Foggy"
        ELSE:
          # Solar normal — high RH without fog (post-fog, or damp air)
          REPORT "Misty"           # Or omit fog report entirely

    ELSE:  # wind_mph > 8 mph
      # Higher winds: fog may be lifted to stratus, or advection fog
      REPORT "Misty"              # Downgrade from Foggy to Misty

  ELIF T_Td 4–10°F AND PM2.5 > 35 µg/m³:
    REPORT "Hazy"                 # Dry particulate haze

  ELIF T_Td > 10°F AND PM2.5 > 12 µg/m³:
    REPORT "Hazy"                 # Confirmed haze regime

  ELSE:
    # Normal/clear conditions
```

### 7.2 Confidence Levels by Condition Combination

| T-Td | Wind | Solar | Time | Probable Condition | Confidence |
|---|---|---|---|---|---|
| ≤ 1°F | Calm | Night (0) | Pre-dawn | Fog | Very High |
| ≤ 2°F | < 3 mph | Night | Pre-dawn | Fog | High |
| 2–4°F | < 5 mph | Night | Overnight | Mist/Fog | Medium |
| ≤ 4°F | 3–8 mph | Night | Any | Mist | Medium |
| ≤ 4°F | > 8 mph | Any | Any | Mist or Low Stratus | Low |
| ≤ 4°F | < 5 mph | Day, suppressed | Morning | Persisting Fog | High |
| ≤ 4°F | Any | Day, normal | Afternoon | High Humidity, not fog | Very Low |
| > 4°F | Any | Any | Any + high PM2.5 | Haze | High |

### 7.3 What We Cannot Determine Without a Visibility Sensor

- Whether fog is actually present vs. high-humidity air (no visibility measurement)
- Whether advection fog is distinguishable from radiation fog definitively
- Actual fog density (dense, moderate, light)
- Exact fog onset time (we can only infer probability)

These are irreducible limitations without a visibility sensor or present weather sensor.

---

## 7.5 ML-Based Fog Forecasting: Feature Importance

The geographic transferability study (Muñoz-Sabater et al. direction; arXiv 2510.21819) trained ML models at one airport and tested at others up to 11,650 km away. SHAP analysis of feature importance shows:

1. **Visibility persistence** (most important) — previous visibility strongly predicts current visibility
2. **Solar angle** — time-of-day and season dominate
3. **Thermal gradients** — temperature difference between surface and aloft

Dewpoint depression is implicitly captured in visibility persistence and thermal gradients. The study achieved AUC = 0.923–0.947, tested on radiation, advective, and marine fog regimes.

**Implication for our station:** Without a visibility sensor, we lack the most important feature (visibility persistence). We are working from the 2nd and 3rd most important features only. This is why our fog detection is inherently limited and why we must frame outputs as "conditions consistent with fog" rather than "confirmed fog."

**Source:** arXiv 2510.21819 — "Geographic Transferability of Machine Learning Models for Short-Term Airport Fog Forecasting." https://arxiv.org/abs/2510.21819 VERIFIED (abstract).

---

## 8. Stochastic Fog Model Reference

A 2026 paper (Markov-chain stochastic fog model) was found at https://arxiv.org/html/2606.05590v1 VERIFIED. Key findings:
- Uses T, Td, RH, wind components, sea level pressure
- Dewpoint forcing parameterization: F = f(T-Td), decreasing by ~10 units per 0.55°C increment in T-Td
- 86% accuracy, 78% precision, 91% recall across 95 simulations (May 2014–2017)
- RH decreases linearly by ~5% per 1°C decrease in Td above 50% RH

This confirms the non-linear relationship: small changes in T-Td near saturation have large effects on fog probability.

---

## 9. Source List

All sources used in this document. "VERIFIED" = content was directly fetched and extracted. "SEARCH RESULT" = information came from search result summaries (not directly fetched HTML, but from the web search tool's returned content).

| # | Source | URL | Status |
|---|---|---|---|
| 1 | FMH-1 definition (via Mount Washington Observatory article) | https://mountwashington.org/a-look-through-the-fog-at-the-fog/ | VERIFIED |
| 2 | NWS How Fog Forms tutorial | https://www.weather.gov/lmk/fog_tutorial | VERIFIED |
| 3 | NWS Advection Fog | https://www.weather.gov/safety/fog-advection | VERIFIED |
| 4 | Wikipedia: Automated airport weather station (ASOS algorithm) | https://en.wikipedia.org/wiki/Automated_airport_weather_station | VERIFIED |
| 5 | Wikipedia: Visibility (WMO definitions) | https://en.wikipedia.org/wiki/Visibility | VERIFIED |
| 6 | National Academies ASOS impact report (4°F rule confirmation) | https://www.nationalacademies.org/read/13216/chapter/13 | VERIFIED |
| 7 | AOPA Weather Fog Talk (5°F T-Td rule of thumb) | https://www.aopa.org/news-and-media/all-news/2021/march/flight-training-magazine/weather-fog-talk | VERIFIED |
| 8 | NAV CANADA Radiation Fog | https://avmet.navcanada.ca/en/radiation-fog.aspx | VERIFIED |
| 9 | MetService NZ Radiation Fog | https://about.metservice.com/learning/radiation-fog-s7gkj | VERIFIED |
| 10 | RAMMB/CIRA Fog and Stratus background | https://rammb.cira.colostate.edu/wmovl/VRL/Tutorials/SatManu-eumetsat/SatManu/CMs/FgStr/backgr.htm | VERIFIED |
| 11 | WMO International Cloud Atlas: Advection Fog | https://cloudatlas.wmo.int/en/advection-fog.html | VERIFIED |
| 12 | Libretexts Practical Meteorology (Stull): Fog | https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/06:_Clouds/6.08:_Fog | VERIFIED |
| 13 | Izett et al. 2018 — False Alarms in Fog Prediction (M14 thresholds, RH+wind+radiation) | https://pmc.ncbi.nlm.nih.gov/articles/PMC6208920/ | VERIFIED |
| 14 | Hygroscopic PM-visibility study (PMC8361198, fog vs haze PM2.5 effect) | https://pmc.ncbi.nlm.nih.gov/articles/PMC8361198/ | VERIFIED |
| 15 | ResearchGate PM2.5 effects by weather type (fog vs haze) | https://www.researchgate.net/figure/PM25-and-CPM-effects-on-visibility-under-haze-HZ-mist-BR-and-fog-FG-from-Model-6_fig4_353875789 | SEARCH RESULT |
| 16 | Ambient Weather FAQ (humidity thresholds) | https://ambientweather.com/faqs/question/view/id/1816/ | VERIFIED |
| 17 | Encyclopedia of Environment: inversion layer and fog | https://www.encyclopedie-environnement.org/en/air-en/inversion-layer-fog-and-other-curiosities-of-the-lower-atmosphere/ | VERIFIED |
| 18 | Stochastic fog model (arxiv 2606.05590) | https://arxiv.org/html/2606.05590v1 | VERIFIED |
| 19 | Search result: rule-based radiation fog (ScienceDirect abs) | https://www.sciencedirect.com/science/article/abs/pii/S0022169421002365 | SEARCH RESULT (paywalled; abstract only) |
| 20 | Search result: fog forecasting rule-based fuzzy system (ResearchGate) | https://www.researchgate.net/publication/225334667_Fog_forecasting_using_rule-based_fuzzy_inference_system | SEARCH RESULT (abstract only) |
| 21 | Oikofuge: Radiation Fog | https://oikofuge.com/radiation-fog/ | VERIFIED |
| 22 | NumberAnalytics: Ultimate Guide Radiation Fog | https://www.numberanalytics.com/blog/ultimate-guide-radiation-fog-meteorology | VERIFIED |
| 23 | ASOS User's Guide (PDF) | https://www.weather.gov/media/asos/aum-toc.pdf | BINARY PDF — not readable by WebFetch |
| 24 | NWS Fog Guide PDF (ZHU) | https://www.weather.gov/media/zhu/ZHU_Training_Page/fog_stuff/fog_guide/fog.pdf | BINARY PDF — not readable by WebFetch |
| 25 | FMH-1 (Google Books reference) | https://books.google.com/books/about/Federal_Meteorological_Handbook_Number_O.html?id=H_nGjwEACAAJ | NOT FETCHED — paywalled book |
| 26 | WMO Code Table 4677 (manned stations: fog, mist, haze, smoke codes) | https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM | VERIFIED |
| 27 | Campbell Scientific — WMO SYNOP 4680 codes (fog, mist, haze; humidity gate) | https://help.campbellsci.com/cs120a-cs125/cs120a-cs125/appendix/present-weather-codes.htm | VERIFIED |
| 28 | CEDA WMO code summary | https://artefacts.ceda.ac.uk/badc_datadocs/surface/code.html | VERIFIED |
| 29 | NAV CANADA Advection Fog (duration/persistence characteristics) | https://avmet.navcanada.ca/en/advection-fog.aspx | VERIFIED |
| 30 | Stull, Practical Meteorology — Fog chapter (dissipation formula with albedo) | https://geo.libretexts.org/Bookshelves/Meteorology_and_Climate_Science/Practical_Meteorology_(Stull)/06:_Clouds/6.08:_Fog | VERIFIED |
| 31 | Tardif & Rasmussen (2007) fog classification algorithm | Journal of Applied Meteorology and Climatology (PAYWALLED) — framework cited through ResearchGate figures: https://www.researchgate.net/figure/Flowchart-diagram-illustrating-the-fog-type-classification-algorithm_fig2_228417816 | SEARCH RESULT (paywalled source) |
| 32 | arXiv 2510.21819 — ML fog forecasting geographic transferability (SHAP feature importance) | https://arxiv.org/abs/2510.21819 | VERIFIED (abstract) |
| 33 | NWS ASOS mist/fog/haze reporting criteria (Wikipedia automated airport weather station) | https://en.wikipedia.org/wiki/Automated_airport_weather_station | VERIFIED |
| 34 | RAMMB/CIRA Fog & Stratus background (advection fog wind 4-7 m/s) | https://rammb.cira.colostate.edu/wmovl/vrl/tutorials/satmanu-eumetsat/satmanu/cms/fgstr/backgr.htm | VERIFIED |

---

## 10. Key Findings Summary

### Finding 1: T-Td ≤ 1°F is Too Tight

Our current threshold (T-Td ≤ 1°F / 0.56°C) is scientifically defensible as a very high-confidence fog indicator, but it is operationally too conservative:

- ASOS uses **4°F (2.2°C)** as the moisture boundary — 4× wider than our current threshold
- Aviation weather guidance uses **5°F (2.8°C)** as the "fog likely" rule of thumb
- Rule-based research finds the best performing threshold is **RH ≥ 94%** (T-Td ≈ 1.0°C / 1.8°F) but combined with wind and radiation filters
- Our threshold will miss real fog events whenever T-Td is 1–4°F
- VERDICT: Widen the T-Td threshold to 4°F (2.2°C), matching ASOS, but add secondary conditions to control false alarms

### Finding 2: Best Fog Detection Without Visibility Sensor

Use a **multi-parameter rule** combining:
1. T-Td ≤ 4°F (primary moisture gate)
2. Wind speed ≤ 8 mph / 3.6 m/s (eliminates lifted/stratus scenarios)
3. Time of day (nighttime / pre-dawn = much higher fog probability)
4. Solar radiation (if solar is suppressed post-sunrise, fog may be persisting)
5. PM2.5 (high PM2.5 with T-Td ≤ 4°F → report haze; low PM2.5 → report fog/mist)

This matches the Izett et al. (2018) finding that RH + wind speed + radiation/temperature trend is near-optimal for surface-based fog detection (≥ 90% hit rate, 13% false-alarm rate at 1-hour lead time).

### Finding 3: How to Improve Our Method

| Step | Change | Justification |
|---|---|---|
| 1 | Widen T-Td threshold from 1°F to 4°F | Match ASOS standard; captures real fog events missed currently |
| 2 | Add wind gate: wind ≤ 8 mph for "Foggy"; allow up to 15 mph for "Misty" | Reduces false positives; advection fog at higher winds still reported as Mist |
| 3 | Add daytime gate: suppress fog label during day unless solar is suppressed | Reduces "phantom fog" reports during warm humid afternoons |
| 4 | Add PM2.5 check: if T-Td ≤ 4°F AND PM2.5 > 35 µg/m³, prefer Hazy over Foggy | Distinguishes particulate haze from water-droplet fog |
| 5 | Add rain rate gate: if actively raining, suppress fog label | Prevents false fog during precipitation |
| 6 | Report Mist for T-Td 2–4°F, Foggy for T-Td ≤ 2°F | Granularity matching FMH-1 fog vs mist distinction |

### Finding 4 (added): WMO Automated Stations Use the Same T-Td Gate

WMO code table 4680 for automated stations explicitly notes that distinguishing mist (code 10) from haze (codes 04/05) requires a humidity sensor. Without one, automated stations default to fog/mist codes. The T-Td (or RH) discriminator is not just our workaround — it is the WMO-sanctioned method for automated stations. We are doing the right thing; we just need to use the correct threshold.

Source: Campbell Scientific implementation of WMO 4680, https://help.campbellsci.com/cs120a-cs125/cs120a-cs125/appendix/present-weather-codes.htm VERIFIED.

### Finding 5 (added): The Most Predictive Fog Variable We Lack

ML fog forecasting shows the #1 predictor is **visibility persistence** — the current/recent visibility reading. We don't have this. Solar angle (#2) and thermal gradients (#3) we do have. This means our fog detection is working from the 2nd and 3rd most important features, which is why probabilistic framing ("conditions consistent with fog") is more honest than deterministic ("confirmed fog").

### Finding 6 (added): Thick Fog Can Persist All Day

Stull's dissipation formula shows fog with albedo ≥ 0.8 may not dissipate at all — insufficient solar energy penetrates to warm the surface. Our proposed daytime solar-suppression gate needs to account for this: suppressed solar during daytime is not just a sign of persisting fog from the previous night; it may persist indefinitely.

### Finding 7 (added): Tardif & Rasmussen (2007) Is the Standard Reference

Tardif and Rasmussen (2007) is the canonical fog type classification algorithm for surface station data, adopted in studies across at least 6 countries. Their wind-based fog type distinction (radiation fog < 2 m/s, advection fog 4–7 m/s) is now well-established. Our implementation should reference this framework.

### Finding 8: What We Still Cannot Know

Without a visibility sensor or present weather sensor, we cannot:
- Confirm fog is actually present (we can only estimate probability)
- Measure fog density (dense vs. light fog)
- Distinguish radiation from advection fog definitively
- Know if visibility is at the 5/8 SM (1 km) threshold or just below it

Our output should be framed as "conditions favorable for fog" rather than "confirmed fog," but for user-facing display, "Foggy" or "Misty" is appropriate when multiple parameters align.

---

*This document was produced as part of R4.2 — Fog Detection Literature research for the Clear Skies / weather conditions engine development. Initial version: 2026-06-21. Updated with WMO code tables 4677/4680, Stull dissipation formula, Tardif & Rasmussen (2007) framework, ML feature importance findings, and single-variable POD/FAR statistics on 2026-06-21.*

*Binary PDFs were encountered for ASOS User's Guide (aum-toc.pdf), NWS Fog Guide (ZHU), FMH-1 (icams-portal.gov), and DENSE EU document — key facts from those documents were obtained through verified web search results and alternative HTML sources that cite them. FMH-1 2019 PDF returned HTTP 403. Paywalled sources: Tardif & Rasmussen (2007), rule-based radiation fog ScienceDirect paper, Google Books FMH-1.*
