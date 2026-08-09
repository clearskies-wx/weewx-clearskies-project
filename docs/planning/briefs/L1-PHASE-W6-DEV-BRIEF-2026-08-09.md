# ROUND BRIEF — W6: read the HRRR wind-grid rotation properly (L1-BOUNDARY-REBUILD-PLAN)

**Round identity:** Phase W task W6 (operator-ruled 2026-08-09, Q3). Lead: coordinator.
You: clearskies-api-dev (Sonnet). Tests: in-round (lead call — W6 is a single-module fix;
its KATs land with it, same commit or a paired commit). Auditor: lead-gate + the Phase V
blind walk (no separate W6 gate; Gate W is closed).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).
Dispatch happens only after Gate B closed and B-Accept recorded (one round at a time in
the marine repo).

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — task W6 (your spec,
   operator ruling verbatim) and W-Accept item 1 (the measured consequence of the current
   approximation: rotation angle depends on the fetch bbox; the plan's byte-identity
   check failed because of it).
2. `weewx_clearskies_marine/providers/wind/hrrr.py` — the whole module header comment,
   then: `_extract_eccodes` (:295-430, esp. the Lambert try/except at :381-391),
   `_extract_pygrib` (:445-535 — the alternate backend, degree + raw-μ° key forms),
   `_rotate_wind_field` (:246-287), `_compute_cone_factor` (:197-...), the fetch loop's
   parameter adoption (:876-893) and the result dict (:912-921).
3. `docs/manuals/PROVIDER-MANUAL.md` §14.14 (HRRR wind sourcing + rotation).
4. `rules/verification.md` — KAT falsifiability (which tests FAIL pre-change, transcript).

## PRE-ROUND VERIFICATION (lead, 2026-08-09, HEAD `11b5768`)
- The WARNING "could not extract Lambert Conformal parameters (LoV/Latin1/Latin2)" fires
  on EVERY live fetch (known journal noise, recorded in the session handoff).
- Code state verified at the lines cited above. Two lead observations — HYPOTHESES to
  verify empirically, not conclusions to code from:
  (a) `_extract_eccodes` :383 requests key `"LovInDegrees"`; the standard eccodes key
      spelling is `"LoVInDegrees"` (capital V). One wrong key inside the single
      try/except (:382-386) fails ALL THREE parameters even if Latin1/Latin2 would read.
  (b) Downstream consequence when the except fires: `grib_data.lov/latin1/latin2` stay
      `0.0`, and the fetch loop (:877-881) computes `cone_factor` from those zeros —
      verify what rotation actually happens live (cone factor from 0/0, and whether
      `lons_2d` is None or populated on the real filtered files — the :387 WARNING text
      claims the lon_first/lon_last approximation engages, which only happens when
      `lons_2d` is None; reconcile the message with reality).

## SCOPE
**Modify:** `weewx_clearskies_marine/providers/wind/hrrr.py` only.
**Create:** KAT test file (e.g. `tests/providers/wind/test_hrrr_lambert.py` — match the
repo's existing test layout; verify at scope-ack) + a small recorded GRIB2 fixture
(committed; keep it minimal — one message subset is enough).
**Do NOT touch:** any other provider, `services/*`, `swan_formats.py`, wind_gatherer,
service.py, any frozen-core file. No config keys, no new dependencies (eccodes and
pygrib are both already present).

## DESIGN (decided — plan W6, verbatim intent)
1. **Diagnose WHY eccodes fails** to read LoV/Latin1/Latin2 from the actually-fetched
   NOMADS-filtered GRIB2 (key names? subregion handling?). Capture one real filtered
   file as the fixture and enumerate its keys (`codes_keys_iterator` or grib_dump) —
   the diagnosis is empirical, from the fixture, not from documentation.
2. **Fix the extraction** so rotation uses the file's OWN projection metadata plus the
   per-point longitudes (`lons_2d` — the exact path that already exists in
   `_rotate_wind_field`). Read the three parameters independently (one failing key must
   not zero the others). Both backends (eccodes + pygrib) get the fix if both are wrong.
3. The `lon_first/lon_last` approximation REMAINS in the code as last-resort fallback
   only, now logging at **ERROR** (it should never fire). Do not delete it.
4. **If the filtered files genuinely do not carry the projection metadata → STOP and
   surface via SendMessage.** Hardcoding HRRR's published constants (lov=262.5°,
   latin=38.5°) is an operator decision, not a fallback you may implement.
5. KATs: (a) extraction succeeds on the recorded GRIB2 fixture — asserts the three
   parameters equal the fixture's own encoded values (independent expectation: state
   them as literals read from grib_dump, not via the code under test); MUST FAIL against
   the pre-change code (transcript in closeout). (b) Property test: two different fetch
   bboxes covering L1 produce identical rotated wind at the same points (the
   bbox-independence the operator asked for — "wobble" gone); build from two fixture
   subsets or synthetic grids exercising `_rotate_wind_field` with metadata-driven
   parameters.
6. No physics change: the rotation formula `alpha = n·(lon − LoV)` is untouched — this
   round changes WHERE its inputs come from (file metadata vs bounds-derived
   approximation), which is the already-operator-ruled W6 scope.

## VERIFICATION
`.venv-round4\Scripts\python.exe -m pytest <your new test file> tests/<existing hrrr
wind tests if any> -q` — targeted files only, NEVER the full suite. Falsifiability
transcript for KAT (a).

## ACCEPT (lead runs post-deploy, not yours)
The WARNING disappears from the journal after the next deploy; one matched-cycle
before/after wind diff recorded.

## LEAD CALLS
- Fixture is committed to the repo (small subset OK). If a full filtered file is >1 MB,
  trim to one UGRD message with eccodes copy tools and note the method.
- Both extraction backends fixed if both are broken; pygrib's raw-μ° fallback form kept.
- The scope-ack must name the exact test-file path and the fixture path.

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS (git
restrictions; stale-test; architectural). **SCOPE-ACK REQUIRED via SendMessage before
any code.** Tone: concise.

## OPEN QUESTIONS
None pre-identified beyond design item 4's STOP condition.
