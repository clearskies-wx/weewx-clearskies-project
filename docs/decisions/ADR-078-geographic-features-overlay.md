---
status: Accepted
date: 2026-06-29
deciders: shane
supersedes:
superseded-by:
---

# ADR-078: Geographic Features Overlay (OSM via Overpass API)

## Context

The satellite map view needs unfilled vector overlays for political boundaries, major roads, and water features so operators can orient themselves geographically. Free raster tile providers don't offer "lines only on transparent background."

The current approach uses a CSS blend-mode hack: CartoDB `dark_nolabels` tiles are inverted + multiply-blended (`.satellite-features` class in `index.css` with `filter: invert(1) brightness(1.8); mix-blend-mode: multiply`). This produces poor results — bleed-through artifacts, washed-out satellite colors, and feature lines that are too faint to be useful. The hack also downloads full raster tiles when only line geometry is needed.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Raster tile providers with lines-only style** | No backend work | No free provider offers this; paid tiers add per-operator cost and ToS complexity |
| **B. CSS blend-mode on existing tile providers** (current) | No backend work, already implemented | Visual artifacts, washed-out colors, faint lines, downloads full raster tiles unnecessarily |
| **C. Server-side OSM extraction via Overpass API** | Crisp vector lines, per-type styling, no raster artifacts, keyless API, ODbL-compatible, operator controls bounds | Requires new API endpoint + cache; Overpass availability risk (mitigated by 90-day cache) |

## Decision

**Option C.** The API queries the Overpass API for OSM vector data within operator-configured bounds, caches the GeoJSON with a 90-day TTL, and serves it via `GET /api/v1/geographic-features`. The dashboard renders native Leaflet `<GeoJSON>` vector lines — crisp, unfilled, per-feature-type styled. This replaces the CSS blend-mode hack entirely.

## Consequences

- **New API endpoint:** `GET /api/v1/geographic-features` returns a GeoJSON FeatureCollection with a `type` property per feature (`"boundary"`, `"road"`, `"water"`).
- **New config section:** `[geographic_features]` in `api.conf` with `enabled`, `bounds`, `radius_km`, `refresh_days`, `overpass_endpoint`.
- **New service module:** `services/geographic_features.py` following the `services/faults.py` pattern (cache-first, lazy-load, return FeatureCollection).
- **Dashboard changes:** New `<GeoJSON>` layer in `radar-map.tsx` (satellite view only), removal of `SATELLITE_FEATURES_URL` constant and its `<TileLayer>`, removal of `.satellite-features` CSS class.
- **External dependency:** Overpass API (keyless, rate-limited by design). 90-day cache = ~4 queries/year; Overpass availability is not a practical concern. Config allows overriding to a self-hosted instance.
- **License:** ODbL (OpenStreetMap contributors). Attribution in response body.
- **No visual regression risk:** Vector lines are strictly better than the current blend-mode hack.
- **Color tuning required:** The per-type colors (boundaries, roads, water) must be visible against dark satellite tiles without overpowering the weather data. Initial values are starting points — they will be adjusted during visual QC against real satellite imagery. Colors are defined as static `PathOptions` constants in `radar-map.tsx`, making them trivial to tune.

## Acceptance criteria

- [ ] `GET /api/v1/geographic-features` returns a valid GeoJSON FeatureCollection with boundary, road, and water features within configured bounds
- [ ] Second request to the endpoint returns instantly (cache hit; no Overpass query)
- [ ] Cache TTL is 90 days (configurable via `refresh_days`)
- [ ] Endpoint returns empty FeatureCollection (not error) when disabled or on fetch failure
- [ ] Dashboard renders vector lines on satellite view only — not on normal basemap view
- [ ] Per-type styling: boundaries=white, roads=gray, water=blue; all unfilled
- [ ] CSS blend-mode hack fully removed (no `.satellite-features` class, no `dark_nolabels` TileLayer)
- [ ] `ruff check` + `mypy` clean (API), `tsc --noEmit` + `vite build` clean (dashboard)

## Implementation guidance

**API — follow `services/faults.py` pattern:**
- `services/geographic_features.py`: `build_overpass_query(south, west, north, east)` builds Overpass QL extracting admin boundaries (level 2/4), major roads (motorway/trunk/primary), and water (rivers + lakes). `fetch_overpass()` does HTTP POST. `get_geographic_features()` is cache-first via `get_cache()` with key `"geo_features:" + sha256(bounds)` and TTL `refresh_days * 86400`.
- `config/settings.py`: `GeographicFeaturesSettings` class (pattern: `RadarSettings`). Bounds cascade: explicit `bounds` setting → `RadarSettings.librewxr_bounds` → station lat/lon + `radius_km`.
- `endpoints/geographic_features.py`: `GET /api/v1/geographic-features`, returns `{"data": <FeatureCollection>, "attribution": "© OpenStreetMap contributors (ODbL)"}`. Empty FeatureCollection when disabled.
- Register router in `__main__.py`.

**Dashboard — follow `seismic.tsx` fault line pattern:**
- `api/client.ts`: `getGeographicFeatures()` (pattern: `getEarthquakeFaults()`).
- `hooks/useWeatherData.ts`: `useGeographicFeatures()` hook (pattern: `useEarthquakeFaults()`).
- `radar-map.tsx`: `<GeoJSON>` component when `satelliteActive`, static `PathOptions` per type, `interactive={false}`, zIndex 250. Initial color values below are starting points — tune during visual QC against real satellite tiles:
  - Boundaries: `color: '#ffffff'`, `weight: 1.5`, `opacity: 0.7`
  - Roads: `color: '#999999'`, `weight: 1`, `opacity: 0.5`
  - Water: `color: '#4a90d9'`, `weight: 1`, `opacity: 0.6`
- Remove `SATELLITE_FEATURES_URL` const, its `<TileLayer>`, and `.satellite-features` from `index.css`.

**Overpass QL query shape:**
```
[out:json][timeout:60];
(
  relation["boundary"="administrative"]["admin_level"~"2|4"](south,west,north,east);
  way["highway"~"motorway|trunk|primary"](south,west,north,east);
  relation["natural"="water"](south,west,north,east);
  way["waterway"="river"](south,west,north,east);
);
out geom;
```

**Out of scope:** Custom feature type selection (v2), GeoJSON simplification (only if payloads exceed ~2 MB), Overpass circuit breaker (90-day cache makes it unnecessary).

## References

- Plan: `docs/planning/GEO-FEATURES-MULTI-SAT-PLAN.md` (Feature A)
- Pattern: `services/faults.py`, `endpoints/earthquakes.py` line 352
- Dashboard pattern: `seismic.tsx` line 341 (FAULT_STYLE + GeoJSON), `radar-map.tsx` line 921 (alert polygons)
- Overpass API: https://wiki.openstreetmap.org/wiki/Overpass_API
