# ROUND Z BRIEF — surf-zone truthing (marine + API)

**Round identity:** Round Z, authorized by operator 2026-08-05 in chat: "1. yes" (foam zone
to the tide-aware waterline), "2. yes" (break-detection rework — kill saturation jitter AND
detect the real shorebreak; operator domain ruling: "HB is notorious for its double break,
it is rare for there not to be a double break"), "yes" to D6 (per-break zone lists in the
contract). Z0 (hotstart read fix) is a defect fix restoring the code's own contract —
audit-evidenced, no criterion change. Lead: coordinator. Implementer: clearskies-api-dev
(marine + api). Guards: clearskies-test-author (after). Auditor: blind (after).

## Pre-round verification (lead)

- marine repo local checkout clean at `541644d` (Round P + guards; deployed process runs
  `8c2def8` source, identical). api repo at `ac96064`.
- Detection call chain verified single-path: pipeline → `run_1d_analytical()` per
  partition → `_find_break_points()` (surf_1d_analytical.py:852 is the ONLY call site).
  Published `breakPoints` come from `p_result.break_points` (surf_1d_pipeline.py:1811).
- `_classify_zones` consumers: run_1d_analytical:861 (internal; its zones are consumed by
  NOBODY downstream — pipeline reads only break_points/hs_profile) and
  beach_profile.py:686 (the published zones). Signature extension with a defaulted param
  is therefore safe.
- Live facts motivating Z1/Z2 (transect 14, 04:00Z, HB pier): inshore of the outer break
  Hs is depth-saturated at exactly gamma·d (0.73) continuously to the waterline — the
  physics already says whitewater-to-the-sand; the published foam zone stops at 137 ft
  only because of the classifier's 0.3 m bore threshold (:564). The published "inner
  break" at 205.6 ft is crossing-jitter on that saturated profile (ratio re-crossings
  around gamma), NOT a real reform: Hs is monotonic shoreward. The REAL HB shorebreak
  breaks in water shallower than the current 0.3 m depth filter (:526) can see.
- Z0 evidence (blind audit 2026-08-05): `_read_hotfile_timestamp()`
  (swan_runner.py:1597-1621) reads only the first 4096 bytes; the "date and time" record
  sits AFTER the LOCATIONS block at byte offsets 32,885 / 180,379 / 72,905 / 258,389 in
  the 4 live level hotfiles → token=None 100% of the time → every SWAN level cold-starts
  every cycle (223 journal hits since Jul 28). The record itself is well-formed
  (`20260807.180000                         date and time`) and `_parse_swan_time()`
  parses it when reached. The existing test fixture
  (tests/services/test_hotstart_timestamp.py `_hotfile_text`) puts the date line first in
  a tiny file and can never reproduce the failure.
- Constants idiom: this file documents criteria as module-level named constants with `#:`
  provenance comments (see `_JACKING_EXTREMUM_HALF_WINDOW_M`). Follow it exactly.

## Scope

**Files you may modify (exhaustive):**
1. `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/swan_runner.py`
   (Z0 — `_read_hotfile_timestamp` ONLY)
2. `repos/weewx-clearskies-marine/weewx_clearskies_marine/services/surf_1d_analytical.py`
   (Z1/Z2/Z3 — `_find_break_points`, `_classify_zones`, new `_classify_zones_per_break`,
   the new named constants, and the `SurfZones`-adjacent dataclass/serializer if per-break
   zones need one)
3. `repos/weewx-clearskies-marine/weewx_clearskies_marine/endpoints/beach_profile.py`
   (Z1 waterline threading + Z3 `perBreakZones` response field + `_unavailable` mirror)
4. `repos/weewx-clearskies-api/weewx_clearskies_api/services/marine_response_conversion.py`
   (Z4 — conversion entries for `perBreakZones` nested fields ONLY)

**Files you must NOT touch:** tests (test-author owns), the pipeline
(surf_1d_pipeline.py, surf_pipeline_timestep.py), SWAN runner beyond the one function
(no grid/physics/sequence code), SurfBeat, dashboard repo, config, docs.

## Reading list (read BEFORE coding)

1. This brief, fully.
2. `services/surf_1d_analytical.py` — `_find_break_points` (:509-536), `_classify_zones`
   (:539-603), the constants idiom block (:606-660), `run_1d_analytical` zone/break calls
   (:852-861).
3. `endpoints/beach_profile.py` — `_build_transect_profile()` Round P block (:660-710),
   waterline computation + response fields (:729-770), `_unavailable_profile_response`.
4. `services/swan_runner.py:1580-1630` — `_read_hotfile_timestamp` and its caller, plus
   the hotfile-writing side so you understand the real file layout (SWAN header → TIME →
   LOCATIONS coordinate block → "date and time" record).
5. api repo `services/marine_response_conversion.py` — the existing beach-profile
   conversion entries (pattern from c1a8212/ac96064).

## Per-deliverable spec (lead calls — implement exactly)

**Z0 — hotstart timestamp read fix.** Replace the fixed 4096-byte read in
`_read_hotfile_timestamp` with a bounded line-scan that reads until the "date and time"
record or EOF, capped at a named constant `_HOTFILE_TIMESTAMP_SCAN_LIMIT_BYTES = 2_000_000`
(largest live hotfile record offset is 258 KB; 2 MB gives 8x headroom and still refuses to
scan a multi-GB corrupt file). Read incrementally (line-iterate; do NOT slurp the whole
hotfile — level hotfiles are ~10 MB). Preserve the function's exact contract: returns the
parsed datetime or None, same log messages on the None path. No other behavior change.

**Z1 — foam zone ends at the tide-aware waterline.**
`_classify_zones(Hs, depths, distances, break_points, waterline_m: float | None = None)`.
When `waterline_m` is not None: the foam-zone end index becomes the first shoreward sample
with `distances[i] <= waterline_m` (arrays arrive seaward-first, distances descending),
replacing the `Hs < 0.3 or depths < 0.2` bore criterion; keep that legacy criterion as the
fallback when `waterline_m` is None (and for run_1d_analytical's internal call, which
passes nothing). Constant for nothing new here — the change is which sample ends foam.
`beach_profile.py` passes the SAME waterline value it publishes as `waterlineDistance`
(it is already computed inside `_build_transect_profile`).

**Z2 — break-detection rework in `_find_break_points`.** Two changes, each a named
constant with a `#:` provenance comment citing this brief + operator approval 2026-08-05:
- `_BREAK_REARM_HYSTERESIS = 0.15` — after a break fires, detection re-arms only when
  `ratio < gamma * (1 - _BREAK_REARM_HYSTERESIS)`. Replaces the bare `was_breaking`
  previous-sample test. Effect: a depth-saturated profile (ratio pinned at gamma) can
  never re-fire on jitter; a genuine reform (ratio drops in a trough, then re-crosses at
  an inner bar or the beach step) still fires.
- `_MIN_BREAK_DEPTH_M = 0.15` — replaces the literal `depths[i] > 0.3`. Rationale: the
  real HB shorebreak breaks in ~0.15-0.5 m of water; 0.3 m structurally excluded it.
  Keep `min_break_hs = 0.15` as-is (promote it to a `#:` named constant
  `_MIN_BREAK_HS_M = 0.15` while you are there — value unchanged).
State in your closeout: these constants are gate-presented — the coordinator shows the
operator worked examples before the round closes; do not tune them further yourself.

**Z3 — per-break zones (D6, operator-approved contract addition).** New module-level
`_classify_zones_per_break(Hs, depths, distances, break_points, waterline_m)` returning a
list ordered outermost-first, one entry per break point k (n = len(break_points)):
- `impactZone[k]`: start = `break_points[k].distance_m`; end = the existing 50%-energy
  criterion (first shoreward sample with `Hs <= 0.707 * Hs_at_break_k`), CLAMPED so it
  never crosses the next break: if k < n-1 and the criterion end lies shoreward of
  `break_points[k+1].distance_m`, end = `break_points[k+1].distance_m`.
- `foamZone[k]`: start = impact end; end = `break_points[k+1].distance_m` for k < n-1;
  for the innermost break (k = n-1): end = the Z1 waterline semantics (waterline_m, with
  the legacy bore criterion as the None-fallback).
- Each entry: `{"breakDistance": m, "breakerType": str, "impactZone": {startDistance,
  endDistance, startDepth, endDepth}, "foamZone": {same keys}}` — SI metres.
Endpoint: add `"perBreakZones"` to the per-transect response dict next to `surfZones`
(which stays unchanged for back-compat), computed from the SAME published break list the
aggregate zones use; mirror as null in `_unavailable_profile_response`. Empty break list →
empty list (not null) when the model is available.

**Z4 — API conversion.** Add `perBreakZones` nested-field entries (breakDistance,
impactZone/foamZone start/end distances + depths → display distance unit) to the marine
conversion table, following the existing beach-profile nested patterns, with `units`
entries as the table's idiom requires.

## Verification (yours, before closeout)

LOCAL toolchain works (Python 3.14 + numpy/scipy + pytest run marine unit tests — proven
this session). From `repos/weewx-clearskies-marine`:
`python -m pytest tests/test_wave_shape_classification.py tests/test_jacking_resolution.py tests/test_main_break_zone_headline.py tests/test_beach_profile_partition_index_spaces.py tests/test_waterline_crossing.py tests/test_beach_profile_unification.py tests/services/test_hotstart_timestamp.py -q`
Expected: existing suite state preserved EXCEPT tests that pin the OLD detection/zone
behavior — if any such test fails, STOP and report it (stale-test protocol below); do NOT
adapt code or tests. Also grep-verify: no remaining literal `0.3` depth filter in
`_find_break_points`; `perBreakZones` present in response dict + unavailable mirror +
conversion table; `4096` gone from `_read_hotfile_timestamp`.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If a remote is ahead or behind, STOP and report via SendMessage.
Edit and commit ONLY in the local checkouts. Never edit, commit, or run anything on any
container or on librewxr.

## Architectural changes — STOP, do not proceed

You may not make an architectural change beyond the FOUR operator-authorized items in this
brief (Z1 foam-end criterion, Z2 detection criteria/constants, Z3 perBreakZones contract
addition, Z0 defect fix). A change is architectural if it: (1) changes a physics/math
formula or any constant/threshold/criterion inside one (beyond the four); (2) deletes/
replaces/rewires a module or changes its responsibility; (3) changes a model's domain/
grid/boundary/resolution/handoff; (4) changes a data contract (beyond perBreakZones);
(5) changes where a computation happens; (6) changes a schedule/trigger/cadence;
(7) adds/removes a dependency, port, endpoint, config key, or persisted file.
"Acceptance criteria unreachable" and "a document says so" do NOT authorize you — STOP
and report via SendMessage.

## Stale tests — STOP, do not obey them

If an existing test contradicts your tasked change (e.g. pins the old 0.3 m depth filter,
the old foam-end criterion, or single-sample re-arm), STOP and report it via SendMessage
with the test name and what it pins — do not modify code to make it pass, do not adapt or
delete it yourself. Test updates are the test-author's, in the guards leg. Your closeout
lists every test you touched (expected: none) and every guard/invariant that fired.

## Protocol

Before writing ANY code: SendMessage the lead ("main") a one-paragraph scope ack (what you
will deliver, what you will NOT touch, your exact local verification command). WAIT for
confirmation. Implement as 4 commits: (1) Z0 hotstart read fix, (2) Z1+Z2 classifier/
detector, (3) Z3 marine contract, (4) Z4 api conversion. Closeout via SendMessage: commit
hashes per repo, pytest tail, grep outputs, constants declared, tests touched (none).
