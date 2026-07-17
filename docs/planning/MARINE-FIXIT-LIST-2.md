# Marine Fixit List 2 — Post-Fixit-Plan Findings

**Created:** 2026-07-16
**Origin:** User walkthrough of the live site after MARINE-FIXIT-PLAN Phases 0-8 were all marked "✅ COMPLETE." Multiple findings: the admin save hangs for 2+ minutes (full API restart on every config change), location cards show no data despite correct configuration, and the surf page visual output does not match the plan's spec despite the code existing in the repo.

## Findings

### FIX2-1: Admin/wizard config save restarts the entire API (2+ minute downtime)

**Severity:** Critical — operational
**Surfaces:** Admin marine save, admin config saves, wizard re-run apply

**Problem:** Every configuration change triggers a full API process restart via `POST /setup/restart` → SIGTERM → systemd restart → 2-minute cache warmer. During this window the API is completely offline — visitors get connection refused, SSE drops, dashboard shows errors. The marine admin save is the worst case: it also runs synchronous NWS WFO lookups and CUDEM bathymetry downloads during `POST /setup/apply` before the restart.

Additionally, non-marine admin config saves (`config_section_post` in admin/routes.py) write directly to `.conf` files via `update_managed_region()` but never signal the API to reload — the change is written to disk but silently doesn't take effect until the next restart.

**Root cause:** The API has no hot-reload mechanism. All config is loaded once at startup and baked into module-level globals. The only way to apply config changes is a full process restart.

**Resolution:** ADR-092 (Accepted 2026-07-16) — implement `POST /setup/reload` endpoint that re-reads `api.conf` and swaps config in-memory without process restart. Admin and wizard re-run use reload instead of restart. Full restart reserved for Tier 2 changes (database, TLS, bind address, provider identity swap).

**Files:**
- API: new `config/reload.py` module, new endpoint in `endpoints/setup.py`
- API: all `wire_*()` functions (already exist, need registration in reload dispatcher)
- Stack: `admin/routes.py` — replace `_restart_api_after_apply()` with reload call
- Stack: `wizard/routes.py` — wizard re-run apply uses reload, falls back to restart for Tier 2

### FIX2-2: Huntington Harbor location card shows no data despite correct configuration

**Severity:** High — data display
**Surfaces:** Marine landing page (`/marine`)

**Problem:** The Huntington Harbor location card shows dashes for Wave Height, Wind, and Water Temp. The API returns `waveHeight: null`, `waterTemp: null` for this location despite having `ndbc_station_ids = prjc1` and `coops_station_ids = 9410660` correctly configured. The API does return `windSpeed: 5.51` and `airTemp: 69.8` but the card still shows Wind as a dash.

**Root cause (two parts):**
1. **NDBC station `prjc1` is a C-MAN station** (Coastal Marine Automated Network), not a buoy. C-MAN stations report wind and air temp but have no wave sensors and no water temp sensors. The location needs wave data from either an NDBC buoy with wave sensors (e.g., 46253 which serves the Pier location) or from the NWPS/WaveWatch III model forecast. The API does return forecast wave data for this location (from WW3) but the landing page card only displays observation data, not forecast data.
2. **Wind IS returned by the API (5.51 kt) but the card shows a dash.** This suggests either a field mapping bug in the `LocationCard.tsx` component or the `MarineLocationSummary` list endpoint is not passing the wind value through. Need to verify: does `GET /api/v1/marine` (list) return windSpeed for Huntington Harbor in `currentConditions`?

**Additional context:** The API's `GET /api/v1/marine` response confirmed at 2026-07-16:
- `huntington-harbor.currentConditions.windSpeed = 5.51` (from prjc1 C-MAN)
- `huntington-harbor.currentConditions.waveHeight = null` (no buoy wave sensor)
- `huntington-harbor.currentConditions.waterTemp = null` (no water temp sensor)
- Forecast data exists (WW3 waveHeight ~1.7ft) but is not surfaced on the card

**Resolution options:**
1. Card should fall back to forecast wave height when observation is null
2. Card should display wind data that IS available (it's returned but not rendering)
3. Location may need a nearby buoy with wave sensors added to its station list, OR the landing card should use NWPS/WW3 model data for wave height when no buoy is configured
4. Water temp should come from the ocean data resolver (OFS/ERDDAP) — this location has `ofs_model = WCOFS` configured

### FIX2-3: MARINE-FIXIT-PLAN Phases 4-7 — code was committed but does not produce the specified output

**Severity:** Critical — the entire marine UI redesign failed to deliver
**Surfaces:** All marine activity pages (surf, fishing, beach safety, boating), marine landing page

**Problem:** The MARINE-FIXIT-PLAN marked Phases 4 through 7 as "✅ COMPLETE" with commit hashes. Agents wrote code and committed it. But the live site does not match what the plan specified. The code is wrong — the agents produced incorrect implementations and self-attested completion without verifying the visual output against the spec.

This is the same pattern that burned C1-C6 (see `rules/clearskies-process.md` "UI implementation quality gates"): agents commit code with correct-sounding commit messages, QC gates check that the code compiles and builds, but nobody compares the rendered output to the spec. The plan's "✅ COMPLETE" markers are false.

**What the surf page plan (T5.1) specified:**
1. Score Card (2x2): prominent numeric score + scoring breakdown factors
2. Swell Card (2x1): wave height at break, period, direction, model-processed swell components, compass
3. Wind Card (2x1): wind speed, direction, quality label, gust
4. No star ratings anywhere
5. All cards match Now page design patterns

**What the surf page actually shows:** Does not match the spec. The operator confirmed the live page does not look like what was asked for.

**Scope of failure:** This is not just the surf page. The same agents wrote Phases 4 (landing page), 5 (surf), 6 (fishing), and 7 (beach safety + boating) — all in a single session, all self-attested as complete. Every phase's visual output must be re-verified against the spec. QC Gates 4-7 were all "deferred to post-deploy visual verification" — meaning they were never actually run.

**Root cause:** QC Gates 4-7 all say "deferred to post-deploy visual verification" in their execution status. This means the adversarial auditors were never spawned for the dashboard UI phases. The code was committed without any visual verification. This directly violates the "Code-complete requires coordinator visual sign-off" rule in clearskies-process.md.

**Resolution:** Every dashboard component modified by Phases 4-7 must be visually verified against the plan spec on the live site. Anything that doesn't match gets rewritten. This is not a "tweak CSS" situation — if the agents produced fundamentally wrong layouts, the components need to be rebuilt.

### FIX2-4: weatherCode and isDay null on all marine location cards

**Severity:** Medium — UI
**Surfaces:** Marine landing page (`/marine`)

**Problem:** Both locations return `weatherCode: null` and `isDay: false` (or null) in the API response. The weather icon never renders on location cards. T2.3 (commit `81f63d0`) was supposed to fix this by reading from the top-level fields instead of inside `currentConditions`, but the API itself is returning null for these fields.

**Root cause:** The API's marine list endpoint (`GET /api/v1/marine`) populates `weatherCode` and `isDay` from the forecast provider's current conditions, but this may not be running for marine locations, or the forecast provider's response for these coordinates isn't being mapped to the marine summary.

### FIX2-5: Marine admin save runs redundant network calls

**Severity:** Medium — performance
**Surfaces:** Admin marine save, wizard re-run apply

**Problem:** Every `POST /setup/apply` runs `_resolve_marine_wfo()` (NWS HTTP call per location) and `_resolve_marine_bathymetry()` (CUDEM download per surf spot) — even when coordinates haven't changed. For an admin edit that only changes a location name or species list, these are completely unnecessary network calls that add seconds to the save time on top of the restart.

**Resolution:** Compare the incoming payload against current config. Skip WFO resolution for locations whose lat/lon haven't changed. Skip bathymetry download for locations that already have a profile and whose coordinates haven't changed.
