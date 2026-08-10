# ROUND BRIEF — A2: admin marine-sources panel + L1 offshore override field — L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase A task A2. Lead: coordinator (session 6). You:
`clearskies-dashboard-dev` (Sonnet; the config UI is stack-repo FastAPI/Jinja2/HTMX — you
own it per plan §A2 owner line). Docs half: `clearskies-docs-author` (separate dispatch,
same round). Auditor: `clearskies-auditor` at Gate A. Dispatches AFTER A1 closes (your
panel renders A1's block; the lead pastes a live sample of the block at dispatch).

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-stack` (local commits only).

**Authorization:** pre-approved via plan register rows **P3** (the `[swan]
l1_offshore_extent_km` override key — admin exposure is THIS task) and **P10** (report
surfaced to admin). Anything beyond → STOP and surface.

## READING LIST (read BEFORE any code)
1. Plan `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` §A2 (spec verbatim),
   §Gate A rows, register rows P3/P10.
2. Stack repo: the admin template + routes that render `/health` `reasons[]` (H1.4
   precedent — the plan names it as the pattern; find it and follow it).
3. The wizard/admin help-key mechanism (`help.admin.*` keys) — existing examples.
4. `docs/manuals/OPERATIONS-MANUAL.md` — admin section conventions.
5. A1's live block sample (lead-pasted at dispatch) — the exact shape you render.

## SCOPE
**Modify (stack repo):** admin template + route for the marine-sources panel; the admin
form handling for the ONE new field; help content keys `help.admin.marine_sources.*`.
**Do NOT touch:** wizard steps, other admin sections, marine repo, dashboard repo, meta
repo (Operator Manual is docs-author's dispatch), any provider/model code. No new
dependencies.

## DESIGN (decided — plan §A2 verbatim)
- **Sources table:** READ-ONLY render of A1's `inputs` block (input / source / coverage /
  reason). A `refused` row shows the exact refusal string. No editing, no refresh logic
  beyond the panel's normal load.
- **Override field:** ONE numeric field writing `[swan] l1_offshore_extent_km`. Validation
  mirrors G5: blank = autosize; value > the 100 km cap rejected with the cap named in the
  error message. No other validation invented.
- Help keys for every new element (`help.admin.marine_sources.*`), same round.

## VERIFICATION (yours, before closeout)
The stack repo's own test/lint conventions for admin routes (name the exact command in
scope-ack; if the repo has no test harness for this surface, say so in scope-ack and the
lead rules). 0 new failures.

## MANDATORY BLOCKS — comply verbatim
The three blocks (git restrictions; stale-test; architectural) from `rules/agents.md`.
**SCOPE-ACK via SendMessage to "main" BEFORE ANY CODE.** Wait for confirmation. Tone:
concise.
