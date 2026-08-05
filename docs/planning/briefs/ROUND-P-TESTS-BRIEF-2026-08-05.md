# ROUND P TESTS BRIEF — guards for beach-profile unification (marine)

**Round identity:** Round P (profile unification), guards leg. Date 2026-08-05. Lead:
coordinator. Implementer was clearskies-api-dev (marine commits 4e0ff18 + 8c2def8, already
deployed). You: clearskies-test-author. Auditor: blind, after you.

## Pre-round verification (lead)

- marine repo local checkout `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`:
  clean at `8c2def8` (verified 2026-08-05 03:30 UTC).
- Targeted pytest on librewxr against deployed 8c2def8:
  `10 failed, 85 passed` — ALL 10 failures are
  `TypeError: _build_transect_profile() missing 1 required positional argument: 'tide_level'`
  in `tests/test_beach_profile_partition_index_spaces.py` (stale call sites; the Round P
  contract change added the parameter; implementer was forbidden from touching tests).
  Reproduced locally: `10 failed, 7 passed` in that file.
- LOCAL toolchain WORKS for marine unit tests: Python 3.14.2 + numpy/scipy/shapely +
  pytest 9.0.3 run the suite (`tests/test_wave_shape_classification.py`: 23 passed
  locally). Your verification loop is LOCAL. The canonical run (librewxr, Python 3.12)
  is the COORDINATOR's step after push+deploy — not yours.
- Live payload facts you may use as fixture-design reference (2026-08-05 03:24Z, HB pier):
  tideLevel −0.34 m; waterlineDistance +9.44 m (tide below datum ⇒ waterline seaward of
  the LMSL zero; interpolated beachElevation at that distance = −0.339 m ≈ tideLevel);
  beachElevation 261 signed points (−73.5..2157.6 m, +2.91..−15.03 m); impactZone.start
  25.55 m vs outermost break 25.6 m; waveShapes = 31 evenly spaced samples across the
  full input arrays; jackingFactors empty (pre-existing, also empty pre-deploy — do NOT
  write a test asserting non-empty jacking).

## Scope

**Files you may create or modify (exhaustive allowlist):**
1. `repos/weewx-clearskies-marine/tests/test_beach_profile_partition_index_spaces.py`
   — ONLY the 10 broken `_build_transect_profile(...)` call sites (T0), plus any small
   shared helper inside this file those fixes need.
2. `repos/weewx-clearskies-marine/tests/test_waterline_crossing.py` — NEW (T1).
3. `repos/weewx-clearskies-marine/tests/test_beach_profile_unification.py` — NEW (T2–T4).

**Files you must NOT touch:** ANY source file (`weewx_clearskies_marine/**` — a test that
seems to need a source change is a STOP-and-report), conftest.py, fixtures/, every other
test file, dashboard/api repos, docs.

## Reading list (read BEFORE writing any test)

1. This brief, fully.
2. `weewx_clearskies_marine/endpoints/beach_profile.py` — `_build_transect_profile()`
   signature and body (~:500-770): the Round P block at :660-710 (zones/shapes/jacking
   from pipeline arrays), the response dict incl. new fields `tideLevel` /
   `waterlineDistance` / `beachElevation` (~:729-766), and `_unavailable_profile_response`
   (new fields mirrored null, ~:800-812). Also the route handler ~:1013-1103 to see how
   `tide_level` is resolved and threaded.
3. `weewx_clearskies_marine/enrichment/bathymetry.py:1928-1994` — BOTH interpolators:
   `_interpolate_zero_depth_crossing` (existing) and `_interpolate_waterline_crossing`
   (new, Round P). Read the docstrings; note ascending-distance walk, LAST (seaward-most)
   crossing kept, None when `-tide_level` never reached.
4. `weewx_clearskies_marine/services/surf_1d_analytical.py` — module-level
   `_classify_zones` (:514-578), `_compute_wave_shapes`, `_compute_jacking` (both
   module-level after the Round P P1.3 extraction).
5. `tests/test_surf_1d_dispersion.py` — the known-answer-test pattern to copy: the
   reference values are computed INDEPENDENTLY (hand math / different algorithm), never
   by calling the code under test.
6. `tests/test_beach_profile_partition_index_spaces.py` — the file you are repairing;
   understand what each broken call site asserts before touching it.
7. `rules/coding.md` (project coding rules).

## Per-deliverable spec (lead calls — implement exactly)

**T0 — repair the 10 stale call sites.** Add the now-required `tide_level` argument to
each broken `_build_transect_profile(...)` call. LEAD CALL: pass `tide_level=0.0` at all
10 sites so every existing assertion is preserved unchanged — the parameter feeds ONLY the
new `tideLevel` field and the waterline computation; zones/shapes use `tr.depths`, which
the pipeline has already tide-blended upstream. VERIFY that claim yourself while reading
beach_profile.py; if you find tide_level influencing anything an existing assertion covers,
STOP and report — do not adapt assertions. Do not add new assertions to this file.

**T1 — waterline-crossing KAT** (`test_waterline_crossing.py`), targeting
`_interpolate_waterline_crossing(profile, tide_level)`:
- Fixture profiles are small hand-built lists; every expected crossing distance is
  HAND-COMPUTED linear interpolation written as a literal with the derivation in a
  comment. Never derive an expectation by calling the function.
- Cases (each its own test): (a) single crossing, tide 0 — must equal the hand value and
  also match `_interpolate_zero_depth_crossing` on the same profile; (b) tide > 0
  (waterline landward: crossing where depth == −tide < 0, i.e. on land relative to LMSL);
  (c) tide < 0 (waterline seaward — mirror of live behavior above); (d) multiple
  crossings (e.g. a bar/trough profile) — seaward-most (LAST in ascending-distance walk)
  is returned; (e) profile never reaches −tide_level — returns None; (f) crossing exactly
  on a node — returns that node's distance.
- DECLARATION REQUIRED in your closeout: this function is NEW in Round P, so
  "fails-against-pre-change" is vacuously unavailable (the function does not exist at
  47c8084). Declare the KAT non-falsifiable-against-pre-change per the 2026-08-03 rule,
  and state that its falsifiability is against the independent hand math instead.

**T2 — zones-anchor-to-published-breaks guard**
(`test_beach_profile_unification.py`): build a minimal fixture through
`_build_transect_profile()` (copy the fixture style of
`test_beach_profile_partition_index_spaces.py`) with ≥2 break points, and assert
`response["surfZones"]["impactZone"]["startDistance"]` equals the OUTERMOST published
`response["breakPoints"][*]["distance"]` (exact float equality is expected — same array
in, same array out; use `pytest.approx` with tight rel=1e-9 if identity is awkward).
This test MUST fail against pre-Round-P code (side-run zones were disjoint from published
breaks) — the COORDINATOR verifies that at acceptance via a read-only checkout of
47c8084; you do NOT run any git checkout. State in your closeout that you designed it to
fail pre-change and why.

**T3 — `_compute_wave_shapes` extraction pin** (same file): call the module-level helper
with fixture arrays and pin the CURRENT behavior: (a) returned sample distances all lie
within [min(distances), max(distances)]; (b) sample count for your fixture pinned as a
literal; (c) every regime value is from the legal set you observe in the source; (d) a
spot value (distance/depth of first + last sample) pinned as literals. Purpose: the P1.3
extraction was declared byte-identical; this pin catches any future "improvement" inside
the helper. Add one `_compute_jacking` smoke call with gamma=0.73 asserting it returns a
list WITHOUT asserting emptiness or non-emptiness.

**T4 — new-fields response guard** (same file): through `_build_transect_profile()`:
(a) `tideLevel` equals the value passed in; (b) `waterlineDistance` equals the
hand-computed crossing for your fixture profile at that tide; (c) `beachElevation` items
are `{distance, elevation}` with elevation == −(signed depth) from the RAW profile,
unclamped (include a land point with negative depth ⇒ positive elevation);
(d) `beachElevation` covers only `distance <= max(raw distances)`; (e) when the
transect-info/bathymetric_profile input is absent, all three fields are null/absent-safe
exactly as `_unavailable_profile_response` mirrors them.

## Verification (yours, before closeout)

Run LOCALLY from `repos/weewx-clearskies-marine`:
`python -m pytest tests/test_beach_profile_partition_index_spaces.py tests/test_waterline_crossing.py tests/test_beach_profile_unification.py tests/test_wave_shape_classification.py tests/test_jacking_resolution.py -q`
Expected: **0 failed** (test_beach_profile_partition_index_spaces.py: 17 passed).
Paste the tail of the run in your closeout. The canonical librewxr re-run is the
coordinator's, after push+deploy — do not attempt it.

## Deliverable definition

Commits on the marine repo local main only: (1) T0 call-site repair, (2) T1 KAT,
(3) T2–T4 unification guards. Closeout via SendMessage: commit hashes, local pytest tail,
the T1 non-falsifiability declaration, the T2 designed-to-fail-pre-change statement,
every test you modified with reason (expected: exactly the 10 call sites).

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or
`git checkout` of remote branches. You may only `git add`, `git commit`, `git status`,
`git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage.
Edit and commit ONLY in the local checkout. Never edit, commit, or run tests on any
container or on librewxr — your runs are local.

## Architectural changes — STOP, do not proceed

You may not make an architectural change. If your task requires one, STOP and report via
SendMessage — do not implement it, do not work around it, do not pick an option.
A change is architectural if it does ANY of these (mechanical test, not judgment):
1. Changes a physics/mathematical/scientific formula, or a constant, coefficient,
   threshold or criterion inside one (NOT covered: solving the same equation differently).
2. Deletes, replaces, or rewires a module/component/service, or changes its responsibility.
3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
4. Changes a data contract between components — field names, shapes, nullability, units.
5. Changes where a computation happens — host, service, process, or lifecycle stage.
6. Changes a schedule, trigger, or cadence.
7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
"My acceptance criteria are unreachable without it" and "a document says so" do NOT
authorize you — STOP and report.

## Stale tests — STOP, do not obey them

If an existing test OTHER than the 10 named call sites contradicts the deployed Round P
behavior, STOP and report via SendMessage — do not modify code, do not adapt or delete
that test on your own authority. The 10 call-site repairs in T0 are the ONLY pre-
authorized test modifications. Your closeout must list every test you modified or deleted
with reason, and every guard/invariant that fired during your work.

## Protocol

Before writing ANY code: SendMessage the lead ("main") a one-paragraph scope ack — what
you will deliver, what you will NOT touch, and your exact local verification command.
WAIT for confirmation. Then implement as 3 commits per the deliverable definition.
