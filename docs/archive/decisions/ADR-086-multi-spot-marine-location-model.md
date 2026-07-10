---
status: Archived — consolidated into OPERATIONS-MANUAL.md, API-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-086: Multi-spot marine location model

## Context

Clear Skies' existing data model is single-station: one weewx station, one set of coordinates, one weather observation stream. Marine activities are location-diverse — an operator near the coast may monitor multiple distinct locations for different activities (surfing at one beach, fishing from a pier, boating from a harbor). Each location needs different data presented differently.

This differs from the multi-station scope decision (ADR-011, which deferred multi-station weewx support). Marine locations are not additional weather stations — they are named points where the operator wants marine data aggregated from nearby NOAA sources (buoys, tide gauges, wave models, forecast zones).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Single marine location (nearest to weewx station) | Simplest. No multi-location config. | Operator with 3 surf spots must pick one. Fishing pier 20 miles from surf beach gets same data. Doesn't match how coastal users think. |
| Multiple locations, single activity per location | Each location has one purpose. | Same beach used for surfing and fishing requires two config entries with identical coordinates. Redundant data fetching. |
| Multiple locations, multiple activities per location | Matches reality — one beach can serve surfing, swimming, fishing simultaneously. Shared data fetching for co-located activities. | Most complex config. Wizard UX must handle multi-activity selection. |

## Decision

Operators configure named **marine locations** (spots), each with coordinates and one or more enabled activities. Activity-specific configuration is per-location. Nearby NOAA stations (NDBC, CO-OPS, NWS zones) are auto-discovered or operator-selected per location.

### Location configuration structure

Each location has:
- **Identity:** `id` (slug), `name` (display), `lat`/`lon`
- **Activities:** One or more of `marine`, `surf`, `fishing`, `beach_safety` — which capabilities each activity enables is defined in ADR-090
- **Station associations:** `ndbc_station_ids`, `coops_station_ids`, `nws_marine_zone_id` — auto-discovered at setup, operator-overridable
- **NWPS binding:** `nwps_wfo` (WFO code), `nwps_cg_grid` (CG grid identifier) — auto-determined from coordinates
- **Station distance:** `station_distance_km` — haversine distance from the weewx station to this location, computed at config time. Used by the weather data source selector to determine whether to use the weewx station's own atmospheric data (close locations) or the nearest NDBC buoy's atmospheric data (distant locations).

### Activity-specific configuration

**Surf** (`SurfSpotConfig`):
- `beach_facing_degrees` (0–360) — compass direction the beach faces
- `bottom_type` — sand, rock, coral_reef, or mixed
- `beach_slope` — computed from NOAA CUDEM bathymetric profile
- `structures` — list of coastal structures with type, material, dimensions, bearing, distance
- `bathymetric_profile` — stored after CUDEM download (list of distance/depth points)
- `topographic_feature` — point_break, bay_break, headland, or straight_beach
- `directional_exposure` — 8 compass directions, each true/false (which swell directions reach this spot)

**Fishing** (`FishingSpotConfig`):
- `target_category` — saltwater_inshore, bottom_fish, freshwater_sport, or salmonids
- `species` — auto-populated from biogeographic region
- `biogeographic_region` — auto-classified from coordinates

**Beach safety** (`BeachSafetyConfig`):
- `external_links` — operator-provided URLs to local water quality reports, lifeguard schedules, wildlife alerts (displayed as informational resources)

### Auto-discovery at setup

When the operator enters coordinates for a new location:
1. Query NDBC `activestations.xml` — find nearest buoys with distances and sensor capabilities
2. Query CO-OPS metadata API — find nearest tide/water-level stations with distances and products
3. Query NWS `/points` → get CWA → determine NWPS WFO domain and CG grid
4. Query NWS `/zones/coastal` for CWA → find marine zones within configured radius (shared with ADR-089)
5. Download NOAA CUDEM bathymetric profile for surf spots (one-time)
6. Auto-classify biogeographic region for fishing spots

Present discovered stations to the operator for confirmation before saving.

### No data deduplication for free providers

v1 marine providers are all free NOAA sources. Each location fetches its own data independently — no deduplication, no request sharing between nearby locations. Deduplication is only appropriate for metered providers where API call cost is a concern. Deduplicating free provider requests risks degrading data quality by substituting a nearby location's data for the actual location's data. If metered marine providers are added in the future (e.g., Xweather maritime for international coverage), deduplication should be introduced as part of that provider's implementation — not as a location-layer concern.

## Consequences

- **New config file section:** `[marine]` in `api.conf` with `[[locations]]` subsections. Pattern differs from existing single-station config but self-contained within `[marine]`.
- **New config module:** `services/marine_config.py` with dataclasses for `MarineConfig`, `MarineLocation`, `SurfSpotConfig`, `FishingSpotConfig`, `BeachSafetyConfig`, `StructureConfig`, `BathymetryPoint`.
- **Wizard step:** Marine location setup becomes a wizard step (Phase 6) with map-based coordinate entry, station auto-discovery, and activity selection.
- **API endpoints:** Location-aware endpoints (`/marine/{locationId}`, `/surf/{locationId}`, etc.) — defined in Phase 5.
- **Dashboard navigation:** Location picker on marine pages — defined in Phase 7.
- **No impact on existing single-station config.** Marine config is additive and optional.

## Acceptance criteria

- [ ] `MarineConfig` loads from `api.conf` with `[marine]` section containing multiple `[[locations]]`
- [ ] Empty `[marine]` section produces empty `MarineConfig` (no error)
- [ ] Missing `[marine]` section returns `None` from `load_marine_config()` (not error)
- [ ] Invalid config values (out-of-range lat/lon, unknown bottom type, unknown activity) raise clear errors naming the offending field
- [ ] Each location can have 1–4 activities enabled simultaneously
- [ ] `station_distance_km` is computed correctly (haversine) from weewx station coordinates to location coordinates
- [ ] Existing settings tests pass unchanged

## Implementation guidance

- **File:** `services/marine_config.py` — follows existing `services/settings.py` pattern.
- **Config format:** ConfigObj/INI (same as `api.conf`). Example:
  ```ini
  [marine]
    [[locations]]
      [[[wrightsville_beach]]]
        name = Wrightsville Beach
        lat = 34.2085
        lon = -77.7964
        activities = surf, beach_safety, fishing
        ndbc_station_ids = 41110, 41037
        coops_station_ids = 8658163
        nws_marine_zone_id = AMZ250
  ```
- **Validation:** Coordinates in [-90,90] / [-180,180]. Activity strings from allowed set. Bottom type from allowed set. Beach facing in [0, 360).
- **Out of scope:** Auto-discovery implementation (Phase 6 wizard). Endpoint design (Phase 5). Dashboard location picker (Phase 7). What capabilities each activity enables (ADR-090).

## References

- Related ADRs: ADR-083 (domain architecture), ADR-084 (NWPS supplementation), ADR-090 (activity capability matrix)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §8 (location model)
