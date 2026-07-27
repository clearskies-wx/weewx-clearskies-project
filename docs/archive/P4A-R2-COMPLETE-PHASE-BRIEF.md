# Phase 4A — Round 2: complete the phase

**Round identity:** Marine Service Separation, Phase 4A, resume-session Round 2.
**Date:** 2026-07-25. **Lead:** coordinator (Opus). **Auditor:** `clearskies-auditor` after all
five agents land.

Five agents, all dispatched together. Every remaining Phase 4A task is in this round. The
**NO DEFERRAL RULE** at the top of `MARINE-SERVICE-SEPARATION-PLAN.md` applies: nothing here
is deferrable, and "blocked on X" is a report-to-coordinator event, not an outcome.

| Agent | Task(s) | Owns these files |
|---|---|---|
| **B1** | T4A.9 + T4A.10 | `services/transect_handoff.py`, `services/surf_1d_pipeline.py` |
| **B2** | T4A.3 + T4A.11 | `endpoints/setup.py`, `enrichment/bathymetry.py`, `providers/nearshore/swan.py`, `services/swan_domain.py`, `config/marine_config.py` |
| **B3** | T4A.6 | `endpoints/beach_profile.py`; dashboard `types.ts`, `BeachProfileChart.tsx`, `HeatMapCard.tsx`, `openapi-v1.yaml` |
| **B4** | T4A.7 | `enrichment/wave_transform.py`, `endpoints/surf.py`, `docs/ARCHITECTURE.md`, `SURF-ZONE-MODEL-BRIEF.md` §7 |
| **B5** | T4A.3.0 | one new file: `docs/planning/briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md` |

**File ownership is exclusive.** If your task seems to need a file another agent owns, STOP and
SendMessage me — do not edit it, do not stage it, and do not work around it.

---

## Pre-round verification (coordinator, 2026-07-25)

| Check | Result |
|---|---|
| API repo `main` | `08ce616`, tree clean, pushed |
| Meta repo `main` | `e9f3e3a`-ish (round briefs committed), tree clean, pushed |
| Dashboard `main` | `20c6e50` + **uncommitted `public/card-manifest.json`** — see B3 |
| weewx API checkout | `08ce616`, pulled with `--no-restart`, service NOT restarted |
| librewxr | `bfff1f7`; `weewx-clearskies-swan` (8767) + `weewx-clearskies-compute` (8770) both **active** |
| Test baseline | `tests/test_surf_endpoint.py` + `tests/test_wave_transform.py` → **37 passed** on both Windows and weewx/Linux-3.12 |

---

## Blocks that apply to EVERY agent

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
> SendMessage. Do not resolve it yourself.

> **Shared working tree — two hard rules.**
> 1. **Stage only the paths in your own scope block, by name.** Never `git add -A`,
>    `git add .`, or `git commit -a`.
> 2. **Whole-repo `git stash` is BANNED.** Four other agents have uncommitted work in these
>    trees; a whole-repo stash transiently reverts theirs. If you need to compare against
>    pre-edit state, use file-scoped patches:
>    `git diff -- <your file> > /c/tmp/p.patch`, `git apply -R /c/tmp/p.patch`, then
>    `git apply /c/tmp/p.patch` to restore. (A Round 1 agent hit this and caught itself.)

> **No container edits:** All editing and committing happens on this local machine. Never edit
> a source file or run any git write operation on `weewx`, `weather-dev`, `librewxr`, or any
> container. SSH is read-only — running tests, reading logs, reading deployed files, reading
> the installed SWAN manual.

> **Verification reality — read this before planning your evidence.** Every deploy path pulls
> **from GitHub**. Your local commits are invisible to every container until the coordinator
> pushes. **A pytest run on a container does not exercise your edit** unless I have pushed and
> pulled it first — reporting one as verification is a false-clean result. What works locally:
> the machine's global `py` / `python` interpreter has `ruff`, `pytest`, and every runtime dep
> at compatible versions, and resolves the package from this checkout. Run your tests locally,
> report those numbers, and say plainly which evidence you produced versus which I still owe on
> Linux. See `reference/clearskies-dev.md` "Which host runs which tests" — updated this session.

> **Architectural changes — STOP, do not proceed.** You may not make an architectural change.
> If your task requires one, STOP and report via SendMessage — do not implement it, do not work
> around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold
>    or criterion inside one. **This does NOT cover changing how the same equation is solved**
>    — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which
>    equation is satisfied*, or only *how precisely/efficiently*? Only the first is
>    architectural. An approximation that does not converge to the original equation IS a
>    formula change and is covered.
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
> taking the reading its own examples support (and say so); apply a rule already written in the
> rules files; fix code that diverges from its own stated contract.

> **Scope acknowledgment before any edit.** SendMessage me one paragraph: what you will
> deliver, what you will not touch, the exact commands you will run. Wait for confirmation.

---

## Settled decisions ALL agents must apply and must NOT re-derive

These were decided by the operator on 2026-07-25 and are recorded in ADR-093 Amendment 2,
ADR-095 Amendment 2, and `L3-1D-BOUNDARY-DECISIONS-BRIEF.md` D1–D7. **Read
`L3-1D-BOUNDARY-DECISIONS-BRIEF.md` in full — all 592 lines, D1 through D7 — not just the
section that looks relevant.** A partial read of that brief cost this session real time.

1. **L3's offshore edge is the 15 m contour.** Closed (D1). Because of that, the existing
   `min(handoff, 15.0)` clamp is already correct and D4's concern about it dissolves.
2. **L3 does not run to shore.** Its shoreward boundary is the handoff surface.
3. **The handoff moves per forecast hour:** `1.3 × Hs(hour) / gamma`, gamma = 0.73. Grid
   geometry stays frozen at setup.
4. **The 5 m minimum handoff depth is REMOVED** (`_MIN_HANDOFF_DEPTH_M`,
   `transect_handoff.py:48`). Operator-approved, **with the condition that its removal is
   watched in testing** — B1 must carry that as an explicit verification item.
5. **LC-R1-4 — the feature-coverage requirement sets L3's shoreward edge**, and the
   breaking-depth expression is the check, not the driver. Amendment 2's *"the grid must
   therefore reach ~1.8 m depth, **which spans the pier end to end**"* is one statement. There
   is **no** minimum-wave-height config key and **no** new shallow-depth constant. Two earlier
   coordinator proposals along those lines are dead; do not revive them.
6. **L3 enables on a discovered structure OR the operator's point-break / headland / bay
   classification.** Structure-only was the old trigger.
7. **Structure geometry can never move the handoff.** It can only deepen SwellTrack's fine
   zone. The breakdown depth is a hard ceiling regardless of what is in the water.
8. **No SPECOUT may be extracted at an L3 boundary cell** (ADR-095 Amendment 2).
9. **The SurfBeat strip keeps its 15 m → shore domain and deliberately spans the surf zone** —
   infragravity energy is *generated by* breaking, so a truncated strip would not produce what
   it exists to produce. Different job from L3, therefore different domain (D5).
10. **Open-beach handoff is 15 m from L2** (D3).
11. **Supplement 4's topographic multipliers are already removed** — landed `7dd9899` this
    session. Do not re-remove them.

### LC-R2-1 — extraction is at a POSITION, not a cell (plan-vs-ADR conflict, resolved)

T4A.9's text says "select the L3 grid **cell**." ADR-095 Amendment 2 says extraction "happens
at the handoff **position** with grid on both sides of it," and the code already emits
`POINTS '{name}' {x} {y}` at explicit UTM coordinates (`swan_formats.py:1424`; same pattern for
the L2 deep-water reference at `swan_runner.py:1444`), which SWAN interpolates to.

Per `rules/clearskies-process.md` — *"Read the ADR before the plan… ADR wins on conflict — fix
the plan to match"* — **the position reading governs.** Keep emitting at explicit coordinates.
This also keeps T4A.7's supplement #3 genuinely redundant, which matters to B4.

---

# Agent B1 — T4A.9 + T4A.10

**Type:** `clearskies-api-dev`. **Owns:** `services/transect_handoff.py`,
`services/surf_1d_pipeline.py`, and their test files.

### Reading list
1. Plan **T4A.9** and **T4A.10** in full.
2. `ADR-093-swan-trushore-nearshore-model.md` **Amendment 2** — all of it, §2 especially.
3. `ADR-095-swan-model-corrections.md` **Amendment 2** — the SPECOUT-placement and QB
   acceptance-criteria paragraphs.
4. `L3-1D-BOUNDARY-DECISIONS-BRIEF.md` **in full**.
5. `services/transect_handoff.py` in full (742 lines) — you are rewriting its depth rule.
6. `services/swan_formats.py` — `compute_spot_transects()` (~523), the `TransectInfo`
   dataclass (~504), and the CURVE/POINTS/SPECOUT emission (~1391–1430).
7. `rules/coding.md` §3 (no dead code, single responsibility).

### Blocking constraints — violating either of these is the failure this task is guarding

**C1 — `compute_handoff_depths()` serves TWO purposes. The shadow classification MUST
survive.** `swan_formats.py:548` states it: *"one computation serves both handoff depth and
obstacle intersection."* Its `is_shadowed` / `shadowing_structures` outputs become
`TransectInfo.is_structure_affected`, which drives the multi-transect obstacle filter that
excludes structure-affected transects from headline metrics (best peak, spot average) while
still rendering them on the heat map. **Replacing the depth rule must not delete, weaken, or
bypass the shadow computation.** Removing it would be trigger 2 — a responsibility
disappearing. If the cleanest structure is to split the function into two (shadow
classification, and per-hour handoff selection), that is in scope and preferred — but both jobs
must still be done and both consumers must still get what they read today.

**C2 — grid geometry must not move.** `compute_domains()` output must be byte-identical across
a forecast cycle. In July an agent that could not get structures into `compute_domains()` added
a runtime grid override instead of fixing the caller; the result was 0.01 m wave heights during
a 6–8 ft swell behind a valid HTTP 200. The per-hour handoff is a **lookup**. Add a test that
asserts byte-identical `compute_domains()` output before and after a cycle.

### Spec

Implement T4A.9 and T4A.10 as the plan specifies, under the settled decisions above and
LC-R2-1 (position, not cell). Four things the plan does not tell you, all coordinator lead
calls:

- **LC-R2-2 — T4A.9's Do step 5 has no target.** "Delete any code path that resolves the
  handoff from `max_hs_m`." I checked: `max_hs_m` appears **only** in
  `enrichment/bathymetry.py` fine-zone sizing (`compute_fine_zone_max_depth`,
  `interpolate_profile_pchip`), which T4A.9 itself says correctly stays. Zero occurrences in
  `transect_handoff.py`, `swan_formats.py`, `swan_runner.py`, or the standalone SWAN repo.
  **The step is a no-op. Do not invent a path in order to delete one.** Confirm my finding and
  report it; if you find a path I missed, that is a real result — report it before acting.
- **LC-R2-3 — remove the 5 m floor, and carry the operator's watch condition.**
  `_MIN_HANDOFF_DEPTH_M = 5.0` goes. The operator approved this **on the condition that its
  removal is watched in testing.** So: your tests must cover the shallow end explicitly — a
  1 m-swell hour resolving to ~1.8 m — and you must report whether anything the floor was
  incidentally protecting against now bites. Candidates to actually check, not assume: whether
  the cached depth profile has usable data shallower than 5 m at HB, and what
  `_dist_at_depth()` (`swan_formats.py:855`) returns when the requested depth is shallower than
  any profile point. If it silently returns a fallback, that is a real defect and a finding.
- **LC-R2-4 — SWAN `POINTS` is fixed geometry for a run.** A single moving POINTS entry is not
  a thing SWAN supports across a nonstationary run. So a per-hour handoff cannot be "move the
  point." The shape I expect is: compute a finite set of candidate handoff positions at setup
  spanning the spot's breaking range, emit SPECOUT at all of them in one INPUT file, and select
  per forecast hour from that set at read time — a lookup, geometry frozen. **Verify this
  against the installed SWAN manual on librewxr before building it** (read-only SSH), and
  report what the manual actually says. If it contradicts my expectation, STOP and report —
  do not improvise a mechanism.
- **LC-R2-5 — T4A.10 extends, it does not duplicate.** `refine_handoff_with_qb()`
  (`transect_handoff.py:441`) already scans a QB profile, detects `QB > threshold` at the
  handoff, moves it deeper until clean or a cap is hit, and logs. T4A.10's assertion belongs
  **in that function's lineage**, not in a second parallel QB scanner (`rules/coding.md` DRY).
  T4A.10 adds: the ERROR log with greppable pattern `SWAN handoff`, the move-seaward-or-fail
  behaviour, and the `/metrics` counter. Note `/metrics` already exists on port 8081 — adding a
  counter to it is not adding an endpoint.

**Data contract you must emit, for B3 (T4A.6 item g):** the per-hour handoff depth actually
used and the level it came from must be available to the beach-profile response.
Emit them from the pipeline as `handoff_depth_m: float` and
`handoff_source_level: "L3" | "L2"` per transect per forecast hour. B3 surfaces them in the
HTTP response and OpenAPI as `handoffDepthM` and `handoffSourceLevel`. Do not choose different
names — B3 is building against these.

### Verification
- Local: `py -m ruff check` on both files; `py -m pytest` on your test files.
- Required tests: handoff depth varies across the 72 hours for one transect; a 1 m hour and a
  4 m hour at HB resolve to different positions (~1.8 m vs ~7.1 m depth); `compute_domains()`
  byte-identical across a cycle; the forced-violation drill for T4A.10 (inject a shallow
  handoff → ERROR log + counter increments); shadow classification unchanged for a
  structure-shadowed transect (guards C1).
- Report which evidence is yours and which I owe on Linux.

**Deliverable:** commits on API repo `main` for T4A.9 and T4A.10 separately. Report hashes,
test output, the SWAN manual finding for LC-R2-4, and the LC-R2-3 shallow-end findings.

---

# Agent B2 — T4A.3 + T4A.11

**Type:** `clearskies-api-dev`. **Owns:** `endpoints/setup.py`, `enrichment/bathymetry.py`,
`providers/nearshore/swan.py`, `services/swan_domain.py`, `config/marine_config.py`, and their
test files.

These two tasks are merged into one agent because both own L3 grid sizing in
`swan_domain.py` — T4A.3's Do step 4 *is* the sizing T4A.11 refines. Splitting them would put
two agents in one function.

### Reading list
1. Plan **T4A.3** in full (including its `AMENDED 2026-07-25` step 6 and Do step 4), then
   **T4A.11** in full, then **T4A.2** (the PCHIP spec your profile generation calls).
2. `ADR-093` **Amendment 2** in full — §3 (trigger), §4 (viability test), §5a, §5b.
3. `L3-1D-BOUNDARY-DECISIONS-BRIEF.md` **in full**.
4. `git show 244ee08` — **the partial T4A.3 implementation that already landed.** It adds
   staged sizing entry points so L1 → coarse download → 30 m contour → L2 → medium download →
   15 m contour → L3 runs in order without any grid being resized after computation; sizes L2
   from the real 30 m contour instead of a hardcoded 6 km; and makes both estimate fallbacks
   log that they are estimates. **You extend this. You do not replace it, and you do not
   re-implement what it already did.** Its known gap: it sizes L3's *offshore* edge only.
5. `services/swan_domain.py` in full (902 lines).
6. `rules/clearskies-process.md` — "All SWAN grid geometry is fixed at setup time" and the
   "Grid sizing must come from actual data" and "Silent skipping of configured inputs" rules.

### Blocking constraints

**C3 — pass inputs INTO `compute_domains()`; never apply them afterwards.** This is the
July incident, verbatim from the rules: an agent could not get structures into
`compute_domains()` at the right time, so it added a runtime override that resized the grid
after L2 had written its NESTOUT. Result: 0.01 m wave heights during a 6–8 ft swell, valid
HTTP 200, no error. **If a value you need is not reachable at the point `compute_domains()`
runs, fix the caller. Do not add a later override. If you cannot fix the caller, STOP and
report.**

**C4 — the viability test's log is mandatory, not optional polish.** ADR-093 Amendment 2 §4:
a grid reaching too far shoreward announces itself at runtime; a grid stopping too far seaward
is *silently indistinguishable* from "nothing here to model." The INFO log naming **which
feature was unreachable and by how much** is the only thing that makes the second case
visible. No silent disable.

### Spec

Implement T4A.3's remaining Do steps and all of T4A.11, under the settled decisions — in
particular #5 (LC-R1-4: feature coverage sets the shoreward edge, breaking depth is the check),
#6 (widened trigger), #7 (structure geometry cannot move the handoff), and #1 (offshore edge
stays 15 m).

Coordinator lead calls:

- **LC-R2-6 — HB Pier's disposition is whatever the viability test returns.** Do not hard-code
  it either way. The "HB is disabled" conclusion in `L3-1D-BOUNDARY-DECISIONS-BRIEF` §D2b is
  **withdrawn** — it was an artefact of the frozen-handoff error. Read that section's
  superseding box.
- **LC-R2-7 — setup-time calculation is depth-based only.** Contour positions, local slope,
  breaking depths, horizontal spans, grid extents and cell counts, profile relief: all in, all
  required. Contour *curvature*, orientation variation along the segment, headland detection,
  automatic break-type classification: all **out of scope**, specified nowhere, built nowhere.
  The operator's classification supplies that answer. If you find yourself needing shoreline
  *shape*, STOP.
- **LC-R2-8 — `structure_zone_depth` has two conflicting definitions in the documents.** Plan
  T4A.2 says "the depth of the deepest structure affecting this spot, plus margin";
  `L3-1D-BOUNDARY-DECISIONS-BRIEF` §4 quotes SURF-ZONE-MODEL-BRIEF §6.1 as "maximum depth at
  the L3 SWAN grid boundary for this spot's cluster." **Report which one the code implements
  and do not silently pick.** T4A.3 Do step 5 and T4A.2's worked examples both support the
  first reading, so implement that if you must proceed — and say so explicitly in your
  closeout. Flag it to me the moment you hit it.
- **LC-R2-9 — the `l3_enabled` config key already exists** (`auto`/`on`/`off`,
  `marine_config.py` ~438/~495, `setup.py` ~495) and `compute_domains()` already honours it
  (`swan_domain.py` ~170). The viability test's disable is the **same disposition** as
  `l3_enabled="off"`, reached by computation rather than config. Reuse that path; do not add a
  second disable mechanism. Adding a config key would be trigger 7 — the widened trigger uses
  the *existing* `topographic_feature` field, which is retained in spot config precisely for
  this job.
- **LC-R2-10 — the vertical datum is currently hardcoded `"NAVD88"`** in the beach-profile
  metadata and that is a defect (plan T4A.6 item f). Your profile cache must record the DEM's
  **actual** datum. Verified fact you should not re-derive: HB is covered by exactly 3 NCEI
  tiles, all 1/3 arc-second (~10.3 m), **no 1/9 arc-second tile**, and they are in **two
  different vertical datums** — `orange_county_13_navd88_2015.nc` (NAVD88),
  `santa_monica_13_mhw_2010.nc` (MHW), `santa_monica_13_navd88_2010.nc` (NAVD88). Report how
  you resolve that, do not silently pick one.

### Verification
- Local `ruff` + `pytest` on your files.
- Required tests: L2 boundary from an actual 30 m contour, not 6 km; L3 offshore edge from an
  actual 15 m contour, not the 2.5 km fallback; **L3 does not reach shore**; a spot classified
  as a point break with **no** structures enables L3; a cluster failing viability gets
  `grid=None` **and** the INFO log naming feature and shortfall; missing caches produce an
  explicit ERROR, not a silent fallback; SWAN runtime performs zero CUDEM downloads and zero
  grid sizing.
- Read `git show 244ee08` before writing, and state in your closeout what you extended versus
  what was already there.

**Deliverable:** separate commits for T4A.3 and T4A.11. Report hashes, test output, and
explicit answers on LC-R2-8 and LC-R2-10.

---

# Agent B3 — T4A.6

**Type:** `clearskies-dashboard-dev`. **Owns:** API `endpoints/beach_profile.py`; dashboard
`src/api/types.ts`, `src/components/marine/tabs/BeachProfileChart.tsx`, `HeatMapCard.tsx`,
`src/api/openapi-v1.yaml`, and dashboard test files.

### Reading list
1. Plan **T4A.6** in full — its table (a) through (g) is your specification, read from the plan
   itself, not from any summary. Item (g) was added 2026-07-25.
2. Plan **T4A.1** — the vocabulary decision (`distance`, `depth`, `hs`, `transect`) that (a)–(f)
   build on. It has already landed; do not redo it.
3. `endpoints/beach_profile.py` — `_build_transect_profile()` and `_serialize_surf_zones()`.
4. `services/surf_1d_analytical.py` — the `SurfZones` dataclass, for item (d).
5. `docs/manuals/DESIGN-MANUAL.md` — the marine card patterns, before touching any component.
6. `rules/coding.md` §5 (accessibility) and §6 (i18n) — both apply to every dashboard edit.

### Hard constraint on the dirty tree

**The dashboard working tree has an uncommitted change to `public/card-manifest.json`** adding
a `marine-summary` card entry. It is not yours, it is not part of T4A.6, and its provenance is
unexplained. **Do not edit it, do not stage it, do not revert it, do not stash it.** Leave it
exactly as it is and confirm in your closeout that `git status` still shows it modified and
unstaged.

### Spec

Do T4A.6's Do list for items (a) through (g). Lead calls:

- **LC-R2-11 — the API's shape wins for (a), (b), (c)**, per T4A.6 Do step 1's stated default
  and T4A.1's decision that the model's vocabulary and structure win. Change the dashboard to
  match the API. If you find a case where the dashboard shape is genuinely better for
  rendering, you may propose it — but report it to me before implementing, with the reason.
- **LC-R2-12 — item (d) is explicitly unconfirmed and you must confirm it.** T4A.6 says which
  zones populate `width_m` "was not verified against `surf_1d_analytical.py`'s `SurfZones`
  dataclass — verify before fixing." Do that verification first and report what you find.
- **LC-R2-13 — item (g)'s field names are fixed, because agent B1 is emitting them.**
  `handoffDepthM: number` and `handoffSourceLevel: "L3" | "L2"`, on the per-hour transect data
  **and** in `metadata`. B1 emits `handoff_depth_m` / `handoff_source_level` from the pipeline.
  Do not rename either side. If B1's output is not in place when you get there, build the
  response and OpenAPI shape against this contract and report the dependency — do not invent a
  different name.
- **LC-R2-14 — item (f)'s hardcoded datum is a defect, and its fix is agent B2's.** The
  `metadata.verticalDatum` value is currently hardcoded `"NAVD88"`. Your job is the *shape* —
  surfacing the datum where the dashboard reads it. B2 owns making the value truthful from DEM
  metadata. Wire the shape; do not hardcode a different constant.

### Verification

`tsc --noEmit` must return **ZERO** errors (`rules/coding.md` §9 — a TS error means `vite
build` never runs and rsync deploys stale files). Then:

**Rendering is not optional and `tsc` is not evidence.** T4A.6's Accept list requires that the
wave-shapes overlay, the jacking-factor annotations, and the break-point partition annotation
each **render against real data**. Per `rules/coding.md` "Render and LOOK before declaring any
UI change done": build, load the page, screenshot it, and *look at the image*. Report what the
rendered image actually showed. "It compiles" and "axe reports 0 violations" are not visual
verification. If you cannot render, say so explicitly and do not claim the visual is correct.

**Deliverable:** separate commits on the API repo and the dashboard repo. Report hashes, the
`tsc --noEmit` output, your rendering evidence, and answers on LC-R2-12.

---

# Agent B4 — T4A.7

**Type:** `clearskies-api-dev`. **Owns:** `enrichment/wave_transform.py`,
`endpoints/surf.py`, `docs/ARCHITECTURE.md`, `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`
§7, and the wave_transform test file.

### Reading list
1. Plan **T4A.7** in full — **including the operator's APPROVED banner at the top.** That
   banner narrows the task substantially and contains the verification gate that governs it.
2. `ADR-095` Amendment 2 — the handoff-SPECOUT-placement paragraph.
3. `enrichment/wave_transform.py` as it stands **now** — Supplement 4 was removed this session
   in `7dd9899`. Read the current file, not the plan's description of it.
4. `endpoints/surf.py` around lines 960–1000 — the `apply_supplements()` call site.
5. `services/swan_formats.py` ~1391–1430 and `services/swan_runner.py` ~1440–1470 — the
   POINTS/SPECOUT emission, which is the evidence for the gate.

### The gate is the task. Do not skip to the deletion.

T4A.7's approval is **conditional**. Of the four supplements: #2 was already removed by
ADR-095; #4 was removed this session (`7dd9899`); #1 is a branch that provably never executes.
**#3 — sub-grid bilinear interpolation — is the only supplement whose removal is a real
decision, and it is gated.**

The gate: confirm the handoff spectrum is emitted at *requested coordinates* rather than at
grid-cell centres. **If SWAN interpolates to the requested point, #3 is redundant and goes. If
it does not, #3 is doing real work and MUST STAY — report that and stop. Do not delete it
anyway.**

**Coordinator finding to verify, not to trust:** I read `swan_formats.py:1424` emitting
`POINTS '{spec_name}' {sx:.2f} {sy:.2f}` at explicit UTM coordinates followed by `SPECOUT`,
and the same pattern at `swan_runner.py:1444` for the L2 deep-water reference. That points
toward "yes, requested coordinates." **Confirm it against the installed SWAN manual on
librewxr** (read-only SSH) — specifically what SWAN does with a POINTS location that falls
between grid nodes. Cite the manual section. My reading is a starting point, not the answer.

Also reconcile with **LC-R2-1**: extraction stays at a position, not a cell, so B1's per-hour
work does not change the answer. Confirm that yourself rather than taking it from me.

- **LC-R2-15 — `bilinear_interpolate()` is RETAINED regardless of the gate's outcome.**
  `surf.py` uses it for HRRR wind interpolation, an unrelated live caller. Only the
  *supplement* goes, if it goes.
- **LC-R2-16 — Supplement 1's disposition is yours, and it is dead code.** Its guard requires
  `spot_config.bathymetric_profile`, which `marine_config.py` deliberately no longer reads, so
  `getattr(..., None)` is always `None` and the branch has never executed. Removing provably
  dead code is methodology, not architecture (`CLAUDE.md`'s table). **Verify the claim yourself
  before deleting** — `rules/clearskies-process.md`: a claim that code is dead needs *more*
  verification than a claim that it is fine. If the branch can execute under any configuration,
  it stays and that is a finding.

Then do T4A.7's Do steps 1–3, including the doc updates: `ARCHITECTURE.md`'s
`wave_transform.py` description and `SURF-ZONE-MODEL-BRIEF.md` §7's "Feeds the 1D model" claim
both describe a design that was never implemented. Replace them with what the code does.

**Do NOT touch** `SURF-ZONE-MODEL-BRIEF.md` outside §7 — four superseded banners landed there
this session in `25afa30` and other sections are inventory territory.

### Verification
Local `ruff` + `pytest` on the wave_transform and surf test files. Deleted functions' tests go
with them. Report the gate's answer with the manual citation as the headline result.

**Deliverable:** commits on API repo `main` + meta repo `main`. The gate's outcome — #3 removed
with evidence, or #3 retained with the reason — is the deliverable I care most about.

---

# Agent B5 — T4A.3.0

**Type:** `clearskies-api-dev` (research and written analysis only).
**Owns:** one new file, `docs/planning/briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md`.

**Your brief is the separate document `docs/planning/briefs/P4A-RECONSTRUCTION-BRIEF.md`.**
Read it in full — it is your reading list, in-scope/out-of-scope boundaries, head start, and
deliverable definition. Everything in it stands, with these corrections and additions:

- **Correction: nothing about L3's shoreward reach is an open question.** `L3-1D-BOUNDARY-
  DECISIONS-BRIEF.md` D1–D7 settle far more than that brief's earlier framing implied. D1
  closed as "offshore edge stays 15 m," which dissolves D4; and LC-R1-4 above settles the
  shoreward edge. Report the three bathymetry facts it asks for as facts, not as inputs to a
  live decision.
- **Addition — D3's reconciliation was recommended and never adopted.** The brief recommends
  stating that the 10 m handoff applies only to unshadowed transects *inside an L3-enabled
  cluster*, and 15 m when the spectrum comes from L2, so the depth follows which model produced
  it. That exists as a recommendation only: ADR-093 Amendment 1 §1 and SURF-ZONE-MODEL-BRIEF
  §2.3.4 still contradict each other, and `transect_handoff.py`'s
  `_DEFAULT_HANDOFF_DEPTH_M = 10.0` applies the 10 m side unconditionally to every open
  transect whether or not L3 exists. Add it to your inventory as a doc-and-code row.
- **Addition — D5's cadence flag, folded into your area 2.** The strip's 15 m → shore domain is
  confirmed and deliberate. But once L3 stops early the strip becomes the *only* SWAN-quality
  wave height in the approach zone, and it runs 1 hour in 3 with carry-forward. The 3-hour
  cadence was chosen because *IG set/lull timing* evolves slowly — a statement about
  infragravity timing, not about approach-zone wave height. Establish from the code: the actual
  cadence and where it is configured, how carry-forward works, and how the blended Hs profile
  combines strip and SwellTrack values. Then state plainly whether the blend has a gap on
  non-strip hours. **Facts and the named gap; no recommendation on cadence.**
- **Note:** four other agents are editing these repos. You create one new file and touch
  nothing else, so read freely but stage only your own file.

---

## Round close (coordinator, after all five land)

1. Independent verification of every agent claim — re-run their commands, spot-check one
   non-trivial requirement per agent against the code, compare commits against scope blocks.
2. Push, pull to weewx and librewxr, re-run the round's tests on Linux.
3. Dispatch the **Phase 4A adversarial audit** (`clearskies-auditor`) per the plan's
   "Adversarial Audit — Phase 4A" scope, its 8 numbered checks.
4. T4A.5 (regenerate profiles on librewxr) — coordinator, after B2 lands.
5. QC Gate 4A checklist, then the plan status table, then the scratch verification block.
