---
status: Accepted
date: 2026-07-16
deciders: shane
---

# ADR-092: Hot-reload configuration without API restart

## Context

Every configuration change — editing a marine location, changing a provider, updating branding — currently requires a full API process restart:

1. `POST /setup/apply` writes `api.conf` to disk.
2. `POST /setup/restart` sends SIGTERM to the API process.
3. systemd restarts the process from scratch.
4. The cache warmer runs for **~2 minutes**, making outbound HTTP calls to every configured provider (NWS, Xweather, NDBC, CO-OPS, etc.) to re-populate the cache.
5. During this entire window the API is **offline** — visitors get connection refused, SSE streams drop, the dashboard shows errors.

This was acceptable for the wizard's one-time initial setup. It is completely unacceptable for ongoing admin operations. An operator editing a site title should not take their weather site offline for 2 minutes. An operator managing marine locations — adding, editing, deleting — should not trigger a full restart per save.

The marine admin save is the worst case: it also runs synchronous NWS WFO lookups and CUDEM bathymetry downloads during `POST /setup/apply` *before* the restart, adding network latency on top of the 2-minute restart.

### Current write paths

| Admin action | Write mechanism | Restart? | Effect |
|---|---|---|---|
| Marine location save/delete | `POST /setup/apply` → `POST /setup/restart` | Yes — full SIGTERM + 2-min cold start | Change takes effect, but site is offline for 2+ min |
| Provider / branding / earthquake / radar / etc. | `update_managed_region()` directly to `.conf` on disk | No | Change written to disk but **does not take effect** until next restart — operator doesn't know |
| Wizard first-run apply | `POST /setup/apply` → `POST /setup/restart` | Yes | Acceptable — one-time operation |

Both non-restart paths are broken: one causes 2-minute outages, the other silently doesn't apply. The root cause is the same: the API has no mechanism to reload configuration from disk without a full process restart.

## Decision

Add a **hot-reload endpoint** (`POST /setup/reload`) that re-reads `api.conf` from disk and swaps configuration in-memory without killing the process. No port unbind, no cache eviction, no SSE drops, no downtime.

### Reload scope

Config sections are classified into two tiers:

**Tier 1 — Hot-reloadable** (module-level globals, swappable via existing `wire_*()` functions):

| Config section | Wire function | Notes |
|---|---|---|
| `[marine]` | `wire_marine_config()`, `wire_tides_config()`, `wire_surf_config()`, `wire_fishing_config()`, `wire_beach_safety_config()` | Also re-resolve grid groups and station distances |
| `[alerts]` | `wire_alerts_settings()` | Including marine alert radius/zones |
| `[aqi]` | `wire_aqi_settings()` | |
| `[earthquakes]` | `wire_earthquakes_settings()` | |
| `[forecast]` | `wire_forecast_settings()` | NWS UA contact only; provider swap is Tier 2 |
| `[radar]` | `wire_radar_settings()` | |
| `[seeing]` | `wire_seeing_settings()` | |
| `[branding]` | `wire_branding_settings()` | |
| `[social]` | `wire_social_settings()` | |
| `[charts]` | Re-parse `charts.conf`, update charts config | |
| `[units]` | Rebuild `UnitTransformer` | |
| `[geographic_features]` | `wire_geographic_features_settings()` | |
| `[freshness]` | Update freshness defaults | |

**Tier 2 — Restart required** (process-level state that cannot be swapped safely):

| Config section | Why |
|---|---|
| `[database]` | SQLAlchemy engine, connection pool, reflected schema |
| `[api] bind_host / bind_port` | Uvicorn listener socket |
| `[tls]` | TLS context bound to uvicorn |
| `[input]` | DirectAdapter thread, Unix socket connection |
| `[logging]` | Logger configuration, handlers |
| Provider *identity* change (e.g., NWS → Xweather) | Provider module import + capability registration |

When `POST /setup/reload` detects a Tier 2 change, it returns a response indicating a restart is required, with the specific reason. The admin UI can then prompt the operator ("Database settings changed — a restart is required to apply this change. Restart now?") instead of silently restarting.

### Classifying new config sections

When new functionality is added to the API that introduces a config section or extends an existing one, the developer must classify it at implementation time:

**Default is Tier 1 (hot-reloadable).** New config sections are hot-reloadable unless they meet one of the Tier 2 criteria below. This is not optional — "I didn't think about reload" is not an acceptable reason for a section to require restart.

**Tier 2 criteria — a section requires restart only if it:**
1. Creates process-level resources that cannot be replaced at runtime (thread pools, socket listeners, DB engine/connection pools, TLS contexts).
2. Requires re-importing a module or re-registering a fundamentally different code path (e.g., swapping from NWS forecast provider to Xweather — different module, different capability declaration, different HTTP client configuration).
3. Modifies state that the Python runtime reads once and caches (environment variables read via `os.environ` at import time, logging handler configuration).

**If none of those apply, it is Tier 1.** The implementation must include:
- A `wire_*()` function (or extension of an existing one) that accepts the new config and replaces the module-level state.
- Registration in `reload_config()`'s section dispatch so the reload endpoint knows to call it.
- A test that verifies the section reloads correctly (config changes, call reload, verify new behavior).

**Where to record the classification:** The Tier 1/Tier 2 tables in this ADR are the reference. When a new section is added, update the appropriate table. The `reload_config()` function's section dispatch is the code-level enforcement — a section not registered there will not reload, and the reload response will flag it as `restart_required`.

### Endpoint contract

```
POST /setup/reload
Auth: proxy-auth (X-Clearskies-Proxy-Auth)

Response 200:
{
  "status": "reloaded",
  "reloaded_sections": ["marine", "alerts", "branding"],
  "restart_required": false
}

Response 200 (partial — Tier 2 changes detected):
{
  "status": "partial",
  "reloaded_sections": ["marine", "alerts"],
  "restart_required": true,
  "restart_reason": "Database configuration changed — restart required to apply."
}
```

### Implementation approach

1. **New function `reload_config()` in `__main__.py` or a new `config/reload.py` module.** Re-reads `api.conf` via `load_settings()`, diffs against current settings, calls the appropriate `wire_*()` functions for changed sections. Thread-safe: the existing `wire_*()` functions assign module-level globals atomically (Python GIL protects single-assignment).

2. **`POST /setup/reload` endpoint in `setup.py`.** Calls `reload_config()`, returns the list of reloaded sections and whether a restart is still needed.

3. **Admin and marine save routes call `/setup/reload` instead of `/setup/restart`.** The admin response shows "Settings applied" (instant) instead of "API is restarting... please wait 2 minutes."

4. **Wizard apply uses reload-or-restart based on what changed.**
   - **First-run apply** (no prior `api.conf`): always restart. Database, TLS, bind address, and provider identity are all being set for the first time. The 2-minute wait is acceptable exactly once.
   - **Re-run apply** (prior `api.conf` exists): the wizard diffs the new payload against the current config. If only Tier 1 sections changed (e.g., operator re-ran to add a marine location, change branding, or tweak units), it calls `/setup/reload` — no restart, no downtime. If any Tier 2 section changed (e.g., operator changed the database host or switched forecast provider), it calls `/setup/restart` and shows the restart-wait UI. The diff logic lives in the API's reload endpoint, not in the wizard — the wizard calls `/setup/reload`, and if the response says `restart_required: true`, the wizard then calls `/setup/restart`.

5. **Marine apply: skip redundant network calls.** `_resolve_marine_wfo()` and `_resolve_marine_bathymetry()` should only run for locations whose coordinates changed, not for every save. This is independent of hot-reload but compounds the problem.

### Cache warmer interaction

The cache warmer runs as a background thread with its own schedule. On hot-reload:

- **Marine config change:** The warmer's `marine_config` reference is updated. Next scheduled marine warm uses the new config. No immediate re-warm needed — cached marine data for unchanged locations is still valid.
- **Provider credential change:** The warmer continues using cached data until the next scheduled warm, which will use the new credentials. No immediate re-warm needed.
- **No cache eviction on reload.** Existing cached data remains valid. The warmer's schedule is unaffected.

### What this does NOT change

- The wizard's first-run apply flow (still uses restart — Tier 2 by definition).
- The cache warmer's startup behavior (still runs on fresh process start).
- The API's `POST /setup/restart` endpoint (still exists for Tier 2 changes and external tooling).
- How `secrets.env` is read (env vars are process-level; secret changes remain Tier 2 unless we add explicit re-read logic).

### What this DOES change beyond admin

- **Wizard re-run apply:** previously always restarted. Now calls `/setup/reload` first; only falls back to `/setup/restart` when the reload response indicates Tier 2 changes. An operator re-running the wizard to add a marine location or change branding no longer takes the site offline.

## Consequences

**Positive:**
- Admin config changes apply in < 1 second instead of 2+ minutes.
- Zero downtime for Tier 1 config changes (the vast majority of admin operations).
- Operators can iterate on marine locations, branding, provider settings without taking their site offline.
- SSE streams stay connected through config changes.
- Cache stays warm — no cold-call penalty for visitors after config changes.

**Negative:**
- Additional code path to maintain and test (reload logic alongside startup logic).
- Potential for reload bugs where old state leaks (mitigated by the existing `wire_*()` pattern which fully replaces module globals).
- Tier 2 changes still require restart — operator needs to understand the distinction. The API communicates this explicitly in the reload response.

## Implementation guidance

- The `wire_*()` functions already exist and are idempotent — they replace module-level globals. The reload function calls them in the same order as `__main__.py`'s startup sequence for the changed sections.
- Thread safety: Python's GIL makes single-reference assignment atomic. The `wire_*()` pattern (assign a new object to a module global) is safe for concurrent readers. No locking needed for the common case.
- For marine config specifically, `marine_location_resolver.resolve_grid_groups()` and `resolve_station_distances()` must be re-called after the config swap.
- The `BackgroundCacheWarmer` holds a reference to `marine_config`. On reload, either update the warmer's reference or have the warmer re-read from the module global on each warm cycle.

## Acceptance criteria

1. `POST /setup/reload` re-reads `api.conf` and applies Tier 1 changes without process restart.
2. Admin marine save completes in < 3 seconds (no restart, no 2-minute wait).
3. Admin provider/branding/earthquake saves take effect immediately (no "change written but not active" gap).
4. SSE streams remain connected through a reload.
5. Visitors experience zero downtime during Tier 1 config changes.
6. Tier 2 changes return `restart_required: true` with a human-readable reason.
7. Wizard first-run apply continues to use restart (unchanged).
8. Wizard re-run apply uses reload when only Tier 1 sections changed; falls back to restart only for Tier 2 changes.
9. Cache remains warm through reload — no cold-call penalty.
10. New config sections added to the API must be classified as Tier 1 or Tier 2, include a `wire_*()` function if Tier 1, and update the tier tables in this ADR.

## References

- ARCHITECTURE.md §"API startup time: ~2 minutes"
- ARCHITECTURE.md §"API endpoints — Setup endpoints"
- OPERATIONS-MANUAL.md §"Cache warmer"
