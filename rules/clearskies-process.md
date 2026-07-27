# clearskies-process.md — Clear Skies project process rules

Load when working on Clear Skies (`weewx-clearskies-*` repos, planning docs, ADRs, contracts).
Incident history and rationale at [reference/process-rule-history.md](../reference/process-rule-history.md).

---

## Architecture document discipline

**Read `docs/ARCHITECTURE.md` before any architecture work.** Before proposing, discussing, or implementing any infrastructure change, deployment fix, proxy configuration, service placement, container change, endpoint change, or config-file change: read `docs/ARCHITECTURE.md` first. This is the single source of truth for what each service is, where it runs, what it exposes, and how traffic flows. Do not re-derive the architecture from ADRs, observation, or memory.

**Update `docs/ARCHITECTURE.md` after any architecture change.** Every change to services, containers, endpoints, routing, config files, or topology must be reflected in the architecture document before the task is considered complete. If the change reveals a gap between intended and current state, update the "Known gaps" section.

**Why (2026-05-23):** Without this document, the lead spent an entire session re-deriving architecture that was already decided in ADRs — going in circles proposing the wizard as a standalone Flask app, then suggesting it be split across containers, then suggesting it be rebuilt in React in the dashboard, then suggesting it be bundled into the API container. All four proposals contradicted existing ADRs. The root cause: 40 ADRs cannot serve as a quick-reference for "how does the system work right now." A single architecture document eliminates the re-derivation loop.

## ADR discipline

**Write decisions to disk immediately.** Decision discussed → ADR drafted as `Proposed` → user reviews full content → user explicitly approves → status becomes `Accepted`. Never create ADRs as Accepted. "It was in the plan" is not sign-off. Directional chat ("yes use the prefix") is input to a Proposed ADR, not approval.

**Corrections edit in place.** Status flips back to Proposed until user re-approves. Don't create a new "supersedes" ADR for ordinary corrections — only for fundamentally distinct decisions.

**Read the ADR before the plan.** Plan body summaries drift. ADR wins on conflict — fix the plan to match.

**Read the ADRs before touching architecture.** Before proposing any infrastructure change, deployment fix, proxy configuration, service placement, or config-file change: read `docs/ARCHITECTURE.md` first (see above), then the relevant ADRs if deeper decision context is needed (especially ADR-034 deployment topology, ADR-027 config wizard, ADR-038 wizard-to-API channel). Do NOT guess the architecture from observation alone — the live state may be broken or interim. The ADRs define what the system SHOULD look like; divergence means a bug to fix, not a new architecture to invent. Session context or resume prompts may be stale or wrong; ADRs are authoritative.

**Why (2026-05-22):** Phase 5 session wasted significant time patching a wrong architecture: running the API on weather-dev (not the weewx host), adding Apache ProxyPass rules between the dashboard and API, manually writing `api.conf` on the wrong host, and proposing the wizard write `api.conf` locally. All of these contradicted ADR-034 (API co-locates with weewx), ADR-038 (API writes its own config via `/setup/apply`), and ADR-027 (wizard auto-detects topology). None of the ADRs were read until the user intervened. The ADRs had all the answers; the session burned tokens and user patience reinventing them badly.

**Recover lost state immediately.** If the user references a decision you can't find in files: STOP. Tell them. Ask for context. Write it down before the next item.

**All ADRs follow the manual consolidation lifecycle.** After acceptance, prescriptive rules are extracted into the target manual, then the ADR is archived:
1. Decision needed → draft ADR as Proposed
2. User approves → ADR becomes Accepted
3. Rules extracted into the target manual:
   - API rules → `docs/manuals/API-MANUAL.md`
   - Provider rules → `docs/manuals/PROVIDER-MANUAL.md`
   - Ops/security/config rules → `docs/manuals/OPERATIONS-MANUAL.md`
   - Dashboard technical rules → `docs/manuals/DASHBOARD-MANUAL.md`
   - UI design rules → `docs/manuals/DESIGN-MANUAL.md`
4. ADR archived → moved to `docs/archive/decisions/`, status "Archived — consolidated into {MANUAL-NAME}.md"
5. Future reference → archived ADR explains *why*; the manual is where you *follow* it

**Doc-code sync is part of task completion.** A task is not done until governing documents reflect the code changes. The coordinator checks this at every QC gate. An agent that ships code without updating the affected manual or ARCHITECTURE.md has not completed the task — same as shipping code without tests.

**Manual authority hierarchy:** Manuals > ADRs > code comments > conversation history. ARCHITECTURE.md = what IS (reference). Manuals = what TO DO (prescriptive). When a manual and ARCHITECTURE.md conflict, investigate — one is stale. Fix the stale one.

**Manual-update discipline:** Any code change that affects manual rules must update the manual in the same commit. A code change that adds behavior not covered by any manual must either (a) update the manual or (b) draft an ADR for user approval first if the behavior is a new architectural decision.

**Wizard ↔ API apply contract sync.** When a wizard step sends a new field in the `/setup/apply` payload, the API's `ApplyRequest` Pydantic model (and its nested models like `ProviderApplyConfig`) MUST accept that field — otherwise the API rejects it with 422 "Extra inputs are not permitted" because the models use `extra="forbid"`. Every wizard change that adds, renames, or removes a field in the apply payload requires a corresponding update to the API's apply endpoint Pydantic models AND the config-writing logic in the apply handler. Verify by running the wizard apply flow end-to-end after every such change.

**Conversely, fields that the API resolves internally during apply must NOT be sent by the wizard or admin.** The apply payload should contain only operator-provided or operator-confirmed data. If the API internally derives a value during apply processing (e.g., resolving `nwps_wfo` via NWS `/points` from the location's coordinates), the wizard/admin must not include that field in the payload — doing so causes the entire payload to be rejected because `extra="forbid"` treats the extra field as an unknown input.

**Why (2026-07-11):** The marine alert radius field (`marine_alert_radius_miles`) was added to the wizard's apply payload (T6.1) but never added to `ProviderApplyConfig` in the API's setup endpoint. The wizard worked, the API compiled, tests passed — but every real wizard apply attempt returned 422. This class of bug is invisible to unit tests because the Pydantic model validation only fires on the actual HTTP request path.

**Why (2026-07-15, `nwps_wfo` incident):** `build_marine_payload` in `config_writer.py` sent `nwps_wfo` in each location entry. But `MarineLocationApplyConfig` does NOT have a `nwps_wfo` field — the API resolves it internally during apply via NWS `/points`. Because the model uses `extra="forbid"`, the entire apply payload was rejected with 422. **No marine data saved at all** — buoy IDs, COOPS stations, zone IDs, surf config, fishing config, everything was lost. The fix was to remove `nwps_wfo` from the wizard payload, not to add it to the API model.

**Help content sync.** When a wizard step's behavior, fields, or options change, the step-level help content (`help.wizard.{step_id}.*` translation keys) and affected field-level help text (`ConfigField.help_text` / `wizard_help`) must be updated in the same commit. Same applies to admin sections: when an admin section's behavior changes, `help.admin.{section_id}.*` keys must be updated.

**Operator Manual sync.** When a feature, configuration option, or operational behavior documented in the Operator Manual changes, the manual must be updated in the same commit or PR. The Operator Manual (`repos/weewx-clearskies-stack/docs/OPERATOR-MANUAL.md`) is a governing document subject to the same doc-code sync rules as ARCHITECTURE.md and the component manuals.

**License document sync.** Changes to licensing terms require updates to LICENSE, ADDITIONAL-USES.md, the EULA wizard step (EULA.txt + 12 locale translations + step template), and the dashboard Legal page (legal.json + legal.tsx + 12 locale translations) in the same commit.

**Legal translation policy.** Legal documents have specific translation rules that differ from UI strings:
- `LICENSE` and `ADDITIONAL-USES.md` — English only, never translated. These are the legally binding documents.
- `EULA.txt` — English is the authoritative version. Translations provided for operator convenience. Every non-English EULA file must begin with a bilingual disclaimer (English + target language) stating the English version is the sole legally binding document.
- Dashboard Legal page content (`legal.json`) — Translated for visitor convenience. Every non-English locale must include a `legalDisclaimer` key rendered as a prominent non-dismissible banner at the top of the Legal page.
- Wizard/admin UI chrome (step titles, labels, buttons, field hints) — Fully translated, no disclaimer needed.
- Help panel content — Fully translated, no disclaimer needed. Educational/guidance content.
- Operator Manual — English only for v1.

**Why:** Translated legal text can alter legal meaning. Industry standard (Stripe, Apple, FSF/GPL) is to translate for understanding but disclaim for legal authority. The English version under California governing law is always authoritative.

## ADR content standards

Use the Nygard format. Template at `docs/decisions/_TEMPLATE.md`. Required: Status, Context, Options considered, Decision, Consequences, Implementation guidance, References.


**Status workflow:** Proposed → Accepted → (rarely) Superseded by ADR-NNN. Pinned = placeholder.

## Research rules

**Research external systems before asking the user.** Check docs/specs before raising questions the docs already settle. Local weewx 5.3 docs at `docs/reference/weewx-5.3/`. Per-provider API docs at `docs/reference/api-docs/`.

**Don't dismiss user-named options.** Evaluate ALL options the user proposes. Every option gets a row — even if the conclusion is "exclude — reason."

**Scope the API to the dashboard.** Don't add fields/endpoints for hypothetical consumers (HA, mobile). The only justification is "the dashboard needs this."

**No premature provider decisions.** Don't declare providers "dropped" or anoint future providers for coverage areas that aren't in scope yet. If v1 is US-only with NOAA, that's what it is — full stop. Which providers would serve international coverage (or any other future expansion) is a decision for when that need arises, not something to pre-decide in current plans or briefs. State what's in scope; leave what's out of scope alone.

**Why (2026-07-09):** Plan and research brief declared "Open-Meteo is dropped" and "Xweather maritime is the future path" for international marine data — decisions about providers that aren't in scope and haven't been evaluated. This creates false constraints that bind future decisions.

**Use weewx terminology where possible.** Prefer weewx ecosystem terms (observations, archive, loop packet, station) over industry alternatives.

## Brief-draft quality

**Audit open questions against ADRs before surfacing.** For each "open question" in a brief, check if an ADR/contract already settles it. Drop questions that are already locked. If a question proposes doing less than an ADR mandates, frame it as a deviation explicitly.

**Cross-check canonical mapping cells against api-docs examples.** For every canonical-mapping cell the brief references, open `docs/reference/api-docs/<provider>.md` and trace the wire field path. Mismatches = canonical-table bug → STOP and surface to user. Do this at brief-draft, not audit-time.

**Verify api-docs provenance.** Files without "Captured: YYYY-MM-DD via <live URL>" headers are unverified inputs. Either capture fresh or mark claims as "tentative, verify at fixture-capture time."

**Verify codebase state.** When the brief cites file paths, helper names, settings paths, or anti-patterns: open the file and confirm. When the brief cites a conversion function: do a dimensional sanity check (name one reference data point, trace it through the function mentally).

**Canonical-spec operationalization.** When a canonical contract leaves a parser definition implicit ("first line of X"), surface the operationalization to the user at brief-draft. Don't let api-dev silently pick a parser.

## Execute the FULL request, not the easy parts

**Every item in the user's request is mandatory.** When the user gives a multi-part instruction ("do X and also Y"), plan and execute ALL parts before reporting progress. Do not cherry-pick the easier or more familiar items and defer the rest. If some parts require more research or harder implementation, that's the reason to start them first — not to skip them.

**Never ask the user to prioritize their own requests.** Everything the user asks for is mandatory — do not ask "which is most blocking?" or "which should we tackle first?" Just do all of them. If they can be parallelized, parallelize. If they must be sequential, start immediately. The user's time is wasted when they have to re-assert that their requests are requirements.

**Why (2026-05-27):** User reported three issues (seismic map sizing, logo upload, earthquake wizard config). The lead asked "which is most blocking?" instead of working all three in parallel. The user had to correct this — every item they raise is mandatory, not optional.

**Plan all parts together before executing any.** When a request has additions AND removals, new features AND fixes, research AND implementation — design one coordinated plan that covers everything. Executing half the request and then asking "what about the other half?" wastes tokens and user patience.

**The lead does not have authority to defer plan items.** When a plan lists a phase or task, the lead executes it. If the plan says "deferred," that is a scheduling note from the plan author, not permission for the lead to skip it when the user says "execute." When the user asks you to execute a plan, every phase that the current work enables is in scope. "The plan said deferred" is not a valid reason to stop short — only the user can decide what is deferred.

**Why (2026-06-30):** Phase 6 audit completed, but the lead reported Phase 7 (Admin UI) as "deferred per plan" without building it. The plan's "deferred" annotation was a drafting-time scheduling note, not an opt-out. The user had to correct this: the lead does not have deferral authority.

**Why (2026-05-26):** User asked to (1) analyze Belchertown records and carry them over to Clear Skies, and (2) eliminate inside-temp and custom records. The lead spent multiple agent cycles researching and executing only the removals while completely ignoring the additions — the primary ask. The user had to remind the lead twice. Tokens were burned on research that was never acted on.

## Agent orchestration, dispatch, and the false-claim protocol → `rules/agents.md`

Moved 2026-07-27 (Marine Model Restoration Plan, task A2). "Agent orchestration", "Architectural
change block — mandatory agent prompt section", "Scope binding before agent dispatch", "Agent prompt
requirements", and "False-claim protocol" now live in one place:
[rules/agents.md](agents.md). Not duplicated here.

## Audit rules and the round-close verification gate → `rules/verification.md`

Moved 2026-07-27 (task A3). "Audit rules" and "Round-close verification gate" now live in
[rules/verification.md](verification.md), together with the three-layer model
(guard / invariant / adversarial) and the known-answer test mandate for numerical kernels.

## Runtime environment

**Dev/test runs in `weather-dev` LXD container, not Windows.** Shell into container: `ssh weather-dev "<command>"`. File sync: push to GitHub from DILBERT, then run `scripts/sync-to-weather-dev.sh`. Browser testing: `http://192.168.2.113:<port>`. DILBERT = editing + git + planning only.

**The API runs on the `weewx` container (`weewx.shaneburkhardt.com`), NOT weather-dev.** The API co-locates with weewx because it reads the weewx archive DB and `weewx.conf` locally. Dashboard, config UI, tests, and builds run on weather-dev. Do not run the API on weather-dev — see `reference/clearskies-dev.md` §"There should be NO clearskies-api running on weather-dev." To deploy API changes: push to GitHub → SSH to the weewx container → `git pull --ff-only` in the API repo → `sudo systemctl restart weewx-clearskies-api`.

**API startup takes ~2 minutes.** After `systemctl restart weewx-clearskies-api`, the cache warmer makes outbound provider API calls (Aeris, NWS, etc.) before uvicorn binds to port 8765. Any deployment script or verification step that restarts the API must wait at least 120 seconds before hitting endpoints. `sleep 10` will get connection refused.

**Config files NEVER go in the web root.** All configuration files (`api.conf`, `realtime.conf`, `stack.conf`, `secrets.env`, `charts.conf`, `webcam.json`) live in `/etc/weewx-clearskies/`. The web root (`/var/www/clearskies/`) is wiped by `rsync --delete` on every dashboard deployment. Any file placed there that isn't in the dashboard's `dist/` output WILL be deleted. If a config file needs to be browser-accessible, Caddy serves it from `/etc/weewx-clearskies/` via a `handle` route — never by placing it alongside static assets.

**Why (2026-06-06):** `webcam.json` was placed in the web root by the wizard and deleted by `rsync --delete` during a dashboard redeploy. This happened repeatedly because the wizard wrote to `_dashboard_root` and no deployment script could exclude every possible config file. Moving all config to `/etc/weewx-clearskies/` eliminates the category of bug.

**PowerShell multi-line commits: use `git commit -F`.** Write message to `c:\tmp\<task>-msg.txt`, then `git commit -s -F c:\tmp\<task>-msg.txt`. PowerShell heredocs break on parens/quotes.

## Plan and documentation discipline

**Plan stays an index.** `CLEAR-SKIES-PLAN.md` links to ADRs. Decision content lives in ADRs, not the plan body.

**Don't hold things across turns.** Comparison tables, open decisions, investigation findings → write to a file immediately. The cost of writing is negligible; the cost of losing context mid-session is high.

**Live scratchpad during multi-agent rounds.** Maintain `c:\tmp\<phase-task>-scratch.md`. Append continuously after every commit, lead-call, audit finding, state change. Not reconstructed retroactively.

**Round briefs land in `docs/planning/briefs/`.** Not in `c:\tmp\` or other ephemeral locations.

**No decision log.** Don't maintain a round-by-round decision log in the plan or in per-domain files — git history is the build trail and the ADRs are the decision record. The decision log went unused and was dropped 2026-05-28.

**`.claude/` stays private.** Agent definitions, settings, MCP config are gitignored. Don't propose tracking them or exposing multi-agent orchestration in public repos.

## Provider module rules

**CAPABILITY declares paid-tier maximum supply set.** `supplied_canonical_fields` enumerates every field the provider can deliver on its richest plan. Runtime bundle population is conditional on what the actual response carries. Document tier-conditional fields in `operator_notes`. Tests cover both paths. Does NOT extend to keyless providers (no tier conditional) or fields the provider categorically does not supply.

**No "promotion candidates" in v0.1 contracts.** Stock weewx columns are first-class. `extras` carries operator-custom columns only.

## Belchertown reference discipline

**Check Belchertown's implementation before building equivalent features.** The Belchertown skin source is in this repo (`bin/user/belchertown.py`, `skins/Belchertown/`). Before implementing any feature that Belchertown already handles — charts, data formatting, archive queries, configuration — read how Belchertown does it and carry forward the correct patterns. Don't re-derive from first principles when a working reference exists.

**Why (2026-06-18):** The archive_interval was hardcoded as 300 across the entire Clear Skies stack. Belchertown correctly reads it from weewx.conf and passes it to the frontend. We had the code in the repo and didn't look at it. Every timing-dependent component was built on a false assumption.

## Meteorological threshold discipline

**Verify external thresholds against primary meteorological research before coding.** EPA AQI breakpoints are health standards, not meteorological observation thresholds. Use IMPROVE, WMO, NWS, CMA, and peer-reviewed atmospheric science as sources for visibility and haze parameters. Document the research source in the code comment and in the governing manual.

**Why (2026-06-24):** PM2.5 > 12 µg/m³ (EPA "Good/Moderate" breakpoint) was used as the haze detection threshold. This is a health standard with zero relationship to visible haze — no meteorological service worldwide uses it. The correct thresholds are RH-graduated values from CMA, IMPROVE, and WMO research (PM2.5: 50/35/25 µg/m³ at dry/moderate/humid RH). The mismatch caused false haze reports under clean SoCal skies with PM2.5 = 11 and AQI = 46 ("Good").

**Exact label matching for sample filters.** When a filter says "clear days," use `label in {"Clear", "Sunny"}`, not substring matching on "Clear". Substring matching is a category error — "Mostly Clear" contains "Clear" but is not a clear sky. Cloud-enhancement-adjacent readings under "Mostly Clear" contaminate the clean-sky sample pool and inflate baselines.

**Why (2026-06-24):** The auto-calibration clean-sky filter used `any(sub in sky_label for sub in ("Clear", "Sunny"))`, which matched "Mostly Clear" because it contains "Clear". Kcs 1.0–1.06 readings from "Mostly Clear" skies leaked into the clean-sky pool, inflating the June baseline to 1.035 — physically impossible for a clean sky.

## Communication rules

**Plain English to the user.** Define every technical term the first time it appears in a conversation. One phrase, not a paragraph. If a reply uses 5+ unfamiliar terms, rewrite.

**Term density — keep it to roughly one technical term per sentence.** Defining a term is not enough. A sentence carrying three or four technical terms at once is hard to process even when every term has been defined and even for a reader who knows all of them — this is why dense terminology is discouraged in academic writing too. Break the sentence up, or carry one idea per sentence and let the next sentence carry the next. Prefer the ordinary word where one exists: "where the model stops" over "the handoff surface," "how far offshore" over "the cross-shore extent," "wave length" over "the characteristic length scale."

**Why (2026-07-25):** During the L3/1D boundary discussion the lead wrote sentences like "N sets how far seaward of the break the handoff sits — but only at L3-enabled spots, because there the handoff **is** L3's shoreward edge." Every term had been defined earlier, but four of them landed in one sentence and the meaning did not come through. The user had to ask "what does N govern?" to get a plain answer. Defined-but-dense is still unreadable.

**One decision thread per reply.** Don't interleave multiple topics. Note side-topics briefly at the end.

**Audit decision completeness before claiming a phase done.** Walk through the surface checklist: data model, database, API contract, external integrations, operational, UI/UX, quality bars, deployment, cross-cutting.

**Never hide operator secrets from the operator.** The wizard re-run, admin config UI, and any setup flow must pre-fill ALL existing configuration including API keys, passwords, and secrets. This is the operator's own system — there is no threat model where hiding their own keys from them makes sense. Every credential field that exists in `secrets.env` or the API's `/setup/current-config` response must round-trip through the wizard without the operator having to re-enter it. Sentinels (e.g., `_unchanged`) for form POST are fine to avoid sending plaintext unnecessarily, but the form must render with the value pre-filled (or a clear "using existing key" indicator with the sentinel). Any new provider module that adds credential fields MUST add corresponding entries to `_FIELD_REMAP` in `routes.py` and verify the env var prefix pattern in `state_persistence.py`.

**Why (2026-05-25):** Aeris `client_id` and `client_secret` were returned correctly by the API's `/setup/current-config` endpoint but silently dropped by the wizard's `_merge_from_api_current_config()` because `_FIELD_REMAP` had no entries for them. The operator was forced to re-enter keys that were already configured. Separately, `populate_from_config()` used a domain-scoped env var prefix (`WEEWX_CLEARSKIES_FORECAST_AERIS_`) instead of the actual provider-scoped prefix (`WEEWX_CLEARSKIES_AERIS_`), so the local fallback also failed.

**Verify default branch name before writing it into briefs.** api repo = `main`, meta repo = `master`. Brief errors propagate when reused as templates.

## UI implementation quality gates

These rules apply to all Track C (component) implementation work. They exist because C1–C6 was marked "code-complete" while the code diverged from the approved mockups on every measurable axis — font sizes 23% too large, border separators missing, SVG geometry changed, layout properties wrong. Forensic comparison proved agents never opened the mockup files. These rules close the gaps that allowed that.

**CX implementation briefs must include exact CSS values, not document references.** The UI-REDESIGN-PLAN and C0 inventory are strategic. Each CX implementation brief (C7-PLAN, C8-PLAN, etc.) must be **prescriptive to exact property values.** No handwaving. No "read the typography doc and apply it." Every acceptance criterion must include the exact values the agent must use, plus grep-checkable FAIL conditions. Example:

```
Card title — ALL cards on this page:
  font-family: var(--font-sans)
  font-size: var(--text-card-title, 0.82rem)
  font-weight: 600 (semibold)
  padding-bottom: 5px
  border-bottom: 1px solid var(--border)

FAIL CONDITIONS (grep-checkable):
  - Any card h2 with className containing "text-base" → WRONG
  - Any card h2 with "font-medium" → WRONG, should be font-semibold
  - Any card h2 missing "border-b" or "borderBottom" → WRONG
```

The same level of specificity applies to every element: stat numerals, labels, gauges, chart axes, SVG geometry. If the mockup says `font-size: 18px`, the brief says `font-size: 18px` and the acceptance criteria says `FAIL if not 18px`.

**Mockup-to-implementation handoff must be explicit.** When an approved HTML mockup exists, the CX implementation brief must include:

```
SOURCE OF TRUTH: docs/design/mockups/<mockup>.html
Agent MUST open this file, extract the exact CSS values for the elements
it is building, and use those values. If the code uses different values,
that is a defect — not a refinement.
```

The brief must ALSO extract the key values from the mockup and list them inline (per the rule above), so there is no ambiguity even if the agent skips the file.

**Why (2026-06-02):** C4 stat tiles mockup specified card titles at 13px with border-bottom separators. Every tile was implemented at 16px with no separators. The C4 brief told agents to read the typography spec and reference implementations but never said "open C4-stat-tiles.html and use its CSS values." The mockup was a Phase 0 artifact with no bridge back to Phase 2 code. The agents coded from a mental model.

**Coordinator must QC agent work iteratively BEFORE it reaches the operator.** The coordinator is the quality gate between the agent and the operator. When an agent delivers code:

1. Open the rendered output (dev server screenshot or headless render).
2. Compare it against the mockup (if one exists) and the spec values from the brief.
3. If there are discrepancies, **send it back to the agent for rework** with specific instructions ("card title is 16px, should be 13px per brief §X; border-bottom missing; fix these").
4. Repeat until the output matches the spec.
5. Only THEN report to the operator as complete.

The operator should never see first-draft slop. If the coordinator cannot run the dev server in a session, the task stays open — do not declare it done based on `tsc` passing.

**Visual verification (QC Gate 3) must be a side-by-side comparison, not a glance.** After the component is built:

1. Screenshot the built component at the locked footprint size.
2. If a mockup exists, screenshot the mockup at the same size.
3. Open both images and compare — report specific discrepancies (font too large, border missing, SVG proportions changed), not "looks good."
4. Run the brief's FAIL CONDITIONS as mechanical grep checks.

"It renders without crashing" is NOT visual verification. "The card title is 13px with a 1px border-bottom and the gauge value is 18px Outfit 600" IS visual verification.

**Auditor must check governing doc compliance mechanically.** For every UI card, the auditor must run these checks (grep or code inspection):

- Every card h2/title uses `var(--text-card-title)` or equivalent 0.82rem — NOT `text-base`
- Every card h2/title has `border-b` or `borderBottom` — NOT missing
- Every card h2/title uses `font-semibold` (600) — NOT `font-medium` (500) or `font-bold` (700)
- Stat numerals use `var(--font-display)` (Outfit) — NOT `var(--font-sans)` (Manrope)
- Chart labels use `var(--font-chart)` (Lexend) — NOT system fonts

These are pattern matches, not judgment calls. FAIL if any violation is found.

## Research-to-implementation discipline

**Verify data coverage claims per-location before coding against them.** When a research brief claims a data source has a given resolution or coverage area, verify the claim at the specific target location before writing code that depends on it. "CUDEM 1/9" has 3.4m resolution in its metadata but no tiles exist for SoCal. Coverage metadata describes the intended extent, not the actual extent.

**Why (2026-07-19):** The SWAN implementation assumed CUDEM 1/9 arc-second data existed for HB Pier because the metadata listed a bounding box covering 23-52°N. Investigation revealed no tiles exist south of 36°N on the Pacific coast. The entire nearshore grid ran on ~90m CRM data instead of the expected 3.4m data, producing staircase bathymetry.

**SWAN nesting files must use different names for BOUNDNEST1 (read) and NESTOUT (write).** When a SWAN level both reads boundary data from a parent and writes boundary data for a child, the input and output files MUST have different names. SWAN reads boundary files progressively during simulation — if NESTOUT overwrites the same file BOUNDNEST1 is reading, the output is corrupt.

**Why (2026-07-19):** Level 2 used `nest_boundary.dat` for both BOUNDNEST1 and NESTOUT. SWAN overwrote Level 1's 83 MB boundary file with a 3.5 MB file during the run. Level 3 read garbage and produced 0.005 m wave heights.

**Match datums at source rather than converting locally.** When a data source supports multiple datums as request parameters (e.g., CO-OPS supports NAVD88, MLLW, MHW, MSL), fetch in the datum you need — don't fetch in one datum and convert to another. Local datum conversion introduces spatial error, computational overhead, and failure modes. Two cheap HTTP requests beat one request plus a conversion that can silently fail.

**Why (2026-07-19):** VDatum REST API was supposed to convert bathymetry from NAVD88 to MSL. It returned 412 errors in production and the code fell back to a 0.0m offset. Even if it had worked, the conversion was to MSL while CO-OPS predictions were in MLLW — creating a worse mismatch (0.86m vs the original 0.06m). ADR-098 replaced this with match-at-source: request CO-OPS predictions in the DEM's native datum, eliminating conversion entirely.

**Never silently fall back to 0.0 for datum conversion failure — fail explicitly.** A silent 0.0m fallback produces code that appears to work but has a systematic depth bias. If datum matching cannot be confirmed, the run must fail with an ERROR log. "Proceed with potentially wrong data" is never acceptable for geophysical models.

**Why (2026-07-19):** The VDatum normalization code logged a WARNING when the API returned 412, then applied a 0.0m offset and continued. The INFO log said "Applied NAVD88 to MSL offset: 0.000m" — making it look like the conversion succeeded with a zero offset when it actually failed entirely.

**SWAN physics commands must be per-level — shared blocks only work when all levels have similar dynamics.** A physics command that is safe at 1km resolution can diverge at 10m. SETUP and bare DIFFRACTION are both stable at coarse resolution but numerically unstable at surf-zone resolution. Per-level physics selection is mandatory for any multi-resolution nested SWAN configuration.

**Why (2026-07-19):** A shared physics block applied SETUP and bare DIFFRACTION identically to all three levels. L1/L2 survived because the surf zone is sub-grid. L3 diverged the moment breaking activated — the exact hour swell arrived and QB > 0.

**Never emit bare `DIFFRACTION` in SWAN — always stabilize with smoothing.** The SWAN manual explicitly warns "diffraction computations often converge poorly or not at all" without stabilization. Smoothing (`DIFFRACTION 1 0.2 [smnum]`) applies to a temporary copy and does not affect outputs. Filter width εx = ½·√(3n)·Δx; for Δx=10m target εx≈45m → smnum=27.

**Silent skipping of configured inputs is a bug pattern — always log what was skipped and why.** When code iterates over configured items (structures, locations, species) and skips some, the skip must produce a WARNING log. Silent skips cause "everything looks fine" while the output is degraded.

**Why (2026-07-19):** HB Pier's structure config (bearing/length/distance format) was silently skipped because the OBSTACLE assembly only handled explicit-coordinate structures. No log, no warning. The pier was absent from every SWAN run since the 3-level redesign.

**Grid sizing must come from actual data (profiles, measurements), not illustrative estimates in briefs.** Research briefs contain approximate numbers for illustration. Implementation code must use real data (cached depth profiles, GSFM shelf distances) to size domains. A brief saying "~1 km offshore" is a rough estimate; the actual 15m depth contour at HB Pier is 2,350m offshore.

**Why (2026-07-19):** Level 3 grid was hardcoded to 1 km offshore based on a brief illustration. The bidirectional profile showed 15m depth at 2,350m. 42% of transect CURVE points fell outside the grid and returned exception values.

**All SWAN grid geometry is fixed at setup time — no runtime overrides.** L1, L2, and L3 bounding boxes and the L2 NESTOUT targeting area are computed together in `compute_domains()` once, before any SWAN level runs. No code may resize, reposition, or override `cluster.grid` after `compute_domains()` returns. All inputs that affect grid sizing (structures, depth profiles, spot positions) must be passed to `compute_domains()` — not applied later. If the NESTOUT doesn't cover the L3 grid, swell energy is silently blocked at the uncovered boundary segments. SWAN will "succeed" with near-zero wave heights and no errors.

**Why (2026-07-23):** A Sonnet agent couldn't get structures passed to `compute_domains()` at the right time, so instead of fixing the caller, it added a second `smart_size_l3_grid()` call at runtime that overrode `cluster.grid` AFTER Level 2 had already written its NESTOUT. The L3 grid extended beyond the NESTOUT. Result: 0.01m Hs during a 6-8 ft south swell. The coordinator accepted "data is flowing" without checking whether the values made physical sense.

**Every SWAN INPUT file requires wind forcing.** GEN3 WESTHUYSEN enables wind generation physics including quadruplet interactions. SWAN refuses to run quadruplets without a wind field (exit code 2). This applies to every SWAN configuration — main 3-level runs, quick updates, AND SurfBeat strips. "Swell-only" is not an excuse to omit wind — the HRRR wind at the spot coordinates is always available and must always be provided.

**Why (2026-07-23):** The SurfBeat strip INPUT had GEN3 WESTHUYSEN but no INPGRID WIND. SWAN exited with code 2. The API retried for every cadence hour, each attempt failing, causing the surf endpoint request to time out.

**"Data is flowing" is not verification — check physical plausibility.** When a pipeline produces output, the coordinator must verify the output values make physical sense before declaring the task complete. For surf data: compare face height against NWS alerts, Surfline, or NDBC buoy observations. For any geophysical model: check that output magnitudes are within the expected range for current conditions. A pipeline that returns 0.1 ft during a Beach Hazards Statement for 5-7 ft surf is not working — it's producing garbage with a valid HTTP status code.

**Why (2026-07-23):** Part A was declared complete because the surf endpoint returned non-empty JSON with populated fields. Nobody checked whether 0.1 ft face height during a Beach Hazards Statement was physically plausible. The data was wrong by a factor of 60x.

**Agents do not make design decisions — they implement prescribed solutions.** When an agent encounters a gap (missing parameter, function that doesn't accept needed data), the correct response is to fix the caller to provide what's needed — not to add a workaround at a different point in the pipeline. Workarounds that bypass the intended data flow create mismatches between components that are invisible to unit tests and only manifest as wrong output values in production.

**Why (2026-07-23):** An agent couldn't pass structures to `compute_domains()`, so it added a runtime override. Another omission left wind out of the SurfBeat strip. A third left CUDEM profiles out of the compute service path. All three were "agent chose the path of least resistance instead of fixing the actual gap" bugs.

**"Code-complete" requires coordinator visual sign-off.** The agent that writes the code cannot declare it done. The coordinator must render the output, verify it against the spec, and sign off. Self-attestation of visual quality is not accepted.

**Why (2026-06-02):** C1–C6 were all self-attested as code-complete. QC gates checked `tsc` (compiles) and `vite build` (bundles) but never compared the rendered output against the mockups. Every tile card had wrong font sizes, missing separators, broken sr-only hiding, no vertical centering, and inconsistent text hierarchy. The operator discovered all of this during live testing — not during any QC gate.

## Units and layer ownership are settled doctrine — read them before escalating

**Rule.** Before escalating anything that touches units, or asking who should compute something,
read `docs/ARCHITECTURE.md` §Layer Responsibilities and the units sections of
`docs/manuals/API-MANUAL.md`. Both questions are already answered there. An escalation that the
manuals answer is not caution — it is a failure to read, and it costs the operator time and money.

**The two answers, so there is no excuse for asking again:**

1. **The API is the single conversion authority.** Every service behind it works in canonical SI
   and emits SI. The API converts to the operator's display units. It follows that **no threshold,
   constant, or function parameter anywhere behind the API may be calibrated in a display unit.**
   A constant named `_FT`, `_F`, `_MPH`, `_IN` compared against a canonical value is the defect —
   the fix is canonical constants, never a conversion call to feed the display-unit-calibrated
   comparison. The only legitimate conversion behind the API is provider **ingest** normalisation
   from an upstream unit into SI, and you must be able to name the upstream unit.

2. **A computation lives where its inputs already live, and exists once.** The API owns station
   metadata — timezone, elevation, location — and owns almanac and solunar. A companion service
   that finds itself needing station timezone is not missing a config key; it is computing
   something that was never its job. Two implementations of the same computation is the defect,
   not a missing input.

**Why (2026-07-25):** during Phase 6 of the marine separation the coordinator escalated two
questions to the operator — "where should the marine service get station timezone for solunar?"
and "which unit should storm-surge thresholds compare in?" — and passed a third along as a
"spot-check" (Fahrenheit water-comfort thresholds behind a conversion call). All three are the
same two doctrines above, both already documented repeatedly. The operator's response was that
this proved the documentation had not been read. Escalating a documented answer is worse than
deciding wrongly: it burns the operator's time *and* signals the docs are optional.

**How to apply.** When a units or ownership question surfaces: grep the manuals first, cite the
section, and implement. Escalate only if the manuals genuinely conflict with each other — and
then escalate the *conflict*, with both citations, not the underlying question.

## Over-triggering is a failure mode too — apply the settled pattern, do not re-escalate it

**Rule.** Before escalating anything as architectural, ask two questions in this order:

1. **Has this responsibility already been ruled on?** If a ruling exists and this is simply the next
   instance of the same question, applying it is not a new decision. Trigger 7 governs deciding that
   a service needs a new interface — a design choice. It does **not** govern applying an
   already-settled pattern to the next case. Counting endpoints, config keys or dependencies is not
   the test; whether the responsibility is settled is the test.
2. **Does the code in question still do anything?** CLAUDE.md's own table says removing code that
   provably never executes is methodology, not architecture — *nothing was being done; nothing stops
   being done*. Trigger 2 asks whether a responsibility moves or vanishes. A control whose only job
   was revealing a field that is being deleted has no responsibility left to lose. "Provably" means
   measured — trace every caller and every effect — not assumed.

**The asymmetry that makes this hard, stated plainly:** under-triggering is loud and
over-triggering is quiet, so over-triggering *feels* safe. It is not. It costs the operator time and
money, it stalls work behind questions the project's own documents already answer, and — as C-15
demonstrated — it can leave whole modules unimportable and routers unregistered while everyone waits
for an approval that was never needed.

**When you do escalate, escalate the conflict, not the question.** If two governing documents
genuinely disagree, bring both citations. If one document answers it, cite the section and implement.

**Why (2026-07-25, marine separation Phase 7):** the coordinator escalated two items in one session
that the documents already settled. **C-54** — how should the wizard learn whether SWAN is installed,
now that it does not run on the API host? — was answered by the C-42 ruling and ARCHITECTURE.md's
add-on invariant (the wizard asks the API; the API fronts the marine service), and two instances of
that exact pattern had landed *the same morning*. The coordinator framed it as open because answering
it needed a third marine endpoint. It also never asked *how the API would know*, whose answer was
structural: the marine service registers with the API, so the channel already existed. **C-58** — may
a control be deleted once the field it existed to reveal is gone? — was answered by the
architecture-vs-methodology table above; the coordinator pattern-matched it to the Phase 4A
`wave_transform.apply_supplements()` incident without applying the test that distinguishes them (in
that incident, a component with **live behaviour** was deleted). The operator's response to both was
that they should never have been asked. Both were over-triggers. Compare C-15, where the same
instinct left eight modules unimportable.

## Moving a module moves its dependencies — that is not a new dependency

**Rule.** When a plan directs you to move a module to another service, its existing imports move with
it. Adding `scipy` to the target service's `pyproject.toml` because you moved a module that has
always imported `scipy` is **not** trigger 7 and does not need approval. Trigger 7 is about a
service *acquiring a dependency it did not previously need* — a design decision. Carrying an
existing one along with the code that requires it is the mechanical consequence of a move that was
already authorised when the file was named on the move list.

**The test:** would this dependency exist if the code had stayed where it was? If yes, it travels
with the code and needs no approval. If no — the module is being changed to need something new —
that is trigger 7 and stops.

**Why (2026-07-25):** Phase 5 of the marine separation named ~29 modules to move. The coordinator
treated their unguarded imports (`scipy`, `shapely`, `prometheus-client`, `babel`, `pyyaml`,
`skyfield`) as six trigger-7 additions, escalated them as one blocking item (C-15), and registered a
decision to "escalate and wait, do not self-approve." The result: eight modules left unimportable,
three routers unregistered, and the operator asked to authorise what the plan had already authorised
by naming the files. The operator's response: *"this was specifically outlined in the plan phase 5
TO MOVE — why did you defer?"* Over-triggering has a real cost; it is not the safe default it feels
like.

**Corollary — do not leave a resolved item wearing a blocking marker.** C-15 was answered and its
code landed, but its heading still read "⛔ BLOCKING, AWAITING OPERATOR" hours later, so it read as
live work. Close the entry in the same action that closes the work.

## The marine service is an add-on reached only through the API

**Rule (operator, 2026-07-25).** The marine service is an add-on to the API and does not necessarily
run on the same host. **Every other element of Clear Skies communicates with it through the API, and
only through the API** — dashboard, config UI wizard, admin pages, third-party clients alike. This is
for **security** (one authenticated boundary, one secret, one place enforcing auth and rate limiting)
and for **coordination** (one source of truth for operator config, one place that knows whether the
service is installed at all).

**When the API needs marine data for something that is not a dashboard route** — a wizard lookup, a
setup-time question, an operational check — the answer is always a **pass-through in the API**. Never
a marine provider module imported into the API. Never a direct call from another component. The
marine service exposes it; the API fronts it.

**Two shapes that look reasonable and are wrong:**

- *"The wizard needs nearby buoy stations, so the API keeps `providers/buoy/`."* No — the API proxies
  the query. Keeping the module puts marine provider code back in the API, which the separation
  exists to remove.
- *"The wizard can call the marine service directly for discovery."* No — that is a second component
  holding the secret and a second network path to secure.

**Why (2026-07-25):** during Phase 6 the coordinator proposed both of the above and put them to the
operator as an open choice. The invariant was implicit in ADR-099 and in the companion-proxy design
but had never been stated as a rule, so each case was re-argued from scratch instead of being decided
once. Now written in `docs/ARCHITECTURE.md` under "The marine service is an add-on reached only
through the API — INVARIANT"; cite it rather than re-deriving it.

**Corollary for anything unreachable.** Because the API is the only client, a marine-service outage
surfaces in exactly one place. Handle it honestly there: a wizard discovery query that cannot reach
the marine service must say so, never return an empty list. "There are no buoys near you" is a wrong
answer wearing a valid response's clothes.

## Validate against reality, never against the model's own output → `rules/verification.md`

Moved 2026-07-27 (task A3). See [rules/verification.md](verification.md). Not duplicated here.

