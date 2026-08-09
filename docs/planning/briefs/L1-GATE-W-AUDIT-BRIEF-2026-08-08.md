# AUDIT BRIEF — Gate W (adversarial), L1-BOUNDARY-REBUILD-PLAN Phase W

**Round identity:** Gate W, L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead: coordinator. You:
clearskies-auditor (Sonnet), adversarial + blind: you get the DESIGN (plan Phase W) and the
commits, NOT the implementer's or test-author's reports. Report via SendMessage to "main".

**Claim under audit:** Phase W (W1–W4 + W5 tests) correctly replaced the spot ±1.0° wind
bbox with an L1-domain-derived bbox, deleted (not conditioned) the wind calm-fill and
current zero-fill, added a fetch-time coverage assert that fires before SWAN input build,
and registered the `wind_coverage_failed` no-publish slug. **Disprove it.** Hunt
especially for: a surviving fallback (fill deleted at one site, alive at another); the
assert placed after input build; the raise reachable only on paths that never execute; a
test that would still pass against pre-change code.

## Sources
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Phase W complete (W1–W5,
   W-Accept, Gate W rows), PRIME DIRECTIVE, register P6/P10.
2. The commits: marine repo `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine`,
   `git log --oneline a399eb6..HEAD` and the diffs.
3. `rules/verification.md` — three-layer model; KAT falsifiability.

## Gate rows (your own command evidence per row; no evidence = row FAILS)
1. **W1 completeness:** grep the WHOLE repo for surviving spot-±1.0 wind-bbox arithmetic
   (`grep -rn "1.0" weewx_clearskies_marine/{service.py,services/wind_gatherer.py,config/marine_config.py}`
   filtered to bbox contexts, plus `_HRRR_MARGIN_DEG` and `hrrr_bbox`) — all four call
   sites (service.py, wind_gatherer.py, swan.py full-run, swan.py quick-update) must route
   through the ONE new function. Any survivor = FAIL.
2. **W2/W4 deletion not conditioning:** open the diffs — the NaN→`0.0000` branch in
   `swan_formats.py` and `_ZERO_BLOCK`/padding in `swan_runner.py` must be GONE, not
   wrapped in an if. Mutation check: reintroduce the NaN fill locally (unstaged, revert
   after), run the W5 KAT that pins it → the KAT must FAIL against the mutant. Paste the
   run. Revert the mutation and confirm clean tree afterward (`git status`).
3. **W3 ordering:** by code reading, prove the fetch-time coverage check executes BEFORE
   any SWAN input file writing/run for the cycle (cite call order, file:line).
4. **Slug registration:** `wind_coverage_failed` present in state.py's registry; confirm
   the catch site records it. (Live /health visibility is W-Accept's row — the lead runs
   it; you verify the code path exists and is reachable.)
5. **KAT falsifiability:** for each of W5's KATs (a)–(d): does it assert the RAISE such
   that pre-change (silently-filling) code fails it? Run the W5 test files locally if an
   env exists, else static verification with reasoning. Any KAT that passes pre-change
   proves nothing — name it.
6. **Scope:** `git show --stat` over the round's commits — only Phase-W-allowlisted files
   (the plan's W1–W4 Files lists + tests/ + API-MANUAL §19.7 doc-sync). Any frozen-core
   file touched = automatic FAIL, surface immediately.
7. **Doc-sync:** API-MANUAL §19.7 entry's Phase-W tag removed and text matches the
   implemented message/behavior.

You may run mutation tests locally (edit → test → REVERT — never commit, never leave the
tree dirty). No git write operations beyond that ephemeral working-tree mutation. Findings
ranked by severity; empty rows only with named rule-outs.
