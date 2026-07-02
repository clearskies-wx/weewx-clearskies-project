# I18N Compliance Audit Brief

**Date:** 2026-07-01
**Scope:** `weewx-clearskies-dashboard` — all `.tsx`/`.ts` source files under `src/`
**Repo path:** `/home/ubuntu/repos/weewx-clearskies-dashboard/` (weather-dev)
**Governing doc:** DASHBOARD-MANUAL.md §3 (Internationalization)

---

## Executive Summary

The i18n **infrastructure** is solid — react-i18next is configured correctly, all 13 locales have all 13 namespace JSON files with well-populated translations, `<html lang>` is set dynamically, CJK font fallbacks are in place. However, the i18n **usage** is incomplete: **48 component files** contain zero `useTranslation` imports and render hardcoded English strings. This brief catalogs every non-compliant area by category for systematic remediation.

---

## Current i18n State (What Works)

- **Framework:** react-i18next + i18next-http-backend + i18next-browser-languagedetector
- **Config:** `src/i18n/index.ts` — loadPath `/locales/{{lng}}/{{ns}}.json`, fallback `en`
- **13 locales:** en, de, es, fil, fr, it, ja, nl, pt-BR, pt-PT, ru, zh-CN, zh-TW
- **13 namespaces:** about, almanac, charts, common, forecast, legal, nav, now, radar, records, reports, seismic (+ weather)
- **`<html lang>`:** Set via `src/i18n/use-locale-sync.ts` — compliant
- **CJK fonts:** System CJK fallbacks in `tailwind.config.ts` — compliant
- **RTL-neutral CSS:** Logical properties used where checked — compliant

---

## Category 1: Hardcoded English Strings in Components

### 1A. Full-page content (HIGH — entire pages untranslated)

| File | Hardcoded strings | Namespace target |
|------|-------------------|------------------|
| `src/components/error-boundary.tsx` | "Something went wrong", error message, "Reload page" | `common` |
| `src/components/SetupGuard.tsx` | "Clear Skies is starting up...", "The weather station API is not responding yet. It may still be initialising.", "Retry" | `common` |

**Note:** `error-boundary.tsx` is a class component (React requirement for error boundaries). It cannot use the `useTranslation` hook directly — needs either a functional wrapper or `withTranslation` HOC, or a consumer pattern that passes pre-translated strings.

### 1B. Card components with zero i18n (HIGH — user-visible labels)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/earthquake-card.tsx` | "Retry", "Unknown location", `"N min ago"`, `"N.N hrs ago"`, `"N.N days ago"`, `aria-label="Recent earthquake events"` |
| `src/components/lightning-card.tsx` | `"Lightning strike history: N strikes in the last 24 hours"`, `"no strikes in the last 24 hours"`, `"No activity"`, sr-only "Loading lightning data", table caption "Lightning strike history — last 24 hours", tooltip labels "Distance", "Count" |
| `src/components/barometer-card.tsx` | `endpointLabels={['Low', 'High']}` — gauge scale labels hardcoded in English (line ~221). Uses `useTranslation` for card title but not for the gauge labels. |

### 1C. Chart components (HIGH — labels visible in tooltips and tables)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/charts/WeatherRangeChart.tsx` | "High:", "Low:", "Avg:" (tooltip + sr-only table) |
| `src/components/charts/WindRoseChart.tsx` | "Wind Rose" (default title), "Calm" (label + sr-only text), `aria-label="Wind speed legend by Beaufort scale"`, `aria-label="Wind Rose Data"`, sr-only table caption, "each Beaufort level", "Calm (all directions)" table row header |
| `src/components/charts/HaysChart.tsx` | "High:", "Low:" (tooltip) |
| `src/components/charts/ConfigDrivenChart.tsx` | Chart axis tick formatting (numbers only — possibly OK) |
| `src/components/charts/ChartGauge.tsx` | No user-visible English text found |

### 1D. Layout components (MEDIUM — visible but less prominent)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/layout/now-hero-card.tsx` | Likely aria-label for station header |
| `src/components/layout/app-layout.tsx` | May contain structural labels |
| `src/components/layout/controls-strip.tsx` | aria-label passed as prop (OK if callers translate) |
| `src/components/layout/page-header-card.tsx` | Check for hardcoded heading text |

### 1E. Shared components (MEDIUM)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/shared/cookie-consent-banner.tsx` | "This website uses cookies to analyze traffic via Google Analytics. No personal data is collected.", "Learn more", "Reject", "Accept" |

### 1F. Forecast sub-components (MEDIUM)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/forecast/HourlyStrip.tsx` | `aria-label="Hourly forecast — scroll to see more"`, `aria-label="Hourly forecast"` |
| `src/components/forecast/NowForecastCard.tsx` | `sr-only "Loading forecast…"` |

### 1G. Almanac sub-components (MEDIUM)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/almanac/PlanetTimelineCard.tsx` | `aria-label="Loading planet outlook"` |
| `src/components/almanac/SunMoonDetailCard.tsx` | "Loading sun and moon data" |
| `src/components/almanac/MeteorShowerCard.tsx` | `aria-label="Peak period"` |
| `src/components/almanac/LunarEclipseCard.tsx` | `aria-label="Close eclipse type description"` |

### 1H. UI primitives (LOW — only if user-visible text exists)

| File | Hardcoded strings |
|------|-------------------|
| `src/components/ui/chart-fullscreen.tsx` | `aria-label="View chart fullscreen"`, `aria-label="Close fullscreen"` |
| `src/components/ui/horizontal-scroll-nav.tsx` | `aria-label="Scroll left"`, `aria-label="Scroll right"` |

### 1I. Route-level pages (VERIFY — some may be partially translated)

| File | Status | Hardcoded strings found |
|------|--------|------------------------|
| `src/routes/not-found.tsx` | Uses `useTranslation('common')` BUT has hardcoded weather pun array (10 English puns) | Puns array needs `common` namespace keys |
| `src/routes/now.tsx` | Zero `useTranslation` imports — container-only, may not need text | Verify no labels |
| `src/routes/custom-page.tsx` | Uses `useTranslation('common')` | Likely OK |

---

## Category 2: Number Formatting (Locale-Unaware)

`.toFixed()` produces locale-unaware decimal separators (always `.`, never `,`). In German (`de`), French (`fr`), Portuguese (`pt-PT`, `pt-BR`), and Russian (`ru`), the decimal separator is `,` not `.`.

### 2A. Display-facing `.toFixed()` (should use `Intl.NumberFormat`)

| File | Lines | Context |
|------|-------|---------|
| `src/components/charts/WeatherRangeChart.tsx` | 208, 214, 220, 292–294 | Tooltip "High: 72.3°F" and sr-only table cells |
| `src/components/charts/WindRoseChart.tsx` | 300, 473, 505, 558, 606, 625, 633 | Percentage values in legend, tooltip, sr-only table |
| `src/components/charts/HaysChart.tsx` | 303, 369, 463, 495, 498, 599–600 | Tooltip "High: 72.3°F", axis ticks, sr-only table |
| `src/components/charts/ChartGauge.tsx` | 244 | Gauge display value |
| `src/components/lightning-card.tsx` | 143, 257, 290 | Distance values |
| `src/components/current-conditions-card.tsx` | 391 | Primary temperature display |
| `src/utils/format.ts` | 30 | Central `formatValue()` utility |
| `src/components/earthquake-card.tsx` | (in `formatEqAge`) | Time values "2.3 hrs ago" |

### 2B. SVG-path `.toFixed()` (OK — not display text)

| File | Lines | Context |
|------|-------|---------|
| `src/components/charts/WindRoseChart.tsx` | 102–105 | SVG path `d` attribute coordinates |
| `src/components/charts/HaysChart.tsx` | 95–98 | SVG path `d` attribute coordinates |

These are mathematical coordinates, not display text. They must stay as `.toFixed()` — SVG always uses `.` as decimal.

### 2C. Recommended fix

Create a locale-aware formatting utility:
```typescript
function formatNumber(value: number, decimals: number, locale: string): string {
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value);
}
```

The `i18n.language` from react-i18next provides the active locale. Wire it through `useTranslation` or a context.

---

## Category 3: Date/Time Formatting Issues

### 3A. Hardcoded `'en-US'` locale in `Intl.DateTimeFormat` (CRITICAL)

Multiple components hardcode `'en-US'` in `Intl.DateTimeFormat` calls, forcing English day/month names regardless of the user's selected locale. This is the most widespread i18n violation.

| File | Lines | What's hardcoded |
|------|-------|------------------|
| `src/components/forecast/DailyColumns.tsx` | 38–39, 43–46, 51–58, 63–78 | "Today", "Tomorrow", "Tmrw" + `'en-US'` weekday/month/time formatting |
| `src/components/forecast/HourlyStrip.tsx` | 31 | `'en-US'` time formatting |
| `src/components/forecast/ForecastDiscussionCard.tsx` | 18 | `'en-US'` date formatting |
| `src/components/almanac/MeteorShowerCard.tsx` | 64, 80, 111 | `'en-US'` month/day formatting |
| `src/components/almanac/LunarEclipseCard.tsx` | 224, 234, 244 | `'en-US'` date formatting |
| `src/components/almanac/SolarEclipseCard.tsx` | 130, 136 | `'en-US'` date formatting |
| `src/components/almanac/SunMoonDetailCard.tsx` | 182, 199, 222, 692 | `'en-US'` time formatting |
| `src/components/almanac/PlanetTimelineCard.tsx` | 154, 185, 536 | `'en-US'` time formatting |
| `src/components/uv-index-card.tsx` | 91, 96, 97, 211, 570 | `'en-US'` time formatting |
| `src/components/shared/alert-banner.tsx` | 97 | `'en-CA'` date formatting |
| `src/hooks/useWeatherData.ts` | 737 | `'en-CA'` date formatting |

**Fix for all:** Replace `'en-US'` / `'en-CA'` with `i18n.language` from `useTranslation()`.

**Special case — "Today" / "Tomorrow" / "Tmrw":** `DailyColumns.tsx` lines 38–39, 51–52 have hardcoded English relative day names. These must be translation keys: `t('forecast.today')`, `t('forecast.tomorrow')`, `t('forecast.tmrw')`.

### 3B. Hardcoded `'default'` locale in chart date formatting

| File | Lines | Code |
|------|-------|------|
| `src/components/charts/WeatherRangeChart.tsx` | 175, 180–181 | `d.toLocaleDateString('default', ...)` |
| `src/components/charts/HaysChart.tsx` | 143, 161, 163 | `d.toLocaleString('default', ...)` |

The `'default'` locale falls back to the browser's system locale, NOT the i18n-selected locale. A user who selects Japanese in the dashboard but has an English browser will see English month names in charts.

**Fix:** Pass `i18n.language` instead of `'default'`.

### 3C. Hardcoded relative time strings

| File | Lines | Strings |
|------|-------|---------|
| `src/components/earthquake-card.tsx` | 59, 63, 66 | `"N min ago"`, `"N.N hrs ago"`, `"N.N days ago"` |

**Fix:** Use `Intl.RelativeTimeFormat` with the active locale, or add translation keys with interpolation: `t('earthquake.timeAgo.minutes', { count: N })`.

---

## Category 4: String Concatenation Anti-Patterns

These template literals build display strings by concatenation instead of using i18n interpolation. Word order varies across languages (e.g., Japanese puts units before numbers in some contexts, German compound nouns differ).

| File | Pattern | Example |
|------|---------|---------|
| `src/components/earthquake-card.tsx` | `` `${N} min ago` `` | Should be `t('timeAgo.minutes', { count })` |
| `src/components/lightning-card.tsx` | `` `${distance} ${distanceUnit}` `` | Unit positioning varies by locale |
| `src/components/charts/WindRoseChart.tsx` | `` `${pct.toFixed(1)}%` `` | Percentage formatting varies |
| `src/components/charts/WeatherRangeChart.tsx` | `` `High: ${val}${unit}` `` | Label + value + unit ordering varies |
| `src/components/charts/HaysChart.tsx` | `` `High: ${val}${unit}` `` | Same pattern |
| `src/components/charts/ConfigDrivenGroup.tsx` | `` `${days}d` `` | Duration formatting |

---

## Category 5: Missing Translation Keys in Namespace Files

Based on the hardcoded strings above, these keys need to be added to the English namespace files (and then translated for all 12 other locales):

### `common.json` additions needed

```
error.somethingWentWrong
error.reloadPage
error.retry
setup.startingUp
setup.apiNotResponding
cookie.consentMessage
cookie.learnMore
cookie.accept
cookie.reject
aria.scrollLeft
aria.scrollRight
aria.viewFullscreen
aria.closeFullscreen
aria.loadingData
```

### `now.json` additions needed

```
earthquake.unknownLocation
earthquake.timeAgo.minutes (with interpolation)
earthquake.timeAgo.hours (with interpolation)
earthquake.timeAgo.days (with interpolation)
earthquake.ariaLabel
earthquake.retry
lightning.chartTitle
lightning.noActivity
lightning.loading
lightning.tableCaption
lightning.distance
lightning.count
```

### `charts.json` additions needed

```
tooltip.high
tooltip.low
tooltip.avg
windRose.title
windRose.calm
windRose.calmAllDirections
windRose.ariaLegend
windRose.ariaData
windRose.srDescription
haysChart.high
haysChart.low
```

### `forecast.json` additions needed

```
hourly.ariaLabel
hourly.ariaScrollLabel
loading.forecast
```

### `almanac.json` additions needed

```
planets.loading
sunMoon.loading
meteorShower.peakPeriod
eclipse.closeDescription
```

### `radar.json` — verify completeness

The radar namespace exists. Verify that all strings in `radar-map.tsx`, `radar-layer-panel.tsx`, and `radar-card.tsx` are covered.

---

## Category 6: CSS / Layout Issues for i18n

### 6A. Font imports missing Cyrillic subset (Russian)

`src/index.css` lines 4–13 import Latin-subset-only web fonts:

```css
@import "@fontsource/manrope/latin-400.css";   /* ← "latin" subset only */
@import "@fontsource/outfit/latin-400.css";     /* ← "latin" subset only */
@import "@fontsource/lexend/latin-400.css";     /* ← "latin" subset only */
```

**CJK (ja, zh-CN, zh-TW) — gap.** DASHBOARD-MANUAL.md §3 currently bans CJK web fonts, but this decision is being reversed to maintain visual consistency across all supported locales. System CJK fonts vary significantly across OSes and don't match the Latin typography. The fix is on-demand CJK font loading — only fetch the CJK font files when the user selects a CJK locale, so Latin/European users pay zero cost.

**Approach:** Use Noto Sans JP / Noto Sans SC / Noto Sans TC via `@fontsource` with locale-gated dynamic imports. Only the weights actually used (400, 600, 700) are loaded, and only for the active locale. Estimated per-locale cost: ~2–4 MB, loaded once and cached.

**Cyrillic (ru) — gap.** Manrope, Outfit, and Lexend all ship Cyrillic glyphs in their `@fontsource` packages, but we only import the `latin-*.css` subset files. Russian text unnecessarily falls back to system fonts when we could serve the same styled fonts with ~20–50 KB of additional CSS imports.

**Fix (Cyrillic):** Add Cyrillic subset imports:
```css
@import "@fontsource/manrope/cyrillic-400.css";
@import "@fontsource/manrope/cyrillic-600.css";
@import "@fontsource/outfit/cyrillic-400.css";
@import "@fontsource/outfit/cyrillic-600.css";
```

**Fix (CJK):** Locale-gated dynamic font loading in `src/i18n/index.ts` or a dedicated `src/i18n/font-loader.ts`:
```typescript
// On locale change, dynamically import the CJK font subset
async function loadCJKFonts(locale: string) {
  switch (locale) {
    case 'ja': await import('@fontsource/noto-sans-jp/400.css'); /* + 600, 700 */ break;
    case 'zh-CN': await import('@fontsource/noto-sans-sc/400.css'); break;
    case 'zh-TW': await import('@fontsource/noto-sans-tc/400.css'); break;
  }
}
```

Font stacks in CSS variables update to include CJK families:
```css
--font-sans: 'Manrope', 'Noto Sans JP', 'Noto Sans SC', 'Noto Sans TC', system-ui, sans-serif;
```

**DASHBOARD-MANUAL.md §3 update required:** Remove the CJK font ban ("Do not bundle Noto-CJK or any other CJK web font") and replace with the on-demand loading rule.

### 6B. Text truncation without `title` attribute fallback

Several components use CSS `truncate` or `line-clamp` on text that will be longer in non-English locales (German averages 30% longer than English). Without a `title` attribute, the full text is inaccessible on hover.

| File | Element | Issue |
|------|---------|-------|
| `src/components/layout/page-header-card.tsx` | Page title heading | `truncate` without `title` |
| `src/components/shared/alert-banner.tsx` | Alert event name, detail line, summary | `truncate`/`line-clamp-2` without `title` |

**Fix:** Add `title={text}` attribute alongside `truncate` class.

---

## Category 7: Structural / Edge-Case Issues

### 7A. Error boundary class component

`error-boundary.tsx` is a React class component (required — hooks can't implement `componentDidCatch`). It cannot call `useTranslation()`. Options:

1. **`withTranslation` HOC** — wrap the class component
2. **Functional wrapper** — render a functional component inside the error fallback that calls `useTranslation`
3. **Pass `t` via context** — complex, not recommended

Recommended: option 2 — extract the error UI into a functional `ErrorFallback` component that uses `useTranslation('common')`, called from the class component's `render()`.

**Risk:** If i18next itself fails (network error loading locale files), the error boundary's fallback must still render. Use `t('key', 'Hardcoded fallback')` (i18next's default value parameter) as a safety net.

### 7B. Suspense fallback (`main.tsx`)

```tsx
<Suspense fallback={<div>Loading…</div>}>
```

This renders before i18next initializes — translation functions aren't available yet. This is an acceptable exception. However, consider using a non-text loading indicator (spinner/logo) instead of English text.

### 7C. Not-found page puns

The 404 page has a hardcoded array of 10 weather-themed puns. These need translation into all 13 locales. Options:

1. Move puns to `common.json` as an array (`notFound.puns.0` through `notFound.puns.9`)
2. Allow each locale to have a different number of culturally-appropriate puns
3. For locales where puns don't translate well, use straightforward 404 messages

Recommended: option 2 — puns are inherently cultural. Let translators provide locale-appropriate humor.

### 7D. Card metadata `displayName` values

`src/lib/card-metadata.ts` contains `displayName` strings for the admin layout editor ("Air Quality Index", "Wind Compass", etc.). These are operator-facing in the admin UI. They should be translated via a `settings` or `admin` namespace, or by using translation keys that resolve at render time.

### 7E. `src/utils/format.ts` central formatting

The `formatValue` function at line 30 uses `.toFixed(decimals)` — this is the **single chokepoint** for most numeric display. Fixing locale-awareness here would cascade to many components. However, it needs the active locale passed in, which means threading `i18n.language` through the call chain.

---

## Category 8: Components With Zero i18n Import (Full List)

These 48 `.tsx` files under `src/components/` have zero `useTranslation` or `react-i18next` imports. Not all need translation (some are purely visual/structural), but each must be verified:

**Need translation (confirmed hardcoded user-visible text):**
- `earthquake-card.tsx`
- `lightning-card.tsx`
- `error-boundary.tsx`
- `SetupGuard.tsx`
- `charts/WeatherRangeChart.tsx`
- `charts/WindRoseChart.tsx`
- `charts/HaysChart.tsx`
- `shared/cookie-consent-banner.tsx`
- `forecast/HourlyStrip.tsx`
- `forecast/NowForecastCard.tsx` (partial — has `useTranslation` in parent but sr-only text hardcoded in sub-component)
- `almanac/PlanetTimelineCard.tsx`
- `almanac/SunMoonDetailCard.tsx`
- `almanac/MeteorShowerCard.tsx`
- `almanac/LunarEclipseCard.tsx`
- `ui/chart-fullscreen.tsx`
- `ui/horizontal-scroll-nav.tsx`

**Probably OK (purely visual / structural / no user-visible text):**
- `layout/grid.tsx`, `layout/page-layout.tsx`, `layout/controls-strip.tsx`
- `ui/badge.tsx`, `ui/button.tsx`, `ui/card.tsx`, `ui/separator.tsx`, `ui/scroll-fade.tsx`, `ui/sticky-table.tsx`, `ui/semi-circular-gauge.tsx`
- `background/scene-background.tsx`
- `forecast/TempTrendLine.tsx`, `forecast/WindSymbol.tsx`
- `moon-phase-icon.tsx`, `weather-icon-glyphs.tsx`
- All `icons/*.tsx` (pure SVG, no text)
- `charts/chart-container.tsx`, `charts/ChartGauge.tsx`, `charts/ConfigDrivenChart.tsx`

**Need verification (may have aria-labels or hidden text):**
- `layout/now-hero-card.tsx`
- `layout/app-layout.tsx`
- `layout/page-header-card.tsx`

---

## Remediation Priority

### P0 — Hardcoded `'en-US'` locale (most widespread, highest impact)
1. Replace all `'en-US'` / `'en-CA'` / `'default'` locale args in `Intl.DateTimeFormat` and `toLocaleDateString` with `i18n.language` (~15 files, ~40 call sites)
2. `DailyColumns.tsx` — "Today", "Tomorrow", "Tmrw" → translation keys
3. `earthquake-card.tsx` — relative time, location fallback, retry

### P1 — Core UI text (blocks i18n compliance claim)
4. `error-boundary.tsx` — "Something went wrong" / "Reload page"
5. `SetupGuard.tsx` — startup messages
6. `cookie-consent-banner.tsx` — GDPR banner (legal requirement for EU locales)
7. `lightning-card.tsx` — all labels and empty state
8. `not-found.tsx` — pun array

### P2 — Chart tooltips and sr-only tables
9. `WeatherRangeChart.tsx` — "High:", "Low:", "Avg:"
10. `WindRoseChart.tsx` — "Wind Rose", "Calm", all aria-labels
11. `HaysChart.tsx` — "High:", "Low:"
12. `barometer-card.tsx` — gauge labels "Low", "High"

### P3 — Number formatting
13. Create locale-aware `formatNumber` utility
14. Replace display-facing `.toFixed()` calls with the new utility
15. Thread `i18n.language` through `formatValue()` in `utils/format.ts`

### P4 — Accessibility labels (screen readers)
16. All `aria-label` strings in forecast, almanac, and UI components
17. All sr-only loading announcements

### P5 — String concatenation
18. Replace template-literal concatenation with `t()` interpolation keys

### P6 — CSS / Structural
19. Add Cyrillic font subset imports for Russian locale
20. Add on-demand CJK font loading (Noto Sans JP/SC/TC) for ja, zh-CN, zh-TW
21. Update CSS font stacks to include CJK families
22. Add `title` attributes alongside `truncate` classes
23. Card metadata `displayName` translation
24. Suspense fallback (cosmetic — replace text with spinner)

---

## Category 9: API-Side i18n (Server-Delivered English Strings)

The API sends pre-composed English text to the dashboard in several response fields. The dashboard cannot translate these — the API composes them from combinatorial decision trees (temperature × moisture × sky × precipitation × wind) that would require the dashboard to pre-translate every possible permutation. The API is the computation authority; it must also be the translation authority for its computed output.

### Translation boundary

| Translates in the… | What | Why |
|---------------------|------|-----|
| **API** | Computed/classified text — weatherText, Beaufort labels, AQI categories, record labels, moon names, barometer trend | The API decides WHAT the output is from thresholds/classifiers. The label is part of that computation's output. Combinatorial explosion makes dashboard-side translation impossible. |
| **Dashboard** | Static UI chrome — nav labels, button text, headings, aria-labels, "Today"/"Tomorrow", error messages, empty states | These are fixed strings that exist regardless of what data the API sends. The dashboard's react-i18next infrastructure handles them. |

### 9A. Locale resolution

The API needs a locale resolution mechanism. It already has a `defaultLocale` setting in station metadata. The resolution chain should be:

| Priority | Source | When used |
|----------|--------|-----------|
| 1 | `Accept-Language` header from the dashboard request | Per-visitor locale (dashboard sends `i18n.language` as `Accept-Language`) |
| 2 | `defaultLocale` in `api.conf` (operator-configured via wizard) | Fallback when no header present |
| 3 | `en` | Hard fallback |

### 9B. Fields that need API-side translation

**`weatherText` / `weatherTextStandard` / `weatherTextVerbose`** (conditions text engine)

The conditions text composer in `sse/conditions_text.py` builds sentences from four component modules. Every component has hardcoded English:

| Module | English strings | Count |
|--------|----------------|-------|
| `temperature_comfort.py` | "Dangerously Cold", "Bitter Cold", "Extreme Cold", "Very Cold", "Cold", "Chilly", "Cool", "Pleasant", "Warm", "Hot", "Very Hot", "Dangerously Hot" | 12 |
| `temperature_comfort.py` (moisture) | "Slightly Humid", "Humid", "Very Humid", "Oppressive", "Miserable" | 5 |
| `sky_condition.py` | "Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy", "Overcast", "Heavy Overcast" | 7 |
| `conditions_text.py` (precip) | "Light Rain", "Moderate Rain", "Heavy Rain", "Light Snow", "Moderate Snow", "Heavy Snow", "Freezing Rain", "Sleet", "Hail", "Snow" | 10 |
| `conditions_text.py` (connectors) | "and", "with" | 2 |
| `text_generator.py` (verbose) | Full sentence templates for standard/verbose weatherText | ~10 templates |

Total: ~46 translatable strings plus sentence-composition grammar rules.

**`beaufort.label`** (derived values)

`units/derived.py` returns `{"value": N, "label": "..."}` with 13 English labels:

"Calm", "Very Light Breeze", "Light breeze", "Gentle breeze", "Moderate breeze", "Fresh breeze", "Strong breeze", "Near gale", "Gale", "Strong gale", "Storm", "Violent storm", "Hurricane"

**AQI `category`**

`providers/aqi/_units.py` classifies AQI values into English category names:

"Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous"

**Record labels**

`services/records.py` defines ~20 record labels in `SECTION_MAP`:

"High temperature", "Low temperature", "High heat index", "Low wind chill", "High apparent temperature", "Low apparent temperature", "Largest daily temperature range", "Smallest daily temperature range", "High wind speed", "High wind gust", "Highest daily wind run", "High daily rainfall", "High monthly rainfall", "Most rain in 1 hour", "Highest annual rainfall", "Highest rain rate", "Consecutive days with rain", "Consecutive days without rain", "High humidity", "Low humidity", "High dewpoint", "Low dewpoint", "High barometer", "Low barometer", "High solar radiation", "High UV index"

**Full moon traditional names**

`services/almanac.py` maps month → name: "Wolf", "Snow", "Worm", "Pink", "Flower", "Strawberry", "Buck", "Sturgeon", "Harvest", "Hunter's", "Beaver", "Cold" — plus special labels "Blue Moon", "Supermoon".

These are culturally specific names. Some locales have their own traditional moon names; others may use the English names or have no equivalent.

**`barometerTrendDirection`** — "rising", "falling", "steady"

These are already machine-readable keys. The dashboard already translates them. **No API change needed** for this field.

**Moon `phaseName`** — "new", "waxing-crescent", "first-quarter", etc.

These are already kebab-case identifiers, not display text. The dashboard already maps them. **No API change needed** for this field.

### 9C. Implementation approach

**Translation file format:** JSON files in the API repo, one per locale, structured by domain:

```
weewx_clearskies_api/
└── locales/
    ├── en.json
    ├── de.json
    ├── es.json
    ├── ... (13 locales matching the dashboard)
```

Example `en.json` structure:
```json
{
  "temperature": {
    "dangerously_cold": "Dangerously Cold",
    "bitter_cold": "Bitter Cold",
    "cold": "Cold",
    ...
  },
  "moisture": {
    "humid": "Humid",
    "oppressive": "Oppressive",
    ...
  },
  "sky": {
    "clear": "Clear",
    "partly_cloudy": "Partly Cloudy",
    ...
  },
  "precipitation": {
    "light_rain": "Light Rain",
    ...
  },
  "connectors": {
    "and": "and",
    "with": "with"
  },
  "beaufort": {
    "0": "Calm",
    "1": "Very Light Breeze",
    ...
  },
  "aqi": {
    "good": "Good",
    "moderate": "Moderate",
    ...
  },
  "records": {
    "high_temperature": "High temperature",
    ...
  },
  "moon_names": {
    "1": "Wolf",
    "2": "Snow",
    ...
  }
}
```

**Loading:** At startup, load the locale files into memory. On each request, resolve the locale from `Accept-Language` → `defaultLocale` → `en`, and look up strings from the loaded locale dict. No per-request file I/O.

**Sentence composition:** The `conditions_text.py` composer must become locale-aware. Different languages have different word order and connector rules. The locale file should include composition templates, not just word lists. For example:

- English: `"{temperature}, {sky}, with {precipitation}"` 
- German: `"{sky}, {temperature}, mit {precipitation}"`
- Japanese: `"{sky}、{temperature}、{precipitation}"`

### 9D. Fields the API does NOT translate (dashboard responsibility)

| Field | Why dashboard translates |
|-------|-------------------------|
| `barometerTrendDirection` ("rising"/"falling"/"steady") | Machine-readable keys; dashboard already maps them via `t()` |
| `phaseName` ("waxing-crescent", "full", etc.) | Kebab-case identifiers; dashboard already maps them |
| `windDirCardinal` (N, NNE, NE, etc.) | Language-neutral codes; dashboard maps via `t('directions.N')` |
| `comfortIndex` ("windChill"/"heatIndex"/"none") | Machine-readable selector; dashboard decides display |
| `source` ("weewx", "nws", "open_meteo") | Internal identifier, not user-facing |

### 9E. Unit labels — ALL labels are locale-specific

`units/labels.py` defines display labels for all unit types as a single English-centric set. **Every unit label is potentially locale-specific** — not just the obvious English words. Different cultures display the same measurements differently, and we cannot assume any symbol is "universal" without verifying it for each of our 13 supported locales.

Examples of locale variation (non-exhaustive — full research needed per locale):

| Unit | English default | Locale variations |
|------|----------------|-------------------|
| degree_C | °C | Japanese: ℃ (single Unicode char) or 度, Chinese: 摄氏度 or °C |
| meter_per_second | m/s | Japanese: m/秒 |
| km_per_hour | km/h | Dutch: km/u, some locales: km/時 |
| mile_per_hour | mph | Not universally recognized abbreviation |
| knot | knots | English word — German: kn, French: nd/nds, Japanese: ノット |
| foot | feet | English word — German: Fuß, French: pieds |
| mile | miles | English word — German: Meilen, Japanese: マイル |
| inch | in | English abbreviation |
| inHg | inHg | English abbreviation for a US-only unit |
| hPa | hPa | Japanese: ヘクトパスカル (sometimes abbreviated hPa) |
| watt_per_meter_squared | W/m² | May vary in CJK contexts |

**Action required:** Research the correct unit display format for every unit × locale combination across all 13 supported locales. Do not assume — verify. The API's locale files must carry the complete set of unit labels per locale, not just overrides for "English words."

**Fix:** The `get_label()` function already accepts overrides from operator config (`api.conf [units][[labels]]`). Extend this to resolve by locale first, then operator override, then defaults. Resolution order:

1. Operator override (`api.conf [units][[labels]]`) — operator always wins
2. Locale-specific label from the API's locale file
3. English default from `labels.py`

**`format_value()` and decimal separators:** The `format_value()` function uses Python `%` formatting (`"%.1f" % value`), which always produces `.` as the decimal separator regardless of locale. German, French, Russian, and Portuguese users expect `,` as the decimal separator. Fix: use `babel.numbers.format_decimal()` with the active locale when formatting for display.

### 9F. Provider data is almost entirely numeric — we generate the text

Providers deliver numbers. We turn them into words:

| Provider delivers | We produce | Our code |
|-------------------|-----------|----------|
| WMO weather code (int) | "Partly cloudy", "Heavy rain" | `_WMO_CODE_TO_TEXT` in `openmeteo.py` |
| Aeris coded string (`::SC`, `::OV`) | "Scattered Clouds", "Overcast" | `weather-code.ts`, conditions engine |
| Numeric AQI value | "Good", "Moderate", "Hazardous" | `_units.py` category classifier |
| Wind speed (float) | "Gentle breeze" (Beaufort 3) | `derived.py` Beaufort scale |
| Sensor readings (float) | "Warm and Humid, Partly Cloudy, with Light Rain" | Conditions text engine (4 modules) |
| Pressure delta (float) | "rising", "falling", "steady" | `barometer_trend.py` |
| Moon phase angle (float) | "Waxing Gibbous" | `almanac.py` phase classifier |
| Month number (int) | "Wolf Moon", "Harvest Moon" | `almanac.py` name table |

**Every English string the visitor sees from these paths is generated by our lookup tables and classifiers.** The i18n fix is translating our own tables — no provider API changes needed.

### 9F. Provider pass-through text (small, out of scope for v0.1 i18n)

The only raw provider text that reaches the visitor verbatim:

| Field | Source | Visibility | Notes |
|-------|--------|-----------|-------|
| Alert `headline` / `description` | NWS / Xweather | Prominent (alert banner) | Safety-critical government text — see below |
| Forecast `narrative` | NWS / paid Aeris | Low (off by default; null for most providers) | Only appears when operator enables discussion card |
| `ForecastDiscussion` | NWS AFD | Low (operator-toggled, off by default) | Technical meteorological prose |
| Earthquake `place` | USGS | Low (tile card, 2 entries) | Proper nouns ("5 km NNW of Ridgecrest, CA") |

**Alerts are out of scope for translation — by design.** Alert text is safety-critical prose from meteorological agencies. We pass it through verbatim in whatever language the issuing agency provides. We do not translate it ourselves — mistranslation of a tornado warning is a liability. NWS alerts are English-only; Xweather's international alerts carry native-language text in `localLanguages` when the issuing agency provides it, but that's the agency's language, not the visitor's locale.

The path to multilingual alerts is **new provider modules**, not translation. The provider module contract already supports this: someone writes `alerts/jma.py` (Japan Meteorological Agency, Japanese), `alerts/dwd.py` (Deutscher Wetterdienst, German), `alerts/meteofrance.py` (Météo-France, French). Each delivers alerts in its agency's native language. The alert banner renders whatever text the provider gives it. No framework change needed — the architecture is already provider-pluggable per domain.

---

## Category 10: Wizard & Admin UI (Zero i18n Infrastructure)

The setup wizard and admin UI are a separate Python/HTMX app (`weewx-clearskies-stack`, `weewx_clearskies_config/` package) using Jinja2 templates. They have **zero i18n infrastructure** — every string is hardcoded English directly in the HTML templates. No `gettext`, no translation functions, no locale files.

The wizard is the first thing the operator sees. An operator in Japan, Germany, or Brazil should not need to read English to set up their own weather station.

### 10A. Template inventory

**Wizard** — 24 templates under `templates/wizard/`:

| Template | UI elements | Content type |
|----------|-------------|-------------|
| `step_station.html` | ~24 labels/hints | Station name, lat/lon, altitude, timezone, language, photo upload |
| `step_providers.html` | ~28 labels/hints | Provider selection, domain cards, API key fields |
| `step_schema.html` | ~38 labels/hints | Column mapping table, canonical field picker |
| `step_appearance.html` | ~24 labels/hints | Theme, branding, logo upload, colors |
| `step_complete.html` | ~28 labels/hints | Review summary, completion message, restart status |
| `step_units.html` | ~9 labels/hints | Unit system selection (US/Metric/MetricWX) |
| `step_db.html` | ~14 labels/hints | Database path, driver, connection test |
| `step_api.html` | ~14 labels/hints | API host, port, TLS configuration |
| `step_eula.html` | ~7 labels/hints | License acceptance |
| `step_privacy_legal.html` | ~12 labels/hints | Analytics, cookie consent, privacy policy |
| `step_import.html` | ~8 labels/hints | skin.conf import |
| `step_review.html` | ~10 labels/hints | Final review before apply |
| `step_webcam.html` | ~4 labels/hints | Webcam configuration |
| `step_tls.html` | ~4 labels/hints | TLS certificate setup |
| `step_feature_settings.html` | ~5 labels/hints | Feature toggles |
| `step_provider_key_fields.html` | ~5 labels/hints | Provider API key entry |
| `layout.html` | ~2 elements | Wizard chrome/navigation |
| `_progress_bar.html` | ~4 elements | Step progress indicator |
| `restart_status_fragment.html` | ~3 elements | API restart status |
| Plus 3 test-result fragments | ~0 elements each | HTMX response fragments |

**Admin** — 9 templates under `templates/admin/`:

| Template | UI elements | Content type |
|----------|-------------|-------------|
| `landing.html` | ~5 elements | Admin dashboard landing page |
| `card_layout.html` | ~11 elements | Now page card layout editor |
| `sky_classification.html` | ~4 elements | Sky condition tuning |
| `haze_calibration.html` | ~19 elements | Haze detection calibration |
| `forecast_correction.html` | ~10 elements | Forecast correction engine config |
| `geographic_features.html` | ~8 elements | Geographic features/PMTiles |
| `connection.html` | ~5 elements | Connection status/test |
| `generic_section.html` | ~3 elements | Reusable config section |
| `result.html` | ~1 element | Action result feedback |

**Shared:**
| Template | Content |
|----------|---------|
| `bootstrap.html` | Base HTML layout |
| `macros/form_fields.html` | Reusable form field macros |

**Estimated total: ~300+ hardcoded English strings** across headings, labels, hints, buttons, placeholders, error messages, and help text.

### 10B. Implementation approach

The config UI is server-rendered Jinja2 + HTMX. The standard Python i18n approach is:

1. **`flask-babel`** (or `babel` standalone) for `gettext` integration with Jinja2
2. **`_()` function** in templates: `{{ _("Station display name") }}`
3. **`.po` / `.mo` files** per locale under `weewx_clearskies_config/translations/`
4. **Locale resolution:** read from the operator's `default_locale` setting in `api.conf` (already captured in wizard step 6). The wizard bootstraps in the browser's `Accept-Language` locale until the operator selects one explicitly.

### 10C. Language selection must be step 1

If the operator doesn't read English, they can't navigate to a language picker buried at step 6. Language selection is the first thing the wizard shows — before import, before EULA, before anything.

**New step 1: Language**
- Shows the 13 supported locales with their native-script labels (e.g., "日本語", "Deutsch", "Français") — no English comprehension required to pick your language
- Pre-selects based on the browser's `Accept-Language` header as a best guess
- On selection, the wizard immediately re-renders in the chosen locale
- The choice persists for all subsequent steps and is written to `api.conf` as `default_locale` at apply time
- If the operator re-runs the wizard, `default_locale` is already in `api.conf` — use it from step 1

This bumps the current step count from 15 to 16. The language field currently on the Station Identity step moves to step 1 and is removed from step 7 (formerly step 6).

### 10D. What stays English

- EULA/license text — GPL v3 is a legal document; official translations exist but are not legally binding. Show English with a link to unofficial translations.
- Technical identifiers in the schema mapping step (column names, canonical field names) — these are code identifiers, not prose.
- Log output and developer-facing error details — operator-facing error *summaries* get translated; stack traces stay English.

---

## Estimated Scope

### Dashboard side
- **~16 component files** need `useTranslation` added and strings extracted
- **~15 component files** have hardcoded `'en-US'`/`'en-CA'`/`'default'` locale → replace with `i18n.language`
- **~50–80 new translation keys** across the dashboard namespace files
- **~12 dashboard locale files** need the new keys translated (en is source)
- **1 utility** (`format.ts`) needs locale-aware number formatting
- **1 error boundary** needs architectural pattern for i18n in class component
- **1 CSS file** needs Cyrillic font subset imports + CJK font-stack update
- **1 font loader module** needs creation for on-demand CJK font loading
- **2 components** need `title` attribute added alongside `truncate` class

### API side
- **1 locale directory** with 13 JSON files (~100 translatable strings each)
- **~6 modules** need locale threading (conditions_text, temperature_comfort, sky_condition, derived, records, almanac)
- **1 middleware or dependency** to resolve locale from `Accept-Language` header
- **Sentence composition** in `conditions_text.py` needs locale-aware templates (grammar differs across languages)

### Wizard & Admin (config UI)
- **~33 Jinja2 templates** need `_()` wrapping on all user-visible strings (~300+ strings)
- **`flask-babel`** (or equivalent) integration for gettext with Jinja2
- **13 `.po` files** (one per locale) with ~300 translation entries each
- **New wizard step 1** — language selection (native-script labels, pre-selected from `Accept-Language`, immediate re-render on change)

---

## Out of Scope

- Operator-authored content (About page markdown, custom page content) — user input, not translatable
- Provider-sourced prose (forecast narratives, alert headlines, earthquake place names, forecast discussion) — comes from external APIs in the provider's language; depends on upstream i18n
- `weather-code.ts` — internal mapping, no user-visible text
- Console log messages — developer-facing only
- Mock data files — test-only
