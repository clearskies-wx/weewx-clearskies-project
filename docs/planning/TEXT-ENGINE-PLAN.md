# NWS GFE Text Generation System with WorldCast Technology — Execution Plan

**Status:** APPROVED — Phase 0 complete, Phase 1 blocked on ADR-082 approval  
**Created:** 2026-07-05  
**Components:** API (`weewx-clearskies-api`), Meta repo docs  
**Research basis:** [gfe-source-code-analysis.md](../../docs/reference/nws-text-system/gfe-source-code-analysis.md) (~18,700 lines across 16 GFE files), [international-forecast-text-patterns.md](../../docs/reference/nws-text-system/international-forecast-text-patterns.md) (13 locales verified against national met services)

## Current State

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — Prerequisites | **Complete** | WU removed (API `31627cf`, meta `e69ce0d`), SkyPyEye rebrand (API `2a05961`, meta `fe182ef`). QC Gate 0 passed 2026-07-05. |
| Phase 1 — ADR + Docs | **In Progress** | ADR-082 Accepted 2026-07-05. T1.2–T1.4 (governing doc updates) in progress. |
| Phase 2 — Threshold tables | Pending | Depends on Phase 1 |
| Phase 3 — Period aggregation | Pending | Depends on Phase 2 |
| Phase 4 — Phrase generators | Pending | Depends on Phase 2 |
| Phase 5 — Composition engine | Pending | Depends on Phases 4, 6 |
| Phase 6 — WorldCast i18n | Pending | Depends on Phase 4 |
| Phase 7 — Integration | Pending | Depends on Phases 5, 6 |
| Phase 8 — Verification | Pending | Depends on Phase 7 |
| Phase 9 — QA audit | Pending | Depends on Phase 8 |

---

## Context

The current conditions text engine (`text_generator.py`, `conditions_text.py`, `enrichment/weather_text.py`) uses a narrower rule set than the NWS GFE system. Temperature is "Temperature near 85 degrees" — no decade phrasing. Wind has no transition connectors. Precipitation has no coverage language or PoP qualification. Building a separate forecast text engine alongside this creates two systems producing different-quality text for the same vocabulary.

This plan replaces both modules with a single GFE-derived engine that serves current observations (single-instant input via `observation_model.py`) and forecast periods (day/night aggregated input from provider hourly data). The engine ports GFE threshold tables and phrase logic faithfully from the public-domain AWIPS-II source (17 USC §105 — US government work). It extends the existing i18n infrastructure (13 locale JSON files + 3 custom composers) to cover all forecast vocabulary, incorporating GFE `Translator.py` gender/number patterns for Romance languages.

**Brand:** "NWS GFE Text Generation System with WorldCast Technology" in all documentation referring to the text generation system. WorldCast refers to the i18n expansion beyond GFE's French/Spanish to 13 locales with proper sentence structure per locale.

**Scope boundary:** Builds the text engine and all threshold tables (including marine and fire weather). Does NOT build marine or fire weather provider modules (separate plan). Does NOT touch dashboard rendering (separate plan).

**GFE code reuse directive:** Agents MUST study the GFE source code analysis document and port algorithms faithfully. Do not reinvent what NWS already wrote and tested. Replicate the GFE's structure, threshold values, and decision logic. The GFE source is the reference implementation — our code adapts it for single-station use and extends it for 13 locales, but the core algorithms stay faithful to the original.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — especially §6 (i18n: every string through locale files)
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates, doc-code sync
- `docs/manuals/API-MANUAL.md` — conditions text engine section
- `docs/reference/nws-text-system/gfe-source-code-analysis.md` — the GFE reference (threshold tables, phrase logic, assembly pipeline, translation system)
- `docs/reference/nws-text-system/international-forecast-text-patterns.md` — 13 locales verified against national met services
- `docs/planning/briefs/FORECAST-TEXT-ENGINE-BRIEF.md` — the brief this plan implements

**Repos:**
- API: `repos/weewx-clearskies-api`, branch `main`, Python 3.12+
- Meta: `.` (root), branch `master`

**Deploy:** API on weewx container. Dashboard on weather-dev. Coordinator pushes after QC.

**Git safety:** Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No pull/push/fetch/rebase/merge/remote/worktree.

**QC role: Coordinator (Opus).** QC after EVERY phase. No phase advances until coordinator signs off. QC evidence recorded in scratchpad.

**Coordinator preparation (mandatory before every phase):** Before issuing agent assignments or performing QC for any phase, the coordinator MUST:
1. **Read all governing docs** relevant to the phase — the manuals (API-MANUAL, PROVIDER-MANUAL, OPERATIONS-MANUAL, DESIGN-MANUAL as applicable), ARCHITECTURE.md, and the GFE source code analysis sections cited in the phase's tasks.
2. **Read the actual code** being modified or replaced — open the files, understand the current state, trace data flow. Do not QC code you haven't read the context for.
3. **Read the phase's task specs** in this plan — understand exactly what was asked before evaluating whether it was delivered.

This is not optional or skippable for "simple" phases. The coordinator's value is informed judgment — judgment uninformed by the docs and code is rubber-stamping.

**QC criteria (mandatory for every phase):** Every QC gate evaluates four dimensions:
1. **Correctness** — does the code work? Run it. Verify outputs match expected behavior. Check edge cases.
2. **Best practices** — does it follow `rules/coding.md`? Clean code, proper error handling, no dead code, no hardcoded values, proper type hints, i18n compliance (§6).
3. **Task completion** — does it fully satisfy the task spec in this plan? Walk each acceptance criterion. Every "Do" item must have a corresponding deliverable.
4. **Manual compliance** — does it comply with the governing manuals? Any code that touches a manual's domain must conform to that manual's rules. Any code that changes behavior documented in a manual must update the manual.

**QA phase:** After the coordinator completes QC for the final integration phase, a separate QA pass verifies the QC itself was done correctly. See Phase 9.

---

## 1. Settled Decisions

| # | Decision | Source |
|---|----------|--------|
| 1 | **Period convention:** NWS 6am/6pm fixed periods. "Today" = 6am–6pm, "Tonight" = 6pm–6am. Sunrise/sunset used for day/night VOCABULARY selection only (e.g., "Sunny" vs "Clear"), not period boundaries. | User directive 2026-07-05 |
| 2 | **Branding:** "NWS GFE Text Generation System with WorldCast Technology" in documentation. Not a legal brand. | User directive 2026-07-05 |
| 3 | **SkyPyEye Technology:** Rebrand "CAELUS" → "SkyPyEye Technology" for the pyranometer sky classification system across all active code and docs. | User directive 2026-07-05 |
| 4 | **i18n:** Extend existing locale JSON + composer module system. Incorporate GFE `Translator.py` gender/number classification for Romance languages (fr, es, it, pt-PT, pt-BR). Template mode (9 locales) + Custom mode (ja, zh-CN, zh-TW). | User directive 2026-07-05 |
| 5 | **Marine:** Build GFE §17 threshold tables and phrase templates only. Do NOT build marine provider modules. | User directive 2026-07-05 |
| 6 | **Fire weather:** Tiered. Tier 1 (now): Humidity Recovery + LAL heuristic — uses data we already have. Tier 2 (provider expansion): Haines Index — requires Open-Meteo pressure-level variables. Tier 3 (provider expansion): Smoke Dispersal/VentRate — requires boundary layer height + pressure-level wind. Build ALL threshold tables now; what activates depends on available data. | User directive 2026-07-05 |
| 7 | **NWS pass-through:** NWS provider → use `detailedForecast` directly. English only. Engine not invoked. NWS does not provide the granular hourly data needed to run through this system. | User directive 2026-07-05 |
| 8 | **Forecast verbosity:** One level (matching GFE's single narrative product per period). Current observations keep three tiers (terse/standard/verbose). | User directive 2026-07-05 |
| 9 | **GFE code reuse:** Port GFE algorithms faithfully. Study GFE source files. Replicate structure. Don't reinvent. | User directive 2026-07-05 |
| 10 | **WU removal:** Phase 0 prerequisite. Provider has insufficient data quality to remain. | User directive 2026-07-05 |
| 11 | **Hybrid wind scale:** Below 30 mph: Beaufort labels (Calm through Strong Breeze). At 30 mph+: GFE/NWS descriptors (Windy through Hurricane Force Winds). Beaufort "Hurricane" label is wrong for non-tropical high winds. Applies to both current conditions and forecast. Gust phrasing upgrades from "and Gusty" to GFE's "with gusts to around X mph." | User directive 2026-07-05 |
| 12 | **Current-conditions preservation:** SkyPyEye 7-level classification, temperature-comfort 2D matrix, sensor-based precipitation (rain gauge + Stull wet-bulb), haze/fog detection, input stability (smoothing/hysteresis/hold time), current composition pattern, provider deferral — ALL preserved. GFE engine does NOT replace these. See ADR-082 settled decision #12 for the full preservation table and implementation safety rule. | User directive 2026-07-05 |

---

## 2. Provider Data Inventory — Forecast Text Engine Inputs

This table documents what each provider currently supplies for text generation inputs. The text engine must handle missing fields gracefully — NWS hourly is the sparsest.

### Hourly forecast fields

| Field | Xweather | NWS | Open-Meteo | OWM | Text engine use |
|-------|----------|-----|------------|-----|-----------------|
| `outTemp` | Y | Y | Y | Y | Temperature phrases |
| `outHumidity` | Y | — | Y | Y | Fire weather (humidity recovery) |
| `windSpeed` | Y | Y | Y | Y | Wind phrases |
| `windDir` | Y | Y | Y | Y | Wind direction phrases |
| `windGust` | Y | — | Y | Y | Gust phrases (> sustained + 10 mph) |
| `precipProbability` | Y | Y | Y | Y | PoP qualification |
| `precipAmount` | Y | — | Y | Y | Coverage language, snow accumulation |
| `precipType` | Y | Y | Y | Y | Weather type phrases |
| `cloudCover` | Y | — | Y | Y | Sky phrases (6-bucket table) |
| `weatherCode` | Y | Y | Y | Y | Weather type hierarchy, LAL heuristic |
| `weatherText` | Y | Y | Y | Y | Fallback when engine can't generate |
| `feelsLike` | Y | — | Y | Y | Extreme temperature descriptors (heat index / wind chill) |

### Daily forecast fields

| Field | Xweather | NWS | Open-Meteo | OWM | Text engine use |
|-------|----------|-----|------------|-----|-----------------|
| `tempMax` / `tempMin` | Y | Y | Y | Y | Temperature decade phrasing |
| `precipProbabilityMax` | Y | Y | Y | Y | PoP gating |
| `windSpeedMax` | Y | Y | Y | Y | Wind descriptor (breezy/windy) |
| `windGustMax` | Y | — | Y | Y | Gust phrases |
| `snowAmount` | Y | — | Y | Y | Snow accumulation phrases |
| `iceAccumulation` | Y | — | — | — | Ice accumulation phrases |
| `humidityMax` / `humidityMin` | Y | — | Y | Y/— | Fire: humidity recovery |
| `sunrise` / `sunset` | Y | Skyfield | Y | Y | Day/night vocabulary selection |
| `narrative` | Y | Y (detailedForecast) | — | Y | NWS pass-through |
| `thunderRisk` | Y | — | — | — | LAL heuristic (Xweather only) |

### Not available from any provider

- Marine forecast data (wave height, swell, sea temp) — tables built, no provider yet
- Fire weather: mixing height, transport wind, VentRate, Haines Index, LAL (direct) — tables built, pending provider expansion

---

## 3. Gap Inventory

### A. Modules to Build

| New module | Purpose | GFE reference | Location |
|------------|---------|---------------|----------|
| `sse/gfe/__init__.py` | Package init + public API | — | API repo |
| `sse/gfe/thresholds.py` | All GFE threshold tables (sky, temp, wind, weather, PoP, snow/ice, marine, fire) | §1-4, 7, 9-10, 17-18 | API repo |
| `sse/gfe/sky_phrases.py` | Sky coverage phrase generator | §1 (ScalarPhrases.py) | API repo |
| `sse/gfe/temp_phrases.py` | Temperature decade phrasing, exceptions, trends, extreme descriptors | §2 (ScalarPhrases.py) | API repo |
| `sse/gfe/wind_phrases.py` | Wind magnitude, descriptors, gusts, marine wind | §3 (VectorRelatedPhrases.py) | API repo |
| `sse/gfe/wx_phrases.py` | Weather/precip: 24 types, 16 coverages, intensity, conjunctions, PoP | §4 (WxPhrases.py) | API repo |
| `sse/gfe/snow_ice_phrases.py` | Snow/ice accumulation phrasing | §9 | API repo |
| `sse/gfe/marine_phrases.py` | Marine phrase templates (tables only, no provider) | §17 | API repo |
| `sse/gfe/fire_phrases.py` | Fire weather generators (tiered) | §18 (FirePhrases.py) | API repo |
| `sse/gfe/time_descriptors.py` | Period labels + 42-entry sub-period table | §6 (TimeDescriptor.py) | API repo |
| `sse/gfe/connectors.py` | Scalar/vector/weather connector strategies | §5.2 (PhraseBuilder.py) | API repo |
| `sse/gfe/composer.py` | Single-pass composition engine, skyPopWx combined phrase | §5.3, §11 | API repo |
| `sse/forecast_model.py` | ForecastPeriod dataclass (structured input for one day/night period) | — | API repo |
| `sse/period_aggregator.py` | Aggregate hourly provider data into day/night periods | §15 (SampleAnalysis.py) | API repo |
| `sse/forecast_text_enrichment.py` | Enrichment adapter for `/api/v1/forecast` | — | API repo |

### B. Modules to Modify

| Existing module | Change |
|-----------------|--------|
| `sse/enrichment/weather_text.py` | Refactor to input adapter only — delegate generation to `sse/gfe/composer.py` |
| `sse/text_generator.py` | Replace — generation moves to shared engine |
| `sse/conditions_text.py` | Replace — terse composition moves to shared engine |
| `sse/sky_condition.py` | Rebrand CAELUS → SkyPyEye Technology |
| `sse/observation_model.py` | Rebrand + minor extension for engine input |
| `sse/i18n.py` | Add `t_inflected()` for gender/number agreement |
| `sse/locales/en.json` + 12 other locale files | Add forecast phrase templates |
| `sse/locales/composers/ja.py` | Extend for forecast compound expressions |
| `sse/locales/composers/zh.py` | Extend for forecast composition |
| `endpoints/forecast.py` | Wire forecast text enrichment |
| `models/responses.py` | Add forecast text fields + `feelsLike` to `HourlyForecastPoint` + `iceAccumulation` to `DailyForecastPoint` |
| `providers/forecast/aeris.py` | Map `feelslikeF`/`feelslikeC` → `feelsLike`; parse `iceaccumMM`/`iceaccumIN` → `iceAccumulation` |
| `providers/forecast/openmeteo.py` | Add `apparent_temperature` to `_HOURLY_VARS`; map → `feelsLike` |
| `providers/forecast/openweathermap.py` | Map `feels_like` → `feelsLike` |
| `docs/contracts/canonical-data-model.md` | Add `feelsLike` to `HourlyForecastPoint`; add `iceAccumulation` to `DailyForecastPoint` |

### C. Documents to Create/Update

| Document | Change | Phase |
|----------|--------|-------|
| New ADR (next available number) | NWS GFE Text Generation System with WorldCast Technology | Phase 1 |
| `docs/ARCHITECTURE.md` | Update conditions text engine section, add SkyPyEye, add forecast text flow | Phase 1 |
| `docs/manuals/API-MANUAL.md` | New section: Forecast Text Generation; update conditions text engine section | Phase 1 |
| `docs/manuals/PROVIDER-MANUAL.md` | Add NWS pass-through behavior, forecast text field mapping, per-provider data inventory | Phase 1 |
| Per-provider API reference docs | Add forecast field inventory to each provider's reference doc in `docs/reference/api-docs/` | Phase 1 |

### D. Files to Remove

| Category | Scope |
|----------|-------|
| WU provider module + tests + fixtures | `providers/forecast/wunderground.py`, tests, fixtures directory |
| WU references in API repo | endpoints, dispatch, config, docs (~12 files) |
| WU references in meta repo | PROVIDER-MANUAL, ARCHITECTURE.md, canonical-data-model, api-docs |
| `sse/text_generator.py` | Replaced by shared engine (Phase 8) |
| `sse/conditions_text.py` | Replaced by shared engine (Phase 8) |

---

## 4. Implementation Phases

### PHASE 0 — Prerequisites (WU Removal + SkyPyEye Rebrand)

Must complete before any engine work begins.

**T0.1 — Remove Weather Underground provider module**
- Owner: `clearskies-api-dev` (Sonnet)
- Files to delete: `providers/forecast/wunderground.py`, test files, `tests/fixtures/providers/wunderground/`
- Files to modify: `endpoints/forecast.py`, `endpoints/setup.py`, `providers/_common/dispatch.py`, `config/settings.py`, `__main__.py`, `correction/collector.py`, test files referencing WU
- Do: Delete all WU-specific code and test fixtures. Remove imports, registration, dispatch branches, credential wiring, env var declarations. Ensure remaining providers (NWS, Open-Meteo, Xweather, OWM) continue to function.
- Accept: `ruff check` passes. `grep -rn "wunderground\|Weather Underground" weewx_clearskies_api/ tests/` returns zero (excluding CHANGELOG). Existing forecast provider tests pass.

**T0.2 — Remove WU references from documentation**
- Owner: `clearskies-docs-author` (Sonnet)
- Files to modify: API repo docs (README, CONFIG, ADDITIONAL-USES), meta repo docs (PROVIDER-MANUAL, ARCHITECTURE.md, canonical-data-model, api-docs)
- Do: Remove WU from all active docs. Archive `docs/reference/api-docs/wunderground.md` to `docs/archive/reference/`. Update provider counts. CHANGELOG entries are historical and stay.
- Accept: `grep -rn "wunderground\|Weather Underground" docs/manuals/ docs/ARCHITECTURE.md docs/contracts/` returns zero.

**T0.3 — Rebrand CAELUS to SkyPyEye Technology**
- Owner: `clearskies-api-dev` (Sonnet)
- API repo files: `sse/sky_condition.py` (~7 refs), `sse/text_generator.py` (~2), `sse/observation_model.py` (~5), `tests/test_sky_condition.py` (~3)
- Meta repo files: `docs/ARCHITECTURE.md` (~3), `docs/manuals/API-MANUAL.md` (~6), `docs/manuals/OPERATIONS-MANUAL.md` (~2)
- Do: Replace "CAELUS" with "SkyPyEye Technology" in comments, docstrings, and docs. Review `caelus` variable names — rename to `skypyeye` or neutral names if internal-only. Do NOT rename in `docs/archive/` or `docs/research/` (historical).
- Accept: `grep -rn "CAELUS\|caelus"` across active code/docs returns zero. All sky_condition tests pass.

**QC Gate 0 (Opus):** Full test suite. Zero WU refs in active code/docs. Zero CAELUS refs in active code/docs. All 4 remaining forecast providers register correctly.

**QC Gate 0 — PASSED (2026-07-05).** Evidence:
- `grep -rni "wunderground|weather underground" weewx_clearskies_api/ tests/` → zero matches (EXIT 1)
- `grep -rni "wunderground|weather underground" docs/manuals/ docs/ARCHITECTURE.md docs/contracts/ docs/INDEX.md` → zero matches (EXIT 1)
- `grep -rni "caelus"` with unqualified filter → zero unqualified refs in source and docs (remaining hits all qualified as "CAELUS library" / "CAELUS research library")
- Forecast `valid_providers`: `{"openmeteo", "nws", "aeris", "openweathermap"}` — 4 providers, no WU
- Dispatch registry: 4 forecast entries, no WU
- `ruff check`: zero new lint errors (685→677, delta from deleted WU files only)
- `pytest tests/test_sky_condition.py`: 56 passed
- Commits: API repo `6ddfa33`, `31627cf`, `2a05961`; meta repo `e69ce0d`, `fe182ef`

---

### PHASE 1 — ADR + Governing Document Updates

Establishes the implementation authority. Must complete before code implementation begins.

**T1.1 — Draft ADR for unified text generation engine**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/decisions/ADR-{next}-unified-text-generation-engine.md`
- Do: Nygard format, status `Proposed`. Cover all 12 settled decisions. Options: (A) unified GFE-derived engine [chosen], (B) separate current/forecast engines, (C) LLM-generated text.
- Accept: Follows Nygard format. All 12 decisions reflected. **DONE** — ADR-082 Accepted 2026-07-05.

**T1.2 — Update API-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Do: Add "Forecast Text Generation" section. Cover: engine architecture, period convention (6am/6pm, sunrise/sunset for vocabulary only), NWS pass-through, GFE threshold tables, phrase generator inventory, composition engine, WorldCast i18n, forecast verbosity (one level), current observation verbosity (three tiers), compute/memory strategy, SkyPyEye Technology. Update existing conditions text engine section.
- Accept: New section complete. All 12 settled decisions documented as prescriptive rules. Current-conditions preservation directive in §15.

**T1.3 — Update ARCHITECTURE.md and PROVIDER-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Do: ARCHITECTURE.md — update conditions text engine section for unified engine, add `sse/gfe/` to module inventory, add vocabulary table entry for "NWS GFE Text Generation System with WorldCast Technology" and "SkyPyEye Technology". PROVIDER-MANUAL — add NWS pass-through rule, forecast text field mapping.
- Accept: Architecture doc current. Provider manual has NWS pass-through documented.

**T1.4 — Document per-provider forecast data inventory**
- Owner: `clearskies-docs-author` (Sonnet)
- Files to modify: `docs/manuals/PROVIDER-MANUAL.md`, `docs/reference/api-docs/aeris.md`, `docs/reference/api-docs/nws.md`, `docs/reference/api-docs/openmeteo.md`, `docs/reference/api-docs/openweathermap.md`
- Do: (a) Add a cross-provider forecast field comparison matrix to PROVIDER-MANUAL.md showing what each provider supplies for hourly and daily forecast fields (use the inventory from §2 of this plan). Include columns for field name, Xweather, NWS, Open-Meteo, OWM, and a notes column explaining gaps (e.g., "NWS hourly: cloudCover requires raw gridpoints endpoint, not currently fetched"). (b) Add a "Forecast Fields Supplied" section to each provider's API reference doc listing exactly which canonical forecast fields that provider populates, which it does not, and the wire-format source field for each. (c) Document fire weather data availability: which providers have partial data (humidity, thunderstorm codes), which have data available but not yet fetched (Open-Meteo pressure-level, boundary_layer_height, CAPE, lightning_potential), and which provider endpoints exist but have no module yet (Xweather `/maritime`, `/tides`). (d) Document Open-Meteo marine weather API availability for future reference.
- Accept: PROVIDER-MANUAL has complete cross-provider matrix. Each provider API reference doc has a "Forecast Fields Supplied" section. Fire weather data gaps documented. Xweather maritime endpoint documented for future work.

**QC Gate 1 (Opus):** Read all updated docs. Internal consistency. All 12 decisions documented. ADR is `Accepted`. No manual contradicts the brief. Provider data inventory verified against the actual provider module code (coordinator reads each provider module to confirm the docs match reality). Preservation directive present in API-MANUAL §15.

---

### PHASE 2 — Threshold Tables + Data Models

Bottom of the dependency stack. Data structures only, no text generation logic.

**T2.1 — Create GFE threshold tables module**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `sse/gfe/__init__.py`, `sse/gfe/thresholds.py`
- GFE source to study: `gfe-source-code-analysis.md` §1-4, §7, §9-10, §17-18
- Do: Port ALL GFE threshold tables as Python constants. Must include: (1) sky coverage 6-bucket table with day/night labels + similar-sky-words lists, (2) temperature decade boundaries + position names + exception table, (3) wind null=5mph, descriptors 25/30/40/50/74 mph, gust=sustained+10, (4) 24 weather types + 16 coverages + 4 intensities, (5) PoP lower 15%/25%, wx lower 20% + PoP-to-coverage derivation table (ADR-082: PoP range → coverage term, split by PoP-related vs areal weather types), (6) snow/ice accumulation tiers, (7) marine wave heights (10 ranges), chop (7 categories), marine wind 34/45/64 kt, (8) fire: smoke dispersal (5), Haines (4), humidity recovery (4), LAL (6). All tables are language-independent data — display strings resolve through locale files.
- Accept: Every threshold value matches the GFE source code analysis exactly. `ruff check` and `mypy` pass.

**T2.2 — Create forecast period model**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/forecast_model.py`
- Do: `ForecastPeriod` dataclass analogous to `Observation`. Fields: `period_label` (str), `is_daytime` (bool), `temp_high`/`temp_low` (float|None), `sky_label` (str), `sky_percent` (float|None 0-100), `pop` (float|None 0-100), `precip_type` (str|None), `precip_coverage` (str|None — derived from pop per PoP-to-coverage table in ADR-082), `wind_speed_min`/`wind_speed_max` (float|None), `wind_gust` (float|None), `wind_direction` (float|None), `weather_codes` (list[str]), `snow_amount` (float|None), `ice_accumulation` (float|None — inches, from Xweather daily), `humidity_max`/`humidity_min` (float|None), `feels_like_max`/`feels_like_min` (float|None — from hourly feelsLike), `thunder_risk` (float|None), `temp_trend` (str|None — "falling"/"rising"/None, computed during aggregation).
- Accept: Dataclass instantiates. Type annotations correct. `mypy` passes.

**T2.4 — Add `feelsLike` to `HourlyForecastPoint` and `iceAccumulation` to `DailyForecastPoint`**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `models/responses.py`, `docs/contracts/canonical-data-model.md`
- Do: (a) Add `feelsLike: float | None = None` to `HourlyForecastPoint`. (b) Add `iceAccumulation: float | None = None` to `DailyForecastPoint`. (c) Update canonical data model doc to include both fields.
- Accept: Both fields present in response models. Canonical data model updated. `mypy` passes.

**T2.5 — Map `feelsLike` and `iceAccumulation` in provider modules**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `providers/forecast/aeris.py`, `providers/forecast/openmeteo.py`, `providers/forecast/openweathermap.py`
- Do: (a) Xweather: map `feelslikeF`/`feelslikeC` → `feelsLike` on hourly; parse `iceaccumMM`/`iceaccumIN` → `iceAccumulation` on daily. (b) Open-Meteo: add `apparent_temperature` to `_HOURLY_VARS`; map → `feelsLike`. (c) OWM: map hourly `feels_like` → `feelsLike`. NWS does not supply either field — no change needed.
- Accept: Xweather, Open-Meteo, OWM hourly responses include `feelsLike`. Xweather daily responses include `iceAccumulation`. Existing provider tests pass. `ruff check` passes.

**T2.3 — Threshold tables unit tests**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_gfe_thresholds.py`
- Do: Test every table for correct values. Spot-check critical boundaries: sky 5/25/50/69/87%, wind calm <5, gust >sustained+10, PoP lower 15%, temperature decade digit 0-3/4-6/7-9. Verify marine wave table=10 entries, fire smoke=5 categories, LAL=6 levels.
- Accept: All tests pass. Full coverage of every table.

**QC Gate 2 (Opus):** Cross-check every threshold in `thresholds.py` against the GFE source document. Flag any mismatch. Run tests.

---

### PHASE 3 — Period Aggregation

Depends on Phase 2 (forecast model).

**T3.1 — Create period aggregator**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: `gfe-source-code-analysis.md` §15 (SampleAnalysis data sampling)
- File: `sse/period_aggregator.py`
- Do: Aggregate `HourlyForecastPoint` list into `ForecastPeriod` list. Period boundaries: 6am/6pm local time (NWS convention). Use sunrise/sunset for `is_daytime` flag only. Aggregation: temp_high=max(outTemp) for day, temp_low=min(outTemp) for night; sky_percent=mean(cloudCover), sky_label from 6-bucket table; pop=max(precipProbability); precip_type=mode(precipType); precip_coverage=derived from pop per PoP-to-coverage table (ADR-082); wind range from windSpeed; wind_gust=max(windGust); wind_direction=mode(windDir, 8-point compass); weather_codes=union(weatherCode); snow_amount=sum where precip_type=snow; humidity from outHumidity; feels_like_max=max(feelsLike), feels_like_min=min(feelsLike); thunder_risk from thunderRisk or weather code heuristic; temp_trend=compare latter-half hourly outTemp vs period extreme, >20°F diff → "falling"/"rising", else None. Generate period labels: Today/Tonight, Tomorrow/Tomorrow Night, weekday names.
- Accept: 72 hourly points → 6 ForecastPeriod instances with correct labels. Day=6am-6pm, Night=6pm-6am. None handling graceful.

**T3.2 — Period aggregator tests**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_period_aggregator.py`
- Do: Synthetic hourly data tests: correct splitting at 6am/6pm, correct day/night labels, statistical aggregation, period label generation, edge cases (missing data, all-None, single-hour periods, DST).
- Accept: All tests pass.

**QC Gate 3 (Opus):** Review aggregation against GFE §15. Verify 6am/6pm boundaries. Run tests.

---

### PHASE 4 — Phrase Generators

Depends on Phase 2 (thresholds). Five independent generators — can be built in parallel.

**T4.1 — Sky phrase generator**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: `gfe-source-code-analysis.md` §1 (ScalarPhrases sky coverage)
- File: `sse/gfe/sky_phrases.py`
- Do: `sky_phrase(sky_percent, is_daytime, locale)` using 6-bucket table. `sky_trend_phrase()` for adjacent-transition suppression. `sky_pop_suppression()` (omit sky when PoP >= 55%). All output through `i18n.t()`.
- Accept: `sky_phrase(30, True, "en")` → "Mostly Sunny". `sky_phrase(30, False, "en")` → "Partly Cloudy". Adjacent suppression works.

**T4.2 — Temperature phrase generator**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: `gfe-source-code-analysis.md` §2 (ScalarPhrases temperature)
- File: `sse/gfe/temp_phrases.py`
- Do: Full GFE algorithm: (1) exception table, (2) spread >4°F → "X to Y", (3) decade + position (lower/mid/upper), (4) zero-crossing, teens, single digits, sub-zero. `temp_descriptor()` for extremes. `temp_trend_phrase()` for falling/rising. All through locale files.
- Accept: `temp_phrase(83, 89, True, "en")` → "in the 80s". Decade, zero-crossing, teens all correct.

**T4.3 — Wind phrase generator**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: `gfe-source-code-analysis.md` §3 (VectorRelatedPhrases, 1564 lines)
- File: `sse/gfe/wind_phrases.py`
- Do: Implement the hybrid Beaufort/GFE wind scale (settled decision #11). Below 30 mph: Beaufort labels (Calm, Very Light Breeze, Light Breeze, Gentle Breeze, Moderate Breeze, Fresh Breeze, Strong Breeze). At 30 mph+: GFE descriptors (Windy, Very Windy, Strong Winds, Hurricane Force Winds). Forecast magnitude phrasing: <5=null("light winds"), min==max="around X", min<null="up to X", else range. Gusts only when >sustained+10, phrase: "with gusts to around X mph". Marine wind: gales/storm force/hurricane force at 34/45/64 kt.
- Accept: Hybrid scale produces Beaufort labels below 30 mph and GFE labels at 30+. No "Hurricane" label at Beaufort 12 — must be "Hurricane Force Winds." Gust suppression correct. Marine descriptors correct.

**T4.4 — Weather/precipitation phrase generator**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: `gfe-source-code-analysis.md` §4 (WxPhrases, 1943 lines), §10 (PoP), §11 (skyPopWx)
- File: `sse/gfe/wx_phrases.py`
- Do: 24 types in priority order, 16 coverage levels, 4 intensity codes. Conjunctions: "and"/"with"/"or"/"mixed with"/"with possible". Serial comma for 3+. PoP qualification. Heavy/severe detection. Visibility phrases.
- Accept: Coverage terms correct for all 16 levels. Conjunctions natural. Serial comma applied.

**T4.5 — Snow/ice + time descriptors + connectors**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: §9 (snow/ice), §6 (TimeDescriptor, 761 lines), §5.2 (connectors)
- Files: `sse/gfe/snow_ice_phrases.py`, `sse/gfe/time_descriptors.py`, `sse/gfe/connectors.py`
- Do: Snow: PoP>=60% gate, accumulation tiers (<0.5"/"little or no"/<3"/range). Ice: fractional-inch. Time: period labels (Today/Tonight/weekday), 42-entry sub-period table, timing connectors. Connectors: scalar ("then"/"increasing to"), vector ("shifting to the"/"becoming"), weather (". "/, then").
- Accept: Snow thresholds match GFE. All 42 sub-period descriptors present. Connector strategies element-aware.

**T4.6 — Marine + fire weather phrases**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: §17 (marine), §18 (FirePhrases, ~540 lines)
- Files: `sse/gfe/marine_phrases.py`, `sse/gfe/fire_phrases.py`
- Do: Marine (tables only, no provider): wave height (10 ranges), chop (7 categories), marine wind descriptors. Fire (tiered): Tier 1 (active): humidity recovery (4 categories), LAL heuristic from weather codes + coverage. Tier 2/3 (tables built, activates with data): Haines (4 levels), smoke dispersal (5 categories).
- Accept: Marine tables complete. Fire Tier 1 works with available data. Tier 2/3 functions accept data but are not wired to providers.

**T4.7 — Phrase generator unit tests**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: One test file per generator module
- Do: Comprehensive tests covering boundaries, edge cases, locale resolution, None handling. Each generator has at least 10 test cases.
- Accept: All tests pass.

**QC Gate 4 (Opus):** Review each generator against its GFE source section. Verify all output through `i18n.t()`. Run full test suite.

---

### PHASE 5 — Composition Engine

Depends on Phase 4 (phrase generators).

**T5.1 — Composition engine**
- Owner: `clearskies-api-dev` (Sonnet)
- GFE source to study: §5.3 (assembleSubPhrases), §11 (skyPopWx), §5.1 (pipeline overview)
- File: `sse/gfe/composer.py`
- Do: Primary entry: `compose_forecast_text(period: ForecastPeriod, locale: str) -> str`. Single-pass sequential (NOT GFE tree traversal — simplified for single-station). Assembly order: period label + colon, sky, temperature, wind, precipitation/weather. `compose_skyPopWx()` for combined sky+PoP+weather pattern. Serial comma. Sentence assembly with capitalization/punctuation. `compose_current_text(obs: Observation, verbosity: str, locale: str) -> str` for current observations (terse/standard/verbose). NWS pass-through: when source == "nws", return `detailedForecast` unchanged.
- Accept: ForecastPeriod with all fields → NWS-style text. Observation → text at all three verbosity levels. NWS pass-through works.

**T5.2 — GFE package public API**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/gfe/__init__.py`
- Do: Export: `generate_forecast_text(period, locale)`, `generate_current_text(obs, verbosity, locale)`, `aggregate_periods(hourly_data, sunrise, sunset, current_time, timezone, locale)`. Module-level `configure(unit_system)` for unit setup.
- Accept: `from sse.gfe import generate_forecast_text` works.

**T5.3 — Composition engine tests**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_gfe_composer.py`
- Do: Full period, missing elements, skyPopWx, NWS pass-through, serial comma, all three current-obs verbosity levels, period labels, sentence assembly. Regression tests against NWS-style examples from the brief.
- Accept: All tests pass. Output matches NWS conventions.

**QC Gate 5 (Opus):** Compare generated text against real NWS Zone Forecast Products. Verify assembly patterns. Run tests.

---

### PHASE 6 — WorldCast i18n Extension

Depends on Phase 4 (phrase generators produce the keys that need translation).

**T6.1 — English locale: forecast phrase keys**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/locales/en.json`
- Do: Add all keys for: period labels, temperature decades, wind descriptors, all 16 coverage terms, intensity terms, conjunction words, 42 sub-period descriptors, marine descriptors, fire weather descriptors, snow/ice phrases. Use GFE English wording as values.
- Accept: No `i18n.t()` call returns a raw key when locale is "en".

**T6.2 — Template-mode locales (9 locales)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `sse/locales/{de,es,fr,it,nl,pt-BR,pt-PT,ru,fil}.json`
- Do: Add all forecast keys with translations verified against `international-forecast-text-patterns.md`. For Romance languages (es, fr, it, pt-BR, pt-PT), add gender-coded coverage/intensity forms: each weather type gets a gender code (MS/MP/FS/FP), each adjective gets 4 inflected forms. For Russian, add case-inflected forms (nominative/instrumental/genitive). Filipino uses English (PAGASA convention). German/Dutch follow DWD/KNMI conventions.
- Accept: All 9 locales have complete forecast key sets. No empty values. Romance gender forms present. Russian case inflection present.

**T6.3 — Custom-mode locales (3 locales)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `sse/locales/{ja,zh-CN,zh-TW}.json`
- Do: Forecast keys using JMA conventions (Japanese), CMA/CWA conventions (Chinese). Period labels, weather types, wind grades, temperature vocabulary.
- Accept: Japanese uses JMA vocabulary. Chinese uses CMA/CWA vocabulary.

**T6.4 — Gender/number inflection in i18n module**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/i18n.py`
- GFE source to study: `gfe-source-code-analysis.md` §14 (Translator, ~460 lines)
- Do: Add `t_inflected(key, gender_code, locale)`. When value at key is a dict of gender_code → string, returns the matching form. When plain string, returns unchanged. Gender codes: MS/MP/FS/FP. Follows existing `t()` resolution chain.
- Accept: `t_inflected("forecast.coverage.scattered", "FS", "fr")` returns feminine singular French. English returns plain string.

**T6.5 — Extend custom composers for forecast**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `sse/locales/composers/ja.py`, `sse/locales/composers/zh.py`
- Do: Japanese: `compose_forecast()` producing JMA-style text with temporal operators (tokidoki, ichiji, nochi). Chinese: `compose_forecast()` producing CMA/CWA-style text.
- Accept: Compound expressions correct per international patterns doc.

**T6.6 — i18n extension tests**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_gfe_i18n.py`
- Do: `t_inflected()` with Romance gender codes, fallback for non-gendered languages, Japanese/Chinese forecast composition, Russian case inflection, Filipino pass-through, all 13 locales resolve all forecast keys.
- Accept: All tests pass. All 13 locales produce non-empty strings for all forecast keys.

**QC Gate 6 (Opus):** Spot-check translations against `international-forecast-text-patterns.md`. Verify French/Spanish gender forms. Verify Japanese compound expressions. Run tests.

---

### PHASE 7 — Integration (Wire into API)

Depends on Phases 5 and 6.

**T7.1 — Forecast text enrichment adapter**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/forecast_text_enrichment.py`
- Do: `enrich_forecast_text(bundle, locale)`: if source=="nws", pass through `narrative`/`detailedForecast` unchanged. Otherwise, aggregate hourly data into periods, generate text per period via composer, attach to daily forecast points. Graceful handling of empty hourly data.
- Accept: NWS bundles pass through. Open-Meteo/Xweather/OWM bundles get generated text.

**T7.2 — Refactor weather_text.py to use shared engine**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sse/enrichment/weather_text.py`
- **MANDATORY: Read ADR-082 settled decision #12 (current-conditions preservation directive) before starting.** The preservation table lists every system that MUST survive this refactor. Deleting or replacing preserved systems is a blocking defect.
- Do: Refactor to delegate wind label generation at ≥ 30 mph to GFE descriptors (settled decision #11 — hybrid wind scale). Upgrade gust phrasing from "and Gusty" to GFE's "with gusts to around X mph." Upgrade standard/verbose tiers to use GFE decade phrasing, extreme temperature descriptors, and wind connectors. Retain ALL preserved systems: SkyPyEye 7-level classification (including Overcast/Heavy Overcast), temperature-comfort 2D matrix (terse tier), sensor-based precipitation detection (rain gauge + Stull wet-bulb), haze detection, fog/mist detection, input stability (smoothing, hysteresis, hold time), current-conditions composition pattern, provider weather text deferral. Remove only code that is genuinely replaced: Beaufort labels at ≥ 30 mph, "and Gusty" qualifier, duplicated sky tables that overlap with GFE thresholds. Delete `text_generator.py` and `conditions_text.py` only after verifying all their functionality is either preserved in `weather_text.py` or delegated to the GFE composer.
- Accept: `/api/v1/current` response still has `weatherText`, `weatherTextStandard`, `weatherTextVerbose`, `weatherCode`. Existing tests pass (minor assertion updates OK for improved phrasing). SkyPyEye still produces 7-level output including Overcast/Heavy Overcast. Temperature-comfort matrix still active in terse tier. Rain gauge detection still active. Wind labels at < 30 mph unchanged (Beaufort). Wind labels at ≥ 30 mph use GFE descriptors. Gusts report speed ("with gusts to around X mph").

**T7.3 — Wire forecast enrichment into forecast endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `endpoints/forecast.py`, `models/responses.py`
- Do: Add `forecastText` field to `DailyForecastPoint` response model. Call `enrich_forecast_text()` after fetching bundle. Pass operator locale. Update OpenAPI schema.
- Accept: `/api/v1/forecast` response includes generated text for non-NWS providers. NWS includes pass-through. OpenAPI updated.

**T7.4 — Integration tests**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `tests/test_forecast_text_enrichment.py`, `tests/test_gfe_integration.py`
- Do: End-to-end: synthetic hourly data → enrichment → text output per period. Current observation → text at all verbosity levels. NWS pass-through. Multi-locale (en, de, ja).
- Accept: All tests pass. Text follows NWS conventions.

**QC Gate 7 (Opus):** Full test suite. No regression in existing endpoints. Forecast endpoint has text. OpenAPI schema correct.

---

### PHASE 8 — Verification + Final Documentation Sync

Depends on Phase 7.

**T8.1 — Cross-locale verification**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Generate forecast text in all 13 locales for same synthetic data. Verify: no raw keys, Romance gender agreement, Russian case inflection, Japanese compound expressions, Chinese formatting, Filipino English.
- Accept: All 13 locales produce grammatically plausible text. No raw keys.

**T8.2 — Documentation final sync**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: `docs/manuals/API-MANUAL.md`, `docs/ARCHITECTURE.md`, `docs/manuals/PROVIDER-MANUAL.md`
- Do: Final doc-code sync pass. Update module paths, function signatures, field names. Verify "NWS GFE Text Generation System with WorldCast Technology" branding in appropriate sections.
- Accept: Doc-code sync complete. No stale references.

**T8.3 — Archive ADR**
- Owner: `clearskies-docs-author` (Sonnet)
- Do: After user approval, change ADR status to `Accepted`. Move to `docs/archive/decisions/`. Add "Archived — consolidated into API-MANUAL.md".
- Accept: ADR archived correctly.

**QC Gate 8 (Opus):** Final test suite run. Cross-locale output review. Doc-code sync verified.

---

### PHASE 9 — QA (Quality Assurance of QC)

Depends on Phase 8. This phase verifies the coordinator's QC was done correctly. The QA auditor is independent of the coordinator — it reviews the QC evidence, not the code directly.

**T9.1 — QA audit of QC evidence**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Review the coordinator's QC evidence from scratchpad for every phase. For each phase, verify:
  1. **Coordinator preparation was done** — evidence that the coordinator read the relevant docs and code before QC (cited files, noted observations). If the coordinator QC'd a threshold table without reading the GFE source document, that is a QA finding.
  2. **All four QC dimensions were evaluated** — correctness, best practices, task completion, manual compliance. If any dimension was skipped or rubber-stamped ("looks good"), that is a QA finding.
  3. **Task completion was independently verified** — the coordinator ran the acceptance criteria checks (grep results, test output, file inspections), not just accepted agent self-reports. If the coordinator took the agent's word for test results without running them independently, that is a QA finding.
  4. **Findings were acted on** — any QC findings were remediated or explicitly deferred with user approval. If findings were noted but not tracked, that is a QA finding.
  5. **Manual compliance was checked against actual manual content** — the coordinator read the manual section, not just asserted compliance. If the QC evidence doesn't cite specific manual sections, that is a QA finding.
- Accept: QA report with per-phase pass/fail assessment. Every QA finding includes: which phase, which QC dimension was deficient, what evidence is missing, and what remediation is needed. Zero findings = clean QA. Findings that require remediation block the plan's completion.

**T9.2 — QA audit of GFE fidelity**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Independently spot-check 5 threshold values from `thresholds.py` against the GFE source code analysis document. Independently spot-check 3 phrase generator functions against their GFE source section — trace the logic and verify the algorithm matches. This is a second pair of eyes on the coordinator's Gate B work.
- Accept: All 5 threshold spot-checks match. All 3 phrase generator spot-checks produce correct output per GFE. Any mismatch is a blocking finding.

**T9.3 — QA audit of i18n completeness**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Run `rules/coding.md` §6 FAIL conditions mechanically across the entire `sse/gfe/` package and all modified files. Run the 13-locale key resolution test independently. Spot-check 2 Romance language locales for gender/number forms. This validates the coordinator's Gate C work.
- Accept: Zero i18n FAIL conditions triggered. All 13 locales resolve all keys. Gender/number forms present in spot-checked locales.

**T9.4 — QA audit of provider data documentation**
- Owner: `clearskies-auditor` (Sonnet)
- Do: Open each provider module (`aeris.py`, `nws.py`, `openmeteo.py`, `openweathermap.py`) and compare the CAPABILITY declarations against the provider data inventory in PROVIDER-MANUAL.md. Verify the cross-provider matrix is accurate. Flag any field the manual claims a provider supplies but the code does not parse, or vice versa.
- Accept: Provider manual matrix matches actual provider code. Zero mismatches.

**QA Gate (reported to user):** QA findings compiled into a single report. User reviews before plan is marked complete. If QA finds the QC was insufficient in any phase, that phase's work is re-examined by the coordinator.

---

## 5. Agent Assignments

| Phase | Task | Owner | QC (Opus) | QC Timing |
|-------|------|-------|-----------|-----------|
| 0 | T0.1 WU removal (code) | `clearskies-api-dev` | Grep verification | After Phase 0 |
| 0 | T0.2 WU removal (docs) | `clearskies-docs-author` | Grep verification | After Phase 0 |
| 0 | T0.3 SkyPyEye rebrand | `clearskies-api-dev` | Grep verification + test run | After Phase 0 |
| 1 | T1.1-T1.3 ADR + manual updates | `clearskies-docs-author` | Content review vs settled decisions | After Phase 1 |
| 1 | T1.4 Provider data inventory docs | `clearskies-docs-author` | Cross-check vs provider module code | After Phase 1 |
| 2 | T2.1-T2.3 Threshold tables + model | `clearskies-api-dev` | Cross-check vs GFE source | After Phase 2 |
| 3 | T3.1-T3.2 Period aggregation | `clearskies-api-dev` | Review vs GFE §15 | After Phase 3 |
| 4 | T4.1-T4.7 Phrase generators | `clearskies-api-dev` | Review each vs GFE section | After Phase 4 |
| 5 | T5.1-T5.3 Composition engine | `clearskies-api-dev` | Compare output vs NWS ZFP | After Phase 5 |
| 6 | T6.1-T6.6 WorldCast i18n | `clearskies-api-dev` | Spot-check translations | After Phase 6 |
| 7 | T7.1-T7.4 Integration | `clearskies-api-dev` | Full regression test | After Phase 7 |
| 8 | T8.1-T8.3 Verification + docs | Both | Final sign-off | After Phase 8 |
| 9 | T9.1-T9.4 QA audit | `clearskies-auditor` | N/A (QA audits the QC) | After Phase 8 QC |

**Sequencing:**
- Phase 0 (prerequisites) → Phase 1 (ADR + docs + provider inventory)
- Phase 2 (tables + model) → Phase 3 (aggregation) → Phase 5 (composition)
- Phase 2 (tables) → Phase 4 (phrase generators) → Phase 5 (composition)
- Phase 4 (generators) → Phase 6 (i18n)
- Phases 5 + 6 → Phase 7 (integration) → Phase 8 (verification) → Phase 9 (QA)
- Phases 4.1-4.4 can run in parallel (independent generators)

---

## 6. QC Gates

Every QC gate evaluates the four mandatory dimensions (see Orientation §"QC criteria"). The gates below add domain-specific checks on top.

### Gate A — Code Quality (every phase)
- `ruff check` passes
- `mypy` passes (or no introduced errors)
- All existing tests pass (no regressions)
- No dead code, no hardcoded values that should be configurable, no unused imports
- Type hints on all new functions

### Gate B — GFE Fidelity (Phases 2, 4, 5)
- Coordinator reads the GFE source code analysis sections cited in the phase's tasks
- Every threshold value cross-checked against `gfe-source-code-analysis.md` — mismatches are blockers
- Phrase generator output compared against GFE source algorithms (trace logic path)
- Generated text compared against real NWS Zone Forecast Products

### Gate C — i18n Compliance (Phases 6, 8)
- All 13 locales resolve all forecast keys (no raw keys in output)
- Romance language gender/number forms present and correct
- Translations verified against `international-forecast-text-patterns.md`
- `rules/coding.md` §6 FAIL conditions run mechanically:
  - `grep` for hardcoded English strings in phrase generators
  - `grep` for hardcoded locale strings (`'en-US'`, `'en'`)
  - `grep` for `.toFixed()` in display contexts
  - `grep` for Python `%` formatting in display output

### Gate D — Task Completion (every phase)
- Walk each task's "Do" list item by item — every item has a corresponding deliverable
- Walk each task's "Accept" criteria — every criterion is met with evidence (test output, grep result, file exists)
- No task is marked complete on self-attestation alone — coordinator independently verifies

### Gate E — Manual Compliance (every phase)
- Coordinator reads the governing manual sections relevant to the phase
- Code changes comply with prescriptive rules in the manual
- Any behavior change that affects a manual is reflected in a manual update (doc-code sync)
- ARCHITECTURE.md reflects implemented module structure
- PROVIDER-MANUAL.md provider data inventory matches actual provider code

### Gate F — Best Practices (every phase)
- Code follows `rules/coding.md` — security, readability, organization, DRY
- Single responsibility — no mega-functions, no files over ~500 lines
- Error handling at trust boundaries only, not defensive everywhere
- Naming describes intent, not implementation

---

## 7. Self-Audit

| Risk | Severity | Mitigation |
|------|----------|------------|
| GFE threshold values copied incorrectly | High | QC Gate 2 cross-checks every value. Separate test suite per table. |
| Romance gender/number agreement grammatically wrong | Medium | Verified against international patterns doc. Native speaker review recommended before v1 release (out of scope). |
| Period aggregation edge cases at DST transitions | Medium | DST test case in T3.2. Boundaries in local time — DST shifts UTC boundary, not local. |
| Refactoring `weather_text.py` breaks `/current` output | High | Existing tests must pass. QC Gate verifies no regression. Refactor is incremental — detection stays, generation moves. |
| NWS pass-through assumes `detailedForecast` always present | Low | NWS provider already normalizes this. Null check in T7.1. |
| i18n key explosion (~300 new keys × 13 locales) | Medium | Structured key hierarchy. T6.6 tests all keys resolve. |
| Marine/fire tables built but never activated | Low (by design) | Tables are stable data. Costs little. Prevents re-reading GFE sections later. Documented as "tables only, no provider" in ADR. |
| Unit system: GFE thresholds in US units, operators may use metric | Medium | Generators compare in US units, convert for display (same pattern as existing code). Tested explicitly. |
| `conditions_text.py` deletion breaks external consumers | Medium | T7.2 searches for imports before deleting. Deprecation shims if needed. |
| Scope creep into dashboard or provider modules | Low | Brief explicit: engine only. QC gates enforce boundary. |
| Coordinator rubber-stamps QC without reading docs/code | High | QA Phase 9 independently audits QC evidence. Coordinator must cite specific files read and observations made. |
| Provider data docs drift from actual provider code | Medium | T1.4 documents current state. T9.4 independently cross-checks docs against code. Provider module changes trigger doc updates per doc-code sync rule. |
