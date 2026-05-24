# First-Run UX — Implementation Plan

**Created:** 2026-05-23
**Drives:** ARCHITECTURE.md gaps #1–3; ADR-027, ADR-038a
**Status:** Draft — awaiting user review

---

## Problem

When an operator installs Clear Skies and visits the site before running the wizard, they see a wall of red "Unable to load" errors on every tile. The API crashes without `api.conf`, the config UI isn't accessible through the site, and the dashboard has no way to detect or communicate the unconfigured state.

## Goal

Operator installs the stack, visits the site, and is automatically guided to the setup wizard. Zero red errors. Zero manual port/URL hunting.

## Dependencies and order

```
Task A: API life-support mode          (no dependencies — must be first)
Task B: Config UI Dockerfile           (no dependencies — parallel with A)
Task C: Compose file updates           (depends on B)
Task D: Caddyfile updates              (depends on C)
Task E: Dashboard unconfigured detect  (depends on A and D)
Task F: QC + end-to-end test           (depends on all above)
```

Tasks A and B are independent and can run in parallel.
Tasks C and D are sequential (compose before Caddy).
Task E needs both A (health endpoint) and D (wizard accessible via Caddy).

---

## Task A: API life-support mode

**Repo:** weewx-clearskies-api
**Goal:** API starts and stays running even when `api.conf` does not exist. Returns a clear "not configured" signal on the health port so the dashboard and wizard can detect the state.

### What changes

1. **`config/settings.py`** — `load_settings()` catches `FileNotFoundError` instead of letting it propagate. Returns a minimal `Settings` object with `configured = False`, bind addresses, health port, and TLS defaults. No database, no providers, no weewx.conf path.

2. **`app.py`** — `create_app()` checks `settings.configured`. When `False`:
   - Mount `/setup/*` router (already exists — wizard needs these)
   - Mount `/health` on main port returning `{"status": "ok", "configured": false}`
   - Do NOT mount any `/api/v1/*` data routers (no DB, no providers)
   - Do NOT run secret-leak guard, DB probe, schema reflection, provider init
   - All other paths return `503 {"type": "not-configured", "title": "Clear Skies is not configured", "detail": "Run the setup wizard to configure this installation."}` (RFC 9457)

3. **`health.py`** — Health app on port 8081:
   - `/health/live` → `200 {"status": "ok"}` (always — process is alive)
   - `/health/ready` → `200 {"status": "not_configured", "configured": false}` when unconfigured (NOT 503 — the service IS functioning, it's just awaiting setup)
   - `/health/ready` → normal readiness logic when configured

4. **`__main__.py`** — Startup flow becomes:
   - Try to load settings
   - If configured: normal startup (DB, providers, all routers)
   - If not configured: minimal startup (health + setup only), log INFO "No config found — running in setup mode. Visit the setup wizard to configure."

### What does NOT change

- TLS still active in both modes (self-signed cert generated regardless)
- Trust token still generated and printed to terminal
- `/setup/handshake` still works (wizard's first step)
- Health port still loopback-only by default

### Acceptance criteria

- `api.conf` absent → API starts, logs "setup mode", prints trust token
- `GET /health/ready` on port 8081 → `200 {"status": "not_configured", "configured": false}`
- `GET /api/v1/current` → `503` RFC 9457 with `type: "not-configured"`
- `POST /setup/handshake` → works normally
- `api.conf` present → API starts normally, all data endpoints work, `/health/ready` returns `{"configured": true}`
- Existing tests pass (no regressions)

### Agent prompt requirements

- Agent gets: exact file paths, exact behavior spec, exact response shapes
- Agent does NOT make architectural decisions — writes what the lead specifies
- QC: lead reads the changed files and runs tests

---

## Task B: Config UI Dockerfile

**Repo:** weewx-clearskies-stack
**Goal:** Containerize the config UI so it can be added to compose files.

### What to create

`Dockerfile` in the stack repo root (or `weewx_clearskies_config/Dockerfile`):

- Base: `python:3.12-slim-bookworm` (match API pattern)
- Install: `pip install .` from the stack repo (installs `weewx-clearskies-config` package)
- Non-root user: `clearskies` (UID 1000, match API/realtime pattern)
- Expose: `9876`
- Health check: `python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9876/health')"` (config UI already has `GET /health`)
- Entrypoint: `python -m weewx_clearskies_config --bind 0.0.0.0 --port 9876`
  - Binds all interfaces inside the container (Caddy handles external exposure)
  - No `--tls` — Caddy handles TLS termination
- Volume mounts expected: `/etc/weewx-clearskies/` (config dir, shared with API/realtime)

### Acceptance criteria

- `docker build -t clearskies-config .` succeeds
- Container starts, prints bootstrap URL
- `GET /health` returns 200
- Container can reach the API container for `/setup/*` calls

---

## Task C: Compose file updates

**Repo:** weewx-clearskies-stack
**Goal:** Add `config` service to `frontend-host/` and `single-host/` compose files.

### Changes

**`frontend-host/docker-compose.yml`** — add service:
```yaml
  config:
    build:
      context: ../../weewx-clearskies-stack
      dockerfile: Dockerfile
    image: ghcr.io/inguy24/weewx-clearskies-config:${CLEARSKIES_VERSION:-0.1.0}
    restart: unless-stopped
    volumes:
      - ${CLEARSKIES_CONFIG_DIR:-./config}:/etc/weewx-clearskies
    env_file: ${CLEARSKIES_SECRETS_FILE:-./config/secrets.env}
    environment:
      - CLEARSKIES_API_URL=${CLEARSKIES_API_URL}
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9876/health')"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
```

**`single-host/docker-compose.yml`** — same service, but `CLEARSKIES_API_URL` points to local `api:8765`.

Caddy `depends_on` updated to include `config` (service_healthy).

### Acceptance criteria

- `docker compose up -d` starts the config service alongside the others
- Config service health check passes
- Config service can reach the API's `/setup/*` endpoints

---

## Task D: Caddyfile updates

**Repo:** weewx-clearskies-stack
**Goal:** Caddy proxies `/wizard`, `/bootstrap`, `/login`, `/admin` to the config UI service.

### Changes

**`frontend-host/Caddyfile`** and **`single-host/Caddyfile`** — add before the SPA fallback:

```caddyfile
    handle /wizard* {
        reverse_proxy config:9876
    }
    handle /bootstrap* {
        reverse_proxy config:9876
    }
    handle /login* {
        reverse_proxy config:9876
    }
    handle /logout* {
        reverse_proxy config:9876
    }
    handle /admin* {
        reverse_proxy config:9876
    }
```

The config UI also needs its static files proxied:
```caddyfile
    handle /static/* {
        reverse_proxy config:9876
    }
```

Order matters: these `handle` blocks must come BEFORE the `/*` SPA fallback.

### Acceptance criteria

- `https://site.example.com/wizard` → serves the wizard UI (not the React SPA's 404)
- `/bootstrap`, `/login`, `/admin/config` all route correctly
- `/` still serves the React SPA
- `/api/v1/*` still proxies to API
- `/sse` still proxies to realtime

---

## Task E: Dashboard unconfigured detection

**Repo:** weewx-clearskies-dashboard
**Goal:** Dashboard detects unconfigured state and redirects to `/wizard` instead of showing error wall.

### What changes

1. **New component: `SetupGuard`** (wraps the app in `App.tsx`)
   - On mount, fetches the API health endpoint: `GET /health/ready` (via the Caddy proxy or direct)
   - If response contains `"configured": false` → redirect browser to `/wizard`
   - If response is a network error (API completely unreachable) → show a static "Clear Skies is starting up..." page with a retry button
   - If response contains `"configured": true` → render children (normal dashboard)
   - Cache the result in sessionStorage so it doesn't re-check on every navigation

2. **`App.tsx`** — wrap `<Routes>` with `<SetupGuard>`

3. **Health endpoint URL** — the dashboard needs to know where to check:
   - In Docker: Caddy proxies `/api/v1/*` already. Add a Caddy route for the health check, OR
   - Simpler: the API's main port already has `GET /health` returning `{"status": "ok"}`. In unconfigured mode this returns `{"status": "ok", "configured": false}`. Dashboard checks `/api/v1/../health` or we add a Caddy route for `/health`.
   - Simplest: API serves `GET /api/v1/status` in both modes returning `{"configured": bool}`. Dashboard checks this.

**Recommended:** Add `GET /api/v1/status` to the API that works in both configured and unconfigured mode. Returns `{"configured": true/false}`. Caddy already proxies `/api/v1/*`. No new Caddy routes needed.

### Acceptance criteria

- API unconfigured → visit site → redirected to `/wizard` (no red errors)
- API configured → visit site → normal dashboard loads
- API unreachable → visit site → friendly "starting up" message, not error wall

---

## Task F: QC + end-to-end test

**Lead-driven, no agent.**

1. Wipe config on weather-dev
2. `docker compose up -d` (single-host)
3. Visit the site in browser
4. Verify: redirected to wizard, no errors
5. Complete the wizard
6. Verify: dashboard loads with real data
7. Restart the stack — verify dashboard still loads (sessionStorage cache doesn't interfere)

---

## Execution rules

- **Lead = Opus, orchestration + judgment only.** Sonnet agents do all implementation.
- **Every agent gets exact file content in its prompt.** No agent makes architectural decisions.
- **QC gate after every task.** Lead reads the written files and verifies.
- **One deliverable per task.** Small scope, clear completion criteria.
- **Tasks A and B run in parallel.** C depends on B. D depends on C. E depends on A and D.

---

## Key files

| Task | Repo | Files changed |
|------|------|--------------|
| A | api | `config/settings.py`, `app.py`, `health.py`, `__main__.py` |
| B | stack | `Dockerfile` (new) |
| C | stack | `frontend-host/docker-compose.yml`, `single-host/docker-compose.yml` |
| D | stack | `frontend-host/Caddyfile`, `single-host/Caddyfile` |
| E | dashboard | `src/components/SetupGuard.tsx` (new), `src/App.tsx` |
| E | api | `app.py` (add `/api/v1/status` endpoint) |

---

## Follow-up tasks (not blocking first-run UX, but must not be forgotten)

### FU-1: Eliminate config UI → API code coupling

**Problem:** `weewx_clearskies_config/wizard/schema.py` and `wizard/routes.py` import `STOCK_COLUMN_MAP` directly from `weewx_clearskies_api.db.reflection`. This violates ADR-038a (wizard talks to API via HTTP, not by importing its code) and forces the Dockerfile to copy the entire API source tree into the config UI build.

**Fix:** The API's `GET /setup/schema` endpoint already returns column schema. The wizard should get the stock column map from that endpoint response instead of importing the Python constant. Remove the `weewx-clearskies-api` dependency from the stack repo's `pyproject.toml`. Remove the `COPY weewx-clearskies-api/` line from the Dockerfile.

**Files:** `weewx_clearskies_config/wizard/schema.py` (lines 304, 467), `weewx_clearskies_config/wizard/routes.py` (line 1883), `pyproject.toml` (remove dep), `Dockerfile` (remove COPY).

**When:** After first-run UX ships. Not blocking v0.1 — the build-context workaround works.
