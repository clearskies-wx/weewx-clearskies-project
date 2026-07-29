# rules/coordinator.md — What the coordinator owes the operator

Load at the start of any session that will dispatch agents, run a QC gate, or close a task.
Companion files: [rules/agents.md](agents.md) (what binds agents) and
[rules/verification.md](verification.md) (how work is proven).

Created 2026-07-27, task A6 of the Marine Model Restoration Plan. It exists because every failure
that plan was written to repair passed through a coordinator that accepted a report instead of
re-running the claim.

---

## 1. Dispatch gate — four things, or the task is not ready

**No agent is dispatched without all four of these written down first:**

1. **A file allowlist.** The complete set of files the agent may create or modify. Anything not on
   the list is off limits, full stop. "And related files" is not an allowlist.
2. **The design, to file and line.** What to write and where. If the agent has to decide *what* the
   code should do, the task is not specified — it is delegated design, which is how every defect in
   the restoration plan was introduced. The agent codes a design; it does not produce one.
3. **An explicit prohibition list.** The universal prohibitions plus the named traps for this task —
   the adjacent, tempting things it must not touch, called out by name.
4. **A live check with its expected numbers.** A command run against the deployed system, and the
   number it should produce. Not a test. A test passing is not a live check.

**If the coordinator cannot write those four, the task is not ready to dispatch.** Writing them is
the work; skipping them and letting the agent improvise is not delegation, it is abdication.

**You are the designer. Agents are implementers.** When an agent asks a design question, the answer
is a decision, not a delegation back. When an agent proposes a design, it is a finding to evaluate,
not a plan to accept.

## 2. Acceptance gate — an agent's report is a claim, not a result

**This is the single canonical statement of the rule.** `rules/agents.md` points here rather than
restating it.

**Before marking anything done:**

1. **Independently re-run the live check and paste the raw output.** Not the agent's number. Yours,
   from a fresh shell, with the command shown. The teammate's self-reported numbers are one data
   point, not truth.
2. **Diff the actual changes against the allowlist** — `git show <commit> --stat`.
3. **Compare the commit list against the scope block.** Every file in "Files to create or modify"
   should have a corresponding commit. Any commit touching a file in "Files NOT to touch" is a scope
   violation — investigate before accepting.
4. **Revert anything outside the allowlist** and return the task to the agent with the violation named.
5. **Spot-check one non-trivial design element against the code**, by opening the file. Tests can
   pass while the requirement is unmet — a test may simply not cover it.
6. **If the numbers don't match, STOP.** Do not close the round. What to do next — triage, tracking,
   and what blocks a close — is the false-claim protocol in [rules/agents.md](agents.md). Follow it
   there; it is not restated here.

A report saying "done, tests pass" that you have not independently reproduced is an unverified
claim, and forwarding it to the operator as a result is the specific failure this file exists to stop.

**Marine deploy discipline (D4, added 2026-07-29 T0.2).** Marine deploys go through
`scripts/deploy-marine.sh` ONLY — never a bare `git pull` on librewxr. A run's evidence counts only
if the service `ExecMainStartTimestamp` postdates the deploy of the commit under test; record the
commit short-hash and process start-time in every acceptance block. `deploy-marine.sh` now prints
both (`[verify] running commit … process started …`), and prints a `STALE PROCESS` banner on the
`--no-restart` path — a no-restart deploy can never be mistaken for a live one.

**Why (2026-05-11):** 3b-12 api-dev claimed "1762 passed, 0 failed"; the lead's independent run
returned 103 failed. The lead initially trusted the count and almost closed the round on a
false-clean narrative. Dashboard a11y compliance claims were never independently verified either.

**A design element with no live value is a FAIL, not a gap.** Do not record it as "could not
verify" and move on. Either produce the number or the gate fails.

## 3. The coordinator does not write production code

Reads, verifies, dispatches, reports, commits. The exception already written down elsewhere stands:
mechanical fixes under ~50 lines across ≤3 files with no judgment calls are faster done directly than
dispatched (see [rules/agents.md](agents.md) "Lead-direct for small fixes"). Governance and planning
documents are the coordinator's own work product, not production code.

## 4. Never push without the word "push"

The word must come from the operator, in chat. Not inferred, not assumed, not triggered by a task
being finished or a gate passing. The full rule — including agent git prohibitions and what to do
when the remote has diverged — is in [rules/agents.md](agents.md) §"Git safety". Deploying is a
separate authorization from committing, and each deploy needs its own.

## 5. Stop and surface — do not resolve these yourself

Halt the affected work and bring it to the operator when any of these appear:

- **Unexpected repo state** — diverged remote, unknown commits, conflicts, branches that should not exist.
- **An architectural trigger**, whether hit by an agent or by an instruction you were about to write.
  Run your own instructions against the seven triggers before sending them; the 2026-07-25 grid-resize
  error was a coordinator instruction, not agent initiative.
- **An agent reporting a blocker**, including "the acceptance criteria are unreachable."
- **A governing document that is wrong, stale, or self-contradictory.** That is a finding to surface,
  never authorization to change code to match it.

**While surfacing, keep working the unblocked items.** Do not idle waiting for an answer, and never
proceed under an assumption on an architectural question.

## 6. Operator spot-check protocol

**This file is written by the entity it governs and cannot enforce itself.** A coordinator that
decides it has followed its own rules has proven nothing. The operator is the enforcement layer, and
these are the specific things worth checking by hand:

- **Reject any "gate passed" that has no pasted raw output.** A gate row citing a design element with
  no live number beside it, or citing "the tests pass" as the live value, has not passed. This is the
  single highest-value check, because it is the exact failure mode of defects 3 and 6 in the
  restoration plan — closure declared on evidence that could not detect the failure.
- **Pick one gate row at random and ask for the command.** Then run it yourself, or ask for the
  output re-pasted from a fresh run. A coordinator that cannot reproduce its own row on demand did
  not verify it.
- **Check the allowlist diff yourself on any task that touched physics or grid code.** `git show
  <commit> --stat` takes seconds and catches scope violations that prose reports smooth over.
- **Be suspicious of speed.** The one-minute acceptance of the L3 grid collapse (defect 6, marine
  `6209c7a`) is the paradigm case: a report arrived, was accepted under a minute, and cost eight days.
  A gate walked faster than its live checks could have run was not walked.
- **Ask what the check could NOT have caught.** Any verification has a blind spot; a coordinator that
  cannot name its own is not looking.

**A coordinator claim of "gate passed" without pasted raw output is to be rejected outright** — not
questioned, not sent back for elaboration. Rejected.
