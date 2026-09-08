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

**Recovery-wave source reconciliation (2026-09-03; source-complete, gates still
open).** The configuration-time grid-sizing chain now builds one `ww3_leg`
derivation from its OSM occupancy and regular datum-converted bathymetry
inputs. It keeps the NOAA-to-WW3 active-cell mapping, one ordered complete
rectangular `CLOSED` L2 transfer curve, and the diagnostic point contract
separate; the native post-`ww3_shel`
inventory is ephemeral, and the final boundary and diagnostic `ww3_outp`
passes are separate. See `services/grid_sizing_chain.py` and
`services/swan_domain.py` in `weewx-clearskies-marine`.

The WW3 producer's paired outputs are selected and recorded only as a complete
boundary/diagnostic pair. A failed or structurally mismatched pair cannot
replace the selected pair. The same source implements direct L2 `BOUNDNEST3`
consumption, the shared full/fast/horizon boundary artifact, and structural
refusal before publication (`service.py`, `services/ww3_runner.py`,
`providers/nearshore/swan.py`). This describes source behavior; A0/A0-I, R1,
R2, and live recovery evidence remain open.

The nearshore path requires one OFS surface-current model (WCOFS for the
current recovery path) whose regular-grid domain contains the complete active
SWAN box. It resamples the
returned U/V fields onto each active SWAN grid, composes same-model records by
valid time and issue cycle, and holds only the terminal WCOFS tail. An absent,
malformed, uncovered, or preflight-failing current input refuses the run; no
alternative provider is selected (`providers/ocean/ofs.py`,
`services/swan_runner.py`, `providers/nearshore/swan.py`).

The runtime state snapshot carries compact attempt identities, stage evidence,
current-forcing summary, selected full-cycle identity, and complete H/D
references without storing forcing arrays. On restart, unobserved evidence is
`unknown`; serving remains `valid`, `stale`, or `unavailable` only when the
selected cache artifact and publication evidence match. The 12-hour fast fill
keeps the selected full-cycle identity while recording its changed-hour
provenance. Same-process WW3 reuse is limited to a matching cycle/input
identity and non-empty verified artifacts; a process restart reruns
conservatively (`state.py`, `service.py`, `providers/nearshore/swan.py`).

**Recovery order correction (2026-09-01).** A cold or wiped run first completes its
six-hour WW3 leg, then builds that same cycle's +6 through +96 hour continuation
from the leg restart and verifies the complete +0 through +72 hour boundary. Only
then may SWAN start. Missing, short, corrupt, or wrong-cycle continuation data
refuses the new cycle before SWAN; the six-hour transfer is never used alone as a
production boundary. Open A0, A0-I, R1, R2, and recovery evidence gates remain open.

**Operator testing reservation (implemented in the current marine source; live
verification and deployment remain pending).** The marine runner also observes
the runtime-only sentinel `/run/weewx-clearskies/marine-test-hold`. A request is
not an idle observation or a reservation by itself: the runner acknowledges it
in `/health` as `modelTestHold.acknowledged` before it gates new full, fast, and
catch-up/horizon dispatch. A model already running is allowed to finish; the
hold does not stop or kill it. While acknowledged, the API continues serving
the last-good output and independent wind assembly continues, while queued
model work remains pending. Removing the sentinel releases the hold on a later
runner iteration. `scripts/run-marine-tests.sh` is the operator wrapper that
requests, verifies, and releases this reservation; it does not deploy, restart,
stop, pull, or push.

## Configuration boundary

The API is the operator-configuration source of truth. It validates and stores
the configuration, then pushes the marine subset to the marine service. The
marine service does not read API configuration files directly. Configuration
keys, secret handling, and recovery procedures are in the
[Operations Manual](manuals/OPERATIONS-MANUAL.md).

### Fishing matrix storage target (not yet shipped)

**TARGET — Fishing and Boating remediation Phase 1; not yet shipped.** Once the
framework receives operator sign-off, the planned operational source will be
one signed-off Excel table at the candidate path
`repos/weewx-clearskies-marine/weewx_clearskies_marine/data/fishing_species_matrix.xlsx`.
It contains only the approved operational lookup fields; it does not contain
research provenance, source identifiers, assessment details, or workflow
status. A target build interface,
`python -m weewx_clearskies_marine.tools.build_fishing_species_matrix`, will
validate the approved headers, types, allowed codes, required fields, unique
keys, FAO-area keys, and conservation flags before atomically replacing the
sibling generated
`repos/weewx-clearskies-marine/weewx_clearskies_marine/data/fishing_species_matrix.sqlite`.
If validation or generation fails, the previous database remains and the build
fails loudly.

The generated database will contain exactly one logical data table. Each species
or practical category has one complete profile, and its `fao_areas` field lists
every applicable FAO area; it is not split into per-area or fallback profiles. The
marine service will open the packaged database read-only and select only the
rows and columns required for the current request. Neither the API nor the
marine service will parse Excel at runtime or materialize the global matrix in
module-level Python dictionaries. Packaging carries the generated SQLite
database, not a runtime Excel reader. The current YAML catalogue and loader
remain only until agreed setup selections and scoring comparison cases are
equivalent, independently reviewed, and live behavior is proved in Phase 4;
only then are the YAML data and loader removed. This section documents a
planned boundary, not a shipped implementation.

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
