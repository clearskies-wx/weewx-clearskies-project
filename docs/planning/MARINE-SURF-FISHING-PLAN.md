# Marine, Surf & Fishing Forecast — Implementation Plan

**Status:** DRAFT — pending supplementation from original extension research documents  
**Created:** 2026-07-08  
**Last updated:** 2026-07-08  
**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`)

## Context

Clear Skies needs marine, surf, and fishing forecast capabilities. Two pre-Clear-Skies weewx extensions (~11,100 lines total) contain reusable code — NOAA marine data collection, surf physics (shoaling, refraction, breaking, bathymetry), and fishing scoring algorithms. Extensive research (two briefs at `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` and `MARINE-SURF-FISHING-RESEARCH-BRIEF.md`) established that:

- **NOAA provides a complete US marine data ecosystem for free** — WaveWatch III (wave forecasts), NWPS/SWAN (nearshore at 50m–1.8 km), NDBC (buoy observations), CO-OPS (tides/water levels), NWS (marine text forecasts + alerts). No third-party providers needed for US.
- **NWPS covers ALL 36 US coastal WFOs + Great Lakes** with no geographic gaps. It is the primary nearshore source; our Phase II physics code supplements it (breaker index correction, structure effects) and serves as fallback when NWPS data is stale.
- **Supplementing NWPS with site-specific corrections is validated practice** — research confirms SWAN's single breaker index is a known limitation, and site-specific adjustments (Battjes 1974 formula) improve accuracy. Surfline's LOTUS model uses the same pipeline (offshore model + nearshore transformation + site-specific correction).
- **Open-Meteo is dropped** (repackages the same NOAA data). International deferred — Xweather maritime is the future path when demand materializes.
- **Spectral data from NDBC is in v1 scope** — reveals multi-swell breakdowns critical for surf assessment.

## Scope

**US-only, NOAA-only for v1.** Architecture is country-agnostic for future international expansion, but v1 provider modules target NOAA exclusively. No standalone proprietary nearshore approach — NWPS is always primary for US spots.

## Phase Breakdown

```
Phase 0A (ADRs — Architectural Decisions)
  │
  └──► Phase 0B (Manual Updates — Consolidate ADR rules into governing documents)
         │
         └──► Phase 0C (Data Model & Canonical Types)
                │
                ├──► Phase 1 (NOAA Provider Modules: NDBC, CO-OPS, WaveWatch III, NWS Marine)
                │       │
                │       ├──► Phase 2 (NWPS GRIB Provider)
                │       │       │
                │       │       └──► Phase 3 (GEBCO Bathymetry + Surf Physics Enrichment)
                │       │
                │       └──────────► Phase 5 (API Endpoints) ◄── Phase 4
                │
                ├──► Phase 4 (Fishing Enrichment: Solunar + Scoring) ── parallel with Phase 1
                │
                Phase 5 ──► Phase 6 (Location Config: Wizard/Admin)
                              │
                              └──► Phase 7 (Dashboard Pages)
                                     │
                                     └──► Phase 8 (End-to-End Validation + Docs)
```

**Parallelism:** Phases 1 and 4 are independent. Within Phase 1, the four provider modules (T1.1–T1.4) can run as separate agent dispatches. Phase 7 dashboard pages (T7.1–T7.3) can run concurrently.

---

## PHASE 0A — Architectural Decision Records

New architectural decisions that need ADRs before code. Per `clearskies-process.md`: decision discussed → ADR drafted as Proposed → user reviews → user approves → Accepted.

### ADRs Required

**ADR-0XX — Marine provider domain architecture**
- Introduces three new provider domains: `"marine"` (wave forecasts), `"tides"` (discrete predictions), `"buoy"` (observations)
- Why three domains and not one: different data types (continuous fields vs. discrete events vs. point observations), different update frequencies, different caching strategies
- Canonical response models for each domain
- Dispatch registry additions

**ADR-0XX — NWPS as primary nearshore source with site-specific supplementation**
- NWPS/SWAN (all 36 US coastal WFOs + Great Lakes) is the primary nearshore wave data source for US
- Phase II physics code supplements NWPS output: breaker index correction (Battjes 1974 formula), coastal structure effects, sub-grid interpolation
- Phase II physics code serves as fallback when NWPS data is stale (> 12 hours)
- Full standalone transformation (WaveWatch III + GEBCO bathymetry + our physics) is the international path (deferred to post-v1)
- Research basis: SWAN's single γ is a documented limitation; site-specific correction is standard practice (Surfline LOTUS, Camus et al. 2011)

**ADR-0XX — Optional GRIB processing dependency**
- eccodes/pygrib introduced as optional install extra (`pip install weewx-clearskies-api[grib]`)
- Without it, NWPS provider is disabled at startup (graceful degradation, not fatal error)
- WaveWatch III via ERDDAP (JSON, no GRIB) + transformation physics serve as complete fallback
- Precedent: no existing Clear Skies dependency is optional; this establishes the pattern

**ADR-0XX — Multi-spot marine location model**
- Operators configure named marine locations (spots) with coordinates
- Each location can have multiple enabled activities: marine/boating, surf, fishing, beach safety
- Activity-specific configuration per location (beach facing, bottom type, target species, etc.)
- Nearest NDBC/CO-OPS/NWS stations auto-discovered or operator-selected per location
- NWPS WFO domain auto-determined from coordinates
- Bathymetric profile computed once per surf spot from GEBCO, stored in `api.conf`
- This differs from the single-station model used by the rest of Clear Skies

**ADR-0XX — NDBC spectral wave data consumption**
- Parse `.swden` (spectral wave density) and `.swdir` (spectral wave direction) in addition to standard meteorological `.txt`
- Spectral data reveals multi-swell breakdowns (separate swell systems from different directions)
- Standard met Hs alone doesn't distinguish clean swell from wind chop — spectral data is required for accurate surf assessment
- New canonical model: `SpectralWaveComponent` (height, period, direction, energy per swell system)

**ADR-0XX — Fishing forecast scoring model**
- Solunar computation via Skyfield (moon transit/underfoot/rise/set + phase intensity)
- Conditions scoring: pressure trend 0.4, tide state 0.3, time of day 0.2, species modifier 0.1
- GEBCO bathymetry for fishing habitat structure identification (drop-offs, reefs, ledges)
- Research basis: barometric pressure + tide state have strongest evidence; solunar is widely used but scientifically mixed — presented as one factor among several, not the primary predictor

### ADR Sizing Note
These ADRs should be **as detailed as the subject demands** — not constrained to the ~80 line standard. The marine domain involves NOAA data ecosystems, wave transformation physics, scoring algorithms with research citations, multi-spot configuration paradigms, and optional dependency patterns. Each ADR includes the full context, research basis (with sources), options analysis, and implementation guidance needed for implementation agents to execute correctly without re-deriving decisions. The research briefs provide the background; the ADRs make the decisions concrete and prescriptive.

### QC Gate 0A
All ADRs drafted as Proposed, reviewed by user, Accepted before proceeding. Each ADR follows Nygard format. No implementation code until all ADRs are Accepted.

---

## PHASE 0B — Manual Consolidation

Per ADR lifecycle: after acceptance, extract prescriptive rules into target manuals.

### Tasks

**T0B.1 — Determine manual structure** (Coordinator)
- Decision: fold marine content into existing manuals, or create a standalone `MARINE-MANUAL.md`
- Existing manuals: API-MANUAL (data model, endpoints, enrichment), PROVIDER-MANUAL (provider contracts), OPERATIONS-MANUAL (deployment, config), DASHBOARD-MANUAL (pages)
- Assessment criteria: does the marine-specific content (scoring algorithms, physics formulas, NWPS/NDBC/CO-OPS data source details, multi-spot config) have enough volume to warrant its own manual, or does it fit naturally into existing sections?

**T0B.2 — Update target manuals with ADR rules** (Coordinator + `clearskies-docs-author`)
- API-MANUAL: marine data model, marine unit groups, enrichment processors (surf scorer, fishing scorer, solunar), marine endpoint patterns
- PROVIDER-MANUAL: NDBC module contract (flat file parsing, spectral data), CO-OPS module contract (JSON API, tide predictions), WaveWatch III module contract (ERDDAP JSON), NWS marine module contract, NWPS module contract (GRIB2, WFO domains, fallback behavior), GEBCO module contract (one-time bathymetry)
- OPERATIONS-MANUAL: eccodes/pygrib optional dependency, marine config section in `api.conf`, marine location setup procedure, GRIB dependency install
- DASHBOARD-MANUAL: marine/surf/fishing page behavior, location-centric navigation, pages.json entries
- ARCHITECTURE.md: marine/tides/buoy domains in provider module layout, marine endpoints, marine freshness defaults, GRIB optional dependency, marine pages in dashboard routes

**T0B.3 — Archive ADRs** (Coordinator)
- Move accepted ADRs to `docs/archive/decisions/` with status "Archived — consolidated into {MANUAL-NAME}.md"

### QC Gate 0B
All ADR rules extracted into manuals. Manual-authority hierarchy maintained. Doc-code sync verified (manuals describe what will be built, not what exists yet — pre-implementation documentation).

---

## PHASE 0C — Data Model & Canonical Types

Define response models, config structures, and unit groups. No provider calls, no UI.

### Tasks

**T0C.1 — Canonical marine response models** (`clearskies-api-dev`)
- File: `repos/weewx-clearskies-api/.../models/responses.py` (additions)
- Add Pydantic models: `MarineObservation`, `SpectralWaveComponent`, `TidePrediction`, `WaterLevel`, `MarineForecastPoint`, `MarineTextForecast`, `SurfForecast`, `FishingForecast`, `SolunarTimes`, bundle types, `MarineLocationSummary`
- Follow existing patterns (`EarthquakeRecord`, `AlertRecord`)

**T0C.2 — Marine location config schema** (`clearskies-api-dev`)
- New file: `.../services/marine_config.py`
- Dataclasses: `MarineLocation` (coordinates, name, activities, station IDs, WFO code), `SurfSpotConfig` (beach facing, bottom type, slope, structures, bathymetric profile, topographic feature, directional exposure), `FishingSpotConfig` (target category, species, biogeographic region), `MarineConfig`
- `SurfSpotConfig.topographic_feature`: point_break / bay_break / headland / straight_beach — affects wave focusing/sheltering coefficients
- `SurfSpotConfig.directional_exposure`: 8 compass directions (N/NE/E/SE/S/SW/W/NW) with boolean swell reception — determines which swell directions can reach the spot
- `FishingSpotConfig.biogeographic_region`: auto-classified from coordinates against 11 US regions (Atlantic NE/SE, Gulf, Pacific SW/Central/NW, Alaska, Hawaii, Great Lakes, Caribbean, Pacific Territories) — determines species lists

**T0C.3 — Marine unit groups** (`clearskies-api-dev`)
- Add `group_wave_height`, `group_wave_period`, `group_water_level`, `group_ocean_speed` to UnitTransformer
- Update `contracts/canonical-data-model.md`

**T0C.4 — Dispatch registry preparation** (`clearskies-api-dev`)
- Verify dispatch accepts `"marine"`, `"tides"`, `"buoy"` domains

### QC Gate 0C
Models validate with empty data. Config loads. Unit groups registered. Existing tests unchanged.

---

## PHASE 1 — NOAA Provider Modules

Four provider modules following the existing contract: `ProviderHTTPClient`, `CAPABILITY` constant, `fetch()` entrypoint.

### Tasks

**T1.1 — NDBC buoy observations** (`clearskies-api-dev`)
- New: `providers/buoy/ndbc.py`
- Parse standard met `.txt` + spectral `.swden`/`.swdir` files (HTTP flat files)
- Station discovery from `activestations.xml`
- Port Phase I parser (handle `MM` markers). Replace hardcoded US unit conversions with UnitTransformer.
- Cache TTL: 60 min

**T1.2 — CO-OPS tides & water levels** (`clearskies-api-dev`)
- New: `providers/tides/coops.py`
- CO-OPS Data API (JSON): tide predictions, water levels, water temp, currents, coastal met
- Metadata API for station discovery by lat/lon
- Cache TTLs: predictions 6 hr, observations 10 min

**T1.3 — GFS Wave (WaveWatch III coupled) forecasts** (`clearskies-api-dev`)
- New: `providers/marine/wavewatch.py`
- Fetch via ERDDAP JSON (NOT GRIB): `erddap.aoml.noaa.gov/hdb/erddap/griddap/WaveWatch_2026.json?` with lat/lon/time subsetting
- Port Phase II grid selection logic for ERDDAP coordinates (7 grids including gsouth.0p25 for future international)
- Note: GFS Wave uses WaveWatch III coupled with GFS atmospheric model (30-min wind forcing vs 3-hr standalone). Model provides up to 384h (hourly 0–120h, 3-hourly 120–384h); v1 uses 72h at 3-hour steps. Data available ~4.5h after model run.
- 72-hour forecast at 3-hour steps. Cache TTL: 30 min

**T1.4 — NWS marine zone text forecasts** (`clearskies-api-dev`)
- New: `providers/marine/nws_marine.py`
- `api.weather.gov/zones/marine/{zoneId}/forecast` (JSON-LD/GeoJSON)
- Marine zone discovery: `/zones?type=marine&point={lat},{lon}`
- Filter marine alerts (SCA, Gale, Storm) by zone code
- Cache TTL: 30 min

**T1.5 — Wire into dispatch registry** (`clearskies-api-dev`)

### QC Gate 1
All four providers fetch real NOAA data. Canonical models populated. Cache works. Integration tests against live endpoints.

---

## PHASE 2 — NWPS GRIB Provider

Primary nearshore data source for US. Requires eccodes/pygrib (optional dependency).

### Tasks

**T2.1 — Port GRIBProcessor** (`clearskies-api-dev`)
- New: `providers/marine/grib_processor.py`
- Port Phase II class (eccodes/pygrib dual backend)
- Fix: merge duplicate `apply_breaking_limit`
- Graceful degradation: NWPS disabled at startup if no GRIB library

**T2.2 — NWPS provider module** (`clearskies-api-dev`)
- New: `providers/marine/nwps.py`
- Fetch GRIB2 from `ftp.ncep.noaa.gov/pub/data/nccf/com/nwps/prod/`
- WFO domain determination from coordinates (all 36 coastal + Great Lakes WFOs)
- CG grid selection (CG1 baseline, CG2–CG5 nested when available)
- Freshness check: fall back to WaveWatch III when NWPS > 12 hours old
- Extract: wave height, period, direction, currents, bottom orbital velocity, rip current probability (v1.5 WFOs), total water level (v1.5), wave runup (v1.5)

**T2.3 — Optional GRIB dependency** (`clearskies-api-dev`)
- `pyproject.toml`: `[project.optional-dependencies] grib = ["eccodes>=1.5"]`
- `pip install weewx-clearskies-api[grib]` for NWPS support

### QC Gate 2
GRIB processing works. NWPS fallback to WaveWatch III works. Optional dependency model works (API starts without GRIB libraries, NWPS disabled gracefully).

---

## PHASE 3 — GEBCO Bathymetry + Surf Physics Enrichment

Enrichment processors (not provider modules). Take NWPS/WaveWatch III data → produce surf quality forecasts.

### Tasks

**T3.1 — Port BathymetryProcessor** (`clearskies-api-dev`)
- New: `enrichment/bathymetry.py`
- Port Phase II (1,370+ lines): GEBCO via OpenTopoData, adaptive refinement, deep-water point finding
- One-time per-spot computation, stored in `api.conf`
- Fix: replace `eval()`, use UnitTransformer
- OpenTopoData API constraints: 1 call/sec, 1000 calls/day, 100 locations/request
- Regional depth profile adaptations: Pacific Coast uses more aggressive refinement (steep shelf), Gulf Coast more conservative (gradual shelf), Hawaii maximum sensitivity (volcanic)
- Fallback depth profiles when GEBCO unavailable: West Coast [50,40,30,20,12,6,3], East Coast [35,28,22,16,10,5,2.5], Gulf [25,20,15,12,8,4,2], Hawaii [60,45,30,18,10,5,3.5]
- Attribution requirement: "GEBCO Compilation Group (2025) GEBCO 2025 Grid" + "Not for navigation" disclaimer

**T3.2 — Port wave transformation physics** (`clearskies-api-dev`)
- New: `enrichment/wave_transform.py`
- Port: shoaling, refraction, breaking, bottom friction, structure effects
- **Upgrade breaking limit** from lookup table to Battjes 1974: γ = 1.06 + 0.14 ln ξ
- Two modes: (a) supplement NWPS (breaker index correction + structure effects only), (b) full transformation from deep-water data (NWPS fallback)

**T3.3 — Surf quality scoring processor** (`clearskies-api-dev`)
- New: `enrichment/surf_scorer.py`
- Port Phase II scoring: wave height 0.35, period 0.35, wind 0.20, swell dominance 0.10
- **Fix critical Phase II bug:** wire transformation INTO scoring (Phase II bypassed physics)
- Apply multi-swell integration: if primary swell > 75% energy, use primary only; if secondary > 50% of primary, apply energy superposition H_combined = √(H₁² + H₂²) with energy-weighted period
- Apply expanded quality coefficients from original research: period multipliers (18+s=1.5, 12-14s=1.0, <8s=0.1), wind direction factors (offshore light=1.2, onshore moderate=0.5), beach angle alignment (±15°=1.0, ±45°=0.6, >60°=0.1), time-of-day adjustments (dawn +10%, afternoon -10%)
- Generate conditions text via existing GFE marine vocabulary
- Register as enrichment processor

### QC Gate 3
Full surf pipeline end-to-end. Phase II bugs fixed. GFE marine text works. Battjes formula produces physically reasonable γ values.

---

## PHASE 4 — Fishing Enrichment (Solunar + Scoring)

Parallel with Phases 1–3. Only depends on Phase 0 models.

### Tasks

**T4.1 — Solunar computation** (`clearskies-api-dev`)
- New: `enrichment/solunar.py`
- Skyfield (already a dependency): moon transit, underfoot, rise, set + phase intensity
- Major periods 2–3 hr, minor 1–2 hr. Intensity peaks at new/full moon.

**T4.2 — Fishing scoring processor** (`clearskies-api-dev`)
- New: `enrichment/fishing_scorer.py`
- Base environmental scoring: pressure 0.4, tide 0.3, time 0.2, species 0.1
- **Species behavioral profiles**: per-species pressure sensitivity (tied to swim bladder size — tuna has none, redfish has large), water temperature preferences (optimal/good/poor/inactive ranges), tide preference, time-of-day multipliers
- **Seasonal behavior**: spawning season multipliers (e.g., Redfish Oct: 2.5×, Striped Bass May: 3.0×), pre-spawn feeding boosts, migration patterns by month, closed seasons (e.g., Snook Jun-Aug: 0.0×)
- **Dynamic scoring**: base environmental score × water temperature multiplier × seasonal multiplier → active / less_active / inactive species classification per period
- **Biogeographic species lists**: 11 US regions auto-classified from coordinates, each with region-specific species by category (saltwater inshore, saltwater offshore, bottom fish, freshwater sport, salmonids)
- Integrate solunar periods. GEBCO for habitat structure identification.
- 3-day forecast, 5–6 periods per day.

**T4.3 — Solunar almanac endpoint** (`clearskies-api-dev`)
- Add `GET /api/v1/almanac/solunar` to existing almanac router

### QC Gate 4
Solunar times match published tables (±5 min). Scoring verified against Phase II test cases.

---

## PHASE 5 — API Endpoints

Wire provider data + enrichment output to REST endpoints.

### Tasks

**T5.1 — `GET /api/v1/marine[/{locationId}]`** — marine conditions bundle
**T5.2 — `GET /api/v1/tides[/{locationId}]`** — tide predictions + water levels
**T5.3 — `GET /api/v1/surf[/{locationId}]`** — surf quality forecasts
**T5.4 — `GET /api/v1/fishing[/{locationId}]`** — fishing forecasts + solunar
**T5.5 — Wire routers, freshness defaults, cache warmer**
**T5.6 — Update capabilities + pages endpoints**

All follow existing endpoint patterns (earthquakes, forecast, alerts): check capability, fetch from provider, normalize, apply units, attach freshness/stationClock.

### QC Gate 5
All endpoints return correct data. Unit conversion works. Freshness block present. Capabilities updated. OpenAPI spec shows new endpoints.

---

## PHASE 6 — Location Config (Wizard/Admin)

### Tasks

**T6.1 — Marine wizard step** (`clearskies-docs-author`)
- Per location: name, coordinates (map picker), activities (checkboxes)
- Per surf spot: beach facing, bottom type, slope, structures, topographic feature, directional exposure (8 compass dirs)
- Per fishing spot: target category, species (auto-populated from biogeographic region)
- **Land/sea validation**: GEBCO depth query to verify all spot coordinates are in water before accepting
- Station auto-discovery (NDBC + CO-OPS + NWS zone + NWPS WFO) with distance-based quality scoring (wave: 0–25 mi excellent, 25–50 good; atmospheric: 0–50 excellent, 50–100 good; tide: 0–20 excellent)
- Multi-location station optimization: identify stations that serve multiple configured spots, recommend shared stations first
- Differentiate NDBC buoy capabilities (wave-only vs. atmospheric-only vs. full) in station selection UI
- Bathymetry trigger on surf spot save (async with progress)

**T6.2 — Marine admin section** (`clearskies-docs-author`)
- Add/edit/remove locations. Re-run bathymetry. Test connectivity.

**T6.3 — Setup API endpoints** (`clearskies-api-dev`)
- `/setup/apply` handles `[marine]` config
- `/setup/marine/bathymetry` async job
- `/setup/marine/discover-stations` discovery endpoint

### QC Gate 6
Config round-trips through wizard. Station discovery returns results for US coastal coordinates. Bathymetry downloads.

---

## PHASE 7 — Dashboard Pages

### Tasks

**T7.1 — Marine conditions page** (`clearskies-dashboard-dev`)
- Route: `/marine`. Location cards → detail view with buoy observations, wave forecast chart, tide chart, NWS text forecast, marine alerts, rip current probability (when available)

**T7.2 — Surf conditions page** (`clearskies-dashboard-dev`)
- Route: `/surf`. Per-spot star ratings, wave height at break, swell breakdown from spectral data, wind quality, tide overlay, 72-hour forecast timeline

**T7.3 — Fishing forecast page** (`clearskies-dashboard-dev`)
- Route: `/fishing`. Solunar calendar, activity ratings, conditions breakdown, 3-day period grid, GEBCO habitat features

**T7.4 — Now page marine summary card** (`clearskies-dashboard-dev`)
- Optional card in `now-layout.json`. Current wave height, SST, next tide, wind, alerts. Links to `/marine`.

**T7.5 — Routing, navigation, pages.json** (`clearskies-dashboard-dev`)
- Lazy-loaded routes, `VisibilityGuard`, Phosphor icons, `pages.json` visibility control

### QC Gate 7
All pages render with real data. Responsive at 375px. i18n keys for 13 locales. Hidden when not in `pages.json`. `tsc --noEmit` + `vite build` clean.

---

## PHASE 8 — End-to-End Validation + Documentation

### Tasks

**T8.1 — Integration test suite** (`clearskies-api-dev`)
- Validate against NDBC buoy observations and CDIP (Coastal Data Information Program, ~180 stations, primarily US West Coast) spectral wave data where available
**T8.2 — Deploy + smoke test** (Coordinator)
- Configure test location, deploy to weewx + weather-dev, run full smoke checklist
**T8.3 — Documentation sync** (Coordinator + `clearskies-docs-author`)
- Update: ARCHITECTURE.md, API-MANUAL.md, PROVIDER-MANUAL.md, DASHBOARD-MANUAL.md, OPERATIONS-MANUAL.md, canonical-data-model.md, api.conf.example

### QC Gate 8
Full-stack smoke test passes. All governing documents updated. Production-ready.

---

## Key Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| NWPS data freshness (on-demand runs) | Stale nearshore data | Freshness check, auto-fallback to WaveWatch III + transformation physics |
| eccodes/pygrib build complexity | Operators can't install GRIB libraries | Optional dependency; without it NWPS disabled, system uses WaveWatch III + physics |
| ERDDAP availability | WaveWatch III unavailable | ProviderHTTPClient retry/backoff; all other marine data (NDBC, CO-OPS, NWS) independent |
| Surf quality accuracy expectations | Users expect Surfline quality | Label as "estimated quality." Provide raw data so experienced surfers can judge. Statistical calibration deferred to v2+. |
| GEBCO/OpenTopoData availability | Bathymetry download fails at setup | One-time operation; stored in config. Operator retries later. System self-sufficient after setup. |
| Great Lakes wave dynamics differ | No swell, no tides (seiche/seasonal levels) | Scoring works on wave height/period/wind regardless of generation mechanism. Tide-dependent scoring handles absent tidal signal gracefully. |
| Wizard complexity | Most complex wizard step yet | HTMX progressive disclosure. Auto-populated stations with override. Async bathymetry with progress indicator. |
| Scope size (~20 new files, 3 repos, 9 phases) | Long timeline | Each phase has independent QC gates. Feature degrades gracefully at every boundary. Each phase adds standalone value. |

## Verification

After each phase gate, the coordinator runs QC checks as described. After Phase 8:
- All marine endpoints return data for configured US coastal locations
- Surf ratings produce physically reasonable 1–5 star values
- Fishing forecasts show solunar + conditions scoring
- Dashboard pages render responsively with i18n
- NWPS → WaveWatch III fallback works when GRIB data is stale
- Documentation reflects the new feature set
