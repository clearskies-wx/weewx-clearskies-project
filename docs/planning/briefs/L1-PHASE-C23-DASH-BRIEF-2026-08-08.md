# ROUND BRIEF — Phase C tasks C2 + C3 (dashboard), L1-BOUNDARY-REBUILD-PLAN

**Round identity:** Phase C (C2, C3), L1-BOUNDARY-REBUILD-PLAN-2026-08-08. Lead:
coordinator (Opus). You: clearskies-dashboard-dev (Sonnet). Auditor: clearskies-auditor
at Gate C (blind). C1 (server aggregates + swell card) is a SEPARATE later round — not
yours.

**Repo:** `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard` (branch main,
HEAD `749ba29`, verified clean/synced; local commits only). R5 (dominant-partition
serving) is DEPLOYED and closed — the served breakPoints all carry the same
`partitionInfo.partitionIndex`; you may rely on that contract.

## READING LIST (read BEFORE any code)
1. `docs/planning/L1-BOUNDARY-REBUILD-PLAN-2026-08-08.md` — Phase C intro + C2 + C3
   designs in full (your spec), register rows P14/P15, Gate C rows.
2. `docs/manuals/DASHBOARD-MANUAL.md` — the Beach Profile and Heat Map sections,
   including the tagged `(ruled 2026-08-08; lands with Phase C ...)` target-state bullets
   Phase DOC added — your doc-sync REMOVES those tags and makes the text live.
3. `src/components/marine/tabs/BeachProfileChart.tsx` — the wave-surface generation
   region (C2's ONLY target in this file; the :585-594 break-marker filter region stays
   exactly as R5 left it — verify by content, line numbers are hints).
4. `src/components/marine/tabs/HeatMapCard.tsx` + `HeatMapCard.test.tsx` — C3's target.
5. The imagery API contract the heatmap consumes (find the fetch/bbox code in
   HeatMapCard.tsx; the imagery endpoints are READ-ONLY — consult, never modify).
6. `docs/manuals/DESIGN-MANUAL.md` — only the sections governing chart axes/labels.

## SCOPE
**Files to modify (exhaustive):**
- `src/components/marine/tabs/BeachProfileChart.tsx` — C2: the drawn wave train(s)
  become the DOMINANT swell only, selected by the `partitionInfo.partitionIndex` carried
  on the served breakPoints (all entries share it post-R5); fallback when no breakPoints
  served: the largest-face component from the swell list (mirrors the backend's own
  dominance criterion — do NOT invent a second definition). Amplitude/wavelength/breaking
  envelope math of the drawn train UNCHANGED — only WHICH train(s) draw.
- `src/components/marine/tabs/HeatMapCard.tsx` — C3 per the plan's design block:
  (a) imagery layer drawn rotated by the beach bearing about the chart frame (the heatmap
  grid is already beach-frame and does not change); imagery REQUEST bbox = north-up
  enclosing box of the rotated heatmap footprint + buffer, computed never hardcoded;
  (b) 50 m visible ortho buffer beyond the heatmap extent on all four sides;
  (c) y-axis tick labels + unit title in the same unit family as the x-axis (if the
  x-axis lacks a title, label both — verify at scope-ack and state what you found);
  (d) DELETE the structure-affected-area overlay layer + its legend entry (dashboard
  only; the API field keeps serving).
- `src/components/marine/tabs/HeatMapCard.test.tsx` + a vitest for C2's selection helper
  (new file or colocated per repo convention — name it at scope-ack).
- `docs/manuals/DASHBOARD-MANUAL.md` (meta repo) — remove the two Phase-C tags for
  C2/C3, text matches implementation; note the structure-overlay API field as
  served-but-not-rendered (deprecation note per the plan).

**Files NOT to touch:** anything else — no API/marine code, no other dashboard
components, no `endpoints/*` anywhere, no shared chart utilities unless the change is
provably additive (surface at scope-ack if you believe one is needed), NOT the
break-marker filter region R5 left in BeachProfileChart.tsx, NOT `HeatMapCard`'s imagery
API endpoints/contract.

**Verification command:** `npm run test -- <your test files>` (or the repo's vitest
invocation — verify from package.json) run locally; `npm run build` must succeed; record
gzipped bundle size vs the ADR-033 budget (baseline table in
reference/clearskies-dev.md).

**Deliverable:** commits on dashboard main (local): C2 and C3 (separate commits
preferred), tests, + meta-repo DASHBOARD-MANUAL doc-sync commit. Closeout via
SendMessage: files/lines, test counts, bundle size, and the axis-title finding.

## MANDATORY BLOCKS
Read and comply with the three mandatory blocks (git restrictions / stale tests /
architectural changes) verbatim from
`docs/planning/briefs/L1-PHASE-W-DEV-BRIEF-2026-08-08.md` §MANDATORY BLOCKS — they bind
you identically. C2/C3 are display-only and pre-approved (register P14/P15); anything
beyond their text → STOP and surface via SendMessage.

**SCOPE-ACK REQUIRED** before any code: SendMessage to "main" — deliverables, exclusions,
verification commands, the C2 selection-helper test location, and the axis-title finding.
Wait for confirmation. **Tone: concise.**
