# ROUND BRIEF — Phase DOC of L1-BOUNDARY-REBUILD-PLAN (2026-08-08)

**Round identity:** Phase DOC, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead: coordinator
(Opus). Implementer: clearskies-docs-author (you, Sonnet). Auditor: clearskies-auditor
(adversarial, at Gate DOC — you will not see its brief; it will not see this report).

**Task:** update every governing document to the ruled TARGET state of the plan, BEFORE any
code lands. Content is sourced ONLY from the plan and the brief — no invented detail. Every
section describing not-yet-deployed behavior carries the tag
**`(ruled 2026-08-08; lands with Phase <X> of L1-BOUNDARY-REBUILD-PLAN)`** where `<X>` is
the implementing phase (W, B, G, S, A, or C). The implementing phase removes the tag on
deploy. Do not change any statement about behavior that IS live today except to add the
tagged target-state text beside/replacing it per the plan's DOC.2–DOC.4 instructions.

## READING LIST (read BEFORE writing anything; you implement what THESE say, not this brief)

1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — the ENTIRE plan. Your spec is
   Phase DOC (DOC.1–DOC.4 + Gate DOC rows). The Pre-approval register (P1–P15), the named
   constants block, the SWAN SYNTAX PRESCRIPTIONS section, and each phase's Design
   paragraphs are the content you are documenting.
2. `docs/planning/briefs/L1-ISLAND-BOUNDARY-RELOCATION-BRIEF-2026-08-08.md` — the ENTIRE
   brief, especially §8 rulings D1–D13 (the decision record ADR-104 captures), §5 (boundary
   contract), §6 (silent-fallback inventory), D7 matrix (service area).
3. `rules/clearskies-process.md` — "ADR discipline" + "ADR content standards" sections.
4. `docs/decisions/_TEMPLATE.md` — the ADR format.
5. `docs/decisions/ADR-093-swan-trushore-nearshore-model.md`, `ADR-100-geography-aware-study-area-geometry.md`,
   `ADR-103-spectral-boundary.md` — read their current amendment conventions before adding notes.
6. `docs/ARCHITECTURE.md` — the L1 sizing region (~:108, ~:118), the boundary paragraph
   (~:122), the SWAN-inputs paragraph, and wherever the service area is stated. Line numbers
   are hints, not gospel (plan PRIME DIRECTIVE 7): verify by content, report drift.
7. `docs/manuals/PROVIDER-MANUAL.md` — §14.3/§14.3a (WW3 boundary), §14.12 (water-temp
   chain / RTOFS's existing role), §14.15. Read before rewriting §14.3a.
8. `docs/manuals/API-MANUAL.md` — data-model section + §19.7 (no-publish slugs).
9. `docs/manuals/OPERATIONS-MANUAL.md` — admin sections + help-key inventory conventions.
10. `docs/manuals/DASHBOARD-MANUAL.md` — beach-profile chart + heatmap + card sections.
11. `docs/contracts/openapi-v1.yaml` — surf forecast response schema region.

## SCOPE

**Files you may create:**
- `docs/decisions/ADR-104-island-aware-l1-partition-boundary.md`

**Files you may modify:**
- `docs/decisions/ADR-093-swan-trushore-nearshore-model.md` (amendment note → ADR-104)
- `docs/decisions/ADR-100-geography-aware-study-area-geometry.md` (amendment note → ADR-104)
- `docs/decisions/ADR-103-spectral-boundary.md` (amendment note → ADR-104; see Lead calls)
- `docs/decisions/INDEX.md` (ADR-104 row)
- `docs/ARCHITECTURE.md` (the four regions DOC.2 names — L1 sizing, boundary, SWAN inputs,
  service area — nothing else)
- `docs/manuals/PROVIDER-MANUAL.md` (DOC.3 items only)
- `docs/manuals/API-MANUAL.md` (P13 fields in the data model; new slug in §19.7)
- `docs/contracts/openapi-v1.yaml` (P13 additive fields, tagged via description text)
- `docs/manuals/DASHBOARD-MANUAL.md` (C2/C3 target display behavior, tagged)
- `docs/manuals/OPERATIONS-MANUAL.md` (admin sources panel + override field, tagged;
  help-key inventory list entries)

**Files NOT to touch:** ANY file outside the list above. No code, no tests, no
`rules/*.md`, no `reference/*.md`, no other planning docs, no other ADRs, no
DESIGN-MANUAL.md, nothing in `repos/`. The Operator Manual in the stack repo
(`repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`) is Phase A's doc-sync, NOT yours.

**Verification command (run before closeout):**
`git -C c:\CODE\weather-belchertown diff --stat` — must show ONLY the allowlisted files.
Also run `git status --short` and confirm the only modified tracked files are allowlisted.

**Deliverable:** one commit on the meta repo (`c:\CODE\weather-belchertown`, branch main —
note: LOCAL COMMIT ONLY, coordinator pushes) titled
`docs(L1-plan): Phase DOC — governing docs to ruled target state (ADR-104, D1–D13)`.
Closeout via SendMessage: list every file touched, every target-state tag added (count per
file), and any drift found between plan-quoted line numbers/text and actual file state.

## LEAD CALLS (already decided — follow, do not re-derive)

1. **The new ADR is ADR-104, not ADR-101.** The plan's "ADR-101" number is stale — ADR-101
   (surf-score), ADR-102, ADR-103 already exist. Same content as the plan's DOC.1 spec,
   number 104. Title: "Island-aware L1 sizing and partition-reconstruction WW3 boundary".
   Status: **Accepted** (operator-authorized in-plan: DOC.1 says status Accepted, recording
   operator rulings D1–D13 with the brief as evidence — this is the operator's own ruling
   record, not a new proposal).
2. **ADR-103 gets an amendment note too** (plan omission, coordinator call): ADR-103
   documents the multi-station `.spec` boundary that Phase B supersedes (register P4/P5).
   Add an amendment note in ADR-103 pointing to ADR-104, tagged with the standard
   target-state tag (Phase B) — the station path is live TODAY and stays live until B lands,
   so the note says "superseded when Phase B lands", not "superseded".
3. **Every constant in ADR-104 comes from the plan's "Named constants" block verbatim**
   (cap 100.0 km, margin 10.0 km, σθ_ref 15°, K_FILL 1, spreads s=28/s=7, σf 0.015 Hz,
   γ 3.3, spacing = L1 dx, wind pad 0.3°, STOFS gate ≤ 0.15 m; r and RTOFS endpoint are
   "measured-then-pinned" — state their bounds and method, not a value).
4. **The D11 distinction must appear verbatim in ADR-104:** missing data → refuse loudly
   with the reason (D5); constrained geometry → best physical answer, silently (D11).
5. **P13/C-phase display items** (API-MANUAL, openapi, DASHBOARD-MANUAL, OPERATIONS-MANUAL)
   are tagged Phase C or Phase A respectively per the plan's DOC.4.
6. **INDEX.md**: one new row for ADR-104, Accepted, 2026-08-08. Do not renumber or touch
   other rows.

## OPEN QUESTIONS
Surface via SendMessage before writing if: any plan statement contradicts the brief; any
manual region the plan names cannot be located; anything requires content not present in
plan or brief. Do NOT resolve such gaps by invention.

## MANDATORY BLOCKS

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via
> SendMessage. Do not resolve it yourself.

> **Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked
> change, STOP and report it via SendMessage — do not modify code to make it pass, and do
> not delete it on your own authority. A behavior change and its test updates land in the
> same commit, per your task's design; a test you were not told to touch that fails against
> your change is a finding. Your closeout report must list every test you modified or
> deleted, with the reason, and every guard, invariant, or viability check that fired during
> your work — including ones you believe are unrelated or pre-existing.

> **Architectural changes — STOP, do not proceed.** You may not make an architectural
> change. If your task requires one, STOP and report via SendMessage — do not implement it,
> do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient,
>    threshold or criterion inside one. This does NOT cover changing how the same equation
>    is solved — iterative vs closed-form, solver tolerance, vectorisation. Test: does it
>    change *which equation is satisfied*, or only *how precisely/efficiently*? Only the
>    first is architectural. An approximation that does not converge to the original
>    equation IS a formula change and is covered.
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is
>    responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components — field names, shapes, nullability, units
>    crossing a boundary.
> 5. Changes where a computation happens — host, service, process, or lifecycle stage.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "my task's acceptance criteria are unreachable without
> it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or
> stale document is a finding to report, not permission to change code).
>
> You MAY still: resolve a contradiction between two statements inside the same document by
> taking the reading its own examples support (and say so); apply a rule already written in
> the rules files; fix code that diverges from its own stated contract.
>
> **The coordinator's ruling on your report is FINAL.** You surface an architectural
> concern ONCE, via SendMessage, then comply with the coordinator's answer. If the
> coordinator states that operator approval exists, that statement is your full
> authorization — verifying the approval chain is the coordinator's responsibility and the
> coordinator's alone. Do not refuse a second time, do not demand to see the paper trail,
> do not audit the coordinator's authority.

**Note for this round:** you are DOCUMENTING pre-approved architectural changes (the plan's
Pre-approval register P1–P15 — operator: "if it is in the plan, it is allowed"). Writing
tagged target-state documentation of a registered change is your task, not a violation. A
change NOT in the register that any document seems to require → STOP and surface.

**SCOPE-ACK REQUIRED:** before writing anything, SendMessage the coordinator ("main") a
one-paragraph acknowledgment: what you will deliver, what you will NOT touch, the
verification command. Wait for confirmation.

**Tone: concise, direct, no filler.** This is documentation of decided rulings — record
them exactly, cite the ruling IDs (D1–D13) and register rows (P1–P15), invent nothing.
