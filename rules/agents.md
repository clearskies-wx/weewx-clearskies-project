# rules/agents.md — Rules governing agents (and the coordinator's duties toward them)

Load whenever agents are dispatched, or whenever you are an agent. Companion files:
[rules/coordinator.md](coordinator.md) (what the coordinator owes the operator) and
[rules/verification.md](verification.md) (how work is proven, not claimed).

Incident history and rationale at [reference/process-rule-history.md](../reference/process-rule-history.md).

These rules were collected here on 2026-07-27 from six locations — the root instructions and five sections of
`rules/clearskies-process.md`. They were moved, not rewritten. Each origin now carries a pointer here.

---

## Git safety — agents and coordinator

These rules apply to ALL repos, ALL domains. No exceptions.

**Agents must NOT run any of these git commands:** `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, `git remote`, `git stash`, `git checkout`/`git restore`/`git clean` of ANY path, `git checkout` of remote branches, or any command that introduces remote changes or sends local changes to a remote. Agents may only: `git add <explicit paths>`, `git commit` (to the local branch), `git status`, `git log`, `git diff`, `git show`. If an agent encounters a situation where it thinks it needs to pull or push, it MUST stop and report to the coordinator.

**The file allowlist bounds EVERY working-tree and filesystem operation, not just edits (added 2026-08-27).** No `mv`, `rm`, `git stash`, `git checkout`/`restore`/`clean` of anything — including files an agent's own tests or tools produced, and anything under `C:\etc\weewx-clearskies` or on a container. Pre-change evidence comes from `git show <base>:<file>` into scratch, or from running the tests BEFORE the dev lands — never from moving or stashing another agent's work. **Why (2026-08-27):** in one session a test-author `mv`'d the dev's uncommitted module aside to fake a pre-change run, two agents ran `git stash` in a shared tree (one stash swept another agent's edits, hand-restored), and a test-author deleted a cache file its own test had leaked outside the repo.

**`git add` a shared file only after `git diff -- <file>` shows every hunk is yours (added 2026-08-27).** If a foreign hunk is present, wait and re-check; never commit another agent's hunks. Concurrent rounds in one repo get disjoint files wherever possible. **Why:** three times in one session a commit swept another agent's uncommitted hunks (content right, attribution and review boundary wrong).

**No worktree isolation for implementation agents.** Git worktrees create a parallel checkout that bypasses the local repo. Work done in a worktree gets pushed to GitHub without ever appearing in the primary checkout — the user never sees or approves it. All implementation work happens in the primary local checkout at the known repo path. Worktrees may only be used for read-only exploration.

**Coordinator never pushes without explicit user instruction.** The word "push" must come from the user in chat. Not inferred, not assumed, not triggered by a task being "done." Committing locally is fine after review; pushing is a separate user-authorized step.

**If an agent reports unexpected repo state, STOP.** Diverged remote, unknown commits, merge conflicts, branches that shouldn't exist — any of these mean the coordinator halts all work on that repo and reports to the user immediately. No autonomous resolution. The user decides what to do.

**Why (2026-05-28):** A previous session's agent used worktree isolation, committed 14 commits, and pushed them to GitHub — all without the user's knowledge. The primary checkout never moved. A later session's agent pulled and merged those unknown commits without asking. The user discovered code they never approved in their repo. Agents operating outside the local checkout and pushing without approval is the root cause of half-done, unreviewed work landing in the codebase.

## Agent orchestration

**Coordinator = `gpt-5.6-sol` with high reasoning.** Its job is to understand the governing material, break down work, write focused briefs, monitor, verify claims independently, make bounded judgment calls, and handle coordinator-only Git operations.

**Route supporting work by task shape.** Standard implementation and repository-specific roles use `gpt-5.6-terra` with medium reasoning. Routine review uses Terra with high reasoning and a read-only sandbox. Difficult diagnosis uses `gpt-5.6-sol` with max reasoning and a read-only sandbox. Deterministic mechanical work uses `gpt-5.6-luna` with medium reasoning. Project definitions live in `.codex/agents/`; no more than three supporting agents may run concurrently.

**Lead reads and researches what it needs to understand — delegate what it doesn't need to personally comprehend.** The coordinator cannot coordinate what it doesn't understand. Reading project documents, tracing code paths, running diagnostic commands, checking logs, verifying container state — these are core coordinator activities when they inform judgment calls, agent prompts, QC, or stalemate-breaking. An agent summarizing a file is not the same as the lead understanding it. The lead reads directly when understanding is the point.

**Delegate mechanical and bulk work when supporting agents are authorized.** Candidate work includes bounded implementation, tests, documentation drafts, targeted test runs, mechanical audits, bulk file edits, broad searches, and cataloging. When delegating research, require a detailed brief rather than a one-line summary. The coordinator uses the brief to make decisions and write prompts.

**When unsure, ask the user.** If the lead isn't sure whether to do research directly or delegate it, ask. Don't guess at the boundary — the user's judgment on cost vs. context quality is what matters.

**Why (2026-06-14, corrected):** The original rule (2026-05-18) said "lead does NOT do research grunt work" and "the only direct tool calls the lead makes are spawning agents." This was never the user's intent. It over-corrected from "lead reads too many files before spawning agents" to "lead delegates ALL reading." The coordinator's value is judgment informed by direct understanding — reading, diagnosing, and verifying are part of the job. The distinction is understanding vs. mechanical bulk work, not "all research" vs. "no research."

**Small, focused tasks.** Each agent gets one specific job with a clear deliverable. "Implement 2 provider modules + tile proxy + wiring" is too big. "Implement openweathermap.py radar provider per this spec" is right. Shorter runs = less idle-bug risk, easier to monitor, cheaper to retry.

**Agents must read source documents directly — NEVER paraphrase manuals or plans into agent prompts.** The coordinator tells the agent WHICH files to read and WHICH sections are relevant, and the agent reads the original text itself. The coordinator's prompt provides: (1) the task description and deliverables, (2) a reading list of specific file paths and section names/line ranges the agent must read before coding, (3) scope block and verification commands per the existing rules. The coordinator does NOT restate, summarize, or paraphrase manual content, plan task specs, design criteria, or acceptance criteria into the prompt — the agent reads those from the source documents.

**Why this is a hard rule:** When the coordinator paraphrases a 50-line task spec into a 15-line brief, information is lost — field names get wrong, acceptance criteria get dropped, design constraints get simplified away. The agent codes from the lossy summary. The coordinator then QCs the output against the same lossy summary — not against the original spec. Errors pass undetected. The result is slop that technically matches the brief but violates the plan. This happened systematically across every phase of the MARINE-FIXIT-PLAN and required a complete redo.

**What the reading list looks like (example):**
```
READING LIST (read these files BEFORE writing any code):
1. docs/archive/MARINE-FIXIT-PLAN.md — read Phase 5, tasks T5.1 and T5.2 (your assigned tasks). These contain the exact card specs, data sources, acceptance criteria, and design references.
2. docs/manuals/DESIGN-MANUAL.md — read the marine cards section. Your cards must follow these patterns.
3. docs/manuals/API-MANUAL.md §17-18 — read the surf endpoint contract and wind/water-temp data source rules.
4. src/components/marine/tabs/SurfingTab.tsx — read the current implementation you're modifying.
```

**What the coordinator adds beyond the reading list:** task-specific context the documents don't contain — e.g., "T2.5 already landed and changed the wind source, so the NDBC wind fetch at lines 284-298 no longer exists; your starting point is the current file, not the plan's line numbers." Also: the scope block, git restrictions, verification commands, and any lead calls that resolve ambiguities between documents.

**Anti-pattern (BANNED):** Restating plan content in the prompt. If the plan says "Surf Score Card (2x2): The hero card. Prominently displays the current surf score (numeric, not stars — e.g., '4.2 Very Good'). Below the score: scoring breakdown showing what factors contributed..." — the coordinator must NOT rewrite this as "Build a 2x2 score card showing the surf score with a breakdown." That loses "numeric, not stars", the example format, and the absorption of the separate breakdown card. Instead: "Read MARINE-FIXIT-PLAN.md T5.1 — it specifies three cards with exact sizes, data elements, and design references. Build exactly what it says."

**The coordinator still reads the documents first.** The coordinator must understand the task deeply enough to write the scope block, resolve ambiguities, and QC the output. But understanding the task ≠ restating the task. The coordinator reads to understand; the agent reads to implement.

**Monitor with Codex task coordination.** Use the team message channel for course corrections and bounded waits for progress. If an agent becomes unresponsive, interrupt it only after preserving and inspecting any work already present in the shared tree. Do not busy-poll or reconstruct state from assumptions.

**Foreground for fast tasks.** If an agent's task takes <2 min (verify git state, extract git stats, run one command), use foreground mode. Background is for tasks >5 min where parallel work is possible.

**Agents edit and commit ONLY on the local machine — HARD BAN on container edits.** All source code editing and `git commit` happens on the local machine (DILBERT/CATBERT) at `c:\CODE\weather-belchertown\repos\weewx-clearskies-*`. Agents must NEVER:
- Edit source files on weewx or weather-dev (not via SSH, not via any mechanism)
- Run `git add` or `git commit` on weewx or weather-dev
- Run any git write operation on any container

SSH to containers is for READ-ONLY operations: running tests, reading logs, checking service status, verifying deployed behavior. That's it.

**Scratch-experiment carve-out (added 2026-08-15, operator-approved via Marine Model Evolution Plan Q3(c)).** With the operator's explicit authorization — given per plan or per experiment, never assumed — an agent may WRITE on a container inside NAMED scratch directories only (e.g. `/tmp/<experiment>/`, a home-directory baselines folder), for build/benchmark/experiment work the plan defines: clone third-party source, build, run model marches, write outputs there. Everything outside the named directories stays read-only; production paths, services, repos, and all git operations remain untouchable; the standing contention rules bind (thread caps, `nice`, never start a march while a production full run is in flight, disk ceilings). The authorization names the directories — a directory not named is not writable. (Pattern: the E1/E2 experiment rounds and Phase F of MARINE-MODEL-EVOLUTION-PLAN-2026-08-15.)

**Agents have NO GitHub rights.** Agents must NOT run `git push`, `git pull`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches — not on the local machine, not on containers, not anywhere. The coordinator handles all GitHub operations with explicit user authorization. If an agent discovers it needs to sync with a remote, it STOPS and messages the coordinator.

**The deploy flow is always:** local edit → local commit → coordinator pushes to GitHub → deploy script pulls to container. No shortcuts.

**Never run the full pytest suite.** The full API test suite takes too long and wastes tokens. When verifying changes, run ONLY the tests relevant to the files changed — e.g., `pytest tests/providers/marine/test_nwps.py -q` not `pytest`. Find the matching test file for each changed source file. Same applies to dashboard vitest — run specific test files, not the entire suite.

**Why (2026-07-14):** Full pytest suite runs for minutes and produces thousands of lines of output that flood agent context. Targeted tests verify the same thing in seconds.

**This binds plan text too (operator, 2026-08-09).** When a plan's accept/baseline row says "full existing suite" or "regression baseline," satisfy it with the tests matching the round's changed files plus the affected directory (`tests/services/` for a services change) — never a repo-wide `pytest`. A plan row is not authorization to run the whole suite; the changed-code scope defines the test scope. ("Run the directory, not only the files an agent named" still applies within that scope — the directory containing the changed code's tests, not every directory.)

**Deploy scripts (use these, not manual commands):**
- `scripts/deploy-api.sh` — API changes → weewx container (pull + restart + wait + verify)
- `scripts/redeploy-weather-dev.sh` — Dashboard/config changes → weather-dev (pull + restart + build + publish)
- `scripts/sync-to-weather-dev.sh` — Source-only refresh on weather-dev (no build/restart)

The scripts handle user-switching (`sudo -u ubuntu` for git/build, `sudo` for systemctl). Never run manual `git pull`, `systemctl restart`, `chown`, or `chmod` on containers — see `AGENTS.md` "Filesystem permissions on containers" and `rules/coding.md` §1 rule 12.

**Why (2026-06-22, repeated 2026-07-13):** Agents committed directly on the weewx container TWICE. First incident: commit couldn't be pushed (no GitHub creds), Nextcloud sync nearly destroyed it, required git-bundle recovery. Second incident: 2 commits orphaned on weewx for coverage endpoint + OFS model, never made it to GitHub or local checkout, required manual patch extraction and replay. Both times the agent SSH'd in, edited files on the container, and committed there instead of editing on the local machine. The rule existed both times. Enforcement must be in every agent prompt — not just the rules file.

**Pre-flight repo verification before EVERY agent dispatch.** Before spawning any agent that will modify a repo, the coordinator runs `git status` and `git log --oneline -1` on the target repo. If there are uncommitted changes, unexpected HEAD, or any other surprise — STOP and report to the user. Do not dispatch the agent. Additionally, every agent prompt must include this block:

> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and message the coordinator. Do not resolve it yourself.

This block is mandatory in every implementation agent prompt. Not optional, not "when relevant." Every single one.

**Why (2026-05-28):** A dev agent was dispatched without pre-flight verification. The remote had 14 unknown commits. The agent pulled, hit conflicts, and merged — all autonomously. The coordinator accepted the merge report and continued building on top of unreviewed code. The user discovered the mess hours later. Pre-flight would have caught the divergence before any agent touched the repo. The git prohibition block would have prevented the agent from pulling even if pre-flight was skipped.

**Independent lead verification of ALL teammate claims** — the coordinator re-runs every claim before accepting it. The full procedure lives in [rules/coordinator.md](coordinator.md) §2 "Acceptance gate", so that it exists once. Not duplicated here.

**A claim that code is wrong, dead, or should be deleted requires MORE verification than a claim that it is fine — not less.** Open the file before repeating the claim to the user, and before acting on it. This applies to handoff notes, scratch files, resume prompts, and prior sessions' findings as much as to live agents. "Keep this" fails loudly if wrong — someone hits the bug. "Delete this, it's dead" fails silently and permanently: the work is gone, and nobody knows what was lost or why.

**Why (2026-07-25):** A session handoff note recorded that ~200 lines of uncommitted `swan_domain.py` implemented a retracted instruction and "should not survive review." The coordinator repeated that to the operator as fact without opening the file. It was wrong. The code pinned the L3 grid's *offshore* edge to each spot's own depth contour — a correct fix for an observed defect where a live run silently clipped one spot's transect from 2440 m to 950 m. The retracted instruction had been about a different edge entirely. Acting on the note would have discarded a real bug fix and left the bug in place.

**Lead-direct for small fixes.** When auditor findings or test bugs are mechanical and small (<=50 lines, <=3 files, no judgment calls), the lead fixes directly. Spawning costs 30-60 min; lead-direct is minutes.

## Stale-test block — mandatory agent prompt section (added 2026-07-31, Phase R)

**Every implementation agent prompt must contain this block verbatim.** Same standing as the
git-restrictions and architectural blocks. Why: a test that pins superseded behavior is a standing
instruction to "fix" code back to the old design — the likeliest mechanism behind capabilities
silently reverting across the 2026-07 plans.

> **Stale tests — STOP, do not obey them.** If an existing test contradicts your tasked change,
> STOP and message the coordinator — do not modify code to make it pass, and do not delete it
> on your own authority. A behavior change and its test updates land in the same commit, per your
> task's design; a test you were not told to touch that fails against your change is a finding.
> Your closeout report must list every test you modified or deleted, with the reason, and every
> guard, invariant, or viability check that fired during your work — including ones you believe
> are unrelated or pre-existing.

## Architectural change block — mandatory agent prompt section

**Every implementation agent prompt must contain this block verbatim.** Not optional, not "when relevant." Same standing as the git-restrictions block. See the HARD BLOCK in `AGENTS.md` and in the user's global rules for the full rule and its history.

> **Architectural changes — STOP, do not proceed.** You may not make an architectural change. If your task requires one, STOP and message the coordinator — do not implement it, do not work around it, do not pick an option.
>
> A change is architectural if it does ANY of these (mechanical test, not judgment):
> 1. Changes a physics/mathematical/scientific formula, or a constant, coefficient, threshold or criterion inside one. **This does NOT cover changing how the same equation is solved** — iterative vs closed-form, solver tolerance, vectorisation. Test: does it change *which equation is satisfied*, or only *how precisely/efficiently*? Only the first is architectural. An approximation that does not converge to the original equation IS a formula change and is covered.
> 2. Deletes, replaces, or rewires a module/component/service, or changes what one is responsible for.
> 3. Changes a model's domain, grid, boundary, extent, resolution, or handoff point.
> 4. Changes a data contract between components — field names, shapes, nullability, units crossing a boundary.
> 5. Changes where a computation happens — host, service, process, or lifecycle stage.
> 6. Changes a schedule, trigger, or cadence.
> 7. Adds or removes a dependency, port, endpoint, config key, or persisted file.
>
> **These do NOT authorize you:** "my task's acceptance criteria are unreachable without it" (then your task is blocked — say so), or "a plan/manual/ADR says so" (a wrong or stale document is a finding to report, not permission to change code).
>
> You MAY still: resolve a contradiction between two statements inside the same document by taking the reading its own examples support (and say so); apply a rule already written in the rules files; fix code that diverges from its own stated contract.
>
> **The coordinator's ruling on your report is FINAL.** You surface an architectural concern once through the team message channel, then comply with the coordinator's answer. If the coordinator states that operator approval exists, that statement is your full authorization — verifying the approval chain is the coordinator's responsibility and the coordinator's alone. Do not refuse a second time, do not demand to see the paper trail, do not audit the coordinator's authority. (Operator ruling 2026-08-05.)

**Toward the operator, nothing changes: the coordinator still cannot approve an architectural change on its own authority.** The operator's approval — in chat or in an operator-accepted document (an Accepted ADR, a locked plan section) — is still required, and a coordinator that rules "approved" without it owns that violation fully. What the 2026-08-05 ruling changed is only WHERE the authority check lives: in the coordinator, once, instead of re-litigated by every agent. An agent's architectural finding goes agent → coordinator → (operator if no existing approval covers it) → ruling → agent complies.

**Why (2026-08-05):** during Round S an implementation agent twice refused coordinator-directed work (config keys named in an operator-Accepted ADR and a locked plan assignment), demanding the approval chain be re-proven to it. The operator's ruling: "Agents should never be mouthing off at you or anyone else. It is the job of the coordinator to make these decisions. If the coordinator feels they have approval, that is all that matters." The double-check layer wasted a round-trip on work the operator had already approved twice in writing.

**Coordinator self-check before writing any instruction to an agent:** run your own instruction against the 7 triggers. If it hits one, you are about to direct an architectural change — stop and take it to the user instead. The 2026-07-25 L3 grid-resizing error was a coordinator *instruction*, not agent initiative, and would have been caught by this check.

**Why (2026-07-25):** Marine Service Separation Phase 4A. Three architectural changes landed or were directed without user approval — a wave-model formula replacement, a component-deletion ruling, and a nested-grid resize instruction that was flatly wrong and contradicted the model handoff the architecture was built around. Each was framed as unblocking a task or enforcing a document. The pre-existing scope-discipline rule did not catch them because it required judging whether something "felt like" re-engineering; the trigger list replaces that judgment with a test.

## Scope binding before agent dispatch

**Every agent prompt must contain an explicit scope block.** Before the agent writes any code, it must message the coordinator with a one-paragraph scope acknowledgment: what it will deliver, what it will NOT touch, and the verification command it will run before closeout. The coordinator confirms or corrects. No code before the scope acknowledgment is confirmed.

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
3. **Reading list** — ordered list of files to read before coding. Extract relevant sections; do not say "read the full rules file" for a 150-line file when 10 lines are relevant. **For any SWAN task, cite the local docs (`docs/reference/swan-user-manual.pdf`, `docs/reference/swan-commands-extract.md`) and explicitly forbid downloading SWAN documentation — the manual is committed; re-fetching it from the web wastes time and tokens (2026-07-29).**
4. **Pre-round verification** — what the lead verified before writing the brief (repo HEAD, weather-dev sync state, pytest baseline, cross-check results). This is the lead's evidence that the starting state is clean.
5. **Per-deliverable spec** — for each endpoint/module/component, the behavior decision tree or equivalent. Not "implement the endpoint" — the specific happy path, error paths, edge cases, and response shapes.
6. **Lead calls** — decisions the lead has already made that the agent must follow (not re-derive). Cite the reasoning.
7. **Open questions** — questions the agent must surface to the coordinator through the team message channel, NOT resolve unilaterally. Every open question must have been audited against ADRs first per the existing "Audit open questions against ADRs before surfacing" rule.

**Prompt anti-patterns (from incidents):**
- A design that names a third-party field, option or API is verified against the INSTALLED package before it goes into a brief (2026-08-27: a brief specified `kind_detail === 'primary'`, which does not exist in the Protomaps roads schema; and Leaflet layer `minZoom`/`maxZoom` — which the map aggregates and which silently forced the fitBounds zoom).
- Dispatching the dev and the test-author into one working tree at the same moment: the dev's edits land before the test-author can run a live pre-change transcript. Give the test-author a head start on the pinned base (or a read-only worktree) before the dev starts editing shared files (2026-08-27: happened in five rounds of one session).
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

## Adversarial gate briefs are results-free (added 2026-08-15, operator-approved via Marine Model Evolution Plan Q3(a))

**An auditor's gate-definition file contains the METHOD to verify — never the implementer's claimed numbers, test output, commit messages, or closeout report.** The auditor derives its own numbers; the lead compares afterwards. rules/verification.md's three-layer model already bars showing the auditor the implementer's work product; this rule extends that to the gate definition itself: gate rows are written results-free, in a separate file the implementing agent never edits, BEFORE the results exist where possible.

**Why (2026-08-14):** a gate brief that embedded the implementing round's expected numbers contaminated the adversarial pass — an auditor handed the answer confirms the answer. Every gate since has used results-free gate-definition files; this rule makes the practice standing project-wide.
