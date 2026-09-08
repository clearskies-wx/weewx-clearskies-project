# Fishing and Boating remediation — scorer known-answer cases

**Status:** Phase 2 working design evidence. These cases use the fixed formula
in the remediation plan §3.6.1. They are not a claim that current production
implements it.

## Formula reminders

`core = 100 × temperature^0.50 × tide_current^0.30 × pressure^0.20`.

For stable pressure, base is `1.00`; for gentle, moderate, and rapid changes,
the bases are `0.95`, `0.80`, and `0.60`. The selected profile's sensitivity
changes this with `1 − sensitivity × (1 − base)`. Refinements apply only after
a viable core: time `1.10/1.00/0.90`, season `1.15/1.00/0.85`, and solunar
`1.03/1.01/1.00`. `final = min(100, core × time × season × solunar, core + 10)`.

## Independent arithmetic cases

| Case | Inputs | Arithmetic | Expected result | What it distinguishes |
|---|---|---|---|---|
| Stable, optimal | T=1.00, tide=1.00, pressure=1.00; normal refinements | core = 100 | 100, Active | Stable pressure never imposes a permanent species penalty. |
| Rapid change, sensitivity 1 | T=1.00, tide=1.00, base=0.60, sensitivity=1 | pressure=0.60; core = 100 × 0.60^0.20 = 90.29 | 90.29 before refinements | Pressure response is conditional on change. |
| Rapid change, sensitivity 0 | T=1.00, tide=1.00, base=0.60, sensitivity=0 | pressure=1.00; core=100 | 100 | Species with zero sensitivity are unaffected. |
| Gentle rising change, sensitivity 1 | T=1.00, tide=1.00, absolute three-hour change=2 hPa, sensitivity=1 | pressure base=0.95; core = 100 × 0.95^0.20 = 98.98 | 98.98 before refinements | The approved default uses change magnitude, so rising and falling changes of the same magnitude have the same pressure result. |
| Gentle falling change, sensitivity 1 | T=1.00, tide=1.00, absolute three-hour change=2 hPa, sensitivity=1 | pressure base=0.95; core = 100 × 0.95^0.20 = 98.98 | 98.98 before refinements | Pressure direction remains factual display context; it is not an unsupported feeding bonus. |
| Preferred tide/current | T=1.00, tide/current=1.00, pressure=1.00 | core = 100 | 100 | The selected profile's preferred state has the fixed full factor. |
| Acceptable tide/current | T=1.00, tide/current=0.70, pressure=1.00 | core = 100 × 0.70^0.30 = 89.85 | 89.85 | The selected profile's acceptable state is distinct from preferred and poor states. |
| Poor tide | T=1.00, tide=0.40, pressure=1.00 | core = 100 × 0.40^0.30 = 75.97 | 75.97 | Tide/current uses the selected profile rule, not universal ebb/flood folklore. |
| Good temperature | T=0.80, tide=1.00, pressure=1.00 | core = 100 × 0.80^0.50 = 89.44 | 89.44 | The good band is below optimal without becoming inactive. |
| Marginal temperature | T=0.45, tide=1.00, pressure=1.00 | core = 100 × 0.45^0.50 = 67.08 | 67.08 | Temperature materially constrains the core. |
| Outside active band | temperature hard stop | no core/refinements | 0, Inactive | No tide, moon, or time value can rescue inactive temperature. |
| Regulatory closure | closure hard stop | no core/refinements | 0, Inactive | Legal availability precedes all scoring. |
| Missing required core input | Target-depth temperature, tide/current, or pressure unavailable after eligible source resolution | no core/refinements | score/status/core/suitability all null | Missing data is not converted into a scientifically meaningful-looking score. |
| Solunar ceiling | core=30, time=1.10, season=1.15, major=1.03 | raw = 39.09; ceiling = 40 | 39.09, Low activity | Solunar/refinements cannot create an Active result from a poor core. |
| Full refinements cap | core=95, time=1.10, season=1.15, major=1.03 | raw = 123.78025; min(100, 123.78025, 105) | 100, Active | Final score is bounded at 100. |
| Lower-activity season | core=80, time=1.00, season=0.85, no solunar period | raw = 68; ceiling = 90 | 68, Active | A documented lower-activity season is bounded and cannot operate as a legal closure. |
| No species adjustment available | Valid core=80; no direct, geographic-group, or geographic-category refinement evidence; time=season=solunar=1.00 | final = 80; explanation identifies the absent adjustment | 80, Active | Missing refinement evidence is neutral and disclosed; it is not borrowed from another species. |
| Direct-species profile resolution | Exact selected source species has a complete location-eligible record | resolve direct source-species record before any broader fallback | `profileLevel=direct_species`; the direct record supplies each factor | Direct evidence takes priority over every fallback. |
| Collapsed-group profile resolution | Eligible members share the same candidate group and every compared effective field | complete-profile equality=true | `profileLevel=collapsed_group`; one disclosed choice contains all members | A familiar group is valid only after complete equality, not shared naming. |
| Geographic-category fallback resolution | No direct or collapsed-group record applies; the selected member belongs to one complete geographic functional category | resolve the region-and-category record, such as all regional rockfish or all regional bottom fish | `profileLevel=functional_category`; each factor retains its own provenance | The final fallback remains geographic and category-specific, never one generic regional fishing profile. |
| Complete-profile difference in provenance | Members have numerically equal factors but one factor arrives from a different fallback level or evidence classification | equality over provenance fields=false | Separate disclosed practical choices | Provenance can change a score's meaning and therefore prevents collapse. |
| Matching-profile collapse | Two eligible source species share every effective field in the matrix comparison contract | equality over all compared fields = true | One disclosed practical group, with both member taxa | Collapse is data equality, not name similarity. |
| Differing-profile split | Two eligible source species share a familiar group label but differ in target depth, legal rule, or any score field | equality over all compared fields = false | Separate disclosed practical choices | One meaningful difference prevents collapse. |

## Required profile and selection cases

- Matching source species may collapse only when every temperature, tide/current,
  pressure, time, seasonal, habitat-depth, and legal-availability field matches.
- A single differing field prevents collapse and each source species remains a
  separate practical choice.
- A missing direct profile records the actual missing source input and its
  documented fallback level; it must not silently borrow another species'
  behavior.
- The implementation test must run these cases through an independently
  calculated expectation, then Phase 4/Gate 4 verifies the deployed scorer with
  timestamped live inputs.
