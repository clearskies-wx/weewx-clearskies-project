---
status: Archived — consolidated into API-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-088: Fishing forecast scoring model

## Context

The fishing forecast page needs a composite activity score that tells an angler whether conditions are favorable. The Phase II extension implemented a 4-component scoring system (pressure trend, tide state, time of day, species modifier). The original development research produced a richer model with species behavioral profiles, biogeographic region classification, and seasonal multipliers.

The evidence base varies by factor. Barometric pressure and water temperature have the strongest research support. Solunar theory (moon position driving feeding periods) is widely used by anglers but has mixed scientific evidence — some peer-reviewed studies show species-specific correlations, others find no significant effect.

Clear Skies already uses Skyfield for almanac computations (moon phases, planet positions). Solunar times (moon transit, underfoot, rise, set) are pure celestial mechanics computable from Skyfield with no external API call.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Simple 4-component model (Phase II) | Proven, straightforward. | Misses water temperature (strongest evidence factor). No solunar. No species differentiation. |
| Enhanced model with solunar + species profiles | Richer, more useful. Water temperature addressed. Species-specific adjustments match fishing reality. | More complex. Solunar evidence is mixed. Species data requires biogeographic region classification. |
| Solunar-primary model | Simple. Anglers expect solunar times. | Overweights the weakest evidence factor. Ignores pressure and temperature which have stronger research support. |

## Decision

Enhanced scoring model with five environmental factors plus species-specific modifiers. Solunar is one factor among several — not the primary predictor.

### Scoring components

| Component | Weight | Method | Evidence strength |
|---|---|---|---|
| Barometric pressure trend | 0.30 | 3-hour pressure delta from weewx station or nearest NDBC buoy. Falling pressure = highest score (fish feed ahead of fronts). Rapid drop (> 3 hPa/3hr) = peak. Stable = moderate. Rising = low initially, improving over 12–24 hr. | Strong — swim bladder pressure sensitivity well-documented |
| Tide state | 0.25 | Current position in the tidal cycle from CO-OPS predictions. Outgoing (ebb) tide rated highest (flushes bait from estuaries). Incoming flood second. Slack tides (high and low) rated poorest. | Strong — water movement concentrates baitfish |
| Water temperature | 0.20 | From nearest NDBC buoy SST or CO-OPS water temp. Compared against species-specific optimal ranges. Within optimal = 1.0, good = 0.8, marginal = 0.5, outside active range = 0.1. | Strongest — fish metabolism is temperature-dependent |
| Solunar intensity | 0.15 | Major periods (moon transit/underfoot) = high intensity. Minor periods (moonrise/moonset) = moderate. Moon phase modulates: new/full moon = 1.0, quarter = 0.7, between = 0.5. Computed via Skyfield. | Mixed — some peer-reviewed support, widely used but not conclusive |
| Time of day | 0.10 | Dawn/dusk = highest (low-light feeding peaks). Morning = good. Midday = poorest. Night = moderate (species-dependent). | Moderate — dawn/dusk peaks well-established |

**Final score** = Σ(component_score × weight) × species_modifier × seasonal_multiplier, scaled to 0–100 integer.

### Solunar computation

Computed locally via Skyfield — no external API:

- **Moon transit:** Highest point in sky → start of major feeding period (2–3 hour window)
- **Moon underfoot:** Opposite side of Earth → second major period (2–3 hours)
- **Moonrise:** Start of minor feeding period (1–2 hours)
- **Moonset:** Second minor period (1–2 hours)
- **Moon phase intensity:** New moon = 1.0, full moon = 1.0 (strongest gravitational pull), first/last quarter = 0.7, waxing/waning crescents = 0.5

### Canonical model

`SolunarTimes`:
- `date` (str, YYYY-MM-DD)
- `moon_phase` (str — new, waxing_crescent, first_quarter, waxing_gibbous, full, waning_gibbous, last_quarter, waning_crescent)
- `moon_illumination` (float, 0.0–1.0)
- `moonrise` (str, ISO-8601 or null)
- `moonset` (str, ISO-8601 or null)
- `moon_transit` (str, ISO-8601)
- `moon_underfoot` (str, ISO-8601)
- `major_periods` (list of {start, end} — two per day, centered on transit and underfoot)
- `minor_periods` (list of {start, end} — two per day, centered on moonrise and moonset)
- `intensity` (float, 0.0–1.0 — driven by moon phase)

### Scope — nearshore and freshwater fishing only

The fishing feature targets recreational anglers fishing from shore, piers, jetties, wading, and nearshore boats — not offshore charter or commercial operations. This scopes the species profiles, habitat display, and data sources to the nearshore zone where CUDEM bathymetry, CO-OPS tides, and NDBC coastal buoys provide complete coverage.

### Species profiles

Four target categories with species lists auto-populated from biogeographic region:

| Category | Example species | Pressure sensitivity | Temperature range (°F) |
|---|---|---|---|
| Saltwater inshore | Redfish, Speckled Trout, Flounder, Snook | High (large swim bladder) | Species-specific, 55–85°F typical |
| Bottom fish | Grouper, Snapper, Sheepshead, Tautog | Moderate | Species-specific, varies widely |
| Freshwater sport | Bass, Walleye, Pike, Catfish | High | Species-specific, 55–75°F typical |
| Salmonids | Salmon, Steelhead, Trout | Moderate | 45–65°F (cold-water species) |

Each species has: optimal temp range (1.0×), good range (0.8×), marginal range (0.5×), inactive below/above (0.1×). Spawning season multipliers (2.0–3.0× during peak runs). Auto-populated from 11 US biogeographic regions based on coordinates.

### Bathymetry for habitat

Bathymetric profiles (also used for surf in ADR-084) identify fishing habitat structure: drop-offs, ledges, reefs, channels, pinnacles. NOAA CUDEM (1/9 arc-second, ~3.4m resolution) resolves individual reef structures, ledges, sandbars, and channel edges — the features anglers actually fish. This is a major improvement over GEBCO (~450m), which could only show continental shelf breaks and major canyons. The fishing page displays a depth profile with habitat annotations.

## Consequences

- **Enrichment processors:** `enrichment/solunar.py` (Skyfield computation), `enrichment/fishing_scorer.py` (composite scoring).
- **Skyfield dependency:** Already present (almanac feature). No new dependency.
- **Species data:** Hardcoded lookup tables keyed by biogeographic region and target category. No external API.
- **Solunar endpoint:** `GET /api/v1/almanac/solunar` — extends the existing almanac endpoint family. Available to all operators, not gated by marine feature (solunar times are useful for hunting and wildlife photography too).
- **Presentation:** Solunar is presented as one factor with appropriate caveats — "Solunar theory suggests feeding activity correlates with moon position. Scientific evidence is mixed; environmental conditions (pressure, temperature, tides) have stronger research support."

## Acceptance criteria

- [ ] Solunar times computed from Skyfield for any date and location (no external API call)
- [ ] Major/minor periods correctly centered on transit/underfoot/rise/set with appropriate durations
- [ ] Moon phase intensity maps correctly (new/full = 1.0, quarter = 0.7)
- [ ] Fishing score combines all five components with the specified weights
- [ ] Species temperature ranges produce correct multipliers (within optimal = 1.0, outside active = 0.1)
- [ ] Biogeographic region auto-classified from coordinates (11 US regions)
- [ ] Score output is 0–100 integer with per-component sub-scores visible
- [ ] Solunar endpoint works without marine feature enabled

## Implementation guidance

- **Solunar:** `enrichment/solunar.py` — uses Skyfield `almanac.find_transits()`, `almanac.find_risings()`, `almanac.find_settings()`. Moon phase from existing almanac code. Major periods = transit ± 1.5 hours, minor periods = rise/set ± 1 hour. Duration modulated by moon phase (new/full = wider windows).
- **Scoring:** `enrichment/fishing_scorer.py` — registered as enrichment processor. Inputs: pressure trend (from weewx archive or NDBC), tide state (from CO-OPS), water temperature (from NDBC/CO-OPS), solunar intensity (from solunar processor), time of day. Output: `FishingForecast` model with overall score and sub-scores.
- **Species data:** Module-level constants in `enrichment/fishing_species.py`. Biogeographic region boundaries as lat/lon bounding boxes. Species per region per category.
- **Out of scope:** Dashboard page design (Phase 7). Wizard species selection UI (Phase 6). Statistical calibration of scoring weights.

## References

- Solunar theory: John Alden Knight (1926), formalized in "Moon Up — Moon Down"
- Barometric pressure and fish feeding: multiple studies via In The Spread, Florida Fish and Wildlife
- Water temperature and fish metabolism: standard fisheries biology
- Biogeographic regions: Costello et al. 2017, NOAA Large Marine Ecosystem boundaries
- Related ADRs: ADR-014 (Skyfield almanac), ADR-083 (domain architecture), ADR-086 (multi-spot location model)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §4 (fishing science), §11.6 (regional model)
- Research: `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` §2 (Phase II fishing scoring)
