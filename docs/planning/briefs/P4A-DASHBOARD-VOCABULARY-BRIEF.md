# Round brief — Marine Service Separation Plan, Phase 4A task T4A.1 (dashboard side)

**Round:** MARINE-SEP-P4A-A3 (beach profile vocabulary — dashboard)
**Date:** 2026-07-24
**Lead (coordinator):** Opus
**Implementation agent:** `clearskies-dashboard-dev` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet) — adversarial audit, mandatory, no deferral

---

## 1. Round identity and mandate

You are implementing the **dashboard half of T4A.1** of
`docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md` — steps 2, 3, 4, 5 and 6 of its
"Do" list. A `clearskies-api-dev` agent implements step 1 (the API side) in
parallel, in a different repo, against the same fixed vocabulary decision.

**NO DEFERRAL RULE applies.** Read §"NO DEFERRAL RULE" at the top of the plan.
If you cannot complete a step, STOP and report via SendMessage. No TODOs, no
"will follow up", no partial renames.

---

## 2. Reading list — read these BEFORE writing any code

Read the original text. This brief deliberately does not restate their content.

1. `docs/planning/MARINE-SERVICE-SEPARATION-PLAN.md`:
   - §0.3 (git restrictions), §0.4 (scratch discipline)
   - §"Phase 4A" Purpose and the 7-item Origin list — item 4 is your task's
     reason for existing.
   - **§T4A.1 in full** — the Problem paragraph, the 4-column vocabulary table,
     the Decision paragraph, all 6 Do steps, and all 7 Accept bullets. This is
     your specification.
   - §T4A.4 — not yours, but it changes the **surf** endpoint response contract in
     a way you must handle. See lead call LC-5 below.
   - §"Adversarial Audit — Phase 4A" item 1 and §"QC Gate 4A" — what you are
     checked against. Audit item 1 is a mechanical grep; make sure it will pass.
2. `docs/manuals/DASHBOARD-MANUAL.md` — the sections on data flow, API types, and
   the marine/surf page.
3. `docs/manuals/DESIGN-MANUAL.md` — the marine card sections. You are not
   redesigning anything, but any state you add (e.g. an "unavailable" state) must
   follow existing patterns, not invent one.
4. `rules/coding.md` — §2, §3, §4, **§5 (accessibility — the §5.7 per-change
   checklist is mandatory)**, **§6 (i18n — the §6.1 dashboard rules and §6.4
   grep-checkable FAIL conditions)**, §9 (build verification — zero TS errors),
   §10 (design system compliance).
5. `rules/clearskies-process.md` — "UI implementation quality gates" and
   "Independent lead verification of ALL teammate claims". Note that I will
   re-run your verification commands myself.
6. Source files you are modifying — read each in full before editing:
   - `repos/weewx-clearskies-dashboard/src/api/types.ts` (the beach-profile and
     heat-map type families)
   - `repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx`
   - `repos/weewx-clearskies-dashboard/src/components/marine/tabs/HeatMapCard.tsx`
   - `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`
   - `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml`
7. The API side you must match — **read-only**:
   - `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py`,
     specifically `_build_transect_profile()` and the `transect_index == "all"`
     branch of `get_beach_profile()`. Both the single-transect and all-transect
     responses come from the same builder, so both change together.

---

## 3. Pre-round verification (performed by the lead, 2026-07-24)

- Dashboard repo HEAD `9603fe6`. Working tree has one pre-existing, unrelated
  delta: `public/card-manifest.json` (+14 lines, a `marine-summary` card entry).
  **Do not touch it and do not commit it.**
- API repo HEAD `0d87b28`. The API currently emits, from
  `_build_transect_profile()`: array key `"transect"`, point keys
  `"distanceFromShore"`, `"depth"`, `"waveHeight"`; break-point keys
  `"distanceFromShore"`, `"depth"`, `"waveHeight"`. Verified by reading the source.
- **Both dashboard type families are currently wrong against that API**, in
  opposite directions — this is the two-parallel-type-systems problem T4A.1 fixes:
  - `HeatMapTransectData.hsEnvelope` — API renamed this key to `transect` in
    commit `89c3bfe`; the dashboard type was never updated.
  - `HeatMapEnvelopePoint` already uses `distance` / `depth` / `hs` — which is
    what T4A.1 standardises on, so this type is **already correct** and its
    point-level fields need no change (T4A.1 Do step 4 says exactly this).
  - `BeachProfileTransectPoint` and `BeachProfileBreakPoint` use
    `distanceFromShore` / `waveHeight` — these are what get renamed.
- Verified counts to expect: `distanceFromShore` appears 8× in `types.ts` and
  across ~20 lines of `BeachProfileChart.tsx`; `waveHeight` appears 8× in
  `types.ts` and 7× in `BeachProfileChart.tsx`; `hsEnvelope` appears once in
  `types.ts` (line 1721) and in `HeatMapCard.tsx`. `HeatMapCard.tsx` has zero
  `waveHeight` references. Use these as a completeness check, not as a licence to
  blind-replace — read each site.
- **`grep -rn "degraded" src/` returns no consumer of the surf endpoint's
  `degraded` field.** The dashboard has never surfaced SwellTrack degradation to
  the user. See LC-5.

---

## 4. Scope

### 4.1 Files to create or modify (exhaustive)

| File | What changes |
|---|---|
| `src/api/types.ts` | Type merge per T4A.1 Do step 2. |
| `src/components/marine/tabs/BeachProfileChart.tsx` | Field accesses per Do step 3. |
| `src/components/marine/tabs/HeatMapCard.tsx` | Array key per Do step 4. |
| `src/components/marine/tabs/SurfingTab.tsx` | Verify per Do step 5; change only if the type merge breaks it. |
| `src/api/openapi-v1.yaml` | Add beach profile schemas per Do step 6. |
| `src/locales/*.json` (all 13 locales) | **Only if** LC-5 requires a new string. See LC-5. |
| Any test file under `src/` covering the above | Update to the new field names if they reference them. |

### 4.2 Files NOT to touch

- `public/card-manifest.json` (pre-existing dirty file).
- Anything in `repos/weewx-clearskies-api/` — **read-only reference.** The API
  side of T4A.1 belongs to a different agent. Do not "helpfully" fix the API.
- Anything in `repos/weewx-clearskies-swan-swelltrack/`,
  `repos/weewx-clearskies-stack/`, `repos/weewx-clearskies-marine/`.
- `src/api/generated-types.ts` — generated; do not hand-edit.
- Any file in the meta repo (`docs/`, `rules/`, `reference/`) — the coordinator
  owns governing-doc updates this round.
- **Any file on any container.** You are forbidden from editing files on weewx,
  weather-dev or librewxr by any mechanism.

### 4.3 Verification commands — run all, report raw output

```bash
# 1. Zero TypeScript errors. rules/coding.md §9: tsc failure = silent deploy failure.
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard
npx tsc --noEmit

# 2. Vocabulary grep — this is Adversarial Audit item 1, run it yourself first.
#    Expected: ZERO matches in src/ (generated-types.ts and historical comments aside).
grep -rn "hsEnvelope\|distanceFromShore" src/
#    And: no `waveHeight` remaining in beach-profile/heat-map context.
grep -rn "waveHeight" src/components/marine/ src/api/types.ts
```

Then, on **weather-dev** (read-only remote execution — running builds and tests is
permitted; editing is not):

```bash
ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-dashboard && npm test -- --run 2>&1 | tail -15"
```

The weather-dev checkout is at the pre-round commit and you cannot push or pull.
If remote verification requires the lead to deploy first, **say so explicitly**
rather than inventing a workaround that edits the container. The lead will deploy
and re-run. `npx tsc --noEmit` locally is not optional and has no such excuse.

**Render-and-look is mandatory.** `rules/coding.md` §4 "Render and LOOK before
declaring any UI/mockup change done": you may not review a visual change by
reading its markup. `tsc` passing is not visual verification. Report explicitly
whether you were able to render the surf page's Beach Profile chart and Heat Map
card, and what the rendered image actually showed. If no dev server or browser is
available to you, **say so plainly and do not claim the visual is correct** — the
lead will do the visual sign-off (per `rules/clearskies-process.md`:
"'Code-complete' requires coordinator visual sign-off").

### 4.4 Deliverable definition

- 1–3 commits on the local `main` branch of the dashboard repo, messages naming
  the task (`refactor(T4A.1): …`).
- `git status` clean apart from `public/card-manifest.json`.
- A SendMessage closeout walking **every one of T4A.1's 7 Accept bullets** with
  evidence — the file and line, or the command and its raw output. Assertion
  without evidence will be rejected.

---

## 5. Lead calls — decisions already made; implement them, do not re-derive

### LC-A — The unified point type keeps the extra optional fields

`BeachProfileTransectPoint` carries four fields `HeatMapEnvelopePoint` does not:
`swellHeight`, `breakingFraction`, `breakingDissipation`, `waveShape`. Merging
must not lose them — the Beach Profile chart's overlays depend on them.

**Implement:** one interface with `distance`, `depth`, `hs` as the required
fields and the four extras as optional (`?`). `HeatMapEnvelopePoint` becomes a
type alias of it, per T4A.1 Do step 2's "they become aliases of the unified
types". Same treatment for the break-point types: the unified break point carries
`distance`, `depth`, `hs`, `faceHeight`, `breakerType` per T4A.1 Do step 1, with
`partitionLabel` and `jackingFactor` optional. `HeatMapBreakPoint` becomes an
alias.

Name the unified types for the concept, not for one of the two consumers —
`BeachProfilePoint` / `BeachProfileBreakPoint` or similar. Do not keep
`HeatMapEnvelopePoint` as the primary name; the plan says those become aliases.

### LC-B — Aliases, not deletions

T4A.1 Do step 2 says "Remove the `HeatMapEnvelopePoint` and `HeatMapBreakPoint`
types — they become aliases of the unified types." That sentence is
self-contradictory read literally. **Implement as aliases** (`export type
HeatMapEnvelopePoint = BeachProfilePoint;`), which is what the second clause
says and what keeps `HeatMapCard.tsx` and `HeatMapProfileData` readable. The
Accept bullet that matters is "One type definition for cross-shore points" —
an alias satisfies it; two independent interface declarations do not.

### LC-C — `hs` is nullable; `distance` and `depth` are not

Match the existing nullability exactly: `hs: number | null` (the current
`waveHeight` and `HeatMapEnvelopePoint.hs` are both nullable), `distance: number`,
`depth: number`. Do not widen or narrow nullability while renaming — that is a
behaviour change smuggled into a rename, and the chart's null-guards depend on it.

### LC-D — Units in the doc comments

The current `BeachProfileTransectPoint` doc comments say "in meters" for
`distanceFromShore`/`depth` but "in display units" for `waveHeight`;
`HeatMapEnvelopePoint` says "in meters" for distance/depth and "display units"
for `hs`. The API converts all three via `_convert_unit(...)` to the operator's
display units — verified in `_build_transect_profile()`. **The "in meters"
comments are wrong.** Fix them to "in display units" as part of the merge. A
merged type with contradictory unit documentation is worse than two wrong ones.

### LC-E — `modelStatus` and nullable `breakingFaceHeight`

T4A.4 (a different agent, same phase) replaces the surf endpoint's boolean
`degraded` field with a `modelStatus` field taking `"ok"`, `"no_breaking"`,
`"unavailable"`, `"degraded_bulk"`, and makes `breakingFaceHeight` **nullable**
(null = model failed; 0.0 = genuinely flat).

I verified the dashboard has **no consumer of `degraded`**, so its removal breaks
nothing. But nullable `breakingFaceHeight` does matter: rendering `null` as `0`
would tell a surfer the ocean is flat when the model actually failed — the exact
class of silent degradation this whole phase exists to eliminate.

**In scope for you:**
1. Update `SurfForecast` (or whatever the surf forecast type is called in
   `types.ts` — locate it) to drop `degraded` and add `modelStatus` with the four
   literal values, and make `breakingFaceHeight` / `breakingHawaiianHeight`
   nullable.
2. Wherever the dashboard renders `breakingFaceHeight`, ensure `null` renders as
   the existing "no data" treatment (an em dash or the existing unavailable
   state — **use what the codebase already does**, do not invent a new one), and
   `0` renders as zero. Find these sites; do not guess.
3. If — and only if — a user-visible string is genuinely needed and none exists,
   add it via `t()` with keys in **all 13 locale files**, per `rules/coding.md`
   §6.1 and §6.4. Prefer reusing an existing key. Tell me which you chose.

This is a doc-code-sync requirement, not scope creep: the response field you
consume is changing in the same phase, and shipping the rename without it leaves
the dashboard reading a field that no longer exists.

### LC-F — OpenAPI schemas must match the API, not your types

T4A.1 Do step 6 adds beach-profile schemas to `openapi-v1.yaml`, which are
currently entirely absent. Write them from the **API response shape** as produced
by `_build_transect_profile()` and the `"all"` branch — read that Python and
document what it emits after the T4A.1 rename (`transect` / `distance` / `depth`
/ `hs`), including the single-transect response, the `transect_index=all`
response with its `profiles` / `perPartitionBreaks` / `metadata` keys, and the
`transect_index` query parameter's three accepted forms. Do not document your
TypeScript interfaces and call it a spec.

If you find the API emits something your merged types cannot represent, that is a
finding — SendMessage me, do not paper over it.

---

## 6. Open questions — SendMessage the lead; do NOT resolve unilaterally

- If the type merge forces a change in a component outside §4.1's file list,
  name the component and stop.
- If `SurfingTab.tsx` needs more than the "verify it still works" that T4A.1 Do
  step 5 anticipates, describe what and why before changing it.
- If you cannot locate the surf forecast type or the `breakingFaceHeight` render
  sites for LC-E, say so — do not skip LC-E.
- If adding OpenAPI schemas surfaces an API/dashboard contract mismatch beyond
  the field names (missing field, different nesting), report it. The API agent
  can still fix it this round.
- Anything that would require touching a file in §4.2.

---

## 7. Git restrictions (MANDATORY)

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`,
> `git rebase`, `git merge`, or `git checkout` of remote branches. You may only
> `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is
> ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

> **Agents edit and commit ONLY on the local machine — HARD BAN on container
> edits.** All editing and committing happens at
> `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`. You must NEVER
> edit source files on weewx, weather-dev or librewxr, and never run any git
> write operation on any container. SSH to containers is READ-ONLY.

**Commit messages:** use `git commit -F c:\tmp\<name>-msg.txt` — PowerShell
heredocs break on parens and quotes.

**Scratch file:** append to `c:\tmp\marine-sep-P4A-scratch.md` after every commit
and every decision. Do not reconstruct it at the end.

---

## 8. Scope acknowledgment — required before any code

Before writing any code, SendMessage the lead with a one-paragraph scope
acknowledgment: what you will deliver, what you will NOT touch, and the exact
verification commands you will run before closeout.
