# Marine Recovery R0 — Results-Free Gate Definition

**Status:** LOCKED — Sol QC pass 4, 2026-08-29; changes require a fresh results-free audit
**Authority:** [`MARINE-MODEL-RECOVERY-PLAN-2026-08-29.md`](../MARINE-MODEL-RECOVERY-PLAN-2026-08-29.md)
**Purpose:** define how each recovery round will be falsified without embedding an implementer's
results, commit messages, or claimed output.

This file defines methods and predeclared limits. Evidence belongs in the active plan's round
record or `scratch/`, never backfilled into this definition. An auditor receives this file and the
governing design, but not the implementing agent's tests or closeout report.

## 1. Universal controls

Every round must satisfy all of these controls in addition to its own gate:

1. The test author records a real pre-change failing transcript, or documents why a live transcript
   is impossible and uses `git show <base>:<path>` to prove the guard was absent.
2. Tests use production-shaped nonzero data and isolate every file write under their temporary
   directory. No provider call may escape a mock.
3. One mutation disables or corrupts the intended repair and must make the guard fail.
4. The coordinator reruns the exact targeted and adjacent commands independently.
5. The auditor receives no implementer report and attempts a different mutation or trace.
6. Any unexpected warning, error, viability guard, changed file, or stale test blocks the round.
7. No model test or deployment starts while production health, the systemd cgroup, or process
   descendants show an active model phase.
8. Deployment evidence is valid only when the running marine revision and process start time both
   postdate the deployment under test.
9. Fixtures include mixed provider cycles, non-exact-hour requests, nonzero forcing, and the exact
   production grid/axis cardinalities where relevant.
10. A source-only review checks the changed seam against the accepted plan, current Provider/API/
    Operations manuals, accepted ADRs and local SWAN/WW3 manuals when model grammar is involved.
11. `git diff --check`, exhaustive changed-file allowlist, targeted plus adjacent tests, and doc-code
    sync are mandatory before commit and again before deploy.
12. Every applicable deployed functional round observes a complete full nest through convergence
    `valid_fraction`, selected-cache publication and a quantity/tolerance declared before matched
    reality is read. Fast-cycle evidence is also required when the round touches fast behavior. An
    intentionally fail-closed intermediate deployment substitutes a real end-to-end safe-refusal
    row proving no cache/marker/hotstart changed; it does not claim model success.
13. Feed-selection rounds use real provider publication-clock and `Last-Modified` evidence in
    addition to injected-clock tests.
14. Every round names a rollback to the prior local revision using the guarded deploy path. Rollback
    never deletes model state and is itself subject to the guard.
15. Dispatch follows `rules/agents.md` exactly: test author first on the pinned clean base; explicit
    exhaustive allowlist/exclusions/verification/deliverable; pre-code scope acknowledgment confirmed
    by the coordinator; verbatim Git, stale-test and architectural-change blocks; no container edits;
    no remote Git by agents; no repo-wide pytest.

## 2. R0 safety-controller specification

### 2.1 Recovery identity and exit path

- Identity is `(forecast_cycle, input_generation_fingerprint, runtime_generation)` exactly as
  defined in the active plan §5.1.
- One automatic process restart is allowed per unchanged identity. A second failure records
  `blocked` and waits for source-generation change or the existing backoff.
- The runner thread requests recovery through one named event scheduled with
  `loop.call_soon_threadsafe`. The main coroutine stops the uvicorn servers and wind task, then exits
  with code **75** (`EX_TEMPFAIL`). SIGTERM/SIGINT remain zero-exit operator stops. Generic runner
  exceptions remain contained unless converted to the named recovery request.
- A partial intent, duplicate request, or killed harness cannot promote model state or clear the
  previous last-good selection.

### 2.2 Literal refusal-code/action table

Ordinary retry may target one provider under its existing backoff. Once any row requests a recovery
restart, the restarted cold recovery reacquires **all four** required time-varying families—NOAA
boundary, HRRR/GFS wind, STOFS water level and WCOFS currents—into one isolated generation. It may
reuse valid raw-horizon retry accounting, but it never partially promotes one provider.

| Literal normalized reason code | Before recovery restart | Restart / same identity again | Must not do |
|---|---|---|---|
| `horizon_missing`, `horizon_short`, `horizon_corrupt`, `horizon_stale` | refuse; preserve last-good and raw-horizon retry accounting; request one cold recovery | refresh all four families and recompute; then block on source/backoff | publish short/frozen boundary; loop restarts |
| `wind_required_missing`, `water_level_required_missing`, `currents_required_missing` | ordinary provider retry under existing limit; if still absent, refuse and request cold recovery | refresh all four families once; then `blocked` with awaited issue/backoff visible | invent/omit/hold unapproved values; bypass rate limits |
| `cache_corrupt` | mark cache ineligible; preserve any independently verified selected artifact; request cold recovery | refresh all four families and rebuild once; then operator intervention | serve corrupt cache; restamp model time |
| `convergence_gate_failed`, `model_output_invalid` | refuse; preserve last-good; request one cold recovery | refresh all four families, quarantine approved SWAN state and run once; then operator intervention | publish partial/zero output; change physics/numerics |
| `boundary_merge_incompatible`, `l2_boundary_exhausted`, `swan_fatal`, `model_runtime_error`, `disk_io_error`, `permission_error` | refuse and surface; **no automatic recovery restart** | operator/code repair or new runtime generation schedules a normal retry | blind provider redownload; permission changes; restart loop |
| `static_input_invalid` | refuse; run only approved checksum/coverage regeneration without process restart | operator intervention if identity cannot be proven | redownload unrelated providers; resize a grid |
| exact κ=1 with valid spectral fields | normal completion, no refusal code | not applicable | recovery intent; κ clamp |

Current slugs are normalized before action by this exhaustive migration map; no unmatched slug may
request restart. Colon-suffixed WW3 program names retain the complete original code in health.

| Current literal slug/pattern | Normalized action |
|---|---|
| `hrrr_wind_failed`, `gfs_wind_failed`, `wind_series_gap`, `far_window_no_gfs_records`, `ww3_horizon_wind_short` | `wind_required_missing` |
| `tide_fetch_failed`, `wlevel_coverage_gap` | `water_level_required_missing` |
| `currents_fetch_failed` | `currents_required_missing` |
| `convergence_gate_failed` | same restart-bearing code |
| `no_usable_handoff_timesteps` | `model_output_invalid` |
| `l2_boundary_exhausted`, `boundary_coverage_gap`, `chain_transfer_missing`, `chain_l2_boundary_staging_failed`, `chain_scaffold_missing` | no restart; precise R2/R3 typed replacement must distinguish `horizon_*` from merge/ingestion failure |
| `wind_coverage_failed`, `wind_cadence_non_uniform`, `far_window_resample_failed`, `wave_setup_failed`, `swan_fatal` | `model_runtime_error`; no restart because the current slug does not prove source absence |
| `no_grid_sizing_cache`, `bathymetry_failed`, `l3_viability_failed`, `ww3_derivation_missing`, `ww3_grid_rebuild_inputs_missing`, `ww3_restart_missing`, `ww3_restart_stale`, `ww3_mod_def_missing`, `ww3_horizon_derivation_missing`, `ww3_horizon_restart_missing`, `ww3_horizon_mod_def_missing` | `static_input_invalid`; use only existing regeneration/cold-leg paths, no process restart |
| `ww3_binaries_invalid`, `ww3_step_timeout:*`, `ww3_step_failed:*`, `ww3_missing_output:*`, `ww3_work_root_failed`, `ww3_grid_rebuild_failed`, `ww3_wind_regrid_failed`, `ww3_boundary_reconstruction_failed`, `ww3_stage_inputs_failed`, `ww3_artifact_promotion_failed`, `ww3_leg_unexpected_error`, `ww3_horizon_wind_regrid_failed`, `ww3_horizon_cycle_unpinned`, `ww3_horizon_boundary_reconstruction_failed`, `ww3_horizon_stage_inputs_failed`, `ww3_horizon_work_root_failed`, `ww3_horizon_artifact_promotion_failed`, `ww3_horizon_unexpected_error` | `model_runtime_error`; no restart/redownload |
| `vchain_ledger_write_failed`, `vchain_bad_cycle_time`, `vchain_unexpected_error`, `chain_swan_refused`, `seam_specout_missing`, `seam_specout_parse_failed` | `disk_io_error` or `model_runtime_error` by typed exception; no restart/redownload |
| derived `ww3_leg_<underlying-slug>` | unwrap exactly once and apply the underlying row; never create a second action |
| legacy `ww3_boundary_failed` | no restart until its caller is migrated to a precise `horizon_*` or runtime code |
| `cache_corrupt` | same restart-bearing code; R6/R11 typed cache validator owns it |
| any unmatched slug | operator-visible `model_runtime_error`; no restart |

A malformed/partial `recovery_intent.json` is **not** a refusal. It is ignored and logged as
`recovery_intent_ignored`; normal scheduling then determines work. It never authorizes mutation.

### 2.3 Pinned recovery states and artifacts

| State | Owning seam | Allowed next states | Required guard test |
|---|---|---|---|
| `HEALTHY` | `service.py` production scheduler | `REFUSE_NEW_CYCLE`, active ordinary attempt | healthy cycle creates no intent |
| `REFUSE_NEW_CYCLE` | `providers/nearshore/swan.py` typed refusal boundary | `RECOVERY_REQUESTED`, `BLOCKED`, operator intervention | cache/marker/selected artifact unchanged |
| `RECOVERY_REQUESTED` | `state.py` intent writer + runner-thread signal | main shutdown, `BLOCKED` on duplicate identity | atomic intent; duplicate idempotent |
| main shutdown | `__main__.py` recovery-event consumer | process exit 75 | uvicorn/wind task stop; generic exception does not exit |
| `REFRESH_INPUTS` | `service.py` recovery controller + existing provider seams | `COLD_MODEL_RUN`, `BLOCKED` | all four families complete in one generation |
| `COLD_MODEL_RUN` | existing WW3/SWAN orchestration | `VALIDATE_COMPLETE_CHAIN`, `BLOCKED` | no pre-existing model state eligible |
| `VALIDATE_COMPLETE_CHAIN` | existing publication boundary | `HEALTHY`, `BLOCKED` | partial chain cannot publish or clear intent |
| `BLOCKED` | `state.py` recovery summary | same identity waits; changed source/runtime may return to `RECOVERY_REQUESTED` | second identical failure causes no process exit |

Pinned artifact names:

- Intent: `${SWAN_WORK_ROOT}/recovery_intent.json`, written temp+fsync+atomic replace.
- Quarantine directory: `${SWAN_WORK_ROOT}/recovery_quarantine/<cycle>_<runtime8>_<attempt>/`.
- Manifest: `<quarantine>/manifest.json`, containing original relative path, size and SHA-256.
- Allowlist: tokened `level2_hotstart_*.dat`, `level3_*_hotstart_*.dat`,
  `level4_*_hotstart_*.dat`, `level2/hotstart_*.dat`, `level3_*/hotstart_*.dat`, and
  `level4_*/hotstart_*.dat`, plus the same six tokened patterns beneath `stationary/`, only.
- Exclusions: un-tokened `hotstart.dat`, every WW3 restart, forecast cache, selected boundary,
  bathymetry, grid/config files and anything outside `SWAN_WORK_ROOT`.
- Rollback restores a manifest entry only when its quarantine hash matches and the original target
  is absent; it never overwrites and never deletes the quarantine automatically.

Transition traceability is pinned to exact future functions and nodes; implementation may move none
of these responsibilities without an approved plan amendment:

| Edge | Owning function | Exact test node | Expected artifact/state and kill-point result |
|---|---|---|---|
| model refusal → `REFUSE_NEW_CYCLE` | `providers/nearshore/swan.py::_run_all_spots_locked` typed refusal exit | `tests/test_recovery_controller.py::test_refusal_preserves_last_good_before_request` | no cache/marker/hotstart write; kill changes nothing |
| refusal → `RECOVERY_REQUESTED` | `service.py::_request_cold_recovery` | `tests/test_recovery_controller.py::test_runner_requests_recovery_once_per_identity` | one thread-safe event and one intent request; duplicate is idempotent |
| atomic intent write/load | `state.py::write_recovery_intent` / `state.py::load_recovery_intent` | `tests/test_recovery_state.py::test_intent_atomic_write_and_truncated_ignore` | temp never promotes; truncated intent logs `recovery_intent_ignored` and schedules normally |
| runner event → main shutdown → exit 75 | `__main__.py::_serve_all` using existing `__main__.py::_stop_everything` | `tests/test_recovery_controller.py::test_recovery_event_stops_servers_and_exits_75` | servers/wind task stop; intent remains; kill before exit leaves no model promotion |
| exit 75 → systemd restart | packaged and installed `weewx-clearskies-marine.service` contract, exercised by matching transient harness units | transient harness `r0-systemd-harness::exit_75_restarts_once` | source and loaded production unit both resolve `Restart=on-failure`; synthetic exit-75 gets one restart and exit-0 gets none |
| startup intent → `REFRESH_INPUTS` | `service.py::_consume_recovery_intent` called by `service.py::_marine_runner_loop` | `tests/test_recovery_controller.py::test_startup_consumes_valid_intent_into_refresh` | same identity/generation restored; no intent clear |
| refresh staging → `COLD_MODEL_RUN` | `service.py::_build_recovery_input_generation` | `tests/test_recovery_inputs.py::test_all_required_sources_promote_atomically` | all four source maps complete before one atomic selection; kill leaves production maps unchanged |
| cold-state quarantine → WW3/SWAN run | `providers/nearshore/swan.py::_prepare_cold_recovery_state` | `tests/test_recovery_cold_state.py::test_only_allowlisted_swan_state_becomes_ineligible` | completed manifest required; only same-recovery +6 WW3 restart eligible |
| complete run → `VALIDATE_COMPLETE_CHAIN` | `providers/nearshore/swan.py::_run_all_spots_locked` publication boundary | `tests/test_recovery_publication.py::test_partial_chain_cannot_publish_or_clear_intent` | candidate only; kill preserves last-good/intent |
| validation pass → `HEALTHY` | `state.py::clear_recovery_intent_after_publish` | `tests/test_recovery_publication.py::test_publish_then_clear_intent_order` | publish/marker fsync precedes intent clear; kill before clear safely revalidates |
| failure/duplicate → `BLOCKED` | `state.py::record_recovery_blocked` | `tests/test_recovery_state.py::test_duplicate_identity_blocks_without_exit` | reason/awaited source visible; no second exit/restart |

The R0 harness kills the controller at every transition and proves no partial promotion. The local
WSL user has no systemd bus. With the operator's 2026-08-29 testing authorization, use uniquely named
transient **non-production** units on the idle librewxr host—prefix
`clearskies-r0-restart-harness-`—with no repository/config/model-state writes. One exit-75 unit uses
`Restart=on-failure` plus `StartLimitBurst=2` and must show exactly one restart before start-limit;
an exit-0 unit shows zero restarts. Reset/remove only those exact transient units afterward.
Duplicate-identity no-flap remains a controller-harness assertion, not a deliberate production
service failure. Before that drill, compare the packaged unit and
`systemctl show weewx-clearskies-marine.service -p Restart --value`; both must resolve exactly
`on-failure`. The transient property matches that proven production contract rather than defining it.

### 2.4 Deployment-guard decision table

The script-only guard runs before source, environment/config, pin, unit, bootstrap/migration
mutation and again immediately before restart.

| Health query | Service state | Descendants | Required classification |
|---|---|---|---|
| reachable and model-busy field true | any | any | busy |
| reachable and busy fields false | active | one or more non-main cgroup processes | busy |
| reachable and busy fields false | active | none | idle |
| reachable and busy fields false | activating/reloading/deactivating/maintenance/inactive/failed/unknown | any | unknown-busy |
| unreachable, empty, or malformed | active/activating/reloading/deactivating/maintenance/unknown | any | unknown-busy |
| unreachable, empty, or malformed | inactive/failed | one or more descendants | unknown-busy |
| unreachable | inactive/failed | none | idle |
| any | any/query failure | descendant query failure | unknown-busy |
| any unlisted/inconsistent combination | any | any | unknown-busy |

`--force-restart` is the only explicit bypass. Check-only mode performs no mutation, returns **0**
for idle and **2** for busy/unknown-busy, and names the evidence used. Ordinary guarded deploy waits
at the existing 60-second cadence and ceiling. A timed-out wait exits nonzero without mutation of
the next guarded phase.

### 2.5 R0 guard tests

Using a fake `ssh` executable and temporary project root, exhaust the Cartesian matrix of health
`busy|idle|unreachable|malformed`, service
`active|activating|reloading|deactivating|maintenance|inactive|failed|unknown|query-failure`, and
descendants `none|present|query-failure` against the priority table above. Named child cases include
`ww3_shel`, SWAN and another cgroup child. Also test wait timeout, force override and check-only
no-mutation. A static ordering guard
proves every named mutation phase is preceded by the guard and restart is immediately preceded by
it. `bash -n` must pass.

The read-only live check is `scripts/deploy-marine.sh --check-guard`. Its result must agree with a
separate health query, `systemctl is-active`, main PID/control group, and cgroup process listing.
All host reachability uses SSH config host `librewxr`, whose `HostName` must resolve to
`librewxr.shaneburkhardt.com`; health is read through the remote loopback TLS endpoint. No raw IP is
used as a reachability target. The guarded R0 script revision must be deployed and independently
classified live before any R1 revision may deploy.

Before every remote command, the coordinator runs
`ssh -G -F .local/ssh/config librewxr` locally and requires the resolved `hostname` to equal
`librewxr.shaneburkhardt.com`. Missing/different output fails closed before SSH. R0 records the
2026-08-29 correction of the prior raw-IP `HostName`; evidence captured through the old alias is
invalid and must be recaptured through the corrected FQDN.

## 3. Predeclared resource and equivalence limits

Measurement protocol is fixed before repair output exists:

- File-function harnesses run three times from identical local/scratch inputs; compare medians for
  wall/I/O and the worst run for RSS/swap. Model marches use one identical-input monolithic
  reference and one candidate because each reference takes hours; neither run may overlap production.
- Isolated helper RSS is sampled from `/proc/<pid>/status` every 100 ms. Incremental RSS is
  `maximum VmRSS after function entry − VmRSS immediately after imports/before function entry` in
  the same process; `/usr/bin/time -v` is a cross-check only. Live marine-cgroup RSS is sampled
  every second by walking its cgroup directory recursively, taking
  the union of PIDs from every `cgroup.procs`, and summing `/proc/<pid>/status` `VmRSS`; the maximum
  sum is the aggregate RSS used by all ceilings.
  `memory.current` is recorded separately as total charged cgroup memory, never called RSS. Swap
  growth is the maximum sampled `memory.swap.current` minus its pre-phase value—not the end delta.
  Disk bytes come from cgroup `io.stat`; host I/O pressure is `/proc/pressure/io` total delta over
  the exact phase.
- Wall time uses monotonic elapsed seconds from immediately before process spawn through verified
  artifact close. Endpoint p95 uses 20 sequential authenticated probes during idle reference and
  20 during the measured phase; sort and select rank 19.
- Existing configured process timeouts remain absolute ceilings. A relative limit never authorizes
  exceeding one.

Frozen limits:

- R2 streaming merge, using the measured 33,688,517-byte nowcast and 433,123,444-byte horizon:
  incremental peak RSS at most **256 MiB**, swap delta exactly **0 bytes**, wall time at most
  **180 seconds**, exactly 73 independently parsed selected records, and no temp residue.
- Any R10A horizon candidate: production full/fast wall time no more than **110%** of its identical-
  input reference; peak RSS no more than the larger of **reference + 128 MiB** or **105% of
  reference**, and never above **5.0 GiB**; swap growth exactly **0 bytes**; total disk bytes and
  I/O-pressure delta no more than **110%** of reference; authenticated health probe p95 no more than the larger of **2.0 seconds** or
  **200% of idle reference**.
- Horizon segmentation must be byte-identical to the monolithic transfer and restart artifacts.
  If it is not, no candidate passes R10A; a numerical tolerance requires a separately approved
  gate amendment made before inspecting candidate values.
- R6 production-sized cache recovery: one 116 MiB cold restore and concurrent coalesced restores
  each complete within **10 seconds**; concurrent callers decode once; health/API probe p95 remains
  within the R10A endpoint limit; no cache restore overlaps active WW3/SWAN work without the
  approved lock.
- Convergence equivalence under identical inputs is exact: the same required SWAN levels must run,
  the same levels must converge, `valid_fraction` may not decrease, and every pre-existing viability
  or invariant result must match. A new warning/error or newly skipped level is failure.
- R11 cold versus warm accepted-reference comparison uses identical inputs and grid/binary pins.
  For every matched hour/spot/partition: Hs absolute difference ≤ **0.02 m** and relative difference
  ≤ **2%** when reference Hs ≥0.1 m; peak period ≤ **0.10 s**; circular mean direction ≤ **2°**;
  served face height ≤ **0.05 m** or **5%**, whichever is larger; break distance ≤ **10 m**. Missing,
  extra or reordered partitions fail regardless of tolerance.
- R12 records production WW3, monolithic horizon, full SWAN and fast SWAN separately. Each must stay
  within its configured timeout, peak cgroup RSS ≤ **5.0 GiB**, swap growth **0 bytes**, and wall/
  cgroup-I/O/host-I/O-pressure deltas ≤ **110%** of the pre-repair identical-phase reference. Health
  probe p95 remains within the endpoint limit above.

## 4. Round-specific falsification matrix

### R1 — direct L2 boundary

Delete `level1/`; make every attempted read raise. Full and fast must emit direct L2 BOUNDNEST3;
L3-middle must emit its one BOUNDNEST1 and L4 NESTOUT. Count exact commands and compare every other
deck byte. Missing verified transfer must refuse before hotstart/publication.
Runtime file-access tracing must show zero L2 or L3-middle reads of `level1/INPUT` or `B_*.txt`.

### R2 — verified streaming boundary

Merge changing-wind/current records and independently count exactly 73 hourly +0…+72 records,
171 ordered points, 35 frequencies and 72 directions. Mutate name/order/coordinate/depth, axis,
gap, duplicate and truncation one at a time. Full and fast must select the same immutable artifact;
a failed candidate cannot replace it. Assert +73…+96 never enters the consumer artifact, injected
failure removes its temp and preserves destination, full/fast staged files are byte-identical, and
both PRINT files contain no exhaustion warning. A same-cycle successful publish followed by a
failed candidate/downstream run keeps the first selection. Apply §3 memory limits.

The destination is exactly
`level0/hstage_<consumer-cycle>/ww3_l2_transfer.ww3`. Every selected dynamic wind/current point
field remains byte-for-byte from its owning source record. Consumer merge failure does not spend the
valid raw horizon's retry budget. Retention cannot prune the selected path/hash. Fast resolution uses
`fullRun.lastSuccessCycle`, the canonical hstage only, and the existing nine-hour age gate.

### R3 — fail-closed boundary

Inject missing, short, incompatible and L2-exhausted boundaries. Each must preserve cache, marker,
selected boundary and every hotstart byte. Before R11 there is no intent/exit; after R11 exactly one
intent/restart occurs per identity. Each fixture produces exactly one refusal; health and admin name
it without fresh model claims. Clean-install bootstrap waits/retries to a complete boundary.

### R4a — current schema, containment, resampling and wiring

Use an affine 53×54 source and production-shaped 76×84 L2 plus every L3/L4 grid. Independent
bilinear values must agree to four decimals. Mutate schema, orientation, center-only containment,
U/V order, padding, top-left slicing and one grid. Every full/fast deck must contain INPGRID/READINP
CURRENT and a nonempty file. Full L2 has 12,264 CURRENT rows and fast L2 has 2,016, each with 76
values; general count is `n_times × 2 × (myc + 1)`. Reject NaN/Infinity and independently recompute
three formatted samples per grid.

### R4b — current valid-time composition

Injected clocks cover every 00/06/12/18 anchor, 00Z before/after 03Z, partial newer cycle,
duplicate valid time, head/interior gap and total failure. Routine tails are exactly 21/3/9/15 hours;
cold recovery resolves 73 targets with zero tail/head/interior gap; fast resolves 12 with normally
zero tail. Every target carries source-cycle provenance. Live read-only evidence records each file's
publication/`Last-Modified` time and independently recomputes selection arithmetic.

### R4c — current health

Fetch success followed by writer/preflight failure must report unavailable. Remove currents from
required inputs and mutate health true before one grid preflight; both fail. Restart restores compact
provenance with original timestamps and no arrays. R4c must be the deployed health behavior before
R5 is allowed to publish.

### R4d — SWAN-state quarantine

Populate every allowlisted and excluded state name from §2.3. Kill between copy/hash/fsync/manifest/
ineligibility steps. Partial work cannot make originals ineligible. Manifest hashes and rollback are
verified; WW3 restart, un-tokened state, cache, bathymetry and grid files remain byte-identical.
The immediately following first R5 attempt proves every active L2/L3/L4 level cold-started and no
quarantined token was read.

### R5 — exact κ=1

An independent limit calculation checks p11=p22=1 and unbounded nRep/nSet/tSet. Wire output keeps
finite ν/Qp/κ/Tm02/band and nulls only unbounded fields. `nextafter(1,0)` remains finite; κ outside
[0,1] refuses. Exact κ=1 completes the full chain without recovery. An unexpected RuntimeError
still blocks publication. JSON/cache/API contain no NaN/Infinity; score fallback is byte-identical
to the existing dominance fallback; full fixture reaches L3/L4, SwellTrack, 73 timestamps, cache and
marker.

### R6 — last-good cache

Fake clock at 24 h, seven days minus one second, and seven days. Force age and capacity eviction,
fresh file write time with old tail, concurrent misses and malformed/incomplete disk content.
Capacity eviction is forced at the actual outer `maxsize=1000` boundary.
Only provenance-complete accepted full-cycle identity restores. Original model time survives.
Mutating the outer 86,400-second TTL must fail. Native/API `lastRunTime`, `dataAge` and unavailable
states agree. Apply §3 cache limits.

Bootstrap branch: before R7a exists, exactly one R2–R5 complete full artifact may qualify through
verified selected hstage + full-success state. After R7a, provenance is mandatory and every legacy/
unknown artifact is ineligible.

### R7 — provenance and serving honesty

A full run writes 73 identities; fast changes exactly h0–h11 and leaves 61 tail entries and public
full-run age unchanged. Advance the current WW3 catalog without the cached SWAN/SwellTrack identity:
the endpoint must use matching stored reconstruction or the established unavailable snapshot, never
a hybrid. Mutating any tail provenance fails; restart preserves valid provenance and legacy becomes
unknown/ineligible. Near-zero invalid output keeps its timestamp but removes every wave-derived
value/string; valid weak sea is the negative control. Cached and on-demand unavailable snapshots are
identical. Existing `lastRunTime`, `dataAge`, `modelStatus` and no-proxy-fallback HTTP 503 remain
testable; OpenAPI/response snapshots contain no new public field.

### R8 — unified model health

Exhaustively test every pair of states, required/optional stages, active versus latest-by-kind
attempts, restart restore and `overall` versus `serving`. Explicitly cover a blocked active attempt
with each serving state `valid`, `stale` and `unavailable`. Mutations make horizon succeed while merge
fails; remove each provider/current/SWAN/cache/publication artifact; remove the required binary pin;
remove required provenance; corrupt the cache; force stale/invalid revision/pin; and fast-fill only
h0–h11. The owning stage and overall state must fail or become unknown. Marine and authenticated API
must carry the same immutable model ledger; transport freshness cannot elevate it. Contract
snapshots prove schema version, old-key compatibility and no visitor change. Production-sized ledger
health latency meets §3 and causes no starvation. One live full and fast attempt agrees across
marine, authenticated API and operator UI for attempt ID, revisions, raw horizon→merge→L2 coverage,
CURRENT, publication and model age. Rollback retains old keys and all model artifacts.

The current-specific mutation passes provider `u/v` where the SWAN contract requires
`u_grid/v_grid`; current stage and overall must fail loudly rather than omit CURRENT.

### R9 — reuse and whole-attempt guard

Two downstream refusals in one process reuse one fingerprint-matching successful +0…+6 WW3 leg.
Mutate any artifact, pin, grid/input identity, process lifetime or cycle and require rerun. Inject an
exception at every phase and prove the outer guard clears. Run the R0 check-only matrix for ordinary
WW3, Python staging, SWAN and horizon phases. A guarded deploy waits and sends no SIGTERM in every
phase. Reuse never refreshes the WW3 success timestamp. Failure injection is test-only; production
is never deliberately failed for this gate.

Before and after the same-cycle retry, SHA-256 for the transfer, +6 restart, nest output and binary
pin file must be unchanged; WW3 invocation count remains exactly one.

### R10A/R10B — horizon lifecycle

R10A compares monolith, 6/12/24 simulated-hour checkpoints and controlled low-priority concurrency
from identical inputs under §3. Kill/resume at every checkpoint; mutate every identity/hash; check
gap/duplicate coverage and production priority. R10B has no gate until the operator selects a
lifecycle after R10A evidence.

### R11 — automatic cold recovery

**Pre-implementation dependency:** before any R11 production-code edit, run a dedicated WW3
cold-start KAT/benchmark in approved scratch from pinned inputs, grid derivation and binaries. It
must make every pre-existing project WW3 restart ineligible, run the six-hour production leg from
the existing cold-start initialization path, prove its +6 restart can seed the +6…+96 continuation,
and compare its +0…+6 transfer plus downstream accepted quantities to an identical-input warm valid
reference under §3 tolerances. It may not delete/move production state. If spin-up, coverage or
tolerance fails—or the path needs a different initializer—R11 remains blocked and the operator gets
the evidence before implementation.

In a non-production harness inject each refusal class from §2.2, kill at every state transition,
restart the harness and verify intent/state idempotence. Provider refresh remains recovery-scoped;
unchanged identity restarts once; source/runtime change permits one new attempt. Existing SWAN and
WW3 state is ineligible; only the current recovery's +6 restart may seed its continuation. Exact
κ=1 is the negative control. No partial artifact publishes.

Required drills explicitly include `cache_corrupt` and a truncated/malformed intent. Cache
corruption follows its restart-bearing row; malformed intent is ignored/logged and creates no
refusal, mutation authority or recovery loop.

The systemd harness must observe one restart after exit 75 under `Restart=on-failure`, no restart
after exit 0, and no flap after the controller suppresses the second unchanged identity.

Each cold recovery proves fresh recovery-generation identities and exact requested/received
valid-time coverage for NOAA boundary, HRRR/GFS, STOFS and WCOFS while static geometry validates.
No routine cache is partially overwritten. The cold output meets §3's warm-reference tolerances
before machine-authoritative publication; the coordinator immediately performs the predeclared
buoy/camera acceptance comparison afterward. Service/host restart during every intent state resumes
safely or restarts the recovery and never publishes partial state. Unified health is sampled at each
transition and must expose trigger, source/runtime generation, awaited issue, attempt count, stage
result, serving state and last-good decision.

### R12 — close gate

Collect one 00/06/12/18 UTC full cycle and one fast fill. Independently verify:

1. Full and fast share the 73-record +0…+72 boundary with 171 ordered points, 35 frequencies and
   72 directions; dynamic point metadata remains dynamic and no exhaustion warning occurs.
2. Project WW3 decks contain required wind forcing. Every active SWAN deck contains WIND, WLEVEL,
   CURRENT and valid bathymetry; CURRENT counts match R4a and contain no NaN/Infinity.
3. No SWAN-L1 scaffold access, κ crash, missing CURRENT, cache premature expiry, mixed-age label,
   mixed-run deep catalog, NaN/Infinity or unexpected near-zero publication survives.
4. Marine, authenticated API and operator UI agree on attempt, revisions/binaries, required stage
   coverage/result, serving model age and recovery intent. No pending failure/intent is hidden.
5. Cache restart preserves original model times. Failure retention is proven only in scratch/staging
   or by read-only observation of a natural production refusal—never induced in the serving process.
6. The predeclared NDBC/Surfline/webcam reality row passes; flat far-window output fails regardless
   of internal consistency.
7. Before deploy, list every expected warning/error class with its exact firing condition and count.
   Post-deploy journal contains those counts and zero unexpected classes. Tail-hold appears only at
   its approved anchor count; exact κ-limit handling is INFO/DEBUG, not generic warning.
8. §3 resource ceilings pass separately for production WW3, horizon, full SWAN, fast SWAN and cache
   restore.
9. Service restart and guard check-only runs preserve state timestamps and interrupt no Python/WW3/
   SWAN/horizon phase.
10. The independent auditor cannot disprove completeness, timing, provenance, health or recovery.

Before reading matched observations, the coordinator writes the chosen quantity and tolerance into
the round evidence. At minimum, offshore WW3 is compared to matched **NDBC 46222 and 46253**
Hs/Tp/direction and the served nearshore result is compared to same-time Surfline/webcam conditions.

## 5. Mandatory deployment/predecessor gates

One functional change deploys at a time. Every row requires its own live gate; a failed predecessor
blocks all later rows until reverted or repaired. The order is exact:

1. R0 guarded deploy preflight.
2. R3 fail-closed refusal only; recovery intent/exit/restart still disabled.
3. R8a schema/reducer skeleton; uninstrumented evidence is `unknown`.
4. R1 direct scaffold removal behind R3.
5. R2 verified streaming boundary/full-fast shared artifact.
6. R4a current schema/containment/resampling/full-fast wiring.
7. R4b same-model valid-time composition and wait/tail policy.
8. R4c current provenance/health.
9. R4d transactional SWAN hotstart quarantine; WW3 restart untouched.
10. R8b complete marine instrumentation and mutations.
11. R5 κ exact limit/null behavior—the first publish-enabling deployment.
12. First verified cold-SWAN full publish and immediate reality/rollback gate.
13. R7a internal provenance, followed by one provenance-complete full cycle.
14. R6 cache liveness using that accepted last-good.
15. R7b same-run identity/existing-field age semantics.
16. R7c near-zero gate.
17. R8c authenticated API/operator UI agreement; CheckMK remains optional.
18. R9 same-cycle reuse and whole-attempt guard.
19. R10A evidence; R10B only after later operator selection.
20. R11 automatic cold recovery.
21. R12 four-anchor close gate.

Each deployment record cites its predecessor's accepted commit/live evidence and the current
rollback revision. No combined deploy is allowed to satisfy two numbered rows.

## 6. Baseline capture inventory

R0 records path, size, mtime and SHA-256 where readable for:

- deployed marine commit and process start;
- selected/current raw WW3 transfer and long-horizon transfer;
- active L2 INPUT and all tokened L2/L3/L4 hotstarts;
- forecast cache and marine atomic state snapshot;
- WW3/SWAN binary pins and current systemd unit hash.
- Pre-repair phase references from immutable marine revision `534bac2`: production WW3, monolithic
  horizon, full SWAN, fast SWAN and cache restore wall/RSS/peak-swap/cgroup-I/O/host-I/O-pressure,
  plus idle and active health-probe samples under §3. A historical metric not captured with the
  required scope is `MISSING`, not estimated. Its corresponding model round cannot dispatch until
  the reference is rerun from the pinned pre-repair revision in an approved non-production scratch
  harness; later implementation results may not be inspected first.

Missing artifacts are recorded as `MISSING`; they are never created for the baseline. Large-file
hashing is read-only and must not run concurrently with a model march if it would materially contend
for disk I/O.

## 7. R0 completion proof

R0 closes only when all of these are present:

1. Artifact/identity inventory from §6 captured before Terra guard implementation dispatch; each
   phase reference is captured before its corresponding model implementation dispatch.
2. This gate file passes a fresh Sol adversarial review and status changes to `LOCKED`.
3. Guard test file fails against pre-change script, then passes the implementation; coordinator
   reruns it and a different Sol reviewer attempts a mutation without seeing implementer output.
4. Thread-to-main and the defined non-production transient-unit systemd harnesses pass the exact §2
   transitions and prove the packaged/loaded production Restart property.
5. `scripts/deploy-marine.sh --check-guard` agrees with four independent live values: health body,
   service state, main/control-group identity and descendant list.
6. The guarded script is committed, documented, deployed through its existing workflow after
   explicit deploy authorization, and proven live before any R1 deployment.
7. The active plan links the baseline/commits/evidence and marks only R0 complete. No later round is
   silently credited.
