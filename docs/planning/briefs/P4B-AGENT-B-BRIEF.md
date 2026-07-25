# Phase 4B — Agent B brief (T4B.2)

**Round:** Marine Service Separation, Phase 4B. **Date:** 2026-07-25.
**Lead:** coordinator (Opus). **You:** `clearskies-api-dev`. **Peer:** Agent A (T4B.1/T4B.3/T4B.4
— owns `services/swan_formats.py`, `services/swan_runner.py`, `services/transect_handoff.py`,
`services/swan_domain.py`; do not touch those four files).
**Auditor:** `clearskies-auditor`, runs after both agents close.

---

## Architectural changes — STOP, do not proceed.

You may not make an architectural change. If your task requires one, STOP and report via
SendMessage — do not implement it, do not work around it, do not pick an option.

A change is architectural if it does ANY of these (mechanical test, not judgment):

1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or
   criterion inside one. **This does NOT cover changing how the same equation is solved** —
   iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which
   equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural.
   An approximation that does not converge to the original equation IS a formula change and is
   covered.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible
   for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units crossing
   a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.

**These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then
your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a
finding to report, not permission to change code).

You MAY still: resolve a contradiction between two statements inside the same document by taking
the reading its own examples support (and say so); apply a rule already written in the rules
files; fix code that diverges from its own stated contract.

## ⚠ YOUR TASK IS TRIGGER 1 AND IS **NOT** APPROVED. READ THIS PARAGRAPH TWICE.

Replacing `decompose_spectrum()` with SWAN's Hanson & Phillips watershed partitioning is a
formula/algorithm change — trigger 1. **The operator has approved building and measuring the
comparison ONLY. The operator decides on the numbers.**

Concretely, this means:

- **`decompose_spectrum()` is not deleted, not disabled, not deprecated, and not bypassed.**
  When you are done, both partitioning paths must work, and the path in production must still be
  the existing one unless the operator says otherwise.
- Add the watershed path **alongside**, behind an explicit selector, defaulting to the existing
  path. Do not make watershed the default. Do not remove the `±4-bin neighbourhood` code.
- Your headline deliverable is **the comparison table**, on **real data**, with the evidence the
  operator needs: partition count, per-partition Hs, and whether Σ partition m0 equals total m0,
  for each algorithm on the same spectra.
- If you conclude one algorithm is better, say so with numbers. Then stop. Do not act on it.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not
resolve it yourself.

**No worktrees.** Work in the primary local checkout at
`c:\CODE\weather-belchertown\repos\weewx-clearskies-api`.

**Never edit or commit on a container.** All editing and committing happens on this machine. SSH
to `weewx` / `librewxr` is READ-ONLY (run tests, read logs, read SWAN output files).

---

## Pre-round verification (done by the lead — this is your clean starting state)

| Check | Result |
|---|---|
| API repo HEAD | `eca80ee`, working tree clean |
| Remote sync | `## main...origin/main` — no ahead/behind |
| Meta repo HEAD | `cd82b71`, clean |
| Deployed | librewxr and weewx both at `eca80ee`, services healthy |

## The sequencing problem you raised last session — resolved. No synthetic data.

You correctly flagged that real `PT*` TABLE columns do not exist until the emission change lands,
so your watershed side would be synthetic. The lead's resolution (LC-4B-3):

Your comparison does **not** need Agent A's per-transect point band. It needs `PT*` columns at
the *same stations where `SPECOUT` already writes spectra*. Those stations exist today —
`swan_formats.py` emits `TABLE 'CVn'` and `SPECOUT 'CVn'` on the same CURVE. **Agent A's first
commit adds `PTHSIGN PTRTP PTDIR PTDSPR` to that existing CURVE TABLE line, and nothing else.**
The lead then deploys that commit to librewxr and runs SWAN, producing a real `TABLE_1.txt` (with
`PT*`) and a real `SPEC_1.txt` from the same run at the same stations.

**Work order for you:**

1. Build the parser and the comparison harness now, with unit tests over fixtures you construct
   from the documented column layout. This is not the comparison — it is the tool.
2. SendMessage the lead when you are ready for real data. The lead tells you the path to the run
   output on librewxr and you read it over read-only SSH.
3. Run the comparison on that real data and record the table.

**Nothing in your deliverable may be labelled or footnoted as synthetic.** If real data has not
arrived by the time you would otherwise close, STOP and say so — do not substitute.

## Reading list — read these BEFORE writing any code

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — the **whole** Phase 4B section
   (`## Phase 4B — Per-Transect Grid-Derived Handoff` through `### QC Gate 4B`). Not the summary.
   Read "The finding" (especially item 5, which is the defect you are measuring), "Verified SWAN
   mechanics" (the column-layout and exception-value table), the ⚠ trigger table, T4B.2, and
   QC Gate 4B. Your task is **T4B.2**.
2. `docs/reference/swan-commands-extract.md` — the whole "Spectral partitioning output (PT*
   quantities)" section, plus `TABLE`. **These SWAN facts are already verified against the
   41.51 manual and the Fortran source. Use them. Do not re-derive them.**
3. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — Amendment 2 §2, specifically the
   "SwellTrack marches bulk parameters per partition and reconstructs no surface" reasoning in
   the *Rejected, for the record* paragraph. That sentence is why TABLE `PT*` can feed SwellTrack
   at all.
4. `docs/decisions/ADR-095-swan-model-corrections.md` — Amendment 1's "Swell decomposition
   reference — amended" paragraph. Note that the **swell display card's** multiSwell components
   come from the L2 deep-water reference SPECOUT, a different consumer from the handoff. Do not
   change what feeds the card.
5. `reference/clearskies-dev.md` — "librewxr (compute host)", "Which host runs which tests",
   "Run pytest — always on `weewx`", "Read SWAN run history on librewxr".
6. `rules/coding.md` §1 ("Treat your own output as untrusted", "Validate inputs at trust
   boundaries"), §2, §3.
7. `rules/clearskies-process.md` — "Research-to-implementation discipline" in full.
8. The code, in full for what you touch: `weewx_clearskies_api/services/swan_spectral.py`
   (all of `decompose_spectrum()` and the SPECOUT parsing above it),
   `services/surf_1d_pipeline.py` (the `partitions` structure and how `run_pipeline()` consumes
   it — see the per-transect loop around lines 960–1050 and `_aggregate_partition_breaks`).
   Read `services/swan_runner.py`'s `_parse_transect_table()` and
   `_select_l3_handoff_spectra()` for context — **read only, Agent A owns that file.**

## Lead calls you must follow — do not re-derive these

**LC-4B-4 — `PTDIR`'s exception value is `-999`. Every other `PT*` variable uses `-9`.**
Verified in `swanmain.ftn:2649+` (`OVEXCV` per `IVTYPE`). A parser assuming one uniform sentinel
reads absent partitions as real data — a `-9 m` wave height is obviously wrong and would be
caught, but a partition direction of `-9°` is a plausible-looking northerly and would not.
Absent partitions carry the exception value — **not** zero and **not** blank. Each keyword
expands to exactly **10** columns (`HsPT01`…`HsPT10`); individual partitions cannot be requested.
QC Gate 4B tests this explicitly: *"`PTDIR`'s `-999` and the other variables' `-9` are both
handled; no partition read as a real 0."* Write a test that fails if a single uniform sentinel
is assumed.

**LC-4B-5 — Partition 01 is wind sea; 02–10 are swells in descending Hs.** T4B.2 Do step 3 says
to feed 02–10 and 01 into the existing per-partition SwellTrack path. Preserve whatever ordering
and semantics `run_pipeline()`'s existing `partitions` list carries — if the existing list has an
implicit ordering contract that watershed order violates, that is a finding to report, not a
thing to quietly re-sort.

**LC-4B-6 — Energy conservation is the measurement, not an assertion.** The plan's finding 5 is
that the current fixed ±4-bin windows overlap with no cell exclusion, so bins are counted into
multiple partitions and others into none. Your comparison must **measure** Σ partition m0 against
total m0 for both algorithms on the same spectra and report the numbers. Do not assert
conservation from the algorithm's description.

## Scope

### Files you may create or modify — exhaustive

- `weewx_clearskies_api/services/swan_spectral.py`
- `weewx_clearskies_api/services/surf_1d_pipeline.py`
- `tests/test_swan_spectral_multi.py`
- `tests/test_surf_1d_pipeline.py`
- One new comparison harness file — `scripts/compare_partitioning.py` in the API repo. It reads a
  SWAN `TABLE_*.txt` and the matching `SPEC_*.txt`, runs both algorithms, and prints the
  comparison table. Keep it a standalone script; it is not part of the service.

### Files you must NOT touch

- `weewx_clearskies_api/services/swan_formats.py`, `services/swan_runner.py`,
  `services/transect_handoff.py`, `services/swan_domain.py` — **Agent A owns these, working
  concurrently.** If your parser needs to be called from `swan_runner.py`, expose it as a public
  function in `swan_spectral.py` and SendMessage the lead with its signature; the lead
  coordinates the wiring. Do not edit A's files.
- `weewx_clearskies_api/services/surfbeat_runner.py` — T4B.5 is closed; SurfBeat stays
  alongshore-uniform.
- `weewx_clearskies_api/endpoints/surf.py`, `endpoints/beach_profile.py`,
  `services/compute_client.py`, `services/compute_service.py` — T4B.6, a later task.
- Anything in the meta repo. **The comparison table itself gets recorded in the plan by the lead
  or `clearskies-docs-author`, not by you** — deliver it in your closeout message and as output
  from your script.
- Any file on any container.

### Verification command

Run on **weewx** (librewxr has no test dependencies), after the lead has pulled your commits
there — ask the lead via SendMessage when you want a `deploy-api.sh --no-restart`:

```
ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && /home/ubuntu/.local/bin/uv run --frozen pytest tests/test_swan_spectral_multi.py tests/test_surf_1d_pipeline.py tests/test_surf_1d_consistency.py -q'"
```

Never run the full suite. A green Windows run is not verification — Windows/Linux divergence is
real on this project (inline POSIX path literals resolve harmlessly on Windows and raise
`PermissionError` on Linux). Any test touching a config path must be isolated to `tmp_path`.

### Deliverable definition

What the lead expects when you are done:

- Commits on local `main` touching only files from the list above.
- Both partitioning paths working, existing path still the default.
- `PT*` parser with the two-sentinel handling and a test that fails on a uniform-sentinel
  assumption.
- **The comparison table, on real SWAN output**, covering: partition count per algorithm,
  per-partition Hs, Σ partition m0 vs total m0, and the 2026-07-25 12°-separation case
  (2.9 ft @ 12 s @ 184° and 0.7 ft @ 23 s @ 196°) — does watershed resolve it as two partitions
  where the ±4-bin window smears it into one?
- A closeout SendMessage carrying: commit hashes, the pytest command and its verbatim result
  line, the comparison table, the path to the real SWAN output you read, and an explicit
  statement of anything you did NOT do and why.

## Open questions — SendMessage the lead, do not resolve unilaterally

1. **How the selector between the two paths is expressed.** A config key is trigger 7 and is not
   approved. Propose a mechanism (function parameter, module constant, call-site argument) and
   get the lead's confirmation before building it.
2. **Whether the existing `partitions` list has an ordering contract** that watershed order would
   violate (LC-4B-5).
3. **If the real data does not contain the 12°-separation sea state.** The 2026-07-25 07:06Z run
   had it; a fresh run may not. Report what the real data actually contains — do not construct
   the case.
4. **If Σ partition m0 turns out to conserve under the existing algorithm too.** That would
   contradict the plan's finding 5. Report it as a finding; it changes the operator's decision.
