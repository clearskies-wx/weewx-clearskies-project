# ROUND BRIEF — S4: currents/wlevel/datum KATs (L1-BOUNDARY-REBUILD-PLAN, test-author)

**Round identity:** Phase S task S4 (S4a currents KATs + S4b wlevel/datum KATs — TWO
commit groups matching the two deploys). Lead: coordinator. You: clearskies-test-author
(Sonnet). Dispatched AFTER the dev's S1–S3 commits land (lead names the HEAD).
Auditor: `clearskies-auditor` at Gate S (blind).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §PHASE S task S4 rows
   (a)–(g) (your spec, verbatim), S1–S3 (behavior under test, esp. S1's compositing
   block), S-Accept + Gate S (which rows lean on your KATs).
2. `rules/verification.md` — falsifiability transcript requirement; independent
   expectations (hand-built synthetic fields, literals — never derived by calling the
   code under test).
3. The dev's shipped code at the HEAD the lead names: `providers/ocean/
   rtofs_currents.py`, `providers/ocean/stofs_wlevel.py`, `providers/ocean/ofs.py`
   (`find_current_source`), the two swan.py fetch sites, the wlevel wiring into the
   EXISTING `_write_wlevel_grid_txt` (:2329 — NOT `_write_wlevel_txt`, which is the
   uniform stamp; lead correction 2026-08-09), `services/vertical_datum.py`,
   `providers/tides/coops.py` (additive `datums` product, S3).
4. Existing test conventions: `tests/` flat layout; fixture precedent
   `tests/fixtures/providers/` (wavewatch, hrrr).

## SCOPE
**Create:** test file(s) matching repo convention (propose exact paths in scope-ack —
e.g. `tests/test_current_source_selection.py`, `tests/test_stofs_wlevel.py`,
`tests/test_hawaii_datum_branch.py`) + minimal recorded fixtures (RTOFS parse KAT (b),
STOFS shape KAT (c)) with provenance in docstrings.
**Do NOT touch:** production code, existing tests, conftest beyond strict fixture
registration (name it if so).

## DESIGN (decided — plan S4 rows (a)–(g), verbatim; hard edges)
- (a) selection: containment (not centre-in-box) proven — a bbox whose CENTRE is inside
  an OFS domain but whose extent is not must select RTOFS (this is Gate S's row).
- (f) composite: synthetic RTOFS+STOFS fields → summed u/v EXACT per cell (literal
  expectations); missing either component at one timestep → raise; the OFS branch
  never composites — mutation-style KAT (feed STOFS to an OFS-region fixture → assert
  no summation happens / it raises or ignores per the dev's shipped contract).
- (e) Hawaii: Oahu fixture, synthetic station datums, MHW→LMSL arithmetic exact
  (hand-computed literals); NAVD88 source present → `DatumConversionError` raised.
- Falsifiability: each KAT's closeout row states FAIL-pre-change (against the HEAD the
  lead names as pre-S) or declared non-falsifiable with reason.
- (g) baseline: changed-files + affected-directory selection, both counts + command.

## VERIFICATION (yours)
`.venv-round4\Scripts\python.exe -m pytest <your new files> tests/services/ -q`
(exact selection in scope-ack).

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS. **SCOPE-ACK
REQUIRED via SendMessage to "main" before any code.** Closeout: raw counts +
falsifiability transcript. Tone: concise.
