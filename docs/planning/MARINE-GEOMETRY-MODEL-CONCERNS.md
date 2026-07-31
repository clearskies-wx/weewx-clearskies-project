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
