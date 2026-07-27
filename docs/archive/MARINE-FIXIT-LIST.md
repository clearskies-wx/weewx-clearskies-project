# Marine Fixit List

Collected 2026-07-15. Issues found during marine feature troubleshooting. To be turned into a formal plan.

---

## FIX-1 (CRITICAL REGRESSION): Wizard `nwps_wfo` in payload causes total marine save failure

**Symptom:** Wizard not saving NDBC buoy IDs, COOPS sites, marine zone IDs, or any marine data at all.

**Root cause:** `build_marine_payload` in `config_writer.py:445` sends `nwps_wfo` in the location entry, but `MarineLocationApplyConfig` in the API (`setup.py:538-557`) does NOT have a `nwps_wfo` field and uses `extra="forbid"`. The API resolves `nwps_wfo` internally during apply via NWS `/points`. The entire apply payload is rejected with 422 "Extra inputs are not permitted," so **nothing saves**.

**Introduced in:** commit `e8ad003` ("align build_marine_payload with API schema").

**Fix:** Remove `"nwps_wfo"` from the key list in `build_marine_payload`. The API resolves it itself.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py:445`

---

## FIX-2: Species not saved — missing from API schema and wizard payload

**Symptom:** Target species selections not persisted after wizard save.

**Root cause (two parts):**
1. Wizard's `build_marine_payload` (`config_writer.py:466-475`) copies `target_categories` and `biogeographic_region` but never copies `species` to `fishing_out`.
2. API's `MarineFishingSpotApplyConfig` (`setup.py:492-518`) does NOT have a `species` field, and uses `extra="forbid"` — so even the admin path (which does send species) would be rejected.

**Fix:**
1. Add `if fishing.get("species"): fishing_out["species"] = fishing["species"]` in `config_writer.py`.
2. Add `species: list[str] = []` to `MarineFishingSpotApplyConfig` in the API.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py:466-475`
- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py:492-518`

---

## FIX-3: Directional exposure corrupted on round-trip through ConfigObj

**Symptom:** After saving surf directional exposure, all 8 directions appear selected on re-edit regardless of original selection.

**Root cause:** Three interacting bugs:
1. `build_marine_payload` (`config_writer.py:457`) sends ALL 8 compass directions with `True`/`False`: `{d: d in exposure for d in all_directions}`. Unselected directions get Python `False`.
2. ConfigObj writes Python `False` as the string `"False"` to `api.conf`.
3. Admin's `_marine_exposure_list` (`admin/routes.py:1902`) reads back with `if v` — the string `"False"` is truthy, so all 8 directions pass the filter.

**Fix:**
1. Change `config_writer.py:457` to send only True directions: `{d: True for d in exposure}`.
2. Change `admin/routes.py:1902` to check `if str(v).lower() == "true"` instead of bare `if v`.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/config_writer.py:457`
- `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py:1902`

---

## FIX-4: Marine location photo not persisted or displayed

**Symptom:** Uploading a location photo does nothing — not displayed on page, not retained on re-edit.

**Root cause:** Photo file IS saved to disk at `/etc/weewx-clearskies/marine-photos/{slug}.{ext}`, but no `photo_url` reference is ever stored on the location dict.
- Wizard `step_marine_post` (`routes.py:2898`) saves bytes but never sets `loc["photo_url"]`.
- Admin `marine_save` (`admin/routes.py:2342-2353`) same issue.
- Templates have no `<img>` to display existing photo, no hidden field to carry URL forward.
- `MarineLocationApplyConfig` does not have a `photo_url` field — photo URL should stay local (stack.conf or local state), not sent to API. Photos are served by Caddy from disk.

**Fix:** After saving photo to disk, set `loc["photo_url"]` in both wizard and admin. Store in local config. Add `<img>` and hidden field to templates.

Additionally, the wizard and admin must include a **photo attribution** text field alongside the photo upload. If attribution is filled out, it must be persisted with the location config and displayed on the dashboard's **About page** under a photo attributions card. All marine location photo attributions can be a single combined list (not per-location cards).

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py:2898`
- `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py:2342-2353`
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_marine.html`
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
- Dashboard About page component (photo attributions card)
- API — attribution data needs to reach the dashboard (either via `/api/v1/content/about` or a marine-specific endpoint)

---

## FIX-5: Clear Skies logo too small in wizard header

**Symptom:** Logo in wizard step bar is undersized (visible in screenshot).

**Fix:** Increase logo dimensions in wizard header template/CSS.

**Files:** TBD — wizard header template/CSS.

---

## FIX-6: Admin header needs visual parity with wizard

**Symptom:** Admin page header is plain ("Clear Skies Admin" text on cloud background). Missing logo, formatting doesn't match wizard, contrast issues with white text on cloud photo.

**Fix:** Add Clear Skies logo, match wizard header layout/formatting, fix text contrast.

**Files:** TBD — admin base template/CSS.

---

## FIX-7: Marine page grid spacing — no gap between cards and map

**Symptom:** Location cards and the Leaflet map have no spacing between them on the Marine Activities page.

**Fix:** Add proper gap/margin in the marine page grid layout.

**Files:** TBD — dashboard `src/routes/marine/` layout component.

---

## FIX-8: Marine map labels — investigate feature-label-only layer

**Symptom:** Map needs labels for marine features (e.g., "San Pedro Channel") but NOT shipping lanes, buoy markers, etc.

**Action:** Investigate whether a tile layer exists that provides marine geographic feature labels only. If no such layer exists, remove the marine feature overlay entirely.

**Files:** TBD — dashboard marine map component.

---

## FIX-9: Marine location cards missing current conditions hero icon (3RD REQUEST)

**Symptom:** Location cards show wave height, wind, water temp — but no weather condition icon (sunny, cloudy, etc.) from the forecast provider or station data.

**This has been requested three times.** The icon should come from the forecast provider or be station-dependent based on location.

**Files:** TBD — dashboard marine location card component, possibly API marine endpoint.

---

## FIX-10: Marine location cards need location photo and larger footprint

**Symptom:** Cards don't display the location photo. Current card size is too small to accommodate a photo.

**Depends on:** FIX-4 (photo persistence must work first).

**Fix:** Display location photo on card. Resize cards to either 2x1 or 1x2 footprint to accommodate the photo alongside the data.

**Files:** TBD — dashboard marine location card component.

---

## FIX-11: Marine location detail page — design rule violations

**Symptom:** Multiple layout/design issues on the per-location detail page (e.g., Huntington City Beach (Pier)):

1. **"Back to map" button placement:** Currently floats above the map as a separate element. Should be inside the map container (overlaid on the map).
2. **Activity tabs (Surfing / Fishing / Beach Safety):** Floating unstyled in the background. Need either a proper design-system tab pattern or buttons on a status strip — current look is unfinished.
3. **Page title ("Huntington City Beach (Pier)"):** Floats in the cloud background with no containing element. Needs a strip/bar like the "Marine Activities" header on the landing page.

**Fix:** Move back-to-map button into the map container. Design a tab/button-strip pattern for activity switching (needs design criteria — either formal tabs or a styled status strip). Put the location name in a proper header strip.

**Files:** TBD — dashboard `src/routes/marine/` location detail component and CSS.

---

## FIX-12: Surf current conditions card — redesign into 3 separate cards

**Symptom:** The "Current Conditions" card on the surf detail page is a jumbled mess:
- The surf score ("Very Good" with stars) is buried below the text summary in a diminished badge — it should be the **leading** element.
- Wave data (height, period) is mixed in with wind and water temp with no logical grouping. Dominant wave period is missing.
- Wind quality shows "Cross-Shore" label but no actual wind speed value.
- The text summary source needs verified — where is "1-3 ft at 18 seconds from the SW. Cross-shore winds. Wind chop dominates." generated from?
- Rip current risk badge is tacked on at the bottom with no visual hierarchy.

**Redesign:** Split the monolithic "Current Conditions" card into 3 separate cards. This replaces the previously-planned separate scoring breakdown card — the score and its breakdown are now integrated into the Surf Score Card here.

1. **Surf Score Card (2x2):** The leading card. Shows the current surf score prominently (e.g., "Very Good" / 4.5 stars or numeric rating) with a scoring breakdown — what factors contributed to the score (swell direction/height match, wind quality, tide phase, etc.). This is the hero card for the surf tab. **This card absorbs and replaces the separate scoring breakdown card that was previously planned.**

2. **Swell Card (2x1):** Wave height, dominant swell period, swell direction, swell height. Organized as a proper swell data section. Should include model-processed swell component breakdown (what swell systems are contributing to conditions at the beach) — this replaces the standalone raw spectral "Swell Components" card, which shows unprocessed buoy data that is not meaningful at the break. **Remove the standalone Swell Components card entirely.** The swell direction compass (currently in `SurfingTab.tsx:590+`, sourced from raw buoy spectral data via `dominantSwellDirection()`) moves into this card and must be sourced from the NWPS/WW3 model output (processed wave direction), not from raw NDBC buoy spectral components.

3. **Wind Card (2x1):** Wind speed (currently missing!), wind direction, wind quality label (onshore/offshore/cross-shore), wind gust if available.

**Answered questions:**
- **Conditions text** is composed **API-side** by `_compose_conditions_text()` in `enrichment/surf_scorer.py:416`. Three i18n template sentences concatenated: wave summary (height range + period + direction), wind part (quality label +/- speed), swell dominance summary (clean/mixed/chop). Dashboard renders `primary.conditionsText` as-is in `SurfingTab.tsx:822`.
- **Water temp** comes from the **NWS Surf Zone Forecast (SRF)** provider (`nws_srf.py`), parsed from the SRF text product field "WATER TEMPERATURE...{value}." — it is NOT from NDBC buoy or the ocean data resolver. Rendered from `zoneForecast.waterTemp` in `SurfingTab.tsx:856`.
- **Rip current risk** also comes from the **NWS SRF** provider, parsed by `_parse_rip_current_risk()` in `nws_srf.py:874`. Compound values like "MODERATE TO HIGH" resolve to the higher category for safety. Rendered as a color-coded `RipCurrentBadge` in `SurfingTab.tsx:863`.

**Remaining open question:**
- Rip current risk — which of the 3 new cards does it belong in, or does it get its own card?

---

## FIX-13: Surf page water temp uses NWS SRF text instead of ocean data resolver

**Symptom:** Water temperature on the surf detail page comes from a forecaster-typed value in the NWS SRF text product ("WATER TEMPERATURE...79."), parsed by `nws_srf.py`. This is a stale, manually-entered number.

**The system already has a proper water temperature source.** The ocean data resolver (`services/ocean_data_resolver.py`) provides modeled/observed water temp via a tiered fallback chain: on-premises sensor → OFS regional model → regional ERDDAP → RTOFS/MUR SST global. The `/marine/{location_id}` endpoint already uses it.
no i think it did s
**Fix:** The surf endpoint (`endpoints/surf.py`) must source water temp from the ocean data resolver, not from `zoneForecast.waterTemp` (NWS SRF). The SRF water temp field should be dropped or demoted to a fallback-only role.

**Files:**
- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
- `repos/weewx-clearskies-api/weewx_clearskies_api/services/ocean_data_resolver.py` (already built)

---

## FIX-14: Surf wind scoring uses offshore NDBC buoy wind only — must use local/coastal wind

**Symptom:** Surf wind quality scoring ("offshore/onshore/cross-shore") uses wind speed and direction exclusively from the NDBC buoy, which is 12+ miles offshore in the channel. This does NOT represent beach/coastal wind conditions. Wind carries 20% of the surf quality score weight.

**Root cause:** `endpoints/surf.py:284-298` fetches wind ONLY from NDBC buoy observation data (`ndbc.fetch() → obs.windSpeed/windDirection`). No fallback, no blending, no local station data, no forecast provider wind. If NDBC fails, wind is `None` and the scorer assigns a neutral 0.5 score with "cross" label — still no local data.

### Research findings: what wind matters for surf quality

**The wind AT THE BEACH determines wave face quality, not offshore wind.** Industry and science confirm this:

1. **Local coastal wind is what shapes the wave face.** Offshore wind (land → sea) grooms wave faces and holds them up longer. Onshore wind (sea → land) chops up the surface and causes early breaking. Cross-shore is in between. This effect happens right at the break — an offshore buoy measures the synoptic wind field, which can be completely different from what's happening at the beach.

2. **Coastal wind is dominated by thermal effects that buoys cannot see.** Sea breezes (onshore, afternoon), land breezes (offshore, morning/early AM), topographic channeling, and coastal temperature gradients drive wind patterns at the beach that diverge sharply from offshore readings. SoCal is textbook sea-breeze territory — morning glass-off conditions at the beach while the buoy 12 miles out reports a steady westerly.

3. **Surfline confirms this with infrastructure investment.** They installed weather stations AT surf spots worldwide because global models and offshore buoys miss local effects. Their support docs state: "Small-scale phenomena such as thermal sea breezes, air interacting with topography, or localized temperature differences near the coast can have a significant impact on surf quality and are potentially missed by the GFS global wind forecast." They expanded beach-level coverage from ~35% to ~70% of spots specifically for this reason.

4. **NDBC buoy wind has a valid role — but not for surf quality scoring.** Offshore buoy wind reflects the synoptic-scale wind field that drives fetch and generates swells. It is relevant to understanding swell generation (already captured by the spectral decomposition). It is NOT relevant to whether the wave faces at the beach are clean or blown out.

### Wind source precedence for surf quality scoring

The surf scorer must use the wind closest to the beach:

1. **Station hardware** (operator's anemometer) — best source when the station is coastal/near the spot
2. **Forecast provider** (NWS point forecast for the spot's coordinates) — captures mesoscale coastal wind patterns including sea breeze onset, but not micro-scale topographic effects
3. **NDBC buoy wind** — WRONG for surf quality. Valid only for swell-generation context (already captured by spectral data). Should be dropped from the wind quality scorer entirely, or demoted to absolute last-resort fallback with a quality caveat.

The marine endpoint already implements this pattern: `endpoints/marine.py:567-638` uses station hardware first → forecast provider fallback. The surf endpoint must adopt the same precedence.

### References

- [Surfline Live Wind](https://support.surfline.com/hc/en-us/articles/5291311612315-Live-Wind) — why local beach wind stations matter
- [How Wind Affects Surfing (Neptune)](https://neptune.coach/blog/how-wind-affects-surfing) — complete guide to wind direction and surf quality
- [Onshore vs Offshore Wind (SurfSpotGuide)](https://www.surfspotguide.com/surf-guide/onshore-vs-offshore-wind) — wind direction thresholds
- [KEWL Mermaid Surf Messiness Rating](https://kewlmermaid.com/articles/surf-messiness-rating.html) — scoring methodology using local wind chop (35% weight)
- [Surf-Forecast.com FAQ](https://www.surf-forecast.com/pages/faq) — star rating degradation from onshore wind

**Files:**
- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py:284-298` (wind sourcing)
- `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py:236-277` (`_wind_quality()`)
- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/marine.py:567-638` (reference: wind precedence to adopt)
- `docs/manuals/API-MANUAL.md` §17, §18 (documentation update)

**Design reference:** Use the Now page cards as the model for layout, typography, stat formatting, and visual style. These marine cards should look like they belong on the same site — same card anatomy, same token usage, same stat tile patterns.

**Files:** TBD — dashboard surf detail components, possibly API surf endpoint response shape.

---

## FIX-17 (CRITICAL): NWPS GRIB reader is NOT temporally aware — may be using hour 144 instead of current

**Symptom:** The GRIB2 reader (`grib_processor.py:116-167`) iterates through all GRIB messages in the file and **overwrites** `result.fields[short_name]` for each matching field. It does not read `stepRange`, `forecastTime`, `endStep`, or any temporal key from the GRIB message. The NWPS GRIB2 file contains **144 hourly forecast timesteps** (hours 0-144). If messages are ordered chronologically (standard GRIB2 ordering), the last overwrite is **hour 144 — six days in the future**.

**Impact:** The "current conditions" wave height, period, and direction on the surf page may be showing the 6-day-out prediction, not what's happening right now. Every downstream consumer of NWPS data (surf scorer, wave_transform supplements, current conditions cards) would be operating on the wrong timestep.

**Root cause:** `_read_eccodes()` and `_read_pygrib()` in `grib_processor.py` have zero temporal awareness. They treat the GRIB2 file as if it contains one message per field. It contains 144.

**Fix:** The GRIB reader must:
1. Read the `stepRange` or `forecastTime` key from each GRIB message to know which forecast hour it represents.
2. For current conditions: select hour 0 (analysis) or the nearest hour to now.
3. For forecast use cases: return all timesteps indexed by hour so consumers can select the right one.
4. Verify the actual message ordering in NWPS GRIB2 files — confirm whether hour 0 is first or last.

This is a prerequisite for any forecast map work but is a standalone data correctness bug regardless.

**Files:**
- `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/grib_processor.py:116-167` (eccodes reader)
- `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/grib_processor.py:175-220` (pygrib reader)
- `repos/weewx-clearskies-api/weewx_clearskies_api/providers/marine/nwps.py:398-447` (`_extract_fields`)

---

## FIX-18 (FUTURE FEATURE — discuss with user): Animated swell height map with forecast time slider

**Concept:** An interactive map showing NWPS gridded wave height/direction across the nearshore domain, with a time slider to scrub through forecast hours (now → +3h → +6h → ... → +144h). Similar to surf-forecast.com's animated swell maps — markers or contours with height values and directional arrows at each grid point, updating as the slider moves.

**Data availability (confirmed):**
- NWPS GRIB2 files contain **144 hourly forecast timesteps** at **500m-1.8km nearshore resolution** — the data is already in the files we download (~14MB per cycle).
- Our GRIB parsing infrastructure (eccodes/pygrib) already exists.
- WaveWatch III provides a coarser (~50km) global fallback with 25 timesteps over 72h at 3-hour intervals.

**What would need to be built:**
1. Modify GRIB reader to return all timesteps indexed by hour (depends on FIX-17)
2. Extract full 2D grids instead of single-point interpolation
3. API endpoint to serve gridded data (GeoJSON or rasterized tiles)
4. Dashboard: Leaflet rendering layer (canvas/WebGL contours or marker grid) + time slider UI
5. Caching strategy for the grid data (144 frames × full grid is substantial)

**Depends on:** FIX-17 (GRIB temporal awareness) must be fixed first.

**Status:** Needs discussion with user about where this fits in the roadmap — current marine remediation scope or future phase.

---

## FIX-15: 72-Hour Surf Forecast card — complete redesign

**Symptom:** The 72-hour surf forecast card is missing critical information and has major usability/design problems:

1. **No day labels.** The x-axis shows "5:00 AM / 5:00 PM" repeating but you cannot tell what DAY you are looking at. Forecast days are indistinguishable.
2. **Star ratings are ridiculous at this scale.** 14+ little star clusters in green badges are unreadable and waste space. Show the numeric surf score only (e.g., "4.2" or "Very Good") — no stars.
3. **Wave chart dominates the card but is missing most data.** The wave face height line chart is fine conceptually but takes up too much vertical space, and it's the ONLY data shown. Missing elements that competitors (Surfline, Magic Seaweed, Surf-Forecast) include:
   - **Weather forecast** — sky condition icon, air temp for each period
   - **Full wave info** — swell height, swell period, swell direction (not just face height)
   - **Wind** — speed, direction, quality label (offshore/onshore/cross-shore)
   - **Wind state** — how wind changes through the day
   - **Tides** — simple text/icon (e.g., "↑ High 4.2ft 11:32 AM") per period, NOT a separate chart here. The full tide chart is a separate card (see FIX-16).

**Redesign:** Layout should follow the dashboard's **Forecast page cards** pattern — each day/period as a structured row or column with all data elements, not a scrolling strip of star badges over a single line chart.

**Industry reference (surf-forecast.com for Huntington Pier):** Their forecast uses a horizontal scrolling table with time periods as columns (8 slots per day: 8AM/11AM/2PM/5PM/8PM/11PM/2AM/5AM) and data categories as rows, top to bottom:

1. **Rating** — numeric score (0-10), NOT stars
2. **Wave height** (m)
3. **Swell direction** (compass)
4. **Period** (seconds)
5. **Energy** (kJ)
6. **Wind speed + direction** (km/h)
7. **Wind state** (on-shore / cross-shore / off-shore / glassy)
8. **High tide** (time + height)
9. **Low tide** (time + height)
10. **Weather icon** (sky conditions)
11. **Sunrise/Sunset**
12. **Precipitation**
13. **Temperature + feels like**
14. **Swell components** (Swell 1, 2, 3 — each with height, direction, period, energy)

Days are separated by day headers (e.g., "Wednesday 15", "Thursday 16"). Every element a surfer needs is visible at a glance for each time period.

**Our approach:** Adapt this structure to match the Clear Skies Forecast page card pattern (our visual language, not a clone). Key requirements:
- Numeric surf score only (no stars)
- Day headers so you know what day you're looking at
- Per-period: weather icon, air temp, wave height, period, direction, wind speed + direction + state label, tide text (e.g., "↑ High 4.2ft 11:32 AM")
- Swell components if available from NDBC spectral data
- The tide info here is simple text/icon — the full graphical tide chart is a separate card (FIX-16)

**Design reference:** Forecast page card pattern from the dashboard — structured day/period layout with multiple data elements per period.

**Files:** TBD — dashboard surf forecast component, API surf endpoint response (may need additional fields).

---

## FIX-16: Tide chart not working on ANY activity detail page

**Symptom:** The tide chart is broken / not rendering on the surf detail page AND the fishing detail page. The tide data exists in the API response (`tidePredictions` array from CO-OPS), but the chart component is not displaying anything.

**Fix:** Investigate and fix the tide chart rendering. This is the full graphical tide chart — separate from the simple tide text/icons that should appear in the forecast cards (FIX-15, FIX-21). The tide chart should work on every activity page that displays it.

**Files:** TBD — dashboard tide chart component.

---

## FIX-19: Marine/coastal alert strip on ALL activity detail pages

**Symptom:** Marine and coastal advisories, statements, watches, and warnings are not shown on the activity detail pages (surfing, fishing, beach safety). If a Small Craft Advisory or Rip Current Statement is active, the surfer/angler/beachgoer sees nothing about it on the page they're actually using.

**Requirement:** ALL activity detail pages must show a marine/coastal alert strip at the top of the page when relevant alerts exist. This includes:
- Advisories (Small Craft Advisory, Beach Hazards Statement, etc.)
- Watches (Hurricane Watch, Tropical Storm Watch, etc.)
- Warnings (Hurricane Warning, High Surf Warning, etc.)
- Statements (Rip Current Statement, etc.)

The strip does NOT need to be the full-width hero banner from the main dashboard page. A thin, color-coded strip is sufficient — severity color + alert name + brief text. Must filter to marine/coastal alert types only (not inland heat advisories, etc.).

**Applies to:** Surfing tab, Fishing tab, Beach Safety tab — all of them.

**Files:** TBD — dashboard activity tab components, API alerts endpoint (already exists, may need marine-specific filtering).

---

## FIX-20: Fishing page — redesign current conditions layout

**Symptom:** The fishing detail page has the same layout problems as the surf page — scoring is not prominent, current conditions data is mostly not working, and the page is missing critical fishing-relevant weather data.

**Redesign:** Two cards for current conditions:

1. **Fishing Score Card (2x2):** The leading card. Shows the current fishing score prominently with a scoring breakdown — what factors contributed (solunar phase, tide phase, barometric trend, wind, water temp, etc.). Same hero treatment as the Surf Score Card in FIX-12.

2. **Current Conditions Card (2x2):** The primary weather/ocean conditions an angler needs:
   - Barometric pressure (and trend — rising/falling/steady)
   - Current wind speed + gust
   - Wind direction
   - Water temperature (from ocean data resolver, NOT NWS SRF — same fix as FIX-13)
   - Air temperature

   Most of these are reportedly **not working on this page**. Same data sourcing issue as the surf page — current conditions must come from station hardware → forecast provider fallback (same precedence as the marine endpoint, per FIX-14), not from NDBC buoy.

**Design reference:** Use the Now page cards as the model. Follow the same card anatomy, token usage, and stat tile patterns as the rest of the dashboard.

**Files:** TBD — dashboard fishing tab component, API fishing endpoint response shape (may need additional fields).

---

## FIX-21: Fishing forecast card — complete redesign (same treatment as FIX-15 surf forecast)

**Symptom:** The fishing forecast card is missing critical data that anglers need to plan trips. Same class of problems as the surf 72-hour forecast (FIX-15) — incomplete data, poor layout, missing day labels.

**Required data elements per forecast period (modeled after the dashboard Forecast page cards):**
- **Fishing score** — numeric quality score per period (same scoring system as the Fishing Score Card in FIX-20, projected forward). This is the leading element — anglers need to see at a glance which periods are best.
- **Weather forecast** — sky condition icon, air temperature
- **Cloud cover percent** — important for fishing (overcast vs. bright sun affects bite activity)
- **Barometric pressure** (and trend) — the single most important weather variable for fishing
- **Wave height and period** — safety and comfort on the water
- **Wind speed, direction, gust** — determines fishability
- **Solunar information** — major/minor feeding periods shown as icon/graphic format (not raw times). The solunar data already exists at `/api/v1/almanac/solunar`.
- **Species-specific detail** — NOT a persistent row. Instead, use the same pattern as the dashboard's 7-day forecast card: clicking/tapping a forecast period column opens an **accordion expander** below the forecast card showing extended detail for that period. The expanded section includes species-relevant information: which configured target species are favorable for that period (based on preferred temp range, barometric sensitivity, feeding pattern, solunar response), solunar major/minor period timing, and any additional detail that doesn't fit in the compact forecast row. This keeps the main forecast card clean while giving anglers the deeper info on demand.

**Design reference:** Dashboard Forecast page cards — structured day/period layout. Same visual language as FIX-15's surf forecast redesign. Day headers required so you know what day you're looking at.

---

## FIX-22: Beach Safety page — layout and missing data

**Symptom:** Beach Safety page is missing critical information beachgoers need and doesn't follow the same layout patterns as the other activity pages.

**Required cards/layout:**

1. **Current Weather Conditions Card (2x2):** Reuse the Now page's current conditions card component directly — air temp, sky condition icon, humidity, feels-like, etc. Don't build a new one.

2. **3-Day Forecast Card (1x2):** Modeled after the dashboard Forecast page cards. Three day columns with weather icon, high/low temp, wind, precipitation chance. Compact — beachgoers don't need 72 hours of detail.

3. **Ocean/Beach Conditions Card:** Water temp (from ocean data resolver), wave height/period, wind speed/direction/gust. Same data sourcing fixes as surf and fishing (station → forecast provider, not NDBC buoy for wind).

4. **Rip Current Risk** — keep, this is good.

5. **What to Wear** — keep, this is good.

6. **UV Index** — **currently missing, important.** Needs both current UV and predicted UV through the day. The NWS SRF already provides `uvIndex` in `zoneForecast` — surface it. For the forecast card, UV per period is needed.

7. **Marine/coastal alert strip** — same as FIX-19, thin strip at top of page under the map.

**Design reference:** Now page cards for current conditions. Forecast page cards for the 3-day forecast. Same card anatomy, tokens, stat tile patterns as the rest of the dashboard.

**Files:** TBD — dashboard beach safety tab component, API beach-safety endpoint response (may need UV field surfaced).

---

## FIX-23: Admin marine location editor missing features that wizard has

**Symptom:** When adding/editing a marine location in the admin, the map does not appear for selecting coordinates. The admin marine editor must have feature parity with the wizard's marine step — every capability the wizard has for location setup must also be in the admin.

**Known gaps (confirmed and to verify):**
- **Map** for selecting/viewing location coordinates — missing in admin, present in wizard
- **Refresh Coverage button** — does not work when adding a new location in the admin
- **Save hangs** — adding/editing a location hangs on save every time. Eventually succeeds (second attempt worked) but the UX is janky — long hang with no feedback. Likely the `/setup/apply` call taking too long (NWPS WFO resolution, API restart, or the 422 retry). Needs a loading indicator at minimum, and the underlying slowness needs diagnosed.
- **Admin dashboard crashes with Internal Server Error after save attempt.** Root cause found in logs: `jinja2.exceptions.UndefinedError: 'builtin_function_or_method object' has no attribute 'items'` at `templates/config/dashboard.html:149`. The template does `{% for k, v in s.values.items() %}` — `s.values` is Python's builtin `dict.values()` method, not a dict. Calling `.items()` on the method object crashes the Jinja render. This may have been introduced by a marine config section whose structure doesn't match what the dashboard template expects. **This crash blocks the entire admin config page, not just marine.**
- **Coverage panel "Refresh Coverage" finds data but doesn't save it.** Clicking Refresh Coverage discovers NDBC buoys, CO-OPS stations, NWS zones, OFS models — but none of it persists to the location config. The coverage panel is display-only; it doesn't write the discovered station IDs back into the location's config fields (ndbc_station_ids, coops_station_ids, nws_marine_zone_id, etc.).
- **New locations added through admin show no data on the dashboard** — direct consequence of the above. Without provider IDs populated, the API has nothing to query for that location. The admin needs the same "Discover Nearby Stations" flow as the wizard that populates these IDs into the location config on save.
---

## FIX-25: Boating page — wind completely missing, needs full redesign

**Symptom:** Wind information is completely absent from the boating page despite being the single most important data point for mariners. The page needs a full layout redesign.

**Required cards/layout:**

1. **Current Conditions Card (2x2):** Reuse the Now page's current conditions card pattern — air temp, sky condition, humidity, barometric pressure, visibility. This is the at-a-glance weather picture.

2. **Forecast Card (2x2):** Multi-day forecast similar to the Now page's forecast card pattern. Weather icons, highs/lows, wind, precipitation chance per period.

3. **Wind Card (separate current conditions card):** Wind speed, gust, direction, trend. This is critical for boating and currently completely missing. Same data sourcing rules as FIX-14 — local/coastal wind, not offshore buoy.

4. **Swell Card (separate current conditions card):** Wave height, period, direction, sea state. Mariners need to know what the water is doing.

5. **NWS Coastal Waters Forecast:** The NWS marine zone forecast for coastal waters. Should be displayed in a card styled like the other forecast cards — not raw text dump. This covers the waters near the harbor/coast.

6. **NWS Offshore Forecast:** The NWS offshore waters forecast. Separate card from coastal. Boats MOVE — a mariner launching from a harbor will transit through coastal waters and potentially into offshore waters. They need both forecasts, not just the point forecast for the harbor location.

**Key design distinction from surfing/fishing:** Surfing and fishing are stationary activities at a fixed point. Boating is mobile — the operator configures a harbor/launch point, but the mariner needs forecasts for the waters they'll transit through (coastal zone AND offshore zone), not just the conditions at the dock. The page must present both the local point conditions AND the broader marine area forecasts.

**Marine/coastal alert strip** — same as FIX-19, required at top of page. Especially important for boating — Small Craft Advisories, Gale Warnings, etc. are life-safety for mariners.

**Design reference:** Now page cards for current conditions and forecast. Same card anatomy, tokens, stat tile patterns.

**Files:** TBD — dashboard boating tab component, API marine endpoint (NWS coastal/offshore forecast text may need a new field or endpoint).

---

## FIX-24: Now page takes ~15 seconds to load — API cold-call performance

**Symptom:** The Now page takes ~15 seconds to load. Direct API timing confirms the problem is server-side, not network or dashboard:
- `/api/v1/current` — **6.2s** cold, 1.3s cached
- `/api/v1/forecast` — **11s** cold, fast when cached
- `/api/v1/station` — 38ms (fine)
- `/api/v1/alerts` — 86ms (fine)

**Root cause (needs investigation):**
- `/forecast` cold call is 11s — the forecast provider (Aeris) is either slow to respond or the enrichment pipeline (GFE text generation, forecast correction engine) is expensive on first call.
- `/current` cold call is 6.2s — some enrichment step is expensive (conditions text engine? sky classifier? unit conversion on first run?).
- The cache warmer is supposed to pre-populate these at startup so visitors never hit cold calls. Either it's not warming these endpoints, or TTLs are expiring between warm cycles and visitors hit the gap.

**This is NOT a marine issue.** It's a core API performance problem affecting the main Now page. The dashboard makes these calls in parallel on page load; the slowest one (forecast at 11s) determines the total load time.

**Fix:** Investigate why cold calls are so slow. Verify the cache warmer is pre-populating `/current` and `/forecast`. Check if TTLs are aligned with warm cycles so there's no gap where a visitor gets a cold call.
- **Discover Nearby Stations** button (HTMX call to find NDBC buoys, CO-OPS stations, NWS zones) — verify present in admin
- **Bathymetry download** trigger — verify present in admin
- **Structure discovery** (Overpass API for jetties, piers, etc.) — verify present in admin
- **Species checklist** based on coordinate + fishing category — verify present in admin
- **Coverage panel** (data source availability for the coordinates) — verify present in admin
- **Photo upload with attribution** (FIX-4) — verify present in admin

**Rule:** The admin is the ongoing config interface. Operators should never have to re-run the wizard to access a feature that should be available in the admin. Every interactive capability in the wizard's marine step must have an equivalent in the admin marine editor.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/admin/marine.html`
- `repos/weewx-clearskies-stack/weewx_clearskies_config/admin/routes.py`
- Compare against wizard: `templates/wizard/step_marine.html` + `wizard/routes.py`

---

**Solunar card:** This is NOT a new component — it is the **same Sun/Moon card from the Almanac page**, reused. The Almanac page already has this card with the arc, moonrise/moonset, moon phase, illumination percentage. Just use the existing component on the fishing page. Do not build a separate solunar card. If solunar major/minor feeding period information is added, it must be added TO the existing Almanac Sun/Moon card and match its design style — not bolted on as a separate element.

**Files:** TBD — dashboard fishing forecast component, API fishing endpoint (may need to include weather forecast data and species-specific scoring per period). Solunar card = reuse Almanac Sun/Moon component.
