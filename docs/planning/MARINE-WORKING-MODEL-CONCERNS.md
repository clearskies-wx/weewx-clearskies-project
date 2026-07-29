# Track A Execution — Out-of-Scope Concerns Log (2026-07-29)

Findings surfaced while executing Track A of `MARINE-WORKING-MODEL-PLAN.md` that are **outside the
scope of the current task** and deferred for later operator/coordinator attention. In-scope defects
are fixed under their task; this file is only for things the plan does not already cover.

Format: `TA-Cnn` | date | severity | title | detail | suggested home.

---

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
