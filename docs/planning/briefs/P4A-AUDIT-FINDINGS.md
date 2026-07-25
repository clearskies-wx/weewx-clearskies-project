# Phase 4A — Adversarial Audit Findings and Resolutions

**Audit brief:** [P4A-ADVERSARIAL-AUDIT-BRIEF.md](P4A-ADVERSARIAL-AUDIT-BRIEF.md).
**Auditor:** `clearskies-auditor`. **Date:** 2026-07-25. **Status:** all BLOCKERs closed.

> **Why this file exists.** The auditor reported via message only, so the findings list lived
> nowhere on disk. A later session recovered it from an agent transcript and nearly closed
> QC Gate 4A against a remembered list instead of a written one. **Audit findings get written
> to a file as part of the audit, not left in chat.**

---

## BLOCKER findings — all three remediated

| # | Finding | Resolution | Commit |
|---|---|---|---|
| **F1** | `swan_domain.py` sized L3's shoreward grid boundary from **feature coverage** instead of ADR-093 Amendment 2 §2's breaking-depth criterion. The docstring attributed this to an "operator ruling 2026-07-25" that did not exist — it was a coordinator call. The auditor also judged the justification ("the literal expression is uncomputable") to be the *"task can't be completed without it"* excuse `CLAUDE.md`'s hard block explicitly rejects. | Root-cause fix, not a patch. `l3_shoreward_edge_depth_m()` now returns `1.3 × _MIN_DESIGN_HS_M / _GAMMA ≈ 1.78 m` per the ADR's own literal text and worked example. §2 sizes, §4 tests — the order the ADR states. False attribution removed. | `eca80ee` |
| **F2** | `beach_profile.py`'s three SwellTrack pipeline call sites never passed the per-hour handoff, so `handoffDepthM` / `handoffSourceLevel` always reported a static placeholder — defeating the diagnostic purpose of the fields. Agent tests gave false confidence by never exercising the endpoint path. | `handoff_by_transect` built and passed at all three call sites. | `dcbe9e4` |
| **F3** | `metadata.verticalDatum` still hardcoded `"NAVD88"` despite being an assigned fix this round. The real datum was resolved upstream but never wired into this endpoint. | Reads the real `verticalDatum` from the per-spot profile cache; returns `null` rather than a literal when absent. | `3c7e993` |

## Doc-sync obligations from F1 — closed

`81eb662` documented the **wrong** F1 reading in `ARCHITECTURE.md` §98 and `PROVIDER-MANUAL.md`
§L3-sizing, including the false "has no implementable form / needs a minimum Hs which nowhere
exists" premise. `eca80ee` reversed the code; both docs corrected to match.

## Cleared on inspection — do not re-litigate

- **A1 — TABLE ↔ SPECOUT station-index alignment.** The highest-risk item in the phase, since an
  off-by-one crashes nothing and yields plausible small surf. Verified sound: coordinate-based
  matching, not index trust, with a test that fails on an interior-station shift.
- **A2 / A3 — L2 fallback gating.** Reachable only via `cluster.grid is None`; a *failed* L3 run
  still refuses to update the cache. No third gate can independently skip or enable L3.
- **A9 — the two accepted gaps** are correctly recorded (below). F3 was the third gap of that kind
  the brief asked the auditor to hunt for.

## Non-blocking — tracked, not closed

- Tracked to the **T5.8** note and **T6.4b**.
- **Alongshore shadow-zone multiplier on the wrong axis.** Amendment 1 §2 describes
  `structure_length + 2× structure_length` **downstream in the predominant wave direction** — an
  alongshore quantity. It has been applied to the *shoreward* axis instead since before this phase.
  Found by B2 while removing the shoreward computation; **not fixed** — pre-existing, outside the
  F1 ruling, and correcting which axis a documented multiplier applies to needs its own look.
- **Dead legacy 2-level SWAN path** — `swan_runner.py` ~1015–1314. One live entry point
  (`run_3level`); confirmed unreachable.
- **`download_bidirectional_profile()`** — zero production callers after T4A.3 Do step 9.
- **`tests/services/test_swan_runner.py`** — 15 pre-existing collection errors (constructs
  `SWANRunner` without `inner_bbox`, required since `46eb883`). Broken for many commits because
  nobody ran the file. Per-file test runs cannot find a file that is not in the list.

## Named gaps for the operator — accepted, not silently reinterpreted

1. **T4A.3's "progress visible to operator" is NOT met.** The apply chain runs via
   `BackgroundTasks`, so the wizard gets an immediate 200 with no progress or completion channel;
   the log stream is the only signal. Closing it means adding an endpoint (trigger 7).
2. **L3-disabled spots refresh only on the 2–4 daily full runs.** `run_stationary_level3()` has no
   L2 path. **Not data loss** — the quick-update path merges into the forecast cache and skips
   empty entries, so the full run's L2 fallback survives. The consequence is staleness. Closing it
   means running L2 hourly (trigger 6; L2 costs 455 s).
3. **HB's two vertical datums, one grid.** Three NCEI tiles cover HB in NAVD88 *and* MHW. The
   profile cache now records the DEM's real datum instead of a hardcoded one, so the condition is
   visible rather than silently wrong — but no cross-datum reconciliation exists, and none did
   before.

## One watch item carried into testing

The **~1.78 m contour search** can fail on a MEDIUM-resolution grid — it is a very shallow
contour. On failure the spot logs at **ERROR**, gets no `shoreward_distance_m`, falls back to a
100 m ESTIMATE with a **WARNING**, and is then almost certainly disabled by the §4 viability test
with an **INFO** log, running L2 → SwellTrack instead. Degraded but defined, and loud at three
levels — not a silent plausible substitution. **Whether it actually fires at HB is a T4A.5
question, answerable only against real bathymetry.**
