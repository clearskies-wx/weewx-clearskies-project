---
status: Accepted
date: 2026-06-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-079: Forecast Correction Engine

## Context

Aeris Xcast and other ML-based forecast models exhibit a systematic 2–4°F cold bias, particularly in afternoon hours. NWP models trained on historical reanalyses fail to account for ongoing climate warming. Local factors (marine layer, land/sea breeze, urban heat, valley drainage) amplify the effect. The operator observed this consistently over multiple weeks at the Huntington Beach station.

This ADR adds a provider-agnostic forecast temperature correction engine to the Clear Skies API using Model Output Statistics (MOS) methodology: collect forecast-vs-observation pairs, train a Random Forest to learn the station's bias pattern, apply corrections in-flight before serving forecast responses.

## Options considered

| Option | Verdict |
|---|---|
| A: Static lookup table (hour×month bias) | Exclude — too crude, can't adapt to weather regime, no continuous learning |
| B: Linear regression | Exclude — bias is non-linear across features (hour, wind dir, cloud cover) |
| C: Random Forest (scikit-learn) | **Chosen** — handles non-linear interactions, proven in MOS, <5ms inference, <3s training, no GPU |
| D: Gradient boosting (XGBoost/LightGBM) | Exclude — marginal accuracy gain, heavier dependency; RF sufficient for station-level correction |
| E: No correction (status quo) | Exclude — consistent 2–4°F cold bias degrades operator trust in forecast data |

## Decision

Add a Random Forest-based forecast correction engine. It collects forecast-observation pairs into a separate SQLite database, trains on the bias pattern (`target = actual_temp − forecast_temp`), and applies corrections to hourly forecast temperatures in-flight (after cache, before response). scikit-learn is a required dependency.

**Locked sub-decisions:**

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | SQLite for correction data | No new DB users/grants; self-contained; within `/etc/weewx-clearskies/` write allowlist |
| D2 | scikit-learn required dependency | Do it right; no fallback lookup table; <5ms inference, <3s training |
| D3 | All features forecast-side | Standard MOS — no observations exist for future hours at prediction time |
| D4 | Predict bias, not absolute temp | `corrected = forecast + predicted_bias`; more stable, interpretable, degrades gracefully |
| D5 | Correction after cache, before response | Raw provider data stays in cache; model updates take effect immediately |
| D6 | Provider-agnostic | Logs `provider_id` per pair; trains on all data regardless of provider |
| D7 | Temperature only (hourly) | Daily high/low have different bias characteristics — future extension |
| D8 | Serve corrected only (operator toggle) | No dual display; operator can enable/disable correction and collection independently |
| D9 | Rolling 3-year data retention | Eliminates ancient climate drift; optimizes training size |
| D10 | TruScore metrics | Provider Score: `100 − MAE_raw`. Correction Score: `max(0, (MAE_raw − MAE_corrected) / MAE_raw × 100)` |

## Consequences

- New `correction/` package in API repo (~7 files, ~780 lines est.)
- scikit-learn added as required dependency (~30 MB installed)
- Separate SQLite DB at `/etc/weewx-clearskies/forecast_correction.db`
- Model `.pkl` at `/etc/weewx-clearskies/forecast_correction_model.pkl`
- Background threads: collector (per archive_interval) + retrainer (weekly/daily/manual schedule)
- 3 new `/setup/forecast-correction/*` admin endpoints (status, toggle, retrain)
- Temperature only for v1; daily high/low and other meteorological variables are future scope
- No dashboard changes — correction is transparent to the client
- 7 features: month, hour, fcst_temp, fcst_wind_dir, fcst_humidity, fcst_cloud_cover, fcst_wind_speed

## Acceptance criteria

- [ ] Forecast-observation pairs logged to separate SQLite; weewx archive DB never written to by the API
- [ ] Trained RandomForestRegressor corrects hourly forecast temperatures before serving responses
- [ ] Correction is provider-agnostic (works with any configured forecast provider)
- [ ] Operator can independently enable/disable data collection and forecast correction via `api.conf` and admin endpoints
- [ ] TruScore metrics computed during training and accessible via admin endpoint
- [ ] Rolling 3-year data retention enforced during each training run
- [ ] Model training triggerable on-demand via `POST /setup/forecast-correction/retrain`
- [ ] When model unavailable or correction disabled, raw forecasts pass through unchanged
- [ ] API startup does not fail when `[forecast_correction]` section absent from `api.conf`
- [ ] All new code respects `rules/coding.md` §1 security constraints

## Implementation guidance

- **Package:** `weewx_clearskies_api/correction/` — `db.py`, `models.py`, `collector.py`, `trainer.py`, `corrector.py`, `retrainer.py`
- **Settings:** `ForecastCorrectionSettings` in `config/settings.py` after `ForecastSettings`
- **Startup:** Step 6m½ in `__main__.py` after forecast settings wiring
- **Correction point:** 3–5 lines in `endpoints/forecast.py` after sunrise/sunset injection, before slice
- **Admin endpoints:** 3 routes on `endpoints/setup.py` router using `require_setup_active` auth
- **Config:** `[forecast_correction]` section in `api.conf` with keys: `enabled`, `collection_enabled`, `retrain_schedule`, `retrain_day`, `min_samples`, `retention_years`, `db_path`, `model_path`
- **Files:** Both DB and model in `/etc/weewx-clearskies/` (within write allowlist — no `coding.md` amendment)
- **Serialization:** `joblib.dump()` (part of scikit-learn); atomic write via temp file + `os.rename()`
- **Out of scope:** Daily high/low correction, other meteorological variables, dashboard UI changes

## References

- Execution plan: `docs/planning/FORECAST-CORRECTION-PLAN.md`
- Related: ADR-007 (forecast providers), ADR-017 (caching), ADR-038 (setup endpoints)
