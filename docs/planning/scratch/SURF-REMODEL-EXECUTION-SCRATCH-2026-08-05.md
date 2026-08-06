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
- **Operator rulings OPEN**: SW-1a (a/b/c); SW-1b go; whether SWAN boundary must ALSO
  wait-and-poll like SW-2 now does (ruling 10 update 2026-08-06 — cards ruled, boundary
  question open, lead rec no); tmpfs hotstart duplication (~2.5 GB RAM on /run tmpfs,
  MEM-1 — fix not pre-authorized); X3 closure-scoping lead ruling reported (operator may
  override).

### 2026-08-06 ~04:45Z — post-compact resume: X3 ACCEPTED; register ruling 10 landed; X4 dispatch

- **X3 ACCEPTED** (commit `9b6a669`, pushed). Acceptance evidence (lead's own runs, fresh
  shell): `git show --name-only` = exactly the 3 allowlist files (surf_1d_analytical.py,
  surf_1d_pipeline.py, beach_profile.py); controls `pytest test_ddd_breaking_w3_constants
  test_ddd_breaking_w6_detection_from_state test_break_detection_z2 -q` → **17 passed**;
  fallout `test_break_aware_handoff_domain test_ddd_breaking_w1_kat test_ddd_breaking_w2_bar_trough
  test_ddd_breaking_w5_saturation -q --tb=line` → **8 failed, 14 passed**, every failure
  `TypeError: ... missing 1 required positional argument: 'T'` (w1_kat 3, w5_saturation 5 —
  both files in X0 Table 2 superseded bucket). Dev's delta note accepted: implemented X-D3's
  roller balance verbatim (no leading 2 in D_r), dead `_roller_model` untouched.
- **X3 finding 1 (T signature break) → routed to X5**: 7 of the 8 fallout failures are
  signature breaks (missing new required `T` param at direct call sites), NOT the semantic
  drift X0 predicted; X5 must add a period argument at every call site in those two files
  AND re-derive expected numbers. `T` required-with-no-default upheld per rules/coding.md §1
  (no silent default physics inputs).
- **X3 finding 2 (closure ratio ~0.34 at shoreline) → LEAD RULING (methodology)**: the
  worst-step closure residual legitimately blows up at the last step before the eps-floored
  depth (0.01 m) because X-D3's own `D_r = g·β_D·E_r/c` diverges as c→0 — a floor artifact,
  not march dishonesty. RULING: `roller_closure_worst_ratio` accounting EXCLUDES any step
  where either endpoint's depth is at/below the numerical depth floor or the phase speed is
  at its floored minimum; the 1% invariant threshold itself is UNTOUCHED. This is scoping
  what the QC measurement covers, not changing physics or the plan's threshold. X4-dev
  implements; reported to operator (can override). X4 must re-run the synthetic bar/trough
  sanity and report the SCOPED worst-ratio — if still >1% away from floored steps, STOP
  (no tuning).
- **Register ruling 10 UPDATE (operator, in chat)**: old-batch reuse DEAD for forecast
  cards — wait-and-poll for NOAA publication ("We operate on NOAA's timeline, not our
  timeline"). Binding SW-2 design: on refresh, if newest expected cycle unpublished →
  do NOT process older cycle; poll until published; previously processed forecast stays
  served. NEW OPEN QUESTION posed to operator: whether SWAN boundary download (which
  always uses newest PUBLISHED run via the step-back at swan.py:2738-2743 /
  `select_boundary_stations_with_cycle_fallback`) must also wait — lead rec NO (it already
  lives on NOAA's timeline; waiting = no surf forecasts ~60% of hours). Register item 10
  updated in plan; item 1 got a how-it-sticks sentence (20% hysteresis); item 2 rewritten
  as record-not-question; register header now states it is a RECORD (operator misread it
  as a questionnaire — items 3/4/7 reactions).
- **M-0 watch (re-established post-compact)**: 0 OOM kills since 03:21:56Z; cycle 1 still
  running at 04:35Z (~73 min, slow per GIL-contention diagnosis), service alive and logging.
- **X4 dispatched** (Sonnet, marine repo @ 9b6a669): W1b cap deletion + INVARIANT_11
  (closure 1%, with the scoping ruling above) + INVARIANT_12 (no-gain ≤ raw + 1 mm);
  allowlist services/surf_1d_analytical.py + services/invariants.py, STOP if wiring needs
  a third file.

### 2026-08-06 ~05:10Z — X4 ACCEPTED; M-0 cycle 1/4 CLEAN; D-7 re-ruled; X5 dispatched

- **X4 ACCEPTED** (commit `2bb1cd1`, pushed). Lead's own runs: `git show --name-only` =
  exactly the 2 allowlist files; exact cap expression `min(marched, float` = 0 occurrences
  (3 remaining greps are historical docstring text describing the deletion — acceptable);
  second γ·d cap intact at pipeline :828; combined 5-file targeted run → **31 passed**;
  fallout w1_kat/w5_saturation unchanged → **8 failed** same TypeError-missing-T mechanism.
  Closure-scoping ruling verified working: dev showed UNSCOPED worst ratio 0.3444 exactly at
  the eps-floored (0.01 m) last grid point, SCOPED ratio 3.4e-15 — exclusion does real work,
  march is honest away from the floor. INVARIANT_11 wired in both marches; INVARIANT_12 in
  apply_ddd_saturation only (the only march with an interior raw reference — accepted
  rationale).
- **Stale comment found by lead during acceptance (X6 sweep item):** surf_1d_pipeline.py
  :738-741 still says "apply_ddd_saturation now bounds its own output by min(marched,
  hs_total_raw)" — describes the cap X4 just deleted. The redistribution ratio there is
  now guarded by INVARIANT_12 (≤ raw + 1 mm) instead of a hard bound; comment must be
  rewritten by X6 (file was outside X4's allowlist, correctly not touched).
- **M-0: cycle 1 of 4 CLEAN** — journal shows `1 × "full SWAN cycle complete"` since
  03:21:56Z, KILLS: 0. Slow (~90 min, GIL-contention diagnosis stands) but completed.
- **D-7 RE-RULED (operator, in chat): NO beach-line label at all** — selection fix ships
  invisibly; Z-gate wording approval dropped. Plan DECIDE + register item 8 updated
  (abdd4d0). D-4 wording corrected: log warnings, not "alarms".
- **Operator D-5 follow-up answered** (in chat): combined RSS total is run through the full
  breaking physics (`apply_ddd_saturation` at pipeline :732) — addition-induced breaking IS
  registered (dissipation, roller/whitewater, zones); the D-5 cap only clips the reported
  face-height figure at the primary swell's already-registered break point.
- **X5 dispatched** (Sonnet, test-author, marine repo @ 2bb1cd1): X-K1..K4 KATs +
  state-machine units + X0 Table 2 dispositions + T-signature call-site fixes in
  w1_kat/w5_saturation; fail-pre-change transcripts vs pre-Round-X commit `27bb9b3`.

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

### 2026-08-06 ~05:40Z — operator order: code first, testing backed off; three agents in flight
- **Operator order**: "back off testing and get the shit coded" → X5 (KAT/test round) DEFERRED;
  still required before X's DEPLOY gate per plan (sequence now: all code first, X5 last
  before deploy). Interpreted as GO for SW-1b (restores previously-approved behavior).
- **SW-1b re-scoped to MARINE repo (dev caught lead's brief error, good stop)**: surf_scorer.py
  moved api→marine in Marine Service Separation (api commit 9df764c deleted it); the defect
  (`score_surf()`/`_select_reference_point()` ref_point bulk TM01/MWD) lives at
  marine `enrichment/surf_scorer.py` + `endpoints/surf.py`. Authorized: marine @ 2bb1cd1,
  allowlist surf_scorer.py + surf.py (if threading requires) + one pinning-test file;
  Round X files + swan.py explicitly out of scope. api repo's marine_enrichment.py = pure
  template fill, nothing to restore there. "sw1b-selection-regression" agent name = stale
  pre-compact residue, ruled not a real teammate.
- **SW-2 dispatched in parallel** (api repo @ 62ee7b2 now free): NOMADS gfswave GRIB2 via
  filter_gfswave.pl + eccodes; ERDDAP deleted outright; ruling-10 wait-and-poll (NO older-
  cycle step-back; poll constant ~10 min gate-reviewed); LEAD RULING flagged to operator:
  cold-start bootstrap = fetch newest PUBLISHED cycle (nothing substituted; steady-state
  rules apply after). Call-site except narrowing (trap 3), level-aware grib keying (trap 2),
  minimal targeted tests only.
- **Z0 fact-pin agent in flight** (read-only, marine repo): selection/anchoring/teardown pins
  → Z code dispatches from its output.

### 2026-08-06 ~06:05Z — M-0 GATE RESET: OOM kill at 05:00:43Z — WORK-STOPPER surfaced

- **Kill evidence**: guest journal 05:00:43Z "killed by the OOM killer"; systemd: marine
  consumed 3h23min CPU, **3.5G memory peak, 2.8G swap peak** (the 03:21:56Z process — cycle 1
  + start of cycle 2). Host dmesg (ratbert, ~04:59Z UTC): CONSTRAINT_MEMCG,
  oom_memcg=/lxc.payload.librewxr, victim task=weewx-clearskie **anon-rss:2671208kB (2.67G)**;
  the FAULTING allocation came from a docker cpuset (radar container) — radar allocated,
  container hit the 6G cap, kernel killed marine as biggest task. Service auto-restarted
  05:00:48Z (restart counter 1), now healthy at 935M.
- **Why D-1b didn't prevent it (D-1b still correct/working)**: startup load is fixed (fresh
  process ~200-935M vs 1.4G before; cache file 17M). But steady-state arithmetic still
  exceeds the 6G container cap: marine mid-cycle working set ~2.7-3.5G + **/run tmpfs 3.5G
  (RAM-charged; ~2.5G of it = the surfaced-but-unauthorized hotstart duplication)** + radar
  docker ~2G. Swap absorbed cycle 1 (2.8G swap peak); cycle 2 + radar allocation tipped it.
- **Verdict**: M-0's 4-consecutive-clean-cycles criterion is NOT reliably reachable by
  pre-authorized changes alone. Remaining levers all need operator word: (1) hotstart tmpfs
  duplication fix (~2.5G, marine code); (2) move SWAN work dir off tmpfs to disk (config/
  lifecycle change, trigger 5/7); (3) raise container cap (infra); (4) radar cohabitation
  (outside project). LEAD REC: (1), optionally +(2). Gate clock resets; cycles continue
  meanwhile (service healthy, kills counted from process start 05:00:48Z if/when a fix is
  ruled).
- Per the two-named-excuses rule: NOT proceeding on any of these without explicit operator
  approval — surfaced with evidence instead. Coding tracks (SW-1b, SW-2 read-phase, Z0)
  unaffected and running.

### 2026-08-06 ~06:45Z — SW-2 design rulings; Z0 saved; SW-2 GO pending SW-1b landing
- **Z0 FACT-PIN saved** (scratch/Z0-FACT-PIN-2026-08-06.md @ 2bb1cd1). Headline: plan's
  anchor-fix site (:1485-1488 COARSE) is superseded at :1629-1632 (MEDIUM) — real fix surface
  is the second write + consumers; hysteresis confirmed ABSENT; teardown inventory resolved
  (wind_timeline/incoming GLOBAL-exclude; precleanup dirs have no in-repo writer).
- **SW-2 lead rulings sent to dev**: (1) additive swell2*/swell3* optional fields CONFIRMED
  (authorized by register 10 "swell-1/2/3 breakdown"; dashboard display of them = separate
  follow-up); (2) REDIRECT on failure semantics — probe/fetch failure with last-good present
  = WARN (distinct slugs ww3_cycle_unpublished vs ww3_fetch_failed) + poll-gate + keep
  serving last-good (ruling 10: previously processed stays served; "no fallbacks" bans other
  SOURCES, not our own NOAA last-good); refusal (RFC9457, serve nothing) only when NO valid
  last-good (cold+bootstrap exhausted, or TTL-expired >24h — loud refusal by design);
  (3) cold-start bounded lookback (3 cycles) confirmed as the bootstrap ruling's
  implementation; (4) cadence preserved (72h/3-hourly/25 steps); level-aware keying design +
  except-shape approved. GO + HEAD pin flashes when SW-1b lands (one dev per repo).

### 2026-08-06 ~07:20Z — librewxr saturated; fresh evidence REVISES the memory picture
- Container pinned at 100.0% (lxc list 5.59GiB/6G); direct SSH fails at banner exchange
  (starvation, not crash); lxc-exec diagnostic (slow but returned): free = 5698/5722M used,
  0 free, 23M available. Top consumers RIGHT NOW: **marine service anon RSS 3.11G (87% CPU —
  actively computing, not hung)**, radar python 1.81G, tmpfs shared 681M, buff/cache 706M.
- **REVISION vs earlier framing**: at this moment tmpfs holds only ~0.7G (df saw 3.5G earlier
  mid-SWAN — it fluctuates with run files); the DOMINANT steady consumer is the marine
  service's own in-cycle working set (3.1G now, 3.5G peak per systemd). Marine ~3.1-3.5G +
  radar ~1.8-2G ≈ 5-5.5G before ANY tmpfs — the hotstart-dedup fix alone (earlier lead rec)
  is likely INSUFFICIENT to make 4-clean-cycles reliable. Historical budget (clearskies-dev)
  expected ~519M compute — 6× over.
- Revised options put to operator: quick unblocks = raise cap (infra) and/or evict/cap radar;
  durable = find why the cycle holds 3.1G anon (new MEM-2 investigation) + tmpfs fixes as
  secondary. MEM-2 dispatched read-only/local (no server load): size the per-cycle in-memory
  structures (162 transects × timesteps × spectra/profiles), find what's held alive
  cycle-long vs released, name the top 3 holders with file:line.
- No new kill since 05:00:43Z. No state-changing action taken on the server (nothing
  pre-authorized).

### 2026-08-06 ~08:40Z — SW-1b ACCEPTED (8bb268a, pushed); M0b in finalization
- **SW-1b ACCEPTED**: commit `8bb268a` = exactly surf_scorer.py + new test file (m0b's
  uncommitted swan_runner.py untouched/unstaged — parallel discipline held). Lead re-run:
  **68 passed** (8 new + 60 pre-existing surf-scorer suites). Semantics = 5be33fc verbatim
  (0.75/0.5 constants restored, no formula change); guard = 4 wiring-pinning integration
  tests through public score_surf() that fail on the exact 66c9634 disconnect shape.
  API-MANUAL already described the restored behavior ("Dominant period") — no doc delta.
- **CAVEAT for operator (ties to SW-1a)**: for the pinned complaint hour, upstream multiSwell
  itself ranks the 1.83m/3.8s wind swell above the 1.15m/13.1s groundswell by energy
  (0.0195 vs 0.0077) → restored selector still headlines the wind swell THAT hour (its own
  numbers now, not bulk TM01). Root cause remains the missing 9s train in the NOAA gfswave
  station input = SW-1a source decision (options a/b/c, still open).
- **M0b**: production edit done + verified (controls 9/9, 18/18); stale-proxy test at
  test_swan_handoff_guards.py:583 ruled option (b) — scoped discriminator swap authorized;
  dev finalizing single fix(m0b) commit.
- SW-2 GO fires at m0b's landing commit (HEAD pin = that commit).

### 2026-08-06 ~09:10Z — M0b ACCEPTED (181a221, pushed); SW-2 GO fired
- **M0b ACCEPTED**: commit `181a221` = exactly swan_runner.py + guards-test discriminator
  swap (authorized) + new 5-test file; tree clean; lead re-run **63 passed** across all four
  files. Dead-field removal at all 3 attachment sites (L3/L4 selector :1062-1071; L2 DWR
  baseline :3603-3609; L2 DWR per-cell :3711-3718 — pre-edit lines at 2bb1cd1); zero-reader
  re-verify independent (parser/TRACE/ww3-dataclass/scalar-energy hits all disambiguated).
  Discriminator swap falsifiability verified (handoff_depth_m 3.8501 st.17 vs 2.4162 st.18).
  Expected effect: ~90-484 MB/cycle dead weight gone from the hourly carrier rebuild.
  Live RSS reduction unverifiable until deploy (blocked on X5 gate knot).
- **SW-2 GO sent**: HEAD pin 181a221; design frozen per ack + rulings. Marine repo queue
  after SW-2: Z1 (from Z0 fact-pin) — brief to be written during SW-2's window.
- Marine main now: 2bb1cd1 → 8bb268a (sw1b) → 181a221 (m0b), all pushed. Deploy still
  gated: X5 KATs + X7 required before ANY deploy (main carries unvetted X physics; deploy
  script ships main HEAD only). Operator word on X5 still open.

### 2026-08-06 ~09:50Z — SW-2 ACCEPTED (b924c90, pushed); PROVIDER-MANUAL §14.3 landed
- **SW-2 ACCEPTED**: commit `b924c90` = 8 files, all within ruled scope (4 source incl.
  responses.py per field-scheme ruling, 3 test files, 1 real NOMADS GRIB fixture). Lead
  re-run in .venv-round4: **14 passed**. ERDDAP: 7 grep hits all historical prose, zero
  live code path. Dev's fail-pre-change check on the refusal tests (stash → 2 failed →
  pop → pass) on record. Live-verified surprises: typeOfLevel=surface reports level=1
  (keying gates on orderedSequenceData, not level==0); gfswave missingValue=9999 real.
- **Doc-code sync landed** (meta repo): PROVIDER-MANUAL §14.3 replaced with the NOMADS/
  GRIB text (dev-drafted, lead-applied); §14.3a stale "NOMADS, not ERDDAP" contrast
  clause updated to product-level contrast.
- **NEW FOLLOW-UPS (backlog, not actioned)**: (1) grib_processor.py generic
  extract_nearest_value/bilinear_interpolate hardcode 9.999e20 missing-value sentinel —
  WRONG for gfswave's 9999; risk for other/future callers of the generic helpers (SW-2's
  own module self-guards). Candidate small fix task. (2) Dashboard does not yet render
  swell2*/swell3* fields (additive, populated, invisible) — dashboard-repo task.
- Marine main: 2bb1cd1 → 8bb268a → 181a221 → b924c90, all pushed. Deploy still gated on
  X5+X7 (operator word open). Next in marine repo: Z1 (brief from Z0 fact-pin + plan
  Round Z section).

### 2026-08-06 ~06:40Z (clock CORRECTED — earlier ~08:00-10:00Z stamps in this file were wrong)
- **TIMEKEEPING CORRECTION**: deploy-script output pinned real time at 06:14Z; several
  earlier entries' "~HH:MMZ" stamps ran hours fast. Durations quoted from those stamps
  ("5h stalled") were WRONG — the post-05:00:48 stall was ~1h at restart time. The
  saturation/SSH-wedge evidence was real regardless.
- **Operator rulings (chat)**: 11a RULED — NO infra change; memory footprint is our
  regression; "computations done → RELEASE THE RAM" = standing mandate (MEM-3 dispatched:
  static hunt for retained-after-use + transient giants beyond MEM-2). 11c CHALLENGED by
  operator and they were RIGHT — lead live-checked NOMADS gfswave 00z f006 at Huntington:
  partitions 12.4s/186°, 14.2s/220°, 9.2s/178° + wind 3.7s ALL PRESENT in gridded GRIB.
  SW-1a reframed: station .spec (SWAN boundary) vs gridded GRIB discrepancy to be
  investigated with this evidence; no operator decision needed now. Register 11b/11d
  rewritten in plain English (operator: "ENGLISH!").
- **Service restarted** via `deploy-marine.sh --skip-pull` (no code shipped): process
  06:14:05Z at 9535e8a, /health 200. Justification: container saturated (0 free), SSH
  banner-timeouts, thrash; restart resets ratcheted RSS.
- **NEW DEFECT found by the 11c live check**: nearest grid cell to Huntington pier is
  LAND-MASKED in gfswave (all 9999); SW-2's plain nearest-cell extraction would serve
  blanks at the flagship spot. **SW-2b dispatched**: nearest-valid-water-cell fallback,
  same-cell-for-all-fields per timestep; fixture's pier case is the ideal test.
- **Z1 ACCEPTED** (46f4d1a, pushed): 5 authorized files; lead re-run 74 passed /
  3 failed = exactly the pinned-old-BD-9-tiebreak tests (Z4 disposition). Sticky
  selection LIVE-WIRED (not inert): swan.py loop carries incumbent in time order,
  cross-cycle seed from persisted swelltrack cache, on-demand path reads same cache so
  beach-profile page and cards can never disagree. Dev self-caught+fixed an unguarded
  seed-read violating precompute's never-raises contract (203-test broader sweep clean).
- Marine main: ...181a221 → b924c90 → 46f4d1a (pushed). In flight: sw2b-dev (marine,
  wavewatch/grib_processor), MEM-3 (read-only). Next: Z2 brief (anchor fix at REAL site
  :1629-1632 + reestablish_spot per Z0), X5 awaiting operator word.

### 2026-08-06 — ING-1 COMPLETE (register 13 step 1): INGESTION IS CLEAN — energy ledger verified
- Method: fresh NOMADS fetch of raw gfswave.46253.spec (00z, f006 — same cycle/hour as the
  gridded ground truth); INDEPENDENT from-scratch parser (zero repo imports) vs our
  ww3_spectrum.py parser vs our generated SWAN boundary file round-tripped through the
  repo's own SPECOUT reader.
- LEDGER: Hs 0.5047 → 0.5047 → 0.5046 m; swell bands identical to 4 decimals at every
  stage; 8-11.7s band Hs≈0.15 m PRESENT at every stage (matches NOAA gridded 0.14m@9.23s
  partition within ~10%); direction 185° vs gridded 186°. **No energy loss anywhere in
  our chain (<0.03%). SWAN receives 100% of what NOAA's station file contains — the model
  was NOT underfed.**
- The "missing 9s swell" is a PARTITIONING phenomenon: at this station the raw 1-D
  spectrum has one smooth 12.7s peak with the 9s energy on its tail (no valley), so a
  frequency-domain split can't separate it; NOAA's gridded product splits it (their 2-D
  partitioner; directions 186°/220°/178°). SW-1A's core claim (no separable 9s peak in
  the raw file) re-confirmed independently; its "no energy" framing corrected (energy IS
  present, merged). Ingestion-defect hypothesis: NOT SUPPORTED by evidence.
- Could-not-verify: SWAN's internal boundary-grid interpolation (needs live run); whether
  NOAA's own partitioner would split the station point's spectrum.
- IMPLICATION for register-13 card rewiring: to show swell 1/2/3 from OUR OWN data, the
  service partitions the model's ingested 2-D spectra itself (standard watershed method,
  same family NOAA uses) — one source of truth AND multi-swell display. Design proposal
  going to operator; new computation = architectural, needs explicit go.

### 2026-08-06 — MEM-3 COMPLETE; M0c dispatched (next RAM cuts)
- **MEM-3 #2 (LIFECYCLE, biggest churn)**: `_align_watershed_partitions_to_curve()` at
  swan_runner.py:826-832 re-parses the SAME unchanged 1273-row CURVE table on EVERY
  transect (162×/spot/parse), and its result is PROVABLY DEAD on the live path (read only
  in the `else` branch of `if pt_table_text:` at :1041-1058; caller :6189-6210 always
  supplies pt_table_text). ~160-320 MB allocate-then-discard churn per spot per parse,
  ~24×/day — the arena-ratchet mechanism. Fix: gate call on `not pt_table_text`.
- **MEM-3 #1 (+#3)**: `parse_specout_file_multi` materializes full 35×72 energy matrices
  for ~37 stations × 34 ts (~89 MB/spot/parse) though production reads ONLY
  station_lonlat + time (energy readers = TRACE only, default off; zero prod readers —
  same evidence family as M0b). Fix: positions/time-only parse mode for the L3/L4
  handoff call site (full parse when trace enabled; default behavior unchanged) — dev
  re-verifies zero readers before cutting (M0b precedent: dropping provably-dead payload
  = methodology).
- MEM-3 #5 (profiles as list-of-dicts → numpy, 20-80MB/spot) = ARCHITECTURAL dtype
  change, backlogged for operator. #4 (`_precompute_swelltrack_for_spot` loop) verified
  ALREADY CLEAN. COULD-NOT-VERIFY: live station count, spot count, TRACE env flag,
  arena-return behavior (needs live profiling post-deploy).
- **M0c dispatched** (marine repo @ 46f4d1a): the two cuts above + targeted tests.

### 2026-08-06 — M0c ACCEPTED (2bf825b, pushed)
- Lead re-run: **71 passed** across all 6 files (H-1 18, M0b 5, guards 31, trace 6,
  decouple 1, new m0c 10); commit = exactly the 4 authorized files (incl. the one-line
  coordinator-authorized stub kwarg-tolerance fix); gate line verified present at
  swan_runner.py:839. Trace path retains full matrices (TRACE_ENABLED → parse_energy=True).
- Cuts now queued for deploy: M0b (dead spectral fields, ~90-484MB/cycle) + M0c cut 1
  (dead 162× table re-parse, ~160-320MB churn/spot/parse) + M0c cut 2 (unread SPECOUT
  matrices, ~89MB/spot/parse). ALL UNDEPLOYED pending X5 gate ("run the tests" open).
- Marine main: ...46f4d1a → 2bf825b (pushed). Next queued work: Z2 brief (anchor fix at
  the REAL site :1629-1632 + reestablish_spot teardown per Z0 inventory). Awaiting
  operator: "run the tests" (deploy gate), "go rewire" (register 13 step 2).

### 2026-08-06 — X6 ACCEPTED (meta 341bc2f + marine a4e538f, both pushed)
- ADR-102 (statistical breaking + roller) authored, Accepted status with explicit
  "X7 reality gate not yet run" caveat; INDEX row; ARCHITECTURE one-sentence delta;
  API-MANUAL §17/§18 4 surgical edits. Marine: stale W1b-cap comment rewritten
  (comment-only, 1 file). Lead spot-open verified the closure floor-scoping doc claim
  against surf_1d_analytical.py:936-948 — exact match (eps 0.01, either-endpoint,
  threshold unchanged); invariant registry names verified.
- X6 bonus finding (fixed in-scope per doc-code-sync): API-MANUAL §18's "Round Z
  hysteresis" paragraph described the legacy onset_indices=None branch not used by
  production since Round W — corrected in the same row.
- X5 fixture delivered by lead (real transect-55, 261 pts, live-pulled read-only,
  LMSL/hat_m metadata included) at tests/fixtures/transect55_profile_huntington.json —
  X5 stages it. In flight: X5, Z2, RW-0.

### 2026-08-06 — RW-1 ACCEPTED (marine ce411f2 + meta docs be3759a, both pushed)
- Surf-spot marine cards now source ALL wave fields from the model's own cached DWR
  watershed partitions (same data the surf page's multiSwell already reads) via new
  services/model_wave_source.py; bulk fields via imported production
  _bulk_params_from_components (no second formula). Wind-sea selected by is_wind_sea
  flag, never by position (SW-1b error class avoided — lead-verified in code :121-122).
  Non-surf locations untouched (fork open, register 11). wavewatch.py NOT deleted
  (gated on fork). source string honest per branch ("swan-model+ndbc+nws_marine").
  Lead re-run: 9/9 (7 new + refusal control). Doc-code sync landed same window
  (API-MANUAL field table incl. previously-undocumented swell2/3 rows; PROVIDER-MANUAL
  consumer notes).
- Remaining in flight: X5 (gate tests), Z2 (anchor + reestablish). Then X7 gate → deploy
  train → M-0/H-1 live gates → Z tail (Z3/Z3b/Z4/Z5/Z6/Z7).

### 2026-08-06 — Z2 + X5 ACCEPTED (a001d57, c49ca47+24ef58e — all pushed); X gate rows 1-2 done
- **Z2 ACCEPTED**: exactly 4 files, +1093/0; lead re-run 12 passed (their 6 + 2 control
  files); fine-preferred anchor write verified in code at :2031+ with the ordering
  rationale in-comment; consumer table on record (L2/L3/study-area unchanged by ordering
  necessity; profile extraction + L4 now FINE-preferred — ruling-6 pre-authorized).
  reestablish_spot: full inventory implemented (PROFILE-hash via documented bbox-containment
  proxy; _clear_stale_swan_run_state not spot-scoped — flagged; rebuild via real
  run_grid_sizing_chain, F1 cold-start self-arms). Live numbers (2.822→≤0.5m, 15m median)
  = Z7 gate rows. PARKED finding: `_perpendicular_bearing` vs `shoreline_normal_bearing`
  fallback resolve OPPOSITE conventions for a N-S segment (pre-existing, latent-bug
  candidate). Z5 docs still open (Z2 correctly didn't cover).
- **X5 ACCEPTED**: lead re-run **103 passed** across the full 15-file sweep. X-K1..K4 +
  state-machine units landed; every Table 2 disposition executed and justified; X-K2
  fail-pre-change transcript on record (pre-change: 1 break @36.84m; post: bar break
  @79.74m + shorebreak @28.26m + reform dip); honest non-falsifiable-pin declarations
  (X-K1 dead-code-revival; 2 X-K4 sub-tests true under old physics too) per
  verification.md. w5 deleted 2 cap-pinning tests (X-D4-named). c49ca47 commit MESSAGE
  mislabeled (content verified correct; noted in 24ef58e).
- X gate rows 1 (scope) + 2 (guards/KATs re-run) COMPLETE. Row 3 blind adversarial audit
  DISPATCHED. Rows 5-6 (deploy discipline + reality) follow the audit.

### 2026-08-06 — Z4 ACCEPTED (3a3e39d, pushed); Z3b pin saved; Z-D4 fork opened
- **Z4 ACCEPTED**: 1 new file, 24 tests; lead re-run 50 passed (24 + 26 headline control).
  Stickiness boundary pinned to the code's strict > at exactly 1.20 (double-precision
  verified); not-in-zone incumbent case documented as OBSERVED behavior for Z6 to judge;
  seed nearest = absolute-delta (can pick a LATER entry — documented, more precise than
  the function name implies; Z6 judgment candidate). Fail-pre-change: collection-level
  ImportError at b924c90 via worktree.
- **Z-D4 fork in register** (Z3b pin: premises disproved — no control points, index-only
  Y axis, radial fan geometry, no imagery georef). Z3 verify premise DOUBTFUL (card
  ignores perBreakZones — likely fix-promotion post-deploy, plan's own failure path).
- Remaining: X-AUDIT (in flight, deploy gate) → deploy train → live gates → Z3/Z3b build
  (fork-gated)/Z5 docs/Z6 audit/Z7 gate. Operator forks open: non-surf locations;
  Z-D4 path (i)/(ii)/(iii).

### 2026-08-06 — X GATE ROW 3: blind audit REPORTED 2 HIGH / 1 MED / 1 LOW — deploy HELD; XF remediation dispatched
- **Audit verdicts**: claims 1 (Q_b solve), 5 (cap deletion literal), 6 (reform floor),
  7 (constants), legacy-path — COULD NOT DISPROVE (attack list on record). Claims 2, 3,
  4(part) — DISPROVEN with reproductions.
- **F1 HIGH (accepted, fix ruled)**: apply_ddd_saturation ignores raw during BREAKING →
  mid-breaking raw drop leaves marched 603mm above raw (repro: monotonic depths, raw
  1.3→0.05 @ idx164). Violates X-D4's own stated ≤raw+1mm property. Ruled: code-vs-own-
  contract defect; fix = in-march min(marched_i, raw_i) during non-passthrough states
  (binds only when raw drops below the decaying trajectory — production case:
  structure-affected transects). NOT the old W1b post-hoc cap.
- **F2 HIGH (accepted, fix ruled)**: INVARIANT_11 closure = algebraic tautology (20k
  fuzz + derivation; can't catch wrong β_D or swapped terms; gate Row 2 vacuous).
  Ruled: second, trapezoid-discretized accumulation in-loop; residual = mismatch between
  discretizations (same equation, second arithmetic = methodology); threshold/exclusion
  unchanged; dev must demonstrate wrong-β detection.
- **F3 MED (accepted as intended behavior + false docstring)**: er-criterion legitimately
  moves impact_end, which reform_trough derives from (80m shift live in served
  reformTrough). Behavior = approved-design consequence, stays; docstring corrected;
  webcam reality-gate row will visually validate extents anyway.
- **F4 LOW**: register 11(f) wording corrected ("single grid point" → floored-step
  scoping, possibly several points).
- XF-dev dispatched (surf_1d_analytical + invariants + 1 regression-test file; KAT
  conflict = STOP). RE-AUDIT of remediations required before deploy (gate rule).
