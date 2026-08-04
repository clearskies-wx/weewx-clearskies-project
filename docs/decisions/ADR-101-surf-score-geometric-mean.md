# ADR-101: Surf Score Rebuild — Weighted Geometric Mean of Five Components

**Status:** Accepted (2026-08-04 — operator approval in chat: "adr 101 approved")

## Context

The surf quality score (0–100 + stars) has never had its own ADR. Its formula was ported from a
pre-Clear-Skies extension whose research basis is lost ("weights came from research and
discussion" — MARINE-SURF-FISHING-RESEARCH-BRIEF §7.4), then restructured for display by ADR-096
without re-examining the formula itself. The 2026-08-04 operator eyeball review found the current
system fails its only purpose — a visitor cannot understand how the factors produce the total:

- Three additive components (35/35/30) coexist with three multiplicative adjustments
  (beach alignment ×0.1–1.0, directional exposure ×0.1/1.0, time-of-day ×0.9–1.1) displayed as
  context-dependent signed point deltas — percentage cuts of a running subtotal, applied in a
  hidden order.
- Components overflow their stated maxima (period > 35; organization-wind 18 of "15").
- Time of Day has been structurally dead since C-47 (inputs hardcoded `None`).
- The model computes the sport-science literature's most important surfability parameters — peel
  angle, breaker intensity (Iribarren), set consistency (SurfBeat) — and the score uses none of
  them, while the alignment/exposure multipliers date from the deep-water-input era and plausibly
  double-count physics now embedded in `breakingFaceHeight`.
- The deepest defect, identified by the operator during redesign: **additive-to-100 scoring
  assumes compensability** — that strength in one factor offsets weakness in another. This is
  false for surf at the extremes: nothing compensates for a closeout or blown-out wind. Under
  every additive variant tried, a clean 6-ft closeout day still scored ~66/100.

Full research basis: [SURF-SCORE-REBUILD-RESEARCH-BRIEF.md](../planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md)
(sport-science factor evidence §1/§1b, competitor survey §3, measurement inventory §4, operator
rulings §6, final proposal §7).

## Options considered

| Option | Verdict |
|---|---|
| Keep additive pools, fix display only | Excluded — cannot express veto; closeout day scores ~66 |
| Additive pools + subtractive penalties (wind, fixed 0 to −100 scale) | Excluded — handles only extrinsic ruiners; intrinsic vetoes (closeout) still overscore; penalty taxonomy added explanatory burden |
| Minimum logic (score = weakest factor) | Excluded — perfect veto but zero differentiation above the bottleneck; distinct days tie |
| **Weighted geometric mean of five 0–1 factors** | **Chosen** — behaves as a weighted average when factors are balanced (mid-range compensation is real in surf), collapses when any factor collapses (veto inherent). Precedent: UN HDI switched arithmetic → geometric (2010) to limit substitutability. Eliminates penalties entirely. |

## Decision

`score = 100 × Size^0.25 × Shape^0.25 × Conditions^0.20 × Power^0.20 × Consistency^0.10`

Each factor is internally 0–1.0, displayed as 0–100. Weight exponents sum to 1.0 and encode
surfer importance (brief §1b), never data quality/convenience (operator apportionment principle).
Stars = score/20 (unchanged). Any factor at 0 → score 0.

**Weights are operator-configurable (operator addition, 2026-08-04).** Because the importance
evidence is ordinal and the exact numbers are judgment, the values above are the shipped
DEFAULTS; the admin config UI exposes the five weights for adjustment — **one weight set for the
whole system, not per spot**. Weights are normalized by their sum at computation time (so the
operator can enter any positive values and the effective percentages are shown), with a
reset-to-defaults affordance. The factor definitions, curves, and single-use assignments are NOT
operator-configurable — only the weights.

The five components and the single-use assignment of every measurement (operator rule: every
measured quantity feeds exactly ONE component, as input or internal modifier):

| Component | Weight | Inputs | Internal modifiers (never displayed) |
|---|---|---|---|
| Wave Size | 0.25 | `breakingFaceHeight`, band curve (flat → ~0, rideable band → 1.0, too big → reduced) | beach alignment; directional exposure |
| Wave Shape | 0.25 | peel angle band curve (closeout ~0° → ~0; ~45–70° → full; >~70° mush → reduced) + breaker type (Iribarren) | jacking factor sweetener (> 1.3) |
| Conditions | 0.20 | wind speed/direction vs beach facing + cleanliness (DSPR, cross-swell) | ruin states rated harshly (blown out → ≤ 0.05) |
| Swell Power | 0.20 | dominant `multiSwell` partition period + energy (NOT Tm01) | short-period discount |
| Consistency | 0.10 | SurfBeat set timing/amplitude | fallback: swell-dominance proxy when SurfBeat disabled |

**Within-component aggregation:** sub-inputs blend by weighted **arithmetic** mean (compensatory)
with FIXED internal weights; the **geometric** (non-compensatory) aggregation exists across
components only. The complete variable inventory — every scoring input with its source, role,
and internal weight, plus the explicit not-an-input list — is brief §7.2 and is **binding on
implementation**: an inventoried variable the code ignores is a defect; an un-inventoried
variable the code reads violates single-use. Internal weights are not admin-adjustable (only the
five top-level weights are).

Removed entirely: the three displayed adjustments (beach alignment, directional exposure, time of
day), the adjustments display column, time-of-day scoring as a concept (dead since C-47), and
Tm01 as a scoring/headline statistic (the dominant-partition convention applies everywhere —
resolves eyeball decision D1; the removal resolves D4).

Display: score + stars + five bars, each 0–100 (fixed denominator; ADR-096 per-category fill
rule trivially satisfied). Visitor explainer: "The score is a weighted geometric mean of the five
factors — they average together, but one very poor factor sinks the whole score."

## Consequences

- Every factor can independently ruin the day — the property no additive variant could provide.
- No signed rows, no hidden multiplier order, no percentage-of-subtotal arithmetic, no component
  overflow past its stated max.
- Bars no longer sum to the total; the explainer sentence carries the aggregation story. The
  operator accepts this explicitly.
- The score becomes sensitive to factor-curve calibration near 0 (geometric mean punishes low
  values hard); ruin-state mappings must be set deliberately and verified with worked examples.
- `SurfScoringBreakdown` wire contract changes shape (five 0–100 factor fields replace the
  3-factor + 3-adjustment structure) — a breaking data-contract change for the dashboard
  (trigger 4), shipped as one coordinated API+marine+dashboard round.
- Peel angle, breaker type, and SurfBeat set data become scoring inputs for the first time; their
  null/availability handling becomes score-critical instead of display-critical.
- DESIGN-MANUAL scoring sections, API-MANUAL §SurfScoringBreakdown, and the scoring explainer
  modal content all require same-round updates (doc-code sync).
- New config keys for the five weights (system-wide surf scoring section) flowing through the
  existing config path (admin → API → marine service `/config` per the add-on invariant — the
  admin never talks to the marine service directly). New admin section ⇒ `help.admin.*` keys and
  Operator Manual updates in the same round (doc-code sync). Not a wizard step — admin only.

## Implementation guidance

1. **Factor curves:** carry forward existing calibrated tables where they exist (height ranges,
   wind brackets, DSPR buckets), rescaled to 0–1.0; author new band curves for peel angle,
   breaker type, and set timing. Every curve documents its ruin-state mapping (e.g., blown out
   ≤ 0.05, closeout ≤ 0.05).
2. **Worked examples gate:** before merge, publish computed scores for at least: balanced good
   day, clean closeout day, blown-out epic swell, small clean day, flat day — each with the five
   factor values and the resulting mean, reviewed by the operator against intuition and Surfline.
3. **Null handling:** per factor, choose neutral-0.5 vs exclude-and-renormalize-exponents; decide
   per factor in the implementation plan, documented in API-MANUAL.
4. **Known-answer tests** (rules/verification.md): fixed synthetic inputs → exact expected
   factor values and total; plus the regression guard that bars render with denominator 100.
5. **Single-use audit:** grep-level check that no measurement feeds two components.
6. **Weight configuration:** admin form with the five weights pre-filled (current values),
   effective-percentage display (value ÷ sum), reset-to-defaults button; scorer normalizes by
   sum at computation time so any positive inputs are valid; reject zero/negative values at the
   form. Defaults live in code, not config — an absent config section means defaults.
7. **Rollout:** one coordinated round across marine (scorer), API (contract), dashboard (bars +
   explainer), stack (admin weights section); the old adjustments UI is deleted, not hidden.
7. Out of scope, explicitly: skill-level lenses, spot-relative calibration, crowding, section
   length (peel angle covers it), any tide-based scoring.

## References

- [SURF-SCORE-REBUILD-RESEARCH-BRIEF.md](../planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md) — research basis and §6 operator rulings (2026-08-04)
- [ADR-096](ADR-096-scoring-restructure.md) — prior scoring restructure (display-level; per-category bar rule retained)
- [EYEBALL-FIX-PLAN-2026-08-04.md](../planning/EYEBALL-FIX-PLAN-2026-08-04.md) — items 1/5/6, decisions D1/D3/D4 (D3 superseded into this ADR; D1/D4 resolved by it)
- Scarfe, Elwany, Mead & Black — The Science of Surfing Waves and Surfing Breaks: A Review — https://escholarship.org/uc/item/6h72j1fz
- UN HDI methodology change (arithmetic → geometric mean, 2010) — precedent for limiting factor substitutability in composite indices
