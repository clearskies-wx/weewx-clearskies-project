# Seasonal Monthly-Normals Calibration Model — Implementation Plan

**Status:** APPROVED — ready to execute  
**Created:** 2026-06-22  
**Origin:** Rework of Phase 8 auto-calibration (flat 90-day window) to science-backed monthly normals  
**Components:** API (`weewx-clearskies-api`), Stack (`weewx-clearskies-stack`), Meta (`weather-belchertown`)

---

## Session Context (for cold-start)

### What prompted this

During Phase 10 (deploy + verify) of the Haze/Fog/NWS Text implementation plan (`docs/planning/HAZE-FOG-NWS-TEXT-IMPLEMENTATION-PLAN.md`), the user identified that the auto-calibration system ignored the project's own research on seasonal variation. The research (Correa 2022, Renner 2019, Stein et al. 2012) established that clear-sky transmittance varies by month, but the implementation used a flat 90-day rolling percentile with no seasonal awareness. The user called this out as "throwing the research out the window."

### What's deployed (as of 2026-06-22)

Phases 0-9 of the Haze/Fog/NWS Text plan are complete and deployed. Phase 10 deployment is partially done:

- **API on weewx** (`192.168.7.20`): at commit `170805f` (includes openaq_api_key fix for wizard 422). Service running, all Phase 9 audit remediations active. 354 new tests passing. `weatherText`, `weatherTextStandard`, `weatherTextVerbose` fields live.
- **Stack on weather-dev** (`192.168.2.113`): at commit `861e121` (includes about_content wizard fixes + openaq_api_key round-trip). Config UI running on port 9876.
- **Meta repo**: at commit `02a49d0` (Phase 9 plan closeout).
- **Aeris AQI** is now the active AQI provider (user applied wizard settings this session).
- **OpenAQ API key** entered by user in wizard, written to `secrets.env` on weewx.

### Key infrastructure notes

- **DILBERT is down.** Working from CATBERT. Repos replicate via Nextcloud.
- Tests run on **weewx** container (not weather-dev): `ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -lc 'export PATH=/home/ubuntu/.local/bin:$PATH && cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest ...'"` 
- API sync: `ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull --ff-only'"` then `sudo systemctl restart weewx-clearskies-api` (2-min startup).
- Stack sync: `ssh -F .local/ssh/config weather-dev "sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-stack && git pull --ff-only'"` then pip reinstall + `sudo systemctl restart weewx-clearskies-config`.
- The sync script (`scripts/sync-to-weather-dev.sh`) does NOT include the API repo.
- Pytest baseline: 3188+ passed, 358 skipped, 3 pre-existing failures (OWM Redis cache x 2, weewx metadata x 1).

### Design decisions from user conversation

These are settled — do not re-derive or re-propose alternatives:

1. **Monthly normals, not rolling window.** 12 per-month Kcs baselines. Compare today against what clear sky looks like *this month*, not a flat average.
2. **3-year rolling window per month.** Samples older than 3 years age out (sensor drift). 2 years minimum for bootstrap.
3. **Fixed parameters, not operator-tunable.** 92nd percentile, 30 samples/month minimum, 3-year window. Science sets these. Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from config and admin UI.
4. **Automatic bootstrap.** API detects OpenAQ key + insufficient data at startup → bootstraps in background. No CLI, no admin button, no SSH.
5. **Progressive activation.** Start with flat baseline (current behavior). Each month independently transitions to its learned normal at >= 30 samples. Admin shows "N of 12 months calibrated."
6. **Operator can disable during learning, auto-enable at 12/12.** Admin toggle for haze detection. System auto-enables once fully calibrated.
7. **Hardware change:** Manual reset button in admin + automatic drift detection + station_type change warning on restart.
8. **Graceful sensor failover.** Missing pyranometer → provider haze 24/7 (extends nighttime deferral). Missing hygrometer → provider fog/mist. Silent failover, no operator messaging. Dashboard never shows nulls.
9. **Cross-host topology.** Admin reads calibration state from API endpoints (`/setup/calibration-state`, `/setup/calibration-reset`), NOT from local filesystem. calibration.json is on weewx, admin is on weather-dev.
10. **calibration.json stays at `/etc/weewx-clearskies/calibration.json`.** Same location, v2 format with month-keyed structure. v1 migration on load.

### Bugs fixed during this session (already deployed, not part of this plan)

- **Wizard 422 on apply:** `ApplyRequest` model missing `openaq_api_key` field (API commit `170805f`, stack commit `2d44b34`).
- **Station description not sticking:** Three bugs — template `about_content` missing `state.` prefix, `populate_from_branding_json` not reading `aboutContent` back, and branding read gated behind `station_name is None` (stack commits `941a961`, `52a3de7`, `861e121`).

---

## What Changes

Replace the flat rolling-window model with 12 per-month Kcs baselines (climatological monthly normals) backed by a 3-year rolling window. Bootstrap automatically on startup. Remove operator-tunable calibration parameters. Add hardware change detection. Add API endpoints for calibration state/reset. Extend provider deferral for missing sensors.

**What doesn't change:** The clean-sky gate criteria (rain holdoff, solar elevation, sky classifier, PM threshold), the hygroscopic correction (gamma), the haze detection logic in haze_condition.py (it still receives a single baseline float), the Kcs computation itself.

**Graceful sensor failover:** When sensor data is absent, the affected module silently falls back to provider present weather codes — same mechanism as nighttime deferral (ADR-071). No operator-facing warnings. Dashboard never shows null data.

| Sensor data absent | Failover |
|---|---|
| `radiation` (no pyranometer) | Sky: provider cloud cover % (already works). Haze: provider present weather (HZ) 24/7. Calibration: skip. |
| `dewpoint` (no hygrometer) | Fog/mist: provider present weather (BR/FG). f(RH) correction: skip (use uncorrected deficit). Comfort: omit. |

---

## Phase 0 — ADR-068 Amendment

ADR-068 (Auto-Calibration Baseline System) must be amended to reflect the monthly-normals model. Status flips to Proposed, user approves, then re-archived.

**T0.1 — Amend ADR-068**
- Owner: Coordinator (Opus) — judgment work
- Changes: Replace 90-day rolling window with monthly-normals model. Remove operator-tunable calibration parameters. Add auto-bootstrap requirement. Add hardware change handling. Add degraded-mode progressive activation.
- Accept: ADR reflects all design decisions from the user conversation. User approves.

---

## Phase 1 — Manual Updates (Before Code)

**T1.1 — Update API-MANUAL.md section 8 (auto-calibration)**
- Owner: `clearskies-docs-author`
- Rewrite auto-calibration subsection: 12 per-month buckets, 3-year rolling window, fixed 92nd percentile (not tunable), progressive activation (each month independently transitions from flat fallback to learned normal at >= 30 samples), auto-bootstrap, hardware change handling.
- Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from config table. Keep `haze_detection`, `gamma`, `haze_aqi_provider`.
- Add: storage format (month-keyed calibration.json), degraded-mode behavior, drift detection, reset semantics.
- Accept: No references to flat 90-day window. No references to removed config keys as tunable.

**T1.2 — Update OPERATIONS-MANUAL.md**
- Owner: `clearskies-docs-author`
- Remove calibration params from `[conditions]` config table. Remove CLI bootstrap instructions. Rewrite admin haze calibration section: per-month status grid, reset button, drift warnings. Describe auto-bootstrap (startup detection, background execution).
- Accept: No manual CLI references. Config table has exactly `haze_detection`, `haze_aqi_provider`, `gamma`.

**T1.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author`
- Update `auto_calibration.py` description: "monthly-normals model, 12 per-month Kcs baselines, 3-year rolling window, automatic bootstrap, persistent storage." Add new API endpoints (`/setup/calibration-state`, `/setup/calibration-reset`) to setup endpoints table.
- Accept: Architecture description says "monthly-normals" not "90-day rolling percentile."

**QC (Opus):** Read every updated section. Walk each removed config key — confirm no orphan references. Cross-check API-MANUAL, OPS-MANUAL, and ARCHITECTURE agree on config keys, state names, and endpoint inventory.

---

## Phase 2 — auto_calibration.py Rework (Core Model)

**T2.1 — Rewrite auto_calibration.py**
- Owner: `clearskies-api-dev`
- This is the largest task. Key changes:

**Data structure:**
- Replace `_samples: list[tuple[float, float]]` with `_monthly_samples: dict[int, list[tuple[float, float]]]` keyed by month 1-12 (station local time, not UTC — a sample at 11pm Jan 31 local is January's bin).
- Add `_monthly_baselines: dict[int, float | None]` and `_flat_baseline: float | None` (fallback from all months pooled).
- Add `_station_type_at_load: str | None` for hardware change tracking.

**Constants (fixed, not configurable):**
- `_WINDOW_YEARS = 3`, `_MIN_SAMPLES_PER_MONTH = 30`, `_PERCENTILE = 92`, `_MIN_MONTHS_AUTO_ENABLE = 12`, `_DRIFT_THRESHOLD = 0.05`
- Remove all mutable globals (`_WINDOW_DAYS_PRIMARY`, `_PERCENTILE_LOW`, etc.)

**Functions:**
- Remove `configure()` entirely.
- `process_packet()`: same gate sequence, appends to `_monthly_samples[local_month]`, prunes >3yr samples across all months, recomputes current month's baseline, calls `haze_condition.set_baseline()` with current month's value (or flat fallback).
- New `compute_monthly_baseline(month) -> float | None`: 92nd percentile of that month's samples, requires >= 30.
- New `get_current_baseline() -> float | None`: returns current month's baseline, falls back to flat, returns None if neither available.
- Reworked `get_calibration_state() -> dict`: returns `months_calibrated` (0-12), `per_month` (12-element list with name/count/baseline/is_calibrated), `flat_baseline`, `overall_state` ("no-data" | "bootstrapping" | "partial" | "fully-calibrated"), `drift_warnings`, `station_type`.
- New `_check_drift(month) -> dict | None`: if mean of last 10 samples diverges from baseline by > 0.05, return warning.
- New `set_station_type(type)` and `check_station_type_change(current) -> bool`.

**Persistence (calibration.json v2):**
```json
{
  "version": 2,
  "station_type": "Vantage",
  "monthly_samples": {"1": [[ts, kcs], ...], ... "12": [...]},
  "monthly_baselines": {"1": 0.912, "2": null, ...},
  "flat_baseline": 0.908
}
```
- `load_persisted()` handles v1 migration: distributes flat `samples` list into month buckets by timestamp (using station timezone).
- `persist()` writes v2 only.

**Station timezone:** Module needs the station timezone (from StationInfo) to bin samples by local month. New `set_timezone(tz_name: str)` called at startup.

**Pyranometer check:** New `_has_radiation: bool` module-level flag. Set at startup via `set_has_radiation(has: bool)` — caller checks column registry for `radiation`. When False: `process_packet()` returns immediately. The flag is also re-evaluated inside `process_packet()` — if `sky_condition.get_current_kcs()` returns a non-None value, flip `_has_radiation = True` (sensor was added). This handles the "added a pyranometer later" case without requiring a restart.

- Accept: Module compiles. `configure()` gone. `_samples` gone. `get_calibration_state()` returns new schema. v1 migration works. v2 persistence round-trips.

**QC:** Coordinator imports module, calls `get_calibration_state()`, verifies schema. Greps for `configure(` — zero hits. Greps for `_samples` as a standalone name — zero hits (only `_monthly_samples`).

---

## Phase 3 — Bootstrap Rework

**T3.1 — Update importer.py for monthly bins**
- Owner: `clearskies-api-dev`
- `run_bootstrap()` appends to `auto_calibration._monthly_samples[month]` (using station local time). Computes per-month baselines after import. Summary reports per-month counts.
- Remove references to `auto_calibration._samples` and `auto_calibration.compute_baseline()`.
- Accept: No references to `_samples`. Summary includes per-month breakdown.

**T3.2 — Add auto-bootstrap to __main__.py**
- Owner: `clearskies-api-dev`
- After `load_persisted()`, check: OpenAQ key present + `months_calibrated < 12` → run bootstrap synchronously after `load_persisted()` but before packet_tap registration (avoids thread safety issues, same order as cache warmer, takes 2-5 minutes).
- Remove `configure()` call. Replace with `haze_condition.set_gamma(conditions.gamma)`.
- Add `auto_calibration.set_timezone(station_info.timezone)`, `auto_calibration.set_station_type(station_info.hardware)`, and `auto_calibration.set_has_radiation("radiation" in column_registry)` after station metadata and schema load.
- Auto-bootstrap gated on `_has_radiation` — skip if no radiation column.
- Station type change check: log WARNING if changed since persisted data.
- Remove `--years` and `--max-distance-km` from bootstrap CLI argparse. Always pull 3 years max available.
- Accept: `configure()` call gone. Auto-bootstrap runs at startup. Station type check logged.

**QC:** Coordinator greps `__main__.py` for `configure(` — zero hits. Greps for `--years` in argparse — zero hits. Checks startup log for auto-bootstrap message.

---

## Phase 4 — Wiring (haze_condition + settings + API endpoints)

**T4.1 — Extend provider deferral for missing sensors**
- Owner: `clearskies-api-dev`
- Extend the nighttime deferral check in `enrichment/weather_text.py` and `provider_weather_feed.py`: the existing check is `solar_elevation <= gate` → defer to provider. Add checks for missing sensor data: if `get_current_kcs()` returns None (no radiation data), defer haze to provider. If dewpoint/humidity smoothed values are None, defer fog/mist to provider. Same deferral code path — just additional None checks on the data the modules already read, not a separate capability system.
- In `haze_condition.py`: `set_baseline()` signature unchanged. Update module docstring. Remove "Phase 6" references. When humidity is None, skip f(RH) correction (use uncorrected Kcs deficit).
- Wire `_has_radiation` flag into `auto_calibration` to gate bootstrap and sample collection (no radiation → skip, re-evaluate on each packet).
- Accept: No pyranometer → provider haze 24/7 + calibration skipped. No hygrometer → provider fog/mist + no f(RH). Both present → existing behavior unchanged. No operator-visible messaging about sensors — just silent failover.

**T4.2 — Update settings.py ConditionsSettings**
- Owner: `clearskies-api-dev`
- Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from class (attributes, __init__, validate). Keep `haze_detection`, `haze_aqi_provider`, `gamma`. Update docstring.
- Old api.conf files with removed keys won't crash — configobj returns them but __init__ never reads them.
- Accept: `ConditionsSettings` has no calibration params. Loads cleanly with old configs.

**T4.3 — Add API endpoints for calibration state and reset**
- Owner: `clearskies-api-dev`
- New in `endpoints/setup.py`:
  - `GET /setup/calibration-state` — returns `auto_calibration.get_calibration_state()`. Auth: proxy secret (same as `/setup/current-config`).
  - `POST /setup/calibration-reset` — calls `auto_calibration.reset()`, deletes calibration.json, triggers re-bootstrap in background. Auth: proxy secret. Returns `{"success": true, "message": "Calibration reset. Re-bootstrap started."}`.
- These endpoints are needed because in cross-host topology the admin UI runs on weather-dev but calibration data is on weewx. The admin cannot read calibration.json directly.
- Accept: Both endpoints respond. State endpoint returns per-month data. Reset endpoint clears data.

**QC:** Coordinator curls both endpoints on weewx. Verifies state response has `months_calibrated` and `per_month`. Verifies reset clears and re-bootstraps.

---

## Phase 5 — Admin UI Rework (Stack Repo)

**T5.1 — Rework haze_calibration.html**
- Owner: `clearskies-api-dev`
- Remove: calibration parameter form (percentile, window, min_samples inputs). Remove CLI bootstrap aside.
- Add: 12-month status grid (month name, sample count, baseline Kcs, status dot: green/amber/gray). Overall "N of 12 months calibrated." Flat fallback baseline display. Drift warning banner. Station type change warning. "Reset Calibration" button with confirmation.
- Keep: haze_detection toggle, gamma input, Save/Cancel.
- Accept: No parameter inputs. 12-month grid renders. Reset button present.

**T5.2 — Rework admin/routes.py haze calibration routes**
- Owner: `clearskies-api-dev`
- `_read_calibration_state()` → replaced: call API endpoint `GET /setup/calibration-state` via ApiClient (not local file read). Handle connection failure gracefully.
- POST handler: only saves `haze_detection` and `gamma`.
- New route `POST /admin/haze-calibration/reset`: calls API `POST /setup/calibration-reset` via ApiClient. Returns success/failure fragment.
- Remove `_HAZE_DEFAULTS` entries for removed params.
- Accept: No local calibration.json reads. POST saves only 2 fields. Reset calls API.

**T5.3 — Update landing.html haze card**
- Owner: `clearskies-api-dev`
- Replace "Samples (90-day)" with "Months calibrated: N/12." Keep detection toggle and baseline display.
- Accept: No "90-day" references.

**QC:** Coordinator loads admin page, verifies 12-month grid renders, no parameter inputs visible, reset button present.

---

## Phase 6 — Testing

**T6.1 — Rewrite test_auto_calibration.py**
- Owner: `clearskies-test-author`
- Complete rewrite for monthly model:
  - Monthly baseline computation (empty, below min, sufficient, wrong month excluded, 3-year pruning)
  - State transitions (no-data → bootstrapping → partial → fully-calibrated)
  - Per-month progressive activation
  - v1→v2 migration in load_persisted()
  - v2 persistence round-trip
  - Drift detection (divergent samples trigger warning, normal samples don't)
  - Station type tracking (change detection, None handling)
  - Flat fallback when current month has no baseline
  - Timezone-aware month binning
- Remove tests for `configure()`, `_percentile_midpoint()`, flat `compute_baseline()`.
- Accept: All pass. No references to removed functions.

**T6.2 — Verify test_haze_condition.py still passes**
- Owner: `clearskies-test-author`
- Minimal changes — `set_baseline()` interface unchanged. Remove any references to `configure()`.
- Accept: All existing tests pass.

**QC:** Coordinator runs full test suite on weewx. Confirms zero introduced failures.

---

## Phase 7 — Audit + QA

**T7.1 — Code audit**
- Owner: `clearskies-auditor`
- Checklist: no `_samples` references remain, no `configure()` calls remain, removed config keys gone from all files, v1 migration correct (timezone-aware), drift threshold reasonable, persistence atomicity preserved, no circular imports, `reset()` clears all state, thread safety (bootstrap before packet_tap).
- Accept: Zero blocking findings.

**T7.2 — Doc-code sync audit**
- Owner: `clearskies-auditor`
- Every config key in docs exists in code and vice versa. State names match. Endpoint inventory matches. Admin UI description matches template.
- Accept: Zero mismatches.

**QC:** Coordinator reviews findings. Blocking findings → fix dispatch. Non-blocking → documented for follow-up.

---

## Phase 8 — Deploy + Verify

**T8.1 — Deploy API (weewx)**
- Push API repo, pull on weewx, restart service.
- Verify: startup log shows v1 migration (if existing data), station type check, auto-bootstrap start.
- Verify: `GET /api/v1/current` still returns weatherText (no regression).

**T8.2 — Deploy Admin (weather-dev)**
- Push stack repo, pull on weather-dev, reinstall pip package, restart config UI.
- Verify: admin haze calibration page renders 12-month grid, no parameter form, reset button works.

**T8.3 — End-to-end**
- Verify auto-bootstrap populated monthly bins (check `/setup/calibration-state` via curl).
- Verify admin shows correct per-month counts.
- Verify haze_detection toggle works from admin.
- Run full pytest suite — confirm baseline count maintained.

---

## Verification

After all phases:
- ADR-068 amended and re-accepted
- 3 manuals updated (API-MANUAL, OPS-MANUAL, ARCHITECTURE)
- auto_calibration.py uses monthly-normals model with 3-year window
- Bootstrap runs automatically at startup (no CLI, no admin button)
- Admin shows 12-month calibration grid, reset button, drift warnings
- No operator-tunable calibration parameters (only haze_detection, gamma, haze_aqi_provider)
- Cross-host calibration state works via API endpoints
- v1→v2 migration preserves existing data
- Hardware change detection (reset + drift + station_type)
- Graceful sensor failover (missing pyranometer/hygrometer → provider deferral)
- All tests pass, zero introduced failures

---

## Key Files

### API repo (`repos/weewx-clearskies-api`)
- `weewx_clearskies_api/sse/auto_calibration.py` — major rewrite (core model)
- `weewx_clearskies_api/bootstrap/importer.py` — monthly bins, remove --years
- `weewx_clearskies_api/__main__.py` — auto-bootstrap, remove configure(), sensor checks
- `weewx_clearskies_api/config/settings.py` — remove calibration params from ConditionsSettings
- `weewx_clearskies_api/sse/haze_condition.py` — docstring update, f(RH) None handling
- `weewx_clearskies_api/sse/enrichment/weather_text.py` — extend deferral for missing sensors
- `weewx_clearskies_api/sse/enrichment/provider_weather_feed.py` — extend deferral
- `weewx_clearskies_api/endpoints/setup.py` — new calibration-state + calibration-reset endpoints
- `tests/test_auto_calibration.py` — complete rewrite
- `tests/test_haze_condition.py` — minimal updates

### Stack repo (`repos/weewx-clearskies-stack`)
- `weewx_clearskies_config/templates/admin/haze_calibration.html` — rework UI
- `weewx_clearskies_config/templates/admin/landing.html` — update haze card
- `weewx_clearskies_config/admin/routes.py` — API-based state reads, reset route

### Meta repo (root)
- `docs/API-MANUAL.md` — section 8 auto-calibration rewrite
- `docs/OPERATIONS-MANUAL.md` — conditions config table, admin section, bootstrap
- `docs/ARCHITECTURE.md` — auto_calibration description, new endpoints
- `docs/archive/decisions/ADR-068-*` — amend for monthly normals
