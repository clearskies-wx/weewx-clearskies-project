# P4A T4A.3.0 (reduced scope) — Intended-vs-Actual Reconstruction

**Author:** Agent B5, Phase 4A Round 2. **Date:** 2026-07-25.
**Type:** Research and written analysis only. **Zero source files modified.**

**Scope (per `P4A-RECONSTRUCTION-BRIEF.md` and the B5 section of
`P4A-R2-COMPLETE-PHASE-BRIEF.md`):** three intended-vs-actual areas — the CURVE transect's
role, the SurfBeat strip's domain, and per-level bathymetry — plus the full inventory of
governing-document statements still describing the pre-1D design, the concrete gaps the
per-hour handoff and viability test still need, and the open questions the documents do not
settle. **L3's shoreward and offshore extent are not open questions** — D1–D7 in
`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` and ADR-093/ADR-095 Amendment 2 settle them; this
document reports those as facts, not as inputs to a live decision.

## Snapshot — read at these commits

This document is a snapshot, not a live view. Four other agents (B1, B2, B3, B4) are editing
`services/transect_handoff.py`, `enrichment/bathymetry.py`, `services/swan_domain.py`,
`endpoints/surf.py`, `enrichment/wave_transform.py`, and related files in the same working
tree, concurrently with this research. Every "actual" citation below reflects the state at:

| Repo | Commit | Working tree at read time |
|---|---|---|
| `weewx-clearskies-api` | `08ce616` | clean (verified via `git status --short`) |
| meta repo (`weather-belchertown`) | `423aabd` | — |

A later reader should treat any row touching B1's, B2's, or B4's owned files as **potentially
stale, not wrong** — check whether their commits have landed before relying on a row marked
"not found" or "silent deferral" in those files.

---

## 1. Intended-vs-actual table

### Area 1 — The CURVE transect's role

| # | What was intended | Actual (file + line) | Classification |
|---|---|---|---|
| 1.1 | CURVE is diagnostic/validation-only, never a primary data source for the surf endpoint (ADR-095 Amendment 1, Decision 1). T4A.4 removes the CURVE face-height fallback entirely — SwellTrack becomes the sole source of breaking wave heights; no formula-based substitute. | **Confirmed done.** `endpoints/surf.py:1018-1022` — comment states the K-G/Caldwell deep-water formula that used to consume CURVE-derived `corrected_hsig` is removed; `surf.py:1266-1316` — when the 1D pipeline is unavailable, height fields are explicitly `None`, never a CURVE-formula guess (`modelStatus="unavailable"`, not `degraded`). | Matches intent |
| 1.2 | Where L3 exists, CURVE spans L3's actual extent (offshore edge → handoff surface), diagnostic-only (ADR-095 Amendment 1 unchanged by Amendment 2). Where L3 is disabled, **there is no CURVE at all** (ADR-095 Amendment 2, "Decision 1 — amended again"). | **Structurally confirmed for the emission mechanism.** The CURVE+TABLE+SPECOUT block only fires when `grid_level == "inner"` **and** `spot_configs` is truthy (`services/swan_formats.py:1360-1430`). In the production 3-level pipeline, L2 is always run with `grid_level="outer"` (`services/swan_runner.py:1378-1385`) — it gets a hand-rolled deep-water-reference (DWR) `POINTS`+`SPECOUT` block instead (`swan_runner.py:1411-1468`), not a CURVE. Only L3 is called with `grid_level="inner"` + `spot_configs` (`swan_runner.py:1619-1628`). When a cluster's L3 is skipped (`l3_enabled="off"`, or `"auto"` with no structures — `swan_runner.py:1529-1547`, `continue`), no L3 directory is created and no CURVE is ever written for that cluster. So: structurally, CURVE cannot exist without L3. | Matches intent (mechanism) |
| 1.3 | Consequence of no L3 (ADR-093 Amendment 2 §4, verbatim): *"That spot runs L1 → L2 → SwellTrack from L2's ~15 m reference, **as an open beach does**."* The spot should still get usable data — an L2-sourced forecast entry feeding SwellTrack — just not L3-quality data. | **Not found — the fallback has no wiring.** `run_3level()`'s return value `all_results` (`swan_runner.py:1523`) is populated **only** inside the L3-success branch (`swan_runner.py:1643`, `all_results.update(cluster_results)`); nothing else ever writes to it, confirmed by exhaustive grep (`all_results` appears at lines 1523, 1643, 1657-1658 and nowhere else in the function). When a cluster's L3 is skipped, its spot_ids never appear in `all_results`. The provider's per-spot cache-write loop, `for spot_id, forecast_points in results.items():` (`providers/nearshore/swan.py:1764`), therefore **never executes** for those spots — no `forecast`, `spectral`, or `transect` key is ever written to their cache entry (`swan.py:1822-1837`). `run_stationary_level3()` has the identical structure (`swan_runner.py:1704, 1775, 1787-1788`) with the same gap. Note: the DWR SPECOUT **is** computed for every spot at L2 stage regardless of L3 status (`swan_runner.py:1480-1519`, populates `self._spectral_results[spot_id]`) — but for L3-disabled spots this data is silently discarded, because the cache-write loop that would read `spectral_results.get(spot_id, [])` (`swan.py:1825`) never reaches those spot_ids. `grep -i "DWR.only\|L2.only\|open beach\|l3_disabled" providers/nearshore/swan.py` returns zero hits — confirming no fallback path exists anywhere in that file. | **Silent deferral** — the design was stated (ADR-093 Amdt2 §4) but nobody built the wiring; the code path structurally cannot reach it. |
| 1.4 | Downstream consequence, traced through to the surf endpoint and SurfBeat (not itself in the ADRs, but follows mechanically from 1.3). | `surf.py:563` — `swan_points = swan_result.get("forecast") or []` reads the same cache entry that 1.3 shows is never written for L3-disabled spots. `_points_by_time` (`surf.py:672-677`) is therefore empty for those spots (barring a stale last-good cache from a prior L3-enabled run). The per-timestep pipeline loop skips every timestep (`surf.py:929-932`, `if not pts_at_time: continue`) — zero `forecast_entries` for that spot on the current run. See Area 2 row 2.1 for the SurfBeat consequence of the same gap. | Consequence of 1.3, not a separate defect |
| 1.5 | (Minor, code hygiene, not a governing-doc drift.) | `surf.py:664-668` still carries the comment *"select the reference point at ~10m depth for K-G/Caldwell and HSWELL display"* — stale since T4A.4 removed the K-G/Caldwell consumer of that reference point (see 1.1). The `ref_point` selection logic itself (`surf.py:991-1004`) still runs and still feeds `HSWELL`/`directionalSpread`/`setup` display fields, which is legitimate — only the comment is wrong. | Not a governing-document row (source comment only) — flagged for whichever agent next touches this block. |

### Area 2 — The SurfBeat strip's domain

| # | What was intended | Actual (file + line) | Classification |
|---|---|---|---|
| 2.1 | Strip spans 15 m → shore deliberately, because IG energy is generated by breaking and a truncated strip would not produce what it exists to produce (D5, ADR-093 Amdt2 unaffected). Different job from L3, therefore different (larger) domain — confirmed and deliberate, not reopened by the L3 shortening. | **Domain is data-derived, not a hardcoded number**, and depends on the same upstream gap as 1.3-1.4. Cross-shore extent = whatever `profile` array is passed to `run_surfbeat_strip()` (`services/surfbeat_runner.py:177-226`, `_interp_profile`). In production this is `_compute_median_bathy_profile(_spot_transects)` (`surf.py:775`) — the per-transect **cached bidirectional bathymetric profile** (same PCHIP/CUDEM source SwellTrack uses), not the `1D-MODEL-BENCHMARK-BRIEF §7.3` figure of "~2,500 m at dx=5 m." Whether that cached profile's offshore end reliably lands at ~15 m — for both L3-enabled and L3-disabled spots — was **not verified in this pass**; flagged as an open item below. **More consequential:** the strip's boundary-condition lookup (`surf.py:833-839`) reads `_points_by_time`, the same dict shown empty for L3-disabled spots in row 1.3-1.4. `_sb_pts = _points_by_time.get(_best_ts, [])` is empty → `if not _sb_pts: _surfbeat_by_hour[_sb_hr] = None; continue` (`surf.py:829-831`) for every cadence hour. **The strip cannot run at all for L3-disabled spots today** — directly undermining D5's stated premise that the strip becomes "the only SWAN-quality wave height in the approach zone" once L3 stops early: it is not available there either, in the current code. | **Silent deferral**, same root cause as 1.3 |
| 2.2 | Boundary condition = "the L2 SPECOUT spectrum at the 15 m handoff" (1D-MODEL-BENCHMARK-BRIEF §7.3, quoted verbatim in D5). | **Confirmed different: a scalar parametric JONSWAP triplet, not a spectrum.** `services/surfbeat_runner.py:361` — code comment: *"v1: parametric JONSWAP (design decision; L2 SPECOUT boundary is future work)"*; emission at `surfbeat_runner.py:362-365` — `BOUND SIDE WEST CCW CONstant PAR {hs} {tp} {direction} {dir_spread}`. The `hs`/`tp`/`direction` values themselves come from `surf.py:833-839` — "the most offshore point at this timestep" in `_points_by_time`, i.e. a bulk Hs/Tp/Dir triplet from the CURVE/points table, not a spectral decomposition. This is explicitly labeled a v1 simplification in the code itself — the deviation is *known*, but D5 in the boundary-decisions brief cites the spectrum-boundary spec without flagging that production code has never implemented it. | **Intentional deviation** (self-documented in code) that the governing brief does not currently reflect — inventory row 2.4 below. |
| 2.3 | Cadence: 3-hour intervals, carry-forward (not interpolation) between runs, because set/lull timing evolves slowly (ARCHITECTURE.md:108-109; D5). | **Confirmed, matches intent exactly.** Default `surfbeat_cadence_hours = 3` (`endpoints/setup.py:505`, `config/marine_config.py:510-512`). Carry-forward implemented as "largest cadence hour key ≤ current elapsed hour" (`surf.py:1334-1341`) — a true carry-forward, not interpolation. | Matches intent |
| 2.4 | Blended Hs profile: SurfBeat Hs for the approach zone (seaward of break point), SwellTrack Hs for the surf zone, 50 m linear taper at the transition (ARCHITECTURE.md:110). | **Confirmed implemented** in `endpoints/beach_profile.py:228-294` (`_blend_hs_profiles()`) — 50 m taper centred on the break point, `numpy.interp` to align SurfBeat's ≤25 m station spacing to SwellTrack's grid, matches the spec exactly. | Matches intent |
| 2.5 | **Named gap to establish (R2 brief addition):** does the blend have a gap on non-strip hours? | **Yes, confirmed gap.** `beach_profile.py:846-848` looks up the SurfBeat data via `get_cached_surfbeat_result(location_id)`, which returns a **single globally-cached "most recent successful SurfBeat result"** (`cache_surfbeat_result()` in `surf.py:919-925`: `_last_sb = next(v for v in reversed(list(_surfbeat_by_hour.values())) if v is not None)`). This is the last successful cadence-hour result across the **entire 72 h forecast run**, not time-aligned to the specific timestep `beach_profile.py`'s request is for. This is a different (and weaker) mechanism than the per-timestep carry-forward `surf.py` itself implements for the IG display fields (row 2.3, `surf.py:1334-1341`, "largest cadence hour key ≤ elapsed hour for **this** timestep"). Practically the drift is bounded by the ≤3 h cadence when both requests hit the same forecast run, but there is no code guaranteeing the cached result is for the same or an earlier hour than the requested profile's timestep — a profile request for hour 3 could serve a SurfBeat run computed at hour 6 if that ran more recently in wall-clock time. | **Partial implementation** — the carry-forward concept exists (surf.py) but was not carried into the consumer (beach_profile.py) that also needs it. |

### Area 3 — Per-level bathymetry

| # | What was intended | Actual (file + line) | Classification |
|---|---|---|---|
| 3.1 | Per-level bathymetry cached separately for L1 (1 km), L2 (100 m), L3 (10 m, one file per cluster bbox), lazy-downloaded, 180-day TTL (ARCHITECTURE.md:100). | **Confirmed implemented as described.** `providers/nearshore/swan.py:110-112` — `_CUDEM_GRID_PATH_L1 = swan_bathymetry_L1.json`, `_CUDEM_GRID_PATH_L2 = swan_bathymetry_L2.json`, L3 hashed per-cluster at `swan_bathymetry_L3_{hash}.json` (`swan.py:204-210`, MD5 of rounded bbox). TTL and download-on-miss logic in `download_bathymetry_for_level()` (`swan.py:181-253`). | Matches intent |
| 3.2 | Vertical datum consistency — resolved per-DEM, not assumed (ARCHITECTURE.md:100, "Vertical datum consistency enforced by matching..."). | **Confirmed implemented for the L1/L2/L3 grid caches.** Each grid dict carries a real `vertical_datum` field sourced from `bathymetry_resolver.find_best_dem()`/`get_operator_grid()` (`swan.py:231-246, 260-312`); a cached grid missing `vertical_datum` is treated as stale and re-downloaded (`swan.py:231-238`). | Matches intent |
| 3.3 | SwellTrack and SurfBeat read bathymetry at the same fidelity as SWAN — "both read the same DEM... SwellTrack varies its computational grid; its data is the same" (`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` §D2b superseded-analysis note). | **Confirmed as a separate but source-consistent cache.** `TransectInfo.bathymetric_profile` (read by both `_compute_median_bathy_profile()` for SurfBeat, `surf.py:369-372`, and by SwellTrack's own pipeline) is a per-transect PCHIP-interpolated profile, cached independently of the L1/L2/L3 SWAN grid caches in row 3.1 (T4A.2's `/etc/weewx-clearskies/spot_profiles/{id}.json`, per `SURF-ZONE-MODEL-BRIEF.md:568-572`). This is a deliberate separation (different consumer, same underlying CUDEM source), not a duplication defect — flagged here only because it is exactly the kind of fact the per-hour handoff (B1) and viability test (B2) need to reason about consistently. | Matches intent (two caches, one source, by design) |
| 3.4 | Beach-profile response records the DEM's **actual** vertical datum, not a hardcoded value (plan T4A.6 item f; flagged as a known defect by the coordinator, LC-R2-10/LC-R2-14). | **Confirmed defect, exactly as flagged.** `endpoints/beach_profile.py:826` — `"verticalDatum": "NAVD88"`, a hardcoded literal, even though row 3.2 shows the true datum is tracked and available on the grid dict that ultimately backs this response. The datum-tracking machinery exists upstream; it was never threaded through to this consumer. | **Partial implementation** — this is B2's/B3's assigned fix this round (LC-R2-10, LC-R2-14); cited here with citation only, not re-litigated. |
| 3.5 | ADR-093 Amendment 2 §4 viability test: compute L3's extent, then test whether it reaches the feature it was created for; disable with a mandatory INFO log naming the feature and shortfall if not. | **Not found.** `grep -i "viability\|unreachable\|shortfall"` across `services/swan_domain.py`, `services/swan_runner.py`, `services/transect_handoff.py` returns zero relevant hits (the only "unreachable" hits in the whole repo are unrelated Redis/DB-connectivity and dead-code-marker comments). The current L3 disable check (`swan_runner.py:1529-1547`) is a **necessary-condition** gate only — `l3_enabled` config value and structure presence — not a **sufficiency** test comparing the grid's computed shoreward reach against the feature's depth. This is B2's in-flight T4A.11 this round, not a discovery of neglect — noted here because T4A.3.0's job is to state what the code does *today*. | **Not yet built** (in-flight, concurrent work — not a stale defect) |
| 3.6 | ADR-093 Amendment 2 §2: size the L3 grid at setup to reach as far shoreward as it is ever useful (the shallow end of the year's breaking range), independent of the old fixed 15 m-to-shore geometry. | **Not found.** `grep -i "1\.3\|per.hour\|breaking_depth\|handoff"` in `services/swan_domain.py` returns zero hits. `compute_domains()`'s L3 offshore-edge default is still the literal `15.0` (`swan_domain.py:104`) — correctly, since D1 keeps the 15 m offshore contour — but there is no corresponding shoreward-reach computation anywhere in that module. This is B1's/B2's in-flight T4A.9/T4A.3/T4A.11 this round. | **Not yet built** (in-flight, concurrent work) |
| 3.7 | D3 (open-beach handoff depth): ADR-093 Amendment 1 §1 says 15 m from L2 when no L3; SURF-ZONE-MODEL-BRIEF §2.3.4 says 10 m default for any unshadowed transect, L3 or no. The boundary-decisions brief recommends reconciling — 10 m only inside an L3-enabled cluster, 15 m when the spectrum comes from L2 — but flags the recommendation as **never adopted**. | **Confirmed still unreconciled in code.** `services/transect_handoff.py:44` — `_DEFAULT_HANDOFF_DEPTH_M: float = 10.0`, applied unconditionally to every unshadowed transect at `transect_handoff.py:386`, with no branch on whether the transect's cluster has L3 enabled. | **Intentional-deviation-turned-drift** — the 10 m value was correct under Era 2 (pre-optional-L3); nobody revisited it when L3 became conditional. Carried as inventory row (below), not re-derived — this is D3, already flagged open by the R2 brief. |

---

## 2. Inventory of governing-document statements still describing the pre-1D design

Per the head start, these 8 rows were located by Agent A3 and deliberately left un-bannered
for this task. Verified against the current file contents (line numbers unchanged from the
brief):

| # | File | Line | Verbatim statement | Verified? | Proposed disposition |
|---|---|---|---|---|---|
| I1 | `SWAN-NESTING-RESEARCH-BRIEF.md` | 196 | "Domain sizing: Per spot: 500m alongshore (250m each side of pin) × ~1 km cross-shore (shore to 15m depth)" | Confirmed at line 196, unchanged | Banner as Era 1 (historically correct, pre-1D) — do not delete, this is the depth-of-closure-derived L3 design that Amendment 2 superseded. |
| I2 | `SWAN-NESTING-RESEARCH-BRIEF.md` | 245 | "The grid is sized **proportionally**: ~1 km cross-shore (to 15m depth where features exist) and ~500m alongshore..." | Confirmed at line 245, unchanged | Banner as Era 1, superseded by ADR-093 Amendment 2 §1/§2 (cross-shore extent is now handoff-derived, not a fixed ~1 km). |
| I3 | `SWAN-NESTING-RESEARCH-BRIEF.md` | 264 | "Each cluster becomes one Level 3 grid: 250m before first pin → 250m after last pin × 1 km cross-shore" | Confirmed at line 264, unchanged | Banner as Era 1 — alongshore figure (250m/250m) is superseded by Amendment 1's shadow-zone-based sizing; cross-shore figure by Amendment 2. |
| I4 | `SURF-ZONE-MODEL-BRIEF.md` | 25 (§2.1) | "SWAN runs 2D all the way to shore (preserving structure interaction and bathymetric refraction)..." | Confirmed at line 25, unchanged | Banner — this is the v1/Era 2 core-concept statement that ADR-093 Amendment 2 directly reverses (L3 does not run to shore). |
| I5 | `SURF-ZONE-MODEL-BRIEF.md` | 234–242 (§2.3.5) | Whole subsection, "SWAN grid scale at the handoff" — assumes the old fixed 15 m handoff and states "Always extract SPECOUT from L3 regardless" | Confirmed, section intact at 234–242 | Banner — superseded by ADR-095 Amendment 2's "No SPECOUT may be extracted at an L3 boundary cell" rule, which is close to the opposite instruction. |
| I6 | `SURF-ZONE-MODEL-BRIEF.md` | 248 (§2.4 item 1) | "SWAN runs the full 2D domain to shore." | Confirmed at line 248, unchanged | Banner — same as I4. |
| I7 | `SURF-ZONE-MODEL-BRIEF.md` | 263–265 (§2.5) | "SWAN runs 2D all the way past structures, down to 5-8m depth." (describing the XBeach-1D-surfbeat established-pattern option, not our own architecture, but presented without qualifying it as such) | Confirmed at line 263, unchanged | Banner or clarify — this describes an external precedent (Deltares SWAN→XBeach pattern), not necessarily our own system; still worth a note since a reader skimming could conflate it with our L3. |
| I8 | `SURF-ZONE-MODEL-BRIEF.md` | 306 | Cost table row: "2500m (HB Pier, 15m to shore)   \| 5m \| 500 \| ~0.5ms \| ~5ms" | Confirmed at line 306, unchanged | Banner — this is the pre-Amendment-2 L3 domain-length estimate used to derive compute-cost figures; the *SurfBeat strip* (a different model, Area 2 above) actually still runs close to this domain, so a corrective note should distinguish "this was an L3 estimate, now wrong" from "the SurfBeat strip legitimately still spans this range." |
| I9 (addition) | `L3-1D-BOUNDARY-DECISIONS-BRIEF.md` §D3, and — the still-unreconciled code | `transect_handoff.py:44, 386` | D3's recommended reconciliation ("10 m only inside an L3-enabled cluster, 15 m when the spectrum comes from L2") was **never adopted**. ADR-093 Amendment 1 §1 and SURF-ZONE-MODEL-BRIEF §2.3.4 still contradict each other, and `_DEFAULT_HANDOFF_DEPTH_M = 10.0` applies unconditionally. | Confirmed in code, this session (see Area 3 row 3.7) | This is live code-and-doc drift, not a historical record — recommend it be picked up explicitly as a task (it currently has no owner in the R2 round) rather than bannered as historical. |
| I10 (addition) | `MARINE-SERVICE-SEPARATION-PLAN.md`, T4A.3.0 body, lines 935–938 | 935–938 | "Still open and in scope for this task: whether L3's **offshore** edge should remain the 15 m contour now that L3's job has narrowed... and the 10 m vs 15 m handoff inconsistency..." | Confirmed present at those lines | **This is now self-contradicting within the plan itself.** The `SCOPE REDUCED 2026-07-25` block earlier in the same T4A.3.0 section (lines 862-869) already says "L3 extent, handoff depth selection... are settled — do not re-derive them," which is correct per ADR-093 Amendment 2 (D1 closed). Lines 935-938 were written before that closure and were not updated. This is the plan's own document, not mine to edit (per scope), but it is exactly the kind of doc-doc drift this inventory exists to catch — flagging for the coordinator to correct at round close alongside the plan's status table. |
| I11 (addition) | `1D-MODEL-BENCHMARK-BRIEF.md` §7.3 (as quoted by D5 in `L3-1D-BOUNDARY-DECISIONS-BRIEF.md:472`) | — | SurfBeat strip spec: boundary = "the L2 SPECOUT spectrum at the 15m handoff" | See Area 2 row 2.2 — production code implements a scalar parametric-JONSWAP boundary, not a spectrum. Not verified against `1D-MODEL-BENCHMARK-BRIEF.md`'s own text directly (not in this task's required reading list at full-file depth), sourced via the D5 quote. | Flag for correction — either the spec should be updated to describe the parametric v1 as accepted-and-intentional (matching the code's own "design decision" comment), or the "L2 SPECOUT boundary" work should be scheduled and the spec left as the target. Not mine to decide which — surfaced as open question OQ2 below. |

---

## 3. What the per-hour handoff and the viability test will need that does not exist yet

Named per area, concrete:

1. **A working L3-disabled fallback path in the SWAN cache-write chain** (blocks B1's T4A.9
   data contract). `handoff_source_level: "L2"` is meaningless in the response unless an
   L2-sourced forecast entry actually exists for that spot/timestep — and today (Area 1, row
   1.3) it does not. B1's per-hour handoff cannot emit a real `"L2"` case until
   `run_3level()`/`run_stationary_level3()` (or the provider layer above them) produce a
   forecast entry for L3-disabled spots from the DWR SPECOUT that is already being computed
   and discarded (`swan_runner.py:1480-1519`).
2. **The grid-reach-vs-feature-depth comparison function itself** (Area 3, row 3.5) — not
   found anywhere in `swan_domain.py`, `swan_runner.py`, or `transect_handoff.py`. The
   viability test cannot run until this exists.
3. **The mandatory INFO log naming the unreachable feature and the shortfall** (ADR-093 Amdt2
   §4) — depends on #2 existing first; not found.
4. **L3's shoreward-reach sizing at setup** (Area 3, row 3.6) — the per-hour breaking-depth
   expression (`1.3 × Hs(hour) / gamma`) does not appear anywhere in `swan_domain.py`. The
   viability test in #2 needs a computed shoreward edge to test against a feature depth; that
   edge does not exist yet.
5. **A SurfBeat boundary-condition source that does not depend on the CURVE/points cache**
   (Area 2, row 2.1) — otherwise the strip stays unusable for every L3-disabled spot even
   after #1 is fixed for the SwellTrack side, because `surf.py:828-831`'s `_sb_pts` lookup
   reads the same empty structure. The natural fix is reading from `spectral_results`/DWR
   directly (already computed, see #1) rather than from `_points_by_time`.
6. **A cadence-aware SurfBeat lookup in `beach_profile.py`** (Area 2, row 2.5) mirroring the
   per-timestep carry-forward `surf.py` already has, so the blend cannot silently serve a
   SurfBeat result computed for a different forecast hour than the one requested.
7. **Datum threading from the per-level grid cache into the beach-profile response** (Area 3,
   row 3.4) — the datum is already tracked (row 3.2); it just needs to reach
   `beach_profile.py:826`.
8. **The D3 reconciliation** (Area 3 row 3.7 / inventory I9) — `transect_handoff.py:44`'s
   unconditional 10 m default needs a branch on cluster L3-enablement before the per-hour
   handoff can correctly report `handoff_source_level` for open (unshadowed) transects.

---

## 4. Open questions the documents do not settle

Audited against ADR-093 Amendment 2, ADR-095 Amendment 2, and
`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` D1–D7 first — only genuinely unsettled items listed.

- **OQ1 — D2's seaward-buffer distance N (in wavelengths) is still open.** ADR-093 Amendment 2
  itself says so explicitly ("The buffer magnitude (N wavelengths) remains open and is the one
  live sub-question" — plan T4A.3.0 body, line 931). Not re-litigated here; just confirmed
  still open as of this reading, not resolved anywhere in the code or docs inspected.
- **OQ2 — SurfBeat's boundary-condition spec vs. its implementation (inventory I11 / Area 2 row
  2.2).** Is the parametric-JONSWAP v1 boundary the accepted long-term design, or is the L2
  SPECOUT spectrum still the target with the parametric version a known interim gap? The code
  comment calls it "v1... future work," implying the latter, but no governing document commits
  to a timeline or confirms the interim state is acceptable for production. Not something this
  task resolves — surfaced for the operator/coordinator.
- **OQ3 — Has the "SWAN open-boundary behaviour at a nested grid's unspecified shoreward edge"
  verification (`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` §6, item 1 — listed as *blocking* before
  D2 could be finalized) actually been done?** ADR-093 Amendment 2 is now Accepted and D2's
  buffer approach (Option C — extract at the handoff position with grid on both sides,
  confirmed in production code per `swan_formats.py:1424`, `swan_runner.py:1444`) was adopted.
  Whether the underlying SWAN-manual verification that was flagged as blocking was actually
  performed, and where its result is recorded, was not located in the reading list for this
  task. This is close to what B1's LC-R2-4 and B4's supplement-#3 gate are independently
  verifying this round from a different angle (POINTS/SPECOUT interpolation behaviour) — it
  may already be answered by their work; not re-derived here to avoid duplicating it.
- **OQ4 — D6 (SwellTrack's missing physics over a long approach leg) recommends stating
  explicitly which quantity is validated (face height at break) and which is not
  (approach-zone Hs from SwellTrack alone).** Not verified in this pass whether any governing
  document (API-MANUAL, ARCHITECTURE.md) actually carries that distinction today, or whether
  it remains an undocumented dependency as D6 warns. Flagged, not resolved.
- **OQ5 — SurfBeat strip's actual offshore starting depth (Area 2, row 2.1).** Whether the
  cached bidirectional bathymetric profile that bounds the strip's domain reliably starts at
  ~15 m depth — for both L3-enabled and L3-disabled spots, and specifically once the per-hour
  L3 shoreward edge (item 4, §3 above) starts moving the handoff around — was not verified.
  This is a factual gap in this reconstruction, not a design question: it needs a code read of
  `download_bidirectional_profile()` and how far offshore it extends, which was out of the file
  list read for this task.

---

## Files read for this reconstruction (not exhaustive of the full reading list, but every
citation above is from a file listed here)

ADR-093, ADR-095, ADR-096, ADR-097 (full text incl. all amendments);
`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` (full, 592 lines, D1–D7, superseding box read first);
`MARINE-SERVICE-SEPARATION-PLAN.md` (T4A.3.0, T4A.3, T4A.1, T4A.2, T4A.2b sections, the
`SCOPE REDUCED` block, and the Phase 4A header/decisions section); `ARCHITECTURE.md` (SWAN
block, lines 90-124); `SURF-ZONE-MODEL-BRIEF.md` (§1, §2.1-2.6, §6.1 region, R1-R10 research
table); `SWAN-NESTING-RESEARCH-BRIEF.md` (domain-sizing table region); `P4A-RECONSTRUCTION-
BRIEF.md`; `P4A-R2-COMPLETE-PHASE-BRIEF.md` (shared blocks + B5 section).

Source: `services/swan_formats.py`, `services/swan_runner.py`, `providers/nearshore/swan.py`,
`services/surfbeat_runner.py`, `endpoints/surf.py`, `endpoints/beach_profile.py`,
`services/transect_handoff.py`, `services/swan_domain.py`, `enrichment/bathymetry.py`
(module-level cache path constants), `config/marine_config.py`, `endpoints/setup.py`
(surfbeat_cadence_hours default).
