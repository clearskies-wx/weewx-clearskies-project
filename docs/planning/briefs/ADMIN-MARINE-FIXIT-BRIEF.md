# Marine & Seismic Post-Deployment Fixit Brief

**Date:** 2026-07-13
**Status:** Issues identified — implementation deferred
**Origin:** Post-deployment visual review of `/admin/marine` and `/marine` dashboard page (screenshot review, 2026-07-13)

---

## Context

The admin marine locations page at `/admin/marine` was built during Phase 5 of the MARINE-CARD-DATA-SOURCE-PLAN (stack commits 8897a37, e2e1ea8, c5f907e). It lists all configured marine locations with columns for Name, Coordinates, Activities, Stations, Connectivity, and Actions. The page is functional — CRUD operations work, data persists correctly through `/setup/apply` — but the UI has several usability and consistency issues identified during post-deployment review.

**Files involved:**

Admin / Wizard (stack repo):
- Template: `weewx_clearskies_config/templates/admin/marine.html`
- Routes: `weewx_clearskies_config/admin/routes.py` lines 2224–2493
- Wizard: `weewx_clearskies_config/templates/wizard/step_marine.html`
- CSS: `page-badge` styles in `templates/admin/landing.html` lines 126–138

Dashboard (dashboard repo):
- Marine page: `src/routes/marine.tsx`
- Seismic page: `src/routes/seismic.tsx`
- Location map: `src/components/marine/LocationMap.tsx`
- Location card: `src/components/marine/LocationCard.tsx`
- Earthquake icon: `src/components/icons/earthquake.tsx`
- Page header: `src/components/layout/page-header-card.tsx`

---

## Findings

### F0. CRITICAL — All locations returning identical wave height and water temp from offshore buoy

**Problem:** All 7 marine locations return identical `waveHeight: 2.132551232182137` and `waterTemp: 69.62` with `stationId: "46253"` — the NDBC buoy 12 miles offshore. This includes **Huntington Harbor** and **Newport Bay**, which are enclosed harbors where open-ocean swell data is physically meaningless. This is exactly the problem the entire MARINE-CARD-DATA-SOURCE-PLAN was built to fix.

The `_location_summary()` function in `endpoints/marine.py` has the correct three-level fallback chain:
1. NWPS + `wave_transform.apply_supplements()` (nearshore model, per-location surf spot config)
2. WaveWatch III first forecast point (offshore model, different from buoy)
3. NDBC buoy Hs (raw offshore observation — last resort only)

But ALL locations are silently falling through levels 1 and 2 to the buoy fallback. Similarly, the ocean data resolver (`services/ocean_data_resolver.py`) is called for `waterTemp` but is either failing or returning null for every location, so the raw buoy value persists.

**Verified from API response (`GET /marine`):**

| Field | Expected | Actual |
|---|---|---|
| waveHeight | Different per location (NWPS + supplements) | Identical 2.13m for all 7 |
| waterTemp | Different per location (OFS model) | Identical 69.62°F for all 7 |
| windSpeed | Different per location (station vs provider) | Varies correctly ✓ |
| airTemp | Different per location (station vs provider) | Varies correctly ✓ |
| stationId | Location-specific or model source | "46253" for all 7 |

Harbor locations should show near-zero wave height (sheltered water), not open-ocean swell. The models exist specifically to differentiate these.

**Root causes identified (2026-07-13 log analysis):**

**Bug 1 — NWPS: case-sensitive WFO lookup.** Config stores `nwps_wfo = LOX` (uppercase). The NWPS provider's `_WFO_TO_REGION` dict at `nwps.py` line 105 uses lowercase keys (`"lox": "wr"`). Line 492 does `if wfo not in _WFO_TO_REGION` — `"LOX" not in {"lox": "wr"}` evaluates True, raises `GeographicallyUnsupported("WFO 'LOX' is not in the NWPS production set")`. Every location's NWPS fetch fails. Every location falls through to NDBC buoy.

**Fix:** `nwps.py` line 491: `wfo = (wfo_override or _determine_wfo(lat, lon)).lower()`

**Bug 1a — Case-sensitivity audit across all marine config fields.** The config loader (`marine_config.py` `_opt_str()` at line 102) does `str(value).strip()` with **no case normalization**. Config values are stored exactly as written (uppercase WFO codes, mixed-case zone IDs). Each consumer is responsible for its own case handling, and some don't:

| Config field | Config value | Consumer | Consumer key format | Normalizes? | Status |
|---|---|---|---|---|---|
| `nwps_wfo` | `LOX` | `nwps.py _WFO_TO_REGION` | lowercase keys | **No** | **BUG** |
| `nwps_wfo` | `LOX` | `nws_srf.py` WFO param | `.upper()` at line 972 | Yes | OK |
| `nws_marine_zone_id` | as-is | `nws_marine.py` line 448 | direct compare | **Needs audit** | **CHECK** |
| `ofs_model` | `WCOFS`/null | `ofs.py` line 110 | `.lower()` | Yes | OK |
| `nws_srf_wfo` | as-is | `nws_srf.py` | handles upper | Yes | OK |

**Recommended fix:** Normalize in the config loader (`_opt_str`) — lowercase WFO codes and zone IDs at parse time so every consumer gets consistent case. This is safer than fixing each consumer individually.

**Bug 2 — ERDDAP ocean provider: wrong constructor argument.** `erddap_ocean.py` line 81 passes `base_url=` to `ProviderHTTPClient.__init__()`, which does not accept that keyword argument. `TypeError: ProviderHTTPClient.__init__() got an unexpected keyword argument 'base_url'` on every single call. Both MUR SST and RTOFS 2D fail for every location. The ocean resolver gets null from all ERDDAP tiers and falls back to the NDBC buoy water temp.

**Fix:** `erddap_ocean.py` line 81: use the correct `ProviderHTTPClient` constructor parameter (inspect the class to find the right signature — likely a positional arg or `provider_base_url`).

**Additional issue — harbor wave handling:** Even after Bug 1 is fixed, Huntington Harbor and Newport Bay don't have `surf` in their activities — they bypass the NWPS + wave_transform path entirely. The fallback chain goes straight to WaveWatch III → NDBC buoy, both of which return open-ocean swell data that is physically meaningless for enclosed harbors. Harbor locations should either suppress wave height entirely or show a near-zero "sheltered water" value — not offshore swell.

**Both bugs mean Phase 2 (NWPS wave data) and Phase 3 (ocean resolver water temp) have been dead since deployment.** The QC gates verified code existence and endpoint stability but did not catch that the data was silently falling back to the single offshore buoy.

**This is the #1 priority fix.** The data pipeline that the plan was designed to build is not functioning. Everything else in this brief is cosmetic by comparison.

**Files:** `providers/marine/nwps.py` line 491 (Bug 1), `providers/ocean/erddap_ocean.py` line 81 (Bug 2), `endpoints/marine.py` (harbor wave handling). All API repo.

### F1. Activities column unreadable — replace text badges with designated icons

**Problem:** Activities render as `page-badge` text pills (0.75rem font, 0.15rem vertical padding, `--pico-secondary-background` fill). At this size the text is illegible — the badges appear as small colored blobs where you cannot read the activity names.

**Fix:** Replace the text badges with 18×18 inline SVG icons using the designated activity icons from DASHBOARD-MANUAL §12:

| Activity | Icon source | Icon name |
|---|---|---|
| Marine / Boating | Phosphor | `Sailboat` |
| Surfing | Material Symbols (inline SVG) | `surfing` — SVG path data already exists at `weewx-clearskies-dashboard/src/components/marine/SurfingIcon.tsx` |
| Fishing | Phosphor | `FishSimple` |
| Beach Safety | Phosphor | `PersonSimpleSwim` |

Each SVG gets `fill="currentColor"`, `aria-hidden="true"`, and a `<title>` element with the activity name for tooltip/accessibility. Laid out in a flex row with ~4px gap.

**Location in template:** `marine.html` lines 402–406 (replace the `page-badge-list` div with inline SVGs).

### F2. Connectivity buttons don't look like buttons

**Problem:** The "Test" and "Update Bathymetry" buttons use `class="outline secondary"` with extreme inline style overrides: `font-size:0.75rem;padding:0.15rem 0.5rem` (lines 415–429). This shrinks them below recognizable button size — they look like tags or labels, not interactive controls.

**Fix:** Remove the inline `font-size` and `padding` overrides. Let Pico CSS render them at standard button sizing. The standard `outline` class at default size is readable and recognizable as a button.

**Location in template:** `marine.html` lines 415 and 423 (remove `style="font-size:0.75rem;padding:0.15rem 0.5rem"`).

### F3. Edit/Delete and connectivity buttons appear merged

**Problem:** Both button pairs are wrapped in `<div role="group">` (lines 414 and 434). In Pico CSS, `role="group"` merges adjacent buttons into a connected button group with shared borders and no gap. The result looks like a single merged control rather than two separate buttons.

**Fix:** Remove the `role="group"` wrapper from both button pairs. Render Edit and Delete as separate buttons with standard spacing between them. Delete should remain visually distinct (`outline secondary` or red-tinted border) to signal destructive action. Same treatment for the connectivity buttons.

**Location in template:** `marine.html` lines 414 and 434 (remove `role="group"` or change to a plain `<div>` with flex gap).

### F4. Per-location bathymetry buttons contradict the manual — both admin AND wizard

**Problem:** PROVIDER-MANUAL §14.7 explicitly states:

> **Unified bounding box download:** When marine locations are saved (wizard apply or admin save), bathymetry downloads are triggered automatically for ALL configured surf/fishing spots in a single pass — **no separate manual download button.** Re-download triggers automatically when locations are added or moved.

Both the admin and the wizard have per-location manual bathymetry buttons that contradict this:

- **Admin:** "Update Bathymetry" button per surf location (`marine.html` lines 422–429), calling `POST /admin/marine/bathymetry` (`routes.py` line 2450).
- **Wizard:** "Download Bathymetry" button per surf location (`step_marine.html` line 183), calling `POST /wizard/marine/bathymetry`, with a results fragment at `marine_bathymetry_result.html`.

**Fix:**
1. Remove per-location "Update Bathymetry" button from the admin table rows.
2. Remove per-location "Download Bathymetry" button from the wizard marine step.
3. Bathymetry download should happen automatically when locations are saved (the `/setup/apply` path). The API setup endpoint already knows which locations have surf/fishing activities and their lat/lon — it should trigger bathymetry downloads for all of them in a single pass during apply.
4. If a manual "refresh all" escape hatch is needed for troubleshooting, add a single "Refresh All Bathymetry" button at the top of the admin marine page (not per-location). This is optional — the automatic-on-save behavior is the primary path.

**Files:** `marine.html` (admin), `step_marine.html` (wizard), `routes.py` (admin bathymetry handler), wizard routes (wizard bathymetry handler).

### F5. NWS zone not shown in the list view

**Problem:** The "Stations" column shows NDBC and CO-OPS counts (`1 NDBC, 1 CO-OPS`) but does not show NWS zone assignment. The NWS marine zone ID (`nws_marine_zone_id`) is stored in the location config and is critical data — it drives the NWS marine text forecast and SRF zone forecast (rip current risk, UV index). An operator has no way to see whether a zone is assigned without clicking the "Test" button or opening the edit form.

The test-connectivity handler (`routes.py` line 2394) does return an NWS zone status dot, but only after the operator clicks "Test" — it's not visible by default.

**Fix:** Add NWS zone to the Stations column display. Change the cell content from:

```
1 NDBC, 1 CO-OPS
```

to something like:

```
1 NDBC, 1 CO-OPS, NWS: PZZ655
```

Or rename the column header from "Stations" to "Data Sources" and include the zone ID. If no zone is configured, show a warning indicator (amber dot or "—") so the operator knows it's missing.

**Location in template:** `marine.html` lines 408–411. The location dict already has `nws_marine_zone_id` available — it's just not rendered in the list view.

### F6. Test button — relabel and clarify purpose

**Problem:** The "Test" button label is vague. It doesn't test connectivity to specific configured stations — it re-runs discovery (`GET /setup/marine/discover-stations`) and checks whether stations exist near the location's coordinates. The NWS zone check is even simpler: it just verifies a zone ID is stored in config, not that the zone is producing forecasts.

**Fix:** Relabel "Test" to "Check Sources" to better communicate what it does. Consider whether this button is still needed at all — the Data Coverage panel from T3.6 (accessible in the edit view) provides a much more comprehensive diagnostic that includes OFS model, coverage tier, all station assignments, capabilities, and sensor proximity.

If we keep the button, it should use standard button sizing (see F2) and a clearer label.

### F7. Column header "Connectivity" is misleading

**Problem:** With the per-location bathymetry button removed (F4) and the Test button relabeled or removed (F6), the "Connectivity" column header no longer describes its content. Even before the fixes, "Connectivity" implies a live connection test, but the handler runs a discovery proxy and a config presence check — not a true connectivity test.

**Fix:** If the Check Sources button is retained, rename the column to "Diagnostics" or "Status". If the button is removed and diagnostics move entirely to the edit view's Data Coverage panel, remove the column.

### F8. Marine and Seismic page header icons — wrong size, weight, and padding

**Problem:** The `PageHeaderCard` component (`page-header-card.tsx` line 84) wraps the icon in a div with `fontSize: '3.75rem'` and `lineHeight: 1`. Phosphor icons default to `1em` when no `size` prop is passed, so the wrapper's font-size controls the icon size. All standard pages follow this pattern correctly:

| Page | Icon code | Result |
|---|---|---|
| Forecast | `<CloudSun weight="duotone" />` | Inherits 3.75rem ✓, duotone ✓ |
| Charts | `<ChartLine weight="duotone" />` | Inherits 3.75rem ✓, duotone ✓ |
| Almanac | `<MoonStars weight="duotone" />` | Inherits 3.75rem ✓, duotone ✓ |
| About | `<Info weight="duotone" />` | Inherits 3.75rem ✓, duotone ✓ |
| Legal | `<Scales weight="duotone" />` | Inherits 3.75rem ✓, duotone ✓ |

Both Marine and Seismic break this pattern:

| Page | Icon code | Issue |
|---|---|---|
| Marine | `<Waves aria-hidden="true" className="h-7 w-7" />` | Forces 28px via Tailwind `h-7 w-7`, missing `weight="duotone"`, redundant `aria-hidden` (wrapper already sets it) |
| Seismic | `<Earthquake size={28} />` | Forces 28px via `size` prop — but the Earthquake custom SVG component uses `width={size}` / `height={size}` (not `1em`), so it can never inherit from the wrapper |

The result: Marine and Seismic page headers have tiny 28px icons while every other page has properly-sized ~60px duotone icons. This is visible in the screenshot — the `≈` Waves icon is small and thin-lined compared to the other pages' icons.

**Fix — Marine (`routes/marine.tsx` line 200):**
```tsx
// Before:
icon={<Waves aria-hidden="true" className="h-7 w-7" />}
// After:
icon={<Waves weight="duotone" />}
```

**Fix — Seismic (`routes/seismic.tsx` line 230):**
The `Earthquake` component (`components/icons/earthquake.tsx` line 24) uses `width={size}` / `height={size}` with a default of 20. It does not support `1em` sizing. Two changes:
1. In `earthquake.tsx`: change the default from `size = 20` to using `"1em"` for width/height when no size is provided, matching Phosphor's behavior.
2. In `seismic.tsx`: remove the `size={28}` override so it inherits from the wrapper.

**Files:** `routes/marine.tsx`, `routes/seismic.tsx`, `components/icons/earthquake.tsx` (all dashboard repo).

### F9. Marine page bypasses the official grid system

**Problem:** The Marine Activities page (`/marine`) wraps all content in a single `col-span-1 md:col-span-2 lg:col-span-4` div and builds its own internal layout, bypassing the official 4-column grid system (DESIGN-MANUAL §5) that every other page uses.

Specific deviations:

| Current behavior | Official grid system |
|---|---|
| Location cards in `grid-cols-3` at lg | No 3-column footprint exists. Cards should use `footprint="tile"` (1 col), flowing 4 per row at lg |
| Map height hardcoded at `h-[400px]` | Should use a design token or grid track height |
| Everything inside a single `col-span-full` wrapper | Cards should be direct Grid children with footprint/rowSpan props |
| LocationCard is a custom component, not a Card primitive | Should be built on the Card component with proper footprint |

At `lg` the official grid is 4 columns. With `footprint="tile"`, 7 location cards would flow as 2 rows (4 + 3), which is actually a better fit than the current 3-column layout (3 + 3 + 1 orphan).

**Fix:** Refactor the marine landing state to place LocationCards directly in the Grid as proper Card children with `footprint="tile"`. The map can remain `footprint="full"` as a special full-width element. Remove the internal `grid-cols-3` grid wrapper.

**Files:** `routes/marine.tsx` lines 225–263, `components/marine/LocationCard.tsx` (dashboard repo).

### F10. Marine map layout should adapt to site geographic arrangement

**Problem:** The map is always a fixed-height (`h-[400px]`) full-width horizontal strip above the card grid. This works for the current SoCal deployment where locations run NW-SE along the coast (wider than tall bounding box). But an operator with locations arranged vertically (north-south coastline) or in a cluster would get a map that's mostly empty ocean/land on the sides with all markers compressed into a narrow vertical band.

**Fix:** Compute the bounding box aspect ratio of all configured locations (correcting longitude for latitude cosine) and choose a layout mode:

```
latSpan = maxLat - minLat
lonSpan = (maxLon - minLon) × cos(centerLat × π/180)
aspectRatio = lonSpan / latSpan
```

| Aspect ratio | Layout | Map | Cards |
|---|---|---|---|
| ≥ 1.2 (wider than tall) | Horizontal — current layout | Full-width above cards | Grid below |
| ≤ 0.8 (taller than wide) | Vertical — map alongside cards | Tall narrow map on one side (`footprint="wide"` or `panel`) | Cards stacked on the other side |
| 0.8–1.2 (roughly square) | Horizontal — default to current | Full-width above | Grid below |

On mobile (<768px), both layouts collapse to stacked (map on top, cards below) regardless of aspect ratio — there's no room for side-by-side.

The `LocationMap` component's `bounds` useMemo (`LocationMap.tsx` lines 113–125) already computes the lat/lon extents. The aspect ratio computation can live next to it.

**Files:** `routes/marine.tsx`, `components/marine/LocationMap.tsx` (dashboard repo). LocationMap may need a new `variant` or `orientation` prop to switch between wide/tall rendering.

### F11. Remove "Use my location" button from the Marine Activities page

**Problem:** The Marine Activities page (`/marine`) shows a "Use my location" button with a Crosshair icon (`marine.tsx` lines 228–236) that uses the browser Geolocation API to find the nearest marine location. This feature was not part of any approved design and adds unnecessary complexity — the operator's marine locations are all within a small coastal area, and the map with location pins already provides clear visual selection. The geolocation feature adds error handling UI (permission denied, timeout, not supported) that clutters the page for marginal benefit.

**Fix:** Remove the "Use my location" button, its click handler (`handleUseMyLocation`), the `geoStatus` / `geoErrorMessage` state, the error display paragraph, the `findNearestLocation` and `haversineKm` helper functions, and the `Crosshair` import.

**Location:** `routes/marine.tsx` lines 228–241 (button + error display), lines 126–146 (handler + state), lines 34–61 (helpers).

### F15. Map pins and cards need cross-referencing and linked hover states

**Problem:** The map pins are generic blue Leaflet default markers — visually identical, with no way to match a pin to its corresponding card below without clicking. When hovering a card, the only visual feedback is `hover:ring-primary/40` (`LocationCard.tsx` line 66), a subtle ring color change that's nearly invisible against the card-glass surface. There is no linked hover state between cards and pins: hovering a card doesn't highlight its pin, and hovering a pin doesn't highlight its card.

For a visitor scanning 7 locations on a map and 7 cards below, the mental connection between a specific pin and its card is guesswork.

**Fix — numbered pins:**
- Replace generic Leaflet default markers with numbered `L.divIcon` markers (1–7, or A–G).
- Each pin displays its number/letter in a circle, using the existing amber alert pin pattern (`LocationMap.tsx` line 49) as a template but with the `--primary` accent color for normal pins.
- Each LocationCard displays the same number/letter as a small badge in the top-left corner, next to or above the location name.
- The numbering is stable — derived from the location's index in the array, not random.

**Fix — linked hover/focus states:**
- **Card hover → pin highlight:** When a card receives `mouseenter` or `focus`, the corresponding map marker should visually enlarge or change color (e.g., scale 1.3× or switch to accent color). Pass hovered location ID up to the parent `MarinePage` via state, then down to `LocationMap` as a `hoveredId` prop.
- **Pin hover → card highlight:** When a map marker receives `mouseover`, the corresponding card should get a stronger visual highlight (e.g., `ring-2 ring-primary` or a background tint, not just `ring-primary/40`). Pass hovered marker ID up from `LocationMap` via a new `onHoverLocation` callback.
- **Stronger card hover:** Replace the current `hover:ring-primary/40` with `hover:ring-2 hover:ring-primary` for a visible border change, plus a slight background brightening (`hover:bg-foreground/5`).

**Files:** `src/components/marine/LocationMap.tsx` (numbered pins, hover state), `src/components/marine/LocationCard.tsx` (number badge, hover styling, hover callback), `src/routes/marine.tsx` (hovered state management, prop threading).

### F16. Add icons to wave height, wind, and water temp stats on LocationCards

**Problem:** The three stat fields on each LocationCard (Wave Height, Wind, Water Temp) are text-only labels with values. Every other stat display on the dashboard pairs an icon with its label — the Now page highlights card, forecast cards, and the marine detail tab stat tiles all use Phosphor icons for visual scanning. The LocationCards are the only stat display without icons.

**Fix:** Add Phosphor icons inline with each stat label, sized to match `--text-label` (0.75rem / 12px). Since the Config UI admin also uses these same activity stats (F1), the icon assignments should be consistent across dashboard and admin.

| Stat | Phosphor icon | Rationale |
|---|---|---|
| Wave Height | `Waves` | Matches the Marine page header icon; wave-specific |
| Wind | `Wind` | Already designated in DESIGN-MANUAL §7 for wind stats |
| Water Temp | `Thermometer` | Already designated in DESIGN-MANUAL §7 for temperature |

Each icon renders at the same `font-size` as the `<dt>` label text (`--text-label`), with `aria-hidden="true"` and `focusable="false"` (decorative — the label text provides the accessible name). Inline flex with `gap-1` between icon and label text.

**Files:** `src/components/marine/LocationCard.tsx` (dashboard repo).

### F18. Detail page hero map should zoom to selected location, not show all locations

**Problem:** When a location is selected, the hero map strip (`LocationMap` with `variant="hero"`) still shows all 7 location markers and fits them all in the bounds. The `FlyToSelected` component does `flyTo` the selected marker at zoom 10, but the initial `bounds` prop on `MapContainer` is computed from ALL locations (`LocationMap.tsx` lines 113–125). On first render, Leaflet fits all markers, then `FlyToSelected` animates to the selected one — creating an unnecessary zoom animation. More importantly, zooming to a single location means you see the actual beach/harbor/pier geography at a useful scale, not a wide-area overview where you can't distinguish coastal features.

**Fix:**
1. When `variant="hero"`, compute `bounds` from the selected location only — center on it with appropriate zoom (~14–15 for individual beach detail, not 10 which is too wide).
2. Only show the selected marker, not all 7. The landing map already shows all markers — once you've selected a location, showing the other 6 is noise.
3. Remove the `FlyToSelected` animation in hero mode — the map starts centered on the right location, no fly needed.

### F19. Maps should label marine features (both landing and detail pages)

**Problem:** Both the landing map and detail hero map use plain OpenStreetMap / CartoDB basemaps that label streets and neighborhoods but do not prominently label marine features — piers, jetties, harbors, channels, buoys, breakwaters, surf breaks. For a marine-focused page, the map should make coastal geography readable — visitors need to see "Huntington Pier," "Newport Harbor entrance," "The Wedge" on the map itself.

**Fix:** This is a basemap choice and/or overlay problem. Options (in order of preference):
1. **OpenSeaMap overlay** — a free nautical chart overlay (`openseamap.org/map`) that renders on top of standard OSM tiles. Adds buoys, beacons, harbors, channels, depth contours, piers. Add it as a second `TileLayer` above the basemap with partial opacity.
2. **NOAA nautical chart tiles** — NOAA's RNC (raster nautical chart) tile service. Authoritative US coastal data but visually dense — better as an optional toggle than a default.
3. **Custom labels** — for a small number of known locations, render Leaflet `Tooltip` or `DivIcon` labels at key marine feature coordinates (pier tip, harbor entrance, breakwater end). Low-tech but guaranteed relevant.

Option 1 (OpenSeaMap overlay) is the most practical — it's a single extra `TileLayer` line, free, and adds exactly the kind of labels marine visitors need. Both the landing map and the detail hero map should use it.

### F20. Detail page map should be a combo card — map + location photo

**Problem:** The detail page hero map is a narrow 120px strip (`h-[120px]` in `LocationMap.tsx` line 128) that's too compressed to be useful. With the location photo feature (F14), there's an opportunity to combine the map and the photo into a single more useful visual element.

**Fix:** Replace the 120px hero map strip with a combo card:
- **Left half:** Map zoomed to the single selected location (per F18), at a useful height (~200–250px, not 120px). Shows marine feature labels (per F19). Single marker for the selected location.
- **Right half:** The same operator-uploaded location photo from F14 (`photoUrl` on `MarineLocationSummary`). `object-fit: cover`, clipped to the card's right-side border radius.
- **No photo fallback:** When no photo is uploaded, the map takes the full width (current behavior but taller and zoomed in).
- **Full-width footprint:** The combo card spans the full grid width, same as the current hero strip but taller and more useful.

This mirrors the Lincoln Cent card pattern the user referenced in F14 — content on the left, photo on the right — but with a map instead of text as the left content.

**Files:** `src/components/marine/LocationMap.tsx` (new combo variant), `src/routes/marine.tsx` (selected state layout).

### F21. BoatingTab — complete redesign required (7 sub-issues)

**Problem:** The Boating activity tab (`BoatingTab.tsx`, 674 lines) has fundamental data source and information architecture problems. Multiple panels are broken, duplicated, or useless. This has been reported more than once.

**F21a. Wind panel shows no data.**
The Wind panel (line 447) reads `observation?.windSpeed` / `observation?.windGust` / `observation?.windDirection` from the `MarineObservation` — which is the raw NDBC buoy observation. Buoy 46253 does not report wind at all, so all three fields show "—". Meanwhile the LocationCard correctly shows wind from the forecast provider (via `is_station_served()` / `marine_weather_cache`), but the detail endpoint's `MarineBundle.observation` is the raw buoy, not the enriched conditions.

**Fix:** The detail endpoint (`GET /marine/{id}`) needs to include the forecast provider wind data in the response (same source as the card summary), not just the raw buoy observation. The BoatingTab should read wind from this enriched source.

**F21b. "Nearest Offshore Buoy" panel is useless — remove it.**
Panel 4 (line ~500) shows raw NDBC buoy observations: wave height, dominant period, average period, mean wave direction, water temp. Nobody cares what buoy 46253 is reading 12 miles offshore. The relevant wave data should be from NWPS models (once F0 is fixed), and should be integrated into the wave panel — not presented as "here's an offshore buoy."

**Fix:** Remove the entire buoy observation panel. Move any useful stats into consolidated panels (see F21c, F21d).

**F21c. Wave information should be a single unified panel.**
Currently wave height/period/direction stats are on the buoy panel (panel 4), and the wave forecast chart is a separate panel (panel 3). These are two views of the same thing — current wave conditions and the forecast — split across two cards for no reason.

**Fix:** Single "Waves" panel with: current wave height + period + direction as stat tiles at the top, followed by the 72h wave forecast chart below. All from NWPS/model data, not buoy.

**F21d. Water temp should be on a primary conditions panel.**
Water temp is buried inside the buoy observations panel. It's one of the most important pieces of information for any marine activity — it should be prominently displayed, not hidden in a "buoy" card that's being removed.

**Fix:** Move water temp to the Conditions panel alongside air temp, or give it its own prominent stat tile at the top of the tab.

**F21e. Conditions panel is broken — shows all dashes.**
Panel 5 (line 543) shows pressure, visibility, air temp — all from `observation?.pressure`, `observation?.visibility`, `observation?.airTemp`. These come from the NDBC buoy observation, which returns null for all three fields for station 46253. The conditions panel shows "— mb", "— nm", "—" for everything. **This has been reported more than once.**

**Fix:** Same as F21a — the detail endpoint needs to include forecast provider data for these fields, not just raw buoy observation. Pressure and visibility may come from the forecast provider or the station hardware (via `is_station_served()`). The Conditions panel should read from the enriched source.

**F21f. Tide forecast chart has clipping on the left side.**
The TideChart (line 577, shared component at `tabs/shared/TideChart.tsx`) has visible clipping/rendering issues on the left portion of the chart. The screenshot shows the left ~15% of the tide curve is cut off or visually broken.

**Fix:** Inspect `TideChart.tsx` Recharts margins and `XAxis` domain. The left clipping is likely a `margin.left` too small for the YAxis label, or the XAxis `domain` starting after the first data point. This is the same chart that had the Y-axis values of 342362 (fixed in T1.6) — it may have lingering layout issues.

**F21g. Marine text forecast should be structured like the forecast page, not raw expandable text.**
Panel 7 (line 594) renders the NWS marine zone text forecast as `<details>/<summary>` expandable sections — click "Tonight" to see raw text. This looks nothing like the main forecast page's polished daily/hourly cards (icons, hi/lo temps, wind, precip).

The data comes from NWS marine zone text forecast (`nws_marine.py`), which returns period names + raw text paragraphs. The raw text includes wind, seas, visibility, and weather as sub-fields — the component tries to parse them (lines 616–634) but falls back to the full text blob when sub-fields are null.

**Fix:** Redesign the marine forecast section to match the main forecast page's card pattern:
1. **Data source:** The NWS marine text forecast is the right source for marine conditions (it covers wind, seas, swell, visibility, weather — purpose-built for mariners). The configured forecast provider (Aeris/NWS/Open-Meteo) provides land-focused forecasts that don't include seas/swell. So keep NWS marine as the source, but present it properly.
2. **Layout:** Instead of expandable text blobs, render each forecast period as a card/column similar to `ForecastDailyCard.tsx` / `DailyColumns.tsx` on the forecast page. Each period shows: period name, wind (speed + direction icon), seas (wave height), visibility, weather conditions — as structured stat tiles, not prose paragraphs.
3. **Horizontal scroll:** Use the same `HorizontalScrollNavigation` pattern from the forecast page for multi-period marine forecasts.

**F21h-research. Industry research — how marine/boating weather apps present data (2026-07-13):**

| App/Site | Wind display | Wave display | Tide display | Pressure display | Conditions assessment | Key visual patterns |
|---|---|---|---|---|---|---|
| **Windfinder** | 3-hourly table: speed (kn), gusts (kn), direction (rotated compass arrow). **Bar height + color = wind speed** — instant visual scanning of which hours are windiest. | Height (m), period (s), direction (compass arrow) — same table columns as wind. | Symbolic icons: ebbing ↓, low ≈, rising ↑, high ≈ with time + height values. | Displayed in hPa as a table column alongside all other params. | No composite score — raw data for experienced boaters. | **Single unified table** with ALL params (wind, gust, cloud, precip, temp, pressure, wave height, wave period, wave direction, tide) in one horizontal timeline. 8 snapshots per day. Color-coded wind bars are the standout visual. |
| **Buoyweather** | Average (kn) + Gust (kn) + direction (compass icon). 16-day table. | Average height (ft) + Peak height (ft) + direction (compass icon) + Period (s). | **Graphical tide curve** showing sea level variations from +4ft to -4ft integrated into the forecast table. | Pressure (mb) as a table column. | **Written narrative forecast** per day: morning + afternoon summaries ("Light and variable winds with smooth seas"). Explicitly disclaims: "not intended for use as safety assessment tool." | Morning/afternoon narrative summaries are the standout — plain-English conditions at a glance, then detailed table below for specifics. Separate Wind Charts and Wave Charts pages for deeper analysis. |
| **Windy.com** | Animated wind arrows on map. Speed + gusts + direction in the spot detail panel. Wind barbs overlay option. Multi-model comparison (ECMWF, GFS, ICON, NAM). | Separate Waves/Swell/Wave power layers on map. Height + period in spot detail. | Tide forecast at 3000+ locations from buoy data. Separate tide layer. | Isobars overlay on map. hPa in spot detail. | No composite score — "tells you nothing about what it means for your specific trip" (per SeaLegs review). 40+ selectable layers. | **Map-first, layer-based** — the map IS the forecast. Best for spatial context (seeing weather systems approach). Weakest for quick spot checks. |
| **PredictWind** | Table + Graph + Map views. Hi-res proprietary models (PWG, PWE) alongside standard. Multi-model comparison graphs. | Wave model data in tables/graphs. | Ocean current + tidal data overlays. | Included in table/graph views. | **Departure planning**: compares conditions for day 1/2/3/4 departures. Weather routing adjusts route based on forecast. Daily Briefing condensed format. | **Three view modes** (table/graph/map) for the same data — let the user choose their preferred format. Departure planner is unique — tells you WHEN to go, not just what's happening now. |
| **Savvy Navvy** | **Wind animation overlaid on nautical chart**. Color-coded strength. Scroll timeline to see wind change over the day. GFS + ECMWF model toggle. | **Wave comfort overlay**: color-coded comfort level (Copernicus Marine Service data). Wave comfort graph. | Tidal stream data from 8,000+ stations. Tap anywhere on chart → stream strength + direction. | Not prominently featured. | **Smart routing**: adjusts planned route based on weather. "Wind not favourable to sail" alerts. Route legs describe heading + conditions. | **Chart-integrated weather** — weather IS part of the navigation chart, not a separate page. Tidal streams as tap-anywhere overlays. Wave "comfort" framing (not raw height) targets recreational boaters. |
| **SeaLegs AI** | Not detailed — focuses on AI synthesis. | Route-based wave analysis. | Not detailed. | Falling pressure noted as a concern factor. | **Go / Caution / Avoid** — single clear recommendation with plain-language reasoning. Analyzes "how conditions interact" (wind opposing current, short-period waves + gusts, falling pressure). 12+ weather models synthesized. | **Decision-first, data-second**. The app tells you what to do, THEN shows why. No raw data overload. Antithesis of Windy's "here's 40 layers, figure it out." |
| **BoatUS** | Real-time wind + weather info. | Not detailed. | Real-time tide info. | Not detailed. | Not detailed beyond safety features. | Practical boating focus: fuel prices, marina discounts, towing services alongside weather. |
| **My Marine Forecast** | Wind speed + gusts on one screen. | Wave conditions displayed. | Tide predictions. | Barometric pressure. | All on "one clean dashboard" — wind, tide, temp, precip, pressure, waves, sun/moon. | **Single-screen dashboard** approach — everything at once, no tabs or drilling down. Solunar fish feeding windows integrated. |
| **NOAA Marine Weather** | NWS zone forecasts: wind descriptions in narrative text ("NW wind 10 to 15 kt, gusts to 20 kt"). | Seas descriptions in narrative ("Wind waves 2 to 3 ft"). | Not chart-based — text mentions in zone forecast. | Not prominently featured. | Marine warnings, small-craft advisories as alert banners. Authoritative but "utilitarian — no animated maps, model comparison, or routing." | **Narrative text forecast** — the traditional marine forecast format. Zone-based, not point-based. What we currently try to show in the NWS text forecast panel (F21g). |

**Common patterns across all boating weather apps:**
1. **Wind is king** — every app prioritizes wind speed, gusts, and direction above all else. Wind is the primary go/no-go factor for recreational boaters. Our BoatingTab has a wind panel that shows "—" because it reads from the buoy.
2. **Single unified table or dashboard** — Windfinder, Buoyweather, and My Marine Forecast put ALL parameters (wind, waves, tide, pressure, temp) in one view. Our BoatingTab splits them across 7+ separate panels.
3. **Narrative text summaries alongside data** — Buoyweather writes "Light and variable winds with smooth seas" as a morning/afternoon summary. NOAA uses narrative zone forecasts. Our NWS text forecast panel uses expandable `<details>` blobs. The `conditionsText` from our surf/fishing scorers follows this pattern but is never shown.
4. **Tide as a visual curve, not just numbers** — Buoyweather integrates a graphical tide curve into the forecast table. Savvy Navvy shows tidal streams as tap-anywhere overlays. Our TideChart exists but has clipping issues and is isolated from other data.
5. **Decision support ranges from "none" to "definitive"** — Windy/Windfinder show raw data (expert users). SeaLegs gives Go/Caution/Avoid (beginners). PredictWind's departure planner tells you WHEN to go. We have no conditions assessment for boating — the tab shows raw stats (that are null) with no interpretation.
6. **Multi-model comparison** — Windy, PredictWind, Savvy Navvy let users compare GFS vs ECMWF. Not necessary for v1 but notable.
7. **Pressure TREND matters more than absolute** — SeaLegs flags falling barometric pressure as a concern. FishWeather foregrounds pressure trends. Our Conditions panel shows "— mb" because the buoy doesn't report pressure, and even if it did, we don't show the trend direction prominently.

**Root cause across F21a/b/d/e:** The detail endpoint `get_marine_location()` (`endpoints/marine.py` line 447+) returns only the raw NDBC buoy observation as `MarineBundle.observation`. The card summary endpoint `_location_summary()` correctly enriches from: forecast provider (wind, air temp, weatherCode, isDay via `marine_weather_cache`), NWPS + wave_transform (wave height), and ocean resolver (water temp). The detail endpoint never got this same enrichment — it was never wired in any phase of the plan.

**API fix required:** `get_marine_location()` must build its `observation` the same way `_location_summary()` does:

| Field | Current source (broken) | Correct source |
|---|---|---|
| windSpeed, windGust, windDirection | NDBC buoy (null for 46253) | Station hardware via `is_station_served()`, else forecast provider via `marine_weather_cache` |
| airTemp | NDBC buoy (null for 46253) | Same as wind |
| pressure | NDBC buoy (null for 46253) | Station hardware or forecast provider |
| visibility | NDBC buoy (null for 46253) | Forecast provider |
| waveHeight, wavePeriod, waveDirection | NDBC buoy (raw offshore Hs) | NWPS + wave_transform (surf locations), WaveWatch III fallback, NDBC last resort |
| waterTemp | NDBC buoy (raw offshore) | Ocean data resolver (OFS → MUR SST → RTOFS fallback) |
| weatherCode, isDay | Not present | Forecast provider via `marine_weather_cache` |

This is not a dashboard-only fix. The API detail endpoint must serve the correct model-derived data before the dashboard can display it.

**Files:** `endpoints/marine.py` (API — wire enriched sources into `get_marine_location()`), `src/components/marine/tabs/BoatingTab.tsx` (dashboard — redesign panels), `src/components/marine/tabs/shared/TideChart.tsx` (dashboard — fix clipping).

### F22. SurfingTab — redesign required (8 sub-issues)

**Problem:** The Surfing activity tab (`SurfingTab.tsx`, 646 lines) has the same model data source failures as BoatingTab (F0, F21), plus fragmented information architecture, missing features, and poor visual design. The surf scoring system built in the API is barely surfaced.

**F22a. "Current Surf Conditions" card shows almost nothing.**
When the API returns a single forecast point (which is all it currently returns — T1.7 deferred multi-point to a future phase), the ForecastTimeline renders one colored pill with a star rating and quality label ("2:22 AM, 1 star, Poor"). No wave height, no period, no wind, no water temp, no swell direction — just a score. This is useless as a conditions display.

**Fix:** The current conditions panel needs to show: wave height at break, dominant period, swell direction, wind speed + quality, water temp, star rating + quality label — all in one card. The star rating is one piece of information, not the entire card.

**F22b. Panels are fragmented — consolidate.**
Three separate panels (Current Conditions → Swell Breakdown → Conditions) present related information split across cards. Current conditions shows just a star rating. Conditions shows wind quality badge + beach alignment compass. Swell breakdown shows spectral components. These are all aspects of "what are the surf conditions right now" and should be consolidated into one or two well-organized panels.

**Fix:** One "Current Conditions" panel at the top with: wave height, period, direction, wind quality, star rating, water temp. Swell breakdown can be a sub-section within it or a second panel. The wind quality badge and beach alignment should be part of the conditions, not a separate card.

**F22c. Wave compass / beach alignment diagram looks horrible.**
The `BeachAlignmentDiagram` (line 396) is a minimal SVG — a plain circle, 4 cardinal labels, and a line with an arrowhead. The Now page has a polished Wind Compass card with proper styling. The swell direction display should match that visual quality.

**Fix:** Redesign the swell direction compass to match the Wind Compass visual style from the Now page. Use the same ring styling, gradient fills, and typography patterns. The compass should show the dominant swell direction prominently with beach orientation context.

**F22d. Swell breakdown looks unfinished — industry research completed.**
The `SwellBreakdown` (line 313) renders colored list items (`<li>`) with tiny inline stats at `--text-micro` (0.7rem). Each component shows height, period, direction in a cramped 3-column grid inside a pill. No visual hierarchy, no indication of which component is most important.

**Industry research (2026-07-13) — how surf forecast sites present this data:**

| Site | Swell component display | Forecast timeline | Conditions rating | Key visual patterns |
|---|---|---|---|---|
| **Surfline** | Primary/secondary swells separated in table rows. Arrow size represents period (longer period = bigger arrow). Y-axis toggle between swell height and swell energy. Swell Spectra view shows full energy density chart. | 16-day graph + table toggle. Graph shows surf rating + height bands. Table shows hourly columns: time, rating color, surf height range, primary swell, secondary swell, wind, energy, consistency, weather, pressure. | 1-10 scale with color bands (green/yellow/red). "Consistency" column shows set frequency. | Color-coded rating columns. Swell arrows with direction + period-proportional sizing. Energy density spectra chart. |
| **surf-forecast.com** | Up to 4 distinct swell components per time slot, each with independent height/direction/period/energy. Directional arrows per component. | 48h table: hourly columns with rating (0-10), swell height maps, each swell component row, wind row (speed + direction + quality label: "glassy"/"cross-offshore"/"on-shore"), tide row, weather icons, temperature. | 0-10 star scale. Star rating with faded stars showing "potential if conditions were better." | Traffic light colors (green=good, amber=fair, red=poor). Small regional wave energy map per time slot. Separate tide chart with high/low annotations. |
| **Surf Captain** | Primary/secondary swells separated with distinct arrows on a compass display. Each component shows height, period, direction. | Interactive wave height graph (multi-day) + detailed grid below with time, surf height, wind, primary swell, secondary swell. | 3 categories: clean (green), fair (blue), choppy (red). Headline summary at top ("3-4 ft and semi glassy right now"). | Circular compass showing swell + wind directions simultaneously. Buoy data modal. Tide calendar (2-week view). |
| **Quiver** | Swell components in custom alert settings. Beach-specific calibration for exposure/shoaling adjusts raw swell → local conditions. | "One clear call for your spot" — period → direction → wind → tide → height reading order. 280+ breaks scored. | ML-personalized: learns from user session ratings. Session history feeds forecast tuning. | Dark theme optimized for pre-dawn checks. Fast load. Personalized "match" scoring. |
| **Windy.app** | Swell direction shown as white triangles on map. Period displayed with quality tiers (8s=normal, 11s=good, 14+=great). | 36h forecast with 12h resolution. Swell propagation visualization (T+0h through T+36h). | No algorithmic score — quality derived from parameter combinations vs. spot working conditions. | Color-coded map (blue→magenta for wave height). Wind impact diagrams showing offshore/cross/onshore effect on wave face. |

**Common patterns across all sites:**
1. **Swell components are always separated** — primary vs secondary vs wind swell, each with its own height/period/direction, ranked by energy contribution.
2. **Direction is always visual** — arrows, compass roses, or directional indicators. Never just text.
3. **Period is treated as a quality indicator** — longer period = better quality (more power per wave). Sites visually emphasize this (Surfline: bigger arrows; surf-forecast: star potential; Windy: quality tiers).
4. **Forecast timeline is tabular or columnar** — hourly or 3-hourly columns with multiple data rows. NOT expandable text blobs.
5. **Conditions summary is a single headline** — "3-4 ft and semi glassy" (Surf Captain), star rating (Surfline), color rating (surf-forecast). One glance tells you the story.
6. **Wind quality has specific surf terminology** — offshore/cross-shore/onshore/glassy, not just speed + direction.

**Fix:** Redesign the swell breakdown to match industry standards:
- Show each swell component as a distinct row/card ranked by energy contribution (primary → secondary → wind swell)
- Each component shows: height, period (with quality tier label), direction (as arrow or compass indicator), energy, classification
- Visual weight proportional to energy — the dominant swell is visually larger/bolder
- Direction uses the same polished compass/arrow style as the Wind Compass on the Now page

**F22e. Tide chart is clipped — same as BoatingTab.**
Same TideChart left-side clipping issue as F21f. Shared component, shared bug.

**F22f. Data appears generic — not pulling from models.**
Same root cause as F0 — NWPS fetch fails due to case sensitivity bug, data falls back to the offshore buoy. The surf endpoint (`GET /surf/{id}`) has the NWPS + wave_transform + surf_scorer pipeline, but NWPS fails for every location so the scorer gets offshore buoy data instead of nearshore model data. The star ratings and quality labels are being computed from the wrong input.

**F22g. Rip current risk presented as an alert banner — should be a condition.**
The rip current risk (from NWS SRF zone forecast) renders as an alert-styled banner with `role="alert"` at the bottom of the tab (line ~590). This is not a warning we're issuing — it's an NWS observation/forecast of rip current conditions. It should be presented as a condition indicator (colored badge + label) on the conditions panel, not as a scary alert banner.

**Fix:** Move rip current risk to the conditions panel as a status badge (low = green, moderate = amber, high = red), always paired with text label. Remove the alert-glass styling. If the NWS SRF also has hazards text, show it as an informational note under the badge, not an alert.

**F22h. The entire surf scoring system is built but barely surfaced.**

The API has a full surf scoring system at `enrichment/surf_scorer.py` (450+ lines) that produces rich output per `SurfForecast` model. Here's what it computes vs what the dashboard shows:

| Scorer output | Description | Dashboard shows? |
|---|---|---|
| `qualityStars` | 1-5 star rating (4 weighted factors × 3 filters) | Yes — one lonely star pill |
| `qualityLabel` | "Poor" / "Fair" / "Good" / "Very Good" / "Epic" | Yes — tiny text under stars |
| `conditionsText` | **Composed natural-language headline**: "3-4 ft at 12 seconds from the SSW. Offshore winds 5-10 mph. Clean conditions with long-period swell." | **NOT SHOWN ANYWHERE** |
| `windQuality` | "Offshore" / "Cross-shore" / "Onshore" / "Glassy" (i18n) | Yes — buried in a separate card |
| `swellDominance` | 0-1 score (pure swell vs mixed vs wind chop) | **NOT SHOWN** |
| `waveHeightAtBreak` | Post-supplement breaking wave height | Only as fallback stat when chart hidden |
| `period` | Dominant swell period (seconds) | **NOT SHOWN** |
| `direction` | Dominant swell direction (degrees) | Only via the ugly compass |
| `multiSwell` | Full spectral component breakdown | Yes — cramped colored pills |

The scorer's 4 weighted factors (height 35%, period 35%, wind 20%, swell dominance 10%), beach alignment filter, directional exposure filter, and time-of-day adjustment are all computed — and none of the breakdown is surfaced to the visitor.

**`conditionsText` is the single biggest miss.** This is exactly the "one-glance headline" that every competitor provides (Surfline's star + range, surf-forecast.com's rating, Surf Captain's "3-4 ft and semi glassy"). The API computes it — the dashboard throws it away.

**Second biggest miss: only ONE forecast point is scored.** The `score_surf()` function runs once for the current moment and the result goes into `forecast[0]`. The dashboard's `ForecastTimeline` component was designed for multi-point data (horizontal scroll of star-rated time slots), but it never gets more than one point. T1.7 acknowledged this and deferred it, but it's the core feature.

**Fix (API):**
1. Run `score_surf()` against each NWPS forecast time step across 72 hours — not just the current snapshot. Each time step gets its own star rating, quality label, conditions text, wind quality, wave height at break.
2. Return the full array as `SurfDetailData.forecast` (the response model already supports it).
3. Include scoring factor breakdown in the response so the dashboard can show visitors WHY conditions are rated the way they are.

**Fix (Dashboard):**
1. Display `conditionsText` as the headline summary at the top — the first thing visitors see.
2. Render the 72-hour timeline with star-rated time slots (the ForecastTimeline component already handles this if it gets data).
3. Show the wave face height chart across the full forecast period.
4. Show scoring factor breakdown (height + period + wind + swell dominance bars/tiles) so visitors understand the rating.
5. Consolidate wind quality, swell direction, water temp, and wave height into a single unified conditions panel — not 3-4 separate cards.

**Files:** `src/components/marine/tabs/SurfingTab.tsx` (dashboard — full redesign), `endpoints/surf.py` (API — multi-point forecast scoring), `endpoints/marine.py` (API — enriched observation for surf detail).

### F23. FishingTab — redesign required (6 sub-issues)

**Problem:** The Fishing activity tab has the same pattern as the Surfing tab: a comprehensive scoring system exists in the API (`enrichment/fishing_scorer.py`, 750+ lines) producing rich output that the dashboard barely uses. Multiple panels are broken or don't follow the design system.

**The fishing scorer outputs (per `FishingForecast` model):**

| Scorer output | Description | Dashboard shows? |
|---|---|---|
| `overallScore` | 0-100 composite score | Yes — as a number in the period grid |
| `pressureScore` | Barometric trend component | Yes — in conditions breakdown |
| `tideScore` | Tidal cycle component | Yes — in conditions breakdown |
| `solunarScore` | Solunar intensity component | Yes — in conditions breakdown |
| `timeofdayScore` | Dawn/dusk/midday component | Yes — in conditions breakdown |
| `conditionsText` | **Composed summary**: "Good fishing. Falling pressure and incoming tide favor activity. Yellowfin croaker and California halibut are active." | **NOT SHOWN ANYWHERE** |
| `speciesScores` | Per-species: name, score, status, temperature suitability, seasonal modifier, note, closed-season warning | **BROKEN — shows empty** |
| `windSpeed/Direction/Gust` | Passthrough fields | Shown in a separate panel |
| `swellHeight/Period` | Passthrough fields | Shown in a separate panel |

**F23a. Forecast cards don't follow site-wide graphical standards.**
The 3-day period grid uses a custom layout that doesn't match the forecast page's `ForecastDailyCard` / `DailyColumns` pattern. Every forecast display on the site should share the same visual language — column structure, icon placement, typography, color treatment. The fishing forecast cards look like a different app.

**Fix:** Redesign the forecast periods to follow the same card/column pattern as the main forecast page. Each period shows: overall score (prominently), time window, scoring factor breakdown (as small bars or indicators), key conditions (pressure trend, tide state, wind), and the `conditionsText` headline.

**F23b. Solunar calendar MUST match almanac page graphics — reported MULTIPLE TIMES.**
The solunar timeline in the FishingTab uses a custom bar/line visualization. The Almanac page has a polished moon phase display with proper graphics. **The user has requested multiple times** that the solunar display use the same visual treatment as the Almanac page card. This has been ignored every time.

**Fix:** Use the same moon phase rendering, solunar period visualization, and typography from the Almanac page's solunar/moon card. The fishing solunar display should look like it belongs to the same design system — same moon icons, same major/minor period indicators, same visual weight.

**F23c. Current conditions panel is completely broken.**
Same root cause as BoatingTab F21a/F21e — the detail endpoint returns raw NDBC buoy observation data, which has null values for wind, pressure, air temp, visibility for station 46253. All condition stats show "—".

**Fix:** Same API fix as F21 — the fishing detail endpoint needs enriched data from the forecast provider and station hardware, not raw buoy observation.

**F23d. Species Forecast is completely broken — shows empty.**
The species table renders empty. The API's `speciesScores` comes back null or empty. The scoring system exists (`_score_one_species()` with per-species temperature multiplier, tide preference, time-of-day preference, seasonal behavior) but the data pipeline isn't feeding it. Likely causes: species not configured in location config, or the species list doesn't reach the scorer.

**Fix:** Trace the path from `api.conf [marine] → location.fishing.species → score_fishing(species=[...])` and find where the list is dropped. The species YAML database was populated with 20+ SoCal species in a prior phase — the config-to-scorer wiring is broken.

**F23d-research. Industry research — how fishing forecast apps present data (2026-07-13):**

| App | Scoring system | Conditions display | Species display | Solunar display | Tide display | Key visual patterns |
|---|---|---|---|---|---|---|
| **Fishbrain** | BiteScore (1-10 per species, per time slot). Tap any peak time → breakdown of how score was computed + how to fish for them. | Weather, water conditions as 7-day report. Hourly intervals. | BiteTime shows "most likely times of peak activity" per species. Filter by species. AI-powered using fish biologist data + community catches. | Not prominently featured on forecast page. | Tide charts integrated. | Species-first design — forecast organized around what you're trying to catch. Conditions serve the species prediction. |
| **BassForecast** | 0-10 score with labels ("Epic", "Excellent"). 96% claimed accuracy. 10-day forecast. | Barometric pressure monitoring as trigger for "sustained feeding windows." Wind graphs. Water conditions. All merged into unified prediction. | Bait recommendations with thumbnail images (9 lure types). Techniques aligned to predicted conditions. | "Major Time" and "Minor Time" windows with specific hour ranges (e.g., 3:22AM-5:22AM). Pressure + solunar graphs. | Not prominently featured. | Scores + bait + technique = actionable advice, not raw data. |
| **Fish & Tides** | **0-100 Fishing Score** — synthesizes ALL factors. Tap any hour → breakdown of why it got that score. Weighted components: tides (strongest), solunar, moon phase, pressure, wind, water temp, time of day. | Hourly breakdowns across 10-day outlook. Switchable charts (wind, pressure, temperature). | After 2+ catches of a species → reveals "your best tide, time of day, and conditions for each species." Top baits, seasonal patterns. | Major/minor solunar periods, moon phase, illumination integrated into score. | **Dual-line tide chart**: height + water movement speed. Color-coded by direction: white=flood, yellow=ebb, red=slack. Green shading for optimal fishing hours. | 0-100 score with tap-to-explain is the gold standard. Tide chart color coding by direction is brilliant. |
| **Saltwater Tides & Forecast** | 1-5 star rating per day. **Separate inshore and offshore ratings** (conditions that wreck offshore can be perfect inshore). 6-factor engine: solunar alignment, tide phase, wind, barometric pressure, water temp, moon phase. | Tide chart with high/low times, real-time weather, wind speed, marine conditions, water temp, swell data. | Not species-specific. | Solunar major/minor feeding windows with moon phase. | Tide chart with high/low times and heights. | Inshore/offshore split is directly relevant to our harbor vs open-coast locations. |
| **FishWeather** | No numeric score — raw conditions for angler interpretation. | **Foregrounded variables**: wind at water level, barometric pressure trend, water temp, tides, moon phase. 125,000+ station network. Nearcast AI for hyperlocal precision. | Not species-specific. | Moon phase timing. | Marine tides integrated. | Highest data density — built for experienced anglers who read conditions themselves. |
| **Fishing Spots** | Fish activity percentage (0-100%) per day. | 7-day forecast: weather, barometric pressure, wind, sun forecasts, moon phases. | Species lookup feature. Activity percentage presumably species-agnostic. | Moon phase calendar. | Not prominently featured. | Simple percentage is scannable at a glance. |
| **Fishing & Hunting Solunar Time** | 1-3 star daily rating. Historical pattern comparison. | Current weather + 5-day forecast. | Not species-specific. | **Core feature**: major/minor feeding periods, moon rise/set, sunrise/sunset. Calendar view with historical patterns. Hourly breakdowns (premium). | Not featured. | Solunar-first design — the calendar IS the forecast. |

**Common patterns across all fishing apps:**
1. **Single composite score is universal** — 0-100 (Fish & Tides), 0-10 (Fishbrain, BassForecast), 1-5 stars (Saltwater Tides), or percentage (Fishing Spots). One number tells the story.
2. **Tap-to-explain scoring** — Fish & Tides and Fishbrain let you tap any time slot to see WHY it got that score. This is exactly what our scorer computes (pressure 37.5%, tide 31.25%, solunar 18.75%, time 12.5%) but never shows.
3. **Species are first-class citizens** — Fishbrain organizes the entire forecast around species activity peaks. BassForecast recommends specific baits. Fish & Tides learns your personal species patterns. Our species table is empty.
4. **Solunar is a visual timeline, not a score number** — major/minor periods shown as time windows on a horizontal timeline, not just a score. Multiple apps use the calendar/timeline view. Our solunar timeline exists but doesn't match the Almanac page's visual quality.
5. **Tide display uses color-coded direction** — Fish & Tides' flood/ebb/slack color coding is the most sophisticated: anglers need to know not just height but movement direction and speed.
6. **Barometric pressure TREND is the metric, not absolute pressure** — falling pressure = feeding trigger. Our scorer uses `pressure_trend_hpa_3hr` correctly but the dashboard shows "—" because the buoy doesn't report pressure.
7. **Actionable advice, not raw data** — BassForecast shows bait recommendations. Fishbrain tells you how to reel. Fish & Tides shows your personal best conditions per species. Raw numbers serve experienced anglers; advice serves everyone.

**F23e. Conditions breakdown is ugly.**
The conditions breakdown shows the 4 scoring factors (pressure, tide, solunar, time-of-day) as plain text with scores. No visual treatment — just labels and numbers. No bars, no color coding, no indication of what's contributing positively or negatively.

**Fix:** Redesign as horizontal score bars or gauge-style indicators for each factor. Green segments for factors contributing positively, red for negative. Each bar labeled with the factor name and its score. Match the visual treatment to the existing `SemiCircularGauge` pattern or the wind rose Beaufort color bands.

**F23f. The entire scoring system is ignored — same pattern as surf.**
`conditionsText` produces a complete natural-language summary ("Good fishing. Falling pressure and incoming tide favor activity.") that is not displayed anywhere. The per-species scoring with temperature suitability, seasonal modifiers, and closed-season warnings is computed but the UI shows an empty table. The habitat feature detection (dropoffs, ledges, reefs, channels, pinnacles from bathymetry) is not surfaced.

**Fix:** Same pattern as F22h — `conditionsText` as the hero headline, scoring breakdown prominently displayed, species forecast table actually populated and styled, habitat features shown as annotations on a depth profile or as badges.

**Files:** `src/components/marine/tabs/FishingTab.tsx` (dashboard — full redesign), `endpoints/fishing.py` (API — verify species data pipeline), `endpoints/marine.py` (API — enriched observation for fishing detail).

### F24. BeachSafetyTab — redesign required (7 sub-issues)

**Problem:** The Beach Safety tab has broken conditions, a "Dangerous" safety classification the user has explicitly rejected, and no meaningful safety information beyond a few hardcoded thresholds. The plan itself flagged this: *"beachSafetyLevel — current implementation is two if/elif statements with hardcoded thresholds, not thought through"* and *"Overall safety computation — user does not like the approach, needs rethinking."* Despite being flagged, the bad implementation shipped.

**F24a. "Dangerous" safety classification is not thought through — user rejected it.**
`classify_sea_state()` at `beach_safety.py` line 195 uses two hardcoded thresholds: wave height >3ft = "dangerous", period <6s = "dangerous." That's it. No consideration of: beach slope, rip current risk, swimmer skill level, time of day, lifeguard presence, water quality, or any of the factors that real beach safety assessments use. Similarly `classify_water_comfort()` returns "dangerous" for <55°F water temp — a crude label for a nuanced condition. The user explicitly said this approach sucks and was told it would be rethought.

**Fix:** Remove the crude safe/caution/dangerous classification entirely. Replace with a multi-factor conditions summary that presents the actual data — wave height, period, rip current risk, water temp, UV index, wind — and lets the visitor assess. If a composite indicator is desired, it should follow the Beach Report pattern (0-10 score based on multiple weighted factors) rather than two `if` statements.

**F24b. Current conditions panel mostly broken.**
Same root cause as BoatingTab F21a/e — data comes from the raw NDBC buoy observation which returns null for most fields. Wave height shows the offshore buoy value (wrong for beach conditions), wind shows "—", units are inconsistent.

**F24c. No UV index.**
`assessment.uvIndex` is null. QC Gate 6 noted: "uvIndex: null — NWS SRF product does not include UV for this time/WFO." The `UVIndexPanel` component exists but never has data to render.

**Fix:** UV index should come from the configured forecast provider (Aeris/NWS/Open-Meteo), not the NWS SRF product. The forecast provider already returns UV index for `fetch_current_conditions()` — it just needs to be wired into the beach safety endpoint.

**F24d. Rip current risk gets a huge card for one line.**
The `RipCurrentPanel` gets its own full-width `Panel` with a title heading for what amounts to one colored badge ("High" / "Moderate" / "Low") and possibly one line of text. This wastes an enormous amount of space for minimal information.

**Fix:** Rip current risk should be a stat tile within the conditions panel — a colored badge alongside wave height, wind, water temp, and UV. Not its own card.

**F24e. Tide chart clipped — same shared bug.**
Same TideChart left-side clipping as F21f and F22e.

**F24f. No water quality data.**
Beach safety for swimmers in SoCal heavily depends on water quality (bacterial counts, post-rain advisories). Heal the Bay grades 700+ California beaches weekly (A-F). LA County posts advisories. None of this is surfaced. This is out of scope for v1 (the tab explicitly says so) but should be noted for the redesign.

**F24g-research. Industry research — how beach safety sites present data (2026-07-13):**

| Site/App | Safety rating | Conditions display | Rip current | UV display | Water quality | Key visual patterns |
|---|---|---|---|---|---|---|
| **Beach Report** | **0-10 "Beach Day Score"** with plain-English summary. 7-day forecast scores highlight the week's best day. | Air temp + real feel, water temp with warming/cooling trend vs previous week, wind, surf height, current tide height + direction. Golden hour for photography. | Low/moderate/high from NWS. Integrated into the flag system. | UV index with **personalized SPF recommendations** based on skin type. | Red tide status (Florida, via FWC). | **3-tier flag system** (green/yellow/red) — tapping reveals hazard breakdown: NWS alerts, rip current, dangerous surf, strong currents, cold water, high UV. Each hazard is a separate line item, not a single crude label. |
| **BeachScan** | No single score — **personalized recommendations** ("best beach for you right now") based on real-time algorithm analyzing wind, waves, water quality, UV, temperature. | Wind speed/direction + shelter score, sea temp, UV, underwater visibility (meters). Hourly shade timeline (tree vs cliff shade). | Not prominently featured. | Standard metric alongside temp/air quality. | **Official EU bathing water classifications** on each beach card. | Recommendation-first design: "Is it safe to swim today?" answered by conditions, not a single label. |
| **Myrtle Beach** | **Color-coded flag** (green=low hazard, yellow=moderate, red=high, double-red=closed, blue=marine life). | Air temp + conditions, wind (speed + compass), surf height range from NWS forecast. Multi-day weather forecast table. | **Separate prominent card**: red circle icon with "High" — NWS attribution. Always visible, not hidden behind a tap. | Numeric value + tier label ("2 — Low") + protection guidance text. | Not shown. | **Status card grid** at top: flag, rip current, water temp, air temp — four equal cards, all visible at once. Tides as a 4-row table (time + height). |
| **NWS Beach Forecast** | Map-based with **beach umbrella icons** per location. 3-tier rip risk (low/moderate/high). | Water temp, UV index, thunderstorm potential, waterspout risk. | **Color-coded map** — green/yellow/red per beach location. Click umbrella for detail. | 6-tier scale: Low (≤2), Moderate (3-5), High (6-7), Very High (8-10), Extreme (11+). | Not shown. | Government-standard, map-first. Each location click reveals detailed hazard breakdown. |
| **Heal the Bay** | **A-F letter grade** per beach per week. Based solely on fecal indicator bacteria sampling. | Not a conditions app — water quality only. | Not shown. | Not shown. | **Core feature**: NowCast daily predictions. Blue "W+" = low risk, Red "W-" = high risk. Weekly sampling data. Post-rain advisory system. | Letter grades are universally understood. NowCast predictions use ML models correlating environmental conditions with historical bacteria levels. |

**Common patterns across all beach safety sites:**
1. **Multi-factor assessment, never a single crude threshold** — Beach Report uses 0-10 with hazard breakdown. Myrtle Beach uses flag + separate rip + UV + temp cards. NWS uses per-hazard assessment. Nobody uses "wave height >3ft = dangerous" as the sole classifier.
2. **Hazards are itemized, not collapsed into one label** — every site shows rip current, UV, surf, water temp, and wind as separate items that the visitor can evaluate. A single "Dangerous" badge hides which hazard triggered it.
3. **UV is always shown** — every site includes UV index with guidance text (SPF recommendations, exposure limits, protection advice). It's a primary safety metric for beachgoers.
4. **Water temperature trend matters** — Beach Report shows warming/cooling vs previous week. A 68°F reading means different things if it was 72°F last week (cooling) vs 64°F (warming).
5. **Rip current is a separate, always-visible indicator** — not hidden in a conditions panel, but also not a massive standalone card. Myrtle Beach uses a compact status card equal in size to the other hazards.
6. **Flag systems are universally understood** — green/yellow/red flag with optional levels (double red for closure, blue for marine life). Visitors from any beach in the world understand flags. Our "Safe/Caution/Dangerous" text labels are a poor substitute.
7. **Water quality is the elephant in the room** — Heal the Bay grades SoCal beaches weekly. LA County posts advisories. This data exists and is publicly available. Not showing it for beach "safety" is a gap, even if it's v2 scope.

**Files:** `src/components/marine/tabs/BeachSafetyTab.tsx`, `src/components/marine/tabs/SafetyIndicator.tsx`, `src/components/marine/tabs/RipCurrentPanel.tsx`, `src/components/marine/tabs/UVIndexPanel.tsx`, `src/components/marine/tabs/WaterTempPanel.tsx` (dashboard). `endpoints/beach_safety.py` (API — `classify_sea_state()` and `classify_water_comfort()` need replacement).

### F25. ALL marine activity tabs violate the DESIGN-MANUAL — systemic non-compliance

**Problem:** Every marine activity tab (Boating, Surfing, Fishing, Beach Safety) was built ignoring the DESIGN-MANUAL that governs all Clear Skies UI. The tabs look like they belong to a different application. This is the overarching issue — F21–F24 are symptoms of this root cause.

**Specific violations:**

**Card system (DESIGN-MANUAL §6):**
- Tabs use a local `Panel` function (`function Panel({ title, children })`) that mimics card-glass styling but is NOT the `Card` component from `src/components/ui/card.tsx`. No `footprint`, no `rowSpan`, no `CardHeader`/`CardTitle`, no header underline, no approved control components. Every panel is a hand-rolled `<section>` with inline class strings.
- None of the panels use the official card anatomy: header slot → underline → content slot. They're just a `<h3>` followed by children with `gap-3`.
- `StatTile` is a local function in each tab file (duplicated 4 times), not a shared component. It doesn't match the stat tile pattern documented in the DESIGN-MANUAL or used on the Now page.

**Typography (DESIGN-MANUAL §4):**
- Hardcoded `fontSize: 'var(--text-body)'` and `fontSize: 'var(--text-label)'` inline styles everywhere instead of using Tailwind utility classes mapped to tokens. The tokens are used correctly but applied inconsistently — some elements use `style={{ fontSize }}`, others use `className` with Tailwind, mixing patterns within the same component.
- `fontFeatureSettings: '"tnum"'` applied via inline style on every numeric element instead of a shared utility class.

**Grid system (DESIGN-MANUAL §5):**
- The tabs render as a `flex flex-col` with `gap-[var(--gap-grid)]` — a vertical stack of panels. This bypasses the 4-column grid entirely. The tab content should use the same `Grid` component and footprint system as every other page.
- Stat tiles use `grid grid-cols-2 sm:grid-cols-3` — not mapped to any official footprint. The Now page's highlights card and other stat displays use `<dl>` grids within proper Cards.

**Charts (DESIGN-MANUAL §11):**
- Charts use `ChartContainer` (correct) but with hardcoded `height={180}` or `height={220}` pixel values instead of letting the chart fill its card content slot via `ResponsiveContainer` with `width="99%" height="100%"`.
- The TideChart has clipping issues (F21f) suggesting margin/axis configuration doesn't follow the Recharts reference doc (`docs/reference/recharts-axis-reference.md`).

**Component patterns (DESIGN-MANUAL §11):**
- No use of `CardHeader` + `CardTitle` — every panel hand-writes its own `<h3>` with inline styles.
- No use of approved header controls (`HeaderTabs`, `HeaderToggle`, `HeaderSelect`, `HeaderButton`) — any controls are raw elements.
- The swell breakdown (SurfingTab) uses `<ul>/<li>` colored pills — no precedent in the design system.
- The safety indicator (BeachSafetyTab) is a standalone badge component with no design system basis.
- The star rating (SurfingTab) uses Unicode glyphs — no precedent in the design system.
- The beach alignment compass (SurfingTab) is a minimal inline SVG with no relationship to the Wind Compass on the Now page.

**Icons (DESIGN-MANUAL §7):**
- The tabs use Phosphor icons correctly for some elements (trend arrows, caret) but don't use them for stat labels (F16 — no icons on wave height, wind, water temp stats).
- No hero weather icons despite the `WeatherIcon` component existing.

**Data tables (DESIGN-MANUAL §11):**
- The fishing period grid and species table don't follow the data table pattern: no `<thead>/<tbody>`, no `<th scope>`, no alternating row backgrounds, no sticky first column for mobile horizontal scroll.

**Accessibility (DESIGN-MANUAL §16):**
- The tabs use `<section>` elements without `aria-labelledby` pointing to the heading.
- `<details>/<summary>` elements in the NWS text forecast panel don't have visible focus indicators that match the design system.
- Charts have `ChartContainer` with `aria-label` + sr-only data tables (correct), but the data tables are minimal — just time + value columns, no unit labels in headers.

**What compliance looks like:**
Every panel in the marine tabs should be a proper `Card` component with:
- `footprint` and `rowSpan` props
- `CardHeader` + `CardTitle` for the heading
- Header underline
- Content slot using the card padding tokens
- Stats using a shared `StatTile` component (not 4 local duplicates)
- Charts filling the content slot via `ResponsiveContainer`
- Same visual language as the Now page, Forecast page, Almanac page, and Charts page

**This is not a "nice to have" cleanup.** The DESIGN-MANUAL §1 states: "This document is the single authority for all Clear Skies UI design rules. When this document conflicts with any other source, this document wins." The marine tabs were built as if this document doesn't exist.

**Files:** All 4 tab files (`BoatingTab.tsx`, `SurfingTab.tsx`, `FishingTab.tsx`, `BeachSafetyTab.tsx`), all sub-components in `tabs/` (`SafetyIndicator.tsx`, `RipCurrentPanel.tsx`, `UVIndexPanel.tsx`, `WaterTempPanel.tsx`), shared components (`tabs/shared/TideChart.tsx`, `tabs/shared/AlertsPanel.tsx`).

### F17. Phantom text on detail page — fixed on viewport, does not scroll

**Problem:** When viewing the expanded detail page for a location (selected state — back button + hero map strip + activity tabs), there is text that stays fixed on the viewport and does not scroll with the rest of the content. This is the second time this has been reported. T1.5 of the MARINE-CARD-DATA-SOURCE-PLAN was specifically tasked with fixing floating text in all tabs, and QC Gate 1 claimed it passed — but the problem persists.

**Investigation needed:** Open each activity tab (Boating, Surfing, Fishing, Beach Safety) in a browser, scroll the page, and identify which text element(s) remain fixed. Likely candidates:
- A `position: fixed` or `position: sticky` element in the tab content or page layout
- A z-index issue where a text element renders above the scrolling container
- A stacking context problem where the PageHeaderCard title ("Marine Activities") or the location name/back-button bar overlaps scrolling content

**Fix:** Once identified, remove the fixed/sticky positioning or fix the stacking context so all content scrolls together. Every text element on the detail page should be in the normal document flow.

**Note:** This was reported once before and not resolved. The implementing agent must verify the fix **in a browser by scrolling the page**, not by grep alone. QC Gate 1's grep-based verification ("zero floating text elements — every text string is inside a Panel") was insufficient — being inside a Panel does not prevent a parent container from being fixed-positioned.

**Files:** Likely in `src/routes/marine.tsx` (selected state layout), or one of the tab components in `src/components/marine/tabs/`, or `src/components/marine/ActivityTabs.tsx`. Needs browser inspection to identify.

### F12. Remove "Updated X minutes ago" from LocationCards

**Problem:** Each LocationCard shows "Updated 53 minutes ago" at the bottom (`LocationCard.tsx` lines 52–56, 131–135). With the cards moving to `footprint="tile"` (F9), vertical space is constrained. The timestamp adds a full row of text for information that has low value — visitors care about the current conditions, not exactly when they were fetched. The staleness system (ADR-075 `freshness.validUntil`) already handles refetch scheduling; the visitor doesn't need to manage cache freshness manually.

**Fix:** Remove the `updatedLabel` computation (lines 52–56) and its rendering (lines 131–135). Remove the `formatRelativeTime` import if no longer used. The alert badge row (lines 114–136) simplifies to just the alert count badge, or disappears entirely when there are no alerts.

**Files:** `src/components/marine/LocationCard.tsx` (dashboard repo).

### F13. Add hero weather icon next to temperature on LocationCards

**Problem:** The LocationCard shows air temperature as a plain number (`67.2°F`) with no visual indication of weather conditions. Every other temperature display on the dashboard (current conditions card, forecast daily cards, hourly strip) shows a WMO-code-driven weather icon alongside the temperature. The marine cards lack this because `MarineObservation` in `api/types.ts` (line 1172) does not include `weatherCode` or `isDay` fields, even though the API's `_location_summary()` was wired to populate them from the forecast provider in T1.1. QC Gate 1 noted these come back null for the current grid points, but the fields still need to exist in the type and be rendered when available.

**Fix:**
1. **API type:** Add `weatherCode: number | null` and `isDay: boolean | null` to `MarineObservation` in `api/types.ts`.
2. **Card rendering:** When `weatherCode` is non-null, render the existing `WeatherIcon` component (`src/components/weather-icon.tsx`) at ~28px next to the temperature. The `WeatherIcon` component already handles the full WMO code → inline SVG mapping with day/night variants. When null, show temperature only (current behavior — no empty icon placeholder).
3. **API investigation:** Determine why `weatherCode`/`isDay` are null for the SoCal grid points. The forecast provider `fetch_current_conditions()` should return these — if it doesn't for this region, the cache warmer's provider call may need a different query approach or a fallback to the NWS forecast API's icon code.

**Files:** `src/api/types.ts`, `src/components/marine/LocationCard.tsx` (dashboard repo). Possibly `endpoints/marine.py` or `services/cache_warmer.py` (API repo) if the null values are a wiring bug.

### F14. Add operator-uploaded location photo to each LocationCard

**Problem:** The LocationCards are text-only — name, temperature, stats, and that's it. Every location represents a physical beach or harbor, but there's no visual identity distinguishing one card from another. A photo of each location would give visitors instant recognition ("that's the pier, that's the harbor") and make the card grid scannable at a glance. The screenshot reference (Lincoln Cent card) shows the pattern: text content on the left, photo clipped to the card shape on the right.

**Design:**
- Photo occupies the right ~40% of the card, clipped to the card's `rounded-xl` border radius
- `object-fit: cover` with `object-position: center` — the photo fills its region without stretching
- Text content (name, temp, stats) occupies the left ~60%, overlaying the card glass as it does now
- When no photo is uploaded for a location, the card renders text-only (current behavior — no empty placeholder image)
- Subtle gradient overlay (`linear-gradient(to right, rgb(var(--card-glass)) 55%, transparent 100%)`) where text meets photo, ensuring text readability over the image edge

**Photo specs (for help content):**
- Format: WebP (preferred) or JPEG
- Dimensions: 600×400px minimum (landscape orientation)
- Max file size: 200 KB
- Content: recognizable view of the location (beach, pier, harbor, etc.)
- One photo per location

**Storage and serving:**
- Photos stored at `/etc/weewx-clearskies/marine-photos/{location_id}.webp` — same pattern as `branding.json` and `webcam.json` (outside the web root, safe from rsync --delete)
- Caddy serves `/marine-photos/*` via `file_server` from `/etc/weewx-clearskies/marine-photos/`
- API returns the photo URL (or null) in the `MarineLocationSummary` response: `photoUrl: string | null`

**Upload flow:**
- **Wizard:** Marine location step gets a file input per location (after name/coordinates, before activities). Upload is optional. Preview thumbnail shown after selection. File is posted to the API's setup endpoint which writes to the storage path.
- **Admin:** Per-location edit form gets the same file input with preview. "Remove photo" button when a photo exists.
- **API endpoint:** New `POST /setup/marine/photo` accepting `multipart/form-data` with `location_id` and `file`. Validates format (WebP/JPEG), dimensions (≥600×400), file size (≤200KB). Converts JPEG to WebP if needed. Writes to storage path.
- **Help content:** `help.admin.marine.photo` keys describing format requirements, recommended content, and the 200KB limit.

**Files:**
- Dashboard: `src/api/types.ts` (add `photoUrl`), `src/components/marine/LocationCard.tsx` (render photo)
- API: new setup endpoint, `endpoints/marine.py` (include `photoUrl` in summary), `models/responses.py`
- Stack: `step_marine.html` (wizard upload), `marine.html` (admin upload), `routes.py` (admin photo handler)
- Caddy: add `/marine-photos/*` route to Caddyfile variants
- Docs: OPERATIONS-MANUAL help content, ARCHITECTURE.md Caddy routing table

---

## Priority order

| Priority | Finding | Repo | Rationale |
|---|---|---|---|
| **0** | **F0 (wave height + water temp from buoy, not models)** | **API** | **Core data pipeline not functioning — the entire plan's reason for existing** |
| 1 | F4 (bathymetry — admin + wizard) | stack | Contradicts the governing manual — architecture mismatch |
| 2 | F9 (marine page grid conformance) | dashboard | Bypasses official grid system used by every other page |
| 3 | F8 (page header icons — Marine + Seismic) | dashboard | Visually broken — wrong size and weight vs all other pages |
| 4 | F12 (remove "Updated X min ago") | dashboard | Wastes card space, low-value info |
| 5 | F15 (numbered pins + linked hover) | dashboard | Pins indistinguishable, no card↔pin connection, hover too subtle |
| 6 | F16 (stat icons on cards) | dashboard | Wave/wind/water temp stats lack icons unlike every other stat display |
| 7 | F13 (hero weather icon on cards) | dashboard + API | Missing visual — every other temp display has a weather icon |
| 7 | F14 (location photo on cards) | all repos | New feature — photo upload, storage, serving, card rendering |
| 8 | F18 (detail map zoom to single location) | dashboard | Hero map shows all 7 locations instead of zooming to the selected one |
| 9 | F19 (marine feature labels on maps) | dashboard | Maps label streets but not piers, harbors, channels, buoys |
| 10 | F20 (detail map + photo combo card) | dashboard | Replace thin hero strip with map + location photo side-by-side |
| 11 | F21 (BoatingTab complete redesign) | dashboard + API | 7 sub-issues: broken panels, wrong data source, fragmented layout — reported multiple times |
| 12 | F22 (SurfingTab complete redesign) | dashboard + API | 8 sub-issues: scoring system ignored, no surf forecast, fragmented panels, wrong data |
| 13 | F23 (FishingTab complete redesign) | dashboard + API | 6 sub-issues: scoring system ignored, species broken, solunar wrong graphics (reported MULTIPLE TIMES), conditions broken |
| 14 | F24 (BeachSafetyTab complete redesign) | dashboard + API | 7 sub-issues: "Dangerous" classification rejected by user, conditions broken, no UV, rip current oversized, crude thresholds |
| 15 | F25 (DESIGN-MANUAL systemic non-compliance) | dashboard | ALL marine tabs ignore card system, typography, grid, chart, icon, and a11y standards |
| 16 | F17 (phantom fixed text on detail page) | dashboard | Text doesn't scroll — reported twice, T1.5 fix incomplete |
| 9 | F11 (remove "Use my location") | dashboard | Unapproved feature, clutters the page |
| 8 | F10 (responsive map layout) | dashboard | Map layout doesn't adapt to site geography |
| 9 | F1 (admin activity icons) | stack | Unreadable data in the list view |
| 10 | F3 (merged buttons) | stack | Confusing UI — buttons look like a single control |
| 11 | F5 (NWS zone display) | stack | Missing data in the list view |
| 12 | F2 (button sizing) | stack | Poor affordance — buttons too small to recognize |
| 13 | F6 (test relabel) | stack | Misleading label |
| 14 | F7 (column header) | stack | Cleanup — depends on F4 and F6 decisions |

---

## Open questions for the user

1. **F4 (bathymetry):** Should we add a single "Refresh All Bathymetry" button at the top of the admin page as an escape hatch, or rely entirely on automatic download on save?
2. **F6 (test button):** Keep "Check Sources" button in the list view, or remove it and rely on the Data Coverage panel in the edit view?
3. **F5 (NWS zone):** Show the zone ID in the Stations column, or add a separate column?
