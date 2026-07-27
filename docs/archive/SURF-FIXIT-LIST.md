# Surf Page Fixit List

**Created:** 2026-07-20
**Origin:** User review of the live surf page after SWAN-DATUM-PLAN and SWAN-L3-STABILITY-PLAN execution. SWAN is now producing full forecast data with datum-consistent inputs, convergence-gated output, and populated scoring breakdowns. The surf page has UI issues that need correction.

---

## Findings

### SURF-1: Penalty/bonus bars missing from score card — design overhaul

**Severity:** High — visual design
**Surfaces:** Surf Score Card, right column (Beach Alignment, Exposure, Time of Day)

**Problem:** The three penalty/bonus items in the right column of the Surf Score Card display only a label and numeric value — no progress bar. The left column (Wave Height, Wave Period, Wave Organization) correctly shows bars. The penalties look "tacked on" without visual weight.

**Root cause:** The `ScoreBar` component ([SurfingTab.tsx:202-230](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L202-L230)) conditionally renders the bar: `{max ? (<div>...bar...</div>) : null}`. Penalties are passed without a `max` prop (line 1850-1856), so the bar div is never rendered.

**Design direction (user-specified):**

All six scoring items must visually explain the total score out of 100:

1. **Column headers required.** The two-column layout has no labels explaining what each column represents. Add a small section header above each column:
   - Column 1: **"Components"** (or "Score Factors") — the three weighted factors that build the base score
   - Column 2: **"Adjustments"** (or "Penalties & Bonuses") — the three modifiers that adjust the base score up or down
   
   Headers should use `--text-micro` size, uppercase, `--muted-foreground` color, with slight letter-spacing — matching the existing section label pattern used elsewhere on the surf page (e.g., "CONDITIONS AT BREAK", "SWELL BREAKDOWN").

2. **All items get bars.** The three factors (Wave Height 35, Wave Period 35, Wave Organization 30) and the three adjustments (Beach Alignment, Directional Exposure, Time of Day) all render progress bars.

3. **Bars fill relative to 100** (the total possible score). A Wave Height score of 35 fills 35% of the bar. A Beach Alignment penalty of −16 fills 16% of the bar. This shared scale makes all six items visually proportional and their widths add up to explain the total.

4. **Color signals sign:**
   - **Positive scores (factors and bonuses):** fill color from the score tier palette (`--score-1` through `--score-5`, based on relative performance within the category).
   - **Penalties (negative values):** always `--score-1` (orange) fill.
   - **Bonuses (positive adjustments, e.g., dawn time-of-day):** `--score-3` (green/lime) fill.

5. **Labels must state "out of what":**
   - Factors: "Wave Height 35/35", "Wave Period 21/35", "Wave Organization 26/30"
   - Penalties: show the signed point value (e.g., "Beach Alignment −16 pts", "Exposure 0 pts", "Time of Day +5 pts"). The three factors max at 100; penalties/bonuses are adjustments against that 100.

6. **Additive identity visible:** The six displayed values must visibly sum to the total score: 35 + 21 + 26 + (−16) + 0 + 0 = 66/100.

**Implementation notes:**
- `beachAlignment` and `directionalExposure` are always ≤ 0 (penalty only — multiplicative reductions from the sub-total).
- `timeOfDay` is the only adjustment that can be positive (dawn bonus at 1.1× multiplier) or negative (afternoon penalty at 0.9× — currently dead code, see SURF-2).
- Penalties don't have a fixed "max possible" because they're percentage-based deductions from the running sub-total. The bar fills proportional to `|value| / 100`.
- The `ScoreBar` component needs a `mode` prop or similar to distinguish factors (has `max`, fill color from tier) from adjustments (no `max`, fill color from sign).

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — `ScoreBar` component + penalty rendering at lines 1849-1857, add column headers at lines 1838-1858
- Dashboard: `public/locales/en/marine.json` — add column header keys (`surfing.scoring.componentsHeader`, `surfing.scoring.adjustmentsHeader`), add "(penalty)" / "(bonus)" suffixes or "pts" unit to adjustment labels
- Dashboard: all 12 non-English locale files in `public/locales/*/marine.json` — same new keys
- Docs: `docs/manuals/DESIGN-MANUAL.md` — update §16 "Scoring factor breakdown" to document column headers and the penalty/bonus bar design

---

### SURF-2: `timeOfDay` scoring is dead code — silent deferral

**Severity:** High — silent deferral (scoring feature specified, implemented as a no-op)
**Surfaces:** Surf Score Card, 72h Forecast score column, API `/surf/{id}` response

**Problem:** The `timeOfDay` penalty/bonus is always 0 in the API response, making it a dead feature. The scoring spec (ADR-096, API-MANUAL §17) specifies "Positive at dawn, negative in afternoon, 0 otherwise." None of this works. This is a silent deferral — the feature appears implemented (constants defined, function signature accepts the inputs, the field is in the response model) but produces no output.

**Two failures:**

1. **Dawn bonus code exists but caller never passes the inputs:** `score_surf()` ([surf_scorer.py:537](repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py#L537)) accepts `sunrise_utc` and `sunset_utc` parameters. The surf endpoint ([surf.py:656](repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py#L656)) never passes them — they default to `None`, so the dawn detection code path is unreachable. The almanac service already computes sunrise/sunset for the station location. The data is available; it simply wasn't connected.

2. **Afternoon penalty not implemented — bogus excuse in docstring:** Constants `_AFTERNOON_MULTIPLIER = 0.9`, `_AFTERNOON_START_HOUR = 14`, `_AFTERNOON_END_HOUR = 17` are defined ([surf_scorer.py:238-241](repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py#L238)) but never used. The docstring (line 446-449) claims: "converting to station-local hour would require a UTC offset that is not part of this function's inputs." This is false — the station timezone is available in the config (`station_tz` in `api.conf`), Python's `zoneinfo` converts UTC to local time in one line, and the scorer's function signature already accepts additional keyword arguments. The "UTC-only" limitation was a choice to defer, not a technical constraint.

**This is the exact class of bug the SWAN stability audit (T6.1 item 2) was supposed to catch:** "functions that return hardcoded values where real computation was specified." The `_time_of_day_adjustment` function returns `1.0` for 100% of inputs in production — making `timeOfDay` always 0.

**Fix:**
1. Pass `sunrise_utc`, `sunset_utc`, and `station_tz` from the surf endpoint to `score_surf()`. The almanac service (`services/almanac.py`) already computes sunrise/sunset. The station timezone is in the config.
2. Implement the afternoon penalty: convert `time_utc` to local time using `station_tz`, check if it's between 14:00-17:00 local, apply `_AFTERNOON_MULTIPLIER`.
3. Remove the misleading docstring that frames a deferral as a technical limitation.

**Files:**
- API: `endpoints/surf.py` — pass sunrise/sunset/timezone to `score_surf()`
- API: `enrichment/surf_scorer.py` — wire dawn bonus, implement afternoon penalty, fix docstring
- API: `services/almanac.py` — sunrise/sunset already computed; just need to make it accessible to the surf endpoint

---

### SURF-3: Penalty labels don't indicate "out of what" — no denominator context

**Severity:** Low — UX clarity (subsumed by SURF-1 redesign)
**Surfaces:** Surf Score Card, right column

**Problem:** The factor scores show denominators (e.g., "35/35", "21/35", "26/30") making it clear what each is scored out of. But penalties show only a signed integer (e.g., "−16", "0", "0") with no context for what range is possible.

**Resolution:** Addressed as part of SURF-1. The redesigned scoring breakdown shows penalties as "−16 pts" with bar fill proportional to `|value| / 100`, making their impact on the total visually clear. Labels append "(penalty)" or "(bonus)" per the Design Manual spec.

---

### SURF-4: Hardcoded period unit "s" in 72h forecast

**Severity:** Low — unit consistency
**Surfaces:** 72-Hour Forecast Card, period row

**Problem:** The 72h forecast period row ([SurfingTab.tsx:1307](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1307)) hardcodes the unit suffix `s`:
```typescript
`${Math.round(item.entry.period)}s`
```
All other unit displays use the dynamic `periodUnit` variable (resolved from API metadata with `t('surfing.secondsAbbr')` fallback). This row should use `periodUnit` for consistency.

**Fix:** Change to `` `${Math.round(item.entry.period)}${periodUnit}` `` or `` `${Math.round(item.entry.period)} ${periodUnit}` ``.

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` line 1307

---

### SURF-5: Hardcoded fallback unit strings throughout marine components

**Severity:** Low — i18n/l10n
**Surfaces:** Multiple marine tab components

**Problem:** When the API `units` block is not yet loaded (or a specific key is missing), several components fall back to hardcoded US-centric unit strings instead of locale-aware defaults:

| Component | Line | Fallback |
|---|---|---|
| SurfingTab | 1657 | `'ft'` for height |
| SurfingTab | 1658 | `'m'` for distance |
| SurfingTab | 1660 | `'kn'` for wind |
| BoatingTab | ~319-323 | `'kn'`, `'ft'`, `'mb'` |
| FishingTab | ~1278-1291 | `'ft'`, `'kn'`, `'mb'` |
| LocationCard | ~134-136 | `'kn'`, `'ft'` |
| TideChart | 80 | `'ft'` default prop |

These fallbacks are acceptable as safety nets (the API almost always provides the `units` block), but they should use translation keys for consistency with the i18n system. The units block is the primary source; fallbacks rarely fire in practice.

**Fix:** Replace hardcoded strings with `t('units.xxx')` translation keys, or accept the current fallbacks as-is since the API reliably provides the units block. Low priority — cosmetic only for non-US locales that somehow lose the units metadata.

**Files:**
- Dashboard: multiple marine tab components (SurfingTab, BoatingTab, FishingTab, LocationCard, TideChart)

---

### SURF-6: `directionalExposure` reads 0 when it should be active — verify spot config

**Severity:** Medium — data verification
**Surfaces:** Surf Score Card

**Problem:** The `directionalExposure` penalty shows 0 for the Huntington City Beach Pier spot even though the beach has obvious directional limitations (headlands, pier, harbor breakwall). The scorer logic is correct — it reads the `directional_exposure` config from `api.conf`. A value of 0 means either:
1. All 8 compass directions are marked `true` (open) in the config, OR
2. The `directional_exposure` section is missing/empty (defaults to all-open)

In either case, the current swell is coming from an "open" direction. But the config should be verified: Huntington Pier is a SW-facing beach with limited NW and N exposure due to Catalina Island shadow, and limited W exposure due to the harbor breakwall.

**Verification needed:**
1. Check `api.conf` on production for the surf spot's `directional_exposure` settings
2. Compare against the beach's actual geography
3. If all directions are open (default), configure the blocked directions

**Files:**
- API config: `/etc/weewx-clearskies/api.conf` `[nearshore]` section, spot-level `directional_exposure`

---

### SURF-7: SurfScoringBreakdown API-MANUAL table is incomplete

**Severity:** Low — documentation
**Surfaces:** API-MANUAL.md §16

**Problem:** The `SurfScoringBreakdown` table at [API-MANUAL.md:2057-2067](docs/manuals/API-MANUAL.md#L2057) lists the old 4-factor scoring fields (`waveHeight`, `wavePeriod`, `windQuality`, `swellDominance`, `beachAlignment` + weights) but doesn't include the ADR-096 restructured fields: `waveOrganization`, `organizationWind`, `organizationSwellDominance`, `organizationDirectionalSpread`, `organizationCrossSwell`, `directionalExposure`, `timeOfDay`. The updated fields ARE documented later in §17 (line 2819) but the §16 response model table is stale.

**Fix:** Update the `SurfScoringBreakdown` table in §16 to match the actual Pydantic model at [responses.py:1608-1643](repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py#L1608).

**Files:**
- Docs: `docs/manuals/API-MANUAL.md` §16 SurfScoringBreakdown table

---

### SURF-8: Tide height in forecast detail panel uses wave `heightUnit` instead of tide-specific unit

**Severity:** Low — unit accuracy
**Surfaces:** 72h Forecast detail panel, tide event chip

**Problem:** The tide event chip in the forecast detail panel ([SurfingTab.tsx:1387](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1387)) displays tide height using `heightUnit` (wave height unit). Tides are typically measured in feet (MLLW) regardless of whether wave heights are in feet or meters. The API serves tide predictions with their own unit (always MLLW-referenced), but the dashboard uses the wave height unit for the display.

In practice, for US stations both wave height and tide height are in feet, so this doesn't produce a visible error. But architecturally, tide predictions should use their own unit from the units block (e.g., `units?.waterLevel ?? units?.tideHeight ?? heightUnit`).

**Fix:** Use a tide-specific unit from the API units block, falling back to `heightUnit`.

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` line 1387

---

### SURF-9: Beach Profile card — multiple issues

**Severity:** Medium — missing context, unlabeled axes
**Surfaces:** Beach Profile Card

**Problem:** The beach profile chart has several issues that make it hard to interpret:

**9a. No units on either axis.** The Y-axis shows bare numbers (-5, -10, -15...) and the X-axis shows bare numbers (0, 200, 400...) with no indication of whether these are meters or feet. The `distanceUnit` and `heightUnit` props are passed to the component but never rendered on the axis labels. The Y-axis depth labels at [BeachProfileChart.tsx:512](repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx#L512) show `{d === 0 ? '0' : `-${d}`}` — no unit suffix. The X-axis labels at [line 541](repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx#L541) show `{dist}` — no unit suffix.

**9b. No datum label.** After the SWAN-DATUM-PLAN implementation, bathymetry has datum metadata (e.g., NAVD88). The chart should indicate the vertical datum for the depth values (e.g., "Depth (ft, NAVD88)" as a Y-axis title).

**9c. "Distance from shore" label is hardcoded English.** The X-axis label at [line 559](repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx#L559) is a hardcoded string, not a translation key.

**9d. No break point markers — QB threshold too high.** Verified against live API: `breakPoints` array is empty (0 entries). The break detection threshold is QB ≥ 0.25, but the actual transect data shows the highest QB is 0.192 (at shore, 0 ft distance). Three points have non-zero QB:
- 328 ft from shore: QB=0.001, wave height 4.5 ft, depth 12.1 ft
- 164 ft from shore: QB=0.107, wave height 4.6 ft, depth 7.1 ft  
- 0 ft (shore): QB=0.192, wave height 2.5 ft, depth 3.5 ft

QB=0.192 means 19.2% of waves are breaking — that's real surf that a visitor can see. The 0.25 threshold was chosen for "meaningful wave breaking" but it's too conservative for low-to-moderate surf conditions. Most beach breaks in the 3-5 ft range won't hit 0.25 unless conditions are steep/hollow. The threshold should be lowered (e.g., 0.10 or 0.15) or made configurable per spot.

**9e. Break point distance labels have no unit.** When break markers do render, the distance label at [line 493](repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx#L493) shows `{bp.distanceFromShore.toFixed(0)}` — a bare number with no unit.

**Verified live data (2026-07-20):**
- Units block: `{distance: "ft", depth: "ft", waveHeight: "ft"}` — all values are in feet
- Transect: 48 points, extending to 7,710 ft (2,350 m) offshore — clipped to the extended tier max of 3,281 ft (1000 m) for display
- Break points: 0 — QB threshold (0.25) not reached; max QB is 0.192 at shore
- Y-axis labels (-5, -10, ..., -30) are feet but show no unit
- X-axis labels (0, 200, ..., 1000) are feet but show no unit

**Fix:**
1. Add unit suffix to Y-axis labels: `-5 ft` or `-5 m`
2. Add unit suffix to X-axis labels: `200 ft` or `200 m` (or at minimum, include the unit in the axis title: "Distance from shore (ft)")
3. Add a Y-axis title with datum: "Depth (ft, NAVD88)"
4. Replace hardcoded "Distance from shore" with a translation key that includes the unit
5. Lower the QB break point threshold from 0.25 to 0.10 — 19.2% breaking (QB=0.192) is real surf. The threshold is too conservative for typical beach break conditions in the 3-5 ft range. Applied in both the beach_profile endpoint ([beach_profile.py:212](repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py#L212)) and the surf endpoint ([surf.py:~507](repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py#L507)).
6. Add unit suffix to break point distance labels

**Files:**
- Dashboard: `src/components/marine/tabs/BeachProfileChart.tsx` — axis labels, break markers, i18n
- Dashboard: `public/locales/en/marine.json` — add translation keys for axis labels
- API: `endpoints/beach_profile.py` — line 212 (QB threshold), add datum field to response
- API: `endpoints/surf.py` — line ~507 (QB threshold, same constant)

---

### SURF-10: Score card conditions text uses hardcoded imperial units

**Severity:** Medium — i18n
**Surfaces:** Surf Score Card conditions text, 72h Forecast detail panel

**Problem:** The `conditionsText` field in the API response (e.g., "3-5 ft at 9 seconds from the S. Cross-onshore winds 9-14 mph.") is composed server-side in `surf_scorer.py:_compose_conditions_text()` ([surf_scorer.py:462](repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py#L462)). It converts wave height to feet and wind speed to mph using hardcoded unit conversions, regardless of the operator's configured display units.

If the operator configures metric units, the conditions text still says "ft" and "mph" while all other display values show meters and km/h.

**Fix:** Use the operator's configured unit system when composing the conditions text. The scorer already receives the locale; it needs the unit preference as well.

**Files:**
- API: `enrichment/surf_scorer.py` — `_compose_conditions_text()` and `score_surf()` (needs unit config parameter)
- API: `endpoints/surf.py` — pass unit config to `score_surf()`

---

### SURF-11: Swell component decomposition masks data — should present what SWAN computed

**Severity:** High — data quality
**Surfaces:** Current Swell Conditions card, swell component table, surf scoring

**Problem:** SWAN resolves the full 2D wave spectrum at the ~10m depth point (SPECOUT). The ocean almost always has multiple swell systems (primary groundswell + wind swell + secondary swells), and SWAN computes all of them. But the post-processing algorithm in [swan_spectral.py](repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_spectral.py) `decompose_spectrum()` throws away everything except the dominant system before the user ever sees it. This is masking real data that the model already computed.

**Three filtering layers discard real swell systems:**

1. **5% minimum energy threshold** (`min_peak_energy_fraction=0.05`): any spectral partition below 5% of total energy is discarded. A secondary wind swell at 3-4% of total energy is real surf-relevant data — discarding it means the surfer doesn't know it exists.
2. **Narrow neighborhood window** (+/-2 frequency bins, +/-2 direction bins = 25 cells): doesn't capture enough energy for spread-out wind swell systems, so their integrated energy appears smaller than it actually is, making them more likely to fall below the threshold.
3. **Greedy cell exclusion**: the dominant peak claims its neighborhood cells first; overlapping secondary peaks get clipped.

**Consequence for scoring:** With only one component surviving, `_cross_swell_score()` in the surf scorer always returns 1.0 (no cross-swell interference = perfect organization). This inflates the Wave Organization sub-score for every timestep. Real-world conditions with two competing swell systems at conflicting angles should score lower but never do.

**Principle:** The decomposition should present what SWAN found, not editorialize about which components are "significant enough." The table already ranks by energy (primary first), so minor systems naturally sort to the bottom. The user and the scorer can decide what matters — the algorithm shouldn't mask data before either of them see it.

**Fix:** Remove or drastically lower the `min_peak_energy_fraction` threshold (e.g., 0.5% or zero). Widen the neighborhood integration window. Present all detected spectral peaks up to `max_components` (currently 5). If a component is truly negligible, its small height value in the table communicates that — no need to hide it.

**Files:**
- API: `services/swan_spectral.py` — `decompose_spectrum()` algorithm parameters and filtering logic
- API: `enrichment/surf_scorer.py` — `_cross_swell_score()` and `_swell_dominance()` rely on multiSwell component count/ratios

---

### SURF-14: Current Conditions card weather icon always shows daytime

**Severity:** Medium — visual accuracy
**Surfaces:** Current Conditions card on the surf page (hero weather icon)

**Problem:** The weather icon in the Current Conditions card always renders the daytime variant (e.g., sun-behind-cloud instead of moon-behind-cloud at night). The Now page's current conditions card correctly switches between day/night icons using the same `scene.daytime` flag from the `/current` API response.

**Root cause:** The surf page at [SurfingTab.tsx:1737](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1737) reads `obsData.scene?.daytime ?? true` — the fallback is `true` (daytime). If `obsData.scene` is `null` or undefined when the marine page loads (e.g., the `/current` poll hasn't completed yet), the icon defaults to daytime and may never update if the component doesn't re-render after scene data arrives.

The Now page's current conditions card at [current-conditions-card.tsx:654](repos/weewx-clearskies-dashboard/src/components/current-conditions-card.tsx#L654) uses the same pattern (`scene ? !scene.daytime : false`) but receives `scene` as a prop from a parent that's already loaded it. The surf page calls `useObservation()` independently, so the scene may not be ready when the icon first renders.

**Additionally:** The 72h forecast icons at [SurfingTab.tsx:1195](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1195) hardcode `isNight: false` — every forecast column shows a day icon regardless of the timestamp. Each forecast column has a specific time; the code should determine day/night per-timestep using sunrise/sunset times.

**Fix:**
1. Current Conditions icon: ensure `obsData.scene` is reactive — the icon should re-render when scene data arrives from the `/current` poll. If the scene fallback `?? true` is the issue, use the same selection criteria as the Now page's current conditions card.
2. 72h forecast icons: determine `isNight` per-timestep. The hourly forecast data (`hp`) may already carry an `isDay` or `isNight` field, or sunrise/sunset times can be used to compute it from the column's timestamp.

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — lines 1737 (currentDaytime) and 1195 (forecast isNight)

---

### SURF-13: Dominant direction compass too large

**Severity:** Low — visual polish
**Surfaces:** Current Swell Conditions card, right side

**Problem:** The swell direction compass graphic takes up too much space relative to the swell component table on its left. It visually dominates the card when the component table is the more information-dense element.

**Fix:** Reduce the compass size by ~20%. Currently the SVG viewBox is 420×420 and fills its flex container at 100% width ([SurfingTab.tsx:636](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L636)). Constrain the compass container with a `max-width` (e.g., `80%` of current size) or reduce the `flex-1` allocation so the component table gets more horizontal space.

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — `SwellDirectionCompass` container div (line ~1921) or the SVG width style (line 636)

---

### SURF-12: Swell component values don't match "CONDITIONS AT BREAK" — confusing display

**Severity:** Medium — UX confusion
**Surfaces:** Current Swell Conditions card

**Problem:** The "CONDITIONS AT BREAK" row shows Swell Height 2.5 ft / Period 8.6s, while the single swell component below shows 3.1 ft / 11.8s. These look contradictory displayed side by side but are actually different measurements from different locations and methods:

| | CONDITIONS AT BREAK | Swell Component |
|---|---|---|
| **Source** | SWAN TABLE (HSWELL, TM01) | SWAN SPECOUT decomposition |
| **Depth** | Near breaking (~2-5m) | ~10m depth |
| **Height** | SWAN HSWELL (frequency cutoff T>10s) | Spectral partition Hs = 4×√m0 |
| **Period** | TM01 — full-spectrum mean period | Energy-weighted period of one partition |

The height drops from 3.1→2.5 ft because the measurement point is closer to breaking (shoaling/breaking reduces height). The period drops from 11.8→8.6s because TM01 averages the entire spectrum including short-period wind chop, while the component period is just the swell partition.

This is physically correct but creates user confusion. A visitor expecting the component table to explain the headline numbers sees contradictory values with no explanation.

**Fix options:**
1. Add a brief label clarifying measurement depth: "CONDITIONS AT BREAK (near shore)" vs "SWELL COMPONENTS (offshore)" — or similar
2. Show the component table values converted to break-point equivalents so they're visually consistent
3. Add a depth annotation to each section (e.g., "at 10m depth" / "at break point")
4. Document the measurement difference in the scoring explainer modal

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — section headers and labels
- Dashboard: `public/locales/en/marine.json` — label keys

---

### SURF-17: 72h forecast "Swell Height" row actually shows breaking face height

**Severity:** Medium — mislabeled data
**Surfaces:** 72-Hour Forecast Card, "Swell Height" row

**Problem:** The row header says "Swell Height" ([SurfingTab.tsx:1091](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1091), translation key `surfing.swellHeightLabel`) but the values come from `getDisplayHeight()` ([SurfingTab.tsx:1286](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1286)) which returns `breakingFaceHeight` (trough-to-crest height after the Komar-Gaughan/Caldwell breaker formula). These are different quantities:

- **Swell Height** (`swellHeight`): SWAN HSWELL at ~10m depth — the raw offshore swell energy
- **Breaking Face Height** (`breakingFaceHeight`): trough-to-crest wave face height after the breaker formula — what a surfer sees at the beach

The breaking face height is typically 50-60% larger than the swell height (e.g., 3.9 ft face vs 2.5 ft swell in observed data). Labeling face height as "Swell Height" understates what surfers expect from a "swell height" label and overstates what oceanographers expect.

**Fix:** Change the row header label to match the displayed value. If `surfHeightDisplay === "face"`, label should be "Wave Height" or "Face Height". If `surfHeightDisplay === "hawaiian"`, label should be "Wave Height (Hawaiian)". The translation key `surfing.swellHeightLabel` should be updated or a new key used. The row header column (`ROW_HEADER_W = 80px`, `whiteSpace: 'nowrap'` at [SurfingTab.tsx:849](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L849)) will need word wrap enabled since longer labels like "Breaking Face Height" won't fit in 80px on one line.

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — line 1091 (row header label), line 849 (`ROW_HEADER_STYLE` whiteSpace)
- Dashboard: `public/locales/en/marine.json` — `surfing.swellHeightLabel` key
- Dashboard: all 12 non-English locale files

---

### SURF-16: Wind row header in 72h forecast missing unit

**Severity:** Low — UX clarity
**Surfaces:** 72-Hour Forecast Card, "Wind" row header

**Problem:** The row header just says "Wind" with no unit indication. The WindSymbol component shows a speed number inside the circle (e.g., "4", "2", "1") but there's no way for the visitor to know if that's knots, mph, or km/h. Other rows include their units (Air Temp shows "°F", Swell Height shows "ft"), but Wind does not.

**Fix:** Append the unit to the row header label — e.g., "Wind (kn)" or "Wind (mph)" — using the dynamic `windUnit` variable already available in the `SurfScrollForecast` component (passed as a prop at [SurfingTab.tsx:870](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L870)). The row header is rendered at [SurfingTab.tsx:1078](repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx#L1078).

**Files:**
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` — line 1078 (Wind row header)

---

### SURF-15: Swell dominance (Power row) always 100% — consequence of SURF-11

**Severity:** Medium — data accuracy (direct consequence of SURF-11)
**Surfaces:** 72-Hour Forecast Card, "Power" row

**Problem:** The "Power" row in the 72h forecast shows 100% for every single column. This value is `swellDominance` — the ratio of primary swell energy to total spectral energy. It's 100% because the spectral decomposition (SURF-11) only ever produces one component, so that component IS 100% of the energy by definition.

In reality, the ocean almost always has some wind chop or secondary swell contributing energy. A true swell dominance of 100% would mean perfectly clean, single-source conditions — exceptional, not the norm. The 100% value is an artifact of the decomposition masking secondary systems, not a reflection of actual conditions.

**Additionally:** The `_swell_dominance()` scoring sub-factor uses this ratio. With dominance always at 1.0, that sub-factor always awards maximum points (7.5 out of 7.5), inflating the Wave Organization score.

**Fix:** Resolves automatically when SURF-11 is fixed — with multiple components surviving the decomposition, swell dominance will reflect the actual energy distribution.

**Files:**
- API: `services/swan_spectral.py` — root cause is SURF-11
- API: `enrichment/surf_scorer.py` — `_swell_dominance()` sub-factor
- Dashboard: `src/components/marine/tabs/SurfingTab.tsx` line 1311 — renders `swellDominance × 100` as "Power"

---

### SURF-20: Beach Profile chart — water column invisible, wave envelope floats in air

**Severity:** Medium — visual quality
**Surfaces:** Beach Profile Card

**Problem:** The chart shows the tan seafloor sloping up to shore and the blue wave envelope above the surface line, but the water column between them is effectively invisible. The water fill at [BeachProfileChart.tsx:410](repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx#L410) uses `rgba(59, 130, 246, 0.08)` — 8% opacity blue. Against the dark glass card background (which shows the page's starfield/gradient), 8% opacity is transparent. The result: the wave envelope appears to float in empty space above the seafloor, with the page background visible between them.

A cross-shore beach profile should show: seafloor (tan) → water column (blue) → wave envelope (lighter blue) → air above. Currently it reads as: seafloor (tan) → air/space → wave blob floating → more air.

**Fix:** The entire region from the water surface down to the seafloor should read as one cohesive body of water — not two disconnected tones that look broken against a dark background. Design direction:

1. **Water column** (surface line → seafloor): solid visible blue fill — one color, one opacity, reads as "this is water." Something like `rgba(59, 130, 246, 0.20–0.30)` — visible but still translucent enough for gridlines. This is the primary visual element.

2. **Wave envelope** (surface line → wave crest): a slightly lighter/brighter blue accent above the surface to show wave height variation. It should look like the top of the same water body, not a separate floating shape. A subtle gradient or slightly higher opacity (`0.35–0.45`) connecting seamlessly to the water column below.

3. **No gap between them.** The wave envelope's bottom edge must sit exactly on the water surface line, and the water column's top edge must also be the surface line. Right now they're technically aligned but the near-invisible water column creates a visual gap.

Currently `seafloorPoints` is drawn twice — once as sand (line 362) and once as clipped water (line 407). A proper water column polygon should span from the surface line down to the seafloor contour, filling only the wet area — not reusing the sand polygon with a clip.

**Files:**
- Dashboard: `src/components/marine/tabs/BeachProfileChart.tsx` — line 410 (water column fill opacity)

---

### SURF-19: CURVE transect samples at 50m — 5× coarser than the L3 grid

**Severity:** High — data quality
**Surfaces:** Beach Profile card, break point detection, surf scoring

**Problem:** The Level 3 SWAN grid computes wave dynamics at 10m resolution, but the CURVE transect output samples it every 50m ([swan_formats.py:461](repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py#L461): `spacing_m: float = 50.0`). This means:

1. **The break zone is captured in 2-3 data points.** A typical beach break zone is 50-100m wide. At 50m spacing, the entire zone falls between one or two sample points. The actual QB peak — which the 10m grid resolved — is missed because we never asked SWAN for it.

2. **Break point detection fails.** The QB threshold of 0.25 is never reached partly because the samples land on either side of the actual peak. The real QB maximum could be 0.3+ between the 50m and 0m sample points, but we'll never know.

3. **The beach profile chart shows a crude linear slope** instead of the sandbar/trough structure that the 10m grid captured. Sandbars are typically 20-40m features — invisible at 50m sampling.

**Verified:** Live transect has 48 points at uniform 50m spacing over 2,350m. The `max_points` parameter is 200, so 10m spacing over even the full transect (235 points) barely exceeds the cap. At 10m spacing over the relevant nearshore zone (0-500m), that's only 50 points.

**Fix (two parts):**

**Part 1 — Increase CURVE resolution:** Change `spacing_m` from 50.0 to 10.0 (match the L3 grid resolution). The model already computed the data at this resolution — there's no added computational cost, only a few more lines in the CURVE output file. The `max_points=200` cap may need a small increase for very long transects, or use variable spacing (10m nearshore, 50m offshore).

**Part 2 — Sub-grid break point interpolation:** Even at 10m CURVE spacing, break point locations have ±33 ft uncertainty (one grid cell). Use the breaking criterion H/d ≈ γ (0.73, same as SWAN's `BREAKING CONSTANT`) to interpolate the exact break location within the cell:

1. SWAN CURVE at 10m gives wave height H and breaking fraction QB at each point.
2. Identify the cell where QB spikes (or where H/d approaches γ).
3. Between the two bounding CURVE points, interpolate depth using the **CUDEM bathymetry profile** — which is 3-10m native resolution, already downloaded and cached. The fine-scale sandbar/trough structure is known from CUDEM even though SWAN's grid is 10m.
4. Linearly interpolate H between the two CURVE points (wave height varies smoothly over 10m).
5. Solve for the distance where H(x) / d(x) = γ. This is simple algebra — no additional model runs.

This gives sub-grid break point precision (~3-5m) at zero computational cost using data already available (SWAN output + CUDEM bathymetry cache).

**Part 3 — 1D cross-shore wave transformation for the profile chart:** SWAN is a phase-averaged spectral model — it outputs wave statistics (H, T, direction) at each grid cell, not wave shapes. But those statistics can seed a 1D analytical wave transformation along the transect at CUDEM's native resolution (3-10m), producing a physically-based wave profile with hundreds of points instead of 48:

1. Take SWAN's H, T, and direction at the ~300m-from-shore point (~5-6m depth) as the boundary condition. Nothing interesting happens further offshore — SWAN already solved the shelf propagation, refraction, and wind interaction. The 1D model only handles the last ~300m where shoaling, breaking, and reformation actually occur.
2. Walk inshore from that boundary along the CUDEM bathymetry at its native 3-10m resolution.
3. At each step, apply **shoaling** (linear wave theory: group velocity ratio Ks = √(Cg_deep / Cg_shallow) → wave height increases as depth decreases).
4. Apply **refraction** corrections if the wave angle changes relative to bathymetric contours.
5. When H/d exceeds γ (0.73) → breaking → apply dissipation (energy decay proportional to excess H/d).
6. Post-breaking: height decays, wave may reform over a trough, break again over the next bar.

This produces:
- A smooth wave height envelope showing buildup over sandbars, reduction in troughs, precise break points, and post-breaking decay — real wave transformation, not flat lumps.
- Exact break point locations at CUDEM resolution (±3-5m).
- Optionally: the actual wave surface shape (crests/troughs) via `η(x) = H(x)/2 × cos(2π·x/L(x))` where L is the local wavelength from the dispersion relation at each depth. The chart would show waves steepening and breaking over bars.

Computationally trivial — algebra on existing data (SWAN output + CUDEM bathymetry), runs in milliseconds. SWAN already did the expensive spectral computation; this is 1D post-processing along one transect line. Standard technique used by CSHORE, SBEACH, and surf forecast platforms.

**Files:**
- API: `services/swan_formats.py` — line 461 (`spacing_m` parameter)
- API: `endpoints/beach_profile.py` — break point detection (add sub-grid interpolation)
- API: `endpoints/surf.py` — break point detection (same algorithm, keep in sync)
- API: new module (e.g., `enrichment/wave_profile.py`) — 1D cross-shore transformation using SWAN boundary conditions + CUDEM bathymetry

---

### SURF-18: Tide chart "Now" line too subtle — doesn't match Now page style

**Severity:** Low — visual polish
**Surfaces:** Tide Forecast card (all marine activity tabs that include the tide chart)

**Problem:** The "Now" vertical line on the tide chart uses `stroke="var(--foreground)"` (same as regular text), `strokeWidth={1}`, and `strokeDasharray="2 4"` ([TideChart.tsx:318-319](repos/weewx-clearskies-dashboard/src/components/marine/tabs/shared/TideChart.tsx#L318)). It blends into the busy chart environment and is easy to miss.

The Now page's current conditions card uses a much more visible treatment: `stroke="#dc2626"` (red-600), `strokeWidth={1.25}`, `strokeDasharray="2 2"` ([current-conditions-card.tsx:231-233](repos/weewx-clearskies-dashboard/src/components/current-conditions-card.tsx#L231)). The red color and tighter dash pattern make it immediately identifiable.

**Fix:** Match the Now page's "Now" line styling in the tide chart:
- `stroke="#dc2626"` (or the equivalent semantic token if one exists)
- `strokeWidth={1.25}`
- `strokeDasharray="2 2"`
- Keep the "Now" label at the top

**Files:**
- Dashboard: `src/components/marine/tabs/shared/TideChart.tsx` — lines 316-327 (ReferenceLine props)

---

### SURF-21: Single transect through OBSTACLE — 31% energy loss at reference point

**Severity:** Critical — produces wrong wave heights
**Surfaces:** All surf height numbers — breakingFaceHeight, swellHeight, multiSwell, scoring

**Problem:** The single CURVE transect for HB Pier passes through the pier's OBSTACLE, which blocks ~31% of wave energy between 10.3m and 7.4m depth. The reference point at ~10m picks up a pier-shadowed Hs value. The result: our breakingFaceHeight is 2.76ft when actual conditions are 5-7ft (confirmed by Surfline, NWS surf advisory, and nearby buoys reading 3.3-3.6ft Hs).

**Evidence (2026-07-20 live data):**
- SWAN CURVE Hsig at 11m depth (pre-pier): 0.875m (2.87ft) — consistent with buoys
- SWAN CURVE Hsig at 9.2m depth (pier shadow): 0.634m (2.08ft) — 28% lower
- SWAN CURVE Hsig at 3.1m depth (post-pier, shoaling): 0.977m (3.20ft)
- SWAN CURVE Hsig at 1.6m depth (breaking, QB=0.107): 1.014m (3.33ft)
- Nearby buoys: San Pedro South 3.3ft, Long Beach Channel 3.6ft
- Surfline surf height: 5-7ft faces
- Our breakingFaceHeight: 2.76ft

The wave energy at the L3 boundary (16m, 2.78ft) is correct. The transect through the pier shadow drops it to ~2.0ft in the shadow zone. The reference point selection picks up this shadowed value.

**Root cause:** `compute_spot_transect()` draws one line from the pin along `beach_facing_degrees`. Even though the pin is south of the pier, the transect line clips the pier's OBSTACLE zone. With a single transect, there is no alternative measurement to compare against.

**Fix:** Multi-transect architecture (SURF-ZONE-MODEL-BRIEF §2.2) with obstacle-aware transect validation (SURF-24). In the interim, the single-transect reference point should be selected from outside any OBSTACLE shadow zone — either by checking if the ref point's Hs shows an anomalous dip relative to neighboring points, or by selecting the ref point from the pre-pier (offshore) portion of the transect.

**Files:**
- API: `services/swan_formats.py` — `compute_spot_transect()` (transect geometry)
- API: `endpoints/surf.py` — ref_point selection (lines 538-560)
- API: `services/swan_runner.py` — CURVE/TABLE output and OBSTACLE emission

---

### SURF-22: K-G/Caldwell applied at ~10m ref depth, not at break point

**Severity:** Critical — systematically underestimates face height
**Surfaces:** breakingFaceHeight on the surf forecast card

**Problem:** The Komar-Gaughan formula is designed to convert **deep water Hs** to **breaking face height**. We feed it the Hs at the ~10m reference point (or just-offshore-of-break, which is better but still has a depth reduction applied). The code then applies an ad-hoc linear depth correction (lines 187-201 in `breaker_height.py`) that reduces K-G amplification by `1 - depth/15` — at 10m depth, this cuts 33% of the amplification. At 3m depth (just-offshore-of-break ref point), it cuts 80%.

This linear interpolation has no physical basis. Shoaling is nonlinear and wavelength-dependent.

**Evidence:** For the 01:00Z timestep:
- Hs at ref point: 0.58m (1.90ft)
- K-G full (deepwater formula): 0.97m (3.18ft)
- After depth correction: 0.84m (2.76ft)
- Actual conditions: 5-7ft faces

Even WITHOUT the depth correction, K-G full at 3.18ft is still half of reality — because the INPUT Hs (1.90ft at the ref point) is already too low (pier shadow, SURF-21). The two bugs compound.

**Fix:** The 1D model (SURF-ZONE-MODEL-BRIEF) solves this properly: transform Hs from the handoff point to the actual break, then apply K-G/Caldwell at the break point with the correct Hs. The ad-hoc depth correction is eliminated.

**Files:**
- API: `enrichment/breaker_height.py` — `hsig_to_face_height()`, `SHALLOW_DEPTH_THRESHOLD_M`, depth correction block (lines 187-201)

---

### SURF-23: Swell display uses nearshore-transformed values, not deep water

**Severity:** High — confusing to surfers
**Surfaces:** multiSwell on the Current Swell Conditions card

**Problem:** The multiSwell component heights come from SWAN SPECOUT decomposition at a nearshore reference point. These are post-refraction, post-structure-interaction values — not the deep water swell heights that the surf community conventionally reports. Surfline explicitly defines "swell" as deep water height before nearshore transformation. Our values are comparable (~2.16ft vs Surfline's 2.6ft for the dominant component) but systematically lower because they include nearshore losses.

**Industry convention (verified):**
- **"Swell height"** = deep water, before nearshore transformation (what NDBC buoys measure, what Surfline/NWS report)
- **"Surf height"** = face height at the break point (Surfline's headline number)
- **Our display** = SPECOUT decomposition at ~10m nearshore depth — neither convention

**Fix:** Swell decomposition should reference a deep water spectrum source: WaveWatch III partitions, SWAN at L1/L2 boundary (before nearshore transformation), or NDBC buoy spectral data. The nearshore SPECOUT continues to feed the 1D model (as boundary conditions), but is NOT displayed as "swell" to the user.

**Files:**
- API: `endpoints/surf.py` — multiSwell construction (lines 697-713)
- API: `services/swan_spectral.py` — SPECOUT decomposition
- Reference: Surfline swell vs surf definition — https://support.surfline.com/hc/en-us/articles/4410126820891-Swell-vs-Surf

---

### SURF-24: No obstacle-aware transect validation

**Severity:** High — affects any spot near a structure
**Surfaces:** All transect-derived metrics at structure-affected spots

**Problem:** When the multi-transect architecture is implemented, some transects will inevitably cross OBSTACLE structures (piers, jetties, breakwaters). These transects will show artificially reduced wave heights in the shadow zone. If included in "best peak" or "spot average" calculations without flagging, they contaminate the reported values.

Additionally, the operator places the spot pin on a map — they should not need to manually avoid structures. The system must be smart enough to detect when a transect crosses an OBSTACLE and handle it appropriately.

**Required behavior:**
1. After computing transect geometry, cross-check each transect against the configured OBSTACLE structures
2. Flag any transect that intersects an OBSTACLE as "structure-affected"
3. Exclude structure-affected transects from "best peak" and "spot average" calculations (or report them separately as "in the pier/jetty shadow")
4. Structure-affected transects can still appear on the quasi-2D heat map — they show real physics (the shadow is real), but should not drive the headline surf height

**Design connection:** The handoff algorithm in SURF-ZONE-MODEL-BRIEF §2.3.4 already computes geometric shadow zones for handoff depth determination. The same shadow geometry can flag which transects are structure-affected. This is one computation serving two purposes.

**Files:**
- API: `services/swan_formats.py` — `compute_spot_transect()` (needs multi-transect + obstacle check)
- API: `services/swan_runner.py` — OBSTACLE structure coordinates (already computed at runtime)

---

## Summary

| ID | Issue | Severity | Component |
|---|---|---|---|
| SURF-1 | Penalty bars missing from score card | High | Dashboard |
| SURF-2 | timeOfDay scoring is dead code (silent deferral) | High | API |
| SURF-3 | Penalty labels lack denominator context | Low | Dashboard |
| SURF-4 | Hardcoded "s" unit in 72h period row | Low | Dashboard |
| SURF-5 | Hardcoded fallback unit strings | Low | Dashboard |
| SURF-6 | directionalExposure config may be all-open | Medium | Config |
| SURF-7 | SurfScoringBreakdown API-MANUAL table stale | Low | Docs |
| SURF-8 | Tide chip uses wave height unit | Low | Dashboard |
| SURF-9 | Beach Profile card missing datum label | Low | Dashboard |
| SURF-10 | Conditions text uses hardcoded imperial | Medium | API |
| SURF-11 | Swell decomposition masks data (1 component) | High | API |
| SURF-12 | Swell component values don't match headline stats | Medium | Dashboard/UX |
| SURF-13 | Dominant direction compass too large | Low | Dashboard |
| SURF-14 | Weather icons always show daytime (hero + forecast) | Medium | Dashboard |
| SURF-15 | Swell dominance (Power) always 100% | Medium | API (consequence of SURF-11) |
| SURF-16 | Wind row header missing unit | Low | Dashboard |
| SURF-17 | "Swell Height" row shows breaking face height | Medium | Dashboard |
| SURF-18 | Tide chart "Now" line too subtle | Low | Dashboard |
| SURF-19 | CURVE transect 50m spacing (5× coarser than grid) | High | API |
| SURF-20 | Water column invisible (8% opacity), waves float in air | Medium | Dashboard |
| SURF-21 | Single transect through OBSTACLE → 31% energy loss in ref point | Critical | API |
| SURF-22 | K-G/Caldwell applied at ~10m ref depth, not at break point | Critical | API |
| SURF-23 | Swell display uses nearshore-transformed values, not deep water | High | API |
| SURF-24 | No obstacle-aware transect validation | High | API |
