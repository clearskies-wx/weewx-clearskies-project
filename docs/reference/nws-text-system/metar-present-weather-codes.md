# METAR Present Weather Codes — Archive Reference

**Task:** R3.1 — METAR-to-Text and Present Weather Codes  
**Archived:** 2026-06-21  
**Status:** Research complete — all claims sourced from fetched documents

---

## Sources

- **WMO Code Table 4677** (manned station present weather codes, 00–99): https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM
- **WMO Code Table 4680** (automated station present weather codes): https://docs.vaisala.com/r/M211607EN-AA/en-US/GUID-4ACEA762-2E41-4FDC-92CA-201C64FEA045/GUID-A16C18DE-D8AF-4525-8C46-FD31D65DF819 and https://aci-standards.atlassian.net/wiki/spaces/ACIDD/pages/17699481
- **NWS Instruction 10-503** (current): https://www.weather.gov/media/directives/010_pdfs/pd01005003curr.pdf (PDF, confirmed URL accessible)
- **NWS Instruction 10-503** (archived rev c): https://www.weather.gov/media/directives/010_pdfs_archived/pd01005003c.pdf
- **ASOS Algorithm — fog/mist/haze discrimination rule**: https://www.avwxtraining.com/post/summertime-vfr-and-haze
- **FMH-1** (Federal Meteorological Handbook No. 1, "Surface Weather Observations and Reports," FCM-H1-1995, 5th ed. with amendments): https://met.nps.edu/~bcreasey/mr3222/files/labs/3-Fed-Met-Handbook-sfc-wx-obs-FMH1.pdf (2005 version, most recent accessible copy; the ofcm.gov domain hosting later amendments is defunct as of 2026)
- **CFI Notebook — Obstructions to Visibility**: https://www.cfinotebook.net/notebook/weather-and-atmosphere/obstructions-to-visibility
- **AviationRef METAR Weather Decoder**: https://www.aviationref.com/metar-weather
- **Meteocentre METAR Reference**: https://meteocentre.com/doc/metar.html
- **Wikipedia — METAR**: https://en.wikipedia.org/wiki/METAR
- **CEDA WMO Meteorological Codes**: https://artefacts.ceda.ac.uk/badc_datadocs/surface/code.html

---

## METAR Present Weather Code Structure

A present weather group is built as:

```
[Intensity] [Descriptor] [Precipitation or Obscuration]
```

- **Intensity** (optional): `-` = Light, _(none)_ = Moderate, `+` = Heavy
- **Descriptor** (optional): MI BC PR DR BL SH TS FZ VC
- **Phenomenon**: precipitation type OR obscuration type

Maximum three present weather groups per METAR, each separated by a space. Source: meteocentre.com

---

## Intensity Modifiers

| Symbol | Meaning |
|--------|---------|
| `-` | Light |
| _(no prefix)_ | Moderate |
| `+` | Heavy |
| `VC` | Vicinity (5–10 SM from station, not at station) |

---

## Descriptor Codes

| Code | Meaning | Permitted with |
|------|---------|----------------|
| MI | Shallow (≤2 m vertical extent) | FG only |
| BC | Patches (irregular, discontinuous) | FG only |
| PR | Partial (covers part of aerodrome) | FG only |
| DR | Low drifting (below eye level) | SN, DU, SA |
| BL | Blowing (at or above eye level) | SN, DU, SA |
| SH | Shower(s) | RA, SN, PE, GR, GS |
| TS | Thunderstorm | alone, or with RA/SN/PE/GR/GS |
| FZ | Freezing | DZ, RA, FG only |
| VC | In the vicinity | SH, TS, FG, BLSN, DS, SS, PO, FC |

Note: TS and SH cannot be used together in the same group. Source: meteocentre.com

---

## Obstruction-to-Vision Codes (US METAR)

These are the codes most relevant to local surface weather observations.

### HZ — Haze

- **Definition (FMH-1 §8.3.2g):** "A suspension in the air of extremely small, dry particles invisible to the naked eye and sufficiently numerous to give the air an opalescent appearance." NOT water droplets.
- **METAR trigger (ASOS algorithm):** Prevailing visibility < 7 SM AND dewpoint depression (temperature − dewpoint) > 4°F (~2°C), AND no precipitation occurring
- **Visibility range:** Reported when vis < 7 SM; no lower visibility limit specified (can be very low)
- **RH boundary:** RH typically < 80%. By definition it is dry-particle obscuration, not moisture-based. When dewpoint depression ≤ 4°F, ASOS codes BR or FG instead.
- **Intensity modifiers:** None applied to HZ in US METAR practice
- **Descriptor:** None
- **ASOS behavior:** ASOS automatically reports HZ when visibility sensor detects vis < 7 SM and dewpoint depression > 4°F. Smoke (FU), dust (DU), sand (SA) are NOT auto-reported by ASOS — require human augmentation.
- **Important note:** The T-Td > 4°F threshold is an ASOS operational algorithm rule, NOT an FMH-1 standard. FMH-1 defines haze by physical composition (dry particles); the ASOS algorithm uses dewpoint depression as a proxy to discriminate dry-particle vs water-particle obscurations without human observation.
- Source: FMH-1 FCM-H1-2005 §8.3.2g (archived: `FMH-1_FCM-H1-2005.pdf`); cfinotebook.net; avwxtraining.com

### FG — Fog

- **Definition (FMH-1 §8.3.2b):** "A visible aggregate of minute water particles (droplets) which are based at the Earth's surface and reduces horizontal visibility to less than 5/8 statute mile and, unlike drizzle, it does not fall to the ground."
- **METAR trigger (ASOS algorithm):** Prevailing visibility < 5/8 SM (< 1 km) AND dewpoint depression ≤ 4°F (~2°C)
- **Temperature condition:** Temperature and dewpoint within approximately 5°F/2°C of each other (high RH)
- **RH boundary:** Typically near 100% (saturation or near-saturation)
- **Intensity modifiers:** None applied to FG in standard US METAR
- **Fog descriptors allowed:** MIFG (shallow fog, ≤6 ft vertical extent), BCFG (patches of fog), PRFG (partial fog, covering < half aerodrome), FZFG (freezing fog, droplets at T < 0°C)
- **Note:** MIFG, BCFG, PRFG may be coded even when prevailing visibility ≥ 7 SM if the local phenomenon is present
- **FZFG:** Any fog with predominantly supercooled water droplets (T < 0°C) and vis < 5/8 SM
- Sources: aviationref.com; cfinotebook.net; Wikipedia METAR; earlier search result citing FMH-1

### BR — Mist

- **Definition (FMH-1 §8.3.2a):** "A visible aggregate of minute water particles suspended in the atmosphere that reduces visibility to less than 7 statute miles but greater than or equal to 5/8 statute miles."
- **METAR trigger (ASOS algorithm):** Prevailing visibility ≥ 5/8 SM AND < 7 SM AND dewpoint depression ≤ 4°F (~2°C)
- **Visibility range:** 5/8 SM ≤ vis < 7 SM  
- **RH boundary:** 95–99% (high relative humidity but below fog saturation)
- **Intensity modifiers:** None (BR shall not be coded with any intensity or descriptor)
- **International note:** WMO/ICAO standard uses 1 km as the fog threshold (instead of 5/8 SM ≈ 1 km); the US FMH-1 uses 5/8 SM. Wikipedia gives BR as 1–5 km (international); US practice is 5/8 SM to < 7 SM.
- Source: cfinotebook.net; aviationref.com; avwxtraining.com; Wikipedia METAR

### FU — Smoke

- **Definition:** Suspension in the air of small particles produced by combustion (wildfires, industrial sources, etc.)
- **METAR trigger:** Visibility reduced by smoke; no automatic ASOS reporting — requires human augmentation
- **Visibility range:** Can reduce visibility to near zero; reported when visibility is impacted
- **Descriptor:** None standard
- **Intensity:** Not typically intensity-coded
- Source: cfinotebook.net; avwxtraining.com

### VA — Volcanic Ash

- **Definition:** Ash particles suspended from volcanic eruption
- **METAR trigger:** Any visibility impact from volcanic ash; human-augmented only
- Source: aviationref.com

### DU — Widespread Dust

- **Definition:** Widely distributed fine soil particles in suspension not raised locally by current wind
- **Trigger:** Visibility ≤ 6 SM; human augmented (not ASOS auto-reported)
- Source: meteocentre.com

### SA — Sand

- **Definition:** Sand particles raised by wind, generally from desert surfaces
- **Trigger:** Visibility ≤ 6 SM; human augmented
- Source: meteocentre.com

### PY — Spray

- **Definition:** Water droplets raised from water surface by wind; always coded as BLPY
- Source: Wikipedia METAR

---

## Summary: HZ / BR / FG Discrimination Algorithm (ASOS)

This is the ASOS automatic decision logic. Note: FMH-1 defines haze/mist/fog by physical composition (dry particles vs water droplets). Since automated stations cannot visually distinguish particle type, the ASOS algorithm uses dewpoint depression as a proxy. Source: avwxtraining.com, confirmed against FMH-1 FCM-H1-2005 definitions.

```
IF prevailing visibility < 7 SM:
    IF dewpoint depression (T − Td) ≤ 4°F (~2°C):
        IF visibility < 5/8 SM:
            Report FG (fog)
        ELSE (visibility ≥ 5/8 SM and < 7 SM):
            Report BR (mist)
    ELSE (dewpoint depression > 4°F):
        IF no precipitation occurring:
            Report HZ (haze)
        ELSE (precipitation present):
            Do NOT report HZ separately
                (precipitation group already in METAR)
ELSE (visibility ≥ 7 SM):
    No obstruction code reported
```

**Key boundary:** 4°F (~2.2°C) dewpoint depression separates moisture-based codes (FG/BR) from dry-particle code (HZ).

**Key visibility thresholds (US):**
- HZ: vis < 7 SM, T−Td > 4°F
- BR: 5/8 SM ≤ vis < 7 SM, T−Td ≤ 4°F
- FG: vis < 5/8 SM, T−Td ≤ 4°F

---

## Precipitation Codes

| Code | Type | Notes |
|------|------|-------|
| RA | Rain | Non-freezing |
| DZ | Drizzle | Fine drops, not reaching ground with force |
| SN | Snow | |
| SG | Snow Grains | Very small white opaque grains |
| IC | Ice Crystals | Diamond dust; vis ≤ 6 SM |
| PL | Ice Pellets (US) / PE (old) | Frozen raindrops; transparent/translucent |
| GR | Hail | Dia. ≥ 5 mm |
| GS | Graupel / Snow Pellets / Small Hail | Dia. < 5 mm |
| UP | Unknown Precipitation | Automated station only |

**Freezing variants:**
- FZDZ — Freezing drizzle
- FZRA — Freezing rain
- FZFG — Freezing fog (descriptor FZ applied to FG)

**Shower/thunderstorm variants:**
- -RASN — Light rain and snow
- TSRA — Thunderstorm with rain
- +TSGR — Heavy thunderstorm with hail

Source: Wikipedia METAR; meteocentre.com

---

## Other Significant Phenomena

| Code | Meaning |
|------|---------|
| SS | Sandstorm; +SS if vis < 5/16 SM |
| DS | Duststorm |
| FC | Funnel cloud; +FC = tornado or waterspout |
| PO | Dust/sand whirls (dust devils) |
| SQ | Squall |
| BLSN | Blowing snow (above eye level) |
| DRSN | Drifting snow (below eye level) |
| BLDU | Blowing dust |
| BLSA | Blowing sand |

---

## WMO Code Table 4677 — Complete Present Weather Codes (Manned Station)

Source: https://www.nodc.noaa.gov/archive/arc0021/0002199/1.1/data/0-data/HTML/WMO-CODE/WMO4677.HTM

### Codes 00–19: No Precipitation at Time of Observation

| Code | Definition |
|------|-----------|
| 00 | Cloud development not observed or not observable |
| 01 | Clouds generally dissolving or becoming less developed |
| 02 | State of sky on the whole unchanged |
| 03 | Clouds generally forming or developing |
| 04 | Visibility reduced by smoke (veldt/forest fires, industrial smoke, volcanic ash) |
| 05 | **Haze** |
| 06 | Widespread dust in suspension in air, not raised by wind at or near station |
| 07 | Wind-raised dust/sand, no developed whirls or storms |
| 08 | Well-developed dust whirls or sand whirls seen; no duststorm or sandstorm |
| 09 | Duststorm or sandstorm within sight at time of observation |
| 10 | **Mist** |
| 11 | Patches of shallow fog or ice fog (≤2 m on land, ≤10 m at sea) |
| 12 | Continuous shallow fog or ice fog (≤2 m on land, ≤10 m at sea) |
| 13 | Lightning visible, no thunder heard |
| 14 | Precipitation within sight, not reaching ground (virga) |
| 15 | Precipitation within sight reaching ground, > 5 km from station |
| 16 | Precipitation within sight reaching ground, near station but not at station |
| 17 | Thunderstorm but no precipitation at time of observation |
| 18 | Squalls at or within sight of the station |
| 19 | Funnel cloud(s) visible at station |

### Codes 20–29: Past-Hour Phenomena (Occurred During Preceding Hour, Not at Obs Time)

| Code | Definition |
|------|-----------|
| 20 | Drizzle (not freezing) or snow grains not falling as shower(s) |
| 21 | Rain (not freezing) not falling as shower(s) |
| 22 | Snow not falling as shower(s) |
| 23 | Rain and snow or ice pellets |
| 24 | Freezing drizzle or freezing rain |
| 25 | Shower(s) of rain |
| 26 | Shower(s) of snow, or of rain and snow |
| 27 | Shower(s) of hail, or of rain and hail |
| 28 | Fog or ice fog |
| 29 | Thunderstorm (with or without precipitation) |

### Codes 30–39: Duststorms, Sandstorms, Blowing Snow

| Code | Definition |
|------|-----------|
| 30 | Slight/moderate duststorm or sandstorm — decreasing during past hour |
| 31 | Slight/moderate duststorm or sandstorm — no appreciable change |
| 32 | Slight/moderate duststorm or sandstorm — beginning or increasing |
| 33 | Severe duststorm or sandstorm — decreasing during past hour |
| 34 | Severe duststorm or sandstorm — no appreciable change |
| 35 | Severe duststorm or sandstorm — beginning or increasing |
| 36 | Slight or moderate drifting snow (generally low, below eye level) |
| 37 | Heavy drifting snow (generally low, below eye level) |
| 38 | Slight or moderate blowing snow (generally high, above eye level) |
| 39 | Heavy blowing snow (generally high, above eye level) |

### Codes 40–49: Fog or Ice Fog at Time of Observation

| Code | Definition |
|------|-----------|
| 40 | Fog or ice fog at a distance but not at station; sky visible above observer |
| 41 | Fog or ice fog in patches |
| 42 | Fog or ice fog, sky visible, has become thinner during past hour |
| 43 | Fog or ice fog, sky obscured, has become thinner during past hour |
| 44 | Fog or ice fog, sky visible, no appreciable change |
| 45 | Fog or ice fog, sky obscured, no appreciable change |
| 46 | Fog or ice fog, sky visible, has begun or become thicker |
| 47 | Fog or ice fog, sky obscured, has begun or become thicker |
| 48 | Fog depositing rime, sky visible |
| 49 | Fog depositing rime, sky obscured |

### Codes 50–59: Drizzle

| Code | Definition |
|------|-----------|
| 50 | Drizzle, not freezing, intermittent, slight |
| 51 | Drizzle, not freezing, continuous, slight |
| 52 | Drizzle, not freezing, intermittent, moderate |
| 53 | Drizzle, not freezing, continuous, moderate |
| 54 | Drizzle, not freezing, intermittent, heavy |
| 55 | Drizzle, not freezing, continuous, heavy |
| 56 | Drizzle, freezing, slight |
| 57 | Drizzle, freezing, moderate or heavy |
| 58 | Drizzle and rain, slight |
| 59 | Drizzle and rain, moderate or heavy |

### Codes 60–69: Rain

| Code | Definition |
|------|-----------|
| 60 | Rain, not freezing, intermittent, slight |
| 61 | Rain, not freezing, continuous, slight |
| 62 | Rain, not freezing, intermittent, moderate |
| 63 | Rain, not freezing, continuous, moderate |
| 64 | Rain, not freezing, intermittent, heavy |
| 65 | Rain, not freezing, continuous, heavy |
| 66 | Rain, freezing, slight |
| 67 | Rain, freezing, moderate or heavy |
| 68 | Rain or drizzle and snow, slight |
| 69 | Rain or drizzle and snow, moderate or heavy |

### Codes 70–79: Solid Precipitation (Non-Shower)

| Code | Definition |
|------|-----------|
| 70 | Snow, intermittent, slight |
| 71 | Snow, continuous, slight |
| 72 | Snow, intermittent, moderate |
| 73 | Snow, continuous, moderate |
| 74 | Snow, intermittent, heavy |
| 75 | Snow, continuous, heavy |
| 76 | Diamond dust (ice crystals), with or without fog |
| 77 | Snow grains, with or without fog |
| 78 | Isolated star-like snow crystals, with or without fog |
| 79 | Ice pellets |

### Codes 80–99: Shower and Thunderstorm Precipitation

| Code | Definition |
|------|-----------|
| 80 | Rain shower(s), slight |
| 81 | Rain shower(s), moderate or heavy |
| 82 | Rain shower(s), violent |
| 83 | Shower(s) of rain and snow mixed, slight |
| 84 | Shower(s) of rain and snow mixed, moderate or heavy |
| 85 | Snow shower(s), slight |
| 86 | Snow shower(s), moderate or heavy |
| 87 | Shower(s) of snow pellets or small hail, slight |
| 88 | Shower(s) of snow pellets or small hail, moderate or heavy |
| 89 | Hail shower(s), slight (no thunder) |
| 90 | Hail shower(s), moderate/heavy (no thunder) |
| 91 | Slight rain at time of observation, thunderstorm during past hour |
| 92 | Moderate/heavy rain, thunderstorm during past hour |
| 93 | Slight snow/mixed precipitation/hail, thunderstorm past hour |
| 94 | Moderate/heavy snow/mixed precipitation/hail, thunderstorm past hour |
| 95 | Thunderstorm, slight or moderate, without hail but with rain and/or snow |
| 96 | Thunderstorm, slight or moderate, with hail |
| 97 | Thunderstorm, heavy, without hail but with rain and/or snow |
| 98 | Thunderstorm combined with duststorm or sandstorm |
| 99 | Thunderstorm, heavy, with hail |

---

## WMO Code Table 4680 — Present Weather Codes (Automated Station)

Source: https://docs.vaisala.com/r/M211607EN-AA/en-US/... and https://aci-standards.atlassian.net/wiki/spaces/ACIDD/pages/17699481

Simplified table used by automatic weather stations (ASOS/AWOS). Subset of 4677.

| Code | Definition |
|------|-----------|
| **00** | No significant weather observed |
| **04** | Haze, smoke, or dust in suspension in the air — visibility ≥ 1 km |
| **05** | Haze, smoke, or dust in suspension in the air — visibility < 1 km |
| **10** | Mist |
| **20** | Fog (occurred during preceding hour, not at observation time) |
| **21** | Drizzle or snow grains (preceding hour) |
| **22** | Rain, not freezing (preceding hour) |
| **23** | Snow (preceding hour) |
| **24** | Freezing rain or freezing drizzle (preceding hour) |
| **30** | Fog |
| **31** | Fog or ice fog in patches that has become thinner |
| **32** | Fog or ice fog in patches with little change |
| **33** | Fog or ice fog in patches that has begun or become thicker |
| **34** | Fog depositing rime |
| **40** | Precipitation (unspecified) |
| **41** | Precipitation, slight or moderate |
| **42** | Precipitation, heavy |
| **50** | Drizzle |
| **51** | Drizzle, slight |
| **52** | Drizzle, moderate |
| **53** | Drizzle, heavy |
| **54** | Freezing drizzle, slight |
| **55** | Freezing drizzle, moderate |
| **56** | Freezing drizzle, heavy |
| **60** | Rain |
| **61** | Rain, slight |
| **62** | Rain, moderate |
| **63** | Rain, heavy |
| **64** | Freezing rain, slight |
| **65** | Freezing rain, moderate |
| **66** | Freezing rain, heavy |
| **67** | Rain/drizzle and snow, slight |
| **68** | Rain/drizzle and snow, moderate or heavy |
| **70** | Snow |
| **71** | Snow, slight |
| **72** | Snow, moderate |
| **73** | Snow, heavy |
| **74** | Ice pellets, slight |
| **75** | Ice pellets, moderate |
| **76** | Ice pellets, heavy |
| **80** | Showers/intermittent precipitation |
| **81** | Rain showers, slight |
| **82** | Rain showers, moderate |
| **83** | Rain showers, heavy |
| **84** | Rain showers, violent (> 32 mm/h) |
| **85** | Snow showers, slight |
| **86** | Snow showers, moderate |
| **87** | Snow showers, heavy |
| **89** | Hail |

---

## Mapping: WMO 4677/4680 → METAR Present Weather Codes

| WMO 4677 | WMO 4680 | METAR Code | Phenomenon |
|----------|----------|------------|-----------|
| 05 | 04/05 | HZ | Haze |
| 10 | 10 | BR | Mist |
| 04 | 04 | FU | Smoke |
| 40–49 | 30–34 | FG | Fog |
| 48–49 | 34 | FZFG | Freezing fog (METAR: FG with FZ descriptor) |
| 06–07 | 04 | DU | Dust |
| — | — | SA | Sand |
| 50–59 | 50–56 | DZ / FZDZ | Drizzle / Freezing drizzle |
| 60–65 | 60–63 | RA | Rain |
| 66–67 | 64–66 | FZRA | Freezing rain |
| 70–75 | 70–73 | SN | Snow |
| 77 | — | SG | Snow grains |
| 76 | — | IC | Ice crystals (diamond dust) |
| 79 | 74–76 | PL | Ice pellets |
| 80–82 | 81–84 | SHRA / +SHRA | Rain showers |
| 85–86 | 85–87 | SHSN | Snow showers |
| 89–90 | 89 | GR / GS | Hail |
| 95 | — | TSRA | Thunderstorm with rain |
| 99 | — | +TSGR | Heavy thunderstorm with hail |

---

## Key Visibility Thresholds Summary (US METAR, FMH-1 / NWS Rules)

| Phenomenon | METAR Code | Visibility Threshold | RH / T−Td Condition |
|-----------|------------|---------------------|---------------------|
| Fog | FG | vis < 5/8 SM (< ~1 km) | T−Td ≤ 4°F; RH ~100% |
| Mist | BR | 5/8 SM ≤ vis < 7 SM | T−Td ≤ 4°F; RH 95–99% |
| Haze | HZ | vis < 7 SM | T−Td > 4°F; RH < 80% typical |
| Smoke | FU | vis impacted | No auto-reporting; human augmented |
| Dust | DU | vis ≤ 6 SM | No auto-reporting; human augmented |
| Sand | SA | vis ≤ 6 SM | No auto-reporting; human augmented |
| Sandstorm | SS | vis ≥ 5/16 SM and ≤ 5/8 SM; +SS if < 5/16 SM | — |
| Shallow fog | MIFG | May report even with vis ≥ 7 SM | Fog present at low elevation |
| Patchy fog | BCFG | May report even with vis ≥ 7 SM | Irregular fog patches |
| Partial fog | PRFG | May report even with vis ≥ 7 SM | Fog covering < half aerodrome |
| Freezing fog | FZFG | vis < 5/8 SM | T ≤ 0°C |

**International vs. US difference:** International (ICAO/WMO) uses 1,000 m (approx. 5/8 SM) as the fog threshold. US FMH-1 uses 5/8 SM explicitly.
