---
status: Accepted
date: 2026-07-16
deciders: shane
supersedes:
superseded-by:
---

# ADR-094: HRRR forecast wind as surf quality scoring source for TruShore forecasts

## Context

The current surf quality scorer wind precedence (ADR-084, API-MANUAL §17) is: station hardware → forecast provider. This is correct for a current-conditions snapshot — the wind AT THE BEACH determines wave face quality. But for a 72-hour surf forecast, station hardware is a real-time observation, not a forecast. The scorer needs wind data for each forecast timestep, not just `t=0`.

With SWAN+TruShore (ADR-093), HRRR forecast wind at 3km resolution is the model forcing wind. The same HRRR run that drove SWAN provides wind at every forecast timestep. Using HRRR wind for forecast scoring is both physically correct (it is the wind field that shaped the waves) and operationally simple (it is already in the TruShore cache).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Station hardware for all timesteps | Consistent with current rule. | Station hardware is a real-time observation — not a forecast. Cannot provide wind for `t+6h` through `t+72h`. |
| Forecast provider (NWS/Aeris) for forecast timesteps | Uses existing provider infrastructure. | Different model than the one that forced SWAN. Introduces a second wind source dependency. |
| HRRR for forecast timesteps (chosen) | Same model that forced SWAN — physically consistent. Already in cache. 3km resolution. Hourly fixed schedule. | New wind provider module required (also needed for SWAN forcing). |

## Decision

For SWAN+TruShore surf forecasts, the wind source for quality scoring is HRRR (the same model run that drove SWAN). Station hardware wind observations remain the source for the current-conditions snapshot (`t=0` scoring) when available.

Wind precedence by timestep:
- **`t=0` (current conditions):** Station hardware → forecast provider → HRRR `t=0` (existing precedence preserved)
- **`t+1h` through `t+72h` (forecast):** HRRR forecast wind from the TruShore cache (the same data that forced SWAN)

## Consequences

- `surf_scorer.py` gains a `wind_source` parameter. When `wind_source == "hrrr_trushore"`, station hardware lookup is bypassed.
- `windSource` field in `SurfForecast` response reflects `"hrrr_trushore"` for forecast timesteps and `"station"` or `"forecast_provider"` for `t=0`.
- Wind quality scores (offshore/cross/onshore classification) now vary across forecast timesteps — a morning sea-breeze pattern produces onshore wind during the day, shifting to offshore at night.
- The NDBC buoy wind exclusion (§17 HARD RULE) is unchanged — NDBC buoy wind is never used for surf quality scoring regardless of source mode.
- **HRRR forecast range limitation (amendment 2026-07-17):** HRRR extended cycles (00/06/12/18Z) reach 48 hours; standard cycles reach only 18 hours. For forecast timesteps beyond HRRR's range (hours 48–72), GFS wind at 0.25° resolution is used as the scoring wind source. The `windSource` field reflects `"gfs_trushore"` for these extended-range timesteps. See research brief §4 "HRRR Forecast Range Limitation."

## Acceptance criteria

- [ ] `windQualityScore` is non-null for all TruShore forecast timesteps
- [ ] `windSource` field reflects `"hrrr_trushore"` for forecast timesteps (`t > 0`)
- [ ] `windSource` field reflects `"station"` or `"forecast_provider"` for `t=0` when available
- [ ] Wind quality varies across forecast timesteps (not identical values)
- [ ] "Glassy" wind quality label applies when HRRR reports winds below 5 mph
- [ ] NDBC buoy wind is never used for surf quality scoring (existing HARD RULE preserved)

## Implementation guidance

- `score_surf()` accepts a `wind_source` parameter. The surf endpoint passes `"hrrr_trushore"` for forecast timesteps and the existing source for `t=0`.
- HRRR wind for a forecast timestep is extracted from the TruShore cache (the wind field used to force SWAN at that timestep's `valid_time`). Interpolated to the surf spot coordinates.
- Wind angle classification (offshore/cross_offshore/cross/cross_onshore/onshore) uses the same formula regardless of wind source — only the U/V values change.

## References

- Related: ADR-093 (SWAN+TruShore replaces NWPS)
- Research: `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` §4
- Existing rule: API-MANUAL §17 "Wind source for surf quality scoring"
