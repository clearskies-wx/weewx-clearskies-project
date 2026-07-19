# SWAN Level 3 Stability Brief — SETUP misuse + unstabilized DIFFRACTION

**Date:** 2026-07-19 · **Status:** APPROVED DIAGNOSIS — implementation pending
**Audience:** Opus coordinator executing the fix. Read this whole brief AND the reading list (§9) before dispatching any agent or writing any code.
**Prerequisite context:** production audit of 2026-07-19 (`c:\tmp\swan-audit-2026-07-19.md`, findings F1-F8) and SWAN-FIXES-PLAN.md regression-prevention RULES 1-5.

---

## 1. The failure, in one paragraph

Level 3 (the 10 m surf-zone grid) diverges numerically: the wave field becomes NaN. In the
stationary hourly quick update, divergence occurs by solver iteration 4 (PRINT shows
convergence 20% → 27% → `******`, then all 48 CURVE points return the −9 exception value
with Depth = NaN). In the nonstationary full run, the field stayed finite for the first
~14 simulated hours and went NaN **at the hour the 3.5 ft SSW swell arrived and surf-zone
breaking began** (670/3504 valid TABLE points = 48 points × ~14 hours). Every input is
clean — BOTTOM, WIND, WLEVEL, and the L2 boundary file contain zero NaN; L1 and L2 fields
are finite. The instability is generated inside the L3 solve. Two SWAN configuration
errors cause it, both documented in the SWAN 41.51 manuals and both emitted from the
single shared physics block at `swan_formats.py:852-860` (`weewx-clearskies-api`), which
applies identically to all three levels:

```python
"GEN3 WESTHUYSEN",
"BREAKING CONSTANT 1.0 0.73",
"FRICTION JON 0.067",
"TRIAD",
"SETUP",          # ← Finding A: unsupported in our parallel runs; ill-posed in nests
"DIFFRACTION",    # ← Finding B: bare command = zero stabilization
```

A diverged run still exits 0 and still writes its HOTFILE; `_save_hotstart()`
(`swan_runner.py:1447-1448`) promotes the NaN field to `level3_0_hotstart.dat`, and the
next run warm-starts from it (`swan_runner.py:1640-1648`) — the failure is
self-perpetuating until that file is deleted (audit F2).

---

## 2. Minimum SWAN background needed

SWAN is a **phase-averaged spectral** model: each cell stores the distribution of wave
energy over 36 directions × 32 frequencies — never actual crests/troughs, never phase.
Two commands in our INPUT try to represent phenomena that fundamentally live in the
discarded information, and both need special handling:

- **DIFFRACTION** (waves bending around obstacles) is approximated by adding a turning
  term driven by the **curvature** (second spatial derivatives) of the computed
  wave-height field. Second derivatives amplify cell-scale noise; at 10 m resolution the
  breaker zone produces enormous real gradients plus numerical jitter, and the term feeds
  back on itself.
- **SETUP** (breaking waves piling water against the beach, tilting the mean surface up
  toward shore by ~10-20% of breaker height) is computed by a **separate elliptic
  (Poisson) solve** — technical manual Eq. (5.2) — whose solution at every interior point
  depends on boundary values along the entire domain rim.

---

## 3. Finding A — SETUP is misused three independent ways

### A1. SETUP is unsupported in parallel runs — and we always run parallel

> "Note that set-up is not supported in case of parallel runs using either MPI or
> OpenMP!"
> — SWAN User Manual v41.51, command SETUP, printed p. 79

Our runner executes the SWAN binary with OpenMP using **all cores by default**
(`swan_runner.py` config `omp_num_threads`, default 0 = all cores; env handling at
lines 1722-1751; today's runs used 16 threads). Every production run to date has
therefore exercised an explicitly unsupported feature/parallelism combination — on all
three levels. L1/L2 survive because their setup solves are trivial (deep water, weak
forcing); L3's surf-zone solve is exactly where an unsupported parallel SOR iteration
breaks down. **This alone mandates removing `SETUP` from every generated INPUT** unless a
run is deliberately serial.

### A2. In a nest, the setup boundary condition is structurally wrong

The elliptic solve needs one boundary condition at every rim point (Tech. Manual §5.1,
Eq. 5.2). SWAN has two BC types (Tech. Manual §5.2.1):

- **Neumann** (Eq. 5.3/5.5, `Fn + gd·∂ζ/∂n = 0`) on open boundaries and the shoreline —
  which leaves an unknown constant, so SWAN pins **ζ = 0 at the deepest boundary point**
  (User Manual p. 78: "a constant added such that the set-up is zero in the deepest point
  in the computational grid").
- **Dirichlet** (Eq. 5.6, ζ given): "also used in nested models. The setup computed in the
  larger model is used as boundary condition in the nested model." (Tech. Manual p. 119-120)

The Dirichlet nesting mode exists in the solver design, **but the standard
NESTOUT/BOUNDNEST1 nest file carries only spectral energy densities** (User Manual
pp. 51-52 and Appendix D) — no water-level field — and the User Manual documents no
command to supply a setup boundary field to a nested run. So a BOUNDNEST1 nest falls back
to Neumann + zero-at-deepest-point. For Level 3, the deepest point is ~18.5 m mid-nearshore
where true setup is *not* zero, and the rim is forced flat where the real surface is
tilted. The interior solution is anchored to a falsehood, and the setup↔breaking feedback
loop (setup changes depth → depth moves the Hs ≈ 0.73·d break point → breaking moves the
forcing → forcing changes setup) iterates against inconsistent constraints.

### A3. Additional restriction notes for the record

- SETUP "can only be applied to open coast … in contrast to closed basin" (p. 79) — we
  comply, but record it in swan-commands-extract.md.
- SETUP requires Cartesian coordinates ("set-up is not computed correctly with spherical
  coordinates", p. 79) — the existing UTM transformation (commit 0610b3d) exists for this
  reason. Preserve it regardless of this fix (plan RULE 1).

### Why the effect appears only at Level 3

At 1 km (L1) and 100 m (L2) cells, the surf zone is sub-cell or smeared: setup forcing is
weak/smooth and the diffraction curvature term is near zero — the misconfigurations are
present but dormant. At 10 m, the grid resolves the breaker zone: sharp Hs collapse over a
few cells, wet/dry flicker at the waterline, strong radiation-stress gradients. Both
defective terms activate at full strength. This also explains the timing evidence: no
breaking during the cold-start hours → stable; swell arrival → breaking → divergence.

---

## 4. Finding B — DIFFRACTION is emitted with zero stabilization

> "Without extra measures, the diffraction computations with SWAN often converge poorly
> or not at all. Two measures can be taken:
> 1. (RECOMMENDED) The user can request under-relaxation. See command NUMERIC parameter
>    [alpha] … Very limited experience suggests [alpha] = 0.01.
> 2. Alternatively, the user can request smoothing of the wave field for the computation
>    of the diffraction parameter (the wave field remains intact for all other
>    computations and output) … For a = 0.2 (recommended) …"
> — SWAN User Manual v41.51, command DIFFRACTION, printed pp. 79-80

Defaults: `[smpar] = 0`, `[smnum] = 0` — i.e., a bare `DIFFRACTION` command (which is
exactly what we emit) applies **no smoothing and no under-relaxation**. Additional facts
that constrain the fix:

- Under-relaxation `[alfa]` (command NUMERIC, printed pp. 85-87) is flagged **not
  meaningful for nonstationary computations**. Our full runs are nonstationary → for them
  the only in-SWAN remedy is smoothing. The stationary quick update can use either.
- Smoothing is a repeated 5-point convolution applied to a **temporary copy** of the wave
  field used only for the diffraction term ("the wave field remains intact for all other
  computations and output") — it is not a fidelity loss in outputs. Filter width
  εx = ½·√(3n)·Δx. Worked example for Δx = 10 m targeting εx ≈ 45 m (≈ half a dominant
  wavelength): n = (2εx/Δx)²/3 ≈ 27 → `DIFFRACTION 1 0.2 27`.
- "The diffraction approximation in SWAN does not properly handle diffraction in harbours
  or in front of reflecting obstacles" (p. 79). Our L3 domain is an open beach with no
  OBSTACLE lines in the INPUT — diffraction currently contributes almost nothing physical.

**OBSTACLE vs DIFFRACTION — do not conflate (common confusion).** OBSTACLE is the
structure itself: a sub-grid line that blocks/attenuates/reflects energy per its
transmission coefficient. It is a standalone command, fully functional WITHOUT
DIFFRACTION, numerically unconditionally safe, and it captures the dominant physical
effect of a structure. DIFFRACTION only refines the *edges* of the shadow zone (energy
bending sideways into the sheltered area). Removing DIFFRACTION does not remove obstacle
modeling.

**Recommendation (user decision 2026-07-19):** DIFFRACTION stays **ON at Level 3 — but
never bare**. The system must work for arbitrary surf spots worldwide, including spots in
the shadow zones of jetties, breakwaters, and piers, where shadow-edge energy leakage is
exactly what diffraction provides; and Finding C's fix restores the HB Pier OBSTACLE, so
the term has a structure to act on. L3's 10 m resolution is within the manual's stated
applicability window ("resolution near (the tip of) the diffraction obstacle should be
1/5 to 1/10 of the dominant wave length" — 10 m vs ~80 m wavelength = 1/8). Emit:

- L3 nonstationary (full run) and stationary (quick update):
  `DIFFRACTION 1 0.2 [smnum]` — smoothing per manual measure 2 (works in both compute
  modes; outputs unaffected). Starting value `[smnum] = 27` (filter width εx ≈ 45 m ≈ half
  a dominant wavelength; εx = ½√(3n)·Δx). Tune via the §6.1 experiment.
- L3 stationary additionally: `NUMERIC … [alfa] = 0.01` (manual measure 1, RECOMMENDED;
  stationary-only — not meaningful for nonstationary runs).

**Hard gate:** smoothed DIFFRACTION must pass the §6.1 convergence experiment before
deploy. If it still diverges with smoothing, STOP and surface the trade-off to the user —
do not silently drop the command and do not ship an unstabilized one.

Keep DIFFRACTION off at L1/L2: at 1 km / 100 m cells, structure-scale diffraction is
sub-grid — the term cannot represent the physics there, only destabilize. (For a
pile-supported pier specifically, OBSTACLE transmission carries most of the effect and
diffraction refines the shadow edges; for solid structures the refinement is larger.)

---

## 4b. Finding C — configured structures are silently dropped (OBSTACLE never emitted)

Production `api.conf` contains a discovered structure for HB Pier
(`type = pier, material = semi_permeable, length_m = 566.8, bearing_degrees = 221.0,
distance_m = 124.5`), but every production INPUT contains **zero OBSTACLE lines**. Cause:
`providers/nearshore/swan.py:1118-1136` skips any structure whose `StructureConfig` lacks
a `coordinates` field ("Structures without coordinates are skipped — silently"), and this
config entry predates the coordinates schema — it stores geometry as
anchor + bearing + length instead. `build_swan_input()`'s OBSTACLE emission
(`swan_formats.py:870-897`) is intact and proven (plan RULE 1); it simply never receives
the structure.

**Fix (in scope):** in the structures assembly at `swan.py:1118-1136`, when `coordinates`
is absent but `bearing_degrees` + `length_m` + `distance_m` are present, compute the
endpoint coordinates of the structure line from the spot pin (simple geodesic projection:
start at the pin offset by `distance_m` along `bearing_degrees`, extend `length_m` along
the structure bearing) and emit the OBSTACLE line. Log at INFO which structures were
emitted vs skipped — never skip silently. Alternative/longer-term: wizard re-discovery
populates `coordinates`; both paths may coexist.

---

## 5. Fix specification

### 5.1 Per-level physics (swan_formats.py)

`build_swan_input()` must take a per-level physics selection instead of the shared list.

| Command | L1 (1 km) | L2 (100 m) | L3 full (10 m, NONSTAT) | L3 quick (10 m, STAT) |
|---|---|---|---|---|
| GEN3 WESTHUYSEN | keep | keep | keep | keep |
| BREAKING CONSTANT 1.0 0.73 | keep | keep | keep | keep |
| FRICTION JON 0.067 | keep | keep | keep | keep |
| TRIAD | keep | keep | keep | keep |
| SETUP | **REMOVE** (A1) | **REMOVE** (A1) | **REMOVE** (A1+A2) | **REMOVE** (A1+A2) |
| DIFFRACTION | **REMOVE** (sub-grid at 1 km) | **REMOVE** (sub-grid at 100 m) | **`DIFFRACTION 1 0.2 27`** (smoothed; §4 gate) | **`DIFFRACTION 1 0.2 27`** + `NUMERIC [alfa]=0.01` |
| OBSTACLE lines | as configured | as configured | **emit** (Finding C fix) | **emit** (Finding C fix) |

Do NOT touch anything else in `build_swan_input()` — plan RULE 1/RULE 4 apply. The UTM
Cartesian transformation stays (needed independently of SETUP for metric grid math and
future re-enablement).

### 5.2 Downstream consequences of removing SETUP (must be handled in the same change)

The `SETUP` column currently appears in TABLE output specs (`swan_formats.py:994` and
`:1011`) and is parsed/consumed by the API (scoring + beach profile `setup` field). With
the command removed, SWAN would emit the column as zeros or reject it — **remove SETUP
from the TABLE variable lists and make the parser and endpoints treat setup as
absent/0.0**, with the response field retained (value 0.0 or null per API-MANUAL §17-18
decision) so the dashboard contract does not break. Grep targets: `swan_runner.py`
`_parse_output`, `endpoints/surf.py`, `endpoints/beach_profile.py`.

### 5.3 Water level at Level 3 — the replacement for SETUP (the injection sequence)

Justification: the SETUP command text states the computed setup "is added to the depth
that is obtained from the READ BOTTOM and READ WLEVEL commands" (p. 79). Depth in SWAN is
`BOTTOM + WLEVEL (+ setup)`. Therefore delivering a setup estimate **through the WLEVEL
input grid is mathematically identical** from the wave model's point of view — and WLEVEL
is a fully supported, parallel-safe input we already generate.

**Stage 1 (ship first): tide-only WLEVEL.** L3 runs with the existing CO-OPS tidal WLEVEL
and no setup at all. Quantified cost: setup ≈ 0.15-0.2 × breaker height (~10-15 cm for a
3 ft breaker); on a ~1:100 beach slope that shifts the break point ~10-15 m ≈ 1 grid cell.
The tide we DO feed swings 1.5-2 m — an order of magnitude larger. Acceptable v1 accuracy.

**Stage 2 (enhancement): analytic setup folded into L3's WLEVEL.** SWAN cannot hand the
parent's setup to the nest (A2), and L2 can no longer compute setup either (A1, unless run
serial — rejected: runtime). Instead OUR code computes the estimate. Sequence per full
run, inside `run_3level()`:

```
1. L1 runs (physics per §5.1) → nest_out.dat                      [unchanged]
2. L2 runs → nest_out.dat + TABLE of Hs/TM01/DIR at the L3
   offshore boundary (add a small POINTS/TABLE output to L2's
   INPUT at the L3 seaward-edge midpoint + quarter points)         [new]
3. Runner post-processes, per forecast hour:
   a. Take L2's Hs at the L3 offshore edge (≈15 m depth).
   b. Shoal it to breaking along the cached bidirectional profile
      (spot_profiles/{spot}.json) → breaker height Hb and breaker
      depth db per cross-shore column.
   c. Static setup profile η(x) from the standard radiation-stress
      balance (Longuet-Higgins & Stewart 1964; USACE CEM II-4):
      η = 0 seaward of the break point; inside the surf zone
      dη/dx = −K·(dd/dx) with K = 1/(1 + 8/(3γ²)), γ = 0.73
      (matches our BREAKING CONSTANT), giving η(shoreline) ≈
      0.15-0.2·Hb. Uniform alongshore (open straight beach).
   d. Build the L3 WLEVEL grid for that hour:
      wlevel(x, y, t) = coops_tide(t) + η(cross-shore distance)
4. Runner writes L3 WLEVEL.txt (existing NONSTAT INPGRID/READINP
   format — no INPUT-syntax changes needed)                        [modified]
5. L3 runs, reading depth = BOTTOM + (tide + setup estimate)       [unchanged]
```

The quick update does the same with the single latest hour (stationary INPGRID WLEVEL,
no NONSTAT keywords).

**Stage 2 is gated on Stage 1 being verified stable in production.** Do not combine.

### 5.4 Related defect found while writing this brief

The stationary quick-update INPUT contains **no WLEVEL input at all** (verified in
production `level3_0/INPUT` 2026-07-19 12:55) — quick updates currently ignore the tide
entirely, a depth error of up to ±1 m at HB. Fix in the same work: the stationary INPUT
builder must emit a static WLEVEL INPGRID/READINP pair using the tide (and later Stage-2
setup) at the compute time.

### 5.5 Operational fixes (from audit — prerequisites for verification)

1. **Purge** on weewx before first fixed run: `level3_0_hotstart.dat` (contains 46,261
   NaN), stale `spot_profiles/huntington-city-beach-pier.json` (pre-OPeNDAP staircase),
   legacy `swan_bathymetry.json`, orphaned `swan_bathymetry_L3_{1d11bda5,eec5bb44}.json`.
2. **Runtime convergence gate + degradation ladder (production is unattended — no run
   may halt on a human, and no failure may be silent).**

   *Health check after every SWAN run* (machine-checkable, in the existing parse step):
   - a. PRINT scan: any `******` in accuracy lines, or (stationary) final accuracy below
     the 99.5% requirement → FAIL.
   - b. NaN scan: any NaN in the run's hotstart/TABLE output → FAIL.
   - c. Valid-point fraction: wet transect points with non-exception values below
     threshold (suggest ≥80% of timesteps having ≥50% valid wet points) → FAIL.

   *Retry behavior is configuration-gated* — new `[nearshore]`/`[swan]` config flag
   `convergence_retry` (bool):

   - **`convergence_retry = false` — REQUIRED for the current testing phase, and the
     shipped default until the user flips it (user decision 2026-07-19).** On FAIL: log
     ERROR with the health-check numbers, do NOT retry, and leave the failed run's
     working directory (INPUT, PRINT, TABLE, hotstart) completely untouched for
     debugging. Skip hotstart save and spot-cache update; API keeps serving the last
     good run. The failed workdir is overwritten only by the next scheduled cycle.
   - **`convergence_retry = true` — production mode, enabled only after the user
     approves.** On FAIL, FIRST quarantine the evidence — copy the failed run's INPUT,
     PRINT, TABLE output, and norm_end/stderr to
     `/var/run/weewx-clearskies/swan/failed/{cycle}_{level}/` (keep the last N=5
     quarantines, prune older) — THEN degrade automatically, one rung per retry, logging
     each rung at ERROR:
     - Rung 1: rerun the level with diffraction smoothing doubled (`smnum` ×2).
     - Rung 2: rerun with DIFFRACTION removed for this cycle only.
     - Rung 3 (all rungs failed): abandon the cycle — no `_save_hotstart()`, no spot-cache
       overwrite; API keeps serving the previous good run with its true
       `generatedAt`/model-run timestamp (staleness stays visible on the card).

   In BOTH modes the non-negotiables are identical: a diverged run never saves a
   hotstart, never overwrites the last-good cache, and never fails silently.

   *Logging/observability requirements:* every FAIL and every rung logs ERROR with level,
   cluster, run type, cycle, accuracy stats, and valid fraction — greppable pattern
   `SWAN convergence`. A successful rung-N run logs WARNING that this cycle ran degraded
   physics (rung > 0 results are cached and served — degraded data beats stale data — but
   the degradation is never silent). Expose a counter on `/metrics`
   (`swan_convergence_failures_total{level,rung}`) so repeated degradation is visible to
   the operator. A diverged run must never persist state of any kind.

   This mirrors the existing crash-retry idiom (`_spawn_swan_with_hotstart_retry`:
   delete stale hotstart, rerun cold) — same pattern, applied to numerical divergence.
3. **Hotstart isolation:** the stationary quick update must stop overwriting the
   nonstationary chain's `level3_{idx}_hotstart.dat` (skip `_save_hotstart` on the
   stationary path, or use a separate filename).
4. **fishing.py:365** — remove the `surf_config.bathymetric_profile` access (Phase 7
   leftover; endpoint 500s today). Sweep `setup.py:1054-1056` and remaining references.

---

## 6. Verification protocol

### 6.1 Toggle experiment (run BEFORE trusting this brief's attribution; ~80 s per run)

On weewx, copy `level3_0/` to a scratch dir (do not touch the live workdir), and run the
SWAN binary directly on four INPUT variants:

| Variant | Change | Expected if brief is right |
|---|---|---|
| 1. Baseline | as deployed | diverges (`******` in PRINT) |
| 2. − DIFFRACTION | delete that line | improved or converges |
| 3. − SETUP | delete that line | improved or converges |
| 4. − both | delete both | **converges** (accuracy → ≥99.5% of wet points) |
| 5. (diagnostic) baseline + `OMP_NUM_THREADS=1` | serial | if converges → A1 confirmed as trigger |
| 6. **ship candidate** | − SETUP, `DIFFRACTION 1 0.2 27`, `NUMERIC [alfa]=0.01` | **must converge** — this is the §4 hard gate |
| 7. (tuning, if 6 marginal) | as 6 with `smnum` 54 / 85 (εx ≈ 64 / 80 m) | pick smallest smnum that converges robustly |

Record the final "accuracy OK in … %" lines from each PRINT as evidence. If variant 4
still diverges, STOP — the diagnosis is incomplete; report to the user before any code
change (CLAUDE.md: solution fails twice → stop). If variant 4 converges but variant 6
does not (even after variant 7 tuning), STOP and surface the diffraction trade-off to the
user — do not decide unilaterally.

**Scope note:** these STOPs are development-time decision gates for the engineer running
the experiment — they choose the shipped configuration. They are NOT runtime behavior.
In production the system never halts or prompts: divergence is handled autonomously by
the §5.5 degradation ladder with explicit ERROR logging and last-good fallback.

### 6.2 Production regression gate (after deploy — Phase 23c criteria, all with evidence)

1. SWAN exits 0 on all levels; PRINT contains no `******` and no NaN in any hotstart
   (`grep -ci nan *hotstart.dat` = 0 for all levels).
2. Full L3 run: ≥95% of timesteps have valid wet-transect points (was 19%).
3. Hs > 0 at scoring depth; QB > 0 at ≥1 transect point during swell.
4. Quick update: >0 spots updated; card model-run timestamp advances hourly.
5. Surf forecast card: 72 populated hours, swell within 50% of NDBC 46253.
6. `/api/v1/fishing/{spot}` returns 200.
7. Level 3 INPUT contains an `OBSTACLE` line for the HB Pier structure (Finding C fix),
   and the runner log shows it emitted (not skipped).
8. **Divergence drill, both modes:** force a diverging run once (e.g., scratch run with
   bare `DIFFRACTION`) and verify:
   - with `convergence_retry = false` (current mode): ERROR log with health-check
     numbers, NO retry attempted, failed workdir left untouched, no hotstart saved,
     last-good cache preserved, card keeps serving previous run with honest timestamp;
   - with `convergence_retry = true` (temporarily, in a scratch config): quarantine
     directory populated with the failed INPUT/PRINT/TABLE, ladder rungs fire in order
     with per-rung ERROR logs, `/metrics` counter incremented.

---

## 7. Doc-code sync obligations (same commits as the code changes)

- `docs/reference/swan-commands-extract.md`: add SETUP (with the parallel-run and
  open-coast restrictions and deepest-point anchoring), DIFFRACTION (defaults, both
  stabilization measures, stationary-only note for [alfa]), NUMERIC [alfa], and the
  per-level physics table from §5.1. Also commit the currently-uncommitted 65-line
  NGRID/NESTOUT/BOUNDNEST1 addition sitting in the meta repo working tree.
- `docs/manuals/PROVIDER-MANUAL.md` §14.15: per-level physics, WLEVEL composition
  (tide [+ setup estimate]), convergence gate + degradation ladder, hotstart isolation.
- `docs/manuals/OPERATIONS-MANUAL.md`: the new `convergence_retry` config key (default
  false, what each mode does, quarantine directory location and retention), and the
  `swan_convergence_failures_total` metric.
- `docs/ARCHITECTURE.md` SWAN paragraph: TRIAD/SETUP sentence must change (SETUP no
  longer a SWAN command; setup delivered via WLEVEL in Stage 2).
- `SWAN-FIXES-PLAN.md`: new phase entry for this work with the two findings and evidence.
- API-MANUAL §17-18 if the `setup` response field semantics change (§5.2).

## 8. Explicitly out of scope (do not let agents drift into these)

- Grid rotation (`alpc` = beach bearing) — worthwhile future improvement, separate task.
- Any rewrite/"cleanup" of `build_swan_input()` beyond the physics-list change (RULE 4).
- Nesting ratios, bathymetry resolver, domain sizing — all working; leave alone.

## 9. Reading list for the executing coordinator/agents

1. This brief, in full.
2. `c:\tmp\swan-audit-2026-07-19.md` — evidence record (findings F1-F8).
3. SWAN User Manual (`docs/reference/swan-user-manual.pdf`): SETUP + DIFFRACTION commands
   (printed pp. 78-80), BOUNDNEST1 (pp. 51-52), NUMERIC (pp. 85-87). Text extraction:
   pypdf via `uv tool run --from pypdf` on weather-dev (PDF page ≈ printed page + 8).
4. SWAN Technical Manual (`docs/reference/swan-technical-manual.pdf`): §2.6 (setup
   physics, p. 57), Ch. 5 (2D setup implementation + boundary conditions, pp. 119-121).
5. `docs/planning/SWAN-FIXES-PLAN.md` — Phase 14 REGRESSION PREVENTION RULES 1-5 (binding).
6. Code: `swan_formats.py:852-860` (physics block), `:994`/`:1011` (TABLE specs);
   `swan_runner.py:1722-1751` (OMP env), `:1640-1648` (hotstart init), `:1447-1448` and
   `:1790-1801` (hotstart save); `providers/nearshore/swan.py` (orchestration);
   `endpoints/fishing.py:365`.
7. `docs/reference/swan-commands-extract.md` + `swan-nesting-reference.md` (existing
   SWAN INPUT ground rules; RULE 5).
