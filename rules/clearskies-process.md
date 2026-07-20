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

**Concise, not padded.** ~80 lines standard, ~150 for parent-pattern ADRs. Cut: historical recaps, multi-paragraph option analysis, implementation mockups, trade-off prose restating the obvious. Keep: the decision in 1-2 sentences, one-line verdicts per option, concrete consequences, out-of-scope items.

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

## Agent orchestration

**Lead = Opus, orchestration + judgment only.** Teammates = Sonnet. The lead does NOT write code, run tests, do code reviews, or fill in templates. Those are delegated tasks. Lead's job: break down work, write focused prompts, spawn agents, monitor, QC output, make judgment calls, commit.

**Sonnet for ALL delegated work.** Implementation, tests, audits, verification, closeout extraction. Opus auditor is not worth the cost — Sonnet auditor validated at 75K tokens with clean results (3b-15 close).

**Lead reads and researches what it needs to understand — delegate what it doesn't need to personally comprehend.** The coordinator cannot coordinate what it doesn't understand. Reading project documents, tracing code paths, running diagnostic commands, checking logs, verifying container state — these are core coordinator activities when they inform judgment calls, agent prompts, QC, or stalemate-breaking. An agent summarizing a file is not the same as the lead understanding it. The lead reads directly when understanding is the point.

**Delegate mechanical and bulk work.** What gets delegated to Sonnet agents: writing code, writing tests, writing documentation drafts, running test suites, performing mechanical audits (grep for banned terms, check file counts), bulk file edits, broad searches across many files, and cataloging tasks. When delegating research, require a detailed brief back (not a one-line summary). The lead uses the brief to make decisions and write prompts.

**When unsure, ask the user.** If the lead isn't sure whether to do research directly or delegate it, ask. Don't guess at the boundary — the user's judgment on cost vs. context quality is what matters.

**Why (2026-06-14, corrected):** The original rule (2026-05-18) said "lead does NOT do research grunt work" and "the only direct tool calls the lead makes are spawning agents." This was never the user's intent. It over-corrected from "lead reads too many files before spawning agents" to "lead delegates ALL reading." The coordinator's value is judgment informed by direct understanding — reading, diagnosing, and verifying are part of the job. The distinction is understanding vs. mechanical bulk work, not "all research" vs. "no research."

**Small, focused tasks.** Each agent gets one specific job with a clear deliverable. "Implement 2 provider modules + tile proxy + wiring" is too big. "Implement openweathermap.py radar provider per this spec" is right. Shorter runs = less idle-bug risk, easier to monitor, cheaper to retry.

**Agents must read source documents directly — NEVER paraphrase manuals or plans into agent prompts.** The coordinator tells the agent WHICH files to read and WHICH sections are relevant, and the agent reads the original text itself. The coordinator's prompt provides: (1) the task description and deliverables, (2) a reading list of specific file paths and section names/line ranges the agent must read before coding, (3) scope block and verification commands per the existing rules. The coordinator does NOT restate, summarize, or paraphrase manual content, plan task specs, design criteria, or acceptance criteria into the prompt — the agent reads those from the source documents.

**Why this is a hard rule:** When the coordinator paraphrases a 50-line task spec into a 15-line brief, information is lost — field names get wrong, acceptance criteria get dropped, design constraints get simplified away. The agent codes from the lossy summary. The coordinator then QCs the output against the same lossy summary — not against the original spec. Errors pass undetected. The result is slop that technically matches the brief but violates the plan. This happened systematically across every phase of the MARINE-FIXIT-PLAN and required a complete redo.

**What the reading list looks like (example):**
```
READING LIST (read these files BEFORE writing any code):
1. docs/planning/MARINE-FIXIT-PLAN.md — read Phase 5, tasks T5.1 and T5.2 (your assigned tasks). These contain the exact card specs, data sources, acceptance criteria, and design references.
2. docs/manuals/DESIGN-MANUAL.md — read the marine cards section. Your cards must follow these patterns.
3. docs/manuals/API-MANUAL.md §17-18 — read the surf endpoint contract and wind/water-temp data source rules.
4. src/components/marine/tabs/SurfingTab.tsx — read the current implementation you're modifying.
```

**What the coordinator adds beyond the reading list:** task-specific context the documents don't contain — e.g., "T2.5 already landed and changed the wind source, so the NDBC wind fetch at lines 284-298 no longer exists; your starting point is the current file, not the plan's line numbers." Also: the scope block, git restrictions, verification commands, and any lead calls that resolve ambiguities between documents.

**Anti-pattern (BANNED):** Restating plan content in the prompt. If the plan says "Surf Score Card (2x2): The hero card. Prominently displays the current surf score (numeric, not stars — e.g., '4.2 Very Good'). Below the score: scoring breakdown showing what factors contributed..." — the coordinator must NOT rewrite this as "Build a 2x2 score card showing the surf score with a breakdown." That loses "numeric, not stars", the example format, and the absorption of the separate breakdown card. Instead: "Read MARINE-FIXIT-PLAN.md T5.1 — it specifies three cards with exact sizes, data elements, and design references. Build exactly what it says."

**The coordinator still reads the documents first.** The coordinator must understand the task deeply enough to write the scope block, resolve ambiguities, and QC the output. But understanding the task ≠ restating the task. The coordinator reads to understand; the agent reads to implement.

**Monitor via SendMessage.** After spawning background agents, check git log for commits every 3-4 minutes. If an agent has committed but gone quiet >4 min, SendMessage to wake it. After ~3 silent pings, TaskStop and reconstruct from git. The idle bug (#56930) means agents can finish work and sit silent for 30+ min — polling is the only mitigation.

**Foreground for fast tasks.** If an agent's task takes <2 min (verify git state, extract git stats, run one command), use foreground mode. Background is for tasks >5 min where parallel work is possible.

**Agents edit and commit ONLY on the local machine — HARD BAN on container edits.** All source code editing and `git commit` happens on the local machine (DILBERT/CATBERT) at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*`. Agents must NEVER:
- Edit source files on weewx or weather-dev (not via SSH, not via any mechanism)
- Run `git add` or `git commit` on weewx or weather-dev
- Run any git write operation on any container

SSH to containers is for READ-ONLY operations: running tests, reading logs, checking service status, verifying deployed behavior. That's it.

**Agents have NO GitHub rights.** Agents must NOT run `git push`, `git pull`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches — not on the local machine, not on containers, not anywhere. The coordinator handles all GitHub operations (push/pull) with explicit user authorization. If an agent discovers it needs to sync with a remote, it STOPS and reports via SendMessage.

**The deploy flow is always:** local edit → local commit → coordinator pushes to GitHub → deploy script pulls to container. No shortcuts.

**Never run the full pytest suite.** The full API test suite takes too long and wastes tokens. When verifying changes, run ONLY the tests relevant to the files changed — e.g., `pytest tests/providers/marine/test_nwps.py -q` not `pytest`. Find the matching test file for each changed source file. Same applies to dashboard vitest — run specific test files, not the entire suite.

**Why (2026-07-14):** Full pytest suite runs for minutes and produces thousands of lines of output that flood agent context. Targeted tests verify the same thing in seconds.

**Deploy scripts (use these, not manual commands):**
- `scripts/deploy-api.sh` — API changes → weewx container (pull + restart + wait + verify)
- `scripts/redeploy-weather-dev.sh` — Dashboard/config changes → weather-dev (pull + restart + build + publish)
- `scripts/sync-to-weather-dev.sh` — Source-only refresh on weather-dev (no build/restart)

The scripts handle user-switching (`sudo -u ubuntu` for git/build, `sudo` for systemctl). Never run manual `git pull`, `systemctl restart`, `chown`, or `chmod` on containers — see CLAUDE.md "Filesystem permissions on containers" and `rules/coding.md` §1 rule 12.

**Why (2026-06-22, repeated 2026-07-13):** Agents committed directly on the weewx container TWICE. First incident: commit couldn't be pushed (no GitHub creds), Nextcloud sync nearly destroyed it, required git-bundle recovery. Second incident: 2 commits orphaned on weewx for coverage endpoint + OFS model, never made it to GitHub or local checkout, required manual patch extraction and replay. Both times the agent SSH'd in, edited files on the container, and committed there instead of editing on the local machine. The rule existed both times. Enforcement must be in every agent prompt — not just the rules file.

**Pre-flight repo verification before EVERY agent dispatch.** Before spawning any agent that will modify a repo, the coordinator runs `git status` and `git log --oneline -1` on the target repo. If there are uncommitted changes, unexpected HEAD, or any other surprise — STOP and report to the user. Do not dispatch the agent. Additionally, every agent prompt must include this block:

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.

This block is mandatory in every implementation agent prompt. Not optional, not "when relevant." Every single one.

**Why (2026-05-28):** A dev agent was dispatched without pre-flight verification. The remote had 14 unknown commits. The agent pulled, hit conflicts, and merged — all autonomously. The coordinator accepted the merge report and continued building on top of unreviewed code. The user discovered the mess hours later. Pre-flight would have caught the divergence before any agent touched the repo. The git prohibition block would have prevented the agent from pulling even if pre-flight was skipped.

**Independent lead verification of ALL teammate claims.** Before accepting any teammate's work:

1. **Re-run the verification command** from the scope-binding step in a fresh shell on weather-dev. The teammate's self-reported numbers are one data point, not truth.
2. **Spot-check one non-trivial requirement against the code.** Pick one requirement from the brief's scope block, open the file, and confirm it was implemented — not just that tests pass. Tests can pass while requirements are unmet (tests may not cover the requirement).
3. **Compare the commit list against the scope block.** Every file in "Files to create or modify" should have a corresponding commit. Any commit touching a file in "Files NOT to touch" is a scope violation — investigate before accepting.
4. **If the numbers don't match, STOP.** Do not close the round. Triage the delta: pre-existing vs. introduced. Surface to user if introduced failures exist.

**Why (2026-05-11):** 3b-12 api-dev claimed "1762 passed, 0 failed"; lead's independent run returned 103 failed. The lead initially trusted the count and almost closed the round on a false-clean narrative. Additionally, dashboard a11y compliance claims were never independently verified by the lead.

**Lead-direct for small fixes.** When auditor findings or test bugs are mechanical and small (<=50 lines, <=3 files, no judgment calls), the lead fixes directly. Spawning costs 30-60 min; lead-direct is minutes.

## Scope binding before agent dispatch

**Every agent prompt must contain an explicit scope block.** Before the agent writes any code, it must SendMessage the lead with a one-paragraph scope acknowledgment: what it will deliver, what it will NOT touch, and the verification command it will run before closeout. The lead confirms or corrects. No code before the scope ack is confirmed.

**Scope block required contents (in the brief):**

1. **Files to create or modify** — exhaustive list, not "and related files."
2. **Files NOT to touch** — explicit exclusions (e.g., "do not write unit tests; test-author owns those").
3. **Verification command** — the exact pytest/axe-core/build command the agent will run before reporting done, including the working directory and expected pass threshold.
4. **Deliverable definition** — what the lead will see in git log when the agent is done (e.g., "N commits on origin/main implementing X; pytest at <path> showing M pass / 0 fail").

**Why (2026-05-11):** 3b-12 api-dev wrote 850 lines of unit tests in a flat file (test-author's job at the nested location), committed a plan-status-close on the meta repo (lead's job), and claimed "1762 passed, 0 failed" (103 actually failed). A scope block naming "files NOT to touch: tests/" and "deliverable: N commits on api repo only" would have made all three violations detectable at the scope-ack step before any code was written.

## Agent prompt requirements

**Every agent prompt (brief) must contain these sections.** Sections may be brief for simple tasks but cannot be omitted.

1. **Round identity** — round number, date, lead, teammates, auditor.
2. **Scope (in / out)** — per "Scope binding before agent dispatch" above.
3. **Reading list** — ordered list of files to read before coding. Extract relevant sections; do not say "read the full rules file" for a 150-line file when 10 lines are relevant.
4. **Pre-round verification** — what the lead verified before writing the brief (repo HEAD, weather-dev sync state, pytest baseline, cross-check results). This is the lead's evidence that the starting state is clean.
5. **Per-deliverable spec** — for each endpoint/module/component, the behavior decision tree or equivalent. Not "implement the endpoint" — the specific happy path, error paths, edge cases, and response shapes.
6. **Lead calls** — decisions the lead has already made that the agent must follow (not re-derive). Cite the reasoning.
7. **Open questions** — questions the agent must surface to the lead via SendMessage, NOT resolve unilaterally. Every open question must have been audited against ADRs first per the existing "Audit open questions against ADRs before surfacing" rule.

**Prompt anti-patterns (from incidents):**
- "Implement X and related files" — vague scope invites scope creep. Name every file.
- Citing a file path without verifying it exists (3b-10: `settings.aeris.client_id` was wrong).
- Citing a helper function without verifying it does what the brief claims (3b-10: brief said "don't extend datetime_utils.py" but the helper already existed there).
- Citing a numerical formula without a dimensional sanity check (3b-11: off-by-1000 chemistry bug encoded in the brief).

## False-claim protocol

When a teammate's self-reported numbers are proven wrong by the lead's independent verification:

1. **Do not close the round.** The round stays open until the real numbers are established.
2. **Triage the delta.** Categorize each failure as pre-existing (present at the round's baseline commit) or introduced (new in this round's commits). Use checkout-and-rerun against the baseline commit for a representative sample.
3. **Record the real numbers in the scratchpad** with the verification command and commit hash. Strike through the false claim with the actual numbers.
4. **Pre-existing failures** go to the parking lot as a tracked item (not buried in narrative). They do not block the current round's close IF the round introduced zero new failures.
5. **Introduced failures** block the round. Remediate before close.
6. **Do not attribute malice.** Agents hit context limits, misread output, or run against stale state. The protocol exists to catch the error, not to punish it. But the error must be caught — that is non-negotiable.

**Why (2026-05-11):** api-dev claimed "1762 passed, 0 failed"; reality was "1754 passed, 103 failed." 102 were pre-existing; 1 was introduced. The lead initially trusted the claim. The false-claim protocol ensures the lead always establishes ground truth independently before closing.

## Audit rules

**Two audit modes, both required for non-trivial work.** Runtime tests against real backends + source-only review against ADRs/rules. Neither alone is sufficient. Order: dev produces → tests run on weather-dev → auditor reviews diff → lead synthesizes.

**Real findings only.** Every finding cites a specific ADR/rule/RFC and identifies: (a) a specific failure mode, (b) a missed constraint, or (c) forced downstream rework. Generic tradeoffs are not findings. Empty audits are fine.

**Lead synthesizes auditor findings.** Per finding: accept (with specific remediation + reasoning), push back (with reasoning), or defer (with condition). Don't forward raw findings to dev unedited.

**Remediation covers ALL affected documents, not just the ones the auditor named.** When accepting a finding, grep all governing documents (plan, manuals, ARCHITECTURE.md, mockups) for the same error before committing the fix. A finding that says "DESIGN-MANUAL count is wrong" almost certainly means the plan, the mockup, and the verification section have the same wrong number. Fix them all in one commit.

**Why (2026-07-14):** QC Gate 1 flagged "icon count 31→32" (11+21=32, not 11+20=31). The remediation fixed the DESIGN-MANUAL and mockup but left the plan document with "20 new" and "31 total" in 9 places. The next session's agent caught the discrepancy at dispatch time — wasting a scope-acknowledgment round-trip to confirm the correct count.

**Phase-boundary ADR compliance sweep (mandatory).** Before declaring any phase complete, run the audit in the *other* direction: for each Accepted ADR, verify that every v0.1 implementation requirement has corresponding code, config, or documentation in the repos. The per-round auditor checks the code that *was* written; this sweep catches code that *should have been* written but wasn't. Walk the full ADR index — not just the ADRs the current phase touched. Surface every gap to the user before closing the phase.

**Why (2026-05-19):** Phases 2–4 closed with clean per-round audits, yet a post-Phase-4 sweep found 15+ ADR requirements with zero implementation: the entire configuration UI (ADR-027), internationalization infrastructure (ADR-021), observability/metrics (ADR-031), realtime direct mode (ADR-005), production docker-compose and systemd units (ADR-034), Leaflet maps, NOAA report parser, custom pages, and more. Per-round audits only checked the diff — they never asked "what's missing from the full ADR surface?" The gap went undetected across 4 phases and dozens of audit rounds because nobody ran the reverse check.

**Per-round ADR spot-check (upstream complement to the phase-boundary sweep).** The phase-boundary sweep is the backstop; it should not be the first time anyone checks ADR compliance. At round close, the lead picks the 2–3 ADRs most relevant to the round's work and verifies that the round's implementation satisfies those ADRs' acceptance criteria (see ADR template). This is not a full sweep — it is a spot-check that catches drift before it accumulates across an entire phase. Record the spot-checked ADRs and their pass/fail in the verification evidence block.

**Acceptance-criteria-driven sweep.** When running the phase-boundary sweep, walk each ADR's acceptance criteria checklist (not just the prose). For ADRs that lack acceptance criteria, flag the absence as a finding — the ADR needs updating before the phase can close. An ADR without acceptance criteria is an ADR that cannot be verified.

## Round-close verification gate

**A round is not closed until all four verification steps are complete.** The lead performs these AFTER the auditor submits findings and AFTER lead-direct remediation. The verification is recorded in the scratchpad before the plan-status-close commit.

### Step 1: Brief scope walkthrough

Open the round brief's "Scope (in / out)" section. For each in-scope item, record one of:
- **DONE** — cite the commit hash where it landed.
- **DEFERRED** — cite the parking-lot entry (must exist in the scratchpad or plan; cannot be implicit).
- **MISSING** — STOP. Do not close the round. Remediate or explicitly defer with user approval.

### Step 2: Verification evidence block

Record in the scratchpad:

```
## Verification evidence — round {N}
- pytest command: `ssh weather-dev "cd /path && pytest ..."`
- pytest result: {N passed / M skipped / K failed} at commit {hash}
- auditor findings: {N total — X remediated, Y deferred (cite parking-lot), Z pushed back (cite reasoning)}
- scope walkthrough: {N of N in-scope items DONE, M DEFERRED (cite items), 0 MISSING}
- lead spot-check: {which requirement was spot-checked, what was observed}
- ADR spot-check: {which ADRs checked, pass/fail per acceptance criterion}
```

### Step 3: Deferred-item tracking

Every item marked DEFERRED or placed in a parking lot must appear in one of:
- The plan's task table as a future-round row with a clear description.
- The scratchpad's parking-lot section with a one-line description and the round that created it.

Items buried in narrative prose (decision log, closeout report, mid-scratchpad notes) are NOT tracked. If an item exists only in narrative, promote it to a tracked location before closing the round.

### Step 4: Prompt faithfulness check (when closing a user-initiated task)

When the task originated from a user prompt (not a plan-internal round), walk the original prompt line by line. Every distinct request in the prompt must map to either:
- A deliverable (cite commit or file).
- An explicit deferral (cite where tracked).
- A justified exclusion (cite reasoning communicated to user).

**Why (2026-05-26, 2026-05-27):** (1) User asked for analysis + carry-over + elimination of records. Lead spent multiple cycles on elimination only, ignoring the analysis (primary ask). User had to remind twice. (2) User reported three issues; lead asked "which is most blocking?" instead of working all three. (3) 3b-12's 102 pre-existing test failures were noted in narrative but not tracked as a parking-lot item until the user asked. (4) Phase-boundary sweep found 15+ ADR requirements with zero implementation — per-round audits checked the diff but never asked "did the brief's scope block get fully delivered?"

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

**"Code-complete" requires coordinator visual sign-off.** The agent that writes the code cannot declare it done. The coordinator must render the output, verify it against the spec, and sign off. Self-attestation of visual quality is not accepted.

**Why (2026-06-02):** C1–C6 were all self-attested as code-complete. QC gates checked `tsc` (compiles) and `vite build` (bundles) but never compared the rendered output against the mockups. Every tile card had wrong font sizes, missing separators, broken sr-only hiding, no vertical centering, and inconsistent text hierarchy. The operator discovered all of this during live testing — not during any QC gate.
