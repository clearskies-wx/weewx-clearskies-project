# Phase 4A — Adversarial Audit

**Round identity:** Marine Service Separation, Phase 4A, adversarial audit before QC Gate 4A.
**Date:** 2026-07-25. **Owner:** `clearskies-auditor`. **Lead:** coordinator (Opus).

**You do not implement anything.** You report findings. If you are tempted to fix something,
report it instead — the coordinator routes remediation.

---

## What you are auditing

Two rounds of Phase 4A work, all on `main` in both repos. The full commit set:

**API repo** (`repos/weewx-clearskies-api/`), from `27bf24c` (pre-round) through HEAD:

| Commit | Task |
|---|---|
| `7dd9899` | T4A.12 — remove Supplement 4 topographic multipliers |
| `60b1bd2` | delete 3 orphaned `apply_structure_effects` tests |
| `08ce616` | T4A.8 — SurfBeat IG-strip wind `NameError` |
| `00564b9` | `max_hs_m` on `SurfSpotConfig` |
| `ceb8252` | T4A.11 — widened trigger, viability test, L2 fallback |
| `d90bc88` | L2 fallback tests |
| `9c5202f` | `compute_structure_zone_depth` |
| `242410b` | extract `build_obstacle_structures()` |
| `6a98270` | `DomainSizing` (de)serialization |
| `8850e7e` | T4A.3 — apply-time chain via `BackgroundTasks` |
| `db33f01` | T4A.3 Do step 9 — runtime reads caches only |
| `167ad73` | T4A.7 — delete both surviving supplements |
| `8e2710f` | T4A.6 item (g) — handoff depth/source in the response |
| `a54f2cb` | T4A.9 — per-hour handoff selection |
| `a0c45b5` | T4A.10 — QB assertion wired into the pipeline |
| `69957f7` | T4A.9/T4A.10 reopen — handoff across the compute boundary |
| `801dcb3` | drop dead `wave_transform` import in `marine.py` |
| plus B2's final commits | shoreward edge seam + doc drift |

**Dashboard repo:** `452d921` (T4A.6 items a–g).

**Meta repo:** `25afa30`, `4d58957`, `836aecc`, `423aabd`, `ed4613f`, `aef7669`, `586ed6b`,
`d12771b`, plus B2's doc commits.

---

## Mandatory blocks

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only read — `git log`, `git diff`,
> `git show`, `git status`. You are not committing anything.

> **No container edits, and no container writes of any kind.** SSH to `weewx`, `librewxr`, and
> `weather-dev` is **read-only** for you: run tests, read logs, read deployed files, read the
> installed SWAN manual. Never edit a file or run a git write operation on any container.

> **Architectural changes — you report, you do not make them.** If you believe the correct
> remediation for a finding is architectural under the 7-trigger list in `CLAUDE.md`, say so in
> the finding and stop there. Do not propose that someone "just" change a formula, a boundary, a
> data contract, or a schedule as though it were a routine fix.

> **Real findings only.** Every finding cites a specific ADR, rule, manual section, or plan
> acceptance criterion, and identifies one of: (a) a specific failure mode with the inputs that
> trigger it, (b) a missed constraint, or (c) forced downstream rework. Generic trade-off
> observations are not findings. **An empty audit is an acceptable result** — do not manufacture
> findings to look thorough.

---

## Reading list

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — Phase 4A intro, then **T4A.3, T4A.6,
   T4A.7, T4A.8, T4A.9, T4A.10, T4A.11, T4A.12, T4A.13**, the **"Adversarial Audit — Phase 4A"**
   section (its 8 numbered checks are your baseline scope), and **QC Gate 4A**.
2. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` **Amendment 2** in full.
3. `docs/decisions/ADR-095-swan-model-corrections.md` **Amendment 2** in full.
4. `docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md` — **in full, all 592 lines, D1
   through D7.** Read the superseding box at the top of D2 before anything else in that file; it
   records discarded approaches beside the adopted one. A partial read of this file cost the
   coordinator real time this session.
5. `docs/planning/briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md` — the gap inventory.
6. `docs/planning/briefs/P4A-R1-CLEANUP-BRIEF.md` and `P4A-R2-COMPLETE-PHASE-BRIEF.md` — the
   scope blocks and lead calls the agents worked to. **Audit against these, not against your own
   idea of what the tasks should have been.**
7. `rules/coding.md`, `rules/clearskies-process.md`, `reference/clearskies-dev.md`.

---

## Baseline scope — the plan's 8 checks

Run all eight from the plan's "Adversarial Audit — Phase 4A" section. Read them there. They
cover: vocabulary greps, profile resolution, no SWAN CURVE face height in the surf endpoint,
scorer input, no silent fallback, CUDEM at apply time, disk persistence, and a silent-deferral
scan.

Two adjustments the coordinator has already established, so you do not report them as findings:

- **Check 2 (HB profile >200 points with variable spacing) cannot be verified from the repo.**
  The deployed profile on librewxr is still the old 50-point one; regenerating it is T4A.5, which
  has not run. Verify the *code path* produces variable resolution and say the deployed artifact
  is pending T4A.5.
- **Check 6's "SWAN runtime does NOT download CUDEM"** is `db33f01`'s subject. Verify it by the
  `allow_download=False` path, not by inspecting logs from a run that predates the change.

---

## Round-specific scope — where this work is most likely to be wrong

These are the coordinator's own risk assessments. Attack them.

**A1 — Station-index alignment between TABLE and SPECOUT.** The single highest-risk item in the
phase. `_select_l3_handoff_spectra()` in `swan_runner.py` pairs a spectrum with a depth and a
breaking fraction from the same curve. **If those sequences are ever offset by one, nothing
crashes** — the handoff lands at an unintended depth, T4A.10's assertion checks the wrong
station and passes, and the output is plausible small surf. The agent says it used
coordinate-based matching rather than index trust, with a test designed to fail on an
interior-station off-by-one. **Verify that claim by reading the test and confirming it would
actually fail** if the sequences were shifted — a test that only passes on correct input proves
nothing here. Also check the boundary-station exclusion uses the same index space as the
selection.

**A2 — The L2 fallback must not fire on convergence failure.** `run_3level()` now serves
L3-disabled spots from the L2 deep-water reference. Confirm that path is reachable **only** via
`cluster.grid is None` and that a *failed* L3 run still refuses to update the cache. A
convergence failure quietly serving L2 data would hide a real fault — and that preservation
behaviour predates this round and must survive it.

**A3 — `grid is None` as the single source of truth.** A second, structure-only gate in
`run_3level()` was deleted rather than re-pointed. Verify no third gate exists anywhere that can
independently skip or enable L3, and that a spot classified point break / headland / bay with
**no** structures genuinely reaches an L3 run end to end.

**A4 — The compute-offload boundary.** `surf_compute_host = https://192.168.7.22:8770` is
configured on both weewx and librewxr, so the remote path is the production path. The per-hour
handoff was originally computed and then discarded at the wire, and the fix also revealed that
2 of 3 in-process call sites had never passed it. **Check every call site of the pipeline and
every field on the wire.** Confirm no remaining hardcoded handoff constant on the service side,
and that the in-process and remote paths cannot produce different handoffs for identical inputs.

**A5 — Silent fallbacks, as a category.** This phase exists because of them. Grep for and assess
every one you find in the touched code: hardcoded `10.0` handoff, hardcoded `"NAVD88"` datum,
hardcoded `6.0` km L2 offshore, `2.5` km L3 fallback, a bare `0.0` datum offset, and any
`except` that swallows an error without an ERROR-level log. For each: does it fail loudly now, or
does it still substitute a plausible value?

**A6 — The 5 m handoff floor removal.** `_MIN_HANDOFF_DEPTH_M` is gone by operator approval,
**conditional on its removal being watched in testing.** Verify the shallow end is actually
covered by tests, and assess whether anything the floor incidentally protected against now
bites — specifically whether the cached profile resolves depths shallower than 5 m at all, and
what the curve-endpoint targeting helper does when asked for a depth shallower than any profile
sample.

**A7 — Doc-code sync across both repos.** Every code change in this phase that touches behaviour
described in `ARCHITECTURE.md`, `API-MANUAL.md`, `PROVIDER-MANUAL.md`, `DESIGN-MANUAL.md`, or
`DASHBOARD-MANUAL.md` must have a matching doc update. Known-corrected already: API-MANUAL §17,
ARCHITECTURE's SWAN deployment section, DESIGN-MANUAL's beach-profile row, four plan errors.
**Look for what was missed.** In particular check whether the apply-time chain, the
`swan_grid_sizing.json` artifact, the `allow_download` parameter, `max_hs_m`, the new response
fields, and the L2 fallback are all documented where the doc-sync rule requires.

**A8 — T4A.6's dashboard claims.** Item (b)'s substance is that jacking annotations moved to
their own bar-crest distances rather than piggybacking on break points; item (c)'s is that the
partition annotation carries the full structure rather than a flat string. The verification was
done against a synthetic harness because the live dev site runs pre-T4A.1 code, and one jacking
value was hand-added because a real parameter sweep stayed below the render threshold — both
disclosed by the agent. **Assess whether the claims are actually supported by what was tested**,
and check the i18n key paths resolve (a wrong key path was caught during the round; look for
others).

**A9 — Two known gaps, already accepted. Confirm they are recorded, do not re-report as new.**
The apply chain runs via `BackgroundTasks` so T4A.3's "progress visible to operator" criterion is
**not met**; and `run_stationary_level3()` does not refresh L3-disabled spots, so those spots'
forecasts are as stale as the last full run. Both are the operator's call. Your job is to verify
they are written down where a future session will find them, and to flag any *third* gap of the
same kind that nobody has recorded.

---

## Verification environment

Local `py -m pytest` / `py -m ruff` work against the checkout. Container runs need
`sudo -u ubuntu` and `--frozen` or `uv` fails trying to rewrite `uv.lock` — see
`reference/clearskies-dev.md` "Which host runs which tests", updated this session. **SWAN runs on
librewxr, not weewx and not weather-dev**; weather-dev's API checkout is stale and unmanaged and
must not be used for anything.

Note the coordinator has **not yet pushed** the final commits at the time this brief was written.
If a container's checkout is behind local `main`, say so and do not report a stale container
result as a finding about the code.

---

## Deliverable

A findings report, ordered most severe first. For each finding:

- **Severity** — BLOCKER (QC Gate 4A cannot close), or NON-BLOCKING (tracked to a named task).
- **The citation** — ADR, rule, manual section, or plan acceptance criterion.
- **The failure mode** — concrete inputs or state, and the wrong output or behaviour that
  results. Not "this could be fragile."
- **File and line.**
- **Whether remediation would be architectural** under the 7 triggers.

Then a short section: **which QC Gate 4A checklist items you consider satisfied, which not, and
which you could not assess** — with the reason for each you could not assess.

Report via SendMessage. Commit nothing.
