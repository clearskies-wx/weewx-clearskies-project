# S12 brief — HANDOFF-RESTART (marine repo)

**Round identity:** MARINE-AND-MAPS-PLAN Phase S, task S12 (absorbs S11-2). Date 2026-08-27.
Lead: coordinator. Teammates: `clearskies-api-dev` (code, marine repo) + `clearskies-test-author`
(KATs, marine repo). Auditor: `clearskies-auditor`, adversarial, results-free gate file
`scratch/GATE-S12-DEFINITION.md` (written by the lead; neither teammate edits it).

**Pre-round verification (lead, 2026-08-27):** marine repo `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`
HEAD `2a05856` on `main`, working tree clean, 1 commit ahead of origin (Q17, unpushed — expected).
Local venv `.venv_local\Scripts\python.exe` imports the package and pytest 8.3.5. Live librewxr runs
`b62008f`; it cannot see unpushed code, so all test runs this round are LOCAL (`.venv_local`); the
host rerun is owed after the operator's push (journal J5).

## The design — read it at the source, do not work from this brief's summary
`docs/planning/MARINE-AND-MAPS-PLAN-2026-08-27.md` → §"S12 — HANDOFF-RESTART" (the Plain English
paragraph, "What exists", the numbered **Design** items 1–7, the ruled constant, and the
**Lead mechanics M1–M10**). Every numbered item and every M-item is binding; a deviation is a finding
you report, not a choice you make. Also read Q11 (bottom of the plan) for the operator's words.

## Scope — api-dev (code)
**Files you may modify (allowlist, exhaustive):**
- `weewx_clearskies_marine/services/swan_runner.py` — M1 only: the additive `"band_stations"`
  key at the results append (`~:1088–1094`) built from `pt_by_band_idx`; nothing else in this file.
- `weewx_clearskies_marine/services/surf_pipeline_timestep.py` — M2: `resolve_band_stations_by_transect()`.
- `weewx_clearskies_marine/services/surf_1d_pipeline.py` — M2/M3/M4/M5/M6/M7/M9.
- `weewx_clearskies_marine/services/surf_1d_analytical.py` — M3 (i) only: `onset_at_node0` field on
  `Analytical1DResult` (additive, default `False`) set from the node-0 onset branch
  (`:1042–1046`) and carried through `run_1d_analytical()`'s result construction. No physics change.
- `weewx_clearskies_marine/services/transect_handoff.py` — `HANDOFF_BREAK_CLEARANCE_M = 10.0` (M9).
- `weewx_clearskies_marine/state.py` + `weewx_clearskies_marine/endpoints/health.py` — M8.
- `weewx_clearskies_marine/services/invariants.py` — the INVARIANT_1 docstring/comment only
  (Design item 7 "invariants docstring"); no logic lives there.
- The call sites that feed `run_pipeline(band_stations_by_transect=)` — find them with
  `grep -n "run_pipeline(" weewx_clearskies_marine/` and wire the new kw-only argument at each
  production call site (list them in your scope ack).
- `CHANGELOG.md` (marine repo) — one entry, `S12 HANDOFF-RESTART`.
- Docs in the META repo `c:\CODE\weather-belchertown\docs\` (Design item 7): `ARCHITECTURE.md` (the
  ⚓ MARINE HANDOFF MODEL bullet "The handoff is always before the break" + the detailed handoff
  paragraph that follows it — grep `select_hourly_handoff` to find both), `manuals/PROVIDER-MANUAL.md`
  §14.15, `manuals/API-MANUAL.md` §17 (`handoff_depth_m` semantics), and a NEW
  `docs/decisions/ADR-093-*` Amendment 5 section (M10, status Proposed) inside the existing ADR-093
  file (find it with `Glob docs/decisions/ADR-093*`). Commit the meta-repo docs as ONE separate
  commit in the meta repo (`c:\CODE\weather-belchertown`, branch `main`) — message
  `docs(S12): handoff restart — ARCHITECTURE/PROVIDER-MANUAL/API-MANUAL/ADR-093 A5`.

**Files NOT to touch:** anything under `tests/` (test-author owns them); `swan_domain.py`,
`grid_sizing_chain.py`, `vchain.py`, `service.py`, `swan_formats.py`, every provider module;
`select_hourly_handoff()` itself and `breaking_margin_depth_m()` (the formula's station stays the
FIRST attempt — Design item 3); the `1.3` margin, `gamma`, `Q_B_VISIBLE`, any physics constant
(trigger 1); `_ddd_breaking_march`'s physics; the shared-spectrum (non-per-transect) path in
`run_pipeline` beyond the M9 invariant fix at `:3330–3336`; `docs/archive/`.

**Named traps:** (1) do NOT carry the whole band in `band_stations` — only stations seaward of the
pick (M1). (2) Do NOT serve the last failed attempt on exhaustion (Design item 2 / M6). (3) Do NOT
make the tide fix alone and call invariant 1 done — the clearance test is part of M9. (4) Do NOT
touch `handoff_by_transect` entries' existing keys. (5) Memory: the extra per-station component
lists are small dicts; do not attach spectra (`freqs_hz`/`energy`) anywhere (M-0b rule in the
code comments). (6) Log volume (rules/coding.md §12.4): one WARNING per transect-hour-partition on
skip/exhaustion with counts — never one line per station tried.

**Verification command (before closeout):**
`cd c:\CODE\weather-belchertown\repos\weewx-clearskies-marine; .venv_local\Scripts\python.exe -m pytest tests/test_break_reform_kat.py tests/test_double_break_transect55_kat.py tests/test_marine_invariants.py tests/test_health.py tests/services -q --tb=short -p no:cacheprovider`
Expected: every test that passed at `2a05856` still passes (state the baseline count you measured
FIRST, before any edit, with the same command), plus the test-author's new S12 tests pass once
both of you have committed.

**Deliverable:** commits on marine `main` (local; never push) implementing M1–M9 + CHANGELOG, and
one meta-repo docs commit. Closeout per your agent definition, including the baseline vs final
counts from the command above.

## Scope — test-author (KATs)
**Files you may create/modify:** `tests/test_s12_handoff_restart_kat.py` (new), `tests/fixtures/s12/`
(new; fixture data), and — only if the fixture capture needs it — `tests/conftest.py` additive
fixtures. Nothing else. No production code.

**The KATs are Design item 5 (a)–(d), verbatim from the plan.** Mechanics:
- (a) Huntington transect 4, 2026-08-27T05Z: capture the inputs READ-ONLY from librewxr
  (`ssh -F .local/ssh/config librewxr "..."` from the meta repo root; `sudo -n` works for reads):
  the transect's truncated/untruncated bathymetry profile (profile store —
  `weewx_clearskies_marine/services/profile_store.py` documents the on-disk path), the per-transect
  band TABLE for that hour (`/var/lib/weewx-clearskies/swan/level3_0/` or `level4_*/` — find the
  `TABLE_PT_*` file whose header matches `swan_formats.py:2249`), the tide level from the STOFS
  record of that cycle, and the partition parameters from the journal firing (`sudo journalctl -u
  weewx-clearskies-marine --since "2026-08-27 05:00" --until "2026-08-27 06:00" | grep "invariant 1"`).
  Store them under `tests/fixtures/s12/` with a README naming every source command. The KAT then
  drives `run_pipeline()` (or `_run_pipeline_per_transect()`) with `band_stations_by_transect`
  built from that TABLE and asserts: settled station seaward of the first; outermost marker
  interior by ≥ `HANDOFF_BREAK_CLEARANCE_M`; `invariants.get_invariant_state()` shows no
  INVARIANT_1 firing.
- (b) synthetic profile, node 0 below onset → `restart_attempts == 0` and output byte-identical
  (compare the serialized `PipelineResult` against a run with `band_stations_by_transect=None`).
- (c) synthetic profile breaking at every band station → `handoff_restart_exhausted`: the
  partition result is `None`, nothing served for it, the health counter's `exhausted` increments.
- (d) run `tests/test_break_reform_kat.py` and `tests/test_double_break_transect55_kat.py`
  unchanged and paste the result.
**Pre-change failure transcripts are mandatory** (rules/verification.md KAT mandate): write the
tests against the plan's contract FIRST, run them at HEAD `2a05856` (they must fail — paste the
transcript into the test file's module docstring), then re-run after the dev's commits land.
Coordinate through the lead, not by reading the dev's diff, until the dev's closeout is in.

**Verification command:** same as the dev's, plus `-k s12`. Deliverable: one or more commits on
marine `main` adding the test file + fixtures; closeout with both transcripts.

## Reading list (both teammates, in order)
1. Plan §S12 (all of it) and Q11 — the design.
2. `rules/coding.md` §1 "A model runs on all its inputs or it does not run", §12 memory; `rules/verification.md` KAT section.
3. `weewx_clearskies_marine/services/surf_1d_pipeline.py` — `_truncate_bathy_at_handoff` (`:597–707`),
   `_run_pipeline_per_transect` (`:2001–2330`), `run_pipeline` (`:2598–2700` docstring, `:2917–3020`
   truncation + invariant-4 block, `:3290–3340` second INVARIANT_1 site, `:3480–3500` wire tuple).
4. `weewx_clearskies_marine/services/surf_pipeline_timestep.py` `:205–420` (`resolve_handoff_by_transect`,
   `resolve_partitions_by_transect`) — the read-side pattern to mirror.
5. `weewx_clearskies_marine/services/swan_runner.py` `:717–1110` (`_select_l3_handoff_position_and_spectrum`)
   — where `pt_by_band_idx` and the entry append live; `:1576–1590` (band spacing/clamp).
6. `weewx_clearskies_marine/services/surf_1d_analytical.py` `:60–110` (constants), `:225–290`
   (dataclasses), `:776–800` + `:1020–1150` (march onset/cessation), `:2309–2380` (`run_1d_analytical`).
7. `weewx_clearskies_marine/services/transect_handoff.py` `:1–120` (constants), `:165–240`.
8. `weewx_clearskies_marine/state.py` `:40–120` (record_* pattern) and `endpoints/health.py` `:120–200`,
   `:380–470` (how blocks are assembled).
9. `scratch/inv1/S11-FINDINGS.md` — the evidence this task answers.
10. `docs/ARCHITECTURE.md` ⚓ MARINE HANDOFF MODEL block (`:98–101`) and the detailed paragraph after it.

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
*Coordinator statement for this round:* the handoff-point change (trigger 3), the `band_stations`
contract (trigger 4, inside the marine service), the invariant-1 redefinition and the
`HANDOFF_BREAK_CLEARANCE_M` constant (trigger 1) are operator-approved — plan Q11 ruling
2026-08-27 and the S12 design block. That statement is your full authorization for exactly those
items and nothing else.

**Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change, STOP
and report it via SendMessage — do not modify code to make it pass, and do not delete it on your own
authority. A behavior change and its test updates land in the same commit, per your task's design;
a test you were not told to touch that fails against your change is a finding. Your closeout report
must list every test you modified or deleted, with the reason, and every guard, invariant, or
viability check that fired during your work — including ones you believe are unrelated or
pre-existing.

## Reporting
Scope ack first (SendMessage to the lead); then proceed — the lead pre-confirms this brief unless
your ack lists a file outside the allowlist. Status every ~4 minutes. Closeout per your agent
definition, with the raw command output.
