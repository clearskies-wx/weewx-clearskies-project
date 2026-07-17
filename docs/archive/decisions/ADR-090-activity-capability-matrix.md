---
status: Archived — consolidated into API-MANUAL.md, DASHBOARD-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
amended: 2026-07-13
deciders: shane
---

# ADR-090: Activity capability matrix

## Context

ADR-086 defines marine locations with one or more activities (marine/boating, surf, fishing, beach safety). What "enabling surf" or "enabling fishing" actually means in terms of data fetched, enrichment run, and UI rendered needs a precise definition. Without it, every downstream implementation decision — which provider modules to call, which enrichment processors to run, which dashboard sections to render — is guesswork.

A capability is a specific data feed, enrichment processor, or UI feature. Each capability has a data source and may appear in one or more activity categories. Some capabilities span multiple categories (tide predictions are needed for marine, surf, fishing, and beach safety). Enabling any one category that uses a capability triggers the data feed; disabling the last category that uses it stops fetching.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Each activity defines its own independent data feeds | Clean separation. Easy to reason about. | Massive duplication — tide data fetched separately for marine, surf, fishing, beach safety. Four cache entries for the same data. |
| Shared capability pool with per-activity activation | Efficient — each data feed fetched once regardless of how many activities use it. Clear cross-activity dependencies. | Requires a matrix to track which activities enable which capabilities. More complex teardown (must check all activities before stopping a feed). |
| Monolithic "marine enabled" flag | Simplest config. | All-or-nothing — operator who only wants fishing still gets wave model processing. Wastes API calls and cache space. |

## Decision

Define an **activity capability matrix** — the authoritative reference for what each activity enables. Capabilities are shared; activities activate them.

### Capability matrix

| Capability | Data source | Marine/Boating | Surf | Fishing | Beach Safety |
|---|---|:---:|:---:|:---:|:---:|
| **Wave data** | | | | | |
| Offshore wave forecast (Hs, period, direction) | WaveWatch III (ERDDAP) | Yes | Yes | — | — |
| Nearshore wave data + ADR-084 supplements | NWPS (GRIB2) | Yes | Yes | — | Yes |
| Surf quality scoring (1–5 stars) | Enrichment: surf_scorer | — | Yes | — | — |
| Multi-swell spectral breakdown | NDBC .swden/.swdir | — | Yes | — | — |
| **Tides & water levels** | | | | | |
| Tide predictions (high/low times + heights) | CO-OPS API | Yes | Yes | Yes | Yes |
| Observed water levels | CO-OPS API | Yes | — | — | Yes |
| **Observations** | | | | | |
| Buoy observations (wind, pressure, air temp, SST) | NDBC standard met (observational reference — offshore) | Yes | Yes | Yes | — |
| Water temperature | NDBC / CO-OPS | — | Yes | Yes | Yes |
| **Ocean data (ADR-091 amendment 2026-07-13)** | | | | | |
| Ocean temperature (surface) | OFS (primary) / MUR SST (fallback) / RTOFS (fallback) | Yes | Yes | Yes | Yes |
| Ocean temperature (water column) | OFS (primary) / RTOFS (fallback) | Yes | — | Yes | — |
| Ocean currents | OFS / RTOFS | Yes | — | Yes | — |
| Salinity | OFS / RTOFS | — | — | Yes | — |
| Modeled water levels (includes surge) | OFS `zeta`/`zetatomllw` | Yes | — | — | Yes |
| **Forecasts** | | | | | |
| NWS marine zone text forecast (wind, seas, visibility) | NWS API (marine zone) | Yes | — | — | — |
| NWS surf zone forecast (rip current risk, surf height) | NWS SRF product | — | Yes | — | Yes |
| **Alerts** | | | | | |
| Marine zone alerts (SCA, Gale, Storm, etc.) | NWS API (coastal marine zones) | Yes | Yes | Yes | — |
| Coastal/beach alerts (Beach Hazards, High Surf, Rip Current) | NWS API (public zones) | — | Yes | — | Yes |
| Coastal flood alerts (Coastal Flood, Storm Surge) | NWS API (public zones) | Yes | — | — | Yes |
| **Enrichment** | | | | | |
| Solunar times (major/minor periods) | Skyfield (computed) | — | — | Yes | — |
| Fishing scoring (pressure, tide, species, solunar) | Enrichment: fishing_scorer | — | — | Yes | — |
| Bathymetric habitat features (drop-offs, reefs, ledges) | NOAA CUDEM | — | — | Yes | — |
| **NWPS v1.5 (show-when-available)** | | | | | |
| Rip current probability | NWPS v1.5 (~12 WFOs) | — | — | — | Yes |
| Total water level | NWPS v1.5 | Yes | — | — | Yes |
| Wave runup | NWPS v1.5 | — | — | — | Yes |

### Cross-category rules

**Shared capabilities:** Tide predictions, marine zone alerts, buoy observations, and nearshore wave data appear in multiple categories. The data feed is activated when ANY category that uses it is enabled. It is deactivated only when ALL categories that use it are disabled.

**Marine zone alerts are NOT gated by the marine feature.** They are part of the general alerts system (ADR-089). When an operator configures a marine alert radius (in the alerts config, not the marine config), those alerts appear in the dashboard's standard alert banner for ALL visitors — regardless of whether any marine activities are enabled. The matrix above shows which marine *pages* additionally display activity-relevant alerts; the general alert banner always shows them.

**Alert routing on marine pages:** When marine activities are enabled, the marine/surf/fishing/beach safety pages show activity-relevant alerts from the general alert feed, filtered by alert type:
- Marine page: marine zone alerts + coastal flood alerts
- Surf page: marine zone alerts + coastal/beach alerts (Beach Hazards, High Surf, Rip Current)
- Fishing page: marine zone alerts
- Beach safety page: coastal/beach alerts + coastal flood alerts + NWS SRF rip current risk

This is display-side filtering of the general alert feed, not a separate data source.

**NWPS v1.5 products** (rip current probability, total water level, wave runup) are "show-when-available" — displayed when the WFO provides them, absent without error when they don't. Currently ~12 WFOs produce v1.5 data, rolling out over time.

### How the matrix drives implementation

**Provider fetch decisions:** At API startup, the marine config loader walks each location's enabled activities against this matrix. The union of all required capabilities across all locations determines which provider modules are activated and which station IDs / zone IDs are queried.

**Enrichment activation:** Solunar and fishing scoring processors are only registered when at least one location has fishing enabled. Surf scoring is only registered when at least one location has surf enabled.

**Dashboard page visibility:** Marine pages appear in navigation only when the corresponding activity is enabled on at least one location. The dashboard reads the API capabilities endpoint to determine which marine pages to show.

## Consequences

- **This matrix is the contract** between the plan, the API implementation, and the dashboard. If a capability cell says "Yes," the implementation must provide it. If it says "—," the implementation must not fetch or process that data for that activity.
- **Matrix evolution:** This matrix will evolve as implementation reveals refinements. Changes follow the normal ADR amendment process.
- **Provider efficiency:** Shared capabilities mean a location with marine + surf + fishing doesn't triple-fetch tide data. The fetch layer deduplicates by capability + station.
- **Config validation:** At startup, the API can validate that each enabled activity has the required station associations (e.g., surf requires an NDBC station for spectral data, fishing requires a CO-OPS station for tides).

## Acceptance criteria

- [ ] API activates only the provider modules required by the union of enabled activities across all locations
- [ ] Disabling the last activity that uses a capability stops that capability's data fetching
- [ ] Enabling any single activity that uses a shared capability activates that capability
- [ ] NWPS v1.5 fields display when available and are absent without error when not
- [ ] Marine zone alerts appear in the general alert banner regardless of marine feature state (per ADR-089)
- [ ] Activity-specific alert filtering on marine pages shows only relevant alert types per the matrix
- [ ] Dashboard capabilities endpoint reflects which marine activities are enabled

## Implementation guidance

- **Capability registry:** Module-level constant in `services/marine_config.py` — a dict mapping activity → list of required capabilities. Each capability maps to a provider domain + specific data type.
- **Fetch planning:** At startup, `plan_marine_fetches(marine_config) -> FetchPlan` walks the matrix and produces a deduplicated list of (provider_module, station_id/zone_id, data_type) tuples.
- **Dashboard pages.json:** Marine pages (`/marine`, `/surf`, `/fishing`, `/beach-safety`) are added to `pages.json` by the wizard when activities are enabled. Page visibility follows the existing `pages.json` pattern (ADR-024).
- **Alert filtering:** Dashboard-side, not API-side. The API's `/alerts` endpoint returns all alerts (including marine zone alerts per ADR-089). Each marine page filters the alert list by relevant `event` types.
- **Out of scope:** Individual provider module implementations (Phase 1–2). Dashboard page designs (Phase 7). Wizard step design (Phase 6).

## References

- Related ADRs: ADR-083 (domain architecture), ADR-084 (NWPS supplementation), ADR-086 (multi-spot location model), ADR-087 (spectral data), ADR-088 (fishing scoring), ADR-089 (marine zone alerts)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §6.4 (NWPS data value), §8 (location model)
