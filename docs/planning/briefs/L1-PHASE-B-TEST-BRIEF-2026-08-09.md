# ROUND BRIEF — Phase B tests (B5), L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase B task B5. Lead: coordinator. You: clearskies-test-author
(Sonnet). B1–B4 landed (commit range given at dispatch). Auditor: clearskies-auditor at
Gate B (blind).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).

## READING LIST
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Phase B (B5's KAT list
   K1–K7 is your spec), SWAN SYNTAX PRESCRIPTIONS §1/§2 (the grammar your KATs pin),
   named-constants block.
2. The B1–B4 diffs (`git show` each commit) — the code under test as written.
3. `rules/verification.md` — KAT falsifiability (state which tests FAIL pre-change, with
   transcript; non-falsifiable pins declared as such).
4. Existing station-suite tests (the ones pinning `ww3_station_selection`/catalogue) —
   you DELETE these, enumerated exhaustively in your scope-ack, per the plan's stale-test
   clause ("ONLY those named may be deleted, each listed in the closeout").

## SCOPE
**Create:** `tests/test_boundary_reconstruction.py` + `tests/test_partition_fields.py`
with KATs K1–K7 exactly as the plan lists them (K1 bin-sum identity ≤1% Hs recovery on a
synthetic 3-train input; K2 direction convention — synthetic due-W swell → energy at 270°
coming-from in the EMITTED file text; K3 multimodality — 3 trains → 3 distinct spectral
peaks; K4 wet-cell fallback ladder incl. the raise; K5 `[len]`/corner geometry vs a
hand-computed UTM fixture; K6 GLWU variant (hourly cadence, 2.5 km corridor); K7
missing-field raise).
**Delete:** ONLY the test files pinning the deleted station modules + any file B1–B4's
closeout listed as expectedly-broken whose sole subject is the station path (e.g.
`tests/services/test_ww3_fetch_backoff.py` IF its subject is the deleted fetch — if its
backoff idiom now lives in B1's fetcher, REWRITE it against the new fetcher instead of
deleting; state which you did and why). Enumerate every deletion in scope-ack AND closeout.
**Modify:** any existing non-station test broken by B1–B4 — intent-preserving repairs
only, same rules as the W5 round; report each with a one-line reason.
**Do NOT touch:** implementation files. A suspected implementation bug = finding via
SendMessage, not a fix.

K5's UTM fixture must be HAND-COMPUTED (independent arithmetic in the test, not calling
the code under test to generate its own expectation) — R5's degrees-in-metres lesson.
K1's identity check likewise recomputes m0 independently (trapezoid over the discrete
grid), not via the module's own helper.

**Verification:** run your new/changed test files with `.venv-round4`; falsifiability per
KAT (K1: break normalization → fails; K2: flip direction → fails; K5: swap a corner →
fails — demonstrate at least these three by ephemeral mutation, revert, clean tree).

**Deliverable:** one commit; closeout with per-KAT falsifiability transcript, the deletion
ledger, and the full run count.

## MANDATORY BLOCKS
Comply verbatim with the three blocks in
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS.
**SCOPE-ACK REQUIRED** (with the exhaustive deletion list) before code. **Tone: concise.**
