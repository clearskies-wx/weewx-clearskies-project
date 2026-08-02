# Track A Execution — Out-of-Scope Concerns Log (2026-07-29)

> ## ⛔ ARCHIVED 2026-08-02 with its plan (`MARINE-WORKING-MODEL-PLAN.md`)
>
> Still-open items were carried into **`docs/planning/MARINE-FORWARD-PLAN.md`** (2026-08-02):
> TA-C21 (invariant-3 rescope, operator decision), TA-C22 (modelStatus grading + transect-31 PT* gap),
> TA-C16 (66 h vs 72 h window). All other TA-C entries are closed or superseded — this file is the
> historical record of each; read the forward plan for what is actionable.

Findings surfaced while executing Track A of `MARINE-WORKING-MODEL-PLAN.md` that are **outside the
scope of the current task** and deferred for later operator/coordinator attention. In-scope defects
are fixed under their task; this file is only for things the plan does not already cover.

Format: `TA-Cnn` | date | severity | title | detail | suggested home.

---

## TA-C21 — [DIAGNOSED 2026-07-30, non-blocking; OPEN operator decision] Marine invariant 3 over-fires — 0/32 shadowed is CORRECT for HB
- **Date:** 2026-07-30. **Severity:** low/non-blocking (a per-cycle false-alarm log line; no wrong physics).
- **Diagnosis (T4.4 Part A, coordinator-reproduced):** invariant 3 (`3:structures_configured_implies_shadowed`, `invariants.py:68`, fired at `transect_handoff.py:553-559`) asserts unconditionally "≥1 structure configured ⇒ ≥1 transect shadowed." For deployed HB this is **too strict**: the pier's coordinate bbox (lat 33.65296–33.65687) sits entirely **up-coast/north** of the operator-drawn 32-transect measurement segment (lat 33.65044–33.65280). At all three shadow angles the algorithm tests (`beach_facing ± 30°` = 208.02/238.02/268.02°), the pier's alongshore (v) shadow span never overlaps the transect fan's v-range — a real **27–139 m gap**, not a rounding artifact. The cross-shore (u) "shoreward of tip" test independently passes for 22–32/32, ruling out a u-axis/tip sign error. **No geometry defect** in `_compute_shadow_span`/`_in_shadow`/`_project_uv`/`_wave_travel_unit_vector`. So **0/32 is the physically correct classification** — the pier does not shadow the drawn segment for this geometry. (`_perpendicular_bearing`'s +90°-only rotation is a separate latent 180° ambiguity but empirically does NOT explain 0/32 here — a 180° flip still gives 0/32.)
- **Consequence for M2 (favorable):** QC Gate 3's shadow-bias requirement is SATISFIED — because no transect is shadowed (correctly), the headline face aggregate is not shadow-biased (nothing wrongly excluded/included). This closes the M2 shadow-bias question without a code change.
- **Home:** OPEN operator decision only — rescoping invariant 3 (e.g. "a configured structure must shadow ≥1 transect of THIS spot's drawn segment" → only assert when the structure is within the segment's alongshore span) is a **criterion change (architectural trigger 1)** and was NOT made. Findings: `docs/planning/briefs/T4.4-SHADOW-DIAGNOSIS-2026-07-30.md`. Options: (a) rescope invariant 3 to not fire when structure is alongshore-disjoint from the segment; (b) downgrade it to INFO; (c) leave as-is (harmless false alarm). Needs operator sign-off.

## TA-C20 — [DOWNGRADED→MEDIUM 2026-07-30 PM] Surf magnitude (trace-confirmed: matches matched-time cam on f337648; "2×" was a stale wrong-hour comparison)
- **Date:** 2026-07-30. **Severity:** HIGH — the served surf height is roughly half of reality. **Verified against reality:** operator Surfline screenshot for HB, 2026-07-30 — **SURF HEIGHT 8–10 ft ("2x overhead")**, swell 2.7 ft @ 16 s SSW 191° + 3.2 ft @ 13 s S 169° + 1.2 ft @ 6 s W 273°. Our deployed run's served face height peaked at ~1.6 m (~5.3 ft) and most hours ~3.5–4.5 ft.
- **Corrected understanding (a wrong hypothesis, recorded so it isn't chased again):** the coordinator first attributed the gap to swell PERIOD (the model running a ~12 s bulk average instead of the real 16 s groundswell). That was WRONG as the *primary* lever. The implementer's probe on the real HB fixture showed: at equal Hs, 16 s vs 12 s changes break-face by only ~2–4%, and **~0% at HB's shallow ~1.46 m handoff** (both periods depth-saturate to γ·d at the handoff with no shoaling room). Period is not the ~2× lever here.
- **Root cause (data-backed, real run 2026-07-30 07:53, L4 TABLE, first timestep):** SWAN itself shoals the swell UP and makes a decent wave, but height is lost at/after the SWAN→1-D handoff. SWAN Hs vs depth: 1.06 m @10 m → 1.15 m @7 m → 1.31 m @4 m → **1.44 m @3 m (peak, breaks here)** → 1.21 m @2 m (broken). So SWAN's own breaking height ≈ 1.44 m → face ≈ **~6 ft** — already MORE than the ~4.5 ft we serve. The ~2× to reality is a **stack**, all in physics/handoff design:
  1. **Handoff placed shoreward of the break.** The 1-D handoff lands at ~1.46 m depth — *inside* the surf zone, shoreward of SWAN's ~3 m break point — so the 1-D surf model receives the already-broken, smaller wave (~1.1 m) instead of the ~1.44 m peak. Biggest single, cleanest lever (~4.5 → ~6 ft). This is the handoff-depth formula (`1.3·Hs/γ`), which uses a wave height smaller than the shoaled breaking Hs, so it self-places too shallow. ARCHITECTURAL (trigger 1/3).
  2. **Headline metric is max-single-partition, not the combined breaking wave.** The 1-D model splits the wave into separate swell partitions and reports the biggest single one; SWAN breaks the COMBINED wave (1.44 m) bigger than any single partition. Splitting can make the headline DROP. Whether the headline should be RSS/combined is a metric-definition decision. ARCHITECTURAL.
  3. **Residual gap even in SWAN.** SWAN's own 6 ft is still under Surfline's 8–10 ft — a further ~30–60% in long-period-swell shoaling/refraction on the way in, or in the face-height SCALE CONVENTION (our 1.27·Hs "face" vs however Surfline defines "surf height"). Needs its own check. ARCHITECTURAL / definitional.
- **This has been wrong for days** and was masked because every automated check (tests, invariants) passed while nobody compared to Surfline — the "validate against reality" failure our own `rules/verification.md` documents.
- **Related work done (correctness, NOT a magnitude fix):** the per-transect swell-spectrum handoff was implemented (each transect now uses its OWN in-grid `PT*` partitions; the single out-of-grid diagnostic CURVE spectrum path is removed entirely — it was returning empty components every hour, forcing a bulk-fallback and serving `multiSwell`/`breakingFaceHeight` as `None`). Full marine suite 490 passed. **Status (updated 2026-07-30): committed `f337648`, pushed to origin/main, and DEPLOYED (librewxr HEAD=f337648, verified this session). The earlier "UNCOMMITTED, NOT deployed" note is stale.** It fixes the empty-partition/None-serving bug but does not by itself move the headline (may even lower it per finding #2).
- **T3.0 UPDATE (2026-07-30 PM, coordinator-reproduced) — the boundary INPUT is faithful AND matches the real buoy; Surfline is the outlier; the "~2×" premise has a timing confound.** Ground-truth done vs a REAL NDBC buoy (46222, the same San Pedro Channel station our pipeline fetches, at the identical lat/lon) + the raw NOAA gfswave `.spec`, valid_time 2026-07-30T19:00:00Z:
  - **Our `ww3_spectrum_to_swan_boundary()` is a byte-faithful passthrough** — raw WW3 Hs 0.894 m = our-converted 0.894 m (0.00% diff, reproduced). So NO boundary-writer / defect-C fix is warranted; verdict (a) ruled out. (Phase 2's old T2.1 join fix is confirmed unnecessary.)
  - **The real buoy AGREES with our WW3 input, not with Surfline.** Buoy total Hs 0.933 m vs our 0.894 m (−4.1%). Buoy swell energy is one S/SSE direction family (13.3 s@161°, 11.8 s@170°, 15.4 s@170°, RSS ≈0.83 m) matching WW3's single swell band (14.5 s@179°, 0.826 m); buoy windsea 6.7 s@272° 0.31 m matches WW3 5.6 s@267° 0.34 m. Buoy and our data agree within a few %.
  - **Surfline is the outlier** (~1.28 m combined swell, 2 distinct swell directions 191°/169°) — neither the buoy nor WW3 supports a 1.28 m swell or two widely-separated swell directions at 19:00Z. **BUT the operator's Surfline screenshot is date-only (no hour)** — it may be a different hour with a bigger pulse. **Before any architectural surgery on magnitude, get a SAME-HOUR Surfline (or NDBC-driven) reality check** — the date-only screenshot cannot pin the true gap.
  - **Train-count (2 vs 3):** the difference is frequency SUB-structure within one swell direction family that WW3 smooths and the buoy resolves; it does NOT move swell Hs or direction (WW3/buoy agree on those). **Named blind spot in the T3.0 method:** partitioning was on the 1-D frequency marginal, which cannot separate same-frequency/different-direction trains — but the buoy's own direction data (single S-family) shows this blind spot is not load-bearing here. A 2-D freq×direction watershed of the raw `.spec` is the one check not done (low expected value given the buoy result).
  - **Implication for TA-C20:** the magnitude gap (if real at matched time) is NOT in the boundary input — it is downstream (causes #1 handoff-placement / #2 combined-wave metric), OR partly a Surfline timing/definition artifact. This strengthens #1/#2 as the levers and argues for a matched-hour reality check FIRST. New sub-finding (needs matched-hour Surfline to confirm): a swell-magnitude residual 0.83 (buoy/WW3) vs 1.28 (Surfline). Findings: `docs/planning/briefs/T3.0-BOUNDARY-GROUNDTRUTH-2026-07-30.md`.
- **BASELINE CORRECTED + FIXES APPROVED (2026-07-30 PM):** the "8–10 ft / ~2×" was LAST NIGHT's bigger swell — a stale comparison. The operator's **current cam reads 4–5 ft "chest to head"** (matched-time reality). So the magnitude gap is much smaller than "2×"; the two fixes are about **correct handoff LOCATION + correct headline DEFINITION**, NOT inflating to 8–10 ft — and must **not over-shoot** the cam. Both fixes are now **operator-APPROVED in chat** and specced in the plan, **briefs-grounded** (not first-principles):
  - **Cause #1 → plan T2.2:** handoff is sampled inside the breaking zone (`1.3·Hs/γ` ≈ 1.46 m < HB's measured QB=0 floor ~3.7 m, SURF-ZONE-MODEL §2.3.4). Restore the clean-zone (QB≈0) handoff the design already specifies via the wired-but-not-firing `refine_handoff_with_qb` guard (transect_handoff.py:821). Amends ADR-093 Amendment 2. **DIAGNOSE via a live QB trace on the fresh run BEFORE fixing.**
  - **Cause #2 → plan T2.3:** headline = max-single-partition → adopt the conditional swell-combination rule (MARINE-SURF-FISHING-RESEARCH-BRIEF §11.3, WaveSEP/AUSWAVE: 75 %/50 % thresholds, ±3 s/±45° compatibility, energy superposition `√(H₁²+H₂²)`), confirmed by NOAA/NWS + BoM (combined SWH = √ΣHs²) and Surfline (combines primary+secondary, gives a range). 1D-MODEL-BENCHMARK §7.9 makes "combined > any single partition" a validation invariant. Respect the K-G face conversion (no double-count, WAVE-BREAKING-CONVERSION-BRIEF).
  - **Cause #3 (residual/train-count) → RESOLVED by T3.0** (boundary faithful; buoy agrees with our input; 2-vs-3 trains = WW3 frequency resolution within one direction family, not our loss). Not a code fix.
- **TRACE-CONFIRMED (2026-07-30 PM — fresh traced run, restart 21:15:40Z → cache 21:56:25Z; read HB `handoff_selection` + `swelltrack` records + L4 `TABLE_PT` ground truth, then reverted the trace).** All from the live run, not reconstruction:
  - **Cause #1 does NOT occur on current code (f337648).** Across all **2144** HB per-transect handoff picks: `qb_refined`=0, `clamped`=0, breaking-exhausted=0, reason **100 % "selected"** — the QB seaward-advancement guard NEVER fires because the **initial pick is already clean**. Ground truth (L4 `TABLE_PT`, transect 0, 18:00): Hsig peaks **1.425 m @3.08 m (Qb 0.008)**; Qb crosses 0.05 between 2.66 m (0.029) and 2.27 m (0.071); the handoff chose **2.5 m → Qb ≈ 0.04 (clean, at breaking onset), catching ~98 % of the Hsig peak.** It is NOT landing in the broken zone — the "1.46 m inside the surf zone" figure was the **PRE-f337648 shared-CURVE state**. The guard is not "dark" (no dark-guard WARNING; real Qb present at the chosen station).
  - **Served magnitude MATCHES the matched-time cam.** Per-hour best_peak **4.7–5.0 ft**, spot_avg **4.2–4.3 ft** (current hour 22:00Z: 4.88 / 4.31 ft) vs the operator's **4–5 ft "chest to head"** cam. `face = 1.27 × hs_at_break` confirmed. On current code + current conditions the magnitude is CORRECT — no "2×" gap. (`hs_break_over_boundary` mean 0.78 is NOT a defect: the resulting face matches observation; measuring at the handoff instead would over-shoot.)
  - **Half-applied advancement (plan T2.2 PART B) = confirmed LATENT/moot for HB.** It only manifests on a `qb_refined` seaward move (updates `station_depth_m` but leaves `handoff_depth_m` at target); the guard never fires here, so chosen≈target (mean diff **0.00 m**, ±0.15 m) → ZERO current impact. Still a real correctness bug where the guard DOES fire — keep as a LOW-priority fix, NOT a magnitude lever.
  - **Cause #2 (combined metric, plan T2.3) not exercised today** — one dominant swell (swellDominance 1.0 / 0.6) → §11.3 "dominant only" → no change today. Latent for multi-swell days; implement guarded so it cannot over-shoot.
  - **K-G face convention re-validated (operator-directed):** flat 1.27× H1/10 at the break is correct + handoff-agnostic (L4 vs L2); period dependence lives in SwellTrack. Recorded in `WAVE-BREAKING-CONVERSION-BRIEF.md` Addendum 2026-07-30 + `API-MANUAL.md`. **No face change.**
  - deployed == local == f337648 (clean) confirmed. Trace reverted (drop-in removed, service restarted 22:10:12Z, trace env cleared).
- **Home:** **DOWNGRADED to MEDIUM — magnitude matches current matched-time reality on f337648.** Cause #1 = resolved (clean handoff, trace-verified). Cause #3 = resolved (T3.0). Residual, non-urgent, **NON-2×** items only: (T2.2 PART B) latent half-applied advancement fix; (T2.3) cause #2 combined metric for multi-swell days (guarded). Neither warrants architectural magnitude surgery. **Caveat: validated at ~1 m swell only** — keep checking best_peak vs the contemporaneous cam at LARGER sea states before fully closing.

## TA-C23 — [RESOLVED 2026-07-30, CORRECT PHYSICS] Small short-period secondary swells legitimately produce no distinct break (not a gap)
- **Date:** 2026-07-30 evening. **Severity:** resolved — **correct physics, no code change.** **Surfaced by** the operator's Surfline comparison (primary S groundswell + secondary swells) challenging the coordinator's misleading "single-partition per transect" claim. **Investigated by** faithful replay of the DEPLOYED (f337648) pipeline against the real T0 handoff inputs on the container.
- **Swells are NOT lost.** At the served headline transect (T0 = 2026-07-30T18:00:00Z, transect 11, handoff 2.19 m, face 4.7 ft ✓ matches cam+Surfline primary), SWAN hands off **3 partitions**. Replaying the deployed `run_1d_analytical` on the ACTUAL handed-off set reproduces the served cache **exactly**: dominant **1.30 m @ 14.7 s** → breaks at 1.57 m (Hs 1.146 = γ·d) → 4.7 ft; secondary **0.506 m @ 7 s** → **no break**; tertiary **0.308 m @ 4.6 s** → no break.
- **The 0.506 m / 7 s secondary correctly does not break.** It is too small to reach depth-limited breaking (`Hs/d ≥ γ=0.73` at `depth > 0.3 m`, detector `services/surf_1d_analytical.py:494-511`) on this gentle sandy profile — weak short-period shoaling + bottom friction keep H/d below γ down to where it saturates into shorebreak chop. It is dominated by the 4.7 ft groundswell; recording no distinct break is physically right.
- **Secondaries DO break when big enough — the multi-swell path works.** Scan of the served cache (67 h × 32 transects = 2144 transect-hours): **215 secondary (partition index ≥ 1) breaks recorded** (e.g. a 0.63 m secondary broke at ~2 ft). So the pipeline breaks and records secondaries whenever they cross threshold; this one simply does not.
- **Investigation error (corrected):** the first replay pass pulled the secondary from the WRONG L4 station — the **shallowest/boundary** cell (row 11, secondary 0.663 m), which DOES break. The real handoff clamps to an **interior** station (boundary cell excluded), whose secondary is the smaller 0.506 m. Using the correct station's partitions, the replay matches the cache to full precision (pinned by exact match + elimination: cache per_partition length 3 → a 3-partition row → of rows 9/10/11 only row 9's set yields `[break, None, None]`). Lesson: the handoff is NOT the shallowest L4 cell — it excludes the grid-boundary station and clamps interior.
- **Implication for T2.3:** T2.3 combines only **compatible broken** faces (§11.3: ±3 s period, ±45° dir). It is NOT globally inert — it fires when compatible secondaries break — but it does NOT change THIS spot's headline: even in cases where a 7 s secondary does break, a 15 s + 7 s pair is period-incompatible (Δ≈7–8 s ≫ 3 s) so §11.3 keeps the dominant only. Showing a distinct 7 s secondary swell (as Surfline does) is a separate multi-swell **display** feature, not what T2.3 (combined face height) does. **T2.3 deploy hold (secondary-inertness reason) is LIFTED** — T2.3 is valid on its own merits.
- **Home:** RESOLVED. Today's headline surf height is correct; secondaries are represented when they break; no code change from this concern.

## TA-C22 — [OPEN 2026-07-30, MEDIUM] `modelStatus=degraded_bulk` over-fires for 52% of served hours (one edge transect flags the whole hour)
- **Date:** 2026-07-30. **Severity:** MEDIUM — a truthfulness-signal defect, NOT a face-number error. **Found by** the blind auditor (audit-m1-t31) on a fresh run (start 22:11:22Z, run_time 22:14:03Z, cache 22:51:03Z); **coordinator-reproduced** (`swelltrack` dict: 67 hours, `degraded` = {False: 32, True: 35} = exactly 35/67).
- **Symptom:** served surf `modelStatus` reads `degraded_bulk` for **35/67 hours (52%)** — every hour from **2026-08-01T02:00Z (~hour 32) to the end**. The **near-term/served-now window (18:00Z–01:00Z) is CLEAN** (degraded=False, best_peak 4.7–5.0 ft). Face numbers remain correct at the degraded hours (open/total 32/32; the headline aggregates only over successful transects).
- **Root cause (code-traced):** `services/surf_1d_pipeline.py::_run_pipeline_per_transect` sets `_degraded = bool(bulk_fallback_transects)` — ANY single transect's per-hour bulk-fallback flags the WHOLE hour; `endpoints/surf.py:400 _determine_model_status` → `if pipeline_result.degraded: return "degraded_bulk"`. Trigger = **transect 31 alone** (edge transect) reproducibly lacking its own PT* swell partitions at its handoff (band station idx ~6, depth ~1.5 m) from ~hour 32+. This is the genuine per-transect last-resort — NOT the old shared-CURVE L2-DWR fallback (that path stays bypassed); 31/32 transects are fully SWAN-per-transect-computed those hours.
- **Two fixes (operator decision):** (a) **grade `modelStatus` by fraction degraded** — only `degraded_bulk` when a material fraction (or the best-peak transect) falls back; a single edge transect → `ok`/`partial`. **Data-contract change to `modelStatus` values (trigger 4 — needs approval).** (b) **root-cause transect 31's PT* gap** (why the edge transect has no partitions at its handoff from ~hour 32 — grid-edge / band-index). Non-arch if a bug.
- **Home:** OPEN — surfaced to operator. Near-term forecast unaffected; matters for the 48–72 h tail's trust signal. Relates to TA-C16 (same tail where GFS 3-hourly wind cuts temporal resolution — auditor F3).

## TA-C19 — [DEFERRED by operator 2026-07-30] Dashboard must handle negative `distanceFromShore`
- **Date:** 2026-07-30. **Severity:** LOW (deferred). **Home:** dashboard repo (separate), future task.
- **Detail:** ADR-093 Amendment 4 (TA-C18 fix) makes `breakPoints[].distanceFromShore` able to be **negative** — a break on the beach face landward of the reference waterline at high tide (physically correct; rare, only near/above HAT with small surf). Marine-side consumers all handle negatives (verified in the remediation audit: peel uses `abs` of differences, sorts/serializers are sign-agnostic). `API-MANUAL.md:2057` updated to document it. **Operator decision 2026-07-30: allow negatives; engineer the dashboard to handle it LATER — not now.** The dashboard beach-profile / surf-zone chart (separate repo, unreachable from marine) must be confirmed/updated to render a negative x (distance) sensibly ("at/onshore of shoreline"), not clamp or `abs()`. Until then, negatives simply flow through the API unvalidated.

## TA-C01 — Forensic SWAN workdirs already destroyed before session start
- **Date:** 2026-07-29
- **Severity:** low (plan already has a fallback)
- **Detail:** T0.0 assumed the D2b retry loop would be actively overwriting `/run/weewx-clearskies/swan/level*`
  workdirs and needed to be stopped to preserve the severe-error + tbegc-clamp PRINTs as T0.4 fixtures.
  At session start (~16:20 UTC) the loop had already gone idle (5-min station-resolve tick, no SWAN runs)
  and the level workdirs were **already gone** — `/run/weewx-clearskies/swan/` held only `forecast_cache.json`
  plus a `swan-precleanup-20260726T083936Z/` backup. No severe-error or tbegc PRINT exists on disk anywhere
  (checked /run, /var/run, /tmp, /home/ubuntu). The two `/tmp/swan_repro_l1/` and `/tmp/swash_test/`
  PRINTs are unrelated repro artifacts, not the failed-cycle fixtures.
- **Resolution in-plan:** T0.4 synthesizes the fatal-string fixtures from the diagnosis's verbatim strings
  (`** Severe error : No value for variable YP`, `start time [tbegc] before current time`); the assertion
  against a REAL converged artifact is deferred to T1.2 (first clean run) per the plan. No action needed
  beyond noting that no real failed-cycle PRINT was preserved.
- **Home:** informational; close after T1.2 captures a real converged fixture.

## TA-C02 — [RESOLVED 2026-07-29] Deployed marine.conf is HB-only, not 2-spot
- **RESOLUTION:** Read the deployed marine.conf structure directly: `marine/locations/` has exactly ONE
  entry, `huntington-city-beach-pier` (one pier structure under `surf/structures/0`). Top-level
  `locations: []` is empty/legacy. The `Marine station distances resolved: 2 locations` log line is the
  marine_location_resolver resolving 2 reference stations (NDBC/CO-OPS for wind/tide/buoy) for the ONE
  surf spot — NOT two surf spots. So there is NO Bolsa and NO D6c refuse condition; the M1/T1.2 cold run
  can proceed HB-only with no config change. Closed.
- ~~**Date:** 2026-07-29~~
- ~~**Severity:** medium (blocks the M1 HB-only run if not corrected)~~
- **Detail:** The idle loop logs `Marine station distances resolved: 2 locations` every 5 min. Diagnosis D6c:
  the 2-spot config (HB + Bolsa) enlarges L1 so WW3 station selection finds 0 qualifying stations → every
  cycle refuses (`BoundaryNotViableError`). Track A's M1/M2 validation is **HB-only**. Before the T1.2 cold
  run the deployed config must be confirmed and reduced to HB-only. (`grep` of marine.conf only surfaced a
  `"structures"` block on the first pass — the spot list needs a proper read.)
- **Home:** must be resolved before T1.2 (I will confirm + set HB-only at that point). D6c itself (making
  Bolsa viable) stays a Track C / Phase 5 item — this concern is only about getting to HB-only for M1.

## TA-C09 — [RESOLVED 2026-07-29, in-scope T1.0] L2 DWR OUTPUT gate would freeze open-beach swell under all-stationary
- **Date:** 2026-07-29
- **Severity:** was HIGH (silent frozen-snapshot physics for L3-disabled/open-beach spots) — fixed same session in T1.0 commit `71d70f9`.
- **Detail:** While implementing T1.0's all-stationary quasi-stationary mode, the api-dev agent surfaced (and
  the coordinator verified in code) that the L2 deep-water-reference (DWR) SPECOUT/TABLE patch block in
  `swan_runner.py` (~`:3210-3260`, four `OUTPUT`-clause sites incl. the T4B.4 per-transect variant) decides
  whether to emit its per-hour `OUTPUT ... MIN` clause by **text-scanning the generated L2 INPUT for
  `COMPUTE NONST`** (`_is_compute_nonstat`). The new mode emits `COMPUTE STAT` (never `NONST`), so that scan
  went False and the DWR SPECOUT/TABLE lost their per-hour OUTPUT clause — **freezing the deep-water swell
  spectrum to a single snapshot for every L3-disabled (open-beach) spot**, while the rest of the run stayed
  hourly. This is the SAME class as Fable finding 1, at a site the plan's T1.0 code map did not enumerate
  (which only cited the 8 gates inside `build_swan_input`). It directly reproduces the "flat across all
  forecast hours" symptom the plan exists to eliminate.
- **Resolution (in-scope T1.0, coordinator ruling 2026-07-29):** ruled NOT architectural (ran the 7 triggers
  — no formula/grid/boundary/contract/host/schedule/dependency change; it completes the operator-approved
  time-varying-I/O decoupling at a missed site — a broken implementation of the approved mode, not a new
  architecture). Fixed with a combined `_dwr_output_enabled = (_dwr_is_nonstat or stationary_sequence) and
  _dwr_tbeg is not None` plus a `COMPUTE STAT <t>` timestamp fallback scan; all four OUTPUT-clause sites
  now gate on it. Byte-identical for the nonstationary and plain-fill paths.
- **Verification status:** confirmed by code-read + the agent's extracted-logic test + coordinator generation
  matrix. **Live confirmation deferred to the T1.2 run:** the run's T0.5 trace must show the open-beach DWR
  spectrum VARYING hourly (not frozen). Until that live check, treat the DWR fix as implemented-but-not-
  run-verified.
- **Home:** RESOLVED in code; live-verify at T1.2 (open-beach DWR varies hourly in the trace).

## TA-C13 — [RESOLVED 2026-07-30] Pier structure was INERT (no coordinates in config) → no L3/L4 grid; fixed by injecting real OSM geometry
- **Date:** 2026-07-30. **Severity:** HIGH for the M1 "all four levels" goal; the run itself is clean.
- **Detail:** Run 3 (first honest complete cycle, cycle 2026-07-30T00Z) ran **L1 → L2 → 1D open-beach from L2's
  15 m deep-water reference** — NOT L1→L2→L3→L4. Cause: the deployed grid-sizing (`swan_grid_sizing.json`,
  generated 2026-07-29 15:42, BEFORE this session) has `level3_clusters[0].grid = null` AND
  `level4_clusters[0].grid = null` for HB, with `structure_zone_depth=0.0m` and "0/1 L3 clusters enabled".
  At both config-push time (15:42) and runtime (Run 3), **marine invariant 3 FIRED**:
  "1 structure configured but 0 of 32 transects classified as shadowed" — every transect logs
  `shadowed=False, structures=[]`. The configured pier is not shadowing any transect and not sizing any
  grid, so no L3 (needed as the structure grid's coarse nest) and no L4 (the structure grid) are created.
- **Consequence:** HB — the canonical structure-spot the whole L3/L4 machinery exists for — currently
  models as a plain open beach. M1's literal "SWAN computes all four levels" cannot be demonstrated on the
  deployed config until the structure is made effective.
- **Separate from T1.0:** T1.0 (all-stationary emitter + gate) succeeded — L1 (acc 100%) and L2 (acc 99.7%)
  computed cleanly, gate honest, forecast persisted this cycle. This is an upstream structure-shadow /
  grid-sizing / transect-classification issue (`transect_handoff` shadow test, `grid_sizing_chain` structure
  viability), pre-existing since the 15:42 push.
- **ROOT CAUSE (found 2026-07-30):** the deployed config's HB pier structure carried only the scalar
  `type=pier, material, length_m=566.8, bearing_degrees=221.0, distance_m=124.5` — with **NO `coordinates`
  field**. Per **ADR-095 Decision 3** the model deliberately REFUSES to fabricate an OBSTACLE coordinate line
  from bearing/length/distance ("SWAN structure EXCLUDED … coordinates absent or fewer than 2 points; never
  fabricated from bearing/length/distance"). So the structure was excluded from BOTH the shadow classifier
  (`transect_handoff.compute_transect_shadows` → 0/32 shadowed → invariant 3) AND
  `bathymetry.compute_structure_zone_depth` (no reachable coord → `structure_zone_depth=0.0`), which made
  `swan_domain` log "no manmade structure" and size no L3/L4 grid. **This is a DATA omission, NOT a model
  bug — the model behaved exactly as ADR-095 dictates.** The geometry was dropped somewhere in the
  wizard→api→marine apply path (see TA-C15 for the API-side round-trip defect that would drop it).
- **FIX (2026-07-30, coordinator):** pulled the REAL "Huntington Beach Pier" footprint from OpenStreetMap /
  Overpass (osm_id 45074900, 35-node closed ring) — the ADR-095-sanctioned source, never fabricated.
  Provenance PROVEN: the geometry's derived length 566.8 m / bearing 221.0° / distance 124.5 m match the
  deployed config to the decimal, so discovery originally ran; only the `coordinates`/`geometry` was lost.
  Injected the 35-node `[lon,lat]` ring as `coordinates` and re-pushed via marine `POST /config`.
  Grid-sizing re-ran WITH the structure: `structure_zone_depth=10.3 m` (was 0.0), **L3 enabled 39×38 @ 40 m**,
  **L4 structure grid rotated 221.0°, 10 m, 5292 cells** — both grids non-null. `swan_grid_sizing_4level.json`
  saved. **Not architectural** (ran the 7 triggers — supplying a real, discovery-sourced value into an
  existing optional contract field; no formula/module/boundary/contract/host/schedule/dependency change).
- **Ran (2026-07-30):** service restarted 02:19:44Z; the run reached **L1→L2→L3→L4** (all four level dirs
  present, L4 computing, peak tmpfs ~1.2 GB) — the first true 4-level path for HB. [Per-level convergence to
  be appended on completion.]
- **Residual (non-blocking):** the 1-D handoff shadow classifier (`transect_handoff`) still logs 0/32
  shadowed (invariant 3 fires) even with coordinates — the pier sits upcoast/offshore of the *downcoast*
  transect segment, so for WSW swell it may genuinely shadow none of THAT segment. This did NOT block L3/L4
  (grid sizing uses `swan_domain`, a different path) and the OBSTACLE is emitted into the SWAN run. Whether
  invariant 3 is simply too strict (a configured structure need not shadow the drawn segment) is a separate
  question — log, don't change the invariant without operator sign-off (it's a criterion; possible trigger 1).
- **Secondary:** the open-beach DWR served **48** timesteps, not 72 — traced to the wind-stitch (see TA-C16;
  HRRR-only when GFS was absent/stale). Superseded by the TA-C16 fix.
- **Home:** RESOLVED in data + config (pier now effective, 4-level run reached). Durability of the fix depends
  on TA-C15 (API round-trip) so a future wizard re-save does not re-drop the coordinates.

## TA-C18 — [ROOT-CAUSED 2026-07-29, FIX IN PROGRESS] Surf zeroes out at high tide — the 1-D profile stops ~1 m deep, not at the beach
- **Date:** 2026-07-29. **Severity:** HIGH — the served forecast is wrong across half the tide cycle.
- **Detail:** Once the per-transect L4 handoff actually reached D1 (TA-C17 fix, d803d9c), the re-run showed the
  whole spot dropping to `best_peak=0.00 m / spot_avg=0.00 m / peel=nan` whenever tide ≳ **+0.5 m** (sharp
  cliff: 0.49 m works, 0.55 m all-zero); at low/mid tide surf is sane (~1.2–1.55 m ≈ 4–5 ft). **Masked before
  the TA-C17 fix** because every hour fell back to the deep (~15 m) scalar handoff, which is not tide-sensitive.
- **ROOT CAUSE (confirmed against the deployed cache + grids, NOT the earlier handoff-depth hypothesis):** the
  hypothesis about `1.3·Hs/γ` pushing the breaking point onto a dry cell was WRONG. The real cause is the
  **1-D transect bathymetry profile stops ~1 m deep instead of reaching the beach.** Two compounding facts:
  1. Each per-transect profile anchors at its **SWAN sampling-band origin** (`_band_ray_origin`, shared with
     the per-transect POINTS bands), which sits ~1 m *seaward* of the true waterline because SWAN deliberately
     stops before the swash. The cached per-transect profiles for HB begin at depth **1.01–2.83 m** at
     `distance_from_shore=0`; the shared per-spot profile (anchored at the true shoreline) begins at **0.00 m**.
     Both are sampled from the SAME grid via the SAME `extract_native_profile_from_grid()` — the difference is
     purely the anchor. (So the operator's "1-D should be independent of SWAN except at handoff" instinct was
     right: the profile imports SWAN's offshore band origin as its own shoreward start.)
  2. The sampler then deletes the subaerial beach twice: `_grid_depth_below_msl()` returns `max(0.0, -elev)`
     (clamps land to depth 0), then a `depth_m > 0` filter (`providers/nearshore/swan.py`,
     `endpoints/beach_profile.py`) drops those zeros. The DEM HAS land up to **+15.1 m** (L4/L3 nest) — we were
     deleting the beach, not lacking it.
  3. `run_1d_analytical` adds tide to every depth. With the profile floored ~1 m deep and the beach face gone,
     a rising tide lifts the shallowest modeled point above breaking depth (`Hs/γ`) → no break points → zero.
     Sharp cliff because all open transects share a similar shoreward floor.
- **FIX (approved — ADR-093 Amendment 4, 2026-07-29):** define the 1-D model's **landward boundary** (left
  open by every prior amendment) as the **Highest Astronomical Tide (HAT)**, a fixed number computed **once at
  setup**: `E_landward = HAT`, DEM datum. HAT is taken as the max of the SAME CO-OPS harmonic predictions
  already feeding `tide_level` (`coops_station_ids[0]`, `swan.py:2397`) — no surge term, no wave term (surf
  model, not flood model; nobody surfs the storm). Decouple each transect to its OWN shoreline
  (`find_shoreline_from_grid`), sample **signed** depth (land negative), drop the `depth_m>0` filter, and extend
  each profile up its own beach face to `E_landward = HAT`. The existing `max(seabed+tide,0.01)` clamp does
  per-hour wet/dry. Setup-time WARN guard if topobathy can't reach HAT (never a silent cap). Seaward handoff
  (L4/L2) and all physics formulas UNCHANGED.
- **Home:** implementation dispatched against Amendment 4 (2026-07-29); coordinator to QC + deploy + verify a
  real run shows sane surf across the full tide cycle before closing. Blocks QC Gate 1 / M1.

## TA-C17 — [FIXED + VERIFIED 2026-07-30, commit d803d9c] L3/L4 never reached the served surf — per-transect handoff was gated behind a single-line pick that fails on the L4 grid
- **Date:** 2026-07-30. **Severity:** HIGH — defeated the entire purpose of the L3/L4 structure path.
- **Symptom:** In the first full 4-level run, the 1-D surf model (`run_pipeline`/SwellTrack, "D1") ran all 67
  hours but every hour logged "no handoff_by_transect for this timestep — falling back to the scalar handoff
  depth" with "32 transects (32 open)". So the L4 structure grid computed but did NOT reach the forecast; D1
  ran open-water-equivalent (near-term best_peak ~1.55 m ≈ ~5 ft face).
- **ROOT CAUSE (confirmed, not the earlier speculation):** in `swan_runner.py` `_parse_output()`'s per-spot
  loop, the single-diagnostic-CURVE ("spot-level") handoff pick `_select_l3_handoff_spectra()` ran FIRST and
  the loop `continue`d out of the whole spot when it returned empty — which also skipped the per-transect
  handoff block below. AND that block only had a container to write into (`self._spectral_results[spot_id]`)
  when the single-line pick had populated one. So an empty single-line pick discarded every transect's own
  per-transect handoff, and D1 fell back to the scalar L2 handoff for all transects.
  - Why the single-line pick was empty (0/67): the diagnostic CURVE is drawn LONGER than the small rotated L4
    structure grid, so its fixed offshore sample station (`_hs_proxy_idx = 1`) falls **OUTSIDE the grid
    rectangle** — SWAN returns its out-of-grid marker (`DEPTH=-99, HSIGN=-9`), which is the SAME sentinel as
    a dry cell. **CORRECTION:** an earlier note in this session called those "dry/off-grid cells" — there is
    NO land offshore of HB; they are simply points beyond the L4 grid's edge (first CURVE point sits ~970 m
    out along a grid axis only ~480 m long). Not a physics/land issue — a fragile line-sampling design.
  - The per-transect path was NEVER the problem: each transect reads its OWN in-grid TABLE_PT_* column via
    `_select_l3_handoff_position_and_spectrum()` and does not need the single-line pick. It was simply gated
    behind it. (My earlier "maybe the transects correctly see open beach" reading was WRONG and contradicted
    PROVIDER-MANUAL §14.15 "the handoff is per transect, not per spot" — the operator corrected it.)
- **FIX (d803d9c, deployed):** the per-transect block now runs whenever the spot has transects, independent
  of the single-line pick. Non-empty single-line pick → byte-identical to before. Empty → build a minimal
  carrier list `{time, handoff_by_transect}` from the union of the per-transect tables' own timesteps and
  publish it to `self._spectral_results[spot_id]`, so the per-transect handoff reaches
  `resolve_handoff_by_transect()`/the 1-D pipeline. The single-line pick is now a diagnostic, not a gate.
  `_select_l3_handoff_spectra` internals / `_hs_proxy_idx` and the per-transect selector are UNTOUCHED (the
  fix sidesteps the in-code-flagged Hs-proxy decision). Known-answer test
  `tests/test_swan_per_transect_handoff_decouple.py` (fails pre-fix, passes post-fix). **Not architectural**
  (restores documented §14.15 behavior; no formula/boundary/contract/grid change).
- **VERIFIED (re-run 2026-07-30, restart 04:38:30Z, complete 05:20:53):** 32/32 transects resolve their own
  L4 handoff, 0% clamp, 6–14 structure-affected transects per hour (was flat 32-open). NO "no
  handoff_by_transect" fallback. Confirmed via journal ("32/32 transect(s) resolved per-hour"; "single-line
  handoff pick was empty, but per-transect handoff produced 73 timesteps" = the carrier path). **But the
  re-run also surfaced TA-C18 (surf zeroes at high tide) — the residual per-transect-path issue predicted here.**
- **Follow-up (minor, separate):** the diagnostic CURVE is drawn longer than the L4 grid so its offshore end
  pokes outside — harmless now that it's not a gate, but worth tidying (size the CURVE to the grid).
- **Home:** code FIXED; close after the live re-run confirms per-transect handoff reaches the forecast.

## TA-C16 — [RESOLVED 2026-07-30, commit a68215d] HRRR+GFS wind stitch non-monotonic when GFS cycle ≠ forecast cycle
- **Date:** 2026-07-30. **Severity:** HIGH (hard SWAN fatal → no forecast) whenever GFS runs a different cycle
  than the forecast — which is the COMMON case shortly after a synoptic hour (GFS lags ~4.5 h, so a 00Z
  forecast started before ~04:30Z falls back to GFS 18Z).
- **Detail:** `swan_runner.SWANRunner._stitch_wind()` blended HRRR (0–48 h hourly) + GFS (48–72 h, 3-hourly →
  hourly) with `combined_grids = hrrr_grids + interpolated_gfs`, ASSUMING the first GFS grid's `valid_time`
  equals HRRR's last (forecast hour 48). But `providers/wind/gfs.py` fetches forecast hours 48–72 relative to
  GFS's OWN most-recent cycle (`_compute_gfs_cycle`), so `valid_time = gfs_cycle + forecast_hour`. With GFS
  18Z for a 00Z forecast, GFS f048 lands at 18:00 next day = forecast hour 42 — BEFORE the HRRR end. The
  concatenated list then jumps backward in time. T1.0's all-stationary emitter writes one `COMPUTE STAT
  <time>` per `valid_time` in list order, and SWAN aborts: `** Error : [time] before current time`. (The
  prior nonstationary range-based COMPUTE masked it; the per-time sequence exposes it. Open-beach Run 3 never
  hit it because GFS was absent → HRRR-only, monotonic. This is also the real cause of TA-C13's "48 not 72
  timesteps" secondary note.) The hardened convergence gate CORRECTLY caught the fatal — that's how it was found.
- **Resolution:** reconcile by ABSOLUTE `valid_time` — keep only interpolated-GFS grids strictly after HRRR's
  last time (HRRR wins overlap), then sort + de-dup so the combined sequence is guaranteed strictly
  increasing. No change to the GFS interpolation math, fetch logic, the 0-48/48-72 split, or the return
  shape. **Not architectural** (enforces the pre-existing "wind grids strictly monotonic in time" invariant;
  ran the 7 triggers, none hit). Known-answer test `tests/services/test_stitch_wind_monotonic.py` (4 cases:
  mismatched-cycle monotonic/no-dup/HRRR-wins/honest-coverage + aligned-cycle 73-grid happy path). 37/37 gate
  + stitch tests pass. Committed `a68215d`, pushed, deployed (running commit `a68215d`).
- **Coverage caveat (honest, worth operator awareness):** when GFS is a stale cycle, the forecast legitimately
  ends before hour 72 (e.g. GFS 18Z reaches only forecast hour 66) — the fix does NOT fabricate a tail. If a
  full 72 h is contractually required (C-77), the real fix is upstream: fetch GFS forecast hours computed
  from the FORECAST cycle offset (so a stale GFS cycle still supplies absolute hours 48–72), or wait for the
  matching GFS cycle. Logged as a follow-up; the monotonic fix is the correct immediate unblock.
- **Home:** RESOLVED (monotonicity). Follow-up: GFS-cycle-offset hour selection for full-72h coverage.

## TA-C15 — [FIXED in code 2026-07-30, commit 9d1c10a; deploy + api.conf patch pending] API StructureConfig cannot decode JSON-string coordinates its own writer produces
- **Date:** 2026-07-30. **Severity:** HIGH for durability — the latent bug that makes TA-C13 recur on any
  wizard re-save; silent (drops geometry / fails config load).
- **Detail:** In the API repo, the apply writer `endpoints/setup.py` (~:1317) persists structure
  `coordinates` to api.conf as a **JSON string** (`json.dumps(...)`) because configobj cannot round-trip a
  native nested `[[lon,lat],...]` list. But `config/marine_config.py` `StructureConfig.__init__` (~:313) read
  it by iterating the value directly (`[float(c[0]), float(c[1])] for c in section.get("coordinates", [])`),
  so `load_marine_config()` walked the raw string character-by-character and raised on `float('[')`. The
  MARINE service's `StructureConfig` already had the `isinstance(str) → json.loads` decode; the API's did
  not. Net effect: a structure with a discovered coordinate outline (exactly what SWAN's OBSTACLE / L3-L4
  grid needs) could never survive an API-side config round-trip — which is how the deployed config ended up
  with the pier's scalars but no `coordinates` (TA-C13).
- **Resolution (code):** added `import json` + the `isinstance(raw_coords, str) → json.loads` branch,
  mirroring the marine reader. Native-list payloads unchanged; empty/absent → `[]`. Verified: configobj
  auto-quotes the JSON string and reads it back as a single `str` (empirically confirmed), so the decode
  engages. Known-answer test `tests/test_marine_config_structure_coordinates.py` (JSON-string, native-list,
  empty, full write-through-configobj round-trip). 4/4 pass. Committed `9d1c10a`, pushed. **Not
  architectural** (fixes read/write contract divergence).
- **Durability DONE (2026-07-30, operator go-ahead "proceed"):** the clearskies-api runs on the **weewx**
  container (port 8765), api.conf at `/etc/weewx-clearskies/api.conf` on WEEWX. Confirmed the live weewx
  api.conf HB pier structure had the same scalars and NO coordinates — i.e. it IS the source that produced
  the coordinate-less marine config (the 08:41 vs 15:42 timestamp gap is apply-vs-regrid timing; structure
  content matches). Steps done: (1) deployed `9d1c10a` to weewx via `scripts/deploy-api.sh` (health 200);
  (2) inserted the real 35-node `coordinates` JSON string into the weewx api.conf structure via a minimal
  text patch run as the `clearskies` user (ownership preserved, no chown; backup at
  `api.conf.bak-precoords`); (3) VERIFIED `load_marine_config(ConfigObj(api.conf))` parses the structure to
  the 35-node closed ring (decode engaged, no raise); (4) restarted the API to load it. So a future wizard
  apply now has the coordinates in api.conf to re-push.
- **Still OPEN (broader):** whether the dashboard/wizard apply payload actually CARRIES the discovered
  `geometry`→`coordinates` (the ORIGINAL drop point). The api.conf patch + reader fix make coordinates
  round-trip once present; if the wizard form does not send them on a fresh apply, a future "save" that
  re-derives structures from the form could still omit them. Confirm the wizard sends coordinates (dashboard
  discover-structures → apply payload) — separate frontend investigation.
- **Broader:** the ORIGINAL point where geometry was dropped (dashboard/wizard apply payload not carrying the
  discovered `geometry`→`coordinates`, or the operator entering the structure without discovery) is not yet
  pinned. TA-C15's read-fix makes coordinates round-trip once present; confirm the wizard actually SENDS them.
- **Home:** code FIXED + pushed; deploy + api.conf patch + wizard-send verification OPEN.

## TA-C14 — [OPEN 2026-07-30] Forced-full-run on an unchanged HRRR cycle silently no-ops and falsely reports success
- **Date:** 2026-07-30. **Severity:** medium (masks a real "no run happened"; defeats the retry-on-failure design).
- **Detail:** After a geometry-changing config push, `grid_sizing_chain` sets `force_full_run_signal` and the
  runner loop (`service.py _marine_runner_loop`) forces a full run bypassing the cycle-unchanged gate. But
  `run_all_spots()`/`_run_all_spots_locked()` has its OWN silent early-returns (DEBUG-level, invisible in the
  INFO journal) that were NOT bypassed for the forced path. Observed 2026-07-30 02:00:14: the forced run for
  the SAME HRRR cycle (00Z) as the just-completed open-beach run logged "starting full SWAN cycle" →
  "forced full run succeeded" → "full SWAN cycle complete" all within ~1 ms, with ZERO run logs and no SWAN
  subprocess and no rebuilt level dirs (tmpfs had only the prior cache). Because the inner return raises
  nothing, the loop treated it as SUCCESS and CLEARED `force_full_run_signal` — so the retry-on-failure
  guard (which relies on an EXCEPTION to leave the signal set) was defeated; the forced run was silently lost.
- **Workaround used:** a plain `systemctl restart` reliably does a full run (fresh start, `last_hrrr_cycle=None`) —
  that is how the 4-level run (TA-C13 fix) was actually triggered.
- **To fix:** either (a) have the forced-full-run path bypass/So-not-share the inner per-cycle/no-op early
  returns, or (b) make a no-op forced run NOT clear the signal (only clear on a genuinely-executed run), or
  (c) raise a distinguishable "nothing ran" result the loop can detect. Confirm which inner early-return
  fired (the config parses fine — surf_spots present, both bboxes valid, structure has 35 coords — so it is
  NOT the top-of-function config guards; likely the same-cycle dedup or a state check). Needs a targeted read
  of `_run_all_spots_locked`'s per-cycle dedup + a known-answer test that a forced run on an unchanged cycle
  actually executes.
- **Home:** OPEN — real defect (silent-success on a run that did nothing), but non-blocking given the restart
  workaround. Prioritise before relying on config-push-triggered runs in production.

## TA-C12 — [OPEN, pre-existing, DEFERRED] Convergence-gate valid-fraction pools across tables/spots (spatial masking)
- **Date:** 2026-07-30
- **Severity:** medium; NOT reachable-problematic for single-spot (HB) M1; pre-existing (predates the 2026-07-30 gate work).
- **Detail:** `_check_convergence` Check 3 (stationary) pools all discovered TABLE files' points into one
  `simple_valid/simple_total` and gates on ≥50%. One badly-failing spot/transect can be masked by several
  good ones summing ≥50% — the SPATIAL analogue of the per-solve temporal masking fixed in `5d2618a`. The
  old code already pooled (across `TABLE_{n}.txt`); the 2026-07-30 HEAD-based table discovery (`495f49f`)
  makes multi-table pooling actually reachable for L2/L3/L4 where the name-guess may not have found them.
  Surfaced by the blind auditor on `495f49f` (explicitly NOT counted against that commit's claim — pre-existing).
- **Why deferred:** M1 is HB-only (one spot); the masking needs multiple spots/tables to bite meaningfully.
  Proper fix (per-table or per-spot minimum valid-fraction, mirroring the per-solve min) belongs with the
  multi-spot path, not the M1 unblock. Log now, fix when multi-spot is live.
- **Home:** OPEN, tracked; revisit at multi-spot enablement (Track C / Phase 5) or if a real spot's garbage output is masked.

## TA-C11b — [follow-up at Run 3] spot-check a REAL L3/L4 TABLE HSIGN header vs the gate's token match
- **Date:** 2026-07-30. **Severity:** low (verification completeness).
- **Detail:** The `495f49f` blind audit ruled out the `any_hs_column`/HSIGN-token attack classes but could NOT
  inspect a real L3/L4 `TABLE_{n}.txt` HSIGN header (no live L3/L4 run dir existed yet) — it reasoned from
  `swan_formats.py` generation code + the analogous real L2 header. When a full run produces real L3/L4
  TABLE files, confirm the plain `HSIGN` column header tokenises to an exact `HSIG`/`HSIGN`/`HS` match (so
  the valid-fraction check actually engages for L3/L4, as intended).
- **Home:** close on the first full L3/L4 run (Run 3+).

## TA-C04 — T0.5 band cutoffs can't separate the real 18 s + 16 s swells; plan prose 16s→12s
- **Date:** 2026-07-29
- **Severity:** low (does not affect the trace's usefulness; matters only for how sub-task F is read)
- **Detail:** `summarize_spectrum`'s three period bands are long ≥14 s, mid 10–14 s, short <10 s. The REAL
  reality baseline has swells at 18 s, 16 s, 10 s — so 18 s AND 16 s BOTH land in the "long" band, and
  the band summary alone cannot distinguish them (long.peak_dir_deg reports whichever is stronger).
  Consequence for sub-task F readout: do NOT rely on the 3-band summary alone to count trains — use the
  full `energy` matrix + `energy_by_freq` marginal + `peak_period_s`, which preserve all peaks. The band
  summary is a convenience, the matrix is ground truth (T0.5 emits both). Separately, the plan's T0.5
  Accept prose gives example test periods "18 s / 16 s / 10 s" but 16 s is in the code's long band, not
  mid — the unit test correctly uses 18/12/8 s (each in its own band). Plan prose could be corrected
  16s→12s for future readers; left to operator (not editing the approved spec mid-run).
- **Home:** informational for sub-task F readout; optional plan-prose fix.

## TA-C05 — L3→L4 nest handoff not spectrally traced (finer bisection, if ever needed)
- **Date:** 2026-07-29
- **Severity:** very low (not needed for the stated diagnosis)
- **Detail:** T0.5 sub-task E instruments L1→L2 and L2→L3 nest copies (spec_l1_nestout, spec_l2_nestout)
  but not the L3→L4 copy, per the plan's stage list (no spec_l3_nestout named; L3→L4 is captured by
  spec_l4_handoff, sub-task D). The plan's collapse hypothesis is upstream of the 15 m DWR point, which
  is fully traced. If sub-task F's readout unexpectedly shows the collapse happening between l2_nestout
  and the l3/l4 handoff, add a spec_l3_nestout trace at the L3→L4 shutil.copy2 (swan_runner.py ~4033) to
  split L3-compute from L4-compute. Not needed otherwise.
- **Home:** conditional follow-on to sub-task F.

## TA-C07 — [RESOLVED 2026-07-29 → ALL-STATIONARY] L1 (all levels) CFL-unstable: nonstationary higher-order scheme
- **RESOLUTION (operator, in chat):** go **ALL-STATIONARY** (quasi-stationary: MODE NONSTATIONARY +
  per-hour COMPUTE STAT sequence at all four levels, SORDUP scheme, no CFL anywhere), + directional
  resolution 36→72 + `NUMERIC alfa` under-relaxation + mandatory COLDSTART. HYBRID (L1/L2 nonstationary)
  retained as a documented fallback if accuracy is insufficient. Full contract: plan `#### T1.0` + the
  ledger entry. **CFL-reasoning correction (Fable review):** the trigger is the spectral grid's 0.03 Hz
  lowest-frequency bin at GROUP velocity (cg≈26 m/s → CFL≈15 on L1), deterministic every run — NOT the
  phase-speed-of-observed-swell reasoning originally written below (which got the right L1 number by luck
  and the L4 estimate 2–4× wrong). Moot under all-stationary. Options list below is superseded by the
  all-stationary decision; kept for the fallback record only.
- ~~[BLOCKER — OPERATOR DECISION REQUIRED]~~
- **Date:** 2026-07-29
- **Severity:** BLOCKS M1. Architectural (trigger 1 — numerical scheme). Surfaced to operator.
- **What:** After deploying all Phase 0 + T1.1 fixes (verified) and running a cold full 12Z cycle with the
  HARDENED gate live, the cycle failed at **L1** — honestly (gate caught `check=print_fatal: 'not possible
  to compute, first iteration'`; no false pass, no degraded publish). Root cause is **NOT D1**: T1.1's
  OBSTACLE wrap works (no line >180 chars in any INPUT). The real blocker is a SWAN **CFL / propagation-
  scheme** error at every timestep:
  `** Error: inadvisable to use the higher order scheme for nonstationary computation with CFL greater
  than 10. Consider using PROP BSBT... for smaller domains use MODE NONSTAT with multiple COMP STAT.`
- **Why it happens:** No `PROP` command is ever emitted (git -S 'PROP' empty; confirmed) → SWAN uses its
  DEFAULT higher-order nonstationary scheme, which is CFL-limited. `compute_dt_min=10` (default, all grids).
  L1 = ~28×20 km / 1 km cells; for long-period swell (T≈15-18s, c≈23 m/s) CFL = c·dt/dx ≈ 23·600/1024 ≈ 13
  > 10 → "not possible to compute" every step. Inner grids (L4 = 10 m cells) would be FAR worse under
  nonstationary (CFL ~ hundreds), so this is a nested-config issue, not just an L1 dt tweak.
- **Implication (load-bearing):** L1 produces no TABLE, so the OLD vacuous gate passed it by absence —
  **L1 nonstationary NEVER actually computed.** The prior "L2→D1 gave 4.6–5.0 ft" baseline the plan rests
  on was very likely a WARM-START ARTIFACT, not a real computation. This is exactly the prime-directive
  failure class; the hardened gate exposed it. The plan/diagnosis assumed D1 was the sole compute blocker.
- **Options (all architectural — operator picks):**
  (a) `PROP BSBT` — first-order upwind, unconditionally stable; standard for operational nonstationary
      SWAN, BUT diffusive (smears/under-predicts the wave field). Likely the intended fix.
  (b) Much smaller `compute_dt_min` to hold CFL<~2 for the higher-order scheme — 5–30× more compute, and
      inner fine grids may still be CFL-bound.
  (c) Run inner grids STATIONARY (SWAN advises COMP STAT for <100km domains); outer nonstationary. Changes
      the nested time-integration design.
  (d) MODE NONSTAT + multiple COMP STAT (quasi-stationary).
- **Coordinator recommendation:** needs a deliberate decision on scheme + per-grid stationary/nonstationary
  + dt — possibly a short research brief on correct nonstationary-nested SWAN config — NOT a coordinator
  guess (this is precisely the 2026-07-25 Battjes-Janssen failure mode the HARD BLOCK exists to prevent).
- **State:** service STOPPED (dev), trace reverted, forensics preserved (scratchpad M1FAIL_level1_PRINT.txt;
  trace at librewxr:/var/log/weewx-clearskies/marine-trace-20260729.jsonl has WW3-raw + L1-boundary spectra).
- **Home:** OPEN — blocks M1 until operator decides the numerics.

## TA-C08 — trace file 126 MB for a partial cycle (full-matrix spectra); prod-hygiene
- **Date:** 2026-07-29. **Severity:** low. The T0.5 trace with include_matrix wrote 126 MB in a partial
  12Z cycle. Fine as a gated diagnostic (reverted after use per sub-task F), but if ever left on in prod it
  would fill the disk fast. Consider size cap / include_matrix=False default if productionized. Informational.

## TA-C06 — [REMEDIATED 2026-07-29] QC Gate 0 found the hardened gate still passed nothing-runs
- **Date:** 2026-07-29
- **Severity:** was HIGH — remediated same session (T0.1b, commit 76ced7f)
- **Detail:** The blind adversarial QC Gate 0 audit defeated the T0.1-hardened `_check_convergence` two
  ways: (1) a completely empty run-dir (no PRINT) returned True — all checks passed by absence; (2) the
  four fatal-string checks were literal substring matches, evaded by a tab / double-space / bare "tbegc"
  (no brackets, no "before current time" phrase) — the same literal-substring class the file's own
  history was burned by (COMPUTE NONSTAT vs NONST, swan_runner.py:1331 comment). Both let a
  never-started / crashed / clamped run report "converged."
- **Remediation (76ced7f, non-architectural — restores the gate's own contract):** missing PRINT now
  FAILs (check=print_missing); the fatal scan collapses internal whitespace before matching and matches
  the bare "tbegc" token. Verified: auditor's exact repros all return False, 24/24 regression green.
  Guard cases + a blind auditor re-attack in flight (T0.4b + re-audit).
- **Second-pass re-audit (blind, on 76ced7f) found 3 NEW defeats, same negative-scan root cause:**
  1. **Unreadable-but-present PRINT** (PRINT is a dir / no read perm → OSError) falls through to a pass —
     the sibling of the missing-PRINT case I fixed. **BEING FIXED NOW** (OSError → FAIL, check=print_unreadable):
     safe, no SWAN-format knowledge, a real PRINT is always readable so no false-fail risk.
  2. **Fatal phrase wrapped across two PRINT lines** (Fortran line-wrap) evades the per-line whitespace
     collapse. Auditor concedes SWAN emits these on ONE line in practice → low reachability. **DEFERRED.**
  3. **Empty / truncated PRINT with no positive completion assertion.** Root cause: the gate only scans
     NEGATIVELY (fail if a failure string is present); for L1/L2 (no TABLE by design) ANY PRINT lacking the
     four fatal phrases passes, including an empty one. **DEFERRED — proper fix is a POSITIVE
     completion-marker check** ("SWAN ... finished"/"is ending" — exact marker per SWAN 41.51AB), which
     MUST be validated against a REAL converged PRINT (T1.2) or it false-fails all of M1. Mitigant already
     in place: a process killed mid-run exits non-zero → run method raises SWANRunError (swan_runner.py
     :5108) BEFORE _check_convergence, so the live reachability of an empty PRINT is low.
- **RECOMMENDED FOLLOW-ON (tie to T1.2):** when the first real converged PRINT exists, capture SWAN's exact
  completion marker and add a positive "level actually finished" assertion to _check_convergence (flips the
  gate from negative-scan to positive-assertion, closing #2 and #3 together). This is the plan's own
  test_converged_passes_real hook. Do NOT guess the marker before a real PRINT is in hand.
- **Home:** #1 fixed this session; #2/#3 deferred to the T1.2-validated positive-completion follow-on.

## TA-C03 — reference/clearskies-dev.md services table is stale (pre-marine-separation)
- **Date:** 2026-07-29
- **Severity:** low (doc drift, already listed in plan Phase 5)
- **Detail:** `reference/clearskies-dev.md` §"librewxr" still documents `weewx-clearskies-swan.service`
  (8767) and `weewx-clearskies-compute.service` (8770) running from the API repo's venv. The live system
  is the unified `weewx-clearskies-marine.service` (8780) running from `repos/weewx-clearskies-marine/`
  with its own venv (per deploy-marine.sh / ADR-099). Plan Phase 5 "Doc drift" already tracks the 8767/8770
  → 8780 change; recording here so the SWAN/surf test-host guidance in that file is read with the
  correction that tests run from the **marine** repo's venv, not the API repo's.
- **Home:** plan Phase 5 doc-drift item (already tracked).
