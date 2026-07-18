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

## References

- Related: ADR-095 (cross-shore transect output), ADR-093 (SWAN+TruShore)
- SWAN user manual: §4.6.1 CURVE, §4.6.2 TABLE (QB, DISSURF quantities)
- Plan: `docs/planning/SWAN-CORRECTIONS-PLAN.md` Phases 5–6
