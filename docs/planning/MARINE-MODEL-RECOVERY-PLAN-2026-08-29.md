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
| GI-1 | Blocker | WW3 reuses the automatic deep-water box but hard-codes wet south/west cells as its NOAA-fed active boundary | East-/north-facing and partial-land installations can force the wrong edges or omit wet incident boundaries |
| GI-2 | Blocker | WW3→SWAN output points are independently hard-coded south/west, discontinuously ordered, and mixed with buoy/deep-reference points | `BOUNDNEST3 ... CLOSED` receives neither a closed rectangle nor one valid open boundary curve |
| GI-3 | Critical | NOAA reconstruction can select N/E/S/W from one open-water bearing while the WW3 status map can activate only S/W | Boundary spectra and active WW3 boundary cells can contradict each other at non-Huntington installations |
| GI-4 | Blocker | Mandatory fine-fraction DEM catalog contains only Southern California CRM Vol. 6 | Atlantic/Great-Lakes installs can omit `ww3_leg` before topology is evaluated |
| GI-5 | Blocker | Setup queries OSM `natural=coastline` for every regime; current Great Lakes geometry is `natural=water` + `water=lake` multipolygons | Great Lakes occupancy/fetch geometry can be empty, incomplete or semantically wrong |
| GI-6 | Blocker | Newly wet CRM cells can insert MLLW depths into an ETOPO/LMSL bottom field without conversion | One WW3 grid mixes vertical datums and invalidates wet/depth interpretation |
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
| TS-1 | High | Non-live verification omits changing WW3 point wind and κ=1→Kimura seam | Broken production paths appear healthy |

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
| D14 WW3 automatic setup parity | **APPROVED 2026-08-30 for A1 local implementation and residual H/D ruling; A0 remains a merge/deployment gate** | O1: every wet G1 perimeter cell is active and NOAA-supplied. H1 retains the existing grids and formatted `FREE` transfer: one ordered, complete rectangular `CLOSED` L2 boundary, including land-covered portions; the mask/bathymetry still controls land. After `ww3_shel`, an ephemeral native `ww3_outp ITYPE=0` inventory captures post-land-filter registered names/effective ordinals, validates contiguous effective ordinals and an ordered/unique `L2P*` subsequence whose gaps exactly match shel land-filter evidence, then builds the final H selector in memory only; it is never persisted, published, or spectral input. D1 is a second formatted native `ww3_outp` pass selecting every ordered diagnostic from `diagnostic_output_contract` in its native source-inventory order; H remains boundary-only. The minimal durable setup-generation envelope is authorized only to group approved artifacts, atomically select one complete current generation, and retain one hash-matched predecessor. | trigger 5 approved for the H inventory and D1 second pass inline in the existing leg/horizon producer transaction, with no schedule/cadence/trigger change; narrow triggers 4/7 approved for the versioned diagnostic contract and exactly its two named persisted transfer artifacts; no dependency, config, endpoint, port, grid, format, or other artifact authority |
| D15 OSM-only horizontal occupancy and regular-depth separation | **APPROVED DIRECTION 2026-08-30; exact implementation gated in A0-G** | OSM is the sole horizontal provider; ocean uses `natural=coastline`, Great Lakes/inland water uses `natural=water` + `water=lake`; regular datum-converted bathymetry supplies every depth; `τ=water_fraction`, obstruction=`1−τ`; no GSHHG/fallback/fine-depth substitution | triggers 1/4/7 approved as scoped; no new provider |

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
- A domain/grid, O active-cell/status, or G occupancy/bathymetry source/datum/depth change invalidates
  `mod_def.ww3`, the WW3 restart, dependent transfers and SWAN state, and requires a full historical
  WW3 cold rebuild:
  acquire the complete historical boundary and forcing window, initialize without any incompatible
  WW3 restart, discard the historical march before forecast hour zero, create a new compatible
  restart, then run +0…+96. No incompatible WW3 restart or SWAN hotstart is reused. This is a
  required deployment procedure, not a separately invented numeric look-back duration.
- No quarantine or recovery action touches forecast cache, grid sizing, bathymetry, or WW3 restart
  until the corresponding task's exact allowlist and rollback are approved.

### 5.4 Clean-install/bootstrap order

With no verified last-good boundary, recovery does not wait for a prior successful SWAN publish.
Where the setup generation changed incompatibly, it first performs §5.3's mandatory historical
cold rebuild; its historical outputs are discarded before h0. Then it proceeds:

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

### 5.6 Recovery-order correction — 2026-09-01

This note corrects an unauthorized implementation that had reversed the order above. A cold or
wiped recovery must not run SWAN after only the six-hour WW3 leg and must not wait for a SWAN
publish before making the continuation. After the leg, it builds the same-cycle +6 through +96
hour continuation from that leg's +6-hour restart, validates the complete +0 through +72 hour
boundary, and only then starts SWAN. A missing, short, corrupt, or wrong-cycle continuation
refuses the new cycle before SWAN; it preserves any verified last-good output and waits for usable
source data. It never substitutes the six-hour boundary as a production fallback.

This correction restores §§5.3–5.4. It does not close A0, A0-I, R1, R2, R11, or any required
historical-cold-run, native-binary, compatibility, retention, or live acceptance gate.

### 5.7 As-built restart/resume and cleanup

The completed recovery implementation resumes only owner-verified stages whose
checkpoint still names the current cycle and carries SHA-256 hashes of the
retained outputs. The atomic state snapshot restores
checkpoints for the WW3 leg, WW3 horizon, SWAN L2/L3/L4, SwellTrack, cache, and
publication. In the full production recovery path, the runner reuses a
completed WW3 leg and horizon after restart or downstream failure while their
checkpoints and retained files still match. For a same-cycle retry, only a
missing or corrupt output proof causes that stage to rebuild; a new cycle
starts a new stage attempt. Fresh provider timestamps or runtime identity
alone do not invalidate a verified output. The full SWAN L2/L3/L4 runner uses the same
callback rule, so a verified level remains available while only that level's
missing or corrupt output causes it to run again. The final
SwellTrack/cache/publication tail resumes only when the restored forecast-cache
artifact and all three output checkpoints match; otherwise the service
re-enters that tail from SwellTrack. The merged `ww3_l2_transfer.ww3` boundary
is retained as the selected artifact and reused while its recorded file hash
still matches; a downstream refusal does not delete or replace it.

For a selected retained WW3 leg/horizon recovery, the downstream SWAN run
never reads the mutable routine wind timeline. It makes one exact-cycle HRRR
and GFS fetch for the selected cycle, stores only that result atomically as
`recovery_wind_timeline.json` under the existing SWAN work root, strictly
rereads it, and then continues the merge/SWAN tail. The artifact contains
HRRR f00–f48 at hourly valid times and GFS f048–f072 at three-hour valid
times, all from the selected source cycle; malformed, missing, duplicate,
extra, wrong-cycle, invalid-geometry, or non-finite U/V fields refuse the
tail. It neither reads nor modifies the normal `wind_timeline.json`, so a
new routine poll cannot mix current wind into the retained WW3 recovery.

The same artifact also carries the recovery's STOFS WLEVEL and WCOFS CURRENT
records plus their exact issue-cycle identities. STOFS is fetched once from
the selected cycle through selected-cycle +72 h, with every hourly field
required. WCOFS is fetched once from its native daily 03Z issue selected by
the recovery anchor (for a 12Z selected cycle, that day's 03Z issue), with
every native f003…f072 three-hour field required; its existing final-field
tail hold remains explicit through the selected SWAN window end. No fresh
current-time provider selector, fallback cycle, or mixed issue cycle may
supply selected recovery forcing.

Private work is cleaned by ownership boundary. `WW3Runner.run_leg_cycle()`
keeps its destination untouched until the complete WW3/H/D transaction
succeeds, and removes its per-cycle staging tree on success or any refusal.
For SWAN, unproved private input/forcing/intermediate files are removed before
rewriting a non-verified level. A failed level's diagnostic work is retained
for diagnosis, while its recovery checkpoint is invalidated and can never
authorize reuse. No cleanup path deletes the durable forecast cache, grid
sizing, bathymetry, or WW3 restart outside its explicitly owned state
(`state.py`, `service.py`, `services/ww3_runner.py`, `services/swan_runner.py`,
and `providers/nearshore/swan.py`).

The restart sequence remains ordered: WW3 six-hour leg, +6…+96 horizon,
verified +0…+72 boundary merge, forcing acquisition/preflight, SWAN L2–L4,
SwellTrack, cache persistence, and publication. The WW3 manual's Type 4
restart-file contract (`docs/reference/ww3-user-manual-v6.07.txt`, §3.4,
around line 19098) and the SWAN manual's `BOUNDNEST3` requirements (formatted
WW3 output points in boundary order and the 0.1 corridor;
`docs/reference/swan-user-manual.txt`, pp. 54–55) remain the governing input
gates. SWAN `INITIAL HOTSTART` is only a verified initialization input; a
failed or poisoned hotstart is not restored or reused.

## 6. Universal round workflow and agents

Every repair phase is completed as one coding wave in the shared marine repo. The phase does not
enter quality control between coding slices.

1. **`expert_coder`** reads the binding plan/manual material, divides only explicit implementation
   work into non-overlapping slices, and integrates cross-service decisions. It delegates bounded
   code-only slices to Spark **`worker`** agents. A Spark worker never resolves a design conflict,
   selects an interface, or integrates a phase.
2. The coding wave continues until every approved code task for that phase is implemented. A source
   finding becomes a named coding correction only when it restores the plan's stated behavior; it
   is not an invitation to investigate, redesign, or begin another phase.
3. **`documentation_author`** updates the applicable governing documents from the implemented,
   approved behavior during the coding wave. Every claim is checked against the landed source. A
   documented `N/A` needs the source evidence required by §7.
4. The coordinator freezes the phase's coding scope, inspects every changed hunk, and records the
   exact next state in the §24 execution ledger. Only then may the phase enter quality control.
5. After code and documentation are complete, **`reviewer`** audits the plan, project directive,
   engineering practice, security practice, and governing documentation. **`test_engineer`** obtains
   functional evidence only on the designated live host using real available input and real output.
6. The coordinator alone commits across repos, pushes only after the operator says **push**, and
   deploys only with `scripts/deploy-marine.sh`. A busy deployment guard pauses only deployment or
   restart; it never pauses unblocked coding or documentation.

No WSL, local-workstation, mock, synthetic, fixture-only, simulated, or pre-change test is valid
for this plan. Tests and audits never choose the design or start a coding phase. Global prohibitions
for every prompt remain: architectural hard block, file allowlist, no remote Git for supporting
agents, no container source edits, and no deployment/restart by supporting agents.

### 6.1 Execution ledger and journal

Each active repair has one row in §24 with these states, in order:

`Code complete` → `Documentation complete` → `QC complete` → `Deployed` → `Live evidence complete`
→ `Closed`.

Only one phase coding wave may be `In progress` at a time. Its `expert_coder` may run several
non-overlapping Spark worker slices in parallel when their file ownership is disjoint. A non-blocking
concern is appended to the plan journal with its phase, observed fact, impact, and next coding item;
coding continues. A blocking architectural or external prerequisite is raised to the operator
immediately and stops only the affected item. A review finding returns to a named coding correction,
then repeats the post-code quality-control sequence; it never opens an unbounded analysis loop.

## 7. Global QC gate template

Every completed coding phase must provide:

- A plan-to-code trace showing each approved task and its implemented source location.
- A document-impact declaration naming the exact affected root architecture/manual sections, operator
  help, contracts/OpenAPI, ADRs/Evolution Plan, changelog, and licensing/third-party notice; every
  named authority is updated in the same functional change or marked `N/A` with a source citation
  showing why it cannot describe the repair.
- A post-code independent `reviewer` audit answering: does the code follow this plan; advance the
  project directive; meet engineering and security practices; and agree with the manuals and
  documentation? A stale, omitted, or contradicted document fails the phase.
- `git diff --check`, changed-file allowlist, and doc-code sync.
- **WW3/SWAN manual evidence where applicable:** the coding brief and independent reviewer cite the exact local-manual clauses for every changed native command, deck, boundary/transfer, output-point list, or hotstart. Before accepting a live row, preserve the generated deck/input and the relevant native output/log lines, compare them to those clauses, and record the result. A solver exit alone is not manual compliance; provider/cache/recovery behavior remains separately verified by its own gate.
- Guarded deployment records the deployed commit/process start and checks the journal for new
  warning/error classes. The `test_engineer` then records real host, real input, real output, and
  the observed result for every applicable live condition.
- One real full cycle and one real fast cycle end-to-end row where relevant.
- Reality comparison quantity/tolerance chosen before reading model values.
- A rollback that restores the prior code without deleting state.

Historical local checks, control cases, simulations, and prior audit claims are not acceptance evidence
under this workflow. They may remain as dated history, but cannot close a current or future gate.

## 8. R0 — Results-free gates and recovery-controller specification — ✅ COMPLETE 2026-08-29

**Owner:** coordinator design; `reviewer` if this completed specification is reopened
**Files:** evidence/gate briefs only; no production code
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
5. Specify the thread-to-main nonzero recovery exit channel and require later live evidence.
6. Verify the service unit's `Restart=on-failure` behavior in a non-production harness.
7. Lock result-free resource ceilings before implementation results are visible: merge peak RSS,
   swap delta (required zero), wall time, and production-latency/convergence tolerances. Baseline
   inputs are the measured 33,688,517-byte nowcast and 433,123,444-byte horizon.
8. Implement/deploy the script-only preflight guard before any model repair: FQDN health check,
   fail-closed health-unreachable behavior, descendant-process defense, and checks before source/
   environment/unit mutation and immediately before restart.

Gate R0:

- Reviewer can map every recovery transition to one source function and one live-evidence condition.
- Killing the harness during each state never promotes partial data.
- Repeated identical failure cannot produce a restart loop.
- No numeric recovery threshold is invented outside this plan.
- Guard check-only harness reports busy during ordinary WW3, Python staging, SWAN, and horizon
  phases without deliberately failing the serving process.

### R0 execution record

- Results-free gate locked at meta `a0484f95` after four independent specialist reviews; full specification:
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
  reads matched each result. Independent adversarial re-audit passed without reading implementer checks.
- Event-driven thread-to-main feasibility harness `bd05015b`: 9/9 standard-library tests passed;
  actual asyncio cross-thread wakeup causally stopped/awaited fake servers and wind task before exit
  75, operator SIGTERM/SIGINT exited 0, generic errors stayed contained, and unchanged identity
  emitted one signal then blocked. Independent re-audit passed; production integration remains
  correctly deferred to R11.
- Non-production transient systemd evidence on the idle host: packaged and loaded unit both
  `Restart=on-failure`; exit 75 produced exactly two `Started`/two exit-75 journal rows (initial plus
  one executed restart) before start-limit rejected the next request; exit 0 produced zero restarts.
  Both uniquely named transient units were removed (`LoadState=not-found`). Marine service/model
  state was untouched.
- The feature branch was pushed under the operator's testing authorization. The guard is a local
  deployment entry point, so live verification used the pushed script directly and required no
  marine-service restart.

## 8A. APPROVED AMENDMENT A — WW3 automatic setup parity

**Status:** Operator approved A1 implementation in chat 2026-08-30. A0/A0-I remain mandatory
post-code merge/deployment gates and may reject a candidate that diverges from this approved design.
They do not interrupt the approved A1/R1/R2 coding wave. Production remains fail-closed. No A1
merge or deployment occurs until the global live-source/native-binary, atomic-rollback and
historical-cold-run gates pass.
**Effect on queue:** R1 and R2 remain blocked from merge/deployment until A1 is accepted. The locally
green R1 scaffold-removal branch is neither merged nor deployed. R3 remains the production exhaustion
guard; it does not validate topology.
**Owner sequence for A0/A0-I:** `troubleshooter` real-source/manual inventory → `reviewer`
independent evidence audit → coordinator evidence review. **A1/R1/R2 coding wave:** `expert_coder`
→ bounded Spark `worker` slices → `documentation_author` → post-code `reviewer`/`test_engineer` →
coordinator guarded deployment and live gate.

### 8A.1 Why this amendment exists

The local WW3 process replaced SWAN L1's computation but did not inherit its complete automatic
installation setup. The former setup still computes, at configuration time:

- the study-area centroid and water-body regime;
- OpenStreetMap coastline geometry;
- a 72-ray, 5-degree fan classifying `directly_open`, `wrap_candidate`, and `truly_blocked` water;
- open-water bearing, fetch and exposure;
- shelf/lake deep-water distance, island/headland enclosure and near-lee limits;
- the regional `deep_water` box, L2 geometry and regional bathymetry.

The later WW3-specific S8.1 path added fine-DEM partial-cell open-water fractions; that mechanism is
not former SWAN setup machinery and its current source coverage is Southern-California-specific.

WW3 correctly reuses the resulting `deep_water` extent and resolution. It then discards the
installation-derived boundary evidence at both interfaces:

1. NOAA reconstruction may select any two cardinal sides from the open-water bearing, while the
   WW3 grid status map can activate only wet south-row/west-column cells.
2. WW3 output for SWAN L2 is independently fixed to the entire south row followed by the west
   column, regardless of installation, wetness or ray fan.
3. That list is discontinuous and is followed by buoy and deep-reference points, yet SWAN receives
   it as one `BOUNDNEST3 ... CLOSED` boundary.

This is a true integration failure. It makes Myrtle Beach and any east-/north-facing, island,
partially-land or three-wet-side installation unsafe. It also exposes a conflict between accepted
authorities: ADR-100's 2026-08-17 amendment requires the setup geography subsystem to derive WW3
extent and boundary placement, while ADR-109 D13 freezes S/W-only status/placement. Neither side is
silently discarded. The A1 documentation round must explicitly amend ADR-109 and reconcile every
dependent manual/plan statement.

A separate global-coverage failure also blocks implementation evidence: the mandatory fine-fraction
DEM catalog currently contains only Southern California CRM Vol. 6 coverage. Outside that footprint,
including Myrtle Beach and the Great Lakes, the sizing chain can omit the entire `ww3_leg` derivation
before boundary topology is evaluated. A0 must resolve the wetness-source/datum policy or surface the
required provider/source approval; synthetic cardinal rotation alone is not a global proof.

### 8A.2 Manual requirements and project choices

The following are manual requirements, not selectable project preferences:

- A SWAN water boundary with no imposed wave conditions assumes no waves enter; the resulting
  error propagates into the domain. Land absorbs incoming wave energy.
- `BOUNDNEST3` locations are WW3 computational/output locations along the SWAN nest boundary,
  include the nest corners, are serialized in one clockwise or counter-clockwise boundary sequence,
  and satisfy SWAN's consecutive-point geometric acceptance rule.
- The WW3 nest/`BOUNDNEST3` transfer curve may cover land and need not be closed.
- `CLOSED` describes a closed rectangular transfer curve; `OPEN` describes one unclosed curve.
  Neither keyword is an accuracy mode.

The operator selected O1 (every wet G1 perimeter cell active and NOAA-supplied), H1 (one complete
ordered rectangular `CLOSED` L2 boundary, including land-covered locations where the manual permits),
and the D invariant that boundary and diagnostics remain separate. The existing bathymetry/mask still
controls land. The residual H/D ruling is approved: H keeps the complete rectangular `CLOSED`
topology, existing grids and formatted `FREE` transfer. Immediately after `ww3_shel`, a native
ephemeral `ww3_outp ITYPE=0` inventory records post-land-filter names/effective ordinals and
validates contiguous effective native ordinals plus an ordered, unique `L2P*` subsequence; every
name gap must exactly match shel land-filter evidence. It is consumed in memory solely to build the
final H selector, never persisted, published or spectral input, and remains inside the locked resource
ceiling. D1 is a separate formatted native `ww3_outp` pass selecting every ordered diagnostic in the
versioned `diagnostic_output_contract`'s native source-inventory order; it writes only the approved
cycle/horizon diagnostic transfers. No binary format change, custom spectral-transfer rewriter, scientific reachability
criterion, grid change, dependency, config key, endpoint or port is authorized.

### 8A.3 Target invariants

Any approved design must satisfy all of these:

1. **One automatic setup authority.** The configuration-time geography/bathymetry pipeline derives
   both NOAA→WW3 and WW3→SWAN boundaries. Forecast cycles consume the frozen derivation; they do
   not re-derive geography at runtime.
2. **Global and rotationally symmetric.** No side name is privileged. Equivalent real-source coast
   geometries rotated by 90 degrees rotate the derived result by 90 degrees.
3. **Cell/segment wetness, never whole-side folklore.** Every perimeter cell is classified from
   the installation's bathymetry/fraction mask. A partially-land side remains partially
   represented; one land cell cannot exclude the rest of that side.
4. **The ray fan aids setup, not wave-energy calculation.** It places/encloses the domain and may
   identify candidate incident segments. SWAN/WW3 compute energy. No unapproved exposure or
   attenuation formula may be invented in setup code.
5. **One authority, two seam-specific derivations.** NOAA→G1 active cells/source mapping and
   G1→L2 SWAN transfer topology consume the same frozen installation evidence but remain distinct
   contracts. NOAA reconstruction cannot contradict the G1 status map; the L2 curve cannot come
   from a second fixed-cardinal list. Their cells/topologies need not be identical.
6. **Boundary-only canonical transfer.** `ww3_l2_transfer.ww3` contains only ordered L2-boundary
   output points, including its native `L2P####` seam locations. Vchain seam continuity reads those
   boundary points as an H concern. Buoy and `DREF*` diagnostics use the separate D output and never
   participate in SWAN boundary interpolation.
7. **Topology is explicit and verified.** The derivation records ordered point identity and actual
   topology. The emitted `OPEN`/`CLOSED` keyword must match the serialized curve exactly; no jumps,
   duplicates, hidden last→first segment or off-boundary point is legal.
8. **Full, fast and horizon share one topology.** The six-hour leg and continuation use the same
   point axis/fingerprint. Full and fast consume the same accepted +0…+72 canonical transfer.
9. **Compatibility is evidence-derived.** A0 produces an artifact dependency table separately for
   outer active-cell, inner transfer-curve and diagnostic-only changes. A1 refuses every artifact
   the selected table proves incompatible; it does not predeclare that every topology-only change
   invalidates `mod_def.ww3` or a restart. Partial regeneration can never publish.
10. **No new operator setup burden.** An operator still defines surf locations/areas. There is no
    Huntington-specific side setting and no product-facing model-setup knob.
11. **Global source coverage is real, not synthetic.** Every supported region reaches setup with an
    approved bathymetry/wetness source and datum. Cardinal-neutral code that cannot build an
    Atlantic or Great Lakes derivation is not global.
12. **R3 is exhaustion-only protection.** It blocks missing/short/unmergeable/exhausted transfers;
    it does not detect a mixed/discontinuous `CLOSED` list or a NOAA-source/status-cell mismatch.
    GI-1/GI-2 remain unsafe until A1 adds their own structural refusal.

### 8A.4 Results-free topology evidence round — A0

**Owner:** `troubleshooter` (read-only real-source/manual inventory) → `reviewer` (independent
evidence audit) → coordinator evidence review
**Environment:** read-only evidence is gathered on librewxr from installed native binaries, real
available sources, and real generated output. No WSL, local scratch, simulated input, or production
model mutation is permitted.

Before inspecting candidate results, lock:

- exact global live-source cases and expected rotation/metamorphic relationships;
- accepted SWAN boundary-read/interpolation warning classes (normally zero);
- point-position/order/spacing checks from the local manual;
- byte/energy identities outside topology changes;
- wall-clock/RSS/disk ceilings for any extra native WW3 post-processing;
- predeclared boundary and independent validation quantities/tolerances.

Prototype two independent boundary axes; never transfer one seam's grammar to the other:

**Outer axis O — NOAA→project-WW3 G1 active boundary.** Compare at least:

- **O1:** every wet G1 perimeter cell active, with NOAA spectra mapped/interpolated per WW3's
  supported boundary mechanism;
- **O2:** installation/ray-derived wet active segments, with a predeclared proof for every omitted
  wet cell and no whole-side land inference;
- **O3 negative control:** the legacy two-sides-nearest-one-mean-bearing/fixed-S/W combination.

This axis decides status-2 cells, source-file coverage and interpolation. `OPEN`/`CLOSED` is not an
O-axis concept.

**Handoff axis H — project WW3 G1→SWAN L2.** Compare at least:

- **H1:** one ordered full rectangular `CLOSED` transfer curve, including land-covered portions as
  permitted by the SWAN manual;
- **H2:** one installation-derived continuous `OPEN` curve, with a predeclared proof for every
  omitted wet L2 boundary and the manual's lateral-boundary error geometry;
- **H3:** a topology-dependent policy only if actual SWAN 41.51AB evidence defines unambiguous
  selection rules for partial land and disconnected wet segments.

This axis decides ordered WW3 output locations and the SWAN keyword. It does not decide G1 status-2
cells. Evaluate O/H pairs that are physically and mechanically compatible; do not imply that one O
candidate forces the same-numbered H candidate.

**Diagnostic axis D — boundary versus validation output.** Compare native WW3 mechanisms that keep
buoy and `DREF*` spectra out of the SWAN curve while preserving their actual-coordinate time
series. Native `L2P####` seam continuity remains H/vchain-owned in the boundary transfer. The
approved ruling selects D1's second formatted native pass; A0 still verifies its locked native method
and compatibility evidence. A new/changed consumer contract is trigger
4. A dependency, port, endpoint, config key or persisted file is trigger 7; a temporary filename or
source-code file is not trigger 7 merely because it exists.

**Global-source axis G — operator-selected OSM policy, evidence still required.** OSM/Overpass is
the sole horizontal occupancy provider; no GSHHG or source fallback is evaluated for implementation.
The query layer follows OSM semantics, not a one-size-fits-all tag:

- ocean/coastal regimes use directed `natural=coastline` ways at OSM's mean-high-water shoreline;
- Great Lakes and other supported inland-water regimes use complete `natural=water` + `water=lake`
  multipolygons, including outer/inner rings and islands; the model regime remains Great Lakes—OSM
  tagging does not reclassify its physics;
- regular installation-selected bathymetry, converted to the model datum, supplies every depth;
  OSM supplies no elevation and never overrides a depth;
- partial-cell transparency is `τ = water_area / cell_area`, and the obstruction file stores
  `1−τ`; this is an occupancy rule, not diffraction;
- missing, malformed, incomplete, stale/unhashable or bbox-clipped geometry refuses setup. There is
  no fallback provider or fallback OSM layer.

A0 validates the regime-specific query, polygon/ring completeness, local fraction method, snapshot
hash/provenance, longitude handling and performance for Pacific, Atlantic, Gulf, Great Lakes,
islands and high latitudes. The current SoCal CRM/fine-depth path and Great-Lakes coastline query are
negative controls. If D15 cannot pass, A0 returns to the operator; it does not pick another source.

The A0 report must establish, without pre-answering:

- whether WW3 explicit point-index selection preserves request order or source order;
- whether all proposed `BOUNDNEST3` locations satisfy the manual's WW3 computational/output-location
  requirement at the actual G1/L2 resolutions;
- whether the approved separate H and D1 native `ww3_outp` passes preserve their boundary-only and
  diagnostic-only contracts;
- whether D1's two exactly approved persisted paths preserve the required setup/generation identity
  without a third artifact;
- how land-separated wet segments can be represented by the actual SWAN 41.51AB binary;
- preserved diagnostic spectra/time coverage, energy equivalence, retention, fingerprints and
  consumer wiring for `model_wave_source` and vchain;
- a dependency table for outer-active-cell-only, L2-curve-only, diagnostic-only, domain/grid,
  bathymetry-source and binary/config changes, naming each affected `mod_def`, restart, raw horizon,
  merged transfer, SWAN state, cache selection and marker;
- a measured warm/cold/bootstrap method for every candidate that needs incompatible WW3
  initialization; the method may not be invented by dropping a restart;
- atomic generation promotion and rollback: what old generation is retained, hash-matched and
  restored together, and when service must remain unavailable instead.

Required live-source cases include Pacific, Atlantic, north-/south-facing coasts, a real Myrtle
Beach partial-land case with three wet incident sides, islands/headlands/coves, disconnected wet
segments, and a **real source-backed Great Lakes setup/binary case**. O3 is evaluated only from
observed real output; no simulated cardinal-rotation or injected-failure control is acceptance
evidence.

**A0 terminal gate:** A0 supplies merge/deployment evidence for the approved A1 contracts after the
approved coding wave is complete. It may reject an implementation candidate that diverges from the
approved H inventory or D1 native-output mechanism, but it does not authorize redesign. Before
merge/deployment, H-only/D-only
compatibility must be evidenced against the approved mechanism. D15 remains fixed pending its global
implementation evidence; a failed G gate refuses setup rather than selecting another provider.

### 8A.5 Implementation design — A1 (implementation approved)

**Owner:** `expert_coder` → bounded Spark `worker` slices → `documentation_author` → post-code
`reviewer` and `test_engineer`
**Likely primary files:** `services/geography.py` (authority; change only if evidence requires),
`services/swan_domain.py`, `services/grid_sizing_chain.py`, `services/boundary_reconstruction.py`,
`service.py`, `services/ww3_formats.py`, `services/ww3_runner.py`, and the required live state/health
evidence paths.
A1 does not wire live SWAN decks, scaffold removal, 73-record merge/selection, or full/fast/vchain
consumption; those remain R1 and R2 ownership.

Approved design and tasks:

1. Define one immutable setup derivation containing shared domain/grid/bathymetry provenance plus
   separate versioned contracts for NOAA→G1 active-cell/source mapping, G1→L2 ordered SWAN curve,
   and diagnostic point output.
2. Prefer extending the existing `ww3_leg` block and grid-derivation fingerprint. Trigger 7 is
   authorized only for the minimal durable setup-generation envelope needed to group approved
   artifacts, atomically select one complete current generation, and retain one hash-matched
   predecessor. A0-I must name the exact path, files and schema before durable implementation. Any
   other dependency, port, endpoint, config key, persisted file, or consumer-contract change remains
   prohibited or separately gated.
3. Make NOAA boundary reconstruction and the WW3 status map consume O1: every wet G1 perimeter cell
   is active and NOAA-supplied. Prove every active cell is supplied and every supplied boundary file
   maps to the selected active set.
4. Make WW3 grid status and boundary assembly refuse any cell/file mismatch.
5. Serialize H1's one ordered, complete rectangular `CLOSED` L2 topology, including its
   required corners and permitted land-covered portions. Retain existing grids and formatted `FREE`
   transfer. Immediately after `ww3_shel`, run an ephemeral native `ww3_outp ITYPE=0` inventory;
   capture actual post-land-filter registered names/effective ordinals; refuse unless effective native
   ordinals are contiguous and the `L2P*` subsequence is ordered/unique, with each skipped name
   exactly matching shel land-filter evidence. Consume it in memory solely to build selectors; never
   persist, publish or use it as spectral input. Construct the coarse-to-fine H curve by max-overlap
   parent mapping, collapse consecutive same-parent runs, preserve corners and land transitions, and
   prove actual F7.2 uniqueness plus the 0.1 corridor for every wet SWAN perimeter node. Keep
   bathymetry/mask control of land. A1 records producer topology/selector output for the later
   live-host gate, but R1 alone wires the live `BOUNDNEST3` deck and boundary transfer file.
6. Keep buoy/`DREF*` diagnostics separate from the boundary transfer. D1 is a second formatted native
   `ww3_outp` pass selecting every ordered diagnostic from the versioned
   `diagnostic_output_contract` in native source-inventory order, with atomic pre-promotion and
   setup/generation identity. It persists exactly
   `level0/cycle_<token>/ww3_outp/ww3_diagnostic_transfer.ww3` and
   `level0/horizon_<token>/ww3_horizon_diagnostic_transfer.ww3`. `model_wave_source` reads D;
   vchain uses D for buoy validation and H for the `L2P####` seam. Missing/mismatched D or H fails
   closed with structural validation/refusal/logs; R8b alone owns canonical `modelHealth`.
   Preserve buoy/`DREF*` valid-time coverage, fingerprinting and spectra at actual coordinates.
   Promotion remains blocked until A0-I names and the operator approves exact cycle-directory
   retention; current approval covers the two files, not their deletion policy. Historical 2×4
   control-case results are not acceptance evidence. The live native gate uses real production-axis
   input and output, not a binary alternative or simulated control.
7. Build the authorized minimal durable setup-generation envelope and promote or roll it back
   atomically as one complete, hash-matched current generation plus one hash-matched predecessor. A0-I
   must first identify its exact path/files/schema. No mixed/partial generation may publish.
8. Invalidate `mod_def.ww3`, the WW3 restart, dependent transfers and SWAN state on every domain/grid,
   O active-cell/status, or G occupancy/bathymetry source/datum/depth change, then perform the
   historical cold rebuild. H-only and D-only preservation remain A0-I native-compatibility candidates;
   until decided, they fail closed. Do not infer preservation or invalidation from topology alone.
9. A1 owns producer derivation, the ephemeral H inventory/final selector, and separate H/D artifacts
   and identities only. R1 owns live `BOUNDNEST3` deck wiring and scaffold removal; R2 owns the
   73-record merge/selection and full/fast/vchain consumption.
10. Preserve R3 exhaustion behavior and add A1-owned structural refusals; no cache, marker or
    persistent SWAN hotstart advances on any derivation/transfer mismatch.
11. Implement D15 exactly: regime-correct OSM queries/fractions only, regular datum-converted
    bathymetry for every depth, no fine-depth substitution or fallback provider, and structural
    refusal on incomplete geometry. No SoCal-only source or universal coastline tag may masquerade
    as a global setup path.
12. Before merge/deployment, update Root Architecture, ADR-100, explicitly amend ADR-109, reconcile the
    Evolution Plan conflict, and update Provider/Operations Manuals, config/operator help,
    changelog, ODbL/third-party notice and this plan. The frozen SWAN/WW3 reference manuals are
    never edited.

### 8A.6 Results-free QC gates

**A0 Gate 1 — global source and derivation evidence**

- West-, east-, north- and south-facing coasts produce rotated-equivalent outputs.
- A three-wet-side coast, partial-land edge, island, headland/peninsula, cove/bay, disconnected wet
  segments and Great Lakes basin each match hand-derived perimeter classifications.
- Real-source output must not exhibit fixed S/W, whole-side land exclusion, or two-nearest-side
  selection behavior.
- No surf-point-local break type, pier or Huntington buoy ID affects regional setup.
- Real source-backed Myrtle Beach and Great Lakes setup reaches WW3 derivation with the correct OSM
  layer/tag/ring contract, frozen geometry hash, and separately declared bathymetry datum/provenance;
  the wrong-layer and mixed-datum controls refuse.

**A0 Gate 2 — separate O/H native-binary behavior**

- For each O candidate, active G1 cells, NOAA source files and interpolation behavior are measured;
  land cells never become active merely because the H curve covers land.
- For each H candidate, canonical transfer contains boundary points only, includes required corners,
  is one verified order with no jump, and has keyword matching actual topology.
- The actual WW3 and SWAN binaries exercise each mechanically viable O/H pair with predeclared
  warning/error/tolerance gates.
- Real native output must show no fixed S/W behavior, missing active-cell source, off-boundary
  diagnostic insertion, point permutation/duplication, missing corner/segment, wrong
  `OPEN`/`CLOSED`, or spacing violation.
- H keeps the existing formatted `FREE` transfer and grids. Native `ww3_outp ITYPE=0` inventory run
  after `ww3_shel` proves contiguous effective native ordinals and an ordered/unique `L2P*`
  subsequence; each name gap must exactly match shel land-filter evidence. It is consumed in memory
  only for selector construction, never published/persisted/spectral input, and remains within the
  locked resource ceiling. The coarse-to-fine max-overlap mapping collapses consecutive same-parent
  runs while preserving corners/land transitions; actual F7.2 uniqueness and the 0.1 corridor for
  every wet SWAN perimeter node pass.

**A0 Gate 3 — diagnostic continuity, compatibility and rollback evidence**

- Every D candidate preserves buoy/DREF actual-coordinate spectra, time coverage and energy identity;
  vchain and `model_wave_source` read the intended diagnostic source.
- Dependency matrix is evidenced from real generation transitions separately for outer active-cell,
  inner curve, diagnostics, grid/domain, wetness source and binary/config changes.
- Bootstrap compatibility and rollback restore complete hash-matched generations; partial or mixed
  generations are unavailable, never publishable.
- Any automatic cold-recovery behavior remains owned by R11; A0 proves only the initialization and
  rollback method A1 would require.
- D1's second formatted native `ww3_outp` pass selects all and only the
  `diagnostic_output_contract` points in native source-inventory order. It proves atomic
  pre-promotion and setup/generation identity for exactly the cycle and horizon D paths;
  missing/mismatched H or D structurally refuses and logs. Exact cycle-directory retention remains
  promotion/merge-blocked until A0-I names it and the operator approves it; current approval covers
  files, not deletion policy. Historical 2×4 refusal results do not close this gate; live native
  production-axis output supplies the required evidence.

**A0 Gate 4 — evidence review and approved H/D implementation packet**

- Results are reported separately for O, H, D, D15-G confirmation, dependency/rollback and
  initialization, against the approved A1 constraints. It verifies the approved H inventory/coarse-to-
  fine construction and D1 mechanism, including the reported H-only/D-only compatibility policy,
  before merge/deployment.
- Each option names manual support, scientific assumptions, trigger set, files/contracts, cost,
  failure mode and unknowns. No combined A/B/C shorthand hides a seam-specific choice.
- The operator approved the residual H/D mechanism on 2026-08-30. A failed inventory, D-contract,
  compatibility or resource gate still stops or revises the candidate and keeps it fail-closed.

**A1 Gate A — implemented automatic derivation and producer contracts**

- Approved global live-source cases and declared rotational relationships are evidenced on the
  installed production code.
- NOAA source/status mapping exactly matches O; the serialized H topology/keyword output is
  boundary-only; the ephemeral H inventory/final selector and coarse-to-fine F7.2/corridor checks
  satisfy the registered-point gate; diagnostics exactly match D1's versioned contract, native order
  and two exact paths; real Atlantic/Great-Lakes setup matches D15-G. R1 owns live SWAN boundary
  wiring and R2 owns consumer transfer assembly/consumption.
- No real live-source case reaches WW3/SWAN publication when an A0 structural condition is absent.

**A1 Gate B — transition, diagnostics and rollback**

- Domain/grid, O active-cell/status, and G occupancy/bathymetry source/datum/depth changes invalidate
  `mod_def.ww3`, WW3 restart, dependent transfers and SWAN state and require the historical cold
  rebuild. H-only and D-only preservation remain A0-I native-compatibility candidates and fail closed
  until decided.
- Atomic generation promotion and rollback are evidenced without deliberately interrupting the
  serving process.
- D1 diagnostic consumers retain time coverage, spectra and setup/generation identity across the
  transition; missing/mismatched H or D remains structurally non-promotable and unavailable. Exact
  cycle-directory retention remains promotion/merge-blocked until A0-I names it and the operator
  approves it; current approval covers files, not deletion policy. R8b owns canonical `modelHealth`.
- A mandatory historical cold rebuild produces a new compatible restart, discards historical outputs
  before h0, then completes +0…+96 without relying on unimplemented R11 automation.

**A1 Gate C — bounded live fail-closed setup evidence**

- Guarded deploy never interrupts active Python/WW3/SWAN work.
- One configuration-derived generation proves O/H/D/G identities and structural refusals without
  publishing. A1 does not wire live SWAN, claim R2's 73-record/full-fast-vchain consumption,
  R8b/R8c's unified health, or R11's automatic recovery gates.
- Cache, marker and persistent SWAN state remain unchanged; rollback is exercised before R1/R2.

**Deferred ownership, not A1 gates:** R2 owns 73-record full/fast/horizon identity; R8b/R8c own final
marine/API/admin health agreement; R11 owns automatic recovery; R12 owns multi-anchor global
reality/operational closeout.

### A1 producer implementation record — P0 H/D transaction (2026-08-30; deployed 2026-08-31)

The marine branch implements the approved post-`ww3_shel` inventory, separate native
boundary/diagnostic passes, strict diagnostic identity validation, and atomic paired promotion.
Historical local regression records exist for this work, but are not acceptance evidence under §7.
The required source/manual review and all functional evidence must be rerun through the post-code
live-host workflow before this phase can close.
The producer and direct WW3-to-SWAN L2 handoff are deployed. This evidence does not close A0,
A0-I, A1, R1, R2, the 73-record transfer, publication, or recovery.

**Retention direction (operator, 2026-08-30):** retain an H/D pair together while it is active,
referenced, or the complete rollback predecessor. An older pair becomes deletion-eligible only
after a newer pair is fully validated and it is no longer needed for forecast coverage or rollback.
Never delete one member of a pair, a partial pair, or a pair in use. A0-I must still name the
exact durable generation identity and reference-tracking mechanism before implementing promotion
or deletion behavior.

### Live recovery implementation record — 2026-08-31

The marine recovery branch was pushed and deployed to the librewxr test system. The following
implementation work is complete on `feature/ww3-automatic-setup`:

- Native WW3 output was reduced from 44 to 43 requested points by retaining buoy `46253` and
  removing buoy `46222` from the WW3 diagnostic-output axis; `46222` remains an independent
  NDBC observation source. The successful native inventory contains 30 usable L2 boundary points
  after three land-filtered points plus the ten diagnostic points.
- The post-solver native `log.ww3` inventory is used for accepted L2 names; formatted native
  coordinate rounding is accepted at its documented half-quantum tolerance.
- A completed WW3 leg is reused when a SWAN retry targets the same cycle. This prevents a failed
  SWAN publish from spending another full WW3 leg and then failing on an existing destination.
- The 06Z continuation march completed: its H and D transfers cover 30 points from +7 through
  +96 hours. The merged boundary contains 97 hourly records from the leg start through +96.
- The transfer merger now compares the stable point name and coordinate identity, not the
  time-varying bulk-wave summary fields written on each point header.
- The L2 sizing code now expands the L2 bounds to the two-decimal coordinate lattice emitted by
  formatted WW3 transfer files. It never shrinks the computed domain. Focused host regression
  for the L2 sizing, WW3 setup/leg, and merge paths: 166 passed, one existing warning.
- The exact coherent wave-group limit was implemented: κ=1 returns the exact unbounded internal
  limit, while persisted/wire values use `null` for unbounded run lengths. Focused host regression:
  58 passed, one existing warning. The marine branch exposes `nSet`; a separate API feature branch
  `feature/wave-group-limit` adds the corresponding optional response fields.

Live execution status at handoff:

- Full cycle `2026-08-31T18:00:00Z` completed with WW3 and vchain marked `ok`; the 72-hour SWAN
  publish completed, but health is `degraded` because all 162 surf transects used the existing
  bulk fallback.
- The observed cause is the persisted L2 generation predating the coordinate-alignment change:
  `gridRebuiltAt` remains `2026-08-31T05:32:37Z`. Deploying source and restarting the service did
  not regenerate the persisted sizing derivation, so the aligned grid has not yet been exercised.
- The next required action is to regenerate the persisted sizing derivation, confirm its new
  identity and formatted-coordinate boundary corridor before starting a new WW3 leg, and then
  repeat the live handoff check. No generation deletion or pruning policy was implemented.

**A0-I durable record (2026-08-30; deployed behavior, evidence gate remains open):** the existing atomic service
state snapshot now stores the current and immediately preceding complete boundary/diagnostic pair
for each leg and horizon directory. Each reference contains the directory token, setup identity,
both filenames, and both SHA-256 file hashes. A new pair advances the record only after both files
exist, are non-empty, and are hashed; the former predecessor is removed only after that record is
durably written, and only when its complete pair still hash-matches. A missing, partial, changed,
or unrecorded pair is retained. The old count-only horizon prune is no longer called. Local evidence:
177 targeted tests passed with two existing environment warnings.

**Test-system execution record (2026-08-31; librewxr):** the local paired-output work was pushed
and deployed to the marine test system. The guarded deploy waited for an active model cycle rather
than interrupting it, verified the five installed WaveWatch III programs, restarted successfully,
and preserved authentication. The targeted host test set passed **181 tests** with one existing
warning. The first configuration rebuild exposed a real boundary-edge rounding defect; marine
commit `73598b5` corrected the check, passed 93 targeted local tests (one expected refusal), and
was deployed. Replaying the unchanged saved configuration then completed the grid-sizing chain:
the four-side WaveWatch III boundary smoke test passed, and the saved file now contains the outer
boundary, L2 boundary, and diagnostic-output contracts. A forced full run is queued through the
existing signal and is waiting only for the wind gatherer's next extended forecast cycle. This is
live test evidence, not merge, publication, recovery, or final-acceptance evidence.

**Direct-boundary live checkpoint (2026-08-31):** after the sizing derivation was regenerated,
the direct WW3-to-SWAN L2 handoff accepted the regenerated boundary and retained an approximately
1.0 m component. Publication refused only because the required +7 through +72 hour continuation
transfer was absent. This verifies neither the raw-horizon producer nor R2's consumer merge, and
does not complete A0, A0-I, A1, R1, R2, or full recovery.

**§7 document-impact declaration for this local record:** Root Architecture, Provider Manual,
Operations Manual, ADR-100, ADR-109, this plan, the Evolution Plan, and the marine changelog are
affected. API Manual/OpenAPI, stack Operator Manual/localized help, and ODbL notice are **N/A to
P0**: it adds no endpoint, operator field, UI behavior, or active OSM data path. D15's OSM and
datum implementation remains an A0/A1 gate and will require those documents before merge.

### 8A.7 Deployment order if approved

1. A1/R1/R2 complete their approved coding wave and documentation under §6. A0/A0-I do not begin
   quality control until that coding wave is complete.
2. A0 manual/source inventory and native-output evidence run read-only on librewxr, followed by an
   independent `reviewer` audit; no simulated input, local test, or production mutation is used.
3. A1 automatic producer-setup integration lands as one coherent derivation/identity replacement.
   It records real producer output for the later gate, but does not wire live SWAN decks, remove
   scaffolding, or assemble/consume the 73-record transfer.
4. ADR-100/ADR-109/Evolution-Plan reconciliation, Provider/Operations Manual and changelog update
   land with A1 before deployment.
5. Post-code `reviewer` source/manual/contract audit, global live-source/native-binary gates, H
   inventory and D1 contract/resource gates, atomic rollback and the mandatory historical cold-run
   gate pass.
6. One guarded A1 setup-evidence deployment is permitted only after those gates pass. It performs the
   required full historical cold rebuild, creates a new compatible restart, then runs +0…+96; no
   incompatible WW3 restart or SWAN hotstart is reused. It remains non-publishing/fail-closed until
   R1 wires live SWAN and R2 supplies merge/selection/consumption.
7. Run R1's post-code reviewer audit and live-host evidence on the accepted A1 contracts, including
   legacy `level1/` rollback-file preservation and the production comment/log truth sweep, then
   deploy R1 as its own functional change.
8. Resume R2 canonical 73-record transfer repair, updated to bind the accepted identities.

### 8A.8 Approval boundary

The operator approved A1 local implementation in chat on 2026-08-30, including O1, H1, the separate
boundary/diagnostic D invariant, D15, the minimal durable setup-generation envelope, the full
historical cold rebuild, and the residual H/D mechanism. The envelope may
only group approved artifacts, atomically select one complete current generation, and retain one
hash-matched predecessor; A0-I must name its exact path/files/schema before durable implementation.
H1 uses `CLOSED` because it is one complete rectangular curve; land-covered locations remain
mask/bathymetry-controlled. Boundary transfer is boundary-only and buoy/`DREF*` diagnostics are
separate. H retains the existing grids and formatted `FREE` transfer and uses the ephemeral native
post-`ww3_shel` inventory before final-selector generation. D1 is the second formatted native
`ww3_outp` pass with the exact cycle/horizon paths and versioned diagnostic contract. H-only/D-only
compatibility evidence remains a merge/deployment gate; local candidate work remains fail-closed.

**Precedence:** the later H/D ruling supersedes only the locked brief's pre-ruling selection and
terminal wording. Frozen methods, live-case definitions, and limits remain authoritative.

Domain/grid, O active-cell/status, and G occupancy/bathymetry source/datum/depth changes invalidate
`mod_def.ww3`, WW3 restart, dependent transfers and SWAN state and require the historical cold
rebuild. H-only and D-only preservation remain A0-I native-compatibility candidates and fail closed
until decided. A1 owns derivation, identities, WW3 producer setup, generation/compatibility and the
historical WW3 rebuild only; R1 owns live `BOUNDNEST3` wiring/scaffold removal and R2 owns the
73-record merge/selection/full-fast-vchain consumption.

This approval does not authorize any persisted artifact outside that minimum envelope, **except**
D1's exactly approved `level0/cycle_<token>/ww3_outp/ww3_diagnostic_transfer.ww3` and
`level0/horizon_<token>/ww3_horizon_diagnostic_transfer.ww3`; durable envelope implementation waits
until A0-I names its exact path/files/schema. It also does not authorize
a new dependency, port, endpoint, config key, scientific threshold/reachability criterion, or custom
spectral-transfer rewriter. A0 remains required before merge/deployment and can stop or revise a
candidate methodology. A1 setup evidence remains non-publishing/fail-closed until R1/R2. Production
retains R3's exhaustion refusal, but R3 is not a GI-1/GI-2 topology validator and must not be
described as making the current boundary safe.

## 9. R1 — Direct SWAN L2 boundary generation (approved D1; BLOCKED by §8A)

**Owner:** §6 universal workflow
**Primary files:** `services/swan_runner.py`, `services/swan_formats.py`, `services/vchain.py`,
`providers/nearshore/swan.py`; required full/fast live-boundary evidence

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
7. Remove config-time cleanup's deletion of the legacy `level1/` rollback directory and finish the
   production L1/scaffold/patch comment and log truth sweep identified in the historical review.

Gate R1:

- Full and fast runs build with no `level1/` directory; monkeypatched level1 reads raise if touched.
- L2 INPUT: exactly one BOUNDNEST3, zero BOUNDSPEC/BOUNDNEST1.
- L3 middle INPUT: exactly one BOUNDNEST1 and correct NESTOUT for L4.
- Missing verified transfer refuses; no fallback or fabricated boundary.
- Runtime read audit proves no L2 or L3-middle access to `level1/INPUT`/`B_*.txt`.
- Legacy physical rollback files remain unchanged through geometry setup/cleanup.

R1's uncommitted local coding is not acceptance evidence; a historical review found that its boundary
contract did not meet §8A. The branch remains unmerged/undeployed. After the A1/R1/R2 coding wave is
complete, reconcile R1 onto the accepted H producer contract and run the §6 post-code source/live
gates.
R1 consumes the A1-produced final H transfer and alone wires it into the live `BOUNDNEST3` deck; it
does not build the inventory, select D diagnostics, or consume diagnostic validation output.
Until R2 is present, any incomplete/frozen boundary must refuse before hotstart or publication;
removing the scaffold alone must not open a publish path.

## 10. R2 — Streaming WW3 horizon and one canonical transfer (BLOCKED by §8A/R1)

**Owner:** §6 universal workflow
**Primary files:** `services/ww3_formats.py`, `services/vchain.py`, `providers/nearshore/swan.py`,
`service.py`, transfer/quick-boundary live evidence paths

Design:

- Streaming merge writes atomically to `level0/hstage_<consumer-cycle>/ww3_l2_transfer.ww3`.
- Static compatibility: header/axes, ordered name/lat/lon identity, and depth.
- Dynamic per-record wind/current metadata is excluded from identity but preserved byte-for-byte.
- Nowcast owns +0…+6; horizon owns +7…+72; exact hourly adjacency required.
- Full and fast paths consume the same verified hstage artifact. Raw seven-record archives are never
  a production fallback.
- Merger reads/writes bounded records; no full-file `read_text()/splitlines()/join()`.
- R2 consumes A1's accepted identities: H for the 73-record boundary merge and vchain seam, D for
  buoy validation and `model_wave_source`. Its diagnostic view is cycle D h0…h6 plus horizon D
  h7…h72, with exact setup/D identity and hourly adjacency; it creates no third persisted artifact.
  It does not generate the H inventory or either H/D producer artifact.

Tasks:

1. Streaming preamble/record reader and atomic temp+fsync+replace writer.
2. Exact lower/upper bounds, duplicate/gap/order checks, actual-file coverage authority.
3. Concise static mismatch logs; never dump contract-derived complete H or D point records.
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
9. Audit and retire stale local-only assertions that pin raw hourly archives, short-horizon partial
   merge, zero dynamic point metadata, and inherited scaffold behavior. Named files include `test_vchain_module.py`,
   `test_transfer_merge.py`, `test_quick_update_l2_boundary_resolution.py`,
   `test_quick_update_chain_boundary_wiring.py`, `test_swan_stationary_full_nest.py`, and
   `test_hourly_fill_chain_boundary.py`.

Gate R2:

- Production-shaped changing-wind pair merges to exactly 73 records, +0…+72.
- Changed name/order/coordinate/depth, short/gapped/duplicate time, or axis mismatch refuses.
- Horizon records +73…+96 never enter the consumer artifact.
- A real downstream failure preserves the prior verified destination and removes the temporary file.
- Memory gate proves bounded RSS on 33.7 MB + 433.1 MB inputs; no new swap growth.
- Full and fast staged files compare byte-identical; both PRINT files show no exhaustion warning.
- Same-cycle successful publish followed by a forced candidate and downstream failure leaves hourly
  selection on the first successful artifact.

## 11. R3 — Horizon safety behavior and cold-recovery trigger — ✅ COMPLETE 2026-08-29

**Owner:** §6 universal workflow
**Approval:** D5 through operator direction; automatic restart remains disabled until R11
**Primary files:** `service.py`, `state.py`, `services/swan_runner.py`,
`providers/nearshore/swan.py`, `endpoints/health.py`, and required live refusal/publication evidence;
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

- A real observed incompatible or short boundary refuses, does not overwrite cache/marker, and
  creates one refusal; recovery intent exists only after R11 is enabled.
- Sentinel prior hotstart remains byte-identical after exhaustion refusal.
- R11 restart/refetch/cold-run harness cannot loop on unchanged inputs.
- Health and admin surface name the recovery state without claiming fresh model data.
- Clean-install bootstrap waits/retries until a complete boundary exists.

### R3 execution record — 2026-08-29

- Historical guard `ed930a1` established the missing typed refusal; later full/fast, convergence-
  priority, restart-truth and clean-fast recovery mutations close at marine `ae551be` plus docs
  `4deed95`. Historical local-check result: 80 passed, one pre-existing dependency warning; this is
  not acceptance evidence under §7.
- Historical independent source audit initially found four ordering/state-truth defects; all were guarded,
  remediated, and re-audited PASS. The R3 gate was clarified at meta `08d2393f`: R3 itself never
  deletes usable hotstarts, while the pre-existing crash cleanup still removes state proven to crash
  SWAN and does not restore poisoned state.
- Marine PR #1 merged to `main` as `875360e`; guarded deploy started the process at
  `2026-08-29 14:45:52 UTC`. Health/manifest returned 200 and the unauthenticated protected route
  returned 401. Targeted deployed tests: 80 passed, one pre-existing dependency warning.
- Post-deploy journal review found no new R3-related warning/error class. The observed NDBC spectral
  rate-limit warning also occurred before deployment and is unrelated.
- Natural full attempt for cycle `2026-08-29T12:00:00Z` started at `14:50:57 UTC`. Six observed
  attempts reached L2 and each emitted one detector WARNING, one typed
  `no-publish: l2_boundary_exhausted` ERROR, and one matching vchain refusal; none reached L3/L4.
  Health reports one no-publish reason, `vchain.status=refused`, and the same refusal slug.
- Persistent evidence remained unchanged: forecast cache mtime `2026-08-28 06:48:20 UTC`, run
  marker mtime `2026-08-28 02:57:56 UTC`, persistent L2 hotstarts no newer than
  `2026-08-29 14:38:44 UTC` (before deploy), and L3/L4 persistent hotstarts remain from August 28.
  The state snapshot alone advanced, as required, to store failure/flag health. R3 live gate PASS.

## 12. R4 — OFS/WCOFS CURRENT restoration

R4 is three separately committed/audited/deployed functional repairs, followed by one controlled
state quarantine before R5 enables publication.

### R4a — Schema, containment, resampling, full + fast wiring

**Owner:** §6 universal workflow
**Primary files:** `providers/ocean/ofs.py`, `services/swan_runner.py`,
`providers/nearshore/swan.py`, `services/swan_formats.py`, and current/full/fast live evidence

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

- Real WCOFS U/V input resamples to the production 76×84 L2 and all L3/L4 grids within the stated
  four-decimal tolerance, with correct pad, containment, orientation, component ordering, and slicing.
- Every full/fast deck contains INPGRID/READINP CURRENT and a nonempty CURRENT file.
- Structural count formula: `rows = n_times × 2 × (myc+1)`, values/row=`mxc+1`.
  Current L2 full: 73×2×84=12,264 rows, 76 values/row; fast: 12×2×84=2,016 rows.
- No NaN/Infinity; three independently recomputed grid samples match text formatting.

### R4b — Same-model valid-time composition and tail policy

**Owner:** §6 universal workflow

- Enumerate overlapping cycles of WCOFS only. Prior cycles fill early valid times; newer issue
  cycle wins duplicates. Never blend values or mix provider families.
- Fetch only files intersecting the required window plus the existing match allowance; partial
  newer cycles backfill from the prior same-model cycle without creating interior gaps.
- Interior/head gaps refuse. Routine cycles retain the approved bounded final-field tail.
- Cold recovery targets zero-tail full coverage and waits/retries for the needed future 03Z issue:
  00Z may wait ~3 h, 06Z ~21 h, 12Z ~15 h, 18Z ~9 h. The exact wait is health-visible and the
  service remains unavailable/last-good; it never fabricates a tail during cold recovery.

Gate R4b:

- Live evidence covers all four anchors, actual source availability around 03Z, partial newer-cycle
  availability, duplicates, interior gaps, and total candidate failure when naturally observed.
- Routine nominal held tails are 21/3/9/15 h for 00/06/12/18; late 00Z retry may reach zero.
- Cold recovery has 73 resolvable targets, zero head/interior/tail gap, and source provenance for
  every valid time. Twelve-hour fast fill normally has 12 current blocks and zero held tail.
- Live gate records real file Last-Modified/availability and actual selected arithmetic.

### R4c — Current health and compact provenance (D8)

**Owner:** §6 universal workflow
**Primary files:** `state.py`, `endpoints/health.py`, `providers/nearshore/swan.py`,
`services/swan_runner.py`, and health/no-publish/restart-survival live evidence

- Add required `inputs.currents`; set available only after every active grid preflight succeeds.
- Persist compact `currentForcing`: status, WCOFS cycles, coverage start/end, first/last field,
  native/hourly counts, held-tail hours, refusal, and update time—never arrays.
- Preserve `currentsTailHeld` for compatibility. Tail hold stays informational; explicit absence,
  malformed data, or head/interior gap floors overall health to failed and refuses publication.

Gate R4c:

- Fetch success followed by writer/preflight failure reports unavailable, never healthy.
- State survives restart with original timestamps and no arrays.
- Live health never reports currents available before required-input preflight completes.
- R4c is deployed and health-verified before R5 can enable publication.

### R4d — Pre-publish SWAN hotstart quarantine (D11)

After R4c and before R5, enumerate/hash only tokened SWAN L2/L3/L4 hotstarts. Use §5.3's
transactional quarantine; do not touch WW3 restarts, forecast cache, bathymetry, or grid sizing.
The first R5 run must cold-start every active SWAN level. Rollback restores only hash-matching
files if R4/R5 code is reverted.

## 13. R5 — κ=1 exact limit and nullable representation

**Owner:** §6 universal workflow; bounded API worker slice in a separate API commit
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

- A real κ=1 occurrence retains the exact finite values; a real out-of-range input refuses.
- JSON/cache/API contain κ=1 and null unbounded fields, never NaN/Infinity.
- Fallback score is byte-identical to existing dominance fallback.
- A real κ=1 occurrence proceeds through L3/L4, SwellTrack, 73 timestamps, cache and marker.
- An unexpected runtime error prevents publication and preserves last-good.

## 14. R6 — Last-good cache contract and recovery

**Owner:** §6 universal workflow
**Primary files:** `providers/_common/cache.py`, `providers/nearshore/swan.py`, and recovery live evidence paths

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

- Live seven-day cache observation proves last-good remains readable after 24 h and expires at seven days.
- No outer cache limit may expire a valid artifact before the approved seven-day entry expiry.
- Live capacity pressure recovers only an eligible disk artifact.
- Concurrent real misses decode disk once; stale/malformed/incomplete artifact is not served.
- Fresh `saved_at` plus old h12–h72 tail does not pass; recovery preserves each hour's producer age.
- Recovery never resets `lastRunTime` or model age.
- Native/API outputs agree on lastRunTime/dataAge and remain explicit when unavailable.
- Production-sized 116 MB cold/concurrent misses have a predeclared endpoint-latency ceiling and do
  not starve TLS/API; recovery does not overlap active WW3/SWAN work unless a lock proves safety.

Deployment note: do not deploy this repair before R2–R5 produce a verified last-good artifact; the
current disk cache contains frozen/invalid hours and must not be resurrected as trusted output.

## 15. R7 — Per-hour provenance and publication honesty

**Owner:** §6 universal workflow
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
`services/model_wave_source.py`, cache/endpoint response live evidence paths

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
- No fast update may overwrite the retained tail provenance.
- Cache restore preserves provenance; legacy cache yields unknown/ineligible.
- Existing public signals remain testable: `lastRunTime`, `dataAge`, per-hour `modelStatus`, and
  HTTP 503 when no proxy fallback exists. Proxy-fallback origin is not claimed publicly.
- Near-zero 0.0 m/1.1 s hour is unavailable/null and invariant still fires; valid weak sea passes.
- Cached and on-demand paths use the identical unavailable field snapshot.
- No new public field appears in OpenAPI/response snapshots.

R7a lands before R6 enables provenance-required recovery. R7b and R7c are separate functional
deployments after R6; all three changes remain separately attributable.

## 16. R8 — Unified Model Health

**Owner:** coordinator contract → §6 universal workflow across marine, API, and dashboard/stack
**Approval:** D13 through plan acceptance; visitor forecast contracts remain unchanged
**Repositories:** marine is the canonical producer; API is an opaque authenticated pass-through;
dashboard/stack renders operator status; each reports its deployed revision where an existing
authoritative revision source is available

### R8a — Contract and reducer — ✅ COMPLETE 2026-08-29

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

**R8a execution record.** Marine PR #2 merged as `f2abf1b` after historical implementation and
independent review. Historical local/deployed check records reported 129 passed with one pre-existing
dependency warning; they do not close current gates under §7. Guarded deploy started the process at
`2026-08-29 21:25:16 UTC`;
health/manifest returned 200 and auth remained enforced. Live `/health.modelHealth` is schema 1,
`overall=unknown` with `not_instrumented`, `serving=unavailable`, provider children
`noaaBoundary/wind/stofsWaterLevel/wcofsCurrents`, and SWAN children `l2/l3/l4`; existing legacy
health remains independent. This is the required conservative skeleton, not R8b instrumentation.

### R8b — Marine instrumentation and restart truth

**Primary files:** marine `state.py`, `endpoints/health.py`, `service.py`, `services/vchain.py`,
`services/ww3_runner.py`, `services/swan_runner.py`, `providers/nearshore/swan.py`, current-provider
path and required live evidence

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

- Reviewer source trace covers every state pair, required/optional stage, active attempt over prior
  failure, restart restore, no-evidence→unknown, and blocked-attempt plus valid/stale/unavailable
  serving-state combinations.
- Live API/operator evidence proves schema versioning, old-key compatibility, opaque API pass-through,
  and no visitor payload change.
- Live observed stage outcomes must identify the exact owning stage and overall state; no neighboring
  success may hide horizon/merge failure, wrong current component mapping, missing SWAN output,
  absent binary pin, missing provenance, corrupt cache, incomplete fast fill, or failed publication.
- A production-sized ledger adds bounded request latency and no material service starvation.
- Authorized live gate captures one full attempt and one fast fill; raw horizon→merge→L2 coverage,
  required CURRENT, publication, revisions, and model age agree across marine health, authenticated
  API, and operator UI.
- Rollback uses normal deploy scripts, retains old health keys, and never deletes model artifacts,
  cache, or pin files.

R8 contract/reducer and marine instrumentation deploy before automatic recovery. Operator UI may
follow as a separately attributable deployment, but the plan cannot close until the required
surfaces agree and the reviewer confirms that source and live evidence leave no silent-stage failure.
CheckMK is
outside the close gate unless the operator later activates the optional follow-on.

## 17. R9 — Retry reuse and deployment guard

**Owner:** §6 universal workflow

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

- Real downstream failures invoke WW3 once; artifact hashes remain unchanged on retry.
- Missing/corrupt/fingerprint mismatch reruns; restart reruns conservatively.
- Deploy started in WW3/Python/SWAN/horizon phases waits and never sends SIGTERM.
- A real exception at any production phase clears state.
- Same-cycle reuse is evidenced from real attempts; production is never deliberately failed for this gate.

## 18. R10A/R10B — Horizon worker evidence, decision, and optional implementation

**Owner:** `troubleshooter` evidence → operator decision → §6 universal workflow
**Status:** R10A evidence is open; R10B remains blocked until D9 is explicitly decided

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
architectural/persisted-artifact decision and receives its own accepted amendment before code. A
later approval of a worker or artifact does not approve service/process placement; that remains a
separate D9 architectural decision.

## 19. R11 — Automatic cold recovery implementation

**Owner:** §6 universal workflow
**Dependency:** R1–R9 have completed their required code, documentation, post-code QC, deployment,
and live-evidence states; A1 historical cold-rebuild/bootstrap method and compatibility gate complete
**Primary files:** marine `__main__.py`, `service.py`, `state.py`, `services/vchain.py`,
`services/ww3_runner.py`, `providers/nearshore/swan.py`, the existing NOAA/wind/STOFS/WCOFS
provider seams, and recovery/restart live evidence paths; no new service or endpoint

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
5. Invalidate only incompatible prior state. Where no compatible WW3 restart exists, acquire the
   complete A1-proven historical boundary and forcing window, march it to h0 and discard that
   historical output, create the h0 restart, run +0…+6, then use that run's +6 restart for the
   +6…+96 continuation. No numeric historical look-back is invented. SWAN hotstart eligibility
   remains governed by its existing approved quarantine policy.
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
- The A1 historical cold-rebuild/bootstrap method and compatibility gate are re-exercised before
  recovery becomes production-authoritative; incompatible prior state is not reused. Independent
  buoy/cam review occurs immediately after the first publish as the deployment acceptance/rollback
  gate.
- Host reboot/service restart mid-recovery resumes safely from intent or restarts recovery; never
  publishes partial state.
- Unified health exposes the trigger, source generation, awaited prerequisite, attempt count, every
  stage result, and last-good decision throughout the drill.

## 20. R12 — End-to-end recovery and close gate

The plan does not close on unit tests. Required live evidence:

1. One successful full cycle at each 00/06/12/18 UTC anchor.
2. One successful fast fill after a full cycle.
3. Full and fast consume the same verified 73-record +0…+72 H boundary with its contract-derived
   boundary-only ordered-point count, 35 frequencies and 72 directions; D is separately validated
   against its contract-derived ordered diagnostic count and identity. Changing wind/current point
   metadata is preserved and no exhaustion warning occurs.
4. Project WW3 decks contain their required wind forcing; every active SWAN deck contains WIND,
   WLEVEL, CURRENT and valid bathymetry. For the current 76×84 L2 grid, full CURRENT has 73×168 =
   12,264 U/V rows and fast has 12×168 = 2,016 rows, each with 76 values; generalized count is
   `n_times × 2 × (myc + 1)` rows of `(mxc + 1)` values.
5. No SWAN-L1 scaffold access, κ crash, NaN/Infinity, missing CURRENT, cache premature expiry, or
   mixed-age tail mislabeling.
6. Unified health names the same attempt, deployed revisions/binaries, stage coverage and result at
   marine, authenticated API and operator UI; no pending failure or recovery intent is hidden.
7. Cache survives service restart with honest model age. Failure-retention is proven only by
   read-only observation of a naturally occurring production refusal—never by deliberately
   corrupting the serving process.
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

Each row is one attribution gate. A0/A0-I are read-only evidence gates after the A1/R1/R2 coding
wave and before its merge/deploy decision. Every other row is one functional deployment unless its
text explicitly says evidence/decision only:

1. R0 guarded deploy preflight.
2. R3 fail-closed refusal behavior; no recovery intent, exit, or restart yet.
3. R8a schema/reducer skeleton; uninstrumented evidence remains `unknown`.
4. §8A A0/A0-I separate O/H/D/G/dependency/bootstrap evidence and independent `reviewer` audit;
   **no deployment**. It follows the completed A1/R1/R2 coding wave and gates merge/deployment.
5. §8A A1 producer setup under the 2026-08-30 approval: O1, H1 serialized topology/coarse-to-fine
   construction, separate diagnostics, the approved ephemeral H inventory/final selector, approved D1
   formatted diagnostic transfer paths, D15, the minimal durable generation envelope, and mandatory
   historical cold rebuild. The H inventory and D1 second pass run inline in the existing leg/horizon
   producer transaction, without schedule/cadence/trigger change. It is non-publishing/fail-closed
   until R1/R2. Merge/deploy waits for global live-source cases, native binaries, H/D contract/resource and
   A0-I compatibility/rollback evidence, and the cold-run gate.
6. R1 direct scaffold removal plus rollback-file/comment truth cleanup; it wires A1's H transfer into
   live `BOUNDNEST3`.
7. R2 verified streaming H boundary + full/fast shared artifact; it consumes D for buoy validation
   and `model_wave_source`, and H for the vchain seam.
8. R4a CURRENT schema/containment/resampling/full+fast wiring.
9. R4b approved same-model valid-time composition and wait/tail policy.
10. R4c CURRENT provenance/health.
11. R4d transactional SWAN L2/L3/L4 hotstart quarantine; WW3 restart untouched at this stage.
12. R8b complete marine stage instrumentation and post-code reviewer/live evidence.
13. R5 κ exact-limit/null handling—the first publish-enabling deployment.
14. First verified cold SWAN full publish and immediate post-publish reality/rollback gate.
15. R7a internal provenance, then one provenance-complete full cycle.
16. R6 cache liveness using that verified provenance-complete last-good.
17. R7b same-run serving identity and existing-field age honesty.
18. R7c near-zero gate.
19. R8c authenticated API pass-through and operator UI agreement; CheckMK remains optional.
20. R9 same-cycle reuse and whole-attempt deployment guard.
21. R10A evidence; R10B only after the later operator worker choice.
22. R11 automatic cold recovery.
23. R12 four-anchor close gate.

If any deploy fails its live gate, revert that deployment first and diagnose second. No later row
proceeds on an unverified predecessor.

## 22. Documentation and contracts

Documentation is part of every repair, not a post-acceptance cleanup step. Before source audit or
deployment, the round owner records its §7 declaration and completes the applicable row below.
"Likely authorities" is an explicit review list, not permission to invent a field, endpoint, config
key, artifact, or architectural decision. Any authority not affected is marked `N/A` with source
evidence in the round record.

| Repair | Likely authorities to declare, update, or evidence as `N/A` before audit/deploy |
| --- | --- |
| A1 | Root `ARCHITECTURE.md` marine chain/configuration; Provider Manual §§14.3/14.10/14.15/14.18; Operations Manual setup, refusal/action, rollback, OSM operations, and ODbL guidance; API Manual §19 and OpenAPI update or evidenced `N/A`; distinct stack Operator Manual; localized wizard/admin help documenting automatic setup, refusal/action, derivation identity, and no selector knob; ADR-100 and ADR-109; Evolution Plan W3/W4 and Q4/PW7; marine changelog and ODbL/third-party notice. |
| R1 | Provider Manual direct-boundary behavior; Root Architecture chain only if its current description changes; ADR-109; Evolution Plan successor note; marine changelog and stale comments/tests terminology. |
| R2 | Provider Manual boundary-streaming/full-fast artifact behavior; Operations Manual artifact/rollback handling; ADR-109; exact stale `24-hour` terminology cleanup across tests/comments and both marine/API changelogs. |
| R3 | Operations Manual refusal/serving-state operations; Provider Manual model-validity behavior; API Manual/OpenAPI and operator help only if existing status semantics require clarification; marine changelog. |
| R4a | Provider Manual current ingestion/resampling and full/fast behavior; Operations Manual source-failure operation; ADR-104 or accepted successor; marine changelog. |
| R4b | Provider Manual valid-time composition/tail behavior; Operations Manual wait/blocked-state operation; ADR-104 or accepted successor; API Manual/OpenAPI and operator help only if existing status semantics change; marine changelog. |
| R4c | Provider Manual current provenance; Operations Manual health/provenance interpretation; API Manual/OpenAPI and operator help for existing model-status pass-through; marine/API changelogs. |
| R4d | Provider Manual SWAN hotstart eligibility; Operations Manual hotstart quarantine/rollback; ADR-109 if accepted artifact policy changes; marine changelog. |
| R5 | Provider Manual exact-limit semantics; API Manual/OpenAPI and operator help for nullable existing group fields; ADR-101; marine/API changelogs. |
| R6 | Operations Manual cache retention/last-good behavior; Provider Manual serving validity; API Manual/OpenAPI and operator help for existing freshness/status semantics; marine/API changelogs. |
| R7a | Provider Manual internal provenance; Operations Manual provenance/revision interpretation; API Manual/OpenAPI and operator help only for existing status pass-through; marine/API changelogs. |
| R7b | Operations Manual serving identity/model age; API Manual/OpenAPI and operator help for existing-field age honesty; marine/API changelogs. |
| R7c | Provider Manual near-zero validity gate; Operations Manual refusal/health interpretation; API Manual/OpenAPI and operator help only if existing status text changes; marine/API changelogs. |
| R8a | Operations Manual health schema/reducer and `unknown`-evidence interpretation; Provider Manual model-stage ownership; API Manual §19/OpenAPI update or evidenced `N/A` for existing opaque pass-through; marine/API changelogs. |
| R8b | Operations Manual stage instrumentation, reason-code, and health interpretation; Provider Manual model-stage/provenance ownership; API Manual §19/OpenAPI update or evidenced `N/A` for existing opaque pass-through; marine/API changelogs. |
| R8c | API Manual §19 and OpenAPI for authenticated opaque pass-through; distinct stack Operator Manual and localized operator/admin help for model-versus-transport freshness and reason/action display; Operations Manual cross-surface health interpretation; Root Architecture only if it describes health routing; optional CheckMK remains documented as unimplemented; marine/API/stack changelogs. |
| R9 | Operations Manual guarded deployment and reuse interpretation; Provider Manual same-cycle reuse constraints; ADR-109 if accepted lifecycle/artifact policy changes; marine changelog. |
| R10A | Operations Manual evidence procedure and no-deploy decision record; ADR-109 and Evolution Plan only for the operator-selected result; marine changelog only if shipped behavior changes. |
| R10B | Root Architecture, Operations Manual, Provider Manual, ADR-109, Evolution Plan, API Manual/OpenAPI/operator help, changelogs, and licensing/notice only to the exact extent of the later approved worker/artifact decision. |
| R11 | Operations Manual recovery controller, recovery intent, source refresh, rollback, and health; Provider Manual cold-recovery validity; API Manual/OpenAPI and operator help for existing health/status semantics; ADR-109 and ADR-104/successor where their accepted policies are implemented; marine/API changelogs. |
| R12 | Operations Manual end-to-end acceptance/reality/rollback procedure; Provider Manual chain validity; API Manual/OpenAPI/operator help for verified existing health semantics; changelogs and plan close record. |

Across applicable rows, A1 documents the OSM ocean `natural=coastline` and Great Lakes/inland
`natural=water` + `water=lake` layer contract, horizontal water-fraction-only semantics, regular
datum-converted bathymetry depth authority, no fallback, ODbL attribution, and removal of the CRM/
fine-depth mixed-datum path. Frozen SWAN and WW3 reference-manual files are read-only citations and
are never edited.

## 23. Approval boundary for operator review

The operator has supplied the recovery direction: invalid required data starts a restart/refetch/
full-cold-run path; recovery may wait for source publication limits; exact κ=1 retains finite fields
and nulls only unbounded values; and unified health must accurately portray every model stage.

Acceptance of this plan activates D6–D8 and D10–D13 exactly as scoped. It does not authorize:

- any grid, model handoff, formula, coefficient, provider family, visitor contract, port, dependency,
  endpoint, or config-key change;
- any R10B worker/process/cadence choice before R10A evidence and a later explicit operator ruling;
- any new persisted artifact beyond the accepted recovery intent and additions to the existing
  state/cache contracts, **except** D1's exactly approved
  `level0/cycle_<token>/ww3_outp/ww3_diagnostic_transfer.ww3` and
  `level0/horizon_<token>/ww3_horizon_diagnostic_transfer.ww3`;
- CheckMK integration, which is optional and separately approvable later.

The operator's 2026-08-30 approval activates D14 A1 local producer-setup implementation and fixes O1
(every wet G1 perimeter cell active and NOAA-supplied), H1 (one ordered complete rectangular `CLOSED`
L2 topology, including permitted land-covered portions), the separate boundary/diagnostic D invariant,
D15, the minimum durable generation envelope, mandatory historical cold rebuild, and the residual
H/D mechanism: existing grids/formatted `FREE` H transfer; ephemeral native post-`ww3_shel`
`ww3_outp ITYPE=0` inventory/final selector; and D1's second formatted native `ww3_outp` with a
versioned native-order `diagnostic_output_contract` and exactly the approved cycle/horizon D paths.
The inventory and D1 second pass run inline in the existing leg/horizon producer transaction, with no
schedule/cadence/trigger change. Domain/grid, O
active-cell/status, and G occupancy/bathymetry source/datum/depth changes invalidate `mod_def.ww3`,
WW3 restart, dependent transfers and SWAN state; H-only/D-only preservation remains A0-I evidence
work and fails closed until decided. A0 remains a merge/deployment gate, not a coding gate. A1 cannot
merge/deploy until global live-source evidence, native binary evidence, A0-I rollback/compatibility and the
cold-run gate pass; production stays fail-closed and non-publishing until R1/R2.

D1 consumes every ordered diagnostic in native source-inventory order and refuses/logs a
missing/mismatched H or D. Its producer passes structural validation, atomic pre-promotion and
setup/generation identity gates; exact cycle-directory retention remains promotion/merge-blocked
until A0-I names it and the operator approves it; current approval covers files, not deletion policy.
R8b owns canonical `modelHealth`. Historical 2×4 control-case results are not acceptance evidence;
production-compatible real native input/output supplies the required live proof. A failed
A0/H/D/cold-run gate, missing
authoritative revision source, or need for a dependency, config key, endpoint, port or persisted
artifact outside the approved scope remains a stop-and-surface event, not implied permission to
expand the design.

---

## 24. Acceptance checklist

### Execution checkpoint — 2026-09-05 (candidate deployed; corrective coding wave active)

This checkpoint is the §6.1 execution ledger. A local test result, control case, simulation, or
uncommitted source change does not advance any column. Only observed live-host evidence advances a
quality-control, deployed, or live-evidence state.

The prior 2026-09-03 wording that described the completed coding wave as
"uncommitted" and "No" under deployment is superseded by observed state: the
clean candidate is committed and deployed on librewxr at marine
`eff77fcf00757fb40e3cabe35487dd638beb5289` on
`feature/ww3-automatic-setup`. Deployment to that test host is not acceptance:
the A0/A0-I gates and every applicable post-code/live gate remain open.

| Repair | Code | Documentation | QC | Deployed | Live evidence / next state |
| --- | --- | --- | --- | --- | --- |
| A0 / A0-I | N/A — evidence-only | Open | Open | N/A | Obtain real librewxr source/native-binary, compatibility, rollback, historical-cold-run, and retention evidence after the A1/R1/R2 coding wave. |
| A1 / R1 / R2 | **Code complete** — committed candidate | **Complete** — source/doc reconciliation 2026-09-03 | Source audit passes; live QC open | Candidate deployed to librewxr; not an accepted deployment | Obtain A0/A0-I real source/native-binary, compatibility/rollback, retention, and historical-cold-run evidence before merge/deployment. |
| R3 | Historical implementation; compatibility recheck open | Open | Not started | Historical deployment only | Recheck against the accepted R1/R2 contracts and obtain current live evidence before relying on its historic status. |
| R4a–R4d | **Code complete** — marine `1cd1209` restores level-specific current-file dimensions and truthful current evidence | Complete — no document delta; restores existing contract | Post-code independent source review passes; live QC pending | `1cd1209` is deployed on librewxr as part of running commit `f5df467`; not an accepted deployment | Obtain the required live WCOFS full/fast, source-clock, preflight, and hotstart-quarantine evidence. |
| R5 | Open | Open | Not started | No | Start only after predecessor coding/deployment gates permit it. |
| R6 / R7 | **Code complete** — uncommitted coding wave | **Complete** — source/doc reconciliation 2026-09-03 | Source audit passes; live QC pending candidate deployment | No | Obtain provenance/last-good live evidence after the required deployment gate. |
| R8b / R8c | **R8b code complete** — marine `1cd1209` restores truthful horizon/current/nested-level evidence; R8c open | Complete — no document delta; restores existing contract | R8b post-code independent source review passes; live QC pending | `1cd1209` is deployed on librewxr as part of running commit `f5df467`; R8c remains open | Obtain live marine/API/operator-surface agreement for full, fast, restart, and named refusal states. |
| R9 | **Code complete** — uncommitted coding wave | **Complete** — source/doc reconciliation 2026-09-03 | Source audit passes; live QC pending candidate deployment | No | Obtain guarded deployment/restart evidence; a busy guard remains a safety refusal, not a test failure. |
| R10A | Open | N/A until evidence exists | Not started | N/A | Gather only the approved evidence; R10B remains unapproved. |
| R11 | Open | Open | Not started | No | Start after its stated predecessors are complete. |
| R12 | Open | Open | Not started | No | Close only after the required four-anchor live evidence and independent review. |

### Plan journal

| Date | Phase | Non-blocking concern | Action recorded |
| --- | --- | --- | --- |
| 2026-09-02 | All active repairs | Earlier local test transcripts and control-case results do not meet the live-only verification rule. | Retained only as history; no current gate may use them. |
| 2026-09-02 | A1/R1/R2 | A0/A0-I is a merge/deployment gate, not a reason to stop unblocked coding. | Complete the approved coding wave, then run the read-only live evidence gate. |
| 2026-09-02 | R9 / deployment | The guarded deploy check observed an active `ww3_shel` descendant. | Do not restart/deploy over it; continue unblocked coding and documentation. |
| 2026-09-02 | A1/R1/R2 | Static linting of the dirty marine worktree reports pre-existing violations outside the active merge/streaming changes. | Correct only new local violations; treat neither local lint nor local tests as a phase gate. |
| 2026-09-02 | A0 / live source | The active continuation's HRRR fetcher is receiving 404 responses for forecast files that NOAA has not posted yet. | Do not interrupt the process or fabricate forcing; retain this as a live-source observation and continue unblocked implementation work. |
| 2026-09-02 | A0 / A0-I | Read-only librewxr inventory found `ww3_shel` actively running as the marine-service child; the service reports `ww3Horizon.inFlight=true`. | Do not run native A0 cases, deploy, or restart over the continuation; continue source/manual/artifact inventory and resume native evidence only after it finishes. |
| 2026-09-02 | A0 / A0-I | The observed `ww3_shel` continuation completed without coordinator intervention. | Native live evidence is unblocked; continue the active R4 coding wave before any phase QC or deployment. |
| 2026-09-03 | R4a | Documentation inspection found that the fast update omitted WCOFS CURRENT even though the accepted plan requires the same resolver/preflight and explicit CURRENT in full and fast paths. | Corrected before coding freeze: the fast path resolves and forwards currents and refuses `currents_fetch_failed`; documentation was not altered to normalize the defect. |
| 2026-09-03 | R7b / R7c | Source inspection found missing transfer identity in per-hour provenance and an identity mismatch that cleared only the swell card instead of serializing the established unavailable hour. | Corrected before coding freeze: full provenance carries H path/hash/coverage; fast retains it; a mismatched or missing identity uses the existing unavailable path. |
| 2026-09-03 | R4 / R8b | Independent post-code review found three source defects: unpadded WCOFS subset extraction, insufficient `currentForcing`/WCOFS provenance, and missing required provider/SwellTrack evidence for fast attempts. | Reopened only the affected R4/R8b coding slices; no live test, merge, deployment, or acceptance proceeds until they are corrected and independently re-reviewed. |
| 2026-09-03 | R4 / R8b | Re-review confirmed the WCOFS two-cell pad but found that some failed fast exits still lacked their owner-stage record and that `hourlyFieldCount` repeated the native source count. | Reopened only those two evidence corrections; no live test, merge, deployment, or acceptance proceeds until the reviewer can verify honest terminal health and native-versus-hourly counts. |
| 2026-09-03 | R4 / R8b | The final independent source review accepted the two-cell WCOFS pad, native-versus-hourly current counts, successful fast-stage coverage, and truthful owner-only fast refusal records. | Source audit complete; all remaining R4/R8 evidence is live-host-only and remains pending deployment of the reviewed candidate. |
| 2026-09-03 | R4 / R8b live QC | Natural post-deploy fast cycle `2026-09-03T11:00:00Z` on candidate `df7b421` exhausted WCOFS across both available source paths before SWAN started. | Live refusal evidence passed: `wcofsCurrents`, `providerInputs`, and overall health all reported `currents_fetch_failed`; no SWAN/WW3 subprocess or publication occurred. Successful-current/full-cycle evidence remains pending real source availability. |
| 2026-09-05 | A0 / A0-I | The deployed candidate is committed and running on librewxr, but read-only inventory could not establish the installed WW3 executable/version, retained native WW3 decks/logs, multi-region source cases, compatibility/rollback, historical cold start, or exact approved retention evidence. | Keep A0/A0-I open; use only read-only retained evidence until a separately authorized native evidence action is ready. |
| 2026-09-05 | R4a–R4c | Live L4 `CURRENT.txt` contains 50 values per row while its active SWAN deck declares 51 x-intervals and therefore requires 52 values. The same live health response reports `inputs.currents.available=true` while compact current forcing is unavailable and incomplete. | Reopen the bounded R4/R8b coding correction. Do not publish new evidence or treat a source tail as complete current forcing until the existing contract is restored. |
| 2026-09-05 | R8b | Independent source review found that ordinary WW3-horizon refusals can leave the owning stage unknown, fast health can assert L3/L4 success when topology did not run them, and compact current counts can be recorded before emitted/preflight-valid proof. | Reopen only the named R8b owner paths and regression guards; repeat source review and live evidence after the correction. |
| 2026-09-05 | R4 / R8b | Corrective marine commit `1cd1209` passed post-code independent source review. It uses each active level's dimensions for current resampling/writing, separates source and emitted current counts, records named horizon refusals as failed stage evidence, and records every required nested-grid instance before reporting its level state. | Await explicit push authorization, then deploy only through the guarded marine script and repeat the live full/fast/current/health gates. |
| 2026-09-05 | R9 / recovery controller | The guarded focused host regression set exposed an ordinary full-run dispatch failure before WW3/SWAN: a missing or wrong-cycle selected recovery artifact raised `recovery_forcing_invalid` through the preliminary recovery-block check. | Corrected and independently source-reviewed in marine `f5df467`; the strict recovery-consumption reader remains fail-closed, while an unavailable preliminary recovery identity returns no block. Deployed only through the idle guarded script. After the natural post-restart attempt returned idle, the exact focused host guard passed: 79 passed, 1 dependency warning. Live chain evidence remains pending. |

- [x] Operator accepts §23's approval boundary and this plan — 2026-08-29.
- [x] Old forward plan archived; redirect installed — 2026-08-29.
- [x] Original recovery results-free gates written and independently reviewed before original implementation — 2026-08-29; historical record only.
- [x] Operator approves §8A A0 evidence/prototype round — 2026-08-30.
- [x] Operator selects D15 OSM-only occupancy + regular datum-converted bathymetry depth direction — 2026-08-30.
- [x] A0 results-free gate record locked and independently reviewed before prototype results — 2026-08-30 (`0aa27635`); historical record only.
- [x] Operator approves D14 A1 local implementation scope and sequencing change — 2026-08-30.
- [x] Operator selects O1, H1 topology, separate diagnostics, D15, the minimal durable generation
      envelope, and mandatory historical cold rebuild — 2026-08-30.
- [x] Operator approves the residual H/D mechanism: ephemeral post-`ww3_shel` H inventory/final
      selector with existing grids/formatted `FREE`, plus D1's separate formatted native diagnostic
      transfers and versioned contract — 2026-08-30.
- [ ] A0 global live-source/native-binary, A0-I compatibility/rollback and historical-cold-run gates
      pass before A1 merge/deployment; H-only/D-only preservation fails closed until then.
- [ ] A0 proves the approved H inventory and D1 contract/resource gates, including H-only/D-only
      compatibility policy, before A1 merge/deployment.
- [ ] A0-I names, and the operator approves, D1's exact cycle-directory retention before D1
      promotion or A1 merge; the existing file-path approval is not deletion-policy approval.
- [ ] A1 matrix row is complete: its §7 document-impact declaration is evidenced, every applicable
      authority is updated in the same functional change (or evidenced `N/A`), and post-code
      reviewer QC passes before atomic rollback gate or deployment.
- [ ] Each of R1–R12 has its own completed §22 matrix row and §7 declaration; no repair closes or
      deploys with a stale, omitted, or contradicted governing document.
- [ ] A1 and every R1–R12 repair pass post-code reviewer QC after the document update, live-host
      functional evidence, independent source audit, live gate, and rollback evidence.
- [ ] R12 four-anchor/reality/health gate passes.
- [ ] No untracked deferred item remains in narrative prose.
- [ ] Coordinator walks the original operator request line by line before close.
