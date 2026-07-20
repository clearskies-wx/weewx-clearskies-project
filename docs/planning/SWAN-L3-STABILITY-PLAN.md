# SWAN Level 3 Stability — Implementation Plan

**Status:** APPROVED
**Created:** 2026-07-19
**Origin:** Production audit found Level 3 (10m surf-zone grid) diverges numerically — wave field becomes NaN when surf-zone breaking activates. Root cause: two SWAN configuration errors in the shared physics block (`swan_formats.py:852-860`) and one silent structure-emission gap. Full diagnosis in `docs/planning/briefs/SWAN-L3-STABILITY-BRIEF.md`.
**Prerequisite:** Read the stability brief (§1-§9) in full before executing any phase.

---

## 0. Orientation — Execution Context

Same as SWAN-FIXES-PLAN.md — read those files, use those deploy scripts, follow those SSH rules. Additionally:

**Stability brief:** `docs/planning/briefs/SWAN-L3-STABILITY-BRIEF.md` — the governing diagnosis. Every code change must trace to a finding (A, B, or C) or a subsection (§5.x) in that brief.

**Regression prevention:** SWAN-FIXES-PLAN.md Phase 14 RULES 1-5 remain binding. In particular:
- RULE 1: Preserve proven INPUT patterns (HOTFILE, INIT HOTSTART, CURVE, TABLE variable ordering for non-SETUP columns, OBSTACLE format, WLEVEL/CURRENT, TRIAD, NESTOUT, UTM transform).
- RULE 4: No blind refactoring of `build_swan_input()` beyond the scoped physics changes.
- RULE 5: Read `docs/reference/swan-commands-extract.md` before writing any SWAN INPUT generation code.

**Logging mandate:** Every code change in this plan MUST include INFO-level logging that identifies the decision made and the values used. During the testing phase, we need full visibility into what the model is doing. Specific logging requirements are called out per task.

**Test baselines (must not regress):**

| Suite | Baseline | Command |
|-------|----------|---------|
| API pytest | Current passing count | `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 \| tail -3"` |

**Deploy script:** `scripts/deploy-api.sh` — the only authorized deploy path.

**Convergence mode:** `convergence_retry = false` for the duration of this testing phase. Failed runs preserve their working directory (INPUT, PRINT, TABLE, hotstart) untouched for debugging. No automatic retry. No hotstart save on failure.

---

## Phase 1 — Documentation Sync (HARD PREREQUISITE)

Governing documents must accurately describe the per-level physics BEFORE agents write code. An agent reading §14.15 must understand that SETUP is removed, DIFFRACTION is per-level, and the convergence gate exists.

### T1.1 — Update `swan-commands-extract.md` with SETUP, DIFFRACTION, NUMERIC

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/reference/swan-commands-extract.md`

**Do:**
1. Add SETUP command documentation:
   - Syntax: `SETUP`
   - What it does: computes wave-induced water level setup via elliptic (Poisson) solve.
   - Restrictions: "Not supported in case of parallel runs using either MPI or OpenMP" (SWAN User Manual p. 79). "Can only be applied to open coast" (p. 79). Requires Cartesian coordinates (p. 79). In a nest, the setup boundary condition requires Dirichlet values that BOUNDNEST1 does not carry — falls back to Neumann with zero at deepest point.
   - Our status: **REMOVED from all levels** — unsupported in parallel runs (we always run OpenMP). Setup effect delivered via WLEVEL injection (Stage 2, future).

2. Add DIFFRACTION command documentation:
   - Syntax: `DIFFRACTION [idiffr] [smpar] [smnum] [cgmod]`
   - Defaults: `idiffr=1, smpar=0, smnum=0, cgmod=1`
   - Stabilization measures (SWAN User Manual pp. 79-80):
     - Measure 1 (RECOMMENDED): Under-relaxation via NUMERIC parameter `[alfa]`. "Very limited experience suggests [alfa] = 0.01." NOT meaningful for nonstationary computations.
     - Measure 2: Smoothing — `smpar` (coefficient, recommended 0.2) and `smnum` (number of smoothing steps). Filter width: εx = ½·√(3n)·Δx. Smoothing applies to a temporary copy — outputs unaffected.
   - Our usage: **L3 only** — `DIFFRACTION 1 0.2 27` (smoothing; filter width εx ≈ 45m ≈ half dominant wavelength at Δx=10m). L1/L2: removed (sub-grid, can only destabilize).
   - Note: "does not properly handle diffraction in harbours or in front of reflecting obstacles" (p. 79). OBSTACLE is independent of DIFFRACTION.

3. Add NUMERIC command documentation (relevant subset):
   - Syntax: `NUMERIC ... [alfa]`
   - `[alfa]` = under-relaxation factor for the iterative solver. Default 0.01. "Not meaningful for nonstationary computations."
   - Our usage: L3 stationary (quick update) only — `NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01`

4. Add the per-level physics table from brief §5.1.

5. Commit the currently-uncommitted 65-line NGRID/NESTOUT/BOUNDNEST1 addition sitting in the working tree (noted in the brief §7).

**Accept:**
- `swan-commands-extract.md` contains SETUP (with parallel restriction + nest BC problem), DIFFRACTION (with both stabilization measures), and NUMERIC `[alfa]`.
- Per-level physics table present and matches brief §5.1.
- No stale references to bare `DIFFRACTION` or universal `SETUP`.

### T1.2 — Update PROVIDER-MANUAL §14.15

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/PROVIDER-MANUAL.md`

**Do:** Update §14.15 (SWAN runner) to add:
1. **Per-level physics:** Table showing which commands are emitted per level (§5.1 of brief). Explain WHY SETUP is removed (A1: parallel unsupported; A2: nest BC wrong) and WHY DIFFRACTION differs by level (sub-grid at L1/L2; stabilized at L3).
2. **WLEVEL composition:** L3 receives tide via WLEVEL INPGRID/READINP. Stage 1: tide-only. Stage 2 (future): tide + analytic setup estimate. Quick update: static WLEVEL at compute time (was previously missing entirely).
3. **Convergence gate:** Health check after every SWAN run — PRINT scan for `******`, NaN scan in hotstart/TABLE, valid-point fraction. On FAIL with `convergence_retry = false`: ERROR log, no retry, failed workdir preserved, no hotstart save, API serves last-good run. On FAIL with `convergence_retry = true` (future): quarantine + degradation ladder (smnum ×2 → DIFFRACTION removed → abandon cycle).
4. **Hotstart isolation:** Stationary quick update does NOT overwrite the nonstationary chain's hotstart files.
5. **OBSTACLE emission:** Structures with bearing/length/distance (no explicit coordinates) are now emitted by computing endpoint coordinates from the spot pin. Log which structures emitted vs skipped.

**Accept:** An agent reading §14.15 can correctly describe the per-level physics, the convergence gate behavior, and the OBSTACLE emission logic without referencing the brief.

### T1.3 — Update ARCHITECTURE.md SWAN section

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md`

**Do:**
- TRIAD/SETUP sentence: change to note SETUP is no longer a SWAN command; setup effect delivered via WLEVEL injection in Stage 2.
- Add: per-level physics differentiation (L1/L2 vs L3).
- Add: convergence gate as a post-run health check.
- Add: OBSTACLE emission from bearing/length/distance configs.

**Accept:** ARCHITECTURE.md SWAN section matches the to-be-implemented code. No references to universal `SETUP` command.

### T1.4 — Update API-MANUAL §17-18

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md`

**Do:**
- §17 (scoring): Document that the `setup` field in surf/beach-profile responses is now `null` (or 0.0). SETUP is no longer computed by SWAN. Future: analytic estimate via WLEVEL (Stage 2).
- §18 (beach profile): Same — `setup` column absent from TABLE output. Response field retained as `null` for API contract stability.

**Accept:** API-MANUAL matches the to-be-implemented response shape.

### T1.5 — Update OPERATIONS-MANUAL

- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/OPERATIONS-MANUAL.md`

**Do:**
- Add `convergence_retry` config key documentation: location in `[nearshore]`/`[swan]`, default `false`, what each mode does.
- Add quarantine directory location: `/var/run/weewx-clearskies/swan/failed/{cycle}_{level}/` (when `convergence_retry = true`).
- Document the purge procedure for NaN-contaminated hotstarts.
- Add `swan_convergence_failures_total{level,rung}` metric.

**Accept:** Operator can understand the convergence behavior and know how to read failure artifacts.

### QC Gate 1

- `clearskies-auditor` verifies:
  - `swan-commands-extract.md` contains SETUP with parallel restriction, DIFFRACTION with both stabilization measures, NUMERIC `[alfa]`, and the per-level physics table.
  - PROVIDER-MANUAL §14.15 describes per-level physics, convergence gate (both modes), hotstart isolation, and OBSTACLE emission from bearing/length/distance.
  - ARCHITECTURE.md SWAN section does not reference universal `SETUP` command.
  - API-MANUAL §17-18 documents `setup` field as `null`.
  - OPERATIONS-MANUAL documents `convergence_retry`, quarantine location, purge procedure.
  - `grep -ri "^SETUP$" docs/reference/swan-commands-extract.md` — the command appears only in the documentation section (not as a recommended emission).
  - All test baselines hold.

---

## Phase 2 — Per-Level Physics Configuration (Core Fix)

The critical change: `build_swan_input()` emits different physics commands per level instead of the shared block at lines 852-860.

### T2.1 — Implement per-level physics selection in `swan_formats.py`

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py` (lines 850-868)
- Reference: Brief §5.1, `docs/reference/swan-commands-extract.md`
- **MUST READ before coding:** `docs/reference/swan-commands-extract.md` (RULE 5)

**Background:** The current physics block (lines 852-860) is a flat list applied identically to all three levels:
```python
"GEN3 WESTHUYSEN",
"BREAKING CONSTANT 1.0 0.73",
"FRICTION JON 0.067",
"TRIAD",
"SETUP",
"DIFFRACTION",
```

**Do:**
1. Replace the static physics list with a function or conditional block that accepts the `grid_level` parameter (already available — `build_swan_input()` receives it).
2. Emit per level:

   | Command | L1 (`"level1"`) | L2 (`"level2"`) | L3 (`"inner"` or `"level3"`) |
   |---------|-----------------|-----------------|------------------------------|
   | `GEN3 WESTHUYSEN` | emit | emit | emit |
   | `BREAKING CONSTANT 1.0 0.73` | emit | emit | emit |
   | `FRICTION JON 0.067` | emit | emit | emit |
   | `TRIAD` | emit | emit | emit |
   | `SETUP` | **DO NOT emit** | **DO NOT emit** | **DO NOT emit** |
   | `DIFFRACTION` | **DO NOT emit** | **DO NOT emit** | emit as `DIFFRACTION 1 0.2 27` |

3. For L3 stationary (quick update): additionally emit `NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01` (the `stationary` parameter is already available in `build_swan_input()`).

4. Determine stationary vs nonstationary from the existing `stationary` parameter passed to `build_swan_input()`. The NUMERIC line is ONLY emitted when `stationary=True AND grid_level in ("inner", "level3")` (or matching the L3 pattern).

5. **Logging (mandatory):**
   - INFO: `"SWAN %s physics: SETUP=removed (parallel unsupported), DIFFRACTION=%s"` with the actual command string emitted (or "removed" for L1/L2).
   - INFO: `"SWAN %s: NUMERIC alfa=0.01 emitted (stationary L3)"` when applicable.

6. **DO NOT** touch anything else in `build_swan_input()`. The UTM transformation, HOTFILE, INIT HOTSTART, CURVE, TABLE, NESTOUT, BOUNDNEST1, WLEVEL, CURRENT — all stay exactly as they are (RULE 1, RULE 4).

**Accept:**
- Generated INPUT for Level 1: contains `GEN3 WESTHUYSEN`, `BREAKING`, `FRICTION`, `TRIAD`. Does NOT contain `SETUP` or `DIFFRACTION`.
- Generated INPUT for Level 2: same as Level 1.
- Generated INPUT for Level 3 (nonstationary full run): contains all of the above PLUS `DIFFRACTION 1 0.2 27`. Does NOT contain bare `DIFFRACTION` or `SETUP`.
- Generated INPUT for Level 3 (stationary quick update): same as L3 nonstationary PLUS `NUMERIC STOPC dabs=0.005 drel=0.01 curvat=0.005 npnts=99.5 STAT mxitst=50 alfa=0.01`.
- INFO log lines identify which physics commands were emitted for each level.
- All existing unit tests pass.

### T2.2 — Remove SETUP from TABLE output variable lists

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py` (lines 993-996, 1010-1013)
- Reference: Brief §5.2

**Background:** The TABLE command at line 993 requests: `TIME XP YP HSIGN HSWELL TM01 DIR DEPTH QB DISSURF SETUP DSPR`. With `SETUP` removed from the physics, SWAN would either reject the output request or emit zeros. Remove it from the TABLE variable list.

**Do:**
1. Remove `SETUP` from the TABLE variable list in the transect/curve branch (line ~993).
2. Remove `SETUP` from the TABLE variable list in the simple-points branch (line ~1010).
3. The column order for remaining variables stays the same (RULE 1 — proven patterns).
4. **Logging:** INFO: `"SWAN TABLE output columns: %s"` listing the actual column names emitted — aids debugging if parse issues arise.

**Accept:**
- Generated TABLE commands do NOT contain `SETUP` in the variable list.
- All other TABLE variables remain in their proven order.
- The parser (`_parse_transect_table` at line 322) handles the absence of SETUP gracefully (it already does — `i_setup = col_idx.get("SETUP")` returns None when the column isn't in the header).

### T2.3 — Downstream API: treat setup as absent

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py`
- Reference: Brief §5.2, API-MANUAL §17-18 (updated in T1.4)

**Do:**
1. In `surf.py`: any code that reads `point.setup` for scoring or display — ensure it handles `None` gracefully (no crash, no NaN propagation). The `setup` field in the response should be `null` (not 0.0) to signal "not computed."
2. In `beach_profile.py`: same — `setup` in the response is `null`.
3. Grep for any other references to `setup` in the endpoints directory and handle them.
4. **Do NOT remove the `setup` field from response models** — API contract stability. The field exists, its value is `null`.

**Accept:**
- `GET /surf/{spot}` response: `setup` field is `null` for all forecast points.
- `GET /beach-profile/{spot}` response: `setup` field is `null` for all transect points.
- No 500 errors from null-propagation when setup is None.
- No scoring regression — scoring logic that previously used setup as an input now treats it as absent/zero contribution.

### QC Gate 2

- `clearskies-auditor` verifies:
  - Generate a test INPUT for each level (L1, L2, L3-nonstat, L3-stat) and confirm:
    - No INPUT contains bare `SETUP` or bare `DIFFRACTION`.
    - L3 INPUT contains `DIFFRACTION 1 0.2 27`.
    - L3-stat INPUT contains `NUMERIC ... alfa=0.01`.
    - L1/L2 INPUT contains neither `DIFFRACTION` nor `SETUP`.
  - TABLE variable lists do not contain `SETUP`.
  - API endpoints return `setup: null` without error.
  - Grep `swan_formats.py` for any remaining `"SETUP"` string literal that would be emitted to INPUT — should find zero (only logging/comment references allowed).
  - INFO log lines confirm physics selection per level.
  - All test baselines hold.
  - Changes match PROVIDER-MANUAL §14.15 (updated in T1.2).

---

## Phase 3 — OBSTACLE Emission Fix + Quick Update Gaps

Two related problems: (1) structures with bearing/length/distance but no coordinates are silently dropped; (2) the quick update path omits both WLEVEL and structures from the L3 INPUT.

### T3.1 — Emit OBSTACLE for bearing/length/distance structures (Finding C)

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` (lines 1117-1136)
- Reference: Brief §4b

**Background:** The structure assembly at lines 1117-1136 skips any `StructureConfig` without a `coordinates` field. The HB Pier config uses `bearing_degrees=221.0, length_m=566.8, distance_m=124.5` — no coordinates. It is silently skipped.

**Do:**
1. In the structure assembly loop, when `coordinates` is absent but `bearing_degrees`, `length_m`, and `distance_m` are all present:
   a. Compute the structure's start point: from the spot's pin coordinates, offset by `distance_m` along `bearing_degrees` (geodesic projection — use the same UTM zone already computed for the grid).
   b. Compute the structure's end point: from the start point, extend `length_m` along `bearing_degrees`.
   c. Emit a coordinate list `[start_point, end_point]` (two-point line segment).
   d. Include the structure in `obstacle_structures` with `type` and `coordinates`.

2. **Logging (mandatory):**
   - INFO: `"SWAN structure emitted: type=%s, bearing=%.1f°, length=%.0fm, distance=%.0fm (computed from pin)"` for each structure emitted via bearing/length/distance.
   - INFO: `"SWAN structure emitted: type=%s, %d coordinate points (explicit)"` for structures with explicit coordinates.
   - WARNING: `"SWAN structure SKIPPED: type=%s — missing both coordinates and bearing/length/distance"` for structures that cannot be emitted. **Never skip silently.**

3. **Do NOT modify** the OBSTACLE emission logic in `swan_formats.py` (lines 870-899) — it is proven and working (RULE 1). Only the structure assembly in `swan.py` changes.

**Accept:**
- For HB Pier config (bearing=221.0, length=566.8, distance=124.5): the generated Level 3 INPUT contains an `OBSTACLE` line with computed UTM coordinates.
- Log shows the structure was emitted with its parameters.
- Structures with explicit coordinates continue to work unchanged.
- Structures missing both coordinates AND bearing/length/distance produce a WARNING log (not silent skip).

### T3.2 — Pass WLEVEL and structures to quick update path

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (line ~1436, `run_stationary_level3`)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` (`_run_quick_update_locked`, line ~1493)
- Reference: Brief §5.4

**Background:** The stationary quick update calls `_write_input_files` at line 1436 without `tide_predictions` or `structures`. The full run passes both. This means:
- Quick updates run with no tidal water level (up to ±1m error at HB).
- Quick updates ignore all coastal structures.

**Do:**
1. In `_run_quick_update_locked` (swan.py, line ~1493):
   a. Obtain the current tide prediction for the compute time. The tide data is already available from CO-OPS (same source as the full run). Fetch a single-hour prediction for `now` or use the cached tide from the most recent full run.
   b. Assemble structures using the same logic as the full-run path (lines 1117-1136, now including the T3.1 fix).
   c. Pass both `tide_predictions` and `structures` to the runner's `run_stationary_level3()`.

2. In `run_stationary_level3` (swan_runner.py, line ~1378):
   a. Accept `tide_predictions` and `structures` parameters.
   b. Pass them through to `_write_input_files` at line 1436.
   c. The existing `_write_input_files` logic already handles stationary WLEVEL (INPGRID WLEVEL with no NONSTAT keywords) — verify this is correct for the single-timestamp case.

3. **Logging (mandatory):**
   - INFO: `"SWAN L3 quick update: WLEVEL=%.2fm (tide at %s), structures=%d"` showing the tide level used and structure count.
   - WARNING: `"SWAN L3 quick update: no tide data available — running without WLEVEL"` if tide fetch fails (don't crash — fall through to no-WLEVEL behavior, same as today, but now it's explicit).

**Accept:**
- Quick update Level 3 INPUT contains `INPGRID WLEVEL` and `READINP WLEVEL` commands with the current tide value.
- Quick update Level 3 INPUT contains `OBSTACLE` lines for configured structures.
- Log confirms tide level and structure count for each quick update.
- Tide fetch failure is non-fatal — logged as WARNING, run proceeds without WLEVEL (degraded but not crashed).

### T3.3 — Fix `fishing.py:365` bathymetric_profile access

- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/fishing.py` (line 365)
- Reference: Brief §5.5 item 4

**Background:** `surf_config.bathymetric_profile` references an attribute removed in SWAN-FIXES-PLAN Phase 7 (dead code removal). The endpoint 500s today.

**Do:**
1. Remove the `surf_config.bathymetric_profile` access and the loop that builds the old-style profile list.
2. Replace with the runtime CUDEM profile from the spot profile cache (`/etc/weewx-clearskies/spot_profiles/{spot_id}.json`), OR set `bathymetric_profile = None` and let `get_habitat_features()` handle the absence gracefully.
3. Verify `get_habitat_features()` returns sensible defaults when profile is None.
4. Sweep `endpoints/setup.py:1054-1056` for any remaining references to `bathymetric_profile` on `SurfSpotConfig`.

**Accept:**
- `GET /fishing/{spot}` returns 200 (not 500).
- `get_habitat_features()` returns a result (possibly with reduced detail) when no profile is available.
- No remaining references to `surf_config.bathymetric_profile` in the codebase (grep confirms).

### QC Gate 3

- `clearskies-auditor` verifies:
  - Generated L3 INPUT (both full and quick update) contains OBSTACLE lines for HB Pier.
  - Quick update L3 INPUT contains WLEVEL commands.
  - Log output shows structure emission with parameters and tide level.
  - Structures without coordinates AND without bearing/length/distance produce WARNING (not silent skip).
  - `GET /fishing/huntington-city-beach-pier` returns 200.
  - `grep -rn "bathymetric_profile" repos/weewx-clearskies-api/` returns zero hits in endpoint code (only in config model if the field still exists for migration).
  - Changes match PROVIDER-MANUAL §14.15 (OBSTACLE emission, WLEVEL in quick update).
  - All test baselines hold.

---

## Phase 4 — Operational Safeguards

Production is unattended — no run may halt on a human, and no failure may be silent. This phase adds the convergence gate, hotstart isolation, and pre-deploy purge instructions.

### T4.1 — Convergence health check after every SWAN run

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
- Reference: Brief §5.5 item 2

**Do:**
1. Add a method `_check_convergence(self, run_dir: Path, grid_level: str) -> bool` that performs three checks:

   a. **PRINT scan:** Read the PRINT file in `run_dir`. If any accuracy line contains `******` (overflow/divergence marker), or if the final accuracy for a stationary run is below 99.5% — return `False`.

   b. **NaN scan:** Read the hotstart file in `run_dir`. If any NaN values are present — return `False`. (Use `grep -ci nan` equivalent or parse as binary floats and check with `math.isnan`.)

   c. **Valid-point fraction:** Read the TABLE output. Count timesteps where ≥50% of wet transect points have non-exception values. If this fraction is below 80% — return `False`.

2. Call `_check_convergence()` after every `_spawn_swan()` call, for every level.

3. On `False` return (FAIL):
   - Log ERROR: `"SWAN convergence FAILED level=%s: %s"` with the specific check that failed and its values (accuracy percentage, NaN count, valid fraction).
   - **Do NOT call `_save_hotstart()`** — the NaN-contaminated hotstart must not propagate.
   - **Do NOT update the spot forecast cache** — API serves the last-good run.
   - **Leave the failed working directory untouched** — it is the debugging artifact.
   - Return early from the level's execution (skip downstream levels if L1/L2 fail).

4. On `True` return (PASS):
   - Log INFO: `"SWAN convergence OK level=%s: accuracy=%.1f%%, valid_fraction=%.1f%%, nan_count=0"`.
   - Proceed with `_save_hotstart()` and cache update as normal.

5. Add config key `convergence_retry` to `SWANRunnerConfig` (or equivalent), default `False`. When `True`, the degradation ladder fires (future — NOT implemented in this plan, only the config key and the branch stub with a `# TODO: degradation ladder` comment).

6. **Logging (mandatory):** Every convergence check logs its three metrics at INFO level regardless of pass/fail. The ERROR is additional on failure.

**Accept:**
- A run producing NaN in the hotstart file: hotstart is NOT saved, cache is NOT updated, ERROR log emitted with level and metrics.
- A run producing `******` in PRINT: same behavior.
- A run with <80% valid-point fraction: same behavior.
- A healthy run: hotstart saved, cache updated, INFO log with metrics.
- Failed working directory is preserved (not cleaned up).
- `convergence_retry` config key exists, defaults to False, and the False branch is the only implemented path.

### T4.2 — Hotstart isolation for stationary quick updates

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (line ~1448)
- Reference: Brief §5.5 item 3

**Background:** The stationary quick update at line 1448 calls `self._save_hotstart(l3_dir, f"level3_{idx}")` — overwriting the nonstationary chain's persistent hotstart. If the stationary run diverges (which is the problem we're fixing), the NaN hotstart infects the next full run.

**Do:**
1. In `run_stationary_level3()`, do NOT call `_save_hotstart()` at all. The stationary quick update is a snapshot — it should not influence the nonstationary chain's warm-start state.

2. Alternatively, if hotstart persistence is needed for the quick update's own warm-start (unlikely for a stationary run, but verify): use a separate filename like `level3_{idx}_stat_hotstart.dat` that is never read by the full run.

3. **Logging:** INFO: `"SWAN L3 stationary: skipping hotstart save (isolation from nonstationary chain)"`.

**Accept:**
- After a quick update, `level3_0_hotstart.dat` is NOT modified.
- The next full run reads the hotstart from the LAST FULL RUN (not from the quick update).
- Log confirms hotstart save was skipped.

### T4.3 — Expose convergence metrics

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/metrics.py` (or equivalent metrics endpoint)

**Do:**
1. Add a Prometheus-style counter: `swan_convergence_failures_total{level, check}` — incremented on each convergence failure. Labels: `level` (level1/level2/level3), `check` (print_overflow/nan_detected/low_valid_fraction).
2. Add a gauge: `swan_last_run_valid_fraction{level}` — the most recent valid-point fraction per level.

**Accept:**
- `/metrics` endpoint includes the convergence counters and gauges.
- After a failed run, the counter increments and the gauge reflects the failed fraction.

### T4.4 — Document purge procedure (operational — not code)

- Owner: Coordinator (Opus)
- Output: Instructions for the deploy step (included in this plan's Phase 5)

**Purge targets on weewx before first fixed run:**
1. `level3_0_hotstart.dat` — contains NaN from diverged runs.
2. Stale `spot_profiles/huntington-city-beach-pier.json` — pre-OPeNDAP staircase data (if not already purged by SWAN-FIXES-PLAN Phase 18).
3. Legacy `swan_bathymetry.json` — orphaned from pre-3-level system.
4. Orphaned `swan_bathymetry_L3_{uuid}.json` files.

These are documented here for the deploy step. They are NOT code changes.

### QC Gate 4

- `clearskies-auditor` verifies:
  - Simulate a diverged run (write a test hotstart with NaN values): convergence check returns False, hotstart is NOT saved, ERROR log emitted.
  - Simulate a healthy run: convergence check returns True, hotstart IS saved, INFO log emitted.
  - Quick update does NOT modify `level3_0_hotstart.dat`.
  - `/metrics` endpoint includes `swan_convergence_failures_total` and `swan_last_run_valid_fraction`.
  - `convergence_retry` config key exists and defaults to False.
  - Grep for `_save_hotstart` in `run_stationary_level3` — should find zero calls (or calls to a separate stat-only filename).
  - Changes match PROVIDER-MANUAL §14.15 (convergence gate) and OPERATIONS-MANUAL (config key, quarantine location).
  - All test baselines hold.

---

## Phase 5 — Deploy & Production Verification

### T5.1 — Deploy and purge

- Owner: Coordinator (Opus)
- Depends on: Phases 1-4 complete, all QC gates passed

**Do:**
1. Deploy the API via `scripts/deploy-api.sh`.
2. SSH to weewx and purge (commands to run):
   ```
   rm -f /var/run/weewx-clearskies/swan/level3_0_hotstart.dat
   rm -f /var/run/weewx-clearskies/swan/swan_bathymetry.json
   rm -f /var/run/weewx-clearskies/swan/swan_bathymetry_L3_*.json
   ```
3. Verify the API started: `systemctl status weewx-clearskies-api`.
4. Check logs for startup errors: `journalctl -u weewx-clearskies-api --since "5 min ago" | grep -i error`.

**Accept:**
- API running.
- Purged files no longer exist.
- No startup errors.

### T5.2 — Wait for and verify full SWAN run

- Owner: Coordinator (Opus)
- Depends on: T5.1

**Do:** Wait for the next HRRR cycle to trigger a full SWAN run. Then verify:

1. **SWAN exits 0 on all levels.** Check: `journalctl -u weewx-clearskies-api | grep "SWAN.*exit"` — all levels show exit code 0.

2. **No `******` in any PRINT file.** Check: `grep -c '\*\*\*\*\*\*' /var/run/weewx-clearskies/swan/level3_0/PRINT` — should be 0.

3. **No NaN in hotstart.** Check: `grep -ci nan /var/run/weewx-clearskies/swan/level3_0_hotstart.dat` — should be 0 (or the file should not exist if this was a cold start that also failed — in which case check logs).

4. **Valid-point fraction ≥80%.** Check: logs should show `"SWAN convergence OK level=level3_0: ... valid_fraction=XX.X%"` with XX ≥ 80.

5. **Hs > 0 at scoring depth.** Check TABLE output: `head -20 /var/run/weewx-clearskies/swan/level3_0/TABLE_1.txt` — HSIGN column should have values > 0 (not -9, not 0).

6. **QB > 0 at ≥1 transect point.** Check TABLE output for QB column > 0 in at least one data row.

7. **OBSTACLE line present in INPUT.** Check: `grep OBSTACLE /var/run/weewx-clearskies/swan/level3_0/INPUT` — should show at least one line (HB Pier).

8. **DIFFRACTION line correct.** Check: `grep DIFFRACTION /var/run/weewx-clearskies/swan/level3_0/INPUT` — should show `DIFFRACTION 1 0.2 27`. Check L1/L2: `grep DIFFRACTION /var/run/weewx-clearskies/swan/level1/INPUT` — should find nothing.

9. **No SETUP in any INPUT.** Check: `grep -r "^SETUP" /var/run/weewx-clearskies/swan/level*/INPUT` — should find nothing.

10. **Surf forecast card shows non-zero swell.** Check: `curl -s http://localhost:8765/api/v1/surf/huntington-city-beach-pier | python3 -m json.tool | grep -A2 swellHeight`.

11. **Fishing endpoint returns 200.** Check: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8765/api/v1/fishing/huntington-city-beach-pier` — should be 200.

**Accept:** All 11 items pass with evidence (command output). If ANY item fails, STOP — do not proceed to T5.3. Report failure details for debugging.

### T5.3 — Verify quick update

- Owner: Coordinator (Opus)
- Depends on: T5.2

**Do:** Wait for the next hourly quick update cycle, then verify:

1. **Log shows quick update fired.** Check: `journalctl -u weewx-clearskies-api --since "90 min ago" | grep "SWAN L3 quick update"` — should show the tide level and structure count.

2. **Quick update convergence OK.** Check: logs show convergence check passed (no ERROR).

3. **Hotstart NOT modified.** Check: `stat /var/run/weewx-clearskies/swan/level3_0_hotstart.dat` — mtime should NOT have changed since the full run (or the file should not exist if the full run was cold).

4. **Card timestamp advances.** Check: `curl -s http://localhost:8765/api/v1/surf/huntington-city-beach-pier | python3 -m json.tool | grep modelRunTime` — should show a time more recent than the full run.

5. **Quick update INPUT has WLEVEL.** Check: verify in logs or inspect the INPUT file if the workdir is preserved.

**Accept:** All 5 items pass. Quick update is functional with WLEVEL + OBSTACLE + stabilized DIFFRACTION.

### QC Gate 5

- `clearskies-auditor` verifies (independently — NOT the implementing agent):
  - All T5.2 evidence items are genuine (re-run the verification commands).
  - All T5.3 evidence items are genuine.
  - The surf forecast card at `https://weather-test.shaneburkhardt.com` shows non-zero swell with a recent model-run timestamp.
  - No `SETUP` string in any level's INPUT file.
  - `DIFFRACTION 1 0.2 27` in L3 INPUT only.
  - OBSTACLE present in L3 INPUT with HB Pier coordinates.
  - Convergence metrics visible at `/metrics`.

---

## Phase 6 — Final Adversarial Audit

Full-scope audit after all phases complete. Exists because the SWAN-FIXES-PLAN Phase 18 audit signed off on criteria that weren't verified, and three critical bugs shipped. This phase prevents that pattern.

### T6.1 — QC gate verification audit

- Owner: `clearskies-auditor` (independent — NOT the implementing agent)

**Do:** For EVERY QC gate in Phases 1-5, verify each item was actually satisfied — not just checked off.

1. **Re-run acceptance tests.** For each Accept criterion that references a testable output (INPUT file content, API response, log line, file on disk), run the test independently and record the command and its output.

2. **Check for silent deferrals.** Search the codebase for:
   - `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER` added during this plan's implementation.
   - Functions that return hardcoded values where real computation was specified.
   - `pass` statements in functions that should have implementations.
   - `NotImplementedError` raises that weren't in the plan.
   - The `convergence_retry = true` branch: verify it has an explicit `# TODO` and is NOT silently dropping failures.

3. **Check for RULE violations.** Verify:
   - RULE 1: HOTFILE, INIT HOTSTART, CURVE, NESTOUT, BOUNDNEST1, UTM transform — all unchanged.
   - RULE 4: No refactoring of `build_swan_input()` beyond the physics-list change and TABLE column removal.
   - RULE 5: `swan-commands-extract.md` was updated to match the new commands.

4. **Log evidence, not assertions.** Every finding includes the command run and output observed.

**Accept:** Audit report with pass/fail per QC gate item, evidence for each, and a list of any silent deferrals found.

### T6.2 — Doc-code consistency audit

- Owner: `clearskies-auditor`

**Do:**
1. For each document updated in Phase 1:
   - Read the document section.
   - Read the corresponding code.
   - Flag any claim in the doc that does not match the code.
2. Specific checks:
   - PROVIDER-MANUAL §14.15 per-level physics table — matches actual `build_swan_input()` output.
   - PROVIDER-MANUAL §14.15 convergence gate — matches actual `_check_convergence()` implementation.
   - OPERATIONS-MANUAL `convergence_retry` — matches actual config key name, location, and default.
   - `swan-commands-extract.md` DIFFRACTION section — `smnum=27` matches what the code emits.
   - API-MANUAL §17-18 `setup` field — matches actual response shape.
   - ARCHITECTURE.md SWAN section — no references to universal SETUP.
3. **Cross-check brief vs implementation:**
   - Brief §5.1 physics table — matches code.
   - Brief §5.4 (quick update WLEVEL) — matches code.
   - Brief §5.5 (convergence gate) — matches code (for the `convergence_retry=false` mode only).
   - Brief §4b (Finding C OBSTACLE fix) — matches code.

**Accept:** Zero doc-code mismatches, or all mismatches reported with specific file:line references.

### T6.3 — Regression sweep

- Owner: `clearskies-auditor`

**Do:**
1. Run the full pytest suite on weewx. Record the output.
2. Verify no new test failures vs baseline.
3. Verify no new WARNING or ERROR logs in the API during the verification period that aren't related to expected conditions (e.g., first cold-start is expected to have lower valid-point fractions than warm runs).
4. Verify the API's `/surf`, `/fishing`, `/beach-profile`, `/marine` endpoints all return 200 for configured spots.

**Accept:** Test suite passes. All marine endpoints return 200. No unexpected errors in logs.

### T6.4 — Lessons capture

- Owner: Coordinator (Opus)

**Do:** After the audit, triage lessons into the correct files per CLAUDE.md "Capture lessons in the right place":
- "SWAN physics commands must be per-level — shared blocks are only safe when all levels have similar dynamics" → `rules/clearskies-process.md` or `docs/reference/swan-commands-extract.md`
- "Bare DIFFRACTION command (no stabilization) diverges at surf-zone resolution" → `docs/reference/swan-commands-extract.md`
- "Stationary quick updates must NOT overwrite nonstationary hotstart files" → PROVIDER-MANUAL §14.15
- "SETUP is unsupported in parallel SWAN — never emit it when OMP_NUM_THREADS > 1" → `docs/reference/swan-commands-extract.md`
- "Silent skipping of structures is a bug pattern — always log what was skipped and why" → `rules/clearskies-process.md`

**Accept:** Each lesson routed to the correct file. No lessons left only in this plan's narrative.

### QC Gate 6 (Final)

All of the following must be true:

- Every QC gate item from Phases 1-5 independently verified with evidence.
- Zero silent deferrals (or all deferrals explicitly documented with `# TODO` and a plan reference).
- Zero doc-code mismatches (or all reported and fixed).
- Production regression gate (T5.2 + T5.3) passes with evidence.
- Lessons captured in the correct rule/reference files.
- All test baselines hold.
- `grep -rn "^SETUP" repos/weewx-clearskies-api/` in INPUT-generation code returns zero (only documentation/comments/logging).
- `grep -rn "DIFFRACTION\"" repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py` shows ONLY the stabilized form `"DIFFRACTION 1 0.2 27"`.

**Sign-off:** The coordinator presents the T6.1 audit report to the user. The user decides whether the plan is complete.

---

## Phase 7 — Stage 2: Analytic Setup via WLEVEL Injection

**Prerequisite:** Phase 5 verified stable (Stage 1 tide-only WLEVEL converges). Verified 2026-07-19.

**Problem:** With SETUP removed, the ~10-15cm wave-induced water level rise near shore is absent. On a 1:100 beach slope this shifts the break point ~1 grid cell (10m). Acceptable for v1 but improvable.

**Design (from brief §5.3):** OUR code computes the setup estimate and delivers it through the WLEVEL input grid — mathematically identical to SWAN's internal SETUP from the wave model's perspective, but parallel-safe and BC-correct.

### T7.1 — Analytic setup computation module

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/wave_setup.py`
- Reference: Brief §5.3 Stage 2, Longuet-Higgins & Stewart (1964), USACE CEM II-4

**Do:**
1. Implement `compute_setup_profile(hs_offshore: float, tm01: float, profile: list[dict], gamma: float = 0.73) -> list[dict]`:
   a. Shoal `hs_offshore` along the cached bidirectional profile (`spot_profiles/{spot}.json`) to find breaking: Hb where Hs/d ≈ gamma.
   b. Compute static setup profile η(x) from the radiation-stress balance:
      - η = 0 seaward of the break point
      - Inside the surf zone: dη/dx = −K·(dd/dx) with K = 1/(1 + 8/(3γ²)), γ = 0.73
      - η(shoreline) ≈ 0.15-0.2·Hb
   c. Return list of `{"distance_m": float, "setup_m": float}` along the profile.

2. Implement `build_wlevel_with_setup(tide_predictions: list[dict], setup_profile: list[dict], grid_dims: dict) -> list[dict]`:
   a. For each forecast hour: `wlevel(x, y, t) = coops_tide(t) + η(cross-shore distance)`
   b. Uniform alongshore (open straight beach assumption).
   c. Return in the same format `_write_input_files` expects for WLEVEL.

**Accept:**
- For a 1m breaker at HB Pier: setup at shoreline ≈ 0.15-0.20m.
- Setup profile is zero offshore of the break point and increases monotonically toward shore.
- WLEVEL grid = tide + setup at each grid point.

### T7.2 — Wire into the SWAN runner

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/nearshore/swan.py` (`run_all_spots` and `_run_quick_update_locked`)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (L3 WLEVEL composition)

**Do:** Per the brief §5.3 injection sequence:
1. After L2 runs, extract Hs/TM01 at the L3 offshore boundary from L2's TABLE output (add a small POINTS/TABLE output to L2's INPUT at the L3 seaward-edge midpoint).
2. Call `compute_setup_profile()` with L2's Hs and the cached bidirectional profile.
3. Call `build_wlevel_with_setup()` to compose the L3 WLEVEL grid (tide + setup).
4. Pass the composed WLEVEL to L3's `_write_input_files` (replaces the tide-only WLEVEL).
5. Quick update: same with the single latest hour (stationary WLEVEL).

**Logging:** INFO: `"SWAN L3 WLEVEL: tide=%.2fm + setup=%.3fm (Hb=%.2fm at %.0fm from shore)"` per forecast hour.

**Accept:**
- L3 WLEVEL grid contains tide + setup (not tide-only).
- Setup values are physically reasonable (0-0.2m for typical swell).
- Convergence gate still passes with the enhanced WLEVEL.
- Break point location shifts by ~1 grid cell compared to Stage 1 (expected).

### T7.3 — Update governing documents

- Owner: Coordinator (Opus)
- Files: PROVIDER-MANUAL §14.15, API-MANUAL §17-18

**Do:**
- PROVIDER-MANUAL §14.15: Update WLEVEL composition from "tide-only (Stage 1)" to "tide + analytic setup (Stage 2)".
- API-MANUAL §17-18: Update `setup` field description — now populated with the analytic estimate (no longer null).

### QC Gate 7

- `clearskies-auditor` verifies:
  - Setup profile is physically reasonable for HB Pier (shoreline setup 0.15-0.20m for 1m breaker).
  - L3 WLEVEL grid contains tide + setup.
  - Convergence gate still passes.
  - TABLE output unchanged (setup is in WLEVEL, not TABLE).
  - Docs match implementation.
  - All test baselines hold.

---

## Execution Order

```
Phase 1 (Docs)       ← COMPLETE — agents read manuals before coding
Phase 2 (Physics)    ← COMPLETE — SETUP removal + DIFFRACTION stabilization
Phase 3 (OBSTACLE)   ← COMPLETE — Finding C + quick update WLEVEL/structures + fishing.py fix
Phase 4 (Safeguards) ← COMPLETE — Convergence gate + hotstart isolation + metrics
Phase 5 (Deploy)     ← COMPLETE — Deploy, purge, verify production output
Phase 6 (Audit)      ← IN PROGRESS — Adversarial verification of every QC gate
Phase 7 (Setup Est.) ← PENDING — Stage 2: analytic setup via WLEVEL injection
```

**Sequence constraints:**
1. Phases 1-6 are the stability fix (mandatory, no deferrals).
2. Phase 7 is the Stage 2 enhancement — gated on Stage 1 being verified stable (verified 2026-07-19).
3. Phase 7 is a separate session — do not combine with Phase 6.

---

## Out of Scope (explicit — do not let agents drift into these)

- VDatum datum normalization (T20.2 from SWAN-FIXES-PLAN) — separate issue, tracked there.
- Grid rotation optimization — already implemented, leave alone.
- Any rewrite/"cleanup" of `build_swan_input()` beyond the physics-list change (RULE 4).
- Nesting ratios, bathymetry resolver, domain sizing — all working; leave alone.
- `convergence_retry = true` degradation ladder implementation — config key only, implementation is future work.
