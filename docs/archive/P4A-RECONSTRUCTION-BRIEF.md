# Phase 4A — T4A.3.0 (reduced scope): intended-vs-actual reconstruction

**Round identity:** Marine Service Separation, Phase 4A, resume-session Round 1, agent A4.
**Date:** 2026-07-25. **Lead:** coordinator (Opus). **Owner:** `clearskies-api-dev`
(research and written analysis only).

**This task modifies zero source files.** Its deliverable is a written document.

---

## Pre-round verification (coordinator, 2026-07-25)

| Check | Result |
|---|---|
| API repo `main` | `27bf24c`, tree clean |
| Meta repo `main` | `25afa30` (T4A.13 banners landed) |
| Agents concurrently editing | A1 in `enrichment/wave_transform.py` + `docs/manuals/API-MANUAL.md`; A2 in `endpoints/surf.py` |
| T4A.13 status | **DONE** — four superseded banners landed in `25afa30` |

Because A1 and A2 are editing the API repo and the meta repo right now, and because this task
writes only one new file, there is no overlap. **You commit exactly one new file.**

---

## Mandatory blocks

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
> SendMessage. Do not resolve it yourself.

> **Staging discipline:** Two other agents are working in these repos. Stage only your own
> single new file, by name. **Never `git add -A`, `git add .`, or `git commit -a`.**

> **No container edits:** Never edit a source file or run any git write operation on `weewx`,
> `weather-dev`, `librewxr`, or any container. SSH is read-only — reading logs and reading
> deployed files is fine and is useful for this task.

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

For this task the block is close to absolute: **you are writing an analysis, not changing
anything.** Recommending a change in your document is in scope. Making one is not.

> **Scope acknowledgment required before you start writing.** SendMessage the coordinator with
> one paragraph: what the document will contain, what you will not do, and how you will
> evidence the "actual" column. Wait for confirmation.

---

## Reading list

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — **T4A.3.0** in full, including the
   `SCOPE REDUCED 2026-07-25` block at the top. That block is binding: it removes most of
   what the original task asked for. Then read **T4A.3** so you know what the reconstruction
   is feeding.
2. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` — **Amendment 1 and Amendment 2**.
3. `docs/decisions/ADR-095-swan-model-corrections.md` — **Amendment 1 and Amendment 2**.
4. `docs/decisions/ADR-096` and `ADR-097` — the scoring restructure and beach profile
   endpoint decisions.
5. `docs/planning/SURF-1D-IMPLEMENTATION-PLAN.md` (and its archived form under
   `docs/archive/` if it has moved) in full — this is the plan whose half-implementation is
   the subject of this task.
6. `docs/planning/briefs/SURF-ZONE-MODEL-BRIEF.md`, `SWAN-L3-STABILITY-BRIEF.md`,
   `SWAN-NESTING-RESEARCH-BRIEF.md`, `1D-MODEL-BENCHMARK-BRIEF.md`.
7. `docs/planning/briefs/L3-1D-BOUNDARY-DECISIONS-BRIEF.md` — **read the superseding box at
   the top of section D2 before anything else in that file.** It records several *discarded*
   approaches beside the adopted one; reading it linearly will hand you a withdrawn answer.
8. `docs/ARCHITECTURE.md` — the SWAN/SwellTrack block around line 98 through 118. Rewritten
   2026-07-25 and current.
9. Source, for the "actual" column: `services/swan_formats.py`, `services/swan_runner.py`,
   `services/surfbeat_runner.py`, `services/surf_1d_analytical.py`,
   `services/surf_1d_pipeline.py`, `enrichment/bathymetry.py`, `services/swan_domain.py`.

---

## What is IN scope

Three intended-vs-actual areas, and one inventory. **Only these.**

1. **The CURVE transect's role.** ADR-095 Amendment 1 made CURVE an L3
   diagnostic/validation output; Amendment 2 further says that where L3 exists the CURVE spans
   L3's actual extent, and **where L3 is disabled there is no CURVE at all.** Establish what
   the code does now: what depth range the CURVE is emitted over, who reads its output, and
   what happens to those consumers when L3 is disabled. T4A.4 removed the CURVE *face-height
   fallback* from the surf endpoint — establish whether any other consumer remains.
2. **The SurfBeat strip's domain.** ADR-093 Amendment 2 says SwellTrack and the SurfBeat strip
   both model from the handoff to the beach. Establish what domain the strip actually spans
   today, where its offshore boundary condition comes from, and whether that boundary moves
   when the handoff moves per forecast hour. Note `surfbeat_runner.py` line ~361 flags its
   boundary as "v1: parametric JONSWAP (design decision; L2 SPECOUT boundary is future
   work)" — establish whether that is still the intended design or a silent deferral.
3. **Per-level bathymetry.** Establish which bathymetry cache each of L1/L2/L3, SwellTrack and
   the SurfBeat strip actually reads, at what resolution, in what vertical datum, and where
   each cache is written. Then state which of those the per-hour handoff and the L3 viability
   test will need that does not exist yet.
4. **The full inventory of governing-document statements still describing the pre-1D design**,
   beyond those already corrected. See the head start below.

## What is OUT of scope — settled, do not re-derive or re-litigate

Per the plan's SCOPE REDUCED block and ADR-093/095 Amendment 2:

- L3's cross-shore extent, and its offshore edge (stays at the 15 m contour).
- How the handoff depth is selected (per forecast hour, `1.3 × Hs(hour) / gamma`).
- The L3 trigger (structure discovered OR operator classification) and the viability test.
- SPECOUT placement (never at an L3 boundary cell).
- Whether structure geometry can move the handoff. **It cannot** — the breakdown depth is a
  ceiling regardless of what is in the water. This survives D2b's superseding box.

If your analysis leads you toward reopening any of these, **stop and report it** rather than
writing it up as a finding. They were decided by the operator on 2026-07-25.

## Head start on the inventory — do not re-find these

Agent A3 located these while landing T4A.13's banners, and deliberately left them
un-bannered because this task owns the inventory. Verify each still reads as quoted, then
carry them into your inventory with a proposed disposition:

| File | Line | Statement |
|---|---|---|
| `SWAN-NESTING-RESEARCH-BRIEF.md` | 196 | table row `Domain sizing: Per spot: 500m alongshore … × ~1 km cross-shore (shore to 15m depth)` |
| `SWAN-NESTING-RESEARCH-BRIEF.md` | 245 | "sized **proportionally**: ~1 km cross-shore (to 15m depth where features exist)…" |
| `SWAN-NESTING-RESEARCH-BRIEF.md` | 264 | "Each cluster becomes one Level 3 grid: 250m before first pin → 250m after last pin × 1 km cross-shore" |
| `SURF-ZONE-MODEL-BRIEF.md` | 25 (§2.1) | "SWAN runs 2D all the way to shore…" |
| `SURF-ZONE-MODEL-BRIEF.md` | 234–242 (§2.3.5) | whole subsection — assumes the old fixed 15 m handoff |
| `SURF-ZONE-MODEL-BRIEF.md` | 248 (§2.4 item 1) | "SWAN runs the full 2D domain to shore." |
| `SURF-ZONE-MODEL-BRIEF.md` | 263–265 (§2.5) | "SWAN runs 2D all the way past structures, down to 5-8m depth" |
| `SURF-ZONE-MODEL-BRIEF.md` | 306 | cost table: "2500m (HB Pier, 15m to shore)" |

Already corrected — do **not** list these as outstanding: `ARCHITECTURE.md` line 98,
this plan's T4A.3, PROVIDER-MANUAL §14.15, API-MANUAL §17, and the four locations
T4A.13 bannered in `25afa30` (SURF-ZONE-MODEL-BRIEF §2.3.4, §4, §9 Options 1 and 3;
SWAN-NESTING-RESEARCH-BRIEF's 15 m derivation).

## Coordinator findings you should build on, not re-derive

I read this code directly this session. Treat these as verified starting points and say so if
you find any of them wrong — that is a useful result.

- **`compute_handoff_depths()` serves two purposes**, not one. `swan_formats.py:548`: "one
  computation serves both handoff depth and obstacle intersection." Its `is_shadowed` output
  becomes `TransectInfo.is_structure_affected`, which drives the filter excluding
  structure-affected transects from headline metrics. Relevant to your CURVE and bathymetry
  rows.
- **The handoff spectrum is emitted at requested coordinates, not cell centres.**
  `swan_formats.py:1424` emits `POINTS '{name}' {sx} {sy}` then `SPECOUT`; same pattern for the
  L2 deep-water reference at `swan_runner.py:1444`.
- **`max_hs_m` has no handoff code path.** It appears only in `enrichment/bathymetry.py`
  fine-zone sizing. Zero occurrences in `transect_handoff.py`, `swan_formats.py`,
  `swan_runner.py`, or the standalone SWAN repo.
- **`refine_handoff_with_qb()` already exists** (`transect_handoff.py:441`) and already scans a
  QB profile and moves the handoff deeper when breaking is detected.

## Deliverable

**One new file: `docs/planning/briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md`.**

Required contents:

1. **An intended-vs-actual table** for the three in-scope areas. Columns: area / what the
   plan-brief-or-ADR said should happen (cite document and section) / what the code does today
   (**cite file and line — every row**) / classification: *silent deferral*, *partial
   implementation*, or *intentional deviation*.
2. **The inventory** of governing-document statements still describing the pre-1D design, each
   with file, line, verbatim quote, and a proposed disposition (banner / correct / leave as
   historical record). Include the eight above.
3. **What the per-hour handoff and the viability test will need that does not exist yet** —
   named, per area, as concrete gaps. This is the part T4A.3, T4A.9 and T4A.11 will consume.
4. **Open questions the documents do not settle** — surfaced, not answered. Audit each one
   against the ADRs first; if an ADR settles it, it is not an open question.

**Rules for the "actual" column:** every claim carries a file and line. If you cannot find
the code that implements something, say "not found" and state where you looked — do not infer
it exists because a document says so. That inference is the exact failure this task exists to
catalogue.

**Zero source files modified.** Your commit contains one new markdown file and nothing else.

## Scope

**Files you may create:** `docs/planning/briefs/P4A-INTENDED-VS-ACTUAL-RECONSTRUCTION.md`
(meta repo).

**Files you must NOT modify:** everything else. Specifically no file in
`repos/weewx-clearskies-api/`, not `docs/manuals/API-MANUAL.md` (A1 has it), not
`endpoints/surf.py` (A2 has it), not `docs/ARCHITECTURE.md`, no ADR, not
`MARINE-SERVICE-SEPARATION-PLAN.md`, and none of the existing briefs — including the two
A3 just bannered.

**Verification:** `git show --stat <your commit>` must show exactly one file, all insertions.
Paste it in your closeout.

**Deliverable definition:** 1 commit on meta repo `main` adding 1 file. Report the hash, the
`--stat` output, the row count of your intended-vs-actual table, and the count of inventory
entries.
