# Clear Skies — System Architecture

This is the current-state map for Clear Skies: component boundaries, service
placement, network paths, and authoritative ports. It describes what is
running, not implementation history or future work.

Use the component manuals for prescriptive behavior and detailed procedures.
Use ADRs for the decisions behind the system, planning documents for open work,
and development reference material for local paths and host-specific commands.

## Canonical components

| Component | Responsibility | Repository or ownership |
|---|---|---|
| API | Data access and transformation, display-unit conversion, enrichment, setup, and the sole client of the marine service. | `weewx-clearskies-api` |
| Dashboard | Browser presentation and visualization. | `weewx-clearskies-dashboard` |
| Config UI | Setup wizard and ongoing operator administration. | `weewx-clearskies-stack` |
| Caddy | Browser ingress, TLS termination, routing, and static dashboard delivery. | Caddy |
| Redis | API response cache. | Redis |
| Marine service | Marine providers and marine-model execution. | `weewx-clearskies-marine` |
| Loop relay | weewx runtime extension that makes loop packets available to the API. | `weewx-clearskies-extension` |
| weewx XType extensions | Runtime extensions that provide additional observations to weewx. | `weewx-clearskies-truesun`, `weewx-clearskies-feelslike` |

The API owns station data, configuration, conversion, and enrichment. The
Dashboard owns presentation. The Config UI collects and administers operator
configuration. The marine service owns marine data and model providers and the
marine model chain. The API retains unified alerts and its boundary
responsibilities. Caddy owns browser ingress and routing.

## Current service inventory

| Service or runtime component | Runs where | Current role |
|---|---|---|
| API | weewx host | REST and server-sent event API; data transformation; configuration authority; marine-service proxy. |
| Dashboard | front-end host | Static browser application. |
| Config UI | front-end host | Operator setup and administration. |
| Caddy | front-end host | Only browser-facing entry point. |
| Redis | weewx host | API cache. |
| Marine service | `librewxr.shaneburkhardt.com` in this installation | Unified marine providers, WW3, SWAN, and SwellTrack. |
| Loop relay and XType extensions | inside the weewx process | Non-container weewx runtime components. |

The normal installation is a two-host topology: the API and Redis share the
weewx host; Caddy, the Dashboard, and Config UI share the front-end host. The
marine service may run with the API or on a separate compute host. This
installation uses the separate host shown above.

## Authoritative port registry

| Port | Service | Binding and use |
|---|---|---|
| 80 | Caddy | Public HTTP ingress. |
| 443 | Caddy | Public HTTPS and HTTP/3 ingress. |
| 8765 | API | API and server-sent event traffic behind Caddy. |
| 8081 | API health | Loopback-only liveness, readiness, and metrics. |
| 9876 | Config UI | Internal service behind Caddy. |
| 6379 | Redis | Loopback-only API cache. |
| 8780 | Marine service | Authenticated TLS service-to-service traffic. |

## Topology and traffic flow

```
Browser
   |
   v
Caddy (front-end host)
   |-- static files --> Dashboard
   |-- operator routes --> Config UI
   `-- API and event routes --> API (weewx host) --> Redis
                                      |
                                      `--> Marine service (when configured)
                                                |
                                                `--> NOAA and other marine data sources

weewx process --> loop relay --> API
```

Browsers reach Clear Skies only through Caddy. The Dashboard, Config UI,
admin pages, and third-party clients never contact the marine service directly.
The API is the marine service's only Clear Skies client: it authenticates,
proxies, converts, enriches, and presents marine responses. This invariant
keeps one authenticated boundary and one configuration authority.

## Marine model chain

The marine service owns the chain from source boundary and forcing through
published output:

```
NOAA boundary and forcing
  -> project WW3 deep-water leg
  -> SWAN L2-L4 nearshore model
  -> SwellTrack handoff-to-shore model
  -> published cache and API-proxied response
```

WW3 owns the project deep-water leg. SWAN starts at L2, has no L1 compute
level, and does not own the break zone. SwellTrack receives the nearshore
handoff and owns the path to shore. The [Provider Manual](manuals/PROVIDER-MANUAL.md)
defines provider and model behavior; the [API Manual](manuals/API-MANUAL.md)
defines the API boundary; the [Operations Manual](manuals/OPERATIONS-MANUAL.md)
defines deployment and health procedures.

**A1 producer and direct handoff (deployed; live recovery still in progress,
2026-08-31).** One frozen setup derives three separate producer contracts: the
NOAA-to-WW3 active-cell mapping, the WW3-to-SWAN L2 boundary curve, and diagnostic
output points. After the WW3 march, the runner uses a native point inventory only
while the run is active, then validates and promotes boundary and diagnostic
transfers as one pair. The production L2 input uses the direct WW3 boundary; it
does not require retired L1 spectrum files after a configuration rebuild. A live
L2 run accepted the regenerated boundary and retained an approximately 1.0 m
component. Publication was refused only because the required +7 through +72 hour
continuation transfer was absent. This is not completion of A0, A0-I, A1, R1, R2,
or the recovery plan. The source of truth for the exact contracts, remaining
evidence, and retention limits is the recovery plan §8A.

**Recovery order correction (2026-09-01).** A cold or wiped run first completes its
six-hour WW3 leg, then builds that same cycle's +6 through +96 hour continuation
from the leg restart and verifies the complete +0 through +72 hour boundary. Only
then may SWAN start. Missing, short, corrupt, or wrong-cycle continuation data
refuses the new cycle before SWAN; the six-hour transfer is never used alone as a
production boundary. Open A0, A0-I, R1, R2, and recovery evidence gates remain open.

## Configuration boundary

The API is the operator-configuration source of truth. It validates and stores
the configuration, then pushes the marine subset to the marine service. The
marine service does not read API configuration files directly. Configuration
keys, secret handling, and recovery procedures are in the
[Operations Manual](manuals/OPERATIONS-MANUAL.md).

## Authority routing

| Need | Authoritative source |
|---|---|
| API contracts, units, conversion, and companion proxy behavior | [API Manual](manuals/API-MANUAL.md) and [OpenAPI contract](contracts/openapi-v1.yaml) |
| Providers, marine data, and model behavior | [Provider Manual](manuals/PROVIDER-MANUAL.md) |
| Deployment, security, configuration, health, and updates | [Operations Manual](manuals/OPERATIONS-MANUAL.md) |
| Dashboard behavior, refresh, i18n, and performance | [Dashboard Manual](manuals/DASHBOARD-MANUAL.md) |
| UI patterns and visual rules | [Design Manual](manuals/DESIGN-MANUAL.md) |
| Current and future work | [Planning documents](planning/) |
| Architectural decisions and rationale | [ADR index](decisions/INDEX.md) |
| Local repository paths, hosts, and development commands | [Development reference](../reference/clearskies-dev.md) |

## Current deployment note

This installation runs `weewx-clearskies-marine.service` on
`librewxr.shaneburkhardt.com` and uses port 8780. The root architecture
document intentionally contains no phase tracker or known-gaps register;
planning owns open work and ADRs and archived plans preserve history.
