# Fishing and Boating Remediation Plan — 2026-09-05

**Status:** APPROVED — operator-approved 2026-09-06. Audit, design, and
implementation proceed under this plan; phase gates remain required.

**Plan approval is architectural approval:** Once approved by the operator, this plan authorizes every architectural change explicitly described in its execution phases and aligned manuals. Those listed changes do not need a second, separate approval. Any proposed change outside this plan remains subject to the repository's architecture gate.

**Scope:** Restore useful, truthful Fishing and Boating tabs for the Huntington Harbour location, then prove the result against live data. This plan covers the unified marine service, the API proxy/enrichment seam, the dashboard, and governing documents. It does not change the marine wave model.

**Current live target:** [Huntington Harbour](https://weather.shaneburkhardt.com/marine), location ID `huntington-harbor`.

**Execution update — 2026-09-09:** The API, Marine service, and dashboard
changes required for the live Fishing depth-profile repair are deployed. The
Marine service is running the updated source; focused deployed checks passed
with 35 tests and 2 non-failing deprecation warnings. Live Huntington Harbour
evidence confirms that public Marine responses omit the private profile field,
the private service-to-service response carries timestamped WCOFS depth layers,
and Fishing uses an eligible 12 m layer for Kelp bass when all core inputs are
available. Raw evidence is retained under
`scratch/fishing-boating-remediation-2026-09-06/`.

This does not close the plan. Gate 1 remains open pending independent
verification of the documentation reconciliation that records the operator's
resolved matrix-row contract; Gate 5 remains open because the required
live browser session was unavailable; and Phase 6 requires the remaining
cross-provider, browser, and operator visual evidence.

## 1. Outcome

Visitors can use either tab without interpreting incomplete data, recycled observations, or opaque scores.

- **Boating** presents the same time-oriented forecast construction used by the regular Forecast page, with boating-relevant rows added. Its nearshore weather comes from station hardware when the location is within the configured station-service radius, otherwise from the configured forecast provider at the location coordinates. NWS marine-zone periods supply the additional marine rows—regional wind, seas, visibility, and marine-weather narrative—after their text is parsed and matched to the correct time columns; they do not replace location weather. It distinguishes both from offshore buoy observations. For a protected harbour, the buoy card is explicitly navigation context for a boat leaving or travelling beyond the harbour; it is never labelled or used as wave conditions at the selected point.
- **Fishing** presents a time-oriented, three-day forecast built from time-matched inputs. The current score and each species score state which inputs were available, never claim a pressure trend when none was measured, and never silently replace unavailable data with a scientifically meaningful-looking score.
- The Fishing solunar card matches the Almanac card's visual structure and complete information set. It may reuse, extract, or duplicate implementation code; the fishing-specific addition is the major/minor feeding-period overlay, not a reduced substitute for the Almanac card.
- Both tabs remain location-first under `/marine`; no new standalone route is assumed.

## 2. Verified live audit — 2026-09-05

The following observations came from the live dashboard and its public API, not fixtures.

| ID | Evidence | Finding | Consequence |
|---|---|---|---|
| FB-01 | `GET /api/v1/marine/huntington-harbor` | Source is `ndbc+nws_marine`; `forecast` is empty and `textForecast` contains 11 NWS zone-text periods. The response exposes parsed prose fields (`wind`, `seas`, `visibility`, `weather`) but no period start/end. | Boating has no time-matched forecast. The intended parsed NWS marine fields cannot be joined to the regular forecast columns because their validity windows were discarded, and the UI renders them as a disconnected text panel instead. |
| FB-02 | Same response | Current observation has wind `14 kt WSW`, gust `15 kt`, and water temperature `75.1°F`, but air temperature, dewpoint, visibility, pressure, pressure tendency, weather code, and wave fields are null. | The Boating current-conditions card truthfully renders blanks, but it fails the expected local-conditions ensemble. |
| FB-03 | `GET /api/v1/fishing/huntington-harbor` | It returns three days × six periods, but all 18 periods reuse one current buoy wind observation. `swellHeight` and `swellPeriod` are null in every period. | The Fishing "forecast" is not time-matched weather or sea-state data. |
| FB-04 | Same response plus live NDBC `PRJC1` report | Current period: overall 42, pressure 50, tide 30, solunar 30, time 70; `waterTempScore` is null; condition sentence says “pressure trend unavailable.” `PRJC1` supplies wind but reports pressure and `PTDY` as missing. | The endpoint incorrectly lets an offshore station without pressure determine the Fishing pressure input, rather than using the location's normal source fallback. It then converts that missing input into 50 points. Water temperature affects species internally but is invisible in the score breakdown. |
| FB-05 | Same response | Current species results: 22 inactive, 1 less active; the top score is 30. | The output is not interpretable enough to establish whether conditions are genuinely poor or the scorer's multiplier chain suppresses all species. |
| FB-06 | Live rendered Fishing tab | The page uses a bespoke solunar arc/timeline and a dense table-style Species Forecast. | It does not meet the requested reuse of the Almanac card/code, and the species view does not read as a forecast card. |
| FB-07 | Live rendered Boating/Fishing tabs | The tabs are vertically long and the app shell scrolls the main region independently of the footer. | This is expected shell behavior, not yet proven clipping. The visual review must explicitly test keyboard, wheel, and touch access to every card before calling it a layout defect. |
| FB-08 | Deployed marine service at `librewxr.shaneburkhardt.com`, revision `25b5807` | The running service matches the audited checkout. At audit time it was degraded for an unrelated WW3 restart issue. | This plan must not depend on Clear Skies model output. Buoy and forecast data verification remains possible while model recovery is separate. |
| FB-09 | Forecast-provider and canonical-model audit | `HourlyForecastPoint` has no pressure field. Xweather and OpenWeatherMap adapters parse raw pressure but drop it before canonical output; Open-Meteo does not request it; NWS exposes a current-observation pressure field only. | The API cannot currently provide a provider-agnostic hourly pressure series for Fishing or any other consumer. |
| FB-10 | NWS gridded-pressure audit | NWS exposes a possible `pressure` grid layer, but the live Huntington Harbour grid returned no pressure values. Availability is location-specific. | Fishing setup needs a real per-location NWS pressure-series check and must block Fishing for a location whenever the selected provider does not return the required data. |

## 3. Backend audit findings

### 3.1 Fishing endpoint is not a forecast assembler

`weewx_clearskies_marine/endpoints/fishing.py` fetches one NDBC observation and one CO-OPS tide set before its three-day loop. It then passes that same water temperature, pressure tendency, wind speed, wind direction, and gust into every period. It never passes a swell height or period to `score_fishing()`.

This directly explains the repeated 14 kt / WSW / 15 kt values and missing wave fields in the live response. It also means the fishing score changes mostly because of tide, solunar period, and time-of-day, not because future weather or marine conditions change.

### 3.2 Pressure-source fallback is missing

Huntington Harbour is 12.30 km from the weather station, outside the configured 2.5 km station-service radius. Its normal local-weather source is therefore the configured forecast provider at the Harbour coordinates, not the wind-only NDBC station `PRJC1`. The Fishing endpoint bypasses that fallback and reads pressure tendency only from the first NDBC station.

**Operator direction, 2026-09-05:** pressure trend follows the same locality rule as other nearshore weather: derive the three-hour delta from the weewx archive when station-served; otherwise derive it from the configured forecast provider's time-matched pressure series at the marine location. NDBC remains an offshore observation source and must not determine whether a Harbor score has pressure.

`fishing_scorer._score_pressure(None)` returns 50. Once the restored source path is proved, missing pressure becomes a genuine exceptional-data case rather than the normal Harbour state; its eventual user-facing semantics remain a scientific-scoring decision.

### 3.3 The deployed score formula diverges from the archived five-factor model

The current scorer uses four shared weights: pressure 37.5%, tide 31.25%, solunar 18.75%, and time of day 12.5%. It removed the shared 20% water-temperature factor and redistributed its weight. It then calculates each species as:

```text
shared weighted score
× pressure-sensitivity coefficient
× temperature multiplier
× tide-preference multiplier
× time-of-day multiplier
× seasonal multiplier
```

The archived ADR-088 describes a five-factor environmental model with temperature as 20% of the environmental score. The Dashboard Manual describes the deployed four-factor display. This is a real governing-document/algorithm disagreement, not a display issue.

At Huntington Harbour, the current overall 42 derives from `50×0.375 + 30×0.3125 + 30×0.1875 + 70×0.125 = 42.5`, rounded to 42. A species with a 0.5 pressure-sensitivity coefficient begins near 21 before other multipliers. This mechanism explains why many species are below the 30-point “less active” threshold even with a fair shared score; it does not establish that the formula is scientifically appropriate.

### 3.4 No scorer or endpoint verification exists

The marine test tree has a regional-classification test and a static `golden_fishing.json` fixture, but no test imports `score_fishing()`, calls `/fishing/{locationId}`, or verifies pressure, temperature, seasonal, tide, or period-input behavior. The fixture is not referenced by a test. Thus neither the score formula nor individual species outputs have been meaningfully verified.

### 3.5 Species source quality is mixed and unvalidated

`data/species.yaml` contains per-species comments, including FishBase, NOAA, CDFW, papers, and fishing-guide sources. The audit found no machine-readable evidence record, source-date validation, or test that proves every configured Huntington Harbour species has a profile supported by the cited material. This is an evidence-quality gap, not grounds to change any coefficient without approval.

### 3.6 Approved Fishing-score structure

The Fishing score is rebuilt around the original fishing research and the accepted lesson from the Surf-score rebuild: a truly bad core condition must not be hidden by unrelated favorable conditions.

1. **Hard stops apply first.** A species outside its approved active temperature range is inactive; no favorable tide, moon, or time of day may turn that into an active forecast.
2. **There is no generic Fishing score.** A generic score would imply that one water temperature, tide, pressure response, and seasonal state mean the same thing for every fish. The shared Current Conditions card reports the actual conditions, but does not rate fishing conditions.
3. **The selected-species score is the only Fishing score.** A species-selection strip sits at the top of the Fishing tab and controls the forecast that follows. Its per-species water-temperature suitability, pressure response, and tide/current suitability form a weighted geometric environmental core. This makes a seriously poor core condition pull the result down instead of being offset by a good unrelated factor.
4. **Pressure sensitivity changes response, not baseline worth.** It shapes how strongly a species responds to a pressure trend. It is never a permanent multiplier that reduces every score, including under stable or favorable pressure.
5. **Time of day and seasonal behavior are bounded species-specific adjustments.** They refine viable conditions; they do not rescue an environmentally unsuitable period.
6. **Solunar is a bounded tiebreaker.** It may refine otherwise favorable conditions but must not create a strong Fishing forecast when core environmental suitability is poor.
7. **Every displayed result is explainable.** The response and page expose the core factors, hard-stop reason when present, and each applied species adjustment. The visitor can see why a species is active, less active, or inactive.

### 3.6.1 Fixed selected-species formula

This formula is part of this plan's architectural approval. Phase 2 verifies species evidence against it; it does not invent substitute constants during implementation.

#### Step 1 — required data and hard stops

- A depth-appropriate water temperature outside the species' approved active range sets the selected species score to **0** and status **Inactive**.
- A missing required live core input withholds the Fishing score. The API uses the documented best available eligible data source, but if target-depth temperature, tide/current, or pressure remains unavailable, score, status, core, and suitability fields are `null`. The service logs the location, period, missing input, and source/provenance at warning level; this log record is not exposed as a visitor-facing explanation. Setup still prevents Fishing from being enabled when the selected forecast provider cannot supply the pressure series. A runtime outage is not converted into a fallback score.

#### Step 2 — environmental core

Each remaining core factor is a number from 0 to 1. The selected-species environmental core is:

`core = 100 × temperature^0.50 × tide_current^0.30 × pressure^0.20`

| Factor | Fixed mapping | Basis |
|---|---|---|
| `temperature` | optimal range `1.00`; good range `0.80`; marginal-but-active range `0.45`; outside active range `0.00` hard stop | Temperature is the strongest supported input. The range is evaluated at the species' documented habitat depth. |
| `tide_current` | source-backed preferred state `1.00`; source-backed acceptable state `0.70`; source-backed poor state `0.40` | Tide/current response is local and species-specific. Every scored profile must classify the relevant states; no universal "outgoing is best" rule exists. |
| `pressure` | Apply the selected species' pressure sensitivity to its researched falling, stable, and rising pressure multipliers. | Pressure direction is a species-profile input; falling, stable, and post-front rising conditions are not collapsed into one magnitude-only value. |

The selected profile supplies the three pressure multipliers and a sensitivity from `0` to `1`. The scorer applies the multiplier selected by the signed three-hour trend, with stable applying when the absolute change is below `1 hPa`.

The temperature and tide/current mappings express the research hierarchy. The geometric exponents, the pressure bands, and the tide/current levels are explicit **product judgments**: they make poor core conditions materially constrain the result without claiming that a universal biological equation supplied those exact numbers.

#### Step 3 — bounded refinements

Only after a valid core exists, apply the selected species' documented refinements:

- Time of day: preferred `1.10`; normal `1.00`; low-activity period `0.90`.
- Season: documented peak `1.15`; normal `1.00`; documented lower-activity season `0.85`.
- Solunar: the selected profile supplies major and minor multipliers, an active-tide alignment multiplier, and a full-moon multiplier. These are bounded refinements and never rescue a poor environmental core.

`final = min(100, core × time_of_day × season × solunar, core + 10)`

The `core + 10` ceiling and the status rule below stop time, season, or solunar from rescuing a poor core. The lookup row must contain the applicable researched direct or approved FAO-area fallback treatment for each adjustment. A normal `1.00` treatment is stored explicitly when that is the researched result; runtime never converts an unfinished or blank matrix field into `1.00`.

#### Step 4 — status and explanation

| Result | Status |
|---|---|
| temperature hard stop | Inactive |
| final `65–100` **and** core at least `55` | Active |
| final `35–64` | Less active |
| final below `35` | Low activity |

The forecast exposes the final score, useful fishing factors, pressure trend, every applied refinement, water-temperature context, and any hard-stop reason. Fallback derivation remains in setup/help documentation, not the visitor-facing page. It does not expose or calculate an `overallScore` / General Conditions score.

### 3.6.2 Global fishing lookup and setup filtering

The catalogue is one global operational lookup table, not a research database
and not a collection of regional lists. Each editable row is exactly one
global selectable species or existing practical-category profile, carries every
applicable FAO area in its `fao_areas` field, and has one fishing type. The
deterministic export expands each listed area into one exact
`(selection_key, fao_area, fishing_type)` runtime row; the workbook row is not
repeated once per FAO area. The editable row contains only the identity and
scoring inputs that setup and the Fishing scorer consume. Section 11 defines
the workbook contract and the recovery source for reconstructing it.

Before any source taxon is eligible for this matrix, screen its current global
IUCN Red List category. Exclude `critically_endangered`, `endangered`, and
`vulnerable` taxa. Retain `near_threatened` taxa with the operational
`near_threatened` flag so the operator can see the status. Detailed assessments,
source URLs, and research identifiers do not belong in the operational lookup
table. Do not flag other IUCN outcomes. This global conservation screen does
not alter the Fishing scoring formula. It applies
to exact source members before any practical-label collapse: a familiar group
is retained only when the non-excluded, locally eligible members still have
matching complete profiles.

Every selectable choice receives a complete effective profile through this fixed
fallback order: its own FAO-scoped profile; the existing matching practical
category in that FAO area; then the matching functional fishing category in
that FAO area. A functional category is specific to both the FAO area and the
fishing type—for example, rockfish in that area or bottom fish in that area.
There is no worldwide default and no general regional-fishing fallback.
These are runtime lookup steps: the exact-area row is generated from a global
workbook profile, and no additional per-area editable profile row is created.

During setup, the API resolves the operator's location to an FAO area and
filters the lookup table by that area and the selected fishing type. The
dashboard receives only the resulting practical choices and never performs
geographic eligibility or fallback logic. Broad labels such as `rockfish`,
`grouper`, `halibut`, `trout`, and `catfish` remain valid practical categories;
they are not re-litigated or removed merely because later research is
incomplete. A category is removed by the Red List screen only when every exact
source species beneath it is excluded. The product does not evaluate fishing
legality; the operator determines availability outside the score.

### 3.7 Location- and depth-appropriate water temperature

Fishing does not use one offshore surface reading for every species. The API resolves water temperature at the fishing location in this order: a genuinely nearby local sensor, the regional ocean model, satellite or broader ocean-model fallback, then a labeled buoy or tide-station observation only as a last resort.

The shared Current Conditions card displays the resolved surface-water temperature and its freshness/provenance. The Fishing forecast uses the water-column temperature appropriate to the selected species and its habitat depth when the ocean data provides it. A missing local water column must remain visible as missing; it is never silently replaced by an offshore buoy reading.

## 4. Governing intent recovered from prior plans and manuals

- ADR-090 makes the capability matrix the contract. For Boating it requires wave data, NDBC observations, tide predictions, and an NWS marine-zone forecast. NWS text periods carry the regional wind/seas/visibility/marine-weather additions to the regular forecast construction; they cannot substitute for the location-aware weather forecast itself.
- ADR-091 explicitly records that NDBC-only cards yielded missing pressure/air temperature/wind fields and identical offshore readings. Its acceptance criteria require station hardware or a forecast provider for wind/air temperature, plus location-appropriate ocean data. The live Harbour response is still in that failure state.
- The Dashboard Manual §12 requires Boating to expose a complete conditions ensemble, wave forecast, tide forecast, and structured marine text forecast. It requires Fishing forecast periods to carry score, species, solunar state, wind, gust, swell height, and swell period.
- The same manual requires the Fishing solunar card to use the Almanac moon-phase component and the visual language of `SunMoonDetailCard`. The present fishing tab has a reduced bespoke arc/timeline that fails to display the Almanac card's information and structure. Code duplication itself is not the defect.

## 5. Provider compatibility requirement

Fishing requires a provider-neutral, hourly mean-sea-level-pressure series so the API can calculate a real three-hour pressure trend at each fishing location.

- **NWS pressure support is location-specific.** Its gridded pressure layer may be absent, including at Huntington Harbour. When NWS is selected, setup must check each fishing location's real grid response. A missing hourly pressure series blocks enabling or saving Fishing for that location and tells the operator to choose a forecast provider that supplies the series there. This is not a blanket block on NWS.
- **API provider information must expose the rule.** Provider metadata and setup help must state whether the selected provider supports the required Fishing pressure series. This must be a machine-readable compatibility fact, not buried prose.
- **The setup flow must enforce it.** The provider-selection step and the marine/fishing-location step both show the live per-location result, block an invalid Fishing configuration, and explain that the operator must choose a provider supplying hourly pressure for that location.
- **The eventual hourly-pressure field stays provider-neutral.** Each eligible provider maps its own upstream value into the API's single canonical series. The dashboard and Fishing page do not see provider-specific fields or provider names.

## 6. Fixed implementation rules

- The dashboard receives normalized API data and never selects providers or assembles source data.
- Nearshore weather uses station data within the existing station-service radius and the configured forecast provider otherwise.
- NWS marine periods augment matching forecast columns; offshore buoy observations remain a separately labeled route/exit reference.
- Fishing uses the score structure in §3.6 and the water-temperature rule in §3.7.
- Any required data-contract, provider, configuration, or formula change is documented in the manuals before code and remains subject to the repository architecture gate.
- Real provider records and live rendered/API output establish whether an implementation is correct. Automated tests protect that established behavior against regression; they never define the desired outcome or substitute for live evidence.

## 7. Execution phases after approval

### Pre-phase — Freeze evidence

**Owner:** coordinator. **No implementation.**

1. Save redacted live response fixtures for Huntington Harbour: `/marine/{id}`, `/tides/{id}`, `/fishing/{id}`, regular `/forecast`, and the nearest configured buoy observation, all with timestamps and source identifiers.
2. Produce a source-to-field ledger: every displayed value, its provider, location, observation/forecast status, valid time, units, and fallback.
3. Build a scorer truth table from the currently deployed formula. Include pressure thresholds, tide states, solunar states, time buckets, temperature-band boundaries, each seasonal rule, and every Huntington Harbour species.
4. Capture the pre-change documentation state and current source/response contract for each affected manual.

**Acceptance:** Every value in the current live Harbour tabs has a recorded provenance or an explicit “unavailable” designation, and the documentation baseline identifies every statement that would conflict with this plan.

### Phase 1 — Manuals and contract alignment before code

**Status:** Documentation alignment and a subsequent source audit are complete
through 2026-09-09. The target-state architecture, manuals, OpenAPI contract,
provider pressure requirement, NWS location check, and later-phase evidence
sheets have been updated. The operator resolved the matrix-row contract on
2026-09-09: the sole editable workbook table has one global
species/practical-category profile row, one fishing type, and a `fao_areas`
list; deterministic generation expands that list into exact runtime
`fao_area` rows. Gate 1 remains open pending independent verification of this
documentation reconciliation; no other phase or gate status changes here.

**Owner:** documentation lead. **No implementation code.**

1. Update `ARCHITECTURE.md`, `API-MANUAL.md`, `PROVIDER-MANUAL.md`, `DASHBOARD-MANUAL.md`, and the OpenAPI contract to the approved target behavior before any code phase begins. Clearly tag not-yet-shipped behavior rather than claiming it is live.
2. Document the provider-neutral hourly-pressure requirement, the NWS per-location Fishing block, NWS marine-period time alignment, the source-to-field rules, and the Boating/Fishing card contracts from this plan. The shared Current Conditions contract explicitly defines air temperature, feels-like temperature, humidity, dew point, wind/gust/direction, pressure and trend, visibility, weather state, water temperature, tide/current-water-level context, update time, source/provenance, and null behavior. It states whether the card is one normalized payload or identified fields from named API responses; the dashboard never performs source selection. The Fishing setup-selection contract defines the one-table global lookup in Section 11, its score-affecting fields, FAO-area/fishing-type filter, permitted fallback order, and practical choices returned to the dashboard.
3. Remove or correct every manual statement that contradicts the planned Fishing score structure, protected-harbour buoy treatment, or surf-only model-wave rule.
4. Create the exact file allowlists, implementation instructions, and acceptance evidence for each later phase from these aligned manuals. Every later phase receives an evidence sheet stating its real-host command, timestamped input, expected output, raw-output record, and the limit of what that check can prove.
5. Document the matrix storage boundary: the signed-off `.xlsx` table is the
   sole human-edited source; a deterministic export produces the packaged,
   read-only SQLite runtime database; neither the API nor marine service parses
   Excel at runtime; and the existing YAML loader is retired only after
   equivalence and live behavior are proved. Document the tracked paths,
   generation command, packaging behavior, read-only connection, indexes, and
   failure behavior before Phase 4 implementation.

**Acceptance:** The manuals and contract describe one non-conflicting target design, including the Excel-to-SQLite boundary; no implementation brief requires an agent to choose between the plan and a manual.

### Phase 2 — Fishing matrix reconstruction and formula test design

**Owner:** coordinator. Research agents supply bounded facts; they do not design
the matrix, decide the methodology, edit the workbook, or reinterpret existing
practical categories. **No production formula changes.**

**Workbook reconstruction and population: COMPLETE 2026-09-07.** The approved
single-table workbook has 191 complete exact-species global profile rows. It contains no
generic, proxy, or unresolved-species-complex rows; no fishing-legality data;
and no required operational blanks or duplicate keys. The scope is Great Lakes
freshwater plus world oceans and seas. This completion covers the workbook,
research-population portion, and Item 9 scorer known-answer design. The
independently calculated cases are recorded in
`docs/planning/briefs/FISHING-SCORER-KNOWN-ANSWERS-2026-09-07.md`, with the
dynamic pressure-trend weighting research in
`docs/planning/briefs/FISHING-PRESSURE-TREND-SPORT-FISHING-RESEARCH-2026-09-07.md`.

1. Preserve the intact staged workbook named in Section 11 as a read-only
   recovery source. Extract its existing usable lookup values without copying
   its worksheet structure, queues, evidence tables, or status machinery.
2. Build the framework workbook defined in Section 11 with exactly one table
   and one fully populated representative global profile row: black sea bass,
   with `fao_areas` containing FAO area 21 and fishing type `bottom`. Populate
   every operational field in that row, including the applicable conservation
   result, using the approved value meanings and units. Do not add any other
   species/profile rows yet.
3. Render the framework table, explain every column in plain English, and stop
   for the operator's explicit sign-off on the table structure, row meaning,
   column names, units, allowed value codes, and layout. A successful file
   export or internal review is not approval. Do not begin bulk recovery,
   further research, or population until the operator approves this exact
   framework in chat. If corrections are requested, revise the same framework
   and present it again; do not create workbook variants.
4. After operator sign-off, reconcile later completed research from the surviving task results and
   import scripts, then identify only the operational lookup fields that still
   require research. Do not use a research queue, blank source identifier, or
   profile-status label as proof that research is missing.
5. Complete the remaining research one fish or practical category at a time.
   Before every assignment, the coordinator supplies the applicable FAO
   area or areas, fishing type, required output fields, units or allowed value
   codes, source scope, existing values to preserve, and the required global
   profile-shaped return format. The agent may not change the field list,
   challenge the category, redesign the scoring method, or return a general
   essay instead of values or area coverage.
6. Use practical sport-fishing sources for behavioral and fishing-outcome
   fields: regional magazines, fishing publications, charter and guide reports,
   angler logs, creel or tournament results, and established fishing blogs.
   Use fisheries agencies, FAO, FishBase, IUCN, and other authoritative sources
   where range, taxonomy, geographic presence, or conservation
   status requires them. Do not reject an operator-approved source class by
   substituting a stricter academic standard.
7. Enter each returned research packet into the one operational table and
   verify that exact global profile row, its `fao_areas` list, units, and codes
   before assigning another fish. A research report that is not applied to the
   table is not progress. A narrow unsuccessful search is not proof that a
   value is unavailable; broaden or reassign the search and keep the field
   marked unfinished. Deterministic generation separately verifies that area
   expansion produces unique runtime keys.
8. Complete the exact-species IUCN Red List screen defined in Section 11 before
   finalizing the selectable rows. Do not apply a Red List category directly to
   a practical group and do not remove a group unless every exact source species
   beneath it is excluded.
9. Produce the hand-calculated known-answer cases for the fixed formula:
   pressure states, tide/current states, temperature boundaries, seasonal
   activity, time and solunar refinements.
   These cases verify the scorer design; they are not additional workbook
   sheets.

**Acceptance:** The reconstructed workbook contains exactly the one table
defined in Section 11. Every required operational field is populated in every
selectable global species/category profile row; each row has one fishing type,
no duplicate entry in its `fao_areas` list, and deterministic expansion
produces a unique `(selection_key, fao_area, fishing_type)` runtime key for
each listed area. No United States regional list or region key remains;
practical categories and Red List decisions follow the stated rules; and
every returned research result has been applied. Independent review verifies
the table contents, the area-expansion key set, and known-answer arithmetic
without adding research, provenance, queue, or quality-control structures to
the workbook.

### Phase 3 — Truthful location data assembly

**Depends on:** Phases 1 and 2.

**Status:** Implementation is deployed. Real-host Gate 3 evidence confirms
provider-neutral Aeris pressure with valid times, timestamped WCOFS target-depth
temperature, CO-OPS tide provenance, timed NWS marine additions, and separately
labelled NDBC offshore observations. The live NWS pressure check truthfully
reports no hourly pressure series at Huntington Harbour; Open-Meteo returned
real pressure data but is not the configured live provider, and OpenWeatherMap
has no configured credential. The previously open NWS setup-save check is now
proven: on 2026-09-09 an authenticated in-memory NWS Fishing
`POST /setup/apply` returned HTTP 422 before any configuration or secret
persistence, naming Huntington Harbour's unavailable hourly pressure series.
Provider-neutral hourly pressure is
carried by Xweather, Open-Meteo, OpenWeatherMap, and the location-specific NWS
grid check. The API assembles location forecast rows, source/provenance, and
the authenticated time-matched scorer input; NDBC remains a separately labelled
offshore observation and is rejected as a local Fishing input. CWF labels map
only to matching regular forecast columns, with explicit UTC bounds and
issuance provenance; unmatched labels remain unavailable. Local guards cover
the source boundaries, CWF matching, and unavailable states. Independent source
review passed after remediation; the correct-host live-provider evidence is
still required.

1. Add the provider-neutral hourly mean-sea-level-pressure series to the forecast contract. Map it across every eligible forecast provider, including source/unit/provenance behavior. Do not add it only for Xweather.
2. Restore the settled nearshore-weather source rule: where `is_station_served(location.id)` is true (currently the configured 2.5 km radius), use station hardware for current wind, direction, gust, air temperature, humidity, dew point, pressure, and any station-supported visibility/feels-like value; otherwise use the configured forecast provider at the marine location coordinates. Derive the Fishing three-hour pressure delta from that same station archive or approved location forecast-provider time series. Obtain weather code/is-day state and any non-station current-condition field from that forecast provider. Preserve field-level source/provenance and null when neither approved source provides the value. Do not let NDBC determine the availability of local weather or Fishing pressure.
3. Resolve location-specific **surface** temperature through the established ocean-data hierarchy, with a labeled buoy/tide-station observation only as a last resort for the shared Current Conditions display. Resolve Fishing's target-depth water-column temperature only from a source that provides that depth. A surface buoy or tide-station reading never substitutes for a missing target-depth value; the selected species reports the core factor as unavailable according to the approved formula.
4. Assemble current observations, hourly forecasts, tide predictions, and buoy waves as separate, time-stamped inputs rather than one current observation copied through three days.
5. Populate existing nullable forecast wind/gust/wave fields only from the approved source, with correct units and provider attribution. Preserve null when the source does not provide that value.
6. Add Boating's separate Offshore Observations card from multiple suitable nearby buoys. Reuse the existing `GET /setup/marine/discover-stations` discovery and the existing multi-value `ndbc_station_ids` location setting; do not build a second buoy-discovery mechanism. Setup/admin presents the discovered distance and sensor capability, lets the operator confirm or adjust the selected list, and the card shows each selected station's identity, distance, timestamp, and supplied measurements. State its route/exit purpose and non-local limitation in the card itself. Do not feed it into harbour-point wave conditions or silently substitute it for missing local data. Distinguish three states: no buoy selected, selected buoy with no current observation, and unavailable discovery/observation service; a failed service must never look like an intentionally empty card.
7. Preserve the NWS marine-zone period validity window, parse its wind/seas/visibility/marine-weather information, and add only those values to the matching regular-forecast time columns. Label these additions as regional marine forecast data; do not overwrite the location-weather provider's values.
8. Add provider compatibility information to the API and setup help. When NWS is selected, perform a real pressure-series check for every fishing location. Block enabling or saving Fishing when the series is unavailable and suggest changing forecast provider in plain English.
9. Add focused automated regression guards for source mapping, observation reuse, NWS validity-window assignment, provider-neutral hourly pressure, the NWS per-location block, target-depth temperature handling, and Offshore Observations empty/error states. These guards may use controlled inputs but do not establish acceptance. Gate 3 separately reruns the documented real-host command against live provider data and records the raw API result.

**Acceptance:** Three consecutive future periods can demonstrate distinct time-matched source values when the forecast changes; the Offshore Observations card identifies every buoy, its distance, observation time, and non-local limitation; unavailable harbour-point fields stay unavailable and explained.

### Phase 4 — Fishing scorer and species implementation

**Depends on:** Phases 1–3.

**Status:** Implementation is deployed and the focused known-answer guard now
passes on librewxr. Live evidence verified read-only SQLite access, required
index use, workbook/database value equivalence, no global runtime catalogue,
hard stops, null-on-missing-core-input behavior, selected-species scores, and
time-matched target-depth WCOFS input. The generated SQLite matrix,
read-only selected-profile lookup, FAO resolver, authenticated API-to-marine
time-matched input handoff, selected-species request, and approved scorer are
implemented. The scorer uses the fixed geometric core, discrete
falling/stable/rising profile pressure response, hard stops, bounded refinements,
and selected-species-only output. Known-answer guards cover the formula,
selection, provenance, missing core inputs, depth-qualified temperature, and
no-generic-score behavior. Gate 4 remains open pending resolution of the
matrix-row contract conflict and full gate synthesis.

1. Implement the Fishing-score structure in §3.6: hard stops, weighted geometric environmental core, species-specific pressure response, bounded time/season adjustments, and solunar tiebreaker.
2. Generate the Section 11 SQLite database from the signed-off and completed `.xlsx` table. Implement a narrow read-only lookup layer over its single data table. Setup queries by FAO area and fishing type and returns only the eligible practical choices. Forecast scoring queries only the configured exact-area runtime rows and approved fallback rows needed for that request. Do not load the full database into module-level dictionaries, parse Excel at runtime, or create parallel research, evidence, taxonomy, queue, or profile tables. The staged recovery workbook is never deployed or queried at runtime.
3. Add the known-answer regression guards designed in Phase 2, endpoint integration checks, profile coverage validation, and a saved live-Harbour regression record. These guards protect the approved formula and contract; Gate 4 proves the deployed scorer and endpoint against real timestamped inputs.
4. Confirm that a change in each input changes only the score components it is supposed to affect, and that no non-core adjustment can overcome a hard stop or poor environmental core.

**Acceptance:** Every scoring branch has a known-answer test; every generated SQLite runtime row and value matches the corresponding signed-off workbook profile, with one runtime row for each listed FAO area; query-plan evidence shows the setup and forecast indexes are used; the service returns only the requested subset without constructing a full in-memory catalogue; every setup choice maps to one complete eligible FAO-area/fishing-type runtime row; no undefined category or unfinished row is silently scored; the visitor-facing Fishing page does not expose the internal fallback trail; and the live Harbour forecast no longer converts a Fair environmental result into near-universal inactivity through a permanent pressure-sensitivity multiplier. After those checks pass, the YAML loader and `species.yaml` are removed in the same phase so only one runtime path remains.

### Phase 5 — Boating and Fishing presentation rebuild

**Depends on:** Phases 1–4.

**Status:** The dashboard is deployed from the Fishing/Boating main revision.
Boating now follows the approved
card order and renders regular forecast columns, labelled Regional NWS
additions, all Offshore Observations states, and the route/exit non-local
warning. Fishing uses the shared normalized Current Conditions card, durable
server-scored species selection, selected-species forecast detail, and the
complete live Almanac Sun & Moon component with only major/minor overlays.
The dashboard production build passes after independent source review. Gate 5
remains open: live API captures were collected, but the required browser test
environment returned HTTP 403 and no usable browser session was available for
desktop/mobile, theme, keyboard, scrolling, or operator visual checks.

1. Rebuild Boating into this card order: activity-relevant marine/coastal-flood alerts; shared Current Conditions; Boating Forecast; Offshore Observations; Tides, Currents, and Water Level. Do not retain disconnected wind, NWS-text, or buoy panels that duplicate these responsibilities.
2. Build the Boating Forecast using the regular Forecast page's time-column/card pattern and shared components. Add boating rows rather than recreating a separate forecast grammar. Parsed NWS wind, seas, visibility, and marine-weather fields belong in the matching forecast periods, never in a separate text-forecast card.
3. Create one shared full Current Conditions card for Boating and Fishing. It renders only the normalized API response and includes current weather icon/description, air and feels-like temperature, humidity, dew point, wind/gust/direction, pressure and three-hour trend, visibility, water temperature, tide/current-water-level context, and update time. Fishing-specific interpretation stays outside this card.
4. Put a species-selection strip at the top of Fishing, sourced from the configured species list. Default to the first configured species and retain the visitor's selection while they move through the forecast. The selection controls all score, suitability, seasonal, and explanation content below it.
5. Rebuild Fishing’s three-day forecast using the Surf forecast's combined forecast-and-score structure. It presents the time-matched weather and marine rows alongside the **selected species'** score, rather than a standalone score table. Each time column carries its tide/current state, depth-appropriate water temperature, major/minor solunar marker, relevant forecast conditions, and an explanation of that selected species' score. Do not render a generic Fishing score.
6. Rebuild the Fishing solunar presentation to match the Almanac `SunMoonDetailCard` in complete information, visual hierarchy, responsive behavior, and accessibility. Add major/minor windows as the fishing-specific overlay. Implementation may reuse, extract, or duplicate code; visual/functionality parity is the requirement.
7. Fold Species Forecast into the Fishing forecast card. The selected-species score, why it is active/less active/inactive, hard-stop reason when present, and detailed accessible data table all live within that one card on demand. Do not render a separate competing Species Forecast card or a generic-score card.
8. Verify all cards follow the Design Manual: card anatomy, fluid non-Now layout, responsive scrolling, tokens, contrast, tab order, and screen-reader labels.

**Acceptance:** The Harbour tabs display the full approved ensemble on desktop and mobile; Boating and Fishing share the complete API-driven Current Conditions card; visual affordances distinguish observed, forecast, regional text, and unavailable data; the solunar display is the complete Almanac Sun & Moon card—sun/moon arcs and current positions, phase/illumination, rise/set times, and the two-day sun/moon detail tables—with only major/minor fishing-period overlays added.

### Phase 6 — Final manual derivations and live closeout

**Depends on:** Phases 1–5.

1. Run affected API checks on `weewx`, marine-service checks on `librewxr`, dashboard production build on `weather-dev`, and an independent source/contract audit. Each check uses the deployed component and its real upstream inputs; a check on one host does not stand in for another component.
2. Perform live browser checks at Huntington Harbour in light/dark themes and mobile/desktop widths. Exercise tab switching, main-region scrolling, expanded period/species detail, keyboard focus, and each empty/unavailable state.
3. Compare the live buoy observation and the displayed current wave values at the same timestamp. Compare the time-matched forecast rows with the approved provider response.
4. Make the final manual updates that capture the shipped derivations: the exact provider-normalization rules, source/fallback behavior, NWS per-location Fishing block, score formula and constants, known-answer cases, and final card contracts. Remove all pre-implementation target-state tags only after live proof.
5. Archive superseded plan material only after the new contract is proved live.

**Acceptance:** The five verification questions in `rules/verification.md` are answered with live evidence; the implemented source-to-field ledger matches the actual live response; the operator signs off on the visual Harbour tabs.

## 8. Quality-control gates

Every gate below independently checks all five required dimensions: the implementation matches this plan; it complies with the aligned manuals and `ARCHITECTURE.md`; it follows the coding rules and security requirements; its automated checks test the intended behavior; and its live evidence matches reality. A phase does not pass on a test result alone.

### Gate P — Pre-phase evidence and source map

After Phase 0, independently verify the redacted Huntington Harbour captures against the live endpoints and source records. The source-to-field ledger must name the provider, location, valid time, units, and fallback for every value used by Boating or Fishing. No implementation brief is written until the ledger has no unexplained value.

### Gate 1 — Manual and contract alignment

After Phase 1, independently compare every affected manual and OpenAPI statement with this plan, then rerun the Phase-1 evidence sheet against the live baseline it describes. The gate fails on any contradiction, untagged target-state claim, missing source/fallback rule, missing provider-compatibility block, or manual instruction that would let an implementation agent build the old behavior. It also fails unless the manuals and architecture name the tracked `.xlsx` source, the one-global-profile-row/`fao_areas` workbook contract, generated exact-area SQLite runtime rows, deterministic generation command, read-only query boundary, indexes, packaging behavior, validation failure behavior, and YAML retirement sequence. This is a documentation/design gate, not proof of a changed live behavior.

### Gate 2 — Fishing matrix and formula design

Gate 2 cannot begin until the operator's Phase 2 framework-table sign-off is recorded. After population, independently verify that the workbook still has exactly the approved single worksheet/table, exact signed-off columns, one global profile row per selection key and fishing type, one fishing type per row, no duplicate FAO area within a row's `fao_areas` list, and unique exact-area `(selection_key, fao_area, fishing_type)` keys after deterministic expansion. Verify correct value types and units, no required blanks, no United States regional-list keys, and no research/provenance support structures. Verify the exact-species Red List decisions and confirm that practical categories were retained or removed only under Section 11.3. Sample the active-task research results only to confirm that values were transferred to the correct global profile rows; do not replace the operator-approved recreational-fishing source policy with a journal-publication standard. Independently reproduce the formula's hand-calculated known-answer cases and each permitted fallback level. This is a research/design gate, not proof of changed live behavior.

### Gate 3 — Provider and location-data contract

After Phase 3, use the evidence sheet's real-host, real-provider commands to prove that every supported forecast provider either supplies the provider-neutral hourly pressure series or returns an honest missing value. Prove that NWS setup reports the live result for each fishing location. At Huntington Harbour, prove that local weather, NWS marine periods, surface and target-depth ocean data, tide/current data, and offshore buoy observations remain distinct and time-stamped.

### Gate 4 — Fishing-score implementation

After Phase 4, first prove that every generated SQLite runtime row and value matches the corresponding signed-off workbook profile, with one runtime row for each listed FAO area, and that the database opens read-only. Record SQLite query-plan output showing the FAO-area/fishing-type index for setup and the selection/FAO-area/fishing-type index for forecast lookup. Verify by code inspection and runtime observation that the full matrix is not reconstructed as module-level Python dictionaries. Confirm that the legacy YAML data and loader are absent after the equivalence gate passes. Then run the evidence sheet's real timestamped inputs through the deployed scorer and endpoint, using the known-answer guards only to detect regression: seasonal activity refinements, inactive temperature, pressure states, tide/current states, time effects, solunar effects, and selected-species behavior. Prove that a hard stop cannot be rescued and that pressure sensitivity no longer acts as a permanent score penalty.

### Gate 5 — Boating and Fishing page behavior

After Phase 5, inspect the live Huntington Harbour tabs on desktop and mobile. Prove the approved Boating card order, forecast-column data alignment, buoy labeling, shared Current Conditions card, Solunar/Almanac parity, species selection, keyboard interaction, and all unavailable-data states.

### Gate 6 — Final manual derivations and independent live audit

After Phase 6, independently compare live provider records, API responses, and rendered pages at matched times. Confirm the final manuals and public API contract capture the shipped derivations, then confirm every earlier gate remains passed after deployment.

## 9. Required QC evidence

Every implementation phase must supply:

1. a pre-change live Huntington Harbour capture;
2. focused automated regression guards derived from the approved contract and real evidence; they may not be the source of the desired output;
3. production build/test output from the correct host;
4. an independent audit against this plan, the manuals, `ARCHITECTURE.md`, coding rules, and security requirements; and
5. a post-deploy live browser/API comparison using exact timestamps and station IDs.

Before any phase dispatch, its evidence sheet records the command, host, timestamped real input, expected result, raw-output destination, and the limitation of that check. A fixture or hand calculation may support diagnosis and future-regression coverage, but cannot by itself pass a gate.

No task may claim completion from static fixtures alone. The final gate must verify the user-facing live page and the provider records it represents.

## 10. Out of scope

- Altering WW3, SWAN, SwellTrack, their domains, grids, boundaries, schedules, or physics.
- Adding a new provider, endpoint, configuration key, persisted data store, or dependency without an approved decision.
- Replacing the activity/location architecture or creating a separate Fishing/Boating navigation model.

## 11. Fishing matrix workbook and recovery contract

This section is the sole authority for the Phase 2 workbook. It supersedes any
earlier plan, brief, handoff, or workbook instruction that describes multiple
matrix worksheets, normalized evidence tables, research queues, source-ID
links, staging mirrors, or a research database.

### 11.1 One-table deliverable

The human-editable deliverable is one structured `.xlsx` workbook containing
exactly one worksheet and one table. Each editable row is one global selectable
species or existing practical-category profile. It has one fishing type and a
`fao_areas` list containing every applicable FAO area. A workbook row is not a
per-FAO editable row. The deterministic generator expands each listed area
into one exact `(selection_key, fao_area, fishing_type)` SQLite runtime row,
where the profile values are preserved. The workbook is the sole manually
maintained matrix source. It is not read by the running service, and it is not
where the research process, citations, audit narrative, or task state are
stored.

The table contains only these operational field groups:

1. the stable selection key and visitor-facing label;
2. the `fao_areas` coverage list and one fishing type that make generated
   runtime rows eligible;
3. the complete direct profile for the one species or practical category;
4. habitat-depth limits used to obtain the applicable water temperature;
5. every temperature-band boundary required by §3.6.1;
6. the preferred, acceptable, and poor tide/current states required by §3.6.1;
7. the pressure sensitivity required by §3.6.1;
8. the preferred and low-activity time and seasonal treatments required by
   §3.6.1;
9. the operational IUCN conservation flag, when required by §11.3.

The framework sign-off in Phase 2 locks the exact column names, order, units,
allowed codes, and visual layout before bulk population begins. No later agent
may add a column, table, worksheet, identifier system, or supporting data
structure without another explicit operator approval.

The workbook contains no source URLs, research-source IDs, evidence IDs,
research notes, rationale, confidence labels, completion status, research
queue, taxonomy table, IUCN assessment details, quality-control sheet, read-me
sheet, duplicate local/global tables, or staging/mirror table. Research may be
checked from the task results while work is active, but it is not copied into
the operational workbook. A blank required operational field means the row is
unfinished; it is never converted into an evidence-status record.

### 11.2 Recovery baseline

The intact local recovery workbook is read-only:

`C:\CODE\weather-belchertown\outputs\01a0777f-c6bb-7ff0-816d-aaf1ebacfe79\FISHING-BOATING-SPECIES-MATRIX-2026-09-06-striped-bass-staged.xlsx`

It predates some later research but contains usable selection and profile data.
Never overwrite, mirror, synchronize, restructure, or treat it as the desired
workbook design. Extract only the values that map to the operator-approved
one-table framework. Do not copy its old worksheets, queues, status fields,
research records, or United States regional keys.

After the framework receives operator sign-off, recover later completed values
from the surviving task results and import scripts. Re-research only fields that
remain empty after those two recovery passes. The damaged current canonical
workbook is not an authority; a value from it may be used only when independently
confirmed by the staged recovery workbook, a surviving research result, or a
fresh source.

Before population continues beyond the signed-off example row, save the
approved framework at an operator-approved tracked project path so Git provides
a recovery point. Neither `scratch/` nor an untracked `outputs/` directory may
hold the only authoritative copy during multi-session work.

### 11.3 IUCN Red List vetting

IUCN Red List screening is mandatory while reconstructing the selection list.
Screen exact source species, never a practical category name.

- Exclude an exact species assessed as `Vulnerable`, `Endangered`, or
  `Critically Endangered`.
- Retain an exact species assessed as `Near Threatened` and set the table's
  operational conservation flag to `near_threatened`.
- Do not flag `Least Concern`, `Data Deficient`, or `Not Evaluated` species.
- Do not remove, rename, or challenge an existing practical category because
  source-member research is incomplete.
- Remove a practical category only when every exact source species beneath it
  has been identified and every one is excluded by the three-category rule
  above. Thresher shark is the confirmed example.

The detailed IUCN assessment and its citation are research inputs used during
vetting, not additional operational workbook tables or columns.

### 11.4 Approved runtime storage — generated SQLite

**Operator decision, 2026-09-09:** The sole editable `.xlsx` table has one
global species or practical-category profile row, one fishing type, and a
`fao_areas` list. A one-table workbook does not mean one editable row per FAO
area. Deterministic generation validates that table and expands each listed
area into exact `fao_area` SQLite runtime rows. Setup and forecast queries use
those exact runtime rows and the indexes below.

**Operator decision, 2026-09-07:** The `.xlsx` table is the editable source and
a generated SQLite database is the runtime lookup. The current YAML catalogue
is not the final runtime format.

The SQLite database contains one logical data table of exact runtime rows. For
each editable global profile row, deterministic generation emits one row per
entry in its `fao_areas` list, adds that exact `fao_area` runtime key, and
preserves the approved operational profile fields. It is never edited
independently. The generator validates the approved headers, value types,
allowed codes, required fields, duplicate-free FAO-area lists, runtime key
uniqueness, FAO-area keys, and Red List flags before replacing the generated
database.

The runtime database has these indexes:

- FAO area + fishing type, for setup to fetch only the eligible practical
  choices for one configured location; and
- selection key + FAO area + fishing type, for the forecast service to fetch
  only the configured species/category profile and any approved fallback rows
  needed for that request.

The marine service opens the packaged database read-only and selects only the
columns and rows needed for the current operation. It does not parse the Excel
workbook at startup and does not materialize the global catalogue as
module-level Python dictionaries. SQLite may use its normal page cache, but the
application does not retain every matrix row as Python objects.

The generated SQLite file and its source workbook are tracked in the marine
repository. The workbook is the sole editable authority; the database is a
replaceable build artifact. Phase 1 names their final paths and the generation
command before implementation. If generation fails or validation finds a
mismatch, the prior generated database remains untouched and the build fails
loudly.

Phase 4 keeps the existing YAML path in place only long enough to prove that
the SQLite queries return equivalent setup selections and scoring values for
the agreed comparison cases. After that proof and independent review, remove
the YAML runtime data and loader rather than maintaining two runtime paths. A
new build-only workbook-reading dependency, if required, must be presented to
the operator before it is added; SQLite access itself uses Python's standard
library.

## 12. Phase 2 coordinator and research-agent execution

The coordinator owns the Phase 2 result. Research agents retrieve bounded
facts; they do not define the work, redesign the matrix, judge the operator's
methodology, edit the workbook, or decide whether a practical category should
exist.

### 12.1 Framework approval before population

The coordinator first builds the Section 11 table with its headers and exactly
one completed example row: black sea bass in FAO area 21 for bottom fishing.
The coordinator renders that table and explains each column in plain English.
It then stops for explicit operator approval of the structure, row meaning,
column names, units, allowed codes, and layout. No other row is recovered,
researched, or populated until that approval is given in chat.

### 12.2 Required research-agent brief

Every research assignment covers one named species or practical category and
contains all of the following before dispatch:

1. the exact selection label, FAO area, and fishing type;
2. the exact output fields still required for that row;
3. the definition, unit, and allowed value or code shape for each field;
4. the existing recovered values that must not be cleared or re-litigated;
5. the approved source scope for each field;
6. explicit exclusions: no workbook edits, schema changes, category changes,
   formula changes, evidence-policy debate, or unrelated research; and
7. a fixed row-shaped return format that the coordinator can apply without
   interpretation.

The brief is self-contained and context-bounded. Do not give a research agent
the full conversation transcript, the whole remediation plan, unrelated
manuals, or earlier agents' methodological arguments. If the agent returns an
essay, proposes a different method, omits requested fields without describing
the searches performed, or challenges an operator-set requirement, the
coordinator rejects the packet and sends a precise corrective follow-up.

### 12.3 Research and import sequence

This matrix supports recreational sport-fishing forecasts for anglers. It is
not an academic biology publication, a fisheries-management model, a
commercial-fishing system, or a source of regulatory decisions. Its purpose is
to turn the best available practical fishing knowledge into useful recreational
forecast guidance. Individual anglers decide how much weight to give that
guidance.

Some relevant knowledge is quantitative and scientifically studied. Much of it
is necessarily qualitative or subjective: accumulated experience passed down
through the sport, repeated observations from anglers and guides, local
seasonal knowledge, and practical advice published by established fishing
sources. That does not make it unusable for this product. Peer-reviewed journal
evidence is welcome when it exists, but it is not the minimum standard for a
recreational fishing field and may not be imposed by a coordinator or research
agent as a reason to reject the operator-approved research method.

For behavioral and fishing-outcome fields, use the broad practical source set
the operator approved: international and regional sport-fishing magazines,
fishing publications and blogs, charter and guide reports, angler records,
creel studies, tournament results, and established fishing-industry material.
Qualitative descriptions such as preferred conditions, common bite windows,
seasonal patterns, pressure responses, tide/current behavior, and active hours
are valid inputs when they are clearly about the named fish or practical
category in the applicable area. Where several sources give different but
compatible ranges, the research packet states the practical range or code that
best represents their shared guidance rather than rejecting the entire field.

Use official fisheries, FAO, FishBase, IUCN, and regulatory sources for range,
taxonomy, regional presence, law, and conservation where appropriate. These
official sources supplement the sport-fishing evidence; they do not displace it
as the authority for practical angling behavior. The coordinator verifies that
a source says what the packet claims and that the finding is applied to the
right fish and area. It does not conduct an unsolicited scientific-method
review or replace this source policy with its own preferred academic standard.

After framework approval, execute this loop:

1. recover the row's existing values from the staged workbook and later task
   records;
2. assign research only for the fields still missing;
3. receive one global profile-shaped packet, including its applicable
   `fao_areas` coverage;
4. enter it immediately into the operational table;
5. verify the exact row, units, codes, and key uniqueness; and
6. only then assign the next fish or category.

Do not launch more research while a returned packet is waiting to be applied.
Do not replace workbook edits with status reports. A narrow failed search does
not establish that nothing can be found; the coordinator broadens or reassigns
the search and keeps the row unfinished. Gate 2 remains open until every
required row is complete and the Red List screen has been applied.
