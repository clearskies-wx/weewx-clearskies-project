---
status: Proposed
date: 2026-07-18
deciders: shane
supersedes:
superseded-by:
---

# ADR-097: Beach profile endpoint — cross-shore transect visualization

## Context

ADR-095 introduces a cross-shore CURVE transect with 10–20 output points per surf spot. The transect data (wave height, swell height, breaking fraction, breaking dissipation at each depth point) enables a beach profile visualization showing where waves break. This is a new capability — no existing surf forecast product exposes the full cross-shore wave transformation to visitors.

The transect data is already computed by SWAN as part of the surf forecast (ADR-095). Exposing it requires a new endpoint and a new dashboard card.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Embed transect in existing surf endpoint | No new endpoint | Response payload grows significantly; most API consumers don't need full transect |
| Separate profile endpoint (chosen) | Clean separation of concerns; dashboard fetches only when the card is visible | New endpoint to maintain |

## Decision

New endpoint `GET /api/v1/surf/{location_id}/profile` returns the cross-shore transect for the current forecast timestep (closest to now).

Response shape:

```json
{
  "data": {
    "locationId": "huntington-city-beach-pier",
    "transect": [
      {
        "distanceFromShore": 800,
        "depth": 12.3,
        "waveHeight": 1.2,
        "swellHeight": 1.0,
        "breakingFraction": 0.0,
        "breakingDissipation": 0.0
      }
    ],
    "breakPoints": [
      { "distanceFromShore": 200, "depth": 3.1, "waveHeight": 1.5 }
    ]
  },
  "units": { "distance": "m", "depth": "m", "waveHeight": "ft" },
  "stationClock": { "...": "standard envelope per §2" },
  "freshness": { "...": "standard envelope per §2" },
  "generatedAt": "2026-07-18T12:00:00Z"
}
```

- `transect` ordered from offshore to shore (decreasing `distanceFromShore`).
- `breakPoints` are QB peak locations — multiple entries for multi-break spots (outer bar, inner bar).
- Unit conversion applies to `waveHeight` and `swellHeight` fields.
- `distance` and `depth` always in meters (physical positions, not display values).

## Consequences

- New endpoint, new response model, new dashboard card.
- Transect data already computed by SWAN (ADR-095) — no additional SWAN compute.
- Dashboard gains a full-width beach profile card (inline SVG, not Recharts) showing bathymetry, water surface, wave envelope, and break point markers.
- Multi-break spots (outer bar + inner bar) show multiple break markers.
- Card positioned before the 72-hour forecast on the surf tab.

## Acceptance criteria

- [ ] `GET /api/v1/surf/{location_id}/profile` returns transect with 10+ points ordered offshore to shore
- [ ] `breakPoints` array has at least one entry for non-flat conditions
- [ ] Multi-break spots show multiple breakPoints at different distances
- [ ] Unit conversion applies correctly to waveHeight and swellHeight
- [ ] Distance and depth always in meters regardless of unit system
- [ ] Standard response envelope (stationClock, freshness, units)
- [ ] Dashboard beach profile card renders bathymetry, water surface, wave envelope, and break markers
- [ ] Card uses inline SVG with proper a11y (`role="img"`, descriptive `aria-label`, sr-only data table)
- [ ] `npx tsc --noEmit` returns zero errors

## Implementation guidance

- **API endpoint:** `endpoints/beach_profile.py`, registered in `endpoints/__init__.py`. Reads transect data from the SWAN cache (same data source as surf endpoint). Selects the timestep closest to now.
- **Response model:** `BeachProfileResponse` in `models/responses.py`. `TransectPoint` and `BreakPoint` nested models.
- **Break detection:** QB peaks along the transect. A point is a break point when QB > threshold (e.g., 0.3) and is a local maximum in QB along the transect.
- **Dashboard card:** `BeachProfileChart.tsx` — inline SVG (not Recharts). X-axis: distance from shore (right-to-left, shore on right). Y-axis: elevation. Bathymetric profile line (brown/tan fill), water surface at tidal elevation, wave height envelope (blue fill between trough and crest), break point markers (vertical dashed line + wave height label).
- **Card placement:** `footprint="full"` (1×4 horizontal), positioned before the 72-Hour Forecast card on the surf tab.
- **Out of scope:** Animated wave rendering, interactive time-step scrubbing. Static profile for current timestep only.

## Amendments

### Amendment 1 (2026-07-21): 1D model output replaces SWAN CURVE

Per SURF-ZONE-MODEL-BRIEF and SURF-1D-IMPLEMENTATION-PLAN:

**Beach profile endpoint returns 1D model output.** Hs at every 3-5m resolution (replacing SWAN CURVE at 50m). Break points from 1D model H/d crossing (replacing SWAN QB threshold). Wave shape data from analytical computation (Stokes/cnoidal) at each transect point.

**Multiple transects available.** Endpoint accepts a `transect_index` query parameter (default: best-peak transect for the current timestep). Also accepts `transect_index=all` for the heat map visualization.

**Response includes per-partition break info:** which swell component breaks where along the profile. Each break point annotated with the canonical partition it belongs to (e.g., "16s SSW groundswell breaks at outer bar").

**New response fields:**
- `waveShapes` — at each profile point, the local wave surface computed from theory (Stokes 2nd order in intermediate water, cnoidal in shallow water, bore/turbulent post-breaking). Represented as discretized wave surface profiles: array of (phase, elevation) pairs relative to local still water level.
- `surfZones` — classified zones along the transect:
  - `impact_zone`: outer break to 50% energy loss — `{start_distance, end_distance, start_depth, end_depth}`
  - `foam_zone`: 50% energy loss to bore minimum — same fields
  - `total_surf_zone`: outer break to swash — `{width_m, start_distance, end_distance}`
  - `reform_trough`: gap between outer and inner break zones on multi-bar beaches (if present)
- `jackingFactor` — per-bar Hs_bar_crest / Hs_approach
- `perPartitionBreaks` — per-partition break info with canonical partition ID, break location, face height, breaker type
- `transectBearing` — degrees true north
- `obstacleFlag` — whether this transect crosses an OBSTACLE
- `verticalDatum` — DEM vertical datum (e.g., "NAVD88")

**Break detection amended.** 1D model's H/d = gamma crossing is the primary break point (not SWAN QB peaks). Multiple break points for multi-bar beaches.

## References

- Related: ADR-095 (cross-shore transect output), ADR-093 (SWAN replaces NWPS)
- Research: `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`
- SWAN user manual: §4.6.1 CURVE, §4.6.2 TABLE (QB, DISSURF quantities)
- Plan: `docs/planning/SWAN-CORRECTIONS-PLAN.md` Phases 5–6, `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md`
