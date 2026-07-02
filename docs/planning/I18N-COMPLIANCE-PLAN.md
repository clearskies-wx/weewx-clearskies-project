# I18N Full Compliance — Execution Plan

**Status:** APPROVED  
**Created:** 2026-07-02  
**Brief:** `docs/briefs/I18N-AUDIT-BRIEF.md`  
**Governing rules:** `rules/coding.md` §6 (Internationalization), DASHBOARD-MANUAL.md §3, ADR-021  
**Components:** Dashboard SPA (`weewx-clearskies-dashboard`), API (`weewx-clearskies-api`), Config UI (`weewx-clearskies-stack`)

---

## Context

The i18n audit revealed that while the react-i18next infrastructure was built correctly (13 locales, 13 namespace files, locale sync hook), virtually every feature built after that ignored i18n. Hardcoded English strings in 16+ dashboard components, `'en-US'` locale in 15+ `Intl.DateTimeFormat` calls, `.toFixed()` for display text everywhere, the API composing English sentences for weatherText/Beaufort/AQI/records, the entire wizard in English with zero i18n infrastructure. This plan remediates all violations and establishes infrastructure so they cannot recur.

Clear Skies is a **scientific weather application**. Measurement display must follow international standards (BIPM SI Brochure, 9th edition). Unit symbols, decimal separators, and number formatting must be locale-correct — not naive, not approximated.

**Locale architecture: operator controls everything.** The operator selects the station's language in the wizard (step 1). That `defaultLocale` setting flows to the API (which uses it for all computed text — weatherText, Beaufort labels, AQI categories, record labels, unit labels, number formatting) and to the dashboard (which uses it for all UI chrome — headings, buttons, labels, dates, number display). Visitors do not choose a language. There is no visitor-facing locale picker, no browser language detection, no `Accept-Language` header. One station, one language, set by the operator.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §6 Internationalization (NEW), §7 Charts
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/briefs/I18N-AUDIT-BRIEF.md` — the audit findings this plan remediates

**Repos:**
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind). On weather-dev at `/home/ubuntu/repos/weewx-clearskies-dashboard/`. Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. On weewx at `/home/ubuntu/repos/weewx-clearskies-api/`. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-stack` — Config wizard (Jinja2 + HTMX + Pico CSS). On weather-dev at `/home/ubuntu/repos/weewx-clearskies-stack/`. Branch: `main`. No build step.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- Wizard: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)

**Key ADRs:** ADR-021 (i18n architecture), ADR-042 (single conversion authority), ADR-044 (conditions text engine), ADR-075 (station clock)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase — not batched. No phase advances until coordinator signs off. QC evidence recorded in scratchpad.

---

## 1. Upfront Research — Locale Reference Table

This research is completed upfront, not deferred. It is the authoritative source for all locale-specific implementation decisions.

### 1A. BIPM/SI Rules (apply to ALL locales)

Source: BIPM SI Brochure 9th edition (2019), NIST SP 330.

| Rule | Standard | Example |
|------|----------|---------|
| SI unit symbols are the same in ALL languages | BIPM §5.1 | °C is °C in Japanese, German, Russian — never 摄氏度 as unit symbol |
| Symbols are never pluralized | BIPM §5.1 | 5 km, not 5 kms |
| Space between number and unit symbol | NIST | `37 °C` not `37°C`; exceptions: `°` alone, `%` |
| Decimal marker: comma or period per locale | BIPM Resolution 10 (2003) | See table below |
| Digit grouping: thin space, never comma or period | BIPM §5.4.4 | `76 483 522` not `76,483,522` |
| Non-SI units: not covered by BIPM — locale-specific | — | "mph", "knots", "feet" need translation |

### 1B. Decimal Separator by Locale

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

### 1C. Unit Label Display Strategy

**SI units (°C, km/h, hPa, mm, m/s, W/m², %):** Per BIPM, symbols are identical in all languages. However, `Intl.NumberFormat` with `style: 'unit'` provides locale-aware formatting for many of these and may produce locale-appropriate variations (e.g., spacing, symbol placement). Use `Intl.NumberFormat` where supported.

**`Intl.NumberFormat` unit support (dashboard side):**

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

**Non-SI units requiring locale-specific labels in API locale files:**

| Unit | en | de | es | fr | it | ja | nl | pt-BR | pt-PT | ru | zh-CN | zh-TW | fil |
|------|----|----|----|----|----|----|----|----|----|----|----|----|-----|
| knot | kn | kn | kn | nd | kn | ノット | kn | nó | nó | уз | 节 | 節 | kn |
| feet | ft | ft | ft | ft | ft | フィート | ft | pés | pés | фт | 英尺 | 英尺 | ft |
| miles | mi | mi | mi | mi | mi | マイル | mi | mi | mi | миль | 英里 | 英里 | mi |
| mph | mph | mph | mph | mph | mph | mph | mph | mph | mph | миль/ч | 英里/时 | 英里/時 | mph |
| inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | inHg | д.рт.ст. | 英寸汞柱 | 英寸汞柱 | inHg |
| hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | hPa | гПа | 百帕 | 百帕 | hPa |
| W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | W/m² | Вт/м² | W/m² | W/m² | W/m² |

**STATUS: VERIFIED against national meteorological service websites (2026-07-02).** Sources cited per locale below. Phase 0 T0.1 documents these findings in `docs/reference/i18n-unit-labels.md` for the codebase.

**Verified unit display per national met service:**

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

**Key findings:**
- **JMA and CMA use ℃** (single Unicode character U+2103), not °C (degree + C). This is a display distinction.
- **Russia uses м/с** (Cyrillic м/с) for m/s, and **мм рт. ст.** (mm mercury column) for pressure — NOT hPa. This is the only locale where the pressure unit symbol differs significantly.
- **KNMI (Netherlands) uses Beaufort** as the primary wind unit, with km/h secondary.
- **PAGASA (Philippines) uses English** for all weather text — Filipino/Tagalog is not used for meteorological descriptions.
- **DWD and ilMeteo use period** (`.`) in data tables despite German/Italian normally using comma — this is standard practice for scientific data display in tabular form per BIPM. However, prose text uses comma.

---

## 2. Implementation Phases

### PHASE 0 — Document Research Findings & Composition Architecture

The research is completed above (§1A–1C). Phase 0 writes the findings into the codebase as reference documents and resolves the composition architecture.

**T0.1 — Write verified locale reference documents**
- Owner: `clearskies-docs-author` (Sonnet)
- Do: Write `docs/reference/i18n-unit-labels.md` containing the verified unit display table from §1C above and `docs/reference/i18n-composition-patterns.md` containing the composition patterns from §1D below. These are reference documents, not code — they are the source of truth for all implementation tasks.
- Deliverable: Two reference documents in `docs/reference/`.
- Accept: Documents contain all data from §1C and §1D with sources cited. No "TBD" or "assumed" cells.

### 1D. Verified Sentence Composition Patterns

**Research findings from national meteorological services (2026-07-02):**

| Locale | Met service example | Pattern | Composition class |
|--------|-------------------|---------|-------------------|
| `en` | "Warm and Humid, Partly Cloudy, with Light Rain" | Comma-separated, "and"/"with" connectors | **TEMPLATE** |
| `de` | "wolkenlos" (DWD), "leichter Regen" (DWD) | Single terms or brief phrases; no compound sentence form in data tables. Prose: "Es wird wechselhaft mit Regen und Wind" | **TEMPLATE** |
| `es` | "Cielo despejado", "Poco nuboso", "Intervalos nubosos" (AEMET) | Single terms; no compound sentence form in forecast cards | **TEMPLATE** |
| `fr` | "Soleil prédominant", "Beau temps ensoleillé", "Vent de Nord-Ouest faible à modéré" (Météo-France) | Descriptive phrases, "et"/"avec" connectors | **TEMPLATE** |
| `it` | "sereno", "poco nuvoloso", "nubi sparse", "pioggia debole" (ilMeteo) | Single terms or brief phrases | **TEMPLATE** |
| `nl` | "lichte bui afgewisseld door zon", "toenemende bewolking en af en toe regen" (KNMI) | Descriptive phrases, "en" connector | **TEMPLATE** |
| `pt-PT` | "céu limpo", "parcialmente nublado", "chuva fraca" (IPMA) | Single terms or brief phrases | **TEMPLATE** |
| `pt-BR` | "nublado", "chuva", "parcialmente nublado" (INMET) | Single terms or brief phrases | **TEMPLATE** |
| `ru` | "Малооблачно, без осадков" (Росгидромет) | Comma-separated, uses case endings (instrumental case with "с/без") | **TEMPLATE** (but labels need case-inflected variants) |
| `ja` | "曇" (cloudy), "薄曇" (thin clouds), "曇り時々晴れ" (cloudy occasionally clear), "晴れのち曇り" (clear then cloudy) (JMA) | **Compound expressions** using 時々 (occasionally), 一時 (temporarily), のち/後 (then/later). 15 base weather types. No Western connectors. No spaces. | **CUSTOM** |
| `zh-CN` | "中雨" (moderate rain), "多云" (cloudy), "雷阵雨" (thunderstorm). Format: "中雨 东南风 3~4级" (moderate rain, SE wind, grade 3-4) (CMA) | Space-separated components, no connectors. Wind direction + grade system. | **CUSTOM** |
| `zh-TW` | "多雲" (cloudy), "晴" (clear), "陰" (overcast), "雨" (rain) (CWA) | Same pattern as zh-CN with traditional characters | **CUSTOM** |
| `fil` | "Cloudy skies with scattered rains and thunderstorms" (PAGASA) | **English** — PAGASA uses English for all meteorological text | **TEMPLATE** (English) |

**Architecture decision: 3 custom composers needed (ja, zh-CN, zh-TW)**

European locales (de, es, fr, it, nl, pt-PT, pt-BR) and English-pattern locales (en, fil) use template interpolation with locale-specific connectors, separators, and component order. Russian (ru) uses templates but needs case-inflected label variants (nominative for standalone, instrumental for "with X" constructions).

CJK locales need custom composer modules:

**Japanese (ja):** JMA uses a unique compound expression system with 15 base weather types and three composition operators:
- `時々` (tokidoki) = occasionally: `曇り時々晴れ` = cloudy, occasionally clear
- `一時` (ichiji) = temporarily: `曇り一時雨` = cloudy, temporarily rainy
- `のち` / `後` (nochi) = then/later: `晴れのち曇り` = clear, then cloudy

The composer must construct these compound forms, not just translate individual words. A separate `composers/ja.py` module is required.

**Chinese (zh-CN, zh-TW):** CMA uses space-separated single-term conditions with wind direction + grade. No connectors. Simplified and Traditional Chinese share the same structure but use different character sets. A `composers/zh.py` module handles both with a character-set parameter.

**Russian (ru):** Template-based but labels need multiple grammatical forms:
- Nominative (standalone): `дождь` (rain)
- Instrumental (with): `с дождём` (with rain)
- Genitive (without): `без осадков` (without precipitation)

The Russian locale file must carry these inflected forms as separate keys, not just a single label per weather type.

**QC (Opus) — after Phase 0:** Read both reference documents. Verify every locale has a composition class. Verify the 3 CUSTOM locales (ja, zh-CN, zh-TW) have documented composition rules sufficient to write a composer module. Verify Russian inflected forms are listed.

---

### PHASE 1 — Dashboard Foundations (Shared Utilities)

All subsequent dashboard phases depend on these utilities.

**T1.1 — Create locale-aware number formatting utility**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to create: `src/utils/format-number.ts`
- Files to modify: None (new file only; consumers updated in Phase 2)
- Do: Export `formatNumber(value: number, decimals: number, locale: string): string` using `Intl.NumberFormat`. Export `formatUnit(value: number, unit: string, locale: string): string` that uses `Intl.NumberFormat` with `style: 'unit'` for supported units, and falls back to `formatNumber() + customLabel` for unsupported units (hPa, knots, W/m², rates). Custom labels loaded from a per-locale lookup object (populated from the Phase 0 reference table).
- Files NOT to touch: `src/utils/format.ts` (modified in T1.2, not this task), any component files
- Accept: `formatNumber(1234.5, 1, 'de')` returns `"1.234,5"`. `formatUnit(22.5, 'celsius', 'ja')` returns locale-correct string. `formatUnit(1013.2, 'hectopascal', 'ru')` returns `"1 013,2 гПа"`. Unit tests pass.

**T1.2 — Retrofit `utils/format.ts` to use locale-aware formatting**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify: `src/utils/format.ts`
- Do: Change `formatValue()` to accept a `locale` parameter and delegate to `formatNumber()` from T1.1. Preserve the function signature for backward compatibility (locale defaults to `'en'`). Add deprecation JSDoc pointing callers to pass locale.
- Files NOT to touch: Component files (callers updated in Phase 2)
- Accept: `formatValue(22.5, 1, 'de')` returns `"22,5"`. Existing callers passing no locale get English behavior (no regression). `tsc --noEmit` passes.

**T1.3 — Create locale-aware date formatting wrapper**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to create: `src/utils/format-date.ts`
- Do: Export wrapper functions around `Intl.DateTimeFormat` that enforce: (a) locale parameter is required (no default to 'en-US'), (b) `timeZone` parameter is required (no bare calls). Functions: `formatDayOfWeek(date, locale, tz)`, `formatMonthDay(date, locale, tz)`, `formatTime(date, locale, tz)`, `formatRelativeTime(diffMs, locale)` (using `Intl.RelativeTimeFormat`). Also export `getLocalizedToday(locale)` and `getLocalizedTomorrow(locale)` that return translated strings (delegating to `t()` — these need translation keys added in Phase 2).
- Files NOT to touch: Component files (callers updated in Phase 2)
- Accept: `formatDayOfWeek(date, 'ja', 'Asia/Tokyo')` returns Japanese day name. `formatRelativeTime(-180000, 'de')` returns `"vor 3 Minuten"`. `tsc --noEmit` passes.

**QC (Opus) — after Phase 1:** Run `tsc --noEmit` on dashboard. Review each utility file — verify `Intl.NumberFormat` is used correctly with locale parameter, verify no hardcoded `'en-US'`. Test `formatNumber` with de, ja, ru locales manually via Node REPL. Verify `formatUnit` handles all unsupported units (hPa, knots, W/m²) with custom labels.

---

### PHASE 2 — Dashboard Component Remediation

Split into three sub-phases to keep agent scope manageable.

**T2.1 — Extract hardcoded strings to `t()` calls (batch 1: Now-page cards)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/components/earthquake-card.tsx` — add `useTranslation('now')`, replace ~12 strings: "Recent Earthquake", "Retry", "Loading earthquake data", "No recent earthquakes", "Data unavailable", "Unknown location", time-ago strings (use `formatRelativeTime` from T1.3), aria-label
  - `src/components/lightning-card.tsx` — add `useTranslation('now')`, replace ~12 strings: "Lightning", "No activity", "Loading lightning data", chart aria-label, table caption, "Distance", "/hr", "/24h", "Nearest:", "Time"
  - `src/components/SetupGuard.tsx` — add `useTranslation('common')`, replace "Clear Skies is starting up...", API message, "Retry"
  - `src/components/shared/cookie-consent-banner.tsx` — add `useTranslation('common')`, replace consent text + Accept/Reject/Learn more
  - `src/components/barometer-card.tsx` — replace hardcoded `endpointLabels={['Low', 'High']}` with translated labels
  - `src/components/aqi-card.tsx` — replace hardcoded `aqiCategoryLabel()` fallback strings ("Good", "Moderate", etc.) with `t()` keys. Note: API should provide these in locale, but dashboard needs fallbacks.
  - `src/components/current-conditions-card.tsx` — replace hardcoded "Now" reference line label
  - `src/components/sun-moon-card.tsx` — replace ~3 sr-only template literal strings with `t()` interpolation
- Files to create/modify for translation keys:
  - `public/locales/en/now.json` — add earthquake.*, lightning.*, aqi fallback keys
  - `public/locales/en/common.json` — add setup.*, cookie.*, error.* keys
- Files NOT to touch: Any file not listed above
- Accept: Zero hardcoded English strings in the 8 modified component files. All new strings use `t()`. `tsc --noEmit` passes. English rendering unchanged.

**T2.2 — Extract hardcoded strings to `t()` calls (batch 2: charts + error boundary + UI + layout)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/components/charts/WeatherRangeChart.tsx` — add `useTranslation('charts')`, replace ~8 strings: "High:", "Low:", "Avg:", "Outside Temperature", "Date", sr-only table headers, chart aria-label
  - `src/components/charts/WindRoseChart.tsx` — add `useTranslation('charts')`, replace ~15 strings: "Wind Rose", "Calm", "Calm (all directions)", "Direction", sr-only captions, all aria-labels
  - `src/components/charts/HaysChart.tsx` — add `useTranslation('charts')`, replace ~10 strings: "High:", "Low:", "peak", "Value range", "Period", sr-only captions
  - `src/components/charts/ChartGauge.tsx` — add `useTranslation('charts')`, replace "Gauge:" fallback prefix, sr-only description
  - `src/components/charts/ConfigDrivenGroup.tsx` — replace ~3 strings: 'Value' + ' High'/' Low' concatenation, "Chart fullscreen view"
  - `src/components/charts/ConfigDrivenChart.tsx` — replace 'Chart' fallback title
  - `src/components/error-boundary.tsx` — wrap with functional `ErrorFallback` component that uses `useTranslation('common')`, replace "Something went wrong" + "Reload page". Use `t('key', 'Hardcoded fallback')` for safety.
  - `src/components/ui/chart-fullscreen.tsx` — replace "Chart fullscreen view" default label
  - `src/components/ui/scroll-fade.tsx` — replace "Scrollable content" default aria-label
  - `src/components/layout/footer.tsx` — replace "Powered by Clear Skies" alt text
  - `src/components/layout/now-hero-card.tsx` — add `useTranslation('common')`, replace "My Weather Station" fallback
  - `src/components/shared/radar-map.tsx` — replace "Weather Alert" fallback
- Files to create/modify for translation keys:
  - `public/locales/en/charts.json` — add tooltip.*, windRose.*, haysChart.*, gauge.* keys
  - `public/locales/en/common.json` — add error.*, aria.*, layout.* keys
- Files NOT to touch: Any file not listed above
- Accept: Zero hardcoded English strings in modified files. `tsc --noEmit` passes.

**T2.3 — Extract hardcoded strings to `t()` calls (batch 3: forecast + almanac + reports + hooks + lib)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/components/forecast/HourlyStrip.tsx` — add `useTranslation('forecast')`, replace aria-labels
  - `src/components/forecast/DailyColumns.tsx` — replace "Today"/"Tomorrow"/"Tmrw" with `t()` keys
  - `src/components/almanac/LunarEclipseCard.tsx` — replace ~15 strings: visibility labels ("Visible All Night", "Mostly Visible", etc.), type labels ("Total", "Partial", "Penumbral"), title templates
  - `src/components/almanac/MonthlyAveragesCard.tsx` — replace hardcoded month abbreviation array ('Jan'-'Dec') with `Intl.DateTimeFormat` month formatting using active locale
  - `src/components/almanac/SunMoonDetailCard.tsx` — replace "Today" fallback, "Waxing"/"Waning" abbreviation strings
  - `src/components/almanac/MeteorShowerCard.tsx` — verify all display strings use `t()` (already has useTranslation)
  - `src/routes/reports.tsx` — replace ~15 CSV header strings ("Day", "Mean Temp", "High Temp", etc.)
  - `src/routes/not-found.tsx` — move pun array to `common.json` translation keys
  - `src/utils/uv.ts` — ensure callers use `labelKey` field instead of hardcoded `label` fallbacks
  - `src/hooks/useWeatherData.ts` — replace "Harvest Moon", "Blue Moon", "Supermoon" with `t()` keys
  - `src/lib/card-metadata.ts` — replace ~14 hardcoded `displayName` strings with translation keys
- Files to create/modify for translation keys:
  - `public/locales/en/forecast.json` — add today, tomorrow, tmrw, hourly.ariaLabel keys
  - `public/locales/en/almanac.json` — add eclipse.*, visibility.*, months.* keys
  - `public/locales/en/reports.json` — add csvHeaders.* keys
  - `public/locales/en/common.json` — add notFound.puns.*, moonNames.* keys
- Files NOT to touch: Any file not listed above
- Accept: Zero hardcoded English strings in modified files. `tsc --noEmit` passes.

**T2.4 — Fix hardcoded locale arguments in all date/time formatting**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify (replace `'en-US'`/`'default'` with `i18n.language`):
  - `src/routes/records.tsx` — 1 site ('en-US')
  - `src/components/sun-moon-card.tsx` — 1 site ('en-US')
  - `src/components/uv-index-card.tsx` — 2 sites ('en-US')
  - `src/components/forecast/DailyColumns.tsx` — 4 sites ('en-US')
  - `src/components/forecast/HourlyStrip.tsx` — 1 site ('en-US')
  - `src/components/forecast/ForecastDiscussionCard.tsx` — 1 site ('en-US')
  - `src/components/almanac/MeteorShowerCard.tsx` — 6 sites ('en-US')
  - `src/components/almanac/LunarEclipseCard.tsx` — uses `locale` var (verify it's `i18n.language`)
  - `src/components/almanac/SunMoonDetailCard.tsx` — 2 sites ('en-US')
  - `src/components/almanac/PlanetTimelineCard.tsx` — 3 sites ('en-US', plus fallback at L852)
  - `src/components/charts/WeatherRangeChart.tsx` — 3 sites ('default')
  - `src/components/charts/HaysChart.tsx` — 1 site ('en-US') + 3 sites ('default')
  - `src/components/charts/ConfigDrivenGroup.tsx` — verify existing sites at L128, L281, L434; some already use `i18n.language` (L995)
- Note: `'en-CA'` in `alert-banner.tsx` L97 and `useWeatherData.ts` L737 produce `YYYY-MM-DD` for date comparison (not display) — these are acceptable and do NOT need changing.
- Do: For each file, add `useTranslation()` import if not present, destructure `i18n`, replace hardcoded locale string with `i18n.language`. Where possible, use the wrapper functions from T1.3 instead of raw `Intl.DateTimeFormat`.
- Files NOT to touch: `'en-CA'` date comparison sites (alert-banner.tsx, useWeatherData.ts)
- Accept: `grep -rn "'en-US'" src/ --include='*.tsx' --include='*.ts' | grep -v node_modules | grep -v test | grep -v mock` returns ZERO results. `grep -rn "'default'" src/ --include='*.tsx' --include='*.ts' | grep -v node_modules | grep -v test | grep -v mock | grep -i 'toLocale\|DateTimeFormat'` returns ZERO results. `tsc --noEmit` passes.

**T2.5 — Replace display-facing `.toFixed()` with locale-aware formatting**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify (14 files, ~50 call sites):
  - `src/utils/format.ts` — central `formatValue()` (1 site — this cascades to many consumers)
  - `src/components/WindCompassCard.tsx` — 2 sites
  - `src/components/current-conditions-card.tsx` — 3 sites
  - `src/components/earthquake-card.tsx` — 4 sites
  - `src/components/lightning-card.tsx` — 3 sites
  - `src/components/todays-highlights-card.tsx` — 1 site
  - `src/components/charts/ChartGauge.tsx` — 1 site
  - `src/components/charts/ConfigDrivenChart.tsx` — 3 sites
  - `src/components/charts/WeatherRangeChart.tsx` — 6 sites
  - `src/components/charts/WindRoseChart.tsx` — 6+ sites (display only)
  - `src/components/charts/HaysChart.tsx` — 8+ sites (display only)
  - `src/components/forecast/DailyColumns.tsx` — 2 sites
  - `src/components/almanac/SunMoonDetailCard.tsx` — 6 sites
- Do: Import `formatNumber` from T1.1, pass `i18n.language` as locale. Leave SVG path coordinate `.toFixed()` calls untouched (these are not display text).
- Files NOT to touch: SVG geometry `.toFixed()` in WindRoseChart lines 102-105, HaysChart lines 95-98
- Accept: `grep -rn '\.toFixed(' src/components/ src/utils/ --include='*.tsx' --include='*.ts' | grep -v test | grep -v mock` returns ONLY SVG coordinate usages (WindRoseChart/HaysChart path `d` attributes). `tsc --noEmit` passes.

**T2.6 — Remove visitor locale detection; use operator's `defaultLocale` only**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/i18n/index.ts` — remove `i18next-browser-languagedetector` plugin. The dashboard's locale is set to the operator's `defaultLocale` from station metadata (fetched via `/api/v1/station`), not from the browser's language preferences or a visitor-facing locale picker. On boot, i18next initializes with `lng: 'en'` (safe default), then switches to `defaultLocale` once station metadata loads.
  - `src/App.tsx` (or wherever station metadata loads) — after fetching station metadata, call `i18n.changeLanguage(stationMetadata.defaultLocale)` to switch the dashboard to the operator's chosen locale.
  - Remove any visitor-facing locale picker / language switcher if one exists in the UI.
  - Remove `?lang=` query parameter detection if it exists (visitors don't get to override the operator's choice).
- Files NOT to touch: `src/i18n/use-locale-sync.ts` (still needed — it syncs `<html lang>` when the locale changes at boot)
- Accept: Dashboard always renders in the operator's `defaultLocale`. No browser language detection. No `?lang=` override. No visitor locale picker. Changing the browser language has no effect on the dashboard.

**T2.7 — Add `title` attributes alongside `truncate` classes**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/components/layout/page-header-card.tsx` — add `title={title}` to heading with `truncate`
  - `src/components/shared/alert-banner.tsx` — add `title={alert.event}` to event name, `title={detailLine}` to detail, `title={summaryText}` to summary
- Accept: Truncated text has tooltip on hover showing full text.

**QC (Opus) — after Phase 2:** Run all grep-checkable FAIL conditions from `rules/coding.md` §6.4:
1. `grep -rn "'en-US'\|'en-CA'" src/ --include='*.tsx' --include='*.ts' | grep -v test | grep -v mock` → 0 results
2. `grep -rn '\.toFixed(' src/components/ --include='*.tsx' | grep -v test` → only SVG coordinate usages
3. Spot-check 3 component files (earthquake-card, WindRoseChart, DailyColumns) — open file, verify every visible string uses `t()`, verify locale param passed to all `Intl.*` calls.
4. `tsc --noEmit` passes. `npm run build` succeeds.
5. Deploy to weather-dev. Switch locale to `de` in the dashboard. Verify: decimal commas appear in numeric displays, German day names in forecast, chart tooltips show German number formatting.

---

### PHASE 3 — API Locale Infrastructure

**T3.1 — Add babel dependency and create locale file structure**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to create:
  - `weewx_clearskies_api/locales/en.json` — all translatable strings (weather text labels, Beaufort, AQI, records, unit labels, composition templates)
  - `weewx_clearskies_api/locales/` — empty JSON files for 12 other locales (populated in Phase 6)
  - `weewx_clearskies_api/i18n.py` — locale loading, resolution, string lookup
- Files to modify:
  - `requirements.txt` or `pyproject.toml` — add `babel` dependency
  - `weewx_clearskies_api/__main__.py` — load locale files at startup (between steps 10 and 11)
- Do: `i18n.py` exports: `load_locales(locale_dir)`, `t(key, locale) -> str`, `format_number(value, decimals, locale) -> str` (delegates to `babel.numbers.format_decimal`). The API uses the operator's `defaultLocale` from `api.conf` as its single active locale — no per-request resolution.
- Files NOT to touch: Any endpoint files, any provider files
- Accept: `from weewx_clearskies_api.i18n import t, format_number; t("beaufort.0", "de")` returns `"Windstille"`. `format_number(22.5, 1, "de")` returns `"22,5"`. `ruff check` passes.

**T3.2 — Thread locale through unit labels and `format_value()`**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to modify:
  - `weewx_clearskies_api/units/labels.py` — modify `get_label()` to accept `locale` param, check locale file first, then operator override, then default
  - `weewx_clearskies_api/units/labels.py` — modify `format_value()` to accept `locale` param, use `babel.numbers.format_decimal()` instead of `%` formatting
  - `weewx_clearskies_api/units/transformer.py` — pass locale through `UnitTransformer.convert()` calls
  - `weewx_clearskies_api/units/response_conversion.py` — accept locale param, pass to label/format calls
- Files NOT to touch: `units/conversion.py` (math only, no display), `units/groups.py`, `units/derived.py` (modified in T3.3)
- Accept: API response `ConvertedValue.label` reflects locale-appropriate unit label. `ConvertedValue.formatted` uses locale-correct decimal separator. `ruff check` + `mypy` pass.

**T3.3 — Translate Beaufort labels, AQI categories, record labels**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to modify:
  - `weewx_clearskies_api/units/derived.py` — `beaufort()` returns label from locale file via `t("beaufort.N", locale)` instead of hardcoded English
  - `weewx_clearskies_api/providers/aqi/_units.py` — `aqi_category()` returns label from locale file via `t("aqi.category_key", locale)` instead of hardcoded English
  - `weewx_clearskies_api/services/records.py` — `_RecordSpec.label` resolves from locale file via `t("records.key", locale)` instead of hardcoded English
  - `weewx_clearskies_api/services/almanac.py` — moon traditional names resolve from locale file; phase names stay as kebab-case identifiers (dashboard translates)
- Files NOT to touch: Provider modules (they don't produce display text), endpoint handlers (locale threading comes from middleware)
- Accept: `GET /api/v1/current` with `Accept-Language: de` returns Beaufort label in German. `GET /api/v1/records` returns German record labels. `ruff check` passes.

**T3.4 — Translate conditions text engine (labels AND sentence composition)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to modify:
  - `weewx_clearskies_api/sse/temperature_comfort.py` — tier labels resolve from locale file
  - `weewx_clearskies_api/sse/sky_condition.py` — sky labels resolve from locale file
  - `weewx_clearskies_api/sse/conditions_text.py` — `compose()` replaced with locale-aware composition (see below)
  - `weewx_clearskies_api/sse/enrichment/weather_text.py` — thread locale through to composer; standard/verbose templates become locale-aware
  - `weewx_clearskies_api/providers/forecast/openmeteo.py` — `_WMO_CODE_TO_TEXT` lookup resolves from locale file
- Do: Two distinct problems:

  **Problem 1 — Word translation:** Each module's hardcoded English labels become keys that resolve through `t()`. Straightforward lookup.

  **Problem 2 — Sentence structure:** The English `compose()` function uses English grammar: `"{temp}, {sky}, with {precip}"`. This pattern does NOT work across languages. Different languages have fundamentally different:
  - **Connectors:** English "and"/"with" → German "und"/"mit" → French "et"/"avec" → Japanese particles (で、と、の) → Russian "и"/"с" (+ case changes)
  - **Word order:** English puts temperature first, sky second. Japanese puts sky condition first, temperature as modifier. Chinese uses similar order to Japanese.
  - **Punctuation:** English uses commas. Japanese uses `、` (tōten). Chinese uses `，`.  CJK languages don't use spaces between elements.
  - **Compound forms:** Japanese weather services use compound expressions like `曇り時々晴れ` (cloudy-sometimes-clear) not "Cloudy, with periods of clearing"
  - **No connectors at all:** CJK languages often just juxtapose conditions with punctuation, no explicit "and"/"with"

  **Solution: Per-locale composer functions, not templates.** The locale file defines not just word translations but a composition strategy. For European languages (de, es, fr, it, nl, pt-PT, pt-BR, ru), template interpolation with locale-specific connectors and word order is sufficient. For CJK languages (ja, zh-CN, zh-TW), a custom composer function per locale produces the correct compound expression pattern. For Filipino (fil), verify whether English-style composition or a Tagalog-native pattern is appropriate.

  The locale file structure for composition:
  ```json
  {
    "composition": {
      "pattern": "template",
      "separator": "、",
      "connector_final": "で",
      "order": ["sky", "temperature", "wind", "precipitation"]
    }
  }
  ```
  For CJK locales where templates are insufficient:
  ```json
  {
    "composition": {
      "pattern": "custom",
      "composer": "ja"
    }
  }
  ```
  When `pattern` is `"custom"`, the API loads a locale-specific composer module (`weewx_clearskies_api/locales/composers/ja.py`) that implements the same interface as `compose()` but with language-native logic.

  **Phase 0 T0.2 must verify** which locales need custom composers vs. template interpolation. This is the highest-risk research item.

- Files NOT to touch: The classifier logic itself (thresholds, hysteresis, ring buffer) — only the label output and composition
- Accept: SSE events with locale=de produce German weatherText with correct German sentence structure. REST `/current` with `Accept-Language: ja` produces Japanese conditions text using Japanese compound expression patterns (not English word order with Japanese words substituted). No change to classification logic. `ruff check` + `mypy` pass.

**T3.5 — Thread operator's `defaultLocale` through all API responses**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to modify:
  - `weewx_clearskies_api/__main__.py` — at startup, after loading station settings, store the operator's `defaultLocale` as the API's active locale. Pass it to `UnitTransformer`, conditions text engine, and all response builders.
  - All REST endpoint handlers — use the stored `defaultLocale` (not per-request header parsing) when calling response builders
  - SSE enrichment pipeline — use the stored `defaultLocale`
- Do: The operator's `defaultLocale` (from `api.conf [station] default_locale`) is the single locale for all API output. No per-request locale resolution. No `Accept-Language` parsing. Every response uses the same locale. When the operator changes `defaultLocale` via the wizard/admin, the API restarts and picks up the new value.
- Accept: API response fields (`weatherText`, `beaufort.label`, `category`, record labels, `formatted`, unit labels) all use the operator's configured locale. `ruff check` passes.

**QC (Opus) — after Phase 3:** 
1. `ruff check` + `mypy` pass on API repo.
2. Set `default_locale = "de"` in `api.conf` on weewx. Restart API. Wait 2 min for cache warm.
3. `curl https://weewx.shaneburkhardt.com:8765/api/v1/current` — verify: `weatherText` in German, `beaufort.label` in German, unit labels locale-correct, decimal commas in `formatted` fields.
4. `curl https://weewx.shaneburkhardt.com:8765/api/v1/records?period=alltime` — verify: record labels in German.
5. Set `default_locale = "en"` back. Restart API. Verify responses return to English.
6. No `Accept-Language` header parsing exists — the locale comes from operator config only.

---

### PHASE 4 — CJK Fonts + Cyrillic

**T4.1 — Add on-demand CJK font loading and Cyrillic subsets**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify:
  - `src/index.css` — add Cyrillic subset imports for Manrope, Outfit, Lexend. Update font-family stacks to include Noto Sans JP/SC/TC.
  - `package.json` — add `@fontsource/noto-sans-jp`, `@fontsource/noto-sans-sc`, `@fontsource/noto-sans-tc`
- Files to create:
  - `src/i18n/font-loader.ts` — dynamic import of CJK font CSS on locale change. Only loads when locale is ja/zh-CN/zh-TW. Caches after first load.
- Files to modify:
  - `src/i18n/use-locale-sync.ts` — call `loadFontsForLocale(locale)` from font-loader on locale change
- Accept: Switching to `ja` locale loads Noto Sans JP (visible in Network tab). Russian text renders in Manrope Cyrillic (not system fallback). `npm run build` succeeds. Bundle size for non-CJK locales unchanged.

**QC (Opus) — after Phase 4:** Deploy to weather-dev. Switch locale to `ja` — verify Japanese text renders in Noto Sans JP (compare against system font). Switch to `ru` — verify Russian text renders in Manrope (not system sans-serif). Check Network tab — CJK font files only load when CJK locale is active.

---

### PHASE 5 — Wizard & Admin i18n

**T5.1 — Add babel i18n infrastructure and language selection step 1**
- Owner: `clearskies-dashboard-dev` (Sonnet) — the stack repo is on weather-dev alongside the dashboard; use dashboard-dev agent for all stack work since no dedicated stack agent type exists
- **Important: The config UI uses FastAPI + Jinja2, NOT Flask.** `flask-babel` will not work. Use `babel` directly with a custom Jinja2 integration:
  1. Add `babel` to `pyproject.toml` dependencies
  2. Create `weewx_clearskies_config/i18n.py` that loads JSON translation files (same pattern as the API's `i18n.py` from T3.1) and exports a `translate(key, locale)` function
  3. Register `_()` as a Jinja2 global in the FastAPI app's `Jinja2Templates` environment: `templates.env.globals['_'] = lambda msg: translate(msg, get_current_locale())`
  4. `get_current_locale()` reads from: (a) session/cookie `clearskies-wizard-locale`, (b) operator's `default_locale` from `api.conf`, (c) `Accept-Language` header, (d) `"en"` fallback
- Files to modify:
  - `pyproject.toml` — add `babel` dependency
  - `weewx_clearskies_config/app.py` — register `_()` global on Jinja2 environment, add locale middleware
  - `weewx_clearskies_config/wizard/routes.py` — add new step 0 (language selection), bump all subsequent step numbers, store selected locale in cookie/session
- Files to create:
  - `weewx_clearskies_config/i18n.py` — locale loading, `translate()`, `get_current_locale()`
  - `weewx_clearskies_config/templates/wizard/step_language.html` — 13 locales shown in native script, pre-selected from browser Accept-Language
  - `weewx_clearskies_config/translations/en.json` — all wizard+admin strings (initial English source file)
- Accept: Wizard opens to language selection. Selecting "日本語" stores locale in session and re-renders in Japanese (once translations exist). `_("Station display name")` in a Jinja2 template resolves correctly. Language choice persists across steps and page reloads.

**T5.2 — Wrap all wizard templates with `_()`**
- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo work
- Files to modify: All 24 wizard templates + `macros/form_fields.html` — wrap every user-visible string with `{{ _("...") }}`
- Do: Systematic find-and-replace. Every `<h2>`, `<label>`, `<small>`, `<button>`, `<legend>`, `placeholder=`, `aria-label=`, and prose `<p>` content wrapped with `_()`.
- Files NOT to touch: Admin templates (T5.3), route handlers (T5.4)
- Accept: All wizard templates render identically to current English (strings resolve through `_()` to English). No Jinja2 template errors.

**T5.3 — Wrap all admin templates with `_()`**
- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo work
- Files to modify: All 9 admin templates — same wrapping pattern as T5.2
- Accept: All admin templates render identically to current English.

**T5.4 — Wrap route handler error/status messages with `_()`**
- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo work
- Files to modify: `wizard/routes.py`, `admin/routes.py` — wrap all error messages, flash messages, validation text with `_()`
- Accept: All user-visible strings in route handlers use `_()`. Python compiles clean.

**T5.5 — Wrap ConfigField registry strings with translation keys**
- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo work
- Files to modify: All files under `weewx_clearskies_config/registry/` that define `ConfigField` objects — wrap `label`, `help_text`, `wizard_help`, `placeholder`, and `options[].label` values with translation keys. The `render_field` macro in `macros/form_fields.html` must pass these through `_()`.
- Do: Audit the registry directory first to count all ConfigField string fields. Modify the `render_field` macro to wrap `field.label`, `field.help_text`, etc. with `{{ _(field.label) }}`. Then add all registry strings to the English translation source file.
- Accept: Every ConfigField-rendered label, help text, and option label resolves through `_()`. Templates render identically in English.

**QC (Opus) — after Phase 5:** Restart config UI on weather-dev. Walk full wizard flow — verify step 1 is language selection, verify all subsequent steps render in English (translations come in Phase 6). Run grep for unwrapped strings across templates. Specifically verify ConfigField-rendered sections (TLS, webcam, feature settings) render correctly. Template rendering produces no Jinja2 errors.

---

### PHASE 6 — Translation Content

**T6.1 — Populate dashboard locale files (12 non-English locales)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files to modify: All new translation keys added in Phase 2, across all 12 non-English locale directories in `public/locales/`
- Do: For each new key added to `en/*.json` in Phase 2, add the translated value in all 12 other locales. Group by locale family: European (de, es, fr, it, nl, pt-PT, pt-BR, ru), CJK (ja, zh-CN, zh-TW), other (fil).
- Accept: `JSON.parse()` succeeds on every locale file. Spot-check 3 locales (de, ja, pt-BR): every new key has a non-empty value.

**T6.2 — Populate API locale files (12 non-English locales)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to modify: `weewx_clearskies_api/locales/{de,es,fr,it,nl,pt-BR,pt-PT,ru,ja,zh-CN,zh-TW,fil}.json`
- Do: Translate all ~100 strings per locale: temperature tiers (12), moisture modifiers (5+), sky conditions (7), precipitation labels (10), connectors, composition templates, Beaufort labels (13), AQI categories (6), record labels (~20), moon traditional names (12+), unit labels (non-SI only, per Phase 0 reference table).
- Accept: JSON parse succeeds on every locale file. Spot-check de, ja, ru: every key has a non-empty value. Composition templates are grammatically correct.

**T6.3 — Populate wizard translation files (12 non-English locales)**
- Owner: `clearskies-dashboard-dev` (Sonnet) — stack repo work
- Files to modify: `weewx_clearskies_config/translations/{de,es,fr,...}.json` (or .po)
- Do: Translate all ~800 wizard + admin strings (670 template + 113 route handler + ConfigField registry strings). Technical terms (database driver names, TLS, API keys) stay in English with translated context.
- Accept: Wizard renders in 3+ non-English locales without Jinja2 errors. Spot-check de, ja, pt-BR.

**QC (Opus) — after Phase 6:** Spot-check 4 locales (de, ja, ru, pt-BR) across all three codebases:
1. Dashboard: switch locale in UI, walk Now page → Forecast → Charts → Records. Verify labels, numbers, dates all localized.
2. API: `curl -H "Accept-Language: ja" /api/v1/current` — verify Japanese weatherText, Beaufort, units.
3. Wizard: access wizard in de locale — verify all steps render in German.

---

### PHASE 7 — Deploy & End-to-End Verification

**T7.1 — Deploy all three codebases**
- Owner: Coordinator (Opus)
- Do: Dashboard `npm run build` + `scripts/redeploy-weather-dev.sh`. Wizard `systemctl restart weewx-clearskies-config`. API `systemctl restart weewx-clearskies-api` (wait 2 min).
- Accept: All three services running. No startup errors in logs.

**T7.2 — End-to-end locale test**
- Owner: Coordinator (Opus)
- Do: For each of 4 test locales (en, de, ja, pt-BR):
  1. Set `default_locale` to the test locale via wizard (or directly in `api.conf` + restart API + redeploy dashboard)
  2. Open dashboard — verify it renders in the target locale WITHOUT any visitor action
  3. Walk all 9 pages: Now, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal
  4. Verify: all headings/labels/buttons in target locale, numbers use correct decimal separator, dates use locale day/month names, unit labels correct, charts tooltips localized, aria-labels in target locale
  5. Verify API responses carry localized `weatherText`, Beaufort labels, AQI categories, record labels, unit labels, number formatting
  6. Verify changing browser language has NO effect on the dashboard display
  7. Access wizard — verify language step shows current locale pre-selected, all subsequent steps in target locale
- Accept: All 4 locales render correctly across dashboard + wizard. No English strings visible (except provider pass-through: alert text, earthquake places). No visitor locale override mechanism exists.

**T7.3 — Update governing documents**
- Owner: Coordinator (Opus)
- Do: Update DASHBOARD-MANUAL.md §3 to reflect: CJK on-demand font loading (ban removed), Cyrillic subset imports, API locale resolution via Accept-Language, sentence composition architecture. Update ARCHITECTURE.md if any service-level changes (new locale middleware). Update API-MANUAL.md §6 to document locale-aware `format_value()` and `get_label()`.
- Accept: All governing documents reflect the implemented behavior. No doc-code drift.

**T7.4 — Accessibility re-verification**
- Owner: Coordinator (Opus)
- Do: Run `axe-core` on Now page and Legal page in `de` and `ja` locales. Verify `<html lang>` attribute matches active locale. Keyboard-navigate the wizard language selection step.
- Accept: axe-core 0 violations. `<html lang>` correct. Wizard language step keyboard-accessible.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 Unit label verification | `clearskies-docs-author` | Sonnet | Spot-check 4 locales against cited sources | After Phase 0 |
| 0 | T0.2 Composition templates | `clearskies-docs-author` | Sonnet | Grammar plausibility check | After Phase 0 |
| 1 | T1.1 formatNumber utility | `clearskies-dashboard-dev` | Sonnet | Manual test in Node REPL | After Phase 1 |
| 1 | T1.2 Retrofit format.ts | `clearskies-dashboard-dev` | Sonnet | `tsc --noEmit` + regression check | After Phase 1 |
| 1 | T1.3 formatDate utility | `clearskies-dashboard-dev` | Sonnet | Manual test in Node REPL | After Phase 1 |
| 2 | T2.1 String extraction batch 1 | `clearskies-dashboard-dev` | Sonnet | Spot-check 2 files | After T2.1 |
| 2 | T2.2 String extraction batch 2 | `clearskies-dashboard-dev` | Sonnet | Spot-check 2 files | After T2.2 |
| 2 | T2.3 String extraction batch 3 | `clearskies-dashboard-dev` | Sonnet | Spot-check 2 files | After T2.3 |
| 2 | T2.4 Fix hardcoded locales | `clearskies-dashboard-dev` | Sonnet | grep verification (0 results) | After T2.4 |
| 2 | T2.5 Fix .toFixed() | `clearskies-dashboard-dev` | Sonnet | grep verification | After T2.5 |
| 2 | T2.6 Remove visitor locale detection | `clearskies-dashboard-dev` | Sonnet | Browser lang change has no effect | After T2.6 |
| 2 | T2.7 Truncation titles | `clearskies-dashboard-dev` | Sonnet | Visual verify | After T2.7 |
| 3 | T3.1 API locale infrastructure | `clearskies-api-dev` | Sonnet | Unit test + ruff | After T3.1 |
| 3 | T3.2 Unit labels + format_value | `clearskies-api-dev` | Sonnet | curl test | After T3.2 |
| 3 | T3.3 Beaufort/AQI/records | `clearskies-api-dev` | Sonnet | curl test | After T3.3 |
| 3 | T3.4 Conditions text engine | `clearskies-api-dev` | Sonnet | curl + SSE test | After T3.4 |
| 3 | T3.5 Thread operator locale through API | `clearskies-api-dev` | Sonnet | curl test with locale set in api.conf | After T3.5 |
| 4 | T4.1 CJK + Cyrillic fonts | `clearskies-dashboard-dev` | Sonnet | Network tab verify | After Phase 4 |
| 5 | T5.1 Wizard i18n infrastructure + step 1 | `clearskies-dashboard-dev` | Sonnet | Wizard renders, step 1 works | After T5.1 |
| 5 | T5.2 Wizard template wrapping | `clearskies-dashboard-dev` | Sonnet | grep for unwrapped strings | After T5.2 |
| 5 | T5.3 Admin template wrapping | `clearskies-dashboard-dev` | Sonnet | grep for unwrapped strings | After T5.3 |
| 5 | T5.4 Route handler messages | `clearskies-dashboard-dev` | Sonnet | Python compile check | After T5.4 |
| 5 | T5.5 ConfigField registry | `clearskies-dashboard-dev` | Sonnet | Rendered field labels through `_()` | After T5.5 |
| 6 | T6.1 Dashboard translations | `clearskies-dashboard-dev` | Sonnet | JSON parse + spot-check 3 locales | After T6.1 |
| 6 | T6.2 API translations | `clearskies-api-dev` | Sonnet | JSON parse + spot-check 3 locales | After T6.2 |
| 6 | T6.3 Wizard translations | `clearskies-dashboard-dev` | Sonnet | Render in 3 locales | After T6.3 |
| 7 | T7.1-T7.4 Deploy + docs + E2E | Coordinator | Opus | Full walkthrough in 4 locales + Gate 5 completeness table | After deploy |

**Sequencing:**
- Phase 0 (research) → Phase 1 (dashboard foundations) → Phase 2 (dashboard remediation)
- Phase 3 (API) can run in parallel with Phase 2 after Phase 0 completes
- Phase 4 (fonts) can run in parallel with Phase 2/3
- Phase 5 (wizard) can run in parallel with Phase 2/3/4
- Phase 6 (translations) depends on Phases 2, 3, 5 completing (all English keys finalized)
- Phase 7 (deploy) depends on Phase 6

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- Dashboard: `tsc --noEmit` 0 errors. `npm run build` clean.
- API: `ruff check` + `mypy` no introduced errors.
- Wizard: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.

### Gate 2 — i18n Compliance (per phase, grep-checkable)
Per `rules/coding.md` §6.4:
- Dashboard: zero `'en-US'`/`'en-CA'` in source, zero display-facing `.toFixed()`, zero hardcoded English in JSX
- API: zero hardcoded English in response fields
- Wizard: zero unwrapped strings in templates

### Gate 3 — Scientific Accuracy (after Phase 0 + Phase 6)
- Unit labels match verified national met service conventions
- Decimal separators match CLDR/BIPM standards per locale
- SI unit symbols unchanged across locales (per BIPM)
- Composition templates grammatically correct per locale

### Gate 4 — Accessibility (after Phase 7)
- `<html lang>` matches active locale on every page
- All aria-labels translated
- axe-core 0 violations in non-English locales
- CJK text renders in correct web font (not system fallback)

### Gate 5 — Plan Completeness (after Phase 7, before reporting done)

Walk every task in this plan. For each T-number, record one of:
- **DONE** — cite the commit hash where it landed
- **DEFERRED** — cite where tracked (must be in a parking lot or future-phase entry, not implicit)
- **MISSING** — STOP. Do not report the plan complete. Remediate or defer with user approval.

| Task | Status | Commit / Note |
|------|--------|---------------|
| T0.1 | | |
| T0.2 | | |
| T1.1 | | |
| T1.2 | | |
| T1.3 | | |
| T2.1 | | |
| T2.2 | | |
| T2.3 | | |
| T2.4 | | |
| T2.5 | | |
| T2.6 | | |
| T2.7 | | |
| T3.1 | | |
| T3.2 | | |
| T3.3 | | |
| T3.4 | | |
| T3.5 | | |
| T4.1 | | |
| T5.1 | | |
| T5.2 | | |
| T5.3 | | |
| T5.4 | | |
| T5.5 | | |
| T6.1 | | |
| T6.2 | | |
| T6.3 | | |
| T7.1 | | |
| T7.2 | | |
| T7.3 | | |
| T7.4 | | |

This table is filled in by the coordinator at close. Every row must have a status. Zero MISSING rows before reporting complete.

### Gate 6 — Regression (after Phase 7)
- English rendering unchanged from pre-i18n state (same visible text, same layout)
- No skeleton flash during refetches (stale-while-revalidate preserved)
- SSE events still deliver data correctly
- Charts still render correctly (axis labels, tooltips, legends)

---

## 5. QA — Verifying QC Was Completed Correctly

After all phases complete and the coordinator reports done, an independent auditor verifies the QC was actually performed and the results are accurate.

**QA-1: Mechanical grep audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Run ALL grep-checkable FAIL conditions from `rules/coding.md` §6.4 independently. Report any violations the coordinator missed.

**QA-2: Cross-locale rendering audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: For 3 locales (de, ja, ru), screenshot the Now page, Forecast page, and Records page. Compare against English screenshots. Flag: any English text visible that should be translated, any layout breakage from longer translated strings, any number formatting violations (wrong decimal separator).

**QA-3: API response audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: For 3 locales, `curl` the `/current`, `/records`, `/forecast/daily` endpoints with `Accept-Language` header. Verify every human-readable string field is in the target locale. Verify `formatted` fields use locale-correct decimal separator. Verify unit labels match the Phase 0 reference table.

**QA-4: Wizard audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Walk the wizard in `ja` locale from step 1 (language) through step 5 (units). Verify every visible string is Japanese. Flag any unwrapped English.

**QA-5: Scientific accuracy audit**
- Owner: `clearskies-auditor` (Sonnet)
- Do: For `ja` and `de` locales, compare unit labels in API responses against the Phase 0 verified reference table. Flag any deviation.

**QA-6: Plan completeness verification**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Read the Gate 5 completeness table filled in by the coordinator. For every row marked DONE, verify the cited commit hash exists and contains changes to the files listed in that task. For every row marked DEFERRED, verify the deferral is tracked in a parking lot or future-phase entry. Flag any row where the commit doesn't match the task scope, or where a deferral has no tracking entry.

**QA-7: Operator locale controls everything**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Verify no visitor-facing locale picker exists in the dashboard. Verify no `Accept-Language` header is sent from the dashboard to the API. Verify the dashboard reads `defaultLocale` from station metadata and uses it as its i18n locale. Verify changing the browser language has NO effect on the dashboard's display language. Verify the API has no `Accept-Language` parsing middleware. Flag any mechanism that allows visitors to override the operator's language choice.

---

## 6. Self-Audit

**Risk: Translation accuracy.** Machine-generated translations may contain errors, especially for scientific/meteorological terminology. Mitigation: Phase 0 establishes verified reference table. Phase 6 translations are spot-checked against the reference table. QA-5 independently verifies.

**Risk: `Intl.NumberFormat` browser support.** `style: 'unit'` requires Chrome 77+, Firefox 78+, Safari 14.1+. Our browser support matrix (DASHBOARD-MANUAL.md §4) targets Chrome 110+, Firefox 110+, Safari 16.4+ — all well within support range.

**Risk: API performance.** Locale file loading at startup adds negligible overhead (13 small JSON files). The active locale is resolved once at startup (operator's `defaultLocale`), not per-request — zero per-request overhead. `babel.numbers.format_decimal` is slower than `%` formatting but still sub-millisecond.

**Risk: Conditions text composition requires 3 custom composer modules.** Research (§1D) confirmed that Japanese, Simplified Chinese, and Traditional Chinese need custom composer modules — they cannot use template interpolation. Japanese uses JMA's compound expression system (時々/一時/のち operators), Chinese uses space-separated single-term conditions with wind grade notation. Russian uses templates but needs case-inflected label variants (nominative/instrumental/genitive). This is the most code-heavy part of Phase 3 T3.4. The architecture is decided; the risk is in the correctness of the composer output — native speaker review of the composer output is recommended but out of scope for this plan.

**Risk: Font loading performance.** CJK fonts are 2-4 MB per locale. Mitigation: on-demand loading only when CJK locale is active. Cache headers ensure single download. Non-CJK users see zero impact.

**Risk: Wizard step renumbering.** Adding language as step 1 bumps all step numbers. Existing progress state (`wizard_progress_*.json`) references step numbers. Mitigation: clear stale progress state on wizard version bump.
