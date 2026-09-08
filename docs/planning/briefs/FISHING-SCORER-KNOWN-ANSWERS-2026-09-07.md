# Fishing scorer known answers — 2026-09-07

## Scope

These are Phase 2 hand calculations for the approved Fishing and Boating
Remediation Plan. They are independent of the existing scorer implementation.
They define regression expectations for the selected-species score after the
dynamic pressure-trend weighting recorded in
`FISHING-PRESSURE-TREND-SPORT-FISHING-RESEARCH-2026-09-07.md`.

No case uses fishing-legality data. The plan excludes that data.

## Calculation rules used

`core = 100 × temperature^0.50 × tide_current^0.30 × pressure^0.20`

For a signed local three-hour pressure change `delta` in hPa:

- `abs(delta) < 1` means stable pressure and factor `1.00`.
- Otherwise, `rate_weight = min(1, (abs(delta) - 1) / 2)`.
- Select the profile's falling multiplier for `delta <= -1` or rising
  multiplier for `delta >= 1`.
- `pressure = 1 + sensitivity × rate_weight × (selected_multiplier - 1)`.

After a valid core:

`final = min(100, core × time_of_day × season × solunar, core + 10)`.

The scorer compares unrounded values to the status boundaries. Display rounding
does not change a test's underlying expected value.

## Core-factor cases

| Case | Inputs | Hand calculation | Expected result |
|---|---|---|---|
| Optimal baseline | temperature `1.00`; preferred tide/current `1.00`; stable pressure `1.00`; normal refinements | `100 × 1^0.50 × 1^0.30 × 1^0.20` | core `100.00000`; final `100.00000`; Active |
| Acceptable tide/current | temperature `1.00`; acceptable tide/current `0.70`; stable pressure | `100 × 0.70^0.30` | core/final `89.85234`; Active |
| Poor tide/current | temperature `1.00`; poor tide/current `0.40`; stable pressure | `100 × 0.40^0.30` | core/final `75.96578`; Active |
| Good temperature | temperature `0.80`; preferred tide/current; stable pressure | `100 × 0.80^0.50` | core/final `89.44272`; Active |
| Marginal active temperature | temperature `0.45`; preferred tide/current; stable pressure | `100 × 0.45^0.50` | core/final `67.08204`; Active |
| Outside active temperature | target-depth temperature outside the selected profile's marginal active range | hard stop; do not calculate core or refinements | score `0`; Inactive |
| Missing target-depth temperature, tide/current, or pressure | the required input remains unavailable after its plan-authorized source resolution | withhold score; do not calculate core or refinements | score, status, core, and suitability are all `null` |

## Dynamic pressure cases

Use the completed black sea bass profile: sensitivity `0.75`, falling multiplier
`1.10`, stable multiplier `1.00`, rising multiplier `0.75`. Temperature and
tide/current are both `1.00`; refinements are normal.

| Three-hour delta | Rate weight | Pressure calculation | Core | Final / status | What it protects |
|---|---:|---|---:|---|---|
| `+0.5 hPa` | n/a | stable factor `1.00000` | `100.00000` | `100.00000`, Active | No permanent sensitivity penalty under stable pressure. |
| `-2 hPa` | `0.50` | `1 + 0.75 × 0.50 × (1.10 - 1) = 1.03750` | `100.73900` | `100.00000`, Active | A gradual falling trend uses only half of the profile response. |
| `-3 hPa` | `1.00` | `1 + 0.75 × 1.00 × (1.10 - 1) = 1.07500` | `101.45692` | `100.00000`, Active | A fast falling trend reaches the profile's full response. |
| `+2 hPa` | `0.50` | `1 + 0.75 × 0.50 × (0.75 - 1) = 0.90625` | `98.05045` | `98.05045`, Active | A gradual rising trend changes only the pressure factor. |
| `+3 hPa` | `1.00` | `1 + 0.75 × 1.00 × (0.75 - 1) = 0.81250` | `95.93226` | `95.93226`, Active | A fast rising trend reaches the full profile response. |
| Any non-stable delta; sensitivity `0` | any | `1 + 0 × rate_weight × (multiplier - 1) = 1.00000` | unchanged by pressure | unchanged by pressure | A pressure-insensitive profile never receives another species' response. |

## Refinement and status cases

| Case | Inputs | Hand calculation | Expected result |
|---|---|---|---|
| Preferred time | valid core `60`; preferred time `1.10`; normal season/solunar | `min(100, 60 × 1.10, 70)` | `66`; Active |
| Lower-activity season | valid core `80`; normal time; lower season `0.85`; no solunar modifier | `min(100, 80 × 0.85, 90)` | `68`; Active |
| Major-solunar ceiling | core `30`; preferred time `1.10`; peak season `1.15`; major period `1.03` | raw `39.08850`; ceiling `40` | `39.08850`; Low activity |
| Full-refinement cap | core `95`; preferred time `1.10`; peak season `1.15`; major period `1.03` | raw `123.78025`; ceilings `100` and `105` | `100`; Active |
| Hard stop cannot be rescued | temperature hard stop plus preferred time, peak season, and major solunar period | no core/refinements are evaluated | `0`; Inactive |

## Required implementation guards

The Phase 4 test suite must calculate these expected numbers directly from the
tables above, not by duplicating scorer helpers. It must prove that changing a
pressure delta changes only the pressure factor and dependent core/final score;
it must also prove that no refinement changes a hard-stop result or makes a
missing required input appear scoreable.
