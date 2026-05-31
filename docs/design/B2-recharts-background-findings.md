# B2 Research Findings — Recharts scene background behind plot area

**Status:** Final.
**Date:** 2026-05-31
**Recharts version:** 3.8.1 (as installed in `weewx-clearskies-dashboard`)
**Spike:** `docs/design/mockups/B2-recharts-background.html`
**Screenshots:** `c:\tmp\b2-technique1.png`, `c:\tmp\b2-technique2.png`, `c:\tmp\b2-fullpage.png`

---

## Verdict

**Technique 2 (usePlotArea() + SVG image/gradient clipped to plot rect) works cleanly and is the recommended approach.** The scene is precisely confined to the plot area with no axis bleed. Technique 1 (CSS layer) works but the scene bleeds into axis gutters — acceptable only if axis margins are zero or the design deliberately extends the scene wall-to-wall.

---

## Technique summary

### Technique 1 — CSS layer behind a transparent chart

A `position: relative` wrapper carries the scene photo as a CSS `background` (or absolutely-positioned `<img>`). The `ResponsiveContainer` / `LineChart` surface and fills are set to `background: transparent` so the CSS layer shows through.

**What it does well:**
- Dead simple — zero Recharts-specific API knowledge required.
- Works before the chart measures itself (scene appears immediately).
- Naturally responsive (CSS handles resize).

**The limitation:** The scene also fills the axis margins (left Y-axis gutter, bottom X-axis gutter, right padding). CSS has no knowledge of where Recharts computed the plot rectangle. You cannot clip a CSS background to `offset.left/top/width/height` because those values live in the Recharts SVG coordinate system, not the CSS box model.

**Visual result (screenshot b2-technique1.png):** Scene gradient fills the entire SVG element including axis gutters — the warm-orange bleeds behind the tick labels.

**Verdict:** Acceptable if the design intentionally extends the scene behind the axes (or axis margins are negligible). Not acceptable for the img-23 inspiration model where the scene is cleanly bounded.

---

### Technique 2 — usePlotArea() + SVG image/gradient clipped to plot rect  ✓ RECOMMENDED

A custom React component placed **directly inside `<LineChart>`** (SVG child, rendered first so it sits below everything in paint order) uses the Recharts 3.x public hook `usePlotArea()` to read `{x, y, width, height}` — the exact plot rectangle in SVG-pixel space. A `<clipPath>` scoped to that rect ensures pixel-perfect confinement.

**Recharts 3.x API confirmation:**
- `usePlotArea()` is a public exported hook in Recharts ≥ 3.1 (`es6/hooks.js` line 382, re-exported from `recharts/index.js`). It calls `useAppSelector(selectPlotArea)` internally.
- `selectPlotArea` returns `{ x: offset.left, y: offset.top, width: chartWidth - left - right, height: chartHeight - top - bottom }`.
- Components placed directly inside `<LineChart>` receive the `RechartsReduxContext` (the internal Redux store context), so `usePlotArea()` works without any prop-drilling.
- `<Customized component={...}>` is **deprecated in Recharts 3.x** and will be removed in 4.0. The modern pattern is direct placement. The spike confirms this works correctly.

**What it does well:**
- Scene is confined to exactly the plot area — axis margins remain dark/neutral.
- Fully responsive: `usePlotArea()` re-derives on chart resize.
- Swap the SVG gradient `<rect>` for `<image href="scene.webp" preserveAspectRatio="xMidYMid slice">` to use a real photo — same geometry applies.
- `<clipPath>` provides belt-and-suspenders: even if chart margins change (e.g. operator adds a Brush component), the image stays within the plot rect.

**The one gotcha:** `usePlotArea()` returns `undefined` on the very first render (before the chart measures its axes and writes to the Redux store). The component must handle this with an early `if (!plotArea) return null;`. In practice this is imperceptible — the chart and scene appear together after a single layout pass.

**Visual result (screenshot b2-technique2.png):** Scene gradient is cleanly bounded by the plot rectangle. Y-axis tick labels sit against the dark card background, not the scene. The white line and grid are legible on top.

---

## Code sketch for C1 (React/TSX, Recharts 3.x)

C1 can lift this pattern directly. The key insight: `SceneBackground` is a plain React component, not a Recharts-specific type — it just happens to be rendered inside the SVG layer.

```tsx
import { usePlotArea } from 'recharts';

interface SceneBackgroundProps {
  /** Absolute URL or data-URL of the scene WebP. */
  imageHref: string;
  /** Unique ID for the SVG clipPath def — must be unique per page if multiple charts exist. */
  clipId: string;
}

/**
 * Renders the scene photo behind the Recharts plot area.
 * Place as the FIRST child of <LineChart> so it paints below all chart elements.
 *
 * usePlotArea() is public API since Recharts 3.1. It returns the plot rect
 * in SVG-pixel space: { x, y, width, height }. Returns undefined before the
 * chart measures itself — handled with early return (imperceptible to users).
 */
function SceneBackground({ imageHref, clipId }: SceneBackgroundProps) {
  const plotArea = usePlotArea();
  if (!plotArea) return null;

  const { x, y, width, height } = plotArea;

  return (
    <g className="scene-background">
      <defs>
        <clipPath id={clipId}>
          <rect x={x} y={y} width={width} height={height} />
        </clipPath>
      </defs>
      <image
        href={imageHref}
        x={x}
        y={y}
        width={width}
        height={height}
        preserveAspectRatio="xMidYMid slice"
        clipPath={`url(#${clipId})`}
        // Decorative background — hidden from AT; the chart aria-label covers it.
        aria-hidden="true"
      />
    </g>
  );
}

// Usage inside the chart:
<ResponsiveContainer width="100%" height={260}>
  <LineChart data={hourlyData} margin={{ top: 16, right: 24, bottom: 8, left: 8 }}>

    {/* Scene first — paints below everything else in SVG paint order */}
    <SceneBackground imageHref={sceneUrl} clipId="temp-chart-scene-clip" />

    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.12)" />
    <XAxis dataKey="hour" ... />
    <YAxis domain={[minTemp - 5, maxTemp + 5]} ... />
    <Tooltip ... />
    <Line type="monotone" dataKey="temp" stroke="#ffffff" strokeWidth={2.5} dot={false} />

  </LineChart>
</ResponsiveContainer>
```

---

## Chart configuration is file-based

Charts — including their data series, axis ranges, and the scene/background image — are configured through chart config files in the Belchertown `graphs.conf` tradition, not through the dashboard UI. The operator edits those files to define what a chart shows and which scene image (if any) appears behind the plot area. The C1 temp-curve card reads that config and passes `imageHref` to `SceneBackground` at render time; the dashboard UI has no chart-configuration controls.

---

## Gotchas C1 must handle

### Chart surface transparency
The chart's SVG `<rect class="recharts-surface">` background defaults to transparent in Recharts, but the `<ResponsiveContainer>` wrapper `<div>` inherits CSS background. Make sure the card background (the glass/frosted card per ADR-048 design tokens) is the only opaque layer outside the chart — the chart wrapper div must be transparent or explicitly set to `background: transparent`.

### clipPath ID uniqueness
If the Today's Temperature card appears more than once on a page (e.g. side-by-side compact variants, or SSR-rendered duplicates), the `clipId` must be unique per instance. Use React `useId()` to generate stable unique IDs:

```tsx
const clipId = `temp-chart-scene-clip-${useId().replace(/:/g, '')}`;
```

(The `:` characters in `useId()` output are invalid in SVG `id` attributes — strip them.)

### Responsiveness
`usePlotArea()` reads from the Recharts Redux store which updates on `ResizeObserver` callbacks. No additional work needed for resize — the hook handles it. However, the `<clipPath>` rect dimensions are also reactive because they derive from the hook return, so the clip stays accurate after resize.

### `<Customized>` deprecation — do not use
As confirmed in the installed source (`node_modules/recharts/es6/component/Customized.js`): the component carries a `@deprecated` JSDoc comment: "Starting from Recharts 3.x, all charts are able to render arbitrary elements anywhere, and Customized is no longer needed. Will be removed in 4.0." C1 must use direct placement + `usePlotArea()`, not `<Customized>`.

### Photo loading — no `<img>` alt on the SVG `<image>`
SVG `<image>` elements do not support the HTML `alt` attribute. The photo is decorative (the chart line and axes communicate the data). Mark it `aria-hidden="true"` (as shown in the code sketch). The chart container's `aria-label` and the sr-only data table (see accessibility note below) provide the accessible name and data.

---

## Accessibility note — constraint for C1 (do not solve in B2)

Per `rules/coding.md` §5 and ADR-026, the temp-curve card must meet WCAG 2.1 AA. The following constraints are flagged here for C1 to honor — they are not resolved in this spike:

1. **Chart container `aria-label`:** The `<ResponsiveContainer>` wrapper `<div>` must carry `role="img"` and `aria-label` summarizing the chart (e.g. "Today's temperature: high 93°F at 2 PM, low 61°F overnight. Hourly readings follow."). This is shown in the spike HTML but C1 must wire the actual data values.

2. **sr-only data table fallback:** A `<table class="sr-only">` with all 24 hourly readings must accompany the chart. Screen readers cannot navigate SVG chart elements. The spike includes this pattern — C1 must keep it current with real data.

3. **Scene photo contrast:** The operator is responsible for keeping the temperature line and axis tick labels legible over their chosen background image. A darken-scrim (`rgba(0,0,0,0.3)`) is available as an optional insurance layer between the scene photo and the chart elements.

4. **`prefers-reduced-motion`:** The background system (ADR-047) specifies no animation. The scene is static. No motion concerns for C1's chart specifically — but if C1 adds any animated line draw, it must respect `prefers-reduced-motion: reduce`.

---

## Verified against installed Recharts 3.8.1

All API names used in this findings note and the spike were verified against the installed package at `node_modules/recharts/`:

| Claim | Verified |
|---|---|
| `usePlotArea()` is public API (exported from `recharts`) | Yes — `es6/index.js` line 66 |
| `usePlotArea()` available since 3.1 | Yes — JSDoc in `es6/hooks.js` line ~392 |
| Returns `{ x, y, width, height }` | Yes — `es6/state/selectors/selectPlotArea.js` |
| `<Customized>` deprecated in 3.x | Yes — `@deprecated` JSDoc in `es6/component/Customized.js` |
| Direct child placement receives chart context | Yes — `RechartsReduxContext` is a standard React context; any descendant component inside `<LineChart>` can call `usePlotArea()` |
| No breaking change to offset shape in 3.x release notes | Confirmed — GitHub Releases search found no offset/plot-area breaking changes in 3.x |

---

## Files

| File | Purpose |
|---|---|
| `docs/design/mockups/B2-recharts-background.html` | Self-contained HTML spike (throwaway) |
| `docs/design/B2-recharts-background-findings.md` | This file — DRAFT findings |
| `c:\tmp\b2-technique1.png` | Screenshot — Technique 1 (CSS layer, bleed visible) |
| `c:\tmp\b2-technique2.png` | Screenshot — Technique 2 (usePlotArea, exact clip) |
| `c:\tmp\b2-fullpage.png` | Full-page side-by-side screenshot |
