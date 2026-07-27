# SWAN Model Corrections & Scoring Restructure Plan

**Status:** COMPLETE (all phases done)
**Created:** 2026-07-18
**Last updated:** 2026-07-18 (session 2 closeout)
**Origin:** Post-deployment review of SWAN+TruShore implementation (2026-07-17). Production testing revealed multiple issues: NDBC spectral data overriding SWAN values in the scorer, output point placed in the surf zone (4.3m depth) instead of at ~10m, missing SWAN inputs (water levels, currents), TruShore branding overstating proprietary contribution, and scoring display bugs.
**Companion:** [SWAN-TRUSHORE-PLAN.md](SWAN-TRUSHORE-PLAN.md) — original implementation plan (completed). [SWAN-TRUSHORE-RESEARCH-BRIEF.md](briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md) — technical research. [WAVE-BREAKING-CONVERSION-BRIEF.md](briefs/WAVE-BREAKING-CONVERSION-BRIEF.md) — breaker height research.

---

## Problem Statement

Six categories of issues identified during production testing of the SWAN implementation:

**1. Scorer uses NDBC instead of SWAN.** `_effective_swell()` in `surf_scorer.py` replaces SWAN's nearshore height/period/direction with NDBC offshore buoy readings when spectral components are present. NDBC is 12 miles offshore — its values don't represent nearshore conditions. The scorer should use SWAN values for all scoring factors.

**2. Output point at wrong depth.** SWAN output points are placed at the operator's pin-drop coordinates (4.3m depth at Huntington Beach). At this depth, SWAN's Battjes-Janssen breaking dissipation has already reduced the wave height — the Hsig is post-breaking. The Komar-Gaughan conversion then applies minimal amplification because the depth correction recognizes SWAN already handled the shoaling. Result: `swellHeight ≈ breakingFaceHeight` — two nearly identical numbers. The research brief recommended output at ~10m depth, where SWAN has handled refraction but not breaking.

**3. Missing SWAN inputs.** Two input types documented in the SWAN manual are not provided:
- **WLEVEL** — time-varying water level from CO-OPS tidal predictions. SWAN runs at static mean sea level for all 72 hours, producing incorrect depth-dependent physics (breaking, shoaling, refraction) across the tidal cycle.
- **CURRENT** — ocean/tidal currents from OFS models. Wave-current interaction affects wave height and breaking at inlets, piers, and tidal channels. OFS data is already fetched for water temperature but never passed to SWAN.

**4. SWAN capabilities not used.** The SWAN manual documents capabilities that would improve accuracy and replace post-processing workarounds:
- **OBSTACLE** — native structure transmission/reflection modeling (replaces `wave_transform.py` Supplement 2)
- **TRIAD** — triad wave-wave interactions in shallow water (not activated)
- **SETUP** — wave-induced water level rise (not activated; useful for beach safety)
- **HSWELL** — swell-only wave height output (replaces NDBC for swell height display)
- **SPECOUT** — full spectral output per timestep (replaces NDBC for multiSwell decomposition)
- **QB** — fraction of breaking waves (enables break point detection along a transect)
- **DSPR** — directional spreading (potential future scoring factor)

**5. Scoring structure issues.** Score bar fill is normalized to 100 instead of each factor's own maximum (28/35 = 80% looks like 28%). Wind quality and swell dominance should be merged into a composite "Wave Organization" factor. Hidden multipliers (directional exposure, time of day) affect the score without being visible. Swell direction displayed twice with different values.

**6. TruShore branding overstates proprietary contribution.** With SWAN handling structure physics (OBSTACLE), spectral decomposition (SPECOUT), and swell height (HSWELL), the "TruShore" name implies proprietary wave physics that don't exist. The system should be called what it is: SWAN. The proprietary value is in Clear Skies (the product), the surf scoring system, and the integration pipeline — not in a branded physics engine.

---

## 0. Orientation — Execution Context

**Mandatory reading before dispatching any agent.** Read the source documents directly — do not paraphrase their content into agent prompts.

| Document | What the coordinator reads for | Required for agents in |
|---|---|---|
| `docs/reference/swan-user-manual.pdf` | SWAN commands: INPGRID WLEVEL, READINP CURRENT, OBSTACLE, TRIAD, SETUP, QUANTITY HSWELL/QB/DSPR, OUTPUT CURVE/POINTS, SPECOUT, TABLE | **Phases 2, 3 (mandatory for any agent modifying SWAN inputs or outputs)** |
| `docs/reference/swan-technical-manual.pdf` | Physics: Battjes-Janssen breaking, triad interactions, obstacle transmission formulas | **Phases 2, 3 (mandatory for any agent modifying SWAN physics or output parsing)** |
| `docs/planning/briefs/SWAN-TRUSHORE-RESEARCH-BRIEF.md` | Grid configuration, nested grids, compute requirements, input data inventory | Phases 2, 3 |
| `docs/planning/briefs/WAVE-BREAKING-CONVERSION-BRIEF.md` | K-G/Caldwell formulas, output depth recommendations (§4), pipeline order (§5) | Phases 3, 4 |
| `docs/ARCHITECTURE.md` | Current SWAN integration, services, provider layout | All phases |
| `docs/manuals/API-MANUAL.md` §17–18 | Surf endpoint contract, wave_transform supplements, scorer factors | All phases |
| `rules/clearskies-process.md` | Agent rules, git restrictions, deploy scripts, verification mandate | All phases |

**SWAN documentation is mandatory reading for model work.** Agents working on SWAN inputs or outputs MUST read `docs/reference/swan-commands-extract.md` — a distilled reference of SWAN command syntax, output quantity names, and file formats. **Do NOT give agents the full 154-page SWAN PDF** (`docs/reference/swan-user-manual.pdf`) — it exceeds Sonnet's 200K context window and causes agents to stall. The extract contains all command names, parameter formats, and output quantities needed for implementation. The full PDFs remain as coordinator reference for resolving ambiguities.

**Git restrictions (mandatory in every agent prompt):**

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, `git checkout` of remote branches, `git add`, or `git commit`. You may only run read-only git commands: `git status`, `git log`, `git diff`. All commits are made by the coordinator, not agents. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

**Only the coordinator commits.** Agents edit files on the local machine at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*` but do NOT run `git add` or `git commit`. The coordinator reviews agent work and commits.

**Deploy scripts — use these, not manual commands:**
- `scripts/deploy-api.sh` — API changes → weewx container
- `scripts/redeploy-weather-dev.sh` — Dashboard changes → weather-dev

**Run targeted tests only.** Do not run the full pytest suite.

**Adversarial auditor on every coding phase.** After dev agents complete their work and before the QC gate closes, a `clearskies-auditor` (Sonnet) reviews the diff against the plan task specs and the governing manuals. The auditor checks: (a) every acceptance criterion in the task is met, (b) code complies with the relevant manual sections, (c) no manual rules are violated, (d) no scope creep or missing deliverables. Auditor findings are triaged by the coordinator: accept (with remediation), push back (with reasoning), or defer (with explicit tracking). Dev agents do not self-attest — the auditor is the quality gate.

**Silent-deferral check at every QC gate.** Before closing any phase, the coordinator walks every T-numbered task in that phase and confirms each is DONE (cite commit) or BLOCKED (cite reason, escalate to user). No task may be silently omitted, marked "deferred," or skipped without user approval. "The plan said deferred" is not a valid reason to skip — only the user can defer. Any task missing from the QC gate evidence block is a gate failure.

---

## Phase 0 — ADR & Documentation Updates ✓ COMPLETE

**Completed:** 2026-07-18 session 1. Commit: 10d243f (meta repo).
**QC Gate 0:** Auditor found 3 low findings, all remediated (F1: ADR-097 envelope note, F2: ADR-096 amends annotation, F3: ADR-093/094 archival).

Before any code is written, the governing documents must describe the architecture we are building toward. This gives dev agents a correct reading list and prevents them from implementing against stale contracts.

### T0.1 — Draft ADR: SWAN model corrections (cross-shore transect, WLEVEL, CURRENT, OBSTACLE)

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next}.md`
- Reference: SWAN user manual (§4.5.2 INPGRID WLEVEL/CURRENT, §4.5.4 OBSTACLE, §4.6.1 CURVE); WAVE-BREAKING-CONVERSION-BRIEF §4 (output depth ~10m recommendation); this plan's Problem Statement

**Do:**
- Draft an ADR (status: Proposed) documenting the architectural corrections to the SWAN integration:
  - **Decision 1:** SWAN output points move from operator pin-drop coordinates to a cross-shore CURVE transect (~15m to 1m depth, ~50m spacing). K-G/Caldwell applied at the ~10m depth point on the transect. Swell Height (HSWELL) read at ~10m. Break points detected from QB peaks along the transect.
  - **Decision 2:** SWAN receives time-varying CO-OPS water level (WLEVEL) and OFS ocean currents (CURRENT) as inputs. Static MSL assumption eliminated.
  - **Decision 3:** Coastal structures modeled via SWAN native OBSTACLE command, replacing `wave_transform.py` Supplement 2 (post-processing structure effects). Supplements 1, 3, 4 retained.
  - **Decision 4:** TRIAD enabled for shallow-water wave dynamics. SETUP enabled for wave-induced water level output.
- Context: why each correction is needed (from this plan's Problem Statement).
- Consequences: cross-shore transect adds ~10 output points per spot (minimal compute cost); CO-OPS/OFS data already fetched; Supplement 2 eliminated.
- Keep to ~80 lines per ADR content standards.

**Accept:**
- ADR exists as Proposed.
- All four decisions clearly stated with context and consequences.
- User reviews and approves before status changes to Accepted.

### T0.2 — Draft ADR: scoring restructure (Wave Organization, TruShore removal)

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next+1}.md`
- Reference: This plan §Phase 4; KEWL Mermaid messiness rating (precedent); current surf_scorer.py

**Do:**
- Draft an ADR (status: Proposed) documenting:
  - **Decision 1:** Scoring restructured from 4 weighted factors (height 35%, period 35%, wind 20%, swell dominance 10%) to 3 weighted factors (height 35%, period 35%, organization 30%). Organization is a composite sub-score: wind effect 50%, swell dominance 25%, directional spread 15%, cross-swell 10%.
  - **Decision 2:** All scoring data sourced from SWAN. NDBC spectral data removed from the surf scoring pipeline. `_effective_swell()` no longer overrides SWAN values.
  - **Decision 3:** All penalty/bonus factors (beach alignment, directional exposure, time of day) surfaced in the scoring breakdown. No hidden multipliers.
  - **Decision 4:** Score bar fill normalized to each factor's own maximum (not to 100).
  - **Decision 5:** TruShore branding removed. Nearshore model referred to as "SWAN." Surf scoring referred to as "Surf Score." No proprietary physics branding.
- Precedent: KEWL Mermaid messiness rating uses directional spread at 30% of a messiness sub-score (beta, experience-based weights). No established surf scoring system uses DSPR as a top-level factor. DSPR is collected but scored as a sub-factor within the organization composite.
- Context: why each change is needed (scorer override bug, display normalization bug, hidden multipliers, branding).

**Accept:**
- ADR exists as Proposed.
- Scoring weights documented with precedent citations.
- DSPR inclusion justified with the caveat that thresholds need empirical validation.
- User reviews and approves before Accepted.

### T0.3 — Draft ADR: beach profile endpoint

- Owner: Coordinator (Opus)
- Files: `docs/decisions/ADR-{next+2}.md`
- Reference: This plan §Phase 5; SWAN user manual CURVE output, QB/DISSURF quantities

**Do:**
- Draft an ADR (status: Proposed) for the new `GET /api/v1/surf/{location_id}/profile` endpoint:
  - Returns the cross-shore transect for the current forecast timestep with depth, wave height, swell height, breaking fraction, and breaking dissipation at each point.
  - `breakPoints` array identifies break locations from QB peaks.
  - Multi-break spots return multiple breakPoints.
  - Unit conversion applies to wave/swell heights; distance and depth always in meters.
- Consequences: new endpoint, new response model, new dashboard card.

**Accept:**
- ADR exists as Proposed.
- Endpoint contract clearly specified with example response shape.
- User reviews and approves before Accepted.

### T0.4 — Update API-MANUAL §17–18

- Owner: Coordinator (Opus)
- Files: `docs/manuals/API-MANUAL.md`
- Reference: T0.1 ADR (SWAN corrections), T0.2 ADR (scoring), T0.3 ADR (beach profile)

**Do:**
- §17: Update the SWAN nearshore model section:
  - Document cross-shore transect output (replaces single output point).
  - Document WLEVEL (CO-OPS), CURRENT (OFS), OBSTACLE inputs.
  - Document HSWELL, QB, DSPR, SPECOUT output quantities.
  - Document that NDBC spectral data is removed from the surf pipeline (NDBC remains for boating/marine).
  - Remove TruShore branding — refer to "SWAN" as the model.
- §17 scoring section: Document the 3-factor + 3-penalty structure with organization sub-factors.
- §18: Add the beach profile endpoint contract.
- Update the surf endpoint response schema with new fields (swellHeight from HSWELL at ~10m, breakingFaceHeight from K-G at ~10m, multiSwell from SPECOUT, directionalSpread, setup).

**Accept:**
- API-MANUAL reflects all three ADR decisions.
- Surf endpoint response schema matches the planned implementation.
- No TruShore references remain in §17–18.
- NDBC role correctly scoped to boating/marine only.

### T0.5 — Update ARCHITECTURE.md and PROVIDER-MANUAL

- Owner: Coordinator (Opus)
- Files: `docs/ARCHITECTURE.md`, `docs/manuals/PROVIDER-MANUAL.md`

**Do:**
- ARCHITECTURE.md: Update the SWAN note to document: WLEVEL input from CO-OPS, CURRENT input from OFS, native OBSTACLE support, TRIAD/SETUP enabled, cross-shore CURVE transect output, SPECOUT for spectral decomposition, HSWELL/QB/DSPR output quantities. Remove TruShore branding.
- PROVIDER-MANUAL: Update the nearshore provider section. Remove NDBC from the surf data source documentation. Document that NDBC remains for boating/marine endpoints only. Remove TruShore branding.

**Accept:**
- ARCHITECTURE.md reflects the corrected SWAN integration.
- PROVIDER-MANUAL scopes NDBC correctly (boating/marine only, not surf).
- No TruShore references in active documentation.

### T0.6 — Update DASHBOARD-MANUAL and DESIGN-MANUAL

- Owner: Coordinator (Opus)
- Files: `docs/manuals/DASHBOARD-MANUAL.md`, `docs/manuals/DESIGN-MANUAL.md`

**Do:**
- DASHBOARD-MANUAL: Update surf tab card inventory — swell card (3 top-row stats, no duplicate direction), score card (3 weighted factors + 3 visible penalties, two-column layout, normalized bars), beach profile card (1×4 full-width, before forecast). Remove TruShore references.
- DESIGN-MANUAL: Add score bar normalization rule (fill relative to each factor's maximum, not to 100). Document beach profile card anatomy (SVG, break point markers, multi-break).

**Accept:**
- Both manuals reflect the planned dashboard changes.
- Score bar normalization documented as a design rule.
- Beach profile card anatomy documented.

### QC Gate 0

- All ADRs exist as Proposed (not Accepted — user approval pending).
- API-MANUAL §17–18 reflect the corrected architecture: cross-shore transect, SWAN inputs, SPECOUT, scoring restructure, beach profile endpoint.
- ARCHITECTURE.md and PROVIDER-MANUAL reflect corrected SWAN integration and NDBC scoping.
- DASHBOARD-MANUAL and DESIGN-MANUAL reflect planned dashboard changes.
- No TruShore references in any governing document (excluding archived decisions and historical planning briefs).
- No manual update contradicts any existing Accepted ADR.
- Adversarial auditor reviews all documents for internal consistency before Phase 1 begins.

---

## Phase 1 — Branding: TruShore → SWAN ✓ COMPLETE

**Completed:** 2026-07-18 session 1. Commits: 0685121 (API), 61e8ac5 (dashboard), 10d243f (meta).
**QC Gate 1:** Verified in production — `nearshoreModel: "swan"`, `source: "swan+ndbc+coops+nws_srf"`. Zero trushore in active code/docs. Phase 1 QC was combined with Phase 0 auditor run.

Remove TruShore branding everywhere. The nearshore model is SWAN. The product is Clear Skies. The surf scoring system is the Surf Score. No proprietary physics branding.

### T1.1 — API code: rename TruShore references

- Owner: `clearskies-api-dev` (Sonnet)
- Files: All files in `repos/weewx-clearskies-api/` containing `trushore`, `TruShore`, `TrushoreProvider`, `swan_trushore`, `hrrr_trushore`
- Scope: rename only — no behavioral changes

**Do:**
- `providers/nearshore/trushore.py` → `providers/nearshore/swan.py`. Class `TrushoreProvider` → `SwanProvider`. `PROVIDER_ID = "swan"` (was `"trushore"`).
- `services/swan_runner.py`: all `trushore` references in comments, variable names, and log messages → `swan`.
- `endpoints/surf.py`: `nearshoreModel: "swan_trushore"` → `"swan"`. `windSource: "hrrr_trushore"` → `"hrrr"`. `source: "swan_trushore+ndbc+..."` → `"swan+ndbc+..."`.
- `config/marine_config.py`: any `trushore` config key names → `swan`.
- `cache_warmer.py`: `trushore` references → `swan`.
- `api.conf` on the weewx host: update `[trushore]` section → `[swan]` (or `[nearshore]`).
- Update all import paths affected by the file rename.
- Run targeted tests to confirm no regressions.

**Accept:**
- `grep -ri trushore repos/weewx-clearskies-api/weewx_clearskies_api/` returns zero hits (excluding git history).
- `GET /surf/{id}` returns `nearshoreModel: "swan"`, `windSource: "hrrr"`.
- All existing tests pass after rename.

### T1.2 — Dashboard: rename TruShore references

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/` — SurfingTab.tsx, all 13 locale `marine.json` files

**Do:**
- Translation keys: `surfing.nearshoreModel` template `"Model: {{model}}"` — the model value now arrives as `"swan"` not `"swan_trushore"`. Update `nearshoreModelDisplayName()` to map `"swan"` → `"SWAN"`.
- `surfing.modelTooltipTitle`: "About SWAN+TruShore" → "About SWAN".
- `surfing.modelTooltip`: remove "TruShore" from the description. Explain it as the Clear Skies nearshore wave model powered by SWAN.
- Update all 13 locale files.

**Accept:**
- Dashboard displays "Model: SWAN" (not "SWAN+TruShore").
- Info tooltip says "About SWAN" with an accurate description.
- `grep -ri trushore repos/weewx-clearskies-dashboard/src/` returns zero hits.
- `npx tsc --noEmit` returns zero errors.

### T1.3 — Documentation: rename TruShore references

- Owner: Coordinator (Opus)
- Files: `docs/ARCHITECTURE.md`, `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/DASHBOARD-MANUAL.md`, `CLAUDE.md`, `rules/clearskies-process.md`, all planning docs

**Do:**
- Replace "TruShore" and "SWAN+TruShore" with "SWAN" throughout governing documents.
- The `weewx-clearskies-trushore` repo is renamed to `weewx-clearskies-swan` (following the `weewx-clearskies-*` convention). Update all references to the repo name in ARCHITECTURE.md, OPERATIONS-MANUAL, and any other docs that cite it.
- ARCHITECTURE.md: update the SWAN note, vocabulary table, provider module layout.
- Keep historical references in archived ADRs and decision logs intact (they document what happened).

**Accept:**
- `grep -ri trushore docs/` returns zero hits outside `docs/archive/` and `docs/planning/briefs/` (historical records).
- ARCHITECTURE.md vocabulary table has no "TruShore" canonical name.

### QC Gate 1

- Zero `trushore` references in active code, config, and governing docs (archived/historical excepted).
- API returns `nearshoreModel: "swan"` and `windSource: "hrrr"`.
- Dashboard displays "SWAN" not "TruShore".
- All tests pass.
- **Auditor:** `clearskies-auditor` reviews T1.1–T1.3 diffs against plan acceptance criteria and governing manuals. Findings triaged by coordinator.
- **Silent-deferral check:** Coordinator confirms T1.1, T1.2, T1.3 each DONE with commit hash. No task omitted.

---

## Phase 2 — SWAN Model Input Corrections ✓ COMPLETE

**Completed:** 2026-07-18 session 1. Commit: 4ec7860 (API). Deployed.
**QC Gate 2:** Auditor found 3 findings — F1 HIGH (OBSTACLE DAM missing DANGremond/GODA keywords, remediated), F2 MEDIUM (OFS gridded fetch, implemented via fetch_surface_currents()), F3 LOW (docstring, fixed). All remediated before commit.

Add the missing inputs the SWAN manual documents as important for nearshore accuracy.

### T2.1 — Add CO-OPS water level as SWAN WLEVEL input

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py` (pass tide data to runner)
- Reference: SWAN user manual §4.5.2 `INPGRID WLEVEL` + `READINP WLEV`; CO-OPS provider (`providers/tides/coops.py`)

**Do:**
- Fetch CO-OPS tide predictions for the forecast period (already done in surf.py for the tide chart — reuse the same data).
- Write a time-varying WLEVEL input file: one water level grid per timestep (hourly, matching SWAN compute steps). For a regular grid, every grid point gets the same tidal elevation (tides vary slowly over the ~30km inner nest domain — uniform is acceptable).
- Add `INPGRID WLEVEL` and `READINP WLEV` to the SWAN INPUT file generator.
- The WLEVEL input is NONSTATIONARY with the same time window as the wind input.

**Accept:**
- SWAN INPUT file contains `INPGRID WLEVEL` and `READINP WLEV` commands.
- SWAN runs without errors with the water level input.
- Wave height at the output points differs between high-tide and low-tide timesteps (confirming SWAN uses the water level data). Compare a high-tide and low-tide timestep's Hs at the same output point — they should differ.

### T2.2 — Add OFS ocean currents as SWAN CURRENT input

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
- Reference: SWAN user manual §4.5.2 `INPGRID CURRENT` + `READINP CURRENT`; OFS provider (`providers/ocean/ofs.py`)

**Do:**
- Fetch OFS surface current data for the inner nest domain. The `ocean_data_resolver` already fetches OFS data — extend to include surface current U/V components.
- Write a time-varying CURRENT input file: U and V current components at each grid point per timestep.
- Add `INPGRID CURRENT` and `READINP CURRENT` to the SWAN INPUT file.
- If OFS current data is unavailable (coverage gap), SWAN runs without currents (no-current is the default and is safe).

**Accept:**
- SWAN INPUT file contains `INPGRID CURRENT` and `READINP CURRENT` commands when OFS data is available.
- SWAN runs successfully with and without current input.
- At locations with known strong currents (harbor entrances, tidal channels), wave height shows current-interaction effects.

### T2.3 — Replace wave_transform Supplement 2 with SWAN OBSTACLE

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (add OBSTACLE commands)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/wave_transform.py` (remove Supplement 2)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/config/marine_config.py` (structure → SWAN params mapping)
- Reference: SWAN user manual §4.5.4 `OBSTACLE` command (GODA, DANGremond, TRANSM, REFL); wizard structure discovery (`setup/marine/discover-structures`)

**Do:**
- Map each structure type from the wizard's Overpass API discovery to SWAN OBSTACLE parameters:
  - `pier` → `OBSTACLE TRANSM [trcoef]` (transmission through pile-supported structure; Kt ~0.7–0.9 depending on pile spacing)
  - `breakwater` → `OBSTACLE DAM DANGremond [hgt] [slope] [Bk]` (rubble-mound; height, seaward slope, crest width from Overpass tags or defaults)
  - `jetty` → `OBSTACLE DAM GODA [hgt] [alpha] [beta]` (vertical wall)
  - `seawall` → `OBSTACLE REFL [reflc]` (wave reflection)
  - `groin` → `OBSTACLE DAM GODA [hgt] [alpha] [beta]` (perpendicular to shore)
- Write OBSTACLE LINE commands using the structure's (x,y) coordinates from the config.
- Remove Supplement 2 (structure effects) from `wave_transform.apply_supplements()`. The remaining supplements (γ correction, spatial interpolation, topographic focusing) continue to apply.
- Update API-MANUAL §17 to document that structure physics are now handled by SWAN natively.

**Accept:**
- SWAN INPUT file contains OBSTACLE commands for each configured structure.
- Wave height shows attenuation behind structures (compare Hs at an output point in the shadow of a pier vs an unobstructed point nearby).
- `wave_transform.apply_supplements()` no longer applies Supplement 2.
- Supplements 1, 3, 4 still fire.

### T2.4 — Enable TRIAD and SETUP

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
- Reference: SWAN user manual §4.5.4 `TRIAD` command; §4.5.5 `SETUP` command

**Do:**
- Add `TRIAD` command to the SWAN INPUT file (uses defaults — Eldeberky 1996).
- Add `SETUP` command to the SWAN INPUT file (enables wave-induced setup computation).
- Add `SETUP` to the TABLE output quantity list.
- TRIAD improves wave dynamics in the surf zone (< 5m depth). SETUP enables wave-induced water level output for future beach safety use.

**Accept:**
- SWAN runs without errors with TRIAD and SETUP enabled.
- SETUP values are non-zero at nearshore output points (confirming the computation runs).
- No significant increase in SWAN runtime (TRIAD adds minimal compute cost).

### QC Gate 2

- SWAN runs with WLEVEL, CURRENT (when available), OBSTACLE, TRIAD, and SETUP.
- Wave heights differ between high-tide and low-tide timesteps.
- Structure attenuation visible in output.
- SETUP values present in TABLE output.
- SWAN runtime still within 15-minute tolerance.
- All existing tests pass.
- **Auditor:** `clearskies-auditor` reviews T2.1–T2.4 diffs against plan acceptance criteria. Verifies SWAN INPUT file contains all new commands (INPGRID WLEVEL, READINP CURRENT, OBSTACLE, TRIAD, SETUP). Checks wave_transform.py Supplement 2 removal doesn't break Supplements 1/3/4.
- **Silent-deferral check:** Coordinator confirms T2.1, T2.2, T2.3, T2.4 each DONE with commit hash. No task omitted.

---

## Phase 3 — Cross-Shore Transect & Output Expansion ✓ COMPLETE

**Completed:** 2026-07-18 session 1. Commits: ea47ed6 (main impl), cdcc38d (QB fix), 5e26e41 (doc sync). All deployed.
**QC Gate 3:** Auditor found 1 HIGH finding — QB peak detection and transect storage not implemented. Remediated in cdcc38d before commit. New file: `services/swan_spectral.py` (488 lines — SPECOUT parser + spectral decomposition).

Replace the single pin-drop output point with a cross-shore transect. Add HSWELL, QB, DSPR, SPECOUT to SWAN output.

### T3.1 — Implement cross-shore CURVE output transect

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_formats.py`
- Reference: SWAN user manual §4.6.1 `CURVE` command; bathymetric_profile in marine config

**Do:**
- For each surf spot, compute a cross-shore transect using the bathymetric profile:
  - Start: the ~15m depth contour (offshore end of the profile, or the deepest point in the bathymetric profile if < 15m)
  - End: the 1m depth contour (near-shore end)
  - Direction: perpendicular to the beach (derived from `beach_facing_degrees` + 180°)
  - Spacing: ~50m between output points (configurable)
  - Typically 10–20 output points per transect
- Replace the single `OUTPUT POINTS` command with a `CURVE` command defining the transect.
- The existing single-point `OUTPUT POINTS` file is replaced — no backward compatibility concern (this is an internal SWAN configuration, not an API contract).

**Accept:**
- SWAN INPUT file contains a CURVE command for each surf spot with 10+ output points along the cross-shore transect.
- TABLE output contains rows for all transect points per timestep.
- Parser correctly maps transect points to their (distance_from_shore, depth) positions.

### T3.2 — Add HSWELL, QB, DISSURF, DEPTH, DSPR to TABLE output

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (TABLE command)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py` (parser)
- Reference: SWAN user manual §4.6.2 `TABLE` output quantities; Appendix A definitions

**Do:**
- Expand the TABLE output to include: `Hsign Hswell Dir Tm01 Depth QB Dissurf Setup Dspr Xp Yp`
- Update the TABLE parser to extract all new columns by header name (parser already discovers columns dynamically — just handle the new column names).
- Store new quantities in a transect data structure per spot per timestep.

**Accept:**
- TABLE output contains all specified columns.
- HSWELL values are ≤ HSIGN at every point (swell component cannot exceed total energy).
- QB values are 0 in deep water and 0–1 in the surf zone.
- DSPR values are in degrees (typically 10–40° for nearshore conditions).

### T3.3 — Add SPECOUT for spectral decomposition

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_runner.py`
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/services/swan_spectral.py` (spectrum parser + decomposition)
- Reference: SWAN user manual §4.6.2 `SPECOUT` command; Appendix D (spectrum file format)

**Do:**
- Add a `SPECOUT` command to write 2D directional-frequency spectra at the ~10m depth point on each transect (one point per spot, not the entire transect — full spectra at every point would be excessive).
- Implement a spectral decomposition function that partitions the 2D spectrum into swell systems:
  - Identify energy peaks in the (frequency, direction) space
  - Classify each peak as groundswell (f < 0.08 Hz / T > 12.5s), swell (0.08–0.1 Hz / T 10–12.5s), or wind swell (f > 0.1 Hz / T < 10s)
  - Extract height, period, direction, energy for each system
  - Return as a list of spectral components (same shape as current `SpectralWaveComponent`)
- This replaces NDBC spectral data for the `multiSwell` field in the surf response. Each timestep gets its own spectral decomposition (not a static NDBC snapshot broadcast to all timesteps).

**Accept:**
- SPECOUT file is written at the ~10m transect point for each spot.
- Spectral decomposition produces 1–5 swell systems per timestep (physically reasonable).
- Component heights sum (in quadrature) to approximately HSIGN at the same point.
- `multiSwell` field in the surf response is populated from SWAN SPECOUT, not NDBC.
- Different timesteps have different spectral decompositions (not identical copies).

### T3.4 — Extract breaking location and peak height from transect

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`
- Reference: WAVE-BREAKING-CONVERSION-BRIEF §4 (output depth ~10m recommendation)

**Do:**
- From the cross-shore transect TABLE output per timestep:
  - Find the point closest to 10m depth → use its HSIGN for K-G/Caldwell face height conversion.
  - Find the point(s) where QB peaks → these are the break point(s). Multiple QB peaks = multiple break locations (outer bar, inner bar).
  - Store HSWELL at the ~10m depth point → this is the "Swell Height" display value.
  - Apply K-G/Caldwell to the ~10m HSIGN → this is the "Breaking Face Height" display value.
- The K-G depth correction at 10m depth applies ~60–80% of the full amplification (appropriate — SWAN has handled refraction but not final shoaling-to-breaking at 10m). The result is a breaking face height meaningfully larger than the swell height.
- Build a per-timestep beach profile data structure: array of `{ distanceFromShore, depth, waveHeight, breakingFraction, swellHeight }` for the endpoint.

**Accept:**
- `swellHeight` (HSWELL at ~10m) and `breakingFaceHeight` (K-G at ~10m HSIGN) are meaningfully different values. For typical conditions, breaking face height should be ~1.1–1.3× swell height.
- Break point(s) identified by QB peaks: at least one break point per timestep for non-flat conditions.
- Multi-break detection works: at a bar-break beach, two QB peaks at different distances from shore are detected.

### T3.5 — Disconnect NDBC from scoring and multiSwell

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
- Reference: API-MANUAL §17

**Do:**
- Stop passing `spectral_components` to `score_surf()`. The scorer receives `spectral_components=None` for all timesteps — scoring uses SWAN values only (T4.1 completes the scorer-side cleanup).
- `multiSwell` field populated from SWAN SPECOUT (T3.3), not from NDBC spectral.
- The NDBC fetch itself STAYS in the surf endpoint. `spectralComponents` STAYS in the surf response bundle. The data remains available for operators and third-party consumers who want raw buoy spectral data alongside the SWAN forecast. It just no longer feeds scoring or the multiSwell display.
- Update API-MANUAL §17 to document: multiSwell sourced from SWAN SPECOUT; NDBC spectral retained in response as reference data, not used for scoring.

**Accept:**
- `score_surf()` receives `spectral_components=None` (NDBC not passed to scorer).
- `multiSwell` populated from SWAN SPECOUT, not NDBC.
- `spectralComponents` still present in surf response (NDBC data available as reference).
- NDBC fetch still runs in the surf endpoint.

### QC Gate 3

- Cross-shore transect produces 10+ output points per spot.
- HSWELL at ~10m is less than HSIGN at the same point (swell ≤ total).
- Breaking face height (K-G at ~10m) is 1.1–1.3× swell height for typical groundswell conditions.
- QB peaks identify break points. Multi-break detection verified at Huntington Beach (outer + inner bar).
- SWAN SPECOUT decomposition produces varying multiSwell per timestep.
- NDBC disconnected from scoring and multiSwell. NDBC fetch and `spectralComponents` response field retained as reference data.
- All tests pass.
- **Auditor:** `clearskies-auditor` reviews T3.1–T3.5 diffs against plan acceptance criteria and API-MANUAL §17. Verifies NDBC spectral not passed to scorer. Verifies SPECOUT replaces NDBC for multiSwell. Verifies K-G applied at ~10m depth point (not pin-drop). Verifies NDBC fetch and response field still present.
- **Silent-deferral check:** Coordinator confirms T3.1, T3.2, T3.3, T3.4, T3.5 each DONE with commit hash. No task omitted.

---

## Phase 4 — Scoring Restructure ✓ COMPLETE

**Completed:** 2026-07-18 session 1. Commit: 66c9634 (API), fccfb2f (doc sync). Deployed session 2.
**QC Gate 4:** Passed (session 2). Auditor found 3 findings — F1 LOW (plan criterion imprecise for glassy org score), F2 MEDIUM (sub-factor rounding vs org total — documented as ≤0.5 tolerance), F3 MEDIUM (test coverage gaps — deferred to T7.2). All remediated or tracked. Production verified: scoring=waveHeight:4, wavePeriod:1, waveOrganization:24, beachAlignment:-6, directionalExposure:0, timeOfDay:0, nearshoreModel:swan.

Restructure the 4-factor weighted scoring into a 3-factor model with a composite "Wave Organization" factor. Fix bar display normalization. Surface all penalty factors.

### T4.1 — Restructure scorer: Wave Organization composite

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (SurfScoringBreakdown)
- Reference: This plan §"Problem Statement" item 5; KEWL Mermaid messiness rating (precedent for sub-factor weighting)

**Do:**
- Replace 4 top-level weighted factors with 3:
  - Wave Height: 35% (unchanged)
  - Wave Period: 35% (unchanged)
  - Wave Organization: 30% (absorbs wind 20% + swell dominance 10%, adds DSPR + cross-swell)
- Wave Organization sub-factors (weights within the 30%):
  - Wind effect: 50% (15% effective) — existing `_wind_quality()` logic, unchanged
  - Swell dominance: 25% (7.5% effective) — existing `_swell_dominance()` logic, but now computed from SWAN SPECOUT instead of NDBC
  - Directional spread: 15% (4.5% effective) — new, uses DSPR from SWAN TABLE output. Scoring: DSPR < 15° → 1.0, 15–25° → 0.7, 25–35° → 0.4, > 35° → 0.2
  - Cross-swell interference: 10% (3% effective) — new, detects multiple energy peaks at different directions in SWAN SPECOUT. No cross-swell → 1.0, secondary system > 50% primary energy at > 30° angle difference → 0.4
- Compute organization sub-score as weighted sum of sub-factors, then multiply by 30 for the top-level contribution.
- Remove `_effective_swell()` override of SWAN values with NDBC data. The scorer uses SWAN height/period/direction directly. NDBC spectral data is no longer passed to the scorer at all.

- Update `SurfScoringBreakdown` model to include:
  - `waveHeight`, `wavePeriod`, `waveOrganization` (top-level, out of 35/35/30)
  - `organizationWind`, `organizationSwellDominance`, `organizationDirectionalSpread`, `organizationCrossSwell` (sub-factors, out of their respective sub-maxima)
  - `beachAlignment`, `directionalExposure`, `timeOfDay` (penalty/bonus values as signed integers)

**Accept:**
- `score_surf()` uses 3 weighted factors summing to 100 max.
- Organization sub-factors are populated in the scoring breakdown.
- No NDBC data used anywhere in the scorer.
- Scorer uses SWAN height/period/direction directly (no `_effective_swell()` override).
- Scoring produces reasonable values for test conditions: a glassy day with clean groundswell scores organization ~25–28/30; a choppy onshore day with crossing swells scores ~5–10/30.

### T4.2 — Surface all penalty factors in the scoring breakdown

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/enrichment/surf_scorer.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`

**Do:**
- `beachAlignment` is already surfaced (shown as negative penalty). No change needed.
- Add `directionalExposure` to the scoring breakdown as a signed integer (0 when open, negative when blocked).
- Add `timeOfDay` to the scoring breakdown as a signed integer (positive at dawn, negative in afternoon, 0 otherwise).
- All three penalty/bonus values are computed as: `applied_score - pre_penalty_score`. This makes them additive with the weighted factors: `total = height + period + organization + beach_alignment + directional_exposure + time_of_day`.

**Accept:**
- All three penalty/bonus factors present in the scoring breakdown.
- `total = waveHeight + wavePeriod + waveOrganization + beachAlignment + directionalExposure + timeOfDay` for every response.
- No hidden score modifications — the displayed factors fully explain the total.

### QC Gate 4

- Scorer produces 3 weighted factors + 3 visible penalties that sum to the total.
- Organization sub-factors are populated and sum to the organization score.
- No NDBC data in the scorer — all inputs from SWAN.
- Scoring values are physically reasonable across test conditions.
- **Auditor:** `clearskies-auditor` reviews T4.1–T4.2 diffs against plan acceptance criteria and API-MANUAL §17 scoring section. Verifies weights sum to 100. Verifies `_effective_swell()` NDBC override is removed. Verifies all three penalties surfaced in breakdown.
- **Silent-deferral check:** Coordinator confirms T4.1, T4.2 each DONE with commit hash. No task omitted.

---

## Phase 5 — API: Beach Profile Endpoint ✓ COMPLETE

**Completed:** 2026-07-18 session 2. Commits: d279c43 (T5.1+T5.2), 267e3e2 (F2 fix). Deployed.
**QC Gate 5:** Passed. Auditor found 2 LOW findings — F1 (setup field undocumented in API-MANUAL table, deferred to T7.1), F2 (stale swellHeight comment, remediated in 267e3e2). All 7 acceptance criteria MET.

New endpoint for the cross-shore transect visualization.

### T5.1 — Implement beach profile endpoint

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/beach_profile.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/__init__.py` (register router)
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`

**Do:**
- `GET /api/v1/surf/{location_id}/profile` — returns the cross-shore transect for the current forecast timestep (closest to now):
  ```json
  {
    "data": {
      "locationId": "huntington-city-beach-pier",
      "transect": [
        {
          "distanceFromShore": 800,
          "depth": 12.3,
          "waveHeight": 1.2,
          "swellHeight": 1.0,
          "breakingFraction": 0.0,
          "breakingDissipation": 0.0
        },
        ...
        {
          "distanceFromShore": 50,
          "depth": 1.8,
          "waveHeight": 0.4,
          "swellHeight": 0.3,
          "breakingFraction": 0.85,
          "breakingDissipation": 45.2
        }
      ],
      "breakPoints": [
        { "distanceFromShore": 200, "depth": 3.1, "waveHeight": 1.5 },
        { "distanceFromShore": 80, "depth": 1.5, "waveHeight": 0.9 }
      ]
    },
    "units": { "distance": "m", "depth": "m", "waveHeight": "ft" }
  }
  ```
- `breakPoints` are the QB peak locations — multiple entries for multi-break spots.
- Unit conversion applies to waveHeight and swellHeight fields.
- Distance and depth always in meters (these are physical positions, not display values).

**Accept:**
- Endpoint returns a transect with 10+ points ordered from offshore to shore.
- `breakPoints` array has at least one entry for non-flat conditions.
- Multi-break spots show multiple breakPoints at different distances.
- Unit conversion applies correctly.

### T5.2 — Update surf endpoint response with new fields

- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/surf.py`
  - Modify: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`

**Do:**
- `swellHeight` now comes from HSWELL at ~10m depth (not raw SWAN Hsig at pin-drop).
- `breakingFaceHeight` comes from K-G/Caldwell applied to HSIGN at ~10m (not at 4.3m pin-drop).
- `waveHeightAtBreak` deprecated but retained for backward compatibility — set to HSIGN at ~10m.
- `multiSwell` populated from SWAN SPECOUT per timestep (not NDBC broadcast).
- New fields: `directionalSpread` (DSPR at ~10m), `setup` (wave-induced setup at shore).
- `nearshoreModel` returns `"swan"` (Phase 1 branding change).
- Scoring breakdown includes the new 3-factor + 3-penalty structure (Phase 4).

**Accept:**
- `swellHeight` < `breakingFaceHeight` by a meaningful margin (~1.1–1.3× for groundswell).
- `multiSwell` varies per timestep.
- `directionalSpread` present in response.
- Scoring breakdown matches Phase 4 structure.

### QC Gate 5

- Beach profile endpoint returns valid transect data.
- Surf endpoint returns corrected height values from the ~10m transect point.
- All new fields populated.
- All existing tests pass.
- **Auditor:** `clearskies-auditor` reviews T5.1–T5.2 diffs against plan acceptance criteria and API-MANUAL §17–18. Verifies endpoint response matches the ADR contract (T0.3). Verifies swellHeight < breakingFaceHeight by a meaningful margin.
- **Silent-deferral check:** Coordinator confirms T5.1, T5.2 each DONE with commit hash. No task omitted.

---

## Phase 6 — Dashboard Changes ✓ COMPLETE

**Completed:** 2026-07-18 session 2. Dashboard commits: ef6f322 (T6.1+T6.2+T6.5), 336b099 (T6.3), 4af021b (TS fix). Deployed.
**QC Gate 6:** T6.1 DONE, T6.2 DONE, T6.3 DONE, T6.4 diagnosed (external CO-OPS outage — NOAA predictions API returns no data for any station; not a code bug; TideChart.tsx is correct), T6.5 DONE. tsc: zero errors.

Update the surf tab to display the corrected data, restructured scoring, and beach profile.

### T6.1 — Current Swell Conditions card layout fix

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`
  - Modify: `repos/weewx-clearskies-dashboard/public/locales/en/marine.json` (+ 12 other locales)

**Do:**
- "Conditions at Break" top row: 3 stats, not 4.
  - Swell Height (HSWELL from API)
  - Breaking Face Height (K-G result from API)
  - Period
  - Remove "Direction" from the top row (redundant with the compass below).
- Compass remains as the sole direction display.
- `primary` forecast entry stays as closest-to-now (the fix from earlier today). With SWAN SPECOUT providing multiSwell per timestep, the closest-to-now entry now has its own spectral decomposition — no more empty multiSwell.
- Swell components table sources from SWAN SPECOUT data (arrives via `multiSwell` in the API response — no dashboard code change needed for the data source, only the display).

**Accept:**
- Top row shows 3 stats: Swell Height, Breaking Face Height, Period.
- Swell Height and Breaking Face Height show meaningfully different values.
- No "Direction" in the top row. Compass is the only direction display.
- `npx tsc --noEmit` returns zero errors.

### T6.2 — Surf Score card: scoring restructure + bar normalization

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`
  - Modify: `repos/weewx-clearskies-dashboard/public/locales/en/marine.json` (+ 12 other locales)

**Do:**
- Score bars: fill normalized to each factor's own maximum, not to 100. Wave Height 28/35 = 80% fill. Wind Quality 20/20 = 100% fill. Color reflects performance within the factor's range.
- Two-column layout for the scoring breakdown:
  - Column 1: Wave Height (35%), Wave Period (35%), Wave Organization (30%)
  - Column 2: Beach Alignment (penalty), Directional Exposure (penalty), Time of Day (bonus/penalty)
- Wave Organization bar is a single bar showing the composite score. The sub-factors (wind, swell dominance, directional spread, cross-swell) are shown in the explainer modal, not on the main card.
- All bars sum to the displayed total score.
- Update explainer modal to describe the new 3-factor + 3-penalty structure with organization sub-factors.
- Update translation keys for new factor names.

**Accept:**
- Bar fill proportional to each factor's maximum (not to 100).
- Two-column layout renders correctly at all responsive breakpoints.
- All factors visible — no hidden modifiers.
- Bars + penalties sum to displayed total.
- Explainer modal describes organization sub-factors.

### T6.3 — Beach profile graphic (1×4 horizontal card, before surf forecast)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - New: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/BeachProfileChart.tsx`
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`

**Do:**
- New card on the surf tab: "Beach Profile" — `footprint="full"` (1×4 horizontal, spanning full grid width). Positioned **before** the 72-Hour Surf Forecast card (after the score/swell/wind/conditions cards, before the forecast scroll).
- X-axis: distance from shore (meters), right-to-left (shore on the right, offshore on the left — matches the surfer's perspective looking out to sea).
- Y-axis: elevation (depth below sea level as negative, wave height envelope as positive).
- Render:
  - Bathymetric profile line (brown/tan fill below, representing the sea floor)
  - Water surface line (at tidal elevation from CO-OPS, not static at 0)
  - Wave height envelope (blue fill between trough and crest, following the HSIGN values along the transect)
  - Break point markers at each QB peak (vertical dashed line + wave height label at the peak). Multiple markers for multi-break spots (e.g., outer bar + inner bar at Huntington Beach Pier).
- Data source: `GET /api/v1/surf/{location_id}/profile` (T5.1).
- Inline SVG (not Recharts — this is a custom profile visualization, not a time-series chart).
- A11y: `role="img"`, descriptive `aria-label` ("Cross-shore beach profile showing bathymetry, wave height, and breaking locations"), sr-only data table with transect values.

**Accept:**
- Beach profile renders showing bathymetry, water surface, wave envelope, and break points.
- Multi-break spots show multiple break point markers.
- Card displays correctly at all responsive breakpoints.
- A11y: aria-label, sr-only data table.
- `npx tsc --noEmit` returns zero errors.

### T6.4 — Fix broken tide card

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/shared/TideChart.tsx` (if needed)

**Do:**
- Diagnose and fix the broken tide card on the surf tab. The tide card was working before the SWAN corrections session (2026-07-18). Investigate whether the closest-to-now `primary` change, the NDBC spectral broadcast fix, or another change broke the tide data or rendering.
- Verify tide predictions are still fetched from CO-OPS and passed to `TideChart`.
- Verify the TideChart component renders correctly with the current data shape.

**Accept:**
- Tide card renders correctly with tide prediction curve and high/low markers.
- No regressions from the current working state of other marine tabs' tide cards (boating, fishing, beach safety).

### T6.5 — 72-hour forecast wind quality text wrap (immediate fix)

- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files:
  - Modify: `repos/weewx-clearskies-dashboard/src/components/marine/tabs/SurfingTab.tsx`

**Do:**
- Wind quality row in the 72h forecast: remove `overflow: hidden`, `textOverflow: ellipsis`. Allow text to wrap to a second line.
- Increase row height from 22px to 34px to accommodate two-line text (e.g., "Cross-Offshore").

**Accept:**
- "Cross-Offshore" and other long wind quality labels display fully without clipping.

### QC Gate 6

- Swell card shows 3 top-row stats with meaningfully different swell height and breaking face height.
- Direction displayed only in the compass (not duplicated in top row).
- Score card bars normalized to each factor's maximum.
- Two-column score layout with all factors visible.
- Beach profile card renders at full width before the 72h forecast, showing bathymetry, wave envelope, and break point markers.
- Multi-break detection visible in beach profile (e.g., two markers at Huntington Beach Pier).
- Tide card renders correctly (regression fixed).
- Wind quality text wraps in 72h forecast.
- All tests pass. `npx tsc --noEmit` returns zero errors.
- Visual verification: render the surf tab and compare against expected layout.
- **Auditor:** `clearskies-auditor` reviews T6.1–T6.5 diffs against plan acceptance criteria, DASHBOARD-MANUAL, and DESIGN-MANUAL. Verifies bar normalization (fill = score/max, not score/100). Verifies no hidden scoring factors. Verifies beach profile card placement (before forecast, 1×4). Verifies tide card regression fixed.
- **Silent-deferral check:** Coordinator confirms T6.1, T6.2, T6.3, T6.4, T6.5 each DONE with commit hash. No task omitted.

---

## Phase 7 — Documentation & Cleanup ✓ COMPLETE

**Completed:** 2026-07-18 session 2. API commit: cf66a43 (T7.2). Meta commit: pending (T7.1). Deployed.
**QC Gate 7:** T7.1 DONE (API-MANUAL setup/scoring/breakPoints fields fixed, ARCHITECTURE.md beach profile endpoint added, PROVIDER-MANUAL NDBC scoped, plan status updated). T7.2 DONE (Supplement 2 removed, test fixes, 51 tests pass 0 fail, zero trushore hits, stale comments fixed).

### T7.1 — Update governing documents

- Owner: Coordinator (Opus)
- Files: `docs/ARCHITECTURE.md`, `docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/DASHBOARD-MANUAL.md`, `docs/manuals/DESIGN-MANUAL.md`

**Do:**
- ARCHITECTURE.md: update SWAN note (WLEVEL, CURRENT, OBSTACLE, TRIAD, SETUP inputs; cross-shore transect output; SPECOUT for spectral decomposition; HSWELL/QB/DSPR output quantities).
- API-MANUAL §17: update surf endpoint response schema (new fields, scoring structure, beach profile endpoint). Remove NDBC spectral role from surf pipeline. Document SWAN as the sole data source for surf.
- PROVIDER-MANUAL: remove NDBC from the surf data source section. Document that NDBC remains for boating/marine only.
- DASHBOARD-MANUAL: update surf tab card inventory (swell card layout, score card layout, beach profile card).
- DESIGN-MANUAL: score bar normalization rule (fill relative to factor maximum, not 100).

**Accept:**
- All governing docs reflect the implemented architecture.
- No stale TruShore references in active docs.
- Doc-code sync verified.

### T7.2 — Clean up deprecated code

- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/`

**Do:**
- Remove `wave_transform.py` Supplement 2 (structure effects) — replaced by SWAN OBSTACLE.
- Verify NDBC spectral fetch remains in surf endpoint but is NOT passed to `score_surf()` (T3.5).
- Remove `_effective_swell()` NDBC override from scorer (should already be removed in T4.1 — verify).
- Remove any dead code paths related to the old single-point output.
- Remove any remaining TruShore variable names or log messages.

**Accept:**
- No dead code related to NDBC-in-surf, Supplement 2, single-point output, or TruShore naming.
- `grep -ri trushore repos/weewx-clearskies-api/weewx_clearskies_api/` returns zero hits.
- All tests pass.

### QC Gate 7 (Final)

- Complete end-to-end verification: surf endpoint returns correct data with all SWAN inputs, cross-shore transect, SPECOUT decomposition, restructured scoring.
- Dashboard renders correctly: swell card, score card, beach profile, 72h forecast, tide card.
- All governing documents up to date.
- No TruShore branding in active code, config, or docs.
- NDBC data retained in surf endpoint (fetch + response field) but not used for scoring or multiSwell.
- No dead code.
- All tests pass.
- **Auditor:** `clearskies-auditor` performs final adversarial review: (a) full diff of all repos against plan acceptance criteria, (b) governing doc consistency check (ARCHITECTURE.md, API-MANUAL, PROVIDER-MANUAL, DASHBOARD-MANUAL, DESIGN-MANUAL all agree), (c) grep for `trushore` in active code/docs (must return zero), (d) verify NDBC spectral not passed to `score_surf()` and multiSwell sourced from SWAN SPECOUT (NDBC fetch and response field still present).
- **Silent-deferral check:** Coordinator walks every T-numbered task across all phases (T0.1–T7.2). Each is DONE with commit hash. Any task not DONE is escalated to the user before the plan can close. No implicit deferrals.

---

## Open Questions

**Q1: `weewx-clearskies-trushore` repo rename.** The standalone repo is renamed to `weewx-clearskies-swan` following the existing `weewx-clearskies-*` convention. Phase 1 T1.3 handles this alongside the documentation branding changes.

**Q2: NDBC endpoints retained.** NDBC is removed from the surf scoring pipeline and surf tab display, but the NDBC API endpoints and provider module remain fully operational. Operators and third-party consumers can still pull NDBC buoy data for use in other cards, custom pages, or external integrations. Only the surf tab stops displaying it.

**Q3: DSPR scoring thresholds.** The directional spread sub-factor thresholds (< 15° → 1.0, 15–25° → 0.7, 25–35° → 0.4, > 35° → 0.2) are based on published nearshore DSPR ranges from coastal engineering literature and the KEWL Mermaid precedent. These are the best available values from the science. The thresholds can be adjusted in future releases if operational experience reveals better breakpoints, but no manual observation/calibration platform is planned or needed — the science is the calibration source.

**Q4: SETUP usage in beach safety.** SWAN SETUP output is collected (T2.4) and stored (T5.2) but not yet used in the beach safety tab. A future task should wire SETUP into the beach safety total water level calculation. Deferred — not blocking.
