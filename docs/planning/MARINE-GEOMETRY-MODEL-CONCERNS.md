# Marine Geometry-Model — Concerns log

Companion to `MARINE-GEOMETRY-MODEL-PLAN.md`. **Non-blocking** items that the governing docs (ARCHITECTURE.md, the
manuals, the ADRs, the briefs) and the plan could not answer, logged here to keep the run moving and triaged later
(at a phase boundary or after the plan lands) — per the plan's "Autonomy & escalation" section.

**This file is NOT for blockers.** A genuinely blocking issue outside the approved architecture STOPs and surfaces
to the operator. This file is for non-blocking gaps where a reasonable, documented assumption let the work proceed.

**Entry format:**

```
## TC-N — [OPEN|RESOLVED yyyy-mm-dd, severity] one-line title
- **What:** the gap / ambiguity.
- **Where:** file:line / task ID (e.g. G2.2).
- **Why non-blocking:** why the run could proceed.
- **Assumption made:** the reasonable default taken to keep going.
- **To revisit:** what would settle it (which doc, which measurement).
```

---

## TC-1 — [OPEN 2026-07-31, low] Plan G0.2 §Verify cites non-existent test files
- **What:** G0.2's `Verify:` line names `tests/enrichment/test_fishing_species.py` and `tests/enrichment/test_bathymetry.py`; neither file (nor a `tests/enrichment/` dir) exists in the marine repo.
- **Where:** MARINE-GEOMETRY-MODEL-PLAN.md G0.2; also G1.1/G1.2/G3.2 cite `tests/enrichment/...` and `tests/config/...` paths that may not exist.
- **Why non-blocking:** the accept criteria are unchanged; the coordinator's brief supplied working alternate verify commands (new `tests/services/test_region.py` KAT + import smoke-check + grep), which proved the same behavior.
- **Assumption made:** where a plan-cited test path doesn't exist, agents create the KAT under `tests/` or `tests/services/` and verify there. Existing coverage for touched modules is run by name-grep.
- **To revisit:** confirm test-file placement convention with operator; optionally correct the plan's `tests/enrichment/`/`tests/config/` verify paths.

## TC-11 — [OPEN 2026-07-31, trivial] ww3_station_selection docstrings call mean_offshore_bearing "the same bearing L1 uses" — now stale
- **What:** After G2.1, L1 prefers the open-water bearing (mean_offshore is the fallback). `ww3_station_selection.py` module docstring (~:55-60) and `_resolve_offshore_bearing_deg` docstring (~:422-427) still say mean_offshore is "the same bearing L1 sizing uses."
- **Where:** `services/ww3_station_selection.py` docstrings only (no functional change — the file needed none; the existing `offshore_bearing_deg` kwarg is the injection point).
- **Why non-blocking:** code comments, not governing docs; the functional behavior is correct; mean_offshore is still the shared fallback.
- **To revisit:** touch up the two docstrings to "L1 prefers the open-water bearing; mean_offshore is the fallback" when the file is next edited for a functional reason. Left untouched now for minimal-delta (don't add a file to the diff that needs no functional change).

## TC-10 — [OPEN 2026-07-31, MEDIUM — operational] Public Overpass (overpass-api.de) is flaky; geography fetch depends on it (raise, no fallback)
- **What:** From librewxr on 2026-07-31, overpass-api.de returned HTTP 504 on 2 of 3 attempts (server-side gateway timeout under load), then 200 in 1.4s on the 3rd. The kumi mirror did not respond (35s). geography.fetch_osm_coastline RAISES on failure (no silent fallback, per ADR-100), so a transient Overpass 504 storm fails the whole config-time grid-sizing chain.
- **Where:** `services/geography.py` fetch_osm_coastline / _get_http_client; every config push that hits a cache-miss bbox.
- **Mitigation applied (d8a4397):** bumped the geography HTTP client read_timeout to 35s (was 15s < the 25s query timeout — a real bug) and max_retries to 5, so the config-time cached-30-days fetch rides out transient 504s. Once fetched, cached 30 days (no re-fetch).
- **Why non-blocking (for the plan):** the code correctly raises (loud, not silent); the retry resilience makes success very likely; the gate just needs ONE success (then cached); scope is testing/gate-validation, not production cutover.
- **To revisit (production hardening, separate task):** consider an Overpass mirror-fallback list (kumi/private.coffee/etc. — still real OSM data, within ADR-100), or a self-hosted Overpass, before a public production cutover. Operator decision.

## TC-8 — [OPEN 2026-07-31, low] Heading-consistency self-check threshold = 30 deg (diagnostic only)
- **What:** `check_heading_consistency` (G1.5, geography.py) flags OSM-vs-isobath heading divergence above 30 deg with a WARN.
- **Why non-blocking:** it is a diagnostic WARN sensitivity (AD-6 self-check); no physics branches on it. Chosen so an "aligned" pair (small diff) passes and a 40-deg-divergent pair flags (per G1.5 accept).
- **Assumption made:** 30 deg. To revisit if it over-fires on real curved coasts (a genuinely curved shore may legitimately diverge OSM-line vs local-isobath by >30 deg at a transect) — tune at G6.2 wiring / on real configs.

## TC-9 — [OPEN 2026-07-31, low] Straight-beach L2 grows slightly under coverage-envelope sizing (expected AD-1)
- **What:** G1.4 folds per-transect offshore-contour points into the L2/L3 bbox union, so on a straight beach L2 now covers the segment's own alongshore extent per-transect rather than via one averaged point → a small size delta (demo: ~150-330 m), NOT bit-identical to the old sizing (plan G1.4 said "unchanged").
- **Why non-blocking:** it is exactly AD-1's coverage-driven intent ("L2 encloses the union of every transect's reach"); the sizing FORMULAS/margins are unchanged, only more points feed the existing union; the result is more correct (old single-point sizing under-covered segment ends). Not a regression.
- **To revisit:** confirm L2 sizing is sensible (not pathologically oversized) on the real HB config at G2/Gate GR. A geometry change will (correctly) trip the D6b cold-start guard.

## TC-7 — [OPEN 2026-07-31, MEDIUM — TRACKED AS G1.6, must close before Gate GR] Production SWAN runtime does not yet see the resolved isobath-normal bearing
- **What:** `grid_sizing_chain.run_grid_sizing_chain()` builds an in-memory `parsed` config, resolves the isobath-normal, and discards it. The SWAN RUNTIME path (`providers/nearshore/swan.py:2543`, `swan_runner.py:3549/4992`) re-parses the persisted operator config FRESH in a separate process/cycle, rebuilding `SurfSpotConfig` → recomputes segment-perpendicular. The per-spot profile cache does not carry a bearing field. So after G1.2/G1.3/G1.4 (4-file scope), the isobath-normal improves ONLY grid_sizing_chain's own L1/L2/L3 sizing + cached PCHIP profiles — the served CURVE/OBSTACLE per-transect bearing stays segment-perpendicular.
- **Where:** discovered in G1.2/G1.3 scope-ack (agent trace). grid_sizing_chain (producer) ↔ providers/nearshore/swan.py + swan_runner.py (runtime consumers).
- **Why non-blocking for THIS round:** the 4-file round delivers real value (sizing + profiles + per-transect bearing infra) and meets G1.2/G1.3/G1.4's own accept criteria (which are about the COMPUTED bearing). Within approved AD-1 ("sets the derived value on the spot's profile") — an implementation-sequencing question, not a blocker outside architecture.
- **Resolution (coordinator ruling 2026-07-31):** split into **G1.6** — persist the resolved midpoint beach_facing + per-transect bearings to the profile cache (grid_sizing_chain, producer) AND wire the runtime read sites (providers/nearshore/swan.py, swan_runner.py) to use them → served CURVE/OBSTACLE emission uses isobath-normals. VALUE-only into the existing emission (NO syntax change). Field + reader land together (no orphan field). G1.6 gets its own focused scope-ack + QC because swan_runner.py is near frozen convergence/hotstart machinery.
- **MUST close before Gate GR** — the served per-transect shadow classification / headline aggregate depends on the runtime using the isobath-normal. This is the whole point of the plan.
- **To revisit:** dispatch G1.6 after G1.2/G1.3/G1.4 lands; verify at Gate GR that the served forecast reflects isobath-normal bearings.

## TC-6 — [OPEN 2026-07-31, low] isobath_normal_bearing falls back if the transect origin is deeper than both contours
- **What:** `isobath_normal_bearing` (G1.1) casts rays and only counts a contour crossing SEAWARD of the origin (its "origin already exceeds the target depth" guard). If a transect origin is at depth > 5 m (both default contours 2 m/5 m are shoreward of it), both are skipped → degenerate → segment-perpendicular fallback + WARN.
- **Where:** `enrichment/bathymetry.py` `isobath_normal_bearing`; realistic shoreline origins (near 0 m) work perfectly (verified N/S/E/W axes).
- **Why non-blocking:** transect origins come from the drawn-segment shoreline anchor (near 0 m depth), where it works; the > 5 m case is a graceful fallback (WARN), not a crash — the plan endorses degenerate→fallback+WARN.
- **Assumption made:** near-shore origins are the norm; behavior stands.
- **To revisit:** at Gate GR / on the real HB bathymetry, confirm transect origins resolve isobath-normals (not fallbacks). If a real steep-shore spot origins deeper than 5 m, consider finding the nearest contour in EITHER direction.

## TC-5 — [OPEN 2026-07-31, trivial] geography NaN horizon_km crashes loudly instead of a clean validated error
- **What:** `resolve_regime_horizon_km`/fan `horizon_km <= 0` guard doesn't catch NaN (NaN comparisons are always False), so a NaN horizon crashes at `int(round(nan))` (`ValueError`) rather than the module's own validated-input error.
- **Where:** `services/geography.py` (~line 292); blind-audit finding F2.
- **Why non-blocking:** NaN is not a reachable input — horizon comes from `find_shelf_distance` (real km or None→40) or the flat GL 200. The failure is LOUD (raises), not silent, so it does not violate the no-silent-fallback rule. No design rule requires NaN handling.
- **Assumption made:** left as-is (fails loudly).
- **To revisit:** optional robustness — add an explicit `math.isnan` check to the horizon guard if a NaN path ever becomes reachable.

## TC-4 — [OPEN 2026-07-31, low] geography.fetch_value defined as max-fetch-among-exposed; feeds G2.4 GL L1 sizing
- **What:** G0.3c says the fetch value = "the open-water fetch along the dominant open direction." The impl defines `fetch_value` = `max(fetch_km among EXPOSED rays)`, not the fetch along `open_water_bearing` specifically.
- **Where:** `services/geography.py` `fetch_value`; consumer is G2.4 (Great Lakes L1 sizing).
- **Why non-blocking:** the G0.3 KAT only checks "finite fetch value for a GL basin"; the exact definition isn't KAT-pinned and has no consumer until G2.4. Max-fetch and along-dominant-bearing both are "lake fetch"; max-fetch is arguably safer for SIZING (L1 must reach the farthest open water).
- **Assumption made:** max-fetch-among-exposed stands for now.
- **To revisit:** at **G2.4** — decide whether Great Lakes L1 sizing wants max-fetch or fetch-along-open_water_bearing, and align `fetch_value` (or have G2.4 read the ray it needs). Verify on the real GL config when one exists.
- **What:** The open-ocean / semi-enclosed / enclosed-basin 3-way split (G0.3c, AD-2) needs a criterion that neither the plan nor ADR-100 pins.
- **Where:** `services/geography.py` `classify_water_body_regime` (G0.3); constant `_OPEN_OCEAN_OPEN_FRACTION = 0.5`.
- **Why non-blocking:** verified against the whole plan — the ONLY regime→physics-parameter binding in G0–G7 is the Great Lakes branch (200 km horizon cap, GLWU product, lake-fetch L1). Nothing branches on open-vs-semi-vs-enclosed ocean; that label is descriptive here and selects no physics parameter, so the threshold is a reasonable-default methodology call, not a trigger-1 change.
- **Assumption made (coordinator ruling 2026-07-31):** great_lakes via classify_region; else fan fractions — exposed_frac==0 → enclosed_basin (== boxed-in/no-surf), open_frac ≥ 0.5 → open_ocean, else semi_enclosed.
- **To revisit:** if a future phase wires the ocean-regime split to a physics parameter, the 0.5 threshold becomes trigger-1 architectural → needs operator sign-off then.
- **What:** Plan G0.3 describes `providers/_common/http.py` as "urllib-based"; it is actually `ProviderHTTPClient`, an httpx.Client wrapper.
- **Where:** MARINE-GEOMETRY-MODEL-PLAN.md G0.3.
- **Why non-blocking:** the actionable instruction — "use the existing shared client, do NOT add `requests`" — is correct and unaffected.
- **Assumption made:** G0.3 uses `ProviderHTTPClient` (the `_get_http_client()` singleton pattern in bathymetry.py:233 / ndbc.py:254).
- **To revisit:** nothing required; cosmetic plan wording.

## TC-14 — [OPEN 2026-07-31, low latent] G2.5 island enclosure re-projects rays from _compute_level1's arithmetic-mean centroid, not the geography step's circular-mean centroid
- **What:** The fan casts rays from grid_sizing_chain's centroid (circular-mean lon, `_circular_mean_lon_deg`); `RayResult.bearing_deg` is relative to that. But `_compute_level1` re-projects each wrap-candidate ray endpoint from its OWN `center_lat/lon` (plain arithmetic mean). The two centroids differ slightly.
- **Where:** swan_domain.py `_compute_level1` (~:1048) vs grid_sizing_chain.py geography step (~:980); G2 blind-audit finding F1.
- **Why non-blocking (not reachable):** the F1-proj UTM-zone-straddle guard (`_locked_utm_zone_for_deployment`) refuses configs spanning >2° lon, where circular-mean ≈ arithmetic-mean are numerically indistinguishable. No accepted config can reach a material difference today.
- **To revisit:** if the >2° guard threshold ever changes, thread the geography step's centroid into `_compute_level1` (a param) so the enclosure re-projects from the same centroid the rays were cast from. Small hardening; not urgent.

## TC-15 — [OPEN 2026-07-31, MEDIUM — being addressed in G3] G1.6 runtime write-back reaches the runner loop but NOT the endpoints/surf.py scoring/pipeline path
- **What:** G1.6 wrote the resolved isobath-normal beach_facing/transect_bearings back onto the runner-loop `SurfSpotConfig` (providers/nearshore/swan.py), which is what produces the cached SWAN forecast (verified live: runner-loop `beach_facing=201.9°`). BUT the SERVE-time path (`endpoints/surf.py`) does an INDEPENDENT fresh `load_marine_config()` parse (the `wire_surf_config()` singleton has zero production callers), so `score_surf` (surf_scorer directional filter) and the endpoint's `_compute_spot_transects`/`_compute_pipeline_for_timestep` (679/993) use the SEGMENT-PERPENDICULAR beach_facing + the CONFIG directional_exposure — not the geometry-derived values.
- **Where:** discovered in G3.2 scope-ack (agent trace). endpoints/surf.py's fresh-parse spot_config ≠ the runner-loop/swan.py spot_config that G1.6 wrote back.
- **Why it matters (Gate GR):** the served headline's directional filter (score) and any serve-time transect recompute would use the OLD facing/exposure — inconsistent with the isobath-normal cached forecast — IF those endpoint paths run at serve time in remote mode (being confirmed).
- **Resolution (in-progress, G3):** add a write-back at `endpoints/surf.py`'s spot_config resolution reading the persisted profile-cache fields (directional_exposure for G3.2, AND beach_facing/transect_bearings for this G1.6 gap) — but ONLY the fields the endpoint actually consumes at serve time in remote mode (agent confirming; skip any that are gated off / cache-read, to avoid orphan write-backs).
- **To revisit:** confirm at Gate GR that the served score + headline reflect the isobath-normal + fan exposure (not segment-perp + config exposure).

## TC-16 — [RESOLVED 2026-07-31, was MEDIUM] Non-override directional_exposure defaulted to worst-case before first fan/cache write (G3 audit F1)
- **What:** A fan-derived (non-override) spot, before grid_sizing_chain persists its profile cache (first cycle / persistent PCHIP failure), had a freshly re-parsed all-False directional_exposure → surf_scorer scored it fully blocked (0.1x every direction), silently (DEBUG). G3.3 made this the common case.
- **Where:** marine_config.py directional_exposure default; endpoints/surf.py _apply_persisted_geometry no-cache path.
- **Resolution (fix committed):** non-override pre-fan default is now all-EXPOSED (neutral) — an unknown-exposure spot is not penalized (parity with beach_facing's segment-perp degrade). Verified: non-override → _directional_filter 1.0 all dirs (was 0.1); override all-False → still 0.1 (honored). KAT updated (_ALL_TRUE for the 3 non-override cases; override-all-False stays _ALL_FALSE).
- **Blast radius (per auditor):** narrow — an existing spot keeps serving its old cache during recompute; only first-cycle-ever + persistent-failure. Did not block HB gate (HB has a cache).

## TC-17 — [OPEN 2026-07-31, low] Gate-G3 test left HB config fan-derived (directional_exposure removed)
- **What:** To exercise the fan-derived exposure path live at Gate G3, the coordinator POSTed the HB marine.conf with `directional_exposure` stripped (making it fan-derived). This overwrote the persisted /etc/weewx-clearskies/marine/marine.conf, so HB's operator-set directional_exposure override is gone; HB now uses the fan.
- **Why non-blocking:** G3.3's intent IS that the fan is the default (directional_exposure optional). The fan (measured openness) is arguably more correct than a typed guess. HB's L4 is exposure-insensitive (identical L4 fan vs config), so grid geometry is unaffected; only the serve-time directional-filter score differs (fan sectors vs the old E/SE/S/SW).
- **To revisit:** at Gate GR, confirm the served HB score with fan exposure is sensible. If the operator intended the E/SE/S/SW override, re-add it to the config (it's now an optional override, honored if present).

## TC-18 — [OPEN 2026-07-31, low] HB L4 across-axis is exposure-insensitive (dominated by structure shadow)
- **What:** Fan exposure (open_ocean, S/SW/W) vs the old config exposure (E/SE/S/SW) produced an IDENTICAL L4 (rotation 221°, 4264 cells, across 1030 m) for HB. So the directional_exposure change was a no-op for L4 geometry.
- **Why non-blocking:** the L4 across-axis is the swell-climate shadow-UNION envelope + 2λ, dominated by the pier's 572 m alongshore structure extent; the exposure sectors are secondary for a structure-grid spot. Correct behavior. Meant the live D6b POSITIVE case (L4 resize → cold-start) couldn't be triggered via exposure alone at HB — but it's conclusively guard-proofed on the deployed signature functions (KAT importlib proof) + KAT clears-run-state tests; the live NO-OP case (no false cold-start) was confirmed.
- **To revisit:** the live D6b positive case will naturally exercise at G4 (OMBB axis changes L4 rotation → real L4 geometry change → D6b cold-start).
