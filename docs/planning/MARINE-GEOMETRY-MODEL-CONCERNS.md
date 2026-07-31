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
