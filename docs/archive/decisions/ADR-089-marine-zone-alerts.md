---
status: Archived — consolidated into PROVIDER-MANUAL.md, OPERATIONS-MANUAL.md
date: 2026-07-09
archived: 2026-07-09
deciders: shane
---

# ADR-089: Marine zone alerts in the existing alert system

## Context

All three Clear Skies alerts providers (NWS, Xweather/Aeris, OWM) query by lat/lon point. NWS marine alerts (Small Craft Advisory, Gale Warning, Storm Warning, etc.) are issued against **marine zones** — water polygons with ocean-prefixed codes (AMZ, GMZ, PZZ, ANZ, PKZ, PHZ). A lat/lon point on land does not fall inside a water polygon.

**Verified behavior (live API testing, July 2026):**
- Wrightsville Beach NC (barrier island, ~1 km from ocean): NWS and Xweather both return marine alerts (SCA active)
- Wilmington NC (15 km inland): Both providers return only heat warnings — no SCA despite active SCAs on nearby marine zones AMZ150–158
- Raleigh NC (200 km inland): Correctly returns no marine alerts

**Root cause:** A point-based query matches against zone polygons. A point on land is not inside a water polygon unless it's on a narrow barrier island or pier.

**This is a gap in the current alert system, not a marine-feature issue.** Any coastal station operator whose weewx station is not directly on the waterline misses marine alerts. A "Huntington Beach Weather" station that shows NWS alerts but not Small Craft Advisories is failing its visitors' expectations — regardless of whether the operator has marine pages enabled.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Gate marine alerts behind the marine feature | Simpler — only marine-enabled installs need zone queries | Coastal stations without marine pages still miss SCAs. A weather dashboard near the coast that doesn't show marine alerts is broken. |
| Add marine zone awareness to the general alerts system | All coastal stations benefit. Marine alerts appear in the standard alert banner. | Adds zone queries to the alerts providers. Wizard/admin needs a marine alert radius field in the alerts section. |
| Always query nearby marine zones automatically | No operator config needed | May return irrelevant marine alerts for stations far inland. Over-fetching. |

## Decision

Add an **operator-defined marine alert radius** to the general alerts configuration (not the marine feature). When configured, the system discovers nearby NWS marine zones and supplements the existing point-based alert query with zone-specific queries.

### Configuration

- **Config key:** `marine_alert_radius_miles` (float, default 0 = disabled)
- **Config location:** Alerts section of `api.conf` (and wizard/admin alerts step), NOT the `[marine]` section
- **Wizard auto-suggest:** When the wizard detects the station is within 50 miles of a marine zone, it suggests a default radius of 25 miles. For inland stations, it leaves the radius at 0.
- **Stored zone IDs:** `marine_alert_zone_ids` (list of strings) — discovered once at setup, stored in config

### Zone discovery algorithm (at setup time)

1. Station lat/lon → NWS `/points/{lat},{lon}` → extract `cwa` (WFO office ID)
2. Fetch all coastal marine zones for that CWA: `GET /zones/coastal` filtered by CWA → typically 6–16 zones
3. For each zone: `GET /zones/coastal/{zoneId}` → extract polygon geometry
4. Compute minimum haversine distance from station to each polygon's nearest vertex
5. Select zones within the operator's configured radius
6. Present discovered zones with names and distances to the operator for confirmation
7. Store confirmed zone IDs in `api.conf`

**Verified results (July 2026):**
- Wilmington NC at 25 miles: 2 zones (Surf City–Cape Fear nearshore, Cape Fear–Little River nearshore)
- Wrightsville Beach at 25 miles: 2 zones (same nearshore + 20–60nm offshore)
- Raleigh NC at 25 miles: 0 zones (correctly excluded)

### Alert query changes — all three providers

**NWS provider (`providers/alerts/nws.py`):**
- After the existing `?point=` query, check if `marine_alert_zone_ids` is non-empty
- For each configured zone: `GET /alerts/active?zone={zoneId}`
- Merge results with point-based results
- De-duplicate by alert `id` field
- Same `ProviderHTTPClient`, rate limiter, and cache infrastructure

**Xweather provider (`providers/alerts/aeris.py`):**
- Test whether Xweather returns marine alerts for the station's point (expected: no, for stations > ~1 km from water)
- If not: add supplemental NWS `?zone=` query for each configured marine zone
- NWS marine zone alerts are free and always available — this is a supplemental data source, not a provider switch
- Merge and de-duplicate by alert ID

**OWM provider (`providers/alerts/openweathermap.py`):**
- Same approach as Xweather: test first, supplement with NWS zone query if needed

### NWS zone taxonomy

| Zone type | Prefix examples | What it covers | How captured |
|---|---|---|---|
| Public zones | NCZ, CAZ, FLZ | Land-based coastal areas. Beach Hazards Statement, Coastal Flood Advisory/Warning, Storm Surge. | Existing `?point=` query (when station is in a coastal county) |
| Coastal marine zones | AMZ, GMZ, PZZ, ANZ, PKZ, PHZ | Nearshore waters out to 20–60 NM. SCA, Gale, Storm, Hurricane Force, Hazardous Seas, Dense Fog (marine), Special Marine Warning, Low Water Advisory. | **This ADR's zone queries** (required for any station not directly on the waterline) |

## Consequences

- **General alerts improvement** — all coastal stations benefit, not just marine-enabled ones.
- **Settings change:** Two new fields in station/alerts config: `marine_alert_radius_miles` and `marine_alert_zone_ids`.
- **NWS alerts provider modification:** Additional zone queries when configured. Shared rate limiter (5 req/s to api.weather.gov).
- **Xweather/OWM providers:** May need supplemental NWS zone queries (test during implementation).
- **Zone discovery utility** (`providers/_common/nws_zones.py`): Shared with NWS marine text forecast provider (ADR-083 T1.4) and NWS SRF provider.
- **Wizard/admin change:** Marine alert radius field in the alerts section (not the marine section). Zone discovery + confirmation UI.
- **Cache:** Zone-based queries cached separately from point-based queries. Same TTL (5 min for alerts).
- **Zero-config behavior preserved:** `marine_alert_radius_miles = 0` (default) → no zone queries → identical behavior to current implementation.

## Acceptance criteria

- [ ] NWS alerts provider with configured marine zone IDs makes additional `?zone=` queries and returns marine alerts
- [ ] NWS alerts provider with no configured marine zones behaves identically to current implementation (zero regression)
- [ ] De-duplication by alert ID — same alert from point and zone queries appears once in output
- [ ] Xweather/OWM providers supplement with NWS zone queries when their point-based results miss marine alerts
- [ ] Zone discovery returns correct zones for test points (Wilmington NC → AMZ250 zone family, Raleigh NC → 0 zones)
- [ ] Wizard auto-suggests 25-mile radius when station is within 50 miles of a marine zone
- [ ] Existing alerts test suite passes unchanged when `marine_alert_radius_miles = 0`
- [ ] Marine zone alerts appear in the dashboard's standard alert banner alongside all other alerts

## Implementation guidance

- **Settings:** Add `marine_alert_radius_miles: float = 0.0` and `marine_alert_zone_ids: list[str] = []` to `services/settings.py` station config. Load from `api.conf` `[alerts]` section.
- **NWS provider:** In `providers/alerts/nws.py` `fetch()`, after the existing point query, iterate `marine_alert_zone_ids` with `GET /alerts/active?zone={id}`. Merge and de-dup. Cache key: `(provider_id, "zone", zone_id)` — distinct from point cache key.
- **Zone discovery:** `providers/_common/nws_zones.py` — `discover_marine_zones(lat, lon, radius_miles) -> list[MarineZone]`. Each `MarineZone` has `zone_id`, `name`, `distance_miles`. Used at wizard/admin time, not per-request.
- **Haversine:** Use the existing haversine utility if one exists, or implement the standard formula. Accuracy to ~0.1 miles is sufficient.
- **Wizard/admin help content for the marine alert radius field:** Explain what the radius does (discovers nearby NWS marine zones for alerts like Small Craft Advisories), why it matters (point-based alert queries miss marine zones for inland stations), and provide the NOAA Weather Radio reference as a practical guide: "NOAA Weather Radio transmitters are positioned so marine forecasts and warnings reach approximately 40 miles inland from the coast — if your station is within that range, you're in the audience NWS considers close enough to need marine alerts. The default suggestion of 25 miles captures most coastal communities; increase it if your station is further inland but still serves a coastal audience."
- **Out of scope:** Dashboard marine page alert routing/filtering by activity type (Phase 7). Marine page design (Phase 7). This ADR modifies the general alert system only.

## References

- NWS API: [api.weather.gov](https://api.weather.gov)
- NWS marine zone map: [weather.gov/marine/AllZones](https://www.weather.gov/marine/AllZones)
- NOAA Weather Radio marine coverage: [weather.gov/marine/wxradio](https://www.weather.gov/marine/wxradio) — transmitters cover ~40 miles inland, establishing NWS's own threshold for marine alert relevance
- NWS marine zone expansion to 60 NM: [weather.gov/ilm/marinezoneexpansion](https://www.weather.gov/ilm/marinezoneexpansion)
- Related ADRs: ADR-016 (severe weather alerts), ADR-052 (geography-correct alert severity model), ADR-083 (domain architecture), ADR-090 (capability matrix — marine alerts routing)
- Research: `docs/planning/briefs/MARINE-SURF-FISHING-RESEARCH-BRIEF.md` §5.5 (NWS marine zone forecasts)
