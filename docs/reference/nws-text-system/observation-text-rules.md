# NWS Observation-to-Text Rules — Archive Reference

**Task:** R3.1 — METAR-to-Text and Present Weather Codes  
**Archived:** 2026-06-21  
**Status:** Research complete — all claims sourced from fetched documents

---

## Sources

- **NWS Forecast Terms (BGM):** https://www.weather.gov/bgm/forecast_terms
- **NWS Terminology (BMX):** https://www.weather.gov/bmx/nwsterms
- **NWS Zone Forecast Terminology (HUN):** https://www.weather.gov/hun/zfp_terminology
- **NWS FFC County Forecast Matrix Guide:** https://www.weather.gov/ffc/rdfexp
- **NWS Glossary — Sky Condition:** https://forecast.weather.gov/glossary.php?word=sky+condition
- **NWS Glossary — Haze:** https://forecast.weather.gov/glossary.php?word=haze
- **Wisconsin AOS — Online Weather Supplemental:** https://www.aos.wisc.edu/~hopkins/online/spring/9907wsup.htm
- **Weather Guys (UW-Madison) — Cloud Cover:** https://wxguys.ssec.wisc.edu/2024/01/08/cloud-cover/
- **NWS Phoenix — Did You Know:** https://www.weather.gov/psr/didyouknow
- **NWS Instruction 10-503 (archived rev c):** https://www.weather.gov/media/directives/010_pdfs_archived/pd01005003c.pdf (PDF confirmed URL exists; binary-compressed, not machine-readable by WebFetch)
- **NWS Forecast Examples (PRZ007 Puerto Rico):** https://forecast.weather.gov/MapClick.php?zoneid=PRZ007
- **NWS Forecast Examples (Los Angeles):** https://forecast.weather.gov/MapClick.php?lat=33.9425&lon=-118.409
- **NWS Forecast Examples (New York):** https://forecast.weather.gov/MapClick.php?textField1=40.728919&textField2=-73.748586

---

## 1. Sky Condition Codes → Plain-Language Text

### 1.1 METAR Sky Condition Codes (Aviation)

METAR uses oktas (eighths of sky) for cloud coverage. Source: NWS Glossary; Wikipedia METAR; meteocentre.com

| METAR Code | Coverage | Oktas |
|-----------|---------|-------|
| SKC | Sky Clear (human report) | 0 |
| CLR | No clouds below 12,000 ft AGL (ASOS/automated) | 0 |
| NCD | Nil Cloud Detected (automated, non-North American) | 0 |
| FEW | Few clouds | 1–2 oktas (1/8–2/8) |
| SCT | Scattered | 3–4 oktas (3/8–4/8) |
| BKN | Broken | 5–7 oktas (5/8–7/8) |
| OVC | Overcast | 8 oktas (8/8) |
| VV | Vertical Visibility (obscured sky — fog, heavy precip) | — |
| TCU | Towering Cumulus | noted separately |
| CB | Cumulonimbus | noted separately |

Sky condition groups are reported as `{code}{height}` (e.g., `SCT045` = scattered at 4,500 ft AGL).

### 1.2 METAR Codes → NWS Public Forecast Text

Source: NWS bgm/forecast_terms; NWS bmx/nwsterms; NWS hun/zfp_terminology; wxguys.ssec.wisc.edu; NWS psr/didyouknow

**Day and night terminology differ for the same cloud coverage.** The key rule: "Sunny" variants apply only during daylight hours. At night, "Clear" variants apply. Source: NWS bmx/nwsterms; NWS psr/didyouknow

| METAR Coverage | Oktas | Daytime Text | Nighttime Text |
|---------------|-------|-------------|----------------|
| CLR / SKC (0) | 0 | **Sunny** | **Clear** |
| FEW (1–2 oktas) | 1–2 | **Mostly Sunny** | **Mostly Clear** |
| FEW–SCT (2–4 oktas) | 2–4 | **Partly Sunny** | **Partly Cloudy** |
| SCT (3–4 oktas) | 3–4 | **Partly Cloudy** or **Partly Sunny** | **Partly Cloudy** |
| BKN (5–7 oktas) | 5–7 | **Mostly Cloudy** | **Mostly Cloudy** |
| OVC (8 oktas) | 8 | **Cloudy** (or **Overcast**) | **Cloudy** |
| VV (obscured) | — | **Foggy** / condition-specific | **Foggy** / condition-specific |

**Percentage equivalents** (NWS FFC Matrix; NWS bgm/forecast_terms use these ranges for forecast periods):

| Code | Percentage | Daytime | Nighttime |
|------|-----------|---------|-----------|
| CL | 0–5% | Sunny or Clear | Clear |
| FW | 6–25% | Mostly Sunny | Mostly Clear |
| SC | 26–50% | Mostly Sunny | Partly Cloudy |
| B1 | 50–69% | Partly Sunny | Mostly Cloudy |
| B2 | 70–87% | Mostly Cloudy | Mostly Cloudy |
| OV | 87–100% | Cloudy | Cloudy |

**Note on terminology precision:** "Partly Cloudy" and "Partly Sunny" are **identical cloud conditions**; the choice is time-of-day dependent. "Partly Sunny cannot be reported during nighttime observations." (Source: wxguys.ssec.wisc.edu) Similarly, "Mostly Sunny" ≡ "Mostly Clear" at night.

**NWS bgm/forecast_terms exact values:**

| Term | Coverage |
|------|---------|
| Clear / Sunny | ≤ 1/8 (≤ 12.5%) opaque cloud |
| Mostly Clear / Mostly Sunny | 1/8 – 3/8 (12.5–37.5%) |
| Partly Cloudy / Partly Sunny | 3/8 – 5/8 (37.5–62.5%) |
| Mostly Cloudy | 5/8 – 7/8 (62.5–87.5%) |
| Cloudy | 7/8 – 8/8 (87.5–100%) |

**Alternative NWS bgm definition** also states "Clear/Sunny" as ≤ 1/8 specifically.

**"Fair"** (mainly nighttime): less than 4/10 opaque clouds, no precipitation, no extremes of visibility/temperature/wind. Source: NWS Glossary — Sky Condition.

---

## 2. Present Weather → Text Description

### 2.1 Obstruction-to-Vision in Text

Source: NWS 10-503 rev c (PDF); NWS forecast examples (PRZ007; LAX; NYC)

NWS observation text and forecast text treat obstruction-to-vision phenomena as **separate elements**, not fused into the sky condition descriptor.

**Confirmed patterns from live NWS forecast pages:**

| METAR Present Weather | NWS Text Convention |
|-----------------------|---------------------|
| HZ (haze) | "Hazy." as a separate sentence/clause |
| FG (fog) | "Foggy." or "Fog." as a separate element; or combined as "Patchy Fog" |
| BR (mist) | "Mist." as separate element (less common in public text) |
| BCFG (patchy fog) | "Patchy Fog." as separate element |
| MIFG (shallow fog) | "Shallow Fog." or "Patches of Low Fog." |
| FU (smoke) | "Smoky." or "Smoke." |

**Key structural rule:** Sky condition text comes first; present weather modifiers follow as separate clauses.

Examples from fetched NWS forecast pages (forecast.weather.gov, PRZ007 and LAX):

```
"Sunny in the morning, then partly cloudy with isolated showers in the afternoon. Hazy."
                                                                                   ^^^^^^
                                                                  Haze as separate sentence

"Partly cloudy this evening, then becoming mostly clear. Isolated showers. Hazy."

"Mostly clear. Hazy. Isolated showers after midnight."

"Patchy fog before 11am. Otherwise, mostly sunny..."
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^
                        "Otherwise" separates fog period from main sky condition
```

**Pattern rule:** NWS uses "Hazy." as a standalone sentence or clause added after the sky condition description — NOT as a compound like "Hazy Sunshine" or "Sunny and Hazy." This is confirmed by three independent live NWS forecast pages.

### 2.2 Precipitation in Text

Source: NWS forecast examples (weather.gov NYC page); NWS bgm/forecast_terms

| Scenario | Text Convention | Example |
|---------|----------------|---------|
| Sky condition + precipitation probability | Sky condition first, then precipitation | "Mostly cloudy, with a high near 77. Chance of showers." |
| Low probability (20–50%) | "Chance of [precip]" or "Isolated [precip]" | "Chance of showers" |
| High probability (60–70%) | "[Precip] likely" | "Showers likely" |
| Certain precipitation (80–100%) | "[Precip]" with periods | "Showers and possibly a thunderstorm" |
| Precipitation with conditional sky | Sky noted conditionally | "Showers likely, mainly before 8am. Partly sunny." |
| Sequential conditions | "Then" conjunction | "Sunny in the morning, then partly cloudy" |

---

## 3. Composition Rules: Combining Sky Condition + Present Weather

### 3.1 Structural Order

Source: NWS 10-503 (PDF confirmed, text extracted via WebFetch tool of rev c): "sky condition information first, followed by relevant weather phenomena"

Standard order for composed text observation or forecast:

```
[Sky Condition Text] [, {temperature context}]. [Present Weather.] [Precipitation.]
```

Or in observation context (current conditions):

```
[Sky Condition Text] and [Temperature description]
```

### 3.2 Conjunction Rules: "With" vs "And" vs "."

From fetched NWS forecast text examples and NWS Instruction 10-503 rev c:

| Usage | Conjunction | Example |
|-------|------------|---------|
| Sky condition + precipitation that limits or modifies the sky condition | **"with"** | "partly cloudy with isolated showers" |
| Two sequential sky conditions | **"then"** | "sunny in the morning, then partly cloudy" |
| Haze as a separate ambient condition | **"."** (period, separate sentence) | "Partly Cloudy. Hazy." |
| Fog as a time-limited condition with "otherwise" sky | **"Otherwise,"** | "Patchy fog before 11am. Otherwise, mostly sunny." |
| Multiple distinct time periods | **"then"** or new sentence | "Mostly clear. Hazy. Isolated showers after midnight." |

**"With"** is used when the second element qualifies or limits the primary sky condition (precipitation mixed with clouds). **"Hazy"** stands alone as a period-terminated sentence — it does not combine with "with" in standard NWS public text for haze.

### 3.3 Confirmed Text Combinations from NWS Forecasts

These are verbatim patterns observed from NWS live forecast pages:

**Hazy conditions:**
- "Sunny in the morning, then partly cloudy with isolated showers in the afternoon. Hazy."
- "Mostly clear. Hazy. Isolated showers after midnight."
- "Partly cloudy this evening, then becoming mostly clear. Isolated showers. Hazy."

**Fog conditions:**
- "Patchy fog before 11am. Otherwise, mostly sunny."

**Precipitation + sky condition:**
- "Showers likely and possibly a thunderstorm" (sky condition omitted when precipitation ≥ 60% probability)
- "Mostly cloudy, with a high near 77" (sky condition + temperature qualifier)
- "partly cloudy with isolated showers" ("with" linking sky to precipitation)

**No observed instances of:**
- "Hazy Sunshine" — not an NWS convention
- "Sunny and Hazy" — not used; haze goes in separate sentence
- "Hazy and Sunny" — not used

---

## 4. Day vs. Night Terminology — Definitive Rules

Source: NWS bmx/nwsterms; NWS bgm/forecast_terms; NWS psr/didyouknow; wxguys.ssec.wisc.edu

| Condition | Daytime Term | Nighttime Term |
|-----------|-------------|----------------|
| 0% cloud cover | Sunny | Clear |
| 1–25% cloud cover | Mostly Sunny | Mostly Clear |
| 26–50% cloud cover | Mostly Sunny or Partly Cloudy | Partly Cloudy |
| 50–62.5% cloud cover | Partly Sunny | Mostly Cloudy |
| 62.5–87.5% cloud cover | Mostly Cloudy | Mostly Cloudy |
| 87.5–100% cloud cover | Cloudy | Cloudy |

**Rules:**
1. "Sunny" and "Partly Sunny" — **daytime only**. At night, "Clear" and "Partly Cloudy" are used instead.
2. "Mostly Cloudy" and "Cloudy" are the same day and night.
3. For nighttime: "for the nighttime forecast periods, a forecast of 'partly cloudy' would be the only appropriate term, as there is no sunshine at night." (NWS Phoenix)
4. "Fair" is a mainly-nighttime term for nearly clear, calm conditions.

---

## 5. NWS Observation Text Field Order (METAR Elements)

Source: NWS METAR training; meteocentre.com; Wikipedia METAR

A standard METAR report encodes observations in this order:

```
Type  Station  DateTime  Auto?  Wind  Visibility  RVR?  PresentWeather  SkyCondition  Temperature/Dewpoint  Altimeter  Remarks
```

When translated to plain-language text for public display, the order is typically:

1. **Sky condition** (primary descriptor)
2. **Present weather** (obstruction or precipitation, if any)
3. **Temperature** (and sometimes dewpoint)
4. **Wind**
5. **Visibility** (typically omitted unless notably reduced)
6. **Pressure / Altimeter** (typically omitted from public text)

Example plain-language translation of `METAR KXXX 211558Z 18010KT 7SM HZ FEW030 SCT050 28/18 A3002`:

```
METAR elements:
  Wind:           180° at 10 knots
  Visibility:     7 SM
  Present Wx:     HZ (haze)
  Sky:            FEW030, SCT050 → "Partly Sunny" (daytime)
  Temp/Dew:       28°C / 18°C → 82°F / 64°F
  Altimeter:      30.02"

Public text (daytime):
  "Partly Sunny. Hazy. Temperature 82°F. Wind S 12 mph."
```

---

## 6. Sky Condition + Present Weather Combination Decision Tree

```
INPUT: METAR Sky Condition codes + Present Weather codes + Time of Day

STEP 1 — Compute Sky Cover Fraction:
    Take the highest meaningful sky layer (BKN or OVC if present; else highest SCT)
    Convert oktas to fraction: FEW=1-2/8, SCT=3-4/8, BKN=5-7/8, OVC=8/8

STEP 2 — Select Sky Text:
    IF daytime:
        0–1/8     → "Sunny"
        1–3/8     → "Mostly Sunny"
        3–5/8     → "Partly Sunny" (or "Partly Cloudy")
        5–7/8     → "Mostly Cloudy"
        7/8–8/8   → "Cloudy"
        VV (obscured) → see STEP 4
    IF nighttime:
        0–1/8     → "Clear"
        1–3/8     → "Mostly Clear"
        3–5/8     → "Partly Cloudy"
        5–7/8     → "Mostly Cloudy"
        7/8–8/8   → "Cloudy"

STEP 3 — Add precipitation text (if any):
    IF precipitation present AND probability < 60%:
        append "Chance of [precip]."
    IF precipitation probability 60–70%:
        append "[precip] likely."
    IF precipitation near-certain (80%+):
        precip text may replace or lead sky condition text

STEP 4 — Add obstruction text (if any):
    HZ present: append "Hazy." as separate sentence
    FG present: append "Foggy." or "Fog." as separate sentence
    BCFG:       append "Patchy Fog." separately
    MIFG:       append "Areas of Fog." or "Shallow Fog." separately
    FU present: append "Smoke." separately
    NOTE: Never fuse obstruction into sky condition text (not "Hazy Sunshine")

STEP 5 — Final output:
    "{Sky Text}. {Present Weather text}. {Precipitation text}."
    OR in time-conditional context:
    "{Sky Text in morning, then sky text in afternoon}. {Present weather}."
```

---

## 7. Specific NWS Terminology Notes

### "Fair"

- Defined as: less than 4/10 opaque clouds, no precipitation, no extremes of visibility/temperature/wind.
- Used primarily for nighttime. Maps to CLR + FEW at low coverage.
- Source: NWS Glossary — Sky Condition

### "Hazy"

- NWS Glossary definition: "An aggregation in the atmosphere of very fine, widely dispersed, solid or liquid particles, or both, giving the air an opalescent appearance that subdues colors."
- In text: always a standalone descriptor ("Hazy."), never fused with sky condition.
- Source: NWS Glossary — Haze; NWS forecast text (PRZ007, LAX)

### "Foggy" vs "Patchy Fog" vs "Fog"

- Persistent/widespread fog → "Foggy." or "Fog."
- Temporally or spatially limited → "Patchy Fog before [time]."
- Often paired with "Otherwise [sky condition]" to indicate the main sky once fog clears.
- Source: NWS forecast text (LAX forecast page)

### WMO vs NWS terminology note

WMO SYNOP/METAR uses numeric codes (4677/4680) that the US NWS encodes into METAR alphanumeric codes. The NWS/FMH-1 system then provides plain-language equivalents through the forecast text generation process. The sky condition text terminology described here (Sunny/Mostly Sunny/etc.) is the **NWS public text** layer, which sits one abstraction level above the raw METAR codes.

---

## 8. What Is NOT Standardized in Public Documentation

The following are **not** formally specified in accessible NWS public documents and were not found in fetched material:

1. **Exact word choice for "Hazy Sunshine" vs "Sunny. Hazy." vs "Sunny with Haze"** — NWS live forecasts consistently use the separate-sentence form ("Hazy." after sky text). No explicit style rule was found in accessible NWS HTML documents, but the pattern is unambiguous across multiple real NWS forecast pages.

2. **"With" vs "And" as a formal rule** — NWS uses "with" when precipitation modifies a sky condition ("partly cloudy with isolated showers") but this is not documented as a named rule; it is inferred from forecast examples.

3. **Exact algorithm for METAR → public text sky condition** — The NWS forecaster tools (National Blend of Models, etc.) apply these rules internally. The FMH-1 (available as PDF at ofcm.gov/publications/fmh/FMH1/FMH1_2017.pdf) contains the authoritative encoding rules, but the PDF is binary-compressed and was not machine-readable by the fetch tool.

4. **Exact observation-to-text conversion for current conditions** — NWS ASOS/AWOS feeds raw METAR; the weather.gov "Current Conditions" widget appears to translate sky condition codes to text using the rules above, but the source code for that translation was not fetched.
