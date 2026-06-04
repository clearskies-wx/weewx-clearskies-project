# Mobile & Background Polish — Implementation Plan

**Status: COMPLETE — 2026-06-03.** All tasks implemented, deployed, and verified live.

### Completion summary

**Global fixes (G1–G8):** Viewport height fixed to `100dvh`, horizontal overflow
suppressed, overscroll contained. Footer responsive layout implemented. Background
flash-on-load fixed (dark fallback + opacity fade-in). Manual theme→background override
implemented (light→day, dark→night, system→BFF almanac). ADR-047 amended. Background
conditions working after BFF deploy.

**Per-card fixes:** Wind compass zero-speed consistency fixed (cardinal derived from
bearing when BFF nulls it). Mobile card collapse batch-fixed across Solar, UV, Lightning,
AQI, Earthquake, Radar (minHeight floors added). Forecast cards mobile layout fixed
(hi/lo stacking, trend line responsive hide, stacked rows on Now card).

**Precipitation & Snow (C2 dialog):** Resolved in separate plan
([archive/FORECAST-DETAIL-SNOW-PLAN.md](FORECAST-DETAIL-SNOW-PLAN.md)). Snow fields
added to API + dashboard. Dewpoint/humidity stayed on precipitation card (renamed
"Precipitation & Humidity"). Forecast cards show precipType icons and amounts.

**7-Day Forecast mobile (C7 dialog):** Resolved — hi/lo temps stack vertically on
mobile, trend lines kept, 7 columns remain readable at 375px.

---

## Context (original)

C1–C6 are code-complete and pushed to GitHub (both repos: `HEAD = origin/main`), but
NOT deployed (`redeploy-weather-dev.sh` hasn't been run). A live mobile review surfaced
bugs across global layout, background system, and individual cards. This plan fixes
them all in a coordinated pass.

**Repo path:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`
**BFF path:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-realtime`

---

## Issue Summary

### Global Issues

| # | Issue | Root cause |
|---|-------|-----------|
| G1 | Non-Now pages horizontal scroll on mobile | Scroll container has `overflow-y-auto` but no `overflow-x-hidden` |
| G2 | Overscroll past footer tears background | No `overscroll-behavior` on scroll container |
| G3 | Nav disappears on forecast page | `h-screen` (100vh) doesn't adjust for mobile URL bar; intermittent fixed-nav clipping |
| G5 | Footer ugly on mobile | No responsive classes; wraps ungracefully |
| G6 | Background flashes clear-day on load | `SCENE_DEFAULT = {sky:'clear', daytime:true}` renders blue sky before BFF responds |
| G7 | Backgrounds don't change with conditions | **Deploy issue** — code is correct and pushed; BFF not restarted on weather-dev |
| G8 | Manual day/night toggle doesn't change bg | ADR-047 design: bg follows BFF almanac. Operator wants theme toggle override |

### Per-Card Issues

| # | Card | Issue | Root cause |
|---|------|-------|-----------|
| C1 | Wind Compass | Zero speed shows en-dash for cardinal but bearing retains old degrees | `windDirCardinal` nulled by BFF at zero speed; `windDir` (degrees) is not cleared. Component shows them independently |
| C2 | Precipitation & Humidity | **No snow support** — rain-only. Needs precipType from external API. **NEEDS DIALOG** | `/current` only has `rain`/`rainRate` (station gauge). `precipType` available on forecast but unused in UI |
| C3 | Solar Radiation | Chart collapses on mobile, no display | `flex:1 minHeight:0 height:100%` pattern — no parent height on mobile grid (auto rows) |
| C4 | UV Index | Chart collapses on mobile, no display | Same pattern as C3 |
| C5 | AQI | Different size than other tiles on mobile | Same collapse pattern; gauge+pollutant flex layout has no responsive stacking |
| C6 | Lightning | Collapses on mobile, chart disappears | Same pattern — `ResponsiveContainer height:100%` → 0px |
| C7 | 7-Day Forecast | Mess on mobile — **NEEDS DIALOG** | 7 vertical columns crammed into 375px; expandable detail panel likely broken |
| C8 | Recent Earthquake | Doesn't retain shape/size | Card collapses without chart or explicit height |
| C9 | Radar | Doesn't display, collapses | Leaflet `MapContainer h-full` needs explicit pixel height; gets 0px on mobile |
| C10 | Webcam | OK per operator | — |

---

## DIALOG ITEMS (need operator input before implementation)

### Dialog 1: Precipitation & Snow

**Current state:** The Precipitation & Humidity card shows `rain` (daily accumulation) and `rainRate` from the weather station only. The forecast cards show `precipProbability` only — no type, no amount.

**What's available in the data:**

| Source | Fields available | Currently used? |
|--------|-----------------|----------------|
| Station (via `/current`) | `rain`, `rainRate` | Yes (precip card) |
| Station archive (weewx) | `snow`, `snowRate`, `snowDepth` | **Not exposed on /current** |
| Forecast hourly | `precipType` (rain/snow/sleet/freezing-rain), `precipAmount`, `precipProbability` | Only `precipProbability` shown; `precipType` used only for background overlay |
| Forecast daily | `precipAmount`, `precipProbabilityMax` | Only probability shown; **no precipType field on daily** |

**Questions for operator:**

1. **Precipitation card (current conditions):** The station rain gauge can't tell rain from snow. Should we use the forecast API's `precipType` for the current hour to label what the gauge is measuring? E.g., if `precipType = "snow"`, show "Snow Rate" instead of "Rain Rate"?

2. **Snow amount:** Weewx has `snow`/`snowRate`/`snowDepth` archive fields but they're NOT on the `/current` endpoint. Should we add them to the API? Or rely on the forecast provider's data?

3. **Forecast cards (hourly):** `precipType` and `precipAmount` are both available but unused. Should the precipitation row show: (a) just probability with a rain/snow icon, (b) probability + amount, (c) amount only for the type?

4. **Forecast cards (daily):** Daily forecast has `precipAmount` but NO `precipType`. Should we derive the type from the hourly data (majority type for the day)? Or show a generic "Precip" label?

5. **Mixed precipitation:** When forecast shows sleet or freezing rain, how should the UI handle it? Same icon with a label? Different color?

### Dialog 2: 7-Day Forecast Mobile Layout

The 7-Day forecast card renders 7 columns side-by-side with: day name, weather icon, hi/lo temps, trend lines, precipitation %, and wind symbols. On a 375px screen, 7 columns = ~54px each — too narrow for readable content.

**Options for operator:**

A. **Horizontal scroll** — make the 7-day card scrollable horizontally on mobile (like the hourly strip). All 7 columns visible by scrolling.

B. **Stack to rows** — convert each day into a horizontal row (icon + day + hi/lo + precip + wind) stacked vertically. Similar to many weather apps' mobile forecast layout.

C. **Show fewer days** — only show 3-4 days on mobile, with a "See all" link to the forecast page.

D. **Accordion/expandable** — show day names + icons + hi/lo in a compact list, tap to expand detail.

---

## IMPLEMENTATION TASKS

### Task 1: Fix viewport height + horizontal overflow + overscroll (G1, G2, G3)

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Files:**
- `src/components/layout/app-layout.tsx` — lines 36, 50
- `src/index.css` — `@layer base` block (line 298)

**Changes:**

**(a) Line 36 — replace `h-screen` with `h-[100dvh]`:**
`100dvh` (dynamic viewport height) adjusts when mobile URL bar shows/hides. `100vh` does NOT, causing the outer container to be shorter than the actual viewport — the fixed bottom nav clips intermittently.

**(b) Line 50 — add `overflow-x-hidden` + `overscroll-behavior`:**
```tsx
<div
  className="flex flex-col flex-1 min-w-0 min-h-0 overflow-y-auto overflow-x-hidden md:overflow-hidden"
  style={{ overscrollBehaviorY: 'contain' }}
>
```

**(c) index.css — safety-net global rules:**
```css
html {
  overflow-x: hidden;
  overscroll-behavior: none;
}
```

**Acceptance:**
- [ ] No horizontal viewport scroll on any page at 375px
- [ ] Tables still scroll horizontally within their own container
- [ ] No overscroll/tear past footer
- [ ] Bottom nav visible at ALL times on ALL pages (especially forecast)
- [ ] Desktop unchanged
- [ ] `tsc --noEmit` 0 errors, `vite build` clean

---

### Task 2: Footer mobile redesign + logo update (G5 + minor)

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Files:**
- `src/components/layout/footer.tsx`
- `src/assets/clearskies-powered-light.svg` — replace with updated artwork

**Changes:**

**(a) Footer responsive layout:**
- Outer flex: `flex-col gap-2` on mobile → `md:flex-row md:flex-wrap md:justify-between` on desktop
- Legal link + bullet separators: `hidden md:inline` (desktop only — legal is in nav menu)
- Photo credit paragraph: `hidden md:block` (desktop only)
- Mobile: copyright + logo on first line, share buttons below, all left-justified

**(b) Update "Powered by Clear Skies" logo:**
Copy artwork from `Graphics/clearskies logo POWERED blue.svg` (the updated Illustrator
export) to replace `src/assets/clearskies-powered-light.svg`. The source file uses
`fill: #2568a3` (dark blue) — change all fill/stroke values to `#93c5fd` (or white
`#ffffff`) for the light variant, since the footer background is dark glass
(`rgba(0,0,0,0.65)`) and the logo must remain legible. Keep the existing filename
(`clearskies-powered-light.svg`) so the import in `footer.tsx` doesn't change.

**Acceptance:**
- [ ] Mobile: copyright, logo, share icons only — left-justified, stacked vertically
- [ ] Desktop: unchanged (legal link, bullets, copyright, logo, shares, photo credit)
- [ ] Smooth transition at md breakpoint
- [ ] Logo shows the updated artwork (verify visually vs `Graphics/` source)
- [ ] Logo is clearly legible on dark footer glass in both light and dark themes

---

### Task 3: Background flash fix (G6)

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Files:**
- `src/hooks/useWeatherData.ts` — line 146 (SCENE_DEFAULT), return block
- `src/components/background/scene-background.tsx` — outer container
- `src/components/layout/app-layout.tsx` — SceneBackground props

**Changes:**

**(a)** Change `SCENE_DEFAULT` to `daytime: false` (dark fallback instead of blue sky).

**(b)** Add `sceneLoaded: boolean` to `ObservationHookResult` and return `data?.scene != null`.

**(c)** `SceneBackground` accepts `visible?: boolean` prop. Outer container always renders
dark navy `#0a0e1a` background. Inner layer wrapper has `opacity: visible ? 1 : 0` with
`transition: opacity 0.6s ease-in-out`. Before BFF responds → dark. After → smooth fade-in.

**(d)** `AppLayout` passes `sceneLoaded` to `SceneBackground`.

**Acceptance:**
- [ ] Fresh load: dark background (not blue sky flash)
- [ ] BFF responds: correct scene fades in over ~600ms
- [ ] BFF unreachable: dark navy persists (not broken white)
- [ ] Mock mode still works

---

### Task 4: Manual theme → background override (G8)

**Owner:** clearskies-dashboard-dev agent (same agent as Task 3 — sequential)
**QC:** Coordinator (me)

**Files:**
- `src/components/layout/app-layout.tsx`
- `docs/decisions/ADR-047-background-system.md` — §5 amendment

**Changes:**

In `AppLayout`, resolve background daytime from theme preference:
```tsx
const bgDaytime = preference === 'light' ? true
                : preference === 'dark'  ? false
                : scene.daytime;

const resolvedScene: SceneDescriptor = {
  sky: scene.sky,
  daytime: bgDaytime,
  overlay: scene.overlay,
};
```

Sky and overlay always from BFF. Only day/night dimension overridden by theme toggle.

ADR-047 §5 amendment: "Manual light/dark override also overrides the background's daytime
flag (light→day, dark→night); system mode follows almanac as before."

**Acceptance:**
- [ ] Light mode → day background (even at night)
- [ ] Dark mode → night background (even during day)
- [ ] System mode → follows BFF almanac
- [ ] Weather conditions (sky/overlay) still change in all modes
- [ ] Card glass/text colors still track the theme toggle correctly

---

### Task 5: Wind compass zero-speed consistency (C1)

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Files:** `src/components/WindCompassCard.tsx` — lines 130–146

**Root cause:** When wind speed is zero, the BFF nulls `windDirCardinal` but leaves `windDir`
(degrees) intact. The component shows them independently — cardinal becomes "—" but bearing
retains old degrees like "305°".

**Fix:** The operator directive is "cardinal should retain last known direction if value is null."

In the component, when `windDirCardinal` is null but `windDir` has a value, derive the
cardinal from the bearing using the existing `cardinalFromDegrees` utility (already used in
forecast — `src/utils/wind.ts` or similar). This makes both fields consistent: if we have
a bearing, we show the matching cardinal. If both are null, both show "—".

```tsx
// After line 130:
const windDirCardinal = observation?.windDirCardinal ?? null;
const windDirDegrees = windDirCV?.value ?? null;

// Derive cardinal from degrees if BFF nulled the cardinal but degrees exist
const effectiveCardinal = windDirCardinal
  ?? (windDirDegrees != null ? cardinalFromDegrees(windDirDegrees) : null);

const cardinalLabel = effectiveCardinal
  ? tCommon(`directions.${effectiveCardinal}`)
  : '—';
```

**Acceptance:**
- [ ] At zero wind speed: if bearing shows "305°", cardinal shows "NW" (not "—")
- [ ] If both bearing and cardinal are null: both show "—"
- [ ] Non-zero wind speed: unchanged behavior

---

### Task 6: Fix mobile card collapse — batch fix (C3, C4, C5, C6, C8, C9)

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Root cause (shared):** All these cards use `flex: 1, minHeight: 0, height: 100%` for
their chart/visualization containers. On desktop, the Grid sets `md:auto-rows-[11rem]`
which gives flex containers a fixed parent height to grow into. On mobile, rows are `auto`
(content-driven) — `flex: 1` with `minHeight: 0` collapses to 0px, and `height: 100%`
resolves to nothing. `ResponsiveContainer` (Recharts) and `MapContainer` (Leaflet) both
need explicit pixel height and get 0.

**Fix pattern:** Add a mobile-specific `minHeight` to the chart/visualization container
in each card. On mobile, this ensures content has a floor height. On desktop (md+),
`min-h-0` or no override is needed since the grid row height controls sizing.

**Files and specific changes:**

| Card | File | Chart container location | Mobile min-height |
|------|------|------------------------|-------------------|
| Solar Radiation | `src/components/solar-radiation-card.tsx` | ~line 212 (`style={{ flex:1, minHeight:0, height:'100%' }}`) | Change `minHeight: 0` → `minHeight: '200px'`. At md+ the grid row height (11rem) overrides this via the Card's overflow-hidden + flex sizing |
| UV Index | `src/components/uv-index-card.tsx` | ~line 422 (same pattern) | Same fix: `minHeight: '200px'` |
| Lightning | `src/components/lightning-card.tsx` | ~line 166–172 (nested flex:1 containers) | Add `minHeight: '180px'` to the chart div |
| AQI | `src/components/aqi-card.tsx` | ~line 354 (gauge+pollutant flex) | Add `minHeight: '160px'` to the outer flex container. Consider stacking vertically on mobile via a responsive class |
| Earthquake | `src/components/earthquake-card.tsx` | ~line 262 (list container) | Add `minHeight: '160px'` to the CardContent or list container |
| Radar | `src/components/shared/radar-map.tsx` | ~line 297 (`h-full min-h-0`) | Replace `min-h-0` with `min-h-[300px] md:min-h-0` on the map container div. Leaflet specifically requires a concrete pixel height |

**Acceptance per card:**
- [ ] Solar Radiation: chart visible on 375px mobile, shows 24h rolling data area
- [ ] UV Index: chart visible on 375px mobile, shows bell curve
- [ ] Lightning: scatter chart visible on mobile (or "No recent activity" message fills space)
- [ ] AQI: gauge and pollutant column visible, not clipped, same visual weight as other tiles
- [ ] Earthquake: both events visible, card same height as neighboring tiles
- [ ] Radar: map renders and is interactive on mobile, shows station location + precipitation
- [ ] All cards: desktop layout unchanged (11rem grid row height still governs)
- [ ] `tsc --noEmit` 0 errors, `vite build` clean

---

### Task 7: Deploy to weather-dev (G7)

**Owner:** Coordinator (me), triggered by operator "deploy" instruction
**QC:** Coordinator (me)

**Action:** Run `scripts/redeploy-weather-dev.sh` — pulls repos on server, restarts
realtime + config services, rebuilds dashboard, rsyncs to web root.

**Acceptance:**
- [ ] `curl /api/v1/current | jq '.scene'` returns real scene data
- [ ] Background matches actual weather conditions
- [ ] Background changes with day/night cycle

---

## PRECIPITATION & SNOW (C2) — decided, blocked on API work

### Operator decisions (2026-06-03):

1. **Move dewpoint + relative humidity OFF the precipitation card → onto Current
   Conditions card**, underneath the Hi/Lo temps. This frees space for snow.
2. **Rain is always shown** on the precipitation card (Rain Rate + Rain Today).
   Never removed.
3. **Snow accumulation appears when > 0**, then stays for the rest of the day.
   Don't show "Snow: 0.00" in summer. Use snowflake icon for snow.
4. **Show snow rate only if the provider supplies it.** If not, don't show rate.
5. **API determines the data source:** check if weewx is providing `snow`/`snowRate`
   (station hardware). If not, pull from the configured external provider.
6. **Rain and snow can coexist** — Midwest weather around 32°F can produce both in
   the same day (morning snow, afternoon rain, mixed precip). Card shows both
   simultaneously when both are active/accumulated.

### Provider snow accumulation availability (from API docs):

| Provider | Current obs | Hourly forecast | Daily forecast |
|----------|------------|----------------|----------------|
| Aeris/XWeather | No (depth only) | `snowIN`/`snowCM` | `snowIN`/`snowCM` |
| Open-Meteo | N/A | `snowfall` (cm) | `snowfall_sum` |
| OWM | `snow.1h` (mm) | `snow.1h` (mm) | `snow` (mm) |
| Wunderground | No | No hourly endpoint | `qpfSnow` |
| NWS | No | Not on standard endpoint | Not on standard (need raw grid) |
| Weewx station | `snow`, `snowRate` if hardware | N/A | N/A |

### Blocking dependency: API-layer work

Before the dashboard can display snow, the API (`weewx-clearskies-api`) must:
1. Map snow accumulation from each provider into canonical `snow` field
2. Implement fallback logic: weewx station data first, provider data second
3. Expose `snow` (and `snowRate` when available) on the `/current` endpoint
4. Map hourly `snowfall` into `HourlyForecastPoint` for forecast cards
5. Map daily `snowfall_sum`/`qpfSnow` into `DailyForecastPoint`

This is a **separate API task** — not dashboard work. The dashboard changes
(precipitation card redesign, forecast card updates, current conditions card
dewpoint/humidity addition) can be implemented once the API supplies the data.

### Dashboard changes (after API work):

**Precipitation card** (`precipitation-card.tsx`):
- Remove dewpoint + humidity display
- Keep: Rain Rate + Rain Today (always)
- Add: Snow Today (snowflake icon) — visible when `snow > 0`, stays for the day
- Add: Snow Rate — visible only when provider supplies it

**Current Conditions card** (`CurrentConditionsCard.tsx` or equivalent):
- Add dewpoint + relative humidity below Hi/Lo line

**Forecast cards** (`HourlyStrip.tsx`, `DailyColumns.tsx`, `NowForecastCard.tsx`):
- Display logic (same rule everywhere precipitation appears):
  - Both rain + snow data → show both lines
  - Snow data but no rain → show snow only
  - Rain data but no snow → show rain only
  - Neither rain nor snow → show rain as 0 (rain is the default/fallback)
- Use snowflake icon vs raindrop icon based on precipType
- Provider must supply the snow data for it to appear — if provider doesn't
  have snow fields (e.g. NWS standard endpoint), only rain is shown

### Task 8: Forecast cards mobile fixes (C7) — decided

**Owner:** clearskies-dashboard-dev agent
**QC:** Coordinator (me)

**Operator decisions (2026-06-03):**

**(a) Today's Forecast card** (`NowForecastCard.tsx` / `DailyColumns.tsx` non-expandable):
- **Remove trend lines on mobile** — not enough room. Can keep on desktop.
- **Convert to stacked rows on mobile** — each day becomes a horizontal row
  (icon + day + hi/lo + precip + wind) instead of vertical columns.

**(b) 7-Day Forecast card** (`ForecastDailyCard.tsx` / `DailyColumns.tsx` expandable):
- **Keep trend lines** on this card.
- **Stack hi/lo temps vertically** on mobile — currently combined as "74°/58°"
  which blends together at narrow column widths. Show hi on top, lo below.
- This buys enough width for the 7 columns to remain readable.

**(c) Hourly Forecast card** (`ForecastHourlyCard.tsx` / `HourlyStrip.tsx`):
- **Horizontal scrollbar on mobile** — already has scroll behavior. No layout
  change needed. Verify it works.

**Files:**
- `src/components/forecast/DailyColumns.tsx` — hi/lo stacking + trend line responsive hide
- `src/components/forecast/NowForecastCard.tsx` — stacked rows on mobile
- `src/components/forecast/HourlyStrip.tsx` — verify scroll works on mobile

**Acceptance:**
- [ ] Today's Forecast (Now page): stacked rows on mobile, no trend lines, readable
- [ ] Today's Forecast (desktop): unchanged (columns + trend lines)
- [ ] 7-Day (Forecast page): hi/lo stacked vertically on mobile, trend lines visible, 7 columns fit
- [ ] 7-Day (desktop): unchanged
- [ ] Hourly (Forecast page): scrollable on mobile, all content visible by scrolling
- [ ] `tsc --noEmit` 0 errors, `vite build` clean

---

## Execution Order

```
 ┌─ Task 1 (viewport/overflow/overscroll)     ─── app-layout.tsx lines 36,50 + index.css
 ├─ Task 2 (footer mobile + logo)             ─── footer.tsx, powered SVG asset
 ├─ Task 5 (wind zero-speed)                  ─── WindCompassCard.tsx only
 ├─ Task 6 (batch mobile collapse fix)        ─── 6 card component files
 ├─ Task 8 (forecast cards mobile)            ─── DailyColumns, NowForecastCard, HourlyStrip
 │
 │  ALL PARALLEL — no file conflicts
 │
 ├─ Task 3 (background flash)                 ─── useWeatherData.ts, scene-background.tsx, app-layout.tsx lines 21,34
 └─ Task 4 (theme→bg override)               ─── app-layout.tsx (sequential after Task 3)

Task 7 (deploy) ← after all code committed; operator says "deploy"
```

**Conflict management:**
- Tasks 1 and 3+4 both touch `app-layout.tsx` but at different lines (1: lines 36,50; 3+4: lines 21,28,34)
- **Recommended grouping:** Run Tasks 1+3+4 as ONE agent (they share `app-layout.tsx`). Run Tasks 2, 5, 6 as separate parallel agents.
- Total: 3 agents in parallel, then Task 7 (deploy) after commits

---

## Agent Assignments

| Agent | Tasks | Files touched |
|-------|-------|---------------|
| Agent A (dashboard-dev) | 1 + 3 + 4 | `app-layout.tsx`, `index.css`, `useWeatherData.ts`, `scene-background.tsx`, `ADR-047` |
| Agent B (dashboard-dev) | 2 + 5 | `footer.tsx`, powered SVG asset, `WindCompassCard.tsx` |
| Agent C (dashboard-dev) | 6 | `solar-radiation-card.tsx`, `uv-index-card.tsx`, `lightning-card.tsx`, `aqi-card.tsx`, `earthquake-card.tsx`, `radar-map.tsx` |
| Agent D (dashboard-dev) | 8 | `DailyColumns.tsx`, `NowForecastCard.tsx`, `HourlyStrip.tsx` |
| Coordinator (me) | 7 + all QC | Deploy script, visual verification |

---

## QC Gates (Coordinator verifies all — agents do NOT self-attest)

### Gate 1: Build
- [ ] `npx tsc --noEmit` → 0 errors
- [ ] `npx vite build` → clean build

### Gate 2: Mobile visual (375px)
- [ ] No horizontal viewport scroll on any page
- [ ] No overscroll/tear past footer
- [ ] Bottom nav visible at ALL times, ALL pages (especially forecast page after deep scroll)
- [ ] Footer: copyright + logo + share icons only, left-justified
- [ ] Background: dark start → smooth fade-in to correct scene
- [ ] Theme toggle: light→day bg, dark→night bg, system→BFF
- [ ] Wind compass at zero speed: cardinal matches bearing (both show direction or both "—")
- [ ] Solar/UV/Lightning/AQI/Earthquake/Radar: all visible, charts render, no collapse
- [ ] All tiles roughly same visual weight (no shrunken outliers)

### Gate 3: Desktop visual (1400px)
- [ ] Footer unchanged (legal link, photo credit, horizontal layout)
- [ ] Nav rail grab bar + auto-hide works
- [ ] Background transitions smooth
- [ ] All stat tiles render at 11rem row height (no overflow, no clipping)
- [ ] No regressions on any Now page card

### Gate 4: Breakpoint transition
- [ ] Resize 375 → 768 → 1400: smooth transitions
- [ ] Footer switches stacked ↔ horizontal at md
- [ ] Bottom nav ↔ desktop rail at md
- [ ] Tiles maintain content at all widths

### Gate 5: Post-deploy live data
- [ ] `/api/v1/current` scene data is real
- [ ] Background reflects actual conditions
- [ ] Day/night background follows manual theme toggle

---

## Out of Scope
- C2 Precipitation/Snow (deferred — dialog first)
- C7 7-Day Forecast mobile layout (deferred — dialog first)
- C7–C10 page redesigns
- Drag-and-drop grid engine
- Full axe-core accessibility audit
- Any git push — operator authorizes separately
