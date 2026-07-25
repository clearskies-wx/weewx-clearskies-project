# Overnight report — 2026-07-25

Written for the operator to read on waking. Times are **UTC** (local = UTC − 7).

---

## 1. The incident: L2 went from ~7 min to 50 min

### What the evidence shows

| Condition | L2 wall-clock |
|---|---|
| 16 threads, quiet box (01:09, 06:47, 07:14) | 6m51s – 7m57s |
| 16 threads, **contended** box (08:37) | **50m32s** |
| 6 threads, quiet box (09:53) | 9m40s |

**Two conditions were both necessary.** At 16 threads on a quiet box, L2 ran in ~7 minutes
three times that same morning — so the thread count alone did not cause it. What made 08:37
different was that the compute service was simultaneously working through a 70-minute batch
at 519 MB RSS.

The mechanism is **paging, not CPU starvation**. The SWAN unit's own exit accounting:

```
weewx-clearskies-swan.service: Consumed 3h 43min 38.631s CPU time,
627.2M memory peak, 179.2M memory swap peak.
```

The SWAN binary is OpenMP (`ldd /usr/local/bin/swan` → `libgomp.so.1`) and allocates private
work arrays **per thread**, so thread count multiplies the resident set. Measured on the
identical 81×71 L2 grid: **627 MB at 16 threads** (179 MB of it swapped) vs **87 MB at 6**.
The box has 5.7 GB with the radar container holding ~3.2 GB, leaving ~1.7 GB. At 16 threads
SWAN only just fit; when the compute batch took another 519 MB it stopped fitting. A swapping
OpenMP solver degrades badly because every sweep barrier waits on whichever thread is faulting
pages off disk.

### I was wrong twice, on the record

- I initially blamed the radar container. You were right that it wasn't the story — 744% CPU
  is 7.4 of 32 cores, ~23% of the box.
- I earlier told you the 50-minute run was "contaminated by my own audit traffic." That was a
  guess and the evidence does not support it — the batch ran 70 continuous minutes including
  40 minutes after I stopped touching anything.

### What I have NOT established

**Nobody knows what drove those ~1,260 `run_pipeline` calls.** The weewx API logged zero lines
in the window, `compute_client.py` has no retry logic, and I caught no inbound connections on
:8770. I refuse to name a cause I cannot evidence. A watcher is now running on librewxr logging
every connection to :8770 → `/tmp/compute_callers.log`. If it recurs, you will have the caller.

---

## 2. `omp_num_threads` was 16, not 6 — FIXED

`/etc/weewx-clearskies/api.conf:376` read `omp_num_threads = 16`. Now `6`.
Backup: `/etc/weewx-clearskies/api.conf.bak-20260725-omp16`.

**I did not change it to 16.** The file's mtime was 2026-07-22 10:11:46 and untouched since;
this session was 07-25. Origin traced to `docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md:382`:

> `api.conf [trushore]→[swan]` | config fix | `omp_num_threads=6→16 now visible`

Renaming the dead `[trushore]` section to `[swan]` made the key live, and it was written as 16.

**Be aware of the trade you have chosen:** 6 threads is 25–40% *slower* in isolation than 16.
It does not make the model faster. It cuts the resident set 7×, which removes the failure mode.

`api.conf` is **not in git**, so nothing detects drift in it. Recorded in
`reference/clearskies-dev.md` with the measurements.

---

## 3. Hotstart has never worked — fix deployed, and it exposed a SECOND bug

### The original defect (fixed, `a1fa14f`)

Save and load used different naming schemes:

| | Written as | Looked for |
|---|---|---|
| L1 | `level1_hotstart.dat` | `outer_hotstart.dat` |
| L2 | `level2_hotstart.dat` | `outer_hotstart.dat` |
| L3 | `level3_0_hotstart.dat` | `inner_hotstart.dat` |

`outer_/inner_hotstart.dat` are never created, so `persistent_hot.exists()` was always False.
Confirmed: `"using hotstart from previous run"` appeared **0 times in 5 days** while 113 MB of
hotstart files were written and discarded every cycle. **Every cycle has always cold-started.**

Test baseline established empirically, not assumed:

| Checkout | Result |
|---|---|
| `eca80ee` (weewx, pre-change) | 65 passed, 15 errors |
| `a1fa14f` (librewxr, post-change) | 65 passed, 15 errors |

Identical. The 15 are a pre-existing fixture defect (`config requires 'inner_bbox'`).

### The second bug it exposed — NOT YET FIXED

First cycle after deploying (10:20:38):

```
10:22:58  SWAN level1: using hotstart from previous run     <- first time in 5 days
10:23:00  SWAN level1: crashed with hotstart loaded — deleting stale hotstart, retrying cold
10:24:03  SWAN level2: using hotstart from previous run
10:24:03  SWAN level2: crashed with hotstart loaded — deleting stale hotstart, retrying cold
```

**The naming fix is correct — SWAN now finds and loads the file. SWAN then rejects it.**
L1 crashed 1.4 s in, L2 in 0.5 s. That speed indicates a parse/format rejection, not numerical
divergence.

Thread count is **not** the cause: those files were written at omp=6 and reloaded at omp=6.

**Prime suspect — command syntax.** `swan_formats.py:1207` emits `INIT HOTSTART 'hotstart.dat'`.
SWAN 41.51's documented form is `INITIAL HOTSTART SINGLE fname='hotstart.dat'`.
`docs/reference/swan-commands-extract.md` has **no HOTSTART entry** — unlike the PT*/CURVE/POINTS
commands, this syntax was never verified against the manual.

**This is safe to leave overnight.** The crash-retry deletes the hotstart and reruns cold, and
the cycle completes normally. Net effect vs before the fix: identical results, ~2–4 s/cycle
wasted, extra WARNING noise. **Do not revert** — the fix is correct and exposed a pre-existing
bug that was invisible while the hotstart was never loaded at all.

**I deliberately did not guess at the syntax overnight.** The experiment to run: with a fresh
hotstart file, run SWAN twice on identical inputs, once with each form, and compare PRINT
output. Then fix, and add the verified syntax to the reference extract.

### When it does get fixed, expect your numbers to change

Every cycle to date cold-started. L3 hour 0 reads `Hsig = 0.00913 m` and the provider logs
`Hs=0.01m (no previous run or flat conditions)`. Warm-starting removes that spin-up transient,
so early-hour wave heights should rise. That is the bug being fixed, not a regression.

---

## 4. 1D pipeline now precomputed once per cycle (`cde804e`)

You approved this. The 1D/SwellTrack results were cached **nowhere** — every API request
re-ran the whole pipeline for all ~67–72 forecast hours × 32 transects.

Now precomputed once per timestep at the end of each successful SWAN cycle, cached under
`payload["swelltrack"][validTime]`, read by the surf endpoint. **The on-demand path is intact
as the fallback** — on a cache miss, malformed entry, or precompute failure, behaviour is
exactly as before.

**Size finding.** Caching the full result measured **558 KB/timestep → ~39 MB/spot/cycle,
~196 MB across 5 spots**, written every cycle and shipped over the cross-host HTTP sync. The
agent caught this before writing code. The trimmed codec drops the three heavy per-transect
arrays: **5.2 KB/timestep → ~1.84 MB for 5 spots**.

I verified this independently rather than accept the report — round-tripped a full result
through the codec and asserted the property a trimmed cache could silently break:

```
encoded size: 5.2 KB/timestep  (0.36 MB per spot @72 steps)
modelStatus before='ok' after='ok'
ALL CHECKS PASSED
```

That matters because surf.py's **only** use of `per_transect` is a truthiness check inside
`_determine_model_status()` — a codec that dropped it would round-trip "successfully" while
turning every cached timestep into `modelStatus: "unavailable"`.

**One scope change I made on your behalf:** `beach_profile.py` is left completely untouched.
It needs the dropped arrays, so a cache lookup there could never hit, and dead caching code
reads as working caching to the next person. It was never part of the problem — 1 call per
request, not 67–72.

---

## 5. PT* partition data — first real data for the trigger-1 decision

Preserved on librewxr at `/home/claude/p4b/` (both files, so the comparison can be finished
without another cycle).

**SWAN emits 6 partitions per PT keyword, not 10** — 35 columns, not the 51 the plan assumed.
`docs/reference/swan-commands-extract.md` is wrong on this. The parser handles it correctly
(`_PT_MAX_PARTITIONS = 10` is an upper bound, absent slots decode as `None`), so no code change
is needed — only the docs.

Watershed partition counts (rows with Hs > 0.05, n = 1254):

| Partitions found | Rows | Share |
|---|---|---|
| 1 | 1194 | **95.2%** |
| 2 | 58 | 4.6% |
| 3 | 2 | 0.2% |
| 4–6 | 0 | never |

Energy closure `sqrt(Σ PTHs²)/Hsig`: mean 1.0161 (range 1.0007–1.0254) — partitions carry
~1.6% more energy than bulk. Small systematic excess, not pathological.

Current `decompose_spectrum()` finds **3–5** partitions.

**Preliminary read: this argues AGAINST the trigger-1 swap.** Replacing `decompose_spectrum()`
with watershed partitioning would collapse 3–5 components to 1 about 95% of the time at this
site, flattening the multi-swell structure.

**Do not treat that as settled.** The 3–5 figure is from the 07:13 cycle's logs; the PT* data
is from the 10:14 cycle. Different cycles. A defensible answer needs both methods on the same
spectrum at the same timestep — the inputs for that are preserved.

---

## 6. QC Gate 4A — walked, NOT a clean PASS

Results committed at `docs/planning/briefs/P4A-QC-GATE-4A-RESULTS.md` (593 lines).

- F1, F2 genuinely closed, in code and live behaviour.
- **F3 closed in code but its live delivery is broken** by a newly-discovered, independently
  confirmed **cross-host profile cache divergence** — BLOCKER-eligible, distinct from the
  already-accepted gap 3.
- `verticalDatum` (an explicit T4A.6/F3 deliverable) does not reach the API — BLOCKER-eligible.
- Gate lines 7, 8, 9, 10 still need finalising after a clean-host retest.

The audit **independently found the same two defects I found separately today**, which is
useful corroboration:

- **`DISSURF` never parsed.** SWAN's header column is `Ssurf`; both parsers look for
  `DISSURF`/`DISS`. The field has always been empty. NOT FIXED.
- **`SWAN_LAST_RUN_VALID_FRACTION` pinned to 0.0 for L1/L2** on every healthy run, with two
  log lines reporting irreconcilable values for the same run. Traced to `ac73ab2`
  (2026-07-19) — pre-existing, not a Phase 4A regression. Zero test coverage. NOT FIXED.

The auditor rates the metric bug **worse in kind** than the `Ssurf` one: a silently *wrong*
exported metric actively misleads anyone alerting on it, where `Ssurf` merely withholds a
diagnostic.

I left both unfixed deliberately. You approved two specific changes; I was not going to widen
that unsupervised, and the `DISSURF` fix in particular would populate a field that has always
been empty, which could shift downstream physics. Your call in the morning.

---

## 7. State at time of writing

| Item | State |
|---|---|
| librewxr repo | `a1fa14f` (`cde804e` pending deploy — see below) |
| weewx repo | `eca80ee`, untouched |
| `origin/main` (api) | `a1fa14f` |
| meta repo | `2f349d3` — **local only, NOT pushed** |
| `omp_num_threads` | **6** |
| SWAN service | active |
| Compute service | active, NOT yet restarted onto `cde804e` |
| Caller watcher | running → `/tmp/compute_callers.log` |
| PT*/SPEC data | preserved at `/home/claude/p4b/` |

---

## 8. What I recommend you decide first

1. **The hotstart syntax experiment** — cheap, and it unblocks a real accuracy improvement.
2. **`DISSURF` and `valid_fraction`** — both trivial to fix, both change externally visible
   values, neither approved.
3. **Whether the 95%-single-partition figure is enough** to close trigger 1, or whether you
   want the same-timestep comparison first.
4. **The cross-host profile cache divergence** — BLOCKER-eligible and architectural. Not
   something I should decide.
