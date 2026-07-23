---
status: Proposed
date: 2026-07-22
deciders: shane
supersedes:
superseded-by:
---

# ADR-099: Marine Service Separation — Unified Standalone Companion Service

## Context

The Clear Skies marine system grew to approximately 28,000 lines of code embedded directly in the API repo (`weewx-clearskies-api`). This included:

- 11 data provider modules (NDBC buoy, CO-OPS tides, NWS marine weather, NWS NWPS surf, WaveWatch III, GRIB2 processor, HRRR wind, GFS wind, OFS ocean, ERDDAP ocean, SWAN orchestration) — 9,517 lines
- 12 wave physics modules (SWAN runner, domain sizing, SWAN INPUT formatting, spectral parsing, SwellTrack 1D analytical model, SwellTrack per-transect pipeline, SurfBeat IG strip, wave setup, bathymetry resolver, shelf boundary, SWAN-to-SwellTrack handoff, bathymetry enrichment) — 11,397 lines
- 3 enrichment/scoring modules (breaker height, surf scorer, wave transform) — 1,325 lines
- 3 config/service support modules (marine config, location resolver, weather cache) — 1,209 lines
- 5 marine API endpoint handlers (surf, beach profile, marine, fishing, beach safety) — 4,245 lines
- 2 compute service artifacts (compute_service.py on librewxr:8770, compute_client.py in the API) — 1,042 lines

**Prior partial extraction (failed state):** An earlier attempt extracted SWAN to a standalone service on `librewxr:8767` (`weewx-clearskies-swan`) and a compute service on `librewxr:8770` (`compute_service.py`). This extraction was incomplete: the API still contained all the original marine code. The result was two fragmented services with a broken integration:

1. The API probes the SWAN service at startup via `[swan] service_url = https://192.168.7.22:8767`
2. TLS certificate verification fails: `SSL: CERTIFICATE_VERIFY_FAILED certificate verify failed: self-signed certificate`
3. The API falls back to running SWAN locally on the weewx host
4. Local SWAN full runs fail at Level 3; quick updates produce "1 spot resolved, 0 spots cached" due to a handoff bug
5. No SWAN data → no SwellTrack → no SurfBeat → no surf forecast
6. Surf endpoint returns `forecast: []`, beach profile returns 404
7. Dashboard surf page shows no data

The surf page was broken for 24+ hours at the time this ADR was drafted.

**Root cause:** Embedding 28,000 lines of compute-intensive, resource-hungry marine physics in the API creates maintenance and operational problems:
- A failed SWAN run blocks or degrades API responsiveness
- Marine physics dependencies (eccodes, wgrib2, SWAN binary, xarray, netCDF4) inflate the API's dependency surface
- The marine system needs dedicated compute (memory, cores) that conflicts with the API's role as a lightweight request handler
- The fragmented two-service model (8767 + 8770) adds operational complexity without providing a clean separation

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Keep marine code in the API** | No migration work; one process to manage | 28K lines unsustainable; compute-heavy SWAN runs degrade API latency; dependency surface bloat; resource contention between API request handling and SWAN execution; scales poorly as more marine locations are added |
| **B. Two half-services (current state: SWAN on 8767 + compute on 8770)** | SWAN already deployed on librewxr; compute service already running | Two ports, two auth tokens, two systemd units, fragmented coordination; API still contains all the original marine code — no size reduction; broken TLS integration causing the current 24+ hour outage; compute service serves SwellTrack/SurfBeat only (NDBC, CO-OPS, NWS, etc. still in API); no coherent boundary |
| **C. Unified standalone marine service (`weewx-clearskies-marine`, port 8780)** | Clean boundary: all marine code in one service, zero marine code in API; one port, one auth token, one systemd unit; API companion proxy is generic and reusable; manifest-driven route registration enables zero-API-change extensibility; marine service can run on dedicated compute hardware; same provider module pattern as API (familiar to developers) | Requires migrating 28K lines; two-phase approach (Part A: fix TLS + Part B: migrate code) adds elapsed time before the clean architecture is in place; new repo to maintain |

## Decision

Separate all marine code into a standalone companion service (`weewx-clearskies-marine`) that runs on port 8780. The API communicates with the marine service via authenticated HTTP (TLS). The marine service registers its endpoints via a manifest (`GET /manifest`); the API dynamically mounts those routes under `/api/v1/` at startup. Operator configuration uses a single `marine_service_url` key in `api.conf [providers]`, replacing both the former `surf_compute_host` (port 8770) and `[swan] service_url` (port 8767).

This work is divided into two parts:

- **Part A (Phases 1–3):** Fix the broken integration between the current API and the SWAN service on librewxr. The surf page must show real data before Part B begins. Part A is a targeted patch — it does not restructure the architecture.
- **Part B (Phases 4–8):** Build the proper unified marine service, migrate all marine code, delete marine code from the API, and update the config UI.

## Consequences

**Positive:**
- API shrinks by ~28,735 lines (all marine physics, providers, and endpoints removed). The API gains only ~200–300 lines (generic companion proxy).
- One marine service, one port (8780), one auth token (`MARINE_SERVICE_SECRET`). Replaces two fragmented services on two ports with two auth tokens.
- Marine service runs on dedicated compute hardware (librewxr) without resource contention with the API.
- Manifest-driven route registration: adding a new marine endpoint requires zero API code changes.
- Same provider module pattern in both repos: CAPABILITY declaration, `fetch()` interface, canonical field mapping, cache TTL management. A developer who knows the API provider pattern can navigate the marine service without re-learning the architecture.
- Dashboard is unchanged. The dashboard calls `/api/v1/*` endpoints; it has no knowledge of the marine service.
- Generic companion proxy pattern is reusable for future companion services (e.g., seismic, air quality offloading).

**Negative / trade-offs:**
- Two repos to maintain instead of one. Version synchronization is the operator's responsibility.
- Marine service migration is a significant code move (~28K lines) with risk of import breakage and behavioral regressions. Golden response fixtures (captured before migration) mitigate this risk.
- The two-phase approach means the intermediate state (Part A) retains all original marine code in the API alongside the new integration — temporarily increasing complexity.

**Implementation impact:**
- API repo: add `services/companion_proxy.py`, delete all marine provider/physics/endpoint modules, delete `compute_service.py` and `compute_client.py`, remove `[marine]` and `[nearshore]` pip extras
- Marine service repo: new repo `weewx-clearskies-marine` with all moved modules, `GET /manifest`, `GET /health`, `POST /config`, TLS, auth
- Config: `api.conf [providers]` gains `marine_service_url`; `secrets.env` gains `MARINE_SERVICE_SECRET`; `api.conf [swan]` section is removed; `surf_compute_host` and `surf_compute_verify_tls` keys are removed
- Wizard/admin: rename "Wave Modeling" to "Marine Service"; unify URL fields to single `marine_service_url`; update Test Connection to test marine service health

**Alerts stay in the API.** Marine alerts (coastal flood advisory, high surf advisory, rip current statement) are served by the API's unified NWS alert system (`providers/alerts/nws.py`). They are never moved to the marine service, regardless of marine service installation state. This is unconditional — alerts are a core feature, not a marine extension.

## Acceptance criteria

- [ ] Marine service (`weewx-clearskies-marine`) deployed on a single port (8780), TLS, authenticated with `MARINE_SERVICE_SECRET`
- [ ] `GET /manifest` returns complete endpoint manifest with all 6 marine endpoint paths, methods, upstream paths, cache TTLs
- [ ] API companion proxy mounts all 6 marine routes dynamically from the manifest at startup
- [ ] API `providers/` directory contains zero files from the marine provider subdirectories (`marine/`, `tides/`, `buoy/`, `wind/`, `ocean/`, `nearshore/`) — verified by grep
- [ ] API `services/` directory contains zero SWAN physics files (`swan_runner.py`, `swan_domain.py`, `swan_formats.py`, `swan_spectral.py`, `surf_1d_analytical.py`, `surf_1d_pipeline.py`, `surfbeat_runner.py`, `wave_setup.py`, `bathymetry_resolver.py`, `shelf_boundary.py`, `transect_handoff.py`) — verified by grep
- [ ] `compute_service.py` and `compute_client.py` deleted from API repo — verified by ls
- [ ] `api.conf` on the weewx host contains `marine_service_url` in `[providers]`, no `[swan]` section, no `surf_compute_host`
- [ ] `secrets.env` on the weewx host contains `MARINE_SERVICE_SECRET`, no `SURF_COMPUTE_SECRET`
- [ ] Ports 8767 and 8770 are not listening on librewxr after Part B deployment
- [ ] `GET /api/v1/surf/huntington-city-beach-pier` returns non-empty `forecast` array via companion proxy
- [ ] `GET /api/v1/capabilities` includes marine capabilities when marine service connected; excludes them when not
- [ ] Wizard shows "Marine Service" (not "Wave Modeling"); single `marine_service_url` field; Test Connection tests marine service `/health`
- [ ] Dashboard surf page renders complete data (wave height, conditions, 72h forecast, beach profile)
- [ ] Marine alerts (`GET /api/v1/alerts`) continue to work regardless of marine service connection state

Checked at: (a) per-phase QC gates (Phases 1–8 per MARINE-SERVICE-SEPARATION-PLAN.md), (b) adversarial audit at every phase close, (c) Part B QA checklist.

## Implementation guidance

**Part A (immediate — fix the outage):**
- T2.1: Add `swan_verify_tls` config option to `marine_config.py` `[swan]` section. Pass `verify=swan_verify_tls` to all `httpx.get()` calls in `configure_remote_mode()` and `_remote_health_loop()`. Pattern: follow `compute_client.py`'s existing `verify=verify_tls` approach.
- T2.3: Set `swan_verify_tls = false` in `[swan]` section of `/etc/weewx-clearskies/api.conf` on weewx (self-signed cert, same VLAN, same pattern as `surf_compute_verify_tls = false`).
- Verify: API logs show "SWAN: remote mode active" not "CERTIFICATE_VERIFY_FAILED".

**Part B (architecture migration):**
- Phase 4: Create `weewx-clearskies-marine` repo. Mirror API repo structure exactly. Implement `/health`, `/manifest`, `/config`, TLS, auth.
- Phase 5: Move all marine provider and physics modules. Update imports. Wire pipeline: SWAN → SwellTrack → SurfBeat → scoring → endpoints.
- Phase 6: Implement `services/companion_proxy.py` in the API. Implement `/setup/apply` config push. Delete all marine code from API.
- Phase 7: Rename wizard/admin "Wave Modeling" → "Marine Service". Replace two URL fields with single `marine_service_url`.
- Phase 8: Deploy marine service on librewxr:8780. Stop old services (8767, 8770). Clean up weewx filesystem.

**Port assignments:**
- Port 8780: marine service (replaces 8767 + 8770)
- Port 8767: SWAN standalone (eliminated in Part B)
- Port 8770: compute service (eliminated in Part B)

**Config key changes:**
- `api.conf [providers] marine_service_url` replaces both `surf_compute_host` and `[swan] service_url`
- `secrets.env MARINE_SERVICE_SECRET` replaces `SURF_COMPUTE_SECRET`
- `api.conf [swan]` section is removed entirely

**Out of scope:**
- Dashboard changes — the dashboard calls `/api/v1/*` and is unaware of the marine service
- Alert system changes — marine alerts stay in the API unconditionally
- LibreWxR changes — radar/satellite tile serving is unrelated

## References

- Plan: `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — full phase breakdown, acceptance criteria per task, QC gates
- Brief: `docs/planning/briefs/SURF-MODEL-SEPARATION-BRIEF.md` — audit findings that triggered this ADR
- ARCHITECTURE.md: marine companion service section, port registry (port 8780), Services table
- Related ADRs: ADR-093 (SWAN + SwellTrack replaces NWPS), ADR-095 (SWAN model corrections), ADR-096 (surf scoring restructure), ADR-097 (beach profile endpoint)
- Archived: ADR-083 (marine provider domain architecture), ADR-086 (multi-spot marine location model), ADR-089 (marine zone alerts in alert system)
