# YQ-1 — Energy-deficit investigation: L3→1D bulk-fallback mechanism, frequency, and energy chain

**Repo pinned against:** `weewx-clearskies-marine` @ `d74c578` (local repo HEAD at dispatch time),
working tree clean. All file:line citations below are against this commit unless noted. Per the
brief, physics is stated identical to `bdf4db8` (Y0's pin commit).

**Read-only throughout.** No code edits, no restarts, no writes/deletes on `librewxr`, no SWAN
runs, no pytest. All `librewxr` commands were `sudo journalctl -u weewx-clearskies-marine ...` and
read-only `sudo ls`/`sudo stat`/`sudo python3 -c "json.load(...)"` against
`/run/weewx-clearskies/swan/forecast_cache.json` (a cache file, opened for reading only).

---

## Q1 — Mechanism: why do transects lack per-transect PT* partitions at their handoff point?

Two **distinct** upstream mechanisms both terminate in the same downstream WARNING and the same
bulk-fallback behavior. Static tracing found mechanism (A); live journal evidence (§Q2) shows
mechanism (B) is what is actually firing on `librewxr`, and (A) is essentially silent in the
samples examined.

### Downstream (both mechanisms land here)

`surf_1d_pipeline.py:1513-1597` (`_run_pipeline_per_transect`), the per-transect Step 1 loop:

```
1572  for t_idx in range(n_transects):
1573      parts = [dict(p) for p in (partitions_by_transect.get(t_idx) or [])]
...
1577      if not parts:
1578          # Genuine per-transect last resort — bulk-fallback THIS transect.
1579          if bulk_hs is not None and bulk_tp is not None and bulk_dir is not None:
1580              logger.warning(
1581                  "run_pipeline[per-transect]: transect %d has NO per-transect "
1582                  "PT* swell partitions at its own handoff point this hour — "
1583                  "bulk-falling-back for THIS transect only ..."
```

`partitions_by_transect` is produced once per timestep by
`resolve_partitions_by_transect()` (`surf_pipeline_timestep.py:350-395`):

```
386  by_transect = ts_handoff_specout.get("handoff_by_transect")
387  if not isinstance(by_transect, dict) or not by_transect:
388      return None                      # -> run_pipeline uses its LEGACY shared-CURVE path instead
390  result: dict[int, list[dict]] = {}
391  for idx in range(len(spot_transects)):
392      entry = by_transect.get(idx)      # int key lookup
393      comps = entry.get("components") if isinstance(entry, dict) else None
394      result[idx] = list(comps) if comps else []   # <- [] whenever idx is MISSING from by_transect,
395                                                    #    or present with components=[]/None
```

So a transect bulk-falls-back whenever it is **either** (a) present in `handoff_by_transect` with
an explicit empty `components` list, **or** (b) simply **absent** from the `handoff_by_transect`
dict for that hour. Both collapse to the same `[]` here — this function cannot distinguish them,
and neither can the downstream WARNING.

### Mechanism (A) — traced: a selected station's TABLE_PT row has zero/absent partitions

`swan_runner.py:1019-1034`, inside `_select_l3_handoff_position_and_spectrum()`:

```
1019  if pt_table_text:
1020      # T4B.6: this transect's OWN in-grid point, at the SAME band
1021      # station the handoff depth was selected at.
1022      components = pt_by_band_idx.get(selection.station_index, {}).get(time_iso)
1023      if not components:
1024          logger.warning(
1025              "SWAN watershed (per-transect): %s @ %s — no PT* "
1026              "partitions at this transect's OWN handoff point ..."
```

`pt_by_band_idx` comes from `_align_watershed_partitions_to_points()`
(`swan_runner.py:481-555`), which in turn calls `parse_table_pt_partitions()`
(`swan_spectral.py:969-1175`). That parser's absence rule (`swan_spectral.py:1122-1166`): a TABLE
row contributes **zero** partitions, and is dropped entirely (`swan_spectral.py:1165-1166`), when
every one of its `HsPT01..HsPT10` columns is within `_PT_HS_ZERO_TOLERANCE` of exact 0.0 (real
SWAN's own absence signal, per the docstring at `swan_spectral.py:981-993`) — i.e., **SWAN's own
watershed partitioning genuinely found no partition at that exact in-grid band point, that exact
hour**. A second, separate way to land here: the row exists but its (XP, YP) doesn't match any of
this transect's own band-station coordinates within `coord_tol_m=200.0`/`coord_tol_deg=0.003`
(`_align_watershed_partitions_to_points`, `swan_runner.py:540-543`) — logged separately as `"SWAN
watershed alignment (per-transect): ... row(s) had no band-station match within tolerance"`
(`swan_runner.py:548-553`).

**Both of these upstream WARNINGs are absent from every live journal sample examined for §Q2**
(zero hits for `"no PT"` and zero hits for `"SWAN watershed alignment (per-transect)"` in the same
windows that show thousands of the *downstream* `run_pipeline[per-transect]` warnings — see §Q2).
This means mechanism (A) is not what produced the observed collapses in the samples checked.

### Mechanism (B) — inferred from the log-absence, not fully pinned: a whole-hour selection failure upstream of the components check

Still inside `_select_l3_handoff_position_and_spectrum()`'s per-timestep loop
(`swan_runner.py:904-1044`), there are three `continue`/skip points that exit **before** the
components lookup ever runs, and **log nothing**:

- `swan_runner.py:908-910` — `hs_this_hour = hs_by_time_dist.get(hs_key); if hs_this_hour is None:
  continue` (no Hs proxy for this transect's own band at this hour — silent).
- `swan_runner.py:952-976` — `HandoffBreakingError` from `refine_handoff_with_qb()` (breaking-zone
  guard exhausted the whole band this hour) — `continue`s at line 976, silent except an optional
  TRACE emission (only active when `trace.TRACE_ENABLED`, not journal-visible).
- `swan_runner.py:978-979` — `selection.station_index is None: continue` — silent.
- `swan_runner.py:1009-1011` — `curve_idx is None: continue` — silent (no nearest-CURVE match at
  all, distinct from the PT* alignment-tolerance case above, which DOES log).

Any of these means `_t_merged` (the per-transect result list) simply has **no entry at all** for
that timestep. Back in `_parse_output()` (`swan_runner.py:6098-6224`),
`_by_transect_by_time[transect_idx]` then also has no entry for that time; the carrier-building
step (`swan_runner.py:6200-6215`) still includes that hour (because the UNION of times across all
162 transects is used, `swan_runner.py:6200-6202`) but with `_tb` (the per-transect map for that
hour) missing every transect that hit one of these silent exits. If **every** transect hits the
same silent exit for the **same** hour — plausible if the trigger is hour-level, not
transect-level (e.g. an Hs-proxy input that is genuinely absent for that one forecast hour across
the whole domain) — the result is a full 162/162 collapse for that one hour with **zero** upstream
WARNING, exactly matching the live evidence in §Q2.

**Could not determine, and why:** which of the three candidate silent exits (or a combination)
is actually firing for the observed collapsed hours. Distinguishing them needs either
`trace.TRACE_ENABLED` output (not on in production; the emitted `handoff_selection` trace record
would show `reason="breaking_zone_exhausted"` vs a station/curve match failure, but no trace
artifacts were found persisted on `librewxr` for the sampled windows) or a live instrumented run —
both out of this task's read-only scope. Flagging as a genuine open question for whoever picks up
Y1/X/Z, not resolved here.

---

## Q2 — Frequency: healthy cycles vs crash-loop cycles

**Cycle boundary markers used:** `"Marine runner: starting full SWAN cycle for 1 spot(s)"` (cycle
attempt start) and `"SWAN T4B.6: spot 'huntington-city-beach-pier' → 162/162 transect(s) resolved"`
(cycle **success** — confirms the deployment's one precomputed spot has exactly **162** transects,
matching the brief). Only one spot (`huntington-city-beach-pier`) is configured on `librewxr`.

**Two independent 162-transect-spot call sites exist and are indistinguishable by warning text
alone** — the SWAN precompute path (`providers/nearshore/swan.py` → `log_prefix="SWAN precompute"`,
default) and a separate on-demand `beach_profile` endpoint path (`log_prefix="beach_profile"`,
`endpoints/beach_profile.py`) that in the Aug 3 sample was serving a **different, 32-transect**
spot config (10 m spacing, 315 m segment, beach_facing=217°, vs the 162-transect
`huntington-city-beach-pier` spot). Grouping raw `run_pipeline[per-transect]` warning lines by
millisecond timestamp and taking `max(transect_index)` per group cleanly separates the two (32-max
bursts vs 161-max bursts) — see method note at the end of this section.

### Healthy window (pre-2026-08-05 05:00Z)

| Day | Cmd | Result |
|---|---|---|
| 2026-08-03 (full day) | `journalctl --since '2026-08-03 00:00:00' --until '2026-08-04 00:00:00' \| grep -c 'SWAN T4B.6: spot'` | **6** successful full cycles |
| 2026-08-03 (full day) | `journalctl ... \| grep -c 'run_pipeline\[per-transect\]: transect'` | **584** total warning-lines |
| 2026-08-03 breakdown | ms-grouped burst analysis (see method) | 584 = **520** (2× 161-max bursts, i.e. 2 forecast-hours of full 162/162 collapse on the real spot) + **64** (2× 31-max bursts, the unrelated 32-transect `beach_profile` spot) |
| 2026-08-03 timing of the 2 collapsed hours | `05:06:09` and `07:03:48` | **Both fall inside/adjacent to a WW3-boundary-fetch failure/retry storm**, `04:31–07:17` UTC (`Provider ww3_spectrum 4xx 404`, `"Marine runner: forced full run no-oped -- signal kept for retry"` repeating every 5 min, `swan_runner.py`/`swan.py`'s documented last-good-cache-preserved retry behavior). Neither collapsed hour belongs to the post-completion output of a *freshly finished* cycle — the first clean completion of the day (07:17:28) itself shows **zero** bulk-fallback warnings in its own precompute window (07:17:28–07:40), confirmed by direct grep. |
| 2026-08-03, the other 4 completed cycles (09:11, 10:49, 13:51, 19:24, 23:56) | spot-checked + accounted for by the arithmetic above | **0/162 transects bulk-fell-back**, every hour, all 4 cycles |
| 2026-08-04 (full day) | same two commands | **5** successful full cycles; **0** bulk-fallback warnings, entire day |

**One healthy-cycle exception found, not near any known failure window:** the cycle that started
21:17:20 and completed T4B.6 at 21:43:49 on 2026-08-05 (before the "sporadic kills since 05:21Z"
window's worst period, and confirmed **zero** OOM-kill journal lines 20:00–22:00 that day) produced
**1,458** warning-lines, decomposing (ms-grouped) into **8 distinct forecast hours** (of the run's
~67) where 154–162 of 162 transects bulk-fell-back simultaneously — a **~12% (8/67) collapsed-hour
rate** in an otherwise clean cycle. The *other* ~59 hours in that same cycle had real, non-fallback
per-transect partitions (independently confirmed for transect 48/transect 55 at the
`2026-08-05T22:00:00Z` timestep via the persisted forecast cache — §Q3). Zero upstream
`swan_runner.py` "no PT*"/"alignment" warnings co-occurred with any of the 8 collapsed hours,
consistent with mechanism (B), not (A), driving this cycle's collapses.

**Net reading:** healthy-cycle bulk-fallback frequency is **not a fixed rate** — it ranged from 0%
(11 of 12 sampled Aug 3–4 cycles) to ~12% of forecast hours (1 sampled Aug 5 cycle, no known
confound), with the only Aug 3 exceptions tied to a separate, already-explained boundary-fetch
failure window. This is evidence of intermittent, hour-dependent behavior, not a permanent
per-cycle collapse.

### Crash-loop window (tonight, 2026-08-05/06)

| Window | Cmd | Result |
|---|---|---|
| 2026-08-05 05:00Z – 2026-08-06 12:00Z (~31 h) | `grep -c 'run_pipeline\[per-transect\]: transect'` | **37,422** warning-lines |
| 2026-08-05 05:00Z – 2026-08-06 12:00Z | `grep -c 'SWAN T4B.6: spot'` | **4** successful full completions in ~31 h (vs 5–6/day healthy) |
| 2026-08-05 05:00Z – 2026-08-06 12:00Z | `grep -ci 'killed\|out of memory\|oom'` | **28** kill-related lines |
| 2-hour sample, 23:00–01:00 (tight crash-loop period, "every ~7 min since 22:17Z") | ms-grouped burst analysis, same method | **12,798** warning-lines in 2 hours alone — recurring 161-max (full-spot) bursts roughly every 1–2 minutes, an order of magnitude denser than any healthy-cycle sample |

**Not further decomposed** (which of mechanism A/B, or a third OOM-specific truncation mode, drives
the crash-loop volume) — this is squarely the OOM investigation's territory (owned by the
`mem1-oom-investigator` agent per the session roster), and the brief explicitly says not to
diagnose the OOM loop itself. The plausible hypothesis — repeated OOM restarts each re-attempt the
per-transect TABLE parse from a truncated/incomplete state before being killed again, each attempt
contributing its own burst of collapsed hours — is consistent with the volume and burst cadence but
**not independently verified here**.

**Method note (burst grouping):** for a given day/window,
`journalctl ... | grep -oE '"timestamp": "[^"]+".*transect ([0-9]+) has NO'` was piped through
`sed` to extract `(timestamp, transect_index)` pairs, then grouped by millisecond-precision
timestamp with `awk` to get `(count, max_transect_index)` per burst. A burst with
`max_transect_index ≈ 161` and count near 162 is one forecast-hour's full collapse on the 162-
transect spot; `max_transect_index ≈ 31` is the unrelated 32-transect `beach_profile` spot. Raw
files: `/c/tmp/aug3_bulkfallback.txt`, `/c/tmp/aug4_bulkfallback.txt`,
`/c/tmp/aug5_2117_bulkfallback.txt`, `/c/tmp/crashloop_bulkfallback.txt` (local scratch, not
committed).

---

## Q3 — Energy accounting: where was the ⅓-energy deficit measured, and which site does the evidence implicate?

**Provenance of the plan's number, inherited from Y0 (not re-litigated here per the no-loops
rule):** Y0 already searched `docs/planning/scratch/` and `docs/` for an inline citation
(`0.47`, `0.47.*0.51`, `3.27 m handoff`) backing the plan's "Hs at T48/T55 bar ≈ 0.52–0.55 m" and
found none — the number is asserted in `SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md:27,31-32` without a
locatable dated measurement artifact. This investigation did not find one either
(`docs/planning/scratch/EYEBALL-FIX-EXECUTION-SCRATCH-2026-08-04.md` and
`docs/planning/scratch/X0-FACT-PIN-2026-08-05.md` were grepped for `1/3`, `third`, `starv`, `T48`,
`T55`, `0.52`, `0.55`, `bar crest` — no measurement record found, only the plan's own restatement
and X0's independent confirmation that the *bathymetric* bar-crest location (~79.7 m, transect 55)
is real).

**What this investigation independently measured, live, tonight (2026-08-05/06), using the current
real spectral boundary architecture Y0 confirmed is live:**

1. **Buoy (closest available ground truth to the boundary):** NDBC station 46253 — one of the L1
   boundary's own selected stations (Y0 §(e): 0.1 km from L1 centre by the selection algorithm's
   internal distance metric) — realtime feed
   (`https://www.ndbc.noaa.gov/data/realtime2/46253.txt`), rows for 2026-08-05 21:26–22:56 UTC:
   **WVHT = 0.6 m, DPD = 13 s** (consistent across all 4 rows in the window).
2. **SWAN handoff (L4, the finest structure grid), live production data, transects 48 and 55
   specifically (the plan's own named reference transects), timestep `2026-08-05T22:00:00Z`,**
   read from `/run/weewx-clearskies/swan/forecast_cache.json` (`saved_at: 2026-08-05T21:53:40Z`,
   `run_time: 2026-08-05T21:20:11Z`, cycle confirmed T4B.6-successful 21:43:49, **zero** OOM kills
   20:00–22:00 that day — a clean, non-degraded cycle):
   - Transect 48: `handoff_depth_m=3.27`, `handoff_source_level=L4`, 2 real (non-fallback)
     components — groundswell Hs=0.479 m/Tp=13.35 s + wind_swell Hs=0.222 m/Tp=5.76 s → RSS
     combined **Hs ≈ 0.528 m**.
   - Transect 55: same depth/source, groundswell Hs=0.468 m/Tp=13.35 s + wind_swell Hs=0.222 m/Tp=
     5.77 s → RSS combined **Hs ≈ 0.518 m**.
   - (Spot-checked 3 other transects at the same hour — 0, 80, 161 — all in the 0.43–0.49 m range,
     same two-partition structure; none bulk-fell-back at this specific hour.)
   - This independently reproduces the plan's own **"3.27 m handoff"** and **"0.47–0.51 m"**
     figures almost exactly (Y0 had flagged both strings as ungrepped/unsourced — they are real,
     live, current numbers, just not the ones Y0 could find a citation for).
3. **1D pipeline output (the SwellTrack/breaking-model cache, same timestep, same cycle),**
   `spots['huntington-city-beach-pier']['swelltrack']['2026-08-05T22:00:00Z']`:
   `spot_average_face_height_m = 0.829`, `best_peak_face_height_m = 0.948`,
   transect 0's dominant-partition break point: `hs_at_break_m = 0.566` at `depth_m = 0.756`,
   `face_height_m = 0.719`. `transect_count=162, open_transect_count=139, degraded=False`.

**Chain, this hour, these transects:** buoy 0.6 m → SWAN L4 handoff (3.27 m depth) ≈ 0.48–0.53 m
(a **~13–20% reduction**, not a ⅓ reduction) → 1D-model breaking face height ≈ 0.72–0.95 m (an
**increase**, via shoaling amplification pre-breaking — physically expected, not evidence of
starvation).

**This one clean, fully-verified snapshot does not reproduce a ⅓-energy deficit anywhere in the
chain the plan names.** It is a single hour on a single (clean) cycle, not a systematic survey —
stated plainly as a bound, not a refutation of the plan's broader claim.

**Where the plan's site attributions (a)–(d) stand against this evidence:**

- **(a) WW3→SWAN L1 boundary:** Already disproven as the "collapse to one parametric peak" site by
  Y0 (the named function doesn't exist; the real multi-station 2-D spectral path has been live
  since 2026-07-26). This investigation's buoy-to-handoff comparison adds one more data point
  consistent with that: energy is substantially preserved from buoy to L4 handoff, not collapsed.
- **(b) SWAN L1→L2→L3 nesting:** Not directly instrumented in this task (no persisted per-level
  intermediate Hs was extracted beyond the final L4 handoff and the boundary spectrum's own
  station Hs). **Could not determine** whether nesting itself loses energy between L1 and L3/L4 —
  would need the same kind of targeted extraction from L1/L2 CURVE/TABLE output, not attempted here
  (out of the effort budget for this task; flagging for whoever owns Round Y/X next).
- **(c) L3→1D handoff bulk-fallback:** Confirmed real and live (§Q1/§Q2), but **intermittent**
  (0–12% of hours in healthy samples, much higher during the OOM crash-loop) — not the permanent,
  every-hour collapse the plan's "starved to ⅓" framing implies. When it fires, it is a genuine
  detail loss for that hour (multi-partition → one bulk scalar triple for every affected transect),
  but this investigation did not find evidence that the *specific* transects/hour the plan cites
  (T48/T55, "0.52–0.55 m") were themselves victims of it — the opposite: they had real partitions
  at the one hour checked.
- **(d) The 1D march itself:** The one hour checked shows the 1D model **amplifying** Hs via
  shoaling toward breaking (0.53 m → 0.72–0.95 m face height), which is directionally correct
  physics, not evidence of an energy sink inside the march. Not exhaustively audited beyond this
  one snapshot.

---

## Q4 — Verdict

**Cannot single out one site with high confidence as *the* ⅓-energy-deficit cause, because the one
clean, fully-traceable measurement this investigation could make — buoy → SWAN L4 handoff → 1D
breaking face height, for the plan's own named reference transects (48/55), on a healthy cycle —
does not reproduce a ⅓-energy deficit at all.** Buoy 0.6 m → handoff ≈0.5 m → break face height
≈0.7–0.95 m is a physically ordinary shoaling chain, not a starved one.

**What IS confirmed live and real:** the L3→1D handoff bulk-fallback mechanism named in the task
brief (`surf_1d_pipeline.py:1577-1589`) genuinely fires, intermittently (§Q2), and when it fires it
does collapse that hour's multi-partition detail to one scalar triple for every affected transect —
but the evidence points to it being **hour-dependent and not universal**, and the specific
hour/transects independently checked here were unaffected by it.

**Single strongest piece of evidence:** the transect-48/55, `2026-08-05T22:00:00Z` chain above —
because it is the one point in this whole investigation where all three legs (real buoy
observation, real live SWAN L4 handoff output, real 1D pipeline output) could be pulled from the
same clean, non-degraded, T4B.6-successful cycle and compared directly, and none of the three legs
shows a ⅓-scale loss.

**What would decide this properly, if the plan's ⅓-energy claim needs to stand or fall:** a
multi-hour, multi-transect survey (not a single snapshot) of buoy-vs-handoff-vs-break-height across
a full healthy forecast run, ideally cross-referencing which hours DID hit the bulk-fallback
collapse (§Q1/§Q2) to see whether *those specific hours* show a real deficit while the
non-collapsed hours (like the one sampled here) do not. That would directly test whether mechanism
(A)/(B) is the plan's ⅓-energy symptom, or whether the symptom (if still reproducible today) lives
somewhere this investigation did not instrument — most likely candidate by elimination, per §Q3,
is the untouched L1→L2→L3 nesting chain (b), or the plan's original measurement predates the
2026-07-26 real-boundary change and is simply stale (Y0's caveat, still unresolved). This is a
measurement task, not a code-reading task — out of this agent's read-only, no-runs scope.

---

## Files touched by this task

Only `docs/planning/scratch/YQ-1-ENERGY-DEFICIT-2026-08-05.md` was created. No code, no other docs,
no remote git operations, no state changes on `librewxr` (all commands were `journalctl`, `ls`,
`stat`, and a read-only `python3 -c "json.load(...)"` against a cache file). Local scratch files
(`/c/tmp/aug3_bulkfallback.txt` etc.) are outside the repo and not committed.
