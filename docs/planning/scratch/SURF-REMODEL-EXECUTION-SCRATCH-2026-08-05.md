# SURF-PHYSICS-REMODEL execution scratch — started 2026-08-05 (local) / 2026-08-06 UTC

Coordinator execution log for docs/planning/SURF-PHYSICS-REMODEL-PLAN-2026-08-05.md (operator-approved
2026-08-05). Execution order per operator: (1) DOC-0, DOC-1, M-1 → (2) Round Y (Y0 first) →
(3) Round X → (4) Round Z.

## Pre-flight state (verified 2026-08-06 ~00:05 UTC)

- Meta repo: clean at `0fe1ee3` (plan-approved commit).
- Marine repo (`repos/weewx-clearskies-marine`): clean at `bdf4db8` — matches operator's stated
  deployed commit. (NOTE: `repos/weewx-clearskies-swan-swelltrack` at ca22432 is a DIFFERENT,
  older repo — the live marine service runs from `weewx-clearskies-marine`; unit ExecStart
  confirms `/home/ubuntu/repos/weewx-clearskies-marine/.venv/...`.)
- Pycache untracked dirs in marine repo (harmless).

## BLOCKER — librewxr OOM crash loop (found 2026-08-06 00:02–00:10 UTC, surfaced to operator)

**The NOAA outage itself has recovered** — WW3 fetches return HTTP 200 with 25 timesteps
(journal 23:35–00:01Z, pae-paha.pacioos.hawaii.edu erddap). But the marine service is in a
kill loop and never completes a run:

- `/health` = `{"status":"failed", "last_run":"2026-08-05T21:20:11Z", reasons: required input
  unavailable ww3_boundary/wind/bathymetry/tide}` — the "all inputs unavailable" readout is an
  artifact of the process being killed and restarted (fresh process has gathered nothing yet).
- systemd: `Main process exited, code=killed, status=9/KILL`, memory peak 3.1–3.2 G, restart
  counter 13→16 between 23:39 and 00:01Z; kill loop continuous since 22:17Z; sporadic kills
  from 05:21Z.
- **Root cause (hard evidence, ratbert host dmesg):**
  `oom-kill:constraint=CONSTRAINT_MEMCG, oom_memcg=/lxc.payload.librewxr,
  task_memcg=.../weewx-clearskies-marine.service, task=weewx-clearskie ... anon-rss:3050700kB`
  — librewxr is an LXC container with a **6 GB memory cap** (`/sys/fs/cgroup/memory.max` =
  5999996928), sitting at **99.9% usage** (`lxc list`: 5.58GiB). The host kernel's cgroup OOM
  killer SIGKILLs the marine process (the biggest task) every time its run pushes the cgroup
  over the cap. Invisible from inside the guest (no dmesg/oomd entries there).
- Cohabitants: radar `librewxr-librewxr-1` docker container (python -m librewxr.main,
  ~1.95 GB RSS, was "Up 36 minutes" at check — may also be getting recycled), dockerd,
  containerd, cmk agent.
- Marine RSS reaches 2.2 GB within ~60 s of start (during spot setup + SWAN run + endpoint
  serving); peak 3.0–3.2 GB at kill. Historical budget doc (reference/clearskies-dev.md) assumed
  SWAN ~87 MB @ 6 threads and compute service ~519 MB — current footprint is far above that
  envelope → suspected memory regression or state-accumulation in the unified marine service.
- Also seen in journal (known, pre-existing): Round-W1b `apply_ddd_saturation` runaway WARNINGs
  (the defect class Round X fixes); NDBC rate-limiter QuotaExhausted tracebacks (endpoints
  degrade gracefully — WARNING + fallback, not fatal).

**Status: work-stopper for all deploys/reality gates (Y5/X7/Z7) — no stable service to gate
against. Unblocked work proceeding meanwhile: DOC-0, DOC-1, M-1, Y0 fact-pin, MEM
investigation (read-only).** Options land with the operator (raise LXC cap / trim radar /
fix marine regression once found). No state-changing remediation attempted without a ruling —
restarting the radar container and raising the cap are both outside-project or infra changes.

## Task log

| When (UTC) | What | Result |
|---|---|---|
| 00:02–00:12 | Pre-flight + OOM root-cause diagnosis (read-only) | See BLOCKER above |
| 00:15 | Dispatched MEM-1 (OOM investigation, read-only Sonnet) + Y0 fact-pin (read-only Sonnet) | Running in background |
| 00:25 | Dispatched DOC-0 (DASHBOARD/DESIGN manual catch-up vs dashboard a36e4e0+ad2ecf9) + DOC-1 (Operator-Manual Surf Score Weights + ARCHITECTURE /admin/surf-scoring rows + locale key check) — both Sonnet docs-author, scope acks received and correct | Running in background |
| 00:30 | **M-1 DONE (lead-direct, mechanical).** pyproject dev extra += configobj==5.0.9 (pin matches API repo), commit `d74c578` pushed; `scripts/deploy-marine.sh --no-restart` (STALE PROCESS banner printed as designed — no restart intended); `uv pip install configobj==5.0.9` into librewxr marine venv (same install mechanism as deploy script); verification MY OWN run: `.venv/bin/python -m pytest tests/test_structure_coordinates_configobj_roundtrip.py -q` on librewxr → **2 passed in 0.06s** (no swan binary process active at run time). Exclusion was de facto (missing dep — no skip markers/addopts to remove). | DONE d74c578 |

| 00:35–00:50 | **DOC-0 DONE.** Meta `e5a94e1` (DASHBOARD-MANUAL + DESIGN-MANUAL only, 8+/2-). Lead verify: `git show --stat` clean vs allowlist; spot-open confirmed `DRY_BEACH_MARGIN = 15.24 * METER_TO_UNIT // 50 ft` at dashboard BeachProfileChart.tsx:349 matches manual claim. | DONE e5a94e1 |
| 00:35–00:50 | **DOC-1 DONE.** Stack `940047f` (OPERATOR-MANUAL Surf Score Weights §7, 24+), meta `86b9d4e` (ARCHITECTURE rows 564-565 only, 2+). Lead verify: stats clean; defaults claim matches routes.py:117-129 verbatim (.25/.25/.20/.20/.10). All 13 locales already had help.admin.surf_scoring.* (agent-verified grep, count=3 each). | DONE 940047f + 86b9d4e |
| 00:50 | **Y0 DONE — PLAN-SHIFTING FINDING (lead-verified by direct grep/read).** (1) `ww3_to_swan_boundary()` DOES NOT EXIST at bdf4db8 — deleted 2026-07-26 commit `5fe77af` (T8.10c r2); only comments referencing the deletion remain (swan_formats.py:2297-2414). (2) Real multi-station 2-D spectral boundary (`ww3_spectrum_to_swan_boundary()` + `ww3_boundary_files_and_command()`, swan_formats.py:2369-2666, `BOUNDSPEC SIDE … VARIABLE FILE` from NOAA gfswave.{46222,46223,46253,46256}.spec) is LIVE for L1 — journal-confirmed. **Y-D1 Tier 1 already satisfied for L1.** (3) NO Tier 2/3 fallback exists — boundary failure hard-aborts the cycle (providers/nearshore/swan.py:2656-2723); zero `boundary_degraded` hits repo-wide. (4) NEW suspect for the ⅓-energy symptom: `surf_1d_pipeline.py:1577-1589` bulk-falls-back transects with no per-transect PT* partitions to one scalar triple (lead-verified by reading the code). (5) Doc drift: swan-commands-extract.md has ZERO BOUNDSPEC mentions. Full table: scratch/Y0-FACT-PIN-2026-08-05.md. **Y1 build ON HOLD pending operator ruling on Round Y scope (L3→1D handoff = new architectural territory, not in plan).** YQ-1 quantification dispatched. | Y0 done; Y1 held |
| 00:55 | **MEM-1 DONE (lead-verified).** OOM root cause: `_load_forecast_cache_from_disk()` (providers/nearshore/swan.py:1482-1539) monolithically json-loads the on-disk forecast cache at every startup; live file `/var/run/weewx-clearskies/swan/forecast_cache.json` = **223 MB** (lead-verified ls; July 26 pre-cleanup snapshot was 24 MB → ~10× growth in 10 days); agent caught RSS 293 MB→1.4 GB in 8 s at startup. Secondary: un-trimmed "transect" cache key holds 162-transect 1-m-resolution arrays per timestep (surf_1d_pipeline.py:2347). Hotstart .dat chain ruled out (file-rss ≈ 0 in all kill records — heap, not file-backed). Timeline: kills sporadic from 08:38Z (pre-dates bdf4db8), continuous from 22:23:59Z = 7 min after bdf4db8 deploy restart (22:16:57Z); radar container ~2 GB sharing the 6 GB cap. Verdict: accumulation (growing cache) + marginal baseline; Round-S deploy correlation medium-confidence proximate trigger. Full report: scratch/MEM-1-OOM-INVESTIGATION-2026-08-05.md. **Remediation needs operator ruling (cache trim/lifecycle = persisted-file/data change = trigger 7; LXC cap raise = infra).** | Surfaced |
| 01:00 | Dispatched YQ-1 (energy-deficit site quantification) + X0 (Round X anchor re-pin + Round-W guard-test inventory), both read-only Sonnet, running | In flight |

## Parking lot

- `repos/weewx-clearskies-swan-swelltrack` local checkout confusion risk: legacy repo shares
  "SWAN" naming with live marine repo. reference/clearskies-dev.md repo tables still list the
  superseded topology (known residual staleness flagged 2026-08-02).
