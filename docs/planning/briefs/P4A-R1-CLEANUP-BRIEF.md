# Phase 4A — Round 1 (2026-07-25 resume) — independent cleanup tasks

**Round identity:** Marine Service Separation, Phase 4A, resume-session Round 1.
**Date:** 2026-07-25. **Lead:** coordinator (Opus). **Auditor:** `clearskies-auditor` (Phase 4A adversarial audit, after all tasks land).

Three tasks that are independent of the L3/1D boundary work (T4A.9–T4A.11) and of each
other. They run in parallel. Each agent gets its own section below and touches **only** the
files named in its own section.

---

## Pre-round verification (coordinator, 2026-07-25)

| Check | Result |
|---|---|
| API repo `main` HEAD | `27bf24c`, working tree **clean**, ahead 10 of `origin/main` |
| Meta repo `main` HEAD | `68b414d`, working tree clean |
| Dashboard repo | `20c6e50`, **uncommitted** `public/card-manifest.json` — no dashboard work in this round |
| weewx container API | `0d87b28` (behind local) |
| librewxr API repo / SWAN repo | `bfff1f7` / `fc5680a`; `weewx-clearskies-swan` service **active** |
| API test baseline | 2 failed, 123 passed at `11b5242` (both pre-existing `test_download_profile_mock*`) |
| T4A.8 defect confirmed present | `endpoints/surf.py` uses `ts_wind_speed`/`ts_wind_direction` at lines 788, 789, 807, 808, 819, 820; both are first assigned at lines 1002–1003 and 1015–1016 — inside a **later** loop |
| T4A.12 target confirmed present | `enrichment/wave_transform.py`: `TOPO_MULTIPLIERS` (line 53), `apply_topographic_adjustment()` (line 206), call site (lines 299–303) |
| API-MANUAL §17 state | Supplement 4 **already** marked "REMOVED 2026-07-25" (line 2582). Two residual stale statements remain — see A1 spec. |

---

## Blocks that apply to EVERY agent in this round

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
> SendMessage. Do not resolve it yourself.

> **Staging discipline:** Other agents are working in the same repos concurrently. **Never
> run `git add -A`, `git add .`, or `git commit -a`.** Stage only the exact paths listed in
> your own scope block, by name.

> **No container edits:** All editing and committing happens on this local machine. Never
> edit a source file on `weewx`, `weather-dev`, `librewxr`, or any container. Never run any
> git write operation on a container. SSH to containers is read-only (run tests, read logs).

> **Architectural changes — STOP, do not proceed.** You may not make an architectural
> change. If your task requires one, STOP and report via SendMessage — do not implement it,
> do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient,
>    threshold or criterion inside one. **This does NOT cover changing how the same equation
>    is solved** — iterative vs closed-form, solver tolerance, vectorisation. Test: does it
>    change *which equation is satisfied*, or only *how precisely/efficiently*? Only the
>    first is architectural. An approximation that does not converge to the original equation
>    IS a formula change and is covered.
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is
>    responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components — field names, shapes, nullability, units
>    crossing a boundary.
> 5. Changes where a computation happens — host, service, process, or lifecycle stage.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "my task's acceptance criteria are unreachable without it"
> (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale
> document is a finding to report, not permission to change code).
>
> You MAY still: resolve a contradiction between two statements inside the same document by
> taking the reading its own examples support (and say so); apply a rule already written in
> the rules files; fix code that diverges from its own stated contract.

> **Scope acknowledgment required before any code.** SendMessage the coordinator with one
> paragraph: what you will deliver, what you will not touch, and the exact verification
> command you will run before closeout. Wait for confirmation. No edits before then.

> **Never run the full pytest suite.** Run only the test files matching the source files you
> changed.

---

## Agent A1 — T4A.12: remove Supplement 4 topographic multipliers

**Agent type:** `clearskies-api-dev`

### Reading list (read before any edit)

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — **T4A.12** in full (the Do and Accept
   lists are your specification; do not work from any summary of them).
2. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — **Amendment 2 §5b** only.
   This is the governing decision and it is operator-approved.
3. `docs/manuals/API-MANUAL.md` lines 2548–2593 — the "Wave transform supplements" section.
   Supplement 4 is already marked REMOVED there; two statements around it are not yet
   consistent with that (see spec below).
4. `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py` — the file
   you are changing, in full. It is 312 lines.
5. `rules/coding.md` §3 "No dead code" and §2 "Comment the WHY, not the WHAT".

### Spec

Do exactly what T4A.12's Do list says. Two clarifications the plan does not state, both of
which are coordinator lead calls for this round:

- **LC-R1-1 — Supplement 1 stays.** T4A.12's Accept bullet says "Supplements 1 and 3 still
  fire." Supplement 1 (the Battjes-1974 breaker-index correction at
  `wave_transform.py` lines 277–291) in fact **never executes** at runtime — its guard
  requires `spot_config.bathymetric_profile`, which `marine_config.py` deliberately no
  longer reads. **Do not remove it and do not fix it.** Its disposition belongs to T4A.7,
  which is a separate operator-gated decision. Read that Accept bullet as "this task does
  not touch supplements 1 or 3." If you find that reading wrong, STOP and report — do not
  choose.
- **LC-R1-2 — the module docstring is part of the change.** Lines 1–31 describe three
  supplements including the topographic one, and the numbering inside the docstring
  disagrees with the section headers further down. Bring the docstring in line with what
  the file does after your edit. Do not renumber the surviving supplements — the numbers
  1/2/3/4 are referenced by ADR-095, ADR-093 Amendment 2, and API-MANUAL §17.

Doc-code sync (required in the same round, per CLAUDE.md "Doc-code sync"):

- `docs/manuals/API-MANUAL.md` line 2555 — "Applies **four** targeted supplements … they are
  unchanged from ADR-084" is now wrong on both counts. Correct the count and drop the
  "unchanged from ADR-084" claim for the removed one.
- `docs/manuals/API-MANUAL.md` line 2592 — "All physics constants (γ bounds, Kt values,
  topographic multipliers) defined as module-level constants" — the topographic multipliers
  no longer exist. Kt values were removed by ADR-095; check whether that part is also stale
  and report what you find rather than guessing.
- Search the API repo and the meta repo for any other reference to
  `apply_topographic_adjustment`, `TOPO_MULTIPLIERS`, or `topographic_adjustment` and report
  every hit with its disposition. Test files that test the removed function are deleted with
  it (`rules/coding.md` §3).

### Scope

**Files you may create or modify — API repo** (`repos/weewx-clearskies-api/`):
- `weewx_clearskies_api/enrichment/wave_transform.py`
- the test file(s) covering the removed function — locate them yourself and name them in
  your scope ack

**Files you may modify — meta repo** (`c:\CODE\weather-belchertown\`):
- `docs/manuals/API-MANUAL.md`

**Files you must NOT touch:** `endpoints/surf.py` (agent A2 has it this round —
`apply_supplements()`'s call site there is T4A.7's, not yours), `services/transect_handoff.py`,
`services/swan_domain.py`, `config/marine_config.py`, anything under
`docs/planning/briefs/`, `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`, the dashboard repo.

**Verification command** (name the actual test file in your scope ack):
```
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/<the wave_transform test file> -q"
```
Plus `ruff check weewx_clearskies_api/enrichment/wave_transform.py` locally.

**Deliverable:** 1 commit on API repo `main` (code + its tests) and 1 commit on meta repo
`main` (API-MANUAL). Report both hashes, the test result, and the full list of grep hits with
dispositions.

### Open questions — surface, do not resolve

- Whether the `Kt values` phrase at API-MANUAL line 2592 is also stale.
- Any caller of `apply_supplements()` whose behavior changes in a way beyond "no topographic
  multiplier is applied."

---

## Agent A2 — T4A.8: fix the latent `NameError` in the SurfBeat IG-strip precomputation

**Agent type:** `clearskies-api-dev`

### Reading list (read before any edit)

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — **T4A.8** in full.
2. `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py` lines 690–860 (the
   SurfBeat IG-strip precomputation block) and lines 960–1030 (the per-timestep loop where
   `ts_wind_speed` / `ts_wind_direction` are actually assigned, under the heading
   "Step 5: wind source per timestep (ADR-094)").
3. `docs/manuals/API-MANUAL.md` — the surf wind-source table immediately above line 2548
   (`t=0` vs forecast wind source rules, ADR-094). Your fix must produce the same wind for a
   given timestep that the per-timestep loop produces.
4. `rules/clearskies-process.md` — the rule "Every SWAN INPUT file requires wind forcing"
   and its 2026-07-23 incident note. That is why this block passes wind at all.

### Spec

Do what T4A.8's Do list says: fix the reference order, and add a regression test that
exercises the block with `surfbeat_enabled=True` and a valid cadence-hour match.

**The fix is not a simple statement reorder.** The precomputation block (surf.py ~722–840)
runs *before* the per-timestep loop and iterates its own cadence hours, so there is no
earlier definition to move up. The block needs the wind **at its own selected timestep**
(`_best_ts`), which is a different timestep from any single iteration of the later loop.

**LC-R1-3 (coordinator lead call):** resolve the wind inside the SurfBeat block using the
same rules the per-timestep loop already applies for a given timestep — station wind for the
`t=0` timestep with HRRR as its fallback, HRRR interpolated at `valid_time_iso` otherwise.
Reuse `_interpolate_hrrr_wind` and the already-computed `hrrr_field` /
`wind_speed_station` / `wind_direction_station` values; do not introduce a second wind
source, a new provider call, or a new config key. If the existing helper cannot be reused
without changing its signature in a way that affects another caller, STOP and report.

Extracting the shared wind-resolution logic into a small local helper used by both sites is
in scope and preferred over duplicating it. That is a refactor inside one file with no
contract crossing a boundary.

### Scope

**Files you may create or modify — API repo only** (`repos/weewx-clearskies-api/`):
- `weewx_clearskies_api/endpoints/surf.py`
- the surf-endpoint test file(s) — locate and name them in your scope ack; add the
  regression test there

**Files you must NOT touch:** `enrichment/wave_transform.py` (agent A1 has it),
`services/transect_handoff.py`, `services/swan_domain.py`, `services/surf_1d_pipeline.py`,
`services/surfbeat_runner.py`, any file in the meta repo, the dashboard repo. Do **not**
remove the `apply_supplements()` call at surf.py ~970–995 — that is T4A.7 and it is gated.

**Verification commands:**
```
ruff check weewx_clearskies_api/endpoints/surf.py     # must report zero F821
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/<surf endpoint test file> -q"
```

**Deliverable:** 1–2 commits on API repo `main`. Report hashes, the `ruff` output proving
zero F821 in `surf.py`, and the pytest result. State explicitly whether your new test fails
against the pre-fix code — a regression test that passes before the fix is not a regression
test; demonstrate it (e.g. `git stash` the source fix, run the test, unstash) and paste the
failing output.

### Open questions — surface, do not resolve

- The block reads `_offshore_pt.get("distanceFromShore")` and `.get("waveHeight")` — the
  pre-T4A.1 vocabulary. Report whether these dict keys are still what the producer emits, and
  whether they are inside or outside T4A.1's unification scope. **Do not rename them.**
- Whether the SurfBeat block should skip the hour or use zero wind when neither station nor
  HRRR wind resolves for `_best_ts`. Report what the code currently implies; do not decide.

---

## Agent A3 — T4A.13: mark superseded research briefs

**Agent type:** `clearskies-docs-author`

### Reading list (read before any edit)

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — **T4A.13** in full. Its four numbered
   items name the exact locations that need banners.
2. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — **Amendment 2** in full. This
   is the superseding decision you cite.
3. `docs/decisions/ADR-095-swan-model-corrections.md` — **Amendment 2** in full.
4. `docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md` — **read the superseding box at
   the top of section D2 first.** This brief records several *discarded* approaches next to
   the adopted one; if you read it linearly you will cite a withdrawn answer.
5. The two target briefs, at the locations T4A.13 names.

### Spec

Do exactly what T4A.13's Do list says. **Add banners; delete nothing and rewrite nothing** —
these are research records and the historical reasoning is the point.

Constraints:
- Every banner is dated `2026-07-25` and names the superseding ADR and amendment number.
- Item 2 is a **reversal**, not a plain supersession: §9 Option 3 ("Truncate L3 at handoff
  depth… not recommended") now describes the adopted architecture. Say that, and say why the
  original recommendation was reversed, sourcing the reason from ADR-093 Amendment 2 rather
  than composing your own.
- Item 4 is a **partial** supersession: the depth-of-closure derivation of 15 m is still
  correct as the rationale for L3's *offshore* edge. The banner must say it does not govern
  the *shoreward* edge — and must not imply the 15 m figure is wrong.
- Do not touch `SURF-ZONE-MODEL-BRIEF.md` §7 (the "Feeds the 1D model" claim). That belongs
  to T4A.7, which is gated on a separate verification.
- If you find a location matching T4A.13's description at a different line number than the
  plan gives, use the content match and report the line drift.

### Scope

**Files you may modify — meta repo only** (`c:\CODE\weather-belchertown\`):
- `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`
- `docs/planning/briefs/SWAN-NESTING-RESEARCH-BRIEF.md`

**Files you must NOT touch:** `docs/manuals/API-MANUAL.md` (agent A1 has it),
`docs/ARCHITECTURE.md`, any ADR, `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`,
`docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md`, any code repo.

**Verification:** quote each banner you added, with its file and the heading it sits under,
in your closeout. Also report, for each of the four items, the line number you found it at
versus the line number the plan gave.

**Deliverable:** 1 commit on meta repo `main` touching exactly those two files.

### Open questions — surface, do not resolve

- Any *other* statement in either brief that describes the pre-1D design and is not covered
  by T4A.13's four items. **List them; do not banner them.** T4A.3.0 owns the full inventory.
