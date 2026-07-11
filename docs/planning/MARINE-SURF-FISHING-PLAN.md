# Marine, Surf & Fishing Forecast — Implementation Plan

**Status:** Phase 6 ✓ COMPLETE — QC Gate 6 passed 2026-07-10  
**Created:** 2026-07-08  
**Last updated:** 2026-07-10 (QC Gate 6 passed: pushed, deployed, API health 200, config UI restarted, 180 targeted API tests passed, 46 stack tests passed)  
**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`)

## Context

Clear Skies needs marine, surf, and fishing forecast capabilities. Two pre-Clear-Skies weewx extensions (~11,100 lines total) contain reusable code — NOAA marine data collection, surf physics (breaking index correction, structure effects, bathymetry, scoring), and fishing scoring algorithms. Extensive research (two briefs at `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` and `MARINE-SURF-FISHING-RESEARCH-BRIEF.md`) established that:

- **NOAA provides a complete US marine data ecosystem for free** — WaveWatch III (wave forecasts), NWPS/SWAN (nearshore at 50m–1.8 km), NDBC (buoy observations), CO-OPS (tides/water levels), NWS (marine text forecasts + alerts). No third-party providers needed for US.
- **NWPS covers ALL 36 US coastal WFOs + Great Lakes** with no geographic gaps. It is the primary nearshore source; our physics code supplements NWPS output with four specific corrections (breaker index, structure effects, sub-grid interpolation, topographic focusing — see ADR-084).
- **Supplementing NWPS with site-specific corrections is validated practice** — research confirms SWAN's single breaker index is a known limitation, and site-specific adjustments (Battjes 1974 formula) improve accuracy. Surfline's LOTUS model uses the same pipeline (offshore model + nearshore transformation + site-specific correction).
- **v1 targets US coverage only.** International marine data is out of scope; provider selection for international coverage will be evaluated if and when that need arises.
- **Spectral data from NDBC is in v1 scope** — reveals multi-swell breakdowns critical for surf assessment.

## Scope

**US-only, NOAA-only for v1.** v1 provider modules target NOAA exclusively. The architecture accommodates additional providers through the existing dispatch registry, but no decisions have been made about non-NOAA providers — that evaluation happens when the need arises.

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety, SSH access, filesystem permissions
- `rules/coding.md` — coding standards (all languages)
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, QC gates, doc-code sync
- `docs/ARCHITECTURE.md` — container inventory, port registry, provider module layout, enrichment pipeline
- `docs/manuals/API-MANUAL.md` — canonical data model, unit system, endpoint patterns, enrichment contract
- `docs/manuals/PROVIDER-MANUAL.md` — provider module contract (§1–§7), capability declaration, cache layer, error taxonomy
- `docs/manuals/OPERATIONS-MANUAL.md` — deployment, config files, wizard steps, admin sections
- `docs/manuals/DASHBOARD-MANUAL.md` — page behavior, i18n, data refresh, component patterns
- `docs/planning/briefs/MARINE-DATA-AUDIT-BRIEF.md` — Phase II code audit, wire formats, config structure
- `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` — NOAA data ecosystem, physics research, scoring algorithms

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**

| Repo | Branch | What changes in this plan |
|------|--------|--------------------------|
| `weewx-clearskies-api` | `main` | Provider modules (NDBC, CO-OPS, WaveWatch III, NWS marine, NWPS), enrichment processors (bathymetry, wave_transform, surf_scorer, fishing_scorer, solunar), canonical models, unit groups, endpoints, marine config schema, alerts provider marine zone extension |
| `weewx-clearskies-dashboard` | `main` | Marine, surf, fishing, beach safety pages + now-page summary card + routing/navigation |
| `weewx-clearskies-stack` | `main` | Marine wizard step, marine admin section, setup API endpoints, alerts config marine radius |
| `weewx-clearskies-project` | `main` | ADRs, manual updates, plan updates |

**Deploy (use scripts — never manual git/npm/systemctl on containers):**
- Dashboard + Config UI: `bash scripts/redeploy-weather-dev.sh`
- API: `bash scripts/deploy-api.sh`
- Source-only refresh: `bash scripts/sync-to-weather-dev.sh`
- Direct SSH: `ssh -F .local/ssh/config weather-dev`, `ssh -F .local/ssh/config weewx`

**Test:**
- API pytest (on weewx): `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"`
- Dashboard vitest (on weather-dev): `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test"`
- Dashboard build (on weather-dev): `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm run build"`
- Browser verification: `https://weather-test.shaneburkhardt.com`

**Existing patterns to follow (read before implementing):**
- Provider module: `providers/alerts/nws.py` (858 lines — full Owner/Files/Do/Accept reference implementation: CAPABILITY, wire Pydantic models, cache key, normalization, fetch entrypoint, rate limiter)
- Provider module (Aeris): `providers/alerts/aeris.py` (858 lines — same pattern, keyed provider with envelope parsing)
- Enrichment processor: `enrichment/conditions_text.py` (GFE text generation — register pattern, input/output contract)
- Response models: `models/responses.py` (Pydantic models — existing EarthquakeRecord, AlertRecord patterns)
- Endpoint router: `routes/earthquakes.py` (capability check, provider fetch, unit conversion, freshness attachment)
- Unit groups: `services/unit_transformer.py` (existing group registration pattern)
- Config schema: `config/settings.py` (existing Settings dataclass, config loading)
- Wizard step: `weewx_clearskies_config/templates/wizard/` (existing HTMX step pattern)
- Admin section: `weewx_clearskies_config/templates/admin/` (existing admin section pattern)
- Dashboard page: `src/pages/` (existing page component pattern, lazy loading, VisibilityGuard)

**Agent assignments:**

| Agent type | Role | Used for |
|-----------|------|----------|
| Coordinator (Opus) | Orchestration, QC, judgment, ADR drafting, manual updates | Phase 0A, 0B (all tasks), QC gates, commit review |
| `clearskies-api-dev` (Sonnet) | API implementation | Provider modules, enrichment, models, endpoints, config, tests |
| `clearskies-test-author` (Sonnet) | Test authoring | Fixtures, integration tests, unit tests |
| `clearskies-dashboard-dev` (Sonnet) | Dashboard implementation | Pages, components, routing, i18n |
| `clearskies-docs-author` (Sonnet) | Wizard/admin, documentation | Phase 6 wizard steps, admin sections, HTMX templates, help content |
| `clearskies-auditor` (Sonnet) | QA verification | Post-QC audit of each phase |

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC + QA pattern (every phase):**
1. **QC (Coordinator):** Verify task deliverables against accept criteria. Run tests. Check manual compliance. Check existing test baselines haven't regressed.
2. **QA (`clearskies-auditor`):** Independent audit of QC results. Verify the QC was thorough — did the coordinator actually run the tests, check the manual rules, verify the patterns? Auditor reads the code, runs its own checks, reports findings. Phase does not advance until QA passes.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | 4079 passed, 341 skipped, 96 failed (pre-existing OWM AQI) | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | 320 passed, 26 failed (pre-existing) | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |
| Dashboard bundle | 96.21 KB gzipped (48% of 200 KB budget) | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm run build 2>&1 \| grep gzip"` |
| Stack pytest | 46 passed, 11 xfailed, 0 failed | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-stack && .venv/bin/python -m pytest -q 2>&1 \| tail -3"` |

---

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
                │       │       └──► Phase 3 (CUDEM Bathymetry + Surf Physics Enrichment)
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

**Parallelism:** Phases 1 and 4 are independent. Within Phase 1, the six provider modules and marine zone alerts task (T1.1–T1.7) can run as separate agent dispatches, though T1.4, T1.5, and T1.7 share the marine zone discovery utility. Phase 7 dashboard pages (T7.1–T7.4) can run concurrently.

---

## PHASE 0A — Architectural Decision Records ✓ COMPLETE

All 8 ADRs drafted, reviewed, and Accepted (2026-07-09). Key changes during review:
- GEBCO replaced with NOAA CUDEM (~3.4m resolution) as sole US bathymetry source (ADR-084, ADR-086, ADR-088, ADR-090)
- `saltwater_offshore` fishing category removed — fishing scoped to nearshore/freshwater recreational (ADR-086, ADR-088)
- Data deduplication removed for free NOAA providers (ADR-086)
- ADR-085 rewritten to clarify Docker always includes eccodes; pip extra is the only variable

### Tasks

**T0A.1 — Draft ADR-083 through ADR-090** (8 ADRs)
- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-083-marine-provider-domain-architecture.md` through `docs/decisions/ADR-090-activity-capability-matrix.md`
- Do: Draft each ADR as Proposed using `docs/decisions/_TEMPLATE.md` (Nygard format). The content for each ADR is specified below — the coordinator translates these plan descriptions into proper ADR format with Status, Context, Options, Decision, Consequences, Implementation guidance, References. Each ADR references the research briefs as background. ADR-084, ADR-089, and ADR-090 are larger than standard (~150–300 lines) per the sizing note below; the rest are standard (~80–150 lines).
- Accept: All 8 ADRs exist as files in `docs/decisions/`. Each has Status: Proposed. Each follows Nygard format. INDEX.md updated with all 8 under "Proposed" section. No implementation code exists yet.

**T0A.2 — User review and approval**
- Owner: Coordinator (Opus) presents, user approves
- Do: Present each ADR to the user for review. User may request changes (ADR stays Proposed, coordinator edits in place). On approval, coordinator changes Status to Accepted and updates the date.
- Accept: All 8 ADRs have Status: Accepted. INDEX.md reflects accepted status.

### ADR Content Specifications

**ADR-083 — Marine provider domain architecture**
- Introduces three new provider domains: `"marine"` (wave forecasts), `"tides"` (discrete predictions), `"buoy"` (observations)
- Why three domains and not one: different data types (continuous fields vs. discrete events vs. point observations), different update frequencies, different caching strategies
- Canonical response models for each domain
- Dispatch registry additions

**ADR-084 — NWPS as primary nearshore source with site-specific supplementation**
- NWPS/SWAN (all 36 US coastal WFOs + Great Lakes) is the primary nearshore wave data source for US
- NWPS data is consumed as-is for wave height, period, direction, and currents — we do NOT re-run the full nearshore transformation (shoaling, refraction, bottom friction) that SWAN already computed. The supplementations address four specific SWAN limitations that are documented in the literature and correctable with operator-provided spot configuration:

  **Supplement 1 — Breaker index correction (γ tuning)**
  SWAN uses a single constant γ = 0.73 (Battjes & Stive 1985 average) for depth-induced breaking across its entire domain. The actual γ varies from ~0.6 (spilling breakers on gentle sand slopes) to ~1.2 (plunging breakers on steep reef). This is well-documented: Battjes & Stive found 0.6–0.83 in their dataset; Carini et al. 2021 found the range extends further on steep bottoms.
  - **Formula:** γ = 1.06 + 0.14 ln ξ (Battjes 1974), where ξ = tan α / √(H₀/L₀) is the Iribarren number (surf similarity parameter), tan α = average nearshore bottom slope (from NOAA CUDEM bathymetric profile), H₀ = NWPS-provided significant wave height, L₀ = deep-water wavelength from NWPS period
  - **Application:** Recompute maximum wave height at breaking as H_max = γ_corrected × depth, using the spot-specific γ instead of SWAN's constant 0.73. This adjusts the NWPS breaking height, not the full wave field.
  - **Operator inputs required:** bottom type (sand/rock/coral_reef/mixed — determines slope characteristics), beach slope (computed from NOAA CUDEM bathymetric profile at setup)
  - **Validation:** γ output clamped to [0.5, 1.4] (physical bounds from literature). Values outside this range indicate bad slope/wave data.

  **Supplement 2 — Coastal structure effects (transmission/reflection)**
  SWAN is a phase-decoupled spectral model. It cannot model wave diffraction behind structures (breakwaters, jetties, piers) because diffraction requires phase-resolved computation at grid cells < 1/10 wavelength — impractical at NWPS grid scales (50m–1.8 km). This is documented in SWAN's own limitations page and confirmed by Holthuijsen et al.
  - **Method:** Apply empirical transmission coefficients (Kt) to reduce wave height in the lee of operator-configured structures. H_transmitted = Kt × H_incident.
  - **Coefficients by material permeability** (from Zanuttigh & Van der Meer 2006, Goda 2000, CERC 1984):
    - Impermeable (concrete seawall, solid breakwater): Kt = 0.10 ± 0.05
    - Semi-permeable (rubble mound breakwater, rock jetty): Kt = 0.35 ± 0.15
    - Permeable (timber pier, open groin): Kt = 0.75 ± 0.10
  - **Influence zone:** effects apply within structure-type-specific distance (jetty: 3–5× length, breakwater: 2–4× length) and diminish as 1/r² with distance from the structure
  - **Caveat:** labeled as "estimated — structure effects are approximate" in all output. We do not claim to resolve the diffraction pattern, only to apply a gross height reduction.
  - **Operator inputs required:** structure type, material, approximate dimensions, position relative to spot

  **Supplement 3 — Sub-grid spatial interpolation**
  NWPS CG1 grids are ~1.8 km resolution. An operator's spot may fall between grid nodes. Standard bilinear interpolation of the gridded output to exact spot coordinates. This is routine practice for any gridded geophysical data and introduces no new physics.
  - **Method:** Bilinear interpolation using the four surrounding NWPS grid nodes
  - **No operator input required** — coordinates are already configured

  **Supplement 4 — Topographic wave focusing/sheltering**
  Large-scale coastal morphology (headlands, bays, points) creates wave focusing and sheltering effects at scales that NWPS may not fully resolve, depending on grid resolution and coastline representation. These are first-order geometric effects, not fine-scale physics.
  - **Method:** Apply a multiplicative adjustment factor to wave height based on operator-classified topographic feature:
    - Point break (wave focusing around headland): × 1.1
    - Headland (refraction enhancement): × 1.2
    - Bay break (sheltering, height reduction): × 0.9
    - Straight beach (no modification): × 1.0
  - **Operator inputs required:** topographic feature classification (from spot config)
  - **Caveat:** these are coarse adjustments. They capture the direction of the effect (focusing vs. sheltering) but not the magnitude with precision.

- **What we do NOT supplement:** shoaling, refraction, bottom friction, wave-current interaction. NWPS/SWAN already computes these using the full spectral model with its bathymetry and current fields. Re-running them with coarser bathymetry would be worse than NWPS's own computation (50m–1.8 km grids with higher-resolution bathymetry).

- **No fallback transformation pipeline.** NWPS data availability was verified against the NOMADS production archive (July 2026): all 36 coastal WFOs produce NWPS runs daily — typically 2–3 cycles per day (00z, 06z, 12z). Data is never more than ~8–12 hours old under normal operations. Maintaining an entire separate transformation codebase (shoaling + refraction + breaking + bottom friction on WaveWatch III deep-water data) for a hypothetical staleness scenario that doesn't occur in practice is unjustified complexity. If NWPS data is temporarily unavailable for a spot (NOAA outage, WFO maintenance), the marine page shows WaveWatch III offshore data without nearshore supplementation — the same data quality the system would have without NWPS at all. No separate code path needed.

- **Research basis:**
  - Battjes 1974, Battjes & Stive 1985 — breaker index variability and γ formula ([Coastal Wiki](https://www.coastalwiki.org/wiki/Breaker_index))
  - Carini et al. 2021 — predicting breaking and breaker type at onset ([JGR Oceans](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2020JC016935))
  - Ruiz de Alegría-Arzaburu et al. 2021 — nearshore breaker index parameterization, 10–24% wave height prediction improvement over constant γ ([arXiv](https://arxiv.org/abs/2104.00208))
  - Ocean Engineering 2022 — modified breaker index for spectral models, γ as function of steepness + slope + relative depth ([ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0029801822018108))
  - SWAN official limitations — diffraction, wave-induced currents, single γ ([SWAN docs](https://swanmodel.sourceforge.io/online_doc/swanuse/node4.html))
  - van der Westhuysen 2010 — NWPS breaking rescaling for finite depth growth ([JGR Oceans](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2009JC005433))
  - Zanuttigh & Van der Meer 2006, Goda 2000, CERC 1984 — structure transmission coefficients
  - Camus et al. 2011 — statistical nearshore downscaling validation
  - Surfline LOTUS model — validates the offshore model + nearshore correction + site-specific tuning pipeline

**ADR-085 — eccodes native dependency for marine feature**
- eccodes (ECMWF's GRIB processing C library) is a **required dependency** for the marine feature — not optional within the marine feature, but the marine feature itself is what operators opt into
- First native (non-pure-Python) library dependency in Clear Skies API
- How it's provided depends on the deployment method:
  - **Docker compose:** eccodes baked into the API Dockerfile. Marine-capable by default, no operator action needed.
  - **Native install (pip):** operator installs the system library (`apt install libeccodes-dev` / equivalent), then `pip install weewx-clearskies-api[marine]` to pull the Python binding. OPERATIONS-MANUAL documents platform-specific prerequisites.
- If eccodes is not present and an operator attempts to enable marine features, the wizard/admin reports the missing dependency with install instructions — not a silent degradation
- Precedent and implications: documents how the project handles native library dependencies going forward (clear error messaging, dependency detection at feature-enable time, per-deployment-method install instructions)

**ADR-086 — Multi-spot marine location model**
- Operators configure named marine locations (spots) with coordinates
- Each location has one or more enabled activities: marine/boating, surf, fishing, beach safety
- Which capabilities are enabled/disabled per activity is defined in ADR-090 (activity capability matrix) — ADR-086 covers the location config structure, not the capability definitions
- Activity-specific configuration per location (beach facing, bottom type, target species, etc.)
- Nearest NDBC/CO-OPS/NWS stations auto-discovered or operator-selected per location
- NWS marine zone(s) auto-discovered per location (see ADR-089)
- NWPS WFO domain auto-determined from coordinates
- Bathymetric profile computed once per surf spot from NOAA CUDEM, stored in `api.conf`
- This differs from the single-station model used by the rest of Clear Skies

**ADR-087 — NDBC spectral wave data consumption**
- Parse `.data_spec` (spectral wave density — **live-verified; `.swden` returns 404**) and `.swdir` (spectral wave direction) in addition to standard meteorological `.txt`
- Spectral data reveals multi-swell breakdowns (separate swell systems from different directions)
- Standard met Hs alone doesn't distinguish clean swell from wind chop — spectral data is required for accurate surf assessment
- New canonical model: `SpectralWaveComponent` (height, period, direction, energy per swell system)

**ADR-088 — Fishing forecast scoring model**
- Solunar computation via Skyfield (moon transit/underfoot/rise/set + phase intensity)
- Conditions scoring: pressure trend 0.4, tide state 0.3, time of day 0.2, species modifier 0.1
- NOAA CUDEM bathymetry for fishing habitat structure identification (drop-offs, reefs, ledges)
- Research basis: barometric pressure + tide state have strongest evidence; solunar is widely used but scientifically mixed — presented as one factor among several, not the primary predictor

**ADR-089 — Marine zone alerts in the existing alert system**
- **Problem:** All three alerts providers (NWS, Xweather/Aeris, OWM) query by lat/lon point. Whether marine zone alerts are returned depends on how close the station is to the water — not whether the operator is in a coastal area.
  - **Verified behavior (live API testing, July 2026):** Both NWS and Xweather return marine alerts (e.g., Small Craft Advisory) for stations directly on the water (Wrightsville Beach, Hatteras, Nags Head — barrier islands within ~1km of the ocean). Both providers **miss** marine alerts for stations even modestly inland (Wilmington NC at ~15km from coast — gets heat warnings only, no SCA despite active SCAs on nearby marine zones AMZ150–158).
  - **OWM:** Not tested (no active API key with One Call 3.0), but uses the same lat/lon point query mechanism. Likely same behavior.
  - **Root cause:** Marine alerts are issued against marine zones (water polygons: AMZ/GMZ/PZZ/ANZ/PKZ/PHZ prefixes). A lat/lon point query matches the point against zone polygons. A point on land is not inside a water polygon unless it's on a narrow barrier island or pier.
- **This is a gap in the current alert system, not a marine-feature issue.** Any coastal station operator whose weewx station is not directly on the waterline misses marine alerts — regardless of which alerts provider they use. A "Huntington Beach Weather" station that shows NWS alerts but not Small Craft Advisories is failing its visitors' expectations.
- **Where this lives: general alerts configuration, not the marine feature.** The marine alert radius is configured in the alerts section of the wizard/admin — alongside the alerts provider selection, not inside marine location setup. An operator who never enables marine pages still sees marine zone alerts in the dashboard's standard alert banner if their station is near the coast.
- **Solution — operator-defined marine alert radius:**
  1. Operator configures a **marine alert radius** in the alerts section of the wizard/admin (in miles). Default: 0 (disabled). The wizard auto-suggests a default of 25 miles when it detects the station is within 50 miles of a marine zone — otherwise leaves it at 0 for inland stations.
  2. At setup time, the system discovers which NWS marine zones fall within that radius:
     - Station lat/lon → NWS `/points` → get CWA (WFO office ID)
     - Fetch all coastal marine zones for that CWA from `/zones/coastal` (typically 6–16 zones per WFO)
     - For each zone, fetch its polygon geometry from `/zones/coastal/{zoneId}`, compute the minimum haversine distance from the station to the polygon's nearest vertex
     - Select all zones where the nearest polygon vertex is within the operator's radius
  3. Store the selected marine zone ID(s) in `api.conf`. Show the operator the discovered zones with distances for confirmation before saving.
  4. **Verified behavior (July 2026):** Wilmington NC (15km inland) at 25-mile radius → 2 zones (Surf City–Cape Fear nearshore + Cape Fear–Little River nearshore). Wrightsville Beach (on the water) at 25-mile radius → 2 zones (same nearshore + the 20–60nm offshore zone). Raleigh NC (200km inland) at 25-mile radius → 0 zones (correctly excluded). The algorithm scales to any station location.
- **Alert query change — all three providers:**
  - **NWS:** Make an additional `?zone={marineZoneId}` query for each configured marine zone, merge with existing `?point=` results, de-duplicate by alert ID.
  - **Xweather:** Test whether Xweather's own proximity logic already covers the configured marine zone. If not, supplement with a direct NWS `?zone=` query for the configured marine zone (NWS marine zone alerts are free and available regardless of which primary alerts provider the operator uses — the marine zone query is a supplemental data source, not a provider switch).
  - **OWM:** Same approach as Xweather — test first, supplement with NWS zone query if needed.
- **NWS zone taxonomy (verified via api.weather.gov, July 2026):**
  - **Public zones** (state-prefixed: NCZ, CAZ, FLZ, etc.) — land-based coastal areas. Issue: Beach Hazards Statement, Coastal Flood Advisory/Warning, Storm Surge Warning/Watch. These are captured by the existing `?point=` query when the station is in a coastal county.
  - **Coastal marine zones** (ocean-prefixed: AMZ, GMZ, PZZ, ANZ, PKZ, PHZ, etc.) — nearshore waters out to 20–60 NM. Issue: Small Craft Advisory, Gale Warning/Watch, Storm Warning, Hurricane Force Wind Warning, Hazardous Seas Warning/Watch, Dense Fog Advisory (marine), Special Marine Warning, Low Water Advisory. These require explicit zone queries for any station not directly on the waterline.
- **Scope:** This ADR modifies the existing alerts system and the general alerts configuration UI. It is completely independent of the marine feature — a coastal station benefits even without marine/surf/fishing enabled. The marine alert radius config lives in the alerts section of the wizard/admin, not in the marine location setup. Marine zone alerts appear in the dashboard's standard alert banner alongside all other NWS alerts.

**ADR-090 — Activity capability matrix**
- Defines exactly what capabilities each of the four activity categories (marine/boating, surf, fishing, beach safety) enables
- A capability is a specific data feed, enrichment processor, or UI feature. Each capability has a data source and may appear in one or more categories.
- This matrix is the authoritative reference for what "enabling surf" or "enabling fishing" actually means in terms of data fetched, processing run, and UI rendered. Without it, every downstream design decision is guesswork.

  | Capability | Data source | Marine/Boating | Surf | Fishing | Beach Safety |
  |---|---|:---:|:---:|:---:|:---:|
  | **Wave data** | | | | | |
  | Offshore wave forecast (Hs, period, direction) | WaveWatch III (ERDDAP) | Yes | Yes | — | — |
  | Nearshore wave data + ADR-084 supplements | NWPS (GRIB2) | Yes | Yes | — | Yes |
  | Surf quality scoring (1–5 stars) | Enrichment: surf_scorer | — | Yes | — | — |
  | Multi-swell spectral breakdown | NDBC .data_spec/.swdir | — | Yes | — | — |
  | **Tides & water levels** | | | | | |
  | Tide predictions (high/low times + heights) | CO-OPS API | Yes | Yes | Yes | Yes |
  | Observed water levels | CO-OPS API | Yes | — | — | Yes |
  | **Observations** | | | | | |
  | Buoy observations (wind, pressure, air temp, SST) | NDBC standard met | Yes | Yes | Yes | — |
  | Water temperature | NDBC / CO-OPS | — | Yes | Yes | Yes |
  | **Forecasts** | | | | | |
  | NWS marine zone text forecast (wind, seas, visibility) | NWS API (marine zone) | Yes | — | — | — |
  | NWS surf zone forecast (rip current risk, surf height) | NWS SRF product | — | Yes | — | Yes |
  | **Alerts** | | | | | |
  | Marine zone alerts (SCA, Gale, Storm, Hurricane Force, Hazardous Seas, Dense Fog, Special Marine Warning) | NWS API (coastal marine zones: AMZ/GMZ/PZZ/ANZ) | Yes | Yes | Yes | — |
  | Coastal/beach alerts (Beach Hazards Statement, High Surf Advisory/Warning, Rip Current Statement) | NWS API (public zones: state-prefixed) | — | Yes | — | Yes |
  | Coastal flood alerts (Coastal Flood Advisory/Warning, Storm Surge Warning/Watch) | NWS API (public zones) | Yes | — | — | Yes |
  | **Enrichment** | | | | | |
  | Solunar times (major/minor periods) | Skyfield (computed) | — | — | Yes | — |
  | Fishing scoring (pressure, tide, species, solunar) | Enrichment: fishing_scorer | — | — | Yes | — |
  | Bathymetric habitat features (drop-offs, reefs, ledges) | NOAA CUDEM | — | — | Yes | — |
  | **NWPS v1.5 (show-when-available)** | | | | | |
  | Rip current probability | NWPS v1.5 (~12 WFOs) | — | — | — | Yes |
  | Total water level | NWPS v1.5 | Yes | — | — | Yes |
  | Wave runup | NWPS v1.5 | — | — | — | Yes |

- **Cross-category capabilities:** Tide predictions, marine zone alerts, and nearshore wave data appear in multiple categories. Enabling any one of those categories triggers the data feed; disabling the last category that uses a feed stops fetching it.
- **Marine zone alerts are NOT gated by the marine feature.** They are part of the general alerts system (ADR-089). When an operator configures a marine alert radius (in the alerts config, not the marine config), those alerts appear in the dashboard's standard alert banner for all visitors — regardless of whether any marine activity categories are enabled. The matrix above shows which marine pages would *additionally* display them; the general alert banner always shows them.
- **Alert routing on marine pages:** When marine activities are enabled, the marine/surf/fishing/beach safety pages show activity-relevant alerts from the general alert feed (filtered by alert type). Coastal/beach alerts (Beach Hazards Statement, High Surf Advisory/Warning, Rip Current Statement) route to surf and beach safety pages. Coastal flood alerts route to marine and beach safety pages. This is filtering for relevance, not a separate data feed.
- **This matrix will evolve** as implementation reveals additional capabilities or refinements, but it must exist as a baseline before implementation begins. Changes go through the normal ADR amendment process.

### ADR Sizing Note
These ADRs should be **as detailed as the subject demands** — not constrained to the ~80 line standard. The marine domain involves NOAA data ecosystems, wave transformation physics, scoring algorithms with research citations, multi-spot configuration paradigms, native dependency management, and alert system extensions. Each ADR includes the full context, research basis (with sources), options analysis, and implementation guidance needed for implementation agents to execute correctly without re-deriving decisions. The research briefs provide the background; the ADRs make the decisions concrete and prescriptive.

### QC Gate 0A
All ADRs drafted as Proposed, reviewed by user, Accepted before proceeding. Each ADR follows Nygard format. No implementation code until all ADRs are Accepted.

---

## PHASE 0B — Manual Consolidation ✓ COMPLETE

All ADR prescriptive rules consolidated into governing manuals (2026-07-09):
- PROVIDER-MANUAL §14 "Marine & Coastal Providers" (8 subsections) + §8 alerts amendment (marine zone extension) + §1 layout/domain updates
- API-MANUAL §16 "Marine Data Model" (13 models + 5 unit groups) + §17 "Marine Enrichment" (4 processors) + §18 "Marine Endpoints" (6 endpoints)
- OPERATIONS-MANUAL: §1 eccodes dependency + §4 marine alert radius + marine config schema + setup procedure
- DASHBOARD-MANUAL §12 "Marine Pages" (4 pages, navigation, alert filtering, refresh intervals)
- ARCHITECTURE.md: provider layout, endpoints, routes, config, caching, eccodes dependency
- All 8 ADRs archived to `docs/archive/decisions/`, INDEX.md updated
- T0B.1 decision: fold into existing manuals (no standalone MARINE-MANUAL.md)

Per ADR lifecycle: after acceptance, extract prescriptive rules into target manuals. Implementation agents read manuals, not ADRs — if it's not in a manual, agents won't follow it.

### Tasks

**T0B.1 — Determine manual structure**
- Owner: Coordinator (Opus)
- Do: Assess whether marine content warrants a standalone `MARINE-MANUAL.md` or folds into existing manuals (API-MANUAL, PROVIDER-MANUAL, OPERATIONS-MANUAL, DASHBOARD-MANUAL). Assessment criteria: volume of marine-specific content (scoring algorithms, physics formulas, NWPS/NDBC/CO-OPS data source details, multi-spot config, species data) vs. how naturally it fits into existing manual sections. Document the decision in this plan.
- Accept: Decision documented. If standalone manual, file created with skeleton sections. If fold-in, target sections identified per manual.
- **Decision (2026-07-09): Fold into existing manuals.** Marine content follows existing manual structures naturally — provider modules → PROVIDER-MANUAL, models/units/enrichment → API-MANUAL, config/deployment → OPERATIONS-MANUAL, pages → DASHBOARD-MANUAL. A standalone MARINE-MANUAL.md would either duplicate the §1-§7 provider contract or add another file to the routing table without structural benefit. Target sections:
  - **PROVIDER-MANUAL §14** — Marine & Coastal Providers (NDBC, CO-OPS, WaveWatch III, NWS Marine, NWS SRF, NWPS, Bathymetry) + §8 Alerts amendment (marine zone extension)
  - **API-MANUAL §16** — Marine Data Model (canonical models, unit groups) + §17 Marine Enrichment + §18 Marine Endpoints
  - **OPERATIONS-MANUAL §1** amendment (eccodes) + §4 amendment (marine config, marine alert radius, setup procedure)
  - **DASHBOARD-MANUAL §12** — Marine Pages (marine, surf, fishing, beach safety, navigation, alert filtering)
  - **ARCHITECTURE.md** — provider layout, endpoints, dependencies, dashboard routes, config files

**T0B.2 — Update PROVIDER-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do: Add new sections for each marine provider module. Each section follows the existing provider contract pattern (§1–§7 of the manual: module identity, capability declaration, wire model, normalization, cache, error handling, testing). Specific additions:
  - **§14.1 NDBC buoy observations** (`providers/buoy/ndbc.py`): flat-file HTTP access pattern (not REST API), `.txt` standard met parsing (handle `MM` missing markers), `.data_spec`/`.swdir` spectral parsing (46 frequency bands, `VALUE(FREQ)` token-pair format — **live-verified 2026-07-09; `.swden` returns 404**), `activestations.xml` station discovery, cache TTL 60 min. Wire format: fixed-width text columns, not JSON. Station capability differentiation best-effort via XML type attributes.
  - **§14.2 CO-OPS tides & water levels** (`providers/tides/coops.py`): CO-OPS Data API (JSON), tide predictions endpoint, water levels endpoint, water temp, currents. Metadata API for station discovery by lat/lon. Cache TTLs: predictions 6 hr, observations 10 min. Datum handling (MLLW, MSL, NAVD88).
  - **§14.3 WaveWatch III forecasts** (`providers/marine/wavewatch.py`): ERDDAP JSON access (NOT GRIB), griddap URL construction with lat/lon/time subsetting, grid selection logic (7 grids with geographic bounds and priority), 72h forecast at 3h steps, cache TTL 30 min. Note: GFS Wave coupled model, ~4.5h data availability delay.
  - **§14.4 NWS marine zone text forecasts** (`providers/marine/nws_marine.py`): `api.weather.gov/zones/coastal/{zoneId}/forecast` (JSON-LD/GeoJSON), marine zone discovery algorithm (station → CWA → zone list → polygon proximity within operator radius), cache TTL 30 min. Zone IDs shared with ADR-089 alerts extension.
  - **§14.6 NWPS nearshore wave data** (`providers/marine/nwps.py`): GRIB2 from NOMADS (`nomads.ncep.noaa.gov/pub/data/nccf/com/nwps/prod/`), eccodes dependency (ADR-085), WFO domain determination, CG grid selection (CG1 baseline, CG2–CG5 nested), extracted fields (wave height, period, direction, currents, bottom orbital velocity, rip current probability, total water level, wave runup). 2–3 cycles/day per WFO, no fallback pipeline.
  - **§14.7 NOAA CUDEM bathymetry** (`enrichment/bathymetry.py`): NCEI THREDDS/OPeNDAP access, one-time per-spot operation, adaptive refinement, 1/9 arc-second (~3.4m) resolution, regional depth profile adaptations, fallback profiles, attribution requirements.
  - **§14.5 NWS Surf Zone Forecast** (`providers/marine/nws_srf.py`): text product access via `api.weather.gov/products/types/SRF/locations/{wfo}`, parsing rip current risk, surf height, UV index, water temp from free-text format. Cache TTL 60 min (issued 1–2x/day). Shared rate limiter with NWS alerts. County zone matching from spot coordinates.
  - **§14.8 NWS alerts marine zone extension (shared zone discovery utility)** (modification to existing `providers/alerts/nws.py`): marine zone discovery algorithm, `?zone={id}` supplemental query, de-duplication, all-provider coverage (NWS confirmed gap, Xweather/OWM test-and-supplement). This section goes in the existing alerts provider chapter, not the marine chapter.
- Accept: Each provider section follows the manual's existing §1–§7 contract pattern. An implementation agent reading only the manual section can build the provider module without referencing ADRs or briefs. grep for "TODO" or "TBD" returns zero hits in new sections.

**T0B.3 — Update API-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Do: Add sections for:
  - **Marine canonical models**: field definitions for `MarineObservation`, `SpectralWaveComponent`, `TidePrediction`, `WaterLevel`, `MarineForecastPoint`, `MarineTextForecast`, `SurfForecast`, `FishingForecast`, `SolunarTimes`, bundle types, `MarineLocationSummary`. Each model: field name, type, unit group, nullable?, description. Follow existing `EarthquakeRecord` pattern.
  - **Marine unit groups**: `group_wave_height` (m, ft), `group_wave_period` (s), `group_water_level` (m, ft), `group_ocean_speed` (m/s, kt, mph, km/h), `group_visibility` (nm, statute mile, km). Conversion formulas. Preset defaults table showing that `group_ocean_speed` and `group_visibility` default to knots and nautical miles respectively in ALL three presets (US, METRIC, METRICWX) — maritime convention overrides land convention. Note on `group_ocean_speed` vs `group_speed` separation (marine vs land wind). Follow existing unit group pattern.
  - **Marine enrichment processors**: NWPS supplement processor (four supplements per ADR-084 with formulas), surf quality scorer (weights, coefficients, multi-swell integration, conditions text), fishing scorer (weights, species profiles, seasonal behavior, solunar integration), solunar computation (Skyfield, major/minor periods). Each processor: inputs, outputs, registration, configuration.
  - **Marine endpoint patterns**: `GET /api/v1/marine[/{locationId}]`, `/tides[/{locationId}]`, `/surf[/{locationId}]`, `/fishing[/{locationId}]`, `/almanac/solunar`. Request params, response shape, capability gating, freshness block, unit conversion. Follow existing endpoint pattern.
- Accept: Models section specifies every field. Unit groups section specifies every conversion. Enrichment section specifies every formula and coefficient. Endpoint section specifies every request/response contract. An implementation agent can build from the manual without referencing the plan.

**T0B.4 — Update OPERATIONS-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/OPERATIONS-MANUAL.md`
- Do: Add sections for:
  - **Marine alert radius** (in the existing alerts configuration section, NOT a marine section): config key, default value, wizard behavior (auto-suggest 25 miles when within 50 miles of marine zone), zone discovery algorithm, operator confirmation UI.
  - **eccodes native dependency**: platform-specific install instructions (Debian/Ubuntu: `apt install libeccodes-dev`, RHEL: `dnf install eccodes-devel`, macOS: `brew install eccodes`), pip install with `[marine]` extra, Docker (baked in), detection behavior (clear error with install instructions when marine enabled without eccodes).
  - **Marine config section in `api.conf`**: `[marine]` section schema, `[[locations]]` subsections, activity configuration, station IDs, NWPS WFO code, bathymetric profile storage.
  - **Marine location setup procedure**: step-by-step wizard flow, station auto-discovery, NOAA CUDEM bathymetry download, configuration verification.
- Accept: An operator can configure marine features by reading only the OPERATIONS-MANUAL. No reference to ADRs, briefs, or this plan needed.

**T0B.5 — Update DASHBOARD-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do: Add sections for marine/surf/fishing/beach safety page behavior, location-centric navigation, `pages.json` entries, alert filtering per ADR-090 capability matrix, responsive breakpoints, i18n key patterns, data refresh intervals.
- Accept: Dashboard agent can build pages from manual alone.

**T0B.6 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do: Add marine/tides/buoy domains to provider module layout. Add marine endpoints to endpoint inventory. Add marine freshness defaults. Add eccodes native dependency to dependency list. Add marine pages to dashboard routes. Add marine alert radius to config registry.
- Accept: ARCHITECTURE.md reflects the system as it will be after all phases complete.

**T0B.7 — Archive ADRs**
- Owner: Coordinator (Opus)
- Do: Move all 8 accepted ADRs to `docs/archive/decisions/` with status "Archived — consolidated into {MANUAL-NAME}.md". Update INDEX.md.
- Accept: ADRs archived. INDEX.md updated. No Proposed or Accepted ADRs remain for this batch.

### QC Gate 0B
- Coordinator verifies: every prescriptive rule from every ADR appears in the target manual. Manual-authority hierarchy maintained (manuals > ADRs). grep each manual for "TODO"/"TBD" returns zero hits in new sections.
- Coordinator verifies: doc-code sync — manuals describe what will be built, not what exists yet. Pre-implementation documentation is expected and correct at this stage.
- Coordinator verifies: ADR INDEX.md updated, archived ADRs moved.

### QA Gate 0B
- `clearskies-auditor`: independently reads each ADR and its target manual section. For each prescriptive rule in the ADR, confirms a corresponding rule exists in the manual. Reports any rules that were lost in translation or softened from the ADR's specificity. Reports any manual sections that contradict existing manual content.

---

## PHASE 0C — Data Model & Canonical Types ✓ COMPLETE

All canonical types, config schema, and unit groups implemented (2026-07-09):
- T0C.1: 17 Pydantic models in `models/responses.py` (12 domain + 5 bundles) — commit 4ae5288
- T0C.2: `config/marine_config.py` (408 lines, 8 dataclasses + loader) — commit b1e51eb
- T0C.3: 5 marine unit groups in `units/groups.py`, `units/conversion.py`, `services/units.py` — commit 656f72e
- T0C.4: Dispatch registry verified open-ended (no changes needed)
- QC: 84/84 model tests, 37/37 unit tests, all conversions verified, config loader verified

Define response models, config structures, and unit groups. No provider calls, no UI. This phase produces the types that all subsequent phases build on — if a field is wrong here, every provider and endpoint inherits the mistake.

### Tasks

**T0C.1 — Canonical marine response models**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (additions to existing file)
- Reference: API-MANUAL marine canonical models section (written in T0B.3), existing `EarthquakeRecord` and `AlertRecord` patterns in the same file
- Do: Add Pydantic models for all marine response types. Each model must include field name, type annotation, unit group assignment (where applicable), Optional markers, and Field descriptions. Models to add:
  - `MarineObservation` — wind speed/dir/gust, wave height/period/direction, pressure, air/water temp, visibility, dewpoint. Fields per NDBC standard met `.txt` columns.
  - `SpectralWaveComponent` — height, period, direction, energy, frequency range. One per detected swell system from spectral decomposition.
  - `TidePrediction` — time (UTC ISO-8601), height, type (high/low). Per CO-OPS prediction datum.
  - `WaterLevel` — time, height, datum, quality flag. Per CO-OPS observation.
  - `MarineForecastPoint` — time, wave height, wave period, wave direction, wind speed, wind direction, swell height, swell period, swell direction, wind wave height, wind wave period. Per WaveWatch III forecast step.
  - `MarineTextForecast` — period name, text, wind, seas, visibility, weather. Per NWS marine zone forecast period.
  - `SurfForecast` — time, wave_height_at_break, period, direction, quality_stars (1–5), quality_label, conditions_text, wind_quality, swell_dominance, multi_swell (list of SpectralWaveComponent). Per forecast step per spot.
  - `FishingForecast` — period_start, period_end, period_label, overall_score (0–100 int), pressure_score (0–100), tide_score (0–100), solunar_score (0–100), water_temp_score (0–100), species_scores (list), conditions_text, wind_speed, wind_direction, wind_gust, swell_height, swell_period (informational — not scored, displayed alongside). Per forecast period.
  - `SolunarTimes` — date, moon_phase, moon_illumination, moonrise, moonset, moon_transit, moon_underfoot, major_periods (list of start/end), minor_periods (list of start/end), intensity (0.0–1.0).
  - `SurfZoneForecast` — date, county_zone, rip_current_risk (low/moderate/high), surf_height_min, surf_height_max, uv_index, water_temp, wind_text, hazards_text. Per NWS SRF text product forecast day.
  - `BeachSafetyAssessment` — safety_level (safe/caution/dangerous), wave_height, wave_period, rip_current_risk, water_temp, comfort_level (comfortable/cool/cold/dangerous), uv_index, visibility, wind_speed, wind_direction, active_alerts (list). Per location snapshot.
  - `MarineLocationSummary` — location_id, name, coordinates, activities, current_conditions (optional MarineObservation), current_tide (optional), active_alerts (list), surf_rating (optional), beach_safety_level (optional).
  - Bundle types: `MarineBundle`, `TideBundle`, `SurfBundle`, `FishingBundle`, `BeachSafetyBundle` — wrap the above with location metadata, freshness block, stationClock.
- Accept: All models importable. `model.model_validate({})` raises `ValidationError` (not crash) for required-field models. `model.model_json_schema()` produces valid JSON Schema. Existing tests pass unchanged (no regression). Models match API-MANUAL field definitions exactly.

**T0C.2 — Marine location config schema**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py`
- Reference: OPERATIONS-MANUAL marine config section (written in T0B.4), existing `config/settings.py` pattern
- Do: Add dataclasses for marine configuration parsed from `api.conf`:
  - `MarineLocation` — `id: str`, `name: str`, `lat: float`, `lon: float`, `activities: list[str]` (from: "marine", "surf", "fishing", "beach_safety"), `ndbc_station_ids: list[str]`, `coops_station_ids: list[str]`, `nws_marine_zone_id: str | None`, `nwps_wfo: str | None`, `nwps_cg_grid: str | None`, `station_distance_km: float` (computed at config time — haversine distance from station to this location; used to determine weather source automatically)
  - `SurfSpotConfig` — `beach_facing_degrees: float` (0–360), `bottom_type: Literal["sand","rock","coral_reef","mixed"]`, `beach_slope: float | None` (computed from NOAA CUDEM), `structures: list[StructureConfig]`, `bathymetric_profile: list[BathymetryPoint] | None` (stored after CUDEM download), `topographic_feature: Literal["point_break","bay_break","headland","straight_beach"]`, `directional_exposure: dict[str, bool]` (8 compass dirs → bool)
  - `StructureConfig` — `type: Literal["jetty","pier","breakwater","seawall","groin"]`, `material: Literal["impermeable","semi_permeable","permeable"]`, `length_m: float`, `bearing_degrees: float`, `distance_m: float` (from spot)
  - `BathymetryPoint` — `distance_m: float`, `depth_m: float`
  - `FishingSpotConfig` — `target_category: Literal["saltwater_inshore","bottom_fish","freshwater_sport","salmonids"]` (`saltwater_offshore` removed in Phase 0A — fishing scoped to nearshore/freshwater recreational per ADR-088), `species: list[str]` (auto-populated from biogeographic region), `biogeographic_region: str` (auto-classified from coordinates)
  - `BeachSafetyConfig` — `external_links: list[ExternalLink]` (operator-provided links to local water quality, lifeguard reports, wildlife alert services — displayed on the beach safety page as informational resources)
  - `ExternalLink` — `label: str`, `url: str`
  - `MarineWeatherConfig` — `forecast_ttl_hours: Literal[1, 3, 6] = 3`, `observation_ttl_minutes: Literal[15, 30, 60] = 30`, `dedup_radius_km: float = 2.5` (locations within this distance share forecast/observation calls)
  - `MarineConfig` — `locations: list[MarineLocation]`, `surf_spots: dict[str, SurfSpotConfig]` (keyed by location_id), `fishing_spots: dict[str, FishingSpotConfig]` (keyed by location_id), `beach_safety: dict[str, BeachSafetyConfig]` (keyed by location_id), `weather: MarineWeatherConfig` (refresh intervals and dedup settings)
  - `load_marine_config(api_conf_path) -> MarineConfig | None` — returns None when no `[marine]` section present
- Accept: Config loads from a test `api.conf` with marine section. Empty marine section → empty MarineConfig. Missing marine section → None. Invalid values raise clear errors with field names. Existing settings tests pass unchanged.

**T0C.3 — Marine unit groups**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/units/groups.py` (additions to `US_UNITS`, `METRIC_UNITS`, `METRICWX_UNITS`)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/services/units.py` (additions to `_SYSTEM_PRESETS`)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/units/transformer.py` (register conversions)
  - `repos/weewx-clearskies-api/contracts/canonical-data-model.md` (additions)
- Reference: API-MANUAL marine unit groups section (written in T0B.3), existing unit group registration pattern in `units/groups.py` and `units/transformer.py`
- Do: Register five new unit groups with conversions and preset defaults:
  - `group_wave_height`: base=meter, conversions: meter↔foot (×3.28084)
  - `group_wave_period`: base=second (single unit — no conversion, but group needed for canonical consistency)
  - `group_water_level`: base=meter, conversions: meter↔foot (×3.28084)
  - `group_ocean_speed`: base=meter_per_second, conversions: m/s↔knot (×1.94384), m/s↔mph (×2.23694), m/s↔km/h (×3.6)
  - `group_visibility`: base=nautical_mile, conversions: nm↔statute_mile (×1.15078), nm↔kilometer (×1.852). Source: NDBC VIS column (reported in nautical miles).
  - **Preset defaults for marine groups:**

    | Marine group | US | METRIC | METRICWX |
    |---|---|---|---|
    | `group_wave_height` | foot | meter | meter |
    | `group_wave_period` | second | second | second |
    | `group_water_level` | foot | meter | meter |
    | `group_ocean_speed` | **knot** | **knot** | **knot** |
    | `group_visibility` | nautical_mile | nautical_mile | nautical_mile |

    **`group_ocean_speed` defaults to knots in ALL three presets.** This is the one case where the maritime convention overrides the land convention. Knots are universal at sea regardless of country — WMO, IMO, and every national maritime service uses knots for wind speed and current speed over water. Even countries that use m/s on land (Scandinavia, etc.) use knots for marine weather. Similarly, visibility at sea is universally reported in nautical miles. Operators who prefer m/s or km/h for ocean speeds can override via the existing per-group mechanism in `api.conf [units][[groups]]`.
  - Add marine groups to all three preset dicts in `units/groups.py` (`US_UNITS`, `METRIC_UNITS`, `METRICWX_UNITS`).
  - Add marine groups to `_SYSTEM_PRESETS` in `services/units.py` with display labels (e.g., `"kt"`, `"ft"`, `"nm"`).
  - Update `canonical-data-model.md` with new unit group definitions and preset mappings.
  - **Note on land vs. marine speed groups:** The existing `group_speed` (used for land wind speed) remains unchanged — it maps to mph/km·h⁻¹/m·s⁻¹ per the existing presets. `group_ocean_speed` is a separate group specifically for marine wind, current, and wave-related speeds. This means an operator using METRICWX will see land wind in m/s and marine wind in knots by default — which is correct practice (weather services do exactly this). If they want both in m/s, they override `group_ocean_speed = meter_per_second`.
- Accept: `UnitTransformer.convert(1.0, "group_wave_height", "us")` returns `3.28084`. `UnitTransformer.convert(1.0, "group_ocean_speed", "us")` returns `1.94384` (knots). `UnitTransformer.convert(1.0, "group_ocean_speed", "metric")` also returns `1.94384` (knots — same across all presets). `UnitTransformer.convert(1.0, "group_visibility", "us")` returns `1.0` (nautical miles — base unit, same across presets). All five groups registered and round-trip correctly. Existing unit tests pass unchanged.

**T0C.4 — Dispatch registry preparation**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/services/dispatch.py` (or equivalent registry file)
- Reference: existing dispatch registry pattern, PROVIDER-MANUAL §dispatch
- Do: Verify the dispatch registry accepts `"marine"`, `"tides"`, `"buoy"` as valid domain strings. If the registry uses an enum or allowlist, add the new domains. If it's open-ended string matching, verify no validation rejects unknown domains.
- Accept: A provider module with `DOMAIN = "marine"` (or `"tides"` or `"buoy"`) would be accepted by dispatch at startup without modification. No existing provider registration is disrupted.

### QC Gate 0C
- Coordinator runs: `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"` — baseline must hold (2311 passed, 365 skipped, 0 failed). New tests for marine models, config, and unit groups must pass.
- Coordinator verifies: every field in API-MANUAL marine models section has a corresponding Pydantic field in `responses.py`. Every unit group in API-MANUAL marine unit groups section is registered in `unit_transformer.py`.
- Coordinator verifies: `MarineConfig` loads from a sample `api.conf` with `[marine]` section. Config with no `[marine]` section returns None (not crash).

### QA Gate 0C
- `clearskies-auditor`: reads API-MANUAL marine models and canonical-data-model.md. Cross-checks every field against the Pydantic model code. Reports any field present in the manual but missing from code, or present in code but missing from the manual. Verifies unit group conversions are dimensionally correct (spot-check: 1 meter = 3.28084 feet, 1 m/s = 1.94384 knots, 1 nm = 1.852 km). Verifies marine groups are present in all three preset dicts (`US_UNITS`, `METRIC_UNITS`, `METRICWX_UNITS`) and in `_SYSTEM_PRESETS`. Verifies `group_ocean_speed` defaults to knot in all three presets. Verifies `group_visibility` defaults to nautical_mile in all three presets.

---

## PHASE 1 — NOAA Provider Modules + Marine Zone Alerts — ✓ COMPLETE

Five provider modules following the existing contract (PROVIDER-MANUAL §1–§7: module identity, `CAPABILITY` constant, wire-shape Pydantic models, normalization to canonical types, cache layer, error handling via `ProviderHTTPClient`, `fetch()` entrypoint). Plus marine zone alerts extension to the existing alert system.

**QC Gate 1 passed (2026-07-10).** Pushed to GitHub, deployed to weewx (health 200), all 5 provider imports verified, dispatch registry confirmed (5 marine entries), alerts regression verified (`marine_zone_ids` default `None`), 190 targeted tests passed (0 failed). Full suite: 3799 passed; 95 pre-existing failures in `aqi/test_openweathermap` — unrelated to marine changes.

| Task | Commit | Lines | Status |
|------|--------|-------|--------|
| T1.1 NDBC buoy observations | 31d5e63 | 939 | Done |
| T1.2 CO-OPS tides & water levels | 4bc648f | 713 | Done |
| T1.3 WaveWatch III forecasts | 858a791 | 562 | Done |
| T1.4 NWS marine + nws_zones.py | cfc58e2 | 361+618 | Done |
| T1.5 NWS Surf Zone Forecast | ef571ff | 931 | Done |
| T1.6 Dispatch wiring (5 providers) | 37424ea | — | Done |
| T1.7 Marine zone alerts | b864ec4 | — | Done |

**Resolved issues:**
1. ~~WaveWatch grid overlap~~: wcoast.0p16 lon narrowed from -165..-100 to -130..-100 (commit 6f71451). Hawaii routes to epacif.0p16.
2. ~~PROVIDER-MANUAL §14.1~~: corrected .swden → .data_spec with VALUE(FREQ) token pairs (meta repo commit 0cc25b5).
3. ERDDAP dataset names: not live-verified; documented in wavewatch.py for integration testing.
4. ~~MarineForecastPoint windWaveDirection~~: added mid-phase (commit 351e516), API-MANUAL §16 already updated.

**Local QC (pre-deploy):**
- All 5 providers import cleanly with correct CAPABILITY declarations
- Dispatch registry: 28 total entries (5 new marine)
- NWS alerts `marine_zone_ids` defaults to None — zero regression when unconfigured

### Tasks

**T1.1 — NDBC buoy observations**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/buoy/ndbc.py`
- Reference: PROVIDER-MANUAL §14.1 NDBC, existing `providers/alerts/nws.py` as pattern, `docs/reference/api-docs/` for NDBC wire format, MARINE-DATA-AUDIT-BRIEF §A.3 for field inventory
- Do:
  - Module structure: `PROVIDER_ID = "ndbc"`, `DOMAIN = "buoy"`, `CAPABILITY` declaration with supplied fields, rate limiter (1 req/s — NDBC is a flat-file server, no documented rate limit but be polite), module-level `ProviderHTTPClient` singleton, cache key builder, `fetch()` entrypoint.
  - **Standard met (`.txt`) parsing:** Fetch `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.txt`. Fixed-width text columns (NOT JSON). First two rows are headers (column names + units). Handle `MM` markers as None (missing data). Columns: WDIR, WSPD, GST, WVHT, DPD, APD, MWD, PRES, ATMP, WTMP, DEWP, VIS, PTDY, TIDE. Parse most recent observation row. Map to canonical `MarineObservation` via UnitTransformer (NDBC reports in metric — m, m/s, °C, hPa — but verify per column).
  - **Spectral density (`.data_spec`) parsing:** Fetch `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.data_spec`. **Live-verified (2026-07-09): `.swden` returns 404; `.data_spec` is the correct extension.** Wire format: each data row contains `VALUE (FREQ)` token pairs (not simple columns) — parse via regex. Skip the `Sep_Freq` column (separation frequency between wind waves and swell; appears after the 5-column timestamp, before spectral pairs). Decompose into swell systems: identify spectral peaks (local maxima in energy density), partition energy around each peak, compute Hs = 4√m₀, Tp = 1/fp, direction from `.swdir` for each partition. Map each partition to `SpectralWaveComponent`.
  - **Spectral direction (`.swdir`) parsing:** Fetch `https://www.ndbc.noaa.gov/data/realtime2/{stationId}.swdir`. Uses the same `VALUE (FREQ)` token-pair format as `.data_spec`. Mean wave direction at each spectral frequency. Used alongside `.data_spec` to assign direction to each swell system.
  - **Station discovery:** Fetch `https://www.ndbc.noaa.gov/activestations.xml`. Parse XML for station IDs, coordinates, sensor types. Differentiate wave-only vs. atmospheric-only vs. full-capability buoys (per MARINE-DATA-AUDIT-BRIEF §C.3). Return list of nearby stations with capabilities and distances.
  - Cache: keyed by (provider_id, station_id). TTL 60 min for standard met, 60 min for spectral.
  - Error handling: 404 for non-existent station → `ProviderProtocolError`. Empty file → log WARNING, return empty observation. Network errors → canonical taxonomy via `ProviderHTTPClient`.
- Tests (`clearskies-test-author`):
  - Capture real `.txt`, `.data_spec`, `.swdir` files as test fixtures (from a known station like 41025 or 46225).
  - Unit tests: parse fixture → verify canonical field values against hand-checked data.
  - Unit tests: `MM` markers → None fields.
  - Unit tests: spectral decomposition → verify peak detection against known multi-swell case.
  - Integration test: fetch live data from a real station, verify non-empty canonical result.
- Accept: `fetch(station_id="41025")` returns a `MarineObservation` with non-None wave height and period. Spectral decomposition produces 1–4 `SpectralWaveComponent` objects for a multi-swell station. `MM` markers produce None, not crash. Station discovery returns stations with correct capabilities. Existing tests pass unchanged.

**T1.2 — CO-OPS tides & water levels**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/tides/coops.py`
- Reference: PROVIDER-MANUAL §14.2 CO-OPS, CO-OPS Data API docs at `docs/reference/api-docs/`, existing provider patterns
- Do:
  - Module structure: `PROVIDER_ID = "coops"`, `DOMAIN = "tides"`, standard provider contract.
  - **Tide predictions:** `GET https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?product=predictions&datum=MLLW&station={id}&begin_date={today}&range=72&units=metric&time_zone=gmt&application=clearskies&format=json`. Parse `predictions[]` array → list of `TidePrediction` (time, height, high/low classification). High/low classification: compare each prediction to neighbors — if height > both neighbors, it's high; if height < both neighbors, it's low; otherwise interpolated.
  - **Water levels (observed):** `product=water_level&datum=MLLW&...&range=24`. Parse `data[]` → list of `WaterLevel` (time, height, datum, quality flag).
  - **Water temperature:** `product=water_temperature&...&range=24`. Parse → water temp values. Some stations don't report water temp — handle gracefully (empty list, not error).
  - **Station discovery:** `GET https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=waterlevels&units=metric`. Filter by distance from coordinates. Return station ID, name, distance, available products (predictions, water_level, water_temperature, currents).
  - Cache: predictions TTL 6 hr (they don't change within a tidal epoch), observations TTL 10 min.
  - `application=clearskies` param on all requests (CO-OPS asks users to identify their application).
- Tests (`clearskies-test-author`):
  - Capture real JSON responses as fixtures.
  - Unit tests: parse predictions → verify high/low classification against known tide table.
  - Unit tests: parse water levels → verify datum handling.
  - Integration test: fetch predictions for a real station (e.g., 8658163 Wrightsville Beach), verify non-empty result with realistic heights.
- Accept: Predictions for 72 hours with correct high/low classifications. Water levels with quality flags. Station discovery returns stations with distance. Existing tests unchanged.

**T1.3 — GFS Wave (WaveWatch III coupled) forecasts**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/wavewatch.py`
- Reference: PROVIDER-MANUAL §14.3 WaveWatch III, MARINE-DATA-AUDIT-BRIEF §B.5 for grid inventory, MARINE-SURF-FISHING-RESEARCH-BRIEF §5.1 for ERDDAP access
- Do:
  - Module structure: `PROVIDER_ID = "wavewatch"`, `DOMAIN = "marine"`, standard provider contract.
  - **ERDDAP JSON fetch:** Construct griddap URL: `https://erddap.aoml.noaa.gov/hdb/erddap/griddap/{grid_dataset}.json?{variables}[({time_start}):1:({time_end})][({lat_nearest})][({lon_nearest})]`. Variables: `Thgt` (wave height), `Tper` (peak period), `Tdir` (peak direction), `shww` (wind wave height), `mpww` (wind wave period), `wvdir` (wind wave direction), `shts` (swell height), `mpts` (swell period), `swdir` (swell direction), `ws` (wind speed), `wdir` (wind direction).
  - **Grid selection:** Port Phase II logic — 7 grids with geographic bounds and priority: `atlocn.0p16` (US East Coast, priority 1), `wcoast.0p16` (US West Coast, 1), `epacif.0p16` (Hawaii/Pacific, 1), `arctic.9km` (Alaska, 1), `global.0p16` (global primary, 2), `gsouth.0p25` (Southern Hemisphere, 2), `global.0p25` (global fallback, 3). For given lat/lon, check bounds → select highest priority match.
  - **Forecast extraction:** 72-hour forecast at 3-hour steps (25 timesteps). Each step → `MarineForecastPoint`. Model run cycle: current UTC - 4.5 hour delay → most recent from [0, 6, 12, 18]. Fall back to 3 previous cycles if current unavailable.
  - Cache: TTL 30 min. Key includes grid ID and nearest lat/lon (rounded to grid resolution).
- Tests (`clearskies-test-author`):
  - Capture real ERDDAP JSON response as fixture.
  - Unit tests: grid selection → verify US East Coast point selects `atlocn.0p16`, Hawaii point selects `epacif.0p16`, mid-Atlantic point selects `global.0p16`.
  - Unit tests: parse ERDDAP JSON → verify MarineForecastPoint fields.
  - Integration test: fetch forecast for Cape Hatteras (35.2, -75.5), verify 25 timesteps.
- Accept: Grid selection correctly routes to highest-priority matching grid. 72-hour forecast with 25 non-null timesteps. Wind and swell components separated. Existing tests unchanged.

**T1.4 — NWS marine zone text forecasts**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nws_marine.py`
- Reference: PROVIDER-MANUAL §14.4 NWS marine zone text, existing `providers/alerts/nws.py` for NWS API patterns (User-Agent, rate limiting)
- Do:
  - Module structure: `PROVIDER_ID = "nws_marine"`, `DOMAIN = "marine"`, standard provider contract.
  - **Zone forecast fetch:** `GET https://api.weather.gov/zones/coastal/{zoneId}/forecast` with `User-Agent: weewx-clearskies-api/{version} (contact email)`. Parse JSON-LD/GeoJSON response → `properties.periods[]` → list of `MarineTextForecast` (period name, text, wind, seas, visibility, weather).
  - **Marine zone discovery utility** (shared with T1.5 and T1.7): given station lat/lon and radius (miles):
    1. `GET /points/{lat},{lon}` → extract `cwa` (WFO ID)
    2. `GET /zones/coastal` → filter by CWA → get zone IDs for this WFO (typically 6–16)
    3. For each zone, `GET /zones/coastal/{zoneId}` → extract polygon geometry
    4. Compute minimum haversine distance from station to each polygon's nearest vertex
    5. Return zones within radius, sorted by distance, with zone ID, name, distance
  - Put the discovery utility in a shared location: `providers/_common/nws_zones.py` — used by T1.4 (text forecasts), T1.5 (SRF), and T1.7 (marine alerts).
  - Cache: TTL 30 min. Key by zone ID.
  - Rate limit: 5 req/s to api.weather.gov (shared rate limiter with existing NWS alerts provider — use the same `RateLimiter` instance or a shared pool).
- Tests (`clearskies-test-author`):
  - Capture real zone forecast JSON as fixture.
  - Unit tests: parse forecast → verify period names and text content.
  - Unit tests: zone discovery → mock API responses, verify distance calculation and radius filtering.
  - Integration test: fetch forecast for AMZ250, verify non-empty periods.
- Accept: Zone forecast returns structured periods with wind/seas/weather text. Zone discovery correctly identifies nearest zones for a coastal point. Discovery returns zero zones for inland points (>50 miles from coast). Existing tests unchanged.

**T1.5 — NWS Surf Zone Forecast (SRF) text product**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nws_srf.py`
- Reference: PROVIDER-MANUAL §14.5 NWS Surf Zone Forecast, existing `providers/marine/nws_marine.py` (T1.4) for NWS API patterns
- Do:
  - Module structure: `PROVIDER_ID = "nws_srf"`, `DOMAIN = "marine"`, standard provider contract.
  - **SRF fetch:** `GET https://api.weather.gov/products/types/SRF/locations/{wfo}` to get latest SRF product for the WFO covering the spot. Parse the text product to extract per-county-zone forecasts for: rip current risk (low/moderate/high), surf height (breaking wave height range), UV index, water temperature, wind, and hazard statements. The SRF is a 2-day text forecast with one value per day per coastal county.
  - **Canonical model:** `SurfZoneForecast` already exists in `models/responses.py` (created in Phase 0C T0C.1). Fields: date, countyZone, ripCurrentRisk, surfHeightMin, surfHeightMax, uvIndex, waterTemp, windText, hazardsText. Do NOT modify the model — only import and populate it.
  - **WFO determination:** Reuse the NWS `/points` → CWA lookup from T1.4's shared zone discovery utility.
  - **County zone matching:** The SRF is issued per coastal county. Match the spot's coordinates to the appropriate county zone in the SRF text. Use the NWS `/zones/forecast` endpoint to determine the spot's public forecast zone.
  - Cache: TTL 60 min (SRF is issued 1–2 times/day). Key by WFO + county zone.
  - Rate limit: shared with existing NWS rate limiter (5 req/s to api.weather.gov).
  - **Scope:** Used by surf (T7.2) and beach safety (T7.4) pages per ADR-090 capability matrix.
- Tests (`clearskies-test-author`):
  - Capture real SRF text product as fixture.
  - Unit tests: parse SRF text → verify rip current risk, surf height, UV index extraction.
  - Integration test: fetch SRF for WFO ILM, verify non-empty forecast.
- Accept: SRF provider returns structured `SurfZoneForecast` with rip current risk and UV index. Text parsing handles WFO format variations. Existing tests unchanged.

**T1.6 — Wire into dispatch registry**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/services/dispatch.py` (or equivalent)
  - Any startup/registration module that loads provider modules
- Do: Register all five new provider modules (NDBC, CO-OPS, WaveWatch III, NWS marine, NWS SRF) in the dispatch registry so they're discovered at startup when configured. Follow the pattern used by existing providers (forecast, alerts, earthquakes). Each provider's `CAPABILITY` is imported and registered.
- Accept: API starts with `[marine]` config section → all five providers register and appear in capabilities endpoint. API starts without `[marine]` → no marine providers register, no errors.

**T1.7 — Marine zone alerts in existing alert system** — per ADR-089
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/nws_zones.py` (shared utility, created in T1.4)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py` (modify existing)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/aeris.py` (modify if needed)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/openweathermap.py` (modify if needed)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` (add `marine_alert_radius_miles` and `marine_alert_zone_ids` to `AlertsSettings`)
- Reference: ADR-089, PROVIDER-MANUAL §8 alerts + §14.8 shared zone discovery, OPERATIONS-MANUAL alerts config section (written in T0B.4)
- Do:
  - **Settings change:** Add `marine_alert_radius_miles: float = 0.0` and `marine_alert_zone_ids: list[str] = []` to `AlertsSettings` in `config/settings.py`. These are general alerts config, not marine-feature config. Loaded from `api.conf` `[alerts]` section. Also wire through `endpoints/alerts.py` (`wire_alerts_settings()` → module-level variable → pass to `nws.fetch()`).
  - **NWS alerts provider modification:** In `fetch()`, after the existing `?point=` query, check if `marine_alert_zone_ids` is non-empty. If so, make additional `GET /alerts/active?zone={zoneId}` queries for each configured marine zone. Merge results with point-based results. De-duplicate by alert `id` field. Use the same `ProviderHTTPClient`, rate limiter, and cache infrastructure. Cache key must distinguish zone-based queries from point-based queries.
  - **Xweather provider:** During implementation, test Xweather with a station at ~15km from coast (Wilmington NC: 34.23, -77.94 — verified in this session to miss SCAs). If Xweather returns marine alerts for this point: no change needed. If not (expected based on session testing): add a supplemental NWS `?zone=` query for the configured marine zones. This is a supplemental data source, not a provider switch — NWS marine zone alerts are free. Merge + de-duplicate by alert ID.
  - **OWM provider:** Same test-and-supplement approach. If no One Call 3.0 key available for testing, implement the NWS supplemental query unconditionally (it's free and adds no harm if OWM already returns the alerts).
- Tests (`clearskies-test-author`):
  - Unit tests: NWS provider with configured marine zones makes additional zone queries and merges/de-duplicates results.
  - Unit tests: NWS provider with no configured marine zones behaves identically to current implementation (regression test).
  - Unit tests: de-duplication — same alert from point and zone queries appears once in output.
  - Integration test: configure Wilmington NC station with AMZ250 marine zone, verify SCA appears when active.
- Accept: NWS alerts provider with configured marine zone IDs returns marine zone alerts that the point-based query misses. Provider with no marine zones behaves identically to before (zero regression). De-duplication works. Existing alerts test suite passes unchanged. API starts and serves all features without marine zone config (marine alert radius = 0 → no zone queries).

### QC Gate 1
- Coordinator runs: full pytest suite on weewx — baseline must hold + new provider tests pass.
- Coordinator runs: integration test against each live NOAA endpoint (NDBC station, CO-OPS station, ERDDAP, NWS marine zone, NWS SRF, NWS alerts with zone).
- Coordinator verifies: each provider module has CAPABILITY declaration, wire-shape Pydantic models, cache layer, rate limiter, error handling via ProviderHTTPClient, fetch() entrypoint — per PROVIDER-MANUAL §1–§7.
- Coordinator verifies: marine zone discovery returns correct zones for test points (Wilmington NC → AMZ250 at ~12.6 km, Wrightsville Beach → AMZ250 at ~0.1 km, Raleigh NC → 0 zones).
- Coordinator verifies: NWS alerts provider with configured marine zones returns marine alerts for Wilmington NC.

### QA Gate 1
- `clearskies-auditor`: reads each provider module against PROVIDER-MANUAL contract. Checks: CAPABILITY fields match manual spec, cache TTL matches manual, rate limiter present, error handling uses canonical taxonomy (no narrow wraps per L2 rule), wire models use `extras="ignore"`. Reports deviations.
- `clearskies-auditor`: verifies test coverage — each provider has fixture-based unit tests AND at least one live integration test. Reports any provider without integration test coverage.

---

## PHASE 2 — NWPS GRIB Provider — ✓ COMPLETE

Primary nearshore data source for US. Requires eccodes (native dependency per ADR-085). This phase produces the NWPS provider module that Phase 3's supplements operate on.

**QC Gate 2 passed (2026-07-10).** Pushed to GitHub (928af62), deployed to weewx (health 200). 56 targeted tests passed (0 failed). eccodes not installed on weewx (expected — marine feature not yet enabled); CAPABILITY correctly None when GRIB backend absent. pyproject.toml `[marine]` extra wired. WFO determination verified by code inspection: Wrightsville Beach → ILM, Huntington Beach → LOX, Galveston → HGX.

| Task | Commit | Lines | Status |
|------|--------|-------|--------|
| T2.1 GRIBProcessor port | 928af62 | 424 | Done |
| T2.2 NWPS provider module | 928af62 | 583 | Done |
| T2.3 eccodes dependency wiring | 928af62 | pyproject.toml + Dockerfile | Done |

### Tasks

**T2.1 — Port GRIBProcessor**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/grib_processor.py`
- Reference: PROVIDER-MANUAL §14.6 NWPS nearshore wave data, MARINE-DATA-AUDIT-BRIEF §B.5 for Phase II GRIBProcessor source, §B.6 for thread architecture
- Do:
  - Port Phase II `GRIBProcessor` class (~42 lines) with eccodes/pygrib dual backend. Try `import eccodes` first; if `ImportError`, try `import pygrib`; if both fail, set `GRIB_AVAILABLE = False`.
  - At module level, check `GRIB_AVAILABLE`. If False and marine config is present, raise `RuntimeError` with platform-specific install instructions: Debian/Ubuntu: `apt install libeccodes-dev && pip install eccodes`, RHEL: `dnf install eccodes-devel && pip install eccodes`, macOS: `brew install eccodes && pip install eccodes`, Docker: included by default.
  - **eccodes API pattern** (the agent must use these function calls):
    ```python
    # Open file and iterate GRIB messages:
    with open(file_path, 'rb') as f:
        while True:
            msgid = eccodes.codes_grib_new_from_file(f)
            if msgid is None:
                break
            try:
                short_name = eccodes.codes_get(msgid, 'shortName')
                if short_name in requested_fields:
                    values = eccodes.codes_get_values(msgid)  # 1D array
                    ni = eccodes.codes_get(msgid, 'Ni')       # grid columns
                    nj = eccodes.codes_get(msgid, 'Nj')       # grid rows
                    data_2d = values.reshape((nj, ni))
                    # Extract lat/lon bounds for geo-referencing:
                    lat_first = eccodes.codes_get(msgid, 'latitudeOfFirstGridPointInDegrees')
                    lon_first = eccodes.codes_get(msgid, 'longitudeOfFirstGridPointInDegrees')
                    lat_last = eccodes.codes_get(msgid, 'latitudeOfLastGridPointInDegrees')
                    lon_last = eccodes.codes_get(msgid, 'longitudeOfLastGridPointInDegrees')
            finally:
                eccodes.codes_release(msgid)
    ```
    A GRIB2 file contains multiple messages. Each message is one parameter at one forecast hour. Iterate all messages, match `shortName` against requested fields, extract the 2D grid.
  - **NWPS GRIB2 shortName mappings** (verify live against real files — these are the expected shortNames for NWPS CG grids):
    - `HTSGW` → significant wave height (m)
    - `PERPW` → peak wave period (s)
    - `DIRPW` → peak wave direction (degrees)
    - `UCUR` → surface current U-component (m/s, east-positive)
    - `VCUR` → surface current V-component (m/s, north-positive)
    - Current speed = √(UCUR² + VCUR²), direction = atan2(UCUR, VCUR) converted to oceanographic convention
    - `BODO` → bottom orbital velocity (m/s) — may appear as a different shortName; verify live
    - v1.5 fields (show-when-available): `RIPCUR`, `TWL`, `RUNUP` — may not exist in all files
  - Provide a `read_grib_fields(file_path, field_names) -> dict[str, ndarray]` function that opens a GRIB2 file and extracts named fields into numpy arrays. Handle missing fields gracefully (log WARNING, return None for that field). No numpy dependency — use Python lists; the grids are small (~100×100 for CG1).
  - **pygrib fallback pattern:** If eccodes unavailable but pygrib is:
    ```python
    grbs = pygrib.open(file_path)
    for grb in grbs:
        if grb.shortName in requested_fields:
            data_2d = grb.values  # numpy 2D array
            lats, lons = grb.latlons()
    ```
  - Fix: Phase II has duplicate `apply_breaking_limit` definitions (lines 4160 and 4581 per audit). Merge into single implementation — keep the enhanced version that accepts bottom-type-specific γ.
- Tests (`clearskies-test-author`):
  - Unit tests with a captured NWPS GRIB2 fixture file (small, single-timestep).
  - Unit tests: missing eccodes → clear error message with install instructions.
  - Unit tests: missing field in GRIB → None, not crash.
- Accept: `read_grib_fields()` extracts wave height, period, direction from a real GRIB2 file. Missing eccodes produces actionable error. Duplicate `apply_breaking_limit` resolved. Existing tests unchanged.

**T2.2 — NWPS provider module**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nwps.py`
- Reference: PROVIDER-MANUAL §14.6 NWPS nearshore wave data, MARINE-DATA-AUDIT-BRIEF §B.5 for grid selection, MARINE-SURF-FISHING-RESEARCH-BRIEF §5.2 for WFO domains and data fields
- Do:
  - Module structure: `PROVIDER_ID = "nwps"`, `DOMAIN = "marine"`, standard provider contract per PROVIDER-MANUAL §1. CAPABILITY depends on `GRIB_AVAILABLE` from grib_processor — if not available, CAPABILITY is None (provider not registered at startup). Config read from `MarineConfig` in `config/marine_config.py` (created in Phase 0C).
  - **GRIB2 fetch:** Download from NOMADS. **Live-verify the exact URL structure before implementing** — the documented pattern below is from NOAA NWPS docs but must be confirmed against the live NOMADS directory listing.
    - Base: `https://nomads.ncep.noaa.gov/pub/data/nccf/com/nwps/prod/`
    - Directory structure: `{region}.{YYYYMMDD}/{wfo}/CG{n}/` (e.g., `er.20260709/ilm/CG1/`)
    - Region prefix mapping (WFO → region):
      - `er` (Eastern Region): BOX, GYX, PHI, OKX, CAR, ALY, BUF, ILN, CLE, PBZ, RLX, AKQ, LWX, MHX, ILM, CHS, JAX, MLB, MFL, KEY, TBW
      - `sr` (Southern Region): MOB, LIX, HGX, CRP, BRO, LCH, SHV, JAN, BMX, FFC, TAE
      - `wr` (Western Region): SEW, PQR, MFR, EKA, MTR, LOX, SGX, HFO
      - `ar` (Alaska Region): AFC, AJK, AFG
      - `pr` (Pacific Region): GUM (Guam), HFO (Hawaii — may appear in both wr and pr; verify)
    - File naming within CG directory: verify live. Expected pattern: `{wfo}_nwps_CG{n}_{YYYYMMDD}_{cycle}.grib2` or individual field files. The agent MUST fetch the NOMADS directory listing first to discover actual file names.
    - Download CG1 (baseline) GRIB2 files for configured forecast hours. Use `ProviderHTTPClient` for downloads with retry/backoff.
    - **NOTE:** NOMADS serves plain files over HTTP, not a REST API. Use `ProviderHTTPClient.get()` and check `Content-Type` — GRIB2 files are binary (`application/octet-stream`). Save to a temp file, then pass to `grib_processor.read_grib_fields()`.
  - **WFO domain determination:** Use `get_cwa()` from `providers/_common/nws_zones.py` (created in T1.4) for land/coastal points. For offshore points where `/points` returns 404, fall back to a WFO bounding box lookup table. The bounding box table should be a module-level constant, not a runtime API call. Seed the table from MARINE-SURF-FISHING-RESEARCH-BRIEF §5.2 WFO domain list, but note the table only needs approximate bounds — the CG1 grid itself defines the exact coverage.
  - **CG grid selection:** CG1 is always available (~1.8 km resolution, covers the full WFO nearshore domain). CG2–CG5 are nested higher-resolution grids (~200–500m) for specific areas (harbors, inlets, high-traffic waterways). They are NOT always present — availability varies by WFO.
    - **Algorithm:** At fetch time, check the NOMADS directory for CG2–CG5 subdirectories. For each present CG grid, read the GRIB2 file header to determine the grid's lat/lon bounds (`latitudeOfFirstGridPointInDegrees`, etc. from eccodes). If the spot's coordinates fall within a nested grid's bounds, prefer that grid (higher resolution). If the spot falls outside all nested grids (or none exist), use CG1.
    - **Fallback chain:** CG5 → CG4 → CG3 → CG2 → CG1 (highest available resolution first).
    - **v1 simplification:** Start with CG1 only. CG2–CG5 support can be added as a follow-up if operators request it for specific harbor areas. This avoids the complexity of grid-within-grid resolution at the cost of slightly lower resolution in nested grid areas (1.8 km vs. 200m). Flag this as a simplification in the module docstring.
  - **Field extraction:** Use `grib_processor.read_grib_fields()` to extract: `HTSGW` (significant wave height), `PERPW` (peak period), `DIRPW` (peak direction), `UCUR`/`VCUR` (current components), `BODO` (bottom orbital velocity), `RIPCUR` (rip current probability — v1.5 WFOs only), `TWL` (total water level — v1.5), `RUNUP` (wave runup — v1.5). Missing v1.5 fields → None (show-when-available).
  - **Freshness metadata:** Include the NWPS cycle timestamp in the response. The provider does NOT implement a fallback pipeline — if NWPS data is temporarily unavailable, the provider returns an empty/stale result with the timestamp indicating age. Consumers decide how to handle.
  - Cache: TTL 30 min. Key by WFO + CG grid + nearest lat/lon.
- Tests (`clearskies-test-author`):
  - Capture real NWPS GRIB2 files as fixtures (one CG1 file from a known WFO like ILM or LOX).
  - Unit tests: WFO domain determination → verify coastal points map to correct WFOs.
  - Unit tests: GRIB2 parsing → verify field extraction against known values.
  - Unit tests: v1.5 field handling → verify rip current/TWL/runup are None when absent.
  - Integration test: fetch NWPS data for a real WFO, verify non-empty result.
- Accept: NWPS provider fetches and parses GRIB2 data from NOMADS. WFO determination works for all US coastal regions. CG grid selection prefers higher resolution. v1.5 fields show when available, None when not. Existing tests unchanged.

**T2.3 — eccodes dependency wiring**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/pyproject.toml` — add `[project.optional-dependencies] marine = ["eccodes>=1.5"]`
  - `repos/weewx-clearskies-stack/weewx-host/Dockerfile` (or equivalent API Dockerfile) — add `RUN apt-get install -y libeccodes-dev` or equivalent
  - `repos/weewx-clearskies-stack/single-host/Dockerfile` — same
- Do:
  - Add `[marine]` install extra to pyproject.toml.
  - Add eccodes system library to all API Dockerfiles (multi-stage: install in builder stage, copy lib to runtime stage).
  - Verify: `pip install .[marine]` on a clean venv installs eccodes. `pip install .` (without `[marine]`) does NOT install eccodes and API starts without marine.
  - Verify: Docker build with eccodes succeeds. `docker run` can `import eccodes`.
- Accept: `pip install weewx-clearskies-api[marine]` installs eccodes on Debian/Ubuntu. `pip install weewx-clearskies-api` (no extra) works without eccodes. Docker image has eccodes. API without `[marine]` config starts and serves all non-marine features.

### QC Gate 2
- Coordinator runs: full pytest suite — baseline holds + new GRIB/NWPS tests pass.
- Coordinator runs: `pip install .[marine]` in clean venv on weather-dev → verify eccodes importable.
- Coordinator runs: `pip install .` (no extra) → verify API starts, verify `import eccodes` raises ImportError, verify marine config enabled → clear error message.
- Coordinator verifies: NWPS provider fetches real GRIB2 data from NOMADS for ILM WFO.
- Coordinator verifies: WFO determination correct for Wrightsville Beach (ILM), Huntington Beach (LOX), Galveston (HGX).

### QA Gate 2
- `clearskies-auditor`: verifies GRIB processing handles corrupt files (truncated, wrong GRIB edition) without crashing. Verifies error messages include platform-specific install instructions. Verifies Dockerfile multi-stage build doesn't bloat runtime image with build tools.

---

## PHASE 3 — NOAA CUDEM Bathymetry + Surf Physics Enrichment — ✓ COMPLETE

Enrichment processors (not provider modules). Take NWPS data → apply site-specific supplements → produce surf quality forecasts. Bathymetry uses NOAA CUDEM via OpenTopoData REST endpoint (~10m resolution v1; THREDDS/OPeNDAP at ~3.4m deferred to future upgrade — see PROVIDER-MANUAL §14.7).

**QC Gate 3 passed (2026-07-10).** Pushed to GitHub (e70e5a3), deployed to weewx (health 200). 94 targeted tests passed (0 failed). Full suite: 3949 passed, 0 new failures (95 pre-existing OWM AQI failures unchanged). PROVIDER-MANUAL §14.7 updated for v1 OpenTopoData access method.

| Task | Commit | Lines | Status |
|------|--------|-------|--------|
| T3.1 CUDEM bathymetry processor | ce9ac4e | 714 | Done |
| T3.2 NWPS supplement processor | 2b28331 | 363 | Done |
| T3.3 Surf quality scorer | 5be33fc | 565 | Done |
| Test fix (shoaling assertion) | e70e5a3 | — | Done |

**Resolved issues:**
1. v1 data source: OpenTopoData CUDEM (1/3 arc-second, ~10m) chosen over THREDDS/OPeNDAP (complex integration). PROVIDER-MANUAL §14.7 updated.
2. Habitat features: all 5 types from manual implemented (dropoff, ledge, reef, channel, pinnacle).
3. i18n: surf_scorer uses `locale: str | None = None` per API-MANUAL §17, not brief's hardcoded `"en"`.
4. Time-of-day: dawn adjustment implemented; afternoon detection deferred (no UTC offset in function signature).

### Tasks

**T3.1 — Port BathymetryProcessor**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/bathymetry.py`
- Reference: API-MANUAL §17 marine enrichment section, PROVIDER-MANUAL §14.7 NOAA CUDEM bathymetry, MARINE-DATA-AUDIT-BRIEF §B.3 for Phase II source (1,370+ lines)
- Do:
  - Port Phase II `BathymetryProcessor` as a one-time setup operation (NOT a per-request enrichment). Called during wizard/admin spot configuration, result stored in `api.conf`.
  - **Deep-water point finding:** Starting from the surf spot coordinates, search outward along the beach-facing bearing in 1 km increments (up to 75 km) until a point with depth ≥ the region's deep-water threshold is found. Use NOAA CUDEM via NCEI THREDDS/OPeNDAP to query depth at each candidate point.
  - **Path creation:** Create a 16-point linear interpolation path between the break point and the deep-water point.
  - **NOAA CUDEM data access:** CUDEM 1/9 arc-second (~3.4m) tiles are available via multiple access methods. The agent MUST verify the actual working endpoint before implementing — NOAA endpoint availability changes. Access options in priority order:
    1. **NCEI THREDDS OPeNDAP** (preferred): `https://www.ngdc.noaa.gov/thredds/dodsC/regional/` hosts CUDEM tiles as OPeNDAP datasets. OPeNDAP subsetting syntax: append `?Band1[{lat_start}:{lat_step}:{lat_end}][{lon_start}:{lon_step}:{lon_end}]` to request a spatial subset. Response is a DAP2 binary or ASCII array. The agent needs to discover which tile covers the target coordinates — tiles are regional (e.g., `crm_vol1.nc` for the East Coast, specific tiles for each region). Check the THREDDS catalog at `https://www.ngdc.noaa.gov/thredds/catalog/regional/catalog.html` to find tile names.
    2. **NCEI point query** (simpler, slower): NCEI may offer a point-query REST API. Check `https://www.ngdc.noaa.gov/mgg/bathymetry/relief.html` for current API endpoints.
    3. **OpenTopoData with CUDEM dataset** (fallback): OpenTopoData hosts a CUDEM 1/3 arc-second dataset at `https://api.opentopodata.org/v1/cudem?locations={lat},{lon}`. Lower resolution (1/3 vs 1/9 arc-second, ~10m vs ~3.4m) but simpler REST API. Rate limit: 1 call/sec, max 100 locations/request, 1000 calls/day. This is the **fallback** if THREDDS is unavailable or too complex to implement in the time available.
    - The agent should attempt THREDDS first. If the endpoint structure is unclear or non-functional during implementation, fall back to OpenTopoData with CUDEM and document the limitation (lower resolution). Either way, the attribution is "NOAA National Centers for Environmental Information" and the data is CUDEM, just at different resolutions.
    - CUDEM covers all US coastal areas including territories (Hawaii, PR, USVI, Guam, CNMI, American Samoa). At 1/9 arc-second (~3.4m), individual reef structures, sandbars, ledges, and channel edges are visible. At 1/3 arc-second (~10m), large features are still visible but fine structure is smoothed.
    - Adaptive refinement (gradient-based, up to 3 iterations with IQR anomaly smoothing) may require 2–4 additional calls.
  - **Regional adaptations:** Pacific Coast: aggressive refinement (steep continental shelf). Gulf Coast: conservative (gradual shelf). Hawaii: maximum sensitivity (volcanic shelf). Great Lakes: adapt for freshwater lake bathymetry (shallower overall).
  - **Fallback profiles** when CUDEM/NCEI is unavailable: West Coast `[50,40,30,20,12,6,3]`, East Coast `[35,28,22,16,10,5,2.5]`, Gulf `[25,20,15,12,8,4,2]`, Hawaii `[60,45,30,18,10,5,3.5]`. Log WARNING when using fallback.
  - **Output:** List of `BathymetryPoint(distance_m, depth_m)` stored in `SurfSpotConfig.bathymetric_profile` (dataclass in `config/marine_config.py`, created in Phase 0C).
  - **Fix:** Replace `eval()` usage from Phase II with safe literal parsing. Use UnitTransformer for any unit conversions (Phase II had hardcoded US conversions).
  - **Attribution:** Every API response that includes bathymetry-derived data must include "NOAA National Centers for Environmental Information" in the attribution block + "Not for navigation" disclaimer.
- Tests (`clearskies-test-author`):
  - Unit tests: mock NCEI THREDDS/OPeNDAP responses → verify path creation, depth extraction, adaptive refinement.
  - Unit tests: fallback profiles → verify each region returns expected default profile when CUDEM unavailable.
  - Unit tests: verify no `eval()` anywhere in the module.
  - Integration test: download bathymetry for Wrightsville Beach (34.21, -77.79, facing 135°) → verify realistic depth profile (starts shallow, deepens to ~30–40m at ~20km offshore).
- Accept: Bathymetry download produces a 16+ point depth profile for a real coastal location. Fallback profiles work. No `eval()`. Rate limits respected. Attribution included. Existing tests unchanged.

**T3.2 — NWPS supplement processor**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py`
- Reference: API-MANUAL §17 marine enrichment section, ADR-084 (all four supplements with formulas and coefficients — archived at `docs/archive/decisions/ADR-084-*`), MARINE-DATA-AUDIT-BRIEF §B.4 for Phase II physics methods, §C.5 for structure coefficient tables
- Do: Implement the four ADR-084 supplements as a registered enrichment processor. Input: NWPS data for a spot + spot config (from `MarineConfig` in `config/marine_config.py`). Output: supplemented wave data.
  - **Supplement 1 — Breaker index correction:**
    - Compute beach slope `tan α` from the CUDEM bathymetric profile (linear regression over the nearshore portion, 0–500m from break).
    - Compute Iribarren number: `ξ = tan α / √(H₀/L₀)` where H₀ = NWPS significant wave height, L₀ = `g * T² / (2π)` (deep-water wavelength from NWPS peak period T).
    - Compute corrected γ: `γ = 1.06 + 0.14 * ln(ξ)`. Clamp to `[0.5, 1.4]`.
    - Compute maximum wave height at breaking: `H_max = γ * depth_at_break`. The `depth_at_break` comes from the bathymetric profile at the break point.
    - If `H_max < NWPS_Hs`: the NWPS wave height is already below the corrected breaking limit → no adjustment. If `NWPS_Hs > H_max`: cap wave height at `H_max`.
  - **Supplement 2 — Coastal structure effects:**
    - For each structure in the spot's `structures` list: compute distance from spot to structure. If within influence zone (jetty: 3–5× length, breakwater: 2–4× length, pier: 1–2× length, seawall: height×20, groin: 2–3× length): apply transmission coefficient `Kt` based on material permeability (impermeable: 0.10, semi-permeable: 0.35, permeable: 0.75). `H_transmitted = Kt * H_incident`. Effect diminishes as `1/r²` with distance beyond the near-field zone.
    - Multiple structures: use dominance formula from Phase II (material weight 0.4, distance weight 0.4, size weight 0.2). Linear superposition valid when structures separated by >5 wavelengths.
  - **Supplement 3 — Sub-grid interpolation:**
    - Bilinear interpolation of NWPS gridded output to exact spot coordinates using the four surrounding grid nodes. Input: NWPS grid (2D array of wave parameters at grid coordinates), spot lat/lon. Output: interpolated wave parameters at spot location.
  - **Supplement 4 — Topographic focusing/sheltering:**
    - Multiply wave height by the topographic factor from spot config: point_break=1.1, headland=1.2, bay_break=0.9, straight_beach=1.0.
  - **Processing order:** interpolation (3) → breaker correction (1) → structure effects (2) → topographic adjustment (4). Interpolation first because it operates on the raw grid; the others operate on the interpolated values.
  - **Registration:** Register as enrichment processor per existing pattern. Called by the surf endpoint after NWPS data is fetched.
  - **NO fallback pipeline.** Phase II shoaling/refraction/bottom friction code is NOT ported. If NWPS data is unavailable, supplements are not applied — the endpoint returns WaveWatch III offshore data as-is.
- Tests (`clearskies-test-author`):
  - Unit tests for each supplement individually:
    - Breaker correction: sand beach slope 0.02 with H₀=2m, T=10s → verify γ in expected range (~0.7–0.8).
    - Breaker correction: reef slope 0.1 with H₀=2m, T=10s → verify γ in expected range (~1.0–1.2).
    - Breaker correction: verify clamping at [0.5, 1.4] boundaries.
    - Structure effects: single jetty at 50m → verify height reduction. No structure → verify no change.
    - Sub-grid interpolation: four known grid nodes → verify interpolated value is bilinear combination.
    - Topographic: headland → verify ×1.2 multiplier applied.
  - Integration test: full pipeline with NWPS fixture data + real Wrightsville Beach config → verify all four supplements produce physically reasonable output.
- Accept: Battjes formula produces γ in [0.5, 1.4] for all test configurations. Structure effects reduce wave height (never increase). Sub-grid interpolation exact at grid nodes. Topographic multipliers applied correctly. Full pipeline produces output within 10% of NWPS raw values (supplements are corrections, not transformations). Existing tests unchanged.

**T3.3 — Surf quality scoring processor**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
- Reference: API-MANUAL §17 marine enrichment section, MARINE-SURF-FISHING-RESEARCH-BRIEF §7.3 for scoring algorithm, §7.4 for what to strengthen
- Do:
  - **Input:** Post-supplement NWPS wave data (from T3.2), wind data (from NDBC or WaveWatch III), tide state (from CO-OPS), spectral swell components (from NDBC), spot config (beach facing, directional exposure).
  - **Scoring weights:** wave_height 0.35, wave_period 0.35, wind_quality 0.20, swell_dominance 0.10.
  - **Wave height component:** Range lookup: 0–0.5ft=0.1, 0.5–1=0.3, 1–1.5=0.5, 1.5–3=0.8, 3–6=1.0, 6–10=0.8, 10–15=0.6, 15+=0.2. Input is post-supplement wave height (NOT raw deep-water).
  - **Wave period component:** Range lookup: 0–6s=0.2, 6–8=0.4, 8–10=0.6, 10–12=0.8, 12–16=1.0, 16–18=0.9, 18+=0.8. Apply period multipliers: 18+s×1.5, 12–14s×1.0, <8s×0.1.
  - **Wind quality component:** Direction relative to beach facing: offshore (wind from land → sea): light (<10mph)=1.2, moderate (10–20)=1.0, strong (>20)=0.7. Cross-shore: 0.8. Onshore: light=0.7, moderate=0.5, strong=0.3. Glassy (calm <5mph)=1.1.
  - **Swell dominance component:** From spectral data: compute energy ratio `swell_energy / total_energy` where swell = components with period > 10s. Pure swell (ratio > 0.8) = 1.0. Mixed (0.5–0.8) = 0.6. Wind chop dominant (< 0.5) = 0.2.
  - **Multi-swell integration:** If primary swell > 75% of total energy → use primary swell only for height/period scoring. If secondary swell > 50% of primary energy → apply energy superposition: `H_combined = √(H₁² + H₂²)` with energy-weighted period `T_combined = (E₁T₁ + E₂T₂) / (E₁ + E₂)`.
  - **Beach angle alignment:** Compute angle between incoming swell direction and beach-facing direction. ±15°=1.0 (direct hit), ±30°=0.8, ±45°=0.6, ±60°=0.3, >60°=0.1 (swell passing by).
  - **Directional exposure filter:** If spot config has directional exposure and the incoming swell direction is blocked (that compass direction = false), multiply score by 0.1.
  - **Time-of-day adjustment:** Dawn (±1hr of sunrise) = ×1.1. Afternoon (2–5pm) = ×0.9. Others = ×1.0.
  - **Final score:** `overall = Σ(component × weight) × beach_alignment × directional_filter × time_adjustment`. Stars = `max(1, min(5, round(overall × 5)))`. Quality labels: 1=Poor, 2=Fair, 3=Good, 4=Very Good, 5=Epic.
  - **Conditions text:** Use existing GFE marine vocabulary system to generate human-readable conditions text (e.g., "3-4 ft at 12 seconds from the SSW. Offshore winds 5-10 mph. Clean conditions with long-period swell.").
  - **Registration:** Register as enrichment processor.
- Tests (`clearskies-test-author`):
  - Unit tests: each scoring component individually with known inputs → verify component scores.
  - Unit tests: multi-swell integration — 2 swells at known heights/periods → verify combined height.
  - Unit tests: directional exposure filter — blocked direction → score ×0.1.
  - Unit tests: full scoring pipeline — "perfect day" (6ft, 14s, offshore light wind, clean swell, direct hit) → 5 stars. "Terrible day" (1ft, 6s, onshore strong, wind chop) → 1 star.
  - Unit tests: conditions text generation → verify GFE vocabulary produces readable English.
  - Integration test: score against real NWPS + NDBC data for a known spot.
- Accept: Scoring produces 1–5 star ratings. "Perfect conditions" consistently score 4–5. "Poor conditions" consistently score 1–2. Multi-swell integration produces physically reasonable combined heights. Conditions text is readable. Existing tests unchanged.

### QC Gate 3
- Coordinator runs: full pytest suite — baseline holds + all enrichment tests pass.
- Coordinator runs: integration test — full surf pipeline end-to-end: NWPS data → supplements → scoring → conditions text for Wrightsville Beach.
- Coordinator verifies: Battjes formula produces γ in [0.5, 1.4] for: sand slope 0.02 (expected ~0.7), rock slope 0.05 (expected ~0.9), reef slope 0.1 (expected ~1.1).
- Coordinator verifies: structure effects reduce wave height (never increase). Sub-grid interpolation exact at grid nodes.
- Coordinator verifies: GFE conditions text is readable English (not template artifacts or raw numbers).
- Coordinator verifies: no `eval()` anywhere in bathymetry or wave_transform modules.
- Coordinator verifies: bathymetry uses NOAA CUDEM via NCEI THREDDS (NOT GEBCO/OpenTopoData — that was the pre-ADR plan; ADR-084 selected CUDEM).

### QA Gate 3
- `clearskies-auditor`: reads API-MANUAL §17 supplements specification (authoritative) and ADR-084 (archived, for decision context). Verifies each supplement is implemented as specified (formula, coefficients, clamping, influence zone, processing order). Reports any deviation from the manual spec. Verifies the Phase II shoaling/refraction/bottom friction code was NOT ported (grep for `calculate_shoaling_coefficient`, `calculate_refraction_coefficient` — zero hits in new code).

---

## PHASE 4 — Fishing Enrichment (Solunar + Scoring) — ✓ COMPLETE

Parallel with Phases 1–3. Only depends on Phase 0C models. Can be dispatched as independent agent work alongside Phase 1 provider modules.

**QC Gate 4 passed (2026-07-10).** Pushed to GitHub (ae78867), deployed to weewx (health 200). 59 targeted tests passed (9 solunar + 50 fishing scorer, 0 failed).

| Task | Commit | Lines | Status |
|------|--------|-------|--------|
| T4.1 Solunar computation | 8b65bc6 | 242 | Done |
| T4.2 Fishing scorer + species data | ae78867 | 1210 (713+497) | Done |
| T4.3 Solunar almanac endpoint | d17e20f | 76 | Done |

**Resolved issues:**
1. moonPhase wire format: `_phase_name_from_angle()` returns hyphens ("waxing-crescent"); SolunarTimes model documents underscores ("waxing_crescent"). Resolved: solunar.py converts via `.replace("-", "_")` per wire contract.
2. Transit/underfoot window: station-local calendar-day window frequently misses underfoot event. Resolved: ±1-day widened search, pick closest to day center.
3. FishingForecast period_start/end: brief signature lacked period window inputs. Resolved: added `period_start_utc`/`period_end_utc` optional kwargs (default "").
4. Habitat features: FishingForecast is per-period, habitat features are per-spot/static. Resolved: standalone `get_habitat_features()` wrapper; model field deferred to Phase 5 endpoints.
5. Scoring weights: API-MANUAL §17 authoritative (0.30/0.25/0.20/0.15/0.10 five-component), not the plan's four-component (0.4/0.3/0.2/0.1).

### Tasks

**T4.1 — Solunar computation**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/solunar.py`
- Reference: API-MANUAL marine enrichment section (written in T0B.3), ADR-088 solunar specification, existing Skyfield usage in `enrichment/almanac.py` (sun/moon rise/set)
- Do:
  - Use Skyfield (already a project dependency) to compute moon positions for a given date and location:
    - **Moon transit:** time when moon crosses the observer's meridian (highest point). This is a "major period" anchor.
    - **Moon underfoot:** time when moon crosses the observer's anti-meridian (opposite side of earth). This is the second "major period" anchor.
    - **Moonrise/moonset:** standard Skyfield rise/set computation.
  - **Major periods:** 2-hour windows centered on transit and underfoot (1 hour before to 1 hour after). Extended to 3 hours during new moon and full moon (strongest gravitational influence).
  - **Minor periods:** 1-hour windows centered on moonrise and moonset. Extended to 2 hours during new/full moon.
  - **Moon phase intensity:** Compute illumination fraction via Skyfield. Map to intensity factor: new moon (0–5% illumination) = 1.0, full moon (95–100%) = 1.0, first/third quarter (45–55%) = 0.6, other phases interpolated linearly. This factor scales solunar period "strength" for fishing scoring.
  - **Output:** `SolunarTimes` canonical model (date, moon_phase, moon_illumination, moonrise, moonset, moon_transit, moon_underfoot, major_periods, minor_periods, intensity).
  - Compute for 3 consecutive days (today + 2 days forward) for the fishing forecast.
- Tests (`clearskies-test-author`):
  - Unit tests: compute solunar for a known date/location → verify transit, underfoot, rise, set times against published solunar tables (e.g., solunarforecast.com). Tolerance: ±5 minutes.
  - Unit tests: verify major period duration extends during new/full moon.
  - Unit tests: verify intensity is 1.0 at new moon and full moon, ~0.6 at quarter.
- Accept: Solunar times match published tables within ±5 minutes for 5 test dates at 3 different US locations (East Coast, West Coast, Gulf). Intensity mapping is monotonic (peaks at new/full, valleys at quarter). Existing tests unchanged.

**T4.2 — Fishing scoring processor**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/fishing_scorer.py`
- Reference: API-MANUAL §17 marine enrichment section, ADR-088 scoring model (archived at `docs/archive/decisions/ADR-088-*`), MARINE-SURF-FISHING-RESEARCH-BRIEF §8 for species data and scoring weights, §C.4 for topographic features
- Do:
  - **Base environmental scoring weights:** pressure_trend 0.4, tide_state 0.3, time_of_day 0.2, species_modifier 0.1.
  - **Pressure trend scoring:** Falling rapidly (>3 hPa/3hr) = 1.0 (feeding frenzy). Falling slowly (1–3) = 0.8. Stable (±1) = 0.5. Rising slowly = 0.3. Rising rapidly = 0.2. Source: NDBC buoy pressure or station barometer.
  - **Tide state scoring:** Moving tide (mid-incoming or mid-outgoing, 2–4 hours after turn) = 1.0. Slack high = 0.4. Slack low = 0.3. Peak flow = 0.7. Source: CO-OPS tide predictions.
  - **Time of day scoring:** Dawn (±1hr sunrise) = 1.0. Dusk (±1hr sunset) = 0.9. Night (2hr after sunset to 2hr before sunrise) = 0.6. Midday = 0.4. Source: Skyfield sunrise/sunset.
  - **Species behavioral profiles** (data table keyed by species name):
    - Pressure sensitivity: tuna=0.1 (no swim bladder), mahi-mahi=0.3 (small), flounder=0.5 (adapted), redfish=0.8 (large swim bladder), striped bass=0.8, walleye=0.7. Applied as multiplier to pressure score.
    - Water temperature preferences: per species, define optimal/good/poor/inactive temperature ranges in °F. E.g., redfish: optimal 70–85, good 60–70 or 85–90, poor 55–60 or 90–95, inactive <55 or >95. Temperature multiplier: optimal=1.0, good=0.7, poor=0.3, inactive=0.0.
    - Tide preference: some species prefer incoming (redfish=incoming×1.2), some outgoing (flounder=outgoing×1.3), some don't care (tuna=1.0).
    - Time-of-day multiplier: some species are dawn specialists (striped bass=dawn×1.5), some nocturnal (snook=night×1.3).
  - **Seasonal behavior** (data table keyed by species + month):
    - Spawning multipliers: redfish Oct=2.5×, striped bass May=3.0×, flounder Nov=2.0×.
    - Pre-spawn feeding: 2–4 weeks before spawn month = 1.5×.
    - Closed seasons: snook Jun–Aug = 0.0× (regulatory closure, don't recommend).
    - Migration patterns: king mackerel southward Oct–Nov, northward Apr–May = 1.5× in transit zones.
  - **Dynamic scoring per period:** `base_env_score × water_temp_multiplier × seasonal_multiplier × solunar_intensity` → classify species as `active` (≥0.6), `less_active` (0.3–0.6), `inactive` (<0.3).
  - **Biogeographic species lists:** Auto-classify station coordinates into one of 11 US regions by lat/lon bounding boxes. The agent defines approximate bounding boxes from the state/geographic ranges — exact boundaries aren't critical since operators can add/remove species manually. Regions:
    - `atlantic_ne` (Maine–Connecticut, ~40–47°N, coastline)
    - `atlantic_se` (New York–Florida east coast, ~25–41°N, Atlantic side)
    - `gulf` (Florida Panhandle–Texas, ~25–31°N, Gulf side)
    - `pacific_sw` (SoCal, ~32–34°N, Pacific side)
    - `pacific_central` (Central CA, ~34–38°N)
    - `pacific_nw` (NorCal–Washington, ~38–49°N)
    - `alaska` (>55°N, or AK bounding box)
    - `hawaii` (~18–23°N, ~154–161°W)
    - `great_lakes` (interior US, near Great Lakes coordinates)
    - `caribbean` (PR, USVI, ~17–19°N)
    - `pacific_territories` (Guam, CNMI, American Samoa)
    Each region has a default species list by category (saltwater inshore, bottom fish, freshwater sport, salmonids — `saltwater_offshore` removed per ADR-088). The species lists are data tables keyed by region → category → species names. Seed from the research brief §8 species data; the agent should populate 5–10 species per category per region as a starting default. Operators customize via the wizard.
  - **CUDEM habitat features:** From the NOAA CUDEM bathymetric profile (stored in config by T3.1), identify drop-offs (depth change >5m in <200m horizontal), reefs (consistent depth plateau surrounded by deeper water), ledges (sharp depth discontinuity). Report as `habitat_features` in the fishing forecast — informational, not scored.
  - **Score scale:** The internal scorer computes 0.0–1.0, then multiplies by 100 for the API response (0–100 integer). This matches the convention fishermen expect from fishing forecast apps (0–100 "fishiness" scale). Classification thresholds on the 0–100 scale: `active` (≥60), `less_active` (30–59), `inactive` (<30).
  - **Wind and swell as scoring factors — DEFERRED pending research.** Practitioner evidence suggests wind speed/direction affects catch rates (a 40,000+ catch database showed doubled rates for >15 mph winds; south/southwest winds correlate with +10–12% improvement). However, the strongest wind effects are tightly correlated with falling barometric pressure from low-pressure systems — which is already the heaviest scorer weight (0.4). Adding wind as a separate factor risks double-counting the same weather event. Swell effects on surf fishing are documented anecdotally but lack peer-reviewed evidence. **Before implementation:** research whether wind can be separated from the pressure signal (e.g., does wind speed improve prediction accuracy when pressure trend is already accounted for?). If yes, add wind as a fifth scoring factor and rebalance weights. Until then, wind and swell data are displayed as informational on the fishing page (providers already supply them) but do not feed the scoring algorithm.
  - **Output:** 3-day forecast, 5–6 periods per day (dawn, morning, midday, afternoon, dusk, night). Each period: overall_score (0–100), component scores (0–100 each), species classifications (active/less_active/inactive with scores), conditions text.
  - Register as enrichment processor.
- Tests (`clearskies-test-author`):
  - Unit tests: pressure scoring — verify each trend category produces expected score.
  - Unit tests: tide state scoring — verify mid-tide scores highest, slack lowest.
  - Unit tests: species profiles — verify temperature multiplier transitions at range boundaries.
  - Unit tests: seasonal behavior — verify redfish Oct gets 2.5× multiplier, snook Jun gets 0.0×.
  - Unit tests: biogeographic classification — verify coordinates in each region classify correctly (at least one test point per region).
  - Unit tests: score scale — verify 0.0–1.0 internal → 0–100 API output.
  - Integration test: full scoring for Wrightsville Beach with real pressure/tide/temperature data → verify reasonable scores.
- Accept: Scoring produces 0–100 range scores. Active/less_active/inactive classifications are consistent with scores (≥60/30–59/<30). Closed seasons produce 0. Biogeographic classification correct for all 11 regions. Existing tests unchanged.

**T4.3 — Solunar almanac endpoint**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/routes/almanac.py` (modify existing)
- Reference: API-MANUAL §18 marine endpoint section, existing `/api/v1/almanac/sun` and `/api/v1/almanac/moon` endpoint patterns
- Do: Add `GET /api/v1/almanac/solunar` to the existing almanac router. Request params: `date` (optional, defaults to today), `days` (optional, defaults to 3). Response: list of `SolunarTimes` for the requested date range. No capability gating — solunar is available to all stations (it's pure math from Skyfield, no provider dependency). Include freshness block (computed, not fetched).
- Accept: Endpoint returns solunar data for the station's location. Response matches `SolunarTimes` schema. Existing almanac endpoints unaffected.

### QC Gate 4
- Coordinator runs: full pytest suite — baseline holds + solunar + fishing scorer tests pass.
- Coordinator verifies: solunar times for 2026-07-09 at Wrightsville Beach (34.21, -77.79) match published solunar tables within ±5 minutes.
- Coordinator verifies: fishing scoring produces reasonable results — falling pressure + incoming tide + dawn = high score (70+); stable pressure + slack tide + midday = low score (<40).
- Coordinator verifies: closed season species (snook Jun–Aug) score exactly 0.
- Coordinator verifies: solunar almanac endpoint returns valid JSON matching SolunarTimes schema.

### QA Gate 4
- `clearskies-auditor`: verifies species data tables are complete — every species in every biogeographic region has pressure sensitivity, temperature ranges, tide preference, and time-of-day multiplier defined. Reports any species with missing data fields. Verifies scoring weights sum to 1.0 (0.4 + 0.3 + 0.2 + 0.1). Verifies solunar intensity is symmetric around new/full moon. Verifies score output is 0–100 integer scale (not 0.0–1.0 float). Verifies wind/swell fields are present in FishingForecast output but NOT used as scoring inputs.

---

## PHASE 5 — API Endpoints — ✓ COMPLETE

Wire provider data + enrichment output to REST endpoints. All follow existing endpoint patterns: check capability → fetch from provider → normalize → apply unit conversion → attach freshness/stationClock. Reference implementation: `routes/earthquakes.py`.

**QC Gate 5 passed (2026-07-10).** Pushed to GitHub (bc49a6d), deployed to weewx (health 200). 131 targeted tests passed (0 failed): 9 solunar + 50 fishing scorer + 21 marine endpoint + 23 tides endpoint + 12 surf endpoint + 17 fishing endpoint + 22 beach-safety endpoint (includes Phase 4 regression).

| Task | Commit | Lines | Status |
|------|--------|-------|--------|
| T5.1 Marine endpoint | 77cd429 | 382 | Done |
| T5.2 Tides endpoint | 77cd429 | 254 | Done |
| T5.3 Surf endpoint | 0659754 | ~700 | Done |
| T5.4 Fishing endpoint | 0659754 | ~700 | Done |
| T5.5 Beach safety endpoint | 0659754 | ~700 | Done |
| T5.6 Router wiring + freshness | bc49a6d | 33 | Done |
| T5.7 Pages entries | bc49a6d | (in T5.6 commit) | Done |

**Resolved issues:**
1. GET /marine (no locationId): API-MANUAL §18 said "first configured location"; implemented as location list per dashboard design requirements (T7.1 card grid). Doc-code sync pending.
2. CO-OPS function names: brief named `fetch_predictions()`/`fetch_water_levels()` but actual API is `coops.fetch(station_id, products=(...))` returning a dict. Used actual API.
3. MarineBundle has no tide fields — CO-OPS traffic handled exclusively by tides.py, not duplicated in marine.py.
4. Marine unit groups not in `get_units_block()`'s `_GROUP_MEMBERS` — endpoints use `get_target_unit()` + local preset table per API-MANUAL §16. Operator overrides for marine groups deferred.
5. No *BundleResponse Pydantic envelope classes — endpoints return plain dicts with standard envelope, matching get_solunar() pattern.

### Tasks

**T5.1 — `GET /api/v1/marine[/{locationId}]`**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/routes/marine.py`
- Reference: API-MANUAL §18 marine endpoint section, existing `routes/earthquakes.py` pattern
- Do:
  - **No locationId:** Return `MarineLocationSummary` for all configured marine locations (list of location cards with current conditions snapshot). Capabilities-gated: returns 404 if marine not configured.
  - **With locationId:** Return `MarineBundle` for the specified location: NDBC buoy observation (latest), WaveWatch III forecast (72h), NWPS nearshore data (with supplements applied if surf activity enabled), NWS marine text forecast, activity-relevant alerts (filtered from general alert feed per ADR-090 — marine zone alerts for marine/boating), CO-OPS tide chart data, water temperature. Each sub-section is optional based on which activities are enabled for this location (ADR-090 capability matrix).
  - Apply unit conversion via UnitTransformer for all numeric fields with unit groups.
  - Attach freshness block with per-source timestamps (NDBC last update, WaveWatch III model run time, NWPS cycle time, CO-OPS last observation).
  - Attach stationClock.
- Accept: Returns valid JSON matching `MarineBundle` schema. Unit conversion works (request `?units=us` returns feet, knots; `?units=metric` returns meters, m/s). Freshness block present with realistic timestamps. 404 when marine not configured. Existing endpoint tests unchanged.

**T5.2 — `GET /api/v1/tides[/{locationId}]`**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/routes/tides.py`
- Do: Return `TideBundle`: tide predictions (72h, high/low markers), observed water levels (24h), water temperature. CO-OPS data. Unit conversion for heights. Freshness block with CO-OPS timestamps.
- Accept: Returns tide predictions with high/low classifications. Water levels with quality flags. 404 when tides not configured for location.

**T5.3 — `GET /api/v1/surf[/{locationId}]`**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/routes/surf.py`
- Do: Return `SurfBundle`: surf quality forecasts (72h with star ratings), post-supplement wave data, spectral swell breakdown, wind quality, tide overlay, conditions text. Requires surf activity enabled for this location. Pipeline: NWPS → supplements (T3.2) → scoring (T3.3) → response.
- Accept: Returns star ratings (1–5) and conditions text for each forecast step. Spectral breakdown shows individual swell components. 404 when surf not configured.

**T5.4 — `GET /api/v1/fishing[/{locationId}]`**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/routes/fishing.py`
- Do: Return `FishingBundle`: 3-day forecast with 5–6 periods per day, solunar times, species activity classifications, habitat features, conditions text. Requires fishing activity enabled. Pipeline: solunar (T4.1) + environmental scoring (T4.2) → response.
- Accept: Returns period scores, species classifications, solunar times. Closed-season species show inactive. 404 when fishing not configured.

**T5.5 — `GET /api/v1/beach-safety[/{locationId}]`**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/routes/beach_safety.py`
- Do: Return `BeachSafetyBundle`: sea state assessment (wave height + period → safety level), rip current risk (from NWS SRF, T1.5), NWPS v1.5 rip current probability (show-when-available), water temperature with comfort classification, UV index (from SRF), tide predictions, observed water levels, wind speed/direction, atmospheric visibility, wave runup + total water level (NWPS v1.5, show-when-available), activity-relevant alerts (Beach Hazards, High Surf, Rip Current, Coastal Flood — filtered per ADR-090). Requires beach_safety activity enabled for this location.
  - **Sea state safety classification:** Compute from nearshore wave height + period. Green (safe): height <2ft AND period >8s. Yellow (caution): height 2–3ft OR period 6–8s. Red (dangerous): height >3ft OR period <6s. Include in response as `safety_level` enum (safe/caution/dangerous).
  - **Water temperature comfort:** <55°F = dangerous (hypothermia risk), 55–65°F = cold (wetsuit recommended), 65–75°F = cool (wetsuit optional), >75°F = comfortable. Include as `comfort_level` enum.
- Accept: Returns safety level, rip current risk, water temp with comfort classification, UV index, relevant alerts. 404 when beach_safety not configured.

**T5.6 — Wire routers, freshness defaults, cache strategy**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/routes/__init__.py` or router registration module
  - `repos/weewx-clearskies-api/weewx_clearskies_api/services/cache_warmer.py` (modify existing)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_weather_cache.py` (new — on-demand cache for marine location weather)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_location_resolver.py` (new — config-time spatial dedup + station substitution)
- Do:
  - **Sub-task A — Router registration:** Register all five new routers (marine, tides, surf, fishing, beach-safety) in the API's router registration. Follow the existing pattern in `__main__.py` where forecast/alerts/earthquakes routers are registered. Marine routers are conditional — only registered when `MarineConfig` is non-None (marine section present in `api.conf`).
  - **Sub-task B — Marine-specific data (proactive cache warmer):** Add marine provider data to the cache warmer's warm-on-startup list. Read the existing `cache_warmer.py` to understand the warm pattern (it pre-fetches provider data at startup and on a timer). Add entries for each configured marine location:
    - NDBC standard met: every 60 min per station
    - NDBC spectral: every 60 min per station (same call as standard met — one station, two file types)
    - CO-OPS predictions: every 6 hr per station
    - CO-OPS water level: every 10 min per station
    - WaveWatch III: every 30 min per grid point
    - NWS marine text: every 30 min per zone
    - NWS SRF: every 60 min per WFO
    - NWPS: every 30 min per WFO
    Use the spatial dedup groups (Sub-task D) to avoid duplicate calls for nearby locations that share the same NDBC station or grid point.
  - **Sub-task C — General weather on-demand cache:** New `marine_weather_cache.py` module. This is NOT part of the proactive cache warmer — it fetches on first request and caches with TTL.
    - **Architecture:** A simple dict-based cache keyed by rounded grid-point coordinates (same rounding as Sub-task D). Each entry stores `{forecast_data, observation_data, forecast_fetched_at, observation_fetched_at}`.
    - **Fetch logic:** When a marine endpoint needs general weather for a location: (1) compute the rounded grid point, (2) check cache for that grid point, (3) if expired or absent, call the configured forecast provider's `fetch()` with the grid-point coordinates, (4) store result with timestamp, (5) return data.
    - **TTLs:** Configurable via `MarineWeatherConfig` from `config/marine_config.py` (created in Phase 0C). Defaults: `forecast_ttl_hours=3` (3 hr), `observation_ttl_minutes=30` (30 min).
    - **Provider call:** Use the same forecast provider module that the main site uses (from `settings.forecast.provider`). Call its `fetch()` with the marine location's coordinates. This is the ONLY new provider call — everything else reuses existing infrastructure.
    - **Thread safety:** The cache is read/written from sync FastAPI handlers. Use a simple `threading.Lock` around the dict (same model as the existing memory cache).
  - **Sub-task D — Spatial deduplication (config-time):** New `marine_location_resolver.py` module. Called once at startup (during config load), not per-request.
    - **Algorithm:** Round each marine location's coordinates to the nearest 0.025° (~2.5 km). Locations with the same rounded coordinates share a single "grid group." Store the mapping: `{location_id → grid_group_key}`.
    - **Effect:** When the cache warmer or on-demand cache fetches data for a grid group, all locations in that group get the same data. The cache key uses the rounded coordinates, not the exact location coordinates.
    - **Config source:** `dedup_radius_km` from `MarineWeatherConfig` in `config/marine_config.py`. Default 2.5 km. Convert to degrees: `radius_deg = dedup_radius_km / 111.0` (approximate). Round to nearest `radius_deg`.
  - **Sub-task E — Station substitution (config-time):** Also in `marine_location_resolver.py`.
    - At config load, compute haversine distance from the station coordinates (from `StationSettings` in `config/settings.py`) to each marine location.
    - If distance ≤ `dedup_radius_km` (default 2.5 km): flag location as `station_served = True`. The marine endpoints for this location will use the station's own `/api/v1/current` data for observations and the station's cached forecast for forecast data — zero additional forecast provider API calls.
    - If distance > `dedup_radius_km`: flag as `station_served = False`. The on-demand cache (Sub-task C) handles weather data for this location.
    - Store the `station_served` flag per location. The marine endpoint routers check this flag to decide data source.
  - **Sub-task F — Freshness defaults:** Add marine freshness domains to `config/settings.py` `FreshnessSettings`. Follow the existing pattern for forecast/alerts/aqi. New domains:
    - `marine`: 1800s (30 min)
    - `tides`: 600s (10 min for observations, 21600s for predictions — use the shorter)
    - `buoy`: 3600s (60 min)
    - `surf`: 1800s (30 min)
    - `fishing`: 3600s (60 min)
    - `beach_safety`: 1800s (30 min)
- Accept: API starts with marine config → all five endpoints respond. Cache warmer pre-fetches marine-specific data on startup. General weather data is fetched on-demand with correct TTLs. Two marine locations within 2.5 km share forecast/observation calls (verified by cache key inspection). Marine location within 2.5 km of station uses station data with zero forecast provider calls. Marine location beyond 2.5 km uses forecast provider on-demand. Freshness block shows realistic data ages for both marine and general weather sources.

**T5.7 — Update capabilities + pages endpoints**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-api/weewx_clearskies_api/routes/capabilities.py` (modify)
  - `repos/weewx-clearskies-api/weewx_clearskies_api/routes/pages.py` (modify)
- Do: Add marine/tides/surf/fishing/beach-safety to the capabilities response when configured. Add marine/surf/fishing/beach-safety page entries to the pages endpoint (these control dashboard navigation visibility). Pages follow existing `pages.json` visibility pattern.
- Accept: `/api/v1/capabilities` includes marine domains when configured, excludes when not. `/api/v1/pages` includes marine pages when configured. OpenAPI spec (`/api/v1/openapi.json`) shows all five new endpoints.

### QC Gate 5
- Coordinator runs: full pytest suite — baseline holds + endpoint tests pass.
- Coordinator runs: `curl` each endpoint against the live API (after deploy) and verifies valid JSON responses with correct structure.
- Coordinator verifies: unit conversion works (`?units=us` vs `?units=metric`) for wave height, water level, ocean speed.
- Coordinator verifies: freshness block present on all responses with per-source timestamps.
- Coordinator verifies: capabilities endpoint shows marine when configured, doesn't show when not configured.
- Coordinator verifies: OpenAPI spec at `/api/v1/openapi.json` includes all five new endpoints with correct request/response schemas.
- Coordinator verifies: beach safety endpoint returns safety_level enum and comfort_level enum with correct thresholds.

### QA Gate 5
- `clearskies-auditor`: verifies each endpoint follows the pattern established by `routes/earthquakes.py` — capability check, provider fetch, unit conversion, freshness attachment. Reports any endpoint that skips a step. Verifies error responses match canonical error format (404 for unconfigured, 503 for provider failure).

---

## PHASE 6 — Location Config (Wizard/Admin) — ✓ COMPLETE

Marine location configuration in the wizard and admin UI. The marine alert radius (ADR-089) is NOT here — it's in the general alerts configuration (already specified in T1.7). This phase covers only the marine feature location setup.

**QC Gate 6 passed (2026-07-10).** Pushed to GitHub (API: 337f71e, stack: e8ad003), deployed to weewx (health 200) and weather-dev (config UI restarted, dashboard built). 15-step wizard with marine step 13, marine admin section with CRUD + connectivity test + bathymetry re-run, marine alert radius in alerts config, 138 new i18n keys across 13 locales, 3 setup API endpoints, shape-mismatch fix between wizard and API apply schemas.

| Task | Commit(s) | Lines | Status |
|------|-----------|-------|--------|
| T6.1 Marine wizard step | 7653bd4, f4c3524, ddc9366, d63cca7, db8d0dd | ~2210 (stack) | Done |
| T6.2 Marine admin section | 08a487a, 39909f7 | ~1669 (stack) | Done |
| T6.3 Setup API endpoints | f29eb63, 337f71e | ~571 (API) | Done |
| T6.4 Marine alert radius | ddc9366 (in T6.1 batch) | ~22 (template) | Done |
| Shape-mismatch fix | e8ad003 | ~47 (stack) | Done |

**Resolved issues:**
1. Agent role mismatch: plan assigned `clearskies-docs-author` to wizard/admin work; re-dispatched with `clearskies-api-dev` (config UI is Python FastAPI + Jinja2).
2. `bathymetric_profile` wire format: brief showed flat CSV, but `marine_config.py` loader parses nested configobj subsections — used loader-authoritative format.
3. `[[weather]]` section: not parsed by `MarineConfig` loader, omitted from config writer (defaults used).
4. `CurrentConfigResponse` missing `marine` field: admin UI couldn't read marine config — added `marine` dict to the response.
5. Wizard → API shape mismatch: `build_marine_payload()` sent dict (keyed by location id) but API expects list (with id field); `directional_exposure` sent as list but API expects dict[str, bool]; `weather` key rejected by API's `extra="forbid"`. Fixed in e8ad003.

### Tasks

**T6.1 — Marine wizard step**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: New templates in `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/marine/`
- Reference: OPERATIONS-MANUAL marine location setup procedure (written in T0B.4), existing wizard step patterns in `templates/wizard/`, DASHBOARD-MANUAL marine pages section (written in T0B.5)
- Do:
  - **Location configuration** (repeatable per location): name (text input), coordinates (map picker — use existing Leaflet map component from radar setup), activities (checkboxes: marine/boating, surf, fishing, beach safety — per ADR-090 capability matrix).
  - **Per surf spot** (shown when surf activity checked): beach facing (compass selector or degree input), bottom type (dropdown: sand/rock/coral_reef/mixed), structures (repeatable: type/material/length/bearing/distance), topographic feature (dropdown: point_break/bay_break/headland/straight_beach with identification hints per MARINE-DATA-AUDIT-BRIEF §C.4), directional exposure (8 compass direction checkboxes — which directions can swell reach this spot from?).
  - **Per fishing spot** (shown when fishing activity checked): target category (dropdown: saltwater_inshore/bottom_fish/freshwater_sport/salmonids — `saltwater_offshore` removed per ADR-088), species list (auto-populated from biogeographic region classification, operator can add/remove).
  - **Per beach safety location** (shown when beach safety activity checked): optional external links for local water quality monitoring, lifeguard reports, or wildlife alert services (repeatable: label + URL). These are informational links displayed on the beach safety page — water quality and wildlife alert APIs are not available in v1, so operators provide their own local resource links. No other beach-safety-specific config needed — the page derives its data from the same NWPS/NDBC/CO-OPS/NWS providers configured for the location.
  - **Station auto-discovery:** On save, call `/setup/marine/discover-stations` (T6.3) → display nearby NDBC buoys and CO-OPS stations with distances and capabilities. Distance-based quality scoring: wave buoys 0–25 mi=excellent, 25–50=good, >50=fair; tide stations 0–20 mi=excellent, 20–40=good. Differentiate NDBC capabilities (wave-only vs. atmospheric-only vs. full — per MARINE-DATA-AUDIT-BRIEF §C.3). Operator selects or accepts auto-selected stations.
  - **Multi-location station optimization:** When multiple locations are configured, identify NDBC/CO-OPS stations that serve multiple spots. Recommend shared stations first to reduce API calls.
  - **Bathymetry trigger** (surf spots only): On surf spot save, trigger async NOAA CUDEM bathymetry download via `/setup/marine/bathymetry` (T6.3). Show progress indicator. Bathymetry result stored in `api.conf` `SurfSpotConfig.bathymetric_profile`.
  - **Land/sea validation** (surf spots only): Query CUDEM depth for the spot coordinates. If depth is positive (on land), show warning — surf spots should be at or near the waterline.
  - **Weather source display per location (automatic, not configurable):** For each location, show the computed distance from the operator's weewx station and which weather source will be used. Within 2.5 km: "Your station is {X} km from this location — station weather data will be used (no additional API calls)." Beyond 2.5 km: "Your station is {X} km from this location — weather data will be fetched from your forecast provider ({provider name})." No operator choice needed — the 2.5 km threshold handles it automatically.
  - **Refresh intervals** (global, not per-location): forecast TTL dropdown (1 hr / 3 hr / 6 hr, default 3 hr), observation TTL dropdown (15 min / 30 min / 60 min, default 30 min). Show estimated API call impact: "{N} additional forecast provider calls per hour based on {M} distinct grid points." NWS operators see a note that NWS API is free with a 5 req/s rate limit.
  - HTMX progressive disclosure: activity checkboxes show/hide the per-activity config sections.
  - Note: NWS marine zone discovery for alerts is NOT in this step — it's in the general alerts configuration (ADR-089, T1.7).
- Accept: Wizard step renders all config fields. Activity checkboxes show/hide appropriate sections. Station weather substitution defaults correctly based on distance. Refresh interval controls show API call estimate. Station discovery returns results for US coastal coordinates. Bathymetry downloads async with progress. Config round-trips through `/setup/apply` → `api.conf` → reload.

**T6.2 — Marine admin section**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: New templates in `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine/`
- Reference: OPERATIONS-MANUAL marine config section (written in T0B.4), existing admin section patterns in `templates/admin/` (read `providers.html` and `earthquakes.html` for the established pattern), DASHBOARD-MANUAL help content sync rule
- Do:
  - **Admin route:** `GET /admin/config/api/marine` → renders the marine admin section. Follow the existing `admin/config/{component}/{section}` pattern in `config/routes.py`.
  - **Location list view:** Table of configured marine locations with columns: name, coordinates, enabled activities (badges), station count (NDBC + CO-OPS), data freshness (color-coded: green = <1 TTL old, yellow = 1–2× TTL, red = >2× TTL or unavailable). Each row has Edit and Delete buttons.
  - **Location edit form (HTMX partial):** Reuse the same fields as T6.1 wizard step (location name, coordinates, activity checkboxes, per-activity config sections with HTMX progressive disclosure). The admin form POST updates `api.conf` via `/setup/apply` (same as wizard). Validation errors display inline per field.
  - **Add location:** Button opens a blank location form (same as edit but empty).
  - **Delete location:** Confirmation dialog ("Remove {name}? This will delete all associated configuration including bathymetric profiles."). POST to a delete handler that removes the location from `api.conf`.
  - **Re-run bathymetry** (per surf spot): Button triggers `POST /setup/marine/bathymetry` (T6.3) for the selected spot. Shows progress indicator (HTMX polling). On completion, displays the updated profile summary (point count, max depth, computed beach slope).
  - **Test connectivity:** Button tests each configured data source for a location:
    - NDBC: fetch latest `.txt` from configured station → green (data <2 hr old) / yellow (data present but old) / red (404 or error)
    - CO-OPS: fetch predictions for configured station → green/red
    - NWS marine: fetch zone forecast for configured zone → green/red
    - NWPS: check NOMADS for latest CG1 file for WFO → green/red
    Results displayed inline via HTMX replacement.
  - **Refresh interval controls** (global, not per-location): same as wizard — forecast TTL dropdown, observation TTL dropdown, with API call estimate.
  - **Weather source display:** Per location, show computed distance from station and whether it uses station data (< 2.5 km) or forecast provider.
  - **Help content keys:** `help.admin.marine.overview`, `help.admin.marine.location`, `help.admin.marine.bathymetry`, `help.admin.marine.connectivity`, `help.admin.marine.refresh`. All wrapped in `_()` for i18n. Add keys to all 13 locale translation files (English content, placeholder translations acceptable for v1).
- Accept: Admin section loads configured locations. Add/edit/delete round-trips through `api.conf`. Connectivity test shows green/red per source. Bathymetry re-run completes and updates profile. Help content renders in all 13 locales. Existing admin sections unaffected.

**T6.3 — Setup API endpoints**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/routes/setup.py` (modify existing)
- Do:
  - **`/setup/apply` extension:** Handle `[marine]` config section in the apply payload. Write marine locations, surf spots, fishing spots to `api.conf`. Trigger NWPS WFO domain determination for each location. Validate station IDs (NDBC/CO-OPS exist and respond). Return validation errors for invalid config.
  - **`POST /setup/marine/bathymetry`:** Async endpoint. Accepts location_id + surf spot config (coordinates, beach facing). Calls `enrichment/bathymetry.py` to download NOAA CUDEM profile via NCEI THREDDS. Returns job ID. Poll via `GET /setup/marine/bathymetry/{jobId}` for status + result.
  - **`GET /setup/marine/discover-stations`:** Accepts lat/lon + radius. Queries NDBC `activestations.xml` and CO-OPS metadata API. Returns list of nearby stations with IDs, names, distances, capabilities, quality scores.
- Accept: `/setup/apply` with marine config creates valid `api.conf` marine section. Bathymetry endpoint downloads a real CUDEM profile. Station discovery returns results for coastal US coordinates. All setup endpoints follow existing security model (auth required).

**T6.4 — Marine alert radius in general alerts config**
- Owner: `clearskies-docs-author` (Sonnet)
- Files: Modify existing alerts wizard step templates in `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/alerts/`
- Reference: OPERATIONS-MANUAL alerts config section (written in T0B.4), ADR-089
- Do: Add marine alert radius field to the alerts configuration wizard step (NOT the marine wizard step). Number input (miles), default 0. When station coordinates are within 50 miles of any NWS marine zone, auto-suggest 25 miles with explanatory text. Show discovered marine zones with names and distances for operator confirmation. Help text explains that marine alerts (Small Craft Advisories, Gale Warnings, etc.) require this radius to be set for coastal stations.
- Accept: Alert radius field appears in alerts config step. Auto-suggest triggers for coastal stations. Discovered zones display with distances. Saving stores zone IDs in `api.conf` alerts section.

### QC Gate 6
- Coordinator runs: configure a test marine location via the wizard on weather-dev for Wrightsville Beach (34.21, -77.79) with surf + fishing activities. Verify: station discovery returns NDBC + CO-OPS stations, bathymetry downloads, config saves to `api.conf`, API reloads and serves marine endpoints.
- Coordinator verifies: marine alert radius auto-suggests 25 miles for this coastal location. Zone discovery shows AMZ250 at ~0.1 km.
- Coordinator verifies: round-trip — edit location in admin → save → verify config unchanged or correctly updated.

### QA Gate 6
- `clearskies-auditor`: verifies wizard steps follow existing HTMX patterns. Verifies help content keys exist for all marine wizard fields (`help.wizard.marine.*`). Verifies setup API endpoints follow existing security model. Verifies no marine-specific config is in the general alerts step beyond the marine alert radius.

---

## PHASE 7 — Dashboard Pages

Four new pages + now-page summary card + routing/navigation.

### General Weather Integration — Two Separate Systems

Marine pages display data from **two independent systems** that must remain cleanly separated:

1. **Marine-specific data** (waves, tides, currents, buoy readings, swell, marine text forecasts, marine alerts) — from the NOAA marine providers built in Phases 1–3. Fetched proactively by the cache warmer. This entire system gets replaced when expanding outside the US.

2. **General weather data** (air temperature, wind, precipitation, sky cover, humidity, UV) — from the **operator's already-configured forecast provider** (NWS, OWM, Xweather, etc.), queried for each marine location's coordinates. This uses the same provider system that powers the main site — no new provider integration needed.

**Why both:** Someone on the fishing page or beach safety page shouldn't have to navigate back to the main weather page to check if it's going to rain. Each marine page is self-contained with weather context relevant to that activity. Coastal weather can differ dramatically from the operator's station location over short distances — sea breeze effects, marine layer fog, convective patterns along sea breeze convergence zones can create 10–20°F temperature differences within a few miles of the shoreline.

**On-demand caching (lazy fetch):** Unlike the main site's forecast (proactively polled by the cache warmer), general weather data for marine locations is fetched **on-demand** — only when a marine page is requested. The response is cached with a configurable TTL. If nobody visits the marine page for 3 hours, zero forecast provider calls are made for that location. This minimizes API costs, especially for metered providers (OWM, Xweather).

**Spatial deduplication:** Marine locations within 2.5 km of each other share a single forecast and observation call (they map to the same forecast grid point — NWS grids are ~2.5 km resolution). Locations farther apart (e.g., a beach vs. an offshore zone 25 miles away) get separate calls. Deduplication is automatic based on grid-point rounding at config time.

**Operator-configurable refresh intervals:**

| Setting | Default | Range | Notes |
|---|---|---|---|
| Marine location forecast TTL | 3 hours | 1 hr / 3 hr / 6 hr | Forecasts don't change dramatically hourly; 3h balances freshness vs. API cost |
| Marine location observation TTL | 30 minutes | 15 min / 30 min / 60 min | Current conditions at the marine location from the forecast provider |

These are set in the marine section of the wizard/admin. The wizard explains that each distinct marine grid point adds ~2 forecast provider calls per refresh cycle, and the operator can tune the interval to manage their API budget. NWS operators (free API) can use shorter intervals; metered provider operators may prefer longer intervals.

**Weather source selection (automatic):** At config time, the system computes the haversine distance from the operator's weewx station to each marine location. The weather source is determined automatically:
- **Station within 2.5 km** → use the weewx station's own data for both forecast and current observations at this location. Zero forecast provider API calls. The station's real-time data (loop interval ~2.5s via SSE) is the most accurate and freshest source when the station is co-located with the marine spot.
- **Station beyond 2.5 km** → use the configured forecast provider (NWS/OWM/Xweather) for this location's coordinates. On-demand fetch, cached at the operator-configured TTLs (default: forecast 3 hr, observations 30 min). Nearby marine locations share calls via the 2.5 km grid-point deduplication.

The wizard displays the computed distance and which source will be used ("Your station is 0.8 km from this location — station data will be used" or "Your station is 14.2 km from this location — forecast provider will be used, adding ~2 calls per refresh cycle").

**NDBC buoy data is always separate.** Buoy observations (SST, wave height, ocean wind, pressure) are marine-specific at-water data. They complement but do not substitute for land-side weather, and land-side weather does not substitute for them. Both are displayed on marine pages.

All pages follow existing dashboard patterns: lazy-loaded routes, `VisibilityGuard` for `pages.json` visibility control, i18n via `useTranslation()`, responsive design (375px minimum), light/dark mode, data refresh via existing polling/SSE infrastructure.

### Tasks

**T7.1 — Marine conditions page**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `repos/weewx-clearskies-dashboard/src/pages/Marine.tsx` + supporting components in `src/components/marine/`
- Reference: DASHBOARD-MANUAL marine pages section (written in T0B.5), DESIGN-MANUAL for card patterns and tokens, existing `src/pages/Earthquakes.tsx` for page structure pattern
- Do:
  - Route: `/marine`. Location cards → detail view.
  - **Design priority:** Boaters need a hyper-specific, localized, and easily scannable marine conditions page. Conditions over water are radically different from land. The page must lead with these essentials:
    1. **Wind speed & direction** — the primary driver of sea chop. Display in knots (the marine standard — use `group_ocean_speed` with knot conversion). Show current speed, gusts, and direction with a wind arrow. In the forecast view, show shifting direction throughout the day so boaters can plan around wind changes. Source: NDBC buoy (real-time) + WaveWatch III (forecast).
    2. **Wave height & period** — height alone isn't enough. The period (seconds between crests) dictates ride quality: short period (~3s) means a rough "washing machine" ride, long period (~10s) means a gentle roll. Both must be displayed together prominently, not period buried in a details table. Source: NDBC (observed) + WaveWatch III (forecast) + NWPS (nearshore).
    3. **Tides & currents** — essential for preventing grounding in shallow bays or safely navigating narrow inlets. Show tide predictions (high/low times + heights), observed water levels, and current speed/direction where available. Source: CO-OPS predictions + observations, NWPS current components (UCUR/VCUR).
    4. **Active advisories** — a dedicated, visually prominent section (not just a badge count) displaying Small Craft Advisories, Gale Warnings, Special Marine Warnings, and other marine zone alerts. These are safety-critical — boaters check this first. Source: NWS marine zone alerts (ADR-089) + coastal flood alerts.
    5. **Visibility forecast** — fog, heavy rain, or haze that drops visibility impacts safe navigation. Display current visibility from NDBC buoy (VIS column) and visibility mentions from NWS marine text forecast. Source: NDBC `.txt` VIS field + NWS marine zone forecast text.
    6. **Live buoy reports** — real-time NDBC buoy observations displayed as a cross-reference panel alongside the forecast, so boaters can compare "what's forecast" vs. "what's actually happening right now." Show: wind, waves, pressure, air/water temp, visibility — all from the nearest NDBC buoy with station ID and distance. Source: NDBC standard met (T1.1).
    7. **Barometric pressure** — a rapid pressure drop is a key warning sign for approaching thunderstorms and squalls. Show current reading, trend arrow (falling/stable/rising), and recent history (6–12h sparkline). Source: NDBC buoy PRES + PTDY (pressure tendency) fields.
  - **Location cards** (no locationId): grid of cards, one per configured marine location. Each card shows: location name, current wind speed/direction (in knots), combined wave height + period, next tide (high/low + time), water temp, active marine alert indicator (color-coded badge: red for warnings, yellow for advisories, count). Click → detail view.
  - **Detail view** (with locationId):
    - Active advisories section (top of page, visually prominent — dedicated panel listing all active marine zone alerts with severity, headline, and expiry time. Not just a count badge).
    - Wind panel: current speed/gust/direction (in knots) from NDBC buoy, plus 72h wind forecast chart showing speed and direction shifts over time (WaveWatch III).
    - Wave forecast chart (72h, Recharts area chart with wave height AND period displayed together — dual-axis or overlaid so the relationship between height and period is visible at a glance).
    - Live buoy observations panel: real-time NDBC data (wind, waves, pressure, air temp, water temp, visibility) with station ID, distance from location, and last-update timestamp. Positioned alongside forecast data for easy cross-reference.
    - Barometric pressure panel: current reading, trend arrow, 6–12h sparkline from NDBC PRES/PTDY.
    - Visibility indicator: current visibility from NDBC (distance in nautical miles), visibility forecast from NWS marine text.
    - Tide chart (standalone, 72h, CO-OPS predictions with high/low markers + observed water level overlay). Current speed/direction where available from CO-OPS or NWPS.
    - NWS marine text forecast (accordion, one period per section — includes wind, seas, visibility, weather text).
    - General weather panel: air temperature, precipitation forecast, sky cover, humidity — from the configured forecast provider (on-demand cached) or weewx station (if operator elected station substitution). Clearly labeled as "Weather at {location name}" to distinguish from buoy/marine data.
    - Rip current probability (when available from NWPS v1.5 — show-when-available pattern).
    - Total water level (NWPS v1.5, show-when-available).
  - Responsive: cards stack single-column at 375px, 2-column at 768px, 3-column at 1024px.
  - i18n: all text via translation keys. Marine-specific keys in `marine.json` per locale.
- Accept: Page renders with real data from the API. Wind displayed in knots. Wave height and period displayed together (not period buried in details). Active advisories are a dedicated prominent section at the top. Live buoy observations panel shows real-time data with station ID and distance. Barometric pressure shows trend with sparkline. Visibility displayed from NDBC. Tide chart is a standalone readable element. Charts display correctly. Responsive at 375px. `tsc --noEmit` clean. `vite build` clean. Bundle size within budget.

**T7.2 — Surf conditions page**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `repos/weewx-clearskies-dashboard/src/pages/Surf.tsx` + `src/components/surf/`
- Do:
  - Route: `/surf`. Per-spot cards → detail view.
  - **Design priority:** Surfers look for high-resolution, localized data on wave height, wind direction, and swell period to determine wave quality and safety. The page must lead with these four essentials:
    1. **Wave face height** — expected height at the break in feet or meters (this is the post-supplement breaking height from the surf scorer, NOT raw offshore Hs). Displayed prominently on both cards and detail view. The face height is what surfers actually experience; offshore significant wave height is a different, less useful number.
    2. **Swell period & direction** — time in seconds between waves and the compass angle from which the swell hits the coast. Show both numerically and contextually (e.g., "12s from NW" with a visual indicator of how that angle meets the beach facing). This tells surfers whether they're getting long-period groundswell (clean, powerful) or short-period wind swell (choppy, weak).
    3. **Wind direction & speed** — critical for spotting clean conditions. Surfers want light offshore winds (blowing from land to sea). The display must make it instantly clear whether wind is offshore (good), cross-shore (mixed), or onshore (poor) relative to the beach facing, not just raw compass direction.
    4. **Tide chart** — standalone prominent element (not just an overlay on the wave chart). Hourly highs and lows with times, because many breaks only work well during specific tidal phases (e.g., mid-tide incoming, or only at low tide). The tide chart should be large enough to read tide height at any hour and correlate with the wave forecast timeline.
  - **Spot cards:** Star rating (1–5, visual stars), current wave face height at break, primary swell period, wind direction indicator (arrow with offshore/cross/onshore label), quality label (Poor–Epic), conditions text snippet.
  - **Detail view:**
    - 72-hour forecast timeline (horizontal scrollable strip with star ratings at each timestep).
    - Wave face height chart (72h, showing post-supplement breaking height — the number surfers care about).
    - Swell breakdown (spectral components as stacked colored bands showing individual swell systems — height, period, and direction per system). This reveals whether conditions are clean groundswell or mixed wind chop.
    - Wind quality panel: direction relative to beach facing (offshore/cross/onshore label), speed, and trend over the forecast period. Offshore light winds highlighted as ideal conditions.
    - Tide chart (standalone, 72h, CO-OPS predictions with high/low markers + observed water level overlay). Sized to be independently readable — not squeezed as a secondary overlay.
    - Beach alignment diagram (simple compass showing swell direction vs beach facing — helps surfers see at a glance whether the swell angle is favorable for their break).
    - General weather panel: air temperature, precipitation forecast, sky cover — from the configured forecast provider or weewx station. Surfers check this for rain/storms that affect sessions.
    - Activity-relevant alerts (Beach Hazards Statement, High Surf Advisory/Warning, Rip Current Statement — filtered per ADR-090).
  - i18n: surf-specific keys in `surf.json`.
- Accept: Star ratings render visually. Wave face height (not offshore Hs) is the primary displayed height. Swell breakdown shows individual components with period and direction. Wind quality clearly labels offshore/cross/onshore relative to beach facing. Tide chart is a standalone readable element with hourly resolution. Forecast timeline scrollable. Responsive at 375px. Build clean.

**T7.3 — Fishing forecast page**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `repos/weewx-clearskies-dashboard/src/pages/Fishing.tsx` + `src/components/fishing/`
- Do:
  - Route: `/fishing`. Per-location → detail view.
  - **Design priority:** Fishermen use a forecast page to quickly identify peak feeding windows and gauge on-the-water safety. The page must lead with these essentials:
    1. **"Fishiness" score (0–100)** — the aggregate score from the fishing scorer, displayed as a prominent number per period. Color-coded: 70–100 green (good), 40–69 yellow (fair), 0–39 red (poor). This is the at-a-glance indicator fishermen scan first.
    2. **Tides & currents** — crucial for both saltwater and tidal river anglers. Show tide stages (high/low times + heights), peak flow times, and tidal movement direction. Many species feed actively during specific tide phases; the tide chart must be prominent and independently readable (not a small sidebar).
    3. **Solunar tables** — lunar phases, sun/moon rise and set times, and major/minor feeding windows calculated for the specific location. Major periods (moon transit/underfoot) and minor periods (moonrise/moonset) displayed on a visual timeline so fishermen can plan trips around peak windows.
    4. **Barometric pressure** — the most closely watched weather metric among fishermen. Show current reading, trend arrow (falling/stable/rising), and recent history (6–12h sparkline). Sudden pressure drops often trigger feeding frenzies — this should be visually prominent, not buried in a data table.
    5. **Water temperature** — impacts fish metabolism and seasonal movements. Show current SST from NDBC/CO-OPS. Species temperature preferences from the scorer provide context (e.g., "Redfish: optimal range" or "Striped bass: water too warm").
    6. **Wind & swell (informational)** — wind speed, direction, and gusts impact boat control, water clarity, and safety. Swell height and period are vital for surfcasting. Displayed as current conditions, NOT as part of the fishing score (wind/swell scoring deferred pending research — see T4.2). Wind data from NDBC buoy, swell from WaveWatch III/NWPS.
    7. **Sunrise/sunset** — displayed alongside the solunar timeline. The classic "morning and evening bites" are prime times — dawn and dusk periods should be visually highlighted on the forecast timeline.
  - **General weather at this location:** Air temperature, precipitation forecast, sky cover, and humidity from the configured forecast provider (on-demand cached) or the weewx station (if operator elected station substitution). Displayed as a compact weather summary panel — fishermen planning a trip need to know if it's going to rain or storm, not just the marine-specific metrics.
  - **Overview:** 3-day grid with 5–6 periods per day. Each cell shows: overall score (0–100, color-coded), top active species icons/names, solunar indicator (major/minor period marker), sunrise/sunset markers on dawn/dusk periods.
  - **Detail view:**
    - Solunar calendar (moon phase, major/minor periods visualized on a 24h timeline with sunrise/sunset markers).
    - Tide chart (standalone, 72h, CO-OPS predictions with high/low markers + observed water level overlay + current tide stage label). Sized for independent readability.
    - Barometric pressure panel (current reading, trend arrow, 6–12h sparkline from NDBC buoy or station barometer).
    - Species activity table (species name, activity status with color, individual component scores on 0–100 scale, water temperature suitability indicator).
    - Conditions breakdown (pressure trend, tide state, time of day, water temp — each with score bar on 0–100 scale).
    - Wind & swell panel (informational — current wind speed/direction/gust, swell height/period. Labeled as conditions data, not scored).
    - CUDEM habitat features (informational: "Drop-off at 200m offshore", "Reef structure at 15m depth").
    - Activity-relevant alerts (marine zone alerts per ADR-090).
  - i18n: fishing-specific keys in `fishing.json`.
- Accept: Period grid renders 3 days × 5–6 periods with 0–100 scores and color coding. Solunar timeline shows major/minor periods with sunrise/sunset. Tide chart is a standalone readable element. Barometric pressure shows trend with sparkline. Species classifications show active/less_active/inactive with 0–100 scores. Wind and swell display as informational (not scored). Responsive at 375px. Build clean.

**T7.4 — Beach safety page**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `repos/weewx-clearskies-dashboard/src/pages/BeachSafety.tsx` + `src/components/beach-safety/`
- Do:
  - Route: `/beach-safety`. Per-location → detail view.
  - **Design priority:** Swimmers, sunbathers, and beachgoers need a safety-first page that combines sea state with environmental hazards. Unlike surfers (who seek waves) or boaters (who plan around wind), this audience's primary question is "is it safe to go in the water today?" The page must lead with clear safety signals:
    1. **Sea state safety indicator** — a simple, color-coded overall assessment (green/yellow/red) derived from wave height and period. Calm conditions: waves under 1–2 ft with long period (10+ seconds, gentle rolling). Moderate: 2–3 ft or short period (4–6 seconds, choppy "washing machine" effect). Dangerous: over 3 ft or very short period. This is NOT the surf quality score — it's an inverted safety assessment (surfers want big waves; swimmers don't).
    2. **Rip current risk** — the most critical safety element for swimmers. Display the NWS Surf Zone Forecast (SRF, T1.5) rip current risk level (low/moderate/high) prominently. When available, supplement with NWPS v1.5 rip current probability (show-when-available). High rip current risk should be visually alarming (red banner or similar).
    3. **Tides & currents** — tide schedule with high/low times and heights. Current speed and direction where available from CO-OPS or NWPS. Important for understanding water depth, exposed sandbars, and beach access — and for avoiding getting swept away by longshore currents or tidal flow.
    4. **Water temperature** — vital for preventing cold shock or hypothermia and for deciding whether a wetsuit is necessary. Display current SST from NDBC/CO-OPS with comfort context (e.g., "65°F — wetsuit recommended" or "78°F — comfortable for swimming"). Temperature thresholds: >75°F comfortable, 65–75°F cool (wetsuit optional), 55–65°F cold (wetsuit recommended), <55°F dangerous (hypothermia risk).
    5. **Wind speed & direction** — wind dictates surface chop and affects body temperature. Note that offshore winds (land to sea) make the water flat but can push swimmers out, while onshore winds create surface chop. Display with safety context, not just raw numbers.
    6. **Active alerts** — Beach Hazards Statement, High Surf Advisory/Warning, Rip Current Statement, Coastal Flood Advisory/Warning (filtered per ADR-090). Displayed as a prominent safety banner, similar to the marine page's advisory section.
    7. **UV Index** — important for prolonged sun exposure. Available from NWS SRF text product (T1.5). Display with exposure guidance (e.g., "8 — Very High: seek shade 10am–4pm, SPF 30+ required").
    8. **Atmospheric visibility** — fog, rain, or haze affecting beach conditions. From NDBC VIS column.
  - **What this page does NOT include (v1):**
    - **Water quality / bacterial counts** — no programmatic data source available in v1. EPA BEACON exists but is a web-only interface with annual state reporting, no REST API. Future enhancement: if EPA or state health departments expose water quality APIs, add a `water_quality` provider. For now, operators can link to their local water quality monitoring site via a configurable URL in the beach safety location config.
    - **Marine life / wildlife alerts** — no universal US API for jellyfish, shark, or stingray sightings. Regional programs exist (e.g., Atlantic White Shark Conservancy's Sharktivity) but nothing standardizable. Future enhancement: add as operator-managed manual entries or integrate regional APIs when available.
    - **Underwater visibility / water clarity** — NDBC VIS is atmospheric visibility, not underwater. No NOAA source provides underwater visibility data. Not available in v1.
    - **Lightning/storm alerts** — covered by the existing general alerts system (Severe Thunderstorm Warning, etc.), which already displays on all pages via the alert banner.
  - **Overview cards** (no locationId): grid of cards per beach safety location. Each card shows: location name, sea state safety indicator (green/yellow/red), rip current risk level, water temp, next tide, active alert count. Click → detail view.
  - **Detail view** (with locationId):
    - Safety alerts banner (top of page — active Beach Hazards, High Surf, Rip Current, Coastal Flood alerts).
    - Sea state panel: current wave height and period with safety interpretation (calm/moderate/dangerous), color-coded. Wave forecast chart showing height + period over 72h with safety threshold lines overlaid.
    - Rip current risk panel: NWS SRF rip current risk (low/moderate/high) with safety guidance text per level. NWPS v1.5 rip current probability when available (show-when-available).
    - Tide chart (standalone, 72h, CO-OPS predictions with high/low markers + observed water level overlay). Current speed/direction where available.
    - Water temperature panel: current SST with comfort/safety interpretation. Temperature trend if available.
    - Wind panel: speed, direction, and offshore/onshore context for swimmers.
    - UV Index: from NWS SRF, with exposure guidance.
    - Visibility: atmospheric visibility from NDBC.
    - Wave runup and total water level (NWPS v1.5, show-when-available) — relevant for beach erosion and flooding risk.
    - General weather panel: air temperature, heat index, precipitation forecast, sky cover, thunderstorm probability — from the configured forecast provider or weewx station. Critical for beach safety (heat stroke, lightning, sudden storms).
    - Hazardous structures note (if operator has configured structures for this location — informational safety warning about nearby jetties, piers, or boating channels).
    - Operator-configurable external links section (for local water quality monitoring, lifeguard reports, or wildlife alert services — empty by default, operator adds URLs in admin).
  - i18n: beach-safety-specific keys in `beach-safety.json`.
- Accept: Sea state safety indicator renders with correct color coding (green/yellow/red based on wave height + period thresholds). Rip current risk displays prominently from SRF data. Water temperature shows comfort/safety interpretation. UV Index displays with guidance. Safety alerts banner shows relevant alerts. External links section renders when configured, hidden when empty. Responsive at 375px. Build clean.

**T7.5 — Now page marine summary card**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: Modify `repos/weewx-clearskies-dashboard/src/pages/Now.tsx` or card registry
- Reference: DASHBOARD-MANUAL now-page layout section, existing card patterns (`now-layout.json`)
- Do: Add optional marine summary card to `now-layout.json` card registry. Card shows: current wave height + period, water temp (SST), next tide (type + time + height), wind speed/direction, active marine alert count (badge, links to alert detail). Card links to `/marine` detail view. Card hidden when marine not in `pages.json`.
- Accept: Card renders in now-page layout when configured. Links work. Hidden when marine not configured. Existing now-page cards unaffected.

**T7.6 — Routing, navigation, pages.json**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - `repos/weewx-clearskies-dashboard/src/router.tsx` (add lazy routes)
  - `repos/weewx-clearskies-dashboard/src/components/Navigation.tsx` (add nav items)
  - `repos/weewx-clearskies-dashboard/public/pages.json` or equivalent visibility config
- Do: Add lazy-loaded routes for `/marine`, `/surf`, `/fishing`, `/beach-safety`. Add navigation items with Phosphor icons (Waves for marine, Surfboard for surf, FishSimple for fishing, SwimmingPool or Umbrella for beach safety). `VisibilityGuard` wraps each route — hidden when page not in `pages.json`. i18n nav item labels.
- Accept: Navigation shows marine/surf/fishing/beach-safety items when pages are in `pages.json`. Hidden when not. Lazy loading works (code-split chunks). No bundle size regression beyond expected page additions.

### QC Gate 7
- Coordinator runs: `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test"` — vitest baseline holds (40 passed) + new page tests pass.
- Coordinator runs: `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm run build"` — `tsc --noEmit` clean + `vite build` clean. Check bundle size against budget (200 KB gzipped JS).
- Coordinator deploys to weather-dev and visually verifies in browser at `https://weather-test.shaneburkhardt.com`:
  - Marine page loads with real data. Wind in knots. Wave height + period displayed together. Active advisories section prominent at top. Live buoy panel shows NDBC data with station ID. Pressure sparkline renders. Visibility displayed.
  - Surf page shows star ratings, swell breakdown, forecast timeline.
  - Fishing page shows period grid, solunar calendar, species table.
  - Beach safety page loads with sea state safety indicator (green/yellow/red), rip current risk from SRF, water temp with comfort interpretation, UV index, safety alerts banner.
  - Now-page marine card renders (if configured).
  - All pages responsive at 375px viewport width.
  - Light and dark mode both work.
  - Navigation items appear/disappear based on pages.json (including beach-safety).

### QA Gate 7
- `clearskies-auditor`: verifies all user-facing text uses i18n translation keys (no hardcoded English strings). Verifies all 13 locale files have marine/surf/fishing/beach-safety translation keys (may be machine-translated placeholders — presence check only). Verifies all pages use `VisibilityGuard`. Verifies no page imports increase the main bundle chunk (all pages lazy-loaded). Verifies beach safety page does NOT include water quality, wildlife alerts, or underwater visibility (explicitly out of scope for v1 — see T7.4 "What this page does NOT include").

---

## PHASE 8 — End-to-End Validation + Documentation

Full-stack validation against real NOAA data for a configured test location. Documentation sync to ensure all governing documents reflect the implemented feature set.

### Tasks

**T8.1 — Integration test suite**
- Owner: `clearskies-test-author` (Sonnet)
- Files: New test files in `repos/weewx-clearskies-api/tests/` covering end-to-end marine flows
- Do:
  - **Provider integration tests** (against live NOAA endpoints — marked with `@pytest.mark.integration`):
    - NDBC: fetch real buoy data from station 41025 (Diamond Shoals). Verify non-null wave height, period, direction.
    - CO-OPS: fetch tide predictions for station 8658163 (Wrightsville Beach). Verify high/low markers present.
    - WaveWatch III: fetch ERDDAP forecast for Cape Hatteras. Verify 25 timesteps.
    - NWPS: fetch GRIB2 for WFO ILM. Verify wave height extraction.
    - NWS marine: fetch zone forecast for AMZ250. Verify non-empty periods.
    - NWS SRF: fetch surf zone forecast for WFO ILM. Verify rip current risk and UV index present.
  - **Enrichment integration tests:**
    - Full surf pipeline: NWPS data → supplements → scoring for Wrightsville Beach config. Verify 1–5 star output.
    - Full fishing pipeline: environmental data + solunar for Wrightsville Beach. Verify period scores.
  - **Endpoint integration tests:**
    - `GET /api/v1/marine` → verify valid MarineBundle.
    - `GET /api/v1/surf/{locationId}` → verify star ratings present.
    - `GET /api/v1/fishing/{locationId}` → verify species classifications.
    - `GET /api/v1/beach-safety/{locationId}` → verify safety_level, rip_current_risk, comfort_level present.
    - `GET /api/v1/almanac/solunar` → verify solunar times.
  - **Cross-validation:** Where CDIP (Coastal Data Information Program, ~180 US West Coast stations) spectral wave data is available, compare NDBC spectral decomposition against CDIP for the same station. Verify swell component heights agree within ±15%.
- Accept: All integration tests pass against live NOAA endpoints. Cross-validation within tolerance. No regressions in existing test suite.

**T8.2 — Deploy + smoke test**
- Owner: Coordinator (Opus)
- Do:
  - Configure a test marine location on weewx + weather-dev: Wrightsville Beach (34.21, -77.79), activities: marine + surf + fishing + beach_safety. Nearest NDBC station: 41025. Nearest CO-OPS: 8658163. Marine zone: AMZ250.
  - Deploy via `scripts/deploy-api.sh` (API to weewx) and `scripts/redeploy-weather-dev.sh` (dashboard + config to weather-dev). Wait for cache warmer (~2 min).
  - **Smoke checklist** (at `https://weather-test.shaneburkhardt.com`):
    - [ ] `/marine` page loads with location card for Wrightsville Beach
    - [ ] Click card → detail view with buoy data, wave chart (height + period together), tide chart, NWS text forecast, wind in knots, pressure sparkline, visibility
    - [ ] `/surf` page loads with star rating for Wrightsville Beach
    - [ ] Surf detail shows wave face height (not offshore Hs), swell breakdown, forecast timeline, conditions text, wind quality (offshore/cross/onshore), standalone tide chart
    - [ ] `/fishing` page loads with 3-day period grid, scores on 0–100 scale
    - [ ] Fishing detail shows solunar calendar, species table, conditions breakdown, pressure sparkline, wind/swell informational panel
    - [ ] `/beach-safety` page loads with sea state safety indicator (green/yellow/red)
    - [ ] Beach safety detail shows rip current risk from SRF, water temp with comfort interpretation, UV index with guidance, tide chart, safety alerts banner
    - [ ] `/api/v1/marine` returns valid JSON with freshness block
    - [ ] `/api/v1/surf/wrightsville-beach` returns star ratings
    - [ ] `/api/v1/fishing/wrightsville-beach` returns period scores on 0–100 scale
    - [ ] `/api/v1/almanac/solunar` returns solunar times matching published tables
    - [ ] Marine alerts display when active (may need to wait for SCA/Gale event)
    - [ ] Now-page marine summary card renders (if added to layout)
    - [ ] All pages responsive at 375px
    - [ ] Light/dark mode works on all new pages
    - [ ] Navigation shows all four marine pages (marine, surf, fishing, beach-safety) when configured
    - [ ] Existing pages (now, forecast, almanac, etc.) unaffected — no regressions
    - [ ] API pytest: full suite passes, baseline holds
    - [ ] Dashboard: `tsc --noEmit` + `vite build` clean, bundle within budget
- Accept: All smoke checklist items pass. No regressions in existing features.

**T8.3 — Documentation sync**
- Owner: `clearskies-docs-author` (Sonnet) for drafts, Coordinator (Opus) for review
- Files:
  - `docs/ARCHITECTURE.md` — verify marine domains, endpoints, pages, dependencies reflected. Close any Known gaps added during implementation.
  - `docs/manuals/API-MANUAL.md` — verify canonical models, unit groups, enrichment, endpoints match implemented code. Fix any discrepancies introduced during implementation.
  - `docs/manuals/PROVIDER-MANUAL.md` — verify provider contracts match implemented modules. Update cache TTLs if any were adjusted during implementation.
  - `docs/manuals/DASHBOARD-MANUAL.md` — verify page behavior, i18n keys, data refresh match implementation.
  - `docs/manuals/OPERATIONS-MANUAL.md` — verify config sections, install instructions, wizard steps match implementation.
  - `contracts/canonical-data-model.md` — verify marine models and unit groups documented.
  - API `api.conf.example` — add example `[marine]` section with comments.
- Do: Read each governing document section added in Phase 0B. Compare against the actual implemented code. Fix discrepancies — the code is authoritative at this point; the docs must match the code.
- Accept: grep across all governing documents for "TODO"/"TBD"/"FIXME" — zero hits in marine-related sections. Every marine endpoint documented in ARCHITECTURE.md and API-MANUAL matches a real route in the code. Every config key documented in OPERATIONS-MANUAL exists in `settings.py` or `marine_config.py`.

### QC Gate 8
- Coordinator runs: full pytest suite on weewx — verify final baseline. Record new baseline in `reference/clearskies-dev.md` pytest baselines table.
- Coordinator runs: full vitest suite on weather-dev — verify final baseline. Record in baselines table.
- Coordinator runs: dashboard build — verify bundle size. Record in baselines table.
- Coordinator runs: smoke checklist — all items pass.
- Coordinator verifies: doc-code sync — every governing document accurately reflects the implemented system.

### QA Gate 8
- `clearskies-auditor`: final audit across all marine code. Checklist:
  - [ ] No `eval()` anywhere in marine code
  - [ ] No hardcoded credentials or API keys
  - [ ] All provider modules follow PROVIDER-MANUAL §1–§7 contract
  - [ ] All enrichment processors follow API-MANUAL enrichment contract
  - [ ] All endpoints follow route pattern (capability check, unit conversion, freshness)
  - [ ] All user-facing text uses i18n (no hardcoded English)
  - [ ] All config keys documented in OPERATIONS-MANUAL
  - [ ] All canonical models documented in API-MANUAL
  - [ ] No Phase II shoaling/refraction/bottom friction code was ported (grep verification)
  - [ ] Attribution text present for NOAA CUDEM and NOAA data sources
  - [ ] Marine alert radius is in general alerts config, not marine config

---

## Key Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| NWPS temporary outage (NOAA maintenance) | No nearshore-supplemented data for affected WFOs | Marine page shows WaveWatch III offshore data + NDBC observations. No nearshore supplements applied. Freshness metadata shows NWPS age. All 36 WFOs run 2–3 cycles/day under normal operations — extended outages are NOAA-wide events, not per-WFO. |
| eccodes build complexity | Operators struggle to install native C library | Docker: baked into image, no operator action. Native: OPERATIONS-MANUAL documents platform-specific prerequisites (e.g., `apt install libeccodes-dev`), then `pip install weewx-clearskies-api[marine]`. Wizard detects missing eccodes and shows install instructions before allowing marine config. |
| ERDDAP availability | WaveWatch III unavailable | ProviderHTTPClient retry/backoff; all other marine data (NDBC, CO-OPS, NWS) independent |
| Surf quality accuracy expectations | Users expect Surfline quality | Label as "estimated quality." Provide raw data so experienced surfers can judge. Statistical calibration deferred to v2+. |
| NOAA CUDEM/NCEI availability | Bathymetry download fails at setup | One-time operation; stored in config. Operator retries later. System self-sufficient after setup. Regional fallback profiles available when CUDEM unavailable. |
| Great Lakes wave dynamics differ | No swell, no tides (seiche/seasonal levels) | Scoring works on wave height/period/wind regardless of generation mechanism. Tide-dependent scoring handles absent tidal signal gracefully. |
| Wizard complexity | Most complex wizard step yet | HTMX progressive disclosure. Auto-populated stations with override. Async bathymetry with progress indicator. |
| Scope size (~20 new files, 3 repos, 9 phases) | Long timeline | Each phase has independent QC gates. Feature degrades gracefully at every boundary. Each phase adds standalone value. |

## Verification

Every phase has a QC gate (coordinator) and QA gate (auditor). No phase advances until both pass. After Phase 8, the complete system must satisfy:

- All marine endpoints return data for configured US coastal locations
- Surf ratings produce physically reasonable 1–5 star values
- Fishing forecasts show solunar + conditions scoring with species classifications
- Dashboard pages render responsively at 375px with i18n in 13 locales
- NWPS supplements produce adjusted nearshore values for configured spots
- Marine zone alerts appear in the general alert banner for coastal stations (regardless of marine feature)
- Missing-eccodes detection produces clear error with platform-specific install instructions
- All governing documents (ARCHITECTURE.md, 5 manuals, canonical-data-model) reflect the implemented system
- Test baselines recorded and no regressions from pre-marine baselines
- No Phase II shoaling/refraction/bottom friction code ported (verified by grep)
- No `eval()`, no hardcoded credentials, no hardcoded English strings in new code
