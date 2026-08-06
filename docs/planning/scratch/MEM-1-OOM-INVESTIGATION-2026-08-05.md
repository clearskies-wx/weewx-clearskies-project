# MEM-1 — Marine Service OOM Investigation (2026-08-05)

Read-only investigation. Host `librewxr` (LXC container, 6 GB memcg cap), service
`weewx-clearskies-marine.service`. Deployed repo `/home/ubuntu/repos/weewx-clearskies-marine`
(commit `bdf4db8`, verified identical to local checkout `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`).

All timestamps below are UTC unless labelled PDT. `ratbert` (LXD host, source of `dmesg`)
runs `America/Los_Angeles` (PDT, UTC-7 today) — confirmed via `ssh ratbert "timedatectl"`.
`dmesg -T` prints PDT; converted to UTC (+7h) throughout this report for consistency with
`journalctl` (which is already UTC).

## Live check (ground truth, captured during this investigation)

```
$ ssh ratbert "date; sudo dmesg -T | grep -i 'Killed process' | tail -3"
Wed Aug 5 05:15:06 PM PDT 2026
[Wed Aug 5 16:53:02 2026] Memory cgroup out of memory: Killed process 2163683 (weewx-clearskie) total-vm:6526424kB, anon-rss:2967696kB, file-rss:1024kB, ...
[Wed Aug 5 16:59:37 2026] Memory cgroup out of memory: Killed process 2203614 (weewx-clearskie) total-vm:6338268kB, anon-rss:2759192kB, file-rss:512kB, ...
[Wed Aug 5 17:07:52 2026] Memory cgroup out of memory: Killed process 2246765 (weewx-clearskie) total-vm:6535100kB, anon-rss:3037868kB, file-rss:768kB, ...
```
(16:53–17:07 PDT = 23:53–00:07 UTC Aug 6 — the loop was still killing every few minutes at capture time.)

```
$ ssh librewxr "date -u; ps aux | grep -i weewx-clearskie | grep -v grep"
Thu Aug 6 00:15:21 UTC 2026
ubuntu 59024 0.0 4.9 3343332 292928 ? Ssl 00:15 0:06 .../weewx-clearskies-marine --host 0.0.0.0 --port 8780 ...
```

Follow-up snapshots of the same PID, seconds apart (`ps -p 59024 -o pid,rss,vsz`):

| Wall time (UTC) | Process age | RSS |
|---|---|---|
| 00:15:21 | ~21s | 293 MB |
| 00:15:29 | ~29s | **1,405 MB** |
| 00:15:36 | ~36s | 1,460 MB |

A **+1.1 GB jump in an 8-second window**, in the first 30 seconds of process life, before any
SWAN cycle can plausibly have run — direct live confirmation of a large, near-instantaneous
startup-time allocation (see Candidate #1 below), matching the brief's "~2.2 GB within 60 s."

## Q1 — Timeline

All kills correlated across `ratbert`'s `dmesg -T` (converted PDT→UTC), `librewxr`'s
`journalctl -u weewx-clearskies-marine`, and the deployed repo's `git reflog` (pull timestamps
are real — this repo is fast-forward-only, pulled via cron/deploy script).

| Time (UTC) | Event | Source |
|---|---|---|
| 2026-08-02 06:10 | Isolated OOM kill, **radar** container (`python`, docker), anon-rss 2.56 GB | `dmesg` |
| 2026-08-04 00:45 | Isolated OOM kill, **radar** container, anon-rss 1.96 GB | `dmesg` |
| 2026-08-05 08:38 (01:38 PDT) | **First marine OOM kill**, anon-rss 3.36 GB, total-vm 9.5 GB | `dmesg` |
| 08:40:08 | journalctl explicitly tags this as `"A process of this unit has been killed by the OOM killer"` (first explicit tag) | `journalctl` |
| 05:21:52, 06:07:06 | Two EARLIER marine "Main process exited, code=killed, status=9/KILL" events, memory peaks 3.6 GB / 2.9 GB, **not** explicitly OOM-tagged by systemd but consistent with OOM (no other kill source found) | `journalctl` |
| 08:44:18 | Deploy: pull to `0525394` ("W1c steep-slope note", docs-only) | reflog |
| 08:56:53 | Deploy: pull to `0560c41` ("Z5b hotstart exact-stamp match") | reflog |
| ~13:26–14:15 PDT (20:26–21:15 UTC) | WS2 hotstart-chain commits authored: `3fd72f8`, `e68bf39` (D1-D8 per-hour warm-start chain), `8620216`, `4972db2` (audit F1) — all in `swan_runner.py`/`swan_formats.py`/`grid_sizing_chain.py`, **not** the forecast-cache code | local `git log` |
| 21:15:59 | Deploy: pull to `4972db2` (WS2 complete) | reflog |
| 21:16:09 | Service restart onto `4972db2` | journalctl |
| 21:16:09–22:16:57 | **Ran clean for ~1 hour**, no kill (memory peak 3.6 GB reported at end, i.e. close to the cap but survived) | journalctl |
| ~02:11–04:12 PDT (09:11–11:12 UTC) | Round S commits authored: 5-component geometric-mean surf-scorer rebuild (`2ef8191`…`bdf4db8`, 12 commits, ADR-101/S-SPEC-1) | local `git log` |
| 22:16:45 | Deploy: pull to `bdf4db8` (HEAD, Round S complete) | reflog |
| 22:16:57 | Service restart onto `bdf4db8` | journalctl |
| **22:23:59** | **First kill of the continuous loop** ("killed by the OOM killer"), only 7 min after the `bdf4db8` restart | journalctl |
| 22:24:04 → 00:09:20 (and ongoing) | **Continuous crash loop**: restart counter 1→17+, every cycle dies within 1–11 min (`Main process exited, code=killed, status=9/KILL`), memory peaks reported 1.6–4.1 GB | journalctl |
| 14:43, 15:13, 16:03, 16:13, 16:26 (Aug 5, UTC) | Interleaved **radar-container** OOM kills (independent process, `python -m librewxr.main`), anon-rss 1.8–2.4 GB each | `dmesg` |

**Commit running when kills began:** the first marine kill (08:38 UTC) ran on whatever commit
preceded `0525394` (pre-dawn Aug 5, before any of today's Round S/WS2 work). The **continuous,
unrecoverable loop** began at 22:23:59 UTC, 7 minutes after the service restarted onto `bdf4db8`
— the full Round S surf-scorer rebuild. The immediately-prior deploy (`4972db2`, WS2 hotstart
work) ran a full clean hour under presumably the same forecast-cache-load path, which weakens
(but doesn't eliminate) WS2 as the trigger and points more at Round S or at the forecast cache
simply having grown/aged past a tipping point by 22:16.

## Q2 — Memory-holder candidates, ranked

### #1 (HIGH confidence, live-confirmed) — monolithic forecast-cache disk load at startup

`weewx_clearskies_marine/providers/nearshore/swan.py`:
- `_load_forecast_cache_from_disk()`, lines **1482–1539**: on every process start ("restore-before-serve step"), does
  `raw = _FORECAST_CACHE_PATH.read_text(encoding="utf-8")` (line 1504) then `data = json.loads(raw)` (line 1505) — a single, un-streamed read+parse of the entire on-disk cache file — then `cache.set(_build_last_good_key(spot_id), payload, _LAST_GOOD_TTL_SECONDS)` for every spot (line 1539), holding the fully-parsed structure in the in-process `MemoryCache` (`TTLCache`, 7-day TTL) for the process's lifetime.
- On-disk size right now: **233,011,775 bytes (233 MB)**, `/var/run/weewx-clearskies/swan/forecast_cache.json` (`ls -la` on librewxr, mtime 2026-08-05 21:53).
- The code's own comment at lines 1454–1463 documents that this is a **known, previously-flagged concern**: the write/encode side was changed to a chunked encoder (`dumps_chunked`, `chunked_json.py`) under an "H4" finding, but *"the read/decode above (json.loads(raw), :1423) stays monolithic this round (lead ruling 2026-08-02): no streaming JSON parser exists in the stdlib without a new dependency (not approved)"* — i.e. the decode-side fix was explicitly deferred, not fixed.
- Live evidence: PID 59024 climbed from 293 MB → 1,405 MB RSS in an 8-second window inside its first 30 seconds of life (table above) — before a SWAN cycle could plausibly have completed. A 233 MB JSON string plus its fully-parsed nested Python dict/list/float structure (typical CPython inflation for numeric-heavy nested JSON is 3–8×) is fully consistent with a ~1.1 GB single-shot jump.
- Estimated size: **~1–1.5 GB** for this one structure alone (live-observed jump ≈ 1.1 GB).

### #2 (MEDIUM-HIGH confidence) — un-trimmed per-transect "transect" cache key, feeding #1

- `swan.py` docstring at lines 1989–1991, describing the *swelltrack* sub-cache: *"encoded with `services/swelltrack_cache.py`'s TRIMMED codec (**drops the three heavy per-transect arrays**) — see that module's docstring for the measured size tradeoff."* This is a direct admission in the code that per-transect arrays are heavy enough to warrant a dedicated trimmed encoding — **for one sub-key**. The sibling `"transect"` key (line 1691–1692: *"full cross-shore transect per timestep (keyed by ISO time string)"*) is **not** trimmed — it is "the pre-existing, load-bearing cache payload" (line 1984) and is exactly what gets `read_text()`/`json.loads()`'d whole by Candidate #1.
- Generative source: `weewx_clearskies_marine/services/surf_1d_pipeline.py` line 2347 (`_truncated = _refine_bathy_profile(_truncated, ANALYTICAL_TARGET_DX_M)`), where `ANALYTICAL_TARGET_DX_M = 1.0` (`services/bathymetry_refine.py:48`) — every transect's bathymetric profile is PCHIP-refined to a **uniform 1-metre grid** ("operator-approved 2026-08-02", comment at surf_1d_pipeline.py:2339–2346). `services/surf_1d_analytical.py` line 864 comment confirms the deployed spot has **162 real transects** ("Z audit ran the deployed detector over all 162 real HB-pier CUDEM ... transects").
- 162 transects × a per-transect profile that, at 1 m resolution, spans however many metres from the L2/L3 handoff depth to shore (hundreds to low thousands of metres, not measured here) × several float fields per point (depth, height, Hs, etc.) × N forecast timesteps = the most plausible generator of the 233 MB on-disk payload and of ongoing numpy-array churn during each SWAN cycle's precompute step (`swan.py` ~1955–2350, `_precompute_1d_pipeline_for_timestep`-shaped function), which is consistent with the brief's reported mid-run peak of 3.0–3.2 GB (startup jump from #1, plus this per-cycle churn on top).
- Not able to pin an exact byte estimate without either reading `forecast_cache.json`'s structure directly (avoided — a 233 MB `json.load()` on the already-memory-starved live host was judged too risky for a read-only task and wasn't authorized) or running the pipeline locally (out of scope — no SWAN run permitted).

### #3 (RULED OUT as a direct RSS driver, but real disk-storage growth) — WS2 per-hour hotstart chain

- `services/swan_runner.py` + `services/swan_formats.py` (commits `3fd72f8`, `e68bf39`, `8620216`), landed 20:26–21:15 UTC Aug 5 — changed the warm-start chain to keep **6 hourly hotstart `.dat` files per SWAN nest level** instead of one.
- Confirmed on disk (`ls -laR /var/run/weewx-clearskies`, `du -sh`): **3.6 GB total** in `/var/run/weewx-clearskies/swan`, with hotstart files present in **two copies each** — once directly under `swan/` (e.g. `level2_hotstart_20260805.190000.dat` … `.230000.dat`, `.000000.dat`) and once again inside `swan/level2/` (`hotstart_20260805.190000.dat` etc.), same 6 timestamps, same byte-for-byte sizes (71,489,735 bytes × 6, per level2 alone). Per level: level1 ≈ 58 MB ×2, level2 ≈ 429 MB ×2, level3_0 ≈ 123 MB ×2, level4_0 ≈ 628 MB ×2 — roughly **2.5 GB of duplicate hotstart storage** across all 4 levels.
- **Ruled out as a direct anon-RSS cause**: every OOM `dmesg` line shows `file-rss` at 256 B–2.8 KB against `anon-rss` of 1.8–4.3 GB. The 3+ GB kill footprint is essentially 100% anonymous (heap/numpy) memory, not page-cache-backed file content — and these `.dat` files are read/written by the **SWAN Fortran binary as a subprocess**, not parsed by the Python process. This candidate explains disk pressure and duplication (worth fixing on its own merits) but not the RSS that triggers the OOM kill.

### #4 (not investigated in depth — lower priority given #1/#2's strength)

- Endpoint concurrency (surf/beach_safety/fishing/marine firing together): `endpoints/surf.py` is 1,719 lines and itself calls `_refine_bathy_profile(_sb_bathy, ANALYTICAL_TARGET_DX_M)` again at line 961 (a second, request-time 1 m refinement, independent of the cached SWAN-cycle one) — a plausible additive contributor under concurrent request load, but not examined for actual concurrency (`asyncio.gather`/thread pool) wiring; a targeted grep for `asyncio.gather`/`ThreadPoolExecutor` across the package found no hits in `endpoints/` or `service.py`, only in `__main__.py` and `bathymetry_resolver.py`, suggesting requests are likely served sequentially per event loop rather than fanned out in parallel threads — lower likelihood of being a multiplicative driver, not conclusively ruled out.

## Q3 — Regression or accumulation?

**Both, in different proportions — not a clean either/or:**

1. **Pre-existing, already-marginal baseline (accumulation).** Sporadic marine OOM kills were
   happening every ~1–2.5 hours from **08:38 UTC Aug 5 onward**, on commits that predate every
   piece of today's Round S and WS2 work. `journalctl`'s own "memory peak" reporting shows
   3.6 GB / 2.9 GB / 3.1 GB / 3.6 GB / 2.9 GB / 3.4 GB peaks across five separate clean-looking
   restarts between 01:03 and 08:40 UTC — i.e. the service was **already flirting with the
   memcg cap for at least 7+ hours before today's deploys landed.** This is consistent with the
   forecast-cache-load design (#1/#2 above) being a long-standing, previously-flagged-but-deferred
   issue (the code's own "lead ruling 2026-08-02: decode stays monolithic this round" comment),
   not something introduced today.
2. **A same-day trigger converted "sporadic, survivable" into "continuous, unrecoverable."**
   The clean 1-hour run on `4972db2` (21:16–22:16 UTC) followed by a kill 7 minutes after
   restarting onto `bdf4db8` (22:23:59 UTC), and every restart failing within minutes since,
   is a tight correlation. I could not find a specific Round S line that itself allocates
   gigabytes — the rewrite (`enrichment/surf_scorer.py`, 1,110 lines changed in `ae30eb1`) is
   scoring/float-arithmetic shaped, not obviously memory-heavy — so my confidence that Round S's
   *own* code is the proximate new consumer is **medium, not high**. Two other explanations fit
   the same timeline equally well and I could not distinguish between them with read-only
   evidence: (a) the 233 MB forecast cache simply crossed a size/age threshold around this time
   (it was last written 21:53 UTC, mid-way through the `4972db2` run, i.e. already at/near its
   current size before `bdf4db8` even deployed); (b) the **radar container** (`python -m
   librewxr.main`, currently 1.98 GB RSS, independently OOM-killed 5 times on Aug 5 between
   14:43 and 16:26 UTC) was consuming a shifting, independent share of the same 6 GB cgroup,
   and headroom simply ran out from the marine side regardless of which commit was running.
3. **Verdict:** the system has been operating with **too little headroom for months' worth of
   accreted per-request/per-cycle memory design** (monolithic cache load chief among it), and
   a combination of ordinary state growth (cache file at 233 MB and climbing) plus a same-day
   deploy landed on top of that already-thin margin and tipped it from occasional kills into a
   permanent crash loop. I do **not** have high confidence pinning bdf4db8/Round S alone as
   causal — flag this for whoever fixes it: check `forecast_cache.json`'s size trend (no
   historical snapshots were available to this investigation) before assuming Round S is the
   regression.

## Scope notes / things NOT done (per prohibitions)

- Did not `json.load()` the live 233 MB `forecast_cache.json` on librewxr (read-only, and risked
  adding memory pressure to an already-OOMing host) — its internal size breakdown by key
  (`forecast` vs `spectral` vs `transect` vs `swelltrack`) is inferred from code comments, not
  measured directly.
- Did not restart, kill, or modify anything on librewxr or ratbert.
- Did not run pytest (noted but did not investigate: a stray `pytest tests -q` process, cwd
  `/home/ubuntu/wt-warmstart`, has been running since Aug 5 on librewxr under a `sudo -u ubuntu`
  wrapper — unrelated to this OOM loop, RSS negligible, flagged for awareness only).
- Git: local checkout `git status` clean, `bdf4db8`, matches deployed. No `pull`/`fetch`/`checkout`
  performed; remote state not checked (not required — deployed and local already match).
