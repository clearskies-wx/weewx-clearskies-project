---
status: Accepted
date: 2026-05-27
deciders: shane
supersedes:
superseded-by:
---

# ADR-046: GEM Global Active Faults Database for seismic fault overlay

## Context

The seismic page needs a fault line overlay to give earthquakes geographic context. Plate boundaries alone miss intraplate faults (e.g., Newport-Inglewood, New Madrid, Wasatch) where significant seismic hazard exists.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Peter Bird plate boundaries | Simple, well-known | Too general — misses all intraplate faults |
| USGS Quaternary Faults (QFaults) | Detailed, authoritative | US-only — useless for non-US operators |
| GEM Global Active Faults Database (GAF-DB) | Global coverage, comprehensive, actively maintained | CC-BY-SA 4.0 requires attribution |

## Decision

Use GEM GAF-DB. CC-BY-SA 4.0 license — attribution required, displayed in the map attribution bar. Data bundled with the API as GeoJSON and served radius-clipped to the operator's configured earthquake radius. ~13,000 fault traces globally.

## Consequences

- API bundles ~2 MB GeoJSON (gzipped ~400 KB).
- New endpoint: `GET /api/v1/earthquakes/faults` returns fault features clipped to the configured radius.
- Attribution text in map overlay: `"Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0"`.
- Dashboard renders fault lines as a Leaflet GeoJSON layer.
- Updates: periodic manual refresh from GEM GitHub repo — no auto-update mechanism.

## Implementation guidance

- `data/gem_active_faults.geojson` bundled in the API package.
- `services/faults.py` — loads GeoJSON, clips by haversine radius from station coordinates.
- `endpoints/earthquakes.py` — adds `/earthquakes/faults` route.
- **Fault show/hide toggle** — checkbox in the map card header; default on (`showFaults` state initialised `true`). When unchecked, the GeoJSON layer and the below-map attribution caption are both hidden.
- **Fault metadata popups** — `onEachFeature` calls `layer.bindPopup()` with the fault name (`feature.properties.name`) and slip type (`feature.properties.slip_type`). Both values fall back to localised "unknown" strings when absent.
- **Dual attribution** — both the in-map Leaflet attribution control and the below-map caption render the same API-provided canonical GEM string — `"Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0"` — single-source and consistent. The below-map caption is shown only while the fault layer is visible.
- Out of scope: fault-type styling differentiation (all fault traces rendered in uniform amber — `FAULT_STYLE` applies one colour regardless of slip type), automatic GEM updates.

## References

- GEM GAF-DB GitHub: https://github.com/GEMScienceTools/gem-global-active-faults
- CC-BY-SA 4.0 license: https://creativecommons.org/licenses/by-sa/4.0/
- [ADR-040](ADR-040-earthquake-providers.md) — earthquake providers day-1 set.
- [ADR-015](ADR-015-radar-map-tiles-strategy.md) — Leaflet / OSM map tile strategy.
