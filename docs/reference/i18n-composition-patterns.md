# I18N Composition Patterns — Verified Reference

**Verified:** 2026-07-02 against national meteorological service websites.  
**Governing plan:** `docs/planning/I18N-COMPLIANCE-PLAN.md` §1D  
**Used by:** API conditions text engine (`weewx_clearskies_api/sse/conditions_text.py`), API locale files (`weewx_clearskies_api/locales/*.json`), CJK composer modules (`weewx_clearskies_api/locales/composers/`)

---

## Composition Classes

Every locale falls into one of two classes:

| Class | How it works | Locales |
|-------|-------------|---------|
| **TEMPLATE** | Template interpolation with locale-specific connectors, separators, and component order. The locale file provides `separator`, `connector_final`, and `order`. | en, de, es, fr, it, nl, pt-PT, pt-BR, ru, fil |
| **CUSTOM** | A dedicated Python composer module that constructs locale-native compound expressions. Template interpolation cannot express these languages' weather description patterns. | ja, zh-CN, zh-TW |

**Russian (ru)** uses TEMPLATE class but requires **case-inflected label variants** (nominative, instrumental, genitive) — see Russian section below.

---

## Verified Patterns per Locale

| Locale | Met service example | Pattern | Class |
|--------|-------------------|---------|-------|
| `en` | "Warm and Humid, Partly Cloudy, with Light Rain" | Comma-separated, "and"/"with" connectors | TEMPLATE |
| `de` | "wolkenlos", "leichter Regen" (DWD). Prose: "Es wird wechselhaft mit Regen und Wind" | Single terms or brief phrases. Connectors: "und"/"mit" | TEMPLATE |
| `es` | "Cielo despejado", "Poco nuboso", "Intervalos nubosos" (AEMET) | Single terms. No compound sentence form in forecast cards | TEMPLATE |
| `fr` | "Soleil prédominant", "Vent de Nord-Ouest faible à modéré" (Météo-France) | Descriptive phrases. Connectors: "et"/"avec" | TEMPLATE |
| `it` | "sereno", "poco nuvoloso", "pioggia debole" (ilMeteo) | Single terms or brief phrases | TEMPLATE |
| `nl` | "lichte bui afgewisseld door zon", "toenemende bewolking en af en toe regen" (KNMI) | Descriptive phrases. Connector: "en" | TEMPLATE |
| `pt-PT` | "céu limpo", "parcialmente nublado", "chuva fraca" (IPMA) | Single terms or brief phrases | TEMPLATE |
| `pt-BR` | "nublado", "chuva", "parcialmente nublado" (INMET) | Single terms or brief phrases | TEMPLATE |
| `ru` | "Малооблачно, без осадков" (Росгидромет) | Comma-separated. Uses case endings (instrumental with "с/без") | TEMPLATE |
| `ja` | "曇り時々晴れ" (cloudy occasionally clear), "晴れのち曇り" (clear then cloudy) (JMA) | Compound expressions using 時々/一時/のち operators. No Western connectors. No spaces. | CUSTOM |
| `zh-CN` | "中雨 东南风 3~4级" (moderate rain, SE wind, grade 3-4) (CMA) | Space-separated components. No connectors. Wind direction + grade system. | CUSTOM |
| `zh-TW` | "多雲", "晴", "陰", "雨" (CWA) | Same pattern as zh-CN with traditional characters | CUSTOM |
| `fil` | "Cloudy skies with scattered rains and thunderstorms" (PAGASA) | English — PAGASA uses English for all meteorological text | TEMPLATE (English) |

---

## TEMPLATE Locale Configuration

For TEMPLATE-class locales, the API locale file carries a `composition` block:

```json
{
  "composition": {
    "pattern": "template",
    "separator": ", ",
    "connector_and": "and",
    "connector_with": "with",
    "order": ["temperature", "sky", "precipitation"]
  }
}
```

### Per-Locale Template Configuration

| Locale | separator | connector_and | connector_with | order |
|--------|-----------|--------------|----------------|-------|
| `en` | `, ` | `and` | `with` | temperature, sky, precipitation |
| `de` | `, ` | `und` | `mit` | sky, temperature, precipitation |
| `es` | `, ` | `y` | `con` | sky, temperature, precipitation |
| `fr` | `, ` | `et` | `avec` | sky, temperature, precipitation |
| `it` | `, ` | `e` | `con` | sky, temperature, precipitation |
| `nl` | `, ` | `en` | `met` | sky, temperature, precipitation |
| `pt-PT` | `, ` | `e` | `com` | sky, temperature, precipitation |
| `pt-BR` | `, ` | `e` | `com` | sky, temperature, precipitation |
| `ru` | `, ` | `и` | `с` | sky, temperature, precipitation |
| `fil` | `, ` | `and` | `with` | temperature, sky, precipitation |

---

## CUSTOM Composer Modules

For CUSTOM-class locales, the API locale file references a composer module:

```json
{
  "composition": {
    "pattern": "custom",
    "composer": "ja"
  }
}
```

### Japanese (ja) — `composers/ja.py`

JMA uses a unique compound expression system with 15 base weather types and three composition operators:

| Operator | Reading | Meaning | Example |
|----------|---------|---------|---------|
| `時々` | tokidoki | occasionally | `曇り時々晴れ` = cloudy, occasionally clear |
| `一時` | ichiji | temporarily | `曇り一時雨` = cloudy, temporarily rainy |
| `のち` / `後` | nochi | then/later | `晴れのち曇り` = clear, then cloudy |

**15 JMA base weather types:**

| Japanese | Reading | English |
|----------|---------|---------|
| 晴れ | hare | Clear/Sunny |
| 曇り | kumori | Cloudy |
| 雨 | ame | Rain |
| 雪 | yuki | Snow |
| 霧 | kiri | Fog |
| 雷 | kaminari | Thunder |
| みぞれ | mizore | Sleet |
| ひょう | hyō | Hail |
| 暴風雨 | bōfūu | Storm |
| 大雨 | ōame | Heavy rain |
| 大雪 | ōyuki | Heavy snow |
| 小雨 | kosame | Light rain |
| 小雪 | koyuki | Light snow |
| 薄曇 | usugumori | Thin clouds |
| 快晴 | kaisei | Clear (fine) |

**Rules:**
- Primary condition comes first, modifier comes second: `曇り時々晴れ` (primary=cloudy, modifier=clear)
- No spaces between components
- Japanese comma `、` (tōten) used when listing independent conditions
- Temperature comfort expressed differently: `蒸し暑い` (muggy), `肌寒い` (chilly)

### Chinese Simplified (zh-CN) — `composers/zh.py`

CMA format: space-separated components with wind direction + grade notation.

**Pattern:** `{condition} {wind_direction}风 {grade_range}级`

**Example:** `中雨 东南风 3~4级` (moderate rain, SE wind, grade 3-4)

**Base conditions:**

| Chinese | English |
|---------|---------|
| 晴 | Clear |
| 多云 | Cloudy |
| 阴 | Overcast |
| 小雨 | Light rain |
| 中雨 | Moderate rain |
| 大雨 | Heavy rain |
| 暴雨 | Torrential rain |
| 雷阵雨 | Thunderstorm |
| 小雪 | Light snow |
| 中雪 | Moderate snow |
| 大雪 | Heavy snow |
| 雾 | Fog |
| 霾 | Haze |

**Rules:**
- No connectors — components are space-separated
- Wind uses Chinese cardinal directions: 东 (E), 南 (S), 西 (W), 北 (N), 东南 (SE), etc.
- Wind grade (级) is the Beaufort number
- Chinese comma `，` used when listing multiple conditions

### Chinese Traditional (zh-TW) — `composers/zh.py` (shared module, traditional character set)

CWA uses the same structural pattern as CMA but with traditional characters.

**Character mapping (simplified → traditional):**

| Simplified | Traditional | English |
|-----------|-------------|---------|
| 晴 | 晴 | Clear |
| 多云 | 多雲 | Cloudy |
| 阴 | 陰 | Overcast |
| 雨 | 雨 | Rain |
| 雪 | 雪 | Snow |
| 雾 | 霧 | Fog |
| 霾 | 霾 | Haze |
| 东 | 東 | East |
| 风 | 風 | Wind |

The `composers/zh.py` module accepts a `variant` parameter (`"simplified"` or `"traditional"`) to select the character set.

---

## Russian Case-Inflected Labels

Russian uses TEMPLATE composition but labels need multiple grammatical forms for correct sentence construction.

### Required case forms per label

| Case | Usage | Example with "дождь" (rain) |
|------|-------|----------------------------|
| **Nominative** | Standalone display | `дождь` |
| **Instrumental** | "with X" construction (`с` + instrumental) | `с дождём` |
| **Genitive** | "without X" construction (`без` + genitive) | `без дождя` |

### Russian locale file structure

```json
{
  "precipitation": {
    "light_rain": {
      "nominative": "слабый дождь",
      "instrumental": "слабым дождём",
      "genitive": "слабого дождя"
    },
    "moderate_rain": {
      "nominative": "умеренный дождь",
      "instrumental": "умеренным дождём",
      "genitive": "умеренного дождя"
    }
  },
  "sky": {
    "clear": {
      "nominative": "ясно",
      "instrumental": "ясной погодой",
      "genitive": "ясной погоды"
    }
  }
}
```

The template engine resolves the correct case form based on the label's position in the sentence:
- Standalone or first position → nominative
- After `с` (with) → instrumental
- After `без` (without) → genitive

---

## Filipino (fil) Special Case

PAGASA uses English for all meteorological text. The Filipino locale uses English-pattern composition (same connectors, same word order as `en`). Weather condition labels in the `fil` locale file are in English, matching PAGASA's practice.
