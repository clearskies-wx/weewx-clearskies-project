---
status: Accepted
date: 2026-06-29
deciders: shane
supersedes:
superseded-by:
---

# ADR-078: Geographic Features Overlay (PMTiles Vector Tiles)

## Context

The satellite map view needs unfilled vector overlays for political boundaries, major roads, and water features so operators can orient themselves geographically. Free raster tile providers don't offer "lines only on transparent background."

The current approach uses a CSS blend-mode hack: CartoDB `dark_nolabels` tiles are inverted + multiply-blended (`.satellite-features` class in `index.css` with `filter: invert(1) brightness(1.8); mix-blend-mode: multiply`). This produces poor results — bleed-through artifacts, washed-out satellite colors, and feature lines that are too faint to be useful. The hack also downloads full raster tiles when only line geometry is needed.

**Amendment (2026-06-29) — Overpass approach does not scale.** Option C (Overpass API) was implemented and deployed. For the current BBOX (14° × 24°, covering SoCal + surrounding states), it produces 125K raw OSM features / 101 MB of GeoJSON that OOM-kills the API during fetch and is too large for the browser. Grid subdivision and feature merging brought it to 3,311 features but the response is still 101 MB of coordinate data. Operators with CONUS or Europe BBOXes would be far worse. The Overpass approach is rejected — it does not scale beyond metro-area BBOXes.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **A. Raster tile providers with lines-only style** | No backend work | No free provider offers this; paid tiers add per-operator cost and ToS complexity |
| **B. CSS blend-mode on existing tile providers** (current) | No backend work, already implemented | Visual artifacts, washed-out colors, faint lines, downloads full raster tiles unnecessarily |
| **C. Server-side OSM extraction via Overpass API** | Crisp vector lines, per-type styling, keyless API | **Rejected.** Does not scale beyond metro-area BBOXes. 101 MB GeoJSON for a 14°×24° BBOX. OOM-kills the API. |
| **D. PMTiles static file + protomaps-leaflet** | Pre-processed vector tiles, on-demand loading (~20-50 KB per tile), geometry pre-simplified per zoom level, industry standard for this problem, no external API dependency at runtime | Requires Go `pmtiles` CLI on weewx host for extraction; protomaps-leaflet in maintenance mode (stable but no new features) |

## Decision

**Option D.** The API serves a pre-extracted PMTiles file (OpenStreetMap data cropped to operator BBOX) via HTTP Range requests. The browser loads only the tiles visible in the current viewport using the `pmtiles` JavaScript client — typically 20-50 KB per tile. The dashboard renders lines using `protomaps-leaflet` (Canvas-based vector tile renderer for Leaflet) with custom paint rules for boundaries, roads, and water. An admin action triggers download of the latest Protomaps daily build and BBOX extraction via the Go `pmtiles` CLI. This replaces the CSS blend-mode hack entirely.

**Why not Overpass (Option C)?** The Overpass approach was implemented and tested. It works for small BBOXes (single metro area) but fails catastrophically at regional or continental scale. The fundamental problem is that Overpass returns raw coordinate-heavy GeoJSON — all zoom levels of detail in a single response. PMTiles pre-simplifies geometry per zoom level (coarse at zoom 5, detailed at zoom 12) and the browser loads only what's visible.

## Consequences

- **New API endpoints:** `GET /api/v1/geographic-features/tiles` serves the PMTiles file with HTTP Range request support (Starlette `FileResponse` handles this natively). `GET /api/v1/geographic-features/status` returns file metadata (available, size, last-updated). `POST /setup/geographic-features/update` triggers download + BBOX extraction.
- **New config section:** `[geographic_features]` in `api.conf` with `enabled` (bool) and `bounds` (CSV BBOX for extraction). No `refresh_days`, `overpass_endpoint`, or `radius_km` — the download is operator-triggered, not automatic.
- **New service module:** `services/geographic_features.py` handles download + extraction by shelling out to the Go `pmtiles` CLI.
- **PMTiles file:** Stored at `/etc/weewx-clearskies/geographic-features.pmtiles`. Extracted from the Protomaps daily build (`https://build.protomaps.com/YYYYMMDD.pmtiles`) to operator BBOX with configurable maxzoom (default 12). Expected size: 200-500 MB for a 14°×24° regional extract.
- **Dashboard changes:** `protomaps-leaflet` and `pmtiles` npm packages. Canvas-based vector tile layer in `radar-map.tsx` (satellite view only) with custom `paintRules` for lines-only rendering (no labels, no buildings, no landuse). Removal of the Overpass-based `GeoFeaturesLayer` component, `useGeographicFeatures` hook, and `getGeographicFeatures` client function.
- **External dependency at setup time only:** Protomaps daily build CDN (download) + Go `pmtiles` CLI (extraction). No runtime external dependency — the PMTiles file is served locally.
- **License:** ODbL (OpenStreetMap contributors). Attribution required.
- **Overpass code removal:** All Overpass-based geographic features code (API service + endpoint, dashboard hook + client + component) is removed.
- **Admin UI:** Config UI gets a "Geographic Features" section with an "Update Map Data" button to trigger download.
- **Color tuning required:** Per-type line colors (boundaries, roads, water) must be visible against dark satellite tiles without overpowering weather data. Defined as `LineSymbolizer` options in `radar-map.tsx`.

## Acceptance criteria

- [ ] `GET /api/v1/geographic-features/tiles` serves PMTiles file with Range request support (206 Partial Content)
- [ ] `GET /api/v1/geographic-features/status` returns `{available, size_bytes, updated_at}`
- [ ] `POST /setup/geographic-features/update` downloads Protomaps daily build, extracts to operator BBOX, stores result
- [ ] Returns 404 with descriptive message when PMTiles file not yet downloaded
- [ ] Dashboard renders vector tile lines on satellite view only — not on normal basemap view
- [ ] Lines-only rendering: boundaries (white), roads (gray), water (blue); no labels, no fills, no buildings
- [ ] On-demand tile loading: browser loads ~20-50 KB per viewport tile, not the full file
- [ ] Graceful handling when PMTiles not downloaded: no overlay, no error state
- [ ] CSS blend-mode hack fully removed (no `.satellite-features` class, no `dark_nolabels` TileLayer)
- [ ] Overpass code fully removed (API service + endpoint, dashboard hook + client + component)
- [ ] Admin UI can trigger download and shows file status
- [ ] `ruff check` clean (API), `tsc --noEmit` + `vite build` clean (dashboard)

## Implementation guidance

**API — PMTiles file serving:**
- `endpoints/geographic_features.py`: `GET /api/v1/geographic-features/tiles` serves `/etc/weewx-clearskies/geographic-features.pmtiles` via `FileResponse` with `media_type="application/octet-stream"`. Returns 404 when file absent.
- `GET /api/v1/geographic-features/status`: returns `{available: bool, size_bytes: int|null, updated_at: str|null}`.
- `POST /setup/geographic-features/update` (auth: proxy secret): downloads latest Protomaps daily build, extracts to BBOX via `pmtiles extract <url> <output> --bbox=<bounds> --maxzoom=<N>`, writes to config directory.
- `config/settings.py`: `GeographicFeaturesSettings` — `enabled: bool = True`, `bounds: str | None = None`.

**Dashboard — protomaps-leaflet:**
- npm: `protomaps-leaflet` + `pmtiles`
- `radar-map.tsx`: When `satelliteActive`, add a `protomapsL.leafletLayer` with custom `paintRules` (LineSymbolizer per feature type) and empty `labelRules`. Check status endpoint first — skip layer if not available.
  - Boundaries: `LineSymbolizer({ color: '#ffffff', width: 1.5, opacity: 0.7 })`
  - Roads: `LineSymbolizer({ color: '#999999', width: 1, opacity: 0.5 })`, filter: `pmap:kind` in `['highway', 'trunk']`
  - Water: `LineSymbolizer({ color: '#4a90d9', width: 1, opacity: 0.6 })`
- Remove Overpass-based code: `GeoFeaturesLayer`, `GEO_*_STYLE` constants, `useGeographicFeatures`, `getGeographicFeatures`.

**Out of scope:** Custom feature type selection (v2), self-hosted PMTiles generation from raw OSM (v2), multiple PMTiles files per zoom range (v2), MapLibre GL JS migration (separate effort).

## References

- Plan: `docs/archive/PMTILES-GEOGRAPHIC-FEATURES-PLAN.md`
- Reference: `docs/reference/pmtiles-protomaps-reference.md`
- Protomaps docs: https://docs.protomaps.com/pmtiles/
- protomaps-leaflet: https://github.com/protomaps/protomaps-leaflet
- PMTiles daily builds: https://docs.protomaps.com/basemaps/downloads
- Go pmtiles CLI: https://docs.protomaps.com/pmtiles/cli

## Amendment 2 (2026-08-27) — superseded by the product basemap (Proposed)

**Status: Proposed — takes effect on the operator's acceptance in chat; the removal commit of the
old feature waits for it (plan journal J3).** This amendment does not change the header `status:`
field above (still `Accepted` for the original 2026-06-29 decision) until the operator accepts it.

### Context

CARTO, the free-tile provider every dark-theme Clear Skies map used (including this ADR's own
satellite-view label overlay, `voyager_only_labels`, and `dark_all` base tiles elsewhere in the
product), began watermarking its tiles "API KEY REQUIRED" around 2026-08-25 and is retiring the
free product. `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` (Phase M) was opened to replace
it with a Clear Skies-served product basemap (Protomaps-derived) for every map surface. That plan
absorbs this ADR's geographic-features feature rather than standing up a second, parallel PMTiles
extract-and-serve mechanism, because the two are the same shape of problem — a self-served OSM
vector-tile extract, one Go `pmtiles` CLI, one Range-request endpoint family — just generalised
from one file/box to three tiers.

Operator rulings 2026-08-27 (verbatim, from the plan's Q5/Q6/Q8 and PRIME DIRECTIVE 13–15):

- **Q5:** surf height map background → "a regular basemap" (the product basemap); NAIP
  "eliminated completely from user facing work"; the wizard's Esri satellite toggle stays ("I
  just do not want to use it in user facing situations when we do not have to").
- **Q6:** "Ok wait, so you did not do it wrong, i apologize. So we needed to bring our own
  basemap. Did we need to bring our own legends too or do those need to move into librewxr?" —
  answered yes, labels too: a radar provider's contract is overlay-only, labels are a basemap
  layer, so both stay in Clear Skies from the product basemap (nothing of this ADR's feature
  moves into the LibreWxR fork).
- **Q8:** "YOU CANNOT FUCKING ZOOM OUT BEYOND THE EXTENTS OF THE BBOX!" — closed: the radar map is
  hard-limited to the radar provider's declared coverage box, so its basemap tier is sized to
  exactly that box, at the radar's own zoom range (z0–12); a provider with no coverage box
  (RainViewer) falls back to the station box.
- **Directive 13:** radar providers (LibreWxR, RainViewer, any other) are overlay-only — transparent
  radar, opaque satellite, nothing else. Clear Skies supplies the basemap AND its labels under
  every radar/satellite view, sourced from the product basemap, never from the provider.
- **Directive 14:** the basemap is sized from Clear Skies' own config (station + earthquake radius
  + marine locations) for the marine/seismic/surf maps; the radar map's basemap is sized to the
  radar provider's own declared coverage box (a provider field is allowed to shape the radar
  VIEW's bounds/min-zoom/mask, which is unrelated to and unchanged by this amendment) — never any
  other provider field.
- **Directive 15:** no Esri, no aerial photography, on any user-facing surface.

### Decision

The geographic-features feature this ADR accepted is **replaced by** the basemap family built in
plan task M1 (CS-BASEMAP). Old item → new item, side by side:

| Old (this ADR, 2026-06-29) | New (M1 basemap family) |
|---|---|
| `GET /api/v1/geographic-features/tiles` (one PMTiles file) | `GET /api/v1/basemap/{tier}/tiles` — `tier` ∈ `world` (z0–6), `local` (z7–15), `radar` (z0–12) |
| `GET /api/v1/geographic-features/status` → `{available, size_bytes, updated_at}` | `GET /api/v1/basemap/status` → per-tier `{available, size_bytes, updated_at, bounds, minzoom, maxzoom}` plus `updating`, `last_error`, `last_started_at`, `last_finished_at` |
| `POST /setup/geographic-features/update` (proxy-secret; one BBOX extract) | `POST /setup/basemap/update` (proxy-secret; one background extract of all three tiers, world → local → radar, one daemon thread) |
| `services/geographic_features.py` | `services/basemap_extract.py` |
| `[geographic_features]` config: `enabled` (bool), `bounds` (operator-typed CSV BBOX) | `[basemap]` config: `enabled` (bool) only — no operator-typed box; the local tier's extent is derived (station + `earthquakes.default_radius_km` × 1.15, unioned with the marine locations bbox padded 40 px at z15), the radar tier's extent is the radar provider's declared coverage box or, absent one, the same station box |
| `geographic-features.pmtiles` (one file, operator BBOX, `/etc/weewx-clearskies/`) | `basemap-world.pmtiles`, `basemap-local.pmtiles`, `basemap-radar.pmtiles` (three files, `/etc/weewx-clearskies/`) |
| Admin "Geographic Features" section, "Update Map Data" action | Admin "Basemap" section, one "update basemap" action + per-tier status |
| Satellite view: `GeoFeaturesLayer` (this ADR's own component, `radar-map.tsx`) drawing this ADR's 4 `LineSymbolizer` paint rules, PLUS a separate CARTO `voyager_only_labels` `TileLayer` for labels | One `ProtomapsLayer` in `satellite-outlines` mode: the same 4 `LineSymbolizer` rules (`earth`, `boundaries`, `roads`, `water` — moved verbatim, unchanged colors/widths/filters) drawn together with the product basemap's own dark labels layer, over the `radar` tier |

**The four outline `LineSymbolizer` rules survive verbatim** as the satellite outlines layer — no
color, width, opacity, or filter changes. Everything else in the left column is retired once this
amendment is accepted.

### Consequences

- M1-API (already shipped, `weewx-clearskies-api` `45d1b63`/`94e9437`/`ecdd3d4`) added the three
  basemap endpoints, `services/basemap_extract.py`, and `[basemap]` settings **additively** — this
  ADR's own endpoints, service, and config section are untouched and still serving. No removal has
  happened yet.
- M1-DASH + M3 SHIPPED (D1 as-built re-sync, 2026-08-27; dashboard `eb7c915`…`43afaee`, M3 radar
  rebase `ec27bfd`): `radar-map.tsx`'s `GeoFeaturesLayer` component and `SATELLITE_LABELS_URL`
  CARTO `TileLayer` are deleted (verified — neither identifier exists as code in `radar-map.tsx`
  any more, only in explanatory comments); replaced by the single `ProtomapsLayer`
  `satellite-outlines` mode described above.
- Once the operator accepts this amendment (status → Accepted), the removal commit deletes:
  `endpoints/geographic_features.py`, `services/geographic_features.py`, the `[geographic_features]`
  settings section, the stack repo's "Geographic Features" admin page/route, the
  `geographic-features.pmtiles` file/path, and the dashboard's `GeoFeaturesLayer` component —
  per plan journal J3. Until then, both features run side by side.
- License/attribution unchanged: OpenStreetMap contributors, ODbL, via Protomaps — attribution
  string becomes "© OpenStreetMap contributors © Protomaps" project-wide (M1), not specific to
  this feature.
- This ADR's header `status:` stays `Accepted` (the original decision — PMTiles over Overpass —
  is not being revisited); only the geographic-features *feature* built under it is superseded.

### Acceptance line

**Status: Proposed — takes effect on the operator's acceptance in chat; the removal commit of the
old feature waits for it (plan journal J3).**
