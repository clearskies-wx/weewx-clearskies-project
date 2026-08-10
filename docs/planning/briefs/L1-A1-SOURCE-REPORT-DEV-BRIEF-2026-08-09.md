# ROUND BRIEF — A1: setup-time per-input source/coverage report — L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase A task A1. Lead: coordinator (session 6). You: `clearskies-api-dev`
(Sonnet). Auditor: `clearskies-auditor` at Gate A. Dispatches AFTER the S1+S4a round closes
on the marine repo (one round per repo at a time); the lead states HEAD at dispatch.

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-marine` (local commits only).

**Authorization:** pre-approved via plan register row **P10** (setup-time per-input
source/coverage report surfaced through config chain → admin; D5). The row authorizes
REPORTING of decisions already made — P10 grants NO new decision logic; adding any =
outside the register → STOP and surface.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` §A1 (your spec verbatim),
   §Gate A rows (the refusal drill your output must survive), register row P10, PRIME
   DIRECTIVE 8.
2. `docs/ARCHITECTURE.md` "L1-BOUNDARY-REBUILD-PLAN target state" block, Service-area
   bullet (the report's purpose in prose).
3. `weewx_clearskies_marine/services/grid_sizing_chain.py` — the config-push chain whose
   existing decisions you collect (bathymetry chain, wind region, current source [S1's
   `find_current_source`], WLEVEL chain, boundary product, datum path). Map each decision
   site before writing anything.
4. `weewx_clearskies_marine/endpoints/config.py` — the `/config` surface the block lands on.
5. The sizing-trace structure (where the chain already records its steps) — follow it from
   grid_sizing_chain.py.

## SCOPE
**Modify:** `services/grid_sizing_chain.py` (collect decisions into the structured block),
marine `/config` surface (`endpoints/config.py`) (expose the block on the existing payload).
**Do NOT touch:** any provider module, any decision logic (you REPORT decisions, never make
or alter them), swan.py, swan_runner.py, endpoints other than config.py, tests (test-author
seams only — leave the block-assembly function pure), meta repo, stack repo (A2's half).
No new config keys, no new dependencies, no new endpoints (the block rides the EXISTING
`/config` payload + sizing trace).

## DESIGN (decided — plan §A1 verbatim)
`inputs: [{input, source, coverage: ok|refused, reason?}]` appended to the existing sizing
trace + `/config` payload. Refusals carry the EXACT refusal string the chain already raises
(no paraphrase, no new wording). One entry per input chain: bathymetry, wind, currents,
water level, boundary product, datum path. No new decision logic — if you find an input
whose decision is not visible at the chain (and so cannot be reported without new logic),
that is a FINDING to SendMessage, not a licence to compute it.

## VERIFICATION (yours, before closeout)
`.venv-round4\Scripts\python.exe -m pytest tests/services/ <plus the test files matching
your changed files> -q` — name the exact selection in scope-ack; pre/post counts; 0 new
failures. NEVER the full suite. Do not write test files.

## MANDATORY BLOCKS — comply verbatim
The three blocks (git restrictions; stale-test; architectural) from `rules/agents.md`.
**SCOPE-ACK via SendMessage to "main" BEFORE ANY CODE** (deliverables, exclusions, exact
verification command, the decision-site map you found in grid_sizing_chain.py). Wait for
confirmation. Tone: concise.
