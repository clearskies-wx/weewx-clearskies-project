# Z-PREMISE-AUDIT — Root-cause #1/#3 + entire Round Z, verified against reality

Read-only. Repos pinned: `weewx-clearskies-marine` @ `d74c578` (clean, matches
`origin/main`, no divergence — same commit X0/YQ-1 used). `weewx-clearskies-dashboard`
@ `ad2ecf9` (clean, matches `origin/main`, no divergence). Live checks against
`librewxr` (`sudo journalctl`/`sudo ls`/`sudo -u ubuntu python3 -c json.load(...)`,
all read-only). X0/Y0/YQ-1 findings cross-cited, not re-derived.

---

## TABLE 1 — Root cause #1 (all-or-nothing breaking)

| Claim (quoted from plan) | Verdict | Evidence |
|---|---|---|
| "The Round W breaking model triggers only when the representative height Hs exceeds γ·d." | VERIFIED (cross-cite X0) | X0 Table 1: `_ddd_breaking_march` onset `Hs_out[i] >= gamma*d_i` at `surf_1d_analytical.py:573,587` — hard trigger, no statistical fraction. Not re-derived here; X0 already pinned it at the same HEAD I audit. |
| "The pre-Round-W model carried a statistical breaking fraction; the Round W replacement silently dropped it." | VERIFIED, with a wording nuance | Commit `e048494` ("Round W1 — unified DDD breaking march replaces B-J+roller+clamp", 2026-08-05 00:43:50) removes the `_battjes_janssen`/`_roller_model` call sites from `run_1d_analytical`, confirmed by X0 as zero call sites remaining. The commit message is NOT itself hidden/silent — it explicitly documents the removal. "Silently dropped" is accurate in the sense that matters (production physics behavior lost the statistical fraction with no replacement mechanism and no invariant/flag marking the regression), not in the sense of a hidden commit. Minor imprecision in the plan's word choice, not a factual error. |
| "Measured: Hs at the T48/T55 bar crest ≈ 0.52–0.55 m vs γ·d ≈ 1.55–1.67 m." | PARTLY VERIFIED | The **Hs figures** (0.52/0.55 m) match YQ-1's independently-measured live numbers almost exactly — but YQ-1 measured these as the **L4 handoff Hs** (depth 3.27 m, offshore of the bar), not Hs specifically at the bar-crest depth. The plan's own X-D2 text (line 137) uses the same pair of numbers labeled "over the T55 bar crest (d≈2.2 m incl. tide)" — i.e., the plan appears to use "handoff Hs" and "bar-crest Hs" interchangeably. Whether shoaling between the L4 handoff and the bar crest changes Hs measurably was not established by any artifact I could find (short reach, mild slope — plausibly small, not confirmed). **γ·d claim:** γ=0.73 confirmed unchanged at HEAD (X0). Raw (no-tide) bathymetric bar-crest depth at T55, distance≈79.7 m, from `spot_profiles/huntington-city-beach-pier.json`: 1.545–1.676 m (X0's own finding) — γ·d on that raw depth ≈ 1.13–1.22 m, NOT 1.55–1.67 m. The plan's stated range only reconciles if ≈0.5–0.6 m of tide is added to reach d≈2.2 m (0.73×2.2=1.61 m), which is exactly X-D2's own worked assumption. I could not independently pull live tide state to confirm the addition — the number is internally consistent with the plan's own worked example, not independently re-derived from a tide feed. |
| Implicit premise: this defect is still live today | VERIFIED, live, current | Multi-day forecast-cache sample (librewxr, `/run/weewx-clearskies/swan/forecast_cache.json`, 2026-08-06 through 2026-08-08, 34 hourly entries): representative/published transect never equals 48 or 55 in any sampled hour despite both routinely having real, computed break points (see Table 2 row on "index 27" for the same data — it is the same live evidence, reused for both claims since it bears on both root causes). |

---

## TABLE 2 — Root cause #3 (selection/anchoring defects)

| Claim (quoted) | Verdict | Evidence |
|---|---|---|
| "(a) the published 'best' transect is a face-height statistic with no bathymetric awareness" | VERIFIED | `_compute_main_break_zone()` at `weewx_clearskies_marine/services/surf_1d_pipeline.py:1281-1469` (plan cites :1281-1467 — off by 2 lines, immaterial; function body confirmed unchanged in character). Docstring step 8 (BD-9 representative): "the in-zone entry ... whose face is closest to `main_zone_face_height_m`" — selection keyed purely on `best_face_height_m`, zero bathymetric input anywhere in the function (no depth/distance/breaker-type field read). `_select_best_transect()` at `endpoints/beach_profile.py:357-377` (exact line match) prefers this `representative_transect_index` when present, else falls back to legacy `max(candidates, key=best_face_height_m)` — also pure face-height, no bathymetry. |
| "(b) was index 27 while the bar transects 48/55 sat unpublished" | VERIFIED-BY-REPRODUCTION, not the literal historical instance | Not found as a persisted 2026-08-05 artifact (no scratch file, journal line, or cache entry from that date names index 27). However, this is the exact mechanism, live and reproducible: forecast-cache sample `2026-08-08T00:00:00Z` has `representative_transect_index=27` (T27 `best_face_height_m=0.940`) while T48 (`0.900`) and T55 (`0.881`) both have real, computed break points but score lower and are not selected — an exact live re-creation of the cited pattern, on the SAME code path, just a different hour than the one originally cited. Across the full 34-hour multi-day sample, the representative index is NEVER 48 or 55, and wanders across {1, 21, 23, 24, 25, 26, 27, 28, 29, 37, 39} — directly confirms "wanders... hour-to-hour" too. |
| "(c) the shared per-spot shoreline anchor is located on the COARSE grid" | VERIFIED | `grid_sizing_chain.py:1485-1488`: `find_shoreline_from_grid(coarse_grid, loc.lat, loc.lon, bearing)` — exact call, exact grid argument (`coarse_grid`), matches plan anchor almost exactly (line 1485-1487 for the call itself, 1488 is the following statement — 1-line drift, immaterial). |
| "...same function, fine input — the per-transect path at grid_sizing_chain.py:2168-2171 already does exactly this" | VERIFIED | `find_shoreline_from_grid()` defined at `weewx_clearskies_marine/enrichment/bathymetry.py:1338-1380` (exact match; plan just says "bathymetry.py", actual path is `enrichment/bathymetry.py` — file basename correct, directory unstated but unambiguous, not a real drift). Per-transect call at `grid_sizing_chain.py:2168-2171`: exact match, `find_shoreline_from_grid(_anchor_grid, _t.origin_lat, _t.origin_lon, _t.bearing_deg)` where `_anchor_grid = fine_grid if fine_grid is not None else medium_grid` (line 2131) — confirms fine-grid-first (with medium as fallback, not "coarse" — small precision gap in the plan's phrasing: the per-transect path's fallback is `medium_grid`, not `coarse_grid`; the plan doesn't claim otherwise but doesn't mention this fallback tier either). |
| "top-level profile depth at distance 0 = 2.822 m" | VERIFIED, exact, live | Live extraction, `librewxr`, `/etc/weewx-clearskies/spot_profiles/huntington-city-beach-pier.json`, top-level `profile` array, first entry: `{"distance_m": 0.0, "depth_m": 2.822}` — bit-for-bit match to the plan's cited number. |

---

## TABLE 3 — Round Z-D1 (bar-aware, surf-first transect selection)

| Claim | Verdict | Evidence |
|---|---|---|
| `_compute_main_break_zone()` exists with a "BD-9 block" as described | VERIFIED | Docstring cites "BD-7/BD-9 (SURF-ZONE-BREAK-DETECTION-SPEC-2026-08-01 sec 3/6/7)" explicitly; step 8 of the docstring is literally titled "BD-9 representative" (`surf_1d_pipeline.py:1281-1469`, representative-selection logic at ~1450-1460). Matches plan's framing exactly. |
| `transectIndex` is already on the wire | VERIFIED | Marine side: `endpoints/beach_profile.py:773` `"transectIndex": tr.transect_index`. Dashboard side: `src/api/types.ts:2034`, `src/api/openapi-v1.yaml:3808` (`{ type: integer, description: "Zero-based transect index." }`), `required: [transectIndex, ...]` at `openapi-v1.yaml:3829`. |
| Dashboard card lacks the transect label today | VERIFIED, with an important omitted history | `BeachProfileCardBody.tsx:108-114`: a "representative transect" header USED to render here and was **deliberately removed** per an explicit operator ruling dated 2026-08-02: *"the user of the site will not [know what that means]"* — same removal round as a similar "BD-9 triangle" marker pulled from `HeatMapCard.tsx`. **The plan's Z-D1 text does not reference this prior ruling at all.** This doesn't make Z-D1 wrong — a friendly label ("Line N of 162, x ft from pier") is a different, more legible proposal than the raw "representative transect" marker the operator rejected — but the plan is silent on a directly relevant precedent, and the Z-QC auditor/gate should know a labeled-transect display was tried and pulled once already for being meaningless to end users, so the new copy needs to clear that bar explicitly, not just structurally exist. |
| 13 locales | VERIFIED, count exact; reuse assumption not fully clean | `public/locales/` has exactly 13 directories (de, en, es, fil, fr, it, ja, nl, pt-BR, pt-PT, ru, zh-CN, zh-TW), each `marine.json` already carries a `"transectIndex": "Transect"` key (`en/marine.json:315`) currently used only by `HeatMapCard.tsx`'s screen-reader-only accessibility table header (`HeatMapCard.tsx:1044`), not any visible card. The existing key's short "Transect" string is not the proposed "Line N of 162, x ft from pier" copy — a genuinely new (longer) string will still need real translation into all 13 locales; the existing key doesn't pre-empt that work, it just confirms the i18n plumbing (13-locale infra) is real and already load-bearing. |

---

## TABLE 4 — Round Z-D2 (fine-grid anchor + `reestablish_spot()` teardown scope)

| Claim | Verdict | Evidence |
|---|---|---|
| Fix code anchors (repeats Table 2 row (c)) | VERIFIED | See Table 2 above — not re-cited twice. |
| "delete EVERY persisted artifact of the spot (spot_profiles JSON, grid-sizing caches, bathymetry-derived per-spot caches, transect/anchor data, all hotstart files, the spot's forecast-cache entries)" — is this list complete? | **INCOMPLETE — finding** | Live `ls` on `librewxr` under `/etc/weewx-clearskies/` and `/run/weewx-clearskies/swan/` turned up several persisted-artifact classes the plan's list does not name: **(1)** Multiple stale, **hash-keyed, co-existing** `swan_bathymetry_L3_<hash>.json` / `L4_<hash>.json` / `PROFILE_<hash>.json` files with different hashes and dates spanning 2026-08-01 through 2026-08-05 sitting side-by-side in `/etc/weewx-clearskies/` — the plan's generic "bathymetry-derived per-spot caches" phrase covers the CATEGORY but not the fact that OLD hash variants accumulate rather than being replaced in place; a teardown that only clears "the current cache" would leave old-hash siblings behind — the exact "something OLD is carried over" failure mode ruling 6 exists to prevent. **(2)** A full leftover snapshot directory, `/etc/weewx-clearskies/swan-precleanup-20260727-030650/` (spot_profiles/, swan_bathymetry_L1/L2/L3\_\*.json, swan_grid_sizing.json), dated 2026-07-27 — evidence an earlier partial-invalidation event already left debris uncleaned for 10 days; not addressed by the plan's list at all. **(3)** `level3_0_bbox_hash.txt` / `level4_0_geom_hash.txt` under `/run/weewx-clearskies/swan/` — grid-identity change-detection markers, a distinct artifact TYPE from the hotstart `.dat` files the plan does name; not separately called out. **(4)** `incoming.json` and `wind_timeline.json` under the same run directory — ownership (global vs. per-spot) could not be determined from filenames alone; not mentioned either way. **(5)** `forecast_cache.json` (108 MB) is a single file shared across all spots keyed by spot_id internally (confirmed: top-level key `spots.huntington-city-beach-pier...`) — the plan's phrase "the spot's forecast-cache entries" already implies in-place key deletion rather than file deletion, which is structurally correct, just noting it as confirmed rather than assumed. |
| "rebuilt anchor within 15 m of the median of the 162 per-transect anchors; top-level 'profile' depth at distance 0 ≤ 0.5 m (was 2.822 m)" | PARTLY VERIFIED | The "was 2.822 m" baseline is exactly reproduced live (Table 2). The "median of 162 per-transect anchors" comparison could not be computed: `spot_profiles/huntington-city-beach-pier.json` carries `profiles_by_transect` (distance/depth arrays) and `transect_bearings`, but no per-transect anchor lat/lon field to compute a median against — would require re-running `find_shoreline_from_grid()` per transect, out of read-only scope. Not a plan defect — just unverifiable from static artifacts. |

---

## TABLE 5 — Round Z-D3 (heat-map double-break truthfulness)

| Claim | Verdict | Evidence |
|---|---|---|
| "`HeatMapCard` renders both break bands (it consumes the published zones)" | PARTLY VERIFIED | Consumption confirmed: `HeatMapCard.tsx` accepts `mainBreakZoneStartIndex`/`mainBreakZoneEndIndex` props (lines 78-80, sourced from the wire's `mainBreakZoneStartIndex`/`EndIndex`, `src/api/types.ts:1372-1374`, `openapi-v1.yaml:3385-3386`, themselves the camelCase of `surf_1d_pipeline.py`'s `main_zone_start_index`/`end_index` — the exact published zone the plan means) and uses them to compute a zone-overlay band (`hasZoneOverlay`, line 665; consumers at 821, 1057, 1121). This mechanism is real. Whether the rendered result actually shows **two distinct break bands** (double-break truthfulness specifically, vs. one wide zone band) is a rendering/visual question this static read cannot answer — correctly scoped by the plan itself as "a verification task, promoted to a fix task only on failure," not something this audit can pre-empt. |

---

## TABLE 6 — Round Z-D4 (heat-map orthophoto registration)

| Claim | Verdict | Evidence |
|---|---|---|
| "the aerial imagery under the surf-height heat map is drawn north-up, while the heat-map data field is in the shore-local transect frame ... rotated to the operator-drawn segment's bearing — so the pier and shoreline in the photo do not lie under the data that describes them" | VERIFIED, verbatim, in the code's own comments | `HeatMapCard.tsx:176-197` (a dedicated comment block titled "LM-2 ... ALIGNMENT ASSUMPTION (operator eyeball step — expect a tweak round)") states almost exactly the plan's defect: *"The fetched tile mosaic ... is stretched (north-up, unrotated) to fill the EXISTING chart rectangle ... This is NOT a per-cell geographic warp and does NOT rotate the mosaic to the beach's own facing direction ... Per-row bearing is used only to justify the radial/circular bound, not for mosaic rotation this round — a possible future refinement."* This is the developers' own contemporaneous acknowledgment of the exact defect Z-D4 now targets. |
| "where the imagery comes from (asset vs tile fetch)" | VERIFIED — tile fetch, not a static asset | Standard Web-Mercator slippy-map XYZ tiles (`lonToTileX`/`latToTileY`/`tileXToLon`/`tileYToLat`, `HeatMapCard.tsx:234-248`), fetched via `GET /api/v1/imagery/config?lat=&lon=` (`useImageryConfig.ts:26-36`) which returns a `tileUrl` template substituted per-tile (`HeatMapCard.tsx:1159`, `substituteTileUrl(imageryConfig!.tileUrl, tile.z, tile.x, tile.y)`). Comment at line 233 references "the API's own NAIP proxy" as the backing provider (not independently confirmed server-side — dashboard-repo-only scope). |
| "its georeference metadata" | VERIFIED available (standard tile math), not itself a stored metadata field | No separate georeference metadata blob is fetched — geo-referencing is DERIVED per tile from the tile's own (z, x, y) via the standard Web Mercator formulas already implemented (`tileXToLon`/`tileYToLat`, lines 243-248; mosaic bounds computed at `mosaicWest/East/North/South`, lines ~336-339). This is sufficient input for Z-D4's proposed 2-control-point affine transform (the code already computes exact lon/lat ↔ screen-pixel mappings via `lonToScreenX`/`latToScreenY`, lines 344-345) — the registration fix is a plausible, well-anchored design given what's already in the file, not a speculative one. |
| "`HeatMapCard`'s current layer stack" | VERIFIED, pinned | DOM/z-order, bottom to top: (1) `<clipPath>` matching the chart rect (`HeatMapCard.tsx:1142-1146`), (2) imagery `<g clipPath=...>` containing one `<image>` per tile when `hasImageryBackground` (lines 1154-1167), else a plain translucent background `<rect>` (line ~1168+), (3) heat-map colour cells drawn afterward in DOM order at reduced opacity when imagery is present (`HEATMAP_CELL_OPACITY_ON_ORTHO = 0.55` vs `HEATMAP_CELL_OPACITY_DEFAULT = 0.85`, lines 209-211) — confirms imagery renders strictly beneath the data layer, consistent with the plan's "imagery conforms to the data, never the reverse" ruling being implementable without touching data-layer rendering. |

---

## TABLE 7 — Z tasks list and gate rows

| Claim | Verdict | Evidence |
|---|---|---|
| Z0/Z1..Z7 task list references (file scope only, no new design claims beyond D1-D4 already covered) | VERIFIED (no drift beyond what's captured above) | Task table (plan lines 270-276) cites no additional file:line anchors beyond Z-D1..D4's own; nothing new to verify independently. |
| Z-QC adversarial brief: "enumerate every file the marine service can persist for a spot" | Directly informs Table 4's finding | The Z-QC brief itself anticipates exactly the artifact-enumeration gap Table 4 found — the brief's own standard ("re-establish, then find ANY artifact with a pre-teardown timestamp") is achievable ONLY if the enumeration is complete; Table 4 shows today's plan text is not yet a complete enumeration. This is squarely fixable before Z2 dispatch (add the 5 items in Table 4 to the teardown list), not a fundamental problem with the design. |
| Z7 gate row: "displayed transect is bar-transect on a bar-break day" | Not independently testable pre-implementation | Depends on Z1 shipping; nothing to verify yet. |

---

## Overall Z-section reliability verdict

**The plan's factual claims for root-cause #1, root-cause #3, and the entire Round Z
section are substantially accurate at HEAD.** Of the claims checked:

- **9 VERIFIED** outright (root cause #1's hard-trigger mechanism [cross-cited], root
  cause #3(a)/(c) selection+anchor code anchors, the 2.822 m live number, Z-D1's
  `_compute_main_break_zone`/BD-9 and `transectIndex`-on-wire and 13-locale-count
  claims, Z-D3's zone-consumption mechanism, Z-D4's entire defect description
  [confirmed almost word-for-word in the target code's own comments] plus its tile-fetch/
  georeference/layer-stack sub-claims).
- **3 PARTLY VERIFIED** (root cause #1's specific Hs/γ·d magnitude range — real numbers,
  but conflates handoff Hs with bar-crest Hs and needs an unconfirmed tide addition to
  reconcile; Z-D2's anchor-accept numbers — the "was 2.822 m" half is exact, the
  "median of 162 anchors" half is not computable from static artifacts; Z-D3's
  "renders both bands" — the plumbing is real, the visual double-band outcome is not
  statically checkable and is correctly deferred to Z3's own verification step).
- **1 VERIFIED-BY-REPRODUCTION** (root cause #3(b)'s "index 27" claim — not found as
  the literal 2026-08-05 historical record, but reproduced live and exactly, including
  the same index number, on later dates, on the same code path).
- **1 genuine INCOMPLETE finding, not a false claim**: Z-D2's persisted-artifact
  teardown list is missing five real artifact classes found live on `librewxr`
  (stale hash-keyed bathymetry cache siblings, a 10-day-old leftover precleanup
  snapshot directory, two grid-identity hash marker files, and two files of
  undetermined per-spot ownership). This is exactly the class of gap the plan's own
  Z-QC adversarial brief is designed to catch — it should be closed by expanding the
  teardown enumeration before Z2 is dispatched, not treated as evidence the plan is
  unreliable.
- **1 notable omission, not a factual error**: Z-D1's transect-label proposal doesn't
  acknowledge that a similar label was already tried and explicitly pulled by
  operator ruling on 2026-08-02 for being meaningless to end users
  (`BeachProfileCardBody.tsx:108-114`). Worth surfacing to whoever runs the Z gate so
  the new copy is judged against that prior standard, not assumed to clear it by
  existing.

**No claim in this audit's scope was found to be stale, contradicted by the code, or
architecturally impossible** — a materially different outcome than the Round Y
root-cause premise that triggered this audit (a function proven deleted ten days
before drafting). Root causes #1 and #3, and the Round Z design, read as accurate,
current, and buildable. The two findings above (incomplete artifact enumeration,
missing prior-ruling context) are the kind of gaps a pre-dispatch fact-pin (Z0) is
supposed to close, not evidence of the same class of error that hit Round Y.

## Claims safe to build on (no further re-verification needed before Z0/Z1/Z2 dispatch)

- Root cause #1's hard-trigger mechanism and γ=0.73 constant (X0-confirmed, re-confirmed here).
- Root cause #3(a): face-height-only selection, no bathymetric awareness — exact code match.
- Root cause #3(c): coarse-grid shared anchor vs. fine-grid per-transect anchor — exact code match, all four cited file:line anchors hold.
- Z-D1: `_compute_main_break_zone`/BD-9 representative logic, `transectIndex` wire field, 13-locale i18n infrastructure.
- Z-D3: the wire fields and component props needed for zone-band rendering exist and are wired correctly.
- Z-D4: the entire defect description, the tile-fetch imagery source, the availability of per-tile georeference math sufficient for the proposed affine-transform fix, and the current layer stack — all confirmed, several confirmed word-for-word against the target file's own comments.

## Claims needing a decision or small scope addition before build, not further fact-finding

- Z-D2's teardown enumeration should be expanded with the five artifact classes in Table 4 before Z2 is dispatched.
- Z-D1's build brief should note the 2026-08-02 prior-ruling context so the Z-QC auditor judges the new label against it explicitly.
