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
| D14 WW3 automatic setup parity | **A0 EVIDENCE/PROTOTYPE APPROVED 2026-08-30; A1 IMPLEMENTATION BLOCKED pending complete O/H/D, dependency/rollback and initialization/bootstrap ruling plus G evidence confirmation** | Make WW3 consume the installation-derived geography/bathymetry setup at both boundaries; no fixed cardinal sides | triggers 3/4/5/6, possibly 1/2/7 |
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

## 8A. PROPOSED AMENDMENT A — WW3 automatic setup parity

**Status:** A0 EVIDENCE/PROTOTYPE APPROVED by operator in chat 2026-08-30;
**A1 IMPLEMENTATION NOT APPROVED** pending A0 evidence and the operator's complete O/H/D,
dependency/rollback and initialization/bootstrap ruling plus confirmation that D15's OSM G policy
passes its locked evidence.
**Effect on queue:** R1 and R2 are blocked. The locally green R1 scaffold-removal branch is neither
merged nor deployed. R3 remains the production exhaustion guard; it does not validate topology.
**Owner sequence for A0:** `troubleshooter` manual/source inventory → `clearskies-test-author`
results-free gate lock → `worker` non-production prototype → independent Sol adversarial QC →
operator policy ruling. **A1 after that ruling:** test author → worker → docs author → Sol QC →
coordinator live gate.

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
silently discarded. The later A1 operator ruling must explicitly amend ADR-109 and reconcile every
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

These remain project design decisions and cannot be selected by an implementation agent:

- which wet perimeter cells must receive NOAA forcing into project WW3;
- whether SWAN's canonical handoff is a full closed rectangle or a proved open curve;
- how multiple wet segments separated by land are represented without violating one-curve grammar;
- whether the existing ray classifications are sufficient as-is or a new scientific reachability
  criterion is needed;
- how NOAA source spectra map/interpolate to WW3 status-2 active cells and what identity/provenance
  must be shared at that outer seam;
- how outer active-cell identity, inner SWAN-curve identity and diagnostic-point identity are
  versioned together without falsely treating them as one topology;
- whether any additional persisted artifact or schema field is required.

### 8A.3 Target invariants

Any approved design must satisfy all of these:

1. **One automatic setup authority.** The configuration-time geography/bathymetry pipeline derives
   both NOAA→WW3 and WW3→SWAN boundaries. Forecast cycles consume the frozen derivation; they do
   not re-derive geography at runtime.
2. **Global and rotationally symmetric.** No side name is privileged. Rotating an otherwise
   identical coast/fixture by 90 degrees rotates the derived result by 90 degrees.
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

**Owner:** `troubleshooter` (Sol, read-only manual/source inventory) → `clearskies-test-author`
(results-free gate/fixture lock) → `worker` (non-production prototype) → Sol auditor
**Environment:** WSL/local scratch is preferred. No production model mutation. Any new librewxr
scratch experiment requires its own named-directory authorization.

Before inspecting candidate results, lock:

- exact global fixtures and expected rotation/metamorphic relationships;
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
cells. Test O/H pairs that are physically and mechanically compatible; do not imply that one O
candidate forces the same-numbered H candidate.

**Diagnostic axis D — boundary versus validation output.** Compare native WW3 mechanisms that keep
buoy and `DREF*` spectra out of the SWAN curve while preserving their actual-coordinate time
series. Native `L2P####` seam continuity remains H/vchain-owned in the boundary transfer. The later
operator ruling separately selects D. A new/changed consumer contract is trigger
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
- whether one native `ww3_outp` pass can satisfy both boundary and diagnostic consumers;
- whether a second native `ww3_outp` pass can reuse existing filenames/contracts with no new
  persisted artifact;
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

Required non-production fixtures include rotated Pacific/Atlantic/north-/south-facing coasts,
Myrtle-Beach-shaped partial land with three wet incident sides, islands/headlands/coves, disconnected
wet segments, and a **real source-backed Great Lakes setup/binary case**. O3 must fail cardinal
rotation, east-facing and three-side controls.

**A0 terminal gate:** the operator separately selects O, H, D, artifact dependency/rollback policy
and WW3 initialization/bootstrap method, and confirms D15 after reviewing G evidence. No production
implementation begins before that complete ruling.

### 8A.5 Implementation design — A1 (blocked until A0 ruling)

**Owner:** `clearskies-test-author` → `worker` (Terra) → docs author → Sol adversarial auditor
**Likely primary files:** `services/geography.py` (authority; change only if evidence requires),
`services/swan_domain.py`, `services/grid_sizing_chain.py`, `services/boundary_reconstruction.py`,
`service.py`, `services/ww3_formats.py`, `services/ww3_runner.py`, `services/vchain.py`,
`services/model_wave_source.py`, `services/swan_formats.py`, `services/swan_runner.py`,
`providers/nearshore/swan.py`, focused state/health and tests.

Tasks after approval:

1. Define one immutable setup derivation containing shared domain/grid/bathymetry provenance plus
   separate versioned contracts for NOAA→G1 active-cell/source mapping, G1→L2 ordered SWAN curve,
   and diagnostic point output.
2. Prefer extending the existing `ww3_leg` block and grid-derivation fingerprint. A new/changed
   consumer contract requires trigger-4 approval; any new dependency, port, endpoint, config key or
   persisted file requires trigger-7 approval.
3. Make NOAA boundary reconstruction and the WW3 status map consume the selected O policy. Prove
   every active cell is supplied and every supplied boundary file maps to the selected active set.
4. Make WW3 grid status and boundary assembly refuse any cell/file mismatch.
5. Generate WW3 L2-boundary output points from the selected H policy, including required corners,
   output-location validity and continuous order.
6. Implement the selected D mechanism. Preserve buoy/DREF valid-time coverage, retention,
   fingerprinting and spectra at their actual coordinates; preserve `L2P####` seam continuity in H;
   update `model_wave_source` and vchain atomically with the producer contracts. Do not maintain a
   custom spectral-transfer rewriter unless separately approved.
7. Emit the final `BOUNDNEST3` command from the derivation's actual topology.
8. Implement exactly A0's approved artifact dependency and generation/rollback table. Do not
   invalidate or preserve `mod_def`, restart, horizon, transfer or SWAN state by blanket assumption.
9. Thread the separate verified outer/inner/diagnostic identities through production full, horizon
   merge, fast fill and vchain. R8b/R8c later add the final unified-health propagation.
10. Preserve R3 exhaustion behavior and add A1-owned structural refusals; no cache, marker or
    persistent SWAN hotstart advances on any derivation/transfer mismatch.
11. Implement D15 exactly: regime-correct OSM queries/fractions only, regular datum-converted
    bathymetry for every depth, no fine-depth substitution or fallback provider, and structural
    refusal on incomplete geometry. No SoCal-only source or universal coastline tag may masquerade
    as a global setup path.
12. Before deployment, update Root Architecture, ADR-100, explicitly amend ADR-109, reconcile the
    Evolution Plan conflict, and update Provider/Operations Manuals, config/operator help,
    changelog, ODbL/third-party notice and this plan. The frozen SWAN/WW3 reference manuals are
    never edited.

### 8A.6 Results-free QC gates

**A0 Gate 1 — global source and derivation evidence**

- West-, east-, north- and south-facing coasts produce rotated-equivalent outputs.
- A three-wet-side coast, partial-land edge, island, headland/peninsula, cove/bay, disconnected wet
  segments and Great Lakes basin each match hand-derived perimeter classifications.
- Mutating any output back to fixed S/W, whole-side land exclusion or two-nearest-side selection
  fails.
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
- Mutations for fixed S/W, missing active-cell source, off-boundary diagnostic insertion, point
  permutation, duplicate, missing corner/segment, wrong `OPEN`/`CLOSED`, and spacing violation fail.

**A0 Gate 3 — diagnostic continuity, compatibility and rollback evidence**

- Every D candidate preserves buoy/DREF actual-coordinate spectra, time coverage and energy identity;
  vchain and `model_wave_source` read the intended diagnostic source.
- Dependency matrix is mutation-proved separately for outer active-cell, inner curve, diagnostics,
  grid/domain, wetness source and binary/config changes.
- Bootstrap compatibility and rollback restore complete hash-matched generations; partial or mixed
  generations are unavailable, never publishable.
- Any automatic cold-recovery behavior remains owned by R11; A0 proves only the initialization and
  rollback method A1 would require.

**A0 Gate 4 — operator decision packet**

- Results are reported separately for O, H, D, D15-G confirmation, dependency/rollback and
  initialization.
- Each option names manual support, scientific assumptions, trigger set, files/contracts, cost,
  failure mode and unknowns. No combined A/B/C shorthand hides a seam-specific choice.
- The operator can select every required policy without inferring an unstated default.

**A1 Gate A — implemented automatic derivation and boundary contracts**

- Approved global fixtures and 90-degree metamorphic rotations pass against the production code.
- NOAA source/status mapping exactly matches O; SWAN boundary-only transfer exactly matches H;
  diagnostics exactly match D; real Atlantic/Great-Lakes setup matches D15-G.
- All A0 mutations refuse before WW3/SWAN publication.

**A1 Gate B — transition, diagnostics and rollback**

- Approved dependency table governs reuse/invalidation exactly; unchanged generations reuse only
  what A0 authorized.
- Atomic generation promotion and rollback are kill-tested at every write/promotion boundary.
- Diagnostic consumers retain time coverage, spectra and retention across the transition.
- A1's approved bootstrap method completes without relying on unimplemented R11 automation.

**A1 Gate C — bounded live fail-closed integration**

- Guarded deploy never interrupts active Python/WW3/SWAN work.
- One configuration-derived generation proves O/H/D/G identities and structural refusals. A1 does
  not claim R2's 73-record, R8b/R8c's unified health or R11's automatic recovery gates.
- Cache, marker and persistent SWAN state remain unchanged on any A1 refusal; rollback is exercised
  before continuing to R1.

**Deferred ownership, not A1 gates:** R2 owns 73-record full/fast/horizon identity; R8b/R8c own final
marine/API/admin health agreement; the WW3 cold-start benchmark plus R11 own automatic cold
recovery; R12 owns multi-anchor global reality/operational closeout.

### 8A.7 Deployment order if approved

1. A0 manual/source inventory, results-free gate lock, non-production prototype and Sol audit; no
   deploy and no production mutation.
2. Operator separately selects O, H, D, dependency/rollback and initialization/bootstrap and
   confirms D15-G against its evidence; that ruling activates A1.
3. A1 test-first automatic-setup integration lands locally as one coherent contract replacement.
   Do not create a half-state where NOAA→G1 and G1→L2 consume contradictory setup generations.
4. ADR-100/ADR-109/Evolution-Plan reconciliation, Provider/Operations Manual and changelog update
   land with A1 before deployment.
5. Independent Sol source/manual/contract audit and global mutation gates pass.
6. One guarded A1 deployment is permitted only if A0's approved bootstrap and atomic rollback are
   executable. If an outer-boundary/grid change still lacks evidence-backed initialization, deploy
   waits for that benchmark/procedure; it does not skip ahead to or pretend R11 exists.
7. Re-run R1 scaffold-removal tests/source audit on the accepted A1 contracts, include legacy
   `level1/` rollback-file preservation and the production comment/log truth sweep, then deploy R1
   as its own functional change.
8. Resume R2 canonical 73-record transfer repair, updated to bind the accepted identities.

### 8A.8 Approval boundary

The operator approved §8A's A0 evidence/prototype round in chat on 2026-08-30. That approval does
not select O/H/D, compatibility/rollback or initialization policy and does not authorize A1
implementation. The later A1 approval must explicitly name:

- the selected O outer active-cell/source-mapping policy;
- the selected H WW3→L2 curve policy and exact `OPEN`/`CLOSED` derivation;
- the selected D diagnostic-output mechanism and its consumer/retention contract;
- confirmation or reopening of D15's OSM-only fraction/regular-depth policy after G evidence;
- the artifact dependency/invalidation table, atomic generation promotion and rollback;
- the evidence-backed WW3 initialization/bootstrap method needed before A1 deploy;
- explicit amendment of ADR-109 and the two boundary contract changes (triggers 3/4, and trigger 2
  if ownership moves);
- any new dependency, port, endpoint, config key or persisted file (trigger 7);
- any new scientific threshold or ray/reachability criterion (trigger 1).

Until that later ruling, R1/R2 remain blocked. Production retains R3's exhaustion refusal, but R3
is not a GI-1/GI-2 topology validator and must not be described as making the current boundary safe.

## 9. R1 — Direct SWAN L2 boundary generation (approved D1; BLOCKED by §8A)

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
7. Remove config-time cleanup's deletion of the legacy `level1/` rollback directory and finish the
   production L1/scaffold/patch comment and log truth sweep found by Sol QC.

Gate R1:

- Full and fast runs build with no `level1/` directory; monkeypatched level1 reads raise if touched.
- L2 INPUT: exactly one BOUNDNEST3, zero BOUNDSPEC/BOUNDNEST1.
- L3 middle INPUT: exactly one BOUNDNEST1 and correct NESTOUT for L4.
- Missing verified transfer refuses; no fallback or fabricated boundary.
- Runtime read audit proves no L2 or L3-middle access to `level1/INPUT`/`B_*.txt`.
- Legacy physical rollback files remain unchanged through geometry setup/cleanup.

R1's scaffold-removal mechanics are locally green, but independent Sol QC failed the boundary
contract described in §8A. The branch remains unmerged/undeployed. After §8A is approved and
implemented, rebase/reconcile R1 onto the accepted topology and repeat every local/source/live gate.
Until R2 is present, any incomplete/frozen boundary must refuse before hotstart or publication;
removing the scaffold alone must not open a publish path.

## 10. R2 — Streaming WW3 horizon and one canonical transfer (BLOCKED by §8A/R1)

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

## 11. R3 — Horizon safety behavior and cold-recovery trigger — ✅ COMPLETE 2026-08-29

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

### R3 execution record — 2026-08-29

- Test-first guard `ed930a1` established the missing typed refusal; later full/fast, convergence-
  priority, restart-truth and clean-fast recovery mutations close at marine `ae551be` plus docs
  `4deed95`. Final WSL targeted result: 80 passed, one pre-existing dependency warning.
- Independent Sol source audit initially found four ordering/state-truth defects; all were guarded,
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

**R8a execution record.** Marine PR #2 merged as `f2abf1b` after Terra test/implementation rounds
and repeated Sol adversarial review. Final WSL and deployed targeted result: 129 passed, one
pre-existing dependency warning. Guarded deploy started the process at `2026-08-29 21:25:16 UTC`;
health/manifest returned 200 and auth remained enforced. Live `/health.modelHealth` is schema 1,
`overall=unknown` with `not_instrumented`, `serving=unavailable`, provider children
`noaaBoundary/wind/stofsWaterLevel/wcofsCurrents`, and SWAN children `l2/l3/l4`; existing legacy
health remains independent. This is the required conservative skeleton, not R8b instrumentation.

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

Each row is one attribution gate; A0 is evidence-only with no deployment. Every other row is one
functional deployment unless its text explicitly says evidence/decision only:

1. R0 guarded deploy preflight.
2. R3 fail-closed refusal behavior; no recovery intent, exit, or restart yet.
3. R8a schema/reducer skeleton; uninstrumented evidence remains `unknown`.
4. §8A A0 separate O/H/D/G/dependency/bootstrap evidence, Sol audit and operator ruling; **no
   deployment**.
5. §8A A1 automatic setup integration only after the complete later operator ruling and executable
   initialization/atomic rollback gate.
6. R1 direct scaffold removal plus rollback-file/comment truth cleanup on A1's accepted contracts.
7. R2 verified streaming boundary + full/fast shared artifact bound to A1 identities.
8. R4a CURRENT schema/containment/resampling/full+fast wiring.
9. R4b approved same-model valid-time composition and wait/tail policy.
10. R4c CURRENT provenance/health.
11. R4d transactional SWAN L2/L3/L4 hotstart quarantine; WW3 restart untouched at this stage.
12. R8b complete marine stage instrumentation and adversarial mutations.
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

Update in the same repair round before deployment: marine code/changelog in its marine commit, API
model/tests in its API commit, dashboard/help in its repository commit, and ADR/manual/OpenAPI/plan
documents in coordinated meta commits:

- Provider Manual §§14.3/14.10/14.15/14.18: reconcile former automatic L1 side selection with the
  accepted WW3 automatic setup; document the OSM ocean `natural=coastline` versus Great Lakes/
  inland `natural=water` + `water=lake` layer contract, water-fraction-only semantics, regular
  bathymetry depth authority, no fallback, current composition, direct boundary, and exact-limit
  semantics.
- Operations Manual: setup generations/topology fingerprints, atomic rollback/bootstrap, recovery
  controller, cache retention, guard, artifacts, OSM snapshot/hash/cache lifecycle, Overpass failure
  and offline behavior, ODbL attribution/notice, and health interpretation.
- API Manual §17–19 and OpenAPI: nullable group fields and existing model-status semantics.
- API/Operations manuals and operator help: unified health schema, reducer, reason codes, stage
  ownership, transport-versus-model freshness, and optional CheckMK status.
- ADR-101: κ=1 exact-limit/null ruling.
- ADR-100 + ADR-109: explicitly reconcile automatic geography consumption against S/W-only rows;
  record selected O/H/D policies, D15's OSM-only/regular-depth contract, initialization and artifact
  dependency/rollback; remove CRM mixed-datum/fine-depth authority. ADR-109 also records horizon
  safety/shared artifact and, later, worker lifecycle.
- Marine Model Evolution Plan W3/W4 and Q4/PW7: annotate the accepted successor decision; do not
  leave the historical S/W/CLOSED design readable as current authority.
- Root Architecture marine configuration/chain section: state that configuration-time automatic
  geography is the sole boundary-setup authority and that OSM supplies horizontal occupancy only;
  no Huntington/cardinal/provider fallback rule. This is required even though service placement is
  unchanged.
- Config/operator help and API pass-through documentation: explain automatic regime-correct OSM
  layer selection, no source selector knob, setup refusal/action, derivation identity and datum-
  converted bathymetry authority. Add no public field unless separately approved.
- Marine changelog and licensing/third-party notices: source URL/layer semantics, ODbL attribution,
  snapshot/version/hash behavior, and removal of the CRM/fine-depth mixed-datum path.
- ADR-104 or successor: WCOFS same-model valid-time composition/tail policy.
- Marine/API changelogs and tests/comments with stale 24-hour terminology.
- Root `ARCHITECTURE.md` additionally changes for §8A's automatic-setup authority as listed above;
  D9 still controls any later service/process placement change.

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

The operator's 2026-08-30 approval activates D14's A0 manual/source inventory, results-free gate
lock and non-production prototypes only. D15 fixes the sole-provider/source-separation direction,
but A1 remains unauthorized until G evidence confirms it and the operator selects O/H/D, artifact/
rollback and initialization. R1/R2 stop until that complete later ruling. A failed
cold-start KAT, missing authoritative revision source, or need for a new health/recovery artifact
remains a stop-and-surface event, not implied permission to expand the design.

---

## 24. Acceptance checklist

- [x] Operator accepts §23's approval boundary and this plan — 2026-08-29.
- [x] Old forward plan archived; redirect installed — 2026-08-29.
- [x] Original recovery results-free gates written and Sol-audited before original implementation — 2026-08-29.
- [x] Operator approves §8A A0 evidence/prototype round — 2026-08-30.
- [x] Operator selects D15 OSM-only occupancy + regular datum-converted bathymetry depth direction — 2026-08-30.
- [ ] A0 results-free gate/fixture file is locked and independently Sol-audited before prototype results.
- [ ] A0 completes and operator selects O/H/D, dependency/rollback and initialization/bootstrap and confirms D15-G.
- [ ] Operator accepts D14 implementation scope before any automatic-setup code lands.
- [ ] A1 is implemented, documented, Sol-audited, atomically rollback-gated and live-verified.
- [ ] R1–R11 individually implemented, audited, documented, and live-gated.
- [ ] R12 four-anchor/reality/health gate passes.
- [ ] No untracked deferred item remains in narrative prose.
- [ ] Coordinator walks the original operator request line by line before close.
