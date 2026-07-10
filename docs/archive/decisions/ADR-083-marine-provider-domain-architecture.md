---
status: Archived — consolidated into PROVIDER-MANUAL.md, ARCHITECTURE.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-083: Marine provider domain architecture

## Context

Clear Skies needs marine/boating, surf, fishing, and beach safety capabilities. The existing provider dispatch registry organizes modules by domain — `"forecast"`, `"alerts"`, `"aqi"`, `"earthquakes"`, `"seeing"`, `"radar"`. Marine data spans three fundamentally different data types with different update cadences, caching strategies, and source APIs:

1. **Wave forecasts** — gridded model output (WaveWatch III, NWPS), updated every 3–6 hours, spatial coverage
2. **Tide predictions & water levels** — harmonic predictions (discrete high/low events) and gauge observations, predictions valid for months, observations every 6–10 minutes
3. **Buoy observations** — point measurements from physical instruments, updated hourly, no forecast capability

Mixing these into a single `"marine"` domain would force a single cache TTL, a single fetch pattern, and a single capability declaration onto data types with incompatible access patterns.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Single `"marine"` domain | Simple registry, one dispatch key | Forces shared cache TTL across 10-min observations and 6-hr predictions. Capability declaration becomes unwieldy. Provider modules become monolithic. |
| Three domains: `"marine"`, `"tides"`, `"buoy"` | Each domain has coherent caching, capability, and fetch pattern. Follows existing pattern where domains map to data types (forecast vs. alerts vs. AQI). | Three registry entries instead of one. |
| Per-source domains (`"ndbc"`, `"coops"`, `"wavewatch"`, etc.) | Maximum granularity | Too fine-grained — domains should represent data types, not providers. Breaks the existing pattern. |

## Decision

Introduce three new provider domains: **`"marine"`** (wave forecasts and marine text), **`"tides"`** (predictions and water levels), **`"buoy"`** (point observations). Each domain follows the existing dispatch registry pattern with its own capability declaration, cache strategy, and provider modules.

## Consequences

- **Dispatch registry** gains three new valid domain strings. Existing domains are unchanged.
- **Provider modules** are organized into three new subdirectories under `providers/`: `providers/marine/`, `providers/tides/`, `providers/buoy/`.
- **Cache TTLs** are domain-appropriate: marine forecasts 30 min, tide predictions 6 hr, tide observations 10 min, buoy observations 60 min.
- **Capability declarations** per domain are coherent — a `"buoy"` provider declares observation fields, a `"marine"` provider declares forecast fields.
- **Future providers** (Xweather maritime, Open-Meteo marine) register under `"marine"` domain alongside NOAA providers, following the existing multi-provider-per-domain pattern.
- **NWS marine text forecasts** live under `"marine"` domain (they're zone-based forecasts, not observations).

### Provider module inventory (v1)

| Domain | Module | Provider ID | Source |
|---|---|---|---|
| `"marine"` | `providers/marine/wavewatch.py` | `wavewatch` | NOAA WaveWatch III via ERDDAP |
| `"marine"` | `providers/marine/nwps.py` | `nwps` | NOAA NWPS GRIB2 |
| `"marine"` | `providers/marine/nws_marine.py` | `nws_marine` | NWS marine zone text forecasts |
| `"marine"` | `providers/marine/nws_srf.py` | `nws_srf` | NWS Surf Zone Forecast text product |
| `"tides"` | `providers/tides/coops.py` | `coops` | NOAA CO-OPS |
| `"buoy"` | `providers/buoy/ndbc.py` | `ndbc` | NOAA NDBC |

### Shared utilities

`providers/_common/nws_zones.py` — marine zone discovery utility (station → CWA → zone list → polygon proximity). Shared by `nws_marine.py`, `nws_srf.py`, and the marine zone alerts extension (ADR-089).

## Acceptance criteria

- [ ] Dispatch registry accepts `"marine"`, `"tides"`, and `"buoy"` as valid domain strings without error
- [ ] A provider module with `DOMAIN = "marine"` registers at startup when marine config is present
- [ ] A provider module with `DOMAIN = "tides"` registers at startup when marine config is present
- [ ] A provider module with `DOMAIN = "buoy"` registers at startup when marine config is present
- [ ] No existing provider registration is disrupted (existing domains unchanged)
- [ ] Provider directory structure matches the layout above

## Implementation guidance

- **Registry change:** If `services/dispatch.py` uses an enum or allowlist, add the three new strings. If open-ended, verify no validation rejects unknown domains.
- **Directory creation:** `providers/marine/`, `providers/tides/`, `providers/buoy/` with `__init__.py` files.
- **No new endpoints in this ADR.** Domain architecture only — endpoints are defined per their respective implementation phases.
- **Out of scope:** Provider module implementations (Phase 1–2), enrichment processors (Phase 3–4), endpoints (Phase 5), dashboard pages (Phase 7).

## References

- Related ADRs: ADR-038 (data-provider module organization), ADR-017 (provider-response caching)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §5–6
- Research: `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` §3
