# Marine Fixit Plan — Full Re-Execution

**Status:** IN PROGRESS
**Created:** 2026-07-16
**Origin:** Complete re-execution of MARINE-FIXIT-PLAN. The original execution marked all 8 phases "✅ COMPLETE" but delivered broken code, corrupted governing documents (agents rewrote specs to match wrong implementations), false QC gate passes, and deferred verification. Nothing from the original execution can be trusted.

## Additional findings (not in original plan)

### FIX2-1: Hot-reload config (ADR-092)
Admin/wizard config saves restart the entire API for 2+ minutes. ADR-092 accepted. Implementation needed.

### FIX2-2: Huntington Harbor card shows no data
Location card shows dashes despite correct config. NDBC station prjc1 is a C-MAN (no wave sensor). Card needs forecast fallback for wave height, and wind data IS returned but not rendering.

### FIX2-3: weatherCode/isDay null on all locations
Weather icon never renders on any location card. API returns null for both fields.

### FIX2-4: Admin save runs redundant network calls
Every save re-downloads WFO and bathymetry even when coordinates haven't changed.

## Execution rules (non-negotiable)

1. **The PLAN is the authority.** Not the manuals, not the code, not agent claims. If a manual contradicts the plan, the manual is wrong and must be fixed.
2. **No QC deferrals.** Every QC gate runs in the same session as the phase. "Deferred to post-deploy" is banned.
3. **Visual verification required.** Dashboard changes must be verified on the live site before marking complete. Screenshots or live-site confirmation.
4. **No self-attestation.** The agent that writes code cannot declare it done. The coordinator verifies. The auditor verifies independently.
5. **Agents run on Sonnet 4.6** (pinned via ANTHROPIC_DEFAULT_SONNET_MODEL).
6. **Governing docs update FROM the plan**, not from code. If the code doesn't match the plan, the code is wrong.

## Phase tracking

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Documentation & Manual Updates | NOT STARTED |
| 1 | Critical Blockers & Data Correctness | NOT STARTED |
| 2 | Data Pipeline & Schema Fixes | NOT STARTED |
| 3 | Config UI Fixes (Wizard + Admin) | NOT STARTED |
| 4 | Marine Landing Page & Shared Layout | NOT STARTED |
| 5 | Surf Page Redesign | NOT STARTED |
| 6 | Fishing Page Redesign | NOT STARTED |
| 7 | Beach Safety & Boating Pages | NOT STARTED |
| 8 | Final QA | NOT STARTED |
| 9 | FIX2 items (hot-reload, Harbor card, weatherCode) | NOT STARTED |
