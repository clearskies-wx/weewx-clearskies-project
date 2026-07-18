---
status: Proposed
date: 2026-07-18
deciders: shane
supersedes:
superseded-by:
---

# ADR-096: Surf scoring restructure — Wave Organization composite, SWAN-only data, TruShore branding removal

## Context

Production testing of the SWAN+TruShore implementation revealed five issues in the surf scoring system:

1. **Scorer uses NDBC instead of SWAN.** `_effective_swell()` in `surf_scorer.py` replaces SWAN nearshore height/period/direction with NDBC offshore buoy readings when spectral components are present. NDBC is 12 miles offshore — its values don't represent nearshore conditions.

2. **Score bar normalization bug.** Bar fill is normalized to 100 instead of each factor's own maximum. A score of 28/35 renders as 28% fill (barely visible) instead of 80% fill.

3. **Hidden multipliers.** Directional exposure and time-of-day modifiers affect the score without appearing in the scoring breakdown. The displayed factors don't explain the total.

4. **Missing scoring dimensions.** SWAN provides DSPR (directional spread) at every output point. Directional spread affects surf quality — tight spread means clean, organized waves; wide spread means messy, disorganized surf. SWAN also provides SPECOUT for detecting cross-swell interference. Neither is used.

5. **TruShore branding.** With SWAN handling structure physics (OBSTACLE, ADR-095), spectral decomposition (SPECOUT), and swell height (HSWELL), the "TruShore" name implies proprietary wave physics that don't exist. The system is SWAN; the value is in Clear Skies, the scoring system, and the integration pipeline.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep 4-factor scoring with NDBC | No code changes | NDBC overrides SWAN values (wrong), missing DSPR, hidden multipliers, bar normalization broken |
| 3-factor + composite Organization (chosen) | Absorbs wind + swell dominance into a richer composite, adds DSPR and cross-swell, sources all data from SWAN, surfaces all modifiers | New sub-factor weights need empirical validation for DSPR thresholds |

## Decision

Five changes to the surf scoring system:

**Decision 1: Three weighted factors.** Restructure from 4 factors (height 35%, period 35%, wind 20%, swell dominance 10%) to 3 factors (height 35%, period 35%, organization 30%). Organization is a composite sub-score: wind effect 50% (15% effective), swell dominance 25% (7.5%), directional spread 15% (4.5%), cross-swell interference 10% (3%).

**Decision 2: All scoring from SWAN.** NDBC spectral data removed from the scoring pipeline. `_effective_swell()` no longer overrides SWAN values. The scorer uses SWAN height/period/direction directly. NDBC spectral data retained in the surf response as reference data — not passed to `score_surf()`.

**Decision 3: All penalty/bonus factors surfaced.** Beach alignment (existing), directional exposure (was hidden), and time of day (was hidden) appear in the scoring breakdown as signed integers. `total = height + period + organization + beachAlignment + directionalExposure + timeOfDay`.

**Decision 4: Bar fill normalized to factor maximum.** Each bar's fill is proportional to its own maximum, not to 100. Wave Height 28/35 = 80% fill. Wave Organization 24/30 = 80% fill.

**Decision 5: TruShore branding removed.** Nearshore model referred to as "SWAN" everywhere. `nearshoreModel` field returns `"swan"` (not `"swan_trushore"`). `windSource` returns `"hrrr"` / `"gfs"` (not `"hrrr_trushore"` / `"gfs_trushore"`). The product is Clear Skies. The scoring system is the Surf Score. No proprietary physics branding.

## Consequences

- Organization sub-factors add DSPR and cross-swell to scoring — two new dimensions that leverage SWAN SPECOUT and TABLE output (ADR-095).
- DSPR thresholds (< 15° → 1.0, 15–25° → 0.7, 25–35° → 0.4, > 35° → 0.2) are based on published nearshore DSPR ranges and the KEWL Mermaid messiness rating precedent. Adjustable in future releases.
- Cross-swell detection uses SWAN SPECOUT at ~10m: secondary energy peak > 50% primary energy at > 30° angle difference → 0.4 score.
- `SurfScoringBreakdown` model gains: `waveOrganization`, `organizationWind`, `organizationSwellDominance`, `organizationDirectionalSpread`, `organizationCrossSwell`, `directionalExposure`, `timeOfDay`.
- Dashboard score bars need per-factor normalization (fill = score / factor_max, not score / 100).
- `grep -ri trushore` must return zero hits in active code, config, and docs (historical/archived excepted).
- `weewx-clearskies-trushore` repo renamed to `weewx-clearskies-swan`.
- NDBC fetch stays in surf endpoint; `spectralComponents` stays in response. Only the scorer and multiSwell field stop using NDBC.

## Acceptance criteria

- [ ] `score_surf()` uses 3 weighted factors summing to 100 max
- [ ] Organization sub-factors populated in scoring breakdown
- [ ] No NDBC data used in scorer — `_effective_swell()` override removed
- [ ] Scorer uses SWAN height/period/direction directly
- [ ] `beachAlignment`, `directionalExposure`, `timeOfDay` all present in breakdown as signed integers
- [ ] `total = height + period + organization + beachAlignment + directionalExposure + timeOfDay`
- [ ] Bar fill normalized to each factor's own maximum (not to 100) in dashboard
- [ ] `nearshoreModel` returns `"swan"` (not `"swan_trushore"`)
- [ ] `windSource` returns `"hrrr"` or `"gfs"` (not `"hrrr_trushore"` or `"gfs_trushore"`)
- [ ] `grep -ri trushore` returns zero hits in active code, config, and governing docs
- [ ] Dashboard displays "Model: SWAN" (not "SWAN+TruShore")
- [ ] NDBC fetch and `spectralComponents` response field retained as reference data
- [ ] `multiSwell` populated from SWAN SPECOUT, not NDBC

## Implementation guidance

- **Scorer restructure:** Replace 4-component weighted scoring table in `surf_scorer.py` with 3-component. Organization sub-score computed as weighted sum of wind (0.50), swell_dominance (0.25), dspr (0.15), cross_swell (0.10), then multiplied by 30 for the top-level contribution.
- **DSPR scoring:** Input from SWAN TABLE DSPR at ~10m depth point. Thresholds: < 15° → 1.0, 15–25° → 0.7, 25–35° → 0.4, > 35° → 0.2.
- **Cross-swell scoring:** Input from SWAN SPECOUT at ~10m. Detect multiple energy peaks at different directions. No cross-swell → 1.0, secondary > 50% primary at > 30° angle diff → 0.4.
- **Penalty surfacing:** Compute each as `applied_score - pre_penalty_score`. Additive with weighted factors.
- **Branding:** File rename `trushore.py` → `swan.py`, class `TrushoreProvider` → `SwanProvider`, `PROVIDER_ID = "swan"`. Update all import paths, config sections, response field values, documentation.
- **Bar normalization:** Dashboard change — fill width = `(score / factorMax) * 100%`, not `score%`.
- **Files affected (API):** `enrichment/surf_scorer.py`, `models/responses.py`, `endpoints/surf.py`, `providers/nearshore/trushore.py` → `swan.py`, `services/swan_runner.py`, `config/marine_config.py`, `cache_warmer.py`, `api.conf`.
- **Files affected (Dashboard):** `SurfingTab.tsx`, all 13 locale `marine.json` files.
- **Files affected (Docs):** `ARCHITECTURE.md`, `API-MANUAL.md`, `PROVIDER-MANUAL.md`, `OPERATIONS-MANUAL.md`, `DASHBOARD-MANUAL.md`, `CLAUDE.md`, `rules/clearskies-process.md`.

## References

- Related: ADR-093 (SWAN+TruShore), ADR-095 (SWAN model corrections)
- Amends: ADR-094 windSource field values: `"hrrr_trushore"` → `"hrrr"`, `"gfs_trushore"` → `"gfs"`
- Precedent: KEWL Mermaid messiness rating (directional spread at 30% of a sub-score)
- Plan: `docs/planning/SWAN-CORRECTIONS-PLAN.md` Phases 1, 4
