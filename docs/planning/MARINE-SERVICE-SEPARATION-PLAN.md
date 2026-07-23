# Marine Service Separation Plan

**Status:** DRAFT — awaiting review
**Created:** 2026-07-22
**Origin:** User-ordered full audit of the marine/surf system. The audit (documented in `docs/planning/briefs/SURF-MODEL-SEPARATION-BRIEF.md`) found that the ~28,000-line marine system was improperly embedded in the API instead of being a standalone companion service. A partial extraction was attempted (SWAN service on librewxr:8767, compute service on librewxr:8770) but left the surf page empty for 24+ hours due to cascading failures: TLS cert rejection, local SWAN fallback producing no cached data, and two-service fragmentation.
**Governing brief:** `docs/planning/briefs/SURF-MODEL-SEPARATION-BRIEF.md`

**NO DEFERRAL RULE:** Every task in every phase must be completed and verified before the QC gate closes. "Deferred to v2", "batched with later audit", and "blocked on X" are not acceptable outcomes. If a task cannot be completed, the phase fails and work stops until the blocker is resolved. This rule exists because the SURF-1D-IMPLEMENTATION-PLAN deferred adversarial audits for Phases 2, 3, and 4 — exactly the quality gate that would have caught the issues this plan remediates. The only exception is Surfline comparisons (weather-dependent — clock extends until conditions occur naturally).

---

## 0. Orientation

### 0.1 Execution context

Same SSH rules, deploy scripts, and filesystem permissions as CLAUDE.md. Additionally:

- **weewx container:** API server (port 8765), MariaDB, Redis. SWAN binary has been **disabled** (`/usr/local/bin/swan.disabled`) during the audit to stop it from choking the API with failed runs. Marine provider modules (NDBC, CO-OPS, NWS, HRRR, GFS, WW3, OFS, ERDDAP) currently embedded in the API and fetching data directly. Config at `/etc/weewx-clearskies/api.conf` has `[swan] service_url = https://192.168.7.22:8767` and `[providers] surf_compute_host = https://192.168.7.22:8770`.
- **librewxr container:** 6 GB RAM, 16 cores. Runs the SWAN standalone service (`weewx-clearskies-swan` repo) on port 8767 and the compute service (`compute_service.py`) on port 8770. SWAN binary at `/usr/local/bin/swan`. API repo at `/home/ubuntu/repos/weewx-clearskies-api` (5 commits behind origin). Memory pressure: 4.3 GB of 5.6 GB used, 1.0 GB swap.
- **weather-dev container:** Dashboard (React SPA), config UI (wizard + admin), Caddy proxy. All deployed and current. Surf page renders but shows no forecast data.
- **Marine service port:** **8780** (registered in ARCHITECTURE.md port registry, Phase 1 T1.1).
- **Deploy scripts:**
  - `scripts/deploy-api.sh` — API changes to weewx (pull + restart + wait + verify)
  - `scripts/deploy-compute.sh` — Compute service to librewxr
  - `scripts/redeploy-weather-dev.sh` — Dashboard/config to weather-dev (pull + restart + build + publish)

### 0.2 Current state

| Component | Host | State | Issue |
|---|---|---|---|
| API service | weewx | Running, healthy (port 8765) | Non-marine endpoints work. Surf returns `forecast: []`, `lastRunTime: null` |
| SWAN binary | weewx | **Disabled** (`swan.disabled`) | Renamed during audit to stop CPU-choking local SWAN runs |
| SWAN provider (`swan.py`) | weewx (in API) | Probes `https://192.168.7.22:8767` at startup | **Fails every time:** `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate` |
| SWAN standalone service | librewxr:8767 | Running, healthy, actively computing | Health shows `last_run` populated, spots configured, runs succeeding |
| Compute service | librewxr:8770 | Running, healthy, idle | No compute requests in 11+ hours. Auth works. |
| Surf endpoint | weewx | Returns empty forecast | `nearshoreModel: "SWAN + SwellTrack"` correct, but `forecast: []` |
| Beach profile | weewx | Returns 404 | "No SWAN data cached for location" |
| Dashboard surf page | weather-dev | Renders, no data | SurfingTab.tsx (2,625 lines) complete — waiting for data |
| API repo (weewx) | weewx | Commit `fa48126` | 1 commit behind origin |
| API repo (librewxr) | librewxr | Commit `7dab1c5` | **5 commits behind origin** |
| Local repos (DILBERT) | local | All current | API: `6a0513e`, Dashboard: `9603fe6`, Stack: `f8beb34` |

**Root cause chain:**

```
1. Everything marine embedded in API (architectural violation)
      ↓
2. Partial extraction: SWAN on librewxr:8767, SwellTrack/SurfBeat on librewxr:8770
   BUT API still contains all the same code
      ↓
3. API tries remote SWAN → self-signed TLS cert → CERTIFICATE_VERIFY_FAILED
      ↓
4. Falls back to "bundled mode" — runs SWAN locally on weewx
      ↓
5. Local SWAN full runs fail at L3; quick updates succeed but 0 spots cached
      ↓
6. No SWAN data → no SwellTrack → no SurfBeat → no surf forecast
      ↓
7. Surf endpoint returns empty forecast, beach profile returns 404
      ↓
8. Dashboard surf page has no data
```

### 0.3 Agent assignments

| Role | Model | Responsibility |
|---|---|---|
| **Coordinator** | Opus | Architecture, agent briefs, QC gates, doc updates, research. Keeps this plan updated and checks items off as verified. |
| **clearskies-api-dev** | Sonnet | API code: TLS fix, companion service proxy, marine service scaffold, provider module moves |
| **clearskies-dashboard-dev** | Sonnet | Dashboard: no changes expected (dashboard is unaware of marine service) |
| **clearskies-docs-author** | Sonnet | Wizard/admin: rename "Wave Modeling" to "Marine Service", unify URL fields, config push |
| **clearskies-test-author** | Sonnet | Tests: marine service unit tests, proxy integration tests, manifest handler tests |
| **clearskies-auditor** | Sonnet | Adversarial audit per phase (MANDATORY — no deferral) |

All agent prompts must include the git restrictions block:

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

### 0.4 Scratch file discipline

All agents write progress to `c:\tmp\marine-sep-{phase}-scratch.md`. Coordinator appends after every commit, lead-call, audit finding, state change. Not reconstructed retroactively. This prevents context loss at session limits.

Scratch files per phase:
- `c:\tmp\marine-sep-P1-scratch.md`
- `c:\tmp\marine-sep-P2-scratch.md`
- `c:\tmp\marine-sep-P3-scratch.md`
- `c:\tmp\marine-sep-P4-scratch.md`
- `c:\tmp\marine-sep-P5-scratch.md`
- `c:\tmp\marine-sep-P6-scratch.md`
- `c:\tmp\marine-sep-P7-scratch.md`
- `c:\tmp\marine-sep-P8-scratch.md`

### 0.5 Test baselines (must not regress)

| Suite | Baseline | Command |
|---|---|---|
| API pytest | Check before Phase 1 | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | Check before Phase 7 | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

### 0.6 Code inventory

All code counts and file paths from the audit brief §4. Every file has been verified to exist in `repos/weewx-clearskies-api/weewx_clearskies_api/`.

#### Marine data provider modules (move entirely to marine service)

| Provider module | Lines | What it provides |
|---|---|---|
| `providers/buoy/ndbc.py` | 1,001 | NDBC buoy observations (wave height, period, water temp, met) |
| `providers/tides/coops.py` | 774 | CO-OPS tide predictions and observations |
| `providers/marine/nws_marine.py` | 645 | NWS marine zone weather forecasts |
| `providers/marine/nws_srf.py` | 1,215 | NWS NWPS surf forecasts |
| `providers/marine/wavewatch.py` | 578 | WaveWatch III deep-water boundary spectra |
| `providers/marine/grib_processor.py` | 449 | GRIB2 processing for marine data |
| `providers/wind/hrrr.py` | 907 | HRRR 3 km wind forcing (0-48h) |
| `providers/wind/gfs.py` | 729 | GFS 0.25° wind forcing (48-72h) |
| `providers/ocean/ofs.py` | 665 | OFS ocean surface currents |
| `providers/ocean/erddap_ocean.py` | 247 | ERDDAP ocean data |
| `providers/nearshore/swan.py` | 2,307 | SWAN orchestration (rewritten as internal pipeline in marine service) |
| **Subtotal** | **9,517** | |

#### Wave physics and model code (move entirely)

| Module | Lines | What it does |
|---|---|---|
| `services/swan_runner.py` | 2,628 | 3-level SWAN subprocess execution |
| `services/swan_domain.py` | 634 | Grid domain sizing, spot clustering |
| `services/swan_formats.py` | 1,511 | SWAN INPUT file generation |
| `services/swan_spectral.py` | 555 | SPECOUT parsing |
| `services/surf_1d_analytical.py` | 612 | SwellTrack 1D cross-shore model |
| `services/surf_1d_pipeline.py` | 1,091 | SwellTrack per-transect pipeline |
| `services/surfbeat_runner.py` | 961 | SurfBeat IG strip |
| `services/wave_setup.py` | 316 | Wave-induced water level |
| `services/bathymetry_resolver.py` | 1,070 | CUDEM bathymetry resolution |
| `services/shelf_boundary.py` | 80 | GSFM shelf distance |
| `services/transect_handoff.py` | 742 | SWAN-to-SwellTrack handoff |
| `enrichment/bathymetry.py` | 1,197 | SWAN depth grid generation |
| **Subtotal** | **11,397** | |

#### Enrichment / scoring (move to marine service)

| Module | Lines | What it does |
|---|---|---|
| `enrichment/breaker_height.py` | 283 | Breaking wave calculations |
| `enrichment/surf_scorer.py` | 730 | Surf quality scoring |
| `enrichment/wave_transform.py` | 312 | Wave transformation utilities |
| **Subtotal** | **1,325** | |

#### Marine config and services (move to marine service)

| Module | Lines | What it does |
|---|---|---|
| `config/marine_config.py` | 934 | Marine location config parsing |
| `services/marine_location_resolver.py` | 140 | Location resolution |
| `services/marine_weather_cache.py` | 135 | Marine weather caching |
| **Subtotal** | **1,209** | |

#### Delete (artifacts of the partial extraction)

| Module | Lines | Why delete |
|---|---|---|
| `services/compute_service.py` | 681 | The broken half-service on librewxr:8770 — replaced by the unified marine service |
| `services/compute_client.py` | 361 | Client for the broken half-service — replaced by the marine service client |
| **Subtotal** | **1,042** | |

#### Marine endpoints (delete from API — replaced by dynamic registration)

| Endpoint | Lines | Disposition |
|---|---|---|
| `endpoints/surf.py` | 1,317 | Delete — marine service serves `/surf/{id}`, API mounts via manifest |
| `endpoints/beach_profile.py` | 881 | Delete — marine service serves `/surf/{id}/profile` |
| `endpoints/marine.py` | 1,040 | Delete — marine service serves `/marine/{id}` |
| `endpoints/fishing.py` | 510 | Delete — marine service serves `/fishing/{id}` |
| `endpoints/beach_safety.py` | 497 | Delete — marine service serves `/beach-safety/{id}` |
| **Subtotal** | **4,245** | All deleted |

#### Summary

| Category | Lines | Disposition |
|---|---|---|
| Provider modules → marine service (11 modules) | 9,517 | Move |
| Wave physics → marine service (12 modules) | 11,397 | Move |
| Enrichment/scoring → marine service (3 modules) | 1,325 | Move |
| Config/services → marine service (3 modules) | 1,209 | Move |
| Delete (broken partial extraction) | 1,042 | Delete |
| Delete (endpoints replaced by dynamic registration) | 4,245 | Delete |
| **Total removed from API** | **~28,735** | |
| **API-side addition** | **~200-300 lines** | Generic companion-service proxy + manifest handler |

---

## PART A — Short-Term Fix (Phases 1-3)

**Goal:** Get the surf page showing real data by fixing the broken integration between the weewx API and the SWAN service running on librewxr. This does NOT restructure the architecture — it patches the existing broken remote mode so data flows again.

---

## Phase 1 — Governing Document Updates

**Purpose:** Update ARCHITECTURE.md, ADRs, and manuals to reflect the target marine service architecture BEFORE any code changes. Agents read docs before coding — stale docs produce wrong code. Documents are updated to describe the world as it WILL be after this plan completes, not as it is now.

**Scratch file:** `c:\tmp\marine-sep-P1-scratch.md`

### T1.1 — Update ARCHITECTURE.md

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/ARCHITECTURE.md`

**Do:**
1. Document the marine service as a **companion service** — a standalone extension that handles everything marine (wave physics, tides, buoy data, marine weather, fishing, beach safety). Same architectural DNA as the API (same provider module pattern, same structure).
2. Add the marine service to the Services table: `clearskies-marine`, repo `weewx-clearskies-marine`, port 8780 (single port), technology FastAPI.
3. Document the **manifest registration pattern**: marine service exposes `GET /manifest` returning an endpoint manifest. API dynamically mounts routes from the manifest under `/api/v1/`. Adding a new marine endpoint requires zero API code changes.
4. Document the deployment model: same-host (API calls `localhost:8780`) or separate-host (API calls `https://{host}:8780`). Operator configures `marine_service_url` in `api.conf` `[providers]`.
5. Remove references to SWAN running inside the API as a subprocess. SWAN runs inside the marine service. The API contains zero marine physics code.
6. Remove references to `surf_compute_host` and the compute service on port 8770.
7. Document that alerts stay in the API — marine alerts (coastal flood, high surf, rip current) are part of the unified alert system regardless of whether the marine service is installed.
8. Update the port registry to include the marine service port (8780). Remove port 8770 (compute service — eliminated).
9. Mark new marine service sections with '(target — pending ADR-099 acceptance)' until the ADR is user-approved. After approval, remove the annotation. This follows process rules that ARCHITECTURE.md describes "what IS."

**Accept:**
- ARCHITECTURE.md describes the marine service as a companion service with manifest registration.
- No references to SWAN running inside the API or as a subprocess.
- No references to compute_service.py or port 8770.
- `marine_service_url` documented as the single config key for the marine service.

### T1.2 — Draft ADR for marine service separation

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** New ADR (e.g., `docs/decisions/ADR-099-marine-service-separation.md`)

**Do:**
Draft an ADR documenting:
1. **Context:** The marine system (~28,000 lines) was embedded in the API. A partial extraction left two services (SWAN on 8767, compute on 8770) and the API still containing all the same code. The surf page has been broken for 24+ hours.
2. **Decision:** Separate all marine code into a standalone companion service (`weewx-clearskies-marine`). The API communicates via HTTP (authenticated, TLS). The marine service registers its endpoints via a manifest. Config is pushed from the API on operator apply.
3. **Options considered:** (a) Keep marine in API — rejected, 28K lines is unsustainable. (b) Two half-services (current broken state) — rejected, fragmented and broken. (c) Unified standalone marine service — accepted.
4. **Consequences:** API shrinks by ~28K lines. One service, one port, one auth token. Extensible pattern for future companion services. Dashboard unchanged.
5. **Implementation guidance:** Part A patches the existing integration first. Part B builds the proper architecture.

**Accept:**
- ADR follows the Nygard format per `docs/decisions/_TEMPLATE.md`.
- Status: Proposed (awaiting user approval).
- All three options evaluated with reasons.

### T1.3 — Update API-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/API-MANUAL.md`

**Do:**
1. Document that marine endpoints (`/surf/{id}`, `/marine/{id}`, `/tides/{id}`, `/fishing/{id}`, `/beach-safety/{id}`, `/surf/{id}/profile`) are **dynamically registered** from the marine service manifest. They are not hardcoded routes in the API.
2. Document the `marine_service_url` config key in the providers section.
3. Document the response envelope wrapping: API fetches raw data from the marine service, wraps in the standard envelope (`data`, `stationClock`, `freshness`, `units`), and applies unit conversion.
4. Document the capability merging: marine capabilities appear in `/api/v1/capabilities` when the marine service is connected.
5. Remove references to SWAN as an in-process model. Remove references to `surf_compute_host`.

**Accept:**
- API-MANUAL describes marine endpoints as dynamically registered.
- `marine_service_url` documented.
- No references to in-process SWAN or `surf_compute_host`.

### T1.4 — Update OPERATIONS-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
1. Document the marine service deployment: same-host (install on API host, use `localhost:8780`) vs separate-host (install on compute machine, use `https://{host}:8780`).
2. Document the `marine_service_url` config key and the shared secret (`MARINE_SERVICE_SECRET` in `secrets.env`).
3. Document the config push model: wizard/admin save → API `/setup/apply` → marine service `/config`.
4. Remove references to the two-service model (`surf_compute_host` + `service_url`).
5. Document the marine service health check endpoint and monitoring.

**Accept:**
- OPERATIONS-MANUAL describes a single `marine_service_url` config key.
- Deployment model (same-host vs separate-host) documented.
- Config push model documented.

### T1.5 — Update PROVIDER-MANUAL

- **Owner:** clearskies-docs-author (Sonnet) — Coordinator (Opus) reviews
- **Files:** `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
1. Document that the marine service's internal provider modules follow the same pattern as API providers: CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL management, error handling.
2. Document that marine data sources (NDBC, CO-OPS, NWS, HRRR, GFS, WW3, OFS, ERDDAP, CUDEM) are fetched directly by the marine service, not by the API.
3. Remove references to marine providers being part of the API's provider registry.

**Accept:**
- PROVIDER-MANUAL describes marine providers as internal to the marine service.
- Same provider module pattern documented for both API and marine service.

### Adversarial Audit — Phase 1

- **Owner:** `clearskies-auditor`

**Scope:**
1. Every doc updated in T1.1-T1.5 — verify no references to `surf_compute_host`, `compute_service.py`, or SWAN running as an API subprocess remain.
2. Verify `marine_service_url` is documented as the single config key for the marine service in all relevant manuals.
3. Verify the manifest registration pattern is described consistently across ARCHITECTURE.md and API-MANUAL.
4. Verify alerts are documented as staying in the API, not moving to the marine service.
5. Silent deferral scan: grep for TODO, FIXME, "deferred", "future" in all modified docs.

### QC Gate 1

- All 5 documents updated.
- `marine_service_url` consistent across all docs.
- No references to `surf_compute_host`, `compute_service.py`, or SWAN-as-subprocess.
- Manifest registration pattern described consistently.
- Alerts documented as staying in the API.
- Auditor: zero unresolved findings.

---

## Phase 2 — Fix TLS + Remote Mode Connection

**Purpose:** Fix the immediate blocker — the API cannot connect to the SWAN service on librewxr because of self-signed TLS cert verification failure. This is the root cause of the 24+ hour outage: `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate`.

**Scratch file:** `c:\tmp\marine-sep-P2-scratch.md`

### T2.1 — Fix TLS verification in SWAN provider remote mode

- **Owner:** `clearskies-api-dev`
- **Files:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`, `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`

**Reading list:**
1. `providers/nearshore/swan.py` — read `configure_remote_mode()` (line ~937) and `_remote_health_loop()` (line ~810). These are the two functions that make `httpx.get()` calls to the SWAN service without passing `verify=False`.
2. `services/compute_client.py` — read `remote_swelltrack()` and `remote_surfbeat()`. These correctly use `verify=verify_tls` — the pattern to follow.
3. `config/marine_config.py` — read the existing `surf_compute_verify_tls` config field.

**Do:**
1. Add a `verify_tls: bool = True` config option to the `[swan]` section in `marine_config.py`. This follows the same pattern as `surf_compute_verify_tls` in the `[providers]` section.
2. In `configure_remote_mode()`, change the `httpx.get(f"{service_url}/health", timeout=10.0)` call to pass `verify=verify_tls`. The function signature must accept the verify flag.
3. In `_remote_health_loop()`, change all `httpx.get()` calls (health check at line ~843, forecast fetch at line ~867) to pass `verify=verify_tls`. The function signature must accept the verify flag.
4. Wire the config: `run_all_spots()` reads `swan_cfg.verify_tls` and passes it to `configure_remote_mode()`.

**Accept:**
- `configure_remote_mode()` passes `verify=False` when `verify_tls=false` in `api.conf`.
- `_remote_health_loop()` passes `verify=False` for all its HTTP calls.
- The pattern matches `compute_client.py`'s existing `verify=verify_tls` approach.
- No regression when `verify_tls=true` (default) — full cert verification still happens.

### T2.2 — Sync librewxr API repo to current HEAD

- **Owner:** Coordinator (Opus) — with user approval before any SSH commands
- **Files:** API repo on librewxr at `/home/ubuntu/repos/weewx-clearskies-api`

**Do:**
1. Push all local API commits to GitHub (coordinator, with user approval).
2. SSH to librewxr, pull the API repo to current HEAD (`sudo -u ubuntu git pull --ff-only`).
3. Restart the SWAN standalone service (`sudo systemctl restart weewx-clearskies-swan`) so it picks up any code changes.
4. Restart the compute service (`sudo systemctl restart weewx-clearskies-compute`) so it picks up any code changes.
5. Verify both services are running and healthy.

**Accept:**
- librewxr API repo at same commit as origin HEAD (currently 5 commits behind).
- SWAN service on port 8767: healthy, running.
- Compute service on port 8770: healthy, running.

### T2.3 — Configure and verify remote mode activates

- **Owner:** Coordinator (Opus)
- **Files:** `/etc/weewx-clearskies/api.conf` on weewx

**Do:**
1. Add `verify_tls = false` to the `[swan]` section in `api.conf` on weewx. (Self-signed cert on same VLAN — same pattern as `surf_compute_verify_tls = false`.)
2. Deploy the TLS-fixed API to weewx via `scripts/deploy-api.sh`.
3. Check API logs for: `"SWAN: probing remote service at https://192.168.7.22:8767"` followed by `"SWAN remote service reachable"` (not `CERTIFICATE_VERIFY_FAILED`).
4. Verify the remote health thread starts: `"SWAN: remote mode active"`.

**Accept:**
- API logs show remote mode activated successfully.
- No `CERTIFICATE_VERIFY_FAILED` errors.
- Remote health thread is running.

### T2.4 — Verify SWAN forecast data flows from librewxr to API cache

- **Owner:** Coordinator (Opus)

**Do:**
1. Monitor the `_remote_health_loop` in API logs. It should:
   - Call `GET https://192.168.7.22:8767/health` every 60 seconds.
   - Get a 200 response with `last_run` populated.
   - Call `GET https://192.168.7.22:8767/surf/{spot_id}/forecast` for each spot.
   - Store the forecast data in the last-good cache key.
2. After the next SWAN cycle completes on librewxr, verify:
   - `GET /api/v1/surf/huntington-city-beach-pier` returns non-empty `forecast` array.
   - `lastRunTime` is populated (not null).
   - `surfForecastError` is absent or null.

**Accept:**
- Health loop fetches forecast data from librewxr and stores in cache.
- Surf endpoint returns non-empty forecast within one SWAN cycle (~1 hour).

### Adversarial Audit — Phase 2

- **Owner:** `clearskies-auditor`

**Scope:**
1. TLS fix: verify `verify=False` is passed in ALL httpx calls in `swan.py` when `verify_tls=false` — not just `configure_remote_mode` but also `_remote_health_loop` and any other HTTP calls.
2. Config: verify `verify_tls` is read from `api.conf` `[swan]` section, not hardcoded.
3. Default safety: verify `verify_tls` defaults to `True` (not `False`) — self-signed skip is opt-in.
4. No bypass on production: verify that setting `verify_tls=true` still performs full cert verification (no accidental always-skip).
5. Silent deferral scan: grep for `pass`, `TODO`, `FIXME`, hardcoded `verify=False` (should be configurable, not hardcoded) in `swan.py`.

### QC Gate 2

- API connects to librewxr:8767 without TLS errors.
- Remote mode activates (log evidence).
- Health thread running and fetching data.
- `verify_tls` is configurable (not hardcoded).
- Default is `True` (secure default).
- Auditor: zero unresolved findings.

---

## Phase 3 — Fix SWAN Data Caching + End-to-End Verification

**Purpose:** Even with remote mode working, the "1 spot resolved, 0 spots cached" bug reported in the audit may exist on librewxr too. Verify the full pipeline produces data visible on the surf page.

**Scratch file:** `c:\tmp\marine-sep-P3-scratch.md`

### T3.1 — Investigate the "0 spots cached" bug

- **Owner:** `clearskies-api-dev`
- **Files:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py`, `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`

**Reading list:**
1. `providers/nearshore/swan.py` — read `_run_all_spots_locked()` and the cache storage logic. The audit found: "Hourly quick updates: 53 seconds, succeeds (1 spot resolved, 48/48 valid), but **0 spots cached** (handoff bug)."
2. `services/swan_runner.py` — read the spot resolution and cache write code path.
3. `services/transect_handoff.py` — read the SWAN-to-SwellTrack handoff logic.

**Do:**
1. Trace the code path from `_run_all_spots_locked()` through to the cache storage step. Find where the resolved spot's data fails to reach the cache.
2. Identify the specific bug: is it a cache key mismatch, a missing write call, a data format issue, or a handoff failure?
3. Document the root cause and fix.

**Accept:**
- Root cause of "1 spot resolved, 0 spots cached" identified and documented.
- Fix implemented.
- Quick update produces "1 spot resolved, 1 spot cached" (or appropriate count).

### T3.2 — Verify the caching bug scope

- **Owner:** `clearskies-api-dev`

**Do:**
1. Determine whether the "0 spots cached" bug affects only the local weewx code path (bundled SWAN mode) or also the remote librewxr code path.
2. The remote health loop (`_remote_health_loop`) fetches `/surf/{spot_id}/forecast` from librewxr and stores it in the last-good cache. This is a different code path from the bundled SWAN mode cache write. If the remote path works, the bug may be limited to bundled mode.
3. If the bug affects the remote path too, fix it there as well.

**Accept:**
- Clear determination: bug is bundled-only or affects both paths.
- If remote path is affected, fix applied.

### T3.3 — Deploy API to weewx with TLS fix

- **Owner:** Coordinator (Opus) — via `scripts/deploy-api.sh`

**Do:**
1. Deploy the API with all Phase 2 changes (TLS fix, any caching bug fix).
2. Verify health endpoint returns 200.
3. Verify remote mode activates in logs.
4. Verify `GET /api/v1/surf/huntington-city-beach-pier` returns a response (may be empty until SWAN cycle completes).

**Accept:**
- API deployed and healthy.
- Remote mode active.
- No TLS errors in logs.

### T3.4 — Wait for SWAN cycle on librewxr and verify surf data

- **Owner:** Coordinator (Opus)

**Do:**
1. Wait for the next SWAN cycle to complete on librewxr (check health endpoint `last_run`).
2. After cycle completes, verify:
   - `GET /api/v1/surf/huntington-city-beach-pier` returns non-empty `forecast` array.
   - `lastRunTime` is populated.
   - `waveHeight`, `wavePeriod`, `waveDirection` fields are present and non-null.
   - `faceHeight` and `breakPoints` are populated (SwellTrack output).
   - `setTimingMinutes` and `igWaveHeightM` populated if SurfBeat is running.

**Accept:**
- Surf endpoint returns complete forecast data.
- All required fields populated.

### T3.5 — Verify dashboard surf page displays real data

- **Owner:** Coordinator (Opus)

**Do:**
1. Open the dashboard surf page in a browser.
2. Verify: wave height card, conditions card, 72h forecast scroll, beach profile chart all render with real data.
3. Verify attribution reads "SWAN + SwellTrack".
4. Take a screenshot for the execution log.

**Accept:**
- Dashboard surf page shows real data (not empty, not "—", not loading).
- Attribution correct.

### T3.6 — Surfline comparison

- **Owner:** Coordinator (Opus)

**Do:**
1. At the time of the SWAN cycle, check Surfline's reported surf height for Huntington Beach.
2. Compare our face height against Surfline's reported height.
3. Document: our value, Surfline's value, delta, conditions.

**Accept:**
- Face height within ±30% of Surfline's reported value for the first comparison.
- This is an ongoing task: ≥3 comparisons across different conditions within 14 days. This is the one exception to the no-deferral rule — it depends on weather, not work.

### Adversarial Audit — Phase 3

- **Owner:** `clearskies-auditor`

**Scope:**
1. Cache verification: verify the SWAN data is stored in the correct cache key and retrievable by the surf endpoint.
2. Remote health loop: verify it fetches and caches data from all configured spots (not just the first one).
3. End-to-end: verify `GET /api/v1/surf/{id}` returns all expected fields (not null, not degraded).
4. Verify SWAN is NOT running on weewx: `swan.disabled` exists, no SWAN processes, no new SWAN log entries.
5. Verify SWAN IS running on librewxr: health check shows spots, `last_run` populated.
6. Silent deferral scan on all modified files.

### QC Gate 3 (Part A Final)

- Surf endpoint returns non-empty forecast array.
- Beach profile endpoint returns data.
- SurfBeat fields present (set timing, IG wave height) if SurfBeat is enabled.
- Dashboard renders complete surf page with real data.
- Attribution reads "SWAN + SwellTrack".
- SWAN is NOT running on weewx (binary disabled, no SWAN processes, no SWAN log entries).
- SWAN IS running on librewxr (health check, last_run populated).
- API connects to librewxr via remote mode (log evidence).
- Silent deferral scan: zero findings.
- Test baselines hold.

---

## Part A QA — Short-Term Fix Verification

A comprehensive final verification that the short-term fix works end-to-end. This checklist must be completed before Part B begins.

| Check | Method | Pass criteria |
|---|---|---|
| Surf endpoint returns non-empty forecast | `GET /api/v1/surf/huntington-city-beach-pier` | `forecast` array length > 0 |
| Beach profile returns data | `GET /api/v1/surf/huntington-city-beach-pier/profile` | 200 response with profile data |
| SurfBeat fields present | Inspect surf response | `setTimingMinutes`, `igWaveHeightM` non-null |
| Dashboard renders complete surf page | Visual inspection | All cards, charts, forecast scroll show data |
| Attribution correct | Inspect surf response + dashboard | `nearshoreModel: "SWAN + SwellTrack"` |
| SWAN NOT on weewx | `ssh weewx "ls /usr/local/bin/swan*"` | Only `swan.disabled` exists |
| SWAN NOT on weewx (processes) | `ssh weewx "pgrep -f swan"` | No matches |
| SWAN IS on librewxr | `curl https://192.168.7.22:8767/health -k` | `status: ok`, `last_run` populated |
| API remote mode active | `journalctl -u weewx-clearskies-api \| grep 'remote mode'` | "SWAN: remote mode active" present |
| Silent deferral scan | `grep -rn "TODO\|FIXME\|pass$\|return \[\]\|return None" {modified_files}` | Zero findings in modified files |
| API pytest baseline | Run baseline command | No regression from pre-Phase 1 baseline |

---

## PART B — Marine Service Separation (Phases 4-8)

**Goal:** Build the proper standalone marine service and remove all marine code from the API. The marine service handles everything marine: wave physics (SWAN, SwellTrack, SurfBeat), tides, buoy data, marine weather forecasts, ocean currents, fishing/solunar, beach safety. The API becomes a thin proxy that dynamically mounts marine routes from the service's manifest.

### Target architecture

```
librewxr (or any compute-capable host, or same host as API)
+------------------------------------------------------+
| Marine Service (standalone)                          |
|                                                      |
|  Wave physics:                                       |
|   - SWAN 3-level nested grid (HRRR+GFS wind)        |
|   - SwellTrack per-transect 1D transformation        |
|   - SurfBeat IG strip (set timing)                   |
|                                                      |
|  Marine data providers (same pattern as API):        |
|   - NDBC buoy (spectral, met, water temp)            |
|   - CO-OPS tides (predictions, observations)         |
|   - NWS marine weather (zone forecasts)              |
|   - NWS NWPS surf forecast                           |
|   - WaveWatch III (boundary spectra)                 |
|   - HRRR wind (3 km, 0-48h)                         |
|   - GFS wind (0.25°, 48-72h)                        |
|   - CUDEM bathymetry (NCEI)                          |
|   - OFS ocean currents                               |
|   - ERDDAP ocean data                                |
|                                                      |
|  Enrichment:                                         |
|   - Surf scoring, breaker classification             |
|   - Beach profile blending                           |
|   - Face height calculation                          |
|   - Solunar, beach safety assessments                |
|                                                      |
|  Serves complete marine data via HTTP endpoints      |
|  One port, one health check, one auth token          |
+------------------------------------------------------+
         ↑
         | HTTP (authenticated, TLS)
         ↓
weewx host
+------------------------------------------------------+
| Clear Skies API                                      |
|   - Companion service proxy (generic, reusable)      |
|     Reads marine service /manifest                   |
|     Dynamically mounts /api/v1/surf, /marine, etc.   |
|   - Response envelope wrapping + unit conversion     |
|   - No marine physics code, no SWAN, no marine       |
|     provider modules                                 |
+------------------------------------------------------+
         ↑
         | HTTP (Caddy proxy)
         ↓
+------------------------------------------------------+
| Dashboard (unchanged)                                |
|   - Calls API endpoints as always                    |
|   - Has zero knowledge of the marine service         |
+------------------------------------------------------+
```

### Decisions (from audit brief §11, resolved 2026-07-22)

1. **Repo name:** `weewx-clearskies-marine`. The "marine" name reflects the full scope — tides, buoy data, fishing, beach safety, surf physics — not just SWAN.
2. **Config model:** API pushes config on apply. Wizard and admin talk only to the API. When the operator saves marine config, the API's `/setup/apply` handler pushes the marine config to the marine service's `/config` endpoint. One source of truth, one push path. The marine service never needs `api.conf`.
3. **Alerts stay in the API.** Alerts are a core feature, not a marine extension. Marine alerts (coastal flood, high surf, rip current) are part of the unified alert system regardless of whether the marine service is installed. Alerts never move.

---

## Phase 4 — Marine Service Repo + Scaffold

**Purpose:** Create the `weewx-clearskies-marine` repo, scaffold the service structure, and set up the provider module architecture. The scaffold has endpoints, auth, TLS, systemd, and health — but no provider modules yet (those move in Phase 5).

**Scratch file:** `c:\tmp\marine-sep-P4-scratch.md`

### T4.1 — Create repo with proper structure

- **Owner:** `clearskies-api-dev`
- **Files:** New repo `weewx-clearskies-marine` (local at `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`)

**Do:**
1. Create the repo structure mirroring API repo conventions:
```
weewx-clearskies-marine/
  weewx_clearskies_marine/
    __init__.py
    __main__.py              # CLI entry point
    service.py               # FastAPI app, startup, health, manifest
    config.py                # Marine service config (reads its own config file)
    providers/               # Provider modules (same pattern as API)
      __init__.py
      buoy/
      tides/
      marine/
      wind/
      ocean/
      nearshore/
    services/                # Internal services (SWAN, SwellTrack, SurfBeat)
      __init__.py
    enrichment/              # Scoring, breaker height, wave transform
      __init__.py
    endpoints/               # HTTP endpoint handlers
      __init__.py
    data/                    # Static data files (GSFM, species YAML, etc.)
  tests/
    __init__.py
  pyproject.toml
  LICENSE
```
2. The structure mirrors the API repo exactly. A developer who knows the API repo can navigate the marine service repo without learning a new layout.

**Accept:**
- Repo created with all directories.
- `pyproject.toml` with proper metadata, dependencies (fastapi, uvicorn, httpx, numpy, eccodes, xarray, netCDF4).
- `pip install -e .` succeeds.
- `[nearshore]` optional extra for SWAN (adds SWAN binary requirement).

### T4.2 — Set up provider module infrastructure

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/providers/__init__.py`, base provider module pattern

**Do:**
1. Create the provider module base pattern — CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL, error handling — identical to the API's provider pattern.
2. Create the provider registry that discovers and loads provider modules.
3. Create the provider dispatch mechanism (internal scheduler, cache warmer).

**Accept:**
- Provider base pattern implemented.
- Registry discovers modules in `providers/` subdirectories.
- A stub provider (empty `fetch()` returning test data) loads and runs.

### T4.3 — Implement /health, /manifest, and /config endpoints

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/service.py`, `weewx_clearskies_marine/endpoints/`

**Do:**
1. `GET /health` (no auth): returns `{"status": "ok", "version": "1.0.0", "last_run": timestamp, "spots": [...], "run_in_progress": bool}`.
2. `GET /manifest` (no auth): returns the endpoint manifest JSON:
```json
{
  "service": "clearskies-marine",
  "version": "1.0.0",
  "endpoints": [
    {"path": "/surf/{location_id}", "method": "GET", "upstream": "/surf/{location_id}", "cache_ttl": 1800},
    {"path": "/surf/{location_id}/profile", "method": "GET", "upstream": "/surf/{location_id}/profile", "cache_ttl": 1800},
    {"path": "/marine/{location_id}", "method": "GET", "upstream": "/marine/{location_id}", "cache_ttl": 300},
    {"path": "/tides/{location_id}", "method": "GET", "upstream": "/tides/{location_id}", "cache_ttl": 3600},
    {"path": "/fishing/{location_id}", "method": "GET", "upstream": "/fishing/{location_id}", "cache_ttl": 1800},
    {"path": "/beach-safety/{location_id}", "method": "GET", "upstream": "/beach-safety/{location_id}", "cache_ttl": 900}
  ],
  "capabilities": ["surf", "tides", "marine_weather", "fishing", "beach_safety"],
  "locations": [...]
}
```
3. `POST /config` (auth required): receives config push from API, stores marine config locally, restarts run loop.

**Accept:**
- `/health` returns valid JSON with all fields.
- `/manifest` returns the complete endpoint manifest.
- `/config` accepts a config payload, persists it, and returns 200.

### T4.4 — Implement TLS, auth, and systemd unit

- **Owner:** `clearskies-api-dev`
- **Files:** `weewx_clearskies_marine/service.py`, systemd unit template

**Do:**
1. **TLS:** Generate self-signed cert on first start (same pattern as API TLS). Store in `/etc/weewx-clearskies/marine/`. Support `--hostname` CLI arg for SAN.
2. **Auth:** Bearer token authentication. Read `MARINE_SERVICE_SECRET` from `secrets.env`. All endpoints except `/health` and `/manifest` require `Authorization: Bearer {token}`. Return 401 for missing/wrong token.
3. **Systemd unit template:** `weewx-clearskies-marine.service` — ExecStart, User, WorkingDirectory, Restart=on-failure.
4. **Bind address:** `0.0.0.0` by default. Configurable via CLI arg.

**Accept:**
- Service starts with TLS on configured port.
- Unauthenticated requests to protected endpoints return 401.
- Wrong-token requests return 401. Correct-token requests return 200.
- Health and manifest endpoints accessible without auth.
- Systemd unit template created.

### T4.5 — Set up pyproject.toml and pip installability

- **Owner:** `clearskies-api-dev`
- **Files:** `pyproject.toml`

**Do:**
1. Package name: `weewx-clearskies-marine`.
2. Dependencies: fastapi, uvicorn, httpx, numpy, pydantic, redis.
3. Optional extra `[nearshore]`: adds SWAN-specific dependencies.
4. Entry point: `python -m weewx_clearskies_marine` starts the service.
5. `pip install -e .` and `pip install -e ".[nearshore]"` both succeed.

**Accept:**
- `pip install -e .` succeeds and service starts.
- `python -m weewx_clearskies_marine --help` shows CLI options.

### T4.6 — Write marine service scaffold tests

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/`

**Do:**
1. Write tests for `/health`, `/manifest`, `/config` endpoints (correct response shape, required fields, status codes).
2. Write auth tests: 401 for missing token, 401 for wrong token, 200 for correct token on protected endpoints. Verify `/health` and `/manifest` are accessible without auth.
3. Write TLS tests: verify service only listens on HTTPS, verify cert generation.

**Accept:**
- All scaffold endpoint tests pass.
- Auth enforcement verified (401 for missing/wrong token on protected endpoints, 200 without auth on /health and /manifest).
- TLS tests pass.

### Adversarial Audit — Phase 4

- **Owner:** `clearskies-auditor`

**Scope:**
1. Repo structure mirrors API repo conventions.
2. Provider module pattern matches API pattern (CAPABILITY, fetch(), canonical mapping, cache TTL).
3. Auth enforcement: verify all endpoints except `/health` and `/manifest` require Bearer token.
4. TLS: verify service only listens on HTTPS.
5. Manifest format matches the specification.
6. Secret storage: verify secret is read from `secrets.env`, not source code, not config file.
7. Silent deferral scan across all new files.

### QC Gate 4

- Repo created with proper structure.
- Provider module infrastructure operational.
- `/health`, `/manifest`, `/config` endpoints functional.
- TLS and auth working (verified with curl tests).
- `pip install -e .` succeeds.
- Auditor: zero unresolved findings.

---

## Phase 5 — Move Provider Modules

**Purpose:** Move all marine data provider modules from the API repo to the marine service repo. Keep the same architecture — same CAPABILITY, same `fetch()`, same caching. Wire the internal pipeline end-to-end.

**Scratch file:** `c:\tmp\marine-sep-P5-scratch.md`

### T5.0 — Capture golden response fixtures

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/fixtures/`

**Do:**
1. Before moving any code, capture the current API response JSON for each marine endpoint as golden fixtures:
   - `GET /api/v1/surf/huntington-city-beach-pier` → `tests/fixtures/golden_surf.json`
   - `GET /api/v1/surf/huntington-city-beach-pier/profile` → `tests/fixtures/golden_surf_profile.json`
   - `GET /api/v1/marine/huntington-city-beach-pier` → `tests/fixtures/golden_marine.json`
   - `GET /api/v1/tides/huntington-city-beach-pier` → `tests/fixtures/golden_tides.json`
   - `GET /api/v1/fishing/huntington-city-beach-pier` → `tests/fixtures/golden_fishing.json`
   - `GET /api/v1/beach-safety/huntington-city-beach-pier` → `tests/fixtures/golden_beach_safety.json`
2. Commit golden fixtures to the marine service test suite.
3. These fixtures serve as regression baselines for Phase 5 provider moves.

**Accept:**
- Golden response JSON captured for all 6 marine endpoints.
- Fixtures committed to `repos/weewx-clearskies-marine/tests/fixtures/`.
- Each fixture contains a valid, non-empty response from the working Part A API.

### T5.1 — Move buoy/ndbc.py (1,001 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/buoy/ndbc.py`
- **Target:** `repos/weewx-clearskies-marine/weewx_clearskies_marine/providers/buoy/ndbc.py`

**Do:** Copy, update imports, wire into marine service registry, verify against live NDBC API.

**Accept:** `fetch()` returns real buoy data from live NDBC. CAPABILITY declaration intact.

### T5.2 — Move tides/coops.py (774 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/tides/coops.py`
- **Target:** `providers/tides/coops.py` in marine service

**Do:** Copy, update imports, wire, verify against live CO-OPS API.

**Accept:** `fetch()` returns real tide data.

### T5.3 — Move marine forecast providers (2,887 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/marine/nws_marine.py` (645), `nws_srf.py` (1,215), `wavewatch.py` (578), `grib_processor.py` (449)
- **Target:** `providers/marine/` in marine service

**Do:** Copy all 4, update imports, wire, verify NWS marine and WW3 against live APIs.

**Accept:** All 4 modules load. NWS marine and WW3 fetch real data.

### T5.4 — Move wind providers (1,636 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/wind/hrrr.py` (907), `gfs.py` (729)
- **Target:** `providers/wind/` in marine service

**Do:** Copy both, update imports, wire, verify HRRR against live NOAA NOMADS.

**Accept:** HRRR and GFS providers load and fetch real wind data.

### T5.5 — Move ocean providers (912 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `providers/ocean/ofs.py` (665), `erddap_ocean.py` (247)
- **Target:** `providers/ocean/` in marine service

**Do:** Copy both, update imports, wire, verify OFS against live data.

**Accept:** OFS and ERDDAP providers load and fetch real data.

### T5.6 — Move wave physics code (11,397 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `services/swan_runner.py` (2,628), `swan_domain.py` (634), `swan_formats.py` (1,511), `swan_spectral.py` (555), `surf_1d_analytical.py` (612), `surf_1d_pipeline.py` (1,091), `surfbeat_runner.py` (961), `wave_setup.py` (316), `bathymetry_resolver.py` (1,070), `shelf_boundary.py` (80), `transect_handoff.py` (742), `enrichment/bathymetry.py` (1,197)
- **Target:** `services/` and `enrichment/` in marine service

**Do:** Copy all 12 files, update imports, move static data files (`data/gsfm_shelf_boundary.json`, `data/ncei_regional_dem_index.json`), verify import resolution.

**Accept:** All 12 modules load without import errors. Static data files present. SWAN runner can locate the SWAN binary.

### T5.7 — Move enrichment code (1,325 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `enrichment/breaker_height.py` (283), `surf_scorer.py` (730), `wave_transform.py` (312)
- **Target:** `enrichment/` in marine service

**Do:** Copy all 3, update imports, move species data YAML if needed.

**Accept:** All enrichment modules load and scoring/classification functions work.

### T5.8 — Move config and service support code (1,209 lines)

- **Owner:** `clearskies-api-dev`
- **Source:** `config/marine_config.py` (934), `services/marine_location_resolver.py` (140), `services/marine_weather_cache.py` (135)
- **Target:** `config/` and `services/` in marine service

**Do:** Copy all 3, adapt `marine_config.py` to read from the marine service's own config file (received via `POST /config`), update imports.

**Accept:** Config parsing works from local config file. Location resolver and weather cache operational.

### T5.9 — Wire the internal pipeline

- **Owner:** `clearskies-api-dev`
- **Files:** `service.py`, endpoint handlers in marine service

**Do:**
1. Wire: SWAN (fetches wind, bathymetry, boundary) → SwellTrack (per-transect) → SurfBeat (IG strip) → scoring → serve via endpoints.
2. Wire: buoy → tides → marine weather → ocean currents → cache → serve via endpoints.
3. Implement all 6 data endpoints with same response shapes as current API endpoints (SI units):
   - `GET /surf/{location_id}` — complete surf forecast
   - `GET /surf/{location_id}/profile` — beach profile
   - `GET /marine/{location_id}` — marine observations
   - `GET /tides/{location_id}` — tide predictions/observations
   - `GET /fishing/{location_id}` — fishing conditions
   - `GET /beach-safety/{location_id}` — beach safety assessment

**Accept:**
- Full SWAN → SwellTrack → SurfBeat pipeline runs end-to-end.
- All 6 data endpoints return correctly shaped responses.

### T5.10 — Write marine service provider + pipeline tests

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-marine/tests/`

**Do:**
1. Write tests for each provider module's `fetch()` method — verify CAPABILITY declaration present, verify `fetch()` returns data in the expected shape, verify canonical field mapping.
2. Write a pipeline integration test: SWAN → SwellTrack → SurfBeat end-to-end with test input data.
3. Write endpoint response shape tests: verify each of the 6 data endpoints returns a response that matches the golden fixture captured in T5.0 (field names, structure — values may differ).

**Accept:**
- Provider `fetch()` tests pass for all 11 provider modules.
- Pipeline integration test passes (SWAN → SwellTrack → SurfBeat).
- Endpoint response shape matches golden fixtures.

### Adversarial Audit — Phase 5

- **Owner:** `clearskies-auditor`

**Scope:**
1. Provider module count: verify all 11 provider modules from §0.6 are present (count files).
2. Wave physics count: verify all 12 modules present.
3. Import resolution: `python -c "import weewx_clearskies_marine.providers.buoy.ndbc"` etc. for all modules.
4. CAPABILITY declarations: verify every provider has one.
5. Pipeline end-to-end: verify SWAN → SwellTrack → SurfBeat → scoring → endpoints.
6. Endpoint shape: verify each endpoint returns the same field names as the current API endpoint.
7. Golden fixture regression: verify each endpoint response matches the golden fixture captured in T5.0 (field names, structure — values may differ due to time).
8. Silent deferral scan across all marine service files.

### QC Gate 5

- All 29 modules moved and loading: 11 providers, 12 physics, 3 enrichment, 3 config.
- Full pipeline operational.
- All 6 data endpoints return correctly shaped responses.
- Auditor: zero unresolved findings.

---

## Phase 6 — API Companion Service Proxy

**Purpose:** Build the generic companion service proxy in the API — the manifest handler that dynamically mounts routes from any companion service. Then delete all marine code from the API.

**Scratch file:** `c:\tmp\marine-sep-P6-scratch.md`

### T6.1 — Implement the manifest handler

- **Owner:** `clearskies-api-dev`
- **Files:** New file `repos/weewx-clearskies-api/weewx_clearskies_api/services/companion_proxy.py`

**Do:**
1. At API startup, when `marine_service_url` is configured in `api.conf` `[providers]`:
   - Call `GET {marine_service_url}/manifest` (no auth).
   - Parse the endpoint manifest JSON.
   - For each endpoint, dynamically create a FastAPI route under `/api/v1/`.
2. Each route handler: fetch from `{marine_service_url}{upstream_path}` with auth, cache with manifest TTL, wrap in API response envelope.
3. When `marine_service_url` not configured: no marine routes (marine features disabled).
4. When marine service unreachable at startup: log ERROR, start without marine routes. Retry every 5 minutes.
5. When the marine service becomes unreachable after startup (runtime failure): mounted routes return the last cached response (stale is preferred to no data, same principle as SWAN provider). If no cache exists, return 503 with a clear error message. Dashboard shows the stale data with a data-age indicator.
6. Support periodic manifest refresh (every 5 minutes) to pick up endpoint changes without API restart. If an endpoint is removed from the manifest, remove its route on the next refresh.
7. API auth/rate-limiting middleware applies to proxied routes identically to native routes. Proxied routes are not exempt from CORS, rate limiting, or security headers.

**Accept:**
- Manifest fetched at startup. Routes dynamically created.
- Each route proxies to marine service, wraps in envelope, returns.
- No marine routes when URL not configured.
- Runtime failure serves cached data (or 503 if no cache).
- Manifest refreshes periodically; removed endpoints are de-registered.
- Proxied routes subject to same auth/rate-limiting/CORS as native routes.

### T6.2 — Implement response envelope wrapping and unit conversion

- **Owner:** `clearskies-api-dev`
- **Files:** `companion_proxy.py`

**Do:**
1. Marine service returns raw data in SI units (meters, seconds, Celsius).
2. Companion proxy wraps in standard API envelope (`data`, `stationClock`, `freshness`, `units`).
3. Apply unit conversion: SI → operator display units per existing unit conversion pipeline.

**Accept:**
- Proxied responses wrapped in standard envelope.
- Unit conversion applied correctly.

### T6.2b — Write companion proxy tests

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-api/tests/`

**Do:**
1. Write tests for the manifest handler: verify manifest parsing, route creation from manifest entries, handling of malformed manifests.
2. Write tests for envelope wrapping: verify raw marine service responses are wrapped in the standard API envelope (`data`, `stationClock`, `freshness`, `units`).
3. Write tests for unit conversion: verify SI → operator display units conversion on proxied responses.
4. Write tests for capability merging: verify marine capabilities appear in `/api/v1/capabilities` when connected, absent when not.
5. All tests use a mock marine service (not a live service).

**Accept:**
- Manifest handler tests pass (parsing, route creation, malformed manifest handling).
- Envelope wrapping tests pass.
- Unit conversion tests pass.
- Capability merging tests pass.
- Tests run with mock marine service, no live dependency.

### T6.3 — Implement capability merging

- **Owner:** `clearskies-api-dev`
- **Files:** Capabilities endpoint code

**Do:**
1. `/api/v1/capabilities` merges marine capabilities from manifest into the response.
2. Marine capabilities appear when service connected, absent when not.

**Accept:**
- Capabilities response includes marine when connected.

### T6.4 — Implement config push

- **Owner:** `clearskies-api-dev`
- **Files:** `endpoints/setup.py`

**Do:**
1. On `/setup/apply`: if `marine_service_url` is configured, POST marine config to `{marine_service_url}/config` with auth.
2. Failure to push logs ERROR but does not fail the apply.

**Accept:**
- Wizard apply → API → marine service `/config` push works.
- Failure does not block apply.

### T6.4b — Migrate marine tests from API repo to marine service repo

- **Owner:** `clearskies-test-author`
- **Files:** `repos/weewx-clearskies-api/tests/`, `repos/weewx-clearskies-marine/tests/`

**Do:**
1. Move existing marine-related tests from `repos/weewx-clearskies-api/tests/` to `repos/weewx-clearskies-marine/tests/`. This includes tests for marine providers, wave physics, enrichment, and marine endpoints.
2. Update imports in moved tests to reference `weewx_clearskies_marine` instead of `weewx_clearskies_api`.
3. Update the API pytest baseline to reflect the reduced test count (marine tests removed).
4. Update the marine service test baseline to include the migrated tests plus the new tests from T4.6 and T5.10.

**Accept:**
- All marine tests moved to marine service repo and passing.
- API pytest baseline updated (lower count, no regressions in remaining tests).
- Marine service test baseline established (migrated + new tests).

### T6.5 — Delete marine endpoints from API (4,245 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** Delete `endpoints/surf.py` (1,317), `beach_profile.py` (881), `marine.py` (1,040), `fishing.py` (510), `beach_safety.py` (497). Also delete `endpoints/tides.py` if it exists as a separate file.

**Do:** Delete all listed files. Remove route registrations from app. Remove dangling imports.

**Note:** If tides are served by `endpoints/marine.py` (which handles all marine list/detail endpoints), no separate `tides.py` deletion is needed — the `marine.py` deletion covers it. Verify before deleting.

**Accept:** All marine endpoint files deleted. No import errors. API starts cleanly.

### T6.6 — Delete marine provider modules from API (~9,517 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** Delete `providers/buoy/`, `providers/tides/`, `providers/marine/`, `providers/wind/`, `providers/ocean/`, `providers/nearshore/`

**Do:** Delete all marine provider directories. Remove from registry. Remove cache warmer entries. Remove imports.

**Accept:** All deleted. No import errors. Cache warmer skips marine.

### T6.7 — Delete wave physics, enrichment, and config code (~13,931 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** All modules from §0.6 sections 4.2, 4.3, 4.4

**Do:** Delete all files. Remove data files moved to marine service. Remove `[nearshore]` pip extra from `pyproject.toml`.

**Accept:** All deleted. `[nearshore]` extra removed. No import errors.

### T6.8 — Delete compute_service.py and compute_client.py (1,042 lines)

- **Owner:** `clearskies-api-dev`
- **Files:** `services/compute_service.py` (681), `services/compute_client.py` (361)

**Do:** Delete both. Remove imports. Remove `surf_compute_host` and `surf_compute_verify_tls` from config. Remove `SURF_COMPUTE_SECRET` references.

**Accept:** Both deleted. No references to compute service in API code.

*T6.9 (api.conf cleanup) moved to Phase 8 as T8.2b — the old Part A API code needs `[swan]` and `surf_compute_host` until the new API is deployed in T8.2. Removing them during Phase 6 while the old code is deployed would break the working Part A fix.*

### Adversarial Audit — Phase 6

- **Owner:** `clearskies-auditor`

**Scope:**
1. **Zero marine code in API:** `grep -rn "swan_runner\|ndbc\|coops\|wavewatch\|hrrr\|gfs\|surfbeat\|swelltrack\|breaker_height\|surf_scorer\|wave_transform\|bathymetry_resolver\|marine_config" repos/weewx-clearskies-api/weewx_clearskies_api/` — zero matches (excluding companion_proxy and config references to `marine_service_url`).
2. Zero hardcoded marine endpoints.
3. Manifest handler works. Envelope wrapping correct. Unit conversion correct.
4. Capability merging works. Config push works.
5. `compute_service.py` and `compute_client.py` deleted.
6. Marine tests migrated to marine service repo (T6.4b).
7. Silent deferral scan across ALL API files.
8. Runtime failure behavior: verify API serves cached data when marine service is unreachable after startup.

### QC Gate 6

- API contains zero marine physics code (grep verified).
- API contains zero marine provider modules (grep verified).
- Companion proxy dynamically mounts routes from manifest.
- Proxied responses wrapped correctly with unit conversion.
- Runtime failure serves cached data (or 503 if no cache).
- Manifest periodic refresh works. Proxied routes subject to auth/rate-limiting.
- Capabilities merged. Config push works.
- Compute service artifacts deleted. Marine tests migrated.
- Auditor: zero unresolved findings.
- Note: api.conf cleanup deferred to T8.2b (after API deploy).

---

## Phase 7 — Wizard/Admin Updates

**Purpose:** Update the config UI for the new marine service architecture.

**Scratch file:** `c:\tmp\marine-sep-P7-scratch.md`

### T7.1 — Rename "Wave Modeling" to "Marine Service" in wizard

- **Owner:** `clearskies-docs-author`
- **Files:** `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_providers.html`, translation files (13 locales)

**Do:** Rename section. Update i18n keys. Update help text.

**Accept:** Wizard shows "Marine Service" not "Wave Modeling". All 13 locales updated.

### T7.2 — Unify URL fields

- **Owner:** `clearskies-docs-author`
- **Files:** `step_providers.html`, `wizard/routes.py`, `endpoints/setup.py`

**Do:**
1. Replace `surf_compute_host` + `service_url` with single `marine_service_url`. Secret field: `MARINE_SERVICE_SECRET`. Update API's `ApplyRequest` Pydantic model.
2. Add a "Same host" checkbox that auto-fills `https://localhost:8780` when checked.

**Accept:** Single URL field. "Same host" checkbox auto-fills localhost URL. Apply payload sends `marine_service_url`. API Pydantic model accepts it.

### T7.3 — Update Test Connection

- **Owner:** `clearskies-docs-author` + `clearskies-api-dev`
- **Files:** `step_providers.html`, `endpoints/setup.py`

**Do:** Change to test marine service health: `POST /setup/providers/test-marine` → `GET {marine_service_url}/health`. Returns version, spots, status.

**Accept:** Test Connection tests marine service health. Returns useful info on success/failure.

### T7.4 — Add validation: blank URL is error when marine features enabled

- **Owner:** `clearskies-docs-author`
- **Files:** `step_providers.html`, `wizard/routes.py`

**Do:** Require Marine Service URL when any marine feature is enabled. Validation client-side and server-side.

**Accept:** Validation error shown when marine features enabled but URL blank.

### T7.5 — Update admin providers section

- **Owner:** `clearskies-docs-author`
- **Files:** `admin/providers.html` or `admin/marine.html`, `admin/routes.py`

**Do:** Rename to "Marine Service". Single URL. Secret update. Test connection. Status display.

**Accept:** Admin shows "Marine Service" with unified URL. Test connection works.

### T7.6 — Config push on apply

- **Owner:** `clearskies-docs-author` + `clearskies-api-dev`

**Do:** Wizard/admin apply → API → marine service `/config`. Show push result in UI feedback. Failure does not block local save.

**Accept:** Config push works end-to-end. Success/failure shown in UI.

### Adversarial Audit — Phase 7

- **Owner:** `clearskies-auditor`

**Scope:**
1. "Wave Modeling" appears nowhere in wizard or admin. Only "Marine Service."
2. Single URL field `marine_service_url`, not two URLs.
3. Test Connection tests marine service, not old compute service.
4. Blank URL + enabled marine = validation error.
5. Secret goes to `secrets.env` as `MARINE_SERVICE_SECRET`.
6. Config push works end-to-end.
7. Pydantic model sync — no 422 errors.
8. Silent deferral scan.

### QC Gate 7

- "Marine Service" naming throughout. Single URL field.
- Test Connection works. Validation works.
- Secret in `secrets.env`. Config push works.
- All 13 locales updated. Pydantic models accept new fields.
- Auditor: zero unresolved findings.

---

## Phase 8 — Deploy + Clean Up

**Purpose:** Deploy everything, clean up old architecture artifacts, verify end-to-end.

**Scratch file:** `c:\tmp\marine-sep-P8-scratch.md`

### T8.1 — Deploy marine service to librewxr

- **Owner:** Coordinator (Opus) — with user approval

**Do:**
1. Create deploy script `scripts/deploy-marine.sh`.
2. Clone `weewx-clearskies-marine` on librewxr. Install with `pip install -e ".[nearshore]"`.
3. Install systemd unit. Generate `MARINE_SERVICE_SECRET` on both hosts.
4. Generate TLS cert. Start service on port 8780.
5. Verify: health OK, manifest returned.

**Accept:** Marine service running on librewxr:8780. Health and manifest endpoints working. TLS and auth verified.

### T8.1b — Verify librewxr memory capacity

- **Owner:** Coordinator (Opus)

**Do:**
1. Before deploying the unified marine service alongside old services, check current memory usage on librewxr without the old SWAN+compute services running.
2. Estimate projected memory for the unified marine service based on the component sizes (SWAN runner, provider modules, enrichment pipeline).
3. Evaluate whether LibreWxR main process (3.3 GB) can be moved or its memory reduced to provide headroom.
4. Document: current usage, projected usage, swap pressure assessment.

**Accept:** Unified marine service runs without swap pressure. Memory assessment documented. If headroom is insufficient, document mitigation plan before proceeding.

### T8.2 — Deploy API to weewx

- **Owner:** Coordinator (Opus) — via `scripts/deploy-api.sh`

**Do:** Deploy API with marine code removed and companion proxy added. Verify manifest fetch from `https://192.168.7.22:8780/manifest`, dynamic route mounting.

**Accept:** API deployed and healthy. Manifest fetched. Marine routes available.

### T8.2b — Clean up api.conf

- **Owner:** Coordinator (Opus)
- **Files:** `/etc/weewx-clearskies/api.conf` on weewx

*Moved from Phase 6 (was T6.9). The old Part A API code needed `[swan]` and `surf_compute_host` — removing them before the new API is deployed (T8.2) would break the working Part A fix.*

**Do:**
1. Remove `[swan]` section.
2. Replace `surf_compute_host` + `surf_compute_verify_tls` with `marine_service_url = https://192.168.7.22:8780` in `[providers]`.
3. Store `MARINE_SERVICE_SECRET` in `secrets.env` (replacing `SURF_COMPUTE_SECRET`).

**Accept:**
- `api.conf` has `marine_service_url`, no `[swan]`, no `surf_compute_host`.
- `secrets.env` has `MARINE_SERVICE_SECRET`.

### T8.3 — Deploy dashboard + config UI to weather-dev

- **Owner:** Coordinator (Opus) — via `scripts/redeploy-weather-dev.sh`

**Do:** Deploy dashboard (no changes expected) and config UI (Marine Service naming). Verify surf page and wizard.

**Accept:** Dashboard and config UI deployed. Surf page renders. Wizard shows "Marine Service."

### T8.6 — E2E verification (BEFORE disabling old services)

- **Owner:** Coordinator (Opus)

**Do:**
1. Wait for marine service SWAN cycle.
2. Verify all marine endpoints return data via companion proxy.
3. Verify dashboard renders all marine tabs with real data.
4. This MUST pass before T8.4 disables old services — old services remain as a rollback path until verification succeeds.

**Accept:** All marine endpoints return data. Dashboard renders complete marine page.

### T8.4 — Stop and disable old services on librewxr (AFTER E2E verification)

- **Owner:** Coordinator (Opus) — with user approval

**Prerequisite:** T8.6 (E2E verification) must pass first.

**Do:**
1. Stop and disable `weewx-clearskies-swan` on 8767.
2. Stop and disable `weewx-clearskies-compute` on 8770.
3. Verify ports 8767 and 8770 not listening.

**Rollback:** If E2E verification (T8.6) fails, re-enable old services before investigating.

**Accept:** Old services stopped and disabled. Neither port listening.

### T8.4b — Archive the old SWAN repo on librewxr

- **Owner:** Coordinator (Opus) — with user approval

**Do:**
1. After T8.4 disables the old SWAN service, archive the `weewx-clearskies-swan` repo on librewxr.
2. Move to `/home/ubuntu/repos/archived/weewx-clearskies-swan` to preserve history.
3. Create the `archived/` directory if it does not exist.

**Accept:** Old repo moved to archived directory. Git history preserved. No files left at original path.

### T8.5 — Clean up weewx filesystem (AFTER E2E verification)

- **Owner:** Coordinator (Opus) — with user approval

**Prerequisite:** T8.6 (E2E verification) must pass first.

**Do:**
1. Remove `swan.disabled` from `/usr/local/bin/`.
2. Remove `/var/run/weewx-clearskies/swan/`.
3. Remove `/etc/weewx-clearskies/swan_bathymetry_*.json`.
4. Remove `/etc/weewx-clearskies/spot_profiles/`.
5. Remove `SURF_COMPUTE_SECRET` from `secrets.env`.

**Accept:** No SWAN artifacts on weewx. `secrets.env` has `MARINE_SERVICE_SECRET` only.

### T8.7 — Surfline comparison

- **Owner:** Coordinator (Opus)

**Do:** Compare face height against Surfline. Document results.

**Accept:** Face height within ±30% of Surfline.

### Adversarial Audit — Phase 8

- **Owner:** `clearskies-auditor`

**Scope:**
1. Marine service standalone on librewxr (one service, one port).
2. Old services (8767, 8770) not listening.
3. weewx clean: no SWAN binary, no working dirs, no caches.
4. API clean: zero marine code (grep verification).
5. Manifest registration: all marine endpoints via manifest.
6. Config push: wizard apply → API → marine service.
7. api.conf: `marine_service_url` present, no `[swan]`, no `surf_compute_host`.
8. secrets.env: `MARINE_SERVICE_SECRET` only, no `SURF_COMPUTE_SECRET`.
9. Dashboard renders all marine tabs.
10. Silent deferral scan across ALL repos.

### QC Gate 8 (Part B Final)

- Marine service standalone on librewxr (one port, one service).
- API contains zero marine code (grep verified).
- All marine endpoints via manifest registration.
- Dashboard renders complete marine page with all tabs.
- Config push works. Old services disabled. weewx clean.
- api.conf and secrets.env match target state.
- Silent deferral scan: zero findings across all repos.
- Test baselines hold.
- All governing documents match implementation.

---

## Part B QA — Marine Service Separation Verification

| Check | Method | Pass criteria |
|---|---|---|
| Marine service standalone | `curl -k https://librewxr:8780/health` | `status: ok`, spots listed, last_run populated |
| One service, one port | `ssh librewxr "ss -tlnp \| grep -E '876[0-9]\|8780'"` | Only port 8780 listening |
| API zero marine physics | `grep -rn "swan_runner\|surf_1d_analytical\|surfbeat_runner" repos/weewx-clearskies-api/weewx_clearskies_api/` | Zero matches |
| API zero marine providers | `grep -rn "ndbc\|coops\|nws_marine\|hrrr\|gfs\|ofs" repos/weewx-clearskies-api/weewx_clearskies_api/providers/` | Zero matches |
| Marine endpoints via manifest | API startup log | All 6 endpoints mounted from manifest |
| Marine service runtime failure | Stop marine service, verify API returns last cached response with `freshness.validUntil` in the past | API serves cached data (or 503 if no cache) |
| Dashboard renders marine | Screenshot comparison against current functional state (from Part A QA) | All marine tabs show data, visual parity with Part A |
| Config push works | Wizard apply | API pushes to marine service `/config` |
| No compute service files | `ls repos/weewx-clearskies-api/.../services/compute_*` | No files found |
| No SWAN on weewx | `ssh weewx "ls /usr/local/bin/swan*"` | Nothing found |
| api.conf clean | `grep -E "swan\|surf_compute" api.conf` | No matches; `marine_service_url` present |
| Old services disabled | `systemctl is-enabled weewx-clearskies-swan weewx-clearskies-compute` | Both "disabled" |
| Silent deferral scan | `grep -rn "TODO\|FIXME" {all_modified_files}` + `grep -rn 'pass$' repos/weewx-clearskies-marine/` | Zero findings (pass$ scoped to marine service files only) |
| API pytest baseline | Run baseline command | No regression |
| Dashboard vitest baseline | Run baseline command | No regression |
| Governing docs match | `grep -rn 'surf_compute_host\|compute_service\|SWAN.*subprocess' docs/ARCHITECTURE.md docs/manuals/API-MANUAL.md docs/manuals/OPERATIONS-MANUAL.md docs/manuals/PROVIDER-MANUAL.md` | Zero matches |

---

## Summary

| Phase | Purpose | Key deliverables | Status |
|---|---|---|---|
| **PART A** | | | |
| 1 | Governing Document Updates | ARCHITECTURE.md, ADR-099, API-MANUAL, OPS-MANUAL, PROVIDER-MANUAL | PENDING |
| 2 | Fix TLS + Remote Mode | `verify_tls` config, TLS fix, librewxr sync, remote mode activated | PENDING |
| 3 | Fix Caching + E2E Verify | Caching bug fixed, surf page shows data, Surfline comparison | PENDING |
| **PART B** | | | |
| 4 | Marine Service Scaffold | `weewx-clearskies-marine` repo, provider infra, /health + /manifest + /config, TLS + auth | PENDING |
| 5 | Move Provider Modules | All 29 modules moved (11+12+3+3), pipeline wired, 6 endpoints serving | PENDING |
| 6 | API Companion Proxy | Manifest handler, response wrapping, unit conversion, delete ~28K lines from API | PENDING |
| 7 | Wizard/Admin Updates | "Marine Service" naming, unified URL, test connection, validation, config push | PENDING |
| 8 | Deploy + Clean Up | Marine service deployed, old services removed, weewx cleaned, E2E verified | PENDING |

**Adversarial audit is mandatory for every phase.** No phase closes without the auditor sign-off. No findings may be deferred to a later phase.

**The coordinator keeps this plan updated and checks items off as verified.** After every QC gate, the coordinator updates the phase status from PENDING to COMPLETE with the date and relevant commit hashes.

---

## Execution Log

*(Empty — ready for session notes. Coordinator appends after every commit, QC gate, and state change.)*
