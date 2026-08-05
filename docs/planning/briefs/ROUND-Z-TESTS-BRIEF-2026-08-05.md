# ROUND Z TESTS BRIEF — guards for surf-zone truthing (marine)

**Round identity:** Round Z (surf-zone truthing), guards leg. Date 2026-08-05. Lead:
coordinator. Implementer was clearskies-api-dev (marine f4354b2/4c0f7e7/b551d03, api
c99f6d5 — all deployed and live-verified). You: clearskies-test-author. Auditor: blind,
after you.

## Pre-round verification (lead)

- marine repo clean at `b551d03`; ALL existing targeted tests pass against it (99 passed,
  7 files; also test_break_aware_handoff_domain.py 10 passed) — no stale call sites this
  time.
- Local toolchain works (Python 3.14 + pytest; proven twice this session).
- Live behavior at deploy (for fixture realism): saturated single-break profile → exactly
  1 break (jitter inner break eliminated); foam end = first sample at/inside the
  waterline (live: foam 21.29→9.29 m vs waterline 9.30 m); perBreakZones single entry
  mirroring aggregate on single-break days.
- Z0 live-proven: journal parses real stamps now ("stamped 20260807.180000 != requested
  start ..."). The stamp-semantics mismatch is a SEPARATE parked item — do NOT write a
  test asserting cross-cycle warm start engages.

## Scope

**Files you may create or modify (exhaustive allowlist):**
1. `repos/weewx-clearskies-marine/tests/services/test_hotstart_timestamp.py` — extend
   with the real-format fixture tests (T-Z0). You may refactor its `_hotfile_text` helper
   into a realistic builder, keeping the three existing tests passing (they pin the
   comparison/logging logic downstream — that behavior is unchanged).
2. `repos/weewx-clearskies-marine/tests/test_break_detection_z2.py` — NEW (T-Z2).
3. `repos/weewx-clearskies-marine/tests/test_zones_waterline_z1.py` — NEW (T-Z1 + T-Z3).

**Files you must NOT touch:** ANY source file, conftest.py, fixtures/, every other test
file, api/dashboard repos, docs.

## Reading list (read BEFORE writing any test)

1. This brief, fully.
2. `services/swan_runner.py` — `_read_hotfile_timestamp` + `_HOTFILE_TIMESTAMP_SCAN_LIMIT_BYTES`
   (~:1597-1640) and the caller that does the stamp comparison; the existing test file.
3. `services/surf_1d_analytical.py` — the three Z constants + `_find_break_points`
   (~:509-575), `_classify_zones` (~:574-658), `_classify_zones_per_break` (~:661-763).
4. `endpoints/beach_profile.py` — the `perBreakZones` response wiring + `_unavailable`
   mirror (for T-Z3's response-shape assertions; fixture style from
   tests/test_beach_profile_unification.py — READ but do not modify that file).
5. `tests/test_surf_1d_dispersion.py` — KAT pattern (independent hand math, never derive
   expectations by calling the code under test).

## Per-deliverable spec (lead calls — implement exactly)

**T-Z0 — hotstart real-format read guards** (extend test_hotstart_timestamp.py):
- A builder producing a REALISTIC hotfile layout: SWAN header lines, TIME block, a
  LOCATIONS block of configurable size, THEN the `"<token>    date and time"` record.
- Test A: date record placed past byte 5,000 (i.e. beyond the old 4096 prefix) →
  `_read_hotfile_timestamp` returns the token. **This is the fails-against-pre-change
  guard: state in your closeout that at 4c0f7e7^ (pre-Z0, commit f4354b2^) the old
  4096-byte read returns None for this fixture — you do NOT run git to prove it; the
  coordinator verifies via read-only worktree at acceptance.**
- Test B: date record placed beyond `_HOTFILE_TIMESTAMP_SCAN_LIMIT_BYTES` → returns None
  (cap honored).
- Test C: no date record at all (EOF before cap) → None.
- Keep the three existing tests green WITHOUT changing what they assert.

**T-Z2 — detection guards** (new test_break_detection_z2.py), hand-built arrays with
derivations in comments (KAT style):
- Saturated-jitter suppression: a profile whose ratio crosses gamma once then jitters
  ±2% around gamma shoreward → EXACTLY 1 break. (Designed to fail pre-change: the old
  `was_breaking` single-sample test re-fires on each jitter re-crossing.)
- Genuine reform re-fires: ratio crosses gamma (outer bar), drops to 0.55·gamma in a
  trough (below the 0.85·gamma re-arm), re-crosses at an inner bar → EXACTLY 2 breaks.
- Shallow shorebreak now visible: a break candidate at depth 0.2 m (between the new
  0.15 m floor and the old 0.3 m) with Hs > 0.15 m → detected. (Fails pre-change: old
  floor excluded it.)
- Constants pinned: `_BREAK_REARM_HYSTERESIS == 0.15`, `_MIN_BREAK_DEPTH_M == 0.15`,
  `_MIN_BREAK_HS_M == 0.15` — a tuning change must trip a test.

**T-Z1 + T-Z3 — zone guards** (new test_zones_waterline_z1.py):
- T-Z1a: `_classify_zones(..., waterline_m=w)` foam end == first sample with
  distance <= w (hand-pick arrays so the expected index is unambiguous). (Fails
  pre-change: old bore criterion ends foam earlier on the same fixture.)
- T-Z1b: `waterline_m=None` → legacy bore criterion (Hs<0.3 / depth<0.2) — unchanged
  behavior pinned.
- T-Z3a: two-break fixture → perBreak entry 0's impact end clamped at break 1's
  distance; entry 0's foam end == break 1's distance; entry 1's (innermost) foam end ==
  waterline sample.
- T-Z3b: single-break fixture → per-break entry mirrors the aggregate zones.
- T-Z3c: empty break list → `_classify_zones_per_break` returns empty list.

## Verification (yours, before closeout)

From `repos/weewx-clearskies-marine`:
`python -m pytest tests/services/test_hotstart_timestamp.py tests/test_break_detection_z2.py tests/test_zones_waterline_z1.py tests/test_break_aware_handoff_domain.py tests/test_beach_profile_unification.py -q`
Expected: **0 failed**. Paste the tail in your closeout.

## Deliverable definition

Commits on marine local main only: (1) T-Z0, (2) T-Z2, (3) T-Z1+T-Z3. Closeout via
SendMessage: commit hashes, pytest tail, the designed-to-fail-pre-change statements per
guard, tests modified (expected: only test_hotstart_timestamp.py, additively).

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage.
Local checkout only; never edit, commit, or run anything on any container or librewxr.

## Architectural changes — STOP, do not proceed

You may not make an architectural change of any kind (the 7-trigger test from the rules
applies; writing tests never requires one). If a test seems to need a source change,
STOP and report via SendMessage.

## Stale tests — STOP, do not obey them

If any existing test contradicts the deployed Round Z behavior, STOP and report via
SendMessage — the lead's pre-round verification says none does (99 passed), so finding
one is itself a discrepancy worth surfacing. Closeout lists every test you modified with
reason.

## Protocol

Before writing ANY code: SendMessage the lead ("main") a one-paragraph scope ack (what
you will deliver, what you will NOT touch, your exact local verification command). WAIT
for confirmation.
