# Surf Model Fix Plan — SwellTrack + SurfBeat Integration

**Status:** IN PROGRESS — Phases 0-2 COMPLETE, Phase 3 next
**Created:** 2026-07-21
**Last updated:** 2026-07-21 (session 1 — Phases 0-2 executed with QC gates passed)
**Origin:** 1D-MODEL-BENCHMARK-BRIEF Round 2 results. The benchmark confirmed Architecture 2-prime (SwellTrack per-transect + SurfBeat strip for IG), but the deployed code has gaps: no SurfBeat integration, friction not enabled, approach-zone Hs overestimate, missing IG display, wrong attribution, deferred adversarial audits from Phases 2-4, and the spot isn't configured for the new pipeline.

**Governing brief:** `docs/planning/briefs/1D-MODEL-BENCHMARK-BRIEF.md` Part 8 (results) and Part 9 (model→display mapping, blended architecture, compute offloading).

**NO DEFERRAL RULE:** Every task in every phase must be completed and verified before the QC gate closes. "Deferred to v2", "batched with later audit", and "blocked on X" are not acceptable outcomes. If a task cannot be completed, the phase fails and work stops until the blocker is resolved. This rule exists because the SURF-1D-IMPLEMENTATION-PLAN deferred adversarial audits for Phases 2, 3, and 4 — exactly the quality gate that would have caught the issues this plan remediates.

---

## 0. Orientation

### 0.1 Execution context

Same SSH rules, deploy scripts, and filesystem permissions as CLAUDE.md. Additionally:

- **weewx container:** API server, SWAN production, MariaDB, Redis. SwellTrack currently runs in-process here.
- **librewxr container:** 6 GB RAM, 16 cores. Benchmark host. Target for compute offloading.
- **weather-dev container:** Dashboard, config UI, Caddy proxy.

### 0.2 Current state (from SURF-1D-IMPLEMENTATION-PLAN execution progress)

| Component | State | Issue |
|---|---|---|
| SwellTrack model code | Deployed (`surf_1d_analytical.py`) | Named "analytical 1D", friction optional (default off), no marketing name in code or docs |
| SwellTrack pipeline | Deployed (`surf_1d_pipeline.py`) | Works but runs in-process on weewx; friction not enabled by default |
| SurfBeat strip | Benchmark prototype only (`surfbeat_strip_benchmark.py`) | Not integrated into production pipeline |
| Beach profile API | Deployed (`beach_profile.py`) | Uses SwellTrack Hs for entire profile including approach zone (24% overestimate vs SWAN) |
| Dashboard surf page | Deployed (Phases 5-7 complete) | No IG/set-timing display; attribution says "SWAN" not "SWAN + SwellTrack"; new fields render as "—" |
| Wizard/Admin | Segment UI deployed (Phase 2) | No SurfBeat toggle, no compute host config, no friction coefficient setting |
| HB Pier config | Needs reconfiguration | transectCount=1, openTransectCount=0 — segment not set via wizard yet |
| DWR SPECOUT | Not yet produced | Next SWAN cycle will generate; spot needs segment config first |
| Adversarial audits | Phases 2, 3, 4 DEFERRED | Never executed — this plan remediates |
| Phase 8 validation | T8.1 (SWASH) blocked, T8.3-T8.6 deferred | SWASH ruled out; webcam validation replaced by Surfline comparison |

### 0.3 Agent assignments

| Role | Model | Responsibility |
|---|---|---|
| **Coordinator** | Opus | Architecture, agent briefs, QC gates, doc updates, SWAN syntax, research |
| **clearskies-api-dev** | Sonnet | API code: SwellTrack core, SurfBeat runner, compute service, pipeline fixes |
| **clearskies-dashboard-dev** | Sonnet | Dashboard: IG display, attribution, blended profile chart |
| **clearskies-docs-author** | Sonnet | Wizard/admin: SurfBeat toggle, compute host, friction config |
| **clearskies-test-author** | Sonnet | Tests: SwellTrack unit tests, SurfBeat integration tests, compute service tests |
| **clearskies-auditor** | Sonnet | Adversarial audit per phase (MANDATORY — no deferral) |

### 0.4 SWAN syntax reference (MANDATORY — no INPUT generation without verification)

**RULE:** No agent writes SWAN INPUT generation code without first reading `docs/reference/swan-commands-extract.md`. Every SWAN command emitted must match the verified syntax in that file. This rule exists because Round 1 of the benchmark had SURFBEAT syntax errors (COMPUTE STAT without timestamp, OBSTACLE RDIFF without POWN) that produced silent errors in SWAN's PRINT file.

**Verified SurfBeat strip syntax (from benchmark, confirmed against SWAN 41.51AB source):**

```
PROJECT 'SBstrip' '001'
$
SET 0. 90. 0.05 200 3
SET NAUTICAL
COORDINATES CARTESIAN
$
MODE STATIONARY
$
$ Grid: x = cross-shore (west=offshore, east=shore), 0° = east
$ ~2500m at dx=5m, 20 rows at dy=25m
CGRID REG 0.0 0.0 0. 2495.0 500.0 499 20 CIRCLE 36 0.004 1.0 60
$
$ Bottom: same grid, depths positive = below water
INPGRID BOTTOM REG 0.0 0.0 0. 499 20 5.0 25.0
READINP BOTTOM 1. 'BOTTOM.txt' 3 0 FREE
$
$ Boundary: west side only (SURFBEAT requirement)
$ Option 1 — parametric (benchmark): BOUND SIDE WEST CCW CONstant PAR [hs] [tp] [dir] [spread]
$ Option 2 — from L2 SPECOUT (production): requires BOUNDSPEC syntax (T2.1 must verify)
BOUND SIDE WEST CCW CONstant PAR [hs] [tp] [dir] [spread]
$
$ Physics
GEN3 WESTHUYSEN
BREAKING CONSTANT 1.0 0.73
FRICTION JON [cfjon]
TRIAD
$
QUANTITY HSIGN TM01 DIR excv=-9.
$
$ Shoreline: OBSTACLE on east side, total blocking + IG reflection
$ REFL [reflc] RDIFF [pown] — POWN is REQUIRED, omitting causes severe error
OBSTACLE TRANSM 0.0 REFL 0.5 RDIFF 2 LINE [x_east] 0.0 [x_east] [ylenc]
$
$ SURFBEAT: two COMPUTEs, bare COMPUTE (no STAT keyword, no timestamp)
SURFBEAT
$
$ Output stations along centerline
POINTS 'S00' [x] [y_center]
SPECOUT 'S00' SPEC2D ABS 'SPEC_S00.txt'
TABLE 'S00' HEAD 'TABLE_S00.txt' HSIGN HSWELL TM01 DIR DEPTH QB
$
$ Two COMPUTEs: first = sea-swell + bound IG, second = reflected free IG
$ MUST be bare COMPUTE — "COMPUTE STAT" triggers "Illegal keyword: STAT"
COMPUTE
COMPUTE
$
STOP
```

**Known SWAN pitfalls (from benchmark):**
- `COMPUTE STAT` without a timestamp → "Illegal keyword: STAT". Use bare `COMPUTE` for stationary.
- `OBSTACLE ... RDIFF` without `[pown]` → "Severe error: No value for variable POWN". Always include the power argument (e.g., `RDIFF 2`).
- `GEN3 WESTHUYSEN` without wind → "Error: It is not recommended to use quadruplets in combination with zero wind conditions." This is a SWAN warning, not fatal — computation proceeds. Acceptable for the strip benchmark.
- SPECOUT values are integer-scaled: actual density = integer × FACTOR line. Parser MUST apply the FACTOR.
- SURFBEAT requires: regular 2D grid (not 1D, not curvilinear), stationary mode, west boundary only.
- BOTTOM.txt layout for `idla=3`: row 0 = south, last row = north; columns west → east. Points = meshes + 1.

**For existing SWAN production commands** (CURVE, TABLE, SPECOUT, POINTS, OBSTACLE, BOUNDNEST1, etc.): the verified syntax is in `docs/reference/swan-commands-extract.md`. Agents MUST read that file before writing or modifying any SWAN INPUT generation code.

### 0.5 Test baselines (must not regress)

| Suite | Baseline | Command |
|---|---|---|
| API pytest | Check before Phase 1 | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |
| Dashboard vitest | Check before Phase 4 | `ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --reporter=verbose 2>&1 \| tail -5"` |

---

## Phase 0 — Governing Document Updates

**Purpose:** Update all ADRs, manuals, and architecture docs to reflect SwellTrack naming, SurfBeat integration, compute offloading, and blended architecture BEFORE any code changes. Agents read docs before coding — stale docs produce wrong code.

**All Phase 0 work is Coordinator (Opus) direct.**

### T0.1 — Update ARCHITECTURE.md

- File: `docs/ARCHITECTURE.md`

**Updates:**
1. SWAN section: add SwellTrack as a named model ("SwellTrack — proprietary analytical 1D cross-shore wave transformation model")
2. Add SurfBeat strip as a SWAN run type (stationary, 2D strip, 3-hour cadence, IG output)
3. Add compute offloading architecture: API on weewx calls compute service on librewxr; fallback to in-process
4. Document the blended Hs profile: SurfBeat strip for approach zone, SwellTrack for surf zone
5. Update pipeline diagram: L1→L2→(L3 optional)→SPECOUT→SwellTrack (hourly) + SurfBeat strip (3-hourly)
6. Attribution: "SWAN + SwellTrack"

### T0.2 — Amend ADR-093 (nearshore model)

- File: `docs/decisions/ADR-093-swan-trushore-nearshore-model.md`

**Amendments:**
1. Name the 1D model "SwellTrack" — replace all "analytical 1D" references
2. Add SurfBeat strip as a complementary model for IG energy
3. Document the decision that SWASH and XBeach are fully ruled out (production, LUT, and referee)
4. Add compute offloading as an architectural option (operator-configurable `surf_compute_host`)

### T0.3 — Update API-MANUAL §17

- File: `docs/manuals/API-MANUAL.md`

**Updates:**
1. Name the model "SwellTrack" in the surf endpoint documentation
2. Add SurfBeat-derived response fields: `setTimingMinutes`, `setAmplitudeM`, `igWaveHeightM`
3. Document `friction_coefficient` as an operator-configurable parameter (default 0.038 swell, 0.067 windsea)
4. Document `surf_compute_host` config key
5. Document `surfbeat_enabled` and `surfbeat_cadence_hours` config keys
6. Document blended beach profile: approach zone from SurfBeat strip, surf zone from SwellTrack
7. Update attribution field: `nearshoreModel: "SWAN + SwellTrack"`
8. Remove all references to SWASH ground truth and webcam validation
9. Replace validation method: "comparison against competing surf forecasts (Surfline, BSR)"

### T0.4 — Update PROVIDER-MANUAL §14

- File: `docs/manuals/PROVIDER-MANUAL.md`

**Updates:**
1. Add SurfBeat strip as a SWAN run type with its own INPUT generation pattern
2. Document the strip's SURFBEAT command syntax (reference `docs/reference/swan-commands-extract.md`)
3. Document the 3-hour cadence and stationary two-COMPUTE procedure
4. Document friction coefficient per condition type (0.038 swell, 0.067 windsea)

### T0.5 — Update OPERATIONS-MANUAL

- File: `docs/manuals/OPERATIONS-MANUAL.md`

**Updates:**
1. Add `surf_compute_host` to config reference (URL of compute service, null = in-process)
2. Add `surfbeat_enabled` and `surfbeat_cadence_hours` to per-spot config
3. Add `friction_coefficient` to per-spot config (advanced, hidden by default)
4. Document librewxr compute service setup (how to deploy, health check, fallback behavior)
5. Update wizard marine step docs for SurfBeat toggle

### T0.6 — Update DASHBOARD-MANUAL

- File: `docs/manuals/DASHBOARD-MANUAL.md`

**Updates:**
1. Add set/lull timing display to surf page card layout
2. Document attribution line change: "SWAN + SwellTrack"
3. Document 72h forecast row for set timing (3-hourly resolution, carry-forward between runs — NOT interpolated)

### T0.7 — Update SURF-1D-IMPLEMENTATION-PLAN

- File: `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md`

**Updates per brief §9.5:** Apply all 9 fixes:
1. Replace "analytical 1D model" / "Option A" → "SwellTrack" throughout
2. Add SurfBeat cadence: every 3 hours (24 runs, carry-forward)
3. Add compute location: librewxr via `surf_compute_host` config
4. Add blended Hs: SurfBeat strip for approach zone, SwellTrack for surf zone
5. Phase 8 T8.1: Remove SWASH ground truth — SWASH ruled out entirely
6. Phase 8 T8.4: Change "webcam/surf-report comparison" → "comparison against Surfline"
7. Friction: always on in production (cfjon=0.038 swell default)
8. IG display: SurfBeat set/lull timing feeds Card 3 and 72h forecast
9. Attribution: "SWAN + SwellTrack"

### Adversarial Audit — Phase 0

- Owner: `clearskies-auditor`

**Scope:**
1. Every doc updated in T0.1-T0.6 — verify "SwellTrack" appears where the model is named, not "analytical 1D" or "Option A"
2. No SWASH references remain in any acceptance criteria or validation tasks
3. No webcam references remain — all validation references say "Surfline comparison" or "competing forecast comparison"
4. All new config keys (`surf_compute_host`, `surfbeat_enabled`, `surfbeat_cadence_hours`, `friction_coefficient`) documented in OPERATIONS-MANUAL
5. SurfBeat strip documented in PROVIDER-MANUAL with correct SURFBEAT syntax

### QC Gate 0 — PASSED (2026-07-21)

- All 6 documents updated ✓
- "SwellTrack" naming consistent across all docs ✓
- No SWASH or webcam references in acceptance criteria ✓ (4 findings remediated — SWASH in T8.1, webcam in T8.3-T8.5, "Option A" in §0.2, stale nearshoreModel in API-MANUAL)
- All new config keys documented ✓
- Auditor: 4 findings, all remediated ✓
- Additional cleanup: TruShore→SwellTrack in openapi-v1.yaml, INDEX.md

**Commits:** dcb7203 (meta repo)

---

## Phase 1 — SwellTrack Core Fixes

**Purpose:** Rename the model, enable friction by default, fix the pipeline to use the correct friction coefficient per condition.

### T1.1 — Rename analytical model to SwellTrack

- Owner: `clearskies-api-dev`
- Files: `surf_1d_analytical.py`, `surf_1d_pipeline.py`, `surf.py`, `beach_profile.py`, all referencing modules

**Do:**
1. Rename module docstrings: "Analytical 1D cross-shore wave transformation model" → "SwellTrack — cross-shore wave transformation model"
2. Rename the CLI entry point: `python -m weewx_clearskies_api.services.surf_1d_analytical` stays (file rename is optional — internal, not user-facing)
3. Add `MODEL_NAME = "SwellTrack"` constant to `surf_1d_analytical.py`
4. Update log messages to use "SwellTrack" instead of "analytical" or "1D model"

**Accept:** All log output and docstrings reference "SwellTrack". No code behavior changes.

### T1.2 — Enable friction by default

- Owner: `clearskies-api-dev`
- Files: `surf_1d_pipeline.py`, `config/marine_config.py`

**Do:**
1. Add `friction_coefficient: float = 0.038` to `SurfSpotConfig` in `marine_config.py`
2. In `surf_1d_pipeline.py`, pass `cfjon=config.friction_coefficient` to every `run_1d_analytical()` call
3. The pipeline currently calls `run_1d_analytical()` with no `cfjon` (defaults to None = frictionless). Change this to always pass the configured friction coefficient.
4. The bottom friction implementation from T7-3 of the benchmark (cumulative exponential attenuation) is already in `surf_1d_analytical.py` — this task wires it into production.

**Accept:**
- Default config: `friction_coefficient=0.038` (swell)
- Pipeline passes friction to SwellTrack on every run
- Verify: Hs at 500m from shore is ~25% lower than without friction for a 14s swell (matches benchmark §8.4)

### T1.3 — Update attribution in surf endpoint

- Owner: `clearskies-api-dev`
- Files: `endpoints/surf.py`

**Do:**
1. Change `nearshoreModel` from `"swan"` to `"SWAN + SwellTrack"`
2. This is a string constant in the response envelope — one-line change

**Accept:** `GET /surf/{location_id}` returns `nearshoreModel: "SWAN + SwellTrack"`.

### T1.4 — Update NearshoreModelIndicator in dashboard

- Owner: `clearskies-dashboard-dev`
- Files: `SurfingTab.tsx` or wherever `NearshoreModelIndicator` renders

**Do:**
1. The indicator currently displays `nearshoreModel` from the API response. If it hardcodes "SWAN", change to use the API field. If it already reads the field, no change needed — T1.3 handles it.

**Accept:** Dashboard shows "Model: SWAN + SwellTrack" in the model indicator.

### Adversarial Audit — Phase 1

- Owner: `clearskies-auditor`

**Scope:**
1. Grep for "analytical" in all API Python files — should appear only in filename and internal function names, never in user-facing strings or log messages
2. Verify friction is actually applied: run the SwellTrack pipeline on the benchmark S1 condition (1.0m @ 14s, cfjon=0.038) and confirm Hs reduction matches benchmark Appendix A.2 (5.9% at 2000m, 25% at 500m)
3. Verify attribution: `GET /surf/{location_id}` returns `nearshoreModel: "SWAN + SwellTrack"`
4. Silent deferral scan: grep for `pass`, `TODO`, `FIXME`, `None` default on `cfjon` in pipeline code

### QC Gate 1 — PASSED (2026-07-21)

- SwellTrack naming in all user-facing output ✓ (MODEL_NAME constant, docstrings, log messages, CLI help)
- Friction enabled by default (0.038) ✓ (friction_coefficient in SurfSpotConfig, wired through pipeline + both endpoints)
- Attribution reads "SWAN + SwellTrack" in API and dashboard ✓ (API nearshoreModel field, dashboard reads dynamically)
- Auditor: 3 findings (0H, 1M, 2L), all remediated ✓ (CLI help string, _build_transect_profile missing cfjon, stale docstring)

**Commits:** 02331df (API repo)

---

## Phase 2 — SurfBeat Strip Integration

**Purpose:** Integrate the SurfBeat strip (benchmark prototype) into the production pipeline. Run at 3-hour intervals. Parse IG output. Wire into the surf endpoint response.

### T2.1 — SurfBeat strip runner

- Owner: `clearskies-api-dev`
- Files: new `services/surfbeat_runner.py`, `services/surfbeat_strip_benchmark.py` (refactor from benchmark prototype)

**Reading list (MANDATORY — read before writing any code):**
1. `docs/reference/swan-commands-extract.md` — verified SWAN syntax, SURFBEAT section
2. §0.4 of this plan — verified SurfBeat strip INPUT template and known pitfalls
3. `1D-MODEL-BENCHMARK-BRIEF.md` Part 7 §7.3 — strip configuration specification
4. Existing `surfbeat_strip_benchmark.py` — the benchmark prototype to refactor from

**Do:**
1. Extract the INPUT generator from `surfbeat_strip_benchmark.py` into a production-grade module `surfbeat_runner.py`
2. Accept: spot config (profile, SPECOUT spectrum, friction coefficient), cadence (3-hour default)
3. Generate INPUT + BOTTOM.txt in a working directory under `/var/run/weewx-clearskies/swan/surfbeat_{spot_id}/`
4. Run SWAN as a subprocess (same pattern as `swan_runner.py`)
5. Parse TABLE output at all stations for Hs_sw
6. Parse SPECOUT at nearshore stations for IG band integration (f < 0.04 Hz → Hs_ig)
7. Extract IG spectral peak period → set timing estimate
8. Return: `SurfBeatResult` with `hs_ig_shoreline`, `set_timing_minutes`, `hs_sw_profile` (for approach-zone blend)
9. Handle the two-COMPUTE procedure (both COMPUTEs in sequence, final results come AFTER the second COMPUTE — it adds reflected free IG, which is the whole point of the shoreline OBSTACLE)
10. Handle FACTOR scaling in SPECOUT parsing (integer values × FACTOR, as discovered in the benchmark)
11. **Boundary condition:** For the benchmark, parametric JONSWAP (`BOUND SIDE WEST CCW CONstant PAR`) is sufficient. For production, the runner must accept the actual L2 SPECOUT spectrum as the boundary. This requires verifying the `BOUNDSPEC` or `BOUND SEGMENT` syntax from the installed SWAN manual — extract into `swan-commands-extract.md` before implementing. If BOUNDSPEC is too complex for v1, decompose the L2 SPECOUT into bulk parameters (Hs, Tp, Dir, spread) and use parametric input — a minor accuracy loss but operationally safe.
12. **Representative profile selection:** The strip uses one profile for the entire spot. Use the median depth profile across all open transects (compute pointwise median depth at each cross-shore distance). This is more robust than picking one transect arbitrarily.

**Accept:**
- SurfBeat strip runs for HB Pier S1 condition and returns `hs_ig_shoreline ≈ 0.155m` (matching benchmark §8.6)
- Set timing estimate produced from IG spectral peak
- Runtime ~28s per run (matching benchmark)
- Working directory cleaned up after successful parse

### T2.2 — Wire SurfBeat into forecast pipeline

- Owner: `clearskies-api-dev`
- Files: `endpoints/surf.py`, `services/surf_1d_pipeline.py`

**Do:**
1. Add `surfbeat_enabled` and `surfbeat_cadence_hours` to `SurfSpotConfig`
2. In the forecast pipeline, for every Nth forecast hour (where N = `surfbeat_cadence_hours`, default 3):
   - Extract the L2 SPECOUT for that timestep
   - Run the SurfBeat strip
   - Store the IG results
3. For intermediate hours: carry forward the nearest SurfBeat result (not interpolated — the user rejected interpolation)
4. Add SurfBeat results to the surf endpoint response: `setTimingMinutes`, `setAmplitudeM` (= Hs_ig in display units), `igWaveHeightM`
5. When `surfbeat_enabled=false` or strip fails: these fields are null in the response

**Accept:**
- SurfBeat runs at 3-hour intervals (hours 0, 3, 6, ..., 69, 72 = 25 runs)
- Intermediate hours carry forward the last SurfBeat result
- Response includes IG fields when SurfBeat is enabled
- Response IG fields are null when disabled or failed (not error, not omitted)

### T2.3 — SurfBeat approach-zone Hs for blended profile

- Owner: `clearskies-api-dev`
- Files: `endpoints/beach_profile.py`, `services/surf_1d_pipeline.py`

**Do:**
1. T2.1's strip TABLE output must have stations at ≤25m spacing along the centerline (every 5th grid cell). This ensures a station exists within 25m of any SwellTrack break point.
2. Store the strip Hs_sw profile alongside the SwellTrack Hs profile in the pipeline result
3. In `beach_profile.py`, implement the blend with a **50m linear taper** centered on the break point:
   - Offshore of (break_point + 25m): 100% SurfBeat strip Hs
   - Between (break_point + 25m) and (break_point - 25m): linear ramp from SurfBeat to SwellTrack
   - Shoreward of (break_point - 25m): 100% SwellTrack Hs
   - The taper eliminates the step discontinuity (SurfBeat ~0.72m vs SwellTrack ~0.91m at 500m from shore = 26% gap → ramped over 50m)
4. When SurfBeat is unavailable: use SwellTrack Hs for the entire profile (current behavior, no blend)

**Accept:**
- Beach profile chart shows lower Hs in the approach zone
- Maximum step at any point in the blended profile < 5% of local Hs (measurable criterion — audit checks this)
- Blend only affects the display profile — face height, scoring, break points still come from SwellTrack

### Adversarial Audit — Phase 2

- Owner: `clearskies-auditor`

**Scope:**
1. SurfBeat runner: verify the two-COMPUTE procedure executes (check PRINT file for "Surfbeat (bound)" and "Surfbeat (reflected)" lines)
2. SPECOUT parsing: verify FACTOR multiplication is applied (raw integer values × FACTOR, not raw integers treated as m²/Hz/deg)
3. IG band separation: verify f_split = 0.04 Hz, Hs_ig integrates ONLY below 0.04 Hz
4. Cadence: verify strip runs at hours 0, 3, 6, ..., 72 (24 runs), NOT every hour
5. Carry-forward: verify intermediate hours get the PREVIOUS SurfBeat result (not null, not interpolated)
6. Blend: verify approach-zone Hs uses SurfBeat data, not SwellTrack; verify transition at break point
7. Silent deferral scan: grep for `pass`, `TODO`, hardcoded return values in surfbeat_runner.py

### QC Gate 2 — PASSED (2026-07-21)

**Note:** QC Gate 2 accepts synthetic SPECOUT verification (benchmark S1 condition). Real L2 SPECOUT requires HB Pier segment reconfiguration (Phase 5 T5.3) and a SWAN cycle (Phase 6 T6.3). End-to-end verification with real data happens at QC Gate 6.

- SurfBeat strip runner implemented (945 lines, commit d2f0a40) ✓
  - Two-COMPUTE enforcement, FACTOR parsing, IG integration at f<0.04 Hz
  - Hs_ig formula corrected to 4·sqrt(m0) per WMO standard (audit F3)
- 3-hour cadence enforced (range(0, 73, 3) = 25 runs) ✓
- IG fields in surf response populated when enabled, null when disabled ✓
  - setTimingMinutes, setAmplitudeM, igWaveHeightM — unit-converted (audit F2)
  - Carry-forward: largest cadence hour ≤ current elapsed hour (not interpolated) ✓
- Blended beach profile uses SurfBeat approach Hs + SwellTrack surf Hs ✓
  - 50m linear taper via _blend_hs_profiles() with numpy.interp alignment
  - Wired through module-level surfbeat result cache (audit F1)
- Auditor: 4 findings (1H, 2M, 1L), all remediated ✓

**Commits:** d2f0a40 (T2.1), d4baa59 (T2.3), 7224f8a (T2.2), 87ae42e (audit fixes) — all in API repo

---

## Phase 3 — Compute Offloading to librewxr

**Purpose:** Move SwellTrack and SurfBeat computation off the weewx API server to the librewxr container. Operator-configurable, not hardcoded.

### T3.1 — Compute service on librewxr

- Owner: `clearskies-api-dev`
- Files: new `services/compute_service.py` (lightweight FastAPI app for librewxr)

**Do:**
1. Build a lightweight HTTP service with two endpoints:
   - `POST /compute/swelltrack` — accepts one timestep's SPECOUT data + transect profiles + config → returns SwellTrack results for that timestep (all transects × partitions). Expected latency: < 500ms.
   - `POST /compute/surfbeat` — accepts one timestep's SPECOUT data + representative profile + config → runs one SurfBeat strip and returns IG results. Expected latency: ~30s.
   - `GET /health` — health check
2. Per-timestep granularity avoids the timeout problem: each request is bounded (SwellTrack < 1s, SurfBeat ~30s), not the full 72-timestep suite.
3. The API on weewx calls these endpoints in a loop over timesteps, accumulating results.
4. Runs on librewxr, listens on a configurable port (default 8770)
5. Requires SWAN binary on librewxr (already installed from benchmark)
6. **Authentication:** Same pattern as wizard→API trust exchange (ADR-038). Shared secret stored in `secrets.env` on both weewx (`SURF_COMPUTE_SECRET`) and librewxr. API sends the secret as `Authorization: Bearer {token}` with every request. Compute service rejects requests without a valid token (401). The secret is generated once during setup (T3.3) and stored — not hardcoded, not transmitted in config files.
7. **TLS:** Use TLS between weewx and librewxr. The compute service generates a self-signed cert on first start (same pattern as the API's TLS setup). The API's `surf_compute_host` config accepts `https://` URLs and validates the cert fingerprint. For same-VLAN deployment, the operator can set `surf_compute_verify_tls=false` in `api.conf` to skip cert verification — but TLS encryption is always on when the URL is `https://`.
8. **Bind address:** Compute service binds to `0.0.0.0` by default (reachable from weewx across the VLAN bridge). Operator can restrict to a specific interface via config.

**Accept:**
- Service starts on librewxr and responds to health check
- `POST /compute/surf` with benchmark S1 inputs returns results matching in-process computation
- Runtime comparable to in-process (network overhead < 1s)

### T3.2 — API client for compute service

- Owner: `clearskies-api-dev`
- Files: `services/surf_1d_pipeline.py`, `config/marine_config.py`

**Do:**
1. Add to marine config (loaded from `api.conf`):
   - `surf_compute_host: str | None = None` — URL of compute service (e.g., `https://librewxr.shaneburkhardt.com:8770`)
   - `surf_compute_verify_tls: bool = True` — verify TLS cert (set `false` for self-signed on same VLAN)
2. Load `SURF_COMPUTE_SECRET` from `secrets.env` on weewx (same pattern as DB password, proxy secret)
3. When `surf_compute_host` is set: serialize inputs, POST to the compute service with `Authorization: Bearer {secret}`, deserialize results
4. When `surf_compute_host` is null: run in-process (current behavior, no change)
5. When compute service is unreachable or returns 401/5xx: log warning, fall back to in-process, set `degraded=true` in response
6. Timeout: 60 seconds for `/compute/swelltrack` (expected < 500ms), 120 seconds for `/compute/surfbeat` (expected ~30s)

**Accept:**
- With `surf_compute_host=http://librewxr:8770`: computation runs on librewxr
- With `surf_compute_host=null`: computation runs in-process on weewx (no regression)
- With unreachable compute host: graceful fallback to in-process + warning log

### T3.3 — Deploy compute service to librewxr

- Owner: Coordinator (Opus) — with user approval before any SSH commands to librewxr

**Do:**
1. Establish SSH access to librewxr: add `Host librewxr` entry to `.local/ssh/config` (same pattern as weewx/weather-dev). Verify connectivity.
2. Create a deploy script `scripts/deploy-compute.sh` (same pattern as `deploy-api.sh` — pull code, restart service, health check). No manual `git pull` or `chown` on containers.
3. Install the compute service on librewxr via the deploy script. Set up systemd unit.
4. Verify SWAN binary on librewxr (`/usr/local/bin/swan` — already present from benchmark)
5. **Generate shared secret:** `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` → store in `secrets.env` on BOTH weewx and librewxr as `SURF_COMPUTE_SECRET=<token>`
6. **TLS setup:** Compute service generates self-signed cert on first start (store in `/etc/weewx-clearskies/compute/`). Record the cert fingerprint.
7. Configure `api.conf` on weewx:
   - `surf_compute_host = https://librewxr.shaneburkhardt.com:8770`
   - `surf_compute_verify_tls = false` (self-signed cert on same VLAN)
8. Verify end-to-end: API on weewx → authenticated TLS request → compute service on librewxr → results back
9. Verify auth rejection: request without Bearer token → 401

**Accept:**
- Compute service running on librewxr behind TLS
- API on weewx authenticates and successfully offloads to librewxr
- Unauthenticated requests rejected with 401
- Health check passes
- Deploy script works for future updates

### Adversarial Audit — Phase 3

- Owner: `clearskies-auditor`

**Scope:**
1. Config: verify `surf_compute_host` is loaded from `api.conf`, not hardcoded
2. Fallback: kill the compute service, verify API falls back to in-process with degraded=true
3. **Auth enforcement:** send a request WITHOUT the Bearer token → must get 401. Send a request with a WRONG token → must get 401. Only the correct `SURF_COMPUTE_SECRET` produces 200.
4. **TLS enforcement:** verify the service listens on HTTPS, not HTTP. Verify a plain HTTP request to the HTTPS port is rejected.
5. **Secret storage:** verify `SURF_COMPUTE_SECRET` is in `secrets.env` on both hosts, NOT in `api.conf`, NOT in source code, NOT in any committed file
6. **Endpoint surface:** verify compute service exposes only `/compute/swelltrack`, `/compute/surfbeat`, and `/health` — no other routes
7. Input validation: verify compute service rejects malformed inputs (missing fields, negative depths, etc.)
8. Silent deferral scan on compute_service.py and the client code

### QC Gate 3

- Compute offloads to librewxr when configured
- Falls back to in-process when unconfigured or unreachable
- No hardcoded host — entirely operator-configurable
- **Auth: unauthenticated and wrong-token requests rejected (401)**
- **TLS: service listens HTTPS only**
- **Secret in secrets.env only — not in source, not in api.conf**
- Auditor: zero findings

---

## Phase 4 — Dashboard IG Display & Polish

**Purpose:** Wire the SurfBeat IG output into the dashboard surf page. Update attribution.

### T4.1 — Set/lull timing display on Card 3

- Owner: `clearskies-dashboard-dev`
- Files: `SurfingTab.tsx`, translation files (13 locales)

**Do:**
1. Add set timing to Card 3 (Conditions at Break): "Sets every ~{N} min" with the `setTimingMinutes` field
2. Add set amplitude: "Sets ~{N}ft bigger" with `setAmplitudeM` converted to display units
3. When SurfBeat fields are null (disabled or unavailable): hide the set timing section entirely (not "—")
4. i18n: add keys for "Sets every", "bigger", etc. in all 13 locales

**Accept:**
- Set timing displays when SurfBeat data is present
- Hidden (not "—") when absent
- Units match operator preference

### T4.2 — Set timing in 72h forecast scroll

- Owner: `clearskies-dashboard-dev`
- Files: `SurfingTab.tsx`, translation files

**Do:**
1. Add a "Set Timing" row to the 72h forecast scroll
2. Shows `setTimingMinutes` at each timestep
3. At 3-hour cadence, intermediate hours show the carried-forward value (visually identical — no "estimated" marker needed since the carry-forward is a design decision, not missing data)

**Accept:**
- Set timing row appears in 72h scroll
- Values present at every hour (carried forward between SurfBeat runs)

### T4.3 — Blended Hs on beach profile chart

- Owner: `clearskies-dashboard-dev`
- Files: `BeachProfileChart.tsx`

**Do:**
1. The beach profile API (T2.3) returns both SwellTrack Hs and blended Hs profiles
2. The chart renders the blended profile (lower approach-zone Hs from SurfBeat, detailed surf-zone Hs from SwellTrack)
3. If only SwellTrack Hs is available (SurfBeat disabled): render SwellTrack Hs for the whole profile (current behavior)

**Accept:**
- Approach zone shows physically reasonable Hs (~0.73m at 500m for S1, not ~0.91m)
- Transition at break point is smooth
- Chart looks the same as before when SurfBeat is disabled

### Adversarial Audit — Phase 4

- Owner: `clearskies-auditor`

**Scope:**
1. IG display: verify set timing is HIDDEN (not "—") when SurfBeat data is null
2. Attribution: verify "SWAN + SwellTrack" renders in the model indicator
3. Blended profile: verify the approach zone uses lower (SurfBeat) values, not higher (SwellTrack)
4. 72h scroll: verify set timing row has values at every hour, not gaps at non-SurfBeat hours
5. i18n: verify all new strings use `t()` — no hardcoded English
6. Accessibility: new elements have aria-labels, contrast meets AA

### QC Gate 4

- Set timing displays when available, hidden when not
- Attribution reads "SWAN + SwellTrack"
- Blended profile renders correctly
- Auditor: zero findings

---

## Phase 5 — Wizard/Admin Config Changes

**Purpose:** Add operator-facing configuration for SurfBeat, compute offloading, and friction.

### T5.1 — SurfBeat toggle in wizard

- Owner: `clearskies-docs-author`
- Files: `step_marine.html`, `routes.py`, translation files

**Do:**
1. Add a checkbox: "Enable set/lull timing (SurfBeat)" — default checked
2. Help text: "Adds set timing predictions showing how often bigger waves arrive. Increases compute time by ~12 minutes per forecast cycle."
3. When unchecked: `surfbeat_enabled=false` in apply payload
4. Add `surfbeat_cadence_hours` as a hidden/advanced field (default 3, visible only in admin)

**Accept:**
- Wizard shows SurfBeat toggle in surf activity section
- Apply payload includes `surfbeat_enabled` and `surfbeat_cadence_hours`

### T5.2 — Compute service provider config in wizard

- Owner: `clearskies-docs-author` + `clearskies-api-dev`
- Files: `step_providers.html` (provider step), `routes.py`, `endpoints/setup.py`, translation files

**Architecture:** The compute service is a backend provider the API consumes — same category as the NWS API, NDBC, CO-OPS, or the librewxr radar provider. The dashboard never sees it. All wave model results flow through the API's surf endpoint like they do today. The operator configures the compute service the same way they configure any other provider the API talks to.

**Do:**
1. Add a "Wave Modeling" provider sub-section to the wizard's **provider configuration step** (alongside forecast, alerts, AQI, radar providers). Fields:
   - **Compute host URL** — text input, placeholder `https://host:8770`. Help text: "URL of a remote wave modeling service. Offloads SwellTrack and SurfBeat computations to a more powerful machine. Leave blank to compute on the API host (works but slower on limited hardware)."
   - **Compute secret** — password input. Help text: "The authentication token generated when the compute service was first installed." Stored in `secrets.env` as `SURF_COMPUTE_SECRET` via the apply endpoint (same write path as DB password, proxy secret, and other provider API keys — API writes its own `secrets.env` per ADR-038).
   - **Test Connection** button — HTMX call to `POST /setup/providers/test-compute` which the API handles: makes an authenticated `GET /health` request to the compute service URL with the provided secret, returns `{ok: bool, version: str, error: str}`. Displayed inline, same UX pattern as other provider test buttons.
2. API endpoint `POST /setup/providers/test-compute` — accepts `{url, secret}`, makes the authenticated health check, returns result. This endpoint lives under `/setup/providers/` (provider namespace), not `/setup/marine/`.
3. On apply: URL goes to `api.conf` under `[providers]` section as `surf_compute_host`, secret goes to `secrets.env` as `SURF_COMPUTE_SECRET`.
4. If the operator leaves URL blank: no compute service, API runs models in-process. No secret needed. No error — this is a valid configuration for operators running on powerful hardware.

**Accept:**
- Compute service appears in the provider step alongside other providers
- "Test Connection" verifies the API can authenticate to the compute service
- Secret stored in `secrets.env`, not `api.conf`
- Blank URL = in-process computation (no error, no warning)
- Apply payload includes `surf_compute_host` and `surf_compute_secret`
- The dashboard is completely unaware of the compute service — it calls `/surf/{id}` as always

### T5.3 — Compute host and SurfBeat config in admin

- Owner: `clearskies-docs-author`
- Files: `admin/providers.html` (or `admin/marine.html` for per-spot settings), `admin/routes.py`

**Do:**
1. Add "Wave Modeling Service" to the admin **providers section** (same placement as wizard — it's a provider):
   - **Compute host URL** — editable, shows current value from `api.conf`
   - **Update Secret** — password input + save button (updates `secrets.env`, does NOT display the current secret — same pattern as updating DB password in admin)
   - **Test Connection** — same HTMX test as wizard (T5.2 endpoint)
   - **Connection status** — show last successful compute call timestamp (from API log/cache)
2. Add to admin **marine section** (per-spot settings):
   - `surfbeat_enabled` toggle
   - `surfbeat_cadence_hours` numeric input (default 3)
   - Friction coefficient as an advanced/collapsible field (default 0.038)

**Accept:**
- Compute host URL + secret management in admin providers section
- SurfBeat toggle + cadence + friction in admin marine section (per-spot)
- Test connection verifies auth
- All values persist through save and load

### T5.4 — Reconfigure HB Pier spot

- Owner: Coordinator (Opus)

**Do:**
1. Open the wizard and reconfigure HB Pier with the shoreline segment (south of pier, ~300m)
2. Verify transects render on the map
3. Enable SurfBeat in the marine step
4. Configure compute host in the provider step (librewxr URL + secret + test connection)
5. Apply and verify config persists: `surf_compute_host` in `api.conf` `[providers]`, `SURF_COMPUTE_SECRET` in `secrets.env`, `surfbeat_enabled` in per-spot config

**Accept:**
- HB Pier configured with segment, transectCount > 1, openTransectCount > 0
- SurfBeat enabled
- Compute host configured and test connection passes
- Secret in `secrets.env`, URL in `api.conf` `[providers]`

### Adversarial Audit — Phase 5

- Owner: `clearskies-auditor`

**Scope:**
1. **Provider placement:** verify compute service config is in the provider step (alongside NWS, NDBC, radar), NOT in the marine step or an infrastructure step
2. **Secret handling:** verify the compute secret goes to `secrets.env` via the apply endpoint (same path as DB password), NOT to `api.conf`, NOT visible in admin display
3. **Test connection:** verify it makes an authenticated request to the configured URL — not a hardcoded URL, not a localhost fallback
4. Wizard: verify SurfBeat toggle generates correct apply payload fields
5. Admin: verify compute host URL in providers section, SurfBeat toggle in marine section (correct separation — host is global, SurfBeat is per-spot)
6. Admin: verify friction coefficient validates (positive float, rejects zero and negative)
7. Config roundtrip: wizard save → api.conf + secrets.env → API reload → admin load → admin save → verify consistency
8. Silent deferral scan on wizard and admin routes

### QC Gate 5

- Compute service config in provider step (not marine step)
- Compute secret in secrets.env (not api.conf)
- Test connection authenticates before reporting success
- SurfBeat toggle works in wizard and admin
- Friction coefficient configurable in admin
- HB Pier reconfigured with segment, SurfBeat enabled, compute host configured
- Auditor: zero findings

---

## Phase 6 — Deployment & Activation

**Purpose:** Deploy everything, trigger a SWAN cycle, verify the full pipeline produces real surf data.

### T6.1 — Deploy API to weewx

- Owner: Coordinator (Opus) — via `scripts/deploy-api.sh`

**Do:**
1. Deploy the API with all Phase 1-3 changes
2. Verify health endpoint returns 200
3. Verify `GET /surf/huntington_beach_pier` returns a response (may be degraded until SWAN cycle runs)

### T6.2 — Deploy dashboard to weather-dev

- Owner: Coordinator (Opus) — via `scripts/redeploy-weather-dev.sh`

**Do:**
1. Deploy the dashboard with all Phase 4 changes
2. Verify the surf page loads
3. Verify attribution shows "SWAN + SwellTrack"

### T6.3 — Trigger SWAN cycle and verify SPECOUT

- Owner: Coordinator (Opus)

**Do:**
1. Trigger a SWAN forecast cycle (or wait for the next scheduled one)
2. Verify DWR SPECOUT files are produced in the L2 working directory
3. Verify the surf endpoint transitions from degraded=true to degraded=false
4. Verify face height, break points, peel angle, and breaker type populate in the response
5. Verify SurfBeat IG fields populate (if SurfBeat enabled and compute service available)

**Accept:**
- Full pipeline runs: SWAN → SPECOUT → SwellTrack → SurfBeat → response
- All fields populated, non-null, physically reasonable
- Dashboard renders the complete surf page with real data

### T6.4 — Surfline comparison (replaces webcam validation)

- Owner: Coordinator (Opus)

**Do:**
1. At the time of the SWAN cycle, check Surfline's reported surf height for HB Pier
2. Compare our face height against Surfline's reported height
3. Document the comparison: our value, Surfline's value, delta, conditions
4. Repeat for at least 3 different swell conditions over the following days/weeks

**Accept:**
- Face height within ±30% of Surfline's reported value for the first comparison (same-day as deployment)
- QC Gate 6 requires ≥1 comparison. T6.4 remains open as an ongoing task: ≥3 comparisons across different conditions must be documented in this plan's execution log within 14 days of deployment. If 3 conditions don't occur naturally in 14 days (flat spell), the clock extends until they do. This is the one exception to the no-deferral rule — it depends on weather, not work.

### Adversarial Audit — Phase 6

- Owner: `clearskies-auditor`

**Scope:**
1. End-to-end: verify API response has ALL expected fields populated (not null, not "—", not degraded)
2. Verify SurfBeat fields present when enabled
3. Verify beach profile blend is active (approach Hs < SwellTrack Hs)
4. Verify attribution in API response AND dashboard both say "SWAN + SwellTrack"
5. Verify friction is applied (Hs at 500m from shore < Hs at boundary)

### QC Gate 6

- Full pipeline operational with real SWAN data
- All surf endpoint fields populated
- SurfBeat IG fields present
- Dashboard renders complete surf page
- Surfline comparison documented for ≥1 condition (more to follow)
- Auditor: zero findings

---

## Phase 7 — Retroactive Adversarial Audit & Final QA

**Purpose:** The SURF-1D-IMPLEMENTATION-PLAN deferred adversarial audits for Phases 2, 3, and 4. This phase executes those deferred audits plus a comprehensive final QA pass. No findings may be deferred.

### T7.1 — Retroactive audit: Phase 2 (measurement zone)

- Owner: `clearskies-auditor`

**Scope (from original SURF-1D-IMPLEMENTATION-PLAN Phase 2 audit):**
1. Silent deferral scan: grep for `pass`, `TODO`, `FIXME`, hardcoded return values, parameters accepted but never read in `swan_formats.py`, `transect_handoff.py`, segment config code
2. Verify `compute_spot_transects()` generates N transects at the configured spacing (not 1 with N ignored)
3. Verify obstacle intersection test uses real OBSTACLE geometry (not hardcoded)
4. Verify handoff algorithm matches the brief's 4-step specification exactly
5. Verify wizard segment data round-trips: draw → apply → reload → admin shows correct segment
6. Doc-code sync: every config field documented, every removed field cleared from docs

### T7.2 — Retroactive audit: Phase 3 (L3 smart sizing)

- Owner: `clearskies-auditor`

**Scope:**
1. L3 skip path: when `l3_enabled=off`, verify NO L3 grid is generated
2. SPECOUT deduplication: verify the dedup logic correctly maps transects to shared SPECOUT points
3. Hotstart chain: verify L3 skip doesn't break L1→L2 nesting for other spots
4. SWAN INPUT syntax: verify generated SPECOUT commands match `swan-commands-extract.md` exactly
5. Silent deferral scan on all Phase 3 modified files

### T7.3 — Retroactive audit: Phase 4 (1D model integration)

- Owner: `clearskies-auditor`

**Scope:**
1. Per-partition verification: verify ALL partitions from decomposition are transformed (not just dominant)
2. K-G depth correction removal: verify `SHALLOW_DEPTH_THRESHOLD_M` and lerp block are completely gone
3. Break point authority: verify SwellTrack break points are used for scoring and face height, not SWAN QB
4. Obstacle filtering: verify structure-affected transects excluded from best-peak and spot-average
5. Combined saturation: verify Hs_total capped at γ×d after RSS combination
6. Partition identity: verify canonical partitions from deep-water SPECOUT match correctly to handoff SPECOUT
7. Fallback: test model crash path — verify API returns degraded response, not 500
8. Silent deferral scan on all Phase 4 modified files

### T7.4 — Comprehensive silent deferral scan

- Owner: `clearskies-auditor`

**Do:** Scan ALL surf-related files across all repos for:
1. `pass` bodies in functions that should do something
2. `TODO`, `FIXME`, `HACK`, `XXX` comments
3. Functions that accept parameters but never read them
4. Hardcoded return values (e.g., `return 0.0`, `return None`, `return []`) where real computation is expected
5. `if False:` or commented-out code blocks
6. Variables assigned but never used

**Files to scan:**
- `weewx_clearskies_api/services/surf_1d_*.py`
- `weewx_clearskies_api/services/surfbeat_*.py`
- `weewx_clearskies_api/endpoints/surf.py`
- `weewx_clearskies_api/endpoints/beach_profile.py`
- `weewx_clearskies_api/enrichment/surf_scorer.py`
- `weewx_clearskies_api/enrichment/breaker_height.py`
- `weewx_clearskies_api/enrichment/wave_transform.py`
- `weewx_clearskies_api/config/marine_config.py`
- Dashboard: all files under `components/marine/`

**Accept:** Zero silent deferrals found. If any are found, they are fixed in this phase — not deferred.

### T7.5 — Disposition of old-plan Phase 8 deferred items

- Owner: Coordinator (Opus)

**The SURF-1D-IMPLEMENTATION-PLAN Phase 8 had 6 tasks, of which T8.2 was done and T8.1/T8.3-T8.6 were deferred. Disposition:**

| Old task | Disposition in this plan |
|---|---|
| T8.1 (SWASH ground truth) | **CANCELLED.** SWASH ruled out entirely. No replacement. |
| T8.2 (Consistency check) | **DONE.** BJ sign bug found and fixed (c987973). |
| T8.3 (Iribarren validation) | **Covered by T6.4.** Surfline comparison includes breaker type when reported. |
| T8.4 (Webcam comparison) | **Replaced by T6.4.** Surfline comparison, not webcam — we don't have a webcam. |
| T8.5 (Peel angle validation) | **Covered by T6.4.** Compare peel angle output against Surfline/BSR descriptions when available. |
| T8.6 (Scoring recalibration) | **Covered by T7.6** below. |

**Accept:** Every old Phase 8 task has an explicit disposition — none left in limbo.

### T7.6 — Scoring recalibration check

- Owner: `clearskies-auditor`

**Do:**
1. With friction now enabled (T1.2), face heights have changed vs the pre-friction pipeline
2. Compare scoring outputs for the current conditions against intuitive expectations
3. If face heights shifted significantly, check `_WAVE_HEIGHT_RANGES_FT` thresholds in the scorer
4. Flag any threshold that needs adjustment — Coordinator + user decide the new values

**Accept:** Scoring produces intuitively correct results for the current conditions. Any threshold adjustment documented and applied.

### QC Gate 7 (Final)

- All 3 retroactive audits completed with zero unresolved findings
- Comprehensive silent deferral scan: zero deferrals across all surf-related code
- Scoring produces reasonable results with friction enabled
- All findings from T7.1-T7.5 resolved — NONE deferred
- Test baselines hold across all repos

---

## Summary

| Phase | Purpose | Key deliverables | Status |
|---|---|---|---|
| 0 | Governing Document Updates | ADR-093, ARCHITECTURE.md, API-MANUAL, PROVIDER-MANUAL, OPS-MANUAL, DASHBOARD-MANUAL — all updated for SwellTrack naming, SurfBeat, compute offloading | **COMPLETE** ✓ |
| 1 | SwellTrack Core Fixes | Rename to SwellTrack, friction on by default (0.038), attribution "SWAN + SwellTrack" | **COMPLETE** ✓ |
| 2 | SurfBeat Strip Integration | Strip runner, IG parsing, 3-hour cadence, blended approach-zone Hs | **COMPLETE** ✓ |
| 3 | Compute Offloading | Compute service on librewxr, `surf_compute_host` config, in-process fallback | NOT STARTED |
| 4 | Dashboard IG Display | Set/lull timing on Card 3 + 72h scroll, blended profile chart, attribution | NOT STARTED |
| 5 | Wizard/Admin Config | SurfBeat toggle, compute host URL, friction coefficient, HB Pier reconfig | NOT STARTED |
| 6 | Deployment & Activation | Deploy all, trigger SWAN cycle, verify full pipeline, Surfline comparison | NOT STARTED |
| 7 | QA & Validation | Retroactive audits (Phases 2-4), silent deferral scan, scoring check | NOT STARTED |

**Adversarial audit is mandatory for every phase.** No phase closes without the auditor sign-off. No findings may be deferred to a later phase.

---

## Execution Log

### Session 1 (2026-07-21)

**Phases completed:** 0, 1, 2 (with all QC gates passed)

**API repo commits (weewx-clearskies-api):**
- `d2f0a40` feat(T2.1): add SurfBeat strip production runner (945 lines)
- `d4baa59` feat(T2.3): add SurfBeat approach-zone Hs blending for beach profile
- `7224f8a` feat(T2.2): wire SurfBeat into surf forecast pipeline
- `02331df` feat(Phase1): SwellTrack rename, friction enabled, SurfBeat config
- `87ae42e` fix(Phase2-audit): Hs formula 4*sqrt(m0), unit conversion, blend wiring, result cache

**Meta repo commits (weather-belchertown):**
- `dcb7203` docs(Phase0): SwellTrack naming, SurfBeat, compute offloading across all governing docs

**Dashboard repo changes (weewx-clearskies-dashboard):**
- openapi-v1.yaml nearshoreModel updated to "SWAN + SwellTrack" (uncommitted, minor)

**Audit results:**
- Phase 0: 4 findings (2H, 1M, 1L) — all remediated
- Phase 1: 3 findings (0H, 1M, 2L) — all remediated
- Phase 2: 4 findings (1H, 2M, 1L) — all remediated

**Uncommitted state at session end:**
- API repo: `nws.py` (pre-existing, unrelated), `surfbeat_strip_benchmark.py` (untracked benchmark prototype)
- Dashboard repo: `public/card-manifest.json` (pre-existing), `src/api/openapi-v1.yaml` (nearshoreModel fix)
- Meta repo: `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`, `docs/reference/swan-commands-extract.md` (pre-existing)

**Next session starts at:** Phase 3 (Compute Offloading). T3.1 and T3.2 are code tasks. T3.3 requires user approval for SSH to librewxr.

**Parallelization:** Phase 0 must complete first. Phases 1 and 4 (dashboard) can partially overlap (API and dashboard repos are separate). Phase 3 depends on Phases 1-2 (compute service wraps the pipeline code). Phase 5 depends on Phase 3 (config references compute host). Phase 6 depends on Phases 1-5 (deployment). Phase 7 runs last (audits the full result).
