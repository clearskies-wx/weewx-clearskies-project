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

| 01:20 | **X0 DONE (lead-verified by direct grep/read).** (1) `apply_ddd_saturation` :615-749 matches plan exactly. (2) **Plan correction:** zones are NOT plumbed in surf_1d_pipeline.py — construction happens in `endpoints/beach_profile.py` (imports `_classify_zones`/`_classify_zones_per_break` at :113-114, call ~:732-745, on a SwellTrack/SurfBeat-blended Hs array); `Analytical1DResult.surf_zones` is dead output (zero reads in pipeline — lead-verified grep). X-D3's E_r→zones plumbing is a 3-file surface: analytical (compute) → pipeline (carry fields) → beach_profile (call site). beach_profile.py is NOT in X-D5's allowlist → allowlist extension goes in the X dispatch packet for operator sign-off. (3) **Revival opportunity:** `_solve_breaking_fraction()` (:236-316, exact B-J relation), `_battjes_janssen()` (:319-405), `_roller_model()` (:408-449) exist as deprecated dead code (zero live call sites — lead-verified; removed from live path by e048494/Round W1, kept pending dead-code sign-off). Consistent with X-D1's "the SAME solve this repo carried pre-Round-W" — coordinator ruling: X1/X3 implement by revival/adaptation of these, per plan text. (4) **Second γ·d cap the plan doesn't name:** `surf_1d_pipeline.py:754` `min(hs_break, gamma*d_break)` in `_combine_partition_faces_11_3` (BD-4 face-height depth cap) — lead-verified. In/out of X-D4 scope = operator question for the X dispatch packet. (5) 15 cm floor `_MIN_BREAK_DEPTH_M=0.15` (:892) exists only as publication filter (:937,:958) + runaway-mask bound (:735) — X-D1's state-machine reform-forbid is genuinely new code. (6) Guard tests: 9 files/~30 tests — 1 file/6 not superseded (constants control), 2 files/9 clearly superseded (w5_saturation cap, w2_bar_trough onset/cessation), 3 files/~13 uncertain → X5 test-author dispositions each. (7) X-K2 fixture live on librewxr: profiles_by_transect["55"], 261 pts, bar depth-min 1.545 m at 79.74 m — corroborates plan's 79.7 m. Full tables: scratch/X0-FACT-PIN-2026-08-05.md. | X0 done |

## Open items for the X dispatch packet (operator rulings needed AT X dispatch, collected here)
1. Extend X allowlist with `endpoints/beach_profile.py` (zone plumbing actually lives there; plan's X-D5 is stale on this point).
2. Second γ·d cap at `surf_1d_pipeline.py:754` — inside or outside X-D4's cap-deletion scope? (Different mechanism: face-height depth cap at the break, not the W1b marched-vs-raw cap.)

| 02:00 | **Operator rulings on swan-commands-extract executed (commit `caf49e8`, lead-verified + pushed).** File stripped to pure manual extract (598-line diff), FROZEN header added (operator's verbatim language; may not be amended w/o direct authorization; may not contain non-manual language); project content → new PROVIDER-MANUAL §14.15 "Measured deviations of the deployed SWAN binary (41.51AB)"; duplicates deleted (agent inventory maps every block); CLAUDE.md routing row + clearskies-dev.md descriptions fixed; plan's extract doc-row struck with dated note. Gate: stat clean vs allowlist (5 files; ARCHITECTURE untouched — nothing unique needed placement); residual-content greps zero; TABLE HEADER|NOHEADER correction grounded at manual :5054. Version corrections ruled+applied: manual is v41.51 (file line 5), NOT v41.45 as older labels claimed. | DONE caf49e8 |
| 02:05 | **Deployed SWAN binary version settled by ground truth:** PRINT output self-reports **41.51AB** (librewxr, level2/PRINT). Fixed stale "SWAN 41.45" binary claims: PROVIDER-MANUAL:1859, OPERATIONS-MANUAL:1151 (lead-direct, mechanical). | DONE (this commit) |
| 02:10 | **Z-PREMISE-AUDIT DONE (lead spot-verified).** Root causes #1/#3 + all Round Z: 9 VERIFIED / 3 PARTLY / 1 reproduced-live / **0 STALE, 0 contradicted** — plan damage confined to Round Y. Spot-checks: pulled-label operator ruling REAL (BeachProfileCardBody.tsx:108-114, 2026-08-02 BD-9 header removal); coexisting hash-keyed bathy cache generations REAL (Aug1/2/3/5 siblings live). Two pre-dispatch corrections: Z-D2 teardown list missing 5 artifact classes; Z-D1 transect label conflicts w/ 2026-08-02 ruling → DECIDE item. "Index 27" selection failure reproduced live in current forecast cache (2026-08-08 forecast hours). Full table: scratch/Z-PREMISE-AUDIT-2026-08-06.md. | Audit done |

| 02:45–03:00 Aug 6 | **M-0 / D-1a EXECUTED.** Pre-flight: kill loop had run through 01:00Z (dmesg pasted in session); current process survived 01:02→02:45Z; cache file had self-shrunk 223→109 MB (rewritten by a completed cycle at 01:21Z). Baseline ERROR/WARNING classes captured (scratchpad m0-journal-baseline-classes.txt). D-1a: service stopped; `forecast_cache.json` (108,905,437 B) moved aside — **preserved at `/home/ubuntu/forecast_cache.json.oom-m0-aside-20260806`** (moved OFF tmpfs to disk; do not delete); `scripts/deploy-marine.sh` full deploy → running commit `d74c578`, process started 02:47:46Z, /health+/manifest 200, auth 401 enforced. Post-restart RSS ~200 MB (vs 1.4 GB in 30 s previously) — startup monolithic load eliminated. /health = "no cycle has ever completed" = the pre-authorized one-cycle forecast gap; awaiting first full cycle. | D-1a done |
| 03:00 Aug 6 | **M-0 finding 1 — plan detail corrected by measurement (streaming grep byte-offsets on the preserved 109 MB file):** the heavy key is `"spectral"` = **104.0 of 108.9 MB (95.5%)** — a full 2-D SPECOUT spectrum (energy+freqs_hz+dirs_deg) for EVERY transect at EVERY timestep (5,508 = 34 ts × 162 tr). The plan's named `"transect"` key is **39 KB** (its only readers: two wave-setup sites reading one scalar, swan.py:3203/:3950). D-1b remediation unchanged in shape (bound what forecast_cache.json persists — same file, same per-transect-arrays mechanism, same trigger-7 pre-authorization); the key to bound is `spectral`, not `transect`. | Correction recorded |
| 03:00 Aug 6 | **M-0 finding 2 — tmpfs = RAM: `/run` is tmpfs (9.4 G, 3.2–3.3 G used)**, so the ~3.6 GB SWAN work tree incl. MEM-1's ~2.5 GB duplicate hotstart copies is charged against the SAME 6 GB memcg cap (closes MEM-1's unexplained gap: lxc 5.58 GiB usage vs ~2.5 GB summed process RSS). Fixing the hotstart duplication is a persisted-file change NOT pre-authorized by the plan → surfaced to operator as a finding, not touched. | Surfaced |

| 03:05–03:15 Aug 6 | **M0-D1B FACT-PIN DONE** (`scratch/M0-D1B-FACT-PIN-2026-08-06.md`; lead spot-verified the load-bearing claim by independent grep — zero live readers of `freqs_hz`/`dirs_deg`/`energy` in the cached spectral entries, top-level or per-transect; only same-cycle consumer gets them as a direct arg BEFORE cache.set; full runs REPLACE spectral wholesale — growth traces to the per-transect handoff feature (d803d9c/f337648, 2026-07-29/30), no append bug). **D-1b design ruled (lead): trim `freqs_hz`/`dirs_deg`/`energy` from spectral entries at the payload-build/cache boundary (swan.py:3480)** — bounds in-memory 7-day cache AND persisted file; + `_FORECAST_CACHE_WARN_MB = 64` fire-only size-guard WARNING in both persist paths; read-side comment; tests (trim/round-trip/guard); docs same task (OPERATIONS-MANUAL cache lifecycle; ARCHITECTURE "keeps full untrimmed data" sentence now stale → amended). Dev dispatched (Sonnet, marine repo, serialized — sole agent in repo). Expected post-fix: cache < ~15 MB at 34 ts (was 109–223 MB); live check = `"freqs_hz":` count 0 in new file. | Dev in flight |

| 03:14–03:25 Aug 6 | **First post-D-1a cycle COMPLETED CLEAN** (T4B.6 162/162 at 03:14:21Z; "full SWAN cycle complete" 03:19:11Z; zero kills) — and it rewrote forecast_cache.json at **233.5 MB from ONE cold-start run** (49 HRRR hours), proving per-cycle regeneration, not slow accumulation. **D-1b ACCEPTED + DEPLOYED**: lead acceptance gate green (independent 9-test run `9 passed`; `git show --stat` matches allowlist both repos — marine `9535e8a` swan.py +90/-1 + new test file; meta `072c27b` 2 doc files; trim function + wiring spot-opened; quick-update path verified clean). Deploy sequence (no-gap): `--no-restart` pull → stop → fresh 233 MB cache moved to `/home/ubuntu/forecast_cache.json.pre-d1b-trim-20260806` (preserved) → offline trim via the DEPLOYED `_trim_spectral_for_cache` in a throwaway process → **17,171,632 bytes** → `--skip-pull` restart. Verify: running commit `9535e8a`, process 03:21:56Z, health/manifest 200, auth 401, restore-from-disk INFO logged (last-good serves, no forecast gap), RSS 535 MB, live check `"freqs_hz":` in persisted file = **0** (expected 0). Pushed: marine `d74c578..9535e8a`, meta `84df600..c42fecb` (incl. `072c27b`). | D-1b live |
| 03:25 Aug 6 | **M-0 GATE CLOCK STARTED** at process start 03:21:56Z on `9535e8a`: 4 consecutive OOM-free cycles (full-run or stationary-fill completions; skips don't count), then dmesg/journal raw evidence + pre/post WARNING-class sweep (baseline in session scratchpad) + /health ok + publish-liveness. Watcher polling 5-min. **H-1 dev dispatched** (local repo only; brief = `briefs/H1-DISPATCH-BRIEF-2026-08-06.md`; deploy embargoed until M-0 closes). | Gate watch |

| 03:30–04:10 Aug 6 | **H-1 BUILD COMPLETE.** Dev `5ca8fcc` (4 exits instrumented [plan said 3, code has 4], per-hour aggregate WARNING, bulk-fallback state registry + /health reasons floor-at-degraded, distinct `ww3_boundary_refused` slug); one design gap surfaced by dev (spot_id absent in surf_1d_pipeline) → lead ruling option (b) (count rides PipelineResult, state write at swan.py precompute site; brief amended in place); test-author caught a REAL defect pre-deploy (total collapse + no bulk substitute → `_degraded_result()` dropped the count to 0 — the exact worst case) → fix `e221a06`; tests `27bb9b3` (18 tests; forced-collapse test carries the behavioral fail-pre-change transcript). ADR-103 authored fresh `d34330f` (file never existed — plan's "REWRITE" premise corrected) + INDEX row; kd-tolerance doc-drift finding fixed lead-direct `9b6bd64`. All pushed. Test-author bonus finding for the gate: exit 2 (`breaking_zone_exhausted`) structurally unreachable via genuine data (BD-1/BD-2 share array+threshold) — narrows mechanism B to exits 1/3/4. H-1 deploy embargoed until M-0 closes. | H-1 built |
| 04:10 Aug 6 | **SW-1a VERDICT (lead spot-verified the buoy leg independently): the ~9 s swell train NEVER ENTERS OUR INPUT.** gfswave.global.0p16 station spectra = one unimodal 12.7 s/185° peak, all stations, all target hours (raw BOUND_*.txt parsed); NDBC 46253 hardware resolves a distinct 9.09 s secondary peak (local min at 9.9 s then +63% rise — lead re-pulled and confirmed); Surfline LOTUS + surf-forecast carry it. Nothing downstream loses it. Fix = data-source change (trigger 7 + touches the operator's WWIII-grid mandate) → OPERATOR OPTIONS SURFACED: (a) accept+document, (b) investigate finer WW3 regional product (lead rec), (c) buoy-blend (not rec). Direction delta (+15.6° vs Surfline) assessed as plausible refraction (deep-water vs 15 m reference), not a defect. Evidence: scratch/SW-1A-SWELL-CHAIN-2026-08-06.md. | Awaiting operator ruling |

| 04:15–04:25 Aug 6 | **Operator orders executed:** (1) SW-1b findings reported (regression = `_effective_swell` deleted 2026-07-18 `ea47ed6`+`66c9634` w/ its tests; both cards read bulk TM01/MWD; fix scope proposed, awaiting go). (2) **WW3 source ruling → register item 10 + task SW-2:** wavewatch.py display provider found on PacIOOS ERDDAP (`aa077d4` "point at reachable ERDDAP origin" — born on ERDDAP at T1.3, never converted, ported as-is `4c206a9`; NOT a regression of the 3-day boundary work, which is verified intact live). SW-2 = NOMADS gfswave GRIB2 rewrite incl. native swell partitions; ERDDAP deleted; refuse-on-failure; fact-pin dispatched. Boundary same-product cycle retry retained pending explicit operator word. (3) X12 ACCEPTED (bce8997, lead-verified: controls 17/17, exactly 1 expected fallout failure w1_kat marker-index, cap intact, constants exact); X3 dispatched (roller per X-D3 + lead calls: combined-profile E_r published, zones' er param optional, reform_trough untouched, closure ratio field for X4). | SW-2 + X3 in flight |
| 04:20 Aug 6 | **M-0 gate cycle 1 running SLOW (~55+ min vs 26 min cold cycle), NOT stalled:** L1/L2/L3 converged by 03:38; L4 prep (162-transect generation logged 03:38:09) + heavy GIL contention with dashboard-poll on-demand recomputes (same 04:00Z timestep recomputed every ~50 s — pre-existing inefficiency, PARKED as a finding; not D-1b-related, trim fields unread by that path). No kills; RSS 1.8 GB. Cycle-overrun degraded at 60 min is transient-by-design. Watch continues; >80 min or silent journal ⇒ stall investigation. | Watching |

## ═══ CONTINUATION CHECKPOINT — written 2026-08-06 ~04:30 UTC at operator compact order ═══

**Read this section FIRST on resume. State of every track, exact next actions.**

### Repo state (all pushed except noted)
- Marine repo `repos/weewx-clearskies-marine`: HEAD `bce8997` (X12) — PUSHED through `27bb9b3`;
  `bce8997` NOT YET PUSHED (local only). Commits since plan start: `9535e8a` (D-1b cache trim,
  DEPLOYED), `5ca8fcc` (H-1 instrumentation), `e221a06` (H-1 counter fix), `27bb9b3` (H-1
  tests, 18), `bce8997` (X12 Q_b state machine — ACCEPTED by lead, controls 17/17, exactly 1
  expected fallout failure = w1_kat marker-index).
- Meta repo: pushed through `9b6bd64`; UNCOMMITTED right now: plan decision-register plain-
  English rewrite (operator order), this scratch update, SW-2-FACT-PIN doc (committed in the
  checkpoint commit that carries this text).
- **x3-dev agent (roller, X-D3) is MID-FLIGHT in the marine repo** — will commit
  `feat(x3): ...` touching surf_1d_analytical.py + surf_1d_pipeline.py + endpoints/
  beach_profile.py. Its scope-ack was confirmed. If resuming and it's dead with no commit:
  re-dispatch from briefs/X-DISPATCH-PACKET-2026-08-06.md §X3 + the lead calls recorded in the
  04:15 log row above.

### Deployed state (librewxr)
- Running commit `9535e8a`, process started 03:21:56Z. Cache trimmed (17.2 MB, freqs_hz=0).
- Preserved artifacts (do NOT delete): `/home/ubuntu/forecast_cache.json.oom-m0-aside-20260806`
  (109 MB) and `/home/ubuntu/forecast_cache.json.pre-d1b-trim-20260806` (233 MB).
- **M-0 gate: cycle counting since 03:21:56Z. Criterion: 4 consecutive OOM-free cycle
  completions** (`full SWAN cycle complete` or `stationary fill complete` journal lines; skips
  don't count) + zero `killed by the OOM killer` + /health ok + journal sweep vs baseline
  (scratchpad file m0-journal-baseline-classes.txt — regenerate from journal since 01:02 if
  lost; the top pre-existing classes: runaway W1b WARNINGs, L-handoff-outside-grid, PT*
  bulk-fallback, HRRR Lambert, provider 4xx). Cycle 1 (started 03:22:57Z) was SLOW (~60 min,
  GIL contention w/ dashboard request storm) but alive at checkpoint, 0 kills. Watch command:
  `ssh -F .local/ssh/config librewxr "sudo journalctl -u weewx-clearskies-marine --since '2026-08-06 03:21:56' --no-pager | grep -cE 'cycle complete|fill complete'"` and same with
  `grep -c 'killed by the OOM killer'`. **After M-0 closes: deploy sequence is H-1 first, then
  X (after X gate), SW-2 with/after X per one-change-per-deploy.**

### Task states
- **M-0**: D-1a+D-1b DONE+deployed. Gate = cycle watch (above) + close record w/ raw output.
- **H-1**: BUILD COMPLETE (code+tests+ADR-103 `d34330f`). Deploy after M-0 close via
  scripts/deploy-marine.sh; then live checks (clean-cycle: no bulk_fallback reason in /health;
  H-1 WARNINGs only on collapsed hours) + six-row gate incl. blind adversarial audit (brief in
  plan; auditor must NOT see dev tests/commits). Gate extras on record: 4 exits not 3; exit 2
  (breaking_zone_exhausted) structurally unreachable via genuine data (test-author proof, in
  test file module docstring); threshold = max(8, ceil(0.25·n)).
- **Round X**: X12 DONE+accepted (`bce8997`). X3 IN FLIGHT (see above). Then X4 (delete W1b cap
  `min(marched, float(hs_total[i]))` — grep-single-occurrence in surf_1d_analytical.py — + wire
  INVARIANT_11 roller-closure-1% reading `roller_closure_worst_ratio` field X3 exposes +
  INVARIANT_12 no-gain marched ≤ raw+1mm, per packet). Then X5 test-author (X-K1..K4 KATs +
  dispositions of every file in X0 Table 2 — note X12 fallout was LIGHTER than X0 predicted:
  only w1_kat failed; w2/w4/w5/w8 passed unmodified — X5 must re-derive/justify each anyway).
  Then X6 docs (ADR-102 + ARCHITECTURE + API-MANUAL §17-18). Then X7 six-row gate + deploy +
  reality gate (webcam row on first ≥3ft/≥12s day). S-5 (dominant-partition direction,
  EYEBALL-FIX plan) + SW-1b fix ride X's window WHEN OPERATOR APPROVES SW-1b scope.
- **SW-1a** DONE: 9s train absent from NOAA gfswave station-spectra input (buoy hardware has
  it; lead re-verified). AWAITING OPERATOR RULING: (a) accept+document / (b) investigate finer
  NOAA WW3 regional product (lead rec) / (c) buoy-blend (not rec).
- **SW-1b** DONE: both cards read bulk TM01/MWD (never multiSwell); prior fix
  `_effective_swell()` (API repo `5be33fc`) deleted 2026-07-18 (`ea47ed6`+`66c9634`) WITH its
  tests. AWAITING OPERATOR GO on fix scope: dominant-partition semantics for published
  period/direction/text + unify tie-breaks + add missing guard; rides X window. Caveat to
  verify at fix time: live hour showed multiSwell ranking a 1.83m "wind swell" above
  groundswell — numbers matching nothing else; possible second wrinkle.
- **SW-2** (operator ruling, register item 10): fact-pin DONE
  (scratch/SW-2-FACT-PIN-2026-08-06.md). Key design inputs: product
  `gfs.YYYYMMDD/CC/wave/gridded/gfswave.tCCz.global.0p16.fXXX.grib2` hourly f000-f120 +
  3-hourly to f159; `filter_gfswave.pl` bbox/var subsetting works (2 live test downloads
  parsed w/ repo eccodes); EXACTLY 3 swell partitions in .idx; **trap 1: NOMADS names
  (HTSGW/WVHGT/SWELL) ≠ eccodes shortNames (swh/shww/shts) — table in fact-pin; trap 2:
  grib_processor.py keys by shortName only → would silently drop 2 of 3 swell partitions —
  needs level-aware keying; trap 3: all 3 wavewatch call sites in endpoints/marine.py catch
  bare Exception and degrade silently — operator's refuse-on-failure requires changing call-
  site except shape too (RFC9457 handler exists at errors.py:74-118 but never reached)**.
  Cycle pattern to mirror: GFS wind's (6h lag, snap to {0,6,12,18}, step-back, 
  ProviderUnavailableError). GL: wavewatch is ocean-only today; GLWU gridded GRIB exists
  (one-file-all-hours). NEXT ACTION: lead writes SW-2 dev brief from fact-pin (allowlist:
  wavewatch.py rewrite + endpoints/marine.py except-shape + grib_processor level-aware fix OR
  local parse helper; tests; docs PROVIDER-MANUAL). Deploy post-M-0 sequence.
- **Round Z**: not started. Seed Z0 from scratch/Z-PREMISE-AUDIT-2026-08-06.md (expanded
  teardown list). D-7 label wording at Z gate.
- **Operator rulings OPEN**: SW-1a (a/b/c); SW-1b go; boundary same-product cycle-retry
  keep/kill (lead rec keep); tmpfs hotstart duplication (~2.5 GB RAM on /run tmpfs, MEM-1 —
  fix not pre-authorized).

### Standing constraints (unchanged, from plan + kickoff)
Sonnet agents only for delegated work; never full pytest; every brief carries git/arch/stale
blocks verbatim; deploys only via scripts/deploy-marine.sh; one functional change per deploy;
six-row gate per round incl. blind adversarial audit; swan-commands-extract.md FROZEN;
journalctl on librewxr needs sudo; port 8780 TLS (`curl -sk`); binary 41.51AB; plain English
to operator — DECISION REGISTER NOW IN PLAIN ENGLISH (operator order 2026-08-06, keep it so).

## Parking lot
- **NEW (2026-08-06): request-path on-demand recompute storm** — dashboard polls re-run the full 162-transect 1D pipeline for the SAME timestep every ~50 s when a field (e.g. wind) is unavailable in cache; no request-side memoization of the recompute result. CPU-starves the runner (GIL). Pre-existing; surfaced during M-0 cycle-1 watch. Candidate follow-up task after M-0/H-1.

- `repos/weewx-clearskies-swan-swelltrack` local checkout confusion risk: legacy repo shares
  "SWAN" naming with live marine repo. reference/clearskies-dev.md repo tables still list the
  superseded topology (known residual staleness flagged 2026-08-02).
- Stale brief refs to moved extract sections (flagged by extract-strip closeout, outside its
  allowlist): `docs/planning/briefs/MARINE-L4-DEGRADED-HANDOFF-2026-07-29.md:57,103` (cites former
  "§WHY THE HOTSTART ACTUALLY FAILS"), `P4B-AGENT-A-BRIEF.md:151` / `P4B-AGENT-B-BRIEF.md:113`
  (cite former PARSER TRAP/PT* content). Content now lives at PROVIDER-MANUAL §14.15.
- Marine repo `pyproject.toml` comment block still says "SWAN 41.45" — binary is 41.51AB
  (PRINT-verified 2026-08-06). Fix in a future marine-repo commit, not doc-only.
- Proposed rule additions NOT yet written (awaiting operator word): (1) plan claims carry
  file:line at a named commit verified at drafting; (2) coordinator reads (not greps)
  ARCHITECTURE's relevant section at dispatch.
