---
status: Accepted
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-068: Auto-Calibration Baseline System

## Context

Haze detection (ADR-067) compares current Kcs against a "clean-sky baseline" — the Kcs value expected on a clear day with no aerosol loading. This baseline varies by station (altitude, local climate, horizon obstructions) and by season (water vapor column changes). A static threshold cannot work across the ~15,000 weewx stations worldwide.

Ground-based radiation networks (ARM, BSRN, SURFRAD) have solved this problem. Long & Ackerman's clear-sky detection algorithm (`long-ackerman-2000-summary.md`) and its operational descendants (`clear-sky-baseline-methodology.md`) establish that cos(Z) normalization (already done by Kcs = GHI/maxSolarRad) handles the diurnal cycle, no time-of-day binning is needed, and seasonal stratification via rolling windows is standard practice. Renner et al. (2019) used the 85th percentile across 42 BSRN stations; for haze detection (higher bar — exclude routine hazy-clear days), 90th-95th percentile is appropriate.

New operators need a bootstrap path. Historical PM data is available free for most stations: EPA AQS bulk CSV for US (`aqi-historical-data-survey.md`), OpenAQ S3 archive for non-US (141 countries, 2016-present). maxSolarRad can be recomputed for pre-weewx-4.0 records using the Ryan-Stolzenbach formula (`weewx-maxsolarrad-history.md`).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Percentile-based rolling window with bootstrap (chosen) | Validated methodology (ARM/BSRN); adapts to each station; bootstrap enables immediate activation | Requires ~22 clean-sky samples before activation; bootstrap needs operator action for historical PM |
| Mean-based with outlier rejection | Simpler statistics | Sensitive to distribution skew; hazy-but-common days pull the mean down, reducing sensitivity |
| Fixed reference from external climatology (e.g., NSRDB) | No learning period | Station-specific factors (horizon, local albedo) make external references unreliable; would need per-station correction anyway |

## Decision

Percentile-based rolling window. Parameters:

- **Window:** 90-day rolling seasonal window. Seasonal stratification is needed (water vapor column varies); 90-day is seasonal-adjacent without requiring 12x the data.
- **Percentile:** 90th-95th of clean-sky Kcs samples. This is the "clean ceiling" — the expected Kcs when atmosphere is clean. Higher than Renner's 85th (climate research, where hazy-clear is "normal") because we need to detect haze against a cleaner reference.
- **Clean-sample selection:** A sample qualifies as "clean" when: (a) PM2.5 < 12 ug/m3 AND PM10 < 50 ug/m3 (EPA "Good" AQI breakpoints), (b) el > 10° (reliable Kcs), (c) sky classifier returns CLOUDLESS or THIN_CLOUDS, (d) no rain in prior 30 min.
- **Minimum samples:** ~22 clean-sky samples per 90-day window before baseline activates. Scaled from ARM's 110-minute/1-min-data threshold.
- **Fallback:** If sample count drops below 15 (seasonal transition, extended haze), widen to 180-day window. If still insufficient, haze detection is inactive (graceful degradation).
- **Confidence states:** "bootstrapping" (<22 samples), "calibrated" (22-50), "well-calibrated" (>50). Reported in admin UI.
- **No time-of-day bins:** cos(Z) normalization via Kcs handles the diurnal cycle. No reviewed radiation network uses time-of-day stratification.
- **Persistent storage:** Across API restarts. JSON file in `/etc/weewx-clearskies/` or SQLite.

Bootstrap:
- **US stations:** EPA AQS annual CSV (free, hourly PM2.5 parameter code 88101, 1980-present). Recent 6-month gap filled by AirNow hourly obs files.
- **Non-US stations:** OpenAQ S3 archive (free, no credentials, 2016-present, 141 countries).
- **Aeris subscribers:** Historical archive endpoint (January 2024-present, 5x call multiplier).
- **maxSolarRad recomputation:** For records where maxSolarRad is NULL (pre-weewx 4.0), recompute using Ryan-Stolzenbach formula (lat/lon/altitude + timestamp + atc=0.80). Values are computationally identical to what weewx would have stored.

## Consequences

- **New module:** `sse/auto_calibration.py` — sample collection, percentile computation, persistence, confidence reporting.
- **New utility:** maxSolarRad recomputation script (standalone or integrated into bootstrap CLI).
- **Bootstrap import:** CLI command (`clearskies-api bootstrap --pm-source file.csv --format epa-aqs`) and admin UI file upload. Accepts EPA AQS CSV, generic CSV (timestamp + PM2.5 + PM10), OpenAQ format.
- **Admin UI:** Calibration status section — baseline state, clean-day count per window, current percentile value, confidence level.
- **Haze detection dependency:** ADR-067's Kcs deficit comparison requires this baseline. Haze detection is inactive until baseline reaches "calibrated" state.
- **Storage location:** `/etc/weewx-clearskies/calibration.json` (or similar). Survives API upgrades.

## Acceptance criteria

- [ ] Baseline persists across API restarts (read from file on startup, write on new sample)
- [ ] Clean-sample selection correctly rejects: high-PM records, low-elevation records, cloudy records, rainy records
- [ ] 90th-95th percentile computed correctly from accumulated samples
- [ ] 90-day rolling window: samples older than 90 days excluded from current percentile
- [ ] 180-day fallback activates when 90-day window has < 15 samples
- [ ] Haze detection inactive when sample count < 22 (no false positives from uncalibrated baseline)
- [ ] Confidence states correctly reported: bootstrapping/calibrated/well-calibrated
- [ ] EPA AQS CSV import parses correctly (parameter code 88101, hourly timestamps, PM2.5 in ug/m3)
- [ ] maxSolarRad recomputation matches weewx `solar_rad_RS()` for same inputs
- [ ] Admin UI displays calibration status, sample count, confidence level

## Implementation guidance

- **Sample storage format:** Array of `{timestamp, kcs, pm25, pm10, el, window_key}` per 90-day window. `window_key` derived from year + quarter-ish (e.g., "2026-Q2" for Apr-Jun). Rolling means a sample collected June 15 counts toward both "Q2" and "Q3" windows.
- **Percentile computation:** `numpy.percentile` or pure-Python equivalent. Recompute on each new sample addition (cheap — max ~200 samples per window for a station with daily clean-sky opportunities).
- **Bootstrap flow:** (1) Operator uploads or points to historical PM CSV. (2) API validates format, deduplicates by timestamp. (3) Cross-references against weewx archive — for each hour with PM data, check if maxSolarRad and Kcs are available. (4) If maxSolarRad is NULL, recompute from R-S formula. (5) Filter for clean-sample criteria. (6) Accumulate into calibration storage. (7) Report: N samples loaded, N qualified as clean, baseline status.
- **Ryan-Stolzenbach recomputation:** Port from `weewx/wxformulas.py` function `solar_rad_RS()`. Inputs: lat, lon, altitude, timestamp, atc=0.80. Requires `ephem` package for solar position. Deterministic — same inputs always produce same output.
- **Out of scope:** Bootstrap from Aeris historical API (viable but adds API call budget complexity — defer to operator documentation). Real-time provider-to-smoother pipeline (Phase 3, ADR-067 implementation).

## References

- Research: `docs/reference/haze-physics/clear-sky-baseline-methodology.md` — ARM/BSRN methodology, 110-min threshold, no time-of-day bins
- Research: `docs/reference/haze-physics/ryan-stolzenbach-model.md` — R-S formula, atc parameter, low-elevation limitations
- Research: `docs/reference/haze-physics/aqi-historical-data-survey.md` — EPA AQS, OpenAQ, Aeris historical; provider landscape
- Research: `docs/reference/haze-physics/weewx-maxsolarrad-history.md` — weewx 4.0.0+ native archiving, recomputation feasibility
- Related ADRs: ADR-067 (haze detection — consumes baseline), ADR-066 (AQI providers — PM data source)
- Existing code: `weewx/wxformulas.py` `solar_rad_RS()` (R-S reference implementation), `sse/sky_condition.py` (Kcs computation)
