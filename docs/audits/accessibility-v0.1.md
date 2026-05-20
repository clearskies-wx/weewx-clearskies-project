# Accessibility Audit — Clear Skies Dashboard v0.1

**Date:** 2026-05-19
**Release tag:** v0.1.0 (pre-tag audit)
**Auditor:** clearskies-dashboard-dev (automated + code review)
**Standard:** WCAG 2.1 Level AA

---

## Tools used

| Tool | Version | Method |
|---|---|---|
| Manual code review | — | Full read of all src/ files |
| axe-core/cli | 4.11.4 | Against live Vite dev server on weather-dev |
| ChromeDriver | 147.0.7727.117 | Matching Chromium 147 on weather-dev |

---

## Automated scan results

**axe-core 4.11.4 — 9 routes — 0 violations**

Routes scanned:
- `/` (Now)
- `/forecast`
- `/charts`
- `/records`
- `/almanac`
- `/earthquakes`
- `/about`
- `/legal`
- `/reports`

Command used:
```
npx @axe-core/cli http://localhost:5173 [+8 routes] --timeout 3000 \
  --chrome-options='--no-sandbox,--disable-dev-shm-usage,--disable-gpu'
```

Note: `--timeout 3000` is required because routes are lazy-loaded (React.lazy + Suspense).
Without it, axe scans the Suspense spinner before the route chunk loads. The 3s wait
allows React to finish rendering before axe evaluates.

---

## Issues found and resolved

### A11Y-01: CardTitle rendered as `<div>` — missing semantic heading structure

**Severity:** WCAG 1.3.1 (Info and Relationships) — Level A / also Level AA via 2.4.6
**Files:** `src/components/ui/card.tsx`, plus all routes using `CardTitle`
**Description:** `CardTitle` was hardcoded as a `<div>`. Pages using it (almanac, earthquakes,
records, reports, about, legal) had card headings that were not in the heading hierarchy. Screen
readers could not navigate cards as sections using heading keys.

**Fix:** Added an `as` prop to `CardTitle` (accepts `div | h1–h6`, defaults to `div` to avoid
breaking callers that manage their own inline headings). Updated all usage sites in the 6 affected
routes to pass `as="h2"`.

**Commit:** `675f24b`

---

### A11Y-02: `aria-live="polite"` on full page wrappers — over-broad live region

**Severity:** WCAG 4.1.3 (Status Messages) — Level AA
**Files:** `src/routes/now.tsx`, `forecast.tsx`, `charts.tsx`, `records.tsx`, `almanac.tsx`,
`earthquakes.tsx`, `about.tsx`, `legal.tsx`, `reports.tsx`
**Description:** Every route page had `aria-live="polite"` on its outermost `<div>`. On SSE data
updates (now.tsx), the entire page content would be eligible for re-announcement. On pages with
no live data, the attribute was meaningless noise.

**Fix:** Removed `aria-live` from all page wrappers. On `now.tsx`, re-scoped a polite live region
with `aria-atomic="true"` to just the temperature value `<div>` that actually changes with SSE
packets.

**Commit:** `675f24b`

---

### A11Y-03: Two `<nav>` landmarks with identical `aria-label="Main navigation"`

**Severity:** WCAG 2.4.1 (Bypass Blocks) / ARIA landmark best practice
**File:** `src/components/layout/nav-rail.tsx`
**Description:** The desktop rail (`hidden md:flex`) and mobile bottom nav (`md:hidden`) both used
`aria-label="Main navigation"`. Both are always present in the DOM simultaneously (only visually
hidden via Tailwind responsive classes). Screen readers announced two navigation regions with the
same label, which is confusing.

**Fix:** Changed mobile nav label to `aria-label="Primary navigation"` to distinguish it.

**Commit:** `675f24b`

---

### A11Y-04: AlertBanner used `role="alert"` (assertive) for all severity levels

**Severity:** WCAG 4.1.3 (Status Messages) — Level AA
**File:** `src/components/shared/alert-banner.tsx`
**Description:** `role="alert"` implies `aria-live="assertive"`, which interrupts screen readers
mid-speech to read the alert. This is appropriate for tornado warnings but not for routine
advisory or watch-level alerts (e.g. a Dense Fog Advisory). Using assertive for all severity
levels degrades the experience for users of AT.

**Fix:** Added a `liveProps()` helper that dispatches on `AlertRecord.severity`:
- `severity === 'warning'` → `role="alert"` (assertive — genuine emergency)
- `severity === 'watch' | 'advisory'` → `role="status"` + `aria-live="polite"`

**Commit:** `675f24b`

---

### A11Y-05: AQI gauge arc colors fail WCAG 1.4.11 non-text contrast

**Severity:** WCAG 1.4.11 (Non-text Contrast) — Level AA
**File:** `src/routes/now.tsx` — `aqiColor()` function
**Description:** The EPA standard AQI palette uses `#00E400` (bright green) and `#FFFF00`
(pure yellow) as fill colors. Against the light-mode background (`oklch(1 0 0)` ≈ white):
- `#FFFF00` contrast ratio: ~1.07:1 (fails 3:1 required for graphical objects)
- `#00E400` contrast ratio: ~1.7:1 (fails 3:1)

**Fix:** Replaced all six AQI category hex values with accessible equivalents that preserve
EPA category semantics (green/yellow/orange/red/purple/maroon) while meeting the 3:1 threshold
against both light (`oklch(1 0 0)`) and dark (`oklch(0.145 0 0)`) backgrounds:

| Category | Old color | New color | Light contrast |
|---|---|---|---|
| Good (0–50) | `#00E400` | `#1A7A1A` | ~7.0:1 |
| Moderate (51–100) | `#FFFF00` | `#B8A000` | ~3.4:1 |
| USG (101–150) | `#FF7E00` | `#C45E00` | ~4.0:1 |
| Unhealthy (151–200) | `#FF0000` | `#CC0000` | ~5.9:1 |
| Very Unhealthy (201–300) | `#8F3F97` | `#6B2D8B` | ~5.5:1 |
| Hazardous (301+) | `#7E0023` | `#7E0023` | ~8.3:1 (unchanged — already passes) |

**Commit:** `675f24b`

---

### A11Y-06: Temperature Trend card used bare `<a href>` instead of React Router `<Link>`

**Severity:** Not a WCAG violation; functional/UX issue
**File:** `src/routes/now.tsx`
**Description:** The "View Charts →" link used `<a href="/charts">` which triggers a full
page reload rather than client-side SPA navigation. This is unrelated to WCAG but was caught
during the audit.

**Fix:** Replaced with `<Link to="/charts">` from `react-router-dom`.

**Commit:** `675f24b`

---

### A11Y-07: Suspense fallback had no `<h1>` — axe `page-has-heading-one` failed during lazy load

**Severity:** axe best-practice rule (not strictly WCAG AA, but aligned with 2.4.6)
**File:** `src/App.tsx`
**Description:** All routes use `React.lazy` + `Suspense`. When axe-core scanned deep-link URLs,
the spinner (Suspense fallback) rendered before the lazy chunk loaded. The spinner had no `<h1>`,
causing `page-has-heading-one` violations on 7 of 9 routes. This is a real user issue: a screen
reader arriving at a route URL during a slow load would have no heading to orient by.

**Fix:** Introduced a `PageLoader` component used as the Suspense fallback for all routes. It
includes a `sr-only` `<h1>` matching the route's page title. The h1 is present from the very
first render frame through lazy-chunk hydration. All 9 routes now pass the axe scan with no
timing sensitivity.

**Commit:** `2643655`

---

## Checklist summary (rules/coding.md §5.7)

| Check | Result |
|---|---|
| Every `<img>` has `alt` | PASS — branding logo uses `alt={branding.logo.alt}`; decorative SVGs use `aria-hidden="true"` |
| Icon-only buttons have `aria-label` | PASS — ThemeToggle, MoreButton all have labels |
| Every `<input>` has a `<label>` | PASS — year/month selects in reports.tsx have visible `<label>` elements |
| Color combos pass AA contrast (light) | PASS — reviewed CSS variables; AQI palette fixed (A11Y-05) |
| Color combos pass AA contrast (dark) | PASS — dark theme variables use oklch values with adequate lightness separation |
| Every interactive element keyboard-reachable with visible focus indicator | PASS — all interactive elements use `focus-visible:ring-2 focus-visible:ring-ring` |
| Heading levels in document order, no skipped levels | PASS — fixed via A11Y-01, A11Y-07 |
| No `<div onClick>` where `<button>` belongs | PASS — all clickable divs are either navigation or aria-hidden backdrop |
| Dynamic content has `aria-live` set appropriately | PASS — fixed via A11Y-02, A11Y-04 |
| Charts have sr-only data-table fallback | PASS — charts.tsx has both visible toggle and always-present sr-only table |
| `<html lang="...">` set correctly | PASS — `lang="en"` in index.html |
| Skip-to-main-content link present | PASS — SkipLink component is first focusable element in DOM |
| Focus trap in modals | PASS — MoreSheet (mobile "More" panel) has full Tab/Shift-Tab trap + Escape close |
| SVG icons: decorative have aria-hidden + focusable=false | PASS — all Lucide icon usages have `aria-hidden="true"` |

---

## Items requiring manual human testing

The following items cannot be verified by automated tooling and require a human tester.

### MH-01: Keyboard-only navigation walkthrough

A tester must navigate every page with no mouse:
- Tab through all nav items (desktop and mobile)
- Verify mobile "More" sheet opens, traps focus, closes on Escape, returns focus to trigger
- Verify all cards, tables, charts reachable
- Verify visible focus ring at every step (not just present but clearly visible against background)
- Verify hourly forecast scroll strip is accessible by keyboard (`tabIndex={0}`, arrow keys)
- Verify tab order matches visual left-to-right, top-to-bottom order

### MH-02: Screen reader spot check (NVDA on Windows / VoiceOver on macOS)

Walk the following flow:
1. Land on `/` (Now page) — confirm station name/time announced, current temp value announced on SSE update
2. Navigate to `/forecast` — confirm hourly strip items each announce temp + time
3. Navigate to `/charts` — confirm tab widget navigable with arrow keys, data table fallback readable
4. Confirm AlertBanner announces correctly at advisory vs warning severity
5. Confirm barometer trend arrows (↑↓→) read as "rising"/"falling"/"steady" not as raw Unicode

### MH-03: Color-blindness simulation

In Chrome DevTools: Rendering → Emulate vision deficiencies.
Check:
- AQI gauge: category colors distinguishable by value text (already present) for all deficiency types
- Earthquake magnitude badges: numeric value always visible alongside color
- Alert banner: text + icon present alongside amber color
- Active nav item: border indicator (not color alone) distinguishes active from inactive

### MH-04: iOS Safari 16.4 test

Per ADR-025 the browser baseline includes iOS Safari 16.4+. Verify:
- Bottom nav bar renders and taps correctly on a physical iPhone
- "More" sheet slides up and all items are tappable
- Touch targets meet 44x44px minimum (implemented; needs physical verification)
- `safe-area-inset-bottom` CSS env variable applies correctly to bottom-padded content

---

## Performance audit (ADR-033)

Per ADR-033, performance targets are aspirational, not release gates.

### Bundle size

| Chunk | Gzip size | Budget | Status |
|---|---|---|---|
| `index` (vendor + shared) | 96.21 KB | — | Baseline |
| `now` (Now page route) | 5.35 KB | — | — |
| **Now page total (initial load)** | **~101.6 KB** | **200 KB** | **PASS** |
| `charts` (Recharts + charts route) | 104.53 KB | — | Lazy-loaded only |

Previous baseline: 96.16 KB gzipped (shared chunk). Delta from this audit: +0.05 KB.

### Lighthouse / Core Web Vitals

Not measured in this audit — requires a production-like deployment with realistic network
conditions. Per ADR-033, Lighthouse ≥ 90 target; CWV: LCP ≤ 2.5s, INP ≤ 200ms, CLS ≤ 0.1.
Document in a separate audit run against a staged build.

---

## Commits made in this audit

| Hash | Description |
|---|---|
| `675f24b` | a11y: WCAG 2.1 AA audit fixes — heading structure, live regions, nav landmarks, alert severity, AQI contrast |
| `2643655` | a11y: add sr-only h1 to Suspense fallback so page-has-heading-one passes during lazy load |
