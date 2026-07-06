# GFE Text Formatter — Source Code Analysis

**Analyzed:** 2026-07-05  
**Source repository:** [Unidata/awips2](https://github.com/Unidata/awips2) (public domain)  
**Base path:** `cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/`  
**Total analyzed:** ~10,800 lines across 6 files + 3 formatter examples  
**Purpose:** Reference for building the Clear Skies forecast text generation engine. Provides the complete threshold tables, phrase construction routines, and sentence-combining algorithm used by the NWS to convert gridded forecast data into written text.

---

## Files Analyzed

| File | Lines | Source URL |
|---|---|---|
| ScalarPhrases.py | 2,747 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ScalarPhrases.py) |
| VectorRelatedPhrases.py | 1,564 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/VectorRelatedPhrases.py) |
| WxPhrases.py | 1,943 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/WxPhrases.py) |
| PhraseBuilder.py | 4,237 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/PhraseBuilder.py) |
| ConfigVariables.py | ~1,280 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ConfigVariables.py) |
| TimeDescriptor.py | 761 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/TimeDescriptor.py) |
| RecreationFcst.py | 567 | [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/python/testFormatters/RecreationFcst.py) |
| HSF.py | 2,789 | `textProducts/HSF.py` in same repo path |
| RDFcst.py | 205 | `python/testFormatters/RDFcst.py` |

**Not available publicly:** `ZoneFcst.py` (the operational Zone Forecast Product formatter) is distributed only through the NWS SCP (Standard Configuration Point) internal Subversion. A `gh search code "ZoneFcst"` against the Unidata repo returned zero results. The `RecreationFcst.py` narrative formatter uses the same `"type": "smart"` architecture and serves as the architectural reference.

---

## 1. Sky Coverage Thresholds

**Source:** `ScalarPhrases.py`, method `sky_valueList()` (line ~98)

```python
(5,   "sunny",        "clear")
(25,  "sunny",        "mostly clear")
(50,  "mostly sunny", "partly cloudy")
(69,  "partly sunny", "mostly cloudy")
(87,  "mostly cloudy","mostly cloudy")
(100, "cloudy",       "cloudy")
```

Format: `(upper_threshold_percent, daytime_phrase, nighttime_phrase)`.

**Adjacent-transition suppression** — `similarSkyWords_list()` (line ~105):

Daytime pairs (transitions between these are suppressed in trend wording):
```
("sunny", "mostly sunny")
("mostly sunny", "partly sunny")
("partly sunny", "mostly cloudy")
("mostly cloudy", "cloudy")
```

Nighttime pairs:
```
("clear", "mostly clear")
("mostly clear", "partly cloudy")
("mostly cloudy", "cloudy")
```

**Sky special cases** — `skySpecialCases()`:
- "Clearing" detected when sky value drops below `clearing_threshold` (default 31%)
- "Increasing clouds" / "decreasing clouds" when `reportIncreasingDecreasingSky_flag` is enabled
- Diurnal sky splits via `getSkyDiurnalWords()`: e.g., "mostly cloudy in the night and morning, otherwise mostly sunny" (for periods > 12 hours, splits into 6-hour chunks)

**Sky suppression by PoP** — `pop_sky_lower_threshold()`:
- When PoP ≥ 55% for > 50% of sub-periods, sky phrase is omitted entirely (precipitation dominates the sky condition)

---

## 2. Temperature Phrasing

**Source:** `ScalarPhrases.py`, methods `getTempPhrase()`, `getDecadeStr()`, `tempPhrase_exceptions()`, `tempPhrase_boundary_dict()` (lines ~340-450)

### 2.1 Core algorithm (`getTempPhrase`)

1. Check `tempPhrase_exceptions` table first (handles zero-crossing, above-100, exact-decade values)
2. If `abs(maxVal - minVal) > tempDiff_threshold` (default 4°F): report exact range "23 to 29"
3. Otherwise: map to decade + position

### 2.2 Decade naming (`getDecadeStr`)

```python
decade == 0    → "single digits"
decade == 10   → "teens"
decade == -10  → "teens below zero"
otherwise      → repr(decade) + "s"    # e.g. "80s"
```

### 2.3 Position within decade (`tempPhrase_boundary_dict`)

```python
ones digit 0-3  → "lower"
ones digit 4-6  → "mid"
ones digit 7-9  → "upper"
```

**Output examples:**
- 83°F → "lower 80s"
- 86°F → "mid 80s"  
- 89°F → "upper 80s"
- Min 83, Max 89 (same decade, span lower-to-upper) → "in the 80s"
- Min 78, Max 82 (cross-decade, both near boundary) → "near 80" or "upper 70s to lower 80s"
- Single value 87 → "near 87" (via exception table for exact-decade case)

### 2.4 Exception table (`tempPhrase_exceptions`)

```python
[(minBounds),    (maxBounds),    equalityPhrase,    rangePhrase]
[(100,200),      (100,200),      "around %min",     "%min to %max"]
[(90,99),        (100,200),      "",                 "%min to %max"]
[(1,19),         (1,29),         "around %min",     "%min to %max"]
[(0,0),          (0,29),         "near zero",       "zero to %zeroPhraseMax"]
[(-200,0),       (0,0),          "near zero",       "%zeroPhraseMin to zero"]
[(-200,-1),      (1,200),        "near zero",       "%zeroPhraseMin to %zeroPhraseMax zero"]
[(-200,-1),      (-200,-1),      "around %zeroPhraseMin", "%zeroPhraseMax to %zeroPhraseMin zero"]
[(20,20),        (20,20),        "around %min",     "%min to %max"]
# ... same pattern for 30, 40, 50, 60, 70, 80, 90
```

### 2.5 Extended forecast temperatures (`getExtendedTempPhrase`)

For `extended_temp_range = 10` (default):
```
digit 0-2  → "{decade-5} to {decade+5}"
digit 3-7  → "in the {decade}s"
digit 8-9  → "{decade+5} to {decade+15}"
```

Sub-zero hardcoded ranges:
```python
temp < -27  → "25 below to 35 below"
temp < -22  → "20 below to 30 below"
temp < -17  → "15 below to 25 below"
temp < -12  → "10 below to 20 below"
temp < -7   → "5 below to 15 below"
temp < -2   → "zero to 10 below"
temp < 3    → "5 below zero to 5 above"
temp < 8    → "zero to 10 above"
temp < 10   → "5 to 15"
```

### 2.6 Temperature trends (`temp_trends_words`)

Compares hourly T stats in the latter half of the period against MaxT/MinT. If difference exceeds `temp_trend_nlValue` (default 20°F):
- Daytime: "temperatures falling into the [lower] 50s in the afternoon"
- Nighttime: "temperatures rising into the [upper] 30s after midnight"

### 2.7 Comparative trends (`colder_warmer_dict`)

Temperature-range-dependent comparative language:

```python
"LowColder":     {(-80,45): "colder",     (45,70): "cooler",      (70,150): "not as warm"}
"LowMuchColder": {(-80,45): "much colder",(45,70): "much cooler", (70,150): "not as warm"}
"LowWarmer":     {(-80,35): "not as cold",(35,50): "not as cool", (50,150): "warmer"}
"HighColder":    {(-80,45): "colder",     (45,75): "cooler",      (75,90): "not as warm", (90,150): "not as hot"}
"HighWarmer":    {(-80,45): "not as cold",(45,65): "not as cool", (65,150): "warmer"}
```

### 2.8 Steady temperature (`steady_temp_trends_words`)

When diurnal range (max - min of hourly T) < `steady_temp_threshold` (default 4°F):
- Produces "near steady temperature in the mid 20s"
- Clears all other highs/lows phrases

### 2.9 Extreme temperature descriptors (`extremeTemps_words`)

Daytime:
- T > 99 AND (heatIndex - T) > 7 → "very hot and humid"
- T > 99 → "very hot"
- T > 95 AND (heatIndex - T) > 6 → "hot and humid"
- T > 95 → "hot"
- T < 20 AND windChill < -9 → "bitterly cold"
- T < 20 → "very cold"
- heatIndex ≥ 108 → "hot and humid"
- windChill ≤ 0 → "bitterly cold"

Nighttime:
- T < 5 AND windChill ≤ 0 → "bitterly cold"
- T < 5 → "very cold"
- windChill ≤ 0 → "bitterly cold"

---

## 3. Wind Phrasing

**Source:** `VectorRelatedPhrases.py` (1,564 lines)

### 3.1 Magnitude phrasing (`vector_mag`, line ~295)

- If maxMag < null threshold (default 5): "null" → uses `first_null_phrase` or `null_phrase`
- If maxMag == minMag: "around {maxMag} {units}"
- If minMag < null threshold: "up to {maxMag} {units}"
- Otherwise: "{minMag} to {maxMag} {units}"

### 3.2 Summary descriptors (`vector_summary_valueStr`, line ~451)

```python
value < 25   → ""              (no descriptor)
value < 30   → "breezy"
value < 40   → "windy"
value < 50   → "very windy"
value < 74   → "strong winds"
value >= 74  → "hurricane force winds"
```

### 3.3 Gust qualification (`embedded_gust_phrase`, line ~183)

- Report gusts only if `gusts - maxWind > gust_wind_difference_nlValue` (default 10 mph)
- Phrase: "with gusts to around {gusts} {units}"
- Tropical mode: round both gusts and maxWind to nearest 5 kt

### 3.4 Marine wind descriptors (`marine_wind_mag`, line ~342)

```python
maxMag >= 64 kt  → "hurricane force winds to"
maxMag >= 45 kt  → "storm force winds to"
maxMag >= 34 kt  → "gales to"
maxMag > 25 kt   → "up to" (no special descriptor)
```

### 3.5 Null wind phrases

**Source:** `ConfigVariables.py`, `first_null_phrase_dict` and `null_phrase_dict`

- First period with null winds: "light winds"
- Subsequent null periods: "light"
- Marine: "waves 2 feet or less" / "2 feet or less"

### 3.6 Tropical cyclone probabilistic wind speed (PWS)

**Source:** `VectorRelatedPhrases.py`, `pws_phrase` through `getPeriod_10_14_Desc` (lines ~690-1560)

14 forecast periods with per-period probability thresholds for 34-kt and 64-kt winds. 9 description codes:

| Code | Meaning |
|---|---|
| `iminHR` | Hurricane conditions (imminent) |
| `expHR` | Hurricane conditions expected |
| `posHR` | Hurricane conditions possible |
| `iminTS` | Tropical storm conditions (imminent) |
| `expTS` | Tropical storm conditions expected |
| `posTS` | Tropical storm conditions possible |
| `iminTSposHR` | Tropical storm conditions with hurricane conditions possible |
| `expTSposHR` | Tropical storm conditions expected with hurricane conditions possible |
| `posTSbcmgposHR` | Tropical storm conditions possible with hurricane conditions also possible |

Threshold pairs per period (34-kt threshold, 64-kt threshold):
```
Period 1:  (45.0/80.0, 25.0/60.0)  — two sub-thresholds
Period 2:  (35.0, 20.0)
Period 3:  (30.0, 15.0)
Period 4:  (25.0, 12.5)
Period 5:  (22.5, 10.0)
...through Period 10: (10.0, 4.0)
```

---

## 4. Weather Type System

**Source:** `WxPhrases.py` (1,943 lines)

### 4.1 Weather type hierarchy (`wxHierarchies`, line ~103)

24 types in priority order (highest priority first):

```
WP  = waterspouts       R   = rain              RW = rain showers
T   = thunderstorms     L   = drizzle           ZR = freezing rain
ZL  = freezing drizzle  S   = snow              SW = snow showers
IP  = ice pellets       F   = fog               ZF = freezing fog
IF  = ice fog           IC  = ice crystals       H  = haze
BS  = blowing snow      BN  = blowing sand       K  = smoke
BD  = blowing dust      FR  = frost             ZY = freezing spray
BA  = unknown/misc
```

### 4.2 Coverage levels (`wxHierarchies["coverage"]`)

16 levels, strongest to weakest:

```
Def     = definite         Wide  = widespread
Brf     = brief            Frq   = frequent
Ocnl    = occasional       Pds   = periods of
Inter   = intermittent     Lkly  = likely
Num     = numerous         Sct   = scattered
Chc     = chance           Areas = areas of
SChc    = slight chance    WSct  = widely scattered
Iso     = isolated         Patchy = patchy
```

**Coverage similarity lists** (`similarCoverageLists`, line ~118):
```python
['SChc', 'Iso']                                           # slight chance ≈ isolated
['Chc', 'Sct']                                            # chance ≈ scattered
['Lkly', 'Num']                                           # likely ≈ numerous
['Brf', 'Frq', 'Ocnl', 'Pds', 'Inter', 'Def', 'Wide']  # all "definite" variants
```

### 4.3 Intensity codes (`wxHierarchies["intensity"]`)

```
+    = heavy
m    = moderate
-    = light
--   = very light / trace
```

### 4.4 Weather type descriptors (`wxTypeDescriptors`, line ~184)

Special type wording overrides:

| Pattern | Output |
|---|---|
| very light snow showers (`SW`, `--`) | "flurries" |
| rain showers, temp < 60°F | "rain showers" |
| rain showers, temp ≥ 60°F | "showers" |
| very light rain showers (`RW`, `--`) | "sprinkles" |
| thunderstorms with Dry attribute | "dry thunderstorms" |

### 4.5 Intensity descriptors (`wxIntensityDescriptors`, line ~214)

Selected mappings (many suppress intensity words for brevity):

| Type | Intensity | Output word |
|---|---|---|
| Rain (`R`), very light (`--`) | "light" |
| Snow (`S`), very light (`--`) | "very light" |
| Freezing rain (`ZR`), very light (`--`) | "light" |
| Fog (`F`), heavy (`+`) | "dense" |
| All shower types (`RW`, `SW`) | (no intensity word — covered by coverage) |
| Heavy rain/snow (`R+`, `S+`) | (no intensity word — covered by `heavyPrecip_phrase`) |

### 4.6 Thunderstorm attributes (`wxAttributeDescriptors`, line ~243)

All thunderstorm attributes are suppressed from inline wording — they're handled by `severeWeather_phrase` instead:

```
DmgW = damaging winds      GW   = gusty winds
FL   = frequent lightning   LgA  = large hail
SmA  = small hail           TOR  = tornadoes
HvyRn = heavy rain          Dry  = dry thunderstorms
```

**Similar attributes** (for combining adjacent sub-phrases) — from `PhraseBuilder.similarAttributeLists()`:
```python
[["DmgW", "GW"], ["LgA", "SmA"]]
```
"Damaging winds" and "gusty winds" are considered similar; "large hail" and "small hail" are considered similar.

### 4.7 PoP-related types (`pop_related_flag`, line ~74)

Types that correlate with PoP (probability of precipitation):
```python
["ZR", "R", "RW", "S", "SW", "T", "IP"]
```
Exceptions: very light (`--`) showers (RW, SW) return 0. Dry thunderstorms return 0.

### 4.8 Weather conjunction rules

**Source:** `WxPhrases.py`, methods `wxConjunction`, `withPossible`, `withPhrase`, `withPocketsOf`, `possiblyMixedWith`, `mixedWith` (lines ~511-576)

| Situation | Conjunction | Example |
|---|---|---|
| Default between types | " and " | "rain and snow" |
| Definite + Likely coverage | " with " | "rain with possible thunderstorms" |
| "OR" attribute present | " or " | "rain or snow" |
| T followed by RW/R | " with little or no rain" | (suppresses the rain) |
| Mixed precipitation | " mixed with " | "snow mixed with sleet" |
| Uncertain secondary | " with possible " | "snow with possible freezing rain" |
| Pockets | " with pockets of " | "fog with pockets of freezing fog" |

**Serial comma rule** — `PhraseBuilder.useCommas()`:
- "rain and snow and freezing rain" → "rain, snow and freezing rain"
- Applied when 3+ items are joined with " and "

### 4.9 Heavy precipitation system

**Source:** `WxPhrases.py`, `heavyPrecip_phrase` through `heavyPrecip_words` (lines ~1247-1365)

Heavy precip types:
```python
heavyRainTypes:  ["R", "RW"]
heavySnowTypes:  ["S", "SW"]
heavyOtherTypes: ["IP", "ZR", "L", "ZL"]
```

Descriptor phrases (from `ConfigVariables.phrase_descriptor_dict`):
```
"heavyRainfall": "locally heavy rainfall possible"
"heavyRain":     "rain may be heavy at times"
"heavySnow":     "snow may be heavy at times"
"heavyPrecip":   "precipitation may be heavy at times"
```

### 4.10 Severe weather phrases

**Source:** `WxPhrases.py`, `severeWeather_phrase` through `severeWeather_words` (lines ~1130-1233)

- If thunderstorms are severe (intensity `+`): descriptor "some thunderstorms may be severe" + attributes
- If not severe but has attributes: descriptor "some thunderstorms may produce" + attributes
- Attributes rendered from `DmgW`, `GW`, `FL`, `LgA`, `SmA`, `TOR`, `HvyRn`

### 4.11 Visibility phrases

**Source:** `WxPhrases.py`, `visibility_phrase` through `visibility_weather_phrase_nlValue` (lines ~1597-1716)

Statute miles:
```python
(0, .3): "one quarter mile or less at times"
```

Nautical miles:
```python
(0, 1):    "1 NM or less"
(1.1, 2):  "2 NM"
(2.1, 3):  "3 NM"
(3.1, 4):  "4 NM"
(4.1, 5):  "5 NM"
(5.1, 6):  "6 NM"
```

Significant weather visibility subkeys: Fog, Freezing Fog, Ice Fog, Haze, Smoke, Blowing Snow, Blowing Dust, Volcanic Ash.

---

## 5. Sentence Assembly Pipeline

**Source:** `PhraseBuilder.py` (4,237 lines)

### 5.1 Standard phrase methods pipeline

Every phrase node runs these 10 methods in order:

```python
standard_phraseMethods = [
    consolidatePhrase,        # separate constant vs varying elements
    checkLocalEffects,        # geographic variation ("windward"/"leeward")
    combinePhraseStats,       # merge similar adjacent sub-phrases
    consolidateTrends,        # monotonic progressions → first+last only
    chooseMostImportant,      # report only min or max sub-phrase
    combineWords,             # merge identical-text sub-phrases
    fillNulls,                # insert "light winds" etc. for null values
    timeDescriptorModeration, # alternate time descriptors on sub-phrases
    assembleSubPhrases,       # join sub-phrases with connectors
    postProcessPhrase,        # string cleanup + translateForecast(language)
]
```

### 5.2 Connector strategies

**Source:** `PhraseBuilder.py`, `scalarConnector`, `vectorConnector`, `wxConnector`, `marine_vectorConnector` (lines ~3510-3780) + `ConfigVariables.py`, `phrase_connector_dict`

#### Scalar connector

Returns "then", "increasing to", or "decreasing to" based on comparison of scalar values between sub-phrases.

From `ConfigVariables.phrase_connector_dict`:
```python
"then":           {"Sky": " then becoming ",  "otherwise": " then "}
"increasing to":  {"Sky": " then becoming ",  "WaveHeight": " building to ",  "otherwise": " increasing to "}
"decreasing to":  {"Sky": " then becoming ",  "WaveHeight": " subsiding to ",  "otherwise": " decreasing to "}
```

#### Vector connector

Direction+magnitude aware logic:
- Same direction, different magnitude: "increasing to" or "decreasing to"
- Same magnitude, different direction: "shifting to the"
- Different both, high wind (≥ 45): "becoming {dir} and increasing/decreasing to"
- Different both, normal wind: "increasing to" or "becoming"

Additional connectors:
```python
"becoming":          " becoming "
"shifting to the":   " shifting to the "
```

#### Weather connector

Returns ". " (period-separated, capitalize next) or ", then " for weather sub-phrases. Manages `useThenConnector` flag to avoid long chains of ", then...then...then".

#### Marine vector connector

```python
"rising to":         " rising to "
"easing to":         " easing to "
"backing":           " backing "
"veering":           " veering "
"becoming onshore":  " becoming onshore"
```

### 5.3 Sub-phrase assembly (`assembleSubPhrases`, lines ~3255-3340)

Algorithm:
1. First non-null sub-phrase: prepend descriptor prefix (e.g., "winds")
2. Subsequent sub-phrases: insert connector from connectorMethod
3. At index 2 (third sub-phrase): optionally insert ", then" conjunctive for flow
4. Each sub-phrase: append time descriptor (e.g., "in the afternoon")

```python
for subPhrase in phrase.childList:
    if index == 0:
        fcst += descriptor + " "          # "winds "
    else:
        connector = connectorMethod(tree, subPhrase)
        if index == 2 and useThenConnector:
            connector = thenConnector + connector   # ", then"
        fcst += connector
    fcst += subPhrase.words + timeDescriptor
```

### 5.4 Trend consolidation (`consolidateTrends`)

If magnitudes form a monotonic progression (steadily increasing or decreasing), only the first and last sub-phrases are kept. The trend connector provides the bridge ("increasing to" / "decreasing to").

### 5.5 Post-processing (`postProcessPhrase`)

```python
words = words.replace("rain showers and thunderstorms", "showers and thunderstorms")
words = words.replace("except of", "except")
words = self.translateForecast(words, self._language)
```

Note: `translateForecast(words, language)` confirms GFE has built-in multi-language support. The method lives in `TextRules.py` (not yet fetched).

### 5.6 Combining system

Pairwise comparison of adjacent sub-phrases:

| Data type | Method | Similarity criteria |
|---|---|---|
| Scalar | `combineScalars` | Difference within `scalar_difference_nlValue` |
| Vector | `combineVectors` | Magnitude within `vector_mag_difference_nlValue`, direction within `vector_dir_difference` |
| Weather | `combineWeather` | Weather subkey similarity (type, coverage, intensity, attributes) |
| Discrete | `combineDiscrete` | Values are equal |

---

## 6. Time Descriptors

**Source:** `TimeDescriptor.py` (761 lines)

### 6.1 Period labels (`getWeekday_descriptor`)

| Situation | Label |
|---|---|
| Current day, daytime | "Today" |
| Current day, nighttime | "Tonight" |
| Current day, < 12h remaining, day | "Rest of Today" |
| Current day, < 12h remaining, night | "Rest of Tonight" |
| Next day, daytime | "Tomorrow" |
| Next day, nighttime | "Tomorrow Night" |
| Future weekday, daytime | "Saturday" |
| Future weekday, nighttime (> 6h) | "Saturday Night" |
| Future weekday, nighttime (≤ 6h) | "Saturday Evening" |
| Duration > 24 hours | "Sunday through Monday Night" |
| 24-hour split | "Saturday and Saturday Night" |

Holiday support: Holidays module can replace weekday names with holiday names.

7 label formatting types: SimpleWorded, Worded (with ": " suffix), Capital (with "..." suffix), CapitalWithPeriod (uppercase, "." prefix, "..." suffix), Abbreviated, CapsAbbreviated, Combo.

### 6.2 Sub-period time descriptors (`timePeriod_descriptor_list`)

42-entry table mapping 3-hour block combinations to phrases. All times relative to `self.DAY()` (default 6 = 6 AM local):

| Start → End (relative to DAY) | Phrase |
|---|---|
| +0 → +3 (6a–9a) | "early in the morning" |
| +0 → +6 (6a–noon) | "in the morning" |
| +0 → +9 (6a–3p) | "until late afternoon" |
| +0 → +12 (6a–6p) | "" (full day — no descriptor) |
| +0 → +15 (6a–9p) | "until early evening" |
| +0 → +18 (6a–midnight) | "through the evening" |
| +3 → +6 (9a–noon) | "late in the morning" |
| +3 → +9 (9a–3p) | "in the late morning and early afternoon" |
| +3 → +12 (9a–6p) | "in the late morning and afternoon" |
| +6 → +9 (noon–3p) | "early in the afternoon" |
| +6 → +12 (noon–6p) | "in the afternoon" |
| +6 → +15 (noon–9p) | "in the afternoon and evening" |
| +9 → +12 (3p–6p) | "late in the afternoon" |
| +9 → +15 (3p–9p) | "early in the evening" |
| +9 → +18 (3p–midnight) | "in the evening" |
| +9 → +21 (3p–3a) | "until early morning" |
| +12 → +15 (6p–9p) | "early in the evening" |
| +12 → +18 (6p–midnight) | "in the evening" |
| +12 → +21 (6p–3a) | "until early morning" |
| +12 → +0 (6p–6a) | "" (full night — no descriptor) |
| +15 → +18 (9p–midnight) | "late in the evening" |
| +15 → +21 (9p–3a) | "in the late evening and early morning" |
| +15 → +0 (9p–6a) | "in the late evening and overnight" |
| +18 → +21 (midnight–3a) | "after midnight" |
| +18 → +0 (midnight–6a) | "after midnight" |
| +21 → +0 (3a–6a) | "early in the morning" |
| +21 → +3 (3a–9a) | "early in the morning" |
| +21 → +6 (3a–noon) | "early in the morning" |
| +21 → +9 (3a–3p) | "until afternoon" |

(Plus additional intermediate entries for 2-hour and 1-hour blocks at 8a–9a, 11a–noon, 2p–3p, 5p–6p, 8p–9p, 11p–midnight, 2a–3a, 5a–6a)

---

## 7. Configuration System

**Source:** `ConfigVariables.py` (~1,280 lines)

### 7.1 Key threshold dictionaries

| Dictionary | Purpose | Key values |
|---|---|---|
| `null_nlValue_dict` | Below this = null | Wind=5, WindGust=20, WaveHeight=3, HeatIndex=108, WindChill=-100 |
| `scalar_difference_nlValue_dict` | Report changes above this | WindGust=10, PoP=200 (never sub-phrase), WaveHeight=5, MaxT=10 |
| `vector_mag_difference_nlValue_dict` | Wind magnitude change threshold | Wind=10, Swell=5, otherwise=5 |
| `vector_dir_difference_dict` | Direction change threshold | Wind=60°, Swell=60°, otherwise=60° |
| `increment_nlValue_dict` | Rounding increments | Wind=5, PoP=10, SnowAmt=0.1, QPF=0.01, MixHgt=100 |
| `range_nlValue_dict` | Narrow-range → single value | MaxT=5, MinT=5, MinRH=5 |
| `highValue_threshold_dict` | Compound direction+magnitude | Wind=45, Swell=20 |

### 7.2 Phrase descriptors (`phrase_descriptor_dict`)

Element-to-descriptor mapping:

| Element | Descriptor |
|---|---|
| Wind | "winds" |
| WindGust | "gusts up to" |
| HeatIndex | "heat index readings" |
| WindChill | "wind chill readings" |
| PoP | "chance of" |
| Visibility | "visibility" |
| Snow | "snow accumulation" |
| SnowSleet | "snow and sleet accumulation" |
| IceAccum | "ice accumulation" |
| TotalSnow | "total snow accumulation" |
| StormTotalSnow | "storm total snow accumulation" |
| highs | "highs" |
| lows | "lows" |
| severeWeather | "some thunderstorms may be severe" |
| thunderstorms | "some thunderstorms may produce" |
| heavyRainfall | "locally heavy rainfall possible" |
| heavyRain | "rain may be heavy at times" |
| heavySnow | "snow may be heavy at times" |
| heavyPrecip | "precipitation may be heavy at times" |

Tropical descriptors:
```python
"iminHR":  "Hurricane conditions"
"expHR":   "Hurricane conditions expected"
"posHR":   "Hurricane conditions possible"
"iminTS":  "Tropical storm conditions"
"expTS":   "Tropical storm conditions expected"
"posTS":   "Tropical storm conditions possible"
```

### 7.3 Units descriptors (`units_descriptor_dict`)

Plural and singular forms:

| Unit code | Plural | Singular |
|---|---|---|
| ft | feet | foot |
| F | "" (suppressed) | "" |
| C | degrees | degree |
| % | percent | percent |
| in | inches | inch |
| kts | knots | knot |
| mph | mph | mph |
| s | seconds | second |

### 7.4 "Most important" sub-phrase (`mostImportant_dict`)

For elements where only the extreme value matters:
```python
"WindChill": "Min"  → reports only the lowest wind chill sub-phrase
```
Descriptor: "lowest wind chill readings"

---

## 8. Narrative Formatter Pattern

**Source:** `RecreationFcst.py` (567 lines), `HSF.py` (2,789 lines)

### 8.1 Architecture

All narrative ("smart") formatters follow this pattern:

```python
class TextProduct(TextRules.TextRules, SampleAnalysis.SampleAnalysis):
    Definition = {"type": "smart", ...}
    
    def generateForecast(self, argDict):
        # 1. Get variables
        # 2. Determine time ranges → _createNarrativeDef()
        # 3. Sample data → ForecastNarrative
        # 4. Loop edit areas → _makeProduct()
    
    def _createNarrativeDef(self, argDict):
        # Returns (timeRange, narrativeDef)
        # narrativeDef = [(componentName, hours), ...]
        return (timeRange, [
            ("RecreationPhrases", 24),  # 24-hour period
            ("Extended", 24),           # extended period
        ])
```

### 8.2 Component definition structure

Each component method returns a dict:

```python
def RecreationPhrases(self):
    return {
        "type": "component",
        "methodList": [self.assembleIndentedPhrases],
        "analysisList": [
            ("T", self.minMax),
            ("Wind", self.vectorMinMax),
            ("Wx", self.rankedWx),
            ("PoP", self.binnedPercent),
            ("Sky", self.minMax),
        ],
        "phraseList": [
            self.sky_phrase,
            self.weather_phrase,
            self.highs_phrase,    # or self.lows_phrase
            self.wind_phrase,
            self.temp_trends,
        ],
    }
```

### 8.3 Local override pattern

```python
import RecreationFcst
import copy

class TextProduct(RecreationFcst.TextProduct):
    Definition = copy.deepcopy(RecreationFcst.TextProduct.Definition)
    Definition['displayName'] = "TEST_RecreationFcst"
```

---

## 9. Snow and Ice Accumulation

**Source:** `ScalarPhrases.py`, `snow_phrase` through `iceAccumulation_words` (lines ~600-850)

### 9.1 Snow accumulation phrases (`snow_words`)

Requires PoP ≥ `pop_snow_lower_threshold` (default 60%) AND accumulating weather types (S, SW, IP, IC).

| Condition | Phrase |
|---|---|
| max < 0.5 | "no snow accumulation" |
| max < 1 | "little or no snow accumulation" |
| min < 1, max < 3 | "up to {max} inches" |
| max - min < 2 | "around {max} inches" |
| otherwise | "of {min} to {max} inches" |

### 9.2 Descriptive snow (`descriptive_snow_words`)

| Max accumulation | Phrase |
|---|---|
| < 1 inch | (none) |
| 1–2 inches | "light snow accumulations" |
| 2–5 inches | "moderate snow accumulations" |
| > 5 inches | "heavy snow accumulations" |

### 9.3 Ice accumulation (`iceAccumulation_words`)

Fractional-inch phrasing:

| Value | Phrase |
|---|---|
| < 0.2 | "less than one quarter" |
| 0.2–0.4 | "one quarter" |
| 0.4–0.7 | "one half" |
| 0.7–0.9 | "three quarters" |
| 0.9–1.3 | "one" |
| 1.3–1.8 | "one and a half" |
| ≥ 1.8 | integer rounded |

---

## 10. PoP Phrasing

**Source:** `ScalarPhrases.py`, `popMax_phrase` through `getPopType` (lines ~280-340)

### 10.1 PoP threshold gating

- `pop_lower_threshold`: default 15% (first 24h) or 25% (thereafter) — below this, weather is not mentioned
- `pop_upper_threshold`: default 100%
- `pop_wx_lower_threshold`: default 20% (used by WxPhrases — suppress weather mention below this)

### 10.2 PoP type qualification (`getPopType`)

```python
"R"  → "rain"
"RW" → "showers"
"S"  → "snow"
"SW" → "snow"
"T"  → "thunderstorms"
["IP", "ZL", "ZR", "ZF", "ZY"] → "precipitation"  (always generic for these)
```

When `wxQualifiedPoP_flag` is 1 (default): "chance of rain 20 percent" instead of "chance of precipitation 20 percent".

---

## 11. Combined Sky+PoP+Weather Phrase

**Source:** `CombinedPhrases.py` ([raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/CombinedPhrases.py))

`CombinedPhrases` inherits from `ScalarPhrases`, `VectorRelatedPhrases`, `WxPhrases`, and `DiscretePhrases` — it is the aggregation point for all phrase types.

### 11.1 `skyPopWx_phrase` — the major compound phrase

This is the phrase that produces NWS-style combined sentences like:
- "Partly cloudy with a 20 percent chance of showers and thunderstorms."
- "Mostly cloudy. Chance of rain 40 percent."

Pipeline (custom, not `standard_phraseMethods`):
```
skyPopWx_separateNonPrecip  — split non-precip weather (fog, haze) into separate phrase
skyPopWx_consolidateWx      — consolidate weather keys spanning all sub-phrases
checkLocalEffects            — geographic variation
combinePhraseStats           — merge similar adjacent sub-phrases
checkSkyPopWx                — decide whether to include sky, PoP, or abort
combineWords                 — merge identical-text sub-phrases
fillNulls                    — insert null phrases
timeDescriptorModeration     — alternate time descriptors
assembleSubPhrases           — join with connectors
postProcessPhrase            — cleanup + translateForecast
```

Key decision methods:
- `checkIncludePoP()`: When PoP ≥ 60%, PoP is reported in a separate `popMax_phrase` (not combined). When areal coverage terms exist, PoP is also separated.
- `checkIncludeSky()`: Sky is included in the combined phrase when weather sub-phrases have non-null weather. If no weather, sky is excluded and the standalone `sky_phrase` handles it.
- `skyPopWx_separateNonPrecip()`: Non-precipitation weather types (fog, haze, smoke) are pulled out into a separate `weather_phrase` so they don't combine with precipitation phrasing.

### 11.2 `weather_orSky_phrase` — mutually exclusive phrase

If weather exists, report weather. Otherwise report sky conditions. Logic:
1. Gather words from both `weather_phrase` and `sky_phrase` children
2. If weather words are non-empty, use weather
3. Otherwise, use sky

---

## 12. Text Utilities

**Source:** `StringUtils.py` ([raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/StringUtils.py))

### 12.1 Sentence construction (`sentence`)

```python
def sentence(self, s, addPeriod=1):
    return s[0].upper() + s[1:] + ". "   # capitalize first letter, add period
```

### 12.2 Word wrapping (`endline`, `linebreak`)

Default line length: 66 characters. Breaks at spaces and "..." sequences, avoids breaking after digits (keeps numbers with units). Force-breaks at spaces and "/" when no preferred break point exists.

### 12.3 Sentence combining (`combineSentences`)

Merges consecutive single-word sentences: "Warm. Dry." → "Warm, dry."

### 12.4 List formatting (`addTextList`, `punctuateList`)

Oxford comma support:
- 2 items: "rain and snow"
- 3+ items: "rain, snow, and freezing rain"

`addTextList` adds a preposition: "with rain, snow, and freezing rain"

### 12.5 Case conversion

`_lowerCase` flag (default True since 2015) controls mixed-case vs ALL-CAPS output. When True: each word capitalized ("Partly Cloudy With A Chance Of Rain"). When False: all uppercase ("PARTLY CLOUDY WITH A CHANCE OF RAIN"). Older NWS products used ALL-CAPS; modern products use mixed case.

---

## 13. TextRules.py — Aggregator Class

**Source:** `TextRules.py` ([raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/TextRules.py))

Only 107 lines. A thin multiple-inheritance aggregator:

```python
class TextRules(ConfigurableIssuance, Header, TableBuilder,
                SimpleTableUtils, CombinedPhrases, MarinePhrases,
                FirePhrases, CommonUtils):
```

Contains only 4 methods: `IFP()`, `getSiteID()`, `getGFESuiteVersion()`, `fillSpecial()`.

**`translateForecast()` is NOT in this file.** The `PhraseBuilder.postProcessPhrase` call `self.translateForecast(words, self._language)` inherits from one of the unfetched parent classes — likely `CommonUtils.py` or `ConfigurableIssuance.py`. These are not in the `textUtilities/` directory; they may be in a different path within the awips2 repo.

---

## 14. Translation System (`translateForecast`)

**Source:** `Interfaces.py` (definition), `Translator.py` (~460 lines, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/Translator.py))  
**Author:** mathwig

### 14.1 Architecture — "Generate English, then replace"

`translateForecast()` is a thin wrapper in `Interfaces.py`:

```python
def translateForecast(self, forecast, language):
    if language == "english":
        return forecast
    trans = Translator.Translator(language)
    return trans.getForecast(forecast)
```

`Translator.getForecast()` is a **multi-pass, ordered string-replacement engine** with grammatical gender/number agreement. NOT a template system, NOT machine translation.

### 14.2 Pipeline stages

```python
def getForecast(self, forecast):
    lwForecast = forecast.lower()                          # 1. lowercase
    transForecast = self._translateExpForecast(lwForecast)  # 2. expression substitution
    exceptForecast = self._translateExceptions(transForecast) # 3. exception inflection
    transForecast = self._translateTypeForecast(exceptForecast) # 4. type/intensity/coverage
    cleanTransForecast = self._cleanUp(transForecast)      # 5. cleanup fixups
    self.capTransForecast = self._capital(cleanTransForecast) # 6. re-capitalize
    return self.capTransForecast
```

#### Stage 2: Expression substitution (`_translateExpForecast`)

Iterates through ordered `(english_phrase, translated_phrase)` tuples, calling `str.replace()` for each. Ordering matters — longer phrases must match before shorter ones (e.g., `'northeast'` before `'north'` and `'east'`).

Examples (French): `'mostly sunny'` → `'généralement ensoleillé'`, `'northeast winds at'` → `'vents du nord-est de'`

~90 pairs for French, ~120+ for Spanish.

#### Stage 3: Exception inflection (`_translateExceptions`)

Handles words like `'likely'` that need gender/number agreement with the preceding weather type. For each (weather_type, exception) pair, builds the English string and replaces with the correctly inflected form based on the type's gender code.

#### Stage 4: Type/Intensity/Coverage inflection (`_translateTypeForecast`)

The most sophisticated pass. Triple-nested loop through Types × Intensities × Coverages. Each weather type has a gender code:

| Code | Meaning | Example (French) |
|---|---|---|
| MS | masculine singular | brouillard (fog) |
| MP | masculine plural | orages (thunderstorms) |
| FS | feminine singular | pluie (rain) |
| FP | feminine plural | averses (showers) |

The gender code selects which inflected form of intensity/coverage adjectives to use:

```python
# For type with gender code FS (feminine singular):
#   "heavy" → index [3] = "abondante" (not "abondant" which is MS)
#   "scattered" → index [3] = "dispersée" (not "dispersé" which is MS)
```

4 sub-passes in order:
1. Coverage + Intensity + Type: `"scattered heavy rain"` → `"pluie abondante dispersée"`
2. Intensity + Type: `"heavy rain"` → `"pluie abondante"`
3. Coverage + Type: `"scattered rain"` → `"pluie dispersée"`
4. Type alone: `"rain"` → `"pluie"`

#### Stage 5: Cleanup (`_cleanUp`)

Post-translation fixups for contractions and spacing artifacts:

French: `('de a', "d'a")`, `('mi- ', 'mi-')`, `("jusqu' a", "jusqu'a")`

#### Stage 6: Re-capitalize (`_capital`)

Scans for `. ` and capitalizes the next letter. Always capitalizes the first character.

### 14.3 Supported languages

Only **French** and **Spanish**. No other languages in the `LanguageTables` dictionary.

| Language | Expressions | Types | Intensities | Coverages | Exceptions |
|---|---|---|---|---|---|
| French | ~90 pairs | 15 types with gender codes | 5 levels × 4 inflected forms | 6 terms × 4 forms | 1 (likely) |
| Spanish | ~120+ pairs | 16 types with gender codes | 6 levels × 4 forms | 5 terms × 4 forms | 1 (likely) |

### 14.4 Limitations of this approach

- **Word-order dependent** — assumes target language has the same word order as English. Works for French/Spanish (SVO, adjective placement similar enough). Cannot handle Japanese (SOV, operator-based composition), Chinese (structured fields), or languages with radically different syntax.
- **Only 2 languages** — French and Spanish. No German, no Italian, no Portuguese, no CJK.
- **Fragile to source text changes** — any change to the English phrase construction can break replacement matches silently.
- **No compositional i18n** — does not compose locale-native phrases from components; instead generates English and post-hoc replaces substrings.

### 14.5 Relevance to our engine

Our i18n architecture (per-locale JSON files with composition templates + custom composers for JA/ZH) is fundamentally different and more extensible. However, GFE's gender/number agreement mechanism is worth studying:

- **Our Russian locale** already handles grammatical case inflection (nominative/instrumental/genitive) for the "with" construction
- **Romance languages** (French, Spanish, Italian, Portuguese) will need adjective agreement for forecast coverage and intensity modifiers — the same MS/MP/FS/FP pattern GFE uses
- The solution: our locale JSON files should carry gender-coded modifier forms, similar to how Russian carries case-inflected forms. The template engine resolves the correct form based on the weather type's grammatical properties.

### 14.6 Callers

`translateForecast` is called from:
- `PhraseBuilder.postProcessPhrase()` — final step of every phrase assembly
- `ForecastTable.py` — table product formatting
- `TextFormatter.py` — product-level text formatting

---

## 15. Data Sampling and Period Segmentation

**Source:** `SampleAnalysis.py` (2,970 lines, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/SampleAnalysis.py))

We replace GFE's gridded data sampling entirely with our provider forecast data (`HourlyForecastPoint` / `DailyForecastPoint`). However, the period segmentation logic and statistical summary methods inform how we should aggregate hourly data into period summaries.

### 15.1 Time range segmentation — three mechanisms

**Fixed hour intervals** (`createStats` with `args[0] > 0`):
```python
subRanges = self.divideRange(timeRange, period)  # period = hours per sub-range
```
Splits a forecast period into sub-ranges of `period` hours each. Used when analysis list specifies e.g., `("Wind", self.vectorMinMax, [6])` — sample wind in 6-hour blocks.

**Grid-aligned sub-ranges** (`createStats` with `args[0] == 0`):
```python
subRanges = self.getGridTimeRanges(parmHisto, timeRange)
```
Produces sub-ranges matching actual data grid boundaries. Trims partial overlaps to the requested time range.

**Equal-part splitting** (`splitRange`):
```python
def splitRange(self, timeRange, numPeriods=2):
    duration = (timeRange.endTime() - timeRange.startTime()) // numPeriods
    # produces numPeriods equal-length sub-ranges
```
Default splits in half. Used by `vectorRange` to compute independent wind averages per half-period.

**Hourly iteration** (`hourlyTemp`):
Creates 1-hour windows from period start to end, queries average temperature per hour. Used for temperature trend detection.

### 15.2 Temporal coverage — grid inclusion gatekeeper

`temporalCoverage_flag` decides whether a data grid should be included in analysis for a time range. Two thresholds must BOTH be satisfied:

1. **Percentage**: grid-time-range intersection must be ≥ `temporalCoverage_percentage` of the period (element-specific: MinT/MaxT = 1%, PoP = 0%, default = 20%)
2. **Hours**: intersection must be ≥ `temporalCoverage_hours` (MinT/MaxT = 5h, default = 0h)

### 15.3 Key analysis methods (what we need equivalents for)

| GFE method | What it computes | Our equivalent |
|---|---|---|
| `getMinMax` | Absolute min and max across all grids in period | `min()/max()` of hourly temps in period |
| `getAverage` | Time-weighted average | `mean()` of hourly values |
| `getDominantWx` | Most prevalent weather type by coverage-weighted hours | Most frequent `precipType` + highest `precipProbability` |
| `vectorMinMax` | Wind magnitude min/max + dominant direction | `min()/max()` of hourly windSpeed + mode of windDir |
| `rankedWx` | Weather types ranked by prevalence | Hourly weather codes ranked by frequency |
| `binnedPercent` | Values distributed into bins with percentages | PoP binning from hourly precipProbability |
| `hourlyTemp` | Per-hour temperature values | Direct from `HourlyForecastPoint.outTemp` |
| `accumMinMax` | Accumulated min/max (e.g., QPF) | Sum of hourly precipAmount |

### 15.4 Coverage weights for weather ranking

```python
coverage_weights = {
    "Def":    6,   "Wide":   5,   "Brf":    4,   "Frq":    4,
    "Ocnl":   4,   "Pds":    4,   "Inter":  4,   "Lkly":   4,
    "Num":    3,   "Sct":    2,   "Chc":    2,   "Areas":  2,
    "SChc":   1,   "WSct":   1,   "Iso":    1,   "Patchy": 1,
}
```

Higher weight = more significant. Used in `getDominantValues` to rank competing weather types within a period.

---

## 16. Narrative Orchestrator

**Source:** `ForecastNarrative.py` (72,889 bytes, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ForecastNarrative.py))

Four classes: `Node`, `Narrative`, `StatisticsDictionary`, `ForecastNarrative`. The main class inherits from both `TextRules` and `SampleAnalysis`.

### 16.1 Period segmentation — NOT fixed day/night splits

Period segmentation is driven entirely by the **narrative definition** (provided externally by the product formatter). ForecastNarrative is agnostic to day/night — it creates consecutive time windows of specified duration.

`__breakOutTimeRange` creates components:
```python
# narrativeDefinition["narrativeDef"] = [
#     ("Period_1", 12),        # 12-hour daytime
#     ("Period_2_3", 12),      # 12-hour overnight
#     ("Period_4_5", 12),      # next day
#     ("Extended", 24),        # extended periods
# ]
# Each tuple → a consecutive time range of N hours
```

For each `(componentType, periodHours)` tuple:
- Creates `TimeRange(start, start + hours * 3600)`
- Start of next component = end of previous
- "Custom" components can specify `(startHour, endHour)` relative to midnight local time for non-consecutive windows

**Day vs night is determined by the product definition naming** — components named "Period_1" (daytime) vs "Period_2_3" (overnight) etc. The orchestrator doesn't know or care.

### 16.2 Tree architecture — four levels

```
Narrative (root)
  └── Component (one per time period — e.g., "Today", "Tonight", "Saturday")
       └── Phrase (one per weather element — sky, wind, temp, wx)
            └── SubPhrase (one per sub-period within the phrase)
```

### 16.3 Tree traversal — fixed-point iteration

```python
def generateForecast(self, argDict, editArea, areaLabel):
    changesMade = 1
    passes = 0
    while changesMade:
        changesMade = self.traverseTree(self.__narrativeTree)
        passes += 1
        if passes > passLimit:
            # error recovery
```

Each pass:
1. Walk every node in the tree
2. For each node, iterate over `node.methodList`
3. Call `method(tree, node)` — truthy return = method is done (add to `doneList`), falsy = call again next pass
4. Recurse into children
5. Stop when no changes made (convergence) or pass limit exceeded

**Error recovery:** Three phases — "lastChance" pass (signal methods to finish), "fixIt" pass (force placeholder text on unresolved nodes: `"|* Please enter ... *|"`), then halt.

### 16.4 Runtime tree restructuring

The tree supports dynamic manipulation during traversal:
- `insertChild(sibling, newChild)` — insert a phrase before/after
- `remove()` — remove a phrase
- `replace(nodeList)` — replace a phrase with multiple
- `addPhrase(prevPhrase)` — clone and insert
- `addPhraseDef(prevPhrase, phraseDef)` — create new type and insert

This is how wind direction changes mid-period get handled: the phrase splits itself into sub-phrases during traversal.

### 16.5 Data sampling — two-phase

**Phase 1 (`getNarrativeData`):** Build sampler requests from all components' `analysisList` entries. Cross-product of elements × edit areas × time ranges. Submit batch to `HistoSampler` or server.

**Phase 2 (`__createStatisticsDictionary`):** For each element/area/timeRange: compute statistics via analysis methods (min, max, avg, dominant weather, etc.), apply unit conversion + rounding, store in `StatisticsDictionary`.

### 16.6 Statistics retrieval during traversal

`StatisticsDictionary.get(element, timeRange, areaLabel, statLabel, mergeMethod)`:
1. Exact-match lookup first
2. If no match, gather all overlapping sub-ranges, sort chronologically
3. Apply merge method: "List" (raw), "Min"/"Max" (extremes), "MinMax" (both), "Average", "Sum", "MergeBins" (time-weighted bin merge)
4. For vectors: magnitude is merged, direction from last entry
5. For weather: all subkeys collected, deduplicated, filtered

### 16.7 Narrative definition structure (what products provide)

```python
narrativeDefinition = {
    "narrativeDef": [
        (componentName, periodHours),  # e.g., ("Period_1", 12)
        ...
    ],
    "methodList": [...],       # methods on Narrative root node
    "passLimit": 20,           # max traversal passes
    "trace": 0,                # debug
}
```

Each component definition (from product formatter):
```python
componentDef = {
    "methodList": [...],       # methods on component node
    "phraseList": [...],       # phrase factory functions
    "analysisList": [          # what data to sample
        (element, method),
        (element, method, args),
    ],
}
```

### 16.8 Relevance to our engine

We don't need the tree traversal/fixed-point-iteration architecture — that solves the AWIPS problem of resolving interdependent phrase methods across a complex gridded data model. Our provider data is pre-structured (`HourlyForecastPoint` / `DailyForecastPoint`), so we can generate text in a single sequential pass.

What IS relevant:
- **Period definition by product** — our narrative definition should similarly specify `(periodLabel, hours)` tuples
- **Component → phrase list** pattern — each period contains an ordered list of phrase generators
- **Statistics dictionary** — we need an equivalent that aggregates hourly provider data into per-period summaries (min/max temp, dominant weather, max wind, etc.)
- **The merge methods** (Min, Max, Average, List, MergeBins) map directly to how we summarize hourly data within a period

---

## 17. Marine Phrases

**Source:** `MarinePhrases.py` (~370 lines, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/MarinePhrases.py))

### 17.1 Wave height text ranges (`wave_range`)

| Average (ft) | Text |
|---|---|
| 0 | "less than 1 foot" |
| 1 | "1 foot or less" |
| 1.5 | "1 to 2 feet" |
| 2 | "1 to 3 feet" |
| 3 | "2 to 4 feet" |
| 5 | "3 to 6 feet" |
| 8 | "6 to 10 feet" |
| 12 | "10 to 14 feet" |
| 20 | "15 to 20 feet" |
| 100 | "over 20 feet" |

### 17.2 Chop categories (`chop_words`)

| Wind (kt) | Chop |
|---|---|
| ≤ 7 | "smooth" |
| 8-12 | "a light chop" |
| 13-17 | "a moderate chop" |
| 18-22 | "choppy" |
| 23-27 | "rough" |
| 28-32 | "very rough" |
| > 32 | "extremely rough" |

### 17.3 Seas/waves/inland logic

- Wind > 34 kt → report combined seas (WaveHeight) instead of wind waves
- Both waves > 7 ft AND swells > 7 ft → report combined seas
- Inland waters areas → use WindWaveHgt with WaveHeight fallback, no Period
- Mixed swell: direction difference ≥ 90° AND swell2Mag/swellMag > 0.50 → "mixed swell" descriptor

### 17.4 Marine text abbreviations (`marine_abbreviateText`)

Regex substitutions: NORTH→N, SOUTH→S, KNOTS→kt, FEET→ft, Thunderstorm→Tstm, NAUTICAL MILES→nm, SUNDAY→SUN, etc.

---

## 18. Fire Weather Phrases

**Source:** `FirePhrases.py` (~540 lines, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/FirePhrases.py))

### 18.1 Smoke dispersal categories

| VentRate (knot-ft) | Category |
|---|---|
| < 40,000 | "poor" |
| 40,000-59,999 | "fair" |
| 60,000-99,999 | "good" |
| 100,000-149,999 | "very good" |
| ≥ 150,000 | "excellent" |

### 18.2 Haines Index

| Index | Text |
|---|---|
| 0-3 | "very low potential for large plume dominated fire growth" |
| 4 | "low potential..." |
| 5 | "moderate potential..." |
| 6-10 | "high potential..." |

### 18.3 Humidity recovery

MaxRH > 50% → "Excellent" immediately. Otherwise diff from 24h prior:

| Threshold (% diff) | Category |
|---|---|
| ≤ 25 | "Poor" |
| ≤ 55 | "Moderate" |
| ≤ 70 | "Good" |
| ≤ 100 | "Excellent" |

### 18.4 LAL (Lightning Activity Level)

| LAL | Description |
|---|---|
| 1 | "No Tstms" |
| 2 | "1-8 strikes" |
| 3 | "9-15 strikes" |
| 4 | "16-25 strikes" |
| 5 | ">25 strikes" |
| 6 | "Dry lightning" |

Coverage-to-LAL: Iso/SChc → 2-3, Patchy → 2, Areas/Chc/Sct → 4, Lkly through Wide → 5, any Dry T → 6.

### 18.5 Ridge/valley wind splitting

When `ridgeValleyAreas` returns non-empty, wind phrases split into "Valleys/lwr slopes..." and "Ridges/upr slopes...." with area intersection.

---

## 19. Discrete Phrases (Hazard Headlines)

**Source:** `DiscretePhrases.py` (~2,200 lines, [raw URL](https://raw.githubusercontent.com/Unidata/awips2/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/DiscretePhrases.py))

### 19.1 Hazard action control words

| Action | Text |
|---|---|
| NEW/EXA/EXB | "in effect" |
| CON | "remains in effect" |
| CAN | "is cancelled" |
| EXT | "now in effect" |
| EXP | "has expired" / "will expire" |
| UPG | "no longer in effect" |

### 19.2 Four timing phrase modes

| Mode | Precision | Example output |
|---|---|---|
| EXPLICIT | Exact time | "from 4 PM MST" |
| FUZZY4 | 6-hour blocks | "this afternoon", "late tonight" |
| FUZZY8 | 3-hour blocks | "early this afternoon", "late this morning" |
| DAY_NIGHT_ONLY | Day/night | "today", "tonight", "Saturday night" |

### 19.3 Timing connector matrix

| Start type | End type | Start prefix | End prefix |
|---|---|---|---|
| NONE | EXPLICIT | — | "until" |
| NONE | FUZZY | — | "through" |
| EXPLICIT | EXPLICIT | "from" | "to" |
| EXPLICIT | FUZZY | "from" | "through" |
| FUZZY | FUZZY | "from" | "through" |
| DAY_NIGHT | DAY_NIGHT | "from" | "through" |
| EXP action | any | — | "at" |

### 19.4 Timing word tables (FUZZY4 example)

**Same day:**
- 0-6h: "early this morning"
- 6-12h: "this morning"
- 12-18h: "this afternoon"
- 18-24h: "this evening"

**Next day:**
- 0h: "this evening"
- 0-6h: "late tonight"
- 6-12h: "{dayOfWeek} morning"
- 12-18h: "{dayOfWeek} afternoon"
- 18-24h: "{dayOfWeek} evening"

### 19.5 Segment VTEC priority ordering

Segments ordered by: significance (F < S < A < Y < W) × action code, with cancellations/expirations weighted last (appear first in product).

### 19.6 Relevance to our engine

The timing word tables (FUZZY4 especially) map directly to how we need to express sub-period timing in forecast text — "this afternoon", "late tonight", "{dayOfWeek} morning" etc. The DAY_NIGHT_ONLY table is essentially our period label system. The connector matrix ("from"/"through"/"until"/"to"/"at") governs how timing phrases are joined.

---

## Analysis Complete

All GFE text formatter source files have been analyzed. Total: ~18,700 lines across 15 files.

| File | Lines | Section |
|---|---|---|
| ScalarPhrases.py | 2,747 | §1-2 (sky, temperature) |
| VectorRelatedPhrases.py | 1,564 | §3 (wind) |
| WxPhrases.py | 1,943 | §4 (weather types) |
| PhraseBuilder.py | 4,237 | §5 (sentence assembly) |
| ConfigVariables.py | 1,280 | §7 (configuration) |
| TimeDescriptor.py | 761 | §6 (time descriptors) |
| CombinedPhrases.py | ~300 | §11 (sky+PoP+weather) |
| TextRules.py | 107 | §13 (aggregator) |
| StringUtils.py | ~250 | §12 (text utilities) |
| Translator.py | ~460 | §14 (translation) |
| Interfaces.py | (translateForecast def) | §14 |
| SampleAnalysis.py | 2,970 | §15 (data sampling) |
| ForecastNarrative.py | ~2,000+ | §16 (narrative orchestrator) |
| MarinePhrases.py | ~370 | §17 (marine) |
| FirePhrases.py | ~540 | §18 (fire weather) |
| DiscretePhrases.py | ~2,200 | §19 (hazard headlines) |
