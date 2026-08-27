# S2 brief — CONSISTENCY-SCORING (marine repo; ADR-101 Amendment 1)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S2 (PA6; Q3 A–E + Q10-1 ruled). Date
2026-08-27. Lead: coordinator. Teammates: `clearskies-api-dev` (code) + `clearskies-test-author`
(KATs). Auditor: `clearskies-auditor`, results-free gate `scratch/GATE-S2-DEFINITION.md`.
**Dispatch condition:** after S12's dev closeout is accepted (both rounds edit `swan_runner.py`).

**Pre-round verification (lead, fill at dispatch):** marine HEAD `<hash>`, clean; baseline
`.venv_local\Scripts\python.exe -m pytest tests/enrichment tests/test_rw1_cards_from_model.py -q -p no:cacheprovider` → `<n passed>`;
`scipy` importable in `.venv_local` (the Kimura integrals need `scipy.integrate.dblquad`,
`scipy.special.i0e`) — scipy is ALREADY a marine dependency (grep `pyproject.toml`), not a new one.

## The design — read it at the source (binding, in this order)
1. `docs/decisions/ADR-101-surf-score-geometric-mean.md` → "Amendment 1 (2026-08-27) — Consistency
   (row 5)": the row-5 formula, the data path (ruling D), the single-use rulings, the KAT values.
2. `docs/planning/briefs/SET-TIMING-AND-AMPLITUDE-BRIEF-2026-08-23.md` §3.2 (the `f_int` knots —
   the `f_wps` table is NOT coded, ruling B), §3.3 steps 1–3 and 5, §4.3 (C, C′, S, `f_amp` knots), §7.
3. `docs/planning/briefs/WAVE-GROUP-FORMULAS-VERIFICATION-2026-08-23.md` §G (order of evaluation),
   §A (moments, Tm02, ν — compute ν from moments, never via a Tm ratio), §C (Kimura eqs. 5, 6, 12,
   16, 19), §D (κ at lag Tm02, modulus/m0; ρ_K = κ/2), §F.2 (KAT table + tolerance ±1 %).
4. `docs/planning/briefs/PARTITION-NARROWNESS-SURVEY-2026-08-23.md` §10 (the 1-D collapse and band
   conventions that match `compute_total_m0()`), §2 (grid facts), §7 (half-way rule sanity).
5. Plan §S2 and PA6.

**Lead mechanics (fill the design's implementation gaps; a deviation is a finding):**
- NEW `weewx_clearskies_marine/services/wave_groups.py` — pure functions, no I/O:
  `halfway_band_edges(peak_freqs_hz, f_min, f_max) -> list[tuple[f_lo, f_hi]]` (ruling C; sorted by
  peak frequency; outermost bands extend to the spectrum's own edges);
  `spectrum_1d(freqs_hz, dirs_deg, energy) -> list[float]` (same df/dθ midpoint convention as
  `swan_spectral.compute_total_m0()` — reuse it, do not re-derive);
  `band_moments(freqs, s1d, f_lo, f_hi) -> (m0, m1, m2)`; `nu(m0, m1, m2)`; `tm02(m0, m2)`;
  `qp(freqs, s1d, f_lo, f_hi, m0)`; `kappa(freqs, s1d, f_lo, f_hi, m0, lag_s)` = |∫S e^{i2πf·lag}df|/m0;
  `kimura_run_lengths(kappa, rho_threshold) -> (p11, p22, n_set, n_rep)` with ρ_K = κ/2, bivariate
  Rayleigh (Kimura eqs. 5/6/12) integrated with `scipy.integrate.dblquad` + `scipy.special.i0e`
  (exponent folded), domain 0..12·h_rms, `epsabs=1e-10, epsrel=1e-8`; the set-wave threshold
  constant `SET_WAVE_THRESHOLD_RHO = 1.80` (H1/10 = 1.80 h_rms — ruling A) as a named constant;
  `partition_group_statistics(freqs, dirs, energy, band) -> dict` returning the scalars
  `{nu, qp, kappa, tm02_s, n_rep, n_set, t_set_s, band_hz: [f_lo, f_hi]}` (T_set = N_rep × Tm02);
  `beat_period_s(tp1, tp2)`.
- `services/swan_runner.py` `:3853–3875` (the L2 DWR entry build): for each timestep, take the
  parsed spectrum `_sp` and the PT components; compute the half-way bands from the components'
  peak frequencies (1/`period`), attach `partition_group_statistics(...)`'s scalars to EACH
  component dict (keys above). Nothing attached when the spectrum or components are missing (the
  existing empty-`components` paths unchanged). No arrays attached (M-0b rule).
- `enrichment/surf_scorer.py`: `score_surf()` gains two kw-only params `per_partition_breaks:
  list[dict] | None = None` (the endpoint's serialized `PartitionBreakInfo` list — `mean_face_height_m`,
  `partition_index`) and `main_zone_face_height_m: float | None = None`.
  `_score_consistency(multi_swell, per_partition_breaks, main_zone_face_height_m)`:
  dominant = the same dominant-selection rule Power uses (`_effective_swell`/index 0 convention —
  cite the line); if the dominant component carries `t_set_s` → **timing** `= _f_int(T_set/60)` with
  the beat override (secondary share ≥ 0.25 of summed partition `energy`, 60 ≤ T_beat ≤ 1800 s →
  `T_set = max(T_set, T_beat)`); **amplitude**: `H_set = main_zone_face_height_m`,
  `Hs_total = H_set / 1.27`, `Hs_dom = mean_face_height_m(dominant) / 1.27` (the spot-wide
  per-partition mean — the main-zone-restricted per-partition value does not exist; documented
  approximation, journal J9), `Hs_rest = sqrt(max(Hs_total² − Hs_dom², 0))`, `H_lull`, `C`, `C′`
  clamped to [0, 1], `S = 0.4 C′ + 0.6 κ_dom`; when either face height is `None` → `S = κ_dom`
  (brief §4.5 fallback); `consistency = 0.6 × timing + 0.4 × f_amp(S)`. Dominant WITHOUT
  `t_set_s` → today's `_consistency_fallback_score(swell_dominance)` for the whole factor,
  byte-identical. Curve knots as module constants with the brief's citations; piecewise-linear
  `_interp_knots()` helper (grep first for an existing one — DRY).
- `endpoints/surf.py` `~:1312–1330`: pass `per_partition_breaks=` (the already-serialized list at
  `:1459`, computed once, reused) and `main_zone_face_height_m=` from the pipeline result.
- `models/responses.py` `SpectralWaveComponent`: optional fields `nu`, `qp`, `kappa`, `tm02S`,
  `nRep`, `tSetS`, `bandHz` (camelCase on the wire, per the model's existing convention);
  `_build_multi_swell()` passes them through. Then VERIFY the API proxies them: read
  `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_response_conversion.py` and the
  API's marine models — if the API drops or rejects unknown component fields, STOP and report (the
  API-side change is a separate commit in the API repo, same round, same allowlist rules).
- Docs (meta, separate commit): API-MANUAL §17 (`multiSwell` component fields + the Consistency
  definition), DESIGN-MANUAL scoring explainer text for Consistency (ADR-101 A1 wording),
  CHANGELOG; the marine `CHANGELOG.md`.

## Scope — api-dev
**Allowlist:** `weewx_clearskies_marine/services/wave_groups.py` (new), `services/swan_runner.py`
(ONLY `:3853–3875`), `enrichment/surf_scorer.py`, `endpoints/surf.py` (the call site only),
`models/responses.py` (the component model + `_build_multi_swell` if it lives there), marine
`CHANGELOG.md`; API repo ONLY if the proxy verification demands it (report first); meta docs listed.
**NOT to touch:** the five top-level weights, Size/Shape/Conditions/Power, `_swell_dominance`, the
stack admin weights section, the dashboard, tests/, anything else in `swan_runner.py`.
**Named traps:** no `f_wps` term (ruling B); threshold ρ = 1.80 not √2 (ruling A) — the §F.2 table
is at √2 and is the INTEGRATION-ROUTINE check only; κ at lag Tm02, modulus not square; ν from
moments; never attach arrays; the fallback must be byte-identical; log volume — one DEBUG per
timestep at most.
**Verification:** baseline command + `tests/test_s2_consistency_kat.py` + `tests/services/test_wave_groups_kat.py`.

## Scope — test-author
**Files:** `tests/services/test_wave_groups_kat.py` (new), `tests/test_s2_consistency_kat.py` (new).
Independent references (rules/verification.md): your OWN dblquad implementation of Kimura's
integrals written fresh in the test (not imported from `wave_groups.py`) → §F.2's table at ρ = √2
(κ 0.3/0.5/0.8 → N_rep 9.06/10.15/15.11, ±1 %) AND the same routine at ρ = 1.80 (state the values
in the test before looking at the implementation); the two-bin spectrum of the verification doc §A
(E = 1 at 0.08 and 0.12 Hz → m0 = 2, Tm01 = 10.0, Tm02 = 9.807, ν = 0.2); κ = 1 for a single-bin
spectrum, → 0 for white noise; half-way bands; `f_int`/`f_amp` knot values and midpoints; the brief
§4.3 worked C values (pure swell 0.67, all-filler 0.50, equal two-swell 0.58); whole-factor worked
examples (clean swell κ 0.8, no filler → S 0.88 → f_amp 1.0; ...); fallback byte-identity when the
dominant carries no `t_set_s`. Pre-change failure transcripts in each module docstring.

## Reading list (both)
Design sources 1–5 above; `weewx_clearskies_marine/enrichment/surf_scorer.py` `:1–160` (constants,
weights), `:320–360`, `:680–720` (`_swell_dominance`), `:860–890`, `:940–1130` (`score_surf`);
`services/swan_spectral.py` `:60–120`, `:960–1050` (`compute_total_m0`, `parse_table_pt_partitions`);
`services/swan_runner.py` `:3812–3906`; `endpoints/surf.py` `:1230–1340`, `:1450–1470`;
`models/responses.py` (grep `SpectralWaveComponent`); `services/surf_1d_pipeline.py` `:280–320`
(`PartitionBreakInfo`); `rules/coding.md` §3 DRY, §12; `rules/verification.md` KAT mandate.

## Mandatory blocks
**Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`,
or `git checkout` of remote branches. You may only `git add <explicit paths>`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve
it yourself. Edit and commit ONLY on the local machine; SSH to containers is read-only.

**Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your
task requires one, STOP and report via SendMessage — do not implement it, do not work around it, do
not pick an option. A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. This does NOT cover changing how the same equation is solved — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
**These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
**The coordinator's ruling on your report is FINAL.** You surface an architectural concern ONCE, via SendMessage, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority.
*Coordinator statement:* the Consistency formula (trigger 1) and the per-partition scalar fields on
the spectral entries and the wire (trigger 4) are operator-approved — plan PA6 (EVO-Q14 "q14
recommendation is fine"; Q3 A–E "yes"; Q10-1 "yes"). That statement is your full authorization for
exactly those items and nothing else.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first; status every ~4 minutes; closeout per your agent definition with raw output.
