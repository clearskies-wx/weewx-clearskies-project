# Brief: Forecast Correction Dual-Path Inconsistency

**Date:** 2026-07-06  
**Severity:** Medium — visible user-facing discrepancy  
**Discovered during:** Phase 9 QA of TEXT-ENGINE-PLAN (GFE text engine)

---

## Problem

The forecast correction engine (ADR-079) corrects hourly `outTemp` and daily `tempMax`/`tempMin` via two independent code paths that produce divergent results for the same forecast day.

**Observed:** Tomorrow's forecast (2026-07-07) from Xweather:
- Raw provider daily `maxTempF` = 71°F
- Raw provider hourly peak = 71°F at 1 PM (consistent at the provider level)
- After correction: daily `tempMax` = 72.8°F (+1.8°F), hourly peak = 77°F (+6°F)
- 7-day card shows 73°F, GFE text says "Highs in the upper 70s" — 4°F gap

**Root cause:** `correct_bundle()` in `correction/corrector.py` runs two different prediction paths:

1. **Hourly path (line 239-253):** For each `HourlyForecastPoint`, extracts all 7 features from the point itself (month, hour, fcst_temp, wind_dir, humidity, cloud_cover, wind_speed) and predicts bias. Uses the actual per-point weather features.

2. **Daily path (line 255-269):** For `tempMax`, predicts bias at hardcoded hour=14 (assumed afternoon high timing). For `tempMin`, hour=5 (assumed morning low). Uses **stored median values** for the 4 nullable weather features (wind_dir, humidity, cloud_cover, wind_speed) because daily points don't carry per-hour values.

Different inputs → different predicted bias → the two paths diverge. The Random Forest model is sensitive to the weather features, so median substitution produces a materially different prediction than actual values.

## Evidence

**Historical bias (July afternoons, 300 samples):**
- Hour 12: +2.47°F average
- Hour 13: +2.27°F
- Hour 14: +2.11°F
- Hour 15: +1.30°F
- Hour 16: +0.40°F

**Model metadata:** 5,932 training pairs, MAE raw=1.55°F, MAE corrected=0.44°F. The model performs well on the training set, but the dual-path application creates inconsistency that doesn't exist in the training/evaluation data (which only covers hourly pairs).

**Yesterday's actual observed bias (Jul 5, afternoon):** Ranged from -1.7 to +4.4°F, with most hours under +1°F. The +6°F correction the model applies to tomorrow's hourly points is 3-4x the historical average for that time slot.

## Impact

- 7-day forecast card shows one temperature, GFE text says another
- The discrepancy is visible to site visitors — undermines trust in the forecast
- The hourly correction may itself be too aggressive for certain feature combinations (the +6°F prediction exceeds the historical average bias of +2°F for July afternoons)

## Options to investigate

**A. Recompute daily from corrected hourly (simplest):** After correcting hourly points, recompute `tempMax = max(corrected hourly outTemp for daytime hours)` and `tempMin = min(corrected hourly outTemp for nighttime hours)`. Eliminates the dual-path entirely. Daily correction code becomes dead. Risk: if the hourly correction is itself wrong (as the +6°F case suggests), the error propagates to the daily display too.

**B. Use only the daily correction path:** Drop hourly correction entirely. Correct only `tempMax`/`tempMin` on daily points. The hourly data stays raw. Risk: the GFE text engine aggregates from hourly data, so text and card would still disagree unless the text engine reads the corrected daily values instead.

**C. Unify the feature vectors:** Instead of median substitution for daily points, look up the actual hourly point closest to the assumed peak hour and use its features. This makes the daily prediction use the same inputs as the corresponding hourly prediction. Requires the hourly data to be available when daily correction runs (it is — `correct_bundle` has the full bundle).

**D. Investigate model overcorrection:** The +6°F prediction for a +2°F-average bias suggests the model may be overfitting to certain feature combinations or the feature space has regions with sparse training data. Audit the model's predictions vs actual outcomes for July afternoons specifically. May need regularization, feature engineering changes, or a simpler model for the tail cases.

**E. Hybrid (recommended investigation path):** Option C (unify features so daily and hourly agree) + Option D (audit why the model predicts +6°F when the average is +2°F). C fixes the consistency problem; D fixes the accuracy problem.

## Scope

This brief covers the correction engine only. The GFE text engine, the 7-day card rendering, and the provider data are all working correctly — they just disagree because they read different corrected values.

## References

- ADR-079: Forecast correction engine
- `weewx_clearskies_api/correction/corrector.py` lines 215-270
- `weewx_clearskies_api/correction/trainer.py` (model training)
- `/etc/weewx-clearskies/forecast_correction.db` (training pairs)
- `/etc/weewx-clearskies/forecast_correction_model.pkl` (trained model)
