# Plan: Conditions Engine Overhaul & Barometer Trend (Revised 2026-05-28)

## Context

Two visible bugs on the live site prompted this work:
1. Current conditions text shows only "Light Air" for extended periods — the sky condition uses a broken single-reading approach (ADR-044's 30-minute sliding window was never implemented), there's no temperature descriptor, and provider cloud cover isn't reliably populating at night.
2. Barometer always says "steady" — `barometerTrend` is never computed anywhere, arrives as `null`, dashboard renders null as "steady."

**Revision context (2026-05-28):** A previous session committed 14 commits to `origin/main` of `weewx-clearskies-realtime` from a worktree, bypassing the local checkout. Today's dev agent pulled and merged that code without asking. The local repo now contains unapproved May 26 code mixed with today's agent code. This revision reconciles it all against the original 9-task plan.

Process rules to prevent recurrence have been written to `CLAUDE.md` (Git safety section) and `rules/clearskies-process.md` (Pre-flight verification).

**Input stability design:** All conditions engine inputs (temperature, dewpoint, wind, rain) must be smoothed before threshold comparison to prevent the conditions text from bouncing every few seconds as raw loop packet values oscillate across tier boundaries. Three mechanisms:
1. **Smoothed inputs** — ring buffers for every conditions input (same pattern as sky kc and UV)
2. **Hysteresis** — once a tier is established, require crossing 2°F / 2 mph past the boundary before switching
3. **Minimum hold time** — conditions text holds for 5 minutes minimum before allowing change (backup mechanism)

Input smoothing windows:

| Input | Buffer window | Samples (~5s interval) | Rationale |
|---|---|---|---|
| Solar radiation (kc) | 30 min | 400 | ADR-044 spec — sky conditions change slowly |
| UV | 10 min | 120 | Cloud-pass noise |
| appTemp | 10 min | 120 | Temperature doesn't legitimately change 5°F in seconds |
| dewpoint | 10 min | 120 | Same |
| outTemp (for depression calc) | 10 min | 120 | Paired with dewpoint |
| windSpeed | 5 min | 60 | Wind is legitimately gusty — shorter window |
| windGust | 5 min | 60 | Same |
| rainRate | 2 min | 24 | Rain onset/cessation should register quickly |
| heatindex | 10 min | 120 | Follows temperature |
| windchill | 10 min | 120 | Follows temperature + wind |

Hysteresis: ±2°F on all temperature thresholds, ±2 mph on wind thresholds, ±2°F on dewpoint thresholds, ±0.02 in/hr on rain rate thresholds. Once a tier is entered, the value must cross this far past the opposite boundary to leave it.

Minimum hold: conditions text string is cached and reused for 5 minutes. If all smoothed+hysteresis inputs still produce the same text, it updates. If they differ, the new text replaces after the hold expires. This prevents rapid flipping even if smoothing and hysteresis don't fully eliminate it.

---

## Code Audit Summary (2026-05-28)

The local repo contains May 26 unapproved code + today's agent code. Audit results:

| Module | Verdict |
|--------|---------|
| `proxy.py` — module-level proxy + unit conversion | **Keep.** Works, tested. |
| `proxy.py` — `create_proxy_router()` factory | **Remove.** Dead code, never called in production. |
| `proxy.py` — `register_enrichment()` + `_run_enrichments()` | **Keep.** Works E2E, tested (1.9-1.11). |
| `enrichment/ring_buffer.py` | **Keep.** Clean, tested (1.18-1.22). |
| `enrichment/packet_tap.py` | **Keep.** Wired but zero processors registered yet. |
| `units/` package | **Keep.** Functional. Beaufort 1 needs rename (Task 6). |
| `sky_condition.py` | **Keep + fix.** Classification passes. Night handling (4.8) and sunset clear (4.12) fail. |
| `conditions_text.py` | **Rewrite comfort section.** 1D dewpoint only — plan requires 2D matrix. Composition function exists but is unwired dead code. |
| `mqtt_fields.py` | **Keep.** Functional. |
| `config/settings.py` | **Keep.** ApiSettings + UnitSettings functional, tested. |

---

## Task 0: Code Cleanup

**Goal:** Remove dead code from proxy.py, consolidate to a single proxy pattern.

**Files to modify:**
| File | Change |
|------|--------|
| `weewx_clearskies_realtime/proxy.py` | Remove `create_proxy_router()` (lines 316-464), `_HOP_BY_HOP_FULL` (lines 60-72), factory docstring paragraph (lines 21-27) |
| `weewx_clearskies_realtime/app.py` | Remove `proxy_router: APIRouter | None = None` parameter from `create_app()`, remove `if proxy_router` block (lines 111-112), remove `APIRouter` import if unused |
| `tests/test_proxy.py` | Remove any test that imports or calls `create_proxy_router`. Keep all tests that exercise the module-level router. |

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 0.1 | `grep -r "create_proxy_router" repos/weewx-clearskies-realtime/` returns 0 matches | grep |
| 0.2 | `grep -r "_HOP_BY_HOP_FULL" repos/weewx-clearskies-realtime/` returns 0 matches | grep |
| 0.3 | `create_app()` signature has no `proxy_router` parameter | code inspection |
| 0.4 | `python -m pytest tests/ -x -q` — all tests pass, 0 failures | test run |

**Agent:** clearskies-realtime-dev

---

## Task 1: BFF REST Proxy + Enrichment Pipeline — VERIFIED

All 22 original acceptance criteria pass after Task 0 cleanup. 293 tests passing at commit `8cf2188`. No further work needed.

| # | Criterion | Status |
|---|---|---|
| 1.1 | GET /current through BFF returns identical JSON (before enrichments) | PASS — test_proxy_forwards_get, test_proxy_observation_envelope_no_transformer |
| 1.2 | GET /archive with query params through BFF returns identical JSON | PASS — test_proxy_forwards_query_params |
| 1.3 | All HTTP methods pass through (GET, POST, PUT, DELETE) | PASS — test_proxy_forwards_post/put/delete |
| 1.4 | Query strings forwarded intact to upstream | PASS — test_proxy_forwards_query_params |
| 1.5 | HTTP 4xx/5xx from upstream forwarded with same status + body | PASS — test_proxy_forwards_400/404/500 |
| 1.6 | Non-JSON responses pass through with correct content-type | PASS — test_proxy_passthrough_non_json |
| 1.7 | Upstream timeout returns 504 | PASS — test_proxy_upstream_timeout |
| 1.8 | Upstream connection refused returns 502 | PASS — test_proxy_upstream_unreachable |
| 1.9 | `register_enrichment("current", fn)` causes fn to run on GET /current | PASS — test_enrichment_runs_on_get_current |
| 1.10 | Enrichment failure caught+logged; response still returned | PASS — test_enrichment_failure_still_returns_response |
| 1.11 | Multiple enrichments on same path run sequentially | PASS — test_multiple_enrichments_run_sequentially |
| 1.12 | `packet_tap.process_packet()` called for every loop packet before SSE broadcast | PASS — test_on_packet_called_before_broadcast |
| 1.13 | Health check includes api_upstream probe | PASS — test_upstream_probe_ok/unhealthy |
| 1.14 | Config [api] parsed correctly | PASS — test_parse_api_section |
| 1.15 | Secret-leak guard rejects [api] api_key | PASS — test_secret_guard_rejects_api_section_key |
| 1.16 | No SSE regression | PASS — 293 passed |
| 1.17 | No health regression | PASS — 293 passed |
| 1.18 | RingBuffer: 400 values → count=400, correct mean/std | PASS — test_ring_buffer_400_values |
| 1.19 | RingBuffer: 500 values → count=400, oldest evicted | PASS — test_ring_buffer_eviction_at_capacity |
| 1.20 | RingBuffer: empty → mean()/std() raise ValueError | PASS — test_ring_buffer_empty_raises |
| 1.21 | RingBuffer: concurrent add() from 2 threads doesn't corrupt | PASS — test_ring_buffer_concurrent_add |
| 1.22 | RingBuffer: clear() resets to empty | PASS — test_ring_buffer_clear |

---

## Task 2: Barometer Trend Computation

**Goal:** BFF enriches GET /current with `barometerTrend` (numeric delta over 3-hour window).

**Design decision:** Make `_run_enrichments()` async so the enrichment function can query the archive endpoint. Current function is sync — change to `async def`, use `await` in `proxy_api()`, use `inspect.isawaitable()` for backward compatibility with sync enrichments.

**Files to create:**
| File | Contents |
|------|----------|
| `weewx_clearskies_realtime/enrichment/barometer_trend.py` | `async def enrich_barometer_trend(data: dict) -> dict` — extracts barometer + timestamp from response, queries `GET /api/v1/archive?to={ts-10800}&limit=1&fields=barometer`, computes delta, injects `barometerTrend` into response. Constants: `TREND_TIME_DELTA=10800`, `TREND_TIME_GRACE=300`. |
| `tests/test_barometer_trend.py` | 11 acceptance criteria tests |

**Files to modify:**
| File | Change |
|------|--------|
| `weewx_clearskies_realtime/proxy.py` | `_run_enrichments()` → `async def`, add `inspect.isawaitable()` check. `proxy_api()` calls `data = await _run_enrichments(...)` |
| `weewx_clearskies_realtime/__main__.py` | Register barometer trend enrichment: `register_enrichment("current", enrich_barometer_trend)` |

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 2.1 | Baro 30.05→30.10 = trend +0.05 | Unit test: mock upstream current + archive |
| 2.2 | Baro 30.10→30.05 = trend -0.05 | Unit test |
| 2.3 | No archive record → trend null | Unit test: mock 404/empty archive |
| 2.4 | Current barometer null → trend null | Unit test |
| 2.5 | Dashboard ↑ when trend > 0.01 | Manual |
| 2.6 | Dashboard ↓ when trend < -0.01 | Manual |
| 2.7 | Dashboard → when |trend| ≤ 0.01 | Manual |
| 2.8 | Dashboard → when trend null | Manual |
| 2.9 | Uses TREND_TIME_DELTA=10800, TREND_TIME_GRACE=300 | Code inspection + unit test |
| 2.10 | Enrichment failure doesn't break GET /current | Unit test: mock archive timeout |
| 2.11 | < 200ms added latency | Timing test with mock |

**Agents:**
- clearskies-realtime-dev: async enrichment refactor + barometer_trend module + wiring
- clearskies-test-author: 11 tests
- clearskies-auditor: error handling, timing

---

## Task 3: ADR-044 Amendment — Temperature-Comfort 2D Matrix & Wind Labels

**Goal:** Amend ADR-044 with: (a) 2D temperature-comfort matrix, (b) Beaufort 1 rename, (c) near-saturation override, (d) input stability specification. Document only — no code.

**File to modify:** `docs/decisions/ADR-044-sky-condition-classification.md` (or equivalent)

**Sections to add/amend:**
1. §5 Temperature axis: 12 tiers (appTemp ≤-10°F through ≥105°F)
2. §6 Moisture axis: 7 tiers (dewpoint <45°F through ≥75°F) + depression ≤5°F override
3. §7 Full 2D matrix: every physically possible cell defined, NWS HI 104/125°F and WC -25/-45°F escalation
4. §4 Wind: Beaufort 1 renamed "Very Light Breeze"
5. §8 Input stability: smoothing windows table, hysteresis values (±2°F temp, ±2 mph wind, ±2°F dewpoint, ±0.02 in/hr rain), 5-min hold time

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 3.1 | Status = Proposed | File inspection |
| 3.2 | Every physically possible temperature×moisture cell has a descriptor | Matrix review |
| 3.3 | Danger thresholds match NWS (HI 104/125°F, WC -25/-45°F) | Cross-reference NWS sources |
| 3.4 | Beaufort 1 = "Very Light Breeze" | File inspection |
| 3.5 | Near-saturation ≤5°F override documented | File inspection |
| 3.6 | Sources cited (NWS, WMO) | Reference section |
| 3.7 | User approves → Accepted | Chat sign-off |

**Agent:** clearskies-docs-author drafts; user approves before any Task 5 work begins.

---

## Task 4: Sky Condition — Fix Existing Implementation

**Goal:** Fix the two failing acceptance criteria and the min-samples discrepancy in the existing sky_condition.py.

**File to modify:** `weewx_clearskies_realtime/sky_condition.py`

**Specific changes:**
| Change | Detail |
|--------|--------|
| Wire `is_daytime()` | In `conditions_text.py` (or wherever `classify()` is consumed): if `not sky_condition.is_daytime()`, return `None` so provider fallback kicks in. Fixes criterion 4.8. |
| Add sunset buffer clear | Add a `_last_daytime` state flag. When `is_daytime()` transitions True→False, call `reset()`. Fixes criterion 4.12. |
| Change `_MIN_SAMPLES` | 30 → 36 to match plan spec. Fixes criterion 4.6. |

**Files NOT to modify:** `enrichment/ring_buffer.py` — the time-based deque in sky_condition.py is a reasonable choice for a time-window (30 min regardless of packet rate). Keep it.

**Acceptance criteria — the failing ones need new tests:**
| # | Criterion | Current | Fix |
|---|-----------|---------|-----|
| 4.8 | Night → provider | FAIL: `is_daytime()` unwired | Wire into classification consumer |
| 4.12 | Buffer cleared at sunset | FAIL: no reset on sunset | Add daytime transition detection + reset() |
| 4.6 | < 36 samples → fallback | PARTIAL: uses 30 | Change constant to 36 |

**Already passing (from May 26 code):** 4.1-4.5 (classification cells), 4.7 (provider fallback on None), 4.9 (kc clamp), 4.10 (maxSolarRad guard), 4.11 (buffer eviction).

**Agents:**
- clearskies-realtime-dev: 3 code changes
- clearskies-test-author: 3 new/updated tests for criteria 4.8, 4.12, 4.6
- clearskies-auditor: verify night path E2E

---

## Task 5: Temperature-Comfort 2D Matrix Implementation

**Goal:** Replace the 1D dewpoint comfort in `conditions_text.py` with the full 2D matrix from the ADR amendment.

**Depends on:** Task 3 accepted.

**Files to create:**
| File | Contents |
|------|----------|
| `weewx_clearskies_realtime/enrichment/input_smoother.py` | Ring buffer accumulators for appTemp, dewpoint, outTemp, windSpeed, windGust, rainRate, heatindex, windchill. Registered as packet_tap processor. Each buffer uses `RingBuffer` from `enrichment/ring_buffer.py` with capacity matching the smoothing windows table. |
| `weewx_clearskies_realtime/temperature_comfort.py` | 2D classifier: `classify(appTemp, dewpoint, outTemp, heatindex, windchill) -> str`. 12 temperature tiers × 7 moisture tiers. Near-saturation override (depression ≤5°F). NWS danger escalation. Hysteresis state (±2°F temp, ±2°F dewpoint). 5-min hold timer. |

**Files to modify:**
| File | Change |
|------|--------|
| `weewx_clearskies_realtime/conditions_text.py` | Replace `_comfort_label()` with call to `temperature_comfort.classify()`. Pass smoothed inputs from `input_smoother`. |
| `weewx_clearskies_realtime/__main__.py` | Register `input_smoother.process_packet` as a packet_tap processor. |

**Acceptance criteria (19+ tests):**
| # | Criterion | Verification |
|---|-----------|-------------|
| 5.1-5.6 | Hot/warm/pleasant combinations | One test per matrix cell |
| 5.7, 5.10 | Near-saturation override (depression ≤5°F) | Unit test |
| 5.8-5.9, 5.11-5.12 | Cold combinations | Unit test |
| 5.13-5.16 | NWS danger escalation (HI 104/125, WC -25/-45) | Unit test with boundary values |
| 5.17-5.18 | Null handling (missing appTemp, missing dewpoint) | Unit test |
| 5.19 | Every non-N/A matrix cell has a test | Count test cases vs matrix cells |

**Agents:**
- clearskies-realtime-dev: input_smoother, temperature_comfort module, conditions_text rewrite
- clearskies-test-author: 19+ tests (one per matrix cell minimum)
- clearskies-auditor: verify every cell matches ADR, verify smoothing windows match plan table

---

## Task 6: Wind Labels + Conditions Composition

**Goal:** (a) Rename Beaufort 1. (b) Wire `build_weather_text()` into the data pipeline. (c) Update locale files.

**Depends on:** Tasks 4 + 5 complete.

**Files to modify:**
| File | Change |
|------|--------|
| `weewx_clearskies_realtime/units/derived.py` | Line 19: `"Light air"` → `"Very Light Breeze"` |
| `weewx_clearskies_realtime/conditions_text.py` | Ensure composition includes all components (sky + temp-comfort + wind + rain) |
| `weewx_clearskies_realtime/proxy.py` | Register `build_weather_text` as enrichment for "current" endpoint (or wire via transformer) |
| `weewx_clearskies_realtime/__main__.py` | Wire composition into startup if not done via enrichment |
| 13 dashboard locale files in `repos/weewx-clearskies-dashboard/` | Add/update Beaufort label translations |

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 6.1 | `grep -r "Light Air" repos/weewx-clearskies-realtime/` returns 0 | grep (case-sensitive) |
| 6.2 | `grep -r "Light air" repos/weewx-clearskies-realtime/weewx_clearskies_realtime/` returns 0 (production code only) | grep |
| 6.3 | windSpeed=2 mph → "Very Light Breeze" | Unit test |
| 6.4 | All 13 locale files contain "Very Light Breeze" equivalent | File inspection |
| 6.5 | 1 component → no comma | Unit test |
| 6.6 | 2 components → "X and Y" | Unit test |
| 6.7 | 3+ components → "X, Y, and Z" | Unit test |
| 6.8 | All null inputs → null weatherText | Unit test |

**Agents:**
- clearskies-realtime-dev: rename + wiring
- clearskies-dashboard-dev: 13 locale files
- clearskies-test-author: composition tests
- clearskies-auditor: verify all locales complete, ADR-044 §4 match

---

## Task 7: Migrate Conditions Engine Out of API

**Goal:** Delete `local_conditions.py` (430 lines) and all conditions wiring from the API repo. API serves raw data only.

**Depends on:** Tasks 4, 5, 6 verified in BFF.

**Files to delete:**
- `repos/weewx-clearskies-api/weewx_clearskies_api/services/local_conditions.py`

**Files to modify:**
- Any file in `repos/weewx-clearskies-api/` that imports from or references `local_conditions`

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 7.1 | `grep -r "local_conditions\|conditions_text\|derive_conditions" repos/weewx-clearskies-api/` returns 0 | grep |
| 7.2 | API GET /current returns `weatherText: null` | Unit test or manual |
| 7.3 | BFF GET /current returns non-null weatherText | Unit test or manual |
| 7.4 | `python -m pytest` in API repo — all tests pass | test run |
| 7.5 | `grep -r "wire_conditions" repos/weewx-clearskies-api/` returns 0 | grep |

**Agents:**
- clearskies-api-dev: remove code
- clearskies-test-author: update/remove API tests that referenced conditions
- clearskies-auditor: verify clean removal, no orphan imports

---

## Task 8: UV Index Smoothing

**Goal:** Smooth UV via 10-min rolling average in BFF. Both SSE and REST paths.

**Files to create:**
| File | Contents |
|------|----------|
| `weewx_clearskies_realtime/enrichment/uv_smoother.py` | `RingBuffer(capacity=120)` for UV. Packet processor: `accumulate_uv(packet)` extracts UV, adds to buffer. Enrichment function: `enrich_uv(data) -> dict` replaces `UV` with smoothed mean, rounded to 1 decimal. |

**Files to modify:**
| File | Change |
|------|--------|
| `weewx_clearskies_realtime/__main__.py` | Register `accumulate_uv` as packet_tap processor. Register `enrich_uv` as enrichment for "current". |
| `weewx_clearskies_realtime/sse/emitter.py` or `mqtt_fields.py` | Apply UV smoothing to SSE output (read from same ring buffer). |

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 8.1 | 120 constant UV=5.0 readings → smoothed=5.0 | Unit test |
| 8.2 | Alternating 4.0/6.0 → smoothed=5.0 | Unit test |
| 8.3 | Single spike 10.0 among 119×5.0 → smoothed ≈ 5.04 (dampened) | Unit test |
| 8.4 | < 10 samples → raw UV passed through (no smoothing) | Unit test |
| 8.5 | Exactly 10 samples → smoothing begins | Unit test |
| 8.6 | UV=null in packet → skipped (not added to buffer) | Unit test |
| 8.7 | Night (all null UV) → smoothed=null | Unit test |
| 8.8 | Output rounded to 1 decimal | Unit test |
| 8.9 | SSE output shows smoothed UV | Unit test via emitter |
| 8.10 | < 1ms overhead per packet | Timing test |

**Agents:**
- clearskies-realtime-dev: uv_smoother module + wiring
- clearskies-test-author: 10 tests
- clearskies-auditor: verify 10-min window responsive enough

---

## Task 9: UV Forecast Display in Dashboard

**Goal:** Show both current (sensor) and forecasted peak UV in dashboard.

**No backend changes.** Provider data already flows end-to-end.

**Files to create/modify in `repos/weewx-clearskies-dashboard/`:**
| File | Change |
|------|--------|
| `src/components/solar-uv-card.tsx` | Add `forecastUvMax` prop, dual display (Now + Forecast Peak) |
| `src/routes/now.tsx` | Pass today's `uvIndexMax` from forecast data to solar-uv-card |
| `src/routes/forecast.tsx` | Add `uvIndexMax` to daily forecast cards |
| `src/utils/uv.ts` | Extract shared EPA UV segments from solar-uv-card (reuse, don't duplicate) |
| 13 locale files | 3 new i18n keys: "Forecast UV Peak", "Current UV", "UV Index" |

**Acceptance criteria:**
| # | Criterion | Verification |
|---|-----------|-------------|
| 9.1 | Now page shows current UV with EPA label | Visual / Playwright |
| 9.2 | Now page shows forecast peak UV with EPA label | Visual / Playwright |
| 9.3 | Both values use consistent EPA color segments | Code inspection |
| 9.4 | UV bar shows current sensor value, not forecast | Code inspection |
| 9.5 | Provider returns null uvIndexMax → "N/A" or hidden | Unit test |
| 9.6 | Sensor UV null → "N/A" for current, forecast still shown | Unit test |
| 9.7 | Forecast page daily cards show uvIndexMax | Visual / Playwright |
| 9.8 | EPA segments in single shared `src/utils/uv.ts`, not duplicated | `grep` for threshold values — only in one file |
| 9.9 | All 13 locales have the 3 new keys | File inspection |
| 9.10 | `aria-label` on UV display elements | axe-core or code inspection |

**Agents:**
- clearskies-dashboard-dev: all UI changes
- clearskies-test-author: null handling + shared utility tests
- clearskies-auditor: thresholds, accessibility

---

## Execution Order

```
Task 0: Code cleanup ─────────────────────────────────────
  Agent: clearskies-realtime-dev
  AC: 0.1-0.4
  ↓
Task 2: Barometer Trend ──────────────────┐
  Agent: realtime-dev, test-author        │
  AC: 2.1-2.11                            │
                                           │ parallel
Task 3: ADR-044 Amendment ───────────────┐│
  Agent: docs-author                     ││
  AC: 3.1-3.7 (user approval gate)      ││
                                          ││
Task 8: UV Smoothing ────────────────────┤│
  Agent: realtime-dev, test-author       ││
  AC: 8.1-8.10                           ││
                                          ││
Task 9: UV Forecast Display ─────────────┤│
  Agent: dashboard-dev, test-author      ││
  AC: 9.1-9.10                           ││
  ↓                                      ││
Task 4: Sky Condition Fixes ─────────────┘│
  Agent: realtime-dev, test-author        │
  AC: 4.6, 4.8, 4.12                     │
  (after Task 3 accepted)                 │
  ↓                                       │
Task 5: Temp-Comfort 2D Matrix ──────────┘
  Agent: realtime-dev, test-author
  AC: 5.1-5.19
  (after Task 3 accepted)
  ↓
Task 6: Wind Labels + Composition
  Agent: realtime-dev, dashboard-dev, test-author
  AC: 6.1-6.8
  (after Tasks 4 + 5)
  ↓
Task 7: API Cleanup
  Agent: api-dev, test-author
  AC: 7.1-7.5
  (after Tasks 4, 5, 6 verified)
```

---

## Verification Protocol (every task)

1. **Pre-flight:** `git status` + `git log --oneline -1` on target repo before dispatching any agent
2. **Agent prompt:** includes mandatory git prohibition block
3. **Post-agent:** coordinator runs `python -m pytest tests/ -x -q` independently
4. **Criteria walkthrough:** each AC checked with evidence (test name, grep output, code line)
5. **No push** until user says "push it"

---

## Out of scope (follow-on plans)

**Full BFF unit conversion system (ADR-042):** 14 unit groups, conversion factors matching weewx exactly, MQTT suffix stripping, {value,label,formatted} output envelope, compass ordinates, string formatting, dashboard unit-awareness removal (45+ references). This plan builds the proxy + enrichment pipeline + packet tap that the unit conversion plugs into, but does not implement the conversion itself. Estimated ~1,000+ additional LOC.

**Self-computed UV forecasts:** A clear-sky UV formula exists (Allaart: `UVI = 12.5 × cos(SZA)^2.42 × (Ω/300)^(-1.23)`) and we have the solar geometry inputs via pvlib. However, the biggest variable in UV forecasting is cloud cover prediction, which requires radar, satellite, and atmospheric model data that a single weather station cannot provide. External providers (Open-Meteo, Aeris, OWM, Wunderground) all return `uvIndexMax` in their daily forecasts with better cloud-cover prediction than we can achieve locally. **Decision: use provider UV forecasts, do not compute our own.** Current UV from the station sensor is smoothed (Task 8) and displayed separately from the provider's daily forecast UV (Task 9).

---

## Total test count estimate

| Task | Unit tests | Integration tests |
|---|---|---|
| 0: Code cleanup | 0 (removals) | 0 |
| 1: Proxy + enrichment pipeline | 22 (DONE) | 3 (DONE) |
| 2: Barometer trend | 11 | 1 (end-to-end) |
| 3: ADR amendment | 0 (document) | 0 |
| 4: Sky condition fixes | 3 (fix failing) | 1 |
| 5: Temperature-comfort | 19+ (one per matrix cell) | 1 |
| 6: Wind + composition | 8 | 1 |
| 7: API cleanup | 0 (remove tests) | 1 (regression) |
| 8: UV smoothing | 10 | 1 (SSE output) |
| 9: UV forecast display | 3 | 1 (visual) |
| **Total** | **~76 new + 22 existing** | **~10** |
