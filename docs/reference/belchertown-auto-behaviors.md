# Belchertown Automatic Chart Behaviors — Gap Analysis

Comprehensive inventory of every built-in behavior Belchertown's code applies automatically when it encounters specific series types or observation names. Each behavior listed here either needs to be replicated in Clear Skies or explicitly documented as excluded.

**Source files analyzed:**
- `docs/snapshots/server-skin-2026-04-29/Belchertown/js/belchertown.js.tmpl` (JavaScript renderer)
- `bin/user/belchertown.py` (Python data generator)

---

## 1. Special Series Types (operator puts these in graphs.conf, system knows what to do)

### weatherRange
**Trigger:** `[[[weatherRange]]]` with `range_type = outTemp` (or any observation)
**Belchertown wiki:** "The weather range will show you a `columnrange` of the observation's min and max for the timespan selected. If you're using `outTemp` as your range observation, the columns will be colored based on the average outTemp."

**Two rendering modes (controlled by config, NOT automatic):**
- Default (no `area_display`): Highcharts `columnrange` — vertical bars per day showing min/max
- `area_display = 1`: Highcharts `arearange` — filled area band between min/max lines
- `polar = true` (optional, NOT default): radial/polar version. Note: area_display does NOT work in polar mode (Highcharts limitation).

**What Belchertown does automatically:**
- Python runs THREE queries: min, max, avg for the `range_type` observation
- Python forces `aggregate_interval = 86400` (daily) if not set
- Output format: `[timestamp_ms, min, max, avg]` per day
- JS auto-scales Y-axis: `tickInterval = Math.ceil(Math.round(max / 5) / 5) * 5`
- JS applies temperature color zones based on unit system (°F or °C) — 15 color bands from blue (cold) to red (hot)
- JS computes per-point color from average temperature via `get_outTemp_color()`
- Tooltip shows high/low/average with color-coded dots
- Legend disabled, markers disabled, borderWidth=0
- **Our status: DONE (2026-06-07)** — WeatherRangeChart rewritten from circular polar SVG to Recharts arearange with 15-band temperature color zones. Renders as Cartesian arearange (default, or when `area_display = 1`) or columnrange. Only goes polar when `polar = true` is explicitly set. Monthly/yearly data flow fixed so groups with both range and regular charts render all charts.

### windRose
**Trigger:** `[[[windRose]]]` with optional beaufort color overrides
**What Belchertown does automatically:**
- Python forces `aggregate_type = None`, `aggregate_interval = None` (raw data)
- Python queries both windDir and windSpeed
- Python bins into 16 compass directions × 7 Beaufort speed groups
- Beaufort thresholds are unit-dependent (different for mph/km/h/m/s/knots)
- Python calculates percentages per direction/speed bin
- JS sets chart type = `column`, polar = true
- JS configures compass direction categories on xAxis (N, NNE, NE, etc.)
- JS positions legend, sets stacking = normal
- Default Beaufort colors: `#7cb5ec, #b2df8a, #f7a35c, #8c6bb1, #dd3497, #e4d354, #268bd2`
- Operator can override colors via `beauford0` through `beauford6` keys
- **Our status: WORKING** — WindRoseChart component handles this correctly on the homepage. Needs verification on monthly/yearly tabs.

### haysChart
**Trigger:** `[[[haysChart]]]`
**Belchertown wiki:** "The Hays Chart is an emulation of the Mount Washington Observatory's wind chart. The hays chart represents the hour of the day in a circle, with the wind speeds wrapping around, indicating the wind speed and time in the circular chart."
**Config options:** `color` (hex), `yAxis_softMax` (soft max for radial scale)

**What Belchertown does automatically:**
- Python queries windSpeed (max) and windGust (max)
- Python auto-calculates aggregate_interval: `(end - start) / 360`, clamped to 300–86400s
- Chart type: `arearange`, `polar = true` (this one IS always polar — it's a circular 24-hour chart by design)
- JS sets connectEnds = false
- Output format: `[timestamp_ms, windSpeed, windGust]`
- **Our status: EXISTS** — HaysChart component exists. Polar rendering IS correct for this chart type (it's supposed to be circular). Verify data flow and visual output.

### aqiChart
**Trigger:** `[[[aqiChart]]]`
**Belchertown wiki:** "The color of the chart changes to match the US-EPA AQI category standards: green for healthy, up through dark maroon for hazardous."
**What Belchertown does automatically:**
- Chart type: `solidgauge`
- Uses only the most recent AQI value
- Auto-colors based on AQI thresholds: green (<51), yellow (51-100), orange (101-150), red (151-200), purple (201-300), maroon (301+)
- Pane: -140° to 140° arc
- Y-axis: 0-500
- The operator HAS this configured and it works in Belchertown
- **Our status: DONE (2026-06-07)** — All archive columns are now served by the `/archive` endpoint without a whitelist gate. The `aqi` column added by weewx extension is queryable directly by its database column name. The "unable to load chart data" error was caused by the API rejecting unmapped columns; this is now fixed (identity mapping for any column not in STOCK_COLUMN_MAP).

### gauge (chart type)
**Trigger:** `type = gauge` in graphs.conf
**What Belchertown does automatically:**
- Converts to `solidgauge`
- Uses only the last (most recent) data point
- Creates background ring (e6e6e6 gray)
- Auto-colors based on configurable thresholds (`color1_position` through `color7_position`)
- Pane: -140° to 140° arc
- dataLabels with 50px bold font showing current value
- **Our status: DEFERRED** — ChartGauge component exists but has not been verified against live data. Deferred: not in the operator's active charts.conf configuration; will be verified when the operator adds a gauge-type chart.

---

## 2. Observation-Specific Automatic Behaviors

### barometer / pressure / altimeter
**JS behavior:** Y-axis labels formatted to 2 decimal places
**Python behavior:** Rounding from weewx StringFormats
**Our status: DONE** — yAxisTickDecimals=2 injected by migration tool

### rain / rainRate / rainTotal
**JS behavior:** Y-axis min=0, minRange=0.01, minor grid lines enabled
**Python behavior:**
- `rainTotal` → queries `rain`, auto-sets `aggregate_type = sum`, applies cumulative sum post-processing
- `rainRate` → auto-sets `aggregate_type = max`
**Our status: PARTIAL** — sumcumulative implemented, yAxis min=0 done, but minRange and minor grid not implemented

### windDir
**JS behavior:** Y-axis tickInterval=90, labels converted to compass (N/NE/E/SE/S/SW/W/NW)
**Python behavior:** Standard query, no special handling
**Our status: DONE** — compass labels implemented

---

## 3. Temperature Color Zones (used by weatherRange)

### Fahrenheit zones (15 bands)
| Threshold | Color |
|-----------|-------|
| ≤0°F | #1278c8 (deep blue) |
| ≤25°F | #30bfef (cyan) |
| ≤32°F | #1fafdd (teal) |
| ≤40°F | rgba(0,172,223,1) (light blue) |
| ≤50°F | #71bc3c (green) |
| ≤55°F | rgba(90,179,41,0.8) (lime) |
| ≤65°F | rgba(131,173,45,1) (yellow-green) |
| ≤70°F | rgba(206,184,98,1) (gold) |
| ≤75°F | rgba(255,174,0,0.9) (orange) |
| ≤80°F | rgba(255,153,0,0.9) (dark orange) |
| ≤85°F | rgba(255,127,0,1) (deep orange) |
| ≤90°F | rgba(255,79,0,0.9) (red-orange) |
| ≤95°F | rgba(255,69,69,1) (red) |
| ≤110°F | rgba(255,104,104,1) (light red) |
| >110°F | rgba(218,113,113,1) (pink-red) |

### Celsius zones (15 bands)
Same visual gradient, thresholds converted: -5, -3.8, 0, 4.4, 10, 12.7, 18.3, 21.1, 23.8, 26.6, 29.4, 32.2, 35, 43.3°C

---

## 4. AQI Color Thresholds
| AQI Range | Color | Category |
|-----------|-------|----------|
| <51 | #71bc3c (green) | Good |
| 51-100 | rgba(255,174,0,0.9) (yellow) | Moderate |
| 101-150 | rgba(255,127,0,1) (orange) | Unhealthy for Sensitive Groups |
| 151-200 | rgba(255,69,69,1) (red) | Unhealthy |
| 201-300 | #b16286 (purple) | Very Unhealthy |
| 301+ | #cc241d (maroon) | Hazardous |

---

## 5. Global Rendering Defaults (plotOptions)

| Chart type | lineWidth | markers | gapSize | threshold |
|-----------|-----------|---------|---------|-----------|
| line/spline | 2 | enabled=false, radius=2 | from config | — |
| area/areaspline | 2 | enabled=false, radius=2 | from config | null (allows negative) |
| scatter | — | radius=2 (enabled) | from config | — |
| column | — | — | — | — |

**Our status: MOSTLY DONE** — markers off, lineWidth=2 implemented. threshold=null for area not implemented.

---

## 6. Multi-Axis Automatic Handling

**Belchertown behavior:** When any series sets `yAxis = 1`:
- Automatically creates right-side Y-axis
- Sets title from that series' `yAxis_label`
- Goes back and sets left axis title from first series' `yAxis_label` if not yet set
- Associates series to correct axis

**Our status: DONE** — ConfigDrivenChart handles dual axes

---

## 7. Data Post-Processing (Python backend)

| Operation | Observation | What it does | Our status |
|-----------|-------------|-------------|------------|
| Cumulative sum | rainTotal | Running total of per-bucket sums | DONE (sumcumulative) |
| Auto aggregate_type | rainTotal | Default to `sum` | DONE (migration tool) |
| Auto aggregate_type | rainRate | Default to `max` | DONE (migration tool) |
| Mirrored values | any (config flag) | Negate values, abs() on axis labels | DEFERRED — not in the operator's current charts.conf; implementation deferred to a future round. |
| Null padding | all | Pad start/end of timespan with nulls | NOT IMPLEMENTED (may not be needed with Recharts) |
| Point timestamp | aggregated data | Midpoint of aggregation period for daily, start for hourly | NOT CHECKED |

---

## 8. Items NOT in graphs.conf That Are Automatic

These behaviors are hardcoded in Belchertown and never configured by the operator:

1. **Temperature color zones** — 15-band gradient applied to weatherRange charts
2. **AQI color thresholds** — 6-tier color coding for AQI gauges
3. **Beaufort wind speed thresholds** — unit-dependent speed bins for wind rose
4. **Compass direction labels** — 16-point compass for windDir Y-axis and wind rose
5. **weatherRange triple query** — automatic min/max/avg from a single `range_type` config
6. **haysChart dual query** — automatic windSpeed/windGust from a single series name
7. **Rain cumulative sum** — automatic running total for rainTotal observation
8. **Barometer 2-decimal formatting** — automatic precision for pressure observations
9. **Rain Y-axis min=0** — rain can't be negative
10. **windDir tickInterval=90** — compass-aligned ticks
11. **Clean Y-axis tick intervals** — `ceil(round(max/5)/5)*5` algorithm for weatherRange
