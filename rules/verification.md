# rules/verification.md — How work is proven, not claimed

Load whenever you are about to declare something done, close a round, audit someone else's work, or
run a QC gate. Companion files: [rules/agents.md](agents.md) and [rules/coordinator.md](coordinator.md).

These rules were collected here on 2026-07-27 from five locations — three sections of
`rules/clearskies-process.md` and two sections of the root instructions. They were moved, not rewritten; each origin
carries a pointer here. The three-layer model and the known-answer test mandate are new, added by
task A3 of the Marine Model Restoration Plan.

---

## Real-data verification only — operator rule, 2026-09-02

**Synthetic, mocked, fixture-only, simulated, and fake tests are banned.** They
do not prove that software works. Any result used to support a repair, audit,
deployment, or plan gate must run the real deployed software on its correct
live project host, use real available inputs, and inspect the real output it
produces. A test double, fabricated provider response, or handwritten model
artifact is never functional evidence.

Use `librewxr` for marine-model work, `weewx` for API/database work, and
`weather-dev` for dashboard/configuration work. If real input data is not
available, the gate remains open; do not replace it with a synthetic substitute.

---

## QC gate questions — operator rule, 2026-09-02

Every QC review, audit, and close gate answers all five questions with direct
evidence:

1. Does the code follow the approved plan?
2. Does the code advance the stated project directive?
3. Does the code meet applicable engineering best practices?
4. Does the code meet applicable security best practices?
5. Does the code follow the governing project documentation and manuals? If
   not, is the code wrong or is the documentation wrong?

The fifth question requires an explicit conclusion. A mismatch is never
silently accepted and a document is never changed merely to make a review
green. Correct the code when it diverges from the approved/manual contract;
surface a genuine documentation error for an operator decision.

## WW3 and SWAN manual gate — operator rule, 2026-09-03

For any coding or QC item that creates, changes, consumes, or validates a WW3
or SWAN deck, boundary, transfer, output-point list, hotstart, or native
command, the committed local model manual is a mandatory design and evidence
authority. The implementation brief and independent review cite the exact
relevant manual clause, not merely the manual filename. QC preserves the
generated input/deck and the native program's relevant output or log lines,
then checks them against that clause before declaring the item accepted.

This manual check supplements, rather than replaces, live input/output and
reality evidence. The manuals cannot validate provider caching, persisted
generation lifecycle, or forecast correctness; those remain separate plan and
runtime gates. A manual/deck mismatch fails the item even if the solver exits
successfully.

**Testing does not drive production.** Tests are evidence after coding is
complete; they are not a productivity measure, a substitute for completing a
task, or a reason to repeatedly reshape production code around a test. The
measure of progress is completion of approved task work and software working
with real inputs and outputs on its correct live host.

---

## The three layers, and what each is worth

Three different things get called "verification." They catch different failures and **none of them
substitutes for another.** Say which layer you mean.

| Layer | What it is | What it proves | What it CANNOT prove |
|---|---|---|---|
| **Guard** | A unit test, written by the implementing side, that must **fail against the pre-change code** | That a specific defect does not silently return | **Nothing about whether the system works.** A guard is a regression guard. It runs against the code's own assumptions, on data the author chose |
| **Invariant** | A runtime assertion evaluated on **real production data**, every cycle | That the relationship still holds on data nobody curated | That the value is *right* — only that it is not obviously wrong |
| **Adversarial** | An auditor who never sees the implementing side's tests, commit messages, or report, briefed to **disprove** the claim | That someone actively trying to break the claim could not | That no defect exists — only that this reviewer found none |

**A guard that passes is not evidence the system works.** It is evidence one specific regression has
not recurred. Reporting "the tests pass" as though it answered "does it work" is the single most
common false-closure in this project's history.

**The adversarial pass has one hard requirement: the auditor must not be shown the implementing
agent's work product.** Not its tests, not its commit message, not its closeout report. An auditor
handed the implementer's own evidence audits the evidence, not the system. Give it the design and
the expected numbers, and the brief: *"This is claimed to work. Prove it does not. Look for values
right by accident, right for one timestep only, right in cache but never recomputed, or right
because a fallback fired silently."* It passes only when it reports it could not disprove the claim
**and names what it ruled out.**

## Known-answer tests are mandatory for numerical kernels

**Any function that computes a physical quantity from a closed-form relation gets a test against an
*independently implemented* reference — not a rearrangement of the same code.**

`tests/test_surf_1d_dispersion.py` is the pattern to copy: it solves ω² = gk·tanh(kd) with Brent's
method, sharing no code path with the implementation under test. The two agree or one of them is
wrong, and neither can hide behind the other.

**This is the only defense against the dispersion class of defect** — a kernel that is wrong in a way
that still produces plausible, well-shaped, monotonic output. Such a defect passes every other gate
in this project: it does not crash, its guards pass, its invariants hold, and its numbers look like
wave numbers. Only an independent computation of the same quantity catches it.

Applies to shoaling, refraction, breaking, and wave setup as they are touched. A rearrangement of the
implementation's own algebra is **not** an independent reference — if the test would still pass with
the same sign error, it is testing nothing.

**Every KAT closeout states which tests FAIL against the pre-change code, with the transcript** — a
KAT that passes pre-change proves nothing; non-falsifiable pins are declared as such (2026-08-03).

**A transcript is pasted only from a run that happened (added 2026-08-27).** When a live pre-change run is impossible (the dev already landed in the shared tree), the docstring says so and cites the `git show <base>:<file>` absence check instead — never a reconstructed or expected transcript. **Why:** a test-author wrote a pre-change "transcript" before running the file, then caught and corrected it before closeout.

**Harness mocks are patched where the caller LOOKS THE NAME UP, and every harness mock asserts it was invoked (added 2026-08-27).** `monkeypatch.setattr(module, "fn", …)` does nothing for a caller that did `from module import fn`. A mock that is never called proves nothing — and can hide a real side effect. Tests never write outside `tmp_path`/their fixtures dir. **Why:** an integration test's mock patched the source module while the caller had a name-bound import; a real network fetch ran inside pytest and its leaked cache file then made the test green by accident. Found by the dev, not the test's author.

**The acceptance check for a dashboard round is the production build command — `npm run build` (`tsc -b` + `vite build`) — not `tsc --noEmit` on a sub-config and not a grep that excludes test files (added 2026-08-27).** `tsc -b` type-checks the test files; fixtures typed against a narrowed union fail the deploy, not the review. **Why:** a round closed with "tsc clean" from `tsc --noEmit -p tsconfig.app.json | grep -v .test.`, and the deploy build failed on 11 test-file type errors.

## Validate against reality, never against the model's own output

A physical model's own output is **never** evidence that the model is right. It is evidence about the
input file. Every internal-consistency check — energy closure, mass balance, partition sums, "the
numbers add up" — measures whether the code is self-consistent, which a model that discarded reality at
its input will pass perfectly.

**The rule:** before declaring any physics output correct, compare it to something that did not come out
of the model. In this project, in order of preference:

1. **An independent observation of the same quantity at the same place and time** — an NDBC buoy, a tide
   gauge, a station reading. Often already in the payload.
2. **A commercial or governmental forecast a user would compare us to** — Surfline, NWS, PredictWind.
   Not ground truth, but a sanity envelope; a large disagreement is a finding, not noise.
3. **What a person standing there would see**, stated in the units they would use. "Chest to overhead"
   and "4–6 ft" are checkable claims. "Hs = 0.82 m with closure 1.02" is not.

**Corollaries, each earned the hard way on 2026-07-26:**

- **A conservation check cannot detect a missing input.** Energy closure of 1.02 means the components sum
  to the spectrum. It says nothing about whether the spectrum is the right spectrum. If the input threw
  away two of three swell trains, closure is *still* 1.02.
- **A conservation check over a degenerate sample is not a pass.** Sum-of-one-partition ÷ spectrum ≡ 1.0
  identically. Report the sample split in the headline and refuse to say PASS when the meaningful
  subsample is n=1.
- **Do not compare the two quantities that happen to agree.** Surfline's *swell heights* combined to
  2.54 ft and our *spectrum Hs* was 2.7 ft, so the coordinator announced a match — while Surfline's
  actual headline, **surf height 4–6 ft**, was a different and much larger quantity we never checked.
  Pick the comparison quantity *before* looking at the numbers, and pick the one the user cares about.
- **"Close" is a number, not an adjective.** 3.8–4.2 ft against 4–6 ft is not agreement: it sits at or
  below the bottom of the range and never reaches the top. State the gap as a percentage or a range
  overlap and let it be judged, rather than characterising it.
- **Flat output is a symptom.** A forecast that barely moves while its drivers swing (face height pinned
  at ~4 ft across 14 h while Tp went 5.2→10.0 s) is reporting something insensitive to its inputs. Treat
  invariance as a defect signal, not as stability.
- **Total right, distribution wrong is the hard failure mode.** Getting Hs approximately right while
  putting the energy at 7.7 s instead of 12–19 s produces plausible-looking numbers and wrong surf.
  Aggregate agreement never licenses skipping the spectral/temporal comparison.

**Why (2026-07-26, Phase 8 T8.6/T8.7):** every automated check in Phase 8 passed while the surf model was
publishing one swell train where a buoy in the same payload resolved four, a 20 s groundswell from a
direction the coastline shadows, and surf height flat at the bottom of the real range. The defect was
found by the **operator**, from a **screenshot**, after the coordinator had reported energy closure as a
PASS. The coordinator then twice characterised clear disagreement as agreement before being corrected.
The cause was upstream and structural — `ww3_to_swan_boundary()` synthesises a single JONSWAP peak from
scalar WW3 parameters — and no self-consistency test could ever have found it. See C-81, C-83.

**Anti-pattern:** running the project's own verification script, reading its PASS, and reporting the
physics validated. The script measures what it measures. Ask what it *cannot* see, and go look at that
with something external.

## Marine deploy verification — reality gate and publish-liveness (added 2026-07-31, Phase R)

**Why:** on 2026-07-31 a single deploy stopped the marine model publishing for a full day and
decoupled its sea state from the ocean — while every gate passed, `/health` said `ok`, and a fired
viability guard scrolled by unread. The only working QC was the operator manually comparing against
Surfline. These rules make that check mandatory and mechanical.

1. **The reality gate.** No marine deploy or config push is complete until, within one forecast
   cycle, the coordinator pastes the model's deep-water values (Hs / Tp / direction at the 15 m
   reference or the published forecast) beside an external reference (NDBC 46222 observations at
   the matching hour, or Surfline) — with the comparison quantity and tolerance stated *before*
   looking at the numbers. Out of tolerance = the deploy FAILED; roll back first, diagnose second.
   A deploy with no pasted reality comparison is an unverified deploy, whatever its gates said.
2. **Publish-liveness.** Within one cycle of any marine deploy, the service either publishes or
   refuses loudly (health ≠ `ok`, reason named, visible on the admin page). Silent `ok` +
   no-publish = FAILED deploy. "The gate passed" does not answer "did it publish."
3. **Every phase gate carries one end-to-end row** — a full nest run → valid_fraction → publish →
   reality comparison — however component-scoped the phase. When a deploy changes published
   semantics, enumerate the invariants whose firing criteria reference the changed quantity and
   pre-state which will move — before deploy, not after (2026-08-03: inv-4 vs d0d0077). Gate G2 (L1-only) and Gate G3
   (sizing-only) both passed while the system was breaking; a component gate with no system row
   is how four regressions stack before the first end-to-end measurement.

## Evidence hygiene (added 2026-07-31, Phase R)

- **Numbers carry their command.** Any quantitative claim entering a gate record, a concerns entry,
  or an operator report cites the command and artifact that produced it. A number without
  provenance is a claim, not evidence — TC-21's "grid is 35% dry land" steered a full day of
  operator decisions and was false; the artifact that would have disproven it existed the whole time.
- **"Behavior unchanged" is verified on production-shaped data, never only the fixture.** A
  commit claiming "matches the old value to 0.0000°" against a 2-point fixture was wrong in
  production. Equivalence claims get checked against the real config/geometry, or they are not made.
- **Stale tests.** A task that changes behavior updates or deletes the tests pinning the old
  behavior IN THE SAME COMMIT. A failing test that pins superseded behavior is a finding — STOP
  and surface it; never alter code to satisfy it. A test pinning dead design is a standing
  instruction to the next agent to revert the system, which is how "finished" capabilities vanish.

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

## Self-audit before delivering

For non-trivial outputs (architecture recommendations, multi-step plans, ADR drafts, code beyond a one-line fix), don't ship the first draft. The pattern is **generate → audit → revise → deliver**, and surface the audit in your reply.

- **Generate** the initial recommendation.
- **Audit it yourself** against concrete categories: security risks, maintenance burden, dependency lock-in, edge cases, what forces rework later, what looks ugly to a future reader. Apply pressure to your own choices.
- **Revise** based on the audit — strengthen weak points, remove unnecessary complexity, document tradeoffs explicitly, propose mitigations for the risks that remain.
- **Deliver** the refined output **with the audit findings surfaced**. Show what you considered, what you ruled out, and what's still uncertain.

You have explicit permission to think critically about your own work and refine it. Goal: correct and durable, not fast and sloppy. Surfacing the audit lets the user push back on points you may have under-weighted.

**Evidence over assertion.** When the self-audit involves verifiable claims (tests pass, file exists, endpoint returns expected shape), include the verification command and its output in the reply. "I verified the tests pass" is not evidence. `pytest result: 73 passed, 0 failed at commit abc1234` is evidence. This applies to claims about test results, accessibility scans, build success, deployment state, and any other machine-verifiable assertion. For non-machine-verifiable claims (design judgment, trade-off analysis), the existing audit-and-surface pattern is sufficient.

**Scope:** non-trivial outputs only. For simple sync / match-state / one-line-fix tasks, the "Simple means simple" rule still wins — don't perform an audit just to look thorough.

**Anti-pattern:** announce a perfect-sounding plan, then scramble when the user surfaces an obvious risk. Better to surface the risk yourself first, with the proposed mitigation.

## Prompt faithfulness

Before reporting a task complete, walk the user's original request and confirm every distinct ask has a corresponding deliverable or an explicit deferral communicated to the user. The user should never have to say "but I also asked you to do X." When the task involves multiple items, enumerate them at the start and check them off at the end.

## Real-clock and production-shape rows (added 2026-08-13, Z3.8 audit)

**Any gate on a schedule- or feed-integration change must include at least one row computed
against the provider's REAL posting clock** — probe the actual publication times (e.g. NOMADS
`Last-Modified`) and show the worst-case coverage arithmetic, not a fixture's assumption. Every
one of the five Z3 wind/input bugs (age-out window, GFS depth, trigger loss, STOFS depth+anchor,
WW3 boundary depth) shipped through gates whose tests used synthetic clocks; the code's own 2h
STOFS lag assumption was wrong by 4h and nothing ever checked it against the real server.

**Test seeds must be production-shaped.** A fixture that seeds all inputs with the same geometry,
the same cycle label, or exact-hour offsets cannot catch mixed-geometry, provenance-race, or
rounding-mode defects — the Z3.7 IndexError shipped because the h49 test's boundary-hour seed was
accidentally homogeneous (a freshness-gate interaction silently discarded the differing write),
and the Z3.9 gate found `ceil` vs `floor` indistinguishable under exact-hour fixtures. When a
gate's mutation drill survives (the mutated code passes every test), that is a FINDING about the
tests, not a pass.

## Post-remediation reruns cover affected + adjacent suites (added 2026-08-15, operator-approved via Marine Model Evolution Plan Q3(b))

**After remediating any audit finding or test failure, rerun the suites for the changed code AND
the adjacent ones** — the directory containing the changed modules' tests plus every suite
exercising the seams the fix touched — not just the single file the fix edited. A remediation that
reruns only its own test file can break a neighbor silently; the round stays open until the wider
rerun is green. Targeted scope still governs: the adjacent directories, never a repo-wide run
(rules/agents.md "Never run the full pytest suite").

**Why (2026-08-13, Z3.3→Z3.4):** a regression introduced at `7aab009` was missed by the round's
own grep AND its `-k` test sweep, and surfaced only when a later round's lead cross-check happened
to cover the seam. The false-claim protocol caught the reporting; this rule closes the scope hole
that let the breakage through in the first place.

## Carried-over items must cite an operator-validated premise (added 2026-08-15, operator-approved via Marine Model Evolution Plan Q3(d))

**When an open item moves from a closed plan into a successor** (carry-over register, parking lot,
deferred queue), **the receiving entry must cite the operator interaction that validated the
item's premise** — the chat ruling, eyeball, or accept record showing the operator knows the issue
exists and wants it worked. A prior session's own observation, hypothesis, or draft protocol is a
FINDING to surface, never an inherited fact. If no validating interaction exists, the item enters
tagged "unvalidated — surface to operator before any work," or does not enter at all. Carry-over
reviews — including adversarial plan reviews — check premise validation, not just fidelity to the
source document.

**Why (2026-08-15, "Problem-2"):** a single-day observation recorded by a session coordinator in a
protocol marked "draft for operator review" was carried through a plan close into the successor
plan as an established defect — with a task, a pre-approval register row, and an open operator
question built on top of it. The operator first learned the issue existed when asked to approve
its capture mechanism ("THIS HAS NEVER BEEN RAISED AS AN ISSUE!") and dropped it on the spot. The
adversarial review had verified the carry-over faithfully tracked the archive, but never asked
whether the operator had ever validated the premise — fidelity to paperwork is not validation.
