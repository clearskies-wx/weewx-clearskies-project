# Stack Repo Rework Plan — Per-Repo Container Architecture

**Created:** 2026-05-23
**Drives:** ADR-034 (revised 2026-05-23), Phase 5 pre-ship testing
**Repo:** weewx-clearskies-stack (`C:\CODE\weather-belchertown\repos\weewx-clearskies-stack`)

---

## Background

ADR-034 was revised on 2026-05-23 to mandate per-repo containers with a two-host default topology:

- **weewx host:** API container only (co-located with weewx archive DB)
- **Front-end host:** dashboard (init container) + realtime + Caddy containers

The stack repo currently has a single monolithic `docker-compose.yml` that bundles all 4 services on one host. This plan reworks the stack repo to match the revised ADR-034, then deploys and tests on the real infrastructure (API on weewx LXD container, frontend on weather-dev LXD container).

### Architecture recap (decided this session)

- **Each repo = its own Docker container.** API, realtime, and dashboard each have their own Dockerfile in their repo. Stack repo provides orchestration only.
- **Realtime has two modes, both valid:**
  - **Direct mode** (single-host): weewx extension hooks `NEW_LOOP_PACKET` via Unix socket. No broker needed. Default for all-in-one operators.
  - **MQTT mode** (multi-host): subscribes to MQTT broker. Required when realtime is on a different host from weewx.
  - Neither mode reads the DB. The API is the only component that touches the database.
- **Our API** is the HTTP/security layer over weewx's raw database. weewx has no REST API — just an internal Python plugin system for extensions.
- **ADR-005** is correct as-is (both modes documented). No changes needed.

### Current stack repo structure

```
weewx-clearskies-stack/
├── docker-compose.yml          ← monolithic, all 4 services (REWORK)
├── Caddyfile                   ← assumes all services same Docker network (REWORK)
├── .env.example                ← single-host vars (REWORK)
├── INSTALL.md                  ← has cross-host section but wrong topology (REWORK)
├── CONFIG.md                   ← env var reference (UPDATE)
├── README.md                   ← architecture diagram, quick-start (UPDATE)
├── weewx_clearskies_config/    ← config wizard Python package (REVIEW for topology)
│   ├── wizard/                 ← multi-step setup wizard
│   │   ├── topology.py         ← topology detection (REVIEW)
│   │   ├── routes.py           ← wizard step routing
│   │   ├── state.py            ← wizard state management
│   │   └── ...
│   ├── templates/wizard/       ← HTML templates for wizard steps
│   │   ├── step_mqtt.html      ← MQTT config step (already exists)
│   │   └── ...
│   ├── config/                 ← config reader/updater
│   └── ...
├── dev/                        ← dev stack (MariaDB/Redis) — UNCHANGED
├── examples/                   ← HA configs, reverse-proxy, systemd — REVIEW
├── tests/                      ← wizard tests — UPDATE after changes
└── ...
```

### Key existing files (current content captured in session)

The lead has read verbatim content of: `docker-compose.yml`, `Caddyfile`, `.env.example`, `INSTALL.md`, `CONFIG.md`, `README.md`. The lead also has the API and realtime Dockerfile details (ports, volumes, health checks, entrypoints). This context is required to draft exact file contents for each task.

---

## Execution rules

- **Lead = Opus, orchestration + judgment only.** Sonnet agents do all implementation.
- **Every agent gets exact file content in its prompt.** No agent makes architectural decisions — they write what the lead specifies.
- **QC gate after every task.** Lead reads the written files and verifies correctness before proceeding.
- **One deliverable per task.** Small scope, clear completion criteria.
- **PowerShell commits:** `git commit -s -F c:\tmp\<task>-msg.txt`

---

## Task Plan

### Phase A: Compose file restructuring

**Task A1: Create `weewx-host/docker-compose.yml`**
- API container only
- Mounts: config dir, weewx.conf, weewx.sdb (SQLite) or DB connection (MariaDB), ephemeris cache
- Health check on port 8081
- Build context points to `../../weewx-clearskies-api` (sibling repo)
- Image: `ghcr.io/clearskies-wx/weewx-clearskies-api:${CLEARSKIES_VERSION:-0.1.0}`
- Env file: secrets.env
- Network: exposes API port to host (for cross-host access from frontend Caddy)
- Volumes: `clearskies-cache` (ephemeris)
- Agent deliverable: one file
- QC: verify ports, volumes, health check match API Dockerfile

**Task A2: Create `weewx-host/.env.example`**
- API-specific vars only: `WEEWX_CONF_PATH`, `WEEWX_DB_PATH`, `CLEARSKIES_CONFIG_DIR`, `CLEARSKIES_SECRETS_FILE`, `CLEARSKIES_VERSION`, `CLEARSKIES_API_PORT` (default 8765)
- Agent deliverable: one file
- QC: verify all vars referenced in A1 compose file are documented

**Task A3: Create `frontend-host/docker-compose.yml`**
- Three services: dashboard (init), realtime, caddy
- Dashboard: copies SPA to `dashboard-dist` volume, exits
- Realtime: mounts config dir, env_file secrets, health check on 8082
- Caddy: mounts Caddyfile, `dashboard-dist` volume, caddy-data, caddy-config. Ports 80/443.
- Caddy depends_on dashboard (completed) + realtime (healthy)
- NO API service — Caddy proxies API requests to remote weewx host
- Build contexts point to sibling repos
- Agent deliverable: one file
- QC: verify no API service, correct depends_on, volume sharing between dashboard and caddy

**Task A4: Create `frontend-host/Caddyfile`**
- Serves dashboard static files from `/srv/dashboard` with SPA fallback
- Proxies `/api/v1/*` to `{$CLEARSKIES_API_URL}` (env var pointing to weewx host, e.g. `https://192.168.7.20:8765`)
- Proxies `/sse` to `realtime:8766` (local Docker network)
- Security headers (same as current)
- gzip encoding
- Agent deliverable: one file
- QC: verify API proxy uses env substitution, SSE proxy is local

**Task A5: Create `frontend-host/.env.example`**
- Frontend-specific vars: `CLEARSKIES_DOMAIN`, `CLEARSKIES_API_URL` (REQUIRED — URL of API on weewx host), `CLEARSKIES_HTTP_PORT`, `CLEARSKIES_HTTPS_PORT`, `CLEARSKIES_VERSION`, `CLEARSKIES_CONFIG_DIR`, `CLEARSKIES_SECRETS_FILE`
- Agent deliverable: one file
- QC: verify `CLEARSKIES_API_URL` is documented as required, all vars referenced in A3/A4 are present

### Phase B: Single-host reference config

**Task B1: Create `single-host/docker-compose.yml`**
- All 4 services (api + realtime + dashboard + caddy) on one machine
- Essentially current docker-compose.yml reorganized into the `single-host/` directory
- Caddy proxies to local Docker network names (`api:8765`, `realtime:8766`)
- Direct mode for realtime (weewx on same host)
- Agent deliverable: one file
- QC: verify it's a correct all-in-one merge

**Task B2: Create `single-host/Caddyfile` and `single-host/.env.example`**
- Caddyfile: same as current (local Docker DNS names)
- .env.example: merged superset of weewx-host + frontend-host vars
- Agent deliverable: two files
- QC: verify Caddyfile uses local DNS names, env example covers all vars

### Phase C: Example configs

**Task C1: Create `config/api.conf.example`**
- Documented example with all sections the API reads
- Lead must check API settings module to draft accurate content
- Agent deliverable: one file
- QC: verify settings match what the API actually reads

**Task C2: Create `config/realtime.conf.example`**
- Documented example with MQTT settings (broker host, port, topic, credentials)
- Direct mode settings (socket path)
- Mode selection (`input_mode = mqtt` or `input_mode = direct`)
- Agent deliverable: one file
- QC: verify settings match what the realtime service reads

### Phase D: Cleanup and migration

**Task D1: Archive old root-level compose + Caddyfile**
- Move `docker-compose.yml` → `archive/docker-compose.yml.pre-split`
- Move `Caddyfile` → `archive/Caddyfile.pre-split`
- Move `.env.example` → `archive/.env.example.pre-split`
- Agent deliverable: files moved
- QC: verify old files removed from root, archived

**Task D2: Update root `.gitignore`**
- Ensure `.env`, `config/secrets.env`, and any per-host `.env` files are gitignored
- Agent deliverable: updated file
- QC: verify patterns cover all host directories

### Phase E: Documentation updates

**Task E1: Rewrite `INSTALL.md`**
- Two-host deployment as primary path (matches ADR-034 default)
- Single-host as alternative
- Native install unchanged
- Step-by-step for each host directory
- Correct cross-host topology: API on weewx host, everything else on frontend host
- Lead provides outline with key details; agent writes full doc
- Agent deliverable: updated file
- QC: verify accuracy against compose files, correct topology description

**Task E2: Update `CONFIG.md`**
- Reflect per-host env files
- Add `CLEARSKIES_API_URL` documentation
- Reference example configs in `config/` directory
- Agent deliverable: updated file
- QC: verify all env vars documented

**Task E3: Update `README.md`**
- Architecture diagram reflects two-host default
- Quick-start updated for new directory structure
- Repo structure section reflects `weewx-host/`, `frontend-host/`, `single-host/` directories
- Agent deliverable: updated file
- QC: verify diagram accuracy, links valid

### Phase F: Wizard review

**Task F1: Audit wizard topology code**
- Read `weewx_clearskies_config/wizard/topology.py` and related files
- Determine if the wizard's topology detection and config writing need updates for two-host model
- Agent deliverable: audit report (read-only, no changes)
- QC: lead decides if wizard changes are needed now or deferred

**Task F2: Update wizard if needed** (conditional on F1)
- Only if F1 audit reveals breaking issues
- Otherwise defer wizard updates to post-v0.1 — the wizard is Phase 2 deferred scope anyway
- Agent deliverable: TBD based on F1 findings
- QC: lead reviews changes

### Phase G: Commit, push, sync

**Task G1: Commit all stack repo changes**
- Lead writes commit message to `c:\tmp\stack-rework-msg.txt`
- Single commit covering all compose/config/doc changes
- Push to GitHub

**Task G2: Sync to weather-dev and weewx**
- Run sync script for stack repo
- Verify repos on both hosts are at new HEAD

### Phase H: Deploy and test

**Task H1: Deploy API on weewx host**
- SSH into weewx, navigate to stack repo's `weewx-host/` directory
- Create `.env` from `.env.example` with real values
- Create `config/api.conf` and `config/secrets.env`
- Run `docker compose up -d`
- Verify: health check passes, `/api/v1/station` returns data
- Agent deliverable: deployment report

**Task H2: Deploy frontend on weather-dev**
- SSH into weather-dev, navigate to stack repo's `frontend-host/` directory
- Create `.env` from `.env.example` with real values (including `CLEARSKIES_API_URL` pointing to weewx host)
- Create `config/realtime.conf` and `config/secrets.env`
- Run `docker compose up -d`
- Verify: all containers healthy, dashboard loads, SSE streams
- Agent deliverable: deployment report

**Task H3: End-to-end testing**
Run through the full test checklist:

#### Dashboard (on weather-dev, served by Caddy)
- [ ] Build succeeds (dashboard init container exits 0)
- [ ] All pages render: Now, Forecast, Charts, Records, Almanac, About, Legal, NOAA Reports
- [ ] Chart tabs load data (homepage + monthly/annual/average climate)
- [ ] NOAA report table parser renders
- [ ] Hero section displays
- [ ] Branding fetches from API (cross-host request via Caddy)
- [ ] Sunrise/sunset theme auto-switching
- [ ] i18n infrastructure loads (locale files, `<html lang>`)
- [ ] Weather Icons render via npm package
- [ ] Font is Inter (not Geist)

#### API (on weewx host)
- [ ] `/api/v1/branding` returns defaults
- [ ] `/api/v1/archive?interval=day` works for chart tabs
- [ ] `/api/v1/station` includes `default_locale`
- [ ] `/api/v1/pages/{slug}/content` serves custom page content
- [ ] `/metrics` on health port 8081 when enabled
- [ ] DEVELOPMENT.md present and accurate
- [ ] Accessible from weather-dev Caddy over network

#### Realtime (on weather-dev, MQTT mode)
- [ ] Connects to MQTT broker on weewx host
- [ ] SSE keepalive comments every 15s
- [ ] SSE streams real weather data

#### Stack integration
- [ ] weewx-host compose builds and runs API container
- [ ] frontend-host compose builds and runs dashboard + realtime + caddy
- [ ] Caddy proxies `/api/v1/*` to weewx host API
- [ ] Caddy proxies `/sse` to local realtime
- [ ] Caddy serves dashboard static files with SPA fallback
- [ ] `.env.example` files document all required variables

### Phase I: Resume prompts

**Task I1: Update `phase5-preship-testing.md`**
- Reflect completed stack rework
- Updated repo HEADs
- Test results
- Remaining Phase 5 work

**Task I2: Generate `phase5-remaining.md`**
- Pre-ship accessibility audit (ADR-026 §5.8)
- CHANGELOG.md updates for v0.1.0 across all repos
- Tag v0.1.0 releases
- Production cutover planning
- Logo incorporation planning

---

## Access details

- **weather-dev SSH:** `ssh weather-dev "..."`
  - Or via ratbert: `ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc '...'"`
- **weewx SSH:** `ssh ratbert "lxc exec weewx -- bash -c '...'"`
- **API (weewx):** `https://192.168.7.20:8765/api/v1/current`
- **Dashboard (weather-dev):** `http://192.168.2.113:<port>`
- **MQTT broker:** on weewx host (check `realtime.conf` for broker details)

## Repos

| Repo | Local path | Branch | HEAD |
|------|-----------|--------|------|
| weewx-clearskies-stack | `C:\CODE\weather-belchertown\repos\weewx-clearskies-stack` | main | `628c9b6` |
| weewx-clearskies-api | `C:\CODE\weather-belchertown\repos\weewx-clearskies-api` | main | `64653ec` |
| weewx-clearskies-realtime | `C:\CODE\weather-belchertown\repos\weewx-clearskies-realtime` | main | `0dfed14` |
| weewx-clearskies-dashboard | `C:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard` | main | `1468bf0` |
| weather-belchertown (meta) | `C:\CODE\weather-belchertown` | master | `ebb6e29` |

## Key references

- **ADR-034** (revised): `docs/decisions/ADR-034-deployment-topology-default.md` — per-repo containers, two-host default
- **ADR-005**: `docs/decisions/ADR-005-realtime-architecture.md` — direct + MQTT modes, both valid
- **ADR-027**: `docs/decisions/ADR-027-config-and-setup-wizard.md` — wizard steps, mode selection
- **ADR-038**: `docs/decisions/ADR-038a-wizard-api-channel.md` — wizard talks to API, not DB
- **Process rules:** `rules/clearskies-process.md`
- **Coding rules:** `rules/coding.md`

## Session rules reminders

- **Lead = Opus, orchestration + judgment only.** Sonnet does all implementation.
- **Read the ADRs before touching architecture.** ADRs are authoritative.
- **Do NOT use AskUserQuestion.** Ask in plain text.
- **PowerShell commits:** `git commit -s -F c:\tmp\<task>-msg.txt`
- **Sync to weather-dev:** push to GitHub, then `scripts/sync-to-weather-dev.sh`

---

## Decision log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-23 | ADR-034 revised: per-repo containers, two-host default | Each repo builds its own image independently. A dashboard CSS tweak doesn't rebuild the API. |
| 2026-05-23 | ADR-005 confirmed correct: direct + MQTT both valid | Direct mode (Unix socket) for single-host, MQTT for multi-host. Neither reads the DB. |
| 2026-05-23 | Our API is necessary | weewx has no REST API — just internal Python plugin hooks. Our API provides HTTP/JSON security layer. |
| 2026-05-23 | MQTT required for multi-host realtime | Direct mode requires co-location with weewx (Unix socket). MQTT is weewx's native out-of-process transport. |
| 2026-05-23 | Wizard updates deferred pending F1 audit | Wizard is Phase 2 deferred scope. Only update if F1 finds breaking issues. |
