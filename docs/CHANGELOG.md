# CHANGELOG

All notable changes to the weather-belchertown project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### 2026-08-27 — S3(b): `level1` label rename to `deep_water` (marine, cosmetic)

- **Marine repo, code/cache label only — no formula, grid, or wire field changed.** `level1`
  named the deep-water domain's *geometry extent* (consumed by WW3's own grid sizing), not a
  running SWAN level — SWAN's own L1 compute was removed 2026-08-23. `DomainSizing.level1` →
  `DomainSizing.deep_water`; `_compute_level1()` → `_compute_deep_water()`;
  `compute_level1_domain()` → `compute_deep_water_domain()`; all
  `domains.level1`/`sizing.level1`/`stage1.level1` → `.deep_water`; in-memory bathymetry dict
  key `"level1"` → `"deep_water"` — verified nothing reads it back by the old key.
- **Persisted `swan_grid_sizing.json` key (migration, no operator action):**
  `domain_sizing_to_dict()` now writes `deep_water` only; `domain_sizing_from_dict()` and
  `grid_sizing_chain._domain_geometry_signature()` read `deep_water`, falling back to the
  legacy `level1` key (one INFO log per load) for a cache written before this change. The
  next sizing-chain run rewrites the file with the new key automatically.
- **Unchanged by design:** the on-disk `swan/level1/` run directory, the ETOPO cache filename
  `swan_bathymetry_L1.json`, and the 22 `B_*.txt` boundary scaffold files keep their existing
  on-disk names — only the code-side label changed. New named constants
  (`SWAN_LEVEL1_DIRNAME`/`_SWAN_LEVEL1_DIRNAME`) document the surviving on-disk literal.
- **Docs:** ARCHITECTURE.md `:107` follow-up sentence (rename tracked as done); PROVIDER-MANUAL
  updated wherever it named the `level1` sizing block/function; OPERATIONS-MANUAL gains the
  migration note above; marine `CHANGELOG.md`.

MARINE-AND-MAPS-PLAN-2026-08-27.md §S3 (b); brief
`docs/planning/briefs/S3B-LEVEL1-RENAME-BRIEF-2026-08-27.md`.

### 2026-08-27 — M4-B: Imagery provider machinery removed (Q10-6)

- **The Esri/NAIP orthophoto imagery providers are gone.** Operator ruling, plan Q10-6,
  2026-08-27: "if we dont need it then get rid of it." Nothing user-facing had read the
  `[imagery]` provider since M4's SURF-MAP-BASEMAP change made `GET /imagery/config` always
  answer the product basemap (PA9, Q5).
- **API:** `git rm` on `providers/imagery/{esri,esri_topo,naip}.py` + `__init__.py`; the three
  `("imagery", ...)` rows removed from `providers/_common/dispatch.py`; `ImagerySettings` deleted
  from `config/settings.py` (an existing `[imagery]` section in `api.conf` now loads silently
  ignored — no crash, no warning); startup dispatch checks and `wire_imagery_settings()` removed
  from `__main__.py`; `wire_imagery_settings`/`reset_imagery_settings_for_tests`/
  `_select_provider`/module globals/`GET /imagery/tiles/{z}/{x}/{y}` removed from
  `endpoints/imagery.py` (that route now 404s); `ImageryTileQueryParams` removed from
  `models/params.py`; `"imagery"` dropped from `endpoints/setup.py`'s `_PROVIDER_DOMAINS`.
  `GET /imagery/config` is unchanged (byte-identical response, `lat`/`lon` still required params).
- **Stack:** admin Imagery section, wizard step-6 imagery fieldset, `imagery_api_key`, and the
  `help.admin.imagery-provider.*`/`help.wizard.imagery.*` locale keys removed. The marine-step
  satellite toggle (`step_marine.html`) stays — it is operator-only, a direct browser URL, per
  the Q10-6 text.
- **Contract + docs:** `docs/contracts/openapi-v1.yaml` — `/imagery/tiles/{z}/{x}/{y}` path
  removed (`/imagery/config` unchanged); API-MANUAL §12a rewritten; OPERATIONS-MANUAL gains a
  legacy-`[imagery]`-section migration note; PROVIDER-MANUAL §16 replaced with a one-line removal
  pointer; stack OPERATOR-MANUAL admin/wizard imagery sections removed.

MARINE-AND-MAPS-PLAN-2026-08-27.md §Q10 item 6; PA9 (extended); brief
`docs/planning/briefs/M4B-IMAGERY-REMOVAL-BRIEF-2026-08-27.md`.

### 2026-08-27 — S8.1-B: WW3 `ww3_grid` production rebuild hook (ADR-109 Gap G10, closed)

- **`mod_def.ww3` (WW3's G1 grid build artifact) is no longer a hand-minted, never-rebuilt
  file.** `service.py::_run_ww3_leg()` (marine repo) gains the production `ww3_grid`
  execution hook (ADR-109 Gap G10, previously unbuilt — `WW3Runner.run_grid()` existed
  standalone since Phase W but nothing called it): once per cycle, before restart chaining,
  it reconstructs the current WW3 setup derivation from the grid-sizing cache
  (`swan_domain.ww3_setup_derivation_from_dict()`, new, the inverse of
  `ww3_setup_derivation_to_dict()`), renders the deck + the three NAME files, hashes them
  (`ww3_grid_files.derivation_grid_sha256()`, new), and compares against
  `level0/mod_def.provenance.json`. A hash mismatch (or missing/unreadable note) triggers a
  rebuild: the superseded artifact is kept as `mod_def.ww3.prev-<token>` (retained
  indefinitely — rebuilds are rare), the new one promoted, the provenance note written
  atomically, and that cycle cold-starts (`ww3_grid_rebuilt_cold_start` — not a leg refusal,
  the cycle still runs). A sizing cache still missing the S8.1-A transparency arrays trusts
  an existing readable provenance note or refuses (`ww3_grid_rebuild_inputs_missing`) — no
  ETOPO substitution, no on-the-fly derivation.
- New named refuse/health slugs: `ww3_grid_rebuild_inputs_missing`, `ww3_grid_rebuild_failed`,
  `ww3_grid_rebuilt_cold_start`. `/health`'s `ww3` block gains `gridRebuiltAt`,
  `gridRebuildReason`, `gridDerivationSha256`, `gridRebuildCycleTime`, `restartRefusedReason`
  (additive, `state.py`'s new `record_ww3_grid_rebuild()`).
- OPERATIONS-MANUAL.md gains a "WW3 grid rebuild (G10 hook)" subsection: triggers, files
  written, the cold start that follows, baseline/diff commands, and the sanctioned
  force-rebuild procedure (delete the provenance note). ADR-109's S8.1-A amendment gains a
  closing paragraph marking Gap G10 closed. ARCHITECTURE.md's ⚓ WW3 paragraph updated.

MARINE-AND-MAPS-PLAN-2026-08-27.md §S8.1 Lead mechanics "S8.1-B"; ADR-109 Gap G10.

### 2026-08-27 — S2: CONSISTENCY-SCORING — Consistency factor rebuilt on spectral group statistics (ADR-101 Amendment 1)

- **The Consistency scoring factor (0.10 weight, `SurfScoringBreakdown.consistency`) is no longer the
  interim swell-dominance bucketing.** `consistency = 0.6 × timing + 0.4 × amplitude`, read off the
  dominant `multiSwell` partition's spectral group statistics — a new `services/wave_groups.py`
  (marine repo) computes Longuet-Higgins spectral width (ν), Goda peakedness (Qp), the Battjes & van
  Vledder (1984) successive-height correlation (κ), and Kimura (1980) bivariate-Rayleigh run-length
  statistics (N_rep, T_set) per partition, attached as scalars at parse time (`services/
  swan_runner.py`'s L2 DWR entry build) — no 2-D array ever attached (M-0b memory rule). Falls back to
  the pre-S2 swell-dominance bucketing, byte-identical, whenever the dominant partition carries no
  group statistics.
- **`SpectralWaveComponent` (marine `models/responses.py`, API-MANUAL §16/§17) gains seven optional
  fields** on `multiSwell` entries: `nu`, `qp`, `kappa`, `tm02S`, `nRep`, `tSetS`, `bandHz`. The API's
  companion-proxy conversion layer (`marine_response_conversion.py`) passes unknown component fields
  through unconverted by design (verified, no API-repo change needed — same treatment already given to
  the existing `energy`/`frequencyRange` fields on the same container).
- API-MANUAL §17 `SurfScoringBreakdown.consistency` row and `SpectralWaveComponent` field table
  updated; DESIGN-MANUAL gains the ADR-101 Amendment 1 Consistency explainer wording.
- ADR-101 Amendment 1 ("Consistency (row 5)") — design source; `docs/planning/briefs/
  SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md`, `WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md`,
  `PARTITION-NARROWNESS-SURVEY-2026-08-23.md` — supporting research and KAT reference values.

MARINE-AND-MAPS-PLAN-2026-08-27 §S2, PA6; Q3 sub-decisions A–E; Q10 item 1.

### 2026-08-27 — S3: doc corrections (wrong no-op/vestigial claims) + swellSource/closeoutFraction documented + ww3_boundary input recorded

- **Docs only (part a).** An adversarial plan review found ARCHITECTURE.md wrongly called
  two live production dependencies "no-op"/"vestigial": the `ww3_chain_enabled` flag (still
  gates both buoy-ledger writers, `vchain.py:914`/`:978`) and
  `_reused_l1_boundary_command_lines()` (called every production chain cycle from
  `vchain._stage_l2_boundary()`, `vchain.py:727`). Both corrected — nothing live is deleted
  by this round. ARCHITECTURE.md Known-gaps rows #12/#13 (WW3 wind regrid, L2 boundary
  point list) verified BUILT and closed; #14 (`ww3_grid` geometry hook) confirmed still
  unbuilt, moved to Phase S8.1; #16 (seam AGG question) CLOSED — Phase V dropped (Q1), the
  per-cycle buoy ledger is the standing instrument. ADR-109 G7 struck as built; D14 item 2
  re-homed to the same Phase-V-dropped finding; items 1/3 unchanged. PROVIDER-MANUAL.md's
  swell-card bullet corrected — the L2 ~15 m SPECOUT feeds the card only via fallback since
  Q16 Round B (2026-08-25), not unconditionally.
- **API-MANUAL.md §17 gains `swellSource` (`"deep_reference" | "nearshore_table" | null`)
  and `closeoutFraction` (`float | null`, 0.0-1.0) field rows** — both already served
  (Q16 C3 2026-08-25 / PEEL-SEGMENTS 2026-08-26) but previously undocumented.
- **Code (part c, separate commits): `state.record_input("ww3_boundary", ...)` now records
  the NOAA boundary fetch outcome on both the leg and horizon-march paths** — `GET /health`'s
  existing required-input reporting for `ww3_boundary` reflects real fetch outcomes instead
  of the never-recorded default (Q10-7 "record it"). No new field, endpoint, or config key.

MARINE-AND-MAPS-PLAN-2026-08-27 §S3, "S3 lead mechanics" (a)/(c); C19/C20; Q10 items 5/7.

### 2026-08-27 — SURF-MAP-BASEMAP (M4, API side): the surf height map's background stops being orthophotography

- **`GET /api/v1/imagery/config` now always answers with the Clear Skies product basemap
  (`provider: "basemap"`), never 404s, and no longer varies by coordinates.** NAIP/Esri/Esri-Topo
  orthophotography (`[imagery] provider = naip|esri|map|auto`) is retired from every user-facing
  surface (PA9, operator ruling Q5: "get rid of the orthophotography for the surf height map and
  replace it with a regular basemap"). Response gains `light: {tileUrl, attribution}` (OSM raster)
  and `dark: {pmtilesUrl: "/api/v1/basemap/local/tiles", maxDataZoom: 15, attribution}` (the local
  Protomaps tier from the M1 basemap work) plus `zoomMin`/`zoomMax`; legacy top-level
  `tileUrl`/`attribution` carry the light values for old-client compatibility. One startup WARNING
  names an ignored `[imagery] provider` value, if set.
- **`GET /api/v1/imagery/tiles/{z}/{x}/{y}` (NAIP proxy) is unchanged** — unreferenced by any
  user-facing surface after this round. The `[imagery]` config section, its provider modules
  (`naip`/`esri`/`esri_topo`), the admin section, and the wizard's Esri satellite toggle all stay
  (Q10-6 open).
- Docs: `docs/contracts/openapi-v1.yaml` gains a fresh `Imagery` tag with `/imagery/config` and
  `/imagery/tiles/{z}/{x}/{y}` — this closes a pre-existing doc-code gap (neither path was ever
  added to the contract in Phase LM or the IMAGERY-MAP round); API-MANUAL.md §12a rewritten to the
  as-built.
- Not yet in this entry: dashboard consumption (`useImageryConfig.ts`, `HeatMapCard.tsx` dark-theme
  rasterization) — separate round (M4-DASH), tracked in
  `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` Phase M.

### 2026-08-27 — CS-BASEMAP (M1): Clear Skies product basemap, API side (CARTO retirement in progress)

- **CARTO, the free dark-theme tile provider every map surface used, began watermarking tiles
  "API KEY REQUIRED" around 2026-08-25 and is retiring the free product.** Fix: Clear Skies serves
  its own product basemap — three zoom-tiered Protomaps-derived PMTiles files (`world` z0–6 global
  fallback, `local` z7–15 station+earthquake-radius+marine-locations box, `radar` z0–12 the radar
  provider's declared coverage box or a station-box fallback) — for every map surface (marine,
  seismic, radar/satellite, surf height map).
- **New API endpoints (`weewx-clearskies-api`):** `GET /api/v1/basemap/{tier}/tiles` (Range
  requests, 206 partial content), `GET /api/v1/basemap/status` (per-tier availability + extraction
  state, `last_error`), `POST /setup/basemap/update` (proxy-secret, background extraction of all
  three tiers in one daemon thread; 202/409). New `[basemap] enabled` config key (the only one —
  no operator-typed box, per PRIME DIRECTIVE 14). Generalises ADR-078's single-file
  geographic-features overlay into three tiers; ADR-078's own endpoints/service/config stay live
  additively this round — see ADR-078 Amendment 2 (Proposed) for the side-by-side replacement
  mapping and the acceptance gate on removal.
- **Not yet in this entry:** dashboard consumption (marine/seismic/radar map dark-theme rendering
  via the new tiers), the admin "Basemap" section (stack repo), and the M4 surf-height-map /
  Esri-NAIP removal — separate rounds, tracked in
  `docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` Phase M.
- Measured extract sizes (this install, M0): world 42.8 MB, local 513.6 MB (exceeds the plan's
  400 MB ceiling — accepted as-designed by the operator, Q12), radar 195.1 MB.
- Docs: ADR-078 Amendment 2 (Proposed); ARCHITECTURE.md endpoints/config-files tables;
  API-MANUAL.md §12b; `docs/contracts/openapi-v1.yaml`; OPERATIONS-MANUAL.md §1/§4/§7.

### 2026-08-27 — Daily WW3 horizon march finally has the wind it asks for (Q17)

- **The 96-hour horizon march (Q16 Round A) had never run.** It fires once a day right after the 00Z cycle publishes and demands wind out to 00Z + 96 h. The wind store's far window comes from NOAA's GFS model, and at that moment it holds the *previous* 18Z GFS run (NOAA posts the 00Z run's +96 h file ~04:00Z, after the march has already fired), fetched to that run's +96 h — which is only 00Z + 90 h. Six hours short by arithmetic, every day; the march refused `ww3_horizon_wind_short` with no retry, and SWAN's forecast beyond +6 h stayed frozen (`fullRun.l2BoundaryExhausted: true`).
- **Fix (operator ruling, option a):** the gatherer's GFS far-window fetch depth goes from +96 h to +108 h — one constant, `_GFS_FAR_FETCH_END_HOUR`. The march now finds its wind already in the store when it fires; no waiting, no retry machinery, no schedule change. Cost: 4 more GRIB2 files per GFS cycle (17 → 21). The ocean-boundary side was already correct (its depth derives from the window end). Marine `2a05856`; ARCHITECTURE ⚓ WW3 leg, ADR-109 fetch-depth note, PROVIDER-MANUAL §14.18 updated.

### 2026-08-26 — Surf height map: photography replaced by map tiles (IMAGERY-MAP)

- **Orthophoto background retired from the surf height map.** The NAIP aerial photography behind the heat map was flown at an extremely abnormal low tide, so the surf almost always rendered on what looks like dry land (operator finding). New `[imagery] provider = map` option serves Esri's World Topo Map tiles instead — a fixed cartographic coastline with the pier and streets, immune to the tide at photo time. The dashboard's mosaic/placement machinery is unchanged; only the tile source config differs. Live-verified: cached tile pyramid to zoom 23 (map uses 14–19); service is in Esri "mature support" (successor noted in PROVIDER-MANUAL §16.3 in case of future sunset). API `a5e45a9`; live config flipped from `auto` to `map`.

### 2026-08-26 — Surf shape score unstuck: segmented peel angle + graded closeout (PEEL-SEGMENTS)

- **Shape score was pinned at 10% every hour.** Cause found: peel angle was computed as ONE beach-wide number — swell obliqueness minus the *average* break-line angle over all transects — which at Huntington's geometry can never clear the closeout threshold (served peel 0.3°–10.1°), and the scorer's closeout ruin clamp then pinned the shape blend at 0.10 permanently. Averaging erases exactly the local bar corners (peaks) that produce rideable peel.
- **Segmented peel.** Peel is now evaluated per local segment (sliding 3-transect windows, ~20–40 m of beach — the scale of one surfable peak): the served peel angle/direction/classification come from the BEST segment (the peak a surfer picks), and a new additive field `closeoutFraction` reports how much of the stretch closes out. A sign-coupling test with an independent geometric ground truth pins that the *correct* (down-swell) flank of a peak is crowned under angled swell.
- **Graded closeout in the shape score.** The hard 10% pin now applies only when literally every segment closes out; otherwise shape = the blend scaled by (1 − 0.5 × closeout fraction) — so the score finally responds to swell angle and bar structure day to day.
- Marine `b62008f`. Wire: `closeoutFraction` additive on the surf forecast entries (API-MANUAL update pending the open fog-section ruling).

### 2026-08-26 — Swell card no longer drops split-swell energy (DREF-MERGE-FIX)

- **Missing west-swell energy found and fixed.** The spectral partitioner sometimes splits one swell into two or three near-duplicate fragments at a single deep-water reference point; the card's merge then published only the best-aligned fragment's height and silently discarded the rest of that swell's energy. Live case (2026-08-26 21Z): the ~15 s west swell was served at 0.09 m while buoy 46222 measured 0.24 m in that band — the operator caught the ~2–3× gap against the buoy. Fragments at a single point are now recombined energy-conserving (heights add as the square root of summed squares — standard spectral theory) before the cross-point merge, which is unchanged: different points are independent measurements of the same wave and are never summed (that would double-count). Recombined value for the live case: 0.26 m, matching both the buoy (0.24 m) and the model field at the buoy's own location (0.25 m). Marine `6abb831`; [manuals/PROVIDER-MANUAL.md](manuals/PROVIDER-MANUAL.md) §14.19 updated.

### 2026-08-26 — Surf break/reform cycle now governed by the whitewater roller (BREAK-REFORM)

- **Too-many-breaks defect fixed.** The 1-D surf model was drawing 5–7 break points per hour on the beach profile where reality showed 2–3: breaking "ceased" the instant the statistical breaking fraction dipped in a trough — while the wave was still far above its stable height — and re-tripped a few meters later as a fake new break (two markers were 5 m apart). The model computed the whitewater roller's energy at every step but never consulted it.
- **Roller-coupled cycle.** A breaking zone now ends only where the roller (the whitewater the camera actually sees) has decayed below a visibility floor of 40 J/m² — derived from pre-existing model constants, not fitted — and a NEW break (Huntington's double break: the same wave breaking twice) can only begin once that roller is spent. Wave decay keeps being paid while the roller is loaded. Verified both regimes: a rough-day fixture drops from 6 published breaks to 2 with the outer break position unchanged, and a calm-day fixture produces a true cessation → reformation → second break. The 2026-08-08 flat-terrace never-ending-impact-zone bug stays fixed (pinned by test).
- **Publication floors raised** to 0.20 m depth / 0.20 m wave height at break (operator-ordered) — breaks in ankle water are swash, not surf.
- Research and design: [planning/briefs/SURF-ZONE-MODEL-BRIEF.md](planning/briefs/SURF-ZONE-MODEL-BRIEF.md) §13 (Nairn/Roelvink/Southgate 1990 transition zone, XBeach roller balance, Dally 1992 field verification, arXiv:1904.06821 field observations). Marine `57af5d6`.

### 2026-08-26 — Per-cycle roller-closure invariant retired (INVARIANT_11)

- The independent recomputation of the roller energy budget that ran on every point of every transect every cycle (INVARIANT_11) is removed from production — operator ruling: a typo-catching check belongs in change-time tests, not re-run thousands of times a day. In its entire history it fired on exactly two days, both from its own coverage guard, never from the energy budget actually being off. Its protection now lives solely in `tests/services/test_roller_closure_kat.py`, strengthened with an independent frozen reference value and proven by deliberate-sabotage drills to catch a wrong coefficient (+20% → 47% deviation flagged) and a sign error in the physics step. Production roller physics byte-identical. Marine `7b6a711`.

### 2026-08-25 — Surf swell card now reads deep-water reference points (Q16 Round B)

- **Swell card source changed.** The surf forecast's swell card (`multiSwell`, swell height/period ranges) now comes primarily from a small fan of deep-water reference points seaward of the surf break — the same offshore field WW3 already models, read before refraction bends nearby swells together. Previously it read a single point in 15 m of water, which had already merged distinct swell trains that arrive from similar directions into one reading. The card should now list separate swell trains more often, matching what buoys offshore report.
- **Fallback for far-out hours.** Forecast hours the offshore model hasn't yet reached (today, roughly beyond 6 hours out) keep the prior 15 m reading — no functional change for those hours. A new field, `forecast[].swellSource`, records which source produced each hour so this is inspectable.
- **`multiSwell` frequency-range field now populated** for the deep-water-sourced hours (previously always a placeholder `[0.0, 0.0]`).
- No change to the 1-D surf break model, the surf score, or any break-point calculation — this round only changes what feeds the display card. Docs: [ARCHITECTURE.md](ARCHITECTURE.md) ⚓ MARINE HANDOFF MODEL, [manuals/PROVIDER-MANUAL.md](manuals/PROVIDER-MANUAL.md) §14.19, [manuals/DASHBOARD-MANUAL.md](manuals/DASHBOARD-MANUAL.md) Swell Card section.

### 2026-08-25 — WW3 forecast-horizon repair: frozen-forecast defect fixed (Q16 Round A)

- **Frozen-forecast defect fixed.** The deep-water WW3 leg marches 6 hours per forecast cycle; SWAN's nearshore model previously consumed that 6-hour file as its offshore boundary for the entire 73-hour forecast, holding the ocean state frozen from hour 7 onward (SWAN's own log recorded "data on boundary file exhausted" every cycle since 2026-08-19). Every published forecast hour now receives an evolving deep-water boundary instead.
- **Daily continuation march.** Once a day, after the normal 6-hour cycle finishes and publishes, WW3 continues marching in the background out to 96 hours, starting from a copy of that cycle's own 6-hour restart state. This never delays or blocks a normal forecast publish — a failure in the background march is logged and skipped, not surfaced to the served forecast.
- **Merged boundary file.** SWAN now reads a boundary file assembled from the fresh 6-hour march (hours 0–6) plus the latest daily long march (hours 7–72), refreshing the far-out forecast hours once a day instead of never. Missing or short long-march coverage falls back to the 6-hour file alone with a logged warning — never a crashed forecast cycle.
- **NOAA data fetch extended** to cover the longer march (boundary wave data to +99 hours, wind data to +96 hours) — no interpolation added; same data feeds, same cadence, just deeper.
- **New health indicators**: `ww3Horizon` (daily-march status) and `fullRun.l2BoundaryExhausted` (should read false every cycle; true signals the old frozen-forecast defect has returned).
- Docs: [ARCHITECTURE.md](ARCHITECTURE.md) ⚓ WW3 DEEP-WATER LEG, [decisions/ADR-109-ww3-deep-water-leg.md](decisions/ADR-109-ww3-deep-water-leg.md) amendment (2026-08-25), [manuals/PROVIDER-MANUAL.md](manuals/PROVIDER-MANUAL.md) §14.18, [manuals/OPERATIONS-MANUAL.md](manuals/OPERATIONS-MANUAL.md) WW3 deep-water leg section.

### 2026-06-04 — Planet Viewing Quality Index + 7Timer seeing forecast integration

- **Planet Viewing Quality Index** — per-planet viewing quality ratings (Excellent/Good/Fair/Poor/Not Visible) computed from 7Timer atmospheric seeing forecast combined with planet altitude, cloud cover, and special-case rules for Mercury (elongation gate), Uranus/Neptune (moon penalty), and close lunar conjunctions
- **7Timer seeing forecast provider** — new keyless provider module (`providers/seeing/seven_timer.py`) fetching 72-hour astronomical seeing/transparency/cloud forecasts from 7Timer ASTRO product
- **`GET /almanac/seeing-forecast` endpoint** — serves cached 7Timer seeing forecast data with 3-hour cache warming
- **Planet viewing enrichment** — new enrichment processor in the API computes and injects per-planet viewing quality fields into `/almanac/planets` responses
- **Expanded planet data** — `/almanac/planets` now returns all 7 planets (Mercury through Neptune), with transit time, RA/Dec, solar elongation, and apparent magnitude
- **Dashboard viewing quality badges** — color-coded per-planet rating badges with best viewing time and clear window display on the Almanac page

### 2026-06-03 — Forecast detail enrichment + precipitation/snow

- **7-day forecast detail panel enriched.** New fields on DailyForecastPoint: dewpointMax/Min, humidityMax/Min, visibilityMax/Min, snowAmount, thunderRisk/tornadoRisk/hailRisk/windRisk. All 5 providers mapped (Aeris, Open-Meteo, OWM, NWS, Wunderground). Aeris convective outlook (`/convective/outlook`) integrated for storm risk fields. Snow/snowRate blended into `/current` from providers when station hardware lacks snow sensors. Plan: [archive/FORECAST-DETAIL-SNOW-PLAN.md](archive/FORECAST-DETAIL-SNOW-PLAN.md).
- **Sunrise/sunset computed locally via Skyfield.** Forecast endpoint now injects sunrise/sunset using the existing almanac service rather than relying on providers (Aeris daynight filter lacks these fields). Narrative mapped from Aeris `weatherPrimary`.
- **Forecast page UX improvements.** Hourly card fixed: Today/Tomorrow tabs now show 24-hour windows (was calendar-date partition, leaving only 4 hours at 8 PM). First daily column auto-selected so detail panel is visible on load. Card title icons removed (matches Now page convention). CloudSun hero icon added to PageHeaderCard.
- **i18n + unit compliance.** All detail panel labels use `t()` translation keys (11 new keys in forecast.json). Unit suffixes driven by API `units` block instead of hardcoded strings.

### 2026-05-06 — Clear Skies Phase 2 task 1: FastAPI scaffold complete

- **Phase 2 task 1 (FastAPI scaffold) complete.** Eight commits on `main` at github.com/clearskies-wx/weewx-clearskies-api: initial scaffold (39 files, 3095 insertions; project layout per [ADR-036](archive/decisions/ADR-036-workspace-layout.md), middleware stack per [security-baseline §3.1](archive/contracts/security-baseline.md), proxy-auth shared secret per [ADR-008](archive/decisions/ADR-008-auth-model.md), RFC 9457 problem+json error handler per [ADR-018](archive/decisions/ADR-018-api-versioning-policy.md), separate-port health on loopback per [ADR-030](archive/decisions/ADR-030-health-check-readiness-probes.md), JSON logging + redaction filter per [ADR-029](archive/decisions/ADR-029-logging-format-destinations.md), ConfigObj/INI loader for `api.conf` per [ADR-027](archive/decisions/ADR-027-config-and-setup-wizard.md), IPv4/IPv6 dual-stack listener per [coding.md §1](../rules/coding.md), pytest scaffold with FastAPI `TestClient`), three pytest-surfaced fix commits (regex group reference in redaction filter; missing path-existence check in `load_settings`; Authorization regex stopping at first whitespace), `uv.lock` follow-up, two dep-audit workflow fixes (scope `pip-audit` to project deps via `uv export --format requirements-txt --no-emit-project`), and a fastapi 0.115.12 → 0.136.1 / starlette 0.46.2 → 1.0.0 bump clearing two real CVEs (CVE-2025-54121, CVE-2025-62727). 73/73 pytest pass on `weather-dev`; both CI workflows (`gitleaks`, `dep-audit`) green. Implements security-baseline §3.1 (network listener), §3.2 (auth), §3.4 (secrets handling), §3.6 (logging + redaction), §3.7 (health). §3.3 (DB) deferred to task 2; §3.5 (full input validation) deferred to task 3 when real Pydantic models land; §3.8 (process hardening) deferred to task 7. Multi-agent execution: api-dev (Sonnet) + auditor (Opus) ×2 + lead (Opus) synthesis.
- **Process rule strengthened.** [rules/clearskies-process.md](../rules/clearskies-process.md) "Plain English when explaining decisions to the user" now requires every technical term, library name, RFC number, file convention, and project-internal acronym be defined the first time it appears in a conversation; later uses can lean on the earlier definition. Counter resets per new conversation. [CLAUDE.md](../CLAUDE.md) "Collaboration style" gained a matching cross-cutting bullet. Trigger: synthesis after the first round of audit findings used a wall of unexplained terms ("RFC 9457 problem+json", "FastAPI TestClient", "loopback port 8081", "trusted-bypass path", "hmac.compare_digest"). User verbatim: *"you have been bombarding me with so much jargon, I cannot see straight."*
- **Branching policy decided.** No feature branches pre-1.0; commit straight to `main`/`master` on all repos. Pre-1.0 with no users, branches add overhead without value. Policy revisits when v0.1 ships and there are real consumers to protect from broken intermediate states.
- **dep-audit workflow refinement** (api repo only). Phase 1's `pip-audit --strict` with no manifest argument audited the entire CI runner Python environment, not project deps — the runner's own pip carried CVEs unrelated to this project so the workflow failed on every push once a manifest existed. Fixed via `uv export --format requirements-txt --no-emit-project` then `pip-audit -r` against that file. Other four repos (realtime, dashboard, stack, design-tokens) still have the original workflow shape; it skips cleanly while their content is placeholder, will need the same one-line fix when each lands its first real code.

### 2026-05-05 — Clear Skies Phase 1: API contract + earthquake provider ADR

- **Phase 1 task: API contract committed** at [contracts/openapi-v1.yaml](contracts/openapi-v1.yaml). OpenAPI 3.1, 23 paths, 53 schemas, validates clean against `openapi-spec-validator`. Endpoint inventory derived from [ADR-024](archive/decisions/ADR-024-page-taxonomy.md) page taxonomy + [ADR-010](archive/decisions/ADR-010-canonical-data-model.md) canonical entities; URL-path versioning + RFC 9457 errors per [ADR-018](archive/decisions/ADR-018-api-versioning-policy.md); auth security scheme is the optional shared secret from [ADR-008](archive/decisions/ADR-008-auth-model.md); pagination on `/archive` and `/aqi/history` supports both cursor and page-number forms; `/reports/{year}/{month}` returns raw weewx-generated text (dashboard parses fixed-width client-side — operator decision); realtime SSE deliberately not in this spec (separate `weewx-clearskies-realtime` contract).
- **[ADR-040](archive/decisions/ADR-040-earthquake-providers.md) Accepted.** Earthquake providers as clearskies-api plugin modules per [ADR-038](archive/decisions/ADR-038-data-provider-module-organization.md). Day-1 set: usgs / geonet / emsc / renass — all FDSN-Event-compliant, free, no key. Single source per deploy; setup wizard suggests by region; USGS provides global fallback so no operator is uncovered. Mirrors [ADR-016](archive/decisions/ADR-016-severe-weather-alerts.md) shape. Research: [reference/EARTHQUAKE-PROVIDER-RESEARCH.md](reference/EARTHQUAKE-PROVIDER-RESEARCH.md).
- **[ADR-010](archive/decisions/ADR-010-canonical-data-model.md) re-Accepted** with `EarthquakeRecord` entity added (per item-7 in-place correction). Required fields: `id`, `time`, `latitude`, `longitude`, `magnitude`, `source`. Optional: `depth`, `magnitudeType`, `place`, `url`, `tsunami`, `felt`, `mmi`, `alert` (USGS PAGER), `status`, `extras`. Brings entity count to 9 cores + 2 containers. Drove a `normalize_earthquakes` addition to the provider normalizer contract.

### 2026-05-04 — Clear Skies Phase 1: tech-stack spike + plan-vs-ADR audit

- **Phase 1 task 1 (tech-stack spike) complete.** Vite 8 + React 19 + TypeScript 6 + Tailwind v4 + shadcn v4 + Recharts 3.8 + Lucide validated end-to-end inside `weather-dev`. Production bundle 164.52 KB gzipped — under [ADR-033](archive/decisions/ADR-033-performance-budget.md)'s 200 KB budget by ~35 KB. Two scaffold-time footguns documented: `react-is` override for Recharts on React 19, and `ignoreDeprecations: "6.0"` for the TS6 `baseUrl` deprecation. Findings: [reference/SPIKE-FINDINGS.md](reference/SPIKE-FINDINGS.md).
- **Plan-vs-ADR audit completed and applied.** Drift fixed in plan body: architecture diagram, components table, tech stack table, security baseline, versioning, coexistence, Phase 1 task descriptions all updated to match the 39 Accepted ADRs verbatim or to defer to them as authoritative pointers. Trigger: spike was built against the plan body's stale tech-stack table (Tremor + ECharts) when ADR-002 had already locked shadcn + Recharts. New process sub-rule landed in [rules/clearskies-process.md](../rules/clearskies-process.md) "Read the ADR before the plan." Audit findings: [reference/PLAN-VS-ADR-AUDIT-2026-05-04.md](reference/PLAN-VS-ADR-AUDIT-2026-05-04.md).
- **Phase 1 task: weather-dev LXD container** stood up on ratbert at `192.168.2.113` (DHCP/SLAAC on br-vlan2). Ubuntu 24.04, Docker-in-LXC nesting, 6 GB memory cap. Provisioned: Docker Engine 29.4 + Compose v5, Node 22 LTS, Python 3.12, uv. Brought forward from Phase 4 because Windows host is a misfit for Linux-first toolchains. Roster entry in `Windows Server/reference/ratbert-lxd.md`.
- **Phase 1 task: docker-compose dev/test stack** scaffolded at [`repos/weewx-clearskies-stack/dev/`](../repos/weewx-clearskies-stack/dev/). MariaDB 10.11 + backend-agnostic Python seed loader. Snapshot capture script (host-side, SQLAlchemy reflection) + seed loader (containerized) — same captured dataset loads into MariaDB or SQLite per [ADR-012](archive/decisions/ADR-012-database-access-pattern.md). Validated end-to-end inside `weather-dev`; both backend profiles load + verify against synthetic fixture. Three real defects surfaced and fixed during validation (silent CSV-row truncation in loader, invalid `pip install --require-hashes=false` Dockerfile syntax, SQLite volume permission collision with non-root container `USER`).

### 2026-05-02 — Clear Skies Phase 1 ADR backlog closed

- **All 39 ADRs Accepted.** Phase 1's architecture-decision surface fully resolved: 5-component breakdown, tech stack, license (GPL v3), repo naming (`weewx-clearskies-*`), realtime architecture (direct + MQTT), compliance model, forecast providers, auth (no end-user, optional shared-secret header), inbound-traffic architecture (one-door reverse proxy), config + setup wizard, canonical data model, multi-station scope (single-station only at v0.1), DB access pattern (SQLAlchemy 2.x sync, read-only enforcement), AQI handling, almanac source (Skyfield), radar/map tiles, severe-weather alerts, provider response caching, API versioning policy (RFC 9457 errors), units handling, time zone handling, i18n (13 locales, no RTL), theming/branding, light/dark mode mechanism, page taxonomy (9 built-in pages), browser support matrix, accessibility commitments (WCAG 2.1 AA, release-blocking), update mechanism, logging format, health-check probes, observability/metrics, versioning across repos, performance budget, deployment topology default, user-driven column mapping, workspace layout, data-provider module organization, distribution/installation. ADR INDEX: [decisions/INDEX.md](decisions/INDEX.md).
- Subsequent cleanup pass (2026-05-04) trimmed nine bloated ADRs in place per the conciseness rule; the remaining 28 audited paragraph-by-paragraph and confirmed tight.

### 2026-04-29 — Project pivot to Clear Skies

- **Pivoted** from "evaluate alternative weewx skins" to "build new modern stack from scratch." Driver: every weewx-ecosystem skin (Belchertown, Seasons, Beautiful Dashboard, Smartphone, Weather Eye) read as visually amateurish; lateral move would not solve the redesign goal. Predecessor plan archived: [archive/WEATHER-EVALUATION-PLAN.md](archive/WEATHER-EVALUATION-PLAN.md). New plan: [archive/CLEAR-SKIES-PLAN.md](archive/CLEAR-SKIES-PLAN.md).
- Five-component breakdown adopted; project name "Clear Skies" verified clear in weewx ecosystem; license set to GPL v3 to mirror weewx.

### 2026-04-29 — AQI centralization (complete)

- **Removed Aeris airquality dependency** from `belchertown.py`: dropped `aqi_url` construction, HTTP fetch, and `"aqi"` key from all 4 `forecast.json` write blocks.
- **AQI now reads from archive DB** via `getSql()` query — single source of truth, no duplicate API calls.
- **Added `aqi_pollutant` template variable** — exposes `main_pollutant` from archive; displayed in AQI block instead of location (location is always Huntington Beach).
- **Added `[airquality]` chart group** to `graphs.conf` — 24h and 7-day AQI history charts.
- Deployed and verified: site shows AQI=21.0 (good), PM2.5 from AirVisual. Aeris airquality endpoint no longer called (~24 fewer calls/day).
- See archived plan: [docs/archive/AQI-CENTRALIZATION-PLAN.md](archive/AQI-CENTRALIZATION-PLAN.md)

### 2026-04-29 — Phase 1 assessment

- Merged origin/master (Belchertown skin code) into local working tree via `--allow-unrelated-histories`. Renamed local README.md → README-eval.md to avoid collision.
- Created local tracking branches `dropdowns` and `inguy24-changes` from origin.
- Pulled WeeWX 5.3.1 docs (98 markdown files from GitHub `weewx/weewx` tag `v5.3.1`) into `docs/reference/weewx-5.3/`. Server runs 5.3.1, not 4.10.
- Pulled WeeWX 4.10 user guide / customizing / upgrading HTML into `docs/reference/` for legacy reference.
- Wrote `docs/reference/SERVER-INVENTORY.md` — authoritative map of containers, MQTT chain, static-site sync via LXD shared disk, etc.
- Wrote `docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md` — file-by-file diff of live skin vs `master`/`dropdowns`/`inguy24-changes`. Identified 7 files on the server that exist in NO branch.
- Corrected `reference/weather-skin.md` — old paths (`/home/weewx/skins/...`), unknown weewx version, and incorrect TLS-termination claim.
- **Identified MQTT root cause:** `mgtt://` typo in `weewx.conf` `[StdRESTful][[MQTT]]` server_url scheme. Cause of regular users not seeing live data.
- No code changes deployed. No commits pushed to GitHub.

### Earlier

- Project initialized with evaluation framework
- Created documentation structure (rules, reference, planning)
- Set up credentials and access configuration

## [1.0.0-evaluation] — 2026-04-29

- Initial project setup with Belchertown fork
- Documentation & evaluation criteria defined
