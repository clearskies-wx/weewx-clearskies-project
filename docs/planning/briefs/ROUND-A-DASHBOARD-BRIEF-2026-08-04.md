# ROUND A BRIEF — dashboard quick fixes (EYEBALL-FIX-PLAN 2026-08-04)

**Round identity:** Round A of EYEBALL-FIX-PLAN-2026-08-04.md. Date 2026-08-04. Lead: coordinator
(this session). Implementer: clearskies-dashboard-dev. Guards: clearskies-test-author (SEPARATE,
after implementation). Auditor: clearskies-auditor (blind, after implementation).

## Pre-round verification (lead, 2026-08-04)

- dashboard repo clean, `main` @ `63733b1` (verified `git status` / `git log -1`).
- Loci verified live by lead: `SurfingTab.tsx:204-282` (ScoreBar; fillPct at :219),
  `useApiQuery.ts` (pollInterval in SECONDS, ×1000 at :307-308), DESIGN-MANUAL:1343-1362
  (SURF-1 section), `BeachProfileChart.tsx` exists at `src/components/marine/tabs/`.
- D2 RULED 2026-08-04: shadow line + AT BREAK rows are STRIPPED (see updated S-SPEC-2 in the
  plan). No exception rows remain.

## Scope

**Files you may modify (exhaustive):**
1. `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx` (A1, A2)
2. `repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx` (A3, A3b)
3. `repos/weewx-clearskies-dashboard/src/hooks/useApiQuery.ts` (A4)
4. `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts` (A4 — marine hooks pollInterval only)

**Files you must NOT touch:** anything else. Specifically: no tests (test-author owns them), no
i18n locale files, no DESIGN-MANUAL/docs (coordinator owns doc sync this round), no API/marine
repos, no `api/client.ts`, no components outside the two listed.

**Deliverable:** one commit per task (A1, A2, A3+A3b, A4) on dashboard `main`, local only.

## Reading list (read BEFORE coding)

1. `docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md` — §1 S-SPEC-2 (as amended by D2: strip
   shadow line + AT BREAK rows too), S-SPEC-3, S-SPEC-4; §2 Round A table rows A1–A4 (your
   acceptance criteria, verbatim).
2. `src/components/marine/tabs/SurfingTab.tsx` — ScoreBar component (:204-282) and the entire
   Current Swell card JSX block.
3. `src/components/marine/tabs/BeachProfileChart.tsx` — zone-label background-rect pattern
   (~:656-670) and break-point label rendering (~:740-850); the wave-shapes toggle state.
4. `src/hooks/useApiQuery.ts` — full file (refresh/poll/error flow).
5. `git show a49059d -- src/components/marine/tabs/SurfingTab.tsx` — the 2026-07-16 baseline
   Current Swell card (title + 3 stat tiles + component table + compass) A2 strips back to.

## Per-task lead calls (decisions already made — follow, do not re-derive)

- **A1:** only `mode === 'factor'` bars change: `fillPct = max ? min(100, |score|/max*100) :
  min(100, |score|)`. Adjustment-mode bars keep current behavior (they are deleted wholesale in
  Round S; do not redesign them now). Delete the stale comment at :217-218 citing "SURF-1 §3".
- **A2:** strip to the a49059d baseline + KEEP the existing peel row. REMOVE: best-peak/average
  headline, main-break-zone text, wave-shape row, SurfBeat section, shadow line, AT BREAK rows
  (D2 ruling — the plan's S-SPEC-2 is already updated; re-read it). Render-only removal: do NOT
  touch types/fields in hooks or client — `shadowFaceHeight`/`perPartitionBreaks` stay in the
  payload types.
- **A3:** break-point labels get the same background-rect treatment zone labels already have
  (rounded rect, card-glass fill, ~:656-670 pattern) + collision handling: labels closer than
  56 px horizontally stagger vertically in 14 px steps, 2-pass greedy from seaward. No other
  visual changes (full redesign is a separate approved effort — do not attempt it).
- **A3b (folded-in defect fix, operator-confirmed):** wave-shape glyphs must not render when the
  "Show wave shapes" toggle is off — the toggle is currently not honored (eyeball item 9g).
  Restore the component to its own stated contract; no new features.
- **A4:** in `useApiQuery`: on fetch error, schedule a retry with exponential backoff
  5 s → 10 → 20 → 40 → cap 60 s; a successful fetch resets backoff and the normal poll timer
  keeps running. **pollInterval is in SECONDS in this codebase** (×1000 at :307-308) — the
  plan's `120_000` is a plan erratum; use `pollInterval: 120` on the marine hooks in
  `useWeatherData.ts` (`useMarineDetail` and sibling marine hooks that currently have no
  pollInterval). No contract change; no new exports.

## Open questions

Surface via SendMessage BEFORE deciding yourself: any case where the a49059d baseline conflicts
with current props/types; any label-collision case the 2-pass greedy cannot resolve; anything
that looks like it needs a type/contract edit.

## Verification

You cannot run node toolchains locally (DILBERT has none; weather-dev builds happen at deploy).
Before each commit: re-read your diff (`git diff`) against the acceptance row in the plan table,
and grep-verify: A1 → no `/100`-equivalent fill on factor bars (`fillPct` must reference `max`);
A2 → no `SurfBeat|shadowFaceHeight|perPartitionBreaks|AT BREAK` markup remains in the Current
Swell card JSX; A3b → wave-shape render is gated on the toggle state. Report the grep outputs in
your closeout. The coordinator deploys to weather-dev and runs the build + vitest there.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage.
Do not resolve it yourself. Edit and commit ONLY in the local checkout at
`c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`. Never edit or commit on any
container.

## Architectural changes — STOP, do not proceed

You may not make an architectural change. If your task requires one, STOP and report via
SendMessage — do not implement it, do not work around it, do not pick an option.

A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or
   criterion inside one. This does NOT cover changing how the same equation is solved. Test:
   does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the
   first is architectural.
2. Deletes, replaces, or rewires a module/component/service, or changes what one is
   responsible for.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units
   crossing a boundary.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.

These do NOT authorize you: "my task's acceptance criteria are unreachable without it" (then
your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a
finding to report, not permission to change code).

You MAY still: resolve a contradiction between two statements inside the same document by
taking the reading its own examples support (and say so); apply a rule already written in the
rules files; fix code that diverges from its own stated contract.

(Note: A2's strip and A4's pollInterval additions are operator-authorized by the plan and the
D2 ruling — they are not yours to re-litigate, just implement as specified.)

## Stale tests — STOP, do not obey them

If an existing test contradicts your tasked change, STOP and report it via SendMessage — do not
modify code to make it pass, and do not delete it on your own authority. A behavior change and
its test updates land in the same commit, per your task's design; a test you were not told to
touch that fails against your change is a finding. Your closeout report must list every test
you modified or deleted, with the reason, and every guard, invariant, or viability check that
fired during your work — including ones you believe are unrelated or pre-existing.

## Protocol

Before writing ANY code: SendMessage the lead a one-paragraph scope acknowledgment — what you
will deliver, what you will NOT touch, and the verification you will run before closeout. Wait
for the lead's confirmation. Then implement task by task, one commit each, and SendMessage a
closeout report (commits, grep outputs, tests touched: expected none).
