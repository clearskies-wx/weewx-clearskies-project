---
status: Accepted
date: 2026-05-26
deciders: shane
amends: ADR-005
supersedes: ADR-019
---

# ADR-041: Realtime service becomes BFF (Backend-for-Frontend)

## Context

The dashboard connects to two backends: the API (REST at `/api/v1/*` via Caddy) and the realtime service (SSE at `/sse`). Unit conversion needs to happen somewhere — splitting it between API and dashboard means two implementations and duplicated logic. MQTT field names arrive with unit suffixes (`outTemp_F`, `windSpeed_mph`) that need stripping and conversion before the dashboard can use them.

The realtime service already sits on the front-end host and handles the SSE path. Adding REST proxying and unit conversion to it creates a single gateway where all outbound data passes through one conversion layer.

ADR-034 places the API on the weewx host (internal network). Today Caddy proxies `/api/v1/*` directly to the API. Moving that proxy responsibility into the BFF means the API is no longer directly browser-accessible — the BFF mediates all dashboard traffic.

## Options considered

| Option | Verdict |
|---|---|
| A. Realtime as BFF — proxy + unit conversion + SSE | **Selected.** One gateway, one conversion layer. |
| B. Unit conversion in API | Wrong service — API is already complex (30+ endpoints, providers). Doesn't solve MQTT suffix problem. |
| C. Unit conversion in dashboard (client-side) | Duplicates logic for REST and SSE. Every component needs unit knowledge. Can't compute Beaufort/comfort index without thresholds. |
| D. New standalone BFF service | New service to maintain. Realtime already occupies the right topology position. |

## Decision

The realtime service (`weewx-clearskies-realtime`) becomes the dashboard's single backend gateway. It:

1. **Proxies REST requests** to the upstream API on the weewx host (catch-all `/api/v1/*` forward, not route-by-route).
2. **Serves SSE** from MQTT/direct input (unchanged from ADR-005).
3. **Applies unit conversion** to ALL outbound data — both proxied REST responses and SSE events pass through the same conversion layer.

**Amends ADR-005:** Adds BFF responsibility (proxy + unit conversion). Input mode decision (direct vs MQTT) is unchanged.

**Supersedes ADR-019:** "No server-side conversion" becomes "BFF converts to operator display units." The API still passes raw archive values to the BFF — the API itself does no conversion.

## Consequences

- **Caddy routing changes:** `/api/v1/*` routes to the BFF (`realtime:8766`) instead of directly to the API. `/sse` routing unchanged.
- **Dashboard has one connection point:** The front-end host where the BFF runs. No direct browser→API traffic.
- **API stays internal:** weewx host, not directly browser-accessible. Strengthens ADR-034 topology.
- **Service growth:** Realtime grows from ~1,200 LOC to ~2,500–3,000 LOC. Still a single-purpose service (dashboard gateway), not a monolith.
- **New dependency:** `httpx` for upstream API communication.
- **Health probes:** Must include upstream API connectivity check alongside existing MQTT/adapter status.
- **Latency:** One extra network hop for REST (BFF → API over LAN). Negligible for weather data.
- **Availability:** BFF down = both REST and SSE unavailable. Same risk profile as any reverse proxy; health checks monitor it.

## Implementation guidance

### New config sections in `realtime.conf`

```ini
[api]
upstream_url = https://weewx-host:8765
timeout = 30
tls_verify = false
```

### New files

- `proxy.py` — httpx async client, catch-all `/api/v1/{path:path}` route, forwards request and applies unit conversion to JSON responses.
- `units/` module — see ADR-042.
- `mqtt_fields.py` — suffix detection and stripping, see ADR-042.

### Modified files

- `app.py` — mount proxy routes, wire unit conversion to both proxy responses and SSE events.
- `config/settings.py` — add `[api]` and `[units]` config sections.
- `health.py` — add upstream API connectivity probe to readiness check.

### Caddy routing change

```
# Before (current)
reverse_proxy /api/v1/* {$CLEARSKIES_API_URL}

# After (BFF)
reverse_proxy /api/v1/* realtime:8766
```

### Out of scope

- Direct mode implementation (ADR-005, separate work item).
- Wizard changes (Phase 5 of the plan).

## References

- Amends: [ADR-005](ADR-005-realtime-architecture.md) (realtime architecture)
- Supersedes: [ADR-019](ADR-019-units-handling.md) (units handling — no server-side conversion)
- Related: [ADR-034](ADR-034-deployment-topology-default.md) (deployment topology), [ADR-037](ADR-037-inbound-traffic-architecture.md) (inbound traffic)
- Research: [brief-realtime-audit.md](../planning/briefs/brief-realtime-audit.md), [brief-mqtt-field-names.md](../planning/briefs/brief-mqtt-field-names.md)
