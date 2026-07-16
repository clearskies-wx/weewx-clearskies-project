# Tide Forecast Accuracy Brief

**Date:** 2026-07-13
**Status:** Research complete — Phase 4 redrafted to implementation
**Origin:** MARINE-CARD-DATA-SOURCE-PLAN.md Phase 4, which identified five research questions about OFS water levels vs CO-OPS tide predictions

---

## Problem

The marine dashboard currently displays CO-OPS harmonic tide predictions — the astronomical tide curve (high/low times and heights) from the nearest CO-OPS gauge station. This is accurate for what it models, but it only models the moon and sun's gravitational pull. It does not include:

- **Storm surge** — wind-driven water piled against the coast
- **Atmospheric pressure effects** — low pressure raises water, high pressure lowers it (inverse barometer effect, ~1 cm per millibar)
- **Wind setup** — sustained onshore wind pushes water higher than the tide table says
- **River discharge** — Santa Ana River outflow raises local water levels
- **Seiches and other oscillations** — harbor resonance, edge waves

The result: visitors see a tide chart that says "high tide 5.2 ft at 3:15 PM" but the actual water level could be 5.8 ft due to onshore wind and low pressure, or 4.6 ft due to strong offshore Santa Ana winds. The tide table is accurate for astronomy but incomplete for what actually happens at the beach.

Additionally, all 7 Huntington Beach marine locations show identical tide predictions because they all reference the same CO-OPS station (9410580 Newport Beach, ~8 miles away). The astronomical tide doesn't meaningfully differ over this distance on an open coast, but the total water level could — a location near the Santa Ana River mouth sees different water levels than one 2 miles down the coast.

---

## Research Questions — Answered

These are the five questions from Phase 4 of the plan, answered with findings.

### Q1: How does OFS zetatomllw compare to CO-OPS harmonic predictions over a 72-hour window?

**They measure different things — comparison is the point, not a problem.**

CO-OPS harmonic predictions model the **astronomical tide only** — the predictable, periodic component of water level driven by celestial mechanics. NOAA uses 37 harmonic constituents computed from historical observations. On calm days with no significant weather, CO-OPS predictions agree with observed water levels within **2-5 cm (1-2 inches) in height and 1-3 minutes in timing** (NOAA Tides & Currents documentation). This accuracy is excellent and is the result of decades of harmonic analysis at each reference station.

OFS `zetatomllw` (and `zeta`) models the **total water level** — astronomical tide plus all meteorological and oceanographic forcing. This includes storm surge, wind setup, atmospheric pressure response, river discharge, and density-driven flows. The NOS accepted RMSE criterion for OFS water level is **0.15m (~6 inches)** — considerably less accurate than CO-OPS for the pure tidal component, but OFS captures effects that CO-OPS predictions cannot.

**The difference between OFS total water level and CO-OPS harmonic prediction IS the non-tidal residual** — the meteorological signal. This is the most valuable data product we can extract:

```
Non-tidal residual = OFS total water level − CO-OPS harmonic prediction
```

On a calm day, this residual is near zero (OFS and CO-OPS agree). During weather events, the residual can be significant:

| Condition | Typical residual (SoCal open coast) |
|---|---|
| Calm, fair weather | -0.05 to +0.10 ft |
| Moderate onshore wind (15-20 kt) | +0.2 to +0.5 ft |
| Strong Santa Ana offshore wind | -0.2 to -0.5 ft |
| Winter storm / low pressure | +0.3 to +0.8 ft |
| Major El Nino event | +0.5 to +1.5 ft |
| King tide + storm (worst case) | +1.0 to +2.5 ft |

**Conclusion:** Don't compare OFS and CO-OPS as competing tide sources — use CO-OPS for the tidal component (where it's superior) and extract the OFS residual for the meteorological component (which CO-OPS cannot provide).

### Q2: Does OFS produce meaningfully different water levels for two locations 1.9km apart?

**Not at current resolution — and it doesn't matter for tides.**

WCOFS operates at ~4km resolution. Two locations 1.9km apart (Huntington Beach Pier and Huntington State Beach) likely map to the same WCOFS grid point, or at most to adjacent grid points. At 4km spacing, the model cannot resolve hyper-local differences in water level caused by:

- Pier/jetty structures channeling water
- Santa Ana River discharge plume
- Local bathymetric effects on wave setup

More fundamentally, **astronomical tides don't meaningfully differ over 1.9km on an open coast.** The tidal wave on the California coast travels at ~200 m/s (shallow water wave speed in ~20m depth). Over 1.9km, the phase difference is ~10 seconds — completely negligible. The tidal range and timing are effectively identical.

**What CAN differ between nearby locations:** total water level during weather events, due to local wind exposure, bathymetry, and structure effects. But resolving this requires ~100m model resolution, which no operational OFS provides for the open California coast (SFBOFS achieves 10m resolution inside San Francisco Bay, but that's a semi-enclosed basin).

**Conclusion:** Per-location tide differentiation for locations 1.9km apart on an open coast is neither feasible with current data sources nor physically meaningful for the astronomical component. All locations sharing a CO-OPS reference station will show the same tide curve, and this is correct.

**Design consequence:** Tide data is removed from the marine landing page location cards. Since all 7 locations show identical tide information, it's visual noise — it doesn't help visitors choose between locations. Tide information belongs in the activity detail tabs (boating, fishing, beach safety, surfing) where it provides context for the specific activity.

### Q3: During storm surge or king tide events, how much did OFS zeta deviate from CO-OPS prediction?

**The deviation IS the storm surge signal — it's the valuable information.**

OFS `zeta` (water level vs MSL) during a storm surge event will be significantly higher than the CO-OPS harmonic prediction. This deviation is not model error — it's the model correctly capturing the meteorological forcing that harmonic predictions cannot represent.

For Southern California specifically:

- **Typical tidal range** (MLLW to MHHW) at station 9410580: approximately 5.5 ft (1.67m). This is a mixed semidiurnal tide with two highs and two lows per day of unequal heights.
- **Normal non-tidal residual:** -0.1 to +0.1 ft. SoCal has a mild surge climate compared to the Gulf or Atlantic coast.
- **Storm events:** Southern California rarely experiences dramatic storm surge (unlike the Gulf Coast), but El Nino winters can produce sustained elevated water levels of 0.5-1.5 ft above predictions for weeks. Combined with king tides (highest astronomical tides of the year), this has caused significant coastal flooding in Huntington Beach.
- **OFS accuracy during events:** OFS models generally capture the direction and approximate magnitude of surge events but may under- or over-predict the peak by 0.1-0.3 ft. The NOS 0.15m RMSE criterion applies as the acceptance threshold.

**Conclusion:** The OFS deviation from CO-OPS prediction during events is real meteorological signal. Displaying this residual to visitors ("water expected 0.8 ft above predicted tide") is the highest-value addition to the tide display.

### Q4: Can OFS zetatomllw serve as a per-location tide proxy?

**No. It should supplement, not replace.**

OFS water levels are less accurate than CO-OPS harmonic predictions for the tidal component. The OFS tidal forcing comes from boundary conditions (tidal harmonics at the model's ocean boundary) propagated through the model's physics — this introduces model errors that CO-OPS's direct harmonic analysis at the station location does not have.

| Metric | CO-OPS harmonic prediction | OFS zetatomllw |
|---|---|---|
| Tidal height accuracy | 2-5 cm (calm conditions) | Up to 15 cm RMSE (total water level) |
| Tidal timing accuracy | 1-3 minutes | Model-dependent, typically 10-30 min |
| High/low classification | Yes — labeled with times | No — continuous water level curve |
| Meteorological effects | Not included | Included (surge, wind, pressure) |
| Spatial coverage | Station locations only (~200 US) | Every grid point in model domain |
| Forecast horizon | Unlimited (harmonic) | 48-72 hours (model run) |

**Conclusion:** CO-OPS is the primary tide source. OFS supplements it with the non-tidal residual. This is the same architecture NOAA uses internally — CO-OPS predictions are the baseline; operational models add the surge/weather component.

### Q5: How should OFS water levels be presented alongside CO-OPS predictions?

**As a "total water level" overlay on the tide chart, with the residual called out.**

The dashboard tide chart (currently `TideChart.tsx`) shows the CO-OPS prediction curve. The enhanced display adds:

1. **Total water level forecast line** — CO-OPS prediction + OFS non-tidal residual, plotted as a second trace on the same chart. When OFS data is available, visitors see both "what the tide table says" and "what the water is actually expected to do."

2. **Current observed water level marker** — from CO-OPS `water_level` product (the physical gauge reading at the station). Already fetched by our provider but not prominently displayed on the chart. This dot on the chart shows "where the water actually is right now."

3. **Non-tidal residual indicator** — when the residual exceeds a threshold (±0.15 ft / ±5 cm), display it as a stat: "Water level +0.4 ft above predicted tide." This tells the visitor the weather is pushing water higher (or lower) than the tide table says.

4. **Storm surge alert** — when the residual exceeds a higher threshold (±0.5 ft / ±15 cm), promote to a warning-level indicator. For beach safety, this is safety-critical information.

---

## The Optimal Architecture: Composite Water Level

### Concept

The most accurate water level forecast for a specific location combines two independently produced signals:

```
Total water level = CO-OPS harmonic prediction + non-tidal residual
```

Where the non-tidal residual has two sources depending on temporal position:

- **Past to present:** computed from CO-OPS observations. `residual = observed_water_level - predicted_tide` at the nearest CO-OPS station. This is ground truth — the actual meteorological effect measured by the gauge.

- **Present to +72 hours:** forecast from OFS model. `residual = OFS_total_water_level - OFS_tidal_component`. The OFS tidal component can be approximated by the CO-OPS prediction at the same time, or by running the OFS model's own tidal extraction.

### Why this is better than either source alone

| Approach | Tidal accuracy | Captures surge | 72h forecast |
|---|---|---|---|
| CO-OPS predictions only (current) | Excellent (2-5 cm) | No | Yes (harmonic) |
| OFS total water level only | Moderate (15 cm RMSE) | Yes | Yes (48-72h) |
| **CO-OPS + OFS residual (proposed)** | **Excellent (2-5 cm base)** | **Yes** | **Yes** |
| STOFS-2D-Global CWL | Moderate (varies) | Yes | Yes (180h) |

The composite approach preserves CO-OPS's excellent tidal accuracy while adding the meteorological signal from OFS. Neither source is degraded — they each contribute what they do best.

### Current-state residual from CO-OPS observations

Our tides provider already fetches both `predictions` and `water_level` from CO-OPS for the same station (confirmed in `providers/tides/coops.py`). The observed water level includes all real-world effects. The predicted water level is pure harmonics. The difference is the observed non-tidal residual:

```python
residual_now = observed_water_level - predicted_tide_at_same_time
```

This requires interpolating the 6-minute prediction series to match observation timestamps, or vice versa. Both are available at 6-minute intervals from CO-OPS.

The observed residual tells us: "right now, the water is 0.3 ft higher than the tide table predicted, because of weather."

### Forecast residual from OFS

For the forecast period (beyond the last observation), we use the OFS model to estimate the future residual:

```python
forecast_residual_t = OFS_zeta_t - COOPS_prediction_t
```

Where `OFS_zeta_t` is the OFS total water level forecast at time `t`, and `COOPS_prediction_t` is the CO-OPS harmonic prediction at the same time. The subtraction removes most of the OFS tidal bias (because the tidal errors in OFS tend to be systematic — a consistent phase or amplitude offset that cancels when you subtract the CO-OPS prediction).

**Persistence fallback:** When OFS forecast data is unavailable (model outage, location outside OFS domain), the simplest fallback is persisting the most recent observed residual with exponential decay — assuming the current meteorological effect fades toward zero over 24 hours. This is a standard operational approach (NOAA's monthly high tide flooding outlook uses "damped persistence of current gauge station monthly non-tidal residual anomalies").

### Data flow

```
CO-OPS station (e.g., 9410580 Newport Beach)
  ├── predictions (harmonic, 72h) ─────────────────┐
  │     TTL: 6h (doesn't change often)             │
  └── water_level (observed, 24h) ──┐               │
        TTL: 10min (real-time gauge) │               │
                                     │               │
  Compute observed residual:         │               │
  residual = water_level - prediction│               │
  at matching timestamps             │               │
                                     ▼               ▼
OFS model (e.g., WCOFS)          ┌──────────────────────────────┐
  └── zeta/zetatomllw (72h) ──► │  Composite Water Level        │
        TTL: 30min               │                              │
                                 │  Past-to-now: prediction +   │
  Compute forecast residual:     │    observed residual          │
  forecast_res = OFS - prediction│                              │
  for each forecast hour         │  Now-to-72h: prediction +    │
                                 │    OFS forecast residual      │
                                 │                              │
                                 │  Fallback: prediction +      │
                                 │    decayed last residual      │
                                 └──────────────────────────────┘
                                           │
                                           ▼
                                 Dashboard tide chart:
                                 - Predicted tide curve (primary)
                                 - Total water level curve (overlay)
                                 - Observed marker (current dot)
                                 - Residual indicator (stat tile)
```

---

## CO-OPS Station Coverage for Our Locations

All 7 configured Huntington Beach marine locations use the same nearest CO-OPS station:

| CO-OPS Station | ID | Distance from HB Pier | Type | Products |
|---|---|---|---|---|
| Newport Beach | 9410580 | ~8.2 mi south | Reference (harmonic) | Predictions + water level + water temp |
| Los Angeles | 9410660 | ~25 mi NW | Reference (harmonic) | Predictions + water level + water temp |
| La Jolla | 9410230 | ~65 mi SE | Reference (harmonic) | Predictions + water level + water temp |

Station 9410580 (Newport Beach) is the nearest and currently used by our tides provider. It is a **reference station** with full harmonic constants — not a subordinate station — meaning its predictions are computed directly from 37 harmonics, not corrected from another station. This gives us the best possible harmonic prediction accuracy.

### Subordinate station methodology — not applicable to us

CO-OPS subordinate stations compute predictions by applying time and height corrections to a reference station. This is useful when a location is in a bay, inlet, or other environment where tides differ significantly from the reference. For open coast locations like Huntington Beach, the astronomical tide is well-represented by the nearest reference station (Newport Beach). Computing subordinate corrections would require collecting actual observation data at each beach location — we don't have gauges there, so this approach is not feasible.

---

## What STOFS-2D-Global Offers (and Why We Don't Need It Separately)

NOAA's STOFS-2D-Global (Surge and Tide Operational Forecast System, formerly Global ESTOFS) is an ADCIRC-based global model that produces three separate water level products:

| Product | Code | What it contains |
|---|---|---|
| Harmonic Tide Prediction | HTP | Astronomical tide only (from model tidal forcing) |
| Sub-tidal Water Level | SWL | Storm surge / meteorological only (no tide) |
| Combined Water Level | CWL | HTP + SWL = total water level |

This decomposition is exactly what we need — a separated tidal and surge component. However:

- **We already have a better tidal component** — CO-OPS harmonic predictions at a reference station are more accurate than STOFS's model-derived HTP.
- **OFS (WCOFS) is higher resolution** than STOFS-2D-Global for the California coast. WCOFS at ~4km resolves coastal processes better than STOFS's global unstructured grid.
- **The OFS non-tidal residual is equivalent to STOFS SWL** for our purposes — both capture the same meteorological signal.

**Decision:** Use OFS (WCOFS) for the forecast residual, not STOFS-2D-Global. OFS is already being integrated in Phase 3 for temperature/currents/salinity — the water level data comes from the same files at zero additional cost. Adding STOFS as a separate data source would introduce a new provider for no accuracy gain.

If the location is outside OFS coverage (and therefore outside WCOFS), the global fallback for water level is STOFS-2D-Global's SWL product. This provides surge forecast coverage everywhere OFS doesn't reach — same fallback principle as RTOFS for temperature.

---

## Dashboard Display Design

### Tide chart enhancements

The existing `TideChart.tsx` (243 lines, Recharts `ComposedChart` with Area + Line + Scatter) currently shows:
- 72-hour CO-OPS prediction curve (Area)
- High/low markers (Scatter)

Enhanced chart adds:

1. **Total water level forecast line** (Line, dashed, `--chart-2` color): CO-OPS prediction + forecast residual. Only rendered when OFS residual data is available. When residual is near zero (<0.05 ft), this line overlaps the prediction curve — visually confirming "weather isn't affecting the tide."

2. **Observed water level line** (Line, solid, `--chart-3` color, thicker): actual gauge readings for the past 24 hours. Already fetched but currently not plotted on the chart. This shows visitors "where the water actually was."

3. **Current water level dot** (Scatter, single point, accent color): the most recent observation, prominently marked on the chart with a vertical "now" line.

4. **Residual fill** (Area between prediction and total water level): when the forecast total water level diverges from the prediction, the gap between the curves is filled — green-tinted above (water higher than predicted), red-tinted below (water lower). This visually communicates "the weather is pushing water up/down."

### Residual stat tile

In the conditions panel (alongside tide height, next high/low):

```
Water Level Offset: +0.4 ft
(above predicted tide — onshore wind)
```

Or when calm:
```
Water Level Offset: +0.0 ft
(conditions match tide prediction)
```

### Storm surge indicator

When residual exceeds thresholds:

| Residual | Display | Color |
|---|---|---|
| < ±0.15 ft | No indicator (normal) | — |
| ±0.15 to ±0.5 ft | "Water level elevated/depressed" | Yellow/caution |
| > ±0.5 ft | "Significant water level offset" | Orange/warning |
| > ±1.0 ft | "Storm surge detected" | Red/danger |

These thresholds are SoCal-specific. Gulf Coast or East Coast locations would need different thresholds — the system should make them configurable per location (or derive from the location's typical tidal range).

---

## Implementation Design

### New service: Water Level Compositor

New file: `services/water_level_compositor.py`

This is a service-layer component (like `ocean_data_resolver.py`), not a provider module. It orchestrates data from CO-OPS predictions, CO-OPS observations, and OFS water levels to produce the composite forecast.

```python
class CompositeWaterLevel:
    # Astronomical tide (from CO-OPS)
    predictions: list[TidePrediction]       # 72h harmonic prediction curve
    next_high: TidePrediction | None        # next high tide
    next_low: TidePrediction | None         # next low tide

    # Observed (from CO-OPS gauge)
    observations: list[WaterLevel]          # 24h observed water levels
    current_water_level: float | None       # most recent gauge reading
    current_residual: float | None          # observed - predicted at current time

    # Total water level forecast (composite)
    total_water_level_forecast: list[dict] | None  # [{"time": iso, "height": ft, "residual": ft}, ...]
    residual_source: str                    # "observed", "ofs:WCOFS", "persistence", "unavailable"
    residual_quality: str                   # "measured", "modeled", "decayed", "none"

    # Metadata
    station_id: str                         # CO-OPS station used
    station_name: str
    station_distance_mi: float              # distance from marine location to station
    ofs_model: str | None                   # OFS model providing forecast residual
```

### Compositor algorithm

```python
def compute_composite(
    predictions: list[TidePrediction],      # CO-OPS 72h
    observations: list[WaterLevel],         # CO-OPS 24h
    ofs_water_levels: list[dict] | None,    # OFS zeta, 72h forecast
    now: datetime,
) -> CompositeWaterLevel:

    # Step 1: Compute observed residuals (past 24h)
    # Interpolate predictions to observation times
    # residual[i] = observation[i].height - interpolated_prediction[i]

    # Step 2: Current residual = most recent observed residual
    # This is ground truth — the actual meteorological effect right now

    # Step 3: Forecast residuals (now to +72h)
    if ofs_water_levels:
        # OFS residual = OFS total - CO-OPS prediction at matching times
        # Bias-correct: shift OFS residuals so the OFS residual at "now"
        # matches the observed residual at "now" (removes systematic bias)
        bias = current_observed_residual - ofs_residual_at_now
        forecast_residuals = [ofs_res + bias for ofs_res in ofs_forecast_residuals]
    else:
        # Persistence fallback: decay current residual toward zero
        # decay_factor = exp(-t / tau) where tau = 12 hours
        forecast_residuals = [current_residual * exp(-dt/tau) for dt in forecast_times]

    # Step 4: Total water level = prediction + forecast residual
    total = [pred + res for pred, res in zip(predictions, forecast_residuals)]

    return CompositeWaterLevel(...)
```

The **bias correction** in step 3 is critical. OFS has systematic biases at each location (maybe it always predicts water 3 cm too high near Newport Beach). By anchoring the OFS forecast residual to the observed residual at the current moment, we remove the systematic component and keep only the forecast trend. This is a standard operational technique.

### API changes

**`GET /tides/{locationId}` response additions:**

```json
{
  "data": {
    "predictions": [...],
    "waterLevels": [...],
    "totalWaterLevelForecast": [
      {"time": "2026-07-13T18:00:00Z", "height": 5.8, "residual": 0.4},
      {"time": "2026-07-13T19:00:00Z", "height": 5.3, "residual": 0.3}
    ],
    "currentResidual": {
      "value": 0.4,
      "quality": "measured",
      "source": "observed:coops:9410580",
      "description": "Water level 0.4 ft above predicted tide"
    },
    "residualForecastSource": "ofs:WCOFS",
    "stormSurgeLevel": "elevated"
  }
}
```

New fields are all nullable — when OFS is unavailable or the location is outside OFS coverage, these fields are null and the dashboard shows only the CO-OPS prediction curve (current behavior, no regression).

**Note:** `currentTide` was removed from the `GET /marine` card summary (see Q2 design consequence). Composite water level data surfaces only in the activity detail tabs via `GET /tides/{locationId}`.

### OFS water level extraction

OFS water level data comes from the same `regulargrid` files already opened for temperature in Phase 3. The variables `zeta` and `zetatomllw` are 2D (time, ny, nx) — no depth dimension. Extracting them from an already-open dataset is a single additional `.isel()` call per forecast hour.

In `providers/ocean/ofs.py`, the `fetch()` function already extracts `temp`, `salt`, `u_eastward`, `v_northward` at the nearest grid point. Adding `zeta` and `zetatomllw` extraction is trivial — same grid point, same file, two additional float values per time step.

In `services/ocean_data_resolver.py`, the `OceanDataResult` already includes `water_level_msl` and `water_level_mllw` fields. These flow through to the compositor.

### Cache warmer integration

The water level compositor runs during the cache warmer's marine warm cycle:

1. CO-OPS predictions: already fetched and cached (6h TTL)
2. CO-OPS observations: already fetched and cached (10min TTL)
3. OFS water levels: extracted alongside temperature from the same OFS files (30min TTL)
4. Composite computation: runs after all three are cached, result cached (10min TTL — matches observation refresh)

No additional outbound API calls. No additional provider modules. The data is already flowing through the system — we just need the compositor to combine it.

---

## What This Plan Does NOT Cover

- **Per-location tide differentiation for nearby open-coast locations.** Not physically meaningful and not feasible without local observation data. All locations sharing a CO-OPS station see the same tide curve.
- **Wave-induced water level setup.** Waves breaking on a beach raise the mean water level by 10-30% of the wave height (wave setup). This is a real effect but is not captured by either CO-OPS predictions or OFS water levels (OFS does not model wave-driven setup). A future enhancement could estimate wave setup from NWPS wave height data, but that's separate from the tide prediction problem.
- **Tidal current predictions.** CO-OPS has current prediction stations, but these are at channel/harbor locations, not open beaches. Not in scope.
- **Long-range water level forecasting (>72h).** STOFS-2D-Global provides 180-hour forecasts, but the accuracy degrades significantly beyond 72 hours and CO-OPS predictions don't need a model for the tidal component. Not in scope.
- **Flooding/inundation assessment.** NOAA's Inundation Dashboard provides flood threshold exceedance data. We display water levels; we don't assess flood risk.

---

## Impact on MARINE-CARD-DATA-SOURCE-PLAN.md

### Phase 4 redraft: Research → Implementation

Phase 4 changes from "research only — no code" to an implementation phase:

**New Phase 4 tasks:**

1. **T4.1 — Create water level compositor service** (`services/water_level_compositor.py`): Implements the composite algorithm (observed residual computation, OFS forecast residual extraction with bias correction, persistence fallback, total water level forecast assembly). Depends on Phase 3 (ocean data resolver provides OFS water levels).

2. **T4.2 — Wire compositor into tides endpoint + cache warmer** (`endpoints/tides.py`, `services/cache_warmer.py`): After existing CO-OPS data fetch, call the compositor. Add `totalWaterLevelForecast`, `currentResidual`, `stormSurgeLevel` to `TideBundle` response. Cache the composite result at 10min TTL (matches CO-OPS observation refresh). Nullable — no regression when OFS unavailable.

3. ~~**T4.3**~~ — Removed. `currentTide` removed from location cards (identical across all locations sharing a CO-OPS station — visual noise per Q2). Composite water level data surfaces in activity detail tabs only.

4. **T4.4 — Enhance TideChart with total water level overlay** (`src/components/marine/tabs/shared/TideChart.tsx`): Add total water level forecast line (dashed), observed water level trace (solid), current marker, and residual fill between curves. Conditionally rendered when data available.

5. **T4.5 — Add residual stat tile to tab conditions panels**: In BoatingTab and BeachSafetyTab, show "Water Level Offset" stat with residual value and storm surge level indicator. Self-hides when residual data unavailable.

6. **T4.6 — Update PROVIDER-MANUAL and API-MANUAL**: Document the compositor service, the composite water level algorithm, the residual computation, the bias correction technique, the OFS water level extraction, and the new response fields.

### Dependency chain

Phase 4 depends on Phase 3 (OFS provider + ocean data resolver must exist to provide OFS water levels). Phase 4 does NOT depend on STOFS-2D-Global — it uses OFS data from the same files already opened for temperature.

### QC Gate 4

- Compositor returns non-null `currentResidual` when CO-OPS observations are available
- Compositor returns non-null `totalWaterLevelForecast` when OFS water levels are available
- Bias correction anchors forecast residual to observed residual at current time
- Persistence fallback produces decaying residual when OFS unavailable
- Cache warmer runs compositor after CO-OPS + OFS warm calls; composite cached at 10min TTL
- `GET /tides/{id}` response includes new fields when data available
- `GET /tides/{id}` response is unchanged (no regression) when OFS unavailable
- Tide chart renders total water level overlay when data available
- Tide chart renders prediction-only (current behavior) when overlay data unavailable
- Storm surge indicator appears at correct thresholds
- All existing tests pass unchanged

---

## Sources

- [NOAA CO-OPS About Harmonic Constituents](https://tidesandcurrents.noaa.gov/about_harmonic_constituents.html) — 37 harmonic constituents, prediction methodology
- [NOAA Tide Prediction Accuracy](https://tidecheck.com/verified) — 2-5 cm accuracy on calm days, 1-3 minutes timing
- [NOAA CO-OPS API Documentation](https://api.tidesandcurrents.noaa.gov/api/prod/) — predictions + water_level products, datums, intervals
- [NOAA CO-OPS Products](https://tidesandcurrents.noaa.gov/products.html) — available data products per station
- [WCOFS Technical Report NOS CO-OPS 097](https://tidesandcurrents.noaa.gov/publications/CO-OPS_Techrpt_097_WCOFS-508.pdf) — WCOFS validation and skill assessment
- [Global ESTOFS / STOFS Skill Assessment](https://repository.library.noaa.gov/view/noaa/52091) — OFS water level skill comparison, 0.15m RMSE criterion
- [NOAA OFS Skill Assessment Code](https://github.com/NOAA-CO-OPS/Next-Gen-NOS-OFS-Skill-Assessment) — validation methodology, metrics definitions
- [STOFS-2D-Global v2](https://repository.library.noaa.gov/view/noaa/72262) — surge + tide decomposition (HTP/SWL/CWL)
- [NOAA Coastal Inundation Dashboard](https://tidesandcurrents.noaa.gov/inundationdb_info.html) — operational total water level display approach
- [NOAA Tidal Analysis and Prediction](https://tidesandcurrents.noaa.gov/publications/Tidal_Analysis_and_Predictions.pdf) — comprehensive tidal analysis methodology
- [NOAA Tides & Currents FAQ](https://tidesandcurrents.noaa.gov/faq.html) — subordinate station methodology
