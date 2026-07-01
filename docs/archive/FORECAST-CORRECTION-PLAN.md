# Forecast Correction Engine — Execution Plan

**Status:** Draft — pending user approval
**Date:** 2026-06-28

## Context

Aeris Xcast and other ML-based forecast models exhibit a systematic 2-4°F cold bias, particularly in afternoon hours. This is a broader phenomenon: NWP models trained on historical reanalyses fail to account for ongoing climate warming. Local factors (marine layer, land/sea breeze, urban heat, valley drainage) amplify the effect.

This plan adds a **provider-agnostic forecast temperature correction engine** to the Clear Skies API. It collects forecast-vs-observation pairs, trains a Random Forest model to learn the station's bias pattern, and applies corrections in-flight before serving forecast responses. Designed for **any Clear Skies operator**, not just one location.

**What prompted this:** The user observed consistent 2-4°F cold afternoon forecasts at their Huntington Beach station over multiple weeks of comparing observed vs. forecasted temperatures. The user proposed the concept; the architecture was refined through dialog (2026-06-28).

---

## How this works — four-layer flow

| Layer | Answers | Controls | Lives in |
|-------|---------|----------|----------|
| **1. This plan** | what phases, in what order, with what agents | sequencing & QC gates | `docs/planning/FORECAST-CORRECTION-PLAN.md` |
| **2. ADR-079** | what we decided & why + acceptance criteria | the decision record | `docs/decisions/ADR-079-forecast-correction-engine.md` |
| **3. Manual updates** | prescriptive rules for the feature | API-MANUAL, OPS-MANUAL, ARCHITECTURE | the manuals (updated BEFORE code) |
| **4. Code** | the implementation | — | `weewx-clearskies-api` repo |

**Discipline:** ADR-079 must be **Accepted** and manuals updated BEFORE any code is written. Manuals define what the code should do; code implements what the manuals describe.

---

## Locked decisions (from dialog 2026-06-28)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **SQLite** for correction data storage | weewx operators may use SQLite or MariaDB; SQLite requires no new DB users/grants; self-contained; follows filesystem write allowlist (`/etc/weewx-clearskies/`); easy to back up or delete |
| D2 | **scikit-learn as required dependency** | Do it right; no fallback lookup table; processing cost negligible (<5ms inference, <3s training) |
| D3 | **All model features are forecast-side** | At prediction time, correcting a 7-day forecast — no observations exist for future hours. Standard MOS methodology. |
| D4 | **Predict bias, not absolute temp** | Target = `actual_temp - forecast_temp`. Corrected = `forecast_temp + predicted_bias`. More stable, interpretable, degrades gracefully. |
| D5 | **Correction applied after cache, before response** | Raw provider data stays in cache; model updates take effect immediately; if disabled, raw forecasts flow through untouched |
| D6 | **Provider-agnostic** | Logs `provider_id` per pair; trains on all data regardless of provider; bias patterns are station-local |
| D7 | **Temperature only** (hourly) | Daily high/low have different bias characteristics; future extension. Other meteorological variables too variable for systematic correction. |
| D8 | **Serve corrected only** (with operator toggle) | No dual display. Operator can enable/disable correction and collection independently. |
| D9 | **Rolling 3-year data retention** | Eliminates ancient climate drift; optimizes training size |
| D10 | **TruScore metrics** | Provider Score: `100 - MAE_raw`. Correction Score: `((MAE_raw - MAE_corrected) / MAE_raw) × 100`. Rolling 30-day validation window. |

---

## Feature set (7 features, all from forecast point)

| # | Feature | Source field | Scientific justification |
|---|---------|-------------|--------------------------|
| 1 | `month` (1-12) | forecast `validTime` | Seasonal variation in bias; solar angle, prevailing circulation |
| 2 | `hour` (0-23) | forecast `validTime` | Diurnal bias cycle; radiative balance shifts |
| 3 | `fcst_temp` | forecast `outTemp` | Bias may scale with predicted value; extremes have different bias profiles |
| 4 | `fcst_wind_dir` (degrees) | forecast `windDir` | Offshore vs onshore flow changes thermal regime |
| 5 | `fcst_humidity` (%) | forecast `outHumidity` | Air mass type proxy; affects radiative assumptions |
| 6 | `fcst_cloud_cover` (%) | forecast `cloudCover` | Radiative heating modulator; overcast suppresses warm bias |
| 7 | `fcst_wind_speed` | forecast `windSpeed` | Wind mixing affects local microclimate amplification |

`day_of_year` also stored in DB for future experiments; `month` used for training (RF splits on 12 discrete values = cleaner seasonal bins than 366 DOY values).

---

## Implementation references (verified file:line)

These are the exact integration points in the codebase. Agents reference these; they do not re-discover.

### Startup sequence (`__main__.py`)

| Step | What | Line |
|------|------|------|
| 6h | Wire cache | 836-852 |
| 6h½ | Wire + start cache warmer daemon thread | 854-876 |
| 6i | Wire providers | 891 |
| 6m | Wire forecast settings | 907 |
| 6p | Wire branding (last 6x step) | 919-920 |
| 7 | Register DB probe | 923 |
| 7c | Configure enrichment processors | 969-1049 |

**New step `6m½`** inserts at line 908 (after forecast settings, before radar settings). Pattern: follows cache warmer startup (lines 854-876) — create object, start daemon thread.

### Settings pattern (`config/settings.py`)

| Item | Line |
|------|------|
| `ForecastSettings` class (pattern to follow) | 789-895 |
| `ForecastSettings.__init__()` | 847-880 |
| `ForecastSettings.validate()` | 882-894 |
| `Settings.__init__()` params | 1302-1358 |
| `Settings.validate()` calls | 1360-1378 |
| `load_settings()` section parse block | 1462-1487 |
| `Settings()` constructor call | 1489-1516 |

**New `ForecastCorrectionSettings`** class inserts after line 895 (after `ForecastSettings`). New parse line inserts after line 1487 (after `freshness_cfg`). New param added to `Settings.__init__` at line 1327 and constructor call at line 1515.

### Forecast endpoint (`endpoints/forecast.py`)

| Item | Line |
|------|------|
| Provider dispatch (all 5 providers) | 377-455 |
| Sunrise/sunset injection | 457-464 |
| **CORRECTION INSERT POINT** | **after 464, before 466** |
| Hours/days slice | 466-478 |
| Response construction | 480-489 |

**3-5 lines** added between lines 464 and 466.

### Setup endpoints (`endpoints/setup.py`)

| Item | Line |
|------|------|
| Router definition (`/setup` prefix) | 51 |
| `_check_proxy_auth()` | 59-74 |
| `require_setup_active()` dependency | 77-97 |
| `require_setup_session()` dependency | 100-123 |
| Request/response model pattern | 130+ |

**3 new endpoints** added to the same router, using `require_setup_active` auth dependency.

### Background thread pattern (`services/cache_warmer.py`)

| Item | Line |
|------|------|
| `BackgroundCacheWarmer.__init__()` | 73-97 |
| `threading.Event()` stop signal | 97 |
| `start()` — daemon thread launch | 122-126 |
| `stop()` — event.set() | 128-130 |
| `_loop()` — while + wait(timeout=) | 136-183 |

**Collector and Retrainer** follow this pattern exactly.

### Module-level DB engine pattern (`db/session.py`)

| Item | Line |
|------|------|
| `_engine: Engine \| None = None` | 35 |
| `wire_engine(engine)` | 41-51 |
| `get_engine()` — RuntimeError if not wired | 54-66 |

**`correction/db.py`** follows this pattern for its own SQLite engine.

### Filesystem write allowlist (`rules/coding.md`)

| Item | Line |
|------|------|
| "Never write files outside `/etc/weewx-clearskies/` or `/tmp`" | 147 |
| "Never INSERT/UPDATE/DELETE weewx DB" | 149 |
| "Never `pickle.loads` on untrusted data" | L~30 |

Correction DB and model file both live in `/etc/weewx-clearskies/` (within allowlist). Model `.pkl` is generated by our own training code on the same machine (not untrusted data). **coding.md needs no amendment.**

### pyproject.toml

| Item | Line |
|------|------|
| `[project.dependencies]` section | 14-54 |

`scikit-learn>=1.5.0` added after existing dependencies.

### Canonical forecast fields (canonical-data-model.md + HourlyForecastPoint)

Available on every hourly forecast point:
- `outTemp` — temperature (all providers)
- `windDir` — wind direction degrees (all providers)
- `outHumidity` — humidity % (all providers)
- `cloudCover` — cloud cover % (all providers)
- `windSpeed` — wind speed (all providers)
- `validTime` — ISO-8601 timestamp (all providers)

---

## Phases

### Phase 0: ADR + Manual Updates (BLOCKS ALL CODE)

No code is written until ADR-079 is Accepted and manuals are updated.

| Task | Owner | Dep | Deliverable | Accept | QC |
|------|-------|-----|-------------|--------|-----|
| **0.1** Draft ADR-079 (Forecast Correction Engine) — Proposed | Lead | — | `docs/decisions/ADR-079-forecast-correction-engine.md` with Status: Proposed | ADR follows Nygard format per `rules/clearskies-process.md` L48-54; has Context, Options, Decision, Consequences, Implementation guidance, Acceptance criteria | User reviews + explicitly approves → Accepted |
| **0.2** Update API-MANUAL.md | docs-author | 0.1 Accepted | New §14 "Forecast Correction Engine" covering: correction pipeline position (after cache, before response), data collection background task, TruScore metrics, model training lifecycle, admin endpoints contract | Section follows existing manual pattern (numbered, cross-refs ADR-079); prescriptive rules for implementers | Lead reviews for completeness + accuracy vs ADR-079 |
| **0.3** Update OPERATIONS-MANUAL.md | docs-author | 0.1 Accepted | New subsection in §4 "Configuration" for `[forecast_correction]` INI section; new entry in §1 "Deployment" for DB + model file paths in `/etc/weewx-clearskies/` | Config format, defaults, every key documented; file paths + permissions documented | Lead reviews |
| **0.4** Update ARCHITECTURE.md | docs-author | 0.1 Accepted | New row in vocabulary table (L11-29) for "Forecast correction engine"; new entry in services/data-stores section (L35-88) for SQLite correction DB | Follows existing table format; references ADR-079 | Lead reviews |

**Tasks 0.2-0.4 can run in parallel** (single docs-author agent, one prompt covering all three manuals).

### Phase 1: Foundation (storage + config + dependency)

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **1.1** Create `correction/db.py` | api-dev | Phase 0 | `correction/__init__.py` (new), `correction/db.py` (new) | SQLite engine wiring (module-level `_engine` pattern per `db/session.py` L35-66); schema creation (two tables per §Schema below); CRUD functions: `insert_pair()`, `get_training_data()`, `get_validation_data()`, `purge_old_records()`, `get_pair_count()`, `get_date_range()`, `save_model_metadata()`, `get_model_metadata()` | All CRUD functions work against in-memory SQLite; schema idempotent (CREATE IF NOT EXISTS); WAL mode enabled on connect | test-author (1.4) |
| **1.2** Create `correction/models.py` | api-dev | Phase 0 | `correction/models.py` (new) | Pydantic response models: `CorrectionStatusResponse`, `CorrectionToggleRequest` (with `ConfigDict(extra="forbid")`), `CorrectionToggleResponse`, `RetrainResponse` — pattern per `endpoints/setup.py` L131-138 | Models importable; `extra="forbid"` on request models; all fields typed | test-author (1.4) |
| **1.3** Create `ForecastCorrectionSettings` + wire into `load_settings()` | api-dev | Phase 0 | `config/settings.py` (modify) | New class after L895 following `ForecastSettings` pattern (L789-895): `__init__` from section dict, `validate()`. Fields: `enabled` (bool, default false), `collection_enabled` (bool, default true), `db_path` (str, default `/etc/weewx-clearskies/forecast_correction.db`), `model_path` (str, default `/etc/weewx-clearskies/forecast_correction_model.pkl`), `retrain_schedule` (str: weekly\|daily\|manual, default weekly), `retrain_day` (int 0-6, default 0), `min_samples` (int, default 500, validate ≥100), `retention_years` (int, default 3, validate ≥1). Add to `Settings.__init__` (L1302) as `forecast_correction: ForecastCorrectionSettings \| None = None`. Add parse in `load_settings()` after L1487. Add to `Settings()` constructor call after L1515. Add `self.forecast_correction.validate()` in `Settings.validate()` after L1377. | Settings load from INI; defaults work when section absent; validation rejects invalid values | test-author (1.4) |
| **1.4** Tests for Phase 1 | test-author | 1.1-1.3 | `tests/test_correction_db.py` (new), `tests/test_correction_settings.py` (new) | DB tests: schema creation, all CRUD ops, purge deletes old records + keeps recent, metadata singleton constraint, WAL mode. Settings tests: defaults, parse from dict, validate rejects bad values, validate accepts good values. Use in-memory SQLite with `StaticPool` per `conftest.py` L85-129 pattern. | All tests pass; ≥15 test cases across DB + settings | Lead reviews test coverage |
| **1.5** Add scikit-learn dependency | api-dev | — | `pyproject.toml` (modify) | Add `"scikit-learn>=1.5.0",` after L54 in `[project.dependencies]` | `pip install -e .` succeeds with scikit-learn resolved | Lead verifies |
| **1.6** Add config example | api-dev | 1.3 | `etc/api.conf.example` (modify) | Add `[forecast_correction]` section with all keys as comments showing defaults | Section matches `ForecastCorrectionSettings` fields exactly | Lead reviews |

**Tasks 1.1, 1.2, 1.3 can run in parallel** (same api-dev agent, one prompt). Task 1.4 depends on 1.1-1.3. Task 1.5 is independent.

### Phase 2: Data Collection

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **2.1** Create `correction/collector.py` | api-dev | Phase 1 | `correction/collector.py` (new) | `ForecastCollector` class following `BackgroundCacheWarmer` daemon thread pattern (`cache_warmer.py` L73-183): `__init__` takes weewx engine + archive_interval + settings; `start()` launches daemon thread; `stop()` signals via `threading.Event`; `_loop()` uses `_stop_event.wait(timeout=archive_interval)`. Per tick: (a) query latest archive record for `outTemp` + `dateTime` using read-only session from `db/session.py` `get_engine()`; (b) read current cached forecast bundle via provider dispatch or cache lookup; (c) find hourly point whose `validTime` is closest to archive timestamp; (d) extract 5 forecast features (outTemp, windDir, outHumidity, cloudCover, windSpeed) + temporal features (month, hour, day_of_year); (e) write pair to correction SQLite via `correction/db.py` `insert_pair()`; (f) skip if pair for this timestamp already exists (UNIQUE constraint). Handle: missing archive record (skip), missing cached forecast (skip), missing individual features (store as None). | Collector runs as daemon thread; writes pairs every archive_interval; handles all skip conditions without crashing; respects read-only posture toward weewx DB | test-author (2.3) + auditor (Phase 6) |
| **2.2** Wire collector at startup in `__main__.py` | api-dev | 2.1 | `__main__.py` (modify) | Insert new step `6m½` after L907 (after `wire_forecast_settings`). Pattern follows cache warmer wiring (L854-876): conditional on `settings.forecast_correction.collection_enabled`; import `ForecastCollector`; create instance with `engine` (weewx read-only), `get_station_info().archive_interval`, `settings.forecast_correction`; call `start()`. Store reference for shutdown. | API starts with collector running; no startup regression when `[forecast_correction]` absent (defaults to collection_enabled=true but no crash if DB path not writable — log warning and disable) | test-author (2.3) |
| **2.3** Tests for Phase 2 | test-author | 2.1-2.2 | `tests/test_correction_collector.py` (new) | Mock weewx session (return canned archive row) + mock forecast cache (return canned ForecastBundle with known hourly points). Test: (a) pair written with correct features; (b) missing archive → no pair written; (c) missing forecast → no pair written; (d) duplicate timestamp → no error (UNIQUE constraint); (e) None features stored correctly; (f) thread starts and stops cleanly. Use in-memory SQLite. | All tests pass; ≥8 test cases | Lead reviews |

### Phase 3: Model Training

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **3.1** Create `correction/trainer.py` | api-dev | Phase 1 | `correction/trainer.py` (new) | `train_model(settings) -> dict` function: (a) purge records older than `retention_years`; (b) load training data (all pairs except last 30 days) via `db.get_training_data()`; (c) load validation data (last 30 days) via `db.get_validation_data()`; (d) check `min_samples` gate — return early with status if insufficient; (e) build feature matrix X from 7 features, target vector y = `actual_temp - fcst_temp` (bias); (f) handle None features with median imputation — compute training medians per feature, store alongside model; (g) fit `RandomForestRegressor(n_estimators=150, max_depth=6, random_state=42)`; (h) predict on validation set — compute MAE_raw (validation `abs(actual - forecast)` mean) and MAE_corrected (validation `abs(actual - (forecast + predicted_bias))` mean); (i) compute TruScore: `provider_score = 100 - mae_raw`, `correction_pct = max(0, (mae_raw - mae_corrected) / mae_raw * 100)`; (j) serialize model + feature medians dict to `.pkl` via `joblib.dump()` — write to temp file then `os.rename()` for atomicity; (k) update `model_metadata` in SQLite via `db.save_model_metadata()`; (l) return dict with success, all metrics, sample_count. | Training produces valid model file; TruScore computed correctly; median imputation consistent between training and prediction; atomic file write; min_samples gate works | test-author (3.2) + auditor (Phase 6) |
| **3.2** Tests for Phase 3 | test-author | 3.1 | `tests/test_correction_trainer.py` (new) | Synthetic data tests: (a) generate 1000 pairs with known constant +2°F bias → model should learn ~+2 bias, MAE_corrected < MAE_raw; (b) generate data with hour-dependent bias (afternoon +3, morning +1) → model captures diurnal pattern; (c) fewer than min_samples → returns early, no model file; (d) None features → median imputation works, no crash; (e) model serialization round-trip (dump + load + predict matches); (f) TruScore math verified against hand-calculated values; (g) retention purge removes old records. Use `tmp_path` for model files, in-memory SQLite. | All tests pass; ≥10 test cases; synthetic bias patterns correctly learned | Lead reviews |

### Phase 4: In-flight Correction

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **4.1** Create `correction/corrector.py` | api-dev | Phase 3 | `correction/corrector.py` (new) | Module-level state pattern (per `haze_condition.py` L45-89): `_model = None`, `_enabled = False`, `_model_path = None`, `_feature_medians = None`. Functions: `wire_corrector(settings)` — load model from disk at startup if file exists, set `_enabled` from settings; `reload_model() -> bool` — reload after retraining; `is_active() -> bool` — True only if `_enabled AND _model is not None`; `set_enabled(enabled: bool)` — runtime toggle; `correct_bundle(bundle: ForecastBundle) -> ForecastBundle` — iterate `bundle.hourly`, for each point extract 7 features from the forecast point fields (month/hour from `validTime`, outTemp, windDir, outHumidity, cloudCover, windSpeed), impute None features with stored medians, predict bias, adjust `point.outTemp = round(point.outTemp + predicted_bias, 1)`. Return bundle (mutated in place is fine — it's post-cache). Daily points untouched. No-op if `not is_active()`. | Correction applies to all hourly points; no-op when model unavailable or disabled; missing features handled via medians; performance <5ms for 168 points | test-author (4.3) |
| **4.2** Integrate correction into forecast endpoint | api-dev | 4.1 | `endpoints/forecast.py` (modify) | Insert after L464 (sunrise/sunset injection), before L466 (slice). 3-5 lines: `from weewx_clearskies_api.correction.corrector import correct_bundle, is_active` then `if is_active(): bundle = correct_bundle(bundle)`. | Forecast responses include corrected temps when model active; raw temps when model inactive; no regression in existing forecast behavior | test-author (4.3) |
| **4.3** Tests for Phase 4 | test-author | 4.1-4.2 | `tests/test_correction_corrector.py` (new), `tests/test_forecast_correction_integration.py` (new) | **Unit tests:** (a) load pre-built model, apply to synthetic ForecastBundle, verify temps adjusted; (b) `is_active()` returns False when model None; (c) `is_active()` returns False when disabled; (d) `correct_bundle()` no-op when not active; (e) missing features use medians; (f) daily points unchanged. **Integration test:** wire forecast provider (openmeteo fixture), populate correction DB with synthetic pairs, train model, call `GET /api/v1/forecast` via TestClient, verify response temps differ from raw provider temps. Use `@pytest.mark.integration` marker per `conftest.py` L131 pattern. | All tests pass; ≥12 test cases (8 unit + 4 integration); integration test proves end-to-end correction flow | Lead reviews |

### Phase 5: Admin Endpoints + Scheduled Retrainer

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **5.1** Add admin endpoints to `endpoints/setup.py` | api-dev | Phases 1-4 | `endpoints/setup.py` (modify) | Add 3 endpoints using existing router (L51) and `require_setup_active` auth (L77-97): (a) `GET /setup/forecast-correction/status` → returns `CorrectionStatusResponse` with all metrics from `db.get_model_metadata()` + `db.get_pair_count()` + `db.get_date_range()` + `corrector.is_active()` + settings state; (b) `POST /setup/forecast-correction/toggle` → accepts `CorrectionToggleRequest`, updates runtime state via `corrector.set_enabled()`, persists to settings (or api.conf if pattern exists), returns `CorrectionToggleResponse`; (c) `POST /setup/forecast-correction/retrain` → calls `trainer.train_model()` synchronously (training takes <5s), calls `corrector.reload_model()`, returns `RetrainResponse` with metrics. All endpoints require proxy auth when setup complete. | All 3 endpoints return correct response shapes; auth enforced; toggle changes runtime behavior; retrain produces updated model | test-author (5.3) |
| **5.2** Create `BackgroundRetrainer` + wire at startup | api-dev | 5.1 | `correction/retrainer.py` (new), `__main__.py` (modify) | `BackgroundRetrainer` class following `BackgroundCacheWarmer` pattern: daemon thread, checks once per hour whether it's time to retrain (weekly: `retrain_day` at ~3:00 AM station time; daily: ~3:00 AM). When triggered: calls `trainer.train_model()` then `corrector.reload_model()`. Logs results. Wire at startup in `__main__.py` step `6m½` alongside collector (conditional on `retrain_schedule != "manual"`). | Retrainer runs on schedule; logs results; does not crash on training failure (logs error, continues) | test-author (5.3) |
| **5.3** Tests for Phase 5 | test-author | 5.1-5.2 | `tests/test_correction_admin.py` (new) | TestClient calls to all 3 `/setup/forecast-correction/*` endpoints: (a) status returns correct shape; (b) status without proxy auth → 401; (c) toggle changes `is_active()`; (d) retrain with sufficient data → success + metrics; (e) retrain with insufficient data → success=false + message. | All tests pass; ≥8 test cases; auth tested | Lead reviews |

### Phase 6: Audit

| Task | Owner | Dep | Files | Do | Accept | QC |
|------|-------|-----|-------|-----|--------|-----|
| **6.1** Source + ADR audit | auditor | Phases 1-5 | All new + modified files | Audit against: (a) ADR-079 acceptance criteria — walk every criterion; (b) `rules/coding.md` §1 security constraints (L145-166) — verify no weewx DB writes, no writes outside `/etc/weewx-clearskies/`, parameterized SQL, no untrusted pickle; (c) `rules/coding.md` §3 organization — single responsibility, no mega-files; (d) API-MANUAL.md §14 — implementation matches prescriptive rules; (e) OPERATIONS-MANUAL.md — config section matches settings class; (f) Settings pattern consistency — new class matches existing pattern. Per finding: severity + citation + file:line + failure mode + remediation. | Every ADR-079 acceptance criterion checked (PASS/FAIL); every coding.md §1 constraint verified; findings formatted F1/F2/..Fn | Lead synthesizes findings |
| **6.2** Address audit findings | api-dev | 6.1 | Per findings | Fix all MEDIUM+ findings from 6.1 | All MEDIUM+ findings resolved; re-audit confirms | auditor re-checks |

### Phase 7: Admin UI (separate brief — deferred)

Config UI changes to render the correction management section in the admin panel. Depends on all API phases complete. Own brief in `docs/planning/briefs/`.

---

## SQLite schema

```sql
CREATE TABLE IF NOT EXISTS forecast_observation_pairs (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp     INTEGER NOT NULL UNIQUE,   -- Unix epoch of the observation
    provider_id   TEXT    NOT NULL,           -- "aeris", "openmeteo", "nws", etc.
    month         INTEGER NOT NULL,           -- 1-12
    hour          INTEGER NOT NULL,           -- 0-23
    day_of_year   INTEGER NOT NULL,           -- 1-366 (stored for future experiments)
    fcst_temp     REAL    NOT NULL,           -- forecast outTemp for this hour
    fcst_wind_dir     REAL,                   -- forecast windDir (nullable)
    fcst_humidity     REAL,                   -- forecast outHumidity (nullable)
    fcst_cloud_cover  REAL,                   -- forecast cloudCover (nullable)
    fcst_wind_speed   REAL,                   -- forecast windSpeed (nullable)
    actual_temp   REAL    NOT NULL,           -- observed outTemp from archive
    created_at    INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS model_metadata (
    id              INTEGER PRIMARY KEY CHECK (id = 1),  -- singleton
    last_trained    TEXT,            -- ISO-8601 UTC
    sample_count    INTEGER,
    mae_raw         REAL,           -- validation MAE of raw forecasts (°F or °C)
    mae_corrected   REAL,           -- validation MAE after correction
    provider_score  REAL,           -- 100 - MAE_raw
    correction_pct  REAL,           -- % improvement (clamped ≥0)
    model_path      TEXT,           -- path to .pkl file
    training_status TEXT DEFAULT 'idle'  -- idle | training | failed
);

CREATE INDEX IF NOT EXISTS idx_pairs_timestamp
    ON forecast_observation_pairs(timestamp);
CREATE INDEX IF NOT EXISTS idx_pairs_provider
    ON forecast_observation_pairs(provider_id);
```

`id = 1` CHECK constraint enforces singleton — one active model at a time.

---

## Configuration (`api.conf`)

```ini
[forecast_correction]
# enabled = false               # Apply corrections to forecast temps
# collection_enabled = true     # Collect forecast-observation pairs (independent of correction)
# retrain_schedule = weekly     # weekly | daily | manual
# retrain_day = 0               # Day of week for weekly retrain (0=Mon, 6=Sun)
# min_samples = 500             # Minimum pairs before first model training (~21 days hourly)
# retention_years = 3           # Rolling data retention window
# db_path = /etc/weewx-clearskies/forecast_correction.db
# model_path = /etc/weewx-clearskies/forecast_correction_model.pkl
```

---

## New file inventory

All in `repos/weewx-clearskies-api/weewx_clearskies_api/correction/`:

| File | Lines (est.) | Owner | Phase | Responsibility |
|------|-------------|-------|-------|---------------|
| `__init__.py` | ~40 | api-dev | 1 | Package init; exports `wire_correction_engine()` orchestrating startup |
| `db.py` | ~180 | api-dev | 1 | SQLite wiring, schema, CRUD |
| `models.py` | ~50 | api-dev | 1 | Pydantic response models for admin endpoints |
| `collector.py` | ~150 | api-dev | 2 | `ForecastCollector` daemon thread |
| `trainer.py` | ~160 | api-dev | 3 | `train_model()`, TruScore, serialization |
| `corrector.py` | ~120 | api-dev | 4 | Module-level model state, `correct_bundle()` |
| `retrainer.py` | ~80 | api-dev | 5 | `BackgroundRetrainer` daemon thread |

## Modified file inventory

| File | What changes | Owner | Phase |
|------|-------------|-------|-------|
| `config/settings.py` | +`ForecastCorrectionSettings` class (~50 lines), +param in `Settings.__init__`, +parse in `load_settings()`, +validate call | api-dev | 1 |
| `pyproject.toml` | +`scikit-learn>=1.5.0` | api-dev | 1 |
| `etc/api.conf.example` | +`[forecast_correction]` section | api-dev | 1 |
| `__main__.py` | +step 6m½ (~20 lines): wire correction engine, start collector + retrainer | api-dev | 2, 5 |
| `endpoints/forecast.py` | +3-5 lines: correction call after L464 | api-dev | 4 |
| `endpoints/setup.py` | +3 endpoints (~80 lines) | api-dev | 5 |
| `docs/ARCHITECTURE.md` | +vocabulary entry, +data store entry | docs-author | 0 |
| `docs/manuals/API-MANUAL.md` | +§14 Forecast Correction Engine | docs-author | 0 |
| `docs/manuals/OPERATIONS-MANUAL.md` | +config section, +file paths | docs-author | 0 |

## Test file inventory

| File | Phase | Focus | Est. cases |
|------|-------|-------|-----------|
| `tests/test_correction_db.py` | 1 | SQLite schema, CRUD, purge, metadata singleton | ≥8 |
| `tests/test_correction_settings.py` | 1 | Settings parse, defaults, validation | ≥7 |
| `tests/test_correction_collector.py` | 2 | Pair collection, skip conditions, thread lifecycle | ≥8 |
| `tests/test_correction_trainer.py` | 3 | Training pipeline, TruScore, imputation, serialization | ≥10 |
| `tests/test_correction_corrector.py` | 4 | Correction application, no-op cases, missing features | ≥8 |
| `tests/test_forecast_correction_integration.py` | 4 | End-to-end: collect → train → correct → verify response | ≥4 |
| `tests/test_correction_admin.py` | 5 | Admin endpoint auth, response shapes, toggle, retrain | ≥8 |

---

## Dependency graph

```
Phase 0: ADR-079 + Manual Updates
    │
    ├──► Phase 1: Foundation (db + config + settings + dependency)
    │        │
    │        ├──► Phase 2: Data Collection (collector + startup wiring)
    │        │        │
    │        │        ├──► Phase 3: Model Training (trainer)
    │        │        │        │
    │        │        │        ├──► Phase 4: In-flight Correction (corrector + endpoint)
    │        │        │        │        │
    │        │        │        │        ├──► Phase 5: Admin Endpoints + Retrainer
    │        │        │        │        │        │
    │        │        │        │        │        ├──► Phase 6: Audit
    │        │        │        │        │        │
    │        │        │        │        │        ├──► Phase 7: Admin UI (deferred)
```

Each phase is strictly sequential — no cross-phase parallelism. Within each phase, api-dev and test-author tasks can overlap where noted.

---

## QC gates (per phase, every phase)

| Gate | What | Who |
|------|------|-----|
| **1. Scope ack** | Agent confirms in-scope files + out-of-scope exclusions + verification command before writing code | Lead confirms via SendMessage |
| **2. Tests pass** | `pytest tests/test_correction_*.py -v` → 0 failures | test-author runs; lead verifies output |
| **3. Type check** | No new type errors introduced (existing codebase does not enforce `mypy --strict` globally, but new module should have clean type hints) | api-dev self-check |
| **4. Manual compliance** | Implementation matches API-MANUAL §14 prescriptive rules | auditor (Phase 6) |
| **5. ADR acceptance criteria** | Every criterion in ADR-079 has a corresponding deliverable | auditor (Phase 6) |

---

## ADR-079 acceptance criteria (draft — to be refined during ADR authoring)

1. Forecast-observation pairs are logged to a separate SQLite database; the weewx archive database is never written to by the API
2. A trained RandomForestRegressor corrects hourly forecast temperatures before serving responses
3. Correction is provider-agnostic (works with any configured forecast provider)
4. Operator can independently enable/disable data collection and forecast correction via `api.conf` and admin endpoints
5. TruScore metrics (provider accuracy + correction improvement %) are computed during training and accessible via admin endpoint
6. Rolling 3-year data retention is enforced during each training run
7. Model training can be triggered on-demand via `/setup/forecast-correction/retrain`
8. When model is unavailable or correction is disabled, raw forecasts pass through unchanged (no degradation)
9. API startup does not fail when `[forecast_correction]` section is absent from `api.conf`
10. All new code respects `rules/coding.md` §1 security constraints

---

## Edge cases (documented for agent briefs)

| Scenario | Expected behavior |
|----------|-------------------|
| `[forecast_correction]` absent from api.conf | Defaults apply: collection_enabled=true, correction disabled. If DB path not writable, log warning, disable collection. |
| Model file missing at startup | `is_active()` = False; raw forecasts served; admin shows `model_available: false` |
| Provider switch (operator changes forecast provider) | New pairs logged with new `provider_id`; existing data retained; next retrain learns from mixed data |
| <500 samples collected | Training returns early; no model produced; admin shows progress toward threshold |
| Training fails (exception) | `training_status` set to `failed`; old model remains active; error logged |
| Concurrent retrain + forecast request | Trainer writes temp file → atomic `os.rename()`; brief window uses old model |
| Forecast point missing windDir or cloudCover | Feature stored as None; training uses median imputation; prediction uses same medians |
| Correction makes forecast worse (negative improvement) | `correction_pct` clamped to 0; admin shows this; operator can disable correction |
| Archive interval longer than 1 hour | Collector fires once per interval; fewer pairs per day but still learns (just slower bootstrap) |

---

## Verification plan

### Per-phase verification (run by test-author, verified by lead)

```bash
# After each phase, from the weewx-clearskies-api repo root:
pytest tests/test_correction_*.py -v --tb=short
```

### End-to-end verification (Phase 4 integration test)

The integration test in `tests/test_forecast_correction_integration.py` covers:
1. Wire a forecast provider (openmeteo fixture)
2. Populate correction SQLite with ≥500 synthetic pairs having known +2°F bias
3. Train model via `trainer.train_model()`
4. Call `GET /api/v1/forecast` via TestClient
5. Assert response hourly temps differ from raw provider temps by ~+2°F (±0.5 tolerance)
6. Assert TruScore metrics show positive improvement

### Manual verification (post-deploy, operator-driven)

1. Deploy to `weewx` container with `collection_enabled = true`, `enabled = false`
2. Wait for 500+ pairs (~3.5 days at 5-min archive interval)
3. Trigger retraining via admin endpoint
4. Enable correction
5. Monitor TruScore over 30 days via admin endpoint

---

## Brief locations

Execution briefs will be created per-phase at `docs/planning/briefs/`:

| Phase | Brief file |
|-------|-----------|
| 0 | `FORECAST-CORRECTION-P0-ADR-MANUALS.md` |
| 1-3 | `FORECAST-CORRECTION-P1-3-FOUNDATION-TRAINING.md` (combined — tightly coupled) |
| 4-5 | `FORECAST-CORRECTION-P4-5-CORRECTION-ADMIN.md` (combined) |
| 6 | `FORECAST-CORRECTION-P6-AUDIT.md` |

Each brief follows the 10-section format per `rules/clearskies-process.md` §"Agent prompt requirements" (L148-165): Objective, Scope (create/modify/NOT-touch), Reading list, Pre-round verification, Per-deliverable spec, Lead calls, Open questions, Verification, Git restrictions, Scope acknowledgment gate.
