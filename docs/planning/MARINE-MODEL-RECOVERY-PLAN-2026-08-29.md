# Marine Model Recovery Plan — 2026-08-29

**Status:** ACTIVE — APPROVED by operator in chat, 2026-08-29
**Scope:** Restore a truthful, complete WW3 → SWAN L2–L4 → SwellTrack production chain, make
automatic cold recovery deterministic, and make one health query report every required stage.
**Supersession:** This is the sole active marine recovery plan. The 2026-08-02 forward plan is
archived as historical, with a small redirect at `MARINE-FORWARD-PLAN.md` for existing links.
**No code authorization by existence:** only the operator-approved rows in the decision register
may be implemented. Open rows remain blocked.

---

## 1. Outcome

A successful production cycle serves 73 hourly forecast points, h0 through h72, only when all of
the following are true:

```text
complete time-varying inputs
  → project WW3 deep-water run and verified +0…+72 transfer
  → SWAN L2–L4 with WIND + WLEVEL + CURRENT + bathymetry
  → finite/nullable wave-group statistics
  → SwellTrack for every eligible partition/transect/hour
  → cache + endpoint publication with honest per-hour provenance
```

The runner is a background thread; raising inside it cannot restart the service. The controller
therefore includes an explicit thread-to-main shutdown channel: the runner signals a named recovery
event through `loop.call_soon_threadsafe`; the main coroutine gracefully stops uvicorn servers and
the wind-gatherer task, then exits with one designated nonzero recovery code. Normal SIGTERM/SIGINT
remains a normal zero-exit operator stop, and generic runner exceptions remain contained unless
they are converted to the named recovery request.

If valid information is unavailable, the service does not manufacture or publish a complete-
looking forecast. It enters the cold-recovery sequence in §5.

## 2. Current production failures

| ID | Severity | Verified defect | Effect |
|---|---|---|---|
| HZ-1 | Critical | Horizon merge compares time-varying point metadata as static identity | Valid 96 h continuation rejected; boundary freezes after +6 h |
| HZ-2 | Critical | Hourly fills read raw seven-record transfer | Fast cycles always freeze after +6 h even if full merge is repaired |
| HZ-3 | High | Merge materializes ~467 MB inputs repeatedly | Multi-gigabyte memory amplification / swap risk |
| SC-1 | Critical | L2 still depends on inherited SWAN-L1 `INPUT` + `B_*.txt` | Clean install or lost scaffold cannot recover |
| WG-1 | Blocker | κ=1 enters Kimura denominator `1−κ²=0` | Every full cycle aborts after L2 |
| CU-1 | Critical | OFS emits `u/v`; SWAN reads `u_grid/v_grid` | CURRENT omitted silently |
| CU-2 | Critical | OFS grid and SWAN grids differ; writer does no geographic resampling | A key rename alone is invalid |
| CU-3 | Critical | Hourly path never fetches/passes currents | Every fast fill lacks required CURRENT |
| CA-1 | Critical | MemoryCache outer TTL is 24 h; SWAN last-good TTL is 7 d | Last-good disappears after one day |
| CA-2 | High | Disk restore is one-shot and disk age gate is shorter than declared retention | Existing disk fallback becomes unreachable |
| PV-1 | High | Fast fill changes h0–h11 then overwrites one bundle `run_time` | Old h12–h72 tail appears equally fresh |
| RC-1 | High | `run_in_progress` starts after ordinary WW3 work | Guarded deploy can restart over WW3 |
| RC-2 | High | 4½ h continuation runs on sole runner thread | Full/fast triggers wait or coalesce |
| MH-1 | Critical | Raw horizon “success,” consumer merge, L2 exhaustion and publication are reported independently without a worst-stage reducer | Upstream success hides an invalid downstream cycle and suppresses useful retry |
| MH-2 | High | API/proxy response freshness can look current while model output is empty, old or invalid | Operators cannot tell transport health from model health |
| TS-1 | High | Synthetic tests omit changing WW3 point wind and κ=1→Kimura seam | Broken production paths remain green |

Evidence, exact commands, artifact sizes, matched buoy rows, and the 79-pass/1-fail baseline are
recorded in meta commit `3300f459` and are copied into each gate below where used.

## 3. Locked architecture and exclusions

Unless an operator-approved decision below says otherwise:

- WW3 remains the only deep-water model and feeds SWAN L2 through BOUNDNEST3.
- SWAN computes L2–L4 only; SwellTrack owns handoff-to-shore and breaking.
- No grid extent, resolution, handoff point, scientific coefficient, threshold, public field,
  endpoint, port, dependency, or provider family changes.
- NOAA model manuals committed under `docs/reference/` are the only SWAN/WW3 syntax authority.
- Production Belchertown remains untouched.
- Repair commits and audits remain individually attributable. Production deployments are also
  one-functional-change except where a fail-closed guard makes a later intermediate state safe;
  no restart may open a known-invalid publish path.
- Empty/unavailable is preferable to a complete-looking answer built from missing forcing.

## 4. Decision register

| Decision | Status | Operator direction / recommendation | Mechanical trigger |
|---|---|---|---|
| D1 Direct WW3→L2 command generation; remove inherited L1 scaffold | **APPROVED 2026-08-29** | Generate the complete L2 boundary command/file set in the live staging path | 2/7, approved |
| D2 Invalid-data recovery | **APPROVED DIRECTION 2026-08-29** | Restart once per failed input/runtime generation, redownload required time-varying sources, and perform a full cold run | triggers 5/6/7; exact design approved with plan |
| D3a κ=1 mathematical limit | **METHODOLOGY — NO NEW APPROVAL** | Implement exact κ→1 limit; never clamp | same equation |
| D3b κ=1 finite representation | **APPROVED 2026-08-29** (`"ok"`) | Retain finite fields; null unbounded nRep/nSet/tSet; existing scorer fallback | scientific scoring criterion |
| D4 WCOFS multi-cycle valid-time resolver | **APPROVED DIRECTION 2026-08-29** | Use prior/current same-model cycles by valid time; recovery waits when a required issue is absent | provider→model selection contract |
| D5 Missing/short horizon publication policy | **APPROVED DIRECTION 2026-08-29** | Refuse cycle, preserve verified last-good, start cold recovery | trigger 6 |
| D6 Per-hour provenance and existing age semantics | **APPROVED 2026-08-29** | Change the internal runner→endpoint cache payload; keep `lastRunTime/dataAge` tied to the selected complete full run; add no public field | trigger 4 |
| D7 Near-zero invariant publication gate | **APPROVED 2026-08-29** | Keep timestamp, return `modelStatus=unavailable`, null wave result | served null semantics |
| D8 Current-forcing health metadata | **APPROVED 2026-08-29** | Add `inputs.currents` + compact `currentForcing`; retain old key | trigger 4; persists in existing snapshot |
| D9 Horizon worker evidence | **APPROVED EVIDENCE ROUND 2026-08-29** | Benchmark checkpointed/yielding vs controlled concurrency; no worker choice yet | later triggers 5/6/7 |
| D10 Same-cycle successful WW3 reuse on SWAN retry | **APPROVED 2026-08-29** | Reuse only same-process, fingerprint-matching artifacts | trigger 6 |
| D11 SWAN hotstart quarantine before first repaired publish | **APPROVED 2026-08-29** | Transactionally quarantine tokened L2/L3/L4 hotstarts; never touch WW3 restart | recoverable state mutation |
| D12 Recovery intent + runtime generation | **APPROVED 2026-08-29** | One atomic intent under existing work root; fingerprint includes deployed revision/binary/config hashes | triggers 5/6/7 |
| D13 Unified Model Health | **APPROVED 2026-08-29; design in §16** | Stage-by-stage required health, deployed revision, API/admin reporting | triggers 4/7 |

Acceptance of this plan approves D6–D8 and D10–D13 as written. D9 remains evidence-only; worker
placement requires a later explicit choice after the benchmark gate.

## 5. Cold-recovery state machine

This implements the operator's intended behavior. “Restart” means the marine service process
exits through a named recovery path and systemd starts it again; it does not stop the host, API,
dashboard, tide, buoy, or other weather services.

```text
HEALTHY
  └─ invalid required input/output
       → REFUSE_NEW_CYCLE (last-good untouched)
       → write atomic recovery intent
       → process exits nonzero
       → systemd restart
       → REFRESH_INPUTS
       → COLD_MODEL_RUN
       → VALIDATE_COMPLETE_CHAIN
          ├─ pass → publish + clear recovery intent → HEALTHY
          └─ fail → remain unavailable/stale + retry after source change/backoff
```

### 5.1 Recovery identity and loop prevention

- Recovery identity is `(forecast_cycle, input_generation_fingerprint, runtime_generation)`.
- One automatic process restart is permitted per identity. A second failure with unchanged inputs
  does not flap systemd; it remains refused and waits for a source-generation change or the existing
  retry backoff.
- `runtime_generation` includes the deployed marine revision/package version, WW3/SWAN binary
  hashes, model-configuration hash, and grid-derivation hash. A repaired deployment is not
  suppressed by an intent created under older code.
- The input fingerprint uses stable source identities—issue cycles, valid-time/file maps, NOAA
  pin, and static hashes—never `fetched_at` timestamps.
- The recovery intent is one small atomic file under the existing SWAN work root. It records only
  cycle, source generations, reason, attempt status, and timestamps—never forcing arrays.
- A partial/corrupt intent is ignored and logged; it never authorizes cache deletion or publication.
- Input redownload occurs in a recovery-scoped generation. Provider rate limits/retry ceilings still
  apply, and partial newer data never mutates the production wind/current timeline. The generation
  is promoted only after complete-window validation.

### 5.2 What is refreshed

Cold recovery bypasses routine provider-result caches and reacquires all time-varying inputs for
the exact required window:

- NOAA boundary partitions used by project WW3.
- HRRR/GFS wind timeline.
- STOFS water level.
- WCOFS current fields, including prior/current cycles required by valid time.

CO-OPS display predictions may be warmed best-effort after a valid model publish; they do not
participate in model completeness or the recovery fingerprint. Static bathymetry, grid geometry,
and operator configuration are checksum/coverage validated. They
are redownloaded/rebuilt only when missing, corrupt, stale under their existing policy, or changed
by configuration; restarting does not gratuitously redownload static geometry.

### 5.3 Cold model state

- Cold recovery first makes all SWAN hotstarts ineligible. A fixed allowlist is copied into a
  unique quarantine, hashes are verified and fsynced, and an atomic manifest marks completion.
  Only then may originals become ineligible. Partial quarantine never authorizes deletion,
  restoration, or cold publication; rollback restores only hash-matching original names.
- WW3 cold-start semantics require a dedicated KAT/benchmark before implementation. The repair may
  not simply delete/ignore a WW3 restart if the resulting six-hour leg lacks the model spin-up
  needed for a valid boundary.
- No quarantine or recovery action touches forecast cache, grid sizing, bathymetry, or WW3 restart
  until the corresponding task's exact allowlist and rollback are approved.

### 5.4 Clean-install/bootstrap order

With no verified last-good boundary, recovery does not wait for a prior successful SWAN publish:

1. Run the six-hour WW3 production leg.
2. Run the +6…+96 continuation from its restart.
3. Validate the raw horizon and build the verified +0…+72 consumer transfer.
4. Fetch/compose every required forcing window.
5. Run SWAN L2–L4, SwellTrack, and machine-verifiable publication gates.
6. Publish the first forecast only after the complete chain succeeds.

This removes the current circular dependency where the horizon is launched only after a publish
that itself would require the horizon.

### 5.5 Publication rule

- New cache/run markers are written only after the complete chain and every automated completeness,
  convergence, coverage, provenance, and non-empty-output gate passes.
- Last-good remains unchanged on every refusal.
- With no valid last-good (clean installation), surf returns an explicit unavailable/empty state
  until recovery produces the first valid full cycle.

The human NDBC/Surfline/webcam reality comparison is a post-publish deployment acceptance gate, not
an automated runtime prerequisite. If it fails, the deployment fails and the coordinator follows
the rollback/diagnosis procedure.

## 6. Universal round workflow and agents

Every repair round is sequential in the shared marine repo:

1. **`clearskies-test-author`** starts first on the pinned base, writes a guard that fails before
   the implementation, and records the real transcript.
2. **`clearskies-api-dev`** or bounded **`worker`** implements only the named files.
3. Coordinator independently reruns targeted + adjacent tests and inspects every hunk.
4. **`clearskies-auditor`** receives the governing design and expected observations—not the
   implementer's report—and tries to disprove the repair.
5. **`clearskies-docs-author`** updates manuals/contracts/help after behavior is accepted.
6. Coordinator alone commits across repos, pushes only after the operator says **push**, and deploys
   only with `scripts/deploy-marine.sh`.

Global prohibitions for every prompt: architecture hard block, stale-test block, file allowlist,
no remote Git for agents, no container edits, and no test execution while a model run is active.

## 7. Global QC gate template

Every round must provide:

- Failing pre-change guard transcript.
- Targeted tests for changed files plus adjacent seam suite; never repo-wide pytest.
- At least one mutation drill that makes the new guard fail.
- Production-shaped geometry, mixed cycles, nonzero forcing, and non-exact-hour fixtures.
- Source-only audit against this plan, manuals, accepted ADRs, and local model manuals.
- `git diff --check`, changed-file allowlist, and doc-code sync.
- Live deploy uses the guarded script, records deployed commit/process start, and checks the journal
  for new warning/error classes.
- One full-cycle and one fast-cycle end-to-end row where relevant.
- Reality comparison quantity/tolerance chosen before reading model values.
- A rollback that restores the prior code without deleting state.

## 8. R0 — Results-free gates and recovery-controller specification — ✅ COMPLETE 2026-08-29

**Owner:** coordinator design; `clearskies-test-author`; `clearskies-auditor`
**Files:** test/gate briefs only; no production code
**Dependency:** plan acceptance

Tasks:

1. Freeze results-free gates for R1–R9 and R11–R12 before implementation output exists; freeze
   R10A benchmark limits before measurements and R10B gates only after the later operator choice.
2. Capture baseline hashes for transfer files, L2 INPUT, hotstarts, cache, state snapshot, and
   deployed marine commit.
3. Pin cold-recovery identity, one-restart-per-input-generation behavior, state transitions, and
   rollback/quarantine naming.
4. Write a refusal-action table before code: each slug maps to ordinary retry, source refresh,
   grid regeneration, one process restart, or operator intervention. Missing/short raw horizon may
   refresh; static identity mismatch may require grid reconciliation; parser bugs, disk I/O, and
   SWAN ingestion exhaustion must not blindly redownload NOAA data.
5. Specify and test the thread-to-main nonzero recovery exit channel.
6. Verify the service unit's `Restart=on-failure` behavior in a non-production harness.
7. Lock result-free resource ceilings before implementation results are visible: merge peak RSS,
   swap delta (required zero), wall time, and production-latency/convergence tolerances. Baseline
   inputs are the measured 33,688,517-byte nowcast and 433,123,444-byte horizon.
8. Implement/deploy the script-only preflight guard before any model repair: FQDN health check,
   fail-closed health-unreachable behavior, descendant-process defense, and checks before source/
   environment/unit mutation and immediately before restart.

Gate R0:

- Auditor can map every recovery transition to one source function and one test.
- Killing the harness during each state never promotes partial data.
- Repeated identical failure cannot produce a restart loop.
- No numeric recovery threshold is invented outside this plan.
- Guard check-only harness reports busy during ordinary WW3, Python staging, SWAN, and horizon
  phases without deliberately failing the serving process.

### R0 execution record

- Results-free gate locked at meta `a0484f95` after four independent Sol passes; full specification:
  `docs/planning/briefs/MARINE-RECOVERY-R0-GATES-2026-08-29.md`.
- FQDN-valid pre-implementation artifact/hash baseline:
  `scratch/marine-recovery-r0-baseline-fqdn-2026-08-29.md`. The earlier raw-IP-alias capture is
  retained but explicitly invalid. Deployed marine base remained `534bac2`.
- Guard implementation/test/doc commits span `5dbd7852` through `d5d7a2ad`, with final docs at
  `48a2d81c`. Coordinator rerun: 108 decision-table cases plus named child, no-main, HTTP/status,
  empty/malformed/duplicate-key, timeout, force, FQDN and mutation-order cases all passed.
- Live read-only evidence caught both formerly invisible classes: health idle with a live
  `ww3_shel` cgroup child returned busy/exit 2; later `run_in_progress=true` with no child returned
  busy/exit 2; a genuinely idle sample returned idle/exit 0. Independent health/systemd/cgroup
  reads matched each result. Sol adversarial re-audit passed without reading implementer tests.
- Event-driven thread-to-main feasibility harness `bd05015b`: 9/9 standard-library tests passed;
  actual asyncio cross-thread wakeup causally stopped/awaited fake servers and wind task before exit
  75, operator SIGTERM/SIGINT exited 0, generic errors stayed contained, and unchanged identity
  emitted one signal then blocked. Independent Sol re-audit passed; production integration remains
  correctly deferred to R11.
- Non-production transient systemd evidence on the idle host: packaged and loaded unit both
  `Restart=on-failure`; exit 75 produced exactly two `Started`/two exit-75 journal rows (initial plus
  one executed restart) before start-limit rejected the next request; exit 0 produced zero restarts.
  Both uniquely named transient units were removed (`LoadState=not-found`). Marine service/model
  state was untouched.
- The feature branch was pushed under the operator's testing authorization. The guard is a local
  deployment entry point, so live verification used the pushed script directly and required no
  marine-service restart.

## 9. R1 — Direct SWAN L2 boundary generation (approved D1)

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Primary files:** `services/swan_runner.py`, `services/swan_formats.py`, `services/vchain.py`,
`providers/nearshore/swan.py`; focused full/fast boundary tests

Design:

- `_write_input_files()` receives the final outer-boundary source explicitly.
- L2 emits one direct BOUNDNEST3 command after final grid geometry is known.
- L3-as-middle receives its real BOUNDNEST1 directly and still emits NESTOUT for L4.
- Remove live reads/copies of `level1/INPUT` and `B_*.txt`; do not generate fake BOUNDSPEC files.
- Legacy scaffold files remain physically untouched for rollback during the first release window.

Tasks:

1. Add explicit boundary-source/transfer parameters.
2. Remove build-then-patch boundary generation from every live outer-grid path: L2 receives direct
   BOUNDNEST3; each L3-as-middle receives direct BOUNDNEST1 while retaining NESTOUT for L4.
3. Remove `reused_l1_boundary_command_lines` from full and fast paths.
4. Remove the dead `l1_nest_source` copy, `nest_l2.dat` alias, every live scaffold reader, and
   stale BOUNDNEST1←L1 logging.
5. Simplify `ChainSpec`; retire `chain_scaffold_missing` in favor of precise transfer refusal.
6. Prove L2/L3/L4 deck bytes outside boundary lines are unchanged.

Gate R1:

- Full and fast runs build with no `level1/` directory; monkeypatched level1 reads raise if touched.
- L2 INPUT: exactly one BOUNDNEST3, zero BOUNDSPEC/BOUNDNEST1.
- L3 middle INPUT: exactly one BOUNDNEST1 and correct NESTOUT for L4.
- Missing verified transfer refuses; no fallback or fabricated boundary.
- Runtime read audit proves no L2 or L3-middle access to `level1/INPUT`/`B_*.txt`.

R1 is locally gated and may restart only behind the already-deployed R3 fail-closed guard. Until R2
is present, any incomplete/frozen boundary must refuse before hotstart or publication; removing the
scaffold alone must not open a publish path.

## 10. R2 — Streaming WW3 horizon and one canonical transfer

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Primary files:** `services/ww3_formats.py`, `services/vchain.py`, `providers/nearshore/swan.py`,
`service.py`, transfer/quick-boundary tests

Design:

- Streaming merge writes atomically to `level0/hstage_<consumer-cycle>/ww3_l2_transfer.ww3`.
- Static compatibility: header/axes, ordered name/lat/lon identity, and depth.
- Dynamic per-record wind/current metadata is excluded from identity but preserved byte-for-byte.
- Nowcast owns +0…+6; horizon owns +7…+72; exact hourly adjacency required.
- Full and fast paths consume the same verified hstage artifact. Raw seven-record archives are never
  a production fallback.
- Merger reads/writes bounded records; no full-file `read_text()/splitlines()/join()`.

Tasks:

1. Streaming preamble/record reader and atomic temp+fsync+replace writer.
2. Exact lower/upper bounds, duplicate/gap/order checks, actual-file coverage authority.
3. Concise static mismatch logs; never dump 171 complete point records.
4. Full `ChainSpec` carries hstage path.
5. Fast resolver uses the hstage for `fullRun.lastSuccessCycle` and retains the nine-hour age gate.
6. Treat a newly merged hstage file as an attempt candidate. The artifact selected for hourly use
   remains immutable until the complete downstream full run publishes successfully.
7. Full success atomically records exact selected path/hash; any SWAN/convergence/SwellTrack/cache/
   publication failure leaves the prior successful selection unchanged, including same-cycle
   forced attempts. Retention cannot prune that selected artifact.
8. Keep raw-horizon and consumer-merge state independent. `ww3Horizon` records raw +7…+96
   validity; consumer state is keyed by cycle and records +0…+72 merge validity. A consumer merge
   mismatch refuses that consumer but does not spend a horizon retry unless the raw horizon itself
   is missing/short/corrupt/stale.
9. Replace stale tests that pin raw hourly archives, short-horizon partial merge, zero dynamic
   point metadata, and inherited scaffold behavior. Named files include `test_vchain_module.py`,
   `test_transfer_merge.py`, `test_quick_update_l2_boundary_resolution.py`,
   `test_quick_update_chain_boundary_wiring.py`, `test_swan_stationary_full_nest.py`, and
   `test_hourly_fill_chain_boundary.py`.

Gate R2:

- Production-shaped changing-wind pair merges to exactly 73 records, +0…+72.
- Changed name/order/coordinate/depth, short/gapped/duplicate time, or axis mismatch refuses.
- Horizon records +73…+96 never enter the consumer artifact.
- Injected failure preserves prior verified destination and removes temp file.
- Memory gate proves bounded RSS on 33.7 MB + 433.1 MB inputs; no new swap growth.
- Full and fast staged files compare byte-identical; both PRINT files show no exhaustion warning.
- Same-cycle successful publish followed by a forced candidate and downstream failure leaves hourly
  selection on the first successful artifact.

## 11. R3 — Horizon safety behavior and cold-recovery trigger

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Approval:** D5 through operator direction; automatic restart remains disabled until R11
**Primary files:** `service.py`, `state.py`, `services/swan_runner.py`,
`providers/nearshore/swan.py`, `endpoints/health.py`, focused refusal/publication tests;
`__main__.py` only when R11 adds process exit

Design:

- Missing, short, unmergeable, or exhausted boundary refuses the new cycle.
- Preserve verified last-good; with none, return unavailable.
- Before R11, record refusal only—no recovery-intent write, process exit, or automatic restart.
- After R11, route the reason through §5's refusal-action table and cold-recovery state machine.
- `l2BoundaryExhausted=true` is a failed cycle, never a successful publish.
- Boundary exhaustion is checked inside the runner immediately after L2 convergence and before any
  L2 hotstart save. An exhausted run saves no L2/L3/L4 hotstart, parses no downstream result, and
  writes no cache/marker.

Gate R3:

- Controlled incompatible/short fixtures refuse, do not overwrite cache/marker, and create one
  refusal; recovery intent exists only in the R11-enabled harness.
- Sentinel prior hotstart remains byte-identical after exhaustion refusal.
- R11 restart/refetch/cold-run harness cannot loop on unchanged inputs.
- Health and admin surface name the recovery state without claiming fresh model data.
- Clean-install bootstrap waits/retries until a complete boundary exists.

## 12. R4 — OFS/WCOFS CURRENT restoration

R4 is three separately committed/audited/deployed functional repairs, followed by one controlled
state quarantine before R5 enables publication.

### R4a — Schema, containment, resampling, full + fast wiring

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Primary files:** `providers/ocean/ofs.py`, `services/swan_runner.py`,
`providers/nearshore/swan.py`, `services/swan_formats.py`, current/full/fast tests

- Canonical record uses `u_grid/v_grid` plus model, issue cycle, forecast hour, valid time, and
  regular-grid geometry.
- Add a SWAN-current-specific full-domain containment selector; do not change point-consumer
  `find_ofs_model()`. Center-inside/edge-outside is a refusal.
- Fetch bbox includes a two-source-cell pad; normalize descending source axes.
- Reuse the existing bilinear helper to resample native WCOFS onto every active SWAN grid; no new
  interpolation formula and no top-left slicing.
- Full and 12-hour fast paths use the same resolver and pass CURRENT explicitly.
- Preflight every active level before L2 spawn/hotstart promotion. Malformed, uncovered, empty, or
  missing deck input refuses.

Gate R4a:

- Analytic affine U/V source at 53×54 resamples exactly to production-shaped 76×84 L2 and all
  L3/L4 grids within four-decimal tolerance; pad, containment, orientation, U/V-swap, and slicing
  mutations fail.
- Every full/fast deck contains INPGRID/READINP CURRENT and a nonempty CURRENT file.
- Structural count formula: `rows = n_times × 2 × (myc+1)`, values/row=`mxc+1`.
  Current L2 full: 73×2×84=12,264 rows, 76 values/row; fast: 12×2×84=2,016 rows.
- No NaN/Infinity; three independently recomputed grid samples match text formatting.

### R4b — Same-model valid-time composition and tail policy

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`

- Enumerate overlapping cycles of WCOFS only. Prior cycles fill early valid times; newer issue
  cycle wins duplicates. Never blend values or mix provider families.
- Fetch only files intersecting the required window plus the existing match allowance; partial
  newer cycles backfill from the prior same-model cycle without creating interior gaps.
- Interior/head gaps refuse. Routine cycles retain the approved bounded final-field tail.
- Cold recovery targets zero-tail full coverage and waits/retries for the needed future 03Z issue:
  00Z may wait ~3 h, 06Z ~21 h, 12Z ~15 h, 18Z ~9 h. The exact wait is health-visible and the
  service remains unavailable/last-good; it never fabricates a tail during cold recovery.

Gate R4b:

- Injectable-clock fixtures cover all four anchors, 00Z before/after 03Z, partial newer cycle,
  duplicates, interior gap, and total candidate failure.
- Routine nominal held tails are 21/3/9/15 h for 00/06/12/18; late 00Z retry may reach zero.
- Cold recovery has 73 resolvable targets, zero head/interior/tail gap, and source provenance for
  every valid time. Twelve-hour fast fill normally has 12 current blocks and zero held tail.
- Live gate records real file Last-Modified/availability and actual selected arithmetic.

### R4c — Current health and compact provenance (D8)

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Primary files:** `state.py`, `endpoints/health.py`, `providers/nearshore/swan.py`,
`services/swan_runner.py`, health/no-publish/restart-survival tests

- Add required `inputs.currents`; set available only after every active grid preflight succeeds.
- Persist compact `currentForcing`: status, WCOFS cycles, coverage start/end, first/last field,
  native/hourly counts, held-tail hours, refusal, and update time—never arrays.
- Preserve `currentsTailHeld` for compatibility. Tail hold stays informational; explicit absence,
  malformed data, or head/interior gap floors overall health to failed and refuses publication.

Gate R4c:

- Fetch success followed by writer/preflight failure reports unavailable, never healthy.
- State survives restart with original timestamps and no arrays.
- Health tests fail if currents are removed from required inputs or marked true before preflight.
- R4c is deployed and health-verified before R5 can enable publication.

### R4d — Pre-publish SWAN hotstart quarantine (D11)

After R4c and before R5, enumerate/hash only tokened SWAN L2/L3/L4 hotstarts. Use §5.3's
transactional quarantine; do not touch WW3 restarts, forecast cache, bathymetry, or grid sizing.
The first R5 run must cold-start every active SWAN level. Rollback restores only hash-matching
files if R4/R5 code is reverted.

## 13. R5 — κ=1 exact limit and nullable representation

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`; bounded API model sync by
`clearskies-api-dev` in a separate API commit
**Approval:** D3a methodology + D3b operator approval
**Primary files:** `services/wave_groups.py`, `services/swan_runner.py`,
`enrichment/surf_scorer.py`, marine/API response models, focused KATs

Design:

- Kernel exact κ=1 result: p11=p22=1, nSet/nRep/tSet unbounded.
- Finite-wire adapter keeps finite ν/Qp/κ/Tm02/band and maps only non-finite nRep/nSet/tSet to null.
- Existing consistency fallback handles null tSet; no arbitrary epsilon/clamp.
- Catch only a typed expected numeric-domain exception per partition. Unexpected programming errors
  still abort and preserve last-good.

Gate R5:

- Independent analytic κ=1 KAT; `nextafter(1,0)` finite path; κ outside [0,1] refuses.
- JSON/cache/API contain κ=1 and null unbounded fields, never NaN/Infinity.
- Fallback score is byte-identical to existing dominance fallback.
- κ=1 L2 fixture proceeds through L3/L4, SwellTrack, 73 timestamps, cache and marker.
- Injected unexpected RuntimeError still prevents publication.

## 14. R6 — Last-good cache contract and recovery

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Primary files:** `providers/_common/cache.py`, `providers/nearshore/swan.py`, focused recovery tests

Design:

- Seven-day per-entry expiry is authoritative; outer LRU/TTL cannot evict earlier by age.
- Startup and miss-time disk recovery share one lock-protected helper.
- Replace the existing 12-hour disk-age gate with the approved seven-day retention. Eligibility is
  based on the selected accepted full-cycle identity and per-hour producer time—not file `saved_at`
  or one bundle `run_time` that a fast fill can refresh.
- Bootstrap: before R7 provenance exists, only the first R2–R5 complete full artifact whose selected
  hstage and full-success state are verified is eligible. After R7a, provenance is mandatory; a
  legacy/unknown artifact is ineligible for recovery.
- Rate-limit missing/stale/corrupt disk checks; preserve original model run time.
- No new cache file or config key.

Gate R6:

- Fake-clock guard: last-good readable after 24 h and expires at seven days.
- Outer-86400 mutation fails.
- Forced `maxsize=1000` capacity eviction recovers only an eligible disk artifact.
- Concurrent misses decode disk once; stale/malformed/incomplete artifact not served.
- Fresh `saved_at` plus old h12–h72 tail does not pass; recovery preserves each hour's producer age.
- Recovery never resets `lastRunTime` or model age.
- Native/API outputs agree on lastRunTime/dataAge and remain explicit when unavailable.
- Production-sized 116 MB cold/concurrent misses have a predeclared endpoint-latency ceiling and do
  not starve TLS/API; recovery does not overlap active WW3/SWAN work unless a lock proves safety.

Deployment note: do not deploy this repair before R2–R5 produce a verified last-good artifact; the
current disk cache contains frozen/invalid hours and must not be resurrected as trusted output.

## 15. R7 — Per-hour provenance and publication honesty

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`
**Approval:** D6/D7 through acceptance of this plan

### R7a — Internal provenance (implemented before R6 recovery)

- Add an internal sibling `forecast_provenance[valid_time]` map in the existing cache artifact:
  producer full/fast, produced-at, full-cycle, input-cycle identities, boundary coverage/end/exhaustion.
- Only a complete accepted full run writes all 73; a refused/short cycle writes none and preserves
  prior accepted metadata. Fast fill replaces exactly h0–h11; h12–h72 remains unchanged.
- Legacy entries are `unknown`, never invented, and become ineligible for R6 disk recovery.
- No public provenance field in this plan.
- API freshness remains response freshness. `lastRunTime/dataAge/modelStatus` remain model signals.

### R7b — Same-run serving identity and age honesty

**Primary files:** `providers/nearshore/swan.py`, `endpoints/surf.py`,
`services/model_wave_source.py`, cache/endpoint response tests

- Bundle `run_time`, public `lastRunTime`, and `dataAge` identify the selected complete full run.
  A fast fill never overwrites them or makes untouched h12–h72 look freshly modeled. Its h0–h11
  producer times remain visible in internal provenance and unified operator health.
- Tie each deep-water catalog to its WW3 cycle, exact transfer path/hash, and accepted full/fast
  provenance. The endpoint may combine it with a cached SWAN/SwellTrack hour only when those
  identities match.
- On mismatch, use only a matching deep-water reconstruction already stored with that accepted
  hour. If no matching source exists, serialize that hour unavailable; never mix a current WW3
  catalog with older nearshore/breaking results.

Gate R7b:

- Full run followed by a fast fill leaves bundle/public full-run time and all h12–h72 producer
  times unchanged; health reports fast replacement times for h0–h11 separately.
- Advancing the current WW3 transfer while retaining an older SWAN cache cannot change its served
  `multiSwell`, `swellHeight`, score, or breaking fields.
- Missing matching deep-water reconstruction produces the exact unavailable snapshot, not a
  cross-run hybrid.

### R7c — Near-zero publication gate

- Reuse invariant-9's existing criterion before publication. Failing hour remains in time axis with
  `modelStatus=unavailable`; use the existing unavailable serializer so no wave-derived numeric
  field, score, conditions text, `multiSwell`, or break metric survives. Timestamp and non-model
  metadata remain. No zero substitution and no timestamp deletion.
- The gate evaluates the same-run SWAN/SwellTrack result being published, not a current deep-swell
  catalog from another run; a newer WW3 transfer cannot make a stale entry pass.

Gate R7a/R7c:

- 73 full provenance entries; exactly 12 fast replacements; 61 tail entries byte-identical.
- Mutation overwriting tail provenance fails.
- Cache restore preserves provenance; legacy cache yields unknown/ineligible.
- Existing public signals remain testable: `lastRunTime`, `dataAge`, per-hour `modelStatus`, and
  HTTP 503 when no proxy fallback exists. Proxy-fallback origin is not claimed publicly.
- Near-zero 0.0 m/1.1 s hour is unavailable/null and invariant still fires; valid weak sea passes.
- Cached and on-demand paths use the identical unavailable field snapshot.
- No new public field appears in OpenAPI/response snapshots.

R7a lands before R6 enables provenance-required recovery. R7b and R7c are separate functional
deployments after R6; all three changes remain separately attributable.

## 16. R8 — Unified Model Health

**Owner:** coordinator contract → `clearskies-test-author` → `worker` (marine) →
`clearskies-api-dev` (pass-through) → dashboard/stack worker (operator UI) →
`clearskies-auditor`
**Approval:** D13 through plan acceptance; visitor forecast contracts remain unchanged
**Repositories:** marine is the canonical producer; API is an opaque authenticated pass-through;
dashboard/stack renders operator status; each reports its deployed revision where an existing
authoritative revision source is available

### R8a — Contract and reducer

Add one versioned, additive `modelHealth` ledger to the marine service's existing `/health`
response. Retain existing top-level fields during migration. The API's existing authenticated
`/setup/marine/health` route passes the ledger through without recalculating model truth. No new
visitor endpoint or visitor forecast field is authorized.

Every attempt has a stable ID, kind (`full`, `fast`, `horizon`, or `recovery`), start/end times,
deployed marine revision/package, SWAN binary hash, existing WW3 pin identity, and model/config/grid
generation. Every stage uses the same shape:

```text
state: ok | running | stale | degraded | failed | blocked | skipped | unknown
reasonCodes: stable machine-readable identifiers
observedAt + attemptId
coverage: required/actual start and end + complete boolean
provenance: compact source cycles, valid-time maps, shapes and identities
output: logical artifact name, bytes/hash when useful, published boolean
```

The report retains compact active and latest-by-kind attempt summaries and has two explicit
top-level truths:

- `overall` reduces the current surf-production/recovery generation and its required linked
  dependencies, not whichever background task finished most recently. A later successful raw
  horizon cannot overwrite a failed consumer merge or failed full/fast publication.
- `serving` identifies what callers can actually receive now: selected attempt/full-cycle identity,
  first/last valid time, original model/producer time, age, `valid|stale|unavailable`, whether it is
  last-good fallback, and the reason. A blocked new attempt may coexist with a still-valid last-good;
  the report shows both and never calls the blocked attempt successful.

Required stage ledger:

| Stage | Evidence required before `ok` |
|---|---|
| provider inputs | Required child stages for NOAA boundary, wind, STOFS water level and WCOFS currents; each child carries source cycles, requested/received valid-time coverage, selected fallback/tail, field names/shapes and fetch failure; no aggregate boolean may hide a failed child |
| WW3 production leg | grid/restart/pin/binary identities; +0…+6 coverage; wall time; artifacts; refusal |
| raw WW3 horizon | +6…+96 coverage, pin, attempt/backoff, wall time and real artifact existence |
| consumer boundary merge | nowcast+horizon identities, static point-axis compatibility, time-varying metadata handling, merge result and +0…+72 coverage |
| SWAN L2/L3/L4 | level/grid/boundary identities; WIND/WLEVEL/CURRENT coverage; convergence; output validity; topology reason when legitimately skipped |
| SwellTrack | handoff/partition/transect inputs; failures; output coverage |
| cache | memory/disk presence, true full-cycle age, restore result, per-hour coverage and fast-fill changed-hour set |
| publication | candidate versus selected run, published and model-data ranges, last-good decision, endpoint availability |
| recovery | trigger, prerequisite/source generation, attempt/result, wait versus changed state |

API transport/proxy health is separate because the marine process cannot truthfully observe its
caller. The API may add reachability, its own deployed revision, transformed response status,
fallback use, and API-observed freshness outside the unchanged `modelHealth` ledger. Those values
never participate in the marine reducer or elevate model health.

The mechanical reducer is results-free:

1. `failed`: any required stage failed, required coverage is incomplete, or a required artifact is
   missing/corrupt.
2. `blocked`: an intentional safety refusal because an approved prerequisite is not yet available.
3. `unknown`: required evidence was never observed or cannot be restored; it can never reduce to
   healthy.
4. `degraded`: a publication exists with an explicitly approved degradation such as held tail.
5. `stale`: stage data exceeded that stage's already-approved freshness policy but remains usable.
6. `running`: the active attempt has no terminal result; it never hides the prior failed/blocked
   attempt.
7. `ok`: every required stage and publication proof passed.

`skipped` is legal only with a stage-specific topology reason and is ignored by the reducer only
when that stage is not required for the configured spot. Overall health is the worst required
state. A healthy raw horizon can never mask a failed merge; a reachable API can never mask failed
model data. Each stage owns its existing freshness/coverage criterion—this round invents no new
scientific or timing threshold.

### R8b — Marine instrumentation and restart truth

**Primary files:** marine `state.py`, `endpoints/health.py`, `service.py`, `services/vchain.py`,
`services/ww3_runner.py`, `services/swan_runner.py`, `providers/nearshore/swan.py`, current-provider
path and focused tests

Tasks:

1. Define the schema, stable reason-code inventory, required/optional-stage matrix, and precedence
   table for each attempt kind before production code.
2. Instrument stage owners at the point they can prove coverage/output—not at orchestration call
   return—and link every observation to one attempt ID.
3. Extend the existing atomic marine state snapshot with only active markers and the compact
   latest-by-kind summaries required by the reducer. Store references/hashes, not forcing/model
   payloads. A new ledger file is not authorized.
4. Preserve original observation/model times on restart. Missing nonpersisted evidence restores as
   `unknown`, never inferred `ok` from a socket, file name, or old success timestamp.
5. Source deployed revision and binary identity from the existing deployment/pin workflow. If an
   additional manifest, environment field, or config key proves necessary, stop for a new trigger-7
   decision.
6. Fold R4c's `inputs.currents`/`currentForcing` evidence into this ledger while retaining its
   compatibility key during migration.

### R8c — API and operator UI; optional future monitoring

Tasks:

1. API preserves opaque pass-through semantics and adds transport/reachability context only.
2. Operator/admin UI renders an attempt header and stage matrix with state, reason, required versus
   actual coverage, source cycle, true model-data age, deployed revisions/binaries, and recovery
   state. It must visually distinguish waiting, failed, stale, and held-tail/degraded conditions.
3. Add operator help text defining each state and the immediate action; expose no raw spectra,
   filesystem secrets, or credential-bearing URLs.
4. The authenticated operator view also shows a component/surface matrix for the marine, API and
   dashboard/stack deployments: reachable/build state and immutable deployed revision from each
   component's existing authoritative source. Missing evidence is `unknown`; this plan does not
   authorize a new manifest/config key merely to make a row green. Repository/build health is
   displayed separately from scientific model health.
5. Marine, API, and admin must display the same attempt ID/state/reason. API or dashboard
   response freshness must never be presented as model health.
6. **Optional follow-on, not a plan-close gate:** CheckMK may later consume the same canonical
   report and map overall plus failed/blocked stages into one service check. Any new endpoint, port,
   dependency, config key, or direct-access exception requires its own approval. Deferring CheckMK
   does not defer or weaken the canonical health ledger.

Gate R8:

- Unit precedence matrix covers every state pair, required/optional stage, active attempt over prior
  failure, restart restore, no-evidence→unknown, and blocked-attempt plus valid/stale/unavailable
  serving-state combinations.
- Contract snapshots prove schema versioning, old-key compatibility, opaque API pass-through, and
  no visitor payload change.
- Mutations force: horizon-success/merge-failure; `u/v` versus `u_grid/v_grid`; one deleted SWAN
  level output; absent binary pin; missing provenance; corrupt cache; h0–h11-only fast fill; and
  failed publication. The exact owning stage and overall state must fail—no neighboring success may
  hide it.
- A production-sized ledger adds bounded request latency and no material service starvation.
- Authorized live gate captures one full attempt and one fast fill; raw horizon→merge→L2 coverage,
  required CURRENT, publication, revisions, and model age agree across marine health, authenticated
  API, and operator UI.
- Rollback uses normal deploy scripts, retains old health keys, and never deletes model artifacts,
  cache, or pin files.

R8 contract/reducer and marine instrumentation deploy before automatic recovery. Operator UI may
follow as a separately attributable deployment, but the plan cannot close until the required
surfaces agree and an auditor's mutations prove silent-stage failures are impossible. CheckMK is
outside the close gate unless the operator later activates the optional follow-on.

## 17. R9 — Retry reuse and deployment guard

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor`

### Same-cycle WW3 reuse (approved D10 with plan acceptance)

- Reuse only in the same process, same cycle, matching grid/binary/input fingerprint, with every
  nonzero +0…+6 artifact and restart/pin present.
- Any mismatch or process restart reruns WW3.
- Reuse does not stamp a new WW3 success time.

Tasks:

1. Define the same-process fingerprint: forecast cycle, grid derivation, WW3 binary pins, NOAA
   boundary cycle pin, +0…+6 wind source identities, and config/geometry revision.
2. Capture it only after successful `_run_ww3_leg()`.
3. Validate transfer, +6 restart, nest output, pin, nonzero sizes, and exact +0…+6 cadence.
4. Clear eligibility on any fingerprint component change; never reuse across process restart,
   newer cycle, failed leg, or forced geometry generation.
5. Never refresh WW3 success timestamps on reuse.

### Guard semantics

- `run_in_progress` covers the whole production attempt: WW3, boundary staging, SWAN, parsing,
  SwellTrack, and publication; one outer `finally` clears it.
- Deploy script treats health-unreachable + active service as unknown/busy, checks descendants for
  defense-in-depth, and keeps `--force-restart` as explicit operator override.

Gate R9:

- Two forced downstream failures invoke WW3 once; artifact hashes unchanged on retry.
- Missing/corrupt/fingerprint mismatch reruns; restart reruns conservatively.
- Deploy started in WW3/Python/SWAN/horizon phases waits and never sends SIGTERM.
- Exception injection at every production phase clears state.
- Test-only downstream refusals prove reuse; production is never deliberately failed for this gate.

## 18. R10A/R10B — Horizon worker evidence, decision, and optional implementation

**Owner:** `troubleshooter` evidence → operator decision → `worker` → test author → auditor
**Status:** R10A evidence approved; R10B blocked until D9 is explicitly decided

The 4½-hour continuation is our own WW3 computation from the production leg's +6 h restart out to
+96 h. It is 96 rather than 72 because one daily horizon must cover later consumer cycles: worst
case 24 h later + 72 h forecast = 96 h. It is not a NOAA download and not SWAN.

Alternatives to measure:

1. **Checkpointed/yielding worker (provisional preference):** 6/12/24 simulated-hour chunks,
   restart/transfer checkpoint after each, yield to production between chunks, resume later.
2. **Concurrent low-priority worker:** horizon competes with production; `nice` alone does not
   constrain memory/I/O or guarantee priority.
3. **Synchronous monolith:** current behavior; blocks/coalesces work.

Evidence gate before any choice:

- Before measurements, lock maximum production-latency increase, RSS/swap/I/O limits,
  convergence equivalence, and numerical transfer tolerance. `nice 15` is never an acceptance
  condition. These thresholds are results-free and cannot be selected after candidate results.

- Monolithic reference versus each chunk size from identical inputs; byte identity first, then
  predeclared bin/Hs/Tp/direction tolerance if segmentation is not bitwise identical.
- Chunk gap/duplicate audit, kill/resume at every boundary, checkpoint mismatch refusal, disk use,
  overhead, and worst production delay.
- Concurrency against full SWAN, production WW3, and fast SWAN: wall time, convergence, RSS, swap,
  I/O wait, provider rate limits, and event latency.
- Host resource evidence: current 5.7 GB RAM and existing swap pressure mean no concurrency approval
  based only on 32 CPUs or `nice 15`.

Checkpoint candidates, if measured, carry trigger cycle, chunk start/end, NOAA pin, grid hash,
binary hashes, restart hash, completed transfer segment, and atomic completion state. Partial or
mismatched checkpoints never resume.

After R10A evidence, the operator selects monolith, checkpointed worker, concurrency, or hybrid.
R10B implements and live-gates that explicit choice. If monolith is retained, record it as the D9
decision; it is not an untracked deferral. Any checkpoint manifest or worker placement is an
architectural/persisted-artifact decision and receives its own accepted amendment before code.

## 19. R11 — Automatic cold recovery implementation

**Owner:** `clearskies-test-author` → `worker` → `clearskies-auditor` → docs author
**Dependency:** R1–R9 locally green; WW3 cold-start benchmark complete
**Primary files:** marine `__main__.py`, `service.py`, `state.py`, `services/vchain.py`,
`services/ww3_runner.py`, `providers/nearshore/swan.py`, the existing NOAA/wind/STOFS/WCOFS
provider seams, focused recovery/restart tests; no new service or endpoint

Tasks:

1. Implement §5 atomic recovery intent and one-restart-per-input-generation circuit breaker.
2. Add explicit recovery refresh calls at the existing NOAA boundary, HRRR/GFS wind, STOFS and
   WCOFS provider seams. Bypass result caches without bypassing rate limits, retry ceilings, source
   issue-cycle rules, or static-data validation.
3. Download into the recovery-scoped generation from §5.1; validate each source's complete
   valid-time map before atomically promoting that generation for model use. A partial newer issue
   cannot overwrite or create an interior gap in the selected timeline.
4. Apply approved same-model current composition. For zero-tail cold recovery, health reports the
   awaited issue and next retry; approximate worst waits are 00Z 3 h, 06Z 21 h, 12Z 15 h and 18Z
   9 h. Waiting is `blocked`, not success or a restart loop.
5. Make all pre-existing SWAN hotstarts and WW3 restarts ineligible. The only WW3 +6 restart allowed
   is the one created by the current recovery's own six-hour production leg; it then seeds that
   recovery's +6…+96 continuation. Any different initialization need discovered by the cold-start
   KAT stops for operator review.
6. Validate complete inputs, 73-record boundary, every required SWAN level, SwellTrack, provenance,
   non-empty output and unified health before publishing and clearing intent.
7. Recovery failure remains unavailable/last-good and cannot flap systemd.

Gate R11:

- In a non-production harness, drill each trigger: missing horizon, missing current, corrupt cache,
  failed convergence, and invalid near-zero output.
- Exact κ=1 is a negative control: it completes with nullable unbounded fields, no recovery intent,
  and no restart. Only malformed/out-of-domain spectral input may refuse.
- Exactly one restart for unchanged fingerprint; new source generation allows another attempt.
- All time-varying providers show fresh, recovery-generation fetch evidence and exact valid-time
  coverage; static geometry is validated and no routine cache entry was partially overwritten.
- Cold-start output passes predeclared machine-verifiable comparison against a warm valid reference
  before becoming production-authoritative. Independent buoy/cam review occurs immediately after
  the first publish as the deployment acceptance/rollback gate.
- Host reboot/service restart mid-recovery resumes safely from intent or restarts recovery; never
  publishes partial state.
- Unified health exposes the trigger, source generation, awaited prerequisite, attempt count, every
  stage result, and last-good decision throughout the drill.

## 20. R12 — End-to-end recovery and close gate

The plan does not close on unit tests. Required live evidence:

1. One successful full cycle at each 00/06/12/18 UTC anchor.
2. One successful fast fill after a full cycle.
3. Full and fast consume the same verified 73-record +0…+72 boundary with 171 ordered points,
   35 frequencies and 72 directions; changing wind/current point metadata is preserved and no
   exhaustion warning occurs.
4. Project WW3 decks contain their required wind forcing; every active SWAN deck contains WIND,
   WLEVEL, CURRENT and valid bathymetry. For the current 76×84 L2 grid, full CURRENT has 73×168 =
   12,264 U/V rows and fast has 12×168 = 2,016 rows, each with 76 values; generalized count is
   `n_times × 2 × (myc + 1)` rows of `(mxc + 1)` values.
5. No SWAN-L1 scaffold access, κ crash, NaN/Infinity, missing CURRENT, cache premature expiry, or
   mixed-age tail mislabeling.
6. Unified health names the same attempt, deployed revisions/binaries, stage coverage and result at
   marine, authenticated API and operator UI; no pending failure or recovery intent is hidden.
7. Cache survives service restart with honest model age. Failure-retention is proven in scratch/
   staging tests or by read-only observation of a naturally occurring production refusal—never by
   deliberately corrupting the serving process.
8. Reality comparison against NDBC 46222/46253 and Surfline/webcam using quantities/tolerances
   declared before values are read. Flat far-window output is automatic failure.
9. Post-deploy journal sweep has zero unexpected ERROR/WARNING classes. Every expected class is
   predeclared with exact firing condition/count; current tail-hold is permitted only at the
   approved anchor count, and exact κ-limit handling is INFO/DEBUG rather than a generic warning.
10. Record wall time, peak RSS, swap delta, I/O wait and endpoint latency for production WW3,
    horizon, full SWAN, fast SWAN and cache restore; every value meets the R0 ceiling.
11. Restart-survival and guarded-deploy drills prove health state is not restamped and no running
    Python/WW3/SWAN/horizon descendant is interrupted.
12. Independent auditor cannot disprove completeness, timing, provenance, health, or recovery.

## 21. Deployment order

Each row is one functional deployment and one attribution gate:

1. R0 guarded deploy preflight.
2. R3 fail-closed refusal behavior; no recovery intent, exit, or restart yet.
3. R8a schema/reducer skeleton; uninstrumented evidence remains `unknown`.
4. R1 direct scaffold removal, still protected by R3.
5. R2 verified streaming boundary + full/fast shared artifact.
6. R4a CURRENT schema/containment/resampling/full+fast wiring.
7. R4b approved same-model valid-time composition and wait/tail policy.
8. R4c CURRENT provenance/health.
9. R4d transactional SWAN L2/L3/L4 hotstart quarantine; WW3 restart untouched at this stage.
10. R8b complete marine stage instrumentation and adversarial mutations.
11. R5 κ exact-limit/null handling—the first publish-enabling deployment.
12. First verified cold SWAN full publish and immediate post-publish reality/rollback gate.
13. R7a internal provenance, then one provenance-complete full cycle.
14. R6 cache liveness using that verified provenance-complete last-good.
15. R7b same-run serving identity and existing-field age honesty.
16. R7c near-zero gate.
17. R8c authenticated API pass-through and operator UI agreement; CheckMK remains optional.
18. R9 same-cycle reuse and whole-attempt deployment guard.
19. R10A evidence; R10B only after the later operator worker choice.
20. R11 automatic cold recovery.
21. R12 four-anchor close gate.

If any deploy fails its live gate, revert that deployment first and diagnose second. No later row
proceeds on an unverified predecessor.

## 22. Documentation and contracts

Update in the same repair round before deployment: marine code/changelog in its marine commit, API
model/tests in its API commit, dashboard/help in its repository commit, and ADR/manual/OpenAPI/plan
documents in coordinated meta commits:

- Provider Manual §§14.10/14.15/14.18: current composition, direct boundary, exact-limit semantics.
- Operations Manual: recovery controller, cache retention, guard, artifacts, health interpretation.
- API Manual §17–19 and OpenAPI: nullable group fields and existing model-status semantics.
- API/Operations manuals and operator help: unified health schema, reducer, reason codes, stage
  ownership, transport-versus-model freshness, and optional CheckMK status.
- ADR-101: κ=1 exact-limit/null ruling.
- ADR-109: horizon safety/shared artifact and, later, worker lifecycle.
- ADR-104 or successor: WCOFS same-model valid-time composition/tail policy.
- Marine/API changelogs and tests/comments with stale 24-hour terminology.
- Root `ARCHITECTURE.md` only if D9 eventually changes service/process placement.

No SWAN or WW3 reference-manual file is edited.

## 23. Approval boundary for operator review

The operator has supplied the recovery direction: invalid required data starts a restart/refetch/
full-cold-run path; recovery may wait for source publication limits; exact κ=1 retains finite fields
and nulls only unbounded values; and unified health must accurately portray every model stage.

Acceptance of this plan activates D6–D8 and D10–D13 exactly as scoped. It does not authorize:

- any grid, model handoff, formula, coefficient, provider family, visitor contract, port, dependency,
  endpoint, or config-key change;
- any R10B worker/process/cadence choice before R10A evidence and a later explicit operator ruling;
- any new persisted artifact beyond the accepted recovery intent and additions to the existing
  state/cache contracts;
- CheckMK integration, which is optional and separately approvable later.

No additional design question blocks plan acceptance. A failed cold-start KAT, missing authoritative
revision source, or need for a new health/recovery artifact is a stop-and-surface event, not implied
permission to expand the design.

---

## 24. Acceptance checklist

- [x] Operator accepts §23's approval boundary and this plan — 2026-08-29.
- [x] Old forward plan archived; redirect installed — 2026-08-29.
- [x] Results-free gates written and Sol-audited before implementation — 2026-08-29.
- [ ] R1–R11 individually implemented, audited, documented, and live-gated.
- [ ] R12 four-anchor/reality/health gate passes.
- [ ] No untracked deferred item remains in narrative prose.
- [ ] Coordinator walks the original operator request line by line before close.
