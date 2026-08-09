# ROUND BRIEF — S4a: currents-ladder KATs — L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase S task S4a (ladder KATs; S4b wlevel KATs are DONE and off limits).
Lead: coordinator (session 6). You: `clearskies-test-author` (Sonnet). Dispatches AFTER the
S1 dev round's commits land; the lead states the S1 commit range at dispatch.

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).
Local venv: `.venv-round4\Scripts\python.exe`.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` §S4 rows (a), (f), (g)
   (re-respecified 2026-08-09 — your spec verbatim; row (b) is DELETED with the RTOFS rung)
   + §S1 (the design under test) + §Gate S rows (containment-not-centre is a gate row —
   your KAT is its evidence).
2. `docs/planning/briefs/L1-S1-CURRENTS-LADDER-DEV-BRIEF-2026-08-09.md` — LEAD CALLS 1-4
   (the pins your fixtures encode: field2d uvel/vvel_surface; roms_hiig; refusal message
   contract).
3. The S1 diff itself (`git log`/`git diff` on the stated range) — the seams you test.
4. `tests/test_stofs_wlevel_provider.py` — S4b's memory-KAT pattern (production-shaped
   fetcher memory KATs are MANDATORY for data fetchers — the S2 OOM lesson; copy the
   pattern, including the mutation-falsifiability transcript).
5. `rules/verification.md` — KAT mandate: every KAT closeout states which tests FAIL against
   pre-change code, with transcript; non-falsifiable pins declared as such.

## SCOPE
**Create:** KAT files for the ladder (naming per repo convention, e.g.
`tests/test_current_source_ladder.py`, `tests/test_stofs3d_currents_provider.py`,
`tests/test_pacioos_roms_provider.py` — final names yours, list them in scope-ack).
**Do NOT touch:** any source file, any existing test file (S4b's five files included), meta
repo. A source-code defect you find is a FINDING (SendMessage), never a fix.

## KATS REQUIRED (plan §S4 rows a/f/g, verbatim intent)
(a) Selection ladder: containment-covered bbox → that OFS (highest-resolution qualifier
    wins); East/Gulf bbox outside all OFS → STOFS-3D-Atl; Hawaii bbox → PacIOOS ROMS;
    a bbox NO rung contains → `CurrentCoverageError` with bbox + three declined rungs in
    the message, and NO publish path reached; a bbox whose CENTRE is in a domain but whose
    extent is not → next rung (containment, not centre — Gate S row).
(f) No-mixing: no summing on any rung (mutation: sum two sources → KAT fails, transcript);
    missing timestep on the selected source → raise, never a silent mid-cycle switch.
(+) Fetcher-shape KATs on tiny synthetic fixtures: STOFS-3D node-mask extraction →
    SWAN-dims float32 subset (memory KAT: retained bytes bounded, dtype float32 — the S2
    pattern); PacIOOS response parse → same output shape as `fetch_surface_currents`.
(g) Baselines 0-delta: the recorded selection
    `tests/test_island_autosizing.py tests/services/ tests/test_coops_fetch_datums.py tests/test_stofs_wlevel_provider.py tests/test_swan_wlevel_chain_fallback.py`
    still 249 pass / 3 tracked pre-existing; your new files all pass; report both counts.

## VERIFICATION (yours)
Your new files + the baseline selection above, `-q`, pre/post counts, falsifiability
transcripts (each KAT shown failing against mutated/pre-change code). NEVER the full suite.
No network in tests — fixtures/mocks only (the live smoke rows are the LEAD's S-Accept work,
not tests).

## MANDATORY BLOCKS — comply verbatim
The three blocks (git restrictions; stale-test; architectural) from `rules/agents.md`.
**SCOPE-ACK via SendMessage to "main" BEFORE ANY CODE** (file list, exclusions, exact
verification command). Wait for confirmation. Tone: concise.
