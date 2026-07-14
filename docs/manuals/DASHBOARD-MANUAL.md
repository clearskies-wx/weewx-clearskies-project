# Clear Skies — Dashboard Manual

Single authority for Clear Skies dashboard technical behavior rules. Companion to **DESIGN-MANUAL.md** (visual design rules).

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **DESIGN-MANUAL.md** — visual design rules (colors, tokens, card anatomy, icons)
- **API-MANUAL.md** — API implementation rules (data model, units, enrichment)
- **ARCHITECTURE.md** — system topology, dashboard pages, routes

Last updated: 2026-07-14

---

## Table of Contents

1. [Pages & Routes](#1-pages--routes)
2. [Time Zones](#2-time-zones)
3. [Internationalization](#3-internationalization)
4. [Browser Support](#4-browser-support)
5. [Performance Budget](#5-performance-budget)
6. [Charts System — Dashboard Side](#6-charts-system--dashboard-side)
7. [Data Refresh & Realtime](#7-data-refresh--realtime)
8. [Card Plugin Contract](#8-card-plugin-contract)
9. [Dynamic Now Page & Page Visibility](#9-dynamic-now-page--page-visibility)
10. [Radar Card & Expanded View](#10-radar-card--expanded-view)
11. [Anti-Patterns](#11-anti-patterns)
12. [Marine Activities Page](#12-marine-activities-page)

---

## §1 Pages & Routes

### Route table

Nine built-in pages plus a custom-page mechanism. React Router v7. All pages lazy-loaded.

| # | Page | Route | Default state |
|---|------|-------|---------------|
| 1 | Now (home) | `/` | Always visible — cannot be hidden |
| 2 | Forecast | `/forecast` | Visible |
| 3 | Charts | `/charts` | Visible |
| 4 | Almanac | `/almanac` | Visible |
| 5 | Seismic | `/seismic` | Visible |
| 6 | Records | `/records` | Visible |
| 7 | Reports | `/reports` | Visible (self-hides when NOAA files absent) |
| 8 | About | `/about` | Visible |
| 9 | Legal | `/legal` | Visible (linked from footer) |
| — | Custom pages | `/:slug` | Operator-defined, appear after Reports before About |
| — | 404 | `/*` | Any hidden or nonexistent route |

Register routes at runtime from operator config. Hidden pages return 404 — they are not reachable at all, not merely absent from navigation.

### Per-page default content

**Now (`/`):**
Current-conditions hero (operator-uploadable photo, `outTemp` primary, condition + feels-like secondary), active alert banner, Today's Highlights (today's hi/lo + peak gust + rain so far + peak AQI + records-broken-today), Wind tile (animated compass + speed/gust + Beaufort), Station observations tile (locked default 8: barometer + 3-hr trend, dewpoint, outHumidity, rain combined, heatindex, windchill, radiation, UV), Precipitation & Humidity tile, Sun & Moon mini-tile, AQI tile (pollutant dots colored per-pollutant from `pollutantSubIndices` when available; falls back to overall AQI color when absent), Lightning tile, Earthquake tile, Today's forecast card, Radar card (expands to full width when webcam is disabled), Webcam card (only when `webcam.json` `enabled: true` and image loads successfully; has Live / Timelapse tab toggle), homepage chart panel (default `homepage` group with 1d/3d/7d/30d/90d range selector and "View all charts →" link).

**Forecast (`/forecast`):**
Active alert banner header strip, hourly forecast (scrollable strip; provider-adaptive 1h or 3h intervals), daily forecast (7-day default, extending if the provider supplies more; per-day icon + day-of-week + condition + hi/lo + precip% + wind), forecast discussion / narrative tile (operator-toggled, off by default; renders NWS AFD or equivalent prose), forecast freshness indicator.

**Charts (`/charts`):**
Config-driven tabs — one tab per chart group from `GET /api/v1/charts/config`. Default tabs: `homepage`, `averageclimate`, `monthly`, `ANNUAL`, then operator-defined custom groups in operator-set order. Per-tab features: time-range navigator, range-selector buttons, year/month dropdowns for `monthly` and `ANNUAL`, hover tooltip, clickable legend, PNG + CSV export, `page_content` markdown narrative slot above charts.

**Almanac (`/almanac`):**
Sun details (civil twilight, rise/transit/set, azimuth/altitude/RA/declination, total daylight + delta vs yesterday, next equinox/solstice), Moon details (rise/transit/set, azimuth/altitude/RA/declination, phase name + % full, next full/new moon), year-long sunrise/sunset chart, year-long daylight chart, moon-phase calendar, planet visibility, lunar eclipses, meteor showers.

**Seismic (`/seismic`):**
Two-card layout: Leaflet/OSM map card (left on desktop, stacked on mobile) with earthquake markers sized by magnitude and colour-coded by age (oldest = blue, newest = red), station location marker, and GEM Global Active Faults overlay (show/hide toggle, default on; fault lines drawn in uniform amber). Scrollable earthquake list card (right on desktop). Clicking a list row flies the map to that earthquake; clicking a map marker scrolls the list. Settings summary bar (provider, radius, minimum magnitude, days). API endpoint: `/api/v1/earthquakes`.

**Records (`/records`):**
Per-section cards for Temperature, Wind, Rain, Humidity, Barometer, Sun (gated on radiation/UV), AQI (gated on AQI columns). Each card: non-sortable table with four columns — Record | Today | Value | Date. Single period toggle (YTD / All-Time) switches all cards simultaneously. "Broken in last 30 days" badge on freshly set records.

**Reports (`/reports`):**
Year/month dropdowns populated from `NOAA-*.txt` files actually present. HTML-parsed table as default rendered view. "Download .txt" link. Self-hide when NOAA files absent; configuration UI prompts operator to enable the weewx NOAA generator.

**About (`/about`):**
Operator-authored markdown. Setup wizard pre-populates from collected station fields. Operator edits via configuration UI.

The Data Providers card dynamically shows active providers by reading the capabilities API — only providers the operator has actually configured appear. Static providers with no operator-configurable equivalent (OpenStreetMap, CARTO, GEM Global Active Faults, Skyfield, IMO) are always shown regardless of configuration, since they are used unconditionally wherever their underlying feature (maps, seismic overlay, almanac, meteor showers) is active. Provider display names and links resolve through the capabilities API's `attribution.displayName` and `attribution.url` fields; entries reflect the Aeris→Xweather rebrand (Vaisala's product name, not the retired "Aeris"/"AerisWeather" naming). Dead provider entries with no path to ever appearing (`geonet`, `emsc`, `renass`, `msc_geomet`, `dwd_radolan`) do not appear, since they have no capabilities API entry.

**In-context provider attribution:** Beyond the About page's centralized index, forecast cards (Today's Forecast on Now, and the Forecast page) and the AQI card show a `ProviderAttribution` footer (see §8 "Attribution rendering") including the provider's logo when `logoRequired` is true. The alert banner shows text-only attribution in the expanded detail section — no logo. Radar and seismic pages continue to rely on Leaflet's built-in attribution controls; that mechanism is unchanged by this work.

**Legal (`/legal`):**
Legal/privacy text. Also linked from footer. Setup wizard requires acknowledgment checkboxes. Privacy Policy text auto-updates to match the configured analytics provider.

### Custom pages

Custom pages appear after Reports, before About. Operator picks slug (validated unique), display name, Phosphor icon (curated subset), nav-bar position, and content blocks. Content blocks: any canonical built-in cards, markdown narrative blocks, custom charts, custom records, embedded media. Custom pages are reorderable, renamable, hide-able, and deletable. Persists in operator config.

### Self-hide behavior

Cards self-hide when all backing data is null over the visible period. A page self-hides when all of its cards self-hide. Now never self-hides.

**Configured-but-no-data:** When backing data is transiently absent (network delay, provider outage), keep the card visible with a graceful empty state (display `—` for missing values). Do NOT hide a card for transient data absence — self-hide is for permanently missing sensors, not temporary gaps.

### API client configuration

The dashboard connects to a single backend: the API. Use relative `/api/v1` by default.

| Variable | Purpose | Default |
|----------|---------|---------|
| `VITE_API_BASE_URL` | Override the API base URL | `/api/v1` |
| `VITE_SSE_URL` | Override the SSE endpoint URL | `/sse` |

A global error boundary wraps the entire app tree. Any unhandled React error surfaces a top-level fallback rather than a blank screen.

---

## §2 Time Zones

### Wire format

Every timestamp on the API wire ends in `Z` (UTC ISO-8601). No local-time strings in API responses. Never accept or display a timestamp that lacks the `Z` suffix.

### Display

Render timestamps in the station's local time zone, not the visitor's browser-local zone. A visitor in Tokyo viewing a New England station sees Eastern times. This matches every weewx skin's precedent.

The station time zone is delivered via `StationMetadata` as an IANA identifier (e.g., `America/New_York`).

### TZ source priority (API-side, for reference)

| Priority | Source |
|----------|--------|
| 1 | Explicit operator setting in clearskies-api config |
| 2 | weewx config (`Station.timezone` if set) |
| 3 | OS timezone (resolved via `zoneinfo`) |
| 4 | UTC + WARN (logged at startup; operator must set a timezone) |

### Browser-side rendering

Use `Intl.DateTimeFormat` with the station IANA time zone and the active locale. No JS date library is required.

Never call `toLocaleString()` without an explicit `timeZone` option. Always supply the station IANA identifier.

### No per-user TZ override

No per-user time zone override at v0.1. All visitors see station-local time. Phase 6+ enhancement: localStorage override using `Intl.DateTimeFormat` (client-side only, no server change).

### Station clock utility

`utils/station-clock.ts` is the single module for station-date logic. Every component that needs to know the station's current date or time imports from this module. No component computes station dates ad-hoc.

The module exports four functions (ADR-075 §6):

```typescript
/** Extract stationClock.date from an API response. */
export function getStationDate(response: { stationClock?: StationClock }): string;

/** Increment a YYYY-MM-DD date string by n days. */
export function addDays(dateStr: string, n: number): string;

/** Is the given validDate "today" at the station? */
export function isStationToday(validDate: string, stationDate: string): boolean;

/** Convert stationClock.time to epoch ms for elapsed-time comparisons. */
export function stationTimeMs(stationClock: StationClock): number;
```

The `stationClock` block is present on every API response:

```json
{
  "data": { "..." : "..." },
  "stationClock": {
    "date": "2026-06-27",
    "time": "2026-06-27T22:30:00-04:00",
    "timezone": "America/New_York"
  }
}
```

- `date` — station-local date as YYYY-MM-DD. Canonical answer to "what day is it at the station?"
- `time` — station-local time as ISO-8601 with UTC offset.
- `timezone` — IANA identifier (redundant with `StationMetadata.timezone`; included for self-contained responses).

### Approved temporal patterns

Authority: ADR-075.

| Need | Pattern | Source |
|------|---------|--------|
| "What date is it at the station?" | Read `stationClock.date` from the most recent API response | API |
| "What time is it at the station?" | Read `stationClock.time`, or convert `Date.now()` using station IANA TZ via `Intl.DateTimeFormat` | API or Intl |
| "Is this forecast entry today?" | Compare `entry.validDate === stationClock.date` | API |
| "Format a timestamp for display" | `formatLocalTime(iso, stationTz, locale)` from `utils/time.ts` | Existing utility |
| "Has enough time elapsed since X?" | `Date.now() - new Date(iso).getTime() > thresholdMs` | Native (UTC epoch math) |
| "Should I refetch?" | `Date.now() > new Date(freshness.validUntil).getTime()` | API freshness envelope |
| "Tomorrow's date at the station" | Increment `stationClock.date` by one day via `addDays()` | Derived from API |

`Date.now()` used for display ticks — arc position updates, "last updated N seconds ago" elapsed-time display — is approved. These are not station-date computations. Mark such uses with `// ADR-075: display tick, not data refresh`.

### Banned temporal patterns

These are grep-checkable FAIL conditions (ADR-075 §6). Any of the following in dashboard source is a violation:

```
FAIL: new Date() used to determine station-local date or time
      (Date.now() is OK for UTC epoch elapsed-time math)
FAIL: .toISOString().split('T')[0] used to derive a station-local date
      (this gives a UTC date, not station-local)
FAIL: index === 0 as a proxy for "today" in forecast or any date-ordered list
FAIL: Hardcoded setInterval for data refresh without reference to freshness.validUntil
      or freshness.refreshInterval
FAIL: toLocaleString() or Intl.DateTimeFormat() without explicit timeZone option
FAIL: Any "is it daytime?" check that doesn't use station timezone or stationClock
```

---

## §3 Internationalization

### Supported locales (v0.1)

13 locales ship at v0.1:

| Code | Language |
|------|----------|
| `en` | English (default) |
| `de` | Deutsch (German) |
| `es` | Español (Spanish) |
| `fil` | Filipino |
| `fr` | Français (French) |
| `it` | Italiano (Italian) |
| `ja` | 日本語 (Japanese) |
| `nl` | Nederlands (Dutch) |
| `pt-PT` | Português (Portugal) |
| `pt-BR` | Português Brasil |
| `ru` | Русский (Russian) |
| `zh-CN` | 中文 简体 (Simplified Chinese) |
| `zh-TW` | 中文 繁體 (Traditional Chinese) |

### Framework and file layout

Use **react-i18next** for all user-facing string handling. All 13 locale directories are present under `public/locales/<lang>/<ns>.json`. Locale files are served as static assets via `i18next-http-backend` (loadPath: `/locales/{{lng}}/{{ns}}.json`). The `src/i18n/` directory contains the i18next configuration (`index.ts`), the locale-sync hook (`use-locale-sync.ts`), and the CJK font loader (`font-loader.ts`) — no locale JSON files live under `src/`.

Default fallback locale is `en`. Missing keys fall back to `en` silently. Numbers, dates, and units format per locale via `Intl.NumberFormat` / `Intl.DateTimeFormat`.

### Locale source — operator-controlled, not visitor-detected

The dashboard does **not** run browser/OS language detection and has no visitor-facing locale picker. `i18next-browser-languagedetector` was removed from the project entirely (package uninstalled; no `LanguageDetector` plugin registered in `src/i18n/index.ts`). There is no `?lang=` query-param override.

Boot sequence:

1. `src/i18n/index.ts` initializes i18next with `lng: "en"` — a safe cold-start default, not a detected value.
2. `AppLayout` (`src/components/layout/app-layout.tsx`) fetches station metadata and reads `station.defaultLocale`. Once it differs from the current `i18n.language` and is one of the 13 `SUPPORTED_LOCALES`, it calls `i18n.changeLanguage(defaultLocale)`.
3. Every visitor of a given station therefore sees the same language — the station's `default_locale`, which the operator sets in the wizard's station step (persisted to `api.conf [station] default_locale`; see API-MANUAL.md) — not a language inferred from the visitor's browser. This is a distinct setting from the wizard's own UI language (a separate, earlier step that only affects what language the operator sees while running the wizard itself — see ARCHITECTURE.md "Wizard" section).

Changing the browser's language preference has no effect on the dashboard. This mirrors how units and timezone are already operator-configured rather than visitor-detected.

### Locale-aware number and date formatting

Two utility modules wrap the browser `Intl` APIs so no call site hardcodes a locale or falls back to `.toFixed()`:

**`src/utils/format-number.ts`:**
- `formatNumber(value, decimals, locale)` — wraps `Intl.NumberFormat(locale, { minimumFractionDigits, maximumFractionDigits })`.
- `formatUnit(value, unit, locale)` — uses `Intl.NumberFormat(locale, { style: 'unit', unit })` for the 9 unit identifiers Intl supports natively across all 13 locales (`celsius`, `fahrenheit`, `kilometer-per-hour`, `mile-per-hour`, `meter-per-second`, `millimeter`, `inch`, `degree`, `percent`). For units Intl does not support (`hectopascal`, `knot`, `watt-per-square-meter`, `inch-of-mercury`), it falls back to `formatNumber()` plus a verified per-locale custom label baked into the module (falls back to the `en` label when a locale entry is absent).
- `src/utils/format.ts`'s `formatValue()` accepts a `locale` parameter (default `'en'` for backward compatibility) and delegates to `formatNumber()`.

**`src/utils/format-date.ts`:** thin wrappers around `Intl.DateTimeFormat` / `Intl.RelativeTimeFormat` that make `locale` and `tz` **required, non-defaulted** parameters — `formatDayOfWeek`, `formatShortDayOfWeek`, `formatMonthDay`, `formatTime`, `formatFullDate`, `formatRelativeTime`. Callers always pass `i18n.language` for locale and the station's IANA timezone for `tz` (see §2). No wrapper accepts `'en-US'`/`'default'` or omits `timeZone` — that class of bug is structurally prevented by the function signatures.

### RTL

No RTL languages in v0.1. Write LTR-neutral CSS throughout: use `margin-inline-start` over `margin-left`, `padding-inline-end` over `padding-right`, and so on. RTL support must be a future addition, not a future rewrite.

### Document language attribute

Set `<html lang="...">` per active locale on every page render.

### CJK fonts

Use Noto Sans JP / Noto Sans SC / Noto Sans TC for Japanese, Simplified Chinese, and Traditional Chinese respectively. Load CJK fonts **on demand** — only when the user selects a CJK locale — so Latin/European users pay zero download cost. Import only the weights the dashboard uses (400, 600, 700). CJK font files are cached by the browser after first load.

**Implementation:** `src/i18n/font-loader.ts` exports `loadFontsForLocale(locale)`. It `import()`s the three `@fontsource/noto-sans-{jp,sc,tc}/{400,600,700}.css` files for `ja` / `zh-CN` / `zh-TW` respectively and no-ops for every other locale. Vite code-splits each dynamic import into its own chunk — none of the ~2–4 MB Noto Sans CJK weight files land in the main bundle. A module-level `Set<string>` tracks which locales have already been loaded so repeat calls within a session are free; the browser HTTP cache persists the fetch across sessions after the first load. `src/i18n/use-locale-sync.ts`'s `useLocaleSync()` hook (called once at the app root) calls `loadFontsForLocale(i18n.language)` inside the same `useEffect` that syncs `<html lang>` — so font loading fires automatically on every locale change, including the initial operator-locale switch described above.

### Cyrillic fonts

Import the Cyrillic subset alongside the Latin subset for every font whose @fontsource distribution ships one, eagerly (not on demand) since Russian is a supported locale. As of T4.1 (2026-07-02): Manrope ships `cyrillic-{400,600,700}.css` and these are imported. Outfit and Lexend do **not** ship a Cyrillic subset upstream (Google Fonts only publishes `latin`/`latin-ext` for these two families, plus `vietnamese` for Lexend) — verified by inspecting `node_modules/@fontsource/{outfit,lexend}`. Cyrillic text rendered in `--font-display` (Outfit) or `--font-chart` (Lexend) falls through to the `system-ui` fallback already present in both stacks, which has full Cyrillic coverage on every supported OS (ADR-025 browser baseline). This is a font-coverage limitation, not an implementation gap — do not re-attempt adding `cyrillic-*.css` imports for Outfit or Lexend without first confirming upstream has added the subset.

---

## §4 Browser Support

### Supported matrix

| Browser | Minimum |
|---------|---------|
| Chrome / Edge / Chromium-based | Last 2 years (~Chrome 110+) |
| Firefox | Last 2 years (~Firefox 110+) |
| Safari (macOS / iPadOS) | 16.4+ |
| iOS Safari | 16.4+ |
| Android Chrome / Samsung Internet / WebView | Last 2 years |

Older browsers may render the dashboard, but do not test against them and do not accept bug reports for them.

### Browserslist config (Vite build target)

```
>0.5%, last 2 years, not dead, not op_mini all
```

This drives transpilation target and CSS prefixing.

### Explicitly not supported

- Internet Explorer (any version) — EOL 2022.
- Opera Mini.
- Any browser without ES2022 baseline, `fetch`, `Intl.DateTimeFormat`, CSS custom properties, or CSS Grid.
- No-JS rendering and progressive enhancement to static HTML — out of scope.

---

## §5 Performance Budget

### Lighthouse targets

Run Lighthouse against the primary pages: Now, Forecast, Charts, Records.

| Category | Target |
|----------|--------|
| Performance | ≥ 90 |

A Performance result below 90 on a release flags a pre-tag investigation.

**Accessibility target:** Lighthouse Accessibility ≥ 90 is tracked here for completeness but is governed by ADR-026 — it is **release-blocking**, not a soft target like the performance budget. A missed accessibility score blocks the release; a missed performance score does not.

### Core Web Vitals

| Metric | Target |
|--------|--------|
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |

### Bundle size

Initial JS bundle (Now-page route): target **≤ 200 KB gzipped**. Monitor in CI via `vite-bundle-visualizer` or equivalent. Going over flags a review — charting and i18n bundles can grow legitimately; the point is awareness.

### Targets, not gates

Missed targets are bugs to investigate, not release blockers. If a release misses a target: record the actual measured numbers in `docs/audits/<release>.md`, note the cause briefly, file a backlog issue if the miss is fixable, then ship.

Accessibility failures are release-blocking (they determine whether a class of users can use the dashboard at all). Performance misses are not.

### Stale-while-revalidate and CLS

The stale-while-revalidate pattern in `useApiQuery` (§7) is the concrete enforcement mechanism for the CLS ≤ 0.1 target. Skeleton swaps during background refetches cause layout shift. Preserve stale data during refetches to prevent those shifts.

---

## §6 Charts System — Dashboard Side

### Rendering architecture

Charts on the `/charts` page render dynamically from `GET /api/v1/charts/config`. Two components own chart rendering:

- **`ConfigDrivenGroup`** — group container; manages the tab, range selectors, and year/month dropdowns.
- **`ConfigDrivenChart`** — renders an individual chart from its config entry; switches chart component based on series type detection.

Use **Recharts** for all standard time-series charts. Use **custom SVG** for the wind rose.

### Proportional data scaling

For rolling-range chart groups, compute `aggregate_interval` client-side and pass it to the API:

```
aggregate_interval = base_interval × max(1, range / base_time)
```

Pass the result as the `aggregate_interval` query parameter on `/archive` requests. The API groups archive records into `FLOOR(dateTime / N) * N` buckets.

### Per-field aggregation

Each series in the config may specify `aggregate_type`. Pass these to the API via the `agg_map` query parameter. Fields without an explicit type default to `AVG`. Supported types: `avg`, `max`, `min`, `sum`, `count`, `sumcumulative`. The `sumcumulative` type applies SQL SUM per bucket then accumulates into a running total (used for cumulative rain).

### Special series auto-detection

When the dashboard encounters these series names in the chart config, it switches chart component and data strategy automatically:

| Series name | Component | Key behaviors |
|-------------|-----------|---------------|
| `windRose` | Custom SVG polar chart | 16 directions × 7 Beaufort speed bands. Separate raw (unaggregated) archive fetch for `windSpeed` + `windDir`. Reads `beaufort.value` from API-injected field. Always polar. Dashboard does NOT compute Beaufort. |
| `weatherRange` | Recharts arearange (default) or columnrange | 15-band temperature color zones. Dual archive fetch (`agg=min` + `agg=max`), `aggregate_interval=86400`. Default Cartesian. Polar ONLY when operator explicitly sets `polar=true`. |
| `haysChart` | Recharts arearange, always polar | Circular 24-hour wind chart (Mount Washington Observatory style). Queries `windSpeed` + `windGust` max. `yAxis_softMax` controls radial scale. |
| `rainTotal` | Standard time-series | Migration tool auto-promotes to `aggregate_type = sumcumulative`. Queries `rain` column. |

These behaviors are triggered by series name in `charts.conf` — they are not further configurable at the component level.

### Wind rose data fetch

The wind rose requires a **separate raw archive fetch** — no `aggregate_interval` — to preserve wind speed distribution for correct Beaufort classification. Read `beaufort.value` from the API-injected field on each archive record. The dashboard does not compute Beaufort from raw wind speed values.

### Weather range chart

Use dual archive fetches: one with `agg=min`, one with `agg=max`, both with `aggregate_interval=86400`. Render as Recharts arearange (default) or columnrange. Render as polar only when `polar=true` is explicitly set in the chart config. The default is Cartesian.

Apply 15-band temperature color zones (°F and °C variants) — deep blue for cold through red for hot, matching Belchertown's `get_outTemp_color()` zones.

### LTTB downsampling

Apply LTTB (Largest-Triangle-Three-Buckets) downsampling client-side for large datasets before passing data to Recharts. This keeps render performance within the INP ≤ 200 ms budget.

### Export

Provide PNG and CSV export per chart. Both exports are client-side operations.

### Grouped-archive charts

Charts with `xAxis_groupby` in their config use `GET /api/v1/archive/grouped` instead of `GET /api/v1/archive`. This endpoint returns calendar-grouped aggregate data (monthly averages, annual summaries). Do not use `/archive` for `xAxis_groupby` charts.

### What belongs in the API, not the dashboard

The computation boundary is strict. The API is the single conversion and enrichment authority. The dashboard does:

- Rendering and presentation-level logic.
- Client-side binning for visualizations (wind rose direction × Beaufort matrix from API-provided fields).
- LTTB downsampling.
- Chart layout, theming, accessibility.

The dashboard does NOT do:

- Unit conversion.
- Beaufort/comfort-index threshold logic.
- Raw SQL queries.
- Provider API calls.

---

## §7 Data Refresh & Realtime

### Stale-while-revalidate

Stale-while-revalidate is the default behavior for all data fetching. `useApiQuery` distinguishes between initial load (no prior data) and background refetch (prior data exists):

| State | `loading` | `refreshing` | UI behavior |
|-------|-----------|-------------|-------------|
| First page load, no data yet | `true` | `true` | Show skeletons |
| Background refetch with existing data | `false` | `true` | Keep showing stale data |
| Fetch complete | `false` | `false` | Update data in place |
| Refetch error with existing data | `false` | `false` | Keep stale data; set `error` |

**`loading=true`** only when `data` has never been populated. Never set `loading=true` on a background refetch where valid data already exists.

**`refreshing=true`** during any in-flight request (initial or background). Cards that want a subtle "updating..." indicator may destructure `refreshing`. No card is required to use it.

**Refetch error:** Stale data stays visible. Do not blank the UI on a failed background refetch. The visitor sees last-known-good data.

### Cold-start splash screen

On a cold start (no prior data in memory — first visit, page reload, direct URL entry on any route), the dashboard shows a branded splash screen (Clear Skies logo, "Loading..." text, spinner) while it fetches `GET /api/v1/current` to resolve the scene. The splash covers the entire viewport at `z-index: 9999` and is defined as static HTML/CSS in `index.html` — no React required.

Once the scene resolves (`sceneLoaded=true`), `AppLayout` calls `dismissSplash()` which fades the splash out over 0.5s and removes it from the DOM. The page behind the splash has the correct theme, correct background photo, and correct weather state — one transition, no corrections.

`/radar` is a child route of `AppLayout` (Phase 5 T5.1 — moved from a top-level sibling route so radar navigation no longer unmounts the shared app shell), so `AppLayout`'s own `dismissSplash()` call covers it. The route component also calls `dismissSplash()` defensively on mount, since `dismissSplash()` is idempotent and this keeps the route resilient to future changes in route nesting.

The `dismissSplash()` utility (`src/lib/dismiss-splash.ts`) is idempotent — multiple calls are safe.

### Scene caching

When the scene resolves, `AppLayout` writes the full scene descriptor (`sky`, `daytime`, `overlay`) to localStorage via `ThemeProvider.cacheScene()`. Three keys:

- `clearskies.scene.daytime` — `"true"` or `"false"`
- `clearskies.scene.sky` — `"clear"`, `"cloudy"`, or `"storm"`
- `clearskies.scene.overlay` — `"rain"`, `"snow"`, or `""`

`getCachedScene()` lives in **one place**: `src/lib/scene-cache.ts`. `useWeatherData.ts` and `useRealtimeObservation.ts` both import it — neither defines its own copy. On page reloads, the cached scene provides a plausible starting state (last-known sky, daytime, overlay) rather than always defaulting to clear-sky night. The splash screen still covers the page until real data arrives, but the cached scene also feeds the background behind the splash, so if the splash timing is tight the fallback is reasonable.

`getCachedScene()` defaults `daytime` to `false` (night) when the `clearskies.scene.daytime` key is absent (first-ever visit) — consistent with `ThemeProvider`'s SSR/cold-start fallback, which also defaults to dark mode.

Each hook reads the cache **lazily, at mount time**, via `useState(() => getCachedScene())` — never as a module-level `const` computed at import time. A module-level constant is frozen the instant the JS bundle loads and never re-reads `cacheScene()`'s later writes, which reintroduces the background-flash bug this pattern exists to prevent (T5.2).

`SceneBackground`'s `visible` prop (default `true`) must be wired to `sceneLoaded` at every call site (`<SceneBackground scene={resolvedScene} visible={sceneLoaded} />` in `AppLayout`). Without it, the background renders at full opacity using the cached/default scene before the first `/current` response arrives, then cross-fades to the real scene — a visible flash on every cold start and route transition, independent of how accurate the cached fallback is.

### Theme initialization

Gate `setDaytime(scene.daytime)` on `sceneLoaded=true`. Before `sceneLoaded`, the theme stays as determined by the `index.html` inline script (localStorage preference or OS `prefers-color-scheme`). The splash screen covers the page during this period.

```tsx
useEffect(() => {
  if (sceneLoaded) {
    setDaytime(scene.daytime);
    cacheScene({ daytime: scene.daytime, sky: scene.sky, overlay: scene.overlay });
    dismissSplash();
  }
}, [scene.daytime, scene.sky, scene.overlay, sceneLoaded, setDaytime, cacheScene]);
```

### Wall-display use case

Do not create a blanking cycle on any interval. Unattended wall-mounted displays must run indefinitely without flashing or going blank. The stale-while-revalidate pattern and the theme initialization gate both serve this requirement.

### `useApiQuery` implementation

- Use `hasDataRef` (a `useRef`) to track whether data has been received at least once.
- Use a `fetcherRef` pattern to avoid stale closures in the polling `useEffect`.
- Use `AbortController` and clean up on component unmount.
- Use a `refetchCounter` for manual refetch triggering.
- Spread the `deps` array into the `useEffect` dependency array.

**Module-level cache (Phase 5 T5.1):** A plain `Map<string, CacheEntry>` at module scope — not React state — persists across component mount/unmount. Callers pass an inline fetcher closure rather than an explicit endpoint string, so the cache key is derived from the closure's stable source text (`fetcher.toString()`) plus `JSON.stringify(deps)`, which uniquely identifies the endpoint and its parameters without requiring every call site in `useWeatherData.ts` to declare an explicit key. On mount, a lazy `useState` initializer reads the cache synchronously so a remounted component (route change, `/radar` navigation, etc.) shows last-known data immediately instead of a loading skeleton, then the effect always fetches (or joins an in-flight fetch) in the background — this is the mechanism that eliminates the full-reload-on-remount problem described in this section's "Stale-while-revalidate" rule. There is no separate "is this cache entry within its freshness TTL" branch: every cache hit is followed by a fetch in the same effect run, so expired data is never served without a refetch already in flight.

**Single-flight request dedup:** A ref-counted `pendingRequests` map (also module-level) shares one in-flight fetch across every simultaneously-mounted hook instance requesting the same key — e.g. `useStation()` called from 6+ components on first Now-page load previously fired 6 identical `GET /station` requests; they now share one. Ref-counting (not a plain boolean) is required because an early unmount from one of several simultaneous callers must not abort the fetch for the others still awaiting it — only the last remaining subscriber's unmount aborts the underlying request.

### `useSSE` hook

The SSE hook subscribes to the event stream at `VITE_SSE_URL` (default `/sse`).

Use `addEventListener("loop", ...)` — NOT `onmessage`. The named event type is `"loop"`. Using `onmessage` will miss all SSE events.

The browser `EventSource` API handles auto-reconnect automatically. Do not implement manual retry logic. The hook reports three statuses: `connecting`, `connected`, `disconnected`.

Skip SSE in mock mode (set `VITE_MOCK_MODE=true` in the build env to disable the live SSE connection for development).

### `useRealtimeObservation` merge

The realtime observation hook maintains a merged view: REST baseline overlaid with SSE updates.

**Merge behavior:**
- REST `GET /api/v1/current` provides the baseline.
- SSE `"loop"` events provide live updates via shallow merge over the REST baseline.
- `dateTime` (epoch integer from SSE) converts to `timestamp` (ISO string) on merge.
- Apply the `WEEWX_TO_OBSERVATION` field map explicitly — do not pass raw loop packet field names to components.

**Special-case plain strings (not `ConvertedValue` shape):**
- `comfortIndex` — plain string (`"windChill"`, `"heatIndex"`, or `"none"`).
- `windDirCardinal` — plain string (16-point compass code).
- `windGustDirCardinal` — plain string (16-point compass code).

Use the `isConvertedValue()` type guard before rendering any field as a `ConvertedValue`.

**`extras` field:** Not updated from SSE. The `extras` object stays at the REST baseline between full REST refetches.

**Scene:** From REST only. SSE events do not update the scene descriptor.

### API client

Use native `fetch` only. Do not add axios, ky, or TanStack Query.

- `fetchApi<T>` is the generic fetch wrapper. It parses `application/problem+json` error bodies.
- `getBranding()` fetches `/branding.json` — a static file served by Caddy — not `/api/v1/branding`.
- All other data comes from `/api/v1/*`.

### Freshness-driven polling

Every cacheable API response carries a `freshness` block (ADR-075 §4):

```json
{
  "data": { "..." : "..." },
  "freshness": {
    "generatedAt": "2026-06-28T02:30:00Z",
    "validUntil": "2026-06-28T03:00:00Z",
    "refreshInterval": 1800
  }
}
```

| Field | Meaning |
|-------|---------|
| `generatedAt` | When the API produced this response (UTC ISO-8601 Z) |
| `validUntil` | When the data should be considered stale. When `Date.now()` exceeds this timestamp, trigger a background refetch. |
| `refreshInterval` | How often the data type typically updates at the source (seconds). Cards that want proactive polling use this as their poll interval. |

`useApiQuery` is extended to schedule refetches from `validUntil`. When `Date.now()` exceeds the `validUntil` epoch, `useApiQuery` triggers a background refetch automatically. Cards do not set their own timers.

No hardcoded `setInterval` for data refresh. A call like `setInterval(fetch, 60_000)` is a banned pattern (§11). All refetch cadence comes from the `freshness` block.

The stale-while-revalidate pattern (§7 existing rule) applies to freshness-driven refetches. Never show skeletons during a background refetch where valid data already exists.

SSE responses and setup endpoints do not carry a `freshness` block — those are push-based or non-cacheable.

### Idle detection

The `useIdleDetector()` hook maintains a single idle state for the entire app tree. It is not per-card.

**Tracked events:** mouse move, keypress, scroll (passive listener), touch (passive listener).

**Provider:** `IdleDetectorProvider` wraps the app tree. Consumer cards call `useIsIdle()` to read the current idle state.

**Idle behavior (ADR-075 §7):**

| Setting | Type | Default | Meaning |
|---------|------|---------|---------|
| `idleTimeout` | integer (minutes) | 30 | Minutes of no interaction before idle mode activates |
| `idleRefreshFactor` | integer | 10 | Multiplier applied to `refreshInterval` during idle |

After `idleTimeout` minutes of no user interaction, all polling cards multiply their `refreshInterval` by `idleRefreshFactor`. A card that normally polls every 30 seconds polls every 300 seconds (5 minutes) while idle.

The SSE connection stays open during idle — it is push-based and has no cost to keeping alive.

Any user interaction (mouse move, keypress, scroll, touch) resets the idle timer and immediately restores normal refresh rates.

Setting `idleTimeout` to `0` disables idle detection entirely. Use this for wall-display and kiosk deployments that must refresh at full rate indefinitely.

`idleTimeout` and `idleRefreshFactor` are served to the dashboard as part of station metadata (populated by the operator via the wizard/admin UI).

---

## §8 Card Plugin Contract

### Card metadata

Every card — built-in and future third-party — declares metadata in a plain data file with no React imports:

- **`type`** — unique string identifier (e.g., `"aqi"`, `"wind-compass"`). The `CardType` is a string literal union of all registered card types.
- **`displayNameKey`** — i18n key (dashboard's `common` namespace, `cards.*`) for the human-readable card name (e.g., `"cards.airQualityIndex"` → `"Air Quality Index"` in English). Metadata carries the key, never a raw English string, per rules/coding.md §6. `card-metadata.ts` has no React imports, so it cannot call `t()` itself — consumers resolve the key through their own translation mechanism (the React admin UI via `useTranslation('common')`; the Python/HTMX admin layout editor via its own i18n layer reading the same key).
- **`apiEndpoints`** — array of API endpoint paths the card needs (e.g., `["/api/v1/aqi/current"]`). Card authors determine these by reading the published OpenAPI spec at `/api/v1/openapi.json`. The container deduplicates across all active cards and fetches each endpoint once.
- **`allowedLayouts`** — array of `{ footprint, rowSpan }` configurations the card supports. A card may render differently for each. The operator selects from this list in the layout editor. Example: `[{ footprint: "tile", rowSpan: 1 }, { footprint: "wide", rowSpan: 1 }]`.
- **`thumbnail`** — path to a static preview image for the admin layout editor (relative to the build output root, e.g., `"/card-thumbnails/aqi.png"`).

The metadata file (`card-metadata.ts`) has **no React imports**. This is enforced by the build-time manifest script importing it in a non-React context.

### Card component props

Every card component receives a uniform props shape:

- **`dataBag`** — `Record<string, any>` keyed by API endpoint path. The container populates the bag by fetching all unique endpoints declared by active cards. Each card extracts the specific fields it needs internally. The loose typing is deliberate: a strongly-typed bag would require the container to know every endpoint's response shape, re-coupling page and card.
- **`layout`** — `{ footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`. The active layout configuration for this card instance, selected by the operator via the layout editor.
- **`stationTz`** — IANA timezone string from station metadata.

**`stationClock` in dataBag:** Every API response stored in `dataBag` includes `stationClock` and `freshness` blocks at the response envelope level (ADR-075 §3–4). A card that needs station-date logic reads `stationClock.date` from its response data via `getStationDate()` from `utils/station-clock.ts`. Cards must not use `new Date()` to determine the station-local date. Example:

```typescript
// Inside ForecastCard component
const forecastData = dataBag["/api/v1/forecast/daily"];
if (!forecastData) return <CardSkeleton />;
const stationDate = getStationDate(forecastData);
// Compare entry.validDate === stationDate, not index === 0
```

Each card handles its own loading and error states based on whether its required data is present in the bag.

### Card registry

The card registry (`card-registry.ts`) combines metadata with lazy React component references. It provides:

- `getCard(type)` — returns the full registration (metadata + component) for a card type.
- `getAllCards()` — returns all registered cards.
- `getBuiltinCards()` — returns only built-in cards (excludes future v2 custom cards).
- `getEndpointsForCards(types)` — collects and deduplicates all API endpoints for a set of card types.

### Build-time card manifest

A prebuild script reads only the metadata file (no React) and writes `card-manifest.json` to the build output (`dist/`). This JSON artifact contains all card metadata (type, displayNameKey, apiEndpoints, allowedLayouts, thumbnail path) and is consumed by the admin card layout editor (Python/HTMX) — no React required. The script runs as a `"prebuild"` entry in `package.json`, before `tsc -b && vite build`.

### Self-extraction pattern

Cards extract their own data from the data bag using their declared endpoint paths. The extraction logic lives inside the card component, not in the page container. This is the key architectural invariant: the container does not know what data each card needs or how it renders. Example pattern:

```
// Inside AqiCard component
const aqiData = dataBag["/api/v1/aqi/current"];
if (!aqiData) return <CardSkeleton />;
// ... render using aqiData
```

### 15 built-in cards

All 15 Now page cards conform to the plugin contract. Their card types, endpoint declarations, and allowed layouts match the current hardcoded arrangement in `now.tsx`. The full inventory is defined in `card-metadata.ts`. The marine-summary card (added in Phase 7) self-hides when no marine locations are configured.

### Attribution rendering

Attribution is a host responsibility — cards must NOT import attribution components.

The host page (Now page, Forecast page) reads `source` from the card's dataBag response, matches it against the capabilities API's `attribution` block, and renders a `ProviderAttribution` component when `attributionRequired` is true. The component lives at `src/components/shared/ProviderAttribution.tsx`.

**Content area budget:** Card designers must account for the attribution footer consuming vertical space within the card:

| Footprint | Footer height | Use |
|---|---|---|
| Standard (wide/full) | 53px | All non-tile cards |
| Compact (tile) | 23px | Tile-sized cards |

**Single-provider-per-card guidance:** Each card should source data from a single provider. Multi-provider cards create ambiguous attribution. If unavoidable, the host renders a combined single-line footer.

**i18n:** When `textTranslatable` is false (all providers in v0.1), the component renders `attributionText` verbatim — never passed through `t()`.

---

## §9 Dynamic Now Page & Page Visibility

### Now page as container

The Now page is a generic container that renders cards from a layout configuration:

1. Fetch the layout config via `fetchNowLayout()` on mount (fetches `/now-layout.json`; falls back to `DEFAULT_NOW_LAYOUT` on 404 or parse error).
2. Look up each card in the card registry.
3. Collect all unique API endpoints from active cards via `getEndpointsForCards()`.
4. Fetch each unique endpoint once, build the data bag.
5. Render cards in layout order: for each entry, render `card.component` with `{ dataBag, layout, stationTz }`.
6. The NowHeroCard renders outside the grid unconditionally — it is a layout element, not a configurable card.

**React hooks constraint:** All data-fetching hooks must be called unconditionally at the top of the component (React rules of hooks). Endpoints not needed by the active card set use skip/enabled flags on hooks — never conditional hook calls. `tsc --noEmit` catches hook ordering violations.

### Layout config types

- `NowLayoutEntry` — `{ type: CardType; footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`.
- `NowLayoutConfig` — `{ version: 1; cards: NowLayoutEntry[] }`.
- `DEFAULT_NOW_LAYOUT` — compiled-in constant matching the current hardcoded card arrangement (15 cards, current sizes and order). Used when `/now-layout.json` is absent or unparseable.

### Layout config fetch

`fetchNowLayout()` fetches `/now-layout.json` from Caddy. On 404 or parse error, returns `DEFAULT_NOW_LAYOUT`. Never throws. Cards not in the layout don't render — this is how operators hide individual Now page cards.

### Page visibility

The dashboard reads `/pages.json` at boot to determine which pages are visible. Format: `{ "hidden": ["seismic", "reports"] }`. Absent file or parse error = `{ "hidden": [] }` (all pages visible).

**Navigation filtering:** `NAV_ITEMS` in the nav rail and mobile bottom nav are filtered by the visibility config. Hidden pages are removed from navigation. "Now" is never filtered — it is always visible regardless of the config.

**Route filtering:** Routes for hidden pages render the 404 (Not Found) page. Hidden pages are not merely absent from navigation — they are unreachable.

**"Now" protection:** The dashboard ignores "now" if present in the hidden list. This is enforced independently of the admin UI's disabled checkbox — defense in depth.

### Branded 404 page

The Not Found page (`not-found.tsx`) renders:

- Operator logo (theme-aware, from `useBranding`).
- A weather-themed pun (randomly selected from a built-in array of 8–10 options).
- "Back to Now" link.
- WCAG AA compliant (contrast, heading hierarchy, keyboard focus).

---

## §10 Radar Card & Expanded View

### Radar card (Now page)

The radar card renders an animated XYZ tile map using Leaflet. Both RainViewer and LibreWxR use the same XYZ tile animation pattern — no WMS-T rendering is involved.

**Tile fetching by provider:**

| Provider | Tile source | Frame metadata source |
|---|---|---|
| `librewxr` | Caddy proxy (`/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`) | API `GET /api/v1/radar/providers/librewxr/frames` |
| `rainviewer` | Direct to CDN (`{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png`) | API `GET /api/v1/radar/providers/rainviewer/frames` |

Tile URL templates come from the API capability response. The dashboard does not hardcode tile paths.

**Expand button:** Phosphor `ArrowsOut` icon in the card header. Navigates to `/radar` (pushes to browser history). Opens the expanded view at the same zoom level and center as the card.

**Frame progress bar (FrameProgressBar component):**
- Replaces the old `<input type="range">` slider (expanded view) and text-only "Frame X of Y" counter (card view).
- Used in BOTH card view and expanded view.
- 6px track with a 12px playhead dot.
- Color-coded: past frames use muted foreground color; nowcast/forecast frames use the primary accent color.
- Vertical tick mark at the past/nowcast boundary.
- Clickable to seek to any frame.
- Keyboard accessible: `role="slider"`, ArrowLeft/ArrowRight to step between frames.
- "Forecast" text label hidden on mobile (`hidden md:inline` / `hidden md:block`) to prevent word-wrap on narrow viewports.

**Animation:**
- Adaptive speed: target ~15-20 second loop regardless of frame count. LibreWxR with 24+ frames and RainViewer with ~13 frames should both feel smooth.
- Card view caps at ~24 most recent frames.
- Nowcast frames visually distinguished via the FrameProgressBar color coding (accent color for nowcast/forecast segment).

**Provider-adaptive legend:** Legend gradient reflects the active provider's color scheme. Updates when the color scheme changes (LibreWxR only — RainViewer has a single scheme). Uses `z-[1001]` to render above Leaflet's internal control panes (z-1000).

**Attribution:** Displayed per PROVIDER-MANUAL.md §7. Both the Leaflet attribution control and any below-card caption must agree.

### Live refresh

Periodically re-fetch frame metadata to pick up new frames as they become available. Drop oldest frames to maintain the cap. The animation loop always shows the latest data, not a stale snapshot from page load.

- Refresh interval: from API capability response `refresh_interval` field (operator-configurable, default 600 seconds).
- On new frames: seamlessly append to the animation loop, drop oldest to maintain cap.
- Applies to both card view and expanded view.

### Idle timeout

Stop animation, tile fetching, and live refresh after 60 minutes of no user interaction (mouse, touch, keyboard, scroll). Resume on interaction.

- **Tab visibility:** Pause immediately when the browser tab is hidden (Page Visibility API). When the tab becomes visible again, refresh frame metadata before resuming animation (data may have changed while hidden).
- Applies to both card view and expanded view.
- Purpose: prevent idle/hidden tabs from generating continuous load against the provider.

### Expanded radar view (`/radar`)

Full-viewport overlay with enhanced controls. Pushed as a SPA route (`/radar`) for bookmarkability — Caddy `try_files` handles it. Not a new "page" in the page taxonomy; it's an overlay that opens from the radar card.

**Overlay behavior:**
- Full viewport (100vw × 100vh).
- Opens at the same zoom level and center as the card — it provides room for controls and readable detail, not a different map.
- Close button (top-right, Phosphor `X`) + Escape key closes. Returns to the previous page.
- Focus trap for accessibility (Tab/Shift-Tab cycles within the overlay).
- Direct navigation to `/radar` renders the expanded view at the provider's default center/zoom.

**Time slider (bottom bar):**
- FrameProgressBar component (same as card view) replaces the old `<input type="range">` slider.
- Play/pause button, speed control (0.5x, 1x, 2x).
- Current timestamp display (formatted in station timezone).
- Nowcast frames visually distinguished via FrameProgressBar color coding (accent color segment).
- Drives the same XYZ tile animation as the card.

**Layer/config panel:**
- Sidebar on desktop (right side), bottom sheet on mobile (drag handle, half-height default).
- Provider-adaptive: shows controls relevant to the active provider.
- Collapsible/expandable. State persists in localStorage.

**Color scheme picker (LibreWxR only):**
- 13 color schemes displayed as a grid with swatch preview.
- Selection updates the `color` path segment in tile URLs + legend.
- Hidden when provider is RainViewer.
- Selected scheme persists in localStorage.

**Opacity slider:**
- 0-100%, default 70%.
- Affects radar tile layer opacity only (base map unaffected).

**Alert polygon overlays (LibreWxR only):**
- Fetched from LibreWxR `/v2/alerts` via Caddy (URL from capability response).
- Query by map viewport bounding box (`?bbox=west,south,east,north`) derived from the provider's bounds.
- Rendered as Leaflet GeoJSON polygons — severity-colored (stroke + fill per WMO CAP severity).
- Auto-refresh every 5 minutes.
- Toggle on/off in layer panel (default: on).
- Only available when provider is LibreWxR. Hidden for RainViewer.
- **Popup positioning:** Uses `leaflet-responsive-popup` (npm dependency) instead of the native `L.Popup`. The plugin automatically opens the popup in whichever direction has the most available space — below when near the top edge, shifted left/right when near side edges — without scrolling or panning the map. `autoPan: false` is set explicitly.
- **Popup trigger:** A single map-level click handler (not per-polygon binding) locates all alert polygons whose geometry contains the click point, using ray-casting point-in-polygon testing against each candidate polygon's coordinates. This replaces per-polygon click binding so overlapping alerts at the same point are all detected in one pass.
- **Popup content (single alert):** Severity-color accent bar, bold title (headline) shown by default. A `▼` toggle button expands to reveal severity, full NWS description, affected regions, and expiry timestamp. The detail section has `max-height: 250px` with `overflow-y: auto` for long descriptions. The `▲` button collapses back to title-only. Toggle symbols are unicode (no i18n needed).
- **Popup content (multiple overlapping alerts):** When the click point falls inside more than one alert polygon, the popup shows the same single-alert content (accent bar, title, expand/collapse detail section) for the active alert, plus a navigator row at the bottom: prev/next arrow buttons, severity-colored pips (one per alert, active pip enlarged) indicating position, and a "1 of N" label. Alerts are ordered most-severe-first. Prev/next navigation wraps circularly (next from the last alert returns to the first, and vice versa). All navigator strings use i18n keys under the `radar` namespace (`alertPopup.*`).

**Wind arrows (LibreWxR only):**
- Rendered via `?arrows=light` or `?arrows=dark` query parameter appended to radar tile URLs by `buildTileUrl()`. LibreWxR composites directional wind barbs onto each radar frame at render time. Not a separate tile layer.
- Arrow style adapts to background visibility: `light` (white arrows) when satellite is active or dark theme is active; `dark` (dark arrows) when using a light-theme basemap.
- Toggle on/off in layer panel (default: off).
- Only available when provider is LibreWxR (detected via `capability.caddyPrefix`).

**Satellite imagery layer (LibreWxR only):**
- Toggleable layer in the expanded radar view. Toggle labeled "Satellite imagery" in the `RadarLayerPanel`.
- Only shown when the API capability response reports `satelliteAvailable === true`.
- When satellite is active, nowcast (radar extrapolation) frames are excluded from the radar animation — only past/current radar frames animate alongside satellite. This ensures both layers have matching frame counts (24 each) and consistent animation cadence.
- Satellite TileLayers render BELOW radar tiles (zIndex 100) with independent animation sharing play/pause state.
- Tile URL pattern: `{caddyPrefix}/{path}/{size}/{z}/{x}/{y}/0/0_0.webp` (from `satelliteTileUrlTemplate` on the capability response).
- **Primary sources:** GOES-18/19 ABI (Americas, 2 km, 5-min) and Himawari-9 AHI (Asia-Pacific, 2 km, 10-min). **Global fallback:** NOAA GMGSI composite (8 km, hourly, ±72.7° latitude).
- **Rendering:** GOES/Himawari tiles are rendered opaque — white clouds on a dark ground, alpha=255 for all data pixels, alpha=0 for no-data only. GMGSI tiles use the legacy semi-transparent RGBA renderer (alpha ~172/255) designed for overlay on a basemap.
- **Basemap swap:** When satellite is enabled, the basemap switches from OSM/CartoDB to CartoDB `light_only_labels` overlay (light text on transparent background) — showing state boundaries, city names, roads, and water labels over the satellite imagery. Light labels are used in both themes because satellite imagery is always dark. When satellite is disabled, the normal OSM/CartoDB basemap returns.
- **Radar toggle:** Radar tiles can be toggled on/off independently via the `RadarLayerPanel`, allowing satellite-only or satellite+radar views. Default: on. State persisted to localStorage key `clearskies-radar-show`.
- **512px tile optimization:** Satellite TileLayer uses `tileSize={512}` and `zoomOffset={-1}`, reducing tile requests 4x compared to default 256px tiles while maintaining the same pixel density.
- **Pre-warming:** LibreWxR's tile warmer pre-renders satellite tiles at zoom levels matching the dashboard viewport (configured via `warm_overview_zoom_regional`) after each ingest cycle. On cache miss, demand-driven warming pre-renders all timestamps at the same tile coordinate, so subsequent frames are immediate cache hits.
- **Default configuration:** IR-only (VIS disabled via `LIBREWXR_GOES_VIS_ENABLED=false`). IR provides all-weather satellite imagery at 2 km resolution. VIS can be enabled for daytime cloud edge detail.
- Preload mechanism: static first frame is rendered initially until tiles are cached, preventing tile flickering during animation.
- Staleness guard: frames older than 24 hours are filtered out (LibreWxR public API satellite pipeline sometimes goes stale).
- **Animation strategy:** All tile layers remain mounted during animation with `visibility: hidden` on inactive frames (no mount/unmount churn). Client-side tile prefetching via `new Image()` populates the browser HTTP cache before animation starts, ensuring smooth playback without mid-animation tile fetches.
- State persisted to localStorage key `clearskies-radar-satellite`.

**Geographic features vector tile overlay (ADR-078):**
- Rendered as a `protomaps-leaflet` Canvas-based vector tile layer when satellite view is active. NOT shown on normal basemap view (basemap already has roads/boundaries).
- Data source: `GET /api/v1/geographic-features/tiles` — PMTiles file served with HTTP Range requests. Browser loads only tiles visible in the current viewport (~20-50 KB per tile, on-demand).
- npm packages: `protomaps-leaflet` (Canvas renderer) + `pmtiles` (Range-request tile reader).
- Rendering: `protomapsL.leafletLayer()` with custom `paintRules` (lines only) and empty `labelRules` (no labels). No full basemap — only geographic feature lines.
- Availability check: `GET /api/v1/geographic-features/status` — if `available` is false (PMTiles not yet downloaded), no overlay is added. Not an error state.
- Per-type line styling (`LineSymbolizer`, no fill):
  - Boundaries: `color: '#ffffff'`, `width: 1.5`, `opacity: 0.7`
  - Roads: `color: '#999999'`, `width: 1`, `opacity: 0.5` (filtered to `pmap:kind` highway/trunk)
  - Water: `color: '#4a90d9'`, `width: 1`, `opacity: 0.6`
- Non-interactive — no popups, no hover, just visual context.
- Replaces the CSS blend-mode hack (`SATELLITE_FEATURES_URL` + `dark_nolabels` TileLayer + `.satellite-features` class in `index.css`). The hack is removed entirely.
- Attribution: "© OpenStreetMap contributors (ODbL)".

**Zoom bounds enforcement:**
- Read geographic bounds from API capability response.
- Set Leaflet `maxBounds` to prevent zooming out past provider coverage.
- No bounds configured = allow global zoom (default behavior).

### WCAG 2.1 AA requirements for radar

- Expanded overlay: `role="dialog"`, `aria-modal="true"`, focus trap.
- All controls keyboard navigable (Tab, Enter, Space, Arrow keys).
- Time slider: Arrow keys move between frames, value announced via `aria-valuenow` / `aria-valuetext`.
- Frame changes: `aria-live="polite"` region announces current timestamp.
- `prefers-reduced-motion`: pause animation automatically, reduce transitions.
- All interactive elements: visible focus indicator, ≥44px tap targets on mobile.
- axe-core: 0 violations on both card and expanded view.

**Background content must be inert while radar is open (Phase 5 T5.1):** `/radar` is a child route of `AppLayout` (§1, §7), so `NavRail`, `Footer`, the alert banner, and `SkipLink` stay mounted in the DOM while the radar overlay covers them via z-index. z-index stacking alone does not remove background content from the keyboard tab order or the accessibility tree, which would let a keyboard or screen-reader user reach navigation "behind" the open `aria-modal="true"` dialog — a real gap, not a theoretical one, since `aria-modal` support for auto-hiding background content is inconsistent across assistive technology. `AppLayout` derives `isRadarOpen` from the route and passes a `hidden` prop to `NavRail`, `Footer`, and `SkipLink` (and applies `aria-hidden`/`inert` directly to the alert-banner wrapper div) so all four are marked `inert` + `aria-hidden` whenever `/radar` is the active route. This mirrors the `inert={!visible}` pattern `NavRail` already used for its own auto-hide state.

---

## §11 Anti-Patterns

Never do the following in dashboard code.

**Never compute Beaufort, comfort index, or unit conversion in the dashboard.**
The API is the single conversion and enrichment authority. The dashboard renders `value` and `label` from `ConvertedValue` shapes. Beaufort thresholds, unit conversion factors, and comfort index selection logic live in the API's enrichment pipeline.

**Never display local-time strings from the API.**
The API emits UTC ISO-8601 with `Z`. Use `Intl.DateTimeFormat` with the station IANA time zone identifier from `StationMetadata` to format all timestamps for display.

**Never call `toLocaleString()` without an explicit `timeZone` option.**
Calling `date.toLocaleString()` with no options uses the visitor's browser time zone, not the station time zone. Always pass `{ timeZone: stationTimezone }`.

**Never show skeletons during background refetches.**
Check `loading` (not `refreshing`) before rendering a skeleton. `loading` is `true` only on genuine first load. Once data exists, background refetches must show stale data, not blanked cards.

**Never create chart-type-specific API calls.**
Use the general-purpose `/archive` and `/archive/grouped` endpoints with config-driven parameters. Do not add API endpoints that exist solely to serve a particular chart type's data shape.

**Never hardcode unit strings.**
Render the `label` field from the `ConvertedValue` shape the API returns. Never write `"°F"`, `"mph"`, `"inHg"`, or any other unit string directly in component code.

**Never gate theme initialization on the cached/default scene.**
The theme system must wait for `sceneLoaded=true` before calling `setDaytime`. Gating on the cached fallback causes a flash-then-correct-theme sequence on every page load.

**Never hardcode a fallback `SceneDescriptor` inline, and never define a second `getCachedScene()`.**
The one and only `getCachedScene()` lives in `src/lib/scene-cache.ts` and must read from the localStorage scene cache. Hardcoding `{ sky: 'clear', daytime: false, overlay: null }` at a call site, or writing a second local copy of `getCachedScene()`, reintroduces the T5.2 background-flash bug (two independently-drifted implementations disagreed on the daytime default). The cache provides the last-known scene, which is almost always still correct on page reload.

**Never compute the cached scene fallback as a module-level constant.**
A `const SCENE_DEFAULT = getCachedScene()` computed at module import time is frozen forever — it never re-reads later `cacheScene()` writes. Call `getCachedScene()` lazily, at mount time, via `useState(() => getCachedScene())` inside the consuming hook.

**Never leave `SceneBackground`'s `visible` prop unwired.**
`visible` defaults to `true`. Every call site must pass `visible={sceneLoaded}` (or equivalent) — otherwise the background renders at full opacity using the default/cached scene before the first `/current` response arrives, then cross-fades to the real scene, producing a visible flash.

**Never render themed or weather-dependent content before the scene resolves on cold start.**
The splash screen covers the page until `sceneLoaded=true`. Do not remove the splash early, bypass it, or render page content above it. The visitor must see one transition: splash → fully resolved page. Multiple visible corrections (wrong theme → right theme, wrong background → right background) look amateur.

**Never use `onmessage` for SSE loop events.**
The SSE stream uses a named event type `"loop"`. Use `addEventListener("loop", handler)`. `onmessage` only fires for unnamed events and will silently miss all weather data updates.

**Never implement manual SSE retry logic.**
The browser `EventSource` API reconnects automatically. Manual retry logic duplicates reconnect behavior and can cause double-subscriptions.

**Never pass raw loop packet field names to components.**
Apply `WEEWX_TO_OBSERVATION` field mapping on merge. Components receive observation field names, not weewx internal names.

**Never share data fetches between cards via page-level props.**
Each card owns its data. A card that needs archive data calls `useArchive` internally with its own parameters (`fields`, `aggregate_interval`, time window). Pages do not fetch archive data and pass it down. This keeps cards self-contained — a developer working on one card does not need to understand or coordinate with the page's data plumbing. Cards that only need a sparkline should use `aggregate_interval` to downsample; cards that need accurate peaks/sums (e.g. today's hi/lo) fetch raw records. Shared hooks like `useRealtimeObservation` (SSE-backed, singleton connection) are the exception — those are inherently global.

**Never read page visibility from the API.**
Page visibility is a static config (`/pages.json`) served by Caddy. The API's `GET /pages` returns all 9 built-in pages unconditionally — it does not filter. The dashboard reads `/pages.json` at boot and filters navigation and routes locally. Do not add API logic for page hiding.

**Never bypass the card plugin contract on the Now page.**
All Now page cards must conform to the card plugin contract (§8). Do not add cards to the Now page by directly importing components and passing specific props — use the card registry and data bag pattern. The Now page container does not know what data each card needs.

**Never use `new Date()` to determine station-local date or time.**
`new Date()` returns the visitor's browser-local time, not the station's time. Use `stationClock.date` from the API response for all date-boundary logic. `Date.now()` is approved for UTC epoch elapsed-time math and display ticks (arc position updates, "last updated N seconds ago") — mark those uses with `// ADR-075: display tick, not data refresh`.

**Never use `.toISOString().split('T')[0]` to derive a station-local date.**
`toISOString()` returns UTC. Splitting it at `'T'` gives a UTC date, which differs from the station-local date near midnight. Use `stationClock.date` from the API response instead.

**Never use array index as a proxy for "today" in forecast or date-ordered lists.**
`index === 0` means "first in the array," not "today." When the provider has already rolled to tomorrow's forecast, the first entry is tomorrow, not today. Compare `entry.validDate === stationClock.date` using `isStationToday()` from `utils/station-clock.ts` instead.

**Never hardcode `setInterval` for data refresh without referencing freshness.**
Each API response carries `freshness.validUntil` (when to refetch) and `freshness.refreshInterval` (the data type's update cadence). Use these fields to drive refresh timing via `useApiQuery`. Magic numbers like `60_000` or `300_000` in a data-refresh `setInterval` are a violation.

**Never use `Date.now()` for "is it daytime?" checks outside station-clock utilities.**
Daytime status comes from the scene descriptor or `stationClock`, not browser-local time. Any daytime determination that does not use the station timezone or `stationClock` is a banned pattern.

---

## §12 Marine Activities Page

Single page at `/marine` — map-based landing with operator-configured locations, activity details in tabs (desktop ≥768px) or accordions (mobile <768px). Location selection is client-side state, not a URL path parameter.

### Route

| Route | Page | Lazy-loaded |
|---|---|---|
| `/marine` | Marine Activities | Yes |

### Page header

Page header uses `PageHeaderCard` with `icon={<Waves weight="duotone" />}` (Phosphor duotone, same visual weight as Forecast page's `CloudSun`). No explicit `className` on the icon — `PageHeaderCard` sizes it via the container's font-size (3.75rem).

### Activity icons

| Activity | Icon source | Icon |
|---|---|---|
| Boating | Phosphor | `Sailboat` |
| Surfing | Material Symbols (inline SVG) | `surfing` |
| Fishing | Phosphor | `FishSimple` |
| Beach Safety | Phosphor | `PersonSimpleSwim` |

Follows existing icon convention: Phosphor for utility/nav/alert, inline Material Symbols SVG for domain-specific glyphs (per ADR-049/050). Main nav item: Phosphor `Waves`, label "Marine". The Now page marine summary card (`marine-summary-card.tsx`) uses the same `Waves` icon for consistency.

### Page states

#### Landing state (no location selected)

Map and LocationCards are direct children of the `PageLayout` Grid — no internal grid wrappers.

**Map (`footprint="full"`):**
- Interactive Leaflet/OpenStreetMap map spanning all 4 Grid columns at lg
- Numbered `L.divIcon` pins — each location gets a 1-based index number
- Pin style: 24×24px circle, `background: var(--primary)` (operator accent color), white centered number text (12px, weight 600)
- Alert locations: amber circle (`background: #f59e0b`) with number
- OpenSeaMap tile overlay (`tiles.openseamap.org/seamark/{z}/{x}/{y}.png`, opacity 0.7) renders marine features (buoys, channels, harbors, depth contours)
- Linked hover: pin `mouseover` → highlights corresponding LocationCard (`ring-2 ring-primary`), pin scale 1.3× when its card is hovered
- Map height adapts to site geography via aspect ratio computation:
  - Compute bounding box from location coordinates, adjust longitude span by `cos(centerLat)`
  - `aspect ≥ 0.8` (horizontal spread): map full-width above cards, height 400px
  - `aspect < 0.8` (vertical spread): at lg, map as `footprint="panel"` (3 columns) with cards stacked in 1 column; height 600px. Below lg: stacked (map on top)
- `LocationMap` accepts `height: number` prop — no hardcoded CSS class for height

**LocationCards (each `footprint="tile"`):**
- Uses `Card` component from `components/ui/card.tsx` with `footprint="tile"` — placed as direct Grid children
- At lg (1024px+): 4 cards per row; md (768px+): 2 per row; mobile: 1 per row (stacked)
- Click-to-select button inside the Card (not the Card itself)
- Each card contains:
  - **Number badge**: small circle (20×20px), `bg-primary text-primary-foreground`, showing same number as the map pin. Top-left area near location name.
  - **Location name**: prominent, `var(--text-body)` size
  - **Hero weather icon + air temp**: `WeatherIcon` component (28px) + temperature when `weatherCode` is non-null. No icon when `weatherCode` is null (no empty placeholder). Temperature uses `var(--text-stat-tile)`, `fontFeatureSettings: '"tnum"'`.
  - **Stat row** (`<dl>` grid with `MarineStatTile` or inline stats):
    - Wave height: Phosphor `Waves` icon (12px) + formatted value
    - Wind: Phosphor `Wind` icon (12px) + formatted value (knots)
    - Water temp: Phosphor `Thermometer` icon (12px) + formatted value
    - All icons decorative (`aria-hidden`, `focusable="false"`), 12px matching `--text-label`
  - **Alert badge**: amber alert count badge when `alerts > 0`
  - **Location photo** (when `photoUrl` non-null): right ~40% of card, `object-fit: cover`, clipped to card's right border-radius. Gradient overlay where text meets photo: `linear-gradient(to right, rgb(var(--card-glass)) 55%, transparent 100%)`. Card layout switches to `flex-row`. When no photo: text-only layout (`flex-col`). `alt={location.name}`. Photo pane is `hidden` below the `sm` (640px) breakpoint — a "tile"-footprint card is too narrow on mobile to spare 40% of its width without crowding the stat row; content-only `flex-1` button fills the full width instead.
- No "Updated X minutes ago" — removed per finding F12
- No "Use my location" button — removed per finding F11
- Linked hover: `onMouseEnter` → highlights corresponding map pin (scale 1.3×), `onMouseLeave` → resets. When hovered (by card hover or pin hover): `ring-2 ring-primary bg-foreground/5`.

#### Selected state (location chosen)

**Combo card (`Card footprint="full"`):**
- Replaces the 120px hero map strip
- Interior layout: `flex-row` at md+, `flex-col` on mobile
- Left ~60%: `LocationMap variant="hero"`, height 220px, zoomed to single location at zoom 14-15 (coastal features visible — pier, harbor, breakwater). Only the selected marker rendered. OpenSeaMap overlay active. No fly-to animation on initial render.
- Right ~40%: `<img src={selectedLocation.photoUrl}>` with `object-fit: cover`, clipped to card's right border-radius. `alt` = location name.
- No photo: map takes full width, height 220px
- Mobile: map full width 180px, photo below or hidden

**Activity tabs (≥768px) / accordions (<768px):**
- Tab headers: activity icon + name + qualitative label
- All tab content uses official `Card` / `CardHeader` / `CardTitle` (with `as` prop for heading level) / `CardContent` components — no hand-rolled `Panel` functions
- Shared `MarineStatTile` component (from `components/marine/shared/MarineStatTile.tsx`) for all stat displays — no per-tab duplicates
- All text scrolls with the page — no `position: fixed` or `position: sticky` on tab content elements

### Activity qualitative labels

Tab/accordion headers show activity-appropriate qualitative labels — not forced into a common scale:

| Activity | Label source | Scale |
|---|---|---|
| Boating | Wind/wave/visibility thresholds | Excellent / Good / Fair / Poor / Dangerous |
| Surfing | Surf quality scorer (1–5 stars) | Star display (★★★☆☆) + `qualityLabel` |
| Fishing | Fishing scorer (0–100) | Excellent (80+) / Good (60–79) / Fair (40–59) / Poor (<40) |
| Beach Safety | Itemized hazards (no overall badge) | Individual hazard indicators — no collapsed "Safe/Dangerous" |

### Tab content — Boating (F21 redesign)

Unified conditions dashboard pattern (Windfinder/My Marine Forecast reference). All data from enriched API detail endpoint (§18 enrichment contract). Uses `Card` / `CardHeader` / `CardTitle as="h3"` / `CardContent` throughout.

**Panel order (top to bottom):**

1. **Alerts** — `AlertsPanel` (shared, unchanged)
2. **Current Conditions** — `Card footprint="full"`:
   - `<dl>` grid of `MarineStatTile` components: wind speed + gust + direction, air temp, water temp, pressure + trend indicator (`PressureTrend` component), water level offset (from tide compositor), storm surge badge (when `stormSurgeLevel` non-null)
   - When ALL fields null: "Conditions unavailable" message
3. **Waves** — `Card footprint="full"`:
   - Wave stats (height, period, direction) as `MarineStatTile` tiles at top
   - 72h wave forecast chart below (`WaveForecastChart` with legend)
   - Wave data from NWPS/model sources (not buoy)
   - Self-hides for harbor locations where wave data is null
4. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` (left margin ≥40px to prevent clipping, XAxis domain starts at first data point)
   - Total water level overlay when compositor data available
5. **Marine Forecast** — `Card footprint="full"`:
   - Structured columns following `DailyColumns` pattern (from `ForecastDailyCard`)
   - Each period column: period name, wind (speed + direction icon), seas (wave height text), visibility, weather text
   - `HorizontalScrollNav` for horizontal scrolling
   - NOT expandable `<details>/<summary>` text blobs

**Removed from BoatingTab:** "Nearest Offshore Buoy" panel (F21b), "Weather at {location}" panel (duplicate of conditions), standalone wind forecast chart (wind consolidated into Conditions).

### Tab content — Surfing (F22 redesign)

Surfaces the surf scoring system (`enrichment/surf_scorer.py`). Hero conditions summary pattern.

**Panel order:**

1. **Alerts** — `AlertsPanel`
2. **Current Conditions Hero** — `Card footprint="full"`:
   - `conditionsText` from `SurfForecast` as headline (large text, full width) — the composed natural-language summary (e.g., "3-4 ft at 12 seconds from the SSW. Offshore winds 5-10 mph. Clean conditions.")
   - Star rating badge + `qualityLabel` ("Poor" / "Fair" / "Good" / "Very Good" / "Epic") with `qualityColorClasses`
   - Stat grid: wave height at break (`waveHeightAtBreak`), period, direction compass, `windQuality` badge ("Offshore"/"Glassy"/"Cross-shore"/"Onshore" with color), water temp
   - Rip current risk as status badge (from `zoneForecast.ripCurrentRisk`)
3. **Scoring Breakdown** — `Card footprint="full"`:
   - 4 horizontal bars showing weighted factors: Wave Height (35%), Wave Period (35%), Wind Quality (20%), Swell Dominance (10%)
   - Each bar: label, score, colored fill proportional to score using gauge color tokens (`--gauge-fill`, `--gauge-unfill`)
   - Beach alignment and directional exposure shown as multipliers
4. **72-Hour Surf Forecast Timeline** — `Card footprint="full"`:
   - `HorizontalScrollNav` with star-rated time slots (`ForecastTimeline` with multi-point data from `GET /surf/{id}`)
   - Wave face height chart below the timeline
   - Each slot: time, star rating, quality color
5. **Swell Components** — `Card footprint="full"`:
   - Each swell component as a row, ranked by energy (primary → secondary → wind swell)
   - Primary swell visually larger (more padding, larger text)
   - Per component: classification badge ("Groundswell"/"Swell"/"Wind Swell" with color), direction arrow (8px rotated icon), height, period with quality tier ("14s — Great"; tiers: 8s=normal, 11s=good, 14+=great), energy value
6. **Swell Direction Compass** — `SwellDirectionCompass` component:
   - SVG `viewBox="0 0 420 420"` matching `WindCompassCard` visual pattern
   - 72 ticks every 5° (outer radius 175, tick length 24px)
   - Ticks within ±8° of swell direction lit with `--chart-2` color
   - Cardinal labels (N/S/E/W), center overlay: direction degrees + cardinal text, dominant height + period
   - Render at ~160×160px within Card content
7. **Tide Forecast** — `Card footprint="full"` with `TideChart`

**Removed:** Standalone "Conditions" card (consolidated into hero), standalone rip current alert banner (rip current becomes condition badge).

### Tab content — Fishing (F23 redesign)

Surfaces the fishing scoring system (`enrichment/fishing_scorer.py`). Hero conditions summary + solunar display matching Almanac page quality.

**Panel order:**

1. **Alerts** — `AlertsPanel`
2. **Current Conditions Hero** — `Card footprint="full"`:
   - `conditionsText` from `FishingForecast` as headline (e.g., "Good fishing. Falling pressure and incoming tide favor activity.")
   - Overall score (0-100) as prominent numeric display
   - Stat grid: pressure + trend, tide state, wind speed, water temp
3. **Scoring Breakdown** — `Card footprint="full"`:
   - 4 horizontal bars: Pressure (37.5%), Tide (31.25%), Solunar (18.75%), Time (12.5%)
   - Each bar: label, score (0-100), colored fill (green >60, amber 30-60, muted <30)
   - Click/tap each bar for explanation text
4. **Forecast Periods** — `Card footprint="full"`:
   - Structured columns following `DailyColumns` pattern
   - Each period: time window, overall score, color-coded
   - `HorizontalScrollNav` for scrolling
5. **Solunar Calendar** — `Card footprint="full"`:
   - Uses `MoonPhaseIcon` from `components/moon-phase-icon.tsx` (same component as Almanac page)
   - Major/minor feeding periods as time windows on a horizontal timeline
   - Moon phase icon + illumination percentage
   - Arc visualization similar to `SunMoonDetailCard` sun/moon arc styling
   - Major periods: accent color bars. Minor periods: muted color bars. Current time indicator.
6. **Species Forecast** — `Card footprint="full"`:
   - Data table with `<thead>/<tbody>/<th scope>` following DESIGN-MANUAL §11 data table pattern
   - Columns: Species name, Score (0-100), Status (active/less active/inactive with color badge), Notes (optional — shown only when at least one species has a seasonal note from the scorer)
   - Alternating row backgrounds (`bg-muted/30`), sticky first column on mobile (`position: sticky, left: 0`)
7. **Tide Forecast** — `Card footprint="full"`:
   - `TideChart` (shared component, reused as-is)

### Tab content — Beach Safety (F24 redesign)

Itemized hazard indicators (Beach Report flag pattern). No overall "safe/caution/dangerous" badge — present individual hazards and let the visitor evaluate.

**Panel order:**

1. **Alerts** — `AlertsPanel`
2. **Beach Conditions** — `Card footprint="full"`:
   - Itemized hazard indicators, each as its own status row:
     - **Rip Current Risk**: badge (low=green, moderate=amber, high=red) + text label + guidance text
     - **UV Index**: numeric value + EPA tier label (Low/Moderate/High/Very High/Extreme) + SPF recommendation + guidance
     - **Wave Height**: `MarineStatTile` with height + period
     - **Wind**: `MarineStatTile` with speed + direction
     - **Water Temperature**: `MarineStatTile` with temp + comfort label (comfortable/cool/cold)
   - Storm surge badge when `stormSurgeLevel` non-null
   - NO composite "Dangerous" badge
3. **Tide Forecast** — `Card footprint="full"` with `TideChart`
4. **Coastal Flooding Risk** (show-when-available) — `Card footprint="full"` with NWPS total water level and wave runup
5. **Local Resources** (show-when-available) — external links (operator-configurable)

**Removed:** `SafetyIndicator` component and its "Safe/Caution/Dangerous" badge, standalone `RipCurrentPanel`, standalone `WaterTempPanel`, standalone `UVIndexPanel` (all consolidated into Beach Conditions card).

### Page visibility

- Single `"marine"` entry in `pages.json` controls the Marine Activities page
- Dashboard reads API capabilities at boot to determine whether the marine nav item appears
- If no marine locations are configured, no marine page appears — dashboard behaves identically to a non-marine installation
- Follows existing `pages.json` visibility pattern (§9)

### Activity-relevant alert filtering

Alert filtering applies within each activity tab, sourced from the general alert feed. This is display-side filtering, not a separate data source.

| Tab | Alert types shown |
|---|---|
| Boating | Marine zone alerts (SCA, Gale, Storm, Hurricane Force, Hazardous Seas, Dense Fog, Special Marine Warning) + coastal flood alerts (Coastal Flood Advisory/Warning, Storm Surge Warning/Watch) |
| Surfing | Marine zone alerts + coastal/beach alerts (Beach Hazards Statement, High Surf Advisory/Warning, Rip Current Statement) |
| Fishing | Marine zone alerts |
| Beach Safety | Coastal/beach alerts + coastal flood alerts + NWS SRF rip current risk |

**Marine zone alerts are NOT gated by the marine feature.** They appear in the dashboard's standard `AlertBanner` for all visitors when an operator configures a marine alert radius. The filtering above applies to the marine activity tabs only — activity-relevant subsets of what the general alert banner already shows.

### Data refresh intervals

| Data type | `refreshInterval` (seconds) | Source |
|---|---|---|
| Marine forecast (WaveWatch III / NWPS) | 1800 | Provider cache TTL |
| Buoy observations (NDBC) | 3600 | Provider cache TTL |
| Tide predictions (CO-OPS) | 21600 | Predictions don't change within tidal epoch |
| Tide observations (CO-OPS water levels) | 600 | 6–10 min update cadence |
| NWS marine zone text | 1800 | Provider cache TTL |
| NWS Surf Zone Forecast | 3600 | Issued 1–2×/day |
| Solunar times | 86400 | Celestial mechanics, changes daily |
| Surf quality scoring | 1800 | Tied to wave forecast refresh |
| Fishing scoring | 3600 | Inputs change slowly |

Dashboard uses `freshness.validUntil` from each API response to schedule refetches (per §7). These intervals match the API-side cache TTLs documented in PROVIDER-MANUAL §14.

### Now page marine summary card

When marine activities are enabled, a `MarineLocationSummary` card can appear on the Now page via `now-layout.json` (per §9 card plugin contract). The card shows:
- Current conditions snapshot (wave height, wind, water temp)
- Surf quality rating (stars, if surf enabled)
- Active marine alert count
- Next high/low tide time and height

The card links to `/marine`.

### i18n

Marine page uses `marine.*` key prefix for shared elements. Activity-specific keys: `marine.boating.*`, `marine.surfing.*`, `marine.fishing.*`, `marine.beachSafety.*`. All user-visible strings must use `t()` from `useTranslation()` — no hardcoded English. Unit labels resolve through the locale file. Number formatting uses `Intl.NumberFormat` with `i18n.language`. Same rules as §3.

### Responsive behavior

- Map: full-width all viewports; height adapts to geography (see Landing state above)
- LocationCards: 1-column mobile, 2-column at md (768px), 4-column at lg (1024px) — direct Grid children with `footprint="tile"`
- Tabs → accordions at <768px breakpoint
- Data tables use `overflow-x: auto` containers on narrow viewports — page body never scrolls horizontally
- Chart components follow existing responsive patterns (§6)
- Combo card (detail state): `flex-row` at md+, `flex-col` on mobile

### Accessibility (WCAG 2.1 AA)

Marine page accessibility requirements, following the precedent set by §10 (Radar Card). All items are release-blocking per ADR-026.

**Tab/accordion switching:**
- Tabs use `role="tablist"` / `role="tab"` / `role="tabpanel"` with `aria-selected`, `aria-controls`, `aria-labelledby`
- Arrow key navigation between tabs (left/right for horizontal tabs)
- Accordion mode (<768px): `role="region"` with `aria-labelledby` pointing to the accordion header button
- Tab/accordion state changes announced via `aria-live="polite"` region or native role semantics

**Map markers (numbered pins):**
- Markers are a mouse/touch supplementary affordance — not the primary keyboard path. `LocationCard` buttons (real `<button>` elements in the card grid) provide the keyboard-accessible selection path for each location, matching the Seismic page's precedent.
- Markers set `keyboard={false}` to avoid axe-core `aria-command-name` violations on Leaflet's internal DOM structure.
- Map container has `role="region"` with `aria-label` describing the map content.

**SwellDirectionCompass (informational SVG):**
- `role="img"` on the root `<svg>` element
- `<title>` element: "Swell direction {degrees}° {cardinal}, {height} at {period}s"
- Ticks and decorative elements: `aria-hidden="true"`

**Data tables (species forecast, sticky column):**
- `<th scope="col">` for column headers, `<th scope="row">` for the sticky first column
- `aria-label` on the scrollable container: "Species forecast table, scroll horizontally for more columns"

**Photos:**
- All `<img>` elements have `alt={location.name}` (LocationCard and combo card)
- No empty `alt=""` — photos are content images, not decorative

**Numeric values:**
- `fontFeatureSettings: '"tnum"'` on all numeric displays (tabular figures for alignment)
- axe-core 0-violations gate applies to the full marine page (landing + all 4 tab views)
