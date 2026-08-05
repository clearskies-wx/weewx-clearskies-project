# ROUND A-T BRIEF — guards for Round A (EYEBALL-FIX-PLAN 2026-08-04)

**Round identity:** Task A-T of EYEBALL-FIX-PLAN-2026-08-04.md Round A. Date 2026-08-04.
Lead: coordinator. You: clearskies-test-author. You land guards SEPARATELY from the
implementer (whose commits a35373d/ca0689e/c39fe30/0debd2a are already on local main).

## Pre-round verification (lead)

- dashboard repo local main @ 0debd2a (pushed; weather-dev deploy in progress).
- Known state: `SurfingTab.test.tsx` has a describe block "SurfingTab — shadowFaceHeight
  secondary readout (D10.2)" (~4 tests) that pins behavior REMOVED by the operator's D2
  ruling — those 4 currently FAIL, expected. No `src/hooks/*.test.*` files exist.

## Scope

**Files you may create or modify (exhaustive):**
1. `src/components/marine/tabs/SurfingTab.test.tsx`
2. `src/hooks/useApiQuery.test.ts` (new file)

**Files you must NOT touch:** all source files (the implementation is FINAL — if a test
cannot pass against it, that is a finding to SendMessage, never a reason to want source
changed), all other test files, i18n, docs.

**Deliverable:** 1-2 commits on dashboard local main, tests only.

## Reading list

1. `docs/planning/EYEBALL-FIX-PLAN-2026-08-04.md` §2 Round A rows A1/A4/A-T + §1 S-SPEC-2
   (D2-amended) and S-SPEC-4.
2. `src/components/marine/tabs/SurfingTab.tsx` — ScoreBar (:204-235) as implemented at
   a35373d; the Current Swell card block as stripped at ca0689e.
3. `src/components/marine/tabs/SurfingTab.test.tsx` — the whole file, especially the D10.2
   describe block.
4. `src/hooks/useApiQuery.ts` at 0debd2a — the retry/backoff implementation
   (RETRY_DELAY_FLOOR_MS/CAP, the .catch path, the success-path reset).

## Per-deliverable spec (lead calls — implement exactly)

1. **D2 regression guard (replaces the stale D10.2 block):** delete the 4 tests asserting
   shadowFaceHeight/AT BREAK rendering; replace with guards asserting the Current Swell
   card does NOT render (a) a shadow face-height secondary line, (b) AT BREAK per-partition
   rows, even when the mocked payload carries non-null `shadowFaceHeight` and
   `perPartitionBreaks`. Cite "D2 ruling 2026-08-04, S-SPEC-2" in the describe name.
2. **A1 guard (bar denominator):** ScoreBar factor-mode: score 21, max 35 → rendered fill
   width style is 60% (21/35), NOT 21%. One more case: score 35, max 35 → 100%.
   Adjustment-mode: score −16 → width 16% (unchanged behavior).
3. **A4 guard (503 recovery):** new `src/hooks/useApiQuery.test.ts` with vitest fake
   timers: fetcher rejects once then resolves; assert a retry fires at ~5 s and data
   arrives WITHOUT any manual refetch/reload; assert consecutive failures back off
   (5→10→20 s…) and a success resets the delay (next failure retries at 5 s again). Do not
   test implementation internals — assert observable behavior (fetch call count over
   advanced time, returned data/error states).

## Fail-against-pre-change proof (mandatory, rules/verification.md KAT rule)

For the A1 guard: `git checkout a35373d~1 -- src/components/marine/tabs/SurfingTab.tsx`,
run ONLY your new A1 test, record the FAIL transcript, then
`git checkout a35373d -- src/components/marine/tabs/SurfingTab.tsx` (restore) and record
the PASS. Same technique for the D2 guard against ca0689e~1. The A4 guard's pre-change
proof: `git checkout 0debd2a~1 -- src/hooks/useApiQuery.ts`, expect FAIL (no retry fires),
restore, PASS. Closeout MUST include all three fail/pass transcripts. Verify `git status`
is clean of source-file modifications before your final commit.

## Verification command

Targeted vitest ONLY (never the full suite): `npx vitest run src/components/marine/tabs/SurfingTab.test.tsx src/hooks/useApiQuery.test.ts`.
Local runs are a smoke check only (known DILBERT/Linux divergence risk) — the coordinator
re-runs on weather-dev as the canonical result after push. Expected final state: all tests
in both files pass locally at your final commit.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`, and the specific `git checkout <local-hash> -- <file>` operations
listed above. If the remote is ahead or behind, STOP and report via SendMessage. Local
checkout only: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`. Never edit
or commit on any container.

## Architectural changes — STOP, do not proceed

You may not make an architectural change. If your task requires one, STOP and report via
SendMessage. A change is architectural if it: (1) changes a physics/math formula or a
constant/threshold inside one (not: how the same equation is solved); (2) deletes/replaces/
rewires a module or changes its responsibility; (3) changes a model's domain/grid/boundary/
resolution/handoff; (4) changes a data contract (field names, shapes, nullability, units);
(5) changes where a computation happens; (6) changes a schedule/trigger/cadence; (7) adds
or removes a dependency, port, endpoint, config key, or persisted file. "Acceptance
criteria unreachable" and "a document says so" do NOT authorize you. You MAY fix code that
diverges from its own stated contract; you write TESTS ONLY in this round regardless.

## Stale tests — STOP, do not obey them

If an existing test outside your spec contradicts the Round A implementation, STOP and
report via SendMessage — do not modify code, do not delete it beyond what spec item 1
explicitly authorizes. Your closeout must list every test you modified or deleted with the
reason, and every guard/invariant that fired during your work.

## Protocol

Before writing any code: SendMessage the lead a one-paragraph scope ack (deliverables,
exclusions, verification command). Wait for confirmation. Then implement, then closeout
via SendMessage: commit hashes, the three fail/pass transcripts, final vitest output.
