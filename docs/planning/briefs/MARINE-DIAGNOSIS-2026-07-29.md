# Marine Model Diagnosis — why the surf forecast is bogus (2026-07-29)

Diagnosis session (Fable), evidence gathered live from librewxr + deployed/local code + the SWAN
user manual. Every claim below is **VERIFIED** against a primary source (cited) unless marked
OPEN. This brief supersedes the failure narrative in
`MARINE-L4-DEGRADED-HANDOFF-2026-07-29.md` where they conflict.

## TL;DR — seven defects, three of them load-bearing

The served forecast is not a bad model run — **it is not a model run at all.** In the currently
served cycle, SWAN computed *nothing at any level*: a severe input error (the over-long OBSTACLE
line, D1) put SWAN into "not possible to compute" at every timestep, and the numbers that got
published are the un-iterated warm-start field from the previous evening's real run, served
through a convergence gate that cannot detect any of this (D3), over a 7-hour window truncated
by the documented hotstart end-of-window defect (D2). Separately, all "passing" evidence
gathered overnight (01:14, 03:33 runs) is void because the service process was running stale
pre-fix code the whole time (D4).

## Verified timeline (journal + workdirs + git reflog + systemd)

| Time (UTC) | Event | Evidence |
|---|---|---|
| Jul 28 22:40:57 | Service restart. **Process runs code as of this instant until 04:53:17.** | systemd `ExecMainStartTimestamp`; reflog |
| 22:41:32 | POST /config → sizing chain **crashes**: `AttributeError: 'StructureConfig' object has no attribute 'get'` at `grid_sizing_chain.py:1270` (running pre-29eb499 code) | journal traceback |
| 22:44:30 | `git pull` → 29eb499 lands **on disk** (process not restarted) | reflog |
| 22:45:07 | POST /config → sizing chain completes; L3/L4 bathymetry caches written | journal |
| 22:45:48–23:10 | **Cold full run, cycle 07-28T18:00Z, window 07-28T18→07-31T18.** L1/L2/L3 "OK" (vacuous, see D3), hotstarts saved **stamped 20260731.180000**. L4 **FAILED 0% valid** (pre-C-E07 code). L2-DWR fallback published (1.7 MB cache). | journal; hotfile stamps |
| 00:59:48 | pull → **641b903 (C-E07 L4 INPGRID BOTTOM fix) on disk only — never in the running process until 04:53** | reflog |
| 01:00–01:14 | Re-run of cycle 07-29T00:00 (window 07-29T00→08-01T00). All levels warm-start from 07-31T18-stamped hotfiles → **tbegc clamp → only the 66–72 h tail computes.** L4 "OK 100%" *on stale code over a 7 h tail*; **SPECOUT empty → 1-D pipeline fell back to a fabricated bulk partition (Hs=0.02 m, Tp=1.6 s), "SwellTrack failed on all transects", degraded=True** | journal 01:14:14 |
| 02:58–03:33 | Same cycle re-run (`prev: None` — the cycle marker never advances, D2b). Same warm-clamp pattern. L4 "OK 100%" again on stale code; cache published **0.4 MB** (7-hour window). | journal |
| 03:23 | POST /config with **2 spots** (Bolsa added) → every subsequent run refuses: `BoundaryNotViableError: 0 suitable ocean stations` for the enlarged L1 (D6c) | journal 03:35–05:15 |
| 04:53:04 | pull → daddf19 (curve-clip fix); **04:53:17 service restart — first process actually running the session's fixes** | reflog; systemd |
| 05:15:37 | POST /config (HB-only) → chain completes; geometry compare finds no L1/L2/L3 change → hotstarts (correctly per its spec) not cleared | journal |
| 05:16:49–05:22 | The one run with all fixes live. All 4 levels carry the malformed OBSTACLE line → severe error → **"not possible to compute, first iteration" at every timestep** (verified L2 PRINT, all 36 steps). All levels warm-clamped to the 07-31T18→08-01T00 tail. L4 TABLE 100% exception values → honest FAIL 0% → **L2-DWR fallback published: 7 hours, waveHeightAtBreak=null ×7, 0.2 MB — the currently served cache.** | PRINT files; TABLE files; journal |

The "13.46 s / 1.17 m" swell in the served cache is SWAN's **un-iterated warm-start field**
(the last real physics is the 22:45 cold run of cycle 07-28T18:00Z) sampled at the DWR point —
not a computation for this cycle. `waveHeightAtBreak` is null because L4 failed → no per-transect
handoff → SwellTrack never ran.

## D1 — OBSTACLE line exceeds SWAN's 180-char input limit; a severe error kills ALL computation

- **SWAN manual (verified, not memory):** "The maximum length of the input lines is 180
  characters" (§ Command syntax and input/output limitations, swanuse node22); continuation is
  `&` or `_` at end of line (node48).
- `swan_formats.py:1707` emits `OBSTACLE TRANSM 0.82 LINE <35 vertices>` as **one ~600-char
  line**. Chars past 180 are discarded mid-coordinate → `** Severe error: No value for variable
  YP`.
- **The same line is emitted into all four levels' INPUTs** (verified: L1 INPUT:30, L2 INPUT:30,
  L3 INPUT:30, L4 INPUT). All four PRINTs carry the severe error.
- Consequence measured: SWAN 41.51AB with this severe error prints **"not possible to compute,
  first iteration" at every timestep** and solves nothing. L4's TABLE_1.txt is 100% exception
  values (-9/-99/-999). L2's DWR table carries plausible-looking values — the warm-start field,
  un-iterated.
- **Fix (mechanical, not architectural):** wrap the coordinate list across continuation lines
  (each ≤180 chars, trailing `&`). Add an emitter guard: refuse/split ANY generated INPUT line
  >180 chars. **Operator decision still open (do not pre-empt):** footprint-polygon vs
  thin-barrier representation and correct pile-pier physics — line-wrapping is only the minimal
  change that makes SWAN parse the existing closed ring.

## D2 — Hotstart end-of-window stamp truncates every warm run to a 7-hour tail (documented defect, now proven live)

- `HOTFILE 'hotstart.dat'` is emitted **after** COMPUTE → the saved field carries the window END
  (verified stamps: L1/L2/L3 `20260801.000000`; L4's 03:33 save `20260731.180000`).
- Any same-cycle re-run or next cycle warm-starts, SWAN reports `tbegc before current time` and
  clamps the start to the hotfile time → only the tail computes. The served 7-hour window
  (07-31T18→08-01T00) is exactly this clamp. Authority: `docs/reference/swan-commands-extract.md`
  §"WHY THE HOTSTART ACTUALLY FAILS".
- **D2b amplifier:** `service.py` `_marine_runner_loop` only advances `last_hrrr_cycle` after the
  whole spot pipeline succeeds (service.py:335-337, 365). It has **never** succeeded (`prev:
  None` on every run all night), so the loop re-runs the same cycle every 5 minutes forever —
  the exact pattern that arms the clamp.
- Likely secondary: the clamp appears to misalign nonstationary input reads — L4's 3 ×
  "Unexpected end of file while reading UNKNOWN_FILE" during COMPUTE (nest/wind/wlevel echoes).
- **Fix: operator decision** (per the extract doc): (a) write hotfile at the next cycle's start
  time, (b) chain windows forward, (c) drop hotstart. **Cheap immediate mitigation for approval:**
  delete `/var/run/weewx-clearskies/swan/*_hotstart.dat` → next run cold-starts. A cold full
  L1→L3 took ~25 min on 2026-07-28 (22:45→23:10), within budget.
- **Gate addition regardless of option chosen:** a run whose computed window ≠ requested window
  must FAIL convergence (detect the tbegc clamp / first computed timestep in PRINT).

## D3 — The convergence gate is vacuous for L1/L2/L3 and blind to every failure mode that occurred

All in `services/swan_runner.py` (`_check_convergence`, ~4993–5250):

1. **PRINT scan only matches `******` overflow markers** (and stationary accuracy). It does not
   fail on `Severe error`, `not possible to compute`, or `tbegc` — all three were in every
   PRINT.
2. The separate severe-error check at swan_runner.py:4965-4975 reads **stderr only**; these
   severe errors appear in the PRINT file, not stderr.
3. **`valid_fraction=None` (no parseable timestep data) is treated as a pass** — the code
   comment says "If no timestep data, leave valid_fraction=None → log 100% (best-effort)"
   (swan_runner.py:5190). L1/L2/L3 emit no per-timestep TABLE the parser reads, so their gate
   passes **vacuously on every run** — including runs where SWAN computed nothing.
4. The contradictory log lines ("valid_fraction=100.0%" then "valid_fraction=0.0%" for the same
   level) are two different None-fallbacks (5208 logs 100.0, 5235 logs 0.0) plus a swapped
   `accuracy` field — cosmetic, but it wrecked run forensics all session.
- **Fix:** scan PRINT for `Severe error` / `not possible to compute` / `tbegc`; treat
  valid_fraction=None as FAIL (or make each level parse an output that actually exists for it);
  add the computed-window check from D2; fix the two log lines.

## D4 — Stale-process deploys void the session's evidence

The process that produced the 01:14 and 03:33 "L4 converges 100%, 32/32 transects" evidence
started 22:40:57 — **before** 641b903 (C-E07) and daddf19 were pulled. Pulls landed on disk at
00:59, 03:32, 04:53 with no restart until 04:53:17. Therefore:

- **C-E07 (L4 convergence fix) has never been verified.** The only run with it live (05:22)
  failed L4 at 0% — though for reasons dominated by D1/D2, so it is *also not refuted*.
- The handoff brief's "B validated on the 03:33 run" is void the same way.
- daddf19 (curve-clip) IS live now and behaving sanely post-restart (one benign clip warning at
  05:21, bbox contains the spot — vs the pre-fix phantom bbox 600 m north of the spot at 23:03,
  which clipped every transect to a degenerate band: "deep end clipped from 171.0 m to
  −990.4 m").
- **Fix:** deploy flow must restart the service after every pull (check
  `scripts/deploy-marine.sh` does; if it does, the 00:59/03:32 pulls bypassed the script);
  coordinator rule: results only count from a process whose start time postdates the deploy.

## D5 — Structure shadowing classifies 0/32 transects shadowed ("seaward tip depth = 0.0 m")

`transect_handoff` logs `Structure pier(567m): seaward tip depth = 0.0 m` and `shadowed=False,
structures=[]` for all 32 transects at BOTH the config-push and runtime call sites → marine
invariant 3 fires on every push and every cycle. The Phases brief triaged the tip-depth log as
cosmetic, but the 0/32 classification is functional: no transect is ever marked
structure-affected, so headline metrics include pier-shadowed transects. The handoff brief's
attribution of invariant 3 to the malformed OBSTACLE is **wrong** — it fires at config time,
before SWAN runs. OPEN: whether shadow geometry actually consumes tip depth; needs a targeted
look at `compute_transect_shadows()` inputs (`bathymetry_profile_fn` missing at both call
sites).

## D6 — Grid-sizing chain instability (three sub-items)

- (a) The `StructureConfig.get` crash (22:41) aborts the chain mid-way, leaving
  `swan_grid_sizing.json` referencing L3/L4 bathymetry caches that were never downloaded → runs
  then refuse with the (misleading) "vertical datums do not agree / no cache" error (seen
  22:03–22:36). Current code at that line reads `.coordinates` — **OPEN:** identify the fixing
  commit and confirm the dict-vs-StructureConfig type split is gone everywhere in the chain
  (crash at 22:41 vs completion at 22:45 in the same process is unexplained; likely two call
  paths hand different types).
- (b) The F1 geometry guard compares **L1/L2 bbox+resolution and L3 clusters only** (per
  ARCHITECTURE.md) — an L4-only geometry change never trips a cold start. Extending it to L4
  changes documented behavior → needs operator sign-off (doc-code sync).
- (c) The 2-spot (Bolsa) config produced an L1 extent for which WW3 station selection finds **0
  qualifying stations within 18.5 km** → every cycle 03:35–05:15 refused. Must be resolved
  before Bolsa returns (C-E01/C-E03 adjacency).

## D7 — Degraded fallback overwrote a better cache

The 05:22 L2-DWR fallback (7 h, null break heights) replaced the previous fuller cache.
"Failed runs never overwrite the forecast cache" holds per-SWAN-level, but the spot pipeline
still publishes the degraded product. **Operator policy question:** should a shorter/degraded
result ever replace a longer last-good one, or should the service serve last-good with honest
staleness?

## Recommended fix order (for the coordinating session)

1. **Re-baseline reality:** confirm deploy-restart discipline (D4); operator-approve deleting
   the stale hotfiles (D2 mitigation) so the next run is cold.
2. **D1 emitter fix** (line-wrap ≤180 chars with `&`, + >180-char guard) — mechanical; unblocks
   all four levels.
3. **D3 gate hardening** (PRINT severe/not-possible/tbegc scan; None→FAIL; window check; log
   fix) — without this, nothing else is verifiable.
4. **Cold full run; honestly re-verify C-E07 (L4 convergence) and daddf19 (curve-clip)** on the
   now-current process. Only then resume C-E05/C-E09/Gate-D validation against the operator's
   Surfline baseline.
5. **D5 shadow/tip-depth**, **D6a chain type bug audit**, **D2 permanent option**, **D6b guard
   scope**, **D7 publish policy** — the last three are operator decisions to queue.

## Corrections to the prior handoff brief

- "01:14/03:33 runs PASS valid_fraction=100%" — true only as a 7-hour-tail, stale-code,
  vacuous-for-L1/L2/L3 pass. Not evidence of a working model.
- "Invariant 3 fires because the OBSTACLE line is malformed" — wrong; it fires at config time
  from the shadow computation (D5).
- "hotfile advanced past the window start across repeated same-cycle re-runs" (hypothesis) —
  confirmed, with the mechanism being D2 + D2b.
- The unexplained 03:33 L4 hotfile stamp (20260731.180000 while siblings say 20260801.000000)
  remains OPEN but is mooted by dropping/fixing hotstart.
