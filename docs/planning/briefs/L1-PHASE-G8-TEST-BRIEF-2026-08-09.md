# ROUND BRIEF — G8: island-autosizing KATs (L1-BOUNDARY-REBUILD-PLAN, test-author)

**Round identity:** Phase G task G8. Lead: coordinator. You: clearskies-test-author
(Sonnet). Dispatched AFTER the dev's G1–G6 commits land (lead will name the HEAD).
Auditor: `clearskies-auditor` at Gate G (blind).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — §PHASE G task G8
   (your spec: fixtures (a)–(g), verbatim), tasks G1–G6 (the behavior under test), the
   named-constants block (:97-101), and G-Accept (context for what the live deploy will
   check — your KATs are the pre-deploy layer).
2. `rules/verification.md` — three-layer model + KAT mandate: every KAT closeout states
   which tests FAIL against the PRE-G code (checkout/stash-based transcript required);
   hand-computed expected values are INDEPENDENT (from D11's formula, not from calling
   the implementation).
3. The dev's shipped code at the HEAD the lead names: `services/geography.py`,
   `services/swan_domain.py`, `services/grid_sizing_chain.py`, `config/marine_config.py`.
4. Existing test layout + fixture idioms: `tests/` (match the repo's conventions; the
   synthetic-coastline fixture pattern — find the existing geography/swan_domain tests
   and reuse their harness, do not invent a parallel one).

## SCOPE
**Create:** `tests/test_island_autosizing.py` (+ minimal committed fixture data if the
Huntington OSM fixture (e) needs a recorded file — keep it small; cite provenance).
**Modify:** nothing else. **Do NOT touch:** production code, existing tests, conftest
beyond what fixture registration strictly requires (name it in scope-ack if so).

## DESIGN (decided — plan G8 rows (a)–(g) are the spec, verbatim)
Hard edges only:
- (b)'s near-lee expected extents are HAND-COMPUTED from D11's arithmetic (chord width,
  `L_fill = W/(2·tan 15°)`) and stated as literals with the derivation in a comment —
  never derived by calling `_near_lee_max_extents`.
- (c) open-coast regression pin: box identical to pre-G sizing — this is the
  falsifiability anchor; it must PASS against pre-G code and every other KAT's
  falsifiability transcript must show it failing pre-G (or be declared non-falsifiable
  with the reason).
- (f) override: exact operator extent honored + enclosure suppression asserted.
- (g) zone-span refusal: assert the refusal message names the span and the cap.
- Baseline row: changed-files + affected-directory selection (tests/services/ etc.),
  NEVER the repo-wide suite; record both pre/post counts and the exact command.

## VERIFICATION (yours)
`.venv-round4\Scripts\python.exe -m pytest tests/test_island_autosizing.py
tests/services/ -q` (adjust to real layout; name it in scope-ack).

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS. **SCOPE-ACK
REQUIRED via SendMessage to "main" before any code** (file paths, fixture plan,
verification command). Closeout: raw counts + falsifiability transcript. Tone: concise.
