# ROUND BRIEF — S4b: wlevel/datum KATs (L1-BOUNDARY-REBUILD-PLAN)

**Round identity:** Task S4b — the wlevel/datum half of S4 (S4a currents-ladder KATs
dispatch later, with S1). Lead: coordinator. You: `clearskies-test-author` (Sonnet).
QC: `clearskies-auditor` at Gate S (blind). **Repo:**
`c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).
Dispatches AFTER the S2/S3 dev round lands; the lead states the S2/S3 commit hashes and
HEAD at dispatch — your tests run against that code.

**Authorization:** tests for the pre-approved S2/S3 work (register P8/P9/P12). You write
tests ONLY — no production-code changes. A production defect you find is a finding to
report via SendMessage, never to fix yourself.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §S4 rows (c), (d),
   (e), (g); §S2 and §S3 designs (what the code under test must do); Gate S rows (what
   the auditor will try to break — your KATs should survive it).
2. The six S2/S3 lead rulings — restated at the top of
   `docs/planning/briefs/L1-PHASE-S-DEV-BRIEF-2026-08-09.md` "SIX LEAD RULINGS" section
   (the dispatched version's rulings are in the lead's dispatch message; the lead
   confirms they are unchanged at your dispatch). They define the behavior your KATs pin:
   water-level-only fetcher, region tokens, Metadata-API datums + offset arithmetic,
   DEM entries, S3 branch gating + config-push-cached offsets, nearest-within-2h +
   per-cycle selection + whole-cycle STOFS failure semantics.
3. The S2/S3 diffs themselves (`git show` the hashes the lead names) — test the real
   interfaces, not the plan's paraphrase.
4. `rules/verification.md` — KAT mandate: independent reference, falsifiability
   transcript (which tests FAIL against pre-S2/S3 code — for new modules, mutation-based
   falsifiability: state the mutation that breaks each KAT).
5. Existing test idioms: `tests/services/` fixtures for writer-shape tests;
   `tests/test_island_autosizing.py` for KAT structure.

## SCOPE
**Create/modify:** test files ONLY, under `tests/` (name them at scope-ack; follow the
repo's existing layout — providers tests beside existing provider tests, services tests
under `tests/services/`). **Do NOT touch:** any production module, any existing test not
directly pinning superseded wlevel behavior (a superseded-behavior test you must touch →
report first, stale-test rule), conftest beyond additive fixtures.

## DELIVERABLES (plan §S4 rows, wlevel/datum half)
- (c) STOFS grid → WLEVEL.txt shape KAT: recorded/synthetic STOFS field fixture through
  the existing `_write_wlevel_grid_txt` path — grid dims, ordering, timestep count exact.
- (d) chain fallback order + loud log + refuse: STOFS ok → STOFS used; STOFS gap →
  whole-cycle CO-OPS-uniform fallback with the loud log line asserted; both fail →
  `tide_fetch_failed` refusal. Per-cycle semantics: a single missing STOFS timestep
  fails the WHOLE cycle over to CO-OPS (no per-timestep mixing — mutation: mix → fails).
- (e) Hawaii datum KAT: Oahu fixture, synthetic station datums JSON (Metadata-API
  shape), MHW→LMSL arithmetic exact (independent hand-computed expected values in the
  test, not derived from the code); NAVD88/geodetic source → `DatumConversionError`
  raise; offsets cached at config push (no per-cycle datums fetch — assert call count).
- (g) baseline 0-delta: the tracked baseline (210 pass / 3 pre-existing fail at
  `eecfabc`, tests/test_island_autosizing.py + tests/services/) unchanged by your round
  apart from your own additions.

## VERIFICATION (yours, before closeout)
`.venv-round4\Scripts\python.exe -m pytest <your new files + tests/services/> -q` from
the marine repo root; record counts. NEVER the full suite. Closeout states each KAT's
falsifiability evidence (mutation + transcript) per rules/verification.md.

## MANDATORY BLOCKS
Comply verbatim with the three blocks (git restrictions; stale-test; architectural) in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS.
**SCOPE-ACK REQUIRED via SendMessage to "main" before any code:** test-file list,
fixture strategy, exact pytest selection. Wait for confirmation. Tone: concise.
