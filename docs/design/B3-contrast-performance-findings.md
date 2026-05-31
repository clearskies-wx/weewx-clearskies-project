# B3 Findings — Card-glass opacity and scene image performance

**Status:** Final.
**Date:** 2026-05-31
**Decision source:** user direction 2026-05-31 (no ADR for this item).

---

## Decision

Card-glass opacity is an **operator-configurable default** over the scene background image. There is no hard-locked contrast value and no research gate. The PROVISIONAL flag in `index.css` has been removed.

**Shipped defaults:**
- Light theme: `rgba(255, 255, 255, 0.72)`
- Dark theme: `rgba(30, 35, 55, 0.55)`
- `backdrop-filter: blur(8px) saturate(1.1)`

Operators may override these values in their config. The defaults were chosen for legibility; operators overriding opacity or background images should keep card text legible. A darken-scrim (`rgba(0,0,0,0.3)`) is available as an optional insurance layer.

## Performance

8 WebP scene/overlay assets at ≤ 300 KB each. Only the active scene and its overlay load at runtime. This is within ADR-033's budget; the images are separate assets, not part of the 200 KB JS bundle.
