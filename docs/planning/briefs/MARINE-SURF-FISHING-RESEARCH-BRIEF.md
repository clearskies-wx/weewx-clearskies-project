# Research Brief: Marine, Surf & Fishing Forecasting — Science, Data Sources & Integration Considerations

**Date:** 2026-07-08  
**Purpose:** Ground the marine/surf/fishing feature plan in real-world forecasting science, data source capabilities, and the critical distinction between model output and observational data  
**Status:** Research only — informs planning discussion, no design decisions made  
**Last updated:** 2026-07-08 (v2 — corrected after user feedback on data source evaluation, surf forecasting approach, and location model)  
**Companion:** [MARINE-DATA-AUDIT-BRIEF.md](MARINE-DATA-AUDIT-BRIEF.md) — code audit of existing extensions and provider landscape survey

---

## 1. The Fundamental Split: Models vs. Observations

This is the single most important concept for the entire marine feature set. Every data source falls into one of two categories, and confusing them leads to bad products.

### Observations (what is happening right now)

Observations come from physical instruments deployed in the ocean — buoys, coastal stations, tide gauges. They tell you what conditions **are** at a specific point in space and time. They are ground truth.

**Strengths:**
- Accurate at the measurement location (instrument error is small and well-characterized)
- Available in near-real-time (most NDBC stations report hourly, CO-OPS every 6 minutes)
- Include parameters that models struggle with (visibility, sea surface temperature from thermistors, actual breaking wave behavior)

**Limitations:**
- Sparse spatial coverage — NDBC has ~1,300 stations, but they're points in a vast ocean. The nearest buoy to your beach might be 50+ miles offshore in deep water
- Gaps in coverage — Southern Hemisphere is extremely sparse, remote Pacific islands have almost nothing
- Equipment failures and maintenance create data gaps
- They tell you what **was** (the latest reading), not what **will be** (no forecast capability)

**Key NDBC observation types:**
- Standard meteorological (`.txt`): wind direction/speed/gust, pressure, air/water temp, dewpoint, visibility, significant wave height, dominant wave period — reported hourly from a 20-minute sampling window
- Spectral wave data (`.spec`): the full wave energy spectrum — distribution of energy across frequencies and directions. This is richer than just "significant wave height" because it reveals multiple swell systems arriving from different directions simultaneously
- ADCP currents (`.adcp`): current speed and direction at multiple depths
- Continuous winds (`.cwind`): 10-minute averaged wind data, updated every 10 minutes

**How significant wave height is actually measured:** A buoy accelerometer records vertical displacement over a 20-minute window. Fourier analysis converts displacement time-series into a frequency spectrum. "Significant wave height" (Hs) is defined as the average height of the highest one-third of waves — a statistical construct, not any single wave you'd see. The "dominant period" is the frequency with peak spectral energy. This matters because Hs = 6 ft with a 15-second period (long-period swell) is a completely different ocean than Hs = 6 ft with a 6-second period (short-period wind chop).

### Model Forecasts (what will happen)

Models are numerical simulations that solve wave physics equations (energy balance, momentum transfer from wind to ocean surface) on a computational grid. They **predict** future conditions across a spatial domain.

**Strengths:**
- Spatial coverage — global models cover the entire ocean
- Temporal coverage — forecasts out to 7-16 days
- Multiple forecast cycles per day (typically 4: 00Z, 06Z, 12Z, 18Z)
- Can separate wave field into components (wind waves vs. swell, primary vs. secondary swell)

**Limitations:**
- Grid resolution limits accuracy. An 8 km grid cell cannot resolve a 200-meter-wide beach, a harbor entrance, or a reef break. The model's value for that cell is an average over 64 square kilometers of ocean.
- Nearshore physics (shoaling, refraction, breaking, bottom friction) are parameterized, not resolved. The widely-used Battjes-Janssen breaking model relies on empirical parameters that don't capture the full range of breaking behavior across different beach slopes and bathymetry.
- Accuracy degrades with forecast horizon: ±0.5m at 24h, ±1m+ at 120h for significant wave height. Period accuracy: ±2-3 seconds at 3-5 days.
- Coastal effects (headlands, islands, harbor resonance, river outflows) are poorly represented
- No visibility forecast (that comes from atmospheric models, not wave models)
- Sea surface temperature from models is interpolated/assimilated, not directly measured

**Available wave models (via Open-Meteo):**
- ECMWF WAM: 9 km global — highest resolution widely available
- Meteo-France MFWAM: 8 km global
- NCEP GFS Wave (WaveWatch III): 16-25 km global — what the Phase II extension downloaded directly as GRIB files
- DWD EWAM: 5 km, Europe only — best resolution for European waters
- DWD GWAM: 25 km global
- ERA5-Ocean: 50 km, historical (back to 1940)

### Why Both Are Needed

A model tells you wave height will be 6 feet tomorrow at your latitude/longitude. A buoy 30 miles offshore currently reads 4 feet with a rising trend. Together: the swell is building as predicted, buoy confirms the model is tracking reality, and you can have confidence the 6-foot forecast is credible. If the buoy reads 2 feet and falling while the model says 6 feet, something is wrong — maybe the swell window shifted, maybe the model initialization was bad.

**For a weather dashboard, the ideal marine page shows both:** model forecast (what's coming) overlaid with or adjacent to the nearest buoy observations (what's actually happening). The NWS does exactly this — forecasters use model guidance but validate against and are constrained by observations.

---

## 2. Marine Forecasting for Boating & Navigation

### What Boaters Need

The NWS Marine Weather Services Program defines the core information boaters require:

| Parameter | Why It Matters | Source |
|-----------|---------------|--------|
| **Wind speed & direction** | Primary safety factor. Determines sea state and wave buildup. 12-13 mph = whitecaps begin. | NWS forecast text + model + buoy obs |
| **Wave height & period** | Safety: swells < 8 ft with period ≥ 2× height are generally manageable for small craft. Short-period chop is more dangerous than same-height long-period swell. | Wave model + buoy obs |
| **Visibility** | Critical for collision avoidance. "Good" = 5+ NM, "Moderate" = 2-5 NM, "Poor" = < 2 NM. Fog is the primary hazard. | NWS forecast text (atmospheric model), buoy obs |
| **Sea surface temperature** | Hypothermia risk, fog formation, weather pattern influence | Buoy obs (precise) + model (spatial coverage) |
| **Tides & currents** | Navigation safety in shallow water, inlet transits, anchoring | CO-OPS predictions (US, harmonic-based) |
| **Hazard warnings** | Small Craft Advisory (21-33 kt wind and/or seas ≥ 10 ft), Gale Warning, Storm Warning | NWS marine zones |

### NWS Marine Zone Forecasts — The Only Source for Official Text

The NWS issues marine forecast text products organized by zone type:
- **Coastal Waters Forecast (CWF):** Bays, harbors, sounds, out to ~100 NM. Subdivided by zone with Universal Generic Code (UGC) identifiers.
- **Offshore Waters Forecast (OFF):** Beyond coastal waters to defined boundaries.

These text products include wind, seas, period, visibility, weather, and hazards — structured narrative that no model API reproduces. The `api.weather.gov` API serves these via `/zones/marine/{zoneId}/forecast` in JSON-LD/GeoJSON format.

**Critical point:** NWS marine forecasts are US-only. There is no global equivalent API. The UK Met Office, Environment Canada, and Australia's BoM each issue their own marine forecasts in different formats, none with a public REST API suitable for automated consumption. For non-US locations, the only option for marine text narratives is to **generate synthetic text from numerical data** — which is exactly what the Clear Skies GFE text engine already does for land weather, and it already has marine vocabulary (wave height phrases, chop categories, marine wind descriptors) translated into 12 languages.

### Marine Observations Are Scarce

The NWS FAQ states the core challenge directly: marine forecasting is much harder than land forecasting because of a **lack of available observations**. Where thousands of observations support a land forecast, only one or two might be available for a local marine forecast. This scarcity is fundamental — it's why model data dominates marine forecasting, and why the few observations that do exist (from NDBC buoys, CO-OPS stations, ship reports) are so valuable.

---

## 3. Surf Forecasting — The "Last Mile" Problem

### Deep Water vs. the Beach

A wave model predicts conditions in deep water (water depth > half the wavelength). What a surfer experiences on a beach is the result of that deep-water swell being **transformed** by the local seafloor as it approaches shore. This transformation involves four physical processes:

**Shoaling:** As water depth decreases below half the wavelength, wave speed decreases and wave height increases. Energy conserved, wavelength compressed, height grows. This is why waves get taller as they approach shore.

**Refraction:** When wave fronts approach the shore at an angle, the shallow-water portion slows while the deep-water portion continues at speed. This bends the wave direction, concentrating energy on headlands and dispersing it in bays. Two beaches 1 mile apart receiving identical deep-water swell can have completely different surf because of refraction around underwater features.

**Breaking:** When wave height exceeds a critical fraction of water depth (the "breaker index," γ), the wave breaks. The breaker index depends on bottom type: sand (γ ≈ 0.78), rock (γ ≈ 1.0), coral reef (γ ≈ 1.2). Bottom type also determines wave shape — sand bottoms create spilling breakers, reef creates plunging barrels.

**Bottom friction and dissipation:** Energy loss from interaction with the seafloor, especially over shallow reef or sandbar approaches.

### Why No API Can Give You a Surf Forecast

Surfline (the industry standard) uses a proprietary model called LOTUS calibrated with 35 years of data, wave buoy assimilation, and per-spot tuning. This is why no public API provides surf forecasts — the transformation from deep water to a specific beach requires:

1. High-resolution local bathymetry (the shape of the ocean floor approaching the break)
2. Knowledge of the break type (point break, beach break, reef break)
3. Beach orientation (determines which swell directions produce rideable waves)
4. Tide state (low tide = shallow = hollow/fast waves; high tide = deep = slow/mushy; most breaks work best at mid-tide)
5. Local wind (offshore wind = clean faces; onshore = chop; cross-shore = variable)

**Beach breaks** add another layer of instability — sandbars shift with storms and seasons, so the same beach can produce different surf quality month to month.

### What We Can Realistically Provide

Without Surfline's proprietary calibration data, Clear Skies can provide:
- Deep-water swell forecast at the operator's coordinates (from wave models via Open-Meteo/Xweather)
- Nearest buoy observations for ground truth
- Basic surf quality estimation using the scoring algorithm from the Phase II extension (wave height + period + wind direction/speed + swell dominance)
- Tide overlay (from CO-OPS or WorldTides) showing when conditions are likely best
- The wave transformation physics code from Phase II (shoaling, refraction, breaking) could be wired in as an enrichment processor if the operator provides spot-specific config (beach facing, bottom type, and ideally bathymetric profile from GEBCO)

**Expectation setting:** This will be a useful tool for "is it worth checking the surf?" — not a Surfline replacement. The star rating gives a directional signal. The raw data (swell height, period, direction, wind, tide) gives an experienced surfer everything they need to make their own call.

---

## 4. Fishing Forecasts — Multi-Factor Scoring

### The Science (and Its Limits)

Fishing forecasts combine multiple environmental factors to predict fish feeding activity. The evidence base varies by factor:

**Strongest evidence:**
- **Water temperature:** Fish metabolism roughly doubles with every 10°C increase. Species have well-documented optimal temperature ranges. This is the most reliably predictive factor — if water temperature is outside a species' comfort zone, nothing else matters.
- **Barometric pressure trend:** Research consistently shows falling pressure triggers increased feeding (fish detect pressure changes via swim bladders and lateral lines). Stable high pressure = moderate activity. Rapid drops = feeding frenzy (fish "know" bad weather limits future feeding opportunities). Rising pressure after a front = slow fishing initially, improving over 12-24 hours.
- **Tide state and current:** Water movement concentrates baitfish and triggers predatory feeding. Outgoing (ebb) tide is generally rated highest (flushes bait from estuaries), incoming flood is second, slack tides (high and low) are poorest.

**Moderate evidence:**
- **Time of day:** Dawn and dusk feeding peaks are well-established for most species. Low-light conditions favor ambush predators. Midday is generally poorest except in deep water or overcast conditions.
- **Moon phase (solunar theory):** Formalized by John Alden Knight in 1926. Theory: major feeding periods when moon is directly overhead (transit) or underfoot, minor periods at moonrise/moonset. Major periods last 2-3 hours, minor 1-2 hours. Scientific evidence is mixed — some peer-reviewed studies show correlations for specific species, others find no significant effect. The practical consensus among anglers is that solunar periods are useful as a tiebreaker when other conditions are favorable, but water temperature, pressure, and tides matter more.

**Weaker/anecdotal evidence:**
- Cloud cover influence on feeding (widely believed, inconsistently supported)
- Wind direction effects (traditional wisdom varies by region)
- Lunar illumination (distinct from solunar positioning — affects nighttime visibility for predators)

### Solunar Computation

Solunar calculations are pure celestial mechanics — moon position relative to the observer. Clear Skies already uses **Skyfield** for almanac computations (moon phases, planet positions). Solunar times require:
- Moon transit (overhead): highest point in sky — major period
- Moon underfoot: opposite side of Earth — major period  
- Moonrise: minor period
- Moonset: minor period
- Moon phase: modulates intensity (new/full moon = strongest periods)

No external API call needed. Computable for any location on Earth. The algorithm is well-defined and deterministic.

### What a Fishing Forecast Page Needs

1. **Solunar calendar:** Major and minor feeding periods for each day, color-coded by intensity
2. **Conditions overlay:** Barometric pressure (current reading + 3-hour trend), tide state (from tide data), water temperature (from buoy obs or SST model), wind
3. **Activity rating:** Composite score combining solunar + pressure + tide + temperature + time-of-day
4. **Species-specific adjustments:** Different fish categories (freshwater sport, saltwater inshore, saltwater offshore, bottom fish) respond differently to the same conditions. The Phase II extension had configurable species modifiers — this is the right approach.

---

## 5. The NOAA Data Ecosystem — A Complete Inventory

NOAA provides the most comprehensive marine data system in the world. Before evaluating third-party providers, we need to understand what NOAA already offers for free, at what resolution, and through what access methods.

### 5.1 Wave Models — NOAA WaveWatch III

NOAA's operational WaveWatch III runs as a **multigrid production system** with nested grids at multiple resolutions:

| Grid | Resolution | Coverage | Purpose |
|------|-----------|----------|---------|
| Global | 30 arc-min (~50 km) | Worldwide | Open ocean baseline |
| Regional (3 grids) | 10 arc-min (~16 km) | US East Coast, US West Coast, Eastern Pacific/Hawaii | US coastal wave forecasts |
| Coastal (2 grids) | 4 arc-min (~7 km) | US East Coast, US West Coast | Higher-res coastal wave detail |

All grids have **internal two-way coupling** — the regional grids feed back into the global grid during computation. The regional grids (e.g., `atlocn.0p16` for the Atlantic, `wcoast.0p16` for the West Coast) are what the Phase II extension downloaded directly. These are **higher resolution than Open-Meteo's 8 km grids** for US coastal areas — the 4-minute (~7 km) coastal grids are comparable, and the 10-minute (~16 km) regional grids are identical.

**Data access:**
- **GRIB via NOMADS FTP** — raw grid files, highest resolution, requires GRIB processing library (eccodes/pygrib). This is what the Phase II extension uses.
- **ERDDAP** — NOAA serves WaveWatch III data via ERDDAP with JSON, CSV, and NetCDF output formats. This provides **REST-style access to the same model data without GRIB processing**. URL pattern: `https://erddap.aoml.noaa.gov/hdb/erddap/griddap/WaveWatch_2026.json?...` with lat/lon/time subsetting.
- **OPeNDAP** — programmatic subset access, similar to ERDDAP.

**Key finding: ERDDAP gives us JSON access to WaveWatch III data at the same resolution as GRIB, without the eccodes dependency.** This potentially eliminates the GRIB-vs-REST tradeoff entirely — we can get NOAA's own high-resolution data via a REST-like JSON interface.

Model runs: 4× daily (00Z, 06Z, 12Z, 18Z). Forecast horizon: 7 days at 3-hour steps.

### 5.2 Nearshore Wave Prediction System (NWPS)

NOAA operates a **separate nearshore wave model** called the Nearshore Wave Prediction System (NWPS), which runs the SWAN (Simulating Waves Nearshore) model for US coastal Weather Forecast Office (WFO) domains. **NWPS does NOT supplant WaveWatch III — it nests inside it.** WaveWatch III provides the deep-water boundary conditions; NWPS/SWAN takes those boundaries and runs high-resolution nearshore physics.

| Aspect | WaveWatch III | NWPS (SWAN) |
|--------|--------------|-------------|
| Resolution | 7–50 km | CG1: ~1.8 km (1 nmi), CG2–CG5: 500m down to **50m** at tidal inlets, some WFOs use unstructured meshes at 200m–5 km |
| Domain | Global + US regional | Individual WFO coastal domains |
| Physics | Spectral wave, deep/intermediate water | Full nearshore: shoaling, refraction, breaking, bottom friction, diffraction, **wave-current interaction** (via RTOFS-Global currents) |
| Forcing | GFS winds | **Forecaster-prepared local wind grids** (submitted by individual WFOs) |
| Boundary conditions | Self-generated | Fed from WaveWatch III operational multigrid |
| Water levels | None | Incorporates ESTOFS or P-SURGE water levels |
| Output | Integrated wave parameters, spectra | Wave parameters, spectra, individually tracked wave systems, **rip current probability** (v1.5), **wave runup** (v1.5), total water level |
| Run schedule | 4× daily (00/06/12/18Z) | **On-demand** — triggered when a WFO submits new wind grids. Not all cycles run every day. |

**NWPS grid nesting (example: WFO Morehead City / MHX):**
- CG1: Overall domain, 1 nmi (~1.8 km) uniform resolution
- CG2: 500 m (focused coastal area)
- CG3: 50 m (tidal inlet)
- CG4: 500 m (second focused area)
- CG5: 100 m (second inlet)

12 WFOs (HGX, MOB, TAE, KEY, MLB, JAX, CHS, ILM, PHI, GYX, ALU, GUM) use unstructured meshes with variable resolution of 5 km to 200 m.

**v1.5 additions (Western + Southern Region WFOs: LOX, MTR, EKA, MFR, PQR, BRO, LCH, LIX, plus Alaska AJK/AER/AFG and Eastern LWX):**
- Erosion occurrence probability
- Overwash occurrence probability
- Wave runup, setup, swash
- Total water level (tide + wind + waves)
- Rip current probability
- Total water level above dune toe/crest

**Data access:**
- **GRIB2 via FTP/HTTPS:** `ftp://ftp.ncep.noaa.gov/pub/data/nccf/com/nwps/prod/` organized by region (sr, er, wr, pr, ar) → date → WFO → cycle → CG.
- File naming: `{WFO}_nwps_CG{n}_{YYYYMMDD}_{CC}00.grib2`
- **No ERDDAP or JSON endpoint.** NWPS output is GRIB2 only. Consuming it requires GRIB processing (eccodes or pygrib).
- **On-demand runs mean data availability is unpredictable** — not all WFOs submit grids every cycle.

**Implication:** NWPS is the highest-resolution nearshore wave data available anywhere, and it includes rip current forecasts and total water level — both directly relevant to beach safety. But it requires GRIB processing, and its on-demand nature makes it unreliable as a sole data source. It is best used as a **supplement** to WaveWatch III (via ERDDAP JSON) when available, not as a replacement.

**NWPS has bathymetry built in.** SWAN requires bottom topography as a fundamental input — it's what drives shoaling, refraction, bottom friction, and depth-limited breaking. NWS WFOs configure their NWPS domains with bathymetry from NOAA hydrographic surveys and ETOPO/GEBCO, typically at higher resolution than the public GEBCO API (~450m). The NWPS output fields (wave height, period, etc.) are **post-transformation values** — the nearshore physics have already been computed. However, the bathymetry grid itself is not exposed in the GRIB2 output; only derived variables (like bottom orbital velocity, UBOT) that reveal seabed effects.

**Relationship to our surf physics code and GEBCO bathymetry:**

**NWPS covers ALL 36 US coastal WFOs.** There are no geographic gaps along the US coastline. Every US coastal spot has an NWPS domain. What varies across WFOs is feature level and grid type:

| Feature | Coverage |
|---------|----------|
| Base NWPS (wave height, period, direction, currents, wave setup) | All 36 coastal WFOs |
| Unstructured mesh (200m–5 km variable resolution) | 22 WFOs (TBW, MFL, SJU, MHX, AKQ, OKX, BOX, CAR, SGX, HFO, HGX, MOB, TAE, KEY, MLB, JAX, CHS, ILM, PHI, GYX, ALU, GUM) |
| Regular grid (1.8 km CG1, nested CG2–CG5 at 500m–50m) | Remaining 14 WFOs |
| v1.5 products (rip current, runup, total water level, erosion) | ~12 WFOs (LOX, MTR, EKA, MFR, PQR, BRO, LCH, LIX, AJK, AER, AFG, LWX) — rolling out |

**Operational availability (verified July 2026):** Despite being described as "on-demand," all 36 coastal WFOs produce NWPS runs on a regular schedule — typically 2–3 cycles per day (00z, 06z, 12z). Data is available on NOMADS within hours of each cycle. NWPS data is never more than ~8–12 hours old under normal operations.

| Scenario | NWPS available? | Our physics code | GEBCO bathymetry |
|----------|----------------|-----------------|-----------------|
| **Any US coastal spot** | **Yes** — all 36 WFOs have domains, 2–3 runs/day | **Supplements NWPS** with four corrections (breaker index, structure effects, sub-grid interpolation, topographic focusing). Also drives the scoring algorithm. | Needed for fishing habitat structure and surf spot setup (slope computation for Battjes formula). |

GEBCO is always needed for fishing habitat identification. For US, NWPS is the primary nearshore source, with our code supplementing NWPS output for the four specific corrections defined in ADR-084.

### 5.2.1 Supplementing NWPS with Site-Specific Corrections — Research Basis

Supplementing coarse-grid model output with site-specific corrections is **standard practice in coastal engineering and surf forecasting.** This is not "double-dipping" — it's addressing documented model limitations with established methods.

**Research findings:**

1. **SWAN's single breaker index is a known limitation.** Research (Battjes 1974, Goda 2010, Carini et al. 2021) shows the breaker index γ varies from ~0.6 to ~1.2 depending on bottom slope, wave steepness, and bottom type. Plunging breakers on steep/hard bottoms: γ = 0.73–0.81. Spilling breakers on gentle sand: γ = 0.63–0.71. SWAN uses a single γ across its entire grid. Tuning γ per site improves model accuracy (Coastal Wiki, multiple studies). Our Phase II values (sand=0.78, rock=1.0, coral=1.2) are in the empirically documented range. The proper formula is Battjes 1974: γ = 1.06 + 0.14 ln ξ (where ξ = slope/√(H₀/L₀)).

2. **SWAN cannot model diffraction behind structures.** SWAN is a phase-decoupled model. Research (Enet et al., Holthuijsen et al.) confirms it cannot properly model wave diffraction behind breakwaters, jetties, or piers. A diffraction approximation exists but requires grid cells < 1/10 wavelength, which is "unrealistic for large computational domains." NWPS grid cells at 1.8 km (or even 200m) cannot resolve a 100m jetty's shadow zone. Simple transmission/reflection coefficients are crude but address a real gap that NWPS cannot fill.

3. **Statistical downscaling from model output to site-specific predictions is validated.** Research (Camus et al. 2011, multiple studies) shows direction-dependent transfer functions between offshore model output and nearshore conditions can be "comparable to measurements" and in some cases "more accurate than numerical models." Because bathymetry and coastal morphology are relatively stable, a strong correspondence exists between offshore and nearshore wave spectra — this is the theoretical basis for all nearshore transformation.

4. **Surfline's LOTUS model validates the pipeline.** Surfline (industry standard) starts with WaveWatch III, runs proprietary nearshore transformation using local bathymetry, then applies machine learning calibration trained on 1M+ observations. Their core approach — offshore model + nearshore transformation + site-specific correction — is the same pipeline our Phase II code implements. Their ML calibration achieves 30–70% error reduction over uncorrected model output.

**How our code should supplement NWPS (US spots):**

| Supplement | Method | Validity |
|-----------|--------|----------|
| **Breaker index by bottom type** | Correct NWPS breaking limit using empirical γ formula (Battjes 1974) with operator-configured bottom type and slope. Apply to the final breaking calculation, not a re-transformation of the full wave field. | **Validated.** Multiple studies show site-specific γ tuning improves accuracy. |
| **Coastal structure effects** | Apply transmission/reflection coefficients for operator-configured structures (jetty, breakwater, pier). Present as qualitative adjustment with caveats. | **Valid for gross effects.** SWAN cannot model these. Crude coefficients > ignoring structures entirely. Don't claim precise wave heights behind structures. |
| **Scoring algorithm** | Take NWPS-provided wave height (already transformed), tide state, wind quality, swell dominance → compute 1–5 star surf quality rating. | **Our enrichment.** This is scoring/judgment, not physics. NWPS doesn't produce surf quality ratings. |
| **Sub-grid interpolation** | Interpolate NWPS output to exact spot coordinates between grid points. | **Standard practice.** Spatial interpolation of gridded data. |
| **Statistical calibration (future)** | Over time, compare forecasts to nearest buoy observations. Build per-spot bias correction. | **Validated approach** (Surfline does this at scale). Requires observation accumulation over time — v2+ feature. |

**Sources:**
- [Battjes 1974 breaker formula — Coastal Wiki](https://www.coastalwiki.org/wiki/Breaker_index)
- [Carini et al. 2021 — Predicting Breaking and Breaker Type (JGR Oceans)](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020JC016935)
- [Modified breaker index for spectral models (Ocean Engineering 2022)](https://www.sciencedirect.com/science/article/abs/pii/S0029801822018108)
- [SWAN diffraction limitations (ResearchGate)](https://www.researchgate.net/publication/316009724_Improving_the_Performance_of_SWAN_Modelling_to_Simulate_Diffraction_of_Waves_Behind_Structures)
- [Nearshore downscaling — dynamical vs statistical (Camus et al.)](https://www.sciencedirect.com/science/article/abs/pii/S0924796309001523)
- [Surfline ML surf forecasting (Medium/Surfline Labs)](https://medium.com/surfline-labs/machine-learning-for-surf-forecasting-4a007f13b3e3)
- [Surfline LOTUS model](https://www.surfline.com/lp/whatsnew/features/lotus-swell-model)
- [Parameterization of nearshore breaker index (arXiv)](https://arxiv.org/pdf/2104.00208)

### 5.3 NDBC Buoy Observations

~1,300 stations. Primarily US waters and open ocean, with some international coverage via WMO coordination.

| Data Type | File Extension | What It Measures | Frequency | Access |
|-----------|---------------|-----------------|-----------|--------|
| Standard Meteorological | `.txt` | Wind dir/speed/gust, significant wave height, dominant period, mean wave direction, pressure, air/water temp, dewpoint, visibility | Hourly (20-min sample) | HTTP flat file |
| Spectral Wave Density | `.swden` | Full frequency spectrum of wave energy (46 bands, 0.02–0.485 Hz) | Hourly | HTTP flat file |
| Spectral Wave Direction | `.swdir` | Mean wave direction at each spectral frequency | Hourly | HTTP flat file |
| Continuous Winds | `.cwind` | 10-min averaged wind speed/direction/gust | Every 10 min | HTTP flat file |
| ADCP Currents | `.adcp` | Current speed/direction at multiple water depths | Varies | HTTP flat file |
| Oceanographic | `.ocean` | Depth-profiled water temp, salinity, dissolved oxygen | Varies | HTTP flat file |

**Spectral data is critical for surf forecasting.** A buoy reporting Hs = 6 ft tells you nothing about whether that's a clean 15-second swell (excellent surf potential) or a messy mix of 8-second wind chop (poor surf despite the same height number). The spectrum reveals multiple swell systems arriving simultaneously from different directions — this is the data experienced surfers and marine forecasters use. The Phase I extension only consumed standard met data; the spectral data is a significant upgrade path.

**Access method:** NDBC serves data as flat text files via HTTP (not a REST API). URL pattern: `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.txt`. Data is also available via DODS/OPeNDAP in NetCDF format. Station metadata (locations, sensor types, owner) available via `activestations.xml`.

### 5.4 CO-OPS Tides, Water Levels & Coastal Met

NOAA CO-OPS operates 420+ stations with the most comprehensive US coastal data available. Three APIs:

| API | Base URL | What It Provides |
|-----|---------|-----------------|
| Data Retrieval API | `api.tidesandcurrents.noaa.gov/api/prod/` | Water levels, tide predictions, currents, met observations |
| Metadata API | `api.tidesandcurrents.noaa.gov/mdapi/prod/` | Station locations, sensors, datums, harmonic constituents |
| Derived Product API | `api.tidesandcurrents.noaa.gov/dpapi/prod/` | Computed products (datums, trends) |

**Products available:**
- **Water level observations** — 6-minute and 1-minute intervals. Real-time to support tsunami detection.
- **Tide predictions** — harmonic-based high/low predictions, on-the-fly for any station with harmonic constituents. Also 6-minute and hourly continuous predictions.
- **Current predictions** — 6-minute, half-hour, hourly tidal currents. Max flood/ebb timing and slack water timing.
- **Meteorological observations** — wind speed/direction, air temperature, water temperature, barometric pressure, relative humidity, visibility. Not all stations have all sensors.

**Output formats:** JSON, XML, CSV, KML, NetCDF, TXT, DODS. JSON is well-structured and directly consumable.

**This is the authoritative US tide source.** Harmonic predictions computed from actual gauge measurements, not model approximations. CO-OPS predictions are what the NWS uses, what NOAA Navigation Charts reference, and what every tide table in the US is derived from.

### 5.5 NWS Marine Zone Forecasts

The NWS issues text forecasts for marine zones via `api.weather.gov`:
- **Coastal Waters Forecast (CWF):** Bays, harbors, sounds, out to ~100 NM
- **Offshore Waters Forecast (OFF):** Beyond coastal waters to defined boundaries

Each zone has a Universal Generic Code (UGC). The API endpoint `GET /zones/marine/{zoneId}/forecast` returns JSON-LD/GeoJSON with structured forecast periods including wind, seas, visibility, weather conditions, and hazard warnings.

**This is the only source for official marine forecast text in the US.** No model API replicates the judgment that NWS forecasters apply when writing these products. For non-US locations, no equivalent global API exists.

---

## 6. Evaluating Our Three Providers Against NOAA

The critical comparison: what do Open-Meteo and Xweather actually add beyond what NOAA provides directly?

### 6.1 Open-Meteo Marine — Full Model Inventory

| Model | Resolution | Coverage | Update | Forecast Range |
|-------|-----------|----------|--------|---------------|
| ECMWF WAM | 9 km | Global | 6-hourly | 15 days |
| ECMWF WAM 0.25° | ~25 km | Global | 6-hourly | 15 days |
| MeteoFrance MFWAM | ~8 km | Global | 12-hourly | 10 days |
| NCEP GFS Wave 0.16° | ~16 km | 52.5°N to 15°S | 6-hourly | 16 days |
| NCEP GFS Wave 0.25° | ~25 km | Global | 6-hourly | 16 days |
| DWD EWAM | ~5 km | **Europe only** | 12-hourly | 8 days |
| DWD GWAM | ~25 km | Global | 12-hourly | 4 days |
| ERA5-Ocean | ~50 km | Global | Daily (5-day delay) | Historical only |

**Key observation:** Open-Meteo's NCEP GFS Wave 0.16° model IS the same WaveWatch III regional data we'd get from NOAA ERDDAP. Open-Meteo is repackaging it. For US coastal areas, going through Open-Meteo adds a middleman without adding resolution. The ECMWF WAM at 9 km and MeteoFrance MFWAM at 8 km are the only models that offer something NOAA doesn't directly provide — and those matter primarily for **non-US** locations.

The DWD EWAM at 5 km is the highest-resolution model for European waters specifically.

### 6.2 Wave Forecast Comparison

| Attribute | NOAA WaveWatch III (direct via ERDDAP) | NOAA NWPS (GRIB2 only) | Open-Meteo Marine | Xweather Maritime |
|-----------|----------------------------------------|------------------------|-------------------|-------------------|
| US coastal resolution | **~7 km** (4 arc-min coastal grids) | **50m–1.8 km** | 8–16 km (wraps the same NOAA data or ECMWF) | Undisclosed (likely wraps NOAA/ECMWF) |
| Global resolution | ~50 km (30 arc-min) | N/A (US only) | **8–9 km** (ECMWF WAM / MFWAM) | Undisclosed |
| Europe resolution | ~50 km | N/A | **5 km** (DWD EWAM) | Undisclosed |
| Access format | **JSON via ERDDAP** | GRIB2 only | REST JSON | REST JSON |
| Swell components | Primary + wind wave | Full spectral | Up to 3 systems | Primary + secondary + tertiary |
| Physics | Deep/intermediate water | **Full nearshore** (shoaling, refraction, breaking, currents) | Deep/intermediate water | Deep/intermediate water |
| Cost | Free | Free | Free (non-commercial) | 1× per request (already keyed) |
| Rip current forecast | No | **Yes** (v1.5 WFOs) | No | No |
| Source independence | Primary source | Primary source | **Wraps NOAA + ECMWF + DWD** | **Wraps NOAA + ECMWF** |

### 6.3 Assessment

**For US operations:** NOAA is definitively the primary source. WaveWatch III via ERDDAP (JSON) provides ~7 km coastal resolution — the same or better than what Open-Meteo repackages. NWPS adds 50m–1.8 km nearshore detail with full physics, rip currents, and total water level, but requires GRIB processing. Open-Meteo and Xweather add no value for US wave data — they're wrapping the same NOAA models at the same or lower resolution.

**For international operations:** Open-Meteo genuinely adds value. ECMWF WAM at 9 km and MFWAM at 8 km provide meaningful global coverage that NOAA's 50 km global grid cannot match. DWD EWAM at 5 km is the best available for European waters. Xweather adds value as a commercial fallback with SLA guarantees, though without disclosing its resolution it's hard to assess the quality.

**Conclusion:** US = NOAA only. WaveWatch III (via ERDDAP JSON) for offshore/coastal wave forecasts + NWPS (via GRIB2) for nearshore refinement where available + NDBC for observations + CO-OPS for tides/water levels + NWS for marine text forecasts and alerts. No third-party providers needed for US operations.

International coverage is out of scope for v1. When the need arises, provider selection for international marine data will be evaluated at that time — no decisions have been made yet.

### 6.4 NWPS Data Value Across Activities

SWAN (the model NWPS runs) produces variables useful across ALL marine activities, not just surfing:

| NWPS Variable | Surfing | Fishing | Boating/Marine | Beach Safety |
|---------------|---------|---------|----------------|--------------|
| Wave height at nearshore resolution | Primary surf scoring input | Pier/shore safety | Small craft risk at harbor | Swim safety |
| Swell height (separated from wind waves) | Critical for quality | Minor | Swell vs chop distinction | Moderate |
| Wave direction | Which swell hits the break | Minor | Critical for heading | Moderate |
| Wave setup (SETUP) | Water depth at break | Pier water level | Dock flooding | **Coastal flooding** |
| Current velocity (VEL) | Rip currents, paddle-out | **Critical** — currents move bait, affect drift | **Critical** — inlet transit, anchoring | **Rip currents** |
| Bottom orbital velocity (UBOT) | Minor | **Interesting** — affects sediment stirring, water clarity, bottom fish behavior | Minor | Minor |
| Fraction of breakers (QB) | Where waves break | Minor | Avoid breaking zones | **Breaking wave hazard** |
| Rip current probability (v1.5) | Paddle-out safety | Minor | Minor | **Primary safety metric** |
| Total water level (v1.5) | Beach access | Pier access | **Dock flooding, clearance** | **Coastal inundation** |
| Wave runup (v1.5) | Minor | Minor | Minor | **How far up the beach waves reach** |

### 6.5 Bathymetry Has Two Distinct Uses

GEBCO bathymetry (15 arc-second / ~450m resolution) serves different purposes for different activities:

**For surfing:** Bathymetry defines the wave transformation path — how waves shoal, refract, and break approaching this specific beach. The Phase II `BathymetryProcessor` computes a depth profile between deep water and the surf break for physics calculations.

**For fishing:** Bathymetry defines **fish habitat structure**. Drop-offs, ledges, reefs, channels, pinnacles, seamounts — these are where fish congregate. Bottom contour changes create current upwelling that brings nutrients. Rocky outcroppings next to sandy flats are prime habitat edges. At 450m resolution, GEBCO reveals major features (shelf breaks, canyons, seamounts) but not fine structure (individual ledges, small rock piles). Still, it's the same data commercial fishing apps (SatFish, FishDope) use to identify productive bottom structure.

**For boating:** Bathymetry matters for depth clearance, anchor selection, and understanding why currents behave the way they do in specific channels and inlets.

### 6.2 Observations

| Attribute | NOAA NDBC | NOAA CO-OPS | Open-Meteo | Xweather |
|-----------|-----------|-------------|------------|----------|
| Buoy observations | **~1,300 stations** | — | None (model only) | None (model only) |
| Water levels | — | **420+ stations, 6-min** | Model-derived, 8 km | Model-derived |
| Coastal met (wind, temp, pressure) | Yes (at buoy) | **Yes (at tide stations)** | None | None |
| Water temperature | At buoy | At tide stations | SST model | SST model |

**Neither Open-Meteo nor Xweather provides observational data.** They wrap models. NOAA is the sole source for real-time observations in US waters. This is a fundamental architectural point: observations and model forecasts are separate data streams with separate provider modules and separate caching strategies.

### 6.3 Tides

| Attribute | NOAA CO-OPS | Xweather `/tides` | Open-Meteo | WorldTides/TidesAtlas |
|-----------|-------------|-------------------|------------|----------------------|
| Coverage | US only | **US only** | Global (model-derived) | Global (8,000–17,400+ stations) |
| Method | Harmonic prediction from gauges | Likely wraps CO-OPS | Ocean model sea-level height | Harmonic prediction from gauges |
| Accuracy | **Authoritative** (used by NOAA charts) | Good (same source) | **"Not recommended for coastal navigation"** — 8 km resolution, ±20 min, ±25 cm | Station-dependent |
| Discrete high/low | Yes | Yes | **No** (continuous field) | Yes |
| Cost | Free | 1× per request | Free | $5–100/month |

**Open-Meteo's tide data is not usable for our purposes.** Their own documentation disclaims it. They don't provide discrete high/low predictions — just a continuous sea-level height field that mixes tidal signal with storm surge and wind setup at 8 km resolution. For tide predictions, NOAA CO-OPS is primary for US; global coverage requires a paid provider or starts as US-only.

Xweather tides are US-only and likely wrap CO-OPS data. They serve as a fallback, not as additional coverage.

---

## 7. Surf Forecasting — Using the Code We Already Built

### 7.1 The Physics Pipeline Exists

The Phase II extension contains a complete wave transformation physics pipeline in `SurfForecastGenerator` (3,213+ lines):

| Physics | Method | Implementation Status |
|---------|--------|--------------------|
| Shoaling | `calculate_shoaling_coefficient()` | **Built.** Linear wave theory, iterative dispersion relation, Ks = √(C₁/C₂), capped at 1.5 |
| Refraction | `calculate_refraction_coefficient()` | **Built.** Snell's Law, Kr = √(cos θ₀/cos θ₁), capped at 1.2 |
| Breaking | `apply_breaking_limit()` | **Built.** Depth-limited: H_max = γ × depth. γ from bottom type (sand=0.78, rock=1.0, coral=1.2). Note: defined twice (lines 4160 and 4581) — second overwrites first. |
| Bottom friction | `_calculate_bottom_friction()` | **Built.** Below 5m depth, max 20% energy loss, coefficients from config. |
| Structure effects | `_apply_structure_wave_effects()` | **Built.** 5 structure types (jetty, pier, breakwater, seawall, groin) with reflection/transmission coefficients. |
| Multi-point transformation | `_apply_multi_point_wave_transformation()` | **Built but not wired.** The pipeline exists at line 5634 but `_transform_to_local_conditions()` is never called from the main forecast loop. |

**The code is there. The bug is that it's not wired in.** The Phase II extension scores surf quality against raw deep-water GFS data instead of running it through the transformation pipeline first. When ported to Clear Skies, the enrichment processor must wire the transformation into the scoring flow: deep-water forecast → transform via bathymetry → then score.

### 7.2 Bathymetry Is Operator-Configured, Not Global

The `BathymetryProcessor` (1,370+ lines) fetches ocean floor depth profiles from GEBCO via the OpenTopoData API. GEBCO provides global bathymetry at 15 arc-second (~450m) resolution. The processor:

1. Finds a deep-water point by searching outward from the surf break along the beach-facing bearing (1 km increments, up to 75 km)
2. Creates a 16-point linear interpolation path between the break and deep water
3. Queries GEBCO API for depth at each point
4. Applies adaptive refinement (gradient-based, up to 3 iterations) with IQR anomaly smoothing
5. Stores the resulting bathymetric profile in configuration

**This is a one-time per-spot operation.** The operator configures their surf spots (lat/lon, beach facing, bottom type), the system downloads bathymetry for those spots, and the profile is stored in `api.conf`. The ocean floor doesn't change (at the resolution we care about). We don't need to be responsible for global bathymetry — each operator gets bathymetry for their configured spots.

Sites like surf-forecast.com prove this approach works at scale. The GEBCO data is freely available worldwide. The physics calculations exist in our codebase for a reason — they represent extensive research and iteration.

### 7.3 Scoring Algorithm

The Phase II surf quality scoring (4 components, weighted):

| Component | Weight | Method |
|-----------|--------|--------|
| Wave Height | 0.35 | Range lookup (0–0.5ft=0.1, 1.5–3=0.8, 3–6=1.0, 10–15=0.6, 15+=0.2) |
| Wave Period | 0.35 | Range lookup (0–6s=0.2, 8–10=0.6, 12–16=1.0, 20+=0.8) |
| Wind Quality | 0.20 | Direction classification (offshore/onshore/cross) + speed brackets |
| Swell Dominance | 0.10 | Energy ratio: swell H²×T² vs wind wave H²×T² |

Stars = `max(1, min(5, int(overall × 5)))`

**This algorithm operates on already-transformed wave parameters.** After porting, the scoring input should be the wave height/period at the beach (post-shoaling/refraction/breaking), not the deep-water value. This is the fix that was missing in Phase II.

### 7.4 What Needs Strengthening vs. What We Reuse

| Aspect | Phase II Status | What to Do |
|--------|----------------|------------|
| Bathymetry processor | Complete, working | Port as-is to enrichment processor; GEBCO API is unchanged |
| Shoaling/refraction/breaking physics | Complete but unwired | Port only the breaker index correction (Battjes 1974) and structure effects as NWPS supplements per ADR-084. Full shoaling/refraction/bottom friction pipeline is NOT ported — NWPS already computes these. |
| Breaking limit (γ) | Fixed values per bottom type (sand=0.78, rock=1.0, coral=1.2) | **Strengthen:** Replace lookup table with Battjes 1974 empirical formula: γ = 1.06 + 0.14 ln ξ, which accounts for both bottom slope AND bottom type. Our current values are in range but a formula is more physically correct. |
| Scoring algorithm | Complete, well-researched weights | Port as-is; weights came from research and discussion |
| Coastal structure effects | 5 structure types with reflection/transmission coefficients | Keep as qualitative adjustment. SWAN/NWPS cannot model diffraction behind structures — our crude parameterization addresses a real gap (research-confirmed). Present with appropriate caveats. |
| Duplicate `apply_breaking_limit` | Two definitions, simpler one overwrites enhanced | Merge: keep the enhanced version |
| Copy-paste forecast loop bug | `_generate_surf_forecast_for_spot` calls fishing generator | Fix: call the correct method |
| `eval()` for unit conversion | Security risk | Replace with safe lookup table |
| Hardcoded US unit conversions | Ignores weewx target_unit | Port to Clear Skies unit converter (UnitTransformer handles this) |
| GFS Wave data input | Direct GRIB download | NWPS (GRIB2, primary nearshore) + WaveWatch III (ERDDAP JSON, offshore wave forecasts). No fallback transformation pipeline. |
| DB storage pattern | REPLACE INTO weewx archive | Replace with Redis cache (ephemeral forecast data) |
| Statistical calibration | Not implemented | **Future (v2+):** Accumulate forecast-vs-observation pairs over time. Build per-spot bias correction transfer functions. Research validates this approach achieves 30–70% error reduction (Surfline). Follows the same pattern as the forecast correction engine (ADR-079). |

---

## 8. Location Model — Activity-Based Multi-Spot Configuration

### 8.1 The Problem

Unlike a fixed weather station (one location, one set of sensors), marine activities are **location-diverse**. An operator living near the coast might care about:

- **Wrightsville Beach** for surfing AND beach safety AND fishing from the pier
- **Masonboro Inlet** for boating (needs tide predictions, current data, wind forecast, small craft advisories)
- **Johnny Mercer's Pier** for fishing (needs tide state, water temp, pressure trend, solunar times)
- **Offshore** for deep-sea fishing (needs wave forecast, SST, current data)

Each location can have **multiple activities**, and each activity needs different data presented differently.

### 8.2 What Defines a "Spot" — Resolution Matters

The granularity of a "spot" depends on the data source resolution:

| Data Source | Resolution | What That Means Geographically |
|-------------|-----------|-------------------------------|
| NOAA WaveWatch III (ERDDAP) | ~7 km coastal | All of Huntington Beach is one grid cell. "North HB" vs "South HB" would get the same deep-water forecast. |
| NOAA NWPS CG1 | ~1.8 km | Can distinguish between different parts of a multi-mile beach, but still coarse for point breaks. |
| NOAA NWPS CG2–CG5 | 500m–50m | Can resolve individual inlets, piers, and jetties. This is the scale of a surf break. |
| GEBCO bathymetry | ~450m (15 arc-sec) | Can resolve major underwater features (reefs, canyons, shoals) but not individual sandbars. |
| NDBC buoy observations | Point measurement | One buoy = one point in the ocean. Nearest buoy might be miles away. |
| CO-OPS tide station | Point measurement | One station = one harbor/pier. Tides vary along a coast. |

**Practical implication:** For deep-water wave forecasts, a "spot" is effectively a ~7 km area — the entire local beach zone gets the same offshore swell data. The differentiation between spots comes from:
1. **Beach facing and bottom type** — which determine how that offshore swell transforms as it approaches THIS beach vs. the one 2 miles away
2. **Bathymetry** — the ocean floor profile is different for each approach
3. **Which NDBC buoy is nearest** — different beaches may have different nearest buoys
4. **Which CO-OPS station is nearest** — different harbors have different tide predictions

So even though two spots 3 miles apart get the same deep-water forecast, their surf quality ratings can differ substantially because the transformation physics (shoaling, refraction, breaking) are computed per-spot using that spot's specific bathymetry and orientation. **This is exactly what the Phase II code does.**

Where NWPS CG2–CG5 grids are available (50m–500m resolution), the model has already resolved these nearshore differences. In those cases, we could pull the NWPS-transformed values directly rather than running our own transformation — but only for the specific WFO domains and grid nesting that NWPS covers.

### 8.3 Configuration Model

Each operator configures **marine locations**, each with:
- Coordinates (lat/lon)
- Name (operator-chosen: "Wrightsville Beach", "Masonboro Inlet", etc.)
- **Multiple activities per location** (one or more of: marine/boating, surf, fishing, beach safety)
- Activity-specific config per location:
  - **Surf:** beach facing, bottom type (sand/rock/coral_reef/mud/mixed), bathymetric profile (auto-downloaded from GEBCO on first setup)
  - **Fishing:** target category (freshwater sport, saltwater inshore, saltwater offshore, bottom fish), target species
  - **Marine/boating:** relevant NWS marine zone code (for text forecasts), small craft advisory threshold
  - **Beach safety:** swim hazard thresholds, rip current (from NWPS where available)

The wizard or admin UI handles the setup. For each location, the system determines which NDBC buoys, CO-OPS stations, and NWS marine zones are relevant, either by auto-discovery (querying metadata APIs) or operator selection.

### 8.4 What This Means for Data Collection

The configured locations inform what data the API needs to fetch:
- Each location's coordinates → nearest NDBC buoy(s) for observations (standard met + spectral data)
- Each location's coordinates → nearest CO-OPS station(s) for tides and water levels
- Each location's NWS zone → marine text forecast
- Each location's coordinates → deep-water wave forecast from NOAA WaveWatch III (via ERDDAP JSON)
- Each location's coordinates → NWPS data if available for that WFO (GRIB2, supplementary)
- Surf spots → bathymetry download (one-time from GEBCO) + wave transformation (each forecast cycle, using our physics code)
- Fishing spots → solunar computation (Skyfield, pure math) + conditions scoring
- All marine locations → spectral data from nearest buoy for multi-swell breakdown

---

## 9. US-First Strategy and Global Expansion Path

### 9.1 What Works for the US Right Now (Free)

| Data Need | US Source | Status | Cost |
|-----------|----------|--------|------|
| Wave forecast (offshore) | NOAA WaveWatch III via ERDDAP (JSON) | Available, ~7–16 km US coastal | Free |
| Wave forecast (nearshore) | NOAA NWPS (SWAN at 500m–1.8 km) | **Needs investigation** — may not have clean API | Free |
| Buoy observations | NDBC (~1,300 stations) | Available, HTTP flat files | Free |
| Tide predictions | CO-OPS (420+ stations, harmonic) | Available, JSON API | Free |
| Water level observations | CO-OPS (6-min real-time) | Available, JSON API | Free |
| Coastal met observations | CO-OPS + NDBC | Available | Free |
| Marine text forecasts | NWS API `/zones/marine/{zoneId}/forecast` | Available, JSON | Free |
| Marine zone warnings | NWS alerts API | Already consumed by Clear Skies | Free |
| SST observations | NDBC buoys (point) + CO-OPS (point) | Available | Free |
| Bathymetry | GEBCO via OpenTopoData | Available globally | Free |
| Solunar computation | Skyfield (already a dependency) | Available globally | Free (local computation) |

**The US marine feature set can be built entirely on free NOAA data.** Open-Meteo and Xweather are not needed for US operations — they're fallback and supplementary sources.

### 9.2 What's Missing for Global Coverage

| Data Need | Global Gap | Path Forward | Notes |
|-----------|-----------|--------------|-------|
| Wave forecast | NOAA global grid is 50 km — too coarse for coastal | Xweather maritime (already keyed, global, likely wraps ECMWF) | Xweather cites NOAA WaveWatch as data source; probably also ECMWF for global |
| Buoy observations | No global API. Each country runs its own network. | Country-by-country integration over time | Southern Hemisphere extremely sparse. No shortcut. |
| Tide predictions | CO-OPS is US-only. Xweather tides also US-only. | Paid provider (WorldTides, TidesAtlas, or TideCheck) when demand materializes | $5–100/mo, but the only path to global tides |
| Water level observations | CO-OPS is US-only | Country-specific agencies | No aggregator exists |
| Marine text forecasts | NWS is US-only. No global aggregator. | GFE text engine synthetic generation from Xweather model data | Clear Skies would be unique here |
| Coastal met observations | NDBC is primarily US | Country-specific agencies | No aggregator exists |

### 9.3 Recommended Approach

**v1: US-only.** Build on NOAA's comprehensive free data ecosystem. The US has every data type needed at usable resolution, for free:
- WaveWatch III via ERDDAP (JSON) for offshore/coastal wave forecasts
- NWPS via GRIB2 for nearshore refinement (requires eccodes/pygrib)
- NDBC for buoy observations (standard met + spectral data)
- CO-OPS for tides, water levels, coastal met
- NWS API for marine zone text forecasts and alerts
- GEBCO via OpenTopoData for bathymetry (global, free)
- Skyfield for solunar computation (local, no API)

No third-party providers for v1. No Open-Meteo. No Xweather marine endpoints.

**Future international expansion:** Xweather maritime is the path — already keyed, already paid, global coverage. Add a paid global tide provider (WorldTides, TidesAtlas, or TideCheck) when non-US demand materializes. GFE text engine generates synthetic marine text narratives from Xweather model data for non-US locations.

**The architecture supports this from day one** — provider domain dispatch, canonical models, and enrichment processors are all country-agnostic. Only the v1 provider module implementations are NOAA-specific. Adding a Xweather maritime module later is the same pattern as adding any other provider.

---

## 10. Decisions Made and Remaining Open Questions

### Decided

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **NOAA is the primary US data source.** No fallback from Open-Meteo/Xweather needed for US operations. | NOAA provides equal or better resolution than Open-Meteo for US waters (they wrap the same NOAA data). NOAA also provides observations and tides that no third-party can replicate. |
| D2 | **v1 is US-only, NOAA-only.** No international provider decisions are in scope. | NOAA provides a complete free ecosystem for US waters (models, observations, tides, text forecasts). International provider selection will be evaluated when that need arises. |
| D3 | **Architecture accommodates future providers.** The dispatch registry pattern supports adding non-NOAA provider modules without architectural changes. | Country-agnostic design, but no premature decisions about which providers would serve international coverage. |
| D4 | **Use ERDDAP for WaveWatch III JSON access.** No GRIB processing needed for deep-water wave data. | ERDDAP serves the same WaveWatch III data as NOMADS GRIB, but in JSON format with lat/lon/time subsetting. Eliminates eccodes dependency for the primary wave forecast source. |
| D5 | **Port the Phase II surf physics code.** Shoaling, refraction, breaking, bathymetry — wire the transformation into the scoring pipeline (fixing the Phase II bug where it was bypassed). | Extensive research and iteration produced this code. The bug is that it wasn't wired in, not that the approach was wrong. |
| D6 | **Spectral data from NDBC is in scope for v1.** Parse `.swden` and `.swdir` files, not just standard met. | Spectral data reveals multi-swell breakdowns critical for accurate surf assessment. Standard met Hs alone doesn't distinguish clean swell from wind chop. |
| D7 | **Multi-activity per location.** Each configured spot can have multiple activities (surf + beach safety + fishing). | An operator's beach might serve surfing, swimming, and pier fishing simultaneously. |
| D8 | **Location-centric page organization.** Master marine page → location sub-pages → activity sections per location. | Matches how people think about the coast ("what's happening at Wrightsville Beach?") rather than activity silos. |
| D9 | **NWPS is worth pursuing as supplementary nearshore data.** | 50m–1.8 km resolution with full nearshore physics, rip currents, total water level. Nothing else comes close. GRIB2-only access is a cost, but the data value justifies it. |

### Open Questions

### Q1: NWPS GRIB Processing — How to Handle

NWPS data is GRIB2-only (no ERDDAP/JSON endpoint). Consuming it requires eccodes or pygrib. The Phase II extension already used pygrib and has a `GRIBProcessor` class (42+ lines with eccodes/pygrib dual backend) that ports cleanly.

Since NWPS covers ALL 36 US coastal WFOs with no geographic gaps (verified: all WFOs run 2–3 cycles/day, July 2026), and since the user has accepted the GRIB dependency, the implementation approach is:
- **Always fetch NWPS for configured US spots.** No fallback transformation pipeline — NWPS availability is operationally reliable.
- **Determine which WFO domain covers each configured spot** at setup time (wizard/admin). Store the WFO code and CG grid identifier in spot config so the API knows which GRIB2 files to fetch.
- **eccodes vs pygrib:** eccodes is the ECMWF C library (more actively maintained, used by operational weather centers). pygrib depends on eccodes under the hood. The Phase II `GRIBProcessor` supports both — keep both backends.

### Q2: Station Auto-Discovery vs. Manual

For NDBC buoys and CO-OPS stations near each configured location: auto-discover (query NDBC `activestations.xml` and CO-OPS metadata API, present nearby stations) with operator override, or require manual station ID entry? Auto-discovery is better UX but adds wizard complexity.

### Q3: International Tides for Future Expansion

When non-US demand materializes, which global tide provider? WorldTides (8K+ stations, $5–100/mo), TidesAtlas (17,400+ stations, 188 countries), or TideCheck (6,470+ stations, 200+ countries)? All are paid. Open-Meteo's model-derived tides are explicitly "not recommended" and don't provide discrete high/low predictions. Xweather tides are US-only. **Not blocking v1 — just needs a decision before international expansion.**

### Q4: International Observation Data

For non-US locations, there's no buoy observation API equivalent to NDBC. Each country runs its own network (UK Met Office, BoM Australia, JMA Japan, etc.) with different formats and access methods. For v1 international, model data from Open-Meteo is the only practical option — but without observations, there's no ground truth layer. **Is model-only marine data good enough to ship, or do we need to state "observations unavailable for this region" and show model data with appropriate caveats?**

### Q5: Marine Alerts Integration

Clear Skies already consumes NWS alerts. Marine-specific alerts (Small Craft Advisory, Gale Warning, Storm Warning, Hurricane Force Wind Warning) should surface on marine location pages. Should these be filtered from the existing alerts provider (checking marine zone codes), or does the marine page need its own alert query scoped to configured marine zone codes?

### Q6: Rip Current Data for Beach Safety

NWPS v1.5 provides rip current probability for select WFOs (LOX, MTR, EKA, MFR, PQR, BRO, LCH, LIX, LWX, plus Alaska). This is unique data — no other source provides rip current forecasts. If we consume NWPS, rip current probability is a compelling beach safety feature. But it's only available for ~12 WFOs. **Include as a "show when available" feature, or defer?**

---

## 11. Supplementary Findings from Original Development Documents

Seven original development documents from the pre-Clear-Skies extension work were reviewed for content not already captured in this brief or the companion Data Audit Brief. This section records the additive findings.

### 11.1 CoastWatch Satellite SST via ERDDAP

NOAA CoastWatch provides satellite-derived sea surface temperature through ERDDAP servers, offering a data source not discussed elsewhere in this brief:

- **JPL MUR SST** (`jplMURSST41`): 0.01° (~1 km) resolution, global, daily. Access via `coastwatch.pfeg.noaa.gov/erddap/griddap/jplMURSST41.json`
- **NOAA Geo-polar Blended Analysis** (`noaacwBLENDEDsstDaily`): 0.05° (~5 km) resolution, global, daily
- **Limitations**: 1–3 day latency, cloud interference gaps (~20% ocean coverage), IR sensors cannot see through clouds
- **Value**: Fills SST gap where NDBC buoys are sparse (Southern Hemisphere, international waters). Spatial coverage that point buoy measurements cannot match. Free.

For v1 (US, NOAA-only), satellite SST supplements NDBC buoy point measurements. For future international expansion, it may be the only SST source in regions without buoy coverage.

### 11.2 GFS-Wave Model Clarifications

The brief refers to "WaveWatch III" throughout, but the operational model is more precisely **GFS Wave** — WaveWatch III one-way coupled with the GFS atmospheric model. Key differences from standalone WaveWatch III:

- **Wind forcing**: 30-minute intervals (vs. 3-hour for standalone WW3), improving accuracy
- **Forecast range**: 384 hours total — hourly for 0–120h, 3-hourly for 120–384h. The plan's 72h scope is a design choice, not a model limitation.
- **Data availability delay**: ~4.5 hours after model run time (00Z available ~04:30 UTC, etc.)
- **Southern Ocean grid** (`gsouth.0p25`): 25 km, 10.5°S to 79.5°S — relevant for future international (Australia, Indonesia, South Africa). Not mentioned in Section 5.1.
- **GRIB file sizes**: Regional grids ~10–15 MB per file, global ~20–30 MB. A 72-hour forecast is ~500 MB–1 GB total storage.
- **GRIB Filter endpoint**: `nomads.ncep.noaa.gov/cgi-bin/filter_gfs_wave.pl` can subset by parameters and region without downloading entire files — a potential complement to ERDDAP access.

### 11.3 Multi-Swell Integration Methodology

The original research produced detailed decision rules for combining multiple swell trains that go beyond the "swell dominance" factor (0.10 weight) described in Section 7.3:

**Energy superposition** (when applicable — similar periods ±3s, compatible directions ±45°):
- Convert heights to energy: E = (ρ × g × H²) / 8
- Sum energies: E_total = E₁ + E₂
- Combined height: H_combined = √(H₁² + H₂²)
- Combined period: T_combined = (T₁ × E₁ + T₂ × E₂) / (E₁ + E₂)

**Dominant swell selection** (the decision rules):
- If primary swell energy > 75% of total → use primary swell only
- If secondary swell energy > 50% of primary → apply energy superposition
- Otherwise → use dominant swell component only

**Directional filtering**: Before combining, check each swell component against the spot's 8-direction directional exposure. Swell from blocked directions is eliminated before scoring. This is the purpose of the directional exposure config added to T0C.2 in the plan.

Research basis: WaveWatch III spectral partitioning (Chawla et al. 2013), WaveSEP algorithm (Hanson & Phillips 2001), Australian BoM AUSWAVE operational practice.

### 11.4 Expanded Wave Quality Assessment Framework

The Phase II scoring (4 components, Section 7.3) was informed by a richer quality assessment framework from the original research:

**Period quality multipliers** (more granular than the binary "groundswell vs wind swell"):
| Period | Multiplier | Classification |
|--------|-----------|----------------|
| 18+ s | 1.5 | Exceptional long-period groundswell |
| 15–17 s | 1.3 | Excellent groundswell |
| 12–14 s | 1.0 | Good groundswell (baseline) |
| 10–11 s | 0.7 | Marginal — weak groundswell |
| 8–9 s | 0.4 | Poor — short period |
| <8 s | 0.1 | Very poor — wind swell only |

**Wind direction quality coefficients**:
| Wind condition | Factor |
|---------------|--------|
| Offshore light (0–10 mph) | 1.2 |
| Offshore moderate (10–20 mph) | 1.0 |
| Offshore strong (20–30 mph) | 0.8 |
| Onshore light (0–10 mph) | 0.8 |
| Onshore moderate (10–20 mph) | 0.5 |
| Onshore strong (20+ mph) | 0.2 |
| Cross-shore light (0–15 mph) | 0.7 |
| Cross-shore strong (15+ mph) | 0.3 |

**Beach angle alignment factors** (swell direction vs. beach perpendicular):
| Angle from perpendicular | Factor |
|-------------------------|--------|
| ±15° | 1.0 |
| ±30° | 0.8 |
| ±45° | 0.6 |
| ±60° | 0.3 |
| >60° | 0.1 |

**Time-of-day adjustments**: Dawn +10%, morning +5%, midday standard, afternoon -10%, evening +5%. Based on typical diurnal wind patterns (calm mornings, onshore afternoons).

**Tidal stage factors**: Optimal stage 1.2, good 1.0, marginal 0.7, poor 0.3 (spot-specific — some breaks work best at low tide, others at high).

### 11.5 Coastal Structure Wave Physics

The original research produced material-based coefficient tables with uncertainty ranges and research citations, extending beyond the Phase II code's fixed values:

**Material category coefficients** (research-validated):
| Category | Reflection (Kr) | Transmission (Kt) | Dissipation (Kd) | Structures |
|----------|----------------|-------------------|------------------|------------|
| Impermeable | 0.80 ± 0.10 | 0.10 ± 0.05 | 0.20 ± 0.10 | Concrete seawalls, solid jetties |
| Semi-Permeable | 0.45 ± 0.15 | 0.35 ± 0.15 | 0.45 ± 0.15 | Rock revetments, rubble breakwaters |
| Permeable | 0.20 ± 0.10 | 0.75 ± 0.10 | 0.25 ± 0.10 | Pile piers, open structures |

Energy conservation constraint: Kr² + Kt² + Kd² = 1

**Spatial influence zones** (from Goda 2000, CERC 1984):
- Reflection effects extend 2–5 wavelengths from structure
- Shadow zone extends 1–2 structure lengths behind breakwaters, 3–5 lengths partial shadow
- Effects diminish approximately as 1/r² with distance

**Structure influence zone multipliers**:
| Type | Influence zone | Shadow zone |
|------|---------------|-------------|
| Jetty | 3–5 × length | 2–3 × length |
| Pier | 1–2 × length | Minimal |
| Breakwater | 2–4 × length | 1–2 × length |
| Seawall | Height × 20 | Minimal |
| Groin | 2–3 × length | 1–2 × length |

**Multi-structure dominance**: Dominance = Material weight (0.4) + Distance weight (0.4) + Size weight (0.2). Linear superposition is valid when structures are separated by >5 wavelengths.

Sources: Zanuttigh & Van der Meer (2006), Goda (2000), Isaacson (1991), CERC (1984), Chakrabarti (2005).

### 11.6 Regional Fishing Forecast Model

The original development research envisioned a significantly richer fishing scoring model than the 4-component system described in Section 4. Key additions:

**Biogeographic region classification** — 11 US regions auto-determined from coordinates, each with distinct species lists by fishing category. Regions: Atlantic Northeast, Atlantic Southeast, Gulf Coast, Pacific Southwest (SoCal), Pacific Central, Pacific Northwest, Alaska, Hawaii, Great Lakes, Caribbean, Pacific Territories. Based on NOAA Large Marine Ecosystem boundaries and Costello et al. (2017) marine biogeographic realms.

**Species behavioral profiles** — per-species parameters that modulate the base environmental score:
- **Pressure sensitivity** correlated with swim bladder size: tuna (absent → very low sensitivity), mahi-mahi (small → low), flounder (adapted → moderate), redfish/striped bass/walleye (large → high)
- **Water temperature preferences** with 5 ranges per species: optimal (1.2× multiplier), good (1.0×), poor (0.6×), inactive_below (0.1×), inactive_above (0.1×). Example: Redfish optimal 65–75°F, Striped Bass optimal 55–68°F, Snook inactive below 60°F.
- **Spawning season multipliers**: Redfish Aug-Nov (2.5× peak Sep-Oct "bull redfish run"), Striped Bass Apr-Jun (3.0× peak May "spawning run"), Snook May-Sep (2.2× but 0.0× during Jun-Aug closed season)
- **Migration patterns** by month affecting location preference
- **Time-of-day multipliers** per species (dawn, morning, midday, dusk, night)

**Dynamic scoring formula**: Final score = base environmental score × water temperature multiplier × seasonal behavior multiplier. Species classified as active / less_active / inactive per forecast period.

### 11.7 Distance-Based Data Quality Thresholds

Research from García-Reyes & Largier (2012) and Bourassa et al. (2019) established distance-based quality decay for marine data:

| Distance | Wave quality | Atmospheric quality | Tide quality |
|----------|-------------|-------------------|-------------|
| 0–25 mi | 1.0 (excellent) | 1.0 | 1.0 |
| 25–50 mi | 0.8 (good) | 1.0 | 0.8 |
| 50–100 mi | 0.6 (fair) | 0.8 | 0.6 |
| 100–200 mi | 0.3 (poor) | 0.6 | 0.3 |
| 200+ mi | — | 0.4 | — |

Atmospheric patterns show stronger coherence alongshore (0.7× decay factor) than cross-shore (1.3× decay factor). These thresholds inform station auto-discovery in the wizard (T6.1): stations farther than "good" quality distance should trigger a recommendation for additional coverage.

### 11.8 Additional Scientific Citations

Not already in this brief's Sources section:

- Komar, P.D. (1998). *Beach Processes and Sedimentation*, 2nd Edition. Prentice Hall.
- Holthuijsen, L.H. (2007). *Waves in Oceanic and Coastal Waters*. Cambridge University Press.
- Wiegel, R.L. (1964). *Oceanographical Engineering*. Prentice-Hall.
- CERC (1984). *Shore Protection Manual*, 4th Edition. U.S. Army Corps of Engineers.
- McCowan, J. (1894). On the highest wave of permanent type. *Philosophical Magazine*, 38, 351-358.
- Chawla, A., et al. (2013). A Multigrid Wave Forecasting Model. *Weather and Forecasting*, 28(4), 1057-1078.
- Hanson, J.L. & Phillips, O.M. (2001). Wind Sea and Swell Delineation. *Proceedings 7th International Workshop on Wave Hindcasting and Forecasting*.
- Zanuttigh, B. & Van der Meer, J.W. (2006). Wave reflection from coastal structures. *Coastal Engineering*, 55(4), 357-372.
- Goda, Y. (2000). *Random Seas and Design of Maritime Structures*. World Scientific.
- Isaacson, M. (1991). Measurement of Regular Wave Reflection. *JWPCOE*, 117(6), 553-569.
- Chakrabarti, S.K. (2005). *Handbook of Offshore Engineering, Volume 1*. Elsevier.
- Costello, M.J., et al. (2017). Marine biogeographic realms and species endemicity. *Nature Communications*, 8(1), 1057.
- García-Reyes, M. & Largier, J. (2012). Seasonality of coastal upwelling. *JGR: Oceans*, 117(C3).
- Bourassa, M.A., et al. (2019). Remotely Sensed Winds for Marine Forecasting. *Frontiers in Marine Science*, 6, 443.

## Sources

- [NDBC Wave Measurement FAQ](https://www.ndbc.noaa.gov/faq/wavecalc.shtml)
- [NDBC Observation Data Descriptions](https://www.ndbc.noaa.gov/obsdes.shtml)
- [NDBC Web Data Guide](https://www.ndbc.noaa.gov/docs/ndbc_web_data_guide.pdf)
- [NDBC Real-Time Data Access](https://www.ndbc.noaa.gov/faq/rt_data_access.shtml)
- [NDBC Station List](https://www.ndbc.noaa.gov/to_station.shtml)
- [NWS Marine Weather Services](https://www.weather.gov/marine/)
- [NWS Marine Forecasts FAQ](https://www.weather.gov/marine/faq)
- [NWS Marine Weather Safety Rules](https://www.weather.gov/mlb/windsea_rules)
- [NWS Marine Text Forecasts by Zone](https://www.weather.gov/marine/textzones)
- [NWS Marine Zone Map](https://www.weather.gov/marine/AllZones)
- [CO-OPS API Documentation](https://api.tidesandcurrents.noaa.gov/api/prod/)
- [CO-OPS Products](https://tidesandcurrents.noaa.gov/products.html)
- [CO-OPS Metadata API](https://api.tidesandcurrents.noaa.gov/mdapi/prod/)
- [CO-OPS Derived Product API](https://api.tidesandcurrents.noaa.gov/dpapi/prod/)
- [WaveWatch III Model Description](https://polar.ncep.noaa.gov/waves/wavewatch/)
- [WaveWatch III Production Multigrid](https://polar.ncep.noaa.gov/waves/validation/)
- [WaveWatch III Data Access](https://polar.ncep.noaa.gov/waves/ensemble/download.shtml)
- [WaveWatch III Model Upgrade Tech Notice](https://polar.ncep.noaa.gov/waves/ww3-technotice.shtml)
- [ERDDAP WaveWatch III 2026 Data Access](https://erddap.aoml.noaa.gov/hdb/erddap/griddap/WaveWatch_2026.html)
- [NOAA NWPS — Nearshore Wave Prediction System](https://polar.ncep.noaa.gov/nwps/)
- [NWPS — Environmental Modeling Center](https://www.emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/nwps.php)
- [NOAA NWPS Upgrade Announcement](https://www.weather.gov/news/212901-nwps)
- [Xweather Maritime API Documentation](https://www.xweather.com/docs/weather-api/endpoints/maritime)
- [Xweather Tides API Documentation](https://www.xweather.com/docs/weather-api/endpoints/tides)
- [Xweather Tides Stations](https://www.xweather.com/docs/weather-api/endpoints/tides-stations)
- [Xweather Data Source Attribution](https://www.xweather.com/docs/weather-api/resources/credits)
- [Open-Meteo Marine Weather API](https://open-meteo.com/en/docs/marine-weather-api)
- [Open-Meteo Marine Models Integration](https://openmeteo.substack.com/p/new-weather-and-marine-models-integrated)
- [Open-Meteo Tide Discussion (limitations)](https://github.com/open-meteo/open-meteo/discussions/1125)
- [GEBCO Gridded Bathymetry Data](https://www.gebco.net/data-products/gridded-bathymetry-data)
- [GEBCO via OpenTopoData](https://www.opentopodata.org/datasets/gebco2020/)
- [Wave Transformation — Coastal Wiki](https://www.coastalwiki.org/wiki/Wave_transformation)
- [Shallow Water Wave Theory — Coastal Wiki](https://www.coastalwiki.org/wiki/Shallow-water_wave_theory)
- [WorldTides API](https://www.worldtides.info/apidocs)
- [TidesAtlas API](https://tidesatlas.com/api/docs)
- [TideCheck API](https://tidecheck.com/developers)
- [Solunar Calendar and Sport Fishing — In The Spread](https://inthespread.com/blog/solunar-calendar-and-sport-fishing-unlocking-the-secrets-of-tides-335)
- [How to Read a Surf Forecast — Quiver](https://www.quiversurf.app/learn/how-to-read-a-surf-forecast)
- [How to Read a Boating Weather Forecast — Boatzon](https://boatzon.com/blog/boating-weather-forecast-how-to-read-a-boating-weather-report/)
- [Buoy Observation High-Frequency Wave Energy (arXiv)](https://arxiv.org/pdf/2512.01749)
- [Ocean Wave Forecasting with Deep Learning (AGU 2025)](https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2025MS005285)
- [NOAA Marine Forecasts and Predictions](https://marinenavigation.noaa.gov/forecasts.html)
