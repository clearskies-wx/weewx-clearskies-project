# Phase 4B — Agent A brief (T4B.1, T4B.3, T4B.4)

**Round:** Marine Service Separation, Phase 4B. **Date:** 2026-07-25.
**Lead:** coordinator (Opus). **You:** `clearskies-api-dev`. **Peer:** Agent B (T4B.2 — owns
`services/swan_spectral.py` and `services/surf_1d_pipeline.py`; do not touch those two files).
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

### What the operator has ALREADY approved for this phase — inside the envelope, do not re-raise

- The handoff moves from one point per spot to **one per transect** (trigger 3).
- `handoff_by_transect` carries **distinct values per transect** (trigger 4). Carrying
  per-transect handoff data from `swan_runner.py` through to the endpoints is the necessary
  mechanism of that approval and is inside the envelope.
- Station spacing **50 m → 10 m** for the per-transect point band (trigger 3).

### What is NOT approved

- Replacing `decompose_spectrum()` with SWAN's watershed partitioning (trigger 1). That is Agent
  B's task and it is **measure-only**. Both partitioning paths must still work when Phase 4B
  closes. You must not delete, disable, or bypass the existing spectral path.
- **SurfBeat is out of scope entirely.** T4B.5 is closed: it stays alongshore-uniform. Do not
  touch `services/surfbeat_runner.py`, including its `_STATION_SPACING_M = 25.0`.
- Anything else hitting a trigger.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not
resolve it yourself.

**No worktrees.** Work in the primary local checkout at
`c:\CODE\weather-belchertown\repos\weewx-clearskies-api`.

**Never edit or commit on a container.** All editing and committing happens on this machine. SSH
to `weewx` / `librewxr` is READ-ONLY (run tests, read logs, check service status).

---

## Pre-round verification (done by the lead — this is your clean starting state)

| Check | Result |
|---|---|
| API repo HEAD | `eca80ee`, working tree clean |
| Remote sync | `## main...origin/main` — no ahead/behind |
| Meta repo HEAD | `cd82b71`, clean |
| Deployed | librewxr and weewx both at `eca80ee`, services healthy |

Known pre-existing breakage you did **not** cause and are **not** asked to fix:
`tests/services/test_swan_runner.py` has 15 collection errors (constructs `SWANRunner` without
`inner_bbox`, required since `46eb883`). If your work makes fixing it trivial and in-file, say so
via SendMessage before doing it — do not expand scope silently.

## Reading list — read these BEFORE writing any code

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — the **whole** Phase 4B section
   (`## Phase 4B — Per-Transect Grid-Derived Handoff` through `### QC Gate 4B`). Not the summary.
   Read "The finding", "Verified SWAN mechanics", the ⚠ trigger table, T4B.1, T4B.3, T4B.4,
   T4B.5 (so you know what NOT to touch), T4B.6 (so you know what your output must feed), and
   QC Gate 4B. Your tasks are **T4B.1, T4B.3, T4B.4**.
2. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — Amendment 2 in full (lines
   93–237). This governs the handoff, the grid's shoreward reach, and the L3 trigger.
3. `docs/decisions/ADR-095-swan-model-corrections.md` — Amendments 1 and 2 in full (lines
   83–144). Amendment 1's "Handoff SPECOUT" paragraph and Amendment 2's "Handoff SPECOUT
   placement — amended" and "Decision 1 (CURVE transect) — amended again" are directly load
   bearing for your work.
4. `docs/reference/swan-commands-extract.md` — `POINTS`, `TABLE`, `SPECOUT`, and the
   "Spectral partitioning output (PT* quantities)" section. **These SWAN syntax facts are
   already verified against the 41.51 manual and the Fortran source. Use them. Do not
   re-derive them, and do not re-check them against the manual.**
5. `docs/ARCHITECTURE.md` — the "SWAN nearshore model (ADR-093 …)" callout (the long block
   starting `> **SWAN nearshore model`) and the "Current deployment" sentences inside it.
6. `reference/clearskies-dev.md` — "librewxr (compute host)", "Which host runs which tests",
   "Deploy before you test", "Run pytest — always on `weewx`".
7. `rules/coding.md` §1 (persistence rule, "Treat your own output as untrusted"), §2, §3.
8. `rules/clearskies-process.md` — "Research-to-implementation discipline" (every rule in it is
   a SWAN rule you can violate), "Scope binding before agent dispatch".
9. The code you are modifying, in full for the functions you touch:
   `weewx_clearskies_api/services/swan_formats.py` (the L3 output block ~1370–1490 and
   `compute_spot_transect()` ~778–1050), `services/swan_runner.py`
   (`_select_l3_handoff_spectra()` ~660–900, `_l3_fallback_points_from_dwr()` ~152–260, and
   `_parse_transect_table()`), `services/transect_handoff.py` (`select_hourly_handoff()`,
   `refine_handoff_with_qb()`), `services/swan_domain.py`.

## Lead calls you must follow — do not re-derive these

**LC-4B-1 — The diagnostic per-spot CURVE + SPECOUT is RETAINED, not replaced.**
T4B.1 Do step 1 says "Replace the one-CURVE-per-spot emission with `POINTS` per transect." Read
literally that deletes the CURVE and with it the only 2D spectrum L3 produces — which is
ADR-095 Amendment 1's named L3 diagnostic/validation output, is restated as "remains
diagnostic-only" by Amendment 2, and is the live input to `decompose_spectrum()`, which the
operator requires keep working through Phase 4B. Per `rules/clearskies-process.md` ("ADR wins on
conflict — fix the plan to match"), the ADR governs. **"Replace" means the handoff stops being
read from the CURVE. The CURVE, its TABLE, and its SPECOUT stay emitted.** Your per-transect
`POINTS` sets are emitted *alongside* them. The lead corrects the plan text in T4B.7.

**LC-4B-2 — 10 m spacing applies to the new per-transect POINTS band, not to the diagnostic
CURVE.** T4B.1 Do step 2 names the mechanism: the per-transect band is at 10 m. Leave
`compute_spot_transect(spacing_m=50.0)` alone — it now only sizes the diagnostic CURVE, and
taking it to 10 m would multiply SPECOUT output ~5× (measured baseline: `SPEC_1.txt` 7.4 MB for
18 stations × 73 timesteps) for diagnostic-only data. If you believe this is wrong, SendMessage —
do not change it.

**LC-4B-3 — Your FIRST commit is one line, and you report it immediately.**
Before anything else: add `PTHSIGN PTRTP PTDIR PTDSPR` to the **existing** per-spot CURVE
`TABLE` line in `swan_formats.py` (the `TABLE '{curve_name}' HEAD '{table_file}' TIME XP YP …`
emission), update the adjacent `logger.info("SWAN TABLE output columns: %s", …)` string to match,
commit it alone, and SendMessage the lead with the commit hash. Nothing else in that commit.

Reason: Agent B's watershed-vs-`decompose_spectrum()` comparison needs real `PT*` columns at the
same stations `SPECOUT` already writes spectra at. `TABLE 'CVn'` and `SPECOUT 'CVn'` are the same
station set today, so this one line makes the comparison possible on real data. The lead deploys
and runs SWAN on librewxr off that commit while you continue. Without it B's evidence would be
synthetic, and the operator's trigger-1 decision would rest on made-up numbers.

Carry the same four `PT*` keywords onto the per-transect `TABLE` you emit in T4B.1 step 4.

**LC-4B-4 — `PTDIR`'s exception value is `-999`. Every other `PT*` variable uses `-9`.**
Verified in `swanmain.ftn:2649+`; recorded in `docs/reference/swan-commands-extract.md`. You are
emitting, not parsing, so this mostly matters for the header/column-count arithmetic — each
keyword expands to **10** columns, so four keywords add **40** columns. Get the column-index
arithmetic in `_parse_transect_table()` right, or every downstream field shifts. Agent B owns the
`PT*` value parsing; you own not breaking the existing columns.

## Scope

### Files you may create or modify — exhaustive

- `weewx_clearskies_api/services/swan_formats.py`
- `weewx_clearskies_api/services/swan_runner.py`
- `weewx_clearskies_api/services/transect_handoff.py`
- `weewx_clearskies_api/services/swan_domain.py`
- `tests/test_swan_runner_handoff.py`
- `tests/test_transect_handoff.py`
- `tests/services/test_swan_domain.py`

### Files you must NOT touch

- `weewx_clearskies_api/services/swan_spectral.py` and
  `weewx_clearskies_api/services/surf_1d_pipeline.py` — **Agent B owns these, working
  concurrently.** If your change needs something in them, SendMessage the lead; do not edit.
- `weewx_clearskies_api/services/surfbeat_runner.py` — T4B.5 is closed.
- `weewx_clearskies_api/endpoints/surf.py`, `endpoints/beach_profile.py`,
  `services/compute_client.py`, `services/compute_service.py` — these are **T4B.6**, a later
  task. Your job is to make `swan_runner.py` *produce* distinct per-transect values; wiring them
  through the five call sites is not yours.
- Anything in the meta repo (`c:\CODE\weather-belchertown\docs\`, `rules\`, `reference\`) — the
  lead and `clearskies-docs-author` own docs. **Exception:** if your code changes behaviour a
  manual describes, say so in your closeout so the lead routes the doc update; do not edit the
  manual yourself.
- Any file on any container.

### Verification command

Run on **weewx** (librewxr has no test dependencies), after the lead has pulled your commits
there — ask the lead via SendMessage when you want a `deploy-api.sh --no-restart`:

```
ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && /home/ubuntu/.local/bin/uv run --frozen pytest tests/test_swan_runner_handoff.py tests/test_transect_handoff.py tests/services/test_swan_domain.py -q'"
```

Run the **whole** `tests/services/` directory once at closeout as well — a per-file run cannot
find a broken file that is not in the list (that is how the 15 `test_swan_runner.py` collection
errors survived for many commits). Never run the full suite.

You may run pytest locally on Windows while iterating, but **a green Windows run is not
verification** — same-day 2026-07-25 incident: a test passed on Windows and failed on Linux
because the code under test had an inline `Path("/etc/weewx-clearskies/...")` literal. Any test
touching a config path must be isolated to `tmp_path`.

### Deliverable definition

What the lead expects to see in `git log` on the local `main` when you are done:

- Commit 1: the one-line `PT*` addition to the existing CURVE TABLE (LC-4B-3), reported
  immediately.
- Further commits implementing T4B.1, T4B.3, T4B.4, each touching only files from the list
  above.
- A closeout SendMessage carrying: commit hashes per task, the pytest command you ran and its
  verbatim result line, the **logged point count and total output size** T4B.1's Accept
  criterion requires, and an explicit statement of anything you did NOT do and why.

## Open questions — SendMessage the lead, do not resolve unilaterally

1. **Where L2's per-hour Hs comes from.** T4B.1 Do step 3 bounds the per-transect point band
   using L2's per-hour Hs, "available because L2 completes before L3 is written." Verify that is
   actually true in `swan_runner.py`'s L2→L3 ordering, at the point where the L3 INPUT file is
   written. If L2's Hs is not available there, that is a finding — report it, do not substitute
   a different quantity.
2. **Whether `swan_domain.py` needs to change at all.** The plan lists it under T4B.1's files.
   Grid geometry is frozen at setup and must not move (`rules/clearskies-process.md`, "All SWAN
   grid geometry is fixed at setup time — no runtime overrides", and ADR-093 Amendment 2 §1–2).
   If T4B.1 turns out to need no `swan_domain.py` change, say so — do not manufacture one.
3. **Any per-transect handoff data shape that must cross out of `swan_runner.py`.** The approval
   envelope covers this, but describe the shape you land on in your closeout so the lead can
   check T4B.6's five call sites against it.
4. **If the clamp rate does not drop.** T4B.3's Accept criterion is that it falls materially
   below the 73/73 measured on 2026-07-25. If your implementation cannot achieve that, report it
   as a finding with the measured rate — do not adjust a threshold to make the criterion pass.
