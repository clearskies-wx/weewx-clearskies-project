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
| Consistency | 0.10 | **Interim since 2026-08-23: swell-dominance bucketing (the former fallback) unconditionally** — SurfBeat was removed from the system (operator ruling "surfbeat is gone"; its IG peak is the within-set wave-group period, not a set interval). The replacement inputs — set interval + waves-per-set from the dominant partition's spectral group statistics, set strength from SwellTrack per-partition break heights + spectral coherence — are proposed in `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` and await the operator's ruling before this row is amended and coded. | (was: SurfBeat set timing 0.6 / amplitude 0.4; swell-dominance fallback) |

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

## Amendment 1 (2026-08-27) — Consistency (row 5) rebuilt on spectral group statistics — **Status: Accepted (2026-08-27 — the plan's PA6 was the approval; operator in chat: "that was in the plan, why do i need to approve what i already approved"; the three §4.5 single-use rulings stand as written)**

**Basis.** Operator rulings recorded in `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md`: EVO-Q14
(2026-08-23, "q14 recommendation is fine"), Q3 (2026-08-27, sub-decisions A–E "yes"; the lead's
correction that nothing was in code yet was recorded back and the coding round re-authorised as
Q10 item 1 "yes"). SurfBeat was removed 2026-08-23 ("surfbeat is gone"). This amendment replaces the
row-5 interim text in the Decision table. It takes effect on the operator's acceptance of THIS text
in chat (rules/clearskies-process.md ADR discipline); the S2 coding round lands after that.

**Inputs of record.** `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.2, §3.3,
§4.3, §7; `WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md` §G (Kimura route verified from the
primary papers; Tm02 lag; KAT values §F.2); `PARTITION-NARROWNESS-SURVEY-2026-08-23.md` (measured
dominant-groundswell ν ≈ 0.17, κ ≈ 0.59; windsea ν ≈ 0.53; the half-way band rule recovers 0.92–1.17
of each partition's own energy; the spectral grid cannot resolve ν < 0.05).

**Row 5 becomes:**

| Component | Weight | Inputs | Internal modifiers |
|---|---|---|---|
| Consistency | 0.10 | `consistency = 0.6 × timing + 0.4 × amplitude`. **Timing** = `f_int(T_set / 60)` (brief §3.2 interval curve, piecewise-linear; the waves-per-set term is DROPPED — ruling B: timing weight 1.0 on the interval curve). `T_set = N_rep × Tm02`, `N_rep = 1/(1−p11) + 1/(1−p22)` (Kimura 1980 eq. 19), `p11`/`p22` from the bivariate-Rayleigh transition integrals (Kimura eqs. 5, 6, 12) with `ρ_K = κ/2` (Battjes & van Vledder 1984) and the set-wave threshold `H > H1/10`, i.e. `h* = 1.80 × h_rms` (ruling A — the code's existing set-wave definition; ≈ 7.6 min on the measured groundswell). `κ = |∫S_dom(f) e^{i2πf·Tm02} df| / m0` over the DOMINANT partition's band (ruling E; SWAN's `FSPR` is this quantity when requested). Band = half-way between adjacent partition peaks, outermost to the spectral edges (ruling C). Two-swell beat override per brief §3.3 step 3 (secondary ≥ 25 % of partition energy; `60 s ≤ T_beat ≤ 1800 s` → `T_set = max(T_set, T_beat)`). **Amplitude** = `f_amp(S)` (brief §4.3 table), `S = 0.4 × C′ + 0.6 × κ_dom`, `C′ = (C − 0.50)/0.17`, `C = 1 − H_lull/H_set` with `H_set = 1.27 × Hs_total,break`, `H_lull = √((0.42 Hs_dom,break)² + (0.63 Hs_rest,break)²)` on the main-break-zone transects. **Fallback** when no dominant-band spectrum exists for the hour: the swell-dominance bucketing for the WHOLE factor, unchanged. | none beyond the curves; every knot carries its source or "judgement" label (brief §3.2/§4.3) |

**Data path (ruling D).** The group statistics are computed ONCE at parse time where the spectrum
exists (`swan_runner.py`, the L2 DWR SPECOUT/TABLE parse that builds the per-timestep entries) and
attached as SCALARS per partition: `nu`, `qp`, `kappa`, `tm02_s`, `t_set_s`, `n_rep`, `band_hz:
[f_lo, f_hi]`. No 2-D array is attached to any carrier (M-0b memory rule). The scorer reads scalars.

**Single-use rulings (brief §4.5 — proposed here, accepted with this amendment):** (1) the at-the-
break partition share `Hs_dom,break / Hs_total,break` is a distinct measured quantity (SwellTrack
output after refraction and breaking), used only inside the ratio `C`; accepted. (2) `H_set` is
Size's face height entering only as a ratio denominator; accepted. (3) `swellDominance` stays the
no-spectrum fallback only.

**Consequences.** `SurfScoringBreakdown` wire shape unchanged (five 0–100 bars); the
`setTimingMinutes`/`setAmplitudeM` fields (SurfBeat era) are already gone. API-MANUAL §17 gains the
per-partition scalar fields on the `multiSwell` entries; DESIGN-MANUAL explainer text for Consistency
is rewritten ("sets arrive in a rhythm the spectrum's narrowness predicts; the bands are operator
judgement pending observation"). Known-answer tests: the Kimura table in
`WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md` §F.2 (κ 0.3/0.5/0.8 → N_rep 9.06/10.15/15.11 at
threshold Hs; the KAT ALSO states the H1/10-threshold values computed by the same independent
integration before looking at the implementation) and fixed synthetic spectra → exact T_set, C, S,
factor value.

## Amendment 2 (2026-09-03): R11 recovery documentation scope (R5 is recorded below)

**N/A for the recovery coding wave.** The accepted weighted-geometric-mean
formula and its five weights were not changed by A1/R1/R2, R4, R6/R7, R8b/R8c,
or R9. R5's exact-limit representation is recorded in the implementation note
below; it does not change the accepted scoring formula or weights. The R11
recovery source changes are in provider, orchestration, state, and health paths;
`enrichment/surf_scorer.py` is not part of the R11 source diff. No scoring
contract or weight is altered by this documentation reconciliation.

## Amendment 3 (2026-09-04): R5 exact κ=1 implementation note

**Status: as-built source clarification; no decision change.** The accepted
Consistency formula and its five scoring weights remain unchanged. The landed
wave-group implementation handles exact `κ = 1` by returning `p11 = p22 = 1`
and unbounded internal `nSet`, `nRep`, and `tSetS` values. The wire adapter
retains finite `ν`, `Qp`, `κ`, `Tm02`, and band values, and maps only those
unbounded fields to JSON `null`; it does not approximate the limit with an
epsilon or clamp. `nSet` is carried on each parsed partition. Invalid or
out-of-range spectral numeric input raises the typed expected numeric-domain
error and prevents publication of that cycle; unexpected programming errors
remain fatal. The source locations are `services/wave_groups.py` and
`services/swan_runner.py` in the marine implementation commit `25a7c62`.

This note documents implementation of the accepted design. It does not claim
live κ=1 occurrence or live end-to-end proof.

## References

- [SURF-SCORE-REBUILD-RESEARCH-BRIEF.md](../planning/briefs/SURF-SCORE-REBUILD-RESEARCH-BRIEF.md) — research basis and §6 operator rulings (2026-08-04)
- [ADR-096](ADR-096-scoring-restructure.md) — prior scoring restructure (display-level; per-category bar rule retained)
- [EYEBALL-FIX-PLAN-2026-08-04.md](../planning/EYEBALL-FIX-PLAN-2026-08-04.md) — items 1/5/6, decisions D1/D3/D4 (D3 superseded into this ADR; D1/D4 resolved by it)
- Scarfe, Elwany, Mead & Black — The Science of Surfing Waves and Surfing Breaks: A Review — https://escholarship.org/uc/item/6h72j1fz
- UN HDI methodology change (arithmetic → geometric mean, 2010) — precedent for limiting factor substitutability in composite indices
