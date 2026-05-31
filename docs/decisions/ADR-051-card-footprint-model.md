---
status: Accepted
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-051: Card footprint model & grid-compatible sizing

## Context

Track A4 is the final Track A foundation: decide how cards are **sized** so that fixed layouts built now
drop into a **future customizable grid** without redesign. The grid **engine** (operator move/resize, layout
persistence, drag) is explicitly a **separate future plan** — not built or designed here. This ADR decides
the **footprint vocabulary, sizing tokens, row model, page anatomy, and responsive collapse** only.

**Why this model exists (the *why*, not just the *what*).** The end goal is an **operator-customizable
dashboard** — the **operator** (not the visiting public) uses a drag-and-drop layout tool (Now page first)
to add, remove, and rearrange cards, building the page their visitors then see. Every decision here is the
**contract that future engine consumes**: footprints tell it how much space a card claims; minimum
footprints let it reject a drop that would clip a card; the half-row track + zero-waste packing let cards
retile cleanly on add/remove/move; the universal card discipline means there is nothing but cards to move.
Locking this now means **no card needs redesigning when the operator drag-and-drop grid is built.**

Locked directional input (NOTES.md, plan §"Out of scope"): the future home page is a **4-column grid**;
cards span **1/2/3/4 columns** and may be multiple rows tall; tiles are **uniform translucent glass**
(bento style), not organic blobs; card header = title + thin underline rule.

As-built starting point ([ADR-048](ADR-048-theme-color-tokens.md), dashboard `index.css`): radius tokens
exist (`--radius` 0.625rem + derived scale; cards use `rounded-xl` = 0.875rem); card surface is `bg-card`
with a subtle ring; shadcn Card is fluid-width and container-query aware. **Missing, and defined here:**
spacing/gutter tokens, column-width math, row-height convention, the 4→2→1 breakpoint strategy, container
max-width, and the translucent-glass surface treatment.

Operator-reviewed render: [mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) (footprints at
desktop/tablet/phone, glass over a stand-in background).

## Options considered

| Option | Verdict |
|---|---|
| Fixed-pixel cards, no grid awareness | **Reject** — forces a full redesign when the grid lands; defeats the compatibility constraint. |
| Build the customizable grid engine now | **Reject** — out of scope (separate future plan); premature before components exist. |
| Fixed row height, cards snap to row units now | **Reject for now** — would clip rich cards (the "too much info" density tension). |
| **Footprints now (col-span enforced, row-span declared), content-driven height** | **Chosen** — grid-forward without the engine; nothing clips today, every card already knows its footprint for later. |
| Column count 3 / 6 | **Reject** — 4 is the locked direction; 4→2→1 collapses cleanly without orphan rows. |
| Container 72rem (as-built) | **Reject** — bumped to 80rem so 4 columns have room. |
| Full-row track only (strips pinned to a fixed height) | **Reject** — a lone half-height strip orphans an empty half-row beneath it. |
| **Half-row base track; cards span in half-row multiples** | **Chosen** — strips (header/controls/alert) pack with zero waste; data cards span 2 tracks, tall cards 4. |
| Page chrome (title/controls) as free page elements | **Reject** — reintroduces free-floating content; everything is a card (page-header card + controls strip). |

## Decision

**Footprint vocabulary** (col-span × row-span):

- `tile` = 1 col · `wide` = 2 col · `panel` = 3 col · `full` = 4 col
- Tall cards add **row-span** (e.g. the Wind Compass = `wide` + 2 rows = **2×2**).

**Minimum footprint per card.** A card may declare a *minimum* span below which its content clips. Surfaced
by the webcam (a 2×1 timelapse clips → **minimum 2×2**). Locked minimums for the signature/large cards:
Current Conditions, Wind Compass, Radar, Webcam = **2×2**; Active Alert and Today's Highlights = **full
(4×1)**; stat tiles = **1×1**.

**Column rule now vs. later.** Column-span is **enforced today** (cards lay out in a CSS grid). Row-span is
**declared/documented** per card for the future grid, but card **height stays content-driven** until the
grid engine exists — so nothing is clipped by a forced row height.

**Responsive collapse:** 4 columns (desktop ≥1024px) → 2 columns (tablet ≥768px) → 1 column (phone
<768px). `full`/`panel` cards become full-width of the current column count; `2×2` cards stay 2-wide and
tall at tablet; everything stacks in reading order on phone.

**Row model — half-row track, zero-waste packing.** The grid's base **row track is the half-row** (`--card-
half-row`, 5.5rem). Cards span row tracks in half-row multiples: a **strip** (page-header, controls, alert
banner) = **1 track**; a **standard data card** = **2 tracks** (= `--card-row` 11rem); a **2×2 / tall card**
= **4 tracks** (22rem). This guarantees half-height cards **pack with no orphaned half-row**: two stacked
strips (e.g. page-header + controls) occupy two consecutive half-tracks = exactly one data-row of height,
no gap. Footprint **badges/vocabulary stay in full-row terms** (1×1, 2×2, 4×½) — only the underlying CSS
track is the half-row, for packing. (Operator-reviewed render:
[mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html).)

**Sizing tokens** (new, to live in dashboard `index.css` `@theme`):

| Token | Value | Meaning |
|---|---|---|
| `--gap-grid` | `1rem` | gutter between cards (both axes) |
| `--container-max` | `80rem` | dashboard content cap (was 72rem) |
| `--card-half-row` | `5.5rem` | **base grid row track**; strips span 1, data cards 2, tall cards 4 |
| `--card-row` | `11rem` | a standard data row = 2 half-row tracks (conceptual full-row pitch) |
| radius | reuse `rounded-xl` (0.875rem) | from ADR-048 |

**Card surface = translucent glass.** Cards are semi-opaque over the A2 photo background with a subtle
`backdrop-filter` blur (uniform tiles, not blobs). The **exact opacity/contrast value is set at the B3
contrast/perf gate**, not fixed here.

**Universal card discipline (ALL pages).** The card model is the *only* layout primitive — there is no
free-floating page-level content anywhere on the site.

- **One container, one width.** Every page renders inside the same `--container-max`, whether it's a
  multi-card grid (Now) or a single-purpose page (Records, Reports, About, Legal). A "simple" page is not
  free-form — it is **one or more `full`-width cards** (content-height, not row-constrained). This keeps
  page widths uniform across the whole site; no page varies its own width.
- **Page-header card (a card, not free text).** Every page opens with a `full`-width **half-row** page-header
  card holding the page title + short info. **On the Now page this card *is* the hero** — it carries the
  station logo + station name (its full content/design is a Track C **C1** job; A4 only establishes it is a
  card). On other pages it is a title + one-line-info card replacing today's free-floating page text.
- **Controls belong to a card.** Tabs, period selectors, sort controls, and buttons (e.g. Records period
  selector, Forecast time-range tabs, Reports download/toggle) live **inside a card** — never floating on the
  page background. Two patterns by volume: **few controls → inline** in the page-header card (right-aligned);
  **many controls → a dedicated `full`-width half-row controls strip** directly below the header.
- **No generic explanatory prose on data pages.** Educational/explainer text (e.g. the Reports page's
  generic intro) does not belong on the page; it belongs in the **user manual/help**. Pages show data +
  controls only. **Distinction:** *data-contextual microcopy* — units, empty/"no data" states, legends, a
  one-line card subtitle — is legitimate and stays **inside its card**; only *generic educational prose*
  relocates to the manual.

## Consequences

- Dashboard `index.css` gains the spacing/container tokens; a **footprint convention** (col-span/row-span
  utility classes, or a Card `footprint` prop mapping to them) is introduced. This is **build work in a
  Track A/C code batch — not done by this ADR.**
- Every Track C component declares a **footprint + minimum footprint** as part of its card spec.
- The translucent surface couples to **ADR-047 (A2 background)** and the **B3 contrast gate** — cards must
  stay WCAG-legible over photos in both themes.
- The Almanac page currently renders as a vertical stack (departs from footprints) — reconciled to the
  footprint model during its Track C pass, not here.
- **Restore the Now-page hero (tracked, Track C / C1).** The page-header card on Now = the hero showing
  **station logo + station name**; it was dropped and never redesigned. A4 establishes it is a card; its
  content/design is a **C1** deliverable (ties to ADR-022 branding / ADR-049 logo alt).
- **Uniform page width site-wide** — no page renders wider/narrower than `--container-max`.
- **Existing pages must be reconciled to the universal card discipline** in their Track C passes:
  Records' free-floating buttons → moved into a card; Reports' generic explainer → relocated to the manual;
  any other page-level chrome → wrapped in a card. These are per-page reconciliation items, not done here.
- **Operator manual is a confirmed future deliverable.** The operator-customizable dashboard will need an
  **operator manual** so operators know how to set up and use the layout tool (and the system generally).
  This is its own build, tracked outside A4 — flagged here because the customizable-grid feature depends on
  it. Generic explainer prose pulled off data pages (e.g. the Reports intro) that is *operator-facing* lands
  here. (Any *visitor-facing* help destination — About page / a Help route — remains a smaller open item.)
- No grid engine, drag-resize, or layout persistence ships — any such work is the separate future grid plan.

## Acceptance criteria

- [ ] Footprint vocabulary (`tile`/`wide`/`panel`/`full` + row-span) is defined and every Track C card
      declares both a footprint and a minimum footprint.
- [ ] Tokens `--gap-grid` (1rem), `--container-max` (80rem), and the conceptual `--card-row` (11rem) exist
      in the dashboard theme; container cap is 80rem.
- [ ] Cards reflow **4→2→1** at ≥1024 / ≥768 / <768px; no card renders narrower than one column.
- [ ] Cards with a minimum row-span (Webcam, Current Conditions, Wind Compass, Radar = 2×2) never render at
      a clipping height.
- [ ] Card surface is translucent glass over the A2 background; final opacity meets the **B3 contrast floor**
      in both themes.
- [ ] No grid engine / drag-resize / persistence is shipped (out of scope — future grid plan).
- [ ] Every page renders within `--container-max`; no page varies the shared site width.
- [ ] No control (tab / button / selector) renders outside a card; all live in a card header or controls card.
- [ ] No generic explainer prose renders on a data page; only data-contextual microcopy remains, in-card.
- [ ] Grid base track = `--card-half-row` (5.5rem); strips span 1, data cards 2, tall cards 4 — two stacked
      half-row strips equal one data-row with **no orphaned half-row** anywhere.
- [ ] Every page opens with a page-header card (the hero on Now); controls render inline in it when few, or
      in a dedicated half-row controls strip when many.

## Implementation guidance

- Represent footprints with Tailwind v4 `col-span-{1..4}` + `row-span-{1..3}` (or a Card `footprint` prop
  that maps to those classes). The shadcn Card is already container-query aware — good for laying out a
  card's *internals* responsively within its footprint.
- Reuse the ADR-048 radius scale; do not introduce a new radius token.
- Keep the grid definition in one place so the future grid engine can replace the static `grid-template`
  without touching individual cards.
- Locked visual reference: [mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) (representative
  Now-page footprints; the exact Now layout is finalized per-component in Track C, not by this ADR).

## References

- Related ADRs: ADR-048 (radius/card-surface tokens — built on here), ADR-047 (A2 background — cards sit over
  it), ADR-026 (a11y/contrast) + the **B3 contrast/perf gate** (sets final card opacity), ADR-049 / ADR-050
  (A3 icons — sibling foundations).
- Inventory: `docs/design/C0-PAGE-INVENTORY.md` (per-page card list the footprints apply to).
- Mockups: `docs/design/mockups/A4-card-grid.html` (footprints + responsive collapse),
  `docs/design/mockups/A4-page-anatomy.html` (page-header/hero card, controls strip, half-row zero-waste packing)
- Out of scope: the **customizable card grid** (engine, move/resize, persistence) — separate future plan per
  `docs/planning/UI-REDESIGN-PLAN.md` §"Out of scope here".
- Plan: `docs/planning/UI-REDESIGN-PLAN.md` Track A4
