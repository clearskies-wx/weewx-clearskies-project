# Provider Attribution Compliance Brief

**Date:** 2026-06-30
**Purpose:** Audit all external data providers for attribution requirements, identify gaps, and inform a compliance plan.

---

## Provider Inventory & Attribution Requirements

### 1. Xweather (Vaisala)

| Field | Detail |
|-------|--------|
| **Used for** | Forecast, AQI, Alerts |
| **Formal name** | **Xweather** (product/division name), owned by **Vaisala** (parent company). Formerly "AerisWeather" — rebranded Mar 2024. The "Aeris" name is fully retired and no longer appears on xweather.com. |
| **Rebrand timeline** | Jan 2022: Vaisala acquires AerisWeather. Sep 2022: "Xweather" brand launched. Mar 2024: formal rebrand complete; aerisweather.com phased out. Apr 2024: API domain changed to `data.api.xweather.com` (old `api.aerisapi.com` still works). |
| **Attribution required?** | **Yes — mandatory** |
| **Required text** | "powered by Vaisala Xweather" linked to `https://www.xweather.com/` |
| **Logo required?** | **Yes — logo can substitute for text attribution.** Multiple SVG/PNG variants available (dark and light backgrounds). Must maintain 10px white space buffer. No rotation, recoloring (except monotone), or using symbol alone without name. |
| **Logo download** | Available at `https://www.xweather.com/docs/weather-api/resources/attribution` |
| **ToS** | `https://www.xweather.com/legal/terms` |
| **Current state** | About page lists "Aeris Weather (DTN)" with link to `aerisweather.com`. **Problems:** (1) Name is outdated — should be "Xweather" or "Vaisala Xweather", not "Aeris Weather (DTN)". (2) No logo displayed. (3) No "powered by" text. (4) URL should be `xweather.com`, not `aerisweather.com`. |
| **Data source credits** | Xweather aggregates from NWS, Environment Canada, and many others. Their attribution guide at `/docs/weather-api/resources/credits` lists the upstream sources. Since we use Xweather as the intermediary, attributing Xweather satisfies the chain. |
| **Naming rule for our codebase** | Internal identifiers (`aeris` as provider_id, module names like `providers/forecast/aeris.py`, config keys like `aeris_forecast_model`, `AERIS_CLIENT_ID` env vars) stay as-is — these are stable machine identifiers. All **human-visible text** (UI labels, wizard text, admin labels, about page, operator_notes, log messages, documentation) must say "Xweather" not "Aeris Weather" / "AerisWeather" / "Aeris Weather (DTN)". PWSWeather (the PWS contributor program) still uses the PWSWeather name, but its footer reads "© 2026 Vaisala Xweather". |

### 2. US National Weather Service (NWS / NOAA)

| Field | Detail |
|-------|--------|
| **Used for** | Forecast, Alerts |
| **Formal name** | National Weather Service (NWS), part of NOAA |
| **Attribution required?** | **Recommended (public domain)** — not legally required, but USGS/NOAA policy requests credit |
| **Required text** | None mandated. Recommended: "Data courtesy of the U.S. National Weather Service" |
| **Logo required?** | **No** |
| **Logo available?** | NWS/NOAA logos exist but are U.S. government marks — use only to indicate the source of data, not to imply endorsement |
| **ToS** | Public domain. API docs: `https://www.weather.gov/documentation/services-web-api`. User-Agent header required (not visitor-facing). |
| **Current state** | About page lists "US National Weather Service / NOAA" — **adequate**. Could use the more formal "National Weather Service" without abbreviation. |

### 3. Open-Meteo

| Field | Detail |
|-------|--------|
| **Used for** | Forecast, AQI |
| **Formal name** | Open-Meteo |
| **Attribution required?** | **Yes — mandatory (CC BY 4.0)** |
| **Required text** | Must include a hyperlink: `<a href="https://open-meteo.com/">Weather data by Open-Meteo.com</a>` — placed next to where data is displayed |
| **Logo required?** | **No** |
| **ToS** | `https://open-meteo.com/en/licence` — free tier is non-commercial only; commercial use requires a paid subscription |
| **Current state** | About page lists "Open-Meteo" with link — satisfies the hyperlink requirement. Free tier is non-commercial only; operators are responsible for reviewing Open-Meteo's terms for their use case. |

### 4. OpenWeatherMap (OpenWeather)

| Field | Detail |
|-------|--------|
| **Used for** | Forecast, AQI (deprecated), Alerts, Radar (model precipitation) |
| **Formal name** | OpenWeather (company), OpenWeatherMap (product/API) |
| **Attribution required?** | **Yes — mandatory for Free through Professional tiers** |
| **Required text** | "Weather data provided by OpenWeather" linked to `https://openweathermap.org/` |
| **Logo required?** | **Yes — mandatory for Free through Professional tiers.** OpenWeather logo must appear in a visible location. Multiple logo styles available (master logo, negative version, screen/print formats). Must maintain breathing space around logo, no skewing, no altering typeface/symbol placement. |
| **Logo download** | Brand guidelines: `https://openweather.co.uk/brand_guidelines`. Logo zip: `https://openweathermap.org/payload/api/files/file/logo_files.zip` |
| **ToS** | `https://openweathermap.org/terms` — data under ODbL |
| **Current state** | About page lists "OpenWeatherMap" with link. **Problems:** (1) No logo displayed — logo is required. (2) No "provided by" language. |

### 5. Weather Underground

**Not in use.** Weather Underground was dropped as a forecast provider because it did not provide enough weather data for full site operation (e.g., insufficient data for the sky condition engine). The module exists in the API dispatch registry but is not offered in the setup wizard.

**Doc-code drift:** The PROVIDER-MANUAL (§4) lists Weather Underground as a day-1 forecast provider. The about page has a `PROVIDER_INFO` entry for `wunderground` that will never appear. Both should be corrected.

### 6. IQAir

| Field | Detail |
|-------|--------|
| **Used for** | AQI |
| **Formal name** | IQAir |
| **Attribution required?** | **Yes** — ToS requires identifying IQAir as owner/licensor when displaying their content |
| **Required text** | No specific wording given. General requirement: "identify us as the owners or licensors" when displaying their data |
| **Logo required?** | **Not explicitly required** — but they reserve all rights to their trademarks and logos |
| **ToS** | `https://www.iqair.com/legal/terms-conditions` |
| **Current state** | About page lists "IQAir" with link — **probably adequate**, but could be more explicit (e.g., "Air quality data by IQAir"). |

### 7. OpenAQ

| Field | Detail |
|-------|--------|
| **Used for** | **Not actively used.** Module exists in the codebase but is not wired into the dispatch registry. The calibration bootstrap feature that previously used OpenAQ has been dropped. |
| **Formal name** | OpenAQ |
| **Attribution required?** | **N/A — not in use.** |
| **Current state** | Dead code. The PROVIDER-MANUAL still lists OpenAQ as a day-1 AQI provider — this is inaccurate and should be corrected (doc-code drift). No attribution action needed. |

### 8. RainViewer

| Field | Detail |
|-------|--------|
| **Used for** | Radar tiles |
| **Formal name** | RainViewer |
| **Attribution required?** | **Yes — mandatory** |
| **Required text** | Credit as data source with hyperlink to `https://www.rainviewer.com/` |
| **Logo required?** | **Not explicitly required** |
| **ToS** | `https://www.rainviewer.com/api.html` — personal/educational use only; commercial requires separate agreement |
| **Current state** | About page has "RainViewer" with link. Radar map has attribution in Leaflet control per the PROVIDER-MANUAL. **Adequate.** |

### 9. LibreWxR

| Field | Detail |
|-------|--------|
| **Used for** | Radar tiles, satellite tiles, weather alerts |
| **Formal name** | LibreWxR |
| **Attribution required?** | **Yes — AGPL-3.0 (code), CC-BY-4.0 (data)** |
| **Required text** | `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"` (per PROVIDER-MANUAL) |
| **Logo required?** | **No** |
| **License** | AGPL-3.0 (code), CC-BY-4.0 (data). Attribution in Leaflet control on radar map. |
| **Current state** | Shows on the about page when selected (via the capabilities API fallback), but renders as raw "librewxr" with no proper display name or link — `librewxr` is not in the `PROVIDER_INFO` map. Needs a proper entry: `{ name: 'LibreWxR', url: 'https://librewxr.net/' }`. Radar map Leaflet attribution is handled separately. |

### 10. OpenStreetMap

| Field | Detail |
|-------|--------|
| **Used for** | Base map tiles (radar page, seismic page), geographic features overlay (PMTiles) |
| **Formal name** | OpenStreetMap |
| **Attribution required?** | **Yes — mandatory (ODbL)** |
| **Required text** | `"© OpenStreetMap contributors"` or `"© OpenStreetMap"` — must link to `https://www.openstreetmap.org/copyright`. Must be visible in a corner of the map. |
| **Logo required?** | **No** |
| **License** | ODbL (Open Database License) |
| **Current state** | In-map Leaflet attribution is present on seismic and radar pages. **MISSING from the about page.** |

### 11. USGS

| Field | Detail |
|-------|--------|
| **Used for** | Earthquake data |
| **Formal name** | U.S. Geological Survey |
| **Attribution required?** | **Recommended (public domain)** — not legally required |
| **Required text** | Recommended: "Earthquake data courtesy of the U.S. Geological Survey" |
| **Logo required?** | **No** |
| **License** | U.S. Public Domain |
| **Current state** | About page lists "US Geological Survey / US Dept. of the Interior" — **adequate.** |

### 12–14. GeoNet, EMSC, ReNASS

**Not in use — decision pending on whether to keep or remove.**

USGS has worldwide coverage (M2.5+ globally) and is the only earthquake provider offered in the setup wizard. GeoNet (New Zealand only), EMSC (Europe/Mediterranean), and ReNASS (France only) are single-country or single-region providers that add limited value over USGS's global coverage.

**Current state:** ADR-040 authorized all four and the module code was built and wired into the API dispatch registry, but the wizard implementation only shipped USGS. Operators have no way to select the other three. The rationale in ADR-040 for rejecting USGS-only (Option C) was GeoNet's NZ-native MMI and ReNASS's French-language descriptions — both niche benefits for a narrow operator population.

**Open question:** Whether to keep these modules (and eventually expose them in the wizard) or remove them entirely. Single-country coverage providers may not justify the maintenance burden. To be decided separately from the attribution work.

**What needs correction regardless:** The PROVIDER-MANUAL (§9) lists all four as "day-1 providers" with regional wizard suggestions that don't exist. The about page has `PROVIDER_INFO` entries for `geonet`, `emsc`, and `renass` that will never appear. Both should reflect reality: USGS is the only earthquake provider.

### 15. GEM Global Active Faults Database

| Field | Detail |
|-------|--------|
| **Used for** | Fault line overlay on seismic page |
| **Formal name** | GEM Global Active Faults Database, by the GEM Foundation |
| **Attribution required?** | **Yes — CC-BY-SA 4.0** |
| **Required text** | "Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0" |
| **Logo required?** | **No** |
| **Current state** | In-map Leaflet attribution is present on the seismic page. **MISSING from the about page.** |

### 16. 7Timer

| Field | Detail |
|-------|--------|
| **Used for** | Astronomical seeing forecast |
| **Formal name** | 7Timer! |
| **Attribution required?** | **Unclear** — no formal ToS found. Service is free for non-commercial use. |
| **Required text** | None documented |
| **Logo required?** | **No** |
| **Current state** | About page lists "7Timer! Astronomical Seeing Forecast" — **adequate** given the lack of formal requirements. |

### 17. AstronomyAPI.com

| Field | Detail |
|-------|--------|
| **Used for** | Eclipse contact times, altitudes, obscuration data (optional — graceful degradation to Skyfield when not configured) |
| **Formal name** | Astronomy API, developed by CodeBreez (Colombo, Sri Lanka) |
| **Attribution required?** | **No.** ToS reviewed (last revised April 11, 2020). Section 6.1 grants a "personal, worldwide, royalty-free, non-assignable and non-exclusive license." No attribution clause exists in the ToS — unlike CC BY licenses, there is no requirement to credit the service when displaying data. |
| **Logo required?** | **No — and do not use.** Section 12.2: "nothing in the Terms gives you a right to use any of CodeBreez's trade names, trademarks, service marks, logos, domain names, and other distinctive brand features." Using their logo without separate written permission would violate their terms. |
| **Required text** | None |
| **ToS** | `https://astronomyapi.com/terms-of-service` |
| **Current state** | About page lists "Astronomy API" — **adequate.** No attribution is required by their terms, and we should not display their logo. The about page listing is a courtesy. |

### 18. Skyfield + NASA JPL Ephemerides

| Field | Detail |
|-------|--------|
| **Used for** | All almanac calculations (sun/moon/planet positions, eclipses, meteor shower radiant) |
| **Formal name** | Skyfield (by Brandon Rhodes), using NASA JPL DE421 ephemeris data |
| **Attribution required?** | **Recommended** — MIT license (Skyfield). NASA/JPL ephemeris data is public domain. |
| **Required text** | None required for MIT; good practice to credit |
| **Logo required?** | **No** |
| **Current state** | **MISSING from the about page.** Skyfield and NASA JPL are not credited anywhere visitor-facing. |

### 19. Protomaps

| Field | Detail |
|-------|--------|
| **Used for** | PMTiles geographic features overlay (via protomaps-leaflet) |
| **Formal name** | Protomaps |
| **Attribution required?** | **No (requested, not required).** The underlying OSM data requires `"© OpenStreetMap"` attribution. Protomaps itself uses CC0 for the map design and BSD-3 for code. They "kindly request" attribution but do not require it. |
| **Required text** | None required for Protomaps itself. OSM attribution is the legal requirement. |
| **Logo required?** | **No** |
| **Current state** | Protomaps is not mentioned on the about page, but OSM attribution covers the legal requirement. Geographic features overlay on radar page has `"© OpenStreetMap contributors (ODbL)"` in the Leaflet control. **Adequate legally**, though a courtesy mention would be polite. |

### 20–21. MSC GeoMet (Canada), DWD RADOLAN (Germany)

**Not in use.** These radar providers are not offered in the setup wizard. The only radar providers exposed to operators are RainViewer and LibreWxR, which together cover most of the world. Module code exists in the API dispatch registry but was never surfaced to operators — same situation as the non-USGS earthquake providers.

**Doc-code drift:** The PROVIDER-MANUAL (§7) lists MSC GeoMet and DWD RADOLAN as active radar providers with a note "(not in wizard — regional)." The about page has `PROVIDER_INFO` entries for `msc_geomet` and `dwd_radolan` that will never appear. Both should be corrected to reflect reality.

### 22. IMO / AMS (Meteor Shower Catalog)

| Field | Detail |
|-------|--------|
| **Used for** | Meteor shower ZHR, velocity, radiant coordinates, descriptions |
| **Formal name** | International Meteor Organization (IMO) + American Meteor Society (AMS) |
| **Attribution required?** | **Recommended** — static catalog data derived from published scientific lists |
| **Required text** | None formally required. Good practice: "Meteor shower data: International Meteor Organization" |
| **Logo required?** | **No** |
| **Current state** | **MISSING from the about page.** |

### 23. CARTO (CartoDB)

| Field | Detail |
|-------|--------|
| **Used for** | Dark basemap tiles on seismic page |
| **Formal name** | CARTO |
| **Attribution required?** | **Yes** — per their ToS |
| **Required text** | `"© CARTO"` with link to `https://carto.com/attributions` |
| **Logo required?** | **No** |
| **Current state** | In-map Leaflet attribution is present on seismic page. **MISSING from the about page.** |

---

## Live Site Verification (2026-06-30)

Verified against `weather.shaneburkhardt.com/about` — screenshot reviewed. Current Data Providers card shows:

| Domain | Displayed text | Issue |
|--------|---------------|-------|
| ALERTS | US National Weather Service / NOAA | OK |
| AIR QUALITY | Aeris Weather (DTN) | **Wrong name** — should be "Xweather (Vaisala)" |
| EARTHQUAKES | US Geological Survey / US Dept. of the Interior | OK |
| FORECAST | Aeris Weather (DTN) | **Wrong name** — should be "Xweather (Vaisala)" |
| RADAR | Librewxr | **Raw provider ID** — CSS capitalize renders "Librewxr" instead of proper "LibreWxR". No link. Needs `PROVIDER_INFO` entry. |
| ASTRONOMICAL SEEING | 7Timer! Astronomical Seeing Forecast | OK |
| ASTRONOMY | Astronomy API | OK |

**Missing from the page entirely:** OpenStreetMap (base map tiles), GEM Global Active Faults (seismic overlay). Neither Xweather nor OpenWeatherMap logos are present.

---

## Gap Summary

### Missing from About Page (PROVIDER_INFO map)

These providers are used by Clear Skies but have no entry in the about page's `PROVIDER_INFO`:

| Provider | Severity | Why it matters |
|----------|----------|----------------|
| **OpenAQ** | None | Dead code — not wired, bootstrap dropped. PROVIDER-MANUAL needs correction. |
| **LibreWxR** | High | Active radar/satellite provider, CC-BY-4.0 data license. Shows on about page but as raw "Librewxr" (CSS capitalize on the provider ID) — needs `PROVIDER_INFO` entry with proper name "LibreWxR" and URL. **Verified on live site 2026-06-30.** |
| **OpenStreetMap** | High | Base map tiles on two pages, ODbL requires attribution |
| **GEM Global Active Faults** | Medium | CC-BY-SA 4.0 requires attribution; only in-map currently |
| **Skyfield / NASA JPL** | Low | MIT license (recommended, not required) |
| **IMO / AMS** | Low | Scientific catalog (recommended, not required) |
| **CARTO** | Low | Only used for dark seismic basemap; in-map attribution present |
| **Protomaps** | Low | Requested but not required; OSM attribution covers the legal need |

### Incorrect or Outdated Information

| Issue | Current | Should be |
|-------|---------|-----------|
| Aeris name | "Aeris Weather (DTN)" | "Xweather (Vaisala)" or "Vaisala Xweather" |
| Aeris URL | `aerisweather.com` | `xweather.com` |
| ReNASS URL | `renass.unistra.fr` | `franceseisme.fr` or `epos-france.fr` |
| GeoNet license | PROVIDER-MANUAL says CC BY 4.0 | Actual license is CC BY 3.0 NZ |

### Logo Requirements Not Met

| Provider | Requirement | Current state |
|----------|-------------|---------------|
| **Xweather** | Logo OR "powered by Vaisala Xweather" text — mandatory | Neither present. Text link only, using wrong name. |
| **OpenWeatherMap** | OpenWeather logo in visible location — mandatory for Free–Professional tiers | No logo. Text link only. |

### Attribution Text Not Meeting Specific Wording

| Provider | Required wording | Current wording |
|----------|-----------------|-----------------|
| Xweather | "powered by Vaisala Xweather" | "Aeris Weather (DTN)" |
| OpenWeatherMap | "Weather data provided by OpenWeather" | "OpenWeatherMap" |
| Open-Meteo | "Weather data by Open-Meteo.com" (hyperlinked) | "Open-Meteo" (hyperlinked) — close but not exact |
| EMSC | "Credit: EMSC/CSEM" | "European-Mediterranean Seismological Centre" — acceptable but not their preferred format |

---

## Logo Asset Status

### Required by ToS

| Provider | Format | Source | Repo path |
|----------|--------|--------|-----------|
| **Xweather** | SVG (dark + light) | `xweather.com/docs/weather-api/resources/attribution` | `src/assets/providers/xweather-dark.svg`, `xweather-light.svg` |
| **OpenWeatherMap** | PNG (master + negative) | `openweather.co.uk/brand_guidelines` | `src/assets/providers/openweathermap-master.png`, `openweathermap-negative.png` |

Note: OpenWeather provides AI/EPS/JPG/PNG but no SVG. The PNGs are the screen-resolution originals from their official zip. If SVG is needed, the EPS files from the same zip can be converted.

### Needed for forecast card/page design (all four forecast providers)

Even where not required by ToS, logos are needed so the forecast card/page can show the active provider's mark consistently regardless of which provider the operator configured.

| Provider | Format | Repo path | Usage rules |
|----------|--------|-----------|-------------|
| **Xweather** | SVG | `src/assets/providers/xweather-dark.svg`, `xweather-light.svg` | 10px buffer, no recoloring except monotone, no symbol alone without name |
| **OpenWeatherMap** | PNG | `src/assets/providers/openweathermap-master.png`, `openweathermap-negative.png` | Maintain spacing, no skewing/distortion, no altering typeface |
| **Open-Meteo** | PNG (512×512 app icon — "om" mark) | `src/assets/providers/open-meteo.png` | No formal usage rules; logo not required by their ToS. No official SVG exists — this is the highest-res asset from their GitHub repo. |
| **NWS** | SVG (400×400 seal) | `src/assets/providers/nws.svg` | U.S. government mark — use to indicate data source only, do not imply endorsement. Public domain. |

All paths are relative to `repos/weewx-clearskies-dashboard/`.

### Do NOT use

| Provider | Why |
|----------|-----|
| **AstronomyAPI** | ToS §12.2 reserves all trademark/logo rights — using their logo without separate written permission violates their terms |
| **IQAir** | ToS reserves all trademark/logo rights — do not use without separate written permission |

---

## Recommendations for Compliance Plan

### P0 — Must fix (ToS/license violations)

1. **Add Xweather logo or "powered by" text** — currently violating their attribution policy. Download their logo assets. Update formal name from "Aeris Weather (DTN)" to "Xweather (Vaisala)". Update URL.
2. **Add OpenWeatherMap logo** — currently violating their Free–Professional tier attribution requirements. Download their logo assets.
3. **Add LibreWxR to the about page** — CC-BY-4.0 data license requires attribution; provider is missing.
4. **Add OpenStreetMap to the about page** — ODbL requires attribution beyond just the in-map control; a general credit on the about page is good practice.

### P1 — Should fix (best practice / requested)

5. **Update Open-Meteo attribution wording** to match their recommended text: "Weather data by Open-Meteo.com".
6. **Add GEM Global Active Faults** to the about page — CC-BY-SA 4.0.
7. **Update ReNASS/EPOS-France URL** — legacy domain.
8. **Verify GeoNet license version** — PROVIDER-MANUAL says CC BY 4.0 but website shows CC BY 3.0 NZ.
9. **Update OpenWeatherMap attribution text** to "Weather data provided by OpenWeather".

### P2 — Nice to have (courtesy/completeness)

10. **Add Skyfield + NASA JPL** to the about page — MIT/public domain, credit is good practice.
11. **Add IMO/AMS** meteor shower catalog credit.
12. **Add CARTO** credit.
13. **Add Protomaps** courtesy mention.
14. **Correct PROVIDER-MANUAL** — OpenAQ is listed as a day-1 AQI provider but is not wired into the dispatch registry and the bootstrap feature was dropped. Remove from day-1 set or mark as unimplemented.
15. **Review AstronomyAPI.com ToS manually** — their terms page would not render; need to check in a browser.

### Design Considerations

**Two-layer attribution model:**

1. **About page** — lists provider names as plain text links. This is the centralized index. No marketing language ("powered by"), no logos. Just the organization name linked to their site. The about page already dynamically shows only the providers that are active (via the capabilities API).

2. **In-context attribution** — provider-required text ("powered by Vaisala Xweather"), logos, and specific wording go on the pages where that provider's data is actually displayed. This is where ToS-mandated attribution lives:
   - Xweather "powered by" text or logo → forecast page, forecast card on the Now page, AQI card, alert banner — wherever Xweather data appears
   - OpenWeatherMap logo → same pattern, on the pages/cards showing OWM data
   - RainViewer / LibreWxR / OSM → already handled via Leaflet attribution controls on the radar and seismic maps
   - GEM Active Faults → already handled via Leaflet attribution on the seismic map

**Where exactly the in-context attribution goes (text vs. logo, card footer vs. page footer, etc.) is a design decision for the implementation plan — not decided here.**

- **i18n:** Attribution text that is required by ToS should generally NOT be translated — the provider specifies exact English wording. The surrounding UI labels ("Data Providers", etc.) should remain translatable.
- **Operator-conditional:** In-context attribution should follow the same logic as the about page — only show a provider's attribution when that provider is configured. If an operator uses NWS instead of Xweather, no Xweather attribution appears anywhere.

---

## Aeris → Xweather Naming Migration Scope

The "Aeris Weather" / "AerisWeather" name is fully retired. The official name is now **Xweather** (product) / **Vaisala Xweather** (formal/legal). This requires changes across four layers:

### What changes

| Layer | What to update | Example |
|-------|---------------|---------|
| **Dashboard** | `PROVIDER_INFO` display name and URL in about page, any translation strings | `"Aeris Weather (DTN)"` → `"Xweather (Vaisala)"`, URL → `https://www.xweather.com` |
| **Config UI (Stack)** | Wizard provider labels, admin provider section labels, help text, HTMX fragments | "Aeris" provider label in wizard step, key-fields templates |
| **API** | `operator_notes` in CAPABILITY declarations, log messages with company name, error messages, docstrings | `"Aeris developer trial"` → `"Xweather developer trial"` |
| **Documentation** | PROVIDER-MANUAL, ARCHITECTURE.md, OPERATIONS-MANUAL, API-MANUAL, all references | Every mention of "Aeris Weather" as a company/product name |

### What does NOT change

| Item | Why it stays |
|------|-------------|
| `provider_id = "aeris"` | Stable machine identifier; changing it would break operator configs |
| Module paths (`providers/forecast/aeris.py`) | File system identifiers; renaming breaks imports |
| Config keys (`aeris_forecast_model`, `aeris_aqi_filter`) | Operator config compatibility |
| Env var names (`AERIS_CLIENT_ID`, `AERIS_CLIENT_SECRET`) | Backward compatibility with existing `secrets.env` files |
| API domain in code (`api.aerisapi.com` or `data.api.xweather.com`) | Either domain works; the code should use the current `data.api.xweather.com` but this is a code fix, not a naming fix |
| Import statements | Internal code structure |

### Inventory of old-name occurrences

#### Visitor-facing (14 files)

| File | Line | Current text | Seen by |
|------|------|-------------|---------|
| `repos/weewx-clearskies-dashboard/src/routes/about.tsx` | 18 | `'Aeris Weather (DTN)'`, URL `aerisweather.com` | Site visitors (About page) |
| `repos/weewx-clearskies-dashboard/public/locales/en/legal.json` | 29 | `"Aeris Weather"` in third-party services section | Site visitors (Legal page) |
| `repos/weewx-clearskies-dashboard/public/locales/de/legal.json` | — | Same | Visitors (German) |
| `repos/weewx-clearskies-dashboard/public/locales/es/legal.json` | — | Same | Visitors (Spanish) |
| `repos/weewx-clearskies-dashboard/public/locales/fil/legal.json` | — | Same | Visitors (Filipino) |
| `repos/weewx-clearskies-dashboard/public/locales/fr/legal.json` | — | Same | Visitors (French) |
| `repos/weewx-clearskies-dashboard/public/locales/it/legal.json` | — | Same | Visitors (Italian) |
| `repos/weewx-clearskies-dashboard/public/locales/ja/legal.json` | — | Same | Visitors (Japanese) |
| `repos/weewx-clearskies-dashboard/public/locales/nl/legal.json` | — | Same | Visitors (Dutch) |
| `repos/weewx-clearskies-dashboard/public/locales/pt-BR/legal.json` | — | Same | Visitors (Portuguese-BR) |
| `repos/weewx-clearskies-dashboard/public/locales/pt-PT/legal.json` | — | Same | Visitors (Portuguese-PT) |
| `repos/weewx-clearskies-dashboard/public/locales/ru/legal.json` | — | Same | Visitors (Russian) |
| `repos/weewx-clearskies-dashboard/public/locales/zh-CN/legal.json` | — | Same | Visitors (Chinese Simplified) |
| `repos/weewx-clearskies-dashboard/public/locales/zh-TW/legal.json` | — | Same | Visitors (Chinese Traditional) |

#### Operator-facing (wizard, admin, EULA, operator_notes — ~20 files)

| File | Line(s) | Current text | Seen by |
|------|---------|-------------|---------|
| `repos/weewx-clearskies-stack/.../wizard/providers.py` | 66 | `"Aeris Weather"` (display_name) | Operators (wizard) |
| Same | 72, 119 | `signup_url="https://www.aerisweather.com/signup/"` | Operators (wizard) |
| `repos/weewx-clearskies-stack/.../docs/providers.md` | 109, 113 | `### Aeris Weather`, `Aeris (AerisWeather / Xweather)` | Operators (provider docs) |
| `repos/weewx-clearskies-stack/.../static/EULA.txt` | 44 | `Aeris Weather (aerisweather.com) — forecast and alerts data` | Operators + visitors (13 language files) |
| `repos/weewx-clearskies-api/.../providers/forecast/aeris.py` | 1, 183 | Docstring + `operator_notes`: `"Aeris (AerisWeather/Xweather)..."` | Operators (config UI, logs) |
| `repos/weewx-clearskies-api/.../providers/aqi/aeris.py` | 1 | Docstring: `"Aeris (AerisWeather/Xweather)..."` | Operators (logs) |
| `repos/weewx-clearskies-api/.../providers/alerts/aeris.py` | 1, 176 | Docstring + `operator_notes`: `"Aeris (AerisWeather/Xweather)..."` | Operators (config UI, logs) |
| `repos/weewx-clearskies-api/.../providers/radar/aeris.py` | 1, 96, 110 | Docstring, `ATTRIBUTION`, `operator_notes`: `"AerisWeather / Xweather"` | Operators (config UI, map attribution) |

#### Documentation-only (not user-facing, lower priority — 10+ files)

| File | Notes |
|------|-------|
| `docs/reference/api-docs/aeris.md` | API reference — header says "Aeris (AerisWeather / Xweather)" |
| `docs/reference/BELCHERTOWN-CONTENT-INVENTORY.md` | Historical content inventory |
| `docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md` | Design decisions reference |
| `docs/reference/FORECAST-PROVIDER-RESEARCH.md` | Research notes |
| `docs/manuals/PROVIDER-MANUAL.md` | Multiple references to "Aeris" as company name |
| `docs/manuals/OPERATIONS-MANUAL.md` | Provider references |
| `docs/ARCHITECTURE.md` | Provider references |
| `docs/archive/decisions/ADR-007-forecast-providers.md` | Archived ADR (historical, low priority) |
| `docs/archive/decisions/ADR-015-radar-map-tiles-strategy.md` | Archived ADR (historical, low priority) |
| `docs/snapshots/...` | Archived Belchertown skin snapshots (historical, do not change) |

---

## Attribution by Card and Page

This section maps every card and page to the providers whose data it displays, so the design plan knows exactly where attribution needs to go. Provider shown depends on operator configuration — all possible providers for each slot are listed.

### Provider attribution summary (quick reference)

| Provider | Required text | Logo policy |
|----------|--------------|-------------|
| **Xweather** | "powered by Vaisala Xweather" (linked to xweather.com) | **Required** (may substitute for text). SVG/PNG available, 10px buffer, no recoloring. Download: `xweather.com/docs/weather-api/resources/attribution` |
| **OpenWeatherMap** | "Weather data provided by OpenWeather" (linked to openweathermap.org) | **Required** (Free–Professional tiers). Multiple styles available. Download: `openweather.co.uk/brand_guidelines` |
| **NWS** | None required. Recommended: "Data courtesy of the National Weather Service" | Not required. Government marks — do not use to imply endorsement. |
| **Open-Meteo** | "Weather data by Open-Meteo.com" (hyperlinked) | Not required. None available. |
| **IQAir** | Identify IQAir as data owner when displaying their content | Not required. **Do not use** their logo/marks without separate written permission. |
| **RainViewer** | Credit with hyperlink to rainviewer.com | Not required. |
| **LibreWxR** | "LibreWxR — Data: CC-BY-4.0" | Not required. |
| **OpenStreetMap** | "© OpenStreetMap" linked to openstreetmap.org/copyright | Not required. No logo. |
| **USGS** | Recommended: "Earthquake data courtesy of the U.S. Geological Survey" | Not required. |
| **GEM Active Faults** | "Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0" | Not required. |
| **7Timer** | None documented | Not required. |
| **AstronomyAPI** | None required | **Do not use** their logo/marks (ToS §12.2 reserves all brand rights). |
| **Skyfield / NASA JPL** | None required (MIT / public domain) | Not applicable. |

---

### Alert Banner (site-wide, all pages)

| Possible provider | Attribution | Logo |
|-------------------|-------------|------|
| **NWS** | Recommended (not required) | Not required |
| **Xweather** | **Required:** "powered by Vaisala Xweather" | **Required** (or text) |
| **OpenWeatherMap** | **Required:** "Weather data provided by OpenWeather" | **Required** |

The alert banner appears across all pages. Attribution should be part of the banner design when Xweather or OWM is the alerts provider. NWS alerts need no attribution.

---

### Now Page Cards

#### Current Conditions (hero card)

Data source: station's own sensors via `/api/v1/current`. Enrichment (weatherText, sky condition, comfort index) is computed by the API from station data.

**No external provider attribution needed.** This is the operator's own data.

#### Today's Forecast (`now-forecast`)

| Possible provider | Attribution | Logo |
|-------------------|-------------|------|
| **Xweather** | **Required:** "powered by Vaisala Xweather" | **Required** (or text) |
| **NWS** | Recommended (not required) | Not required |
| **Open-Meteo** | **Required:** "Weather data by Open-Meteo.com" (hyperlinked) | None available |
| **OpenWeatherMap** | **Required:** "Weather data provided by OpenWeather" | **Required** |

#### Air Quality (`aqi`)

| Possible provider | Attribution | Logo |
|-------------------|-------------|------|
| **Xweather** | **Required:** "powered by Vaisala Xweather" | **Required** (or text) |
| **IQAir** | **Required:** identify as data owner | **Do not use** without permission |
| **Open-Meteo** | **Required:** "Weather data by Open-Meteo.com" (hyperlinked) | None available |

#### Earthquake (`earthquake`)

| Provider | Attribution | Logo |
|----------|-------------|------|
| **USGS** | Recommended: "Earthquake data courtesy of the U.S. Geological Survey" | Not required |

#### Radar (`radar` mini-map)

| Possible provider | Attribution | Logo |
|-------------------|-------------|------|
| **RainViewer** | **Required:** credit with link to rainviewer.com | Not required |
| **LibreWxR** | **Required:** "LibreWxR — Data: CC-BY-4.0" | Not required |
| **OpenStreetMap** | **Required:** "© OpenStreetMap" (base map tiles) | Not required |

Already handled via Leaflet attribution control on the map.

#### Wind Compass, Today's Highlights, Precipitation, Barometer, Solar Radiation, UV Index, Lightning

Data source: station's own sensors via `/api/v1/current`.

**No external provider attribution needed.**

Note: UV Index card also fetches `/api/v1/forecast` and `/api/v1/almanac` — forecast data is used for UV forecast overlay. If attribution is needed for the forecast provider, it would apply here too, but this is a minor data use within a station-data card. Design decision whether to include.

#### Sun & Moon (`sun-moon`)

Data source: Skyfield (MIT license) via `/api/v1/almanac`.

**No external provider attribution needed.** Skyfield is an open-source library, not a data provider. Courtesy credit on the about page is sufficient.

#### Webcam (`webcam`)

Data source: operator's own camera.

**No external provider attribution needed.**

---

### Forecast Page

| Possible provider | Attribution | Logo |
|-------------------|-------------|------|
| **Xweather** | **Required:** "powered by Vaisala Xweather" | **Required** (or text) |
| **NWS** | Recommended (not required) | Not required |
| **Open-Meteo** | **Required:** "Weather data by Open-Meteo.com" (hyperlinked) | None available |
| **OpenWeatherMap** | **Required:** "Weather data provided by OpenWeather" | **Required** |

Contains: daily forecast cards, hourly forecast card, forecast discussion card. All from the forecast provider. Attribution should appear once on the page (e.g., page footer or header subtitle), not repeated per card.

---

### Charts Page

Data source: station's own archive data via `/api/v1/archive`.

**No external provider attribution needed.** All chart data comes from the weewx database.

---

### Almanac Page

| Component | Provider | Attribution | Logo |
|-----------|----------|-------------|------|
| Sun/Moon detail | Skyfield | None required | N/A |
| Seeing forecast | 7Timer | None documented | Not required |
| Planet visibility | Skyfield + 7Timer | None required | N/A |
| Solar eclipses | Skyfield + AstronomyAPI (optional) | None required. **Do not use** AstronomyAPI logo. | **Do not use** |
| Lunar eclipses | Skyfield + AstronomyAPI (optional) | None required. **Do not use** AstronomyAPI logo. | **Do not use** |
| Meteor showers | Skyfield + IMO/AMS catalog | Recommended: "Meteor shower data: International Meteor Organization" | Not required |
| Monthly averages | Station archive data | None required | N/A |

---

### Seismic Page

| Component | Provider | Attribution | Logo |
|-----------|----------|-------------|------|
| Earthquake list + map | USGS | Recommended: "Earthquake data courtesy of the U.S. Geological Survey" | Not required |
| Base map tiles | OpenStreetMap / CARTO | **Required:** "© OpenStreetMap" (already in Leaflet control) | Not required |
| Fault line overlay | GEM Active Faults | **Required:** "Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0" (already in Leaflet control) | Not required |

Leaflet attribution controls already handle map-level attribution. No design changes needed unless we want to add attribution outside the map.

---

### Radar Page (expanded view)

| Component | Possible provider | Attribution | Logo |
|-----------|-------------------|-------------|------|
| Radar tiles | RainViewer | **Required:** credit with link | Not required |
| Radar tiles | LibreWxR | **Required:** "LibreWxR — Data: CC-BY-4.0" | Not required |
| Satellite tiles | LibreWxR only | Included in LibreWxR attribution | N/A |
| Weather alerts overlay | LibreWxR only | Included in LibreWxR attribution | N/A |
| Base map tiles | OpenStreetMap | **Required:** "© OpenStreetMap" | Not required |
| Geographic features | OpenStreetMap (via PMTiles) | **Required:** "© OpenStreetMap contributors (ODbL)" (already in Leaflet control) | Not required |

Leaflet attribution controls already handle all radar page attribution. No design changes needed.

---

### Records Page

Data source: station's own archive data via `/api/v1/records`.

**No external provider attribution needed.**

---

### Reports Page

Data source: station's own archive data via `/api/v1/reports`.

**No external provider attribution needed.**

---

### About Page

Already covered — plain text provider name links. No logos, no marketing text. Needs: fix Xweather name/URL, add LibreWxR `PROVIDER_INFO` entry, add OpenStreetMap and GEM entries.

---

### Legal Page

No external data displayed. Provider names appear in the third-party services disclosure (EULA text). Needs Aeris→Xweather name fix only.

---

### Summary: Cards/Pages That Need Design Work for Attribution

| Location | Why | Complexity |
|----------|-----|------------|
| **Now page: Today's Forecast card** | Xweather/OWM require logo or "powered by" text | Card footer or subtle attribution line |
| **Now page: AQI card** | Xweather requires logo or "powered by" text; IQAir requires identification | Card footer or subtle attribution line |
| **Forecast page** | Xweather/OWM require logo or "powered by" text | Page-level attribution (once, not per card) |
| **Alert banner** | Xweather/OWM require attribution when they are the alerts provider | Part of banner design |
| **About page** | Fix names, add missing providers | Text changes only, no design work |

All other pages and cards either use station data (no attribution), use providers with no attribution requirements (USGS, Skyfield, 7Timer), or already have attribution handled via Leaflet map controls (radar, seismic).

---

## Sources

- Xweather Attribution Guide: `https://www.xweather.com/docs/weather-api/resources/attribution`
- Xweather Data Credits: `https://www.xweather.com/docs/weather-api/resources/credits`
- Open-Meteo License: `https://open-meteo.com/en/licence`
- OpenWeatherMap FAQ: `https://openweathermap.org/faq`
- OpenWeather Brand Guidelines: `https://openweather.co.uk/brand_guidelines`
- RainViewer API: `https://www.rainviewer.com/api.html`
- IQAir ToS: `https://www.iqair.com/legal/terms-conditions`
- USGS Credit Policy: `https://www.usgs.gov/information-policies-and-instructions/acknowledging-or-crediting-usgs`
- OpenAQ Licenses: `https://docs.openaq.org/resources/licenses`
- EMSC/SeismicPortal Terms: `https://www.seismicportal.eu/terms.html`
- EPOS-France Data Policy: `https://seismology.epos-france.fr/data-policy/`
- OSM Attribution Guidelines: `https://osmfoundation.org/wiki/Licence/Attribution_Guidelines`
- Protomaps Data License: `https://github.com/protomaps/basemaps/blob/main/LICENSE_DATA.md`
- GEM Active Faults: `https://github.com/GEMScienceTools/gem-global-active-faults`
- NWS API FAQ: `https://weather-gov.github.io/api/general-faqs`
