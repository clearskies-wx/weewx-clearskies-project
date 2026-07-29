# Marine Working-Model Plan — get a real, validated surf forecast (2026-07-29)

**Status:** DRAFT — Track A + Track B specified to the line; both SWAN-obstacle and bathymetry-structures
research briefs are in hand; reviewed by a Fable agent 2026-07-29 and its 17 findings incorporated
(see Decision log). Track B still gated on operator sign-off of its architectural items.
**Created:** 2026-07-29
**Origin:** `docs/planning/briefs/MARINE-DIAGNOSIS-2026-07-29.md` (Fable diagnosis, D1–D7) + operator
design discussion 2026-07-29. Structural template: `docs/archive/MARINE-COMPLETE-REMEDIATION-PLAN.md`.
**Supersedes:** `MARINE-L4-DEGRADED-HANDOFF-2026-07-29.md`, and — per operator 2026-07-29 — most of
`MARINE-MODEL-RESTORATION-CONCERNS.md` (superseded by the diagnosis; only the C-E items explicitly
carried into Phase 5 survive).

**NOTE TO ALL IMPLEMENTING AGENTS:** This plan tells you the file, the line, the current code, and the
exact change. **You are here to CODE, not to design.** Do not restructure, do not "improve," do not
choose an approach — the approach is written below. If a change you are told to make trips the
architectural block (see `rules/agents.md` → "Architectural change block"), STOP and surface to the
coordinator; do not proceed under an assumption. If the code does not match the line/quote given here,
STOP and report the drift — do not hunt for "what was probably meant."

---

## Execution status — LIVE (keep this updated; last: 2026-07-29 coordinator session)

**Legend:** ✅ done+verified · 🔄 in progress · ⛔ blocked · ⬜ not started

### Phase 0 — Honest instrumentation & deploy discipline — ✅ COMPLETE (deployed, commit `c15944d`)
- T0.0 preserve forensics — ✅ moot (artifacts already gone before session; service stopped). Concerns TA-C01.
- T0.1 harden convergence gate (D3) — ✅ `9f238ba`.
- T0.1b/c gate hardening (QC Gate 0 re-audit: missing/unreadable PRINT → FAIL; whitespace/bare-`tbegc` scan) — ✅ `76ced7f`, `d488449`. Concerns TA-C06.
- T0.2 deploy-restart proof (D4) + coordinator rule — ✅ (meta repo). Verified LIVE: deploy printed running-commit + process-start.
- T0.3 hotstart split + stale-hotfile guard (D2/D2b) — ✅ `94c43f4`. **STANDS under the hybrid** — L1/L2 stay nonstationary in the full run, so the hotstart-timestamp fix is still needed (earlier "moot if stationary" note was wrong: the hybrid keeps L1/L2 nonstationary).
- T0.4/T0.4b gate known-answer tests + re-audit guards — ✅ `63c6191`, `f39f9cf`, `c15944d`.
- T0.5 spectral trace WW3→L4 (A–E) — ✅ `f657bda`. Sub-task F (live readout) — 🔄 partial: WW3-raw + L1-boundary captured; downstream stages need a completed run.
- QC Gate 0 — ✅ two blind adversarial passes; all *reachable* defeats closed+guarded; negative-scan residual (positive-completion check) deferred to T1.2 (TA-C06).

### Phase 1 — Unblock computation; prove a REAL run (M1) — ⛔ BLOCKED
- T1.1 OBSTACLE ≤180-char wrap (D1) — ✅ `a915deb`. **D1 is FIXED** — no >180-char line in generated INPUT.
- Phase 0+T1.1 deploy — ✅ `deploy-marine.sh`, `c15944d` live 2026-07-29 17:14 UTC.
- **T1.0 (NEW) — all-stationary quasi-stationary full run — 🔄 DECIDED + SCOPED, READY TO DISPATCH (not yet coded). THIS is the real M1 blocker, not D1.** Cold run failed *honestly* at L1: the nonstationary S&L scheme trips CFL>10 (governed by the 0.03 Hz spectral bin at group speed — deterministic every run). **DECIDED (operator 2026-07-29) = ALL-STATIONARY** (quasi-stationary: `MODE NONSTATIONARY` + per-hour `COMPUTE STAT` sequence at every level, SORDUP, no CFL; manual-recommended for <100 km) **+ directional resolution 36→72 + `NUMERIC alfa` under-relaxation on + mandatory COLDSTART.** Operator confirmed hourly cadence + alfa on. HYBRID (L1/L2 nonstationary) retained as documented fallback. Full task contract in `#### T1.0`; design/rationale in the ledger; Fable-review corrections incorporated. NEXT ACTION: dispatch `clearskies-api-dev` for the emitter+caller, then `clearskies-test-author` guard, then coordinator deploy(COLDSTART)+measure.
- T1.2 cold full run (M1 evidence) — ⬜ blocked by T1.0 (run so far = honest FAIL at L1).
- T1.3 re-verify C-E07 + curve-clip — ⬜ blocked by T1.2.
- QC Gate 1 / **M1** — ⬜ not reached.

### Phases 2–3 — ⬜ not started (blocked by M1)
- T3.0 partially informed: trace shows the WW3 boundary DOES carry directional structure (≥2 distinct swell directions + windsea at station 46223) → swell loss is **downstream in our pipeline, not the WW3 data** (confirms the plan's leading hypothesis). Which grid collapses it = TBD (needs a completed run's full trace).

### Key findings this session (corrected per Fable review 2026-07-29)
- **The "217 s complete" runs were fake** — established by PRINT forensics (SWAN refused every timestep; L4 TABLE 100% exception values), so the old vacuous gate published garbage/warm-start, not a computed field. **Fable correction:** those *pre-deploy* runs failed on the **D1 over-long-OBSTACLE severe error**, NOT CFL; the **CFL block is the NEW post-D1 blocker**, shown only after T1.1 fixed the obstacle — do not conflate them. (Earlier "L2 alone ~10 min" was an invented figure contradicting "no baseline exists" — struck.) **No real run-time baseline exists yet.**
- **Spectral resolution = `CIRCLE 36 0.03 1.0 34`** (36 dir = 10°, hardcoded `swan_formats.py:1529`). Finer directional resolution is a real lever — but **Fable correction on the rationale:** the at-risk pair is **195°@18 s vs 168°@16 s** (≈1 *frequency* bin apart, ~27° in direction ≈ ~3 bins at 10°), NOT "195°/184° 11° apart" — 195°@18 s and 184°@10 s differ by ~5–6 frequency bins, so directional width never merges them, and the 184°@10 s train may be **absent from the WW3 input** (station 46223 shows ~195°/~165°/~275°-windsea). The trace already resolved distinct trains ~30° apart at the boundary at 10°, so "cannot be separated at 10°" was wrong. Manual recommends 2–5° for swell; 72 dir (5°) is sanctioned. Worth doing — for the right reason (separating 18 s/16 s, and better resolving directional spread).

---

## Prime directive

Prior work served an **un-iterated warm-start field** through a convergence gate that could not tell
computation from cache, and reported **stale-code** runs as passes. This plan's #1 goal is **a real,
non-cached, non-truncated model run whose correctness is validated against reality (the operator's
Surfline baseline) — never against the model's own output.** Track A is ordered to reach that. The
obstacle-accuracy overhaul (Track B) comes after; a working model does not depend on it.

- **M1 (end of Phase 1) — A REAL RUN.** SWAN computes all four levels for the requested cycle (no
  severe error; computed window == requested window); the hardened gate passes honestly; the published
  forecast is THIS cycle's computation — not cache, warm-start, or a degraded fallback.
- **M2 (end of Phase 3) — A CORRECT RUN.** The quantity we can validate directly is the **surf face**:
  the L2→D1 path already produced 4.6–5.0 ft against Surfline 4–6 ft. M2 = the served path (L4→D1 after
  the Phase 2 fixes) **matches or beats** the L2→D1 path against reality, with the face within a **pinned
  numeric tolerance** (Phase 3). **On period and train count, DO NOT assume a boundary cap.** The
  "~13 s / ~2 trains" figure was measured at our **L2 grid — inside our own SWAN model, downstream of the
  UNAUDITED WW3 fetch + `ww3_spectrum_to_swan_boundary()` conversion** — NOT at the raw boundary. A
  limitation seen there could be our code, not WW3. So M2's period/train gap must be **diagnosed to its
  source (T3.0: raw NOAA `.spec` vs reality) before any of it is attributed to the boundary.** If the raw
  spectrum has the trains and our pipeline smears them, that is a **Track-A bug to fix**, not a cap to
  accept. Nothing is "capped" until the raw source is measured against reality.

No "it works" at any point without (a) a process whose start-time postdates the deploy, (b) a gate PASS
that can actually fail, and (c) a reality comparison. And "matches reality" is a **pinned number**
(Phase 3), compared against Surfline's **contemporaneous** forecast at validation time — the 07-28/29
figures below are an illustrative baseline, not a hardcoded pass condition against a days-old ocean.

---

## Operator decisions ledger

**2026-07-29 — SWAN propagation scheme & time-integration — DECIDED: ALL-STATIONARY (operator, in chat); HYBRID retained as a documented fallback if accuracy is insufficient (architectural, trigger 1/3).**
The cold M1 run failed honestly at L1: the nonstationary higher-order **S&L** scheme trips SWAN's CFL>10
guard ("not possible to compute" every timestep). Verified against the local manual + code:
- `PROP` can only override to **BSBT**; the higher-order schemes are mode-defaults — **S&L (nonstationary)
  / SORDUP (stationary)**. **SORDUP CANNOT be selected for a nonstationary run.**
- **S&L IS available and IS the nonstationary sharp scheme** (correction: an earlier note here wrongly
  said BSBT was the only working nonstationary option). It failed only because the current 10-min time
  step puts CFL>10 on L1. The manual's first remedy is a **smaller time step**; BSBT is its fallback.
- S&L stays viable if the time step drops enough for each grid's CFL<10. **CFL correction (Fable):** SWAN
  propagates action at the **group velocity**, and the governing component is the spectral grid's **lowest
  frequency bin, 0.03 Hz** (`CIRCLE 36 0.03 1.0 34`) — cg ≈ 26 m/s deep water → CFL ≈ 15 on L1 at
  dt=10 min, so **L1 trips DETERMINISTICALLY every run, in all sea states** (not only long-period days —
  this strengthens the fake-run conclusion). Size dt from that 0.03 Hz bin's cg at local depth (approx,
  MUST be measured): L1 1 km ≈ ≤6.5 min, L2 100 m ≈ ≤1 min, **L4 10 m ≈ ≤10–15 s** (earlier "20–60 s" was
  2–4× optimistic; moot under the hybrid since L4 goes stationary). Per-level dt (levels already run as
  separate nested passes). Cost = more timesteps → slower by an UNMEASURED factor. Open question is speed,
  not validity. (Nuance: the manual says SWAN's implicit scheme is NOT Courant-limited for *stability* and
  frames CFL<10 as *accuracy* advice — but the 41.51AB binary enforces it as a FATAL level-2 error, not
  tunable via `SET MAXERR`; don't attempt that dodge.)
- SORDUP is stationary-only; it CANNOT be put on a nonstationary run. "Nonstationary + SORDUP" is invalid.
- **✅ CHOSEN (operator 2026-07-29) — ALL-STATIONARY (quasi-stationary at all four levels).** Every level
  L1→L4 runs stationary via `MODE NONSTATIONARY` + a SEQUENCE of `COMPUTE STAT [t]` at each forecast hour
  (scheme = **SORDUP**, sharp, automatic). **No CFL anywhere** (nothing time-marches); manual-recommended
  for a <100 km domain (`:5718`); simplest path; scheme-consistent with the existing hourly fill; and it
  makes T0.3's split-COMPUTE + all per-level-dt/cross-scheme questions **moot** (see note below).
  Rationale: 28 km domain (~33 min transit) + every forcing hourly → no sub-hourly propagation memory to
  capture, so the stationary snapshot at each hour IS the correct field. Finer directional resolution
  (36→72) + mandatory COLDSTART still apply. Runtime = 72 hourly solves × 4 levels × (iterations to
  converge) → tune the iteration cap `mxitst` (default 50) from the observed convergence curve; MEASURE it.
- **⏸ FALLBACK — RETAINED, not chosen (operator 2026-07-29: keep as an option if all-stationary accuracy is
  insufficient; do NOT discard the schema) — HYBRID nonstationary/stationary nest (SWAN best practice,
  manual-sanctioned):** L1/L2 run **nonstationary (S&L, sharp)** to capture time-evolving deep-water
  propagation across the larger/deeper grids; L3/L4 run **stationary** via `MODE NONSTATIONARY` + a
  SEQUENCE of `COMPUTE STAT [t]` at each forecast hour (manual p.113 line 5728: "high resolution model
  with a very large time step … apply multiple COMPUT STAT"; line 5708: COMPUTE STAT valid under MODE
  NONSTAT, each warm-starting the next). Stationary L3/L4 use **SORDUP (sharp)** automatically. Result:
  **sharp everywhere (S&L + SORDUP, NO BSBT); CFL constrains only L1/L2; the fine-grid CFL blow-up is
  eliminated; no accuracy loss on L3/L4** (their transit time ≪ hourly step, so a stationary solve IS the
  correct field). Two separate compute knobs, both directed: **(i) L1/L2 time step** reduced for their
  CFL (L1 ≈ ≤6.5 min; L2 measure — never reached); **(ii) finer directional spectral resolution** (36→72
  dir) to better separate the **195°@18 s / 168°@16 s** pair (close in frequency) and resolve directional
  spread — NOT the "195°/184° 11°" rationale, which Fable showed was wrong (see Key findings). The L3/L4
  stationary saving offsets (i)+(ii). Runtime has no baseline — MEASURE the first real run. Supersedes the
  earlier a/b/c (BSBT vs stationary-only) framing.
- **Implementation delta (T1.0 = ALL-STATIONARY; to be scoped for sign-off before coding):** the new full
  run is a **quasi-stationary SEQUENCE, applied UNIFORMLY to all four levels** — simpler than the hybrid
  (no per-level mode split, no per-level `compute_dt_min`, no CFL). Per Fable finding 1, the single
  `stationary` flag today gates **EIGHT** emissions in `build_swan_input`, not just COMPUTE — the
  `INPGRID … NONSTAT` clauses for wind/WLEVEL/CURRENT (~`swan_formats.py:1575/1587/1599`) and four
  `OUTPUT …` clauses on SPECOUT/TABLE (~`:1887/1906/1937/1958`), plus COMPUTE (~`:1964-1987`). The
  all-stationary full run is a **THIRD emission state** (distinct from today's single `COMPUTE STAT` fill
  and the T0.3 nonstationary split): **`MODE NONSTATIONARY` + nonstationary INPGRIDs (time-varying
  wind/tide/current) + per-hour OUTPUT clauses + a SEQUENCE of `COMPUTE STAT [t]` at each forecast hour
  (each warm-starting the next) + explicit HOTFILE placement.** ⚠ If an implementer emits only the
  COMPUTE-STAT sequence but drops the time-varying INPGRIDs/OUTPUTs, they get ONE weather snapshot frozen
  across all 72 hours — no SWAN error, silently wrong physics (Fable finding 1). Plus `CIRCLE 36 → 72` at
  `swan_formats.py:1529`. **MANDATORY COLDSTART (Fable finding 5): the 36→72 change invalidates every
  persisted hotstart** — SWAN requires hotfile identity in *spectral* space too (manual :2806) and the F1
  guard checks *spatial* geometry ONLY, so T1.0 must clear `*_hotstart.dat` on deploy or risk the
  fort.21/segfault hotstart-corruption class.
- **T0.3 under all-stationary — dormant, retained (do NOT revert):** the full run no longer emits
  `COMPUTE NONST`, so T0.3's split-COMPUTE + hotstart-timestamp logic is unexercised by the all-stationary
  full run. Keep it in the code: it is correct, its stale-hotfile guard may still apply to warm-starts,
  and the **hybrid fallback uses it**. Removing it would be discarding the fallback the operator chose to
  keep. (The hourly fill's single `COMPUTE STAT` and this new stationary-sequence coexist with it.)
- **Hotstart / hourly-fill interaction (confirmed against code):** KEEP hotstart. The full nonstationary
  L1/L2 run writes it (**T0.3 stands** — not moot; L1/L2 remain nonstationary). The hourly fill
  (`run_quick_update` → `run_stationary_full_nest`, `stationary=True`) already runs ALL levels stationary
  and reuses-but-never-overwrites the full run's hotstart — so the fill's L1/L2 already use **SORDUP**
  automatically (stationary default; no `PROP` needed) and the hybrid does not change the fill. Bonus:
  under the hybrid, L3/L4 are stationary/SORDUP in BOTH the full run and the fill → scheme-consistent
  across paths (today they mismatch). Cross-scheme hotstart handoff (S&L full → SORDUP fill on L1/L2) is
  harmless — a hotstart is a scheme-agnostic wave-energy field; both schemes are sharp higher-order.
- **RESOLVED (operator 2026-07-29) — ALL levels stationary. Fable finding 9 accepted.** The manual's own
  rule of thumb is "<100 km / 1° → stationary recommended" (`:5718`); L1 is only ~28×20 km (transit ~33 min)
  and every forcing is hourly, so there is no sub-hourly propagation memory to capture even on L1/L2.
  Runtime arithmetic: L2 nonstationary at a CFL-safe ≤1 min over 72 h ≈ ~4,320 implicit steps vs ~72
  stationary solves — the hybrid's L2 leg is plausibly the runtime dominant, for marginal fidelity. So
  **all-stationary (quasi-stationary at all four levels) is the simpler baseline the hybrid must beat**:
  no per-level dt, no CFL anywhere, scheme-consistent with the fill, T0.3/cross-scheme questions moot.
  The hybrid is defensible ONLY if L1/L2 sub-hourly propagation across 28 km actually matters — which the
  hourly forcing suggests it does not. **Decision needed: run the first real run BOTH ways (hybrid vs
  all-stationary) and compare, or commit to one.** Coordinator lean after Fable: all-stationary is the
  honest default; make the hybrid earn its extra complexity against it.
- **DIRECTED regardless of mode:** try **finer spectral (directional) resolution** (current 36 dir/10°;
  195° & 184° trains only 11° apart) to stop merging the trains. Architectural (resolution) but
  operator-directed. Runtime cost to be measured against a first real run (no baseline exists — the old
  "217 s" runs were non-computing vacuous passes). See TA-C07.

**Approved in chat 2026-07-29 — do not re-litigate:** D3 gate hardening; D4 deploy-restart discipline;
D2 testing discipline (explicit HOTSTART/COLDSTART per run; COLDSTART clears stale hotfiles + caches);
D6b geometry guard → L4 (doc-code sync); D7 MOOT for dev (always surface current output; last-good
parked to cutover); obstacle input = operator draws polygon, we convert (scalar entry = fallback);
conversion direction = thin→line, solid-wide→footprint, permeable pier→low-vertex `TRANSM` line.

**RESOLVED 2026-07-29 (operator) — the hotstart mechanism (D2, architectural, operator-directed).**
KEEP hotstart; **do NOT drop it** (cold-starting every cycle is unacceptable compute overhead). **FIX
the hotfile so it is written at the NEXT full-cycle start time, not the window END** — split the
nonstationary COMPUTE and place `HOTFILE` at the split (manual p.113: HOTFILE writes the field at the
end of the immediately preceding COMPUTE). Same total window computed (no cold-start); warm-start
preserved; the timestamp now matches what the next cycle's `INIT HOTSTART` needs, removing the tbegc
clamp (D2), the 7 h truncation, and the same-cycle spin (D2b). Chosen over drop and over chain-forward.
**T0.3 implements this.** COLDSTART (clearing `*_hotstart.dat`) is retained only as a testing tool and
as the mandatory step after a geometry change (the F1 guard).

**Phase F (wind-sea source term) pre-approval — RE-RECORD REQUIRED (architectural, trigger 1).** The
prior plan (§0B.4) records operator pre-approval of the Young & Verhagen wind-sea growth kernel. Per the
architectural block, "a governing document says so" is not authorization — approvals for THIS plan live
in THIS ledger. **Operator: confirm the Phase F pre-approval in chat** before T3.2 can run. Until then
T3.2 is blocked, not assumed.

**Pending operator sign-off (ARCHITECTURAL — Track B / Phase 5):** emission fork for solid cell-spanning
structures (bathymetry land-cells vs thick obstacle band); per-type transmission/reflection coefficients
(formula constants); **adding `rasterio`/`exactextract` as a dependency** (trigger 7 — pyproject.toml has
`shapely` but neither raster lib; T4.2 defaults to a shapely-only rasterizer to avoid this, but if a
raster lib is preferred it needs sign-off); draw-tool polygon mode.

**Note — non-architectural Track B tasks:** T4.4 (D5 shadow diagnosis) and T4.5 (C-E02 coordinate
round-trip) are **not** architectural and are **not** gated on the Track B sign-off — they are grouped in
Phase 4 topically and may be dispatched independently (T4.4 should run before/with Phase 3, since a
0/32 shadow misclassification biases M2's headline aggregates).

---

## 0. Orientation — execution context

**Read before any task:** `CLAUDE.md`; `rules/agents.md`, `rules/coordinator.md`, `rules/verification.md`;
`docs/ARCHITECTURE.md`; `docs/reference/swan-commands-extract.md` + the **local** manual
`docs/reference/swan-user-manual.pdf` (**NEVER download SWAN docs — `pdftotext -layout` locally**);
`reference/clearskies-dev.md`; the diagnosis brief.

| Thing | Value |
|---|---|
| Marine service | `librewxr` (192.168.7.22), unit `weewx-clearskies-marine.service`, port **8780** (TLS) |
| Marine repo (local) | `repos/weewx-clearskies-marine/` (on host: `/home/ubuntu/repos/weewx-clearskies-marine/`) |
| SWAN binary | `/usr/local/bin/swan` (41.51AB, OpenMP, `omp_num_threads=6` — operator ruling, do not change) |
| Served cache | `/run/weewx-clearskies/swan/forecast_cache.json` |
| Workdirs | `/var/run/weewx-clearskies/swan/level{1,2,3_0,4_0}/` (INPUT, PRINT, BOTTOM.txt, TABLE_*, *_hotstart.dat) |
| Logs | `sudo journalctl -u weewx-clearskies-marine.service` (JSON lines) |
| SSH | `ssh -F .local/ssh/config librewxr "<cmd>"` (repo cmds `sudo -u ubuntu`; containers read-only) |
| Deploy | `scripts/deploy-marine.sh` (restarts + verifies /health, /manifest, auth) |
| Tests | on librewxr: `sudo -u ubuntu /home/ubuntu/repos/weewx-clearskies-marine/.venv/bin/python -m pytest <targeted file> -q` |

**Agent assignments:** Coordinator (Opus) — orchestration, QC gates, reality validation, deploy (operator
types "push"). `clearskies-api-dev` (Sonnet) — marine-service Python. `clearskies-test-author` (Sonnet)
— guards + known-answer tests. `clearskies-auditor` (Sonnet) — adversarial, **blind to impl work product**.

**Verification mandate (`rules/verification.md`):** (1) impl agent reports are NOT trusted; (2)
coordinator checks run on a process whose start-time **postdates the deploy**, and every acceptance block
records that start-time; (3) auditor is blind to impl tests/commits/report and is briefed to prove the
result is *cache / warm-start / truncated tail / silent fallback / stale code*, passing only when it
cannot and names what it ruled out; (4) physics validated against **reality** (Surfline), comparison
quantity chosen before looking; (5) numerical kernels get **known-answer tests** vs an independent reference.

**Reality baseline (operator screenshots 2026-07-28/29 — ground truth):** surf face **4–6 ft**; LOTUS
swell **1.9 ft @ 18 s SSW 195° + 1.9 ft @ 16 s SSE 168° + 1.1 ft @ 10 s S 184°** (THREE trains).

---

## Phase overview

| Phase | Track | Goal | Items |
|---|---|---|---|
| **0** | A | Honest instrumentation & deploy discipline (no physics) | D3, D4, D2/D2b, **spectral trace WW3→L4 (T0.5)** |
| **1** | A | Unblock SWAN; prove a REAL run — **M1** | D1 |
| **2** | A | Correct the spectrum & handoff (defect B done, defect C join) | C-E05, C-E09 |
| **3** | A | Validate against reality — **M2** (face; period/trains diagnosed to source first, T3.0) | raw-boundary check, reality gate, (Phase F if approved + needed) |
| **4** | B | Obstacle representation overhaul (T4.4/T4.5 non-arch, may run earlier) | D1 representation, D5, C-E02 |
| **5** | C | Cleanup & open architectural decisions | D6a, D6b, D6c, C-E12 (boundary quality), D7, C-E10/11/01/03/04/08, doc drift |

---

## TRACK A — GET A WORKING MODEL

### Phase 0 — Honest instrumentation & deploy discipline (NO physics)

#### T0.0 — Preserve the forensic artifacts NOW (first action, before any code)
- Owner: Coordinator
- Architectural block: none.

**Why:** the D2b loop re-runs the same failing cycle every ~5 min and each attempt **overwrites** the
per-level workdirs (`/var/run/weewx-clearskies/swan/level{1,2,3_0,4_0}/{INPUT,PRINT,BOTTOM.txt,TABLE_*,
*_hotstart.dat}`). The severe-error (05:22) and tbegc-clamp PRINTs that T0.4 needs as fixtures are being
destroyed continuously; a genuinely-converged L3/L4 artifact no longer exists on disk at all.

**Do (before anything else):**
1. Stop the loop so it stops overwriting: `ssh -F .local/ssh/config librewxr "sudo systemctl stop
   weewx-clearskies-marine"`. The service stays down through Phase 0 dev (it serves only garbage right
   now); the T0.2 deploy restarts it at the Phase 0→1 boundary.
2. Copy the current `level{1,2,3_0,4_0}` workdirs off-host into the scratch dir — these become T0.4
   fixtures (a) severe-error and (b) tbegc-clamp.

**Accept:** severe-error + tbegc-clamp PRINTs preserved off-host and referenced by T0.4; runner stopped.

#### T0.1 — Harden the convergence gate (D3)
- Owner: `clearskies-api-dev`
- File: `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/swan_runner.py`, function `_check_convergence` (starts line 4993)
- Architectural block: none (bug fix restoring the gate's own stated contract).

**Current code (verified this session):** the PRINT scan loop at lines 5049–5058 only counts `******`
overflow markers and parses a stationary accuracy %. It does **not** detect `Severe error`, `not
possible to compute`, or the `[tbegc]` clamp — all three were present in every failed PRINT. When TABLE
files exist but no timestep rows parse, `valid_fraction` stays `None` (line 5190 comment: "leave
valid_fraction=None → log 100% (best-effort)"), the INFO log at 5208 prints **100.0%** while the metric
at 5235 sets **0.0%**, and `fraction_ok` stays `True` from line 5106 → the level **PASSES on nothing.**

**Do (make exactly these five changes, nothing else in this function):**

1. **Detect fatal PRINT strings.** Immediately before the PRINT scan loop (`for line in
   print_text.splitlines():`, line 5049), add `print_fatal: str | None = None`. Inside that loop, after
   the existing `if "******" in line:` block, add:
   ```python
   if print_fatal is None:
       _low = line.lower()
       if ("severe error" in _low
               or "not possible to compute" in _low
               or "[tbegc]" in _low
               or "before current time" in _low):
           print_fatal = line.strip()
   ```
2. **Fail hard on a fatal PRINT string.** Immediately after the PRINT-reading block, before
   `print_ok = overflow_count == 0` (line 5068), add:
   ```python
   if print_fatal is not None:
       logger.error(
           "SWAN convergence FAILED level=%s: check=print_fatal, details=%r",
           grid_level, print_fatal,
       )
       SWAN_CONVERGENCE_FAILURES_TOTAL.labels(level=grid_level, check="print_fatal").inc()
       return False
   ```
3. **`None` valid_fraction is a FAIL when TABLE output exists.** The `if timestep_counts:` at line 5182
   has no `else`. Add one so an existing-but-unparseable TABLE fails instead of passing:
   ```python
   if timestep_counts:
       ...  # existing body unchanged
   else:
       # TABLE files exist but produced no parseable timestep rows → SWAN
       # computed nothing usable at this level. FAIL, do not best-effort pass.
       valid_fraction = 0.0
       fraction_ok = False
   ```
   (Do NOT touch the `else` at line 5191 — L1/L2 legitimately produce no TABLE and continue to rely on
   the PRINT/overflow checks, which now include the fatal-string gate above.)
4. **Stop the INFO log from lying.** Replace the INFO log (lines 5201–5209) so BOTH `None` cases print
   `n/a`, never a fake `0.0`/`100.0`:
   ```python
   logger.info(
       "SWAN convergence %s: overflow_count=%d, accuracy=%s, "
       "nan_count=%d, valid_fraction=%s",
       grid_level, overflow_count,
       f"{accuracy_pct:.1f}%" if accuracy_pct is not None else "n/a",
       nan_count,
       f"{valid_fraction * 100.0:.1f}%" if valid_fraction is not None else "n/a",
   )
   ```
5. **Declared-but-missing TABLE is a FAIL.** Right after the TABLE-file collection (`while (run_dir /
   f"TABLE_{n}.txt").exists()`, ~lines 5099–5104): a level whose INPUT **declared** a `TABLE` output but
   wrote none produced nothing usable, yet the `else` at 5191 passes it vacuously on a clean PRINT (an
   output-command regression or a write failure slips through). Make it **INPUT-driven** so it can't
   false-fail a level that legitimately emits no TABLE (resolves the L3-vs-L4 ambiguity):
   ```python
   input_has_table = input_path.exists() and "TABLE" in input_path.read_text(
       encoding="ascii", errors="replace")
   if input_has_table and not table_files:
       logger.error("SWAN convergence FAILED level=%s: check=table_missing", grid_level)
       SWAN_CONVERGENCE_FAILURES_TOTAL.labels(level=grid_level, check="table_missing").inc()
       return False
   ```
   (`input_path` is already defined at line 5025. L1/L2, which declare no TABLE, are unaffected.)

**Do NOT:** modify the run method's severe-error check at lines 4965–4978 (it raises on stderr/Errfile;
the authoritative PRINT detection is centralized here). Do NOT change thresholds (0.50/0.80/99.5).

**Note (D2 window check):** the `[tbegc]`/`before current time` string scan (step 1) is the proxy for the
diagnosis's "computed window ≠ requested window must FAIL." It catches the observed clamp message
verbatim; a stricter first-computed-timestep-vs-requested comparison is a known follow-on, not required
for M1.

**Accept (T0.4 proves these mechanically):** feeding a PRINT containing `** Severe error : No value for
variable YP` → returns `False` with `check=print_fatal`. Feeding a PRINT with `start time [tbegc]
before current time` → `False`. A nonstationary run whose TABLE parses to zero timestep rows → `False`.
A run whose INPUT declares `TABLE` but wrote none → `False` (`check=table_missing`). A clean converged PRINT+TABLE →
`True`. L1/L2 (no TABLE, clean PRINT) → `True`, and the INFO log shows `accuracy=n/a`,
`valid_fraction=n/a`, never a fake `0.0`/`100.0`.

#### T0.2 — Deploy-restart proof (D4)
- Owner: `clearskies-api-dev` (script) + Coordinator (rule)
- Files: `scripts/deploy-marine.sh`; `rules/coordinator.md`
- Architectural block: none.

**Current code:** `deploy-marine.sh` already restarts the service (line 276 `systemctl restart`) and
verifies /health, /manifest, and auth. **The D4 failure was not a missing restart** — it was three
`git pull`s applied manually on librewxr that never ran this script, so the running process kept
executing pre-fix code. The fix is to make "what commit is actually running, since when" impossible to
miss.

**Do:**
1. In `deploy-marine.sh`, after the `[svc] ${SERVICE} active` line (line 285), add:
   ```bash
   DEPLOYED_COMMIT=$(run_ubuntu "cd ${REPO_PATH} && git rev-parse --short HEAD")
   PROC_START=$(run_root "systemctl show ${SERVICE} -p ExecMainStartTimestamp --value")
   echo "[verify] running commit ${DEPLOYED_COMMIT}; process started ${PROC_START}"
   ```
2. On the `--no-restart` path (the script `exit`s at line 272, before the lines above), print
   `[verify] STALE PROCESS — service not restarted; running process predates this deploy` with the
   current `ExecMainStartTimestamp`, so a no-restart deploy can never be mistaken for a live one.
3. Add to `rules/coordinator.md` (Acceptance-gate section): "Marine deploys go through
   `scripts/deploy-marine.sh` ONLY — never a bare `git pull` on librewxr. A run's evidence counts only
   if the service `ExecMainStartTimestamp` postdates the deploy of the commit under test; record the
   commit short-hash and process start-time in every acceptance block."

**Accept:** a normal deploy prints the running commit + process start-time; a `--no-restart` deploy prints
the STALE warning; the coordinator rule is present.

#### T0.3 — Fix the hotstart timestamp so warm-start works (D2) + stop the same-cycle spin (D2b)
- Owner: `clearskies-api-dev`
- Files: `services/swan_formats.py` (`build_swan_input`, COMPUTE/HOTFILE emission ~lines 1942–1951; the
  `INIT HOTSTART` emission ~1546–1547) and its caller in `services/swan_runner.py`; `service.py`
  `_marine_runner_loop`
- Architectural: **RESOLVED & operator-directed 2026-07-29 (keep hotstart, fix the timestamp — see
  ledger). Do NOT drop hotstart.**

**Current code (`swan_formats.py:1948–1951`):**
```python
else:
    lines.append(f"COMPUTE NONST {swan_t_start} {compute_dt_min} MIN {swan_t_end}")

lines.append("HOTFILE 'hotstart.dat'")
```
`HOTFILE` writes the wave field at the END of the immediately preceding COMPUTE (manual p.113), so the
hotfile is stamped at `swan_t_end` (window end, +72 h). The next full cycle begins 6 h AFTER
`swan_t_start` — hours BEFORE `swan_t_end` — so its `INIT HOTSTART` reads a future-stamped file →
`start time [tbegc] before current time` → clamp → only a ~7 h tail computes (D2). Each same-cycle retry
re-arms it (D2b). **SWAN mechanism verified against the local manual:** a second COMPUTE's `[tbegc]`
defaults to the previous nonstationary computation's end time in the same run, so
`COMPUTE t0→t_split; HOTFILE; COMPUTE t_split→t_end` is valid and computes the identical total window.

**Do — part 1: split the COMPUTE, write the hotfile at the next cycle's start.**
1. Add a `swan_t_hotsave` argument to `build_swan_input` = the NEXT full-cycle start time, formatted like
   `swan_t_start` (`YYYYMMDD.HHmmss`). Compute it in the caller (the runner that sets `swan_t_start`/
   `swan_t_end`) as `min(swan_t_end, swan_t_start + 6 h)`. Full nonstationary runs fire on the extended
   HRRR cycles 00/06/12/18Z → **cadence 6 h** (verify against `service.py:121` `_is_extended_hrrr_cycle`).
2. Replace the nonstationary emission (lines 1948–1951) with:
   ```python
   else:
       # HOTFILE writes the field at the END of the preceding COMPUTE (manual
       # p.113). Split so the hotfile is stamped at the NEXT full cycle's start
       # (swan_t_hotsave) — what that cycle's INIT HOTSTART needs. A hotfile at
       # swan_t_end can only trigger the tbegc clamp. Total window unchanged.
       lines.append(f"COMPUTE NONST {swan_t_start} {compute_dt_min} MIN {swan_t_hotsave}")
       lines.append("HOTFILE 'hotstart.dat'")
       lines.append(f"COMPUTE NONST {swan_t_hotsave} {compute_dt_min} MIN {swan_t_end}")
   ```
   Leave the stationary branch (`COMPUTE STAT` + its `HOTFILE`) unchanged. If `swan_t_hotsave` is not
   strictly between start and end, emit the original single-COMPUTE form and log (never a zero/negative
   segment).

**Do — part 2: guard against a stale hotfile (the two failure modes the split alone does NOT fix).**
In `swan_runner.py`, before deciding to pass `hotstart_file` into `build_swan_input`, read the persistent
hotfile's own timestamp line and compare it to the requested `swan_t_start`. If they do **not** match,
**delete the hotfile and cold-start that level** (do not pass `hotstart_file`), and log it. Two cases this
kills: (a) a cycle that computes L1–L3 then raises at L4 has already saved L1–L3 hotfiles at `t0+6h`; the
runner retries the SAME cycle at `t0`, the stale `t0+6h` file would clamp again → the hardened gate fails
it → D2b spin; (b) after downtime the stamp is older than the new `t0`. The timestamp compare dissolves
both — and is the only thing that makes the fix survive a partial-failure retry.

**Do — part 3 (D2b):** with the timestamp fixed and the guard in place, a clean warm run no longer clamps,
`run_all_spots()` returns normally, and `last_hrrr_cycle` advances at `service.py:457`. Do NOT change the
on-exception no-advance path (lines 446–454) — retrying a genuinely failed cycle is correct.

> **COLDSTART** (clearing `/var/run/weewx-clearskies/swan/*_hotstart.dat`) is retained as a **testing
> tool** and the mandatory step **after a geometry change** (the F1 guard), NOT the production mechanism.

**Accept:**
- Generated nonstationary INPUT has TWO `COMPUTE NONST` lines with `HOTFILE 'hotstart.dat'` between them.
- The date line inside `hotstart.dat` after a run equals `swan_t_hotsave` (not `swan_t_end`).
- The next cycle's PRINT shows first computed timestep == its requested `swan_t_start` (no `[tbegc]`); the
  full window computes, not a ~7 h tail.
- A cycle whose persistent hotfile timestamp ≠ requested start deletes it and cold-starts that level
  (logged), rather than clamping.
- Journal shows `last_hrrr_cycle` advancing (`prev:` not `None`) after a clean warm cycle.
- Unit test asserts the split emission + HOTFILE-between ordering, and the stale-hotfile timestamp guard.

#### T0.4 — Gate known-answer test (guard layer)
- Owner: `clearskies-test-author`
- File: NEW `repos/weewx-clearskies-marine/tests/services/test_convergence_gate.py`
- Architectural block: none.

**Do:** build fixtures under `tests/fixtures/convergence/`:
- (a) `severe_error_PRINT` and (b) `tbegc_clamp_PRINT` — the **real** artifacts preserved by T0.0 (do not
  re-fetch from librewxr; the runner is stopped and would have overwritten them).
- (c) `converged_PRINT` + `TABLE_1.txt` — **a genuinely converged L3/L4 run no longer exists on disk**
  (D2b overwrote the only one, the 22:45 cold run). **Synthesize a minimal converged fixture** (a clean
  PRINT + a TABLE with ≥1 valid HSIGN row per timestep) and **label it synthetic**. The assertion against
  a REAL converged artifact lands as a **follow-on in T1.2** (the first clean run), not here.
- (d) `no_table_L4/` — an L4 workdir with a clean PRINT and no `TABLE_*.txt` (for `check=table_missing`).

Tests on a temp dir seeded with each: `test_severe_error_fails`→`False`; `test_tbegc_clamp_fails`→`False`;
`test_no_table_l4_fails`→`False`; `test_converged_passes` (synthetic)→`True`. The module must **fail
against pre-T0.1 code** (checkout parent commit, ≥2 of the fail-cases pass wrongly) — that is what makes
it a guard.

**Accept:** `pytest tests/services/test_convergence_gate.py -q` → all pass on T0.1 code; ≥2 fail on the
pre-T0.1 commit (evidence pasted). T1.2 adds `test_converged_passes_real` against the first clean run.

#### T0.5 — Full-pipeline spectral trace (WW3 → L4): log every stage's INPUT and OUTPUT
- Owner: `clearskies-api-dev`
- Files: `services/trace.py` (helper); `services/swan_formats.py`, `services/swan_runner.py` (call sites)
- Architectural block: **none.** Read-only observability, gated by the existing
  `CLEARSKIES_MARINE_DEBUG_TRACE` env var; changes no formula, contract, grid, boundary, schedule, or
  responsibility. It only reads spectra the pipeline already produces and writes them to the trace log.
- **Sequencing: build this FIRST among Phase 0 code tasks; RUN it (sub-task F) immediately after the
  T0.2 deploy.** Its output is the arbiter for Phase 2 (defect C) and Phase 3 (T3.0). *(Session note
  2026-07-29: a deep dive established the publish/partition/join code faithfully reports whatever
  spectrum reaches it, and the swell card is sourced from the 15 m DWR — NOT the surf zone — so the
  three-swell collapse is UPSTREAM of the 15 m point. This trace exists to pin exactly which stage
  between WW3 and the 15 m DWR destroys the directional structure, before any Phase 2 code change.)*

**Why:** we cannot tell whether SWAN collapses a genuine three-swell input or the input was already one
swell, because every run deletes its per-level files and ad-hoc forensics compared three different runs.
This logs the 2-D directional spectrum at every real handoff **within one run at one time**, so the
collapse point is a bisection, not a guess. Peak PERIOD is conserved through shoaling/refraction — any
stage where the peak period jumps or three band-directions become one is the defect.

**Do — sub-task A (helper, `services/trace.py`):** after `emit()` (ends line 175), append two functions.
`summarize_spectrum` is the diagnostic; `emit_spectrum` logs full matrix + summary and reuses `emit()`.
```python
def summarize_spectrum(
    freqs_hz: list[float],
    dirs_deg: list[float],
    energy: list[list[float]],
) -> dict[str, Any]:
    """Directional summary of a 2-D spectrum ``E[i_freq][i_dir]`` (m^2/Hz/deg).

    Reveals whether three swells from three directions survive a stage:
    Hs, the peak (period, direction), the two 1-D marginals, and the
    peak+mean direction within three period bands (long >=14 s, mid
    10-14 s, short <10 s) -- the fingerprint a single peak hides. Pure;
    a degenerate/empty spectrum returns zeros, never raises.

    Axis order is FIXED: ``energy[i_freq][i_dir]``. A caller holding WW3's
    direction-major radian array MUST transpose and convert rad->deg first.
    """
    import math

    nf, nd = len(freqs_hz), len(dirs_deg)
    if nf == 0 or nd == 0 or len(energy) != nf:
        return {"hs_m": 0.0, "total_m0": 0.0, "peak_period_s": None,
                "peak_dir_deg": None, "energy_by_freq": [], "energy_by_dir": [],
                "band_directions": []}

    df = [0.0] * nf
    for i in range(nf):
        if nf == 1:
            df[i] = 1.0
        elif i == 0:
            df[i] = freqs_hz[1] - freqs_hz[0]
        elif i == nf - 1:
            df[i] = freqs_hz[-1] - freqs_hz[-2]
        else:
            df[i] = (freqs_hz[i + 1] - freqs_hz[i - 1]) / 2.0
    dtheta = 360.0 / nd  # deg; SWAN/WW3 both span the full circle

    e_freq = [0.0] * nf   # m^2/Hz  (integrated over direction)
    e_dir = [0.0] * nd    # m^2/deg (integrated over frequency)
    m0 = 0.0
    for i in range(nf):
        row = energy[i]
        for j in range(nd):
            e = row[j] if j < len(row) else 0.0
            e_freq[i] += e * dtheta
            e_dir[j] += e * df[i]
            m0 += e * df[i] * dtheta

    hs = 4.0 * math.sqrt(m0) if m0 > 0 else 0.0
    i_pk = max(range(nf), key=lambda k: e_freq[k])
    j_pk = max(range(nd), key=lambda k: e_dir[k])
    peak_period = 1.0 / freqs_hz[i_pk] if freqs_hz[i_pk] > 0 else None

    band_dirs = []
    for name, f_lo, f_hi in (("long", 0.0, 1.0 / 14.0),
                             ("mid", 1.0 / 14.0, 0.10),
                             ("short", 0.10, float("inf"))):
        sx = sy = etot = 0.0
        pj, pe = None, -1.0
        for j in range(nd):
            ej = sum((energy[i][j] if j < len(energy[i]) else 0.0) * df[i]
                     for i in range(nf) if f_lo <= freqs_hz[i] < f_hi)
            if ej <= 0:
                continue
            etot += ej
            sx += ej * math.cos(math.radians(dirs_deg[j]))
            sy += ej * math.sin(math.radians(dirs_deg[j]))
            if ej > pe:
                pe, pj = ej, j
        band_dirs.append({
            "band": name,
            "peak_dir_deg": dirs_deg[pj] if pj is not None else None,
            "mean_dir_deg": (math.degrees(math.atan2(sy, sx)) % 360.0) if etot > 0 else None,
            "energy": etot,
        })

    return {
        "hs_m": round(hs, 4),
        "total_m0": m0,
        "peak_period_s": round(peak_period, 2) if peak_period else None,
        "peak_dir_deg": round(dirs_deg[j_pk], 1),
        "energy_by_freq": [round(x, 6) for x in e_freq],
        "energy_by_dir": [round(x, 6) for x in e_dir],
        "band_directions": band_dirs,
    }


def emit_spectrum(
    stage: str,
    *,
    freqs_hz: list[float],
    dirs_deg: list[float],
    energy: list[list[float]],
    spot_id: str | None = None,
    valid_time: str | None = None,
    transect_index: int | None = None,
    include_matrix: bool = True,
    **extra: Any,
) -> None:
    """Emit one spectral-trace record: the directional summary always, plus
    the full ``E[i_freq][i_dir]`` matrix when *include_matrix*. Guard the
    CALL SITE with ``if trace.TRACE_ENABLED:`` -- assembling the arrays is
    not free. No-op / never raises (same contract as ``emit()``)."""
    if not TRACE_ENABLED:
        return
    fields: dict[str, Any] = {
        "summary": summarize_spectrum(freqs_hz, dirs_deg, energy),
        "nfreq": len(freqs_hz),
        "ndir": len(dirs_deg),
        **extra,
    }
    if include_matrix:
        fields["freqs_hz"] = freqs_hz
        fields["dirs_deg"] = dirs_deg
        fields["energy"] = energy
    emit(stage, spot_id=spot_id, valid_time=valid_time,
         transect_index=transect_index, **fields)
```

**Do — sub-task B (WW3 raw + L1 boundary, `services/swan_formats.py`):** this file does **not** import
`trace` yet — add `from weewx_clearskies_marine.services import trace` with the other service imports
(near line 43, beside the `ww3_spectrum` import). Then add this module-level helper directly above
`ww3_boundary_files_and_command` (the function whose loop is at lines 2226–2243):
```python
def _trace_ww3_and_boundary(side: str, station: Any, boundary_text: str) -> None:
    """spec_ww3_raw = the ocean input (per WW3 timestep); spec_l1_boundary =
    the exact bytes SWAN will read for this station (post +180 / rad->deg /
    density conversions). Read-only; caller guards with TRACE_ENABLED."""
    from weewx_clearskies_marine.services.swan_spectral import parse_specout_file
    st_id = station.station_id
    for spec in station.spectra:
        # WW3 energy is [i_dir][i_freq], m^2/Hz/rad -> canonical
        # [i_freq][i_dir], m^2/Hz/deg (× pi/180, matching the writer's
        # _RAD_TO_DEG_DENSITY_FACTOR so Hs is comparable to the buoy).
        nf, nd = len(spec.freqs_hz), len(spec.dirs_rad)
        dirs_deg = [math.degrees(d) % 360.0 for d in spec.dirs_rad]
        e_fd = [[spec.energy[j][i] * (math.pi / 180.0) for j in range(nd)]
                for i in range(nf)]
        trace.emit_spectrum(
            "spec_ww3_raw", freqs_hz=spec.freqs_hz, dirs_deg=dirs_deg,
            energy=e_fd, valid_time=spec.time, station_id=st_id, side=side,
            depth_m=spec.header.depth_m, level="ww3",
        )
    for entry in parse_specout_file(boundary_text):
        trace.emit_spectrum(
            "spec_l1_boundary", freqs_hz=entry["freqs_hz"],
            dirs_deg=entry["dirs_deg"], energy=entry["energy"],
            valid_time=entry["time"], station_id=st_id, side=side, level="L1_bnd",
        )
```
At line 2241, immediately after `files[fname] = ww3_spectrum_to_swan_boundary(station.spectra)`, add:
```python
            if trace.TRACE_ENABLED:
                _trace_ww3_and_boundary(side, station, files[fname])
```

**Do — sub-task C (L2 DWR = the 15 m swell-catalog source, `services/swan_runner.py`):** in the
`_entries.append({...})` loop (lines 3427–3446), immediately after that `.append(`, add — `_sid`,
`_sp_time`, `_components`, `_sp` are all in scope:
```python
                        if trace.TRACE_ENABLED:
                            trace.emit_spectrum(
                                "spec_l2_dwr",
                                freqs_hz=_sp.get("freqs_hz", []),
                                dirs_deg=_sp.get("dirs_deg", []),
                                energy=_sp.get("energy", []),
                                spot_id=_sid, valid_time=_sp_time,
                                level="L2_dwr_15m", n_components=len(_components),
                            )
```

**Do — sub-task D (L3/L4 surf handoff, `services/swan_runner.py`):** at the merge-path
`results.append({...})` (lines 2080–2092 — the builder that emits `handoff_selection_merge`;
`spot_id`, `time_iso`, `transect_index`, `selection`, `is_structure_grid`, `spectrum_entry` all in
scope), immediately after that `.append(`, add:
```python
        if trace.TRACE_ENABLED:
            trace.emit_spectrum(
                "spec_l4_handoff" if is_structure_grid else "spec_l3_handoff",
                freqs_hz=spectrum_entry["freqs_hz"],
                dirs_deg=spectrum_entry["dirs_deg"],
                energy=spectrum_entry["energy"],
                spot_id=spot_id, valid_time=time_iso, transect_index=transect_index,
                level="L4" if is_structure_grid else "L3",
                handoff_depth_m=selection.handoff_depth_m,
                station_depth_m=selection.station_depth_m,
            )
```
Apply the **same** block at the curve-index handoff builder's `results.append` (lines 908–917), using
that function's own identifier (`label`) for `spot_id=` and its `time_iso`/`transect_index`/
`spectrum_entry`/`selection` — the two builders differ only in which local holds the spot id.

**Do — sub-task E (nest handoffs L1→L2 and L2→L3, finer bisection, same helper):** at every site that
copies a parent's `nest_out.dat` into a child's `nest_in.dat` — the 2-level site is
`services/swan_runner.py:2773–2777` (`shutil.copy2(str(src), str(dst))`); the 3-level sites are the
equivalent copies inside `run_3level` (locate by grepping `shutil.copy2` together with `_NESTOUT_FILE`/
`_NEST_INPUT_FILE`) — add, immediately after the `shutil.copy2(...)`:
```python
            if trace.TRACE_ENABLED:
                _trace_nest_handoff(src, "spec_l1_nestout", "L1_nestout")  # stage/level per level
```
and add this helper near the other module helpers in `swan_runner.py` (it already imports `trace`):
```python
def _trace_nest_handoff(nest_path: Path, stage: str, level: str) -> None:
    """Trace the most-energetic location of a NESTOUT handoff file (the point
    carrying the swell) as a full 2-D spectrum, and a matrix-free summary of
    every nest location. Read-only; caller guards with TRACE_ENABLED."""
    from weewx_clearskies_marine.services.swan_spectral import parse_specout_file_multi
    try:
        specout = parse_specout_file_multi(nest_path.read_text(encoding="utf-8", errors="replace"))
    except Exception:  # noqa: BLE001 - a trace must never break a run
        return
    # Per timestep, the most-energetic location gets the full matrix; every
    # other location gets a summary only (keeps a 302-point nest file sane).
    per_time_by_t: dict[str, list[tuple[int, dict]]] = {}
    for loc_idx, per_time in enumerate(specout.station_timesteps):
        for entry in per_time:
            per_time_by_t.setdefault(entry.get("time", ""), []).append((loc_idx, entry))
    for t_iso, items in per_time_by_t.items():
        best_idx = max(
            range(len(items)),
            key=lambda k: trace.summarize_spectrum(
                items[k][1]["freqs_hz"], items[k][1]["dirs_deg"], items[k][1]["energy"]
            )["total_m0"],
        )
        for k, (loc_idx, entry) in enumerate(items):
            trace.emit_spectrum(
                stage, freqs_hz=entry["freqs_hz"], dirs_deg=entry["dirs_deg"],
                energy=entry["energy"], valid_time=t_iso, level=level,
                nest_loc_index=loc_idx, include_matrix=(k == best_idx),
            )
```
*(Sub-task E is the one non-line-exact site: the 3-level copy points must be located by the grep anchor
above. If E balloons the trace file, keep `include_matrix=False` for all nest locations — the summary's
`peak_period_s` + `band_directions` are enough to bisect; the single-point stages B/C/D carry the full
matrices.)*

**Do — sub-task F (run it + read it out):** after the T0.2 deploy, enable the trace for exactly one
cycle and capture the readout.
1. `ssh -F .local/ssh/config librewxr "sudo systemctl edit weewx-clearskies-marine"` → add
   `[Service]\nEnvironment=CLEARSKIES_MARINE_DEBUG_TRACE=1`, then `sudo systemctl restart` and wait one
   full forecast cycle.
2. Read out one spot/one valid_time across all stages (deep→shore), asserting peak period + the three
   band-directions at each: `spec_ww3_raw → spec_l1_boundary → spec_l1_nestout → spec_l2_dwr →
   spec_l2_nestout → spec_l3_handoff/spec_l4_handoff`.
3. Remove the drop-in (`systemctl revert`) so production does not run with the trace on.

**Do NOT:** change any spectrum, axis, conversion, selection, or file the pipeline produces; the trace
only reads them. Do NOT leave `CLEARSKIES_MARINE_DEBUG_TRACE` set in production after sub-task F.

**Accept:**
- With `CLEARSKIES_MARINE_DEBUG_TRACE` unset, `emit_spectrum`/`_trace_*` are no-ops (one boolean check);
  the model's published output is unchanged.
- Unit test (NEW `tests/services/test_spectrum_trace.py`): a synthetic three-swell spectrum
  (peaks at 18 s from 195°, 16 s from 168°, 10 s from 184°) fed to `summarize_spectrum` returns
  `band_directions` whose long/mid/short `peak_dir_deg` are ~195/~168/~184 and `peak_period_s`≈18 —
  i.e. the summary actually separates three directions. A single-swell spectrum returns one dominant
  band. `summarize_spectrum([],[],[])` returns the zero dict, no raise.
- After sub-task F: the trace file contains `spec_ww3_raw`, `spec_l1_boundary`, `spec_l2_dwr`, and
  `spec_l3_handoff`/`spec_l4_handoff` records for `huntington-city-beach-pier` at a shared valid_time,
  each carrying `summary.peak_period_s`, `summary.peak_dir_deg`, and `summary.band_directions`; and the
  readout shows peak period + band-directions at every stage in one table — **the deliverable that
  names the exact stage where the three swells collapse.**

#### QC Gate 0
- **Mechanical:** T0.4 green on new code, red on old; `deploy-marine.sh` prints commit + start-time;
  COLDSTART procedure clears hotfiles. T0.5: `test_spectrum_trace.py` green (three-swell summary
  separates three band-directions); trace is a no-op when the env var is unset; sub-task F readout
  table produced (peak period + band-directions at every stage, one spot, one valid_time).
- **Adversarial (blind):** auditor is given ONLY the three fixtures + the gate's stated contract and
  told "prove this gate can be made to pass on a run that computed nothing." Passes only if it cannot,
  and names the paths it checked (fatal-string, None→FAIL, overflow).

---

### Phase 1 — Unblock computation; prove a REAL run (**M1**)

#### T1.1 — OBSTACLE emitter: legal ≤180-char lines + guard (D1)
- Owner: `clearskies-api-dev`
- File: `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/swan_formats.py`, structure loop at lines 1695–1713
- Architectural block: none (line-wrapping the SAME obstacle geometry; no coefficient, boundary, or
  responsibility change). Vertex-reduction/footprint representation is **Phase 4, not here** — do NOT
  reduce, resample, or re-order vertices in this task.

**Current code (line 1706–1707):**
```python
coord_str = " ".join(coord_parts)
lines.append(f"OBSTACLE {params} LINE {coord_str}")
```
`coord_parts` is a list of `"{x:.2f} {y:.2f}"` strings (one per vertex). For the 35-vertex HB pier this
is one ~600-char line; SWAN's hard 180-char input limit (manual §Command syntax, node22) truncates it
mid-coordinate → `Severe error: No value for variable YP` → "not possible to compute" at every timestep,
all four levels.

**Do:**
1. Add a module-level helper (near the other format helpers in this file):
   ```python
   def _wrap_swan_tokens(head: str, tokens: list[str], limit: int = 180) -> list[str]:
       """Emit `head` + space-joined `tokens` across >=1 physical lines, each
       <= `limit` chars, using SWAN's trailing '&' continuation (manual node48).
       Whole tokens are never split across lines."""
       out: list[str] = []
       cur = head.rstrip()
       for tok in tokens:
           candidate = f"{cur} {tok}"
           # +2 reserves room for a trailing " &" on a continued line.
           if len(candidate) + 2 > limit and cur != head.rstrip():
               out.append(cur + " &")
               cur = tok
           else:
               cur = candidate
       out.append(cur)
       return out
   ```
2. Replace lines 1706–1707 with:
   ```python
   # SWAN input lines are capped at 180 chars; a 35-vertex ring is ~600 on one
   # line and truncates mid-coordinate. Wrap with '&' continuation (D1).
   lines.extend(_wrap_swan_tokens(f"OBSTACLE {params} LINE", coord_parts, limit=180))
   ```
3. **Emitter guard (belt-and-braces, all commands).** At the point `build_swan_input` assembles its
   `lines` list into the returned INPUT text, add, immediately before the return:
   ```python
   for _ln in lines:
       if len(_ln) > 180:
           raise SWANFormatError(f"generated SWAN INPUT line exceeds 180 chars ({len(_ln)}): {_ln[:60]}...")
   ```
   (If `SWANFormatError` does not exist, raise `ValueError` — do not invent a new exception hierarchy.)

**Accept:** `grep -n '.\{181,\}'` on a generated L1/L2/L3/L4 INPUT returns nothing; the OBSTACLE block is
multiple lines each ending in ` &` except the last; a fresh cold run's PRINT contains no `No value for
variable YP` and no `not possible to compute`. Add a unit test `test_obstacle_line_wrapping` asserting
(a) every emitted line ≤180 chars and (b) the vertex count round-trips (no vertices dropped by wrapping).

#### T1.0 — All-stationary quasi-stationary full run (the real M1 unblock; supersedes the CFL blocker)
- Owner: `clearskies-api-dev` (emitter + caller) + `clearskies-test-author` (emission guard) + Coordinator (deploy/measure)
- Files: `services/swan_formats.py` (`build_swan_input`), `services/swan_runner.py` (`run_3level` + the full-run caller), and the full-run entry in `providers/nearshore/swan.py`. NEW test under `tests/services/`.
- Architectural: **operator-DECIDED 2026-07-29 (all-stationary; hybrid retained as fallback).** See the
  ledger entry "SWAN propagation scheme & time-integration" for the full design + Fable-verified rationale.

**Design (the ledger holds the detail; this is the task contract):** the full run becomes a
**quasi-stationary sequence at ALL four levels**. Add a THIRD emission mode to `build_swan_input`,
distinct from today's two (nonstationary `COMPUTE NONST` split = T0.3; single `COMPUTE STAT` snapshot =
the hourly fill). The new mode emits: `MODE NONSTATIONARY`; the **time-varying** `INPGRID … NONSTAT`
clauses for WIND/WLEVEL/CURRENT (`swan_formats.py:1575/1587/1599` — kept, NOT dropped); the per-hour
`OUTPUT …` clauses on NESTOUT/TABLE/SPECOUT (`:1783/1887/1906/1934` — kept); a **SEQUENCE of
`COMPUTE STAT [t]`** at each forecast hour (hourly — operator-confirmed; each warm-starts the next);
`HOTFILE` at the end; and the `NUMERIC … alfa=0.01` under-relaxation on the stationary solves
(operator-confirmed — manual's stationary convergence stabilizer; extend the existing `is_structure_grid
and stationary` emission at `:1667` to the all-stationary solves). **The trap (Fable finding 1): do NOT
just emit the COMPUTE-STAT loop while dropping the NONSTAT inputs/OUTPUT clauses — that freezes ONE
weather snapshot across all 72 h with no SWAN error.** Representation (a `compute_mode` enum vs a
`stationary_sequence` flag) is the implementer's call in the scope-ack, provided it cleanly decouples
"time-varying I/O" from "compute mode."
- **Also:** `CIRCLE 36 → 72` directional resolution at `swan_formats.py:1529` (separate the 195°@18 s /
  168°@16 s pair + resolve directional spread). **Iteration cap `mxitst`** left at default 50 for the
  first run, then tuned from the observed convergence curve (do NOT guess it low — a too-low cap fails
  the hardened gate). **Deploy MUST COLDSTART** (`*_hotstart.dat`) — 36→72 invalidates hotfiles in
  spectral space and the F1 guard won't catch it.
- **Do NOT touch:** the single-`COMPUTE STAT` fill path or the T0.3 nonstationary split (both retained —
  the split is the hybrid fallback). Do NOT change `_OBSTACLE_PARAMS` or any coefficient. Do NOT switch
  to BSBT. If the manual/code contradicts this contract at a cited line, STOP and surface.

**Accept:** (1) unit test asserts the new mode emits `MODE NONSTATIONARY` + `NONSTAT` inputs + per-hour
`OUTPUT` + a multi-line `COMPUTE STAT` sequence (one per forecast hour) + `HOTFILE` + `NUMERIC alfa`, and
that inputs are NOT frozen; a generated INPUT has 72-ish `COMPUTE STAT` lines and `CIRCLE … 72 …`.
(2) Deploy (COLDSTART) → a real cold run **completes with the hardened gate PASSING honestly at all four
levels** (no `not possible to compute`, no CFL error, real `valid_fraction`). (3) Coordinator records the
**wall-clock runtime** (first real baseline), the per-iteration convergence curve (to set `mxitst`), and
the T0.5 trace showing whether the swell structure survives to the handoff. This is M1 evidence.

#### T1.2 — Cold full run, all fixes live (M1 evidence)
- Owner: Coordinator (no code)

**Do:** after Phase 0 + T1.1 deploy via `scripts/deploy-marine.sh` (record commit + `ExecMainStartTimestamp`),
run the T0.3 COLDSTART procedure, trigger a full cycle, then capture from the workdirs: (a) no fatal
string in any level's PRINT; (b) first computed timestep == requested window start (no clamp); (c) real
`valid_fraction` (not `n/a`) at L3/L4; (d) `forecast_cache.json` `run_time` == this run.

**Accept:** evidence pasted — a real, non-truncated, all-level computation for the requested cycle, from
a process whose start-time postdates the deploy.

#### T1.3 — Re-verify C-E07 (L4 convergence) + curve-clip on live code
- Owner: Coordinator + `clearskies-auditor`

**Do:** on the T1.2 run, verify L4 `valid_fraction` via the hardened gate, the per-transect handoff
depth (`truncated_at_m` in `/var/log/weewx-clearskies/marine-trace-*.jsonl`, rule-1 vs rule-3), and one
benign curve-clip bbox containing the spot (no phantom bbox 600 m north). Prior "C-E07 passes / 32/32"
evidence is void (stale process, D4).

**Accept:** L4 convergence + curve-clip confirmed on a process postdating deploy, or the true failure
surfaced (not asserted from the old runs).

#### QC Gate 1 — **MILESTONE M1**
- **Mechanical:** SWAN computes all 4 levels; hardened gate passes; window not truncated; `forecast_cache`
  `run_time` == process start (not warm-start/fallback).
- **Adversarial (blind):** auditor briefed to prove the served forecast is cache / warm-start field /
  degraded L2-DWR fallback / stale code — must fail to and name what it ruled out.
- **M1 does NOT claim reality-match** — that is M2.

---

### Phase 2 — Correct the spectrum & handoff (root cause corrected 2026-07-29)

> **Read `MARINE-MODEL-RESTORATION-CONCERNS.md` "DIAGNOSIS UPDATE 2026-07-29" first.** It OVERTURNS the
> earlier C-E05/C-E09 theories: the L4 `TABLE_PT*` are NOT exception values (the L4 CURVE table carries 4
> non-zero partitions; L2 DWR carries 2), and "read each transect's OWN L4 stations" is the **wrong
> target**. The real causes are **defect B** and **defect C**. **Do NOT assume a boundary cap on trains:**
> the "~2 trains at ~13 s" was measured at our L2 grid (inside our own code). Everyone — Surfline included —
> forces from the same NOAA global wave data, and Surfline resolves 3 sharp trains, so the data supports
> them and the loss is likely ours. **T3.0 (real buoy + raw `.spec` vs reality) decides** whether the
> shortfall is our pipeline (fix here) or a genuine limit; until then, recover every train the data holds.

#### T2.0 — Confirm defect B is live (curve-clip rotation, already fixed in `daddf19`)
- Owner: Coordinator + `clearskies-auditor`

**Defect B:** the diagnostic CURVE feeding the L4 handoff spectrum was clipped to a ~7 m degenerate sliver
at ~2 m depth because the curve-clip bbox in `swan_formats.py` (~line 1802) was built axis-aligned and
ignored the L4 grid's ~221° rotation — sampling the handoff in breaking-zone water. **The fix (`daddf19`)
is already in the marine repo.** D4 voided its prior verification; on the T1.2 run confirm the bbox now
tracks the rotated L4 grid and the CURVE samples the intended offshore depth, not a 2 m sliver.

**Accept:** L4 handoff CURVE samples at the intended offshore depth (trace), process postdating deploy. If
B is not effective, STOP — C is downstream of B.

#### T2.1 — Defect C: fix the watershed join that drops partitions → bulk TM01 = 8.1 s
- Owner: `clearskies-api-dev`
- Files: `services/swan_runner.py` (the watershed PT*↔CURVE-station coordinate join); `services/swan_spectral.py`
  (`parse_table_pt_partitions`:949, `watershed_partitions_to_component_format`:1158, `decompose_spectrum`:632)

**Defect C:** the watershed **PT*↔CURVE-station coordinate join** orphans stations (nearest-neighbour
collision on the sub-metre-spaced degenerate curve) → empty `components` → the T4B.2 no-fallback rule
forces a single **bulk** partition, publishing `TM01` (mean, 8.1 s) instead of the partition peak (~13 s)
and collapsing the trains to 1. Same mechanism as the "flat/static across all 67 forecast hours" symptom.

**Do — diagnose then fix (only if the join still drops partitions AFTER B is live, T2.0):**
1. On the T1.2 run, instrument the join in `swan_runner.py`: PT* partitions per station vs how many
   survive the coordinate join into `components`; find where a ≥2-partition station orphans.
2. Fix the join so partitions are not orphaned on the (post-B, non-degenerate) curve, and **surface the
   partition PEAK period, not `TM01`.** Do **NOT** reinstate "each transect reads its own stations" (the
   overturned target).
3. Result: the ~2 real trains survive to `spectralComponents`/`multiSwell`; period is the swell peak
   (~13 s per our boundary, NOT forced to 16–18 s); swell varies across hours.

**Accept:** join-survival count logged (≥ the 2 real trains); published period is the partition peak not
the 8.1 s bulk TM01; swell not flat across 67 h; a **known-answer test** on `parse_table_pt_partitions` (a
synthetic 3-partition table → 3 components). The L2→D1 path is not broken.

#### QC Gate 2
- **Mechanical:** `spectralComponents` carries the trains our boundary actually contains (~2, not forced
  to 3); published period is the partition peak (not 8.1 s bulk TM01); output varies across hours.
- **Adversarial:** auditor tries to show the trains are phantom/duplicate or the period mis-surfaced, and
  confirms the "own-stations" change was NOT re-introduced; known-answer tests pass.
- **Boundary NOT assumed as the cap:** any residual gap to Surfline's 3 trains is decided by T3.0 (real
  buoy + raw `.spec` vs reality), not auto-blamed on WW3 — if the raw data has the trains, the loss is ours
  and stays a Phase 2 fix.

---

### Phase 3 — Validate against reality (**M2**)

#### T3.0 — Ground-truth the boundary against a REAL BUOY and the RAW WW3 spec (prerequisite — do FIRST)
- Owner: `clearskies-api-dev` + Coordinator
- Files audited as SUSPECT: the WW3 `.spec` fetch (`ww3_station_selection`),
  `ww3_spectrum_to_swan_boundary()` / boundary synthesis
- Architectural: none (measurement + audit).

**Why (the reasoning error this fixes):** every "the boundary only has ~2 trains at ~13 s" statement was
measured at our **L2 grid — inside our own SWAN run, downstream of the unaudited WW3 fetch + conversion.**
That cannot distinguish "WW3 is coarse" from "our code smears it." Two facts make **our pipeline the prime
suspect, not the data:** (1) **there is no other open-ocean wave source** — Surfline and every competitor
force from the same NOAA global wave products (WW3 / GFS-wave); Surfline resolving **3 sharp trains at
16–18 s means that structure is derivable from the data we also have**; (2) a **real NDBC buoy** measures
the actual in-water spectrum — ground truth, no model.

**Do (REAL data, never our pipeline's output):**
1. Pull a **real NDBC buoy** spectral-density record near HB (46222 San Pedro Channel / 46253 / 46256) for
   a validation time — observed train count / periods / directions.
2. Pull the **raw** `gfswave.<station>.spec` 2-D spectrum (the untouched NOAA file, before any of our code)
   and partition it **independently** of our pipeline.
3. Trace what **our** `ww3_spectrum_to_swan_boundary()` produces from that same raw spec.
Compare all four: **real buoy vs raw WW3 `.spec` vs our-converted-boundary vs Surfline LOTUS**, same time.

**Decide:** (a) raw WW3/buoy show the trains but our conversion loses them → **OUR bug — fix in Track A
(Phase 2); M2 does not pass until fixed** ← *leading hypothesis*; (b) raw WW3 lacks what the buoy/Surfline
show → wrong station/product/sub-sampling in our fetch → still fixable, escalate; (c) buoy AND raw WW3 AND
Surfline all genuinely agree on fewer/shorter trains than assumed → only THEN a real limit. **Set nothing
in M2's period/train handling until this returns.**

**Accept:** a comparison table (real buoy vs raw `.spec` vs our-converted-boundary vs Surfline) with the
verdict and, if (a)/(b), the exact stage in our code that drops the structure.

#### T3.1 — Reality validation vs the Surfline baseline (PINNED tolerance)
- Owner: Coordinator + `clearskies-auditor`

**Do:** compare our surf **FACE** to Surfline's surf **FACE** (never swell height — that error was made and
corrected). Baseline = Surfline's **contemporaneous** forecast at validation time (the 07-28/29 numbers
are illustrative, not a hardcoded pass condition). Pinned thresholds so the gate is mechanical:
- **Face (the quantity we CAN match):** range-overlap between our face range and Surfline's ≥ **50%**, AND
  our face midpoint within **±25%** of Surfline's midpoint.
- **Primary period & train count:** compare ours to Surfline **and the real buoy (T3.0)**, but **attribute
  the gap only per T3.0's verdict** — do NOT pre-attribute to the boundary. If T3.0 proves the raw buoy/WW3
  genuinely lack the trains → real limit (report). If T3.0 shows our pipeline loses trains the raw data has
  → **Track-A bug; M2 does not pass until it is fixed** (the leading hypothesis).
- **Match-or-beat gate (C-E09):** the served L4→D1 path must **match or beat** the L2→D1 path (which gave
  face 4.6–5.0 ft / ~17.5 s against reality) before rule-1 (L4) is trusted; if it does not, the stopgap is
  to force the L2→D1 handoff (available per C-E09).
- **Flat output is a defect** — a 3-day forecast whose swell never moves fails regardless of the numbers.

**Accept:** face within the pinned tolerance vs contemporaneous Surfline; period/train gap quantified and
attributed to C-E12; L4→D1 ≥ L2→D1; no flat output.

#### T3.2 — (Conditional) Phase F wind-sea source term
- Owner: `clearskies-api-dev` — **run only if BOTH:** (i) the operator has **re-recorded the Phase F
  pre-approval in THIS plan's ledger** (the prior plan's §0B.4 does not authorize it here — architectural
  block); AND (ii) T3.1's gap analysis shows a wind-sea partition (the 10 s S train) Phase 2 did not
  recover. Gated on a **known-answer test** for the Young & Verhagen (1996) growth kernel. If either is
  unmet, do NOT run it.

#### QC Gate 3 — **MILESTONE M2**
- **Mechanical:** the T3.1 comparison table (ours vs contemporaneous Surfline) meets the pinned face
  tolerance; the period/train gap is quantified and attributed to C-E12; L4→D1 ≥ L2→D1.
- **Shadow-bias handling:** the headline face aggregate either **excludes** structure-shadowed transects
  or records that T4.4's D5 diagnosis shows the shadow classification does not materially bias it (run
  T4.4 before closing M2 — non-architectural, may run in parallel with Track A).
- **Adversarial:** auditor validates against reality independently; checks total-right/distribution-wrong,
  flat output, degenerate-sample closure (n=1 partition ≠ pass); known-answer tests green.

---

## TRACK B — OBSTACLE REPRESENTATION OVERHAUL

**Gate to start:** M1 reached + operator sign-off on the architectural items (bathymetry-injection fork;
coefficient changes; draw-tool polygon mode). **Both research briefs are in hand and every number below
is pinned from them, not guessed:** `SWAN-OBSTACLE-BEST-PRACTICES-2026-07-29.md` (obstacle mechanics,
coefficients) and `BATHYMETRY-STRUCTURES-BEST-PRACTICES-2026-07-29.md` (injection, presence check). The
coefficient edits (T4.3) are formula changes (architectural trigger 1) — do not touch them until the
operator signs off in the ledger.

**The rule that governs the whole track (brief §Decision rule):** a SWAN OBSTACLE line **carries no
width** — two structures of different widths crossing the same grid cell are identical to SWAN. Real width
exists **only** in the bathymetry. Split by **width ÷ L4 cell (10 m)**, but note the research caveat: at a
10 m grid a structure **narrower than ~20–30 m is borderline** (≈1–3 cells) and belongs on the obstacle
line, not the footprint path.

### Phase 4 — Structure representation

#### T4.0 — Structure geometry normalizer (new module)
- Owner: `clearskies-api-dev`
- File: NEW `services/structure_geometry.py`; dep **`shapely` only** (in `[nearshore]`). **`rasterio` is
  NOT a current dependency — do not import it** (see Track B pending list).
- Architectural: none (new pure-geometry helper; emits nothing to SWAN itself).

**Do:** implement `normalize_structure(coords_lonlat, s_type, l4_mesh_m, width_m=None) -> StructureShape`
where `StructureShape` carries `{kind: "line"|"footprint", vertices_lonlat, width_m, width_cells}`.
1. Build a shapely geometry from `coords_lonlat` (closed ring → polygon; open way → linestring).
2. **Centerline + width (pick the method by shape):** compute the **oriented minimum bounding box** (OMBB).
   If the polygon is **near-straight** (max vertex deviation from the OMBB long axis `< l4_mesh_m`), the
   centerline is that long axis (**2 points**) and `width_m` = the OMBB short side. Otherwise (curved /
   dogleg — a jetty elbow) the centerline is the polygon's **medial-axis skeleton** simplified to ≤6
   vertices. For a linestring with operator `width_m`, the line IS the centerline.
3. **Simplify** the centerline with `shapely.simplify` (Douglas–Peucker, tol ~½·`l4_mesh_m`).
4. **Classify:** `width_cells = width_m / l4_mesh_m`. `kind = "footprint"` iff `width_cells ≥ 3.0` **and**
   `s_type` solid (`breakwater|jetty|groin|seawall|mole`); else `kind = "line"` — all piers, **and any solid
   structure `< 3` cells (~30 m) wide, per the ~20–30 m-borderline caveat above.**

**Accept:** KAT tests — a straight 40 m breakwater ring → `footprint`, `width_cells≈4`, 2-point centerline;
a **25 m** breakwater → `line` (2.5 cells, below the 3-cell threshold); a dogleg jetty → skeleton centerline
≤6 vertices; the HB 35-vertex pier ring → `line` (pier), simplified centerline.

#### T4.1 — Route structures by kind in the OBSTACLE emitter
- Owner: `clearskies-api-dev`
- File: `services/swan_formats.py`, structure loop at lines 1695–1713 (the `_OBSTACLE_PARAMS` block)
- Architectural: none (routing existing geometry; no new physics).

**Do:** before the emit loop, call `normalize_structure(...)` per structure. Then:
- `kind == "line"` → emit the `OBSTACLE {params} LINE …` for the **simplified centerline**, wrapped per
  T1.1 (≤180 chars, `&`). This replaces feeding the raw 35-vertex ring.
- `kind == "footprint"` → do **NOT** emit an OBSTACLE line; add the structure to a `bathymetry_structures`
  list handed to T4.2 (the footprint blocks in the bottom grid instead).

**Accept:** HB pier emits a ≤6-vertex OBSTACLE line (not 35); a configured wide breakwater emits **no**
OBSTACLE line and appears in `bathymetry_structures`; unit test asserts the routing per `kind`.

#### T4.2 — Structure → bathymetry injection (the new data path)
- Owner: `clearskies-api-dev`
- Files: `services/swan_formats.py` — **`cudem_to_swan_bottom` (defined at line 402)** — and its caller
  `services/swan_runner.py` (~4387–4396, where it produces `bottom_text` and `BOTTOM.txt` is written)
- Architectural: **operator sign-off required — the bathymetry-injection fork.** New data path (structure
  geometry now drives BOTTOM). Do NOT implement before sign-off.

**Do:** `cudem_to_swan_bottom` currently **streams bilinear source-samples straight into strings** (there is
no intermediate SWAN-grid depth array to burn into). Restructure it to **materialize → burn → serialize**:
build the numeric L4 depth array, burn the footprints, then serialize to text. Add an optional
`bathymetry_structures` arg **and** a `max_water_level_m` arg — there is **no tide input to this function
today**, so thread it from the runner as the max (tide+surge+setup) over the forecast window. Apply
injection to the **L4 grid only** (the surf grid; L1–L3 do not resolve structures). Then:
1. **Rasterize** each footprint onto the L4 grid by **coverage fraction**, not cell-center: classify a cell
   emergent where polygon coverage ≥ **0.5** (area-majority). **Compute the coverage fraction in pure
   shapely** (cell-polygon ∩ footprint area ÷ cell area) — `rasterio`/`exactextract` are NOT current deps.
   Then **enforce along-axis connectivity** (morphological closing) so no one-cell hole opens a spurious
   channel, and **grade the outer ring** one step shallower to cut staircase over-reflection (brief §A2).
2. **Already-present check (MANDATORY, brief §B5 — gate on BOTH signals):** (a) **emergent-cell fraction** =
   share of footprint cells whose resolved depth is already emergent (≥ the max-water-level reference); (b)
   **elevation-anomaly** = mask the footprint, IDW-fill a "no-structure" background from surrounding cells,
   difference — a residual ridge of **≥ ~1 m** means the structure is already in the DEM. If emergent
   fraction **≥ 0.65 AND** anomaly ridge present → **skip injection**, and log/invariant `structure X
   already in bathymetry (N% emergent, +M m anomaly) — not injected`. Otherwise inject, filling **only the
   currently-wet cells** (idempotent; leaves DEM-present cells untouched). Record injected-vs-skipped cell
   counts every build. **(Piers never reach here — they are `kind="line"`, T4.0.)**
3. **Emergent value:** a fixed dry elevation above the run's **max water level** (max tide+surge+setup) +
   margin — **in the DEM's vertical datum** (convert via `operator_meta` datum / VDatum; brief §A4). In
   SWAN's positive-down BOTTOM convention this is a negative/near-zero depth that keeps total depth < 0
   across the run; it is **NOT** the `MISSING_DEPTH_EXCVAL` sentinel (that means "unknown depth" and trips
   the single-width-channel filter). Use **true crest elevation** instead only for a structure flagged as
   overtopping-relevant (brief §A3).

**Accept:** a burned breakwater shows an emergent ridge in `BOTTOM.txt` and a lee wave-shadow in the L4
TABLE (Hs behind < Hs beside); a structure **already emergent in the DEM** → **0 cells injected** (logged);
no one-cell channel between footprint and shore; KAT test on the rasterizer (coverage-fraction, connectivity)
+ a presence-check test (all-present → skip; none-present → full fill; half → half).

#### T4.3 — Per-type coefficients (FORMULA — operator sign-off each)
- Owner: `clearskies-api-dev`
- File: `services/swan_formats.py` `_OBSTACLE_PARAMS`, lines 1688–1694
- Architectural: **trigger 1 (formula constants). Each value change needs operator sign-off in the ledger.**

**Do (only signed-off values):** `Kt` is a wave-HEIGHT ratio — square-root any energy figure.
- `pier: "TRANSM 0.82"` → **`"TRANSM 0.74"`** (Elgar 2001 best-fit 45 % energy blocking; 0.82 is the
  low-blocking edge of the measured 0.71–0.84 band). Directional; pair with scour bathymetry.
- `seawall: "REFL 0.5"` → **`"REFL 0.9 RSPEC"`** (smooth vertical / sheet-pile wall reflects ~0.9 not 0.5;
  JMSE 2021).
- `breakwater`/`jetty`/`groin` **keep their current `DAM …` constant forms for M2** — swap only to a
  **static, cited** constant, never a computed one. The brief's **dynamic** ideas — per-segment crest `Rc`
  that tracks the tide, and a Seelig–Ahrens `Kr = A·ξ²/(ξ²+B)` reflection default — need data no config
  field carries (crest elevation) or a per-run, wave-dependent Iribarren number that SWAN's **constant**
  `REFL` cannot take. **Defer both to a separate signed-off design task (Phase 5)** — do NOT implement them
  in this constant swap (that would be design work smuggled in as a code edit).

**Accept:** each changed constant cites its source in a code comment; static values only; a
coefficient-sensitivity run is recorded at QC Gate 4 (not a blind swap).

#### T4.4 — Diagnose structure shadowing 0/32 (D5): geometry defect, or over-firing invariant?
- Owner: `clearskies-api-dev`
- Files: `services/transect_handoff.py` (`compute_transect_shadows`, `_compute_shadow_span`, `_in_shadow`,
  `_structure_seaward_tip_depth`); `services/swan_formats.py` (`compute_spot_transects`:594); `invariants.py:68`
- Architectural: none (diagnosis + a wiring fix).

**Correction to the earlier premise (do NOT repeat it):** the `bathy_fn = lambda: None` fallback
(`swan_formats.py:762–766`) does **not** cause 0/32. `_structure_seaward_tip_depth` returns **0.0, not
None** (`transect_handoff.py:332`), so the pier is **still included**; the shadow span is computed **purely
geometrically** (`_compute_shadow_span` takes no depth; `_in_shadow`:380–392 tests u/v over
`beach_facing ± 30°`). Wiring a real depth lookup changes the LOG line, not the classification. The
diagnosis (D5) left this **OPEN** — so this task diagnoses before fixing.

**Do — part A (diagnose, no fix):** instrument `_compute_shadow_span`/`_in_shadow` on the real HB fan.
Decide whether 0/32 is (i) a **geometry defect** (shadow angle/span computed wrong) → fix the geometry; or
(ii) **geometrically correct** for HB's segment-vs-pier bearing → then marine **invariant 3 over-fires**
(C-E06 possibility (a)) and the fix is to **rescope invariant 3**, not the geometry. Report which, with the
numbers.
**Do — part B (small, separate):** wire a real CUDEM `bathymetry_profile_fn` so the `seaward tip depth =
0.0 m` log stops lying — **acceptance is only "the log shows a real depth,"** NOT a change to 0/32.

**Note — 6 call sites, not 2 (choose ONE place):** `compute_spot_transects` is called WITHOUT
`bathymetry_profile_fn` at `swan_runner.py:3246` & `:4670`, `grid_sizing_chain.py:1218` & `:1400`,
`endpoints/surf.py:670`, `endpoints/beach_profile.py:947` (the `bathymetry_profile_fn=` at
`swan_formats.py:1128` is an internal pass-through, not a call site). To avoid editing six callers, **route
the depth lookup inside `compute_spot_transects`** (resolve from `bathymetry_resolver` when the arg is None).

**Accept:** a findings note stating (i) vs (ii) with the geometry numbers; if (i), the fix makes HB classify
a non-zero shadowed count; if (ii), invariant 3 is rescoped so it no longer fires on a correct 0/32; Part B's
log shows a real tip depth.

#### T4.5 — Structure coordinates must round-trip through admin save (C-E02)
- Owner: `clearskies-api-dev` (stack repo)
- File: `weewx_clearskies_config/admin/routes.py` (the `structure_{n}_coordinates` handling near line 2189)
- Architectural: none (data-loss bug fix).

**Finding (concerns C-E02):** an admin save produced `coordinates: None` in live `marine.conf` — the OSM
polygon was dropped. **BUT the admin fix may already be deployed:** stack HEAD `19d9332` (2026-07-27,
"persist discovered structure geometry from wizard through apply") added the `structure_{n}_coordinates`
round-trip at `admin/routes.py:2188–2198` and the hidden field at `templates/admin/marine.html:365`. The
observed loss was likely on a build predating `19d9332`.

**Do:** (1) verify `19d9332` is the deployed stack; (2) re-run the admin round-trip live (edit a structure,
read back `marine.conf`); (3) **only if it still drops `coordinates`**, diagnose the residual defect.
Regardless, **add the round-trip guard test** (a structure saved via admin retains `coordinates`, endpoints
within ~10 m of the OSM base/tip) — valuable even if the bug is already fixed.

**Accept:** the guard test exists and passes on the deployed stack; if a residual drop is found it is fixed
and the guard fails on the pre-fix code.

#### T4.6 — Draw-tool polygon mode (only if operator approves)
- Owner: `clearskies-dashboard-dev` (stack repo)
- File: `templates/wizard/step_marine.html` (currently `polygon: false` at line 1287, `L.Draw.Polyline` at 1456)
- **Do:** enable `L.Draw.Polygon` alongside the polyline; on `CREATED`, capture the ring into the existing
  `_coordinates` hidden field (same `[lon,lat]` contract). Wizard/admin already consume `coordinates`.

**QC Gate 4 (brief §Validation):**
- **Physics vs reality:** HB has **no instrumented alongshore array** (Elgar's method needs the pressure
  sensors Duck had; a Surfline cam gives face at one break, not alongshore Hs ratios). So the **executable**
  checks are the **coefficient sensitivity sweep** (0/30/45/60 % blocking → report the sensitivity, not
  just a best fit) and the **direction-shift** check (blocking shifts mean direction toward normal in the
  shadow). The alongshore-gradient comparison runs **only if** an operator/cam observation pair north vs
  south of the pier on an oblique-swell day is available (named at that time, with its precision) —
  otherwise it is explicitly **deferred, not softened into a pass**.
- **Bathymetry injection:** a burned breakwater casts a lee shadow with **no single-cell channel** and no
  staircase over-reflection; the presence check skips a DEM-already-present structure (injected count = 0).
- Adversarial audit; known-answer tests on the normalizer + rasterizer.

---

## TRACK C — CLEANUP & OPEN DECISIONS

### Phase 5
- **D6a** grid-sizing chain type bug: `StructureConfig` vs `dict` split (`grid_sizing_chain.py:1270`).
- **D6b** extend geometry guard to L4-only changes (**approved**; update `ARCHITECTURE.md` same change).
- **D6c** the enlarged-L1 (Bolsa) WW3 station selection finds **0 qualifying stations within 18.5 km** →
  every cycle refuses. Distinct from the C-E01/C-E03 adjacency items; resolve before Bolsa is re-enabled.
- **D2 permanent hotstart mechanism** — **RESOLVED in T0.3** (fix the timestamp; keep hotstart). No further
  Phase 5 work unless the split-COMPUTE proves insufficient in production.
- **C-E12 — boundary train/period resolution** (operator-PINNED). **NOT assumed to be a real cap** — the
  "~2 trains at 13 s" was a pipeline-internal (L2) number. T3.0 measures a **real buoy + the raw `.spec`
  vs reality** first. Everyone forces from the same NOAA global wave data and Surfline resolves 3 trains,
  so "no data source" is NOT the cause; the likely finding is a loss in our own
  `ww3_spectrum_to_swan_boundary()` / fetch — a **Track-A fix**, not a Phase 5 cap. This entry only
  survives if T3.0 proves the raw data itself genuinely lacks what the buoy/Surfline show.
- **Deferred T4.3 dynamic coefficients** — per-segment DAM crest `Rc`, Seelig–Ahrens reflection (needs a
  config crest field + per-run Iribarren; a separate signed-off design task).
- **D7 publish policy** (production last-good vs degraded; parked to cutover).
- **C-E10** `CLEARSKIES_MARINE_API_URL` unset; **C-E11** OFS future-dated 404; **C-E01/C-E03** Bolsa
  adjacency; **C-E04** bathymetry re-fetch; **C-E08** L4 `INPGRID WIND`.
- **Doc drift** `reference/clearskies-dev.md` services table (8767/8770 → unified 8780, seen at lines
  138–139/270).

---

## Decision log
- **2026-07-29** — Plan created from the Fable diagnosis + operator obstacle discussion. Track A written
  to the line against verified current code (gate `_check_convergence`:4993; OBSTACLE emitter
  `swan_formats.py`:1706; runner loop `service.py`:457; `deploy-marine.sh` already restarts). Concerns
  list superseded by the diagnosis. SWAN-docs-are-local rule added to `reference/clearskies-dev.md` +
  `rules/agents.md`.
- **2026-07-29** — Operator: KEEP hotstart, do NOT drop it (compute overhead); fix the timestamp
  (split-COMPUTE, T0.3). Two research briefs (SWAN-obstacle, bathymetry-structures) landed and Track B
  pinned to their numbers.
- **2026-07-29** — **Fable adversarial review incorporated (17 findings).** Fixes: T0.3 now actually
  implements the split-COMPUTE (was contradictory / unwritten) + a stale-hotfile timestamp guard; M2
  re-derived — face is the matchable quantity (pinned tolerance), period/train count **capped by C-E12**
  (WW3 boundary), gap attributed not failed; Phase 2 rewritten to the corrected **defect-B(done)/defect-C
  join** root cause (dropped the overturned "own-stations" fix); T4.4 corrected (tip depth returns 0.0 not
  None → 0/32 is geometric → diagnose-first; 6 call sites not 2); T4.2 file corrected to
  `swan_formats.py:402` + materialize-burn-serialize + shapely-only (rasterio is not a dep → flagged
  trigger 7); T4.5 made verify-first (fix may be live at stack `19d9332`); T4.0 method/threshold made
  consistent (OMBB/skeleton, ≥3 cells); T0.0 added (preserve forensic artifacts before the loop overwrites
  them); T0.4 converged fixture synthesized (real one no longer on disk); no-TABLE-L3/L4 gate fail added;
  Phase F pre-approval must be re-recorded in this ledger; C-E12 + D6c given Phase 5 homes; nits fixed.
- **2026-07-29** — **T0.5 added (operator directive): full-pipeline spectral trace WW3→L4.** A deep dive
  this session established, by reading code + real trace/cache data, that: (1) the offshore boundary we
  feed SWAN DOES carry directional structure (a real boundary had a dominant long-period swell from S/SSW
  + a separate W windsea); (2) the published dominant swell / `multiSwell` is sourced from the **15 m
  deep-water reference** (`_spectral_dwr_results`, `SPEC_DWR`/`TABLE_DWR` at `_compute_15m_point`), NOT
  the surf zone — the SURF-23 rebind (`swan_runner.py`:5384) leaves the DWR slot at 15 m, and Invariant 7
  (`surf.py`:1144) guards it; the `field_provenance` "stage: handoff_selection_merge" stamp is a
  hardcoded label, not the data path. So the three-swell collapse is **upstream of the 15 m point**, and
  the publish/partition/join code faithfully reports an already-collapsed spectrum. Ad-hoc forensics
  could not pin the exact stage because every run deletes its per-level files and three different runs
  were being compared. T0.5 instruments every real handoff (WW3 raw → L1 boundary → nest → L2 DWR → nest
  → L3/L4 handoff) with a directional summary (peak period + peak/mean direction per period band) + full
  matrix, gated by `CLEARSKIES_MARINE_DEBUG_TRACE`. **Its readout is the arbiter for Phase 2 (defect C)
  and Phase 3 (T3.0): the "watershed join drops partitions → bulk TM01 8.1 s" hypothesis must be
  re-checked against the trace before any Phase 2 code change — the 8.1 s was measured at a 2 m surf-zone
  sample, not the 15 m swell catalog.**
