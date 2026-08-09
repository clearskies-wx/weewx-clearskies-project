# ROUND BRIEF — Phase W tests (W5), L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase W task W5, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead: coordinator
(Opus). You: clearskies-test-author (Sonnet). The W1–W4 implementation has ALREADY landed
on marine main (commit hash given at dispatch); you write the KATs pinning it. Auditor:
clearskies-auditor at Gate W (blind).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).

## READING LIST (read BEFORE any code)
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Phase W in full (W1–W5
   designs), PRIME DIRECTIVE, register rows P6/P10.
2. The W1–W4 implementation diff: `git log --oneline -5` then `git show <w-commit>` —
   the code under test as actually written (exception class names/locations, message
   formats, the fetch-time assert's placement).
3. Existing test conventions: `tests/services/` directory layout, nearest existing tests
   for `swan_formats` / `swan_runner` (fixtures, naming, parametrization style).
4. `rules/verification.md` — "Known-answer tests are mandatory" + the falsifiability rule
   (every KAT closeout states which tests FAIL against pre-change code, with transcript).

## SCOPE
**Files to create/modify:** test files ONLY, under `tests/` in the marine repo — a new
test module (or additions to the matching existing modules) covering the plan's W5 KATs:
(a) wind grid one cell smaller than CGRID → `WindCoverageError` naming the count;
(b) fetch-time assert fires on undersized bbox;
(c) current timestep gap (no OFS entry within 2 h) → raise;
(d) current U/V shape mismatch → raise;
(e) regression baseline: run the affected test DIRECTORY (`tests/services/`) on librewxr
    against the W commit once it is deployed there — the LEAD runs this at W-Accept; your
    job is that the new tests pass locally-on-librewxr-checkout semantics (pure-Python,
    tmp_path-isolated, no `/etc/weewx-clearskies` literals — Windows-green is not proof,
    per reference/clearskies-dev.md).

**Falsifiability:** for (a)–(d), demonstrate each test FAILS against pre-change code:
`git stash`-free method — check out the PRE-W commit of the module under test into a temp
copy? NO — instead do it the sanctioned way: run the test with the fill/pad behavior
mentally reverted is NOT acceptable; instead each KAT asserts the RAISE (which pre-change
code cannot produce: it silently filled). State in your closeout, per KAT: "pre-change
code returns silently-filled output; this test asserts <Error> is raised, so it fails
pre-change by construction" — plus run at least ONE of them against the pre-W commit
(`git worktree` is BANNED; use `git show <pre-commit>:<path> > <tmpfile>` + import-from-
tmp harness, or state clearly it was verified by construction only).

**Files NOT to touch:** any non-test file. If a W1–W4 behavior looks wrong while writing
tests, that is a FINDING — SendMessage, do not fix code.

**Verification command:** local run of just your new test file(s) with the repo venv or
`python -m pytest <your files> -q` if a local env exists; otherwise compile-check and
state that the executable run happens on librewxr at W-Accept (lead's step).

**Deliverable:** one commit on marine main (local): the new/updated test files. Closeout
via SendMessage: per-KAT falsifiability statements, every existing test you found pinning
the OLD fill behavior (list them — do NOT delete or modify any test the W commit did not
already handle without reporting first).

## MANDATORY BLOCKS
(identical to the dev brief — read them at
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS and comply:
git restrictions; stale-test STOP rule; architectural STOP rule. They bind you verbatim.)

**SCOPE-ACK REQUIRED** before code, via SendMessage to "main". **Tone: concise.**
