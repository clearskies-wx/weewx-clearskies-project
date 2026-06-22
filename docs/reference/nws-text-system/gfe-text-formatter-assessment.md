# GFE Text Formatter / AWIPS-II Assessment

**Task:** R3.2 — Research whether the NWS AWIPS-II GFE text formatter can be adapted for our conditions text engine.  
**Date:** 2026-06-21  
**Researcher:** Claude Code (Sonnet 4.6)

---

## 1. Is AWIPS-II GFE Open Source?

**Yes. Confirmed.**

AWIPS-II (Advanced Weather Interactive Processing System II) was originally developed for NOAA/NWS by Raytheon. The NSF Unidata Program Center at UCAR maintains an open-source, non-operational version released to the research and education community. The source code is in the public domain — no restrictions on download, modification, or redistribution.

**Primary repository:** https://github.com/Unidata/awips2  
**License:** Public domain (confirmed by Unidata documentation)  
**Source:** https://github.com/Unidata/awips2 (repository About page)

A companion NWS-plugins repository exists at https://github.com/Unidata/awips2-nws but is mostly Java (95.5%) and does not contain the text formatter infrastructure.

**Important caveat:** The NWS operational text formatters (e.g., ZoneFcst.py for the Zone Forecast Product) are distributed through the NWS Software Configuration Point (SCP) via Subversion, not the public GitHub repo. The GitHub repo contains the *framework* (base classes, phrase libraries, utilities) and test/example formatters. The operational product formatters are NWS-internal localizations. However, the framework itself is fully sufficient for our purposes — we do not need the operational formatters.

---

## 2. Language and Repository Structure

**Language:** Python (text formatter layer) over Java/OSGi (EDEX data server and CAVE visualization application).

The text generation subsystem is entirely Python. It runs as a plugin within the CAVE Eclipse application via a Java-Python bridge, but the phrase-building and text-assembly logic is pure Python.

### Key directory paths in the repository

All relative to `cave/com.raytheon.viz.gfe/` in the `Unidata/awips2` repo:

```
localization/gfe/userPython/
    textProducts/          # Concrete product formatters (e.g., ZoneFcst, HSF, MultipleElementTable)
    textUtilities/         # The reusable framework — this is what we care about
    utilities/             # General Python utilities
    smartTools/            # Grid-editing tools (not relevant)
    procedures/            # Automation procedures (not relevant)

python/
    testFormatters/        # Example/test formatters (RecreationFcst, RDFcst, PeriodByElement, etc.)
    utility/               # Supporting utilities
```

**Sources:**
- https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython
- https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/python/testFormatters

---

## 3. How GFE Converts Gridded Data to Narrative Text

The GFE text generation pipeline has four distinct stages:

### Stage 1: Data Sampling and Statistics

The `ForecastNarrative` class (inherits `TextRules` and `SampleAnalysis`) requests gridded weather element data for specified time ranges and geographic areas. For each element (sky cover, temperature, wind, PoP, etc.) it computes statistics over the time window: min, max, average, vector average, mode.

The `StatisticsDictionary` provides multi-level keyed access: `stats[element][areaLabel][timeRange]`.

**Source:** `localization/gfe/userPython/textUtilities/ForecastNarrative.py`

### Stage 2: Threshold-Based Categorization

Raw statistics are passed through threshold tables to produce categorical values. This is where numbers become words. Examples:

**Sky coverage → text** (`ScalarPhrases.sky_valueList()`):
```python
(5,  "sunny",        "clear")
(25, "sunny",        "mostly clear")
(50, "mostly sunny", "partly cloudy")
(69, "partly sunny", "mostly cloudy")
(87, "mostly cloudy","mostly cloudy")
(100,"cloudy",       "cloudy")
```
First value in each tuple is the upper % threshold; second/third are day/night phrases.

**Temperature → text** (`ScalarPhrases.getTempPhrase()`):
- If max-min spread > 4°F: outputs "X to Y" (e.g., "84 to 89")
- If spread ≤ 4°F: converts to decade+position string
  - Decade: 80 → "80s", 10 → "teens", 0 → "single digits"
  - Position (digit 0-3 = "lower", 4-6 = "middle", 7-9 = "upper")
  - Result: 87°F → "upper 80s"; single value → "near 87"

**Wind → text** (`VectorRelatedPhrases`):
- If min==max magnitude: "around 8 mph"
- If min < low threshold: "up to 12 mph"
- Otherwise: "5 to 10 mph"
- Speed summary descriptors:
  ```
  < 25 mph: (no adjective)
  25-29:    "breezy"
  30-39:    "windy"
  40-49:    "very windy"
  50-73:    "strong winds"
  74+:      "hurricane force winds"
  ```
- Gusts only reported if > 10 mph above sustained (configurable)

**Weather type → text** (`WxPhrases.wxTypeDescriptors()`):
- Internal codes map to words: SW→"flurries", RW→"rain showers", T with Dry→"dry thunderstorms"
- Intensity codes: "--" → "light", "-" → "light", "+" → "heavy"
- Coverage codes: "Chc" → "chance of", "Def" → definite (no qualifier)

**Source:** `localization/gfe/userPython/textUtilities/ScalarPhrases.py`, `VectorRelatedPhrases.py`, `WxPhrases.py`

### Stage 3: Tree-Based Phrase Assembly

This is the architectural core. The system builds a tree of `Node` objects:

```
Narrative (root)
  Component (e.g., "Today" period)
    Phrase (sky condition)
    Phrase (temperature)
    Phrase (wind)
    Phrase (precipitation)
  Component (e.g., "Tonight" period)
    ...
```

Each `Node` has a `methodList` — a list of Python callables that progressively fill in the node's `words` field. The tree is traversed repeatedly until no node changes (`changeFlag=0`). This is constraint-satisfaction: methods can fire when their prerequisites are met.

The standard phrase-processing pipeline (`PhraseBuilder.standard_phraseMethods()`):
```python
[
    self.consolidatePhrase,
    self.checkLocalEffects,
    self.combinePhraseStats,
    self.consolidateTrends,
    self.chooseMostImportant,
    self.combineWords,
    self.fillNulls,
    self.timeDescriptorModeration,
    self.assembleSubPhrases,
    self.postProcessPhrase,
]
```

Conjunction logic: "rain and snow and freezing rain" → "rain, snow and freezing rain" (Oxford comma with serial comma rule via `useCommas()`).

**Source:** `localization/gfe/userPython/textUtilities/PhraseBuilder.py`, `ForecastNarrative.py`

### Stage 4: Time Descriptor Attachment

`TimeDescriptor.py` maps time ranges to natural language labels:

```python
(6,  9,  "early in the morning")
(6,  12, "in the morning")
(15, 18, "late in the evening")
(18, 21, "after midnight")
```

The `getWeekday_descriptor()` method produces "Tonight", "Tuesday evening", "Wednesday afternoon", etc., based on current time vs. the period start.

**Source:** `localization/gfe/userPython/textUtilities/TimeDescriptor.py`

---

## 4. Key Grammar Rules and Template Examples

The system is **not template-string based** (no Jinja2 or f-string templates). It is **method-dispatch based**: each weather element class defines phrase generator methods, and the framework calls them in order and assembles the results.

### Concrete product definition example (from RecreationFcst.py)

```python
class TextProduct(TextRules.TextRules, SampleAnalysis.SampleAnalysis):
    Definition = {
        "type": "smart",
        "displayName": "None",
        "defaultEditAreas": [("area1","Area 1")],
        "lineLimit": 45,
    }
    
    def _createNarrativeDef(self):
        # Defines what components and phrases appear in output
        phraseList = [
            self._td_phrase,                    # dew point
            self._rh_phrase,                    # relative humidity
            self._windChill_heatIndex_compoundPhrase,
            self._wind_phrase,                  # wind speed/dir
            self._wx_phrase,                    # weather/precip
            self._ltng_phrase,                  # lightning
        ]
```

### Threshold overrides (per-product customization)

```python
def pop_wx_lower_threshold(self, tree, node):
    return 20  # suppress wx mention if PoP < 20%

def gust_wind_difference_nlValue(self, tree, node):
    return 10  # report gusts only if > 10 mph above sustained
```

Every threshold in `ConfigVariables.py` can be overridden at the product level by defining the same-named method in the TextProduct subclass.

### Tabular product example (from RDFcst.py / PeriodByElement.py)

```python
Definition = {
    "type": "table",
    "rowVariable": "TimePeriod",
    "columnVariable": "WeatherElement",
    "elementList": [
        ("Sky",  "Sky (%)",    "avg",         "singleValue", "Scalar", 1, None),
        ("Wind", "Wind (mph)", "vectorRange",  "avgValue",    "Vector", 5, "ktToMph"),
        ("T",    "Temp",       "avg",          "singleValue", "Scalar", 1, None),
        ("PoP",  "Precip (%)", "avg",          "singleValue", "Scalar", 1, None),
    ],
    "timePeriod": 3,  # 3-hour intervals
}
```

**Source:** `python/testFormatters/RecreationFcst.py`, `PeriodByElement.py`, `RDFcst.py`

---

## 5. Infrastructure Dependencies and Coupling Assessment

### What the GFE text formatter requires from AWIPS

| Dependency | What it is | How tightly coupled |
|---|---|---|
| `SampleAnalysis` | Pulls statistics from GFE gridded database (IFP/HDF5) | Hard dependency — this is the data ingestion layer |
| `ForecastNarrative` | Orchestrates sampling + tree traversal | Depends on `SampleAnalysis` for data |
| `EditArea` / `TimeRange` | GFE geographic area + time range objects | AWIPS-internal Java bridge objects |
| AWIPS IFP Database | The gridded forecast store (GFS, NAM, etc. on HDF5) | All data access goes through this |
| Java Bridge | Python↔Java JVM communication | Required by `ForecastNarrative` to call EDEX |

### What is NOT coupled to AWIPS

| Module | Purpose | Standalone? |
|---|---|---|
| `ScalarPhrases.py` | Number → word conversion (temps, sky %) | YES — pure logic, no AWIPS imports |
| `VectorRelatedPhrases.py` | Wind speed/dir → words | YES — pure logic |
| `WxPhrases.py` | Weather type codes → words | Mostly yes — depends only on `PhraseBuilder` |
| `TimeDescriptor.py` | Time range → "tonight", "Tuesday" | YES — uses Python `datetime` only |
| `ConfigVariables.py` | All threshold tables | YES — pure data |
| `PhraseBuilder.py` | Phrase assembly and grammar | YES — depends on `ConfigVariables`, `TimeDescriptor`, `StringUtils` |
| `TextRules.py` | Product-level class base | Mostly yes — mixin of the above |

**The phrase libraries (ScalarPhrases, VectorRelatedPhrases, WxPhrases, PhraseBuilder, ConfigVariables, TimeDescriptor) are architecturally decoupled from AWIPS data access.** The coupling is in `SampleAnalysis` and `ForecastNarrative` — which are the gridded-data sampling layers we would not use anyway.

---

## 6. Adaptation Assessment

### Can we adapt GFE text formatting? Yes, but not by transplanting the framework.

**What we should NOT do:** Extract and run the GFE framework as-is. The `TextProduct` → `ForecastNarrative` → `SampleAnalysis` pipeline depends on the IFP gridded database, AWIPS Java bridge, and GFE edit areas. Removing these requires gutting the scaffold that holds everything together.

**What we SHOULD do:** Treat the GFE phrase libraries as a *reference implementation* and extract the core thresholds and logic directly. The valuable IP in GFE text formatting is:

1. **The threshold tables** — exact numeric cutoffs for sky coverage → word, temperature → decade phrase, wind speed → descriptor, etc. These are compact and extractable.
2. **The phrase-assembly grammar** — how conjunctions work, how "around X" vs "X to Y" is chosen, how local effects qualify phrases.
3. **The time descriptor vocabulary** — how time periods map to "tonight", "this afternoon", etc.

All of these can be implemented as simple Python dictionaries and functions in under 300 lines, without any AWIPS dependency.

### Specific reusable logic (copy-adapt, not copy-paste)

**Sky coverage threshold table** — The six-bucket system (0-5% sunny, 5-25% mostly sunny, etc.) is exactly what we need. Extract `sky_valueList()` as a Python list of `(threshold, day_word, night_word)` tuples. ~8 lines.

**Temperature decade phrases** — The `getTempPhrase()` logic (upper/middle/lower + decade) matches NWS output exactly. Extract as a standalone function taking `(temp_f, is_daytime)`. ~30 lines.

**Wind speed category** — The `vector_summary_valueStr()` thresholds (25/30/40/50/74 mph) give descriptors we can layer on top of numeric output. ~10 lines.

**"Around X" vs "X to Y" wind logic** — The min/max comparison and threshold for choosing phrasing. ~15 lines.

**Gust qualification** — Only report gusts if > 10 mph above sustained. ~5 lines.

**Conjunction handling** — The "rain, snow and freezing rain" (not "rain and snow and freezing rain") pattern. ~10 lines.

**Time descriptor vocabulary** — The period-to-label mapping. Directly applicable if we ever add multi-period output. ~40 lines.

### What we are building vs. what GFE does

| Dimension | GFE | Our use case |
|---|---|---|
| Data source | Gridded NWP model forecasts, multi-element | Single PWS sensor stream |
| Time coverage | 7-day forecast, multiple periods | Current conditions (single instant) |
| Geography | Multiple forecast zones, local effects | Single location |
| Output length | Paragraph+ per zone per period | 1-3 sentences, multiple verbosity levels |
| Phrase assembly | Tree traversal, constraint satisfaction | Sequential: sky → temp → wind → feel |

For current conditions text, GFE's elaborate tree machinery is overkill. We need the *vocabulary and thresholds*, not the *assembly engine*.

---

## 7. Alternative Approaches

Since the GFE framework is too coupled for direct reuse, and no community project has cleanly extracted the phrase libraries, three practical paths exist:

### Path A: Extract GFE vocabulary directly (recommended)

Port the threshold tables and phrase-generation logic from `ScalarPhrases.py`, `VectorRelatedPhrases.py`, `WxPhrases.py`, and `ConfigVariables.py` into our own `conditions_text.py` module. This is a 1-3 day implementation exercise. The GFE source is open for study and the logic is clear. Result: NWS-vocabulary-compatible output with no framework dependency.

### Path B: Use an LLM for variable-verbosity text

Provide the LLM with structured sensor readings and a verbosity level prompt. The LLM handles all phrasing. Pros: handles edge cases gracefully, generates natural variation. Cons: requires API call at display time, potential latency, cost at scale, not reproducible (same inputs may produce different output each time). Good as a complement to Path A for the verbose level.

### Path C: Minimal rules engine from scratch

Ignore GFE entirely and write a simple lookup-table system based on reading NWS Zone Forecast Products from the NWS API for our area, and reverse-engineering the vocabulary from observed outputs. This is viable but slower to validate and may produce regional inconsistencies.

**Recommendation: Path A (with optional Path B for verbose level).** The GFE source provides authoritative, production-validated vocabulary. Extracting it is straightforward because the phrase libraries are already pure Python logic.

---

## 8. Source URLs

| Source | URL |
|---|---|
| AWIPS-II main repository | https://github.com/Unidata/awips2 |
| NWS Plugins repository | https://github.com/Unidata/awips2-nws |
| Unidata AWIPS overview | https://www.unidata.ucar.edu/software/awips |
| AWIPS manual | http://unidata.github.io/awips2/ |
| GFE Focal Point Curriculum | https://vlab.noaa.gov/web/oclo/gfe-focal-point-curriculum |
| GFE localization/userPython | https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython |
| textUtilities directory | https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities |
| textProducts directory | https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textProducts |
| testFormatters directory | https://github.com/Unidata/awips2/tree/master/cave/com.raytheon.viz.gfe/python/testFormatters |
| ScalarPhrases.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ScalarPhrases.py |
| PhraseBuilder.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/PhraseBuilder.py |
| VectorRelatedPhrases.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/VectorRelatedPhrases.py |
| WxPhrases.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/WxPhrases.py |
| ForecastNarrative.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ForecastNarrative.py |
| TimeDescriptor.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/TimeDescriptor.py |
| ConfigVariables.py | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/localization/gfe/userPython/textUtilities/ConfigVariables.py |
| RecreationFcst.py (example) | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/python/testFormatters/RecreationFcst.py |
| RDFcst.py (example) | https://github.com/Unidata/awips2/blob/master/cave/com.raytheon.viz.gfe/python/testFormatters/RDFcst.py |
| AMS GFE text formatting paper | https://ams.confex.com/ams/pdfpapers/54419.pdf (PDF — binary, not parseable) |
| AMS GFE methodology paper | https://ams.confex.com/ams/pdfpapers/29049.pdf (PDF — binary, not parseable) |
