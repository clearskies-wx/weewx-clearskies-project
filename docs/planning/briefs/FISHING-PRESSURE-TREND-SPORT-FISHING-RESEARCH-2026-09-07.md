# Fishing pressure-trend sport-fishing research — 2026-09-07

## Scope

This record answers one Phase 2 design question from the approved Fishing and
Boating Remediation Plan: how angler and sport-fishing sources use barometric
pressure information. It does not change the approved scorer, matrix fields,
or any runtime behavior.

## Sources reviewed

- [Outdoor Life: How Storms Affect Fishing and How to Fish When the Weather Turns](https://www.outdoorlife.com/how-storms-weather-affect-fishing/) — treats the direction of change, rather than the absolute pressure number, as the useful planning signal: falling pressure as an opportunity, rising pressure after a front as difficult, and extended stable conditions as predictable.
- [In-Fisherman: Understanding Barometric Pressure and How It Affects Fishing Success](https://www.in-fisherman.com/editorial/understanding-barometric-pressure/154358) — uses pressure trend together with water temperature, light, current, weather, and food-chain effects; it directs different angling tactics by situation rather than publishing a numerical species-response equation.
- [In-Fisherman: Barometric Pressure and Bass](https://www.in-fisherman.com/editorial/barometric-pressure-and-bass/153689) — presents rising, stable, and falling conditions as separate angling situations, while explicitly cautioning against treating pressure alone as a complete fishing predictor.
- [FishCaster](https://www.fishcasterapp.com/) — lets anglers create personal criteria using a pressure range plus rising, falling, or steady trend, alongside other weather and moon variables.
- [Catchy](https://getcatchy.app/) — records pressure trend as one of multiple conditions associated with the angler's own catches and learns a waterbody-specific pattern from that catch log.
- [CurrentCast](https://krumenja.com/currentcast/) — exposes a time-based score that includes barometric trend among tide direction, water temperature, wind, lunar phase, and solunar periods.

## Findings

1. These sources use pressure as a **signed trend**—falling, stable, or
   rising—at the fishing location and forecast time. They do not use a single
   static pressure value as the fishing signal.
2. They treat that trend as one input among conditions that anglers actually
   use together: water temperature, light/weather, wind, tide/current,
   season, solunar timing, and local catch history.
3. Their usual result is a conditional fishing recommendation, a time-window
   rating, or a tactical change. It is not a claim that the same numerical
   effect applies to every species or waterbody.
4. None of the reviewed sport-fishing sources publishes an equation that
   combines a numeric `pressure_sensitivity` field with separate falling,
   stable, and rising species multipliers. The reviewed apps either keep their
   calculation proprietary or allow angler-specific criteria/catch-log
   calibration.

## Rate-of-change practice

The additional sport-fishing sources below make the time dependence explicit.

- [Tackle fishing barometer](https://tackleapp.ai/tools/fishing-barometer)
  reads the local three-hour trend, treating little change as stable, roughly
  1–3 hPa of movement as gradual, and movement beyond 3 hPa as fast.
- [BitePredict](https://bitepredict.com/barometric-pressure-fishing) scores a
  local three-hour trend and distinguishes gradual from rapid movement when it
  identifies a bite window.
- [Catchy](https://getcatchy.app/) scores a live six-hour trend and gives a
  time-limited bonus when a falling trend follows stability.
- [FishCaster](https://www.fishcasterapp.com/) keeps pressure range and
  rising/falling/steady trend as separate angler-defined conditions rather
  than a permanent species discount.

The sources disagree about whether rising or falling is favorable for a given
fishery. That is why the approved matrix's per-species falling and rising
multipliers, rather than a universal directional bonus, must determine the
direction of the score change.

## Dynamic weighting derivation for the approved matrix

The workbook has 191 complete profiles. All 191 have a stable multiplier of
`1.00`; the researched falling and rising values vary by species, and 53
profiles have sensitivity `0` with neutral directional multipliers. The
following derivation uses those existing inputs and the plan's existing
three-hour stable boundary. It makes the score change continuously as the
forecast pressure trend changes.

Let `delta` be the signed local pressure change in hPa over the three hours
ending at the forecast period. Let `s` be the profile's
`pressure_sensitivity`. Let `m_falling` and `m_rising` be that profile's
directional multipliers.

1. When `abs(delta) < 1`, use the stable pressure factor `1.00`.
2. Otherwise, calculate the trend-rate weight
   `rate_weight = min(1, (abs(delta) - 1) / 2)`.
   This begins at the plan's 1 hPa stability boundary and reaches the profile's
   full directional response at a 3 hPa change over three hours, the upper end
   of the gradual band used by Tackle before its fast-change category.
3. Select `m_falling` when `delta <= -1`; select `m_rising` when
   `delta >= 1`. The pressure factor is then
   `1 + s * rate_weight * (selected_multiplier - 1)`.

This rule has no permanent pressure-sensitivity penalty: a stable trend is
always `1.00`, and sensitivity `0` is always `1.00`. It reaches the
researched species-specific directional response only when the measured rate
is large enough; values in between change smoothly with time.

### Worked dynamic examples from the black sea bass profile

The completed black sea bass row has `s = 0.75`, falling multiplier `1.10`,
and rising multiplier `0.75`.

| Three-hour change | Rate weight | Pressure factor | Calculation |
|---|---:|---:|---|
| `0.5 hPa` | n/a | `1.00000` | stable under the plan's `1 hPa` boundary |
| `-2 hPa` | `0.50` | `1.03750` | `1 + 0.75 × 0.50 × (1.10 − 1)` |
| `-3 hPa` | `1.00` | `1.07500` | `1 + 0.75 × 1.00 × (1.10 − 1)` |
| `+2 hPa` | `0.50` | `0.90625` | `1 + 0.75 × 0.50 × (0.75 − 1)` |
| `+3 hPa` | `1.00` | `0.81250` | `1 + 0.75 × 1.00 × (0.75 − 1)` |

This is the research-derived dynamic weighting rule for the Phase 2
known-answer cases. It has not changed runtime code or the approved plan.
