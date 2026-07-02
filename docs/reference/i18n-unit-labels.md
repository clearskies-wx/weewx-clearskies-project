# I18N Unit Labels — Verified Reference Table

**Verified:** 2026-07-02 against national meteorological service websites.  
**Governing plan:** `docs/planning/I18N-COMPLIANCE-PLAN.md` §1C  
**Used by:** API locale files (`weewx_clearskies_api/locales/*.json`), dashboard `formatUnit()` custom label fallbacks

---

## BIPM/SI Rules (apply to ALL locales)

Source: BIPM SI Brochure 9th edition (2019), NIST SP 330.

| Rule | Standard | Example |
|------|----------|---------|
| SI unit symbols are the same in ALL languages | BIPM §5.1 | °C is °C in Japanese, German, Russian — never 摄氏度 as unit symbol |
| Symbols are never pluralized | BIPM §5.1 | 5 km, not 5 kms |
| Space between number and unit symbol | NIST | `37 °C` not `37°C`; exceptions: `°` alone, `%` |
| Decimal marker: comma or period per locale | BIPM Resolution 10 (2003) | See decimal separator table below |
| Digit grouping: thin space, never comma or period | BIPM §5.4.4 | `76 483 522` not `76,483,522` |
| Non-SI units: not covered by BIPM — locale-specific | — | "mph", "knots", "feet" need translation |

---

## Decimal Separator by Locale

| Locale | Decimal sep | Thousands grouping | Example |
|--------|------------|-------------------|---------|
| `en` | `.` | `,` | 1,234.5 |
| `de` | `,` | `.` or thin space | 1.234,5 |
| `es` | `,` | `.` or thin space | 1.234,5 |
| `fr` | `,` | narrow no-break space | 1 234,5 |
| `it` | `,` | `.` | 1.234,5 |
| `nl` | `,` | `.` or thin space | 1.234,5 |
| `pt-PT` | `,` | thin space or `.` | 1.234,5 |
| `pt-BR` | `,` | `.` | 1.234,5 |
| `ru` | `,` | thin space | 1 234,5 |
| `ja` | `.` | `,` | 1,234.5 |
| `zh-CN` | `.` | `,` | 1,234.5 |
| `zh-TW` | `.` | `,` | 1,234.5 |
| `fil` | `.` | `,` | 1,234.5 |

**Implementation:** Use `Intl.NumberFormat(locale)` (dashboard) and `babel.numbers.format_decimal(value, locale=locale)` (API). These handle decimal/grouping correctly per CLDR data. Do NOT build custom formatting.

---

## `Intl.NumberFormat` Unit Support (Dashboard)

| Weather unit | Intl unit identifier | Supported? |
|-------------|---------------------|-----------|
| Temperature °C | `celsius` | Yes |
| Temperature °F | `fahrenheit` | Yes |
| Wind km/h | `kilometer-per-hour` | Yes |
| Wind mph | `mile-per-hour` | Yes |
| Wind m/s | `meter-per-second` | Yes |
| Rain mm | `millimeter` | Yes |
| Rain in | `inch` | Yes |
| Direction ° | `degree` | Yes |
| Humidity % | `percent` | Yes |
| Pressure hPa | — | No — custom label |
| Pressure mbar | — | No — custom label |
| Pressure inHg | — | No — custom label |
| Wind knots | — | No — custom label |
| Radiation W/m² | — | No — custom label |
| Rain rate (any)/hr | — | No — custom label |
| Pressure rate (any)/hr | — | No — custom label |

---

## Non-SI Unit Labels by Locale

Verified against national meteorological service websites. These labels are used in API locale files and dashboard `formatUnit()` custom label fallbacks for units not supported by `Intl.NumberFormat`.

| Unit | en | de | es | fr | it | ja | nl | pt-BR | pt-PT | ru | zh-CN | zh-TW | fil |
|------|----|----|----|----|----|----|----|----|----|----|----|----|-----|
| knot | kn | kn | kn | nd | kn | ノット | kn | nó | nó | уз | 节 | 節 | kn |
| feet | ft | ft | ft | ft | ft | フィート | ft | pés | pés | фт | 英尺 | 英尺 | ft |
| miles | mi | mi | mi | mi | mi | マイル | mi | mi | mi | миль | 英里 | 英里 | mi |
| mph | mph | mph | mph | mph | mph | mph | mph | mph | mph | миль/ч | 英里/时 | 英里/時 | mph |
| inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | д.рт.ст. | 英寸汞柱 | 英寸汞柱 | inHg |
| hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | гПа | 百帕 | 百帕 | hPa |
| W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | Вт/м² | W/m² | W/m² | W/m² |

---

## Verified Unit Display per National Meteorological Service

| Locale | Met service | Temp | Wind | Pressure | Rain | Decimal | Source |
|--------|-------------|------|------|----------|------|---------|--------|
| `en` | NWS (US) | °F/°C | mph/kt | inHg/mb | in/mm | `.` | weather.gov |
| `de` | DWD | °C | km/h | hPa | mm | `.` (data tables) | dwd.de |
| `es` | AEMET | °C | km/h | — | mm | `,` | aemet.es |
| `fr` | Météo-France | °C | km/h | hPa | mm | `,` | meteofrance.com |
| `it` | ilMeteo/AM | °C | km/h | mbar | mm | `.` (data) | ilmeteo.it |
| `nl` | KNMI | °C | Beaufort + km/h | — | mm | `,` | knmi.nl |
| `pt-PT` | IPMA | °C | km/h | hPa | mm | `,` | ipma.pt |
| `pt-BR` | INMET | °C | km/h | hPa | mm | `,` | inmet.gov.br |
| `ru` | Росгидромет | °C | м/с (m/s) | мм рт. ст. (mmHg) | mm | `,` | meteoinfo.ru |
| `ja` | JMA | ℃ | m/s | hPa | mm | `.` | jma.go.jp |
| `zh-CN` | CMA | ℃ | m/s + 级 (grade) | hPa | mm | `.` | weather.cma.cn |
| `zh-TW` | CWA | °C | km/h | hPa | mm | `.` | cwa.gov.tw |
| `fil` | PAGASA | °C | km/h | — | mm | `.` | pagasa.dost.gov.ph |

### Key Findings

- **JMA and CMA use ℃** (single Unicode character U+2103), not °C (degree + C). This is a display distinction.
- **Russia uses м/с** (Cyrillic м/с) for m/s, and **мм рт. ст.** (mm mercury column) for pressure — NOT hPa. This is the only locale where the pressure unit symbol differs significantly.
- **KNMI (Netherlands) uses Beaufort** as the primary wind unit, with km/h secondary.
- **PAGASA (Philippines) uses English** for all weather text — Filipino/Tagalog is not used for meteorological descriptions.
- **DWD and ilMeteo use period** (`.`) in data tables despite German/Italian normally using comma — this is standard practice for scientific data display in tabular form per BIPM. However, prose text uses comma.
